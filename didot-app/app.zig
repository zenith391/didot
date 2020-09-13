//! The application module is used for managing the lifecycle of a video game.
const graphics = @import("didot-graphics");
const objects = @import("didot-objects");
const Window = graphics.Window;
const Scene = objects.Scene;

pub const Application = struct {
    // How many time per second update should be called, defaults to 30 updates/s.
    updateTarget: u32 = 30,
    window: Window = undefined,
    scene: *Scene = undefined,

    pub fn init(self: *Application, scene: *Scene) !void {
        var window = try Window.create();
        self.scene = scene;
        self.window = window;
        objects.initPrimitives();
    }

    pub fn loop(self: *Application) void {
        while (self.window.update()) {
            self.scene.render(self.window);
        }
        self.window.deinit();
    }
};
