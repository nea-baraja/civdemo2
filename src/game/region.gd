extends RefCounted
class_name RegionData

var id: int = -1
var name: String = ""
var cells: Array = [] # Array[Vector2i]
var tiles: Array = [] # MapTileData refs
var color: Color = Color.WHITE

# Temporary buffs during production
var pioneer: float = 0.0
var build: float = 0.0

func non_empty_tiles() -> int:
    var count = 0
    for t in tiles:
        if t.building_id != "":
            count += 1
    return count
