const rl = @import("raylib");

pub const max_bullets = 100;
const bullet_speed = 10; // Bullet speed
const bullet_cooldown = 8; // 8 frames cooldown between shots (was 0)
const bullet_lifetime = 120; // How long bullets live for
const bullet_spread = 2.0; // Slight spread when shooting (in degrees)

pub const Bullet = struct {
    position: rl.Vector2,
    velocity: rl.Vector2,
    radius: f32,
    active: bool,
    lifeTime: f32,
    color: rl.Color, // Added color for visual variety
    alpha: f32, // Added alpha for fading effect

    pub fn init(b: []Bullet) void {
        for (0..max_bullets) |i| {
            b[i].active = false;
        }
    }
};
