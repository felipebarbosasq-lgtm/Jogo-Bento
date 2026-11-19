class_name Terrain
extends RefCounted
## Terreno com relevo procedural: a área jogável (trilhas, praças, arenas)
## permanece plana na altura 0 — preservando a jogabilidade — e o resto do
## mapa se ergue em encostas e colinas com rochas, como nas artes de referência.
## Também espalha capim/flores e cria riachos.

static var active: Terrain = null

var size := Vector2(200, 200)
var center := Vector3.ZERO
var cell := 1.5
var segs: Array = []       # [a: Vector3, b: Vector3, meia_largura]
var circles: Array = []    # [centro: Vector3, raio]
var rects: Array = []      # [min: Vector2, max: Vector2]  (zonas planas retangulares)
var paths: Array = []      # [a, b, meia_largura] (terra batida)
var rivers: Array = []     # [a, b, meia_largura]
var pits: Array = []       # [min: Vector2, max: Vector2] (abismos)
var ramp := 14.0
var rise := 9.0
var hill := 10.0
var noise := FastNoiseLite.new()
var noise2 := FastNoiseLite.new()


func _init() -> void:
	noise.seed = 7
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	noise2.seed = 21
	noise2.frequency = 0.05
	noise2.fractal_octaves = 2


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func flat_dist(x: float, z: float) -> float:
	## Distância (m) até a zona plana mais próxima (<= 0 dentro dela).
	var p := Vector2(x, z)
	var d := 99999.0
	for s in segs:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		d = minf(d, _seg_dist(p, Vector2(a.x, a.z), Vector2(b.x, b.z)) - float(s[2]))
	for c in circles:
		var cc: Vector3 = c[0]
		d = minf(d, p.distance_to(Vector2(cc.x, cc.z)) - float(c[1]))
	for r in rects:
		var mn: Vector2 = r[0]
		var mx: Vector2 = r[1]
		var q := Vector2(maxf(maxf(mn.x - p.x, p.x - mx.x), 0.0), maxf(maxf(mn.y - p.y, p.y - mx.y), 0.0))
		var inside := p.x > mn.x and p.x < mx.x and p.y > mn.y and p.y < mx.y
		d = minf(d, -1.0 if inside else q.length())
	return d


func height(x: float, z: float) -> float:
	var d := flat_dist(x, z)
	var h := 0.0
	if d > 0.0:
		var k := smoothstep(0.0, ramp, d)
		var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
		h = k * rise * (0.6 + 0.8 * n) + smoothstep(ramp * 0.5, ramp * 4.0, d) * hill * n
		h += noise2.get_noise_2d(x, z) * 0.6 * k
	for r in rivers:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		var rd := _seg_dist(Vector2(x, z), Vector2(a.x, a.z), Vector2(b.x, b.z))
		var w: float = r[2]
		if rd < w + 2.0:
			h = minf(h, lerpf(-0.7, h, smoothstep(w * 0.6, w + 2.0, rd)))
	for pt in pits:
		var mn: Vector2 = pt[0]
		var mx: Vector2 = pt[1]
		if x > mn.x and x < mx.x and z > mn.y and z < mx.y:
			h = -30.0
	return h


func path_mask(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var m := 0.0
	for s in paths:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var d := _seg_dist(p, Vector2(a.x, a.z), Vector2(b.x, b.z))
		m = maxf(m, 1.0 - smoothstep(float(s[2]) * 0.6, float(s[2]) * 1.3, d))
	return m


static func ground_y(x: float, z: float) -> float:
	if active == null:
		return 0.0
	return active.height(x, z)


func build(parent: Node3D, colors: Dictionary = {}) -> void:
	active = self
	var nx := int(size.x / cell) + 1
	var nz := int(size.y / cell) + 1
	var ox := center.x - size.x * 0.5
	var oz := center.z - size.y * 0.5
	var hs := PackedFloat32Array()
	hs.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			hs[iz * nx + ix] = height(ox + ix * cell, oz + iz * cell)
	# malha
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in nz:
		for ix in nx:
			var x := ox + ix * cell
			var z := oz + iz * cell
			st.set_color(Color(path_mask(x, z), 0, 0))
			st.set_uv(Vector2(x, z) * 0.1)
			st.add_vertex(Vector3(x, hs[iz * nx + ix], z))
	for iz in nz - 1:
		for ix in nx - 1:
			var i := iz * nx + ix
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + nx)
			st.add_index(i + 1)
			st.add_index(i + nx + 1)
			st.add_index(i + nx)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Shaders.terrain(colors)
	mi.name = "Terrain"
	parent.add_child(mi)
	# colisão (grade de 1 m, independente da malha visual)
	var cw := int(size.x) + 1
	var cd := int(size.y) + 1
	var data := PackedFloat32Array()
	data.resize(cw * cd)
	var cx0 := center.x - (cw - 1) * 0.5
	var cz0 := center.z - (cd - 1) * 0.5
	for iz in cd:
		for ix in cw:
			data[iz * cw + ix] = height(cx0 + ix, cz0 + iz)
	var shape := HeightMapShape3D.new()
	shape.map_width = cw
	shape.map_depth = cd
	shape.map_data = data
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = Vector3(center.x, 0, center.z)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	# chão de segurança bem abaixo
	Props.wall(parent, Vector3(size.x, 1, size.y), Vector3(center.x, -34, center.z))


