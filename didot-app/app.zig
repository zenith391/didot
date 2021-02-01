//! The application module is used for managing the lifecycle of a video game.
const graphics = @import("didot-graphics");
const objects = @import("didot-objects");
const std = @import("std");
const single_threaded = @import("builtin").single_threaded;
const Allocator = std.mem.Allocator;
const Window = graphics.Window;
const Scene = objects.Scene;

const System = struct {
    function: anytype,
    type: type,
};

pub const Systems = struct {
    items: []const System = &[0]System {},

    pub fn addSystem(comptime self: *Systems, system: anytype) void {
        const T = @TypeOf(system);
        const info = @typeInfo(T).Fn;
        const arr = [1]System { .{ .type = T, .function = system } };
        self.items = self.items ++ arr;
    }
};

pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    if (@enumToInt(message_level) <= @enumToInt(std.log.level)) {
        const level_txt = switch (message_level) {
            .emerg => "emergency",
            .alert => "alert",
            .crit => "critical",
            .err => "error",
            .warn => "warning",
            .notice => "notice",
            .info => "info",
            .debug => "debug",
        };
        const prefix2 = if (scope == .default) " -> " else " (" ++ @tagName(scope) ++ ") -> ";
        const stderr = std.io.getStdErr().writer();
        const held = std.debug.getStderrMutex().acquire();
        defer held.release();
        nosuspend stderr.print("[" ++ level_txt ++ "]" ++ prefix2 ++ format ++ "\n", args) catch return;
    }
}

const SystemList = std.ArrayList(usize);

