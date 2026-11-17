extends Control
## 내정(정책 이벤트) 직후 진입하는 마을 관리 페이즈 (TownPhaseScene)
## - 상단 공통 바: 날짜, 계절, 디펜스 데이 카운트다운, 핵심 자원 실시간 표시
## - 탭 1: 여관 (보유 영웅 관리, 1~5 파티 편성, 회복, 훈련, 장비 장착)
## - 탭 2: 술집 (신규 영웅 모집 — 스토리 전용 네임드 제외)
## - 탭 3: 마을 (농장/제재소 증설, 시민 사기 진작)
## - 탭 4: 성벽 (성벽 수리/증축, 기본 포탑 강화, 커스텀 타워 3슬롯 장착)
## - 탭 5: 대장간 (제작 가능 장비 및 연구 해금 커스텀 포탑 제작)
## - 탭 6: 연구소 (커스텀 포탑 및 고급 장비 제작 해금 연구)
## - 하단 [출정 준비 완료 (다음 페이즈로)] -> 평일: 던전(DungeonMapScene), 5일 주기 디펜스 데이: 방어전(DefenseScene)

signal ready_for_next_phase()

const HEAL_COST: Dictionary = {"food": 8, "gold": 10}
const HERO_REST_FATIGUE_RECOVERY: int = 50
const PARTY_REST_COST: Dictionary = {"food": 15, "gold": 15}
const PARTY_REST_FATIGUE_RECOVERY: int = 35
const REFRESH_RECRUIT_COST: Dictionary = {"gold": 5}
const RECRUIT_COST_BY_RARITY: Dictionary = {
	"N": {"gold": 20, "food": 5},
	"R": {"gold": 35, "food": 8},
	"SR": {"gold": 55, "food": 12},
	"SSR": {"gold": 80, "food": 15},
}

const WALL_REPAIR_AMOUNT: int = 25
const WALL_REPAIR_COST: Dictionary = {"materials": 12, "gold": 15}
const WALL_EXPAND_HP_GAIN: int = 30
const MORALE_BOOST_AMOUNT: int = 12
const MORALE_BOOST_COST: Dictionary = {"food": 10, "gold": 20}

const BLACKSMITH_COST_BY_RARITY: Dictionary = {
	"N": {"gold": 20, "materials": 8},
	"R": {"gold": 35, "materials": 14},
	"SR": {"gold": 55, "materials": 22},
	"SSR": {"gold": 85, "materials": 35},
}

const BASE_FOOD_PROD: int = 10
const BASE_MAT_PROD: int = 8
const CALENDAR_SCENE: PackedScene = preload("res://scenes/ui/CalendarOverlay.tscn")

@onready var top_date_label: Label = %TopDateLabel
@onready var top_season_label: Label = %TopSeasonLabel
@onready var top_defense_countdown_label: Label = %TopDefenseCountdownLabel
@onready var calendar_button: Button = %CalendarButton
@onready var top_resources_label: Label = %TopResourcesLabel

@onready var town_tab_container: TabContainer = %TownTabContainer

# --- 탭 1: 보유 영웅 관리 ---
@onready var hero_count_label: Label = %HeroCountLabel
@onready var hero_roster_list: ItemList = %HeroRosterList
@onready var hero_element_swatch: ColorRect = %HeroElementSwatch
@onready var hero_rarity_label: Label = %HeroRarityLabel
@onready var hero_title_label: Label = %HeroTitleLabel
@onready var hero_deployment_label: Label = %HeroDeploymentLabel
@onready var hero_hp_bar: ProgressBar = %HeroHpBar
@onready var hero_hp_label: Label = %HeroHpLabel
@onready var hero_fatigue_label: Label = %HeroFatigueLabel
@onready var hero_fatigue_bar: ProgressBar = %HeroFatigueBar
@onready var hero_stats_label: Label = %HeroStatsLabel
@onready var equip_weapon_button: Button = %EquipWeaponButton
@onready var equip_armor_button: Button = %EquipArmorButton
@onready var equip_accessory_button: Button = %EquipAccessoryButton
@onready var skills_header_label: Label = %SkillsHeaderLabel
@onready var passive_skill_label: Label = %PassiveSkillLabel
@onready var active_skill_label: Label = %ActiveSkillLabel
@onready var active2_skill_label: Label = %Active2SkillLabel
@onready var ultimate_skill_label: Label = %UltimateSkillLabel
@onready var equip_passive_label: Label = %EquipPassiveLabel
@onready var hero_heal_button: Button = %HeroHealButton
@onready var hero_train_button: Button = %HeroTrainButton
@onready var party_rest_button: Button = %PartyRestButton
@onready var hero_action_status_label: Label = %HeroActionStatusLabel

# --- 탭 2: 신규 영웅 모집 ---
@onready var tavern_info_label: Label = %TavernInfoLabel
@onready var refresh_recruit_button: Button = %RefreshRecruitButton
@onready var candidates_hbox: HBoxContainer = %CandidatesHBox
@onready var tavern_status_label: Label = %TavernStatusLabel

# --- 탭 3: 마을 ---
@onready var facility_summary_label: Label = %FacilitySummaryLabel
@onready var upgrade_farm_desc_label: Label = %UpgradeFarmDescLabel
@onready var upgrade_farm_button: Button = %UpgradeFarmButton
@onready var upgrade_mill_desc_label: Label = %UpgradeMillDescLabel
@onready var upgrade_mill_button: Button = %UpgradeMillButton
@onready var boost_morale_desc_label: Label = %BoostMoraleDescLabel
@onready var boost_morale_button: Button = %BoostMoraleButton
@onready var facility_status_label: Label = %FacilityStatusLabel

# --- 탭 4: 성벽 ---
@onready var wall_summary_label: Label = %WallSummaryLabel
@onready var repair_wall_desc_label: Label = %RepairWallDescLabel
@onready var repair_wall_button: Button = %RepairWallButton
@onready var expand_wall_desc_label: Label = %ExpandWallDescLabel
@onready var expand_wall_button: Button = %ExpandWallButton
@onready var base_tower_desc_label: Label = %BaseTowerDescLabel
@onready var base_tower_atk_button: Button = %BaseTowerAtkButton
@onready var base_tower_spd_button: Button = %BaseTowerSpdButton
@onready var tower_mounts_hbox: HBoxContainer = %TowerMountsHBox
@onready var tower_mount_list_vbox: VBoxContainer = %TowerMountListVBox
@onready var wall_status_label: Label = %WallStatusLabel

# --- 탭 5: 대장간 ---
@onready var blacksmith_list_vbox: VBoxContainer = %BlacksmithListVBox
@onready var tower_catalog_vbox: VBoxContainer = %TowerCatalogVBox
@onready var blacksmith_status_label: Label = %BlacksmithStatusLabel

# --- 탭 6: 연구소 ---
@onready var research_summary_label: Label = %ResearchSummaryLabel
@onready var research_list_vbox: VBoxContainer = %ResearchListVBox
@onready var research_status_label: Label = %ResearchStatusLabel

# --- 하단 푸터 ---
@onready var footer_status_label: Label = %FooterStatusLabel
@onready var ready_deploy_button: Button = %ReadyDeployButton

# --- 장비 선택 팝업 ---
@onready var equip_picker_overlay: ColorRect = %EquipPickerOverlay
@onready var equip_picker_title_label: Label = %EquipPickerTitleLabel
@onready var equip_picker_sub_label: Label = %EquipPickerSubLabel
@onready var equip_picker_list_vbox: VBoxContainer = %EquipPickerListVBox
@onready var equip_picker_unequip_button: Button = %EquipPickerUnequipButton
@onready var equip_picker_close_button: Button = %EquipPickerCloseButton

# --- 파티 프리셋 3x3 편성 UI ---
@onready var preset_buttons_hbox: HBoxContainer = %PresetButtonsHBox
@onready var party_formation_grid: GridContainer = %PartyFormationGrid
@onready var quick_formation_button: Button = %QuickFormationButton
@onready var clear_preset_button: Button = %ClearPresetButton
@onready var preset_status_label: Label = %PresetStatusLabel

# --- 던전 출정 직전 파티 선택 팝업 ---
@onready var dungeon_deploy_overlay: ColorRect = %DungeonDeployOverlay
@onready var deploy_preset_buttons_hbox: HBoxContainer = %DeployPresetButtonsHBox
@onready var deploy_members_vbox: VBoxContainer = %DeployMembersVBox
@onready var deploy_summary_label: Label = %DeploySummaryLabel
@onready var deploy_cancel_button: Button = %DeployCancelButton
@onready var deploy_confirm_button: Button = %DeployConfirmButton

var _selected_hero_uid: int = -1
var _picking_slot_type: String = ""
var _recruit_candidates: Array[Dictionary] = []
var _last_tavern_day: int = -1
var _preset_tab_buttons: Array[Button] = []
var _formation_slot_buttons: Dictionary = {} # "rank,row" -> Button
var _deploy_preset_buttons: Array[Button] = []
var _selected_tower_mount_idx: int = 0
var _calendar_modal: Control = null


func _ready() -> void:
	GlobalData.resources_changed.connect(_on_global_changed)
	GlobalData.morale_changed.connect(_on_global_changed)
	GlobalData.wall_hp_changed.connect(_on_global_changed)
	GlobalData.day_changed.connect(_on_global_changed)
	GlobalData.phase_changed.connect(_on_phase_changed)
	GlobalData.roster_changed.connect(_on_roster_changed)
	GlobalData.facilities_changed.connect(_on_facilities_changed)
	GlobalData.inventory_changed.connect(_on_inventory_changed)
	GlobalData.party_presets_changed.connect(_on_party_presets_changed)
	GlobalData.towers_changed.connect(_on_facilities_changed)
	GlobalData.research_changed.connect(_on_facilities_changed)
	GlobalData.dungeon_state_changed.connect(_on_global_changed)
	GlobalData.game_reset.connect(_on_game_reset)
	TimeManager.time_updated.connect(_on_global_changed)
	DataManager.data_reloaded.connect(_on_data_reloaded)

	hero_roster_list.item_selected.connect(_on_hero_selected)
	equip_weapon_button.pressed.connect(_open_equip_picker.bind("WEAPON"))
	equip_armor_button.pressed.connect(_open_equip_picker.bind("ARMOR"))
	equip_accessory_button.pressed.connect(_open_equip_picker.bind("ACCESSORY"))
	equip_picker_unequip_button.pressed.connect(_on_equip_picker_unequip_pressed)
	equip_picker_close_button.pressed.connect(_close_equip_picker)
	hero_heal_button.pressed.connect(_on_hero_heal_pressed)
	hero_train_button.pressed.connect(_on_hero_train_pressed)
	party_rest_button.pressed.connect(_on_party_rest_pressed)

	refresh_recruit_button.pressed.connect(_on_refresh_recruit_pressed)

	repair_wall_button.pressed.connect(_on_repair_wall_pressed)
	expand_wall_button.pressed.connect(_on_expand_wall_pressed)
	upgrade_farm_button.pressed.connect(_on_upgrade_farm_pressed)
	upgrade_mill_button.pressed.connect(_on_upgrade_mill_pressed)
	boost_morale_button.pressed.connect(_on_boost_morale_pressed)
	base_tower_atk_button.pressed.connect(_on_upgrade_base_tower_atk_pressed)
	base_tower_spd_button.pressed.connect(_on_upgrade_base_tower_spd_pressed)

	ready_deploy_button.pressed.connect(_on_ready_deploy_pressed)
	quick_formation_button.pressed.connect(_on_quick_formation_pressed)
	clear_preset_button.pressed.connect(_on_clear_preset_pressed)
	deploy_cancel_button.pressed.connect(_close_dungeon_deploy_popup)
	deploy_confirm_button.pressed.connect(_on_deploy_confirm_pressed)

	_build_party_formation_ui()
	_calendar_modal = CALENDAR_SCENE.instantiate()
	add_child(_calendar_modal)
	calendar_button.pressed.connect(_on_calendar_button_pressed)

	if GlobalData.hero_roster.is_empty():
		GlobalData.init_starter_roster()
	if GlobalData.equipment_inventory.is_empty():
		GlobalData.init_starter_equipment()
	equip_picker_overlay.visible = false
	dungeon_deploy_overlay.visible = false
	_roll_recruit_candidates()
	_refresh_all()