# ------------------------------------------------------------ capim e flores
static var _grass_mesh: ArrayMesh
static var _flower_mesh: ArrayMesh


static func _clump(flower: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3 if flower else 1
	var blades := 4 if flower else 11
	for i in blades:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.0, 0.18)
		var base := Vector3(cos(a) * r, 0, sin(a) * r)
		var h := rng.randf_range(0.35, 0.7)
		var lean := Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))
		var side := Vector3(cos(a + 1.57), 0, sin(a + 1.57)) * 0.03
		st.set_color(Color(1, 1, 0))
		st.add_vertex(base - side)
		st.add_vertex(base + side)
		st.add_vertex(base + Vector3(0, h, 0) + lean)
	if flower:
		for i in 3:
			var a := rng.randf() * TAU
			var c := Vector3(cos(a) * 0.1, rng.randf_range(0.45, 0.6), sin(a) * 0.1)
			var s := 0.07
			st.set_color(Color(1, 1, 1))
			for k in 5:
				var a0 := k / 5.0 * TAU
				var a1 := (k + 1) / 5.0 * TAU
				st.add_vertex(c)
				st.add_vertex(c + Vector3(cos(a0), 0.15, sin(a0)) * s)
				st.add_vertex(c + Vector3(cos(a1), 0.15, sin(a1)) * s)
	st.generate_normals()
	return st.commit()


func scatter_grass(parent: Node3D, count: int, col_base: Color, col_tip: Color, flower_colors: Array = [], flower_ratio := 0.12, max_flat_dist := 22.0, min_flat_dist := -999.0, avoid_paths := true) -> void:
	if _grass_mesh == null:
		_grass_mesh = _clump(false)
		_flower_mesh = _clump(true)
	var q := Game.quality_level()
	count = int(count * [0.3, 0.6, 1.0][q])
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var gx: Array = []
	var fx: Array = []
	var fc: Array = []
	var tries := 0
	while gx.size() + fx.size() < count and tries < count * 6:
		tries += 1
		var x := center.x + rng.randf_range(-size.x * 0.5, size.x * 0.5)
		var z := center.z + rng.randf_range(-size.y * 0.5, size.y * 0.5)
		var fd := flat_dist(x, z)
		if fd > max_flat_dist or fd < min_flat_dist:
			continue
		if avoid_paths and path_mask(x, z) > 0.35:
			continue
		var y := height(x, z)
		if y < -0.3:
			continue
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.0, rng.randf_range(0.55, 1.1), 1.0) * rng.randf_range(0.6, 0.95)), Vector3(x, y - 0.02, z))
		if not flower_colors.is_empty() and rng.randf() < flower_ratio:
			fx.append(t)
			fc.append(flower_colors[rng.randi() % flower_colors.size()])
		else:
			gx.append(t)
	var mat := Shaders.grass(col_base, col_tip, [35.0, 55.0, 80.0][q])
	_mm(parent, _grass_mesh, mat, gx, [])
	if not fx.is_empty():
		_mm(parent, _flower_mesh, mat, fx, fc)


static func _mm(parent: Node3D, mesh: Mesh, mat: Material, xs: Array, customs: Array) -> void:
	if xs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
		mm.set_instance_custom_data(i, customs[i] if i < customs.size() else Color(0, 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


func build_rivers(parent: Node3D) -> void:
	## Faixas de água sobre os leitos escavados pelos rios.
	for r in rivers:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		var w: float = r[2]
		var d := b - a
		d.y = 0
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := int(d.length() / 2.0) + 1
		var side := Vector3(-d.z, 0, d.x).normalized()
		for i in n + 1:
			var p := a + d * (float(i) / n)
			for k in 5:
				var s := (k / 4.0) * 2.0 - 1.0
				st.set_color(Color(1.0 - absf(s), 0, 0))
				st.add_vertex(p + side * s * (w + 0.8) + Vector3(0, -0.25, 0))
		for i in n:
			for k in 4:
				var i0 := i * 5 + k
				st.add_index(i0)
				st.add_index(i0 + 5)
				st.add_index(i0 + 1)
				st.add_index(i0 + 1)
				st.add_index(i0 + 5)
				st.add_index(i0 + 6)
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var m := Shaders.water()
		m.set_shader_parameter("flow", Vector2(d.x, d.z).normalized() * 0.6)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
