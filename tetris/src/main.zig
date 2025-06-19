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
    I,
    J,
    L,
    O,
    T,
    S,
    Z,
};

const GridPos = struct {
    x: i32,
    y: i32,
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
        for (self.grid.items) |*item| {
            item.deinit();
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

    fn rotateDynamicMinos(self: *Appp, clockwise: bool) bool {
        var mino_positions = std.ArrayList(MinoPos).init(self.allocator);
        var new_mino_positions = std.ArrayList(MinoPos).init(self.allocator);

        // 1. Get a vector of all dynamic minos
        for (0..self.grid.items.len) |i| {
            for (0..self.grid.items[i].items.len) |j| {
                mino = self.grid.items[i].items[j];
                if (self.grid.items[i].items[j] == null || mino == null || !mino->is_dynamic)
                    continue;
                mino_pos = {.mino = mino, .pos = GridPos{.x = j, .y = i}};
                try mino_positions.append(mino_pos);
            }
        }
        if (mino_positions.items.len == 0)
            return false;

        // 2. Check if minos can rotate
        for (0..mino_positions.items.len) |i| {
            // TODO
            new_pos = self.getRotationAroundPivot(mino_positions.items[i].pos, clockwise);
            if (newPos.x < 0 || newPos.x >= self.grid.items[0].len
                || newPos.y < 0 || newPos.y >= self.grid.len)
                return false;
            if (self.grid.items[newPos.y].items[newPos.x] != NULL
                && !self.grid.items[newPos.y].items[newPos.x]->isDynamic)
                return false;
            YacDynamicArrayAppend(&newDynamicMinos, ((MinoPos){dynamicMinos.items[i].mino, newPos}));
        }

    }

    fn getRotationAroundPivot(self: *App pos: GridPos, clockwise: bool)GridPos {
        // TODO
        
    }

    fn update(self: *App) bool {
        self.next_update -= 1;
        self.last_movement_update += 1;

        //
        // Input handling
        //

        // KEY_RIGHT
        if (rl.isKeyDown(.right)) {
            if (!self.input_state.right_pressed_last_frame) {
                self.moveDynamicMinos(1, 0);
                self.right_key_hold_time = 0;
            } else {
                self.right_key_hold_time += 1;
                if (self.right_key_hold_time >= das_delay && (self.right_key_hold_time - das_delay) % arr_rate == 0)
                    self.moveDynamicMinos(1, 0);
            }
        } else {
            self.right_key_hold_time = 0;
        }

        // KEY_LEFT
        if (rl.isKeyDown(.left)) {
            if (!self.input_state.left_pressed_last_frame) {
                self.moveDynamicMinos(-1, 0);
                self.left_key_hold_time = 0;
            } else {
                self.left_key_hold_time++;
                if (self.left_key_hold_time >= das_delay && (self.left_key_hold_time - DAS_DELAY) % arr_rate == 0)
                    self.moveDynamicMinos(-1, 0);
            }
        } else {
            self.left_key_hold_time = 0;
        }

        // KEY_DOWN
        if (rl.isKeyDown(.down) && !self.input_state.down_pressed_last_frame)
            self.next_update = 0;

        // KEY_SPACE
        if (!rl.isKeyDown(.space) && self.input_state.space_pressed_last_frame) {
            while (self.moveDynamicMinos(0, 1));
            self.last_movement_update = piece_statification_delay;
        }

        // KEY_UP
        if (!rl.isKeyDown(.up) && self.input_state.up_pressed_last_frame)
            // TODO
            self.rotateDynamicMinos(false);

        // KEY_A
        if (!IsKeyDown(KEY_A) && self.input_state.a_pressed_last_frame)
            GameGridRotateDynamicMinos(gg, false);

        // KEY_D
        if (!IsKeyDown(KEY_D) && self.input_state.d_pressed_last_frame)
            GameGridRotateDynamicMinos(gg, true);

        // KEY_LEFT_SHIFT
        if (!IsKeyDown(KEY_LEFT_SHIFT) && self.input_state.shift_pressed_last_frame)
            GameGridHoldPiece(gg);

        self.input_state.right_pressed_last_frame = IsKeyDown(KEY_RIGHT);
        self.input_state.left_pressed_last_frame = IsKeyDown(KEY_LEFT);
        self.input_state.down_pressed_last_frame = IsKeyDown(KEY_DOWN);
        self.input_state.up_pressed_last_frame = IsKeyDown(KEY_UP);
        self.input_state.space_pressed_last_frame = IsKeyDown(KEY_SPACE);
        self.input_state.a_pressed_last_frame = IsKeyDown(KEY_A);
        self.input_state.d_pressed_last_frame = IsKeyDown(KEY_D);
        self.input_state.shift_pressed_last_frame = IsKeyDown(KEY_LEFT_SHIFT);

    }

    fn draw(self: App) void {}

    fn moveDynamicMinos(self: *App, right: usize, down: usize) bool{
        var change_occurred = false;

        // 1. Move horizontally
        if (right != 0) {
            // Check if minos can move
            var dynamic_minos_movable = true;
            var dynamic_minos_present = false;

            for (0..self.grid.items.len) {
                for (0..self.grid.items[i].len) {
                    const mino = self.grid.items[i].items[j];
                    if (self.grid.items[i].items[j] == null || mino == null || !mino->is_dynamic)
                        continue;
                    dynamic_minos_present = true;
                    if (j + right < 0 || j + right >= self.grid.items[i].len) {
                        dynamic_minos_movable = false;
                        break;
                    }
                    if (self.grid.items[i].items[j + right] == null)
                        continue;
                    const mono_goal = self.grid.items[i].items[j];
                    if (!mino_goal->is_dynamic) {
                        dynamic_minos_movable = false;
                        break;
                    }
                }
                if (!dynamic_minos_movable)
                    break;
            }

            // Move minos
            const start = if (right > 0) self.grid.items[0].len - 1 else 0;
            const end = if (right > 0 ) -1 else self.grid.items[0].len;
            const step = if (right > 0) -1 else 1;
            if (dynamic_minos_movable && dynamic_minos_present) {
                self.pivot.x += right;
                for (0..self.grid.items.len) |i| {
                    var j = start;
                    while (j != end) : (j += step) {
                        if (self.grid.items[i].items[j] == null)
                            continue;
                        mino = self.grid.items[i].items[j];
                        if (!mino->is_dynamic)
                            continue;
                        if (self.grid.items[i].items[j + right] == null) {
                            self.grid.items[i].items[j + right] = self.grid.items[i].items[j];
                            self.grid.items[i].items[j] = null;
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
                for (0..self.grid.items[i].items.len) |j| {
                    const mino = self.grid.items[i].items[j];
                    if (self.grid.items[i].items[j] == null || mino == null || !mino->is_dynamic)
                        continue;
                    dynamic_minos_present = true;
                    if (i + down < 0 || i + down >= self.grid.len) {
                        dynamic_minos_movable = false;
                        break;
                    }
                    if (self.grid.items[i + down].items[j] == null)
                        continue;
                    mino_goal = self.grid.items[i + down].items[j];
                    if (!mino_goal->is_dynamic) {
                        dynamic_minos_movable = false;
                        break;
                    }
                }
                if (!dynamic_minos_movable)
                    break;
            }

            // Move minos
            const start = if (down > 0) self.grid.items.len - 1 else 0;
            const end = if (down > 0 ) -1 else self.grid.items.len;
            const step = if (down > 0 )  -1 else 1;
            if (dynamic_minos_movable && dynamic_minos_present) {
                self.pivot.y += down;
                while (i != end) : (i += step) {
                    for (0..self.grid.items[i].items.len) |j| {
                        if (self.grid.items[i].items[j] == null)
                            continue;
                        const mino = self.grid.items[i].items[j];
                        if (dm == null || !dm.is_dynamic)
                            continue;
                        if (self.grid.items[i + down].items[j] == null) {
                            self.grid.items[i + down].items[j] = self.grid.items[i].items[j];
                            self.grid.items[i].items[j] = null;
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
    const allocator = if (builtin.mode == .Debug) gpa.allocator() else std.heap.c_allocator;

    defer if (builtin.mode == .Debug) {
        _ = gpa.deinit();
    };

    var app = try App.init(allocator, rand);
    defer app.deinit();

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.black);
        if (!app.update()) break; // game over
        app.draw();
    }
}
