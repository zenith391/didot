const std = @import("std");
const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;
const Pkg = std.build.Pkg;

pub fn addEngineToExe(step: *LibExeObjStep) void {
    const zlm = Pkg {
        .name = "zlm",
        .path = "zlm/zlm.zig"
    };
    const image = Pkg {
        .name = "didot-image",
        .path = "didot-image/image.zig"
    };
    const graphics = Pkg {
        .name = "didot-graphics",
        .path = "didot-opengl/graphics.zig",
        .dependencies = ([_]Pkg{zlm,image})[0..]
    };
    const objects = Pkg {
        .name = "didot-objects",
        .path = "didot-objects/objects.zig",
        .dependencies = ([_]Pkg{zlm,graphics})[0..]
    };
    const models = Pkg {
        .name = "didot-models",
        .path = "didot-models/models.zig",
        .dependencies = ([_]Pkg{zlm,graphics})[0..]
    };
    const app = Pkg {
        .name = "didot-app",
        .path = "didot-app/app.zig",
        .dependencies = ([_]Pkg{objects,graphics})[0..]
    };

    step.addPackage(zlm);
    step.addPackage(image);
    step.addPackage(graphics);
    step.addPackage(objects);
    step.addPackage(models);
    step.addPackage(app);

    step.linkSystemLibrary("glfw");
    step.linkSystemLibrary("c");
    step.linkSystemLibrary("GL");
}

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("didot-example-scene", "didot-test/example-scene.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    addEngineToExe(exe);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("test", "Test Didot with didot-test/example-scene");
    run_step.dependOn(&run_cmd.step);
}
