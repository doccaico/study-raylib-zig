const Game = @import("Game.zig");

const rl = @import("raylib");

// Sound Types
const Sound = enum {
    menu_music, // Background music for the menu
    game_music, // Background music during gameplay
    shoot, // Bullet shooting sound
    explosion_big, // Large asteroid explosion
    explosion_small, // Small asteroid explosion
    thrust, // Player ship thrust sound
    menu_select, // Menu selection sound
    game_over, // Game over sound
};

const max_sounds = 8;

// const sound_names = [_][:0]const u8{
//     "resources/sounds/alienshoot1.wav",
// "resources/sounds/explosion_1.wav",
// "resources/sounds/explosion_3.wav",
// "resources/sounds/engine.wav",
// "resources/sounds/menu_select.wav",
// "resources/sounds/game_over.mp3",
// "resources/music/menu_music.mp3",
// "resources/music/menu_music2.mp3",
// };

// Sound structure
pub const Manager = struct {
    sounds: [max_sounds]rl.Sound,
    menu_music: rl.Music,
    game_music: rl.Music,
    sound_loaded: [max_sounds]bool,
    music_loaded: bool,
    music_volume: f32,
    sound_volume: f32,

    pub fn init(m: *Manager) !void {
        // Initialize the audio device
        rl.initAudioDevice();

        // Initialize volumes
        m.music_volume = 0.7;
        m.sound_volume = 1.0;

        m.sound_loaded = [_]bool{false} ** max_sounds;

        m.music_loaded = false;

        // Load all game sounds
        try m.loadGameSounds();
    }

    pub fn deinit(m: *Manager) void {
        // Unload all sound effects that were loaded
        for (0..max_sounds) |i| {
            if (m.sound_loaded[i]) {
                rl.unloadSound(m.sounds[i]);
                m.sound_loaded[i] = false;
            }
        }

        // Unload music if it was loaded
        if (m.music_loaded) {
            // Only unload menuMusic if gameMusic isn't the same pointer
            rl.unloadMusicStream(m.menu_music);

            // Only unload gameMusic if it's different from menuMusic
            if (m.game_music.ctxData != m.menu_music.ctxData) {
                rl.unloadMusicStream(m.game_music);
            }

            m.music_loaded = false;
        }

        // Close the audio device
        rl.closeAudioDevice();
    }

    fn loadGameSounds(m: *Manager) !void {
        // Load sound effects - using your specific file names

        // Shooting sounds - using alienshoot files
        if (rl.fileExists("resources/sounds/alienshoot1.wav")) {
            m.sounds[@intFromEnum(Sound.shoot)] = try rl.loadSound("resources/sounds/alienshoot1.wav");
            m.sound_loaded[@intFromEnum(Sound.shoot)] = true;
        }

        // Big explosion - using explosion_1.wav (presumably the largest one)
        if (rl.fileExists("resources/sounds/explosion_1.wav")) {
            m.sounds[@intFromEnum(Sound.explosion_big)] = try rl.loadSound("resources/sounds/explosion_1.wav");
            m.sound_loaded[@intFromEnum(Sound.explosion_big)] = true;
        }

        // Small explosion - using explosion_3.wav (medium sized one)
        if (rl.fileExists("resources/sounds/explosion_3.wav")) {
            m.sounds[@intFromEnum(Sound.explosion_small)] = try rl.loadSound("resources/sounds/explosion_3.wav");
            m.sound_loaded[@intFromEnum(Sound.explosion_small)] = true;
        }

        // Thrust sound - using engine.wav
        if (rl.fileExists("resources/sounds/engine.wav")) {
            m.sounds[@intFromEnum(Sound.thrust)] = try rl.loadSound("resources/sounds/engine.wav");
            m.sound_loaded[@intFromEnum(Sound.thrust)] = true;
        }

        // Menu selection sound
        if (rl.fileExists("resources/sounds/menu_select.wav")) {
            m.sounds[@intFromEnum(Sound.menu_select)] = try rl.loadSound("resources/sounds/menu_select.wav");
            m.sound_loaded[@intFromEnum(Sound.menu_select)] = true;
        }

        // Game over sound - you have this as MP3 so we'll use that
        if (rl.fileExists("resources/sounds/game_over.mp3")) {
            m.sounds[@intFromEnum(Sound.game_over)] = try rl.loadSound("resources/sounds/game_over.mp3");
            m.sound_loaded[@intFromEnum(Sound.game_over)] = true;
        }

        // Load music files
        if (rl.fileExists("resources/music/menu_music.mp3")) {
            m.menu_music = try rl.loadMusicStream("resources/music/menu_music.mp3");
            rl.setMusicVolume(m.menu_music, m.music_volume);
            m.music_loaded = true;
        }

        // For game music, we'll use menu_music2.mp3 if it exists
        if (rl.fileExists("resources/music/menu_music2.mp3")) {
            m.game_music = try rl.loadMusicStream("resources/music/menu_music2.mp3");
            rl.setMusicVolume(m.game_music, m.music_volume);
        } else if (m.music_loaded) {
            // Fallback to the same music for both menu and game if separate game music doesn't exist
            m.game_music = m.menu_music;
        }
    }

    pub fn toggleSoundEnabled(m: *Manager, enabled: bool) void {
        if (enabled) {
            m.setGameSoundVolume(m.sound_volume);
        } else {
            // Keep the soundManager->soundVolume value but set actual sound output to 0
            for (0..max_sounds) |i| {
                if (m.sound_loaded[i]) {
                    rl.setSoundVolume(m.sounds[i], 0.0);
                }
            }
        }
    }

    pub fn toggleMusicEnabled(m: *Manager, enabled: bool) void {
        if (!m.music_loaded)
            return;

        if (enabled) {
            rl.setMusicVolume(m.menu_music, m.music_volume);
            if (m.game_music.ctxData != m.menu_music.ctxData) {
                rl.setMusicVolume(m.game_music, m.music_volume);
            }
            // Resume the appropriate music based on current state (handled in UpdateGameMusic)
        } else {
            // Pause all music
            if (rl.isMusicStreamPlaying(m.menu_music)) {
                rl.pauseMusicStream(m.menu_music);
            }

            if (m.game_music.ctxData != m.menu_music.ctxData and
                rl.isMusicStreamPlaying(m.game_music))
            {
                rl.pauseMusicStream(m.game_music);
            }
        }
    }

    fn setGameSoundVolume(m: *Manager, volume: f32) void {
        // Clamp volume between 0.0 and 1.0
        m.sound_volume = if (volume < 0.0) 0.0 else (if (volume > 1.0) 1.0 else volume);

        // Apply volume to all loaded sounds
        for (0..max_sounds) |i| {
            if (m.sound_loaded[i]) {
                rl.setSoundVolume(m.sounds[i], m.sound_volume);
            }
        }
    }

    pub fn updateGameMusic(s: *SoundManager, g: *Game) void {
        // Only update music if it was loaded successfully
        if (!s.music_loaded) return;

        // Update music stream, required to play music
        rl.updateMusicStream(s.menu_music);
        if (s.game_music.ctxData != s.menu_music.ctxData) {
            rl.updateMusicStream(s.game_music);
        }

        const S = struct {
            var previous_state: Game.State = undefined;
        };
        // Remove unused variable
        S.previous_state = g.state;

        // Switch between menu and game music based on game state
        if (g.state == .gameplay) {
            // If in gameplay, stop menu music and play game music if it's not already playing
            if (rl.isMusicStreamPlaying(s.menu_music)) {
                rl.stopMusicStream(s.menu_music);
            }

            if (!rl.isMusicStreamPlaying(s.game_music) and g.settings.music_enabled) {
                rl.playMusicStream(s.game_music);
            }
        } else if (g.state != .paused) { // Don't change music when paused
            // If in menu, stop game music and play menu music if it's not already playing
            if (rl.isMusicStreamPlaying(s.game_music)) {
                rl.stopMusicStream(s.game_music);
            }

            if (!rl.isMusicStreamPlaying(s.menu_music) and g.settings.music_enabled) {
                rl.playMusicStream(s.menu_music);
            }
        }
    }
};
