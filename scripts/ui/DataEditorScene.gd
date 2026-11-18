extends Control
## 캐릭터(영웅), 정책 이벤트, 조립식 스킬 외부 JSON 편집기 씬 컨트롤러
## - DataManager와 연동하여 data/heroes/, data/events/, data/skills.json을 편집·저장·삭제합니다.

const RANK_OPTIONS: Array[String] = ["전열", "중위", "후열"]
const ZONE_OPTIONS: Array[String] = ["성벽위", "성벽밖"]

const SCOPE_LABELS: Dictionary = {
	"SINGLE_FRONT": "단일 전열(SINGLE_FRONT)",
	"SINGLE_BACK": "단일 후열(SINGLE_BACK)",
	"ROW": "가로/전열 전체(ROW)",
	"COLUMN": "세로 1열 전체(COLUMN)",
	"CROSS": "십자 광역(CROSS)",
	"SQUARE_2X2": "2x2 사각 광역(SQUARE_2X2)",
	"ALL_ENEMIES": "적 전체(ALL_ENEMIES)",
	"AOE_SMALL": "소형 광역 폭발(AOE_SMALL)",
	"AOE_LARGE": "대형 광역 폭격(AOE_LARGE)",
	"SELF": "자신(SELF)",
	"SINGLE_ALLY": "아군 단일(SINGLE_ALLY)",
	"ALL_ALLIES": "아군 전체(ALL_ALLIES)",
}

@onready var data_root_label: Label = %DataRootLabel
@onready var reload_all_button: Button = %ReloadAllButton

# --- 1. 영웅 편집기 UI ---
@onready var hero_list: ItemList = %HeroList
@onready var hero_file_label: Label = %HeroFileLabel
@onready var hero_name_edit: LineEdit = %HeroNameEdit
@onready var hero_rarity_option: OptionButton = %HeroRarityOption
@onready var hero_named_check: CheckButton = %HeroNamedCheck
@onready var hero_named_source_option: OptionButton = %HeroNamedSourceOption
@onready var hero_named_title_edit: LineEdit = %HeroNamedTitleEdit
@onready var hero_sig_equip_option: OptionButton = %HeroSigEquipOption
@onready var hero_lore_edit: LineEdit = %HeroLoreEdit
@onready var hero_category_option: OptionButton = %HeroCategoryOption
@onready var hero_job_option: OptionButton = %HeroJobOption
@onready var hero_element_color_rect: ColorRect = %HeroElementColorRect
@onready var hero_element_option: OptionButton = %HeroElementOption
@onready var hero_def_spin: SpinBox = %HeroDefSpin
@onready var hero_hp_spin: SpinBox = %HeroHpSpin
@onready var hero_atk_spin: SpinBox = %HeroAtkSpin
@onready var hero_speed_spin: SpinBox = %HeroSpeedSpin
@onready var hero_heal_spin: SpinBox = %HeroHealSpin
@onready var hero_dmg_bonus_spin: SpinBox = %HeroDmgBonusSpin
@onready var hero_crit_rate_spin: SpinBox = %HeroCritRateSpin
@onready var hero_crit_dmg_spin: SpinBox = %HeroCritDmgSpin
@onready var hero_armor_pen_spin: SpinBox = %HeroArmorPenSpin
@onready var hero_final_mult_spin: SpinBox = %HeroFinalMultSpin
@onready var hero_skill_option: OptionButton = %HeroSkillOption
@onready var hero_skill2_option: OptionButton = %HeroSkill2Option
@onready var hero_ultimate_option: OptionButton = %HeroUltimateOption
@onready var hero_rank_option: OptionButton = %HeroRankOption
@onready var hero_zone_option: OptionButton = %HeroZoneOption
@onready var hero_skill_edit: TextEdit = %HeroSkillEdit
@onready var hero_status_label: Label = %HeroStatusLabel
@onready var hero_new_button: Button = %HeroNewButton
@onready var hero_save_button: Button = %HeroSaveButton
@onready var hero_delete_button: Button = %HeroDeleteButton

# --- 2. 정책 이벤트 편집기 UI ---
@onready var event_list: ItemList = %EventList
@onready var event_file_label: Label = %EventFileLabel
@onready var event_title_edit: LineEdit = %EventTitleEdit
@onready var event_category_option: OptionButton = %EventCategoryOption
@onready var event_min_stage_option: OptionButton = %EventMinStageOption
@onready var event_max_stage_option: OptionButton = %EventMaxStageOption
@onready var event_desc_edit: TextEdit = %EventDescEdit
@onready var opt_a_text_edit: LineEdit = %OptATextEdit
@onready var opt_a_food_spin: SpinBox = %OptAFoodSpin
@onready var opt_a_mat_spin: SpinBox = %OptAMatSpin
@onready var opt_a_morale_spin: SpinBox = %OptAMoraleSpin
@onready var opt_a_gold_spin: SpinBox = %OptAGoldSpin
@onready var opt_a_unrest_spin: SpinBox = %OptAUnrestSpin
@onready var opt_a_hero_option: OptionButton = %OptAHeroOption
@onready var opt_a_equip_option: OptionButton = %OptAEquipOption
@onready var opt_a_item_option: OptionButton = %OptAItemOption
@onready var opt_b_text_edit: LineEdit = %OptBTextEdit
@onready var opt_b_food_spin: SpinBox = %OptBFoodSpin
@onready var opt_b_mat_spin: SpinBox = %OptBMatSpin
@onready var opt_b_morale_spin: SpinBox = %OptBMoraleSpin
@onready var opt_b_gold_spin: SpinBox = %OptBGoldSpin
@onready var opt_b_unrest_spin: SpinBox = %OptBUnrestSpin
@onready var opt_b_hero_option: OptionButton = %OptBHeroOption
@onready var opt_b_equip_option: OptionButton = %OptBEquipOption
@onready var opt_b_item_option: OptionButton = %OptBItemOption
@onready var event_status_label: Label = %EventStatusLabel
@onready var event_new_button: Button = %EventNewButton
@onready var event_save_button: Button = %EventSaveButton
@onready var event_delete_button: Button = %EventDeleteButton

# --- 3. 스킬 편집기 UI ---
@onready var skill_list: ItemList = %SkillList
@onready var skill_id_label: Label = %SkillIdLabel
@onready var skill_name_edit: LineEdit = %SkillNameEdit
@onready var skill_cooldown_spin: SpinBox = %SkillCooldownSpin
@onready var skill_desc_edit: TextEdit = %SkillDescEdit
@onready var skill_effect_list: ItemList = %SkillEffectList
@onready var effect_type_option: OptionButton = %EffectTypeOption
@onready var effect_scope_option: OptionButton = %EffectScopeOption
@onready var effect_mult_spin: SpinBox = %EffectMultSpin
@onready var effect_duration_spin: SpinBox = %EffectDurationSpin
@onready var effect_bonus_crit_spin: SpinBox = %EffectBonusCritSpin
@onready var effect_bonus_pen_spin: SpinBox = %EffectBonusPenSpin
@onready var effect_add_button: Button = %EffectAddButton
@onready var effect_update_button: Button = %EffectUpdateButton
@onready var effect_remove_button: Button = %EffectRemoveButton
@onready var skill_status_label: Label = %SkillStatusLabel
@onready var skill_new_button: Button = %SkillNewButton
@onready var skill_save_button: Button = %SkillSaveButton
@onready var skill_delete_button: Button = %SkillDeleteButton

# --- 4. 장비 편집기 UI ---
@onready var equip_list: ItemList = %EquipList
@onready var equip_id_label: Label = %EquipIdLabel
@onready var equip_name_edit: LineEdit = %EquipNameEdit
@onready var equip_rarity_option: OptionButton = %EquipRarityOption
@onready var equip_slot_option: OptionButton = %EquipSlotOption
@onready var equip_classes_edit: LineEdit = %EquipClassesEdit
@onready var equip_exclusive_option: OptionButton = %EquipExclusiveOption
@onready var equip_passive_option: OptionButton = %EquipPassiveOption
@onready var equip_resonance_option: OptionButton = %EquipResonanceOption
@onready var equip_named_check: CheckButton = %EquipNamedCheck
@onready var equip_craftable_check: CheckButton = %EquipCraftableCheck
@onready var equip_named_title_edit: LineEdit = %EquipNamedTitleEdit
@onready var equip_hp_spin: SpinBox = %EquipHpSpin
@onready var equip_atk_spin: SpinBox = %EquipAtkSpin
@onready var equip_def_spin: SpinBox = %EquipDefSpin
@onready var equip_speed_spin: SpinBox = %EquipSpeedSpin
@onready var equip_dmg_bonus_spin: SpinBox = %EquipDmgBonusSpin
@onready var equip_crit_rate_spin: SpinBox = %EquipCritRateSpin
@onready var equip_crit_dmg_spin: SpinBox = %EquipCritDmgSpin
@onready var equip_armor_pen_spin: SpinBox = %EquipArmorPenSpin
@onready var equip_final_mult_spin: SpinBox = %EquipFinalMultSpin
@onready var equip_desc_edit: TextEdit = %EquipDescEdit
@onready var equip_status_label: Label = %EquipStatusLabel
@onready var equip_new_button: Button = %EquipNewButton
@onready var equip_save_button: Button = %EquipSaveButton
@onready var equip_delete_button: Button = %EquipDeleteButton

# --- 5. 직군·피로도 설정 UI ---
@onready var class_list: ItemList = %ClassList
@onready var class_id_label: Label = %ClassIdLabel
@onready var class_name_label: Label = %ClassNameLabel
@onready var class_move_fatigue_spin: SpinBox = %ClassMoveFatigueSpin
@onready var class_battle_fatigue_spin: SpinBox = %ClassBattleFatigueSpin
@onready var class_desc_edit: TextEdit = %ClassDescEdit
@onready var class_status_label: Label = %ClassStatusLabel
@onready var class_save_button: Button = %ClassSaveButton

# --- 6. 던전 이벤트(?) 편집기 UI ---
@onready var dungeon_event_list: ItemList = %DungeonEventList
@onready var dun_ev_id_label: Label = %DunEvIdLabel
@onready var dun_ev_title_edit: LineEdit = %DunEvTitleEdit
@onready var dun_ev_desc_edit: TextEdit = %DunEvDescEdit
@onready var dun_ev_choice_list: ItemList = %DunEvChoiceList
@onready var dun_ev_choice_label_edit: LineEdit = %DunEvChoiceLabelEdit
@onready var dun_ev_choice_result_edit: LineEdit = %DunEvChoiceResultEdit
@onready var dun_ev_cost_gold_spin: SpinBox = %DunEvCostGoldSpin
@onready var dun_ev_cost_food_spin: SpinBox = %DunEvCostFoodSpin
@onready var dun_ev_cost_mat_spin: SpinBox = %DunEvCostMatSpin
@onready var dun_ev_reward_gold_spin: SpinBox = %DunEvRewardGoldSpin
@onready var dun_ev_reward_food_spin: SpinBox = %DunEvRewardFoodSpin
@onready var dun_ev_reward_mat_spin: SpinBox = %DunEvRewardMatSpin
@onready var dun_ev_reward_morale_spin: SpinBox = %DunEvRewardMoraleSpin
@onready var dun_ev_reward_wall_hp_spin: SpinBox = %DunEvRewardWallHpSpin
@onready var dun_ev_reward_wall_atk_spin: SpinBox = %DunEvRewardWallAtkSpin
@onready var dun_ev_fatigue_delta_spin: SpinBox = %DunEvFatigueDeltaSpin
@onready var dun_ev_drop_equip_check: CheckButton = %DunEvDropEquipCheck
@onready var dun_ev_choice_add_button: Button = %DunEvChoiceAddButton
@onready var dun_ev_choice_update_button: Button = %DunEvChoiceUpdateButton
@onready var dun_ev_choice_remove_button: Button = %DunEvChoiceRemoveButton
@onready var dun_ev_status_label: Label = %DunEvStatusLabel
@onready var dun_ev_new_button: Button = %DunEvNewButton
@onready var dun_ev_save_button: Button = %DunEvSaveButton
@onready var dun_ev_delete_button: Button = %DunEvDeleteButton

# --- 7. 던전·드랍 테이블 편집기 UI ---
@onready var dungeon_list: ItemList = %DungeonList
@onready var dungeon_id_label: Label = %DungeonIdLabel
@onready var dungeon_name_edit: LineEdit = %DungeonNameEdit
@onready var dungeon_type_option: OptionButton = %DungeonTypeOption
@onready var dungeon_width_spin: SpinBox = %DungeonWidthSpin
@onready var dungeon_height_spin: SpinBox = %DungeonHeightSpin
@onready var dungeon_depth_spin: SpinBox = %DungeonDepthSpin
@onready var dungeon_desc_edit: TextEdit = %DungeonDescEdit
@onready var dungeon_drop_checks_vbox: VBoxContainer = %DungeonDropChecksVBox
@onready var dungeon_status_label: Label = %DungeonStatusLabel
@onready var dungeon_new_button: Button = %DungeonNewButton
@onready var dungeon_save_button: Button = %DungeonSaveButton
@onready var dungeon_delete_button: Button = %DungeonDeleteButton

# --- 8. 적 유닛 편집기 UI ---
@onready var enemy_list: ItemList = %EnemyList
@onready var enemy_id_label: Label = %EnemyIdLabel
@onready var enemy_name_edit: LineEdit = %EnemyNameEdit
@onready var enemy_element_option: OptionButton = %EnemyElementOption
@onready var enemy_type_option: OptionButton = %EnemyTypeOption
@onready var enemy_hp_spin: SpinBox = %EnemyHpSpin
@onready var enemy_atk_spin: SpinBox = %EnemyAtkSpin
@onready var enemy_def_spin: SpinBox = %EnemyDefSpin
@onready var enemy_spd_spin: SpinBox = %EnemySpdSpin
@onready var enemy_seasons_edit: LineEdit = %EnemySeasonsEdit
@onready var enemy_desc_edit: TextEdit = %EnemyDescEdit
@onready var enemy_passive_checks_vbox: VBoxContainer = %EnemyPassiveChecksVBox
@onready var enemy_active_checks_vbox: VBoxContainer = %EnemyActiveChecksVBox
@onready var enemy_status_label: Label = %EnemyStatusLabel
@onready var enemy_new_button: Button = %EnemyNewButton
@onready var enemy_save_button: Button = %EnemySaveButton
@onready var enemy_delete_button: Button = %EnemyDeleteButton

