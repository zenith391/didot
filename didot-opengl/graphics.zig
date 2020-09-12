const c = @import("c.zig");
const std = @import("std");

pub const ShaderError = error {
    UnknownShaderError
};

pub const Mesh = struct {
    /// Meshes are lazily loaded and path is used when mesh must be loaded
    path: []const u8,
    
    /// Whether the model has been loaded or not.
    loaded: bool,

    // OpenGL related variables
    vao: c.GLuint,
    vbo: c.GLuint,
    ebo: c.GLuint
};

pub const ShaderProgram = struct {
    id: c.GLuint,
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

        return ShaderProgram {
            .id = shaderProgramId,
            .vertex = vertexShader,
            .fragment = fragmentShader
        };
    }

    /// Set an OpenGL uniform to the following 4D matrix.
    pub fn setUniformMat4(self: *ShaderProgram, name: [:0]const u8, program: c.GLuint, mat: Mat4) void {
        var uniform = c.glGetUniformLocation(program, name);

        var m = mat.fields;
        const columns: [16]f32 = .{
            m[0][0], m[0][1], m[0][2], m[0][3],
            m[1][0], m[1][1], m[1][2], m[1][3],
            m[2][0], m[2][1], m[2][2], m[2][3],
            m[3][0], m[3][1], m[3][2], m[3][3]
        };
        c.glUniformMatrix4fv(uniform, 1, c.GL_FALSE, &columns[0]);
    }

    pub fn checkError(shader: c.GLuint) ShaderError!void {
        var status: c.GLint = undefined;
        c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &status);
        if (status != c.GL_TRUE) {
            std.debug.warn("uncorrect shader:\n", .{});
            var buf: [512]u8 = undefined;
            var totalLen: c.GLsizei = undefined;
            c.glGetShaderInfoLog(shader, 512, &totalLen, buf[0..]);
            var totalSize: usize = @bitCast(u32, totalLen);
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
        return Texture {
            .id = id
        };
    }

};

pub const WindowError = error {
    InitializationError
};

usingnamespace @import("glfw.zig");
