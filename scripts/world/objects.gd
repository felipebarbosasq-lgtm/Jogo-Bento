class_name WorldObjects
extends RefCounted
## Objetos interativos do mundo: bonecos de treino, pontos de interação,
## santuários de salvamento, armadilhas e marcadores de objetivo.


# ------------------------------------------------------------ boneco de treino
class Dummy:
	extends StaticBody3D
	signal destroyed
	var hp := 30.0
	var hit_radius := 0.4
	var _wobble := 0.0
	var _pivot: Node3D
	var _dead := false

	func _ready() -> void:
		add_to_group("hittable")
		collision_layer = Game.L_WORLD
		_pivot = Node3D.new()
		add_child(_pivot)
		var straw := Props.mat(Color(0.78, 0.66, 0.38), 1.0)
		var wood := Props.mat(Color(0.35, 0.24, 0.14))
		Props.mesh(self, Props.cyl_mesh(0.06, 0.06, 1.0, 6), Vector3(0, 0.5, 0), wood)
		Props.mesh(_pivot, Props.cyl_mesh(0.22, 0.26, 0.9, 8), Vector3(0, 1.3, 0), straw)
		Props.mesh(_pivot, Props.sphere_mesh(0.18, 8, 5), Vector3(0, 1.95, 0), straw)
		Props.mesh(_pivot, Props.box_mesh(Vector3(1.1, 0.08, 0.08)), Vector3(0, 1.55, 0), wood)
		Props.mesh(_pivot, Props.box_mesh(Vector3(0.5, 0.06, 0.3)), Vector3(0, 1.0, 0), Props.mat(Color(0.6, 0.1, 0.1)))
		Props.add_cyl_shape(self, 0.3, 2.0, Vector3(0, 1.0, 0))

	func is_dead() -> bool:
		return _dead

	func take_hit(amount: float, _from: Vector3, _attacker: Node = null, props: Dictionary = {}) -> String:
		if _dead:
			return "none"
		hp -= amount
		_wobble = 1.0 if not props.get("heavy", false) else 1.8
		if hp <= 0.0:
			_dead = true
			remove_from_group("hittable")
			Fx.burst(global_position + Vector3(0, 1.3, 0), Color(0.85, 0.75, 0.45), 30, 5.0)
			Sfx.play_at("fall", global_position, -4.0)
			var tw := create_tween()
			tw.tween_property(_pivot, "rotation:x", 1.5, 0.4)
			tw.tween_property(_pivot, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
			destroyed.emit()
			return "dead"
		return "hit"

	func _process(delta: float) -> void:
		if _wobble > 0.0:
			_wobble = maxf(0.0, _wobble - delta * 2.5)
			_pivot.rotation.x = sin(_wobble * 18.0) * 0.25 * _wobble


# ------------------------------------------------------------- interação
class Interactable:
	extends Node3D
	var prompt := "Interagir"
	var radius := 2.2
	var enabled := true
	var one_shot := true
	var on_use: Callable
	var _marker: MeshInstance3D
	var _t := 0.0

	func _ready() -> void:
		add_to_group("interactable")
		_marker = MeshInstance3D.new()
		_marker.mesh = Props.prism_mesh(Vector3(0.25, 0.3, 0.06))
		_marker.material_override = Props.mat(Color(1.0, 0.85, 0.4), 0.3, 0.0, 2.5)
		_marker.rotation.z = PI
		_marker.position = Vector3(0, 2.4, 0)
		_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_marker)

	func _process(delta: float) -> void:
		_t += delta
		_marker.visible = enabled
		_marker.position.y = 2.4 + sin(_t * 3.0) * 0.1
		_marker.rotation.y += delta * 2.0

	func use(player: Node) -> void:
		if not enabled:
			return
		if one_shot:
			enabled = false
		if on_use.is_valid():
			on_use.call(player)


