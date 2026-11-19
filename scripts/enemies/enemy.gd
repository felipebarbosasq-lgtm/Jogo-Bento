class_name Enemy
extends CharacterBody3D
## IA base dos inimigos: patrulha, detecção (distância + campo de visão + linha
## de visada), perseguição com área limitada (leash), ataque, defesa ocasional,
## reação a golpes, atordoamento ao ser aparado e retorno à patrulha.

signal died(enemy: Enemy)

const TYPES := {
	"training": {
		"name": "Recruta", "hp": 30.0, "walk": 1.6, "run": 3.6, "dmg": 6.0, "range": 1.9,
		"cd": Vector2(2.4, 3.4), "block": 0.0, "view": 16.0, "fov": 140.0, "leash": 30.0,
		"poise": 0.0, "windup": 0.8, "combo": 1, "ranged": false,
		"look": {"helmet": "jingasa", "hair_style": "none", "armor": Color(0.36, 0.3, 0.22), "armor2": Color(0.3, 0.25, 0.18), "trim": Color(0.2, 0.25, 0.4), "cloth": Color(0.18, 0.2, 0.3), "hakama": Color(0.16, 0.17, 0.24), "mon": false, "skin": Color(0.82, 0.66, 0.52)},
	},
	"soldier": {
		"name": "Soldado", "hp": 42.0, "walk": 1.8, "run": 4.4, "dmg": 10.0, "range": 2.0,
		"cd": Vector2(1.6, 2.6), "block": 0.15, "view": 16.0, "fov": 120.0, "leash": 24.0,
		"poise": 0.0, "windup": 0.6, "combo": 2, "ranged": false,
		"look": {"helmet": "jingasa", "hair_style": "none", "armor": Color(0.34, 0.27, 0.2), "armor2": Color(0.28, 0.22, 0.16), "trim": Color(0.55, 0.12, 0.1), "cloth": Color(0.2, 0.16, 0.14), "hakama": Color(0.15, 0.13, 0.12), "mon": false, "skin": Color(0.8, 0.63, 0.5)},
	},
	"elite": {
		"name": "Samurai de Elite", "hp": 100.0, "walk": 2.0, "run": 5.0, "dmg": 15.0, "range": 2.2,
		"cd": Vector2(1.1, 2.0), "block": 0.45, "view": 18.0, "fov": 130.0, "leash": 26.0,
		"poise": 28.0, "windup": 0.48, "combo": 3, "ranged": false,
		"look": {"helmet": "kabuto", "mask": true, "armor": Color(0.42, 0.05, 0.06), "armor2": Color(0.12, 0.1, 0.1), "trim": Color(0.08, 0.08, 0.08), "cloth": Color(0.1, 0.08, 0.08), "hakama": Color(0.12, 0.05, 0.05), "crest": Color(0.9, 0.7, 0.2)},
	},
	"archer": {
		"name": "Arqueiro", "hp": 32.0, "walk": 1.8, "run": 4.0, "dmg": 9.0, "range": 1.6,
		"cd": Vector2(2.4, 3.4), "block": 0.05, "view": 24.0, "fov": 150.0, "leash": 28.0,
		"poise": 0.0, "windup": 0.5, "combo": 1, "ranged": true,
		"look": {"helmet": "jingasa", "hair_style": "none", "weapon": "bow", "armor": Color(0.22, 0.3, 0.22), "armor2": Color(0.2, 0.22, 0.16), "trim": Color(0.6, 0.5, 0.2), "cloth": Color(0.2, 0.24, 0.18), "hakama": Color(0.14, 0.16, 0.12), "mon": false, "skin": Color(0.78, 0.6, 0.46)},
	},
}

var type_id := "soldier"
var data: Dictionary = {}
var display_name := ""
var max_hp := 40.0
var hp := 40.0
var hit_radius := 0.45
var model: CharacterModel

var state := "patrol"
var state_time := 0.0
var home := Vector3.ZERO
var patrol_points: Array = []
var patrol_idx := 0
var patrol_wait := 0.0
var aggro := false
var lost_time := 0.0
var attack_cd := 1.0
var combo_left := 0
var cur_attack: Dictionary = {}
var hit_done := false
var poise_acc := 0.0
var strafe_dir := 1.0
var strafe_timer := 0.0
var _see_timer := 0.0
var _can_see := false
var leash := 24.0
var stationary := false     # não patrulha (ex.: arqueiro numa torre)
var drop_chance := 0.3
var is_boss := false
var speed_mult := 1.0
var stun_time := 1.7
var override_velocity := false   # estados especiais controlam a velocidade diretamente

