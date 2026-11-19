class_name Nature
extends RefCounted
## Vegetação, rochas, cordilheiras e raios de luz no estilo das artes de referência
## (copas volumosas, cedros altíssimos, bordos vermelhos, montanhas nevadas).

const PAL := {
	"green": [Color(0.02, 0.1, 0.07), Color(0.3, 0.46, 0.15)],
	"deep": [Color(0.02, 0.08, 0.07), Color(0.18, 0.34, 0.18)],
	"cedar": [Color(0.015, 0.08, 0.08), Color(0.2, 0.36, 0.2)],
	"cherry": [Color(0.72, 0.38, 0.52), Color(1.0, 0.84, 0.9)],
	"maple": [Color(0.38, 0.03, 0.04), Color(0.98, 0.32, 0.16)],
	"autumn": [Color(0.45, 0.2, 0.04), Color(0.95, 0.62, 0.18)],
	"night": [Color(0.02, 0.06, 0.07), Color(0.12, 0.25, 0.25)],
	"ash": [Color(0.12, 0.1, 0.08), Color(0.35, 0.3, 0.2)],
	"bamboo": [Color(0.05, 0.15, 0.06), Color(0.34, 0.5, 0.18)],
}

static var _blobs: Array = []
static var _rocks: Array = []
static var _trunk: ArrayMesh
static var _fern: ArrayMesh
static var _shaft_mesh: QuadMesh


static func gy(p: Vector3) -> Vector3:
	## Ajusta a altura ao terreno quando a posição está no nível 0.
	if absf(p.y) < 0.001:
		return Vector3(p.x, Terrain.ground_y(p.x, p.z), p.z)
	return p


# -------------------------------------------------------------- malhas base
static func _displaced_sphere(seed_v: int, amount: float, rad_seg := 14, rings := 8) -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = rad_seg
	sm.rings = rings
	var arr := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = 1.4
	for i in verts.size():
		var v := verts[i]
		var d := 1.0 + n.get_noise_3dv(v * 1.0) * amount
		verts[i] = v * d
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in idx:
		st.add_vertex(verts[i])
	st.generate_normals()
	return st.commit()


static func blob(i: int) -> ArrayMesh:
	if _blobs.is_empty():
		for k in 4:
			_blobs.append(_displaced_sphere(10 + k, 0.38))
	return _blobs[i % _blobs.size()]


static func rock_mesh(i: int) -> ArrayMesh:
	if _rocks.is_empty():
		for k in 4:
			_rocks.append(_displaced_sphere(50 + k, 0.5, 9, 6))
	return _rocks[i % _rocks.size()]


static func trunk_mesh() -> ArrayMesh:
	if _trunk:
		return _trunk
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 9
	var rings := 8
	var n := FastNoiseLite.new()
	n.frequency = 2.0
	for r in rings + 1:
		var t := float(r) / rings
		var rad := lerpf(1.0, 0.45, t) + (0.6 * pow(1.0 - t, 6.0))   # raízes alargadas
		for s in seg + 1:
			var a := float(s) / seg * TAU
			var bump := 1.0 + n.get_noise_2d(a * 2.0, t * 6.0) * 0.18
			st.set_uv(Vector2(float(s) / seg, t))
			st.add_vertex(Vector3(cos(a) * rad * bump, t, sin(a) * rad * bump))
	for r in rings:
		for s in seg:
			var i := r * (seg + 1) + s
			st.add_index(i)
			st.add_index(i + seg + 1)
			st.add_index(i + 1)
			st.add_index(i + 1)
			st.add_index(i + seg + 1)
			st.add_index(i + seg + 2)
	st.generate_normals()
	_trunk = st.commit()
	return _trunk


static func fern_mesh() -> ArrayMesh:
	if _fern:
		return _fern
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in 9:
		var a := float(f) / 9.0 * TAU
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x)
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for k in 6:
			var t := float(k + 1) / 6.0
			var c := dir * t * 1.1 + Vector3(0, sin(t * 2.2) * 0.55, 0)
			var w := sin(t * PI) * 0.22
			var l := c + side * w
			var r := c - side * w
			if k > 0:
				st.add_vertex(prev_l); st.add_vertex(l); st.add_vertex(c)
				st.add_vertex(prev_r); st.add_vertex(c); st.add_vertex(r)
			else:
				st.add_vertex(Vector3.ZERO); st.add_vertex(l); st.add_vertex(r)
			prev_l = l
			prev_r = r
	st.generate_normals()
	_fern = st.commit()
	return _fern


