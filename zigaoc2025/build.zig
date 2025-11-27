const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule("lib", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    // const module = b.createModule(.{ .root_source_file = b.path("src/zigaoc2024.zig"), .target = target, .optimize = optimize });
    // const lib = b.addLibrary(.{ .name = "zigaoc2025", .linkage = .static, .version = .{ .major = 0, .minor = 0, .patch = 1 }, .root_module = module });

    // b.installArtifact(lib);

    // Creates an executable that will run `test` blocks from the provided module.
    // Here `mod` needs to define a target, which is why earlier we made sure to
    // set the releative field.
    const mod_tests = b.addTest(.{
        .root_module = module,
    });

    // A run step that will run the test executable.
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
