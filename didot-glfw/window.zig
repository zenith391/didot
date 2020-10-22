const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub const WindowError = error {
    InitializationError
};

const std = @import("std");
const zlm = @import("zlm");
const Vec2 = zlm.Vec2;

// TODO: more inputs and a more efficient way to do them

pub const Input = struct {
    nativeId: *c.GLFWwindow,
    lastMousePos: Vec2 = Vec2.zero,
    mouseDelta: Vec2 = Vec2.zero,
    firstFrame: bool = true,

    pub const KEY_A = c.GLFW_KEY_A;
    pub const KEY_D = c.GLFW_KEY_D;
    pub const KEY_S = c.GLFW_KEY_S;
    pub const KEY_W = c.GLFW_KEY_W;

    pub const KEY_ESCAPE = c.GLFW_KEY_ESCAPE;

    pub const KEY_UP = c.GLFW_KEY_UP;
    pub const KEY_LEFT = c.GLFW_KEY_LEFT;
    pub const KEY_RIGHT = c.GLFW_KEY_RIGHT;
    pub const KEY_DOWN = c.GLFW_KEY_DOWN;

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
        return c.glfwGetKey(self.nativeId, @intCast(c_int, key)) == c.GLFW_PRESS;
    }

    pub fn getJoystick(self: *const Input, id: u4) ?Joystick {
        if (c.glfwJoystickPresent(@intCast(c_int, id)) == c.GLFW_FALSE) {
            return null;
        } else {
            const gamepad = c.glfwJoystickIsGamepad(id) == c.GLFW_TRUE;
            const cName = if (gamepad) c.glfwGetJoystickName(id) else c.glfwGetGamepadName(id);
            var i: usize = 0;
            while (true) {
                if (cName[i] == 0) break;
                i += 1;
            }
            const name = cName[0..i];

            return Joystick {
                .id = id,
                .name = name,
                .isGamepad = gamepad
            };
        }
    }

    pub fn isMouseButtonDown(self: *const Input, button: MouseButton) bool {
        var glfwButton: c_int = 0;
        switch (button) {
            .Left => glfwButton = c.GLFW_MOUSE_BUTTON_LEFT,
            .Middle => glfwButton = c.GLFW_MOUSE_BUTTON_MIDDLE,
            .Right => glfwButton = c.GLFW_MOUSE_BUTTON_RIGHT
        }
        return c.glfwGetMouseButton(self.nativeId, glfwButton) == c.GLFW_PRESS;
    }

    pub fn getMousePosition(self: *const Input) Vec2 {
        var xpos: f64 = 0;
        var ypos: f64 = 0;
        c.glfwGetCursorPos(self.nativeId, &xpos, &ypos);
        return Vec2.new(@floatCast(f32, xpos), @floatCast(f32, ypos));
    }

    /// Set the input mode of the mouse.
    /// This allows to grab, hide or reset to normal the cursor.
    pub fn setMouseInputMode(self: *const Input, mode: MouseInputMode) void {
        var glfwMode: c_int = 0;
        switch (mode) {
            .Normal => glfwMode = c.GLFW_CURSOR_NORMAL,
            .Hidden => glfwMode = c.GLFW_CURSOR_HIDDEN,
            .Grabbed => glfwMode = c.GLFW_CURSOR_DISABLED
        }
        c.glfwSetInputMode(self.nativeId, c.GLFW_CURSOR, glfwMode);
    }

    pub fn getMouseInputMode(self: *const Input) MouseInputMode {
        var mode: c_int = c.glfwGetInputMode(self.nativeId, c.GLFW_CURSOR);
        switch (mode) {
            c.GLFW_CURSOR_NORMAL => return .Normal,
            c.GLFW_CURSOR_HIDDEN => return .Hidden,
            c.GLFW_CURSOR_DISABLED => return .Grabbed,
            else => {
                // this cannot happen
                return .Normal;
            }
        }
    }

    pub fn update(self: *Input) void {
        const pos = self.getMousePosition();
        if (self.firstFrame) {
            self.lastMousePos = pos;
            self.firstFrame = false;
        }
        self.mouseDelta = pos.sub(self.lastMousePos);
        self.lastMousePos = pos;
    }
};

pub const Window = struct {
    nativeId: *c.GLFWwindow,
    /// The input context of the window
    input: Input,

    /// Create a new window
    /// By default, the window will be resizable, with empty title and a size of 800x600.
    pub fn create() !Window {
        if (c.glfwInit() != 1) {
            std.debug.warn("Could not init GLFW!\n", .{});
            return WindowError.InitializationError;
        }
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 2);
        c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
        c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_TRUE);

        const nullableWindow = c.glfwCreateWindow(800, 600, "", null, null);
        var window: *c.GLFWwindow = undefined;
        if (nullableWindow) |win| {
            window = win;
        } else {
            std.debug.warn("Could not create GLFW window!\n", .{});
            return WindowError.InitializationError;
        }
        c.glfwMakeContextCurrent(window);
        c.glfwSwapInterval(1);
        return Window {
            .nativeId = window,
            .input = .{
                .nativeId = window
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

comptime {
    std.testing.refAllDecls(Window);
    std.testing.refAllDecls(Input);
}