/// Helper class for using Didot.
pub fn Application(comptime systems: Systems) type {
    const App = struct {
        const Self = @This();
        /// How many time per second updates should be called, defaults to 60 updates/s.
        updateTarget: u32 = 60,
        window: Window = undefined,
        /// The current scene, this is set by init() and start().
        /// It can also be set manually to change scene in-game.
        scene: *Scene = undefined,
        title: [:0]const u8 = "Didot Game",
        allocator: *Allocator = undefined,
        /// Optional function to be called on application init.
        initFn: ?fn(allocator: *Allocator, app: *Self) callconv(if (std.io.is_async) .Async else .Unspecified) anyerror!void = null,
        closing: bool = false,
        timer: std.time.Timer = undefined,

        /// Initialize the application using the given allocator and scene.
        /// This creates a window, init primitives and call the init function if set.
        pub fn init(self: *Self, allocator: *Allocator, scene: *Scene) !void {
            var window = try Window.create();
            errdefer window.deinit();
            window.setTitle(self.title);
            self.scene = scene;
            errdefer scene.deinit();
            self.window = window;
            self.allocator = allocator;
            self.timer = try std.time.Timer.start();
            objects.initPrimitives();
            
            try scene.assetManager.put("Mesh/Cube", .{
                .objectPtr = @ptrToInt(&objects.PrimitiveCubeMesh),
                .unloadable = false,
                .objectType = .Mesh
            });
            try scene.assetManager.put("Mesh/Plane", .{
                .objectPtr = @ptrToInt(&objects.PrimitivePlaneMesh),
                .unloadable = false,
                .objectType = .Mesh
            });

            if (self.initFn) |func| {
                if (std.io.is_async) {
                    var stack = try allocator.alignedAlloc(u8, 16, @frameSize(func));
                    defer allocator.free(stack);
                    var result: anyerror!void = undefined;
                    try await @asyncCall(stack, &result, func, .{allocator, self});
                } else {
                    try func(allocator, self);
                }
            }
        }

        inline fn printErr(err: anyerror) void {
            std.log.err("{s}", .{@errorName(err)});
            if (@errorReturnTrace()) |trace| {
                std.debug.dumpStackTrace(trace.*);
            }
        }

        fn updateTick(self: *Self, comptime doSleep: bool) void {
            var arena = std.heap.ArenaAllocator.init(self.allocator);
            const allocator = &arena.allocator;

            const time_per_frame = (1 / @intToFloat(f64, self.updateTarget)) * std.time.ns_per_s;
            const time = self.timer.lap();
            const dt = @floatCast(f32, time_per_frame / @intToFloat(f64, time));

            var result: anyerror!void = undefined;
            self.scene.gameObject.update(self.allocator, dt) catch |err| printErr(err);

            inline for (systems.items) |sys| {
                const info = @typeInfo(sys.type).Fn;
                var tuple: std.meta.ArgsTuple(sys.type) = undefined;
                var skip: bool = false;
                comptime var isForEach: bool = false;
                comptime var forEachTypes: []const type = &[0]type {};

                inline for (info.args) |arg, i| {
                    const key = comptime std.fmt.comptimePrint("{}", .{i});
                    const Type = arg.arg_type.?;
                    if (comptime std.mem.eql(u8, @typeName(Type), "SystemQuery")) {
                        var query = Type { .scene = self.scene };
                        @field(tuple, key) = query;
                    } else if (comptime std.meta.trait.isSingleItemPtr(Type)) {
                        isForEach = true;
                        forEachTypes = forEachTypes ++ &[_]type {Type};
                    } else {
                        @compileError("Invalid argument type: " ++ @typeName(Type));
                    }
                }
                
                if (!skip) {
                    const opts: std.builtin.CallOptions = .{};
                    if (isForEach) {
                        const tupleTypes = [1]type {type} ** forEachTypes.len;
                        const TupleType = std.meta.Tuple(&tupleTypes);
                        comptime var queryTuple: TupleType = undefined;
                        inline for (forEachTypes) |compType, i| {
                            @field(queryTuple, comptime std.fmt.comptimePrint("{}", .{i})) = compType;
                        }
                        var query = objects.Query(queryTuple) { .scene = self.scene };
                        var it = query.iterator();

                        while (it.next()) |o| {
                            inline for (info.args) |arg, i| {
                                if (comptime std.meta.trait.isSingleItemPtr(arg.arg_type.?)) {
                                    const key = comptime std.fmt.comptimePrint("{}", .{i});
                                    const name = @typeName(std.meta.Child(arg.arg_type.?));
                                    comptime var fieldName: [name.len]u8 = undefined;
                                    fieldName = name.*;
                                    fieldName[0] = comptime std.ascii.toLower(fieldName[0]);
                                    @field(tuple, key) = @field(o, &fieldName);
                                }
                            }
                            try @call(opts, sys.function, tuple);
                        }
                    } else {
                        try @call(opts, sys.function, tuple);
                    }
                }
            }
            
            const updateLength = self.timer.read();
            arena.deinit();
            if (doSleep) {
                const wait = @floatToInt(u64, 
                    std.math.max(0, @floor(
                        (1.0 / @intToFloat(f64, self.updateTarget)) * std.time.ns_per_s
                        - @intToFloat(f64, updateLength)))
                );
                std.time.sleep(wait);
            }
        }

        fn updateLoop(self: *Self) void {
            while (!self.closing) {
                self.updateTick(true);
            }
        }

        /// Start the game loop, that is doing rendering.
        /// It is also ensuring game updates and updating the window.
        pub fn loop(self: *Self) !void {
            var thread: *std.Thread = undefined;
            if (!single_threaded) {
                if (std.io.is_async) {
                    _ = async self.updateLoop();
                } else {
                    thread = try std.Thread.spawn(self, updateLoop);
                }
            }
            while (self.window.update()) {
                if (single_threaded) {
                    self.updateTick(false);
                }
                try self.scene.render(self.window);
            }
            self.closing = true;
            if (!single_threaded and !std.io.is_async) {
                thread.wait(); // thread must be closed before scene is de-init (to avoid use-after-free)
            }
            self.closing = false;
            self.window.deinit();
            self.scene.deinitAll();
        }

        /// Helper method to call both init() and loop().
        pub fn run(self: *Self, allocator: *Allocator, scene: *Scene) !void {
            try self.init(allocator, scene);
            try self.loop();
        }

    };
    return App;
}

comptime {
    //std.testing.refAllDecls(Application);
}
