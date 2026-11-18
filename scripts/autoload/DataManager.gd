extends Node
## 외부 JSON 모딩 데이터 로더 및 저장 매니저 (Autoload: DataManager)
## 개발 중에는 res://data/, 빌드 후에는 실행 파일 옆 data/ 폴더에서
## heroes/*.json 및 events/*.json을 자동으로 스캔해 로드합니다.

signal data_reloaded()

const SUBDIR_HEROES: String = "heroes"
const SUBDIR_EVENTS: String = "events"
const ELEMENTS_FILE: String = "elements.json"
const SKILLS_FILE: String = "skills.json"
const EQUIPMENTS_FILE: String = "equipments.json"
const CLASSES_FILE: String = "classes.json"
const DUNGEONS_FILE: String = "dungeons.json"
const DUNGEON_EVENTS_FILE: String = "dungeon_events.json"
const ENEMIES_FILE: String = "enemies.json"
const TOWERS_FILE: String = "towers.json"
const RESEARCH_FILE: String = "research.json"
const ITEMS_FILE: String = "items.json"

const EVENT_CATEGORIES: Array[String] = ["NORMAL", "REBELLION"]
const EVENT_CATEGORY_LABELS: Dictionary = {
	"NORMAL": "일반 정책 (NORMAL)",
	"REBELLION": "반란·위기 (REBELLION)",
}

const ITEM_TYPES: Array[String] = [
	"HEAL_HP",
	"HEAL_ALL_HP",
	"RECOVER_FATIGUE",
	"BUFF_ATK",
	"BUFF_DEF",
	"DAMAGE_ENEMY",
	"SHIELD_ALL",
	"CLEANSE",
]
const ITEM_TYPE_LABELS: Dictionary = {
	"HEAL_HP": "단일 체력 회복 (HEAL_HP)",
	"HEAL_ALL_HP": "전체 체력 회복 (HEAL_ALL_HP)",
	"RECOVER_FATIGUE": "파티 피로도 회복 (RECOVER_FATIGUE)",
	"BUFF_ATK": "공격력 버프 (BUFF_ATK)",
	"BUFF_DEF": "방어력 버프 (BUFF_DEF)",
	"DAMAGE_ENEMY": "적 피해 투척 (DAMAGE_ENEMY)",
	"SHIELD_ALL": "전체 보호막+정화 (SHIELD_ALL)",
	"CLEANSE": "상태이상 정화 (CLEANSE)",
}
const ITEM_SCOPES: Array[String] = ["SINGLE_ALLY", "ALL_ALLIES", "SINGLE_ENEMY", "ALL_ENEMIES"]

const NAMED_SOURCES: Array[String] = ["NONE", "STORY", "NON_STORY"]
const NAMED_SOURCE_LABELS: Dictionary = {
	"NONE": "비네임드 (일반)",
	"STORY": "네임드 · 스토리 획득",
	"NON_STORY": "네임드 · 스토리 외(주점·탐험)",
}

const DUNGEON_TYPES: Array[String] = ["FIELD_GRID", "MINI_ROGUE"]
const ENEMY_TYPES: Array[String] = ["NORMAL", "ELITE", "BOSS", "SIEGE"]
const ENEMY_CATEGORIES: Array[String] = ["MONSTER", "HUMANOID"]
const ENEMY_CATEGORY_LABELS: Dictionary = {
	"MONSTER": "괴물형 (MONSTER)",
	"HUMANOID": "인간형 (HUMANOID)",
}
const ENEMY_ARCHETYPES_BY_CATEGORY: Dictionary = {
	"MONSTER": ["SWARMER", "BEHEMOTH", "SPITTER", "VOLATILE", "THORNBACK", "BROODMOTHER", "ABYSSAL_LORD"],
	"HUMANOID": ["FOOTMAN", "PHALANX", "CUTTHROAT", "ARBALEST", "PREACHER", "SIEGE_CREW", "COMMANDER"],
}
const ENEMY_ARCHETYPE_LABELS: Dictionary = {
	"SWARMER": "군집 돌격수 (SWARMER)",
	"BEHEMOTH": "외골격 거수 (BEHEMOTH)",
	"SPITTER": "산성/포자 분출체 (SPITTER)",
	"VOLATILE": "자폭 변이체 (VOLATILE)",
	"THORNBACK": "가시 갑각체 (THORNBACK)",
	"BROODMOTHER": "기생/분열체 (BROODMOTHER)",
	"ABYSSAL_LORD": "심연 재앙체 보스 (ABYSSAL_LORD)",
	"FOOTMAN": "약탈/반란 보병 (FOOTMAN)",
	"PHALANX": "중장갑 방패기사 (PHALANX)",
	"CUTTHROAT": "척후 암살자 (CUTTHROAT)",
	"ARBALEST": "석궁/마도포병 (ARBALEST)",
	"PREACHER": "교단 사제/군악대 (PREACHER)",
	"SIEGE_CREW": "공성 기술병/충차 (SIEGE_CREW)",
	"COMMANDER": "지휘관/배교자 보스 (COMMANDER)",
}
const PALETTE_ELEMENT_MODS: Dictionary = {
	"FIRE": {"prefix": "작열하는", "skill_id": "skill_palette_fire", "hp_mult": 1.0, "atk_mult": 1.12, "def_add": 0, "spd_mult": 1.0},
	"ICE": {"prefix": "서리맺힌", "skill_id": "skill_palette_ice", "hp_mult": 1.08, "atk_mult": 1.0, "def_add": 4, "spd_mult": 0.95},
	"WIND": {"prefix": "질풍의", "skill_id": "skill_palette_wind", "hp_mult": 0.95, "atk_mult": 1.05, "def_add": 0, "spd_mult": 1.20},
	"WATER": {"prefix": "심해의", "skill_id": "skill_palette_water", "hp_mult": 1.15, "atk_mult": 1.0, "def_add": 2, "spd_mult": 1.0},
	"EARTH": {"prefix": "암반의", "skill_id": "skill_palette_earth", "hp_mult": 1.12, "atk_mult": 0.98, "def_add": 6, "spd_mult": 0.92},
	"LIGHTNING": {"prefix": "뇌전의", "skill_id": "skill_palette_lightning", "hp_mult": 1.0, "atk_mult": 1.10, "def_add": 0, "spd_mult": 1.12},
	"LIGHT": {"prefix": "성광의", "skill_id": "skill_palette_light", "hp_mult": 1.10, "atk_mult": 1.06, "def_add": 3, "spd_mult": 1.0},
	"DARK": {"prefix": "공허의", "skill_id": "skill_palette_dark", "hp_mult": 1.02, "atk_mult": 1.14, "def_add": 1, "spd_mult": 1.06},
}
const SEASONS: Array[String] = ["ALL", "SPRING", "SUMMER", "AUTUMN", "WINTER"]
const TOWER_SCOPES: Array[String] = ["SINGLE_FRONT", "AOE_SMALL", "AOE_LARGE", "ALL_ENEMIES"]
const SLOT_TYPES: Array[String] = ["WEAPON", "ARMOR", "ACCESSORY"]
const SLOT_LABELS: Dictionary = {
	"WEAPON": "무기",
	"ARMOR": "방어구",
	"ACCESSORY": "장신구",
}
const EQUIP_STAT_KEYS: Array[String] = [
	"max_hp",
	"atk",
	"def",
	"speed",
	"dmg_bonus",
	"crit_rate",
	"crit_dmg",
	"armor_pen",
	"final_dmg_mult",
]

const ROLE_CATEGORIES: Array[String] = ["전위", "중위", "후위"]
const CLASS_GROUPS: Array[String] = ["중장", "근위", "선봉", "특수", "보조", "저격", "술사", "의료"]
const CLASS_GROUPS_BY_CATEGORY: Dictionary = {
	"전위": ["중장", "근위", "선봉"],
	"중위": ["특수", "보조"],
	"후위": ["저격", "술사", "의료"],
}
const CLASS_GROUP_TO_CATEGORY: Dictionary = {
	"중장": "전위",
	"근위": "전위",
	"선봉": "전위",
	"특수": "중위",
	"보조": "중위",
	"저격": "후위",
	"술사": "후위",
	"의료": "후위",
}
const SUB_CLASSES_BY_GROUP: Dictionary = {
	"중장": ["방패수호자", "성기사", "심연의 파수꾼", "중갑돌격병"],
	"근위": ["검투사", "광전사", "마검사", "피의 기사"],
	"선봉": ["용기사", "무투가", "공병대장", "야수조련사"],
	"특수": ["척후병", "그림자 암살자", "창술사", "의적", "쌍검무희"],
	"보조": ["음유시인", "연금술사", "사냥꾼", "주술사", "풍수사", "기계공학자"],
	"저격": ["장궁병", "석궁병", "포격수"],
	"술사": ["원소술사", "빙결술사", "시간술사", "소환사", "강령술사", "천문학자"],
	"의료": ["대사제", "전투사제", "약초학자", "점성술사"],
}
const LEGACY_JOB_TO_HIERARCHY: Dictionary = {
	"탱커": {"group": "중장", "sub": "방패수호자"},
	"근접딜러": {"group": "근위", "sub": "검투사"},
	"돌격검객": {"group": "근위", "sub": "검투사"},
	"원거리딜러": {"group": "저격", "sub": "장궁병"},
	"속사명사수": {"group": "저격", "sub": "석궁병"},
	"장거리저격수": {"group": "저격", "sub": "장궁병"},
	"마법사": {"group": "술사", "sub": "원소술사"},
	"힐러": {"group": "의료", "sub": "대사제"},
	"성역치유사": {"group": "의료", "sub": "대사제"},
	"특수": {"group": "특수", "sub": "척후병"},
	"연금교란가": {"group": "보조", "sub": "연금술사"},
	"음유전령": {"group": "보조", "sub": "음유시인"},
	"척후병": {"group": "특수", "sub": "척후병"},
	"요새수비대": {"group": "중장", "sub": "심연의 파수꾼"},
	"결투무사": {"group": "근위", "sub": "검투사"},
	"암살추적자": {"group": "특수", "sub": "그림자 암살자"},
}
const DEFAULT_CLASS_GROUP_TRAITS: Dictionary = {
	"중장": {"id": "중장", "role_category": "전위", "trait_id": "DEFENDER_BASTION", "trait_name": "철벽 방진", "trait_desc": "디펜스 성벽 밖 기본 저지 수 +1(총 4저지), 전열 배치 시 받는 피해 -10%"},
	"근위": {"id": "근위", "role_category": "전위", "trait_id": "GUARD_EXECUTION", "trait_name": "파쇄 돌격", "trait_desc": "근접 공격 시 방어력 10% 무시, 적 처치 시 다음 턴 속도 +2"},
	"선봉": {"id": "선봉", "role_category": "전위", "trait_id": "VANGUARD_PIONEER", "trait_name": "선봉 기동", "trait_desc": "던전 이동 피로도 -1 경감, 전투 첫 턴 속도(SPD) +3"},
	"특수": {"id": "특수", "role_category": "중위", "trait_id": "SPECIALIST_TRICK", "trait_name": "변칙 기동", "trait_desc": "진형 이동(밀치기/당기기/교환) 성공률 100%, 기습 공격 시 치명피해 +20%"},
	"보조": {"id": "보조", "role_category": "중위", "trait_id": "SUPPORTER_TACTIC", "trait_name": "전술 공명", "trait_desc": "부여하는 버프·디버프 지속시간 +1턴(디펜스 +2초) 연장"},
	"저격": {"id": "저격", "role_category": "후위", "trait_id": "SNIPER_EAGLE_WALL", "trait_name": "고지 사격", "trait_desc": "디펜스 성벽 위 배치 시 사거리 추가 +15%"},
	"술사": {"id": "술사", "role_category": "후위", "trait_id": "CASTER_OVERLOAD", "trait_name": "원소 증폭", "trait_desc": "속성 상성 우위(1.5x) 공격 시 최종 피해 +15%"},
	"의료": {"id": "의료", "role_category": "후위", "trait_id": "MEDIC_AEGIS_WARD", "trait_name": "구호 결계", "trait_desc": "치유 실행 시 대상에게 1턴(디펜스 2초)간 받는 피해 -10% 보호 가호 부여"},
}
const RARITIES: Array[String] = ["N", "R", "SR", "SSR"]
const RARITY_COLORS: Dictionary = {
	"N": Color(0.70, 0.72, 0.76, 1.0),
	"R": Color(0.35, 0.75, 1.00, 1.0),
	"SR": Color(0.76, 0.45, 1.00, 1.0),
	"SSR": Color(1.00, 0.78, 0.22, 1.0),
}
const JOB_CLASSES_BY_CATEGORY: Dictionary = {
	"전위": ["방패수호자", "성기사", "심연의 파수꾼", "중갑돌격병", "검투사", "광전사", "마검사", "피의 기사", "용기사", "무투가", "공병대장", "야수조련사"],
	"중위": ["척후병", "그림자 암살자", "창술사", "의적", "쌍검무희", "음유시인", "연금술사", "사냥꾼", "주술사", "풍수사", "기계공학자"],
	"후위": ["장궁병", "석궁병", "포격수", "원소술사", "빙결술사", "시간술사", "소환사", "강령술사", "천문학자", "대사제", "전투사제", "약초학자", "점성술사"],
}