# --- 9. 커스텀 타워 편집기 UI ---
@onready var tower_list: ItemList = %TowerList
@onready var tower_id_label: Label = %TowerIdLabel
@onready var tower_name_edit: LineEdit = %TowerNameEdit
@onready var tower_element_option: OptionButton = %TowerElementOption
@onready var tower_scope_option: OptionButton = %TowerScopeOption
@onready var tower_atk_spin: SpinBox = %TowerAtkSpin
@onready var tower_interval_spin: SpinBox = %TowerIntervalSpin
@onready var tower_on_hit_option: OptionButton = %TowerOnHitOption
@onready var tower_cost_mat_spin: SpinBox = %TowerCostMatSpin
@onready var tower_cost_gold_spin: SpinBox = %TowerCostGoldSpin
@onready var tower_desc_edit: TextEdit = %TowerDescEdit
@onready var tower_status_label: Label = %TowerStatusLabel
@onready var tower_new_button: Button = %TowerNewButton
@onready var tower_save_button: Button = %TowerSaveButton
@onready var tower_delete_button: Button = %TowerDeleteButton

# --- 10. 소비 아이템 편집기 UI ---
@onready var item_list: ItemList = %ItemList
@onready var item_id_label: Label = %ItemIdLabel
@onready var item_name_edit: LineEdit = %ItemNameEdit
@onready var item_rarity_option: OptionButton = %ItemRarityOption
@onready var item_type_option: OptionButton = %ItemTypeOption
@onready var item_scope_option: OptionButton = %ItemScopeOption
@onready var item_power_spin: SpinBox = %ItemPowerSpin
@onready var item_duration_spin: SpinBox = %ItemDurationSpin
@onready var item_cost_gold_spin: SpinBox = %ItemCostGoldSpin
@onready var item_combat_check: CheckButton = %ItemCombatCheck
@onready var item_dungeon_check: CheckButton = %ItemDungeonCheck
@onready var item_desc_edit: TextEdit = %ItemDescEdit
@onready var item_status_label: Label = %ItemStatusLabel
@onready var item_new_button: Button = %ItemNewButton
@onready var item_save_button: Button = %ItemSaveButton
@onready var item_delete_button: Button = %ItemDeleteButton

var _selected_hero_path: String = ""
var _selected_event_path: String = ""
var _selected_skill_id: String = ""
var _selected_equip_id: String = ""
var _selected_class_id: String = ""
var _selected_dun_ev_id: String = ""
var _selected_dungeon_id: String = ""
var _selected_enemy_id: String = ""
var _selected_tower_id: String = ""
var _selected_item_id: String = ""
var _editing_effects: Array[Dictionary] = []
var _selected_effect_idx: int = -1
var _editing_dun_choices: Array[Dictionary] = []
var _selected_dun_choice_idx: int = -1
var _dungeon_drop_checkboxes: Dictionary = {} # eq_id -> CheckBox
var _enemy_passive_checkboxes: Dictionary = {} # skill_id -> CheckBox
var _enemy_active_checkboxes: Dictionary = {} # skill_id -> CheckBox

var hero_class_group_option: OptionButton = null
var hero_lock_temp_check: CheckBox = null
var _hero_fixed_temp_checks: Dictionary = {} # temp_id -> CheckBox
var enemy_category_option: OptionButton = null
var enemy_archetype_option: OptionButton = null
var enemy_palette_swap_button: Button = null


func _ready() -> void:
	_build_dynamic_hierarchy_and_enemy_controls()
	_setup_option_buttons()

	reload_all_button.pressed.connect(_on_reload_all_pressed)
	DataManager.data_reloaded.connect(_on_data_reloaded)

	hero_list.item_selected.connect(_on_hero_selected)
	hero_rarity_option.item_selected.connect(_on_hero_rarity_changed)
	hero_category_option.item_selected.connect(_on_hero_category_changed)
	hero_element_option.item_selected.connect(_on_hero_element_changed)
	hero_named_check.pressed.connect(_on_hero_named_pressed)
	hero_named_source_option.item_selected.connect(_on_hero_named_source_changed)
	hero_new_button.pressed.connect(_on_hero_new_pressed)
	hero_save_button.pressed.connect(_on_hero_save_pressed)
	hero_delete_button.pressed.connect(_on_hero_delete_pressed)

	event_list.item_selected.connect(_on_event_selected)
	event_new_button.pressed.connect(_on_event_new_pressed)
	event_save_button.pressed.connect(_on_event_save_pressed)
	event_delete_button.pressed.connect(_on_event_delete_pressed)

	skill_list.item_selected.connect(_on_skill_selected)
	skill_effect_list.item_selected.connect(_on_skill_effect_selected)
	effect_add_button.pressed.connect(_on_effect_add_pressed)
	effect_update_button.pressed.connect(_on_effect_update_pressed)
	effect_remove_button.pressed.connect(_on_effect_remove_pressed)
	skill_new_button.pressed.connect(_on_skill_new_pressed)
	skill_save_button.pressed.connect(_on_skill_save_pressed)
	skill_delete_button.pressed.connect(_on_skill_delete_pressed)

	equip_list.item_selected.connect(_on_equip_selected)
	equip_named_check.pressed.connect(_on_equip_named_pressed)
	equip_new_button.pressed.connect(_on_equip_new_pressed)
	equip_save_button.pressed.connect(_on_equip_save_pressed)
	equip_delete_button.pressed.connect(_on_equip_delete_pressed)

	class_list.item_selected.connect(_on_class_selected)
	class_save_button.pressed.connect(_on_class_save_pressed)

	dungeon_event_list.item_selected.connect(_on_dun_ev_selected)
	dun_ev_choice_list.item_selected.connect(_on_dun_choice_selected)
	dun_ev_choice_add_button.pressed.connect(_on_dun_choice_add_pressed)
	dun_ev_choice_update_button.pressed.connect(_on_dun_choice_update_pressed)
	dun_ev_choice_remove_button.pressed.connect(_on_dun_choice_remove_pressed)
	dun_ev_new_button.pressed.connect(_on_dun_ev_new_pressed)
	dun_ev_save_button.pressed.connect(_on_dun_ev_save_pressed)
	dun_ev_delete_button.pressed.connect(_on_dun_ev_delete_pressed)

	dungeon_list.item_selected.connect(_on_dungeon_selected)
	dungeon_new_button.pressed.connect(_on_dungeon_new_pressed)
	dungeon_save_button.pressed.connect(_on_dungeon_save_pressed)
	dungeon_delete_button.pressed.connect(_on_dungeon_delete_pressed)

	enemy_list.item_selected.connect(_on_enemy_selected)
	enemy_new_button.pressed.connect(_on_enemy_new_pressed)
	enemy_save_button.pressed.connect(_on_enemy_save_pressed)
	enemy_delete_button.pressed.connect(_on_enemy_delete_pressed)

	tower_list.item_selected.connect(_on_tower_selected)
	tower_new_button.pressed.connect(_on_tower_new_pressed)
	tower_save_button.pressed.connect(_on_tower_save_pressed)
	tower_delete_button.pressed.connect(_on_tower_delete_pressed)

	item_list.item_selected.connect(_on_item_selected)
	item_new_button.pressed.connect(_on_item_new_pressed)
	item_save_button.pressed.connect(_on_item_save_pressed)
	item_delete_button.pressed.connect(_on_item_delete_pressed)

	data_root_label.text = "모딩 데이터 경로: %s" % DataManager.get_data_root_path()
	_refresh_lists()
	_clear_hero_form()
	_clear_event_form()
	_clear_skill_form()
	_clear_equip_form()
	_clear_class_form()
	_clear_dun_ev_form()
	_clear_dungeon_form()
	_clear_enemy_form()
	_clear_tower_form()
	_clear_item_form()


func _setup_option_buttons() -> void:
	hero_rarity_option.clear()
	for r in DataManager.RARITIES:
		hero_rarity_option.add_item(r)

	hero_named_source_option.clear()
	for i in range(DataManager.NAMED_SOURCES.size()):
		var src_id: String = DataManager.NAMED_SOURCES[i]
		hero_named_source_option.add_item(DataManager.get_named_source_label(src_id))
		hero_named_source_option.set_item_metadata(i, src_id)

	hero_category_option.clear()
	for cat in DataManager.ROLE_CATEGORIES:
		hero_category_option.add_item(cat)
	_populate_job_options(DataManager.ROLE_CATEGORIES[0])

	_populate_element_options()
	_populate_hero_skill_options()

	hero_rank_option.clear()
	for r in RANK_OPTIONS:
		hero_rank_option.add_item(r)

	hero_zone_option.clear()
	for z in ZONE_OPTIONS:
		hero_zone_option.add_item(z)

	effect_type_option.clear()
	for i in range(DataManager.EFFECT_TYPES.size()):
		var eid: String = DataManager.EFFECT_TYPES[i]
		effect_type_option.add_item("%s (%s)" % [StatusEffectManager.get_effect_label(eid), eid])
		effect_type_option.set_item_metadata(i, eid)

	effect_scope_option.clear()
	for i in range(DataManager.TARGET_SCOPES.size()):
		var sid: String = DataManager.TARGET_SCOPES[i]
		effect_scope_option.add_item(SCOPE_LABELS.get(sid, sid))
		effect_scope_option.set_item_metadata(i, sid)

	equip_rarity_option.clear()
	for r in DataManager.RARITIES:
		equip_rarity_option.add_item(r)

	equip_slot_option.clear()
	for i in range(DataManager.SLOT_TYPES.size()):
		var st: String = DataManager.SLOT_TYPES[i]
		equip_slot_option.add_item("%s (%s)" % [DataManager.get_slot_label(st), st])
		equip_slot_option.set_item_metadata(i, st)

	dungeon_type_option.clear()
	var d_type_labels := {"FIELD_GRID": "대형 외곽 그리드 (FIELD_GRID)", "MINI_ROGUE": "분기형 미니 던전 (MINI_ROGUE)"}
	for i in range(DataManager.DUNGEON_TYPES.size()):
		var dt: String = DataManager.DUNGEON_TYPES[i]
		dungeon_type_option.add_item(str(d_type_labels.get(dt, dt)))
		dungeon_type_option.set_item_metadata(i, dt)

	enemy_type_option.clear()
	for et in DataManager.ENEMY_TYPES:
		enemy_type_option.add_item(et)

	if enemy_category_option != null:
		enemy_category_option.clear()
		for i in range(DataManager.ENEMY_CATEGORIES.size()):
			var cat_id: String = DataManager.ENEMY_CATEGORIES[i]
			enemy_category_option.add_item(str(DataManager.ENEMY_CATEGORY_LABELS.get(cat_id, cat_id)))
			enemy_category_option.set_item_metadata(i, cat_id)
		_populate_enemy_archetype_options(DataManager.ENEMY_CATEGORIES[0])

	tower_scope_option.clear()
	for i in range(DataManager.TOWER_SCOPES.size()):
		var ts: String = DataManager.TOWER_SCOPES[i]
		tower_scope_option.add_item(SCOPE_LABELS.get(ts, ts))
		tower_scope_option.set_item_metadata(i, ts)

	item_rarity_option.clear()
	for r in DataManager.RARITIES:
		item_rarity_option.add_item(r)

	item_type_option.clear()
	for i in range(DataManager.ITEM_TYPES.size()):
		var it: String = DataManager.ITEM_TYPES[i]
		item_type_option.add_item(DataManager.get_item_type_label(it))
		item_type_option.set_item_metadata(i, it)

	item_scope_option.clear()
	for i in range(DataManager.ITEM_SCOPES.size()):
		var sc: String = DataManager.ITEM_SCOPES[i]
		item_scope_option.add_item(SCOPE_LABELS.get(sc, sc))
		item_scope_option.set_item_metadata(i, sc)

	event_category_option.clear()
	for i in range(DataManager.EVENT_CATEGORIES.size()):
		var cid: String = DataManager.EVENT_CATEGORIES[i]
		event_category_option.add_item(DataManager.EVENT_CATEGORY_LABELS.get(cid, cid))
		event_category_option.set_item_metadata(i, cid)

	event_min_stage_option.clear()
	event_max_stage_option.clear()
	for s in range(1, 7):
		var lbl: String = TimeManager.get_event_stage_label(s)
		event_min_stage_option.add_item(lbl)
		event_min_stage_option.set_item_metadata(s - 1, s)
		event_max_stage_option.add_item(lbl)
		event_max_stage_option.set_item_metadata(s - 1, s)

	_populate_element_dropdown(enemy_element_option, "")
	_populate_element_dropdown(tower_element_option, "")
	_populate_skill_dropdown(tower_on_hit_option, "")
	_populate_equip_reference_options()
	_populate_event_reward_options()


func _populate_event_reward_options(
	sel_a_hero: String = "",
	sel_a_equip: String = "",
	sel_a_item: String = "",
	sel_b_hero: String = "",
	sel_b_equip: String = "",
	sel_b_item: String = ""
) -> void:
	_populate_hero_dropdown(opt_a_hero_option, sel_a_hero)
	_populate_hero_dropdown(opt_b_hero_option, sel_b_hero)
	_populate_equip_dropdown(opt_a_equip_option, sel_a_equip)
	_populate_equip_dropdown(opt_b_equip_option, sel_b_equip)
	_populate_item_dropdown(opt_a_item_option, sel_a_item)
	_populate_item_dropdown(opt_b_item_option, sel_b_item)


func _populate_hero_dropdown(opt_btn: OptionButton, select_hero_id: String = "") -> void:
	opt_btn.clear()
	opt_btn.add_item("(없음)")
	opt_btn.set_item_metadata(0, "")
	var sel: int = 0
	for i in range(DataManager.heroes.size()):
		var h: Dictionary = DataManager.heroes[i]
		var hid: String = str(h.get("id", ""))
		var idx: int = i + 1
		var tag: String = "★" if bool(h.get("is_named", false)) else ""
		opt_btn.add_item("%s[%s] %s (%s)" % [tag, DataManager.normalize_rarity(h.get("rarity", "N")), str(h.get("name", hid)), hid])
		opt_btn.set_item_metadata(idx, hid)
		if not select_hero_id.is_empty() and hid == select_hero_id:
			sel = idx
	opt_btn.select(sel)


func _populate_equip_dropdown(opt_btn: OptionButton, select_equip_id: String = "") -> void:
	opt_btn.clear()
	opt_btn.add_item("(없음)")
	opt_btn.set_item_metadata(0, "")
	var sel: int = 0
	for i in range(DataManager.equipments.size()):
		var eq: Dictionary = DataManager.equipments[i]
		var eid: String = str(eq.get("id", ""))
		var idx: int = i + 1
		var tag: String = "★" if bool(eq.get("is_named", false)) else ""
		opt_btn.add_item("%s[%s] %s (%s)" % [tag, DataManager.normalize_rarity(eq.get("rarity", "N")), str(eq.get("name", eid)), eid])
		opt_btn.set_item_metadata(idx, eid)
		if not select_equip_id.is_empty() and eid == select_equip_id:
			sel = idx
	opt_btn.select(sel)


