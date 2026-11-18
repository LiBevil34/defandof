extends Control
## 5일 주기 디펜스 데이용 실시간 디펜스 씬 (DefenseScene)
## - 로스터 중 최대 10명만 성벽 위(사거리 증가·근접 면역) 또는 성벽 밖(최대 3마리 저지)에 배치
## - 우측에서 몰려오는 몬스터 100마리를 Area2D 오브젝트 풀링으로 스폰하여 방어

signal defense_finished(victory: bool)

enum ZoneType {
	ON_WALL,
	OUTSIDE_WALL,
}

enum BattleState {
	PREPARING,
	FIGHTING,
	FINISHED,
}

const MAX_DEPLOYED_UNITS: int = 10
const MAX_BLOCK_COUNT: int = 3
const ON_WALL_RANGE_MULT: float = 1.90
const TOTAL_MONSTERS: int = 100
const POOL_SIZE: int = 100
const SPAWN_INTERVAL: float = 0.22
const SPAWN_X: float = 1820.0
const WALL_X: float = 215.0
const LANE_COUNT: int = 5
const LANE_Y_START: float = 104.0
const LANE_Y_STEP: float = 136.0

# --- 색상 팔레트 ---
const COLOR_SLOT_WALL_EMPTY := Color(0.24, 0.30, 0.42, 0.9)
const COLOR_SLOT_WALL_OCCUPIED := Color(0.22, 0.50, 0.82, 1.0)
const COLOR_SLOT_OUTSIDE_EMPTY := Color(0.22, 0.28, 0.24, 0.9)
const COLOR_SLOT_OUTSIDE_OCCUPIED := Color(0.24, 0.58, 0.36, 1.0)
const COLOR_SLOT_FLASH := Color(0.95, 0.85, 0.35, 1.0)
const COLOR_SLOT_HEAL_FLASH := Color(0.30, 0.92, 0.72, 1.0)

@onready var wall_hp_label: Label = %WallHpLabel
@onready var wave_info_label: Label = %WaveInfoLabel
@onready var deploy_count_label: Label = %DeployCountLabel
@onready var status_label: Label = %StatusLabel
@onready var auto_deploy_button: Button = %AutoDeployButton
@onready var start_wave_button: Button = %StartWaveButton
@onready var element_chart_button: Button = %ElementChartButton
@onready var auto_battle_button: Button = %AutoBattleButton
@onready var cast_ultimates_button: Button = %CastUltimatesButton
@onready var defense_item_button: Button = %DefenseItemButton
@onready var defense_item_overlay: ColorRect = %DefenseItemOverlay
@onready var defense_items_vbox: VBoxContainer = %DefenseItemsVBox
@onready var defense_item_close_button: Button = %DefenseItemCloseButton
@onready var defense_victory_overlay: ColorRect = %DefenseVictoryOverlay
@onready var defense_victory_title_label: Label = %DefenseVictoryTitleLabel
@onready var defense_victory_summary_label: Label = %DefenseVictorySummaryLabel
@onready var defense_victory_next_button: Button = %DefenseVictoryNextButton
@onready var defense_victory_stay_button: Button = %DefenseVictoryStayButton
@onready var speed_button: Button = %SpeedButton
@onready var reset_button: Button = %ResetButton
@onready var finish_phase_button: Button = %FinishPhaseButton

@onready var battlefield: Control = %Battlefield
@onready var field_bg: ColorRect = %FieldBg
@onready var wall_visual: ColorRect = %WallVisual
@onready var wall_area: Area2D = %WallArea
@onready var slots_container: Control = %SlotsContainer
@onready var monster_container: Node2D = %MonsterContainer
@onready var roster_hbox: HBoxContainer = %RosterHBox

var _battle_state: BattleState = BattleState.PREPARING
var _speed_scale: float = 1.0
var _selected_roster_id: int = -1

var _roster: Array[Dictionary] = []
var _roster_buttons: Dictionary = {}
var _slots: Array[Dictionary] = []

var _monster_pool: Array[DefenseMonster] = []
var _active_monsters: Array[DefenseMonster] = []
var _spawned_count: int = 0
var _killed_count: int = 0
var _spawn_timer: float = 0.0
var _next_monster_id: int = 1
var _base_tower_cd: float = 0.0
var _custom_tower_cds: Array[float] = [0.0, 0.0, 0.0]
var _tower_visual_nodes: Array[Node] = []
var _element_chart_overlay: ColorRect = null
var _pending_miracle_uids: Array[int] = []
var _defense_kills_by_uid: Dictionary = {}
var _defense_healed_by_uid: Dictionary = {}


func _ready() -> void:
	GlobalData.phase_changed.connect(_on_phase_changed)
	GlobalData.wall_hp_changed.connect(_on_wall_hp_changed)
	GlobalData.roster_changed.connect(_on_global_roster_changed)
	GlobalData.towers_changed.connect(_rebuild_tower_mounts)
	wall_area.area_entered.connect(_on_wall_area_entered)

	auto_deploy_button.pressed.connect(_on_auto_deploy_pressed)
	start_wave_button.pressed.connect(_on_start_wave_pressed)
	auto_battle_button.pressed.connect(_on_auto_battle_pressed)
	cast_ultimates_button.pressed.connect(_on_cast_ultimates_pressed)
	defense_item_button.pressed.connect(_on_defense_item_button_pressed)
	defense_item_close_button.pressed.connect(_close_defense_item_overlay)
	defense_victory_next_button.pressed.connect(_on_finish_phase_pressed)
	defense_victory_stay_button.pressed.connect(_close_defense_victory_overlay)
	speed_button.pressed.connect(_on_speed_pressed)
	GlobalData.battle_settings_changed.connect(_sync_battle_control_buttons)
	GlobalData.inventory_changed.connect(_sync_defense_item_button)
	reset_button.pressed.connect(_on_reset_pressed)
	finish_phase_button.pressed.connect(_on_finish_phase_pressed)

	_element_chart_overlay = CombatFeedbackUI.create_element_chart_overlay(self)
	element_chart_button.pressed.connect(_element_chart_overlay.show)

	_init_roster()
	_style_battlefield()
	_build_slots()
	_rebuild_tower_mounts()
	_init_monster_pool()
	_sync_battle_control_buttons()
	_sync_defense_item_button()
	defense_item_overlay.visible = false
	defense_victory_overlay.visible = false
	_reset_battle_state(false)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _battle_state != BattleState.FIGHTING:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R or event.keycode == KEY_3:
			_on_cast_ultimates_pressed()
			get_viewport().set_input_as_handled()


func _sync_battle_control_buttons() -> void:
	if not is_node_ready():
		return
	_speed_scale = GlobalData.battle_speed_mult
	auto_battle_button.text = "전투: %s" % GlobalData.get_auto_battle_label()
	match GlobalData.auto_battle_mode:
		GlobalData.AutoBattleMode.AUTO_SAVE_ULT:
			auto_battle_button.modulate = Color(0.55, 0.90, 1.0)
		GlobalData.AutoBattleMode.FULL_AUTO:
			auto_battle_button.modulate = Color(0.55, 1.0, 0.65)
		_:
			auto_battle_button.modulate = Color.WHITE
	speed_button.text = "배속 %s" % GlobalData.get_battle_speed_label()
	speed_button.modulate = Color(1.0, 0.85, 0.45) if GlobalData.battle_speed_mult > 1.5 else Color.WHITE


func _on_auto_battle_pressed() -> void:
	GlobalData.cycle_auto_battle_mode()


func _on_cast_ultimates_pressed() -> void:
	if _battle_state != BattleState.FIGHTING:
		return
	var triggered: int = 0
	for slot in _slots:
		if slot["unit"].is_empty() or int(slot["hp"]) <= 0:
			continue
		if float(slot.get("ult_cd_timer", 0.0)) > 0.0:
			continue
		var rarity: String = DataManager.normalize_rarity(slot.get("rarity", "N"))
		var rules: Dictionary = DataManager.get_skill_slot_rules(rarity)
		var ult_id: String = str(slot.get("ultimate_id", ""))
		if bool(rules["ultimate"]) and not ult_id.is_empty():
			var sk: Dictionary = DataManager.get_skill(ult_id)
			if not sk.is_empty():
				var target: DefenseMonster = _find_target_for_slot(slot)
				_execute_realtime_skill(slot, sk, target)
				slot["ult_cd_timer"] = maxf(6.0, float(sk.get("cooldown", 4)) * 2.5)
				triggered += 1
		elif GlobalData.auto_battle_mode == GlobalData.AutoBattleMode.MANUAL:
			var a1_id: String = str(slot.get("skill_id", ""))
			if bool(rules["active1"]) and not a1_id.is_empty() and float(slot.get("active1_cd_timer", 0.0)) <= 0.0:
				var sk1: Dictionary = DataManager.get_skill(a1_id)
				if not sk1.is_empty():
					var target1: DefenseMonster = _find_target_for_slot(slot)
					_execute_realtime_skill(slot, sk1, target1)
					slot["active1_cd_timer"] = maxf(3.0, float(sk1.get("cooldown", 2)) * 2.0)
					triggered += 1
	if triggered > 0:
		_set_status("수동 스킬/궁극기 발동! (%d명 시전)" % triggered)
	else:
		_set_status("발동 가능한 궁극기/스킬 쿨타임이 남아 있습니다.")


func _on_phase_changed(new_phase: GlobalData.GamePhase) -> void:
	if new_phase == GlobalData.GamePhase.DEFENSE:
		_init_roster()
		_reset_battle_state(false)


func _on_global_roster_changed() -> void:
	if _battle_state == BattleState.PREPARING:
		_init_roster()
		_refresh_roster_ui()


func _on_wall_hp_changed(_cur: int, _max_hp: int) -> void:
	_update_hud()


