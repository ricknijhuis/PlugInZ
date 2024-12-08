const std = @import("std");

const assets = @import("build.assets.zig");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const build_examples = b.option(bool, "build_examples", "Build all examples") orelse true;

    const glfw_dep = addGlfwDependency(b, target, optimize);
    const vma_dep = addVmaDependency(b, target, optimize);
    const vulkan_module = addVulkanModule(b, target, optimize);
    const pluginz_module = addPlugInZModule(b, target, optimize, glfw_dep, vma_dep, vulkan_module);

    if (build_examples) {
        buildExamples(b, target, optimize, pluginz_module);
    }

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/pluginz/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

fn addPlugInZModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, glfw: *std.Build.Dependency, vma: *std.Build.Dependency, vulkan: *std.Build.Module) *std.Build.Module {
    const pluginz_module = b.addModule("pluginz", .{
        .root_source_file = b.path("src/pluginz/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    pluginz_module.addImport("vulkan", vulkan);

    pluginz_module.linkLibrary(glfw.artifact("glfw"));
    pluginz_module.addImport("glfw", glfw.module("root"));

    pluginz_module.linkLibrary(vma.artifact("vma"));
    pluginz_module.addImport("vma", vma.module("root"));
    return pluginz_module;
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

fn addGlfwDependency(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Dependency {
    return b.dependency("glfw", .{
        .target = target,
        .optimize = optimize,
    });
}

fn addVmaDependency(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Dependency {
    return b.dependency("vma", .{
        .target = target,
        .optimize = optimize,
    });
}

fn buildExamples(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    pluginz: *std.Build.Module,
) void {
    inline for (examples) |example| {
        const example_exe = b.addExecutable(.{
            .name = example,
            .root_source_file = b.path("examples/" ++ example ++ "/main.zig"),
            .target = target,
            .optimize = optimize,
        });

        example_exe.root_module.addImport("pluginz", pluginz);

        b.installArtifact(example_exe);

        const run_cmd = b.addRunArtifact(example_exe);

        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);

        assets.addAssets(b, example_exe);
    }
}

const examples = &.{"basic"};
