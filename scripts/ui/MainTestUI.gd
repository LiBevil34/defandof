extends Control
## TimeManager 및 GlobalData 연동 테스트용 메인 UI 컨트롤러
## 평일 내정(MANAGEMENT) 페이즈에서는 ManagementScene을 표시합니다.

@onready var date_label: Label = %DateLabel
@onready var day_type_label: Label = %DayTypeLabel
@onready var phase_label: Label = %PhaseLabel
@onready var phase_center_label: Label = %PhaseCenterLabel
@onready var flow_label: Label = %FlowLabel
@onready var next_phase_button: Button = %NextPhaseButton
@onready var skip_day_button: Button = %SkipDayButton
@onready var reset_button: Button = %ResetButton
@onready var management_scene: Control = %ManagementScene
@onready var town_phase_scene: Control = %TownPhaseScene
@onready var dungeon_map_scene: Control = %DungeonMapScene
@onready var defense_scene: Control = %DefenseScene
@onready var center_container: CenterContainer = %CenterContainer


func _ready() -> void:
	TimeManager.time_updated.connect(_refresh_ui)
	GlobalData.phase_changed.connect(_on_phase_changed)

	next_phase_button.pressed.connect(_on_next_phase_pressed)
	skip_day_button.pressed.connect(_on_skip_day_pressed)
	reset_button.pressed.connect(_on_reset_pressed)

	_refresh_ui()


func _on_next_phase_pressed() -> void:
	TimeManager.advance_phase()


func _on_skip_day_pressed() -> void:
	var start_day: int = GlobalData.current_day
	while GlobalData.current_day == start_day:
		TimeManager.advance_phase()


func _on_reset_pressed() -> void:
	TimeManager.reset_time()


func _on_phase_changed(_new_phase: GlobalData.GamePhase) -> void:
	_refresh_ui()


func _refresh_ui() -> void:
	var season_name: String = TimeManager.get_season_name()
	date_label.text = "%d년차 %s (%d월) %d일  |  총 %d일차" % [
		TimeManager.current_year,
		season_name,
		TimeManager.current_month,
		TimeManager.current_day_of_month,
		GlobalData.current_day,
	]

	if TimeManager.is_defense_day():
		day_type_label.text = "[디펜스 데이]"
		day_type_label.modulate = Color(1.0, 0.45, 0.35)
	else:
		day_type_label.text = "[평일]"
		day_type_label.modulate = Color(0.55, 0.9, 1.0)

	var phase_name: String = TimeManager.get_phase_name()
	phase_label.text = "페이즈: %s" % phase_name
	phase_center_label.text = "현재 페이즈: %s" % phase_name
	flow_label.text = "오늘의 순환: %s" % TimeManager.get_today_flow_text()

	var is_management: bool = (GlobalData.current_phase == GlobalData.GamePhase.MANAGEMENT)
	var is_town: bool = (GlobalData.current_phase == GlobalData.GamePhase.TOWN)
	var is_offense: bool = (GlobalData.current_phase == GlobalData.GamePhase.DUNGEON)
	var is_defense: bool = (GlobalData.current_phase == GlobalData.GamePhase.DEFENSE)
	management_scene.visible = is_management
	town_phase_scene.visible = is_town
	dungeon_map_scene.visible = is_offense
	defense_scene.visible = is_defense
	center_container.visible = not is_management and not is_town and not is_offense and not is_defense
