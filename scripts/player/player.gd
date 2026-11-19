class_name Player
extends CharacterBody3D
## Shin Kurogane — controlador do jogador.
## Movimento em 8 direções relativo à câmera, corrida, esquiva com salto,
## combo leve (3 golpes), golpe pesado (segurar ataque), defesa, aparar com
## janela de precisão, habilidade especial e câmera com colisão.

signal died

const SHIN_LOOK := {
	"skin": Color(0.78, 0.6, 0.48),
	"hair": Color(0.03, 0.03, 0.035),
	"armor": Color(0.1, 0.1, 0.12),
	"armor2": Color(0.18, 0.17, 0.2),
	"trim": Color(0.62, 0.05, 0.08),
	"cloth": Color(0.08, 0.08, 0.1),
	"hakama": Color(0.06, 0.06, 0.07),
	"hair_style": "shin",
	"helmet": "none",
	"weapon": "katana",
}

const WALK_SPEED := 3.4
const RUN_SPEED := 6.8
const ACCEL := 16.0
const HEAVY_HOLD := 0.3

const ATTACKS := {
	"attack1": {"dur": 0.48, "hit": 0.22, "dmg": 12.0, "range": 2.3, "arc": 80.0, "stam": 8.0, "kb": 1.5, "lunge": 3.5, "heavy": false, "roll": -0.8, "sfx": "swing_light"},
	"attack2": {"dur": 0.48, "hit": 0.22, "dmg": 12.0, "range": 2.3, "arc": 85.0, "stam": 8.0, "kb": 1.5, "lunge": 3.5, "heavy": false, "roll": 3.1, "sfx": "swing_light"},
	"attack3": {"dur": 0.62, "hit": 0.27, "dmg": 18.0, "range": 2.8, "arc": 45.0, "stam": 10.0, "kb": 4.0, "lunge": 6.0, "heavy": false, "roll": 1.57, "sfx": "swing_heavy"},
	"heavy": {"dur": 0.95, "hit": 0.53, "dmg": 30.0, "range": 2.7, "arc": 75.0, "stam": 22.0, "kb": 5.0, "lunge": 4.0, "heavy": true, "roll": 1.45, "sfx": "swing_heavy"},
}

# Atributos
var max_hp := 100.0
var hp := 100.0
var max_stamina := 100.0
var stamina := 100.0
var ki := 0.0
var max_ki := 100.0

# Estado
var state := "move"   # move, attack, block, parry, dodge, hurt, dead, special, interact
var state_time := 0.0
var combo := 0
var combo_reset := 0.0
var queued := ""
var atk: Dictionary = {}
var atk_name := ""
var hit_done := false
var invuln := 0.0
var parry_window := 0.0
var stamina_delay := 0.0
var exhausted := false
var controls_locked := false
var hurt_time := 0.0
var safe_pos := Vector3.ZERO
var _safe_timer := 0.0

# Entrada
var mouse_attack := false
var mouse_block := false
var _attack_prev := false
var _charging := false
var _hold := 0.0
var _dodge_dir := Vector3.ZERO

# Câmera
var cam_rig: Node3D
var cam_pitch_node: Node3D
var spring: SpringArm3D
var cam_target: Node3D
var camera: Camera3D
var yaw := 0.0
var pitch := -0.25
var shake := 0.0
var _cine_xf := Transform3D()
var _cine_t := 0.0
var _cine_dur := 1.0
var _cine_hold := 0.0

var model: CharacterModel


func _ready() -> void:
	add_to_group("player")
	collision_layer = Game.L_PLAYER
	collision_mask = Game.L_WORLD | Game.L_ENEMY
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)

	model = CharacterModel.new()
	add_child(model)
	model.setup(SHIN_LOOK)
	model.step_callback = _on_step

	_build_camera()
	Game.player = self
	safe_pos = global_position if is_inside_tree() else position


