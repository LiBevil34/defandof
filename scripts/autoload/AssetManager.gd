extends Node
## 전역 비주얼 테마, 에셋 자동 탐색·캐싱, 프로시저럴 SVG/배경 폴백 매니저 (Autoload: AssetManager)
## - res://assets/... 폴더에 실제 PNG/WebP/SVG 에셋을 배치하면 자동으로 우선 적용됩니다.
## - 에셋이 없는 항목은 깔끔한 벡터 SVG 아이콘/그라데이션 배경/레어도 프레임으로 자동 렌더링됩니다.

const ASSET_ROOT: String = "res://assets"
const SUPPORTED_EXTS: PackedStringArray = ["png", "webp", "svg", "jpg", "jpeg"]

# --- 다크 시타델 판타지 컬러 팔레트 ---
const COL_BG_DEEP := Color(0.06, 0.07, 0.11, 1.0)
const COL_SURFACE := Color(0.10, 0.12, 0.18, 0.96)
const COL_SURFACE_ALT := Color(0.13, 0.16, 0.23, 0.96)
const COL_SURFACE_DARK := Color(0.07, 0.09, 0.13, 0.98)
const COL_BORDER := Color(0.28, 0.33, 0.45, 0.92)
const COL_BORDER_GOLD := Color(0.78, 0.62, 0.28, 0.95)
const COL_BTN_NORMAL := Color(0.15, 0.19, 0.28, 1.0)
const COL_BTN_HOVER := Color(0.21, 0.27, 0.39, 1.0)
const COL_BTN_PRESSED := Color(0.11, 0.14, 0.21, 1.0)
const COL_BTN_DISABLED := Color(0.10, 0.12, 0.16, 0.72)
const COL_TEXT_PRIMARY := Color(0.93, 0.94, 0.97, 1.0)
const COL_TEXT_MUTED := Color(0.68, 0.73, 0.82, 1.0)
const COL_TEXT_GOLD := Color(0.98, 0.84, 0.44, 1.0)

var _texture_cache: Dictionary = {} # key -> Texture2D (or null)
var _svg_cache: Dictionary = {} # key -> ImageTexture
var _backdrop_cache: Dictionary = {} # key -> ImageTexture
var _game_theme: Theme = null


func _ready() -> void:
	_game_theme = build_game_theme()
	if get_tree() != null and get_tree().root != null:
		get_tree().root.theme = _game_theme


func get_game_theme() -> Theme:
	if _game_theme == null:
		_game_theme = build_game_theme()
	return _game_theme


