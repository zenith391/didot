const std = @import("std");
const zlm = @import("zlm");
const graphics = @import("didot-graphics");
const Mesh = graphics.Mesh;
const Allocator = std.mem.Allocator;

const OBJError = error {
};

pub fn read_obj(allocator: *Allocator, path: []const u8) !Mesh {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(path, .{
        .read = true,
        .write = false
    });
    const reader = file.reader();

    var vertices = ArrayList(zlm.Vec3).init(allocator);

    while (true) {
        const line = try reader.readUntilDelimiterAlloc(allocator, '\n', std.math.max(u64));
        const split = std.mem.split(line, " ");
        const command = split.next().?;
        if (std.mem.eql(u8, command, "v")) {
            const xStr = split.next().?;
            const yStr = split.next().?;
            const zStr = split.next().?;
            //var wStr = "0";
            //if (split.next()) |w| {
            //  wStr = w;
            //}

            const x = std.fmt.parseFloat(f32, xStr);
            const y = std.fmt.parseFloat(f32, yStr);
            const z = std.fmt.parseFloat(f32, yStr);
            try vertices.append(zlm.Vec3.new(x, y, z));
        }
    }
} 
