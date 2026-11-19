class_name UIStyle
extends RefCounted
## Estilo visual compartilhado dos menus (botões, painéis, rótulos).

const RED := Color(0.75, 0.1, 0.12)
const GOLD := Color(0.95, 0.78, 0.4)
const INK := Color(0.04, 0.03, 0.04)


static func button(text: String, min_w := 320.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 56)
	b.add_theme_font_size_override("font_size", 25)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("font_color", Color(0.92, 0.9, 0.86))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.42, 0.4))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	b.add_theme_stylebox_override("normal", _sb(Color(0.03, 0.02, 0.03, 0.55), Color(0.55, 0.42, 0.25, 0.6)))
	b.add_theme_stylebox_override("hover", _sb(Color(0.45, 0.05, 0.07, 0.85), Color(0.95, 0.75, 0.45)))
	b.add_theme_stylebox_override("pressed", _sb(Color(0.6, 0.08, 0.1, 0.95), Color(1, 0.85, 0.5)))
	b.add_theme_stylebox_override("focus", _sb(Color(0.35, 0.04, 0.06, 0.8), GOLD))
	b.add_theme_stylebox_override("disabled", _sb(Color(0.05, 0.05, 0.05, 0.5), Color(0.2, 0.2, 0.2)))
	b.mouse_entered.connect(func():
		if not b.disabled:
			Sfx.play("ui_click", -12.0))
	b.pressed.connect(func(): Sfx.play("ui_select", -8.0))
	return b


static func _sb(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = 4
	s.border_width_bottom = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.set_corner_radius_all(3)
	s.content_margin_left = 18
	s.content_margin_right = 18
	return s


static func panel(bg := Color(0.03, 0.02, 0.03, 0.88)) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = Color(0.55, 0.1, 0.12)
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 22
	s.content_margin_bottom = 22
	p.add_theme_stylebox_override("panel", s)
	return p


static func label(text: String, size := 20, col := Color(0.92, 0.9, 0.86), align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	return l


static func backdrop(alpha := 0.7) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.color = Color(0, 0, 0, alpha)
	return r


static func centered(node: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(node)
	return c


static var _title_font: Font
static var _text_font: Font


static func title_font() -> Font:
	if _title_font == null and ResourceLoader.exists("res://assets/fonts/Shippori-Title.ttf"):
		_title_font = load("res://assets/fonts/Shippori-Title.ttf")
	return _title_font


static func text_font() -> Font:
	if _text_font == null and ResourceLoader.exists("res://assets/fonts/Shippori-Text.ttf"):
		_text_font = load("res://assets/fonts/Shippori-Text.ttf")
	return _text_font


static func title(text: String, size := 64, col := Color(0.97, 0.94, 0.88)) -> Label:
	var l := label(text, size, col)
	if title_font():
		l.add_theme_font_override("font", title_font())
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 4)
	return l


static func gradient_shade(left := true, strength := 0.92) -> TextureRect:
	## Sombreado em degradê para dar legibilidade ao texto sobre a arte.
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.01, 0.02, strength))
	g.set_color(1, Color(0.02, 0.01, 0.02, 0.0))
	g.add_point(0.5, Color(0.02, 0.01, 0.02, strength * 0.7))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0) if left else Vector2(0, 1)
	gt.fill_to = Vector2(1, 0) if left else Vector2(0, 0)
	var r := TextureRect.new()
	r.texture = gt
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func make_theme() -> Theme:
	var t := Theme.new()
	if text_font():
		t.default_font = text_font()
	t.default_font_size = 18
	return t
