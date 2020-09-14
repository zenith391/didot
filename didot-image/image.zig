pub const bmp = @import("bmp.zig");
pub const Allocator = @import("std").mem.Allocator;

pub const Image = struct {
    allocator: ?*Allocator = null,
    data: []u8,
    width: usize,
    height: usize,

    pub fn deinit(self: *Image) void {
        if (self.allocator) |allocator| {
            allocator.free(self.data);
        }
    }
};