var _bar: Node3D
var _bar_fill: MeshInstance3D
var _bar_timer := 0.0


func configure(t: String, pos: Vector3, points: Array = [], yaw := 0.0) -> Enemy:
	type_id = t
	position = pos
	home = pos
	patrol_points = points
	rotation.y = yaw
	return self


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("hittable")
	data = TYPES.get(type_id, TYPES.soldier)
	_init_stats()
	collision_layer = Game.L_ENEMY
	collision_mask = Game.L_WORLD | Game.L_PLAYER
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36 * _scale()
	cap.height = 1.8 * _scale()
	cs.shape = cap
	cs.position = Vector3(0, 0.9 * _scale(), 0)
	add_child(cs)
	model = CharacterModel.new()
	add_child(model)
	model.setup(_look())
	if home == Vector3.ZERO:
		home = global_position
	attack_cd = randf_range(0.6, 1.4)
	strafe_dir = 1.0 if randf() < 0.5 else -1.0
	_build_bar()
	if patrol_points.is_empty() and not stationary:
		for i in 3:
			var a := randf() * TAU
			patrol_points.append(home + Vector3(cos(a), 0, sin(a)) * randf_range(2.5, 5.0))


func _init_stats() -> void:
	display_name = data.name
	max_hp = data.hp
	hp = max_hp
	leash = data.leash


func _look() -> Dictionary:
	return data.look


func _scale() -> float:
	return 1.0


func is_dead() -> bool:
	return state == "dead"


# ------------------------------------------------------------ barra de vida
func _build_bar() -> void:
	if is_boss:
		return
	_bar = Node3D.new()
	_bar.position = Vector3(0, 2.35 * _scale(), 0)
	add_child(_bar)
	var bg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.09)
	bg.mesh = q
	bg.material_override = Props.unshaded(Color(0, 0, 0, 0.6))
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.add_child(bg)
	_bar_fill = MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(0.86, 0.06)
	_bar_fill.mesh = q2
	_bar_fill.material_override = Props.unshaded(Color(0.85, 0.12, 0.1, 0.95))
	_bar_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar_fill.position.z = 0.002
	_bar.add_child(_bar_fill)
	_bar.visible = false


func _update_bar(delta: float) -> void:
	if _bar == null:
		return
	_bar_timer -= delta
	var show := state != "dead" and (hp < max_hp or aggro) and _bar_timer > -6.0
	_bar.visible = show
	if not show:
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		var dir := cam.global_position - _bar.global_position
		dir.y = 0
		if dir.length() > 0.01:
			_bar.global_rotation = Vector3(0, atan2(dir.x, dir.z), 0)
	var r := clampf(hp / max_hp, 0.0, 1.0)
	_bar_fill.scale.x = maxf(r, 0.001)
	_bar_fill.position.x = -0.43 * (1.0 - r)


# --------------------------------------------------------------- percepção
func _player() -> Player:
	var p = Game.player
	if is_instance_valid(p) and p is Player:
		return p
	return null


func _check_sight(p: Player) -> bool:
	var to := p.global_position - global_position
	var dist := to.length()
	var view: float = data.view
	if dist > view:
		return false
	if dist > 3.5:
		var fwd := -global_transform.basis.z
		var flat := Vector3(to.x, 0, to.z).normalized()
		var fov: float = data.fov
		if not aggro and rad_to_deg(fwd.angle_to(flat)) > fov * 0.5:
			return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.6, 0), p.global_position + Vector3(0, 1.3, 0), Game.L_WORLD)
	var hit := space.intersect_ray(q)
	return hit.is_empty()


func alert(propagate := true) -> void:
	if state == "dead":
		return
	var was := aggro
	aggro = true
	lost_time = 0.0
	if not was:
		if state in ["patrol", "return", "idle"]:
			_set_state("alert")
		if propagate:
			for e in get_tree().get_nodes_in_group("enemies"):
				if e != self and is_instance_valid(e) and e is Enemy and (e as Enemy).global_position.distance_to(global_position) < 12.0:
					(e as Enemy).alert(false)


func _set_state(s: String) -> void:
	state = s
	state_time = 0.0


