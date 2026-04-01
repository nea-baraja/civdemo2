extends RefCounted
class_name MapTileData

var coord: Vector2i
var terrain_id: String = "plains"
var region_id: int = -1
var building_id: String = ""

func _init(c: Vector2i, terrain: String, r_id: int) -> void:
    coord = c
    terrain_id = terrain
    region_id = r_id
