# Didot 3D Engine

This engine made for Zig is aimed at high-level constructs, you manipulate game objects and meshes instead of OpenGL calls and batches.

That combined with the fact the engine is in multiple packages, this means that changing the graphics module to something else is easy,
just need to for example use `didot-vulkan` (while it is planned, there is currently no Vulkan backend) instead of `didot-opengl` to use Vulkan. And since they share the same API, absolutely zero porting is necessary (as Vulkan can use a GLSL compiler, however it might not be 100% true for other backends)!

## Examples

Cube:
```zig
const std = @import("std");
const zlm = @import("zlm");
const Vec3 = zlm.Vec3;

const graphics = @import("didot-graphics");
const objects = @import("didot-objects");
const Application = @import("didot-app").Application;

const Texture = graphics.Texture;
const Window = graphics.Window;
const ShaderProgram = graphics.ShaderProgram;

const GameObject = objects.GameObject;
const Scene = objects.Scene;
const Camera = objects.Camera;

pub fn main() !void {

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var scene = try Scene.create(allocator);

    var app = Application {};
    try app.init(scene);

    var shader = try ShaderProgram.create(@embedFile("vert.glsl"), @embedFile("frag.glsl"));

    var camera = try Camera.create(allocator, shader);
    camera.gameObject.position = Vec3.new(1.5, 1.5, -0.5);
    camera.pitch = zlm.toRadians(-15.0);
    camera.yaw = zlm.toRadians(-120.0);
    try scene.add(camera.gameObject);

    var plane = GameObject.createObject(allocator, objects.PrimitiveCubeMesh);
    plane.position = Vec3.new(0, 0.75, -3);
    try scene.add(plane);

    app.loop();
}

```
That is where you can see it's not 100% true that zero porting is necessary, if you use some other backend that doesn't accept GLSL, you'll have to rewrite the shaders.

It's done this way because making a universal shader language is hard and would also bloat the engine.

And to make that into a textured cube, only a few lines are necessary:
```zig
var img = try bmp.read_bmp(allocator, "grass.bmp");
var tex = Texture.create(img);
var material = Material {
    .texture = tex
};
plane.material = material;
```

## How to use

Just add this to your build script:
```
const engine = @import("path/to/engine/build.zig");

pub fn build(b: *Builder) {
    // your code ...
    addEngineToExe(exe);
    // more code ...
}
```
Where `exe` is a `LibExeObjStep` (made by `b.addExecutable`).

And now Didot is ready for use!
