const std = @import("std");
const glfw = @import("glfw");
const vk = @import("vulkan");
const core = @import("core.zig");

const Platform = @import("../platform.zig").Platform;
const Window = @import("../window.zig").Window;
const BaseDispatch = core.BaseDispatch;
const InstanceDispatch = core.InstanceDispatch;
const DeviceDispatch = core.DeviceDispatch;
const VulkanPhysicalDevice = core.VulkanPhysicalDevice;
const VulkanLogicalDevice = core.VulkanLogicalDevice;
const Instance = core.Instance;
const Device = core.Device;

pub const VulkanContext = struct {
    allocator: std.mem.Allocator,
    base: BaseDispatch,
    instance: Instance,
    debug_messenger: vk.DebugUtilsMessengerEXT,

    pub fn init(
        platform: *const Platform,
    ) !VulkanContext {
        var self = VulkanContext{
            .allocator = platform.allocator,
            .base = undefined,
            .instance = undefined,
            .debug_messenger = undefined,
        };

        self.base = try BaseDispatch.load(core.glfwGetInstanceProcAddress);

        const extensions = try getRequiredExtensions(self.allocator);
        defer self.allocator.free(extensions);

        const layers = try getRequiredLayers(self.allocator);
        defer self.allocator.free(layers);

        try self.validateLayers(layers);

        const app_info = vk.ApplicationInfo{
            .p_application_name = "test",
            .application_version = vk.makeApiVersion(0, 0, 0, 0),
            .p_engine_name = "engine",
            .engine_version = vk.makeApiVersion(0, 0, 0, 0),
            .api_version = vk.API_VERSION_1_3,
        };

        const instance = try self.base.createInstance(&.{
            .p_application_info = &app_info,
            .enabled_extension_count = @intCast(extensions.len),
            .pp_enabled_extension_names = @ptrCast(extensions.ptr),
            .enabled_layer_count = @intCast(layers.len),
            .pp_enabled_layer_names = @ptrCast(layers.ptr),
        }, null);

        const instance_dispatch = try self.allocator.create(InstanceDispatch);
        errdefer self.allocator.destroy(instance_dispatch);

        instance_dispatch.* = try InstanceDispatch.load(instance, self.base.dispatch.vkGetInstanceProcAddr);
        self.instance = Instance.init(instance, instance_dispatch);
        errdefer self.instance.destroyInstance(null);

        self.debug_messenger = try self.createDebugCallback();

        errdefer self.deinitDevices();

        return self;
    }

    pub fn deinit(self: VulkanContext) void {
        self.instance.destroyInstance(null);
        self.allocator.destroy(self.instance.wrapper);
    }

    fn createDebugCallback(self: VulkanContext) !vk.DebugUtilsMessengerEXT {
        return try self.instance.createDebugUtilsMessengerEXT(&.{
            .message_severity = .{ .verbose_bit_ext = true },
            .message_type = .{
                .general_bit_ext = true,
                .performance_bit_ext = true,
                .validation_bit_ext = true,
            },
            .pfn_user_callback = debugCallback,
            .p_user_data = null,
        }, null);
    }

    fn validateLayers(self: VulkanContext, required_layers: [][*c]const u8) !void {
        const available_layers = try self.base.enumerateInstanceLayerPropertiesAlloc(self.allocator);
        var found = false;
        for (required_layers) |required_layer| {
            for (available_layers) |available_layer| {
                if (std.mem.eql(u8, std.mem.span(required_layer), std.mem.span(@as([*:0]const u8, @ptrCast(&available_layer.layer_name))))) {
                    found = true;
                    break;
                }
            }
            if (!found)
                return error.RequiredValidationLayerNotAvailable;
        }
    }
};

fn getRequiredExtensions(allocator: std.mem.Allocator) ![][*c]const u8 {
    var glfw_extensions_count: i32 = 0;
    const glfw_extensions = glfw.getRequiredInstanceExtensions(&glfw_extensions_count)[0..@intCast(glfw_extensions_count)];
    const other_extensions = [_][*c]const u8{
        vk.extensions.ext_debug_utils.name,
        vk.extensions.khr_get_physical_device_properties_2.name,
    };

    const extensions = try allocator.alloc([*c]const u8, glfw_extensions.len + other_extensions.len);
    @memcpy(extensions[0..glfw_extensions.len], glfw_extensions);
    @memcpy(extensions[glfw_extensions.len..], other_extensions[0..other_extensions.len]);

    return extensions;
}

fn getRequiredLayers(allocator: std.mem.Allocator) ![][*c]const u8 {
    const required_layers = [_][*c]const u8{"VK_LAYER_KHRONOS_validation"};
    const layers = try allocator.alloc([*c]const u8, 1);
    @memcpy(layers, required_layers[0..required_layers.len]);

    return layers;
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