# --------------------------------------------------------------------- IA
func _physics_process(delta: float) -> void:
	state_time += delta
	_update_bar(delta)
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.5
	if state == "dead":
		velocity.x = move_toward(velocity.x, 0, 10 * delta)
		velocity.z = move_toward(velocity.z, 0, 10 * delta)
		move_and_slide()
		return
	if Game.cutscene:
		velocity.x = 0
		velocity.z = 0
		model.move_speed = 0.0
		move_and_slide()
		return
	attack_cd -= delta
	var p := _player()
	_see_timer -= delta
	if _see_timer <= 0.0:
		_see_timer = 0.2
		_can_see = p != null and not p.is_dead() and _check_sight(p)
		if _can_see and not aggro:
			alert()
	var move := Vector3.ZERO
	var spd := 0.0
	var face_target := Vector3.INF

	if p and p.is_dead() and aggro and state not in ["hurt", "stunned"]:
		aggro = false
		_set_state("return")

	match state:
		"patrol":
			if stationary or patrol_points.is_empty():
				pass
			elif patrol_wait > 0.0:
				patrol_wait -= delta
			else:
				var tgt: Vector3 = patrol_points[patrol_idx]
				var to := tgt - global_position
				to.y = 0
				if to.length() < 0.6:
					patrol_idx = (patrol_idx + 1) % patrol_points.size()
					patrol_wait = randf_range(1.0, 3.0)
				else:
					move = to.normalized()
					spd = float(data.walk)
		"alert":
			if p:
				face_target = p.global_position
			if state_time > 0.45:
				_set_state("chase")
		"chase":
			if p == null:
				_set_state("return")
			else:
				var r := _chase(p, delta)
				move = r[0]
				spd = r[1]
				face_target = p.global_position
		"attack":
			_update_attack(p, delta)
			if p and state_time < float(cur_attack.get("windup", 0.5)) * 0.8:
				face_target = p.global_position
			var lunge: float = cur_attack.get("lunge", 2.0)
			var w: float = cur_attack.get("windup", 0.5)
			if state_time > w - 0.12 and state_time < w + 0.1:
				move = -global_transform.basis.z
				spd = lunge
		"block":
			if p:
				face_target = p.global_position
			if state_time > 0.7:
				model.clear_action()
				_set_state("chase")
		"hurt":
			if state_time > 0.45:
				_set_state("chase" if aggro else "return")
		"stunned":
			if state_time > stun_time:
				model.clear_action()
				_set_state("chase")
		"return":
			var to := home - global_position
			to.y = 0
			if to.length() < 0.8:
				_set_state("patrol")
				hp = max_hp
			else:
				move = to.normalized()
				spd = float(data.walk) * 1.3
			if _can_see and p and p.global_position.distance_to(home) < leash * 0.8:
				alert(false)
				_set_state("chase")
		"shoot":
			if p:
				face_target = p.global_position
			_update_shoot(p, delta)
		_:
			_custom_state(p, delta)

	# separação entre inimigos
	var sep := Vector3.ZERO
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not is_instance_valid(e):
			continue
		var o := e as Node3D
		var d := global_position - o.global_position
		d.y = 0
		var l := d.length()
		if l < 1.3 and l > 0.001:
			sep += d / l * (1.3 - l)
	spd *= speed_mult
	var desired := move * spd + sep * 2.5
	var hv := Vector3(velocity.x, 0, velocity.z)
	if override_velocity:
		override_velocity = false
	elif state in ["hurt", "stunned"]:
		hv = hv.lerp(Vector3.ZERO, clampf(6.0 * delta, 0, 1))
		velocity.x = hv.x
		velocity.z = hv.z
	else:
		hv = hv.lerp(desired, clampf(10.0 * delta, 0, 1))
		velocity.x = hv.x
		velocity.z = hv.z
	move_and_slide()

	if face_target != Vector3.INF:
		var to := face_target - global_position
		if Vector2(to.x, to.z).length() > 0.05:
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(9.0 * delta, 0, 1))
	elif move.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-move.x, -move.z), clampf(7.0 * delta, 0, 1))
	model.move_speed = Vector2(velocity.x, velocity.z).length() if state in ["patrol", "chase", "return", "alert"] else 0.0


