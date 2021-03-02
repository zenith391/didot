const c = @import("c.zig");
const std = @import("std");
const zalgebra = @import("zalgebra");
const Thread = std.Thread;
const Allocator = std.mem.Allocator;

pub const ShaderError = error{ ShaderCompileError, InvalidContextError };

/// The type used for meshes's elements
pub const MeshElementType = c.GLuint;

pub const Mesh = struct {
    // OpenGL related variables
    vao: c.GLuint = 0,
    vbo: c.GLuint,
    ebo: ?c.GLuint,

    /// how many elements this Mesh has
    elements: usize,
    vertices: usize,

    pub fn create(vertices: []f32, elements: ?[]c.GLuint) Mesh {
        var vbo: c.GLuint = 0;
        c.glGenBuffers(1, &vbo);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(c_long, vertices.len * @sizeOf(f32)), vertices.ptr, c.GL_STATIC_DRAW);

        const stride = 8 * @sizeOf(f32);

        var vao: c.GLuint = 0;
        c.glGenVertexArrays(1, &vao);
        c.glBindVertexArray(vao);
        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, stride, 0);
        c.glVertexAttribPointer(1, 3, c.GL_FLOAT, c.GL_FALSE, stride, 3 * @sizeOf(f32));
        c.glVertexAttribPointer(2, 2, c.GL_FLOAT, c.GL_FALSE, stride, 6 * @sizeOf(f32));
        c.glEnableVertexAttribArray(0);
        c.glEnableVertexAttribArray(1);
        c.glEnableVertexAttribArray(2);

        var ebo: c.GLuint = 0;
        var elementsSize: ?usize = null;
        if (elements) |elem| {
            c.glGenBuffers(1, &ebo);
            c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
            c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @intCast(c_long, elem.len * @sizeOf(c.GLuint)), elem.ptr, c.GL_STATIC_DRAW);
            elementsSize = elem.len;
        }

        std.log.scoped(.didot).debug("Created mesh (VAO = {}, VBO = {})", .{vao, vbo});

        return Mesh{
            .vao = vao,
            .vbo = vbo,
            .ebo = if (elements == null) null else ebo,
            .elements = elementsSize orelse 0,
            .vertices = vertices.len,
        };
    }
};

/// Color defined to be a 3 component vector
/// X value is red, Y value is blue and Z value is green.
pub const Color = zalgebra.vec3;

pub const Material = struct {
    texture: ?AssetHandle = null,
    ambient: Color = Color.zero(),
    diffuse: Color = Color.one(),
    specular: Color = Color.one(),
    shininess: f32 = 32.0,

    pub const default = Material{};
};

