const c = @import("c.zig");
const WindowError = @import("graphics.zig").WindowError;
const std = @import("std");

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

        const nullableWindow = c.glfwCreateWindow(800, 600, "Didot Game", null, null);
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

    /// Poll events and swap buffer
    /// Returns false if the window is closed and true otherwises.
    pub fn update(self: *Window) bool {
        c.glfwSwapBuffers(self.nativeId);
        c.glfwPollEvents();
        return c.glfwWindowShouldClose(self.nativeId) == 1;
    }

    pub fn deinit(self: *Window) void {
        c.glfwTerminate();
    }

};
