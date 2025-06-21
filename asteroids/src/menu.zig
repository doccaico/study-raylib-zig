const std = @import("std");
const Sound = @import("Sound.zig");
const Global = @import("global.zig");
const Game = @import("Game.zig");
const Resolution = @import("Resolution.zig");
const max_resolutions = Resolution.max_resolutions;

const rl = @import("raylib");

// MENU OPTIONS indices for the MAIN MENU
const menu_start = 0;
const menu_options = 1;
const menu_controls = 2;
const menu_exit = 3;
const menu_main_count = 4;

// menu indices for options menu
const menu_sound = 0;
const menu_music = 1;
const menu_fps = 2;
const menu_difficulty = 3;
const menu_resolution = 4;
const menu_fullscreen = 5; // added this new setting for fullscreen game NEW
const menu_back = 6;
const menu_options_count = 7;

pub fn updateMainMenu(g: *Game) bool {
    // Navigation bar
    var menu_changed = false;

    if (rl.isKeyPressed(.down)) {
        g.selected_option = @mod((g.selected_option + 1), menu_main_count);
        menu_changed = true;
    } else if (rl.isKeyPressed(.up)) {
        // FIX: Proper handling of wrap-around when going up in menu
        g.selected_option = @mod((g.selected_option - 1 + menu_main_count), menu_main_count);
        menu_changed = true;
    }

    // Play sound on menu navigation
    if (menu_changed and g.settings.sound_enabled) {
        Sound.playGameSound(g.sound, .menu_select);
    }

    // Selected
    if (rl.isKeyPressed(.enter)) {
        // Play selection sound
        if (g.settings.sound_enabled) {
            Sound.playGameSound(g.sound, .menu_select);
        }

        switch (g.selected_option) {
            menu_start => g.state = .game_play,
            menu_options => {
                g.state = .options_menu;
                g.selected_option = 0; // need to reset the select for this to start from 0
            },
            menu_controls => {
                g.state = .controls_menu;
                g.selected_option = 0; // need to reset the select option
            },
            menu_exit => {
                return false;
            },
            else => {},
        }
    }

    return true;
}

pub fn updateOptionsMenu(g: *Game) void {
    // Navigation
    var menu_changed = false;

    if (rl.isKeyPressed(.down)) {
        g.selected_option = @mod((g.selected_option + 1), menu_options_count);
        menu_changed = true;
    } else if (rl.isKeyPressed(.up)) {
        g.selected_option = @mod((g.selected_option - 1 + menu_options_count), menu_options_count);
        menu_changed = true;
    }

    // Play sound on menu navigation
    if (menu_changed and g.settings.sound_enabled) {
        Sound.playGameSound(g.sound, .menu_select);
    }

    // Change settings with left/right keybinds
    if (rl.isKeyPressed(.right) or rl.isKeyPressed(.left)) {
        // Play selection sound
        if (g.settings.sound_enabled) {
            Sound.playGameSound(g.sound, .menu_select);
        }

        // toggle or cycle values
        switch (g.selected_option) {
            menu_sound => {
                g.settings.sound_enabled = !g.settings.sound_enabled;
                // Update sound manager
                Sound.toggleSoundEnabled(g.sound, g.settings.sound_enabled);
            },
            menu_music => {
                g.settings.music_enabled = !g.settings.music_enabled;
                // Update music manager
                Sound.toggleMusicEnabled(g.sound, g.settings.music_enabled);
            },
            menu_fps => {
                g.settings.show_fps = !g.settings.show_fps;
            },
            menu_resolution => {
                if (rl.isKeyPressed(.right)) {
                    // Cycle to next resolution
                    const new_res = @mod((g.current_resolution + 1), max_resolutions);
                    Resolution.changeResolution(g, @intCast(new_res));
                } else {
                    // Cycle to previous resolution
                    const new_res = @mod((g.current_resolution - 1 + max_resolutions), max_resolutions);
                    Resolution.changeResolution(g, @intCast(new_res));
                }
            },
            menu_fullscreen => {
                Resolution.toggleFullscreenMode(g);
            },
            menu_difficulty => {
                if (rl.isKeyPressed(.right)) {
                    g.settings.difficulty = @mod((g.settings.difficulty + 1), 3);
                } else {
                    g.settings.difficulty = @mod((g.settings.difficulty - 1 + 3), 3);
                }
            },
            else => {},
        }
    }

    if (rl.isKeyPressed(.enter)) {
        // Play selection sound
        if (g.settings.sound_enabled) {
            Sound.playGameSound(g.sound, .menu_select);
        }

        if (g.selected_option == menu_back) {
            g.state = .main_menu;
            g.selected_option = menu_options;
        }
    }

    // Going back using ESC keys
    if (rl.isKeyPressed(.escape)) {
        // Play selection sound
        if (g.settings.sound_enabled) {
            Sound.playGameSound(g.sound, .menu_select);
        }

        g.state = .main_menu;
        g.selected_option = menu_options;
    }
}

