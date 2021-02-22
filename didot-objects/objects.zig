const graphics = @import("didot-graphics");
const zlm = @import("zlm");
const std = @import("std");

pub usingnamespace @import("assets.zig");
pub usingnamespace @import("components.zig");

const Mesh = graphics.Mesh;
const Window = graphics.Window;
const Material = graphics.Material;
const Allocator = std.mem.Allocator;

pub const GameObjectArrayList = std.ArrayList(*GameObject);
pub const ComponentMap = std.StringHashMap(Component);

/// Mesh of a plane.
pub var PrimitivePlaneMesh: Mesh = undefined;
/// Mesh of a cube.
pub var PrimitiveCubeMesh: Mesh = undefined;

pub fn createHeightmap(allocator: *Allocator, heightmap: [][]const f32) !Mesh {
    const height = heightmap.len;
    const width  = heightmap[0].len;
    const sqLen = 0.5;

    var vertices = try allocator.alloc(f32, width*height*(4*5)); // width*height*vertices*vertex size
    defer allocator.free(vertices);
    var elements = try allocator.alloc(graphics.MeshElementType, heightmap.len*height*6);
    defer allocator.free(elements);

    for (heightmap) |column, column_index| {
        for (column) |cell, row_index| {
            var pos: usize = (column_index*height+row_index)*(5*4);
            var x: f32 = @intToFloat(f32, row_index)*sqLen*2;
            var z: f32 = @intToFloat(f32, column_index)*sqLen*2;

            var trY: f32 = 0.0;
            var blY: f32 = 0.0;
            var brY: f32 = 0.0;
            if (column_index < height-1) trY = column[row_index+1];
            if (column_index > 0) blY = heightmap[column_index-1][column_index];
            if (column_index > 0 and column_index < width-1) brY = heightmap[column_index-1][column_index+1];

            vertices[pos] = x-sqLen; vertices[pos+1] = cell; vertices[pos+2] = z+sqLen; vertices[pos+3] = 0.0; vertices[pos+4] = 0.0; // top-left
            vertices[pos+5] = x-sqLen; vertices[pos+6] = blY; vertices[pos+7] = z-sqLen; vertices[pos+8] = 0.0; vertices[pos+9] = 1.0; // bottom-left
            vertices[pos+10] = x+sqLen; vertices[pos+11] = brY; vertices[pos+12] = z-sqLen; vertices[pos+13] = 1.0; vertices[pos+14] = 1.0; // bottom-right
            vertices[pos+15] = x+sqLen; vertices[pos+16] = trY; vertices[pos+17] = z+sqLen; vertices[pos+18] = 1.0; vertices[pos+19] = 0.0; // top-right

            var vecPos: graphics.MeshElementType = @intCast(graphics.MeshElementType, (column_index*height+row_index)*4);
            var elemPos: usize = (column_index*height+row_index)*6;
            elements[elemPos] = vecPos;
            elements[elemPos+1] = vecPos+1;
            elements[elemPos+2] = vecPos+2;
            elements[elemPos+3] = vecPos;
            elements[elemPos+4] = vecPos+3;
            elements[elemPos+5] = vecPos+2;
        }
    }

    return Mesh.create(vertices, elements);
}

