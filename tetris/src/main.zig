const builtin = @import("builtin");
const std = @import("std");

const rl = @import("raylib");

const window_title = if (builtin.mode == .Debug) "tetris (debug)" else "tetris";
const fps = 60;

// Sizings
const cell_size = 25;
const cells_x = 10;
const cells_y = 20;
const gride_width = cell_size * cells_x;
const gride_height = cell_size * cells_y;
const sidebar_width = (cell_size * 4) + 20;
const screen_width = gride_width + sidebar_width;
const screen_height = gride_height;

// Colors
const grid_color = rl.Color.init(50, 50, 50, 255);

const i_piece_color = rl.Color.init(0, 255, 255, 255);
const j_piece_color = rl.Color.init(0, 0, 255, 255);
const l_piece_color = rl.Color.init(255, 165, 0, 255);
const o_piece_color = rl.Color.init(255, 255, 0, 255);
const t_piece_color = rl.Color.init(128, 0, 128, 255);
const s_piece_color = rl.Color.init(0, 255, 0, 255);
const z_piece_color = rl.Color.init(255, 0, 0, 255);

// Game settings
const drop_speed = 30; // Every X frames, drop minos by 1 cell
const sped_up_drop_speed = 2;
const level_up_speed_increase = 0.85;
const piece_statification_delay = 30;

// Backend game settings
const piece_lookahead = 3;
const max_piece_queue = 20;
const das_delay = 10; // Delay before auto-shift starts (in frames)
const arr_rate = 2; // Frames between auto-shift after DAS start

// Pieces
const PieceType = enum {
    i,
    j,
    l,
    o,
    t,
    s,
    z,
};

const GridPos = struct {
    x: isize,
    y: isize,
};

const Mino = struct {
    color: rl.Color,
    is_dynamic: bool,
};

const MinoPos = struct {
    mino: ?*Mino,
    pos: GridPos,
};

const InputState = struct {
    right_pressed_last_frame: bool = false, // move right
    left_pressed_last_frame: bool = false, // move left
    down_pressed_last_frame: bool = false, // drop faster
    up_pressed_last_frame: bool = false, // rotate
    space_pressed_last_frame: bool = false, // hard drop
    a_pressed_last_frame: bool = false, // rotate left
    d_pressed_last_frame: bool = false, // rotate right
    shift_pressed_last_frame: bool = false, // rotate right
};

