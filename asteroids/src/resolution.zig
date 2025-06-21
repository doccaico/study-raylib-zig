const Game = @import("Game.zig");
const Global = @import("global.zig");
const Star = @import("Star.zig");

const rl = @import("raylib");

pub const max_resolutions = 4; // Number of supported resolutions NEW

width: i32,
height: i32,
name: [:0]const u8,

pub const Self = @This();

pub fn init(game: *Game) void {
    game.resolutions[0] = Self{ .width = 800, .height = 600, .name = "800x600" };
    game.resolutions[1] = Self{ .width = 1024, .height = 768, .name = "1024x768" };
    game.resolutions[2] = Self{ .width = 1280, .height = 720, .name = "1280x720 (HD)" };
    game.resolutions[3] = Self{ .width = 1920, .height = 1080, .name = "1920x1080 (FHD)" };

    game.current_resolution = 2; // Default to 1280x720

    // Store the default screen dimensions
    game.default_screen_width = rl.getScreenWidth();
    game.default_screen_height = rl.getScreenHeight();
}

pub fn toggleFullscreenMode(game: *Game) void {
    const monitor = rl.getCurrentMonitor();

    if (!rl.isWindowFullscreen()) {
        // Save current window dimensions before going fullscreen
        game.default_screen_width = Global.current_screen_width;
        game.default_screen_height = Global.current_screen_height;

        // Get monitor dimensions for proper fullscreen
        const monitor_width = rl.getMonitorWidth(monitor);
        const monitor_height = rl.getMonitorHeight(monitor);

        // Set to the monitor's resolution before toggling fullscreen
        // This is critical to ensure the game fills the entire screen
        rl.setWindowSize(monitor_width, monitor_height);

        // Toggle fullscreen
        rl.toggleFullscreen();

        // Update screen dimensions to monitor size
        Global.current_screen_width = monitor_width;
        Global.current_screen_height = monitor_height;

        // Update fullscreen flag
        game.settings.fullscreen = true;
    } else {
        // Exit fullscreen first
        rl.toggleFullscreen();

        // Get the current resolution from the selected resolution index
        const cur_res = game.resolutions[@intCast(game.current_resolution)];

        // Restore window size to the selected resolution
        rl.setWindowSize(cur_res.width, cur_res.height);

        // Update screen dimensions
        Global.current_screen_width = cur_res.width;
        Global.current_screen_height = cur_res.height;

        // Center window
        const display_width = rl.getMonitorWidth(monitor);
        const display_height = rl.getMonitorHeight(monitor);
        rl.setWindowPosition(@divTrunc((display_width - cur_res.width), 2), @divTrunc((display_height - cur_res.height), 2));

        // Update fullscreen flag
        game.settings.fullscreen = false;
    }

    // Apply necessary adjustments for the new screen size
    handleSelfChange(game);
}

fn handleSelfChange(game: *Game) void {
    // Adjust game elements based on new resolution if needed

    // Reinitialize stars to fill the new screen dimensions
    Star.init(&game.stars);

    // Reset player to center of new screen
    game.player.position.x = @floatFromInt(@divTrunc(Global.current_screen_width, 2));
    game.player.position.y = @floatFromInt(@divTrunc(Global.current_screen_height, 2));
}

pub fn changeResolution(game: *Game, new_resolution_index: usize) void {
    if (new_resolution_index < 0 or new_resolution_index >= max_resolutions) {
        return; // Invalid resolution index
    }

    // If we're currently in fullscreen, exit fullscreen first
    if (rl.isWindowFullscreen()) {
        rl.toggleFullscreen();
        game.settings.fullscreen = false;
    }

    // Update resolution details
    const new_res = game.resolutions[new_resolution_index];

    // Change window size
    rl.setWindowSize(new_res.width, new_res.height);

    // Center the window on the monitor
    const display_width = rl.getMonitorWidth(rl.getCurrentMonitor());
    const display_height = rl.getMonitorHeight(rl.getCurrentMonitor());
    rl.setWindowPosition(@divTrunc((display_width - new_res.width), 2), @divTrunc((display_height - new_res.height), 2));

    // Update screen dimension globals
    Global.current_screen_width = new_res.width;
    Global.current_screen_height = new_res.height;

    // Update current resolution index
    game.current_resolution = @intCast(new_resolution_index);

    // If the game was in fullscreen, toggle it back
    if (game.settings.fullscreen) {
        toggleFullscreenMode(game);
    }

    // Handle any additional adjustments needed
    handleSelfChange(game);
}
