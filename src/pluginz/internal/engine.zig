const std = @import("std");

const Platform = @import("platform.zig").Platform;
const Renderer = @import("renderer.zig").Renderer;

pub const EngineConfig = struct {
    app_name: []const u8,
    app_version: []const u8,
    asset_path: []const u8,
    max_threads: ?u32 = null,
    max_memory: ?u64 = null,
    max_vram: ?u64 = null,
};

pub const EngineState = struct {
    pub const Jobs = struct {
        // TODO
    };

    allocator: std.mem.Allocator,
    config: EngineConfig,
    platform: Platform,
    renderer: Renderer,
    jobs: Jobs,

    pub fn init(allocator: std.mem.Allocator, config: EngineConfig) !void {
        instance = try allocator.create(EngineState);
        errdefer allocator.destroy(instance);

        instance.allocator = allocator;
        instance.config = config;

        try instance.platform.init(allocator);
        errdefer instance.platform.deinit(allocator);

        try instance.renderer.init(allocator);
        errdefer instance.renderer.deinit(allocator);
    }

    pub fn deinit() void {
        instance.renderer.deinit(instance.allocator);
        instance.platform.deinit(instance.allocator);
        instance.allocator.destroy(instance);
    }

    pub var instance: *EngineState = undefined;
};
