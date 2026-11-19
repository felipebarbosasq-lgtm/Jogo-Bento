class_name Props
extends RefCounted
## Biblioteca de construção procedural de cenários (sem modelos externos).
## Todas as formas são primitivas do Godot combinadas em código, o que mantém o
## projeto leve, sem dependências e com licença livre.

static var _mats := {}
static var _meshes := {}
static var _batches := {}   # chave -> {mesh, mat, xforms: Array[Transform3D]}

const SKY_SHADER := """
shader_type sky;
uniform vec3 top_color : source_color = vec3(0.1, 0.2, 0.4);
uniform vec3 horizon_color : source_color = vec3(0.6, 0.7, 0.8);
uniform vec3 bottom_color : source_color = vec3(0.2, 0.2, 0.2);
uniform vec3 moon_dir = vec3(0.3, 0.35, -1.0);
uniform vec3 moon_color : source_color = vec3(1.0, 1.0, 0.9);
uniform float moon_size = 0.05;
uniform float moon_glow = 0.4;
uniform float stars = 0.0;
uniform float clouds = 0.3;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, clamp(pow(max(h, 0.0), 0.55), 0.0, 1.0));
	col = mix(col, bottom_color, clamp(-h * 4.0, 0.0, 1.0));
	vec3 md = normalize(moon_dir);
	float c = dot(d, md);
	float disc = smoothstep(cos(moon_size), cos(moon_size * 0.9), c);
	float glow = pow(max(c, 0.0), 80.0) * moon_glow + pow(max(c, 0.0), 6.0) * moon_glow * 0.25;
	if (stars > 0.0 && h > 0.0) {
		vec3 p = floor(d * 220.0);
		float s = step(0.996, hash(p));
		col += vec3(s * stars * clamp(h * 3.0, 0.0, 1.0));
	}
	if (clouds > 0.0 && h > 0.0) {
		vec2 uv = d.xz / (h + 0.15) * 2.0 + vec2(TIME * 0.01, 0.0);
		float n = vnoise(uv) * 0.6 + vnoise(uv * 2.3) * 0.3 + vnoise(uv * 5.1) * 0.1;
		float cl = smoothstep(0.5, 0.85, n) * clouds * clamp(h * 4.0, 0.0, 1.0);
		col = mix(col, horizon_color * 1.1 + moon_color * glow * 0.3, cl);
	}
	col += moon_color * (disc + glow);
	COLOR = col;
}
"""


