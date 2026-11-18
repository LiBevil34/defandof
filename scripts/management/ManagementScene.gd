extends Control
## 평일 내정(MANAGEMENT) 페이즈 씬 컨트롤러
## - 페이즈 시작 시 시민 사기와 계절, 시설 레벨에 따라 식량·자재 자동 생산
## - 화면 중앙 양자택일 정책 이벤트 표시 및 선택지 적용
## - 정책 선택 완료 후 '마을 관리로 이동' 버튼 활성화

signal offense_started()
signal town_started()

const BASE_FOOD_PRODUCTION: int = 10
const BASE_MATERIALS_PRODUCTION: int = 8

const SEASON_MULTIPLIERS: Dictionary = {
	TimeManager.Season.SPRING: {"food": 1.2, "materials": 1.0},
	TimeManager.Season.SUMMER: {"food": 1.3, "materials": 1.1},
	TimeManager.Season.AUTUMN: {"food": 1.5, "materials": 1.2},
	TimeManager.Season.WINTER: {"food": 0.6, "materials": 0.8},
}

const RESOURCE_LABELS: Dictionary = {
	"food": "식량",
	"materials": "자재",
	"gold": "골드",
	"wood": "목재",
	"stone": "석재",
	"morale": "시민 사기",
	"wall_hp": "성벽 내구도",
	"unrest": "반란 위험",
}
const CALENDAR_SCENE: PackedScene = preload("res://scenes/ui/CalendarOverlay.tscn")

const POLICY_EVENTS: Array[Dictionary] = [
	{
		"title": "정책 이벤트 ①: 마을 축제와 비축 식량",
		"description": "시민들이 지친 마음을 달래기 위해 소규모 마을 축제를 원하고 있습니다.\n어떻게 결정하시겠습니까?",
		"option_a": {
			"text": "축제를 열어 사기를 진작한다",
			"deltas": {"food": -10, "morale": 15},
		},
		"option_b": {
			"text": "축제를 보류하고 물자를 비축한다",
			"deltas": {"food": 10, "materials": 8, "morale": -10},
		},
	},
	{
		"title": "정책 이벤트 ②: 성벽 보수 자재 조달",
		"description": "다가올 몬스터의 습격에 대비해 추가 자재 확보가 필요합니다.\n어떤 방식으로 자재를 조달하시겠습니까?",
		"option_a": {
			"text": "상단에서 자재를 정식 매입한다",
			"deltas": {"gold": -20, "materials": 18, "morale": 5},
		},
		"option_b": {
			"text": "시민들에게 긴급 노역을 지시한다",
			"deltas": {"materials": 15, "food": -5, "morale": -12},
		},
	},
]

@onready var bg_rect: ColorRect = %BgRect
@onready var status_label: Label = %StatusLabel
@onready var production_label: Label = %ProductionLabel
@onready var calendar_button: Button = %CalendarButton
@onready var event_title_label: Label = %EventTitleLabel
@onready var event_illustration_frame: PanelContainer = %EventIllustrationFrame
@onready var event_illustration_tex: TextureRect = %EventIllustrationTex
@onready var event_desc_label: Label = %EventDescLabel
@onready var option_a_button: Button = %OptionAButton
@onready var option_b_button: Button = %OptionBButton
@onready var event_result_label: Label = %EventResultLabel
@onready var offense_button: Button = %OffenseButton

var _current_event: Dictionary = {}
var _current_scaled_a: Dictionary = {}
var _current_scaled_b: Dictionary = {}
var _shuffled_event_ids: Array[String] = []
var _last_event_id: String = ""
var _last_processed_day: int = -1
var _event_resolved: bool = false
var _calendar_modal: Control = null


func _ready() -> void:
	AssetManager.apply_backdrop(bg_rect, "management_bg", Color(0.11, 0.13, 0.20), Color(0.05, 0.06, 0.10), 0.03)
	GlobalData.resources_changed.connect(_on_stats_changed)
	GlobalData.morale_changed.connect(_on_stats_changed)
	GlobalData.facilities_changed.connect(_on_stats_changed)
	GlobalData.phase_changed.connect(_on_phase_changed)
	GlobalData.game_reset.connect(_on_game_reset)

	_calendar_modal = CALENDAR_SCENE.instantiate()
	add_child(_calendar_modal)
	calendar_button.pressed.connect(_on_calendar_button_pressed)
	option_a_button.pressed.connect(_on_option_selected.bind("option_a"))
	option_b_button.pressed.connect(_on_option_selected.bind("option_b"))
	offense_button.pressed.connect(_on_offense_button_pressed)

	_update_status_label()

	if GlobalData.current_phase == GlobalData.GamePhase.MANAGEMENT:
		start_management_phase()


