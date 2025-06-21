const constant = @import("constant.zig");
const Sound = @import("Sound.zig");
const Game = @import("Game.zig");
const Resolution = @import("Resolution.zig");

const rl = @import("raylib");

// Global screen dimensions
// var screen_width: i32 = constant.screen_width;
// var screen_height: i32 = constant.screen_height;

pub fn main() !void {
    rl.initWindow(constant.screen_width, constant.screen_height, constant.window_title);
    // defer rl.closeWindow();

    // Enable vsync
    rl.setWindowState(.{ .vsync_hint = true });

    rl.setTargetFPS(constant.fps);

    // Disable default exit key (escape)
    rl.setExitKey(.null);

    // Initialize the sound system
    var sound: Sound = undefined;
    try Sound.init(&sound);
    defer sound.deinit();

    // Initialize the Game itself
    var g: Game = undefined;
    Game.init(&g, &sound);

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
