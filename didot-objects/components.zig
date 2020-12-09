const std = @import("std");
const Allocator = std.mem.Allocator;
const GameObject = @import("objects.zig").GameObject;

// TODO: redo components
pub const Component = struct {
    options: ComponentOptions,
    data: usize,
    allocator: *Allocator,

    pub fn update(self: *Component, allocator: *Allocator, gameObject: *GameObject, delta: f32) anyerror!void {
        if (self.options.updateFn) |func| {
            try func(allocator, self, gameObject, delta);
        }
    }

    pub fn getData(self: *const Component, comptime T: type) *T {
        return @intToPtr(*T, self.data);
    }

    pub fn deinit(self: *Component) void {
        self.allocator.destroy(@intToPtr(*u8, self.data));
    }
};

pub const ComponentOptions = struct {
    /// Functions called regularly depending on the updateTarget value of the Application.
    updateFn: ?fn(allocator: *Allocator, component: *Component, gameObject: *GameObject, delta: f32) anyerror!void = null
};

pub fn ComponentType(comptime name: @Type(.EnumLiteral), comptime Data: anytype, options: ComponentOptions) type {
    return struct {

        pub fn newWithData(self: *const @This(), allocator: *Allocator, data: Data) !Component {
            std.debug.warn("alloc {} bytes\n", .{@sizeOf(Data)});
            const newData: ?*Data = if (@sizeOf(Data) == 0) null else try allocator.create(Data);
            if (newData != null) {
                newData.?.* = data;
            }
            var cp = Component {
                .options = options,
                .allocator = allocator,
                .data = if (@sizeOf(Data) == 0) 0 else @ptrToInt(newData)
            };
            return cp;
        }

        pub fn new(self: *const @This(), allocator: *Allocator) !Component {
            return self.newWithData(allocator, undefined);
        }

    };
} 
