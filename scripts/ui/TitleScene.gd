extends Control
## 메인 타이틀 씬 컨트롤러
## - '게임 시작'과 '설정' 두 가지 선택지 제공
## - '게임 시작' 선택 시 최대 3개 저장 데이터 슬롯을 불러오거나 새 게임 시작

const MAIN_GAME_SCENE_PATH: String = "res://scenes/MainGame.tscn"

@onready var main_menu_panel: Control = %MainMenuPanel
@onready var start_game_button: Button = %StartGameButton
@onready var settings_button: Button = %SettingsButton

@onready var save_slots_panel: Control = %SaveSlotsPanel
@onready var slots_vbox: VBoxContainer = %SlotsVBox
@onready var save_back_button: Button = %SaveBackButton

@onready var settings_panel: Control = %SettingsPanel
@onready var master_slider: HSlider = %MasterSlider
@onready var master_value_label: Label = %MasterValueLabel
@onready var bgm_slider: HSlider = %BgmSlider
@onready var bgm_value_label: Label = %BgmValueLabel
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_value_label: Label = %SfxValueLabel
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var settings_status_label: Label = %SettingsStatusLabel
@onready var settings_save_button: Button = %SettingsSaveButton
@onready var settings_back_button: Button = %SettingsBackButton


func _ready() -> void:
	start_game_button.pressed.connect(_on_start_game_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	save_back_button.pressed.connect(_show_main_menu)
	settings_back_button.pressed.connect(_show_main_menu)
	settings_save_button.pressed.connect(_on_settings_save_pressed)

	master_slider.value_changed.connect(func(v: float) -> void: master_value_label.text = "%d%%" % roundi(v * 100.0))
	bgm_slider.value_changed.connect(func(v: float) -> void: bgm_value_label.text = "%d%%" % roundi(v * 100.0))
	sfx_slider.value_changed.connect(func(v: float) -> void: sfx_value_label.text = "%d%%" % roundi(v * 100.0))

	SaveManager.save_slots_updated.connect(_refresh_save_slots)
	_show_main_menu()


func _show_main_menu() -> void:
	main_menu_panel.visible = true
	save_slots_panel.visible = false
	settings_panel.visible = false


func _on_start_game_pressed() -> void:
	main_menu_panel.visible = false
	save_slots_panel.visible = true
	settings_panel.visible = false
	_refresh_save_slots()


func _on_settings_pressed() -> void:
	main_menu_panel.visible = false
	save_slots_panel.visible = false
	settings_panel.visible = true
	_load_settings_to_ui()


func _refresh_save_slots() -> void:
	for child in slots_vbox.get_children():
		child.queue_free()

	for slot_idx in range(1, SaveManager.MAX_SLOTS + 1):
		var summary: Dictionary = SaveManager.get_slot_summary(slot_idx)
		var card := _build_slot_card(slot_idx, summary)
		slots_vbox.add_child(card)


func _build_slot_card(slot_idx: int, summary: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)

	var title_lbl := Label.new()
	title_lbl.add_theme_font_size_override("font_size", 17)

	var detail_lbl := Label.new()
	detail_lbl.add_theme_font_size_override("font_size", 13)

	var exists: bool = bool(summary.get("exists", false))
	if exists:
		var season_enum: TimeManager.Season = int(summary["season"]) as TimeManager.Season
		var phase_enum: GlobalData.GamePhase = int(summary["phase"]) as GlobalData.GamePhase
		title_lbl.text = "슬롯 %d  —  %d년차 %s %d일 (총 %d일차) [%s]" % [
			slot_idx,
			summary["year"],
			TimeManager.get_season_name(season_enum),
			summary["day_of_month"],
			summary["total_day"],
			TimeManager.get_phase_name(phase_enum),
		]
		detail_lbl.text = "골드 %d | 식량 %d | 자재 %d | 성벽 %d/%d   (저장: %s)" % [
			summary["gold"],
			summary["food"],
			summary["materials"],
			summary["wall_hp"],
			summary["wall_max_hp"],
			summary["saved_at"],
		]
	else:
		title_lbl.text = "슬롯 %d  —  [비어 있음]" % slot_idx
		detail_lbl.text = "저장된 데이터가 없습니다. 새 게임을 시작할 수 있습니다."

	info_vbox.add_child(title_lbl)
	info_vbox.add_child(detail_lbl)

	if exists:
		var load_btn := Button.new()
		load_btn.custom_minimum_size = Vector2(105, 42)
		load_btn.text = "불러오기"
		load_btn.pressed.connect(_on_load_slot_pressed.bind(slot_idx))
		hbox.add_child(load_btn)

		var delete_btn := Button.new()
		delete_btn.custom_minimum_size = Vector2(76, 42)
		delete_btn.text = "삭제"
		delete_btn.pressed.connect(_on_delete_slot_pressed.bind(slot_idx))
		hbox.add_child(delete_btn)
	else:
		var new_btn := Button.new()
		new_btn.custom_minimum_size = Vector2(130, 42)
		new_btn.text = "새 게임 시작"
		new_btn.pressed.connect(_on_new_slot_pressed.bind(slot_idx))
		hbox.add_child(new_btn)

	return panel


func _on_load_slot_pressed(slot_idx: int) -> void:
	if SaveManager.load_from_slot(slot_idx):
		get_tree().change_scene_to_file(MAIN_GAME_SCENE_PATH)


func _on_new_slot_pressed(slot_idx: int) -> void:
	SaveManager.start_new_game_in_slot(slot_idx)
	get_tree().change_scene_to_file(MAIN_GAME_SCENE_PATH)


func _on_delete_slot_pressed(slot_idx: int) -> void:
	SaveManager.delete_slot(slot_idx)


func _load_settings_to_ui() -> void:
	master_slider.value = SaveManager.master_volume
	master_value_label.text = "%d%%" % roundi(SaveManager.master_volume * 100.0)
	bgm_slider.value = SaveManager.bgm_volume
	bgm_value_label.text = "%d%%" % roundi(SaveManager.bgm_volume * 100.0)
	sfx_slider.value = SaveManager.sfx_volume
	sfx_value_label.text = "%d%%" % roundi(SaveManager.sfx_volume * 100.0)
	fullscreen_check.button_pressed = SaveManager.fullscreen
	settings_status_label.text = ""


func _on_settings_save_pressed() -> void:
	SaveManager.save_settings(
		master_slider.value,
		bgm_slider.value,
		sfx_slider.value,
		fullscreen_check.button_pressed
	)
	settings_status_label.text = "설정이 저장 및 적용되었습니다."
