const std = @import("std");

pub fn build(b: *std.Build) void {
    // General options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const name = b.option([]const u8, "name", "Name of the app") orelse "PlugInZ";

    const options = b.addOptions();
    options.addOption([]const u8, "name", name);

    // Steps
    const run_step = b.step("run", "Run the app");

    // Modules
    const options_mod = options.createModule();

    const sandbox_mod = b.createModule(.{
        .root_source_file = b.path("src/sandbox/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const engine_mod = b.createModule(.{
        .root_source_file = b.path("src/engine/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    engine_mod.addImport("options", options_mod);
    exe_mod.addImport("engine", engine_mod);
    exe_mod.addImport("options", options_mod);
    sandbox_mod.addImport("engine", engine_mod);

    // Artifacts
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = exe_mod,
    });

    const lib = b.addLibrary(.{
        .name = name,
        .root_module = sandbox_mod,
        .linkage = .dynamic,
    });

    b.installArtifact(lib);
    b.installArtifact(exe);

    // Executable
    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    run_step.dependOn(&run_cmd.step);

    // Unit tests
}