# ==========================================
# 전역 Dark Citadel UI 테마 생성
# ==========================================
func build_game_theme() -> Theme:
	var t := Theme.new()

	# 기본 텍스트 색상
	t.set_color("font_color", "Label", COL_TEXT_PRIMARY)
	t.set_color("font_shadow_color", "Label", Color(0.0, 0.0, 0.0, 0.45))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)

	# PanelContainer / Panel
	var panel_sb := make_panel_style(COL_SURFACE, COL_BORDER, 8, 1, 0)
	panel_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	panel_sb.shadow_size = 6
	t.set_stylebox("panel", "PanelContainer", panel_sb)
	t.set_stylebox("panel", "Panel", make_panel_style(COL_SURFACE_ALT, COL_BORDER, 6, 1, 0))

	# Button
	var btn_norm := make_button_style(COL_BTN_NORMAL, COL_BORDER)
	var btn_hover := make_button_style(COL_BTN_HOVER, COL_BORDER_GOLD)
	var btn_press := make_button_style(COL_BTN_PRESSED, COL_BORDER_GOLD)
	var btn_dis := make_button_style(COL_BTN_DISABLED, Color(0.20, 0.23, 0.30, 0.55))
	t.set_stylebox("normal", "Button", btn_norm)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", btn_press)
	t.set_stylebox("focus", "Button", btn_hover)
	t.set_stylebox("disabled", "Button", btn_dis)
	t.set_color("font_color", "Button", COL_TEXT_PRIMARY)
	t.set_color("font_hover_color", "Button", Color(1.0, 0.96, 0.85, 1.0))
	t.set_color("font_pressed_color", "Button", COL_TEXT_GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.52, 0.56, 0.64, 0.72))

	# OptionButton / CheckButton
	t.set_stylebox("normal", "OptionButton", btn_norm)
	t.set_stylebox("hover", "OptionButton", btn_hover)
	t.set_stylebox("pressed", "OptionButton", btn_press)
	t.set_stylebox("disabled", "OptionButton", btn_dis)

	# TabContainer
	var tab_panel := make_panel_style(Color(0.09, 0.11, 0.16, 0.96), COL_BORDER, 8, 1, 10)
	var tab_sel := make_panel_style(Color(0.18, 0.23, 0.35, 1.0), COL_BORDER_GOLD, 6, 2, 0)
	tab_sel.content_margin_left = 16
	tab_sel.content_margin_right = 16
	tab_sel.content_margin_top = 7
	tab_sel.content_margin_bottom = 7
	tab_sel.corner_radius_bottom_left = 0
	tab_sel.corner_radius_bottom_right = 0
	var tab_unsel := make_panel_style(Color(0.11, 0.14, 0.21, 0.9), COL_BORDER, 6, 1, 0)
	tab_unsel.content_margin_left = 14
	tab_unsel.content_margin_right = 14
	tab_unsel.content_margin_top = 6
	tab_unsel.content_margin_bottom = 6
	tab_unsel.corner_radius_bottom_left = 0
	tab_unsel.corner_radius_bottom_right = 0
	t.set_stylebox("panel", "TabContainer", tab_panel)
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_hovered", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", tab_unsel)
	t.set_color("font_selected_color", "TabContainer", COL_TEXT_GOLD)
	t.set_color("font_unselected_color", "TabContainer", COL_TEXT_MUTED)
	t.set_color("font_hovered_color", "TabContainer", COL_TEXT_PRIMARY)

	# ItemList
	var list_bg := make_panel_style(COL_SURFACE_DARK, COL_BORDER, 6, 1, 6)
	var list_sel := make_panel_style(Color(0.22, 0.31, 0.48, 0.95), COL_BORDER_GOLD, 4, 1, 4)
	t.set_stylebox("panel", "ItemList", list_bg)
	t.set_stylebox("selected", "ItemList", list_sel)
	t.set_stylebox("selected_focus", "ItemList", list_sel)
	t.set_color("font_color", "ItemList", COL_TEXT_PRIMARY)
	t.set_color("font_selected_color", "ItemList", Color(1.0, 0.96, 0.85, 1.0))

	# LineEdit / TextEdit / PopupMenu
	var input_bg := make_panel_style(COL_SURFACE_DARK, COL_BORDER, 5, 1, 6)
	var input_focus := make_panel_style(COL_SURFACE_DARK, COL_BORDER_GOLD, 5, 1, 6)
	t.set_stylebox("normal", "LineEdit", input_bg)
	t.set_stylebox("focus", "LineEdit", input_focus)
	t.set_stylebox("normal", "TextEdit", input_bg)
	t.set_stylebox("focus", "TextEdit", input_focus)
	t.set_stylebox("panel", "PopupMenu", make_panel_style(COL_SURFACE, COL_BORDER_GOLD, 6, 1, 6))
	t.set_stylebox("hover", "PopupMenu", list_sel)

	# ProgressBar
	t.set_stylebox("background", "ProgressBar", make_panel_style(Color(0.06, 0.07, 0.11, 1.0), COL_BORDER, 5, 1, 0))
	t.set_stylebox("fill", "ProgressBar", make_panel_style(Color(0.24, 0.72, 0.48, 1.0), Color(0.45, 0.92, 0.68, 0.7), 4, 1, 0))

	# HSeparator / VSeparator
	var hsep := StyleBoxLine.new()
	hsep.color = Color(0.32, 0.38, 0.50, 0.55)
	hsep.thickness = 1
	t.set_stylebox("separator", "HSeparator", hsep)
	var vsep := StyleBoxLine.new()
	vsep.vertical = true
	vsep.color = Color(0.32, 0.38, 0.50, 0.55)
	vsep.thickness = 1
	t.set_stylebox("separator", "VSeparator", vsep)

	return t


