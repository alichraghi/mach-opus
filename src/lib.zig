const std = @import("std");
const c = @cImport(@cInclude("FLAC/stream_decoder.h"));

const Flac = @This();

num_channels: u8,

pub const DecodeError = error{
    OutOfMemory,
};

pub fn decodeStream(reader: anytype) Flac {
    const Dec = Decoder(@TypeOf(reader));
    var decoder = c.FLAC__stream_decoder_new() orelse return error.OutOfMemory;
    c.FLAC__stream_decoder_init_stream(decoder, Dec.readCallback, null, null, null, null, Dec.writeCallback, reader);
}

fn Decoder(comptime Reader: type) type {
    return struct {
        fn readCallback(_: [*c]const c.FLAC__StreamDecoder, buffer: [*c]c.FLAC__byte, bytes: [*c]usize, user_data: ?*anyopaque) callconv(.C) c.FLAC__StreamDecoderReadStatus {
            const flac = @ptrCast(*Reader, user_data);

            if (bytes != null) {
                bytes.* = flac.reader.read(buffer[0..bytes.*]) catch return c.FLAC__STREAM_DECODER_READ_STATUS_END_OF_STREAM;

                if (bytes.* == 0) {
                    return c.FLAC__STREAM_DECODER_READ_STATUS_END_OF_STREAM;
                }

                return c.FLAC__STREAM_DECODER_READ_STATUS_CONTINUE;
            }

            return c.FLAC__STREAM_DECODER_READ_STATUS_ABORT;
        }

        fn writeCallbackfn(_: [*c]const c.FLAC__StreamDecoder, frame: [*c]const c.FLAC__Frame, buffer: [*c]const [*c]const c.FLAC__int32, user_data: ?*anyopaque) callconv(.C) c.FLAC__StreamDecoderWriteStatus {
            _ = frame;
            _ = buffer;
            _ = user_data;
            return c.FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE;

            //             Sint16 *data;
            // unsigned int i, j, channels;
            // int shift_amount = 0;

            // if (!music->stream) {
            //     return FLAC__STREAM_DECODER_WRITE_STATUS_ABORT;
            // }

            // switch (music->bits_per_sample) {
            // case 16:
            //     shift_amount = 0;
            //     break;
            // case 20:
            //     shift_amount = 4;
            //     break;
            // case 24:
            //     shift_amount = 8;
            //     break;
            // default:
            //     SDL_SetError("FLAC decoder doesn't support %d bits_per_sample", music->bits_per_sample);
            //     return FLAC__STREAM_DECODER_WRITE_STATUS_ABORT;
            // }

            // if (music->channels == 3) {
            //     /* We'll just drop the center channel for now */
            //     channels = 2;
            // } else {
            //     channels = music->channels;
            // }

            // data = SDL_stack_alloc(Sint16, (frame->header.blocksize * channels));
            // if (!data) {
            //     SDL_SetError("Couldn't allocate %d bytes stack memory", (int)(frame->header.blocksize * channels * sizeof(*data)));
            //     return FLAC__STREAM_DECODER_WRITE_STATUS_ABORT;
            // }
            // if (music->channels == 3) {
            //     Sint16 *dst = data;
            //     for (i = 0; i < frame->header.blocksize; ++i) {
            //         Sint16 FL = (buffer[0][i] >> shift_amount);
            //         Sint16 FR = (buffer[1][i] >> shift_amount);
            //         Sint16 FCmix = (Sint16)((buffer[2][i] >> shift_amount) * 0.5f);
            //         int sample;

            //         sample = (FL + FCmix);
            //         if (sample > SDL_MAX_SINT16) {
            //             *dst = SDL_MAX_SINT16;
            //         } else if (sample < SDL_MIN_SINT16) {
            //             *dst = SDL_MIN_SINT16;
            //         } else {
            //             *dst = sample;
            //         }
            //         ++dst;

            //         sample = (FR + FCmix);
            //         if (sample > SDL_MAX_SINT16) {
            //             *dst = SDL_MAX_SINT16;
            //         } else if (sample < SDL_MIN_SINT16) {
            //             *dst = SDL_MIN_SINT16;
            //         } else {
            //             *dst = sample;
            //         }
            //         ++dst;
            //     }
            // } else {
            //     for (i = 0; i < channels; ++i) {
            //         Sint16 *dst = data + i;
            //         for (j = 0; j < frame->header.blocksize; ++j) {
            //             *dst = (buffer[i][j] >> shift_amount);
            //             dst += channels;
            //         }
            //     }
            // }
            // SDL_AudioStreamPut(music->stream, data, (frame->header.blocksize * channels * sizeof(*data)));
            // SDL_stack_free(data);

            // return FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE;
            //     }
        }

        fn metadataCallbackfn(_: [*c]const c.FLAC__StreamDecoder, metadata: [*c]const c.FLAC__StreamMetadata, user_data: ?*anyopaque) callconv(.C) void {
            _ = metadata;
            _ = user_data;
        }
    };
}

test {
    const test_file = @embedFile("");
    var fbs = std.io.fixedBufferStream(test_file);
    decodeStream(fbs.reader());
}