/// This function must be called before primitive meshes (like PrimitiveCubeMesh) can be used.
/// Since it create meshes it must be called after the window context is set.
/// It is also automatically called by didot-app.Application
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

    // position, normal, tex coords
    // var cubeVert = [_]f32 {
    //     // front
    //     -0.5, 0.5, 0.5, 0.0, 0.0, 1.0, 0.0, 0.0, // upper left
    //     0.5, 0.5, 0.5, 0.0, 0.0, 1.0, 1.0, 0.0, // upper right
    //     0.5, -0.5, 0.5, 0.0, 0.0, 1.0, 1.0, 1.0, // bottom right
    //     -0.5, -0.5, 0.5, 0.0, 0.0, 1.0, 0.0, 1.0, // bottom left
    //     // bottom
    //     -0.5, -0.5, -0.5, 0.0, -1.0, 0.0, 0.0, 0.0, // bottom left
    //     0.5, -0.5, -0.5, 0.0, -1.0, 0.0, 1.0, 0.0, // bottom right
    //     // right
    //     -0.5, 0.5, -0.5, 1.0, 0.0, 1.0, 1.0, 0.0, // upper left
    //     -0.5, -0.5, -0.5, 1.0, 0.0, -1.0, 1.0, 1.0, // bottom left
    //     // left
    //     0.5, 0.5, -0.5, -1.0, 0.0, 0.0, 0.0, 0.0, // upper left
    //     0.5, -0.5, -0.5, -1.0, 0.0, 0.0, 0.0, 1.0, // bottom left
    //     // top
    //     -0.5, 0.5, -0.5, 0.0, 1.0, 0.0, 0.0, 1.0, // top left
    //     0.5, 0.5, -0.5, 0.0, 1.0, 0.0, 1.0, 1.0, // top right
    // };
    // var cubeElem = [_]graphics.MeshElementType {
    //     // front
    //     0, 1, 3,
    //     1, 3, 2,
    //     // bottom
    //     3, 2, 4,
    //     2, 5, 4,
    //     // right
    //     0, 3, 6,
    //     3, 6, 7,
    //     // left
    //     1, 2, 8,
    //     2, 8, 9,
    //     // top
    //     0, 1, 10,
    //     1, 11, 10,
    // };
    //PrimitiveCubeMesh = Mesh.create(cubeVert[0..], cubeElem[0..]);

    var cubeVert = [_]f32{
        // back
        -0.5, -0.5, -0.5,  0.0,  0.0, -1.0, 0.0, 0.0,
         0.5, -0.5, -0.5,  0.0,  0.0, -1.0, 1.0, 0.0,
         0.5,  0.5, -0.5,  0.0,  0.0, -1.0, 1.0, 1.0,
         0.5,  0.5, -0.5,  0.0,  0.0, -1.0, 1.0, 1.0,
        -0.5,  0.5, -0.5,  0.0,  0.0, -1.0, 0.0, 1.0,
        -0.5, -0.5, -0.5,  0.0,  0.0, -1.0, 0.0, 0.0,

        // front
        -0.5, -0.5,  0.5,  0.0,  0.0, 1.0, 0.0, 0.0,
         0.5, -0.5,  0.5,  0.0,  0.0, 1.0, 1.0, 0.0,
         0.5,  0.5,  0.5,  0.0,  0.0, 1.0, 1.0, 1.0,
         0.5,  0.5,  0.5,  0.0,  0.0, 1.0, 1.0, 1.0,
        -0.5,  0.5,  0.5,  0.0,  0.0, 1.0, 0.0, 1.0,
        -0.5, -0.5,  0.5,  0.0,  0.0, 1.0, 0.0, 0.0,

        // left
        -0.5,  0.5,  0.5, -1.0,  0.0,  0.0, 0.0, 1.0,
        -0.5,  0.5, -0.5, -1.0,  0.0,  0.0, 1.0, 1.0,
        -0.5, -0.5, -0.5, -1.0,  0.0,  0.0, 1.0, 0.0,
        -0.5, -0.5, -0.5, -1.0,  0.0,  0.0, 1.0, 0.0,
        -0.5, -0.5,  0.5, -1.0,  0.0,  0.0, 0.0, 0.0,
        -0.5,  0.5,  0.5, -1.0,  0.0,  0.0, 0.0, 1.0,

        // right
         0.5,  0.5,  0.5,  1.0,  0.0,  0.0, 0.0, 1.0,
         0.5,  0.5, -0.5,  1.0,  0.0,  0.0, 1.0, 1.0,
         0.5, -0.5, -0.5,  1.0,  0.0,  0.0, 1.0, 0.0,
         0.5, -0.5, -0.5,  1.0,  0.0,  0.0, 1.0, 0.0,
         0.5, -0.5,  0.5,  1.0,  0.0,  0.0, 0.0, 0.0,
         0.5,  0.5,  0.5,  1.0,  0.0,  0.0, 0.0, 1.0,

        // bottom
        -0.5, -0.5, -0.5,  0.0, -1.0,  0.0, 0.0, 0.0,
         0.5, -0.5, -0.5,  0.0, -1.0,  0.0, 0.0, 0.0,
         0.5, -0.5,  0.5,  0.0, -1.0,  0.0, 0.0, 0.0,
         0.5, -0.5,  0.5,  0.0, -1.0,  0.0, 0.0, 0.0,
        -0.5, -0.5,  0.5,  0.0, -1.0,  0.0, 0.0, 0.0,
        -0.5, -0.5, -0.5,  0.0, -1.0,  0.0, 0.0, 0.0,

        // top
        -0.5,  0.5, -0.5,  0.0,  1.0,  0.0, 0.0, 0.0,
         0.5,  0.5, -0.5,  0.0,  1.0,  0.0, 1.0, 0.0,
         0.5,  0.5,  0.5,  0.0,  1.0,  0.0, 1.0, 1.0,
         0.5,  0.5,  0.5,  0.0,  1.0,  0.0, 1.0, 1.0,
        -0.5,  0.5,  0.5,  0.0,  1.0,  0.0, 0.0, 1.0,
        -0.5,  0.5, -0.5,  0.0,  1.0,  0.0, 0.0, 0.0,
    };
    PrimitiveCubeMesh = Mesh.create(cubeVert[0..], null);
}

