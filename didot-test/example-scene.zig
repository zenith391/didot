const std = @import("std");
const zlm = @import("zlm");
const Vec3 = zlm.Vec3;
const Allocator = std.mem.Allocator;

const graphics = @import("didot-graphics");
const objects = @import("didot-objects");
const models = @import("didot-models");
const bmp = @import("didot-image").bmp;
const obj = models.obj;
const Application = @import("didot-app").Application;

const Texture = graphics.Texture;
const Window = graphics.Window;
const ShaderProgram = graphics.ShaderProgram;
const Material = graphics.Material;

const GameObject = objects.GameObject;
const Scene = objects.Scene;
const Camera = objects.Camera;

var win: Window = undefined;

fn input(allocator: *Allocator, gameObject: *GameObject, delta: f32) !void {
    if (win.isKeyDown(graphics.KEY_W)) {
        gameObject.*.position = Vec3.new(1, 2, 1);
    }
}

fn init(allocator: *Allocator, app: *Application) !void {
    win = app.window;
    var shader = try ShaderProgram.create(@embedFile("vert.glsl"), @embedFile("frag.glsl"));
    const scene = app.scene;

    var grassImage = try bmp.read_bmp(allocator, "grass.bmp");
    var texture = Texture.create(grassImage);
    grassImage.deinit(); // it's now uploaded to the GPU, so we can free the image.
    var grassMaterial = Material {
        .texture = texture
    };

    var camera = try Camera.create(allocator, shader);
    camera.gameObject.position = Vec3.new(1.5, 1.5, -0.5);
    camera.pitch = zlm.toRadians(-15.0);
    camera.yaw = zlm.toRadians(-120.0);
    camera.gameObject.updateFn = input;
    try scene.add(camera.gameObject);

    var cube = GameObject.createObject(allocator, objects.PrimitiveCubeMesh);
    cube.position = Vec3.new(0, 0.75, -3);
    cube.material = grassMaterial;
    try scene.add(cube);

    var cube2 = GameObject.createObject(allocator, objects.PrimitiveCubeMesh);
    cube2.position = Vec3.new(-1.2, 0.75, -3);
    try scene.add(cube2);

    var kartMesh = try obj.read_obj(allocator, "kart.obj");
    var kart = GameObject.createObject(allocator, kartMesh);
    kart.position = Vec3.new(0.7, 0.75, -5);
    try scene.add(kart);
}

pub fn main() !void {
    var gp = std.heap.GeneralPurposeAllocator(.{}) {};
    const allocator = &gp.allocator;

    var scene = try Scene.create(allocator);

    var app = Application {
        .title = "Test Cubes",
        .initFn = init
    };
    try app.start(allocator, scene);
}
