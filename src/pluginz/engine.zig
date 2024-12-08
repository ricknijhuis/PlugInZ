const std = @import("std");

pub const EngineConfig = @import("internal/engine.zig").EngineConfig;
const EngineState = @import("internal/engine.zig").EngineState;
const Platform = @import("internal/platform.zig").Platform;

pub const Engine = struct {
    pub fn init(allocator: std.mem.Allocator, config: EngineConfig) !void {
        try EngineState.init(allocator, config);
    }

    pub fn deinit() void {
        EngineState.deinit();
    }

    pub inline fn pollEvents() void {
        Platform.pollEvents();
    }
};