func _on_phase_changed(new_phase: GlobalData.GamePhase) -> void:
	if new_phase == GlobalData.GamePhase.TOWN:
		if _last_tavern_day != GlobalData.current_day or _recruit_candidates.is_empty():
			_last_tavern_day = GlobalData.current_day
			_roll_recruit_candidates()
		hero_action_status_label.text = ""
		tavern_status_label.text = ""
		facility_status_label.text = ""
		wall_status_label.text = ""
		blacksmith_status_label.text = ""
		research_status_label.text = ""
		_refresh_all()


func _on_game_reset() -> void:
	_selected_hero_uid = -1
	_last_tavern_day = -1
	_roll_recruit_candidates()
	_refresh_all()


func _on_data_reloaded() -> void:
	if _recruit_candidates.is_empty():
		_roll_recruit_candidates()
	_refresh_all()


func _on_global_changed(_a = null, _b = null) -> void:
	if not is_node_ready():
		return
	_refresh_top_bar()
	_refresh_hero_action_buttons()
	_refresh_tavern_ui()
	_refresh_facilities_ui()
	_refresh_footer()


func _on_roster_changed() -> void:
	if not is_node_ready():
		return
	_refresh_hero_roster_tab()
	_refresh_party_formation_ui()
	if dungeon_deploy_overlay.visible:
		_refresh_dungeon_deploy_popup()


func _on_party_presets_changed() -> void:
	if not is_node_ready():
		return
	_refresh_party_formation_ui()
	if dungeon_deploy_overlay.visible:
		_refresh_dungeon_deploy_popup()


func _on_facilities_changed() -> void:
	if not is_node_ready():
		return
	_refresh_top_bar()
	_refresh_facilities_ui()


func _on_inventory_changed() -> void:
	if not is_node_ready():
		return
	_refresh_hero_roster_tab()
	_refresh_facilities_ui()
	if equip_picker_overlay.visible and not _picking_slot_type.is_empty():
		_refresh_equip_picker_list()


func _refresh_all() -> void:
	_refresh_top_bar()
	_refresh_hero_roster_tab()
	_refresh_party_formation_ui()
	_refresh_tavern_ui()
	_refresh_facilities_ui()
	_refresh_footer()


# ==========================================
# 상단 공통 바 & 하단 푸터
# ==========================================
func _refresh_top_bar() -> void:
	top_date_label.text = "%d년차 %d월 %d일 (총 %d일차)" % [
		TimeManager.current_year,
		TimeManager.current_month,
		TimeManager.current_day_of_month,
		GlobalData.current_day,
	]
	top_season_label.text = "계절: %s" % TimeManager.get_season_name()

	var days_left: int = TimeManager.get_days_until_defense()
	if days_left == 0:
		top_defense_countdown_label.text = "⚠ 디펜스 데이 D-Day (오늘 밤 습격!)"
		top_defense_countdown_label.modulate = Color(1.0, 0.42, 0.35)
	elif days_left == 1:
		top_defense_countdown_label.text = "디펜스 데이: D-1 (내일 습격)"
		top_defense_countdown_label.modulate = Color(1.0, 0.78, 0.35)
	else:
		top_defense_countdown_label.text = "디펜스 데이: D-%d (%d일 후)" % [days_left, days_left]
		top_defense_countdown_label.modulate = Color(0.55, 0.90, 1.0)

	top_resources_label.text = "식량 %d  |  자재 %d  |  골드 %d  |  시민 사기 %d/%d  |  성벽 %d/%d (Lv.%d)%s  |  예상 적 속성: [%s]" % [
		GlobalData.get_resource("food"),
		GlobalData.get_resource("materials"),
		GlobalData.get_resource("gold"),
		GlobalData.citizen_morale,
		GlobalData.MAX_MORALE,
		GlobalData.wall_hp,
		GlobalData.wall_max_hp,
		GlobalData.wall_level,
		"  |  " + GlobalData.get_territory_debuff_summary() if not GlobalData.get_territory_debuff_summary().is_empty() else "",
		GlobalData.get_upcoming_defense_elements_text(),
	]


func _on_calendar_button_pressed() -> void:
	if _calendar_modal != null:
		_calendar_modal.open_calendar()


func _refresh_footer() -> void:
	var elem_info: String = "  |  다음 디펜스 예상 적 속성: [%s]" % GlobalData.get_upcoming_defense_elements_text()
	if TimeManager.is_defense_day():
		footer_status_label.text = "다음 페이즈: ⚠ 5일 주기 디펜스 데이 — 성벽 방어전(DefenseScene)으로 출정합니다." + elem_info
		footer_status_label.modulate = Color(1.0, 0.72, 0.45)
	else:
		footer_status_label.text = "다음 페이즈: 평일 오펜스 — 던전 탐험(DungeonMapScene)으로 출정합니다." + elem_info
		footer_status_label.modulate = Color(0.75, 0.90, 1.0)


func _on_ready_deploy_pressed() -> void:
	if TimeManager.is_defense_day():
		ready_for_next_phase.emit()
		if GlobalData.current_phase == GlobalData.GamePhase.TOWN:
			TimeManager.advance_phase()
		return
	_open_dungeon_deploy_popup()


# ==========================================
# 탭 1: 보유 영웅 관리
# ==========================================
func _refresh_hero_roster_tab() -> void:
	var roster: Array[Dictionary] = GlobalData.hero_roster
	hero_count_label.text = "보유 영웅 (%d명)" % roster.size()

	hero_roster_list.clear()
	var selected_idx: int = -1
	for i in range(roster.size()):
		var hero: Dictionary = roster[i]
		var uid: int = int(hero.get("uid", -1))
		var hp: int = int(hero.get("hp", 0))
		var max_hp: int = roundi(GlobalData.get_effective_stat(hero, "max_hp"))
		var elem_name: String = DataManager.get_element_name(str(hero.get("element", "")))
		var state_str: String = ""
		if hp <= 0:
			state_str = " [전투불능]"
		elif hp < max_hp:
			state_str = " [부상]"
		var fatigue_val: int = int(hero.get("fatigue", 0))
		if GlobalData.is_hero_exhausted(hero):
			state_str += " [탈진]"
		elif GlobalData.is_hero_tired(hero):
			state_str += " [지침]"

		var rarity: String = DataManager.normalize_rarity(hero.get("rarity", "N"))
		var is_named: bool = bool(hero.get("is_named", false))
		var named_prefix: String = "★" if is_named else ""
		var title_str: String = " «%s»" % str(hero.get("named_title", "")) if is_named and not str(hero.get("named_title", "")).is_empty() else ""
		var row_text: String = "%s[%s][Lv.%d] %s%s (%s | %s) HP %d/%d | 피로 %d%%%s" % [
			named_prefix,
			rarity,
			int(hero.get("level", 1)),
			str(hero.get("name", "영웅")),
			title_str,
			str(hero.get("job_class", "근접딜러")),
			elem_name,
			hp,
			max_hp,
			fatigue_val,
			state_str,
		]
		hero_roster_list.add_item(row_text)
		hero_roster_list.set_item_metadata(i, uid)
		if uid == _selected_hero_uid:
			selected_idx = i

	if selected_idx == -1 and not roster.is_empty():
		selected_idx = 0
		_selected_hero_uid = int(roster[0].get("uid", -1))

	if selected_idx >= 0:
		hero_roster_list.select(selected_idx)
		_display_hero_detail(roster[selected_idx])
	else:
		_display_empty_hero_detail()


func _on_hero_selected(index: int) -> void:
	if index < 0 or index >= GlobalData.hero_roster.size():
		return
	var hero: Dictionary = GlobalData.hero_roster[index]
	_selected_hero_uid = int(hero.get("uid", -1))
	hero_action_status_label.text = ""
	_display_hero_detail(hero)


func _display_empty_hero_detail() -> void:
	hero_element_swatch.color = Color.GRAY
	hero_rarity_label.text = "[-]"
	hero_rarity_label.modulate = Color.WHITE
	hero_title_label.text = "보유 중인 영웅이 없습니다."
	hero_deployment_label.text = "주점·길드 탭에서 신규 영웅을 영입하세요."
	hero_hp_bar.max_value = 100
	hero_hp_bar.value = 0
	hero_hp_label.text = "HP 0 / 0"
	hero_fatigue_bar.max_value = GlobalData.MAX_FATIGUE
	hero_fatigue_bar.value = 0
	hero_fatigue_label.text = "피로도: 0 / 100 [-]"
	hero_fatigue_label.modulate = Color.WHITE
	hero_stats_label.text = "-"
	skills_header_label.text = "보유 스킬창"
	passive_skill_label.visible = true
	passive_skill_label.text = "[패시브] -"
	active_skill_label.visible = false
	active2_skill_label.visible = false
	ultimate_skill_label.visible = false
	equip_passive_label.visible = false
	equip_weapon_button.text = "무기: (없음)"
	equip_weapon_button.disabled = true
	equip_armor_button.text = "방어구: (없음)"
	equip_armor_button.disabled = true
	equip_accessory_button.text = "장신구: (없음)"
	equip_accessory_button.disabled = true
	_refresh_hero_action_buttons()


func _format_skill_line(slot_label: String, skill_id: String, fallback_text: String = "") -> String:
	var skill: Dictionary = DataManager.get_skill(skill_id) if not skill_id.is_empty() else {}
	if not skill.is_empty():
		var eff_parts: PackedStringArray = []
		for eff in skill.get("effects", []):
			var e_label: String = StatusEffectManager.get_effect_label(str(eff.get("effect_type", "")))
			eff_parts.append("%s(×%.2f)" % [e_label, float(eff.get("multiplier", 1.0))])
		return "[%s] %s (쿨다운 %d턴): %s [%s]" % [
			slot_label,
			str(skill.get("name", skill_id)),
			int(skill.get("cooldown", 1)),
			str(skill.get("description", "")),
			", ".join(eff_parts),
		]
	if not fallback_text.is_empty():
		return "[%s] %s" % [slot_label, fallback_text]
	return "[%s] 미장착" % slot_label