func _on_calendar_button_pressed() -> void:
	if _calendar_modal != null:
		_calendar_modal.open_calendar()


func _on_phase_changed(new_phase: GlobalData.GamePhase) -> void:
	if new_phase == GlobalData.GamePhase.MANAGEMENT:
		start_management_phase()


func _on_game_reset() -> void:
	_last_processed_day = -1
	_shuffled_event_ids.clear()
	_last_event_id = ""


func _on_stats_changed(_arg = null) -> void:
	_update_status_label()


## 내정 페이즈 시작 시 자동 생산과 양자택일 정책 이벤트를 초기화합니다.
func start_management_phase() -> void:
	if _last_processed_day == GlobalData.current_day:
		return
	_last_processed_day = GlobalData.current_day

	if GlobalData.last_management_day != GlobalData.current_day:
		GlobalData.last_management_day = GlobalData.current_day
		_run_auto_production()
	else:
		production_label.text = "[일일 자동 생산] 오늘의 생산은 이미 완료되었습니다."

	_present_next_policy_event()


func _run_auto_production() -> void:
	var season: TimeManager.Season = TimeManager.current_season
	var season_mult: Dictionary = SEASON_MULTIPLIERS.get(season, {"food": 1.0, "materials": 1.0})
	var morale_mult: float = 0.5 + (float(GlobalData.citizen_morale) / 100.0)
	var territory_mult: float = GlobalData.get_territory_production_multiplier()
	var base_food: int = BASE_FOOD_PRODUCTION + (GlobalData.farm_level - 1) * 5
	var base_materials: int = BASE_MATERIALS_PRODUCTION + (GlobalData.lumber_mill_level - 1) * 4

	var food_gain: int = maxi(1, roundi(base_food * morale_mult * territory_mult * float(season_mult["food"])))
	var materials_gain: int = maxi(1, roundi(base_materials * morale_mult * territory_mult * float(season_mult["materials"])))

	GlobalData.apply_deltas({
		"food": food_gain,
		"materials": materials_gain,
	})

	var debuff_txt: String = GlobalData.get_territory_debuff_summary()
	var debuff_line: String = "  |  " + debuff_txt if not debuff_txt.is_empty() else ""
	production_label.text = (
		"[일일 자동 생산] %s(식량×%.1f, 자재×%.1f) · 사기(×%.2f) · 영지생산효율 %d%%%s\n"
		+ "→ 농장 Lv.%d / 제재소 Lv.%d : 식량 +%d, 자재 +%d 생산 완료"
	) % [
		TimeManager.get_season_name(season),
		float(season_mult["food"]),
		float(season_mult["materials"]),
		morale_mult,
		roundi(territory_mult * 100.0),
		debuff_line,
		GlobalData.farm_level,
		GlobalData.lumber_mill_level,
		food_gain,
		materials_gain,
	]


func _present_next_policy_event() -> void:
	_event_resolved = false
	var cur_stage: int = TimeManager.get_event_stage()
	var scale_mult: float = TimeManager.get_event_scale_multiplier(cur_stage)
	var is_crisis: bool = GlobalData.should_trigger_rebellion_event()

	_current_event = _pick_next_shuffled_event(cur_stage, is_crisis)
	if _current_event.is_empty():
		_current_event = POLICY_EVENTS[randi() % POLICY_EVENTS.size()]

	var cat: String = str(_current_event.get("event_category", "NORMAL"))
	var stage_badge: String = "[%d단계 · %s | 강도 ×%.2f]" % [cur_stage, TimeManager.get_event_stage_label(cur_stage).split("·")[1].strip_edges(), scale_mult]
	if cat == "REBELLION":
		event_title_label.text = "⚠ [영지 위기 · 반란 조짐!] %s" % str(_current_event.get("title", "반란"))
		event_title_label.modulate = Color(1.0, 0.42, 0.35)
	else:
		event_title_label.text = "%s %s" % [stage_badge, str(_current_event.get("title", "정책 이벤트"))]
		event_title_label.modulate = Color.WHITE
	event_desc_label.text = str(_current_event.get("description", ""))
	_update_event_illustration(_current_event, cat)

	var opt_a: Dictionary = _current_event["option_a"]
	var opt_b: Dictionary = _current_event["option_b"]
	_current_scaled_a = _scale_event_deltas(opt_a["deltas"], scale_mult)
	_current_scaled_b = _scale_event_deltas(opt_b["deltas"], scale_mult)

	option_a_button.text = "%s\n(%s)" % [opt_a["text"], _format_option_summary(opt_a, _current_scaled_a)]
	option_b_button.text = "%s\n(%s)" % [opt_b["text"], _format_option_summary(opt_b, _current_scaled_b)]

	option_a_button.disabled = false
	option_b_button.disabled = false

	if cat == "REBELLION":
		event_result_label.text = "시민들의 불만이 폭발했습니다! 신중하게 대응해 영지를 수습하세요."
		event_result_label.modulate = Color(1.0, 0.65, 0.45)
	else:
		event_result_label.text = "정책을 선택해야 마을 관리로 이동할 수 있습니다. (반란 위험도: %d/10)" % GlobalData.rebellion_risk
		event_result_label.modulate = Color(0.85, 0.85, 0.85)
	offense_button.disabled = true
	offense_button.text = "마을 관리로 이동"