func _init_roster() -> void:
	_roster.clear()

	if not GlobalData.hero_roster.is_empty():
		for hero in GlobalData.hero_roster:
			var uid: int = int(hero.get("uid", -1))
			var eq_bonuses: Dictionary = GlobalData.get_hero_equipment_bonuses(hero)
			var temp_max_hp: int = maxi(1, roundi(GlobalData.get_hero_base_with_temperament(hero, "max_hp")))
			var base_max: int = maxi(1, temp_max_hp + roundi(float(eq_bonuses.get("max_hp", 0.0))))
			var base_cur: int = clampi(int(hero.get("hp", base_max)), 0, base_max)
			var scaled_max: int = maxi(60, base_max * 2)
			var scaled_cur: int = 0 if base_cur <= 0 else maxi(1, roundi(float(base_cur) / float(base_max) * float(scaled_max)))
			var def_zone: String = str(hero.get("defense_zone", "성벽밖"))
			var is_wall_pref: bool = (def_zone == "성벽위")
			var slot_passives: Dictionary = eq_bonuses.duplicate(true)
			slot_passives["max_hp"] = 0.0
			var temp_spd: float = GlobalData.get_hero_base_with_temperament(hero, "speed")
			var eff_spd_val: float = temp_spd + float(eq_bonuses.get("speed", 0.0))
			var hier: Dictionary = DataManager.normalize_class_hierarchy(
				str(hero.get("class_group", "")),
				str(hero.get("sub_class", hero.get("job_class", "돌격검객"))),
				str(hero.get("role_category", "전위"))
			)
			var sub_cls_info: Dictionary = DataManager.get_sub_class_info(str(hier["sub_class"]))
			_roster.append({
				"id": uid,
				"uid": uid,
				"hero_id": str(hero.get("id", "")),
				"is_named": bool(hero.get("is_named", false)),
				"portrait_path": str(hero.get("portrait_path", "")),
				"sprite_path": str(hero.get("sprite_path", "")),
				"name": str(hero.get("name", "영웅")),
				"rarity": DataManager.normalize_rarity(hero.get("rarity", "N")),
				"level": int(hero.get("level", 1)),
				"role_category": str(hier["role_category"]),
				"class_group": str(hier["class_group"]),
				"sub_class": str(hier["sub_class"]),
				"sub_trait": str(sub_cls_info.get("sub_trait", "")),
				"role": str(hier["sub_class"]),
				"defense_zone": def_zone,
				"element": str(hero.get("element", "FIRE")),
				"base_max_hp": base_max,
				"max_hp": scaled_max,
				"current_hp": scaled_cur,
				"atk": maxi(1, roundi(GlobalData.get_hero_base_with_temperament(hero, "atk"))),
				"def": maxi(0, roundi(GlobalData.get_hero_base_with_temperament(hero, "def"))),
				"heal_power": maxi(0, roundi(GlobalData.get_hero_base_with_temperament(hero, "heal_power"))),
				"dmg_bonus": GlobalData.get_hero_base_with_temperament(hero, "dmg_bonus"),
				"crit_rate": GlobalData.get_hero_base_with_temperament(hero, "crit_rate"),
				"crit_dmg": GlobalData.get_hero_base_with_temperament(hero, "crit_dmg"),
				"armor_pen": GlobalData.get_hero_base_with_temperament(hero, "armor_pen"),
				"final_dmg_mult": float(hero.get("final_dmg_mult", 1.0)),
				"is_tired": GlobalData.is_hero_tired(hero),
				"is_exhausted": GlobalData.is_hero_exhausted(hero),
				"fatigue": int(hero.get("fatigue", 0)),
				"passive_bonuses": slot_passives,
				"skill_id": str(hero.get("skill_id", "")),
				"skill2_id": str(hero.get("skill2_id", "")),
				"ultimate_id": str(hero.get("ultimate_id", "")),
				"atk_speed": clampf(eff_spd_val / 10.0, 0.8, 2.5),
				"range": 380.0 if is_wall_pref else 165.0,
			})
	else:
		# 폴백 기본 로스터 (단독 테스트 등 GlobalData 로스터가 비어 있을 때)
		_roster = [
			{"id": 1, "uid": -1, "name": "궁수 A", "role_category": "후위", "role": "원거리딜러", "defense_zone": "성벽위", "element": "LIGHTNING", "max_hp": 90, "current_hp": 90, "atk": 22, "def": 5, "heal_power": 0, "atk_speed": 1.6, "range": 240.0, "crit_rate": 0.25, "crit_dmg": 1.8, "skill_id": "skill_snipe_back"},
			{"id": 2, "uid": -1, "name": "마법사 A", "role_category": "후위", "role": "원거리딜러", "defense_zone": "성벽위", "element": "ICE", "max_hp": 80, "current_hp": 80, "atk": 34, "def": 4, "heal_power": 0, "atk_speed": 1.1, "range": 250.0, "dmg_bonus": 0.15, "skill_id": "skill_frost_nova"},
			{"id": 3, "uid": -1, "name": "사제 A", "role_category": "후위", "role": "힐러", "defense_zone": "성벽위", "element": "LIGHT", "max_hp": 90, "current_hp": 90, "atk": 10, "def": 8, "heal_power": 30, "atk_speed": 1.2, "range": 250.0, "skill_id": "skill_holy_blessing"},
			{"id": 4, "uid": -1, "name": "방패병 A", "role_category": "전위", "role": "탱커", "defense_zone": "성벽밖", "element": "EARTH", "max_hp": 260, "current_hp": 260, "atk": 14, "def": 25, "heal_power": 0, "atk_speed": 1.0, "range": 90.0, "skill_id": "skill_shield_bash"},
			{"id": 5, "uid": -1, "name": "기사 A", "role_category": "전위", "role": "근접딜러", "defense_zone": "성벽밖", "element": "FIRE", "max_hp": 220, "current_hp": 220, "atk": 24, "def": 12, "heal_power": 0, "atk_speed": 1.2, "range": 100.0, "dmg_bonus": 0.1, "skill_id": "skill_fire_slash"},
		]

	for child in roster_hbox.get_children():
		child.queue_free()
	_roster_buttons.clear()

	for member in _roster:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(204, 84)
		btn.add_theme_font_size_override("font_size", 12)
		btn.expand_icon = true
		btn.add_theme_constant_override("icon_max_width", 40)
		btn.icon = AssetManager.get_hero_portrait(member)
		btn.pressed.connect(_on_roster_button_pressed.bind(int(member["id"])))
		roster_hbox.add_child(btn)
		_roster_buttons[int(member["id"])] = btn


func _style_battlefield() -> void:
	AssetManager.apply_backdrop(field_bg, "defense_bg", Color(0.11, 0.14, 0.16), Color(0.05, 0.07, 0.09), 0.03)
	AssetManager.apply_backdrop(wall_visual, "wall_texture", Color(0.28, 0.31, 0.38), Color(0.18, 0.20, 0.26), 0.06)

	var wall_border := Panel.new()
	wall_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	wall_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall_border.add_theme_stylebox_override(
		"panel",
		AssetManager.make_panel_style(Color(0, 0, 0, 0), Color(0.62, 0.56, 0.42, 0.85), 4, 2, 0)
	)
	wall_visual.add_child(wall_border)

	# 5개 진격 레인 가이드 스트라이프
	for lane in range(LANE_COUNT):
		var cy: float = LANE_Y_START + lane * LANE_Y_STEP
		var lane_strip := ColorRect.new()
		lane_strip.position = Vector2(296.0, cy - 46.0)
		lane_strip.size = Vector2(1580.0, 92.0)
		lane_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lane_strip.color = Color(0.18, 0.21, 0.26, 0.22) if (lane % 2 == 0) else Color(0.12, 0.14, 0.18, 0.16)
		field_bg.add_child(lane_strip)


func _build_slots() -> void:
	for child in slots_container.get_children():
		child.queue_free()
	_slots.clear()

	# 성벽 위 슬롯 5개 (각 레인 1개씩, x = 215)
	for lane in range(LANE_COUNT):
		var pos := Vector2(WALL_X, LANE_Y_START + lane * LANE_Y_STEP)
		_create_slot(ZoneType.ON_WALL, lane, pos)

	# 성벽 밖 1차 저지선 5개 (x = 485)
	for lane in range(LANE_COUNT):
		var pos := Vector2(485.0, LANE_Y_START + lane * LANE_Y_STEP)
		_create_slot(ZoneType.OUTSIDE_WALL, lane, pos)

	# 성벽 밖 2차 전진 저지선 5개 (x = 755)
	for lane in range(LANE_COUNT):
		var pos := Vector2(755.0, LANE_Y_START + lane * LANE_Y_STEP)
		_create_slot(ZoneType.OUTSIDE_WALL, lane, pos)


func _create_slot(zone: ZoneType, lane: int, center_pos: Vector2) -> void:
	var slot_size := Vector2(142, 78)
	var root := Control.new()
	root.position = center_pos - slot_size * 0.5
	root.size = slot_size
	slots_container.add_child(root)

	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override(
		"panel",
		AssetManager.make_panel_style(
			COLOR_SLOT_WALL_EMPTY if zone == ZoneType.ON_WALL else COLOR_SLOT_OUTSIDE_EMPTY,
			AssetManager.COL_BORDER,
			8,
			1,
			0
		)
	)
	root.add_child(bg)

	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", 30)
	btn.add_theme_font_size_override("font_size", 11)
	root.add_child(btn)

	# 사거리 판정용 Area2D
	var range_area := Area2D.new()
	range_area.position = slot_size * 0.5
	range_area.collision_layer = 0
	range_area.collision_mask = 2
	range_area.monitoring = true
	range_area.monitorable = false
	var range_shape := CollisionShape2D.new()
	var range_circle := CircleShape2D.new()
	range_circle.radius = 100.0
	range_shape.shape = range_circle
	range_area.add_child(range_shape)
	root.add_child(range_area)

	# 성벽 밖 저지 판정용 Area2D
	var block_area: Area2D = null
	if zone == ZoneType.OUTSIDE_WALL:
		block_area = Area2D.new()
		block_area.position = slot_size * 0.5
		block_area.collision_layer = 0
		block_area.collision_mask = 2
		block_area.monitoring = true
		block_area.monitorable = false
		var block_shape := CollisionShape2D.new()
		var block_circle := CircleShape2D.new()
		block_circle.radius = 38.0
		block_shape.shape = block_circle
		block_area.add_child(block_shape)
		root.add_child(block_area)

	var slot_data: Dictionary = {
		"index": _slots.size(),
		"zone": zone,
		"lane": lane,
		"world_pos": center_pos,
		"button": btn,
		"bg": bg,
		"range_area": range_area,
		"range_circle": range_circle,
		"block_area": block_area,
		"unit": {},
		"hp": 0,
		"max_hp": 0,
		"attack_cooldown": 0.0,
		"flash_timer": 0.0,
		"heal_flash_timer": 0.0,
		"blocked_monsters": [],
	}

	btn.pressed.connect(_on_slot_pressed.bind(slot_data))
	_slots.append(slot_data)


## Area2D 몬스터 오브젝트 풀 사전 생성
func _init_monster_pool() -> void:
	for child in monster_container.get_children():
		child.queue_free()
	_monster_pool.clear()
	_active_monsters.clear()

	for _i in range(POOL_SIZE):
		var monster := DefenseMonster.new()
		monster.died.connect(_on_monster_died)
		monster_container.add_child(monster)
		monster.deactivate()
		_monster_pool.append(monster)


func _acquire_monster() -> DefenseMonster:
	if _monster_pool.is_empty():
		return null
	var monster: DefenseMonster = _monster_pool.pop_back()
	_active_monsters.append(monster)
	return monster


func _release_monster(monster: DefenseMonster) -> void:
	if not monster.blocked_by_slot.is_empty():
		var slot: Dictionary = monster.blocked_by_slot
		var blocked: Array = slot["blocked_monsters"]
		blocked.erase(monster)
	monster.deactivate()
	_active_monsters.erase(monster)
	if not _monster_pool.has(monster):
		_monster_pool.append(monster)


func _reset_battle_state(restore_wall: bool) -> void:
	_battle_state = BattleState.PREPARING
	_spawned_count = 0
	_killed_count = 0
	_spawn_timer = 0.0
	_next_monster_id = 1
	_base_tower_cd = 0.0
	_custom_tower_cds = [0.0, 0.0, 0.0]
	_selected_roster_id = -1
	_pending_miracle_uids.clear()
	_defense_kills_by_uid.clear()
	_defense_healed_by_uid.clear()
	_rebuild_tower_mounts()
	defense_victory_overlay.visible = false
	defense_item_overlay.visible = false

	if restore_wall or GlobalData.wall_hp <= 0:
		GlobalData.repair_wall(GlobalData.wall_max_hp)

	for monster in _active_monsters.duplicate():
		_release_monster(monster)

	for slot in _slots:
		_clear_slot(slot)

	start_wave_button.disabled = false
	auto_deploy_button.disabled = false
	finish_phase_button.disabled = true
	var note_parts: PackedStringArray = []
	if TimeManager.is_final_battle_day():
		note_parts.append("★ [3년차 최종 결전] 최후의 대공세! 이 방어전을 막아내면 영지 수호 최종 승리!")
	if GlobalData.outpost_weakened_stacks > 0:
		note_parts.append("전초기지 약화 x%d (적 %d마리)" % [GlobalData.outpost_weakened_stacks, _get_wave_total_monsters()])
	if GlobalData.defense_wall_atk_bonus > 0:
		note_parts.append("성벽 화력 +%d" % GlobalData.defense_wall_atk_bonus)
	if not GlobalData.upcoming_defense_elements.is_empty():
		note_parts.append("예상 적 속성: [%s]" % GlobalData.get_upcoming_defense_elements_text())
	note_parts.append(str(TimeManager.get_season_enemy_multipliers().get("trait_label", "")))
	var extra_note: String = "  |  " + ", ".join(note_parts) if not note_parts.is_empty() else ""
	_set_status("로스터에서 유닛을 선택 후 성벽 위(사거리↑·근접면역) 또는 성벽 밖(3저지)에 최대 10명 배치하세요." + extra_note)
	_refresh_all_ui()


