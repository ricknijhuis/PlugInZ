const std = @import("std");
const c = @import("c.zig").c;
const Key = @import("key.zig").Key;

pub const PlatformError = error{ InitializationFailed, AlreadyInitialized };

var initialized: bool = false;

pub const Platform = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Platform {
        if (initialized) {
            return error.AlreadyInitialized;
        }
        if (c.glfwInit() == c.GLFW_FALSE) {
            return error.InitializationFailed;
        }

        initialized = true;

        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: Platform) void {
        _ = self; // autofix
        if (initialized) {
            c.glfwTerminate();
            initialized = false;
        }
    }

    pub fn pollEvents(self: Platform) void {
        _ = self; // autofix
        c.glfwPollEvents();
    }

    pub inline fn getKeyName(self: Platform, key: Key, scancode: i32) ?[:0]const u8 {
        _ = key; // autofix
        const name_opt = c.glfwGetKeyName(@intFromEnum(self), @as(c_int, @intCast(scancode)));
        return if (name_opt) |name|
            std.mem.span(@as([*:0]const u8, @ptrCast(name)))
        else
            null;
    }

    pub inline fn getScancode(self: Platform, key: Key) i32 {
        _ = self; // autofix
        return c.glfwGetKeyScancode(@intFromEnum(key));
    }
};