static func bark(col := Color(0.32, 0.2, 0.13)) -> StandardMaterial3D:
	return Props.mat(col, 1.0, 0.0, 0.0, true)


# ---------------------------------------------------------------- árvores
static func big_tree(parent: Node, pos: Vector3, rnd: RandomNumberGenerator, s := 1.0, pal := "green", collide := true) -> void:
	## Árvore frondosa (carvalho/bordo/cerejeira) com tronco retorcido e copa em camadas.
	pos = gy(pos)
	var p: Array = PAL[pal]
	var fol := Shaders.foliage(p[0], p[1], 0.1, pal)
	var h := rnd.randf_range(5.0, 7.5) * s
	var lean := Vector3(rnd.randf_range(-0.12, 0.12), 0, rnd.randf_range(-0.12, 0.12))
	var bark_c := Color(0.28, 0.18, 0.12) if pal != "cherry" else Color(0.22, 0.13, 0.12)
	Props.batch_add("trunk_" + pal, trunk_mesh(), bark(bark_c), Props.xf(pos, lean, Vector3(0.45 * s, h, 0.45 * s)))
	var top := pos + Vector3(lean.z * -h, h, lean.x * h)
	for i in rnd.randi_range(3, 4):
		var a := rnd.randf() * TAU + i * 1.7
		var d := Vector3(cos(a), 0, sin(a))
		var len := rnd.randf_range(2.0, 3.4) * s
		var bp := pos + Vector3(0, h * rnd.randf_range(0.55, 0.85), 0)
		var axis := Vector3.UP.cross(d).normalized()
		var bb := Basis(axis, rnd.randf_range(0.8, 1.1))
		Props.batch_add("branch_" + pal, trunk_mesh(), bark(bark_c), Transform3D(bb.scaled(Vector3(0.14 * s, len, 0.14 * s)), bp))
		var tip := bp + bb * Vector3(0, len, 0)
		Props.batch_add("canopy_%s_%d" % [pal, i % 4], blob(i), fol, Props.xf(tip + Vector3(0, 0.6 * s, 0), Vector3(0, rnd.randf() * TAU, 0), Vector3(2.2, 1.5, 2.2) * s * rnd.randf_range(0.85, 1.2)))
	for i in 4:
		var off := Vector3(rnd.randf_range(-1.6, 1.6), rnd.randf_range(0.2, 1.6), rnd.randf_range(-1.6, 1.6)) * s
		Props.batch_add("canopy_%s_%d" % [pal, (i + 1) % 4], blob(i + 1), fol, Props.xf(top + off, Vector3(0, rnd.randf() * TAU, 0), Vector3(2.6, 1.8, 2.6) * s * rnd.randf_range(0.8, 1.15)))
	if collide:
		var b := Props.body(parent, pos)
		Props.add_cyl_shape(b, 0.5 * s, h, Vector3(0, h * 0.5, 0))


static func cedar(parent: Node, pos: Vector3, rnd: RandomNumberGenerator, s := 1.0, pal := "cedar", collide := true) -> void:
	## Cedro altíssimo de tronco reto e copa alta (como na floresta de referência).
	pos = gy(pos)
	var p: Array = PAL[pal]
	var fol := Shaders.foliage(p[0], p[1], 0.06, pal + "_c")
	var h := rnd.randf_range(16.0, 24.0) * s
	Props.batch_add("cedar_trunk", trunk_mesh(), bark(Color(0.36, 0.2, 0.13)), Props.xf(pos, Vector3(rnd.randf_range(-0.03, 0.03), 0, rnd.randf_range(-0.03, 0.03)), Vector3(0.55 * s, h, 0.55 * s)))
	var y := h * 0.45
	var k := 0
	while y < h + 2.0:
		var t := (y - h * 0.45) / (h * 0.55)
		var r := lerpf(2.6, 1.2, clampf(t, 0, 1)) * s
		var off := Vector3(rnd.randf_range(-1, 1), 0, rnd.randf_range(-1, 1)) * r * 0.5
		Props.batch_add("cedar_fol_%d" % (k % 3), blob(k), fol, Props.xf(pos + Vector3(0, y, 0) + off, Vector3(0, rnd.randf() * TAU, 0), Vector3(r, r * 0.6, r)))
		y += rnd.randf_range(1.6, 2.6) * s
		k += 1
	if collide:
		var b := Props.body(parent, pos)
		Props.add_cyl_shape(b, 0.6 * s, 6.0, Vector3(0, 3.0, 0))


