const std = @import("std");
const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;
const Pkg = std.build.Pkg;

pub const EngineConfig = struct {
    /// Path to where didot is relative to the game's build.zig file. Must end with a slash or be empty.
    prefix: []const u8 = "",
    windowModule: []const u8 = "didot-glfw",
    physicsModule: []const u8 = "didot-ode",
    graphicsModule: []const u8 = "didot-opengl",
    /// Whether or not to automatically set the recommended window module depending on the target platform.
    /// Currently, didot-x11 will be used for Linux and didot-glfw for other platforms.
    autoWindow: bool = true,
    /// Whether or not to include the physics module
    usePhysics: bool = false,
    embedAssets: bool = false,
};

pub fn addEngineToExe(step: *LibExeObjStep, comptime config: EngineConfig) !void {
    const allocator = step.builder.allocator;
    const prefix = config.prefix;

    const zlm = Pkg {
        .name = "zlm",
        .path = prefix ++ "zlm/zlm.zig"
    };
    const image = Pkg {
        .name = "didot-image",
        .path = prefix ++ "didot-image/image.zig"
    };

    const windowModule = comptime blk: {
        if (config.autoWindow) {
            const target = step.target.toTarget().os.tag;
            break :blk switch (target) {
                .linux => "didot-x11",
                else => "didot-glfw"
            };
        } else {
            break :blk config.windowModule;
        }
    };

    const window = (try @import(prefix ++ windowModule ++ "/build.zig").build(step, config)) orelse Pkg {
        .name = "didot-window",
        .path = prefix ++ windowModule ++ "/window.zig",
        .dependencies = &[_]Pkg{zlm}
    };

    const graphics = Pkg {
        .name = "didot-graphics",
        .path = prefix ++ config.graphicsModule ++ "/graphics.zig",
        .dependencies = &[_]Pkg{window,image,zlm}
    };
    try @import(prefix ++ config.graphicsModule ++ "/build.zig").build(step);
    
    const models = Pkg {
        .name = "didot-models",
        .path = prefix ++ "didot-models/models.zig",
        .dependencies = &[_]Pkg{zlm,graphics}
    };

    const b = step.builder;
    const assetDep = Pkg {
        .name = "didot-assets-embed",
        .path = try std.mem.concat(allocator, u8, &[_][]const u8 {b.build_root, "/", b.cache_root, "/assets/", step.name, ".zig"})
    };
    var objDep: [5]Pkg = .{zlm,graphics,models,image,undefined};
    if (config.embedAssets) {
        objDep[4] = assetDep;
        var dir = try std.fs.openDirAbsolute(b.build_root, .{});
        defer dir.close();

        var cacheDir = try dir.openDir(b.cache_root, .{});
        var assetCacheDir = try cacheDir.makeOpenPath("assets", .{});
        defer assetCacheDir.close();
        cacheDir.close();

        const fullName = try std.mem.concat(allocator, u8, &[_][]const u8 {step.name, ".zig"});
        const cacheFile = try assetCacheDir.createFile(fullName, .{ .truncate = true });
        defer cacheFile.close();
        allocator.free(fullName);
        const writer = cacheFile.writer();

        const dirPath = try dir.realpathAlloc(allocator, "assets");
        defer allocator.free(dirPath);

        var walker = try std.fs.walkPath(allocator, dirPath);
        defer walker.deinit();
        while (try walker.next()) |entry| {
            if (entry.kind == .File) {
                const rel = entry.path[dirPath.len+1..];
                const file = try entry.dir.openFile(entry.basename, .{});
                defer file.close();
                const text = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
                try writer.print("pub const @\"{s}\" = @embedFile(\"{s}\");\n", .{rel, entry.path});
                allocator.free(text);
            }
        }
    }

    const objects = Pkg {
        .name = "didot-objects",
        .path = prefix ++ "didot-objects/objects.zig",
        .dependencies = if (config.embedAssets) &objDep else objDep[0..4]
    };

    const physics = Pkg {
        .name = "didot-physics",
        .path = prefix ++ config.physicsModule ++ "/physics.zig",
        .dependencies = &[_]Pkg{objects, zlm}
    };
    if (config.usePhysics) {
        try @import(prefix ++ config.physicsModule ++ "/build.zig").build(step);
        step.addPackage(physics);
    }



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
}