func _get_wave_total_monsters() -> int:
	return maxi(40, TOTAL_MONSTERS - GlobalData.outpost_weakened_stacks * 15)


func _get_deployed_count() -> int:
	var count: int = 0
	for slot in _slots:
		if not slot["unit"].is_empty():
			count += 1
	return count


func _is_roster_member_deployed(roster_id: int) -> bool:
	for slot in _slots:
		var unit: Dictionary = slot["unit"]
		if not unit.is_empty() and int(unit["id"]) == roster_id:
			return true
	return false


func _on_roster_button_pressed(roster_id: int) -> void:
	if _battle_state == BattleState.FINISHED:
		return
	var member := _find_roster_member(roster_id)
	if not member.is_empty() and int(member.get("current_hp", 1)) <= 0:
		_set_status("[%s]은(는) 전투불능 상태입니다. 마을 관리에서 치료 후 배치하세요." % member["name"])
		return
	if not member.is_empty() and bool(member.get("is_exhausted", false)):
		_set_status("[%s]은(는) 탈진 상태(피로도 100)라 디펜스에 출전할 수 없습니다." % member["name"])
		return
	if _is_roster_member_deployed(roster_id):
		_set_status("이미 전장에 배치된 유닛입니다. 배치된 슬롯을 클릭하면 회수됩니다.")
		return
	_selected_roster_id = roster_id
	_refresh_roster_ui()


func _on_slot_pressed(slot: Dictionary) -> void:
	if _battle_state == BattleState.FINISHED:
		return

	# 이미 배치된 슬롯 클릭 시 회수
	if not slot["unit"].is_empty():
		var removed_name: String = slot["unit"]["name"]
		_clear_slot(slot)
		_set_status("[%s] 배치 해제되었습니다." % removed_name)
		_refresh_all_ui()
		return

	if _selected_roster_id == -1:
		_set_status("먼저 하단 로스터에서 배치할 유닛을 선택하세요.")
		return

	if _get_deployed_count() >= MAX_DEPLOYED_UNITS:
		_set_status("최대 %d명까지만 배치할 수 있습니다! 기존 유닛을 회수 후 배치하세요." % MAX_DEPLOYED_UNITS)
		return

	var member := _find_roster_member(_selected_roster_id)
	if member.is_empty() or _is_roster_member_deployed(_selected_roster_id):
		return

	_deploy_unit_to_slot(member, slot)
	_selected_roster_id = -1
	_refresh_all_ui()


func _find_roster_member(roster_id: int) -> Dictionary:
	for m in _roster:
		if int(m["id"]) == roster_id:
			return m
	return {}


func _deploy_unit_to_slot(member: Dictionary, slot: Dictionary) -> void:
	slot["unit"] = member
	slot["name"] = str(member["name"])
	slot["class_group"] = str(member.get("class_group", DataManager.get_class_group_for_sub_class(str(member.get("role", "근접딜러")))))
	slot["sub_class"] = str(member.get("sub_class", member.get("role", "돌격검객")))
	slot["sub_trait"] = str(member.get("sub_trait", ""))
	slot["_duration_ext"] = 2.0
	slot["max_block"] = MAX_BLOCK_COUNT + (1 if str(slot["class_group"]) == "중장" else 0)
	slot["element"] = str(member.get("element", "FIRE"))
	slot["max_hp"] = int(member["max_hp"])
	slot["hp"] = clampi(int(member.get("current_hp", member["max_hp"])), 1, int(member["max_hp"]))
	slot["atk"] = int(member.get("atk", 15)) + (GlobalData.defense_wall_atk_bonus if slot["zone"] == ZoneType.ON_WALL else 0)
	slot["def"] = int(member.get("def", 10))
	slot["speed"] = float(member.get("atk_speed", 1.0)) * 10.0
	slot["is_tired"] = bool(member.get("is_tired", false))
	slot["dmg_bonus"] = float(member.get("dmg_bonus", 0.0))
	slot["crit_rate"] = float(member.get("crit_rate", 0.05))
	slot["crit_dmg"] = float(member.get("crit_dmg", 1.5))
	slot["armor_pen"] = float(member.get("armor_pen", 0.0))
	slot["final_dmg_mult"] = float(member.get("final_dmg_mult", 1.0))
	slot["crit_gauge"] = 0.0
	slot["rarity"] = DataManager.normalize_rarity(member.get("rarity", "N"))
	slot["skill_id"] = str(member.get("skill_id", ""))
	slot["skill2_id"] = str(member.get("skill2_id", ""))
	slot["ultimate_id"] = str(member.get("ultimate_id", ""))
	slot["skill_rotation_idx"] = 0
	slot["attack_count"] = 0
	slot["active1_cd_timer"] = 0.0
	slot["active2_cd_timer"] = 0.0
	slot["ult_cd_timer"] = 0.0
	slot["shield"] = 0
	slot["status_effects"] = []
	slot["passive_bonuses"] = (member.get("passive_bonuses", {}) as Dictionary).duplicate(true)
	slot["attack_cooldown"] = 0.0
	slot["flash_timer"] = 0.0
	slot["heal_flash_timer"] = 0.0
	slot["_miracle_revived"] = false
	slot["blocked_monsters"] = []

	var base_range: float = float(member["range"])
	var final_range: float = (
		base_range * ON_WALL_RANGE_MULT
		if slot["zone"] == ZoneType.ON_WALL
		else base_range
	)
	if slot["zone"] == ZoneType.ON_WALL and str(slot["class_group"]) == "저격":
		final_range *= 1.15
	var circle: CircleShape2D = slot["range_circle"]
	circle.radius = final_range

	var zone_str: String = "성벽 위(사거리 %.0f, 근접면역)" % final_range if slot["zone"] == ZoneType.ON_WALL else "성벽 밖(최대 %d저지)" % int(slot["max_block"])
	_set_status("[%s] → %s 배치 완료!" % [member["name"], zone_str])


func _clear_slot(slot: Dictionary) -> void:
	var blocked: Array = slot["blocked_monsters"]
	for monster in blocked.duplicate():
		if is_instance_valid(monster):
			monster.blocked_by_slot = {}
	blocked.clear()

	slot["unit"] = {}
	slot["hp"] = 0
	slot["max_hp"] = 0
	slot["shield"] = 0
	slot["status_effects"] = []
	slot["attack_count"] = 0
	slot["attack_cooldown"] = 0.0
	slot["flash_timer"] = 0.0
	slot["heal_flash_timer"] = 0.0


func _on_auto_deploy_pressed() -> void:
	if _battle_state == BattleState.FINISHED:
		return

	for slot in _slots:
		_clear_slot(slot)

	var wall_candidates: Array[Dictionary] = []
	var outside_candidates: Array[Dictionary] = []
	for member in _roster:
		if int(member.get("current_hp", member.get("max_hp", 1))) <= 0 or bool(member.get("is_exhausted", false)):
			continue
		if str(member.get("defense_zone", "")) == "성벽위" or DataManager.normalize_role_category(str(member.get("role_category", "")), str(member.get("role", ""))) == "후위":
			wall_candidates.append(member)
		else:
			outside_candidates.append(member)

	var deployed_total: int = 0
	for lane in range(LANE_COUNT):
		if wall_candidates.is_empty() or deployed_total >= MAX_DEPLOYED_UNITS:
			break
		_deploy_unit_to_slot(wall_candidates.pop_front(), _slots[lane])
		deployed_total += 1

	for lane in range(LANE_COUNT):
		if outside_candidates.is_empty() or deployed_total >= MAX_DEPLOYED_UNITS:
			break
		_deploy_unit_to_slot(outside_candidates.pop_front(), _slots[LANE_COUNT + lane])
		deployed_total += 1

	# 남은 빈 슬롯에 여유 인원 보충
	var leftovers: Array[Dictionary] = []
	leftovers.append_array(wall_candidates)
	leftovers.append_array(outside_candidates)
	for slot in _slots:
		if leftovers.is_empty() or deployed_total >= MAX_DEPLOYED_UNITS:
			break
		if slot["unit"].is_empty():
			_deploy_unit_to_slot(leftovers.pop_front(), slot)
			deployed_total += 1

	_selected_roster_id = -1
	_set_status("자동 배치 완료! (총 %d명 배치)" % deployed_total)
	_refresh_all_ui()


func _on_start_wave_pressed() -> void:
	if _battle_state != BattleState.PREPARING:
		return
	if _get_deployed_count() == 0:
		_set_status("최소 1명 이상 배치해야 웨이브를 시작할 수 있습니다!")
		return

	_battle_state = BattleState.FIGHTING
	start_wave_button.disabled = true

	var deployed_slots: Array[Dictionary] = []
	for s in _slots:
		if not s["unit"].is_empty() and int(s["hp"]) > 0:
			deployed_slots.append(s)
	for s in deployed_slots:
		var uid: int = int(s["unit"].get("uid", -1))
		if uid > 0:
			var h_data: Dictionary = GlobalData.get_hero_by_uid(uid)
			if not h_data.is_empty():
				GlobalData.apply_equipment_passives_to_combat_unit(h_data, s, deployed_slots)

	var wave_total: int = _get_wave_total_monsters()
	_set_status("웨이브 시작! 몬스터 %d마리가 우측에서 진격합니다!" % wave_total)
	_refresh_all_ui()


func _on_speed_pressed() -> void:
	GlobalData.cycle_battle_speed()


func _on_reset_pressed() -> void:
	_reset_battle_state(true)


func _on_finish_phase_pressed() -> void:
	if _battle_state != BattleState.FINISHED:
		return
	if GlobalData.current_phase == GlobalData.GamePhase.DEFENSE:
		TimeManager.advance_phase()


func _physics_process(delta: float) -> void:
	if _battle_state != BattleState.FIGHTING:
		return

	var sim_dt: float = delta * _speed_scale

	_process_spawning(sim_dt)
	_process_monsters(sim_dt)
	_process_towers(sim_dt)
	_process_units(sim_dt)
	_check_battle_end()
	_update_hud()
	_refresh_slots_ui()


