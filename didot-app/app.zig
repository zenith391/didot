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
    /// The current scene, this is set by init() and start().
    /// It can also be set manually to change scene in-game.
    scene: *Scene = undefined,
    title: [:0]const u8 = "Didot Game",
    allocator: *Allocator = undefined,
    /// Optional function to be called on application init.
    initFn: ?fn(allocator: *Allocator, app: *Application) anyerror!void = null,

    /// Initialize the application using the given allocator and scene.
    /// This creates a window, init primitives and call the init function if set.
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

    /// Start the game loop, that is doing rendering.
    /// It is also ensuring game updates and updating the window.
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

    /// Helper method to call both init() and loop().
    pub fn start(self: *Application, allocator: *Allocator, scene: *Scene) !void {
        try self.init(allocator, scene);
        try self.loop();
    }

};

test "" {
    comptime {
        std.meta.refAllDecls(Application);
    }
}