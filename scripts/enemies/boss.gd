class_name Boss
extends Enemy
## Chefes com padrões de combate próprios:
##  - "raiga": General Raiga (miniboss da Fase 4) — combos, investida e golpe sísmico.
##  - "akuma": Lorde Akuma (chefe final) — duas etapas; na segunda ganha
##    teleporte, ondas de sangue e pilares da Lua Sangrenta.

signal phase_changed(phase: int)

const BOSSES := {
	"raiga": {
		"name": "General Raiga, a Lâmina do Trovão", "hp": 430.0, "walk": 2.2, "run": 5.2, "dmg": 15.0, "range": 2.6,
		"cd": Vector2(0.9, 1.7), "block": 0.25, "view": 40.0, "fov": 360.0, "leash": 999.0,
		"poise": 70.0, "windup": 0.55, "combo": 3, "ranged": false, "scale": 1.2,
		"look": {"helmet": "hood", "hair_style": "none", "weapon": "scimitar", "dual": true, "eyes": Color(0.5, 0.8, 1.0), "armor": Color(0.32, 0.4, 0.5), "armor2": Color(0.18, 0.22, 0.28), "trim": Color(0.25, 0.17, 0.1), "cloth": Color(0.05, 0.05, 0.07), "hakama": Color(0.06, 0.06, 0.08), "crest": Color(0.6, 0.62, 0.66), "cape": true, "cape_color": Color(0.05, 0.05, 0.07), "straps": true, "mon": false, "blade_color": Color(0.62, 0.72, 0.82), "blade_glow": 0.15},
	},
	"akuma": {
		"name": "Lorde Akuma, o Guerreiro da Lua Sangrenta", "hp": 820.0, "walk": 2.3, "run": 5.6, "dmg": 17.0, "range": 2.8,
		"cd": Vector2(0.8, 1.5), "block": 0.3, "view": 50.0, "fov": 360.0, "leash": 999.0,
		"poise": 95.0, "windup": 0.52, "combo": 4, "ranged": false, "scale": 1.3,
		"look": {"helmet": "oni_crown", "cape": true, "cape_color": Color(0.45, 0.04, 0.06), "weapon": "odachi", "armor": Color(0.2, 0.05, 0.06), "armor2": Color(0.08, 0.05, 0.05), "trim": Color(0.5, 0.05, 0.07), "cloth": Color(0.05, 0.03, 0.04), "hakama": Color(0.06, 0.03, 0.04), "eyes": Color(1.0, 0.12, 0.05), "crest": Color(0.6, 0.05, 0.05), "blade_color": Color(0.95, 0.12, 0.1), "blade_glow": 2.0, "skin": Color(0.62, 0.5, 0.44), "hair_style": "long_silver", "hair": Color(0.82, 0.82, 0.86), "straps": true, "mon": false},
	},
}

var boss_id := "raiga"
var phase := 1
var active := false
var _move_dir := Vector3.ZERO
var _custom_done := false
var _pillar_spots: Array = []
var _shift_done := false


func setup_boss(id: String, pos: Vector3, yaw := 0.0) -> Boss:
	boss_id = id
	is_boss = true
	stationary = true
	drop_chance = 0.0
	configure("soldier", pos, [], yaw)
	return self


func _init_stats() -> void:
	data = BOSSES[boss_id].duplicate(true)
	display_name = data.name
	max_hp = data.hp
	hp = max_hp
	leash = 999.0
	stun_time = 1.25
	hit_radius = 0.7


func _ready() -> void:
	super._ready()
	_set_state("dormant")
	add_to_group("boss")


func _look() -> Dictionary:
	return data.look


func _scale() -> float:
	return float(BOSSES[boss_id].scale)


func activate() -> void:
	active = true
	aggro = true
	_set_state("chase")
	attack_cd = 1.0


func _check_sight(_p: Player) -> bool:
	return active


func alert(_propagate := true) -> void:
	if active:
		aggro = true


func take_hit(amount: float, from_pos: Vector3, attacker: Node = null, props: Dictionary = {}) -> String:
	if not active or state in ["phase_shift", "teleport_out"]:
		return "none"
	var res := super.take_hit(amount, from_pos, attacker, props)
	_check_phase()
	return res


func _check_phase() -> void:
	if phase == 1 and hp <= max_hp * 0.5 and state != "dead":
		phase = 2
		_set_state("phase_shift")
		model.play("cast", 2.6)
		Sfx.play("roar", 2.0, 0.0)
		model.set_aura(true, Color(1.0, 0.1, 0.05) if boss_id == "akuma" else Color(0.4, 0.6, 1.0))
		speed_mult = 1.2
		data.windup = float(data.windup) * 0.8
		var cd: Vector2 = data.cd
		data.cd = cd * 0.75
		phase_changed.emit(2)


