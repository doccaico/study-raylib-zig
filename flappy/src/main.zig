const builtin = @import("builtin");
const std = @import("std");

const rl = @import("raylib");

const window_title = if (builtin.mode == .Debug) "flappy (debug)" else "flappy";
const screen_width = 640;
const screen_height = 360;
const fps = 60;

const jump = -4.0;
// 壁の追加間隔
const interval = 120;
// 壁の初期X座標
const wall_start_x = 640;
// 穴のY座標の最大値
const hole_y_max = 150;
// gopherの幅
const gopher_width = 60;
// gopherの高さ
const gopher_height = 75;
// 穴のサイズ（高さ）
const hole_height = 170;
// 壁の高さ
const wall_height = 360;
// 壁の幅
const wall_width = 20;
// 重力
const gravity = 0.1;

const file_names = [_][]const u8{
    "gopher",
    "sky",
    "wall",
};

const assets_dir_name = "assets";

const suffix = "png";

const Scene = enum(u8) {
    game_title,
    game_play,
    game_over,
};

const Gopher = struct {
    x: f32,
    y: f32,
    width: i32,
    height: i32,
};

const Wall = struct {
    wall_x: i32,
    hole_y: i32,
};

const App = struct {
    allocator: std.mem.Allocator,
    gopher: Gopher = Gopher{
        .x = 200.0,
        .y = 150.0,
        .width = 60,
        .height = 75,
    },
    velocity: f32 = 0.0,
    frames: i32 = 0,
    old_score: i32 = 0,
    new_score: i32 = 0,
    score_string: [:0]u8,
    scene: Scene = .game_title,
    walls: std.ArrayList(Wall) = undefined,
    textures: std.StringHashMap(rl.Texture2D) = undefined,
    rand: std.Random,

    fn init(allocator: std.mem.Allocator, rand: std.Random) !App {
        return App{
            .allocator = allocator,
            .walls = std.ArrayList(Wall).init(allocator),
            .textures = std.StringHashMap(rl.Texture2D).init(allocator),
            .rand = rand,
            .score_string = try allocator.dupeZ(u8, "Score: 0"),
        };
    }

    fn deinit(self: *App) void {
        self.walls.deinit();

        for (file_names) |file_name| {
            const asset = self.textures.get(file_name).?;
            rl.unloadTexture(asset);
        }
        self.textures.deinit();

        self.allocator.free(self.score_string);
    }

    fn loadTextures(self: *App) !void {
        var buf: [32]u8 = undefined;
        for (file_names) |file_name| {
            const path = try std.fmt.bufPrintZ(&buf, "{s}/{s}.{s}", .{ assets_dir_name, file_name, suffix });
            const texture = try rl.loadTexture(path);
            try self.textures.put(file_name, texture);
        }
    }

    fn drawTitle(self: *App) void {
        rl.drawTexture(self.textures.get("sky").?, 0, 0, .white);
        rl.drawText("Click!", (screen_width / 2) - 40, screen_height / 2, 20, .white);
        rl.drawTexture(self.textures.get("gopher").?, @intFromFloat(self.gopher.x), @intFromFloat(self.gopher.y), .white);
        if (rl.isMouseButtonPressed(.left)) {
            self.scene = .game_play;
        }
    }

    fn drawGameOver(self: *App) !void {
        rl.drawTexture(self.textures.get("sky").?, 0, 0, .white);
        rl.drawTexture(self.textures.get("gopher").?, @intFromFloat(self.gopher.x), @intFromFloat(self.gopher.y), .white);

        for (0..self.walls.items.len) |i| {
            const wall_x = self.walls.items[i].wall_x;
            const hole_y = self.walls.items[i].hole_y;
            rl.drawTexture(self.textures.get("wall").?, wall_x, hole_y - wall_height, .white);
            rl.drawTexture(self.textures.get("wall").?, wall_x, hole_y + hole_height, .white);
        }
        rl.drawText("Game Over", (screen_width / 2) - 60, (screen_height / 2) - 60, 20, .white);

        self.allocator.free(self.score_string);
        self.score_string = try std.fmt.allocPrintZ(self.allocator, "Score: {d}", .{self.new_score});
        rl.drawText(self.score_string, (screen_width / 2) - 60, (screen_height / 2) - 40, 20, .white);

        if (rl.isMouseButtonPressed(.left)) {
            try self.reset();
        }
    }

    fn drawGame(self: *App) !void {
        if (rl.isMouseButtonPressed(.left)) {
            self.velocity = jump;
        }
        self.velocity += gravity;
        self.gopher.y += self.velocity;

        self.frames += 1;
        if (@mod(self.frames, interval) == 0) {
            const min = 0;
            const max = hole_y_max - 1;
            const rand_num = std.Random.intRangeAtMost(self.rand, i32, min, max);
            // int rand_num = rand() % (max - min + 1) + min;
            try self.walls.append(.{ .wall_x = wall_start_x, .hole_y = rand_num });
            // YacDynamicArrayAppend(&self.walls, ((Wall){.wall_x = WALL_START_X, .hole_y = rand_num}));
        }

        // wallを左へ移動
        for (0..self.walls.items.len) |i| {
            self.walls.items[i].wall_x -= 2;
        }

        // スコアを計算
        for (0..self.walls.items.len) |i| {
            if (@as(f32, @floatFromInt(self.walls.items[i].wall_x)) < self.gopher.x) {
                self.new_score = @as(i32, @intCast(i)) + 1;
            }
        }
        // スコアの文字列を生成
        if (self.new_score != self.old_score) {
            self.allocator.free(self.score_string);
            self.score_string = try std.fmt.allocPrintZ(self.allocator, "Score: {d}", .{self.new_score});
            self.old_score = self.new_score;
        }

        rl.drawTexture(self.textures.get("sky").?, 0, 0, .white);
        rl.drawTexture(self.textures.get("gopher").?, @intFromFloat(self.gopher.x), @intFromFloat(self.gopher.y), .white);

        for (0..self.walls.items.len) |i| {
            const wall_x = self.walls.items[i].wall_x;
            const hole_y = self.walls.items[i].hole_y;
            const x = self.gopher.x;
            const y = self.gopher.y;

            // 上の壁の描画
            rl.drawTexture(self.textures.get("wall").?, wall_x, hole_y - wall_height, .white);
            // 下の壁の描画
            rl.drawTexture(self.textures.get("wall").?, wall_x, hole_y + hole_height, .white);

            // gopherを表す四角形を作る
            const g_left = @as(i32, @intFromFloat(x));
            const g_top = @as(i32, @intFromFloat(y));
            const g_right = @as(i32, @intFromFloat(x)) + gopher_width;
            const g_bottom = @as(i32, @intFromFloat(y)) + gopher_height;

            // 上の壁を表す四角形を作る
            var w_left = wall_x;
            var w_top = hole_y - wall_height;
            var w_right = wall_x + wall_width;
            var w_bottom = hole_y;

            // 上の壁との当たり判定
            if (g_left < w_right and w_left < g_right and g_top < w_bottom and w_top < g_bottom) {
                self.scene = .game_over;
            }

            // 下の壁を表す四角形を作る
            w_left = wall_x;
            w_top = hole_y + hole_height;
            w_right = wall_x + wall_width;
            w_bottom = hole_y + hole_height + wall_height;

            // 下の壁との当たり判定
            if (g_left < w_right and w_left < g_right and g_top < w_bottom and w_top < g_bottom) {
                self.scene = .game_over;
            }
        }

        // スコアを描画
        rl.drawText(self.score_string, 10, 10, 20, .red);

        // 上の壁との当たり判定
        if (self.gopher.y < 0) {
            self.scene = .game_over;
        }
        // 地面との当たり判定
        if (360 - gopher_height < self.gopher.y) {
            self.scene = .game_over;
        }
    }

    fn reset(self: *App) !void {
        self.walls.clearRetainingCapacity();
        self.gopher = Gopher{
            .x = 200.0,
            .y = 150.0,
            .width = 60,
            .height = 75,
        };
        self.velocity = 0.0;
        self.frames = 0;
        self.old_score = 0;
        self.new_score = 0;
        self.allocator.free(self.score_string);
        self.score_string = try self.allocator.dupeZ(u8, "Score: 0");
        self.scene = .game_title;
    }
};

