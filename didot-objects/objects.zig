const graphics = @import("didot-graphics");
const zlm = @import("zlm");
const std = @import("std");

const Mesh = graphics.Mesh;
const Window = graphics.Window;
const Material = graphics.Material;
const Allocator = std.mem.Allocator;

pub const GameObjectArrayList = std.ArrayList(GameObject);

// Must *NOT* be used before initPrimitives() is called.
pub var PrimitivePlaneMesh: Mesh = undefined;
pub var PrimitiveCubeMesh: Mesh = undefined;

pub fn initPrimitives() void {
    var planeVert = [_]f32 {
        -0.5, 0.5, 0.0, 0.0, 0.0,
        0.5, 0.5, 0.0, 1.0, 0.0,
        0.5, -0.5, 0.0, 1.0, 1.0,
        -0.5, -0.5, 0.0, 0.0, 1.0
    };
    var planeElem = [_]graphics.MeshElementType {
        0, 1, 2,
        2, 3, 0
    };
    PrimitivePlaneMesh = Mesh.create(planeVert[0..], planeElem[0..]);

    var cubeVert = [_]f32 {
        // front
        -0.5, 0.5, 0.5, 0.0, 0.0, // upper left
        0.5, 0.5, 0.5, 1.0, 0.0, // upper right
        0.5, -0.5, 0.5, 1.0, 1.0, // bottom right
        -0.5, -0.5, 0.5, 0.0, 1.0, // bottom left
        // bottom
        -0.5, -0.5, -0.5, 0.0, 0.0, // bottom left
        0.5, -0.5, -0.5, 1.0, 0.0, // bottom right
        // right
        -0.5, 0.5, -0.5, 1.0, 0.0, // upper left
        -0.5, -0.5, -0.5, 1.0, 1.0, // bottom left
        // left
        0.5, 0.5, -0.5, 0.0, 0.0, // upper left
        0.5, -0.5, -0.5, 0.0, 1.0, // bottom left
        // top
        -0.5, 0.5, -0.5, 0.0, 1.0, // top left
        0.5, 0.5, -0.5, 1.0, 1.0, // top right
    };
    var cubeElem = [_]graphics.MeshElementType {
        // front
        0, 1, 3,
        1, 3, 2,
        // bottom
        3, 2, 4,
        2, 5, 4,
        // right
        0, 3, 6,
        3, 6, 7,
        // left
        1, 2, 8,
        2, 8, 9,
        // top
        0, 1, 10,
        1, 11, 10,
    };
    PrimitiveCubeMesh = Mesh.create(cubeVert[0..], cubeElem[0..]);
}

pub const GameObject = struct {
    mesh: ?Mesh = null,
    /// Functions called regularly depending on the updateTarget value of the Application.
    updateFn: ?fn(allocator: *Allocator, gameObject: *GameObject, delta: f32) anyerror!void = null,
    // Model matrix
    matrix: zlm.Mat4,
    position: zlm.Vec3 = zlm.Vec3.zero,
    scale: zlm.Vec3 = zlm.Vec3.one,
    childrens: GameObjectArrayList,

    /// Type of object owning this game object ("camera", "scene", etc.)
    objectType: ?[]const u8 = null,
    /// Pointer to the struct of the object owning this game object.
    objectPointer: usize = 0,
    material: Material = Material.default,

    pub fn createEmpty(allocator: *Allocator) GameObject {
        var childs = GameObjectArrayList.init(allocator);
        var matrix = zlm.Mat4.identity;
        return GameObject {
            .matrix = matrix,
            .childrens = childs
        };
    }

    pub fn createObject(allocator: *Allocator, mesh: Mesh) GameObject {
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

    pub fn update(self: *GameObject, allocator: *Allocator, delta: f32) anyerror!void {
        if (self.updateFn) |func| {
            try func(allocator, self, delta);
        }
        for (self.childrens.items) |*child| {
            try child.update(allocator, delta); // TODO: correctly handle errors
        }
    }

    pub fn add(self: *GameObject, go: GameObject) !void {
        try self.childrens.append(go);
    }

    pub fn deinit(self: *const GameObject) void {
        self.childrens.deinit();
    }
};

pub const Camera = struct {
    fov: f32 = 70,
    yaw: f32 = zlm.toRadians(-90.0),
    pitch: f32 = 0,
    gameObject: GameObject,
    viewMatrix: zlm.Mat4,
    shader: graphics.ShaderProgram,

    /// Memory is caller-owned (to free, deinit must be called then the object must be freed)
    pub fn create(allocator: *Allocator, shader: graphics.ShaderProgram) !*Camera {
        var camera = try allocator.create(Camera);
        var go = GameObject.createCustom(allocator, "camera", @ptrToInt(camera));
        camera.gameObject = go;
        camera.shader = shader;
        camera.fov = 70;
        camera.yaw = zlm.toRadians(-90.0);
        camera.pitch = 0;

        return camera;
    }

    pub fn render() void {

    }

    pub fn deinit(self: *const Camera) void {
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
            if (child.objectType) |objectType| {
                if (std.mem.eql(u8, objectType, "camera")) {
                    self.camera = @intToPtr(*Camera, child.objectPointer);
                    self.camera.?.gameObject = child;
                    break;
                }
            }
        }

        graphics.renderScene(self, window);
    }

    pub fn add(self: *Scene, go: GameObject) !void {
        try self.gameObject.add(go);
    }

    pub fn deinit(self: *const Scene) void {
        self.gameObject.deinit();
    }
};
