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
    /// Temporarily disabled!
    autoWindow: bool = true,
    /// Whether or not to include the physics module
    usePhysics: bool = false,
    embedAssets: bool = false,
};

pub fn addEngineToExe(step: *LibExeObjStep, comptime config: EngineConfig) !void {
    const prefix = config.prefix;

    const zlm = Pkg {
        .name = "zalgebra",
        .path = std.build.FileSource.relative(prefix ++ "zalgebra/src/main.zig")
    };
    const image = Pkg {
        .name = "didot-image",
        .path = std.build.FileSource.relative(prefix ++ "didot-image/image.zig")
    };

    const windowModule = comptime blk: {
        // if (config.autoWindow) {
        //     const target = step.target.toTarget().os.tag;
        //     break :blk switch (target) {
        //         .linux => "didot-x11",
        //         else => "didot-glfw"
        //     };
        // } else {
            break :blk config.windowModule;
        // }
    };

    if (!comptime std.mem.eql(u8, windowModule, "didot-glfw")) {
        @compileError("windowing module must be didot-glfw");
    } else if (!comptime std.mem.eql(u8, config.graphicsModule, "didot-opengl")) {
        @compileError("graphics module must be OpenGL");
    } else if (!comptime std.mem.eql(u8, config.physicsModule, "didot-ode")) {
        @compileError("graphics module must be ODE");
    }

    //const windowPath = windowModule ++ "/build.zig";
    const window = (try @import("didot-glfw/build.zig").build(step, config)) orelse Pkg {
        .name = "didot-window",
        .path = std.build.FileSource.relative(prefix ++ windowModule ++ "/window.zig"),
        .dependencies = &[_]Pkg{zlm}
    };

    const graphics = Pkg {
        .name = "didot-graphics",
        .path = std.build.FileSource.relative(prefix ++ config.graphicsModule ++ "/main.zig"),
        .dependencies = &[_]Pkg{window,image,zlm}
    };
    try @import("didot-opengl/build.zig").build(step);
    
    const models = Pkg {
        .name = "didot-models",
        .path = std.build.FileSource.relative(prefix ++ "didot-models/models.zig"),
        .dependencies = &[_]Pkg{zlm,graphics}
    };

    if (config.embedAssets) {
        try createBundle(step);
    }

    const objects = Pkg {
        .name = "didot-objects",
        .path = std.build.FileSource.relative(prefix ++ "didot-objects/main.zig"),
        .dependencies = &[_]Pkg{zlm,graphics,models,image}
    };

    const physics = Pkg {
        .name = "didot-physics",
        .path = std.build.FileSource.relative(prefix ++ config.physicsModule ++ "/physics.zig"),
        .dependencies = &[_]Pkg{objects, zlm}
    };
    if (config.usePhysics) {
        try @import("didot-ode/build.zig").build(step);
        step.addPackage(physics);
    }

    const app = Pkg {
        .name = "didot-app",
        .path = std.build.FileSource.relative(prefix ++ "didot-app/app.zig"),
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

fn createBundle(step: *LibExeObjStep) !void {
    const b = step.builder;
    const allocator = b.allocator;
    var dir = try std.fs.openDirAbsolute(b.build_root, .{});
    defer dir.close();

    var cacheDir = try dir.openDir(b.cache_root, .{});
    defer cacheDir.close();
    (try cacheDir.makeOpenPath("assets", .{})).close(); // mkdir "assets"

    const fullName = try std.mem.concat(allocator, u8, &[_][]const u8 {"assets/", step.name, ".bundle"});
    const cacheFile = try cacheDir.createFile(fullName, .{ .truncate = true });
    defer cacheFile.close();
    allocator.free(fullName);
    const writer = cacheFile.writer();

    const dirPath = try dir.realpathAlloc(allocator, "assets");
    defer allocator.free(dirPath);

    var walkedDir = try std.fs.openDirAbsolute(dirPath, .{ .iterate = true });
    defer walkedDir.close();

    var count: u64 = 0;

    // Count the number of items
    {
        var walker = try walkedDir.walk(allocator);
        defer walker.deinit();
        while ((try walker.next()) != null) {
            count += 1;
        }
    }

    var walker = try walkedDir.walk(allocator);
    defer walker.deinit();

    try writer.writeByte(0); // no compression
    try writer.writeIntLittle(u64, count);
    while (try walker.next()) |entry| {
        if (entry.kind == .File) {
            const path = entry.path[dirPath.len+1..];
            const file = try std.fs.openFileAbsolute(entry.path, .{});
            defer file.close();
            const data = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
            defer allocator.free(data);

            try writer.writeIntLittle(u32, @intCast(u32, path.len));
            try writer.writeIntLittle(u32, @intCast(u32, data.len));
            try writer.writeAll(path);
            try writer.writeAll(data);
        }
    }
}

pub fn build(b: *Builder) !void {
    var target = b.standardTargetOptions(.{});
    var mode = b.standardReleaseOptions();
    const stripExample = b.option(bool, "strip-example", "Attempt to minify examples by stripping them and changing release mode.") orelse false;
    const wasm = b.option(bool, "wasm-target", "Compile the code to run on WASM backend.") orelse false;

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
        .{"kart-and-cubes", "examples/kart-and-cubes/example-scene.zig"},
        .{"planet-test", "examples/planet-test/example-scene.zig"}
    };

    const engineConfig = EngineConfig {
        .windowModule = "didot-glfw",
        .graphicsModule = "didot-opengl",
        .autoWindow = false,
        .usePhysics = true,
        .embedAssets = true
    };

    if (wasm) {
        target = try std.zig.CrossTarget.parse(.{
            .arch_os_abi = "wasm64-freestanding-gnu"
        });
    }

    inline for (examples) |example| {
        const name = example[0];
        const path = example[1];

        const exe = b.addExecutable(name, path);
        exe.setTarget(target);
        exe.setBuildMode(if (stripExample) std.builtin.Mode.ReleaseSmall else mode);
        try addEngineToExe(exe, engineConfig);
        exe.single_threaded = stripExample;
        exe.strip = stripExample;
        exe.install();

        const run_cmd = exe.run();
        run_cmd.step.dependOn(&exe.install_step.?.step);

        const run_step = b.step(name, "Test Didot with the " ++ name ++ " example");
        run_step.dependOn(&run_cmd.step);
    }
}