func _populate_item_dropdown(opt_btn: OptionButton, select_item_id: String = "") -> void:
	opt_btn.clear()
	opt_btn.add_item("(없음)")
	opt_btn.set_item_metadata(0, "")
	var sel: int = 0
	for i in range(DataManager.items.size()):
		var it: Dictionary = DataManager.items[i]
		var iid: String = str(it.get("id", ""))
		var idx: int = i + 1
		opt_btn.add_item("[%s] %s (%s)" % [DataManager.normalize_rarity(it.get("rarity", "N")), str(it.get("name", iid)), iid])
		opt_btn.set_item_metadata(idx, iid)
		if not select_item_id.is_empty() and iid == select_item_id:
			sel = idx
	opt_btn.select(sel)


func _populate_element_options(select_element_id: String = "") -> void:
	var target_id: String = select_element_id
	if target_id.is_empty() and hero_element_option.item_count > 0 and hero_element_option.selected >= 0:
		target_id = str(hero_element_option.get_item_metadata(hero_element_option.selected))

	hero_element_option.clear()
	var selected_idx: int = 0
	for i in range(DataManager.elements.size()):
		var elem: Dictionary = DataManager.elements[i]
		var e_id: String = str(elem["id"])
		var e_name: String = str(elem["name"])
		hero_element_option.add_item("%s (%s)" % [e_name, e_id])
		hero_element_option.set_item_metadata(i, e_id)
		if not target_id.is_empty() and e_id == target_id:
			selected_idx = i

	if hero_element_option.item_count > 0:
		hero_element_option.select(selected_idx)
		_update_element_color_preview()
	else:
		hero_element_color_rect.color = Color.WHITE


func _populate_skill_dropdown(option_btn: OptionButton, select_skill_id: String = "") -> void:
	var target_id: String = select_skill_id
	if target_id.is_empty() and option_btn.item_count > 0 and option_btn.selected >= 0:
		target_id = str(option_btn.get_item_metadata(option_btn.selected))

	option_btn.clear()
	option_btn.add_item("(없음)")
	option_btn.set_item_metadata(0, "")
	var selected_idx: int = 0
	for i in range(DataManager.skills.size()):
		var s: Dictionary = DataManager.skills[i]
		var s_id: String = str(s["id"])
		var idx: int = i + 1
		option_btn.add_item("%s (%s)" % [s["name"], s_id])
		option_btn.set_item_metadata(idx, s_id)
		if not target_id.is_empty() and s_id == target_id:
			selected_idx = idx
	option_btn.select(selected_idx)


func _populate_hero_skill_options(select_skill1: String = "", select_skill2: String = "", select_ult: String = "") -> void:
	_populate_skill_dropdown(hero_skill_option, select_skill1)
	_populate_skill_dropdown(hero_skill2_option, select_skill2)
	_populate_skill_dropdown(hero_ultimate_option, select_ult)
	_update_skill_slots_by_rarity()


func _populate_hero_sig_equip_options(select_eq_id: String = "") -> void:
	var target_id: String = select_eq_id
	if target_id.is_empty() and hero_sig_equip_option.item_count > 0 and hero_sig_equip_option.selected >= 0:
		target_id = str(hero_sig_equip_option.get_item_metadata(hero_sig_equip_option.selected))

	hero_sig_equip_option.clear()
	hero_sig_equip_option.add_item("(없음)")
	hero_sig_equip_option.set_item_metadata(0, "")
	var sel: int = 0
	for i in range(DataManager.equipments.size()):
		var eq: Dictionary = DataManager.equipments[i]
		var eid: String = str(eq.get("id", ""))
		var idx: int = i + 1
		hero_sig_equip_option.add_item("%s (%s)" % [str(eq.get("name", eid)), eid])
		hero_sig_equip_option.set_item_metadata(idx, eid)
		if not target_id.is_empty() and eid == target_id:
			sel = idx
	hero_sig_equip_option.select(sel)


func _populate_equip_reference_options(select_hero_id: String = "", select_passive_id: String = "", select_res_id: String = "") -> void:
	var target_hero: String = select_hero_id
	if target_hero.is_empty() and equip_exclusive_option.item_count > 0 and equip_exclusive_option.selected >= 0:
		target_hero = str(equip_exclusive_option.get_item_metadata(equip_exclusive_option.selected))

	equip_exclusive_option.clear()
	equip_exclusive_option.add_item("(없음 - 일반 공용/직업 장비)")
	equip_exclusive_option.set_item_metadata(0, "")
	var sel_h: int = 0
	for i in range(DataManager.heroes.size()):
		var h: Dictionary = DataManager.heroes[i]
		var hid: String = str(h.get("id", ""))
		var idx: int = i + 1
		equip_exclusive_option.add_item("%s (%s)" % [str(h.get("name", hid)), hid])
		equip_exclusive_option.set_item_metadata(idx, hid)
		if not target_hero.is_empty() and hid == target_hero:
			sel_h = idx
	equip_exclusive_option.select(sel_h)

	_populate_skill_dropdown(equip_passive_option, select_passive_id)
	_populate_skill_dropdown(equip_resonance_option, select_res_id)


func _on_hero_rarity_changed(_index: int) -> void:
	_update_skill_slots_by_rarity()


func _get_selected_rarity() -> String:
	if hero_rarity_option.item_count == 0 or hero_rarity_option.selected < 0:
		return "N"
	return str(hero_rarity_option.get_item_text(hero_rarity_option.selected))


func _update_skill_slots_by_rarity() -> void:
	var rules: Dictionary = DataManager.get_skill_slot_rules(_get_selected_rarity())
	hero_skill_option.disabled = not bool(rules["active1"])
	hero_skill2_option.disabled = not bool(rules["active2"])
	hero_ultimate_option.disabled = not bool(rules["ultimate"])


func _on_hero_element_changed(_index: int) -> void:
	_update_element_color_preview()


func _update_element_color_preview() -> void:
	hero_element_color_rect.color = DataManager.get_element_color(_get_selected_element_id())


func _on_hero_named_pressed() -> void:
	if hero_named_check.button_pressed:
		if hero_named_source_option.selected <= 0:
			hero_named_source_option.select(2)
		if hero_lock_temp_check != null:
			hero_lock_temp_check.button_pressed = true
	else:
		hero_named_source_option.select(0)


func _on_hero_named_source_changed(index: int) -> void:
	hero_named_check.button_pressed = (index > 0)


func _on_equip_named_pressed() -> void:
	equip_craftable_check.button_pressed = not equip_named_check.button_pressed


func _get_selected_element_id() -> String:
	if hero_element_option.item_count == 0 or hero_element_option.selected < 0:
		return "FIRE"
	return str(hero_element_option.get_item_metadata(hero_element_option.selected))


func _get_selected_dropdown_skill_id(option_btn: OptionButton) -> String:
	if option_btn.item_count == 0 or option_btn.selected < 0:
		return ""
	return str(option_btn.get_item_metadata(option_btn.selected))


func _populate_element_dropdown(opt: OptionButton, select_element_id: String = "") -> void:
	var target_id: String = select_element_id
	if target_id.is_empty() and opt.item_count > 0 and opt.selected >= 0:
		target_id = str(opt.get_item_metadata(opt.selected))
	opt.clear()
	var sel: int = 0
	for i in range(DataManager.elements.size()):
		var elem: Dictionary = DataManager.elements[i]
		var eid: String = str(elem["id"])
		opt.add_item("%s (%s)" % [str(elem["name"]), eid])
		opt.set_item_metadata(i, eid)
		if not target_id.is_empty() and eid == target_id:
			sel = i
	if opt.item_count > 0:
		opt.select(sel)


func _on_data_reloaded() -> void:
	_populate_element_options(_get_selected_element_id())
	_populate_element_dropdown(enemy_element_option, _get_selected_dropdown_skill_id(enemy_element_option))
	_populate_element_dropdown(tower_element_option, _get_selected_dropdown_skill_id(tower_element_option))
	_populate_skill_dropdown(tower_on_hit_option, _get_selected_dropdown_skill_id(tower_on_hit_option))
	_populate_hero_skill_options(
		_get_selected_dropdown_skill_id(hero_skill_option),
		_get_selected_dropdown_skill_id(hero_skill2_option),
		_get_selected_dropdown_skill_id(hero_ultimate_option)
	)
	_populate_hero_sig_equip_options(_get_selected_dropdown_skill_id(hero_sig_equip_option))
	_populate_equip_reference_options(
		_get_selected_dropdown_skill_id(equip_exclusive_option),
		_get_selected_dropdown_skill_id(equip_passive_option),
		_get_selected_dropdown_skill_id(equip_resonance_option)
	)
	_populate_event_reward_options(
		_get_selected_dropdown_skill_id(opt_a_hero_option),
		_get_selected_dropdown_skill_id(opt_a_equip_option),
		_get_selected_dropdown_skill_id(opt_a_item_option),
		_get_selected_dropdown_skill_id(opt_b_hero_option),
		_get_selected_dropdown_skill_id(opt_b_equip_option),
		_get_selected_dropdown_skill_id(opt_b_item_option)
	)
	_refresh_lists()


func _build_dynamic_hierarchy_and_enemy_controls() -> void:
	# 영웅 편집기: 8대 병과 OptionButton 동적 추가 (2열 GridContainer 정렬 유지)
	var job_parent := hero_job_option.get_parent()
	if job_parent != null:
		hero_class_group_option = OptionButton.new()
		hero_class_group_option.name = "HeroClassGroupOption"
		hero_class_group_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var job_idx: int = hero_job_option.get_index()
		if job_parent is GridContainer:
			var cg_lbl := Label.new()
			cg_lbl.text = "8대 병과:"
			var insert_at: int = maxi(0, job_idx - 1)
			job_parent.add_child(cg_lbl)
			job_parent.move_child(cg_lbl, insert_at)
			job_parent.add_child(hero_class_group_option)
			job_parent.move_child(hero_class_group_option, insert_at + 1)
		else:
			job_parent.add_child(hero_class_group_option)
			job_parent.move_child(hero_class_group_option, job_idx)
		hero_class_group_option.item_selected.connect(_on_hero_class_group_changed)

	# 적 편집기: 진영(MONSTER/HUMANOID), 아키타입(14종), 팔레트 스왑 버튼 동적 추가
	var en_parent := enemy_type_option.get_parent()
	if en_parent != null:
		enemy_category_option = OptionButton.new()
		enemy_category_option.name = "EnemyCategoryOption"
		enemy_category_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		enemy_archetype_option = OptionButton.new()
		enemy_archetype_option.name = "EnemyArchetypeOption"
		enemy_archetype_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var en_idx: int = enemy_type_option.get_index()
		if en_parent is GridContainer:
			var cat_lbl := Label.new()
			cat_lbl.text = "적 진영:"
			var arch_lbl := Label.new()
			arch_lbl.text = "적 아키타입:"
			var ins: int = maxi(0, en_idx - 1)
			en_parent.add_child(cat_lbl)
			en_parent.move_child(cat_lbl, ins)
			en_parent.add_child(enemy_category_option)
			en_parent.move_child(enemy_category_option, ins + 1)
			en_parent.add_child(arch_lbl)
			en_parent.move_child(arch_lbl, ins + 2)
			en_parent.add_child(enemy_archetype_option)
			en_parent.move_child(enemy_archetype_option, ins + 3)
		else:
			en_parent.add_child(enemy_category_option)
			en_parent.add_child(enemy_archetype_option)
		enemy_category_option.item_selected.connect(_on_enemy_category_changed)

	var save_parent := enemy_save_button.get_parent()
	if save_parent != null:
		enemy_palette_swap_button = Button.new()
		enemy_palette_swap_button.name = "EnemyPaletteSwapButton"
		enemy_palette_swap_button.text = "선택 속성 팔레트 스왑 변종 생성"
		save_parent.add_child(enemy_palette_swap_button)
		enemy_palette_swap_button.pressed.connect(_on_enemy_palette_swap_pressed)

	# 영웅 편집기: 고정 기질(fixed_temperaments) 및 일반 기질 잠금 체크 UI 동적 추가
	var form_vbox := hero_skill_edit.get_parent()
	if form_vbox != null:
		var temp_panel := PanelContainer.new()
		temp_panel.name = "HeroTemperamentConfigPanel"
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 4)
		temp_panel.add_child(tv)

		var t_head := HBoxContainer.new()
		var t_lbl := Label.new()
		t_lbl.text = "고정 기질 및 일반 기질 잠금 규칙:"
		t_head.add_child(t_lbl)
		hero_lock_temp_check = CheckBox.new()
		hero_lock_temp_check.name = "HeroLockTempCheck"
		hero_lock_temp_check.text = "일반 기질 추가 습득 잠금 (고정 기질 전용)"
		t_head.add_child(hero_lock_temp_check)
		tv.add_child(t_head)

		var t_scroll := ScrollContainer.new()
		t_scroll.custom_minimum_size = Vector2(0, 110)
		var t_grid := GridContainer.new()
		t_grid.columns = 3
		t_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t_scroll.add_child(t_grid)
		tv.add_child(t_scroll)

		_hero_fixed_temp_checks.clear()
		for cat_name in ["POSITIVE", "MIXED"]:
			for t_info in GlobalData.get_temperaments_by_category(cat_name):
				var tid: String = str(t_info["id"])
				var cb := CheckBox.new()
				var star: String = "★" if cat_name == "POSITIVE" else ""
				cb.text = "%s%s (%s)" % [star, str(t_info["name"]), str(t_info["summary"])]
				cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				t_grid.add_child(cb)
				_hero_fixed_temp_checks[tid] = cb

		form_vbox.add_child(temp_panel)
		form_vbox.move_child(temp_panel, hero_skill_edit.get_index())


func _populate_job_options(category: String, select_job: String = "", select_group: String = "") -> void:
	var hier := DataManager.normalize_class_hierarchy(select_group, select_job, category)
	var target_group: String = select_group if DataManager.CLASS_GROUPS.has(select_group) else str(hier["class_group"])
	var target_sub: String = select_job if not select_job.is_empty() else str(hier["sub_class"])

	if hero_class_group_option != null:
		hero_class_group_option.clear()
		var groups: Array = DataManager.get_class_groups_for_category(category)
		if not groups.has(target_group):
			target_group = str(groups[0])
		var g_sel: int = 0
		for i in range(groups.size()):
			var g_name: String = str(groups[i])
			var g_info: Dictionary = DataManager.get_class_group_info(g_name)
			hero_class_group_option.add_item("%s (%s)" % [g_name, str(g_info.get("trait_name", ""))])
			hero_class_group_option.set_item_metadata(i, g_name)
			if g_name == target_group:
				g_sel = i
		hero_class_group_option.select(g_sel)

	hero_job_option.clear()
	var subs: Array = DataManager.get_sub_classes_for_group(target_group)
	var target_idx: int = 0
	for i in range(subs.size()):
		var sub_name: String = str(subs[i])
		var sub_info: Dictionary = DataManager.get_sub_class_info(sub_name)
		var trait_lbl: String = str(sub_info.get("sub_trait_label", ""))
		hero_job_option.add_item("%s (%s)" % [sub_name, trait_lbl] if not trait_lbl.is_empty() else sub_name)
		hero_job_option.set_item_metadata(i, sub_name)
		if not target_sub.is_empty() and sub_name == target_sub:
			target_idx = i
	hero_job_option.select(target_idx)