func _rebuild_tower_mounts() -> void:
	for n in _tower_visual_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_tower_visual_nodes.clear()

	var base_stats: Dictionary = GlobalData.get_base_tower_stats()
	var base_panel := Panel.new()
	base_panel.position = Vector2(18, 285)
	base_panel.size = Vector2(84, 92)
	base_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_panel.add_theme_stylebox_override("panel", AssetManager.make_panel_style(Color(0.20, 0.30, 0.42, 0.96), AssetManager.COL_BORDER_GOLD, 8, 2, 4))
	var base_vb := VBoxContainer.new()
	base_vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	base_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	base_panel.add_child(base_vb)
	var base_icon := TextureRect.new()
	base_icon.custom_minimum_size = Vector2(34, 34)
	base_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	base_icon.texture = AssetManager.get_tower_sprite("base_tower")
	base_icon.modulate = Color(0.85, 0.92, 1.0)
	base_vb.add_child(base_icon)
	var base_lbl := Label.new()
	base_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	base_lbl.add_theme_font_size_override("font_size", 11)
	base_lbl.text = "기본포탑\nATK %d" % int(base_stats["atk"])
	base_vb.add_child(base_lbl)
	slots_container.add_child(base_panel)
	_tower_visual_nodes.append(base_panel)

	var mount_ys: Array[float] = [100.0, 420.0, 580.0]
	for idx in range(GlobalData.MAX_TOWER_SLOTS):
		var tid: String = GlobalData.equipped_tower_slots[idx] if idx < GlobalData.equipped_tower_slots.size() else ""
		var t_tpl: Dictionary = DataManager.get_tower(tid) if not tid.is_empty() else {}
		var mount_rect := Panel.new()
		mount_rect.position = Vector2(18, mount_ys[idx])
		mount_rect.size = Vector2(84, 78)
		mount_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		mount_rect.add_child(vb)
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 10)
		if t_tpl.is_empty():
			mount_rect.add_theme_stylebox_override("panel", AssetManager.make_panel_style(Color(0.14, 0.16, 0.21, 0.88), AssetManager.COL_BORDER, 8, 1, 4))
			lbl.text = "타워%d\n(빈슬롯)" % (idx + 1)
		else:
			var t_col: Color = DataManager.get_element_color(str(t_tpl.get("element", "FIRE")))
			mount_rect.add_theme_stylebox_override("panel", AssetManager.make_panel_style(t_col.darkened(0.55), t_col, 8, 2, 4))
			var t_icon := TextureRect.new()
			t_icon.custom_minimum_size = Vector2(28, 28)
			t_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t_icon.texture = AssetManager.get_tower_sprite(tid, str(t_tpl.get("sprite_path", "")))
			t_icon.modulate = t_col.lightened(0.35)
			vb.add_child(t_icon)
			lbl.text = "%s\n(%s)" % [str(t_tpl.get("name", "타워")).left(4), str(t_tpl.get("target_scope", "SINGLE_FRONT")).left(4)]
		vb.add_child(lbl)
		slots_container.add_child(mount_rect)
		_tower_visual_nodes.append(mount_rect)


func _get_tower_haste_cooldown_mult() -> float:
	var haste: float = float(GlobalData.get_party_exploration_bonuses().get("tower_haste_bonus", 0.0))
	for s in _slots:
		if not s["unit"].is_empty() and int(s["hp"]) > 0:
			var st: String = str(s.get("sub_trait", ""))
			if st == "TOWER_HASTE" or st == "WALL_GUARD":
				haste = maxf(haste, 0.20)
	return 1.0 / (1.0 + haste)


func _process_towers(sim_dt: float) -> void:
	var tower_cd_mult: float = _get_tower_haste_cooldown_mult()
	# 1) 성벽 기본 포탑 자동 공격
	_base_tower_cd -= sim_dt
	if _base_tower_cd <= 0.0:
		var base_stats: Dictionary = GlobalData.get_base_tower_stats()
		var target := _find_closest_monster_in_range(Vector2(WALL_X, 376.0), 540.0)
		if target != null:
			_base_tower_cd = float(base_stats["attack_interval"]) * tower_cd_mult
			var dummy_caster: Dictionary = {
				"name": "성벽 기본 타워",
				"atk": int(base_stats["atk"]),
				"element": "EARTH",
				"dmg_bonus": 0.0,
				"crit_rate": 0.05,
				"crit_dmg": 1.5,
				"armor_pen": 0.1,
				"final_dmg_mult": 1.0,
				"status_effects": [],
				"passive_bonuses": {},
			}
			var calc: Dictionary = CombatCalculator.calculate_skill_damage(dummy_caster, target.combat_state, {"multiplier": 1.0})
			var base_dmg: int = int(calc["damage"])
			target.take_damage(base_dmg)
			_spawn_defense_damage_float(target.position, base_dmg, bool(calc.get("is_crit", false)), float(calc.get("element_multiplier", 1.0)))

	# 2) 커스텀 타워 3슬롯 자동 공격 (단일/광역 + on_hit_effect_id)
	var mount_ys: Array[float] = [140.0, 460.0, 620.0]
	for idx in range(GlobalData.MAX_TOWER_SLOTS):
		var tid: String = GlobalData.equipped_tower_slots[idx] if idx < GlobalData.equipped_tower_slots.size() else ""
		if tid.is_empty():
			continue
		var t_tpl: Dictionary = DataManager.get_tower(tid)
		if t_tpl.is_empty():
			continue
		_custom_tower_cds[idx] -= sim_dt
		if _custom_tower_cds[idx] > 0.0:
			continue

		var anchor_m := _find_closest_monster_in_range(Vector2(WALL_X, mount_ys[idx]), 960.0)
		if anchor_m == null:
			continue

		_custom_tower_cds[idx] = float(t_tpl.get("attack_interval", 1.5)) * tower_cd_mult
		var t_scope: String = str(t_tpl.get("target_scope", "SINGLE_FRONT"))
		var targets: Array[DefenseMonster] = _get_monsters_in_defense_scope(t_scope, anchor_m)
		var tower_caster: Dictionary = {
			"name": str(t_tpl.get("name", "타워")),
			"atk": int(t_tpl.get("atk", 20)),
			"element": str(t_tpl.get("element", "FIRE")),
			"dmg_bonus": 0.0,
			"crit_rate": 0.10,
			"crit_dmg": 1.5,
			"armor_pen": 0.15,
			"final_dmg_mult": 1.0,
			"status_effects": [],
			"passive_bonuses": {},
		}
		var on_hit_id: String = str(t_tpl.get("on_hit_effect_id", ""))
		var on_hit_skill: Dictionary = DataManager.get_skill(on_hit_id) if not on_hit_id.is_empty() else {}
		for m in targets:
			if not m.is_active or m.hp <= 0:
				continue
			var calc: Dictionary = CombatCalculator.calculate_skill_damage(tower_caster, m.combat_state, {"multiplier": 1.0})
			var t_dmg: int = int(calc["damage"])
			m.take_damage(t_dmg)
			_spawn_defense_damage_float(m.position, t_dmg, bool(calc.get("is_crit", false)), float(calc.get("element_multiplier", 1.0)))
			if m.is_active and m.hp > 0 and not on_hit_skill.is_empty():
				for eff in on_hit_skill.get("effects", []):
					StatusEffectManager.apply_effect(
						m.combat_state,
						str(eff.get("effect_type", "SLOW")),
						float(eff.get("multiplier", 0.3)),
						float(eff.get("duration", 2.0)),
						tower_caster
					)


func _find_closest_monster_in_range(origin: Vector2, max_range: float) -> DefenseMonster:
	var best: DefenseMonster = null
	var best_x: float = INF
	for m in _active_monsters:
		if not m.is_active or m.hp <= 0:
			continue
		if m.position.distance_to(origin) <= max_range and m.position.x < best_x:
			best_x = m.position.x
			best = m
	return best


func _get_monsters_in_defense_scope(scope: String, anchor: DefenseMonster, slot_range_area: Area2D = null) -> Array[DefenseMonster]:
	var out: Array[DefenseMonster] = []
	match scope:
		"ALL_ENEMIES":
			for m in _active_monsters:
				if m.is_active and m.hp > 0:
					out.append(m)
		"AOE_LARGE":
			var center_l: Vector2 = anchor.position if anchor != null else Vector2(680, 376)
			for m in _active_monsters:
				if m.is_active and m.hp > 0 and m.position.distance_to(center_l) <= 290.0:
					out.append(m)
		"AOE_SMALL", "CROSS", "SQUARE_2X2":
			var center_s: Vector2 = anchor.position if anchor != null else Vector2(520, 376)
			for m in _active_monsters:
				if m.is_active and m.hp > 0 and m.position.distance_to(center_s) <= 155.0:
					out.append(m)
		"ROW", "COLUMN":
			if slot_range_area != null:
				for area in slot_range_area.get_overlapping_areas():
					if area is DefenseMonster and area.is_active and area.hp > 0:
						out.append(area)
			elif anchor != null:
				for m in _active_monsters:
					if m.is_active and m.hp > 0 and m.lane_index == anchor.lane_index:
						out.append(m)
		_:
			if anchor != null and anchor.is_active and anchor.hp > 0:
				out.append(anchor)
	return out


func _process_spawning(sim_dt: float) -> void:
	var wave_total: int = _get_wave_total_monsters()
	if _spawned_count >= wave_total:
		return

	var weaken_mult: float = maxf(0.55, 1.0 - float(GlobalData.outpost_weakened_stacks) * 0.12)
	var season_key: String = TimeManager.get_season_key()
	var s_mults: Dictionary = TimeManager.get_season_enemy_multipliers()
	var hp_mult: float = float(s_mults.get("hp", 1.0))
	var atk_mult: float = float(s_mults.get("atk", 1.0))
	var def_mult: float = float(s_mults.get("def", 1.0))
	var spd_mult: float = float(s_mults.get("speed", 1.0))
	var season_bonus_eff: String = str(s_mults.get("bonus_effect", ""))

	_spawn_timer -= sim_dt
	while _spawn_timer <= 0.0 and _spawned_count < wave_total:
		var monster: DefenseMonster = _acquire_monster()
		if monster == null:
			_spawn_timer = 0.05
			break

		var lane: int = _spawned_count % LANE_COUNT
		var spawn_pos := Vector2(SPAWN_X, LANE_Y_START + lane * LANE_Y_STEP)

		var idx_1: int = _spawned_count + 1
		var target_type: String = "NORMAL"
		if idx_1 == wave_total:
			target_type = "BOSS"
		elif idx_1 % 20 == 0:
			target_type = "SIEGE"
		elif idx_1 % 5 == 0:
			target_type = "ELITE"

		var candidates: Array[Dictionary] = DataManager.get_enemies_for_context(season_key, target_type, GlobalData.upcoming_defense_elements, GlobalData.is_rebellion_humanoid_preferred())
		var m_hp: int = 55
		var m_spd: float = 95.0
		var m_atk: int = 7
		var m_def: int = 5
		var m_elem: String = "FIRE"
		var m_enemy_id: String = ""
		var m_sprite_path: String = ""
		var m_category: String = "MONSTER"
		var m_archetype: String = "SWARMER"
		var m_tint: String = ""
		var m_pal_swap: bool = false
		var passive_ids: Array = []

		if not candidates.is_empty():
			var tpl: Dictionary = candidates[_spawned_count % candidates.size()]
			m_enemy_id = str(tpl.get("id", ""))
			m_sprite_path = str(tpl.get("sprite_path", ""))
			m_category = str(tpl.get("category", "MONSTER"))
			m_archetype = str(tpl.get("archetype", "SWARMER"))
			m_tint = str(tpl.get("tint_color", ""))
			m_pal_swap = bool(tpl.get("palette_swapped", false))
			m_hp = maxi(15, roundi(float(tpl.get("max_hp", 55)) * 1.1 * hp_mult * weaken_mult))
			m_atk = maxi(3, roundi(float(tpl.get("atk", 10)) * 0.65 * atk_mult * weaken_mult))
			m_def = maxi(0, roundi(float(tpl.get("def", 6)) * def_mult))
			m_spd = clampf(float(tpl.get("speed", 12)) * 7.2 * spd_mult, 55.0, 145.0)
			if m_archetype == "CUTTHROAT":
				m_spd = minf(165.0, m_spd * 1.18)
			m_elem = str(tpl.get("element", "FIRE"))
			passive_ids = tpl.get("passive_skill_ids", [])
		else:
			var is_elite: bool = (target_type != "NORMAL")
			m_hp = maxi(15, roundi(float(115 if is_elite else 55) * hp_mult * weaken_mult))
			m_spd = (68.0 if is_elite else 95.0) * spd_mult
			m_atk = maxi(3, roundi(float(12 if is_elite else 7) * atk_mult * weaken_mult))
			m_def = roundi(float(12 if is_elite else 5) * def_mult)
			var elem_ids: PackedStringArray = DataManager.get_element_ids()
			if not GlobalData.upcoming_defense_elements.is_empty():
				m_elem = GlobalData.upcoming_defense_elements[_spawned_count % GlobalData.upcoming_defense_elements.size()]
			elif not elem_ids.is_empty():
				m_elem = elem_ids[_spawned_count % elem_ids.size()]

		var m_color: Color = DataManager.get_element_color(m_elem)
		if target_type != "NORMAL":
			m_color = m_color.darkened(0.25)

		monster.activate(_next_monster_id, spawn_pos, lane, m_hp, m_spd, m_atk, m_color, m_def, m_elem, m_enemy_id, target_type, m_sprite_path, m_category, m_archetype, m_tint, m_pal_swap, false)
		monster.combat_state["season_bonus_effect"] = season_bonus_eff
		for pid in passive_ids:
			var psk := DataManager.get_skill(str(pid))
			for eff in psk.get("effects", []):
				StatusEffectManager.apply_effect(
					monster.combat_state,
					str(eff.get("effect_type", "")),
					float(eff.get("multiplier", 0.0)),
					999.0,
					monster.combat_state
				)
		if m_archetype == "VOLATILE" and not StatusEffectManager.has_effect(monster.combat_state, "EXPLODE_ON_DEATH"):
			StatusEffectManager.apply_effect(monster.combat_state, "EXPLODE_ON_DEATH", 1.6, 999.0, monster.combat_state)
		elif m_archetype == "THORNBACK" and not StatusEffectManager.has_effect(monster.combat_state, "REFLECT"):
			StatusEffectManager.apply_effect(monster.combat_state, "REFLECT", 0.25, 999.0, monster.combat_state)
		elif m_archetype == "PHALANX" and StatusEffectManager.get_total_shield(monster.combat_state) <= 0:
			StatusEffectManager.apply_effect(monster.combat_state, "SHIELD", 0.8, 999.0, monster.combat_state)
		_next_monster_id += 1
		_spawned_count += 1
		_spawn_timer += SPAWN_INTERVAL


