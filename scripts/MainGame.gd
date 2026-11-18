extends Control
## 게임 전체 루프를 총괄하는 최상위 컨트롤러 (MainGame)
## - TimeManager 및 GlobalData 상태에 따라 ManagementScene / DungeonMapScene / OffenseScene / DefenseScene 전환
## - 하루 정산(SETTLEMENT) 처리 및 다음 날 진행
## - 성벽 파괴 또는 오펜스 전멸 시 게임 오버 UI 표시

const TITLE_SCENE_PATH: String = "res://scenes/ui/TitleScene.tscn"

@onready var top_bar: PanelContainer = %TopBar
@onready var date_label: Label = %DateLabel
@onready var day_type_label: Label = %DayTypeLabel
@onready var phase_label: Label = %PhaseLabel
@onready var resource_label: Label = %ResourceLabel
@onready var save_button: Button = %SaveButton
@onready var title_button: Button = %TitleButton
@onready var reset_game_button: Button = %ResetGameButton

@onready var management_scene: Control = %ManagementScene
@onready var town_phase_scene: Control = %TownPhaseScene
@onready var dungeon_map_scene: Control = %DungeonMapScene
@onready var offense_scene: Control = %OffenseScene
@onready var defense_scene: Control = %DefenseScene

@onready var settlement_panel: Control = %SettlementPanel
@onready var settlement_title_label: Label = %SettlementTitleLabel
@onready var settlement_summary_label: Label = %SettlementSummaryLabel
@onready var settlement_next_day_button: Button = %SettlementNextDayButton

@onready var game_over_overlay: ColorRect = %GameOverOverlay
@onready var game_over_panel: PanelContainer = %GameOverPanel
@onready var game_over_reason_label: Label = %GameOverReasonLabel
@onready var game_over_record_label: Label = %GameOverRecordLabel
@onready var game_over_restart_button: Button = %GameOverRestartButton
@onready var game_over_title_button: Button = %GameOverTitleButton

@onready var game_victory_overlay: ColorRect = %GameVictoryOverlay
@onready var victory_panel: PanelContainer = %VictoryPanel
@onready var victory_rank_label: Label = %VictoryRankLabel
@onready var victory_territory_label: Label = %VictoryTerritoryLabel
@onready var victory_stats_label: Label = %VictoryStatsLabel
@onready var victory_endless_button: Button = %VictoryEndlessButton
@onready var victory_title_button: Button = %VictoryTitleButton

var _in_offense_combat: bool = false
var _is_game_over: bool = false


func _ready() -> void:
	var top_style := AssetManager.make_panel_style(Color(0.08, 0.10, 0.16, 0.98), Color(0.55, 0.45, 0.24, 0.75), 0, 0, 0)
	top_style.border_width_bottom = 2
	top_bar.add_theme_stylebox_override("panel", top_style)
	game_over_panel.add_theme_stylebox_override(
		"panel",
		AssetManager.make_panel_style(Color(0.11, 0.06, 0.08, 0.96), Color(0.85, 0.28, 0.28, 0.9), 10, 2, 0)
	)
	victory_panel.add_theme_stylebox_override(
		"panel",
		AssetManager.make_panel_style(Color(0.09, 0.11, 0.17, 0.97), AssetManager.COL_BORDER_GOLD, 12, 2, 0)
	)

	TimeManager.time_updated.connect(_on_time_updated)
	GlobalData.phase_changed.connect(_on_phase_changed)
	GlobalData.resources_changed.connect(_on_global_stats_changed)
	GlobalData.morale_changed.connect(_on_global_stats_changed)
	GlobalData.wall_hp_changed.connect(_on_global_stats_changed)
	GlobalData.wall_destroyed.connect(_on_wall_destroyed)
	GlobalData.game_reset.connect(_on_game_reset)

	dungeon_map_scene.combat_requested.connect(_on_dungeon_combat_requested)
	dungeon_map_scene.return_to_town_requested.connect(_on_dungeon_return_to_town)
	offense_scene.map_return_requested.connect(_on_offense_return_requested)
	offense_scene.battle_finished.connect(_on_offense_battle_finished)
	defense_scene.defense_finished.connect(_on_defense_finished)

	settlement_next_day_button.pressed.connect(_on_settlement_next_day_pressed)
	save_button.pressed.connect(_on_save_pressed)
	title_button.pressed.connect(_on_return_to_title_pressed)
	reset_game_button.pressed.connect(_on_restart_pressed)
	game_over_restart_button.pressed.connect(_on_restart_pressed)
	game_over_title_button.pressed.connect(_on_return_to_title_pressed)
	victory_endless_button.pressed.connect(_on_victory_endless_pressed)
	victory_title_button.pressed.connect(_on_return_to_title_pressed)

	game_over_overlay.visible = false
	game_victory_overlay.visible = false
	if GlobalData.current_phase == GlobalData.GamePhase.SETTLEMENT:
		_run_daily_settlement()
	_sync_all_views()


