const std = @import("std");

pub fn build(step: *std.build.LibExeObjStep) !void {
    step.linkSystemLibrary("GL");
}
