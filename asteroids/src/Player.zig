const std = @import("std");
const constant = @import("constant.zig");
const Util = @import("util.zig");
const Bullet = @import("Bullet.zig");
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

const Self = @This();

pub fn init(self: *Self) void {
    // Setting up initially
    self.position = rl.Vector2.init(constant.screen_width / 2, constant.screen_height / 2);
    self.velocity = rl.Vector2.zero();
    self.rotation = 0.0;
    self.rotation_velocity = 0.0; // Add rotation velocity for smooth turning
    self.is_thrusting = false;
    self.shoot_cooldown = 0;
    self.control_mode = .keyboard; // Default to keyboard controls
}

pub fn update(self: *Self, bullets: *[max_bullets]Bullet) void {
    // Handle control mode switching
    if (rl.isKeyPressed(.m)) {
        self.control_mode = if (self.control_mode == .keyboard) .mouse else .keyboard;
    }

    if (self.control_mode == .keyboard) {
        updatePlayerKeyboard(self, bullets);
    } else {
        updatePlayerMouse(self, bullets);
    }

    // Apply velocities to position (common for both control modes)
    self.position.x += self.velocity.x;
    self.position.y += self.velocity.y;

    // Apply dampening (space drag)
    self.velocity.x *= ship_drag;
    self.velocity.y *= ship_drag;

    // Apply rotation velocity and dampening for smooth rotation
    self.rotation += self.rotation_velocity;
    self.rotation_velocity *= 0.9; // Rotation dampening

    // Keep rotation in 0-360 range for clean math
    if (self.rotation > 360)
        self.rotation -= 360;
    if (self.rotation < 0)
        self.rotation += 360;

    // Wrap position around the screen
    Util.wrapPosition(&self.position);

    // Handle shooting cooldown (common for both control modes)
    if (self.shoot_cooldown > 0) {
        self.shoot_cooldown -= 1;
    }
}

fn updatePlayerKeyboard(self: *Self, bullets: *[max_bullets]Bullet) void {
    // Smoother rotation with acceleration
    if (rl.isKeyDown(.left) or rl.isKeyDown(.a)) {
        // Add rotation acceleration with a cap
        self.rotation_velocity = @max(self.rotation_velocity - 0.3, -rotation_speed);
    } else if (rl.isKeyDown(.right) or rl.isKeyDown(.d)) {
        // Add rotation acceleration with a cap
        self.rotation_velocity = @min(self.rotation_velocity + 0.3, rotation_speed);
    } else {
        // If no keys are pressed, apply more dampening to stop rotation more quickly
        self.rotation_velocity *= 0.85;
    }

    // Handle thrusting with smoother acceleration
    self.is_thrusting = rl.isKeyDown(.up) or rl.isKeyDown(.w);
    if (self.is_thrusting) {
        // Calculate the acceleration vector based on the ship's rotation
        const cosA = @cos(self.rotation * std.math.rad_per_deg);
        const sinA = @sin(self.rotation * std.math.rad_per_deg);

        // Apply acceleration with slightly increasing force for better control
        var thrust_factor = ship_acceleration * (1.0 + 0.1 * (@abs(self.velocity.x) + @abs(self.velocity.y)) / 10.0);
        thrust_factor = @min(thrust_factor, ship_acceleration * 1.5); // Cap the boost

        self.velocity.x += cosA * thrust_factor;
        self.velocity.y += sinA * thrust_factor;

        // Cap maximum velocity for better control
        const current_speed = @sqrt(self.velocity.x * self.velocity.x + self.velocity.y * self.velocity.y);
        if (current_speed > 5.0) {
            self.velocity.x = (self.velocity.x / current_speed) * 5.0;
            self.velocity.y = (self.velocity.y / current_speed) * 5.0;
        }
    }

    // Shooting with keyboard
    if ((rl.isKeyDown(.space) or rl.isKeyPressed(.space)) and self.shoot_cooldown == 0) {
        Bullet.shootBullets(bullets, self.position, self.rotation);
        self.shoot_cooldown = bullet_cooldown;
    }
}

