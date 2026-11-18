extends Control
## 오펜스(DUNGEON) 페이즈용 3x3 그리드 턴제 전투 프로토타입
## - 아군/적군 각 3x3(전열/중위/후열) 배치
## - 속도(Speed) 순 행동 큐 및 열 붕괴(Rank Collapse) 타겟팅
## - CombatCalculator(확정 데미지), StatusEffectManager(버프/디버프/DoT/CC/보호막), 조립식 스킬(skills.json) 연동

signal battle_finished(victory: bool)
signal map_return_requested(victory: bool, is_boss: bool)

@export var embedded_in_map: bool = false

enum Team {
	ALLY,
	ENEMY,
}

enum Rank {
	FRONT = 0,
	MIDDLE = 1,
	BACK = 2,
}

const RANK_NAMES: Dictionary = {
	Rank.FRONT: "전열",
	Rank.MIDDLE: "중열",
	Rank.BACK: "후열",
}

const GRID_ROWS: int = 3
const GRID_COLS: int = 3

# --- 색상 팔레트 (ColorRect용) ---
const COLOR_EMPTY_SLOT := Color(0.14, 0.15, 0.18, 1.0)
const COLOR_ALLY_NORMAL := Color(0.18, 0.36, 0.62, 1.0)
const COLOR_ALLY_HEALABLE := Color(0.18, 0.58, 0.42, 1.0)
const COLOR_ENEMY_NORMAL := Color(0.50, 0.20, 0.22, 1.0)
const COLOR_ENEMY_TARGETABLE := Color(0.78, 0.24, 0.22, 1.0)
const COLOR_ENEMY_SKILL_TARGET := Color(0.86, 0.42, 0.16, 1.0)
const COLOR_ENEMY_BLOCKED := Color(0.28, 0.16, 0.18, 1.0)
const COLOR_ACTIVE_TURN := Color(0.85, 0.68, 0.16, 1.0)
const COLOR_DEAD_UNIT := Color(0.18, 0.18, 0.20, 0.7)
const COLOR_HP_BG := Color(0.08, 0.08, 0.10, 1.0)
const COLOR_HP_ALLY := Color(0.25, 0.82, 0.45, 1.0)
const COLOR_HP_ENEMY := Color(0.92, 0.32, 0.28, 1.0)

@onready var bg_color_rect: ColorRect = %BgColorRect
@onready var round_label: Label = %RoundLabel
@onready var turn_queue_label: Label = %TurnQueueLabel
@onready var frontline_status_label: Label = %FrontlineStatusLabel
@onready var combat_log_label: Label = %CombatLogLabel
@onready var ally_grid: GridContainer = %AllyGrid
@onready var enemy_grid: GridContainer = %EnemyGrid
@onready var skill_action_button: Button = %SkillActionButton
@onready var skill2_action_button: Button = %Skill2ActionButton
@onready var ultimate_action_button: Button = %UltimateActionButton
@onready var auto_battle_button: Button = %AutoBattleButton
@onready var element_chart_button: Button = %ElementChartButton
@onready var speed_button: Button = %SpeedButton
@onready var item_action_button: Button = %ItemActionButton
@onready var item_overlay: ColorRect = %ItemOverlay
@onready var combat_items_vbox: VBoxContainer = %CombatItemsVBox
@onready var item_overlay_close_button: Button = %ItemOverlayCloseButton
@onready var victory_overlay: ColorRect = %VictoryOverlay
@onready var victory_title_label: Label = %VictoryTitleLabel
@onready var victory_summary_label: Label = %VictorySummaryLabel
@onready var victory_direct_return_button: Button = %VictoryDirectReturnButton
@onready var victory_prep_button: Button = %VictoryPrepButton
@onready var post_prep_overlay: ColorRect = %PostPrepOverlay
@onready var post_prep_hero_hbox: HBoxContainer = %PostPrepHeroHBox
@onready var post_prep_items_vbox: VBoxContainer = %PostPrepItemsVBox
@onready var post_prep_status_label: Label = %PostPrepStatusLabel
@onready var post_prep_done_button: Button = %PostPrepDoneButton
@onready var restart_button: Button = %RestartButton
@onready var finish_phase_button: Button = %FinishPhaseButton

var _units: Array[Dictionary] = []
var _slot_views: Dictionary = {
	Team.ALLY: {},
	Team.ENEMY: {},
}

var _turn_queue: Array[Dictionary] = []
var _active_unit: Dictionary = {}
var _round_number: int = 1
var _battle_over: bool = false
var _is_busy: bool = false
var _next_unit_id: int = 1
var _is_boss_battle: bool = false
var _is_elite_battle: bool = false
var _encounter_type: String = "NORMAL"
var _last_victory: bool = false
var _atk_bonus: int = 0
var _hp_bonus: int = 0
var _skill_targeting_mode: bool = false
var _selected_skill_slot: String = "active1"
var _item_targeting_mode: bool = false
var _pending_item_id: String = ""
var _prep_target_hero_uid: int = -1
var _auto_turn_seq: int = 0
var _floating_layer: Control = null
var _element_chart_overlay: ColorRect = null


func _ready() -> void:
	AssetManager.apply_backdrop(bg_color_rect, "offense_bg", Color(0.10, 0.11, 0.17), Color(0.05, 0.05, 0.08), 0.04)
	skill_action_button.pressed.connect(_on_skill_slot_pressed.bind("active1"))
	skill2_action_button.pressed.connect(_on_skill_slot_pressed.bind("active2"))
	ultimate_action_button.pressed.connect(_on_skill_slot_pressed.bind("ultimate"))
	item_action_button.pressed.connect(_on_item_action_pressed)
	item_overlay_close_button.pressed.connect(_close_item_overlay)
	victory_direct_return_button.pressed.connect(_on_finish_phase_pressed)
	victory_prep_button.pressed.connect(_open_post_prep_overlay)
	post_prep_done_button.pressed.connect(_on_finish_phase_pressed)
	auto_battle_button.pressed.connect(_on_auto_battle_pressed)
	speed_button.pressed.connect(_on_speed_pressed)
	GlobalData.battle_settings_changed.connect(_sync_battle_control_buttons)
	restart_button.pressed.connect(func() -> void: start_battle(_is_boss_battle, _atk_bonus, _hp_bonus, _is_elite_battle))
	finish_phase_button.pressed.connect(_on_finish_phase_pressed)

	_build_grid_ui(Team.ALLY, ally_grid)
	_build_grid_ui(Team.ENEMY, enemy_grid)

	_floating_layer = Control.new()
	_floating_layer.name = "FloatingTextLayer"
	_floating_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_floating_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floating_layer.z_index = 60
	add_child(_floating_layer)

	_element_chart_overlay = CombatFeedbackUI.create_element_chart_overlay(self)
	element_chart_button.pressed.connect(_element_chart_overlay.show)

	_sync_battle_control_buttons()

	if not embedded_in_map:
		GlobalData.phase_changed.connect(_on_phase_changed)
		start_battle()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _battle_over:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R or event.keycode == KEY_3:
			if not _active_unit.is_empty() and _active_unit["team"] == Team.ALLY:
				_on_skill_slot_pressed("ultimate")
				get_viewport().set_input_as_handled()


func _sync_battle_control_buttons() -> void:
	if not is_node_ready():
		return
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
	if not _battle_over and not _active_unit.is_empty() and _active_unit["team"] == Team.ALLY:
		if GlobalData.auto_battle_mode == GlobalData.AutoBattleMode.MANUAL:
			_auto_turn_seq += 1
			_is_busy = false
			_refresh_ui()
		elif not _is_busy:
			_run_ally_auto_turn()


func _on_speed_pressed() -> void:
	GlobalData.cycle_battle_speed()


func _get_step_delay(base_sec: float) -> float:
	return maxf(0.05, base_sec / maxf(1.0, GlobalData.battle_speed_mult))


func _on_phase_changed(new_phase: GlobalData.GamePhase) -> void:
	if new_phase == GlobalData.GamePhase.DUNGEON:
		start_battle()


func _build_grid_ui(team: Team, grid_container: GridContainer) -> void:
	for child in grid_container.get_children():
		child.queue_free()

	grid_container.columns = GRID_COLS
	_slot_views[team].clear()

	var col_ranks: Array[Rank] = []
	if team == Team.ALLY:
		col_ranks = [Rank.BACK, Rank.MIDDLE, Rank.FRONT]
	else:
		col_ranks = [Rank.FRONT, Rank.MIDDLE, Rank.BACK]

	for row in range(GRID_ROWS):
		for rank in col_ranks:
			var slot_root := Control.new()
			slot_root.custom_minimum_size = Vector2(228, 152)

			var bg_rect := Panel.new()
			bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bg_rect.add_theme_stylebox_override("panel", AssetManager.make_panel_style(COLOR_EMPTY_SLOT, AssetManager.COL_BORDER, 8, 1, 0))
			slot_root.add_child(bg_rect)

			var hp_bg := ColorRect.new()
			hp_bg.anchor_left = 0.0
			hp_bg.anchor_right = 1.0
			hp_bg.anchor_top = 1.0
			hp_bg.anchor_bottom = 1.0
			hp_bg.offset_left = 10
			hp_bg.offset_right = -10
			hp_bg.offset_top = -14
			hp_bg.offset_bottom = -5
			hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hp_bg.color = COLOR_HP_BG
			slot_root.add_child(hp_bg)

			var hp_fill := ColorRect.new()
			hp_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
			hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hp_fill.color = COLOR_HP_ALLY if team == Team.ALLY else COLOR_HP_ENEMY
			hp_bg.add_child(hp_fill)

			var btn := Button.new()
			btn.set_anchors_preset(Control.PRESET_FULL_RECT)
			btn.offset_left = 6
			btn.offset_right = -6
			btn.offset_top = 4
			btn.offset_bottom = -18
			btn.flat = true
			btn.expand_icon = true
			btn.add_theme_constant_override("icon_max_width", 42)
			btn.add_theme_font_size_override("font_size", 13)
			btn.text = "-"
			btn.disabled = true
			btn.pressed.connect(_on_slot_pressed.bind(team, rank, row))
			slot_root.add_child(btn)

			grid_container.add_child(slot_root)

			var key := _slot_key(rank, row)
			_slot_views[team][key] = {
				"slot_root": slot_root,
				"button": btn,
				"bg": bg_rect,
				"hp_bg": hp_bg,
				"hp_fill": hp_fill,
			}


func _slot_key(rank: Rank, row: int) -> Vector2i:
	return Vector2i(int(rank), row)


func start_battle(is_boss: bool = false, atk_bonus: int = 0, hp_bonus: int = 0, is_elite: bool = false, encounter_type: String = "NORMAL") -> void:
	_is_boss_battle = is_boss
	_is_elite_battle = is_elite
	var norm_enc: String = encounter_type.strip_edges().to_upper()
	_encounter_type = norm_enc if norm_enc in ["AMBUSH_ALLY", "AMBUSH_ENEMY", "NORMAL"] else "NORMAL"
	_atk_bonus = atk_bonus
	_hp_bonus = hp_bonus
	_last_victory = false
	_skill_targeting_mode = false
	_item_targeting_mode = false
	_pending_item_id = ""
	item_overlay.visible = false
	victory_overlay.visible = false
	post_prep_overlay.visible = false
	_units.clear()
	_turn_queue.clear()
	_active_unit = {}
	_round_number = 1
	_battle_over = false
	_is_busy = false
	_next_unit_id = 1
	finish_phase_button.disabled = true
	finish_phase_button.text = "던전 맵으로 복귀" if embedded_in_map else "정산으로 이동"

	_spawn_sample_units()
	_apply_encounter_opening_buffs()
	_rebuild_turn_queue()
	var enc_banner: String = _get_encounter_banner_text()
	if _is_boss_battle:
		_set_log("%s ★ [보스전] 심연의 군주와 수호자들이 길을 막습니다! 속도(SPD) 순으로 진행됩니다." % enc_banner)
	elif _is_elite_battle:
		_set_log("%s ◆ [정예 전투] 강력한 정예 수호대가 길을 막습니다! 속도(SPD) 순으로 진행됩니다." % enc_banner)
	else:
		_set_log("%s 전투 시작! 속도(SPD) 순으로 행동합니다. 기본 공격 또는 스킬 버튼을 사용하세요." % enc_banner)
	_advance_turn()


func _get_encounter_banner_text() -> String:
	match _encounter_type:
		"AMBUSH_ALLY":
			return "[★ 아군 기습! 아군 전원 1턴 SPD +10]"
		"AMBUSH_ENEMY":
			return "[⚠ 적 매복 기습! 적군 전원 1턴 SPD +10]"
		_:
			return "[일반 조우]"


func _apply_encounter_opening_buffs() -> void:
	var ally_units: Array[Dictionary] = _get_living_units(Team.ALLY)
	var enemy_units: Array[Dictionary] = _get_living_units(Team.ENEMY)

	if _encounter_type == "AMBUSH_ALLY":
		for unit in ally_units:
			unit["ambush_active"] = true
			StatusEffectManager.apply_effect(unit, "BUFF_SPEED_FLAT", 10.0, 1.0, unit)
	elif _encounter_type == "AMBUSH_ENEMY":
		for unit in enemy_units:
			StatusEffectManager.apply_effect(unit, "BUFF_SPEED_FLAT", 10.0, 1.0, unit)

	# 8대 병과 & 36 세부직군 전투 개시 특성 적용
	for unit in ally_units:
		var cg: String = str(unit.get("class_group", ""))
		var st: String = str(unit.get("sub_trait", ""))
		if cg == "선봉":
			var init_spd: float = 6.0 if st == "FIRST_STRIKE" else 3.0
			StatusEffectManager.apply_effect(unit, "VANGUARD_INIT_SPD", init_spd, 1.0, unit)
		match st:
			"SHIELD_WALL":
				StatusEffectManager.apply_effect(unit, "BUFF_DEF", 0.20, 2.0, unit)
			"THORN_CARAPACE":
				StatusEffectManager.apply_effect(unit, "REFLECT", 0.15, 99.0, unit)
			"ARCANE_BULWARK":
				StatusEffectManager.apply_effect(unit, "BUFF_ATK", 0.10, 99.0, unit)
			"BERSERK_FURY":
				StatusEffectManager.apply_effect(unit, "BUFF_ATK", 0.12, 99.0, unit)
			"RUNE_BLADE":
				StatusEffectManager.apply_effect(unit, "BUFF_ARMOR_PEN", 0.15, 99.0, unit)
			"ARCANE_PIERCE":
				StatusEffectManager.apply_effect(unit, "BUFF_ARMOR_PEN", 0.20, 99.0, unit)
			"DUELIST_CRIT":
				StatusEffectManager.apply_effect(unit, "BUFF_CRIT_RATE", 0.12, 99.0, unit)
				StatusEffectManager.apply_effect(unit, "BUFF_CRIT_DMG", 0.20, 99.0, unit)
			"EXECUTION_CRIT":
				StatusEffectManager.apply_effect(unit, "BUFF_CRIT_RATE", 0.15, 99.0, unit)
			"RAPID_FIRE":
				StatusEffectManager.apply_effect(unit, "BUFF_SPEED", 0.10, 99.0, unit)
			"ARMOR_CRUSH":
				StatusEffectManager.apply_effect(unit, "BUFF_ARMOR_PEN", 0.15, 99.0, unit)
			"DARK_RESONANCE":
				StatusEffectManager.apply_effect(unit, "BUFF_DMG_BONUS", 0.12, 99.0, unit)
				StatusEffectManager.apply_effect(unit, "BUFF_CRIT_DMG", 0.15, 99.0, unit)
			"GOLD_BONUS":
				if cg == "선봉":
					for mate in ally_units:
						StatusEffectManager.apply_effect(mate, "BUFF_ATK", 0.10, 1.0, unit)
			"VULNERABLE_HEX":
				for foe in enemy_units:
					StatusEffectManager.apply_effect(foe, "DEF_DOWN", 0.10, 3.0, unit)
			"TACTICAL_COMMAND":
				for mate in ally_units:
					StatusEffectManager.apply_effect(mate, "BUFF_CRIT_RATE", 0.08, 3.0, unit)
			"REGEN_SUPPORT":
				for mate in ally_units:
					StatusEffectManager.apply_effect(mate, "SHIELD", 0.6, 3.0, unit)


