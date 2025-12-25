const std = @import("std");
const testing = @import("testing");
const math = @import("math");

test {
    testing.refAllDeclsRecursive(math);
}