const EFFECT_TYPES: Array[String] = [
	"DAMAGE",
	"HEAL",
	"SHIELD",
	"BUFF_ATK",
	"BUFF_DEF",
	"BUFF_SPEED",
	"BUFF_DMG_BONUS",
	"BUFF_CRIT_RATE",
	"BUFF_CRIT_DMG",
	"BUFF_ARMOR_PEN",
	"BUFF_FINAL_DMG",
	"BURN",
	"POISON",
	"STUN",
	"SLOW",
	"DEF_DOWN",
	"REFLECT",
	"EXPLODE_ON_DEATH",
	"PUSH_BACK",
	"PULL_FRONT",
	"SWAP_POS",
	"SHUFFLE_POS",
	"VISION_UP",
	"DANGER_SENSE",
]

const TARGET_SCOPES: Array[String] = [
	"SINGLE_FRONT",
	"SINGLE_BACK",
	"ROW",
	"COLUMN",
	"CROSS",
	"SQUARE_2X2",
	"ALL_ENEMIES",
	"AOE_SMALL",
	"AOE_LARGE",
	"SELF",
	"SINGLE_ALLY",
	"ALL_ALLIES",
]

var heroes: Array[Dictionary] = []
var events: Array[Dictionary] = []
var elements: Array[Dictionary] = []
var element_map: Dictionary = {}
var element_matrix: Dictionary = {}
var skills: Array[Dictionary] = []
var skill_map: Dictionary = {}
var equipments: Array[Dictionary] = []
var equipment_map: Dictionary = {}
var classes: Array[Dictionary] = []
var class_map: Dictionary = {}
var dungeons: Array[Dictionary] = []
var dungeon_map: Dictionary = {}
var dungeon_events: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var enemy_map: Dictionary = {}
var towers: Array[Dictionary] = []
var tower_map: Dictionary = {}
var researches: Array[Dictionary] = []
var research_map: Dictionary = {}
var items: Array[Dictionary] = []
var item_map: Dictionary = {}
var class_groups: Array[Dictionary] = []
var class_group_map: Dictionary = {}


func _ready() -> void:
	ensure_data_directories()
	reload_all_data()


## 개발 환경(res://data) 또는 배포 환경(실행 파일 경로/data)의 루트 경로를 반환합니다.
func get_data_root_path() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://data")
	return OS.get_executable_path().get_base_dir().path_join("data")


func get_heroes_dir_path() -> String:
	return get_data_root_path().path_join(SUBDIR_HEROES)


func get_events_dir_path() -> String:
	return get_data_root_path().path_join(SUBDIR_EVENTS)


func get_elements_file_path() -> String:
	return get_data_root_path().path_join(ELEMENTS_FILE)


func get_skills_file_path() -> String:
	return get_data_root_path().path_join(SKILLS_FILE)


func get_equipments_file_path() -> String:
	return get_data_root_path().path_join(EQUIPMENTS_FILE)


func get_classes_file_path() -> String:
	return get_data_root_path().path_join(CLASSES_FILE)


func get_dungeons_file_path() -> String:
	return get_data_root_path().path_join(DUNGEONS_FILE)


func get_dungeon_events_file_path() -> String:
	return get_data_root_path().path_join(DUNGEON_EVENTS_FILE)


func get_enemies_file_path() -> String:
	return get_data_root_path().path_join(ENEMIES_FILE)


func get_towers_file_path() -> String:
	return get_data_root_path().path_join(TOWERS_FILE)


func get_research_file_path() -> String:
	return get_data_root_path().path_join(RESEARCH_FILE)


func get_items_file_path() -> String:
	return get_data_root_path().path_join(ITEMS_FILE)


func ensure_data_directories() -> void:
	DirAccess.make_dir_recursive_absolute(get_heroes_dir_path())
	DirAccess.make_dir_recursive_absolute(get_events_dir_path())


## data/ 내 모든 외부 JSON 모딩 파일을 다시 읽어들입니다.
func reload_all_data() -> void:
	ensure_data_directories()
	load_elements()
	load_skills()
	load_equipments()
	load_classes()
	load_dungeons()
	load_dungeon_events()
	load_enemies()
	load_towers()
	load_researches()
	load_items()
	heroes = _load_json_folder(get_heroes_dir_path(), _normalize_hero)
	events = _load_json_folder(get_events_dir_path(), _normalize_event)
	data_reloaded.emit()


