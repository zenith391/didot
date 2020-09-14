const c = @import("c.zig");
const std = @import("std");
const zlm = @import("zlm");

pub const ShaderError = error {
    UnknownShaderError,
    InvalidGLContextError
};

/// The type used for meshes's elements
pub const MeshElementType = c.GLuint;

pub const Mesh = struct {
    /// Meshes can be lazily loaded and path is used when a mesh must be loaded
    path: ?[]const u8 = null,
    
    /// Whether the model has been loaded or not.
    loaded: bool = true,

    // OpenGL related variables
    hasVao: bool = false,
    vao: c.GLuint = 0,
    vbo: c.GLuint,
    ebo: c.GLuint,

    /// how many elements this Mesh has
    elements: usize,

    pub fn create(vertices: []f32, elements: []c.GLuint) Mesh {
        var vbo: c.GLuint = 0;
        c.glGenBuffers(1, &vbo);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        std.debug.warn("vbo: {}\n", .{vbo});
        c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(c_long, vertices.len*@sizeOf(f32)), vertices.ptr, c.GL_STATIC_DRAW);
        
        const stride = 5 * @sizeOf(f32);

        var vao: c.GLuint = 0;
        c.glGenVertexArrays(1, &vao);
        c.glBindVertexArray(vao);
        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, stride, 0);
        c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, stride, 3*@sizeOf(f32));
        c.glEnableVertexAttribArray(0);
        c.glEnableVertexAttribArray(1);

        var ebo: c.GLuint = 0;
        c.glGenBuffers(1, &ebo);
        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
        c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @intCast(c_long, elements.len*@sizeOf(c.GLuint)), elements.ptr, c.GL_STATIC_DRAW);

        return Mesh {
            .vao = vao,
            .vbo = vbo,
            .ebo = ebo,
            .elements = elements.len
        };
    }
};

pub const Material = struct {
    texture: ?Texture = null,
    color: ?zlm.Vec3 = null,

    pub const default = Material {};
};

pub const ShaderProgram = struct {
    id: c.GLuint,
    vao: c.GLuint,
    vertex: c.GLuint,
    fragment: c.GLuint,

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
        c.glVertexAttribPointer(@bitCast(c.GLuint, texAttrib), 2, c.GL_FLOAT, c.GL_FALSE, stride, 3*@sizeOf(f32));
        c.glEnableVertexAttribArray(@bitCast(c.GLuint, texAttrib));

        return ShaderProgram {
            .id = shaderProgramId,
            .vao = vao,
            .vertex = vertexShader,
            .fragment = fragmentShader
        };
    }

    /// Set an OpenGL uniform to the following 4x4 matrix.
    pub fn setUniformMat4(self: *ShaderProgram, name: [:0]const u8, mat: zlm.Mat4) void {
        var uniform = c.glGetUniformLocation(self.id, name);

        var m = mat.fields;
        const columns: [16]f32 = .{ // put the matrix in the order OpenGL wants it to be
            m[0][0], m[0][1], m[0][2], m[0][3],
            m[1][0], m[1][1], m[1][2], m[1][3],
            m[2][0], m[2][1], m[2][2], m[2][3],
            m[3][0], m[3][1], m[3][2], m[3][3]
        };
        c.glUniformMatrix4fv(uniform, 1, c.GL_FALSE, &columns[0]);
    }

    /// Set an OpenGL uniform to the following boolean.
    pub fn setUniformBool(self: *ShaderProgram, name: [:0]const u8, val: bool) void {
        var uniform = c.glGetUniformLocation(self.id, name);
        var v: c.GLint = 0;
        if (val) v = 1;
        c.glUniform1i(uniform, v);
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
            std.debug.warn("uncorrect shader: \n", .{});
            var totalSize: usize = @intCast(usize, totalLen);
            std.debug.warn("{}\n", .{buf[0..totalSize]});
            return ShaderError.UnknownShaderError;
        }
    }
};

pub const Image = @import("didot-image").Image;

pub const Texture = struct {
    id: c.GLuint,

    pub fn create(image: Image) Texture {
        var id: c.GLuint = undefined;
        c.glGenTextures(1, &id);
        c.glBindTexture(c.GL_TEXTURE_2D, id);
        c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
        c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA,
            @intCast(c_int, image.width), @intCast(c_int, image.height),
            0, c.GL_RGB, c.GL_UNSIGNED_BYTE, &image.data[0]);
        c.glBindTexture(c.GL_TEXTURE_2D, 0);
        return Texture {
            .id = id
        };
    }

};

const objects = @import("../didot-objects/objects.zig"); // hacky hack til i found a way for graphics to depend on objects
const Scene = objects.Scene;
const GameObject = objects.GameObject;
const Camera = objects.Camera;

// renderScene is here as it uses graphics API-dependent code (it's the rendering part afterall)
pub fn renderScene(scene: *const Scene, window: Window) void {
    const size = window.getFramebufferSize();
    c.glViewport(0, 0, @floatToInt(c_int, @floor(size.x)), @floatToInt(c_int, @floor(size.y)));
    c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
    c.glEnable(c.GL_DEPTH_TEST);
    
    if (scene.camera) |camera| {
        var projMatrix = zlm.Mat4.createPerspective(camera.fov, size.x / size.y, 0.001, 100);
        camera.shader.setUniformMat4("projMatrix", projMatrix);

        // create the direction vector to be used with the view matrix.
        var direction = zlm.Vec3.new(
            @cos(camera.yaw) * @cos(camera.pitch),
            @sin(camera.pitch),
            @sin(camera.yaw) * @cos(camera.pitch)
        );

        var viewMatrix = zlm.Mat4.createLookAt(
            camera.gameObject.position,
            camera.gameObject.position.add(direction),
            zlm.Vec3.new(0.0, 1.0, 0.0)
        );
        camera.shader.setUniformMat4("viewMatrix", viewMatrix);
        c.glBindVertexArray(camera.shader.vao);
        //c.glEnableVertexAttribArray(0);
        //c.glEnableVertexAttribArray(1);

        renderObject(scene.gameObject, camera);
    }
}

fn renderObject(gameObject: GameObject, camera: *Camera) void {
    if (gameObject.mesh) |mesh| {
        //c.glBindBuffer(c.GL_ARRAY_BUFFER, mesh.vbo);
        //c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, mesh.ebo);
        c.glBindVertexArray(mesh.vao);
        std.debug.warn("ebo: {}\n", .{mesh.ebo});
        var material = gameObject.material;

        if (material.texture) |texture| {
            c.glBindTexture(c.GL_TEXTURE_2D, texture.id);
            camera.shader.setUniformBool("useTex", true);
        } else {
            camera.shader.setUniformBool("useTex", false);
            if (material.color) |color| {

            }
        }

        var matrix = zlm.Mat4.createTranslation(gameObject.position);
        camera.shader.setUniformMat4("modelMatrix", matrix);
        c.glDrawElements(c.GL_TRIANGLES, @intCast(c_int, mesh.elements), c.GL_UNSIGNED_INT, null);
    }

    var childs = gameObject.childrens;
    for (childs.items) |child| {
        renderObject(child, camera);
    }
}

pub const WindowError = error {
    InitializationError
};

usingnamespace @import("glfw.zig");
