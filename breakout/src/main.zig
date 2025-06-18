const builtin = @import("builtin");
const std = @import("std");

const rl = @import("raylib");

const window_title = if (builtin.mode == .Debug) "breakout (debug)" else "breakout";
const screen_width = 800;
const screen_height = 600;
const fps = 60;

const paddle_width = 100;
const paddle_height = 20;
const paddle_speed = 6.0;
const ball_size = 10;
const brick_rows = 5;
const brick_cols = 10;
const brick_spacing = 5;
const brick_width = (screen_width - (brick_cols + 1) * brick_spacing) / brick_cols;
const brick_height = 20;

const Brick = struct {
    rect: rl.Rectangle,
    active: bool,
};

const App = struct {
    allocator: std.mem.Allocator,
    bricks: std.ArrayList(Brick),
    paddle_pos: rl.Rectangle = rl.Rectangle.init(screen_width / 2 - paddle_width / 2, screen_height - 40, paddle_width, paddle_height),
    ball_pos: rl.Vector2 = rl.Vector2.init(screen_width / 2.0, screen_height / 2.0),
    ball_vel: rl.Vector2 = rl.Vector2.init(4.0, -4.0),
    game_over: bool = false,
    win: bool = false,

    fn init(allocator: std.mem.Allocator) !App {
        var app = App{
            .allocator = allocator,
            .bricks = std.ArrayList(Brick).init(allocator),
        };

        try app.prepareBricks();

        return app;
    }

    fn deinit(self: *App) void {
        self.bricks.deinit();
    }

    fn prepareBricks(self: *App) !void {
        for (0..brick_rows) |i| {
            for (0..brick_cols) |j| {
                var brick = Brick{
                    .rect = rl.Rectangle.init(0, 0, 0, 0),
                    .active = true,
                };
                brick.rect.x = @floatFromInt(brick_spacing + j * (brick_width + brick_spacing));
                brick.rect.y = @floatFromInt(brick_spacing + i * (brick_height + brick_spacing));
                brick.rect.width = brick_width;
                brick.rect.height = brick_height;

                try self.bricks.append(brick);
            }
        }
    }

    fn checkCollision(self: *App) void {
        // Wall collision
        if (self.ball_pos.x <= 0 or self.ball_pos.x >= screen_width - ball_size)
            self.ball_vel.x *= -1;
        if (self.ball_pos.y <= 0)
            self.ball_vel.y *= -1;

        // Bottom (game over)
        if (self.ball_pos.y >= screen_height) {
            self.game_over = true;
            self.win = false;
        }

        // Paddle collision
        const ball_rect = rl.Rectangle.init(self.ball_pos.x, self.ball_pos.y, ball_size, ball_size);
        if (rl.checkCollisionRecs(ball_rect, self.paddle_pos)) {
            self.ball_vel.y *= -1;
            self.ball_pos.y = self.paddle_pos.y - ball_size;
        }

        // Brick collision
        for (self.bricks.items) |*brick| {
            if (brick.active and rl.checkCollisionRecs(ball_rect, brick.rect)) {
                brick.active = false;
                self.ball_vel.y *= -1;
                break;
            }
        }
    }

    fn checkWin(self: *App) void {
        self.win = true;
        for (self.bricks.items) |brick| {
            if (brick.active) {
                self.win = false;
                break;
            }
        }
        if (self.win) self.game_over = true;
    }

    fn showMessage(self: App) void {
        const msg = if (self.win) "YOU WIN!" else "GAME OVER";
        rl.drawText(msg, screen_width / 2 - @divTrunc(rl.measureText(msg, 40), 2), screen_height / 2, 40, .red);
        rl.drawText("Press R to Restart", screen_width / 2 - 100, screen_height / 2 + 50, 20, .dark_gray);
    }

    fn reset(self: *App) !void {
        self.ball_pos = rl.Vector2.init(screen_width / 2.0, screen_height / 2.0);
        self.ball_vel = rl.Vector2.init(4.0, -4.0);
        self.paddle_pos.x = screen_width / 2 - paddle_width / 2;
        self.bricks.clearAndFree();
        try self.prepareBricks();
        self.game_over = false;
        self.win = false;
    }
};

pub fn main() !void {
    rl.initWindow(screen_width, screen_height, window_title);
    defer rl.closeWindow();

    rl.setTargetFPS(fps);

    var gpa: std.heap.DebugAllocator(.{}) = .init;
    const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

    defer if (builtin.mode == .Debug) {
        _ = gpa.deinit();
    };

    var app = try App.init(allocator);
    defer app.deinit();

    while (!rl.windowShouldClose()) {
        // Input
        if (rl.isKeyDown(.left) and app.paddle_pos.x > 0)
            app.paddle_pos.x -= paddle_speed;
        if (rl.isKeyDown(.right) and app.paddle_pos.x + app.paddle_pos.width < screen_width)
            app.paddle_pos.x += paddle_speed;

        if (!app.game_over) {
            // Ball Movement
            app.ball_pos.x += app.ball_vel.x;
            app.ball_pos.y += app.ball_vel.y;

            app.checkCollision();

            app.checkWin();
        }

        // Drawing
        rl.beginDrawing();
        {
            rl.clearBackground(.ray_white);

            // Draw paddle
            rl.drawRectangleRec(app.paddle_pos, .dark_gray);

            // Draw ball
            rl.drawRectangleRec(rl.Rectangle.init(app.ball_pos.x, app.ball_pos.y, ball_size, ball_size), .maroon);

            // Draw bricks
            for (app.bricks.items) |brick| {
                if (brick.active) {
                    rl.drawRectangleRec(brick.rect, .blue);
                }
            }

            // Messages
            if (app.game_over) {
                app.showMessage();
                if (rl.isKeyPressed(.r)) try app.reset();
            }
        }
        rl.endDrawing();
    }
}
