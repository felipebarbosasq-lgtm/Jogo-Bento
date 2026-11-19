class_name PauseMenu
extends Control
## Menu de pausa com lista de controles.

signal resume_pressed
signal settings_pressed
signal restart_pressed
signal menu_pressed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UIStyle.backdrop(0.65))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 40)
	add_child(UIStyle.centered(h))

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	h.add_child(left)
	left.add_child(UIStyle.label("PAUSA", 48, Color(0.96, 0.94, 0.9)))
	if is_instance_valid(Game.level):
		left.add_child(UIStyle.label(Game.LEVEL_TITLES[Game.level.level_index], 18, Color(0.9, 0.3, 0.3)))
	left.add_child(UIStyle.label("Tempo: %s   •   Quedas: %d" % [Game.format_time(Game.play_time), Game.deaths], 16, Color(0.75, 0.75, 0.75)))
	var b1 := UIStyle.button("Continuar")
	b1.pressed.connect(func(): resume_pressed.emit())
	left.add_child(b1)
	var b2 := UIStyle.button("Configurações")
	b2.pressed.connect(func(): settings_pressed.emit())
	left.add_child(b2)
	var b3 := UIStyle.button("Voltar ao último santuário")
	b3.pressed.connect(func(): restart_pressed.emit())
	left.add_child(b3)
	var b4 := UIStyle.button("Menu principal")
	b4.pressed.connect(func(): menu_pressed.emit())
	left.add_child(b4)
	b1.grab_focus.call_deferred()

	var panel := UIStyle.panel(Color(0.03, 0.02, 0.03, 0.8))
	h.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(UIStyle.label("CONTROLES", 22, UIStyle.GOLD))
	var rows: Array
	if Game.is_touch():
		rows = [["Joystick (esquerda)", "Mover (até o fim: correr)"], ["Arrastar (direita)", "Câmera"], ["ATAQUE", "Toque: leve • Segure: pesado"], ["DEFESA", "Segure para defender"], ["APARAR", "No instante do golpe"], ["ESQUIVA", "Rolamento / salto"], ["ESPECIAL", "Corte da Lua (Ki cheio)"], ["AGIR", "Interagir"]]
	else:
		rows = [["W A S D", "Mover"], ["Mouse", "Câmera (roda: zoom)"], ["Shift", "Correr"], ["Clique esquerdo", "Ataque leve (combo x3)"], ["Segurar clique esq.", "Ataque pesado"], ["Clique direito", "Defender"], ["F", "Aparar (janela precisa)"], ["Espaço", "Esquivar / saltar"], ["Q", "Habilidade especial"], ["E", "Interagir"], ["Esc", "Pausar"]]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for r in rows:
		grid.add_child(UIStyle.label(str(r[0]), 17, Color(1.0, 0.85, 0.6)))
		grid.add_child(UIStyle.label(str(r[1]), 17))
	v.add_child(UIStyle.label("\nDica: defender no instante exato do golpe\ntambém apara o ataque inimigo.", 15, Color(0.7, 0.75, 0.8)))
