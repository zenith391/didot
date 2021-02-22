const std = @import("std");
const graphics = @import("didot-graphics");
const Allocator = std.mem.Allocator;

const runtime_safety = @import("builtin").mode == .Debug or @import("builtin").mode == .ReleaseSafe;

pub const AssetType = enum(u8) {
    Mesh,
    Texture,
    Shader
};

pub const AssetStream = struct {
    readFn: fn(data: usize, buffer: []u8) callconv(if (std.io.is_async) .Async else .Unspecified) anyerror!usize,
    writeFn: ?fn (data: usize, buffer: []const u8) anyerror!usize = null,
    seekToFn: fn (data: usize, pos: u64) anyerror!void,
    getPosFn: fn (data: usize) anyerror!u64,
    getEndPosFn: fn (data: usize) anyerror!u64,
    closeFn: fn (data: usize) callconv(if (std.io.is_async) .Async else .Unspecified) void,
    data: usize,

    pub fn bufferStream(constBuf: []const u8) !AssetStream {
        const Data = struct { buffer: []const u8, pos: usize };
        const BufferAssetStream = struct {
            pub fn read(ptr: usize, buffer: []u8) !usize {
                const data = @intToPtr(*Data, ptr);
                const end = std.math.min(data.pos + buffer.len, data.buffer.len);
                const len = end - data.pos;
                std.mem.copy(u8, buffer, data.buffer[data.pos..end]);
                data.pos += len;
                return len;
            }

            pub fn seekTo(ptr: usize, pos: u64) !void {
                const data = @intToPtr(*Data, ptr);
                if (pos >= data.buffer.len) return error.OutOfBounds;
                data.pos = @intCast(usize, pos);
            }

            pub fn getPos(ptr: usize) !u64 {
                const data = @intToPtr(*Data, ptr);
                return data.pos;
            }

            pub fn getEndPos(ptr: usize) !u64 {
                const data = @intToPtr(*Data, ptr);
                return data.buffer.len;
            }

            pub fn close(ptr: usize) void {
                std.heap.page_allocator.destroy(@intToPtr(*Data, ptr));
            }
        };

        var data = try std.heap.page_allocator.create(Data);
        data.* = Data { .buffer = constBuf, .pos = 0 };

        return AssetStream {
            .readFn      = BufferAssetStream.read,
            .closeFn     = BufferAssetStream.close,
            .seekToFn    = BufferAssetStream.seekTo,
            .getPosFn    = BufferAssetStream.getPos,
            .getEndPosFn = BufferAssetStream.getEndPos,
            .data        = @ptrToInt(data)
        };
    }

    pub fn fileStream(path: []const u8) !AssetStream {
        const File = std.fs.File;

        const FileAssetStream = struct {
            pub fn read(ptr: usize, buffer: []u8) !usize {
                const file = @intToPtr(*File, ptr);
                return try file.read(buffer);
            }

            pub fn write(ptr: usize, buffer: []const u8) !usize {
                const file = @intToPtr(*File, ptr);
                return try file.write(buffer);
            }

            pub fn seekTo(ptr: usize, pos: u64) !void {
                const file = @intToPtr(*File, ptr);
                try file.seekTo(pos);
            }

            pub fn getPos(ptr: usize) !u64 {
                const file = @intToPtr(*File, ptr);
                return try file.getPos();
            }

            pub fn getEndPos(ptr: usize) !u64 {
                const file = @intToPtr(*File, ptr);
                return try file.getEndPos();
            }

            pub fn close(ptr: usize) void {
                const file = @intToPtr(*File, ptr);
                file.close();
                std.heap.page_allocator.destroy(file);
            }
        };

        var file = try std.heap.page_allocator.create(File);
        file.* = try std.fs.cwd().openFile(path, .{ .read = true });

        return AssetStream {
            .readFn      = FileAssetStream.read,
            .writeFn     = FileAssetStream.write,
            .closeFn     = FileAssetStream.close,
            .seekToFn    = FileAssetStream.seekTo,
            .getPosFn    = FileAssetStream.getPos,
            .getEndPosFn = FileAssetStream.getEndPos,
            .data        = @ptrToInt(file)
        };
    }

    pub const Reader         = std.io.Reader(*AssetStream, anyerror, read);
    pub const Writer         = std.io.Writer(*AssetStream, anyerror, write);
    pub const SeekableStream = std.io.SeekableStream(*AssetStream, anyerror, anyerror, seekTo, seekBy, getPos, getEndPos);

    pub fn read(self: *AssetStream, buffer: []u8) !usize {
        if (std.io.is_async) {
            var buf = try std.heap.page_allocator.alignedAlloc(u8, 16, @frameSize(self.readFn));
            defer std.heap.page_allocator.free(buf);
            var result: anyerror!usize = undefined;
            return try await @asyncCall(buf, &result, self.readFn, .{self.data, buffer});
        } else {
            return try self.readFn(self.data, buffer);
        }
    }

    pub fn seekTo(self: *AssetStream, pos: u64) !void {
        return try self.seekToFn(self.data, pos);
    }

    pub fn seekBy(self: *AssetStream, pos: i64) !void {
        return try self.seekTo(@intCast(u64, @intCast(i64, try self.getPos()) + pos));
    }

    pub fn getPos(self: *AssetStream) !u64 {
        return try self.getPosFn(self.data);
    }

    pub fn getEndPos(self: *AssetStream) !u64 {
        return try self.getEndPosFn(self.data);
    }

    pub fn write(self: *AssetStream, buffer: []const u8) !usize {
        if (self.writeFn) |func| {
            return try func(self.data, buffer);
        } else {
            return error.Unimplemented;
        }
    }

    pub fn reader(self: *AssetStream) Reader {
        return .{ .context = self };
    }

    pub fn writer(self: *AssetStream) Writer {
        return .{ .context = self };
    }

    pub fn seekableStream(self: *AssetStream) SeekableStream {
        return .{ .context = self };
    }

    pub fn deinit(self: *AssetStream) void {
        if (std.io.is_async) {
            var buf = try std.heap.page_allocator.alignedAlloc(u8, 16, @frameSize(self.closeFn));
            defer std.heap.page_allocator.free(buf);
            var result: anyerror!void = undefined;
            try await @asyncCall(buf, &result, self.closeFn, .{self.data});
        }  else {
            return try self.closeFn(self.data);
        }
    }
};

