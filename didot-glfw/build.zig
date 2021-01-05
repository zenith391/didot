const std = @import("std");
const EngineConfig = @import("../build.zig").EngineConfig;

pub fn build(step: *std.build.LibExeObjStep, comptime config: EngineConfig) !?std.build.Pkg {
    step.linkSystemLibrary("glfw");
    step.linkLibC();
    return null;
}
