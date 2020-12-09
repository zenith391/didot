const std = @import("std");
const graphics = @import("didot-graphics");
const Allocator = std.mem.Allocator;

const runtime_safety = @import("builtin").mode == .Debug or @import("builtin").mode == .ReleaseSafe;

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
    /// If true, after loading the asset, loader is not set to null
    /// (making it re-usable) and unload() can be called. If false, loader is
    /// set to null and cannot be unloaded.
    unloadable: bool = true,

    /// Allocator must be the same as the one used to create loaderData
    pub fn get(self: *Asset, allocator: *Allocator) !usize {
        if (self.objectPtr == 0) {
            if (self.loader) |loader| {
                self.objectPtr = try loader(allocator, self.loaderData);
                self.objectAllocator = allocator;
                if (!self.unloadable) { // if it cannot be reloaded, we can destroy loaderData
                    if (self.loaderData != 0) {
                        allocator.destroy(@intToPtr(*u8, self.loaderData));
                        self.loaderData = 0;
                    }
                    self.loader = null;
                }
            }
        }
        return self.objectPtr;
    }

    /// Temporarily unload the asset until it is needed again
    pub fn unload(self: *Asset) void {
        if (self.unloadable and self.objectPtr != 0) {
            if (self.objectAllocator) |alloc| {
                alloc.destroy(@intToPtr(*u8, self.objectPtr));
            }
            self.objectPtr = 0;
        }
    }

    pub fn deinit(self: *Asset) void {
        if (self.objectAllocator) |alloc| {
            alloc.destroy(@intToPtr(*u8, self.objectPtr));
            if (self.loaderData != 0) {
                alloc.destroy(@intToPtr(*u8, self.loaderData));
                self.loaderData = 0;
            }
        }
    }
};

pub const AssetError = error {
    UnexpectedType
};

const AssetMap = std.StringHashMap(Asset);
pub const AssetManager = struct {
    assets: AssetMap,
    allocator: *Allocator,

    pub fn init(allocator: *Allocator) AssetManager {
        var map = AssetMap.init(allocator);
        return AssetManager {
            .assets = map,
            .allocator = allocator
        };
    }

    pub fn getAsset(self: *AssetManager, key: []const u8) ?Asset {
        return self.assets.get(key);
    }

    pub inline fn isType(self: *AssetManager, key: []const u8, expected: AssetType) bool {
        if (runtime_safety) {
            if (self.assets.get(key)) |asset| {
                return asset.objectType == expected;
            } else {
                return false;
            }
        } else {
            return true;
        }
    }

    pub fn getExpected(self: *AssetManager, key: []const u8, expected: AssetType) anyerror!?usize {
        if (self.assets.get(key)) |*asset| {
            const value = try asset.get(self.allocator);
            try self.assets.put(key, asset.*);
            if (runtime_safety and asset.objectType != expected) {
                return AssetError.UnexpectedType;
            }
            return value;
        } else {
            return null;
        }
    }

    pub fn get(self: *AssetManager, key: []const u8) anyerror!?usize {
        if (self.assets.get(key)) |*asset| {
            const value = try asset.get(self.allocator);
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
