pub const obj = @import("obj.zig");
const graphics = @import("didot-graphics");
const std = @import("std");
const Allocator = std.mem.Allocator;

// Mesh asset loader
pub const MeshAssetLoaderData = struct {
    path: []const u8,
    format: []const u8,

    /// Memory is caller owned
    pub fn init(allocator: *Allocator, path: []const u8, format: []const u8) !usize {
        var data = try allocator.create(MeshAssetLoaderData);
        data.path = path;
        data.format = format;
        return @ptrToInt(data);
    }
};

pub const MeshAssetLoaderError = error {
    InvalidFormat
};

pub fn meshAssetLoader(allocator: *Allocator, dataPtr: usize) !usize {
    const data = @intToPtr(*MeshAssetLoaderData, dataPtr);
    defer allocator.destroy(data);
    if (std.mem.eql(u8, data.format, "obj")) {
        const mesh = try obj.read_obj(allocator, data.path);
        var m = try allocator.create(graphics.Mesh);
        m.* = mesh;
        return @ptrToInt(m);
    } else {
        return MeshAssetLoaderError.InvalidFormat;
    }
}

test "" {
    comptime {
        @import("std").meta.refAllDecls(obj);
    }
}
