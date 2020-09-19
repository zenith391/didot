//! The application module is used for managing the lifecycle of a video game.
const graphics = @import("didot-graphics");
const objects = @import("didot-objects");
const std = @import("std");
const Allocator = std.mem.Allocator;
const Window = graphics.Window;
const Scene = objects.Scene;

pub const Application = struct {
    /// How many time per second updates should be called, defaults to 60 updates/s.
    updateTarget: u32 = 60,
    window: Window = undefined,
    scene: *Scene = undefined,
    title: [:0]const u8 = "Didot Game",
    allocator: *Allocator = undefined,
    /// Optional function to be called on application init.
    initFn: ?fn(allocator: *Allocator, app: *Application) anyerror!void = null,

    pub fn init(self: *Application, allocator: *Allocator, scene: *Scene) !void {
        var window = try Window.create();
        window.setTitle(self.title);
        self.scene = scene;
        self.window = window;
        self.allocator = allocator;
        objects.initPrimitives();
        if (self.initFn) |func| {
            try func(allocator, self);
        }
    }

    pub fn loop(self: *Application) !void {
        while (self.window.update()) {
            var arena = std.heap.ArenaAllocator.init(self.allocator);
            const allocator = &arena.allocator;
            // TODO: move updating to a separate thread (so rendering doesn't affect updates and vice versa)
            try self.scene.gameObject.update(allocator, 1); // TODO: correctly handle errors
            arena.deinit();

            self.scene.render(self.window);
        }
        self.window.deinit();
    }

    pub fn start(self: *Application, allocator: *Allocator, scene: *Scene) !void {
        try self.init(allocator, scene);
        try self.loop();
    }

};
