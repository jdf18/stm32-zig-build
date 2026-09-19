const std = @import("std");

pub fn splitDefines(allocator: std.mem.Allocator, defines: []const u8) ![]const []const u8 {
    // Given a string of space-separated defines, return an array of string defines
    var tokens = std.mem.tokenizeScalar(u8, defines, ' ');
    var list = std.ArrayList([]const u8).empty;

    while (tokens.next()) |token| {
        try list.append(allocator, token);
    }

    return list.toOwnedSlice(allocator);
}

pub fn concatSlices(allocator: std.mem.Allocator, sliceA: []const []const u8, sliceB: []const []const u8) ![]const []const u8 {
    // concatenate two arrays of strings
    var list = std.ArrayList([]const u8).empty;

    try list.appendSlice(allocator, sliceA);
    try list.appendSlice(allocator, sliceB);
    return list.toOwnedSlice(allocator);
}
