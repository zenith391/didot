const std = @import("std");
const graphics = @import("didot-graphics");
const Allocator = std.mem.Allocator;

pub const AssetType = enum(u8) {
    Mesh,
    Texture,
    Shader
};

pub const Asset = struct {
    /// Pointer to object
    objectPtr: usize = 0,
    objectAllocator: ?*Allocator = null,
    /// If the function is null, the asset is already loaded.
    /// Otherwise this method must called, objectPtr must be set to the function result
    /// and must have been allocated on the given Allocator (or duped if not).
    /// That internal behaviour is handled with the get() function
    loader: ?fn(*Allocator, usize) anyerror!usize = null,
    /// Optional data that can be used by the loader.
    loaderData: usize = 0,
    objectType: AssetType,

    pub fn get(self: *Asset, allocator: *Allocator) !usize {
        if (self.loader) |loader| {
            self.objectPtr = try loader(allocator, self.loaderData);
            self.objectAllocator = allocator;
            self.loader = null;
        }
        return self.objectPtr;
    }

    pub fn deinit(self: *const Asset) void {
        if (self.objectAllocator) |alloc| {
            alloc.destroy(@intToPtr(*u8, self.objectPtr));
        }
    }
};

pub const AssetManager = struct {
    assets: std.StringHashMap(Asset),
    allocator: *Allocator,

    pub fn init(allocator: *Allocator) AssetManager {
        var map = std.StringHashMap(Asset).init(allocator);
        return AssetManager {
            .assets = map,
            .allocator = allocator
        };
    }

    pub fn getAsset(self: *AssetManager, key: []const u8) ?Asset {
        return self.assets.get(key);
    }

    pub inline fn isType(self: *AssetManager, key: []const u8, expected: AssetType) bool {
        if (@import("builtin").mode == .Debug or @import("builtin").mode == .ReleaseSafe) {
            if (self.assets.get(key)) |asset| {
                return asset.objectType == expected;
            }
        } else {
            return true;
        }
    }

    pub fn get(self: *AssetManager, key: []const u8) !?usize {
        if (self.assets.get(key)) |*asset| {
            var value = try asset.get(self.allocator);
            try self.assets.put(key, asset.*);
            return value;
        } else {
            return null;
        }
    }

    pub fn has(self: *AssetManager, key: []const u8) bool {
        return self.assets.get(key) != null;
    }

    pub fn put(self: *AssetManager, key: []const u8, asset: Asset) !void {
        try self.assets.put(key, asset);
    }

    pub fn deinit(self: *AssetManager) void {
        var iterator = self.assets.iterator();
        while (iterator.next()) |item| {
            item.value.deinit();
        }
        self.assets.deinit();
    }
}; 
