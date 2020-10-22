comptime {
    @import("std").testing.refAllDecls(@This());
}

// this is very dirty code but is the only way for things to work correctly (i'll post issue on ziglang/zig later)
pub const graphics = @import("didot-opengl/graphics.zig");
pub const app = @import("didot-app/app.zig");
pub const image = @import("didot-image/image.zig");
pub const models = @import("didot-models/models.zig");
pub const objects = @import("didot-objects/objects.zig");

comptime {
    const testing = @import("std").testing;
    testing.refAllDecls(graphics);
    testing.refAllDecls(objects);
    testing.refAllDecls(app);
    testing.refAllDecls(models);
    testing.refAllDecls(image);
}