func _process_monsters(sim_dt: float) -> void:
	for monster in _active_monsters.duplicate():
		if not monster.is_active:
			continue

		# 실시간 1초 DoT(화상/독) 및 상태이상 지속시간 틱 처리
		var prev_dot_hp: int = monster.hp
		StatusEffectManager.tick_realtime_effects(monster.combat_state, sim_dt)
		monster.sync_hp_from_combat_state()
		var dot_delta: int = prev_dot_hp - monster.hp
		if dot_delta > 0:
			_spawn_defense_damage_float(monster.position, dot_delta, false, 1.0, true)
		if not monster.is_active or monster.hp <= 0:
			continue

		if StatusEffectManager.is_stunned(monster.combat_state):
			continue

		var spd_factor: float = StatusEffectManager.get_speed_factor(monster.combat_state)

		# PREACHER 아키타입: 주변 아군 적 주기적 회복 + 공격력 버프 오라
		if monster.archetype == "PREACHER":
			monster.support_aura_cd -= sim_dt * spd_factor
			if monster.support_aura_cd <= 0.0:
				monster.support_aura_cd = 3.5
				var healed_any: bool = false
				for mate in _active_monsters:
					if not mate.is_active or mate.hp <= 0:
						continue
					if mate.position.distance_to(monster.position) <= 240.0:
						StatusEffectManager.apply_effect(mate.combat_state, "BUFF_ATK", 0.15, 2.5, monster.combat_state)
						if mate.hp < mate.max_hp:
							var h_val: int = maxi(8, roundi(float(monster.atk) * 0.7))
							mate.hp = mini(mate.max_hp, mate.hp + h_val)
							mate.combat_state["hp"] = mate.hp
							mate._update_hp_bar()
							healed_any = true
				if healed_any:
					_spawn_defense_text(monster.position, "교단 치유·축복!", "HEAL")

		# 저지 중이던 유닛이 회수/사망했으면 저지 해제
		if not monster.blocked_by_slot.is_empty():
			var blocker: Dictionary = monster.blocked_by_slot
			if blocker["unit"].is_empty() or int(blocker["hp"]) <= 0:
				monster.blocked_by_slot = {}

		if monster.blocked_by_slot.is_empty() and not monster.reached_wall:
			monster.position.x -= monster.move_speed * spd_factor * sim_dt
			_try_block_monster(monster)

		if not monster.blocked_by_slot.is_empty():
			# 성벽 밖 유닛과 근접 교전
			var blocker_slot: Dictionary = monster.blocked_by_slot
			monster.attack_cooldown -= sim_dt * spd_factor
			if monster.attack_cooldown <= 0.0:
				monster.attack_cooldown = monster.attack_interval
				_damage_deployed_unit(blocker_slot, monster)
		elif monster.reached_wall:
			if monster.archetype == "VOLATILE":
				# VOLATILE 성벽 접촉 즉시 자폭
				var wall_boom: int = maxi(8, roundi(float(monster.atk) * 1.6))
				GlobalData.damage_wall(wall_boom)
				_spawn_defense_text(Vector2(WALL_X + 12.0, monster.position.y), "자폭! -%d" % wall_boom, "CRIT")
				monster.take_damage(monster.max_hp + 999)
				continue
			# 성벽 공격 (SIEGE_CREW는 2.5배 공성 피해!)
			monster.attack_cooldown -= sim_dt * spd_factor
			if monster.attack_cooldown <= 0.0:
				monster.attack_cooldown = monster.attack_interval
				var wall_dmg: int = roundi(float(monster.atk) * 2.5) if monster.archetype == "SIEGE_CREW" else monster.atk
				GlobalData.damage_wall(wall_dmg)
				if monster.archetype == "SIEGE_CREW":
					_spawn_defense_text(Vector2(WALL_X + 12.0, monster.position.y), "공성2.5x -%d" % wall_dmg, "CRIT")
				else:
					_spawn_defense_damage_float(Vector2(WALL_X + 12.0, monster.position.y), wall_dmg)


func _try_block_monster(monster: DefenseMonster) -> void:
	for slot in _slots:
		if slot["zone"] != ZoneType.OUTSIDE_WALL:
			continue
		if slot["unit"].is_empty() or int(slot["hp"]) <= 0:
			continue
		var blocked: Array = slot["blocked_monsters"]
		var slot_max_block: int = int(slot.get("max_block", MAX_BLOCK_COUNT))
		if blocked.size() >= slot_max_block:
			continue

		var block_area: Area2D = slot["block_area"]
		if block_area.get_overlapping_areas().has(monster):
			monster.blocked_by_slot = slot
			blocked.append(monster)
			if monster.archetype == "VOLATILE":
				var contact_dmg: int = maxi(4, roundi(float(monster.atk) * 0.6))
				StatusEffectManager.apply_damage_with_shield(slot, contact_dmg)
				_spawn_defense_text(slot["world_pos"], "접촉 폭발 -%d" % contact_dmg, "CRIT")
				if int(slot["hp"]) <= 0 and not _try_slot_miracle_survival(slot):
					_sync_slot_hp_to_global(slot, 0)
					_clear_slot(slot)
					_refresh_roster_ui()
			return


func _try_slot_miracle_survival(slot: Dictionary) -> bool:
	if slot.is_empty() or slot["unit"].is_empty() or int(slot.get("hp", 0)) > 0:
		return false
	if bool(slot.get("_miracle_revived", false)):
		return false
	var unit: Dictionary = slot["unit"]
	var uid: int = int(unit.get("uid", -1))
	if not GlobalData.roll_miracle_survival(uid):
		return false
	slot["_miracle_revived"] = true
	var rev_hp: int = maxi(1, roundi(float(slot.get("max_hp", 60)) * 0.15))
	slot["hp"] = rev_hp
	if uid > 0 and not _pending_miracle_uids.has(uid):
		_pending_miracle_uids.append(uid)
	_spawn_defense_text(slot["world_pos"], "★ 기적적 생환! (+%d HP)" % rev_hp, "CRIT")
	_set_status("★ [기적적 생환!] [%s]이(가) 죽음의 문턱에서 HP %d로 다시 일어섰습니다!" % [str(unit.get("name", "영웅")), rev_hp])
	return true


func _damage_deployed_unit(slot: Dictionary, attacker_monster: DefenseMonster) -> void:
	# 성벽 위 유닛은 근접 면역
	if slot["zone"] == ZoneType.ON_WALL:
		return
	if slot["unit"].is_empty():
		return

	var calc_u: Dictionary = CombatCalculator.calculate_skill_damage(attacker_monster.combat_state, slot, {"multiplier": 1.0})
	var dmg: int = int(calc_u["damage"])
	var hit_res_u: Dictionary = StatusEffectManager.apply_damage_with_shield(slot, dmg)
	_spawn_defense_damage_float(slot["world_pos"], dmg, bool(calc_u.get("is_crit", false)), float(calc_u.get("element_multiplier", 1.0)))
	if int(hit_res_u.get("shield_absorbed", 0)) > 0:
		_spawn_defense_text(slot["world_pos"] + Vector2(0, -18), "보호막 -%d" % int(hit_res_u["shield_absorbed"]), "SHIELD")
	var s_bonus_eff: String = str(attacker_monster.combat_state.get("season_bonus_effect", ""))
	if not s_bonus_eff.is_empty() and int(slot["hp"]) > 0:
		StatusEffectManager.apply_effect(slot, s_bonus_eff, 0.20, 2.0, attacker_monster.combat_state)
	if int(slot["hp"]) <= 0:
		if not _try_slot_miracle_survival(slot):
			var fallen_name: String = slot["unit"]["name"]
			_sync_slot_hp_to_global(slot, 0)
			_clear_slot(slot)
			_set_status("[전사] 성벽 밖의 [%s]이(가) 쓰러져 저지가 해제되었습니다!" % fallen_name)
			_refresh_roster_ui()


func _process_units(sim_dt: float) -> void:
	for slot in _slots:
		if slot["unit"].is_empty() or int(slot["hp"]) <= 0:
			continue

		StatusEffectManager.tick_realtime_effects(slot, sim_dt)
		if int(slot["hp"]) <= 0:
			if not _try_slot_miracle_survival(slot):
				_sync_slot_hp_to_global(slot, 0)
				_clear_slot(slot)
				_refresh_roster_ui()
				continue

		if float(slot["flash_timer"]) > 0.0:
			slot["flash_timer"] = maxf(0.0, float(slot["flash_timer"]) - sim_dt)
		if float(slot["heal_flash_timer"]) > 0.0:
			slot["heal_flash_timer"] = maxf(0.0, float(slot["heal_flash_timer"]) - sim_dt)
		for cd_key in ["active1_cd_timer", "active2_cd_timer", "ult_cd_timer"]:
			if float(slot.get(cd_key, 0.0)) > 0.0:
				slot[cd_key] = maxf(0.0, float(slot[cd_key]) - sim_dt)

		if StatusEffectManager.is_stunned(slot):
			continue

		var spd_factor: float = StatusEffectManager.get_speed_factor(slot)
		slot["attack_cooldown"] = maxf(0.0, float(slot["attack_cooldown"]) - sim_dt * spd_factor)
		if float(slot["attack_cooldown"]) > 0.0:
			continue

		var unit: Dictionary = slot["unit"]
		var heal_power: int = int(unit.get("heal_power", 0))
		var is_healer: bool = (str(slot.get("class_group", "")) == "의료" or str(unit.get("role", "")) == "힐러" or heal_power > 0)

		if is_healer:
			var injured_slot: Dictionary = _find_injured_ally_in_range(slot)
			if not injured_slot.is_empty():
				var heal_amount: int = heal_power if heal_power > 0 else maxi(10, roundi(StatusEffectManager.get_effective_stat(slot, "atk")))
				if str(slot.get("sub_trait", "")) == "EMERGENCY_HEAL" and float(injured_slot["hp"]) / maxf(1.0, float(injured_slot["max_hp"])) <= 0.40:
					heal_amount = roundi(float(heal_amount) * 1.40)
				var healed_rt: int = heal_deployed_slot(injured_slot, heal_amount)
				var h_uid: int = int(unit.get("uid", -1))
				if h_uid > 0 and healed_rt > 0:
					_defense_healed_by_uid[h_uid] = int(_defense_healed_by_uid.get(h_uid, 0)) + healed_rt
				if str(slot.get("class_group", "")) == "의료":
					StatusEffectManager.apply_effect(injured_slot, "DMG_REDUCE", 0.10, 2.0, slot)
				if str(slot.get("sub_trait", "")) == "WARD_PURIFY":
					StatusEffectManager.clear_debuffs(injured_slot)
				slot["attack_cooldown"] = 1.0 / float(unit["atk_speed"])
				slot["heal_flash_timer"] = 0.14
				slot["attack_count"] = int(slot.get("attack_count", 0)) + 1
				_maybe_cast_realtime_skill(slot, null)
				continue

		var target: DefenseMonster = _find_target_for_slot(slot)
		if target == null:
			continue

		slot["attack_cooldown"] = 1.0 / float(unit["atk_speed"])
		slot["flash_timer"] = 0.10
		slot["attack_count"] = int(slot.get("attack_count", 0)) + 1

		if not _maybe_cast_realtime_skill(slot, target):
			var calc: Dictionary = CombatCalculator.calculate_skill_damage(slot, target.combat_state, {"multiplier": 1.0})
			var hit_dmg: int = int(calc["damage"])
			target.take_damage(hit_dmg)
			if target.hp <= 0:
				var k_uid: int = int(unit.get("uid", -1))
				if k_uid > 0:
					_defense_kills_by_uid[k_uid] = int(_defense_kills_by_uid.get(k_uid, 0)) + 1
				if str(slot.get("class_group", "")) == "근위":
					StatusEffectManager.apply_effect(slot, "BUFF_SPEED", 0.15, 3.0, slot)
			_spawn_defense_damage_float(target.position, hit_dmg, bool(calc.get("is_crit", false)), float(calc.get("element_multiplier", 1.0)))
			_apply_monster_reflect_to_slot(slot, target, hit_dmg)