pub const ShaderProgram = struct {
    id: c.GLuint,
    vao: c.GLuint,
    vertex: c.GLuint,
    fragment: c.GLuint,
    allocator: *Allocator = std.heap.page_allocator,
    uniformLocations: std.StringHashMap(c.GLint),
    /// Hashes of the current values of uniforms. Used to avoid expensive glUniform
    uniformHashes: std.StringHashMap(u32),

    pub fn createFromFile(allocator: *Allocator, vertPath: []const u8, fragPath: []const u8) !ShaderProgram {
        const vertFile = try std.fs.cwd().openFile(vertPath, .{ .read = true });
        const vert = try vertFile.reader().readAllAlloc(allocator, std.math.maxInt(u64));
        const nullVert = try allocator.dupeZ(u8, vert); // null-terminated string
        allocator.free(vert);
        defer allocator.free(nullVert);
        vertFile.close();

        const fragFile = try std.fs.cwd().openFile(fragPath, .{ .read = true });
        const frag = try fragFile.reader().readAllAlloc(allocator, std.math.maxInt(u64));
        const nullFrag = try allocator.dupeZ(u8, frag);
        allocator.free(frag);
        defer allocator.free(nullFrag);
        fragFile.close();

        return try ShaderProgram.create(allocator, nullVert, nullFrag);
    }

    pub fn create(allocator: *Allocator, vert: [:0]const u8, frag: [:0]const u8) !ShaderProgram {
        const held = windowContextLock();
        defer held.release();

        const vertexShader = c.glCreateShader(c.GL_VERTEX_SHADER);
        var v = try std.fmt.allocPrintZ(allocator, "{s}", .{vert});
        c.glShaderSource(vertexShader, 1, &v, null);
        c.glCompileShader(vertexShader);
        allocator.free(v);
        try checkError(vertexShader);

        const fragmentShader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
        var f = try std.fmt.allocPrintZ(allocator, "#version 330 core\n#define MAX_POINT_LIGHTS 4\n{s}", .{frag});
        c.glShaderSource(fragmentShader, 1, &f, null);
        c.glCompileShader(fragmentShader);
        allocator.free(f);
        try checkError(fragmentShader);

        const shaderProgramId = c.glCreateProgram();
        c.glAttachShader(shaderProgramId, vertexShader);
        c.glAttachShader(shaderProgramId, fragmentShader);
        c.glBindFragDataLocation(shaderProgramId, 0, "outColor");
        c.glLinkProgram(shaderProgramId);
        c.glUseProgram(shaderProgramId);

        var vao: c.GLuint = 0;
        c.glGenVertexArrays(1, &vao);
        c.glBindVertexArray(vao);

        const stride = 5 * @sizeOf(f32);
        const posAttrib = c.glGetAttribLocation(shaderProgramId, "position");
        c.glVertexAttribPointer(@bitCast(c.GLuint, posAttrib), 3, c.GL_FLOAT, c.GL_FALSE, stride, 0);
        c.glEnableVertexAttribArray(@bitCast(c.GLuint, posAttrib));

        const texAttrib = c.glGetAttribLocation(shaderProgramId, "texcoord");
        c.glVertexAttribPointer(@bitCast(c.GLuint, texAttrib), 2, c.GL_FLOAT, c.GL_FALSE, stride, 3 * @sizeOf(f32));
        c.glEnableVertexAttribArray(@bitCast(c.GLuint, texAttrib));

        std.log.scoped(.didot).debug("Created shader", .{});

        return ShaderProgram{
            .id = shaderProgramId,
            .vao = vao,
            .vertex = vertexShader,
            .fragment = fragmentShader,
            .uniformLocations = std.StringHashMap(c.GLint).init(std.heap.page_allocator),
            .uniformHashes = std.StringHashMap(u32).init(std.heap.page_allocator),
            .allocator = allocator,
        };
    }

    pub fn bind(self: *const ShaderProgram) void {
        c.glUseProgram(self.id);
    }

    fn getUniformLocation(self: *ShaderProgram, name: [:0]const u8) c.GLint {
        if (self.uniformLocations.get(name)) |location| {
            return location;
        } else {
            const location = c.glGetUniformLocation(self.id, name);
            if (location == -1) {
                std.log.scoped(.didot).warn("Shader uniform not found: {s}", .{name});
            } else {
                //std.log.scoped(.didot).debug("Uniform location of {s} is {}", .{name, location});
            }
            self.uniformLocations.put(name, location) catch {}; // as this is a cache, not being able to put the entry can be and should be discarded
            return location;
        }
    }

    fn isUniformSame(self: *ShaderProgram, name: [:0]const u8, bytes: []const u8) bool {
        const hash = std.hash.Crc32.hash(bytes);
        defer {
            self.uniformHashes.put(name, hash) catch {}; // again, as this is an optimization, it is not fatal if we can't put it in the map
        }
        if (self.uniformHashes.get(name)) |expected| {
            return expected == hash;
        } else {
            return false;
        }
    }

    /// Set an OpenGL uniform to the following 4x4 matrix.
    pub fn setUniformMat4(self: *ShaderProgram, name: [:0]const u8, val: zalgebra.mat4) void {
        if (self.isUniformSame(name, &std.mem.toBytes(val))) return;
        var uniform = self.getUniformLocation(name);
        c.glUniformMatrix4fv(uniform, 1, c.GL_FALSE, val.get_data());
    }

    /// Set an OpenGL uniform to the following boolean.
    pub fn setUniformBool(self: *ShaderProgram, name: [:0]const u8, val: bool) void {
        if (self.isUniformSame(name, &std.mem.toBytes(val))) return;
        var uniform = self.getUniformLocation(name);
        var v: c.GLint = if (val) 1 else 0;
        c.glUniform1i(uniform, v);
    }

    /// Set an OpenGL uniform to the following float.
    pub fn setUniformFloat(self: *ShaderProgram, name: [:0]const u8, val: f32) void {
        if (self.isUniformSame(name, &std.mem.toBytes(val))) return;
        var uniform = self.getUniformLocation(name);
        c.glUniform1f(uniform, val);
    }

    /// Set an OpenGL uniform to the following 3D float vector.
    pub fn setUniformVec3(self: *ShaderProgram, name: [:0]const u8, val: zalgebra.vec3) void {
        if (self.isUniformSame(name, &std.mem.toBytes(val))) return;
        var uniform = self.getUniformLocation(name);
        c.glUniform3f(uniform, val.x, val.y, val.z);
    }

    fn checkError(shader: c.GLuint) ShaderError!void {
        var status: c.GLint = undefined;
        const err = c.glGetError();
        if (err != c.GL_NO_ERROR) {
            std.log.scoped(.didot).err("GL error while initializing shaders: {}", .{err});
        }
        c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &status);
        if (status != c.GL_TRUE) {
            var buf: [2048]u8 = undefined;
            var totalLen: c.GLsizei = -1;
            c.glGetShaderInfoLog(shader, 2048, &totalLen, buf[0..]);
            if (totalLen == -1) {
                // the length of the infolog seems to not be set
                // when a GL context isn't set (so when the window isn't created)
                return ShaderError.InvalidContextError;
            }
            var totalSize: usize = @intCast(usize, totalLen);
            std.log.scoped(.didot).alert("shader compilation errror:\n{s}", .{buf[0..totalSize]});
            return ShaderError.ShaderCompileError;
        }
    }

    pub fn deinit(self: *ShaderProgram) void {
        self.uniformLocations.deinit();
        self.uniformHashes.deinit();
    }
};