pub const GameObject = struct {
    // TODO: change to a Renderer component
    mesh: ?AssetHandle = null,
    name: []const u8 = "Game Object",
    components: ComponentMap,

    /// Type of object owning this game object ("camera", "scene", etc.)
    objectType: ?[]const u8 = null,
    /// Pointer to the struct of the object owning this game object.
    /// To save space, it must be considered null when objectType is null.
    objectPointer: usize = 0,
    /// The allocator used to create objectPointer, if any.
    objectAllocator: ?*Allocator = null,
    material: Material = Material.default,

    /// To be used for game objects entirely made of other game objects as childrens, or for script-only game objects.
    pub fn createEmpty(allocator: *Allocator) GameObject {
        return GameObject {
            .components = ComponentMap.init(allocator)
        };
    }

    /// The default kind of game object, it is renderable via its mesh and material.
    pub fn createObject(allocator: *Allocator, mesh: ?AssetHandle) !GameObject {
        var gameObject = GameObject {
            .mesh = mesh,
            .components = ComponentMap.init(allocator)
        };
        try gameObject.addComponent(Transform {});
        if (mesh != null) {
            // TODO: add Renderer
        }
        return gameObject;
    }

    // TODO: remove
    /// For cameras, scenes, etc.
    pub fn createCustom(allocator: *Allocator, customType: []const u8, ptr: usize) !GameObject {
        var gameObject = GameObject {
            .objectType = customType,
            .objectPointer = ptr,
            .objectAllocator = allocator,
            .components = ComponentMap.init(allocator)
        };
        try gameObject.addComponent(Transform {});
        return gameObject;
    }

    pub fn getComponent(self: *const GameObject, comptime T: type) ?*T {
        if (self.components.get(@typeName(T))) |cp| {
            return @intToPtr(*T, cp.data);
        } else {
            return null;
        }
    }

    pub fn hasComponent(self: *const GameObject, comptime T: type) bool {
        return self.getComponent(T) != null;
    }

    pub fn addComponent(self: *GameObject, component: anytype) !void {
        const wrapper = try Component.from(self.components.allocator, component);
        try self.components.put(wrapper.name, wrapper);
    }

    // TODO: move to Transform component (which will also include hierarchy)

    // pub fn findChild(self: *GameObject, name: []const u8) ?*GameObject {
    //     const held = self.treeLock.acquire();
    //     defer held.release();
    //     for (self.childrens.items) |child| {
    //         if (std.mem.eql(u8, child.name, name)) return child;
    //     }
    //     return null;
    // }

    // pub fn look(self: *GameObject, direction: zlm.Vec3, up: zlm.Vec3) void {
    //     // self.rotation.x = ((std.math.cos(direction.z)) * (std.math.cos(direction.x)) +1)* std.math.pi;
    //     // self.rotation.y = (std.math.cos(direction.y) + 1) * std.math.pi;
    //     // self.rotation.z = 0;
    //     // const mat = zlm.Mat4.createLook(self.position, direction, up);
    //     // self.rotation = mat.mulVec3(zlm.Vec3.new(0, 0, 1));
    //     // self.rotation.x = (self.rotation.x * self.rotation.z) * std.math.pi;
    //     // self.rotation.y = 0;
    //     // self.rotation.z = 0;

    //     var angle = std.math.atan2(f32, direction.y, direction.x);
        
    // }

    // pub fn lookAt(self: *GameObject, target: zlm.Vec3, up: zlm.Vec3) void {
    //     self.look(target.sub(self.position).normalize(), up);
    // }


    // pub fn add(self: *GameObject, go: GameObject) !void {
    //     const held = self.treeLock.acquire();
    //     defer held.release();
        
    //     var gameObject = try self.childrens.allocator.create(GameObject);
    //     gameObject.* = go;
    //     gameObject.parent = self;
    //     try self.childrens.append(gameObject);
    // }

    /// Frees childrens array list (not childrens themselves!), the object associated to it and itself.
    pub fn deinit(self: *GameObject) void {
        var iterator = self.components.iterator();
        while (iterator.next()) |entry| {
            var component = &entry.value;
            component.deinit();
        }
        self.components.deinit();
        const objectAllocator = self.objectAllocator;
        const objectPointer = self.objectPointer;
        if (objectAllocator) |alloc| {
            if (objectPointer != 0) {
                alloc.destroy(@intToPtr(*u8, objectPointer));
            }
        }
    }
};

