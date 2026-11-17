extends Node
## 전역 게임 데이터 및 상태 관리 싱글톤 (Autoload: GlobalData)
## 성벽 디펜스, 3x3 던전 오펜스, 내정 경영 간의 공유 상태를 관리합니다.

enum GamePhase {
	MANAGEMENT, ## 내정 경영 페이즈
	TOWN,       ## 마을 관리 페이즈
	DUNGEON,    ## 3x3 던전 오펜스 페이즈
	DEFENSE,    ## 성벽 디펜스 페이즈
	SETTLEMENT, ## 하루 정산 페이즈
}

# --- 시그널 ---
signal resources_changed(resources: Dictionary)
signal morale_changed(current_morale: int)
signal wall_hp_changed(current_hp: int, max_hp: int)
signal phase_changed(new_phase: GamePhase)
signal day_changed(new_day: int)
signal wall_destroyed()
signal game_reset()
signal roster_changed()
signal facilities_changed()
signal inventory_changed()
signal party_presets_changed()
signal battle_settings_changed()
signal towers_changed()
signal research_changed()
signal dungeon_state_changed()

enum AutoBattleMode {
	MANUAL = 0,        ## 수동
	AUTO_SAVE_ULT = 1, ## 자동 (궁극기 수동)
	FULL_AUTO = 2,     ## 완전 자동 (궁극기 포함)
}

# --- 게임 진행 상태 ---
var current_phase: GamePhase = GamePhase.MANAGEMENT
var current_day: int = 1
var last_management_day: int = -1
var last_settled_day: int = -1

# --- 내정 경영 자원 ---
const MAX_MORALE: int = 100
var resources: Dictionary = {
	"gold": 100,
	"wood": 50,
	"stone": 30,
	"food": 50,
	"materials": 40,
}
var citizen_morale: int = 70
var population: int = 10
var max_population: int = 20

# --- 마을 생산 시설 레벨 ---
var farm_level: int = 1
var lumber_mill_level: int = 1

# --- 성벽 디펜스 데이터 ---
const MAX_TOWER_SLOTS: int = 3
var wall_max_hp: int = 100
var wall_hp: int = 100
var wall_level: int = 1
var defense_wave: int = 1
var outpost_weakened_stacks: int = 0
var defense_wall_atk_bonus: int = 0
var base_tower_atk_level: int = 1
var base_tower_spd_level: int = 1
var owned_towers: Array[String] = []
var equipped_tower_slots: Array[String] = ["", "", ""]
var completed_research_ids: Array[String] = []

# --- 영지 단기 생산 디버프 & 반란 위험도 ---
var territory_debuff_name: String = ""
var territory_debuff_rate: float = 0.0
var territory_debuff_days: int = 0
var rebellion_risk: int = 0
var bad_choice_streak: int = 0

# --- 대형 던전(FIELD_GRID) 디펜스 주기 유지 상태 & 예상 적 속성 ---
var field_dungeon_state: Dictionary = {}
var upcoming_defense_elements: Array[String] = []

# --- 영웅 피로도 상수 (0 = 최상, >= 80 지침, 100 탈진) ---
const MAX_FATIGUE: int = 100
const FATIGUE_TIRED_THRESHOLD: int = 80

# --- 보유 영웅 로스터 ---
const STARTER_HERO_IDS: Array[String] = [
	"hero_militia",
	"hero_shieldbearer",
	"hero_archer",
	"hero_knight",
	"hero_priest",
]
var hero_roster: Array[Dictionary] = []
var next_hero_uid: int = 1

# --- 보유 장비 & 소비 아이템 인벤토리 ---
var equipment_inventory: Array[Dictionary] = []
var next_equip_inst_id: int = 1
var item_inventory: Dictionary = {} # item_id -> count: int

# --- 3x3 던전 오펜스 데이터 ---
const DUNGEON_GRID_SIZE: Vector2i = Vector2i(3, 3)
const MAX_PARTY_PRESETS: int = 5
const MAX_PARTY_SIZE: int = 5
const RANK_POSITION_BONUSES: Dictionary = {
	0: {
		"name": "전열",
		"tag": "선봉·철벽",
		"max_hp_pct": 0.15,
		"def_pct": 0.25,
		"summary": "전열 [선봉·철벽]: 최대HP +15%, 방어력 +25%",
	},
	1: {
		"name": "중열",
		"tag": "돌격·기동",
		"atk_pct": 0.12,
		"speed": 3.0,
		"crit_rate": 0.08,
		"summary": "중열 [돌격·기동]: 공격력 +12%, 속도 +3, 치명타 +8%",
	},
	2: {
		"name": "후열",
		"tag": "포격·지원",
		"dmg_bonus": 0.18,
		"crit_dmg": 0.25,
		"heal_pct": 0.15,
		"summary": "후열 [포격·지원]: 피해량 +18%, 치명피해 +25%, 치유량 +15%",
	},
}
var dungeon_floor: int = 1
## 3x3 그리드(인덱스 0~8)에 배치된 아군 유닛 데이터
var dungeon_party_grid: Array = []
## 최대 5개 오펜스 파티 프리셋: [{"name": "제1원정대", "slots": {"rank,row": uid}}]
var party_presets: Array[Dictionary] = []
var selected_party_index: int = 0

# --- 전투 자동/배속 설정 (전역 유지) ---
var auto_battle_mode: int = AutoBattleMode.MANUAL
var battle_speed_mult: float = 1.0


func _ready() -> void:
	_init_dungeon_grid()
	_init_party_presets()
	call_deferred("_init_starter_roster_if_empty")


func _init_dungeon_grid() -> void:
	dungeon_party_grid.resize(DUNGEON_GRID_SIZE.x * DUNGEON_GRID_SIZE.y)
	dungeon_party_grid.fill(null)


func _init_party_presets() -> void:
	party_presets.clear()
	for i in range(MAX_PARTY_PRESETS):
		party_presets.append({
			"name": "%d번 파티" % (i + 1),
			"slots": {},
		})
	selected_party_index = 0


# --- 자원 관리 ---
func get_resource(resource_key: String) -> int:
	return resources.get(resource_key, 0)


func add_resource(resource_key: String, amount: int) -> void:
	if amount == 0:
		return
	var current: int = resources.get(resource_key, 0)
	resources[resource_key] = max(0, current + amount)
	resources_changed.emit(resources.duplicate())


func can_afford(costs: Dictionary) -> bool:
	for key in costs:
		if get_resource(key) < costs[key]:
			return false
	return true


func spend_resources(costs: Dictionary) -> bool:
	if not can_afford(costs):
		return false
	for key in costs:
		resources[key] = get_resource(key) - costs[key]
	resources_changed.emit(resources.duplicate())
	return true


func add_morale(amount: int) -> void:
	if amount == 0:
		return
	citizen_morale = clampi(citizen_morale + amount, 0, MAX_MORALE)
	_evaluate_morale_territory_debuff()
	morale_changed.emit(citizen_morale)