func _spawn_hero_unit_to_slot(hero: Dictionary, target_rank: Rank, row: int) -> void:
	var base_max_hp: int = maxi(1, roundi(GlobalData.get_hero_base_with_temperament(hero, "max_hp")))
	var eq_bonuses: Dictionary = GlobalData.get_hero_equipment_bonuses(hero)
	var eff_max_hp: int = maxi(1, base_max_hp + roundi(float(eq_bonuses.get("max_hp", 0.0))) + _hp_bonus)
	var base_cur_hp: int = int(hero.get("hp", eff_max_hp))
	var hier: Dictionary = DataManager.normalize_class_hierarchy(
		str(hero.get("class_group", "")),
		str(hero.get("sub_class", hero.get("job_class", "돌격검객"))),
		str(hero.get("role_category", "전위"))
	)
	var sub_info: Dictionary = DataManager.get_sub_class_info(str(hier["sub_class"]))
	_add_unit(
		Team.ALLY,
		target_rank,
		row,
		str(hero.get("name", "영웅")),
		base_max_hp + _hp_bonus,
		maxi(1, roundi(GlobalData.get_hero_base_with_temperament(hero, "atk"))) + _atk_bonus,
		maxi(1, roundi(GlobalData.get_hero_base_with_temperament(hero, "speed"))),
		str(hier["role_category"]),
		str(hier["sub_class"]),
		maxi(0, roundi(GlobalData.get_hero_base_with_temperament(hero, "heal_power"))),
		str(hero.get("element", "FIRE")),
		maxi(0, roundi(GlobalData.get_hero_base_with_temperament(hero, "def"))),
		{
			"hero_uid": int(hero.get("uid", -1)),
			"hero_id": str(hero.get("id", "")),
			"class_group": str(hier["class_group"]),
			"sub_class": str(hier["sub_class"]),
			"sub_trait": str(sub_info.get("sub_trait", "")),
			"is_named": bool(hero.get("is_named", false)),
			"portrait_path": str(hero.get("portrait_path", "")),
			"sprite_path": str(hero.get("sprite_path", "")),
			"rarity": DataManager.normalize_rarity(hero.get("rarity", "N")),
			"is_tired": GlobalData.is_hero_tired(hero),
			"current_hp": clampi(base_cur_hp + _hp_bonus, 1, eff_max_hp),
			"effective_max_hp": eff_max_hp,
			"passive_bonuses": eq_bonuses,
			"dmg_bonus": GlobalData.get_hero_base_with_temperament(hero, "dmg_bonus"),
			"crit_rate": GlobalData.get_hero_base_with_temperament(hero, "crit_rate"),
			"crit_dmg": GlobalData.get_hero_base_with_temperament(hero, "crit_dmg"),
			"armor_pen": GlobalData.get_hero_base_with_temperament(hero, "armor_pen"),
			"final_dmg_mult": float(hero.get("final_dmg_mult", 1.0)),
			"skill_id": str(hero.get("skill_id", "")),
			"skill2_id": str(hero.get("skill2_id", "")),
			"ultimate_id": str(hero.get("ultimate_id", "")),
		}
	)


func _spawn_sample_units() -> void:
	var preset_entries: Array[Dictionary] = GlobalData.get_preset_slots_list(GlobalData.selected_party_index)
	var spawned_any: bool = false

	if not preset_entries.is_empty():
		for entry in preset_entries:
			var hero: Dictionary = entry["hero"]
			if not GlobalData.can_hero_deploy(hero):
				continue
			_spawn_hero_unit_to_slot(hero, int(entry["rank"]) as Rank, int(entry["row"]))
			spawned_any = true
	else:
		var source_heroes: Array[Dictionary] = []
		for h in GlobalData.hero_roster:
			if GlobalData.can_hero_deploy(h):
				source_heroes.append(h)

		if source_heroes.is_empty() and GlobalData.hero_roster.is_empty() and not DataManager.heroes.is_empty():
			source_heroes = DataManager.heroes

		if not source_heroes.is_empty():
			var row_order: Array[int] = [0, 2, 1]
			var rank_counts: Dictionary = {Rank.FRONT: 0, Rank.MIDDLE: 0, Rank.BACK: 0}
			for hero in source_heroes:
				var pref_str: String = str(hero.get("offense_rank", "전열"))
				var target_rank: Rank = Rank.FRONT
				if pref_str == "중위":
					target_rank = Rank.MIDDLE
				elif pref_str == "후열":
					target_rank = Rank.BACK

				if int(rank_counts[target_rank]) >= 3:
					var found_fallback: bool = false
					for alt_rank in [Rank.FRONT, Rank.MIDDLE, Rank.BACK]:
						if int(rank_counts[alt_rank]) < 3:
							target_rank = alt_rank
							found_fallback = true
							break
					if not found_fallback:
						continue

				var idx_in_rank: int = int(rank_counts[target_rank])
				rank_counts[target_rank] = idx_in_rank + 1
				_spawn_hero_unit_to_slot(hero, target_rank, row_order[idx_in_rank])
				spawned_any = true

	if spawned_any:
		# 장비 패시브 스킬(passive_skill_id) 전투 시작 시 자동 발동
		var ally_units: Array[Dictionary] = _get_living_units(Team.ALLY)
		for ally_unit in ally_units:
			var uid: int = int(ally_unit.get("hero_uid", -1))
			if uid > 0:
				var h_data: Dictionary = GlobalData.get_hero_by_uid(uid)
				if not h_data.is_empty():
					GlobalData.apply_equipment_passives_to_combat_unit(h_data, ally_unit, ally_units)
	elif GlobalData.hero_roster.is_empty():
		_add_unit(Team.ALLY, Rank.FRONT, 0, "기사", 65 + _hp_bonus, 20 + _atk_bonus, 12, "전위", "근접딜러", 0, "FIRE", 12, {"rarity": "SR", "skill_id": "skill_fire_slash", "skill2_id": "skill_flame_aura"})
		_add_unit(Team.ALLY, Rank.FRONT, 2, "방패병", 85 + _hp_bonus, 12 + _atk_bonus, 8, "전위", "탱커", 0, "EARTH", 25, {"rarity": "R", "skill_id": "skill_shield_bash"})
		_add_unit(Team.ALLY, Rank.MIDDLE, 1, "창병", 52 + _hp_bonus, 22 + _atk_bonus, 15, "중위", "근접딜러", 0, "WIND", 10, {"rarity": "R", "skill_id": "skill_spear_drag"})
		_add_unit(Team.ALLY, Rank.BACK, 0, "궁수", 35 + _hp_bonus, 24 + _atk_bonus, 18, "후위", "원거리딜러", 0, "LIGHTNING", 5, {"rarity": "R", "skill_id": "skill_snipe_back"})
		_add_unit(Team.ALLY, Rank.BACK, 2, "사제", 40 + _hp_bonus, 8 + _atk_bonus, 16, "후위", "힐러", 24, "LIGHT", 8, {"rarity": "SR", "skill_id": "skill_holy_blessing", "skill2_id": "skill_sanctuary_ward"})

	_spawn_enemies_from_data()


func _spawn_enemies_from_data() -> void:
	var season_key: String = TimeManager.get_season_key()
	var s_mults: Dictionary = TimeManager.get_season_enemy_multipliers()
	var hp_mult: float = float(s_mults.get("hp", 1.0))
	var atk_mult: float = float(s_mults.get("atk", 1.0))
	var def_mult: float = float(s_mults.get("def", 1.0))
	var spd_mult: float = float(s_mults.get("speed", 1.0))
	var season_bonus_eff: String = str(s_mults.get("bonus_effect", ""))

	var prefer_rebel: bool = GlobalData.is_rebellion_humanoid_preferred()
	var spawn_plan: Array[Dictionary] = []
	if _is_boss_battle:
		var bosses := DataManager.get_enemies_for_context(season_key, "BOSS", [], prefer_rebel)
		var elites := DataManager.get_enemies_for_context(season_key, "ELITE", [], prefer_rebel)
		var normals := DataManager.get_enemies_for_context(season_key, "NORMAL", GlobalData.upcoming_defense_elements, prefer_rebel)
		if not normals.is_empty():
			spawn_plan.append({"tpl": normals[0 % normals.size()], "rank": Rank.FRONT, "row": 0})
			spawn_plan.append({"tpl": normals[1 % normals.size()], "rank": Rank.FRONT, "row": 2})
		if not elites.is_empty():
			spawn_plan.append({"tpl": elites[0], "rank": Rank.MIDDLE, "row": 1})
		if not bosses.is_empty():
			spawn_plan.append({"tpl": bosses[0], "rank": Rank.BACK, "row": 1})
	elif _is_elite_battle:
		var elites := DataManager.get_enemies_for_context(season_key, "ELITE", [], prefer_rebel)
		var normals := DataManager.get_enemies_for_context(season_key, "NORMAL", GlobalData.upcoming_defense_elements, prefer_rebel)
		if not normals.is_empty():
			spawn_plan.append({"tpl": normals[0 % normals.size()], "rank": Rank.FRONT, "row": 0})
			spawn_plan.append({"tpl": normals[1 % normals.size()], "rank": Rank.FRONT, "row": 2})
		if not elites.is_empty():
			spawn_plan.append({"tpl": elites[randi() % elites.size()], "rank": Rank.BACK, "row": 1})
	else:
		var pool := DataManager.get_enemies_for_context(season_key, "NORMAL", GlobalData.upcoming_defense_elements, prefer_rebel)
		if pool.is_empty():
			pool = DataManager.get_enemies_for_context(season_key, "", [], prefer_rebel)
		var slots_order: Array = [[Rank.FRONT, 0], [Rank.FRONT, 2], [Rank.MIDDLE, 1], [Rank.BACK, 2]]
		for i in range(slots_order.size()):
			if not pool.is_empty():
				var tpl: Dictionary = pool[i % pool.size()]
				spawn_plan.append({"tpl": tpl, "rank": slots_order[i][0], "row": slots_order[i][1]})

	if spawn_plan.is_empty():
		_add_unit(Team.ENEMY, Rank.FRONT, 0, "고블린 약탈자", roundi(42 * hp_mult), roundi(12 * atk_mult), roundi(13 * spd_mult), "전위", "근접딜러", 0, "WIND", roundi(5 * def_mult))
		_add_unit(Team.ENEMY, Rank.MIDDLE, 1, "오크 전사", roundi(58 * hp_mult), roundi(16 * atk_mult), roundi(11 * spd_mult), "전위", "탱커", 0, "EARTH", roundi(12 * def_mult))
		return

	for item in spawn_plan:
		var tpl: Dictionary = item["tpl"]
		var e_type: String = str(tpl.get("enemy_type", "NORMAL"))
		var rank_int: int = int(item["rank"])
		var e_role_cat: String = "후위" if rank_int == Rank.BACK else ("중위" if rank_int == Rank.MIDDLE else "전위")
		var active_ids: Array = tpl.get("active_skill_ids", [])
		var passive_ids: Array = tpl.get("passive_skill_ids", [])
		var s_hp: int = maxi(10, roundi(float(tpl.get("max_hp", 50)) * hp_mult))
		var s_atk: int = maxi(4, roundi(float(tpl.get("atk", 12)) * atk_mult))
		var s_def: int = maxi(0, roundi(float(tpl.get("def", 6)) * def_mult))
		var s_spd: int = maxi(3, roundi(float(tpl.get("speed", 12)) * spd_mult))
		_add_unit(
			Team.ENEMY,
			item["rank"],
			int(item["row"]),
			str(tpl.get("name", "적")),
			s_hp,
			s_atk,
			s_spd,
			e_role_cat,
			e_type,
			0,
			str(tpl.get("element", "FIRE")),
			s_def,
			{
				"enemy_id": str(tpl.get("id", "")),
				"enemy_type": e_type,
				"category": str(tpl.get("category", "MONSTER")),
				"archetype": str(tpl.get("archetype", "SWARMER")),
				"tint_color": str(tpl.get("tint_color", "")),
				"palette_swapped": bool(tpl.get("palette_swapped", false)),
				"sprite_path": str(tpl.get("sprite_path", "")),
				"rarity": "SSR" if e_type == "BOSS" else ("SR" if e_type == "ELITE" else "R"),
				"skill_id": str(active_ids[0]) if active_ids.size() >= 1 else "",
				"skill2_id": str(active_ids[1]) if active_ids.size() >= 2 else "",
				"passive_skill_ids": passive_ids,
				"season_bonus_effect": season_bonus_eff,
			}
		)

	# 적 패시브 스킬(skills.json) 및 14대 아키타입 고유 특성 전투 시작 시 일괄 발동
	var enemy_units: Array[Dictionary] = _get_living_units(Team.ENEMY)
	for eu in enemy_units:
		for p_id in eu.get("passive_skill_ids", []):
			var sk := DataManager.get_skill(str(p_id))
			if sk.is_empty():
				continue
			for eff in sk.get("effects", []):
				var etype: String = str(eff.get("effect_type", ""))
				var scope: String = str(eff.get("target_scope", "SELF"))
				var mult: float = float(eff.get("multiplier", 0.0))
				var dur: float = maxf(99.0, float(eff.get("duration", 99)))
				if scope == "ALL_ALLIES":
					for mate in enemy_units:
						StatusEffectManager.apply_effect(mate, etype, mult, dur, eu)
				else:
					StatusEffectManager.apply_effect(eu, etype, mult, dur, eu)

		var arch: String = str(eu.get("archetype", ""))
		match arch:
			"VOLATILE":
				if not StatusEffectManager.has_effect(eu, "EXPLODE_ON_DEATH"):
					StatusEffectManager.apply_effect(eu, "EXPLODE_ON_DEATH", 1.6, 99.0, eu)
			"THORNBACK":
				if not StatusEffectManager.has_effect(eu, "REFLECT"):
					StatusEffectManager.apply_effect(eu, "REFLECT", 0.25, 99.0, eu)
			"PHALANX":
				if StatusEffectManager.get_total_shield(eu) <= 0:
					StatusEffectManager.apply_effect(eu, "SHIELD", 0.8, 99.0, eu)
			"CUTTHROAT":
				eu["crit_rate"] = float(eu.get("crit_rate", 0.05)) + 0.15
				eu["armor_pen"] = float(eu.get("armor_pen", 0.0)) + 0.15
			"ARBALEST":
				eu["armor_pen"] = float(eu.get("armor_pen", 0.0)) + 0.20
			"COMMANDER":
				for mate in enemy_units:
					StatusEffectManager.apply_effect(mate, "BUFF_ATK", 0.12, 99.0, eu)


