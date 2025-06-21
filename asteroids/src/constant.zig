const builtin = @import("builtin");

pub const window_title = if (builtin.mode == .Debug) "asteroids (debug)" else "asteroids";

pub const screen_width = 1280;
pub const screen_height = 920;

pub const fps = 60;