## 자원, 사기("morale"), 성벽("wall_hp"), 반란위험("unrest") 증감 딕셔너리를 한 번에 적용합니다.
func apply_deltas(deltas: Dictionary) -> void:
	var res_changed: bool = false
	for key in deltas:
		var amount: int = int(deltas[key])
		if amount == 0:
			continue
		if key == "morale":
			add_morale(amount)
		elif key == "wall_hp":
			if amount > 0:
				repair_wall(amount)
			else:
				damage_wall(-amount)
		elif key == "unrest":
			add_rebellion_risk(amount)
		else:
			var current: int = resources.get(key, 0)
			resources[key] = max(0, current + amount)
			res_changed = true
	if res_changed:
		resources_changed.emit(resources.duplicate())


# --- 성벽 관리 ---
func damage_wall(amount: int) -> void:
	if amount <= 0 or wall_hp <= 0:
		return
	wall_hp = max(0, wall_hp - amount)
	wall_hp_changed.emit(wall_hp, wall_max_hp)
	if wall_hp == 0:
		wall_destroyed.emit()


func repair_wall(amount: int) -> void:
	if amount <= 0 or wall_hp >= wall_max_hp:
		return
	wall_hp = min(wall_max_hp, wall_hp + amount)
	wall_hp_changed.emit(wall_hp, wall_max_hp)


func upgrade_wall_max_hp(hp_gain: int = 30) -> void:
	if hp_gain <= 0:
		return
	wall_level += 1
	wall_max_hp += hp_gain
	wall_hp = min(wall_max_hp, wall_hp + hp_gain)
	wall_hp_changed.emit(wall_hp, wall_max_hp)
	facilities_changed.emit()


func upgrade_farm() -> void:
	farm_level += 1
	facilities_changed.emit()


func upgrade_lumber_mill() -> void:
	lumber_mill_level += 1
	facilities_changed.emit()


# --- 영웅 로스터 관리 ---
func _init_starter_roster_if_empty() -> void:
	if hero_roster.is_empty():
		init_starter_roster()
	if equipment_inventory.is_empty():
		init_starter_equipment()
	if item_inventory.is_empty():
		init_starter_items()


func init_starter_roster() -> void:
	hero_roster.clear()
	next_hero_uid = 1

	var added_ids: Dictionary = {}
	if DataManager != null and not DataManager.heroes.is_empty():
		for target_id in STARTER_HERO_IDS:
			for h in DataManager.heroes:
				if str(h.get("id", "")) == target_id and not added_ids.has(target_id):
					hero_roster.append(create_hero_instance(h))
					added_ids[target_id] = true
					break
		# 기본 ID가 부족하면 나머지 영웅에서 최대 5명까지 보충
		if hero_roster.size() < 5:
			for h in DataManager.heroes:
				var hid: String = str(h.get("id", ""))
				if hid == "hero_test123" or added_ids.has(hid):
					continue
				hero_roster.append(create_hero_instance(h))
				added_ids[hid] = true
				if hero_roster.size() >= 5:
					break

	if hero_roster.is_empty():
		var fallbacks: Array[Dictionary] = [
			{"id": "hero_militia", "name": "민병대", "rarity": "N", "role_category": "전위", "job_class": "탱커", "element": "EARTH", "max_hp": 58, "atk": 11, "def": 16, "heal_power": 0, "speed": 9, "offense_rank": "전열", "defense_zone": "성벽밖", "skill_id": ""},
			{"id": "hero_shieldbearer", "name": "방패병", "rarity": "R", "role_category": "전위", "job_class": "탱커", "element": "EARTH", "max_hp": 85, "atk": 12, "def": 25, "heal_power": 0, "speed": 8, "offense_rank": "전열", "defense_zone": "성벽밖", "skill_id": "skill_shield_bash"},
			{"id": "hero_archer", "name": "궁수", "rarity": "R", "role_category": "후위", "job_class": "원거리딜러", "element": "LIGHTNING", "max_hp": 35, "atk": 24, "def": 5, "heal_power": 0, "speed": 18, "offense_rank": "후열", "defense_zone": "성벽위", "skill_id": "skill_snipe_back"},
			{"id": "hero_knight", "name": "기사", "rarity": "SR", "role_category": "전위", "job_class": "근접딜러", "element": "FIRE", "max_hp": 65, "atk": 20, "def": 12, "heal_power": 0, "speed": 12, "offense_rank": "전열", "defense_zone": "성벽밖", "skill_id": "skill_fire_slash", "skill2_id": "skill_flame_aura"},
			{"id": "hero_priest", "name": "사제", "rarity": "SR", "role_category": "후위", "job_class": "힐러", "element": "LIGHT", "max_hp": 40, "atk": 8, "def": 8, "heal_power": 24, "speed": 16, "offense_rank": "후열", "defense_zone": "성벽위", "skill_id": "skill_holy_blessing", "skill2_id": "skill_sanctuary_ward"},
		]
		for fb in fallbacks:
			hero_roster.append(create_hero_instance(fb))

	roster_changed.emit()
	if party_presets.is_empty():
		_init_party_presets()
	if _is_preset_empty(0):
		auto_fill_party_preset(0)


func create_hero_instance(template: Dictionary) -> Dictionary:
	var uid: int = next_hero_uid
	next_hero_uid += 1
	var max_hp: int = maxi(1, int(template.get("max_hp", 50)))
	var job_class: String = str(template.get("job_class", "근접딜러"))
	var traits: Dictionary = _default_skill_traits_for_job(job_class)
	var rarity: String = DataManager.normalize_rarity(template.get("rarity", "N"))
	var slots: Dictionary = DataManager.get_skill_slot_rules(rarity)

	return {
		"uid": uid,
		"id": str(template.get("id", "hero_%d" % uid)),
		"name": str(template.get("name", "이름 없는 영웅")),
		"is_named": bool(template.get("is_named", false)),
		"named_title": str(template.get("named_title", "")).strip_edges(),
		"lore": str(template.get("lore", "")).strip_edges(),
		"signature_equip_id": str(template.get("signature_equip_id", "")).strip_edges(),
		"rarity": rarity,
		"level": maxi(1, int(template.get("level", 1))),
		"fatigue": clampi(int(template.get("fatigue", 0)), 0, MAX_FATIGUE),
		"role_category": DataManager.normalize_role_category(str(template.get("role_category", "전위")), job_class),
		"job_class": job_class,
		"element": str(template.get("element", "FIRE")),
		"max_hp": max_hp,
		"hp": clampi(int(template.get("hp", max_hp)), 0, max_hp),
		"atk": int(template.get("atk", 15)),
		"def": int(template.get("def", 10)),
		"heal_power": int(template.get("heal_power", 0)),
		"speed": int(template.get("speed", 10)),
		"dmg_bonus": float(template.get("dmg_bonus", 0.0)),
		"crit_rate": float(template.get("crit_rate", 0.05)),
		"crit_dmg": float(template.get("crit_dmg", 1.5)),
		"armor_pen": float(template.get("armor_pen", 0.0)),
		"final_dmg_mult": float(template.get("final_dmg_mult", 1.0)),
		"offense_rank": str(template.get("offense_rank", "전열")),
		"defense_zone": str(template.get("defense_zone", "성벽밖")),
		"skill_id": str(template.get("skill_id", "")) if slots["active1"] else "",
		"skill2_id": str(template.get("skill2_id", "")) if slots["active2"] else "",
		"ultimate_id": str(template.get("ultimate_id", "")) if slots["ultimate"] else "",
		"skill_description": str(template.get("skill_description", "")),
		"passive_name": str(template.get("passive_name", traits["passive_name"])),
		"passive_desc": str(template.get("passive_desc", traits["passive_desc"])),
		"ultimate_name": str(template.get("ultimate_name", traits["ultimate_name"])),
		"ultimate_desc": str(template.get("ultimate_desc", traits["ultimate_desc"])),
		"equipped_items": _normalize_equipped_items(template.get("equipped_items", {})),
	}


