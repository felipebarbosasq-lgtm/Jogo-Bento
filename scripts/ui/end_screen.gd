class_name EndScreen
extends Control
## Telas de vitória e derrota.

signal retry_pressed
signal menu_pressed

var victory := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art := TextureRect.new()
	art.texture = LoadingScreen.tex("res://assets/art/samurai_castelo.jpg" if victory else "res://assets/art/elite.jpg")
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.modulate = Color(1, 1, 1, 0)
	add_child(art)
	var tw0 := create_tween()
	tw0.tween_property(art, "modulate:a", 1.0, 2.0)
	var bg := UIStyle.backdrop(0.0)
	add_child(bg)
	var tw := create_tween()
	tw.tween_property(bg, "color:a", 0.62 if not victory else 0.6, 1.2)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(UIStyle.centered(v))
	v.modulate.a = 0.0
	var tw2 := create_tween()
	tw2.tween_interval(0.6)
	tw2.tween_property(v, "modulate:a", 1.0, 1.0)

	if victory:
		var vt := UIStyle.title("VITÓRIA", 96, UIStyle.GOLD)
		vt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(vt)
		v.add_child(UIStyle.label("A Lua Sangrenta se apaga. A paz retorna às terras de Kurogane.", 22, Color(0.95, 0.92, 0.88), HORIZONTAL_ALIGNMENT_CENTER))
		var epi := UIStyle.label("Com a espada Tsukikage embainhada, Shin caminha ao amanhecer.\nA lenda do Samurai das Sombras será contada por gerações.", 18, Color(0.8, 0.78, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(epi)
		v.add_child(UIStyle.label("Tempo total: %s     •     Quedas: %d     •     Pergaminhos: %d" % [Game.format_time(Game.play_time), Game.deaths, Game.scrolls], 20, Color(1.0, 0.8, 0.6), HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(UIStyle.label("\nSHIN: A Lenda do Samurai das Sombras\nDesign, código, modelos, animações e música: gerados de forma procedural para este projeto.\nFeito com Godot Engine (licença MIT).", 15, Color(0.6, 0.6, 0.6), HORIZONTAL_ALIGNMENT_CENTER))
		var b := UIStyle.button("Menu principal")
		b.pressed.connect(func(): menu_pressed.emit())
		v.add_child(UIStyle.centered(b))
		b.get_parent().custom_minimum_size = Vector2(0, 60)
		b.grab_focus.call_deferred()
	else:
		var dt := UIStyle.title("DERROTA", 96, Color(0.9, 0.15, 0.14))
		dt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(dt)
		v.add_child(UIStyle.label("Shin caiu em combate... mas a lâmina ainda não descansou.", 22, Color(0.9, 0.88, 0.85), HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(UIStyle.label("Dica: use a defesa (ou aparar no tempo certo) e esquive dos ataques marcados em vermelho.", 16, Color(0.7, 0.7, 0.7), HORIZONTAL_ALIGNMENT_CENTER))
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 20)
		v.add_child(h)
		var r := UIStyle.button("Tentar novamente", 280)
		r.pressed.connect(func(): retry_pressed.emit())
		h.add_child(r)
		var m := UIStyle.button("Menu principal", 280)
		m.pressed.connect(func(): menu_pressed.emit())
		h.add_child(m)
		r.grab_focus.call_deferred()