func make_panel_style(
	bg_color: Color,
	border_color: Color = COL_BORDER,
	radius: int = 6,
	border_w: int = 1,
	padding: int = 0
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	if padding > 0:
		sb.set_content_margin_all(padding)
	return sb


func make_button_style(bg_color: Color, border_color: Color, radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


# ==========================================
# 에셋 자동 탐색 (res://assets/... 우선 로드 + 캐시)
# ==========================================
func get_texture(subdir: String, asset_id: String, explicit_path: String = "") -> Texture2D:
	var clean_explicit: String = explicit_path.strip_edges()
	if not clean_explicit.is_empty():
		var exp_key: String = "path:" + clean_explicit
		if _texture_cache.has(exp_key):
			return _texture_cache[exp_key] as Texture2D
		if ResourceLoader.exists(clean_explicit):
			var loaded: Resource = ResourceLoader.load(clean_explicit)
			if loaded is Texture2D:
				_texture_cache[exp_key] = loaded
				return loaded as Texture2D
		_texture_cache[exp_key] = null

	var clean_id: String = asset_id.strip_edges()
	if clean_id.is_empty():
		return null

	var cache_key: String = subdir + "/" + clean_id
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key] as Texture2D

	for ext in SUPPORTED_EXTS:
		var candidate: String = "%s/%s/%s.%s" % [ASSET_ROOT, subdir, clean_id, ext]
		if ResourceLoader.exists(candidate):
			var res: Resource = ResourceLoader.load(candidate)
			if res is Texture2D:
				_texture_cache[cache_key] = res
				return res as Texture2D

	_texture_cache[cache_key] = null
	return null


func clear_asset_cache() -> void:
	_texture_cache.clear()


func get_hero_portrait(hero: Dictionary) -> Texture2D:
	var hid: String = str(hero.get("id", hero.get("hero_id", ""))).strip_edges()
	var explicit_p: String = str(hero.get("portrait_path", "")).strip_edges()
	var tex: Texture2D = get_texture("heroes/portraits", hid, explicit_p)
	if tex != null:
		return tex
	tex = get_texture("heroes/sprites", hid, str(hero.get("sprite_path", "")))
	if tex != null:
		return tex
	return get_job_emblem_texture(str(hero.get("job_class", hero.get("role", "근접딜러"))))


func get_hero_sprite(hero: Dictionary) -> Texture2D:
	var hid: String = str(hero.get("id", hero.get("hero_id", ""))).strip_edges()
	var explicit_s: String = str(hero.get("sprite_path", "")).strip_edges()
	var tex: Texture2D = get_texture("heroes/sprites", hid, explicit_s)
	if tex != null:
		return tex
	tex = get_texture("heroes/portraits", hid, str(hero.get("portrait_path", "")))
	if tex != null:
		return tex
	return get_job_emblem_texture(str(hero.get("job_class", hero.get("role", "근접딜러"))))


func get_enemy_sprite(enemy_id: String, enemy_type: String = "NORMAL", explicit_path: String = "") -> Texture2D:
	var tex: Texture2D = get_texture("enemies", enemy_id, explicit_path)
	if tex != null:
		return tex
	var type_key: String = enemy_type.strip_edges().to_lower()
	if not type_key.is_empty():
		tex = get_texture("enemies", type_key)
		if tex != null:
			return tex
	return get_enemy_emblem_texture(enemy_type)


func get_equipment_icon(equip: Dictionary) -> Texture2D:
	var eq_id: String = str(equip.get("id", "")).strip_edges()
	var tex: Texture2D = get_texture("equipments", eq_id, str(equip.get("icon_path", "")))
	if tex != null:
		return tex
	return get_slot_emblem_texture(str(equip.get("slot_type", "WEAPON")))


func get_item_icon(item: Dictionary) -> Texture2D:
	var item_id: String = str(item.get("id", "")).strip_edges()
	var tex: Texture2D = get_texture("items", item_id, str(item.get("icon_path", "")))
	if tex != null:
		return tex
	return get_item_emblem_texture(str(item.get("item_type", "HEAL_HP")))


func get_tower_sprite(tower_id: String, explicit_path: String = "") -> Texture2D:
	var tex: Texture2D = get_texture("towers", tower_id, explicit_path)
	if tex != null:
		return tex
	return get_tower_emblem_texture(tower_id == "base_tower")


func get_tile_icon(tile_key: String) -> Texture2D:
	var tex: Texture2D = get_texture("tiles", tile_key)
	if tex != null:
		return tex
	return get_tile_emblem_texture(tile_key)


func get_element_icon(element_id: String) -> Texture2D:
	var key: String = element_id.strip_edges().to_lower()
	var tex: Texture2D = get_texture("elements", key)
	if tex != null:
		return tex
	return get_element_emblem_texture(element_id)


# ==========================================
# 배경 레이어 / 그라데이션 폴백
# ==========================================
func apply_backdrop(
	target_bg: Control,
	bg_key: String,
	top_color: Color,
	bottom_color: Color,
	grid_alpha: float = 0.045
) -> void:
	if target_bg == null or not is_instance_valid(target_bg):
		return

	var tex: Texture2D = get_texture("ui", bg_key)
	if tex == null:
		tex = _get_or_build_procedural_backdrop(bg_key, top_color, bottom_color, grid_alpha)

	if target_bg is TextureRect:
		var tr := target_bg as TextureRect
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		return

	# 기존 ColorRect 위에 TextureRect 레이어를 안전하게 삽입
	var existing := target_bg.get_node_or_null("BackdropTexture")
	var tex_rect: TextureRect
	if existing is TextureRect:
		tex_rect = existing as TextureRect
	else:
		tex_rect = TextureRect.new()
		tex_rect.name = "BackdropTexture"
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		target_bg.add_child(tex_rect)
	tex_rect.texture = tex

	# 실제 이미지 에셋이 있을 때는 어두운 비네팅을 살짝 얹어 UI 가독성을 유지
	var has_custom_art: bool = get_texture("ui", bg_key) != null
	tex_rect.modulate = Color(0.55, 0.58, 0.65, 1.0) if has_custom_art else Color.WHITE


func _get_or_build_procedural_backdrop(
	bg_key: String,
	top_color: Color,
	bottom_color: Color,
	grid_alpha: float
) -> ImageTexture:
	var key: String = "%s_%s_%s_%.3f" % [bg_key, top_color.to_html(), bottom_color.to_html(), grid_alpha]
	if _backdrop_cache.has(key):
		return _backdrop_cache[key] as ImageTexture

	var w: int = 240
	var h: int = 135
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var center := Vector2(w * 0.5, h * 0.42)
	var max_dist: float = Vector2(w * 0.6, h * 0.65).length()

	for y in range(h):
		var v_t: float = float(y) / float(h - 1)
		var base_row: Color = top_color.lerp(bottom_color, v_t)
		for x in range(w):
			var dist_ratio: float = clampf(Vector2(x, y).distance_to(center) / max_dist, 0.0, 1.0)
			var c: Color = base_row.darkened(dist_ratio * 0.34)
			if grid_alpha > 0.0 and ((x % 24 == 0) or (y % 24 == 0)):
				c = c.lightened(grid_alpha)
			img.set_pixel(x, y, c)

	var itex := ImageTexture.create_from_image(img)
	_backdrop_cache[key] = itex
	return itex


# ==========================================
# 재사용 가능한 초상화/아이콘 프레임 빌더
# ==========================================
func create_hero_portrait(hero: Dictionary, box_size: Vector2 = Vector2(72, 72), use_sprite: bool = false) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = box_size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var root := Control.new()
	root.name = "Inner"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(root)

	var elem_bar := ColorRect.new()
	elem_bar.name = "ElementBar"
	elem_bar.anchor_left = 0.0
	elem_bar.anchor_right = 1.0
	elem_bar.anchor_top = 1.0
	elem_bar.anchor_bottom = 1.0
	elem_bar.offset_top = -5
	elem_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(elem_bar)

	var tex_rect := TextureRect.new()
	tex_rect.name = "PortraitTex"
	tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex_rect.offset_left = 6
	tex_rect.offset_top = 6
	tex_rect.offset_right = -6
	tex_rect.offset_bottom = -8
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tex_rect)

	var named_badge := Label.new()
	named_badge.name = "NamedBadge"
	named_badge.position = Vector2(4, 2)
	named_badge.add_theme_font_size_override("font_size", 12)
	named_badge.add_theme_color_override("font_color", COL_TEXT_GOLD)
	named_badge.text = "★"
	named_badge.visible = false
	root.add_child(named_badge)

	update_hero_portrait(frame, hero, use_sprite)
	return frame


