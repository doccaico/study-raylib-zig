const std = @import("std");
const constant = @import("constant.zig");

const rl = @import("raylib");

pub const max_asteroids = 20;
const asteroid_speed = 0.6; // Reduced the asteroid speed from 2 to 1.0 (v1.0 had 2.0)

position: rl.Vector2,
velocity: rl.Vector2,
rotation: f32,
rotation_speed: f32,
radius: f32,
active: bool,

const Self = @This();

pub fn init(self: *[max_asteroids]Self) void {
    for (0..max_asteroids) |i| {
        self[i].active = false;
    }
}

pub fn spawn(self: *[max_asteroids]Self) void {
    for (0..max_asteroids) |i| {
        if (!self[i].active) {
            // randomly choose from one of the window edges
            const edge = rl.getRandomValue(0, 3);
            // if the edge is 0 then we get the following;
            if (edge == 0) {
                // this will make an asteroid that will spawn from the top
                self[i].position = rl.Vector2.init(@floatFromInt(rl.getRandomValue(0, constant.screen_width)), 0);
            } else if (edge == 1) {
                // Right
                self[i].position = rl.Vector2.init(constant.screen_width, @floatFromInt(rl.getRandomValue(0, constant.screen_height)));
            } else if (edge == 2) {
                // BOTTOM
                self[i].position = rl.Vector2.init(@floatFromInt(rl.getRandomValue(0, constant.screen_width)), constant.screen_height);
            } else {
                // Left
                self[i].position = rl.Vector2.init(0, @floatFromInt(rl.getRandomValue(0, constant.screen_height)));
            }

            // random velocity we need to do this first
            const angle = @as(f32, @floatFromInt(rl.getRandomValue(0, 360))) * std.math.rad_per_deg;
            self[i].velocity.x = @cos(angle) * asteroid_speed;
            self[i].velocity.y = @sin(angle) * asteroid_speed;

            // Now we do the size and rotational part, we need to program that as well
            self[i].radius = @floatFromInt(rl.getRandomValue(20, 40));
            self[i].rotation = @as(f32, @floatFromInt(rl.getRandomValue(0, 360))) * std.math.rad_per_deg;
            self[i].rotation_speed = @as(f32, @floatFromInt(rl.getRandomValue(-10, 10))) / 100.0;

            self[i].active = true;
            break;
        }
    }
}

// Now we need to implement the functionality of the SPlitting of the asteroid
pub fn split(self: *[max_asteroids]Self, index: usize) void {
    // we get the position of the asteroid
    const position = self[index].position;
    // here we are splitting the radius
    const radius = self[index].radius / 2;

    // we need to split only if the radius is big enough
    // we only make fragments if that radius is larger than 10 pixels
    if (radius >= 10) {
        for (0..2) |_| {
            for (0..max_asteroids) |j| {
                if (!self[j].active) {
                    // here we are setting the position of the fragmented asteroid to the original position of the asteroid
                    self[j].position = position;
                    // we need to make a new angle for this fragment to move in
                    const angle = @as(f32, @floatFromInt(rl.getRandomValue(0, 360))) * std.math.rad_per_deg;
                    // we need to make sure that fragments move faster than big asteroids
                    self[j].velocity.x = @cos(angle) * asteroid_speed * 1.5;
                    // factor of 1.5 is to make sure it moves faster than regular
                    self[j].velocity.y = @sin(angle) * asteroid_speed * 1.5;
                    self[j].radius = radius;
                    self[j].rotation = @as(f32, @floatFromInt(rl.getRandomValue(0, 360))) * std.math.rad_per_deg;
                    // it is from -15 to 15 because they spin faster
                    self[j].rotation_speed = @as(f32, @floatFromInt(rl.getRandomValue(-15, 15))) / 100.0;
                    self[j].active = true;
                    break;
                }
            }
        }
    }
}
