const std = @import("std");
const Image = @import("image.zig").Image;
const Allocator = std.mem.Allocator;

pub fn read(allocator: *Allocator, unbufferedReader: anytype) !Image {
    var bufferedReader = std.io.BufferedReader(16*1024, @TypeOf(unbufferedReader)) { 
        .unbuffered_reader = unbufferedReader
    };
    const reader = bufferedReader.reader();

    const signature = reader.readBytesNoEof(2) catch return error.UnsupportedFormat;
    const sizeLine = try reader.readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize));
    const size = std.mem.split(sizeLine, " ");
    const width = std.fmt.parseUnsigned(usize, if (size.next()) |n| n else return error.UnsupportedFormat, 10);
    const height = std.fmt.parseUnsigned(usize, if (size.next()) |n| n else return error.UnsupportedFormat, 10);
    if (std.mem.eql(u8, signature, "P3")) {

    }
}
