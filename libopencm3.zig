const std = @import("std");
const stm = @import("stm32.zig");

const path_libopencm3 = struct {
    fn dirname() []const u8 {
        return std.fs.path.dirname(@src().file) orelse "./stm32-zig-build";
    }
}.dirname();

pub fn libopencm3(b: *std.Build, chip: stm.STM32Chip) !struct { *std.Build.Step, std.Build.LazyPath } {

    // Build the library object file
    const verbose_str = switch (b.verbose) {
        true => "",
        false => " > /dev/null",
    };
    const make_command: []const u8 = try std.mem.concat(b.allocator, u8, &[_][]const u8{
        "make TARGETS=", chip.chip.opencm3target, " -s V=0 -C ",
        b.path(try std.mem.concat(b.allocator, u8, &[_][]const u8{
            path_libopencm3, "/libopencm3",
        })).getPath(b),
        verbose_str,
    });
    defer b.allocator.free(make_command);

    const opencm3_build = b.addSystemCommand(&.{ "sh", "-c" });
    opencm3_build.addArg(make_command);

    const path = try std.fmt.allocPrint(
        b.allocator,
        "{s}/libopencm3/lib/libopencm3_{s}.a",
        .{ path_libopencm3, chip.chip.family },
    );

    return .{ &opencm3_build.step, b.path(path) };
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

pub fn splitDefines(allocator: std.mem.Allocator, defines: []const u8) ![]const []const u8 {
    // Given a string of space-separated defines, return an array of string defines
    var tokens = std.mem.tokenizeScalar(u8, defines, ' ');
    var list = std.ArrayList([]const u8).init(allocator);

    while (tokens.next()) |token| {
        try list.append(token);
    }

    return list.toOwnedSlice();
}
