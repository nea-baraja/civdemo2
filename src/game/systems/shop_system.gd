extends Node
class_name ShopSystem

var region_offers: Array = []
var building_offers: Array = []

var region_offer_count: int = 3
var building_offer_count: int = 5
var region_cost_gold: int = 5

func refresh(state: GameState) -> void:
    region_offers.clear()
    building_offers.clear()

    print("[Shop] refresh: shapes=%d buildings=%d" % [state.data.region_shapes.size(), state.data.data.get("buildings", []).size()])
    # Regions
    for i in range(region_offer_count):
        var shape = state.data.region_shapes[randi() % state.data.region_shapes.size()]
        region_offers.append({
            "shape": shape,
            "cost_gold": region_cost_gold
        })

    # Buildings (exclude improvements)
    var candidates: Array = []
    for b in state.data.data.get("buildings", []):
        if b["kind"] == "building":
            candidates.append(b)
    for j in range(building_offer_count):
        var pick = candidates[randi() % candidates.size()]
        building_offers.append(pick)
    print("[Shop] offers: regions=%d buildings=%d" % [region_offers.size(), building_offers.size()])

func get_improvements(state: GameState) -> Array:
    var result: Array = []
    for b in state.data.data.get("buildings", []):
        if b["kind"] == "improvement":
            result.append(b)
    return result
