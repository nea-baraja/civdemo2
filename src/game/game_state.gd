extends Node
class_name GameState

signal state_changed
signal log_message(msg)

var data: GameData
var tiles: Dictionary = {} # key -> MapTileData
var regions: Array = [] # Array[RegionData]
var buildings: Dictionary = {} # key -> BuildingInstance

var placement_radius: int = 4
var next_region_id: int = 1

var food_points: int = 8
var prod_points: int = 8
var gold: int = 10

var phase: String = "decision" # decision / production
var production_rounds: int = 10

func _ready() -> void:
    initialize()

func initialize() -> void:
    if data == null:
        data = GameData.new()
        data.load_data()
    if regions.size() == 0:
        _create_start_region()

func _key(coord: Vector2i) -> String:
    return str(coord.x) + "," + str(coord.y)

func get_tile(coord: Vector2i) -> MapTileData:
    return tiles.get(_key(coord), null)

func _create_start_region() -> void:
    # Place standard hex at center
    var shape = null
    for s in data.region_shapes:
        if s["id"] == "hex7":
            shape = s
            break
    if shape == null:
        return
    var region = _spawn_region(shape["name"])
    _apply_region_cells(region, shape["cells"], Vector2i.ZERO, 0)
    _assign_region_tiles(region, shape["terrain_weights"])
    _finalize_region(region)

func _spawn_region(name: String) -> RegionData:
    var r = RegionData.new()
    r.id = next_region_id
    next_region_id += 1
    r.name = name
    r.color = Color.from_hsv(randf(), 0.4 + randf() * 0.4, 0.8)
    regions.append(r)
    return r

func _apply_region_cells(region: RegionData, cells: Array, origin: Vector2i, rotation_steps: int) -> void:
    region.cells.clear()
    for c in cells:
        var v = Vector2i(c[0], c[1])
        v = Hex.rotate60(v, rotation_steps)
        v = Hex.add(v, origin)
        region.cells.append(v)

func _assign_region_tiles(region: RegionData, terrain_weights: Dictionary) -> void:
    region.tiles.clear()
    for c in region.cells:
        var terrain = _pick_weighted(terrain_weights)
        var t = MapTileData.new(c, terrain, region.id)
        region.tiles.append(t)

func _finalize_region(region: RegionData) -> void:
    for t in region.tiles:
        tiles[_key(t.coord)] = t
    emit_signal("state_changed")

func can_place_region(cells: Array) -> bool:
    for c in cells:
        if Hex.distance(Vector2i.ZERO, c) > placement_radius:
            return false
        if tiles.has(_key(c)):
            return false
    return true

func place_region(shape: Dictionary, origin: Vector2i, rotation_steps: int) -> bool:
    var temp_cells: Array = []
    for c in shape["cells"]:
        var v = Vector2i(c[0], c[1])
        v = Hex.rotate60(v, rotation_steps)
        v = Hex.add(v, origin)
        temp_cells.append(v)
    if not can_place_region(temp_cells):
        return false
    var region = _spawn_region(shape["name"])
    region.cells = temp_cells
    _assign_region_tiles(region, shape["terrain_weights"])
    _finalize_region(region)
    return true

func can_place_building(coord: Vector2i, building_id: String) -> bool:
    var tile = get_tile(coord)
    if tile == null:
        return false
    if tile.building_id != "":
        return false
    if not data.can_build_on(building_id, tile.terrain_id):
        return false
    var b = data.get_building(building_id)
    if b.is_empty():
        return false
    if building_id == "irrigation" and not is_adjacent_to_water_or_river(coord):
        return false
    if b["kind"] == "building":
        # no duplicate building in same region
        for t in regions_by_id(tile.region_id).tiles:
            if t.building_id == building_id:
                return false
    return true

func place_building(coord: Vector2i, building_id: String) -> bool:
    if not can_place_building(coord, building_id):
        return false
    var b = data.get_building(building_id)
    if b["kind"] == "building" and prod_points < b["cost_prod"]:
        return false
    if b["kind"] == "building":
        prod_points -= b["cost_prod"]
    var tile = get_tile(coord)
    tile.building_id = building_id
    buildings[_key(coord)] = BuildingInstance.new(building_id)
    emit_signal("state_changed")
    return true

func remove_building(coord: Vector2i) -> void:
    var tile = get_tile(coord)
    if tile == null:
        return
    tile.building_id = ""
    buildings.erase(_key(coord))
    emit_signal("state_changed")

func regions_by_id(id: int) -> RegionData:
    for r in regions:
        if r.id == id:
            return r
    return null

func _pick_weighted(weights: Dictionary) -> String:
    var total = 0
    for k in weights.keys():
        total += int(weights[k])
    var roll = randi() % max(total, 1)
    var acc = 0
    for k in weights.keys():
        acc += int(weights[k])
        if roll < acc:
            return String(k)
    return String(weights.keys()[0])

func is_adjacent_to_water_or_river(coord: Vector2i) -> bool:
    var tile = get_tile(coord)
    if tile == null:
        return false
    for n in Hex.neighbors():
        var nc = Hex.add(coord, n)
        var nt = get_tile(nc)
        if nt == null:
            return true # water/lake
        if nt.region_id != tile.region_id:
            return true # river between regions
    return false

func get_neighbors_within(coord: Vector2i, range: int) -> Array:
    var result: Array = []
    for c_key in tiles.keys():
        var parts = c_key.split(",")
        var c = Vector2i(int(parts[0]), int(parts[1]))
        if Hex.distance(coord, c) <= range:
            result.append(c)
    return result

func reset_production_buffs() -> void:
    for r in regions:
        r.pioneer = 0.0
        r.build = 0.0

func add_region_buff(region_id: int, pioneer: float, build: float) -> void:
    var r = regions_by_id(region_id)
    if r == null:
        return
    r.pioneer += pioneer
    r.build += build
