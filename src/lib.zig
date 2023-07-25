const std = @import("std");
const c = @cImport(@cInclude("FLAC/stream_decoder.h"));

const Flac = @This();

channels: u8,
sample_rate: u24,
samples: []i32,

pub const DecodeError = error{
    OutOfMemory,
    InvalidData,
};

pub fn decodeStream(allocator: std.mem.Allocator, stream: std.io.StreamSource) (DecodeError || std.io.StreamSource.ReadError)!Flac {
    var data = DecodeData{ .allocator = allocator, .stream = stream };
    var decoder = c.FLAC__stream_decoder_new() orelse return error.OutOfMemory;

    switch (c.FLAC__stream_decoder_init_stream(
        decoder,
        readCallback,
        seekCallback,
        tellCallback,
        lengthCallback,
        eofCallback,
        writeCallback,
        metadataCallback,
        errorCallback,
        &data,
    )) {
        c.FLAC__STREAM_DECODER_INIT_STATUS_OK => {},
        c.FLAC__STREAM_DECODER_INIT_STATUS_UNSUPPORTED_CONTAINER => unreachable,
        c.FLAC__STREAM_DECODER_INIT_STATUS_INVALID_CALLBACKS => unreachable,
        c.FLAC__STREAM_DECODER_INIT_STATUS_MEMORY_ALLOCATION_ERROR => return error.OutOfMemory,
        c.FLAC__STREAM_DECODER_INIT_STATUS_ERROR_OPENING_FILE => unreachable,
        c.FLAC__STREAM_DECODER_INIT_STATUS_ALREADY_INITIALIZED => unreachable,
        else => unreachable,
    }

    if (c.FLAC__stream_decoder_process_until_end_of_stream(decoder) == 0) {
        switch (data.status) {
            c.FLAC__STREAM_DECODER_ERROR_STATUS_LOST_SYNC => unreachable,
            c.FLAC__STREAM_DECODER_ERROR_STATUS_BAD_HEADER => return error.InvalidData,
            c.FLAC__STREAM_DECODER_ERROR_STATUS_FRAME_CRC_MISMATCH => return error.InvalidData,
            c.FLAC__STREAM_DECODER_ERROR_STATUS_UNPARSEABLE_STREAM => return error.InvalidData,
            c.FLAC__STREAM_DECODER_ERROR_STATUS_BAD_METADATA => return error.InvalidData,
            else => unreachable,
        }
    }

    return .{
        .channels = data.channels,
        .sample_rate = @intCast(data.sample_rate),
        .samples = data.samples,
    };
}

const DecodeData = struct {
    allocator: std.mem.Allocator,
    stream: std.io.StreamSource,
    channels: u8 = 0,
    sample_rate: u24 = 0,
    bits_per_sample: u8 = 0,
    bytes_per_sample: u8 = 0,
    total_samples: usize = 0,
    status: c.FLAC__StreamDecoderErrorStatus = undefined,
    samples: []i32 = &.{},
    sample_index: usize = 0,
};

fn readCallback(
    _: [*c]const c.FLAC__StreamDecoder,
    buffer: [*c]c.FLAC__byte,
    bytes: [*c]usize,
    user_data: ?*anyopaque,
) callconv(.C) c.FLAC__StreamDecoderReadStatus {
    const data = @as(*DecodeData, @ptrCast(@alignCast(user_data)));

    if (bytes.* > 0) {
        bytes.* = data.stream.read(buffer[0..bytes.*]) catch return c.FLAC__STREAM_DECODER_READ_STATUS_END_OF_STREAM;
        return c.FLAC__STREAM_DECODER_READ_STATUS_CONTINUE;
    }

    return c.FLAC__STREAM_DECODER_READ_STATUS_ABORT;
}

fn seekCallback(
    _: [*c]const c.FLAC__StreamDecoder,
    absolute_byte_offset: u64,
    user_data: ?*anyopaque,
) callconv(.C) c.FLAC__StreamDecoderSeekStatus {
    const data = @as(*DecodeData, @ptrCast(@alignCast(user_data)));
    data.stream.seekTo(absolute_byte_offset) catch return c.FLAC__STREAM_DECODER_SEEK_STATUS_ERROR;
    return c.FLAC__STREAM_DECODER_SEEK_STATUS_OK;
}

fn tellCallback(
    _: [*c]const c.FLAC__StreamDecoder,
    absolute_byte_offset: [*c]u64,
    user_data: ?*anyopaque,
) callconv(.C) c.FLAC__StreamDecoderTellStatus {
    const data = @as(*DecodeData, @ptrCast(@alignCast(user_data)));
    absolute_byte_offset.* = data.stream.getPos() catch return c.FLAC__STREAM_DECODER_TELL_STATUS_ERROR;
    return c.FLAC__STREAM_DECODER_TELL_STATUS_OK;
}

