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
    var window = try Window.create();
    shaderProgram = try ShaderProgram.create(@embedFile("vert.glsl"), @embedFile("frag.glsl"));

    while (window.update()) {
        
    }
}
