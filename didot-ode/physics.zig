const std = @import("std");
const zalgebra = @import("zalgebra");
const objects = @import("didot-objects");
const c = @cImport({
    @cDefine("dSINGLE", "1");
    @cInclude("ode/ode.h");
});

const Allocator = std.mem.Allocator;
const Component = objects.Component;
const GameObject = objects.GameObject;
const Transform = objects.Transform;

const Vec3 = zalgebra.vec3;

var isOdeInit: bool = false;
const logger = std.log.scoped(.didot);

var odeThread: ?std.Thread.Id = null;

fn ensureInit() void {
    if (!isOdeInit) {
        _ = c.dInitODE2(0);
        const conf = @ptrCast([*:0]const u8, c.dGetConfiguration());
        logger.debug("Initialized ODE.", .{});
        logger.debug("ODE configuration: {s}", .{conf});
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

        const b1data = @ptrCast(*Rigidbody, @alignCast(@alignOf(Rigidbody), c.dBodyGetData(b1).?));
        const b2data = @ptrCast(*Rigidbody, @alignCast(@alignOf(Rigidbody), c.dBodyGetData(b2).?));

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

    pub fn setGravity(self: *World, gravity: Vec3) void {
        c.dWorldSetGravity(self.id, gravity.x, gravity.y, gravity.z);
        c.dWorldSetAutoDisableFlag(self.id, 1);
        c.dWorldSetAutoDisableLinearThreshold(self.id, 0.1);
        c.dWorldSetAutoDisableAngularThreshold(self.id, 0.1);
        //c.dWorldSetERP(self.id, 0.1);
        //c.dWorldSetCFM(self.id, 0.0000);
    }

    pub fn update(self: *World) void {
        self.accumulatedStep += @intToFloat(f64, std.time.milliTimestamp())/1000 - @intToFloat(f64, self.lastStep)/1000;
        if (self.accumulatedStep > 0.1) self.accumulatedStep = 0.1;
        const timeStep = 0.01;
        while (self.accumulatedStep > timeStep) {
            c.dSpaceCollide(self.space, self, nearCallback);
            _ = c.dWorldStep(self.id, timeStep);
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

pub const SphereCollider = struct {
    radius: f32
};

pub const BoxCollider = struct {
    size: Vec3 = Vec3.new(1, 1, 1)
};

pub const Collider = union(enum) {
    Box: BoxCollider,
    Sphere: SphereCollider
};

/// Rigidbody component.
/// Add it to a GameObject for it to have physics with other rigidbodies.
pub const Rigidbody = struct {
    /// Set by the Rigidbody component allowing it to know when to initialize internal values.
    inited: bool = false,
    /// The pointer to the World **MUST** be set.
    world: *World,
    kinematic: KinematicState = .Dynamic,
    transform: *Transform = undefined,
    material: PhysicsMaterial = .{},
    collider: Collider = .{ .Box = .{} },
    /// Internal value (ODE dBodyID)
    _body: c.dBodyID = undefined,
    /// Internal value (ODE dGeomID)
    _geom: c.dGeomID = undefined,
    /// Internal value (ODE dMass)
    _mass: c.dMass = undefined,

    pub fn addForce(self: *Rigidbody, force: Vec3) void {
        c.dBodyEnable(self._body);
        c.dBodyAddForce(self._body, force.x, force.y, force.z);
    }

    pub fn setPosition(self: *Rigidbody, position: Vec3) void {
        c.dBodySetPosition(self._body, position.x, position.y, position.z);
        self.transform.position = position;
    }
};

fn quatToEuler(q: [*]const c.dReal) Vec3 {
    var angles = Vec3.new(0, 0, 0);
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

pub fn rigidbodySystem(query: objects.Query(.{*Rigidbody, *Transform})) !void {
    var iterator = query.iterator();
    while (iterator.next()) |o| {
        const data = o.rigidbody;
        const transform = o.transform;
        if (!data.inited) { // TODO: move to a system that uses the Created() filter
            data._body = c.dBodyCreate(data.world.id);
            const scale = transform.scale;
            data._geom = switch (data.collider) {
                .Box => |box| c.dCreateBox(data.world.space, box.size.x, box.size.y, box.size.z),
                .Sphere => |sphere| c.dCreateSphere(data.world.space, sphere.radius)
            };
            data.transform = transform;
            c.dMassSetBox(&data._mass, 1.0, 1.0, 1.0, 1.0);
            c.dGeomSetBody(data._geom, data._body);
            data.setPosition(transform.position);
            c.dBodySetData(data._body, data);
            c.dBodySetMass(data._body, &data._mass);
            c.dBodySetDamping(data._body, 0.005, 0.005);
            data.inited = true;
        }
        if (c.dBodyIsEnabled(data._body) != 0) {
            switch (data.kinematic) {
                .Dynamic => c.dBodySetDynamic(data._body),
                .Kinematic => c.dBodySetKinematic(data._body)
            }
            const scale = transform.scale;
            //c.dGeomBoxSetLengths(data._geom, scale.x, scale.y, scale.z);
            const pos = c.dBodyGetPosition(data._body);
            const raw = c.dBodyGetQuaternion(data._body);
            transform.rotation = zalgebra.quat.new(raw[0], raw[1], raw[2], raw[3]);
            transform.position = Vec3.new(pos[0], pos[1], pos[2]);
        }
    }
}

comptime {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(Rigidbody);
    std.testing.refAllDecls(World);
}