func _normalize_equipped_items(raw_eq: Variant) -> Dictionary:
	var out: Dictionary = {"WEAPON": null, "ARMOR": null, "ACCESSORY": null}
	if typeof(raw_eq) != TYPE_DICTIONARY:
		return out
	var d: Dictionary = raw_eq
	for slot in DataManager.SLOT_TYPES:
		var v: Variant = d.get(slot, null)
		out[slot] = int(v) if v != null else null
	return out


func _default_skill_traits_for_job(job_class: String) -> Dictionary:
	match job_class:
		"탱커":
			return {
				"passive_name": "철벽 수호",
				"passive_desc": "성벽 밖 배치 시 최대 3명의 적을 저지하며 전열에서 아군을 보호합니다.",
				"ultimate_name": "불굴의 요새",
				"ultimate_desc": "아군 전체에 강력한 보호막과 방어력 증가를 부여하는 궁극기입니다.",
			}
		"근접딜러":
			return {
				"passive_name": "돌격 태세",
				"passive_desc": "근접 교전에서 안정적인 물리 피해와 전선 돌파 능력을 발휘합니다.",
				"ultimate_name": "파멸의 일격",
				"ultimate_desc": "적 전열에 치명적인 속성 연격을 퍼붓는 궁극기입니다.",
			}
		"원거리딜러":
			return {
				"passive_name": "정밀 조준",
				"passive_desc": "성벽 위 배치 시 사거리가 크게 증가하며 근접 공격에 면역입니다.",
				"ultimate_name": "폭풍 일제사격",
				"ultimate_desc": "전장의 모든 적에게 속성 광역 피해를 가하는 궁극기입니다.",
			}
		"마법사":
			return {
				"passive_name": "마력 공명",
				"passive_desc": "마법 공격 피해가 강화되지만 전투당 피로도 소모가 큰 편입니다.",
				"ultimate_name": "비전 폭풍",
				"ultimate_desc": "전장의 모든 적에게 거대한 마법 속성 폭격을 가하는 궁극기입니다.",
			}
		"힐러":
			return {
				"passive_name": "치유의 기도",
				"passive_desc": "전투 중 체력이 가장 낮은 아군을 우선 탐색하여 회복시킵니다.",
				"ultimate_name": "대천사의 은총",
				"ultimate_desc": "아군 전체의 체력을 대폭 회복하고 상태이상을 정화하는 궁극기입니다.",
			}
		_:
			return {
				"passive_name": "전술 응용",
				"passive_desc": "상황에 따라 지속 피해와 아군 강화 효과를 동시에 운용합니다.",
				"ultimate_name": "비술 개방",
				"ultimate_desc": "전장에 강력한 디버프와 버프를 동시에 전개하는 궁극기입니다.",
			}


func has_hero_id_in_roster(hero_id: String) -> bool:
	if hero_id.is_empty():
		return false
	for h in hero_roster:
		if str(h.get("id", "")) == hero_id:
			return true
	return false


func can_recruit_hero(template: Dictionary) -> bool:
	if template.is_empty():
		return false
	if bool(template.get("is_named", false)) and has_hero_id_in_roster(str(template.get("id", ""))):
		return false
	return true


func can_recruit_hero_in_tavern(template: Dictionary) -> bool:
	if not can_recruit_hero(template):
		return false
	if bool(template.get("is_named", false)) and str(template.get("named_source", "NON_STORY")) == "STORY":
		return false
	return true


func recruit_hero(template: Dictionary) -> Dictionary:
	if not can_recruit_hero(template):
		return {}
	var hero_inst: Dictionary = create_hero_instance(template)
	hero_roster.append(hero_inst)
	roster_changed.emit()
	return hero_inst


func recruit_hero_by_id(hero_id: String) -> Dictionary:
	var tpl: Dictionary = DataManager.get_hero_template(hero_id)
	if tpl.is_empty():
		return {}
	return recruit_hero(tpl)


func get_hero_by_uid(uid: int) -> Dictionary:
	for h in hero_roster:
		if int(h.get("uid", -1)) == uid:
			return h
	return {}


func heal_hero(uid: int, amount: int = -1) -> int:
	var hero: Dictionary = get_hero_by_uid(uid)
	if hero.is_empty():
		return 0
	var max_hp: int = roundi(get_effective_stat(hero, "max_hp"))
	var prev_hp: int = int(hero.get("hp", max_hp))
	if prev_hp >= max_hp:
		return 0
	var target_hp: int = max_hp if amount < 0 else mini(max_hp, prev_hp + amount)
	hero["hp"] = target_hp
	roster_changed.emit()
	return target_hp - prev_hp


func set_hero_hp(uid: int, new_hp: int) -> void:
	var hero: Dictionary = get_hero_by_uid(uid)
	if hero.is_empty():
		return
	var max_hp: int = roundi(get_effective_stat(hero, "max_hp"))
	hero["hp"] = clampi(new_hp, 0, max_hp)
	roster_changed.emit()


# ==========================================
# 장비 인벤토리 · 장착 유효성 · 스탯 합산
# ==========================================
const CLASS_ALIAS_MAP: Dictionary = {
	"탱커": ["TANK", "WARRIOR", "KNIGHT", "탱커", "근거리"],
	"근접딜러": ["WARRIOR", "KNIGHT", "MELEE", "근접딜러", "근거리"],
	"원거리딜러": ["ARCHER", "RANGER", "RANGED", "원거리딜러", "원거리"],
	"마법사": ["MAGE", "WIZARD", "SORCERER", "CASTER", "마법사", "원거리"],
	"힐러": ["HEALER", "PRIEST", "CLERIC", "힐러", "원거리"],
	"특수": ["SPECIAL", "ALCHEMIST", "특수"],
}


func init_starter_equipment() -> void:
	equipment_inventory.clear()
	next_equip_inst_id = 1
	for eq_id in ["eq_iron_sword", "eq_leather_armor", "eq_swift_charm"]:
		if not DataManager.get_equipment(eq_id).is_empty():
			add_equipment_to_inventory(eq_id, false)
	inventory_changed.emit()


func has_equipment_id_in_inventory(equip_id: String) -> bool:
	if equip_id.is_empty():
		return false
	for item in equipment_inventory:
		if str(item.get("equip_id", "")) == equip_id:
			return true
	return false


func can_obtain_equipment(equip_id: String) -> bool:
	var tpl: Dictionary = DataManager.get_equipment(equip_id)
	if tpl.is_empty():
		return false
	if bool(tpl.get("is_named", false)) and has_equipment_id_in_inventory(equip_id):
		return false
	return true


