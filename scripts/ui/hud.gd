class_name HUD
extends CanvasLayer
## Interface durante o jogo: vida, resistência, ki, chefe, objetivo, diálogos,
## dicas, prompt de interação, letterbox cinematográfico e efeitos de tela.

const RED := Color(0.78, 0.1, 0.12)
const GOLD := Color(0.95, 0.78, 0.4)

var root: Control
var hp_bar: ProgressBar
var hp_ghost: ProgressBar
var st_bar: ProgressBar
var ki_bar: ProgressBar
var ki_label: Label
var obj_panel: PanelContainer
var obj_label: Label
var boss_box: VBoxContainer
var boss_name: Label
var boss_bar: ProgressBar
var boss: Boss
var prompt_label: Label
var hint_label: Label
var toast_label: Label
var title_label: Label
var subtitle_label: Label
var dialog_box: Control
var dialog_name: Label
var dialog_text: Label
var dialog_more: Label
var vignette: ColorRect
var bar_top: ColorRect
var bar_bottom: ColorRect
var fps_label: Label

var _lines: Array = []
var _line_idx := 0
var _dialog_cb: Callable
var _typing := 0.0
var _hint_t := 0.0
var _toast_t := 0.0
var _vig := 0.0
var _letterbox := 0.0


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	vignette = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.6, 0.0, 0.0, 0.0)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vignette)

	# letterbox
	bar_top = _bar_rect(true)
	bar_bottom = _bar_rect(false)

	# ---- status (canto superior esquerdo)
	var stats := VBoxContainer.new()
	stats.position = Vector2(24, 20)
	stats.add_theme_constant_override("separation", 6)
	root.add_child(stats)
	var name_l := _label("SHIN KUROGANE", 18, GOLD)
	stats.add_child(name_l)
	var hp_stack := Control.new()
	hp_stack.custom_minimum_size = Vector2(320, 20)
	stats.add_child(hp_stack)
	hp_ghost = _bar(Color(1.0, 0.85, 0.6), Vector2(320, 20))
	hp_stack.add_child(hp_ghost)
	hp_bar = _bar(RED, Vector2(320, 20), true)
	hp_stack.add_child(hp_bar)
	st_bar = _bar(Color(0.85, 0.75, 0.3), Vector2(250, 10))
	stats.add_child(st_bar)
	var ki_row := HBoxContainer.new()
	ki_row.add_theme_constant_override("separation", 8)
	stats.add_child(ki_row)
	ki_bar = _bar(Color(0.45, 0.7, 1.0), Vector2(200, 10))
	ki_row.add_child(ki_bar)
	ki_label = _label("KI", 14, Color(0.6, 0.8, 1.0))
	ki_row.add_child(ki_label)

	# ---- objetivo (canto superior direito)
	obj_panel = PanelContainer.new()
	obj_panel.anchor_left = 1.0
	obj_panel.anchor_right = 1.0
	obj_panel.offset_left = -380
	obj_panel.offset_right = -20
	obj_panel.offset_top = 20
	obj_panel.add_theme_stylebox_override("panel", _panel_style(Color(0, 0, 0, 0.5)))
	root.add_child(obj_panel)
	var ov := VBoxContainer.new()
	obj_panel.add_child(ov)
	ov.add_child(_label("◆ OBJETIVO", 14, GOLD))
	obj_label = _label("", 18, Color(0.95, 0.95, 0.92))
	obj_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_label.custom_minimum_size = Vector2(330, 0)
	ov.add_child(obj_label)
	obj_panel.visible = false

	# ---- chefe
	boss_box = VBoxContainer.new()
	boss_box.anchor_left = 0.5
	boss_box.anchor_right = 0.5
	boss_box.anchor_top = 1.0
	boss_box.anchor_bottom = 1.0
	boss_box.offset_left = -330
	boss_box.offset_right = 330
	boss_box.offset_top = -92
	boss_box.offset_bottom = -40
	root.add_child(boss_box)
	boss_name = _label("", 20, Color(1, 0.85, 0.8))
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_name)
	boss_bar = _bar(Color(0.75, 0.05, 0.08), Vector2(660, 16), true)
	boss_box.add_child(boss_bar)
	boss_box.visible = false

	# ---- textos
	prompt_label = _label("", 22, Color.WHITE)
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_top = 0.68
	prompt_label.anchor_bottom = 0.68
	prompt_label.offset_left = -300
	prompt_label.offset_right = 300
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt_label)

	hint_label = _label("", 20, Color(1, 0.95, 0.85))
	hint_label.anchor_left = 0.5
	hint_label.anchor_right = 0.5
	hint_label.offset_left = -420
	hint_label.offset_right = 420
	hint_label.offset_top = 110
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint_label)

	toast_label = _label("", 18, GOLD)
	toast_label.anchor_left = 1.0
	toast_label.anchor_right = 1.0
	toast_label.anchor_top = 1.0
	toast_label.anchor_bottom = 1.0
	toast_label.offset_left = -320
	toast_label.offset_right = -24
	toast_label.offset_top = -50
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(toast_label)

	title_label = _label("", 46, Color(0.97, 0.94, 0.88))
	title_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title_label.offset_left = -600
	title_label.offset_right = 600
	title_label.offset_top = -80
	title_label.offset_bottom = -10
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.modulate.a = 0.0
	root.add_child(title_label)
	subtitle_label = _label("", 22, Color(0.85, 0.2, 0.2))
	subtitle_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	subtitle_label.offset_left = -600
	subtitle_label.offset_right = 600
	subtitle_label.offset_top = -10
	subtitle_label.offset_bottom = 30
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.modulate.a = 0.0
	root.add_child(subtitle_label)

	fps_label = _label("", 14, Color(0.7, 1, 0.7))
	fps_label.position = Vector2(24, 140)
	root.add_child(fps_label)

	_build_dialog()


