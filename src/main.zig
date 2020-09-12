const std = @import("std");
const zlm = @import("zlm");

const graphics = @import("didot-graphics");
//const image = @import("didot-image");
const objects = @import("didot-objects");

//const bmp = image.bmp;

const Texture = graphics.Texture;
const Window = graphics.Window;
const ShaderProgram = graphics.ShaderProgram;

const Scene = objects.Scene;
const Camera = objects.Camera;

const warn = std.debug.warn;

// OpenGL and GLFW code
pub fn main() !void {
    var window = try Window.create();
    var shaderProgram = try ShaderProgram.create(@embedFile("vert.glsl"), @embedFile("frag.glsl"));

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var scene = try Scene.create(allocator);
    var camera = try Camera.create(allocator);
    try scene.add(camera.gameObject);

    while (window.update()) {
        scene.render(window);
    }
}
