const std = @import("std");
const stm = @import("../../stm32.zig");

const splitDefines = stm.utils.splitDefines;

// @src needs to be inside a function scope which is why this is cursed
const path_libopencm3 = struct {
    fn dirname() []const u8 {
        return std.fs.path.dirname(std.fs.path.dirname(std.fs.path.dirname(@src().file).?).?) orelse "./stm32-zig-build";
    }
}.dirname();

pub fn linkLibopencm3(b: *std.Build, exe: *std.Build.Step.Compile, path: std.Build.LazyPath) void {
    exe.addObjectFile(path);
    exe.addIncludePath(b.path(path_libopencm3 ++ "/libopencm3/include")); 
}


pub fn addLibopencm3(b: *std.Build, chip: stm.STM32Chip) !struct { *std.Build.Step, std.Build.LazyPath } {

    // Build the library object file
    const verbose_str = switch (b.verbose) {
        true => "",
        false => " > /dev/null",
    };
    const make_command: []const u8 = try std.mem.concat(b.allocator, u8, &[_][]const u8{
        "make TARGETS=", chip.defines.opencm3target, " -s V=0 -C ",
        b.path(try std.mem.concat(b.allocator, u8, &[_][]const u8{
            path_libopencm3, "/libopencm3",
        })).getPath(b),
        verbose_str,
    });
    defer b.allocator.free(make_command);

    const opencm3_build = b.addSystemCommand(&.{ "sh", "-c" });
    opencm3_build.addArg(make_command);

    const name = try std.fmt.allocPrint(b.allocator, "build libopencm3 for {s}", .{
        chip.defines.id,
    });
    opencm3_build.step.name = name;

    const path = try std.fmt.allocPrint(
        b.allocator,
        "{s}/libopencm3/lib/libopencm3_{s}.a",
        .{ path_libopencm3, chip.defines.family },
    );

    return .{ &opencm3_build.step, b.path(path) };
}

pub fn addLibopencm3Linker(b: *std.Build, defines: []const []const u8) !std.Build.LazyPath {
    // generate a linker script for the model of processor being used
    const out_path = "linker.ld";

    // Use a C preprocessor to fill in values into the linker template provided by libopencm3
    //   Defines can be found using the genlink.py script in the DEFS mode.
    const run = b.addSystemCommand(&[_][]const u8{
        "zig", "cc",
        "-E",  "-P",
    });
    run.addArgs(defines);

    run.addArg(try std.mem.concat(b.allocator, u8, &[_][]const u8{
        path_libopencm3, "/libopencm3/ld/linker.ld.S",
    }));

    run.addArg("-o");
    const linker_script = run.addOutputFileArg(out_path);

    run.setName("Pre-process linker script");

    return linker_script;
}

pub fn clean(b: *std.Build) !*std.Build.Step {
    // Build the library object file
    const verbose_str = switch (b.verbose) {
        true => "",
        false => " > /dev/null",
    };
    const make_command: []const u8 = try std.mem.concat(b.allocator, u8, &[_][]const u8{
        "make clean -C ",
        b.path(try std.mem.concat(b.allocator, u8, &[_][]const u8{
            path_libopencm3, "/libopencm3",
        })).getPath(b),
        verbose_str,
    });
    defer b.allocator.free(make_command);

    const opencm3_clean = b.addSystemCommand(&.{ "sh", "-c" });
    opencm3_clean.addArg(make_command);

    return &opencm3_clean.step;
}

