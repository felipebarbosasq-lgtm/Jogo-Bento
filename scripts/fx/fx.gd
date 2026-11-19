class_name Fx
extends RefCounted
## Efeitos visuais procedurais: faíscas, poeira, rastros de corte, ondas e partículas ambientes.

static var _arc_mesh: ArrayMesh
static var _quad: QuadMesh


static func _root() -> Node:
	if is_instance_valid(Game.level):
		return Game.level
	return null


static func _quad_mesh() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(0.12, 0.12)
	return _quad


static func _particles(pos: Vector3, amount: int, color: Color, lifetime: float, speed: Vector2, size: float, gravity := Vector3(0, -9.8, 0), additive := true, spread := 180.0, dir := Vector3.UP) -> CPUParticles3D:
	var root := _root()
	if root == null:
		return null
	if Game.quality_level() == 0:
		amount = maxi(4, amount / 2)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = lifetime
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	p.mesh = qm
	p.material_override = Props.unshaded(Color.WHITE, additive, true)
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = gravity
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var grad := Gradient.new()
	grad.set_color(0, color)
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = grad
	root.add_child(p)
	p.global_position = pos
	p.emitting = true
	var t := Timer.new()
	t.wait_time = lifetime + 0.5
	t.one_shot = true
	t.autostart = true
	t.timeout.connect(p.queue_free)
	p.add_child(t)
	return p


static func sparks(pos: Vector3, color := Color(1.0, 0.75, 0.3), amount := 18) -> void:
	_particles(pos, amount, color, 0.45, Vector2(3, 7), 0.07, Vector3(0, -12, 0))


static func hit(pos: Vector3, color := Color(0.75, 0.05, 0.08)) -> void:
	_particles(pos, 14, color, 0.5, Vector2(2, 4.5), 0.1, Vector3(0, -9, 0), false)
	_particles(pos, 6, Color(1, 0.9, 0.8), 0.18, Vector2(1, 3), 0.18)


static func dust(pos: Vector3, color := Color(0.6, 0.55, 0.45, 0.6), amount := 10) -> void:
	_particles(pos + Vector3(0, 0.1, 0), amount, color, 0.7, Vector2(0.6, 1.8), 0.35, Vector3(0, 0.6, 0), false, 80.0)


static func burst(pos: Vector3, color: Color, amount := 30, speed := 6.0) -> void:
	_particles(pos, amount, color, 0.8, Vector2(speed * 0.4, speed), 0.14, Vector3(0, -2, 0))


static func _arc() -> ArrayMesh:
	if _arc_mesh:
		return _arc_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 16
	var a0 := -1.4
	var a1 := 1.4
	var r_in := 0.55
	var r_out := 1.0
	for i in seg:
		var t0 := float(i) / seg
		var t1 := float(i + 1) / seg
		var ang0: float = lerpf(a0, a1, t0)
		var ang1: float = lerpf(a0, a1, t1)
		var w0 := sin(t0 * PI)
		var w1 := sin(t1 * PI)
		var ri0 := lerpf(r_out, r_in, w0)
		var ri1 := lerpf(r_out, r_in, w1)
		var o0 := Vector3(sin(ang0) * r_out, 0, -cos(ang0) * r_out)
		var o1 := Vector3(sin(ang1) * r_out, 0, -cos(ang1) * r_out)
		var i0 := Vector3(sin(ang0) * ri0, 0, -cos(ang0) * ri0)
		var i1 := Vector3(sin(ang1) * ri1, 0, -cos(ang1) * ri1)
		var c_o0 := Color(1, 1, 1, w0 * t0)
		var c_o1 := Color(1, 1, 1, w1 * t1)
		var c_i := Color(1, 1, 1, 0)
		st.set_color(c_o0); st.add_vertex(o0)
		st.set_color(c_o1); st.add_vertex(o1)
		st.set_color(c_i); st.add_vertex(i1)
		st.set_color(c_o0); st.add_vertex(o0)
		st.set_color(c_i); st.add_vertex(i1)
		st.set_color(c_i); st.add_vertex(i0)
	_arc_mesh = st.commit()
	return _arc_mesh


static func slash(origin: Node3D, local_offset: Vector3, roll: float, radius: float, color: Color, duration := 0.22, mirror := false) -> void:
	## Arco luminoso do corte da katana, orientado pelo personagem.
	var root := _root()
	if root == null or not is_instance_valid(origin):
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _arc()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_fog = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var b := origin.global_transform.basis.orthonormalized()
	var basis := b * Basis(Vector3(0, 0, 1), roll)
	if mirror:
		basis = basis * Basis(Vector3(0, 1, 0), PI).scaled(Vector3(1, 1, 1))
	mi.global_transform = Transform3D(basis.scaled(Vector3.ONE * radius), origin.global_transform * local_offset)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "albedo_color:a", 0.0, duration)
	tw.tween_property(mi, "scale", mi.scale * 1.15, duration)
	tw.chain().tween_callback(mi.queue_free)