func update_hero_portrait(frame: Control, hero: Dictionary, use_sprite: bool = false) -> void:
	if frame == null or not is_instance_valid(frame):
		return
	var rarity: String = DataManager.normalize_rarity(hero.get("rarity", "N"))
	var r_color: Color = DataManager.get_rarity_color(rarity)
	var elem_id: String = str(hero.get("element", "FIRE"))
	var elem_color: Color = DataManager.get_element_color(elem_id)

	if frame is PanelContainer:
		(frame as PanelContainer).add_theme_stylebox_override(
			"panel",
			make_panel_style(Color(0.08, 0.10, 0.15, 0.96), r_color, 8, 2, 0)
		)

	var inner := frame.get_node_or_null("Inner")
	if inner == null:
		return
	var elem_bar := inner.get_node_or_null("ElementBar") as ColorRect
	if elem_bar != null:
		elem_bar.color = elem_color
	var tex_rect := inner.get_node_or_null("PortraitTex") as TextureRect
	if tex_rect != null:
		var hid: String = str(hero.get("id", hero.get("hero_id", ""))).strip_edges()
		var has_real_art: bool = (
			get_texture("heroes/portraits", hid, str(hero.get("portrait_path", ""))) != null
			or get_texture("heroes/sprites", hid, str(hero.get("sprite_path", ""))) != null
		)
		tex_rect.texture = get_hero_sprite(hero) if use_sprite else get_hero_portrait(hero)
		tex_rect.modulate = Color.WHITE if has_real_art else elem_color.lightened(0.32)
	var named_badge := inner.get_node_or_null("NamedBadge") as Label
	if named_badge != null:
		named_badge.visible = bool(hero.get("is_named", false))


