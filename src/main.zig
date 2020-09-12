const std = @import("std");
const zlm = @import("zlm");

const graphics = @import("didot-graphics");
const image = @import("didot-image");
const bmp = image.bmp;
const Texture = graphics.Texture;
const Window = graphics.Window;
const ShaderProgram = graphics.ShaderProgram;

const Real = f32;
const math = zlm.specializeOn(Real);
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;

const c = @import("c.zig");
const Allocator = std.mem.Allocator;
const warn = std.debug.warn;

const WIDTH = 800.0;
const HEIGHT = 600.0;

/// Check for an error after compiling an OpenGL shader
fn checkError(shader: c.GLuint) void {
    var status: c.GLint = undefined;
    c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &status);
    if (status != c.GL_TRUE) {
        warn("uncorrect shader:\n", .{});
        var buf: [512]u8 = undefined;
        var totalLen: c.GLsizei = undefined;
        c.glGetShaderInfoLog(shader, 512, &totalLen, buf[0..]);
        var totalSize: usize = @bitCast(u32, totalLen);
        warn("{}\n", .{buf[0..totalSize]});
    }
}

/// Set an OpenGL uniform to the following 4D matrix.
fn setUniformMat4(name: [:0]const u8, program: c.GLuint, mat: Mat4) void {
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

const Mesh = struct {
    vao: c.GLuint,
    vbo: c.GLuint,
    ebo: c.GLuint
};

const Camera = struct {
    fov: Real,
    position: Vec3,
    yaw: Real = zlm.toRadians(-90.0),
    pitch: Real = 0
};

var camera: Camera = undefined;
var terrainMesh: Mesh = undefined;
var shaderProgram: ShaderProgram = undefined;

fn render(window: *c.GLFWwindow) void {
    // get the framebuffer size and set viewport
    var width: i32 = 0;
    var height: i32 = 0;
    c.glfwGetFramebufferSize(window, &width, &height);
    c.glViewport(0, 0, width, height);

    // set the projection matrix
    var projMatrix = Mat4.createPerspective(camera.fov, @intToFloat(f32, width) / @intToFloat(f32, height), 0.001, 100);
    setUniformMat4("projMatrix", shaderProgram.id, projMatrix);

    // create the direction vector to be used with the view matrix.
    var direction = Vec3.new(
        @cos(camera.yaw) * @cos(camera.pitch),
        @sin(camera.pitch),
        @sin(camera.yaw) * @cos(camera.pitch)
    );
    var viewMatrix = Mat4.createLookAt(
        camera.position,
        camera.position.add(direction),
        Vec3.new(0.0, 1.0, 0.0)
    );
    setUniformMat4("viewMatrix", shaderProgram.id, viewMatrix);

    c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
    c.glBindVertexArray(terrainMesh.vbo);
    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, terrainMesh.ebo);

    // create a new model matrix for the position at Y zero.
    var modelMatrix = Mat4.createTranslationXYZ(0, 0, 0);
    setUniformMat4("modelMatrix", shaderProgram.id, modelMatrix);
    c.glDrawElements(c.GL_TRIANGLES, @intCast(c_int, 6*HMWIDTH*HMHEIGHT), c.GL_UNSIGNED_INT, null);
    //c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(c_int, HMWIDTH*HMHEIGHT));
}

