const graphics = @import("didot-graphics");
const zlm = @import("zlm");
const std = @import("std");
const Mesh = graphics.Mesh;
const Window = graphics.Window;
const Allocator = std.mem.Allocator;

pub const GameObjectArrayList = std.ArrayList(GameObject);

pub const GameObject = struct {
    mesh: ?Mesh = null,
    /// Functions called regularly depending on the updateTarget value of the Application.
    updateFn: ?fn(delta: f32) void = null,
    // Model matrix
    matrix: zlm.Mat4,
    childrens: GameObjectArrayList,

    /// Type of object owning this game object ("camera", "scene", etc.)
    objectType: []const u8,
    /// Pointer to the struct of the object owning this game object.
    objectPointer: usize,

    pub fn createEmpty(allocator: *Allocator) GameObject {
        var childs = GameObjectArrayList.init(allocator);
        var matrix = zlm.Mat4.identity;
        return GameObject {
            .matrix = matrix,
            .childrens = childs
        };
    }

    pub fn createObject(allocator: *Allocator, mesh: ?Mesh) GameObject {
        var childs = GameObjectArrayList.init(allocator);
        var matrix = zlm.Mat4.identity;
        return GameObject {
            .matrix = matrix,
            .childrens = childs,
            .mesh = mesh
        };
    }

    /// For cameras, scenes, etc.
    pub fn createCustom(allocator: *Allocator, customType: []const u8, ptr: usize) GameObject {
        var childs = GameObjectArrayList.init(allocator);
        var matrix = zlm.Mat4.identity;
        return GameObject {
            .matrix = matrix,
            .childrens = childs,
            .objectType = customType,
            .objectPointer = ptr
        };
    }

    pub fn add(self: *GameObject, go: GameObject) !void {
        try self.childrens.append(go);
    }

    pub fn deinit(self: *GameObject) void {

    }
};

pub const Camera = struct {
    fov: f32 = 70,
    position: zlm.Vec3,
    yaw: f32 = zlm.toRadians(-90.0),
    pitch: f32 = 0,
    gameObject: GameObject,
    viewMatrix: zlm.Mat4,
    shader: graphics.ShaderProgram,

    /// Memory is caller-owned (to free, deinit must be called then the object must be freed)
    pub fn create(allocator: *Allocator) !*Camera {
        var camera = try allocator.create(Camera);
        camera.position = zlm.Vec3.zero;
        camera.gameObject = GameObject.createCustom(allocator, "camera", @ptrToInt(camera));

        return camera;
    }

    pub fn render() void {

    }

    pub fn deinit(self: *Camera) void {
        self.gameObject.deinit();
    }
};

pub const Scene = struct {
    gameObject: GameObject,
    /// The camera the scene is currently using
    camera: ?*Camera,

    pub fn create(allocator: *Allocator) !*Scene {
        var scene = try allocator.create(Scene);
        scene.gameObject = GameObject.createCustom(allocator, "scene", @ptrToInt(scene));
        return scene;
    }

    pub fn render(self: *Scene, window: Window) void {
        var childs: GameObjectArrayList = self.gameObject.childrens;

        // TODO: only do this when a new child is inserted
        self.camera = null;
        for (childs.items) |child| {
            if (std.mem.eql(u8, child.objectType, "camera")) {
                self.camera = @intToPtr(*Camera, child.objectPointer);
                break;
            }
        }

        graphics.renderScene(self, window);
    }

    pub fn add(self: *Scene, go: GameObject) !void {
        try self.gameObject.add(go);
    }

    pub fn deinit(self: *Scene) void {
        self.gameObject.deinit();
    }
};
