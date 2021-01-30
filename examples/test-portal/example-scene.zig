const std = @import("std");
const zlm = @import("zlm");
const Vec3 = zlm.Vec3;
const Allocator = std.mem.Allocator;

usingnamespace @import("didot-graphics");
usingnamespace @import("didot-objects");
usingnamespace @import("didot-app");

const physics = @import("didot-physics");

var world: physics.World = undefined;
var simPaused: bool = false;
var r = std.rand.DefaultPrng.init(0);

//pub const io_mode = .evented;

const App = comptime blk: {
    comptime var systems = Systems {};
    systems.addSystem(update);
    systems.addSystem(testSystem);
    break :blk Application(systems);
};

const CameraControllerData = struct { input: *Input, player: *GameObject };
const CameraController = ComponentType(.CameraController, CameraControllerData, .{ .updateFn = cameraInput }) {};
fn cameraInput(allocator: *Allocator, component: *Component, delta: f32) !void {
    const data = component.getData(CameraControllerData);
    const gameObject = component.gameObject;
    const input = data.input;

    gameObject.position = data.player.position;

    if (input.isMouseButtonDown(.Left)) {
        input.setMouseInputMode(.Grabbed);
        simPaused = false;
    } else if (input.isMouseButtonDown(.Right) or input.isKeyDown(Input.KEY_ESCAPE)) {
        input.setMouseInputMode(.Normal);
    }

    if (input.getMouseInputMode() == .Grabbed) {
        gameObject.rotation.x -= (input.mouseDelta.x / 300.0) * delta;
        gameObject.rotation.y -= (input.mouseDelta.y / 300.0) * delta;
    }
}

const PlayerControllerData = struct { input: *Input };
const PlayerController = ComponentType(.PlayerController, PlayerControllerData, .{ .updateFn = playerInput }) {};
fn playerInput(allocator: *Allocator, component: *Component, delta: f32) !void {
    const data = component.getData(PlayerControllerData);
    const gameObject = component.gameObject;
    const input = data.input;

    const speed: f32 = 40 / delta;

    const camera = gameObject.parent.?.findChild("Camera").?;
    var forward = camera.getForward();
    const left = camera.getLeft();
    forward.y = 0;

    const rb = gameObject.findComponent(.Rigidbody).?.getData(physics.RigidbodyData);
    if (input.isKeyDown(Input.KEY_W)) {
        rb.addForce(forward.scale(speed));
    }
    if (input.isKeyDown(Input.KEY_S)) {
        rb.addForce(forward.scale(-speed));
    }
    if (input.isKeyDown(Input.KEY_A)) {
        rb.addForce(left.scale(speed));
    }
    if (input.isKeyDown(Input.KEY_D)) {
        rb.addForce(left.scale(-speed));
    }
    if (input.isKeyDown(Input.KEY_SPACE)) {
        rb.addForce(Vec3.new(0, speed, 0));
    }

    if (input.isKeyDown(Input.KEY_UP)) {
        // var cube2 = GameObject.createObject(allocator, "Mesh/Cube");
        // cube2.position = Vec3.new(-1.2, 5.75, -3);
        // const color = Vec3.new(r.random.float(f32), r.random.float(f32), r.random.float(f32));
        // cube2.material.ambient = color.mul(Vec3.new(0.1, 0.1, 0.1));
        // cube2.material.diffuse = color.mul(Vec3.new(0.9, 0.9, 0.9));
        // try cube2.addComponent(try physics.Rigidbody.newWithData(allocator, .{
        //    .world = &world,
        //    .material = .{
        //        .bounciness = 0.6
        //    }
        // }));
        // const parent = gameObject.parent.?;
        // try parent.add(cube2);
    }
}

fn loadSkybox(allocator: *Allocator, camera: *Camera, scene: *Scene) !GameObject {
    var skyboxShader = try ShaderProgram.createFromFile(allocator, "assets/shaders/skybox-vert.glsl", "assets/shaders/skybox-frag.glsl");
    camera.*.skyboxShader = skyboxShader;

    const asset = &scene.assetManager;

    try asset.put("textures/skybox", try TextureAsset.initCubemap(allocator, .{
        .front = asset.get("textures/skybox/front.png").?,
        .back = asset.get("textures/skybox/back.png").?,
        .left = asset.get("textures/skybox/left.png").?,
        .right = asset.get("textures/skybox/right.png").?,
        .top = asset.get("textures/skybox/top.png").?,
        .bottom = asset.get("textures/skybox/bottom.png").?,
    }));

    var skyboxMaterial = Material{ .texture = scene.assetManager.get("textures/skybox") };
    var skybox = try createSkybox(allocator);
    skybox.mesh = asset.get("Mesh/Cube");
    skybox.material = skyboxMaterial;
    return skybox;
}

