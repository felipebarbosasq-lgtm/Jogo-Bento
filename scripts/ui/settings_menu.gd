class_name SettingsMenu
extends Control
## Configurações: volumes, sensibilidade, inverter Y, qualidade gráfica,
## controles touch, tela cheia e contador de FPS. Salvas em user://.

signal closed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UIStyle.backdrop(0.75))
	var panel := UIStyle.panel()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	scroll.add_child(v)
	add_child(UIStyle.centered(panel))

	v.add_child(UIStyle.label("CONFIGURAÇÕES", 32, UIStyle.GOLD))
	_slider(v, "Volume geral", "master", 0.0, 1.0)
	_slider(v, "Música", "music", 0.0, 1.0)
	_slider(v, "Efeitos sonoros", "sfx", 0.0, 1.0)
	_slider(v, "Sensibilidade da câmera", "sensitivity", 0.2, 3.0)
	_check(v, "Inverter eixo Y da câmera", "invert_y")
	_option(v, "Qualidade gráfica", "quality", [["low", "Baixa (celulares simples)"], ["medium", "Média"], ["high", "Alta"]])
	_option(v, "Controles touchscreen", "touch", [["auto", "Automático"], ["on", "Sempre ligados"], ["off", "Desligados"]])
	if not Game.is_mobile():
		_check(v, "Tela cheia", "fullscreen")
	_check(v, "Mostrar FPS", "show_fps")
	v.add_child(UIStyle.label("A qualidade gráfica é aplicada por completo ao carregar a próxima fase.", 14, Color(0.7, 0.7, 0.7)))
	var back := UIStyle.button("Voltar", 260)
	back.pressed.connect(_close)
	v.add_child(back)
	back.grab_focus.call_deferred()


func _row(parent: Control, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l := UIStyle.label(text, 20)
	l.custom_minimum_size = Vector2(280, 0)
	h.add_child(l)
	parent.add_child(h)
	return h


func _slider(parent: Control, text: String, key: String, mn: float, mx: float) -> void:
	var h := _row(parent, text)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.05
	s.value = float(Game.settings[key])
	s.custom_minimum_size = Vector2(260, 32)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var val := UIStyle.label("%d%%" % int(s.value * 100), 18)
	s.value_changed.connect(func(x):
		Game.settings[key] = x
		val.text = "%d%%" % int(x * 100)
		Game.apply_settings())
	h.add_child(s)
	h.add_child(val)


func _check(parent: Control, text: String, key: String) -> void:
	var h := _row(parent, text)
	var c := CheckBox.new()
	c.button_pressed = bool(Game.settings[key])
	c.toggled.connect(func(on):
		Game.settings[key] = on
		Game.apply_settings())
	h.add_child(c)


func _option(parent: Control, text: String, key: String, opts: Array) -> void:
	var h := _row(parent, text)
	var o := OptionButton.new()
	o.add_theme_font_size_override("font_size", 18)
	for i in opts.size():
		o.add_item(str(opts[i][1]), i)
		if str(opts[i][0]) == str(Game.settings[key]):
			o.select(i)
	o.item_selected.connect(func(i):
		Game.settings[key] = opts[i][0]
		Game.apply_settings())
	h.add_child(o)


func _close() -> void:
	Game.save_settings()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