func _display_hero_detail(hero: Dictionary) -> void:
	var elem_id: String = str(hero.get("element", "FIRE"))
	var elem_name: String = DataManager.get_element_name(elem_id)
	hero_element_swatch.color = DataManager.get_element_color(elem_id)

	var rarity: String = DataManager.normalize_rarity(hero.get("rarity", "N"))
	hero_rarity_label.text = "[★네임드·%s]" % rarity if bool(hero.get("is_named", false)) else "[%s]" % rarity
	hero_rarity_label.modulate = DataManager.get_rarity_color(rarity)

	var is_named: bool = bool(hero.get("is_named", false))
	var named_title: String = str(hero.get("named_title", ""))
	var title_suffix: String = "  «%s»" % named_title if is_named and not named_title.is_empty() else ""
	hero_title_label.text = "[Lv.%d] %s%s  —  %s · %s" % [
		int(hero.get("level", 1)),
		str(hero.get("name", "영웅")),
		title_suffix,
		DataManager.normalize_role_category(str(hero.get("role_category", "전위")), str(hero.get("job_class", ""))),
		str(hero.get("job_class", "근접딜러")),
	]

	var sig_id: String = str(hero.get("signature_equip_id", ""))
	var sig_note: String = ""
	if not sig_id.is_empty():
		var sig_tpl: Dictionary = DataManager.get_equipment(sig_id)
		var sig_name: String = str(sig_tpl.get("name", sig_id)) if not sig_tpl.is_empty() else sig_id
		var sig_active: bool = false
		for eq_tpl in GlobalData.get_hero_equipped_templates(hero):
			if GlobalData.is_signature_resonance_active(hero, eq_tpl):
				sig_active = true
				break
		sig_note = "  |  ★전용장비 [%s]: %s" % [sig_name, "공명 활성!" if sig_active else "미장착"]

	var lore_str: String = str(hero.get("lore", ""))
	var lore_line: String = "\n" + lore_str if is_named and not lore_str.is_empty() else ""
	hero_deployment_label.text = "등급: %s  |  속성: %s  |  오펜스 배치: %s  |  디펜스 배치: %s%s%s" % [
		rarity,
		elem_name,
		str(hero.get("offense_rank", "전열")),
		str(hero.get("defense_zone", "성벽밖")),
		sig_note,
		lore_line,
	]

	var hp: int = int(hero.get("hp", 0))
	var max_hp: int = maxi(1, roundi(GlobalData.get_effective_stat(hero, "max_hp")))
	hero_hp_bar.max_value = max_hp
	hero_hp_bar.value = hp
	hero_hp_label.text = "체력: %d / %d" % [hp, max_hp]

	var fatigue_val: int = int(hero.get("fatigue", 0))
	var f_state: String = GlobalData.get_hero_fatigue_state_label(hero)
	var f_costs: Dictionary = DataManager.get_class_fatigue_costs(str(hero.get("job_class", "")))
	hero_fatigue_bar.max_value = GlobalData.MAX_FATIGUE
	hero_fatigue_bar.value = fatigue_val
	hero_fatigue_label.text = "피로도: %d / %d [%s] (이동+%d/전투+%d)" % [
		fatigue_val, GlobalData.MAX_FATIGUE, f_state, int(f_costs.get("move", 4)), int(f_costs.get("battle", 10))
	]
	if GlobalData.is_hero_exhausted(hero):
		hero_fatigue_label.modulate = Color(1.0, 0.35, 0.35)
		hero_fatigue_bar.modulate = Color(1.0, 0.35, 0.35)
	elif GlobalData.is_hero_tired(hero):
		hero_fatigue_label.modulate = Color(1.0, 0.72, 0.30)
		hero_fatigue_bar.modulate = Color(1.0, 0.72, 0.30)
	else:
		hero_fatigue_label.modulate = Color(0.68, 0.92, 1.0)
		hero_fatigue_bar.modulate = Color(0.45, 0.85, 1.0)

	var eff_atk: int = roundi(GlobalData.get_effective_stat(hero, "atk"))
	var eff_def: int = roundi(GlobalData.get_effective_stat(hero, "def"))
	var eff_spd: int = roundi(GlobalData.get_effective_stat(hero, "speed"))
	var eff_dmg_bonus: float = GlobalData.get_effective_stat(hero, "dmg_bonus") * 100.0
	var eff_crit_rate: float = GlobalData.get_effective_stat(hero, "crit_rate") * 100.0
	var eff_crit_dmg: float = GlobalData.get_effective_stat(hero, "crit_dmg") * 100.0
	var eff_armor_pen: float = GlobalData.get_effective_stat(hero, "armor_pen") * 100.0
	var eff_final_mult: float = GlobalData.get_effective_stat(hero, "final_dmg_mult")

	hero_stats_label.text = (
		"공격력(ATK): %d    방어력(DEF): %d    치유력(HEAL): %d    속도(SPD): %d\n"
		+ "피해 증가: +%.0f%%    치명타율: %.0f%%    치명타 피해: %.0f%%    방어관통: %.0f%%    최종배율: ×%.2f"
	) % [
		eff_atk,
		eff_def,
		int(hero.get("heal_power", 0)),
		eff_spd,
		eff_dmg_bonus,
		eff_crit_rate,
		eff_crit_dmg,
		eff_armor_pen,
		eff_final_mult,
	]

	_refresh_hero_equip_slot_buttons(hero)

	# 레어도별 스킬창 구성:
	# N: 패시브 / R: 패시브 + 액티브1 / SR: 패시브 + 액티브1 + 액티브2 / SSR: 패시브 + 액티브1,2 + 궁극기
	var rules: Dictionary = DataManager.get_skill_slot_rules(rarity)
	match rarity:
		"N":
			skills_header_label.text = "보유 스킬창 [N등급: 패시브]"
		"R":
			skills_header_label.text = "보유 스킬창 [R등급: 패시브 + 액티브1]"
		"SR":
			skills_header_label.text = "보유 스킬창 [SR등급: 패시브 + 액티브1 + 액티브2]"
		"SSR":
			skills_header_label.text = "보유 스킬창 [SSR등급: 패시브 + 액티브1·2 + 궁극기]"

	passive_skill_label.visible = bool(rules["passive"])
	passive_skill_label.text = "[패시브] %s: %s" % [
		str(hero.get("passive_name", "기본 소양")),
		str(hero.get("passive_desc", "-")),
	]

	active_skill_label.visible = bool(rules["active1"])
	if active_skill_label.visible:
		active_skill_label.text = _format_skill_line(
			"액티브 1",
			str(hero.get("skill_id", "")),
			str(hero.get("skill_description", ""))
		)

	active2_skill_label.visible = bool(rules["active2"])
	if active2_skill_label.visible:
		active2_skill_label.text = _format_skill_line(
			"액티브 2",
			str(hero.get("skill2_id", ""))
		)

	ultimate_skill_label.visible = bool(rules["ultimate"])
	if ultimate_skill_label.visible:
		var ult_id: String = str(hero.get("ultimate_id", ""))
		var ult_fallback: String = "%s: %s" % [
			str(hero.get("ultimate_name", "궁극기")),
			str(hero.get("ultimate_desc", "-")),
		]
		ultimate_skill_label.text = _format_skill_line("궁극기", ult_id, ult_fallback)

	var eq_passives: Array[Dictionary] = GlobalData.get_hero_equipment_passives(hero)
	if eq_passives.is_empty():
		equip_passive_label.visible = false
	else:
		var ep_lines: PackedStringArray = []
		for entry in eq_passives:
			var sk: Dictionary = entry["skill"]
			var tag: String = "★전용 공명" if bool(entry.get("is_resonance", false)) else "장비 패시브"
			ep_lines.append("[%s · %s] %s: %s" % [
				tag,
				str(entry["equipment_name"]),
				str(sk.get("name", "")),
				str(sk.get("description", "")),
			])
		equip_passive_label.visible = true
		equip_passive_label.text = "\n".join(ep_lines)

	_refresh_hero_action_buttons()


func _get_train_cost(hero: Dictionary) -> Dictionary:
	var lv: int = maxi(1, int(hero.get("level", 1)))
	return {
		"food": 8 * lv,
		"gold": 20 * lv,
	}


func _refresh_hero_action_buttons() -> void:
	var hero: Dictionary = GlobalData.get_hero_by_uid(_selected_hero_uid)
	var any_fatigued: bool = false
	for h in GlobalData.hero_roster:
		if int(h.get("fatigue", 0)) > 0:
			any_fatigued = true
			break
	var can_party_rest: bool = any_fatigued and GlobalData.can_afford(PARTY_REST_COST)
	party_rest_button.text = "전체 숙소 휴식 (피로 -%d)\n[식량 %d, 골드 %d]" % [
		PARTY_REST_FATIGUE_RECOVERY, PARTY_REST_COST["food"], PARTY_REST_COST["gold"]
	]
	party_rest_button.disabled = not can_party_rest
	if not any_fatigued:
		party_rest_button.tooltip_text = "피로가 쌓인 영웅이 없습니다."
	elif not GlobalData.can_afford(PARTY_REST_COST):
		party_rest_button.tooltip_text = "전체 숙소 휴식에 필요한 자원이 부족합니다."
	else:
		party_rest_button.tooltip_text = "보유 영웅 전원의 피로도를 %d 낮춥니다." % PARTY_REST_FATIGUE_RECOVERY

	if hero.is_empty():
		hero_heal_button.disabled = true
		hero_heal_button.text = "숙소 휴식 / 치료"
		hero_train_button.disabled = true
		hero_train_button.text = "훈련 / 레벨업"
		return

	var hp: int = int(hero.get("hp", 0))
	var max_hp: int = roundi(GlobalData.get_effective_stat(hero, "max_hp"))
	var fatigue_val: int = int(hero.get("fatigue", 0))
	var needs_care: bool = (hp < max_hp) or (fatigue_val > 0)
	var can_heal_cost: bool = GlobalData.can_afford(HEAL_COST)

	hero_heal_button.text = "숙소 휴식 / 치료 (HP전액·피로-%d)\n[식량 %d, 골드 %d]" % [
		HERO_REST_FATIGUE_RECOVERY, HEAL_COST["food"], HEAL_COST["gold"]
	]
	hero_heal_button.disabled = (not needs_care) or (not can_heal_cost)
	if not needs_care:
		hero_heal_button.tooltip_text = "체력과 컨디션이 이미 최상입니다."
	elif not can_heal_cost:
		hero_heal_button.tooltip_text = "치료 및 휴식에 필요한 자원이 부족합니다."
	else:
		hero_heal_button.tooltip_text = ""

	var train_cost: Dictionary = _get_train_cost(hero)
	var can_train_cost: bool = GlobalData.can_afford(train_cost)
	hero_train_button.text = "훈련 / 레벨업 (Lv.%d → %d)\n[식량 %d, 골드 %d]" % [
		int(hero.get("level", 1)),
		int(hero.get("level", 1)) + 1,
		train_cost["food"],
		train_cost["gold"],
	]
	hero_train_button.disabled = not can_train_cost
	hero_train_button.tooltip_text = "" if can_train_cost else "훈련에 필요한 자원이 부족합니다."


func _on_hero_heal_pressed() -> void:
	var hero: Dictionary = GlobalData.get_hero_by_uid(_selected_hero_uid)
	if hero.is_empty():
		return
	var eff_max_hp: int = roundi(GlobalData.get_effective_stat(hero, "max_hp"))
	var fatigue_val: int = int(hero.get("fatigue", 0))
	if int(hero.get("hp", 0)) >= eff_max_hp and fatigue_val <= 0:
		hero_action_status_label.text = "%s은(는) 이미 체력과 컨디션이 최상입니다." % hero["name"]
		hero_action_status_label.modulate = Color(0.85, 0.85, 0.85)
		return
	if not GlobalData.spend_resources(HEAL_COST):
		hero_action_status_label.text = "자원 부족: 휴식/치료에는 식량 %d, 골드 %d이 필요합니다." % [HEAL_COST["food"], HEAL_COST["gold"]]
		hero_action_status_label.modulate = Color(1.0, 0.5, 0.45)
		return

	var gained: int = GlobalData.heal_hero(_selected_hero_uid)
	var reduced: int = GlobalData.recover_hero_fatigue(_selected_hero_uid, HERO_REST_FATIGUE_RECOVERY)
	hero_action_status_label.text = "%s 휴식/치료 완료! 체력 +%d, 피로도 -%d (HP %d/%d, 피로 %d)" % [
		hero["name"],
		gained,
		reduced,
		int(hero["hp"]),
		eff_max_hp,
		int(hero.get("fatigue", 0)),
	]
	hero_action_status_label.modulate = Color(0.55, 0.95, 0.65)


func _on_party_rest_pressed() -> void:
	if not GlobalData.spend_resources(PARTY_REST_COST):
		hero_action_status_label.text = "자원 부족: 전체 휴식에는 식량 %d, 골드 %d이 필요합니다." % [PARTY_REST_COST["food"], PARTY_REST_COST["gold"]]
		hero_action_status_label.modulate = Color(1.0, 0.5, 0.45)
		return
	GlobalData.recover_all_roster_fatigue(PARTY_REST_FATIGUE_RECOVERY)
	hero_action_status_label.text = "숙소 전체 휴식 완료! 모든 영웅의 피로도가 %d 감소했습니다." % PARTY_REST_FATIGUE_RECOVERY
	hero_action_status_label.modulate = Color(0.55, 0.95, 0.65)


func _on_hero_train_pressed() -> void:
	var hero: Dictionary = GlobalData.get_hero_by_uid(_selected_hero_uid)
	if hero.is_empty():
		return
	var cost: Dictionary = _get_train_cost(hero)
	if not GlobalData.spend_resources(cost):
		hero_action_status_label.text = "자원 부족: 훈련에는 식량 %d, 골드 %d이 필요합니다." % [cost["food"], cost["gold"]]
		hero_action_status_label.modulate = Color(1.0, 0.5, 0.45)
		return

	var res: Dictionary = GlobalData.level_up_hero(_selected_hero_uid)
	hero_action_status_label.text = "%s 훈련 성공! Lv.%d 달성 (HP +%d, ATK +%d, DEF +%d%s)" % [
		hero["name"],
		int(res["level"]),
		int(res["hp_gain"]),
		int(res["atk_gain"]),
		int(res["def_gain"]),
		", HEAL +%d" % int(res["heal_gain"]) if int(res["heal_gain"]) > 0 else "",
	]
	hero_action_status_label.modulate = Color(0.55, 0.95, 0.65)


