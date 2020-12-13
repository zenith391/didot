const c = @import("c.zig");
const std = @import("std");
const zlm = @import("zlm");
const Thread = std.Thread;
const Allocator = std.mem.Allocator;

pub const ShaderError = error{ ShaderCompileError, InvalidGLContextError };

/// The type used for meshes's elements
pub const MeshElementType = c.GLuint;

pub const Mesh = struct {
    // OpenGL related variables
    hasVao: bool = false,
    hasEbo: bool = true,
    vao: c.GLuint = 0,
    vbo: c.GLuint,
    ebo: c.GLuint,

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
        var elementsSize: usize = 0;
        if (elements) |elem| {
            c.glGenBuffers(1, &ebo);
            c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
            c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @intCast(c_long, elem.len * @sizeOf(c.GLuint)), elem.ptr, c.GL_STATIC_DRAW);
            elementsSize = elem.len;
        }

        return Mesh{
            .vao = vao,
            .vbo = vbo,
            .ebo = ebo,
            .elements = elementsSize,
            .vertices = vertices.len,
            .hasEbo = elements != null,
        };
    }
};

/// Color defined to be a 3 component vector
/// X value is red, Y value is blue and Z value is green.
pub const Color = zlm.Vec3;

pub const Material = struct {
    texturePath: ?[]const u8 = null,
    ambient: Color = Color.zero,
    diffuse: Color = Color.one,
    specular: Color = Color.one,
    shininess: f32 = 32.0,

    pub const default = Material{};
};

pub const ShaderProgram = struct {
    id: c.GLuint,
    vao: c.GLuint,
    vertex: c.GLuint,
    fragment: c.GLuint,

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

        return try ShaderProgram.create(nullVert, nullFrag);
    }

    pub fn create(vert: [:0]const u8, frag: [:0]const u8) ShaderError!ShaderProgram {
        const vertexShader = c.glCreateShader(c.GL_VERTEX_SHADER);
        var v = vert;
        c.glShaderSource(vertexShader, 1, &v, null);
        c.glCompileShader(vertexShader);
        try checkError(vertexShader);

        const fragmentShader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
        var f = frag;
        c.glShaderSource(fragmentShader, 1, &f, null);
        c.glCompileShader(fragmentShader);
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

        return ShaderProgram{
            .id = shaderProgramId,
            .vao = vao,
            .vertex = vertexShader,
            .fragment = fragmentShader,
        };
    }

    pub inline fn bind(self: *const ShaderProgram) void {
        c.glUseProgram(self.id);
    }

    /// Set an OpenGL uniform to the following 4x4 matrix.
    pub fn setUniformMat4(self: *const ShaderProgram, name: [:0]const u8, mat: zlm.Mat4) void {
        var uniform = c.glGetUniformLocation(self.id, name);

        var m = mat.fields;
        const columns: [16]f32 = .{ // put the matrix in the order OpenGL wants it to be
            m[0][0], m[0][1], m[0][2], m[0][3],
            m[1][0], m[1][1], m[1][2], m[1][3],
            m[2][0], m[2][1], m[2][2], m[2][3],
            m[3][0], m[3][1], m[3][2], m[3][3],
        };
        c.glUniformMatrix4fv(uniform, 1, c.GL_FALSE, &columns[0]);
    }

    /// Set an OpenGL uniform to the following boolean.
    pub fn setUniformBool(self: *ShaderProgram, name: [:0]const u8, val: bool) void {
        var uniform = c.glGetUniformLocation(self.id, name);
        var v: c.GLint = if (val) 1 else 0;
        c.glUniform1i(uniform, v);
    }

    /// Set an OpenGL uniform to the following float.
    pub fn setUniformFloat(self: *ShaderProgram, name: [:0]const u8, val: f32) void {
        var uniform = c.glGetUniformLocation(self.id, name);
        c.glUniform1f(uniform, val);
    }

    /// Set an OpenGL uniform to the following 3D float vector.
    pub fn setUniformVec3(self: *ShaderProgram, name: [:0]const u8, vec: zlm.Vec3) void {
        var uniform = c.glGetUniformLocation(self.id, name);
        c.glUniform3f(uniform, vec.x, vec.y, vec.z);
    }

    pub fn checkError(shader: c.GLuint) ShaderError!void {
        var status: c.GLint = undefined;
        c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &status);
        if (status != c.GL_TRUE) {
            var buf: [2048]u8 = undefined;
            var totalLen: c.GLsizei = -1;
            c.glGetShaderInfoLog(shader, 2048, &totalLen, buf[0..]);
            if (totalLen == -1) {
                // the length of the infolog seems to not be set
                // when a GL context isn't set (so when the window isn't created)
                return ShaderError.InvalidGLContextError;
            }
            var totalSize: usize = @intCast(usize, totalLen);
            std.log.scoped(.didot).alert("shader compilation errror:\n{}", .{buf[0..totalSize]});
            return ShaderError.ShaderCompileError;
        }
    }
};

