extends Control
## 이중 던전 탐험 씬 (DungeonMapScene)
## 1) FIELD_GRID (대형 외곽 그리드 맵): 안개(Fog of War)를 걷어내며 1칸씩 이동
##    - 이동 1칸당 맵 위협도 증가 및 파티 영웅 직군별 이동 피로도 누적
##    - 특수 타일: OUTPOST(전초기지 - 다음 디펜스 약화), SUPPLY(보급), EVENT(?), MINI_DUNGEON_PORTAL(미니 파밍 던전 입구), EXIT(귀환)
## 2) MINI_ROGUE (분기형 미니 파밍 던전): 포탈 진입 시 4~5단계 갈림길 트리 생성
##    - 노드 타입: BATTLE, ELITE, MYSTERY(?), CAMP(식량 소모 피로 회복), TREASURE(드랍 장비 파밍), BOSS(클리어 시 외곽 귀환)

signal combat_requested(is_boss: bool, atk_bonus: int, hp_bonus: int, is_elite: bool)
signal return_to_town_requested()

@export var managed_externally: bool = false

enum ExploreMode {
	FIELD_GRID,
	MINI_ROGUE,
}

enum DungeonLayoutStyle {
	CONCENTRIC_CITADEL,
	RANDOM_CHAMBERS,
	CORRIDOR_MAZE,
}

const LAYOUT_STYLE_LABELS: Dictionary = {
	DungeonLayoutStyle.CONCENTRIC_CITADEL: "1형·동심원 성채",
	DungeonLayoutStyle.RANDOM_CHAMBERS: "2형·변칙 외곽",
	DungeonLayoutStyle.CORRIDOR_MAZE: "3형·3면봉쇄 미로",
}

enum FieldTileType {
	START,
	EMPTY,
	WALL,
	OUTPOST,
	SUPPLY,
	TREASURE,
	EVENT,
	MINI_DUNGEON_PORTAL,
	BOSS,
	EXIT,
}

enum RogueRoomType {
	START,
	BATTLE,
	ELITE,
	MYSTERY,
	CAMP,
	TREASURE,
	BOSS,
}

const FIELD_TILE_LABELS: Dictionary = {
	FieldTileType.START: "출발 거점",
	FieldTileType.EMPTY: "황무지 통로",
	FieldTileType.WALL: "바위 장벽",
	FieldTileType.OUTPOST: "전초기지",
	FieldTileType.SUPPLY: "보급 지점",
	FieldTileType.TREASURE: "보물 상자",
	FieldTileType.EVENT: "? 조우",
	FieldTileType.MINI_DUNGEON_PORTAL: "미니 던전",
	FieldTileType.BOSS: "외곽 보스방",
	FieldTileType.EXIT: "귀환 포탈",
}

const FIELD_TILE_COLORS: Dictionary = {
	FieldTileType.START: Color(0.20, 0.42, 0.48, 1.0),
	FieldTileType.EMPTY: Color(0.18, 0.21, 0.25, 1.0),
	FieldTileType.WALL: Color(0.09, 0.10, 0.12, 1.0),
	FieldTileType.OUTPOST: Color(0.65, 0.24, 0.24, 1.0),
	FieldTileType.SUPPLY: Color(0.24, 0.52, 0.34, 1.0),
	FieldTileType.TREASURE: Color(0.76, 0.56, 0.16, 1.0),
	FieldTileType.EVENT: Color(0.46, 0.34, 0.62, 1.0),
	FieldTileType.MINI_DUNGEON_PORTAL: Color(0.68, 0.44, 0.16, 1.0),
	FieldTileType.BOSS: Color(0.62, 0.18, 0.72, 1.0),
	FieldTileType.EXIT: Color(0.22, 0.54, 0.68, 1.0),
}

const ENTRY_DIR_LABELS: Dictionary = {
	"NORTH": "북쪽 관문",
	"SOUTH": "남쪽 관문",
	"WEST": "서쪽 관문",
	"EAST": "동쪽 관문",
}
const FIELD_TILE_W: int = 114
const FIELD_TILE_H: int = 78
const FIELD_TILE_SEP: int = 6
const DRAG_THRESHOLD_PX: float = 10.0

const ROGUE_ROOM_NAMES: Dictionary = {
	RogueRoomType.START: "입구",
	RogueRoomType.BATTLE: "일반 전투",
	RogueRoomType.ELITE: "정예 전투",
	RogueRoomType.MYSTERY: "? 이벤트",
	RogueRoomType.CAMP: "야영지",
	RogueRoomType.TREASURE: "보물 상자",
	RogueRoomType.BOSS: "지하 군주",
}

const ROGUE_ROOM_COLORS: Dictionary = {
	RogueRoomType.START: Color(0.18, 0.45, 0.52, 1.0),
	RogueRoomType.BATTLE: Color(0.65, 0.24, 0.24, 1.0),
	RogueRoomType.ELITE: Color(0.76, 0.32, 0.18, 1.0),
	RogueRoomType.MYSTERY: Color(0.46, 0.32, 0.62, 1.0),
	RogueRoomType.CAMP: Color(0.20, 0.54, 0.34, 1.0),
	RogueRoomType.TREASURE: Color(0.75, 0.58, 0.16, 1.0),
	RogueRoomType.BOSS: Color(0.54, 0.20, 0.68, 1.0),
}

const COLOR_FOG := Color(0.08, 0.09, 0.11, 0.95)
const COLOR_PLAYER_TILE := Color(0.24, 0.62, 0.80, 1.0)
const COLOR_CLEARED_TILE := Color(0.16, 0.22, 0.20, 0.92)
const COLOR_NODE_LOCKED := Color(0.20, 0.21, 0.25, 0.85)
const COLOR_NODE_CLEARED := Color(0.16, 0.24, 0.20, 0.85)
const COLOR_NODE_CURRENT := Color(0.24, 0.58, 0.72, 1.0)
const COLOR_LINE_DEFAULT := Color(0.35, 0.38, 0.45, 0.8)
const COLOR_LINE_AVAILABLE := Color(0.95, 0.80, 0.30, 1.0)
const COLOR_LINE_TRAVELED := Color(0.35, 0.85, 0.55, 0.95)
const NODE_SIZE := Vector2(198, 96)
const CALENDAR_SCENE: PackedScene = preload("res://scenes/ui/CalendarOverlay.tscn")

@onready var map_root: Control = %MapRoot
@onready var title_label: Label = %TitleLabel
@onready var mode_badge_label: Label = %ModeBadgeLabel
@onready var threat_label: Label = %ThreatLabel
@onready var buff_label: Label = %BuffLabel
@onready var status_label: Label = %StatusLabel
@onready var dungeon_bag_button: Button = %DungeonBagButton
@onready var calendar_button: Button = %CalendarButton
@onready var center_camera_button: Button = %CenterCameraButton
@onready var regenerate_button: Button = %RegenerateButton
@onready var return_button: Button = %ReturnButton

@onready var map_canvas: Control = %MapCanvas
@onready var field_pan_container: Control = %FieldPanContainer
@onready var field_grid: GridContainer = %FieldGrid
@onready var rogue_layer: Control = %RogueLayer
@onready var lines_layer: Control = %LinesLayer
@onready var nodes_layer: Control = %NodesLayer
@onready var party_status_hbox: HBoxContainer = %PartyStatusHBox

@onready var bag_overlay: ColorRect = %BagOverlay
@onready var bag_hero_hbox: HBoxContainer = %BagHeroHBox
@onready var bag_items_vbox: VBoxContainer = %BagItemsVBox
@onready var bag_status_label: Label = %BagStatusLabel
@onready var bag_close_button: Button = %BagCloseButton

@onready var event_overlay: ColorRect = %EventOverlay
@onready var event_title_label: Label = %EventTitleLabel
@onready var event_desc_label: Label = %EventDescLabel
@onready var event_choices_vbox: VBoxContainer = %EventChoicesVBox
@onready var event_confirm_button: Button = %EventConfirmButton

@onready var offense_scene: Control = %OffenseScene

var _mode: ExploreMode = ExploreMode.FIELD_GRID
var _active_field_dungeon: Dictionary = {}
var _active_mini_dungeon: Dictionary = {}

# FIELD_GRID 상태
var _grid_width: int = 19
var _grid_height: int = 13
var _layout_style: DungeonLayoutStyle = DungeonLayoutStyle.CONCENTRIC_CITADEL
var _entry_direction: String = "WEST"
var _field_tiles: Dictionary = {} # Vector2i -> Dictionary
var _field_buttons: Dictionary = {} # Vector2i -> Button
var _player_pos: Vector2i = Vector2i(0, 6)
var _active_portal_pos: Vector2i = Vector2i(-1, -1)
var _threat_level: int = 0

# 터치·마우스 드래그 패닝 상태
var _is_dragging: bool = false
var _drag_moved: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_start_grid_pos: Vector2 = Vector2.ZERO
var _suppress_tile_click: bool = false
var _bag_target_hero_uid: int = -1
var _calendar_modal: Control = null

# MINI_ROGUE 상태
var _rogue_nodes: Array[Dictionary] = []
var _rogue_node_views: Dictionary = {}
var _rogue_edges: Array[Dictionary] = []
var _rogue_current_id: int = 0
var _rogue_cleared_ids: Array[int] = []
var _rogue_traveled_edges: Array[Vector2i] = []

# 공용 런 상태
var _awaiting_modal: bool = false
var _run_atk_bonus: int = 0
var _run_hp_bonus: int = 0
var _pending_combat_context: String = "" # "OUTPOST", "ROGUE_BATTLE", "ROGUE_ELITE", "ROGUE_BOSS"


func _ready() -> void:
	GlobalData.phase_changed.connect(_on_phase_changed)
	GlobalData.roster_changed.connect(_on_state_updated)
	GlobalData.resources_changed.connect(_on_state_updated)
	GlobalData.party_presets_changed.connect(_on_state_updated)
	DataManager.data_reloaded.connect(_on_data_reloaded)

	dungeon_bag_button.pressed.connect(_open_bag_overlay)
	calendar_button.pressed.connect(_on_calendar_button_pressed)
	center_camera_button.pressed.connect(_center_camera_on_player)
	_calendar_modal = CALENDAR_SCENE.instantiate()
	add_child(_calendar_modal)
	bag_close_button.pressed.connect(_close_bag_overlay)
	regenerate_button.pressed.connect(func() -> void: generate_new_map(true))
	return_button.pressed.connect(_on_return_button_pressed)
	event_confirm_button.pressed.connect(_close_modal)
	map_canvas.resized.connect(_layout_rogue_elements)
	field_pan_container.resized.connect(_on_pan_container_resized)
	offense_scene.map_return_requested.connect(_on_offense_return_requested)
	bag_overlay.visible = false

	generate_new_map(false)


func _on_phase_changed(new_phase: GlobalData.GamePhase) -> void:
	if new_phase == GlobalData.GamePhase.DUNGEON:
		generate_new_map(false)


func _on_data_reloaded() -> void:
	if GlobalData.current_phase == GlobalData.GamePhase.DUNGEON:
		_refresh_all_ui()


func _on_state_updated(_arg = null) -> void:
	if is_node_ready():
		_refresh_party_hud()
		_refresh_header_labels()


