const playdate = @import("../main.zig");
const c = playdate.c;
const std = @import("std");

// SamplePlayer
// https://sdk.play.date/1.12.3/Inside%20Playdate%20with%20C.html#C-sound.sampleplayer
pub const SamplePlayer = anyopaque;

pub fn isPlaying(player: *SamplePlayer) bool {
    const val = playdate.api.sound.*.sampleplayer.*.isPlaying.?(@ptrCast(*c.SamplePlayer, player));
    return if (val != 0) true else false;
}
pub fn newSamplePlayer() *SamplePlayer {
    const ptr = playdate.api.sound.*.sampleplayer.*.newPlayer.?();
    return @ptrCast(*SamplePlayer, ptr);
}
pub fn setSample(player: *SamplePlayer, sample: *playdate.sound.audio_sample.AudioSample) void {
    playdate.api.sound.*.sampleplayer.*.setSample.?(@ptrCast(*c.SamplePlayer, player), @ptrCast(*c.AudioSample, sample));
}
pub fn play(player: *SamplePlayer, repeat: i32, rate: f32) void {
    _ = playdate.api.sound.*.sampleplayer.*.play.?(@ptrCast(*c.SamplePlayer, player), repeat, rate);
}
pub fn freePlayer(player: *SamplePlayer) void {
    playdate.api.sound.*.sampleplayer.*.freePlayer.?(@ptrCast(*c.SamplePlayer, player));
}
pub fn setVolume(player: *SamplePlayer, left: f32, right: f32) void {
    playdate.api.sound.*.sampleplayer.*.setVolume.?(@ptrCast(*c.SamplePlayer, player), left, right);
}
pub fn getVolume(player: *SamplePlayer) struct { left: f32, right: f32 } {
    var left: f32 = undefined;
    var right: f32 = undefined;
    playdate.api.sound.*.sampleplayer.*.getVolume.?(@ptrCast(*c.SamplePlayer, player), &left, &right);

    return .{
        .left = left,
        .right = right,
    };
}