pub fn updateControlsMenu(g: *Game) void {
    // Only need to handle back action
    if (rl.isKeyPressed(.enter) or rl.isKeyPressed(.escape)) {
        // Play selection sound
        if (g.settings.sound_enabled) {
            Sound.playGameSound(g.sound, .menu_select);
        }

        g.state = .main_menu;
        g.selected_option = menu_controls; // usually is always selected at main menu controls
    }
}

pub fn updatePauseMenu(g: *Game) void {
    // We only need two options
    var menu_changed = false;

    if (rl.isKeyPressed(.down) or rl.isKeyPressed(.up)) {
        // g.selected_option = !g.selected_option;
        g.selected_option = if (g.selected_option == 0) 1 else 0; // toggle between 0 and 1
        menu_changed = true;
    }

    // Play sound on menu navigation
    if (menu_changed and g.settings.sound_enabled) {
        Sound.playGameSound(g.sound, .menu_select);
    }

    if (rl.isKeyPressed(.enter)) {
        // Play selection sound
        if (g.settings.sound_enabled) {
            Sound.playGameSound(g.sound, .menu_select);
        }

        if (g.selected_option == 0) {
            // Resume
            g.state = .game_play;
        } else {
            g.state = .main_menu;
            g.selected_option = 0;
        }
    }

    if (rl.isKeyPressed(.escape) or rl.isKeyPressed(.p)) {
        // Play selection sound
        if (g.settings.sound_enabled) {
            Sound.playGameSound(g.sound, .menu_select);
        }

        g.state = .game_play;
    }
}

fn drawMenuTitle(title: [:0]const u8) void {
    rl.drawText(title, @divTrunc(Global.current_screen_width, 2) - @divTrunc(rl.measureText(title, 40), 2), @divTrunc(Global.current_screen_height, 6), 40, .white);
}

fn drawMenuOption(text: [:0]const u8, y: i32, selected: bool) void {
    // basic option selection, yellow for something being selected and font size 25
    // otherwise using default
    const color: rl.Color = if (selected) .yellow else .white;
    const font_size: i32 = if (selected) 25 else 20;

    if (selected) {
        rl.drawText(">", @divTrunc(Global.current_screen_width, 2) - @divTrunc(rl.measureText(text, font_size), 2) - 30, y, font_size, .yellow);
    }

    rl.drawText(text, @divTrunc(Global.current_screen_width, 2) - @divTrunc(rl.measureText(text, font_size), 2), y, font_size, color);
}