func _add_unit(
	team: Team,
	rank: Rank,
	row: int,
	unit_name: String,
	max_hp: int,
	atk: int,
	speed: int,
	role_category: String = "전위",
	job_class: String = "근접딜러",
	heal_power: int = 0,
	element: String = "FIRE",
	defense: int = 10,
	extra: Dictionary = {}
) -> void:
	var new_unit: Dictionary = {
		"id": _next_unit_id,
		"team": team,
		"rank": rank,
		"row": row,
		"name": unit_name,
		"role_category": role_category,
		"class_group": str(extra.get("class_group", DataManager.get_class_group_for_sub_class(job_class))),
		"sub_class": str(extra.get("sub_class", job_class)),
		"sub_trait": str(extra.get("sub_trait", "")),
		"job_class": job_class,
		"element": element,
		"max_hp": max_hp,
		"hp": clampi(int(extra.get("current_hp", max_hp)), 0, int(extra.get("effective_max_hp", max_hp))),
		"hero_uid": int(extra.get("hero_uid", -1)),
		"hero_id": str(extra.get("hero_id", "")),
		"enemy_id": str(extra.get("enemy_id", "")),
		"enemy_type": str(extra.get("enemy_type", "NORMAL")),
		"category": str(extra.get("category", "")),
		"archetype": str(extra.get("archetype", "")),
		"tint_color": str(extra.get("tint_color", "")),
		"palette_swapped": bool(extra.get("palette_swapped", false)),
		"ambush_active": false,
		"_duration_ext": 1.0,
		"_brood_spawned": false,
		"_is_summoned": bool(extra.get("_is_summoned", false)),
		"_miracle_revived": false,
		"_miracle_pending_trauma": false,
		"_battle_kills": 0,
		"_battle_healed": 0,
		"portrait_path": str(extra.get("portrait_path", "")),
		"sprite_path": str(extra.get("sprite_path", "")),
		"is_named": bool(extra.get("is_named", false)),
		"is_tired": bool(extra.get("is_tired", false)),
		"atk": atk,
		"def": defense,
		"heal_power": heal_power,
		"speed": speed,
		"dmg_bonus": float(extra.get("dmg_bonus", 0.0)),
		"crit_rate": float(extra.get("crit_rate", 0.05)),
		"crit_dmg": float(extra.get("crit_dmg", 1.5)),
		"armor_pen": float(extra.get("armor_pen", 0.0)),
		"final_dmg_mult": float(extra.get("final_dmg_mult", 1.0)),
		"crit_gauge": 0.0,
		"rarity": DataManager.normalize_rarity(extra.get("rarity", "N")),
		"skill_id": str(extra.get("skill_id", "")),
		"skill2_id": str(extra.get("skill2_id", "")),
		"ultimate_id": str(extra.get("ultimate_id", "")),
		"passive_skill_ids": (extra.get("passive_skill_ids", []) as Array).duplicate(),
		"season_bonus_effect": str(extra.get("season_bonus_effect", "")),
		"skill_cd": 0,
		"skill2_cd": 0,
		"ultimate_cd": 0,
		"shield": 0,
		"status_effects": [],
		"passive_bonuses": (extra.get("passive_bonuses", {}) as Dictionary).duplicate(true),
		"rank_bonuses": {},
	}
	_apply_rank_position_bonus(new_unit, true)
	_units.append(new_unit)
	_next_unit_id += 1


func _apply_rank_position_bonus(unit: Dictionary, scale_hp: bool = true) -> void:
	if unit.is_empty():
		return
	var old_eff_max: float = maxf(1.0, StatusEffectManager.get_effective_stat(unit, "max_hp"))
	var passives: Dictionary = unit.get("passive_bonuses", {})
	var bonus_cfg: Dictionary = GlobalData.get_rank_position_bonus(int(unit.get("rank", 0)))
	var base_hp: float = float(unit.get("max_hp", 50)) + float(passives.get("max_hp", 0.0))
	var base_atk: float = float(unit.get("atk", 15)) + float(passives.get("atk", 0.0))
	var base_def: float = float(unit.get("def", 10)) + float(passives.get("def", 0.0))

	var rb: Dictionary = {
		"max_hp": float(roundi(base_hp * float(bonus_cfg.get("max_hp_pct", 0.0)))),
		"atk": float(roundi(base_atk * float(bonus_cfg.get("atk_pct", 0.0)))),
		"def": float(roundi(base_def * float(bonus_cfg.get("def_pct", 0.0)))),
		"speed": float(bonus_cfg.get("speed", 0.0)),
		"dmg_bonus": float(bonus_cfg.get("dmg_bonus", 0.0)),
		"crit_rate": float(bonus_cfg.get("crit_rate", 0.0)),
		"crit_dmg": float(bonus_cfg.get("crit_dmg", 0.0)),
		"heal_pct": float(bonus_cfg.get("heal_pct", 0.0)),
	}
	unit["rank_bonuses"] = rb

	if int(unit.get("hp", 0)) > 0:
		var new_eff_max: int = maxi(1, roundi(StatusEffectManager.get_effective_stat(unit, "max_hp")))
		if scale_hp:
			var cur_hp: int = int(unit["hp"])
			if cur_hp >= roundi(old_eff_max):
				unit["hp"] = new_eff_max
			else:
				unit["hp"] = clampi(roundi(float(cur_hp) * (float(new_eff_max) / old_eff_max)), 1, new_eff_max)
		else:
			unit["hp"] = clampi(int(unit["hp"]), 1, new_eff_max)


func _get_unit_at(team: Team, rank: Rank, row: int) -> Dictionary:
	for unit in _units:
		if unit["team"] == team and unit["rank"] == rank and unit["row"] == row:
			return unit
	return {}


func _get_living_units(team: Team) -> Array[Dictionary]:
	var alive: Array[Dictionary] = []
	for unit in _units:
		if unit["team"] == team and int(unit["hp"]) > 0:
			alive.append(unit)
	return alive


func get_active_front_rank(team: Team) -> int:
	for rank in [Rank.FRONT, Rank.MIDDLE, Rank.BACK]:
		for unit in _units:
			if unit["team"] == team and unit["rank"] == rank and int(unit["hp"]) > 0:
				return int(rank)
	return -1


func get_active_back_rank(team: Team) -> int:
	for rank in [Rank.BACK, Rank.MIDDLE, Rank.FRONT]:
		for unit in _units:
			if unit["team"] == team and unit["rank"] == rank and int(unit["hp"]) > 0:
				return int(rank)
	return -1


func get_targetable_units(team: Team) -> Array[Dictionary]:
	var front_rank: int = get_active_front_rank(team)
	if front_rank == -1:
		return []
	var targets: Array[Dictionary] = []
	for unit in _units:
		if unit["team"] == team and int(unit["rank"]) == front_rank and int(unit["hp"]) > 0:
			targets.append(unit)
	return targets


func _rebuild_turn_queue() -> void:
	_turn_queue.clear()
	for unit in _units:
		if int(unit["hp"]) > 0:
			_turn_queue.append(unit)

	_turn_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var spd_a: float = StatusEffectManager.get_effective_stat(a, "speed")
		var spd_b: float = StatusEffectManager.get_effective_stat(b, "speed")
		if spd_a != spd_b:
			return spd_a > spd_b
		if a["team"] != b["team"]:
			return int(a["team"]) < int(b["team"])
		if a["rank"] != b["rank"]:
			return int(a["rank"]) < int(b["rank"])
		return a["row"] < b["row"]
	)


func _advance_turn() -> void:
	_skill_targeting_mode = false
	if _check_battle_end():
		return

	_turn_queue = _turn_queue.filter(func(u: Dictionary) -> bool: return int(u["hp"]) > 0)
	if _turn_queue.is_empty():
		_round_number += 1
		_rebuild_turn_queue()

	_active_unit = _turn_queue.pop_front()

	# 턴 시작 시 스킬 쿨다운 감소 + 상태이상(DoT/기절/지속턴) 처리
	for cd_key in ["skill_cd", "skill2_cd", "ultimate_cd"]:
		if int(_active_unit.get(cd_key, 0)) > 0:
			_active_unit[cd_key] = int(_active_unit[cd_key]) - 1

	var dot_logs: PackedStringArray = []
	var was_stunned: bool = StatusEffectManager.is_stunned(_active_unit)
	var tick_events: Array[Dictionary] = StatusEffectManager.tick_turn_effects(_active_unit)
	for ev in tick_events:
		if ev.get("type", "") == "dot":
			var eff_label: String = StatusEffectManager.get_effect_label(str(ev["effect_id"]))
			var dot_dmg: int = int(ev["damage"])
			_spawn_unit_damage_float(_active_unit, dot_dmg, false, 1.0, 0, true)
			dot_logs.append("[%s] %s 지속피해 -%d (남은 HP %d/%d)" % [
				_active_unit["name"],
				eff_label,
				dot_dmg,
				int(_active_unit["hp"]),
				int(_active_unit["max_hp"]),
			])

	if int(_active_unit["hp"]) <= 0:
		if not _try_unit_miracle_survival(_active_unit, dot_logs):
			if not dot_logs.is_empty():
				_set_log("\n".join(dot_logs) + " [지속 피해로 전투불능!]")
			_refresh_ui()
			_advance_turn()
			return
		if not dot_logs.is_empty():
			_set_log("\n".join(dot_logs))

	if was_stunned:
		var stun_msg: String = "💫 %s은(는) 기절 상태라 행동할 수 없습니다!" % _active_unit["name"]
		if not dot_logs.is_empty():
			stun_msg = "\n".join(dot_logs) + "\n" + stun_msg
		_set_log(stun_msg)
		_refresh_ui()
		_skip_stunned_turn()
		return

	if not dot_logs.is_empty():
		_set_log("\n".join(dot_logs))

	_refresh_ui()

	if _active_unit["team"] == Team.ENEMY:
		_run_enemy_turn()
	elif GlobalData.auto_battle_mode != GlobalData.AutoBattleMode.MANUAL:
		_run_ally_auto_turn()


func _skip_stunned_turn() -> void:
	_is_busy = true
	await get_tree().create_timer(_get_step_delay(0.45)).timeout
	if not is_inside_tree() or _battle_over:
		return
	_is_busy = false
	_advance_turn()


func _can_unit_heal(unit: Dictionary) -> bool:
	if unit.is_empty():
		return false
	return str(unit.get("class_group", "")) == "의료" or str(unit.get("job_class", "")) == "힐러" or int(unit.get("heal_power", 0)) > 0


func _get_heal_amount(unit: Dictionary) -> int:
	var h: int = int(unit.get("heal_power", 0))
	var base: float = float(h) if h > 0 else maxf(10.0, StatusEffectManager.get_effective_stat(unit, "atk"))
	var heal_mult: float = 1.0 + float((unit.get("rank_bonuses", {}) as Dictionary).get("heal_pct", 0.0))
	return maxi(1, roundi(base * heal_mult))


func _spawn_unit_floating_text(unit: Dictionary, text: String, kind: String = "NORMAL", y_offset: float = 0.0) -> void:
	if _floating_layer == null or unit.is_empty():
		return
	var team: Team = unit["team"]
	var key := _slot_key(int(unit["rank"]) as Rank, int(unit["row"]))
	var view: Dictionary = _slot_views.get(team, {}).get(key, {})
	var slot_root: Control = view.get("slot_root", null)
	if slot_root == null or not is_instance_valid(slot_root):
		return
	var pos: Vector2 = slot_root.global_position + slot_root.size * Vector2(0.5, 0.35) - _floating_layer.global_position + Vector2(0.0, y_offset)
	CombatFeedbackUI.spawn_floating_text(_floating_layer, pos, text, kind, GlobalData.battle_speed_mult)


func _spawn_unit_damage_float(target: Dictionary, dmg: int, is_crit: bool, elem_mult: float, shield_absorbed: int = 0, is_dot: bool = false) -> void:
	var info: Dictionary = CombatFeedbackUI.classify_damage_display(dmg, is_crit, elem_mult, is_dot)
	_spawn_unit_floating_text(target, str(info["text"]), str(info["kind"]))
	if shield_absorbed > 0:
		_spawn_unit_floating_text(target, "보호막 -%d" % shield_absorbed, "SHIELD", -22.0)


func heal_unit(target: Dictionary, amount: int) -> int:
	if target.is_empty() or int(target.get("hp", 0)) <= 0 or amount <= 0:
		return 0
	var prev_hp: int = int(target["hp"])
	var max_hp: int = roundi(StatusEffectManager.get_effective_stat(target, "max_hp"))
	var new_hp: int = mini(max_hp, prev_hp + amount)
	target["hp"] = new_hp
	var healed: int = new_hp - prev_hp
	if healed > 0:
		_spawn_unit_floating_text(target, "+%d" % healed, "HEAL")
	return healed