const image = @import("didot-image");
const Image = image.Image;

pub const CubemapSettings = struct {
    right: AssetHandle, left: AssetHandle, top: AssetHandle, bottom: AssetHandle, front: AssetHandle, back: AssetHandle
};

pub const Texture = struct {
    id: c.GLuint,
    width: usize = 0,
    height: usize = 0,
    tiling: zalgebra.vec2 = zalgebra.vec2.new(1, 1),

    pub fn createEmptyCubemap() Texture {
        var id: c.GLuint = undefined;
        c.glGenTextures(1, &id);
        c.glBindTexture(c.GL_TEXTURE_CUBE_MAP, id);
        c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);
        c.glTexParameteri(c.GL_TEXTURE_CUBE_MAP, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
        c.glTexParameteri(c.GL_TEXTURE_CUBE_MAP, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
        return Texture { .id = id };
    }

    pub fn createEmpty2D() Texture {
        var id: c.GLuint = undefined;
        c.glGenTextures(1, &id);
        c.glBindTexture(c.GL_TEXTURE_2D, id);
        c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_REPEAT);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_REPEAT);
        return Texture { .id = id };
    }

    pub fn bind(self: *const Texture) void {
        c.glBindTexture(c.GL_TEXTURE_2D, self.id);
    }

    pub fn deinit(self: *const Texture) void {
        c.glDeleteTextures(1, &self.id);
    }
};

