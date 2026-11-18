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
signal run_stats_changed()

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

const MAX_GENERAL_TEMPERAMENTS: int = 3
const TRAUMA_CURE_COST: Dictionary = {"gold": 60, "food": 25}
const EXHAUSTION_TRAUMA_CHANCE: float = 0.25

## 테스트 결정성용 오버라이드 (< 0 이면 기본 45% + 사기 보정 확률 적용)
var miracle_survival_rate_override: float = -1.0

## 영웅 4대 기질 데이터베이스
## category: "MIXED"(양면 · 일반), "POSITIVE"(순수 긍정 · 희귀), "NEGATIVE"(순수 부정 · 후유증), "VETERAN"(경험 · 소소한 습관)
const TEMPERAMENT_DATA: Dictionary = {
	# --- 1) MIXED (양면 기질 · 최소 10종+) ---
	"temp_mixed_berserk": {
		"id": "temp_mixed_berserk", "name": "광포한", "category": "MIXED",
		"summary": "ATK +14%, DEF -10%",
		"stats": {"atk_pct": 0.14, "def_pct": -0.10},
	},
	"temp_mixed_heavy": {
		"id": "temp_mixed_heavy", "name": "육중한", "category": "MIXED",
		"summary": "최대HP +16%, SPD -2",
		"stats": {"max_hp_pct": 0.16, "speed_flat": -2.0},
	},
	"temp_mixed_hasty": {
		"id": "temp_mixed_hasty", "name": "성급한", "category": "MIXED",
		"summary": "SPD +3, DEF -10%",
		"stats": {"speed_flat": 3.0, "def_pct": -0.10},
	},
	"temp_mixed_perfectionist": {
		"id": "temp_mixed_perfectionist", "name": "완벽주의", "category": "MIXED",
		"summary": "치명타율 +10%, 피로 누적 +20%",
		"stats": {"crit_rate": 0.10, "fatigue_mult": 0.20},
	},
	"temp_mixed_dull": {
		"id": "temp_mixed_dull", "name": "둔감한", "category": "MIXED",
		"summary": "피로 경감 -25%, SPD -2",
		"stats": {"fatigue_mult": -0.25, "speed_flat": -2.0},
	},
	"temp_mixed_devoted": {
		"id": "temp_mixed_devoted", "name": "헌신적인", "category": "MIXED",
		"summary": "HEAL +16%, 최대HP -10%",
		"stats": {"heal_pct": 0.16, "max_hp_pct": -0.10},
	},
	"temp_mixed_reckless": {
		"id": "temp_mixed_reckless", "name": "무모한", "category": "MIXED",
		"summary": "치명피해 +25%, 최대HP -12%",
		"stats": {"crit_dmg": 0.25, "max_hp_pct": -0.12},
	},
	"temp_mixed_cautious": {
		"id": "temp_mixed_cautious", "name": "신중한", "category": "MIXED",
		"summary": "DEF +14%, ATK -8%",
		"stats": {"def_pct": 0.14, "atk_pct": -0.08},
	},
	"temp_mixed_greedy": {
		"id": "temp_mixed_greedy", "name": "과욕의", "category": "MIXED",
		"summary": "피해증가 +12%, 피로 누적 +20%",
		"stats": {"dmg_bonus": 0.12, "fatigue_mult": 0.20},
	},
	"temp_mixed_stubborn": {
		"id": "temp_mixed_stubborn", "name": "완고한", "category": "MIXED",
		"summary": "방어관통 +12%, 치명타율 -5%",
		"stats": {"armor_pen": 0.12, "crit_rate": -0.05},
	},
	"temp_mixed_agile": {
		"id": "temp_mixed_agile", "name": "예민한 감각", "category": "MIXED",
		"summary": "SPD +2, 치명타율 +6%, 피로 누적 +15%",
		"stats": {"speed_flat": 2.0, "crit_rate": 0.06, "fatigue_mult": 0.15},
	},

	# --- 2) POSITIVE (순수 긍정 기질 · 최소 6종+) ---
	"temp_pos_genius": {
		"id": "temp_pos_genius", "name": "천재적인", "category": "POSITIVE",
		"summary": "전 스탯 +6%",
		"stats": {"max_hp_pct": 0.06, "atk_pct": 0.06, "def_pct": 0.06, "heal_pct": 0.06, "speed_pct": 0.06},
	},
	"temp_pos_undying": {
		"id": "temp_pos_undying", "name": "불사신의 활력", "category": "POSITIVE",
		"summary": "최대HP +15%, 피로 경감 -15%",
		"stats": {"max_hp_pct": 0.15, "fatigue_mult": -0.15},
	},
	"temp_pos_warlord": {
		"id": "temp_pos_warlord", "name": "전장의 지배자", "category": "POSITIVE",
		"summary": "ATK +12%, 치명피해 +20%",
		"stats": {"atk_pct": 0.12, "crit_dmg": 0.20},
	},
	"temp_pos_ironclad": {
		"id": "temp_pos_ironclad", "name": "철벽의 화신", "category": "POSITIVE",
		"summary": "DEF +15%, 최대HP +10%",
		"stats": {"def_pct": 0.15, "max_hp_pct": 0.10},
	},
	"temp_pos_blessed": {
		"id": "temp_pos_blessed", "name": "축복받은 손길", "category": "POSITIVE",
		"summary": "HEAL +18%, SPD +2",
		"stats": {"heal_pct": 0.18, "speed_flat": 2.0},
	},
	"temp_pos_windrunner": {
		"id": "temp_pos_windrunner", "name": "질풍의 축복", "category": "POSITIVE",
		"summary": "SPD +3, 치명타율 +8%",
		"stats": {"speed_flat": 3.0, "crit_rate": 0.08},
	},

	# --- 3) NEGATIVE (순수 부정 기질 · 후유증/트라우마 · 최소 6종+) ---
	"temp_neg_trauma": {
		"id": "temp_neg_trauma", "name": "전장의 트라우마", "category": "NEGATIVE",
		"summary": "ATK -12%, 피로 누적 +25%",
		"stats": {"atk_pct": -0.12, "fatigue_mult": 0.25},
	},
	"temp_neg_injury": {
		"id": "temp_neg_injury", "name": "고질적인 부상", "category": "NEGATIVE",
		"summary": "최대HP -15%, DEF -8%",
		"stats": {"max_hp_pct": -0.15, "def_pct": -0.08},
	},
	"temp_neg_weak_heart": {
		"id": "temp_neg_weak_heart", "name": "쇠약한 심장", "category": "NEGATIVE",
		"summary": "SPD -3, 피로 누적 +20%",
		"stats": {"speed_flat": -3.0, "fatigue_mult": 0.20},
	},
	"temp_neg_fragile_mind": {
		"id": "temp_neg_fragile_mind", "name": "유리 멘탈", "category": "NEGATIVE",
		"summary": "DEF -12%, 치명타율 -5%",
		"stats": {"def_pct": -0.12, "crit_rate": -0.05},
	},
	"temp_neg_chronic_fatigue": {
		"id": "temp_neg_chronic_fatigue", "name": "만성 피로", "category": "NEGATIVE",
		"summary": "피로 누적 +35%",
		"stats": {"fatigue_mult": 0.35},
	},
	"temp_neg_trembling_hand": {
		"id": "temp_neg_trembling_hand", "name": "떨리는 손", "category": "NEGATIVE",
		"summary": "ATK -10%, HEAL -12%",
		"stats": {"atk_pct": -0.10, "heal_pct": -0.12},
	},

	# --- 4) VETERAN (경험 기질 · 실전 습관/요령 · 최소 7종) ---
	"temp_vet_wall_familiar": {
		"id": "temp_vet_wall_familiar", "name": "성벽 위가 익숙한", "category": "VETERAN",
		"summary": "DEF +3%, 최대HP +2%",
		"unlock_hint": "디펜스 2회 이상 생존",
		"stats": {"def_pct": 0.03, "max_hp_pct": 0.02},
	},
	"temp_vet_night_march": {
		"id": "temp_vet_night_march", "name": "야간 행군 요령", "category": "VETERAN",
		"summary": "피로 경감 -5%",
		"unlock_hint": "던전 탐사 15걸음 이상",
		"stats": {"fatigue_mult": -0.05},
	},
	"temp_vet_vital_spot": {
		"id": "temp_vet_vital_spot", "name": "급소 노리기", "category": "VETERAN",
		"summary": "치명타율 +2%, 치명피해 +4%",
		"unlock_hint": "누적 적 12기 이상 처치",
		"stats": {"crit_rate": 0.02, "crit_dmg": 0.04},
	},
	"temp_vet_first_aid": {
		"id": "temp_vet_first_aid", "name": "상처 소독 습관", "category": "VETERAN",
		"summary": "최대HP +3%, HEAL +3%",
		"unlock_hint": "누적 치유량 80 이상 또는 5회 이상 교전",
		"stats": {"max_hp_pct": 0.03, "heal_pct": 0.03},
	},
	"temp_vet_giant_slayer": {
		"id": "temp_vet_giant_slayer", "name": "큰 덩치 상대법", "category": "VETERAN",
		"summary": "ATK +3%",
		"unlock_hint": "보스전 1회 이상 승리",
		"stats": {"atk_pct": 0.03},
	},
	"temp_vet_tenacious_life": {
		"id": "temp_vet_tenacious_life", "name": "질긴 생명력", "category": "VETERAN",
		"summary": "최대HP +4%, DEF +2%",
		"unlock_hint": "죽음의 문턱(기적적 생환) 1회 이상 극복",
		"stats": {"max_hp_pct": 0.04, "def_pct": 0.02},
	},
	"temp_vet_worn_weapon": {
		"id": "temp_vet_worn_weapon", "name": "손에 익은 무기", "category": "VETERAN",
		"summary": "ATK +2%, SPD +1",
		"unlock_hint": "실전 전투 4회 이상 참전",
		"stats": {"atk_pct": 0.02, "speed_flat": 1.0},
	},
}

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
var rebellion_suppression_active: bool = false