# ------------------------------------------------------------------ materiais
static func mat(c: Color, rough := 0.85, metal := 0.0, emit := 0.0, toon := true, rim := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f|%s|%.2f" % [c.to_html(true), rough, metal, emit, toon, rim]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if toon:
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	if rim > 0.0:
		m.rim_enabled = true
		m.rim = rim
		m.rim_tint = 0.3
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	if c.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


static func unshaded(c: Color, additive := false, billboard := false) -> StandardMaterial3D:
	var key := "U|%s|%s|%s" % [c.to_html(true), additive, billboard]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.disable_fog = true
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mats[key] = m
	return m


# --------------------------------------------------------------------- malhas
static func box_mesh(size: Vector3) -> BoxMesh:
	var key := "box%s" % size
	if _meshes.has(key):
		return _meshes[key]
	var m := BoxMesh.new()
	m.size = size
	_meshes[key] = m
	return m


static func cyl_mesh(top: float, bottom: float, h: float, seg := 10) -> CylinderMesh:
	var key := "cyl%.3f_%.3f_%.3f_%d" % [top, bottom, h, seg]
	if _meshes.has(key):
		return _meshes[key]
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	_meshes[key] = m
	return m


static func sphere_mesh(r: float, seg := 12, rings := 6) -> SphereMesh:
	var key := "sph%.3f_%d_%d" % [r, seg, rings]
	if _meshes.has(key):
		return _meshes[key]
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = rings
	_meshes[key] = m
	return m


static func prism_mesh(size: Vector3) -> PrismMesh:
	var key := "prism%s" % size
	if _meshes.has(key):
		return _meshes[key]
	var m := PrismMesh.new()
	m.size = size
	_meshes[key] = m
	return m


# ---------------------------------------------------------- nós básicos
static func mesh(parent: Node, m: Mesh, pos: Vector3, material: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func body(parent: Node, pos: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	b.position = pos
	b.rotation = rot
	parent.add_child(b)
	return b


static func add_box_shape(b: CollisionObject3D, size: Vector3, offset := Vector3.ZERO) -> void:
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.position = offset
	b.add_child(cs)


static func add_cyl_shape(b: CollisionObject3D, r: float, h: float, offset := Vector3.ZERO) -> void:
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = h
	cs.shape = s
	cs.position = offset
	b.add_child(cs)


static func solid_box(parent: Node, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO) -> StaticBody3D:
	var b := body(parent, pos, rot)
	mesh(b, box_mesh(size), Vector3.ZERO, material)
	add_box_shape(b, size)
	return b


static func wall(parent: Node, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	## Parede invisível (limites do mapa).
	var b := body(parent, pos, rot)
	add_box_shape(b, size)
	return b


static func ground(parent: Node, size: Vector2, pos: Vector3, material: Material) -> StaticBody3D:
	return solid_box(parent, Vector3(size.x, 1.0, size.y), pos + Vector3(0, -0.5, 0), material)


static func ramp(parent: Node, from: Vector3, to: Vector3, width: float, material: Material = null) -> StaticBody3D:
	## Rampa de colisão (e opcionalmente visual) entre dois pontos.
	var mid := (from + to) * 0.5
	var d := to - from
	var length := d.length()
	var b := body(parent, mid)
	b.look_at_from_position(mid, to, Vector3.UP)
	var size := Vector3(width, 0.3, length)
	add_box_shape(b, size, Vector3(0, -0.15, 0))
	if material:
		mesh(b, box_mesh(size), Vector3(0, -0.15, 0), material)
	return b


static func stairs(parent: Node, base: Vector3, yaw: float, width: float, steps: int, step_h: float, step_d: float, material: Material) -> Vector3:
	## Escadaria visual com rampa de colisão. Retorna o ponto do topo.
	var root := Node3D.new()
	root.position = base
	root.rotation.y = yaw
	parent.add_child(root)
	for i in steps:
		var h := step_h * (i + 1)
		mesh(root, box_mesh(Vector3(width, h, step_d)), Vector3(0, h * 0.5, -step_d * (i + 0.5)), material)
	var top_local := Vector3(0, step_h * steps, -step_d * steps)
	var b := StaticBody3D.new()
	b.collision_layer = 1
	root.add_child(b)
	var length := Vector2(step_d * steps, step_h * steps).length()
	var ang := atan2(step_h * steps, step_d * steps)
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(width, 0.4, length + 0.4)
	cs.shape = s
	cs.position = top_local * 0.5 + Vector3(0, -0.2, 0)
	cs.rotation.x = ang
	b.add_child(cs)
	return root.to_global(top_local) if root.is_inside_tree() else base + top_local.rotated(Vector3.UP, yaw)


# ------------------------------------------------------- instâncias em lote
static func batch_add(key: String, m: Mesh, material: Material, xf: Transform3D) -> void:
	if not _batches.has(key):
		_batches[key] = {"mesh": m, "mat": material, "xforms": []}
	_batches[key].xforms.append(xf)


static func batch_flush(parent: Node, shadows := true) -> void:
	for key in _batches.keys():
		var b: Dictionary = _batches[key]
		var xs: Array = b.xforms
		if xs.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = b.mesh
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = b.mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.name = "Batch_" + key
		parent.add_child(mmi)
	_batches.clear()


static func xf(pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	var bas := Basis.from_euler(rot).scaled(scl)
	return Transform3D(bas, pos)


# ------------------------------------------------------------------ vegetação
static func bamboo(parent: Node, pos: Vector3, rnd: RandomNumberGenerator, collide := false) -> void:
	var h := rnd.randf_range(7.0, 11.0)
	var tilt := Vector3(rnd.randf_range(-0.06, 0.06), 0, rnd.randf_range(-0.06, 0.06))
	var green := "bamboo%d" % rnd.randi_range(0, 2)
	var cols := [Color(0.42, 0.55, 0.22), Color(0.36, 0.5, 0.2), Color(0.5, 0.58, 0.26)]
	var c: Color = cols[int(green.right(1))]
	var stalk := cyl_mesh(0.07, 0.09, 1.0, 6)
	batch_add(green, stalk, mat(c, 0.6), xf(pos + Vector3(0, h * 0.5, 0), tilt, Vector3(1, h, 1)))
	# nós do bambu
	var ring := cyl_mesh(0.1, 0.1, 0.06, 6)
	var k := 1.4
	while k < h - 1.0:
		batch_add("bamboo_ring", ring, mat(c.darkened(0.25), 0.6), xf(pos + Vector3(tilt.z * -k, k, tilt.x * k), tilt))
		k += rnd.randf_range(1.2, 1.8)
	# folhagem
	var leaf := sphere_mesh(1.0, 6, 3)
	for i in 3:
		var lh := h - rnd.randf_range(0.0, 2.5)
		var off := Vector3(rnd.randf_range(-0.8, 0.8), 0, rnd.randf_range(-0.8, 0.8))
		batch_add("bamboo_leaf", leaf, mat(Color(0.3, 0.48, 0.18), 0.9), xf(pos + off + Vector3(tilt.z * -lh, lh, tilt.x * lh), Vector3(0, rnd.randf() * TAU, 0), Vector3(1.2, 0.35, 0.7) * rnd.randf_range(0.8, 1.4)))
	if collide:
		var b := body(parent, pos)
		add_cyl_shape(b, 0.12, 4.0, Vector3(0, 2, 0))


static func cherry_tree(parent: Node, pos: Vector3, rnd: RandomNumberGenerator, s := 1.0, petal := Color(0.98, 0.66, 0.78)) -> void:
	var trunk_c := Color(0.24, 0.14, 0.12)
	var h := 3.2 * s
	batch_add("ch_trunk", cyl_mesh(0.18, 0.32, 1.0, 7), mat(trunk_c), xf(pos + Vector3(0, h * 0.5, 0), Vector3(rnd.randf_range(-0.1, 0.1), 0, rnd.randf_range(-0.1, 0.1)), Vector3(s, h, s)))
	for i in 3:
		var a := rnd.randf() * TAU
		var br := Vector3(cos(a), 0, sin(a))
		batch_add("ch_branch", cyl_mesh(0.08, 0.14, 1.0, 5), mat(trunk_c), xf(pos + Vector3(0, h * 0.85, 0) + br * 0.7 * s, Vector3(sin(a) * 0.9, 0, -cos(a) * 0.9), Vector3(s, 1.8 * s, s)))
	var leaf := sphere_mesh(1.0, 8, 5)
	for i in 5:
		var off := Vector3(rnd.randf_range(-1.6, 1.6), rnd.randf_range(-0.3, 0.9), rnd.randf_range(-1.6, 1.6)) * s
		var col := petal.lightened(rnd.randf_range(-0.05, 0.12))
		var key := "ch_leaf%d" % (i % 2)
		batch_add(key, leaf, mat(col if i % 2 == 0 else petal.darkened(0.08), 0.95), xf(pos + Vector3(0, h + 0.6 * s, 0) + off, Vector3(0, rnd.randf() * TAU, 0), Vector3.ONE * rnd.randf_range(1.1, 1.7) * s))
	var b := body(parent, pos)
	add_cyl_shape(b, 0.3 * s, h, Vector3(0, h * 0.5, 0))


static func pine_tree(parent: Node, pos: Vector3, rnd: RandomNumberGenerator, s := 1.0, col := Color(0.12, 0.25, 0.18)) -> void:
	var h := rnd.randf_range(6.0, 9.0) * s
	batch_add("pine_trunk", cyl_mesh(0.18, 0.3, 1.0, 6), mat(Color(0.2, 0.13, 0.1)), xf(pos + Vector3(0, h * 0.25, 0), Vector3.ZERO, Vector3(s, h * 0.5, s)))
	var cone := cyl_mesh(0.0, 1.0, 1.0, 7)
	for i in 4:
		var t := float(i) / 4.0
		var r := (2.2 - t * 1.6) * s
		batch_add("pine_cone%d" % (i % 2), cone, mat(col.lightened(0.04 * (i % 2)), 0.9), xf(pos + Vector3(0, h * (0.3 + t * 0.55), 0), Vector3(0, rnd.randf() * TAU, 0), Vector3(r, h * 0.35, r)))
	var b := body(parent, pos)
	add_cyl_shape(b, 0.35 * s, h * 0.6, Vector3(0, h * 0.3, 0))


static func bush(pos: Vector3, rnd: RandomNumberGenerator, col := Color(0.2, 0.36, 0.16)) -> void:
	var m := sphere_mesh(1.0, 7, 4)
	for i in 3:
		var off := Vector3(rnd.randf_range(-0.6, 0.6), 0.2, rnd.randf_range(-0.6, 0.6))
		batch_add("bush", m, mat(col, 0.95), xf(pos + off, Vector3(0, rnd.randf() * TAU, 0), Vector3(0.9, 0.6, 0.8) * rnd.randf_range(0.6, 1.1)))


static func grass_patch(pos: Vector3, rnd: RandomNumberGenerator, col := Color(0.32, 0.5, 0.2), count := 6) -> void:
	var blade := prism_mesh(Vector3(0.12, 0.5, 0.02))
	for i in count:
		var off := Vector3(rnd.randf_range(-0.7, 0.7), 0.22, rnd.randf_range(-0.7, 0.7))
		batch_add("grass", blade, mat(col, 1.0), xf(pos + off, Vector3(rnd.randf_range(-0.3, 0.3), rnd.randf() * TAU, 0), Vector3.ONE * rnd.randf_range(0.6, 1.3)))


static func rock(parent: Node, pos: Vector3, s: Vector3, rnd: RandomNumberGenerator, col := Color(0.36, 0.36, 0.38), collide := true) -> void:
	batch_add("rock", sphere_mesh(1.0, 6, 4), mat(col, 1.0), xf(pos, Vector3(rnd.randf() * 0.4, rnd.randf() * TAU, rnd.randf() * 0.4), s))
	if collide:
		var b := body(parent, pos)
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = minf(s.x, s.z) * 0.9
		cs.shape = sh
		b.add_child(cs)


static func mountain(parent: Node, pos: Vector3, r: float, h: float, col: Color, snow := false) -> void:
	mesh(parent, cyl_mesh(r * 0.08, r, h, 8), pos + Vector3(0, h * 0.5, 0), mat(col, 1.0), Vector3(0, randf() * TAU, 0))
	if snow:
		mesh(parent, cyl_mesh(0.0, r * 0.3, h * 0.28, 8), pos + Vector3(0, h * 0.88, 0), mat(Color(0.9, 0.9, 0.95), 1.0))


# ------------------------------------------------------------- arquitetura
static func torii(parent: Node, pos: Vector3, yaw := 0.0, s := 1.0, col := Color(0.72, 0.1, 0.08)) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	var red := mat(col, 0.6)
	var black := mat(Color(0.08, 0.06, 0.06), 0.6)
	var w := 2.4 * s
	var h := 4.6 * s
	for x in [-w, w]:
		var b := body(root, Vector3(x, 0, 0))
		mesh(b, cyl_mesh(0.22 * s, 0.26 * s, h, 10), Vector3(0, h * 0.5, 0), red)
		mesh(b, cyl_mesh(0.3 * s, 0.3 * s, 0.4 * s, 10), Vector3(0, 0.2 * s, 0), black)
		add_cyl_shape(b, 0.26 * s, h, Vector3(0, h * 0.5, 0))
	mesh(root, box_mesh(Vector3(w * 2.7, 0.32 * s, 0.5 * s)), Vector3(0, h + 0.1 * s, 0), black)
	mesh(root, box_mesh(Vector3(w * 2.5, 0.3 * s, 0.42 * s)), Vector3(0, h - 0.2 * s, 0), red)
	mesh(root, box_mesh(Vector3(w * 2.2, 0.22 * s, 0.3 * s)), Vector3(0, h - 1.1 * s, 0), red)
	mesh(root, box_mesh(Vector3(0.25 * s, 0.9 * s, 0.2 * s)), Vector3(0, h - 0.65 * s, 0), black)
	return root


static func stone_lantern(parent: Node, pos: Vector3, lit := true, light := true) -> Node3D:
	var root := body(parent, pos)
	var stone := mat(Color(0.5, 0.5, 0.48), 1.0)
	mesh(root, box_mesh(Vector3(0.7, 0.2, 0.7)), Vector3(0, 0.1, 0), stone)
	mesh(root, cyl_mesh(0.12, 0.15, 0.9, 6), Vector3(0, 0.65, 0), stone)
	mesh(root, box_mesh(Vector3(0.55, 0.12, 0.55)), Vector3(0, 1.15, 0), stone)
	var glow := mat(Color(1.0, 0.7, 0.3), 0.5, 0.0, 3.0 if lit else 0.0)
	mesh(root, box_mesh(Vector3(0.38, 0.38, 0.38)), Vector3(0, 1.4, 0), glow if lit else stone)
	mesh(root, cyl_mesh(0.05, 0.5, 0.3, 4), Vector3(0, 1.75, 0), stone, Vector3(0, PI / 4, 0))
	mesh(root, sphere_mesh(0.08, 6, 3), Vector3(0, 1.95, 0), stone)
	add_box_shape(root, Vector3(0.6, 1.8, 0.6), Vector3(0, 0.9, 0))
	if lit and light and Game.quality_level() >= 1:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.65, 0.3)
		l.light_energy = 1.6
		l.omni_range = 7.0
		l.position = Vector3(0, 1.45, 0)
		l.shadow_enabled = false
		root.add_child(l)
	return root


static func hanging_lantern(parent: Node, pos: Vector3, col := Color(0.95, 0.25, 0.15), light := false) -> void:
	var m := sphere_mesh(0.22, 10, 6)
	mesh(parent, m, pos, mat(col, 0.6, 0.0, 2.2), Vector3.ZERO, Vector3(1, 1.4, 1))
	mesh(parent, cyl_mesh(0.12, 0.12, 0.06, 8), pos + Vector3(0, 0.32, 0), mat(Color(0.1, 0.08, 0.06)))
	mesh(parent, cyl_mesh(0.12, 0.12, 0.06, 8), pos - Vector3(0, 0.32, 0), mat(Color(0.1, 0.08, 0.06)))
	if light and Game.quality_level() >= 2:
		var l := OmniLight3D.new()
		l.light_color = col.lightened(0.3)
		l.light_energy = 1.0
		l.omni_range = 5.0
		l.position = pos
		parent.add_child(l)


static func house(parent: Node, pos: Vector3, yaw := 0.0, w := 6.0, d := 5.0, destroyed := false, burnt := false, rnd: RandomNumberGenerator = null) -> Node3D:
	## Casa japonesa de madeira (minka). Pode estar destruída/queimada.
	if rnd == null:
		rnd = RandomNumberGenerator.new()
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	var wood := mat(Color(0.3, 0.2, 0.13) if not burnt else Color(0.12, 0.09, 0.08), 0.9)
	var dark := mat(Color(0.16, 0.11, 0.08) if not burnt else Color(0.06, 0.05, 0.05), 0.9)
	var paper := mat(Color(0.86, 0.8, 0.66) if not burnt else Color(0.3, 0.27, 0.24), 0.9)
	var roof := mat(Color(0.2, 0.2, 0.24) if not burnt else Color(0.1, 0.09, 0.09), 0.8)
	var h := 2.8
	# plataforma
	var plat := body(root, Vector3.ZERO)
	mesh(plat, box_mesh(Vector3(w + 0.6, 0.4, d + 0.6)), Vector3(0, 0.2, 0), dark)
	add_box_shape(plat, Vector3(w + 0.6, 0.4, d + 0.6), Vector3(0, 0.2, 0))
	# pilares
	for x in [-w / 2, 0.0, w / 2]:
		for z in [-d / 2, d / 2]:
			if destroyed and rnd.randf() < 0.25:
				continue
			var ph := h if not destroyed else h * rnd.randf_range(0.5, 1.0)
			mesh(root, box_mesh(Vector3(0.22, ph, 0.22)), Vector3(x, 0.4 + ph / 2, z), wood)
	# paredes (com colisão)
	var walls := [
		[Vector3(w, h, 0.12), Vector3(0, 0.4 + h / 2, -d / 2)],
		[Vector3(0.12, h, d), Vector3(-w / 2, 0.4 + h / 2, 0)],
		[Vector3(0.12, h, d), Vector3(w / 2, 0.4 + h / 2, 0)],
	]
	for wd in walls:
		var sz: Vector3 = wd[0]
		var p: Vector3 = wd[1]
		if destroyed and rnd.randf() < 0.4:
			# parede parcialmente caída
			var low := sz
			low.y = h * 0.35
			var bb := body(root, p - Vector3(0, h * 0.325, 0))
			mesh(bb, box_mesh(low), Vector3.ZERO, paper)
			add_box_shape(bb, low)
			continue
		var b := body(root, p)
		mesh(b, box_mesh(sz), Vector3.ZERO, paper)
		add_box_shape(b, sz)
		# grade de madeira das paredes de papel
		if sz.x > 1.0:
			for i in int(sz.x / 1.0):
				mesh(b, box_mesh(Vector3(0.06, sz.y, 0.16)), Vector3(-sz.x / 2 + 0.5 + i, 0, 0), dark)
		else:
			for i in int(sz.z / 1.0):
				mesh(b, box_mesh(Vector3(0.16, sz.y, 0.06)), Vector3(0, 0, -sz.z / 2 + 0.5 + i), dark)
	# frente: duas metades com porta aberta
	for side in [-1.0, 1.0]:
		var fw := w * 0.32
		var b := body(root, Vector3(side * (w / 2 - fw / 2), 0.4 + h / 2, d / 2))
		mesh(b, box_mesh(Vector3(fw, h, 0.12)), Vector3.ZERO, paper)
		add_box_shape(b, Vector3(fw, h, 0.12))
	mesh(root, box_mesh(Vector3(w + 0.3, 0.25, d + 0.3)), Vector3(0, 0.4 + h, 0), dark)
	# telhado
	var roof_node := Node3D.new()
	roof_node.position = Vector3(0, 0.4 + h + 0.12, 0)
	root.add_child(roof_node)
	if destroyed:
		roof_node.rotation = Vector3(rnd.randf_range(-0.25, 0.25), 0, rnd.randf_range(-0.3, 0.3))
		roof_node.position.y -= rnd.randf_range(0.2, 1.0)
	mesh(roof_node, prism_mesh(Vector3(w + 1.6, 1.8, d + 1.8)), Vector3(0, 0.9, 0), roof, Vector3(0, PI / 2, 0))
	mesh(roof_node, box_mesh(Vector3(0.3, 0.25, w + 1.8)), Vector3(0, 1.85, 0), dark, Vector3(0, PI / 2, 0))
	if destroyed:
		for i in 4:
			mesh(root, box_mesh(Vector3(rnd.randf_range(1.0, 2.5), 0.15, 0.25)), Vector3(rnd.randf_range(-w, w), 0.1, d / 2 + rnd.randf_range(0.6, 2.5)), wood, Vector3(0, rnd.randf() * TAU, rnd.randf_range(-0.2, 0.2)))
	return root


static func fence(parent: Node, from: Vector3, to: Vector3, col := Color(0.3, 0.2, 0.13), collide := true) -> void:
	var d := to - from
	var n := int(d.length() / 1.2) + 1
	var m := mat(col, 0.9)
	for i in n + 1:
		var p := from + d * (float(i) / n)
		batch_add("fence_post", box_mesh(Vector3(0.15, 1.3, 0.15)), m, xf(p + Vector3(0, 0.65, 0)))
	var mid := (from + to) * 0.5
	var yaw := atan2(d.x, d.z)
	for y in [0.45, 1.0]:
		batch_add("fence_rail", box_mesh(Vector3(0.08, 0.1, 1.0)), m, xf(mid + Vector3(0, y, 0), Vector3(0, yaw, 0), Vector3(1, 1, d.length())))
	if collide:
		var b := body(parent, mid + Vector3(0, 0.65, 0), Vector3(0, yaw, 0))
		add_box_shape(b, Vector3(0.2, 1.3, d.length()))


static func crate(parent: Node, pos: Vector3, s := 1.0, yaw := 0.0) -> void:
	var b := body(parent, pos + Vector3(0, 0.4 * s, 0), Vector3(0, yaw, 0))
	mesh(b, box_mesh(Vector3(0.8, 0.8, 0.8) * s), Vector3.ZERO, mat(Color(0.45, 0.32, 0.18)))
	mesh(b, box_mesh(Vector3(0.84, 0.1, 0.84) * s), Vector3(0, 0.3 * s, 0), mat(Color(0.3, 0.2, 0.12)))
	add_box_shape(b, Vector3(0.8, 0.8, 0.8) * s)


static func barrel(parent: Node, pos: Vector3) -> void:
	var b := body(parent, pos + Vector3(0, 0.5, 0))
	mesh(b, cyl_mesh(0.38, 0.38, 1.0, 10), Vector3.ZERO, mat(Color(0.4, 0.27, 0.15)))
	for y in [-0.3, 0.3]:
		mesh(b, cyl_mesh(0.4, 0.4, 0.07, 10), Vector3(0, y, 0), mat(Color(0.15, 0.12, 0.1), 0.5, 0.5))
	add_cyl_shape(b, 0.38, 1.0)


static func banner(parent: Node, pos: Vector3, col := Color(0.6, 0.05, 0.08), yaw := 0.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	mesh(root, cyl_mesh(0.04, 0.05, 4.0, 6), Vector3(0, 2.0, 0), mat(Color(0.12, 0.1, 0.08)))
	mesh(root, box_mesh(Vector3(0.8, 0.05, 0.05)), Vector3(0.4, 3.9, 0), mat(Color(0.12, 0.1, 0.08)))
	mesh(root, box_mesh(Vector3(0.75, 2.4, 0.03)), Vector3(0.42, 2.65, 0), mat(col, 0.9))
	mesh(root, cyl_mesh(0.2, 0.2, 0.04, 12), Vector3(0.42, 3.2, 0.02), mat(Color(0.92, 0.9, 0.85)), Vector3(PI / 2, 0, 0))


static func stone_wall(parent: Node, from: Vector3, to: Vector3, h := 3.0, thick := 1.2, col := Color(0.42, 0.4, 0.38), cap := true) -> void:
	var d := to - from
	var mid := (from + to) * 0.5
	var yaw := atan2(d.x, d.z)
	var b := body(parent, mid + Vector3(0, h * 0.5, 0), Vector3(0, yaw, 0))
	mesh(b, box_mesh(Vector3(thick, h, d.length())), Vector3.ZERO, mat(col, 1.0))
	add_box_shape(b, Vector3(thick, h, d.length()))
	if cap:
		mesh(b, box_mesh(Vector3(thick + 0.5, 0.25, d.length() + 0.3)), Vector3(0, h * 0.5 + 0.12, 0), mat(Color(0.16, 0.16, 0.2)))
		mesh(b, box_mesh(Vector3(thick * 0.6, 0.5, d.length())), Vector3(0, h * 0.5 + 0.45, 0), mat(Color(0.88, 0.86, 0.8)))


static func temple(parent: Node, pos: Vector3, yaw := 0.0, s := 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	var stone := mat(Color(0.4, 0.4, 0.42), 1.0)
	var wood := mat(Color(0.45, 0.08, 0.06), 0.7)
	var dark := mat(Color(0.1, 0.08, 0.07), 0.8)
	var roof := mat(Color(0.14, 0.16, 0.2), 0.7)
	var w := 14.0 * s
	var d := 10.0 * s
	var base := body(root, Vector3.ZERO)
	mesh(base, box_mesh(Vector3(w + 2, 1.0, d + 2)), Vector3(0, 0.5, 0), stone)
	add_box_shape(base, Vector3(w + 2, 1.0, d + 2), Vector3(0, 0.5, 0))
	var ph := 5.0 * s
	for i in 6:
		for z in [-d / 2, d / 2]:
			var x := -w / 2 + i * (w / 5)
			var pb := body(root, Vector3(x, 1.0, z))
			mesh(pb, cyl_mesh(0.3, 0.32, ph, 10), Vector3(0, ph / 2, 0), wood)
			add_cyl_shape(pb, 0.32, ph, Vector3(0, ph / 2, 0))
	# parede dos fundos
	var back := body(root, Vector3(0, 1.0 + ph / 2, -d / 2 + 0.3))
	mesh(back, box_mesh(Vector3(w, ph, 0.3)), Vector3.ZERO, mat(Color(0.82, 0.78, 0.66)))
	add_box_shape(back, Vector3(w, ph, 0.3))
	mesh(root, box_mesh(Vector3(w + 1.5, 0.5, d + 1.5)), Vector3(0, 1.0 + ph + 0.25, 0), dark)
	mesh(root, prism_mesh(Vector3(w + 5, 3.0 * s, d + 5)), Vector3(0, 1.0 + ph + 2.0 * s, 0), roof, Vector3(0, PI / 2, 0))
	mesh(root, box_mesh(Vector3(w * 0.6, 1.4 * s, d * 0.6)), Vector3(0, 1.0 + ph + 3.8 * s, 0), wood)
	mesh(root, prism_mesh(Vector3(w * 0.6 + 3, 2.2 * s, d * 0.6 + 3)), Vector3(0, 1.0 + ph + 5.4 * s, 0), roof, Vector3(0, PI / 2, 0))
	return root


static func castle_keep(parent: Node, pos: Vector3, yaw := 0.0, s := 1.0) -> Node3D:
	## Torre principal do castelo (tenshu) com base de pedra e telhados em camadas.
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	var stone := mat(Color(0.38, 0.37, 0.36), 1.0)
	var white := mat(Color(0.88, 0.86, 0.82), 0.9)
	var roof := mat(Color(0.12, 0.12, 0.16), 0.6)
	var dark := mat(Color(0.08, 0.06, 0.06), 0.8)
	var gold := mat(Color(0.85, 0.65, 0.2), 0.3, 0.8)
	var base_w := 26.0 * s
	var b := body(root, Vector3.ZERO)
	mesh(b, cyl_mesh(base_w * 0.62, base_w * 0.75, 8.0 * s, 4), Vector3(0, 4.0 * s, 0), stone, Vector3(0, PI / 4, 0))
	add_box_shape(b, Vector3(base_w, 8.0 * s, base_w), Vector3(0, 4.0 * s, 0))
	var y := 8.0 * s
	var w := base_w * 0.8
	for tier in 4:
		var th := 4.0 * s
		mesh(root, box_mesh(Vector3(w, th, w * 0.8)), Vector3(0, y + th / 2, 0), white)
		# janelas
		for i in 3:
			mesh(root, box_mesh(Vector3(w * 0.12, th * 0.3, 0.1)), Vector3(-w * 0.3 + i * w * 0.3, y + th * 0.55, w * 0.4 + 0.05), dark)
		y += th
		mesh(root, prism_mesh(Vector3(w + 4 * s, 2.0 * s, w * 0.8 + 4 * s)), Vector3(0, y + 0.8 * s, 0), roof, Vector3(0, PI / 2 if tier % 2 == 0 else 0.0, 0))
		y += 1.6 * s
		w *= 0.72
	# shachihoko dourados
	for x in [-1.0, 1.0]:
		mesh(root, box_mesh(Vector3(0.5, 1.2, 0.5) * s), Vector3(x * w * 0.9, y + 0.6 * s, 0), gold)
	return root


static func gate(parent: Node, pos: Vector3, yaw := 0.0, width := 6.0, col := Color(0.3, 0.18, 0.1)) -> Dictionary:
	## Portão com folhas que podem ser abertas (retorna {root, doors, blocker}).
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	var wood := mat(col, 0.8)
	var dark := mat(Color(0.08, 0.07, 0.07), 0.6, 0.4)
	var h := 4.5
	for x in [-width / 2 - 0.4, width / 2 + 0.4]:
		var pb := body(root, Vector3(x, h / 2, 0))
		mesh(pb, box_mesh(Vector3(0.7, h, 0.7)), Vector3.ZERO, dark)
		add_box_shape(pb, Vector3(0.7, h, 0.7))
	mesh(root, box_mesh(Vector3(width + 2.5, 0.6, 1.2)), Vector3(0, h + 0.3, 0), dark)
	mesh(root, prism_mesh(Vector3(width + 3.5, 1.2, 1.8)), Vector3(0, h + 1.2, 0), mat(Color(0.14, 0.14, 0.18)), Vector3(0, 0, 0))
	var doors: Array = []
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(side * width / 2, 0, 0)
		root.add_child(hinge)
		mesh(hinge, box_mesh(Vector3(width / 2, h - 0.2, 0.25)), Vector3(-side * width / 4, (h - 0.2) / 2, 0), wood)
		for yy in [1.0, 3.0]:
			mesh(hinge, box_mesh(Vector3(width / 2, 0.15, 0.3)), Vector3(-side * width / 4, yy, 0), dark)
		hinge.set_meta("side", side)
		doors.append(hinge)
	var blocker := body(root, Vector3(0, h / 2, 0))
	add_box_shape(blocker, Vector3(width, h, 0.6))
	return {"root": root, "doors": doors, "blocker": blocker}


static func open_gate(g: Dictionary) -> void:
	if g.is_empty():
		return
	for door in g.doors:
		var hinge: Node3D = door
		var side: float = hinge.get_meta("side")
		var tw := hinge.create_tween()
		tw.tween_property(hinge, "rotation:y", side * 1.75, 1.6).set_trans(Tween.TRANS_SINE)
	var blk: Node = g.blocker
	if is_instance_valid(blk):
		blk.queue_free()
	Sfx.play_at("gong", (g.root as Node3D).global_position, -6.0)


static func barrier(parent: Node, pos: Vector3, width: float, yaw := 0.0, col := Color(0.6, 0.1, 0.12)) -> StaticBody3D:
	## Barreira mística temporária (bloqueia o caminho até cumprir o objetivo).
	var b := body(parent, pos, Vector3(0, yaw, 0))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r, col.g, col.b, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_fog = true
	mesh(b, box_mesh(Vector3(width, 4.0, 0.08)), Vector3(0, 2.0, 0), m)
	# runas
	for i in int(width / 2.0):
		mesh(b, box_mesh(Vector3(0.3, 0.3, 0.1)), Vector3(-width / 2 + 1 + i * 2, 2.0, 0), Props.unshaded(col.lightened(0.4), true), Vector3(0, 0, PI / 4))
	add_box_shape(b, Vector3(width, 6.0, 0.6), Vector3(0, 3.0, 0))
	return b


static func remove_barrier(b: Node) -> void:
	if not is_instance_valid(b):
		return
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector3(1, 0.01, 1), 0.6)
	tw.tween_callback(b.queue_free)


# ------------------------------------------------------------------ ambiente
static func environment(parent: Node, cfg: Dictionary) -> DirectionalLight3D:
	var q := Game.quality_level()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SKY_SHADER
	sm.shader = sh
	sm.set_shader_parameter("top_color", cfg.get("sky_top", Color(0.2, 0.35, 0.6)))
	sm.set_shader_parameter("horizon_color", cfg.get("sky_horizon", Color(0.7, 0.75, 0.8)))
	sm.set_shader_parameter("bottom_color", cfg.get("sky_bottom", Color(0.2, 0.22, 0.2)))
	sm.set_shader_parameter("moon_dir", cfg.get("moon_dir", Vector3(0.3, 0.3, -1)))
	sm.set_shader_parameter("moon_color", cfg.get("moon_color", Color(1, 1, 0.9)))
	sm.set_shader_parameter("moon_size", cfg.get("moon_size", 0.04))
	sm.set_shader_parameter("moon_glow", cfg.get("moon_glow", 0.4))
	sm.set_shader_parameter("stars", cfg.get("stars", 0.0))
	sm.set_shader_parameter("clouds", cfg.get("clouds", 0.3))
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = cfg.get("ambient", Color(0.5, 0.5, 0.55))
	env.ambient_light_energy = cfg.get("ambient_energy", 0.6)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = cfg.get("exposure", 1.0)
	env.fog_enabled = true
	env.fog_light_color = cfg.get("fog_color", Color(0.6, 0.65, 0.7))
	env.fog_density = cfg.get("fog_density", 0.015) * (0.8 if q == 0 else 1.0)
	env.fog_sky_affect = cfg.get("fog_sky", 0.35)
	env.fog_aerial_perspective = 0.0
	env.glow_enabled = q >= 1
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.adjustment_enabled = true
	env.adjustment_contrast = cfg.get("contrast", 1.08)
	env.adjustment_saturation = cfg.get("saturation", 1.05)
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = cfg.get("sun_color", Color(1, 0.95, 0.85))
	sun.light_energy = cfg.get("sun_energy", 1.0)
	var r: Vector3 = cfg.get("sun_rot", Vector3(-50, 30, 0))
	sun.rotation_degrees = r
	sun.shadow_enabled = q >= 1
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q == 2 else DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0 if q == 2 else 30.0
	sun.shadow_bias = 0.05
	sun.shadow_blur = 1.5
	parent.add_child(sun)
	return sun
