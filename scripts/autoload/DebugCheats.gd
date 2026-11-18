extends Node
## [DEBUG CHEAT CONSOLE] 디버깅 및 밸런스 테스트용 독립 치트 모듈 (Autoload: DebugCheats)
## ---------------------------------------------------------------------------
## 삭제 방법 (다른 씬/스크립트에 의존성이 전혀 없어 2단계로 완벽히 제거 가능):
##   1. project.godot 의 [autoload] 섹션에서 `DebugCheats=...` 한 줄 삭제
##   2. 본 파일 `res://scripts/autoload/DebugCheats.gd` 삭제
## (또는 일시 비활성화 시 아래 CHEATS_ENABLED 를 false 로 변경)
## ---------------------------------------------------------------------------
## 단축키: F12 또는 F9 (또는 입력창 포커스가 없을 때 ` 키) 로 치트 창 토글

const CHEATS_ENABLED: bool = true

var _layer: CanvasLayer = null
var _panel: PanelContainer = null
var _cmd_input: LineEdit = null
var _log_label: RichTextLabel = null


func _ready() -> void:
	if not CHEATS_ENABLED:
		return
	_build_cheat_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not CHEATS_ENABLED or _layer == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kev: InputEventKey = event
		if kev.keycode == KEY_F12 or kev.keycode == KEY_F9:
			_toggle_panel()
			get_viewport().set_input_as_handled()
		elif kev.keycode == KEY_QUOTELEFT:
			var focus_owner: Control = get_viewport().gui_get_focus_owner()
			if not (focus_owner is LineEdit or focus_owner is TextEdit):
				_toggle_panel()
				get_viewport().set_input_as_handled()


func _toggle_panel() -> void:
	_layer.visible = not _layer.visible
	if _layer.visible and _cmd_input != null:
		_cmd_input.grab_focus()


func _build_cheat_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 120
	_layer.visible = false
	add_child(_layer)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.03, 0.05, 0.55)
	_layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(920, 620)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	var head_hbox := HBoxContainer.new()
	root_vbox.add_child(head_hbox)

	var title := Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.text = "[DEBUG] 치트 콘솔 (F12 / F9 토글 · 순간 수치 조정 전용)"
	title.modulate = Color(1.0, 0.86, 0.42)
	head_hbox.add_child(title)

	var close_btn := Button.new()
	close_btn.custom_minimum_size = Vector2(90, 34)
	close_btn.text = "닫기"
	close_btn.pressed.connect(_toggle_panel)
	head_hbox.add_child(close_btn)

	# 치트 코드 입력 줄
	var cmd_hbox := HBoxContainer.new()
	cmd_hbox.add_theme_constant_override("separation", 8)
	root_vbox.add_child(cmd_hbox)

	_cmd_input = LineEdit.new()
	_cmd_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cmd_input.custom_minimum_size = Vector2(0, 38)
	_cmd_input.placeholder_text = "치트코드 입력 (예: gold 500 | res 200 | heal | research | story_heroes | next_def | help)"
	_cmd_input.text_submitted.connect(_on_cmd_submitted)
	cmd_hbox.add_child(_cmd_input)

	var exec_btn := Button.new()
	exec_btn.custom_minimum_size = Vector2(110, 38)
	exec_btn.text = "실행"
	exec_btn.pressed.connect(_on_exec_button_pressed)
	cmd_hbox.add_child(exec_btn)

	# 원클릭 버튼 모음 (Grid 4열)
	var btn_title := Label.new()
	btn_title.add_theme_font_size_override("font_size", 13)
	btn_title.text = "원클릭 순간 수치 조정 치트:"
	root_vbox.add_child(btn_title)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	root_vbox.add_child(grid)

	var quick_defs: Array[Array] = [
		["골드 +500", "gold 500"],
		["전체 자원 +300", "res 300"],
		["식량 +200", "food 200"],
		["자재 +200", "mat 200"],
		["아군 HP·피로도 완치", "heal"],
		["전 영웅 Lv +1", "lvlup 1"],
		["성벽 최대 수리", "wall"],
		["시민 사기 100", "morale 100"],
		["모든 연구 즉시 완료", "research"],
		["모든 커스텀 타워 지급", "towers"],
		["모든 장비 1개씩 지급", "equips"],
		["모든 포션·아이템 +3", "items 3"],
		["스토리 네임드 영입", "story_heroes"],
		["전체 네임드 영입", "all_heroes"],
		["다음 디펜스 데이로", "next_def"],
		["날짜 +1일 진행", "day 1"],
		["현재 던전 형태 및 시야/매복 디버그 확인", "dungeon_info"],
		["던전 전체 안개 해제 토글", "reveal_map"],
		["도움말 (help)", "help"],
	]
	for entry in quick_defs:
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 36)
		b.text = str(entry[0])
		b.pressed.connect(_run_quick_cmd.bind(str(entry[1])))
		grid.add_child(b)

	_log_label = RichTextLabel.new()
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.bbcode_enabled = false
	_log_label.scroll_following = true
	root_vbox.add_child(_log_label)
	_append_log("준비 완료. F12/F9로 언제든 열고 닫을 수 있습니다. (`help` 입력 시 전체 명령어 확인)")