func _pick_next_shuffled_event(cur_stage: int, crisis_mode: bool) -> Dictionary:
	var all_events: Array = DataManager.events if not DataManager.events.is_empty() else POLICY_EVENTS
	if crisis_mode:
		var rebellion_pool: Array[Dictionary] = []
		for ev in all_events:
			if str(ev.get("event_category", "NORMAL")) == "REBELLION":
				rebellion_pool.append(ev)
		if not rebellion_pool.is_empty():
			rebellion_pool.shuffle()
			return rebellion_pool[0]

	var stage_pool: Array[Dictionary] = []
	var fallback_pool: Array[Dictionary] = []
	for ev in all_events:
		if str(ev.get("event_category", "NORMAL")) == "REBELLION":
			continue
		fallback_pool.append(ev)
		var min_s: int = int(ev.get("min_stage", 1))
		var max_s: int = int(ev.get("max_stage", 6))
		if cur_stage >= min_s and cur_stage <= max_s:
			stage_pool.append(ev)

	var use_pool: Array[Dictionary] = stage_pool if not stage_pool.is_empty() else fallback_pool
	if use_pool.is_empty():
		return {}

	var valid_ids: Array[String] = []
	var by_id: Dictionary = {}
	for ev in use_pool:
		var eid: String = str(ev.get("id", ev.get("title", "")))
		valid_ids.append(eid)
		by_id[eid] = ev

	# 현재 단계에 유효한 섞인 덱이 비었으면 새로 셔플 (연속 중복 방지)
	var clean_deck: Array[String] = []
	for eid in _shuffled_event_ids:
		if by_id.has(eid):
			clean_deck.append(eid)
	_shuffled_event_ids = clean_deck

	if _shuffled_event_ids.is_empty():
		_shuffled_event_ids = valid_ids.duplicate()
		_shuffled_event_ids.shuffle()
		if _shuffled_event_ids.size() > 1 and _shuffled_event_ids[0] == _last_event_id:
			var first_id: String = _shuffled_event_ids[0]
			_shuffled_event_ids[0] = _shuffled_event_ids[_shuffled_event_ids.size() - 1]
			_shuffled_event_ids[_shuffled_event_ids.size() - 1] = first_id

	var picked_id: String = _shuffled_event_ids.pop_front()
	_last_event_id = picked_id
	return by_id.get(picked_id, use_pool[0])


func _scale_event_deltas(raw_deltas: Dictionary, scale_mult: float) -> Dictionary:
	var out: Dictionary = {}
	for key in raw_deltas:
		var val: int = int(raw_deltas[key])
		if val == 0:
			continue
		var k_str: String = str(key)
		if k_str == "unrest":
			out[k_str] = val
		elif k_str == "morale":
			var m_scale: float = 1.0 + (scale_mult - 1.0) * 0.45
			var scaled_m: int = roundi(float(val) * m_scale)
			if scaled_m == 0:
				scaled_m = 1 if val > 0 else -1
			out[k_str] = scaled_m
		else:
			var scaled: int = roundi(float(val) * scale_mult)
			if scaled == 0:
				scaled = 1 if val > 0 else -1
			out[k_str] = scaled
	return out