# ==========================================
# 탭 2: 신규 영웅 모집 (주점/길드)
# ==========================================
func _get_recruit_cost_for_template(tpl: Dictionary) -> Dictionary:
	var rarity: String = DataManager.normalize_rarity(tpl.get("rarity", "N"))
	return (RECRUIT_COST_BY_RARITY.get(rarity, RECRUIT_COST_BY_RARITY["N"]) as Dictionary).duplicate()


func _roll_recruit_candidates() -> void:
	_recruit_candidates.clear()
	var pool: Array[Dictionary] = []
	var generic_pool: Array[Dictionary] = []
	for h in DataManager.heroes:
		if not GlobalData.can_recruit_hero_in_tavern(h):
			continue
		pool.append(h.duplicate(true))
		if not bool(h.get("is_named", false)):
			generic_pool.append(h.duplicate(true))

	if pool.is_empty():
		return

	pool.shuffle()
	var pick_count: int = mini(3, pool.size())
	for i in range(pick_count):
		var tpl: Dictionary = pool[i]
		_recruit_candidates.append({
			"template": tpl,
			"cost": _get_recruit_cost_for_template(tpl),
			"recruited": false,
		})

	# 후보 풀이 3종 미만일 경우 일반 영웅에 한해 중복 허용해 3슬롯 채움 (네임드는 1장만 등장)
	while _recruit_candidates.size() < 3 and not generic_pool.is_empty():
		var extra_tpl: Dictionary = generic_pool[randi() % generic_pool.size()].duplicate(true)
		_recruit_candidates.append({
			"template": extra_tpl,
			"cost": _get_recruit_cost_for_template(extra_tpl),
			"recruited": false,
		})


func _on_refresh_recruit_pressed() -> void:
	if not GlobalData.spend_resources(REFRESH_RECRUIT_COST):
		tavern_status_label.text = "자원 부족: 목록 새로고침에는 골드 %d이 필요합니다." % REFRESH_RECRUIT_COST["gold"]
		tavern_status_label.modulate = Color(1.0, 0.5, 0.45)
		return
	_roll_recruit_candidates()
	tavern_status_label.text = "모집 목록을 새로고침했습니다! (골드 -%d)" % REFRESH_RECRUIT_COST["gold"]
	tavern_status_label.modulate = Color(0.75, 0.90, 1.0)
	_refresh_tavern_ui()


func _refresh_tavern_ui() -> void:
	var can_refresh: bool = GlobalData.can_afford(REFRESH_RECRUIT_COST)
	refresh_recruit_button.text = "모집 목록 새로고침 (골드 %d)" % REFRESH_RECRUIT_COST["gold"]
	refresh_recruit_button.disabled = not can_refresh or DataManager.heroes.is_empty()

	for child in candidates_hbox.get_children():
		child.queue_free()

	if _recruit_candidates.is_empty():
		tavern_info_label.text = "모집 가능한 영웅 데이터(DataManager.heroes)가 없습니다."
		return

	tavern_info_label.text = "술집 모집 후보 (스토리 전용 네임드 제외 · %d명 풀에서 3명 등장) — 등급별 비용/스킬 차이" % DataManager.heroes.size()

	for i in range(_recruit_candidates.size()):
		var entry: Dictionary = _recruit_candidates[i]
		var card := _build_candidate_card(i, entry)
		candidates_hbox.add_child(card)


