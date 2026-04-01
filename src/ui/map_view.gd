extends Node2D
class_name MapView

signal tile_clicked(coord)

var state: GameState
var hex_size: float = 28.0
var selected_coord: Vector2i = Vector2i(9999, 9999)

var preview_cells: Array = []
var preview_valid: bool = false

func _ready() -> void:
	set_process_unhandled_input(true)

func set_state(gs: GameState) -> void:
	state = gs
	if state != null:
		state.state_changed.connect(_on_state_changed)

func set_preview(cells: Array, valid: bool) -> void:
	preview_cells = cells
	preview_valid = valid
	queue_redraw()

func clear_preview() -> void:
	preview_cells = []
	queue_redraw()

func _on_state_changed() -> void:
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var coord = Hex.world_to_axial(to_local(event.position), hex_size)
		emit_signal("tile_clicked", coord)

func _draw() -> void:
	if state == null:
		return
	# Draw existing tiles
	for key in state.tiles.keys():
		var parts = key.split(",")
		var coord = Vector2i(int(parts[0]), int(parts[1]))
		var tile = state.get_tile(coord)
		var terrain = state.data.get_terrain(tile.terrain_id)
		var color = Color(terrain["color"]) if terrain.has("color") else Color(0.7, 0.7, 0.7)
		_draw_hex(coord, color)
		if tile.building_id != "":
			_draw_building_icon(coord, tile.building_id)

	# Draw preview
	for c in preview_cells:
		var pcolor = Color(0.2, 0.8, 0.3, 0.4) if preview_valid else Color(0.9, 0.2, 0.2, 0.4)
		_draw_hex(c, pcolor, true)

	# Draw selection
	if state.tiles.has(state._key(selected_coord)):
		_draw_hex(selected_coord, Color(1, 1, 1, 0.15), true, 3)

func _draw_hex(coord: Vector2i, color: Color, filled: bool = true, width: int = 1) -> void:
	var center = Hex.axial_to_world(coord, hex_size)
	var pts: PackedVector2Array = []
	for i in range(6):
		var angle = deg_to_rad(60 * i - 30)
		pts.append(center + Vector2(cos(angle), sin(angle)) * hex_size)
	if filled:
		draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.1, 0.1, 0.1, 0.6), width)

func _draw_building_icon(coord: Vector2i, building_id: String) -> void:
	var center = Hex.axial_to_world(coord, hex_size)
	var color = Color(0.2, 0.2, 0.2)
	draw_circle(center, hex_size * 0.25, color)
	var font = ThemeDB.get_fallback_font()
	if font != null:
		draw_string(font, center + Vector2(-6, 4), building_id.left(1).to_upper())