func _on_option_selected(option_key: String) -> void:
	if _event_resolved or _current_event.is_empty():
		return

	_event_resolved = true
	var chosen: Dictionary = _current_event[option_key]
	var deltas: Dictionary = _current_scaled_a if option_key == "option_a" else _current_scaled_b

	GlobalData.apply_deltas(deltas)
	var extra_res: Dictionary = GlobalData.grant_event_rewards(chosen)
	GlobalData.record_event_resolved()
	if str(_current_event.get("event_category", "NORMAL")) == "REBELLION":
		GlobalData.rebellion_suppression_active = true
	elif GlobalData.rebellion_risk < 4:
		GlobalData.rebellion_suppression_active = false

	# 잘못된 선택(사기 큰 하락) 시 반란 위험도 증가 / 선한 선택 시 감소
	if not deltas.has("unrest"):
		var morale_delta: int = int(deltas.get("morale", 0))
		if morale_delta <= -10:
			GlobalData.add_rebellion_risk(2)
		elif morale_delta <= -5:
			GlobalData.add_rebellion_risk(1)
		elif morale_delta >= 8:
			GlobalData.add_rebellion_risk(-1)

	option_a_button.disabled = true
	option_b_button.disabled = true

	var risk_note: String = "  (반란 위험도: %d/10)" % GlobalData.rebellion_risk if GlobalData.rebellion_risk > 0 else ""
	var extra_msgs: PackedStringArray = extra_res.get("messages", PackedStringArray())
	var extra_text: String = ("\n" + "  |  ".join(extra_msgs)) if not extra_msgs.is_empty() else ""
	event_result_label.text = "정책 적용 완료: [%s] → %s%s%s" % [
		chosen["text"],
		_format_deltas(deltas),
		risk_note,
		extra_text,
	]
	event_result_label.modulate = Color(0.55, 0.95, 0.65)
	offense_button.disabled = false


func _on_offense_button_pressed() -> void:
	if not _event_resolved:
		return
	town_started.emit()
	offense_started.emit()
	if GlobalData.current_phase == GlobalData.GamePhase.MANAGEMENT:
		TimeManager.advance_phase()


func _update_status_label() -> void:
	if not is_node_ready():
		return
	var debuff_txt: String = GlobalData.get_territory_debuff_summary()
	var extra_part: String = "  |  " + debuff_txt if not debuff_txt.is_empty() else ""
	var stage_lbl: String = "%d단계" % TimeManager.get_event_stage()
	status_label.text = "[%s] 식량: %d  |  자재: %d  |  골드: %d  |  시민 사기: %d/%d  |  반란 위험: %d/10%s" % [
		stage_lbl,
		GlobalData.get_resource("food"),
		GlobalData.get_resource("materials"),
		GlobalData.get_resource("gold"),
		GlobalData.citizen_morale,
		GlobalData.MAX_MORALE,
		GlobalData.rebellion_risk,
		extra_part,
	]