pub const Projection = union(enum) {
    Perspective: struct {
        fov: f32,
        far: f32,
        near: f32
    },
    Orthographic: struct {
        left: f32,
        right: f32,
        bottom: f32,
        top: f32,
        far: f32,
        near: f32
    }
};

// pub const Camera = struct {
//     gameObject: GameObject,
//     shader: graphics.ShaderProgram,
//     skyboxShader: ?graphics.ShaderProgram,
//     projection: Projection,
//     priority: u32 = 0,

//     /// Memory is caller-owned (de-init must be called before)
//     pub fn create(allocator: *Allocator, shader: graphics.ShaderProgram) !*Camera {
//         var camera = try allocator.create(Camera);
//         var go = try GameObject.createCustom(allocator, "camera", @ptrToInt(camera));
//         go.getComponent(Transform).?.rotation = zlm.Vec3.new(zlm.toRadians(-90.0), 0, 0);
//         camera.gameObject = go;
//         camera.shader = shader;
//         camera.projection = .{
//             .Perspective = .{ .fov = 70, .far = 1000, .near = 0.1 }
//         };
//         return camera;
//     }

//     pub fn deinit(self: *Camera) void {
//         self.gameObject.deinit();
//     }
// };

pub const Skybox = struct {
    shader: graphics.ShaderProgram,
    cubemap: AssetHandle,
    mesh: AssetHandle
};

/// Camera component.
/// Add it to a GameObject for it to act as the camera.
pub const Camera = struct {
    shader: graphics.ShaderProgram,
    skybox: ?Skybox = null,
    priority: u32 = 0,
    projection: Projection = .{
        .Perspective = .{ .fov = 70, .far = 1000, .near = 0.1 }
    }
};

/// Point light component.
/// Add it to a GameObject for it to emit point light.
pub const PointLight = struct {
    /// The color emitted by the light
    color: graphics.Color = graphics.Color.one,
    /// Constant attenuation (the higher it is, the darker the light is)
    constant: f32 = 1.0,
    /// Linear attenuation
    linear: f32 = 0.018,
    /// Quadratic attenuation
    quadratic: f32 = 0.016
};

pub const Transform = struct {
    position: zlm.Vec3 = zlm.Vec3.zero,
    /// In order: roll, pitch, yaw. Angles are in radians.
    /// Note: this will be replaced with quaternions very soon!
    rotation: zlm.Vec3 = zlm.Vec3.zero,
    scale: zlm.Vec3 = zlm.Vec3.one,
    parent: ?*Transform = null,

    /// This functions returns the forward (the direction) vector of this game object using its rotation.
    pub fn getForward(self: *const Transform) zlm.Vec3 {
        const rot = self.rotation;
        return zlm.Vec3.new(
            std.math.cos(rot.x) * std.math.cos(rot.y),
            std.math.sin(rot.y),
            std.math.sin(rot.x) * std.math.cos(rot.y)
        );
    }

    /// This functions returns the left vector of this game object using its rotation.
    pub fn getLeft(self: *const Transform) zlm.Vec3 {
        const rot = self.rotation;
        return zlm.Vec3.new(
            -std.math.sin(rot.x),
            0,
            std.math.cos(rot.x)
        );
    }
};

//pub const Renderer2D = ComponentType(.Renderer2D, struct {}, .{}) {};

