const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const src_dir = try std.fs.cwd().openDir("src", .{ .iterate = true });
    var iter = src_dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
        const dot = std.mem.indexOf(u8, entry.name, ".") orelse continue;
        const day = std.fmt.parseUnsigned(u8, entry.name[0..dot], 10) catch continue;
        try build_day(b, target, optimize, day);
    }
}

fn build_day(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, day: u8) !void {
    const exe = b.addExecutable(.{
        .name = b.fmt("{d}.zip", .{day}),
        .root_source_file = b.path(b.fmt("src/{d}.zig", .{day})),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step(b.fmt("{d}", .{day}), b.fmt("Run day {d}", .{day}));
    run_step.dependOn(&run_cmd.step);
}
