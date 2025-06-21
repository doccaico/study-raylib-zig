const constant = @import("constant.zig");

const rl = @import("raylib");

pub const max_stars = 100; // number of stars
const star_layers = 3; // using this to try to make a parallax effect in the game

position: rl.Vector2, // 2D vector for the position of the stars
brightness: f32, // variable that controls the brightness of the stars 0.0f to 1.0f
size: i32, // 1-3 pixels size
layer: i32, // can be 0, 1 or 2 for different movement layers and speeds
color: rl.Color, // wanted to make sure different stars have different colors

const Self = @This();

pub fn init(self: *[max_stars]Self) void {
    for (0..max_stars) |i| {
        // making random positions of the stars at first
        self[i].position.x = @floatFromInt(rl.getRandomValue(0, constant.screen_width));
        self[i].position.y = @floatFromInt(rl.getRandomValue(0, constant.screen_height));
        // adding stars brigthness levels
        self[i].brightness = @floatFromInt(@divTrunc(rl.getRandomValue(10, 100), 100));
        self[i].size = rl.getRandomValue(1, 3);
        self[i].layer = rl.getRandomValue(0, star_layers - 1);

        // now adding slightly varying colors of the stars
        const color_var = rl.getRandomValue(-20, 20);
        self[i].color = rl.Color.init(@intCast(@as(i32, 230) + color_var), @intCast(@as(i32, 230) + color_var), 240, @intFromFloat(self[i].brightness * 255));
    }
}

// Adding function for Updating the stars themselves
pub fn update(self: *[max_stars]Self) void {
    // Adding a twinkle effect or something like that
    for (0..max_stars) |i| {
        {
            if (rl.getRandomValue(0, 100) < 5) {
                self[i].brightness = @as(f32, @floatFromInt(rl.getRandomValue(10, 100))) / 100.0;
                self[i].color.a = @intFromFloat(self[i].brightness * 255.0);
            }
        }

        // Optional adding the paralax effect with layers
    }
}

pub fn draw(self: [max_stars]Self) void {
    for (0..max_stars) |i| {
        if (self[i].size == 1) {
            rl.drawPixelV(self[i].position, self[i].color);
        } else {
            rl.drawCircleV(self[i].position, @as(f32, @floatFromInt(self[i].size)) * 0.5, self[i].color);
        }
    }
}
