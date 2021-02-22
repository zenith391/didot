# Didot
A Zig 3D game engine.

---

![Demo featuring skybox, karts, grass and a cube](https://raw.githubusercontent.com/zenith391/didot/master/examples/kart-and-cubes.png)

## Introduction

Didot is a multi-threaded 3D game engine programmed in Zig and aimed at high-level constructs: you manipulate game objects and meshes instead of OpenGL calls and batches.

It improves developers life by splitting the engine into multiple modules in order to have easier porting to other platforms. For example, you can change the windowing module from `didot-glfw` to `didot-x11` to use Xlib instead of depending on GLFW without any change to your game's code, as porting (except for shaders) is transparent to the developer's code.

## Installation
Prerequisites:
- Zig compiler (`master` branch, didot is currently tested with commit `0aef1fa`)

You only need to launch your terminal and execute those commands in an empty directory:
```sh
git clone https://github.com/zenith391/didot
zig init-exe
```
And then, change the resulting `build.zig` file looks like this:
```zig
const didot = @import("didot/build.zig");
const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    // ...
    exe.setBuildMode(mode);
    try didot.addEngineToExe(exe, .{
        .prefix = "didot/"
    });
    exe.install();
    // ...
}
```

## Using Didot
Showing a cube:
```zig
const std = @import("std");
const zlm = @import("zlm");
usingnamespace @import("didot-graphics");
usingnamespace @import("didot-objects");
usingnamespace @import("didot-app");

const Vec3 = zlm.Vec3;
const Allocator = std.mem.Allocator;

fn init(allocator: *Allocator, app: *Application) !void {
    var shader = try ShaderProgram.create(@embedFile("vert.glsl"), @embedFile("frag.glsl"));

    var camera = try GameObject.createObject(allocator, null);
    camera.getComponent(Transform).?.* = .{
        .position = Vec3.new(1.5, 1.5, -0.5),
        .rotation = Vec3.new(-120.0, -15.0, 0).toRadians()
    };
    try camera.addComponent(Camera { .shader = shader });
    try app.scene.add(camera);
    
    var cube = try GameObject.createObject(allocator, "Mesh/Cube");
    cube.getComponent(Transform).?.position = Vec3.new(-1.2, 0.75, -3);
    try app.scene.add(cube);
}

pub fn main() !void {
    var gp = std.heap.GeneralPurposeAllocator(.{}) {};
    const allocator = &gp.allocator;

    var scene = try Scene.create(allocator, null);
    comptime var systems = Systems {};
    var app = Application(systems) {
        .title = "Test Cube",
        .initFn = init
    };
    try app.run(allocator, scene);
}
```

And to make that into a textured cube, only a few lines are necessary:
```zig
try scene.assetManager.put("Texture/Grass", try TextureAsset.init2D(allocator, "assets/textures/grass.png", "png"));
var material = Material { .texturePath = "Texture/Grass" };
cube.material = material;
```
First line loads `assets/textures/grass.png` to `Texture/Grass`.  
Second line creates a Material with the `Texture/Grass` texture.  
Third line links the cube to the newly created Material.

You can also look at the [example](https://github.com/zenith391/didot/blob/master/examples/test-portal/example-scene.zig) to see how to make camera movement or load models from OBJ files or even load scenes from JSON files.

Systems (currently):
```zig
fn exampleSystem(query: Query(.{*Transform})) !void {
    var iterator = query.iterator();
    while (iterator.next()) |o| {
        std.log.info("Someone's at position {} !", .{o.transform.position});
    }
}

pub fn main() !void {
    // ...
    comptime var systems = Systems {};
    systems.addSystem(exampleSystem);
    var app = Application(systems) {
        .title = "Test Cube",
        .initFn = init
    };
    try app.run(allocator, scene);
}
```

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