static func pine(parent: Node, pos: Vector3, rnd: RandomNumberGenerator, s := 1.0, pal := "deep", collide := true) -> void:
	pos = gy(pos)
	var p: Array = PAL[pal]
	var fol := Shaders.foliage(p[0], p[1], 0.05, pal + "_p")
	var h := rnd.randf_range(7.0, 11.0) * s
	Props.batch_add("pine_trunk2", trunk_mesh(), bark(Color(0.25, 0.15, 0.1)), Props.xf(pos, Vector3.ZERO, Vector3(0.3 * s, h * 0.6, 0.3 * s)))
	var cone := Props.cyl_mesh(0.0, 1.0, 1.0, 9)
	for i in 5:
		var t := float(i) / 5.0
		var r := (2.4 - t * 1.8) * s
		Props.batch_add("pine2_%s_%d" % [pal, i % 2], cone, fol, Props.xf(pos + Vector3(0, h * (0.25 + t * 0.62), 0), Vector3(rnd.randf_range(-0.05, 0.05), rnd.randf() * TAU, 0), Vector3(r, h * 0.3, r)))
	if collide:
		var b := Props.body(parent, pos)
		Props.add_cyl_shape(b, 0.35 * s, h * 0.6, Vector3(0, h * 0.3, 0))


static func bush(pos: Vector3, rnd: RandomNumberGenerator, pal := "green", s := 1.0) -> void:
	pos = gy(pos)
	var p: Array = PAL[pal]
	var fol := Shaders.foliage(p[0], p[1], 0.05, pal + "_b")
	for i in 3:
		var off := Vector3(rnd.randf_range(-0.7, 0.7), 0.35, rnd.randf_range(-0.7, 0.7)) * s
		Props.batch_add("bush_%s" % pal, blob(i + 2), fol, Props.xf(pos + off, Vector3(0, rnd.randf() * TAU, 0), Vector3(1.0, 0.7, 0.9) * s * rnd.randf_range(0.6, 1.1)))


static func fern(pos: Vector3, rnd: RandomNumberGenerator, pal := "green", s := 1.0) -> void:
	pos = gy(pos)
	var p: Array = PAL[pal]
	var fol := Shaders.foliage(p[0], p[1], 0.12, pal + "_f")
	Props.batch_add("fern_%s" % pal, fern_mesh(), fol, Props.xf(pos, Vector3(0, rnd.randf() * TAU, 0), Vector3.ONE * s * rnd.randf_range(0.7, 1.3)))


static func boulder(parent: Node, pos: Vector3, scl: Vector3, rnd: RandomNumberGenerator, col := Color(0.42, 0.42, 0.44), collide := true) -> void:
	pos = gy(pos)
	var i := rnd.randi_range(0, 3)
	Props.batch_add("boulder_%d" % i, rock_mesh(i), rock_mat(col), Props.xf(pos, Vector3(rnd.randf() * 0.5, rnd.randf() * TAU, rnd.randf() * 0.3), scl))
	if collide and scl.length() > 1.2:
		var b := Props.body(parent, pos)
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = minf(scl.x, scl.z) * 0.85
		cs.shape = sh
		b.add_child(cs)


static var _rock_mats := {}


static func rock_mat(col: Color) -> ShaderMaterial:
	var k := col.to_html()
	if _rock_mats.has(k):
		return _rock_mats[k]
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = ROCK
	m.shader = sh
	m.set_shader_parameter("rock", col)
	_rock_mats[k] = m
	return m


const ROCK := """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform vec3 rock : source_color = vec3(0.42, 0.42, 0.44);
uniform vec3 moss : source_color = vec3(0.22, 0.42, 0.14);
varying vec3 wn;
varying vec3 wp;
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }
void vertex() { wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = n2(wp.xz * 1.3 + wp.y) * 0.5 + n2(wp.xy * 3.7) * 0.3 + n2(wp.zy * 7.0) * 0.2;
	vec3 c = rock * (0.7 + 0.55 * n);
	float m = smoothstep(0.45, 0.8, wn.y + (n - 0.5) * 0.5);
	ALBEDO = mix(c, moss * (0.8 + 0.4 * n), m);
	ROUGHNESS = 1.0;
}
"""


