# Didot 3D Engine

This engine made for Zig is aimed at high-level constructs, you manipulate game objects and meshes instead of OpenGL calls and batches.

That combined with the fact the engine is in multiple packages, this means that changing the graphics module to something else is easy,
just need to for example use `didot-vulkan` (while it is planned, there is currently no Vulkan backend) instead of `didot-opengl` to use Vulkan. And since they share the same API, absolutely zero porting is necessary (as Vulkan can use a GLSL compiler, however it might not be 100% true for other backends)!

## Examples

Cube:
```zig
const std = @import("std");

const graphics = @import("didot-graphics");
const objects = @import("didot-objects");

const Texture = graphics.Texture;
const Window = graphics.Window;
const ShaderProgram = graphics.ShaderProgram;

const Scene = objects.Scene;
const Camera = objects.Camera;

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
```
That is where you can see it's not 100% true that zero porting is necessary, if you use some other backend that doesn't accept GLSL, you'll have to rewrite the shaders.

It's done this way because making a universal shader language is hard and would also bloat the engine.
