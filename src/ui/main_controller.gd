extends Node2D
class_name MainController

@onready var map_view: MapView = $MapView
@onready var resources_label: Label = $CanvasLayer/UIPanel/Margin/VBox/Resources
@onready var phase_label: Label = $CanvasLayer/UIPanel/Margin/VBox/Phase
@onready var info_label: Label = $CanvasLayer/UIPanel/Margin/VBox/Info
@onready var region_list: ItemList = $CanvasLayer/UIPanel/Margin/VBox/RegionBox/RegionList
@onready var building_list: ItemList = $CanvasLayer/UIPanel/Margin/VBox/BuildingBox/BuildingList
@onready var improve_list: ItemList = $CanvasLayer/UIPanel/Margin/VBox/ImproveBox/ImproveList
@onready var log_box: TextEdit = $CanvasLayer/UIPanel/Margin/VBox/Log

var state: GameState
var shop: ShopSystem
var production: ProductionSystem

var mode: String = "none" # none, place_region, place_building, place_improve
var selected_region_offer: int = -1
var selected_building_offer: int = -1
var selected_improve_id: String = ""
var rotation_steps: int = 0

func _ready() -> void:
    randomize()
    state = GameState.new()
    add_child(state)
    state.initialize()

    shop = ShopSystem.new()
    add_child(shop)

    production = ProductionSystem.new()
    add_child(production)

    map_view.set_state(state)
    map_view.tile_clicked.connect(_on_tile_clicked)

    shop.refresh(state)
    _refresh_lists()
    _update_ui()
    print("[UI] region_list=%d building_list=%d improve_list=%d" % [region_list.item_count, building_list.item_count, improve_list.item_count])

func _process(_delta: float) -> void:
    if mode == "place_region" and selected_region_offer >= 0:
        var mouse = get_viewport().get_mouse_position()
        var local = map_view.to_local(mouse)
        var origin = Hex.world_to_axial(local, map_view.hex_size)
        var offer = shop.region_offers[selected_region_offer]
        var shape = offer["shape"]
        var cells: Array = []
        for c in shape["cells"]:
            var v = Vector2i(c[0], c[1])
            v = Hex.rotate60(v, rotation_steps)
            v = Hex.add(v, origin)
            cells.append(v)
        var valid = state.can_place_region(cells)
        map_view.set_preview(cells, valid)
    else:
        map_view.clear_preview()

func _refresh_lists() -> void:
    region_list.clear()
    for i in range(shop.region_offers.size()):
        var o = shop.region_offers[i]
        region_list.add_item("%s (花费 %d金)" % [o.shape["name"], o["cost_gold"]])

    building_list.clear()
    for b in shop.building_offers:
        building_list.add_item("%s (耗 %d生产)" % [b["name"], b["cost_prod"]])

    improve_list.clear()
    for b in shop.get_improvements(state):
        improve_list.add_item(b["name"])

func _update_ui() -> void:
    resources_label.text = "点数: 食物 %d | 生产 %d | 金币 %d" % [state.food_points, state.prod_points, state.gold]
    phase_label.text = "阶段: %s" % ("决策" if state.phase == "decision" else "生产")
    _update_info()

func _update_info() -> void:
    var sel = map_view.selected_coord
    var tile = state.get_tile(sel)
    if tile == null:
        info_label.text = "选中: 无"
        return
    var terrain = state.data.get_terrain(tile.terrain_id)
    var building = "空"
    if tile.building_id != "":
        building = state.data.get_building(tile.building_id)["name"]
    var terrain_name = terrain["name"] if terrain.has("name") else tile.terrain_id
    info_label.text = "选中: %s | 地形: %s | 建筑: %s" % [sel, terrain_name, building]

func _log(msg: String) -> void:
    log_box.text += msg + "\n"

func _on_tile_clicked(coord: Vector2i) -> void:
    map_view.selected_coord = coord
    _update_info()

    if mode == "place_region" and selected_region_offer >= 0:
        var offer = shop.region_offers[selected_region_offer]
        if state.gold < offer["cost_gold"]:
            _log("金币不足，无法购买区域")
            return
        var origin = coord
        var success = state.place_region(offer["shape"], origin, rotation_steps)
        if success:
            state.gold -= offer["cost_gold"]
            _log("放置区域: %s" % offer["shape"]["name"])
        else:
            _log("无法放置区域")
        _update_ui()
        return

    if mode == "place_building" and selected_building_offer >= 0:
        var b = shop.building_offers[selected_building_offer]
        var ok = state.place_building(coord, b["id"])
        if ok:
            _log("放置建筑: %s" % b["name"])
        else:
            _log("无法放置建筑")
        _update_ui()
        return

    if mode == "place_improve" and selected_improve_id != "":
        var ok2 = state.place_building(coord, selected_improve_id)
        if ok2:
            var b2 = state.data.get_building(selected_improve_id)
            _log("放置改良: %s" % b2["name"])
        else:
            _log("无法放置改良")
        _update_ui()
        return

func _on_region_list_item_selected(index: int) -> void:
    selected_region_offer = index
    mode = "place_region"

func _on_building_list_item_selected(index: int) -> void:
    selected_building_offer = index
    mode = "place_building"

func _on_improve_list_item_selected(index: int) -> void:
    var b = shop.get_improvements(state)[index]
    selected_improve_id = b["id"]
    mode = "place_improve"

func _on_rotate_pressed() -> void:
    rotation_steps = (rotation_steps + 1) % 6

func _on_refresh_pressed() -> void:
    shop.refresh(state)
    _refresh_lists()
    _log("商店已刷新")

func _on_production_pressed() -> void:
    if state.phase != "decision":
        return
    state.phase = "production"
    var result = production.run_production(state)
    var food_total = result.food
    var prod_total = result.prod
    var gold_gain = result.gold

    # Diminishing returns conversion
    var next_food = _diminish(food_total, 20)
    var next_prod = _diminish(prod_total, 20)

    # Leftover points -> gold
    state.gold += gold_gain
    state.gold += max(0, state.food_points) + max(0, state.prod_points)

    state.food_points = next_food
    state.prod_points = next_prod

    # Gold halves carry over
    state.gold = int(floor(state.gold * 0.5))

    _log("生产结束: 食物产出 %d, 生产产出 %d, 金币产出 %d" % [food_total, prod_total, gold_gain])
    _log("下回合点数: 食物 %d, 生产 %d, 金币 %d" % [state.food_points, state.prod_points, state.gold])

    state.phase = "decision"
    _update_ui()

func _diminish(x: int, k: int) -> int:
    if x <= 0:
        return 0
    return int(floor(float(x) / (1.0 + float(x) / float(k))))

func _on_demolish_pressed() -> void:
    var sel = map_view.selected_coord
    var tile = state.get_tile(sel)
    if tile == null or tile.building_id == "":
        _log("没有可拆除的建筑")
        return
    var b = state.data.get_building(tile.building_id)
    state.remove_building(sel)
    _log("拆除: %s" % b["name"])
    _update_ui()

func _on_expand_pressed() -> void:
    state.placement_radius += 1
    _log("可放置范围扩大到半径 %d" % state.placement_radius)
