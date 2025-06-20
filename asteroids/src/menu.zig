const Sound = @import("sound.zig");
const Resolution = @import("resolution.zig").Resolution;
const max_resolutions = @import("resolution.zig").max_resolutions;

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

pub fn updateMainMenu(g: *Game) void {
    // Navigation bar
    const menu_changed = false;

    if (rl.isKeyPressed(.down)) {
        g.selected_option = (g.selected_option + 1) % menu_main_count;
        menu_changed = true;
    } else if (rl.isKeyPressed(.up)) {
        // FIX: Proper handling of wrap-around when going up in menu
        g.selected_option = (g.selected_option - 1 + menu_main_count) % menu_main_count;
        menu_changed = true;
    }

    // Play sound on menu navigation
    if (menu_changed and g.settings.sound_enabled) {
        rl.playGameSound(g.sound_manager, .menu_select);
    }

    // Selected
    if (rl.isKeyPressed(.enter)) {
        // Play selection sound
        if (g.settings.sound_enabled) {
            rl.playGameSound(g.sound_manager, .menu_select);
        }

        switch (g.selectedOption) {
            menu_start => g.state = .gameplay,
            menu_options => {
                g.state = .options_menu;
                g.selected_option = 0; // need to reset the select for this to start from 0
            },
            menu_controls => {
                g.state = .controls_menu;
                g.selected_option = 0; // need to reset the select option
            },
            menu_exit => {
                // The proper Cleanup happens in the mai part of the main loop WindowShouldClose()
                rl.closeWindow();
            },
        }
    }
}

pub fn updateOptionsMenu(g:*Game) void
{
    // Navigation
    bool menu_changed = false;
    
    if (rl.isKeyPressed(.down))
    {
        g.selected_option = (g.selected_option + 1) % menu_options_count;
        menu_changed = true;
    }
    else if (rl.isKeyPressed(.up))
    {
        g.selected_option = (g.selected_option - 1 + menu_options_count) % menu_options_count;
        menu_changed = true;
    }

    // Play sound on menu navigation
    if (menu_changed and g.settings.sound_enabled) {
        rl.playGameSound(g.sound_manager, .menu_select);
    }

    // Change settings with left/right keybinds
    if (rl.isKeyPressed(.right) or rl.isKeyPressed(.left))
    {
        // Play selection sound
        if (g.settings.sound_enabled) {
            rl.playGameSound(g.sound_manager, .menu_select);
        }
        
        // toggle or cycle values
        switch(g.selected_option)
        {
            menu_sound => {
                g.settings.sound_enabled = !g.settings.sound_enabled;
                // Update sound manager
                Sound.toggleSoundEnabled(g.sound_manager, g.settings.sound_enabled);
            },
            menu_music => {
                g.settings.music_enabled = !g.settings.music_enabled;
                // Update music manager
                Sound.toggleMusicEnabled(g.sound_manager, g.settings.music_enabled);
            },
            menu_fps => {
                g.settings.show_fps = !g.settings.show_fps;
            },
            menu_resolution => {
                if (rl.isKeyPressed(.right))
                {
                    // Cycle to next resolution
                    const new_res = (g.current_resolution + 1) % max_resolutions;
                    Resolution.changeResolution(g, new_res);
                }
                else
                {
                    // Cycle to previous resolution
                    const new_res = (g.current_resolution - 1 + max_resolutions) % max_resolutions;
                    Resolution.changeResolution(g, new_res);
                }
            },
            menu_fullscreen => {
                Resolution.toggleFullscreenMode(g);
            },
            menu_difficulty => {
                if (rl.isKeyPressed(.right))
                {
                    g.settings.difficulty = (g.settings.difficulty + 1) % 3;
                }
                else {
                    g.settings.difficulty = (g.settings.difficulty - 1 + 3) % 3;
                }
            },
        }
    }

    if (rl.isKeyPressed(.enter))
    {
        // Play selection sound
        if (g.settings.sound_enabled) {
            // TODO
            rl.playGameSound(g.soundManager, SOUND_MENU_SELECT);
        }
        
        if (g.selected_option == MENU_BACK)
        {
            g.state = MAIN_MENU;
            g.selected_option = MENU_OPTIONS;
        }
    }

    // Going back using ESC keys
    if (IsKeyPressed(KEY_ESCAPE))
    {
        // Play selection sound
        if (g.soundManager != NULL && g.settings.soundEnabled) {
            PlayGameSound(g.soundManager, SOUND_MENU_SELECT);
        }
        
        g.state = MAIN_MENU;
        g.selected_option = MENU_OPTIONS;
    }
}