func add_equipment_to_inventory(equip_id: String, emit_sig: bool = true) -> Dictionary:
	if not can_obtain_equipment(equip_id):
		return {}
	var inst: Dictionary = {
		"inst_id": next_equip_inst_id,
		"equip_id": equip_id,
	}
	next_equip_inst_id += 1
	equipment_inventory.append(inst)
	if emit_sig:
		inventory_changed.emit()
	return inst


func get_equipment_instance(inst_id: int) -> Dictionary:
	for item in equipment_inventory:
		if int(item.get("inst_id", -1)) == inst_id:
			return item
	return {}


func get_equipment_template_for_instance(inst_id: int) -> Dictionary:
	var inst: Dictionary = get_equipment_instance(inst_id)
	if inst.is_empty():
		return {}
	return DataManager.get_equipment(str(inst.get("equip_id", "")))


func get_equipment_owner_uid(inst_id: int) -> int:
	for hero in hero_roster:
		var equipped: Dictionary = hero.get("equipped_items", {})
		for slot in DataManager.SLOT_TYPES:
			var eq_val: Variant = equipped.get(slot, null)
			if eq_val != null and int(eq_val) == inst_id:
				return int(hero.get("uid", -1))
	return -1


## 영웅이 해당 장비를 장착할 수 있는지 검사합니다. (전용 영웅 ID + 직업군 제한)
func can_equip(hero: Dictionary, equipment: Dictionary) -> bool:
	return get_equip_block_reason(hero, equipment).is_empty()


func get_equip_block_reason(hero: Dictionary, equipment: Dictionary) -> String:
	if hero.is_empty() or equipment.is_empty():
		return "유효하지 않은 대상입니다."

	var exclusive_id: String = str(equipment.get("exclusive_hero_id", "")).strip_edges()
	if not exclusive_id.is_empty() and str(hero.get("id", "")) != exclusive_id:
		return "전용 장비 제한 (%s 전용)" % exclusive_id

	var allowed: Array = equipment.get("allowed_classes", [])
	if allowed.is_empty():
		return ""
	for a in allowed:
		if str(a).strip_edges().to_upper() == "ALL":
			return ""

	var hero_job: String = str(hero.get("job_class", hero.get("hero_class", "")))
	var hero_cat: String = str(hero.get("role_category", ""))
	var hero_aliases: Array = CLASS_ALIAS_MAP.get(hero_job, [hero_job])

	for raw_req in allowed:
		var req_upper: String = str(raw_req).strip_edges().to_upper()
		if req_upper == hero_job.to_upper() or (not hero_cat.is_empty() and req_upper == hero_cat.to_upper()):
			return ""
		for alias in hero_aliases:
			if str(alias).to_upper() == req_upper:
				return ""

	return "직업군 제한 (%s)" % ", ".join(PackedStringArray(allowed))


func equip_item(hero_uid: int, equip_inst_id: int) -> bool:
	var hero: Dictionary = get_hero_by_uid(hero_uid)
	var eq_tpl: Dictionary = get_equipment_template_for_instance(equip_inst_id)
	if hero.is_empty() or eq_tpl.is_empty():
		return false
	if not can_equip(hero, eq_tpl):
		return false

	var slot_type: String = str(eq_tpl.get("slot_type", "WEAPON"))
	# 다른 영웅이 장착 중이면 해제
	var prev_owner_uid: int = get_equipment_owner_uid(equip_inst_id)
	if prev_owner_uid != -1 and prev_owner_uid != hero_uid:
		unequip_slot(prev_owner_uid, slot_type)

	if not hero.has("equipped_items"):
		hero["equipped_items"] = {"WEAPON": null, "ARMOR": null, "ACCESSORY": null}
	hero["equipped_items"][slot_type] = equip_inst_id

	var eff_max_hp: int = roundi(get_effective_stat(hero, "max_hp"))
	hero["hp"] = clampi(int(hero.get("hp", eff_max_hp)), 0, eff_max_hp)
	roster_changed.emit()
	inventory_changed.emit()
	return true


func unequip_slot(hero_uid: int, slot_type: String) -> bool:
	var hero: Dictionary = get_hero_by_uid(hero_uid)
	if hero.is_empty():
		return false
	var equipped: Dictionary = hero.get("equipped_items", {})
	if equipped.get(slot_type, null) == null:
		return false
	equipped[slot_type] = null

	var eff_max_hp: int = roundi(get_effective_stat(hero, "max_hp"))
	hero["hp"] = clampi(int(hero.get("hp", eff_max_hp)), 0, eff_max_hp)
	roster_changed.emit()
	inventory_changed.emit()
	return true