func _custom_state(p: Player, delta: float) -> void:
	match state:
		"dormant":
			model.move_speed = 0.0
		"phase_shift":
			if state_time > 2.6:
				model.clear_action()
				_set_state("chase")
				attack_cd = 0.3
				Fx.ring(global_position, 7.0, Color(1, 0.2, 0.1, 0.9), 0.6)
				if p and p.global_position.distance_to(global_position) < 4.5:
					p.take_hit(8.0, global_position, null, "unblockable")
		"dash_wind":
			if p:
				var to := p.global_position - global_position
				rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(10.0 * delta, 0, 1))
			if state_time > float(data.windup) * 1.4:
				_move_dir = -global_transform.basis.z
				_set_state("dash")
				hit_done = false
				model.play("thrust_dash", 0.6)
				Sfx.play_at("swing_heavy", global_position, 2.0)
		"dash":
			velocity.x = _move_dir.x * 14.0
			velocity.z = _move_dir.z * 14.0
			override_velocity = true
			if not hit_done and p and p.global_position.distance_to(global_position) < 1.9 * _scale():
				hit_done = true
				p.take_hit(float(data.dmg) * 1.25, global_position, self, "melee")
			if state_time > 0.42 or (is_on_wall() and state_time > 0.1):
				velocity.x = 0
				velocity.z = 0
				_set_state("recover")
		"recover":
			if state_time > 0.7:
				_end_pattern()
		"slam_wind":
			if state_time >= 0.95 and not hit_done:
				hit_done = true
				var r := 4.8 if phase == 1 else 6.0
				Fx.ring(global_position, r, Color(1.0, 0.6, 0.2, 0.9) if boss_id == "raiga" else Color(1, 0.15, 0.1, 0.9), 0.45)
				Fx.dust(global_position, Color(0.5, 0.45, 0.4, 0.7), 26)
				Sfx.play_at("slam", global_position, 3.0)
				if p:
					p.shake = 0.5
					if p.global_position.distance_to(global_position) < r:
						p.take_hit(22.0, global_position, null, "unblockable")
			if state_time > 1.7:
				_end_pattern()
		"wave_wind":
			if p:
				var to := p.global_position - global_position
				rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(10.0 * delta, 0, 1))
			if state_time >= 0.5 and not hit_done:
				hit_done = true
				var n := 1 if phase == 1 else 3
				for i in n:
					var ang := (i - (n - 1) / 2.0) * 0.32
					var dir := (-global_transform.basis.z).rotated(Vector3.UP, ang)
					var w := BloodWave.new()
					w.dir = dir
					w.damage = 16.0
					if is_instance_valid(Game.level):
						Game.level.add_child(w)
						w.global_position = global_position + Vector3(0, 1.1, 0) + dir * 1.2
						w.rotation.y = atan2(-dir.x, -dir.z)
				Sfx.play_at("special", global_position, -2.0)
			if state_time > 1.2:
				_end_pattern()
		"teleport_out":
			if state_time > 0.6 and p:
				var behind := p.global_position + p.global_transform.basis.z * 2.6
				global_position = Vector3(behind.x, p.global_position.y + 0.2, behind.z)
				var to := p.global_position - global_position
				rotation.y = atan2(-to.x, -to.z)
				model.visible = true
				Fx.burst(global_position + Vector3(0, 1.2, 0), Color(1, 0.1, 0.05), 30, 5.0)
				Sfx.play_at("roar", global_position, -6.0)
				collision_layer = Game.L_ENEMY
				combo_left = 1
				cur_attack = _attack_spec(2)
				cur_attack.windup = 0.6
				cur_attack.dur = 0.6 / 0.58
				hit_done = false
				_set_state("attack")
				model.play("heavy", float(cur_attack.dur))
		"pillars":
			if state_time > 1.3 and not hit_done:
				hit_done = true
				for spot in _pillar_spots:
					var sp: Vector3 = spot
					_pillar_fx(sp)
					if p and Vector2(p.global_position.x - sp.x, p.global_position.z - sp.z).length() < 2.0:
						p.take_hit(20.0, sp, null, "unblockable")
				Sfx.play_at("slam", global_position, 0.0)
				if p:
					p.shake = 0.4
			if state_time > 2.0:
				model.clear_action()
				_end_pattern()
		_:
			_set_state("chase")


func _end_pattern() -> void:
	var cd: Vector2 = data.cd
	attack_cd = randf_range(cd.x, cd.y)
	_set_state("chase")


func _chase(p: Player, delta: float) -> Array:
	var to := p.global_position - global_position
	to.y = 0
	var dist := to.length()
	var dir := to.normalized() if dist > 0.01 else Vector3.ZERO
	if attack_cd <= 0.0:
		_choose_pattern(p, dist)
		if state != "chase":
			return [Vector3.ZERO, 0.0]
	if dist > float(data.range) + 0.8:
		return [dir, float(data.run) if dist > 7.0 else float(data.walk) * 1.5]
	strafe_timer -= delta
	if strafe_timer <= 0.0:
		strafe_timer = randf_range(1.2, 2.4)
		strafe_dir = -strafe_dir
	return [Vector3(-dir.z, 0, dir.x) * strafe_dir, float(data.walk) * 0.7]