pub fn drawMainMenu(g: *Game) void {
    // Game Logo Adding
    drawMenuTitle("ASTEROIDS");

    // Menu Options
    const start_y = @divTrunc(Global.current_screen_height, 2) - 40;
    const spacing = 50; // for adding space in the menu
    // TODO
    drawMenuOption("START GAME", start_y, g.selected_option == menu_start);
    drawMenuOption("OPTIONS", start_y + spacing, g.selected_option == menu_options);
    drawMenuOption("CONTROLS", start_y + spacing * 2, g.selected_option == menu_controls);
    drawMenuOption("EXIT", start_y + spacing * 3, g.selected_option == menu_exit);

    // Footer - FIXED positioning
    rl.drawText("© 2025 Karlo Siric", @divTrunc(Global.current_screen_width, 2) - @divTrunc(rl.measureText("© 2025 Karlo Siric", 15), 2), Global.current_screen_height - 30, 15, .gray);

    // Showing high score if it exists - FIXED positioning
    if (g.high_score > 0) {
        rl.drawText(rl.textFormat("HIGH SCORE: %d", .{g.high_score}), @divTrunc(Global.current_screen_width, 2) - @divTrunc(rl.measureText(rl.textFormat("HIGH SCORE: %d", .{g.high_score}), 20), 2), Global.current_screen_height - 60, 20, .yellow);
    }
}

pub fn drawOptionsMenu(g: *Game) void {
    drawMenuTitle("OPTIONS");

    const start_y = @divTrunc(Global.current_screen_height, 2) - 60;
    const spacing = 50;

    var sound_text: [20:0]u8 = undefined;
    var music_text: [20:0]u8 = undefined;
    var fps_text: [20:0]u8 = undefined;
    // Increased size to be safe
    var difficulty_text: [30:0]u8 = undefined;
    // added a buffer to hold FULLSCREEN NEW!!
    var fullscreen_text: [30:0]u8 = undefined;
    // Buffer for resolution text
    var resolution_text: [40:0]u8 = undefined;

    {
        const s = if (g.settings.sound_enabled) "ON" else "OFF";
        _ = std.fmt.bufPrintZ(&sound_text, "SOUND: {s}", .{s}) catch @panic("bufPrintZ() failed");
    }
    {
        const s = if (g.settings.music_enabled) "ON" else "OFF";
        _ = std.fmt.bufPrintZ(&music_text, "MUSIC: {s}", .{s}) catch @panic("bufPrintZ() failed");
    }
    {
        const s = if (g.settings.show_fps) "ON" else "OFF";
        _ = std.fmt.bufPrintZ(&fps_text, "SHOW FPS: {s}", .{s}) catch @panic("bufPrintZ() failed");
    }
    {
        const s = if (g.settings.fullscreen) "ON" else "OFF";
        _ = std.fmt.bufPrintZ(&fullscreen_text, "FULLSCREEN: {s}", .{s}) catch @panic("bufPrintZ() failed");
    }
    {
        const s = g.resolutions[@intCast(g.current_resolution)].name;
        _ = std.fmt.bufPrintZ(&resolution_text, "RESOLUTION: {s}", .{s}) catch @panic("bufPrintZ() failed");
    }

    // setting difficulty switch case
    {
        const s = switch (g.settings.difficulty) {
            0 => "EASY",
            1 => "NORMAL",
            2 => "HARD",
            else => unreachable,
        };
        _ = std.fmt.bufPrintZ(&difficulty_text, "DIFFICULTY: {s}", .{s}) catch @panic("bufPrintZ() failed");
    }

    drawMenuOption(&sound_text, start_y, g.selected_option == menu_sound);
    drawMenuOption(&music_text, start_y + spacing, g.selected_option == menu_music);
    drawMenuOption(&fps_text, start_y + spacing * 2, g.selected_option == menu_fps);
    drawMenuOption(&difficulty_text, start_y + spacing * 3, g.selected_option == menu_difficulty);
    drawMenuOption(&resolution_text, start_y + spacing * 4, g.selected_option == menu_resolution);
    drawMenuOption(&fullscreen_text, start_y + spacing * 5, g.selected_option == menu_fullscreen);
    drawMenuOption("BACK", start_y + spacing * 6, g.selected_option == menu_back);

    // Instructions in the menu
    rl.drawText("<- -> to change settings", @divTrunc(Global.current_screen_width, 2) - @divTrunc(rl.measureText("<- -> to change settings", 15), 2), Global.current_screen_height - 30, 15, .gray);
}

