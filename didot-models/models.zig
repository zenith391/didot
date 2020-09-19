pub const obj = @import("obj.zig"); 

test "" {
    comptime {
        @import("std").meta.refAllDecls(obj);
    }
}
