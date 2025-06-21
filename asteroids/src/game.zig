const Config = @import("config.zig");
const Util = @import("util.zig");
const Global = @import("global.zig");
const Menu = @import("menu.zig");
const Player = @import("player.zig");
const Sound = @import("sound.zig");
const Asteroid = @import("asteroid.zig");
const max_asteroids = Asteroid.max_asteroids;
const Bullet = @import("bullet.zig");
const max_bullets = Bullet.max_bullets;
const Star = @import("star.zig");
const max_stars = Star.max_stars;
const Resolution = @import("resolution.zig");
const max_resolutions = Resolution.max_resolutions;

const rl = @import("raylib");

// Game states
pub const State = enum {
    main_menu,
    game_play,
    game_over,
    options_menu, // new INCLUDED, WASNT PRESENT IN V1.0
    controls_menu, // new INCLUDED, WASNT PRESENT IN V1.0
    paused, // new INCLUDED, WASNT PRESENT IN V1.0
};

// Adding game settings structure architecture, NEW, not present within the v1.0
const Settings = struct {
    sound_enabled: bool,
    music_enabled: bool,
    show_fps: bool,
    difficulty: i32, // 0 - easy, 1 - normal, 2 - Hard
    fullscreen: bool, // Added the fullscreen flag NEW!
};

// Game Architecture
state: State,
score: i32,
player: Player, // still missing needs to be implemented in player.h first
asteroids: [max_asteroids]Asteroid,
bullets: [max_bullets]Bullet,
stars: [max_stars]Star, // added the array of Star structures that we need
selected_option: i32, // used for tracking which menu option has been selected
settings: Settings, // structure containg game settings to the game
high_score: i32, // added additionally as well not present in v1.0
current_resolution: i32,
resolutions: [max_resolutions]Resolution,
default_screen_width: i32,
default_screen_height: i32,
sound_manager: *Sound.Manager, // Added sound manager pointer

pub const Game = @This();

pub fn init(g: *Game, sound_manager: *Sound.Manager) void {
    // init global variables
    Global.current_screen_width = Config.screen_width;
    Global.current_screen_height = Config.screen_height;

    // dereferencing the pointer and using -> syntax in this case
    g.state = .main_menu; // we initially set this to the MENU part of the game
    g.score = 0; // we then set the score to be equal to 0 for its own sake of the game
    g.high_score = 0;
    g.selected_option = 0; // added new into this version, did not have it in v1.0
    g.settings.fullscreen = false; // we initialize it to start with false at the start of the game

    // Initializing settings
    g.settings.sound_enabled = true;
    g.settings.music_enabled = true;
    g.settings.show_fps = false;
    g.settings.difficulty = 1;

    Player.init(&g.player); // initialize the player

    Asteroid.init(&g.asteroids); // initialize the asteroids

    Bullet.init(&g.bullets); // initialize the bullets

    Star.init(&g.stars); // Initialize the stars, added new not present in v1.0

    Resolution.init(g); // Initialize resolutions AFTER other components

    g.sound_manager = sound_manager; // Link the sound manager to the game

    // Initialize the sound manager (if it exists)
    Sound.Manager.toggleSoundEnabled(g.sound_manager, g.settings.sound_enabled);
    Sound.Manager.toggleMusicEnabled(g.sound_manager, g.settings.music_enabled);

    for (0..5) |_| {
        Asteroid.spawn(&g.asteroids);
    }
}