func _maybe_cast_realtime_skill(slot: Dictionary, primary_target: DefenseMonster) -> bool:
	if GlobalData.auto_battle_mode == GlobalData.AutoBattleMode.MANUAL:
		return false
	if int(slot.get("attack_count", 0)) % 4 != 0:
		return false

	var rarity: String = DataManager.normalize_rarity(slot.get("rarity", "N"))
	var rules: Dictionary = DataManager.get_skill_slot_rules(rarity)
	var ready_actives: Array[Dictionary] = []
	if bool(rules["active1"]) and not str(slot.get("skill_id", "")).is_empty() and float(slot.get("active1_cd_timer", 0.0)) <= 0.0:
		var s1 := DataManager.get_skill(str(slot["skill_id"]))
		if not s1.is_empty():
			ready_actives.append({"slot": "active1", "cd_key": "active1_cd_timer", "skill": s1})
	if bool(rules["active2"]) and not str(slot.get("skill2_id", "")).is_empty() and float(slot.get("active2_cd_timer", 0.0)) <= 0.0:
		var s2 := DataManager.get_skill(str(slot["skill2_id"]))
		if not s2.is_empty():
			ready_actives.append({"slot": "active2", "cd_key": "active2_cd_timer", "skill": s2})

	# 아군 HP 비율 파악 (긴급 케어 <= 40% / 힐 아끼기 >= 85%)
	var lowest_ratio: float = 2.0
	var all_healthy_85: bool = true
	for a_slot in _slots:
		if a_slot["unit"].is_empty() or int(a_slot["hp"]) <= 0:
			continue
		var r: float = float(a_slot["hp"]) / maxf(1.0, float(a_slot["max_hp"]))
		if r < 0.85:
			all_healthy_85 = false
		if r < lowest_ratio:
			lowest_ratio = r

	# 1) 긴급 케어 (체력 40% 이하 아군 -> HEAL/SHIELD 액티브 우선)
	if lowest_ratio <= 0.40:
		for entry in ready_actives:
			var sk: Dictionary = entry["skill"]
			for eff in sk.get("effects", []):
				var et := str(eff.get("effect_type", ""))
				if et == "HEAL" or et == "SHIELD":
					slot[entry["cd_key"]] = maxf(2.0, float(sk.get("cooldown", 2)) * 1.5)
					return _execute_realtime_skill(slot, sk, primary_target)

	# 2) 미적용 디버프 (STUN, SLOW, DEF_DOWN 없는 적 우선)
	if primary_target != null and primary_target.is_active and primary_target.hp > 0:
		var debuffs := PackedStringArray(["STUN", "SLOW", "DEF_DOWN"])
		for entry in ready_actives:
			var sk: Dictionary = entry["skill"]
			for eff in sk.get("effects", []):
				var et := str(eff.get("effect_type", ""))
				if debuffs.has(et) and not StatusEffectManager.has_effect(primary_target.combat_state, et):
					slot[entry["cd_key"]] = maxf(2.0, float(sk.get("cooldown", 2)) * 1.5)
					return _execute_realtime_skill(slot, sk, primary_target)

	# 4) 궁극기 ([완전 자동]일 때만 즉시 발동)
	if GlobalData.auto_battle_mode == GlobalData.AutoBattleMode.FULL_AUTO and bool(rules["ultimate"]) and not str(slot.get("ultimate_id", "")).is_empty() and float(slot.get("ult_cd_timer", 0.0)) <= 0.0:
		var ult_sk := DataManager.get_skill(str(slot["ultimate_id"]))
		if not ult_sk.is_empty():
			slot["ult_cd_timer"] = maxf(5.0, float(ult_sk.get("cooldown", 4)) * 2.0)
			return _execute_realtime_skill(slot, ult_sk, primary_target)

	# 3) 고계수 공격 액티브 우선
	var best_entry: Dictionary = {}
	var best_mult: float = -1.0
	for entry in ready_actives:
		var sk: Dictionary = entry["skill"]
		var is_pure_heal: bool = true
		var max_dmg_m: float = 0.0
		for eff in sk.get("effects", []):
			if str(eff.get("effect_type", "")) == "DAMAGE":
				is_pure_heal = false
				max_dmg_m = maxf(max_dmg_m, float(eff.get("multiplier", 1.0)))
			elif str(eff.get("effect_type", "")) != "HEAL":
				is_pure_heal = false
		if all_healthy_85 and is_pure_heal:
			continue
		if max_dmg_m > best_mult:
			best_mult = max_dmg_m
			best_entry = entry

	if not best_entry.is_empty():
		var chosen_sk: Dictionary = best_entry["skill"]
		slot[best_entry["cd_key"]] = maxf(2.0, float(chosen_sk.get("cooldown", 2)) * 1.5)
		return _execute_realtime_skill(slot, chosen_sk, primary_target)
	return false


func _execute_realtime_skill(slot: Dictionary, skill: Dictionary, primary_target: DefenseMonster) -> bool:
	var effects: Array = skill.get("effects", [])
	var dealt_skill_damage: bool = false
	for eff in effects:
		var eff_type: String = str(eff.get("effect_type", "DAMAGE"))
		var scope: String = str(eff.get("target_scope", "SINGLE_FRONT"))
		var mult: float = float(eff.get("multiplier", 1.0))
		var dur: float = float(eff.get("duration", 2))

		if scope == "SELF":
			if eff_type == "HEAL":
				heal_deployed_slot(slot, maxi(1, roundi(StatusEffectManager.get_effective_stat(slot, "atk") * mult)))
			else:
				var self_eff: Dictionary = StatusEffectManager.apply_effect(slot, eff_type, mult, dur, slot)
				if eff_type == "SHIELD" and int(self_eff.get("value", 0)) > 0:
					_spawn_defense_text(slot["world_pos"], "보호막 +%d" % int(self_eff["value"]), "SHIELD")
		elif scope == "SINGLE_ALLY" or scope == "ALL_ALLIES":
			var ally_candidates: Array[Dictionary] = []
			for ally_slot in _slots:
				if not ally_slot["unit"].is_empty() and int(ally_slot["hp"]) > 0:
					ally_candidates.append(ally_slot)
			ally_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return float(a["hp"]) / maxf(1.0, float(a["max_hp"])) < float(b["hp"]) / maxf(1.0, float(b["max_hp"]))
			)
			for ally_slot in ally_candidates:
				if eff_type == "HEAL":
					var h_base: float = float(ally_slot["unit"].get("heal_power", 0))
					var amt: int = maxi(10, roundi((h_base if h_base > 0.0 else StatusEffectManager.get_effective_stat(slot, "atk")) * mult))
					if str(slot.get("sub_trait", "")) == "EMERGENCY_HEAL" and float(ally_slot["hp"]) / maxf(1.0, float(ally_slot["max_hp"])) <= 0.40:
						amt = roundi(float(amt) * 1.40)
					var healed_sk: int = heal_deployed_slot(ally_slot, amt)
					var s_huid: int = int(slot["unit"].get("uid", -1))
					if s_huid > 0 and healed_sk > 0:
						_defense_healed_by_uid[s_huid] = int(_defense_healed_by_uid.get(s_huid, 0)) + healed_sk
					if str(slot.get("class_group", "")) == "의료":
						StatusEffectManager.apply_effect(ally_slot, "DMG_REDUCE", 0.10, 2.0, slot)
					if str(slot.get("sub_trait", "")) == "WARD_PURIFY":
						StatusEffectManager.clear_debuffs(ally_slot)
				else:
					var ally_eff: Dictionary = StatusEffectManager.apply_effect(ally_slot, eff_type, mult, dur, slot)
					if eff_type == "SHIELD" and int(ally_eff.get("value", 0)) > 0:
						_spawn_defense_text(ally_slot["world_pos"], "보호막 +%d" % int(ally_eff["value"]), "SHIELD")
				if scope == "SINGLE_ALLY":
					break
		else:
			var targets: Array[DefenseMonster] = _get_monsters_in_defense_scope(scope, primary_target, slot["range_area"])

			for m in targets:
				if not m.is_active or m.hp <= 0:
					continue
				if eff_type == "DAMAGE":
					var calc: Dictionary = CombatCalculator.calculate_skill_damage(slot, m.combat_state, eff)
					var hit_dmg: int = int(calc["damage"])
					m.take_damage(hit_dmg)
					if m.hp <= 0:
						var sk_uid: int = int(slot["unit"].get("uid", -1))
						if sk_uid > 0:
							_defense_kills_by_uid[sk_uid] = int(_defense_kills_by_uid.get(sk_uid, 0)) + 1
					_spawn_defense_damage_float(m.position, hit_dmg, bool(calc.get("is_crit", false)), float(calc.get("element_multiplier", 1.0)))
					_apply_monster_reflect_to_slot(slot, m, hit_dmg)
					dealt_skill_damage = true
				else:
					StatusEffectManager.apply_effect(m.combat_state, eff_type, mult, dur, slot)
	return dealt_skill_damage


func _apply_monster_reflect_to_slot(attacker_slot: Dictionary, victim: DefenseMonster, hit_dmg: int) -> void:
	if attacker_slot["zone"] == ZoneType.ON_WALL or attacker_slot["unit"].is_empty() or int(attacker_slot["hp"]) <= 0:
		return
	var reflect_ratio: float = StatusEffectManager.get_effect_value(victim.combat_state, "REFLECT")
	if reflect_ratio > 0.0 and hit_dmg > 0:
		var ref_dmg: int = maxi(1, roundi(float(hit_dmg) * reflect_ratio))
		StatusEffectManager.apply_damage_with_shield(attacker_slot, ref_dmg)
		_spawn_defense_damage_float(attacker_slot["world_pos"], ref_dmg, false, 1.0, true)
		if int(attacker_slot["hp"]) <= 0:
			if not _try_slot_miracle_survival(attacker_slot):
				_sync_slot_hp_to_global(attacker_slot, 0)
				_clear_slot(attacker_slot)
				_refresh_roster_ui()


