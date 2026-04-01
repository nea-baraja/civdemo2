extends Node
class_name ProductionSystem

func run_production(state: GameState) -> Dictionary:
    var totals = {"food": 0, "prod": 0, "gold": 0, "pioneer": 0, "build": 0}
    state.reset_production_buffs()

    for round in range(state.production_rounds):
        # Base progress
        for key in state.buildings.keys():
            var inst: BuildingInstance = state.buildings[key]
            inst.progress += 1

        # Precompute irrigation effects
        var farm_reduction: Dictionary = {}
        for key in state.buildings.keys():
            var inst_i: BuildingInstance = state.buildings[key]
            if inst_i.id != "irrigation":
                continue
            var coord = _key_to_coord(key)
            if not state.is_adjacent_to_water_or_river(coord):
                continue
            var neighbors = state.get_neighbors_within(coord, 1)
            for n in neighbors:
                var t = state.get_tile(n)
                if t != null and t.building_id == "farm":
                    farm_reduction[state._key(n)] = 1

        var round_pioneer_gain: Dictionary = {}
        var round_build_gain: Dictionary = {}

        # Resolve production
        for key in state.buildings.keys():
            var inst: BuildingInstance = state.buildings[key]
            var b = state.data.get_building(inst.id)
            var maxp = int(b["progress_max"])
            if inst.id == "farm" and farm_reduction.has(key):
                maxp = max(1, maxp - 1)
            # Allow multiple triggers per round
            while inst.progress >= maxp and maxp > 0:
                inst.progress -= maxp
                var out = b["outputs"] if b.has("outputs") else {}
                if out.has("food"):
                    var extra_food = _animal_mill_bonus(state, _key_to_coord(key))
                    totals.food += int(out["food"]) + extra_food
                if out.has("prod"):
                    totals.prod += int(out["prod"])
                if out.has("gold"):
                    totals.gold += int(out["gold"])
                if out.has("pioneer"):
                    totals.pioneer += int(out["pioneer"])
                    var reg = state.get_tile(_key_to_coord(key)).region_id
                    round_pioneer_gain[reg] = round_pioneer_gain.get(reg, 0) + int(out["pioneer"])
                if out.has("build"):
                    totals.build += int(out["build"])
                    var reg2 = state.get_tile(_key_to_coord(key)).region_id
                    round_build_gain[reg2] = round_build_gain.get(reg2, 0) + int(out["build"])

                # Special: pasture production boosts nearby animal mills
                if inst.id == "pasture":
                    _boost_animal_mills(state, _key_to_coord(key))

        # Apply pioneer/build gains to region buffs
        for reg_id in round_pioneer_gain.keys():
            state.add_region_buff(reg_id, float(round_pioneer_gain[reg_id]), 0.0)
        for reg_id in round_build_gain.keys():
            state.add_region_buff(reg_id, 0.0, float(round_build_gain[reg_id]))

        # Special: bone workshop / brick kiln gain progress when region gains
        for key in state.buildings.keys():
            var inst2: BuildingInstance = state.buildings[key]
            var t = state.get_tile(_key_to_coord(key))
            if t == null:
                continue
            if inst2.id == "bone_workshop":
                var addp = int(round_pioneer_gain.get(t.region_id, 0))
                inst2.progress += addp
            elif inst2.id == "brick_kiln":
                var addb = int(round_build_gain.get(t.region_id, 0))
                inst2.progress += addb

        # Region buffs produce and decay
        for r in state.regions:
            if r.pioneer > 0.0:
                totals.food += int(floor(r.pioneer))
            if r.build > 0.0:
                totals.prod += int(floor(r.build))
            var decay = 0.2 + 0.1 * r.non_empty_tiles()
            decay = clamp(decay, 0.0, 0.9)
            r.pioneer = max(0.0, r.pioneer * (1.0 - decay))
            r.build = max(0.0, r.build * (1.0 - decay))

    return totals

func _key_to_coord(key: String) -> Vector2i:
    var parts = key.split(",")
    return Vector2i(int(parts[0]), int(parts[1]))

func _animal_mill_bonus(state: GameState, farm_coord: Vector2i) -> int:
    var bonus = 0
    for key in state.buildings.keys():
        var inst: BuildingInstance = state.buildings[key]
        if inst.id != "animal_mill":
            continue
        var c = _key_to_coord(key)
        if Hex.distance(c, farm_coord) <= 2:
            bonus += 1
    return bonus

func _boost_animal_mills(state: GameState, pasture_coord: Vector2i) -> void:
    for key in state.buildings.keys():
        var inst: BuildingInstance = state.buildings[key]
        if inst.id != "animal_mill":
            continue
        var c = _key_to_coord(key)
        if Hex.distance(c, pasture_coord) <= 2:
            inst.progress += 1