func _on_hero_class_group_changed(index: int) -> void:
	if hero_class_group_option == null or index < 0 or index >= hero_class_group_option.item_count:
		return
	var cg: String = str(hero_class_group_option.get_item_metadata(index))
	var cat: String = DataManager.ROLE_CATEGORIES[maxi(0, hero_category_option.selected)]
	_populate_job_options(cat, "", cg)


func _on_hero_category_changed(index: int) -> void:
	if index < 0 or index >= DataManager.ROLE_CATEGORIES.size():
		return
	_populate_job_options(DataManager.ROLE_CATEGORIES[index])


func _on_reload_all_pressed() -> void:
	DataManager.reload_all_data()
	hero_status_label.text = "영웅 %d개 / 속성 %d개를 다시 불러왔습니다." % [DataManager.heroes.size(), DataManager.elements.size()]
	event_status_label.text = "이벤트 %d개를 다시 불러왔습니다." % DataManager.events.size()
	skill_status_label.text = "스킬 %d개를 다시 불러왔습니다." % DataManager.skills.size()
	equip_status_label.text = "장비 %d개를 다시 불러왔습니다." % DataManager.equipments.size()
	class_status_label.text = "직군 %d개를 다시 불러왔습니다." % DataManager.classes.size()
	dun_ev_status_label.text = "던전 이벤트 %d개를 다시 불러왔습니다." % DataManager.dungeon_events.size()
	dungeon_status_label.text = "던전 %d개를 다시 불러왔습니다." % DataManager.dungeons.size()
	enemy_status_label.text = "적 유닛 %d개를 다시 불러왔습니다." % DataManager.enemies.size()
	tower_status_label.text = "커스텀 타워 %d개를 다시 불러왔습니다." % DataManager.towers.size()
	item_status_label.text = "아이템 %d개를 다시 불러왔습니다." % DataManager.items.size()


func _refresh_lists() -> void:
	hero_list.clear()
	for hero in DataManager.heroes:
		var elem_name: String = DataManager.get_element_name(str(hero.get("element", "FIRE")))
		var rarity: String = DataManager.normalize_rarity(hero.get("rarity", "N"))
		var is_named_h: bool = bool(hero.get("is_named", false))
		var src_tag: String = ""
		if is_named_h:
			src_tag = "[스토리]" if str(hero.get("named_source", "NON_STORY")) == "STORY" else "[스토리외]"
		var named_mark: String = ("★" + src_tag) if is_named_h else ""
		var display_text: String = "%s[%s] %s [%s·%s / %s / %s]" % [
			named_mark,
			rarity,
			hero.get("name", "영웅"),
			DataManager.normalize_role_category(str(hero.get("role_category", "전위")), str(hero.get("job_class", ""))),
			hero.get("job_class", "탱커"),
			elem_name,
			hero.get("offense_rank", "전열"),
		]
		var idx: int = hero_list.add_item(display_text)
		var path: String = str(hero.get("_file_path", ""))
		hero_list.set_item_metadata(idx, path)
		if not _selected_hero_path.is_empty() and path == _selected_hero_path:
			hero_list.select(idx)

	event_list.clear()
	for ev in DataManager.events:
		var cat: String = str(ev.get("event_category", "NORMAL"))
		var cat_tag: String = "[반란]" if cat == "REBELLION" else ""
		var stage_tag: String = "[%d~%d단계]" % [int(ev.get("min_stage", 1)), int(ev.get("max_stage", 6))]
		var oa: Dictionary = ev.get("option_a", {})
		var ob: Dictionary = ev.get("option_b", {})
		var has_hero_rw: bool = not str(oa.get("recruit_hero_id", "")).is_empty() or not str(ob.get("recruit_hero_id", "")).is_empty()
		var has_eq_rw: bool = not str(oa.get("grant_equip_id", "")).is_empty() or not str(ob.get("grant_equip_id", "")).is_empty()
		var rw_tag: String = "★[영웅]" if has_hero_rw else ("★[장비]" if has_eq_rw else "")
		var idx: int = event_list.add_item("%s%s%s %s" % [rw_tag, cat_tag, stage_tag, str(ev.get("title", "이벤트"))])
		var path: String = str(ev.get("_file_path", ""))
		event_list.set_item_metadata(idx, path)
		if not _selected_event_path.is_empty() and path == _selected_event_path:
			event_list.select(idx)

	skill_list.clear()
	for s in DataManager.skills:
		var eff_cnt: int = (s.get("effects", []) as Array).size()
		var idx: int = skill_list.add_item("%s (효과 %d개, CD %d)" % [s["name"], eff_cnt, int(s["cooldown"])])
		var s_id: String = str(s["id"])
		skill_list.set_item_metadata(idx, s_id)
		if not _selected_skill_id.is_empty() and s_id == _selected_skill_id:
			skill_list.select(idx)

	equip_list.clear()
	for eq in DataManager.equipments:
		var r: String = DataManager.normalize_rarity(eq.get("rarity", "N"))
		var slot_lbl: String = DataManager.get_slot_label(str(eq.get("slot_type", "WEAPON")))
		var named_mark: String = "★" if bool(eq.get("is_named", false)) else ""
		var craft_tag: String = "" if bool(eq.get("craftable_in_blacksmith", not bool(eq.get("is_named", false)))) else "[제작불가]"
		var idx: int = equip_list.add_item("%s%s[%s][%s] %s" % [named_mark, craft_tag, r, slot_lbl, str(eq.get("name", "장비"))])
		var e_id: String = str(eq.get("id", ""))
		equip_list.set_item_metadata(idx, e_id)
		if not _selected_equip_id.is_empty() and e_id == _selected_equip_id:
			equip_list.select(idx)

	class_list.clear()
	for c in DataManager.classes:
		var cid: String = str(c.get("id", ""))
		var cg: String = str(c.get("class_group", DataManager.get_class_group_for_sub_class(cid)))
		var idx: int = class_list.add_item("[%s] %s (이동+%d / 전투+%d)" % [
			cg,
			str(c.get("name", cid)),
			int(c.get("move_fatigue_cost", 4)),
			int(c.get("battle_fatigue_cost", 10)),
		])
		class_list.set_item_metadata(idx, cid)
		if not _selected_class_id.is_empty() and cid == _selected_class_id:
			class_list.select(idx)

	dungeon_event_list.clear()
	for dev in DataManager.dungeon_events:
		var dev_id: String = str(dev.get("id", ""))
		var ch_cnt: int = (dev.get("choices", []) as Array).size()
		var idx: int = dungeon_event_list.add_item("%s (선택지 %d개)" % [str(dev.get("title", dev_id)), ch_cnt])
		dungeon_event_list.set_item_metadata(idx, dev_id)
		if not _selected_dun_ev_id.is_empty() and dev_id == _selected_dun_ev_id:
			dungeon_event_list.select(idx)

	dungeon_list.clear()
	for d in DataManager.dungeons:
		var did: String = str(d.get("id", ""))
		var dtype: String = str(d.get("dungeon_type", "FIELD_GRID"))
		var drop_cnt: int = (d.get("drop_equipment_ids", []) as Array).size()
		var idx: int = dungeon_list.add_item("[%s] %s (드랍 %d종)" % [dtype, str(d.get("name", did)), drop_cnt])
		dungeon_list.set_item_metadata(idx, did)
		if not _selected_dungeon_id.is_empty() and did == _selected_dungeon_id:
			dungeon_list.select(idx)

	_rebuild_dungeon_drop_checkboxes()

	enemy_list.clear()
	for en in DataManager.enemies:
		var eid: String = str(en.get("id", ""))
		var etype: String = str(en.get("enemy_type", "NORMAL"))
		var ecat: String = str(en.get("category", "MONSTER"))
		var earch: String = str(en.get("archetype", "SWARMER"))
		var el_name: String = DataManager.get_element_name(str(en.get("element", "FIRE")))
		var idx: int = enemy_list.add_item("[%s·%s][%s][%s] %s (HP %d)" % [ecat, earch, etype, el_name, str(en.get("name", eid)), int(en.get("max_hp", 50))])
		enemy_list.set_item_metadata(idx, eid)
		if not _selected_enemy_id.is_empty() and eid == _selected_enemy_id:
			enemy_list.select(idx)

	_rebuild_enemy_skill_checkboxes()

	tower_list.clear()
	for tw in DataManager.towers:
		var tid: String = str(tw.get("id", ""))
		var el_name: String = DataManager.get_element_name(str(tw.get("element", "FIRE")))
		var idx: int = tower_list.add_item("[%s][%s] %s (ATK %d)" % [el_name, str(tw.get("target_scope", "SINGLE_FRONT")), str(tw.get("name", tid)), int(tw.get("atk", 20))])
		tower_list.set_item_metadata(idx, tid)
		if not _selected_tower_id.is_empty() and tid == _selected_tower_id:
			tower_list.select(idx)

	item_list.clear()
	for it in DataManager.items:
		var iid: String = str(it.get("id", ""))
		var r: String = DataManager.normalize_rarity(it.get("rarity", "N"))
		var itype: String = str(it.get("item_type", "HEAL_HP"))
		var idx: int = item_list.add_item("[%s][%s] %s (수치 %.2g)" % [r, itype, str(it.get("name", iid)), float(it.get("power", 0.0))])
		item_list.set_item_metadata(idx, iid)
		if not _selected_item_id.is_empty() and iid == _selected_item_id:
			item_list.select(idx)


# ==========================================
# 1. 영웅 편집기 로직
# ==========================================
func _on_hero_selected(index: int) -> void:
	if index < 0 or index >= DataManager.heroes.size():
		return
	var hero: Dictionary = DataManager.heroes[index]
	_selected_hero_path = str(hero.get("_file_path", ""))
	hero_file_label.text = "파일: %s" % _selected_hero_path.get_file()

	hero_name_edit.text = str(hero.get("name", ""))
	hero_named_check.button_pressed = bool(hero.get("is_named", false))
	var src_idx: int = DataManager.NAMED_SOURCES.find(str(hero.get("named_source", "NONE")))
	hero_named_source_option.select(maxi(0, src_idx))
	hero_named_title_edit.text = str(hero.get("named_title", ""))
	hero_lore_edit.text = str(hero.get("lore", ""))
	_populate_hero_sig_equip_options(str(hero.get("signature_equip_id", "")))
	var r_idx: int = DataManager.RARITIES.find(DataManager.normalize_rarity(hero.get("rarity", "N")))
	hero_rarity_option.select(maxi(0, r_idx))

	var hier: Dictionary = DataManager.normalize_class_hierarchy(
		str(hero.get("class_group", "")),
		str(hero.get("sub_class", hero.get("job_class", ""))),
		str(hero.get("role_category", "전위"))
	)
	var cat: String = str(hier["role_category"])
	var cat_idx: int = DataManager.ROLE_CATEGORIES.find(cat)
	hero_category_option.select(maxi(0, cat_idx))
	_populate_job_options(cat, str(hier["sub_class"]), str(hier["class_group"]))

	_populate_element_options(str(hero.get("element", "")))
	_populate_hero_skill_options(
		str(hero.get("skill_id", "")),
		str(hero.get("skill2_id", "")),
		str(hero.get("ultimate_id", ""))
	)
	hero_def_spin.value = int(hero.get("def", 10))
	hero_hp_spin.value = int(hero.get("max_hp", 50))
	hero_atk_spin.value = int(hero.get("atk", 15))
	hero_speed_spin.value = int(hero.get("speed", 10))
	hero_heal_spin.value = int(hero.get("heal_power", 0))
	hero_dmg_bonus_spin.value = float(hero.get("dmg_bonus", 0.0))
	hero_crit_rate_spin.value = float(hero.get("crit_rate", 0.05))
	hero_crit_dmg_spin.value = float(hero.get("crit_dmg", 1.5))
	hero_armor_pen_spin.value = float(hero.get("armor_pen", 0.0))
	hero_final_mult_spin.value = float(hero.get("final_dmg_mult", 1.0))

	var rank_idx: int = RANK_OPTIONS.find(str(hero.get("offense_rank", "전열")))
	hero_rank_option.select(maxi(0, rank_idx))

	var zone_idx: int = ZONE_OPTIONS.find(str(hero.get("defense_zone", "성벽밖")))
	hero_zone_option.select(maxi(0, zone_idx))

	hero_skill_edit.text = str(hero.get("skill_description", ""))
	if hero_lock_temp_check != null:
		hero_lock_temp_check.button_pressed = bool(hero.get("lock_general_temperaments", false))
	var fixed_arr: Array = hero.get("fixed_temperaments", [])
	for tid in _hero_fixed_temp_checks:
		var cb: CheckBox = _hero_fixed_temp_checks[tid]
		cb.button_pressed = fixed_arr.has(tid)
	hero_delete_button.disabled = false
	hero_status_label.text = ""


func _on_hero_new_pressed() -> void:
	_clear_hero_form()
	hero_status_label.text = "새 영웅 작성 모드입니다. 입력 후 [JSON 파일로 저장]을 누르세요."


func _clear_hero_form() -> void:
	_selected_hero_path = ""
	hero_list.deselect_all()
	hero_file_label.text = "파일: (새 파일로 저장됨)"
	hero_name_edit.text = ""
	hero_named_check.button_pressed = false
	hero_named_source_option.select(0)
	hero_named_title_edit.text = ""
	hero_lore_edit.text = ""
	_populate_hero_sig_equip_options("")
	hero_rarity_option.select(0)
	hero_category_option.select(0)
	_populate_job_options(DataManager.ROLE_CATEGORIES[0])
	_populate_element_options()
	_populate_hero_skill_options("", "", "")
	hero_def_spin.value = 10
	hero_hp_spin.value = 60
	hero_atk_spin.value = 18
	hero_speed_spin.value = 12
	hero_heal_spin.value = 0
	hero_dmg_bonus_spin.value = 0.0
	hero_crit_rate_spin.value = 0.05
	hero_crit_dmg_spin.value = 1.5
	hero_armor_pen_spin.value = 0.0
	hero_final_mult_spin.value = 1.0
	hero_rank_option.select(0)
	hero_zone_option.select(1)
	hero_skill_edit.text = ""
	if hero_lock_temp_check != null:
		hero_lock_temp_check.button_pressed = false
	for tid in _hero_fixed_temp_checks:
		(_hero_fixed_temp_checks[tid] as CheckBox).button_pressed = false
	hero_delete_button.disabled = true