pub fn main() anyerror!void {
    rl.initWindow(screen_width, screen_height, window_title);
    defer rl.closeWindow();

    rl.setTargetFPS(fps);

    var gpa: std.heap.DebugAllocator(.{}) = .init;
    const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

    defer if (builtin.mode == .Debug) {
        _ = gpa.deinit();
    };

    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });

    const rand = prng.random();

    var app = try App.init(allocator, rand);
    defer app.deinit();

    try app.loadTextures();

    const render_texture = try rl.loadRenderTexture(screen_width, screen_height);
    defer rl.unloadRenderTexture(render_texture);

    while (!rl.windowShouldClose()) {
        rl.beginTextureMode(render_texture);
        {
            switch (app.scene) {
                .game_title => app.drawTitle(),
                .game_play => try app.drawGame(),
                .game_over => try app.drawGameOver(),
            }
        }
        rl.endTextureMode();

        rl.beginDrawing();
        {
            const w: f32 = @floatFromInt(render_texture.texture.width);
            const h: f32 = @floatFromInt(render_texture.texture.height);
            var source = rl.Rectangle{ .x = 0, .y = 0, .width = w, .height = h };
            const dest = source;
            source.height = -source.height;
            rl.drawTexturePro(render_texture.texture, source, dest, (rl.Vector2){ .x = 0.0, .y = 0.0 }, 0, .white);
        }
        rl.endDrawing();
    }
}
