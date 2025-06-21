// const builtin = @import("builtin");
const std = @import("std");
const Config = @import("config.zig");
const Sound = @import("sound.zig");
const Game = @import("game.zig");
const Resolution = @import("resolution.zig");

const rl = @import("raylib");

// Global screen dimensions
// var screen_width: i32 = Config.screen_width;
// var screen_height: i32 = Config.screen_height;

pub fn main() !void {
    rl.initWindow(Config.screen_width, Config.screen_height, Config.window_title);
    // defer rl.closeWindow();

    // Enable vsync
    rl.setWindowState(.{ .vsync_hint = true });

    rl.setTargetFPS(Config.fps);

    // Disable default exit key (escape)
    rl.setExitKey(.null);

    // Initialize the sound system
    var sound_manager: Sound.Manager = undefined;
    try Sound.Manager.init(&sound_manager);
    defer sound_manager.deinit();

    // Initialize the Game itself
    var g: Game = undefined;
    Game.init(&g, &sound_manager);

    // var prng = std.Random.DefaultPrng.init(blk: {
    //     var seed: u64 = undefined;
    //     try std.posix.getrandom(std.mem.asBytes(&seed));
    //     break :blk seed;
    // });
    //
    // const rand = prng.random();
    //
    // var gpa: std.heap.DebugAllocator(.{}) = .init;
    // const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;
    // defer if (builtin.mode == .Debug) {
    //     _ = gpa.deinit();
    // };
    //
    // var app = try App.init(allocator, rand);
    // defer app.deinit();

    while (!rl.windowShouldClose()) {
        // We handle the F11 key for fullscreen toggle
        if (rl.isKeyPressed(.f11)) {
            Resolution.toggleFullscreenMode(&g);
        }

        // Game.update(&g);
        if (!Game.update(&g)) {
            break;
        }

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.black);

        Game.draw(&g);
    }

    rl.closeWindow();
}