fn embedAssets(step: *LibExeObjStep) !void {
    const b = step.builder;
    const allocator = b.allocator;
    var dir = try std.fs.openDirAbsolute(b.build_root, .{});
    defer dir.close();

    var cacheDir = try dir.openDir(b.cache_root, .{});
    var assetCacheDir = try cacheDir.makeOpenPath("assets", .{});
    defer assetCacheDir.close();
    cacheDir.close();

    const fullName = try std.mem.concat(allocator, u8, &[_][]const u8 {step.name, ".zig"});
    const cacheFile = try assetCacheDir.createFile(fullName, .{ .truncate = true });
    defer cacheFile.close();
    allocator.free(fullName);
    const writer = cacheFile.writer();

    const dirPath = try dir.realpathAlloc(allocator, "assets");
    defer allocator.free(dirPath);

    var walker = try std.fs.walkPath(allocator, dirPath);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        if (entry.kind == .File) {
            const rel = entry.path[dirPath.len+1..];
            const file = try entry.dir.openFile(entry.basename, .{});
            defer file.close();
            const text = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
            try writer.print("pub const @\"{s}\" = @embedFile(\"{s}\");\n", .{rel, entry.path});
            allocator.free(text);
        }
    }

    step.addPackage(Pkg {
        .name = "didot-assets-embed",
        .path = try std.mem.concat(allocator, u8, &[_][]const u8 {b.build_root, "/", b.cache_root, "/assets/", step.name, ".zig"})
    });
}

pub fn build(b: *Builder) !void {
    const target = b.standardTargetOptions(.{});
    var mode = b.standardReleaseOptions();
    const stripExample = b.option(bool, "strip-example", "Attempt to minify examples by stripping them and changing release mode.") orelse false;

    if (@hasField(LibExeObjStep, "emit_docs")) {
        const otest = b.addTest("didot.zig");
        otest.emit_docs = true;
        //otest.emit_bin = false;
        try addEngineToExe(otest, .{
            .autoWindow = false,
            .usePhysics = true
        });

        const test_step = b.step("doc", "Test and generate documentation for Didot");
        test_step.dependOn(&otest.step);
    } else {
        const no_doc = b.addSystemCommand(&[_][]const u8{"echo", "Please build with the latest version of Zig to be able to emit documentation."});
        const no_doc_step = b.step("doc", "Test and generate documentation for Didot");
        no_doc_step.dependOn(&no_doc.step);
    }

    const examples = [_][2][]const u8 {
        .{"test-portal", "examples/test-portal/example-scene.zig"},
        .{"kart-and-cubes", "examples/kart-and-cubes/example-scene.zig"}
    };

    const engineConfig = EngineConfig {
        .windowModule = "didot-glfw",
        .autoWindow = false,
        .usePhysics = true,
        .embedAssets = true
    };

    inline for (examples) |example| {
        const name = example[0];
        const path = example[1];

        const exe = b.addExecutable(name, path);
        exe.setTarget(target);
        exe.setBuildMode(if (stripExample) @import("builtin").Mode.ReleaseSmall else mode);
        try addEngineToExe(exe, engineConfig);
        try embedAssets(exe);
        exe.single_threaded = stripExample;
        exe.strip = stripExample;
        exe.install();

        const run_cmd = exe.run();
        run_cmd.step.dependOn(&exe.install_step.?.step);

        const run_step = b.step(name, "Test Didot with the " ++ name ++ " example");
        run_step.dependOn(&run_cmd.step);
    }
}