func _chase(p: Player, delta: float) -> Array:
	var to := p.global_position - global_position
	to.y = 0
	var dist := to.length()
	var dir := to.normalized() if dist > 0.01 else Vector3.ZERO
	# abandona a perseguição fora da área limitada
	if p.global_position.distance_to(home) > leash or global_position.distance_to(home) > leash + 4.0:
		aggro = false
		_set_state("return")
		return [Vector3.ZERO, 0.0]
	if not _can_see:
		lost_time += delta
		if lost_time > 5.0:
			aggro = false
			_set_state("return")
			return [Vector3.ZERO, 0.0]
	else:
		lost_time = 0.0
	if data.ranged:
		return _chase_ranged(p, dist, dir, delta)
	var rng: float = data.range
	strafe_timer -= delta
	if strafe_timer <= 0.0:
		strafe_timer = randf_range(1.5, 3.0)
		strafe_dir = -strafe_dir
	# defesa proativa quando o jogador ataca
	if p.is_attacking() and dist < 3.2 and randf() < float(data.block) * delta * 6.0:
		_start_block()
		return [Vector3.ZERO, 0.0]
	if attack_cd <= 0.0 and dist < rng + 2.5 and _attack_slot_free():
		if dist <= rng + 0.3:
			_start_attack()
			return [Vector3.ZERO, 0.0]
		return [dir, float(data.run)]
	if dist > 3.6:
		return [dir, float(data.run) if dist > 6.0 else float(data.walk) * 1.4]
	# circula o jogador mantendo distância
	var side := Vector3(-dir.z, 0, dir.x) * strafe_dir
	var keep := (dist - 2.9) * 0.8
	return [(side + dir * keep).normalized(), float(data.walk) * 0.8]


func _chase_ranged(p: Player, dist: float, dir: Vector3, delta: float) -> Array:
	if dist < 2.4 and attack_cd <= 0.0:
		_start_attack()
		return [Vector3.ZERO, 0.0]
	if dist < 6.0 and not stationary:
		return [-dir, float(data.walk) * 1.2]
	if attack_cd <= 0.0 and _can_see and dist < float(data.view):
		_set_state("shoot")
		model.play("aim", 0.9)
		hit_done = false
		return [Vector3.ZERO, 0.0]
	if dist > 15.0 and not stationary:
		return [dir, float(data.walk)]
	strafe_timer -= delta
	if strafe_timer <= 0.0:
		strafe_timer = randf_range(1.5, 3.0)
		strafe_dir = -strafe_dir
	if stationary:
		return [Vector3.ZERO, 0.0]
	return [Vector3(-dir.z, 0, dir.x) * strafe_dir, float(data.walk) * 0.6]


func _attack_slot_free() -> bool:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and is_instance_valid(e) and (e as Enemy).state == "attack":
			n += 1
	return n < 2 or is_boss


# ------------------------------------------------------------------ ataque
func _start_attack() -> void:
	combo_left = randi_range(1, int(data.combo)) - 1
	_begin_attack_step(0)


func _attack_spec(step: int) -> Dictionary:
	var anims := ["attack1", "attack2", "attack3"]
	var anim: String = anims[step % 3]
	var w: float = data.windup * (1.0 if step == 0 else 0.75)
	var frac := {"attack1": 0.5, "attack2": 0.48, "attack3": 0.45, "heavy": 0.58}
	return {"anim": anim, "windup": w, "dur": w / float(frac[anim]), "dmg": float(data.dmg), "range": float(data.range) + 0.6, "arc": 70.0, "kind": "melee", "lunge": 2.5, "step": step}


func _begin_attack_step(step: int) -> void:
	cur_attack = _attack_spec(step)
	hit_done = false
	_set_state("attack")
	model.play(str(cur_attack.anim), float(cur_attack.dur))
	if step == 0:
		_glint()


func _glint() -> void:
	## Brilho na lâmina: aviso visual do ataque (ajuda a cronometrar o aparar).
	if is_instance_valid(model.weapon_tip):
		Fx.sparks(model.weapon_tip.global_position, Color(1, 1, 0.85), 6)


