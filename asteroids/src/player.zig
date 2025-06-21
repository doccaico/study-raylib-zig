const std = @import("std");
const Config = @import("config.zig");
const Util = @import("util.zig");
const Bullet = @import("bullet.zig");
const max_bullets = Bullet.max_bullets;
const bullet_cooldown = Bullet.bullet_cooldown;

const rl = @import("raylib");

pub const ship_size = 20;
const ship_acceleration = 0.15; // Changed the ship acceleration (v1.0 -> 0.1f value) to 0.15f
const rotation_speed = 4.0; // Changed the rot speed (v1.0 -> 3,0f) to 4.0f
const ship_drag = 0.97; // Decided to add the necessary drag changes as well

const ControlMode = enum { keyboard, mouse };

// Player ship structure
position: rl.Vector2,
velocity: rl.Vector2,
rotation: f32,
rotation_velocity: f32, // Added for smoother rotation
is_thrusting: bool,
shoot_cooldown: i32,
control_mode: ControlMode, // 0 = keyboard, 1 = mouse

const Player = @This();

pub fn init(p: *Player) void {
    // Setting up initially
    p.position = rl.Vector2.init(Config.screen_width / 2, Config.screen_height / 2);
    p.velocity = rl.Vector2.zero();
    p.rotation = 0.0;
    p.rotation_velocity = 0.0; // Add rotation velocity for smooth turning
    p.is_thrusting = false;
    p.shoot_cooldown = 0;
    p.control_mode = .keyboard; // Default to keyboard controls
}

pub fn update(p: *Player, bullets: *[max_bullets]Bullet) void {
    // Handle control mode switching
    if (rl.isKeyPressed(.m)) {
        p.control_mode = if (p.control_mode == .keyboard) .mouse else .keyboard;
    }

    if (p.control_mode == .keyboard) {
        updatePlayerKeyboard(p, bullets);
    } else {
        updatePlayerMouse(p, bullets);
    }

    // Apply velocities to position (common for both control modes)
    p.position.x += p.velocity.x;
    p.position.y += p.velocity.y;

    // Apply dampening (space drag)
    p.velocity.x *= ship_drag;
    p.velocity.y *= ship_drag;

    // Apply rotation velocity and dampening for smooth rotation
    p.rotation += p.rotation_velocity;
    p.rotation_velocity *= 0.9; // Rotation dampening

    // Keep rotation in 0-360 range for clean math
    if (p.rotation > 360)
        p.rotation -= 360;
    if (p.rotation < 0)
        p.rotation += 360;

    // Wrap position around the screen
    Util.wrapPosition(&p.position);

    // Handle shooting cooldown (common for both control modes)
    if (p.shoot_cooldown > 0) {
        p.shoot_cooldown -= 1;
    }
}

fn updatePlayerKeyboard(p: *Player, bullets: *[max_bullets]Bullet) void {
    // Smoother rotation with acceleration
    if (rl.isKeyDown(.left) or rl.isKeyDown(.a)) {
        // Add rotation acceleration with a cap
        p.rotation_velocity = @max(p.rotation_velocity - 0.3, -rotation_speed);
    } else if (rl.isKeyDown(.right) or rl.isKeyDown(.d)) {
        // Add rotation acceleration with a cap
        p.rotation_velocity = @min(p.rotation_velocity + 0.3, rotation_speed);
    } else {
        // If no keys are pressed, apply more dampening to stop rotation more quickly
        p.rotation_velocity *= 0.85;
    }

    // Handle thrusting with smoother acceleration
    p.is_thrusting = rl.isKeyDown(.up) or rl.isKeyDown(.w);
    if (p.is_thrusting) {
        // Calculate the acceleration vector based on the ship's rotation
        const cosA = @cos(p.rotation * std.math.rad_per_deg);
        const sinA = @sin(p.rotation * std.math.rad_per_deg);

        // Apply acceleration with slightly increasing force for better control
        var thrust_factor = ship_acceleration * (1.0 + 0.1 * (@abs(p.velocity.x) + @abs(p.velocity.y)) / 10.0);
        thrust_factor = @min(thrust_factor, ship_acceleration * 1.5); // Cap the boost

        p.velocity.x += cosA * thrust_factor;
        p.velocity.y += sinA * thrust_factor;

        // Cap maximum velocity for better control
        const current_speed = @sqrt(p.velocity.x * p.velocity.x + p.velocity.y * p.velocity.y);
        if (current_speed > 5.0) {
            p.velocity.x = (p.velocity.x / current_speed) * 5.0;
            p.velocity.y = (p.velocity.y / current_speed) * 5.0;
        }
    }

    // Shooting with keyboard
    if ((rl.isKeyDown(.space) or rl.isKeyPressed(.space)) and p.shoot_cooldown == 0) {
        Bullet.shootBullets(bullets, p.position, p.rotation);
        p.shoot_cooldown = bullet_cooldown;
    }
}

fn updatePlayerMouse(p: *Player, bullets: *[max_bullets]Bullet) void {
    // Get mouse position
    const mouse_pos = rl.getMousePosition();

    // Calculate direction to mouse from player
    const direction = rl.Vector2.init(mouse_pos.x - p.position.x, mouse_pos.y - p.position.y);

    // Calculate angle to mouse (in degrees)
    var target_angle = std.math.atan2(direction.y, direction.x) * std.math.deg_per_rad;
    if (target_angle < 0)
        target_angle += 360.0;

    // Smoothly rotate toward mouse pointer
    var angle_diff = target_angle - p.rotation;

    // Handle angle wrapping
    if (angle_diff > 180)
        angle_diff -= 360;
    if (angle_diff < -180)
        angle_diff += 360;

    // Set rotation velocity based on how far we need to turn
    p.rotation_velocity = angle_diff * 0.1;

    // Cap rotation speed
    if (p.rotation_velocity > rotation_speed)
        p.rotation_velocity = rotation_speed;
    if (p.rotation_velocity < -rotation_speed)
        p.rotation_velocity = -rotation_speed;

    // Right mouse button for thrust
    p.is_thrusting = rl.isMouseButtonDown(.right);
    if (p.is_thrusting) {
        const cosA = @cos(p.rotation * std.math.rad_per_deg);
        const sinA = @sin(p.rotation * std.math.rad_per_deg);
        p.velocity.x += cosA * ship_acceleration;
        p.velocity.y += sinA * ship_acceleration;

        // Cap maximum velocity for better control
        const current_speed = @sqrt(p.velocity.x * p.velocity.x + p.velocity.y * p.velocity.y);
        if (current_speed > 5.0) {
            p.velocity.x = (p.velocity.x / current_speed) * 5.0;
            p.velocity.y = (p.velocity.y / current_speed) * 5.0;
        }
    }

    // Left mouse button for shooting
    if (rl.isMouseButtonDown(.left) and p.shoot_cooldown == 0) {
        Bullet.shootBullets(bullets, p.position, p.rotation);
        p.shoot_cooldown = bullet_cooldown;
    }
}
