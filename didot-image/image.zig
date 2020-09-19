pub const bmp = @import("bmp.zig");
const Allocator = @import("std").mem.Allocator;

pub const Image = struct {
    allocator: ?*Allocator = null,
    /// The image data, in linear 8-bit RGB format.
    data: []u8,
    width: usize,
    height: usize,

    pub fn deinit(self: *Image) void {
        if (self.allocator) |allocator| {
            allocator.free(self.data);
        }
    }
};

test "" {
    comptime {
        @import("std").meta.refAllDecls(bmp);
    }
}