fn updatePlayerMouse(self: *Self, bullets: *[max_bullets]Bullet) void {
    // Get mouse position
    const mouse_pos = rl.getMousePosition();

    // Calculate direction to mouse from player
    const direction = rl.Vector2.init(mouse_pos.x - self.position.x, mouse_pos.y - self.position.y);

    // Calculate angle to mouse (in degrees)
    var target_angle = std.math.atan2(direction.y, direction.x) * std.math.deg_per_rad;
    if (target_angle < 0)
        target_angle += 360.0;

    // Smoothly rotate toward mouse pointer
    var angle_diff = target_angle - self.rotation;

    // Handle angle wrapping
    if (angle_diff > 180)
        angle_diff -= 360;
    if (angle_diff < -180)
        angle_diff += 360;

    // Set rotation velocity based on how far we need to turn
    self.rotation_velocity = angle_diff * 0.1;

    // Cap rotation speed
    if (self.rotation_velocity > rotation_speed)
        self.rotation_velocity = rotation_speed;
    if (self.rotation_velocity < -rotation_speed)
        self.rotation_velocity = -rotation_speed;

    // Right mouse button for thrust
    self.is_thrusting = rl.isMouseButtonDown(.right);
    if (self.is_thrusting) {
        const cosA = @cos(self.rotation * std.math.rad_per_deg);
        const sinA = @sin(self.rotation * std.math.rad_per_deg);
        self.velocity.x += cosA * ship_acceleration;
        self.velocity.y += sinA * ship_acceleration;

        // Cap maximum velocity for better control
        const current_speed = @sqrt(self.velocity.x * self.velocity.x + self.velocity.y * self.velocity.y);
        if (current_speed > 5.0) {
            self.velocity.x = (self.velocity.x / current_speed) * 5.0;
            self.velocity.y = (self.velocity.y / current_speed) * 5.0;
        }
    }

    // Left mouse button for shooting
    if (rl.isMouseButtonDown(.left) and self.shoot_cooldown == 0) {
        Bullet.shootBullets(bullets, self.position, self.rotation);
        self.shoot_cooldown = bullet_cooldown;
    }
}

pub fn draw(self: Self) void {
    const cos_a = @cos(self.rotation * std.math.rad_per_deg);
    const sin_a = @sin(self.rotation * std.math.rad_per_deg);

    // Draw the ship triangle
    var v1: rl.Vector2 = undefined;
    var v2: rl.Vector2 = undefined;
    var v3: rl.Vector2 = undefined;

    v1.x = self.position.x + cos_a * ship_size;
    v1.y = self.position.y + sin_a * ship_size;

    v2.x = self.position.x + @cos(self.rotation * std.math.rad_per_deg + 2.5) * ship_size * 0.7;
    v2.y = self.position.y + @sin(self.rotation * std.math.rad_per_deg + 2.5) * ship_size * 0.7;

    v3.x = self.position.x + @cos(self.rotation * std.math.rad_per_deg - 2.5) * ship_size * 0.7;
    v3.y = self.position.y + @sin(self.rotation * std.math.rad_per_deg - 2.5) * ship_size * 0.7;

    rl.drawTriangleLines(v1, v2, v3, .white);

    // Draw the thrust flame with animated size for visual feedback
    if (self.is_thrusting) {
        var thrust_pos: rl.Vector2 = undefined;
        thrust_pos.x = self.position.x - cos_a * ship_size * 0.5;
        thrust_pos.y = self.position.y - sin_a * ship_size * 0.5;

        // Animated flame length
        const flame_length = @as(f32, @floatFromInt(ship_size * rl.getRandomValue(5, 15))) / 10.0;

        rl.drawLineEx(thrust_pos, rl.Vector2.init(thrust_pos.x - cos_a * flame_length, thrust_pos.y - sin_a * flame_length), 3.0, .yellow);

        // Add a second, shorter flame line for visual effect
        rl.drawLineEx(thrust_pos, rl.Vector2.init(thrust_pos.x - cos_a * flame_length * 0.7 + sin_a * 3.0, thrust_pos.y - sin_a * flame_length * 0.7 - cos_a * 3.0), 2.0, .red);
    }

    // Indicate control mode with a small indicator
    const s = if (self.control_mode == .keyboard) "K" else "M";
    rl.drawText(s, @as(i32, @intFromFloat(self.position.x)) - 5, @as(i32, @intFromFloat(self.position.y)) - ship_size - 10, 10, .gray);
}
