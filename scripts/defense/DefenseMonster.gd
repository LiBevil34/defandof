class_name DefenseMonster
extends Area2D
## 오브젝트 풀링으로 재사용되는 디펜스 몬스터 (Area2D 기반)

signal died(monster: DefenseMonster)

var monster_id: int = 0
var is_active: bool = false
var max_hp: int = 60
var hp: int = 60
var move_speed: float = 85.0
var atk: int = 8
var def: int = 5
var element: String = "FIRE"
var category: String = "MONSTER"
var archetype: String = "SWARMER"
var is_summoned_spawn: bool = false
var attack_interval: float = 1.0
var attack_cooldown: float = 0.0
var support_aura_cd: float = 2.5

var lane_index: int = 0
var reached_wall: bool = false
var blocked_by_slot: Dictionary = {}
var combat_state: Dictionary = {}

var _body_rect: ColorRect
var _sprite: Sprite2D
var _hp_bg: ColorRect
var _hp_fill: ColorRect
var _collision_shape: CollisionShape2D


func _init() -> void:
	collision_layer = 2
	collision_mask = 1
	monitoring = false
	monitorable = false
	visible = false
	set_physics_process(false)

	_collision_shape = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36, 36)
	_collision_shape.shape = shape
	add_child(_collision_shape)

	_body_rect = ColorRect.new()
	_body_rect.position = Vector2(-18, -18)
	_body_rect.size = Vector2(36, 36)
	_body_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_rect.color = Color(0.85, 0.25, 0.28, 0.35)
	add_child(_body_rect)

	_sprite = Sprite2D.new()
	add_child(_sprite)

	_hp_bg = ColorRect.new()
	_hp_bg.position = Vector2(-19, -27)
	_hp_bg.size = Vector2(38, 6)
	_hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bg.color = Color(0.1, 0.1, 0.12, 1.0)
	add_child(_hp_bg)

	_hp_fill = ColorRect.new()
	_hp_fill.position = Vector2.ZERO
	_hp_fill.size = Vector2(38, 6)
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_fill.color = Color(0.95, 0.35, 0.3, 1.0)
	_hp_bg.add_child(_hp_fill)


## 풀에서 꺼낼 때 상태와 좌표를 초기화합니다.
func activate(
	id: int,
	spawn_pos: Vector2,
	lane: int,
	p_max_hp: int,
	p_speed: float,
	p_atk: int,
	body_color: Color,
	p_def: int = 5,
	p_element: String = "FIRE",
	p_enemy_id: String = "",
	p_enemy_type: String = "NORMAL",
	p_sprite_path: String = "",
	p_category: String = "MONSTER",
	p_archetype: String = "SWARMER",
	p_tint_color: String = "",
	p_palette_swapped: bool = false,
	p_is_summoned: bool = false
) -> void:
	monster_id = id
	lane_index = lane
	max_hp = p_max_hp
	hp = p_max_hp
	move_speed = p_speed
	atk = p_atk
	def = p_def
	element = p_element
	category = p_category
	archetype = p_archetype
	is_summoned_spawn = p_is_summoned
	attack_cooldown = 0.0
	support_aura_cd = 2.0
	reached_wall = false
	blocked_by_slot = {}
	combat_state = {
		"name": "분열 유충#%d" % id if p_is_summoned else "몬스터#%d" % id,
		"max_hp": p_max_hp,
		"hp": p_max_hp,
		"atk": p_atk,
		"def": p_def,
		"speed": p_speed,
		"element": p_element,
		"category": p_category,
		"archetype": p_archetype,
		"status_effects": [],
		"shield": 0,
		"passive_bonuses": {},
	}
	var is_boss_or_elite: bool = p_enemy_type in ["BOSS", "ELITE", "SIEGE"]
	var target_px: float = 28.0 if p_is_summoned else (52.0 if p_enemy_type == "BOSS" else (44.0 if is_boss_or_elite else 38.0))
	var half_px: float = target_px * 0.5
	_body_rect.position = Vector2(-half_px, -half_px)
	_body_rect.size = Vector2(target_px, target_px)
	_body_rect.color = Color(body_color.r, body_color.g, body_color.b, 0.28)
	_hp_bg.position = Vector2(-half_px, -half_px - 9.0)
	_hp_bg.size = Vector2(target_px, 6.0)

	var sprite_tex: Texture2D = AssetManager.get_enemy_sprite(p_enemy_id, p_enemy_type, p_sprite_path)
	if sprite_tex != null:
		_sprite.texture = sprite_tex
		var tex_sz: Vector2 = sprite_tex.get_size()
		var max_dim: float = maxf(1.0, maxf(tex_sz.x, tex_sz.y))
		var sc: float = (target_px + 4.0) / max_dim
		_sprite.scale = Vector2(sc, sc)
		var has_custom: bool = (
			AssetManager.get_texture("enemies", p_enemy_id, p_sprite_path) != null
			or AssetManager.get_texture("enemies", p_enemy_type.to_lower()) != null
		)
		if p_palette_swapped and not p_tint_color.is_empty():
			_sprite.modulate = Color.from_string(p_tint_color, body_color).lightened(0.32)
		else:
			_sprite.modulate = Color.WHITE if has_custom else body_color.lightened(0.35)
		_sprite.visible = true
	else:
		_sprite.visible = false
		_body_rect.color = body_color
	_update_hp_bar()

	position = spawn_pos
	is_active = true
	visible = true
	monitoring = true
	monitorable = true
	set_physics_process(true)


## 풀로 반환하며 물리/충돌/상태를 비활성화합니다.
func deactivate() -> void:
	is_active = false
	reached_wall = false
	blocked_by_slot = {}
	combat_state = {}
	visible = false
	monitoring = false
	monitorable = false
	set_physics_process(false)
	position = Vector2(-9999.0, -9999.0)


func take_damage(amount: int) -> void:
	if not is_active or hp <= 0:
		return
	StatusEffectManager.apply_damage_with_shield(combat_state, amount)
	sync_hp_from_combat_state()


func sync_hp_from_combat_state() -> void:
	hp = int(combat_state.get("hp", 0))
	_update_hp_bar()
	if hp <= 0 and is_active:
		died.emit(self)


func _update_hp_bar() -> void:
	var ratio: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_hp_fill.size.x = _hp_bg.size.x * ratio
