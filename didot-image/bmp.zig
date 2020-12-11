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

    const signature = try reader.readBytesNoEof(2);
    if (!std.mem.eql(u8, &signature, "BM")) {
        return BmpError.UnsupportedFormat;
    }

    const size = reader.readIntLittle(u32);
    _ = try reader.readBytesNoEof(4); // skip the reserved bytes
    const offset = try reader.readIntLittle(u32);
    const dibSize = try reader.readIntLittle(u32);

    if (dibSize == 40 or dibSize == 108) { // BITMAPV4HEADER
        const width = @intCast(usize, try reader.readIntLittle(i32));
        const height = @intCast(usize, try reader.readIntLittle(i32));
        const colorPlanes = try reader.readIntLittle(u16);
        const bpp = try reader.readIntLittle(u16);

        const compression = try reader.readIntLittle(u32);
        const imageSize = try reader.readIntLittle(u32);
        const horzRes = try reader.readIntLittle(i32);
        const vertRes = try reader.readIntLittle(i32);
        const colorsNum = try reader.readIntLittle(u32);
        const importantColors = try reader.readIntLittle(u32);

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
                .format = @import("image.zig").ImageFormat.GRAY8
            };
        } else if (bytesPerPixel == 3) {
            const skipAhead: usize = @mod(width, 4);
            while (i >= 0) {
                const pos = i * bytesPerLine;
                _ = try imgReader.readAll(data[pos..(pos+bytesPerLine)]);
                try imgReader.skipBytes(skipAhead, .{});
                if (i == 0) break;
                i -= 1;
            }
            return Image {
                .allocator = allocator, .data = data,
                .width = width, .height = height,
                .format = @import("image.zig").ImageFormat.BGR24
            };
        } else {
            return BmpError.UnsupportedFormat;
        }
    } else {
        return BmpError.InvalidHeader;
    }
}
