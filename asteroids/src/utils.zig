const globals = @import("globals.zig");

const rl = @import("raylib");

pub fn wrapPosition(position: *rl.Vector2) void {
    if (position.x > globals.current_screen_width) {
        position.x = 0;
    } else if (position.x < 0) {
        position.x = globals.current_screen_width;
    }

    if (position.y > globals.current_screen_height) {
        position.y = 0;
    } else if (position.y < 0) {
        position.y = globals.current_screen_height;
    }
}
