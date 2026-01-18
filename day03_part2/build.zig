const std = @import("std");

pub fn build(b: *std.Build) void {
    const package_name = "day3_part2";
    // b.verbose_llvm_ir = "";
    // b.verbose = true;
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule(package_name, .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const exe = b.addExecutable(.{
        .use_llvm = true, // allows for llvm debugger to work correctly
        .name = package_name,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = package_name, .module = mod },
            },
        }),
    });

    b.installArtifact(exe);

    const zigaoc2025_package = b.dependency("zigaoc2025", .{
        .target = target,
        .optimize = optimize,
    });

    const zigaoc2025_module = zigaoc2025_package.module("lib");
    exe.root_module.addImport("libaoc", zigaoc2025_module);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
