extends Node
class_name GameData

var data: Dictionary = {}
var building_by_id: Dictionary = {}
var terrain_by_id: Dictionary = {}
var build_rules: Dictionary = {}
var region_shapes: Array = []

func load_data() -> void:
    var path = "res://src/data/game_data.json"
    var file = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Failed to load game data")
        return
    var text = file.get_as_text()
    var json = JSON.new()
    var err = json.parse(text)
    if err != OK:
        # Strip UTF-8 BOM if present
        text = text.trim_prefix("\ufeff")
        err = json.parse(text)
    if err != OK:
        push_error("Invalid game data JSON")
        return
    data = json.data
    if typeof(data) != TYPE_DICTIONARY:
        push_error("Invalid game data JSON")
        return
    print("[GameData] Loaded game_data.json")
    building_by_id.clear()
    for b in data.get("buildings", []):
        building_by_id[b["id"]] = b
    terrain_by_id.clear()
    for t in data.get("terrains", []):
        terrain_by_id[t["id"]] = t
    build_rules.clear()
    for r in data.get("terrain_build_rules", []):
        build_rules[r["building_id"]] = r["terrains"]
    region_shapes = data.get("region_shapes", [])
    print("[GameData] terrains=%d buildings=%d shapes=%d" % [terrain_by_id.size(), building_by_id.size(), region_shapes.size()])

func get_building(id: String) -> Dictionary:
    return building_by_id.get(id, {})

func can_build_on(building_id: String, terrain_id: String) -> bool:
    if not build_rules.has(building_id):
        return true
    return terrain_id in build_rules[building_id]

func get_terrain(id: String) -> Dictionary:
    return terrain_by_id.get(id, {})
