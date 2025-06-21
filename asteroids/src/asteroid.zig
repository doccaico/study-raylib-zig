const std = @import("std");
const config = @import("config.zig");

const rl = @import("raylib");

pub const max_asteroids = 20;
const asteroid_speed = 0.6; // Reduced the asteroid speed from 2 to 1.0 (v1.0 had 2.0)

position: rl.Vector2,
velocity: rl.Vector2,
rotation: f32,
rotation_speed: f32,
radius: f32,
active: bool,

const Asteroid = @This();

pub fn init(a: *[max_asteroids]Asteroid) void {
    for (0..max_asteroids) |i| {
        a[i].active = false;
    }
}

pub fn spawn(a: *[max_asteroids]Asteroid) void {
    for (0..max_asteroids) |i| {
        if (!a[i].active) {
            // randomly choose from one of the window edges
            const edge = rl.getRandomValue(0, 3);
            // if the edge is 0 then we get the following;
            if (edge == 0) {
                // this will make an asteroid that will spawn from the top
                a[i].position = rl.Vector2.init(@floatFromInt(rl.getRandomValue(0, config.screen_width)), 0);
            } else if (edge == 1) {
                // Right
                a[i].position = rl.Vector2.init(config.screen_width, @floatFromInt(rl.getRandomValue(0, config.screen_height)));
            } else if (edge == 2) {
                // BOTTOM
                a[i].position = rl.Vector2.init(@floatFromInt(rl.getRandomValue(0, config.screen_width)), config.screen_height);
            } else {
                // Left
                a[i].position = rl.Vector2.init(0, @floatFromInt(rl.getRandomValue(0, config.screen_height)));
            }

            // random velocity we need to do this first
            const angle = @as(f32, @floatFromInt(rl.getRandomValue(0, 360))) * std.math.rad_per_deg;
            a[i].velocity.x = @cos(angle) * asteroid_speed;
            a[i].velocity.y = @sin(angle) * asteroid_speed;

            // Now we do the size and rotational part, we need to program that as well
            a[i].radius = @floatFromInt(rl.getRandomValue(20, 40));
            a[i].rotation = @as(f32, @floatFromInt(rl.getRandomValue(0, 360))) * std.math.rad_per_deg;
            a[i].rotation_speed = @as(f32, @floatFromInt(rl.getRandomValue(-10, 10))) / 100.0;

            a[i].active = true;
            break;
        }
    }
}

// Now we need to implement the functionality of the SPlitting of the asteroid
pub fn split(a: *[max_asteroids]Asteroid, index: usize) void {
    // we get the position of the asteroid
    const position = a[index].position;
    // here we are splitting the radius
    const radius = a[index].radius / 2;

    // we need to split only if the radius is big enough
    // we only make fragments if that radius is larger than 10 pixels
    if (radius >= 10) {
        for (0..2) |_| {
            for (0..max_asteroids) |j| {
                if (!a[j].active) {
                    // here we are setting the position of the fragmented asteroid to the original position of the asteroid
                    a[j].position = position;
                    // we need to make a new angle for this fragment to move in
                    const angle = @as(f32, @floatFromInt(rl.getRandomValue(0, 360))) * std.math.rad_per_deg;
                    // we need to make sure that fragments move faster than big asteroids
                    a[j].velocity.x = @cos(angle) * asteroid_speed * 1.5;
                    // factor of 1.5 is to make sure it moves faster than regular
                    a[j].velocity.y = @sin(angle) * asteroid_speed * 1.5;
                    a[j].radius = radius;
                    a[j].rotation = @as(f32, @floatFromInt(rl.getRandomValue(0, 360))) * std.math.rad_per_deg;
                    // it is from -15 to 15 because they spin faster
                    a[j].rotation_speed = @as(f32, @floatFromInt(rl.getRandomValue(-15, 15))) / 100.0;
                    a[j].active = true;
                    break;
                }
            }
        }
    }
}