func _build_candidate_card(idx: int, entry: Dictionary) -> PanelContainer:
	var tpl: Dictionary = entry["template"]
	var cost: Dictionary = entry["cost"]
	var is_recruited: bool = bool(entry.get("recruited", false))
	var can_afford: bool = GlobalData.can_afford(cost)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# 상단 이름 + 속성 컬러바
	var head_hbox := HBoxContainer.new()
	head_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(head_hbox)

	var elem_id: String = str(tpl.get("element", "FIRE"))
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(20, 20)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.color = DataManager.get_element_color(elem_id)
	head_hbox.add_child(swatch)

	var is_named: bool = bool(tpl.get("is_named", false))
	var named_title: String = str(tpl.get("named_title", ""))

	var rarity: String = DataManager.normalize_rarity(tpl.get("rarity", "N"))
	var rarity_lbl := Label.new()
	rarity_lbl.add_theme_font_size_override("font_size", 18)
	rarity_lbl.modulate = DataManager.get_rarity_color(rarity)
	rarity_lbl.text = "[★네임드·%s]" % rarity if is_named else "[%s]" % rarity
	head_hbox.add_child(rarity_lbl)

	var name_lbl := Label.new()
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.text = "%s (%s)" % [str(tpl.get("name", "영웅")), DataManager.get_element_name(elem_id)]
	head_hbox.add_child(name_lbl)

	var role_lbl := Label.new()
	role_lbl.add_theme_font_size_override("font_size", 13)
	role_lbl.modulate = Color(0.98, 0.86, 0.52) if is_named else Color(0.8, 0.88, 0.96)
	var title_tag: String = "«%s»  |  " % named_title if is_named and not named_title.is_empty() else ""
	role_lbl.text = "%s%s · %s  |  오펜스:%s / 디펜스:%s" % [
		title_tag,
		DataManager.normalize_role_category(str(tpl.get("role_category", "전위")), str(tpl.get("job_class", ""))),
		str(tpl.get("job_class", "근접딜러")),
		str(tpl.get("offense_rank", "전열")),
		str(tpl.get("defense_zone", "성벽밖")),
	]
	vbox.add_child(role_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var stats_lbl := Label.new()
	stats_lbl.add_theme_font_size_override("font_size", 13)
	stats_lbl.text = "HP: %d  |  ATK: %d  |  DEF: %d\nHEAL: %d  |  SPD: %d  |  치명: %.0f%%" % [
		int(tpl.get("max_hp", 50)),
		int(tpl.get("atk", 15)),
		int(tpl.get("def", 10)),
		int(tpl.get("heal_power", 0)),
		int(tpl.get("speed", 10)),
		float(tpl.get("crit_rate", 0.05)) * 100.0,
	]
	vbox.add_child(stats_lbl)

	var rules: Dictionary = DataManager.get_skill_slot_rules(rarity)
	var skill_lines: PackedStringArray = ["스킬창 [%s등급]: 패시브" % rarity]
	if bool(rules["active1"]):
		var s1: Dictionary = DataManager.get_skill(str(tpl.get("skill_id", "")))
		skill_lines.append("• 액티브1: %s" % (str(s1.get("name", "없음")) if not s1.is_empty() else "미지정"))
	if bool(rules["active2"]):
		var s2: Dictionary = DataManager.get_skill(str(tpl.get("skill2_id", "")))
		skill_lines.append("• 액티브2: %s" % (str(s2.get("name", "없음")) if not s2.is_empty() else "미지정"))
	if bool(rules["ultimate"]):
		var su: Dictionary = DataManager.get_skill(str(tpl.get("ultimate_id", "")))
		skill_lines.append("• 궁극기: %s" % (str(su.get("name", "없음")) if not su.is_empty() else "미지정"))
	var skill_desc: String = str(tpl.get("skill_description", ""))
	if not skill_desc.is_empty():
		skill_lines.append(skill_desc)

	var skill_lbl := Label.new()
	skill_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_lbl.add_theme_font_size_override("font_size", 12)
	skill_lbl.modulate = Color(0.88, 0.88, 0.88)
	skill_lbl.text = "\n".join(skill_lines)
	vbox.add_child(skill_lbl)

	var recruit_btn := Button.new()
	recruit_btn.custom_minimum_size = Vector2(0, 44)
	var already_owned_named: bool = not GlobalData.can_recruit_hero(tpl)
	if is_recruited:
		recruit_btn.text = "영입 완료"
		recruit_btn.disabled = true
	elif already_owned_named:
		recruit_btn.text = "보유 중 (네임드 유일 영웅)"
		recruit_btn.disabled = true
	elif not can_afford:
		recruit_btn.text = "영입 불가 (자원 부족)\n골드 %d, 식량 %d" % [cost["gold"], cost["food"]]
		recruit_btn.disabled = true
	else:
		recruit_btn.text = "영입하기 (골드 %d, 식량 %d)" % [cost["gold"], cost["food"]]
		recruit_btn.disabled = false
	recruit_btn.pressed.connect(_on_recruit_candidate_pressed.bind(idx))
	vbox.add_child(recruit_btn)

	return panel


func _on_recruit_candidate_pressed(idx: int) -> void:
	if idx < 0 or idx >= _recruit_candidates.size():
		return
	var entry: Dictionary = _recruit_candidates[idx]
	if bool(entry.get("recruited", false)):
		return

	var tpl: Dictionary = entry["template"]
	if not GlobalData.can_recruit_hero(tpl):
		tavern_status_label.text = "이미 보유 중인 네임드 영웅(%s)은 중복 영입할 수 없습니다." % str(tpl.get("name", ""))
		tavern_status_label.modulate = Color(1.0, 0.65, 0.35)
		_refresh_tavern_ui()
		return

	var cost: Dictionary = entry["cost"]
	if not GlobalData.spend_resources(cost):
		tavern_status_label.text = "자원 부족: 영입에는 골드 %d, 식량 %d이 필요합니다." % [cost["gold"], cost["food"]]
		tavern_status_label.modulate = Color(1.0, 0.5, 0.45)
		return

	var new_hero: Dictionary = GlobalData.recruit_hero(tpl)
	if new_hero.is_empty():
		return
	entry["recruited"] = true
	_selected_hero_uid = int(new_hero["uid"])

	tavern_status_label.text = "★ [%s] 영웅을 로스터에 영입했습니다! (현재 총 %d명)" % [
		str(new_hero["name"]),
		GlobalData.hero_roster.size(),
	]
	tavern_status_label.modulate = Color(0.55, 0.95, 0.65)
	_refresh_tavern_ui()


# ==========================================
# 탭 3: 마을 및 성벽 시설 관리
# ==========================================
func _get_wall_expand_cost() -> Dictionary:
	return {
		"materials": 20 + (GlobalData.wall_level - 1) * 10,
		"gold": 30 + (GlobalData.wall_level - 1) * 15,
	}


func _get_farm_upgrade_cost() -> Dictionary:
	return {
		"materials": 15 * GlobalData.farm_level,
		"gold": 25 * GlobalData.farm_level,
	}


func _get_mill_upgrade_cost() -> Dictionary:
	return {
		"materials": 12 * GlobalData.lumber_mill_level,
		"gold": 25 * GlobalData.lumber_mill_level,
	}


func _refresh_facilities_ui() -> void:
	var daily_food_base: int = BASE_FOOD_PROD + (GlobalData.farm_level - 1) * 5
	var daily_mat_base: int = BASE_MAT_PROD + (GlobalData.lumber_mill_level - 1) * 4
	facility_summary_label.text = (
		"농장 Lv.%d (기본 식량 +%d/일)  |  제재소 Lv.%d (기본 자재 +%d/일)  |  시민 사기 %d/%d"
	) % [
		GlobalData.farm_level,
		daily_food_base,
		GlobalData.lumber_mill_level,
		daily_mat_base,
		GlobalData.citizen_morale,
		GlobalData.MAX_MORALE,
	]

	var bs_wall: Dictionary = GlobalData.get_base_tower_stats()
	var mounted_cnt: int = 0
	for sid in GlobalData.equipped_tower_slots:
		if not sid.is_empty():
			mounted_cnt += 1
	wall_summary_label.text = "성벽 Lv.%d (내구도 %d / %d)  |  기본 포탑 ATK %d (%.2fs)  |  커스텀 타워 장착 %d / %d" % [
		GlobalData.wall_level,
		GlobalData.wall_hp,
		GlobalData.wall_max_hp,
		int(bs_wall["atk"]),
		float(bs_wall["attack_interval"]),
		mounted_cnt,
		GlobalData.MAX_TOWER_SLOTS,
	]

	# 1. 성벽 수리
	var wall_damaged: bool = GlobalData.wall_hp < GlobalData.wall_max_hp
	repair_wall_desc_label.text = "성벽 내구도 +%d 회복 (현재 %d/%d)" % [WALL_REPAIR_AMOUNT, GlobalData.wall_hp, GlobalData.wall_max_hp]
	if not wall_damaged:
		repair_wall_button.text = "수리 불필요 (최대 내구도)"
		repair_wall_button.disabled = true
	else:
		repair_wall_button.text = "성벽 수리\n(자재 %d, 골드 %d)" % [WALL_REPAIR_COST["materials"], WALL_REPAIR_COST["gold"]]
		repair_wall_button.disabled = not GlobalData.can_afford(WALL_REPAIR_COST)

	# 2. 성벽 최대 내구도 증축
	var expand_cost: Dictionary = _get_wall_expand_cost()
	expand_wall_desc_label.text = "성벽 Lv.%d → Lv.%d 증축 (최대/현재 내구도 +%d)" % [
		GlobalData.wall_level,
		GlobalData.wall_level + 1,
		WALL_EXPAND_HP_GAIN,
	]
	expand_wall_button.text = "성벽 증축\n(자재 %d, 골드 %d)" % [expand_cost["materials"], expand_cost["gold"]]
	expand_wall_button.disabled = not GlobalData.can_afford(expand_cost)

	# 3. 농장 업그레이드
	var farm_cost: Dictionary = _get_farm_upgrade_cost()
	upgrade_farm_desc_label.text = "농장 Lv.%d → Lv.%d 확장 (1일 기본 식량 생산 %d → %d)" % [
		GlobalData.farm_level,
		GlobalData.farm_level + 1,
		daily_food_base,
		daily_food_base + 5,
	]
	upgrade_farm_button.text = "농장 업그레이드\n(자재 %d, 골드 %d)" % [farm_cost["materials"], farm_cost["gold"]]
	upgrade_farm_button.disabled = not GlobalData.can_afford(farm_cost)

	# 4. 제재소 업그레이드
	var mill_cost: Dictionary = _get_mill_upgrade_cost()
	upgrade_mill_desc_label.text = "제재소 Lv.%d → Lv.%d 확장 (1일 기본 자재 생산 %d → %d)" % [
		GlobalData.lumber_mill_level,
		GlobalData.lumber_mill_level + 1,
		daily_mat_base,
		daily_mat_base + 4,
	]
	upgrade_mill_button.text = "제재소 업그레이드\n(자재 %d, 골드 %d)" % [mill_cost["materials"], mill_cost["gold"]]
	upgrade_mill_button.disabled = not GlobalData.can_afford(mill_cost)

	# 5. 시민 사기 진작
	var morale_not_full: bool = GlobalData.citizen_morale < GlobalData.MAX_MORALE
	boost_morale_desc_label.text = "마을 광장 축제/배급 지원으로 시민 사기 +%d (현재 %d/%d)" % [
		MORALE_BOOST_AMOUNT,
		GlobalData.citizen_morale,
		GlobalData.MAX_MORALE,
	]
	if not morale_not_full:
		boost_morale_button.text = "사기 최대치 (100/100)"
		boost_morale_button.disabled = true
	else:
		boost_morale_button.text = "사기 진작 투자\n(식량 %d, 골드 %d)" % [MORALE_BOOST_COST["food"], MORALE_BOOST_COST["gold"]]
		boost_morale_button.disabled = not GlobalData.can_afford(MORALE_BOOST_COST)

	_refresh_towers_ui()
	_refresh_blacksmith_ui()
	_refresh_research_ui()


func _get_base_tower_atk_cost() -> Dictionary:
	return {"materials": 14 * GlobalData.base_tower_atk_level, "gold": 25 * GlobalData.base_tower_atk_level}


func _get_base_tower_spd_cost() -> Dictionary:
	return {"materials": 14 * GlobalData.base_tower_spd_level, "gold": 25 * GlobalData.base_tower_spd_level}


func _refresh_towers_ui() -> void:
	var bs: Dictionary = GlobalData.get_base_tower_stats()
	base_tower_desc_label.text = "현재 공격력 %d (Lv.%d) | 공격 주기 %.2f초 (Lv.%d)" % [
		int(bs["atk"]), int(bs["atk_level"]), float(bs["attack_interval"]), int(bs["spd_level"])
	]
	var atk_cost: Dictionary = _get_base_tower_atk_cost()
	base_tower_atk_button.text = "공격력 강화 (+7)\n(자재 %d, 골드 %d)" % [atk_cost["materials"], atk_cost["gold"]]
	base_tower_atk_button.disabled = not GlobalData.can_afford(atk_cost)

	var spd_cost: Dictionary = _get_base_tower_spd_cost()
	base_tower_spd_button.text = "공격속도 강화 (-0.14s)\n(자재 %d, 골드 %d)" % [spd_cost["materials"], spd_cost["gold"]]
	base_tower_spd_button.disabled = (float(bs["attack_interval"]) <= 0.46) or (not GlobalData.can_afford(spd_cost))

	for child in tower_mounts_hbox.get_children():
		child.queue_free()
	for i in range(GlobalData.MAX_TOWER_SLOTS):
		var tid: String = GlobalData.equipped_tower_slots[i] if i < GlobalData.equipped_tower_slots.size() else ""
		var t_tpl: Dictionary = DataManager.get_tower(tid) if not tid.is_empty() else {}
		var m_btn := Button.new()
		m_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m_btn.custom_minimum_size = Vector2(0, 48)
		m_btn.add_theme_font_size_override("font_size", 12)
		var is_sel: bool = (i == _selected_tower_mount_idx)
		if t_tpl.is_empty():
			m_btn.text = "%s슬롯 %d: (비어 있음)" % ["▶ " if is_sel else "", i + 1]
		else:
			m_btn.text = "%s슬롯 %d: %s [%s]" % ["▶ " if is_sel else "", i + 1, str(t_tpl.get("name", tid)), str(t_tpl.get("target_scope", "SINGLE_FRONT"))]
		m_btn.modulate = Color(0.55, 0.92, 1.0) if is_sel else Color.WHITE
		m_btn.pressed.connect(_on_tower_mount_selected.bind(i))
		tower_mounts_hbox.add_child(m_btn)

	# 1) 성벽 탭: 보유한 커스텀 타워 슬롯 배치 목록
	for child in tower_mount_list_vbox.get_children():
		child.queue_free()
	var any_owned_tower: bool = false
	for t_tpl in DataManager.towers:
		var tid: String = str(t_tpl.get("id", ""))
		if not GlobalData.has_owned_tower(tid):
			continue
		any_owned_tower = true
		var equipped_at: int = GlobalData.equipped_tower_slots.find(tid)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var elem_name: String = DataManager.get_element_name(str(t_tpl.get("element", "FIRE")))
		var eff_sk: Dictionary = DataManager.get_skill(str(t_tpl.get("on_hit_effect_id", "")))
		var eff_note: String = " | 적중:%s" % str(eff_sk.get("name", "")) if not eff_sk.is_empty() else ""
		var mount_note: String = " [슬롯%d 장착중]" % (equipped_at + 1) if equipped_at >= 0 else " [대기중]"
		lbl.text = "%s [%s | %s] ATK %d / %.2fs%s%s\n%s" % [
			str(t_tpl.get("name", tid)),
			elem_name,
			str(t_tpl.get("target_scope", "SINGLE_FRONT")),
			int(t_tpl.get("atk", 20)),
			float(t_tpl.get("attack_interval", 1.5)),
			eff_note,
			mount_note,
			str(t_tpl.get("description", "")),
		]
		row.add_child(lbl)

		var act_btn := Button.new()
		act_btn.custom_minimum_size = Vector2(190, 42)
		if equipped_at == _selected_tower_mount_idx:
			act_btn.text = "슬롯 %d에서 해제" % (_selected_tower_mount_idx + 1)
			act_btn.pressed.connect(_on_unequip_tower_pressed.bind(_selected_tower_mount_idx))
		else:
			act_btn.text = "슬롯 %d에 배치" % (_selected_tower_mount_idx + 1)
			act_btn.pressed.connect(_on_equip_tower_pressed.bind(_selected_tower_mount_idx, tid))
		row.add_child(act_btn)
		tower_mount_list_vbox.add_child(row)

	if not any_owned_tower:
		var empty_mount_lbl := Label.new()
		empty_mount_lbl.add_theme_font_size_override("font_size", 13)
		empty_mount_lbl.modulate = Color(0.8, 0.84, 0.9)
		empty_mount_lbl.text = "보유 중인 커스텀 타워가 없습니다. [연구소]에서 설계를 해금한 뒤 [대장간]에서 제작하세요."
		tower_mount_list_vbox.add_child(empty_mount_lbl)

	# 2) 대장간 탭: 커스텀 타워 제작 카탈로그 (연구 해금 여부 연동)
	for child in tower_catalog_vbox.get_children():
		child.queue_free()
	for t_tpl in DataManager.towers:
		var tid: String = str(t_tpl.get("id", ""))
		var cost: Dictionary = t_tpl.get("build_cost", {"materials": 20, "gold": 30})
		var owned: bool = GlobalData.has_owned_tower(tid)
		var unlocked: bool = GlobalData.is_tower_unlocked(tid)
		var req_res_id: String = DataManager.get_required_research_for_tower(tid)
		var req_res: Dictionary = DataManager.get_research(req_res_id) if not req_res_id.is_empty() else {}
		var req_name: String = str(req_res.get("name", req_res_id))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var elem_name: String = DataManager.get_element_name(str(t_tpl.get("element", "FIRE")))
		var eff_sk: Dictionary = DataManager.get_skill(str(t_tpl.get("on_hit_effect_id", "")))
		var eff_note: String = " | 적중:%s" % str(eff_sk.get("name", "")) if not eff_sk.is_empty() else ""
		var state_note: String = " [제작 완료]" if owned else (" [연구 필요: %s]" % req_name if not unlocked else " [제작 가능]")
		lbl.text = "%s [%s | %s] ATK %d / %.2fs%s%s\n%s" % [
			str(t_tpl.get("name", tid)),
			elem_name,
			str(t_tpl.get("target_scope", "SINGLE_FRONT")),
			int(t_tpl.get("atk", 20)),
			float(t_tpl.get("attack_interval", 1.5)),
			eff_note,
			state_note,
			str(t_tpl.get("description", "")),
		]
		if not unlocked:
			lbl.modulate = Color(0.68, 0.72, 0.78)
		elif owned:
			lbl.modulate = Color(0.75, 0.96, 0.80)
		row.add_child(lbl)

		var act_btn := Button.new()
		act_btn.custom_minimum_size = Vector2(220, 42)
		if not unlocked:
			act_btn.text = "미해금 (연구소: %s)" % req_name
			act_btn.disabled = true
		elif owned:
			act_btn.text = "보유 중 (성벽 탭에서 장착)"
			act_btn.disabled = true
		else:
			act_btn.text = "타워 제작 (자재 %d, 골드 %d)" % [int(cost.get("materials", 20)), int(cost.get("gold", 30))]
			act_btn.disabled = not GlobalData.can_afford(cost)
			act_btn.pressed.connect(_on_craft_tower_pressed.bind(tid))
		row.add_child(act_btn)
		tower_catalog_vbox.add_child(row)


func _on_tower_mount_selected(idx: int) -> void:
	_selected_tower_mount_idx = idx
	_refresh_towers_ui()


func _on_upgrade_base_tower_atk_pressed() -> void:
	var cost: Dictionary = _get_base_tower_atk_cost()
	if not GlobalData.spend_resources(cost):
		_set_wall_status("자원이 부족해 기본 포탑 공격력을 강화할 수 없습니다.", false)
		return
	GlobalData.upgrade_base_tower_atk()
	_set_wall_status("성벽 기본 포탑 공격력 Lv.%d 강화 완료!" % GlobalData.base_tower_atk_level, true)


func _on_upgrade_base_tower_spd_pressed() -> void:
	var cost: Dictionary = _get_base_tower_spd_cost()
	if not GlobalData.spend_resources(cost):
		_set_wall_status("자원이 부족해 기본 포탑 공속을 강화할 수 없습니다.", false)
		return
	GlobalData.upgrade_base_tower_spd()
	_set_wall_status("성벽 기본 포탑 공격속도 Lv.%d 강화 완료!" % GlobalData.base_tower_spd_level, true)


func _on_craft_tower_pressed(tower_id: String) -> void:
	var t_tpl: Dictionary = DataManager.get_tower(tower_id)
	if t_tpl.is_empty():
		return
	if not GlobalData.is_tower_unlocked(tower_id):
		var req_res: Dictionary = DataManager.get_research(DataManager.get_required_research_for_tower(tower_id))
		_set_blacksmith_status("연구소에서 [%s] 연구를 먼저 완료해야 제작할 수 있습니다." % str(req_res.get("name", "")), false)
		return
	var cost: Dictionary = t_tpl.get("build_cost", {"materials": 20, "gold": 30})
	if not GlobalData.spend_resources(cost):
		_set_blacksmith_status("자원이 부족해 커스텀 타워를 제작할 수 없습니다.", false)
		return
	GlobalData.add_owned_tower(tower_id)
	_set_blacksmith_status("커스텀 타워 [%s] 제작 완료! (성벽 탭에서 장착 슬롯 변경 가능)" % str(t_tpl.get("name", tower_id)), true)


func _on_equip_tower_pressed(slot_idx: int, tower_id: String) -> void:
	GlobalData.equip_tower_to_slot(slot_idx, tower_id)
	var t_tpl: Dictionary = DataManager.get_tower(tower_id)
	_set_wall_status("타워 슬롯 %d에 [%s] 장착 완료!" % [slot_idx + 1, str(t_tpl.get("name", tower_id))], true)


func _on_unequip_tower_pressed(slot_idx: int) -> void:
	GlobalData.unequip_tower_slot(slot_idx)
	_set_wall_status("타워 슬롯 %d의 타워를 해제했습니다." % (slot_idx + 1), true)


func _on_repair_wall_pressed() -> void:
	if GlobalData.wall_hp >= GlobalData.wall_max_hp:
		return
	if not GlobalData.spend_resources(WALL_REPAIR_COST):
		_set_wall_status("자원이 부족해 성벽을 수리할 수 없습니다.", false)
		return
	var before: int = GlobalData.wall_hp
	GlobalData.repair_wall(WALL_REPAIR_AMOUNT)
	_set_wall_status("성벽 수리 완료! 내구도 +%d (%d/%d)" % [GlobalData.wall_hp - before, GlobalData.wall_hp, GlobalData.wall_max_hp], true)


func _on_expand_wall_pressed() -> void:
	var cost: Dictionary = _get_wall_expand_cost()
	if not GlobalData.spend_resources(cost):
		_set_wall_status("자원이 부족해 성벽을 증축할 수 없습니다.", false)
		return
	GlobalData.upgrade_wall_max_hp(WALL_EXPAND_HP_GAIN)
	_set_wall_status("성벽 증축 완료! Lv.%d 달성 (내구도 %d/%d)" % [GlobalData.wall_level, GlobalData.wall_hp, GlobalData.wall_max_hp], true)


func _on_upgrade_farm_pressed() -> void:
	var cost: Dictionary = _get_farm_upgrade_cost()
	if not GlobalData.spend_resources(cost):
		_set_facility_status("자원이 부족해 농장을 업그레이드할 수 없습니다.", false)
		return
	GlobalData.upgrade_farm()
	_set_facility_status("농장 Lv.%d 업그레이드 완료! (일일 기본 식량 생산 +5)" % GlobalData.farm_level, true)


func _on_upgrade_mill_pressed() -> void:
	var cost: Dictionary = _get_mill_upgrade_cost()
	if not GlobalData.spend_resources(cost):
		_set_facility_status("자원이 부족해 제재소를 업그레이드할 수 없습니다.", false)
		return
	GlobalData.upgrade_lumber_mill()
	_set_facility_status("제재소 Lv.%d 업그레이드 완료! (일일 기본 자재 생산 +4)" % GlobalData.lumber_mill_level, true)


func _on_boost_morale_pressed() -> void:
	if GlobalData.citizen_morale >= GlobalData.MAX_MORALE:
		return
	if not GlobalData.spend_resources(MORALE_BOOST_COST):
		_set_facility_status("자원이 부족해 사기 진작 투자를 진행할 수 없습니다.", false)
		return
	var before: int = GlobalData.citizen_morale
	GlobalData.add_morale(MORALE_BOOST_AMOUNT)
	_set_facility_status("시민 사기 진작 완료! 사기 +%d (%d/%d)" % [GlobalData.citizen_morale - before, GlobalData.citizen_morale, GlobalData.MAX_MORALE], true)


func _set_facility_status(msg: String, success: bool) -> void:
	facility_status_label.text = msg
	facility_status_label.modulate = Color(0.55, 0.95, 0.65) if success else Color(1.0, 0.5, 0.45)


func _set_wall_status(msg: String, success: bool) -> void:
	wall_status_label.text = msg
	wall_status_label.modulate = Color(0.55, 0.95, 0.65) if success else Color(1.0, 0.5, 0.45)


func _set_blacksmith_status(msg: String, success: bool) -> void:
	blacksmith_status_label.text = msg
	blacksmith_status_label.modulate = Color(0.55, 0.95, 0.65) if success else Color(1.0, 0.5, 0.45)


func _set_research_status(msg: String, success: bool) -> void:
	research_status_label.text = msg
	research_status_label.modulate = Color(0.55, 0.95, 0.65) if success else Color(1.0, 0.5, 0.45)


# ==========================================
# 영웅 장비 슬롯 & 장착 선택 팝업
# ==========================================
func _refresh_hero_equip_slot_buttons(hero: Dictionary) -> void:
	var equipped: Dictionary = hero.get("equipped_items", {})
	var btn_map: Dictionary = {
		"WEAPON": equip_weapon_button,
		"ARMOR": equip_armor_button,
		"ACCESSORY": equip_accessory_button,
	}
	for slot_type in DataManager.SLOT_TYPES:
		var btn: Button = btn_map[slot_type]
		var slot_label: String = DataManager.get_slot_label(slot_type)
		btn.disabled = false
		var inst_val: Variant = equipped.get(slot_type, null)
		if inst_val == null:
			btn.text = "%s: (비어 있음)" % slot_label
			btn.modulate = Color.WHITE
		else:
			var tpl: Dictionary = GlobalData.get_equipment_template_for_instance(int(inst_val))
			if tpl.is_empty():
				btn.text = "%s: (비어 있음)" % slot_label
				btn.modulate = Color.WHITE
			else:
				var r: String = DataManager.normalize_rarity(tpl.get("rarity", "N"))
				var is_named_eq: bool = bool(tpl.get("is_named", false))
				var res_mark: String = " [공명!]" if GlobalData.is_signature_resonance_active(hero, tpl) else ""
				var named_mark: String = "★" if is_named_eq else ""
				btn.text = "%s: %s[%s] %s%s" % [slot_label, named_mark, r, str(tpl.get("name", "")), res_mark]
				btn.modulate = Color(1.0, 0.88, 0.40) if not res_mark.is_empty() else DataManager.get_rarity_color(r)


func _open_equip_picker(slot_type: String) -> void:
	var hero: Dictionary = GlobalData.get_hero_by_uid(_selected_hero_uid)
	if hero.is_empty():
		return
	_picking_slot_type = slot_type
	equip_picker_overlay.visible = true
	_refresh_equip_picker_list()


func _close_equip_picker() -> void:
	equip_picker_overlay.visible = false
	_picking_slot_type = ""


func _refresh_equip_picker_list() -> void:
	for child in equip_picker_list_vbox.get_children():
		child.queue_free()

	var hero: Dictionary = GlobalData.get_hero_by_uid(_selected_hero_uid)
	if hero.is_empty() or _picking_slot_type.is_empty():
		_close_equip_picker()
		return

	var slot_label: String = DataManager.get_slot_label(_picking_slot_type)
	equip_picker_title_label.text = "%s — %s 장착 선택" % [str(hero.get("name", "영웅")), slot_label]
	equip_picker_sub_label.text = "전용 장비 및 직업군 제한(%s)을 통과한 보유 %s만 표시됩니다." % [
		str(hero.get("job_class", "")),
		slot_label,
	]

	var equipped: Dictionary = hero.get("equipped_items", {})
	var current_inst_val: Variant = equipped.get(_picking_slot_type, null)
	var current_inst_id: int = int(current_inst_val) if current_inst_val != null else -1
	equip_picker_unequip_button.disabled = (current_inst_id == -1)

	var matching_count: int = 0
	for item in GlobalData.equipment_inventory:
		var inst_id: int = int(item.get("inst_id", -1))
		var tpl: Dictionary = DataManager.get_equipment(str(item.get("equip_id", "")))
		if tpl.is_empty() or str(tpl.get("slot_type", "")) != _picking_slot_type:
			continue
		if not GlobalData.can_equip(hero, tpl):
			continue

		matching_count += 1
		var row_panel := PanelContainer.new()
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 8)
		row_panel.add_child(margin)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		margin.add_child(hbox)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_vbox)

		var r: String = DataManager.normalize_rarity(tpl.get("rarity", "N"))
		var is_named_eq: bool = bool(tpl.get("is_named", false))
		var res_tag: String = " ★[전용 공명]" if GlobalData.is_signature_resonance_active(hero, tpl) else ""
		var owner_uid: int = GlobalData.get_equipment_owner_uid(inst_id)
		var owner_tag: String = ""
		if owner_uid == _selected_hero_uid:
			owner_tag = " [현재 장착 중]"
		elif owner_uid != -1:
			var other_hero: Dictionary = GlobalData.get_hero_by_uid(owner_uid)
			if not other_hero.is_empty():
				owner_tag = " [%s 장착 중]" % str(other_hero.get("name", ""))

		var title_lbl := Label.new()
		title_lbl.add_theme_font_size_override("font_size", 14)
		title_lbl.modulate = DataManager.get_rarity_color(r)
		var eq_prefix: String = "★[네임드·%s]" % r if is_named_eq else "[%s]" % r
		title_lbl.text = "%s %s%s%s" % [eq_prefix, str(tpl.get("name", "")), res_tag, owner_tag]
		info_vbox.add_child(title_lbl)

		var detail_lbl := Label.new()
		detail_lbl.add_theme_font_size_override("font_size", 12)
		detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var bonus_text: String = _format_equipment_bonuses(tpl)
		var passive_id: String = str(tpl.get("passive_skill_id", ""))
		var passive_str: String = ""
		if not passive_id.is_empty():
			var p_skill: Dictionary = DataManager.get_skill(passive_id)
			if not p_skill.is_empty():
				passive_str = " | 패시브: %s" % str(p_skill.get("name", passive_id))
		detail_lbl.text = "%s%s\n%s" % [bonus_text, passive_str, str(tpl.get("description", ""))]
		info_vbox.add_child(detail_lbl)

		var eq_btn := Button.new()
		eq_btn.custom_minimum_size = Vector2(105, 40)
		if inst_id == current_inst_id:
			eq_btn.text = "장착됨"
			eq_btn.disabled = true
		else:
			eq_btn.text = "교체" if current_inst_id != -1 else "장착"
			eq_btn.pressed.connect(_on_equip_picker_item_pressed.bind(inst_id))
		hbox.add_child(eq_btn)

		equip_picker_list_vbox.add_child(row_panel)

	if matching_count == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "인벤토리에 장착 가능한 %s이(가) 없습니다. (마을 시설 관리 → 대장간에서 제작/구매 가능)" % slot_label
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		equip_picker_list_vbox.add_child(empty_lbl)


