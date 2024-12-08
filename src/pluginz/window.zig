const std = @import("std");

const EngineState = @import("internal/engine.zig").EngineState;
const WindowResource = @import("internal/platform/window.zig").WindowResource;
pub const WindowConfig = @import("internal/platform/window.zig").WindowConfig;
pub const WindowResourceHandle = @import("internal/platform/window.zig").WindowResourceHandle;
pub const WindowResourceBuffer = @import("internal/platform/window.zig").WindowResourceBuffer;
pub const WindowResizeCallbackFn = @import("internal/platform/window.zig").WindowResizeCallbackFn;

pub const Window = struct {
    pub fn init(config: WindowConfig) !WindowResourceHandle {
        var window: *WindowResource = undefined;
        const handle = try EngineState.instance.platform.windows.alloc(&window);

        try window.init(EngineState.instance.allocator, config);

        return handle;
    }

    pub fn deinit(handle: WindowResourceHandle) void {
        const window = EngineState.instance.platform.windows.at(handle);
        Window.deinit(window);

        EngineState.instance.platform.windows.dealloc(handle);
    }

    pub fn shouldClose(handle: WindowResourceHandle) bool {
        const window = EngineState.instance.platform.windows.at(handle);
        return window.shouldClose();
    }

    pub fn resize(handle: WindowResourceHandle, width: u32, height: u32) void {
        const window = EngineState.instance.platform.windows.at(handle);
        window.resize(width, height);
    }

    pub fn hide(handle: WindowResourceHandle) void {
        const window = EngineState.instance.platform.windows.at(handle);
        window.hide();
    }

    pub fn show(handle: WindowResourceHandle) void {
        const window = EngineState.instance.platform.windows.at(handle);
        window.show();
    }

    pub fn focus(handle: WindowResourceHandle) void {
        const window = EngineState.instance.platform.windows.at(handle);
        window.focus();
    }

    pub fn addResizeCallback(
        handle: WindowResourceHandle,
        context: ?*anyopaque,
        callback: WindowResizeCallbackFn,
    ) !void {
        const window = EngineState.instance.platform.windows.at(handle);
        window.addResizeCallback(context, callback);
    }

    pub fn removeResizeCallback(
        handle: WindowResourceHandle,
        callback: WindowResizeCallbackFn,
    ) !void {
        const window = EngineState.instance.platform.windows.at(handle);
        window.removeResizeCallback(callback);
    }
};
