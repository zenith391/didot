# Didot 3D Engine

![A kart and 2 cubes rendering with Didot](https://raw.githubusercontent.com/zenith391/didot/master/examples/kart-and-cubes.png)

This engine made for Zig is aimed at high-level constructs, you manipulate game objects and meshes instead of OpenGL calls and batches and you have multi-threading.

That combined with the fact the engine is in multiple packages, this means that changing the graphics module to something else is easy,
just need to for example use `didot-vulkan` (while it is planned, there is currently no Vulkan backend) instead of `didot-opengl` to use Vulkan. And since they share the same API, absolutely zero porting is necessary (as Vulkan can use a GLSL compiler, however it might not be 100% true for other backends)!

[API reference](https://zenith391.github.io/didot/#root)

## Examples

Cube:
```zig
const std = @import("std");
const zlm = @import("zlm");
const Vec3 = zlm.Vec3;
const Allocator = std.mem.Allocator;

const graphics = @import("didot-graphics");
const objects = @import("didot-objects");
const Application = @import("didot-app").Application;

const Window = graphics.Window;
const ShaderProgram = graphics.ShaderProgram;

const GameObject = objects.GameObject;
const Scene = objects.Scene;
const Camera = objects.Camera;

fn init(allocator: *Allocator, app: *Application) !void {
    win = app.window;
    var shader = try ShaderProgram.create(@embedFile("vert.glsl"), @embedFile("frag.glsl"));
    const scene = app.scene;

    var camera = try Camera.create(allocator, shader);
    camera.gameObject.position = Vec3.new(1.5, 1.5, -0.5);
    camera.gameObject.rotation = Vec3.new(-120.0, -15.0, 0).toRadians();
    try scene.add(camera.gameObject);

    var cube = GameObject.createObject(allocator, objects.PrimitiveCubeMesh);
    cube.position = Vec3.new(-1.2, 0.75, -3);
    try scene.add(cube);
}

pub fn main() !void {
    var gp = std.heap.GeneralPurposeAllocator(.{}) {};
    const allocator = &gp.allocator;

    var scene = try Scene.create(allocator);

    var app = Application {
        .title = "Test Cube",
        .initFn = init
    };
    try app.start(allocator, scene);
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

You can also look at the [kart and cubes example](https://github.com/zenith391/didot/blob/master/examples/kart-and-cubes/example-scene.zig) to see how to make camera movement or load models from OBJ files.

## How to use

Just add this to your build script:
```zig
const engine = @import("path/to/engine/build.zig");

pub fn build(b: *Builder) {
    // your code ...
    engine.addEngineToExe(exe);
    // more code ...
}
```
Where `exe` is a `LibExeObjStep` (made by `b.addExecutable`).

And now Didot is ready for use!
