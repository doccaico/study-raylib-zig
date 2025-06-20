const std = @import("std");
const config = @import("config.zig");

const rl = @import("raylib");

pub const max_asteroids = 20;
const asteroid_speed = 0.6; // Reduced the asteroid speed from 2 to 1.0 (v1.0 had 2.0)

pub const Asteroid = struct {
    position: rl.Vector2,
    velocity: rl.Vector2,
    rotation: f32,
    rotation_speed: f32,
    radius: f32,
    active: bool,

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
};
