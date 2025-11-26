//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub fn exposed() void {
    return;
}

test "exposed exists" {
    exposed();
}

pub fn expose2() i32 {
    return 1;
}
