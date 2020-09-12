const std = @import("std");
const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;

pub fn buildEngine(step: *LibExeObjStep) void {
    step.addPackage(.{ .name = "zlm", .path = "zlm/zlm.zig" });
    step.addPackage(.{ .name = "didot-graphics", .path = "didot-graphics/graphics.zig"});
    step.addPackage(.{ .name = "didot-image", .path = "didot-image/image.zig"});
    step.linkSystemLibrary("glfw");
    step.linkSystemLibrary("c");
    step.linkSystemLibrary("GL");
}

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("didot-test", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    buildEngine(exe);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("test", "Test Didot with didot-test");
    run_step.dependOn(&run_cmd.step);
}