func _on_time_updated() -> void:
	_sync_all_views()


func _on_phase_changed(new_phase: GlobalData.GamePhase) -> void:
	_in_offense_combat = false
	if new_phase == GlobalData.GamePhase.SETTLEMENT:
		_run_daily_settlement()
	_sync_all_views()


func _on_global_stats_changed(_a = null, _b = null) -> void:
	_refresh_top_bar()


func _on_game_reset() -> void:
	_in_offense_combat = false
	_is_game_over = false
	game_over_overlay.visible = false
	game_victory_overlay.visible = false
	save_button.text = "저장"


## 던전 노드맵에서 전투/정예/보스 노드 클릭 시 OffenseScene으로 전환
func _on_dungeon_combat_requested(is_boss: bool, atk_bonus: int, hp_bonus: int, is_elite: bool = false, encounter_type: String = "NORMAL") -> void:
	if _is_game_over:
		return
	_in_offense_combat = true
	_sync_all_views()
	offense_scene.start_battle(is_boss, atk_bonus, hp_bonus, is_elite, encounter_type)


## 던전 노드맵에서 귀환(포탈/버튼) 시 정산으로 이동
func _on_dungeon_return_to_town() -> void:
	if _is_game_over:
		return
	_in_offense_combat = false
	if GlobalData.current_phase == GlobalData.GamePhase.DUNGEON:
		TimeManager.advance_phase()


## OffenseScene에서 전투 완료 후 던전 맵으로 복귀
func _on_offense_return_requested(victory: bool, is_boss: bool) -> void:
	if _is_game_over:
		return
	if not victory:
		_trigger_game_over("오펜스 던전에서 아군이 전멸했습니다.")
		return

	_in_offense_combat = false
	dungeon_map_scene.on_external_combat_victory(is_boss)
	_sync_all_views()


## 오펜스 전투 패배(전멸) 즉시 게임 오버 처리
func _on_offense_battle_finished(victory: bool) -> void:
	if not victory and not _is_game_over:
		_trigger_game_over("오펜스 던전에서 아군이 전멸했습니다.")


## 디펜스 종료 처리 (성벽 파괴 시 게임 오버 / 3년차 최종 결전 승리 시 엔딩 화면)
func _on_defense_finished(victory: bool) -> void:
	if _is_game_over:
		return
	if not victory:
		_trigger_game_over("성벽이 붕괴되어 몬스터 침공을 막지 못했습니다.")
		return
	if TimeManager.is_final_battle_day():
		_trigger_victory_ending()


func _on_wall_destroyed() -> void:
	if not _is_game_over:
		defense_scene.stop_battle()
		_trigger_game_over("성벽 체력이 0이 되어 성벽이 붕괴되었습니다.")