const image = @import("didot-image");
const Image = image.Image;

pub const CubemapSettings = struct {
    right: []const u8, left: []const u8, top: []const u8, bottom: []const u8, front: []const u8, back: []const u8
};

pub const Texture = struct {
    id: c.GLuint,
    tiling: zlm.Vec2 = zlm.Vec2.new(1, 1),

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

    pub inline fn bind(self: *const Texture) void {
        c.glBindTexture(c.GL_TEXTURE_2D, self.id);
    }

    pub fn deinit(self: *const Texture) void {
        c.glDeleteTextures(1, &self.id);
    }
};

// Image asset loader
pub const TextureAssetLoaderData = struct {
    path: ?[]const u8 = null,
    cubemap: ?CubemapSettings = null,
    format: []const u8,
    tiling: zlm.Vec2 = zlm.Vec2.new(1, 1),

    /// Memory is caller owned
    pub fn init2D(allocator: *Allocator, path: []const u8, format: []const u8) !usize {
        var data = try allocator.create(TextureAssetLoaderData);
        data.path = path;
        data.cubemap = null;
        data.format = format;
        return @ptrToInt(data);
    }

    /// Memory is caller owned
    pub fn init(allocator: *Allocator, original: TextureAssetLoaderData) !usize {
        var data = try allocator.create(TextureAssetLoaderData);
        data.* = original;
        return @ptrToInt(data);
    }

    /// Memory is caller owned
    pub fn initCubemap(allocator: *Allocator, cb: CubemapSettings, format: []const u8) !usize {
        var data = try allocator.create(TextureAssetLoaderData);
        data.path = null;
        data.cubemap = cb;
        data.format = format;
        return @ptrToInt(data);
    }
};

pub const TextureAssetLoaderError = error{InvalidFormat};

fn textureLoadImage(allocator: *Allocator, path: []const u8, format: []const u8) !Image {
    if (std.mem.eql(u8, format, "png")) {
        return try image.png.read(allocator, path);
    } else if (std.mem.eql(u8, format, "bmp")) {
        return try image.bmp.read(allocator, path);
    } else {
        return TextureAssetLoaderError.InvalidFormat;
    }
}

// struct used to pass data between main thread and worker threads
const CubemapThreadStruct = struct {
    allocator: *Allocator, path: []const u8, format: []const u8, image: Image
};

fn cubemapThread(data: *CubemapThreadStruct) !void {
    data.image = try textureLoadImage(data.allocator, data.path, data.format);
}

inline fn getTextureFormat(format: image.ImageFormat) c.GLuint {
    if (format.redMask == 0xFF0000 and format.greenMask == 0xFF00 and format.blueMask == 0xFF and format.bitsSize == 24) {
        return c.GL_RGB;
    } else if (format.redMask == 0xFF and format.greenMask == 0xFF00 and format.blueMask == 0xFF0000 and format.bitsSize == 24) {
        return c.GL_BGR;
    } else if (format.redMask == 0xFF000000 and format.greenMask == 0xFF0000 and format.blueMask == 0xFF00 and format.alphaMask == 0xFF) {
        return c.GL_RGBA;
    } else {
        unreachable; // TODO convert the source image to RGB
    }
}

