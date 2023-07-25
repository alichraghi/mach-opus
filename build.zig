const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    _ = b.addModule("mach-flac", .{ .source_file = .{ .path = "src/lib.zig" } });

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const main_test = b.addTest(.{
        .root_source_file = .{ .path = "src/lib.zig" },
        .target = target,
        .optimize = optimize,
    });

    const cmake_config_header = b.addConfigHeader(
        .{
            .style = .{ .cmake = .{ .path = "flac/config.cmake.h.in" } },
            .include_path = "config.h",
        },
        .{
            .CPU_IS_BIG_ENDIAN = builtin.target.cpu.arch.endian() == .Big,
            .FLAC__CPU_ARM64 = builtin.target.cpu.arch.isAARCH64(),
            .ENABLE_64_BIT_WORDS = builtin.target.ptrBitWidth() == 64,
            .FLAC__ALIGN_MALLOC_DATA = builtin.target.cpu.arch.isX86(),
            .FLAC__SYS_DARWIN = builtin.target.isDarwin(),
            .FLAC__SYS_LINUX = builtin.target.os.tag == .linux,
            .HAVE_BYTESWAP_H = true,
            .HAVE_CPUID_H = true,
            .HAVE_FSEEKO = true,
            .HAVE_INTTYPES_H = true,
            .HAVE_MEMORY_H = true,
            .HAVE_STDINT_H = true,
            .HAVE_STDLIB_H = true,
            .HAVE_STRING_H = true,
            .HAVE_TYPEOF = true,
            .HAVE_UNISTD_H = true,
        },
    );
    main_test.addConfigHeader(cmake_config_header);
    main_test.addIncludePath("flac/include");
    main_test.addIncludePath("flac/src/libFLAC/include");
    main_test.addCSourceFiles(&sources, &.{});
    main_test.defineCMacro("HAVE_CONFIG_H", null);
    main_test.linkLibC();
    b.installArtifact(main_test);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&b.addRunArtifact(main_test).step);
}

const sources = [_][]const u8{
    "flac/src/libFLAC/bitmath.c",
    "flac/src/libFLAC/bitreader.c",
    "flac/src/libFLAC/bitwriter.c",
    "flac/src/libFLAC/cpu.c",
    "flac/src/libFLAC/crc.c",
    "flac/src/libFLAC/fixed.c",
    "flac/src/libFLAC/fixed_intrin_sse2.c",
    "flac/src/libFLAC/fixed_intrin_ssse3.c",
    "flac/src/libFLAC/fixed_intrin_sse42.c",
    "flac/src/libFLAC/fixed_intrin_avx2.c",
    "flac/src/libFLAC/float.c",
    "flac/src/libFLAC/format.c",
    "flac/src/libFLAC/lpc.c",
    "flac/src/libFLAC/lpc_intrin_neon.c",
    "flac/src/libFLAC/lpc_intrin_sse2.c",
    "flac/src/libFLAC/lpc_intrin_sse41.c",
    "flac/src/libFLAC/lpc_intrin_avx2.c",
    "flac/src/libFLAC/lpc_intrin_fma.c",
    "flac/src/libFLAC/md5.c",
    "flac/src/libFLAC/memory.c",
    "flac/src/libFLAC/metadata_iterators.c",
    "flac/src/libFLAC/metadata_object.c",
    "flac/src/libFLAC/stream_decoder.c",
    "flac/src/libFLAC/stream_encoder.c",
    "flac/src/libFLAC/stream_encoder_intrin_sse2.c",
    "flac/src/libFLAC/stream_encoder_intrin_ssse3.c",
    "flac/src/libFLAC/stream_encoder_intrin_avx2.c",
    "flac/src/libFLAC/stream_encoder_framing.c",
    "flac/src/libFLAC/window.c",
};
