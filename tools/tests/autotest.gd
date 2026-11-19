extends Node
## Bot de teste automatizado: joga a campanha sozinho para validar etapas,
## combate, chefes e transições. Uso:
##   godot --path . -- --level=1 --autotest [--shots=/caminho] [--god]
## Imprime cada etapa concluída e encerra com código 0 ao vencer o jogo.

var main: Node
var _t := 0.0
var _act := 0.0
var _last_stage := -1
var _last_level := -1
var _stage_time := 0.0
var _shot_dir := ""
var _shot_t := 0.0
var _god := true
var _fails := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("--shots="):
			_shot_dir = s.split("=")[1]
		if s == "--nogod":
			_god = false
	print("[AUTOTEST] iniciado")


func _process(delta: float) -> void:
	_t += delta
	_stage_time += delta
	var lvl = Game.level
	if not is_instance_valid(lvl):
		return
	if lvl.level_index != _last_level:
		_last_level = lvl.level_index
		_last_stage = -1
		print("[AUTOTEST] FASE %d carregada (t=%.1fs)" % [lvl.level_index + 1, _t])
	if lvl.stage != _last_stage:
		_last_stage = lvl.stage
		_stage_time = 0.0
		print("[AUTOTEST]   etapa %d  objetivo: %s" % [lvl.stage, lvl.hud.obj_label.text if lvl.hud else ""])
	if _stage_time > 150.0:
		push_error("[AUTOTEST] etapa travada: fase %d etapa %d" % [lvl.level_index + 1, lvl.stage])
		_fails += 1
		_stage_time = 0.0
		if _fails > 2:
			get_tree().quit(1)
	if _shot_dir != "":
		_shot_t += delta
		if _shot_t > 6.0:
			_shot_t = 0.0
			var img := get_viewport().get_texture().get_image()
			img.save_png("%s/L%d_S%d_%04d.png" % [_shot_dir, lvl.level_index + 1, lvl.stage, int(_t)])
	_drive(lvl, delta)


func _drive(lvl, delta: float) -> void:
	var hud = lvl.hud
	var p = Game.player
	if not is_instance_valid(p):
		return
	if _god:
		p.hp = p.max_hp
		p.stamina = p.max_stamina
	if hud and hud.is_dialog_open():
		_act += delta
		if _act > 0.25:
			_act = 0.0
			hud._advance()
			hud._advance()
		return
	if get_tree().paused:
		return
	_act += delta
	if _act < 0.12:
		return
	_act = 0.0
	if Game.cutscene or p.controls_locked:
		return
	# alvo mais próximo
	var target: Node3D = null
	var bd := 9999.0
	for n in get_tree().get_nodes_in_group("hittable"):
		var h := n as Node3D
		if h == null or (h.has_method("is_dead") and h.is_dead()):
			continue
		if h is Boss and not (h as Boss).active:
			continue
		var d := h.global_position.distance_to(p.global_position)
		if d < bd:
			bd = d
			target = h
	if target and (bd < 60.0):
		var to: Vector3 = target.global_position - p.global_position
		to.y = 0
		if bd > 2.0:
			var dest: Vector3 = target.global_position - to.normalized() * 1.6
			p.global_position = Vector3(dest.x, target.global_position.y + 0.2, dest.z)
		p.rotation.y = atan2(-to.x, -to.z)
		if p.state == "move":
			if Game.special_unlocked and p.ki >= p.max_ki:
				p._try_special()
			else:
				p._start_attack("heavy" if randf() < 0.3 else p._next_combo())
		return
	# interação
	if hud and hud.prompt_label.text != "":
		lvl.try_interact(p)
		return
	# vai até o marcador
	var b = lvl._beacon
	if is_instance_valid(b):
		var bp: Vector3 = b.global_position
		var dir: Vector3 = bp - p.global_position
		dir.y = 0
		if dir.length() > 1.0:
			var step: Vector3 = p.global_position + dir.normalized() * minf(dir.length() - 0.5, 6.0)
			p.global_position = Vector3(step.x, bp.y + 0.3, step.z)
		return
	# sem marcador: procura interações próximas
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.enabled:
			p.global_position = n.global_position + Vector3(0, 0.3, 1.0)
			return