fn input(window: *c.GLFWwindow) void {
    const cameraSpeed: Real = 0.05;
    var direction = Vec3.new(
        @cos(camera.yaw) * cameraSpeed,
        0,
        @sin(camera.yaw) * cameraSpeed
    );
    if (c.glfwGetKey(window, c.GLFW_KEY_W) == c.GLFW_PRESS) {
        camera.position = camera.position.add(direction);
    }
    if (c.glfwGetKey(window, c.GLFW_KEY_S) == c.GLFW_PRESS) {
        camera.position = camera.position.sub(direction);
    }
    if (c.glfwGetKey(window, c.GLFW_KEY_A) == c.GLFW_PRESS) {
        camera.position = camera.position.add(Vec3.new(
            -cameraSpeed * @sin(camera.yaw),
            0,
            cameraSpeed * @cos(camera.yaw)
        ));
    }
    if (c.glfwGetKey(window, c.GLFW_KEY_D) == c.GLFW_PRESS) {
        camera.position = camera.position.add(Vec3.new(
            cameraSpeed * @sin(camera.yaw),
            0,
            -cameraSpeed * @cos(camera.yaw)
        ));
    }

    if (c.glfwGetKey(window, c.GLFW_KEY_ESCAPE) == c.GLFW_PRESS and mouseGrabbed) {
        mouseGrabbed = false;
        c.glfwSetInputMode(window, c.GLFW_CURSOR, c.GLFW_CURSOR_NORMAL);
    }

    if (c.glfwGetKey(window, c.GLFW_KEY_SPACE) == c.GLFW_PRESS) {
        camera.position.y += cameraSpeed;
    }
    if (c.glfwGetKey(window, c.GLFW_KEY_LEFT_SHIFT) == c.GLFW_PRESS) {
        camera.position.y -= cameraSpeed;
    }
}

var lastX: f64 = WIDTH / 2.0;
var lastY: f64 = HEIGHT / 2.0;
var mouseGrabbed = false;

// heightmap size
var HMWIDTH: usize = undefined;
var HMHEIGHT: usize = undefined;

export fn mouse_callback(window: ?*c.GLFWwindow, xpos: f64, ypos: f64) void {
    if (mouseGrabbed) {
        const sensitivity = 0.1;

        var xOff = (xpos - lastX) * sensitivity;
        var yOff = (ypos - lastY) * sensitivity;
        lastX = xpos;
        lastY = ypos;

        camera.yaw -= @floatCast(Real, zlm.toRadians(xOff));
        camera.pitch -= @floatCast(Real, zlm.toRadians(yOff));
        if (camera.pitch < zlm.toRadians(-89.0)) camera.pitch = zlm.toRadians(-89.0);
    }
}

export fn mouse_button_callback(window: ?*c.GLFWwindow, button: c_int, action: c_int, mods: c_int) void {
    if (button == c.GLFW_MOUSE_BUTTON_LEFT and action == c.GLFW_PRESS and !mouseGrabbed) {
        mouseGrabbed = true;
        c.glfwSetInputMode(window, c.GLFW_CURSOR, c.GLFW_CURSOR_DISABLED);
    }
}



