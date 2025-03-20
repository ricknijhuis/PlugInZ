const std = @import("std");
const log = std.log;

const Engine = @import("engine").Engine;

pub export fn init(engine: *Engine) bool {
    _ = engine; // autofix
    log.info("Starting up application", .{});
    return true;
}

pub export fn deinit(engine: *Engine) void {
    _ = engine; // autofix
    log.info("Shutting down application", .{});
}
