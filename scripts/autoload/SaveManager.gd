extends Node
## 최대 3개 슬롯의 게임 저장/불러오기 및 환경설정 관리 싱글톤 (Autoload: SaveManager)

const MAX_SLOTS: int = 3
const SAVE_PATH_TEMPLATE: String = "user://save_slot_%d.json"
const SETTINGS_PATH: String = "user://settings.json"

signal save_slots_updated()
signal settings_updated()

var active_slot: int = 1

# --- 환경설정 ---
var master_volume: float = 1.0
var bgm_volume: float = 0.8
var sfx_volume: float = 0.8
var fullscreen: bool = false


func _ready() -> void:
	load_settings()
	apply_settings()


func get_slot_path(slot_index: int) -> String:
	return SAVE_PATH_TEMPLATE % clampi(slot_index, 1, MAX_SLOTS)


func has_save(slot_index: int) -> bool:
	return FileAccess.file_exists(get_slot_path(slot_index))


## 슬롯 요약 정보를 반환합니다. ({exists, slot, year, season, month, day_of_month, total_day, phase, gold, food, materials, wall_hp, wall_max_hp, saved_at})
func get_slot_summary(slot_index: int) -> Dictionary:
	var path: String = get_slot_path(slot_index)
	if not FileAccess.file_exists(path):
		return {"exists": false, "slot": slot_index}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": false, "slot": slot_index}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"exists": false, "slot": slot_index}

	var data: Dictionary = parsed
	var gd: Dictionary = data.get("global_data", {})
	var tm: Dictionary = data.get("time_manager", {})
	var res: Dictionary = gd.get("resources", {})

	return {
		"exists": true,
		"slot": slot_index,
		"year": int(tm.get("current_year", 1)),
		"season": int(tm.get("current_season", TimeManager.Season.SPRING)),
		"month": int(tm.get("current_month", 1)),
		"day_of_month": int(tm.get("current_day_of_month", 1)),
		"total_day": int(gd.get("current_day", 1)),
		"phase": int(gd.get("current_phase", GlobalData.GamePhase.MANAGEMENT)),
		"gold": int(res.get("gold", 0)),
		"food": int(res.get("food", 0)),
		"materials": int(res.get("materials", 0)),
		"wall_hp": int(gd.get("wall_hp", 100)),
		"wall_max_hp": int(gd.get("wall_max_hp", 100)),
		"saved_at": str(data.get("saved_at", "")),
	}