func _on_hero_save_pressed() -> void:
	var h_name: String = hero_name_edit.text.strip_edges()
	if h_name.is_empty():
		hero_status_label.text = "오류: 영웅 이름을 입력해 주세요."
		return

	var cat: String = DataManager.ROLE_CATEGORIES[hero_category_option.selected]
	var cg: String = str(hero_class_group_option.get_item_metadata(maxi(0, hero_class_group_option.selected))) if hero_class_group_option != null and hero_class_group_option.item_count > 0 else ""
	var job: String = str(hero_job_option.get_item_metadata(maxi(0, hero_job_option.selected))) if hero_job_option.item_count > 0 else "방패수호자"
	if job.is_empty():
		var jobs: Array = DataManager.get_job_classes_for_category(cat)
		job = str(jobs[clampi(hero_job_option.selected, 0, jobs.size() - 1)])

	var rarity: String = _get_selected_rarity()
	var rules: Dictionary = DataManager.get_skill_slot_rules(rarity)
	var is_named_hero: bool = hero_named_check.button_pressed
	var named_source_val: String = str(hero_named_source_option.get_item_metadata(maxi(0, hero_named_source_option.selected)))
	if not is_named_hero:
		named_source_val = "NONE"
	elif named_source_val == "NONE":
		named_source_val = "NON_STORY"

	var fixed_temps_save: Array[String] = []
	for tid in _hero_fixed_temp_checks:
		var cb: CheckBox = _hero_fixed_temp_checks[tid]
		if cb.button_pressed:
			fixed_temps_save.append(str(tid))
	var lock_temp_save: bool = (hero_lock_temp_check.button_pressed if hero_lock_temp_check != null else false) or is_named_hero or not fixed_temps_save.is_empty()

	var payload: Dictionary = {
		"name": h_name,
		"is_named": is_named_hero,
		"named_source": named_source_val,
		"named_title": hero_named_title_edit.text.strip_edges(),
		"lore": hero_lore_edit.text.strip_edges(),
		"signature_equip_id": _get_selected_dropdown_skill_id(hero_sig_equip_option),
		"fixed_temperaments": fixed_temps_save,
		"lock_general_temperaments": lock_temp_save,
		"rarity": rarity,
		"role_category": cat,
		"class_group": cg if not cg.is_empty() else DataManager.get_class_group_for_sub_class(job),
		"sub_class": job,
		"job_class": job,
		"element": _get_selected_element_id(),
		"max_hp": int(hero_hp_spin.value),
		"atk": int(hero_atk_spin.value),
		"def": int(hero_def_spin.value),
		"heal_power": int(hero_heal_spin.value),
		"speed": int(hero_speed_spin.value),
		"dmg_bonus": hero_dmg_bonus_spin.value,
		"crit_rate": hero_crit_rate_spin.value,
		"crit_dmg": hero_crit_dmg_spin.value,
		"armor_pen": hero_armor_pen_spin.value,
		"final_dmg_mult": hero_final_mult_spin.value,
		"offense_rank": RANK_OPTIONS[hero_rank_option.selected],
		"defense_zone": ZONE_OPTIONS[hero_zone_option.selected],
		"skill_id": _get_selected_dropdown_skill_id(hero_skill_option) if bool(rules["active1"]) else "",
		"skill2_id": _get_selected_dropdown_skill_id(hero_skill2_option) if bool(rules["active2"]) else "",
		"ultimate_id": _get_selected_dropdown_skill_id(hero_ultimate_option) if bool(rules["ultimate"]) else "",
		"passive_skill_id": _get_existing_hero_passive_skill_id(_selected_hero_path),
		"skill_description": hero_skill_edit.text.strip_edges(),
	}

	var saved_path: String = DataManager.save_hero(payload, _selected_hero_path)
	if saved_path.is_empty():
		hero_status_label.text = "저장 실패: 파일 쓰기 권한을 확인해 주세요."
		return

	_selected_hero_path = saved_path
	_refresh_lists()
	hero_file_label.text = "파일: %s" % saved_path.get_file()
	hero_delete_button.disabled = false
	hero_status_label.text = "저장 완료: %s" % saved_path


func _get_existing_hero_passive_skill_id(file_path: String) -> String:
	if file_path.is_empty():
		return ""
	for h in DataManager.heroes:
		if str(h.get("_file_path", "")) == file_path:
			return str(h.get("passive_skill_id", "")).strip_edges()
	return ""


func _on_hero_delete_pressed() -> void:
	if _selected_hero_path.is_empty():
		return
	var deleted_name: String = _selected_hero_path.get_file()
	if DataManager.delete_data_file(_selected_hero_path):
		_clear_hero_form()
		hero_status_label.text = "삭제 완료: %s" % deleted_name
	else:
		hero_status_label.text = "삭제 실패: 파일을 찾을 수 없습니다."


# ==========================================
# 2. 정책 이벤트 편집기 로직
# ==========================================
func _on_event_selected(index: int) -> void:
	if index < 0 or index >= DataManager.events.size():
		return
	var ev: Dictionary = DataManager.events[index]
	_selected_event_path = str(ev.get("_file_path", ""))
	event_file_label.text = "파일: %s" % _selected_event_path.get_file()

	event_title_edit.text = str(ev.get("title", ""))
	var cat_idx: int = DataManager.EVENT_CATEGORIES.find(str(ev.get("event_category", "NORMAL")))
	event_category_option.select(maxi(0, cat_idx))
	event_min_stage_option.select(clampi(int(ev.get("min_stage", 1)) - 1, 0, 5))
	event_max_stage_option.select(clampi(int(ev.get("max_stage", 6)) - 1, 0, 5))
	event_desc_edit.text = str(ev.get("description", ""))

	var opt_a: Dictionary = ev.get("option_a", {})
	var deltas_a: Dictionary = opt_a.get("deltas", {})
	opt_a_text_edit.text = str(opt_a.get("text", ""))
	opt_a_food_spin.value = int(deltas_a.get("food", 0))
	opt_a_mat_spin.value = int(deltas_a.get("materials", 0))
	opt_a_morale_spin.value = int(deltas_a.get("morale", 0))
	opt_a_gold_spin.value = int(deltas_a.get("gold", 0))
	opt_a_unrest_spin.value = int(deltas_a.get("unrest", 0))

	var opt_b: Dictionary = ev.get("option_b", {})
	var deltas_b: Dictionary = opt_b.get("deltas", {})
	opt_b_text_edit.text = str(opt_b.get("text", ""))
	opt_b_food_spin.value = int(deltas_b.get("food", 0))
	opt_b_mat_spin.value = int(deltas_b.get("materials", 0))
	opt_b_morale_spin.value = int(deltas_b.get("morale", 0))
	opt_b_gold_spin.value = int(deltas_b.get("gold", 0))
	opt_b_unrest_spin.value = int(deltas_b.get("unrest", 0))

	_populate_event_reward_options(
		str(opt_a.get("recruit_hero_id", "")),
		str(opt_a.get("grant_equip_id", "")),
		str(opt_a.get("grant_item_id", "")),
		str(opt_b.get("recruit_hero_id", "")),
		str(opt_b.get("grant_equip_id", "")),
		str(opt_b.get("grant_item_id", ""))
	)

	event_delete_button.disabled = false
	event_status_label.text = ""


func _on_event_new_pressed() -> void:
	_clear_event_form()
	event_status_label.text = "새 정책 이벤트 작성 모드입니다. 입력 후 [JSON 파일로 저장]을 누르세요."


func _clear_event_form() -> void:
	_selected_event_path = ""
	event_list.deselect_all()
	event_file_label.text = "파일: (새 파일로 저장됨)"
	event_title_edit.text = ""
	event_category_option.select(0)
	event_min_stage_option.select(0)
	event_max_stage_option.select(5)
	event_desc_edit.text = ""
	opt_a_text_edit.text = ""
	opt_a_food_spin.value = 0
	opt_a_mat_spin.value = 0
	opt_a_morale_spin.value = 0
	opt_a_gold_spin.value = 0
	opt_a_unrest_spin.value = 0
	opt_b_text_edit.text = ""
	opt_b_food_spin.value = 0
	opt_b_mat_spin.value = 0
	opt_b_morale_spin.value = 0
	opt_b_gold_spin.value = 0
	opt_b_unrest_spin.value = 0
	_populate_event_reward_options("", "", "", "", "", "")
	event_delete_button.disabled = true


func _on_event_save_pressed() -> void:
	var title: String = event_title_edit.text.strip_edges()
	if title.is_empty():
		event_status_label.text = "오류: 이벤트 제목을 입력해 주세요."
		return

	var min_s: int = clampi(event_min_stage_option.selected + 1, 1, 6)
	var max_s: int = clampi(event_max_stage_option.selected + 1, min_s, 6)
	var cat_str: String = str(event_category_option.get_item_metadata(maxi(0, event_category_option.selected)))

	var deltas_a: Dictionary = {
		"food": int(opt_a_food_spin.value),
		"materials": int(opt_a_mat_spin.value),
		"morale": int(opt_a_morale_spin.value),
	}
	if int(opt_a_gold_spin.value) != 0:
		deltas_a["gold"] = int(opt_a_gold_spin.value)
	if int(opt_a_unrest_spin.value) != 0:
		deltas_a["unrest"] = int(opt_a_unrest_spin.value)

	var deltas_b: Dictionary = {
		"food": int(opt_b_food_spin.value),
		"materials": int(opt_b_mat_spin.value),
		"morale": int(opt_b_morale_spin.value),
	}
	if int(opt_b_gold_spin.value) != 0:
		deltas_b["gold"] = int(opt_b_gold_spin.value)
	if int(opt_b_unrest_spin.value) != 0:
		deltas_b["unrest"] = int(opt_b_unrest_spin.value)

	var payload: Dictionary = {
		"title": title,
		"description": event_desc_edit.text.strip_edges(),
		"event_category": cat_str,
		"min_stage": min_s,
		"max_stage": max_s,
		"option_a": {
			"text": opt_a_text_edit.text.strip_edges(),
			"deltas": deltas_a,
			"recruit_hero_id": _get_selected_dropdown_skill_id(opt_a_hero_option),
			"grant_equip_id": _get_selected_dropdown_skill_id(opt_a_equip_option),
			"grant_item_id": _get_selected_dropdown_skill_id(opt_a_item_option),
		},
		"option_b": {
			"text": opt_b_text_edit.text.strip_edges(),
			"deltas": deltas_b,
			"recruit_hero_id": _get_selected_dropdown_skill_id(opt_b_hero_option),
			"grant_equip_id": _get_selected_dropdown_skill_id(opt_b_equip_option),
			"grant_item_id": _get_selected_dropdown_skill_id(opt_b_item_option),
		},
	}

	var saved_path: String = DataManager.save_event(payload, _selected_event_path)
	if saved_path.is_empty():
		event_status_label.text = "저장 실패: 파일 쓰기 권한을 확인해 주세요."
		return

	_selected_event_path = saved_path
	_refresh_lists()
	event_file_label.text = "파일: %s" % saved_path.get_file()
	event_delete_button.disabled = false
	event_status_label.text = "저장 완료: %s" % saved_path


func _on_event_delete_pressed() -> void:
	if _selected_event_path.is_empty():
		return
	var deleted_name: String = _selected_event_path.get_file()
	if DataManager.delete_data_file(_selected_event_path):
		_clear_event_form()
		event_status_label.text = "삭제 완료: %s" % deleted_name
	else:
		event_status_label.text = "삭제 실패: 파일을 찾을 수 없습니다."


# ==========================================
# 3. 조립식 스킬 편집기 로직
# ==========================================
func _on_skill_selected(index: int) -> void:
	if index < 0 or index >= DataManager.skills.size():
		return
	var skill: Dictionary = DataManager.skills[index]
	_selected_skill_id = str(skill.get("id", ""))
	skill_id_label.text = "스킬 ID: %s (skills.json)" % _selected_skill_id

	skill_name_edit.text = str(skill.get("name", ""))
	skill_cooldown_spin.value = int(skill.get("cooldown", 1))
	skill_desc_edit.text = str(skill.get("description", ""))

	_editing_effects.clear()
	for eff in skill.get("effects", []):
		_editing_effects.append(eff.duplicate(true))

	_selected_effect_idx = -1
	_refresh_skill_effect_list()
	skill_delete_button.disabled = false
	skill_status_label.text = ""


func _on_skill_new_pressed() -> void:
	_clear_skill_form()
	skill_status_label.text = "새 스킬 작성 모드입니다. 효과를 조립한 뒤 [JSON 파일로 저장]을 누르세요."


func _clear_skill_form() -> void:
	_selected_skill_id = ""
	_editing_effects.clear()
	_selected_effect_idx = -1
	skill_list.deselect_all()
	skill_id_label.text = "스킬 ID: (새 스킬로 저장됨)"
	skill_name_edit.text = ""
	skill_cooldown_spin.value = 2
	skill_desc_edit.text = ""
	effect_type_option.select(0)
	effect_scope_option.select(0)
	effect_mult_spin.value = 1.5
	effect_duration_spin.value = 2
	effect_bonus_crit_spin.value = 0.0
	effect_bonus_pen_spin.value = 0.0
	_refresh_skill_effect_list()
	skill_delete_button.disabled = true


func _refresh_skill_effect_list() -> void:
	skill_effect_list.clear()
	for i in range(_editing_effects.size()):
		var eff: Dictionary = _editing_effects[i]
		var e_type: String = str(eff.get("effect_type", "DAMAGE"))
		var scope: String = str(eff.get("target_scope", "SINGLE_FRONT"))
		var mult: float = float(eff.get("multiplier", 1.0))
		var dur: int = int(eff.get("duration", 0))
		var b_crit: float = float(eff.get("skill_bonus_crit_rate", 0.0))
		var b_pen: float = float(eff.get("skill_bonus_armor_pen", 0.0))

		var summary: String = "#%d [%s / %s] 계수:%.2f | 지속:%d" % [
			i + 1,
			StatusEffectManager.get_effect_label(e_type),
			scope,
			mult,
			dur,
		]
		if b_crit > 0.0 or b_pen > 0.0:
			summary += " (치명+%.0f%%, 방관+%.0f%%)" % [b_crit * 100.0, b_pen * 100.0]

		skill_effect_list.add_item(summary)

	if _selected_effect_idx >= 0 and _selected_effect_idx < _editing_effects.size():
		skill_effect_list.select(_selected_effect_idx)
		effect_update_button.disabled = false
		effect_remove_button.disabled = false
	else:
		_selected_effect_idx = -1
		effect_update_button.disabled = true
		effect_remove_button.disabled = true