fn testSystem(query: Query(.{})) !void {
    var iter = query.iterator();
    while (iter.next()) |go| {

    }
}

fn update() !void {
     if (!simPaused)
        world.update();
}

fn init(allocator: *Allocator, app: *App) !void {
    world = physics.World.create();
    world.setGravity(zlm.Vec3.new(0, -9.8, 0));

    var shader = try ShaderProgram.createFromFile(allocator, "assets/shaders/vert.glsl", "assets/shaders/frag.glsl");
    const scene = app.scene;
    const asset = &scene.assetManager;

    //try asset.autoLoad(allocator);
    try asset.comptimeAutoLoad(allocator);

    // try asset.put("Texture/Concrete", try TextureAsset.init(allocator, .{
    //     .path = "assets/textures/grass.png", .format = "png",
    //     .tiling = zlm.Vec2.new(2, 2)
    // }));
    var concreteMaterial = Material { .texture = asset.get("textures/grass.bmp") };

    var player = GameObject.createEmpty(allocator);
    player.position = Vec3.new(1.5, 3.5, -0.5);
    player.scale = Vec3.new(2, 2, 2);
    player.name = "Player";
    try player.addComponent(try PlayerController.newWithData(allocator, .{ .input = &app.window.input }));
    try player.addComponent(try physics.Rigidbody.newWithData(allocator,
        .{
            .world = &world,
            .collider = .{
                .Sphere = .{ .radius = 1.0 }
                //.Box = .{ }
            }
        }));
    try scene.add(player);

    var camera = try Camera.create(allocator, shader);
    camera.gameObject.position = Vec3.new(1.5, 3.5, -0.5);
    camera.gameObject.rotation = Vec3.new(-120.0, -15.0, 0).toRadians();
    camera.gameObject.name = "Camera";
    const controller = try CameraController.newWithData(allocator, .{
        .input=&app.window.input,
        .player=scene.gameObject.findChild("Player").?
    });
    try camera.gameObject.addComponent(controller);
    try scene.add(camera.gameObject);

    const skybox = try loadSkybox(allocator, camera, scene);
    try scene.add(skybox);

    var cube = GameObject.createObject(allocator, asset.get("Mesh/Cube"));
    cube.position = Vec3.new(5, -0.75, -10);
    cube.scale = Vec3.new(250, 0.1, 250);
    cube.material = concreteMaterial;
    try cube.addComponent(try physics.Rigidbody.newWithData(allocator, .{ .world=&world, .kinematic=.Kinematic,
        .collider = .{ .Box = .{ .size = Vec3.new(250, 0.1, 250) }}}));
    try scene.add(cube);

    var cube2 = GameObject.createObject(allocator, asset.get("Mesh/Cube"));
    cube2.position = Vec3.new(-1.2, 5.75, -3);
    cube2.scale = Vec3.new(1, 2, 1);
    cube2.material.ambient = Vec3.new(0.2, 0.1, 0.1);
    cube2.material.diffuse = Vec3.new(0.8, 0.8, 0.8);
    try cube2.addComponent(try physics.Rigidbody.newWithData(allocator, .{ .world = &world,
        .collider = .{ .Box = .{ .size = Vec3.new(1, 2, 1) }}}));
    try scene.add(cube2);

    var light = GameObject.createObject(allocator, asset.get("Mesh/Cube"));
    light.position = Vec3.new(1, 5, -5);
    light.material.ambient = Vec3.one;
    try light.addComponent(try PointLight.newWithData(allocator, .{}));
    try scene.add(light);
}

var gp: std.heap.GeneralPurposeAllocator(.{}) = .{};

pub fn main() !void {
    defer _ = gp.deinit();
    const allocator = &gp.allocator;
    var scene = try Scene.create(allocator, null);

    var app = App {
        .title = "Test Room",
        .initFn = init
    };
    try app.run(allocator, scene);
}
