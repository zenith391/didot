//! The application module is used for managing the lifecycle of a video game.
const graphics = @import("didot-graphics");
const Window = graphics.Window;

pub const Application = struct {
	// How many time per second update should be called, defaults to 30 updates/s.
	updateTarget: u32 = 30,
	window: Window = null,

	pub fn start() !void {
		var window = Window.create();

		while (window.update()) {

		}
		window.deinit();
	}
};
