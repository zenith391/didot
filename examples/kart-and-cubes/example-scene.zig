const std = @import("std");
const zlm = @import("zlm");
const Vec3 = zlm.Vec3;
const Allocator = std.mem.Allocator;

usingnamespace @import("didot-graphics");
const objects = @import("didot-objects");
const models = @import("didot-models");
const image = @import("didot-image");
const physics = @import("didot-physics");
const bmp = image.bmp;
const obj = models.obj;
const Application = @import("didot-app").Application;

const GameObject = objects.GameObject;
const Scene = objects.Scene;
const Camera = objects.Camera;
const PointLight = objects.PointLight;

var world: physics.World = undefined;
var simPaused: bool = false;
var cube2: GameObject = undefined;

const Component = objects.Component;
const CameraControllerData = struct { input: *Input };
const CameraController = objects.ComponentType(.CameraController, CameraControllerData, .{ .updateFn = cameraInput }) {};
fn cameraInput(allocator: *Allocator, component: *Component, delta: f32) !void {
    const data = component.getData(CameraControllerData);
    const input = data.input;
    const gameObject = component.gameObject;

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

    if (input.isKeyDown(Input.KEY_UP)) {
        if (cube2.findComponent(.Rigidbody)) |rb| {
            rb.getData(physics.RigidbodyData).addForce(zlm.Vec3.new(0, 20, 0));
        }
    }
    if (input.isKeyDown(Input.KEY_LEFT)) {
        if (cube2.findComponent(.Rigidbody)) |rb| {
            rb.getData(physics.RigidbodyData).addForce(zlm.Vec3.new(5, 0, 0));
        }
    }
    if (input.isKeyDown(Input.KEY_RIGHT)) {
        if (cube2.findComponent(.Rigidbody)) |rb| {
            rb.getData(physics.RigidbodyData).addForce(zlm.Vec3.new(0, 0, 5));
        }
    }

    if (input.isMouseButtonDown(.Left)) {
        input.setMouseInputMode(.Grabbed);
        simPaused = false;
    } else if (input.isMouseButtonDown(.Right)) {
        input.setMouseInputMode(.Normal);
    } else if (input.isKeyDown(Input.KEY_ESCAPE)) {
        input.setMouseInputMode(.Normal);
    }

    if (input.getMouseInputMode() == .Grabbed) {
        gameObject.rotation.x -= (input.mouseDelta.x / 300.0) * delta;
        gameObject.rotation.y -= (input.mouseDelta.y / 300.0) * delta;
    }

    if (input.getJoystick(0)) |joystick| {
        const axes = joystick.getRawAxes();
        var r = axes[0]; // right
        var fw = axes[1]; // forward
        const thrust = (axes[3] - 1.0) * -0.5;
        const threshold = 0.2;

        if (r < threshold and r > 0) r = 0; if (r > -threshold and r < 0) r = 0;
        if (fw < threshold and fw > 0) fw = 0; if (fw > -threshold and fw < 0) fw = 0;

        gameObject.position = gameObject.position.add(forward.scale(thrust * speed));
        gameObject.rotation.x -= (r / 50.0) * delta;
        gameObject.rotation.y -= (fw / 50.0) * delta;

        // std.debug.warn("A: {}, B: {}, X: {}, Y: {}\n", .{
        //    joystick.isButtonDown(.A),
        //    joystick.isButtonDown(.B),
        //    joystick.isButtonDown(.X),
        //    joystick.isButtonDown(.Y),
        // });
    }
}

const TestLight = objects.ComponentType(.TestLight, struct {}, .{ .updateFn = testLight }) {};
fn testLight(allocator: *Allocator, component: *Component, delta: f32) !void {
    const time = @intToFloat(f64, std.time.milliTimestamp());
    const rad = @floatCast(f32, @mod((time / 1000.0), std.math.pi * 2.0));
    component.gameObject.position = Vec3.new(std.math.sin(rad) * 20 + 10, 3, std.math.cos(rad) * 10 - 10);
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
    var skybox = try objects.createSkybox(allocator);
    skybox.meshPath = "Mesh/Cube";
    skybox.material = skyboxMaterial;
    return skybox;
}