func _on_return_button_pressed() -> void:
	if _awaiting_modal:
		return
	if _mode == ExploreMode.MINI_ROGUE:
		_show_choice_modal(
			"미니 던전 철수",
			"현재 미니 파밍 던전을 중단하고 어떻게 하시겠습니까?",
			[
				{"label": "외곽 그리드 지도로 후퇴", "action": _on_retreat_to_field_grid},
				{"label": "마을(정산)로 완전히 귀환", "action": _on_confirm_return_to_town},
				{"label": "탐험 계속", "action": _close_modal},
			]
		)
		return
	_finish_dungeon_expedition()


func _on_retreat_to_field_grid() -> void:
	_mode = ExploreMode.FIELD_GRID
	_close_modal()
	_set_status("외곽 그리드로 철수했습니다.")
	_refresh_all_ui()


func _on_confirm_return_to_town() -> void:
	_close_modal()
	_finish_dungeon_expedition()


func _finish_dungeon_expedition() -> void:
	if managed_externally:
		return_to_town_requested.emit()
	elif GlobalData.current_phase == GlobalData.GamePhase.DUNGEON:
		TimeManager.advance_phase()


# ==========================================
# 맵 생성 / 복원 (FIELD_GRID 디펜스 주기 유지)
# ==========================================
func generate_new_map(force_regenerate: bool = false) -> void:
	_mode = ExploreMode.FIELD_GRID
	_awaiting_modal = false
	_pending_combat_context = ""
	_active_portal_pos = Vector2i(-1, -1)
	event_overlay.visible = false
	bag_overlay.visible = false
	offense_scene.visible = false
	map_root.visible = true

	if force_regenerate:
		GlobalData.clear_field_dungeon_state()

	if not GlobalData.field_dungeon_state.is_empty() and _restore_field_state_from_global():
		_set_status("이전 평일 던전 탐사(%s 진입) 이어서 진행! (드래그로 지도 탐색 가능)" % ENTRY_DIR_LABELS.get(_entry_direction, _entry_direction))
		_refresh_all_ui()
		call_deferred("_center_camera_on_player")
		return

	_run_atk_bonus = 0
	_run_hp_bonus = 0
	_threat_level = 0

	var field_pool: Array[Dictionary] = DataManager.get_dungeons_by_type("FIELD_GRID")
	if not field_pool.is_empty():
		_active_field_dungeon = field_pool[randi() % field_pool.size()]
	else:
		_active_field_dungeon = {
			"id": "dun_outer_wasteland",
			"name": "외곽 황무지 경계선",
			"grid_width": 19,
			"grid_height": 13,
			"drop_equipment_ids": ["eq_iron_sword", "eq_leather_armor", "eq_swift_charm", "eq_hunter_bow"],
		}

	var mini_pool: Array[Dictionary] = DataManager.get_dungeons_by_type("MINI_ROGUE")
	if not mini_pool.is_empty():
		_active_mini_dungeon = mini_pool[randi() % mini_pool.size()]
	else:
		_active_mini_dungeon = {
			"id": "dun_crimson_crypt",
			"name": "붉은 지하묘지",
			"depth": 5,
			"drop_equipment_ids": ["eq_hunter_bow", "eq_steel_bulwark"],
		}

	_build_field_grid()
	_save_field_state_to_global()
	var style_name: String = str(LAYOUT_STYLE_LABELS.get(_layout_style, "미궁"))
	_set_status("[%s · %s] %dx%d 대규모 외곽 미궁 진입 완료! 드래그로 맵을 살피며 보스가 지키는 귀환 포탈로 돌파하세요." % [
		style_name,
		ENTRY_DIR_LABELS.get(_entry_direction, _entry_direction),
		_grid_width,
		_grid_height,
	])
	_refresh_all_ui()
	call_deferred("_center_camera_on_player")


func _build_field_grid() -> void:
	_grid_width = clampi(int(_active_field_dungeon.get("grid_width", 19)), 5, 29)
	_grid_height = clampi(int(_active_field_dungeon.get("grid_height", 13)), 4, 21)
	_field_tiles.clear()
	_field_buttons.clear()

	# 매 던전 생성 시 3가지 구조(동심원 성채 / 변칙 외곽 / 3면 봉쇄 미로) 중 무작위 선택
	var styles_all: Array[DungeonLayoutStyle] = [
		DungeonLayoutStyle.CONCENTRIC_CITADEL,
		DungeonLayoutStyle.RANDOM_CHAMBERS,
		DungeonLayoutStyle.CORRIDOR_MAZE,
	]
	_layout_style = styles_all[randi() % styles_all.size()]

	# 동·서·남·북 4방향 중 무작위 진입 루트 선택
	var dirs_all: Array[String] = ["NORTH", "SOUTH", "WEST", "EAST"]
	_entry_direction = dirs_all[randi() % dirs_all.size()]
	var start_pos: Vector2i = _pick_perimeter_start_pos(_entry_direction)
	_player_pos = start_pos

	# 현재 계절에 출현 가능한 적 속성 추출 -> 다음 디펜스 웨이브 예상 속성 동기화
	var season_key: String = TimeManager.get_season_key()
	var season_enemies: Array[Dictionary] = DataManager.get_enemies_for_season(season_key)
	var elem_pool: Array[String] = []
	for e in season_enemies:
		var el: String = str(e.get("element", "")).strip_edges().to_upper()
		if not el.is_empty() and not elem_pool.has(el):
			elem_pool.append(el)
	if elem_pool.is_empty():
		elem_pool = ["FIRE", "EARTH"]
	elem_pool.shuffle()
	var dominant_elems: Array[String] = []
	for i in range(mini(2, elem_pool.size())):
		dominant_elems.append(elem_pool[i])
	GlobalData.set_upcoming_defense_elements(dominant_elems)

	for y in range(_grid_height):
		for x in range(_grid_width):
			var pos := Vector2i(x, y)
			_field_tiles[pos] = {
				"pos": pos,
				"type": FieldTileType.WALL,
				"revealed": false,
				"cleared": false,
				"visited": false,
				"boss_defeated": false,
				"locked_wall": false,
				"element": dominant_elems[randi() % dominant_elems.size()],
			}

	var gen_info: Dictionary = {}
	match _layout_style:
		DungeonLayoutStyle.CONCENTRIC_CITADEL:
			gen_info = _generate_concentric_citadel_layout(start_pos)
		DungeonLayoutStyle.RANDOM_CHAMBERS:
			gen_info = _generate_random_chambers_layout(start_pos)
		DungeonLayoutStyle.CORRIDOR_MAZE:
			gen_info = _generate_corridor_maze_layout(start_pos)

	var exit_pos: Vector2i = gen_info.get("exit_pos", Vector2i(_grid_width - 1, int(_grid_height / 2)))
	var approach_pos: Vector2i = gen_info.get("approach_pos", exit_pos)

	# 시작점 및 보스 수호 귀환 포탈 고정 배치 (보스는 무조건 귀환 포탈 방에 배치!)
	_field_tiles[start_pos]["type"] = FieldTileType.START
	_field_tiles[start_pos]["cleared"] = true
	_field_tiles[start_pos]["visited"] = true
	_field_tiles[start_pos]["locked_wall"] = false
	_field_tiles[exit_pos]["type"] = FieldTileType.EXIT
	_field_tiles[exit_pos]["boss_defeated"] = false
	_field_tiles[exit_pos]["cleared"] = false
	_field_tiles[exit_pos]["locked_wall"] = false

	_ensure_path_bfs(start_pos, approach_pos)
	_ensure_path_bfs(start_pos, exit_pos)

	# BFS로 도달 가능한 EMPTY 타일만 수집해 특수 노드(전초기지/보물상자/보급/이벤트/미니던전) 배치
	var visited_map: Dictionary = _run_bfs_from(start_pos)
	var candidates: Array[Vector2i] = []
	for k in visited_map:
		var p: Vector2i = k
		if p != start_pos and p != exit_pos and int(_field_tiles[p]["type"]) == FieldTileType.EMPTY:
			candidates.append(p)
	candidates.shuffle()

	var scale_factor: float = maxf(1.0, float(_grid_width * _grid_height) / 90.0)
	var assign_plan: Array[Dictionary] = [
		{"type": FieldTileType.MINI_DUNGEON_PORTAL, "count": clampi(roundi(2.0 * scale_factor), 2, 5)},
		{"type": FieldTileType.TREASURE, "count": clampi(roundi(3.5 * scale_factor), 4, 8)},
		{"type": FieldTileType.OUTPOST, "count": clampi(roundi(3.0 * scale_factor), 4, 7)},
		{"type": FieldTileType.SUPPLY, "count": clampi(roundi(3.0 * scale_factor), 4, 7)},
		{"type": FieldTileType.EVENT, "count": clampi(roundi(3.0 * scale_factor), 3, 7)},
	]
	for entry in assign_plan:
		var t_type: FieldTileType = entry["type"]
		var cnt: int = int(entry["count"])
		for _i in range(cnt):
			if candidates.is_empty():
				break
			var p: Vector2i = candidates.pop_back()
			_field_tiles[p]["type"] = t_type

	_reveal_around(_player_pos)
	_create_field_grid_buttons()


func _pick_perimeter_start_pos(dir_key: String) -> Vector2i:
	match dir_key:
		"NORTH":
			return Vector2i(randi_range(1, maxi(1, _grid_width - 2)), 0)
		"SOUTH":
			return Vector2i(randi_range(1, maxi(1, _grid_width - 2)), _grid_height - 1)
		"EAST":
			return Vector2i(_grid_width - 1, randi_range(1, maxi(1, _grid_height - 2)))
		_:
			return Vector2i(0, randi_range(1, maxi(1, _grid_height - 2)))