# --- 대형 던전(FIELD_GRID) 디펜스 주기 유지 상태 & 예상 적 속성 ---
var field_dungeon_state: Dictionary = {}
var upcoming_defense_elements: Array[String] = []

# --- 누적 플레이 통계 & 엔딩/무한 모드 상태 ---
var run_stats: Dictionary = {
	"defenses_won": 0,
	"bosses_defeated": 0,
	"dungeons_cleared": 0,
	"heroes_recruited": 0,
	"events_resolved": 0,
}
var victory_achieved: bool = false
var is_endless_mode: bool = false

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
	var raw_sub: String = str(template.get("sub_class", template.get("job_class", "돌격검객")))
	var raw_group: String = str(template.get("class_group", ""))
	var hier: Dictionary = DataManager.normalize_class_hierarchy(raw_group, raw_sub, str(template.get("role_category", "")))
	var role_category: String = str(hier["role_category"])
	var class_group: String = str(hier["class_group"])
	var sub_class: String = str(hier["sub_class"])
	var class_info: Dictionary = DataManager.get_sub_class_info(sub_class)
	var traits: Dictionary = _default_skill_traits_for_job(class_group)
	var rarity: String = DataManager.normalize_rarity(template.get("rarity", "N"))
	var slots: Dictionary = DataManager.get_skill_slot_rules(rarity)
	var is_named_hero: bool = bool(template.get("is_named", false))

	# 고정 기질 및 잠금 여부 결정 (템플릿 우선, 없으면 직군 설정 참조)
	var fixed_list: Array[String] = []
	for ft in template.get("fixed_temperaments", []):
		var fts: String = str(ft).strip_edges()
		if TEMPERAMENT_DATA.has(fts) and not fixed_list.has(fts):
			fixed_list.append(fts)
	if fixed_list.is_empty():
		for cft in class_info.get("fixed_temperaments", []):
			var cfts: String = str(cft).strip_edges()
			if TEMPERAMENT_DATA.has(cfts) and not fixed_list.has(cfts):
				fixed_list.append(cfts)

	var lock_general: bool = (
		is_named_hero
		or bool(template.get("lock_general_temperaments", false))
		or bool(class_info.get("lock_general_temperaments", false))
		or not fixed_list.is_empty()
	)

	var final_temps: Array[String] = []
	var has_saved_temps: bool = template.has("temperaments") and typeof(template.get("temperaments")) == TYPE_ARRAY
	if has_saved_temps:
		for tid in template.get("temperaments", []):
			var tids: String = str(tid).strip_edges()
			if TEMPERAMENT_DATA.has(tids) and not final_temps.has(tids):
				final_temps.append(tids)
	elif lock_general:
		if not fixed_list.is_empty():
			for ft in fixed_list:
				final_temps.append(ft)
		else:
			# 고정 기질이 지정되지 않은 네임드/잠금 영웅은 직군 성향에 맞는 긍정/고유 기질 1개 자동 부여
			final_temps.append(_fallback_fixed_temperament_for_class(class_group, sub_class))
	else:
		# 일반 영웅 생성 시 1~2개 일반 기질 무작위 추첨 (MIXED ~92%, POSITIVE ~8%)
		var roll_count: int = randi_range(1, 2)
		for _i in range(roll_count):
			var cat_pick: String = "POSITIVE" if randf() < 0.08 else "MIXED"
			var picked: String = roll_random_temperament_id(cat_pick, final_temps)
			if not picked.is_empty():
				final_temps.append(picked)

	var svc: Dictionary = _normalize_service_record(template.get("service_record", {}))

	var inst: Dictionary = {
		"uid": uid,
		"id": str(template.get("id", "hero_%d" % uid)),
		"name": str(template.get("name", "이름 없는 영웅")),
		"is_named": is_named_hero,
		"named_source": str(template.get("named_source", "NONE")),
		"named_title": str(template.get("named_title", "")).strip_edges(),
		"lore": str(template.get("lore", "")).strip_edges(),
		"signature_equip_id": str(template.get("signature_equip_id", "")).strip_edges(),
		"fixed_temperaments": fixed_list,
		"lock_general_temperaments": lock_general,
		"temperaments": final_temps,
		"service_record": svc,
		"rarity": rarity,
		"level": maxi(1, int(template.get("level", 1))),
		"fatigue": clampi(int(template.get("fatigue", 0)), 0, MAX_FATIGUE),
		"role_category": role_category,
		"class_group": class_group,
		"sub_class": sub_class,
		"job_class": sub_class,
		"element": str(template.get("element", "FIRE")),
		"max_hp": max_hp,
		"hp": max_hp,
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
		"passive_skill_id": str(template.get("passive_skill_id", "")).strip_edges(),
		"skill_description": str(template.get("skill_description", "")),
		"passive_name": str(template.get("passive_name", traits["passive_name"])),
		"passive_desc": str(template.get("passive_desc", traits["passive_desc"])),
		"ultimate_name": str(template.get("ultimate_name", traits["ultimate_name"])),
		"ultimate_desc": str(template.get("ultimate_desc", traits["ultimate_desc"])),
		"portrait_path": str(template.get("portrait_path", "")).strip_edges(),
		"sprite_path": str(template.get("sprite_path", "")).strip_edges(),
		"equipped_items": _normalize_equipped_items(template.get("equipped_items", {})),
	}

	var eff_max: int = maxi(1, roundi(get_effective_stat(inst, "max_hp")))
	if template.has("hp"):
		inst["hp"] = clampi(int(template.get("hp", eff_max)), 0, eff_max)
	else:
		inst["hp"] = eff_max
	return inst


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
	var cg: String = job_class if DataManager.CLASS_GROUPS.has(job_class) else DataManager.get_class_group_for_sub_class(job_class)
	match cg:
		"중장":
			return {
				"passive_name": "철벽 방진",
				"passive_desc": "디펜스 성벽 밖 기본 저지 수 +1(총 4저지), 전열 배치 시 받는 피해 -10%.",
				"ultimate_name": "불굴의 요새",
				"ultimate_desc": "아군 전체에 강력한 보호막과 방어력 증가를 부여하는 궁극기입니다.",
			}
		"근위":
			return {
				"passive_name": "파쇄 돌격",
				"passive_desc": "근접 공격 시 방어력 10% 무시, 적 처치 시 다음 턴 속도 +2.",
				"ultimate_name": "파멸의 일격",
				"ultimate_desc": "적 전열에 치명적인 속성 연격을 퍼붓는 궁극기입니다.",
			}
		"선봉":
			return {
				"passive_name": "선봉 기동",
				"passive_desc": "던전 이동 피로도 -1 경감, 전투 첫 턴 속도(SPD) +3.",
				"ultimate_name": "기습 신호탄",
				"ultimate_desc": "적의 헛점을 찔러 아군 전체의 기동력을 끌어올리는 정찰 궁극기입니다.",
			}
		"특수":
			return {
				"passive_name": "변칙 기동",
				"passive_desc": "진형 이동(밀치기/당기기/교환) 성공률 100%, 기습 공격 시 치명피해 +20%.",
				"ultimate_name": "비술 개방",
				"ultimate_desc": "전장에 강력한 디버프와 버프를 동시에 전개하는 궁극기입니다.",
			}
		"보조":
			return {
				"passive_name": "전술 공명",
				"passive_desc": "부여하는 버프·디버프 지속시간 +1턴(디펜스 +2초) 연장.",
				"ultimate_name": "승리의 교향곡",
				"ultimate_desc": "아군 전선의 화력과 방어를 동시에 극대화하는 지원 궁극기입니다.",
			}
		"저격":
			return {
				"passive_name": "고지 사격",
				"passive_desc": "디펜스 성벽 위 배치 시 사거리 추가 +15% 및 근접 공격 면역.",
				"ultimate_name": "폭풍 일제사격",
				"ultimate_desc": "전장의 모든 적에게 속성 광역 피해를 가하는 궁극기입니다.",
			}
		"술사":
			return {
				"passive_name": "원소 증폭",
				"passive_desc": "속성 상성 우위(1.5x) 공격 시 최종 피해 +15%.",
				"ultimate_name": "비전 폭풍",
				"ultimate_desc": "전장의 모든 적에게 거대한 마법 속성 폭격을 가하는 궁극기입니다.",
			}
		"의료":
			return {
				"passive_name": "구호 결계",
				"passive_desc": "치유 실행 시 대상에게 1턴(디펜스 2초)간 받는 피해 -10% 보호 가호 부여.",
				"ultimate_name": "대천사의 은총",
				"ultimate_desc": "아군 전체의 체력을 대폭 회복하고 상태이상을 정화하는 궁극기입니다.",
			}
		_:
			return {
				"passive_name": "전술 응용",
				"passive_desc": "병과와 세부직군 특성을 결합해 전장을 지원합니다.",
				"ultimate_name": "비술 개방",
				"ultimate_desc": "전장에 강력한 디버프와 버프를 동시에 전개하는 궁극기입니다.",
			}


