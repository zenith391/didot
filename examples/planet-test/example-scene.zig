const std = @import("std");
const zalgebra = @import("zalgebra");
usingnamespace @import("didot-graphics");
usingnamespace @import("didot-objects");
usingnamespace @import("didot-app");

const Vec3 = zalgebra.vec3;
const Quat = zalgebra.quat;
const rad = zalgebra.to_radians;
const Allocator = std.mem.Allocator;

var scene: *Scene = undefined;

const App = comptime blk: {
    comptime var systems = Systems {};
    systems.addSystem(cameraSystem);
    break :blk Application(systems);
};

const CameraController = struct {};

pub fn cameraSystem(controller: *Camera, transform: *Transform) !void {
    if (scene.findChild("Planet")) |planet| {
        const planetPosition = planet.getComponent(Transform).?.position;
        transform.lookAt(planetPosition);
    }
}

pub fn init(allocator: *Allocator, app: *App) !void {
    scene = app.scene;
    const asset = &scene.assetManager;

    try asset.autoLoad(allocator);

    var shader = try ShaderProgram.createFromFile(allocator, "assets/shaders/vert.glsl", "assets/shaders/frag.glsl");

    var camera = try GameObject.createObject(allocator, null);
    camera.getComponent(Transform).?.position = Vec3.new(1.5, 1.5, -0.5);
    camera.getComponent(Transform).?.rotation = Quat.from_euler_angle(Vec3.new(300, -15, 0));
    try camera.addComponent(Camera { .shader = shader });
    try camera.addComponent(CameraController {});
    try app.scene.add(camera);

    var sphere = try GameObject.createObject(allocator, asset.get("sphere.obj"));
    sphere.name = "Planet";
    sphere.getComponent(Transform).?.position = Vec3.new(5, 0.75, -5);
    try app.scene.add(sphere);

    var light = try GameObject.createObject(allocator, null);
    light.getComponent(Transform).?.position = Vec3.new(1, 5, -5);
    light.material.ambient = Vec3.one();
    try light.addComponent(PointLight {});
    try scene.add(light);
}

pub fn main() !void {
    var gp = std.heap.GeneralPurposeAllocator(.{}) {};
    const allocator = &gp.allocator;

    var app = App {
        .title = "Planets",
        .initFn = init
    };
    try app.run(allocator, try Scene.create(allocator, null));
}