func _run_daily_settlement() -> void:
	var upkeep_note: String = "오늘의 식량 정산이 완료되었습니다."
	if GlobalData.last_settled_day != GlobalData.current_day:
		GlobalData.last_settled_day = GlobalData.current_day

		var upkeep: int = GlobalData.population
		var current_food: int = GlobalData.get_resource("food")

		if current_food >= upkeep:
			GlobalData.add_resource("food", -upkeep)
			upkeep_note = "시민 배급 식량 소비: -%d\n야간 숙영 휴식: 보유 영웅 전원 피로도 -25 회복" % upkeep
		else:
			var deficit: int = upkeep - current_food
			GlobalData.add_resource("food", -current_food)
			GlobalData.add_morale(-10)
			upkeep_note = "식량 부족(-%d)! 보유 식량 소진 및 시민 사기 -10\n야간 숙영 휴식: 보유 영웅 전원 피로도 -25 회복" % deficit

		GlobalData.recover_all_roster_fatigue(25)
		GlobalData.tick_territory_debuff_day()

	var debuff_note: String = GlobalData.get_territory_debuff_summary()
	if not debuff_note.is_empty():
		upkeep_note += "\n" + debuff_note

	var next_day_num: int = TimeManager.current_day_of_month + 1
	if next_day_num > TimeManager.DAYS_PER_MONTH:
		next_day_num = 1
	var next_is_defense: bool = TimeManager.is_defense_day(next_day_num)
	var tomorrow_notice: String = (
		"⚠ 내일(%d일)은 [디펜스 데이]입니다! 성벽 방어를 준비하세요." % next_day_num
		if next_is_defense
		else "내일(%d일)은 [평일]입니다." % next_day_num
	)

	settlement_title_label.text = "%d년차 %s %d일 정산 완료" % [
		TimeManager.current_year,
		TimeManager.get_season_name(),
		TimeManager.current_day_of_month,
	]
	settlement_summary_label.text = (
		"%s\n\n"
		+ "[현재 보유 현황]\n"
		+ "식량: %d  |  자재: %d  |  골드: %d\n"
		+ "시민 사기: %d/%d  |  성벽 HP: %d/%d\n\n"
		+ "%s"
	) % [
		upkeep_note,
		GlobalData.get_resource("food"),
		GlobalData.get_resource("materials"),
		GlobalData.get_resource("gold"),
		GlobalData.citizen_morale,
		GlobalData.MAX_MORALE,
		GlobalData.wall_hp,
		GlobalData.wall_max_hp,
		tomorrow_notice,
	]


func _on_settlement_next_day_pressed() -> void:
	if _is_game_over:
		return
	if GlobalData.current_phase == GlobalData.GamePhase.SETTLEMENT:
		TimeManager.advance_phase()
		SaveManager.save_to_slot(SaveManager.active_slot)


func _on_save_pressed() -> void:
	if _is_game_over:
		return
	if SaveManager.save_to_slot(SaveManager.active_slot):
		save_button.text = "저장됨 (슬롯%d)" % SaveManager.active_slot
		await get_tree().create_timer(1.2).timeout
		if is_inside_tree():
			save_button.text = "저장"


func _on_return_to_title_pressed() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)


func _trigger_game_over(reason: String) -> void:
	_is_game_over = true
	game_over_reason_label.text = reason
	game_over_record_label.text = "생존 기록: %d년차 %s %d일 (총 %d일차)" % [
		TimeManager.current_year,
		TimeManager.get_season_name(),
		TimeManager.current_day_of_month,
		GlobalData.current_day,
	]
	game_over_overlay.visible = true


func _trigger_victory_ending() -> void:
	GlobalData.victory_achieved = true
	var rank_info: Dictionary = GlobalData.evaluate_victory_rank()
	victory_rank_label.text = "최종 평가: %s 랭크 — %s (종합 점수 %d점)" % [
		str(rank_info.get("rank", "C")),
		str(rank_info.get("title", "")),
		int(rank_info.get("score", 0)),
	]
	victory_rank_label.modulate = rank_info.get("color", Color.WHITE)

	var named_heroes: Array[Dictionary] = GlobalData.get_owned_named_heroes()
	var named_lines: PackedStringArray = []
	for nh in named_heroes:
		var r: String = DataManager.normalize_rarity(nh.get("rarity", "SR"))
		var n_name: String = str(nh.get("name", "영웅"))
		var n_title: String = str(nh.get("named_title", ""))
		var title_part: String = " «%s»" % n_title if not n_title.is_empty() else ""
		named_lines.append("• ★ [%s] %s%s (Lv.%d · %s)" % [
			r,
			n_name,
			title_part,
			int(nh.get("level", 1)),
			str(nh.get("job_class", "")),
		])
	var named_block: String = "\n".join(named_lines) if not named_lines.is_empty() else "• 보유 중인 네임드 영웅 없음"

	victory_territory_label.text = (
		"[영지 최종 상태]\n"
		+ "• 달성 시점: %d년차 %s %d일 (총 %d일차)\n"
		+ "• 시민 사기: %d / %d\n"
		+ "• 성벽 등급: Lv.%d (내구도 %d / %d)\n"
		+ "• 시설 현황: 농장 Lv.%d  |  제재소 Lv.%d\n"
		+ "• 연구 완료: %d / %d종\n"
		+ "• 총 보유 영웅: %d명 (네임드 %d명)\n\n"
		+ "[보유 네임드 영웅 목록]\n%s"
	) % [
		TimeManager.current_year,
		TimeManager.get_season_name(),
		TimeManager.current_day_of_month,
		GlobalData.current_day,
		GlobalData.citizen_morale,
		GlobalData.MAX_MORALE,
		GlobalData.wall_level,
		GlobalData.wall_hp,
		GlobalData.wall_max_hp,
		GlobalData.farm_level,
		GlobalData.lumber_mill_level,
		GlobalData.completed_research_ids.size(),
		DataManager.researches.size(),
		GlobalData.hero_roster.size(),
		named_heroes.size(),
		named_block,
	]

	var st: Dictionary = GlobalData.run_stats
	victory_stats_label.text = (
		"[누적 클리어 통계]\n\n"
		+ "• 성벽 디펜스 승리: %d회\n\n"
		+ "• 던전 보스 격파: %d회\n\n"
		+ "• 던전 클리어: %d회\n\n"
		+ "• 영웅 영입: %d명\n\n"
		+ "• 정책 · 던전 이벤트 해결: %d건\n\n"
		+ "• 최종 보유 자원: 골드 %d | 식량 %d | 자재 %d"
	) % [
		int(st.get("defenses_won", 0)),
		int(st.get("bosses_defeated", 0)),
		int(st.get("dungeons_cleared", 0)),
		int(st.get("heroes_recruited", 0)),
		int(st.get("events_resolved", 0)),
		GlobalData.get_resource("gold"),
		GlobalData.get_resource("food"),
		GlobalData.get_resource("materials"),
	]

	game_victory_overlay.visible = true