# ==========================================
# SVG 벡터 폴백 엠블럼 생성기 (에셋 투입 전까지 사용)
# ==========================================
func _svg_to_texture(cache_key: String, svg_body: String, scale_factor: float = 1.0) -> Texture2D:
	var full_key: String = "%s_%.2f" % [cache_key, scale_factor]
	if _svg_cache.has(full_key):
		return _svg_cache[full_key] as Texture2D

	var svg_xml: String = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">%s</svg>' % svg_body
	var img := Image.new()
	var err: Error = img.load_svg_from_string(svg_xml, scale_factor)
	if err != OK:
		return null
	var itex := ImageTexture.create_from_image(img)
	_svg_cache[full_key] = itex
	return itex


func get_job_emblem_texture(job_class: String) -> Texture2D:
	var key: String = job_class.strip_edges()
	var cg: String = key
	if not ["중장", "근위", "선봉", "특수", "보조", "저격", "술사", "의료", "탱커", "근접딜러", "원거리딜러", "마법사", "힐러"].has(key):
		cg = DataManager.get_class_group_for_sub_class(key)
	match cg:
		"탱커", "중장":
			return _svg_to_texture("job_tank", '<path d="M32 6 L54 14 V30 C54 45 42 54 32 58 C22 54 10 45 10 30 V14 Z" fill="white" fill-opacity="0.9"/><path d="M32 13 L47 19 V30 C47 40 39 47 32 51 Z" fill="#182030" fill-opacity="0.45"/>')
		"근접딜러", "근위":
			return _svg_to_texture("job_melee", '<path d="M48 10 L54 16 L26 44 L31 49 L27 53 L20 46 L13 53 L9 49 L16 42 L9 35 L13 31 L18 36 Z" fill="white" fill-opacity="0.95"/>')
		"선봉":
			return _svg_to_texture("job_vanguard", '<path d="M14 52 V12 H48 L38 22 L48 32 H20 V52 Z" fill="white" fill-opacity="0.95"/>')
		"원거리딜러", "저격":
			return _svg_to_texture("job_ranged", '<path d="M18 10 C38 14 48 24 52 46 L46 48 C42 30 34 21 16 17 Z" fill="white" fill-opacity="0.9"/><line x1="16" y1="14" x2="49" y2="47" stroke="white" stroke-width="2.5"/><path d="M12 52 L48 16 M48 16 L38 16 M48 16 L48 26" stroke="white" stroke-width="4" stroke-linecap="round" fill="none"/>')
		"마법사", "술사":
			return _svg_to_texture("job_mage", '<polygon points="32,6 38,22 54,28 38,34 32,50 26,34 10,28 26,22" fill="white" fill-opacity="0.95"/><circle cx="32" cy="28" r="5" fill="#182030" fill-opacity="0.55"/>')
		"힐러", "의료":
			return _svg_to_texture("job_healer", '<rect x="25" y="10" width="14" height="44" rx="3" fill="white" fill-opacity="0.95"/><rect x="10" y="25" width="44" height="14" rx="3" fill="white" fill-opacity="0.95"/>')
		"보조":
			return _svg_to_texture("job_supporter", '<circle cx="32" cy="32" r="18" fill="none" stroke="white" stroke-width="4"/><circle cx="32" cy="32" r="7" fill="white" fill-opacity="0.95"/><path d="M32 6 V14 M32 50 V58 M6 32 H14 M50 32 H58" stroke="white" stroke-width="4" stroke-linecap="round"/>')
		_:
			return _svg_to_texture("job_special", '<path d="M25 10 H39 V20 L50 42 C52 47 48 54 42 54 H22 C16 54 12 47 14 42 L25 20 Z" fill="white" fill-opacity="0.92"/><rect x="22" y="8" width="20" height="4" rx="2" fill="white"/>')


