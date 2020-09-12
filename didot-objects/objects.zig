const graphics = @import("didot-graphics");
const zlm = @import("zlm");
const std = @import("std");
const Mesh = graphics.Mesh;

pub const GameObjectArrayList = std.ArrayList(GameObject);

pub const GameObject = struct {
    mesh: ?Mesh = null,
    /// Functions called regularly depending on the updateTarget value of the Application.
    updateFn: ?fn(delta: f32) void = null,
    // Model matrix
    matrix: zlm.Mat4,
    childrens: GameObjectArrayList,

    pub fn create(allocator: *Allocator, mesh: ?Mesh) GameObject {
    	var childs = GameObjectArrayList.init(allocator);
    	var matrix = zlm.Mat4.identity;
    	return GameObject {
    		.matrix = matrix,
    		.childrens = childs,
    		.mesh = mesh
    	};
    }
};

pub const Camera = struct {
    fov: f32 = 70,
    position: Vec3,
    yaw: f32 = zlm.toRadians(-90.0),
    pitch: f32 = 0,
    gameObject: GameObject,
    viewMatrix: Mat4,

    pub fn create(allocator: *Allocator) Camera {
    	var go = GameObject.create(allocator, null);
    	
    	return Camera {
    		.gameObject = go,
    		.position = Vec3.zero
    	};
    }
};
