const config = @import("config.zig");

const rl = @import("raylib");

pub const max_stars = 100; // number of stars
const star_layers = 3; // using this to try to make a parallax effect in the game

position: rl.Vector2, // 2D vector for the position of the stars
brightness: f32, // variable that controls the brightness of the stars 0.0f to 1.0f
size: i32, // 1-3 pixels size
layer: i32, // can be 0, 1 or 2 for different movement layers and speeds
color: rl.Color, // wanted to make sure different stars have different colors

const Star = @This();

pub fn init(s: *[max_stars]Star) void {
    for (0..max_stars) |i| {
        // making random positions of the stars at first
        s[i].position.x = @floatFromInt(rl.getRandomValue(0, config.screen_width));
        s[i].position.y = @floatFromInt(rl.getRandomValue(0, config.screen_height));
        // adding stars brigthness levels
        s[i].brightness = @floatFromInt(@divTrunc(rl.getRandomValue(10, 100), 100));
        s[i].size = rl.getRandomValue(1, 3);
        s[i].layer = rl.getRandomValue(0, star_layers - 1);

        // now adding slightly varying colors of the stars
        const color_var = rl.getRandomValue(-20, 20);
        // zig fmt: off
            s[i].color = rl.Color.init(
                @intCast(@as(i32, 230) + color_var),
                @intCast(@as(i32, 230) + color_var),
                240,
                @intFromFloat(s[i].brightness * 255));
            // zig fmt: on
    }
}

// Adding function for Updating the stars themselves
pub fn update(s: *[max_stars]Star) void {
    // Adding a twinkle effect or something like that
    for (0..max_stars) |i| {
        {
            if (rl.getRandomValue(0, 100) < 5) {
                s[i].brightness = @as(f32, @floatFromInt(rl.getRandomValue(10, 100))) / 100.0;
                s[i].color.a = @intFromFloat(s[i].brightness * 255.0);
            }
        }

        // Optional adding the paralax effect with layers
    }
}