## 영웅의 2계층 직군 정보(병과 특성 + 세부직군 고유 특성)를 함께 반환
func get_hero_trait_summary(hero: Dictionary) -> Dictionary:
	var hier: Dictionary = DataManager.normalize_class_hierarchy(
		str(hero.get("class_group", "")),
		str(hero.get("sub_class", hero.get("job_class", ""))),
		str(hero.get("role_category", ""))
	)
	var cg: String = str(hier["class_group"])
	var sub: String = str(hier["sub_class"])
	var cg_info: Dictionary = DataManager.get_class_group_info(cg)
	var sub_info: Dictionary = DataManager.get_sub_class_info(sub)
	return {
		"role_category": str(hier["role_category"]),
		"class_group": cg,
		"sub_class": sub,
		"class_trait_name": str(cg_info.get("trait_name", cg)),
		"class_trait_desc": str(cg_info.get("trait_desc", "")),
		"sub_trait": str(sub_info.get("sub_trait", "")),
		"sub_trait_label": str(sub_info.get("sub_trait_label", sub)),
		"sub_trait_desc": str(sub_info.get("sub_trait_desc", str(sub_info.get("description", "")))),
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
	record_hero_recruited()
	roster_changed.emit()
	return hero_inst


func recruit_hero_by_id(hero_id: String) -> Dictionary:
	var tpl: Dictionary = DataManager.get_hero_template(hero_id)
	if tpl.is_empty():
		return {}
	return recruit_hero(tpl)


func find_hero_by_id_in_roster(hero_id: String) -> Dictionary:
	if hero_id.is_empty():
		return {}
	for h in hero_roster:
		if str(h.get("id", "")) == hero_id:
			return h
	return {}


func get_owned_named_heroes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for h in hero_roster:
		if bool(h.get("is_named", false)):
			out.append(h)
	return out


func get_unowned_story_heroes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for h in DataManager.heroes:
		if bool(h.get("is_named", false)) and str(h.get("named_source", "")) == "STORY":
			if not has_hero_id_in_roster(str(h.get("id", ""))):
				out.append(h)
	return out


## 이벤트 선택지(option_a/option_b)의 영웅 영입 / 장비 지급 / 아이템 지급 보상을 안전하게 적용합니다.
## 이미 보유 중인 네임드 영웅 또는 네임드 장비일 경우 자원 및 한계훈련 보상으로 자동 대체합니다.
func grant_event_rewards(opt_data: Dictionary) -> Dictionary:
	var messages: PackedStringArray = []
	var recruited_hero: Dictionary = {}
	var granted_equip: Dictionary = {}
	var granted_item: Dictionary = {}

	var hero_id: String = str(opt_data.get("recruit_hero_id", "")).strip_edges()
	if not hero_id.is_empty():
		var tpl: Dictionary = DataManager.get_hero_template(hero_id)
		if not tpl.is_empty():
			if can_recruit_hero(tpl):
				recruited_hero = recruit_hero(tpl)
				if not recruited_hero.is_empty():
					messages.append("★ 스토리 네임드 영웅 합류: [%s] %s" % [
						DataManager.normalize_rarity(tpl.get("rarity", "R")),
						str(tpl.get("name", hero_id)),
					])
			else:
				var existing: Dictionary = find_hero_by_id_in_roster(hero_id)
				var bonus_gold: int = 60
				var bonus_mat: int = 25
				apply_deltas({"gold": bonus_gold, "materials": bonus_mat})
				if not existing.is_empty():
					var lv_res: Dictionary = level_up_hero(int(existing.get("uid", -1)))
					messages.append("★ [%s] 이미 보유 중 → 대체 보상: Lv.%d 한계훈련 강화 + 골드 +%d, 자재 +%d" % [
						str(tpl.get("name", hero_id)),
						int(lv_res.get("level", existing.get("level", 1))),
						bonus_gold,
						bonus_mat,
					])
				else:
					messages.append("★ [%s] 이미 보유 중 → 대체 보상: 골드 +%d, 자재 +%d" % [
						str(tpl.get("name", hero_id)),
						bonus_gold,
						bonus_mat,
					])

	var equip_id: String = str(opt_data.get("grant_equip_id", "")).strip_edges()
	if not equip_id.is_empty():
		var eq_tpl: Dictionary = DataManager.get_equipment(equip_id)
		if not eq_tpl.is_empty():
			if can_obtain_equipment(equip_id):
				granted_equip = add_equipment_to_inventory(equip_id)
				if not granted_equip.is_empty():
					messages.append("★ 장비 획득: [%s] %s" % [
						DataManager.normalize_rarity(eq_tpl.get("rarity", "N")),
						str(eq_tpl.get("name", equip_id)),
					])
			else:
				var eq_rw: Dictionary = get_equipment_disassemble_reward(eq_tpl)
				var g_amt: int = int(eq_rw.get("gold", 30)) + 25
				var m_amt: int = int(eq_rw.get("materials", 20)) + 15
				apply_deltas({"gold": g_amt, "materials": m_amt})
				messages.append("★ 장비 [%s] 이미 보유 중 → 대체 보상: 골드 +%d, 자재 +%d" % [
					str(eq_tpl.get("name", equip_id)),
					g_amt,
					m_amt,
				])

	var item_id: String = str(opt_data.get("grant_item_id", "")).strip_edges()
	if not item_id.is_empty():
		var it_tpl: Dictionary = DataManager.get_item(item_id)
		if not it_tpl.is_empty():
			add_item(item_id, 1)
			granted_item = it_tpl
			messages.append("★ 아이템 획득: [%s] %s x1" % [
				DataManager.normalize_rarity(it_tpl.get("rarity", "N")),
				str(it_tpl.get("name", item_id)),
			])

	return {
		"messages": messages,
		"hero": recruited_hero,
		"equip": granted_equip,
		"item": granted_item,
	}


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


const HERO_DISMISS_REFUND_BY_RARITY: Dictionary = {
	"N": 12,
	"R": 25,
	"SR": 55,
	"SSR": 110,
}

const EQUIP_DISASSEMBLE_REWARDS: Dictionary = {
	"N": {"materials": 8, "gold": 5},
	"R": {"materials": 16, "gold": 12},
	"SR": {"materials": 35, "gold": 25},
	"SSR": {"materials": 70, "gold": 50},
}


func get_hero_dismiss_refund(hero: Dictionary) -> int:
	if hero.is_empty():
		return 0
	var rarity: String = DataManager.normalize_rarity(hero.get("rarity", "N"))
	var base_gold: int = int(HERO_DISMISS_REFUND_BY_RARITY.get(rarity, 12))
	var lv: int = maxi(1, int(hero.get("level", 1)))
	return base_gold + (lv - 1) * 6


func dismiss_hero(hero_uid: int) -> Dictionary:
	if hero_roster.size() <= 1:
		return {"ok": false, "reason": "로스터에 최소 1명의 영웅은 남겨야 합니다."}
	var target_idx: int = -1
	for i in range(hero_roster.size()):
		if int(hero_roster[i].get("uid", -1)) == hero_uid:
			target_idx = i
			break
	if target_idx == -1:
		return {"ok": false, "reason": "전역시킬 영웅을 찾을 수 없습니다."}

	var hero: Dictionary = hero_roster[target_idx]
	var h_name: String = str(hero.get("name", "영웅"))
	var rarity: String = DataManager.normalize_rarity(hero.get("rarity", "N"))
	var gold_refund: int = get_hero_dismiss_refund(hero)

	# 장착 중이던 장비 자동 해제 (equipment_inventory에 인스턴스 그대로 보존)
	var unequipped_cnt: int = 0
	var equipped: Dictionary = hero.get("equipped_items", {})
	for slot in DataManager.SLOT_TYPES:
		if equipped.get(slot, null) != null:
			equipped[slot] = null
			unequipped_cnt += 1

	# 모든 파티 프리셋 슬롯에서 해당 영웅 제거
	for preset in party_presets:
		var slots: Dictionary = preset.get("slots", {})
		for k in slots.keys().duplicate():
			if int(slots[k]) == hero_uid:
				slots.erase(k)

	hero_roster.remove_at(target_idx)
	_sync_dungeon_party_grid_from_preset()
	apply_deltas({"gold": gold_refund})
	roster_changed.emit()
	party_presets_changed.emit()
	if unequipped_cnt > 0:
		inventory_changed.emit()

	return {
		"ok": true,
		"name": h_name,
		"rarity": rarity,
		"gold": gold_refund,
		"unequipped_count": unequipped_cnt,
	}


func get_equipment_disassemble_reward(tpl: Dictionary) -> Dictionary:
	var rarity: String = DataManager.normalize_rarity(tpl.get("rarity", "N"))
	var reward: Dictionary = EQUIP_DISASSEMBLE_REWARDS.get(rarity, EQUIP_DISASSEMBLE_REWARDS["N"])
	return {
		"materials": int(reward.get("materials", 8)),
		"gold": int(reward.get("gold", 5)),
	}


func can_disassemble_equipment(inst_id: int) -> Dictionary:
	var inst: Dictionary = get_equipment_instance(inst_id)
	if inst.is_empty():
		return {"ok": false, "reason": "장비를 찾을 수 없습니다."}
	var tpl: Dictionary = DataManager.get_equipment(str(inst.get("equip_id", "")))
	if tpl.is_empty():
		return {"ok": false, "reason": "장비 데이터가 유효하지 않습니다."}
	if get_equipment_owner_uid(inst_id) != -1:
		return {"ok": false, "reason": "영웅이 장착 중인 장비는 분해할 수 없습니다."}
	if bool(tpl.get("is_named", false)) or bool(tpl.get("is_unique", false)) or not str(tpl.get("exclusive_hero_id", "")).strip_edges().is_empty():
		return {"ok": false, "reason": "네임드·유일 전용 장비는 실수 방지를 위해 분해할 수 없습니다."}
	return {"ok": true}


func disassemble_equipment(inst_id: int) -> Dictionary:
	var check: Dictionary = can_disassemble_equipment(inst_id)
	if not bool(check.get("ok", false)):
		return check
	var target_idx: int = -1
	for i in range(equipment_inventory.size()):
		if int(equipment_inventory[i].get("inst_id", -1)) == inst_id:
			target_idx = i
			break
	if target_idx == -1:
		return {"ok": false, "reason": "장비를 찾을 수 없습니다."}

	var tpl: Dictionary = DataManager.get_equipment(str(equipment_inventory[target_idx].get("equip_id", "")))
	var reward: Dictionary = get_equipment_disassemble_reward(tpl)
	equipment_inventory.remove_at(target_idx)
	apply_deltas(reward)
	inventory_changed.emit()

	return {
		"ok": true,
		"name": str(tpl.get("name", "장비")),
		"rarity": DataManager.normalize_rarity(tpl.get("rarity", "N")),
		"materials": int(reward["materials"]),
		"gold": int(reward["gold"]),
	}


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


# ==========================================
# 영웅 3계층 다중 기질(Temperament) & 실전 이력 시스템
# ==========================================
func get_temperament_info(temp_id: String) -> Dictionary:
	return TEMPERAMENT_DATA.get(temp_id, {})


func _fallback_fixed_temperament_for_class(class_group: String, _sub_class: String) -> String:
	match class_group:
		"중장":
			return "temp_pos_ironclad"
		"근위", "선봉":
			return "temp_pos_warlord"
		"저격", "특수":
			return "temp_pos_windrunner"
		"의료":
			return "temp_pos_blessed"
		_:
			return "temp_pos_genius"


func _normalize_service_record(raw: Variant) -> Dictionary:
	var d: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	return {
		"defenses_survived": maxi(0, int(d.get("defenses_survived", 0))),
		"dungeon_steps": maxi(0, int(d.get("dungeon_steps", 0))),
		"boss_kills": maxi(0, int(d.get("boss_kills", 0))),
		"near_deaths": maxi(0, int(d.get("near_deaths", 0))),
		"total_kills": maxi(0, int(d.get("total_kills", 0))),
		"total_healed": maxi(0, int(d.get("total_healed", 0))),
		"battles_fought": maxi(0, int(d.get("battles_fought", 0))),
	}


func get_temperaments_by_category(category: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for tid in TEMPERAMENT_DATA:
		var t: Dictionary = TEMPERAMENT_DATA[tid]
		if str(t.get("category", "")) == category:
			out.append(t)
	return out


func roll_random_temperament_id(category: String, exclude_ids: Array = []) -> String:
	var pool: Array[String] = []
	for tid in TEMPERAMENT_DATA:
		var t: Dictionary = TEMPERAMENT_DATA[tid]
		if str(t.get("category", "")) == category and not exclude_ids.has(tid):
			pool.append(tid)
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]


func get_hero_temperaments_by_category(hero: Dictionary) -> Dictionary:
	var general: Array[String] = []
	var veteran: Array[String] = []
	var negative: Array[String] = []
	for tid in hero.get("temperaments", []):
		var tids: String = str(tid)
		var info: Dictionary = get_temperament_info(tids)
		if info.is_empty():
			continue
		match str(info.get("category", "")):
			"MIXED", "POSITIVE":
				if not general.has(tids):
					general.append(tids)
			"VETERAN":
				if not veteran.has(tids):
					veteran.append(tids)
			"NEGATIVE":
				if not negative.has(tids):
					negative.append(tids)
	return {
		"general": general,
		"veteran": veteran,
		"negative": negative,
	}


func get_hero_temperament_bonuses(hero: Dictionary) -> Dictionary:
	var totals: Dictionary = {
		"max_hp_pct": 0.0,
		"atk_pct": 0.0,
		"def_pct": 0.0,
		"heal_pct": 0.0,
		"speed_pct": 0.0,
		"speed_flat": 0.0,
		"dmg_bonus": 0.0,
		"crit_rate": 0.0,
		"crit_dmg": 0.0,
		"armor_pen": 0.0,
		"fatigue_mult": 0.0,
	}
	for tid in hero.get("temperaments", []):
		var info: Dictionary = get_temperament_info(str(tid))
		if info.is_empty():
			continue
		var stats: Dictionary = info.get("stats", {})
		for k in stats:
			if totals.has(k):
				totals[k] = float(totals[k]) + float(stats[k])
	return totals


func get_hero_fatigue_multiplier(hero: Dictionary) -> float:
	var tb: Dictionary = get_hero_temperament_bonuses(hero)
	return maxf(0.35, 1.0 + float(tb.get("fatigue_mult", 0.0)))


func add_hero_temperament(uid_or_hero: Variant, temp_id: String, emit_change: bool = true) -> Dictionary:
	var hero: Dictionary = uid_or_hero if typeof(uid_or_hero) == TYPE_DICTIONARY else get_hero_by_uid(int(uid_or_hero))
	if hero.is_empty():
		return {"added": false, "reason": "NO_HERO"}
	var info: Dictionary = get_temperament_info(temp_id)
	if info.is_empty():
		return {"added": false, "reason": "INVALID_ID"}

	if not hero.has("temperaments") or typeof(hero.get("temperaments")) != TYPE_ARRAY:
		hero["temperaments"] = []
	var t_list: Array = hero["temperaments"]
	if t_list.has(temp_id):
		return {"added": false, "reason": "DUPLICATE"}

	var cat: String = str(info.get("category", ""))
	if cat == "MIXED" or cat == "POSITIVE":
		if bool(hero.get("lock_general_temperaments", false)):
			return {"added": false, "reason": "LOCKED"}
		var grouped: Dictionary = get_hero_temperaments_by_category(hero)
		if (grouped["general"] as Array).size() >= MAX_GENERAL_TEMPERAMENTS:
			return {"added": false, "reason": "FULL"}

	t_list.append(temp_id)
	# 최대 체력 기질 변동 시 현재 HP 상한 보정
	var eff_max: int = maxi(1, roundi(get_effective_stat(hero, "max_hp")))
	hero["hp"] = clampi(int(hero.get("hp", eff_max)), 0, eff_max)
	if emit_change:
		roster_changed.emit()
	return {"added": true, "reason": "OK", "temperament": info}


func grant_random_general_temperament(uid: int, positive_chance: float = 0.08) -> String:
	var hero: Dictionary = get_hero_by_uid(uid)
	if hero.is_empty() or bool(hero.get("lock_general_temperaments", false)):
		return ""
	var grouped: Dictionary = get_hero_temperaments_by_category(hero)
	if (grouped["general"] as Array).size() >= MAX_GENERAL_TEMPERAMENTS:
		return ""
	var cur_list: Array = hero.get("temperaments", [])
	var cat: String = "POSITIVE" if randf() < positive_chance else "MIXED"
	var picked: String = roll_random_temperament_id(cat, cur_list)
	if picked.is_empty():
		picked = roll_random_temperament_id("MIXED" if cat == "POSITIVE" else "POSITIVE", cur_list)
	if picked.is_empty():
		return ""
	var res: Dictionary = add_hero_temperament(hero, picked, true)
	return picked if bool(res.get("added", false)) else ""


func grant_random_negative_temperament(uid: int) -> String:
	var hero: Dictionary = get_hero_by_uid(uid)
	if hero.is_empty():
		return ""
	var cur_list: Array = hero.get("temperaments", [])
	var picked: String = roll_random_temperament_id("NEGATIVE", cur_list)
	if picked.is_empty():
		return ""
	var res: Dictionary = add_hero_temperament(hero, picked, true)
	return picked if bool(res.get("added", false)) else ""


func cure_hero_negative_temperament(uid: int, cost: Dictionary = TRAUMA_CURE_COST) -> Dictionary:
	var hero: Dictionary = get_hero_by_uid(uid)
	if hero.is_empty():
		return {"cured": false, "reason": "NO_HERO"}
	var grouped: Dictionary = get_hero_temperaments_by_category(hero)
	var negs: Array = grouped["negative"]
	if negs.is_empty():
		return {"cured": false, "reason": "NO_TRAUMA"}
	if not cost.is_empty() and not spend_resources(cost):
		return {"cured": false, "reason": "NO_RESOURCES"}

	var target_tid: String = str(negs[0])
	var t_list: Array = hero.get("temperaments", [])
	t_list.erase(target_tid)
	var eff_max: int = maxi(1, roundi(get_effective_stat(hero, "max_hp")))
	hero["hp"] = clampi(int(hero.get("hp", eff_max)), 0, eff_max)
	roster_changed.emit()
	return {
		"cured": true,
		"reason": "OK",
		"removed_id": target_tid,
		"removed_name": str(get_temperament_info(target_tid).get("name", target_tid)),
	}


## 전투 중 치명타/죽음(HP 0) 도달 시 기적적 생환 확률 판정 (기본 45% + 사기 보정)
func roll_miracle_survival(_hero_uid: int = -1) -> bool:
	if miracle_survival_rate_override >= 0.0:
		return randf() < clampf(miracle_survival_rate_override, 0.0, 1.0)
	var morale_bonus: float = clampf(float(citizen_morale - 50) / 200.0, -0.15, 0.25)
	var chance: float = clampf(0.45 + morale_bonus, 0.15, 0.80)
	return randf() < chance


func record_hero_service(uid: int, deltas: Dictionary, emit_change: bool = true) -> Array[String]:
	var unlocked_ids: Array[String] = []
	var hero: Dictionary = get_hero_by_uid(uid)
	if hero.is_empty():
		return unlocked_ids
	if not hero.has("service_record") or typeof(hero.get("service_record")) != TYPE_DICTIONARY:
		hero["service_record"] = _normalize_service_record({})
	var svc: Dictionary = hero["service_record"]
	for key in ["defenses_survived", "dungeon_steps", "boss_kills", "near_deaths", "total_kills", "total_healed", "battles_fought"]:
		var d: int = int(deltas.get(key, 0))
		if d > 0:
			svc[key] = int(svc.get(key, 0)) + d

	unlocked_ids = _evaluate_veteran_temperaments(hero, false)
	if emit_change and (not unlocked_ids.is_empty()):
		roster_changed.emit()
	return unlocked_ids


func record_party_service(deltas: Dictionary) -> Array[Dictionary]:
	var unlocked_reports: Array[Dictionary] = []
	for hero in get_deployable_party_heroes():
		var uid: int = int(hero.get("uid", -1))
		if uid <= 0:
			continue
		var new_vets: Array[String] = record_hero_service(uid, deltas, false)
		for vid in new_vets:
			unlocked_reports.append({
				"uid": uid,
				"hero_name": str(hero.get("name", "영웅")),
				"temp_id": vid,
				"temp_name": str(get_temperament_info(vid).get("name", vid)),
				"summary": str(get_temperament_info(vid).get("summary", "")),
			})
	if not unlocked_reports.is_empty():
		roster_changed.emit()
	return unlocked_reports


func _evaluate_veteran_temperaments(hero: Dictionary, emit_change: bool = false) -> Array[String]:
	var unlocked: Array[String] = []
	var svc: Dictionary = hero.get("service_record", {})
	var checks: Array[Array] = [
		["temp_vet_wall_familiar", int(svc.get("defenses_survived", 0)) >= 2],
		["temp_vet_night_march", int(svc.get("dungeon_steps", 0)) >= 15],
		["temp_vet_vital_spot", int(svc.get("total_kills", 0)) >= 12],
		["temp_vet_first_aid", int(svc.get("total_healed", 0)) >= 80 or int(svc.get("battles_fought", 0)) >= 5],
		["temp_vet_giant_slayer", int(svc.get("boss_kills", 0)) >= 1],
		["temp_vet_tenacious_life", int(svc.get("near_deaths", 0)) >= 1],
		["temp_vet_worn_weapon", int(svc.get("battles_fought", 0)) >= 4],
	]
	for pair in checks:
		var vid: String = str(pair[0])
		var cond: bool = bool(pair[1])
		if cond and not (hero.get("temperaments", []) as Array).has(vid):
			var res: Dictionary = add_hero_temperament(hero, vid, false)
			if bool(res.get("added", false)):
				unlocked.append(vid)
	if emit_change and not unlocked.is_empty():
		roster_changed.emit()
	return unlocked


func format_temperament_summary_text(hero: Dictionary) -> String:
	var tb: Dictionary = get_hero_temperament_bonuses(hero)
	var parts: PackedStringArray = []
	if absf(float(tb["max_hp_pct"])) > 0.001:
		parts.append("HP %+d%%" % roundi(float(tb["max_hp_pct"]) * 100.0))
	if absf(float(tb["atk_pct"])) > 0.001:
		parts.append("ATK %+d%%" % roundi(float(tb["atk_pct"]) * 100.0))
	if absf(float(tb["def_pct"])) > 0.001:
		parts.append("DEF %+d%%" % roundi(float(tb["def_pct"]) * 100.0))
	if absf(float(tb["heal_pct"])) > 0.001:
		parts.append("HEAL %+d%%" % roundi(float(tb["heal_pct"]) * 100.0))
	if absf(float(tb["speed_pct"])) > 0.001:
		parts.append("SPD %+d%%" % roundi(float(tb["speed_pct"]) * 100.0))
	if absf(float(tb["speed_flat"])) > 0.05:
		parts.append("SPD %+d" % roundi(float(tb["speed_flat"])))
	if absf(float(tb["crit_rate"])) > 0.001:
		parts.append("치명 %+d%%" % roundi(float(tb["crit_rate"]) * 100.0))
	if absf(float(tb["crit_dmg"])) > 0.001:
		parts.append("치명피해 %+d%%" % roundi(float(tb["crit_dmg"]) * 100.0))
	if absf(float(tb["dmg_bonus"])) > 0.001:
		parts.append("피해증가 %+d%%" % roundi(float(tb["dmg_bonus"]) * 100.0))
	if absf(float(tb["armor_pen"])) > 0.001:
		parts.append("방관 %+d%%" % roundi(float(tb["armor_pen"]) * 100.0))
	if absf(float(tb["fatigue_mult"])) > 0.001:
		parts.append("피로누적 %+d%%" % roundi(float(tb["fatigue_mult"]) * 100.0))
	return ", ".join(parts) if not parts.is_empty() else "변동 없음"


## 전투 씬에 넘기기 위해 장비/피로도를 제외하고 영웅 기본 스탯 + 기질 보정만 반영한 값을 반환합니다.
func get_hero_base_with_temperament(hero: Dictionary, stat_name: String) -> float:
	if hero.is_empty():
		return 0.0
	var tb: Dictionary = get_hero_temperament_bonuses(hero)
	var base_val: float = float(hero.get(stat_name, 0.0))
	match stat_name:
		"max_hp":
			return maxf(1.0, base_val * maxf(0.20, 1.0 + float(tb["max_hp_pct"])))
		"atk":
			return maxf(1.0, base_val * maxf(0.10, 1.0 + float(tb["atk_pct"])))
		"def":
			return maxf(0.0, base_val * maxf(0.0, 1.0 + float(tb["def_pct"])))
		"heal_power":
			return maxf(0.0, base_val * maxf(0.10, 1.0 + float(tb["heal_pct"])))
		"speed":
			return maxf(1.0, (base_val + float(tb["speed_flat"])) * maxf(0.15, 1.0 + float(tb["speed_pct"])))
		"dmg_bonus":
			return base_val + float(tb["dmg_bonus"])
		"crit_rate":
			return clampf(base_val + float(tb["crit_rate"]), 0.0, 1.0)
		"crit_dmg":
			return maxf(1.0, base_val + float(tb["crit_dmg"]))
		"armor_pen":
			return clampf(base_val + float(tb["armor_pen"]), 0.0, 1.0)
		_:
			return base_val


## 영웅의 기본 스탯 + 기질 보정 + 장착 장비 stat_bonuses + 장비 패시브(SELF 버프)를 합산한 최종 유효 스탯을 반환합니다.
func get_effective_stat(hero: Dictionary, stat_name: String) -> float:
	if hero.is_empty():
		return 0.0
	var eq_bonuses: Dictionary = get_hero_equipment_bonuses(hero)
	var tb: Dictionary = get_hero_temperament_bonuses(hero)
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
			return maxf(1.0, base_val * maxf(0.20, 1.0 + float(tb["max_hp_pct"])))
		"atk":
			return maxf(1.0, base_val * maxf(0.1, 1.0 + pct_add + float(tb["atk_pct"])) * fatigue_mult)
		"def":
			return maxf(0.0, base_val * maxf(0.0, 1.0 + pct_add + float(tb["def_pct"])))
		"heal_power":
			return maxf(0.0, base_val * maxf(0.1, 1.0 + pct_add + float(tb["heal_pct"])))
		"speed":
			return maxf(1.0, (base_val + float(tb["speed_flat"])) * maxf(0.15, 1.0 + pct_add + float(tb["speed_pct"])) * fatigue_mult)
		"dmg_bonus":
			return base_val + flat_add + float(tb["dmg_bonus"])
		"crit_rate":
			return clampf(base_val + flat_add + float(tb["crit_rate"]), 0.0, 1.0)
		"crit_dmg":
			return maxf(1.0, base_val + flat_add + float(tb["crit_dmg"]))
		"armor_pen":
			return clampf(base_val + flat_add + float(tb["armor_pen"]), 0.0, 1.0)
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


func _check_exhaustion_trauma(hero: Dictionary, prev_f: int, next_f: int) -> String:
	if prev_f < MAX_FATIGUE and next_f >= MAX_FATIGUE and randf() < EXHAUSTION_TRAUMA_CHANCE:
		return grant_random_negative_temperament(int(hero.get("uid", -1)))
	return ""


func add_hero_fatigue(uid: int, amount: int) -> Dictionary:
	var hero: Dictionary = get_hero_by_uid(uid)
	if hero.is_empty():
		return {}
	var prev_f: int = int(hero.get("fatigue", 0))
	var scaled_amount: int = amount
	if amount > 0:
		scaled_amount = maxi(1, roundi(float(amount) * get_hero_fatigue_multiplier(hero)))
	var next_f: int = clampi(prev_f + scaled_amount, 0, MAX_FATIGUE)
	hero["fatigue"] = next_f
	var trauma_id: String = _check_exhaustion_trauma(hero, prev_f, next_f)
	roster_changed.emit()
	return {"prev": prev_f, "next": next_f, "hero": hero, "trauma_id": trauma_id}


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
		var sub_or_job: String = str(hero.get("sub_class", hero.get("job_class", "")))
		var costs: Dictionary = DataManager.get_class_fatigue_costs(sub_or_job)
		var cost: int = int(costs.get("move", 4))
		# 선봉 병과 공통 특성: 던전 이동 피로도 -1 경감
		if str(hero.get("class_group", "")) == "선봉":
			cost = maxi(0, cost - 1)
		if cost > 0:
			cost = maxi(1, roundi(float(cost) * get_hero_fatigue_multiplier(hero)))
		var prev_f: int = int(hero.get("fatigue", 0))
		var next_f: int = clampi(prev_f + cost, 0, MAX_FATIGUE)
		hero["fatigue"] = next_f
		var trauma_id: String = _check_exhaustion_trauma(hero, prev_f, next_f)
		changes.append({
			"uid": int(hero.get("uid", 0)),
			"name": str(hero.get("name", "")),
			"cost": cost,
			"fatigue": next_f,
			"trauma_id": trauma_id,
		})
	if not changes.is_empty():
		roster_changed.emit()
	return changes


## 던전 전투 1회 완료 시 활성 원정 파티(또는 로스터) 영웅들의 직군별 전투 피로도를 누적합니다.
func apply_party_battle_fatigue() -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	for hero in get_active_party_heroes():
		if not can_hero_deploy(hero):
			continue
		var sub_or_job: String = str(hero.get("sub_class", hero.get("job_class", "")))
		var costs: Dictionary = DataManager.get_class_fatigue_costs(sub_or_job)
		var cost: int = int(costs.get("battle", 10))
		if cost > 0:
			cost = maxi(1, roundi(float(cost) * get_hero_fatigue_multiplier(hero)))
		var prev_f: int = int(hero.get("fatigue", 0))
		var next_f: int = clampi(prev_f + cost, 0, MAX_FATIGUE)
		hero["fatigue"] = next_f
		var trauma_id: String = _check_exhaustion_trauma(hero, prev_f, next_f)
		changes.append({
			"uid": int(hero.get("uid", 0)),
			"name": str(hero.get("name", "")),
			"cost": cost,
			"fatigue": next_f,
			"trauma_id": trauma_id,
		})
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


## 현재 활성 파티의 던전 탐색 보너스(시야 반경 증가 + 매복 사전 감지 + 세부직군 탐험/보상/타워 특성) 계산
func get_party_exploration_bonuses() -> Dictionary:
	var party: Array[Dictionary] = get_active_party_heroes()
	var total_vision_bonus: int = 0
	var has_danger_sense: bool = false
	var camp_bonus_mult: float = 1.0
	var gold_bonus_mult: float = 1.0
	var supply_bonus_mult: float = 1.0
	var tower_haste_bonus: float = 0.0
	var sources: PackedStringArray = PackedStringArray()

	for hero in party:
		if int(hero.get("hp", 0)) <= 0:
			continue
		var h_name: String = str(hero.get("name", "영웅"))
		var sub_or_job: String = str(hero.get("sub_class", hero.get("job_class", "")))
		var cg: String = str(hero.get("class_group", DataManager.get_class_group_for_sub_class(sub_or_job)))
		var cls_info: Dictionary = DataManager.get_sub_class_info(sub_or_job)
		var sub_trait: String = str(cls_info.get("sub_trait", ""))
		var cls_vision: int = maxi(0, int(cls_info.get("vision_bonus", 1 if (sub_or_job == "척후병" or sub_trait == "VISION_UP") else 0)))
		var cls_sense: bool = bool(cls_info.get("danger_sense", sub_or_job == "척후병" or sub_trait == "DANGER_SENSE"))

		if sub_trait == "CAMP_BONUS":
			camp_bonus_mult = maxf(camp_bonus_mult, 1.50)
		elif sub_trait == "GOLD_BONUS":
			gold_bonus_mult = maxf(gold_bonus_mult, 1.30)
		elif sub_trait == "TRAP_DISARM":
			supply_bonus_mult = maxf(supply_bonus_mult, 1.25)
		elif sub_trait == "TOWER_HASTE":
			tower_haste_bonus = maxf(tower_haste_bonus, 0.20)

		var skill_vision: int = 0
		var skill_sense: bool = false
		var hero_skill_ids: Array[String] = [
			str(hero.get("passive_skill_id", "")),
			str(hero.get("skill_id", "")),
			str(hero.get("skill2_id", "")),
			str(hero.get("ultimate_id", "")),
		]
		var seen_skills: Dictionary = {}
		for sid in hero_skill_ids:
			if sid.is_empty() or seen_skills.has(sid):
				continue
			seen_skills[sid] = true
			var sk: Dictionary = DataManager.get_skill(sid)
			for eff in sk.get("effects", []):
				if typeof(eff) != TYPE_DICTIONARY:
					continue
				var etype: String = str((eff as Dictionary).get("effect_type", ""))
				if etype == "VISION_UP":
					skill_vision += maxi(1, int(round(float((eff as Dictionary).get("multiplier", 1.0)))))
				elif etype == "DANGER_SENSE":
					skill_sense = true

		var equip_vision: int = 0
		var equip_sense: bool = false
		var hero_id: String = str(hero.get("id", ""))
		for eq_tmpl in get_hero_equipped_templates(hero):
			var eq_skill_ids: Array[String] = [str(eq_tmpl.get("passive_skill_id", ""))]
			var excl_id: String = str(eq_tmpl.get("exclusive_hero_id", "")).strip_edges()
			if excl_id.is_empty() or excl_id == hero_id:
				eq_skill_ids.append(str(eq_tmpl.get("resonance_skill_id", "")))
			for eq_sid in eq_skill_ids:
				if eq_sid.is_empty():
					continue
				var eq_sk: Dictionary = DataManager.get_skill(eq_sid)
				for eff in eq_sk.get("effects", []):
					if typeof(eff) != TYPE_DICTIONARY:
						continue
					var etype: String = str((eff as Dictionary).get("effect_type", ""))
					if etype == "VISION_UP":
						equip_vision += maxi(1, int(round(float((eff as Dictionary).get("multiplier", 1.0)))))
					elif etype == "DANGER_SENSE":
						equip_sense = true

		var hero_vis: int = maxi(cls_vision, skill_vision) + equip_vision
		var hero_sense: bool = cls_sense or skill_sense or equip_sense
		if hero_vis > 0:
			total_vision_bonus += hero_vis
		if hero_sense:
			has_danger_sense = true
		if hero_vis > 0 or hero_sense:
			var tag: String = "%s(%s-%s)" % [h_name, cg, sub_or_job]
			if not sources.has(tag):
				sources.append(tag)

	var clamped_bonus: int = clampi(total_vision_bonus, 0, 3)
	return {
		"base_vision": 1,
		"vision_bonus": clamped_bonus,
		"vision_radius": 1 + clamped_bonus,
		"danger_sense": has_danger_sense,
		"camp_bonus_mult": camp_bonus_mult,
		"gold_bonus_mult": gold_bonus_mult,
		"supply_bonus_mult": supply_bonus_mult,
		"tower_haste_bonus": tower_haste_bonus,
		"sources": sources,
	}


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
	rebellion_suppression_active = false
	field_dungeon_state.clear()
	upcoming_defense_elements.clear()
	dungeon_floor = 1
	auto_battle_mode = AutoBattleMode.MANUAL
	battle_speed_mult = 1.0
	reset_run_stats()
	victory_achieved = false
	is_endless_mode = false
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
	run_stats_changed.emit()


# ==========================================
# 누적 플레이 통계 & 최종 랭크 평가
# ==========================================
func reset_run_stats() -> void:
	run_stats = {
		"defenses_won": 0,
		"bosses_defeated": 0,
		"dungeons_cleared": 0,
		"heroes_recruited": 0,
		"events_resolved": 0,
	}
	run_stats_changed.emit()


func record_defense_won() -> void:
	run_stats["defenses_won"] = int(run_stats.get("defenses_won", 0)) + 1
	run_stats_changed.emit()


func record_boss_defeated() -> void:
	run_stats["bosses_defeated"] = int(run_stats.get("bosses_defeated", 0)) + 1
	run_stats_changed.emit()


func record_dungeon_cleared() -> void:
	run_stats["dungeons_cleared"] = int(run_stats.get("dungeons_cleared", 0)) + 1
	run_stats_changed.emit()


func record_hero_recruited() -> void:
	run_stats["heroes_recruited"] = int(run_stats.get("heroes_recruited", 0)) + 1
	run_stats_changed.emit()


func record_event_resolved() -> void:
	run_stats["events_resolved"] = int(run_stats.get("events_resolved", 0)) + 1
	run_stats_changed.emit()


func evaluate_victory_rank() -> Dictionary:
	var named_count: int = get_owned_named_heroes().size()
	var score: int = (
		int(run_stats.get("defenses_won", 0)) * 12
		+ int(run_stats.get("bosses_defeated", 0)) * 35
		+ int(run_stats.get("dungeons_cleared", 0)) * 25
		+ int(run_stats.get("heroes_recruited", 0)) * 25
		+ int(run_stats.get("events_resolved", 0)) * 2
		+ citizen_morale * 2
		+ wall_level * 40
		+ named_count * 70
		+ completed_research_ids.size() * 30
	)

	if score >= 1600:
		return {"rank": "S", "title": "불멸의 성채 수호자", "score": score, "color": Color(1.0, 0.84, 0.25)}
	if score >= 1000:
		return {"rank": "A", "title": "위대한 영지 사령관", "score": score, "color": Color(0.68, 0.58, 1.0)}
	if score >= 550:
		return {"rank": "B", "title": "숙련된 변방의 수호자", "score": score, "color": Color(0.45, 0.88, 1.0)}
	return {"rank": "C", "title": "끈질긴 개척의 생존자", "score": score, "color": Color(0.70, 0.90, 0.72)}


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


## 반란 위험도가 높거나 내정 토벌 이벤트가 활성화되었는지 여부 (인간형 반란군/교단 주력 스폰 판단)
func is_rebellion_humanoid_preferred() -> bool:
	return rebellion_suppression_active or rebellion_risk >= 4 or should_trigger_rebellion_event()