fn lengthCallback(
    _: [*c]const c.FLAC__StreamDecoder,
    stream_length: [*c]u64,
    user_data: ?*anyopaque,
) callconv(.C) c.FLAC__StreamDecoderLengthStatus {
    const data = @as(*DecodeData, @ptrCast(@alignCast(user_data)));
    stream_length.* = data.stream.getEndPos() catch return c.FLAC__STREAM_DECODER_LENGTH_STATUS_ERROR;
    return c.FLAC__STREAM_DECODER_LENGTH_STATUS_OK;
}

fn eofCallback(_: [*c]const c.FLAC__StreamDecoder, user_data: ?*anyopaque) callconv(.C) c_int {
    const data = @as(*DecodeData, @ptrCast(@alignCast(user_data)));
    const pos = data.stream.getPos() catch return 1;
    const end_pos = data.stream.getEndPos() catch return 1;
    return @intFromBool(pos == end_pos);
}

fn writeCallback(
    _: [*c]const c.FLAC__StreamDecoder,
    frame: [*c]const c.FLAC__Frame,
    buffer: [*c]const [*c]const c.FLAC__int32,
    user_data: ?*anyopaque,
) callconv(.C) c.FLAC__StreamDecoderWriteStatus {
    const data = @as(*DecodeData, @ptrCast(@alignCast(user_data)));

    if (data.total_samples == 0) {
        if (frame.*.header.blocksize > data.samples.len - data.sample_index) {
            const size = data.samples.len + data.channels * frame.*.header.blocksize * data.bytes_per_sample;
            data.samples = data.allocator.realloc(data.samples, size) catch {
                return c.FLAC__STREAM_DECODER_WRITE_STATUS_ABORT;
            };
        }
    } else {
        if (data.samples.len == 0) {
            const size = data.total_samples * data.bytes_per_sample;
            data.samples = data.allocator.alloc(i32, size) catch {
                return c.FLAC__STREAM_DECODER_WRITE_STATUS_ABORT;
            };
        }
    }

    const shift_amount: u5 = @intCast(32 - data.bits_per_sample);
    if (frame.*.header.channels == 3) {
        for (0..frame.*.header.blocksize) |i| {
            const center = @divExact(buffer[2][i] << shift_amount, 2);
            const left = (buffer[0][i] << shift_amount) + center;
            const right = (buffer[1][i] << shift_amount) + center;
            data.samples[data.sample_index] = left;
            data.samples[data.sample_index + 1] = right;
            data.sample_index += 2;
        }
    } else {
        for (0..frame.*.header.blocksize) |i| {
            for (0..data.channels) |ch| {
                const sample = buffer[ch][i];
                data.samples[data.sample_index] = sample << shift_amount;
                data.sample_index += 1;
            }
        }
    }

    return c.FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE;
}

fn metadataCallback(
    _: [*c]const c.FLAC__StreamDecoder,
    metadata: [*c]const c.FLAC__StreamMetadata,
    user_data: ?*anyopaque,
) callconv(.C) void {
    const data = @as(*DecodeData, @ptrCast(@alignCast(user_data)));
    data.channels = switch (metadata.*.data.stream_info.channels) {
        3 => 2, // We'll drop the center channel and mix it with Left and Right channels
        else => @intCast(metadata.*.data.stream_info.channels),
    };
    data.sample_rate = @intCast(metadata.*.data.stream_info.sample_rate);
    data.bits_per_sample = @intCast(metadata.*.data.stream_info.bits_per_sample);
    data.bytes_per_sample = data.bits_per_sample / 8;
    data.total_samples = metadata.*.data.stream_info.total_samples;
}

fn errorCallback(
    _: [*c]const c.FLAC__StreamDecoder,
    status: c.FLAC__StreamDecoderErrorStatus,
    user_data: ?*anyopaque,
) callconv(.C) void {
    const data = @as(*DecodeData, @ptrCast(@alignCast(user_data)));
    data.status = status;
}

test {
    const test_file = @embedFile("center.flac");
    const fbs = std.io.fixedBufferStream(test_file);
    var stream = std.io.StreamSource{ .const_buffer = fbs };
    const out = try decodeStream(std.testing.allocator, stream);
    try std.testing.expect(out.samples.len > 0);
    try std.fs.cwd().writeFile("zig-out/raw.pcm", std.mem.sliceAsBytes(out.samples));
    std.testing.allocator.free(out.samples);
}
