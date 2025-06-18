const builtin = @import("builtin");
const std = @import("std");
const intRangeAtMost = std.Random.intRangeAtMost;

const rl = @import("raylib");

const window_title = if (builtin.mode == .Debug) "lifegame (debug)" else "lifegame";
const cell_size = 2;
const initial_cell_count = 40 * 2;
const fps = 30 / 2;
const screen_width = 480;
const screen_height = 640;
const col_size = (screen_width / cell_size + 2);
const row_size = (screen_height / cell_size + 2);
const initial_cell_color = rl.Color.black;
const initial_bg_color = rl.Color.ray_white;

const State = enum(u8) { dead = 0, alive = 1 };

const App = struct {
    board: [row_size][col_size]State = .{.{State.dead} ** col_size} ** row_size,
    board_neighbors: [row_size][col_size]u8 = .{.{0} ** col_size} ** row_size,
    rand: std.Random,
    cell_color: rl.Color = initial_cell_color,
    bg_color: rl.Color = initial_bg_color,

    fn newGame(self: *App) void {
        for (1..row_size - 1) |i| {
            for (1..col_size - 1) |j| {
                self.board[i][j] = if (1 <= j and j <= initial_cell_count) State.alive else State.dead;
            }
        }

        self.randomize();
    }

    fn draw(self: App) void {
        for (1..row_size - 1) |i| {
            for (1..col_size - 1) |j| {
                if (self.board[i][j] == State.alive) {
                    rl.drawRectangle(@intCast(cell_size * (j - 1)), @intCast(cell_size * (i - 1)), cell_size, cell_size, self.cell_color);
                }
            }
        }
    }

    fn randomize(self: *App) void {
        for (1..row_size - 1) |i| {
            std.Random.shuffle(self.rand, State, self.board[i][1 .. col_size - 1]);
        }
    }

    fn changeBgColor(self: *App) void {
        self.bg_color = .{ .r = intRangeAtMost(self.rand, u8, 0, 255), .g = intRangeAtMost(self.rand, u8, 0, 255), .b = intRangeAtMost(self.rand, u8, 0, 255), .a = 255 };
    }

    fn changeCellColor(self: *App) void {
        self.cell_color = .{ .r = intRangeAtMost(self.rand, u8, 0, 255), .g = intRangeAtMost(self.rand, u8, 0, 255), .b = intRangeAtMost(self.rand, u8, 0, 255), .a = 255 };
    }

    fn nextGeneration(self: *App) void {
        for (1..row_size - 1) |i| {
            for (1..col_size - 1) |j| {
                // top = top-left + top-middle + top-right
                const top = @intFromEnum(self.board[i - 1][j - 1]) + @intFromEnum(self.board[i - 1][j]) + @intFromEnum(self.board[i - 1][j + 1]);
                // middle = left + right
                const middle = @intFromEnum(self.board[i][j - 1]) + @intFromEnum(self.board[i][j + 1]);
                // bottom = bottom-left + bottom-middle + bottom-right
                const bottom = @intFromEnum(self.board[i + 1][j - 1]) + @intFromEnum(self.board[i + 1][j]) + @intFromEnum(self.board[i + 1][j + 1]);

                self.board_neighbors[i][j] = top + middle + bottom;
            }
        }

        for (1..row_size - 1) |i| {
            for (1..col_size - 1) |j| {
                switch (self.board_neighbors[i][j]) {
                    2 => {}, // Do nothing
                    3 => self.board[i][j] = State.alive,
                    else => self.board[i][j] = State.dead,
                }
            }
        }
    }
};

pub fn main() anyerror!void {
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });

    const rand = prng.random();

    var app = App{ .rand = rand };
    app.newGame();

    rl.initWindow(screen_width, screen_height, window_title);
    defer rl.closeWindow();

    rl.setTargetFPS(fps);

    while (!rl.windowShouldClose()) {
        if (rl.isKeyPressed(rl.KeyboardKey.r)) {
            app.newGame();
        } else if (rl.isKeyPressed(rl.KeyboardKey.b)) {
            app.changeBgColor();
        } else if (rl.isKeyPressed(rl.KeyboardKey.c)) {
            app.changeCellColor();
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(app.bg_color);
        app.draw();
        app.nextGeneration();
    }
}
