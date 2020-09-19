comptime {
    @import("std").meta.refAllDecls(@This());
}

pub const graphics = @import("didot-graphics");
pub const app = @import("didot-app");
pub const image = @import("didot-image");
pub const models = @import("didot-models");
pub const objects = @import("didot-objects");

test "" {
    comptime {
        const meta = @import("std").meta;
        meta.refAllDecls(graphics);
        meta.refAllDecls(objects);
        meta.refAllDecls(app);
        meta.refAllDecls(models);
        meta.refAllDecls(image);
    }
}
