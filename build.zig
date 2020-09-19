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
        .dependencies = &[_]Pkg{zlm,image}
    };
    const objects = Pkg {
        .name = "didot-objects",
        .path = "didot-objects/objects.zig",
        .dependencies = &[_]Pkg{zlm,graphics}
    };
    const models = Pkg {
        .name = "didot-models",
        .path = "didot-models/models.zig",
        .dependencies = &[_]Pkg{zlm,graphics}
    };
    const app = Pkg {
        .name = "didot-app",
        .path = "didot-app/app.zig",
        .dependencies = &[_]Pkg{objects,graphics}
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

    const exe = b.addExecutable("didot-example-scene", "examples/kart-and-cubes/example-scene.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    addEngineToExe(exe);
    //exe.single_threaded = true;
    //exe.strip = true;
    exe.install();

    if (@hasField(LibExeObjStep, "emit_docs")) {
        const otest = b.addTest("didot.zig");
        otest.emit_docs = true;
        //otest.emit_bin = false;
        otest.output_dir = "docs";
        addEngineToExe(otest);

        const test_step = b.step("doc", "Test and document Didot");
        test_step.dependOn(&otest.step);
    } else {
        const no_doc = b.addSystemCommand(&[_][]const u8{"echo", "Please build with the latest version of Zig to be able to emit documentation."});
        const no_doc_step = b.step("doc", "Test and document Didot");
        no_doc_step.dependOn(&no_doc.step);
    }

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("example", "Test Didot with kart-and-cubes example");
    run_step.dependOn(&run_cmd.step);
}