static func ring(pos: Vector3, radius: float, color: Color, duration := 0.5, from_radius := 0.2) -> void:
	## Onda de choque expansiva no chão.
	var root := _root()
	if root == null:
		return
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 6
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_fog = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.1, 0)
	mi.scale = Vector3(from_radius, 0.3, from_radius)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.3, radius), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(mi.queue_free)


static func telegraph(pos: Vector3, radius: float, duration: float, color := Color(1.0, 0.1, 0.1, 0.45)) -> MeshInstance3D:
	## Círculo de aviso no chão antes de um ataque em área.
	var root := _root()
	if root == null:
		return null
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.04
	cm.radial_segments = 32
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_fog = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.06, 0)
	mi.scale = Vector3(0.1, 1, 0.1)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(radius, 1, radius), duration * 0.85)
	tw.tween_property(m, "albedo_color:a", 0.9, duration * 0.15)
	tw.tween_callback(mi.queue_free)
	return mi


static func ambient(kind: String) -> CPUParticles3D:
	## Partículas ambientes que acompanham o jogador (folhas, pétalas, brasas, vagalumes...).
	var p := CPUParticles3D.new()
	var q := Game.quality_level()
	var base_amount := 60
	var col := Color.WHITE
	var size := 0.12
	var grav := Vector3(0, -0.5, 0)
	var additive := false
	var vel := Vector2(0.2, 0.8)
	match kind:
		"leaves":
			col = Color(0.55, 0.65, 0.25, 0.9); size = 0.14; grav = Vector3(0.3, -0.6, 0.1)
		"petals":
			col = Color(1.0, 0.7, 0.82, 0.95); size = 0.12; grav = Vector3(0.6, -0.5, 0.2); base_amount = 90
		"embers":
			col = Color(1.0, 0.5, 0.15, 1.0); size = 0.07; grav = Vector3(0.2, 1.2, 0); additive = true; base_amount = 70
		"fireflies":
			col = Color(0.75, 1.0, 0.45, 1.0); size = 0.06; grav = Vector3(0, 0.05, 0); additive = true; base_amount = 40
		"ash":
			col = Color(0.85, 0.3, 0.3, 0.8); size = 0.08; grav = Vector3(0.4, -0.3, 0); additive = true; base_amount = 80
		"dust":
			col = Color(0.8, 0.8, 0.7, 0.35); size = 0.08; grav = Vector3(0.1, -0.05, 0)
	p.amount = int(base_amount * [0.35, 0.7, 1.0][q])
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(14, 6, 14)
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size * (0.6 if kind == "petals" or kind == "leaves" else 1.0))
	p.mesh = qm
	var m := Props.unshaded(Color.WHITE, additive, true)
	p.material_override = m
	p.direction = Vector3(0, -1, 0)
	p.spread = 60
	p.initial_velocity_min = vel.x
	p.initial_velocity_max = vel.y
	p.gravity = grav
	p.angular_velocity_min = -90
	p.angular_velocity_max = 90
	var grad := Gradient.new()
	grad.set_color(0, Color(col.r, col.g, col.b, 0.0))
	grad.add_point(0.15, col)
	grad.add_point(0.85, col)
	grad.set_color(grad.get_point_count() - 1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = grad
	p.emitting = true
	return p


static func fire(parent: Node, pos: Vector3, s := 1.0, with_light := true) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var p := CPUParticles3D.new()
	p.amount = 24 if Game.quality_level() > 0 else 12
	p.lifetime = 0.9
	var qm := QuadMesh.new()
	qm.size = Vector2(0.5, 0.5) * s
	p.mesh = qm
	p.material_override = Props.unshaded(Color.WHITE, true, true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35 * s
	p.direction = Vector3.UP
	p.spread = 15
	p.initial_velocity_min = 1.0 * s
	p.initial_velocity_max = 2.2 * s
	p.gravity = Vector3(0, 1.5, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.4, 0.9))
	grad.add_point(0.4, Color(1.0, 0.4, 0.1, 0.7))
	grad.set_color(grad.get_point_count() - 1, Color(0.3, 0.05, 0.02, 0.0))
	p.color_ramp = grad
	p.local_coords = true
	root.add_child(p)
	if with_light and Game.quality_level() >= 1:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.2)
		l.light_energy = 2.0 * s
		l.omni_range = 8.0 * s
		l.position = Vector3(0, 0.8 * s, 0)
		root.add_child(l)
		var flick := FireFlicker.new()
		flick.light = l
		root.add_child(flick)
	return root


class FireFlicker:
	extends Node
	var light: OmniLight3D
	var _t := randf() * 10.0
	var _base := -1.0

	func _process(delta: float) -> void:
		if not is_instance_valid(light):
			return
		if _base < 0.0:
			_base = light.light_energy
		_t += delta * 9.0
		light.light_energy = _base * (0.8 + 0.15 * sin(_t) + 0.1 * sin(_t * 2.7 + 1.3))
