const c = @import("c.zig");
const std = @import("std");
const zlm = @import("zlm");

pub const ShaderError = error {
    UnknownShaderError
};

pub const Mesh = struct {
    /// Meshes can be lazily loaded and path is used when a mesh must be loaded
    path: ?[]const u8 = null,
    
    /// Whether the model has been loaded or not.
    loaded: bool = true,

    // OpenGL related variables
    vao: c.GLuint,
    vbo: c.GLuint,
    ebo: c.GLuint,

    /// how many elements this Mesh has
    elements: usize,
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

const objects = @import("../didot-objects/objects.zig"); // hacky hack til i found a way for graphics to depend on objects
const Scene = objects.Scene;
const GameObject = objects.GameObject;
const Camera = objects.Camera;

// renderScene is here as it uses graphics API-dependent code (it's the rendering part afterall)
pub fn renderScene(scene: *const Scene, window: Window) void {
    const size = window.getSize();
    c.glViewport(0, 0, @floatToInt(c_int, @floor(size.x)), @floatToInt(c_int, @floor(size.y)));
    c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
    
    if (scene.camera) |camera| {
        var projMatrix = zlm.Mat4.createPerspective(camera.fov, size.x / size.y, 0.001, 100);
        camera.shader.setUniformMat4("projMatrix", projMatrix);

        // create the direction vector to be used with the view matrix.
        var direction = zlm.Vec3.new(
            @cos(camera.yaw) * @cos(camera.pitch),
            @sin(camera.pitch),
            @sin(camera.yaw) * @cos(camera.pitch)
        );

        var viewMatrix = zlm.Mat4.createLook(
            camera.position,
            direction,
            zlm.Vec3.new(0.0, 1.0, 0.0)
        );
        camera.shader.setUniformMat4("viewMatrix", viewMatrix);

        renderObject(scene.gameObject, camera);
    }
}

fn renderObject(gameObject: GameObject, camera: *Camera) void {
    if (gameObject.mesh) |mesh| {
        c.glBindBuffer(c.GL_ARRAY_BUFFER, mesh.vbo);
        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, mesh.ebo);
        camera.shader.setUniformMat4("modelMatrix", gameObject.matrix);
        c.glDrawElements(c.GL_TRIANGLES, @intCast(c_int, mesh.elements), c.GL_UNSIGNED_INT, null);
    }

    var childs = gameObject.childrens;
    for (childs.items) |child| {
        renderObject(child, camera);
    }
}

usingnamespace @import("glfw.zig");
