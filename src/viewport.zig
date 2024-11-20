const vk = @import("vulkan");

const VulkanContext = @import("vulkan/vulkan_context.zig").VulkanContext;
const Renderer = @import("renderer.zig").Renderer;
const Window = @import("window.zig").Window;

const SwapImage = struct {
    image: vk.Image,
    view: vk.ImageView,
    image_acquired: vk.Semaphore,
    render_finished: vk.Semaphore,
    frame_fence: vk.Fence,
};

pub const Viewport = struct {
    ctx: *const VulkanContext,

    surface: vk.SurfaceKHR,
    surface_format: vk.SurfaceFormatKHR,
    present_mode: vk.PresentModeKHR,
    extent: vk.Extent2D,
    handle: vk.SwapchainKHR,

    swap_images: []SwapImage,
    image_index: u32,
    next_image_acquired: vk.Semaphore,

    pub fn init(renderer: *const Renderer, window: *const Window) !Viewport {
        _ = renderer; // autofix
        _ = window; // autofix
    }
};
