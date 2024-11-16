const std = @import("std");
const Platform = @import("pluginz.platform").Platform;
const Window = @import("pluginz.platform").Window;
const VulkanContext = @import("vulkan/vulkan_context.zig").VulkanContext;
const VulkanSurface = @import("vulkan/vulkan_surface.zig").VulkanSurface;

const Surface = struct {
    window: Window,
    surface: *VulkanSurface,

    pub fn init(context: *const VulkanContext, window: Window) !Surface {
        return .{
            .window = window,
            .surface = try VulkanSurface.init(context, window),
        };
    }

    pub fn deinit(self: Surface) void {
        self.surface.deinit();
    }
};

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    ctx: *VulkanContext,

    pub fn init(platform: Platform, params: struct {}) !Renderer {
        _ = params; // autofix
        return .{
            .allocator = platform.allocator,
            .ctx = try VulkanContext.init(platform),
        };
    }
    pub fn deinit(self: Renderer) void {
        _ = self; // autofix
    }

    pub fn createSurface(self: *Renderer, window: Window) !Surface {
        return .{
            .window = window,
            .surface = try Surface.init(self.ctx, window),
        };
    }
};