func _get_skill_key_for_slot(slot_name: String) -> Dictionary:
	match slot_name:
		"active2":
			return {"id_key": "skill2_id", "cd_key": "skill2_cd", "label": "액티브 2"}
		"ultimate":
			return {"id_key": "ultimate_id", "cd_key": "ultimate_cd", "label": "궁극기"}
		_:
			return {"id_key": "skill_id", "cd_key": "skill_cd", "label": "액티브 1"}


func _get_active_unit_skill(slot_name: String = "") -> Dictionary:
	if _active_unit.is_empty():
		return {}
	var use_slot: String = slot_name if not slot_name.is_empty() else _selected_skill_slot
	var rarity: String = DataManager.normalize_rarity(_active_unit.get("rarity", "N"))
	var rules: Dictionary = DataManager.get_skill_slot_rules(rarity)
	if not bool(rules.get(use_slot, false)):
		return {}
	var meta: Dictionary = _get_skill_key_for_slot(use_slot)
	var skill_id: String = str(_active_unit.get(meta["id_key"], ""))
	if skill_id.is_empty():
		return {}
	return DataManager.get_skill(skill_id)


func _is_scope_auto_cast(scope: String) -> bool:
	return scope == "ALL_ENEMIES" or scope == "ALL_ALLIES" or scope == "SELF"


func _is_scope_ally(scope: String) -> bool:
	return scope == "SELF" or scope == "SINGLE_ALLY" or scope == "ALL_ALLIES"


func _on_skill_slot_pressed(slot_name: String) -> void:
	if _battle_over or _active_unit.is_empty() or _active_unit["team"] != Team.ALLY:
		return
	var can_interrupt_auto_ult: bool = (
		_is_busy
		and slot_name == "ultimate"
		and GlobalData.auto_battle_mode == GlobalData.AutoBattleMode.AUTO_SAVE_ULT
	)
	if _is_busy and not can_interrupt_auto_ult:
		return
	var skill: Dictionary = _get_active_unit_skill(slot_name)
	var meta: Dictionary = _get_skill_key_for_slot(slot_name)
	if skill.is_empty() or int(_active_unit.get(meta["cd_key"], 0)) > 0:
		return

	var effects: Array = skill.get("effects", [])
	if effects.is_empty():
		return

	if can_interrupt_auto_ult:
		_auto_turn_seq += 1
		_is_busy = false
		var smart_target: Dictionary = _pick_smart_target_for_skill(_active_unit, skill)
		_execute_skill(_active_unit, skill, smart_target, slot_name)
		_advance_turn()
		return

	var primary_scope: String = str(effects[0].get("target_scope", "SINGLE_FRONT"))
	if _is_scope_auto_cast(primary_scope):
		_execute_skill(_active_unit, skill, {}, slot_name)
		_advance_turn()
		return

	if _skill_targeting_mode and _selected_skill_slot == slot_name:
		_skill_targeting_mode = false
		_set_log("스킬 사용을 취소하고 기본 행동 모드로 돌아왔습니다.")
	else:
		_selected_skill_slot = slot_name
		_skill_targeting_mode = true
		_item_targeting_mode = false
		_pending_item_id = ""
		_set_log("[%s 대기: %s] 주황/초록으로 표시된 대상을 클릭하세요. (취소하려면 버튼 재클릭)" % [meta["label"], skill["name"]])
	_refresh_ui()


func _on_slot_pressed(team: Team, rank: Rank, row: int) -> void:
	if _battle_over or _is_busy:
		return
	if _active_unit.is_empty() or _active_unit["team"] != Team.ALLY:
		return

	var target: Dictionary = _get_unit_at(team, rank, row)
	if target.is_empty() or int(target["hp"]) <= 0:
		return

	if _item_targeting_mode:
		var item: Dictionary = DataManager.get_item(_pending_item_id)
		if item.is_empty():
			_item_targeting_mode = false
			_pending_item_id = ""
			return
		var i_scope: String = str(item.get("target_scope", "SINGLE_ALLY"))
		var valid_ally: bool = (i_scope == "SINGLE_ALLY" and team == Team.ALLY)
		var valid_enemy: bool = (i_scope == "SINGLE_ENEMY" and team == Team.ENEMY)
		if not (valid_ally or valid_enemy):
			return
		_execute_combat_item(_active_unit, item, target)
		_advance_turn()
		return

	if _skill_targeting_mode:
		var skill: Dictionary = _get_active_unit_skill(_selected_skill_slot)
		if skill.is_empty():
			_skill_targeting_mode = false
			return
		var primary_scope: String = str(skill["effects"][0].get("target_scope", "SINGLE_FRONT"))
		if not _is_valid_skill_click_target(target, primary_scope):
			return
		_execute_skill(_active_unit, skill, target, _selected_skill_slot)
		_advance_turn()
		return

	if team == Team.ALLY:
		if not _can_unit_heal(_active_unit):
			return
		var eff_target_max: int = roundi(StatusEffectManager.get_effective_stat(target, "max_hp"))
		if int(target["hp"]) >= eff_target_max:
			_set_log("%s은(는) 이미 최대 체력입니다." % target["name"])
			return
		_execute_heal(_active_unit, target)
		_advance_turn()
		return

	var active_rank: int = get_active_front_rank(Team.ENEMY)
	var can_back_snipe: bool = (str(_active_unit.get("sub_trait", "")) == "BACKLINE_SNIPE" and int(target["rank"]) == get_active_back_rank(Team.ENEMY))
	if int(target["rank"]) != active_rank and not can_back_snipe:
		return

	_execute_attack(_active_unit, target)
	_advance_turn()


func _is_valid_skill_click_target(target: Dictionary, scope: String) -> bool:
	var t_team: Team = target["team"]
	var t_rank: int = int(target["rank"])
	match scope:
		"SINGLE_FRONT", "ROW":
			return t_team == Team.ENEMY and t_rank == get_active_front_rank(Team.ENEMY)
		"SINGLE_BACK":
			return t_team == Team.ENEMY and t_rank == get_active_back_rank(Team.ENEMY)
		"CROSS", "SQUARE_2X2", "COLUMN", "AOE_SMALL", "AOE_LARGE":
			return t_team == Team.ENEMY
		"SINGLE_ALLY":
			return t_team == Team.ALLY
		_:
			return false


func _resolve_effect_targets(caster: Dictionary, scope: String, clicked_target: Dictionary) -> Array[Dictionary]:
	var caster_team: Team = caster["team"]
	var enemy_team: Team = Team.ENEMY if caster_team == Team.ALLY else Team.ALLY
	var out: Array[Dictionary] = []

	var anchor: Dictionary = clicked_target
	if anchor.is_empty() or anchor.get("team") != enemy_team or int(anchor.get("hp", 0)) <= 0:
		var front_list := get_targetable_units(enemy_team)
		if not front_list.is_empty():
			anchor = front_list[0]

	match scope:
		"SELF":
			out.append(caster)
		"SINGLE_ALLY":
			if not clicked_target.is_empty() and clicked_target["team"] == caster_team and int(clicked_target["hp"]) > 0:
				out.append(clicked_target)
			else:
				var allies := _get_living_units(caster_team)
				if not allies.is_empty():
					out.append(allies[0])
		"ALL_ALLIES":
			out = _get_living_units(caster_team)
		"ALL_ENEMIES", "AOE_LARGE":
			out = _get_living_units(enemy_team)
		"ROW":
			var target_rank: int = int(anchor["rank"]) if not anchor.is_empty() else get_active_front_rank(enemy_team)
			for u in _get_living_units(enemy_team):
				if int(u["rank"]) == target_rank:
					out.append(u)
		"COLUMN":
			var target_row: int = int(anchor["row"]) if not anchor.is_empty() else 1
			for u in _get_living_units(enemy_team):
				if int(u["row"]) == target_row:
					out.append(u)
		"CROSS", "AOE_SMALL":
			if not anchor.is_empty():
				var cr: int = int(anchor["rank"])
				var cw: int = int(anchor["row"])
				for u in _get_living_units(enemy_team):
					var dr: int = absi(int(u["rank"]) - cr)
					var dw: int = absi(int(u["row"]) - cw)
					if dr + dw <= 1:
						out.append(u)
		"SQUARE_2X2":
			if not anchor.is_empty():
				var base_r: int = clampi(int(anchor["rank"]), 0, 1)
				var base_w: int = clampi(int(anchor["row"]), 0, 1)
				for u in _get_living_units(enemy_team):
					var ur: int = int(u["rank"])
					var uw: int = int(u["row"])
					if ur >= base_r and ur <= base_r + 1 and uw >= base_w and uw <= base_w + 1:
						out.append(u)
		"SINGLE_BACK":
			if not clicked_target.is_empty() and clicked_target["team"] == enemy_team and int(clicked_target["hp"]) > 0:
				out.append(clicked_target)
			else:
				var back_rank: int = get_active_back_rank(enemy_team)
				for u in _get_living_units(enemy_team):
					if int(u["rank"]) == back_rank:
						out.append(u)
						break
		_:
			if not clicked_target.is_empty() and clicked_target["team"] == enemy_team and int(clicked_target["hp"]) > 0:
				out.append(clicked_target)
			else:
				var front := get_targetable_units(enemy_team)
				if not front.is_empty():
					out.append(front[0])
	return out


func _execute_skill(caster: Dictionary, skill: Dictionary, clicked_target: Dictionary, slot_name: String = "active1") -> void:
	var meta: Dictionary = _get_skill_key_for_slot(slot_name)
	caster[meta["cd_key"]] = int(skill.get("cooldown", 2))
	_skill_targeting_mode = false

	var logs: PackedStringArray = ["★ [%s] %s 발동: <%s>" % [caster["name"], meta["label"], skill["name"]]]
	var effects: Array = skill.get("effects", [])
	var displaced_any: bool = false

	for eff in effects:
		var eff_type: String = str(eff.get("effect_type", "DAMAGE"))
		var scope: String = str(eff.get("target_scope", "SINGLE_FRONT"))
		var mult: float = float(eff.get("multiplier", 1.0))
		var dur: float = float(eff.get("duration", 1))
		var targets: Array[Dictionary] = _resolve_effect_targets(caster, scope, clicked_target)

		if eff_type == "SHUFFLE_POS":
			if not targets.is_empty():
				var target_team: Team = targets[0]["team"]
				if _shuffle_team_positions(target_team, logs):
					displaced_any = true
			continue

		for target in targets:
			if int(target["hp"]) <= 0:
				continue
			if eff_type == "DAMAGE":
				var prev_front: int = get_active_front_rank(target["team"])
				var calc: Dictionary = CombatCalculator.calculate_skill_damage(caster, target, eff)
				var dmg: int = int(calc["damage"])
				var hit_res: Dictionary = StatusEffectManager.apply_damage_with_shield(target, dmg)
				var crit_tag: String = " [치명타!]" if bool(calc["is_crit"]) else ""
				var shield_tag: String = " (보호막 -%d)" % int(hit_res["shield_absorbed"]) if int(hit_res["shield_absorbed"]) > 0 else ""
				var elem_mult: float = float(calc["element_multiplier"])
				_spawn_unit_damage_float(target, dmg, bool(calc["is_crit"]), elem_mult, int(hit_res["shield_absorbed"]))
				var elem_tag: String = " [상성%.2gx]" % elem_mult if elem_mult > 1.05 else (" [반감%.2gx]" % elem_mult if elem_mult < 0.95 else "")
				var t_max: int = roundi(StatusEffectManager.get_effective_stat(target, "max_hp"))
				logs.append("→ %s에게 %d 피해%s%s%s (HP %d/%d)" % [
					target["name"], dmg, crit_tag, elem_tag, shield_tag, target["hp"], t_max
				])
				_apply_unit_reactive_passives(caster, target, dmg, logs)
				_try_unit_miracle_survival(target, logs)
				if int(target["hp"]) == 0:
					if caster["team"] == Team.ALLY:
						caster["_battle_kills"] = int(caster.get("_battle_kills", 0)) + 1
					if caster["team"] == Team.ALLY and str(caster.get("class_group", "")) == "근위":
						StatusEffectManager.apply_effect(caster, "KILL_SPD_BOOST", 2.0, 2.0, caster)
						displaced_any = true
						logs.append("  ↳ ⚡ [근위: 파쇄 돌격] 처치 보너스로 %s 다음 턴 SPD +2!" % caster["name"])
					var new_front: int = get_active_front_rank(target["team"])
					if new_front != -1 and new_front != prev_front:
						logs.append("★ [열 붕괴!] %s 전멸 → %s 타겟팅!" % [RANK_NAMES[prev_front], RANK_NAMES[new_front]])
			elif eff_type == "HEAL":
				var base_heal: float = float(_get_heal_amount(caster))
				var heal_val: int = maxi(1, roundi(base_heal * mult))
				var t_max_chk: float = maxf(1.0, StatusEffectManager.get_effective_stat(target, "max_hp"))
				if str(caster.get("sub_trait", "")) == "EMERGENCY_HEAL" and float(target["hp"]) / t_max_chk <= 0.40:
					heal_val = roundi(float(heal_val) * 1.40)
				var healed: int = heal_unit(target, heal_val)
				if caster["team"] == Team.ALLY and healed > 0:
					caster["_battle_healed"] = int(caster.get("_battle_healed", 0)) + healed
				if str(caster.get("class_group", "")) == "의료":
					StatusEffectManager.apply_effect(target, "DMG_REDUCE", 0.10, 1.0, caster)
				if str(caster.get("sub_trait", "")) == "WARD_PURIFY":
					StatusEffectManager.clear_debuffs(target)
				var t_max: int = roundi(StatusEffectManager.get_effective_stat(target, "max_hp"))
				logs.append("→ %s 체력 +%d 회복%s (HP %d/%d)" % [
					target["name"],
					healed,
					" [구호 결계 -10%]" if str(caster.get("class_group", "")) == "의료" else "",
					target["hp"],
					t_max,
				])
			elif StatusEffectManager.is_displacement_effect(eff_type):
				if _apply_displacement_effect(eff_type, target, mult, logs, caster):
					displaced_any = true
					if str(caster.get("sub_trait", "")) == "FORCE_DISPLACE" and int(target["hp"]) > 0:
						StatusEffectManager.apply_effect(target, "DEF_DOWN", 0.15, 1.0, caster)
			else:
				var applied: Dictionary = StatusEffectManager.apply_effect(target, eff_type, mult, dur, caster)
				var eff_name: String = StatusEffectManager.get_effect_label(eff_type)
				if eff_type == "SHIELD":
					var sh_gain: int = int(applied.get("value", 0))
					if sh_gain > 0:
						_spawn_unit_floating_text(target, "보호막 +%d" % sh_gain, "SHIELD")
					logs.append("→ %s에게 보호막 +%d (%d턴)" % [target["name"], sh_gain, int(dur)])
				else:
					logs.append("→ %s에게 [%s] 부여 (%d턴)" % [target["name"], eff_name, int(dur)])

	if displaced_any and not _turn_queue.is_empty():
		_turn_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return StatusEffectManager.get_effective_stat(a, "speed") > StatusEffectManager.get_effective_stat(b, "speed")
		)

	_set_log("\n".join(logs))


