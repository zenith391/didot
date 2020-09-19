const std = @import("std");
const zlm = @import("zlm");
const graphics = @import("didot-graphics");
const Mesh = graphics.Mesh;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const OBJError = error {
};

const Element = struct {
    posIdx: graphics.MeshElementType,
    normalIdx: usize
};

pub fn read_obj(allocator: *Allocator, path: []const u8) !Mesh {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(path, .{
        .read = true,
        .write = false
    });
    const reader = std.io.bufferedReader(file.reader()).reader();

    var vertices = ArrayList(zlm.Vec3).init(allocator);
    var normals = ArrayList(zlm.Vec3).init(allocator);
    var texCoords = ArrayList(zlm.Vec2).init(allocator);
    var elements = ArrayList(Element).init(allocator);

    defer vertices.deinit();
    defer elements.deinit();
    defer normals.deinit();
    defer texCoords.deinit();

    const text = try reader.readAllAlloc(allocator, std.math.maxInt(u64));
    defer allocator.free(text);
    var linesSplit = std.mem.split(text, "\n");

    while (true) {
        const line = if (linesSplit.next()) |s| s else break;
        var split = std.mem.split(line, " ");
        const command = split.next().?;
        if (std.mem.eql(u8, command, "v")) { // vertex (position)
            const xStr = split.next().?;
            const yStr = split.next().?;
            const zStr = split.next().?;
            //var wStr = "1.0";
            //if (split.next()) |w| {
            //  wStr = w;
            //}

            const x = try std.fmt.parseFloat(f32, xStr);
            const y = try std.fmt.parseFloat(f32, yStr);
            const z = try std.fmt.parseFloat(f32, zStr);
            try vertices.append(zlm.Vec3.new(x, y, z));
        } else if (std.mem.eql(u8, command, "vt")) { // vertex (texture coordinate)
            const uStr = split.next().?;
            const vStr = split.next().?;
            //const wStr = split.next().?;

            const u = try std.fmt.parseFloat(f32, uStr);
            const v = try std.fmt.parseFloat(f32, vStr);
            //const w = try std.fmt.parseFloat(f32, wStr);
            try texCoords.append(zlm.Vec2.new(u, v));
        } else if (std.mem.eql(u8, command, "vn")) { // vertex (normal)
            const xStr = split.next().?;
            const yStr = split.next().?;
            const zStr = split.next().?;

            const x = try std.fmt.parseFloat(f32, xStr);
            const y = try std.fmt.parseFloat(f32, yStr);
            const z = try std.fmt.parseFloat(f32, zStr);
            try normals.append(zlm.Vec3.new(x, y, z));
        } else if (std.mem.eql(u8, command, "f")) { // face
            while (true) {
                if (split.next()) |vertex| {
                    var faceSplit = std.mem.split(vertex, "/");
                    const posIdx = try std.fmt.parseInt(i32, faceSplit.next().?, 10);
                    const texIdx = try std.fmt.parseInt(i32, faceSplit.next().?, 10);
                    const normalIdx = try std.fmt.parseInt(i32, faceSplit.next().?, 10);
                    try elements.append(.{
                        .posIdx = @intCast(graphics.MeshElementType, posIdx-1),
                        .normalIdx = @intCast(usize, normalIdx-1),
                    });
                } else {
                    break;
                }
            }
        } else {
            //std.debug.warn("Unknown OBJ command: {}\n", .{command});
        }
    }

    var final = try allocator.alloc(f32, elements.items.len*8);
    defer allocator.free(final);
    var i: usize = 0;
    for (elements.items) |f| {
        const v = vertices.items[f.posIdx];
        const n = normals.items[f.normalIdx];
        // position
        final[i] = v.x;
        final[i+1] = v.y;
        final[i+2] = v.z;
        // normal
        final[i+3] = n.x;
        final[i+4] = n.y;
        final[i+5] = n.z;
        // texture coordinate
        final[i+6] = 0.0;
        final[i+7] = 0.0;
        i = i + 8;
    }

    return Mesh.create(final, null); // TODO simplify
}