func _build_camera() -> void:
	cam_rig = Node3D.new()
	cam_rig.name = "CameraRig"
	cam_rig.top_level = true
	add_child(cam_rig)
	cam_pitch_node = Node3D.new()
	cam_rig.add_child(cam_pitch_node)
	spring = SpringArm3D.new()
	spring.spring_length = 4.3
	spring.margin = 0.25
	spring.collision_mask = Game.L_WORLD
	var sph := SphereShape3D.new()
	sph.radius = 0.25
	spring.shape = sph
	spring.add_excluded_object(get_rid())
	cam_pitch_node.add_child(spring)
	cam_target = Node3D.new()
	spring.add_child(cam_target)
	camera = Camera3D.new()
	camera.top_level = true
	camera.fov = 68.0
	camera.near = 0.08
	camera.far = 400.0
	add_child(camera)
	camera.current = true


func snap_camera(face_yaw := INF) -> void:
	if face_yaw != INF:
		yaw = face_yaw
	cam_rig.global_position = global_position + Vector3(0, 1.55, 0)
	cam_rig.rotation = Vector3(0, yaw, 0)
	cam_pitch_node.rotation = Vector3(pitch, 0, 0)


func face(dir_yaw: float) -> void:
	rotation.y = dir_yaw
	yaw = dir_yaw


