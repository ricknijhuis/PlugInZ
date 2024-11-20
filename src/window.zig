const std = @import("std");
const glfw = @import("glfw");
const Platform = @import("platform.zig").Platform;

pub const Window = struct {
    platform: *const Platform,
    handle: *glfw.Window,

    pub fn init(
        platform: *const Platform,
        params: struct { width: u32 = 1280, height: u32 = 720, title: [:0]const u8 = "" },
    ) !Window {
        var window = Window{
            .platform = platform,
            .handle = undefined,
        };

        glfw.defaultWindowHints();
        glfw.windowHint(glfw.WindowHint.client_api, 0);

        if (glfw.createWindow(
            @intCast(params.width),
            @intCast(params.height),
            params.title.ptr,
            null,
            null,
        )) |handle| {
            window.handle = handle;
        } else {
            try glfw.convertToError(glfw.getError(null));
        }

        return window;
    }

    pub fn shouldClose(self: Window) bool {
        return glfw.windowShouldClose(self.handle) == 1;
    }

    pub fn deinit(self: Window) void {
        glfw.destroyWindow(self.handle);
    }
};