func _on_equip_picker_item_pressed(inst_id: int) -> void:
	var hero: Dictionary = GlobalData.get_hero_by_uid(_selected_hero_uid)
	if hero.is_empty():
		return
	var tpl: Dictionary = GlobalData.get_equipment_template_for_instance(inst_id)
	if GlobalData.equip_item(_selected_hero_uid, inst_id):
		hero_action_status_label.text = "%s에게 [%s] 장착 완료!" % [str(hero.get("name", "")), str(tpl.get("name", ""))]
		hero_action_status_label.modulate = Color(0.55, 0.95, 0.65)
		_close_equip_picker()


func _on_equip_picker_unequip_pressed() -> void:
	if _picking_slot_type.is_empty():
		return
	if GlobalData.unequip_slot(_selected_hero_uid, _picking_slot_type):
		hero_action_status_label.text = "%s 슬롯 장비를 해제했습니다." % DataManager.get_slot_label(_picking_slot_type)
		hero_action_status_label.modulate = Color(0.75, 0.90, 1.0)
	_close_equip_picker()


func _format_equipment_bonuses(tpl: Dictionary) -> String:
	var bonuses: Dictionary = tpl.get("stat_bonuses", {})
	var parts: PackedStringArray = []
	var labels: Dictionary = {
		"max_hp": "HP",
		"atk": "ATK",
		"def": "DEF",
		"speed": "SPD",
		"dmg_bonus": "피해+",
		"crit_rate": "치명%",
		"crit_dmg": "치피%",
		"armor_pen": "방관%",
		"final_dmg_mult": "최종%",
	}
	for k in DataManager.EQUIP_STAT_KEYS:
		var v: float = float(bonuses.get(k, 0.0))
		if absf(v) < 0.0001:
			continue
		if k in ["dmg_bonus", "crit_rate", "crit_dmg", "armor_pen", "final_dmg_mult"]:
			parts.append("%s %+.0f%%" % [labels[k], v * 100.0])
		else:
			parts.append("%s %+d" % [labels[k], roundi(v)])
	return ", ".join(parts) if not parts.is_empty() else "스탯 보정 없음"