func _on_skill_effect_selected(index: int) -> void:
	if index < 0 or index >= _editing_effects.size():
		return
	_selected_effect_idx = index
	var eff: Dictionary = _editing_effects[index]

	var t_idx: int = DataManager.EFFECT_TYPES.find(str(eff.get("effect_type", "DAMAGE")))
	effect_type_option.select(maxi(0, t_idx))

	var s_idx: int = DataManager.TARGET_SCOPES.find(str(eff.get("target_scope", "SINGLE_FRONT")))
	effect_scope_option.select(maxi(0, s_idx))

	effect_mult_spin.value = float(eff.get("multiplier", 1.0))
	effect_duration_spin.value = float(eff.get("duration", 0))
	effect_bonus_crit_spin.value = float(eff.get("skill_bonus_crit_rate", 0.0))
	effect_bonus_pen_spin.value = float(eff.get("skill_bonus_armor_pen", 0.0))

	effect_update_button.disabled = false
	effect_remove_button.disabled = false


func _read_effect_builder_dict() -> Dictionary:
	var e_type: String = str(effect_type_option.get_item_metadata(effect_type_option.selected))
	var scope: String = str(effect_scope_option.get_item_metadata(effect_scope_option.selected))
	return {
		"effect_type": e_type,
		"target_scope": scope,
		"multiplier": effect_mult_spin.value,
		"duration": int(effect_duration_spin.value),
		"skill_bonus_crit_rate": effect_bonus_crit_spin.value,
		"skill_bonus_armor_pen": effect_bonus_pen_spin.value,
	}


func _on_effect_add_pressed() -> void:
	_editing_effects.append(_read_effect_builder_dict())
	_selected_effect_idx = _editing_effects.size() - 1
	_refresh_skill_effect_list()


func _on_effect_update_pressed() -> void:
	if _selected_effect_idx < 0 or _selected_effect_idx >= _editing_effects.size():
		return
	_editing_effects[_selected_effect_idx] = _read_effect_builder_dict()
	_refresh_skill_effect_list()


func _on_effect_remove_pressed() -> void:
	if _selected_effect_idx < 0 or _selected_effect_idx >= _editing_effects.size():
		return
	_editing_effects.remove_at(_selected_effect_idx)
	_selected_effect_idx = -1
	_refresh_skill_effect_list()


func _on_skill_save_pressed() -> void:
	var s_name: String = skill_name_edit.text.strip_edges()
	if s_name.is_empty():
		skill_status_label.text = "오류: 스킬 이름을 입력해 주세요."
		return
	if _editing_effects.is_empty():
		skill_status_label.text = "오류: 최소 1개 이상의 효과 블록을 추가해 주세요."
		return

	var payload: Dictionary = {
		"name": s_name,
		"description": skill_desc_edit.text.strip_edges(),
		"cooldown": int(skill_cooldown_spin.value),
		"effects": _editing_effects.duplicate(true),
	}

	var saved_id: String = DataManager.save_skill(payload, _selected_skill_id)
	if saved_id.is_empty():
		skill_status_label.text = "저장 실패: skills.json 파일 쓰기 권한을 확인해 주세요."
		return

	_selected_skill_id = saved_id
	_refresh_lists()
	skill_id_label.text = "스킬 ID: %s (skills.json)" % saved_id
	skill_delete_button.disabled = false
	skill_status_label.text = "저장 완료: %s (%s)" % [DataManager.get_skills_file_path(), saved_id]


func _on_skill_delete_pressed() -> void:
	if _selected_skill_id.is_empty():
		return
	var target_id: String = _selected_skill_id
	if DataManager.delete_skill(target_id):
		_clear_skill_form()
		skill_status_label.text = "삭제 완료: %s" % target_id
	else:
		skill_status_label.text = "삭제 실패: 스킬을 찾을 수 없습니다."


# ==========================================
# 4. 모듈형 장비 편집기 로직 (data/equipments.json)
# ==========================================
func _on_equip_selected(index: int) -> void:
	if index < 0 or index >= DataManager.equipments.size():
		return
	var eq: Dictionary = DataManager.equipments[index]
	_selected_equip_id = str(eq.get("id", ""))
	equip_id_label.text = "장비 ID: %s (equipments.json)" % _selected_equip_id

	equip_name_edit.text = str(eq.get("name", ""))
	var r_idx: int = DataManager.RARITIES.find(DataManager.normalize_rarity(eq.get("rarity", "N")))
	equip_rarity_option.select(maxi(0, r_idx))

	var s_idx: int = DataManager.SLOT_TYPES.find(str(eq.get("slot_type", "WEAPON")))
	equip_slot_option.select(maxi(0, s_idx))

	var classes: Array = eq.get("allowed_classes", ["ALL"])
	equip_classes_edit.text = ", ".join(PackedStringArray(classes))

	equip_named_check.button_pressed = bool(eq.get("is_named", false))
	equip_craftable_check.button_pressed = bool(eq.get("craftable_in_blacksmith", not bool(eq.get("is_named", false))))
	equip_named_title_edit.text = str(eq.get("named_title", ""))
	_populate_equip_reference_options(
		str(eq.get("exclusive_hero_id", "")),
		str(eq.get("passive_skill_id", "")),
		str(eq.get("resonance_skill_id", ""))
	)

	var bonuses: Dictionary = eq.get("stat_bonuses", {})
	equip_hp_spin.value = float(bonuses.get("max_hp", 0.0))
	equip_atk_spin.value = float(bonuses.get("atk", 0.0))
	equip_def_spin.value = float(bonuses.get("def", 0.0))
	equip_speed_spin.value = float(bonuses.get("speed", 0.0))
	equip_dmg_bonus_spin.value = float(bonuses.get("dmg_bonus", 0.0))
	equip_crit_rate_spin.value = float(bonuses.get("crit_rate", 0.0))
	equip_crit_dmg_spin.value = float(bonuses.get("crit_dmg", 0.0))
	equip_armor_pen_spin.value = float(bonuses.get("armor_pen", 0.0))
	equip_final_mult_spin.value = float(bonuses.get("final_dmg_mult", 0.0))

	equip_desc_edit.text = str(eq.get("description", ""))
	equip_delete_button.disabled = false
	equip_status_label.text = ""


func _on_equip_new_pressed() -> void:
	_clear_equip_form()
	equip_status_label.text = "새 장비 작성 모드입니다. 입력 후 [JSON 파일로 저장]을 누르세요."


func _clear_equip_form() -> void:
	_selected_equip_id = ""
	equip_list.deselect_all()
	equip_id_label.text = "장비 ID: (새 장비로 저장됨)"
	equip_name_edit.text = ""
	equip_rarity_option.select(0)
	equip_slot_option.select(0)
	equip_classes_edit.text = "ALL"
	equip_named_check.button_pressed = false
	equip_craftable_check.button_pressed = true
	equip_named_title_edit.text = ""
	_populate_equip_reference_options("", "", "")
	equip_hp_spin.value = 0.0
	equip_atk_spin.value = 0.0
	equip_def_spin.value = 0.0
	equip_speed_spin.value = 0.0
	equip_dmg_bonus_spin.value = 0.0
	equip_crit_rate_spin.value = 0.0
	equip_crit_dmg_spin.value = 0.0
	equip_armor_pen_spin.value = 0.0
	equip_final_mult_spin.value = 0.0
	equip_desc_edit.text = ""
	equip_delete_button.disabled = true


func _on_equip_save_pressed() -> void:
	var e_name: String = equip_name_edit.text.strip_edges()
	if e_name.is_empty():
		equip_status_label.text = "오류: 장비 이름을 입력해 주세요."
		return

	var allowed_classes: Array[String] = []
	for token in equip_classes_edit.text.split(",", false):
		var clean_tok: String = token.strip_edges()
		if not clean_tok.is_empty():
			allowed_classes.append(clean_tok)
	if allowed_classes.is_empty():
		allowed_classes.append("ALL")

	var rarity_str: String = equip_rarity_option.get_item_text(equip_rarity_option.selected)
	var slot_str: String = str(equip_slot_option.get_item_metadata(equip_slot_option.selected))

	var payload: Dictionary = {
		"name": e_name,
		"description": equip_desc_edit.text.strip_edges(),
		"rarity": rarity_str,
		"slot_type": slot_str,
		"is_named": equip_named_check.button_pressed,
		"craftable_in_blacksmith": equip_craftable_check.button_pressed,
		"named_title": equip_named_title_edit.text.strip_edges(),
		"allowed_classes": allowed_classes,
		"exclusive_hero_id": _get_selected_dropdown_skill_id(equip_exclusive_option),
		"passive_skill_id": _get_selected_dropdown_skill_id(equip_passive_option),
		"resonance_skill_id": _get_selected_dropdown_skill_id(equip_resonance_option),
		"stat_bonuses": {
			"max_hp": int(equip_hp_spin.value),
			"atk": int(equip_atk_spin.value),
			"def": int(equip_def_spin.value),
			"speed": int(equip_speed_spin.value),
			"dmg_bonus": equip_dmg_bonus_spin.value,
			"crit_rate": equip_crit_rate_spin.value,
			"crit_dmg": equip_crit_dmg_spin.value,
			"armor_pen": equip_armor_pen_spin.value,
			"final_dmg_mult": equip_final_mult_spin.value,
		},
	}

	var saved_id: String = DataManager.save_equipment(payload, _selected_equip_id)
	if saved_id.is_empty():
		equip_status_label.text = "저장 실패: equipments.json 파일 쓰기 권한을 확인해 주세요."
		return

	_selected_equip_id = saved_id
	_refresh_lists()
	equip_id_label.text = "장비 ID: %s (equipments.json)" % saved_id
	equip_delete_button.disabled = false
	equip_status_label.text = "저장 완료: %s (%s)" % [DataManager.get_equipments_file_path(), saved_id]


func _on_equip_delete_pressed() -> void:
	if _selected_equip_id.is_empty():
		return
	var target_id: String = _selected_equip_id
	if DataManager.delete_equipment(target_id):
		_clear_equip_form()
		equip_status_label.text = "삭제 완료: %s" % target_id
	else:
		equip_status_label.text = "삭제 실패: 장비를 찾을 수 없습니다."


# ==========================================
# 5. 직군·피로도 설정 로직
# ==========================================
func _on_class_selected(index: int) -> void:
	if index < 0 or index >= DataManager.classes.size():
		return
	var cls: Dictionary = DataManager.classes[index]
	_selected_class_id = str(cls.get("id", ""))
	var cg: String = str(cls.get("class_group", DataManager.get_class_group_for_sub_class(_selected_class_id)))
	var cg_info: Dictionary = DataManager.get_class_group_info(cg)
	class_id_label.text = "세부직군 ID: %s (병과: %s · %s)" % [_selected_class_id, cg, str(cg_info.get("trait_name", ""))]
	class_name_label.text = "직군명: %s  |  고유 특성: %s" % [str(cls.get("name", _selected_class_id)), str(cls.get("sub_trait_label", "-"))]
	class_move_fatigue_spin.value = int(cls.get("move_fatigue_cost", 4))
	class_battle_fatigue_spin.value = int(cls.get("battle_fatigue_cost", 10))
	class_desc_edit.text = str(cls.get("description", ""))
	class_save_button.disabled = false
	class_status_label.text = ""


func _clear_class_form() -> void:
	_selected_class_id = ""
	class_list.deselect_all()
	class_id_label.text = "직군 ID: -"
	class_name_label.text = "직군을 왼쪽 목록에서 선택하세요"
	class_move_fatigue_spin.value = 4
	class_battle_fatigue_spin.value = 10
	class_desc_edit.text = ""
	class_save_button.disabled = true


func _on_class_save_pressed() -> void:
	if _selected_class_id.is_empty():
		class_status_label.text = "오류: 먼저 왼쪽 목록에서 직군을 선택하세요."
		return
	var existing_cls: Dictionary = DataManager.class_map.get(_selected_class_id, {})
	var payload: Dictionary = {
		"id": _selected_class_id,
		"name": _selected_class_id,
		"move_fatigue_cost": int(class_move_fatigue_spin.value),
		"battle_fatigue_cost": int(class_battle_fatigue_spin.value),
		"vision_bonus": int(existing_cls.get("vision_bonus", 1 if _selected_class_id == "척후병" else 0)),
		"danger_sense": bool(existing_cls.get("danger_sense", _selected_class_id == "척후병")),
		"description": class_desc_edit.text.strip_edges(),
	}
	var saved_id: String = DataManager.save_class_data(payload, _selected_class_id)
	if saved_id.is_empty():
		class_status_label.text = "저장 실패: classes.json 쓰기 권한을 확인하세요."
		return
	_refresh_lists()
	class_status_label.text = "저장 완료: %s (%s: 이동+%d / 전투+%d)" % [
		DataManager.CLASSES_FILE,
		saved_id,
		int(payload["move_fatigue_cost"]),
		int(payload["battle_fatigue_cost"]),
	]


# ==========================================
# 6. 던전 이벤트(?) 편집기 로직
# ==========================================
func _on_dun_ev_selected(index: int) -> void:
	if index < 0 or index >= DataManager.dungeon_events.size():
		return
	var ev: Dictionary = DataManager.dungeon_events[index]
	_selected_dun_ev_id = str(ev.get("id", ""))
	dun_ev_id_label.text = "던전 이벤트 ID: %s (dungeon_events.json)" % _selected_dun_ev_id
	dun_ev_title_edit.text = str(ev.get("title", ""))
	dun_ev_desc_edit.text = str(ev.get("description", ""))
	_editing_dun_choices.clear()
	for ch in ev.get("choices", []):
		if typeof(ch) == TYPE_DICTIONARY:
			_editing_dun_choices.append((ch as Dictionary).duplicate(true))
	_selected_dun_choice_idx = -1
	_refresh_dun_choice_list()
	_clear_dun_choice_inputs()
	dun_ev_delete_button.disabled = false
	dun_ev_status_label.text = ""


func _on_dun_ev_new_pressed() -> void:
	_clear_dun_ev_form()
	dun_ev_status_label.text = "새 던전(?) 이벤트 작성 모드입니다."


func _clear_dun_ev_form() -> void:
	_selected_dun_ev_id = ""
	dungeon_event_list.deselect_all()
	dun_ev_id_label.text = "던전 이벤트 ID: (새 이벤트로 저장됨)"
	dun_ev_title_edit.text = ""
	dun_ev_desc_edit.text = ""
	_editing_dun_choices.clear()
	_selected_dun_choice_idx = -1
	_refresh_dun_choice_list()
	_clear_dun_choice_inputs()
	dun_ev_delete_button.disabled = true


func _clear_dun_choice_inputs() -> void:
	dun_ev_choice_label_edit.text = ""
	dun_ev_choice_result_edit.text = ""
	dun_ev_cost_gold_spin.value = 0
	dun_ev_cost_food_spin.value = 0
	dun_ev_cost_mat_spin.value = 0
	dun_ev_reward_gold_spin.value = 0
	dun_ev_reward_food_spin.value = 0
	dun_ev_reward_mat_spin.value = 0
	dun_ev_reward_morale_spin.value = 0
	dun_ev_reward_wall_hp_spin.value = 0
	dun_ev_reward_wall_atk_spin.value = 0
	dun_ev_fatigue_delta_spin.value = 0
	dun_ev_drop_equip_check.button_pressed = false
	dun_ev_choice_update_button.disabled = true
	dun_ev_choice_remove_button.disabled = true


