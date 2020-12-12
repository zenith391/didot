const std = @import("std");

const ODE = "didot-ode/ode-0.16.2";

pub fn build(step: *std.build.LibExeObjStep) !void {
    // const b = step.builder;
    // const cwd = try std.process.getCwdAlloc(b.allocator);
    // const odePWD = try std.mem.concat(b.allocator, u8, &([_][]const u8{cwd, "/" ++ ODE}));
    // const odeBuild1 = b.addSystemCommand(
    //     &[_][]const u8{"sh", ODE ++ "/configure", "--disable-demos", "--srcdir=" ++ ODE});
    // odeBuild1.setEnvironmentVariable("PWD", odePWD);
    // odeBuild1.addPathDir(ODE);
    // // const odeBuild2 = b.addSystemCommand(&[_][]const u8{"make"});
    // // odeBuild2.setEnvironmentVariable("PWD", odePWD);
    // step.step.dependOn(&odeBuild1.step);
    // step.step.dependOn(&odeBuild2.step);
    // const flags = [_][]const u8 {"-iquote", ODE};
    // step.addCSourceFile(ODE ++ "/ode/src/array.cpp", &flags);
    step.addIncludeDir(ODE ++ "/include");
    //step.addLibPath(ODE ++ "/ode/src/.libs/");
    step.linkSystemLibraryName("ode");
    //step.linkSystemLibraryName("stdc++");
}