func _apply_displacement_effect(eff_type: String, target: Dictionary, mult: float, logs: PackedStringArray, caster: Dictionary = {}) -> bool:
	var cur_rank: int = int(target.get("rank", 0))
	var steps: int = maxi(1, roundi(mult))
	var dest_rank: int = cur_rank
	var action_label: String = "배치 이동"
	var guaranteed: bool = (not caster.is_empty() and str(caster.get("class_group", "")) == "특수")
	if not guaranteed and bool(target.get("displacement_immune", false)):
		logs.append("→ %s은(는) 강제 이동에 저항했습니다." % target["name"])
		return false
	match eff_type:
		"PUSH_BACK":
			dest_rank = mini(2, cur_rank + steps)
			action_label = "강제 후퇴" + ("(특수100%)" if guaranteed else "")
		"PULL_FRONT":
			dest_rank = maxi(0, cur_rank - steps)
			action_label = "강제 견인" + ("(특수100%)" if guaranteed else "")
		"SWAP_POS":
			dest_rank = 2 if cur_rank == 0 else 0
			action_label = "진형 교체" + ("(특수100%)" if guaranteed else "")
	if dest_rank == cur_rank:
		logs.append("→ %s은(는) 이미 %s 끝열이라 이동하지 않았습니다." % [target["name"], RANK_NAMES[cur_rank]])
		return false

	var team: Team = target["team"]
	var old_row: int = int(target.get("row", 0))
	var occupant: Dictionary = _get_unit_at(team, dest_rank as Rank, old_row)
	if not occupant.is_empty():
		for r_cand in [0, 1, 2]:
			if _get_unit_at(team, dest_rank as Rank, r_cand).is_empty():
				occupant = {}
				target["rank"] = dest_rank as Rank
				target["row"] = r_cand
				_apply_rank_position_bonus(target, true)
				logs.append("  ↳ ⇄ [%s] %s: %s → %s 이동!" % [action_label, target["name"], RANK_NAMES[cur_rank], RANK_NAMES[dest_rank]])
				return true
		var occ_rank: int = int(occupant["rank"])
		var occ_row: int = int(occupant["row"])
		occupant["rank"] = cur_rank as Rank
		occupant["row"] = old_row
		target["rank"] = occ_rank as Rank
		target["row"] = occ_row
		_apply_rank_position_bonus(target, true)
		_apply_rank_position_bonus(occupant, true)
		logs.append("  ↳ ⇄ [%s] %s(%s) ⇄ %s(%s) 위치 맞교환!" % [action_label, target["name"], RANK_NAMES[occ_rank], occupant["name"], RANK_NAMES[cur_rank]])
		return true

	target["rank"] = dest_rank as Rank
	_apply_rank_position_bonus(target, true)
	logs.append("  ↳ ⇄ [%s] %s: %s → %s 이동! (%s)" % [action_label, target["name"], RANK_NAMES[cur_rank], RANK_NAMES[dest_rank], GlobalData.get_rank_bonus_summary(dest_rank)])
	return true


func _shuffle_team_positions(team: Team, logs: PackedStringArray) -> bool:
	var living: Array[Dictionary] = _get_living_units(team)
	if living.is_empty():
		return false
	var corpse_cells: Dictionary = {}
	for u in _units:
		if u["team"] == team and int(u.get("hp", 0)) <= 0:
			corpse_cells["%d,%d" % [int(u["rank"]), int(u["row"])]] = true

	var avail_cells: Array[Vector2i] = []
	for r in [0, 1, 2]:
		for w in [0, 1, 2]:
			if not corpse_cells.has("%d,%d" % [r, w]):
				avail_cells.append(Vector2i(r, w))
	if avail_cells.size() < living.size():
		return false

	avail_cells.shuffle()
	for i in range(living.size()):
		var u: Dictionary = living[i]
		var cell: Vector2i = avail_cells[i]
		u["rank"] = cell.x as Rank
		u["row"] = cell.y
		_apply_rank_position_bonus(u, true)

	var team_name: String = "아군" if team == Team.ALLY else "적군"
	logs.append("  ↳ 🌀 [진형 교란] %s 전원의 위치가 무작위로 재배치되었습니다! (열 보너스 갱신)" % team_name)
	return true


func _apply_unit_reactive_passives(attacker: Dictionary, victim: Dictionary, dealt_dmg: int, logs: PackedStringArray) -> void:
	# 1) 피격 반사 (REFLECT)
	var reflect_ratio: float = StatusEffectManager.get_effect_value(victim, "REFLECT")
	if reflect_ratio > 0.0 and int(attacker.get("hp", 0)) > 0 and dealt_dmg > 0:
		var ref_dmg: int = maxi(1, roundi(float(dealt_dmg) * reflect_ratio))
		var ref_res: Dictionary = StatusEffectManager.apply_damage_with_shield(attacker, ref_dmg)
		_spawn_unit_damage_float(attacker, ref_dmg, false, 1.0, int(ref_res["shield_absorbed"]), true)
		logs.append("  ↳ [가시 반사] %s → %s에게 %d 반사 피해! (HP %d/%d)" % [
			victim["name"], attacker["name"], ref_dmg, attacker["hp"], attacker["max_hp"]
		])
		_try_unit_miracle_survival(attacker, logs)

	# 2) 사망 자폭 (EXPLODE_ON_DEATH) & 3) 기생/분열체(BROODMOTHER) 유충 소환
	if int(victim.get("hp", 0)) <= 0:
		var explode_mult: float = StatusEffectManager.get_effect_value(victim, "EXPLODE_ON_DEATH")
		if explode_mult > 0.0:
			var exp_dmg: int = maxi(4, roundi(StatusEffectManager.get_effective_stat(victim, "atk") * explode_mult))
			var foe_team: Team = Team.ALLY if victim["team"] == Team.ENEMY else Team.ENEMY
			for foe in get_targetable_units(foe_team):
				var exp_res: Dictionary = StatusEffectManager.apply_damage_with_shield(foe, exp_dmg)
				_spawn_unit_damage_float(foe, exp_dmg, false, 1.0, int(exp_res["shield_absorbed"]))
				logs.append("  ↳ 💥 [사망 자폭] %s 폭발 → %s에게 %d 피해! (HP %d/%d)" % [
					victim["name"], foe["name"], exp_dmg, foe["hp"], foe["max_hp"]
				])
				_try_unit_miracle_survival(foe, logs)
		if str(victim.get("archetype", "")) == "BROODMOTHER" and not bool(victim.get("_brood_spawned", false)):
			victim["_brood_spawned"] = true
			var spawned_cnt: int = _spawn_brood_minions(victim)
			if spawned_cnt > 0:
				logs.append("  ↳ 🪲 [군체 분열!] %s의 사체에서 분열 유충 %d기가 튀어나왔습니다!" % [victim["name"], spawned_cnt])


func _try_unit_miracle_survival(unit: Dictionary, out_logs: PackedStringArray) -> bool:
	if unit.is_empty() or int(unit.get("team", -1)) != Team.ALLY:
		return false
	if int(unit.get("hp", 0)) > 0 or bool(unit.get("_miracle_revived", false)):
		return false
	var uid: int = int(unit.get("hero_uid", -1))
	if not GlobalData.roll_miracle_survival(uid):
		return false
	unit["_miracle_revived"] = true
	unit["_miracle_pending_trauma"] = true
	var rev_hp: int = maxi(1, roundi(StatusEffectManager.get_effective_stat(unit, "max_hp") * 0.15))
	unit["hp"] = rev_hp
	_spawn_unit_floating_text(unit, "★ 기적적 생환! (+%d HP)" % rev_hp, "CRIT")
	out_logs.append("★ [기적적 생환!] %s이(가) 죽음의 문턱에서 HP %d로 다시 일어섰습니다!" % [str(unit.get("name", "영웅")), rev_hp])
	return true


func _spawn_brood_minions(parent_unit: Dictionary) -> int:
	var p_team: Team = parent_unit["team"]
	var spawned: int = 0
	var base_hp: int = maxi(14, roundi(float(parent_unit.get("max_hp", 60)) * 0.35))
	var base_atk: int = maxi(6, roundi(float(parent_unit.get("atk", 15)) * 0.55))
	var base_spd: int = maxi(12, int(parent_unit.get("speed", 12)) + 3)
	var elem: String = str(parent_unit.get("element", "DARK"))
	for r in [Rank.FRONT, Rank.MIDDLE, Rank.BACK]:
		for w in [0, 1, 2]:
			if spawned >= 2:
				return spawned
			var occ: Dictionary = _get_unit_at(p_team, r, w)
			if occ.is_empty():
				_add_unit(
					p_team, r, w, "분열 유충", base_hp, base_atk, base_spd,
					"전위", "NORMAL", 0, elem, 3,
					{"enemy_id": "enemy_feral_swarmer", "enemy_type": "NORMAL", "category": "MONSTER", "archetype": "SWARMER", "_is_summoned": true}
				)
				var new_minion: Dictionary = _units[-1]
				_turn_queue.append(new_minion)
				spawned += 1
	return spawned


func _run_enemy_turn() -> void:
	_is_busy = true
	_refresh_ui()

	await get_tree().create_timer(_get_step_delay(0.45)).timeout
	if not is_inside_tree() or _battle_over:
		return

	# 적이 장착한 액티브 스킬이 쿨타임 준비됐으면 우선 발동
	var used_skill: bool = false
	for slot_name in ["active1", "active2"]:
		var meta: Dictionary = _get_skill_key_for_slot(slot_name)
		var sid: String = str(_active_unit.get(meta["id_key"], ""))
		if sid.is_empty() or int(_active_unit.get(meta["cd_key"], 0)) > 0:
			continue
		var sk := DataManager.get_skill(sid)
		if not sk.is_empty():
			var picked_target: Dictionary = _pick_enemy_skill_target(sk)
			_execute_skill(_active_unit, sk, picked_target, slot_name)
			used_skill = true
			break

	if not used_skill:
		var arch: String = str(_active_unit.get("archetype", ""))
		if arch == "PREACHER":
			var enemy_allies: Array[Dictionary] = _get_living_units(Team.ENEMY)
			var injured: Dictionary = {}
			var lowest_ratio: float = 0.85
			for ea in enemy_allies:
				var mhp: float = maxf(1.0, StatusEffectManager.get_effective_stat(ea, "max_hp"))
				var r: float = float(ea["hp"]) / mhp
				if r < lowest_ratio:
					lowest_ratio = r
					injured = ea
			if not injured.is_empty():
				var heal_amt: int = maxi(10, roundi(StatusEffectManager.get_effective_stat(_active_unit, "atk") * 1.1))
				var healed: int = heal_unit(injured, heal_amt)
				StatusEffectManager.apply_effect(injured, "BUFF_ATK", 0.15, 2.0, _active_unit)
				_set_log("[교단 사제 AI] %s → %s 체력 +%d 치유 & 공격력 +15%%!" % [_active_unit["name"], injured["name"], healed])
				used_skill = true
			elif not enemy_allies.is_empty():
				for ea in enemy_allies:
					StatusEffectManager.apply_effect(ea, "BUFF_ATK", 0.12, 2.0, _active_unit)
				_set_log("[교단 사제 AI] %s → 적군 전원에게 광신 공격력 축복!" % _active_unit["name"])
				used_skill = true

	if not used_skill:
		var arch2: String = str(_active_unit.get("archetype", ""))
		if arch2 == "CUTTHROAT":
			var back_r: int = get_active_back_rank(Team.ALLY)
			var back_targets: Array[Dictionary] = []
			for u in _get_living_units(Team.ALLY):
				if int(u["rank"]) == back_r:
					back_targets.append(u)
			if not back_targets.is_empty():
				back_targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
					var ah: int = 1 if _can_unit_heal(a) else 0
					var bh: int = 1 if _can_unit_heal(b) else 0
					if ah != bh:
						return ah > bh
					return int(a["hp"]) < int(b["hp"])
				)
				_execute_attack(_active_unit, back_targets[0], " [후열 암살 저격!]")
				used_skill = true

	if not used_skill:
		var targets: Array[Dictionary] = get_targetable_units(Team.ALLY)
		if not targets.is_empty():
			targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a["hp"]) < int(b["hp"])
			)
			_execute_attack(_active_unit, targets[0])

	_is_busy = false
	_advance_turn()


func _pick_enemy_skill_target(skill: Dictionary) -> Dictionary:
	var effects: Array = skill.get("effects", [])
	var primary_scope: String = str(effects[0].get("target_scope", "SINGLE_FRONT")) if not effects.is_empty() else "SINGLE_FRONT"
	var primary_type: String = str(effects[0].get("effect_type", "DAMAGE")) if not effects.is_empty() else "DAMAGE"

	if primary_scope == "SINGLE_ALLY" or primary_scope == "ALL_ALLIES":
		var foes := _get_living_units(Team.ENEMY)
		if foes.is_empty():
			return _active_unit
		foes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["hp"]) < int(b["hp"])
		)
		return foes[0]

	if primary_scope == "SINGLE_BACK":
		var back_rank: int = get_active_back_rank(Team.ALLY)
		var back_allies: Array[Dictionary] = []
		for u in _get_living_units(Team.ALLY):
			if int(u["rank"]) == back_rank:
				back_allies.append(u)
		if not back_allies.is_empty():
			back_allies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var a_heal: int = 1 if _can_unit_heal(a) else 0
				var b_heal: int = 1 if _can_unit_heal(b) else 0
				if a_heal != b_heal:
					return a_heal > b_heal
				return int(a["hp"]) < int(b["hp"])
			)
			return back_allies[0]

	var front_allies := get_targetable_units(Team.ALLY)
	if front_allies.is_empty():
		var any_allies := _get_living_units(Team.ALLY)
		return any_allies[0] if not any_allies.is_empty() else {}

	front_allies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if primary_type == "PUSH_BACK":
			return StatusEffectManager.get_effective_stat(a, "def") > StatusEffectManager.get_effective_stat(b, "def")
		return int(a["hp"]) < int(b["hp"])
	)
	return front_allies[0]


