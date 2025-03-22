const std = @import("std");

pub const Engine = struct {
    pub fn init() !Engine {
        return .{};
    }
    pub fn deinit(self: *Engine) void {
        _ = self;
    }
};