// Image asset loader
pub const TextureAsset = struct {
    pub fn init2D(allocator: *Allocator, format: []const u8) !Asset {
        var data = try allocator.create(TextureAssetLoaderData);
        data.tiling = zalgebra.vec2.new(0, 0);
        data.cubemap = null;
        data.format = format;
        return Asset {
            .loader = textureAssetLoader,
            .loaderData = @ptrToInt(data),
            .objectType = .Texture
        };
    }

    /// Memory is caller owned
    pub fn init(allocator: *Allocator, original: TextureAssetLoaderData) !Asset {
        var data = try allocator.create(TextureAssetLoaderData);
        data.* = original;
        return Asset {
            .loader = textureAssetLoader,
            .loaderData = @ptrToInt(data),
            .objectType = .Texture
        };
    }

    /// Memory is caller owned
    pub fn initCubemap(allocator: *Allocator, cb: CubemapSettings) !Asset {
        var data = try allocator.create(TextureAssetLoaderData);
        data.cubemap = cb;
        return Asset {
            .loader = textureAssetLoader,
            .loaderData = @ptrToInt(data),
            .objectType = .Texture
        };
    }
};
pub const TextureAssetLoaderData = struct {
    cubemap: ?CubemapSettings = null,
    format: []const u8,
    tiling: zalgebra.vec2 = zalgebra.vec2.new(1, 1)
};

pub const TextureAssetLoaderError = error{InvalidFormat};

fn textureLoadImage(allocator: *Allocator, stream: *AssetStream, format: []const u8) !Image {
    if (std.mem.eql(u8, format, "png")) {
        return try image.png.read(allocator, stream.reader());
    } else if (std.mem.eql(u8, format, "bmp")) {
        return try image.bmp.read(allocator, stream.reader(), stream.seekableStream());
    }
    return TextureAssetLoaderError.InvalidFormat;
}

fn getTextureFormat(format: image.ImageFormat) c.GLuint {
    if (std.meta.eql(format, image.ImageFormat.RGB24)) {
        return c.GL_RGB;
    } else if (std.meta.eql(format, image.ImageFormat.BGR24)) {
        return c.GL_BGR;
    } else if (std.meta.eql(format, image.ImageFormat.RGBA32)) {
        return c.GL_RGBA;
    } else {
        unreachable; // TODO convert the source image to RGB
    }
}

pub fn textureAssetLoader(allocator: *Allocator, dataPtr: usize, stream: *AssetStream) !usize {
    var data = @intToPtr(*TextureAssetLoaderData, dataPtr);
    if (data.cubemap) |cb| {
        const texHeld = windowContextLock();
        var texture = Texture.createEmptyCubemap();
        texHeld.release();

        const targets = [_]c.GLuint {
            c.GL_TEXTURE_CUBE_MAP_POSITIVE_X,
            c.GL_TEXTURE_CUBE_MAP_NEGATIVE_X,
            c.GL_TEXTURE_CUBE_MAP_POSITIVE_Y,
            c.GL_TEXTURE_CUBE_MAP_NEGATIVE_Y,
            c.GL_TEXTURE_CUBE_MAP_POSITIVE_Z,
            c.GL_TEXTURE_CUBE_MAP_NEGATIVE_Z
        };
        const names = [_][]const u8 {"X+", "X-", "Y+", "Y-", "Z+", "Z-"};
        var frames: [6]@Frame(AssetHandle.getPointer) = undefined;
        comptime var i = 0;
        inline for (@typeInfo(CubemapSettings).Struct.fields) |field| {
            const handle = @field(cb, field.name);
            frames[i] = async handle.getPointer(allocator);
            i += 1;
        }

        i = 0;
        inline for (@typeInfo(CubemapSettings).Struct.fields) |field| {
            const ptr = try await frames[i];
            const tex = @intToPtr(*Texture, ptr);
            var tmp = try allocator.alloc(u8, tex.width * tex.height * 3);
            const held = windowContextLock();
            tex.bind();
            c.glGetTexImage(c.GL_TEXTURE_2D, 0, c.GL_RGB, c.GL_UNSIGNED_BYTE, tmp.ptr);
            c.glTexImage2D(targets[i], 0, c.GL_SRGB,
                @intCast(c_int, tex.width), @intCast(c_int, tex.height),
                0, c.GL_RGB, c.GL_UNSIGNED_BYTE, tmp.ptr);
            allocator.free(tmp);
            held.release();
            std.log.scoped(.didot).debug("Loaded cubemap {s}", .{names[i]});
            i += 1;
        }
        var t = try allocator.create(Texture);
        t.* = texture;
        return @ptrToInt(t);
    } else {
        var img = try textureLoadImage(allocator, stream, data.format);
        const held = windowContextLock();
        var texture = Texture.createEmpty2D();
        defer held.release();
        c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_SRGB, @intCast(c_int, img.width), @intCast(c_int, img.height),
            0, getTextureFormat(img.format), c.GL_UNSIGNED_BYTE, &img.data[0]);
        texture.tiling = data.tiling;
        texture.width = img.width;
        texture.height = img.height;
        img.deinit();
        std.log.scoped(.didot).debug("Loaded texture (format={}, size={}x{})", .{img.format, img.width, img.height});
        var t = try allocator.create(Texture);
        t.* = texture;
        return @ptrToInt(t);
    }
}