## 1형: 중앙에 출구(보스·귀환포탈)가 있고 성벽 고리가 층층이 중심을 감싸는 구조
func _generate_concentric_citadel_layout(start_pos: Vector2i) -> Dictionary:
	_carve_empty_rect(0, 0, _grid_width, _grid_height)
	var center := Vector2i(int(_grid_width / 2), int(_grid_height / 2))

	# 외곽에서 중심으로 들어가는 동심원 성벽 고리(margin = 2, 4, 6...) 생성
	var max_margin: int = int(mini(_grid_width, _grid_height) / 2) - 1
	var margin: int = 2
	var gate_side_idx: int = randi() % 4
	while margin <= max_margin:
		var left: int = margin
		var right: int = _grid_width - 1 - margin
		var top: int = margin
		var bottom: int = _grid_height - 1 - margin
		if right - left < 2 or bottom - top < 2:
			break

		for x in range(left, right + 1):
			_set_tile_type_if_valid(Vector2i(x, top), FieldTileType.WALL)
			_set_tile_type_if_valid(Vector2i(x, bottom), FieldTileType.WALL)
		for y in range(top, bottom + 1):
			_set_tile_type_if_valid(Vector2i(left, y), FieldTileType.WALL)
			_set_tile_type_if_valid(Vector2i(right, y), FieldTileType.WALL)

		# 층마다 다른 방향(어긋난 성문 2곳)에 2칸 폭 관문 개방
		for g in range(2):
			var side: int = (gate_side_idx + g * 2) % 4
			match side:
				0: # 북측 성문
					var gx: int = randi_range(left + 1, maxi(left + 1, right - 1))
					_set_tile_type_if_valid(Vector2i(gx, top), FieldTileType.EMPTY)
					if gx + 1 < right:
						_set_tile_type_if_valid(Vector2i(gx + 1, top), FieldTileType.EMPTY)
				1: # 동측 성문
					var gy: int = randi_range(top + 1, maxi(top + 1, bottom - 1))
					_set_tile_type_if_valid(Vector2i(right, gy), FieldTileType.EMPTY)
					if gy + 1 < bottom:
						_set_tile_type_if_valid(Vector2i(right, gy + 1), FieldTileType.EMPTY)
				2: # 남측 성문
					var gx: int = randi_range(left + 1, maxi(left + 1, right - 1))
					_set_tile_type_if_valid(Vector2i(gx, bottom), FieldTileType.EMPTY)
					if gx + 1 < right:
						_set_tile_type_if_valid(Vector2i(gx + 1, bottom), FieldTileType.EMPTY)
				3: # 서측 성문
					var gy: int = randi_range(top + 1, maxi(top + 1, bottom - 1))
					_set_tile_type_if_valid(Vector2i(left, gy), FieldTileType.EMPTY)
					if gy + 1 < bottom:
						_set_tile_type_if_valid(Vector2i(left, gy + 1), FieldTileType.EMPTY)
		gate_side_idx = (gate_side_idx + 1 + (randi() % 2)) % 4
		margin += 2

	# 중앙 성소(3x3) 확보 및 링 사이 무작위 돌출 암벽 추가
	_carve_empty_rect(maxi(0, center.x - 1), maxi(0, center.y - 1), 3, 3)
	for _s in range(10):
		var sp := Vector2i(randi_range(1, _grid_width - 2), randi_range(1, _grid_height - 2))
		if sp.distance_to(start_pos) > 2.2 and sp.distance_to(center) > 2.2 and int(_field_tiles[sp]["type"]) == FieldTileType.EMPTY:
			if randf() < 0.45:
				_field_tiles[sp]["type"] = FieldTileType.WALL

	_carve_empty_rect(maxi(0, start_pos.x - 1), maxi(0, start_pos.y - 1), 2, 2)
	return {"exit_pos": center, "approach_pos": center}


## 2형: 방/통로 기반이지만 출구가 고정 반대편이 아닌 다른 외곽 벽면 중 무작위 위치에 배치
func _generate_random_chambers_layout(start_pos: Vector2i) -> Dictionary:
	var perimeter_pool: Array[Vector2i] = []
	var min_dist: int = int(round(float(_grid_width + _grid_height) * 0.48))
	for x in range(_grid_width):
		for y in [0, _grid_height - 1]:
			var p := Vector2i(x, y)
			if not _is_same_entry_edge(p, _entry_direction) and (absi(p.x - start_pos.x) + absi(p.y - start_pos.y)) >= min_dist:
				perimeter_pool.append(p)
	for y in range(1, _grid_height - 1):
		for x in [0, _grid_width - 1]:
			var p := Vector2i(x, y)
			if not _is_same_entry_edge(p, _entry_direction) and (absi(p.x - start_pos.x) + absi(p.y - start_pos.y)) >= min_dist:
				perimeter_pool.append(p)
	var exit_pos: Vector2i = perimeter_pool[randi() % perimeter_pool.size()] if not perimeter_pool.is_empty() else Vector2i(_grid_width - 1 - start_pos.x, _grid_height - 1 - start_pos.y)

	var room_centers: Array[Vector2i] = []
	var room_count: int = clampi(int(round(float(_grid_width * _grid_height) / 22.0)), 6, 11)
	for _r in range(room_count):
		var rw: int = randi_range(2, mini(4, maxi(2, _grid_width - 2)))
		var rh: int = randi_range(2, mini(3, maxi(2, _grid_height - 2)))
		var rx: int = randi_range(1, maxi(1, _grid_width - rw - 1))
		var ry: int = randi_range(1, maxi(1, _grid_height - rh - 1))
		_carve_empty_rect(rx, ry, rw, rh)
		room_centers.append(Vector2i(rx + int(rw / 2), ry + int(rh / 2)))

	_carve_empty_rect(maxi(0, start_pos.x - 1), maxi(0, start_pos.y - 1), 2, 2)
	_carve_empty_rect(maxi(0, exit_pos.x - 1), maxi(0, exit_pos.y - 1), 2, 2)

	var prev_pt: Vector2i = start_pos
	for rc in room_centers:
		_carve_winding_corridor(prev_pt, rc)
		if randf() < 0.72:
			prev_pt = rc
	_carve_winding_corridor(prev_pt, exit_pos)

	if room_centers.size() >= 2:
		for _b in range(mini(4, room_centers.size())):
			var ra: Vector2i = room_centers[randi() % room_centers.size()]
			var rb: Vector2i = room_centers[randi() % room_centers.size()]
			if ra != rb:
				_carve_winding_corridor(ra, rb)

	for rc in room_centers:
		if rc != start_pos and rc != exit_pos and randf() < 0.35:
			_field_tiles[rc]["type"] = FieldTileType.WALL
	for rc in room_centers:
		if int(_field_tiles[rc]["type"]) != FieldTileType.WALL:
			_ensure_path_bfs(start_pos, rc)

	return {"exit_pos": exit_pos, "approach_pos": exit_pos}


func _is_same_entry_edge(p: Vector2i, dir_key: String) -> bool:
	match dir_key:
		"NORTH":
			return p.y == 0
		"SOUTH":
			return p.y == _grid_height - 1
		"WEST":
			return p.x == 0
		"EAST":
			return p.x == _grid_width - 1
	return false


## 3형: 랜덤 위치 출구 + 출구 주변 3면 무조건 WALL 봉쇄(1방향 진입 통로) + 빈공간이 많은 미로 구조
func _generate_corridor_maze_layout(start_pos: Vector2i) -> Dictionary:
	var min_dist: int = int(round(float(_grid_width + _grid_height) * 0.42))
	var exit_candidates: Array[Vector2i] = []
	for y in range(2, maxi(3, _grid_height - 2)):
		for x in range(2, maxi(3, _grid_width - 2)):
			var p := Vector2i(x, y)
			if absi(p.x - start_pos.x) + absi(p.y - start_pos.y) >= min_dist:
				exit_candidates.append(p)
	var exit_pos: Vector2i = exit_candidates[randi() % exit_candidates.size()] if not exit_candidates.is_empty() else Vector2i(int(_grid_width / 2), int(_grid_height / 2))

	# 출구 4방 중 1개만 통로 입구(approach_pos)로 열고 나머지 3면은 locked_wall = true 로 무조건 봉쇄!
	var cardinals: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	cardinals.shuffle()
	var approach_dir: Vector2i = cardinals[0]
	var approach_pos: Vector2i = exit_pos + approach_dir
	_field_tiles[exit_pos]["type"] = FieldTileType.EMPTY
	_field_tiles[approach_pos]["type"] = FieldTileType.EMPTY

	for i in range(1, cardinals.size()):
		var wall_p: Vector2i = exit_pos + cardinals[i]
		if _field_tiles.has(wall_p):
			_field_tiles[wall_p]["type"] = FieldTileType.WALL
			_field_tiles[wall_p]["locked_wall"] = true

	# DFS 재귀 백트래킹 미로 생성 (step 2 격자)
	var maze_visited: Dictionary = {}
	var stack: Array[Vector2i] = [approach_pos]
	maze_visited[approach_pos] = true
	var step_dirs: Array[Vector2i] = [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]
	while not stack.is_empty():
		var cur: Vector2i = stack[stack.size() - 1]
		var shuffled_dirs: Array[Vector2i] = step_dirs.duplicate()
		shuffled_dirs.shuffle()
		var carved: bool = false
		for sd in shuffled_dirs:
			var nxt: Vector2i = cur + sd
			if nxt.x < 0 or nxt.x >= _grid_width or nxt.y < 0 or nxt.y >= _grid_height:
				continue
			if maze_visited.has(nxt) or nxt == exit_pos:
				continue
			var mid := Vector2i(cur.x + int(sd.x / 2), cur.y + int(sd.y / 2))
			if bool(_field_tiles[nxt].get("locked_wall", false)) or bool(_field_tiles[mid].get("locked_wall", false)):
				continue
			_field_tiles[mid]["type"] = FieldTileType.EMPTY
			_field_tiles[nxt]["type"] = FieldTileType.EMPTY
			maze_visited[nxt] = true
			stack.append(nxt)
			carved = true
			break
		if not carved:
			stack.pop_back()

	# 미로 속에 빈공간(넓은 공터/방)을 여러 곳 열어 미로+오픈 공간 혼합 지형 형성 (locked_wall 제외)
	var clearing_cnt: int = clampi(int(round(float(_grid_width * _grid_height) / 28.0)), 4, 8)
	for _c in range(clearing_cnt):
		var cw: int = randi_range(2, 3)
		var ch: int = randi_range(2, 3)
		var cx: int = randi_range(1, maxi(1, _grid_width - cw - 1))
		var cy: int = randi_range(1, maxi(1, _grid_height - ch - 1))
		_carve_empty_rect(cx, cy, cw, ch)

	# 미로 내 남은 일반 WALL 중 일부 추가 개방해 빈공간 비중을 늘리고 루프 통로 생성
	for pos in _field_tiles:
		var t: Dictionary = _field_tiles[pos]
		if bool(t.get("locked_wall", false)) or pos == exit_pos:
			continue
		if int(t["type"]) == FieldTileType.WALL and randf() < 0.28:
			t["type"] = FieldTileType.EMPTY

	_carve_empty_rect(maxi(0, start_pos.x - 1), maxi(0, start_pos.y - 1), 2, 2)
	return {"exit_pos": exit_pos, "approach_pos": approach_pos}


func _set_tile_type_if_valid(pos: Vector2i, t_type: FieldTileType) -> void:
	if _field_tiles.has(pos) and not bool(_field_tiles[pos].get("locked_wall", false)):
		_field_tiles[pos]["type"] = t_type


func _carve_empty_rect(rx: int, ry: int, rw: int, rh: int) -> void:
	for y in range(ry, ry + rh):
		for x in range(rx, rx + rw):
			var p := Vector2i(x, y)
			_set_tile_type_if_valid(p, FieldTileType.EMPTY)


func _carve_winding_corridor(from_pos: Vector2i, to_pos: Vector2i) -> void:
	var cur: Vector2i = from_pos
	var safety: int = _grid_width * _grid_height
	while cur != to_pos and safety > 0:
		safety -= 1
		_set_tile_type_if_valid(cur, FieldTileType.EMPTY)
		var move_x: bool = (cur.x != to_pos.x)
		var move_y: bool = (cur.y != to_pos.y)
		if move_x and move_y:
			if randf() < 0.5:
				cur.x += 1 if to_pos.x > cur.x else -1
			else:
				cur.y += 1 if to_pos.y > cur.y else -1
		elif move_x:
			cur.x += 1 if to_pos.x > cur.x else -1
		elif move_y:
			cur.y += 1 if to_pos.y > cur.y else -1
		_set_tile_type_if_valid(cur, FieldTileType.EMPTY)