const App = struct {
    allocator: std.mem.Allocator,
    grid: std.ArrayList(std.ArrayList(?*Mino)), // origin is top-left
    upcoming_pieces: std.ArrayList(PieceType),
    bag: std.ArrayList(PieceType),
    held_piece: ?*PieceType = null,
    current_piece: PieceType = undefined,
    next_update: usize = drop_speed,
    input_state: InputState = InputState{},
    pivot: GridPos = undefined,
    last_movement_update: usize = 0,
    right_key_hold_time: isize = 0,
    left_key_hold_time: isize = 0,
    level: usize = 0,
    score: usize = 0,
    lines_cleared: usize = 0,
    speed: f32 = 1.0,
    rand: std.Random,

    fn init(allocator: std.mem.Allocator, rand: std.Random) !App {
        var grid = try std.ArrayList(std.ArrayList(?*Mino)).initCapacity(allocator, cells_y);

        for (0..cells_y) |_| {
            const minos = try std.ArrayList(?*Mino).initCapacity(allocator, cells_x);
            try grid.append(minos);
        }

        for (0..cells_y) |i| {
            for (0..cells_x) |_| {
                try grid.items[i].append(null);
            }
        }

        const upcoming_pieces = try std.ArrayList(PieceType).initCapacity(allocator, max_piece_queue);

        var app = App{
            .allocator = allocator,
            .grid = grid,
            .upcoming_pieces = upcoming_pieces,
            .bag = std.ArrayList(PieceType).init(allocator),
            .rand = rand,
        };

        for (0..max_piece_queue) |_| {
            try app.upcoming_pieces.append(try app.pickNewPiece());
        }

        return app;
    }

    fn deinit(self: *App) void {
        // for (self.grid.items) |*item| {
        //     item.deinit();
        // }

        // for (0..self.grid.items.len) |i| {
        //     for (0..self.grid.items[i].items.len) |j| {
        //         if (self.grid.items[i].items[j]) |item| {
        //             self.allocator.destroy(item);
        //         }
        //     }
        //     self.grid.items[i].deinit();
        // }
        // self.grid.deinit();

        for (0..self.grid.items.len) |i| {
            self.grid.items[i].deinit();
        }
        self.grid.deinit();

        self.upcoming_pieces.deinit();

        self.bag.deinit();
    }

    fn pickNewPiece(self: *App) !PieceType {
        if (self.bag.items.len == 0) try self.fillBag();
        const piece_index = std.Random.intRangeAtMost(self.rand, usize, 0, self.bag.items.len - 1);
        const piece = self.bag.items[piece_index];
        _ = self.bag.orderedRemove(piece_index);
        return piece;
    }

    fn fillBag(self: *App) !void {
        for (0..std.meta.fields(PieceType).len) |i| {
            const piece: PieceType = @enumFromInt(i);
            try self.bag.append(piece);
        }
    }

    fn rotateDynamicMinos(self: *App, clockwise: bool) !bool {
        var mino_positions = std.ArrayList(MinoPos).init(self.allocator);
        defer mino_positions.deinit();
        var new_mino_positions = std.ArrayList(MinoPos).init(self.allocator);
        defer new_mino_positions.deinit();

        // 1. Get a vector of all dynamic minos
        for (0..self.grid.items.len) |i| {
            for (0..self.grid.items[i].items.len) |j| {
                const mino = self.grid.items[i].items[j];
                if (self.grid.items[i].items[j] == null or mino == null or !mino.?.is_dynamic)
                    continue;
                const mino_pos = MinoPos{ .mino = mino, .pos = GridPos{ .x = @intCast(j), .y = @intCast(i) } };
                try mino_positions.append(mino_pos);
            }
        }
        if (mino_positions.items.len == 0)
            return false;

        // 2. Check if minos can rotate
        for (0..mino_positions.items.len) |i| {
            const new_pos = self.getRotationAroundPivot(mino_positions.items[i].pos, clockwise);
            if (new_pos.x < 0 or new_pos.x >= self.grid.items[0].items.len or new_pos.y < 0 or new_pos.y >= self.grid.items.len)
                return false;
            if (self.grid.items[@intCast(new_pos.y)].items[@intCast(new_pos.x)] != null and !self.grid.items[@intCast(new_pos.y)].items[@intCast(new_pos.x)].?.is_dynamic)
                return false;
            try new_mino_positions.append(MinoPos{ .mino = mino_positions.items[i].mino, .pos = new_pos });
        }

        // 3. Rotate minos
        for (0..mino_positions.items.len) |i| {
            const j: usize = @intCast(mino_positions.items[i].pos.y);
            const k: usize = @intCast(mino_positions.items[i].pos.x);
            self.grid.items[j].items[k] = null;
        }
        for (0..new_mino_positions.items.len) |i| {
            const j: usize = @intCast(new_mino_positions.items[i].pos.y);
            const k: usize = @intCast(new_mino_positions.items[i].pos.x);
            self.grid.items[j].items[k] = new_mino_positions.items[i].mino;
        }

        if (!(new_mino_positions.items.len == 0))
            self.last_movement_update = 0;

        const ret = !(new_mino_positions.items.len == 0);

        mino_positions.deinit();
        new_mino_positions.deinit();

        return ret;
    }

    fn getRotationAroundPivot(self: *App, pos: GridPos, clockwise: bool) GridPos {
        const rel_x: isize = @intCast(pos.x - self.pivot.x);
        const rel_y: isize = @intCast(pos.y - self.pivot.y);

        var new_rel_x: isize = undefined;
        var new_rel_y: isize = undefined;

        if (clockwise) {
            new_rel_x = rel_y;
            new_rel_y = -rel_x;
        } else {
            new_rel_x = -rel_y;
            new_rel_y = rel_x;
        }

        return GridPos{
            .x = new_rel_x + self.pivot.x,
            .y = new_rel_y + self.pivot.y,
        };
    }

    fn update(self: *App) !bool {
        // TODO (BUG?)
        self.next_update -= 1;
        self.last_movement_update += 1;

        //
        // Input handling
        //

        // KEY_RIGHT
        if (rl.isKeyDown(.right)) {
            if (!self.input_state.right_pressed_last_frame) {
                _ = self.moveDynamicMinos(1, 0);
                self.right_key_hold_time = 0;
            } else {
                self.right_key_hold_time += 1;
                if (self.right_key_hold_time >= das_delay and @mod((self.right_key_hold_time - das_delay), arr_rate) == 0)
                    _ = self.moveDynamicMinos(1, 0);
            }
        } else {
            self.right_key_hold_time = 0;
        }

        // KEY_LEFT
        if (rl.isKeyDown(.left)) {
            if (!self.input_state.left_pressed_last_frame) {
                _ = self.moveDynamicMinos(-1, 0);
                self.left_key_hold_time = 0;
            } else {
                self.left_key_hold_time += 1;
                if (self.left_key_hold_time >= das_delay and @mod((self.left_key_hold_time - das_delay), arr_rate) == 0)
                    _ = self.moveDynamicMinos(-1, 0);
            }
        } else {
            self.left_key_hold_time = 0;
        }

        // KEY_DOWN
        if (rl.isKeyDown(.down) and !self.input_state.down_pressed_last_frame)
            self.next_update = 0;

        // KEY_SPACE
        if (!rl.isKeyDown(.space) and self.input_state.space_pressed_last_frame) {
            while (self.moveDynamicMinos(0, 1)) {}
            self.last_movement_update = piece_statification_delay;
        }

        // KEY_UP
        if (!rl.isKeyDown(.up) and self.input_state.up_pressed_last_frame)
            _ = try self.rotateDynamicMinos(false);

        // KEY_A
        if (!rl.isKeyDown(.a) and self.input_state.a_pressed_last_frame)
            _ = try self.rotateDynamicMinos(false);

        // KEY_D
        if (!rl.isKeyDown(.d) and self.input_state.d_pressed_last_frame)
            _ = try self.rotateDynamicMinos(true);

        // KEY_LEFT_SHIFT
        if (!rl.isKeyDown(.left_shift) and self.input_state.shift_pressed_last_frame)
            try self.holdPiece();

        self.input_state.right_pressed_last_frame = rl.isKeyDown(.right);
        self.input_state.left_pressed_last_frame = rl.isKeyDown(.left);
        self.input_state.down_pressed_last_frame = rl.isKeyDown(.down);
        self.input_state.up_pressed_last_frame = rl.isKeyDown(.up);
        self.input_state.space_pressed_last_frame = rl.isKeyDown(.space);
        self.input_state.a_pressed_last_frame = rl.isKeyDown(.a);
        self.input_state.d_pressed_last_frame = rl.isKeyDown(.d);
        self.input_state.shift_pressed_last_frame = rl.isKeyDown(.left_shift);

        // Update grid state
        if (self.next_update == 0) {
            self.next_update = drop_speed * @as(usize, @intFromFloat(self.speed));
            if (self.input_state.down_pressed_last_frame and self.next_update > sped_up_drop_speed)
                self.next_update = sped_up_drop_speed;

            var mid_air = true;
            for (0..self.grid.items.len) |i| {
                for (0..self.grid.items[i].items.len) |j| {
                    if (self.grid.items[i].items[j] == null)
                        continue;
                    const mino = self.grid.items[i].items[j];
                    if (mino == null or !mino.?.is_dynamic)
                        continue;
                    if (i + 1 < self.grid.items.len and self.grid.items[i + 1].items[j] != null) {
                        const mino_goal = self.grid.items[i + 1].items[j];
                        if (mino_goal == null or !mino_goal.?.is_dynamic)
                            mid_air = false;
                    } else if (i + 1 == self.grid.items.len)
                        mid_air = false;
                }
            }
            if (self.last_movement_update < piece_statification_delay and !mid_air)
                return true;

            // TODO (BUG?)
            // Make minos static
            if (!self.moveDynamicMinos(0, 1)) {
                for (0..self.grid.items.len) |i| {
                    for (0..self.grid.items[i].items.len) |j| {
                        if (self.grid.items[i].items[j] == null)
                            continue;
                        const mino = self.grid.items[i].items[j];
                        if (mino == null or !mino.?.is_dynamic)
                            continue;
                        self.grid.items[i].items[j].?.is_dynamic = false;
                    }
                }

                // Check for full rows
                var cleared_rows: usize = 0;
                for (0..self.grid.items.len) |i| {
                    var row_full = true;
                    for (0..self.grid.items[i].items.len) |j| {
                        if (self.grid.items[i].items[j] == null) {
                            row_full = false;
                            break;
                        }
                    }
                    if (row_full) {
                        cleared_rows += 1;
                        for (0..self.grid.items[i].items.len) |j| {
                            // After TODO
                            // free(self.grid.items[i].items[j]);
                            self.allocator.destroy(self.grid.items[i].items[j].?);
                            self.grid.items[i].items[j] = null;
                        }
                        // for (size_t k = i; k != 0; --k) {
                        var k = i;
                        while (k != 0) : (k -= 1) {
                            for (0..self.grid.items[k].items.len) |j| {
                                self.grid.items[k].items[j] = self.grid.items[k - 1].items[j];
                                self.grid.items[k - 1].items[j] = null;
                            }
                        }
                    }
                }
                self.lines_cleared += cleared_rows;
                const prev_level = self.level;
                self.level = self.lines_cleared / 10;
                if (self.level != prev_level)
                    self.speed *= level_up_speed_increase;
                if (cleared_rows > 0) {
                    switch (cleared_rows) {
                        1 => {
                            self.score += 40 * (self.level + 1);
                        },
                        2 => {
                            self.score += 100 * (self.level + 1);
                        },
                        3 => {
                            self.score += 300 * (self.level + 1);
                        },
                        4 => {
                            self.score += 1200 * (self.level + 1);
                        },
                        else => {
                            std.debug.print("What? How did you clear something other than 0-4 rows?", .{});
                        },
                    }
                }

                // Then, spawn in a new piece
                if (!try self.spawnNewTetromino())
                    return false;
            }
        }
        return true;
    }

    fn draw(self: *App) !void {
        // Draw grid
        for (0..cells_x) |i| {
            for (0..cells_y) |j| {
                const x = @as(i32, @intCast(i)) * cell_size;
                const y = @as(i32, @intCast(j)) * cell_size;
                rl.drawRectangleLines(x, y, cell_size, cell_size, grid_color);
            }
        }

        // Draw minos
        for (0..self.grid.items.len) |i| {
            for (0..self.grid.items[i].items.len) |j| {
                if (self.grid.items[i].items[j] != null)
                    rl.drawRectangle(@as(i32, @intCast(j)) * cell_size, @as(i32, @intCast(i)) * cell_size, cell_size, cell_size, self.grid.items[i].items[j].?.color);
            }
        }

        // Draw progress
        var buf: [32]u8 = undefined;
        const left_offset = self.grid.items[0].items.len * cell_size + 5;
        {
            const s = try std.fmt.bufPrintZ(&buf, "LVL {d}", .{self.level});
            rl.drawText(s, @intCast(left_offset), 20, 15, .white);
        }
        {
            const s = try std.fmt.bufPrintZ(&buf, "SCR {d}", .{self.score});
            rl.drawText(s, @intCast(left_offset), 35, 15, .white);
        }
        {
            const s = try std.fmt.bufPrintZ(&buf, "LNS {d}", .{self.lines_cleared});
            rl.drawText(s, @intCast(left_offset), 50, 15, .white);
        }

        // Draw upcoming pieces
        const margin = 10;
        const piece_size = 4 * cell_size;
        for (0..piece_lookahead) |i| {
            var pos: GridPos = undefined;
            const pieces = try self.getPiece(self.upcoming_pieces.items[i], &pos);
            for (0..pieces.items.len) |j| {
                if (pieces.items[j] == null)
                    continue;
                const x = self.grid.items[0].items.len * cell_size + margin + (j % 4) * cell_size;
                const y = (margin + (i * piece_size) + (j / 4) * cell_size + (piece_size * 2));
                rl.drawRectangle(@intCast(x), @intCast(y), cell_size, cell_size, pieces.items[j].?.color);
            }

            for (0..pieces.items.len) |k| {
                if (pieces.items[k]) |item| {
                    // self.allocator.destroy(pieces.items[j].?);
                    self.allocator.destroy(item);
                }
            }
            // YacDynamicArrayClearAndFree(pieces);
            pieces.deinit();
        }
    }

    fn moveDynamicMinos(self: *App, right: isize, down: isize) bool {
        var change_occurred = false;

        // 1. Move horizontally
        if (right != 0) {
            // Check if minos can move
            var dynamic_minos_movable = true;
            var dynamic_minos_present = false;

            for (self.grid.items) |item_i| {
                for (item_i.items, 0..) |item_j, j| {
                    const mino = item_j;
                    const j_isize = @as(isize, @intCast(j));
                    if (mino == null or !mino.?.is_dynamic)
                        continue;
                    dynamic_minos_present = true;
                    if (j_isize + right < 0 or j_isize + right >= item_i.items.len) {
                        dynamic_minos_movable = false;
                        break;
                    }
                    if (item_i.items[@as(usize, @intCast(j_isize + right))] == null)
                        continue;
                    const mino_goal = item_j;
                    if (!mino_goal.?.is_dynamic) {
                        dynamic_minos_movable = false;
                        break;
                    }
                }
                if (!dynamic_minos_movable)
                    break;
            }

            // Move minos
            const start: isize = if (right > 0) @as(isize, @intCast(self.grid.items[0].items.len)) - 1 else 0;
            const end: isize = if (right > 0) -1 else @intCast(self.grid.items[0].items.len);
            const step: isize = if (right > 0) -1 else 1;
            if (dynamic_minos_movable and dynamic_minos_present) {
                self.pivot.x += right;
                for (0..self.grid.items.len) |i| {
                    var j = start;
                    while (j != end) : (j += step) {
                        if (self.grid.items[i].items[@intCast(j)] == null)
                            continue;
                        const mino = self.grid.items[i].items[@intCast(j)];
                        if (!mino.?.is_dynamic)
                            continue;
                        if (self.grid.items[i].items[@intCast(j + right)] == null) {
                            self.grid.items[i].items[@intCast(j + right)] = self.grid.items[i].items[@intCast(j)];
                            self.grid.items[i].items[@intCast(j)] = null;
                            change_occurred = true;
                        }
                    }
                }
            }
        }

        // 2. Move vertically
        if (down != 0) {
            // Check if minos can move
            var dynamic_minos_movable = true;
            var dynamic_minos_present = false;
            for (0..self.grid.items.len) |i| {
                const i_isize = @as(isize, @intCast(i));
                for (0..self.grid.items[i].items.len) |j| {
                    const mino = self.grid.items[i].items[j];
                    if (self.grid.items[i].items[j] == null or mino == null or !mino.?.is_dynamic)
                        continue;
                    dynamic_minos_present = true;
                    if (i_isize + down < 0 or i_isize + down >= self.grid.items.len) {
                        dynamic_minos_movable = false;
                        break;
                    }
                    if (self.grid.items[@as(usize, @intCast(i_isize)) + @as(usize, @intCast(down))].items[j] == null)
                        continue;
                    const mino_goal = self.grid.items[@as(usize, @intCast(i_isize)) + @as(usize, @intCast(down))].items[j];
                    if (!mino_goal.?.is_dynamic) {
                        dynamic_minos_movable = false;
                        break;
                    }
                }
                if (!dynamic_minos_movable)
                    break;
            }

            // Move minos
            const start: isize = if (down > 0) @as(isize, @intCast(self.grid.items.len)) - 1 else 0;
            const end: isize = if (down > 0) -1 else @intCast(self.grid.items.len);
            const step: isize = if (down > 0) -1 else 1;
            if (dynamic_minos_movable and dynamic_minos_present) {
                self.pivot.y += down;
                var i = start;
                const i_usize = @as(usize, @intCast(i));
                while (i != end) : (i += step) {
                    for (0..self.grid.items[i_usize].items.len) |j| {
                        if (self.grid.items[i_usize].items[j] == null)
                            continue;
                        const mino = self.grid.items[i_usize].items[j];
                        if (mino == null or !mino.?.is_dynamic)
                            continue;
                        if (self.grid.items[i_usize + @as(usize, @intCast(down))].items[j] == null) {
                            self.grid.items[i_usize + @as(usize, @intCast(down))].items[j] = self.grid.items[i_usize].items[j];
                            self.grid.items[i_usize].items[j] = null;
                            change_occurred = true;
                        }
                    }
                }
            }
        }
        if (change_occurred)
            self.last_movement_update = 0;

        return change_occurred;
    }

    fn holdPiece(self: *App) !void {
        if (self.held_piece) |hp| {
            const next_piece = hp.*;

            self.allocator.destroy(hp);

            const pt = try self.allocator.create(PieceType);
            pt.* = self.current_piece;
            self.held_piece = pt;

            _ = self.deleteDynamicMinos();
            try self.upcoming_pieces.insert(0, next_piece);
            _ = try self.spawnNewTetromino();
        } else {
            const pt = try self.allocator.create(PieceType);
            pt.* = self.current_piece;
            self.held_piece = pt;

            _ = self.deleteDynamicMinos();
            _ = try self.spawnNewTetromino();
        }
    }

    fn deleteDynamicMinos(self: *App) bool {
        var change_occurred = false;

        for (0..self.grid.items.len) |i| {
            for (0..self.grid.items[i].items.len) |j| {
                if (self.grid.items[i].items[j] == null)
                    continue;
                const mino = self.grid.items[i].items[j];
                if (mino == null or !mino.?.is_dynamic)
                    continue;
                // free(self.grid.items[i].items[j]);
                // self.grid.items[i].items[j] = NULL;
                self.allocator.destroy(self.grid.items[i].items[j].?);
                self.grid.items[i].items[j] = null;
                change_occurred = true;
            }
        }
        return change_occurred;
    }

    fn spawnNewTetromino(self: *App) !bool {
        const pt = self.upcoming_pieces.items[0];
        _ = self.upcoming_pieces.orderedRemove(0);
        if (self.upcoming_pieces.items.len < piece_lookahead) {
            var i = self.upcoming_pieces.items.len;
            while (i < piece_lookahead) : (i += 1) {
                try self.upcoming_pieces.append(try self.pickNewPiece());
            }
        }
        self.current_piece = pt;

        const pieces = try self.getPiece(pt, &self.pivot);
        const spawning_offset = (cells_x - 4) / 2;

        self.pivot.x += spawning_offset;
        for (0..pieces.items.len) |i| {
            if (pieces.items[i] == null)
                continue;
            if (self.grid.items[i / 4].items[(i % 4) + spawning_offset] != null) {
                std.debug.print(" ---------------- ", .{});
                std.debug.print(" -- Game Over! -- ", .{});
                std.debug.print(" ---------------- ", .{});
                // YacDynamicArrayClearAndFree(pieces);
                for (0..pieces.items.len) |j| {
                    if (pieces.items[j]) |item| {
                        // self.allocator.destroy(pieces.items[j].?);
                        self.allocator.destroy(item);
                    }
                }
                // pieces.deinit();
                std.debug.print("::::       FALSE>>> \n", .{});
                return false;
            }
            self.grid.items[i / 4].items[(i % 4) + spawning_offset] = pieces.items[i];
        }

        for (0..pieces.items.len) |j| {
            if (pieces.items[j]) |item| {
                // self.allocator.destroy(pieces.items[j].?);
                self.allocator.destroy(item);
            }
        }
        pieces.deinit();

        std.debug.print("::::       TRUE>>> \n", .{});
        return true;
    }

    fn getPiece(self: *App, piece_type: PieceType, pivot: *GridPos) !std.ArrayList(?*Mino) {
        var pieces = try std.ArrayList(?*Mino).initCapacity(self.allocator, 8);

        switch (piece_type) {
            .i => {
                pivot.* = GridPos{ .x = 1, .y = 0 };
                try pieces.append(try self.minoInit(i_piece_color, true));
                try pieces.append(try self.minoInit(i_piece_color, true));
                try pieces.append(try self.minoInit(i_piece_color, true));
                try pieces.append(try self.minoInit(i_piece_color, true));
            },
            .j => {
                pivot.* = GridPos{ .x = 1, .y = 1 };
                try pieces.append(try self.minoInit(j_piece_color, true));
                try pieces.append(null);
                try pieces.append(null);
                try pieces.append(null);
                try pieces.append(try self.minoInit(j_piece_color, true));
                try pieces.append(try self.minoInit(j_piece_color, true));
                try pieces.append(try self.minoInit(j_piece_color, true));
                try pieces.append(null);
            },
            .l => {
                pivot.* = GridPos{ .x = 1, .y = 1 };
                try pieces.append(null);
                try pieces.append(null);
                try pieces.append(try self.minoInit(l_piece_color, true));
                try pieces.append(null);
                try pieces.append(try self.minoInit(l_piece_color, true));
                try pieces.append(try self.minoInit(l_piece_color, true));
                try pieces.append(try self.minoInit(l_piece_color, true));
                try pieces.append(null);
            },
            .o => {
                pivot.* = GridPos{ .x = 0, .y = 0 };
                try pieces.append(null);
                try pieces.append(try self.minoInit(o_piece_color, true));
                try pieces.append(try self.minoInit(o_piece_color, true));
                try pieces.append(null);
                try pieces.append(null);
                try pieces.append(try self.minoInit(o_piece_color, true));
                try pieces.append(try self.minoInit(o_piece_color, true));
                try pieces.append(null);
            },
            .t => {
                pivot.* = GridPos{ .x = 1, .y = 1 };
                try pieces.append(null);
                try pieces.append(try self.minoInit(t_piece_color, true));
                try pieces.append(null);
                try pieces.append(null);
                try pieces.append(try self.minoInit(t_piece_color, true));
                try pieces.append(try self.minoInit(t_piece_color, true));
                try pieces.append(try self.minoInit(t_piece_color, true));
                try pieces.append(null);
            },
            .s => {
                pivot.* = GridPos{ .x = 1, .y = 1 };
                try pieces.append(null);
                try pieces.append(try self.minoInit(s_piece_color, true));
                try pieces.append(try self.minoInit(s_piece_color, true));
                try pieces.append(null);
                try pieces.append(try self.minoInit(s_piece_color, true));
                try pieces.append(try self.minoInit(s_piece_color, true));
                try pieces.append(null);
                try pieces.append(null);
            },
            .z => {
                pivot.* = GridPos{ .x = 1, .y = 1 };
                try pieces.append(try self.minoInit(z_piece_color, true));
                try pieces.append(try self.minoInit(z_piece_color, true));
                try pieces.append(null);
                try pieces.append(null);
                try pieces.append(null);
                try pieces.append(try self.minoInit(z_piece_color, true));
                try pieces.append(try self.minoInit(z_piece_color, true));
                try pieces.append(null);
            },
        }
        return pieces;
    }

    fn minoInit(self: *App, color: rl.Color, is_dynamic: bool) !?*Mino {
        var mino = try self.allocator.create(Mino);
        mino.color = color;
        mino.is_dynamic = is_dynamic;
        return mino;
    }
};

pub fn main() !void {
    rl.initWindow(screen_width, screen_height, window_title);
    defer rl.closeWindow();

    rl.setTargetFPS(fps);

    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });

    const rand = prng.random();

    var gpa: std.heap.DebugAllocator(.{}) = .init;
    // _ = gpa;
    // const allocator = std.heap.c_allocator;

    const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;
    //
    defer if (builtin.mode == .Debug) {
        _ = gpa.deinit();
    };

    var app = try App.init(allocator, rand);
    defer app.deinit();

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.black);
        if (!try app.update()) break; // game over
        try app.draw();
    }
}
