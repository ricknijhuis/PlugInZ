const std = @import("std");
const Platform = @import("platform.zig").Platform;
const Key = @import("key.zig").Key;
const MouseButton = @import("mouse.zig").MouseButton;
const KeyState = @import("key.zig").KeyState;

const c = @import("c.zig").c;

const Handle = *c.GLFWwindow;
const WindowError = error{ InitializationFailed, CreationFailed };

pub const Window = struct {
    allocator: std.mem.Allocator,
    handle: Handle,

    const Data = struct {
        key_state: [512]KeyState,
        mouse_state: [8]KeyState,
    };

    pub fn init(platform: Platform, params: struct { width: u32 = 1280, height: u32 = 720, title: []const u8 = "" }) !Window {
        c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
        const handle_or_null = c.glfwCreateWindow(
            @intCast(params.width),
            @intCast(params.height),
            params.title.ptr,
            null,
            null,
        );
        if (handle_or_null) |handle| {
            const window_data = try platform.allocator.create(Data);
            setWindowUserPointer(Data, handle, window_data);

            _ = c.glfwSetKeyCallback(handle, keyCallback);
            _ = c.glfwSetMouseButtonCallback(handle, mouseCallback);

            return .{ .allocator = platform.allocator, .handle = handle };
        } else {
            return error.CreationFailed;
        }
    }
    pub fn deinit(self: Window) void {
        const data = getWindowUserPointer(Data, self.handle);
        c.glfwDestroyWindow(self.handle);
        self.allocator.destroy(data);
    }

    pub fn shouldClose(self: Window) bool {
        return c.glfwWindowShouldClose(self.handle) == c.GLFW_TRUE;
    }

    pub inline fn isKeyPressed(self: Window, key: Key) bool {
        return c.glfwGetKey(self.handle, @intFromEnum(key)) == c.GLFW_PRESS;
    }

    pub inline fn isKeyPressedRepeat(self: Window, key: Key) bool {
        return c.glfwGetKey(self.handle, @intFromEnum(key)) == c.GLFW_RELEASE;
    }

    pub inline fn isKeyDown(self: Window, key: Key) bool {
        const data = getWindowUserPointer(Data, self.handle);
        return data.key_state[@intFromEnum(key)] == KeyState.down;
    }

    pub inline fn isKeyUp(self: Window, key: Key) bool {
        const data = getWindowUserPointer(Data, self.handle);
        return data.key_state[@intFromEnum(key)] == KeyState.up;
    }

    pub inline fn isMouseButtonPressed(self: Window, button: MouseButton) bool {
        return c.glfwGetMouseButton(self.handle, @intFromEnum(button)) == c.GLFW_PRESS;
    }

    pub inline fn isMouseButtonDown(self: Window, button: MouseButton) bool {
        const data = getWindowUserPointer(Data, self.handle);
        return data.mouse_state[@intFromEnum(button)] == KeyState.down;
    }

    pub inline fn isMouseButtonUp(self: Window, button: MouseButton) bool {
        const data = getWindowUserPointer(Data, self.handle);
        return data.mouse_state[@intFromEnum(button)] == KeyState.up;
    }

    fn keyCallback(handle: ?Handle, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
        _ = scancode; // autofix
        _ = mods; // autofix
        const data = getWindowUserPointer(Data, handle.?);

        if (action == c.GLFW_PRESS) {
            data.key_state[@intCast(key)] = KeyState.down;
            return;
        }

        if (action == c.GLFW_RELEASE) {
            data.key_state[@intCast(key)] = KeyState.up;
            return;
        }
    }

    fn mouseCallback(handle: ?Handle, button: c_int, action: c_int, mods: c_int) callconv(.C) void {
        _ = mods; // autofix
        const data = getWindowUserPointer(Data, handle.?);

        if (action == c.GLFW_PRESS) {
            data.mouse_state[@intCast(button)] = KeyState.down;
            return;
        }

        if (action == c.GLFW_RELEASE) {
            data.mouse_state[@intCast(button)] = KeyState.up;
            return;
        }
    }

    inline fn setWindowUserPointer(T: type, handle: Handle, ptr: *T) void {
        c.glfwSetWindowUserPointer(handle, ptr);
    }

    inline fn getWindowUserPointer(T: type, handle: Handle) *T {
        return @ptrCast(c.glfwGetWindowUserPointer(handle));
    }
};
