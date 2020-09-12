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
        //std.debug.warn("Signature = {}\n", .{signature});
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
        const bytesPerPixel = @intCast(i32, bpp/8);
        var data = try allocator.alloc(u8, @intCast(usize, width*height*3)); // data is always in RGB format

        var i: i32 = height-1;
        var j: i32 = 0;
        while (i >= 0) {
            j = 0;
            while (j < width) {
                var pos = @intCast(usize, j*bytesPerPixel + i*(width*bytesPerPixel));

                if (bytesPerPixel == 1) {
                    const gray = try reader.readIntLittle(u8);
                    data[pos] = gray;
                    data[pos+1] = gray;
                    data[pos+2] = gray;
                } else {
                    const b = try reader.readIntLittle(u8);
                    const g = try reader.readIntLittle(u8);
                    const r = try reader.readIntLittle(u8);
                    data[pos] = r;
                    data[pos+1] = g;
                    data[pos+2] = b;
                }
                j += 1;
            }
            var skipAhead = @mod(width, 4);
            try file.seekBy(skipAhead);
            i -= 1;
        }

        return Image {
            .allocator = allocator,
            .data = data,
            .width = @intCast(usize, width),
            .height = @intCast(usize, height)
        };
    } else {
        return BMPError.InvalidHeader;
    }
}