func _ensure_path_bfs(start_pos: Vector2i, target_pos: Vector2i) -> void:
	for _attempt in range(16):
		var visited: Dictionary = _run_bfs_from(start_pos)
		if visited.has(target_pos):
			return

		# 도달 불가 시, 목표와 가장 가까운 방문 타일에서 직교 연결 (locked_wall 제외)
		var best_node: Vector2i = start_pos
		var best_dist: int = 999999
		for k in visited:
			var p: Vector2i = k
			var d: int = absi(p.x - target_pos.x) + absi(p.y - target_pos.y)
			if d < best_dist:
				best_dist = d
				best_node = p

		var cur: Vector2i = best_node
		while cur != target_pos:
			var step := Vector2i.ZERO
			if cur.x != target_pos.x:
				step.x = 1 if target_pos.x > cur.x else -1
			elif cur.y != target_pos.y:
				step.y = 1 if target_pos.y > cur.y else -1
			var nxt: Vector2i = cur + step
			if _field_tiles.has(nxt) and bool(_field_tiles[nxt].get("locked_wall", false)):
				var alt := Vector2i(0, 1 if target_pos.y >= cur.y else -1) if step.x != 0 else Vector2i(1 if target_pos.x >= cur.x else -1, 0)
				nxt = cur + alt
				if not _field_tiles.has(nxt) or bool(_field_tiles[nxt].get("locked_wall", false)):
					break
			cur = nxt
			_set_tile_type_if_valid(cur, FieldTileType.EMPTY)


func _run_bfs_from(start_pos: Vector2i) -> Dictionary:
	var visited: Dictionary = {start_pos: true}
	var queue: Array[Vector2i] = [start_pos]
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in dirs:
			var nxt: Vector2i = cur + d
			if visited.has(nxt) or not _field_tiles.has(nxt):
				continue
			if int(_field_tiles[nxt]["type"]) == FieldTileType.WALL:
				continue
			visited[nxt] = true
			queue.append(nxt)
	return visited


func _create_field_grid_buttons() -> void:
	for child in field_grid.get_children():
		child.queue_free()
	_field_buttons.clear()
	field_grid.columns = _grid_width

	for y in range(_grid_height):
		for x in range(_grid_width):
			var pos := Vector2i(x, y)
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(FIELD_TILE_W, FIELD_TILE_H)
			btn.add_theme_font_size_override("font_size", 12)
			btn.clip_text = true
			btn.mouse_filter = Control.MOUSE_FILTER_PASS
			btn.pressed.connect(_on_field_tile_pressed.bind(pos))
			field_grid.add_child(btn)
			_field_buttons[pos] = btn

	var total_w: float = float(_grid_width * FIELD_TILE_W + maxi(0, _grid_width - 1) * FIELD_TILE_SEP)
	var total_h: float = float(_grid_height * FIELD_TILE_H + maxi(0, _grid_height - 1) * FIELD_TILE_SEP)
	field_grid.size = Vector2(total_w, total_h)


func _save_field_state_to_global() -> void:
	var tiles_arr: Array = []
	for pos in _field_tiles:
		var t: Dictionary = _field_tiles[pos]
		tiles_arr.append({
			"x": pos.x,
			"y": pos.y,
			"type": int(t["type"]),
			"revealed": bool(t["revealed"]),
			"cleared": bool(t["cleared"]),
			"visited": bool(t["visited"]),
			"boss_defeated": bool(t.get("boss_defeated", false)),
			"locked_wall": bool(t.get("locked_wall", false)),
			"element": str(t.get("element", "FIRE")),
		})
	GlobalData.set_field_dungeon_state({
		"grid_width": _grid_width,
		"grid_height": _grid_height,
		"layout_style": int(_layout_style),
		"entry_direction": _entry_direction,
		"player_x": _player_pos.x,
		"player_y": _player_pos.y,
		"threat_level": _threat_level,
		"run_atk_bonus": _run_atk_bonus,
		"run_hp_bonus": _run_hp_bonus,
		"active_field_dungeon": _active_field_dungeon.duplicate(true),
		"active_mini_dungeon": _active_mini_dungeon.duplicate(true),
		"tiles": tiles_arr,
	})


func _restore_field_state_from_global() -> bool:
	var st: Dictionary = GlobalData.field_dungeon_state
	var raw_tiles: Variant = st.get("tiles", [])
	if typeof(raw_tiles) != TYPE_ARRAY or (raw_tiles as Array).is_empty():
		return false

	_grid_width = clampi(int(st.get("grid_width", 19)), 5, 29)
	_grid_height = clampi(int(st.get("grid_height", 13)), 4, 21)
	_layout_style = clampi(int(st.get("layout_style", 0)), 0, 2) as DungeonLayoutStyle
	_entry_direction = str(st.get("entry_direction", "WEST"))
	_player_pos = Vector2i(int(st.get("player_x", 0)), int(st.get("player_y", 5)))
	_threat_level = int(st.get("threat_level", 0))
	_run_atk_bonus = int(st.get("run_atk_bonus", 0))
	_run_hp_bonus = int(st.get("run_hp_bonus", 0))
	_active_field_dungeon = (st.get("active_field_dungeon", {}) as Dictionary).duplicate(true)
	_active_mini_dungeon = (st.get("active_mini_dungeon", {}) as Dictionary).duplicate(true)

	_field_tiles.clear()
	for raw_t in (raw_tiles as Array):
		if typeof(raw_t) != TYPE_DICTIONARY:
			continue
		var pos := Vector2i(int(raw_t.get("x", 0)), int(raw_t.get("y", 0)))
		_field_tiles[pos] = {
			"pos": pos,
			"type": int(raw_t.get("type", FieldTileType.EMPTY)) as FieldTileType,
			"revealed": bool(raw_t.get("revealed", false)),
			"cleared": bool(raw_t.get("cleared", false)),
			"visited": bool(raw_t.get("visited", false)),
			"boss_defeated": bool(raw_t.get("boss_defeated", false)),
			"locked_wall": bool(raw_t.get("locked_wall", false)),
			"element": str(raw_t.get("element", "FIRE")),
		}

	if _field_tiles.is_empty():
		return false
	_create_field_grid_buttons()
	return true


func _reveal_around(center: Vector2i, radius: int = 1) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var p := Vector2i(center.x + dx, center.y + dy)
			if _field_tiles.has(p):
				_field_tiles[p]["revealed"] = true


func _has_deployable_hero() -> bool:
	if GlobalData.hero_roster.is_empty():
		return true
	for h in GlobalData.get_active_party_heroes():
		if GlobalData.can_hero_deploy(h):
			return true
	return false


func _input(event: InputEvent) -> void:
	if not visible or not map_root.visible or _mode != ExploreMode.FIELD_GRID or _awaiting_modal or bag_overlay.visible:
		_is_dragging = false
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				if field_pan_container.get_global_rect().has_point(mb.global_position):
					_is_dragging = true
					_drag_moved = false
					_drag_start_pos = mb.global_position
					_drag_start_grid_pos = field_grid.position
			else:
				if _is_dragging and _drag_moved:
					_suppress_tile_click = true
					call_deferred("_clear_drag_suppress")
				_is_dragging = false
	elif event is InputEventMouseMotion and _is_dragging:
		var mm: InputEventMouseMotion = event
		var delta: Vector2 = mm.global_position - _drag_start_pos
		if delta.length() > DRAG_THRESHOLD_PX:
			_drag_moved = true
		if _drag_moved:
			field_grid.position = _clamp_grid_position(_drag_start_grid_pos + delta)
	elif event is InputEventScreenTouch:
		var st_ev: InputEventScreenTouch = event
		if st_ev.pressed:
			if field_pan_container.get_global_rect().has_point(st_ev.position):
				_is_dragging = true
				_drag_moved = false
				_drag_start_pos = st_ev.position
				_drag_start_grid_pos = field_grid.position
		else:
			if _is_dragging and _drag_moved:
				_suppress_tile_click = true
				call_deferred("_clear_drag_suppress")
			_is_dragging = false
	elif event is InputEventScreenDrag and _is_dragging:
		var sd: InputEventScreenDrag = event
		var delta_t: Vector2 = sd.position - _drag_start_pos
		if delta_t.length() > DRAG_THRESHOLD_PX:
			_drag_moved = true
		if _drag_moved:
			field_grid.position = _clamp_grid_position(_drag_start_grid_pos + delta_t)


func _clear_drag_suppress() -> void:
	_suppress_tile_click = false


func _on_pan_container_resized() -> void:
	if _mode == ExploreMode.FIELD_GRID:
		field_grid.position = _clamp_grid_position(field_grid.position)


func _clamp_grid_position(raw_pos: Vector2) -> Vector2:
	var view_size: Vector2 = field_pan_container.size
	var grid_size: Vector2 = field_grid.size
	var pad: float = 48.0
	var out_x: float = raw_pos.x
	var out_y: float = raw_pos.y

	if grid_size.x <= view_size.x:
		out_x = (view_size.x - grid_size.x) * 0.5
	else:
		out_x = clampf(out_x, view_size.x - grid_size.x - pad, pad)

	if grid_size.y <= view_size.y:
		out_y = (view_size.y - grid_size.y) * 0.5
	else:
		out_y = clampf(out_y, view_size.y - grid_size.y - pad, pad)

	return Vector2(out_x, out_y)


func _center_camera_on_player() -> void:
	var view_size: Vector2 = field_pan_container.size
	if view_size.x <= 10.0 or view_size.y <= 10.0:
		return
	var step_x: float = float(FIELD_TILE_W + FIELD_TILE_SEP)
	var step_y: float = float(FIELD_TILE_H + FIELD_TILE_SEP)
	var player_center := Vector2((_player_pos.x + 0.5) * step_x, (_player_pos.y + 0.5) * step_y)
	field_grid.position = _clamp_grid_position(view_size * 0.5 - player_center)


