const std = @import("std");
const EngineConfig = @import("../build.zig").EngineConfig;

pub fn build(step: *std.build.LibExeObjStep, comptime config: EngineConfig) !?std.build.Pkg {
    const zlm = std.build.Pkg {
        .name = "zlm",
        .path = config.prefix ++ "zlm/zlm.zig"
    };

    const zwl = std.build.Pkg {
        .name = "zwl",
        .path = config.prefix ++ "didot-zwl/zwl/src/zwl.zig"
    };

    step.linkSystemLibrary("X11"); // necessary until zwl's x11 backend support opengl
    step.linkSystemLibrary("c");

    return std.build.Pkg {
        .name = "didot-window",
        .path = config.prefix ++ "didot-zwl/window.zig",
        .dependencies = &[_]std.build.Pkg{zlm, zwl}
    };
}