# ------------------------------------------------------------------- entrada
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			mouse_attack = mb.pressed
			if mb.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not Game.is_touch() and not get_tree().paused:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			mouse_block = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			spring.spring_length = clampf(spring.spring_length - 0.3, 2.5, 7.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			spring.spring_length = clampf(spring.spring_length + 0.3, 2.5, 7.0)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		var sens: float = 0.0028 * float(Game.settings.sensitivity)
		yaw -= mm.relative.x * sens
		var inv := -1.0 if Game.settings.invert_y else 1.0
		pitch = clampf(pitch - mm.relative.y * sens * inv, -1.2, 0.6)


func _input_dir() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if Game.touch_move.length() > 0.05:
		v = Game.touch_move
	return v.limit_length(1.0)


func _world_dir(v: Vector2) -> Vector3:
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	return (right * v.x + fwd * -v.y)


# ------------------------------------------------------------------- física
func _physics_process(delta: float) -> void:
	state_time += delta
	invuln = maxf(0.0, invuln - delta)
	parry_window = maxf(0.0, parry_window - delta)
	combo_reset = maxf(0.0, combo_reset - delta)
	if combo_reset <= 0.0 and state != "attack":
		combo = 0
	_regen(delta)

	var locked := controls_locked or Game.cutscene
	var in_v := Vector2.ZERO if locked else _input_dir()
	var wish := _world_dir(in_v)
	var attack_down := false
	var block_down := false
	if not locked:
		attack_down = mouse_attack or Input.is_action_pressed("attack")
		block_down = mouse_block or Input.is_action_pressed("block")

	var target_speed := 0.0
	var can_turn := true
	match state:
		"move":
			var sprinting := Input.is_action_pressed("sprint") and in_v.length() > 0.2 and not exhausted and not locked
			if Game.touch_move.length() > 0.92 and not exhausted:
				sprinting = true
			target_speed = (RUN_SPEED if sprinting else WALK_SPEED) * in_v.length()
			if sprinting:
				stamina -= 11.0 * delta
				stamina_delay = 0.5
				if stamina <= 0.0:
					exhausted = true
			if not locked:
				_handle_actions(attack_down, block_down, wish, delta)
		"attack":
			can_turn = false
			_update_attack(delta, attack_down, wish)
		"block":
			target_speed = 1.3 * in_v.length()
			if not block_down or locked:
				_set_state("move")
			elif Input.is_action_just_pressed("dodge"):
				_try_dodge(wish)
			elif Input.is_action_just_pressed("parry"):
				_try_parry()
		"parry":
			if state_time > 0.45:
				_set_state("block" if block_down else "move")
		"dodge":
			can_turn = false
			if state_time > 0.42 and is_on_floor():
				_set_state("move")
				Fx.dust(global_position)
		"hurt":
			can_turn = false
			if state_time > hurt_time:
				_set_state("move")
		"special":
			can_turn = false
			_update_special()
		"interact":
			if state_time > 0.6:
				_set_state("move")
		"dead":
			can_turn = false

	# velocidade horizontal
	var hv := Vector3(velocity.x, 0, velocity.z)
	if state == "dodge":
		hv = _dodge_dir * lerpf(10.0, 4.0, clampf(state_time / 0.45, 0, 1))
	elif state == "attack":
		var lunge_t := state_time / float(atk.dur)
		var push := 0.0
		if lunge_t > 0.25 and lunge_t < 0.55:
			push = float(atk.lunge)
		hv = hv.lerp(-global_transform.basis.z * push, clampf(12.0 * delta, 0, 1))
	elif state in ["hurt", "dead", "special", "parry", "interact"]:
		hv = hv.lerp(Vector3.ZERO, clampf(10.0 * delta, 0, 1))
	else:
		var desired := wish.normalized() * target_speed if wish.length() > 0.01 else Vector3.ZERO
		hv = hv.lerp(desired, clampf(ACCEL * delta, 0, 1))
	if can_turn and wish.length() > 0.1 and state in ["move"]:
		var target_yaw := atan2(-wish.x, -wish.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(14.0 * delta, 0, 1))
	elif state == "block" and not locked:
		rotation.y = lerp_angle(rotation.y, yaw, clampf(10.0 * delta, 0, 1))

	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	elif velocity.y < 0:
		velocity.y = -0.5
	move_and_slide()

	model.move_speed = Vector2(velocity.x, velocity.z).length() if state in ["move", "block"] else 0.0

	# segurança: queda fora do mapa
	_safe_timer += delta
	if is_on_floor() and _safe_timer > 1.0 and state == "move":
		_safe_timer = 0.0
		safe_pos = global_position
	if global_position.y < -25.0:
		global_position = safe_pos + Vector3(0, 1, 0)
		velocity = Vector3.ZERO
		_apply_damage(15.0, global_position)


func _regen(delta: float) -> void:
	stamina_delay -= delta
	if stamina_delay <= 0.0 and state != "block":
		stamina = minf(max_stamina, stamina + 32.0 * delta)
	elif state == "block":
		stamina = minf(max_stamina, stamina + 8.0 * delta)
	if exhausted and stamina > 30.0:
		exhausted = false
	stamina = maxf(stamina, 0.0)
	if Game.special_unlocked and state != "dead":
		ki = minf(max_ki, ki + 2.5 * delta)


func _handle_actions(attack_down: bool, block_down: bool, wish: Vector3, delta: float) -> void:
	# ataque: toque = leve, segurar = pesado
	if attack_down and not _attack_prev:
		_charging = true
		_hold = 0.0
	if _charging:
		if attack_down:
			_hold += delta
			if _hold >= HEAVY_HOLD:
				_charging = false
				_start_attack("heavy")
		else:
			_charging = false
			_start_attack(_next_combo())
	_attack_prev = attack_down
	if state != "move":
		return
	if Input.is_action_just_pressed("dodge"):
		_try_dodge(wish)
	elif Input.is_action_just_pressed("parry"):
		_try_parry()
	elif Input.is_action_just_pressed("special"):
		_try_special()
	elif Input.is_action_just_pressed("interact"):
		_try_interact()
	elif block_down:
		_set_state("block")
		parry_window = 0.12  # defesa no momento exato também apara
		model.play("block", 0.2)


func _next_combo() -> String:
	var names := ["attack1", "attack2", "attack3"]
	var n: String = names[combo % 3]
	return n


func _set_state(s: String) -> void:
	if state == "block" and s != "block":
		model.clear_action()
	state = s
	state_time = 0.0


func _start_attack(name: String) -> void:
	var a: Dictionary = ATTACKS[name]
	var cost: float = a.stam
	if stamina < cost * 0.5:
		Sfx.play("ui_click", -10)
		return
	stamina -= cost
	stamina_delay = 0.7
	atk = a
	atk_name = name
	hit_done = false
	queued = ""
	_auto_aim()
	_set_state("attack")
	model.play(name, float(a.dur))
	if name != "heavy":
		combo += 1
		combo_reset = 0.9
	else:
		combo = 0
	_attack_prev = true


func _auto_aim() -> void:
	## Gira suavemente em direção ao inimigo mais próximo à frente (ajuda no touch).
	var best: Node3D = null
	var best_d := 5.5
	var wish := _world_dir(_input_dir())
	var fwd := wish.normalized() if wish.length() > 0.2 else -global_transform.basis.z
	for e in get_tree().get_nodes_in_group("hittable"):
		var n := e as Node3D
		if n == null or (n.has_method("is_dead") and n.is_dead()):
			continue
		var to := n.global_position - global_position
		to.y = 0
		var d := to.length()
		if d < best_d and (d < 1.5 or fwd.angle_to(to.normalized()) < deg_to_rad(70)):
			best = n
			best_d = d
	if best:
		var to2 := best.global_position - global_position
		rotation.y = atan2(-to2.x, -to2.z)
	elif wish.length() > 0.2:
		rotation.y = atan2(-wish.x, -wish.z)


func _update_attack(delta: float, attack_down: bool, wish: Vector3) -> void:
	var dur: float = atk.dur
	var hit_t: float = atk.hit
	if not hit_done and state_time >= hit_t:
		hit_done = true
		_do_hit()
	# entrada para continuar o combo
	if attack_down and not _attack_prev and state_time > dur * 0.35 and atk_name != "heavy":
		queued = _next_combo()
	_attack_prev = attack_down
	if Input.is_action_just_pressed("dodge") and state_time > hit_t:
		_try_dodge(wish)
		return
	if state_time >= dur * (0.78 if queued != "" else 1.0):
		if queued != "" and combo < 3:
			var q := queued
			queued = ""
			_start_attack(q)
			if state != "attack":
				_set_state("move")
		else:
			_set_state("move")
			if combo >= 3:
				combo = 0


func _do_hit() -> void:
	var a := atk
	Sfx.play_at(str(a.sfx), global_position + Vector3(0, 1.2, 0), -2.0)
	var col := Color(0.85, 0.9, 1.0, 0.9)
	Fx.slash(self, Vector3(0, 1.1, -0.3), float(a.roll), float(a.range) * 0.9, col, 0.2)
	var fwd := -global_transform.basis.z
	var landed := 0
	for e in get_tree().get_nodes_in_group("hittable"):
		var n := e as Node3D
		if n == null or not n.has_method("take_hit"):
			continue
		if n.has_method("is_dead") and n.is_dead():
			continue
		var to := n.global_position - global_position
		if absf(to.y) > 2.2:
			continue
		to.y = 0
		var d := to.length()
		var hr: float = n.get("hit_radius") if n.get("hit_radius") != null else 0.4
		if d > float(a.range) + hr:
			continue
		if d > 0.6 and rad_to_deg(fwd.angle_to(to.normalized())) > float(a.arc):
			continue
		var res: String = n.take_hit(float(a.dmg), global_position, self, {"heavy": a.heavy, "knockback": a.kb})
		var hp_pos := n.global_position + Vector3(0, 1.2, 0)
		match res:
			"hit", "dead":
				landed += 1
				ki = minf(max_ki, ki + 7.0)
				Fx.hit(hp_pos)
				Sfx.play_at("hit", hp_pos, 0.0)
			"blocked":
				Sfx.play_at("clash", hp_pos, 0.0)
				Fx.sparks(hp_pos.lerp(global_position + Vector3(0, 1.2, 0), 0.4))
				if not a.heavy:
					_recoil()
			"guard_break":
				landed += 1
				Sfx.play_at("clash", hp_pos, 2.0)
				Fx.sparks(hp_pos, Color(1, 0.5, 0.2), 30)
			"parried":
				Sfx.play_at("parry", hp_pos, 0.0)
				Fx.sparks(hp_pos, Color(1, 1, 0.6), 28)
				_stagger(0.8)
	if landed > 0:
		shake = maxf(shake, 0.12 if not a.heavy else 0.25)
		Game.hitstop(0.05 if not a.heavy else 0.09)


func _recoil() -> void:
	_set_state("hurt")
	hurt_time = 0.3
	model.play("hurt", 0.3)


func _stagger(t: float) -> void:
	_set_state("hurt")
	hurt_time = t
	model.play("stunned", t)


func _try_dodge(wish: Vector3) -> void:
	if stamina < 12.0 or not is_on_floor():
		return
	stamina -= 20.0
	stamina_delay = 0.6
	_dodge_dir = wish.normalized() if wish.length() > 0.1 else global_transform.basis.z
	rotation.y = atan2(-_dodge_dir.x, -_dodge_dir.z) if wish.length() > 0.1 else rotation.y
	velocity.y = 6.4
	invuln = 0.38
	_set_state("dodge")
	model.play("dodge", 0.5)
	Sfx.play_at("dodge", global_position, -4.0)
	Fx.dust(global_position)


func _try_parry() -> void:
	if stamina < 6.0:
		return
	stamina -= 6.0
	stamina_delay = 0.4
	parry_window = 0.24
	_set_state("parry")
	model.play("parry", 0.45)
	Sfx.play("swing_light", -8.0)


func _try_special() -> void:
	if not Game.special_unlocked:
		if is_instance_valid(Game.level) and Game.level.has_method("hint"):
			Game.level.hint("A habilidade especial ainda não foi desbloqueada.")
		return
	if ki < max_ki:
		if is_instance_valid(Game.level) and Game.level.has_method("hint"):
			Game.level.hint("Ki insuficiente: acerte golpes e apare ataques para carregar.")
		return
	ki = 0.0
	invuln = 1.1
	_set_state("special")
	hit_done = false
	model.play("special", 1.1)
	Sfx.play("special", 0.0, 0.0)
	model.flash(Color(0.5, 0.7, 1.0), 0.3)


func _update_special() -> void:
	if not hit_done and state_time > 0.5:
		hit_done = true
		var c := global_position + Vector3(0, 1.0, 0)
		Fx.ring(global_position, 6.5, Color(0.55, 0.75, 1.0, 0.9), 0.5)
		Fx.burst(c, Color(0.6, 0.8, 1.0), 50, 9.0)
		for i in 3:
			Fx.slash(self, Vector3(0, 0.6 + i * 0.4, 0), 1.57 + i * 0.4, 5.5, Color(0.6, 0.8, 1.0, 1.0), 0.45)
		shake = 0.45
		_spawn_crescent()
		for e in get_tree().get_nodes_in_group("hittable"):
			var n := e as Node3D
			if n == null or not n.has_method("take_hit") or (n.has_method("is_dead") and n.is_dead()):
				continue
			var to := n.global_position - global_position
			if to.length() < 6.0:
				n.take_hit(45.0, global_position, self, {"heavy": true, "special": true, "knockback": 7.0})
				Fx.hit(n.global_position + Vector3(0, 1.2, 0), Color(0.6, 0.8, 1.0))
		Game.hitstop(0.12, 0.1)
	if state_time > 1.1:
		_set_state("move")


func _spawn_crescent() -> void:
	## Onda crescente que viaja à frente e corta tudo em seu caminho.
	var cr := Crescent.new()
	cr.owner_player = self
	if is_instance_valid(Game.level):
		Game.level.add_child(cr)
		cr.global_position = global_position + Vector3(0, 1.0, 0) - global_transform.basis.z * 1.0
		cr.dir = -global_transform.basis.z
		cr.rotation.y = rotation.y


func _try_interact() -> void:
	if is_instance_valid(Game.level) and Game.level.has_method("try_interact"):
		if Game.level.try_interact(self):
			_set_state("interact")
			model.play("interact", 0.6)


# ------------------------------------------------------------- receber dano
func is_dead() -> bool:
	return state == "dead"


func is_attacking() -> bool:
	return state == "attack" and state_time < float(atk.get("hit", 0.3)) + 0.05


func take_hit(amount: float, from_pos: Vector3, attacker: Node = null, kind := "melee") -> String:
	## Retorna: "dodged", "parried", "blocked", "hit" ou "none".
	if state == "dead":
		return "none"
	if invuln > 0.0:
		return "dodged"
	var to := from_pos - global_position
	to.y = 0
	var facing := to.length() < 0.01 or (-global_transform.basis.z).dot(to.normalized()) > 0.1
	var defendable := kind != "trap" and kind != "unblockable"
	if parry_window > 0.0 and facing and defendable:
		_on_parry(attacker, from_pos)
		return "parried"
	if state == "block" and facing and defendable:
		var cost := amount * (1.4 if kind == "heavy" else 1.0)
		stamina -= cost
		stamina_delay = 0.8
		var wp := global_position + Vector3(0, 1.3, 0) + to.normalized() * 0.5
		if stamina <= 0.0:
			stamina = 0.0
			exhausted = true
			Sfx.play_at("clash", wp, 3.0)
			Fx.sparks(wp, Color(1, 0.4, 0.2), 30)
			_apply_damage(amount * 0.5, from_pos)
			if state != "dead":
				_stagger(1.0)
			return "hit"
		Sfx.play_at("block", wp, 0.0)
		Fx.sparks(wp)
		velocity += -to.normalized() * 3.0
		shake = maxf(shake, 0.08)
		model.flash(Color(1, 0.8, 0.5), 0.05)
		return "blocked"
	_apply_damage(amount, from_pos)
	return "hit"


func _on_parry(attacker: Node, from_pos: Vector3) -> void:
	var wp := global_position + Vector3(0, 1.3, 0) + (from_pos - global_position).normalized() * 0.6
	Sfx.play_at("parry", wp, 2.0, 0.0)
	Fx.sparks(wp, Color(1.0, 0.95, 0.6), 34)
	Fx.ring(wp - Vector3(0, 1.2, 0), 2.0, Color(1, 0.9, 0.5, 0.8), 0.3)
	ki = minf(max_ki, ki + 22.0)
	stamina = minf(max_stamina, stamina + 15.0)
	shake = 0.2
	model.flash(Color(1, 0.95, 0.6), 0.12)
	_set_state("parry")
	state_time = 0.2
	model.play("parry", 0.45)
	model.action_time = 0.18
	if attacker and is_instance_valid(attacker) and attacker.has_method("on_parried"):
		attacker.on_parried()
	Game.hitstop(0.25, 0.15)
	if is_instance_valid(Game.level) and Game.level.has_method("on_player_parry"):
		Game.level.on_player_parry()


func _apply_damage(amount: float, from_pos: Vector3) -> void:
	hp -= amount
	Sfx.play_at("hurt", global_position + Vector3(0, 1, 0), 0.0)
	Fx.hit(global_position + Vector3(0, 1.2, 0))
	model.flash(Color(1, 0.2, 0.2), 0.12)
	shake = maxf(shake, 0.3)
	if is_instance_valid(Game.level) and Game.level.has_method("on_player_hurt"):
		Game.level.on_player_hurt(amount)
	if hp <= 0.0:
		hp = 0.0
		_die()
		return
	if state not in ["special", "dodge"]:
		var push := global_position - from_pos
		push.y = 0
		velocity += push.normalized() * 4.0
		_set_state("hurt")
		hurt_time = 0.35 if amount < 20 else 0.6
		model.play("hurt", hurt_time)


func _die() -> void:
	_set_state("dead")
	model.play("dead", 0.9)
	Sfx.play("fall", 0.0)
	Game.deaths += 1
	await get_tree().create_timer(2.2).timeout
	died.emit()


func heal_full() -> void:
	hp = max_hp
	stamina = max_stamina


func _on_step() -> void:
	if is_on_floor() and state in ["move", "block"]:
		Sfx.play_at("step", global_position, -12.0, 0.15)


# ------------------------------------------------------------------- câmera
func _process(delta: float) -> void:
	# câmera por arraste (touch) e analógico direito
	if Game.touch_look != Vector2.ZERO:
		var s: float = 0.006 * float(Game.settings.sensitivity)
		yaw -= Game.touch_look.x * s
		var inv := -1.0 if Game.settings.invert_y else 1.0
		pitch = clampf(pitch - Game.touch_look.y * s * inv, -1.2, 0.6)
		Game.touch_look = Vector2.ZERO
	var rs := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if rs.length() > 0.2:
		yaw -= rs.x * 2.6 * delta * float(Game.settings.sensitivity)
		pitch = clampf(pitch - rs.y * 1.8 * delta, -1.2, 0.6)

	var follow := global_position + Vector3(0, 1.55, 0)
	cam_rig.global_position = cam_rig.global_position.lerp(follow, clampf(14.0 * delta, 0, 1))
	cam_rig.rotation = Vector3(0, yaw, 0)
	cam_pitch_node.rotation = Vector3(pitch, 0, 0)
	spring.position = Vector3(0.45, 0, 0)

	var xf := cam_target.global_transform
	shake = maxf(0.0, shake - delta * 1.6)
	if shake > 0.0:
		var a := shake * shake * 0.35
		xf.origin += Vector3(randf_range(-a, a), randf_range(-a, a), randf_range(-a, a))
	if _cine_hold > 0.0:
		_cine_hold -= delta
		camera.global_transform = _cine_xf
	elif _cine_t > 0.0:
		_cine_t -= delta
		var k := 1.0 - clampf(_cine_t / _cine_dur, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		camera.global_transform = _cine_xf.interpolate_with(xf, k)
	else:
		camera.global_transform = xf


func cinematic(from_pos: Vector3, look_at_pos: Vector3, hold := 1.0, blend := 2.0) -> void:
	## Posiciona a câmera numa tomada cinematográfica e volta suavemente para trás do jogador.
	var t := Transform3D(Basis(), from_pos)
	t = t.looking_at(look_at_pos, Vector3.UP)
	_cine_xf = t
	_cine_hold = hold
	_cine_t = blend
	_cine_dur = blend


# ------------------------------------------------------- onda crescente (Q)
class Crescent:
	extends Node3D
	var owner_player: Node3D
	var dir := Vector3.FORWARD
	var speed := 22.0
	var life := 0.75
	var hit_list := []
	var mi: MeshInstance3D

	func _ready() -> void:
		mi = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.5
		tm.outer_radius = 1.8
		tm.rings = 24
		tm.ring_segments = 4
		mi.mesh = tm
		mi.scale = Vector3(1.0, 0.25, 0.4)
		mi.rotation = Vector3(0, 0, 0)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.6, 0.85, 1.0, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.disable_fog = true
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

	func _physics_process(delta: float) -> void:
		global_position += dir * speed * delta
		life -= delta
		mi.scale = mi.scale.lerp(Vector3(1.6, 0.25, 0.5), 3.0 * delta)
		(mi.material_override as StandardMaterial3D).albedo_color.a = clampf(life / 0.75, 0, 1) * 0.85
		for e in get_tree().get_nodes_in_group("hittable"):
			var n := e as Node3D
			if n == null or n in hit_list or not n.has_method("take_hit"):
				continue
			if n.has_method("is_dead") and n.is_dead():
				continue
			var to := n.global_position + Vector3(0, 1.0, 0) - global_position
			if to.length() < 2.6:
				hit_list.append(n)
				n.take_hit(30.0, global_position - dir, owner_player, {"heavy": true, "special": true, "knockback": 5.0})
				Fx.hit(n.global_position + Vector3(0, 1.2, 0), Color(0.6, 0.8, 1.0))
		if life <= 0.0:
			queue_free()