func get_hero_equipped_templates(hero: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var equipped: Dictionary = hero.get("equipped_items", {})
	for slot in DataManager.SLOT_TYPES:
		var inst_val: Variant = equipped.get(slot, null)
		if inst_val == null:
			continue
		var tpl: Dictionary = get_equipment_template_for_instance(int(inst_val))
		if not tpl.is_empty():
			out.append(tpl)
	return out


func get_hero_equipment_bonuses(hero: Dictionary) -> Dictionary:
	var totals: Dictionary = {}
	for key in DataManager.EQUIP_STAT_KEYS:
		totals[key] = 0.0
	for eq_tpl in get_hero_equipped_templates(hero):
		var bonuses: Dictionary = eq_tpl.get("stat_bonuses", {})
		for key in bonuses:
			totals[key] = float(totals.get(key, 0.0)) + float(bonuses[key])
	return totals


## 네임드 영웅과 전용 네임드 장비가 짝을 이뤄 공명이 발동되는지 확인합니다.
func is_signature_resonance_active(hero: Dictionary, eq_tpl: Dictionary) -> bool:
	if hero.is_empty() or eq_tpl.is_empty():
		return false
	if not bool(eq_tpl.get("is_named", false)):
		return false
	var hero_id: String = str(hero.get("id", ""))
	var eq_id: String = str(eq_tpl.get("id", ""))
	var sig_id: String = str(hero.get("signature_equip_id", ""))
	var excl_id: String = str(eq_tpl.get("exclusive_hero_id", ""))
	return (not sig_id.is_empty() and sig_id == eq_id) or (not excl_id.is_empty() and excl_id == hero_id)


func get_hero_equipment_passives(hero: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for eq_tpl in get_hero_equipped_templates(hero):
		var eq_name: String = str(eq_tpl.get("name", ""))
		var pid: String = str(eq_tpl.get("passive_skill_id", "")).strip_edges()
		if not pid.is_empty():
			var skill: Dictionary = DataManager.get_skill(pid)
			if not skill.is_empty():
				out.append({
					"equipment_name": eq_name,
					"skill": skill,
					"is_resonance": false,
				})
		if is_signature_resonance_active(hero, eq_tpl):
			var rid: String = str(eq_tpl.get("resonance_skill_id", "")).strip_edges()
			if not rid.is_empty():
				var res_skill: Dictionary = DataManager.get_skill(rid)
				if not res_skill.is_empty():
					out.append({
						"equipment_name": eq_name,
						"skill": res_skill,
						"is_resonance": true,
					})
	return out


## 영웅의 기본 스탯 + 장착 장비 stat_bonuses + 장비 패시브(SELF 버프)를 합산한 최종 유효 스탯을 반환합니다.
func get_effective_stat(hero: Dictionary, stat_name: String) -> float:
	if hero.is_empty():
		return 0.0
	var eq_bonuses: Dictionary = get_hero_equipment_bonuses(hero)
	var base_val: float = float(hero.get(stat_name, 0.0)) + float(eq_bonuses.get(stat_name, 0.0))

	# 장비의 passive_skill_id 중 SELF 즉시 스탯 버프 반영
	var pct_add: float = 0.0
	var flat_add: float = 0.0
	var mult_factor: float = 1.0
	for entry in get_hero_equipment_passives(hero):
		var skill: Dictionary = entry["skill"]
		for eff in skill.get("effects", []):
			var scope: String = str(eff.get("target_scope", "SELF"))
			if scope != "SELF" and scope != "ALL_ALLIES":
				continue
			var etype: String = str(eff.get("effect_type", ""))
			var mult: float = float(eff.get("multiplier", 0.0))
			match stat_name:
				"atk":
					if etype == "BUFF_ATK":
						pct_add += mult
				"def":
					if etype == "BUFF_DEF":
						pct_add += mult
				"speed":
					if etype == "BUFF_SPEED":
						pct_add += mult
				"dmg_bonus":
					if etype == "BUFF_DMG_BONUS":
						flat_add += mult
				"crit_rate":
					if etype == "BUFF_CRIT_RATE":
						flat_add += mult
				"crit_dmg":
					if etype == "BUFF_CRIT_DMG":
						flat_add += mult
				"armor_pen":
					if etype == "BUFF_ARMOR_PEN":
						flat_add += mult
				"final_dmg_mult":
					if etype == "BUFF_FINAL_DMG":
						mult_factor *= maxf(0.1, 1.0 + mult)

	var fatigue_mult: float = 0.85 if is_hero_tired(hero) else 1.0

	match stat_name:
		"max_hp":
			return maxf(1.0, base_val)
		"atk":
			return maxf(1.0, base_val * maxf(0.1, 1.0 + pct_add) * fatigue_mult)
		"def":
			return maxf(0.0, base_val * maxf(0.0, 1.0 + pct_add))
		"speed":
			return maxf(1.0, base_val * maxf(0.15, 1.0 + pct_add) * fatigue_mult)
		"crit_rate", "armor_pen":
			return clampf(base_val + flat_add, 0.0, 1.0)
		"crit_dmg":
			return maxf(1.0, base_val + flat_add)
		"final_dmg_mult":
			return maxf(0.1, base_val * mult_factor)
		_:
			return base_val + flat_add


# --- 영웅 피로도 (0 = 최상, >= 80 지침, 100 = 탈진) ---
func is_hero_tired(hero: Dictionary) -> bool:
	var f: int = int(hero.get("fatigue", 0))
	return f >= FATIGUE_TIRED_THRESHOLD and f < MAX_FATIGUE


func is_hero_exhausted(hero: Dictionary) -> bool:
	return int(hero.get("fatigue", 0)) >= MAX_FATIGUE


func get_hero_fatigue_state_label(hero: Dictionary) -> String:
	var f: int = int(hero.get("fatigue", 0))
	if f >= MAX_FATIGUE:
		return "탈진"
	if f >= FATIGUE_TIRED_THRESHOLD:
		return "지침"
	if f >= 50:
		return "피곤"
	return "양호"


func add_hero_fatigue(uid: int, amount: int) -> Dictionary:
	var hero: Dictionary = get_hero_by_uid(uid)
	if hero.is_empty():
		return {}
	var prev_f: int = int(hero.get("fatigue", 0))
	var next_f: int = clampi(prev_f + amount, 0, MAX_FATIGUE)
	hero["fatigue"] = next_f
	roster_changed.emit()
	return {"prev": prev_f, "next": next_f, "hero": hero}


func recover_hero_fatigue(uid: int, amount: int) -> int:
	if amount <= 0:
		return 0
	var hero: Dictionary = get_hero_by_uid(uid)
	if hero.is_empty():
		return 0
	var prev_f: int = int(hero.get("fatigue", 0))
	var next_f: int = maxi(0, prev_f - amount)
	hero["fatigue"] = next_f
	roster_changed.emit()
	return prev_f - next_f


func recover_all_roster_fatigue(amount: int) -> void:
	if amount <= 0:
		return
	var changed: bool = false
	for hero in hero_roster:
		var prev_f: int = int(hero.get("fatigue", 0))
		if prev_f > 0:
			hero["fatigue"] = maxi(0, prev_f - amount)
			changed = true
	if changed:
		roster_changed.emit()


## 던전 이동 1칸마다 활성 원정 파티(또는 로스터) 영웅들의 직군별 이동 피로도를 누적합니다.
func apply_party_move_fatigue() -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	for hero in get_active_party_heroes():
		if not can_hero_deploy(hero):
			continue
		var costs: Dictionary = DataManager.get_class_fatigue_costs(str(hero.get("job_class", "")))
		var cost: int = int(costs.get("move", 4))
		var prev_f: int = int(hero.get("fatigue", 0))
		var next_f: int = clampi(prev_f + cost, 0, MAX_FATIGUE)
		hero["fatigue"] = next_f
		changes.append({"uid": int(hero.get("uid", 0)), "name": str(hero.get("name", "")), "cost": cost, "fatigue": next_f})
	if not changes.is_empty():
		roster_changed.emit()
	return changes


## 던전 전투 1회 완료 시 활성 원정 파티(또는 로스터) 영웅들의 직군별 전투 피로도를 누적합니다.
func apply_party_battle_fatigue() -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	for hero in get_active_party_heroes():
		if not can_hero_deploy(hero):
			continue
		var costs: Dictionary = DataManager.get_class_fatigue_costs(str(hero.get("job_class", "")))
		var cost: int = int(costs.get("battle", 10))
		var prev_f: int = int(hero.get("fatigue", 0))
		var next_f: int = clampi(prev_f + cost, 0, MAX_FATIGUE)
		hero["fatigue"] = next_f
		changes.append({"uid": int(hero.get("uid", 0)), "name": str(hero.get("name", "")), "cost": cost, "fatigue": next_f})
	if not changes.is_empty():
		roster_changed.emit()
	return changes


# ==========================================
# 파티 편성 프리셋 & 탈진 안전장치 & 전투 배속/자동 모드
# ==========================================
func can_hero_deploy(hero: Dictionary) -> bool:
	if hero.is_empty():
		return false
	return int(hero.get("hp", 0)) > 0 and not is_hero_exhausted(hero)


func get_hero_combat_power(hero: Dictionary) -> float:
	if hero.is_empty():
		return 0.0
	var hp_s: float = get_effective_stat(hero, "max_hp") * 0.5
	var atk_s: float = get_effective_stat(hero, "atk") * 3.0
	var def_s: float = get_effective_stat(hero, "def") * 1.5
	var heal_s: float = float(hero.get("heal_power", 0)) * 2.5
	var spd_s: float = get_effective_stat(hero, "speed") * 1.5
	var rarity_order := {"N": 0.0, "R": 15.0, "SR": 35.0, "SSR": 65.0}
	var r_bonus: float = float(rarity_order.get(DataManager.normalize_rarity(hero.get("rarity", "N")), 0.0))
	return hp_s + atk_s + def_s + heal_s + spd_s + r_bonus


func _slot_key_str(rank: int, row: int) -> String:
	return "%d,%d" % [rank, row]


func _is_preset_empty(preset_idx: int) -> bool:
	var preset: Dictionary = get_party_preset(preset_idx)
	var slots: Dictionary = preset.get("slots", {})
	return slots.is_empty()


func get_party_preset(preset_idx: int = -1) -> Dictionary:
	if party_presets.is_empty():
		_init_party_presets()
	var idx: int = selected_party_index if preset_idx < 0 else clampi(preset_idx, 0, MAX_PARTY_PRESETS - 1)
	return party_presets[idx]


func select_party_preset(preset_idx: int) -> void:
	if party_presets.is_empty():
		_init_party_presets()
	selected_party_index = clampi(preset_idx, 0, MAX_PARTY_PRESETS - 1)
	_sync_dungeon_party_grid_from_preset()
	party_presets_changed.emit()


func get_rank_position_bonus(rank: int) -> Dictionary:
	return RANK_POSITION_BONUSES.get(clampi(rank, 0, 2), {})


func get_rank_bonus_summary(rank: int) -> String:
	var info: Dictionary = get_rank_position_bonus(rank)
	return str(info.get("summary", ""))


func set_party_slot(preset_idx: int, rank: int, row: int, hero_uid: int) -> bool:
	if hero_uid <= 0:
		clear_party_slot(preset_idx, rank, row)
		return true
	var hero: Dictionary = get_hero_by_uid(hero_uid)
	if not can_hero_deploy(hero):
		return false
	var preset: Dictionary = get_party_preset(preset_idx)
	var slots: Dictionary = preset["slots"]
	var target_key: String = _slot_key_str(clampi(rank, 0, 2), clampi(row, 0, 2))
	var already_in_preset: bool = false
	for k in slots.keys():
		if int(slots[k]) == hero_uid:
			already_in_preset = true
			break
	if not already_in_preset and not slots.has(target_key) and slots.size() >= MAX_PARTY_SIZE:
		return false
	for k in slots.keys().duplicate():
		if int(slots[k]) == hero_uid:
			slots.erase(k)
	slots[target_key] = hero_uid
	if clampi(preset_idx, 0, MAX_PARTY_PRESETS - 1) == selected_party_index:
		_sync_dungeon_party_grid_from_preset()
	party_presets_changed.emit()
	return true


func clear_party_slot(preset_idx: int, rank: int, row: int) -> void:
	var preset: Dictionary = get_party_preset(preset_idx)
	var slots: Dictionary = preset["slots"]
	slots.erase(_slot_key_str(clampi(rank, 0, 2), clampi(row, 0, 2)))
	if clampi(preset_idx, 0, MAX_PARTY_PRESETS - 1) == selected_party_index:
		_sync_dungeon_party_grid_from_preset()
	party_presets_changed.emit()


func clear_party_preset(preset_idx: int) -> void:
	var preset: Dictionary = get_party_preset(preset_idx)
	(preset["slots"] as Dictionary).clear()
	if clampi(preset_idx, 0, MAX_PARTY_PRESETS - 1) == selected_party_index:
		_sync_dungeon_party_grid_from_preset()
	party_presets_changed.emit()


func get_party_slot_hero(preset_idx: int, rank: int, row: int) -> Dictionary:
	var preset: Dictionary = get_party_preset(preset_idx)
	var slots: Dictionary = preset.get("slots", {})
	var key: String = _slot_key_str(rank, row)
	if not slots.has(key):
		return {}
	return get_hero_by_uid(int(slots[key]))


func get_preset_slots_list(preset_idx: int = -1) -> Array[Dictionary]:
	var preset: Dictionary = get_party_preset(preset_idx)
	var slots: Dictionary = preset.get("slots", {})
	var out: Array[Dictionary] = []
	for rank in range(3):
		for row in range(3):
			var key: String = _slot_key_str(rank, row)
			if not slots.has(key):
				continue
			var hero: Dictionary = get_hero_by_uid(int(slots[key]))
			if not hero.is_empty():
				out.append({"rank": rank, "row": row, "hero": hero})
	return out


func get_active_party_heroes() -> Array[Dictionary]:
	var entries: Array[Dictionary] = get_preset_slots_list(selected_party_index)
	var out: Array[Dictionary] = []
	for entry in entries:
		out.append(entry["hero"])
		if out.size() >= MAX_PARTY_SIZE:
			break
	if out.is_empty() and not hero_roster.is_empty():
		var lim: int = mini(MAX_PARTY_SIZE, hero_roster.size())
		for i in range(lim):
			out.append(hero_roster[i])
		return out
	return out


func get_deployable_party_heroes(preset_idx: int = -1) -> Array[Dictionary]:
	var entries: Array[Dictionary] = get_preset_slots_list(preset_idx)
	var out: Array[Dictionary] = []
	for entry in entries:
		var hero: Dictionary = entry["hero"]
		if can_hero_deploy(hero):
			out.append(hero)
	return out


## 빠른 편성: 출전 가능한 영웅 중 전투력 상위 영웅을 전열(탱커/전사)과 후열(원거리/힐러) 역할에 맞게 빈칸 자동 배치
func auto_fill_party_preset(preset_idx: int = -1) -> int:
	var target_idx: int = selected_party_index if preset_idx < 0 else clampi(preset_idx, 0, MAX_PARTY_PRESETS - 1)
	var preset: Dictionary = get_party_preset(target_idx)
	var slots: Dictionary = preset["slots"]

	var already_uids: Dictionary = {}
	for k in slots.keys().duplicate():
		var uid: int = int(slots[k])
		var h: Dictionary = get_hero_by_uid(uid)
		if not can_hero_deploy(h):
			slots.erase(k)
		else:
			already_uids[uid] = true

	var candidates: Array[Dictionary] = []
	for h in hero_roster:
		var uid: int = int(h.get("uid", -1))
		if can_hero_deploy(h) and not already_uids.has(uid):
			candidates.append(h)

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return get_hero_combat_power(a) > get_hero_combat_power(b)
	)

	var added_count: int = 0
	var row_order: Array[int] = [1, 0, 2]
	for hero in candidates:
		if slots.size() >= MAX_PARTY_SIZE:
			break
		var cat: String = DataManager.normalize_role_category(str(hero.get("role_category", "")), str(hero.get("job_class", "")))
		var off_rank: String = str(hero.get("offense_rank", "전열"))
		var rank_priority: Array[int] = []
		if cat == "전위" or off_rank == "전열":
			rank_priority = [0, 1, 2]
		elif cat == "후위" or off_rank == "후열":
			rank_priority = [2, 1, 0]
		else:
			rank_priority = [1, 0, 2]

		var placed: bool = false
		for r in rank_priority:
			for rw in row_order:
				var key: String = _slot_key_str(r, rw)
				if not slots.has(key):
					slots[key] = int(hero["uid"])
					added_count += 1
					placed = true
					break
			if placed:
				break

	if target_idx == selected_party_index:
		_sync_dungeon_party_grid_from_preset()
	party_presets_changed.emit()
	return added_count


func _sync_dungeon_party_grid_from_preset() -> void:
	_init_dungeon_grid()
	var preset: Dictionary = get_party_preset(selected_party_index)
	var slots: Dictionary = preset.get("slots", {})
	for rank in range(3):
		for row in range(3):
			var key: String = _slot_key_str(rank, row)
			if slots.has(key):
				var hero: Dictionary = get_hero_by_uid(int(slots[key]))
				if not hero.is_empty():
					dungeon_party_grid[rank * 3 + row] = hero


func cycle_auto_battle_mode() -> int:
	auto_battle_mode = (auto_battle_mode + 1) % 3
	battle_settings_changed.emit()
	return auto_battle_mode


func cycle_battle_speed() -> float:
	if battle_speed_mult < 1.5:
		battle_speed_mult = 2.0
	elif battle_speed_mult < 2.5:
		battle_speed_mult = 3.0
	else:
		battle_speed_mult = 1.0
	battle_settings_changed.emit()
	return battle_speed_mult


func get_auto_battle_label() -> String:
	match auto_battle_mode:
		AutoBattleMode.AUTO_SAVE_ULT:
			return "자동 (궁극기 수동)"
		AutoBattleMode.FULL_AUTO:
			return "완전 자동 (궁극기 포함)"
		_:
			return "수동"


func get_battle_speed_label() -> String:
	return "%.0fx" % battle_speed_mult


## 전투 시작 시 영웅이 장착한 장비의 passive_skill_id 효과들을 전투 유닛(들)에 자동 발동합니다.
func apply_equipment_passives_to_combat_unit(hero: Dictionary, combat_unit: Dictionary, all_allies: Array = []) -> PackedStringArray:
	var logs: PackedStringArray = []
	for entry in get_hero_equipment_passives(hero):
		var skill: Dictionary = entry["skill"]
		var eq_name: String = str(entry["equipment_name"])
		for eff in skill.get("effects", []):
			var etype: String = str(eff.get("effect_type", ""))
			var scope: String = str(eff.get("target_scope", "SELF"))
			var mult: float = float(eff.get("multiplier", 0.0))
			var dur: float = maxf(99.0, float(eff.get("duration", 99)))
			if StatusEffectManager.is_buff(etype):
				if scope == "ALL_ALLIES" and not all_allies.is_empty():
					for ally in all_allies:
						StatusEffectManager.apply_effect(ally, etype, mult, dur, combat_unit)
				else:
					StatusEffectManager.apply_effect(combat_unit, etype, mult, dur, combat_unit)
		logs.append("[%s] 장비 패시브 발동: <%s>" % [eq_name, str(skill.get("name", ""))])
	return logs


func level_up_hero(uid: int) -> Dictionary:
	var hero: Dictionary = get_hero_by_uid(uid)
	if hero.is_empty():
		return {}
	var new_lv: int = int(hero.get("level", 1)) + 1
	var hp_gain: int = 8
	var atk_gain: int = 3
	var def_gain: int = 2
	var heal_gain: int = 3 if (str(hero.get("job_class", "")) == "힐러" or int(hero.get("heal_power", 0)) > 0) else 0
	var spd_gain: int = 1 if new_lv % 2 == 0 else 0

	hero["level"] = new_lv
	hero["max_hp"] = int(hero.get("max_hp", 50)) + hp_gain
	hero["hp"] = mini(int(hero["max_hp"]), int(hero.get("hp", 0)) + hp_gain)
	hero["atk"] = int(hero.get("atk", 15)) + atk_gain
	hero["def"] = int(hero.get("def", 10)) + def_gain
	hero["heal_power"] = int(hero.get("heal_power", 0)) + heal_gain
	hero["speed"] = int(hero.get("speed", 10)) + spd_gain
	roster_changed.emit()
	return {
		"level": new_lv,
		"hp_gain": hp_gain,
		"atk_gain": atk_gain,
		"def_gain": def_gain,
		"heal_gain": heal_gain,
		"spd_gain": spd_gain,
	}


# --- 페이즈 / 날짜 전환 ---
func set_phase(new_phase: GamePhase) -> void:
	if current_phase == new_phase:
		return
	current_phase = new_phase
	phase_changed.emit(current_phase)


func advance_day() -> void:
	current_day += 1
	day_changed.emit(current_day)


# --- 게임 초기화 ---
func reset_game() -> void:
	current_phase = GamePhase.MANAGEMENT
	current_day = 1
	last_management_day = -1
	last_settled_day = -1
	resources = {
		"gold": 100,
		"wood": 50,
		"stone": 30,
		"food": 50,
		"materials": 40,
	}
	citizen_morale = 70
	population = 10
	max_population = 20
	farm_level = 1
	lumber_mill_level = 1
	wall_max_hp = 100
	wall_hp = 100
	wall_level = 1
	defense_wave = 1
	outpost_weakened_stacks = 0
	defense_wall_atk_bonus = 0
	base_tower_atk_level = 1
	base_tower_spd_level = 1
	owned_towers.clear()
	equipped_tower_slots = ["", "", ""]
	completed_research_ids.clear()
	territory_debuff_name = ""
	territory_debuff_rate = 0.0
	territory_debuff_days = 0
	rebellion_risk = 0
	bad_choice_streak = 0
	field_dungeon_state.clear()
	upcoming_defense_elements.clear()
	dungeon_floor = 1
	auto_battle_mode = AutoBattleMode.MANUAL
	battle_speed_mult = 1.0
	_init_dungeon_grid()
	_init_party_presets()
	init_starter_roster()
	init_starter_equipment()
	init_starter_items()

	game_reset.emit()
	notify_all_changed()


func notify_all_changed() -> void:
	resources_changed.emit(resources.duplicate())
	morale_changed.emit(citizen_morale)
	wall_hp_changed.emit(wall_hp, wall_max_hp)
	day_changed.emit(current_day)
	phase_changed.emit(current_phase)
	roster_changed.emit()
	facilities_changed.emit()
	inventory_changed.emit()
	party_presets_changed.emit()
	battle_settings_changed.emit()
	towers_changed.emit()
	research_changed.emit()
	dungeon_state_changed.emit()


# ==========================================
# 성벽 기본 타워, 커스텀 타워(3슬롯), 대형 던전 주기 상태 관리
# ==========================================
func get_base_tower_stats() -> Dictionary:
	var atk_val: int = 14 + (base_tower_atk_level - 1) * 7
	var interval_val: float = maxf(0.45, 1.35 - float(base_tower_spd_level - 1) * 0.14)
	return {
		"atk": atk_val,
		"attack_interval": interval_val,
		"atk_level": base_tower_atk_level,
		"spd_level": base_tower_spd_level,
		"range": 330.0,
	}


func upgrade_base_tower_atk() -> void:
	base_tower_atk_level += 1
	towers_changed.emit()
	facilities_changed.emit()


func upgrade_base_tower_spd() -> void:
	base_tower_spd_level += 1
	towers_changed.emit()
	facilities_changed.emit()


func has_owned_tower(tower_id: String) -> bool:
	return owned_towers.has(tower_id)


func add_owned_tower(tower_id: String) -> void:
	if not tower_id.is_empty() and not owned_towers.has(tower_id):
		owned_towers.append(tower_id)
		# 빈 타워 슬롯이 있으면 자동 장착 편의 제공
		for i in range(equipped_tower_slots.size()):
			if equipped_tower_slots[i].is_empty():
				equipped_tower_slots[i] = tower_id
				break
		towers_changed.emit()


func equip_tower_to_slot(slot_idx: int, tower_id: String) -> void:
	if slot_idx < 0 or slot_idx >= MAX_TOWER_SLOTS:
		return
	if equipped_tower_slots.size() < MAX_TOWER_SLOTS:
		equipped_tower_slots.resize(MAX_TOWER_SLOTS)
	equipped_tower_slots[slot_idx] = tower_id
	towers_changed.emit()


func unequip_tower_slot(slot_idx: int) -> void:
	equip_tower_to_slot(slot_idx, "")


func set_field_dungeon_state(state: Dictionary) -> void:
	field_dungeon_state = state.duplicate(true)
	dungeon_state_changed.emit()


func clear_field_dungeon_state() -> void:
	field_dungeon_state.clear()
	upcoming_defense_elements.clear()
	dungeon_state_changed.emit()


func set_upcoming_defense_elements(elems: Array[String]) -> void:
	upcoming_defense_elements.clear()
	for e in elems:
		var eu: String = e.strip_edges().to_upper()
		if not eu.is_empty() and not upcoming_defense_elements.has(eu):
			upcoming_defense_elements.append(eu)
	dungeon_state_changed.emit()


func get_upcoming_defense_elements_text() -> String:
	if upcoming_defense_elements.is_empty():
		return "미확인 (평일 던전 탐사 시 동기화)"
	var names: PackedStringArray = []
	for e in upcoming_defense_elements:
		names.append(DataManager.get_element_name(e))
	return ", ".join(names)


# ==========================================
# 연구소 기술 해금 상태 관리
# ==========================================
func is_research_completed(research_id: String) -> bool:
	if research_id.is_empty():
		return true
	return completed_research_ids.has(research_id)


func can_start_research(research_id: String) -> bool:
	if is_research_completed(research_id):
		return false
	var res: Dictionary = DataManager.get_research(research_id)
	if res.is_empty():
		return false
	var prereq: String = str(res.get("prerequisite_id", ""))
	if not prereq.is_empty() and not is_research_completed(prereq):
		return false
	return can_afford(res.get("cost", {}))


func complete_research(research_id: String) -> bool:
	if research_id.is_empty() or is_research_completed(research_id):
		return false
	completed_research_ids.append(research_id)
	research_changed.emit()
	towers_changed.emit()
	facilities_changed.emit()
	return true


func is_tower_unlocked(tower_id: String) -> bool:
	var req_res: String = DataManager.get_required_research_for_tower(tower_id)
	if req_res.is_empty():
		return true
	return is_research_completed(req_res)


func is_equipment_blacksmith_craftable(equip_id: String) -> bool:
	var eq: Dictionary = DataManager.get_equipment(equip_id)
	if eq.is_empty():
		return false
	return bool(eq.get("craftable_in_blacksmith", not bool(eq.get("is_named", false))))


func is_equipment_research_unlocked(equip_id: String) -> bool:
	var req_res: String = DataManager.get_required_research_for_equip(equip_id)
	if req_res.is_empty():
		return true
	return is_research_completed(req_res)


# ==========================================
# 소비 아이템 / 포션 인벤토리 관리
# ==========================================
func init_starter_items() -> void:
	item_inventory.clear()
	var starter: Dictionary = {
		"item_hp_potion_small": 3,
		"item_stamina_tonic": 2,
		"item_fire_flask": 2,
		"item_war_elixir": 1,
	}
	for iid in starter:
		if not DataManager.get_item(iid).is_empty():
			item_inventory[iid] = int(starter[iid])
	inventory_changed.emit()


func get_item_count(item_id: String) -> int:
	return maxi(0, int(item_inventory.get(item_id, 0)))


func add_item(item_id: String, amount: int = 1) -> void:
	if item_id.is_empty() or amount <= 0:
		return
	item_inventory[item_id] = get_item_count(item_id) + amount
	inventory_changed.emit()


func consume_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	var cur: int = get_item_count(item_id)
	if cur < amount:
		return false
	var next_cnt: int = cur - amount
	if next_cnt <= 0:
		item_inventory.erase(item_id)
	else:
		item_inventory[item_id] = next_cnt
	inventory_changed.emit()
	return true


func get_owned_items(combat_only: bool = false, dungeon_only: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it in DataManager.items:
		var iid: String = str(it.get("id", ""))
		var cnt: int = get_item_count(iid)
		if cnt <= 0:
			continue
		if combat_only and not bool(it.get("usable_in_combat", true)):
			continue
		if dungeon_only and not bool(it.get("usable_in_dungeon", false)):
			continue
		var entry: Dictionary = it.duplicate(true)
		entry["count"] = cnt
		out.append(entry)
	return out


# ==========================================
# 영지 단기 생산 디버프 & 반란 위험도 관리
# ==========================================
func _evaluate_morale_territory_debuff() -> void:
	if citizen_morale < 25:
		apply_territory_production_debuff("민심 붕괴 · 대거 태업", 0.45, 3)
	elif citizen_morale < 45:
		apply_territory_production_debuff("사기 저하 · 작업 태업", 0.25, 2)
	elif citizen_morale >= 65 and (territory_debuff_name.begins_with("사기") or territory_debuff_name.begins_with("민심")):
		territory_debuff_name = ""
		territory_debuff_rate = 0.0
		territory_debuff_days = 0
		facilities_changed.emit()


func apply_territory_production_debuff(debuff_name: String, penalty_rate: float, days: int) -> void:
	var clamped_rate: float = clampf(penalty_rate, 0.0, 0.80)
	if territory_debuff_days <= 0 or clamped_rate >= territory_debuff_rate:
		territory_debuff_name = debuff_name
		territory_debuff_rate = clamped_rate
		territory_debuff_days = maxi(territory_debuff_days, days)
	else:
		territory_debuff_days = maxi(territory_debuff_days, days)
	facilities_changed.emit()


func tick_territory_debuff_day() -> void:
	if territory_debuff_days > 0:
		territory_debuff_days -= 1
		if territory_debuff_days <= 0:
			territory_debuff_name = ""
			territory_debuff_rate = 0.0
	_evaluate_morale_territory_debuff()
	facilities_changed.emit()


func get_territory_production_multiplier() -> float:
	if territory_debuff_days > 0 and territory_debuff_rate > 0.0:
		return maxf(0.20, 1.0 - territory_debuff_rate)
	return 1.0


func get_territory_debuff_summary() -> String:
	if territory_debuff_days <= 0 or territory_debuff_rate <= 0.0:
		return ""
	return "⚠ 영지 디버프 [%s]: 식량·자재 생산 -%d%% (남은 %d일)" % [
		territory_debuff_name,
		roundi(territory_debuff_rate * 100.0),
		territory_debuff_days,
	]


func add_rebellion_risk(delta: int) -> void:
	rebellion_risk = clampi(rebellion_risk + delta, 0, 10)
	if delta > 0:
		bad_choice_streak += 1
	elif delta < 0:
		bad_choice_streak = 0
	morale_changed.emit(citizen_morale)


func should_trigger_rebellion_event() -> bool:
	return rebellion_risk >= 4 or (bad_choice_streak >= 2 and citizen_morale < 45) or citizen_morale <= 20