func _choose_pattern(p: Player, dist: float) -> void:
	var opts := []   # [nome, peso]
	if dist < float(data.range) + 0.6:
		opts.append(["combo", 5.0])
		opts.append(["slam", 2.0 if boss_id == "raiga" or phase == 2 else 0.0])
	elif dist < 3.8:
		opts.append(["approach_combo", 2.0])
	if dist > 4.0:
		opts.append(["dash", 3.0])
		if boss_id == "akuma":
			opts.append(["wave", 3.0])
	if boss_id == "akuma" and phase == 2:
		opts.append(["teleport", 1.6])
		opts.append(["pillars", 1.6 if dist > 2.5 else 0.6])
	if boss_id == "raiga" and phase == 2 and dist > 3.0:
		opts.append(["slam", 1.0])
	var total := 0.0
	for o in opts:
		total += float(o[1])
	if total <= 0.0:
		return
	var r := randf() * total
	var pick := ""
	for o in opts:
		r -= float(o[1])
		if r <= 0.0:
			pick = o[0]
			break
	match pick:
		"combo":
			_start_attack()
		"approach_combo":
			attack_cd = 0.0
		"dash":
			_set_state("dash_wind")
			model.play("charge", 1.0)
			_glint()
		"slam":
			_set_state("slam_wind")
			hit_done = false
			model.play("heavy", 1.65)
			Fx.telegraph(global_position, 4.8 if phase == 1 else 6.0, 0.95, Color(1.0, 0.25, 0.1, 0.4))
		"wave":
			_set_state("wave_wind")
			hit_done = false
			model.play("attack2", 1.0)
			_glint()
		"teleport":
			_set_state("teleport_out")
			model.visible = false
			collision_layer = 0
			Fx.burst(global_position + Vector3(0, 1.2, 0), Color(1, 0.1, 0.05), 30, 5.0)
			Sfx.play_at("dodge", global_position, 2.0)
		"pillars":
			_set_state("pillars")
			hit_done = false
			model.play("cast", 2.0)
			_pillar_spots.clear()
			var center := p.global_position
			_pillar_spots.append(center)
			for i in 4:
				var a := randf() * TAU
				_pillar_spots.append(center + Vector3(cos(a), 0, sin(a)) * randf_range(2.8, 5.0))
			for sp in _pillar_spots:
				Fx.telegraph(sp, 2.0, 1.3, Color(1.0, 0.05, 0.05, 0.45))
			Sfx.play("roar", -6.0)


func _pillar_fx(pos: Vector3) -> void:
	if not is_instance_valid(Game.level):
		return
	var mi := MeshInstance3D.new()
	mi.mesh = Props.cyl_mesh(1.0, 1.4, 1.0, 12)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.1, 0.06, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_fog = true
	mi.material_override = m
	Game.level.add_child(mi)
	mi.global_position = pos + Vector3(0, 4.0, 0)
	mi.scale = Vector3(1.6, 8.0, 1.6)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(0.1, 9.0, 0.1), 0.5)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(mi.queue_free)
	Fx.burst(pos + Vector3(0, 0.5, 0), Color(1, 0.15, 0.05), 20, 6.0)


func _attack_spec(step: int) -> Dictionary:
	var spec := super._attack_spec(step)
	if step >= 2 and step % 2 == 0:
		spec.anim = "heavy"
		spec.windup = float(data.windup) * 1.1
		spec.dur = float(spec.windup) / 0.58
		spec.dmg = float(data.dmg) * 1.35
		spec.kind = "heavy"
		spec.lunge = 4.0
	spec.range = float(data.range) + 0.8
	return spec


func on_parried() -> void:
	if state in ["phase_shift", "dead"]:
		return
	super.on_parried()


func _die(from_pos: Vector3) -> void:
	_set_state("dead")
	hp = 0.0
	model.set_aura(false)
	remove_from_group("hittable")
	remove_from_group("enemies")
	collision_layer = 0
	model.play("kneel", 1.0)
	Sfx.play("gong", 0.0, 0.0)
	Fx.burst(global_position + Vector3(0, 1.5, 0), Color(1.0, 0.3, 0.2), 60, 7.0)
	died.emit(self)


class BloodWave:
	extends Node3D
	var dir := Vector3.FORWARD
	var damage := 16.0
	var speed := 15.0
	var life := 1.6
	var done := false
	var mi: MeshInstance3D

	func _ready() -> void:
		mi = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.0
		tm.outer_radius = 1.25
		tm.rings = 20
		tm.ring_segments = 4
		mi.mesh = tm
		mi.scale = Vector3(1.0, 0.3, 0.45)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.12, 0.08, 0.9)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.disable_fog = true
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

	func _physics_process(delta: float) -> void:
		global_position += dir * speed * delta
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		var p = Game.player
		if not done and is_instance_valid(p) and not p.is_dead():
			var d: float = (p.global_position + Vector3(0, 1.0, 0)).distance_to(global_position)
			if d < 1.4:
				var res: String = p.take_hit(damage, global_position - dir, null, "melee")
				if res != "dodged":
					done = true
					Fx.sparks(global_position, Color(1, 0.3, 0.2), 20)
					queue_free()
