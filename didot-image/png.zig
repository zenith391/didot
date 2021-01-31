const std = @import("std");
const Image = @import("image.zig").Image;
const Allocator = std.mem.Allocator;

pub const PngError = error {
    InvalidHeader,
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
        var reader = self.stream.reader();
        inline for (@typeInfo(T).Struct.fields) |field| {
            const fieldInfo = @typeInfo(field.field_type);
            switch (fieldInfo) {
                .Int => {
                    const f = reader.readIntBig(field.field_type) catch unreachable;
                    @field(result, field.name) = f;
                },
                .Enum => |e| {
                    const id = reader.readIntBig(e.tag_type) catch unreachable;
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

fn filterNone(image: []const u8, sample: u8, x: u32, y: u32, width: usize, pos: usize, bytes: u8) u8 {
    return sample;
}

fn filterSub(image: []const u8, sample: u8, x: u32, y: u32, width: usize, pos: usize, bytes: u8) u8 {
    return if (x < bytes) sample else sample +% image[pos-bytes];
}

fn filterUp(image: []const u8, sample: u8, x: u32, y: u32, width: usize, pos: usize, bytes: u8) u8 {
    return if (y == 0) sample else sample +% image[pos-width];
}

fn filterAverage(image: []const u8, sample: u8, x: u32, y: u32, width: usize, pos: usize, bytes: u8) u8 {
    var val: u9 = if (x >= bytes) image[pos-bytes] else 0;
    if (y > 0) {
        val += image[pos-width]; // val = a + b
    }
    return sample +% @truncate(u8, val / 2);
}

fn filterPaeth(image: []const u8, sample: u8, x: u32, y: u32, width: usize, pos: usize, bytes: u8) u8 {
    const a: i10 = if (x >= bytes) image[pos-bytes] else 0;
    const b: i10 = if (y > 0) image[pos-width] else 0;
    const c: i10 = if (x >= bytes and y > 0) image[pos-width-bytes] else 0;
    const p: i10 = a + b - c;
    // the minimum value of p is -255, minus the maximum value of a/b/c, the minimum result is -510, so using unreachable is safe
    const pa = std.math.absInt(p - a) catch unreachable;
    const pb = std.math.absInt(p - b) catch unreachable;
    const pc = std.math.absInt(p - c) catch unreachable;

    if (pa <= pb and pa <= pc) {
        return sample +% @truncate(u8, @bitCast(u10, a));
    } else if (pb <= pc) {
        return sample +% @truncate(u8, @bitCast(u10, b));
    } else {
        return sample +% @truncate(u8, @bitCast(u10, c));
    }
}

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

pub fn read(allocator: *Allocator, unbufferedReader: anytype) !Image {
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
    var zlibReader = zlibStream.reader();
    const idatReader = (std.io.BufferedReader(64*1024, @TypeOf(zlibReader)) { 
        .unbuffered_reader = zlibReader
    }).reader();

    // allocate image data (TODO: support more than RGB)
    var bpp: u32 = 3;
    if (ihdr.colorType == .TruecolorAlpha) {
        bpp = 4;
    }
    const imageData = try allocator.alloc(u8, ihdr.width*ihdr.height*bpp);
    var y: u32 = 0;

    const Filter = fn(image: []const u8, sample: u8, x: u32, y: u32, width: usize, pos: usize, bytes: u8) u8;
    const filters = [_]Filter {filterNone, filterSub, filterUp, filterAverage, filterPaeth};

    if (ihdr.colorType == .Truecolor) {
        const bytesPerLine = ihdr.width * bpp;
        var line = try allocator.alloc(u8, bytesPerLine);
        defer allocator.free(line);
        while (y < ihdr.height) {
            var x: u32 = 0;
            // in PNG files, each scanlines have a filter, it is used to have more efficient compression.
            const filterType = try idatReader.readByte();
            const offset = y*bytesPerLine;
            _ = try idatReader.readAll(line);

            inline for (filters) |filter, i| {
                if (filterType == i) {
                    while (x < bytesPerLine) {
                        const pos = offset + x;
                        imageData[pos] = filter(imageData, line[x], x, y, bytesPerLine, pos, 3);
                        x += 1;
                        imageData[pos+1] = filter(imageData, line[x], x, y, bytesPerLine, pos+1, 3);
                        x += 1;
                        imageData[pos+2] = filter(imageData, line[x], x, y, bytesPerLine, pos+2, 3);
                        x += 1;
                    }
                }
            }
            if (std.debug.runtime_safety and x != bytesPerLine) {
                return error.InvalidFilter;
            }
            y += 1;
        }

        return Image {
            .allocator = allocator,
            .data = imageData,
            .width = ihdr.width,
            .height = ihdr.height,
            .format = @import("image.zig").ImageFormat.RGB24
        };
    } else if (ihdr.colorType == .TruecolorAlpha and false) {
        var pixel: [4]u8 = undefined;
        const bytesPerLine = ihdr.width * 4;
        while (y < ihdr.height) {
            var x: u32 = 0;
            // in PNG files, each scanlines have a filter, it is used to have more efficient compression.
            const filterType = try idatReader.readByte();
            const filter = switch (filterType) {
                0 => filterNone,
                1 => filterSub,
                2 => filterUp,
                3 => filterAverage,
                4 => filterPaeth,
                else => return error.InvalidFilter
            };
            while (x < bytesPerLine) {
                const pos = y*bytesPerLine + x;
                _ = try idatReader.readAll(&pixel);
                imageData[pos] = filter(imageData, pixel[0], x, y, bytesPerLine, pos, 4);
                imageData[pos+1] = filter(imageData, pixel[1], x+1, y, bytesPerLine, pos+1, 4);
                imageData[pos+2] = filter(imageData, pixel[2], x+2, y, bytesPerLine, pos+2, 4);
                imageData[pos+3] = filter(imageData, pixel[3], x+3, y, bytesPerLine, pos+3, 4);
                x += 4; // since we use 4 bytes per pixel, let's directly increment X by 4
                // (that optimisation is also useful in the filter method)
            }
            y += 1;
        }

        return Image {
            .allocator = allocator,
            .data = imageData,
            .width = ihdr.width,
            .height = ihdr.height,
            .format = @import("image.zig").ImageFormat.RGBA32
        };
    } else {
        std.log.scoped(.didot).err("Unsupported PNG format: {}", .{ihdr.colorType});
        return PngError.UnsupportedFormat;
    }
}
