extends RefCounted
class_name BuildingInstance

var id: String
var progress: int = 0

func _init(b_id: String) -> void:
    id = b_id
