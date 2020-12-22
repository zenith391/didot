const std = @import("std");
const Allocator = std.mem.Allocator;
const GameObject = @import("objects.zig").GameObject;

pub const Component = struct {
    options: ComponentOptions,
    data: usize,
    allocator: *Allocator,
    gameObject: *GameObject = undefined,
    // Uses a pointer in order to save memory.
    name: *const []const u8,

    pub fn update(self: *Component, allocator: *Allocator, delta: f32) anyerror!void {
        if (self.options.updateFn) |func| {
            try func(allocator, self, delta);
        }
    }

    pub inline fn getName(self: *const Component) []const u8 {
        return self.name.*;
    }

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

pub fn ComponentType(comptime name: @Type(.EnumLiteral), comptime Data: anytype, options: ComponentOptions) type {
    return struct {
        name: []const u8 = @tagName(name),

        pub fn newWithData(self: *const @This(), allocator: *Allocator, data: Data) !Component {
            const newData: ?*Data = if (@sizeOf(Data) == 0) null else try allocator.create(Data);
            if (newData != null) {
                newData.?.* = data;
            }
            var cp = Component {
                .options = options,
                .allocator = allocator,
                .data = if (@sizeOf(Data) == 0) 0 else @ptrToInt(newData),
                .name = &self.name
            };
            return cp;
        }

        pub fn new(self: *const @This(), allocator: *Allocator) !Component {
            return self.newWithData(allocator, undefined);
        }

    };
} 