# ----------------------------------------------------- santuário (checkpoint)
class Shrine:
	extends Node3D
	signal activated
	var radius := 2.6
	var active := false
	var _flame: MeshInstance3D
	var _light: OmniLight3D

	func _ready() -> void:
		var stone := Props.mat(Color(0.45, 0.45, 0.47), 1.0)
		var b := Props.body(self, Vector3.ZERO)
		Props.mesh(b, Props.box_mesh(Vector3(1.2, 0.25, 1.2)), Vector3(0, 0.12, 0), stone)
		Props.mesh(b, Props.cyl_mesh(0.18, 0.22, 1.0, 6), Vector3(0, 0.75, 0), stone)
		Props.mesh(b, Props.box_mesh(Vector3(0.8, 0.14, 0.8)), Vector3(0, 1.3, 0), stone)
		Props.mesh(b, Props.cyl_mesh(0.05, 0.62, 0.4, 4), Vector3(0, 1.95, 0), stone, Vector3(0, PI / 4, 0))
		Props.add_box_shape(b, Vector3(0.9, 2.0, 0.9), Vector3(0, 1.0, 0))
		_flame = Props.mesh(self, Props.box_mesh(Vector3(0.4, 0.4, 0.4)), Vector3(0, 1.58, 0), Props.mat(Color(0.35, 0.55, 0.95), 0.5, 0.0, 1.2))
		_light = OmniLight3D.new()
		_light.light_color = Color(0.4, 0.6, 1.0)
		_light.light_energy = 0.6
		_light.omni_range = 6.0
		_light.position = Vector3(0, 1.6, 0)
		add_child(_light)

	func _process(_delta: float) -> void:
		if active:
			return
		var p = Game.player
		if is_instance_valid(p) and p.global_position.distance_to(global_position) < radius:
			activate()

	func activate(silent := false) -> void:
		if active:
			return
		active = true
		_flame.material_override = Props.mat(Color(1.0, 0.7, 0.3), 0.5, 0.0, 4.0)
		_light.light_color = Color(1.0, 0.65, 0.3)
		_light.light_energy = 1.8
		if not silent:
			Sfx.play("checkpoint", -2.0, 0.0)
			Fx.burst(global_position + Vector3(0, 1.6, 0), Color(1, 0.75, 0.35), 30, 4.0)
			activated.emit()