pub const AsssetStreamType = union(enum) {
    Buffer: []const u8,
    File: []const u8,
    //Http: []const u8 // TODO!
};

pub const AssetHandle = struct {
    manager: *AssetManager,
    key: []const u8,

    pub fn getPointer(self: *const AssetHandle, allocator: *Allocator) anyerror!usize {
        const asset = self.manager.getAsset(self.key).?;
        if (asset.objectPtr == 0) {
            std.log.scoped(.didot).debug("Load asset {s}", .{self.key});
        }
        return try asset.getPointer(allocator);
    }

    pub fn get(self: *const AssetHandle, comptime T: type, allocator: *Allocator) !*T {
        return @intToPtr(*T, try self.getPointer(allocator));
    }
};

pub const Asset = struct {
    /// Pointer to object
    objectPtr: usize = 0,
    objectAllocator: ?*Allocator = null,
    /// If the function is null, the asset is already loaded and unloadable is false.
    /// Otherwise this method must called, objectPtr must be set to the function result
    /// and must have been allocated on the given Allocator (or duped if not).
    /// That internal behaviour is handled with the get() function
    loader: ?fn(allocator: *Allocator, ptr: usize, stream: *AssetStream) callconv(if (std.io.is_async) .Async else .Unspecified) anyerror!usize = null,
    /// Optional data that can be used by the loader.
    loaderData: usize = 0,
    loaderFrameBuffer: []align(16) u8 = undefined,
    loaderFrameResult: anyerror!usize = undefined,
    loaderFrame: ?anyframe->anyerror!usize = null,
    objectType: AssetType,
    /// If true, after loading the asset, loader is not set to null
    /// (making it re-usable) and unload() can be called. If false, loader is
    /// set to null and cannot be unloaded.
    unloadable: bool = true,
    /// Used for the loader
    stream: AssetStream = undefined,

    pub inline fn loadAsync(self: *Asset, allocator: *Allocator) !void {
        if (std.io.is_async) {
            if (self.loader) |loader| {
                self.loaderFrameBuffer = try allocator.alignedAlloc(u8, 16, @frameSize(loader));
                self.loaderFrame = @asyncCall(self.loaderFrameBuffer, &self.loaderFrameResult, loader,
                    .{allocator, self.loaderData, &self.stream});
            } else {
                return error.NoLoader;
            }
        }
    }

    /// Allocator must be the same as the one used to create loaderData and must be the same for all calls to this function
    pub fn getPointer(self: *Asset, allocator: *Allocator) anyerror!usize {
        if (self.objectPtr == 0) {
            if (std.io.is_async) {
                if (self.loaderFrame == null) {
                    try self.loadAsync(allocator);
                }
                self.objectPtr = try await self.loaderFrame.?;
                // TODO: use lock
                self.loaderFrame = null;
                allocator.free(self.loaderFrameBuffer);
            } else {
                if (self.loader) |loader| {
                    self.objectPtr = try loader(allocator, self.loaderData, &self.stream);
                } else {
                    return error.NoLoader;
                }
            }

            self.objectAllocator = allocator;
            if (!self.unloadable) { // if it cannot be reloaded, we can destroy loaderData
                if (self.loaderData != 0) {
                    allocator.destroy(@intToPtr(*u8, self.loaderData));
                    self.loaderData = 0;
                }
                //self.loader = null;
            }
        }
        return self.objectPtr;
    }

    /// Temporarily unload the asset until it is needed again
    pub fn unload(self: *Asset) callconv(.Async) void {
        if (self.unloadable and self.objectPtr != 0) {
            // todo: add unloader optional function to Asset
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

const TextureAsset = @import("didot-graphics").TextureAsset;
const textureExtensions = [_][]const u8 {".png", ".bmp"};

pub const AssetManager = struct {
    assets: AssetMap,
    allocator: *Allocator,

    pub fn init(allocator: *Allocator) AssetManager {
        return AssetManager {
            .assets = AssetMap.init(allocator),
            .allocator = allocator
        };
    }

    pub fn autoLoad(self: *AssetManager, allocator: *Allocator) !void {
        const dirPath = try std.fs.cwd().realpathAlloc(allocator, "assets");
        defer allocator.free(dirPath);

        var walker = try std.fs.walkPath(allocator, dirPath);
        defer walker.deinit();
        while (try walker.next()) |entry| {
            //const sep: []const u8 = if (basepath.len == 0) "" else "/";
            //const path = try std.mem.concat(allocator, u8, &[_][]const u8{basepath, sep, entry.name});
            if (entry.kind == .Directory) {
                //var d = try dir.openDir(entry.name, .{ .iterate = true });
                //try self.autoLoadDir(allocator, path, &d);
            } else if (entry.kind == .File) {
                const rel = entry.path[dirPath.len+1..];
                const ext = std.fs.path.extension(entry.basename);

                var asset: ?Asset = null;
                inline for (textureExtensions) |expected| {
                    if (std.mem.eql(u8, ext, expected)) {
                        asset = try TextureAsset.init2D(allocator, expected[1..]);
                    }
                }
                if (asset) |*ast| {
                    ast.stream = try AssetStream.fileStream(entry.path);
                    try self.put(try allocator.dupe(u8, rel), ast.*);
                } else {
                    std.log.warn("No corresponding asset type for {s}", .{rel});
                }
            }
        }
    }

    pub fn comptimeAutoLoad(self: *AssetManager, allocator: *Allocator) !void {
        if (false) {
            inline for (@typeInfo(@import("didot-assets-embed")).Struct.decls) |decl| {
                const value = @field(@import("didot-assets-embed"), decl.name);

                const ext = std.fs.path.extension(decl.name);
                var asset: ?Asset = null;
                inline for (textureExtensions) |expected| {
                    if (std.mem.eql(u8, ext, expected)) {
                        asset = try TextureAsset.init2D(allocator, expected[1..]);
                    }
                }
                if (asset) |*ast| {
                    ast.stream = try AssetStream.bufferStream(value);
                    try self.put(decl.name, ast.*);
                } else {
                    std.log.warn("No corresponding asset type for {s}", .{decl.name});
                }
            }
        }
    }

    /// The returned pointer should only be temporarily used due to map resizes.
    pub fn getAsset(self: *AssetManager, key: []const u8) ?*Asset {
        if (self.assets.getEntry(key)) |entry| {
            // TODO: asynchronously start loading the asset
            return &entry.value;
        } else {
            return null;
        }
    }

    /// Stable handle to an asset
    pub fn get(self: *AssetManager, key: []const u8) ?AssetHandle {
        if (self.assets.get(key)) |*asset| {
            return AssetHandle {
                .manager = self,
                .key = key
            };
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
            const value = try asset.getPointer(self.allocator);
            try self.assets.put(key, asset.*);
            return value;
        } else {
            return null;
        }
    }

    /// Retrieve an asset from the asset manager, loading it if it wasn't already.
    pub fn getObject(self: *AssetManager, key: []const u8) anyerror!?usize {
        if (self.assets.get(key)) |*asset| {
            const value = try asset.getPointer(self.allocator);
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
