const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const glfw_dep = b.dependency(glfw_module_name, .{
        .target = target,
        .optimize = optimize,
    });

    const vulkan_module = addVulkanModule(b, target, optimize);

    const math_module = b.addModule(math_module_name, .{
        .root_source_file = b.path("src/math/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const platform_module = b.addModule(platform_module_name, .{
        .root_source_file = b.path("src/platform/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    platform_module.linkLibrary(glfw_dep.artifact(glfw_module_name));

    const rendering_module = b.addModule(rendering_module_name, .{
        .root_source_file = b.path("src/rendering/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    rendering_module.addImport(platform_module_name, platform_module);
    rendering_module.addImport(math_module_name, math_module);
    rendering_module.addImport(vulkan_module_name, vulkan_module);
    rendering_module.linkLibrary(glfw_dep.artifact(glfw_module_name));

    // UNIT TESTS
    const math_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/math/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_math_unit_tests = b.addRunArtifact(math_unit_tests);

    const platform_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/platform/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    platform_unit_tests.linkLibrary(glfw_dep.artifact(glfw_module_name));
    const run_platform_unit_tests = b.addRunArtifact(platform_unit_tests);

    const rendering_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/rendering/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    rendering_unit_tests.root_module.addImport(vulkan_module_name, vulkan_module);
    rendering_unit_tests.root_module.addImport(platform_module_name, platform_module);
    const run_rendering_unit_tests = b.addRunArtifact(rendering_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_math_unit_tests.step);
    test_step.dependOn(&run_platform_unit_tests.step);
    test_step.dependOn(&run_rendering_unit_tests.step);
}

fn addVulkanModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    // Get the (lazy) path to vk.xml:
    const registry = b.dependency("vulkan_headers", .{}).path("registry/vk.xml");
    // Get generator executable reference
    const vk_gen = b.dependency("vulkan_zig", .{}).artifact("vulkan-zig-generator");
    // Set up a run step to generate the bindings
    const vk_generate_cmd = b.addRunArtifact(vk_gen);
    // Pass the registry to the generator
    vk_generate_cmd.addFileArg(registry);
    // Create a module from the generator's output...
    const vulkan_zig = b.addModule("vulkan-zig", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = vk_generate_cmd.addOutputFileArg("vk.zig"),
    });

    return vulkan_zig;
}

const glfw_module_name = "glfw";
const math_module_name = "pluginz.math";
const platform_module_name = "pluginz.platform";
const rendering_module_name = "pluginz.rendering";
const vulkan_module_name = "vulkan";
