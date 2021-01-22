const std = @import("std");
const Image = @import("image.zig").Image;
const Allocator = std.mem.Allocator;

pub fn read(allocator: *Allocator, path: []const u8) !Image {
    const file = try std.fs.cwd().openFile(path, .{ .read = true });
    const unbufferedReader = file.reader();
    var bufferedReader = std.io.BufferedReader(16*1024, @TypeOf(unbufferedReader)) { 
        .unbuffered_reader = unbufferedReader
    };
    const reader = bufferedReader.reader();

    const signature = reader.readBytesNoEof(2) catch return error.UnsupportedFormat;
}