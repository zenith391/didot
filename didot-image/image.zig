pub const bmp = @import("bmp.zig");
pub const png = @import("png.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;

pub const ColorChannel = enum {
    Red,
    Green,
    Blue,
    Alpha
};

pub const ImageFormat = struct {
    redMask: u32,
    greenMask: u32,
    blueMask: u32,
    alphaMask: u32 = 0,
    bitsSize: u8,

    /// 8-bit red, green and blue samples in that order.
    pub const RGB24 = ImageFormat {.redMask=0xFF0000, .greenMask=0x00FF00, .blueMask=0x0000FF, .bitsSize=24};
    /// 8-bit blue, green and red samples in that order.
    pub const BGR24 = ImageFormat {.redMask=0x0000FF, .greenMask=0x00FF00, .blueMask=0xFF0000, .bitsSize=24};
    /// 8-bit red, green, blue and alpha samples in that order.
    pub const RGBA32 = ImageFormat{.redMask=0xFF000000,.greenMask=0x00FF0000,.blueMask=0x0000FF00,.alphaMask=0x000000FF,.bitsSize=32};
    /// 8-bit gray sample.
    pub const GRAY8 = ImageFormat {.redMask=0xFF, .greenMask=0xFF, .blueMask=0xFF, .bitsSize=8};

    pub fn getBitSize(self: *ImageFormat) u8 {
        return self.bitsSize;
    }

    pub fn getBitMask(self: *ImageFormat, channel: ColorChannel) u32 {
        return switch (channel) {
            .Red => self.redMask, .Green => self.greenMask,
            .Blue => self.blueMask, .Alpha => self.alphaMask
        };
    }

    pub const ShiftError = error { NullMask };

    pub fn getShift(self: *ImageFormat, channel: ColorChannel) ShiftError!u32 {
        // Example:
        //   The mask of the red color is 0b111000
        //   We shift right one time and get 0b011100, last bit is 0 so continue
        //   We shift right another time and get 0b001110, last bit is also 0 so continue
        //   We shift right a 3rd time and get 0b000111, the last bit is 1 and our shift is correct.
        //   So we now know that a color value has to be shifted 3 times to get the red color.

        const mask = self.getBitMask(channel);
        var shift: u8 = 0;
        while (shift < self.bitsSize) : (shift += 1) {
            const num = mask >> shift;
            if ((num & 1) == 1) { // if we hit the first 1 bit of the mask
                return shift;
            }
        }
        return ShiftError.NullMask;
    }

    pub fn getValue(self: *ImageFormat, channel: ColorChannel, value: u32) !u32 {
        const mask = self.getBitMask(channel);
        const shift = try self.getShift(channel);
        return (value & mask) >> shift;
    }
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