func _spawn_defense_text(world_pos: Vector2, text: String, kind: String = "NORMAL") -> void:
	if battlefield == null or not is_instance_valid(battlefield):
		return
	CombatFeedbackUI.spawn_floating_text(battlefield, world_pos + Vector2(0.0, -34.0), text, kind, _speed_scale)


func _spawn_defense_damage_float(world_pos: Vector2, dmg: int, is_crit: bool = false, elem_mult: float = 1.0, is_dot: bool = false) -> void:
	var info: Dictionary = CombatFeedbackUI.classify_damage_display(dmg, is_crit, elem_mult, is_dot)
	_spawn_defense_text(world_pos, str(info["text"]), str(info["kind"]))


func heal_deployed_slot(target_slot: Dictionary, amount: int) -> int:
	if target_slot.is_empty() or target_slot["unit"].is_empty() or amount <= 0:
		return 0
	var cur_hp: int = int(target_slot["hp"])
	var max_hp: int = int(target_slot["max_hp"])
	if cur_hp <= 0 or cur_hp >= max_hp:
		return 0
	var new_hp: int = mini(max_hp, cur_hp + amount)
	target_slot["hp"] = new_hp
	target_slot["heal_flash_timer"] = 0.16
	var healed: int = new_hp - cur_hp
	if healed > 0:
		_spawn_defense_text(target_slot["world_pos"], "+%d" % healed, "HEAL")
	return healed


func _find_injured_ally_in_range(healer_slot: Dictionary) -> Dictionary:
	var healer_pos: Vector2 = healer_slot["world_pos"]
	var range_circle: CircleShape2D = healer_slot["range_circle"]
	var max_dist: float = range_circle.radius

	var best_slot: Dictionary = {}
	var lowest_ratio: float = 1.0
	for candidate in _slots:
		if candidate["unit"].is_empty():
			continue
		var cur_hp: int = int(candidate["hp"])
		var max_hp: int = int(candidate["max_hp"])
		if cur_hp <= 0 or cur_hp >= max_hp:
			continue
		if healer_pos.distance_to(candidate["world_pos"]) > max_dist:
			continue
		var ratio: float = float(cur_hp) / float(max_hp)
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			best_slot = candidate
	return best_slot


func _find_target_for_slot(slot: Dictionary) -> DefenseMonster:
	var use_smart: bool = (GlobalData.auto_battle_mode != GlobalData.AutoBattleMode.MANUAL)

	# 1순위: 자신이 저지 중인 몬스터
	var blocked: Array = slot["blocked_monsters"]
	var valid_blocked: Array[DefenseMonster] = []
	for m in blocked:
		if is_instance_valid(m) and m.is_active and m.hp > 0:
			valid_blocked.append(m)
	if not valid_blocked.is_empty():
		if not use_smart:
			return valid_blocked[0]
		return _pick_smart_defense_monster(slot, valid_blocked)

	# 2순위: 사거리(Area2D) 내 몬스터 (자동 모드면 스마트 타겟팅, 수동 모드면 가장 왼쪽 우선)
	var range_area: Area2D = slot["range_area"]
	var in_range: Array[DefenseMonster] = []
	var best: DefenseMonster = null
	var best_x: float = INF
	for area in range_area.get_overlapping_areas():
		if area is DefenseMonster:
			var monster: DefenseMonster = area
			if monster.is_active and monster.hp > 0:
				in_range.append(monster)
				if monster.position.x < best_x:
					best_x = monster.position.x
					best = monster
	if use_smart and not in_range.is_empty():
		return _pick_smart_defense_monster(slot, in_range)
	return best


func _pick_smart_defense_monster(slot: Dictionary, monsters: Array[DefenseMonster]) -> DefenseMonster:
	var best_m: DefenseMonster = monsters[0]
	var best_score: float = -99999.0
	for m in monsters:
		var res: Dictionary = CombatCalculator.score_smart_target(slot, m.combat_state, {"multiplier": 1.0})
		var sc: float = float(res["score"])
		if sc > best_score:
			best_score = sc
			best_m = m
	return best_m


func _on_wall_area_entered(area: Area2D) -> void:
	if area is DefenseMonster:
		var monster: DefenseMonster = area
		if monster.is_active and monster.blocked_by_slot.is_empty():
			monster.reached_wall = true


func _on_monster_died(monster: DefenseMonster) -> void:
	if not monster.is_active:
		return
	# 자폭 패시브(EXPLODE_ON_DEATH) 처리
	var exp_mult: float = StatusEffectManager.get_effect_value(monster.combat_state, "EXPLODE_ON_DEATH")
	if exp_mult > 0.0:
		var exp_dmg: int = maxi(4, roundi(float(monster.atk) * exp_mult))
		for s in _slots:
			if s["zone"] == ZoneType.OUTSIDE_WALL and not s["unit"].is_empty() and int(s["hp"]) > 0:
				if (s["world_pos"] as Vector2).distance_to(monster.position) <= 130.0:
					StatusEffectManager.apply_damage_with_shield(s, exp_dmg)
					_spawn_defense_damage_float(s["world_pos"], exp_dmg, true, 1.0)
					if int(s["hp"]) <= 0:
						_sync_slot_hp_to_global(s, 0)
						_clear_slot(s)
						_refresh_roster_ui()

	# BROODMOTHER 아키타입: 사망 시 소형 군집 유충 2기 분열 소환
	if monster.archetype == "BROODMOTHER" and not monster.is_summoned_spawn:
		var m_hp_sub: int = maxi(12, roundi(float(monster.max_hp) * 0.30))
		var m_atk_sub: int = maxi(4, roundi(float(monster.atk) * 0.55))
		var m_spd_sub: float = minf(160.0, monster.move_speed * 1.25)
		var m_col_sub: Color = DataManager.get_element_color(monster.element)
		for offset_y in [-24.0, 24.0]:
			var spawn_m: DefenseMonster = _acquire_monster()
			if spawn_m == null:
				break
			var sp_pos := Vector2(monster.position.x + 18.0, clampf(monster.position.y + offset_y, 80.0, 680.0))
			spawn_m.activate(_next_monster_id, sp_pos, monster.lane_index, m_hp_sub, m_spd_sub, m_atk_sub, m_col_sub, 3, monster.element, "enemy_feral_swarmer", "NORMAL", "", "MONSTER", "SWARMER", "", false, true)
			_next_monster_id += 1
		_spawn_defense_text(monster.position, "군체 분열!", "CRIT")

	_killed_count += 1
	_release_monster(monster)


func stop_battle() -> void:
	_battle_state = BattleState.FINISHED
	auto_deploy_button.disabled = true


func _finalize_defense_service_and_traumas(victory: bool) -> PackedStringArray:
	var report_logs: PackedStringArray = []
	var processed_uids: Dictionary = {}

	for uid in _pending_miracle_uids:
		var hero: Dictionary = GlobalData.get_hero_by_uid(uid)
		if hero.is_empty():
			continue
		var neg_id: String = GlobalData.grant_random_negative_temperament(uid)
		if not neg_id.is_empty():
			var neg_name: String = str(GlobalData.get_temperament_info(neg_id).get("name", neg_id))
			report_logs.append("★ [기적적 생환] %s이(가) 죽음에서 돌아왔으나, 후유증 [%s] 기질을 얻었습니다!" % [str(hero.get("name", "영웅")), neg_name])

	for slot in _slots:
		if slot["unit"].is_empty():
			continue
		var uid: int = int(slot["unit"].get("uid", -1))
		if uid <= 0 or processed_uids.has(uid):
			continue
		processed_uids[uid] = true
		var survived_def: int = 1 if (victory and int(slot.get("hp", 0)) > 0) else 0
		var was_miracle: int = 1 if _pending_miracle_uids.has(uid) else 0
		var unlocked: Array[String] = GlobalData.record_hero_service(uid, {
			"defenses_survived": survived_def,
			"battles_fought": 1,
			"total_kills": int(_defense_kills_by_uid.get(uid, 0)),
			"total_healed": int(_defense_healed_by_uid.get(uid, 0)),
			"near_deaths": was_miracle,
		})
		for vid in unlocked:
			var vinfo: Dictionary = GlobalData.get_temperament_info(vid)
			report_logs.append("• [실전 습관 해금] %s → [%s] (%s)" % [
				str(slot["unit"].get("name", "영웅")),
				str(vinfo.get("name", vid)),
				str(vinfo.get("summary", "")),
			])

	# 생환 후 슬롯에서 쓰러졌거나 킬/힐 기록이 남은 나머지 영웅 이력 반영
	for uid in _pending_miracle_uids:
		if processed_uids.has(uid):
			continue
		processed_uids[uid] = true
		var hero_m: Dictionary = GlobalData.get_hero_by_uid(uid)
		var unlocked_m: Array[String] = GlobalData.record_hero_service(uid, {
			"battles_fought": 1,
			"total_kills": int(_defense_kills_by_uid.get(uid, 0)),
			"total_healed": int(_defense_healed_by_uid.get(uid, 0)),
			"near_deaths": 1,
		})
		for vid in unlocked_m:
			var vinfo_m: Dictionary = GlobalData.get_temperament_info(vid)
			report_logs.append("• [실전 습관 해금] %s → [%s] (%s)" % [
				str(hero_m.get("name", "영웅")),
				str(vinfo_m.get("name", vid)),
				str(vinfo_m.get("summary", "")),
			])

	_pending_miracle_uids.clear()
	return report_logs


func _check_battle_end() -> void:
	var wave_total: int = _get_wave_total_monsters()
	if GlobalData.wall_hp <= 0:
		_battle_state = BattleState.FINISHED
		_sync_all_slots_hp_to_global()
		var lose_svc: PackedStringArray = _finalize_defense_service_and_traumas(false)
		GlobalData.outpost_weakened_stacks = 0
		GlobalData.defense_wall_atk_bonus = 0
		var lose_str: String = "패배... 성벽이 붕괴되었습니다! (처치: %d / %d)" % [_killed_count, wave_total]
		if not lose_svc.is_empty():
			lose_str += "  |  " + " / ".join(lose_svc)
		_set_status(lose_str)
		finish_phase_button.disabled = false
		auto_deploy_button.disabled = true
		defense_finished.emit(false)
		return

	if _spawned_count >= wave_total and _active_monsters.is_empty():
		_battle_state = BattleState.FINISHED
		_sync_all_slots_hp_to_global()
		var win_svc: PackedStringArray = _finalize_defense_service_and_traumas(true)
		GlobalData.outpost_weakened_stacks = 0
		GlobalData.defense_wall_atk_bonus = 0
		GlobalData.clear_field_dungeon_state()
		GlobalData.apply_deltas({"gold": 80, "materials": 30})
		GlobalData.record_defense_won()
		var is_final_victory: bool = TimeManager.is_final_battle_day()
		var status_str: String = "디펜스 승리! 몬스터 %d마리를 모두 막아냈습니다! (보상: 골드 +80, 자재 +30 / 다음 평일 던전 맵 초기화)" % wave_total
		if not win_svc.is_empty():
			status_str += "  |  " + " / ".join(win_svc)
		_set_status(status_str)
		finish_phase_button.disabled = false
		auto_deploy_button.disabled = true
		defense_item_overlay.visible = false
		var cleared_wave: int = GlobalData.defense_wave
		GlobalData.defense_wave += 1
		defense_victory_title_label.text = "★ 제%d차 성벽 디펜스 승리!" % cleared_wave
		var svc_note: String = ("\n\n" + "\n".join(win_svc)) if not win_svc.is_empty() else ""
		defense_victory_summary_label.text = (
			"공성 웨이브(%d마리)를 완전히 격퇴했습니다!\n\n"
			+ "남은 성벽 내구도: %d / %d\n"
			+ "방어 보상: 골드 +80, 자재 +30\n"
			+ "(다음 평일 던전 지형이 새롭게 생성됩니다)%s"
		) % [wave_total, GlobalData.wall_hp, GlobalData.wall_max_hp, svc_note]
		defense_victory_overlay.visible = not is_final_victory
		defense_finished.emit(true)


