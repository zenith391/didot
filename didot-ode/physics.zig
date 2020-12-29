const std = @import("std");
const zlm = @import("zlm");
const objects = @import("didot-objects");
const c = @cImport({
    @cDefine("dSINGLE", "1");
    @cInclude("ode/ode.h");
});

const Allocator = std.mem.Allocator;
const Component = objects.Component;
const GameObject = objects.GameObject;

var isOdeInit: bool = false;
const logger = std.log.scoped(.didotphysics);

var odeThread: ?std.Thread.Id = null;

fn ensureInit() void {
    if (!isOdeInit) {
        _ = c.dInitODE2(0);
        const conf = @ptrCast([*:0]const u8, c.dGetConfiguration());
        logger.debug("Initialized ODE.", .{});
        logger.debug("ODE configuration: {}", .{conf});
        isOdeInit = true;
    }
}

/// A physical world in which the physics simulation happen.
pub const World = struct {
    /// Internal value (ODE dWorldID)
    id: c.dWorldID,
    /// Internal value (ODE dSpaceID)
    space: c.dSpaceID,
    /// Internal value (ODE dJointGroupID)
    /// Used internally as a group for contact joints.
    contactGroup: c.dJointGroupID,
    /// The time, in milliseconds, when the last step was executed
    lastStep: i64,
    /// The lag-behind of the physics simulation measured in seconds.
    /// The maximum value is set to 0.1 seconds.
    accumulatedStep: f64 = 0.0,

    pub fn create() World {
        ensureInit();
        return World {
            .id = c.dWorldCreate(),
            .space = c.dHashSpaceCreate(null),
            .contactGroup = c.dJointGroupCreate(0),
            .lastStep = std.time.milliTimestamp()
        };
    }

    export fn nearCallback(data: ?*c_void, o1: c.dGeomID, o2: c.dGeomID) void {
        const b1 = c.dGeomGetBody(o1);
        const b2 = c.dGeomGetBody(o2);
        const self = @ptrCast(*World, @alignCast(@alignOf(World), data.?));

        const b1data = @ptrCast(*RigidbodyData, @alignCast(@alignOf(RigidbodyData), c.dBodyGetData(b1).?));
        const b2data = @ptrCast(*RigidbodyData, @alignCast(@alignOf(RigidbodyData), c.dBodyGetData(b2).?));

        const bounce: f32 = std.math.max(b1data.material.bounciness, b2data.material.bounciness);

        var contact: c.dContact = undefined;
        contact.surface.mode = c.dContactBounce;
        contact.surface.mu = std.math.inf(c.dReal);
        contact.surface.bounce = bounce;
        contact.surface.bounce_vel = 1;
        contact.surface.soft_cfm = 0.1;
        const numc = c.dCollide(o1, o2, 1, &contact.geom, @sizeOf(c.dContact));
        if (numc != 0) {
            const joint = c.dJointCreateContact(self.id, self.contactGroup, &contact);
            c.dJointAttach(joint, b1, b2);
        }
    }

    pub fn setGravity(self: *World, gravity: zlm.Vec3) void {
        c.dWorldSetGravity(self.id, gravity.x, gravity.y, gravity.z);
        c.dWorldSetERP(self.id, 0.1);
        //dWorldSetCFM(self.id, 0.0000);
    }

    pub fn update(self: *World) void {
        self.accumulatedStep += @intToFloat(f64, std.time.milliTimestamp())/1000 - @intToFloat(f64, self.lastStep)/1000;
        if (self.accumulatedStep > 0.1) self.accumulatedStep = 0.1;
        const timeStep = 0.01;
        while (self.accumulatedStep > timeStep) {
            c.dSpaceCollide(self.space, self, nearCallback);
            _ = c.dWorldQuickStep(self.id, timeStep);
            c.dJointGroupEmpty(self.contactGroup);
            self.accumulatedStep -= timeStep;
        }
        self.lastStep = std.time.milliTimestamp();
    }

    pub fn deinit(self: *const World) void {
        c.dWorldDestroy(self.id);
    }
};

