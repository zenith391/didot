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
    lastStep: i64,
    accumulatedStep: f64 = 0.0,

    pub fn create() World {
        ensureInit();
        return World {
            .id = dWorldCreate(),
            .space = dHashSpaceCreate(null),
            .contactGroup = dJointGroupCreate(0),
            .lastStep = std.time.milliTimestamp()
        };
    }

    export fn nearCallback(data: ?*c_void, o1: dGeomID, o2: dGeomID) void {
        const b1 = dGeomGetBody(o1);
        const b2 = dGeomGetBody(o2);
        const self = @ptrCast(*World, @alignCast(@alignOf(World), data.?));

        var contact: dContact = undefined;
        contact.surface.mode = dContactBounce;
        contact.surface.mu = std.math.inf(dReal);
        contact.surface.bounce = 0.2;
        contact.surface.bounce_vel = 10;
        contact.surface.soft_cfm = 0.1;
        const numc = dCollide(o1, o2, 1, &contact.geom, @sizeOf(dContact));
        if (numc != 0) {
            const c = dJointCreateContact(self.id, self.contactGroup, &contact);
            dJointAttach(c, b1, b2);
        }
    }

    pub fn setGravity(self: *World, gravity: zlm.Vec3) void {
        dWorldSetGravity(self.id, gravity.x, gravity.y, gravity.z);
        dWorldSetERP(self.id, 0.1);
        //dWorldSetCFM(self.id, 0.0000);
    }

    pub fn update(self: *World) void {
        self.accumulatedStep += @intToFloat(f64, std.time.milliTimestamp())/1000 - @intToFloat(f64, self.lastStep)/1000;
        if (self.accumulatedStep > 0.1) self.accumulatedStep = 0.1;
        const timeStep = 0.01;
        while (self.accumulatedStep > timeStep) {
            dSpaceCollide(self.space, self, nearCallback);
            _ = dWorldQuickStep(self.id, timeStep);
            dJointGroupEmpty(self.contactGroup);
            self.accumulatedStep -= timeStep;
        }
        self.lastStep = std.time.milliTimestamp();
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
    mass: dMass = undefined,
    kinematic: KinematicState = .Dynamic,

    pub fn addForce(self: *RigidbodyData, force: zlm.Vec3) void {
        dBodyAddForce(self.body, force.x, force.y, force.z);
    }
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
        dMassSetBox(&data.mass, 1.0, 1.0, 1.0, 1.0);
        dGeomSetBody(data.geom, data.body);
        dBodySetPosition(data.body, gameObject.position.x, gameObject.position.y, gameObject.position.z);
        dBodySetData(data.body, data);
        dBodySetMass(data.body, &data.mass);
        dBodySetDamping(data.body, 0.001, 0.001);
        dBodySetAutoDisableFlag(data.body, 1);
        data.inited = true;
    }
    if (dBodyIsEnabled(data.body) != 0) {
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
}
