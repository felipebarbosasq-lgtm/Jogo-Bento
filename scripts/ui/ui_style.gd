class_name UIStyle
extends RefCounted
## Estilo visual compartilhado dos menus (botões, painéis, rótulos).

const RED := Color(0.75, 0.1, 0.12)
const GOLD := Color(0.95, 0.78, 0.4)
const INK := Color(0.04, 0.03, 0.04)


static func button(text: String, min_w := 320.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 54)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color(0.92, 0.9, 0.86))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.42, 0.4))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	b.add_theme_stylebox_override("normal", _sb(Color(0.06, 0.04, 0.05, 0.75), Color(0.4, 0.08, 0.1)))
	b.add_theme_stylebox_override("hover", _sb(Color(0.4, 0.05, 0.07, 0.9), Color(0.95, 0.3, 0.25)))
	b.add_theme_stylebox_override("pressed", _sb(Color(0.6, 0.08, 0.1, 0.95), Color(1, 0.6, 0.4)))
	b.add_theme_stylebox_override("focus", _sb(Color(0.3, 0.04, 0.06, 0.85), GOLD))
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
