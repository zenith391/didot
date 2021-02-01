const std = @import("std");
const Allocator = std.mem.Allocator;
const objects = @import("objects.zig");
const GameObject = objects.GameObject;

pub const Component = struct {
    data: usize,
    allocator: *Allocator,
    name: []const u8,
    gameObject: *GameObject = undefined,
    // TODO: index into a scene array of objects

    pub fn from(allocator: *Allocator, x: anytype) !Component {
        const T = @TypeOf(x);
        var copy = try allocator.create(T);
        copy.* = x;
        return Component {
            .data = @ptrToInt(copy),
            .allocator = allocator,
            .name = @typeName(T),
        };
    }

    /// Get the type name of this component.
    pub inline fn getName(self: *const Component) []const u8 {
        return self.name.*;
    }

    /// Get the data, as type T, holded in this component.
    pub inline fn getData(self: *const Component, comptime T: type) *T {
        if (@sizeOf(T) == 0) {
            return undefined;
        } else {
            return @intToPtr(*T, self.data);
        }
    }

    pub fn deinit(self: *Component) void {
        if (self.data != 0) {
            self.allocator.destroy(@intToPtr(*u8, self.data));
        }
    }
};

pub const ComponentOptions = struct {
    /// Functions called regularly depending on the updateTarget value of the Application.
    updateFn: ?fn(allocator: *Allocator, component: *Component, delta: f32) anyerror!void = null
};

/// System selector to select objects where component T has just been created.
pub fn Created(comptime T: type) type {

}

/// System selector to select objects without component T, you should feed a struct type instead of a pointer to struct type as the
/// pointer info (const or not const) is not used for a Without query.
pub fn Without(comptime T: type) type {

}

/// System selector to select objects with component T, you should feed a pointer to struct type as the
/// pointer info (const or not const) is used for a With query.
/// This is also the default system selector.
pub fn With(comptime T: type) type {
    return struct {
        const is_condition = true;

        pub fn include(go: GameObject) bool {
            return true;
        }
    };
}

fn getComponents(comptime parameters: anytype) []type {
    const info = @typeInfo(@TypeOf(parameters)).Struct;
    var types: [info.fields.len]type = undefined;

    for (info.fields) |field, i| {
        types[i] = @field(parameters, field.name);
        if (!std.meta.trait.isSingleItemPtr(types[i])) {
            @compileError("Invalid type " ++ @typeName(types[i]) ++ ", must be *" ++ @typeName(types[i]) ++ " or *const " ++ @typeName(types[i]));
        }
    }

    return &types;
}

// fn testSystem(pos: *Position, vel: *const Velocity); is used for single item systems
// fn testSystem(ent: Query(.{*Mob}), obs: Query(.{*const Obstacle}))
// fn testSystem(x: Query(.{Without(Velocity), With(*Position)})) without doesn't need a pointer

// Example: Query(.{*Position, *const Velocity})
// You have to specify something like Query(.{*Position, *const Velocity, .sync=true}) to avoid this
/// Queries are to be used for processing multiple components at a time
pub fn Query(comptime parameters: anytype) type {
    const SystemQuery = struct {
        const Self = @This();

        scene: *objects.Scene,
        const Result = comptime blk: {
            const StructField = std.builtin.TypeInfo.StructField;

            var fields: []const StructField = &[0]StructField {};
            const comps = getComponents(parameters);
            for (comps) |comp| {
                const name = @typeName(std.meta.Child(comp));
                var newName: [name.len]u8 = undefined;
                newName = name.*;
                newName[0] = std.ascii.toLower(newName[0]);
                const field = StructField {
                    .name = &newName,
                    .field_type = comp,
                    .default_value = null,
                    .is_comptime = false,
                    .alignment = @alignOf(comp)
                };
                fields = fields ++ &[_]StructField {field};
            }


            const info = std.builtin.TypeInfo {
                .Struct = .{
                    .layout = .Auto,
                    .fields = fields,
                    .decls = &[0]std.builtin.TypeInfo.Declaration {},
                    .is_tuple = false
                }
            };
            break :blk @Type(info);
        };

        const Iterator = struct {
            pos: usize = 0,
            query: *const Self,

            pub fn next(self: *Iterator) ?Result {
                const scene = self.query.scene;
                while (self.pos < scene.objects.items.len) : (self.pos += 1) {
                    const obj = scene.objects.items[self.pos];
                    const comps = getComponents(parameters);
                    var result: Result = undefined;

                    // TODO: use filters
                    var ok: bool = true;
                    inline for (comps) |comp| {
                        const name = @typeName(std.meta.Child(comp));
                        comptime var newName: [name.len]u8 = undefined;
                        newName = name.*;
                        newName[0] = comptime std.ascii.toLower(newName[0]);
                        if (obj.getComponent(std.meta.Child(comp))) |cp| {
                            @field(result, &newName) = cp;
                        } else {
                            ok = false;
                        }
                    }
                    if (ok) {
                        self.pos += 1;
                        return result;
                    }
                }

                return null;
            }
        };

        pub fn iterator(self: *const @This()) Iterator {
            return Iterator { .query = self };
        }

        pub fn parallelIterator(self: *const @This(), divides: usize) Iterator {
            @compileError("TODO");
        }

    };
    return SystemQuery;
}

comptime {
    std.testing.refAllDecls(@This());
}