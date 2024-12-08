const std = @import("std");
const builtin = @import("builtin");

const glfw = @import("glfw");
const vk = @import("vulkan");

const Renderer = @import("../renderer.zig").Renderer;
const BaseDispatch = @import("wrapper.zig").BaseDispatch;
const InstanceDispatch = @import("wrapper.zig").InstanceDispatch;
const InstanceProxy = @import("wrapper.zig").InstanceProxy;

pub const Instance = struct {
    pub fn init(self: *Renderer, allocator: std.mem.Allocator) !void {
        self.base = try BaseDispatch.load(glfwGetInstanceProcAddress);

        const extensions = try getRequiredInstanceExtensions(allocator);
        defer allocator.free(extensions);

        const app_info = vk.ApplicationInfo{
            .p_application_name = "test",
            .application_version = vk.makeApiVersion(0, 0, 0, 0),
            .p_engine_name = "engine",
            .engine_version = vk.makeApiVersion(0, 0, 0, 0),
            .api_version = vk.API_VERSION_1_3,
        };

        var instance_info = vk.InstanceCreateInfo{
            .p_application_info = &app_info,
            .enabled_extension_count = @intCast(extensions.len),
            .pp_enabled_extension_names = @ptrCast(extensions.ptr),
            // use vulkan configurator to enable layers
            .enabled_layer_count = 0,
            .pp_enabled_layer_names = null,
        };

        const debug_msg_create_info = vk.DebugUtilsMessengerCreateInfoEXT{
            .message_severity = .{ .verbose_bit_ext = true },
            .message_type = .{
                .general_bit_ext = true,
                .performance_bit_ext = true,
                .validation_bit_ext = true,
            },
            .pfn_user_callback = debugCallback,
            .p_user_data = null,
        };

        if (builtin.mode == .Debug) {
            instance_info.p_next = &debug_msg_create_info;
        }

        const instance = try self.base.createInstance(&instance_info, null);
        const instance_dispatch = try allocator.create(InstanceDispatch);
        errdefer allocator.destroy(instance_dispatch);

        instance_dispatch.* = try InstanceDispatch.load(instance, self.base.dispatch.vkGetInstanceProcAddr);
        errdefer instance_dispatch.destroyInstance(instance, null);

        self.instance = InstanceProxy.init(instance, instance_dispatch);

        if (builtin.mode == .Debug) {
            self.debug_messenger = try self.instance.createDebugUtilsMessengerEXT(&debug_msg_create_info, null);
        }
    }

    pub fn deinit(self: *Renderer, allocator: std.mem.Allocator) void {
        std.debug.assert(self.instance.handle != .null_handle);

        if (builtin.mode == .Debug) {
            self.instance.destroyDebugUtilsMessengerEXT(self.debug_messenger, null);
        }

        self.instance.destroyInstance(null);
        allocator.destroy(self.instance.wrapper);
    }
};

fn getRequiredInstanceExtensions(allocator: std.mem.Allocator) ![][*c]const u8 {
    const other_extensions = [_][*c]const u8{
        vk.extensions.ext_debug_utils.name,
        vk.extensions.khr_get_physical_device_properties_2.name,
    };

    var glfw_extensions_count: i32 = 0;
    const glfw_extensions = glfw.getRequiredInstanceExtensions(&glfw_extensions_count)[0..@intCast(glfw_extensions_count)];

    var extensions = try allocator.alloc([*c]const u8, glfw_extensions.len + other_extensions.len);
    @memcpy(extensions[0..glfw_extensions.len], glfw_extensions);
    @memcpy(extensions[glfw_extensions.len..], other_extensions[0..other_extensions.len]);

    return extensions;
}

fn debugCallback(
    severity: vk.DebugUtilsMessageSeverityFlagsEXT,
    msg_type: vk.DebugUtilsMessageTypeFlagsEXT,
    callback_data: ?*const vk.DebugUtilsMessengerCallbackDataEXT,
    user_data: ?*anyopaque,
) callconv(.C) vk.Bool32 {
    _ = msg_type; // autofix
    _ = user_data; // autofix

    if (callback_data) |data| {
        if (data.p_message) |message| {
            if (severity.verbose_bit_ext) {
                std.log.debug("{s}", .{message});
            } else if (severity.info_bit_ext) {
                std.log.info("{s}", .{message});
            } else if (severity.warning_bit_ext) {
                std.log.warn("{s}", .{message});
            } else if (severity.error_bit_ext) {
                std.log.err("{s}", .{message});
            } else {
                std.log.warn("{s}", .{message});
            }
        }
    }

    return vk.FALSE;
}

extern fn glfwGetInstanceProcAddress(instance: vk.Instance, procname: [*:0]const u8) vk.PfnVoidFunction;
