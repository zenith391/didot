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

/// Material must be set manually.
/// Memory is caller owned
/// initPrimitives() must have been called before calling this function!
pub fn createSkybox(allocator: *Allocator) !GameObject {
    var go = GameObject.createCustom(allocator, "skybox", 0);
    return go;
}

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
    //mesh: ?Mesh = null,
    mesh: ?AssetHandle = null,
    name: []const u8 = "Game Object",
    position: zlm.Vec3 = zlm.Vec3.zero,
    /// In order: roll, pitch, yaw. Angles are in radians.
    /// Note: this will be replaced with quaternions very soon!
    rotation: zlm.Vec3 = zlm.Vec3.zero,
    scale: zlm.Vec3 = zlm.Vec3.one,
    childrens: GameObjectArrayList,
    components: ComponentMap,

    /// Type of object owning this game object ("camera", "scene", etc.)
    objectType: ?[]const u8 = null,
    /// Pointer to the struct of the object owning this game object.
    /// To save space, it must be considered null when objectType is null.
    objectPointer: usize = 0,
    /// The allocator used to create objectPointer, if any.
    objectAllocator: ?*Allocator = null,
    material: Material = Material.default,
    /// Lock used when accesing the game object's tree
    treeLock: std.Thread.Mutex = .{},
    parent: ?*GameObject = null,

    /// To be used for game objects entirely made of other game objects as childrens, or for script-only game objects.
    pub fn createEmpty(allocator: *Allocator) GameObject {
        var childs = GameObjectArrayList.init(allocator);
        return GameObject {
            .childrens = childs,
            .components = ComponentMap.init(allocator)
        };
    }

    /// The default kind of game object, it is renderable via its mesh and material.
    pub fn createObject(allocator: *Allocator, mesh: ?AssetHandle) GameObject {
        var childs = GameObjectArrayList.init(allocator);
        return GameObject {
            .childrens = childs,
            .mesh = mesh,
            .components = ComponentMap.init(allocator)
        };
    }

    /// For cameras, scenes, etc.
    pub fn createCustom(allocator: *Allocator, customType: []const u8, ptr: usize) GameObject {
        var childs = GameObjectArrayList.init(allocator);
        return GameObject {
            .childrens = childs,
            .objectType = customType,
            .objectPointer = ptr,
            .objectAllocator = allocator,
            .components = ComponentMap.init(allocator)
        };
    }

    pub fn update(self: *GameObject, allocator: *Allocator, delta: f32) anyerror!void {
        var iterator = self.components.iterator();
        while (iterator.next()) |entry| {
            var component = &entry.value;
            component.gameObject = self;
            try component.update(allocator, delta);
        }

        // The length is set in advance to avoid problems when adding a game object while updating
        const len = self.childrens.items.len;
        var copy = self.childrens;
        var i: usize = 0;
        while (i < len) : (i += 1) {
            const child = self.childrens.items[i];
            child.parent = self;
            try child.update(allocator, delta); // TODO: correctly handle errors
        }
    }

    pub fn findChild(self: *GameObject, name: []const u8) ?*GameObject {
        const held = self.treeLock.acquire();
        defer held.release();
        for (self.childrens.items) |child| {
            if (std.mem.eql(u8, child.name, name)) return child;
        }
        return null;
    }

    pub fn findComponent(self: *const GameObject, comptime name: @Type(.EnumLiteral)) ?*Component {
        if (self.components.get(@tagName(name))) |*cp| {
            return cp;
        } else {
            return null;
        }
    }

    pub fn hasComponent(self: *const GameObject, comptime name: @Type(.EnumLiteral)) bool {
        return self.findComponent(name) != null;
    }

    /// This functions returns the forward (the direction) vector of this game object using its rotation.
    pub fn getForward(self: *const GameObject) zlm.Vec3 {
        const rot = self.rotation;
        return zlm.Vec3.new(
            std.math.cos(rot.x) * std.math.cos(rot.y),
            std.math.sin(rot.y),
            std.math.sin(rot.x) * std.math.cos(rot.y)
        );
    }

    /// This functions returns the left vector of this game object using its rotation.
    pub fn getLeft(self: *const GameObject) zlm.Vec3 {
        const rot = self.rotation;
        return zlm.Vec3.new(
            -std.math.sin(rot.x),
            0,
            std.math.cos(rot.x)
        );
    }

    pub fn look(self: *GameObject, direction: zlm.Vec3, up: zlm.Vec3) void {
        // self.rotation.x = ((std.math.cos(direction.z)) * (std.math.cos(direction.x)) +1)* std.math.pi;
        // self.rotation.y = (std.math.cos(direction.y) + 1) * std.math.pi;
        // self.rotation.z = 0;
        // const mat = zlm.Mat4.createLook(self.position, direction, up);
        // self.rotation = mat.mulVec3(zlm.Vec3.new(0, 0, 1));
        // self.rotation.x = (self.rotation.x * self.rotation.z) * std.math.pi;
        // self.rotation.y = 0;
        // self.rotation.z = 0;

        var angle = std.math.atan2(f32, direction.y, direction.x);
        
    }

    pub fn lookAt(self: *GameObject, target: zlm.Vec3, up: zlm.Vec3) void {
        self.look(target.sub(self.position).normalize(), up);
    }

    /// Add a game object as children to this game object.
    pub fn add(self: *GameObject, go: GameObject) !void {
        const held = self.treeLock.acquire();
        defer held.release();
        
        var gameObject = try self.childrens.allocator.create(GameObject);
        gameObject.* = go;
        gameObject.parent = self;
        try self.childrens.append(gameObject);
    }

    pub fn addComponent(self: *GameObject, cp: Component) !void {
        try self.components.put(cp.getName(), cp);
    }

    /// Frees childrens array list (not childrens themselves!), the object associated to it and itself.
    pub fn deinit(self: *GameObject) void {
        const allocator = self.childrens.allocator;
        self.childrens.deinit();
        var iterator = self.components.iterator();
        while (iterator.next()) |entry| {
            var component = &entry.value;
            component.deinit();
        }
        self.components.deinit();
        const objectAllocator = self.objectAllocator;
        const objectPointer = self.objectPointer;
        if (self.parent != null) {
            allocator.destroy(self);
        }
        if (objectAllocator) |alloc| {
            if (objectPointer != 0) {
                alloc.destroy(@intToPtr(*u8, objectPointer));
            }
        }
    }

    /// De-init the game object and its children (recursive deinit)
    pub fn deinitAll(self: *GameObject) void {
        const held = self.treeLock.acquire();
        for (self.childrens.items) |child| {
            child.deinitAll();
        }
        held.release();
        self.deinit();
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

pub const Camera = struct {
    gameObject: GameObject,
    viewMatrix: zlm.Mat4,
    shader: graphics.ShaderProgram,
    skyboxShader: ?graphics.ShaderProgram,
    projection: Projection,
    priority: u32 = 0,

    /// Memory is caller-owned (de-init must be called before)
    pub fn create(allocator: *Allocator, shader: graphics.ShaderProgram) !*Camera {
        var camera = try allocator.create(Camera);
        var go = GameObject.createCustom(allocator, "camera", @ptrToInt(camera));
        go.rotation = zlm.Vec3.new(zlm.toRadians(-90.0), 0, 0);
        camera.gameObject = go;
        camera.shader = shader;
        camera.projection = .{
            .Perspective = .{ .fov = 70, .far = 1000, .near = 0.1 }
        };
        return camera;
    }

    pub fn deinit(self: *Camera) void {
        self.gameObject.deinit();
    }
};

pub const PointLightData = struct {
    /// The color emitted by the light
    color: graphics.Color = graphics.Color.one,
    /// Constant attenuation (the higher it is, the darker the light is)
    constant: f32 = 1.0,
    /// Linear attenuation
    linear: f32 = 0.018,
    /// Quadratic attenuation
    quadratic: f32 = 0.016
};

/// Point light component.
/// Add it to a GameObject for it to emit point light.
pub const PointLight = ComponentType(.PointLight, PointLightData, .{}) {};

pub const Renderer2D = ComponentType(.Renderer2D, struct {}, .{}) {};

pub const Scene = struct {
    gameObject: GameObject,
    /// The camera the scene is currently using.
    /// It is auto-detected at runtime before each render by looking
    /// on top-level game objects to select one that corresponds
    /// to the "camera" type.
    camera: ?*Camera,
    /// The skybox the scene is currently using.
    /// It is auto-detected at runtime before each render by looking
    /// on top-level game objects to select one that corresponds
    /// to the "skybox" type.
    skybox: ?*GameObject,
    pointLight: ?*GameObject,
    assetManager: AssetManager,
    allocator: *Allocator,

    pub fn create(allocator: *Allocator, assetManager: ?AssetManager) !*Scene {
        var scene = try allocator.create(Scene);
        scene.gameObject = GameObject.createEmpty(allocator);
        scene.allocator = allocator;
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
        var childs: GameObjectArrayList = self.gameObject.childrens;

        // TODO: only do this when a new child is inserted
        self.camera = null;
        self.skybox = null;
        self.pointLight = null;

        var held = self.gameObject.treeLock.acquire();
        for (childs.items) |child| {
            if (child.objectType) |objectType| {
                if (std.mem.eql(u8, objectType, "camera")) {
                    const cam = @intToPtr(*Camera, child.objectPointer);
                    if (self.camera) |currentCam| {
                        if (cam.priority < currentCam.priority) continue;
                    }
                    self.camera = cam;
                    self.camera.?.gameObject = child.*;
                } else if (std.mem.eql(u8, objectType, "skybox")) {
                    self.skybox = child;
                }
            }
            if (child.hasComponent(.PointLight)) {
                self.pointLight = child;
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
        try self.gameObject.add(go);
    }

    pub fn findChild(self: *const Scene, name: []const u8) ?*GameObject {
        return self.gameObject.findChild(name);
    }

    pub fn deinit(self: *Scene) void {
        self.assetManager.deinit();
        self.gameObject.deinit();
        self.allocator.destroy(self);
    }

    pub fn deinitAll(self: *Scene) void {
        self.assetManager.deinit();
        self.gameObject.deinitAll();
        self.allocator.destroy(self);
    }
};

// Tests
const expect = std.testing.expect;

test "empty gameobject" {
    var alloc = std.heap.page_allocator;
    var go = GameObject.createEmpty(alloc);
    expect(go.childrens.items.len == 0);
    expect(go.objectType == null);
}

test "empty asset" {
    var scene = try Scene.create(std.testing.allocator, null);
    var mgr = scene.assetManager;
    std.testing.expectEqual(false, mgr.has("azerty"));
    scene.deinit();
}

test "default camera" {
    var alloc = std.heap.page_allocator;
    var cam = try Camera.create(alloc, undefined);
    expect(cam.projection.Perspective.fov == 70); // default FOV
    expect(cam.gameObject.objectType != null);
    std.testing.expectEqualStrings("camera", cam.gameObject.objectType.?);
    cam.deinit();
}

comptime {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(GameObject);
}
