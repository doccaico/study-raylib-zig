const Game = @import("Game.zig");

const rl = @import("raylib");

const Type = enum {
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

sounds: [max_sounds]rl.Sound,
menu_music: rl.Music,
game_music: rl.Music,
sound_loaded: [max_sounds]bool,
music_loaded: bool,
music_volume: f32,
sound_volume: f32,

const Self = @This();

pub fn init(self: *Self) !void {
    // Initialize the audio device
    rl.initAudioDevice();

    // Initialize volumes
    // self.music_volume = 0.7;
    // self.sound_volume = 1.0;
    self.music_volume = 0.15;
    self.sound_volume = 0.4;

    self.sound_loaded = [_]bool{false} ** max_sounds;

    self.music_loaded = false;

    // Load all game sounds
    try self.loadGameSounds();
}

pub fn deinit(self: *Self) void {
    // Unload all sound effects that were loaded
    for (0..max_sounds) |i| {
        if (self.sound_loaded[i]) {
            rl.unloadSound(self.sounds[i]);
            self.sound_loaded[i] = false;
        }
    }

    // Unload music if it was loaded
    if (self.music_loaded) {
        // Only unload menuMusic if gameMusic isn't the same pointer
        rl.unloadMusicStream(self.menu_music);

        // Only unload gameMusic if it's different from menuMusic
        if (self.game_music.ctxData != self.menu_music.ctxData) {
            rl.unloadMusicStream(self.game_music);
        }

        self.music_loaded = false;
    }

    // Close the audio device
    rl.closeAudioDevice();
}

fn loadGameSounds(self: *Self) !void {
    // Load sound effects - using your specific file names

    // Shooting sounds - using alienshoot files
    if (rl.fileExists("resources/sounds/alienshoot1.wav")) {
        self.sounds[@intFromEnum(Type.shoot)] = try rl.loadSound("resources/sounds/alienshoot1.wav");
        self.sound_loaded[@intFromEnum(Type.shoot)] = true;
    }

    // Big explosion - using explosion_1.wav (presumably the largest one)
    if (rl.fileExists("resources/sounds/explosion_1.wav")) {
        self.sounds[@intFromEnum(Type.explosion_big)] = try rl.loadSound("resources/sounds/explosion_1.wav");
        self.sound_loaded[@intFromEnum(Type.explosion_big)] = true;
    }

    // Small explosion - using explosion_3.wav (medium sized one)
    if (rl.fileExists("resources/sounds/explosion_3.wav")) {
        self.sounds[@intFromEnum(Type.explosion_small)] = try rl.loadSound("resources/sounds/explosion_3.wav");
        self.sound_loaded[@intFromEnum(Type.explosion_small)] = true;
    }

    // Thrust sound - using engine.wav
    if (rl.fileExists("resources/sounds/engine.wav")) {
        self.sounds[@intFromEnum(Type.thrust)] = try rl.loadSound("resources/sounds/engine.wav");
        self.sound_loaded[@intFromEnum(Type.thrust)] = true;
    }

    // Menu selection sound
    if (rl.fileExists("resources/sounds/menu_select.wav")) {
        self.sounds[@intFromEnum(Type.menu_select)] = try rl.loadSound("resources/sounds/menu_select.wav");
        self.sound_loaded[@intFromEnum(Type.menu_select)] = true;
    }

    // Game over sound - you have this as MP3 so we'll use that
    if (rl.fileExists("resources/sounds/game_over.mp3")) {
        self.sounds[@intFromEnum(Type.game_over)] = try rl.loadSound("resources/sounds/game_over.mp3");
        self.sound_loaded[@intFromEnum(Type.game_over)] = true;
    }

    // Load music files
    if (rl.fileExists("resources/music/menu_music.mp3")) {
        self.menu_music = try rl.loadMusicStream("resources/music/menu_music.mp3");
        rl.setMusicVolume(self.menu_music, self.music_volume);
        self.music_loaded = true;
    }

    // For game music, we'll use menu_music2.mp3 if it exists
    if (rl.fileExists("resources/music/menu_music2.mp3")) {
        self.game_music = try rl.loadMusicStream("resources/music/menu_music2.mp3");
        rl.setMusicVolume(self.game_music, self.music_volume);
    } else if (self.music_loaded) {
        // Fallback to the same music for both menu and game if separate game music doesn't exist
        self.game_music = self.menu_music;
    }
}

pub fn toggleSoundEnabled(self: *Self, enabled: bool) void {
    if (enabled) {
        self.setGameSoundVolume(self.sound_volume);
    } else {
        // Keep the soundManager->soundVolume value but set actual sound output to 0
        for (0..max_sounds) |i| {
            if (self.sound_loaded[i]) {
                rl.setSoundVolume(self.sounds[i], 0.0);
            }
        }
    }
}

pub fn toggleMusicEnabled(self: *Self, enabled: bool) void {
    if (!self.music_loaded)
        return;

    if (enabled) {
        rl.setMusicVolume(self.menu_music, self.music_volume);
        if (self.game_music.ctxData != self.menu_music.ctxData) {
            rl.setMusicVolume(self.game_music, self.music_volume);
        }
        // Resume the appropriate music based on current state (handled in UpdateGameMusic)
    } else {
        // Pause all music
        if (rl.isMusicStreamPlaying(self.menu_music)) {
            rl.pauseMusicStream(self.menu_music);
        }

        if (self.game_music.ctxData != self.menu_music.ctxData and
            rl.isMusicStreamPlaying(self.game_music))
        {
            rl.pauseMusicStream(self.game_music);
        }
    }
}

fn setGameSoundVolume(self: *Self, volume: f32) void {
    // Clamp volume between 0.0 and 1.0
    self.sound_volume = if (volume < 0.0) 0.0 else (if (volume > 1.0) 1.0 else volume);

    // Apply volume to all loaded sounds
    for (0..max_sounds) |i| {
        if (self.sound_loaded[i]) {
            rl.setSoundVolume(self.sounds[i], self.sound_volume);
        }
    }
}

pub fn updateGameMusic(self: *Self, g: *Game) void {
    // Only update music if it was loaded successfully
    if (!self.music_loaded) return;

    // Update music stream, required to play music
    rl.updateMusicStream(self.menu_music);
    if (self.game_music.ctxData != self.menu_music.ctxData) {
        rl.updateMusicStream(self.game_music);
    }

    const S = struct {
        var previous_state: Game.State = undefined;
    };
    // Remove unused variable
    S.previous_state = g.state;

    // Switch between menu and game music based on game state
    if (g.state == .game_play) {
        // If in game_play, stop menu music and play game music if it's not already playing
        if (rl.isMusicStreamPlaying(self.menu_music)) {
            rl.stopMusicStream(self.menu_music);
        }

        if (!rl.isMusicStreamPlaying(self.game_music) and g.settings.music_enabled) {
            rl.playMusicStream(self.game_music);
        }
    } else if (g.state != .paused) { // Don't change music when paused
        // If in menu, stop game music and play menu music if it's not already playing
        if (rl.isMusicStreamPlaying(self.game_music)) {
            rl.stopMusicStream(self.game_music);
        }

        if (!rl.isMusicStreamPlaying(self.menu_music) and g.settings.music_enabled) {
            rl.playMusicStream(self.menu_music);
        }
    }
}

pub fn playGameSound(self: *Self, typ: Type) void {
    // Only play if the sound was loaded successfully and sound is enabled
    if (self.sound_loaded[@intFromEnum(typ)]) {
        rl.playSound(self.sounds[@intFromEnum(typ)]);
    }
}

pub fn pauseGameMusic(self: *Self) void {
    if (self.music_loaded) {
        if (rl.isMusicStreamPlaying(self.menu_music)) {
            rl.pauseMusicStream(self.menu_music);
        }

        if (self.game_music.ctxData != self.menu_music.ctxData and
            rl.isMusicStreamPlaying(self.game_music))
        {
            rl.pauseMusicStream(self.game_music);
        }
    }
}