func _on_field_tile_pressed(pos: Vector2i) -> void:
	if _suppress_tile_click:
		_suppress_tile_click = false
		return
	if _mode != ExploreMode.FIELD_GRID or _awaiting_modal or bag_overlay.visible:
		return

	var dist: int = absi(pos.x - _player_pos.x) + absi(pos.y - _player_pos.y)
	var tile: Dictionary = _field_tiles.get(pos, {})
	if tile.is_empty():
		return

	# 현재 서 있는 포탈/출구 재클릭 허용
	if dist == 0:
		if tile["type"] == FieldTileType.MINI_DUNGEON_PORTAL and not bool(tile["cleared"]):
			_open_portal_modal(pos)
		elif tile["type"] == FieldTileType.EXIT:
			if bool(tile.get("boss_defeated", false)):
				_open_exit_modal()
			else:
				_pending_combat_context = "FIELD_BOSS"
				_launch_offense_combat(true, false)
		return

	if dist != 1:
		_set_status("인접한 타일(상하좌우 1칸)로만 이동할 수 있습니다.")
		return

	if int(tile["type"]) == FieldTileType.WALL:
		_set_status("바위 장벽으로 막혀 있어 통과할 수 없습니다. 우회 경로를 찾으세요.")
		return

	if not _has_deployable_hero():
		_show_info_modal("파티 전원 탈진/전투불능!", "출정 가능한 영웅이 없습니다 (피로도 100 [탈진] 또는 전투불능).\n우측 상단 [귀환] 버튼으로 마을로 복귀해 휴식하세요.")
		return

	# 1칸 이동 처리: 위치 이동, 안개 해제, 위협도 증가, 직군별 이동 피로도 누적
	_player_pos = pos
	tile["visited"] = true
	_reveal_around(pos)
	_threat_level = mini(100, _threat_level + 5)
	var f_changes: Array[Dictionary] = GlobalData.apply_party_move_fatigue()
	var sample_note: String = ""
	if not f_changes.is_empty():
		var parts: PackedStringArray = []
		for ch in f_changes.slice(0, mini(3, f_changes.size())):
			parts.append("%s+%d" % [ch["name"], int(ch["cost"])])
		sample_note = " (이동 피로: %s)" % ", ".join(parts)

	_save_field_state_to_global()
	_refresh_all_ui()
	call_deferred("_center_camera_on_player")

	if bool(tile["cleared"]) and tile["type"] != FieldTileType.EXIT:
		_set_status("이미 정리된 [%s] 지점입니다.%s" % [FIELD_TILE_LABELS[tile["type"]], sample_note])
		return

	match int(tile["type"]):
		FieldTileType.EMPTY, FieldTileType.START:
			tile["cleared"] = true
			_save_field_state_to_global()
			_set_status("황무지 정찰 완료. 주변 시야를 확보했습니다.%s" % sample_note)
			_refresh_field_grid_ui()
		FieldTileType.OUTPOST:
			_pending_combat_context = "OUTPOST"
			_launch_offense_combat(false, false)
		FieldTileType.BOSS:
			_pending_combat_context = "FIELD_BOSS"
			_launch_offense_combat(true, false)
		FieldTileType.SUPPLY:
			_trigger_supply_tile(tile)
		FieldTileType.TREASURE:
			_trigger_treasure_tile(tile)
		FieldTileType.EVENT:
			_trigger_mystery_event(tile)
		FieldTileType.MINI_DUNGEON_PORTAL:
			_open_portal_modal(pos)
		FieldTileType.EXIT:
			if bool(tile.get("boss_defeated", false)):
				_open_exit_modal()
			else:
				_pending_combat_context = "FIELD_BOSS"
				_launch_offense_combat(true, false)


func _trigger_supply_tile(tile: Dictionary) -> void:
	tile["cleared"] = true
	var food_gain: int = randi_range(12, 20)
	var mat_gain: int = randi_range(10, 18)
	var gold_gain: int = randi_range(15, 28)
	GlobalData.apply_deltas({
		"food": food_gain,
		"materials": mat_gain,
		"gold": gold_gain,
	})
	_save_field_state_to_global()
	_refresh_field_grid_ui()
	_show_info_modal(
		"보급 지점 확보!",
		"방치된 군수 물자를 회수했습니다.\n식량 +%d, 자재 +%d, 골드 +%d 획득!" % [food_gain, mat_gain, gold_gain]
	)


func _trigger_treasure_tile(tile: Dictionary) -> void:
	tile["cleared"] = true
	var gold_gain: int = randi_range(22, 48)
	GlobalData.apply_deltas({"gold": gold_gain})

	var reward_lines: PackedStringArray = ["골드 +%d" % gold_gain]
	# 소비 아이템 / 포션 1~2개 획득
	if not DataManager.items.is_empty():
		var item_rolls: int = 2 if randf() < 0.45 else 1
		for _i in range(item_rolls):
			var picked_item: Dictionary = DataManager.items[randi() % DataManager.items.size()]
			var iid: String = str(picked_item.get("id", ""))
			if not iid.is_empty():
				GlobalData.add_item(iid, 1)
				reward_lines.append("[%s] %s x1" % [str(picked_item.get("rarity", "N")), str(picked_item.get("name", ""))])

	# 65% 확률로 던전 드랍 장비 획득
	if randf() < 0.65:
		var drop_tpl: Dictionary = _roll_equipment_drop(_active_field_dungeon.get("drop_equipment_ids", []))
		if not drop_tpl.is_empty():
			reward_lines.append("★ 장비 [%s] %s" % [str(drop_tpl.get("rarity", "N")), str(drop_tpl.get("name", ""))])

	_save_field_state_to_global()
	_refresh_field_grid_ui()
	_show_info_modal(
		"★ 보물 상자 발견!",
		"외곽 미궁에 숨겨진 보물 상자를 열었습니다!\n\n[획득 보상]\n• " + "\n• ".join(reward_lines)
	)


func _open_portal_modal(portal_pos: Vector2i) -> void:
	var mini_name: String = str(_active_mini_dungeon.get("name", "미니 파밍 던전"))
	var drop_names: PackedStringArray = []
	for eq_id in _active_mini_dungeon.get("drop_equipment_ids", []):
		var tpl: Dictionary = DataManager.get_equipment(str(eq_id))
		if not tpl.is_empty():
			drop_names.append("[%s] %s" % [str(tpl.get("rarity", "N")), str(tpl.get("name", eq_id))])
	var drop_text: String = ", ".join(drop_names) if not drop_names.is_empty() else "무작위 장비"

	_show_choice_modal(
		"미니 파밍 던전 입구: %s" % mini_name,
		"깊이 %d단계의 분기형 파밍 던전으로 진입하시겠습니까?\n클리어 시 외곽 그리드로 복귀하며 파밍 장비를 획득합니다.\n\n[예상 드랍 장비]\n%s" % [
			int(_active_mini_dungeon.get("depth", 5)),
			drop_text,
		],
		[
			{"label": "▶ [%s] 진입 (미니 던전 시작)" % mini_name, "action": _on_confirm_enter_mini_rogue.bind(portal_pos)},
			{"label": "나중에 진입하기", "action": _close_modal},
		]
	)


func _on_confirm_enter_mini_rogue(portal_pos: Vector2i) -> void:
	_close_modal()
	_enter_mini_rogue(portal_pos)


func _open_exit_modal() -> void:
	_show_choice_modal(
		"외곽 귀환 포탈",
		"탐험 성과를 챙겨 안전하게 마을(정산)로 귀환하시겠습니까?",
		[
			{"label": "마을로 귀환 (하루 정산으로 이동)", "action": _on_confirm_return_to_town},
			{"label": "외곽 탐험 계속하기", "action": _close_modal},
		]
	)


# ==========================================
# MINI_ROGUE (분기형 미니 파밍 던전)
# ==========================================
func _enter_mini_rogue(portal_pos: Vector2i) -> void:
	_mode = ExploreMode.MINI_ROGUE
	_active_portal_pos = portal_pos
	_rogue_nodes.clear()
	_rogue_edges.clear()
	_rogue_cleared_ids.clear()
	_rogue_traveled_edges.clear()
	_rogue_current_id = 0

	var depth: int = clampi(int(_active_mini_dungeon.get("depth", 5)), 4, 6)
	var mid_layers: int = depth - 2
	var layers: Array = []

	var start_node := _make_rogue_node(0, RogueRoomType.START, 0, Vector2(0.08, 0.50))
	_rogue_nodes.append(start_node)
	layers.append([start_node])

	var next_id: int = 1
	var mid_pool: Array[RogueRoomType] = [
		RogueRoomType.BATTLE,
		RogueRoomType.ELITE,
		RogueRoomType.MYSTERY,
		RogueRoomType.CAMP,
		RogueRoomType.TREASURE,
	]
	for layer_idx in range(1, mid_layers + 1):
		var count: int = 2 if (layer_idx == 1 or layer_idx == mid_layers) else randi_range(2, 3)
		var layer_nodes: Array = []
		var x_ratio: float = lerp(0.24, 0.74, float(layer_idx - 1) / maxf(1.0, float(mid_layers - 1)))
		for i in range(count):
			var y_ratio: float = 0.50 if count == 1 else lerp(0.20, 0.80, float(i) / float(count - 1))
			var r_type: RogueRoomType = mid_pool[randi() % mid_pool.size()]
			if layer_idx == 1 and i == 0:
				r_type = RogueRoomType.BATTLE
			elif layer_idx == mid_layers and i == count - 1:
				r_type = RogueRoomType.CAMP if randf() < 0.5 else RogueRoomType.TREASURE
			var node := _make_rogue_node(next_id, r_type, layer_idx, Vector2(x_ratio, y_ratio))
			next_id += 1
			_rogue_nodes.append(node)
			layer_nodes.append(node)
		layers.append(layer_nodes)

	var boss_node := _make_rogue_node(next_id, RogueRoomType.BOSS, depth - 1, Vector2(0.91, 0.50))
	_rogue_nodes.append(boss_node)
	layers.append([boss_node])

	for layer_i in range(layers.size() - 1):
		var cur_layer: Array = layers[layer_i]
		var nxt_layer: Array = layers[layer_i + 1]
		for u_idx in range(cur_layer.size()):
			var u_node: Dictionary = cur_layer[u_idx]
			var target_idx: int = mini(u_idx, nxt_layer.size() - 1)
			_connect_rogue_nodes(u_node, nxt_layer[target_idx])
			if nxt_layer.size() > 1 and (cur_layer.size() == 1 or randf() < 0.5):
				var alt_idx: int = (target_idx + 1) % nxt_layer.size()
				_connect_rogue_nodes(u_node, nxt_layer[alt_idx])
		for v_node in nxt_layer:
			if not _has_incoming_rogue_edge(int(v_node["id"])):
				var prev_node: Dictionary = cur_layer[randi() % cur_layer.size()]
				_connect_rogue_nodes(prev_node, v_node)

	_rogue_cleared_ids.append(0)
	_build_rogue_views()
	_set_status("[%s] 진입 완료! 연결된 다음 분기 노드를 선택해 파밍하세요." % str(_active_mini_dungeon.get("name", "미니 던전")))
	_refresh_all_ui()


func _make_rogue_node(node_id: int, r_type: RogueRoomType, layer: int, norm_pos: Vector2) -> Dictionary:
	return {
		"id": node_id,
		"type": r_type,
		"layer": layer,
		"norm_pos": norm_pos,
		"next_ids": [],
	}


func _connect_rogue_nodes(from_node: Dictionary, to_node: Dictionary) -> void:
	var to_id: int = int(to_node["id"])
	var next_ids: Array = from_node["next_ids"]
	if next_ids.has(to_id):
		return
	next_ids.append(to_id)
	_rogue_edges.append({"from": int(from_node["id"]), "to": to_id})


func _has_incoming_rogue_edge(target_id: int) -> bool:
	for edge in _rogue_edges:
		if int(edge["to"]) == target_id:
			return true
	return false


func _get_rogue_node(node_id: int) -> Dictionary:
	for n in _rogue_nodes:
		if int(n["id"]) == node_id:
			return n
	return {}


func _build_rogue_views() -> void:
	for child in lines_layer.get_children():
		child.queue_free()
	for child in nodes_layer.get_children():
		child.queue_free()
	_rogue_node_views.clear()

	for edge in _rogue_edges:
		var line := Line2D.new()
		line.width = 4.0
		line.default_color = COLOR_LINE_DEFAULT
		line.antialiased = true
		lines_layer.add_child(line)
		edge["line"] = line

	for node in _rogue_nodes:
		var n_id: int = int(node["id"])
		var root := Control.new()
		root.size = NODE_SIZE

		var bg := ColorRect.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bg)

		var btn := Button.new()
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(_on_rogue_node_pressed.bind(n_id))
		root.add_child(btn)

		nodes_layer.add_child(root)
		_rogue_node_views[n_id] = {"root": root, "bg": bg, "button": btn}

	call_deferred("_layout_rogue_elements")