func _refresh_dun_choice_list() -> void:
	dun_ev_choice_list.clear()
	for i in range(_editing_dun_choices.size()):
		var ch: Dictionary = _editing_dun_choices[i]
		var line: String = "%d. %s (피로 %+d%s)" % [
			i + 1,
			str(ch.get("text", ch.get("label", "선택지"))),
			int(ch.get("fatigue_delta", 0)),
			", 장비드랍" if bool((ch.get("rewards", {}) as Dictionary).get("drop_random_equip", false)) else "",
		]
		dun_ev_choice_list.add_item(line)
	if _selected_dun_choice_idx >= 0 and _selected_dun_choice_idx < _editing_dun_choices.size():
		dun_ev_choice_list.select(_selected_dun_choice_idx)


func _on_dun_choice_selected(index: int) -> void:
	if index < 0 or index >= _editing_dun_choices.size():
		return
	_selected_dun_choice_idx = index
	var ch: Dictionary = _editing_dun_choices[index]
	var cost: Dictionary = ch.get("cost", {})
	var rewards: Dictionary = ch.get("rewards", {})
	dun_ev_choice_label_edit.text = str(ch.get("text", ch.get("label", "")))
	dun_ev_choice_result_edit.text = str(ch.get("result_text", ""))
	dun_ev_cost_gold_spin.value = int(cost.get("gold", 0))
	dun_ev_cost_food_spin.value = int(cost.get("food", 0))
	dun_ev_cost_mat_spin.value = int(cost.get("materials", 0))
	dun_ev_reward_gold_spin.value = int(rewards.get("gold", 0))
	dun_ev_reward_food_spin.value = int(rewards.get("food", 0))
	dun_ev_reward_mat_spin.value = int(rewards.get("materials", 0))
	dun_ev_reward_morale_spin.value = int(rewards.get("morale", 0))
	dun_ev_reward_wall_hp_spin.value = int(rewards.get("wall_hp", 0))
	dun_ev_reward_wall_atk_spin.value = int(rewards.get("wall_atk_bonus", 0))
	dun_ev_fatigue_delta_spin.value = int(ch.get("fatigue_delta", 0))
	dun_ev_drop_equip_check.button_pressed = bool(rewards.get("drop_random_equip", false))
	dun_ev_choice_update_button.disabled = false
	dun_ev_choice_remove_button.disabled = false


func _read_dun_choice_from_form() -> Dictionary:
	var cost: Dictionary = {}
	if int(dun_ev_cost_gold_spin.value) > 0:
		cost["gold"] = int(dun_ev_cost_gold_spin.value)
	if int(dun_ev_cost_food_spin.value) > 0:
		cost["food"] = int(dun_ev_cost_food_spin.value)
	if int(dun_ev_cost_mat_spin.value) > 0:
		cost["materials"] = int(dun_ev_cost_mat_spin.value)

	var rewards: Dictionary = {}
	if int(dun_ev_reward_gold_spin.value) != 0:
		rewards["gold"] = int(dun_ev_reward_gold_spin.value)
	if int(dun_ev_reward_food_spin.value) != 0:
		rewards["food"] = int(dun_ev_reward_food_spin.value)
	if int(dun_ev_reward_mat_spin.value) != 0:
		rewards["materials"] = int(dun_ev_reward_mat_spin.value)
	if int(dun_ev_reward_morale_spin.value) != 0:
		rewards["morale"] = int(dun_ev_reward_morale_spin.value)
	if int(dun_ev_reward_wall_hp_spin.value) > 0:
		rewards["wall_hp"] = int(dun_ev_reward_wall_hp_spin.value)
	if int(dun_ev_reward_wall_atk_spin.value) > 0:
		rewards["wall_atk_bonus"] = int(dun_ev_reward_wall_atk_spin.value)
	if dun_ev_drop_equip_check.button_pressed:
		rewards["drop_random_equip"] = true

	var lbl: String = dun_ev_choice_label_edit.text.strip_edges()
	if lbl.is_empty():
		lbl = "선택지"
	return {
		"text": lbl,
		"cost": cost,
		"rewards": rewards,
		"fatigue_delta": int(dun_ev_fatigue_delta_spin.value),
		"result_text": dun_ev_choice_result_edit.text.strip_edges(),
	}


func _on_dun_choice_add_pressed() -> void:
	_editing_dun_choices.append(_read_dun_choice_from_form())
	_selected_dun_choice_idx = _editing_dun_choices.size() - 1
	_refresh_dun_choice_list()
	dun_ev_choice_update_button.disabled = false
	dun_ev_choice_remove_button.disabled = false


func _on_dun_choice_update_pressed() -> void:
	if _selected_dun_choice_idx < 0 or _selected_dun_choice_idx >= _editing_dun_choices.size():
		return
	_editing_dun_choices[_selected_dun_choice_idx] = _read_dun_choice_from_form()
	_refresh_dun_choice_list()


func _on_dun_choice_remove_pressed() -> void:
	if _selected_dun_choice_idx < 0 or _selected_dun_choice_idx >= _editing_dun_choices.size():
		return
	_editing_dun_choices.remove_at(_selected_dun_choice_idx)
	_selected_dun_choice_idx = -1
	_refresh_dun_choice_list()
	_clear_dun_choice_inputs()


func _on_dun_ev_save_pressed() -> void:
	var title_str: String = dun_ev_title_edit.text.strip_edges()
	if title_str.is_empty():
		dun_ev_status_label.text = "오류: 던전 이벤트 제목을 입력해 주세요."
		return
	if _editing_dun_choices.is_empty():
		dun_ev_status_label.text = "오류: 최소 1개의 선택지를 [+ 선택지 추가]로 등록해 주세요."
		return

	var payload: Dictionary = {
		"title": title_str,
		"description": dun_ev_desc_edit.text.strip_edges(),
		"choices": _editing_dun_choices.duplicate(true),
	}
	var saved_id: String = DataManager.save_dungeon_event(payload, _selected_dun_ev_id)
	if saved_id.is_empty():
		dun_ev_status_label.text = "저장 실패: dungeon_events.json 쓰기 권한을 확인하세요."
		return
	_selected_dun_ev_id = saved_id
	_refresh_lists()
	dun_ev_id_label.text = "던전 이벤트 ID: %s (dungeon_events.json)" % saved_id
	dun_ev_delete_button.disabled = false
	dun_ev_status_label.text = "저장 완료: %s (%s)" % [DataManager.DUNGEON_EVENTS_FILE, saved_id]


func _on_dun_ev_delete_pressed() -> void:
	if _selected_dun_ev_id.is_empty():
		return
	var target_id: String = _selected_dun_ev_id
	if DataManager.delete_dungeon_event(target_id):
		_clear_dun_ev_form()
		dun_ev_status_label.text = "삭제 완료: %s" % target_id
	else:
		dun_ev_status_label.text = "삭제 실패: 이벤트를 찾을 수 없습니다."


# ==========================================
# 7. 던전·드랍 테이블 편집기 로직
# ==========================================
func _rebuild_dungeon_drop_checkboxes() -> void:
	var checked_ids: Array[String] = []
	for eq_id in _dungeon_drop_checkboxes:
		var cb: CheckBox = _dungeon_drop_checkboxes[eq_id]
		if is_instance_valid(cb) and cb.button_pressed:
			checked_ids.append(str(eq_id))

	for child in dungeon_drop_checks_vbox.get_children():
		child.queue_free()
	_dungeon_drop_checkboxes.clear()

	for eq in DataManager.equipments:
		var eq_id: String = str(eq.get("id", ""))
		var rarity: String = DataManager.normalize_rarity(eq.get("rarity", "N"))
		var named_tag: String = "★전용·" if not str(eq.get("exclusive_hero_id", "")).is_empty() else ""
		var cb := CheckBox.new()
		cb.text = "[%s%s] %s (%s)" % [named_tag, rarity, str(eq.get("name", eq_id)), eq_id]
		cb.button_pressed = checked_ids.has(eq_id)
		dungeon_drop_checks_vbox.add_child(cb)
		_dungeon_drop_checkboxes[eq_id] = cb


func _apply_dungeon_drop_checks(drop_ids: Array) -> void:
	for eq_id in _dungeon_drop_checkboxes:
		var cb: CheckBox = _dungeon_drop_checkboxes[eq_id]
		if is_instance_valid(cb):
			cb.button_pressed = drop_ids.has(eq_id)


func _on_dungeon_selected(index: int) -> void:
	if index < 0 or index >= DataManager.dungeons.size():
		return
	var d: Dictionary = DataManager.dungeons[index]
	_selected_dungeon_id = str(d.get("id", ""))
	dungeon_id_label.text = "던전 ID: %s (dungeons.json)" % _selected_dungeon_id
	dungeon_name_edit.text = str(d.get("name", ""))
	var dtype: String = str(d.get("dungeon_type", "FIELD_GRID"))
	var t_idx: int = DataManager.DUNGEON_TYPES.find(dtype)
	dungeon_type_option.select(maxi(0, t_idx))
	dungeon_width_spin.value = int(d.get("grid_width", 7))
	dungeon_height_spin.value = int(d.get("grid_height", 5))
	dungeon_depth_spin.value = int(d.get("depth", 5))
	dungeon_desc_edit.text = str(d.get("description", ""))
	_apply_dungeon_drop_checks(d.get("drop_equipment_ids", []))
	dungeon_delete_button.disabled = false
	dungeon_status_label.text = ""


func _on_dungeon_new_pressed() -> void:
	_clear_dungeon_form()
	dungeon_status_label.text = "새 던전 작성 모드입니다."


func _clear_dungeon_form() -> void:
	_selected_dungeon_id = ""
	dungeon_list.deselect_all()
	dungeon_id_label.text = "던전 ID: (새 던전으로 저장됨)"
	dungeon_name_edit.text = ""
	dungeon_type_option.select(0)
	dungeon_width_spin.value = 7
	dungeon_height_spin.value = 5
	dungeon_depth_spin.value = 5
	dungeon_desc_edit.text = ""
	_apply_dungeon_drop_checks([])
	dungeon_delete_button.disabled = true


func _on_dungeon_save_pressed() -> void:
	var d_name: String = dungeon_name_edit.text.strip_edges()
	if d_name.is_empty():
		dungeon_status_label.text = "오류: 던전 이름을 입력해 주세요."
		return
	var drop_ids: Array[String] = []
	for eq_id in _dungeon_drop_checkboxes:
		var cb: CheckBox = _dungeon_drop_checkboxes[eq_id]
		if is_instance_valid(cb) and cb.button_pressed:
			drop_ids.append(str(eq_id))

	var dtype: String = str(dungeon_type_option.get_item_metadata(dungeon_type_option.selected))
	var payload: Dictionary = {
		"name": d_name,
		"dungeon_type": dtype,
		"description": dungeon_desc_edit.text.strip_edges(),
		"grid_width": int(dungeon_width_spin.value),
		"grid_height": int(dungeon_height_spin.value),
		"depth": int(dungeon_depth_spin.value),
		"drop_equipment_ids": drop_ids,
	}
	var saved_id: String = DataManager.save_dungeon(payload, _selected_dungeon_id)
	if saved_id.is_empty():
		dungeon_status_label.text = "저장 실패: dungeons.json 쓰기 권한을 확인하세요."
		return
	_selected_dungeon_id = saved_id
	_refresh_lists()
	_apply_dungeon_drop_checks(drop_ids)
	dungeon_id_label.text = "던전 ID: %s (dungeons.json)" % saved_id
	dungeon_delete_button.disabled = false
	dungeon_status_label.text = "저장 완료: %s (%s, 드랍 장비 %d종)" % [DataManager.DUNGEONS_FILE, saved_id, drop_ids.size()]


func _on_dungeon_delete_pressed() -> void:
	if _selected_dungeon_id.is_empty():
		return
	var target_id: String = _selected_dungeon_id
	if DataManager.delete_dungeon(target_id):
		_clear_dungeon_form()
		dungeon_status_label.text = "삭제 완료: %s" % target_id
	else:
		dungeon_status_label.text = "삭제 실패: 던전을 찾을 수 없습니다."


# ==========================================
# 8. 적 유닛 편집기 로직 (data/enemies.json)
# ==========================================
func _rebuild_enemy_skill_checkboxes() -> void:
	var p_checked: Array[String] = []
	for sid in _enemy_passive_checkboxes:
		var cb: CheckBox = _enemy_passive_checkboxes[sid]
		if is_instance_valid(cb) and cb.button_pressed:
			p_checked.append(str(sid))
	var a_checked: Array[String] = []
	for sid in _enemy_active_checkboxes:
		var cb: CheckBox = _enemy_active_checkboxes[sid]
		if is_instance_valid(cb) and cb.button_pressed:
			a_checked.append(str(sid))

	for child in enemy_passive_checks_vbox.get_children():
		child.queue_free()
	for child in enemy_active_checks_vbox.get_children():
		child.queue_free()
	_enemy_passive_checkboxes.clear()
	_enemy_active_checkboxes.clear()

	for s in DataManager.skills:
		var sid: String = str(s.get("id", ""))
		var label_txt: String = "%s (%s)" % [str(s.get("name", sid)), sid]

		var cb_p := CheckBox.new()
		cb_p.text = label_txt
		cb_p.button_pressed = p_checked.has(sid)
		enemy_passive_checks_vbox.add_child(cb_p)
		_enemy_passive_checkboxes[sid] = cb_p

		var cb_a := CheckBox.new()
		cb_a.text = label_txt
		cb_a.button_pressed = a_checked.has(sid)
		enemy_active_checks_vbox.add_child(cb_a)
		_enemy_active_checkboxes[sid] = cb_a


func _apply_enemy_skill_checks(passive_ids: Array, active_ids: Array) -> void:
	for sid in _enemy_passive_checkboxes:
		var cb: CheckBox = _enemy_passive_checkboxes[sid]
		if is_instance_valid(cb):
			cb.button_pressed = passive_ids.has(sid)
	for sid in _enemy_active_checkboxes:
		var cb: CheckBox = _enemy_active_checkboxes[sid]
		if is_instance_valid(cb):
			cb.button_pressed = active_ids.has(sid)


