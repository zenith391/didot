//! The application module is used for managing the lifecycle of a video game.
const graphics = @import("didot-graphics");
const objects = @import("didot-objects");
const std = @import("std");
const single_threaded = @import("builtin").single_threaded;
const Allocator = std.mem.Allocator;
const Window = graphics.Window;
const Scene = objects.Scene;

/// Helper class for using Didot.
pub const Application = struct {
    /// How many time per second updates should be called, defaults to 60 updates/s.
    updateTarget: u32 = 60,
    window: Window = undefined,
    /// The current scene, this is set by init() and start().
    /// It can also be set manually to change scene in-game.
    scene: *Scene = undefined,
    title: [:0]const u8 = "Didot Game",
    allocator: *Allocator = undefined,
    /// Optional function to be called on application init.
    initFn: ?fn(allocator: *Allocator, app: *Application) anyerror!void = null,
    /// Optional function to be called on each application update.
    /// This function, depending on settings, might not execute on the main thread.
    updateFn: ?fn(tempAllocator: *Allocator, app: *Application, delta: f32) anyerror!void = null,
    closing: bool = false,
    lastUpdateTime: i64 = 0,

    /// Initialize the application using the given allocator and scene.
    /// This creates a window, init primitives and call the init function if set.
    pub fn init(self: *Application, allocator: *Allocator, scene: *Scene) !void {
        var window = try Window.create();
        window.setTitle(self.title);
        self.scene = scene;
        self.window = window;
        self.allocator = allocator;
        self.lastUpdateTime = std.time.milliTimestamp();
        objects.initPrimitives();
        
        try scene.assetManager.put("Mesh/Cube", .{
            .objectPtr = @ptrToInt(&objects.PrimitiveCubeMesh),
            .unloadable = false,
            .objectType = .Mesh
        });
        try scene.assetManager.put("Mesh/Plane", .{
            .objectPtr = @ptrToInt(&objects.PrimitivePlaneMesh),
            .unloadable = false,
            .objectType = .Mesh
        });

        if (self.initFn) |func| {
            try func(allocator, self);
        }
    }

    inline fn printErr(err: anyerror) void {
        std.debug.warn("{}", .{@errorName(err)});
        if (@errorReturnTrace()) |trace| {
            std.debug.dumpStackTrace(trace.*);
        }
    }

    fn updateTick(self: *Application, comptime doSleep: bool) void {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        const allocator = &arena.allocator;

        const s_per_frame = (1 / @intToFloat(f64, self.updateTarget)) * 1000;
        const time = std.time.milliTimestamp();
        const delta = @floatCast(f32, @intToFloat(f64, time-self.lastUpdateTime) / s_per_frame);
        if (self.updateFn) |func| {
            func(allocator, self, delta) catch |err| printErr(err);
        }
        self.scene.gameObject.update(self.allocator, delta) catch |err| printErr(err);
        self.lastUpdateTime = std.time.milliTimestamp();
        arena.deinit();
        if (doSleep) {
            const wait = @floatToInt(u64, 
                @floor((1.0/@intToFloat(f64, self.updateTarget))*1000000000.0)
            );
            std.time.sleep(wait);
        }
    }

    fn updateLoop(self: *Application) void {
        while (!self.closing) {
            self.updateTick(true);
        }
    }

    /// Start the game loop, that is doing rendering.
    /// It is also ensuring game updates and updating the window.
    pub fn loop(self: *Application) !void {
        var thread: *std.Thread = undefined;
        if (!single_threaded) {
            thread = try std.Thread.spawn(self, updateLoop);
        }
        while (self.window.update()) {
            if (single_threaded) {
                self.updateTick(false);
            }
            try self.scene.render(self.window);
        }
        self.closing = true;
        if (!single_threaded) {
            thread.wait(); // thread must be closed before scene is de-init (to avoid use-after-free)
        }
        self.closing = false;
        self.window.deinit();
        self.scene.deinitAll();
    }

    /// Helper method to call both init() and loop().
    pub fn run(self: *Application, allocator: *Allocator, scene: *Scene) !void {
        try self.init(allocator, scene);
        try self.loop();
    }

};

comptime {
    std.testing.refAllDecls(Application);
}