func _update_event_illustration(ev: Dictionary, cat: String) -> void:
	var ev_id: String = str(ev.get("id", "")).strip_edges()
	var custom_tex: Texture2D = AssetManager.get_texture("events", ev_id, str(ev.get("illustration_path", "")))
	if custom_tex != null:
		event_illustration_frame.custom_minimum_size = Vector2(360, 140)
		event_illustration_tex.custom_minimum_size = Vector2(344, 128)
		event_illustration_tex.texture = custom_tex
		event_illustration_tex.modulate = Color.WHITE
		event_illustration_frame.add_theme_stylebox_override(
			"panel",
			AssetManager.make_panel_style(Color(0.07, 0.08, 0.12, 0.96), AssetManager.COL_BORDER_GOLD, 8, 2, 6)
		)
		return

	event_illustration_frame.custom_minimum_size = Vector2(140, 102)
	event_illustration_tex.custom_minimum_size = Vector2(124, 88)
	var opt_a: Dictionary = ev.get("option_a", {})
	var opt_b: Dictionary = ev.get("option_b", {})
	var hero_id: String = str(opt_a.get("recruit_hero_id", "")).strip_edges()
	if hero_id.is_empty():
		hero_id = str(opt_b.get("recruit_hero_id", "")).strip_edges()
	if not hero_id.is_empty():
		var h_tpl: Dictionary = DataManager.get_hero_template(hero_id)
		if not h_tpl.is_empty():
			var r_col: Color = DataManager.get_rarity_color(DataManager.normalize_rarity(h_tpl.get("rarity", "SR")))
			var el_col: Color = DataManager.get_element_color(str(h_tpl.get("element", "FIRE")))
			var has_art: bool = AssetManager.get_texture("heroes/portraits", hero_id, str(h_tpl.get("portrait_path", ""))) != null
			event_illustration_tex.texture = AssetManager.get_hero_portrait(h_tpl)
			event_illustration_tex.modulate = Color.WHITE if has_art else el_col.lightened(0.32)
			event_illustration_frame.add_theme_stylebox_override(
				"panel",
				AssetManager.make_panel_style(Color(0.08, 0.10, 0.16, 0.96), r_col, 8, 2, 6)
			)
			return

	var equip_id: String = str(opt_a.get("grant_equip_id", "")).strip_edges()
	if equip_id.is_empty():
		equip_id = str(opt_b.get("grant_equip_id", "")).strip_edges()
	if not equip_id.is_empty():
		var eq_tpl: Dictionary = DataManager.get_equipment(equip_id)
		if not eq_tpl.is_empty():
			var r_col: Color = DataManager.get_rarity_color(DataManager.normalize_rarity(eq_tpl.get("rarity", "SR")))
			event_illustration_tex.texture = AssetManager.get_equipment_icon(eq_tpl)
			event_illustration_tex.modulate = r_col.lightened(0.18)
			event_illustration_frame.add_theme_stylebox_override(
				"panel",
				AssetManager.make_panel_style(Color(0.08, 0.10, 0.16, 0.96), r_col, 8, 2, 6)
			)
			return

	if cat == "REBELLION":
		event_illustration_tex.texture = AssetManager.get_enemy_emblem_texture("BOSS")
		event_illustration_tex.modulate = Color(1.0, 0.45, 0.38, 0.95)
		event_illustration_frame.add_theme_stylebox_override(
			"panel",
			AssetManager.make_panel_style(Color(0.14, 0.06, 0.08, 0.96), Color(0.90, 0.32, 0.28, 0.9), 8, 2, 6)
		)
	else:
		event_illustration_tex.texture = AssetManager.get_tile_icon("tile_outpost")
		event_illustration_tex.modulate = Color(0.82, 0.88, 0.98, 0.92)
		event_illustration_frame.add_theme_stylebox_override(
			"panel",
			AssetManager.make_panel_style(Color(0.09, 0.11, 0.17, 0.96), AssetManager.COL_BORDER, 8, 1, 6)
		)


func _format_option_summary(opt: Dictionary, deltas: Dictionary) -> String:
	var parts: PackedStringArray = []
	var delta_txt: String = _format_deltas(deltas)
	if delta_txt != "변동 없음":
		parts.append(delta_txt)

	var hero_id: String = str(opt.get("recruit_hero_id", "")).strip_edges()
	if not hero_id.is_empty():
		var h_tpl: Dictionary = DataManager.get_hero_template(hero_id)
		if not h_tpl.is_empty():
			if GlobalData.can_recruit_hero(h_tpl):
				parts.append("★영웅 영입: [%s] %s" % [DataManager.normalize_rarity(h_tpl.get("rarity", "R")), str(h_tpl.get("name", hero_id))])
			else:
				parts.append("★%s 보유중(한계훈련+자원)" % str(h_tpl.get("name", hero_id)))

	var equip_id: String = str(opt.get("grant_equip_id", "")).strip_edges()
	if not equip_id.is_empty():
		var eq_tpl: Dictionary = DataManager.get_equipment(equip_id)
		if not eq_tpl.is_empty():
			if GlobalData.can_obtain_equipment(equip_id):
				parts.append("★장비: [%s] %s" % [DataManager.normalize_rarity(eq_tpl.get("rarity", "N")), str(eq_tpl.get("name", equip_id))])
			else:
				parts.append("★장비 중복→골드·자재 대체")

	var item_id: String = str(opt.get("grant_item_id", "")).strip_edges()
	if not item_id.is_empty():
		var it_tpl: Dictionary = DataManager.get_item(item_id)
		if not it_tpl.is_empty():
			parts.append("아이템: %s x1" % str(it_tpl.get("name", item_id)))

	return " | ".join(parts) if not parts.is_empty() else "변동 없음"


func _format_deltas(deltas: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in deltas:
		var val: int = int(deltas[key])
		if val == 0:
			continue
		var label: String = RESOURCE_LABELS.get(key, key)
		var sign_str: String = "+" if val > 0 else ""
		parts.append("%s %s%d" % [label, sign_str, val])
	return ", ".join(parts) if not parts.is_empty() else "변동 없음"