# ==========================================
# 자동 전투 AI (우선순위 1~5) & 스마트 타겟팅
# ==========================================
func _run_ally_auto_turn() -> void:
	_is_busy = true
	_auto_turn_seq += 1
	var my_seq: int = _auto_turn_seq
	_refresh_ui()

	await get_tree().create_timer(_get_step_delay(0.32)).timeout
	if not is_inside_tree() or _battle_over or my_seq != _auto_turn_seq:
		return
	if GlobalData.auto_battle_mode == GlobalData.AutoBattleMode.MANUAL or _active_unit.is_empty() or _active_unit["team"] != Team.ALLY:
		_is_busy = false
		_refresh_ui()
		return

	_execute_ally_ai_action(_active_unit)
	_is_busy = false
	_advance_turn()


func _get_ready_skill_entries(caster: Dictionary, include_ultimate: bool) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var rarity: String = DataManager.normalize_rarity(caster.get("rarity", "N"))
	var rules: Dictionary = DataManager.get_skill_slot_rules(rarity)
	var slot_list: Array[String] = ["active1", "active2"]
	if include_ultimate:
		slot_list.append("ultimate")

	for slot_name in slot_list:
		if not bool(rules.get(slot_name, false)):
			continue
		var meta: Dictionary = _get_skill_key_for_slot(slot_name)
		if int(caster.get(meta["cd_key"], 0)) > 0:
			continue
		var sid: String = str(caster.get(meta["id_key"], ""))
		if sid.is_empty():
			continue
		var skill: Dictionary = DataManager.get_skill(sid)
		if skill.is_empty() or (skill.get("effects", []) as Array).is_empty():
			continue
		entries.append({"slot": slot_name, "skill": skill})
	return entries


func _skill_has_effect(skill: Dictionary, eff_types: PackedStringArray) -> bool:
	for eff in skill.get("effects", []):
		if eff_types.has(str(eff.get("effect_type", ""))):
			return true
	return false


func _skill_is_pure_support_heal(skill: Dictionary) -> bool:
	var has_heal: bool = false
	for eff in skill.get("effects", []):
		var etype: String = str(eff.get("effect_type", ""))
		if etype == "DAMAGE":
			return false
		if etype == "HEAL":
			has_heal = true
	return has_heal


func _get_skill_max_damage_multiplier(skill: Dictionary) -> float:
	var best_mult: float = 0.0
	for eff in skill.get("effects", []):
		if str(eff.get("effect_type", "")) == "DAMAGE":
			best_mult = maxf(best_mult, float(eff.get("multiplier", 1.0)))
	return best_mult


func _get_valid_enemies_for_scope(scope: String) -> Array[Dictionary]:
	match scope:
		"ALL_ENEMIES", "CROSS", "SQUARE_2X2", "COLUMN", "AOE_SMALL", "AOE_LARGE":
			return _get_living_units(Team.ENEMY)
		"SINGLE_BACK":
			var back_rank: int = get_active_back_rank(Team.ENEMY)
			var out_b: Array[Dictionary] = []
			for u in _get_living_units(Team.ENEMY):
				if int(u["rank"]) == back_rank:
					out_b.append(u)
			return out_b
		_:
			return get_targetable_units(Team.ENEMY)


func _pick_smart_enemy_target(caster: Dictionary, enemies: Array[Dictionary], skill_effect: Dictionary, preferred_missing_debuff: String = "") -> Dictionary:
	if enemies.is_empty():
		return {}
	var best_enemy: Dictionary = enemies[0]
	var best_score: float = -99999.0
	for enemy in enemies:
		var res: Dictionary = CombatCalculator.score_smart_target(caster, enemy, skill_effect)
		var sc: float = float(res["score"])
		if not preferred_missing_debuff.is_empty() and not StatusEffectManager.has_effect(enemy, preferred_missing_debuff):
			sc += 45.0
		if sc > best_score:
			best_score = sc
			best_enemy = enemy
	return best_enemy


func _pick_smart_target_for_skill(caster: Dictionary, skill: Dictionary) -> Dictionary:
	var effects: Array = skill.get("effects", [])
	if effects.is_empty():
		return {}
	var primary_eff: Dictionary = effects[0]
	var scope: String = str(primary_eff.get("target_scope", "SINGLE_FRONT"))
	if _is_scope_ally(scope):
		var allies := _get_living_units(Team.ALLY)
		allies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var ra: float = float(a["hp"]) / maxf(1.0, StatusEffectManager.get_effective_stat(a, "max_hp"))
			var rb: float = float(b["hp"]) / maxf(1.0, StatusEffectManager.get_effective_stat(b, "max_hp"))
			return ra < rb
		)
		return allies[0] if not allies.is_empty() else caster
	var valid_enemies: Array[Dictionary] = _get_valid_enemies_for_scope(scope)
	return _pick_smart_enemy_target(caster, valid_enemies, primary_eff)


func _execute_ally_ai_action(caster: Dictionary) -> void:
	var allies := _get_living_units(Team.ALLY)
	if allies.is_empty():
		return

	var lowest_ally: Dictionary = allies[0]
	var lowest_ratio: float = 2.0
	var all_healthy_85: bool = true
	for a in allies:
		var ratio: float = float(a["hp"]) / maxf(1.0, StatusEffectManager.get_effective_stat(a, "max_hp"))
		if ratio < 0.85:
			all_healthy_85 = false
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			lowest_ally = a

	var is_full_auto: bool = (GlobalData.auto_battle_mode == GlobalData.AutoBattleMode.FULL_AUTO)
	var ready_actives: Array[Dictionary] = _get_ready_skill_entries(caster, false)
	var ready_ult: Array[Dictionary] = _get_ready_skill_entries(caster, true).filter(func(e: Dictionary) -> bool: return str(e["slot"]) == "ultimate")

	# 1) 긴급 케어: 체력 40% 이하 아군이 있으면 HEAL/SHIELD 액티브 우선 사용 (아군 전원 85% 이상이면 힐 아낌)
	if lowest_ratio <= 0.40:
		for entry in ready_actives:
			var sk: Dictionary = entry["skill"]
			if _skill_has_effect(sk, PackedStringArray(["HEAL", "SHIELD"])):
				_execute_skill(caster, sk, lowest_ally, str(entry["slot"]))
				return
		if _can_unit_heal(caster) and int(lowest_ally["hp"]) < roundi(StatusEffectManager.get_effective_stat(lowest_ally, "max_hp")):
			_execute_heal(caster, lowest_ally)
			return

	# 2) 미적용 디버프: STUN, SLOW, DEF_DOWN이 없는 적에게 해당 디버프 스킬 우선 사용
	var priority_debuffs := PackedStringArray(["STUN", "SLOW", "DEF_DOWN"])
	for entry in ready_actives:
		var sk: Dictionary = entry["skill"]
		for eff in sk.get("effects", []):
			var etype: String = str(eff.get("effect_type", ""))
			if priority_debuffs.has(etype):
				var scope: String = str(eff.get("target_scope", "SINGLE_FRONT"))
				var candidates := _get_valid_enemies_for_scope(scope)
				var has_missing: bool = false
				for enemy in candidates:
					if not StatusEffectManager.has_effect(enemy, etype):
						has_missing = true
						break
				if has_missing:
					var picked := _pick_smart_enemy_target(caster, candidates, eff, etype)
					_execute_skill(caster, sk, picked, str(entry["slot"]))
					return

	# 4) 궁극기: [완전 자동]일 때만 쿨타임이 차면 즉시 발동 ([자동] 모드에서는 플레이어 단축키 입력 대기)
	if is_full_auto and not ready_ult.is_empty():
		var ult_sk: Dictionary = ready_ult[0]["skill"]
		if not (all_healthy_85 and _skill_is_pure_support_heal(ult_sk)):
			var ult_target := _pick_smart_target_for_skill(caster, ult_sk)
			_execute_skill(caster, ult_sk, ult_target, "ultimate")
			return

	# 3) 고계수 액티브: 사용 가능한 공격 액티브 중 계수(multiplier)가 가장 높은 스킬 사용
	var best_attack_entry: Dictionary = {}
	var best_mult: float = -1.0
	for entry in ready_actives:
		var sk: Dictionary = entry["skill"]
		if all_healthy_85 and _skill_is_pure_support_heal(sk):
			continue
		var m: float = _get_skill_max_damage_multiplier(sk)
		if m > best_mult:
			best_mult = m
			best_attack_entry = entry

	if not best_attack_entry.is_empty() and best_mult > 0.0:
		var atk_sk: Dictionary = best_attack_entry["skill"]
		var atk_target := _pick_smart_target_for_skill(caster, atk_sk)
		_execute_skill(caster, atk_sk, atk_target, str(best_attack_entry["slot"]))
		return

	# 힐러인데 공격 스킬이 없고 아군 중 85% 미만 부상자가 있으면 기본 회복 수행
	if not all_healthy_85 and _can_unit_heal(caster) and int(lowest_ally["hp"]) < roundi(StatusEffectManager.get_effective_stat(lowest_ally, "max_hp")):
		_execute_heal(caster, lowest_ally)
		return

	# 5) 기본 공격: 스마트 타겟팅 점수가 가장 높은 전열(또는 BACKLINE_SNIPE 후열) 적 공격
	var front_enemies := get_targetable_units(Team.ENEMY)
	if str(caster.get("sub_trait", "")) == "BACKLINE_SNIPE":
		var back_r: int = get_active_back_rank(Team.ENEMY)
		var back_pool: Array[Dictionary] = []
		for u in _get_living_units(Team.ENEMY):
			if int(u["rank"]) == back_r:
				back_pool.append(u)
		if not back_pool.is_empty():
			front_enemies = back_pool
	if not front_enemies.is_empty():
		var smart_basic_target := _pick_smart_enemy_target(caster, front_enemies, {"multiplier": 1.0})
		_execute_attack(caster, smart_basic_target)


func _execute_attack(attacker: Dictionary, defender: Dictionary, extra_tag: String = "") -> void:
	var def_team: Team = defender["team"]
	var prev_front_rank: int = get_active_front_rank(def_team)

	var atk_elem: String = str(attacker.get("element", ""))
	var def_elem: String = str(defender.get("element", ""))
	var skill_eff: Dictionary = {"multiplier": 1.0}
	if str(attacker.get("sub_trait", "")) == "BACKLINE_SNIPE" and int(defender.get("rank", 0)) == get_active_back_rank(def_team):
		skill_eff["multiplier"] = 1.20
	var calc: Dictionary = CombatCalculator.calculate_skill_damage(attacker, defender, skill_eff)
	var dmg: int = int(calc["damage"])
	var elem_mult: float = float(calc["element_multiplier"])
	var hit_res: Dictionary = StatusEffectManager.apply_damage_with_shield(defender, dmg)
	_spawn_unit_damage_float(defender, dmg, bool(calc.get("is_crit", false)), elem_mult, int(hit_res["shield_absorbed"]))

	var elem_note: String = ""
	if elem_mult > 1.05:
		elem_note = " [상성 %.2gx!]" % elem_mult
	elif elem_mult < 0.95:
		elem_note = " [반감 %.2gx]" % elem_mult
	var crit_note: String = " [치명타!]" if bool(calc.get("is_crit", false)) else ""
	var shield_note: String = " (보호막 -%d)" % int(hit_res["shield_absorbed"]) if int(hit_res["shield_absorbed"]) > 0 else ""

	var miracle_logs: PackedStringArray = []
	_try_unit_miracle_survival(defender, miracle_logs)

	var team_tag: String = "아군" if attacker["team"] == Team.ALLY else "적"
	var msg: String = "[%s]%s %s(%s) → %s(%s)에게 %d 피해!%s%s%s (남은 HP: %d/%d)" % [
		team_tag,
		extra_tag,
		attacker["name"],
		DataManager.get_element_name(atk_elem),
		defender["name"],
		DataManager.get_element_name(def_elem),
		dmg,
		crit_note,
		elem_note,
		shield_note,
		defender["hp"],
		defender["max_hp"],
	]
	if not miracle_logs.is_empty():
		msg += "\n" + "\n".join(miracle_logs)

	if int(defender["hp"]) == 0:
		msg += " [처치!]"
		if attacker["team"] == Team.ALLY:
			attacker["_battle_kills"] = int(attacker.get("_battle_kills", 0)) + 1
		if attacker["team"] == Team.ALLY and str(attacker.get("class_group", "")) == "근위":
			StatusEffectManager.apply_effect(attacker, "KILL_SPD_BOOST", 2.0, 2.0, attacker)
			if not _turn_queue.is_empty():
				_turn_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
					return StatusEffectManager.get_effective_stat(a, "speed") > StatusEffectManager.get_effective_stat(b, "speed")
				)
			msg += "\n  ↳ ⚡ [근위: 파쇄 돌격] %s 다음 턴 SPD +2!" % attacker["name"]
		var new_front_rank: int = get_active_front_rank(def_team)
		if new_front_rank != -1 and new_front_rank != prev_front_rank:
			var target_team_name: String = "적군" if def_team == Team.ENEMY else "아군"
			msg += "\n★ [열 붕괴!] %s %s 전멸 → 이제 %s을(를) 타겟팅합니다!" % [
				target_team_name,
				RANK_NAMES[prev_front_rank],
				RANK_NAMES[new_front_rank],
			]

	# 계절 환경 특성 부여 (여름: 화상 / 가을: 방감 / 겨울: 감속)
	var s_eff: String = str(attacker.get("season_bonus_effect", ""))
	if attacker["team"] == Team.ENEMY and not s_eff.is_empty() and int(defender["hp"]) > 0:
		StatusEffectManager.apply_effect(defender, s_eff, 0.25, 2.0, attacker)
		msg += " [계절:%s]" % StatusEffectManager.get_effect_label(s_eff)

	var passive_logs: PackedStringArray = []
	_apply_unit_reactive_passives(attacker, defender, dmg, passive_logs)
	if not passive_logs.is_empty():
		msg += "\n" + "\n".join(passive_logs)

	_set_log(msg)