const objects = @import("../didot-objects/objects.zig"); // hacky hack til i found a way for graphics to depend on objects
const Scene = objects.Scene;
const GameObject = objects.GameObject;
const Camera = objects.Camera;
const AssetManager = objects.AssetManager;
const Asset = objects.Asset;
const AssetStream = objects.AssetStream;
const AssetHandle = objects.AssetHandle;

/// Set this function to replace normal pre-render behaviour (GL state, clear, etc.), it happens after viewport
pub var preRender: ?fn() void = null;
/// Set this function to replace normal viewport behaviour
pub var viewport: ?fn() zalgebra.vec4 = null;

pub fn renderScene(scene: *Scene, window: Window) !void {
    const size = window.getFramebufferSize();
    try renderSceneOffscreen(scene, if (viewport) |func| func() else zalgebra.vec4.new(0, 0, size.x, size.y));
}

var renderHeld: @typeInfo(@TypeOf(std.Thread.Mutex.acquire)).Fn.return_type.? = undefined;

/// Internal method for rendering a game scene.
/// This method is here as it uses graphics API-dependent code (it's the rendering part afterall)
pub fn renderSceneOffscreen(scene: *Scene, vp: zalgebra.vec4) !void {
    renderHeld = windowContextLock();
    defer renderHeld.release();
    c.glViewport(@floatToInt(c_int, @floor(vp.x)), @floatToInt(c_int, @floor(vp.y)),
        @floatToInt(c_int, @floor(vp.z)), @floatToInt(c_int, @floor(vp.w)));
    if (preRender) |func| {
        func();
    } else {
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
        c.glEnable(c.GL_DEPTH_TEST);
        c.glEnable(c.GL_FRAMEBUFFER_SRGB);
        //c.glEnable(c.GL_CULL_FACE);
    }

    var assets = &scene.assetManager;
    if (scene.camera) |cameraObject| {
        const camera = cameraObject.getComponent(Camera).?;
        const projMatrix = switch (camera.projection) {
            .Perspective => |p| zalgebra.mat4.perspective(p.fov, vp.z / vp.w, p.near, p.far),
            .Orthographic => |p| zalgebra.mat4.orthographic(p.left, p.right, p.bottom, p.top, p.near, p.far)
        };

        // create the direction vector to be used with the view matrix.
        const transform = cameraObject.getComponent(objects.Transform).?;
        const euler = transform.rotation.extract_rotation();
        const yaw = zalgebra.to_radians(euler.x);
        const pitch = zalgebra.to_radians(euler.y);
        const direction = zalgebra.vec3.new(
            std.math.cos(yaw) * std.math.cos(pitch),
            std.math.sin(pitch),
            std.math.sin(yaw) * std.math.cos(pitch)
        ).norm();
        const viewMatrix = zalgebra.mat4.look_at(transform.position, transform.position.add(direction), zalgebra.vec3.new(0.0, 1.0, 0.0));
        // const viewMatrix = zalgebra.mat4.from_translate(transform.position)
        //    .mult(transform.rotation.to_mat4());

        //const viewMatrix = zalgebra.mat4.from_translate(transform.position).mult(zalgebra.mat4.identity());

        if (camera.skybox) |*skybox| {
            skybox.shader.bind();
            const view = zalgebra.mat4.identity()
                .mult(zalgebra.mat4.from_euler_angle(viewMatrix.extract_rotation()));
            skybox.shader.setUniformMat4("view", view);
            skybox.shader.setUniformMat4("projection", projMatrix);
            try renderSkybox(skybox, assets, camera);
        }

        camera.shader.bind();
        camera.shader.setUniformMat4("projMatrix", projMatrix);
        camera.shader.setUniformMat4("viewMatrix", viewMatrix);
        if (scene.pointLight) |light| {
            const lightData = light.getComponent(objects.PointLight).?;
            camera.shader.setUniformVec3("light.position", light.getComponent(objects.Transform).?.position);
            camera.shader.setUniformVec3("light.color", lightData.color);
            camera.shader.setUniformFloat("light.constant", lightData.constant);
            camera.shader.setUniformFloat("light.linear", lightData.linear);
            camera.shader.setUniformFloat("light.quadratic", lightData.quadratic);
            camera.shader.setUniformBool("useLight", true);
        } else {
            camera.shader.setUniformBool("useLight", false);
        }
        camera.shader.setUniformVec3("viewPos", transform.position);

        const held = scene.treeLock.acquire();
        for (scene.objects.items) |gameObject| {
            try renderObject(gameObject, assets, camera, zalgebra.mat4.identity());
        }
        held.release();
    }
}

