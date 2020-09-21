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
const PointLight = objects.PointLight;

var input: *Input = undefined;

fn cameraInput(allocator: *Allocator, gameObject: *GameObject, delta: f32) !void {
    const speed: f32 = 0.1 * delta;
    const forward = gameObject.getForward();
    const left = gameObject.getLeft();

    if (input.isKeyDown(Input.KEY_W)) {
        gameObject.position = gameObject.position.add(forward.scale(speed));
    }
    if (input.isKeyDown(Input.KEY_S)) {
        gameObject.position = gameObject.position.add(forward.scale(-speed));
    }
    if (input.isKeyDown(Input.KEY_A)) {
        gameObject.position = gameObject.position.add(left.scale(speed));
    }
    if (input.isKeyDown(Input.KEY_D)) {
        gameObject.position = gameObject.position.add(left.scale(-speed));
    }

    if (input.isMouseButtonDown(.Left)) {
        input.setMouseInputMode(.Grabbed);
    } else if (input.isKeyDown(Input.KEY_ESCAPE)) {
        input.setMouseInputMode(.Normal);
    }

    if (input.getMouseInputMode() == .Grabbed) {
        gameObject.rotation.x -= (input.mouseDelta.x / 300.0) * delta;
        gameObject.rotation.y -= (input.mouseDelta.y / 300.0) * delta;
    }
}

fn testLight(allocator: *Allocator, gameObject: *GameObject, delta: f32) !void {
    const time = @intToFloat(f64, std.time.milliTimestamp());
    const rad = @floatCast(f32, @mod((time/1000.0), std.math.pi*2.0));
    gameObject.position = Vec3.new(@sin(rad)*10+5, 3, @cos(rad)*10-10);
}

fn init(allocator: *Allocator, app: *Application) !void {
    input = &app.window.input;
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
    camera.gameObject.updateFn = cameraInput;
    try scene.add(camera.gameObject);

    var cube = GameObject.createObject(allocator, objects.PrimitiveCubeMesh);
    cube.position = Vec3.new(10, -0.75, -10);
    cube.scale = Vec3.new(20, 1, 20);
    cube.material = grassMaterial;
    try scene.add(cube);

    var cube2 = GameObject.createObject(allocator, objects.PrimitiveCubeMesh);
    cube2.position = Vec3.new(-1.2, 0.75, -3);
    cube2.material.ambient = Vec3.new(0.2, 0.1, 0.1);
    cube2.material.diffuse = Vec3.new(0.8, 0.8, 0.8);
    try scene.add(cube2);

    var kartMesh = try obj.read_obj(allocator, "res/kart.obj");

    var kart = GameObject.createObject(allocator, kartMesh);
    kart.position = Vec3.new(0.7, 0.75, -5);
    try scene.add(kart);

    var i: f32 = 0;
    while (i < 5) {
        var j: f32 = 0;
        while (j < 5) {
            var kart2 = GameObject.createObject(allocator, kartMesh);
            kart2.position = Vec3.new(0.7 + (j*8), 0.75, -8 - (i*3));
            try scene.add(kart2);
            j += 1;
        }
        i += 1;
    }

    var light = try PointLight.create(allocator);
    light.gameObject.position = Vec3.new(1, 5, -5);
    light.gameObject.updateFn = testLight;
    light.gameObject.mesh = objects.PrimitiveCubeMesh;
    light.gameObject.material.ambient = Vec3.one;
    try scene.add(light.gameObject);

    std.debug.warn("{} bytes used after init.\n", .{gp.total_requested_bytes});
}

var gp: std.heap.GeneralPurposeAllocator(.{.enable_memory_limit = true}) = undefined;

pub fn main() !void {
    gp = .{};
    defer {
        _ = gp.deinit();
    }
    const allocator = &gp.allocator;

    var scene = try Scene.create(allocator);

    var app = Application {
        .title = "Test Cubes",
        .initFn = init
    };
    try app.start(allocator, scene);
}
