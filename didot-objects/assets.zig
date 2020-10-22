const std = @import("std");
const Allocator = std.mem.Allocator;

pub const AssetType = enum(u8) {
    Mesh,
    Texture,
    Shader
};

pub const Asset = struct {
    /// Pointer to object
    objectPtr: usize,
    /// If the function is null, the asset is already loaded.
    /// Otherwise this method must called, objectPtr must be set to the function result
    /// and must have been allocated on the given Allocator (or duped if not).
    /// That internal behaviour is handled with the get() function
    loader: ?fn(*Allocator, usize) usize,
    /// Optional data that can be used by the loader.
    loaderData: usize,
    objectType: AssetType,

    pub fn get(self: *Asset, allocator: *Allocator) usize {
        if (self.loader) |loader| {
            self.objectPtr = loader(allocator, loaderData);
        }
        return self.objectPtr;
    }
};

pub const AssetManager = struct {
    assets: std.StringHashMap(Asset),
    allocator: *Allocator,

    pub fn init(allocator: *Allocator) AssetManager {
        return AssetManager {
            .assets = std.StringHashMap(Asset).init(allocator),
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

    pub fn get(self: *AssetManager, key: []const u8) ?usize {
        if (self.assets.get(key)) |asset| {
            return asset.get(self.allocator);
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
}; 