func _bar_rect(top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.anchor_right = 1.0
	if top:
		r.anchor_bottom = 0.0
	else:
		r.anchor_top = 1.0
		r.anchor_bottom = 1.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)
	return r


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel_style(c: Color, border := Color(0.6, 0.12, 0.12, 0.8)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.border_color = border
	sb.border_width_left = 3
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	return sb


func _bar(col: Color, size: Vector2, transparent_bg := false) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = size
	b.size = size
	b.show_percentage = false
	b.max_value = 100
	b.value = 100
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.0 if transparent_bg else 0.55)
	bg.border_color = Color(0, 0, 0, 0.8)
	bg.set_border_width_all(0 if transparent_bg else 2)
	bg.set_corner_radius_all(2)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(2)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


func _build_dialog() -> void:
	dialog_box = Control.new()
	dialog_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog_box.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog_box.gui_input.connect(_on_dialog_input)
	root.add_child(dialog_box)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -470
	panel.offset_right = 470
	panel.offset_top = -210
	panel.offset_bottom = -78
	var sb := _panel_style(Color(0.03, 0.02, 0.03, 0.85), Color(0.7, 0.12, 0.12))
	sb.border_width_top = 2
	sb.content_margin_left = 22
	sb.content_margin_top = 12
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(panel)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	dialog_name = _label("", 20, Color(0.9, 0.25, 0.22))
	v.add_child(dialog_name)
	dialog_text = _label("", 21, Color(0.95, 0.93, 0.9))
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text.custom_minimum_size = Vector2(880, 56)
	v.add_child(dialog_text)
	dialog_more = _label("", 14, Color(0.7, 0.7, 0.7))
	dialog_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(dialog_more)
	dialog_box.visible = false