pub const KinematicState = enum {
    Dynamic,
    Kinematic
};

pub const PhysicsMaterial = struct {
    bounciness: f32 = 0.0
};

pub const RigidbodyData = struct {
    /// Set by the Rigidbody component allowing it to know when to initialize internal values.
    inited: bool = false,
    /// The pointer to the World **MUST** be set.
    world: *World,
    kinematic: KinematicState = .Dynamic,
    gameObject: *GameObject = undefined,
    material: PhysicsMaterial = .{},
    /// Internal value (ODE dBodyID)
    _body: c.dBodyID = undefined,
    /// Internal value (ODE dGeomID)
    _geom: c.dGeomID = undefined,
    /// Internal value (ODE dMass)
    _mass: c.dMass = undefined,

    pub fn addForce(self: *RigidbodyData, force: zlm.Vec3) void {
        c.dBodyAddForce(self._body, force.x, force.y, force.z);
    }

    pub fn setPosition(self: *RigidbodyData, position: zlm.Vec3) void {
        c.dBodySetPosition(self._body, position.x, position.y, position.z);
        self.gameObject.position = position;
    }
};

/// Rigidbody component. Add it to a GameObject for it to have physics with other rigidbodies.
pub const Rigidbody = comptime objects.ComponentType(.Rigidbody, RigidbodyData, .{ .updateFn = rigidbodyUpdate }) {};

fn quatToEuler(q: [*]const c.dReal) zlm.Vec3 {
    var angles = zlm.Vec3.new(0, 0, 0);
    const sinr_cosp = 2.0 * (q[0] * q[1] + q[2] * q[3]);
    const cosr_cosp = 1.0 - 2.0 * (q[1] * q[1] + q[2] * q[2]);
    angles.z = std.math.atan2(c.dReal, sinr_cosp, cosr_cosp);

    const sinp = 2.0 * (q[0] * q[2] - q[3] * q[1]);
    angles.y = if (std.math.fabs(sinp) >= 1) std.math.copysign(c.dReal, std.math.pi / 2.0, sinp) else std.math.asin(sinp);

    const siny_cosp = 2.0 * (q[0] * q[3] + q[1] * q[2]);
    const cosy_cosp = 1.0 - 2.0 * (q[2] * q[2] + q[3] * q[3]);
    angles.x = std.math.atan2(c.dReal, siny_cosp, cosy_cosp);

    return angles;
}

fn rigidbodyUpdate(allocator: *Allocator, component: *Component, delta: f32) !void {
    const data = component.getData(RigidbodyData);
    const gameObject = component.gameObject;
    if (!data.inited) {
        data._body = c.dBodyCreate(data.world.id);
        data._geom = c.dCreateBox(data.world.space, 1.0, 1.0, 1.0);
        data.gameObject = gameObject;
        c.dMassSetBox(&data._mass, 1.0, 1.0, 1.0, 1.0);
        c.dGeomSetBody(data._geom, data._body);
        data.setPosition(gameObject.position);
        c.dBodySetData(data._body, data);
        c.dBodySetMass(data._body, &data._mass);
        c.dBodySetDamping(data._body, 0.001, 0.001);
        c.dBodySetAutoDisableFlag(data._body, 1);
        data.inited = true;
    }
    if (c.dBodyIsEnabled(data._body) != 0) {
        switch (data.kinematic) {
            .Dynamic => c.dBodySetDynamic(data._body),
            .Kinematic => c.dBodySetKinematic(data._body)
        }
        const scale = gameObject.scale;
        c.dGeomBoxSetLengths(data._geom, scale.x, scale.y, scale.z);
        const pos = c.dBodyGetPosition(data._body);
        const rot = quatToEuler(c.dBodyGetQuaternion(data._body));
        gameObject.rotation = rot;
        gameObject.position = zlm.Vec3.new(pos[0], pos[1], pos[2]);
    }
}

comptime {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(RigidbodyData);
    std.testing.refAllDecls(World);
}
