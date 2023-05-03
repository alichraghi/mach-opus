const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("mach-flac", .{ .source_file = .{ .path = "src/lib.zig" } });

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const main_test = b.addTest(.{
        .root_source_file = .{ .path = "src/lib.zig" },
        .target = target,
        .optimize = optimize,
    });
    main_test.linkLibC();

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&b.addRunArtifact(main_test).step);
}

const sources = [_][]const u8{
    "src/libFLAC/bitmath.c",
    "src/libFLAC/bitreader.c",
    "src/libFLAC/bitwriter.c",
    "src/libFLAC/cpu.c",
    "src/libFLAC/crc.c",
    "src/libFLAC/fixed.c",
    "src/libFLAC/fixed_intrin_sse2.c",
    "src/libFLAC/fixed_intrin_ssse3.c",
    "src/libFLAC/fixed_intrin_sse42.c",
    "src/libFLAC/fixed_intrin_avx2.c",
    "src/libFLAC/float.c",
    "src/libFLAC/format.c",
    "src/libFLAC/lpc.c",
    "src/libFLAC/lpc_intrin_neon.c",
    "src/libFLAC/lpc_intrin_sse2.c",
    "src/libFLAC/lpc_intrin_sse41.c",
    "src/libFLAC/lpc_intrin_avx2.c",
    "src/libFLAC/lpc_intrin_fma.c",
    "src/libFLAC/md5.c",
    "src/libFLAC/memory.c",
    "src/libFLAC/metadata_iterators.c",
    "src/libFLAC/metadata_object.c",
    "src/libFLAC/stream_decoder.c",
    "src/libFLAC/stream_encoder.c",
    "src/libFLAC/stream_encoder_intrin_sse2.c",
    "src/libFLAC/stream_encoder_intrin_ssse3.c",
    "src/libFLAC/stream_encoder_intrin_avx2.c",
    "src/libFLAC/stream_encoder_framing.c",
    "src/libFLAC/window.c",
};