func _layout_rogue_elements() -> void:
	if _mode != ExploreMode.MINI_ROGUE or _rogue_nodes.is_empty():
		return
	var canvas_size: Vector2 = rogue_layer.size
	if canvas_size.x <= 10.0 or canvas_size.y <= 10.0:
		return
	var centers: Dictionary = {}
	for node in _rogue_nodes:
		var n_id: int = int(node["id"])
		if not _rogue_node_views.has(n_id):
			continue
		var norm: Vector2 = node["norm_pos"]
		var center := Vector2(norm.x * canvas_size.x, norm.y * canvas_size.y)
		centers[n_id] = center
		var root: Control = _rogue_node_views[n_id]["root"]
		root.position = center - NODE_SIZE * 0.5
		root.size = NODE_SIZE

	for edge in _rogue_edges:
		var line: Line2D = edge.get("line")
		if line == null:
			continue
		var from_id: int = int(edge["from"])
		var to_id: int = int(edge["to"])
		if centers.has(from_id) and centers.has(to_id):
			line.points = PackedVector2Array([centers[from_id], centers[to_id]])


func _on_rogue_node_pressed(node_id: int) -> void:
	if _mode != ExploreMode.MINI_ROGUE or _awaiting_modal:
		return
	var current_node: Dictionary = _get_rogue_node(_rogue_current_id)
	var reachable: Array = current_node.get("next_ids", [])
	if not reachable.has(node_id):
		return

	var target: Dictionary = _get_rogue_node(node_id)
	if target.is_empty():
		return

	_rogue_traveled_edges.append(Vector2i(_rogue_current_id, node_id))
	_rogue_current_id = node_id
	_threat_level = mini(100, _threat_level + 4)
	_refresh_all_ui()

	match int(target["type"]):
		RogueRoomType.BATTLE:
			_pending_combat_context = "ROGUE_BATTLE"
			_launch_offense_combat(false, false)
		RogueRoomType.ELITE:
			_pending_combat_context = "ROGUE_ELITE"
			_launch_offense_combat(false, true)
		RogueRoomType.BOSS:
			_pending_combat_context = "ROGUE_BOSS"
			_launch_offense_combat(true, false)
		RogueRoomType.MYSTERY:
			_trigger_mystery_event({})
		RogueRoomType.CAMP:
			_trigger_camp_modal()
		RogueRoomType.TREASURE:
			_trigger_treasure_modal()


# ==========================================
# 전투 연결 & 이벤트/캠프/장비 드랍 처리
# ==========================================
func _launch_offense_combat(is_boss: bool, is_elite: bool) -> void:
	if not _has_deployable_hero():
		_show_info_modal("출정 불가!", "전투에 나설 수 있는 영웅이 없습니다 (전원 탈진 또는 전투불능).\n마을로 귀환해 휴식하세요.")
		return

	if managed_externally:
		combat_requested.emit(is_boss, _run_atk_bonus, _run_hp_bonus, is_elite)
	else:
		map_root.visible = false
		offense_scene.visible = true
		offense_scene.start_battle(is_boss, _run_atk_bonus, _run_hp_bonus, is_elite)


func _on_offense_return_requested(victory: bool, is_boss: bool) -> void:
	if not victory:
		offense_scene.visible = false
		map_root.visible = true
		_set_status("전투 패배... 아군이 전멸했습니다.")
		_refresh_all_ui()
		return
	on_external_combat_victory(is_boss)
	offense_scene.visible = false
	map_root.visible = true


func on_external_combat_victory(is_boss: bool) -> void:
	if _mode == ExploreMode.FIELD_GRID:
		if _field_tiles.has(_player_pos):
			_field_tiles[_player_pos]["cleared"] = true
		if _pending_combat_context == "OUTPOST":
			GlobalData.outpost_weakened_stacks += 1
			# 전초기지 점령 시 정찰 조명탄(반경 2 시야 개방) + 인접 바위 장벽 1곳 붕괴로 비밀 우회로 개통
			_reveal_around(_player_pos, 2)
			var broken_note: String = ""
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var adj: Vector2i = _player_pos + d
				if _field_tiles.has(adj) and int(_field_tiles[adj]["type"]) == FieldTileType.WALL and not bool(_field_tiles[adj].get("locked_wall", false)):
					_field_tiles[adj]["type"] = FieldTileType.EMPTY
					_field_tiles[adj]["revealed"] = true
					broken_note = " / 인접 바위 장벽이 무너져 비밀 통로가 열렸습니다!"
					break
			_set_status("적 전초기지 격파! 다음 디펜스 웨이브 약화 (스택: %d) + 반경 2칸 시야 확보%s" % [GlobalData.outpost_weakened_stacks, broken_note])
		elif _pending_combat_context == "FIELD_BOSS":
			if _field_tiles.has(_player_pos):
				_field_tiles[_player_pos]["boss_defeated"] = true
				_field_tiles[_player_pos]["cleared"] = true
			GlobalData.apply_deltas({"gold": 120, "materials": 45, "food": 25})
			var boss_drop: Dictionary = _roll_high_tier_equipment_drop()
			var b_msg: String = "귀환 포탈을 수호하던 던전 보스를 격파했습니다!\n대량 보상: 골드 +120, 자재 +45, 식량 +25"
			if not DataManager.items.is_empty():
				var sr_items: Array[Dictionary] = []
				for it in DataManager.items:
					if str(it.get("rarity", "N")) in ["R", "SR", "SSR"]:
						sr_items.append(it)
				var bonus_it: Dictionary = sr_items[randi() % sr_items.size()] if not sr_items.is_empty() else DataManager.items[0]
				GlobalData.add_item(str(bonus_it["id"]), 1)
				b_msg += "\n포션 획득: [%s] %s x1" % [str(bonus_it.get("rarity", "R")), str(bonus_it.get("name", ""))]
			if not boss_drop.is_empty():
				b_msg += "\n\n★ 보스 확정 고등급 장비 획득:\n[%s] %s" % [str(boss_drop.get("rarity", "SR")), str(boss_drop.get("name", ""))]
			b_msg += "\n\n귀환 포탈이 해방되었습니다! 다음 행동을 선택하세요."
			_show_choice_modal(
				"★ 던전 클리어 · 보스 격파 & 포탈 해방!",
				b_msg,
				[
					{"label": "바로 다음으로 진행 (마을 귀환 · 정산)", "action": _on_confirm_return_to_town},
					{"label": "전투 후 가방/포션 정비 (계속 탐색)", "action": _on_open_bag_after_clear},
					{"label": "남은 던전 계속 탐색", "action": _close_modal},
				]
			)
			_set_status("보스 격파! 귀환 포탈이 해방되었습니다.")
		else:
			_set_status("전투 승리! 다음 타일로 이동하세요.")
		_pending_combat_context = ""
		_save_field_state_to_global()
		_refresh_all_ui()
		return

	# MINI_ROGUE 승리 처리
	if not _rogue_cleared_ids.has(_rogue_current_id):
		_rogue_cleared_ids.append(_rogue_current_id)

	if is_boss or _pending_combat_context == "ROGUE_BOSS":
		_pending_combat_context = ""
		var drop_tpl: Dictionary = _roll_equipment_drop(_active_mini_dungeon.get("drop_equipment_ids", []))
		if _field_tiles.has(_active_portal_pos):
			_field_tiles[_active_portal_pos]["cleared"] = true
		_mode = ExploreMode.FIELD_GRID
		_save_field_state_to_global()
		_refresh_all_ui()
		var drop_msg: String = "미니 던전 [%s]의 최종 수호자를 격파하고 클리어했습니다!" % str(_active_mini_dungeon.get("name", "지하묘지"))
		if not drop_tpl.is_empty():
			drop_msg += "\n\n★ 클리어 보상 장비 획득:\n[%s] %s" % [str(drop_tpl.get("rarity", "N")), str(drop_tpl.get("name", ""))]
		drop_msg += "\n\n바로 외곽 던전으로 복귀하거나 가방/포션으로 정비할 수 있습니다."
		_show_choice_modal(
			"★ 미니 던전 클리어!",
			drop_msg,
			[
				{"label": "바로 외곽 던전으로 복귀", "action": _close_modal},
				{"label": "정비하기 (가방/포션 사용)", "action": _on_open_bag_after_clear},
			]
		)
		_set_status("미니 파밍 던전 클리어! 외곽 그리드로 복귀했습니다.")
		return

	if _pending_combat_context == "ROGUE_ELITE":
		_pending_combat_context = ""
		var elite_drop: Dictionary = _roll_equipment_drop(_active_mini_dungeon.get("drop_equipment_ids", []))
		_refresh_all_ui()
		if not elite_drop.is_empty():
			_show_info_modal(
				"정예 적 격파!",
				"강력한 정예 수호대를 쓰러뜨렸습니다!\n\n전리품 장비 획득:\n[%s] %s" % [str(elite_drop.get("rarity", "N")), str(elite_drop.get("name", ""))]
			)
		else:
			_set_status("정예 전투 승리! 다음 분기 노드로 이동하세요.")
		return

	_pending_combat_context = ""
	_set_status("전투 승리! 다음 분기 노드를 선택하세요.")
	_refresh_all_ui()


func _roll_equipment_drop(drop_ids: Array) -> Dictionary:
	var valid_tpls: Array[Dictionary] = []
	var unowned_named: Array[Dictionary] = []
	for raw_id in drop_ids:
		var tpl: Dictionary = DataManager.get_equipment(str(raw_id))
		if tpl.is_empty():
			continue
		valid_tpls.append(tpl)
		var is_named_eq: bool = not str(tpl.get("exclusive_hero_id", "")).is_empty()
		if is_named_eq and not GlobalData.has_equipment_id_in_inventory(str(tpl["id"])):
			unowned_named.append(tpl)

	if valid_tpls.is_empty():
		var all_eq: Array[Dictionary] = DataManager.equipments
		if all_eq.is_empty():
			return {}
		var fallback: Dictionary = all_eq[randi() % all_eq.size()]
		GlobalData.add_equipment_to_inventory(str(fallback["id"]))
		return fallback

	var chosen: Dictionary = unowned_named[randi() % unowned_named.size()] if not unowned_named.is_empty() else valid_tpls[randi() % valid_tpls.size()]
	GlobalData.add_equipment_to_inventory(str(chosen["id"]))
	return chosen


func _roll_high_tier_equipment_drop() -> Dictionary:
	var high_tier: Array[Dictionary] = []
	for eq in DataManager.equipments:
		var r: String = DataManager.normalize_rarity(eq.get("rarity", "N"))
		if r == "SR" or r == "SSR":
			if GlobalData.can_obtain_equipment(str(eq["id"])):
				high_tier.append(eq)
	if high_tier.is_empty():
		return _roll_equipment_drop([])
	var chosen: Dictionary = high_tier[randi() % high_tier.size()]
	GlobalData.add_equipment_to_inventory(str(chosen["id"]))
	return chosen


