const std = @import("std");
const Image = @import("image.zig").Image;
const Allocator = std.mem.Allocator;

const BmpError = error {
    InvalidHeader,
    InvalidCompression,
    UnsupportedFormat
};

pub fn read(allocator: *Allocator, path: []const u8) !Image {
    const file = try std.fs.cwd().openFile(path, .{ .read = true });
    const reader = file.reader();

    var signature = try reader.readBytesNoEof(2);
    if (!std.mem.eql(u8, &signature, "BM")) {
        return BmpError.UnsupportedFormat;
    }

    var size = reader.readIntLittle(u32);
    _ = try reader.readBytesNoEof(4); // skip the reserved bytes
    var offset = try reader.readIntLittle(u32);
    var dibSize = try reader.readIntLittle(u32);

    if (dibSize == 108) { // BITMAPV4HEADER
        var width = @intCast(usize, try reader.readIntLittle(i32));
        var height = @intCast(usize, try reader.readIntLittle(i32));
        var colorPlanes = try reader.readIntLittle(u16);
        var bpp = try reader.readIntLittle(u16);

        var compression = try reader.readIntLittle(u32);
        var imageSize = try reader.readIntLittle(u32);
        var horzRes = try reader.readIntLittle(i32);
        var vertRes = try reader.readIntLittle(i32);
        var colorsNum = try reader.readIntLittle(u32);
        var importantColors = try reader.readIntLittle(u32);

        try file.seekTo(offset);
        const imgReader = (std.io.BufferedReader(16*1024, @TypeOf(reader)) { 
            .unbuffered_reader = reader
        }).reader(); // the input is only buffered now as when seeking the file, the buffer isn't emptied
        const bytesPerPixel = @intCast(usize, bpp/8);
        var data = try allocator.alloc(u8, @intCast(usize, width*height*bytesPerPixel));

        var i: usize = height-1;
        var j: usize = 0;
        const bytesPerLine = width * bytesPerPixel;

        if (bytesPerPixel == 1) {
            const skipAhead: usize = @mod(width, 4);
            while (i >= 0) {
                j = 0;
                while (j < width) {
                    const pos = j + i*bytesPerLine;
                    data[pos] = try imgReader.readByte();
                    j += 1;
                }
                try imgReader.skipBytes(skipAhead, .{});
                if (i == 0) break;
                i -= 1;
            }
            return Image {
                .allocator = allocator, .data = data,
                .width = width, .height = height,
                .format = .GRAY8
            };
        } else if (bytesPerPixel == 3) {
            var pixel: [3]u8 = undefined; // BGR pixel
            const skipAhead: usize = @mod(width, 4);
            while (i >= 0) {
                j = 0;
                while (j < bytesPerLine) {
                    const pos = j + i*bytesPerLine;
                    _ = try imgReader.readAll(&pixel);
                    @memcpy(data[pos..].ptr, @ptrCast([*]u8, &pixel[0]), 3);
                    j += 3; // 3 bytes per pixel
                }
                try imgReader.skipBytes(skipAhead, .{});
                if (i == 0) break;
                i -= 1;
            }
            return Image {
                .allocator = allocator, .data = data,
                .width = width, .height = height,
                .format = .BGR24
            };
        } else {
            return BmpError.UnsupportedFormat;
        }
    } else {
        return BmpError.InvalidHeader;
    }
}
