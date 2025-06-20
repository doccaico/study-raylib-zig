const config = @import("config.zig");

const rl = @import("raylib");

const ship_size = 20;
const ship_acceleration = 0.15; // Changed the ship acceleration (v1.0 -> 0.1f value) to 0.15f
const rotation_speed = 4.0; // Changed the rot speed (v1.0 -> 3,0f) to 4.0f
const ship_drag = 0.97; // Decided to add the necessary drag changes as well

const ControlMode = enum { keyboard, mouse };

// Player ship structure
pub const Player = struct {
    position: rl.Vector2,
    velocity: rl.Vector2,
    rotation: f32,
    rotation_velocity: f32, // Added for smoother rotation
    is_thrusting: bool,
    shoot_cooldown: i32,
    control_mode: ControlMode, // 0 = keyboard, 1 = mouse

    pub fn init(p: *Player) void {
        // Setting up initially
        p.position = rl.Vector2.init(config.screen_width / 2, config.screen_height / 2);
        p.velocity = rl.Vector2.zero();
        p.rotation = 0.0;
        p.rotation_velocity = 0.0; // Add rotation velocity for smooth turning
        p.is_thrusting = false;
        p.shoot_cooldown = 0;
        p.control_mode = .keyboard; // Default to keyboard controls
    }
};
