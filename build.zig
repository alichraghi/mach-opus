const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    _ = b.addModule("mach-flac", .{ .source_file = .{ .path = "src/lib.zig" } });

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libflac_dep = b.dependency("libFLAC", .{ .target = target, .optimize = optimize });

    const main_test = b.addTest(.{
        .root_source_file = .{ .path = "src/lib.zig" },
        .target = target,
        .optimize = optimize,
    });
    main_test.linkLibrary(libflac_dep.artifact("flac"));
    b.installArtifact(main_test);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&b.addRunArtifact(main_test).step);
}
