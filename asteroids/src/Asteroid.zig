const std = @import("std");
const constant = @import("constant.zig");
const util = @import("util.zig");

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

pub fn init(asteroids: *[max_asteroids]Asteroid) void {
    for (0..max_asteroids) |i| {
        asteroids[i].active = false;
    }
}

pub fn spawn(asteroids: *[max_asteroids]Asteroid) void {
    for (0..max_asteroids) |i| {
        if (!asteroids[i].active) {
            // randomly choose from one of the window edges
            const edge = rl.getRandomValue(0, 3);
            // if the edge is 0 then we get the following;
            if (edge == 0) {
                // this will make an asteroid that will spawn from the top
                asteroids[i].position = rl.Vector2.init(@floatFromInt(rl.getRandomValue(0, constant.screen_width)), 0);
            } else if (edge == 1) {
                // Right
                asteroids[i].position = rl.Vector2.init(constant.screen_width, @floatFromInt(rl.getRandomValue(0, constant.screen_height)));
            } else if (edge == 2) {
                // BOTTOM
                asteroids[i].position = rl.Vector2.init(@floatFromInt(rl.getRandomValue(0, constant.screen_width)), constant.screen_height);
            } else {
                // Left
                asteroids[i].position = rl.Vector2.init(0, @floatFromInt(rl.getRandomValue(0, constant.screen_height)));
            }

            // random velocity we need to do this first
            const angle = @as(f32, @floatFromInt(rl.getRandomValue(0, 360))) * std.math.rad_per_deg;
            asteroids[i].velocity.x = @cos(angle) * asteroid_speed;
            asteroids[i].velocity.y = @sin(angle) * asteroid_speed;

            // Now we do the size and rotational part, we need to program that as well
            asteroids[i].radius = @floatFromInt(rl.getRandomValue(20, 40));
            asteroids[i].rotation = @as(f32, @floatFromInt(rl.getRandomValue(0, 360))) * std.math.rad_per_deg;
            asteroids[i].rotation_speed = @as(f32, @floatFromInt(rl.getRandomValue(-10, 10))) / 100.0;

            asteroids[i].active = true;
            break;
        }
    }
}

// Now we need to implement the functionality of the SPlitting of the asteroid
pub fn split(asteroids: *[max_asteroids]Asteroid, index: usize) void {
    // we get the position of the asteroid
    const position = asteroids[index].position;
    // here we are splitting the radius
    const radius = asteroids[index].radius / 2;

    // we need to split only if the radius is big enough
    // we only make fragments if that radius is larger than 10 pixels
    if (radius >= 10) {
        for (0..2) |_| {
            for (0..max_asteroids) |j| {
                if (!asteroids[j].active) {
                    // here we are setting the position of the fragmented asteroid to the original position of the asteroid
                    asteroids[j].position = position;
                    // we need to make a new angle for this fragment to move in
                    const angle = @as(f32, @floatFromInt(rl.getRandomValue(0, 360))) * std.math.rad_per_deg;
                    // we need to make sure that fragments move faster than big asteroids
                    asteroids[j].velocity.x = @cos(angle) * asteroid_speed * 1.5;
                    // factor of 1.5 is to make sure it moves faster than regular
                    asteroids[j].velocity.y = @sin(angle) * asteroid_speed * 1.5;
                    asteroids[j].radius = radius;
                    asteroids[j].rotation = @as(f32, @floatFromInt(rl.getRandomValue(0, 360))) * std.math.rad_per_deg;
                    // it is from -15 to 15 because they spin faster
                    asteroids[j].rotation_speed = @as(f32, @floatFromInt(rl.getRandomValue(-15, 15))) / 100.0;
                    asteroids[j].active = true;
                    break;
                }
            }
        }
    }
}

pub fn draw(asteroids: *[max_asteroids]Asteroid) void {
    // we need to draw some interesting asteroid shape
    for (0..max_asteroids) |i| {
        if (asteroids[i].active) {
            // we make it a irregular polygon of 8 sides
            const points = 8.0;
            var prev = rl.Vector2.zero();
            var current = rl.Vector2.zero();

            var j: usize = 0;
            while (j <= points) : (j += 1) {
                // we divide the circles into equal segments
                const angle = @as(f32, @floatFromInt(j)) * (2.0 * std.math.pi / points) + asteroids[i].rotation;
                const radius = asteroids[i].radius * (0.8 + 0.2 * @sin(angle * 5));

                current.x = asteroids[i].position.x + radius * @cos(angle);
                current.y = asteroids[i].position.y + radius * @sin(angle);

                if (j > 0) {
                    rl.drawLineV(prev, current, .white);
                }
                prev = current;
            }
        }
    }
}

pub fn update(asteroids: *[max_asteroids]Asteroid) void {
    for (0..max_asteroids) |i| {
        if (asteroids[i].active) {
            // Then we move the asteroids
            asteroids[i].position.x += asteroids[i].velocity.x;
            asteroids[i].position.y += asteroids[i].velocity.y;

            // Now we can rotate the asteroids
            asteroids[i].rotation += asteroids[i].rotation_speed;

            // Now we wrap their position
            util.wrapPosition(&asteroids[i].position);
        }
    }

    // Spawn new asteroids ocassionally
    if (rl.getRandomValue(0, 100) < 1) {
        spawn(asteroids);
    }
}
