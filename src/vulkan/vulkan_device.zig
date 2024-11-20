const std = @import("std");
const vk = @import("vulkan");
const core = @import("core.zig");
const glfw = @import("glfw");

const VulkanPhysicalDevice = core.VulkanPhysicalDevice;
const VulkanPhysicalDeviceCollection = core.VulkanPhysicalDeviceCollection;
const DeviceRequirements = core.DeviceRequirements;
const DeviceQueueFamilyIndices = core.DeviceQueueFamilyIndices;
const VulkanContext = core.VulkanContext;
const DeviceDispatch = core.DeviceDispatch;
const Device = core.Device;

pub const VulkanLogicalDevice = struct {
    context: *const VulkanContext,
    physical_device: *const VulkanPhysicalDevice,
    device: Device,
    graphics_queue: vk.Queue,
    present_queue: vk.Queue,
    graphics_queue_family_index: u32,
    present_queue_family_index: u32,

    pub fn init(context: *const VulkanContext, devices: *const VulkanPhysicalDeviceCollection) !VulkanLogicalDevice {
        var self = VulkanLogicalDevice{
            .context = context,
            .device = undefined,
            .physical_device = undefined,
            .present_queue = undefined,
            .graphics_queue = undefined,
            .graphics_queue_family_index = undefined,
            .present_queue_family_index = undefined,
        };

        // Create dummy window and surface
        glfw.defaultWindowHints();
        glfw.windowHint(glfw.WindowHint.client_api, 0);
        glfw.windowHint(glfw.WindowHint.visible, 0);
        glfw.windowHint(glfw.WindowHint.focused, 0);
        glfw.windowHint(glfw.WindowHint.focus_on_show, 0);

        const handle_or_null = glfw.createWindow(1, 1, "", null, null);

        if (handle_or_null == null) {
            try glfw.convertToError(glfw.getError(null));
        }

        const handle = handle_or_null.?;
        defer glfw.destroyWindow(handle);

        var surface: vk.SurfaceKHR = undefined;
        if (core.glfwCreateWindowSurface(self.context.instance.handle, handle, null, &surface) != .success) {
            return error.SurfaceInitFailed;
        }
        defer self.context.instance.destroySurfaceKHR(surface, null);

        const extensions = [_][*:0]const u8{
            vk.extensions.khr_swapchain.name,
            vk.extensions.khr_dynamic_rendering.name,
        };
        const requirements: DeviceRequirements = .{
            .surface = surface,
            .extensions = &extensions,
        };

        var device_or_null: ?*VulkanPhysicalDevice = null;

        for (devices.devices) |*device| {
            if (try device.meetsRequirements(requirements)) {
                device_or_null = device;
            }
        }

        if (device_or_null == null)
            return error.NoDeviceMeetsCriteria;

        self.physical_device = device_or_null.?;

        var queues: ?DeviceQueueFamilyIndices = null;
        var queue_create_info_count: u32 = 0;
        var queue_create_info = [2]vk.DeviceQueueCreateInfo{
            .{
                .queue_family_index = undefined,
                .queue_count = undefined,
                .p_queue_priorities = undefined,
            },
            .{
                .queue_family_index = undefined,
                .queue_count = undefined,
                .p_queue_priorities = undefined,
            },
        };

        const priority = [_]f32{1};
        queues = try self.physical_device.getQueueFamilies(surface);
        if (queues) |families| {
            queue_create_info[0].queue_family_index = families.graphics_family;
            queue_create_info[0].queue_count = 1;
            queue_create_info[0].p_queue_priorities = &priority;

            queue_create_info[0].queue_family_index = families.present_family;
            queue_create_info[0].queue_count = 1;
            queue_create_info[0].p_queue_priorities = &priority;

            queue_create_info_count = if (families.graphics_family == families.present_family)
                1
            else
                2;

            self.graphics_queue_family_index = families.graphics_family;
            self.present_queue_family_index = families.present_family;
        }

        const dynamic_endering_features = vk.PhysicalDeviceDynamicRenderingFeatures{
            .dynamic_rendering = vk.TRUE,
        };

        const device_create_info = vk.DeviceCreateInfo{
            .p_next = &dynamic_endering_features,
            .queue_create_info_count = queue_create_info_count,
            .p_queue_create_infos = &queue_create_info,
            .enabled_extension_count = @intCast(requirements.extensions.len),
            .pp_enabled_extension_names = @ptrCast(requirements.extensions.ptr),
        };

        const device = try context.instance.createDevice(self.physical_device.device, &device_create_info, null);

        const device_dispatch = try context.allocator.create(DeviceDispatch);
        errdefer context.allocator.destroy(device_dispatch);

        device_dispatch.* = try DeviceDispatch.load(device, context.instance.wrapper.dispatch.vkGetDeviceProcAddr);
        self.device = Device.init(device, device_dispatch);

        if (queues) |families| {
            self.graphics_queue = self.device.getDeviceQueue(families.graphics_family, 0);
            self.present_queue = self.device.getDeviceQueue(families.present_family, 0);
        }

        return self;
    }

    pub fn deinit(self: VulkanLogicalDevice) void {
        self.device.destroyDevice(null);
        self.context.allocator.destroy(self.device.wrapper);
    }
};