func _update_attack(p: Player, delta: float) -> void:
	var w: float = cur_attack.windup
	if not hit_done and state_time >= w:
		hit_done = true
		Sfx.play_at("swing_light" if cur_attack.kind != "heavy" else "swing_heavy", global_position + Vector3(0, 1.2, 0), -3.0)
		Fx.slash(self, Vector3(0, 1.1 * _scale(), -0.3), 1.0 if cur_attack.step % 2 == 0 else -1.0, float(cur_attack.range) * 0.8, Color(1.0, 0.55, 0.45, 0.7), 0.18)
		_on_attack_hit(p)
		if state != "attack":
			return
	var dur: float = cur_attack.dur
	if state_time >= dur * 0.85:
		if combo_left > 0 and p and global_position.distance_to(p.global_position) < float(cur_attack.range) + 1.5:
			combo_left -= 1
			_begin_attack_step(int(cur_attack.step) + 1)
		else:
			var cd: Vector2 = data.cd
			attack_cd = randf_range(cd.x, cd.y)
			_set_state("chase")


func _on_attack_hit(p: Player) -> void:
	if p == null:
		return
	var to := p.global_position - global_position
	if absf(to.y) > 2.0:
		return
	to.y = 0
	var d := to.length()
	if d > float(cur_attack.range):
		return
	if d > 0.5 and rad_to_deg((-global_transform.basis.z).angle_to(to.normalized())) > float(cur_attack.arc):
		return
	var res := p.take_hit(float(cur_attack.dmg), global_position, self, str(cur_attack.kind))
	if res == "blocked":
		velocity += -to.normalized() * 2.0


func _update_shoot(p: Player, delta: float) -> void:
	if not hit_done and state_time >= 0.9:
		hit_done = true
		if p:
			_fire_arrow(p)
		model.play("shoot", 0.4)
	if state_time > 1.4:
		var cd: Vector2 = data.cd
		attack_cd = randf_range(cd.x, cd.y)
		_set_state("chase")


func _fire_arrow(p: Player) -> void:
	var from := global_position + Vector3(0, 1.45, 0) - global_transform.basis.z * 0.5
	var target := p.global_position + Vector3(0, 1.1, 0) + p.velocity * 0.25
	var a := Arrow.new()
	a.shooter = self
	a.damage = data.dmg
	if is_instance_valid(Game.level):
		Game.level.add_child(a)
		a.launch(from, (target - from).normalized(), 26.0)
		Sfx.play_at("bow", from, -2.0)


func _custom_state(_p: Player, _delta: float) -> void:
	_set_state("chase")


# --------------------------------------------------------------- receber dano
func _start_block() -> void:
	_set_state("block")
	model.play("block", 0.2)


func take_hit(amount: float, from_pos: Vector3, attacker: Node = null, props: Dictionary = {}) -> String:
	if state == "dead":
		return "none"
	alert()
	_bar_timer = 0.0
	var heavy: bool = props.get("heavy", false)
	var special: bool = props.get("special", false)
	var to := from_pos - global_position
	to.y = 0
	var facing := (-global_transform.basis.z).dot(to.normalized()) > 0.2
	if not special and facing:
		if state == "block":
			if heavy:
				_guard_break()
				_damage(amount * 0.5, from_pos, 0.0)
				return "guard_break"
			Fx.sparks(global_position + Vector3(0, 1.3, 0) + to.normalized() * 0.4)
			return "blocked"
		if state in ["chase", "alert", "patrol", "return"] and not heavy and randf() < float(data.block):
			_start_block()
			return "blocked"
	var mult := 1.5 if state == "stunned" else 1.0
	var kb: float = props.get("knockback", 1.5)
	return _damage(amount * mult, from_pos, kb, heavy or special)


func _damage(amount: float, from_pos: Vector3, kb: float, force_stagger := false) -> String:
	hp -= amount
	model.flash(Color(1, 0.3, 0.3), 0.1)
	if hp <= 0.0:
		_die(from_pos)
		return "dead"
	var push := global_position - from_pos
	push.y = 0
	velocity += push.normalized() * kb
	poise_acc += amount
	var poise: float = data.poise
	if state == "stunned":
		pass
	elif force_stagger or poise_acc >= poise:
		poise_acc = 0.0
		if state != "attack" or poise <= 0.0 or force_stagger:
			_set_state("hurt")
			model.play("hurt", 0.45)
	return "hit"


func _guard_break() -> void:
	_set_state("stunned")
	model.play("guard_break", 1.2)
	Sfx.play_at("clash", global_position + Vector3(0, 1.3, 0), 3.0)


func on_parried() -> void:
	## Chamado pelo jogador quando apara um golpe deste inimigo.
	if state == "dead":
		return
	_set_state("stunned")
	poise_acc = 0.0
	model.play("stunned", stun_time)
	model.flash(Color(1, 1, 0.6), 0.15)
	velocity += global_transform.basis.z * 3.0