fn renderSkybox(skybox: *objects.Skybox, assets: *AssetManager, camera: *Camera) !void {
    var mesh = try skybox.mesh.get(Mesh, assets.allocator);
    c.glDepthMask(c.GL_FALSE);
    c.glBindVertexArray(mesh.vao);

    renderHeld.release();
    const texture = try skybox.cubemap.get(Texture, assets.allocator);
    renderHeld = windowContextLock();
    c.glBindTexture(c.GL_TEXTURE_CUBE_MAP, texture.id);

    if (mesh.ebo != null) {
        c.glDrawElements(c.GL_TRIANGLES, @intCast(c_int, mesh.elements), c.GL_UNSIGNED_INT, null);
    } else {
        c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(c_int, mesh.vertices));
    }
    c.glDepthMask(c.GL_TRUE);
}

// TODO: remake parent matrix with the new system
fn renderObject(gameObject: *GameObject, assets: *AssetManager, camera: *Camera, parentMatrix: zalgebra.mat4) anyerror!void {
    if (gameObject.getComponent(objects.Transform)) |transform| {
        const matrix = zalgebra.mat4.recompose(transform.position, transform.rotation, transform.scale);
        if (gameObject.mesh) |handle| {
            renderHeld.release();
            const mesh = try handle.get(Mesh, assets.allocator);
            renderHeld = windowContextLock();
            c.glBindVertexArray(mesh.vao);
            const material = gameObject.material;

            if (material.texture) |asset| {
                renderHeld.release();
                const texture = try asset.get(Texture, assets.allocator);
                renderHeld = windowContextLock();
                texture.bind();
                camera.shader.setUniformFloat("xTiling", if (texture.tiling.x == 0) 1 else transform.scale.x / texture.tiling.x);
                camera.shader.setUniformFloat("yTiling", if (texture.tiling.y == 0) 1 else transform.scale.z / texture.tiling.y);
                camera.shader.setUniformBool("useTex", true);
            } else {
                camera.shader.setUniformBool("useTex", false);
            }
            camera.shader.setUniformVec3("material.ambient", material.ambient);
            camera.shader.setUniformVec3("material.diffuse", material.diffuse);
            camera.shader.setUniformVec3("material.specular", material.specular);
            var s: f32 = std.math.clamp(material.shininess, 1.0, 128.0);
            camera.shader.setUniformFloat("material.shininess", s);
            camera.shader.setUniformMat4("modelMatrix", matrix);

            if (mesh.ebo != null) {
                c.glDrawElements(c.GL_TRIANGLES, @intCast(c_int, mesh.elements), c.GL_UNSIGNED_INT, null);
            } else {
                c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(c_int, mesh.vertices));
            }
        }
    }
}

pub usingnamespace @import("didot-window");

comptime {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(ShaderProgram);
    std.testing.refAllDecls(Texture);
}
