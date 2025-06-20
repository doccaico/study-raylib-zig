const config = @import("config.zig");
const Player = @import("player.zig").Player;
const Sound = @import("sound.zig");
const Asteroid = @import("asteroids.zig").Asteroid;
const max_asteroids = @import("asteroids.zig").max_asteroids;
const Bullet = @import("bullet.zig").Bullet;
const max_bullets = @import("bullet.zig").max_bullets;
const Star = @import("stars.zig").Star;
const max_stars = @import("stars.zig").max_stars;
const Resolution = @import("resolution.zig").Resolution;
const max_resolutions = @import("resolution.zig").max_resolutions;

const rl = @import("raylib");

// Game states
const State = enum {
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
pub const Game = struct {
    state: GameState,
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
    current_screen_width: i32,
    current_screen_height: i32,
    sound_manager: *Sound.Manager, // Added sound manager pointer

    pub fn init(g: *Game, sound_manager: *Sound.Manager) void {
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
        g.current_screen_width = config.screen_width;
        g.current_screen_height = config.screen_height;

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

pub fn UpdateGame(g :*Game) void
{
    // Update music
    Sound.updateGameMusic(g.sound_manager, g);

    // Check first if we should exit the application
    if (WindowShouldClose()) 
    {
        // This is the exit process triggered by the window X button
        // You may want to add confirmation here
        return;
    }

    // Handle pausing during gameplay - ONLY pause, don't exit
    if (g.state == .gameplay and rl.isKeyPressed(.p))
    {
        g.state = .paused;
        g.selected_option = 0;   // Default to Resume
        
        // Pause music when game is paused
        PauseGameMusic(g.soundManager);
        
        return;
    }
    
    // Handle ESC during gameplay to return to main menu
    if (g.state == .gameplay and rl.isKeyPressed(.escape))
    {
        g.state = .main_menu;
        g.selectedOption = 0;   // Default to first option
        
        // Play menu select sound
        if (g.settings.sound_enabled) {
            rl.playGameSound(g.sound_manager, .menu_select);
        }
        
        return;
    }

    // Handle different game states
    switch (g.state)
    {
        .main_menu => {
            updateMainMenu(g);
            updateStars(g.stars);
        },

        .options_menu => {
            // TODO
            updateOptionsMenu(g);
            updateStars(g.stars);
        },

        case CONTROLS_MENU:
            UpdateControlsMenu(game);
            UpdateStars(g.stars);
            break;

        case PAUSED:
            UpdatePauseMenu(game);
            break;

        case GAMEPLAY:
            {  // Add braces to create a new scope for local variables
                // Store previous thrusting state to detect changes
                bool wasThrustingBefore = g.player.isThrusting;
                int previousShootCooldown = g.player.shootCooldown;
                
                UpdatePlayer(&g.player, g.bullets); 
                
                // Play thrust sound if player just started thrusting
                if (!wasThrustingBefore && g.player.isThrusting) {
                    if (g.soundManager != NULL && g.settings.soundEnabled) {
                        PlayGameSound(g.soundManager, SOUND_THRUST);
                    }
                }
                
                // Play shooting sound
                if (previousShootCooldown == 0 && g.player.shootCooldown > 0) {
                    if (g.soundManager != NULL && g.settings.soundEnabled) {
                        PlayGameSound(g.soundManager, SOUND_SHOOT);
                    }
                }
                
                UpdateAsteroid(g.asteroids);
                UpdateBullets(g.bullets);
                UpdateStars(g.stars);

                // We check the collisions - added sound support for collisions
                GameState previousState = g.state;
                int previousScore = g.score;
                
                checkCollisions(&g.player, g.asteroids, g.bullets, &g.score, &g.state);
                
                // If score changed, an asteroid was hit
                if (g.score > previousScore) {
                    if (g.soundManager != NULL && g.settings.soundEnabled) {
                        // Choose between small and large explosion sound randomly
                        if (GetRandomValue(0, 1) == 0) {
                            PlayGameSound(g.soundManager, SOUND_EXPLOSION_SMALL);
                        } else {
                            PlayGameSound(g.soundManager, SOUND_EXPLOSION_BIG);
                        }
                    }
                }
                
                // If state changed to GAME_OVER, player collided with asteroid
                if (previousState != GAME_OVER && g.state == GAME_OVER) {
                    if (g.soundManager != NULL && g.settings.soundEnabled) {
                        PlayGameSound(g.soundManager, SOUND_EXPLOSION_BIG);
                        PlayGameSound(g.soundManager, SOUND_GAME_OVER);
                    }
                }
            }
            break;

        case GAME_OVER:
            // Check for the high score
            if (g.score > g.highScore)
            {
                g.highScore = g.score;
            }

            // Now here we handle the restart or return to menu
            if (IsKeyPressed(KEY_ENTER))
            {
                ResetGame(game);
                g.state = GAMEPLAY;
                
                // Play select sound
                if (g.soundManager != NULL && g.settings.soundEnabled) {
                    PlayGameSound(g.soundManager, SOUND_MENU_SELECT);
                }
            }
            else if (IsKeyPressed(KEY_ESCAPE))
            {
                ResetGame(game);
                g.state = MAIN_MENU;
                g.selectedOption = 0;
                
                // Play select sound
                if (g.soundManager != NULL && g.settings.soundEnabled) {
                    PlayGameSound(g.soundManager, SOUND_MENU_SELECT);
                }
            }
            // Keep updating stars for visual effect
            UpdateStars(g.stars);
            break;
    }
}
};