# ------------------------------------------------------------- armadilhas
class SpikeTrap:
	extends Node3D
	var size := Vector2(2.4, 2.4)
	var period := 3.0
	var offset := 0.0
	var damage := 14.0
	var _t := 0.0
	var _spikes: Node3D
	var _hurt_cd := 0.0
	var _phase := "down"

	func _ready() -> void:
		_t = offset
		var base := Props.mat(Color(0.2, 0.18, 0.17), 0.9)
		Props.mesh(self, Props.box_mesh(Vector3(size.x, 0.06, size.y)), Vector3(0, 0.03, 0), base)
		_spikes = Node3D.new()
		add_child(_spikes)
		var metal := Props.mat(Color(0.6, 0.6, 0.62), 0.3, 0.8)
		var nx := int(size.x / 0.4)
		var nz := int(size.y / 0.4)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Props.cyl_mesh(0.0, 0.07, 0.6, 4)
		mm.instance_count = nx * nz
		for i in nx:
			for k in nz:
				mm.set_instance_transform(i * nz + k, Transform3D(Basis(), Vector3(-size.x / 2 + 0.2 + i * 0.4, 0.3, -size.y / 2 + 0.2 + k * 0.4)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = metal
		_spikes.add_child(mmi)
		_spikes.position.y = -0.62

	func _physics_process(delta: float) -> void:
		_t += delta
		_hurt_cd -= delta
		var c := fmod(_t, period)
		var warn := period * 0.55
		var up := period * 0.7
		var target_y := -0.62
		var new_phase := "down"
		if c > up:
			target_y = 0.0
			new_phase = "up"
		elif c > warn:
			target_y = -0.5 + sin(c * 60.0) * 0.03
			new_phase = "warn"
		if new_phase == "up" and _phase != "up":
			Sfx.play_at("trap", global_position, -2.0)
		elif new_phase == "warn" and _phase == "down":
			Fx.dust(global_position, Color(0.5, 0.45, 0.4, 0.5), 8)
		_phase = new_phase
		_spikes.position.y = lerpf(_spikes.position.y, target_y, clampf(delta * 30.0, 0, 1))
		if _phase == "up" and _hurt_cd <= 0.0:
			var p = Game.player
			if is_instance_valid(p):
				var lp: Vector3 = to_local(p.global_position)
				if absf(lp.x) < size.x / 2 + 0.2 and absf(lp.z) < size.y / 2 + 0.2 and lp.y < 1.0:
					var r: String = p.take_hit(damage, p.global_position + Vector3(0, -1, 0), null, "trap")
					if r == "hit":
						_hurt_cd = 1.0


class Pendulum:
	extends Node3D
	var length := 4.5
	var amp := 1.1
	var speed := 1.6
	var offset := 0.0
	var damage := 18.0
	var _t := 0.0
	var _arm: Node3D
	var _blade: Node3D
	var _hurt_cd := 0.0
	var _last_sign := 0.0

	func _ready() -> void:
		_t = offset
		var wood := Props.mat(Color(0.25, 0.16, 0.1))
		Props.mesh(self, Props.box_mesh(Vector3(0.3, 0.3, 4.0)), Vector3(0, 0, 0), wood)
		_arm = Node3D.new()
		add_child(_arm)
		Props.mesh(_arm, Props.cyl_mesh(0.03, 0.03, length, 4), Vector3(0, -length / 2, 0), Props.mat(Color(0.3, 0.3, 0.32), 0.4, 0.7))
		_blade = Node3D.new()
		_blade.position = Vector3(0, -length, 0)
		_arm.add_child(_blade)
		var metal := Props.mat(Color(0.75, 0.75, 0.8), 0.2, 0.9)
		Props.mesh(_blade, Props.cyl_mesh(0.9, 0.9, 0.05, 16), Vector3.ZERO, metal, Vector3(0, 0, PI / 2), Vector3(1, 1, 0.5))
		Props.mesh(_blade, Props.box_mesh(Vector3(0.12, 0.5, 0.5)), Vector3(0, 0.3, 0), Props.mat(Color(0.2, 0.2, 0.22), 0.5, 0.5))

	func _physics_process(delta: float) -> void:
		_t += delta
		_hurt_cd -= delta
		var a := sin(_t * speed) * amp
		_arm.rotation.x = a
		var sg := signf(cos(_t * speed))
		if sg != _last_sign:
			_last_sign = sg
			Sfx.play_at("swing_heavy", _blade.global_position, -8.0, 0.2)
		var p = Game.player
		if is_instance_valid(p) and _hurt_cd <= 0.0:
			var bp := _blade.global_position
			var pp: Vector3 = p.global_position + Vector3(0, 0.9, 0)
			var lp := to_local(pp) - to_local(bp)
			if absf(lp.x) < 0.5 and Vector2(lp.y, lp.z).length() < 1.1:
				var r: String = p.take_hit(damage, bp, null, "trap")
				if r == "hit":
					_hurt_cd = 1.0
					p.velocity += (global_transform.basis.z * signf(cos(_t * speed))) * 6.0


class ArrowTrap:
	extends Node3D
	var interval := 2.2
	var offset := 0.0
	var damage := 10.0
	var _t := 0.0
	var active := true

	func _ready() -> void:
		_t = offset
		var stone := Props.mat(Color(0.35, 0.33, 0.32), 1.0)
		var b := Props.body(self, Vector3.ZERO)
		Props.mesh(b, Props.box_mesh(Vector3(0.8, 2.2, 0.8)), Vector3(0, 1.1, 0), stone)
		Props.mesh(b, Props.box_mesh(Vector3(0.3, 0.3, 0.1)), Vector3(0, 1.2, -0.41), Props.mat(Color(0.05, 0.05, 0.05)))
		Props.mesh(b, Props.box_mesh(Vector3(0.6, 0.15, 0.1)), Vector3(0, 1.75, -0.41), Props.mat(Color(0.8, 0.15, 0.1), 0.5, 0.0, 1.0))
		Props.add_box_shape(b, Vector3(0.8, 2.2, 0.8), Vector3(0, 1.1, 0))

	func _physics_process(delta: float) -> void:
		if not active:
			return
		_t += delta
		if _t >= interval:
			_t = 0.0
			var p = Game.player
			if is_instance_valid(p) and p.global_position.distance_to(global_position) < 24.0:
				var a := Enemy.Arrow.new()
				a.damage = damage
				if is_instance_valid(Game.level):
					Game.level.add_child(a)
					var from := global_position + Vector3(0, 1.2, 0) - global_transform.basis.z * 0.6
					a.launch(from, -global_transform.basis.z, 20.0)
					Sfx.play_at("bow", from, -6.0)


# --------------------------------------------------------- marcador objetivo
class Beacon:
	extends Node3D
	var color := Color(1.0, 0.8, 0.35)
	var _t := 0.0
	var _mi: MeshInstance3D

	func _ready() -> void:
		_mi = MeshInstance3D.new()
		_mi.mesh = Props.cyl_mesh(0.25, 0.25, 30.0, 8)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(color.r, color.g, color.b, 0.18)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.disable_fog = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mi.material_override = m
		_mi.position.y = 15.0
		_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_mi)

	func _process(delta: float) -> void:
		_t += delta
		_mi.scale = Vector3.ONE * (1.0 + sin(_t * 2.0) * 0.15)
		var p = Game.player
		if is_instance_valid(p):
			var d: float = p.global_position.distance_to(global_position)
			visible = d > 3.0