func _on_enemy_selected(index: int) -> void:
	if index < 0 or index >= DataManager.enemies.size():
		return
	var en: Dictionary = DataManager.enemies[index]
	_selected_enemy_id = str(en.get("id", ""))
	enemy_id_label.text = "적 ID: %s (enemies.json)" % _selected_enemy_id
	enemy_name_edit.text = str(en.get("name", ""))
	_populate_element_dropdown(enemy_element_option, str(en.get("element", "FIRE")))
	var cat_val: String = str(en.get("category", "MONSTER"))
	if enemy_category_option != null:
		var c_idx: int = DataManager.ENEMY_CATEGORIES.find(cat_val)
		enemy_category_option.select(maxi(0, c_idx))
	_populate_enemy_archetype_options(cat_val, str(en.get("archetype", "SWARMER")))
	var t_idx: int = DataManager.ENEMY_TYPES.find(str(en.get("enemy_type", "NORMAL")))
	enemy_type_option.select(maxi(0, t_idx))
	enemy_hp_spin.value = int(en.get("max_hp", 50))
	enemy_atk_spin.value = int(en.get("atk", 12))
	enemy_def_spin.value = int(en.get("def", 6))
	enemy_spd_spin.value = int(en.get("speed", 12))
	var s_arr: PackedStringArray = []
	for sn in en.get("allowed_seasons", ["ALL"]):
		s_arr.append(str(sn))
	enemy_seasons_edit.text = ", ".join(s_arr)
	enemy_desc_edit.text = str(en.get("description", ""))
	_apply_enemy_skill_checks(en.get("passive_skill_ids", []), en.get("active_skill_ids", []))
	enemy_delete_button.disabled = false
	enemy_status_label.text = ""


func _on_enemy_new_pressed() -> void:
	_clear_enemy_form()
	enemy_status_label.text = "새 적 유닛 작성 모드입니다."


func _clear_enemy_form() -> void:
	_selected_enemy_id = ""
	enemy_list.deselect_all()
	enemy_id_label.text = "적 ID: (새 적 유닛으로 저장됨)"
	enemy_name_edit.text = ""
	_populate_element_dropdown(enemy_element_option, "FIRE")
	if enemy_category_option != null:
		enemy_category_option.select(0)
	_populate_enemy_archetype_options(DataManager.ENEMY_CATEGORIES[0])
	enemy_type_option.select(0)
	enemy_hp_spin.value = 60
	enemy_atk_spin.value = 14
	enemy_def_spin.value = 8
	enemy_spd_spin.value = 12
	enemy_seasons_edit.text = "ALL"
	enemy_desc_edit.text = ""
	_apply_enemy_skill_checks([], [])
	enemy_delete_button.disabled = true


func _on_enemy_save_pressed() -> void:
	var e_name: String = enemy_name_edit.text.strip_edges()
	if e_name.is_empty():
		enemy_status_label.text = "오류: 적 이름을 입력해 주세요."
		return
	var p_ids: Array[String] = []
	for sid in _enemy_passive_checkboxes:
		var cb: CheckBox = _enemy_passive_checkboxes[sid]
		if is_instance_valid(cb) and cb.button_pressed:
			p_ids.append(str(sid))
	var a_ids: Array[String] = []
	for sid in _enemy_active_checkboxes:
		var cb: CheckBox = _enemy_active_checkboxes[sid]
		if is_instance_valid(cb) and cb.button_pressed:
			a_ids.append(str(sid))
	var seasons: Array[String] = []
	for tok in enemy_seasons_edit.text.split(",", false):
		var clean_s: String = tok.strip_edges().to_upper()
		if not clean_s.is_empty():
			seasons.append(clean_s)
	if seasons.is_empty():
		seasons.append("ALL")

	var cat_id: String = str(enemy_category_option.get_item_metadata(maxi(0, enemy_category_option.selected))) if enemy_category_option != null and enemy_category_option.item_count > 0 else "MONSTER"
	var arch_id: String = str(enemy_archetype_option.get_item_metadata(maxi(0, enemy_archetype_option.selected))) if enemy_archetype_option != null and enemy_archetype_option.item_count > 0 else "SWARMER"

	var payload: Dictionary = {
		"name": e_name,
		"description": enemy_desc_edit.text.strip_edges(),
		"category": cat_id,
		"archetype": arch_id,
		"element": _get_selected_dropdown_skill_id(enemy_element_option),
		"enemy_type": enemy_type_option.get_item_text(enemy_type_option.selected),
		"max_hp": int(enemy_hp_spin.value),
		"atk": int(enemy_atk_spin.value),
		"def": int(enemy_def_spin.value),
		"speed": int(enemy_spd_spin.value),
		"passive_skill_ids": p_ids,
		"active_skill_ids": a_ids,
		"allowed_seasons": seasons,
	}
	var saved_id: String = DataManager.save_enemy(payload, _selected_enemy_id)
	if saved_id.is_empty():
		enemy_status_label.text = "저장 실패: enemies.json 쓰기 권한을 확인하세요."
		return
	_selected_enemy_id = saved_id
	_refresh_lists()
	_apply_enemy_skill_checks(p_ids, a_ids)
	enemy_id_label.text = "적 ID: %s (enemies.json)" % saved_id
	enemy_delete_button.disabled = false
	enemy_status_label.text = "저장 완료: %s (%s)" % [DataManager.ENEMIES_FILE, saved_id]


func _populate_enemy_archetype_options(category: String, select_arch: String = "") -> void:
	if enemy_archetype_option == null:
		return
	enemy_archetype_option.clear()
	var archs: Array = DataManager.get_archetypes_for_enemy_category(category)
	var sel: int = 0
	for i in range(archs.size()):
		var aid: String = str(archs[i])
		enemy_archetype_option.add_item(str(DataManager.ENEMY_ARCHETYPE_LABELS.get(aid, aid)))
		enemy_archetype_option.set_item_metadata(i, aid)
		if not select_arch.is_empty() and aid == select_arch:
			sel = i
	enemy_archetype_option.select(sel)


func _on_enemy_category_changed(index: int) -> void:
	if enemy_category_option == null or index < 0 or index >= enemy_category_option.item_count:
		return
	var cat_id: String = str(enemy_category_option.get_item_metadata(index))
	_populate_enemy_archetype_options(cat_id)


func _on_enemy_palette_swap_pressed() -> void:
	if _selected_enemy_id.is_empty():
		enemy_status_label.text = "먼저 왼쪽 목록에서 복제할 원본 적을 선택하세요."
		return
	var target_elem: String = _get_selected_dropdown_skill_id(enemy_element_option)
	var variant: Dictionary = DataManager.create_palette_swapped_enemy(_selected_enemy_id, target_elem, true)
	if variant.is_empty():
		enemy_status_label.text = "팔레트 스왑 변종 생성 실패."
		return
	_selected_enemy_id = str(variant["id"])
	_refresh_lists()
	enemy_id_label.text = "적 ID: %s (enemies.json)" % _selected_enemy_id
	enemy_name_edit.text = str(variant.get("name", ""))
	_apply_enemy_skill_checks(variant.get("passive_skill_ids", []), variant.get("active_skill_ids", []))
	enemy_status_label.text = "★ 팔레트 스왑 변종 생성·저장 완료: %s (%s)" % [variant["name"], _selected_enemy_id]


func _on_enemy_delete_pressed() -> void:
	if _selected_enemy_id.is_empty():
		return
	var target_id: String = _selected_enemy_id
	if DataManager.delete_enemy(target_id):
		_clear_enemy_form()
		enemy_status_label.text = "삭제 완료: %s" % target_id
	else:
		enemy_status_label.text = "삭제 실패: 적 유닛을 찾을 수 없습니다."


# ==========================================
# 9. 커스텀 타워 편집기 로직 (data/towers.json)
# ==========================================
func _on_tower_selected(index: int) -> void:
	if index < 0 or index >= DataManager.towers.size():
		return
	var tw: Dictionary = DataManager.towers[index]
	_selected_tower_id = str(tw.get("id", ""))
	tower_id_label.text = "타워 ID: %s (towers.json)" % _selected_tower_id
	tower_name_edit.text = str(tw.get("name", ""))
	_populate_element_dropdown(tower_element_option, str(tw.get("element", "FIRE")))
	var sc_idx: int = DataManager.TOWER_SCOPES.find(str(tw.get("target_scope", "SINGLE_FRONT")))
	tower_scope_option.select(maxi(0, sc_idx))
	tower_atk_spin.value = int(tw.get("atk", 20))
	tower_interval_spin.value = float(tw.get("attack_interval", 1.5))
	_populate_skill_dropdown(tower_on_hit_option, str(tw.get("on_hit_effect_id", "")))
	var cost: Dictionary = tw.get("build_cost", {})
	tower_cost_mat_spin.value = int(cost.get("materials", 20))
	tower_cost_gold_spin.value = int(cost.get("gold", 35))
	tower_desc_edit.text = str(tw.get("description", ""))
	tower_delete_button.disabled = false
	tower_status_label.text = ""


func _on_tower_new_pressed() -> void:
	_clear_tower_form()
	tower_status_label.text = "새 커스텀 타워 작성 모드입니다."


func _clear_tower_form() -> void:
	_selected_tower_id = ""
	tower_list.deselect_all()
	tower_id_label.text = "타워 ID: (새 타워로 저장됨)"
	tower_name_edit.text = ""
	_populate_element_dropdown(tower_element_option, "FIRE")
	tower_scope_option.select(0)
	tower_atk_spin.value = 25
	tower_interval_spin.value = 1.5
	_populate_skill_dropdown(tower_on_hit_option, "")
	tower_cost_mat_spin.value = 20
	tower_cost_gold_spin.value = 35
	tower_desc_edit.text = ""
	tower_delete_button.disabled = true


func _on_tower_save_pressed() -> void:
	var t_name: String = tower_name_edit.text.strip_edges()
	if t_name.is_empty():
		tower_status_label.text = "오류: 타워 이름을 입력해 주세요."
		return
	var payload: Dictionary = {
		"name": t_name,
		"description": tower_desc_edit.text.strip_edges(),
		"element": _get_selected_dropdown_skill_id(tower_element_option),
		"target_scope": str(tower_scope_option.get_item_metadata(tower_scope_option.selected)),
		"atk": int(tower_atk_spin.value),
		"attack_interval": tower_interval_spin.value,
		"on_hit_effect_id": _get_selected_dropdown_skill_id(tower_on_hit_option),
		"build_cost": {
			"materials": int(tower_cost_mat_spin.value),
			"gold": int(tower_cost_gold_spin.value),
		},
	}
	var saved_id: String = DataManager.save_tower(payload, _selected_tower_id)
	if saved_id.is_empty():
		tower_status_label.text = "저장 실패: towers.json 쓰기 권한을 확인하세요."
		return
	_selected_tower_id = saved_id
	_refresh_lists()
	tower_id_label.text = "타워 ID: %s (towers.json)" % saved_id
	tower_delete_button.disabled = false
	tower_status_label.text = "저장 완료: %s (%s)" % [DataManager.TOWERS_FILE, saved_id]


func _on_tower_delete_pressed() -> void:
	if _selected_tower_id.is_empty():
		return
	var target_id: String = _selected_tower_id
	if DataManager.delete_tower(target_id):
		_clear_tower_form()
		tower_status_label.text = "삭제 완료: %s" % target_id
	else:
		tower_status_label.text = "삭제 실패: 타워를 찾을 수 없습니다."


# ==========================================
# 10. 소비 아이템 편집기 로직 (data/items.json)
# ==========================================
func _on_item_selected(index: int) -> void:
	if index < 0 or index >= DataManager.items.size():
		return
	var it: Dictionary = DataManager.items[index]
	_selected_item_id = str(it.get("id", ""))
	item_id_label.text = "아이템 ID: %s (items.json)" % _selected_item_id
	item_name_edit.text = str(it.get("name", ""))
	var r_idx: int = DataManager.RARITIES.find(DataManager.normalize_rarity(it.get("rarity", "N")))
	item_rarity_option.select(maxi(0, r_idx))
	var t_idx: int = DataManager.ITEM_TYPES.find(str(it.get("item_type", "HEAL_HP")))
	item_type_option.select(maxi(0, t_idx))
	var s_idx: int = DataManager.ITEM_SCOPES.find(str(it.get("target_scope", "SINGLE_ALLY")))
	item_scope_option.select(maxi(0, s_idx))
	item_power_spin.value = float(it.get("power", 45.0))
	item_duration_spin.value = float(it.get("duration", 1))
	var cost: Dictionary = it.get("buy_cost", {"gold": 15})
	item_cost_gold_spin.value = float(cost.get("gold", 15))
	item_combat_check.button_pressed = bool(it.get("usable_in_combat", true))
	item_dungeon_check.button_pressed = bool(it.get("usable_in_dungeon", false))
	item_desc_edit.text = str(it.get("description", ""))
	item_delete_button.disabled = false
	item_status_label.text = ""


func _on_item_new_pressed() -> void:
	_clear_item_form()
	item_status_label.text = "새 아이템 작성 모드입니다."


func _clear_item_form() -> void:
	_selected_item_id = ""
	item_list.deselect_all()
	item_id_label.text = "아이템 ID: (새 아이템으로 저장됨)"
	item_name_edit.text = ""
	item_rarity_option.select(0)
	item_type_option.select(0)
	item_scope_option.select(0)
	item_power_spin.value = 45.0
	item_duration_spin.value = 1.0
	item_cost_gold_spin.value = 15.0
	item_combat_check.button_pressed = true
	item_dungeon_check.button_pressed = true
	item_desc_edit.text = ""
	item_delete_button.disabled = true


func _on_item_save_pressed() -> void:
	var i_name: String = item_name_edit.text.strip_edges()
	if i_name.is_empty():
		item_status_label.text = "오류: 아이템 이름을 입력하세요."
		return
	var payload: Dictionary = {
		"name": i_name,
		"description": item_desc_edit.text.strip_edges(),
		"rarity": item_rarity_option.get_item_text(item_rarity_option.selected),
		"item_type": str(item_type_option.get_item_metadata(item_type_option.selected)),
		"target_scope": str(item_scope_option.get_item_metadata(item_scope_option.selected)),
		"power": item_power_spin.value,
		"duration": int(item_duration_spin.value),
		"usable_in_combat": item_combat_check.button_pressed,
		"usable_in_dungeon": item_dungeon_check.button_pressed,
		"buy_cost": {"gold": int(item_cost_gold_spin.value)},
	}
	var saved_id: String = DataManager.save_item(payload, _selected_item_id)
	if saved_id.is_empty():
		item_status_label.text = "저장 실패: items.json 쓰기 권한을 확인하세요."
		return
	_selected_item_id = saved_id
	_refresh_lists()
	item_id_label.text = "아이템 ID: %s (items.json)" % saved_id
	item_delete_button.disabled = false
	item_status_label.text = "저장 완료: %s (%s)" % [DataManager.ITEMS_FILE, saved_id]


func _on_item_delete_pressed() -> void:
	if _selected_item_id.is_empty():
		return
	var target_id: String = _selected_item_id
	if DataManager.delete_item(target_id):
		_clear_item_form()
		item_status_label.text = "삭제 완료: %s" % target_id
	else:
		item_status_label.text = "삭제 실패: 아이템을 찾을 수 없습니다."