func get_enemy_emblem_texture(enemy_type: String) -> Texture2D:
	match enemy_type.strip_edges().to_upper():
		"BOSS":
			return _svg_to_texture("enemy_boss", '<path d="M10 46 L14 20 L25 32 L32 14 L39 32 L50 20 L54 46 Z" fill="white" fill-opacity="0.95"/><rect x="12" y="48" width="40" height="7" rx="2" fill="white"/><circle cx="32" cy="11" r="4" fill="white"/>')
		"SIEGE":
			return _svg_to_texture("enemy_siege", '<rect x="10" y="18" width="44" height="24" rx="4" fill="white" fill-opacity="0.92"/><circle cx="20" cy="48" r="7" fill="white"/><circle cx="44" cy="48" r="7" fill="white"/><path d="M54 24 L61 30 L54 36 Z" fill="white"/>')
		"ELITE":
			return _svg_to_texture("enemy_elite", '<path d="M14 14 L24 24 L32 12 L40 24 L50 14 L46 44 L32 54 L18 44 Z" fill="white" fill-opacity="0.92"/><circle cx="25" cy="34" r="3" fill="#182030"/><circle cx="39" cy="34" r="3" fill="#182030"/>')
		_:
			return _svg_to_texture("enemy_normal", '<circle cx="32" cy="34" r="18" fill="white" fill-opacity="0.9"/><polygon points="18,22 24,10 30,20" fill="white"/><polygon points="46,22 40,10 34,20" fill="white"/><circle cx="25" cy="33" r="3" fill="#182030"/><circle cx="39" cy="33" r="3" fill="#182030"/>')


func get_slot_emblem_texture(slot_type: String) -> Texture2D:
	match slot_type.strip_edges().to_upper():
		"WEAPON":
			return get_job_emblem_texture("근접딜러")
		"ARMOR":
			return get_job_emblem_texture("탱커")
		_:
			return _svg_to_texture("slot_acc", '<polygon points="32,8 50,24 44,52 20,52 14,24" fill="white" fill-opacity="0.92"/><polygon points="32,15 43,26 39,46 25,46 21,26" fill="#182030" fill-opacity="0.45"/>')


func get_item_emblem_texture(item_type: String) -> Texture2D:
	match item_type.strip_edges().to_upper():
		"DAMAGE_ENEMY":
			return _svg_to_texture("item_bomb", '<circle cx="30" cy="38" r="16" fill="white" fill-opacity="0.95"/><path d="M38 24 L46 14 M46 14 L52 12 M46 14 L48 20" stroke="white" stroke-width="4" stroke-linecap="round"/>')
		"SHIELD_ALL":
			return get_job_emblem_texture("탱커")
		_:
			return get_job_emblem_texture("특수")


func get_tower_emblem_texture(is_base: bool = false) -> Texture2D:
	if is_base:
		return _svg_to_texture("tower_base", '<path d="M16 14 H24 V22 H28 V14 H36 V22 H40 V14 H48 V54 H16 Z" fill="white" fill-opacity="0.92"/><rect x="27" y="34" width="10" height="20" rx="2" fill="#182030" fill-opacity="0.55"/>')
	return _svg_to_texture("tower_custom", '<polygon points="32,8 48,26 42,54 22,54 16,26" fill="white" fill-opacity="0.92"/><circle cx="32" cy="28" r="6" fill="#182030" fill-opacity="0.5"/>')


