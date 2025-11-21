const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("prep2", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "prep2",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "prep2", .module = mod },
            },
        }),
    });

    // detail regex library as fetched with: zig fetch --save "https://github.com/mnemnion/mvzr/archive/refs/tags/v0.3.7.tar.gz"
    const mvzr = b.dependency("mvzr", .{ .target = target, .optimize = optimize });
    const module = mvzr.module("mvzr");
    exe.root_module.addImport("mvzr", module);

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
