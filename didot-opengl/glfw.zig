const c = @import("c.zig");
const WindowError = @import("graphics.zig").WindowError;
const std = @import("std");
const zlm = @import("zlm");
const Vec2 = zlm.Vec2;

pub const Window = struct {
    nativeId: *c.GLFWwindow,

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

        return Window {
            .nativeId = window
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

    /// Poll events and swap buffer
    /// Returns false if the window is closed and true otherwises.
    pub fn update(self: *Window) bool {
        c.glfwMakeContextCurrent(self.nativeId);
        c.glfwSwapBuffers(self.nativeId);
        c.glfwPollEvents();
        return c.glfwWindowShouldClose(self.nativeId) == 0;
    }

    pub fn deinit(self: *Window) void {
        c.glfwTerminate();
    }

};
