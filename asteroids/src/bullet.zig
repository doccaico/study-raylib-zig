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
    life_time: f32,
    color: rl.Color, // Added color for visual variety
    alpha: f32, // Added alpha for fading effect

    pub fn init(b: []Bullet) void {
        for (0..max_bullets) |i| {
            b[i].active = false;
        }
    }

    pub fn shootBullets(b :*[max_bullets]bullets, position : rl.Vector2 , rotation: f32) void
    {
        // We'll shoot 3 bullets with a slight spread for a more interesting effect
        var spread: isize = -1;
        while (spread <= 1) : (spread  += 1) {
            // Find an inactive bullet to use
            for (0..max_bullets) |i| {
            {
                if(!b[i].active)
                {
                    // Get the actual rotation with spread
                    const bullet_rotation = rotation + spread * bullet_spread;

                    // Calculate velocity based on spread-adjusted rotation
                    const cosA = @cos(bullet_rotation * std.math.rad_per_deg);
                    const sinA = @sin(bullet_rotation * std.math.rad_per_deg);

                    b[i].position = position;
                    b[i].velocity.x = cosA * bullet_speed;
                    b[i].velocity.y = sinA * bullet_speed;
                    b[i].radius = 3 + @abs(spread) * 0.5; // Slightly different sizes
                    b[i].life_time = bullet_lifetime - @abs(spread) * 10; // Center bullet lasts longer
                    b[i].active = true;
                    b[i].alpha = 1.0;

                    // Set different colors for visual interest
                    if (spread == 0) {
                        b[i].color = rl.Color.init( 255, 255, 255, 255 ); // White for center
                    } else if (spread == -1) {
                        b[i].color = rl.Color.init( 0, 200, 255, 255 );   // Blue-ish
                    } else {
                        b[i].color = rl.Color.init( 255, 200, 0, 255 );   // Yellow-ish
                    }

                    break; // We found an inactive bullet to use, so break the inner loop
                }
            }
        }
    }

};
