const std = @import("std");
const glfw = @import("glfw");
const assert = std.debug.assert;

pub const Key = glfw.Key;

pub const PlatformError = error{ InitializationFailed, AlreadyInitialized };

pub const Platform = struct {
    allocator: std.mem.Allocator,
    initialized: bool,

    pub fn init(allocator: std.mem.Allocator) !Platform {
        if (glfw.init() != 0) {
            try glfw.convertToError(glfw.getError(null));
        }

        return .{
            .initialized = true,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Platform) void {
        if (self.initialized) {
            glfw.terminate();
            self.initialized = false;
        }
    }

    pub fn pollEvents(self: Platform) void {
        assert(self.initialized);
        glfw.pollEvents();
    }
};