func _trigger_mystery_event(field_tile: Dictionary) -> void:
	if not field_tile.is_empty():
		field_tile["cleared"] = true
		_save_field_state_to_global()
	var events: Array[Dictionary] = DataManager.dungeon_events
	if events.is_empty():
		GlobalData.apply_deltas({"gold": 25})
		_show_info_modal("? 미지 조우", "낡은 상자에서 골드 25를 발견했습니다.")
		return

	var ev: Dictionary = events[randi() % events.size()]
	var choices_data: Array = ev.get("choices", [])
	if choices_data.is_empty():
		_show_info_modal(str(ev.get("title", "? 이벤트")), str(ev.get("description", "")))
		return

	var modal_choices: Array[Dictionary] = []
	for raw_ch in choices_data:
		var ch: Dictionary = raw_ch
		var cost: Dictionary = ch.get("cost", {})
		var rewards: Dictionary = ch.get("rewards", {})
		var f_delta: int = int(ch.get("fatigue_delta", 0))
		var can_pay: bool = cost.is_empty() or GlobalData.can_afford(cost)
		var summary_parts: PackedStringArray = []
		var cost_txt: String = _format_delta_dict(cost)
		var rew_txt: String = _format_delta_dict(rewards)
		if not cost_txt.is_empty():
			summary_parts.append("비용:" + cost_txt)
		if not rew_txt.is_empty():
			summary_parts.append("보상:" + rew_txt)
		if f_delta != 0:
			summary_parts.append("피로 %+d" % f_delta)
		var base_txt: String = str(ch.get("text", ch.get("label", "선택지")))
		var suffix: String = " (%s)" % " / ".join(summary_parts) if (not summary_parts.is_empty() and not base_txt.contains("(")) else ""
		var btn_label: String = "%s%s" % [base_txt, suffix]
		modal_choices.append({
			"label": btn_label,
			"disabled": not can_pay,
			"action": _on_mystery_choice_picked.bind(ch, cost),
		})

	_show_choice_modal(str(ev.get("title", "? 이벤트")), str(ev.get("description", "")), modal_choices)


func _on_mystery_choice_picked(ch: Dictionary, cost: Dictionary) -> void:
	if not cost.is_empty() and not GlobalData.spend_resources(cost):
		return
	_apply_event_choice_effects(ch)


func _apply_event_choice_effects(ch: Dictionary) -> void:
	var rewards: Dictionary = ch.get("rewards", {})
	var f_delta: int = int(ch.get("fatigue_delta", 0))
	var res_deltas: Dictionary = {}
	var drop_log: String = ""

	for key in rewards:
		var val: Variant = rewards[key]
		if key == "wall_hp":
			GlobalData.repair_wall(int(val))
		elif key == "wall_atk_bonus":
			GlobalData.defense_wall_atk_bonus += int(val)
		elif key == "drop_random_equip":
			if bool(val):
				var pool_ids: Array = _active_mini_dungeon.get("drop_equipment_ids", []) if _mode == ExploreMode.MINI_ROGUE else _active_field_dungeon.get("drop_equipment_ids", [])
				var drop_tpl: Dictionary = _roll_equipment_drop(pool_ids)
				if not drop_tpl.is_empty():
					drop_log = "\n장비 획득: [%s] %s" % [str(drop_tpl.get("rarity", "N")), str(drop_tpl.get("name", ""))]
		elif key == "atk_bonus":
			_run_atk_bonus += int(val)
		elif key == "hp_bonus":
			_run_hp_bonus += int(val)
		else:
			res_deltas[key] = int(val)

	if not res_deltas.is_empty():
		GlobalData.apply_deltas(res_deltas)

	if f_delta < 0:
		GlobalData.recover_all_roster_fatigue(absi(f_delta))
	elif f_delta > 0:
		for h in GlobalData.hero_roster:
			if int(h.get("hp", 0)) > 0:
				GlobalData.add_hero_fatigue(int(h.get("uid", -1)), f_delta)

	if _mode == ExploreMode.MINI_ROGUE and not _rogue_cleared_ids.has(_rogue_current_id):
		_rogue_cleared_ids.append(_rogue_current_id)

	_close_modal()
	var raw_res: String = str(ch.get("result_text", "")).strip_edges()
	var auto_summary: String = _format_delta_dict(rewards)
	if f_delta != 0:
		auto_summary = (auto_summary + ", " if not auto_summary.is_empty() else "") + "피로도 %+d" % f_delta
	var result_text: String = raw_res if not raw_res.is_empty() else ("선택 완료! (%s)" % auto_summary if not auto_summary.is_empty() else "선택 결과를 적용했습니다.")
	result_text += drop_log
	_show_info_modal("이벤트 결과", result_text)


func _trigger_camp_modal() -> void:
	var camp_cost := {"food": 12}
	var can_cook: bool = GlobalData.can_afford(camp_cost)
	_show_choice_modal(
		"던전 야영지 (CAMP)",
		"잠시 안전을 확보하고 파티의 피로와 체력을 회복할 수 있습니다.",
		[
			{
				"label": "식량 12 소비 → 파티 전원 피로도 -35 & HP +20 회복",
				"disabled": not can_cook,
				"action": _on_camp_rest_food.bind(camp_cost),
			},
			{
				"label": "간단한 휴식 (식량 미소비) → 파티 피로도 -15",
				"disabled": false,
				"action": _on_camp_rest_free,
			},
		]
	)


func _on_camp_rest_food(camp_cost: Dictionary) -> void:
	if not GlobalData.spend_resources(camp_cost):
		return
	GlobalData.recover_all_roster_fatigue(35)
	for h in GlobalData.hero_roster:
		var uid: int = int(h.get("uid", -1))
		if uid > 0 and int(h.get("hp", 0)) > 0:
			var max_hp: int = roundi(GlobalData.get_effective_stat(h, "max_hp"))
			GlobalData.set_hero_hp(uid, mini(max_hp, int(h.get("hp", 0)) + 20))
	if not _rogue_cleared_ids.has(_rogue_current_id):
		_rogue_cleared_ids.append(_rogue_current_id)
	_close_modal()
	_show_info_modal("야영 휴식 완료", "따뜻한 식사와 휴식으로 파티 피로도가 35 감소하고 체력이 회복되었습니다!")


func _on_camp_rest_free() -> void:
	GlobalData.recover_all_roster_fatigue(15)
	if not _rogue_cleared_ids.has(_rogue_current_id):
		_rogue_cleared_ids.append(_rogue_current_id)
	_close_modal()
	_show_info_modal("간단한 휴식 완료", "잠시 숨을 고르며 파티 피로도가 15 감소했습니다.")


func _trigger_treasure_modal() -> void:
	if not _rogue_cleared_ids.has(_rogue_current_id):
		_rogue_cleared_ids.append(_rogue_current_id)
	var gold_gain: int = randi_range(30, 55)
	var mat_gain: int = randi_range(12, 22)
	GlobalData.apply_deltas({"gold": gold_gain, "materials": mat_gain})
	var drop_tpl: Dictionary = _roll_equipment_drop(_active_mini_dungeon.get("drop_equipment_ids", []))
	var msg: String = "미니 던전의 보물 상자를 열었습니다!\n골드 +%d, 자재 +%d 획득!" % [gold_gain, mat_gain]
	if not drop_tpl.is_empty():
		msg += "\n\n★ 파밍 장비 획득:\n[%s] %s" % [str(drop_tpl.get("rarity", "N")), str(drop_tpl.get("name", ""))]
	_show_info_modal("보물 상자 발견!", msg)


func _format_delta_dict(d: Dictionary) -> String:
	var key_names := {"gold": "골드", "food": "식량", "materials": "자재", "morale": "사기", "wall_hp": "성벽HP", "wall_atk_bonus": "성벽화력", "drop_random_equip": "랜덤장비"}
	var parts: PackedStringArray = []
	for k in d:
		var lbl: String = str(key_names.get(str(k), str(k)))
		if str(k) == "drop_random_equip":
			if bool(d[k]):
				parts.append(lbl)
		elif int(d[k]) != 0:
			parts.append("%s %+d" % [lbl, int(d[k])])
	return ", ".join(parts)


# ==========================================
# 모달 제어
# ==========================================
func _clear_modal_choices() -> void:
	for child in event_choices_vbox.get_children():
		child.queue_free()


func _show_info_modal(title_text: String, desc_text: String) -> void:
	_awaiting_modal = true
	_clear_modal_choices()
	event_title_label.text = title_text
	event_desc_label.text = desc_text
	event_choices_vbox.visible = false
	event_confirm_button.visible = true
	event_overlay.visible = true
	_refresh_all_ui()


func _show_choice_modal(title_text: String, desc_text: String, choices: Array) -> void:
	_awaiting_modal = true
	_clear_modal_choices()
	event_title_label.text = title_text
	event_desc_label.text = desc_text
	event_choices_vbox.visible = true
	event_confirm_button.visible = false
	for ch in choices:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 40)
		btn.add_theme_font_size_override("font_size", 13)
		btn.text = str(ch.get("label", "선택"))
		btn.disabled = bool(ch.get("disabled", false))
		var cb: Callable = ch.get("action", _close_modal)
		btn.pressed.connect(cb)
		event_choices_vbox.add_child(btn)
	event_overlay.visible = true
	_refresh_all_ui()


func _close_modal() -> void:
	_awaiting_modal = false
	event_overlay.visible = false
	_clear_modal_choices()
	_refresh_all_ui()


# ==========================================
# UI 전체 갱신
# ==========================================
func _refresh_all_ui() -> void:
	_refresh_header_labels()
	_refresh_party_hud()

	field_pan_container.visible = (_mode == ExploreMode.FIELD_GRID)
	rogue_layer.visible = (_mode == ExploreMode.MINI_ROGUE)
	center_camera_button.visible = (_mode == ExploreMode.FIELD_GRID)

	if _mode == ExploreMode.FIELD_GRID:
		_refresh_field_grid_ui()
	else:
		_refresh_rogue_ui()


func _refresh_header_labels() -> void:
	if _mode == ExploreMode.FIELD_GRID:
		title_label.text = str(_active_field_dungeon.get("name", "외곽 황무지 경계선"))
		mode_badge_label.text = "[%s · %dx%d · %s 진입 | %d번 파티]" % [
			LAYOUT_STYLE_LABELS.get(_layout_style, "외곽 미궁"),
			_grid_width,
			_grid_height,
			ENTRY_DIR_LABELS.get(_entry_direction, _entry_direction),
			GlobalData.selected_party_index + 1,
		]
		mode_badge_label.modulate = Color(0.55, 0.90, 1.0)
	else:
		title_label.text = str(_active_mini_dungeon.get("name", "붉은 지하묘지"))
		mode_badge_label.text = "[2. 미니 파밍 던전 | %d번 파티]" % (GlobalData.selected_party_index + 1)
		mode_badge_label.modulate = Color(1.0, 0.72, 0.35)

	threat_label.text = "위협도: %d/100 | 전초기지 약화: %d | 예상 디펜스 속성: [%s]" % [
		_threat_level,
		GlobalData.outpost_weakened_stacks,
		GlobalData.get_upcoming_defense_elements_text(),
	]
	buff_label.text = "탐험 버프: ATK +%d / HP +%d | 식량 %d | 골드 %d" % [
		_run_atk_bonus,
		_run_hp_bonus,
		GlobalData.get_resource("food"),
		GlobalData.get_resource("gold"),
	]


