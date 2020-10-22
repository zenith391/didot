const std = @import("std");
const Image = @import("image.zig").Image;
const Allocator = std.mem.Allocator;

pub const PngError = error {
    InvalidHeader,
    InvalidCompression,
    InvalidFilter,
    UnsupportedFormat
};

const ChunkStream = std.io.FixedBufferStream([]u8);

// PNG files are made of chunks which have this structure:
const Chunk = struct {
    length: u32,
    type: []const u8,
    data: []const u8,
    stream: ChunkStream,
    crc: u32,
    allocator: *Allocator,

    pub fn deinit(self: *const Chunk) void {
        self.allocator.free(self.type);
        self.allocator.free(self.data);
    }

    // fancy Zig reflection for basically loading the chunk into a struct
    // for the experienced: this method is necessary instead of a simple @bitCast because of endianess, as
    // PNG uses big-endian.
    pub fn toStruct(self: *Chunk, comptime T: type) T {
        var result: T = undefined;
        inline for (@typeInfo(T).Struct.fields) |field| {
            const fieldInfo = @typeInfo(field.field_type);
            switch (fieldInfo) {
                .Int => {
                    const f = self.stream.reader().readIntBig(field.field_type) catch unreachable;
                    @field(result, field.name) = f;
                },
                .Enum => |e| {
                    const id = self.stream.reader().readIntBig(e.tag_type) catch unreachable;
                    @field(result, field.name) = @intToEnum(field.field_type, id);
                },
                else => unreachable
            }
        }
        return result;
    }
};

const ColorType = enum(u8) {
    Greyscale = 0,
    Truecolor = 2,
    IndexedColor = 3,
    GreyscaleAlpha = 4,
    TruecolorAlpha = 6
};

const CompressionMethod = enum(u8) {
    Deflate = 0,
};

// Struct for the IHDR chunk, which contains most of metadata about the image.
const IHDR = struct {
    width: u32,
    height: u32,
    bitDepth: u8,
    colorType: ColorType,
    compressionMethod: CompressionMethod,
    filterMethod: u8,
    interlaceMethod: u8
};

fn readChunk(allocator: *Allocator, reader: anytype) !Chunk {
    const length = try reader.readIntBig(u32);
    var chunkType = try allocator.alloc(u8, 4);
    _ = try reader.readAll(chunkType);
    var data = try allocator.alloc(u8, length);
    _ = try reader.readAll(data);

    const crc = try reader.readIntBig(u32);
    var stream = ChunkStream {
        .buffer = data,
        .pos = 0
    };

    return Chunk {
        .length = length,
        .type = chunkType,
        .data = data,
        .stream = stream,
        .crc = crc,
        .allocator = allocator
    };
}

fn filterNone(image: []const u8, sample: u8, x: usize, y: usize, width: usize, pos: usize) u8 {
    return sample;
}

fn filterSub(image: []const u8, sample: u8, x: usize, y: usize, width: usize, pos: usize) u8 {
    if (x < 3) {
        return sample;
    } else {
        return sample +% image[pos-3];
    }
}

fn filterUp(image: []const u8, sample: u8, x: usize, y: usize, width: usize, pos: usize) u8 {
    if (y == 0) {
        return sample;
    } else {
        return sample +% image[pos-width];
    }
}

fn filterAverage(image: []const u8, sample: u8, x: usize, y: usize, width: usize, pos: usize) u8 {
    var val: u9 = if (x > 3) image[pos-3] else 0; // val = a
    if (y > 0) {
        val += image[pos-width]; // val = a + b
    }
    return sample +% @intCast(u8, @divFloor(val, 2));
}

fn filterPaeth(image: []const u8, sample: u8, x: usize, y: usize, width: usize, pos: usize) u8 {
    const a: i32 = if (x > 3) image[pos-3] else 0;
    const b: i32 = if (y > 0) image[pos-width] else 0;
    const c: i32 = if (x > 3 and y > 0) image[pos-width-3] else 0;

    const p: i32 = a + b - c;
    // the minimum value of p is -255, minus the minimum value of a/b/c, the minimum result is -510, so using unreachable is safe
    const pa = std.math.absInt(p - a) catch unreachable;
    const pb = std.math.absInt(p - b) catch unreachable;
    const pc = std.math.absInt(p - c) catch unreachable;

    if (pa <= pb and pa <= pc) {
        return sample +% @intCast(u8, a);
    } else if (pb <= pc) {
        return sample +% @intCast(u8, b);
    } else {
        return sample +% @intCast(u8, c);
    }
}

