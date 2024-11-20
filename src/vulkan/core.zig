const vk = @import("vulkan");
const glfw = @import("glfw");

pub const required_layers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};
pub const apis: []const vk.ApiInfo = &.{
    .{
        .base_commands = .{
            .createInstance = true,
        },
        .instance_commands = .{
            .createDevice = true,
        },
    },
    vk.features.version_1_0,
    vk.features.version_1_1,
    vk.features.version_1_2,
    vk.features.version_1_3,
    vk.extensions.khr_surface,
    vk.extensions.khr_swapchain,
    vk.extensions.ext_debug_utils,
    vk.extensions.khr_dynamic_rendering,
};

/// Next, pass the `apis` to the wrappers to create dispatch tables.
pub const BaseDispatch = vk.BaseWrapper(apis);
pub const InstanceDispatch = vk.InstanceWrapper(apis);
pub const DeviceDispatch = vk.DeviceWrapper(apis);

// Also create some proxying wrappers, which also have the respective handles
pub const Instance = vk.InstanceProxy(apis);
pub const Device = vk.DeviceProxy(apis);

const physical_device = @import("vulkan_physical_device.zig");

pub const VulkanPhysicalDevice = physical_device.VulkanPhysicalDevice;
pub const DeviceRequirements = physical_device.DeviceRequirements;
pub const DeviceQueueFamilyIndices = physical_device.DeviceQueueFamilyIndices;
pub const VulkanPhysicalDeviceCollection = @import("vulkan_physical_device_collection.zig").VulkanPhysicalDeviceCollection;

pub const VulkanContext = @import("vulkan_context.zig").VulkanContext;
pub const VulkanLogicalDevice = @import("vulkan_device.zig").VulkanLogicalDevice;
pub const VulkanSurface = @import("vulkan_surface.zig").VulkanSurface;

pub extern fn glfwGetInstanceProcAddress(instance: vk.Instance, procname: [*:0]const u8) vk.PfnVoidFunction;
pub extern fn glfwGetPhysicalDevicePresentationSupport(instance: vk.Instance, pdev: vk.PhysicalDevice, queuefamily: u32) c_int;
pub extern fn glfwCreateWindowSurface(instance: vk.Instance, window: *glfw.Window, allocation_callbacks: ?*const vk.AllocationCallbacks, surface: *vk.SurfaceKHR) vk.Result;