pub fn textureAssetLoader(allocator: *Allocator, dataPtr: usize) !usize {
    var data = @intToPtr(*TextureAssetLoaderData, dataPtr);
    if (data.cubemap) |cb| {
        var texture = Texture.createEmptyCubemap();
        const targets = [_]c.GLuint {
            c.GL_TEXTURE_CUBE_MAP_POSITIVE_X,
            c.GL_TEXTURE_CUBE_MAP_NEGATIVE_X,
            c.GL_TEXTURE_CUBE_MAP_POSITIVE_Y,
            c.GL_TEXTURE_CUBE_MAP_NEGATIVE_Y,
            c.GL_TEXTURE_CUBE_MAP_POSITIVE_Z,
            c.GL_TEXTURE_CUBE_MAP_NEGATIVE_Z,
        };

        if (@import("builtin").single_threaded) {
            comptime var i = 0;

            inline for (@typeInfo(CubemapSettings).Struct.fields) |field| {
                const path = @field(cb, field.name);
                const img = try textureLoadImage(allocator, path, data.format);
                c.glTexImage2D(targets[i], 0, c.GL_SRGB,
                    @intCast(c_int, img.width), @intCast(c_int, img.height),
                    0, getTextureFormat(img.format), c.GL_UNSIGNED_BYTE, &img.data[0]);
                img.deinit();
                i += 1;
            }
        } else {
            var structs: [6]CubemapThreadStruct = undefined;
            var threads: [6]*Thread = undefined;
            comptime var i = 0;

            // start loading the textures
            inline for (@typeInfo(CubemapSettings).Struct.fields) |field| {
                const path = @field(cb, field.name);
                structs[i] = .{
                    .allocator = allocator,
                    .path = path,
                    .format = data.format,
                    .image = undefined
                };
                threads[i] = try Thread.spawn(&structs[i], cubemapThread);
                i += 1;
            }

            // retrieve them
            var j: usize = 0;
            while (j < 6) : (j += 1) {
                threads[j].wait();
                const img = structs[j].image;
                c.glTexImage2D(targets[j], 0, c.GL_SRGB,
                    @intCast(c_int, img.width), @intCast(c_int, img.height),
                    0, getTextureFormat(img.format), c.GL_UNSIGNED_BYTE, &img.data[0]);
                img.deinit();
            }
        }
        var t = try allocator.create(Texture);
        t.* = texture;
        return @ptrToInt(t);
    } else if (data.path) |path| {
        var texture = Texture.createEmpty2D();

        var img = try textureLoadImage(allocator, path, data.format);
        c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_SRGB, @intCast(c_int, img.width), @intCast(c_int, img.height),
            0, getTextureFormat(img.format), c.GL_UNSIGNED_BYTE, &img.data[0]);
        texture.tiling = data.tiling;
        img.deinit();
        var t = try allocator.create(Texture);
        t.* = texture;
        return @ptrToInt(t);
    } else {
        return TextureAssetLoaderError.InvalidFormat;
    }
}

const objects = @import("../didot-objects/objects.zig"); // hacky hack til i found a way for graphics to depend on objects
const Scene = objects.Scene;
const GameObject = objects.GameObject;
const Camera = objects.Camera;
const AssetManager = objects.AssetManager;

/// Set this function to replace normal pre-render behaviour (GL state, clear, etc.), it happens after viewport
pub var preRender: ?fn() void = null;
/// Set this function to replace normal viewport behaviour
pub var viewport: ?fn() zlm.Vec4 = null;

pub fn renderScene(scene: *Scene, window: Window) !void {
    const size = window.getFramebufferSize();
    try renderSceneOffscreen(scene, if (viewport) |func| func() else zlm.vec4(0, 0, size.x, size.y));
}

/// Internal method for rendering a game scene.
/// This method is here as it uses graphics API-dependent code (it's the rendering part afterall)
pub fn renderSceneOffscreen(scene: *Scene, vp: zlm.Vec4) !void {
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
    if (scene.camera) |camera| {
        var projMatrix = zlm.Mat4.createPerspective(camera.fov, vp.z / vp.w, 0.1, 1000);
        camera.shader.setUniformMat4("projMatrix", projMatrix);

        // create the direction vector to be used with the view matrix.
        const yaw = camera.gameObject.rotation.x;
        const pitch = camera.gameObject.rotation.y;
        const direction = zlm.Vec3.new(std.math.cos(yaw) * std.math.cos(pitch), std.math.sin(pitch), std.math.sin(yaw) * std.math.cos(pitch));
        const viewMatrix = zlm.Mat4.createLookAt(camera.gameObject.position, camera.gameObject.position.add(direction), zlm.Vec3.new(0.0, 1.0, 0.0));
        if (scene.skybox) |skybox| {
            if (camera.skyboxShader) |skyboxShader| {
                skyboxShader.bind();
                const view = viewMatrix.toMat3().toMat4();
                skyboxShader.setUniformMat4("view", view);
                skyboxShader.setUniformMat4("projection", projMatrix);
                try renderSkybox(skybox, assets, camera);
            }
        }

        camera.shader.bind();
        camera.shader.setUniformMat4("viewMatrix", viewMatrix);
        if (scene.pointLight) |light| {
            camera.shader.setUniformVec3("light.position", light.gameObject.position);
            camera.shader.setUniformVec3("light.color", light.color);
            camera.shader.setUniformFloat("light.constant", light.constant);
            camera.shader.setUniformFloat("light.linear", light.linear);
            camera.shader.setUniformFloat("light.quadratic", light.quadratic);
            camera.shader.setUniformBool("useLight", true);
        } else {
            camera.shader.setUniformBool("useLight", false);
        }
        camera.shader.setUniformVec3("viewPos", camera.gameObject.position);
        try renderObject(&scene.gameObject, assets, camera);
    }
}

