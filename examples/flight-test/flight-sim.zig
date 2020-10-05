//! Space-y exploration "game" with planets, asteroids and space airplanes.
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
var airplane: ?*GameObject = undefined;

fn cameraUpdate(allocator: *Allocator, gameObject: *GameObject, delta: f32) !void {
    if (airplane) |plane| {
        gameObject.position = plane.position.add(zlm.Vec3.new(
           -9.0,
           3.0,
           0.0,
        ));
        //gameObject.lookAt(plane.position, zlm.Vec3.new(0, 1, 0));
        gameObject.rotation = zlm.Vec3.new(0, 0, -15).toRadians();
    }
}

fn planeInput(allocator: *Allocator, gameObject: *GameObject, delta: f32) !void {
    const speed: f32 = 0.1 * delta;
    const forward = gameObject.getForward();
    const left = gameObject.getLeft();
    airplane = gameObject;

    // if (input.isMouseButtonDown(.Left)) {
    //     input.setMouseInputMode(.Grabbed);
    // } else if (input.isKeyDown(Input.KEY_ESCAPE)) {
    //     input.setMouseInputMode(.Normal);
    // }

    // if (input.getMouseInputMode() == .Grabbed) {
    //     gameObject.rotation.x -= (input.mouseDelta.x / 300.0) * delta;
    //     gameObject.rotation.y -= (input.mouseDelta.y / 300.0) * delta;
    // }

    if (input.getJoystick(0)) |joystick| {
        const axes = joystick.getRawAxes();
        var fw = axes[1]; // forward
        var r = axes[0]; // right
        var thrust = (axes[3] - 1.0) * -0.5;
        const threshold = 0.2;

        if (r < threshold and r > 0) r = 0;
        if (r > -threshold and r < 0) r = 0;
        if (fw < threshold and fw > 0) fw = 0;
        if (fw > -threshold and fw < 0) fw = 0;
        gameObject.position = gameObject.position.add(forward.scale(thrust*speed));
        gameObject.rotation.x -= (r / 50.0) * delta;
        gameObject.rotation.y -= (fw / 50.0) * delta;
    }
}

fn testLight(allocator: *Allocator, gameObject: *GameObject, delta: f32) !void {
    const time = @intToFloat(f64, std.time.milliTimestamp());
    const rad = @floatCast(f32, @mod((time/1000.0), std.math.pi*2.0));
    gameObject.position = Vec3.new(std.math.sin(rad)*10+5, 3, std.math.cos(rad)*10-10);
}

fn init(allocator: *Allocator, app: *Application) !void {
    input = &app.window.input;
    var shader = try ShaderProgram.create(@embedFile("vert.glsl"), @embedFile("frag.glsl"));
    const scene = app.scene;

    var grassImage = try bmp.read_bmp(allocator, "grass.bmp");
    var texture = Texture.create2D(grassImage);
    grassImage.deinit(); // it's now uploaded to the GPU, so we can free the image.
    var grassMaterial = Material {
        .texture = texture
    };

    var camera = try Camera.create(allocator, shader);
    camera.gameObject.position = Vec3.new(1.5, 1.5, -0.5);
    camera.gameObject.rotation = Vec3.new(-120.0, -15.0, 0).toRadians();
    camera.gameObject.updateFn = cameraUpdate;
    try scene.add(camera.gameObject);

    var airplaneMesh = try obj.read_obj(allocator, "res/f15.obj");
    var plane = GameObject.createObject(allocator, airplaneMesh);
    plane.position = Vec3.new(-1.2, 1.95, -3);
    plane.updateFn = planeInput;
    try scene.add(plane);

    // var light = try PointLight.create(allocator);
    // light.gameObject.position = Vec3.new(1, 5, -5);
    // light.gameObject.updateFn = testLight;
    // light.gameObject.mesh = objects.PrimitiveCubeMesh;
    // light.gameObject.material.ambient = Vec3.one;
    // try scene.add(light.gameObject);
}

var gp: std.heap.GeneralPurposeAllocator(.{}) = undefined;

pub fn main() !void {
    gp = .{};
    defer {
        _ = gp.deinit();
    }
    const allocator = &gp.allocator;

    var scene = try Scene.create(allocator);
    var app = Application {
        .title = "Flight Test",
        .initFn = init
    };
    try app.start(allocator, scene);
}