pub fn update(g: *Game) bool {
    // Update music
    Sound.updateGameMusic(g.sound_manager, g);

    // Check first if we should exit the application
    if (rl.windowShouldClose()) {
        // This is the exit process triggered by the window X button
        // You may want to add confirmation here
        return false;
    }

    // Handle pausing during game_play - ONLY pause, don't exit
    if (g.state == .game_play and rl.isKeyPressed(.p)) {
        g.state = .paused;
        g.selected_option = 0; // Default to Resume

        // Pause music when game is paused
        Sound.pauseGameMusic(g.sound_manager);

        return true;
    }

    // Handle ESC during game_play to return to main menu
    if (g.state == .game_play and rl.isKeyPressed(.escape)) {
        g.state = .main_menu;
        g.selected_option = 0; // Default to first option

        // Play menu select sound
        if (g.settings.sound_enabled) {
            Sound.playGameSound(g.sound_manager, .menu_select);
        }

        return true;
    }

    // Handle different game states
    switch (g.state) {
        .main_menu => {
            if (!Menu.updateMainMenu(g)) {
                return false;
            }
            Star.update(&g.stars);
        },

        .options_menu => {
            Menu.updateOptionsMenu(g);
            Star.update(&g.stars);
        },

        .controls_menu => {
            Menu.updateControlsMenu(g);
            Star.update(&g.stars);
        },
        .paused => {
            Menu.updatePauseMenu(g);
        },
        .game_play => {
            // Add braces to create a new scope for local variables
            // Store previous thrusting state to detect changes
            const was_thrusting_before = g.player.is_thrusting;
            const previous_shoot_cooldown = g.player.shoot_cooldown;

            Player.update(&g.player, &g.bullets);

            // Play thrust sound if player just started thrusting
            if (!was_thrusting_before and g.player.is_thrusting) {
                if (g.settings.sound_enabled) {
                    Sound.playGameSound(g.sound_manager, .thrust);
                }
            }

            // Play shooting sound
            if (previous_shoot_cooldown == 0 and g.player.shoot_cooldown > 0) {
                if (g.settings.sound_enabled) {
                    Sound.playGameSound(g.sound_manager, .shoot);
                }
            }

            // TODO 後でやる
            // UpdateAsteroid(g.asteroids);
            // UpdateBullets(g.bullets);
            // UpdateStars(g.stars);
            //

            // We check the collisions - added sound support for collisions
            const previous_state = g.state;
            const previous_score = g.score;

            Util.checkCollisions(&g.player, &g.asteroids, &g.bullets, &g.score, &g.state);

            // If score changed, an asteroid was hit
            if (g.score > previous_score) {
                if (g.settings.sound_enabled) {
                    // Choose between small and large explosion sound randomly
                    if (rl.getRandomValue(0, 1) == 0) {
                        Sound.playGameSound(g.sound_manager, .explosion_small);
                    } else {
                        Sound.playGameSound(g.sound_manager, .explosion_big);
                    }
                }
            }

            // If state changed to GAME_OVER, player collided with asteroid
            if (previous_state != .game_over and g.state == .game_over) {
                if (g.settings.sound_enabled) {
                    Sound.playGameSound(g.sound_manager, .explosion_big);
                    Sound.playGameSound(g.sound_manager, .game_over);
                }
            }
        },

        .game_over => {
            // Check for the high score
            if (g.score > g.high_score) {
                g.high_score = g.score;
            }

            // Now here we handle the restart or return to menu
            if (rl.isKeyPressed(.enter)) {
                resetGame(g);
                g.state = .game_play;

                // Play select sound
                if (g.settings.sound_enabled) {
                    Sound.playGameSound(g.sound_manager, .menu_select);
                }
            } else if (rl.isKeyPressed(.escape)) {
                resetGame(g);
                g.state = .main_menu;
                g.selected_option = 0;

                // Play select sound
                if (g.settings.sound_enabled) {
                    Sound.playGameSound(g.sound_manager, .menu_select);
                }
            }
            // Keep updating stars for visual effect
            Star.update(&g.stars);
        },
    }

    return true;
}

// Implementing the reset game feature
fn resetGame(g: *Game) void {
    // We reset the player
    Player.init(&g.player);

    Asteroid.init(&g.asteroids);
    Bullet.init(&g.bullets);

    // now we spawn those initial asteroids once again
    for (0..5) |_| {
        Asteroid.spawn(&g.asteroids);
    }
    // reset the score finally
    g.score = 0;
}

pub fn draw(g: *Game) void {
    // Always draw stars first for all states
    Star.draw(g.stars);

    // TODO
    switch (g.state) {
        .main_menu => Menu.drawMainMenu(g),
        .options_menu => Menu.drawOptionsMenu(g),
        .controls_menu => Menu.drawControlsMenu(),
        else => {},
        // case GAMEPLAY:
        //     // Original gameplay drawing code
        //     DrawAsteroids(game->asteroids);
        //     DrawBullets(game->bullets);
        //     DrawPlayer(game->player);
        //
        //     // For drawing the score on the screen
        //     DrawText(TextFormat("SCORE: %d", game->score), 10, 10, 20, WHITE);
        //     break;
        //
        // case PAUSED:
        //     // We need to make sure we Draw the game in the background
        //     DrawAsteroids(game->asteroids);
        //     DrawBullets(game->bullets);
        //     DrawPlayer(game->player);
        //
        //     // Then draw the pause menu overlay
        //     DrawPauseMenu(game);
        //     break;
        //
        // case GAME_OVER:
        //     // Draw game over text
        //     DrawTextCenteredX("GAME OVER", screenHeight / 2 - 40, 40, WHITE);
        //     DrawTextCenteredX(TextFormat("FINAL SCORE: %d", game->score), screenHeight / 2, 20, WHITE);
        //     DrawTextCenteredX("Press ENTER to play again", screenHeight / 2 + 40, 20, WHITE);
        //     DrawTextCenteredX("Press ESC to return to menu", screenHeight / 2 + 70, 20, WHITE);
        //     break;
    }
    //
    // // FIXED: Adding fps options enabled - properly use DrawFPS
    // if (game->settings.showFPS)
    // {
    //     DrawFPS(10, screenHeight - 30);
    // }
}