func _sync_all_slots_hp_to_global() -> void:
	for slot in _slots:
		if not slot["unit"].is_empty():
			_sync_slot_hp_to_global(slot, int(slot.get("hp", 0)))


func _sync_slot_hp_to_global(slot: Dictionary, slot_hp: int) -> void:
	var unit: Dictionary = slot.get("unit", {})
	var uid: int = int(unit.get("uid", -1))
	if uid <= 0:
		return
	var hero: Dictionary = GlobalData.get_hero_by_uid(uid)
	if hero.is_empty():
		return
	var slot_max: int = maxi(1, int(slot.get("max_hp", unit.get("max_hp", 1))))
	var base_max: int = maxi(1, roundi(GlobalData.get_effective_stat(hero, "max_hp")))
	if slot_hp <= 0:
		GlobalData.set_hero_hp(uid, 0)
	else:
		var scaled: int = maxi(1, roundi(float(slot_hp) / float(slot_max) * float(base_max)))
		GlobalData.set_hero_hp(uid, mini(base_max, scaled))


func _refresh_all_ui() -> void:
	_update_hud()
	_refresh_slots_ui()
	_refresh_roster_ui()


func _update_hud() -> void:
	var wave_total: int = _get_wave_total_monsters()
	wall_hp_label.text = "성벽 HP: %d / %d" % [GlobalData.wall_hp, GlobalData.wall_max_hp]
	wave_info_label.text = "스폰: %d/%d  |  처치: %d/%d  |  활성: %d (풀 대기: %d)" % [
		_spawned_count,
		wave_total,
		_killed_count,
		wave_total,
		_active_monsters.size(),
		_monster_pool.size(),
	]
	deploy_count_label.text = "배치 인원: %d / %d명" % [_get_deployed_count(), MAX_DEPLOYED_UNITS]


func _refresh_slots_ui() -> void:
	for slot in _slots:
		var btn: Button = slot["button"]
		var bg: Panel = slot["bg"]
		var unit: Dictionary = slot["unit"]
		var is_wall: bool = (slot["zone"] == ZoneType.ON_WALL)

		if unit.is_empty():
			btn.text = "성벽 위\n(사거리↑/면역)" if is_wall else "성벽 밖\n(최대 3저지)"
			btn.icon = null
			var empty_col: Color = COLOR_SLOT_WALL_EMPTY if is_wall else COLOR_SLOT_OUTSIDE_EMPTY
			bg.add_theme_stylebox_override("panel", AssetManager.make_panel_style(empty_col, Color(0.28, 0.34, 0.44, 0.7), 8, 1, 0))
			continue

		btn.icon = AssetManager.get_hero_sprite(unit)
		var flash: bool = float(slot["flash_timer"]) > 0.0
		var heal_flash: bool = float(slot["heal_flash_timer"]) > 0.0
		var fill_col: Color
		var border_col: Color = DataManager.get_rarity_color(DataManager.normalize_rarity(unit.get("rarity", "N")))
		if heal_flash:
			fill_col = COLOR_SLOT_HEAL_FLASH.darkened(0.2)
			border_col = Color(0.45, 1.0, 0.80)
		elif flash:
			fill_col = COLOR_SLOT_FLASH.darkened(0.25)
			border_col = Color(1.0, 0.90, 0.40)
		else:
			fill_col = (COLOR_SLOT_WALL_OCCUPIED if is_wall else COLOR_SLOT_OUTSIDE_OCCUPIED).darkened(0.25)
		bg.add_theme_stylebox_override("panel", AssetManager.make_panel_style(fill_col, border_col, 8, 2 if bool(unit.get("is_named", false)) else 1, 0))

		var heal_power: int = int(unit.get("heal_power", 0))
		var eff_atk: int = roundi(StatusEffectManager.get_effective_stat(slot, "atk"))
		var shield_val: int = StatusEffectManager.get_total_shield(slot)
		var shield_txt: String = " (+%d)" % shield_val if shield_val > 0 else ""
		if is_wall:
			var is_med: bool = (str(slot.get("class_group", "")) == "의료" or str(unit.get("role", "")) == "힐러")
			var stat_str: String = "HEAL %d" % heal_power if is_med else "ATK %d" % eff_atk
			btn.text = "%s\n[근접면역]\n%s" % [unit["name"], stat_str]
		else:
			var blocked_cnt: int = (slot["blocked_monsters"] as Array).size()
			var max_blk: int = int(slot.get("max_block", MAX_BLOCK_COUNT))
			btn.text = "%s\nHP %d/%d%s\n저지 %d/%d" % [
				unit["name"],
				slot["hp"],
				slot["max_hp"],
				shield_txt,
				blocked_cnt,
				max_blk,
			]


func _refresh_roster_ui() -> void:
	for member in _roster:
		var r_id: int = int(member["id"])
		var btn: Button = _roster_buttons[r_id]
		var deployed: bool = _is_roster_member_deployed(r_id)
		var selected: bool = (_selected_roster_id == r_id)
		var is_down: bool = int(member.get("current_hp", 1)) <= 0
		var is_exhausted: bool = bool(member.get("is_exhausted", false))
		var is_tired: bool = bool(member.get("is_tired", false))

		var tag: String = ""
		if is_down:
			tag = " [전투불능]"
		elif is_exhausted:
			tag = " [탈진]"
		elif deployed:
			tag = " [배치됨]"
		elif selected:
			tag = " [선택됨]"
		elif is_tired:
			tag = " [지침]"

		var stat_text: String = "HEAL %d" % member["heal_power"] if str(member.get("role", "")) == "힐러" else "ATK %d" % member["atk"]
		var rarity: String = DataManager.normalize_rarity(member.get("rarity", "N"))
		var lv_prefix: String = "Lv.%d " % int(member.get("level", 1)) if int(member.get("level", 1)) > 1 else ""
		btn.text = "[%s] %s%s%s\n%s·%s %s" % [
			rarity,
			lv_prefix,
			member["name"],
			tag,
			member.get("role_category", "전위"),
			member["role"],
			stat_text,
		]
		btn.disabled = deployed or is_down or is_exhausted
		btn.modulate = Color(1.0, 0.9, 0.45) if selected else Color.WHITE


func _set_status(msg: String) -> void:
	status_label.text = msg


# ==========================================
# 디펜스 전술 아이템 / 포션 사용
# ==========================================
func _sync_defense_item_button() -> void:
	if not is_node_ready():
		return
	var combat_items: Array[Dictionary] = GlobalData.get_owned_items(true, false)
	defense_item_button.disabled = combat_items.is_empty()
	defense_item_button.text = "아이템 (%d종)" % combat_items.size() if not combat_items.is_empty() else "아이템 (없음)"


func _on_defense_item_button_pressed() -> void:
	if _battle_state == BattleState.FINISHED:
		return
	_refresh_defense_item_overlay()
	defense_item_overlay.visible = true


func _close_defense_item_overlay() -> void:
	defense_item_overlay.visible = false


func _close_defense_victory_overlay() -> void:
	defense_victory_overlay.visible = false


func _refresh_defense_item_overlay() -> void:
	for child in defense_items_vbox.get_children():
		child.queue_free()

	var owned: Array[Dictionary] = GlobalData.get_owned_items(true, false)
	if owned.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "전투 중 사용할 수 있는 아이템이 없습니다."
		defense_items_vbox.add_child(empty_lbl)
		return

	for it in owned:
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
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(120, 40)
		btn.text = "사용"
		btn.pressed.connect(_on_defense_use_item_pressed.bind(iid))
		row.add_child(btn)
		defense_items_vbox.add_child(row)


func _on_defense_use_item_pressed(item_id: String) -> void:
	var item: Dictionary = DataManager.get_item(item_id)
	if item.is_empty():
		return
	var itype: String = str(item.get("item_type", "HEAL_HP"))
	var pwr: float = float(item.get("power", 30.0))
	var dur_sec: float = float(maxi(1, int(item.get("duration", 3)))) * 3.0
	var iname: String = str(item.get("name", item_id))

	if itype == "DAMAGE_ENEMY":
		var living_monsters: Array[DefenseMonster] = []
		for m in _active_monsters:
			if m.is_active and m.hp > 0:
				living_monsters.append(m)
		if living_monsters.is_empty():
			_set_status("현재 전장에 활성화된 적이 없어 [%s]을(를) 사용할 수 없습니다." % iname)
			return
		if not GlobalData.consume_item(item_id, 1):
			return
		var dmg_amt: int = maxi(1, int(round(pwr)))
		for m in living_monsters:
			m.take_damage(dmg_amt)
			_spawn_defense_damage_float(m.position, dmg_amt)
		_set_status("[아이템: %s] 활성 적 %d마리에게 %d 화염 폭격 피해!" % [iname, living_monsters.size(), dmg_amt])
	else:
		var deployed_slots: Array[Dictionary] = []
		for s in _slots:
			if not s["unit"].is_empty() and int(s["hp"]) > 0:
				deployed_slots.append(s)
		if deployed_slots.is_empty():
			_set_status("배치된 살아있는 아군 영웅이 없어 [%s]을(를) 사용할 수 없습니다." % iname)
			return
		if not GlobalData.consume_item(item_id, 1):
			return

		match itype:
			"HEAL_HP":
				var best_slot: Dictionary = deployed_slots[0]
				var best_ratio: float = 999.0
				for s in deployed_slots:
					var ratio: float = float(s["hp"]) / maxf(1.0, float(s["max_hp"]))
					if ratio < best_ratio:
						best_ratio = ratio
						best_slot = s
				heal_deployed_slot(best_slot, int(round(pwr)))
				if str(item.get("rarity", "N")) != "N":
					StatusEffectManager.clear_debuffs(best_slot)
				_set_status("[아이템: %s] %s 체력 +%d 회복!" % [iname, str(best_slot["name"]), int(round(pwr))])
			"HEAL_ALL_HP":
				for s in deployed_slots:
					heal_deployed_slot(s, int(round(pwr)))
				_set_status("[아이템: %s] 배치된 아군 전원(%d명) 체력 +%d 회복!" % [iname, deployed_slots.size(), int(round(pwr))])
			"BUFF_ATK", "BUFF_DEF":
				for s in deployed_slots:
					StatusEffectManager.apply_effect(s, itype, pwr, dur_sec, s)
				_set_status("[아이템: %s] 아군 전원 %s +%.0f%% (%.0f초)!" % [iname, StatusEffectManager.get_effect_label(itype), pwr * 100.0, dur_sec])
			"SHIELD_ALL":
				for s in deployed_slots:
					StatusEffectManager.clear_debuffs(s)
					var sh_amt: int = int(round(pwr))
					StatusEffectManager.add_flat_shield(s, sh_amt, dur_sec, iname)
					_spawn_defense_text(s["world_pos"], "보호막 +%d" % sh_amt, "SHIELD")
				_set_status("[아이템: %s] 아군 전원 상태이상 정화 및 보호막 +%d!" % [iname, int(round(pwr))])
			"CLEANSE":
				for s in deployed_slots:
					StatusEffectManager.clear_debuffs(s)
					heal_deployed_slot(s, int(round(pwr)))
				_set_status("[아이템: %s] 배치된 아군 전원 상태이상 정화 완료!" % iname)

	defense_item_overlay.visible = false
	_sync_defense_item_button()