# ==========================================
# 대장간 · 장비 제작 (탭 5 연동) & 연구소 (탭 6 연동)
# ==========================================
func _refresh_blacksmith_ui() -> void:
	for child in blacksmith_list_vbox.get_children():
		child.queue_free()

	if DataManager.equipments.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "장비 데이터(data/equipments.json)가 없습니다."
		blacksmith_list_vbox.add_child(empty_lbl)
		return

	var hidden_uncraftable_count: int = 0
	for eq in DataManager.equipments:
		var eq_id: String = str(eq.get("id", ""))
		if not GlobalData.is_equipment_blacksmith_craftable(eq_id):
			hidden_uncraftable_count += 1
			continue

		var rarity: String = DataManager.normalize_rarity(eq.get("rarity", "N"))
		var is_named_eq: bool = bool(eq.get("is_named", false))
		var research_unlocked: bool = GlobalData.is_equipment_research_unlocked(eq_id)
		var req_res_id: String = DataManager.get_required_research_for_equip(eq_id)
		var req_res: Dictionary = DataManager.get_research(req_res_id) if not req_res_id.is_empty() else {}
		var req_res_name: String = str(req_res.get("name", req_res_id))
		var cost: Dictionary = (BLACKSMITH_COST_BY_RARITY.get(rarity, BLACKSMITH_COST_BY_RARITY["N"]) as Dictionary)
		var can_obtain: bool = GlobalData.can_obtain_equipment(eq_id)
		var can_craft: bool = research_unlocked and can_obtain and GlobalData.can_afford(cost)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var info_lbl := Label.new()
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_lbl.add_theme_font_size_override("font_size", 13)
		var slot_lbl: String = DataManager.get_slot_label(str(eq.get("slot_type", "WEAPON")))
		var excl_id: String = str(eq.get("exclusive_hero_id", ""))
		var excl_hero: Dictionary = DataManager.get_hero_template(excl_id) if not excl_id.is_empty() else {}
		var excl_name: String = str(excl_hero.get("name", excl_id)) if not excl_hero.is_empty() else excl_id
		var excl_str: String = " [전용:%s]" % excl_name if not excl_id.is_empty() else ""
		var named_badge: String = "★네임드·" if is_named_eq else ""
		var title_tag: String = " «%s»" % str(eq.get("named_title", "")) if is_named_eq and not str(eq.get("named_title", "")).is_empty() else ""
		var lock_tag: String = " [연구 필요: %s]" % req_res_name if not research_unlocked else ""
		var owned_cnt: int = 0
		for item in GlobalData.equipment_inventory:
			if str(item.get("equip_id", "")) == eq_id:
				owned_cnt += 1
		info_lbl.text = "[%s%s][%s] %s%s%s%s (보유 %d)\n%s" % [
			named_badge,
			rarity,
			slot_lbl,
			str(eq.get("name", "")),
			title_tag,
			excl_str,
			lock_tag,
			owned_cnt,
			_format_equipment_bonuses(eq),
		]
		if not research_unlocked:
			info_lbl.modulate = Color(0.68, 0.72, 0.78)
		elif is_named_eq:
			info_lbl.modulate = Color(1.0, 0.90, 0.55)
		row.add_child(info_lbl)

		var craft_btn := Button.new()
		craft_btn.custom_minimum_size = Vector2(220, 42)
		if not research_unlocked:
			craft_btn.text = "미해금 (연구소: %s)" % req_res_name
			craft_btn.disabled = true
		elif not can_obtain:
			craft_btn.text = "보유 중 (유일 장비)"
			craft_btn.disabled = true
		else:
			craft_btn.text = "제작 (골드 %d, 자재 %d)" % [cost["gold"], cost["materials"]]
			craft_btn.disabled = not can_craft
		craft_btn.pressed.connect(_on_craft_equipment_pressed.bind(eq_id))
		row.add_child(craft_btn)

		blacksmith_list_vbox.add_child(row)

	if hidden_uncraftable_count > 0:
		var note_lbl := Label.new()
		note_lbl.add_theme_font_size_override("font_size", 12)
		note_lbl.modulate = Color(0.75, 0.78, 0.85)
		note_lbl.text = "※ 대장간 제작 불가 장비(네임드 전용 장비 등) %d종은 목록에서 제외되며 던전·이벤트 보상으로 획득할 수 있습니다." % hidden_uncraftable_count
		blacksmith_list_vbox.add_child(note_lbl)


func _on_craft_equipment_pressed(equip_id: String) -> void:
	var eq: Dictionary = DataManager.get_equipment(equip_id)
	if eq.is_empty():
		return
	if not GlobalData.is_equipment_blacksmith_craftable(equip_id):
		_set_blacksmith_status("[%s]은(는) 대장간에서 제작할 수 없는 특수/전용 장비입니다." % str(eq.get("name", "")), false)
		return
	if not GlobalData.is_equipment_research_unlocked(equip_id):
		var req_res: Dictionary = DataManager.get_research(DataManager.get_required_research_for_equip(equip_id))
		_set_blacksmith_status("연구소에서 [%s] 연구를 먼저 완료해야 제작할 수 있습니다." % str(req_res.get("name", "")), false)
		return
	if not GlobalData.can_obtain_equipment(equip_id):
		_set_blacksmith_status("유일 장비 [%s]은(는) 1개만 보유할 수 있습니다." % str(eq.get("name", "")), false)
		return
	var rarity: String = DataManager.normalize_rarity(eq.get("rarity", "N"))
	var cost: Dictionary = (BLACKSMITH_COST_BY_RARITY.get(rarity, BLACKSMITH_COST_BY_RARITY["N"]) as Dictionary)
	if not GlobalData.spend_resources(cost):
		_set_blacksmith_status("자원이 부족해 장비를 제작할 수 없습니다.", false)
		return
	GlobalData.add_equipment_to_inventory(equip_id)
	_set_blacksmith_status("[%s] %s 제작 완료! (여관 탭에서 장착 가능)" % [rarity, str(eq.get("name", ""))], true)


func _refresh_research_ui() -> void:
	for child in research_list_vbox.get_children():
		child.queue_free()

	var total_cnt: int = DataManager.researches.size()
	var done_cnt: int = 0
	for res in DataManager.researches:
		if GlobalData.is_research_completed(str(res.get("id", ""))):
			done_cnt += 1
	research_summary_label.text = "연구소 · 완료 %d / %d건 (완료 시 대장간 커스텀 포탑 및 고급 장비 제작 해금)" % [done_cnt, total_cnt]

	if DataManager.researches.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "등록된 연구 항목(data/research.json)이 없습니다."
		research_list_vbox.add_child(empty_lbl)
		return

	for res in DataManager.researches:
		var r_id: String = str(res.get("id", ""))
		var is_done: bool = GlobalData.is_research_completed(r_id)
		var prereq_id: String = str(res.get("prerequisite_id", ""))
		var prereq_done: bool = prereq_id.is_empty() or GlobalData.is_research_completed(prereq_id)
		var cost: Dictionary = res.get("cost", {"gold": 25, "materials": 15})
		var can_start: bool = (not is_done) and prereq_done and GlobalData.can_afford(cost)

		var card := PanelContainer.new()
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 10)
		card.add_child(margin)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)
		margin.add_child(hbox)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 4)
		hbox.add_child(info_vbox)

		var badge: String = "[연구 완료]" if is_done else ("[선행 연구 필요]" if not prereq_done else "[연구 가능]")
		var title_lbl := Label.new()
		title_lbl.add_theme_font_size_override("font_size", 16)
		title_lbl.text = "%s %s" % [badge, str(res.get("name", r_id))]
		if is_done:
			title_lbl.modulate = Color(0.58, 0.96, 0.68)
		elif not prereq_done:
			title_lbl.modulate = Color(0.68, 0.72, 0.78)
		else:
			title_lbl.modulate = Color(0.68, 0.90, 1.0)
		info_vbox.add_child(title_lbl)

		var unlock_parts: PackedStringArray = []
		for tid in res.get("unlock_tower_ids", []):
			var t_tpl: Dictionary = DataManager.get_tower(str(tid))
			unlock_parts.append("포탑:%s" % str(t_tpl.get("name", str(tid))))
		for eid in res.get("unlock_equip_ids", []):
			var eq_tpl: Dictionary = DataManager.get_equipment(str(eid))
			unlock_parts.append("장비:%s" % str(eq_tpl.get("name", str(eid))))
		var unlock_str: String = " | 해금 대상: %s" % ", ".join(unlock_parts) if not unlock_parts.is_empty() else ""
		var prereq_str: String = ""
		if not prereq_id.is_empty():
			var p_tpl: Dictionary = DataManager.get_research(prereq_id)
			prereq_str = " | 선행 연구: %s" % str(p_tpl.get("name", prereq_id))

		var desc_lbl := Label.new()
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.text = "%s%s%s" % [str(res.get("description", "")), unlock_str, prereq_str]
		info_vbox.add_child(desc_lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(220, 48)
		if is_done:
			btn.text = "연구 완료"
			btn.disabled = true
		elif not prereq_done:
			var p_tpl: Dictionary = DataManager.get_research(prereq_id)
			btn.text = "선행 연구 필요\n(%s)" % str(p_tpl.get("name", prereq_id))
			btn.disabled = true
		else:
			btn.text = "연구 진행\n(골드 %d, 자재 %d)" % [int(cost.get("gold", 0)), int(cost.get("materials", 0))]
			btn.disabled = not can_start
			btn.pressed.connect(_on_start_research_pressed.bind(r_id))
		hbox.add_child(btn)

		research_list_vbox.add_child(card)


func _on_start_research_pressed(research_id: String) -> void:
	var res: Dictionary = DataManager.get_research(research_id)
	if res.is_empty():
		return
	if GlobalData.is_research_completed(research_id):
		return
	var prereq: String = str(res.get("prerequisite_id", ""))
	if not prereq.is_empty() and not GlobalData.is_research_completed(prereq):
		_set_research_status("선행 연구를 먼저 완료해야 합니다.", false)
		return
	var cost: Dictionary = res.get("cost", {})
	if not GlobalData.spend_resources(cost):
		_set_research_status("자원이 부족해 연구를 시작할 수 없습니다.", false)
		return
	GlobalData.complete_research(research_id)
	_set_research_status("[%s] 연구 완료! 대장간에서 새 제작 항목이 해금되었습니다." % str(res.get("name", "")), true)


# ==========================================
# 파티 프리셋 (1~5번) 3x3 편성 & 출정 직전 파티 선택 팝업
# ==========================================
func _build_party_formation_ui() -> void:
	for child in preset_buttons_hbox.get_children():
		child.queue_free()
	_preset_tab_buttons.clear()
	for i in range(GlobalData.MAX_PARTY_PRESETS):
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 34)
		btn.add_theme_font_size_override("font_size", 12)
		btn.text = "%d번" % (i + 1)
		btn.pressed.connect(func() -> void: GlobalData.select_party_preset(i))
		preset_buttons_hbox.add_child(btn)
		_preset_tab_buttons.append(btn)

	for child in party_formation_grid.get_children():
		child.queue_free()
	_formation_slot_buttons.clear()
	# 좌→우: 후열(2) | 중열(1) | 전열(0) — OffenseScene 아군 그리드 방향과 일치
	for row in range(3):
		for rank in [2, 1, 0]:
			var slot_btn := Button.new()
			slot_btn.custom_minimum_size = Vector2(132, 118)
			slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
			slot_btn.add_theme_font_size_override("font_size", 13)
			slot_btn.clip_text = true
			slot_btn.tooltip_text = GlobalData.get_rank_bonus_summary(rank)
			slot_btn.pressed.connect(_on_formation_slot_pressed.bind(rank, row))
			party_formation_grid.add_child(slot_btn)
			_formation_slot_buttons["%d,%d" % [rank, row]] = slot_btn

	for child in deploy_preset_buttons_hbox.get_children():
		child.queue_free()
	_deploy_preset_buttons.clear()
	for i in range(GlobalData.MAX_PARTY_PRESETS):
		var dbtn := Button.new()
		dbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dbtn.custom_minimum_size = Vector2(0, 38)
		dbtn.add_theme_font_size_override("font_size", 13)
		dbtn.text = "%d번 파티" % (i + 1)
		dbtn.pressed.connect(func() -> void:
			GlobalData.select_party_preset(i)
			_refresh_dungeon_deploy_popup()
		)
		deploy_preset_buttons_hbox.add_child(dbtn)
		_deploy_preset_buttons.append(dbtn)