func _execute_heal(healer: Dictionary, target: Dictionary) -> void:
	var amount: int = _get_heal_amount(healer)
	var t_max_chk: float = maxf(1.0, StatusEffectManager.get_effective_stat(target, "max_hp"))
	if str(healer.get("sub_trait", "")) == "EMERGENCY_HEAL" and float(target["hp"]) / t_max_chk <= 0.40:
		amount = roundi(float(amount) * 1.40)
	var healed: int = heal_unit(target, amount)
	if int(healer.get("team", -1)) == Team.ALLY and healed > 0:
		healer["_battle_healed"] = int(healer.get("_battle_healed", 0)) + healed
	var ward_tag: String = ""
	if str(healer.get("class_group", "")) == "의료":
		StatusEffectManager.apply_effect(target, "DMG_REDUCE", 0.10, 1.0, healer)
		ward_tag = " [구호 결계: 1턴 피해 -10%]"
	if str(healer.get("sub_trait", "")) == "WARD_PURIFY":
		StatusEffectManager.clear_debuffs(target)
	_set_log("[회복] %s → %s 체력 +%d 회복!%s (HP: %d/%d)" % [
		healer["name"],
		target["name"],
		healed,
		ward_tag,
		target["hp"],
		target["max_hp"],
	])


func _finalize_hero_service_and_traumas(victory: bool) -> PackedStringArray:
	var report_logs: PackedStringArray = []
	for unit in _units:
		if int(unit.get("team", -1)) != Team.ALLY:
			continue
		var uid: int = int(unit.get("hero_uid", -1))
		if uid <= 0:
			continue
		var was_miracle: bool = bool(unit.get("_miracle_pending_trauma", false))
		if was_miracle:
			unit["_miracle_pending_trauma"] = false
			var neg_id: String = GlobalData.grant_random_negative_temperament(uid)
			if not neg_id.is_empty():
				var neg_name: String = str(GlobalData.get_temperament_info(neg_id).get("name", neg_id))
				report_logs.append("★ [기적적 생환] %s이(가) 죽음에서 돌아왔으나, 후유증 [%s] 기질을 얻었습니다!" % [str(unit.get("name", "영웅")), neg_name])
		var unlocked_vets: Array[String] = GlobalData.record_hero_service(uid, {
			"battles_fought": 1,
			"boss_kills": 1 if (victory and _is_boss_battle) else 0,
			"total_kills": int(unit.get("_battle_kills", 0)),
			"total_healed": int(unit.get("_battle_healed", 0)),
			"near_deaths": 1 if was_miracle else 0,
		})
		for vid in unlocked_vets:
			var vinfo: Dictionary = GlobalData.get_temperament_info(vid)
			report_logs.append("• [실전 습관 해금] %s → [%s] (%s)" % [
				str(unit.get("name", "영웅")),
				str(vinfo.get("name", vid)),
				str(vinfo.get("summary", "")),
			])
	return report_logs


func _check_battle_end() -> bool:
	var allies_alive: int = _get_living_units(Team.ALLY).size()
	var enemies_alive: int = _get_living_units(Team.ENEMY).size()

	if enemies_alive == 0:
		_battle_over = true
		_last_victory = true
		_active_unit = {}
		_sync_ally_hp_to_global()
		GlobalData.apply_party_battle_fatigue()
		var svc_logs: PackedStringArray = _finalize_hero_service_and_traumas(true)
		var gold_mult: float = float(GlobalData.get_party_exploration_bonuses().get("gold_bonus_mult", 1.0))
		var base_gold: int = 70 if _is_boss_battle else (50 if _is_elite_battle else 30)
		var base_mat: int = 25 if _is_boss_battle else (18 if _is_elite_battle else 10)
		var reward: Dictionary = {"gold": roundi(float(base_gold) * gold_mult), "materials": base_mat}
		GlobalData.apply_deltas(reward)
		var win_msg: String = "승리! 모든 적을 섬멸했습니다! (전리품: 골드 +%d, 자재 +%d / 직군별 전투 피로도 누적)" % [reward["gold"], reward["materials"]]
		if not svc_logs.is_empty():
			win_msg += "\n" + "\n".join(svc_logs)
		_set_log(win_msg)
		finish_phase_button.disabled = false
		skill_action_button.disabled = true
		skill2_action_button.disabled = true
		ultimate_action_button.disabled = true
		item_action_button.disabled = true
		item_overlay.visible = false
		if embedded_in_map:
			finish_phase_button.text = "던전 맵으로 복귀"
		_refresh_ui()
		_show_victory_popup(reward)
		battle_finished.emit(true)
		return true

	if allies_alive == 0:
		_battle_over = true
		_last_victory = false
		_active_unit = {}
		_sync_ally_hp_to_global()
		GlobalData.apply_party_battle_fatigue()
		var lose_svc_logs: PackedStringArray = _finalize_hero_service_and_traumas(false)
		var lose_msg: String = "패배... 아군이 전멸했습니다."
		if not lose_svc_logs.is_empty():
			lose_msg += "\n" + "\n".join(lose_svc_logs)
		_set_log(lose_msg)
		finish_phase_button.disabled = false
		skill_action_button.disabled = true
		skill2_action_button.disabled = true
		ultimate_action_button.disabled = true
		item_action_button.disabled = true
		item_overlay.visible = false
		if embedded_in_map:
			finish_phase_button.text = "패배 - 정산으로 이동"
		_refresh_ui()
		battle_finished.emit(false)
		return true

	return false


func _sync_ally_hp_to_global() -> void:
	for unit in _units:
		if unit["team"] != Team.ALLY:
			continue
		var uid: int = int(unit.get("hero_uid", -1))
		if uid <= 0:
			continue
		var hero: Dictionary = GlobalData.get_hero_by_uid(uid)
		if hero.is_empty():
			continue
		var cur_hp: int = int(unit.get("hp", 0))
		var base_max: int = roundi(GlobalData.get_effective_stat(hero, "max_hp"))
		GlobalData.set_hero_hp(uid, clampi(cur_hp, 0, base_max))


func _on_finish_phase_pressed() -> void:
	if not _battle_over:
		return
	victory_overlay.visible = false
	post_prep_overlay.visible = false
	if embedded_in_map:
		map_return_requested.emit(_last_victory, _is_boss_battle)
		return
	if GlobalData.current_phase == GlobalData.GamePhase.DUNGEON:
		TimeManager.advance_phase()


func _refresh_ui() -> void:
	round_label.text = "라운드 %d" % _round_number

	var enemy_front: int = get_active_front_rank(Team.ENEMY)
	var ally_front: int = get_active_front_rank(Team.ALLY)
	var enemy_front_str: String = RANK_NAMES.get(enemy_front, "전멸")
	var ally_front_str: String = RANK_NAMES.get(ally_front, "전멸")
	frontline_status_label.text = "%s  |  현재 교전 전선 — 아군: [%s]  |  적군: [%s]" % [_get_encounter_banner_text(), ally_front_str, enemy_front_str]

	var queue_parts: PackedStringArray = []
	if not _active_unit.is_empty() and int(_active_unit["hp"]) > 0:
		var active_prefix: String = "아" if _active_unit["team"] == Team.ALLY else "적"
		var eff_spd: int = roundi(StatusEffectManager.get_effective_stat(_active_unit, "speed"))
		queue_parts.append("▶[%s:%s(%d)]" % [active_prefix, _active_unit["name"], eff_spd])

	for queued in _turn_queue:
		if int(queued["hp"]) > 0:
			var prefix: String = "아" if queued["team"] == Team.ALLY else "적"
			var eff_spd: int = roundi(StatusEffectManager.get_effective_stat(queued, "speed"))
			queue_parts.append("[%s:%s(%d)]" % [prefix, queued["name"], eff_spd])

	turn_queue_label.text = "행동 큐(SPD순): " + (" → ".join(queue_parts) if not queue_parts.is_empty() else "-")

	_refresh_skill_button()
	_refresh_team_grid(Team.ALLY, ally_front)
	_refresh_team_grid(Team.ENEMY, enemy_front)


func _refresh_skill_button() -> void:
	var allow_auto_ult: bool = (
		not _battle_over
		and _is_busy
		and not _active_unit.is_empty()
		and _active_unit["team"] == Team.ALLY
		and GlobalData.auto_battle_mode == GlobalData.AutoBattleMode.AUTO_SAVE_ULT
	)
	if _battle_over or (_is_busy and not allow_auto_ult) or _active_unit.is_empty() or _active_unit["team"] != Team.ALLY:
		skill_action_button.visible = true
		skill_action_button.disabled = true
		skill_action_button.text = "스킬: 대기"
		skill2_action_button.visible = false
		ultimate_action_button.visible = false
		item_action_button.disabled = true
		item_action_button.text = "아이템 (포션)"
		return

	var rarity: String = DataManager.normalize_rarity(_active_unit.get("rarity", "N"))
	var rules: Dictionary = DataManager.get_skill_slot_rules(rarity)

	if allow_auto_ult:
		skill_action_button.visible = true
		skill_action_button.disabled = true
		skill_action_button.text = "자동 행동 중..."
		skill2_action_button.visible = false
		ultimate_action_button.visible = bool(rules["ultimate"])
		if ultimate_action_button.visible:
			_update_single_skill_button(ultimate_action_button, "ultimate")
			if not ultimate_action_button.disabled:
				ultimate_action_button.text = "[R] " + ultimate_action_button.text
		return

	skill_action_button.visible = true
	if not bool(rules["active1"]):
		skill_action_button.disabled = true
		skill_action_button.text = "액티브1: 없음 (N등급)"
	else:
		_update_single_skill_button(skill_action_button, "active1")

	skill2_action_button.visible = bool(rules["active2"])
	if skill2_action_button.visible:
		_update_single_skill_button(skill2_action_button, "active2")

	ultimate_action_button.visible = bool(rules["ultimate"])
	if ultimate_action_button.visible:
		_update_single_skill_button(ultimate_action_button, "ultimate")

	var combat_items: Array[Dictionary] = GlobalData.get_owned_items(true, false)
	if _item_targeting_mode:
		item_action_button.disabled = false
		item_action_button.text = "아이템 대상 취소"
	else:
		item_action_button.disabled = combat_items.is_empty()
		item_action_button.text = "아이템 (%d종)" % combat_items.size() if not combat_items.is_empty() else "아이템 (없음)"


func _update_single_skill_button(btn: Button, slot_name: String) -> void:
	var meta: Dictionary = _get_skill_key_for_slot(slot_name)
	var skill: Dictionary = _get_active_unit_skill(slot_name)
	if skill.is_empty():
		btn.disabled = true
		btn.text = "%s: 없음" % meta["label"]
		return
	var cd: int = int(_active_unit.get(meta["cd_key"], 0))
	if cd > 0:
		btn.disabled = true
		btn.text = "%s: %s (CD %d)" % [meta["label"], skill["name"], cd]
	elif _skill_targeting_mode and _selected_skill_slot == slot_name:
		btn.disabled = false
		btn.text = "[취소] %s" % skill["name"]
	else:
		btn.disabled = false
		btn.text = "%s: %s" % [meta["label"], skill["name"]]


func _refresh_team_grid(team: Team, active_front_rank: int) -> void:
	var is_ally_turn: bool = (
		not _battle_over
		and not _is_busy
		and not _active_unit.is_empty()
		and _active_unit["team"] == Team.ALLY
	)
	var skill: Dictionary = _get_active_unit_skill(_selected_skill_slot) if _skill_targeting_mode else {}
	var skill_scope: String = ""
	if not skill.is_empty() and not (skill.get("effects", []) as Array).is_empty():
		skill_scope = str(skill["effects"][0].get("target_scope", "SINGLE_FRONT"))
	var pending_item: Dictionary = DataManager.get_item(_pending_item_id) if _item_targeting_mode else {}
	var item_scope: String = str(pending_item.get("target_scope", ""))

	for rank in [Rank.FRONT, Rank.MIDDLE, Rank.BACK]:
		for row in range(GRID_ROWS):
			var view: Dictionary = _slot_views[team][_slot_key(rank, row)]
			var btn: Button = view["button"]
			var bg: Panel = view["bg"]
			var hp_bg: ColorRect = view["hp_bg"]
			var hp_fill: ColorRect = view["hp_fill"]

			var unit: Dictionary = _get_unit_at(team, rank, row)
			if unit.is_empty():
				btn.text = "(빈 칸)"
				btn.icon = null
				btn.disabled = true
				bg.add_theme_stylebox_override("panel", AssetManager.make_panel_style(COLOR_EMPTY_SLOT, Color(0.22, 0.25, 0.32, 0.7), 8, 1, 0))
				hp_bg.visible = false
				continue

			hp_bg.visible = true
			var is_alive: bool = int(unit["hp"]) > 0
			var is_active: bool = (not _active_unit.is_empty() and unit["id"] == _active_unit["id"])
			var eff_max_hp: int = roundi(StatusEffectManager.get_effective_stat(unit, "max_hp"))

			var hp_ratio: float = clampf(float(unit["hp"]) / float(eff_max_hp), 0.0, 1.0)
			hp_fill.anchor_right = hp_ratio

			if not is_alive:
				btn.text = "%s\n[전투불능]" % unit["name"]
				btn.icon = null
				btn.disabled = true
				bg.add_theme_stylebox_override("panel", AssetManager.make_panel_style(COLOR_DEAD_UNIT, Color(0.25, 0.25, 0.28, 0.6), 8, 1, 0))
				continue

			var is_item_ally: bool = is_ally_turn and _item_targeting_mode and item_scope == "SINGLE_ALLY" and team == Team.ALLY
			var is_item_enemy: bool = is_ally_turn and _item_targeting_mode and item_scope == "SINGLE_ENEMY" and team == Team.ENEMY
			var is_skill_target: bool = (is_ally_turn and _skill_targeting_mode and _is_valid_skill_click_target(unit, skill_scope)) or is_item_ally or is_item_enemy
			var can_heal_ally: bool = is_ally_turn and not _skill_targeting_mode and not _item_targeting_mode and _can_unit_heal(_active_unit)
			var is_healable_ally: bool = (
				team == Team.ALLY
				and (is_skill_target or (can_heal_ally and int(unit["hp"]) < eff_max_hp))
			)
			var can_back_snipe: bool = (is_ally_turn and str(_active_unit.get("sub_trait", "")) == "BACKLINE_SNIPE" and int(rank) == get_active_back_rank(Team.ENEMY))
			var is_targetable_enemy: bool = (
				team == Team.ENEMY
				and is_ally_turn
				and ((not _skill_targeting_mode and not _item_targeting_mode and (int(rank) == active_front_rank or can_back_snipe)) or is_skill_target)
			)

			var state_tag: String = ""
			if is_active:
				state_tag = " [행동]"
			elif is_skill_target:
				state_tag = " [스킬대상]"
			elif is_healable_ally:
				state_tag = " [회복]"
			elif is_targetable_enemy:
				state_tag = " [공격]"

			var elem_name: String = DataManager.get_element_name(str(unit.get("element", "")))
			var eff_atk: int = roundi(StatusEffectManager.get_effective_stat(unit, "atk"))
			var eff_spd: int = roundi(StatusEffectManager.get_effective_stat(unit, "speed"))
			var shield_val: int = StatusEffectManager.get_total_shield(unit)
			var shield_str: String = " (+%d)" % shield_val if shield_val > 0 else ""
			var badges: String = StatusEffectManager.get_active_effect_badges(unit)

			var stat_line: String = "HEAL %d | SPD %d" % [_get_heal_amount(unit), eff_spd] if (str(unit.get("class_group", "")) == "의료" or str(unit.get("job_class", "")) == "힐러") else "ATK %d | SPD %d" % [eff_atk, eff_spd]
			var status_line: String = "\n" + badges if not badges.is_empty() else ""

			btn.text = "%s[%s]%s\nHP %d/%d%s\n%s%s" % [
				unit["name"],
				elem_name,
				state_tag,
				unit["hp"],
				eff_max_hp,
				shield_str,
				stat_line,
				status_line,
			]

			if team == Team.ALLY:
				btn.icon = AssetManager.get_hero_sprite(unit)
				btn.self_modulate = Color.WHITE
				btn.disabled = not is_healable_ally
				if is_active:
					bg.add_theme_stylebox_override("panel", AssetManager.make_panel_style(COLOR_ACTIVE_TURN.darkened(0.35), Color(1.0, 0.86, 0.30, 1.0), 8, 2, 0))
				elif is_healable_ally:
					bg.add_theme_stylebox_override("panel", AssetManager.make_panel_style(COLOR_ALLY_HEALABLE.darkened(0.25), Color(0.35, 0.95, 0.65, 1.0), 8, 2, 0))
				else:
					var r_col: Color = DataManager.get_rarity_color(DataManager.normalize_rarity(unit.get("rarity", "N")))
					bg.add_theme_stylebox_override("panel", AssetManager.make_panel_style(COLOR_ALLY_NORMAL.darkened(0.2), r_col, 8, 1, 0))
			else:
				btn.icon = AssetManager.get_enemy_sprite(str(unit.get("enemy_id", "")), str(unit.get("enemy_type", "NORMAL")), str(unit.get("sprite_path", "")))
				if bool(unit.get("palette_swapped", false)) and not str(unit.get("tint_color", "")).is_empty():
					btn.self_modulate = Color.from_string(str(unit["tint_color"]), Color.WHITE).lightened(0.25)
				else:
					btn.self_modulate = Color.WHITE
				btn.disabled = not is_targetable_enemy
				if is_active:
					bg.add_theme_stylebox_override("panel", AssetManager.make_panel_style(COLOR_ACTIVE_TURN.darkened(0.35), Color(1.0, 0.86, 0.30, 1.0), 8, 2, 0))
				elif is_skill_target:
					bg.add_theme_stylebox_override("panel", AssetManager.make_panel_style(COLOR_ENEMY_SKILL_TARGET.darkened(0.25), Color(1.0, 0.62, 0.22, 1.0), 8, 2, 0))
				elif is_targetable_enemy:
					bg.add_theme_stylebox_override("panel", AssetManager.make_panel_style(COLOR_ENEMY_TARGETABLE.darkened(0.25), Color(1.0, 0.35, 0.35, 1.0), 8, 2, 0))
				elif int(rank) == active_front_rank:
					bg.add_theme_stylebox_override("panel", AssetManager.make_panel_style(COLOR_ENEMY_NORMAL.darkened(0.2), Color(0.65, 0.32, 0.35, 0.9), 8, 1, 0))
				else:
					bg.add_theme_stylebox_override("panel", AssetManager.make_panel_style(COLOR_ENEMY_BLOCKED, Color(0.35, 0.24, 0.28, 0.7), 8, 1, 0))