func _on_cmd_submitted(text: String) -> void:
	execute_cheat_command(text)
	_cmd_input.text = ""


func _on_exec_button_pressed() -> void:
	execute_cheat_command(_cmd_input.text)
	_cmd_input.text = ""


func _run_quick_cmd(cmd: String) -> void:
	execute_cheat_command(cmd)


func _append_log(msg: String) -> void:
	if _log_label != null:
		_log_label.append_text("> %s\n" % msg)


## 텍스트 치트 코드를 파싱해 즉시 게임 수치에 반영합니다.
func execute_cheat_command(raw_text: String) -> String:
	if not CHEATS_ENABLED:
		return "Cheats disabled."
	var clean: String = raw_text.strip_edges()
	if clean.is_empty():
		return ""

	var tokens: PackedStringArray = clean.split(" ", false)
	var cmd: String = tokens[0].to_lower()
	var arg1: String = tokens[1] if tokens.size() >= 2 else ""
	var result: String = ""

	match cmd:
		"help", "?":
			result = (
				"치트 목록:\n"
				+ "  gold [N=500] / food [N=200] / mat [N=200] / res [N=200] : 자원 즉시 추가\n"
				+ "  heal : 영웅 전원 HP 100% + 피로도 0\n"
				+ "  fatigue [V=0] : 영웅 전원 피로도 V 설정\n"
				+ "  lvlup [N=1] : 보유 영웅 전원 레벨 +N\n"
				+ "  morale [V=100] : 시민 사기 즉시 설정\n"
				+ "  wall [확장량=0] : 성벽 HP 최대 회복 (+ 지정 시 최대HP 증축)\n"
				+ "  research : 모든 연구소 기술 즉시 완료\n"
				+ "  towers : 모든 커스텀 타워 즉시 지급\n"
				+ "  equips : equipments.json 전체 장비 1개씩 지급\n"
				+ "  items [N=3] : items.json 전체 포션·아이템 N개씩 지급\n"
				+ "  story_heroes : 스토리 전용 네임드 영웅 즉시 영입\n"
				+ "  all_heroes : 미보유 네임드 영웅 전체 영입\n"
				+ "  day [N=1] / next_def : 날짜 N일 진행 / 다음 5일 주기 디펜스 데이 점프\n"
				+ "  season <spring|summer|autumn|winter> : 계절 즉시 변경\n"
				+ "  phase <mgmt|town|dungeon|defense|settle> : 페이즈 즉시 전환\n"
				+ "  dungeon_info : 현재 던전 형태·진입방향·시야/매복 상태 확인\n"
				+ "  reveal_map : 현재 던전 전체 안개 일시 해제 토글"
			)
		"gold":
			var amt: int = int(arg1) if not arg1.is_empty() else 500
			GlobalData.add_resource("gold", amt)
			result = "골드 %+d 적용 (현재 %d)" % [amt, GlobalData.get_resource("gold")]
		"food":
			var amt: int = int(arg1) if not arg1.is_empty() else 200
			GlobalData.add_resource("food", amt)
			result = "식량 %+d 적용 (현재 %d)" % [amt, GlobalData.get_resource("food")]
		"mat", "materials":
			var amt: int = int(arg1) if not arg1.is_empty() else 200
			GlobalData.add_resource("materials", amt)
			result = "자재 %+d 적용 (현재 %d)" % [amt, GlobalData.get_resource("materials")]
		"res", "resources":
			var amt: int = int(arg1) if not arg1.is_empty() else 200
			GlobalData.add_resource("gold", amt)
			GlobalData.add_resource("food", amt)
			GlobalData.add_resource("materials", amt)
			result = "골드/식량/자재 각각 %+d 적용 완료!" % amt
		"heal":
			for h in GlobalData.hero_roster:
				var uid: int = int(h.get("uid", -1))
				GlobalData.heal_hero(uid, -1)
				GlobalData.recover_hero_fatigue(uid, GlobalData.MAX_FATIGUE)
			result = "보유 영웅 %d명 체력 완치 및 피로도 0 초기화 완료." % GlobalData.hero_roster.size()
		"fatigue":
			var target_f: int = clampi(int(arg1) if not arg1.is_empty() else 0, 0, GlobalData.MAX_FATIGUE)
			for h in GlobalData.hero_roster:
				h["fatigue"] = target_f
			GlobalData.roster_changed.emit()
			result = "보유 영웅 전원 피로도 = %d 적용 완료." % target_f
		"lvlup", "levelup":
			var steps: int = maxi(1, int(arg1) if not arg1.is_empty() else 1)
			for h in GlobalData.hero_roster:
				var uid: int = int(h.get("uid", -1))
				for _s in range(steps):
					GlobalData.level_up_hero(uid)
			result = "보유 영웅 %d명 레벨 +%d 적용 완료." % [GlobalData.hero_roster.size(), steps]
		"morale":
			var target_m: int = clampi(int(arg1) if not arg1.is_empty() else GlobalData.MAX_MORALE, 0, GlobalData.MAX_MORALE)
			GlobalData.citizen_morale = target_m
			GlobalData.morale_changed.emit(GlobalData.citizen_morale)
			result = "시민 사기 = %d/%d 적용 완료." % [GlobalData.citizen_morale, GlobalData.MAX_MORALE]
		"wall":
			var bonus: int = maxi(0, int(arg1) if not arg1.is_empty() else 0)
			if bonus > 0:
				GlobalData.wall_max_hp += bonus
			GlobalData.wall_hp = GlobalData.wall_max_hp
			GlobalData.wall_hp_changed.emit(GlobalData.wall_hp, GlobalData.wall_max_hp)
			result = "성벽 내구도 %d/%d 적용 완료." % [GlobalData.wall_hp, GlobalData.wall_max_hp]
		"research":
			var cnt: int = 0
			for r in DataManager.researches:
				var rid: String = str(r.get("id", ""))
				if GlobalData.complete_research(rid):
					cnt += 1
			result = "연구소 연구 %d건 추가 완료 (총 %d/%d)." % [cnt, GlobalData.completed_research_ids.size(), DataManager.researches.size()]
		"towers":
			var cnt: int = 0
			for t in DataManager.towers:
				var tid: String = str(t.get("id", ""))
				if not GlobalData.has_owned_tower(tid):
					GlobalData.add_owned_tower(tid)
					cnt += 1
			result = "커스텀 타워 %d종 지급 완료." % cnt
		"equips":
			var cnt: int = 0
			for eq in DataManager.equipments:
				var eq_id: String = str(eq.get("id", ""))
				if GlobalData.can_obtain_equipment(eq_id):
					GlobalData.add_equipment_to_inventory(eq_id)
					cnt += 1
			result = "장비 %d종 인벤토리 지급 완료." % cnt
		"items":
			var qty: int = maxi(1, int(arg1) if not arg1.is_empty() else 3)
			var cnt: int = 0
			for it in DataManager.items:
				GlobalData.add_item(str(it.get("id", "")), qty)
				cnt += 1
			result = "아이템 %d종 x%d개 인벤토리 지급 완료." % [cnt, qty]
		"story_heroes":
			var names: PackedStringArray = []
			for h in DataManager.heroes:
				if bool(h.get("is_named", false)) and str(h.get("named_source", "")) == "STORY":
					var rec: Dictionary = GlobalData.recruit_hero(h)
					if not rec.is_empty():
						names.append(str(rec.get("name", "")))
			result = "스토리 네임드 영입 (%d명): %s" % [names.size(), ", ".join(names) if not names.is_empty() else "이미 모두 보유 중"]
		"all_heroes":
			var names: PackedStringArray = []
			for h in DataManager.heroes:
				if bool(h.get("is_named", false)):
					var rec: Dictionary = GlobalData.recruit_hero(h)
					if not rec.is_empty():
						names.append(str(rec.get("name", "")))
			result = "네임드 영입 (%d명): %s" % [names.size(), ", ".join(names) if not names.is_empty() else "이미 모두 보유 중"]
		"day":
			var steps: int = maxi(1, int(arg1) if not arg1.is_empty() else 1)
			for _i in range(steps):
				TimeManager.set_phase_skip_to_next_day_debug() if TimeManager.has_method("set_phase_skip_to_next_day_debug") else _advance_one_day_direct()
			result = "%d일 경과 -> %d년차 %d월 %d일 (총 %d일차)" % [
				steps, TimeManager.current_year, TimeManager.current_month, TimeManager.current_day_of_month, GlobalData.current_day
			]
		"next_def":
			var guard_steps: int = 0
			while not TimeManager.is_defense_day() and guard_steps < 31:
				_advance_one_day_direct()
				guard_steps += 1
			result = "디펜스 데이 점프 완료 -> %d년차 %d월 %d일 (총 %d일차)" % [
				TimeManager.current_year, TimeManager.current_month, TimeManager.current_day_of_month, GlobalData.current_day
			]
		"season":
			match arg1.to_lower():
				"spring", "봄":
					TimeManager.current_season = TimeManager.Season.SPRING
				"summer", "여름":
					TimeManager.current_season = TimeManager.Season.SUMMER
				"autumn", "fall", "가을":
					TimeManager.current_season = TimeManager.Season.AUTUMN
				"winter", "겨울":
					TimeManager.current_season = TimeManager.Season.WINTER
			TimeManager.season_changed.emit(TimeManager.current_season)
			TimeManager.time_updated.emit()
			result = "계절 변경: %s" % TimeManager.get_season_name()
		"phase":
			match arg1.to_lower():
				"mgmt", "management":
					GlobalData.set_phase(GlobalData.GamePhase.MANAGEMENT)
				"town":
					GlobalData.set_phase(GlobalData.GamePhase.TOWN)
				"dungeon":
					GlobalData.set_phase(GlobalData.GamePhase.DUNGEON)
				"defense":
					GlobalData.set_phase(GlobalData.GamePhase.DEFENSE)
				"settle", "settlement":
					GlobalData.set_phase(GlobalData.GamePhase.SETTLEMENT)
			TimeManager.time_updated.emit()
			result = "페이즈 전환: %s" % TimeManager.get_phase_name()
		"dungeon_info":
			var exp_b: Dictionary = GlobalData.get_party_exploration_bonuses()
			var src_list: PackedStringArray = exp_b.get("sources", PackedStringArray())
			var src_txt: String = ", ".join(src_list) if not src_list.is_empty() else "없음"
			var dmap: Node = _find_dungeon_map_scene()
			if dmap == null:
				result = "[탐색 보너스] 시야 반경 %d칸 (+%d) | 매복감지=%s (%s)\n※ 활성화된 DungeonMapScene이 없습니다. 던전 탭 진입 후 다시 확인하세요." % [
					int(exp_b.get("vision_radius", 1)),
					int(exp_b.get("vision_bonus", 0)),
					"ON" if bool(exp_b.get("danger_sense", false)) else "OFF",
					src_txt,
				]
			else:
				var info: Dictionary = dmap.call("get_debug_map_info")
				result = (
					"[던전 디버그 정보] 레이아웃: %s | 크기: %s | 진입 방향: %s\n"
					+ "  시야 반경: %d칸 (보너스 +%d) | 매복감지: %s (기여: %s)\n"
					+ "  안개 전체해제: %s | 공개 타일: %d | 미식별(?): %d | 잠복 매복: %d"
				) % [
					str(info.get("layout_label", "")),
					str(info.get("grid_size", "")),
					str(info.get("entry_label", "")),
					int(info.get("vision_radius", 1)),
					int(info.get("vision_bonus", 0)),
					"ON" if bool(info.get("danger_sense", false)) else "OFF",
					src_txt,
					"ON" if bool(info.get("debug_reveal_all", false)) else "OFF",
					int(info.get("revealed_count", 0)),
					int(info.get("blind_unknown_count", 0)),
					int(info.get("armed_ambush_count", 0)),
				]
		"reveal_map":
			var dmap2: Node = _find_dungeon_map_scene()
			if dmap2 == null:
				result = "오류: 활성화된 DungeonMapScene을 찾을 수 없습니다."
			else:
				var now_on: bool = bool(dmap2.call("toggle_debug_reveal_all"))
				var info2: Dictionary = dmap2.call("get_debug_map_info")
				result = "던전 전체 안개 해제 %s [형태: %s / 진입: %s / 크기: %s]" % [
					"ON (전체 구조 표시)" if now_on else "OFF (정상 시야 복원)",
					str(info2.get("layout_label", "")),
					str(info2.get("entry_label", "")),
					str(info2.get("grid_size", "")),
				]
		_:
			result = "알 수 없는 치트코드 '%s' (`help` 입력으로 확인)" % cmd

	_append_log(result)
	return result


func _find_dungeon_map_scene() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return _search_node_for_method(tree.root, "get_debug_map_info")


func _search_node_for_method(node: Node, method_name: StringName) -> Node:
	if node == null:
		return null
	if node.has_method(method_name):
		return node
	for child in node.get_children():
		var found: Node = _search_node_for_method(child, method_name)
		if found != null:
			return found
	return null


func _advance_one_day_direct() -> void:
	TimeManager.current_day_of_month += 1
	if TimeManager.current_day_of_month > TimeManager.DAYS_PER_MONTH:
		TimeManager.current_day_of_month = 1
		TimeManager.current_month += 1
		var next_season_idx: int = (int(TimeManager.current_season) + 1) % TimeManager.Season.size()
		if next_season_idx == 0:
			TimeManager.current_year += 1
		TimeManager.current_season = next_season_idx as TimeManager.Season
		TimeManager.season_changed.emit(TimeManager.current_season)
	GlobalData.advance_day()
	TimeManager.date_changed.emit(TimeManager.current_year, TimeManager.current_season, TimeManager.current_day_of_month)
	TimeManager.time_updated.emit()
