extends Control
## 영지 경영 및 던전 탐험 중 현재 월(30일), 5일 주기 디펜스 데이, 3년차 6단계 시기를 확인하는 공용 달력 모달

@onready var cal_title_label: Label = %CalTitleLabel
@onready var cal_meta_label: Label = %CalMetaLabel
@onready var cal_grid: GridContainer = %CalGrid
@onready var cal_stage_label: Label = %CalStageLabel
@onready var cal_close_button: Button = %CalCloseButton


func _ready() -> void:
	cal_close_button.pressed.connect(close_calendar)
	visible = false


func open_calendar() -> void:
	refresh_calendar()
	visible = true


func close_calendar() -> void:
	visible = false


func refresh_calendar() -> void:
	var cur_year: int = TimeManager.current_year
	var cur_month: int = TimeManager.current_month
	var cur_day: int = TimeManager.current_day_of_month
	var season_name: String = TimeManager.get_season_name()
	var stage: int = TimeManager.get_event_stage()
	var stage_label: String = TimeManager.get_event_stage_label(stage)
	var scale_mult: float = TimeManager.get_event_scale_multiplier(stage)
	var days_left: int = TimeManager.get_days_until_defense()

	cal_title_label.text = "%d년차 %d월 (%s) — 영지 달력 (매 5일 주기 디펜스 데이)" % [
		cur_year,
		cur_month,
		season_name,
	]

	var d_day_str: String = "오늘 밤 방어전 (D-Day)" if days_left == 0 else "D-%d (%d일 후)" % [days_left, days_left]
	var debuff_str: String = GlobalData.get_territory_debuff_summary()
	var debuff_part: String = "  |  " + debuff_str if not debuff_str.is_empty() else ""
	cal_meta_label.text = "시기: [%s · 이벤트 스케일 ×%.2f]  |  다음 디펜스: %s  |  반란 위험도: %d/10%s\n예상 디펜스 적 속성: [%s]" % [
		stage_label,
		scale_mult,
		d_day_str,
		GlobalData.rebellion_risk,
		debuff_part,
		GlobalData.get_upcoming_defense_elements_text(),
	]

	for child in cal_grid.get_children():
		child.queue_free()

	for d in range(1, TimeManager.DAYS_PER_MONTH + 1):
		var is_today: bool = (d == cur_day)
		var is_def: bool = TimeManager.is_defense_day(d)
		var is_past: bool = (d < cur_day)

		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(168, 64)
		if is_today:
			cell.self_modulate = Color(0.32, 0.78, 1.0, 1.0)
		elif is_def:
			cell.self_modulate = Color(0.88, 0.34, 0.28, 1.0) if not is_past else Color(0.45, 0.24, 0.22, 0.85)
		elif is_past:
			cell.self_modulate = Color(0.24, 0.26, 0.30, 0.72)
		else:
			cell.self_modulate = Color(0.34, 0.38, 0.44, 0.95)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_bottom", 6)
		cell.add_child(margin)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		margin.add_child(vb)

		var top_lbl := Label.new()
		top_lbl.add_theme_font_size_override("font_size", 14)
		top_lbl.text = "%d일 %s" % [d, "★오늘" if is_today else ("(지남)" if is_past else "")]
		if is_today:
			top_lbl.modulate = Color(0.65, 0.96, 1.0)
		vb.add_child(top_lbl)

		var tag_lbl := Label.new()
		tag_lbl.add_theme_font_size_override("font_size", 12)
		if is_def:
			tag_lbl.text = "⚔ 5일 디펜스 데이"
			tag_lbl.modulate = Color(1.0, 0.72, 0.52) if not is_past else Color(0.75, 0.55, 0.55)
		else:
			tag_lbl.text = "평일 (내정·던전)"
			tag_lbl.modulate = Color(0.78, 0.84, 0.90) if not is_past else Color(0.55, 0.58, 0.62)
		vb.add_child(tag_lbl)

		cal_grid.add_child(cell)

	var stage_parts: PackedStringArray = []
	for s in range(1, 7):
		var marker: String = "▶" if s == stage else ""
		stage_parts.append("%s%d단계(%d~%d월)" % [marker, s, (s - 1) * 2 + 1, s * 2])
	cal_stage_label.text = "3년차 6단계 로드맵: " + "  →  ".join(stage_parts)