pub const Scene = struct {
    objects: GameObjectArrayList,
    /// The camera the scene is currently using.
    /// It is auto-detected at runtime before each render by looking
    /// on top-level game objects to select one that has a Camera component.
    camera: ?*GameObject,
    /// The skybox the scene is currently using.
    /// It is auto-detected at runtime before each render by looking
    /// on top-level game objects to select one that corresponds
    /// to the "skybox" type.
    skybox: ?*GameObject,
    pointLight: ?*GameObject,
    assetManager: AssetManager,
    allocator: *Allocator,
    /// Lock used when accesing the game object's tree
    treeLock: std.Thread.Mutex = .{},

    pub fn create(allocator: *Allocator, assetManager: ?AssetManager) !*Scene {
        var scene = try allocator.create(Scene);
        scene.allocator = allocator;
        scene.treeLock = .{};
        scene.objects = GameObjectArrayList.init(allocator);
        if (assetManager) |mg| {
            scene.assetManager = mg;
        } else {
            scene.assetManager = AssetManager.init(allocator);
        }
        return scene;
    }

    pub fn loadFromFile(allocator: *Allocator, path: []const u8) !Scene {
        const file = try std.fs.cwd().openFile(path, .{ .read = true });
        defer file.close();

        const text = try reader.readAllAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(text);

        return Scene.loadFromMemory(allocator, text);
    }

    pub fn loadFromMemory(allocator: *Allocator, json: []const u8) !Scene {
        std.debug.warn("{s}\n", .{json});
    }

    fn renderCommon(self: *Scene) void {
        var childs: GameObjectArrayList = self.objects;

        // TODO: only do this when a new child is inserted
        self.camera = null;
        self.skybox = null;
        self.pointLight = null;

        var held = self.treeLock.acquire();
        for (childs.items) |child| {
            if (child.objectType) |objectType| {
                if (std.mem.eql(u8, objectType, "skybox")) {
                    self.skybox = child;
                }
            }
            if (child.hasComponent(PointLight)) {
                self.pointLight = child;
            }
            if (child.getComponent(Camera)) |cam| {
                if (self.camera) |currentCam| {
                    if (cam.priority < currentCam.getComponent(Camera).?.priority) continue;
                }
                self.camera = child;
            }
        }
        held.release();
    }

    pub fn renderOffscreen(self: *Scene, viewport: zlm.Vec4) !void {
        self.renderCommon();
        try graphics.renderSceneOffscreen(self, viewport);
    }

    pub fn render(self: *Scene, window: Window) !void {
        self.renderCommon();
        try graphics.renderScene(self, window);
    }

    pub fn add(self: *Scene, go: GameObject) !void {
        const held = self.treeLock.acquire();
        defer held.release();
        
        var gameObject = try self.objects.allocator.create(GameObject);
        gameObject.* = go;
        try self.objects.append(gameObject);
    }

    pub fn findChild(self: *Scene, name: []const u8) ?*GameObject {
        const held = self.treeLock.acquire();
        defer held.release();
        for (self.objects.items) |child| {
            if (std.mem.eql(u8, child.name, name)) return child;
        }
        return null;
    }

    pub fn deinit(self: *Scene) void {
        self.assetManager.deinit();
        for (self.objects.items) |child| {
            child.deinit();
            self.objects.allocator.destroy(child);
        }
        self.objects.deinit();
        self.allocator.destroy(self);
    }

    pub fn deinitAll(self: *Scene) void {
        self.assetManager.deinit();
        for (self.objects.items) |child| {
            child.deinit();
            self.objects.allocator.destroy(child);
        }
        self.objects.deinit();
        self.allocator.destroy(self);
    }
};

// Tests
const expect = std.testing.expect;

test "empty gameobject" {
    var alloc = std.heap.page_allocator;
    var go = GameObject.createEmpty(alloc);
    //expect(go.childrens.items.len == 0);
    //expect(go.objectType == null);
}

test "empty asset" {
    var scene = try Scene.create(std.testing.allocator, null);
    var mgr = scene.assetManager;
    std.testing.expectEqual(false, mgr.has("azerty"));
    scene.deinit();
}

test "default camera" {
    // var alloc = std.heap.page_allocator;
    // var cam = try Camera.create(alloc, undefined);
    // expect(cam.projection.Perspective.fov == 70); // default FOV
    // expect(cam.gameObject.objectType != null);
    // std.testing.expectEqualStrings("camera", cam.gameObject.objectType.?);
    // cam.deinit();
}

comptime {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(GameObject);
}
