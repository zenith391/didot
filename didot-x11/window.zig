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
    nativeDisplay: *c.Display,
    nativeId: c.Window,
    /// The input context of the window
    input: Input,
    glCtx: c.GLXContext,

    /// Create a new window
    /// By default, the window will be resizable, with empty title and a size of 800x600.
    pub fn create() !Window {
        if (!@import("builtin").single_threaded) {
            _ = c.XInitThreads();
        }
        const dpy = c.XOpenDisplay(null) orelse return WindowError.InitializationError;
        const screen = c.DefaultScreen(dpy);
        const root = c.DefaultRootWindow(dpy);

        const black = c.BlackPixel(dpy, screen);
        const white = c.WhitePixel(dpy, screen);

        const window = try initGLX(dpy, root, screen);
        _ = c.XFlush(dpy);

        return Window {
            .nativeId = window,
            .nativeDisplay = dpy,
            .glCtx = undefined,
            .input = .{
                
            }
        };
    }

    fn initGLX(dpy: *c.Display, root: c.Window, screen: c_int) !c.Window {
        var att = [_]c.GLint{c.GLX_RGBA, c.GLX_DEPTH_SIZE, 24, c.GLX_DOUBLEBUFFER, c.None};
        const visual = c.glXChooseVisual(dpy, screen, &att[0]) orelse return WindowError.InitializationError;
        const colormap = c.XCreateColormap(dpy, root, visual.*.visual, c.AllocNone);
        var swa = c.XSetWindowAttributes {
            .background_pixmap = c.None,
            .background_pixel = 0,
            .border_pixmap = c.CopyFromParent,
            .border_pixel = 0,
            .bit_gravity = c.ForgetGravity,
            .win_gravity = c.NorthWestGravity,
            .backing_store = c.NotUseful,
            .backing_planes = 1,
            .backing_pixel = 0,
            .save_under = 0,
            .event_mask = 0,
            .do_not_propagate_mask = 0,
            .override_redirect = 0,
            .colormap = colormap,
            .cursor = c.None
        };
        const window = c.XCreateWindow(dpy, root, 0, 0,
                800, 600, 0, visual.*.depth, c.InputOutput,
                visual.*.visual, c.CWColormap | c.CWEventMask, &swa);
        _ = c.XMapWindow(dpy, window);
        const ctx = c.glXCreateContext(dpy, visual, null, c.GL_TRUE);
        _ = c.glXMakeCurrent(dpy, window, ctx);
        return window;
    }

    pub fn setSize(self: *const Window, width: u32, height: u32) void {

    }

    pub fn setPosition(self: *const Window, x: i32, y: i32) void {

    }

    pub fn setTitle(self: *const Window, title: [:0]const u8) void {
        _ = c.XStoreName(self.nativeDisplay, self.nativeId, title);
    }

    pub fn getPosition(self: *const Window) Vec2 {
        var x: i32 = 0;
        var y: i32 = 0;
        return Vec2.new(@intToFloat(f32, x), @intToFloat(f32, y));
    }

    pub fn getSize(self: *const Window) Vec2 {
        var width: i32 = 1;
        var height: i32 = 1;
        return Vec2.new(@intToFloat(f32, width), @intToFloat(f32, height));
    }

    pub fn getFramebufferSize(self: *const Window) Vec2 {
        var wa: c.XWindowAttributes = undefined;
        _ = c.XGetWindowAttributes(self.nativeDisplay, self.nativeId, &wa);
        return Vec2.new(@intToFloat(f32, wa.width), @intToFloat(f32, wa.height));
    }

    /// Poll events, swap buffer and update input.
    /// Returns false if the window should be closed and true otherwises.
    pub fn update(self: *Window) bool {
        std.time.sleep(16*1000000); // TODO: vsync
        c.glXSwapBuffers(self.nativeDisplay, self.nativeId);
        return true;
    }

    pub fn deinit(self: *Window) void {
        _ = c.glXMakeCurrent(self.nativeDisplay, c.None, null);
    }

};

test "" {
    comptime {
        std.meta.refAllDecls(Window);
        std.meta.refAllDecls(Input);
    }
}
