extends Node
## Teste: jogador parado/defendendo perto de inimigos — verifica IA e dano.
var _t := 0.0
var _mode := "idle"
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--probe="):
			_mode = str(a).split("=")[1]
func _process(delta: float) -> void:
	_t += delta
	var lvl = Game.level
	var p = Game.player
	if not is_instance_valid(lvl) or not is_instance_valid(p):
		return
	if lvl.hud.is_dialog_open():
		lvl.hud._advance(); lvl.hud._advance()
		return
	if _t > 1.5 and _t - delta <= 1.5:
		var es := get_tree().get_nodes_in_group("enemies")
		if es.size() > 0:
			var e: Node3D = es[0]
			p.global_position = e.global_position - e.global_transform.basis.z * 6.0 + Vector3(0, 0.2, 0)
	if _mode == "block":
		p.mouse_block = true
	if int(_t * 2) != int((_t - delta) * 2):
		var info := []
		for e in get_tree().get_nodes_in_group("enemies"):
			info.append("%s:%s d=%.1f hp=%d" % [e.type_id, e.state, e.global_position.distance_to(p.global_position), e.hp])
		print("t=%.1f HP=%d ST=%d state=%s | %s" % [_t, p.hp, p.stamina, p.state, ", ".join(info)])
	if _t > 14.0:
		get_tree().quit()