func save_to_slot(slot_index: int) -> bool:
	var idx: int = clampi(slot_index, 1, MAX_SLOTS)
	active_slot = idx

	var payload: Dictionary = {
		"version": 1,
		"slot": idx,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"global_data": {
			"current_phase": int(GlobalData.current_phase),
			"current_day": GlobalData.current_day,
			"last_management_day": GlobalData.last_management_day,
			"last_settled_day": GlobalData.last_settled_day,
			"resources": GlobalData.resources.duplicate(true),
			"citizen_morale": GlobalData.citizen_morale,
			"population": GlobalData.population,
			"max_population": GlobalData.max_population,
			"farm_level": GlobalData.farm_level,
			"lumber_mill_level": GlobalData.lumber_mill_level,
			"wall_max_hp": GlobalData.wall_max_hp,
			"wall_hp": GlobalData.wall_hp,
			"wall_level": GlobalData.wall_level,
			"defense_wave": GlobalData.defense_wave,
			"outpost_weakened_stacks": GlobalData.outpost_weakened_stacks,
			"defense_wall_atk_bonus": GlobalData.defense_wall_atk_bonus,
			"base_tower_atk_level": GlobalData.base_tower_atk_level,
			"base_tower_spd_level": GlobalData.base_tower_spd_level,
			"owned_towers": GlobalData.owned_towers.duplicate(),
			"equipped_tower_slots": GlobalData.equipped_tower_slots.duplicate(),
			"completed_research_ids": GlobalData.completed_research_ids.duplicate(),
			"territory_debuff_name": GlobalData.territory_debuff_name,
			"territory_debuff_rate": GlobalData.territory_debuff_rate,
			"territory_debuff_days": GlobalData.territory_debuff_days,
			"rebellion_risk": GlobalData.rebellion_risk,
			"rebellion_suppression_active": GlobalData.rebellion_suppression_active,
			"bad_choice_streak": GlobalData.bad_choice_streak,
			"field_dungeon_state": GlobalData.field_dungeon_state.duplicate(true),
			"upcoming_defense_elements": GlobalData.upcoming_defense_elements.duplicate(),
			"dungeon_floor": GlobalData.dungeon_floor,
			"next_hero_uid": GlobalData.next_hero_uid,
			"hero_roster": GlobalData.hero_roster.duplicate(true),
			"next_equip_inst_id": GlobalData.next_equip_inst_id,
			"equipment_inventory": GlobalData.equipment_inventory.duplicate(true),
			"item_inventory": GlobalData.item_inventory.duplicate(true),
			"party_presets": GlobalData.party_presets.duplicate(true),
			"selected_party_index": GlobalData.selected_party_index,
			"auto_battle_mode": GlobalData.auto_battle_mode,
			"battle_speed_mult": GlobalData.battle_speed_mult,
			"run_stats": GlobalData.run_stats.duplicate(true),
			"victory_achieved": GlobalData.victory_achieved,
			"is_endless_mode": GlobalData.is_endless_mode,
		},
		"time_manager": {
			"current_year": TimeManager.current_year,
			"current_month": TimeManager.current_month,
			"current_season": int(TimeManager.current_season),
			"current_day_of_month": TimeManager.current_day_of_month,
		},
	}

	var file := FileAccess.open(get_slot_path(idx), FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	save_slots_updated.emit()
	return true


func load_from_slot(slot_index: int) -> bool:
	var idx: int = clampi(slot_index, 1, MAX_SLOTS)
	var path: String = get_slot_path(idx)
	if not FileAccess.file_exists(path):
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false

	var data: Dictionary = parsed
	var gd: Dictionary = data.get("global_data", {})
	var tm: Dictionary = data.get("time_manager", {})

	active_slot = idx

	TimeManager.current_year = int(tm.get("current_year", 1))
	TimeManager.current_month = int(tm.get("current_month", 1))
	TimeManager.current_season = int(tm.get("current_season", 0)) as TimeManager.Season
	TimeManager.current_day_of_month = int(tm.get("current_day_of_month", 1))

	GlobalData.current_day = int(gd.get("current_day", 1))
	GlobalData.last_management_day = int(gd.get("last_management_day", -1))
	GlobalData.last_settled_day = int(gd.get("last_settled_day", -1))
	GlobalData.resources = gd.get("resources", GlobalData.resources).duplicate(true)
	GlobalData.citizen_morale = int(gd.get("citizen_morale", 70))
	GlobalData.population = int(gd.get("population", 10))
	GlobalData.max_population = int(gd.get("max_population", 20))
	GlobalData.farm_level = maxi(1, int(gd.get("farm_level", 1)))
	GlobalData.lumber_mill_level = maxi(1, int(gd.get("lumber_mill_level", 1)))
	GlobalData.wall_max_hp = int(gd.get("wall_max_hp", 100))
	GlobalData.wall_hp = int(gd.get("wall_hp", 100))
	GlobalData.wall_level = int(gd.get("wall_level", 1))
	GlobalData.defense_wave = int(gd.get("defense_wave", 1))
	GlobalData.outpost_weakened_stacks = maxi(0, int(gd.get("outpost_weakened_stacks", 0)))
	GlobalData.defense_wall_atk_bonus = maxi(0, int(gd.get("defense_wall_atk_bonus", 0)))
	GlobalData.base_tower_atk_level = maxi(1, int(gd.get("base_tower_atk_level", 1)))
	GlobalData.base_tower_spd_level = maxi(1, int(gd.get("base_tower_spd_level", 1)))

	GlobalData.owned_towers.clear()
	for tid in gd.get("owned_towers", []):
		GlobalData.owned_towers.append(str(tid))

	GlobalData.equipped_tower_slots = ["", "", ""]
	var raw_tslots: Variant = gd.get("equipped_tower_slots", [])
	if typeof(raw_tslots) == TYPE_ARRAY:
		for i in range(mini((raw_tslots as Array).size(), GlobalData.MAX_TOWER_SLOTS)):
			GlobalData.equipped_tower_slots[i] = str(raw_tslots[i])

	GlobalData.completed_research_ids.clear()
	for rid in gd.get("completed_research_ids", []):
		GlobalData.completed_research_ids.append(str(rid))

	GlobalData.territory_debuff_name = str(gd.get("territory_debuff_name", ""))
	GlobalData.territory_debuff_rate = float(gd.get("territory_debuff_rate", 0.0))
	GlobalData.territory_debuff_days = maxi(0, int(gd.get("territory_debuff_days", 0)))
	GlobalData.rebellion_risk = clampi(int(gd.get("rebellion_risk", 0)), 0, 10)
	GlobalData.rebellion_suppression_active = bool(gd.get("rebellion_suppression_active", false))
	GlobalData.bad_choice_streak = maxi(0, int(gd.get("bad_choice_streak", 0)))

	var raw_fstate: Variant = gd.get("field_dungeon_state", {})
	GlobalData.field_dungeon_state = (raw_fstate as Dictionary).duplicate(true) if typeof(raw_fstate) == TYPE_DICTIONARY else {}

	GlobalData.upcoming_defense_elements.clear()
	for el in gd.get("upcoming_defense_elements", []):
		GlobalData.upcoming_defense_elements.append(str(el))

	GlobalData.dungeon_floor = int(gd.get("dungeon_floor", 1))
	GlobalData.next_hero_uid = maxi(1, int(gd.get("next_hero_uid", 1)))
	GlobalData.next_equip_inst_id = maxi(1, int(gd.get("next_equip_inst_id", 1)))

	var raw_inv: Variant = gd.get("equipment_inventory", [])
	GlobalData.equipment_inventory.clear()
	if typeof(raw_inv) == TYPE_ARRAY and not (raw_inv as Array).is_empty():
		var max_inst_id: int = 0
		for eq_item in raw_inv:
			if typeof(eq_item) == TYPE_DICTIONARY:
				var iid: int = int(eq_item.get("inst_id", max_inst_id + 1))
				max_inst_id = maxi(max_inst_id, iid)
				GlobalData.equipment_inventory.append({
					"inst_id": iid,
					"equip_id": str(eq_item.get("equip_id", "")),
				})
		GlobalData.next_equip_inst_id = maxi(GlobalData.next_equip_inst_id, max_inst_id + 1)
	else:
		GlobalData.init_starter_equipment()

	var raw_items: Variant = gd.get("item_inventory", {})
	GlobalData.item_inventory.clear()
	if typeof(raw_items) == TYPE_DICTIONARY and not (raw_items as Dictionary).is_empty():
		var item_dict: Dictionary = raw_items
		for iid in item_dict:
			var cnt: int = int(item_dict[iid])
			if cnt > 0:
				GlobalData.item_inventory[str(iid)] = cnt
	else:
		GlobalData.init_starter_items()

	var raw_roster: Variant = gd.get("hero_roster", [])
	GlobalData.hero_roster.clear()
	if typeof(raw_roster) == TYPE_ARRAY and not (raw_roster as Array).is_empty():
		var max_uid: int = 0
		for item in raw_roster:
			if typeof(item) == TYPE_DICTIONARY:
				var inst: Dictionary = GlobalData.create_hero_instance(item)
				if item.has("uid"):
					inst["uid"] = int(item["uid"])
				max_uid = maxi(max_uid, int(inst["uid"]))
				GlobalData.hero_roster.append(inst)
		GlobalData.next_hero_uid = maxi(GlobalData.next_hero_uid, max_uid + 1)
	else:
		GlobalData.init_starter_roster()

	GlobalData.auto_battle_mode = clampi(int(gd.get("auto_battle_mode", GlobalData.AutoBattleMode.MANUAL)), 0, 2)
	GlobalData.battle_speed_mult = clampf(float(gd.get("battle_speed_mult", 1.0)), 1.0, 3.0)
	GlobalData.reset_run_stats()
	var raw_stats: Variant = gd.get("run_stats", {})
	if typeof(raw_stats) == TYPE_DICTIONARY:
		for k in GlobalData.run_stats.keys():
			GlobalData.run_stats[k] = maxi(0, int((raw_stats as Dictionary).get(k, 0)))
	GlobalData.victory_achieved = bool(gd.get("victory_achieved", false))
	GlobalData.is_endless_mode = bool(gd.get("is_endless_mode", false))
	var raw_presets: Variant = gd.get("party_presets", [])
	GlobalData._init_party_presets()
	if typeof(raw_presets) == TYPE_ARRAY and (raw_presets as Array).size() > 0:
		for i in range(mini((raw_presets as Array).size(), GlobalData.MAX_PARTY_PRESETS)):
			var raw_p: Variant = raw_presets[i]
			if typeof(raw_p) == TYPE_DICTIONARY:
				GlobalData.party_presets[i]["name"] = str(raw_p.get("name", "%d번 파티" % (i + 1)))
				var clean_slots: Dictionary = {}
				var raw_slots: Variant = raw_p.get("slots", {})
				if typeof(raw_slots) == TYPE_DICTIONARY:
					for k in (raw_slots as Dictionary):
						clean_slots[str(k)] = int(raw_slots[k])
				GlobalData.party_presets[i]["slots"] = clean_slots
	else:
		GlobalData.auto_fill_party_preset(0)
	GlobalData.select_party_preset(int(gd.get("selected_party_index", 0)))

	GlobalData.current_phase = int(gd.get("current_phase", 0)) as GlobalData.GamePhase

	GlobalData.notify_all_changed()
	TimeManager.date_changed.emit(TimeManager.current_year, TimeManager.current_season, TimeManager.current_day_of_month)
	TimeManager.season_changed.emit(TimeManager.current_season)
	TimeManager.time_updated.emit()
	return true


func start_new_game_in_slot(slot_index: int) -> void:
	var idx: int = clampi(slot_index, 1, MAX_SLOTS)
	active_slot = idx
	TimeManager.reset_time()
	save_to_slot(idx)


func delete_slot(slot_index: int) -> void:
	var path: String = get_slot_path(slot_index)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		save_slots_updated.emit()


# --- 설정 저장/불러오기/적용 ---
func save_settings(p_master: float, p_bgm: float, p_sfx: float, p_fullscreen: bool) -> void:
	master_volume = clampf(p_master, 0.0, 1.0)
	bgm_volume = clampf(p_bgm, 0.0, 1.0)
	sfx_volume = clampf(p_sfx, 0.0, 1.0)
	fullscreen = p_fullscreen

	var payload: Dictionary = {
		"master_volume": master_volume,
		"bgm_volume": bgm_volume,
		"sfx_volume": sfx_volume,
		"fullscreen": fullscreen,
	}

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))

	apply_settings()
	settings_updated.emit()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	master_volume = clampf(float(data.get("master_volume", 1.0)), 0.0, 1.0)
	bgm_volume = clampf(float(data.get("bgm_volume", 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", 0.8)), 0.0, 1.0)
	fullscreen = bool(data.get("fullscreen", false))


func apply_settings() -> void:
	_apply_bus_volume("Master", master_volume)
	_apply_bus_volume("BGM", bgm_volume)
	_apply_bus_volume("SFX", sfx_volume)

	var target_mode: DisplayServer.WindowMode = (
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if DisplayServer.window_get_mode() != target_mode:
		DisplayServer.window_set_mode(target_mode)


func _apply_bus_volume(bus_name: String, linear_vol: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return
	AudioServer.set_bus_mute(bus_idx, linear_vol <= 0.001)
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(maxf(linear_vol, 0.0001)))