# ------------------------------------------------------------------- update
func _process(delta: float) -> void:
	var p = Game.player
	if is_instance_valid(p):
		var hpr: float = p.hp / p.max_hp * 100.0
		hp_bar.value = hpr
		hp_ghost.value = lerpf(hp_ghost.value, hpr, clampf(delta * 2.0, 0, 1)) if hp_ghost.value > hpr else hpr
		st_bar.value = p.stamina / p.max_stamina * 100.0
		(st_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color(0.55, 0.3, 0.2) if p.exhausted else Color(0.85, 0.75, 0.3)
		ki_bar.visible = Game.special_unlocked
		ki_label.visible = Game.special_unlocked
		ki_bar.value = p.ki / p.max_ki * 100.0
		var full: bool = p.ki >= p.max_ki
		ki_label.text = "KI  [Q] PRONTO" if full and not Game.is_touch() else ("KI  PRONTO" if full else "KI")
		ki_label.modulate = Color(1, 1, 1, 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)) if full else Color.WHITE
	if is_instance_valid(boss):
		boss_bar.value = boss.hp / boss.max_hp * 100.0
		boss_box.visible = boss.active and not boss.is_dead() and not dialog_box.visible
	else:
		boss_box.visible = false
	# dicas
	if _hint_t > 0.0:
		_hint_t -= delta
		hint_label.modulate.a = clampf(_hint_t, 0.0, 1.0)
	if _toast_t > 0.0:
		_toast_t -= delta
		toast_label.modulate.a = clampf(_toast_t, 0.0, 1.0)
	# vinheta de dano
	_vig = maxf(0.0, _vig - delta * 1.5)
	var low := 0.0
	if is_instance_valid(p) and p.hp < p.max_hp * 0.3 and not p.is_dead():
		low = 0.12 + 0.06 * sin(Time.get_ticks_msec() * 0.006)
	vignette.color.a = maxf(_vig * 0.35, low)
	# letterbox
	var want := 1.0 if Game.cutscene else 0.0
	_letterbox = move_toward(_letterbox, want, delta * 3.0)
	var vh := root.size.y
	bar_top.offset_bottom = vh * 0.1 * _letterbox
	bar_bottom.offset_top = -vh * 0.1 * _letterbox
	# digitação do diálogo
	if dialog_box.visible and _typing < 1.0:
		_typing = minf(1.0, _typing + delta * 40.0 / maxf(1.0, dialog_text.text.length()))
		dialog_text.visible_ratio = _typing
	fps_label.visible = bool(Game.settings.show_fps)
	if fps_label.visible:
		fps_label.text = "FPS %d" % Engine.get_frames_per_second()


# --------------------------------------------------------------------- API
func set_objective(text: String) -> void:
	obj_label.text = text
	obj_panel.visible = text != ""
	if text != "":
		obj_panel.modulate = Color(1.6, 1.4, 1.0)
		var tw := create_tween()
		tw.tween_property(obj_panel, "modulate", Color.WHITE, 0.8)


func set_prompt(text: String) -> void:
	if text == "" or dialog_box.visible:
		prompt_label.text = ""
		return
	prompt_label.text = ("Toque em AGIR:  " if Game.is_touch() else "[E]  ") + text


func hint(text: String, time := 6.0) -> void:
	hint_label.text = text
	_hint_t = time
	hint_label.modulate.a = 1.0


func toast(text: String) -> void:
	toast_label.text = "✦ " + text
	_toast_t = 2.5


func damage_flash() -> void:
	_vig = 1.0


func set_boss(b: Boss) -> void:
	boss = b
	if b:
		boss_name.text = b.display_name


func title_card(title: String, sub := "") -> void:
	var parts := title.split(" — ")
	title_label.text = parts[parts.size() - 1] if parts.size() > 1 else title
	subtitle_label.text = (parts[0] if parts.size() > 1 else sub).to_upper()
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(title_label, "modulate:a", 1.0, 1.0)
	tw.parallel().tween_property(subtitle_label, "modulate:a", 1.0, 1.0)
	tw.tween_interval(2.5)
	tw.tween_property(title_label, "modulate:a", 0.0, 1.0)
	tw.parallel().tween_property(subtitle_label, "modulate:a", 0.0, 1.0)


func show_dialog(lines: Array, cb: Callable) -> void:
	_lines = lines
	_line_idx = 0
	_dialog_cb = cb
	dialog_box.visible = true
	prompt_label.text = ""
	_show_line()


func is_dialog_open() -> bool:
	return dialog_box.visible


func _show_line() -> void:
	var l: Array = _lines[_line_idx]
	dialog_name.text = str(l[0])
	dialog_text.text = str(l[1])
	_typing = 0.0
	dialog_text.visible_ratio = 0.0
	dialog_more.text = ("Toque para continuar  ▶" if Game.is_touch() else "Clique / Enter para continuar  ▶")
	Sfx.play("ui_click", -10.0)


func _advance() -> void:
	if _typing < 1.0:
		_typing = 1.0
		dialog_text.visible_ratio = 1.0
		return
	_line_idx += 1
	if _line_idx >= _lines.size():
		dialog_box.visible = false
		var cb := _dialog_cb
		_dialog_cb = Callable()
		if cb.is_valid():
			cb.call()
	else:
		_show_line()


func _on_dialog_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not dialog_box.visible or get_tree().paused:
		return
	if event.is_action_pressed("advance") or event.is_action_pressed("interact") or event.is_action_pressed("dodge") or event.is_action_pressed("attack"):
		_advance()
		get_viewport().set_input_as_handled()
