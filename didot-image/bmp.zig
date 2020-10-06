const std = @import("std");
const Image = @import("image.zig").Image;
const Allocator = std.mem.Allocator;

const BMPError = error {
    InvalidHeader,
    InvalidCompression,
    UnsupportedFormat
};

pub fn read_bmp(allocator: *Allocator, path: []const u8) !Image {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(path, .{
        .read = true,
        .write = false
    });
    const reader = file.reader();

    var signature = try reader.readBytesNoEof(2);

    if (!std.mem.eql(u8, signature[0..], "BM")) {
        return error.UnsupportedFormat;
    }

    var size = reader.readIntLittle(u32);

    _ = try reader.readBytesNoEof(4); // skip the reserved bytes

    var offset = try reader.readIntLittle(u32);

    var dibSize = try reader.readIntLittle(u32);

    if (dibSize == 108) { // BITMAPV4HEADER
        var width = try reader.readIntLittle(i32);
        var height = try reader.readIntLittle(i32);
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
        const bytesPerPixel = @intCast(i32, bpp/8);
        var data = try allocator.alloc(u8, @intCast(usize, width*height*3)); // data is always in RGB format

        var i: i32 = height-1;
        var j: i32 = 0;
        const bytesPerLine = width * bytesPerPixel;

        if (bytesPerPixel == 1) {
            while (i >= 0) {
                j = 0;
                while (j < width) {
                    const pos = @intCast(usize, j + i*bytesPerLine);
                    const gray = try imgReader.readByte();
                    data[pos] = gray;
                    data[pos+1] = gray;
                    data[pos+2] = gray;
                    j += 3;
                }
                const skipAhead: usize = @intCast(usize, @mod(width, 4));
                try imgReader.skipBytes(skipAhead, .{});
                i -= 1;
            }
        } else {
            while (i >= 0) {
                j = 0;
                while (j < bytesPerLine) {
                    const pos = @intCast(usize, j + i*bytesPerLine);
                    const b = try imgReader.readByte();
                    const g = try imgReader.readByte();
                    const r = try imgReader.readByte();
                    data[pos] = r;
                    data[pos+1] = g;
                    data[pos+2] = b;
                    j += 3; // 3 bytes per pixel
                }
                const skipAhead: usize = @intCast(usize, @mod(width, 4));
                try imgReader.skipBytes(skipAhead, .{});
                i -= 1;
            }
        }

        return Image {
            .allocator = allocator,
            .data = data,
            .width = @intCast(usize, width),
            .height = @intCast(usize, height),
            .format = .RGB24
        };
    } else {
        return BMPError.InvalidHeader;
    }
}