func _die(from_pos: Vector3) -> void:
	_set_state("dead")
	hp = 0.0
	remove_from_group("hittable")
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = Game.L_WORLD
	var push := global_position - from_pos
	push.y = 0
	velocity = push.normalized() * 3.0
	model.play("dead", 0.8)
	if _bar:
		_bar.visible = false
	Sfx.play_at("fall", global_position, 0.0)
	died.emit(self)
	if randf() < drop_chance and is_instance_valid(Game.level):
		var orb := HealthOrb.new()
		Game.level.add_child(orb)
		orb.global_position = global_position + Vector3(0, 0.8, 0)
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(self, "scale", Vector3(1, 0.01, 1), 0.8)
	tw.tween_callback(queue_free)


# ================================================================ projéteis
class Arrow:
	extends Node3D
	var shooter: Node
	var damage := 9.0
	var vel := Vector3.ZERO
	var life := 3.0
	var stuck := false
	var _parried := false

	func _ready() -> void:
		var wood := Props.mat(Color(0.5, 0.36, 0.2))
		Props.mesh(self, Props.cyl_mesh(0.012, 0.012, 0.8, 4), Vector3(0, 0, 0), wood, Vector3(PI / 2, 0, 0))
		Props.mesh(self, Props.cyl_mesh(0.0, 0.03, 0.09, 4), Vector3(0, 0, -0.44), Props.mat(Color(0.6, 0.6, 0.65), 0.3, 0.8), Vector3(-PI / 2, 0, 0))
		Props.mesh(self, Props.box_mesh(Vector3(0.06, 0.005, 0.12)), Vector3(0, 0, 0.36), Props.mat(Color(0.9, 0.9, 0.85)))
		Props.mesh(self, Props.box_mesh(Vector3(0.005, 0.06, 0.12)), Vector3(0, 0, 0.36), Props.mat(Color(0.9, 0.9, 0.85)))

	func launch(from: Vector3, dir: Vector3, speed: float) -> void:
		global_position = from
		vel = dir * speed
		look_at(from + dir, Vector3.UP)

	func _physics_process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		if stuck:
			return
		vel.y -= 3.0 * delta
		var from := global_position
		var to := from + vel * delta
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(from, to, Game.L_WORLD | Game.L_PLAYER)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var col = hit.collider
			if col is Player:
				var res: String = (col as Player).take_hit(damage, from - vel.normalized() * 2.0, null, "arrow")
				if res == "dodged":
					global_position = to
					return
				if res == "parried" or res == "blocked":
					Sfx.play_at("block", hit.position, -4.0)
					queue_free()
					return
				queue_free()
				return
			global_position = hit.position
			stuck = true
			life = 2.0
			Sfx.play_at("arrow_hit", hit.position, -8.0)
			return
		global_position = to
		if vel.length() > 0.1:
			look_at(global_position + vel, Vector3.UP)


class HealthOrb:
	extends Node3D
	var heal := 25.0
	var _t := 0.0
	var _mi: MeshInstance3D

	func _ready() -> void:
		_mi = Props.mesh(self, Props.sphere_mesh(0.16, 10, 6), Vector3.ZERO, Props.mat(Color(0.3, 1.0, 0.5), 0.3, 0.0, 3.0))
		if Game.quality_level() >= 2:
			var l := OmniLight3D.new()
			l.light_color = Color(0.3, 1.0, 0.5)
			l.light_energy = 0.8
			l.omni_range = 2.5
			add_child(l)

	func _process(delta: float) -> void:
		_t += delta
		_mi.position.y = sin(_t * 3.0) * 0.12
		_mi.rotation.y += delta * 2.0
		var p = Game.player
		if is_instance_valid(p) and not p.is_dead():
			var d: float = (p.global_position + Vector3(0, 0.8, 0)).distance_to(global_position)
			if d < 4.0 and p.hp < p.max_hp:
				global_position = global_position.move_toward(p.global_position + Vector3(0, 0.8, 0), delta * 6.0)
			if d < 0.9 and p.hp < p.max_hp:
				p.hp = minf(p.max_hp, p.hp + heal)
				Sfx.play("pickup", -6.0)
				Fx.burst(global_position, Color(0.3, 1.0, 0.5), 16, 3.0)
				queue_free()
		if _t > 40.0:
			queue_free()
