const std = @import("std");

extern fn app_panic_handler(msg_ptr: [*]const u8, msg_len: usize) noreturn;

pub const panic = std.debug.FullPanic(myPanic);

fn myPanic(msg: []const u8, ret_addr: ?usize) noreturn {
    _ = ret_addr;
    app_panic_handler(msg.ptr, msg.len);
}
