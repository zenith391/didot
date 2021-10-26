pub const obj = @import("obj.zig");
const graphics = @import("didot-graphics");
const objects = @import("../didot-objects/assets.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;
const AssetStream = objects.AssetStream;
const Asset = objects.Asset;

pub const MeshAsset = struct {
    /// Memory is caller owned
    pub fn init(allocator: *Allocator, format: []const u8) !Asset {
        var data = try allocator.create(MeshAssetLoaderData);
        data.format = format;
        return Asset {
            .loader = meshAssetLoader,
            .loaderData = @ptrToInt(data),
            .objectType = .Mesh,
            .allocator = allocator
        };
    }
};

pub const MeshAssetLoaderData = struct {
    format: []const u8
};

pub const MeshAssetLoaderError = error {
    InvalidFormat
};

pub fn meshAssetLoader(allocator: *Allocator, dataPtr: usize, stream: *AssetStream) !usize {
    const data = @intToPtr(*MeshAssetLoaderData, dataPtr);
    if (std.mem.eql(u8, data.format, "obj")) {
        const mesh = try obj.read_obj(allocator, stream.reader());
        var m = try allocator.create(graphics.Mesh);
        m.* = mesh;
        return @ptrToInt(m);
    } else {
        return MeshAssetLoaderError.InvalidFormat;
    }
}

comptime {
    @import("std").testing.refAllDecls(obj);
}
