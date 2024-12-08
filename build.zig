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

    const glfw_dep = addGlfwDependency(b, target, optimize);
    const vma_dep = addVmaDependency(b, target, optimize);
    const vulkan_module = addVulkanModule(b, target, optimize);
    const pluginz_module = addPlugInZModule(b, target, optimize, glfw_dep, vma_dep, vulkan_module);

    const exe = b.addExecutable(.{
        .name = "sandbox",
        .root_source_file = b.path("src/sandbox/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("pluginz", pluginz_module);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

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

    assets.addAssets(b, exe);
}

pub fn addPlugInZModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, glfw: *std.Build.Dependency, vma: *std.Build.Dependency, vulkan: *std.Build.Module) *std.Build.Module {
    const core_module = b.createModule(.{
        .root_source_file = b.path("src/pluginz/core/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    _ = core_module; // autofix

    const internal_module = b.createModule(.{
        .root_source_file = b.path("src/pluginz/internal/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    _ = internal_module; // autofix

    const pluginz_module = b.addModule("pluginz", .{
        .root_source_file = b.path("src/pluginz/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    // internal_module.linkLibrary(glfw.artifact("glfw"));
    // internal_module.addImport("glfw", glfw.module("root"));
    // internal_module.addImport("core", core_module);
    pluginz_module.addImport("vulkan", vulkan);

    pluginz_module.linkLibrary(glfw.artifact("glfw"));
    pluginz_module.addImport("glfw", glfw.module("root"));

    pluginz_module.linkLibrary(vma.artifact("vma"));
    pluginz_module.addImport("vma", vma.module("root"));
    // pluginz_module.addImport("core", core_module);
    // pluginz_module.addImport("internal", internal_module);

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