# ------------------------------------------------------------- montanhas
const MOUNTAIN := """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform vec3 low : source_color = vec3(0.15, 0.3, 0.16);
uniform vec3 mid : source_color = vec3(0.42, 0.42, 0.46);
uniform vec3 snow : source_color = vec3(0.95, 0.96, 1.0);
uniform float h_mid = 40.0;
uniform float h_snow = 110.0;
varying vec3 wp;
varying vec3 wn;
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	float n = n2(wp.xz * 0.05) * 0.6 + n2(wp.xz * 0.2) * 0.4;
	float y = wp.y + (n - 0.5) * 25.0;
	vec3 c = mix(low * (0.8 + 0.4 * n), mid * (0.75 + 0.5 * n), smoothstep(h_mid - 15.0, h_mid + 15.0, y));
	float sn = smoothstep(h_snow - 10.0, h_snow + 10.0, y) * smoothstep(0.2, 0.6, wn.y + 0.2);
	c = mix(c, snow, sn);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
"""


static func mountain_range(parent: Node, center: Vector3, r_in: float, r_out: float, max_h: float, cols: Array = [], seed_v := 1, arc_from := 0.0, arc_to := TAU) -> void:
	## Anel de cordilheiras recortadas ao redor do mapa (picos com neve).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = 0.9
	n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	n.fractal_octaves = 5
	var seg := 160
	var rad := 10
	for i in seg + 1:
		var a := lerpf(arc_from, arc_to, float(i) / seg)
		for k in rad + 1:
			var t := float(k) / rad
			var r := lerpf(r_in, r_out, t)
			var dir := Vector3(cos(a), 0, sin(a))
			var prof := sin(t * PI)
			var nv := n.get_noise_2d(cos(a) * 3.0 + t * 0.8, sin(a) * 3.0 + t * 0.6) * 0.5 + 0.5
			var hh := max_h * prof * (0.25 + nv * 1.1)
			st.add_vertex(center + dir * r + Vector3(0, hh - 2.0, 0))
	for i in seg:
		for k in rad:
			var i0 := i * (rad + 1) + k
			st.add_index(i0)
			st.add_index(i0 + 1)
			st.add_index(i0 + rad + 1)
			st.add_index(i0 + 1)
			st.add_index(i0 + rad + 2)
			st.add_index(i0 + rad + 1)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = MOUNTAIN
	m.shader = sh
	if cols.size() >= 3:
		m.set_shader_parameter("low", cols[0])
		m.set_shader_parameter("mid", cols[1])
		m.set_shader_parameter("snow", cols[2])
	m.set_shader_parameter("h_mid", max_h * 0.35)
	m.set_shader_parameter("h_snow", max_h * 0.72)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


# ----------------------------------------------------------- raios de luz
static func light_shafts(parent: Node, center: Vector3, area: Vector2, count: int, sun_rot_deg: Vector3, col := Color(1.0, 0.95, 0.75), strength := 0.18) -> void:
	if Game.quality_level() == 0:
		count = count / 2
	if _shaft_mesh == null:
		_shaft_mesh = QuadMesh.new()
		_shaft_mesh.size = Vector2(1, 1)
		_shaft_mesh.center_offset = Vector3(0, 0.5, 0)
	var mat := Shaders.shaft(col, strength)
	var sun_basis := Basis.from_euler(sun_rot_deg * PI / 180.0)
	var light_dir := -sun_basis.z   # direção em que a luz viaja
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in count:
		var p := center + Vector3(rng.randf_range(-area.x, area.x), 0, rng.randf_range(-area.y, area.y))
		p.y = Terrain.ground_y(p.x, p.z)
		var up := -light_dir.normalized()
		var length := rng.randf_range(18.0, 30.0)
		for k in 2:
			var mi := MeshInstance3D.new()
			mi.mesh = _shaft_mesh
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mi)
			var side := up.cross(Vector3(1, 0, 0) if absf(up.x) < 0.9 else Vector3(0, 0, 1)).normalized().rotated(up, k * PI / 2 + rng.randf())
			var fwd := side.cross(up).normalized()
			mi.global_transform = Transform3D(Basis(side * rng.randf_range(1.5, 3.5), up * length, fwd), p)
