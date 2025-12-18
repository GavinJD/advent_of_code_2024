const std = @import("std");

const DEBUG = false;

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) !void {
    log("Running build script...", .{});
    const allocator = std.heap.smp_allocator;

    // Standard target options allow the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});
    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});
    // It's also possible to define more custom flags to toggle optional features
    // of this build script using `b.option()`. All defined flags (including
    // target and optimize options) will be listed when running `zig build --help`
    // in this directory.

    // This creates a module, which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Zig modules are the preferred way of making Zig code available to consumers.
    // addModule defines a module that we intend to make available for importing
    // to our consumers. We must give it a name because a Zig package can expose
    // multiple modules and consumers will need to be able to specify which
    // module they want to access.
    const mod = b.addModule("aoc_2024", .{
        // The root source file is the "entry point" of this module. Users of
        // this module will only be able to access public declarations contained
        // in this file, which means that if you have declarations that you
        // intend to expose to consumers that were defined in other files part
        // of this module, you will have to make sure to re-export them from
        // the root file.
        .root_source_file = b.path("src/common/root.zig"),
        // Later on we'll use this module as the root module of a test executable
        // which requires us to specify a target.
        .target = target,
    });

    const DAYS = 25;
    var executables_len: usize = 0;
    var executables: [DAYS]*std.Build.Step.Compile = undefined;

    for (1..26) |day| {
        log("Checking day {}", .{day});
        const mod_name = try std.fmt.allocPrint(allocator, "day_{}", .{day});
        const filename = try std.fmt.allocPrint(allocator, "src/{s}.zig", .{mod_name});

        var file_exists = true;
        std.fs.cwd().access(filename, .{}) catch |err| switch (err) {
            std.posix.AccessError.FileNotFound => file_exists = false,
            else => return err,
        };

        log("File for day {} exists? {}", .{ day, file_exists });

        if (!file_exists) break;

        executables[executables_len] = b.addExecutable(.{
            .name = mod_name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(filename),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "aoc_2024", .module = mod },
                },
            }),
        });
        b.installArtifact(executables[executables_len]);
        executables_len += 1;
    }

    var chosen_step_idx: usize = undefined;

    const run_step = b.step("run", "Run the app");
    if (b.args) |args| {
        const requested_day = try std.fmt.parseInt(usize, args[0], 10);
        if (requested_day - 1 >= executables_len) {
            std.log.err("{} steps implemented so far, but request step {}", .{ executables_len, requested_day });
            return error.InvalidDay;
        }

        chosen_step_idx = requested_day - 1;
    } else {
        chosen_step_idx = executables_len - 1;
    }

    log("Chosen step index - {}", .{chosen_step_idx});

    const run_cmd = b.addRunArtifact(executables[chosen_step_idx]);
    if (b.args) |args| {
        if (args.len > 1)
            run_cmd.addArgs(args[1..]);
    }

    run_step.dependOn(&run_cmd.step);

    // By making the run step depend on the default step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    run_cmd.step.dependOn(b.getInstallStep());

    // Redefine exe's for a check step: https://zigtools.org/zls/guides/build-on-save/
    const check = b.step("check", "Check if everything compiles");

    for (0..executables_len) |i| {
        const check_exe = b.addExecutable(.{ .name = executables[i].name, .root_module = executables[i].root_module });
        check.dependOn(&check_exe.step);
    }

    // Creates an executable that will run `test` blocks from the provided module.
    // Here `mod` needs to define a target, which is why earlier we made sure to
    // set the releative field.
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    // A run step that will run the test executable.
    const run_mod_tests = b.addRunArtifact(mod_tests);

    // Creates an executable that will run `test` blocks from the executable's
    // root module. Note that test executables only test one module at a time,
    // hence why we have to create two separate ones.
    const exe_tests = b.addTest(.{
        .root_module = executables[chosen_step_idx].root_module,
    });

    // A run step that will run the second test executable.
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // A top level step for running all tests. dependOn can be called multiple
    // times and since the two run steps do not depend on one another, this will
    // make the two of them run in parallel.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    // Just like flags, top level steps are also listed in the `--help` menu.
    //
    // The Zig build system is entirely implemented in userland, which means
    // that it cannot hook into private compiler APIs. All compilation work
    // orchestrated by the build system will result in other Zig compiler
    // subcommands being invoked with the right flags defined. You can observe
    // these invocations when one fails (or you pass a flag to increase
    // verbosity) to validate assumptions and diagnose problems.
    //
    // Lastly, the Zig build system is relatively simple and self-contained,
    // and reading its source code will allow you to master it.
}

fn log(comptime format: []const u8, args: anytype) void {
    if (DEBUG) {
        std.log.debug(format, args);
    }
}
