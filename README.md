# Didot 3D Engine

![Demo featuring skybox, karts, grass and a cube](https://raw.githubusercontent.com/zenith391/didot/master/examples/kart-and-cubes.png)

This multi-threaded 3D game engine made for Zig is aimed at high-level constructs, you manipulate game objects and meshes instead of OpenGL calls and batches.

That combined with the fact the engine is in multiple packages, this means that changing the graphics module to something else is easy,
just need to for example use `didot-x11` instead of `didot-glfw` to use X11 instead of depending on GLFW. And since they share the same API, absolutely zero porting is necessary!

This also works for graphics backend, so by using `didot-vulkan` (will come one day) instead of `didot-opengl`, your games can now seamlessly run with Vulkan! (althought some changes to shaders will be required)

[API reference](https://zenith391.github.io/didot/#root)

## Features
- [Scene editor](https://github.com/zenith391/didot-editor)
- Assets manager
- OpenGL backend
  - Shaders
  - Meshes
  - Materials
  - Textures
- Windowing
  - GLFW backend
  - X11 backend
- Model loader
  - OBJ files
- Image loader
  - BMP files
  - PNG files
- Application system for easier use
- Game objects system

## Examples

Cube:
```zig
const std = @import("std");
const zlm = @import("zlm");
const graphics = @import("didot-graphics");
const objects = @import("didot-objects");
const Application = @import("didot-app").Application;

const Vec3 = zlm.Vec3;
const Allocator = std.mem.Allocator;
const ShaderProgram = graphics.ShaderProgram;
const GameObject = objects.GameObject;
const Scene = objects.Scene;
const Camera = objects.Camera;

fn init(allocator: *Allocator, app: *Application) !void {
    var shader = try ShaderProgram.create(@embedFile("vert.glsl"), @embedFile("frag.glsl"));

    var camera = try Camera.create(allocator, shader);
    camera.gameObject.position = Vec3.new(1.5, 1.5, -0.5);
    camera.gameObject.rotation = Vec3.new(-120.0, -15.0, 0).toRadians();
    try app.scene.add(camera.gameObject);
    
    var cube = GameObject.createObject(allocator, "Mesh/Cube");
    cube.position = Vec3.new(-1.2, 0.75, -3);
    try app.scene.add(cube);
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
That is where you can see it's not 100% true that zero porting is necessary, if you use some other graphics backend that doesn't accept GLSL, you'll have to rewrite the shaders.

It's done this way because making a universal shader language is hard and would also bloat the engine.

And to make that into a textured cube, only a few lines are necessary:
```zig
try scene.assetManager.put("Texture/Grass", .{
    .loader = graphics.textureAssetLoader,
    .loaderData = try graphics.TextureAssetLoaderData.init2D(allocator, "assets/textures/grass.png", "png"),
    .objectType = .Texture
});
var material = Material { .texturePath = "Texture/Grass" };
cube.material = material;
```

You can also look at the [kart and cubes example](https://github.com/zenith391/didot/blob/master/examples/kart-and-cubes/example-scene.zig) to see how to make camera movement or load models from OBJ files or even load scenes from JSON files.

## How to use

Just add this to your build script:
```zig
const engine = @import("path/to/engine/build.zig");

pub fn build(b: *Builder) !void {
    // your code ...
    try engine.addEngineToExe(exe, .{
      .prefix = "path/to/engine/"
    });
    // more code ...
}
```
Where `exe` is a `LibExeObjStep` (made by `b.addExecutable`).

And now Didot is ready for use!
