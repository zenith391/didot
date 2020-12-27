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
    /// If the function is null, the asset is already loaded and unloadable is false.
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
        return AssetManager {
            .assets = AssetMap.init(allocator),
            .allocator = allocator
        };
    }

    pub fn getAsset(self: *AssetManager, key: []const u8) anyerror!?Asset {
        if (self.assets.get(key)) |*asset| {
            const value = try asset.get(self.allocator);
            try self.assets.put(key, asset.*);
            return asset.*;
        } else {
            return null;
        }
    }

    /// Checks whether an asset's type match the 'expected argument'.
    /// For performance reasons, isType always return true in ReleaseSmall and ReleaseFast modes.
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

    /// Get the asset and asserts its type match the 'expected' argument.
    /// For performance reasons, getExpected only does the check on ReleaseSafe and Debug modes.
    pub fn getExpected(self: *AssetManager, key: []const u8, expected: AssetType) anyerror!?usize {
        if (self.assets.get(key)) |*asset| {
            if (runtime_safety and asset.objectType != expected) {
                return AssetError.UnexpectedType;
            }
            const value = try asset.get(self.allocator);
            try self.assets.put(key, asset.*);
            return value;
        } else {
            return null;
        }
    }

    /// Retrieve an asset from the asset manager, loading it if it wasn't already.
    pub fn get(self: *AssetManager, key: []const u8) anyerror!?usize {
        if (self.assets.get(key)) |*asset| {
            const value = try asset.get(self.allocator);
            try self.assets.put(key, asset.*);
            return value;
        } else {
            return null;
        }
    }

    /// Whether the asset manager has an asset with the following key.
    pub fn has(self: *AssetManager, key: []const u8) bool {
        return self.assets.get(key) != null;
    }

    /// Put the following asset with the following key in the asset manager.
    pub fn put(self: *AssetManager, key: []const u8, asset: Asset) !void {
        try self.assets.put(key, asset);
    }

    /// De-init all the assets in this asset manager.
    pub fn deinit(self: *AssetManager) void {
        var iterator = self.assets.iterator();
        while (iterator.next()) |item| {
            item.value.deinit();
        }
        self.assets.deinit();
    }
};

comptime {
    std.testing.refAllDecls(AssetManager);
    std.testing.refAllDecls(Asset);
}