func _set_log(message: String) -> void:
	combat_log_label.text = message


# ==========================================
# 전투 중 포션·소비 아이템 사용
# ==========================================
func _on_item_action_pressed() -> void:
	if _battle_over or _is_busy or _active_unit.is_empty() or _active_unit["team"] != Team.ALLY:
		return
	if _item_targeting_mode:
		_item_targeting_mode = false
		_pending_item_id = ""
		_set_log("아이템 사용을 취소했습니다.")
		_refresh_ui()
		return

	_skill_targeting_mode = false
	for child in combat_items_vbox.get_children():
		child.queue_free()

	var owned: Array[Dictionary] = GlobalData.get_owned_items(true, false)
	if owned.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "전투 중 사용할 수 있는 아이템이 없습니다."
		combat_items_vbox.add_child(empty_lbl)
	else:
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
			btn.pressed.connect(_on_combat_item_chosen.bind(iid))
			row.add_child(btn)
			combat_items_vbox.add_child(row)

	item_overlay.visible = true


func _close_item_overlay() -> void:
	item_overlay.visible = false


func _on_combat_item_chosen(item_id: String) -> void:
	item_overlay.visible = false
	var item: Dictionary = DataManager.get_item(item_id)
	if item.is_empty():
		return
	var scope: String = str(item.get("target_scope", "SINGLE_ALLY"))
	if scope == "ALL_ALLIES" or scope == "ALL_ENEMIES":
		_execute_combat_item(_active_unit, item, {})
		_advance_turn()
	else:
		_item_targeting_mode = true
		_pending_item_id = item_id
		_skill_targeting_mode = false
		_set_log("[아이템: %s] 사용할 대상을 클릭하세요." % str(item.get("name", "")))
		_refresh_ui()


func _execute_combat_item(caster: Dictionary, item: Dictionary, target: Dictionary) -> void:
	var iid: String = str(item.get("id", ""))
	if not GlobalData.consume_item(iid, 1):
		_set_log("보유 수량이 부족해 [%s]을(를) 사용할 수 없습니다." % str(item.get("name", "")))
		return
	_item_targeting_mode = false
	_pending_item_id = ""

	var itype: String = str(item.get("item_type", "HEAL_HP"))
	var pwr: float = float(item.get("power", 30.0))
	var dur: float = float(maxi(1, int(item.get("duration", 3))))
	var iname: String = str(item.get("name", iid))

	match itype:
		"HEAL_HP":
			if not target.is_empty():
				var healed: int = heal_unit(target, int(round(pwr)))
				var cleansed: int = 0
				if str(item.get("rarity", "N")) != "N":
					cleansed = StatusEffectManager.clear_debuffs(target)
				var c_note: String = " + 정화(%d)" % cleansed if cleansed > 0 else ""
				_set_log("[아이템: %s] %s 체력 +%d 회복%s!" % [iname, target["name"], healed, c_note])
		"HEAL_ALL_HP":
			var allies: Array[Dictionary] = _get_living_units(Team.ALLY)
			for a in allies:
				heal_unit(a, int(round(pwr)))
			_set_log("[아이템: %s] 아군 전원 체력 +%d 회복!" % [iname, int(round(pwr))])
		"BUFF_ATK", "BUFF_DEF":
			for a in _get_living_units(Team.ALLY):
				StatusEffectManager.apply_effect(a, itype, pwr, dur, caster)
			_set_log("[아이템: %s] 아군 전원 %s +%.0f%% (%d턴)!" % [iname, StatusEffectManager.get_effect_label(itype), pwr * 100.0, int(dur)])
		"SHIELD_ALL":
			for a in _get_living_units(Team.ALLY):
				StatusEffectManager.clear_debuffs(a)
				var sh_amt: int = int(round(pwr))
				StatusEffectManager.add_flat_shield(a, sh_amt, dur, iname)
				_spawn_unit_floating_text(a, "보호막 +%d" % sh_amt, "SHIELD")
			_set_log("[아이템: %s] 아군 전원 상태이상 정화 및 보호막 +%d!" % [iname, int(round(pwr))])
		"CLEANSE":
			var total_cl: int = 0
			for a in _get_living_units(Team.ALLY):
				total_cl += StatusEffectManager.clear_debuffs(a)
				heal_unit(a, int(round(pwr)))
			_set_log("[아이템: %s] 아군 상태이상 %d건 정화!" % [iname, total_cl])
		"DAMAGE_ENEMY":
			var targets: Array[Dictionary] = [target] if (str(item.get("target_scope", "")) == "SINGLE_ENEMY" and not target.is_empty()) else _get_living_units(Team.ENEMY)
			var dmg_amt: int = maxi(1, int(round(pwr)))
			for e in targets:
				var it_res: Dictionary = StatusEffectManager.apply_damage_with_shield(e, dmg_amt)
				_spawn_unit_damage_float(e, dmg_amt, false, 1.0, int(it_res["shield_absorbed"]))
			_set_log("[아이템: %s] 적 %d기에게 %d 고정 피해!" % [iname, targets.size(), dmg_amt])


# ==========================================
# 전투 승리 알림창 & 전투 후 정비 오버레이
# ==========================================
func _show_victory_popup(reward: Dictionary) -> void:
	victory_title_label.text = "★ 보스전 승리!" if _is_boss_battle else ("★ 정예 전투 승리!" if _is_elite_battle else "★ 전투 승리!")
	var party_lines: PackedStringArray = []
	for h in GlobalData.get_active_party_heroes():
		var m_hp: int = maxi(1, roundi(GlobalData.get_effective_stat(h, "max_hp")))
		party_lines.append("%s: HP %d/%d (피로 %d%%)" % [
			str(h.get("name", "영웅")),
			int(h.get("hp", 0)),
			m_hp,
			int(h.get("fatigue", 0)),
		])
	var party_text: String = "\n".join(party_lines) if not party_lines.is_empty() else "생존 아군 없음"
	victory_summary_label.text = (
		"전투에서 승리했습니다!\n"
		+ "전리품 획득: 골드 +%d, 자재 +%d (직군별 피로도 누적)\n\n"
		+ "[출정 파티 현재 상태]\n%s\n\n"
		+ "전투 후 포션으로 정비한 뒤 돌아갈지, 바로 복귀할지 선택하세요."
	) % [int(reward.get("gold", 0)), int(reward.get("materials", 0)), party_text]
	victory_direct_return_button.text = "바로 던전으로 돌아가기" if embedded_in_map else "바로 다음으로 진행"
	victory_prep_button.visible = embedded_in_map
	post_prep_done_button.text = "정비 완료 · 던전으로 복귀" if embedded_in_map else "정비 완료 · 다음 진행"
	victory_overlay.visible = true


func _open_post_prep_overlay() -> void:
	victory_overlay.visible = false
	post_prep_status_label.text = ""
	post_prep_overlay.visible = true
	_refresh_post_prep_overlay()


func _refresh_post_prep_overlay() -> void:
	for child in post_prep_hero_hbox.get_children():
		child.queue_free()
	for child in post_prep_items_vbox.get_children():
		child.queue_free()

	var party: Array[Dictionary] = GlobalData.get_active_party_heroes()
	if _prep_target_hero_uid < 0 or GlobalData.get_hero_by_uid(_prep_target_hero_uid).is_empty():
		if not party.is_empty():
			_prep_target_hero_uid = int(party[0].get("uid", -1))

	for h in party:
		var uid: int = int(h.get("uid", -1))
		var max_hp: int = maxi(1, roundi(GlobalData.get_effective_stat(h, "max_hp")))
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_font_size_override("font_size", 12)
		var sel: bool = (uid == _prep_target_hero_uid)
		b.text = "%s%s\nHP %d/%d | 피로 %d%%" % ["▶ " if sel else "", str(h.get("name", "영웅")), int(h.get("hp", 0)), max_hp, int(h.get("fatigue", 0))]
		b.modulate = Color(0.55, 0.92, 1.0) if sel else Color.WHITE
		b.pressed.connect(_on_prep_hero_selected.bind(uid))
		post_prep_hero_hbox.add_child(b)

	var owned: Array[Dictionary] = GlobalData.get_owned_items(false, true)
	if owned.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "정비에 사용할 수 있는 포션/강장제 아이템이 없습니다."
		post_prep_items_vbox.add_child(empty_lbl)
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
		var use_btn := Button.new()
		use_btn.custom_minimum_size = Vector2(140, 40)
		use_btn.text = "사용"
		use_btn.pressed.connect(_on_prep_use_item_pressed.bind(iid))
		row.add_child(use_btn)
		post_prep_items_vbox.add_child(row)


func _on_prep_hero_selected(uid: int) -> void:
	_prep_target_hero_uid = uid
	_refresh_post_prep_overlay()


func _on_prep_use_item_pressed(item_id: String) -> void:
	var it: Dictionary = DataManager.get_item(item_id)
	if it.is_empty():
		return
	var itype: String = str(it.get("item_type", "HEAL_HP"))
	var pwr: float = float(it.get("power", 30.0))

	if itype == "HEAL_HP":
		var hero: Dictionary = GlobalData.get_hero_by_uid(_prep_target_hero_uid)
		if hero.is_empty():
			return
		var max_hp: int = roundi(GlobalData.get_effective_stat(hero, "max_hp"))
		if int(hero.get("hp", 0)) >= max_hp:
			post_prep_status_label.text = "%s은(는) 이미 최대 체력입니다." % str(hero.get("name", ""))
			post_prep_status_label.modulate = Color(1.0, 0.78, 0.35)
			return
		if not GlobalData.consume_item(item_id, 1):
			return
		var gained: int = GlobalData.heal_hero(_prep_target_hero_uid, int(round(pwr)))
		post_prep_status_label.text = "[%s] 사용! %s 체력 +%d 회복." % [str(it.get("name", "")), str(hero.get("name", "")), gained]
	elif itype == "HEAL_ALL_HP":
		if not GlobalData.consume_item(item_id, 1):
			return
		for h in GlobalData.get_active_party_heroes():
			if int(h.get("hp", 0)) > 0:
				GlobalData.heal_hero(int(h.get("uid", -1)), int(round(pwr)))
		post_prep_status_label.text = "[%s] 사용! 파티 전원 체력 +%d 회복." % [str(it.get("name", "")), int(round(pwr))]
	elif itype == "RECOVER_FATIGUE":
		if not GlobalData.consume_item(item_id, 1):
			return
		for h in GlobalData.get_active_party_heroes():
			GlobalData.recover_hero_fatigue(int(h.get("uid", -1)), int(round(pwr)))
		post_prep_status_label.text = "[%s] 사용! 파티 전원 피로도 -%d 감소." % [str(it.get("name", "")), int(round(pwr))]
	post_prep_status_label.modulate = Color(0.55, 0.95, 0.65)
	_refresh_post_prep_overlay()
