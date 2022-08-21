const playdate = @import("../main.zig");
const c = playdate.c;
const std = @import("std");

// AudioSample
// https://sdk.play.date/1.12.3/Inside%20Playdate%20with%20C.html#C-sound.sample
pub const AudioSample = anyopaque;

pub fn loadFile(path: []const u8) *AudioSample {
    const cstr_path = std.cstr.addNullByte(playdate.allocator, path) catch unreachable;
    defer playdate.allocator.free(cstr_path);

    const ptr = playdate.api.sound.*.sample.*.load.?(@ptrCast([*c]const u8, cstr_path));
    return @ptrCast(*AudioSample, ptr);
}
pub fn freeSample(sample: *AudioSample) void {
    playdate.api.sound.*.sample.*.freeSample.?(@ptrCast(*c.AudioSample, sample));
}
