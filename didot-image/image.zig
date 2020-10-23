pub const bmp = @import("bmp.zig");
pub const png = @import("png.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;

pub const ImageFormat = enum {
    /// 8-bit red, green and blue samples in that order.
    RGB24,
    /// 8-bit blue, green and red samples in that order.
    BGR24,
    /// 8-bit red, green, blue and alpha samples in that order.
    RGBA32,
    /// 8-bit gray sample.
    GRAY8
};

pub const Image = struct {
    allocator: ?*Allocator = null,
    /// The image data, in linear 8-bit RGB format.
    data: []u8,
    width: usize,
    height: usize,
    format: ImageFormat,

    pub fn deinit(self: *const Image) void {
        if (self.allocator) |allocator| {
            allocator.free(self.data);
        }
    }
};

comptime {
    @import("std").testing.refAllDecls(bmp);
    @import("std").testing.refAllDecls(png);
}