fn initFromFile(allocator: *Allocator, app: *Application) !void {
    input = &app.window.input;
    var scene = Scene.loadFromFile(allocator, "res/example-scene.json");
    scene.findChild("Camera").?.updateFn = cameraInput;
    scene.findChild("Light").?.updateFn = testLight;
    app.scene = scene;

    //var skybox = try loadSkybox(allocator, camera);
    //try scene.add(skybox);

    // var i: f32 = 0;
    // while (i < 5) {
    //     var j: f32 = 0;
    //     while (j < 5) {
    //         var kart2 = GameObject.createObject(allocator, "Mesh/Kart");
    //         kart2.position = Vec3.new(0.7 + (j*8), 0.75, -8 - (i*3));
    //         try scene.add(kart2);
    //         j += 1;
    //     }
    //     i += 1;
    // }
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

    try scene.assetManager.put("Texture/Grass", try TextureAsset.init(allocator, .{
        .path = "assets/textures/grass.png", .format = "png",
        .tiling = zlm.Vec2.new(2, 2)
    }));
    var grassMaterial = Material{ .texturePath = "Texture/Grass" };

    var camera = try Camera.create(allocator, shader);
    camera.gameObject.position = Vec3.new(1.5, 1.5, -0.5);
    camera.gameObject.rotation = Vec3.new(-120.0, -15.0, 0).toRadians();
    const controller = try CameraController.newWithData(allocator, .{ .input = &app.window.input });
    try camera.gameObject.addComponent(controller);
    try scene.add(camera.gameObject);

    const skybox = try loadSkybox(allocator, camera, scene);
    try scene.add(skybox);

    var cube = GameObject.createObject(allocator, "Mesh/Cube");
    cube.position = Vec3.new(5, -0.75, -10);
    cube.scale = Vec3.new(50, 1, 50);
    cube.material = grassMaterial;
    try cube.addComponent(try physics.Rigidbody.newWithData(allocator, .{ .world=&world, .kinematic=.Kinematic, .collider = .{
        .Box = .{ .size = Vec3.new(50, 1, 50) }
        } }));
    try scene.add(cube);

    cube2 = GameObject.createObject(allocator, "Mesh/Cube");
    cube2.position = Vec3.new(-1.2, 5.75, -3);
    cube2.material.ambient = Vec3.new(0.2, 0.1, 0.1);
    cube2.material.diffuse = Vec3.new(0.8, 0.8, 0.8);
    try cube2.addComponent(try physics.Rigidbody.newWithData(allocator, .{ .world = &world }));
    try scene.add(cube2);

    try scene.assetManager.put("Mesh/Kart", .{
        .loader = models.meshAssetLoader,
        .loaderData = try models.MeshAssetLoaderData.init(allocator, "assets/kart.obj", "obj"),
        .objectType = .Mesh,
    });
    var kart = GameObject.createObject(allocator, "Mesh/Kart");
    kart.position = Vec3.new(0.7, 0.75, -5);
    kart.name = "Kart";
    try kart.addComponent(try physics.Rigidbody.newWithData(allocator, .{ .world = &world }));
    try scene.add(kart);

    var i: f32 = 0;
    while (i < 7) { // rows front to back
        var j: f32 = 0;
        while (j < 5) { // cols left to right
            var kart2 = GameObject.createObject(allocator, "Mesh/Kart");
            kart2.position = Vec3.new(0.7 + (j * 8), 0.75, -8 - (i * 3));

            // lets decorate the kart based on its location
            kart2.material.ambient = Vec3.new(0.0, j * 0.001, 0.002);
            kart2.material.diffuse = Vec3.new(i * 0.1, j * 0.1, 0.6);

            // dull on the left, getting shinier to the right
            kart2.material.specular = Vec3.new(1.0 - (j * 0.2), 1.0 - (j * 0.2), 0.2);
            kart2.material.shininess = 110.0 - (j * 20.0);
            //try kart2.addComponent(try physics.Rigidbody.newWithData(allocator,.{.world=&world}));
            try scene.add(kart2);
            j += 1;
        }
        i += 1;
    }

    var light = GameObject.createObject(allocator, "Mesh/Cube");
    light.position = Vec3.new(1, 5, -5);
    light.material.ambient = Vec3.one;
    try light.addComponent(try TestLight.new(allocator));
    try light.addComponent(try PointLight.newWithData(allocator, .{}));
    try scene.add(light);
}

var gp: std.heap.GeneralPurposeAllocator(.{}) = .{};

pub fn main() !void {
    defer _ = gp.deinit();
    const allocator = &gp.allocator;
    var scene = try Scene.create(allocator, null);
    var app = Application{
        .title = "Test Cubes",
        .initFn = init
    };
    try app.run(allocator, scene);
}