func _refresh_field_grid_ui() -> void:
	for pos in _field_tiles:
		var tile: Dictionary = _field_tiles[pos]
		var btn: Button = _field_buttons.get(pos)
		if btn == null:
			continue
		var dist: int = absi(pos.x - _player_pos.x) + absi(pos.y - _player_pos.y)
		var is_player: bool = (pos == _player_pos)
		var is_revealed: bool = bool(tile["revealed"])
		var is_cleared: bool = bool(tile["cleared"])
		var t_type: FieldTileType = tile["type"]

		if not is_revealed:
			btn.text = "???\n(안개)"
			btn.modulate = COLOR_FOG
			btn.disabled = true
			continue

		var type_label: String = FIELD_TILE_LABELS.get(t_type, "타일")
		var tile_color: Color = FIELD_TILE_COLORS.get(t_type, Color.GRAY)
		if t_type == FieldTileType.EXIT:
			var boss_done: bool = bool(tile.get("boss_defeated", false))
			type_label = "귀환 포탈(해방)" if boss_done else "★보스·귀환포탈"
			tile_color = FIELD_TILE_COLORS[FieldTileType.EXIT] if boss_done else FIELD_TILE_COLORS[FieldTileType.BOSS]
		if t_type == FieldTileType.WALL:
			btn.text = "■ %s\n(통행불가)" % type_label
			btn.modulate = FIELD_TILE_COLORS[FieldTileType.WALL]
			btn.disabled = true
			continue
		if is_player:
			btn.text = "★ 현재 위치\n[%s]" % type_label
			btn.modulate = COLOR_PLAYER_TILE
			btn.disabled = _awaiting_modal or (t_type != FieldTileType.MINI_DUNGEON_PORTAL and t_type != FieldTileType.EXIT)
		elif dist == 1:
			var status_tag: String = "(정리됨)" if is_cleared else ("▶ 보스전" if t_type == FieldTileType.EXIT else "▶ 이동")
			btn.text = "%s\n%s" % [type_label, status_tag]
			btn.modulate = COLOR_CLEARED_TILE if is_cleared else tile_color
			btn.disabled = _awaiting_modal
		else:
			btn.text = "%s\n%s" % [type_label, "(완료)" if is_cleared else "(탐사 가능)"]
			btn.modulate = COLOR_CLEARED_TILE if is_cleared else tile_color.darkened(0.25)
			btn.disabled = true


func _refresh_rogue_ui() -> void:
	var current_node: Dictionary = _get_rogue_node(_rogue_current_id)
	var reachable_ids: Array = current_node.get("next_ids", [])

	for edge in _rogue_edges:
		var line: Line2D = edge.get("line")
		if line == null:
			continue
		var from_id: int = int(edge["from"])
		var to_id: int = int(edge["to"])
		if _rogue_traveled_edges.has(Vector2i(from_id, to_id)):
			line.default_color = COLOR_LINE_TRAVELED
			line.width = 5.0
		elif from_id == _rogue_current_id and not _awaiting_modal:
			line.default_color = COLOR_LINE_AVAILABLE
			line.width = 5.0
		else:
			line.default_color = COLOR_LINE_DEFAULT
			line.width = 3.0

	for node in _rogue_nodes:
		var n_id: int = int(node["id"])
		if not _rogue_node_views.has(n_id):
			continue
		var view: Dictionary = _rogue_node_views[n_id]
		var bg: ColorRect = view["bg"]
		var btn: Button = view["button"]
		var room_name: String = ROGUE_ROOM_NAMES.get(node["type"], "노드")

		var is_current: bool = (n_id == _rogue_current_id)
		var is_cleared: bool = _rogue_cleared_ids.has(n_id)
		var is_reachable: bool = reachable_ids.has(n_id) and not _awaiting_modal

		if is_current:
			bg.color = COLOR_NODE_CURRENT
			btn.text = "%s\n[현재 위치]" % room_name
			btn.disabled = true
		elif is_reachable:
			bg.color = ROGUE_ROOM_COLORS.get(node["type"], Color.GRAY)
			btn.text = "%s\n▶ [진입 가능]" % room_name
			btn.disabled = false
		elif is_cleared:
			bg.color = COLOR_NODE_CLEARED
			btn.text = "%s\n[완료]" % room_name
			btn.disabled = true
		else:
			bg.color = COLOR_NODE_LOCKED
			btn.text = "%s\n[미개방]" % room_name
			btn.disabled = true

	call_deferred("_layout_rogue_elements")


func _refresh_party_hud() -> void:
	for child in party_status_hbox.get_children():
		child.queue_free()

	for hero in GlobalData.get_active_party_heroes():
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(246, 86)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_bottom", 4)
		card.add_child(margin)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 3)
		margin.add_child(vb)

		var hp: int = int(hero.get("hp", 0))
		var max_hp: int = maxi(1, roundi(GlobalData.get_effective_stat(hero, "max_hp")))
		var fatigue: int = int(hero.get("fatigue", 0))
		var f_state: String = GlobalData.get_hero_fatigue_state_label(hero)

		var name_lbl := Label.new()
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.text = "%s (%s)" % [str(hero.get("name", "영웅")), str(hero.get("job_class", ""))]
		vb.add_child(name_lbl)

		var hp_lbl := Label.new()
		hp_lbl.add_theme_font_size_override("font_size", 10)
		hp_lbl.text = "HP %d/%d  |  피로 %d%% [%s]" % [hp, max_hp, fatigue, f_state]
		if GlobalData.is_hero_exhausted(hero):
			hp_lbl.modulate = Color(1.0, 0.35, 0.35)
		elif GlobalData.is_hero_tired(hero):
			hp_lbl.modulate = Color(1.0, 0.72, 0.30)
		vb.add_child(hp_lbl)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 10)
		bar.max_value = GlobalData.MAX_FATIGUE
		bar.value = fatigue
		bar.show_percentage = false
		if GlobalData.is_hero_exhausted(hero):
			bar.modulate = Color(1.0, 0.35, 0.35)
		elif GlobalData.is_hero_tired(hero):
			bar.modulate = Color(1.0, 0.72, 0.30)
		else:
			bar.modulate = Color(0.42, 0.86, 1.0)
		vb.add_child(bar)

		party_status_hbox.add_child(card)


func _set_status(msg: String) -> void:
	status_label.text = msg


# ==========================================
# 탐험 가방 / 던전 포션 사용 오버레이
# ==========================================
func _open_bag_overlay() -> void:
	if _awaiting_modal:
		return
	bag_status_label.text = ""
	bag_overlay.visible = true
	_refresh_bag_overlay()


func _close_bag_overlay() -> void:
	bag_overlay.visible = false
	_refresh_all_ui()


func _refresh_bag_overlay() -> void:
	for child in bag_hero_hbox.get_children():
		child.queue_free()
	for child in bag_items_vbox.get_children():
		child.queue_free()

	var party: Array[Dictionary] = GlobalData.get_active_party_heroes()
	if _bag_target_hero_uid < 0 or GlobalData.get_hero_by_uid(_bag_target_hero_uid).is_empty():
		if not party.is_empty():
			_bag_target_hero_uid = int(party[0].get("uid", -1))

	for h in party:
		var uid: int = int(h.get("uid", -1))
		var max_hp: int = maxi(1, roundi(GlobalData.get_effective_stat(h, "max_hp")))
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 44)
		b.add_theme_font_size_override("font_size", 12)
		var sel: bool = (uid == _bag_target_hero_uid)
		b.text = "%s%s\nHP %d/%d | 피로 %d%%" % ["▶ " if sel else "", str(h.get("name", "영웅")), int(h.get("hp", 0)), max_hp, int(h.get("fatigue", 0))]
		b.modulate = Color(0.55, 0.92, 1.0) if sel else Color.WHITE
		b.pressed.connect(_on_bag_hero_selected.bind(uid))
		bag_hero_hbox.add_child(b)

	var owned_items: Array[Dictionary] = GlobalData.get_owned_items(false, true)
	if owned_items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.text = "탐험 중 사용 가능한 포션·아이템이 없습니다. (보물 상자 또는 던전 보상으로 획득)"
		bag_items_vbox.add_child(empty_lbl)
		return

	for it in owned_items:
		var iid: String = str(it.get("id", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.text = "[%s] %s (보유 %d개)\n%s" % [
			str(it.get("rarity", "N")),
			str(it.get("name", iid)),
			int(it.get("count", 0)),
			str(it.get("description", "")),
		]
		row.add_child(lbl)

		var use_btn := Button.new()
		use_btn.custom_minimum_size = Vector2(140, 42)
		use_btn.text = "사용"
		use_btn.pressed.connect(_on_dungeon_use_item_pressed.bind(iid))
		row.add_child(use_btn)
		bag_items_vbox.add_child(row)


func _on_bag_hero_selected(uid: int) -> void:
	_bag_target_hero_uid = uid
	_refresh_bag_overlay()


func _on_calendar_button_pressed() -> void:
	if _calendar_modal != null and not _awaiting_modal:
		_calendar_modal.open_calendar()


func _on_open_bag_after_clear() -> void:
	_close_modal()
	_open_bag_overlay()


func _on_dungeon_use_item_pressed(item_id: String) -> void:
	var it: Dictionary = DataManager.get_item(item_id)
	if it.is_empty():
		return
	var itype: String = str(it.get("item_type", "HEAL_HP"))
	var pwr: float = float(it.get("power", 30.0))

	if itype == "HEAL_HP":
		var hero: Dictionary = GlobalData.get_hero_by_uid(_bag_target_hero_uid)
		if hero.is_empty():
			return
		var max_hp: int = roundi(GlobalData.get_effective_stat(hero, "max_hp"))
		if int(hero.get("hp", 0)) >= max_hp:
			bag_status_label.text = "%s은(는) 이미 최대 체력입니다." % str(hero.get("name", ""))
			bag_status_label.modulate = Color(1.0, 0.78, 0.35)
			return
		if not GlobalData.consume_item(item_id, 1):
			return
		var gained: int = GlobalData.heal_hero(_bag_target_hero_uid, int(round(pwr)))
		bag_status_label.text = "[%s] 사용! %s 체력 +%d 회복." % [str(it.get("name", "")), str(hero.get("name", "")), gained]
	elif itype == "HEAL_ALL_HP":
		if not GlobalData.consume_item(item_id, 1):
			return
		for h in GlobalData.get_active_party_heroes():
			var uid: int = int(h.get("uid", -1))
			if int(h.get("hp", 0)) > 0:
				GlobalData.heal_hero(uid, int(round(pwr)))
		bag_status_label.text = "[%s] 사용! 파티 전원 체력 +%d 회복." % [str(it.get("name", "")), int(round(pwr))]
	elif itype == "RECOVER_FATIGUE":
		if not GlobalData.consume_item(item_id, 1):
			return
		for h in GlobalData.get_active_party_heroes():
			GlobalData.recover_hero_fatigue(int(h.get("uid", -1)), int(round(pwr)))
		bag_status_label.text = "[%s] 사용! 파티 전원 피로도 -%d 감소." % [str(it.get("name", "")), int(round(pwr))]
	bag_status_label.modulate = Color(0.55, 0.95, 0.65)
	_refresh_party_hud()
	_refresh_bag_overlay()
