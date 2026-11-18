class_name CombatFeedbackUI
extends RefCounted
## 전투 공용 시각 피드백 유틸리티:
## - 플로팅 데미지/치명타/상성/회복/보호막 텍스트 연출
## - 8속성 상성표 모달 팝업 생성 (DataManager.element_matrix 기반)


static func classify_damage_display(
	damage: int,
	is_crit: bool = false,
	elem_mult: float = 1.0,
	is_dot: bool = false
) -> Dictionary:
	if is_crit:
		var suffix: String = " (상성!)" if elem_mult > 1.05 else (" (반감)" if elem_mult < 0.95 else "")
		return {"text": "💥 -%d!%s" % [damage, suffix], "kind": "CRIT"}
	if elem_mult > 1.05:
		return {"text": "▲ -%d (상성)" % damage, "kind": "ADVANTAGE"}
	if elem_mult < 0.95:
		return {"text": "-%d (반감)" % damage, "kind": "DISADVANTAGE"}
	if is_dot:
		return {"text": "-%d" % damage, "kind": "DOT"}
	return {"text": "-%d" % damage, "kind": "NORMAL"}


static func spawn_floating_text(
	host: Node,
	pos: Vector2,
	text: String,
	kind: String = "NORMAL",
	speed_mult: float = 1.0
) -> void:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return

	var color: Color = Color.WHITE
	var font_size: int = 19
	var pop_scale: float = 1.05
	var rise_px: float = 42.0

	match kind:
		"CRIT":
			color = Color(1.0, 0.24, 0.22, 1.0)
			font_size = 26
			pop_scale = 1.32
			rise_px = 54.0
		"ADVANTAGE":
			color = Color(1.0, 0.80, 0.16, 1.0)
			font_size = 22
			pop_scale = 1.18
			rise_px = 46.0
		"DISADVANTAGE":
			color = Color(0.66, 0.76, 0.90, 1.0)
			font_size = 17
			pop_scale = 1.0
			rise_px = 34.0
		"HEAL":
			color = Color(0.32, 0.96, 0.48, 1.0)
			font_size = 21
			pop_scale = 1.14
			rise_px = 44.0
		"SHIELD":
			color = Color(0.42, 0.88, 1.0, 1.0)
			font_size = 19
			pop_scale = 1.10
			rise_px = 38.0
		"DOT":
			color = Color(0.98, 0.56, 0.20, 1.0)
			font_size = 18
			pop_scale = 1.05
			rise_px = 36.0

	var lbl := Label.new()
	lbl.text = text
	lbl.z_index = 120
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(130, 0)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06, 0.95))
	lbl.add_theme_constant_override("outline_size", 4)

	var jitter_x: float = randf_range(-16.0, 16.0)
	var jitter_y: float = randf_range(-6.0, 6.0)
	lbl.position = pos + Vector2(-65.0 + jitter_x, -16.0 + jitter_y)
	lbl.pivot_offset = Vector2(65.0, 14.0)
	lbl.scale = Vector2(pop_scale, pop_scale)
	host.add_child(lbl)

	var dur: float = clampf(0.85 / maxf(1.0, speed_mult), 0.35, 0.95)
	var tw: Tween = lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - rise_px, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2.ONE, dur * 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, dur * 0.55).set_delay(dur * 0.45)
	tw.chain().tween_callback(lbl.queue_free)


static func create_element_chart_overlay(parent: Node) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.name = "ElementChartOverlay"
	overlay.visible = false
	overlay.z_index = 90
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.03, 0.06, 0.84)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(880, 560)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "8속성 상성표 (행: 공격 속성  →  열: 방어 속성)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var legend := Label.new()
	legend.text = "★ 1.50x = 상성 우위 (큰 피해 + 노랑/주황 강조)   |   1.00x = 보통   |   0.75x = 반감"
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.add_theme_font_size_override("font_size", 13)
	legend.modulate = Color(0.84, 0.90, 0.98)
	vbox.add_child(legend)

	var elem_ids: PackedStringArray = DataManager.get_element_ids()
	var grid := GridContainer.new()
	grid.columns = maxi(2, elem_ids.size() + 1)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(grid)

	# 좌상단 코너 헤더
	grid.add_child(_make_matrix_cell("공격＼방어", Color(0.14, 0.16, 0.22, 1.0), Color(0.85, 0.88, 0.94)))

	# 상단 방어 속성 헤더 행
	for def_id in elem_ids:
		var d_name: String = DataManager.get_element_name(def_id)
		var d_col: Color = DataManager.get_element_color(def_id)
		grid.add_child(_make_matrix_cell(d_name, Color(0.14, 0.16, 0.22, 1.0), d_col))

	# 각 공격 속성 행
	for atk_id in elem_ids:
		var a_name: String = DataManager.get_element_name(atk_id)
		var a_col: Color = DataManager.get_element_color(atk_id)
		grid.add_child(_make_matrix_cell(a_name, Color(0.14, 0.16, 0.22, 1.0), a_col))

		for def_id in elem_ids:
			var mult: float = DataManager.get_element_multiplier(atk_id, def_id)
			var cell_bg := Color(0.11, 0.12, 0.16, 1.0)
			var cell_fg := Color(0.68, 0.72, 0.78, 1.0)
			var txt := "1.0x"
			if mult > 1.05:
				cell_bg = Color(0.40, 0.26, 0.08, 1.0)
				cell_fg = Color(1.0, 0.84, 0.24, 1.0)
				txt = "▲ %.2gx" % mult
			elif mult < 0.95:
				cell_bg = Color(0.14, 0.18, 0.28, 1.0)
				cell_fg = Color(0.55, 0.70, 0.92, 1.0)
				txt = "%.2gx" % mult
			grid.add_child(_make_matrix_cell(txt, cell_bg, cell_fg))

	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.custom_minimum_size = Vector2(0, 42)
	close_btn.add_theme_font_size_override("font_size", 15)
	close_btn.pressed.connect(overlay.hide)
	vbox.add_child(close_btn)

	parent.add_child(overlay)
	return overlay


static func _make_matrix_cell(text: String, bg_color: Color, fg_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", fg_color)
	panel.add_child(lbl)
	return panel
