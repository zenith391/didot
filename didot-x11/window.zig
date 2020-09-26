const c = @import("c.zig");

pub const WindowError = error {
    InitializationError
};

const std = @import("std");
const zlm = @import("zlm");
const Vec2 = zlm.Vec2;

// TODO: more inputs and a more efficient way to do them

pub const Input = struct {
    pub const KEY_A = 0;
    pub const KEY_D = 0;
    pub const KEY_S = 0;
    pub const KEY_W = 0;

    pub const KEY_ESCAPE = 0;

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
        c.glfwSetInputMode(self.nativeId, c.GLFW_STICKY_MOUSE_BUTTONS, c.GLFW_TRUE);
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
        return undefined;
    }

    /// Set the input mode of the mouse.
    /// This allows to grab, hide or reset to normal the cursor.
    pub fn setMouseInputMode(self: *const Input, mode: MouseInputMode) void {
        
    }

    pub fn getMouseInputMode(self: *const Input) MouseInputMode {
        return .Normal;
    }

    pub fn update(self: *Input) void {
        
    }
};

pub const Window = struct {
    nativeId: *c.Window,
    /// The input context of the window
    input: Input,

    /// Create a new window
    /// By default, the window will be resizable, with empty title and a size of 800x600.
    pub fn create() !Window {
        var dpy: *c.Display = c.XOpenDisplay(null) orelse return WindowError.InitializationError;
        var screen = c.DefaultScreen(dpy);

        var black = c.BlackPixel(dpy, screen);
        var white = c.WhitePixel(dpy, screen);
        var window = c.XCreateSimpleWindow(dpy, c.DefaultRootWindow(dpy), 0, 0,
                200, 100, 0, black, black);
        c.XMapWindow(dpy, window);

        return Window {
            .nativeId = window,
            .input = .{
                
            }
        };
    }

    pub fn setSize(self: *const Window, width: u32, height: u32) void {
        c.glfwSetWindowSize(self.nativeId, @intCast(c_int, width), @intCast(c_int, height));
    }

    pub fn setPosition(self: *const Window, x: i32, y: i32) void {
        c.glfwSetWindowPos(self.nativeId, @intCast(c_int, x), @intCast(c_int, y));
    }

    pub fn setTitle(self: *const Window, title: [:0]const u8) void {
        c.glfwSetWindowTitle(self.nativeId, title);
    }

    pub fn getPosition(self: *const Window) Vec2 {
        var x: i32 = 0;
        var y: i32 = 0;
        c.glfwGetWindowPos(self.nativeId, &y, &x);
        return Vec2.new(@intToFloat(f32, x), @intToFloat(f32, y));
    }

    pub fn getSize(self: *const Window) Vec2 {
        var width: i32 = 0;
        var height: i32 = 0;
        c.glfwGetWindowSize(self.nativeId, &width, &height);
        return Vec2.new(@intToFloat(f32, width), @intToFloat(f32, height));
    }

    pub fn getFramebufferSize(self: *const Window) Vec2 {
        var width: i32 = 0;
        var height: i32 = 0;
        c.glfwGetFramebufferSize(self.nativeId, &width, &height);
        return Vec2.new(@intToFloat(f32, width), @intToFloat(f32, height));
    }

    /// Poll events, swap buffer and update input.
    /// Returns false if the window should be closed and true otherwises.
    pub fn update(self: *Window) bool {
        c.glfwMakeContextCurrent(self.nativeId);
        c.glfwSwapBuffers(self.nativeId);
        c.glfwPollEvents();
        self.input.update();
        return c.glfwWindowShouldClose(self.nativeId) == 0;
    }

    pub fn deinit(self: *Window) void {
        c.glfwTerminate();
    }

};

test "" {
    comptime {
        std.meta.refAllDecls(Window);
        std.meta.refAllDecls(Input);
    }
}