// OpenGL and GLFW code
pub fn main() !void {
    if (c.glfwInit() != 1) {
        warn("Could not init GLFW!\n", .{});
        return;
    }
    defer c.glfwTerminate();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator: *Allocator = &arena.allocator;

    var img = bmp.read_bmp(allocator, "grass.bmp") catch |err| {
        std.debug.warn("error while loading grass.bmp: {}\n", .{err});
        return;
    };

    var heightImg = bmp.read_bmp(allocator, "heightmap.bmp") catch |err| {
        std.debug.warn("error while loading heightmap.bmp: {}\n", .{err});
        return;
    };

    var window = try Window.create();

    //_ = graphics.glfwSetCursorPosCallback(window.nativeId, mouse_callback);
    //_ = graphics.glfwSetMouseButtonCallback(window.nativeId, mouse_button_callback);

    var vert: [:0]const u8 = @embedFile("vert.glsl");
    var frag: [:0]const u8 = @embedFile("frag.glsl");

    const sqLen = 0.5;

    var heightmap = try allocator.alloc([]f32, @intCast(usize, heightImg.height));
    var i: usize = 0;
    var j: usize = 0;
    while (i < heightmap.len) {
        heightmap[i] = try allocator.alloc(f32, @intCast(usize, heightImg.width));
        j = 0;
        while (j < heightImg.width) {
            heightmap[i][j] = @intToFloat(f32, heightImg.data[(i*heightmap[i].len+j)*3]) / 255.0 * sqLen*100;
            j += 1;
        }
        i += 1;
    }

    allocator.free(heightImg.data);

    // heightmap width and height
    HMWIDTH = heightmap.len;
    HMHEIGHT = heightmap[0].len;

    var vertices = try allocator.alloc(f32, HMWIDTH*HMHEIGHT*(4*5)); // width*height*vertices*vertex size
    var elements = try allocator.alloc(c.GLuint, heightmap.len*HMHEIGHT*6);

    for (heightmap) |row, row_index| {
        for (row) |cell, column_index| {
            var pos: usize = (row_index*HMHEIGHT+column_index)*(5*4);
            var x: f32 = @intToFloat(f32, column_index)*sqLen*2;
            var z: f32 = @intToFloat(f32, row_index)*sqLen*2;

            var trY: f32 = 0.0;
            var blY: f32 = 0.0;
            var brY: f32 = 0.0;
            if (column_index < HMHEIGHT-1) trY = row[column_index+1];
            if (row_index > 0) blY = heightmap[row_index-1][column_index];
            if (row_index > 0 and column_index < HMWIDTH-1) brY = heightmap[row_index-1][column_index+1];

            vertices[pos] = x-sqLen; vertices[pos+1] = cell; vertices[pos+2] = z+sqLen; vertices[pos+3] = 0.0; vertices[pos+4] = 0.0; // top-left
            vertices[pos+5] = x-sqLen; vertices[pos+6] = blY; vertices[pos+7] = z-sqLen; vertices[pos+8] = 0.0; vertices[pos+9] = 1.0; // bottom-left
            vertices[pos+10] = x+sqLen; vertices[pos+11] = brY; vertices[pos+12] = z-sqLen; vertices[pos+13] = 1.0; vertices[pos+14] = 1.0; // bottom-right
            vertices[pos+15] = x+sqLen; vertices[pos+16] = trY; vertices[pos+17] = z+sqLen; vertices[pos+18] = 1.0; vertices[pos+19] = 0.0; // top-right

            var vecPos: c.GLuint = @intCast(c.GLuint, (row_index*heightmap[0].len+column_index)*4);
            var elemPos: usize = (row_index*HMHEIGHT+column_index)*6;
            elements[elemPos] = vecPos;
            elements[elemPos+1] = vecPos+1;
            elements[elemPos+2] = vecPos+2;
            elements[elemPos+3] = vecPos;
            elements[elemPos+4] = vecPos+3;
            elements[elemPos+5] = vecPos+2;
        }
    }

    var vbo: c.GLuint = 0;
    c.glGenBuffers(1, &vbo);
    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(c_long, vertices.len*@sizeOf(f32)), vertices.ptr, c.GL_STATIC_DRAW);

    var vao: c.GLuint = 0;
    c.glGenVertexArrays(1, &vao);
    c.glBindVertexArray(vbo);

    var ebo: c.GLuint = 0;
    c.glGenBuffers(1, &ebo);
    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
    c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @intCast(c_long, elements.len*@sizeOf(c.GLuint)), elements.ptr, c.GL_STATIC_DRAW);

    allocator.free(vertices);
    allocator.free(elements);
    allocator.free(heightmap);

    terrainMesh = .{
        .vao = vao,
        .vbo = vbo,
        .ebo = ebo
    };

    camera = .{
        .fov = 70,
        .position = Vec3.new(0, 4.3, 1.2)
    };

    shaderProgram = try ShaderProgram.create(vert, frag);

    const stride = 5 * @sizeOf(f32);
    const posAttrib = c.glGetAttribLocation(shaderProgram.id, "position");
    c.glVertexAttribPointer(@bitCast(c.GLuint, posAttrib), 3, c.GL_FLOAT, c.GL_FALSE, stride, 0);
    c.glEnableVertexAttribArray(@bitCast(c.GLuint, posAttrib));

    const texAttrib = c.glGetAttribLocation(shaderProgram.id, "texcoord");
    c.glVertexAttribPointer(@bitCast(c.GLuint, texAttrib), 2, c.GL_FLOAT, c.GL_FALSE, stride, 3*@sizeOf(f32));
    c.glEnableVertexAttribArray(@bitCast(c.GLuint, texAttrib));

    var tex = Texture.create(img);
    arena.deinit(); // free the memory allocated for initialization (textures and heightmap)

    c.glEnable(c.GL_DEPTH_TEST);

    while (window.update()) {
        //render(window);
        //input(window);
    }
}
