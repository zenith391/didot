const std = @import("std");
const zalgebra = @import("zalgebra");
const physics = @import("didot-physics");
const Vec3 = zalgebra.vec3;
const Quat = zalgebra.quat;
const Allocator = std.mem.Allocator;
const rad = zalgebra.to_radians;

usingnamespace @import("didot-graphics");
usingnamespace @import("didot-objects");
usingnamespace @import("didot-app");

var world: physics.World = undefined;
var scene: *Scene = undefined;

//pub const io_mode = .evented;

const App = comptime blk: {
    comptime var systems = Systems {};
    systems.addSystem(update);
    systems.addSystem(testSystem);
    systems.addSystem(playerSystem);
    systems.addSystem(cameraSystem);

    systems.addSystem(physics.rigidbodySystem);
    break :blk Application(systems);
};

const CameraController = struct { input: *Input, player: *GameObject };
fn cameraSystem(controller: *CameraController, transform: *Transform) !void {
    const input = controller.input;
    transform.position = controller.player.getComponent(Transform).?.position;

    if (input.isMouseButtonDown(.Left)) {
        input.setMouseInputMode(.Grabbed);
    } else if (input.isMouseButtonDown(.Right) or input.isKeyDown(Input.KEY_ESCAPE)) {
        input.setMouseInputMode(.Normal);
    }

    if (input.getMouseInputMode() == .Grabbed) {
        const delta = 1.0; // TODO: put delta in Application struct
        var euler = transform.rotation.extract_rotation();
        euler.x += (input.mouseDelta.x / 3.0) * delta;
        euler.y -= (input.mouseDelta.y / 3.0) * delta;
        if (euler.y > 89) euler.y = 89;
        if (euler.y < -89) euler.y = -89;

        transform.rotation = Quat.from_euler_angle(euler);
    }
}

const PlayerController = struct { input: *Input };
fn playerSystem(controller: *PlayerController, rb: *physics.Rigidbody) !void {
    const input = controller.input;

    const delta = 1.0; // TODO: put delta in Application struct
    const speed: f32 = 40 / delta;

    const camera = scene.findChild("Camera").?.getComponent(Transform).?;
    var forward = camera.getForward();
    const right = camera.getRight();
    forward.y = 0;

    if (input.isKeyDown(Input.KEY_W)) {
        rb.addForce(forward.scale(speed));
    }
    if (input.isKeyDown(Input.KEY_S)) {
        rb.addForce(forward.scale(-speed));
    }
    if (input.isKeyDown(Input.KEY_A)) {
        rb.addForce(right.scale(-speed));
    }
    if (input.isKeyDown(Input.KEY_D)) {
        rb.addForce(right.scale(speed));
    }
    if (input.isKeyDown(Input.KEY_SPACE)) {
        rb.addForce(Vec3.new(0, speed, 0));
    }
}

fn loadSkybox(allocator: *Allocator, camera: *Camera) !void {
    const asset = &scene.assetManager;
    try asset.put("textures/skybox", try TextureAsset.initCubemap(allocator, .{
        .front = asset.get("textures/skybox/front.png").?,
        .back = asset.get("textures/skybox/back.png").?,
        .left = asset.get("textures/skybox/left.png").?,
        .right = asset.get("textures/skybox/right.png").?,
        .top = asset.get("textures/skybox/top.png").?,
        .bottom = asset.get("textures/skybox/bottom.png").?,
    }));

    var skyboxShader = try ShaderProgram.createFromFile(allocator, "assets/shaders/skybox-vert.glsl", "assets/shaders/skybox-frag.glsl");
    camera.skybox = Skybox {
        .mesh = asset.get("Mesh/Cube").?,
        .cubemap = asset.get("textures/skybox").?,
        .shader = skyboxShader
    };
}

fn testSystem(query: Query(.{})) !void {
    var iter = query.iterator();
    while (iter.next()) |go| {

    }
}

fn update() !void {
    world.update();
}

fn init(allocator: *Allocator, app: *App) !void {
    world = physics.World.create();
    world.setGravity(Vec3.new(0, -9.8, 0));

    var shader = try ShaderProgram.createFromFile(allocator, "assets/shaders/vert.glsl", "assets/shaders/frag.glsl");
    scene = app.scene;
    const asset = &scene.assetManager;

    try asset.autoLoad(allocator);
    //try asset.comptimeAutoLoad(allocator);

    var concreteMaterial = Material { .texture = asset.get("textures/grass.bmp") };

    var player = try GameObject.createObject(allocator, null);
    player.getComponent(Transform).?.* = .{
        .position = Vec3.new(1.5, 3.5, -0.5),
        .scale = Vec3.new(2, 2, 2)
    };
    player.name = "Player";
    try player.addComponent(PlayerController { .input = &app.window.input });
    try player.addComponent(physics.Rigidbody {
        .world = &world,
        .collider = .{
            .Sphere = .{ .radius = 1.0 }
        }
    });
    try scene.add(player);

    var camera = try GameObject.createObject(allocator, null);
    try camera.addComponent(Camera { .shader = shader });
    camera.getComponent(Transform).?.* = .{
        .position = Vec3.new(1.5, 3.5, -0.5),
        .rotation = Quat.from_euler_angle(Vec3.new(-120, -15, 0))
    };
    camera.name = "Camera";
    try camera.addComponent(CameraController {
        .input = &app.window.input,
        .player = scene.findChild("Player").?
    });
    try scene.add(camera);

    try loadSkybox(allocator, camera.getComponent(Camera).?);

    var cube = try GameObject.createObject(allocator, asset.get("Mesh/Cube"));
    cube.getComponent(Transform).?.* = .{
        .position = Vec3.new(5, -0.75, -10),
        .scale = Vec3.new(250, 0.1, 250)
    };
    cube.material = concreteMaterial;
    try cube.addComponent(physics.Rigidbody { .world=&world, .kinematic=.Kinematic,
        .collider = .{ .Box = .{ .size = Vec3.new(250, 0.1, 250) }}});
    try scene.add(cube);

    var cube2 = try GameObject.createObject(allocator, asset.get("Mesh/Cube"));
    cube2.getComponent(Transform).?.* = .{
        .position = Vec3.new(-1.2, 5.75, -3),
        .scale = Vec3.new(1, 2, 1)
    };
    cube2.material.ambient = Vec3.new(0.2, 0.1, 0.1);
    cube2.material.diffuse = Vec3.new(0.8, 0.8, 0.8);
    try cube2.addComponent(physics.Rigidbody { .world = &world,
        .collider = .{ .Box = .{ .size = Vec3.new(1, 2, 1) }}});
    try scene.add(cube2);

    var light = try GameObject.createObject(allocator, asset.get("Mesh/Cube"));
    light.getComponent(Transform).?.position = Vec3.new(1, 5, -5);
    light.material.ambient = Vec3.one();
    try light.addComponent(PointLight {});
    try scene.add(light);
}

var gp: std.heap.GeneralPurposeAllocator(.{}) = .{};

pub fn main() !void {
    defer _ = gp.deinit();
    const gpa_allocator = &gp.allocator;
    const allocator = gpa_allocator;

    var app = App {
        .title = "Test Room",
        .initFn = init
    };
    try app.run(allocator, try Scene.create(allocator, null));
}
