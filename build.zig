const std = @import("std");
const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;
const Pkg = std.build.Pkg;

pub const EngineConfig = struct {
    /// Path to where didot is relative to the game's build.zig file. Must end with a slash.
    prefix: []const u8 = "",
    windowModule: []const u8 = "didot-glfw",
    physicsModule: []const u8 = "didot-ode",
    /// Whether or not to automatically set the window module depending on the target platform.
    /// didot-glfw will be used for Windows and didot-x11 will be used for Linux.
    autoWindow: bool = true,
    /// Whether or not to include the physics module
    usePhysics: bool = false
};

/// hacky workaround some compiler bug
var graphics_deps: [3]Pkg = undefined;

pub fn addEngineToExe(step: *LibExeObjStep, comptime config: EngineConfig) !void {
    var allocator = step.builder.allocator;
    const prefix = config.prefix;

    const zlm = Pkg {
        .name = "zlm",
        .path = prefix ++ "zlm/zlm.zig"
    };
    const image = Pkg {
        .name = "didot-image",
        .path = prefix ++ "didot-image/image.zig"
    };

    var windowModule = config.windowModule;
    if (config.autoWindow) {
        const target = step.target.toTarget().os.tag;
        switch (target) {
            .linux => {
                windowModule = "didot-x11";
            },
            else => {}
        }
    }

    const windowPath = try std.mem.concat(allocator, u8, &[_][]const u8{prefix, windowModule, "/window.zig"});
    if (std.mem.eql(u8, windowModule, "didot-glfw")) {
        step.linkSystemLibrary("glfw");
        step.linkSystemLibrary("c");
    }
    if (std.mem.eql(u8, windowModule, "didot-x11")) {
        step.linkSystemLibrary("X11");
        step.linkSystemLibrary("c");
    }
    const window = Pkg {
        .name = "didot-window",
        .path = windowPath,
        .dependencies = &[_]Pkg{zlm}
    };
    graphics_deps[0] = window;
    graphics_deps[1] = image;
    graphics_deps[2] = zlm;

    const graphics = Pkg {
        .name = "didot-graphics",
        .path = prefix ++ "didot-opengl/graphics.zig",
        .dependencies = &graphics_deps
    };
    step.linkSystemLibrary("GL");
    
    const models = Pkg {
        .name = "didot-models",
        .path = prefix ++ "didot-models/models.zig",
        .dependencies = &[_]Pkg{zlm,graphics}
    };
    const objects = Pkg {
        .name = "didot-objects",
        .path = prefix ++ "didot-objects/objects.zig",
        .dependencies = &[_]Pkg{zlm,graphics}
    };

    const physics = Pkg {
        .name = "didot-physics",
        .path = prefix ++ config.physicsModule ++ "/physics.zig",
        .dependencies = &[_]Pkg{objects, zlm}
    };
    if (config.usePhysics)
        try @import(prefix ++ config.physicsModule ++ "/build.zig").build(step);

    const app = Pkg {
        .name = "didot-app",
        .path = prefix ++ "didot-app/app.zig",
        .dependencies = &[_]Pkg{objects,graphics}
    };

    step.addPackage(zlm);
    step.addPackage(image);
    step.addPackage(window);
    step.addPackage(graphics);
    step.addPackage(objects);
    step.addPackage(models);
    step.addPackage(app);
    if (config.usePhysics)
        step.addPackage(physics);
}

pub fn build(b: *Builder) !void {
    const target = b.standardTargetOptions(.{});
    var mode = b.standardReleaseOptions();
    const stripExample = b.option(bool, "strip-example", "Attempt to minify examples by stripping them and changing release mode.") orelse false;

    const exe = b.addExecutable("didot-example-scene", "examples/kart-and-cubes/example-scene.zig");
    exe.setTarget(target);
    exe.setBuildMode(if (stripExample) @import("builtin").Mode.ReleaseSmall else mode);
    try addEngineToExe(exe, .{
        //.windowModule = "didot-x11"
        .autoWindow = false,
        .usePhysics = true
    });
    exe.single_threaded = stripExample;
    exe.strip = stripExample;
    exe.install();

    if (@hasField(LibExeObjStep, "emit_docs") and false) {
        const otest = b.addTest("didot.zig");
        otest.emit_docs = true;
        //otest.emit_bin = false;
        otest.setOutputDir("docs");
        try addEngineToExe(otest, .{
            .autoWindow = false
        });

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
