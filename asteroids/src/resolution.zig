const Game = @import("game.zig");
const Global = @import("global.zig");
const Star = @import("star.zig");

const rl = @import("raylib");

pub const max_resolutions = 4; // Number of supported resolutions NEW

width: i32,
height: i32,
name: [:0]const u8,

pub const Resolution = @This();

pub fn init(g: *Game) void {
    g.resolutions[0] = Resolution{ .width = 800, .height = 600, .name = "800x600" };
    g.resolutions[1] = Resolution{ .width = 1024, .height = 768, .name = "1024x768" };
    g.resolutions[2] = Resolution{ .width = 1280, .height = 720, .name = "1280x720 (HD)" };
    g.resolutions[3] = Resolution{ .width = 1920, .height = 1080, .name = "1920x1080 (FHD)" };

    g.current_resolution = 2; // Default to 1280x720

    // Store the default screen dimensions
    g.default_screen_width = rl.getScreenWidth();
    g.default_screen_height = rl.getScreenHeight();
}

pub fn toggleFullscreenMode(g: *Game) void {
    const monitor = rl.getCurrentMonitor();

    if (!rl.isWindowFullscreen()) {
        // Save current window dimensions before going fullscreen
        g.default_screen_width = Global.current_screen_width;
        g.default_screen_height = Global.current_screen_height;

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
        g.settings.fullscreen = true;
    } else {
        // Exit fullscreen first
        rl.toggleFullscreen();

        // Get the current resolution from the selected resolution index
        const cur_res = g.resolutions[@intCast(g.current_resolution)];

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
        g.settings.fullscreen = false;
    }

    // Apply necessary adjustments for the new screen size
    handleResolutionChange(g);
}

fn handleResolutionChange(g: *Game) void {
    // Adjust game elements based on new resolution if needed

    // Reinitialize stars to fill the new screen dimensions
    Star.init(&g.stars);

    // Reset player to center of new screen
    g.player.position.x = @floatFromInt(@divTrunc(Global.current_screen_width, 2));
    g.player.position.y = @floatFromInt(@divTrunc(Global.current_screen_height, 2));
}

pub fn changeResolution(g: *Game, new_resolution_index: usize) void {
    if (new_resolution_index < 0 or new_resolution_index >= max_resolutions) {
        return; // Invalid resolution index
    }

    // If we're currently in fullscreen, exit fullscreen first
    if (rl.isWindowFullscreen()) {
        rl.toggleFullscreen();
        g.settings.fullscreen = false;
    }

    // Update resolution details
    const new_res = g.resolutions[new_resolution_index];

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
    g.current_resolution = @intCast(new_resolution_index);

    // If the game was in fullscreen, toggle it back
    if (g.settings.fullscreen) {
        toggleFullscreenMode(g);
    }

    // Handle any additional adjustments needed
    handleResolutionChange(g);
}