pub fn drawControlsMenu() void {
    drawMenuTitle("CONTROLS");

    // Start higher to fit more controls
    const start_y = @divTrunc(Global.current_screen_height, 2) - 150;
    // Reduced spacing to fit more items
    const spacing = 30;

    var current_y = start_y;

    // Keyboard controls section
    rl.drawText("KEYBOARD CONTROLS:", @divTrunc(Global.current_screen_width, 2) - @divTrunc(rl.measureText("KEYBOARD CONTROLS:", 22), 2), current_y, 22, .yellow);
    current_y += spacing + 10;

    rl.drawText("UP / W - Thrust", @divTrunc(Global.current_screen_width, 2) - @divTrunc(rl.measureText("UP / W - Thrust", 20), 2), current_y, 20, .white);
    current_y += spacing;

    rl.drawText("LEFT / A - Rotate Left", @divTrunc(Global.current_screen_width, 2) - @divTrunc(rl.measureText("LEFT / A - Rotate Left", 20), 2), current_y, 20, .white);
    current_y += spacing;

    rl.drawText("RIGHT / D - Rotate Right", @divTrunc(Global.current_screen_width, 2) - @divTrunc(rl.measureText("RIGHT / D - Rotate Right", 20), 2), current_y, 20, .white);
    current_y += spacing;

    rl.drawText("SPACE - Fire", @divTrunc(Global.current_screen_width, 2) - @divTrunc(rl.measureText("SPACE - Fire", 20), 2), current_y, 20, .white);
    current_y += spacing + 20;

    // Mouse controls section
    rl.drawText("MOUSE CONTROLS:", @divTrunc(Global.current_screen_width, 2) - @divTrunc(rl.measureText("MOUSE CONTROLS:", 22), 2), current_y, 22, .yellow);
    current_y += spacing + 10;

    rl.drawText("MOUSE POSITION - Aim Ship", @divTrunc(Global.current_screen_width, 2) - @divTrunc(rl.measureText("MOUSE POSITION - Aim Ship", 20), 2), current_y, 20, .white);
    current_y += spacing;

    rl.drawText("LEFT CLICK - Fire", @divTrunc(Global.current_screen_width, 2) - @divTrunc(rl.measureText("LEFT CLICK - Fire", 20), 2), current_y, 20, .white);
    current_y += spacing;

    rl.drawText("RIGHT CLICK - Thrust", @divTrunc(Global.current_screen_width, 2) - @divTrunc(rl.measureText("RIGHT CLICK - Thrust", 20), 2), current_y, 20, .white);
    current_y += spacing;

    rl.drawText("M - Switch Control Mode", @divTrunc(Global.current_screen_width, 2) - @divTrunc(rl.measureText("M - Switch Control Mode", 20), 2), current_y, 20, .white);
    current_y += spacing + 20;

    // General controls
    rl.drawText("P - Pause Game", @divTrunc(Global.current_screen_width, 2) - @divTrunc(rl.measureText("P - Pause Game", 20), 2), current_y, 20, .white);
    current_y += spacing;

    rl.drawText("ESC - Return to Menu", @divTrunc(Global.current_screen_width, 2) - @divTrunc(rl.measureText("ESC - Return to Menu", 20), 2), current_y, 20, .white);
    current_y += spacing + 10;

    // back button
    drawMenuOption("BACK", current_y, true);

    // Instructions for the menu
    rl.drawText("Press ENTER or ESC to return", @divTrunc(Global.current_screen_width, 2) - @divTrunc(rl.measureText("Press ENTER or ESC to return", 15), 2), Global.current_screen_height - 30, 15, .gray);
}
