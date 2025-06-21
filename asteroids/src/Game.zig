const constant = @import("constant.zig");
const global = @import("global.zig");
const menu = @import("menu.zig");
const util = @import("util.zig");
const Player = @import("Player.zig");
const Sound = @import("Sound.zig");
const Asteroid = @import("Asteroid.zig");
const max_asteroids = Asteroid.max_asteroids;
const Bullet = @import("Bullet.zig");
const max_bullets = Bullet.max_bullets;
const Star = @import("Star.zig");
const max_stars = Star.max_stars;
const Resolution = @import("Resolution.zig");
const max_resolutions = Resolution.max_resolutions;

const rl = @import("raylib");

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
sound: *Sound, // Added sound pointer

const Self = @This();

pub fn init(self: *Self, sound: *Sound) void {
    // init global variables
    global.current_screen_width = constant.screen_width;
    global.current_screen_height = constant.screen_height;

    // dereferencing the pointer and using -> syntax in this case
    self.state = .main_menu; // we initially set this to the MENU part of the game
    self.score = 0; // we then set the score to be equal to 0 for its own sake of the game
    self.high_score = 0;
    self.selected_option = 0; // added new into this version, did not have it in v1.0
    self.settings.fullscreen = false; // we initialize it to start with false at the start of the game

    // Initializing settings
    self.settings.sound_enabled = true;
    self.settings.music_enabled = true;
    self.settings.show_fps = false;
    self.settings.difficulty = 1;

    Player.init(&self.player); // initialize the player

    Asteroid.init(&self.asteroids); // initialize the asteroids

    Bullet.init(&self.bullets); // initialize the bullets

    Star.init(&self.stars); // Initialize the stars, added new not present in v1.0

    Resolution.init(self); // Initialize resolutions AFTER other components

    self.sound = sound; // Link the sound manager to the game

    // Initialize the sound manager (if it exists)
    Sound.toggleSoundEnabled(self.sound, self.settings.sound_enabled);
    Sound.toggleMusicEnabled(self.sound, self.settings.music_enabled);

    for (0..5) |_| {
        Asteroid.spawn(&self.asteroids);
    }
}

pub fn update(self: *Self) bool {
    // Update music
    Sound.updateGameMusic(self.sound, self);

    // Check first if we should exit the application
    if (rl.windowShouldClose()) {
        // This is the exit process triggered by the window X button
        // You may want to add confirmation here
        return false;
    }

    // Handle pausing during game_play - ONLY pause, don't exit
    if (self.state == .game_play and rl.isKeyPressed(.p)) {
        self.state = .paused;
        self.selected_option = 0; // Default to Resume

        // Pause music when game is paused
        Sound.pauseGameMusic(self.sound);

        return true;
    }

    // Handle ESC during game_play to return to main menu
    if (self.state == .game_play and rl.isKeyPressed(.escape)) {
        self.state = .main_menu;
        self.selected_option = 0; // Default to first option

        // Play menu select sound
        if (self.settings.sound_enabled) {
            Sound.playGameSound(self.sound, .menu_select);
        }

        return true;
    }

    // Handle different game states
    switch (self.state) {
        .main_menu => {
            if (!menu.updateMainMenu(self)) {
                return false;
            }
            Star.update(&self.stars);
        },

        .options_menu => {
            menu.updateOptionsMenu(self);
            Star.update(&self.stars);
        },

        .controls_menu => {
            menu.updateControlsMenu(self);
            Star.update(&self.stars);
        },
        .paused => {
            menu.updatePauseMenu(self);
        },
        .game_play => {
            // Add braces to create a new scope for local variables
            // Store previous thrusting state to detect changes
            const was_thrusting_before = self.player.is_thrusting;
            const previous_shoot_cooldown = self.player.shoot_cooldown;

            Player.update(&self.player, &self.bullets);

            // Play thrust sound if player just started thrusting
            if (!was_thrusting_before and self.player.is_thrusting) {
                if (self.settings.sound_enabled) {
                    Sound.playGameSound(self.sound, .thrust);
                }
            }

            // Play shooting sound
            if (previous_shoot_cooldown == 0 and self.player.shoot_cooldown > 0) {
                if (self.settings.sound_enabled) {
                    Sound.playGameSound(self.sound, .shoot);
                }
            }

            // TODO 後でやる
            // UpdateAsteroid(self.asteroids);
            // UpdateBullets(self.bullets);
            // UpdateStars(self.stars);
            //

            // We check the collisions - added sound support for collisions
            const previous_state = self.state;
            const previous_score = self.score;

            util.checkCollisions(&self.player, &self.asteroids, &self.bullets, &self.score, &self.state);

            // If score changed, an asteroid was hit
            if (self.score > previous_score) {
                if (self.settings.sound_enabled) {
                    // Choose between small and large explosion sound randomly
                    if (rl.getRandomValue(0, 1) == 0) {
                        Sound.playGameSound(self.sound, .explosion_small);
                    } else {
                        Sound.playGameSound(self.sound, .explosion_big);
                    }
                }
            }

            // If state changed to GAME_OVER, player collided with asteroid
            if (previous_state != .game_over and self.state == .game_over) {
                if (self.settings.sound_enabled) {
                    Sound.playGameSound(self.sound, .explosion_big);
                    Sound.playGameSound(self.sound, .game_over);
                }
            }
        },

        .game_over => {
            // Check for the high score
            if (self.score > self.high_score) {
                self.high_score = self.score;
            }

            // Now here we handle the restart or return to menu
            if (rl.isKeyPressed(.enter)) {
                resetGame(self);
                self.state = .game_play;

                // Play select sound
                if (self.settings.sound_enabled) {
                    Sound.playGameSound(self.sound, .menu_select);
                }
            } else if (rl.isKeyPressed(.escape)) {
                resetGame(self);
                self.state = .main_menu;
                self.selected_option = 0;

                // Play select sound
                if (self.settings.sound_enabled) {
                    Sound.playGameSound(self.sound, .menu_select);
                }
            }
            // Keep updating stars for visual effect
            Star.update(&self.stars);
        },
    }

    return true;
}

// Implementing the reset game feature
fn resetGame(self: *Self) void {
    // We reset the player
    Player.init(&self.player);

    Asteroid.init(&self.asteroids);
    Bullet.init(&self.bullets);

    // now we spawn those initial asteroids once again
    for (0..5) |_| {
        Asteroid.spawn(&self.asteroids);
    }
    // reset the score finally
    self.score = 0;
}

pub fn draw(self: *Self) void {
    // Always draw stars first for all states
    Star.draw(self.stars);

    // TODO
    switch (self.state) {
        .main_menu => menu.drawMainMenu(self),
        .options_menu => menu.drawOptionsMenu(self),
        .controls_menu => menu.drawControlsMenu(),
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
        //     DrawPausemenu(game);
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
