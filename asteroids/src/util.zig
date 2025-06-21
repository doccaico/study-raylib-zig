const Global = @import("global.zig");
const Player = @import("Player.zig");
const Game = @import("Game.zig");
const Asteroid = @import("Asteroid.zig");
const max_asteroids = Asteroid.max_asteroids;
const Bullet = @import("Bullet.zig");
const max_bullets = Bullet.max_bullets;

const rl = @import("raylib");

pub fn wrapPosition(position: *rl.Vector2) void {
    if (position.x > @as(f32, @floatFromInt(Global.current_screen_width))) {
        position.x = 0;
    } else if (position.x < 0) {
        position.x = @as(f32, @floatFromInt(Global.current_screen_width));
    }

    if (position.y > @as(f32, @floatFromInt(Global.current_screen_height))) {
        position.y = 0;
    } else if (position.y < 0) {
        position.y = @as(f32, @floatFromInt(Global.current_screen_height));
    }
}

// Function for checking collisions between bullets, asteroids, player and updating the score nad gameState if needed
pub fn checkCollisions(player: *Player, asteroids: *[max_asteroids]Asteroid, bullets: *[max_bullets]Bullet, score: *i32, game_state: *Game.State) void {
    // let's check the bullet and asteroid collisions
    for (0..max_bullets) |i| {
        if (bullets[i].active) {
            for (0..max_asteroids) |j| {
                if (asteroids[j].active) {
                    // now we check here if the collision occured really
                    if (checkCollisionCircles(bullets[i].position, bullets[i].radius, asteroids[j].position, asteroids[j].radius)) {
                        // if it did occur the asteroid has been hit it seems!
                        bullets[i].active = false;
                        asteroids[j].active = false;
                        score.* = score.* + 100;

                        if (asteroids[j].radius > 20) {
                            // splitAsteroid(asteroids, j);
                            Asteroid.split(asteroids, j);
                        }

                        break;
                    }
                }
            }
        }
    }

    // now we check the collisions between ship and asteroid
    for (0..max_asteroids) |i| {
        // if the asteroid is acctive
        if (asteroids[i].active) {
            // if we the collision happened
            if (checkCollisionCircles(player.position, Player.ship_size / 2, asteroids[i].position, asteroids[i].radius)) {
                // Player has been HIT!
                game_state.* = .game_over;
                break;
            }
        }
    }
}

fn checkCollisionCircles(center1: rl.Vector2, radius1: f32, center2: rl.Vector2, radius2: f32) bool {
    const dx = center2.x - center1.x;
    const dy = center2.y - center1.y;
    const distance = @sqrt(dx * dx + dy * dy);

    return distance <= radius1 + radius2;
}
