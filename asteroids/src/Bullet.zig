const std = @import("std");
const global = @import("global.zig");

const rl = @import("raylib");

pub const max_bullets = 100;
const bullet_speed = 10; // Bullet speed
pub const bullet_cooldown = 8; // 8 frames cooldown between shots (was 0)
const bullet_lifetime = 120; // How long bullets live for
const bullet_spread = 2.0; // Slight spread when shooting (in degrees)

position: rl.Vector2,
velocity: rl.Vector2,
radius: f32,
active: bool,
life_time: f32,
color: rl.Color, // Added color for visual variety
alpha: f32, // Added alpha for fading effect

const Bullet = @This();

pub fn init(bullets: []Bullet) void {
    for (0..max_bullets) |i| {
        bullets[i].active = false;
    }
}

pub fn shootBullets(bullets: *[max_bullets]Bullet, position: rl.Vector2, rotation: f32) void {
    // We'll shoot 3 bullets with a slight spread for a more interesting effect
    var spread: isize = -1;
    while (spread <= 1) : (spread += 1) {
        // Find an inactive bullet to use
        for (0..max_bullets) |i| {
            {
                if (!bullets[i].active) {
                    // Get the actual rotation with spread
                    const bullet_rotation = rotation + @as(f32, @floatFromInt(spread)) * bullet_spread;

                    // Calculate velocity based on spread-adjusted rotation
                    const cos_a = @cos(bullet_rotation * std.math.rad_per_deg);
                    const sin_a = @sin(bullet_rotation * std.math.rad_per_deg);

                    bullets[i].position = position;
                    bullets[i].velocity.x = cos_a * bullet_speed;
                    bullets[i].velocity.y = sin_a * bullet_speed;
                    // Slightly different sizes
                    bullets[i].radius = 3.0 + @as(f32, @floatFromInt(@abs(spread))) * 0.5;
                    // Center bullet lasts longer
                    bullets[i].life_time = @floatFromInt(bullet_lifetime - @abs(spread) * 10);
                    bullets[i].active = true;
                    bullets[i].alpha = 1.0;

                    // Set different colors for visual interest
                    if (spread == 0) {
                        bullets[i].color = rl.Color.init(255, 255, 255, 255); // White for center
                    } else if (spread == -1) {
                        bullets[i].color = rl.Color.init(0, 200, 255, 255); // Blue-ish
                    } else {
                        bullets[i].color = rl.Color.init(255, 200, 0, 255); // Yellow-ish
                    }

                    break; // We found an inactive bullet to use, so break the inner loop
                }
            }
        }
    }
}

pub fn draw(bullets: *[max_bullets]Bullet) void {
    for (0..max_bullets) |i| {
        if (bullets[i].active) {
            // Create a color with adjusted alpha for fading effect
            var bullet_color = bullets[i].color;
            bullet_color.a = @intFromFloat(bullets[i].alpha * 255.0);

            // Draw the bullet
            rl.drawCircle(@intFromFloat(bullets[i].position.x), @intFromFloat(bullets[i].position.y), bullets[i].radius, bullet_color);

            // Draw a smaller inner circle for a more interesting visual
            var inner_color = rl.Color.white;
            inner_color.a = @intFromFloat(bullets[i].alpha * 255.0);
            rl.drawCircle(@intFromFloat(bullets[i].position.x), @intFromFloat(bullets[i].position.y), bullets[i].radius * 0.5, inner_color);
        }
    }
}

pub fn update(bullets: *[max_bullets]Bullet) void {
    for (0..max_bullets) |i| {
        // Update active bullets
        if (bullets[i].active) {
            // Move the bullets
            bullets[i].position.x += bullets[i].velocity.x;
            bullets[i].position.y += bullets[i].velocity.y;

            // We don't wrap bullets around edges anymore - they disappear offscreen

            // If bullet goes off-screen, deactivate it
            if (bullets[i].position.x < 0 or
                bullets[i].position.x > @as(f32, @floatFromInt(global.current_screen_width)) or
                bullets[i].position.y < 0 or
                bullets[i].position.y > @as(f32, @floatFromInt(global.current_screen_height)))
            {
                bullets[i].active = false;
                continue;
            }

            // Update lifetime
            bullets[i].life_time -= 1;

            // Fade bullets as they get older
            if (bullets[i].life_time < 40) {
                bullets[i].alpha = bullets[i].life_time / 40.0;
            }

            // Deactivate expired bullets
            if (bullets[i].life_time <= 0) {
                bullets[i].active = false;
            }
        }
    }
}
