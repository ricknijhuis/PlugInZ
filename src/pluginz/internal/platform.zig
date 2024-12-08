const std = @import("std");

const glfw = @import("glfw");

const WindowResourceBuffer = @import("platform/window.zig").WindowResourceBuffer;

pub const Platform = struct {
    windows: WindowResourceBuffer,

    pub fn init(self: *Platform, allocator: std.mem.Allocator) !void {
        if (glfw.init() != 1) {
            // Try get a meaning full glfw error.
            try glfw.convertToError(glfw.getError(null));

            // If no error returned, return generic error.
            return error.FailedToInitializePlatform;
        }
        errdefer glfw.terminate();

        self.windows = try WindowResourceBuffer.init(allocator, 2);
    }

    pub fn deinit(self: *Platform, allocator: std.mem.Allocator) void {
        for (self.windows.getAll()) |*window| {
            window.deinit(allocator);
        }
        self.windows.deinit(allocator);

        glfw.terminate();
    }

    pub fn pollEvents() void {
        glfw.pollEvents();
    }
};
