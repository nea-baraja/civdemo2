extends Object
class_name Hex

# Axial coordinates (q, r)
static func add(a: Vector2i, b: Vector2i) -> Vector2i:
    return Vector2i(a.x + b.x, a.y + b.y)

static func neighbors() -> Array:
    return [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]

static func distance(a: Vector2i, b: Vector2i) -> int:
    var dq = abs(a.x - b.x)
    var dr = abs(a.y - b.y)
    var ds = abs((-a.x - a.y) - (-b.x - b.y))
    return int((dq + dr + ds) / 2)

static func rotate60(offset: Vector2i, steps: int) -> Vector2i:
    var s = ((steps % 6) + 6) % 6
    var q = offset.x
    var r = offset.y
    var x = q
    var z = r
    var y = -x - z
    for i in range(s):
        var tmp = x
        x = -z
        z = -y
        y = -tmp
    return Vector2i(x, z)

static func axial_to_world(a: Vector2i, size: float) -> Vector2:
    # Pointy-top hex
    var x = size * (sqrt(3.0) * a.x + sqrt(3.0) / 2.0 * a.y)
    var y = size * (3.0 / 2.0 * a.y)
    return Vector2(x, y)

static func world_to_axial(pos: Vector2, size: float) -> Vector2i:
    var q = (sqrt(3.0) / 3.0 * pos.x - 1.0 / 3.0 * pos.y) / size
    var r = (2.0 / 3.0 * pos.y) / size
    return axial_round(Vector2(q, r))

static func axial_round(frac: Vector2) -> Vector2i:
    var q = frac.x
    var r = frac.y
    var x = q
    var z = r
    var y = -x - z
    var rx = round(x)
    var ry = round(y)
    var rz = round(z)

    var dx = abs(rx - x)
    var dy = abs(ry - y)
    var dz = abs(rz - z)

    if dx > dy and dx > dz:
        rx = -ry - rz
    elif dy > dz:
        ry = -rx - rz
    else:
        rz = -rx - ry
    return Vector2i(int(rx), int(rz))
