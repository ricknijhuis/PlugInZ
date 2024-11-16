const std = @import("std");
const Platform = @import("pluginz.platform").Platform;
const Window = @import("pluginz.platform").Window;

const vk = @import("vulkan");
const c = @import("c.zig");

const core = @import("core.zig");

/// Next, pass the `apis` to the wrappers to create dispatch tables.
const BaseDispatch = core.BaseDispatch;
const InstanceDispatch = core.InstanceDispatch;
const DeviceDispatch = core.DeviceDispatch;
const VulkanPhysicalDevice = core.VulkanPhysicalDevice;

// Also create some proxying wrappers, which also have the respective handles
const Instance = core.Instance;
const Device = core.Device;

pub const VulkanContext = struct {
    allocator: std.mem.Allocator,
    base: BaseDispatch,
    instance: Instance,
    debug_messenger: vk.DebugUtilsMessengerEXT,

    devices: []VulkanPhysicalDevice,

    pub fn init(
        platform: Platform,
    ) !*VulkanContext {
        const self = try platform.allocator.create(VulkanContext);
        self.allocator = platform.allocator;

        self.base = try BaseDispatch.load(c.glfwGetInstanceProcAddress);

        const extensions = try getRequiredExtensions(self.allocator);
        defer self.allocator.free(extensions);

        const layers = try getRequiredLayers(self.allocator);
        defer self.allocator.free(layers);

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

        self.devices = try self.getDevicesOrderedByScore();
        errdefer self.deinitDevices();

        return self;
    }

    pub fn deinit(self: VulkanContext) void {
        self.deinitDevices();
        self.deinitInstance();
    }

    fn deinitDevices(self: VulkanContext) void {
        for (self.devices) |device| {
            device.deinit();
        }
        self.allocator.free(self.devices);
    }

    fn deinitInstance(self: VulkanContext) void {
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

    fn getDevicesOrderedByScore(self: *const VulkanContext) ![]VulkanPhysicalDevice {
        const physical_devices = try self.instance.enumeratePhysicalDevicesAlloc(self.allocator);
        defer self.allocator.free(physical_devices);

        const devices = try self.allocator.alloc(VulkanPhysicalDevice, physical_devices.len);
        errdefer self.allocator.free(devices);

        for (devices, 0..) |*device, i| {
            const physical_device = physical_devices[i];

            try device.init(self, physical_device);
        }

        errdefer {
            for (devices) |device| {
                device.deinit();
            }
        }

        std.mem.sort(VulkanPhysicalDevice, devices, {}, sortDeviceLessThan);

        return devices;
    }
};

// orders by gpu type and memory size (general indicative of gpu performance)
fn sortDeviceLessThan(context: void, lhs: VulkanPhysicalDevice, rhs: VulkanPhysicalDevice) bool {
    _ = context; // autofix
    // prefer discrete gpu
    if (lhs.physical_device_properties.device_type == vk.PhysicalDeviceType.discrete_gpu and rhs.physical_device_properties.device_type != vk.PhysicalDeviceType.discrete_gpu)
        return false;

    // if not discrete prefer integrated
    if (lhs.physical_device_properties.device_type == vk.PhysicalDeviceType.integrated_gpu and rhs.physical_device_properties.device_type != vk.PhysicalDeviceType.integrated_gpu)
        return false;

    // check memory size
    var lhs_total_device_local: vk.DeviceSize = 0;
    for (lhs.physical_device_mem_properties.memory_heaps) |heap| {
        if (heap.flags.device_local_bit) {
            lhs_total_device_local += heap.size;
        }
    }

    var rhs_total_device_local: vk.DeviceSize = 0;
    for (rhs.physical_device_mem_properties.memory_heaps) |heap| {
        if (heap.flags.device_local_bit) {
            rhs_total_device_local += heap.size;
        }
    }

    if (lhs_total_device_local > rhs_total_device_local)
        return false;

    return true;
}

fn getRequiredExtensions(allocator: std.mem.Allocator) ![][*c]const u8 {
    var glfw_extensions_count: u32 = 0;
    const glfw_extensions = c.glfwGetRequiredInstanceExtensions(&glfw_extensions_count)[0..glfw_extensions_count];
    const other_extensions = [1][*c]const u8{vk.extensions.ext_debug_utils.name};

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
