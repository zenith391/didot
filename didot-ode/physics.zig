const std = @import("std");
const zlm = @import("zlm");
const objects = @import("didot-objects");
usingnamespace @cImport({
    @cDefine("dSINGLE", "1");
    @cInclude("ode/ode.h");
});

const Allocator = std.mem.Allocator;
const Component = objects.Component;
const GameObject = objects.GameObject;

var isOdeInit: bool = false;
const logger = std.log.scoped(.didotphysics);

var odeThread: std.Thread.Id = -1;

fn ensureInit() void {
    if (!isOdeInit) {
        _ = dInitODE2(0);
        const conf = @ptrCast([*:0]const u8, dGetConfiguration());
        logger.debug("Initialized ODE.", .{});
        logger.debug("ODE configuration: {}", .{conf});
        isOdeInit = true;
    }
}

pub const World = struct {
    id: dWorldID,
    space: dSpaceID,
    /// Group for contact joints.
    contactGroup: dJointGroupID,

    pub fn create() World {
        ensureInit();
        return World {
            .id = dWorldCreate(),
            .space = dHashSpaceCreate(null),
            .contactGroup = dJointGroupCreate(0)
        };
    }

    export fn nearCallback(data: ?*c_void, o1: dGeomID, o2: dGeomID) void {
        const b1 = dGeomGetBody(o1);
        const b2 = dGeomGetBody(o2);
        const self = @ptrCast(*World, @alignCast(@alignOf(World), data.?));

        var contact: dContact = undefined;
        contact.surface.mode = dContactBounce | dContactSoftCFM;
        contact.surface.mu = std.math.inf(dReal);
        contact.surface.bounce = 0.5;
        contact.surface.bounce_vel = 0.2;
        contact.surface.soft_cfm = 0.001;
        const numc = dCollide(o1, o2, 1, &contact.geom, @sizeOf(dContact));
        if (numc != 0) {
            const c = dJointCreateContact(self.id, self.contactGroup, &contact);
            dJointAttach(c, b1, b2);
        }
    }

    pub fn setGravity(self: *World, gravity: zlm.Vec3) void {
        dWorldSetGravity(self.id, gravity.x, gravity.y, gravity.z);
        dWorldSetCFM(self.id, 0.00001);
    }

    pub fn update(self: *World) void {
        dSpaceCollide(self.space, self, nearCallback);
        _ = dWorldStep(self.id, 0.0167);
        dJointGroupEmpty(self.contactGroup);
    }

    pub fn deinit(self: *const World) void {
        dWorldDestroy(self.id);
    }
};

pub const KinematicState = enum {
    Dynamic,
    Kinematic
};

pub const RigidbodyData = struct {
    inited: bool = false,
    world: *World,
    body: dBodyID = undefined,
    geom: dGeomID = undefined,
    kinematic: KinematicState = .Dynamic
};
pub const Rigidbody = objects.ComponentType(.Rigidbody, RigidbodyData, .{ .updateFn = rigidbodyUpdate }) {};

fn quatToEuler(q: [*]const dReal) zlm.Vec3 {
    var angles = zlm.Vec3.new(0, 0, 0);
    const sinr_cosp = 2.0 * (q[0] * q[1] + q[2] * q[3]);
    const cosr_cosp = 1.0 - 2.0 * (q[1] * q[1] + q[2] * q[2]);
    angles.x = std.math.atan2(dReal, sinr_cosp, cosr_cosp);

    const sinp = 2.0 * (q[0] * q[2] - q[3] * q[1]);
    angles.y = if (std.math.fabs(sinp) >= 1) std.math.copysign(dReal, std.math.pi / 2.0, sinp) else std.math.asin(sinp);

    const siny_cosp = 2.0 * (q[0] * q[3] + q[1] * q[2]);
    const cosy_cosp = 1.0 - 2.0 * (q[2] * q[2] + q[3] * q[3]);
    angles.z = std.math.atan2(dReal, siny_cosp, cosy_cosp);

    return angles;
}

fn rigidbodyUpdate(allocator: *Allocator, component: *Component, gameObject: *GameObject, delta: f32) !void {
    const data = component.getData(RigidbodyData);
    if (!data.inited) {
        std.debug.warn("Init rigidbody!\n", .{});
        data.body = dBodyCreate(data.world.id);
        data.geom = dCreateBox(data.world.space, 1.0, 1.0, 1.0);
        dGeomSetBody(data.geom, data.body);
        dBodySetPosition(data.body, gameObject.position.x, gameObject.position.y, gameObject.position.z);
        dBodySetData(data.body, data);
        data.inited = true;
    }
    switch (data.kinematic) {
        .Dynamic => dBodySetDynamic(data.body),
        .Kinematic => dBodySetKinematic(data.body)
    }
    const scale = gameObject.scale;
    dGeomBoxSetLengths(data.geom, scale.x, scale.y, scale.z);
    const pos = dBodyGetPosition(data.body);
    const rot = quatToEuler(dBodyGetQuaternion(data.body));
    gameObject.rotation = rot;
    gameObject.position = zlm.Vec3.new(pos[0], pos[1], pos[2]);
}