func _refresh_party_formation_ui() -> void:
	if _preset_tab_buttons.is_empty():
		return
	var cur_idx: int = GlobalData.selected_party_index
	for i in range(_preset_tab_buttons.size()):
		var btn: Button = _preset_tab_buttons[i]
		var entries: Array[Dictionary] = GlobalData.get_preset_slots_list(i)
		btn.text = "%d번(%d)" % [i + 1, entries.size()]
		btn.modulate = Color(0.55, 0.92, 1.0) if i == cur_idx else Color(0.82, 0.84, 0.88)

	var rank_labels := {0: "전열", 1: "중열", 2: "후열"}
	var total_count: int = 0
	var deployable_count: int = 0
	for row in range(3):
		for rank in [2, 1, 0]:
			var key: String = "%d,%d" % [rank, row]
			var sbtn: Button = _formation_slot_buttons.get(key)
			if sbtn == null:
				continue
			var hero: Dictionary = GlobalData.get_party_slot_hero(cur_idx, rank, row)
			if hero.is_empty():
				sbtn.text = "[%s]\n(빈 칸)" % rank_labels[rank]
				sbtn.modulate = Color(0.75, 0.78, 0.82)
			else:
				total_count += 1
				var can_go: bool = GlobalData.can_hero_deploy(hero)
				if can_go:
					deployable_count += 1
				var f_val: int = int(hero.get("fatigue", 0))
				var f_tag: String = "탈진" if GlobalData.is_hero_exhausted(hero) else ("사망" if int(hero.get("hp", 0)) <= 0 else "피로%d%%" % f_val)
				sbtn.text = "%s\n(%s · %s)" % [
					str(hero.get("name", "영웅")),
					str(hero.get("job_class", "")),
					f_tag,
				]
				if not can_go:
					sbtn.modulate = Color(1.0, 0.45, 0.45)
				elif GlobalData.is_hero_tired(hero):
					sbtn.modulate = Color(1.0, 0.78, 0.40)
				else:
					sbtn.modulate = Color(0.65, 0.95, 0.78)

	preset_status_label.text = "%d번 파티: %d/%d명 편성 (출정 가능 %d명)" % [cur_idx + 1, total_count, GlobalData.MAX_PARTY_SIZE, deployable_count]
	preset_status_label.modulate = Color(1.0, 0.72, 0.35) if deployable_count < total_count else Color(0.80, 0.92, 1.0)


func _on_formation_slot_pressed(rank: int, row: int) -> void:
	var cur_idx: int = GlobalData.selected_party_index
	var existing: Dictionary = GlobalData.get_party_slot_hero(cur_idx, rank, row)
	if not existing.is_empty() and int(existing.get("uid", -1)) == _selected_hero_uid:
		GlobalData.clear_party_slot(cur_idx, rank, row)
		preset_status_label.text = "%s을(를) 파티 슬롯에서 해제했습니다." % str(existing.get("name", "영웅"))
		return

	var selected_hero: Dictionary = GlobalData.get_hero_by_uid(_selected_hero_uid)
	if selected_hero.is_empty():
		if not existing.is_empty():
			GlobalData.clear_party_slot(cur_idx, rank, row)
			preset_status_label.text = "%s을(를) 슬롯에서 해제했습니다." % str(existing.get("name", "영웅"))
		return

	if not GlobalData.can_hero_deploy(selected_hero):
		var reason: String = "피로도 100 [탈진]" if GlobalData.is_hero_exhausted(selected_hero) else "HP 0 [전투불능]"
		preset_status_label.text = "편성 불가: %s은(는) %s 상태입니다! (휴식/치료 필요)" % [str(selected_hero.get("name", "")), reason]
		preset_status_label.modulate = Color(1.0, 0.42, 0.42)
		return

	var placed_ok: bool = GlobalData.set_party_slot(cur_idx, rank, row, _selected_hero_uid)
	if not placed_ok:
		preset_status_label.text = "편성 제한: 한 파티는 최대 %d명까지만 편성할 수 있습니다!" % GlobalData.MAX_PARTY_SIZE
		preset_status_label.modulate = Color(1.0, 0.42, 0.42)
	else:
		preset_status_label.text = "%s 배치 완료! (%s)" % [str(selected_hero.get("name", "")), GlobalData.get_rank_bonus_summary(rank)]
		preset_status_label.modulate = Color(0.65, 0.95, 0.78)


func _on_quick_formation_pressed() -> void:
	var cur_idx: int = GlobalData.selected_party_index
	var added: int = GlobalData.auto_fill_party_preset(cur_idx)
	if added > 0:
		preset_status_label.text = "%d번 파티 빠른 편성 완료! (%d명 자동 배치)" % [cur_idx + 1, added]
		preset_status_label.modulate = Color(0.55, 0.95, 0.65)
	else:
		preset_status_label.text = "추가로 편성할 출정 가능 영웅이 없거나 빈 칸이 없습니다."
		preset_status_label.modulate = Color(1.0, 0.78, 0.35)


func _on_clear_preset_pressed() -> void:
	var cur_idx: int = GlobalData.selected_party_index
	GlobalData.clear_party_preset(cur_idx)
	preset_status_label.text = "%d번 파티 편성을 비웠습니다." % (cur_idx + 1)


func _open_dungeon_deploy_popup() -> void:
	dungeon_deploy_overlay.visible = true
	_refresh_dungeon_deploy_popup()


func _close_dungeon_deploy_popup() -> void:
	dungeon_deploy_overlay.visible = false


func _refresh_dungeon_deploy_popup() -> void:
	var cur_idx: int = GlobalData.selected_party_index
	for i in range(_deploy_preset_buttons.size()):
		var b: Button = _deploy_preset_buttons[i]
		var dep_cnt: int = GlobalData.get_deployable_party_heroes(i).size()
		var tot_cnt: int = GlobalData.get_preset_slots_list(i).size()
		b.text = "%d번 파티 (%d/%d명)" % [i + 1, dep_cnt, tot_cnt]
		b.modulate = Color(0.55, 0.92, 1.0) if i == cur_idx else Color.WHITE

	for child in deploy_members_vbox.get_children():
		child.queue_free()

	var entries: Array[Dictionary] = GlobalData.get_preset_slots_list(cur_idx)
	var rank_labels := {0: "전열", 1: "중위", 2: "후열"}
	var deployable_cnt: int = 0

	if entries.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "현재 선택된 %d번 파티에 편성된 영웅이 없습니다.\n파티 편성 패널에서 영웅을 배치하거나 [빠른 편성]을 사용하세요." % (cur_idx + 1)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		deploy_members_vbox.add_child(empty_lbl)
	else:
		for entry in entries:
			var hero: Dictionary = entry["hero"]
			var rank: int = int(entry["rank"])
			var row: int = int(entry["row"])
			var hp: int = int(hero.get("hp", 0))
			var max_hp: int = maxi(1, roundi(GlobalData.get_effective_stat(hero, "max_hp")))
			var fatigue: int = int(hero.get("fatigue", 0))
			var f_state: String = GlobalData.get_hero_fatigue_state_label(hero)
			var can_go: bool = GlobalData.can_hero_deploy(hero)
			if can_go:
				deployable_cnt += 1

			var card := PanelContainer.new()
			var margin := MarginContainer.new()
			margin.add_theme_constant_override("margin_left", 10)
			margin.add_theme_constant_override("margin_right", 10)
			margin.add_theme_constant_override("margin_top", 6)
			margin.add_theme_constant_override("margin_bottom", 6)
			card.add_child(margin)

			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 12)
			margin.add_child(hb)

			var info_lbl := Label.new()
			info_lbl.custom_minimum_size = Vector2(210, 0)
			info_lbl.add_theme_font_size_override("font_size", 13)
			info_lbl.text = "[%s %d행] %s (%s)" % [rank_labels[rank], row + 1, str(hero.get("name", "")), str(hero.get("job_class", ""))]
			hb.add_child(info_lbl)

			var hp_bar := ProgressBar.new()
			hp_bar.custom_minimum_size = Vector2(120, 18)
			hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hp_bar.max_value = max_hp
			hp_bar.value = hp
			hp_bar.show_percentage = false
			hb.add_child(hp_bar)

			var hp_txt := Label.new()
			hp_txt.custom_minimum_size = Vector2(88, 0)
			hp_txt.add_theme_font_size_override("font_size", 12)
			hp_txt.text = "HP %d/%d" % [hp, max_hp]
			hb.add_child(hp_txt)

			var f_bar := ProgressBar.new()
			f_bar.custom_minimum_size = Vector2(110, 18)
			f_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			f_bar.max_value = GlobalData.MAX_FATIGUE
			f_bar.value = fatigue
			f_bar.show_percentage = false
			f_bar.modulate = Color(1.0, 0.35, 0.35) if GlobalData.is_hero_exhausted(hero) else (Color(1.0, 0.72, 0.30) if GlobalData.is_hero_tired(hero) else Color(0.45, 0.85, 1.0))
			hb.add_child(f_bar)

			var f_txt := Label.new()
			f_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			f_txt.add_theme_font_size_override("font_size", 12)
			if not can_go:
				f_txt.text = "피로 %d%% [%s·출정불가]" % [fatigue, "사망" if hp <= 0 else f_state]
				f_txt.modulate = Color(1.0, 0.42, 0.42)
			else:
				f_txt.text = "피로 %d%% [%s]" % [fatigue, f_state]
				if GlobalData.is_hero_tired(hero):
					f_txt.modulate = Color(1.0, 0.75, 0.35)
			hb.add_child(f_txt)

			deploy_members_vbox.add_child(card)

	if deployable_cnt <= 0:
		deploy_summary_label.text = "⚠ 출정 가능한 영웅이 없습니다! (탈진/사망 영웅 제외 0명) 다른 파티를 선택하거나 마을에서 휴식/편성하세요."
		deploy_summary_label.modulate = Color(1.0, 0.45, 0.45)
		deploy_confirm_button.disabled = true
	else:
		deploy_summary_label.text = "선택된 파티: %d번 파티 — 출정 가능 %d명 / 편성 %d명" % [cur_idx + 1, deployable_cnt, entries.size()]
		deploy_summary_label.modulate = Color(0.65, 0.95, 0.75)
		deploy_confirm_button.disabled = false


func _on_deploy_confirm_pressed() -> void:
	if GlobalData.get_deployable_party_heroes(GlobalData.selected_party_index).is_empty():
		return
	_close_dungeon_deploy_popup()
	ready_for_next_phase.emit()
	if GlobalData.current_phase == GlobalData.GamePhase.TOWN:
		TimeManager.advance_phase()