func get_tile_emblem_texture(tile_key: String) -> Texture2D:
	match tile_key:
		"tile_wall":
			return _svg_to_texture("tile_wall", '<rect x="10" y="14" width="44" height="36" rx="3" fill="white" fill-opacity="0.45"/><line x1="10" y1="26" x2="54" y2="26" stroke="#10131a" stroke-width="3"/><line x1="10" y1="38" x2="54" y2="38" stroke="#10131a" stroke-width="3"/>', 0.55)
		"tile_boss":
			return get_enemy_emblem_texture("BOSS")
		"tile_outpost":
			return _svg_to_texture("tile_outpost", '<line x1="18" y1="10" x2="18" y2="54" stroke="white" stroke-width="4" stroke-linecap="round"/><polygon points="20,12 50,21 20,30" fill="white" fill-opacity="0.95"/>', 0.55)
		"tile_treasure":
			return _svg_to_texture("tile_treasure", '<rect x="12" y="22" width="40" height="28" rx="4" fill="white" fill-opacity="0.92"/><path d="M12 22 C12 13 52 13 52 22 Z" fill="white" fill-opacity="0.8"/><rect x="28" y="26" width="8" height="10" rx="2" fill="#182030"/>', 0.55)
		"tile_supply":
			return _svg_to_texture("tile_supply", '<rect x="14" y="16" width="36" height="34" rx="4" fill="white" fill-opacity="0.9"/><line x1="14" y1="28" x2="50" y2="28" stroke="#182030" stroke-width="3"/><line x1="32" y1="16" x2="32" y2="50" stroke="#182030" stroke-width="3"/>', 0.55)
		"tile_event":
			return _svg_to_texture("tile_event", '<path d="M24 22 C24 14 40 14 40 22 C40 28 32 30 32 37" stroke="white" stroke-width="6" stroke-linecap="round" fill="none"/><circle cx="32" cy="48" r="4" fill="white"/>', 0.55)
		"tile_portal":
			return _svg_to_texture("tile_portal", '<circle cx="32" cy="32" r="20" stroke="white" stroke-width="5" fill="none"/><circle cx="32" cy="32" r="10" fill="white" fill-opacity="0.85"/>', 0.55)
		"tile_exit":
			return _svg_to_texture("tile_exit", '<path d="M16 52 V24 C16 14 48 14 48 24 V52 Z" fill="white" fill-opacity="0.9"/><path d="M24 52 V27 C24 21 40 21 40 27 V52 Z" fill="#182030" fill-opacity="0.65"/>', 0.55)
		"tile_player":
			return _svg_to_texture("tile_player", '<polygon points="32,8 39,24 56,26 43,38 46,55 32,46 18,55 21,38 8,26 25,24" fill="white" fill-opacity="0.98"/>', 0.55)
		_:
			return null


func get_element_emblem_texture(element_id: String) -> Texture2D:
	match element_id.strip_edges().to_upper():
		"FIRE":
			return _svg_to_texture("el_fire", '<path d="M32 8 C42 20 50 28 48 42 C46 52 38 56 32 56 C22 56 16 48 16 38 C16 28 24 22 32 8 Z" fill="white" fill-opacity="0.95"/>', 0.5)
		"ICE":
			return _svg_to_texture("el_ice", '<polygon points="32,8 48,22 48,42 32,56 16,42 16,22" fill="white" fill-opacity="0.92"/>', 0.5)
		"LIGHTNING":
			return _svg_to_texture("el_lightning", '<polygon points="36,8 16,35 30,35 26,56 48,28 34,28" fill="white" fill-opacity="0.95"/>', 0.5)
		"EARTH":
			return _svg_to_texture("el_earth", '<polygon points="10,50 26,18 38,34 46,24 54,50" fill="white" fill-opacity="0.92"/>', 0.5)
		"WIND":
			return _svg_to_texture("el_wind", '<path d="M12 24 H44 C50 24 50 14 42 14 M10 34 H50 C56 34 56 44 48 44 M16 44 H36" stroke="white" stroke-width="4.5" stroke-linecap="round" fill="none"/>', 0.5)
		"LIGHT":
			return _svg_to_texture("el_light", '<circle cx="32" cy="32" r="13" fill="white"/><polygon points="32,6 36,16 28,16" fill="white"/><polygon points="32,58 36,48 28,48" fill="white"/><polygon points="6,32 16,28 16,36" fill="white"/><polygon points="58,32 48,28 48,36" fill="white"/>', 0.5)
		"DARK":
			return _svg_to_texture("el_dark", '<path d="M40 12 C24 14 16 28 20 42 C24 52 38 56 48 50 C36 50 28 42 28 30 C28 20 34 15 40 12 Z" fill="white" fill-opacity="0.95"/>', 0.5)
		_:
			return _svg_to_texture("el_none", '<circle cx="32" cy="32" r="14" fill="white" fill-opacity="0.8"/>', 0.5)
