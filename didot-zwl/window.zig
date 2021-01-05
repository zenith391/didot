const zwl = @import("zwl/src/zwl.zig");

pub const WindowError = error {
    InitializationError
};

const std = @import("std");
const zlm = @import("zlm");
const Vec2 = zlm.Vec2;

// TODO: more inputs and a more efficient way to do them

pub const Input = struct {
    nativeId: u32,
    lastMousePos: Vec2 = Vec2.zero,
    mouseDelta: Vec2 = Vec2.zero,
    firstFrame: bool = true,

    pub const KEY_A = 0;
    pub const KEY_D = 0;
    pub const KEY_S = 0;
    pub const KEY_W = 0;

    pub const KEY_ESCAPE = 0;
    pub const KEY_SPACE = 0;

    pub const KEY_UP = 0;
    pub const KEY_LEFT = 0;
    pub const KEY_RIGHT = 0;
    pub const KEY_DOWN = 0;

    pub const MouseInputMode = enum {
        Normal,
        Hidden,
        Grabbed
    };

    pub const MouseButton = enum {
        Left,
        Middle,
        Right
    };

    pub const Joystick = struct {
        id: u4,
        name: []const u8,
        /// This doesn't necessarily means the joystick *IS* a gamepad, this means it is registered in the DB.
        isGamepad: bool,

        pub const ButtonType = enum {
            A,
            B,
            X,
            Y,
            LeftBumper,
            RightBumper,
            Back,
            Start,
            Guide,
            LeftThumb,
            RightThumb,
            DPad_Up,
            DPad_Right,
            DPad_Down,
            DPad_Left
        };

        pub fn getRawAxes(self: *const Joystick) []const f32 {
            var count: c_int = 0;
            const axes = c.glfwGetJoystickAxes(self.id, &count);
            return axes[0..@intCast(usize, count)];
        }

        pub fn getRawButtons(self: *const Joystick) []bool {
            var count: c_int = 0;
            const cButtons = c.glfwGetJoystickButtons(self.id, &count);
            var cButtonsBool: [15]bool = undefined;

            var i: usize = 0;
            while (i < count) {
                cButtonsBool[i] = cButtons[i] == c.GLFW_PRESS;
                i += 1;
            }

            return cButtonsBool[0..@intCast(usize, count)];
        }

        pub fn getAxes(self: *const Joystick) []const f32 {
            if (self.isGamepad) {
                var state: c.GLFWgamepadstate = undefined;
                _ = c.glfwGetGamepadState(self.id, &state);
                return state.axes[0..6];
            } else {
                return self.getRawAxes();
            }
        }

        pub fn isButtonDown(self: *const Joystick, btn: ButtonType) bool {
            const buttons = self.getButtons();
            return buttons[@enumToInt(btn)];
        }

        pub fn getButtons(self: *const Joystick) []bool {
            if (self.isGamepad) {
                var state: c.GLFWgamepadstate = undefined;
                _ = c.glfwGetGamepadState(self.id, &state);
                var buttons: [15]bool = undefined;
                for (state.buttons[0..15]) |value, i| {
                    buttons[i] = value == c.GLFW_PRESS;
                }
                return buttons[0..];
            } else {
                return self.getRawButtons();
            }
        }
    };

    fn init(self: *const Input) void {

    }

    /// Returns true if the key is currently being pressed.
    pub fn isKeyDown(self: *const Input, key: u32) bool {
        return false;
    }

    pub fn getJoystick(self: *const Input, id: u4) ?Joystick {
        return null;
    }

    pub fn isMouseButtonDown(self: *const Input, button: MouseButton) bool {
        return false;
    }

    pub fn getMousePosition(self: *const Input) Vec2 {
        return Vec2.new(0, 0);
    }

    /// Set the input mode of the mouse.
    /// This allows to grab, hide or reset to normal the cursor.
    pub fn setMouseInputMode(self: *const Input, mode: MouseInputMode) void {

    }

    pub fn getMouseInputMode(self: *const Input) MouseInputMode {
        return MouseInputMode.Normal;
    }

    pub fn update(self: *Input) void {

    }
};

pub const Window = struct {
    const Platform = zwl.Platform(.{
        .single_window = true,
        .backends_enabled = .{
            .opengl = true
        },
        .platforms_enabled = .{
            .x11 = false,
            .xlib = true // temporary, for OpenGL support
        }
    });

    /// The input context of the window
    input: Input,
    platform: *Platform,
    nativeId: *Platform.Window,

    /// Create a new window
    /// By default, the window will be resizable, with empty title and a size of 800x600.
    pub fn create() !Window {
        var platform = try Platform.init(std.heap.page_allocator, .{});
        var window = try platform.createWindow(.{
            .resizeable = true,
            .decorations = true,
            .track_keyboard = true,
            .track_mouse = true,
            .title = "",
            .backend = .{
                .opengl = .{
                    .major = 3, .minor = 2
                }
            }
        });

        return Window {
            .nativeId = window,
            .platform = platform,
            .input = .{
                .nativeId = 0
            }
        };
    }

    pub fn setSize(self: *const Window, width: u32, height: u32) void {
        var w = @floor(width);
        var h = @floor(height);
        if (w > std.math.maxInt(u16) or h > std.math.maxInt(u16)) {
            std.log.warn("Unable to set size to {d}x{d} : ZWL only supports up to a 65535x65535 window size, size will be set to 655535x65535", .{w, h});
            w = @intToFloat(f32, std.math.maxInt(u16));
            h = @intToFloat(f32, std.math.maxInt(u16));
        }
        self.nativeId.configure(.{
            .width = @floatToInt(u16, w),
            .height = @floatToInt(u16, h)
        });
    }

    pub fn setPosition(self: *const Window, x: i32, y: i32) void {

    }

    pub fn setTitle(self: *const Window, title: [:0]const u8) void {
        self.nativeId.configure(.{
            .title = title
        }) catch unreachable; // TODO: handle error on title change?
    }

    pub fn getPosition(self: *const Window) Vec2 {
        return Vec2.new(0, 0);
    }

    pub fn getSize(self: *const Window) Vec2 {
        return self.getFramebufferSize();
    }

    pub fn getFramebufferSize(self: *const Window) Vec2 {
        var size = self.nativeId.getSize();
        return Vec2.new(@intToFloat(f32, size[0]), @intToFloat(f32, size[1]));
    }

    /// Poll events, swap buffer and update input.
    /// Returns false if the window should be closed and true otherwises.
    pub fn update(self: *Window) bool {
        self.input.update();
        self.nativeId.present() catch unreachable;
        return true;
    }

    pub fn deinit(self: *Window) void {
        self.nativeId.deinit();
        self.platform.deinit();
    }

};

comptime {
    std.testing.refAllDecls(Window);
    std.testing.refAllDecls(Input);
}
