const std = @import("std");

pub fn build(b: *std.Build) void {
    // General options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const name = b.option([]const u8, "name", "Name of the app") orelse "PlugInZ";

    const options = b.addOptions();
    options.addOption([]const u8, "name", name);

    // Steps
    // const run_step = b.step("run", "Run the app");

    // Modules
    const options_mod = options.createModule();

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const engine_mod = b.addModule("pluginz", .{
        .root_source_file = b.path("src/engine/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    engine_mod.addImport("options", options_mod);
    exe_mod.addImport("engine", engine_mod);
    exe_mod.addImport("options", options_mod);

    // Artifacts
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    // Executable
    // const run_cmd = b.addRunArtifact(exe);

    // run_cmd.step.dependOn(b.getInstallStep());

    // if (b.args) |args| {
    //     run_cmd.addArgs(args);
    // }
    // run_step.dependOn(&run_cmd.step);
}