fn renderSkybox(skybox: *GameObject, assets: *AssetManager, camera: *Camera) !void {
    if (skybox.meshPath) |meshPath| {
        var mesh = @intToPtr(*Mesh, (try assets.getExpected(meshPath, .Mesh)).?);
        c.glDepthMask(c.GL_FALSE);
        c.glBindVertexArray(mesh.vao);
        const material = &skybox.material;

        if (material.texturePath) |path| {
            const texture = @intToPtr(*Texture, (try assets.getExpected(path, .Texture)).?);
            c.glBindTexture(c.GL_TEXTURE_CUBE_MAP, texture.id);
        }

        if (mesh.hasEbo) {
            c.glDrawElements(c.GL_TRIANGLES, @intCast(c_int, mesh.elements), c.GL_UNSIGNED_INT, null);
        } else {
            c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(c_int, mesh.vertices));
        }
        c.glDepthMask(c.GL_TRUE);
    }
}

fn renderObject(gameObject: *GameObject, assets: *AssetManager, camera: *Camera) anyerror!void {
    if (gameObject.objectType) |custom| {
        if (std.mem.eql(u8, custom, "skybox")) {
            return; // don't render skybox here
        }
    }
    if (gameObject.meshPath) |meshPath| {
        var mesh = @intToPtr(*Mesh, (try assets.getExpected(meshPath, .Mesh)).?);
        c.glBindVertexArray(mesh.vao);
        var material = &gameObject.material;

        if (material.texturePath) |path| {
            const texture = @intToPtr(*Texture, (try assets.getExpected(path, .Texture)).?);
            texture.bind();
            camera.shader.setUniformFloat("xTiling", if (texture.tiling.x == 0) 1 else gameObject.scale.x / texture.tiling.x);
            camera.shader.setUniformFloat("yTiling", if (texture.tiling.y == 0) 1 else gameObject.scale.z / texture.tiling.y);
            camera.shader.setUniformBool("useTex", true);
        } else {
            camera.shader.setUniformBool("useTex", false);
        }
        camera.shader.setUniformVec3("material.ambient", material.ambient);
        camera.shader.setUniformVec3("material.diffuse", material.diffuse);
        camera.shader.setUniformVec3("material.specular", material.specular);
        var s: f32 = std.math.clamp(material.shininess, 1.0, 128.0);
        camera.shader.setUniformFloat("material.shininess", s);
        const rotMatrix = 
            zlm.Mat4.createAngleAxis(zlm.Vec3.new(0, 0, 1), gameObject.rotation.x).mul(
            zlm.Mat4.createAngleAxis(zlm.Vec3.new(0, 1, 0), gameObject.rotation.y).mul(
            zlm.Mat4.createAngleAxis(zlm.Vec3.new(1, 0, 0), gameObject.rotation.z)));
        const matrix = rotMatrix.mul(zlm.Mat4.createScale(gameObject.scale).mul(zlm.Mat4.createTranslation(gameObject.position)));
        camera.shader.setUniformMat4("modelMatrix", matrix);

        if (mesh.hasEbo) {
            c.glDrawElements(c.GL_TRIANGLES, @intCast(c_int, mesh.elements), c.GL_UNSIGNED_INT, null);
        } else {
            c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(c_int, mesh.vertices));
        }
    }

    const held = gameObject.treeLock.acquire();
    var childs = gameObject.childrens.items;
    for (childs) |*child| {
        try renderObject(child, assets, camera);
    }
    held.release();
}

usingnamespace @import("didot-window");

comptime {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(ShaderProgram);
    std.testing.refAllDecls(Texture);
}
