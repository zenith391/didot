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
const Input = graphics.Input;
const Window = graphics.Window;
const ShaderProgram = graphics.ShaderProgram;
const Material = graphics.Material;

const GameObject = objects.GameObject;
const Scene = objects.Scene;
const Camera = objects.Camera;

var inp: Input = undefined;

fn input(allocator: *Allocator, gameObject: *GameObject, delta: f32) !void {
    const speed: f32 = 0.1 * delta;
    const forward = gameObject.getForward();
    const left = gameObject.getLeft();

    if (inp.isKeyDown(Input.KEY_W)) {
        gameObject.position = gameObject.position.add(forward.scale(speed));
    }
    if (inp.isKeyDown(Input.KEY_S)) {
        gameObject.position = gameObject.position.add(forward.scale(-speed));
    }
    if (inp.isKeyDown(Input.KEY_A)) {
        gameObject.position = gameObject.position.add(left.scale(speed));
    }
    if (inp.isKeyDown(Input.KEY_D)) {
        gameObject.position = gameObject.position.add(left.scale(-speed));
    }
}

fn init(allocator: *Allocator, app: *Application) !void {
    inp = app.window.input();
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
    camera.gameObject.rotation = Vec3.new(-120.0, -15.0, 0).toRadians();
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
