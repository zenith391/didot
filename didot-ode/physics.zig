const c = @cImport({
    @cDefine("dSINGLE", "1");
    @cInclude("ode/ode.h");
}); 

pub const World = struct {
    id: c.dWorldID,

    pub fn create() World {
        const id = c.dWorldCreate();
        return World {
            .id = id
        };
    }

    pub fn deinit(self: *World) void {
        c.dWorldDestroy(self.id);
    }
};