pub fn read_png(allocator: *Allocator, path: []const u8) !Image {
    const file = try std.fs.cwd().openFile(path, .{ .read = true });
    const unbufferedReader = file.reader();
    var bufferedReader = std.io.BufferedReader(16*1024, @TypeOf(unbufferedReader)) { 
        .unbuffered_reader = unbufferedReader
    };
    const reader = bufferedReader.reader();

    var signature = reader.readBytesNoEof(8) catch return error.UnsupportedFormat;
    if (!std.mem.eql(u8, signature[0..], "\x89PNG\r\n\x1A\n")) {
        return error.UnsupportedFormat;
    }

    var ihdrChunk = try readChunk(allocator, reader);
    defer ihdrChunk.deinit();
    if (!std.mem.eql(u8, ihdrChunk.type, "IHDR")) {
        return error.InvalidHeader; // first chunk must ALWAYS be IHDR
    }
    const ihdr = ihdrChunk.toStruct(IHDR);

    if (ihdr.filterMethod != 0) {
        // there's only one filter method declared in the PNG specification
        // the error falls under InvalidHeader because InvalidFilter is for
        // the per-scanline filter type.
        return error.InvalidHeader;
    }

    var idatData = try allocator.alloc(u8, 0);
    defer allocator.free(idatData);

    while (true) {
        const chunk = try readChunk(allocator, reader);
        defer chunk.deinit();

        if (std.mem.eql(u8, chunk.type, "IEND")) {
            break;
        } else if (std.mem.eql(u8, chunk.type, "IDAT")) { // image data
            const pos = idatData.len;
            // in PNG files, there can be multiple IDAT chunks, and their data must all be concatenated.
            idatData = try allocator.realloc(idatData, idatData.len + chunk.data.len);
            std.mem.copy(u8, idatData[pos..], chunk.data);
        }
    }

    // the following lines create a zlib stream over our concatenated data from IDAT chunks.
    var idatStream = std.io.FixedBufferStream([]u8) {
        .buffer = idatData,
        .pos = 0
    };
    var zlibStream = try std.compress.zlib.zlibStream(allocator, idatStream.reader());
    defer zlibStream.deinit();
    const idatReader = zlibStream.reader();

    // allocate image data (TODO: support more than RGB)
    const imageData = try allocator.alloc(u8, ihdr.width*ihdr.height*3);

    if (ihdr.colorType == .Truecolor) {
        var x: u32 = 0;
        var y: u32 = 0;
        const bytesPerLine = ihdr.width * 3;
        while (y < ihdr.height) {
            x = 0;
            // in PNG files, each scanlines have a filter, it is used to have more efficient compression.
            const filterType = try idatReader.readByte();
            std.debug.warn("line #{} : filter {}\n", .{y, filterType});
            const filter = switch(filterType) {
                0 => filterNone,
                1 => filterSub,
                2 => filterUp,
                3 => filterAverage,
                4 => filterPaeth,
                else => return error.InvalidFilter
            };
            while (x < bytesPerLine) {
                const pos = y*bytesPerLine + x;
                const r = try idatReader.readByte();
                const g = try idatReader.readByte();
                const b = try idatReader.readByte();
                imageData[pos] = filter(imageData, r, x, y, bytesPerLine, pos);
                imageData[pos+1] = filter(imageData, g, x+1, y, bytesPerLine, pos+1);
                imageData[pos+2] = filter(imageData, b, x+2, y, bytesPerLine, pos+2);
                x += 3; // since we use 3 bytes per pixel, let's directly increment X by 3
                // (that optimisation is also useful in the filter method)
            }
            y += 1;
        }
    }

    return Image {
        .allocator = allocator,
        .data = imageData,
        .width = ihdr.width,
        .height = ihdr.height,
        .format = .RGB24
    };
}