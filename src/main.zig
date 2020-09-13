const std = @import("std");
const zlm = @import("zlm");
const Vec3 = zlm.Vec3;

const graphics = @import("didot-graphics");
const objects = @import("didot-objects");
const bmp = @import("didot-image").bmp;
const Application = @import("didot-app").Application;

const Texture = graphics.Texture;
const Window = graphics.Window;
const ShaderProgram = graphics.ShaderProgram;
const Material = graphics.Material;

const GameObject = objects.GameObject;
const Scene = objects.Scene;
const Camera = objects.Camera;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var scene = try Scene.create(allocator);

    var app = Application {};
    try app.init(scene);

    var shader = try ShaderProgram.create(@embedFile("vert.glsl"), @embedFile("frag.glsl"));

    var camera = try Camera.create(allocator, shader);
    camera.gameObject.position = Vec3.new(1.5, 1.5, -0.5);
    camera.pitch = zlm.toRadians(-15.0);
    camera.yaw = zlm.toRadians(-120.0);
    try scene.add(camera.gameObject);

    var cube = GameObject.createObject(allocator, objects.PrimitiveCubeMesh);
    cube.position = Vec3.new(0, 0.75, -3);
    var img = try bmp.read_bmp(allocator, "grass.bmp");
    var tex = Texture.create(img);
    var material = Material {
        .texture = tex
    };
    cube.material = material;
    try scene.add(cube);

    var cube2 = GameObject.createObject(allocator, objects.PrimitiveCubeMesh);
    cube2.position = Vec3.new(-1.2, 0.75, -3);
    try scene.add(cube2);

    var inputController = GameObject.createEmpty(allocator);

    app.loop();
}
