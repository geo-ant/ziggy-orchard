const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("ziggy-orchard", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();
    //exe.addPackagePath("test-helpers","test-helpers/helpers.zig");

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // not sure if this is completely idiomatic, but I got it from
    // https://github.com/ziglang/zig/blob/6cc88458029759bbedcb4d949deb887d464cdd60/build.zig
    const test_suite = b.addTest("test-suite.zig");
    test_suite.addPackagePath("test-helpers", "test-helpers/helpers.zig");
    const tests_suite_step = b.step("test", "test suite for ziggy-orchard");
    tests_suite_step.dependOn(&test_suite.step);
}
