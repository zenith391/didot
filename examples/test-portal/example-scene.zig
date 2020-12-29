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

    const speed: f32 = 0.1 * delta;

    const camera = gameObject.parent.?.findChild("Camera").?;
    var forward = camera.getForward();
    const left = camera.getLeft();
    forward.y = 0;

    const rb = gameObject.findComponent(.Rigidbody).?.getData(physics.RigidbodyData);
    if (input.isKeyDown(Input.KEY_W)) {
        rb.addForce(forward.scale(speed*400));
    }
    if (input.isKeyDown(Input.KEY_S)) {
        rb.setPosition(gameObject.position.add(forward.scale(-speed)));
    }
    if (input.isKeyDown(Input.KEY_A)) {
        rb.setPosition(gameObject.position.add(left.scale(speed)));
    }
    if (input.isKeyDown(Input.KEY_D)) {
        rb.setPosition(gameObject.position.add(left.scale(-speed)));
    }
    if (input.isKeyDown(Input.KEY_SPACE)) {
        rb.addForce(Vec3.new(0, 400*speed, 0));
    }

    if (input.isKeyDown(Input.KEY_UP)) {
        var cube2 = GameObject.createObject(allocator, "Mesh/Cube");
        cube2.position = Vec3.new(-1.2, 5.75, -3);
        const color = Vec3.new(r.random.float(f32), r.random.float(f32), r.random.float(f32));
        cube2.material.ambient = color.mul(Vec3.new(0.1, 0.1, 0.1));
        cube2.material.diffuse = color.mul(Vec3.new(0.9, 0.9, 0.9));
        try cube2.addComponent(try physics.Rigidbody.newWithData(allocator, .{
           .world = &world,
           .material = .{
               .bounciness = 0.6
           }
        }));
        const parent = gameObject.parent.?;
        try parent.add(cube2);
    }
}

fn loadSkybox(allocator: *Allocator, camera: *Camera, scene: *Scene) !GameObject {
    var skyboxShader = try ShaderProgram.createFromFile(allocator, "assets/shaders/skybox-vert.glsl", "assets/shaders/skybox-frag.glsl");
    camera.*.skyboxShader = skyboxShader;

    try scene.assetManager.put("Texture/Skybox", try TextureAsset.initCubemap(allocator, .{
        .front = "assets/textures/skybox/front.bmp",
        .back = "assets/textures/skybox/back.bmp",
        .left = "assets/textures/skybox/left.bmp",
        .right = "assets/textures/skybox/right.bmp",
        .top = "assets/textures/skybox/top.bmp",
        .bottom = "assets/textures/skybox/bottom.bmp"
    }, "bmp"));

    var skyboxMaterial = Material{ .texturePath = "Texture/Skybox" };
    var skybox = try createSkybox(allocator);
    skybox.meshPath = "Mesh/Cube";
    skybox.material = skyboxMaterial;
    return skybox;
}

fn update(allocator: *Allocator, app: *Application, delta: f32) !void {
    if (!simPaused)
        world.update();
}

fn init(allocator: *Allocator, app: *Application) !void {
    world = physics.World.create();
    world.setGravity(zlm.Vec3.new(0, -9.8, 0));

    var shader = try ShaderProgram.createFromFile(allocator, "assets/shaders/vert.glsl", "assets/shaders/frag.glsl");
    const scene = app.scene;
    const asset = &scene.assetManager;

    try asset.put("Texture/Concrete", try TextureAsset.init(allocator, .{
        .path = "assets/textures/grass.png", .format = "png",
        .tiling = zlm.Vec2.new(2, 2)
    }));
    var concreteMaterial = Material{ .texturePath = "Texture/Concrete" };

    var player = GameObject.createEmpty(allocator);
    player.position = Vec3.new(1.5, 3.5, -0.5);
    player.scale = Vec3.new(2, 2, 2);
    player.name = "Player";
    try player.addComponent(try PlayerController.newWithData(allocator, .{ .input = &app.window.input }));
    try player.addComponent(try physics.Rigidbody.newWithData(allocator, .{ .world=&world }));
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

    var cube = GameObject.createObject(allocator, "Mesh/Cube");
    cube.position = Vec3.new(5, -0.75, -10);
    cube.scale = Vec3.new(250, 0.1, 250);
    cube.material = concreteMaterial;
    try cube.addComponent(try physics.Rigidbody.newWithData(allocator, .{ .world=&world, .kinematic=.Kinematic }));
    try scene.add(cube);

    var cube2 = GameObject.createObject(allocator, "Mesh/Cube");
    cube2.position = Vec3.new(-1.2, 5.75, -3);
    cube2.scale = Vec3.new(1, 2, 1);
    cube2.material.ambient = Vec3.new(0.2, 0.1, 0.1);
    cube2.material.diffuse = Vec3.new(0.8, 0.8, 0.8);
    try cube2.addComponent(try physics.Rigidbody.newWithData(allocator, .{ .world = &world }));
    try scene.add(cube2);

    var light = try PointLight.create(allocator);
    light.gameObject.position = Vec3.new(1, 5, -5);
    light.gameObject.meshPath = "Mesh/Cube";
    light.gameObject.material.ambient = Vec3.one;
    try scene.add(light.gameObject);
}

var gp: std.heap.GeneralPurposeAllocator(.{}) = .{};

pub fn main() !void {
    defer _ = gp.deinit();
    const allocator = &gp.allocator;
    var scene = try Scene.create(allocator, null);
    var app = Application{
        .title = "Test Room",
        .initFn = init,
        .updateFn = update,
    };
    try app.run(allocator, scene);
}
