const std = @import("std");

const glfw = @import("glfw");

const ResourceBufferUnmanaged = @import("../../resource_buffer.zig").ResourceBufferUnmanaged;

const WindowResizeCallback = Callback(WindowResizeCallbackFn);

pub const WindowResizeCallbackFn = *const fn (context: ?*anyopaque, width: i32, height: i32) void;
pub const WindowResourceBuffer = ResourceBufferUnmanaged(WindowResource);
pub const WindowResourceHandle = WindowResourceBuffer.Handle;
pub const WindowConfig = struct {
    title: [:0]const u8,
    width: u32,
    height: u32,
};

pub const WindowData = struct {
    resize_callbacks: []WindowResizeCallback,
};

pub const WindowResource = struct {
    handle: *glfw.Window,
    data: *WindowData,

    pub fn init(
        self: *WindowResource,
        allocator: std.mem.Allocator,
        config: WindowConfig,
    ) !void {
        glfw.defaultWindowHints();
        glfw.windowHint(glfw.WindowHint.client_api, 0);

        self.handle = glfw.createWindow(@intCast(config.width), @intCast(config.height), config.title.ptr, null, null) orelse {
            try glfw.convertToError(glfw.getError(null));
            return error.FailedToInitializeWindow;
        };

        self.data = try allocator.create(WindowData);
        self.data.resize_callbacks = &[_]WindowResizeCallback{};

        glfw.setWindowUserPointer(WindowData, self.handle, self.data);

        _ = glfw.setFramebufferSizeCallback(self.handle, frameBufferResizeCallback);
    }

    pub fn deinit(self: *WindowResource, allocator: std.mem.Allocator) void {
        allocator.destroy(self.data);
        glfw.destroyWindow(self.handle);
    }

    pub fn shouldClose(self: *const WindowResource) bool {
        return glfw.windowShouldClose(self.handle) == 1;
    }

    pub fn resize(self: *const WindowResource, width: u32, height: u32) void {
        glfw.setWindowSize(self.handle, @intCast(width), @intCast(height));
    }

    pub fn hide(self: *const WindowResource) void {
        glfw.hideWindow(self.handle);
    }

    pub fn show(self: *const WindowResource) void {
        glfw.showWindow(self.handle);
    }

    pub fn focus(self: *const WindowResource) void {
        glfw.focusWindow(self.handle);
    }

    pub fn addResizeCallback(
        self: *const WindowResource,
        allocator: std.mem.Allocator,
        context: ?*anyopaque,
        callback: WindowResizeCallbackFn,
    ) !void {
        if (glfw.getWindowUserPointer(WindowData, self.handle)) |ptr| {
            ptr.resize_callbacks = try allocator.realloc(ptr.resize_callbacks, ptr.resize_callbacks.len + 1);
            ptr.resize_callbacks[ptr.resize_callbacks.len - 1].callback = callback;
            ptr.resize_callbacks[ptr.resize_callbacks.len - 1].context = context;
        }
    }

    pub fn removeResizeCallback(
        self: *const WindowResource,
        allocator: std.mem.Allocator,
        callback: WindowResizeCallbackFn,
    ) !void {
        if (glfw.getWindowUserPointer(WindowData, self.handle)) |ptr| {
            var index = 0;

            for (ptr.resize_callbacks, 0..) |callback_fn, i| {
                if (callback_fn == callback) {
                    index = i;
                    break;
                }
            }

            // Shift back to keep items continues
            @memcpy(ptr.resize_callbacks[index..], ptr.resize_callbacks[index + 1 ..]);

            // Resize slice
            ptr.resize_callbacks = try allocator.resize(ptr.resize_callbacks, ptr.resize_callbacks.len - 1);
        }
    }
};

fn Callback(callbackFnType: type) type {
    return struct {
        context: ?*anyopaque,
        callback: callbackFnType,
    };
}

// GLFW callbacks
fn frameBufferResizeCallback(window: *glfw.Window, width: i32, height: i32) callconv(.c) void {
    if (glfw.getWindowUserPointer(WindowData, window)) |ptr| {
        for (ptr.resize_callbacks) |callback| {
            callback.callback(callback.context, width, height);
        }
    }
}