func _on_victory_endless_pressed() -> void:
	GlobalData.is_endless_mode = true
	GlobalData.victory_achieved = true
	game_victory_overlay.visible = false
	if GlobalData.current_phase == GlobalData.GamePhase.DEFENSE:
		TimeManager.advance_phase()
	SaveManager.save_to_slot(SaveManager.active_slot)
	_sync_all_views()


func _on_restart_pressed() -> void:
	TimeManager.reset_time()
	_sync_all_views()


func _sync_all_views() -> void:
	_refresh_top_bar()

	var phase: GlobalData.GamePhase = GlobalData.current_phase
	management_scene.visible = (phase == GlobalData.GamePhase.MANAGEMENT)
	town_phase_scene.visible = (phase == GlobalData.GamePhase.TOWN)
	dungeon_map_scene.visible = (phase == GlobalData.GamePhase.DUNGEON and not _in_offense_combat)
	offense_scene.visible = (phase == GlobalData.GamePhase.DUNGEON and _in_offense_combat)
	defense_scene.visible = (phase == GlobalData.GamePhase.DEFENSE)
	settlement_panel.visible = (phase == GlobalData.GamePhase.SETTLEMENT)


func _refresh_top_bar() -> void:
	date_label.text = "%d년차 %s (%d월) %d일 [총 %d일]" % [
		TimeManager.current_year,
		TimeManager.get_season_name(),
		TimeManager.current_month,
		TimeManager.current_day_of_month,
		GlobalData.current_day,
	]

	if TimeManager.is_final_battle_day():
		day_type_label.text = "[★ 최종 결전일]"
		day_type_label.modulate = Color(1.0, 0.82, 0.25)
	elif TimeManager.is_defense_day():
		day_type_label.text = "[엔드리스 · 디펜스 데이]" if GlobalData.is_endless_mode else "[디펜스 데이]"
		day_type_label.modulate = Color(1.0, 0.45, 0.35)
	elif GlobalData.is_endless_mode:
		day_type_label.text = "[엔드리스 · 평일]"
		day_type_label.modulate = Color(0.65, 1.0, 0.72)
	else:
		day_type_label.text = "[평일]"
		day_type_label.modulate = Color(0.55, 0.9, 1.0)

	var phase_text: String = TimeManager.get_phase_name()
	if GlobalData.current_phase == GlobalData.GamePhase.DUNGEON:
		phase_text = "오펜스 (3x3 전투)" if _in_offense_combat else "오펜스 (던전 탐험)"
	phase_label.text = "페이즈: %s" % phase_text

	resource_label.text = "식량 %d | 자재 %d | 골드 %d | 사기 %d | 성벽 %d/%d" % [
		GlobalData.get_resource("food"),
		GlobalData.get_resource("materials"),
		GlobalData.get_resource("gold"),
		GlobalData.citizen_morale,
		GlobalData.wall_hp,
		GlobalData.wall_max_hp,
	]