## data/elements.json에서 동적 속성 목록과 상성 매트릭스를 로드합니다.
func load_elements() -> void:
	elements.clear()
	element_map.clear()
	element_matrix.clear()

	var path: String = get_elements_file_path()
	if not FileAccess.file_exists(path):
		push_warning("DataManager: elements.json 파일을 찾을 수 없습니다 -> %s" % path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("DataManager: elements.json 파싱 실패 -> %s" % path)
		return

	var data: Dictionary = parsed
	var raw_elements: Variant = data.get("elements", [])
	if typeof(raw_elements) == TYPE_ARRAY:
		for item in raw_elements:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var elem_id: String = str(item.get("id", "")).strip_edges().to_upper()
			if elem_id.is_empty():
				continue
			var entry: Dictionary = {
				"id": elem_id,
				"name": str(item.get("name", elem_id)),
				"color": str(item.get("color", "#FFFFFF")),
			}
			elements.append(entry)
			element_map[elem_id] = entry

	var raw_matrix: Variant = data.get("matrix", {})
	if typeof(raw_matrix) == TYPE_DICTIONARY:
		var mat_dict: Dictionary = raw_matrix
		for atk_key in mat_dict:
			var atk_id: String = str(atk_key).strip_edges().to_upper()
			var row_val: Variant = mat_dict[atk_key]
			if typeof(row_val) != TYPE_DICTIONARY:
				continue
			var clean_row: Dictionary = {}
			var row_dict: Dictionary = row_val
			for def_key in row_dict:
				var def_id: String = str(def_key).strip_edges().to_upper()
				clean_row[def_id] = float(row_dict[def_key])
			element_matrix[atk_id] = clean_row


func get_element_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for e in elements:
		ids.append(str(e["id"]))
	return ids


func get_element_info(element_id: String) -> Dictionary:
	return element_map.get(element_id.strip_edges().to_upper(), {})


func get_element_name(element_id: String) -> String:
	var key: String = element_id.strip_edges().to_upper()
	if element_map.has(key):
		return str(element_map[key].get("name", key))
	return key if not key.is_empty() else "무속성"


func get_element_color(element_id: String) -> Color:
	var key: String = element_id.strip_edges().to_upper()
	if element_map.has(key):
		return Color.from_string(str(element_map[key].get("color", "#FFFFFF")), Color.WHITE)
	return Color.WHITE


## 공격 속성 → 방어 속성 상성 배율을 반환합니다.
## 모더가 추가한 속성 등 매트릭스에 누락된 조합이 있으면 안전하게 기본값 1.0을 반환합니다.
func get_element_multiplier(attacker_element: String, defender_element: String) -> float:
	var atk_key: String = attacker_element.strip_edges().to_upper()
	var def_key: String = defender_element.strip_edges().to_upper()
	if atk_key.is_empty() or def_key.is_empty():
		return 1.0
	if not element_matrix.has(atk_key):
		return 1.0
	var row: Dictionary = element_matrix[atk_key]
	if not row.has(def_key):
		return 1.0
	return float(row[def_key])


func _load_json_folder(folder_path: String, normalizer: Callable) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return results

	var files: PackedStringArray = dir.get_files()
	files.sort()

	for file_name in files:
		if not file_name.to_lower().ends_with(".json"):
			continue
		var full_path: String = folder_path.path_join(file_name)
		var file := FileAccess.open(full_path, FileAccess.READ)
		if file == null:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			push_warning("DataManager: JSON 객체 형식이 아닙니다 -> %s" % full_path)
			continue
		var item: Dictionary = normalizer.call(parsed, full_path)
		results.append(item)

	return results


func get_class_groups_for_category(category: String) -> Array:
	var norm_cat: String = normalize_role_category(category)
	return CLASS_GROUPS_BY_CATEGORY.get(norm_cat, ["중장"])


func get_sub_classes_for_group(class_group: String) -> Array:
	var cg: String = class_group.strip_edges()
	return SUB_CLASSES_BY_GROUP.get(cg, ["방패수호자"])


func get_class_group_for_sub_class(sub_or_job: String) -> String:
	var s: String = sub_or_job.strip_edges()
	if class_map.has(s):
		var cg: String = str(class_map[s].get("class_group", ""))
		if not cg.is_empty():
			return cg
	for cg in SUB_CLASSES_BY_GROUP:
		var arr: Array = SUB_CLASSES_BY_GROUP[cg]
		if arr.has(s):
			return cg
	if LEGACY_JOB_TO_HIERARCHY.has(s):
		return str(LEGACY_JOB_TO_HIERARCHY[s]["group"])
	return "근위"


func get_class_group_info(class_group: String) -> Dictionary:
	var cg: String = class_group.strip_edges()
	if class_group_map.has(cg):
		return class_group_map[cg]
	return DEFAULT_CLASS_GROUP_TRAITS.get(cg, DEFAULT_CLASS_GROUP_TRAITS["근위"])


func get_sub_class_info(sub_or_job: String) -> Dictionary:
	var s: String = sub_or_job.strip_edges()
	if class_map.has(s):
		return class_map[s]
	if LEGACY_JOB_TO_HIERARCHY.has(s):
		var mapped: String = str(LEGACY_JOB_TO_HIERARCHY[s]["sub"])
		if class_map.has(mapped):
			return class_map[mapped]
		return {"id": mapped, "name": mapped, "class_group": str(LEGACY_JOB_TO_HIERARCHY[s]["group"]), "sub_trait": "", "sub_trait_label": "", "sub_trait_desc": ""}
	return {}


## 8대 병과(class_group) × 36 세부직군(sub_class) 정규화 (레거시 job_class 자동 변환 포함)
func normalize_class_hierarchy(raw_group: String, raw_sub_or_job: String, raw_cat: String = "") -> Dictionary:
	var g: String = raw_group.strip_edges()
	var s: String = raw_sub_or_job.strip_edges()

	if LEGACY_JOB_TO_HIERARCHY.has(s):
		var leg: Dictionary = LEGACY_JOB_TO_HIERARCHY[s]
		if g.is_empty() or not CLASS_GROUPS.has(g):
			g = str(leg["group"])
		s = str(leg["sub"])

	var inferred_g: String = get_class_group_for_sub_class(s) if not s.is_empty() else ""
	if not g.is_empty() and CLASS_GROUPS.has(g):
		var allowed_subs: Array = get_sub_classes_for_group(g)
		if s.is_empty() or not allowed_subs.has(s):
			if not s.is_empty() and not inferred_g.is_empty() and g == inferred_g:
				pass
			elif not s.is_empty() and class_map.has(s):
				g = get_class_group_for_sub_class(s)
			else:
				s = str(allowed_subs[0])
	else:
		if not s.is_empty() and (class_map.has(s) or not inferred_g.is_empty()):
			g = get_class_group_for_sub_class(s)
		else:
			var norm_cat: String = normalize_role_category(raw_cat)
			var c_groups: Array = get_class_groups_for_category(norm_cat)
			g = str(c_groups[0])
			s = str(get_sub_classes_for_group(g)[0])

	var final_cat: String = str(CLASS_GROUP_TO_CATEGORY.get(g, "전위"))
	return {
		"role_category": final_cat,
		"class_group": g,
		"sub_class": s,
	}


func get_job_classes_for_category(category: String) -> Array:
	var norm_cat: String = normalize_role_category(category)
	return JOB_CLASSES_BY_CATEGORY.get(norm_cat, ["방패수호자"])


func normalize_role_category(raw_cat: String, job_class: String = "") -> String:
	match raw_cat.strip_edges():
		"전위", "근거리":
			return "전위"
		"중위", "특수":
			return "중위"
		"후위", "원거리":
			return "후위"
	if not job_class.is_empty():
		return infer_category_from_job(job_class)
	return "전위"


func infer_category_from_job(job_class: String) -> String:
	var s: String = job_class.strip_edges()
	if LEGACY_JOB_TO_HIERARCHY.has(s):
		var g: String = str(LEGACY_JOB_TO_HIERARCHY[s]["group"])
		return str(CLASS_GROUP_TO_CATEGORY.get(g, "전위"))
	for cat in ROLE_CATEGORIES:
		var jobs: Array = JOB_CLASSES_BY_CATEGORY[cat]
		if jobs.has(s):
			return cat
	if CLASS_GROUP_TO_CATEGORY.has(s):
		return str(CLASS_GROUP_TO_CATEGORY[s])
	return "전위"


func normalize_rarity(raw_rarity: Variant) -> String:
	var r: String = str(raw_rarity).strip_edges().to_upper()
	if RARITIES.has(r):
		return r
	return "N"


func get_rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(normalize_rarity(rarity), Color(0.70, 0.72, 0.76, 1.0))


func get_skill_slot_rules(rarity: String) -> Dictionary:
	match normalize_rarity(rarity):
		"R":
			return {"passive": true, "active1": true, "active2": false, "ultimate": false}
		"SR":
			return {"passive": true, "active1": true, "active2": true, "ultimate": false}
		"SSR":
			return {"passive": true, "active1": true, "active2": true, "ultimate": true}
		_:
			return {"passive": true, "active1": false, "active2": false, "ultimate": false}


func _normalize_hero(raw: Dictionary, file_path: String) -> Dictionary:
	var fallback_id: String = file_path.get_file().get_basename()
	var raw_sub: String = str(raw.get("sub_class", raw.get("job_class", ""))).strip_edges()
	var raw_group: String = str(raw.get("class_group", "")).strip_edges()
	var hier: Dictionary = normalize_class_hierarchy(raw_group, raw_sub, str(raw.get("role_category", "")))
	var role_category: String = str(hier["role_category"])
	var class_group: String = str(hier["class_group"])
	var sub_class: String = str(hier["sub_class"])
	var job_class: String = sub_class

	var default_elem: String = str(elements[0]["id"]) if not elements.is_empty() else "FIRE"
	var elem_id: String = str(raw.get("element", default_elem)).strip_edges().to_upper()
	if elem_id.is_empty():
		elem_id = default_elem

	var rarity: String = normalize_rarity(raw.get("rarity", "R" if not str(raw.get("skill_id", "")).is_empty() else "N"))
	var slots: Dictionary = get_skill_slot_rules(rarity)
	var is_named_hero: bool = bool(raw.get("is_named", false))
	var raw_src: String = str(raw.get("named_source", "")).strip_edges().to_upper()
	var named_source: String = "NONE"
	if is_named_hero:
		if raw_src == "STORY" or raw_src == "NON_STORY":
			named_source = raw_src
		else:
			named_source = "NON_STORY"

	var raw_fixed_t: Array[String] = []
	for ft in raw.get("fixed_temperaments", []):
		var fts: String = str(ft).strip_edges()
		if not fts.is_empty() and not raw_fixed_t.has(fts):
			raw_fixed_t.append(fts)
	var lock_gen_t: bool = bool(raw.get("lock_general_temperaments", is_named_hero or not raw_fixed_t.is_empty()))

	return {
		"id": str(raw.get("id", fallback_id)),
		"name": str(raw.get("name", "이름 없는 영웅")),
		"is_named": is_named_hero,
		"named_source": named_source,
		"named_title": str(raw.get("named_title", "")).strip_edges(),
		"lore": str(raw.get("lore", "")).strip_edges(),
		"signature_equip_id": str(raw.get("signature_equip_id", "")).strip_edges(),
		"fixed_temperaments": raw_fixed_t,
		"lock_general_temperaments": lock_gen_t,
		"rarity": rarity,
		"role_category": role_category,
		"class_group": class_group,
		"sub_class": sub_class,
		"job_class": job_class,
		"element": elem_id,
		"max_hp": int(raw.get("max_hp", 50)),
		"atk": int(raw.get("atk", 15)),
		"def": int(raw.get("def", 10)),
		"heal_power": int(raw.get("heal_power", 0)),
		"speed": int(raw.get("speed", 10)),
		"dmg_bonus": float(raw.get("dmg_bonus", 0.0)),
		"crit_rate": clampf(float(raw.get("crit_rate", 0.05)), 0.0, 1.0),
		"crit_dmg": maxf(1.0, float(raw.get("crit_dmg", 1.5))),
		"armor_pen": clampf(float(raw.get("armor_pen", 0.0)), 0.0, 1.0),
		"final_dmg_mult": maxf(0.1, float(raw.get("final_dmg_mult", 1.0))),
		"offense_rank": str(raw.get("offense_rank", "전열")),
		"defense_zone": str(raw.get("defense_zone", "성벽밖")),
		"skill_id": str(raw.get("skill_id", "")) if slots["active1"] else "",
		"skill2_id": str(raw.get("skill2_id", "")) if slots["active2"] else "",
		"ultimate_id": str(raw.get("ultimate_id", "")) if slots["ultimate"] else "",
		"passive_skill_id": str(raw.get("passive_skill_id", "")).strip_edges(),
		"skill_description": str(raw.get("skill_description", "")),
		"portrait_path": str(raw.get("portrait_path", "")).strip_edges(),
		"sprite_path": str(raw.get("sprite_path", "")).strip_edges(),
		"_file_path": file_path,
	}


func _normalize_event(raw: Dictionary, file_path: String) -> Dictionary:
	var fallback_id: String = file_path.get_file().get_basename()
	var cat: String = str(raw.get("event_category", "NORMAL")).strip_edges().to_upper()
	if not EVENT_CATEGORIES.has(cat):
		cat = "NORMAL"
	var min_s: int = clampi(int(raw.get("min_stage", 1)), 1, 6)
	var max_s: int = clampi(int(raw.get("max_stage", 6)), min_s, 6)
	return {
		"id": str(raw.get("id", fallback_id)),
		"title": str(raw.get("title", "이름 없는 이벤트")),
		"description": str(raw.get("description", "")),
		"event_category": cat,
		"min_stage": min_s,
		"max_stage": max_s,
		"illustration_path": str(raw.get("illustration_path", "")).strip_edges(),
		"option_a": _normalize_event_option(raw.get("option_a", {}), "선택지 A"),
		"option_b": _normalize_event_option(raw.get("option_b", {}), "선택지 B"),
		"_file_path": file_path,
	}


func _normalize_event_option(raw_opt: Variant, default_text: String) -> Dictionary:
	var opt: Dictionary = raw_opt if typeof(raw_opt) == TYPE_DICTIONARY else {}
	var raw_deltas: Variant = opt.get("deltas", {})
	var deltas_dict: Dictionary = raw_deltas if typeof(raw_deltas) == TYPE_DICTIONARY else {}
	return {
		"text": str(opt.get("text", default_text)),
		"deltas": _normalize_deltas(deltas_dict),
		"recruit_hero_id": str(opt.get("recruit_hero_id", deltas_dict.get("recruit_hero_id", ""))).strip_edges(),
		"grant_equip_id": str(opt.get("grant_equip_id", deltas_dict.get("grant_equip_id", ""))).strip_edges(),
		"grant_item_id": str(opt.get("grant_item_id", deltas_dict.get("grant_item_id", ""))).strip_edges(),
	}


func _normalize_deltas(raw_deltas: Variant) -> Dictionary:
	var out: Dictionary = {"food": 0, "materials": 0, "morale": 0}
	if typeof(raw_deltas) != TYPE_DICTIONARY:
		return out
	var d: Dictionary = raw_deltas
	for key in d:
		var k_str: String = str(key)
		if k_str in ["recruit_hero_id", "grant_equip_id", "grant_item_id"]:
			continue
		out[k_str] = int(d[key])
	return out


## 영웅 데이터를 지정된 JSON 파일(없으면 새 파일 생성)로 저장합니다.
func save_hero(hero_data: Dictionary, existing_file_path: String = "") -> String:
	ensure_data_directories()
	var target_path: String = existing_file_path
	if target_path.is_empty():
		target_path = _generate_unique_json_path(get_heroes_dir_path(), "hero", str(hero_data.get("name", "")))

	var default_elem: String = str(elements[0]["id"]) if not elements.is_empty() else "FIRE"
	var elem_id: String = str(hero_data.get("element", default_elem)).strip_edges().to_upper()
	if elem_id.is_empty():
		elem_id = default_elem

	var rarity: String = normalize_rarity(hero_data.get("rarity", "N"))
	var slots: Dictionary = get_skill_slot_rules(rarity)
	var is_named_hero: bool = bool(hero_data.get("is_named", false))
	var raw_src: String = str(hero_data.get("named_source", "")).strip_edges().to_upper()
	var named_source: String = "NONE"
	if is_named_hero:
		named_source = raw_src if (raw_src == "STORY" or raw_src == "NON_STORY") else "NON_STORY"

	var raw_sub_save: String = str(hero_data.get("sub_class", hero_data.get("job_class", ""))).strip_edges()
	var raw_group_save: String = str(hero_data.get("class_group", "")).strip_edges()
	var hier_save: Dictionary = normalize_class_hierarchy(raw_group_save, raw_sub_save, str(hero_data.get("role_category", "전위")))

	var raw_fixed_save: Array[String] = []
	for ft in hero_data.get("fixed_temperaments", []):
		var fts: String = str(ft).strip_edges()
		if not fts.is_empty() and not raw_fixed_save.has(fts):
			raw_fixed_save.append(fts)
	var lock_gen_save: bool = bool(hero_data.get("lock_general_temperaments", is_named_hero or not raw_fixed_save.is_empty()))

	var payload: Dictionary = {
		"id": target_path.get_file().get_basename(),
		"name": str(hero_data.get("name", "")),
		"is_named": is_named_hero,
		"named_source": named_source,
		"named_title": str(hero_data.get("named_title", "")).strip_edges(),
		"lore": str(hero_data.get("lore", "")).strip_edges(),
		"signature_equip_id": str(hero_data.get("signature_equip_id", "")).strip_edges(),
		"fixed_temperaments": raw_fixed_save,
		"lock_general_temperaments": lock_gen_save,
		"rarity": rarity,
		"role_category": str(hier_save["role_category"]),
		"class_group": str(hier_save["class_group"]),
		"sub_class": str(hier_save["sub_class"]),
		"job_class": str(hier_save["sub_class"]),
		"element": elem_id,
		"max_hp": int(hero_data.get("max_hp", 50)),
		"atk": int(hero_data.get("atk", 15)),
		"def": int(hero_data.get("def", 10)),
		"heal_power": int(hero_data.get("heal_power", 0)),
		"speed": int(hero_data.get("speed", 10)),
		"dmg_bonus": float(hero_data.get("dmg_bonus", 0.0)),
		"crit_rate": clampf(float(hero_data.get("crit_rate", 0.05)), 0.0, 1.0),
		"crit_dmg": maxf(1.0, float(hero_data.get("crit_dmg", 1.5))),
		"armor_pen": clampf(float(hero_data.get("armor_pen", 0.0)), 0.0, 1.0),
		"final_dmg_mult": maxf(0.1, float(hero_data.get("final_dmg_mult", 1.0))),
		"offense_rank": str(hero_data.get("offense_rank", "전열")),
		"defense_zone": str(hero_data.get("defense_zone", "성벽밖")),
		"skill_id": str(hero_data.get("skill_id", "")) if slots["active1"] else "",
		"skill2_id": str(hero_data.get("skill2_id", "")) if slots["active2"] else "",
		"ultimate_id": str(hero_data.get("ultimate_id", "")) if slots["ultimate"] else "",
		"passive_skill_id": str(hero_data.get("passive_skill_id", "")).strip_edges(),
		"skill_description": str(hero_data.get("skill_description", "")),
	}

	if _write_json_file(target_path, payload):
		reload_all_data()
		return target_path
	return ""


## 정책 이벤트 데이터를 지정된 JSON 파일(없으면 새 파일 생성)로 저장합니다.
func save_event(event_data: Dictionary, existing_file_path: String = "") -> String:
	ensure_data_directories()
	var target_path: String = existing_file_path
	if target_path.is_empty():
		target_path = _generate_unique_json_path(get_events_dir_path(), "event", str(event_data.get("title", "")))

	var opt_a: Dictionary = event_data.get("option_a", {})
	var opt_b: Dictionary = event_data.get("option_b", {})
	var cat: String = str(event_data.get("event_category", "NORMAL")).strip_edges().to_upper()
	if not EVENT_CATEGORIES.has(cat):
		cat = "NORMAL"
	var min_s: int = clampi(int(event_data.get("min_stage", 1)), 1, 6)
	var max_s: int = clampi(int(event_data.get("max_stage", 6)), min_s, 6)
	var serialized_a: Dictionary = {
		"text": str(opt_a.get("text", "")),
		"deltas": _normalize_deltas(opt_a.get("deltas", {})),
	}
	var rec_a: String = str(opt_a.get("recruit_hero_id", "")).strip_edges()
	var eq_a: String = str(opt_a.get("grant_equip_id", "")).strip_edges()
	var it_a: String = str(opt_a.get("grant_item_id", "")).strip_edges()
	if not rec_a.is_empty():
		serialized_a["recruit_hero_id"] = rec_a
	if not eq_a.is_empty():
		serialized_a["grant_equip_id"] = eq_a
	if not it_a.is_empty():
		serialized_a["grant_item_id"] = it_a

	var serialized_b: Dictionary = {
		"text": str(opt_b.get("text", "")),
		"deltas": _normalize_deltas(opt_b.get("deltas", {})),
	}
	var rec_b: String = str(opt_b.get("recruit_hero_id", "")).strip_edges()
	var eq_b: String = str(opt_b.get("grant_equip_id", "")).strip_edges()
	var it_b: String = str(opt_b.get("grant_item_id", "")).strip_edges()
	if not rec_b.is_empty():
		serialized_b["recruit_hero_id"] = rec_b
	if not eq_b.is_empty():
		serialized_b["grant_equip_id"] = eq_b
	if not it_b.is_empty():
		serialized_b["grant_item_id"] = it_b

	var payload: Dictionary = {
		"id": target_path.get_file().get_basename(),
		"title": str(event_data.get("title", "")),
		"description": str(event_data.get("description", "")),
		"event_category": cat,
		"min_stage": min_s,
		"max_stage": max_s,
		"option_a": serialized_a,
		"option_b": serialized_b,
	}

	if _write_json_file(target_path, payload):
		reload_all_data()
		return target_path
	return ""


func delete_data_file(file_path: String) -> bool:
	if file_path.is_empty() or not FileAccess.file_exists(file_path):
		return false
	var err: Error = DirAccess.remove_absolute(file_path)
	if err == OK:
		reload_all_data()
		return true
	return false


func _write_json_file(file_path: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	return true


func _generate_unique_json_path(folder_path: String, prefix: String, raw_label: String) -> String:
	var slug: String = _sanitize_filename(raw_label)
	if slug.is_empty():
		slug = "%s_%d" % [prefix, Time.get_unix_time_from_system()]
	else:
		slug = "%s_%s" % [prefix, slug]

	var candidate: String = folder_path.path_join(slug + ".json")
	var suffix: int = 2
	while FileAccess.file_exists(candidate):
		candidate = folder_path.path_join("%s_%d.json" % [slug, suffix])
		suffix += 1
	return candidate


func _sanitize_filename(text: String) -> String:
	var out: String = ""
	var cleaned: String = text.strip_edges().to_lower()
	for i in range(cleaned.length()):
		var ch: String = cleaned[i]
		var code: int = ch.unicode_at(0)
		var is_ascii_alnum: bool = (code >= 48 and code <= 57) or (code >= 97 and code <= 122)
		if is_ascii_alnum:
			out += ch
		elif ch == " " or ch == "-" or ch == "_":
			if not out.ends_with("_"):
				out += "_"
	return out.strip_edges().trim_prefix("_").trim_suffix("_")


# ==========================================
# 스킬 데이터 (data/skills.json) 관리
# ==========================================
func load_skills() -> void:
	skills.clear()
	skill_map.clear()

	var path: String = get_skills_file_path()
	if not FileAccess.file_exists(path):
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("DataManager: skills.json 파싱 실패 -> %s" % path)
		return

	var data: Dictionary = parsed
	var raw_skills: Variant = data.get("skills", [])
	if typeof(raw_skills) != TYPE_ARRAY:
		return

	for raw_item in raw_skills:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var normalized := _normalize_skill(raw_item)
		skills.append(normalized)
		skill_map[normalized["id"]] = normalized


func _normalize_skill(raw: Dictionary) -> Dictionary:
	var s_id: String = str(raw.get("id", "")).strip_edges()
	if s_id.is_empty():
		s_id = "skill_%d" % Time.get_unix_time_from_system()

	var clean_effects: Array[Dictionary] = []
	var raw_effects: Variant = raw.get("effects", [])
	if typeof(raw_effects) == TYPE_ARRAY:
		for raw_eff in raw_effects:
			if typeof(raw_eff) != TYPE_DICTIONARY:
				continue
			clean_effects.append({
				"effect_type": str(raw_eff.get("effect_type", "DAMAGE")),
				"target_scope": str(raw_eff.get("target_scope", "SINGLE_FRONT")),
				"multiplier": float(raw_eff.get("multiplier", 1.0)),
				"duration": int(raw_eff.get("duration", 0)),
				"skill_bonus_crit_rate": clampf(float(raw_eff.get("skill_bonus_crit_rate", 0.0)), 0.0, 1.0),
				"skill_bonus_armor_pen": clampf(float(raw_eff.get("skill_bonus_armor_pen", 0.0)), 0.0, 1.0),
			})

	return {
		"id": s_id,
		"name": str(raw.get("name", "이름 없는 스킬")),
		"description": str(raw.get("description", "")),
		"cooldown": maxi(0, int(raw.get("cooldown", 1))),
		"effects": clean_effects,
	}


func get_skill(skill_id: String) -> Dictionary:
	return skill_map.get(skill_id, {})


func save_skill(skill_data: Dictionary, existing_skill_id: String = "") -> String:
	ensure_data_directories()
	var target_id: String = existing_skill_id.strip_edges()
	if target_id.is_empty():
		var slug: String = _sanitize_filename(str(skill_data.get("name", "")))
		target_id = "skill_" + slug if not slug.is_empty() else "skill_%d" % Time.get_unix_time_from_system()
		var suffix: int = 2
		var base_id: String = target_id
		while skill_map.has(target_id):
			target_id = "%s_%d" % [base_id, suffix]
			suffix += 1

	var clean_skill: Dictionary = _normalize_skill({
		"id": target_id,
		"name": skill_data.get("name", ""),
		"description": skill_data.get("description", ""),
		"cooldown": skill_data.get("cooldown", 1),
		"effects": skill_data.get("effects", []),
	})

	var replaced: bool = false
	for i in range(skills.size()):
		if str(skills[i].get("id", "")) == target_id:
			skills[i] = clean_skill
			replaced = true
			break
	if not replaced:
		skills.append(clean_skill)

	if _write_skills_file():
		reload_all_data()
		return target_id
	return ""


func delete_skill(skill_id: String) -> bool:
	var idx_to_remove: int = -1
	for i in range(skills.size()):
		if str(skills[i].get("id", "")) == skill_id:
			idx_to_remove = i
			break
	if idx_to_remove == -1:
		return false
	skills.remove_at(idx_to_remove)
	if _write_skills_file():
		reload_all_data()
		return true
	return false


func _write_skills_file() -> bool:
	var serialized_skills: Array = []
	for s in skills:
		serialized_skills.append({
			"id": s["id"],
			"name": s["name"],
			"description": s["description"],
			"cooldown": s["cooldown"],
			"effects": s["effects"],
		})
	var payload: Dictionary = {
		"version": 1,
		"skills": serialized_skills,
	}
	return _write_json_file(get_skills_file_path(), payload)


# ==========================================
# 모듈형 장비 데이터 (data/equipments.json) 관리
# ==========================================
func get_slot_label(slot_type: String) -> String:
	return SLOT_LABELS.get(slot_type.strip_edges().to_upper(), slot_type)


func load_equipments() -> void:
	equipments.clear()
	equipment_map.clear()

	var path: String = get_equipments_file_path()
	if not FileAccess.file_exists(path):
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("DataManager: equipments.json 파싱 실패 -> %s" % path)
		return

	var data: Dictionary = parsed
	var raw_list: Variant = data.get("equipments", [])
	if typeof(raw_list) != TYPE_ARRAY:
		return

	for raw_item in raw_list:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var normalized := _normalize_equipment(raw_item)
		equipments.append(normalized)
		equipment_map[normalized["id"]] = normalized


func _normalize_equipment(raw: Dictionary) -> Dictionary:
	var e_id: String = str(raw.get("id", "")).strip_edges()
	if e_id.is_empty():
		e_id = "eq_%d" % Time.get_unix_time_from_system()

	var slot_type: String = str(raw.get("slot_type", "WEAPON")).strip_edges().to_upper()
	if not SLOT_TYPES.has(slot_type):
		slot_type = "WEAPON"

	var clean_classes: Array[String] = []
	var raw_classes: Variant = raw.get("allowed_classes", ["ALL"])
	if typeof(raw_classes) == TYPE_ARRAY:
		for c in raw_classes:
			var cls_str: String = str(c).strip_edges()
			if not cls_str.is_empty():
				clean_classes.append(cls_str)
	if clean_classes.is_empty():
		clean_classes.append("ALL")

	var raw_stats: Variant = raw.get("stat_bonuses", {})
	var clean_stats: Dictionary = {}
	for key in EQUIP_STAT_KEYS:
		clean_stats[key] = 0.0
	if typeof(raw_stats) == TYPE_DICTIONARY:
		var s_dict: Dictionary = raw_stats
		for key in s_dict:
			clean_stats[str(key)] = float(s_dict[key])

	var exclusive_id: String = str(raw.get("exclusive_hero_id", "")).strip_edges()
	var is_named_eq: bool = bool(raw.get("is_named", not exclusive_id.is_empty()))
	var default_craftable: bool = not is_named_eq
	var craftable_flag: bool = bool(raw.get("craftable_in_blacksmith", default_craftable))

	return {
		"id": e_id,
		"name": str(raw.get("name", "이름 없는 장비")),
		"description": str(raw.get("description", "")),
		"rarity": normalize_rarity(raw.get("rarity", "N")),
		"slot_type": slot_type,
		"is_named": is_named_eq,
		"craftable_in_blacksmith": craftable_flag,
		"named_title": str(raw.get("named_title", "")).strip_edges(),
		"allowed_classes": clean_classes,
		"exclusive_hero_id": exclusive_id,
		"stat_bonuses": clean_stats,
		"passive_skill_id": str(raw.get("passive_skill_id", "")).strip_edges(),
		"resonance_skill_id": str(raw.get("resonance_skill_id", "")).strip_edges(),
		"icon_path": str(raw.get("icon_path", "")).strip_edges(),
	}


func get_hero_template(hero_id: String) -> Dictionary:
	for h in heroes:
		if str(h.get("id", "")) == hero_id:
			return h
	return {}


func get_equipment(equip_id: String) -> Dictionary:
	return equipment_map.get(equip_id, {})


func save_equipment(equip_data: Dictionary, existing_equip_id: String = "") -> String:
	ensure_data_directories()
	var target_id: String = existing_equip_id.strip_edges()
	if target_id.is_empty():
		var slug: String = _sanitize_filename(str(equip_data.get("name", "")))
		target_id = "eq_" + slug if not slug.is_empty() else "eq_%d" % Time.get_unix_time_from_system()
		var suffix: int = 2
		var base_id: String = target_id
		while equipment_map.has(target_id):
			target_id = "%s_%d" % [base_id, suffix]
			suffix += 1

	var clean_eq: Dictionary = _normalize_equipment({
		"id": target_id,
		"name": equip_data.get("name", ""),
		"description": equip_data.get("description", ""),
		"rarity": equip_data.get("rarity", "N"),
		"slot_type": equip_data.get("slot_type", "WEAPON"),
		"is_named": bool(equip_data.get("is_named", false)),
		"craftable_in_blacksmith": bool(equip_data.get("craftable_in_blacksmith", not bool(equip_data.get("is_named", false)))),
		"named_title": equip_data.get("named_title", ""),
		"allowed_classes": equip_data.get("allowed_classes", ["ALL"]),
		"exclusive_hero_id": equip_data.get("exclusive_hero_id", ""),
		"stat_bonuses": equip_data.get("stat_bonuses", {}),
		"passive_skill_id": equip_data.get("passive_skill_id", ""),
		"resonance_skill_id": equip_data.get("resonance_skill_id", ""),
	})

	var replaced: bool = false
	for i in range(equipments.size()):
		if str(equipments[i].get("id", "")) == target_id:
			equipments[i] = clean_eq
			replaced = true
			break
	if not replaced:
		equipments.append(clean_eq)

	if _write_equipments_file():
		reload_all_data()
		return target_id
	return ""


func delete_equipment(equip_id: String) -> bool:
	var idx_to_remove: int = -1
	for i in range(equipments.size()):
		if str(equipments[i].get("id", "")) == equip_id:
			idx_to_remove = i
			break
	if idx_to_remove == -1:
		return false
	equipments.remove_at(idx_to_remove)
	if _write_equipments_file():
		reload_all_data()
		return true
	return false


func _write_equipments_file() -> bool:
	var serialized: Array = []
	for eq in equipments:
		serialized.append({
			"id": eq["id"],
			"name": eq["name"],
			"description": eq["description"],
			"rarity": eq["rarity"],
			"slot_type": eq["slot_type"],
			"is_named": eq["is_named"],
			"craftable_in_blacksmith": bool(eq.get("craftable_in_blacksmith", not bool(eq.get("is_named", false)))),
			"named_title": eq["named_title"],
			"allowed_classes": eq["allowed_classes"],
			"exclusive_hero_id": eq["exclusive_hero_id"],
			"stat_bonuses": eq["stat_bonuses"],
			"passive_skill_id": eq["passive_skill_id"],
			"resonance_skill_id": eq["resonance_skill_id"],
		})
	var payload: Dictionary = {
		"version": 1,
		"equipments": serialized,
	}
	return _write_json_file(get_equipments_file_path(), payload)


# ==========================================
# 직군별 피로도 규칙 (data/classes.json)
# ==========================================
func load_classes() -> void:
	classes.clear()
	class_map.clear()
	class_groups.clear()
	class_group_map.clear()

	# 기본 8대 병과 로드
	for cg_id in CLASS_GROUPS:
		var def_g: Dictionary = (DEFAULT_CLASS_GROUP_TRAITS[cg_id] as Dictionary).duplicate(true)
		class_groups.append(def_g)
		class_group_map[cg_id] = def_g

	var path: String = get_classes_file_path()
	if not FileAccess.file_exists(path):
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var raw_groups: Variant = (parsed as Dictionary).get("class_groups", [])
	if typeof(raw_groups) == TYPE_ARRAY and not (raw_groups as Array).is_empty():
		class_groups.clear()
		class_group_map.clear()
		for g_item in (raw_groups as Array):
			if typeof(g_item) != TYPE_DICTIONARY:
				continue
			var gid: String = str((g_item as Dictionary).get("id", "")).strip_edges()
			if gid.is_empty():
				continue
			var norm_g: Dictionary = {
				"id": gid,
				"role_category": str((g_item as Dictionary).get("role_category", CLASS_GROUP_TO_CATEGORY.get(gid, "전위"))),
				"trait_id": str((g_item as Dictionary).get("trait_id", "")),
				"trait_name": str((g_item as Dictionary).get("trait_name", gid)),
				"trait_desc": str((g_item as Dictionary).get("trait_desc", "")),
			}
			class_groups.append(norm_g)
			class_group_map[gid] = norm_g

	var raw_list: Variant = (parsed as Dictionary).get("classes", [])
	if typeof(raw_list) != TYPE_ARRAY:
		return

	for item in raw_list:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var norm := _normalize_class_data(item)
		classes.append(norm)
		class_map[norm["id"]] = norm


func _normalize_class_data(raw: Dictionary) -> Dictionary:
	var cid: String = str(raw.get("id", "방패수호자")).strip_edges()
	var cg: String = str(raw.get("class_group", "")).strip_edges()
	if cg.is_empty():
		cg = get_class_group_for_sub_class(cid)
	var rcat: String = str(raw.get("role_category", CLASS_GROUP_TO_CATEGORY.get(cg, "전위"))).strip_edges()
	var fixed_t: Array[String] = []
	for ft in raw.get("fixed_temperaments", []):
		var fts: String = str(ft).strip_edges()
		if not fts.is_empty() and not fixed_t.has(fts):
			fixed_t.append(fts)
	var lock_gen: bool = bool(raw.get("lock_general_temperaments", not fixed_t.is_empty()))
	return {
		"id": cid,
		"name": str(raw.get("name", cid)),
		"class_group": cg,
		"role_category": rcat,
		"sub_trait": str(raw.get("sub_trait", "")).strip_edges(),
		"sub_trait_label": str(raw.get("sub_trait_label", "")).strip_edges(),
		"sub_trait_desc": str(raw.get("sub_trait_desc", "")).strip_edges(),
		"move_fatigue_cost": maxi(0, int(raw.get("move_fatigue_cost", 4))),
		"battle_fatigue_cost": maxi(0, int(raw.get("battle_fatigue_cost", 10))),
		"vision_bonus": maxi(0, int(raw.get("vision_bonus", 1 if cid == "척후병" else 0))),
		"danger_sense": bool(raw.get("danger_sense", cid == "척후병")),
		"fixed_temperaments": fixed_t,
		"lock_general_temperaments": lock_gen,
		"description": str(raw.get("description", "")),
	}


func get_class_fatigue_costs(job_class: String) -> Dictionary:
	var info: Dictionary = get_sub_class_info(job_class)
	if not info.is_empty() and info.has("move_fatigue_cost"):
		return {
			"move": int(info.get("move_fatigue_cost", 4)),
			"battle": int(info.get("battle_fatigue_cost", 10)),
		}
	match job_class:
		"척후병", "전술척후수":
			return {"move": 2, "battle": 7}
		"원거리딜러":
			return {"move": 3, "battle": 8}
		"탱커", "근접딜러":
			return {"move": 6, "battle": 12}
		"마법사", "힐러":
			return {"move": 5, "battle": 15}
		_:
			return {"move": 4, "battle": 11}


func save_class_data(class_data: Dictionary, existing_id: String = "") -> String:
	ensure_data_directories()
	var target_id: String = existing_id.strip_edges()
	if target_id.is_empty():
		target_id = str(class_data.get("id", "")).strip_edges()
	if target_id.is_empty():
		target_id = "class_%d" % Time.get_unix_time_from_system()

	var existing: Dictionary = class_map.get(target_id, {})
	var clean := _normalize_class_data({
		"id": target_id,
		"name": class_data.get("name", existing.get("name", target_id)),
		"class_group": class_data.get("class_group", existing.get("class_group", get_class_group_for_sub_class(target_id))),
		"role_category": class_data.get("role_category", existing.get("role_category", "전위")),
		"sub_trait": class_data.get("sub_trait", existing.get("sub_trait", "")),
		"sub_trait_label": class_data.get("sub_trait_label", existing.get("sub_trait_label", "")),
		"sub_trait_desc": class_data.get("sub_trait_desc", existing.get("sub_trait_desc", "")),
		"move_fatigue_cost": class_data.get("move_fatigue_cost", existing.get("move_fatigue_cost", 4)),
		"battle_fatigue_cost": class_data.get("battle_fatigue_cost", existing.get("battle_fatigue_cost", 10)),
		"vision_bonus": class_data.get("vision_bonus", existing.get("vision_bonus", 1 if target_id == "척후병" else 0)),
		"danger_sense": class_data.get("danger_sense", existing.get("danger_sense", target_id == "척후병")),
		"fixed_temperaments": class_data.get("fixed_temperaments", existing.get("fixed_temperaments", [])),
		"lock_general_temperaments": class_data.get("lock_general_temperaments", existing.get("lock_general_temperaments", false)),
		"description": class_data.get("description", existing.get("description", "")),
	})

	var replaced: bool = false
	for i in range(classes.size()):
		if str(classes[i].get("id", "")) == target_id:
			classes[i] = clean
			replaced = true
			break
	if not replaced:
		classes.append(clean)

	if _write_classes_file():
		reload_all_data()
		return target_id
	return ""


func _write_classes_file() -> bool:
	var serialized: Array = []
	for c in classes:
		serialized.append({
			"id": c["id"],
			"name": c["name"],
			"class_group": c.get("class_group", "근위"),
			"role_category": c.get("role_category", "전위"),
			"sub_trait": c.get("sub_trait", ""),
			"sub_trait_label": c.get("sub_trait_label", ""),
			"sub_trait_desc": c.get("sub_trait_desc", ""),
			"move_fatigue_cost": c["move_fatigue_cost"],
			"battle_fatigue_cost": c["battle_fatigue_cost"],
			"vision_bonus": int(c.get("vision_bonus", 0)),
			"danger_sense": bool(c.get("danger_sense", false)),
			"fixed_temperaments": c.get("fixed_temperaments", []),
			"lock_general_temperaments": bool(c.get("lock_general_temperaments", false)),
			"description": c["description"],
		})
	return _write_json_file(get_classes_file_path(), {"version": 2, "class_groups": class_groups, "classes": serialized})


# ==========================================
# 던전 및 드랍 테이블 (data/dungeons.json)
# ==========================================
func load_dungeons() -> void:
	dungeons.clear()
	dungeon_map.clear()

	var path: String = get_dungeons_file_path()
	if not FileAccess.file_exists(path):
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var raw_list: Variant = (parsed as Dictionary).get("dungeons", [])
	if typeof(raw_list) != TYPE_ARRAY:
		return

	for item in raw_list:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var norm := _normalize_dungeon(item)
		dungeons.append(norm)
		dungeon_map[norm["id"]] = norm


func _normalize_dungeon(raw: Dictionary) -> Dictionary:
	var d_id: String = str(raw.get("id", "")).strip_edges()
	if d_id.is_empty():
		d_id = "dun_%d" % Time.get_unix_time_from_system()
	var d_type: String = str(raw.get("dungeon_type", "FIELD_GRID")).strip_edges().to_upper()
	if not DUNGEON_TYPES.has(d_type):
		d_type = "FIELD_GRID"

	var drops: Array[String] = []
	var raw_drops: Variant = raw.get("drop_equipment_ids", [])
	if typeof(raw_drops) == TYPE_ARRAY:
		for eq_id in raw_drops:
			var s_id: String = str(eq_id).strip_edges()
			if not s_id.is_empty() and not drops.has(s_id):
				drops.append(s_id)

	return {
		"id": d_id,
		"name": str(raw.get("name", "이름 없는 던전")),
		"description": str(raw.get("description", "")),
		"dungeon_type": d_type,
		"grid_width": clampi(int(raw.get("grid_width", 19)), 5, 29),
		"grid_height": clampi(int(raw.get("grid_height", 13)), 4, 21),
		"depth": clampi(int(raw.get("depth", 5)), 3, 8),
		"drop_equipment_ids": drops,
	}


func get_dungeon(dungeon_id: String) -> Dictionary:
	return dungeon_map.get(dungeon_id, {})


func get_dungeons_by_type(dungeon_type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in dungeons:
		if str(d.get("dungeon_type", "")) == dungeon_type:
			out.append(d)
	return out


func save_dungeon(dungeon_data: Dictionary, existing_id: String = "") -> String:
	ensure_data_directories()
	var target_id: String = existing_id.strip_edges()
	if target_id.is_empty():
		var slug: String = _sanitize_filename(str(dungeon_data.get("name", "")))
		target_id = "dun_" + slug if not slug.is_empty() else "dun_%d" % Time.get_unix_time_from_system()
		var suffix: int = 2
		var base_id: String = target_id
		while dungeon_map.has(target_id):
			target_id = "%s_%d" % [base_id, suffix]
			suffix += 1

	var clean := _normalize_dungeon({
		"id": target_id,
		"name": dungeon_data.get("name", ""),
		"description": dungeon_data.get("description", ""),
		"dungeon_type": dungeon_data.get("dungeon_type", "FIELD_GRID"),
		"grid_width": dungeon_data.get("grid_width", 7),
		"grid_height": dungeon_data.get("grid_height", 5),
		"depth": dungeon_data.get("depth", 5),
		"drop_equipment_ids": dungeon_data.get("drop_equipment_ids", []),
	})

	var replaced: bool = false
	for i in range(dungeons.size()):
		if str(dungeons[i].get("id", "")) == target_id:
			dungeons[i] = clean
			replaced = true
			break
	if not replaced:
		dungeons.append(clean)

	if _write_dungeons_file():
		reload_all_data()
		return target_id
	return ""


func delete_dungeon(dungeon_id: String) -> bool:
	var idx: int = -1
	for i in range(dungeons.size()):
		if str(dungeons[i].get("id", "")) == dungeon_id:
			idx = i
			break
	if idx == -1:
		return false
	dungeons.remove_at(idx)
	if _write_dungeons_file():
		reload_all_data()
		return true
	return false


func _write_dungeons_file() -> bool:
	var serialized: Array = []
	for d in dungeons:
		serialized.append({
			"id": d["id"],
			"name": d["name"],
			"description": d["description"],
			"dungeon_type": d["dungeon_type"],
			"grid_width": d["grid_width"],
			"grid_height": d["grid_height"],
			"depth": d["depth"],
			"drop_equipment_ids": d["drop_equipment_ids"],
		})
	return _write_json_file(get_dungeons_file_path(), {"version": 1, "dungeons": serialized})


# ==========================================
# 던전 ? 돌발 이벤트 (data/dungeon_events.json)
# ==========================================
func load_dungeon_events() -> void:
	dungeon_events.clear()

	var path: String = get_dungeon_events_file_path()
	if not FileAccess.file_exists(path):
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var raw_list: Variant = (parsed as Dictionary).get("events", [])
	if typeof(raw_list) != TYPE_ARRAY:
		return

	for item in raw_list:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		dungeon_events.append(_normalize_dungeon_event(item))


func _normalize_dungeon_event(raw: Dictionary) -> Dictionary:
	var e_id: String = str(raw.get("id", "")).strip_edges()
	if e_id.is_empty():
		e_id = "dev_%d" % Time.get_unix_time_from_system()

	var clean_choices: Array[Dictionary] = []
	var raw_choices: Variant = raw.get("choices", [])
	if typeof(raw_choices) == TYPE_ARRAY:
		for ch in raw_choices:
			if typeof(ch) != TYPE_DICTIONARY:
				continue
			var c_dict: Dictionary = ch
			var cost_in: Variant = c_dict.get("cost", {})
			var clean_cost: Dictionary = {}
			if typeof(cost_in) == TYPE_DICTIONARY:
				for k in (cost_in as Dictionary):
					var v: int = int(cost_in[k])
					if v > 0:
						clean_cost[str(k)] = v

			var rew_in: Variant = c_dict.get("rewards", {})
			var rew_dict: Dictionary = rew_in if typeof(rew_in) == TYPE_DICTIONARY else {}
			var clean_rewards: Dictionary = {
				"food": int(rew_dict.get("food", 0)),
				"materials": int(rew_dict.get("materials", 0)),
				"gold": int(rew_dict.get("gold", 0)),
				"morale": int(rew_dict.get("morale", 0)),
				"wall_hp": int(rew_dict.get("wall_hp", 0)),
				"wall_atk_bonus": int(rew_dict.get("wall_atk_bonus", 0)),
				"drop_random_equip": bool(rew_dict.get("drop_random_equip", false)),
			}

			clean_choices.append({
				"text": str(c_dict.get("text", c_dict.get("label", "선택지"))),
				"cost": clean_cost,
				"rewards": clean_rewards,
				"fatigue_delta": int(c_dict.get("fatigue_delta", 0)),
				"result_text": str(c_dict.get("result_text", "")),
			})

	return {
		"id": e_id,
		"title": str(raw.get("title", "이름 없는 조우")),
		"description": str(raw.get("description", "")),
		"choices": clean_choices,
	}


func save_dungeon_event(ev_data: Dictionary, existing_id: String = "") -> String:
	ensure_data_directories()
	var target_id: String = existing_id.strip_edges()
	if target_id.is_empty():
		var slug: String = _sanitize_filename(str(ev_data.get("title", "")))
		target_id = "dev_" + slug if not slug.is_empty() else "dev_%d" % Time.get_unix_time_from_system()
		var suffix: int = 2
		var base_id: String = target_id
		var existing_ids: PackedStringArray = []
		for e in dungeon_events:
			existing_ids.append(str(e.get("id", "")))
		while existing_ids.has(target_id):
			target_id = "%s_%d" % [base_id, suffix]
			suffix += 1

	var clean := _normalize_dungeon_event({
		"id": target_id,
		"title": ev_data.get("title", ""),
		"description": ev_data.get("description", ""),
		"choices": ev_data.get("choices", []),
	})

	var replaced: bool = false
	for i in range(dungeon_events.size()):
		if str(dungeon_events[i].get("id", "")) == target_id:
			dungeon_events[i] = clean
			replaced = true
			break
	if not replaced:
		dungeon_events.append(clean)

	if _write_dungeon_events_file():
		reload_all_data()
		return target_id
	return ""


func delete_dungeon_event(event_id: String) -> bool:
	var idx: int = -1
	for i in range(dungeon_events.size()):
		if str(dungeon_events[i].get("id", "")) == event_id:
			idx = i
			break
	if idx == -1:
		return false
	dungeon_events.remove_at(idx)
	if _write_dungeon_events_file():
		reload_all_data()
		return true
	return false


func _write_dungeon_events_file() -> bool:
	var serialized: Array = []
	for e in dungeon_events:
		serialized.append({
			"id": e["id"],
			"title": e["title"],
			"description": e["description"],
			"choices": e["choices"],
		})
	return _write_json_file(get_dungeon_events_file_path(), {"version": 1, "events": serialized})


# ==========================================
# 적 유닛 데이터 (data/enemies.json)
# ==========================================
func load_enemies() -> void:
	enemies.clear()
	enemy_map.clear()

	var path: String = get_enemies_file_path()
	if not FileAccess.file_exists(path):
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var raw_list: Variant = (parsed as Dictionary).get("enemies", [])
	if typeof(raw_list) != TYPE_ARRAY:
		return

	for item in raw_list:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var norm: Dictionary = _normalize_enemy(item)
		enemies.append(norm)
		enemy_map[norm["id"]] = norm


func infer_enemy_category_from_archetype(arch: String) -> String:
	var a: String = arch.strip_edges().to_upper()
	for cat in ENEMY_CATEGORIES:
		if (ENEMY_ARCHETYPES_BY_CATEGORY[cat] as Array).has(a):
			return cat
	return "MONSTER"


func get_archetypes_for_enemy_category(cat: String) -> Array:
	var c: String = cat.strip_edges().to_upper()
	if not ENEMY_ARCHETYPES_BY_CATEGORY.has(c):
		c = "MONSTER"
	return ENEMY_ARCHETYPES_BY_CATEGORY[c]


func _normalize_enemy(raw: Dictionary) -> Dictionary:
	var e_id: String = str(raw.get("id", "")).strip_edges()
	if e_id.is_empty():
		e_id = "enemy_%d" % Time.get_unix_time_from_system()
	var e_type: String = str(raw.get("enemy_type", "NORMAL")).strip_edges().to_upper()
	if not ENEMY_TYPES.has(e_type):
		e_type = "NORMAL"

	var arch: String = str(raw.get("archetype", "")).strip_edges().to_upper()
	var cat: String = str(raw.get("category", "")).strip_edges().to_upper()
	if arch.is_empty():
		if e_type == "BOSS":
			arch = "ABYSSAL_LORD"
		elif e_type == "SIEGE":
			arch = "SIEGE_CREW"
		else:
			arch = "FOOTMAN" if cat == "HUMANOID" else "SWARMER"
	if not ENEMY_CATEGORIES.has(cat):
		cat = infer_enemy_category_from_archetype(arch)
	elif not (ENEMY_ARCHETYPES_BY_CATEGORY[cat] as Array).has(arch):
		arch = str((ENEMY_ARCHETYPES_BY_CATEGORY[cat] as Array)[0])

	var p_skills: Array[String] = []
	for s in raw.get("passive_skill_ids", []):
		var sid: String = str(s).strip_edges()
		if not sid.is_empty():
			p_skills.append(sid)

	var a_skills: Array[String] = []
	for s in raw.get("active_skill_ids", []):
		var sid: String = str(s).strip_edges()
		if not sid.is_empty():
			a_skills.append(sid)

	var seasons_out: Array[String] = []
	for sn in raw.get("allowed_seasons", ["ALL"]):
		var sn_u: String = str(sn).strip_edges().to_upper()
		if SEASONS.has(sn_u) and not seasons_out.has(sn_u):
			seasons_out.append(sn_u)
	if seasons_out.is_empty():
		seasons_out.append("ALL")

	return {
		"id": e_id,
		"name": str(raw.get("name", "적 유닛")),
		"description": str(raw.get("description", "")),
		"category": cat,
		"archetype": arch,
		"faction_group": str(raw.get("faction_group", "BANDIT" if cat == "HUMANOID" else "MONSTER")).strip_edges().to_upper(),
		"element": str(raw.get("element", "FIRE")).strip_edges().to_upper(),
		"enemy_type": e_type,
		"max_hp": maxi(1, int(raw.get("max_hp", 50))),
		"atk": maxi(1, int(raw.get("atk", 12))),
		"def": maxi(0, int(raw.get("def", 6))),
		"speed": maxi(1, int(raw.get("speed", 12))),
		"attack_interval": maxf(0.3, float(raw.get("attack_interval", 1.0))),
		"passive_skill_ids": p_skills,
		"active_skill_ids": a_skills,
		"allowed_seasons": seasons_out,
		"sprite_path": str(raw.get("sprite_path", "")).strip_edges(),
		"tint_color": str(raw.get("tint_color", "")).strip_edges(),
		"palette_swapped": bool(raw.get("palette_swapped", false)),
	}


func get_enemy(enemy_id: String) -> Dictionary:
	return enemy_map.get(enemy_id, {})


func is_enemy_allowed_in_season(enemy: Dictionary, season_key: String) -> bool:
	var allowed: Array = enemy.get("allowed_seasons", ["ALL"])
	return allowed.has("ALL") or allowed.has(season_key.to_upper())


func get_enemies_for_season(season_key: String, enemy_type: String = "", elements_filter: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in enemies:
		if not is_enemy_allowed_in_season(e, season_key):
			continue
		if not enemy_type.is_empty() and str(e.get("enemy_type", "")) != enemy_type:
			continue
		if not elements_filter.is_empty() and not elements_filter.has(str(e.get("element", ""))):
			continue
		out.append(e)
	if out.is_empty() and not elements_filter.is_empty():
		return get_enemies_for_season(season_key, enemy_type, [])
	if out.is_empty() and not enemy_type.is_empty():
		return get_enemies_for_season(season_key, "", elements_filter)
	return out


## 상황별 세력 스폰 필터:
## - 일반 던전/위기 이전: 괴물형(MONSTER) 및 산적단(BANDIT) 주력
## - 반란 위험도 높음 또는 내정 토벌 이벤트 시: 인간형 반란군(REBEL)/교단(CULT) 세력 주력
func get_enemies_for_context(
	season_key: String,
	enemy_type: String = "",
	elements_filter: Array = [],
	prefer_rebellion_humanoid: bool = false
) -> Array[Dictionary]:
	var base_pool: Array[Dictionary] = get_enemies_for_season(season_key, enemy_type, elements_filter)
	if base_pool.is_empty():
		return base_pool

	var primary: Array[Dictionary] = []
	var secondary_bandits: Array[Dictionary] = []
	for e in base_pool:
		var cat: String = str(e.get("category", "MONSTER"))
		var fac: String = str(e.get("faction_group", "MONSTER" if cat == "MONSTER" else "BANDIT")).to_upper()
		if prefer_rebellion_humanoid:
			if cat == "HUMANOID":
				if fac == "REBEL" or fac == "CULT":
					primary.append(e)
				elif fac == "BANDIT":
					secondary_bandits.append(e)
		else:
			if cat == "MONSTER" or fac == "BANDIT":
				primary.append(e)

	if not primary.is_empty():
		return primary
	if prefer_rebellion_humanoid and not secondary_bandits.is_empty():
		return secondary_bandits
	# 속성 필터 때문에 주력 진영이 비었을 경우 속성 제한 완화 후 재시도
	if not elements_filter.is_empty():
		var relaxed: Array[Dictionary] = get_enemies_for_context(season_key, enemy_type, [], prefer_rebellion_humanoid)
		if not relaxed.is_empty():
			return relaxed
	return base_pool


func save_enemy(enemy_data: Dictionary, existing_id: String = "") -> String:
	ensure_data_directories()
	var target_id: String = existing_id.strip_edges()
	if target_id.is_empty():
		var slug: String = _sanitize_filename(str(enemy_data.get("name", "")))
		target_id = "enemy_" + slug if not slug.is_empty() else "enemy_%d" % Time.get_unix_time_from_system()
		var suffix: int = 2
		var base_id: String = target_id
		while enemy_map.has(target_id):
			target_id = "%s_%d" % [base_id, suffix]
			suffix += 1

	var clean := _normalize_enemy({
		"id": target_id,
		"name": enemy_data.get("name", ""),
		"description": enemy_data.get("description", ""),
		"category": enemy_data.get("category", ""),
		"archetype": enemy_data.get("archetype", ""),
		"faction_group": enemy_data.get("faction_group", ""),
		"element": enemy_data.get("element", "FIRE"),
		"enemy_type": enemy_data.get("enemy_type", "NORMAL"),
		"max_hp": enemy_data.get("max_hp", 50),
		"atk": enemy_data.get("atk", 12),
		"def": enemy_data.get("def", 6),
		"speed": enemy_data.get("speed", 12),
		"attack_interval": enemy_data.get("attack_interval", 1.0),
		"passive_skill_ids": enemy_data.get("passive_skill_ids", []),
		"active_skill_ids": enemy_data.get("active_skill_ids", []),
		"allowed_seasons": enemy_data.get("allowed_seasons", ["ALL"]),
		"tint_color": enemy_data.get("tint_color", ""),
		"palette_swapped": bool(enemy_data.get("palette_swapped", false)),
	})

	var replaced: bool = false
	for i in range(enemies.size()):
		if str(enemies[i].get("id", "")) == target_id:
			enemies[i] = clean
			replaced = true
			break
	if not replaced:
		enemies.append(clean)

	if _write_enemies_file():
		reload_all_data()
		return target_id
	return ""


func delete_enemy(enemy_id: String) -> bool:
	var idx: int = -1
	for i in range(enemies.size()):
		if str(enemies[i].get("id", "")) == enemy_id:
			idx = i
			break
	if idx == -1:
		return false
	enemies.remove_at(idx)
	if _write_enemies_file():
		reload_all_data()
		return true
	return false


func _write_enemies_file() -> bool:
	var serialized: Array = []
	for e in enemies:
		serialized.append({
			"id": e["id"],
			"name": e["name"],
			"description": e["description"],
			"category": e.get("category", "MONSTER"),
			"archetype": e.get("archetype", "SWARMER"),
			"faction_group": e.get("faction_group", "MONSTER"),
			"element": e["element"],
			"enemy_type": e["enemy_type"],
			"max_hp": e["max_hp"],
			"atk": e["atk"],
			"def": e["def"],
			"speed": e["speed"],
			"attack_interval": e["attack_interval"],
			"passive_skill_ids": e["passive_skill_ids"],
			"active_skill_ids": e["active_skill_ids"],
			"allowed_seasons": e["allowed_seasons"],
			"tint_color": e.get("tint_color", ""),
			"palette_swapped": bool(e.get("palette_swapped", false)),
		})
	return _write_json_file(get_enemies_file_path(), {"version": 2, "enemies": serialized})


## 기본 적 아키타입을 복제해 8속성 색상 틴트와 속성별 접두사/패시브를 자동 부여한 팔레트 스왑 변종 생성
func create_palette_swapped_enemy(base_enemy_or_id: Variant, target_element: String, save_to_pool: bool = false) -> Dictionary:
	var base_tpl: Dictionary = {}
	if typeof(base_enemy_or_id) == TYPE_STRING:
		base_tpl = get_enemy(str(base_enemy_or_id))
	elif typeof(base_enemy_or_id) == TYPE_DICTIONARY:
		base_tpl = base_enemy_or_id as Dictionary
	if base_tpl.is_empty():
		return {}

	var elem_id: String = target_element.strip_edges().to_upper()
	if not PALETTE_ELEMENT_MODS.has(elem_id):
		elem_id = "FIRE"
	var mod: Dictionary = PALETTE_ELEMENT_MODS[elem_id]
	var elem_col: Color = get_element_color(elem_id)

	var clone: Dictionary = base_tpl.duplicate(true)
	var base_id: String = str(base_tpl.get("base_enemy_id", base_tpl.get("id", "enemy")))
	var base_name: String = str(base_tpl.get("name", "적 유닛"))
	# 기존 접두사가 붙어 있으면 제거 후 새 속성 접두사 적용
	for el_k in PALETTE_ELEMENT_MODS:
		var pfx: String = str(PALETTE_ELEMENT_MODS[el_k]["prefix"]) + " "
		if base_name.begins_with(pfx):
			base_name = base_name.substr(pfx.length())
			break

	var new_id: String = "%s_%s" % [base_id, elem_id.to_lower()]
	var p_skills: Array[String] = []
	for sid in clone.get("passive_skill_ids", []):
		var s_str: String = str(sid).strip_edges()
		if not s_str.is_empty() and not s_str.begins_with("skill_palette_"):
			p_skills.append(s_str)
	var mod_skill: String = str(mod.get("skill_id", ""))
	if not mod_skill.is_empty() and not p_skills.has(mod_skill):
		p_skills.append(mod_skill)

	clone["id"] = new_id
	clone["base_enemy_id"] = base_id
	clone["name"] = "%s %s" % [str(mod["prefix"]), base_name]
	clone["element"] = elem_id
	clone["tint_color"] = elem_col.to_html(false)
	clone["palette_swapped"] = true
	clone["max_hp"] = maxi(10, roundi(float(base_tpl.get("max_hp", 50)) * float(mod["hp_mult"])))
	clone["atk"] = maxi(3, roundi(float(base_tpl.get("atk", 12)) * float(mod["atk_mult"])))
	clone["def"] = maxi(0, int(base_tpl.get("def", 6)) + int(mod["def_add"]))
	clone["speed"] = maxi(2, roundi(float(base_tpl.get("speed", 12)) * float(mod["spd_mult"])))
	clone["passive_skill_ids"] = p_skills
	var orig_desc: String = str(base_tpl.get("description", ""))
	clone["description"] = "[%s 속성 변종] %s" % [get_element_name(elem_id), orig_desc]

	var normalized: Dictionary = _normalize_enemy(clone)
	normalized["base_enemy_id"] = base_id
	if save_to_pool:
		var saved_id: String = save_enemy(normalized, new_id if enemy_map.has(new_id) else "")
		if not saved_id.is_empty():
			return get_enemy(saved_id)
	return normalized


# ==========================================
# 커스텀 타워 데이터 (data/towers.json)
# ==========================================
func load_towers() -> void:
	towers.clear()
	tower_map.clear()

	var path: String = get_towers_file_path()
	if not FileAccess.file_exists(path):
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var raw_list: Variant = (parsed as Dictionary).get("towers", [])
	if typeof(raw_list) != TYPE_ARRAY:
		return

	for item in raw_list:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var norm: Dictionary = _normalize_tower(item)
		towers.append(norm)
		tower_map[norm["id"]] = norm


func _normalize_tower(raw: Dictionary) -> Dictionary:
	var t_id: String = str(raw.get("id", "")).strip_edges()
	if t_id.is_empty():
		t_id = "tower_%d" % Time.get_unix_time_from_system()
	var scope: String = str(raw.get("target_scope", "SINGLE_FRONT")).strip_edges().to_upper()
	if not TOWER_SCOPES.has(scope):
		scope = "SINGLE_FRONT"
	var cost_in: Variant = raw.get("build_cost", {})
	var cost_dict: Dictionary = cost_in if typeof(cost_in) == TYPE_DICTIONARY else {}
	return {
		"id": t_id,
		"name": str(raw.get("name", "커스텀 타워")),
		"description": str(raw.get("description", "")),
		"element": str(raw.get("element", "FIRE")).strip_edges().to_upper(),
		"atk": maxi(1, int(raw.get("atk", 20))),
		"attack_interval": maxf(0.3, float(raw.get("attack_interval", 1.5))),
		"target_scope": scope,
		"on_hit_effect_id": str(raw.get("on_hit_effect_id", "")).strip_edges(),
		"build_cost": {
			"materials": maxi(0, int(cost_dict.get("materials", 20))),
			"gold": maxi(0, int(cost_dict.get("gold", 30))),
		},
		"sprite_path": str(raw.get("sprite_path", "")).strip_edges(),
	}


func get_tower(tower_id: String) -> Dictionary:
	return tower_map.get(tower_id, {})


func save_tower(tower_data: Dictionary, existing_id: String = "") -> String:
	ensure_data_directories()
	var target_id: String = existing_id.strip_edges()
	if target_id.is_empty():
		var slug: String = _sanitize_filename(str(tower_data.get("name", "")))
		target_id = "tower_" + slug if not slug.is_empty() else "tower_%d" % Time.get_unix_time_from_system()
		var suffix: int = 2
		var base_id: String = target_id
		while tower_map.has(target_id):
			target_id = "%s_%d" % [base_id, suffix]
			suffix += 1

	var clean := _normalize_tower({
		"id": target_id,
		"name": tower_data.get("name", ""),
		"description": tower_data.get("description", ""),
		"element": tower_data.get("element", "FIRE"),
		"atk": tower_data.get("atk", 20),
		"attack_interval": tower_data.get("attack_interval", 1.5),
		"target_scope": tower_data.get("target_scope", "SINGLE_FRONT"),
		"on_hit_effect_id": tower_data.get("on_hit_effect_id", ""),
		"build_cost": tower_data.get("build_cost", {"materials": 20, "gold": 30}),
	})

	var replaced: bool = false
	for i in range(towers.size()):
		if str(towers[i].get("id", "")) == target_id:
			towers[i] = clean
			replaced = true
			break
	if not replaced:
		towers.append(clean)

	if _write_towers_file():
		reload_all_data()
		return target_id
	return ""


func delete_tower(tower_id: String) -> bool:
	var idx: int = -1
	for i in range(towers.size()):
		if str(towers[i].get("id", "")) == tower_id:
			idx = i
			break
	if idx == -1:
		return false
	towers.remove_at(idx)
	if _write_towers_file():
		reload_all_data()
		return true
	return false


func _write_towers_file() -> bool:
	var serialized: Array = []
	for t in towers:
		serialized.append({
			"id": t["id"],
			"name": t["name"],
			"description": t["description"],
			"element": t["element"],
			"atk": t["atk"],
			"attack_interval": t["attack_interval"],
			"target_scope": t["target_scope"],
			"on_hit_effect_id": t["on_hit_effect_id"],
			"build_cost": t["build_cost"],
		})
	return _write_json_file(get_towers_file_path(), {"version": 1, "towers": serialized})


# ==========================================
# 연구소 기술 트리 (data/research.json)
# ==========================================
func get_named_source_label(source_id: String) -> String:
	return NAMED_SOURCE_LABELS.get(source_id.strip_edges().to_upper(), "비네임드 (일반)")


func load_researches() -> void:
	researches.clear()
	research_map.clear()

	var path: String = get_research_file_path()
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var raw_list: Variant = (parsed as Dictionary).get("researches", [])
	if typeof(raw_list) != TYPE_ARRAY:
		return
	for item in raw_list:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var normalized := _normalize_research(item)
		researches.append(normalized)
		research_map[normalized["id"]] = normalized


func _normalize_research(raw: Dictionary) -> Dictionary:
	var r_id: String = str(raw.get("id", "")).strip_edges()
	var cost_in: Variant = raw.get("cost", {})
	var cost_dict: Dictionary = cost_in if typeof(cost_in) == TYPE_DICTIONARY else {}
	var tower_ids: Array[String] = []
	for tid in raw.get("unlock_tower_ids", []):
		var ts: String = str(tid).strip_edges()
		if not ts.is_empty():
			tower_ids.append(ts)
	var equip_ids: Array[String] = []
	for eid in raw.get("unlock_equip_ids", []):
		var es: String = str(eid).strip_edges()
		if not es.is_empty():
			equip_ids.append(es)
	return {
		"id": r_id,
		"name": str(raw.get("name", "이름 없는 연구")),
		"description": str(raw.get("description", "")),
		"cost": {
			"gold": maxi(0, int(cost_dict.get("gold", 25))),
			"materials": maxi(0, int(cost_dict.get("materials", 15))),
		},
		"prerequisite_id": str(raw.get("prerequisite_id", "")).strip_edges(),
		"unlock_tower_ids": tower_ids,
		"unlock_equip_ids": equip_ids,
	}


func get_research(research_id: String) -> Dictionary:
	return research_map.get(research_id, {})


func get_required_research_for_tower(tower_id: String) -> String:
	for res in researches:
		if (res.get("unlock_tower_ids", []) as Array).has(tower_id):
			return str(res.get("id", ""))
	return ""


func get_required_research_for_equip(equip_id: String) -> String:
	for res in researches:
		if (res.get("unlock_equip_ids", []) as Array).has(equip_id):
			return str(res.get("id", ""))
	return ""


# ==========================================
# 소비 아이템/포션 데이터 (data/items.json)
# ==========================================
func get_item_type_label(item_type: String) -> String:
	return ITEM_TYPE_LABELS.get(item_type.strip_edges().to_upper(), item_type)


func load_items() -> void:
	items.clear()
	item_map.clear()

	var path: String = get_items_file_path()
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var raw_list: Variant = (parsed as Dictionary).get("items", [])
	if typeof(raw_list) != TYPE_ARRAY:
		return
	for raw_item in raw_list:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var norm := _normalize_item(raw_item)
		items.append(norm)
		item_map[norm["id"]] = norm


func _normalize_item(raw: Dictionary) -> Dictionary:
	var i_id: String = str(raw.get("id", "")).strip_edges()
	if i_id.is_empty():
		i_id = "item_%d" % Time.get_unix_time_from_system()
	var itype: String = str(raw.get("item_type", "HEAL_HP")).strip_edges().to_upper()
	if not ITEM_TYPES.has(itype):
		itype = "HEAL_HP"
	var scope: String = str(raw.get("target_scope", "SINGLE_ALLY")).strip_edges().to_upper()
	if not ITEM_SCOPES.has(scope):
		scope = "SINGLE_ALLY"
	var cost_in: Variant = raw.get("buy_cost", {})
	var cost_dict: Dictionary = cost_in if typeof(cost_in) == TYPE_DICTIONARY else {}
	return {
		"id": i_id,
		"name": str(raw.get("name", "이름 없는 아이템")),
		"description": str(raw.get("description", "")),
		"rarity": normalize_rarity(raw.get("rarity", "N")),
		"item_type": itype,
		"target_scope": scope,
		"power": float(raw.get("power", 30.0)),
		"duration": maxi(1, int(raw.get("duration", 1))),
		"usable_in_combat": bool(raw.get("usable_in_combat", true)),
		"usable_in_dungeon": bool(raw.get("usable_in_dungeon", false)),
		"buy_cost": {
			"gold": maxi(0, int(cost_dict.get("gold", 15))),
		},
		"icon_path": str(raw.get("icon_path", "")).strip_edges(),
	}


func get_item(item_id: String) -> Dictionary:
	return item_map.get(item_id, {})


func save_item(item_data: Dictionary, existing_id: String = "") -> String:
	ensure_data_directories()
	var target_id: String = existing_id.strip_edges()
	if target_id.is_empty():
		var slug: String = _sanitize_filename(str(item_data.get("name", "")))
		target_id = "item_" + slug if not slug.is_empty() else "item_%d" % Time.get_unix_time_from_system()
		var suffix: int = 2
		var base_id: String = target_id
		while item_map.has(target_id):
			target_id = "%s_%d" % [base_id, suffix]
			suffix += 1

	var clean := _normalize_item({
		"id": target_id,
		"name": item_data.get("name", ""),
		"description": item_data.get("description", ""),
		"rarity": item_data.get("rarity", "N"),
		"item_type": item_data.get("item_type", "HEAL_HP"),
		"target_scope": item_data.get("target_scope", "SINGLE_ALLY"),
		"power": item_data.get("power", 30.0),
		"duration": item_data.get("duration", 1),
		"usable_in_combat": bool(item_data.get("usable_in_combat", true)),
		"usable_in_dungeon": bool(item_data.get("usable_in_dungeon", false)),
		"buy_cost": item_data.get("buy_cost", {"gold": 15}),
	})

	var replaced: bool = false
	for i in range(items.size()):
		if str(items[i].get("id", "")) == target_id:
			items[i] = clean
			replaced = true
			break
	if not replaced:
		items.append(clean)

	if _write_items_file():
		reload_all_data()
		return target_id
	return ""


func delete_item(item_id: String) -> bool:
	var idx: int = -1
	for i in range(items.size()):
		if str(items[i].get("id", "")) == item_id:
			idx = i
			break
	if idx == -1:
		return false
	items.remove_at(idx)
	if _write_items_file():
		reload_all_data()
		return true
	return false


func _write_items_file() -> bool:
	var serialized: Array = []
	for it in items:
		serialized.append({
			"id": it["id"],
			"name": it["name"],
			"description": it["description"],
			"rarity": it["rarity"],
			"item_type": it["item_type"],
			"target_scope": it["target_scope"],
			"power": it["power"],
			"duration": it["duration"],
			"usable_in_combat": it["usable_in_combat"],
			"usable_in_dungeon": it["usable_in_dungeon"],
			"buy_cost": it["buy_cost"],
		})
	return _write_json_file(get_items_file_path(), {"version": 1, "items": serialized})
