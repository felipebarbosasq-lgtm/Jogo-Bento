class_name CharacterModel
extends Node3D
## Modelo humanoide procedural (samurai) com animação por poses.
## Construído apenas com primitivas — nenhum arquivo externo — e animado em
## código através de interpolação entre poses-chave (descanso, andar, correr,
## ataques, defesa, esquiva, dano, morte, etc.). Frente do modelo = -Z.

const JOINTS := ["pelvis", "torso", "head", "sh_r", "el_r", "sh_l", "el_l", "hip_r", "kn_r", "hip_l", "kn_l", "wpn", "root"]

var cfg := {}
var j := {}            # nome da junta -> Node3D
var cur := {}          # rotação atual de cada junta
var lift := 0.0        # deslocamento vertical da pélvis
var _cur_lift := 0.0
var meshes: Array[MeshInstance3D] = []
var weapon_tip: Node3D
var weapon_node: Node3D
var blade_mat: StandardMaterial3D

# Estado de animação
var action := ""
var action_time := 0.0
var action_dur := 1.0
var loop_action := false
var move_speed := 0.0      # m/s, para o ciclo de passos
var run_ref := 6.0
var stance := "sword"      # sword / bow
var _phase := 0.0
var _t := 0.0
var _flash_mat: StandardMaterial3D
var _flash_time := 0.0
var step_callback: Callable
var _last_step_sign := 0.0
var aura: CPUParticles3D
var cloth: Array = []      # [nó, rotação de repouso, amplitude, fase]
var _caps := {}
var _outline_mat: Material
var _last_pos := Vector3.INF
var _vel := Vector3.ZERO

const PELVIS_H := 0.98


func setup(config: Dictionary) -> void:
	cfg = {
		"skin": Color(0.8, 0.62, 0.5),
		"hair": Color(0.04, 0.04, 0.05),
		"armor": Color(0.1, 0.1, 0.12),
		"armor2": Color(0.2, 0.19, 0.22),
		"trim": Color(0.62, 0.05, 0.08),
		"cloth": Color(0.09, 0.09, 0.11),
		"hakama": Color(0.07, 0.07, 0.08),
		"metal": Color(0.75, 0.76, 0.8),
		"helmet": "none",     # none / kabuto / jingasa / oni
		"hair_style": "shin", # shin / topknot / none
		"weapon": "katana",   # katana / odachi / bow / spear
		"mask": false,
		"cape": false,
		"eyes": Color(0, 0, 0, 0),
		"blade_glow": 0.0,
		"blade_color": Color(0.82, 0.84, 0.9),
		"scale": 1.0,
		"crest": Color(0.85, 0.65, 0.2),
		"mon": true,
	}
	for k in config.keys():
		cfg[k] = config[k]
	_build()
	scale = Vector3.ONE * float(cfg.scale)
	stance = "bow" if cfg.weapon == "bow" else "sword"
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.albedo_color = Color(1, 1, 1, 0.0)
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_mat.disable_fog = true
	for name in JOINTS:
		cur[name] = Vector3.ZERO


# ------------------------------------------------------------------ construção
func _m(c: Color, rough := 0.7, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
	return Props.mat(c, rough, metal, emit, true, 0.5)


func _part(parent: Node3D, m: Mesh, pos: Vector3, material: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := Props.mesh(parent, m, pos, material, rot, scl)
	meshes.append(mi)
	return mi


func _joint(name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	parent.add_child(n)
	j[name] = n
	return n


func _cap(r: float, h: float) -> CapsuleMesh:
	var key := "cap%.3f_%.3f" % [r, h]
	if _caps.has(key):
		return _caps[key]
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0 + 0.001)
	c.radial_segments = 12
	c.rings = 4
	_caps[key] = c
	return c


func _sph(seg := 14, rings := 8) -> SphereMesh:
	return Props.sphere_mesh(1.0, seg, rings)


func _cloth(parent: Node3D, pos: Vector3, size: Vector3, material: Material, rest := Vector3.ZERO, amp := 1.0, tattered := false) -> Node3D:
	## Peça de tecido pendurada que balança com o movimento e o vento.
	var piv := Node3D.new()
	piv.position = pos
	piv.rotation = rest
	parent.add_child(piv)
	var segs := 3
	var prev: Node3D = piv
	var seg_h := size.y / segs
	for k in segs:
		var w := size.x * (1.0 - k * 0.12)
		var mi := _part(prev, Props.box_mesh(Vector3(w, seg_h, size.z)), Vector3(0, -seg_h * 0.5, 0), material)
		if tattered and k == segs - 1:
			for t in 3:
				_part(prev, Props.prism_mesh(Vector3(w / 3.0, seg_h * 0.5, size.z)), Vector3(-w / 3.0 + t * w / 3.0, -seg_h - seg_h * 0.2, 0), material, Vector3(PI, 0, 0))
		var nxt := Node3D.new()
		nxt.position = Vector3(0, -seg_h, 0)
		prev.add_child(nxt)
		cloth.append([prev, prev.rotation, amp * (0.6 + k * 0.4), randf() * TAU])
		prev = nxt
	return piv


func _build() -> void:
	var skin := _m(cfg.skin, 0.8)
	var hair := _m(cfg.hair, 0.55)
	var armor := _m(cfg.armor, 0.4, 0.45)
	var armor2 := _m(cfg.armor2, 0.5, 0.3)
	var trim := _m(cfg.trim, 0.75)
	var cloth_m := _m(cfg.cloth, 0.9)
	var hakama := _m(cfg.hakama, 0.9)
	var metal := _m(cfg.metal, 0.25, 0.8)
	var glove := _m(Color(0.06, 0.05, 0.05), 0.7, 0.2)
	var gold := _m(cfg.crest, 0.3, 0.8)

	var root := _joint("root", self, Vector3.ZERO)
	var pelvis := _joint("pelvis", root, Vector3(0, PELVIS_H, 0))
	_part(pelvis, _sph(), Vector3(0, -0.02, 0), hakama, Vector3.ZERO, Vector3(0.2, 0.15, 0.15))
	# obi (faixa) e nó
	_part(pelvis, Props.cyl_mesh(1.0, 1.0, 1.0, 16), Vector3(0, 0.08, 0), trim, Vector3.ZERO, Vector3(0.205, 0.1, 0.155))
	_part(pelvis, _sph(8, 5), Vector3(-0.08, 0.08, -0.15), trim, Vector3.ZERO, Vector3(0.05, 0.045, 0.035))
	_cloth(pelvis, Vector3(-0.1, 0.06, -0.15), Vector3(0.06, 0.42, 0.012), trim, Vector3(0.05, 0, 0.12), 1.0, true)
	_cloth(pelvis, Vector3(-0.15, 0.06, 0.1), Vector3(0.07, 0.55, 0.012), trim, Vector3(-0.08, 0, 0.18), 1.2, true)
	# tare (pano frontal rasgado) e kusazuri (placas laterais)
	_cloth(pelvis, Vector3(0, 0.0, -0.16), Vector3(0.16, 0.42, 0.015), _m(cfg.get("tare", cfg.trim.darkened(0.35)), 0.9), Vector3(0.1, 0, 0), 0.6, true)
	for i in 5:
		var a := PI * 0.35 + i * 0.32
		var dir := Vector3(sin(a), 0, -cos(a))
		var plate := _part(pelvis, Props.box_mesh(Vector3(0.15, 0.3, 0.025)), Vector3(dir.x * 0.2, -0.12, dir.z * 0.17), armor, Vector3(0.2 * (1.0 if dir.z < 0 else -1.0), a, 0))
		for k in 3:
			_part(plate, Props.box_mesh(Vector3(0.152, 0.012, 0.03)), Vector3(0, 0.1 - k * 0.09, 0), trim)
		var mirror := _part(pelvis, Props.box_mesh(Vector3(0.15, 0.3, 0.025)), Vector3(-dir.x * 0.2, -0.12, dir.z * 0.17), armor, Vector3(0.2 * (1.0 if dir.z < 0 else -1.0), -a, 0))
		for k in 3:
			_part(mirror, Props.box_mesh(Vector3(0.152, 0.012, 0.03)), Vector3(0, 0.1 - k * 0.09, 0), trim)

	var torso := _joint("torso", pelvis, Vector3(0, 0.1, 0))
	_part(torso, _cap(0.15, 0.56), Vector3(0, 0.28, 0), cloth_m, Vector3.ZERO, Vector3(1.25, 1.0, 0.85))
	# dō (peitoral) arredondado com faixas de cordão
	_part(torso, _sph(16, 8), Vector3(0, 0.3, -0.01), armor, Vector3.ZERO, Vector3(0.205, 0.2, 0.15))
	for k in 4:
		_part(torso, Props.cyl_mesh(1.0, 1.0, 1.0, 16), Vector3(0, 0.18 + k * 0.065, -0.01), trim, Vector3.ZERO, Vector3(0.203 - absf(k - 1.5) * 0.014, 0.01, 0.148 - absf(k - 1.5) * 0.012))
	# gola em V e pescoço
	for x in [-1.0, 1.0]:
		_part(torso, Props.box_mesh(Vector3(0.05, 0.22, 0.02)), Vector3(x * 0.05, 0.5, -0.135), cloth_m, Vector3(0.2, 0, -x * 0.45))
	_part(torso, _cap(0.065, 0.16), Vector3(0, 0.56, 0), skin)
	if cfg.mon:
		_part(torso, Props.cyl_mesh(0.03, 0.03, 0.012, 12), Vector3(0.1, 0.32, -0.175), gold, Vector3(PI / 2, 0, 0))
	if cfg.get("straps", false):
		for x in [-1.0, 1.0]:
			_part(torso, Props.box_mesh(Vector3(0.035, 0.6, 0.012)), Vector3(0, 0.32, -0.175), _m(Color(0.25, 0.15, 0.1), 0.8), Vector3(0, 0, x * 0.75))
	if cfg.cape:
		var cape_m := _m(cfg.get("cape_color", cfg.trim.darkened(0.3)), 0.9)
		for i in 5:
			var x := -0.2 + i * 0.1
			_cloth(torso, Vector3(x, 0.52, 0.16), Vector3(0.11, 1.15 + (i % 2) * 0.15, 0.012), cape_m, Vector3(0.18, 0, x * 0.3), 1.3, true)

	# cabeça
	var head := _joint("head", torso, Vector3(0, 0.62, 0))
	_part(head, _sph(16, 10), Vector3(0, 0.12, 0), skin, Vector3.ZERO, Vector3(0.11, 0.13, 0.118))
	_part(head, _sph(10, 6), Vector3(0, 0.05, -0.035), skin, Vector3.ZERO, Vector3(0.085, 0.07, 0.08))  # mandíbula
	_part(head, Props.prism_mesh(Vector3(0.025, 0.04, 0.025)), Vector3(0, 0.1, -0.12), skin, Vector3(-0.3, 0, 0))  # nariz
	var eye_col: Color = cfg.eyes
	var eye_mat := _m(Color(0.04, 0.03, 0.03), 0.5) if eye_col.a == 0.0 else _m(eye_col, 0.5, 0.0, 5.0)
	for x in [-0.045, 0.045]:
		_part(head, Props.box_mesh(Vector3(0.036, 0.012, 0.01)), Vector3(x, 0.13, -0.112), eye_mat, Vector3(0, 0, -x * 3.0))
		_part(head, Props.box_mesh(Vector3(0.05, 0.012, 0.014)), Vector3(x, 0.153, -0.108), hair, Vector3(0, 0, -0.3 if x < 0 else 0.3))
	_build_hair(head, hair, trim)
	_build_helmet(head, armor, armor2, trim)

	# braços
	for side in ["r", "l"]:
		var sx := 1.0 if side == "r" else -1.0
		var sh := _joint("sh_" + side, torso, Vector3(0.26 * sx, 0.46, 0))
		_part(sh, _sph(), Vector3(0.02 * sx, -0.02, 0), cloth_m, Vector3.ZERO, Vector3(0.08, 0.08, 0.08))
		var sode := Node3D.new()
		sode.position = Vector3(0.06 * sx, 0.04, 0)
		sode.rotation = Vector3(0, 0, 0.32 * sx)
		sh.add_child(sode)
		for k in 4:
			_part(sode, Props.box_mesh(Vector3(0.028, 0.058, 0.2 - k * 0.006)), Vector3(0.05 * sx + 0.012 * sx * k, -0.03 - k * 0.052, 0), armor)
			_part(sode, Props.box_mesh(Vector3(0.03, 0.009, 0.202 - k * 0.006)), Vector3(0.05 * sx + 0.012 * sx * k, -0.058 - k * 0.052, 0), trim)
		_part(sh, _cap(0.058, 0.32), Vector3(0, -0.15, 0), cloth_m)
		var el := _joint("el_" + side, sh, Vector3(0, -0.3, 0))
		_part(el, _cap(0.05, 0.28), Vector3(0, -0.13, 0), armor2)
		_part(el, Props.cyl_mesh(0.062, 0.055, 0.17, 10), Vector3(0, -0.15, 0), armor)
		for k in 2:
			_part(el, Props.cyl_mesh(0.064, 0.064, 0.015, 10), Vector3(0, -0.09 - k * 0.11, 0), trim)
		var hand := Node3D.new()
		hand.name = "hand_" + side
		hand.position = Vector3(0, -0.29, 0)
		el.add_child(hand)
		j["hand_" + side] = hand
		_part(hand, _sph(10, 6), Vector3(0, -0.02, 0), glove, Vector3.ZERO, Vector3(0.045, 0.05, 0.05))

	# pernas
	for side in ["r", "l"]:
		var sx := 1.0 if side == "r" else -1.0
		var hp := _joint("hip_" + side, pelvis, Vector3(0.11 * sx, -0.06, 0))
		_part(hp, Props.cyl_mesh(0.11, 0.15, 0.46, 12), Vector3(0, -0.21, 0), hakama)
		var kn := _joint("kn_" + side, hp, Vector3(0, -0.44, 0))
		_part(kn, Props.cyl_mesh(0.13, 0.07, 0.3, 12), Vector3(0, -0.12, 0), hakama)
		_part(kn, _cap(0.055, 0.3), Vector3(0, -0.3, 0), hakama)
		# suneate e joelheira
		_part(kn, Props.cyl_mesh(0.065, 0.06, 0.26, 8), Vector3(0, -0.28, -0.02), armor, Vector3.ZERO, Vector3(1.0, 1.0, 1.1))
		_part(kn, _sph(10, 6), Vector3(0, -0.02, -0.05), armor, Vector3.ZERO, Vector3(0.07, 0.06, 0.05))
		_part(kn, Props.cyl_mesh(0.067, 0.067, 0.012, 8), Vector3(0, -0.2, -0.02), trim)
		# bota
		_part(kn, _cap(0.055, 0.24), Vector3(0, -0.47, -0.05), glove, Vector3(PI / 2, 0, 0))

	_build_weapon(metal, trim)
	_apply_outline()


func _apply_outline() -> void:
	if Game.quality_level() == 0:
		return
	var w: float = 0.007 * float(cfg.get("outline", 1.0))
	_outline_mat = Shaders.outline(w)
	for mi in meshes:
		if is_instance_valid(mi):
			mi.material_overlay = _outline_mat


func _build_hair(head: Node3D, hair: Material, trim: Material) -> void:
	var tip_c: Color = cfg.get("hair_tip", cfg.hair)
	var tip := _m(tip_c, 0.55)
	match str(cfg.hair_style):
		"shin":
			# cabelo preto despenteado com pontas avermelhadas
			_part(head, _sph(), Vector3(0, 0.17, 0.015), hair, Vector3.ZERO, Vector3(0.128, 0.1, 0.132))
			for i in 9:
				var a := -1.3 + i * 0.32
				var spike := _part(head, Props.prism_mesh(Vector3(0.07, 0.17, 0.05)), Vector3(sin(a) * 0.095, 0.21, -0.095 + absf(a) * 0.03), hair if i % 3 else tip, Vector3(-2.25, 0, a * 0.65))
			for i in 9:
				var a := PI * 0.45 + i * 0.25
				_part(head, Props.prism_mesh(Vector3(0.085, 0.24, 0.05)), Vector3(sin(a) * 0.11, 0.14, -cos(a) * 0.1), tip if i % 2 else hair, Vector3(2.5 + (i % 3) * 0.15, a, 0))
			for i in 5:
				var a := -1.0 + i * 0.5
				_part(head, Props.prism_mesh(Vector3(0.06, 0.16, 0.04)), Vector3(sin(a) * 0.08, 0.27, 0.0), hair, Vector3(0.2 * cos(a), 0, a * 0.5))
			for x in [-1.0, 1.0]:
				_part(head, Props.box_mesh(Vector3(0.025, 0.17, 0.08)), Vector3(x * 0.112, 0.08, -0.02), hair, Vector3(0, 0, x * 0.08))
		"long_silver":
			# longos cabelos prateados que caem pelas costas
			_part(head, _sph(), Vector3(0, 0.17, 0.02), hair, Vector3.ZERO, Vector3(0.13, 0.11, 0.135))
			for i in 7:
				var x := -0.11 + i * 0.037
				_cloth(head, Vector3(x, 0.16, 0.1), Vector3(0.05, 0.75 + (i % 3) * 0.12, 0.02), hair, Vector3(0.25, 0, x * 1.2), 0.9)
			for x in [-1.0, 1.0]:
				_cloth(head, Vector3(x * 0.1, 0.14, -0.04), Vector3(0.04, 0.42, 0.02), hair, Vector3(-0.05, 0, x * 0.15), 0.6)
			_part(head, Props.prism_mesh(Vector3(0.18, 0.08, 0.05)), Vector3(0, 0.22, -0.1), hair, Vector3(-2.6, 0, 0))
		"topknot":
			_part(head, _sph(), Vector3(0, 0.16, 0.02), hair, Vector3.ZERO, Vector3(0.125, 0.1, 0.125))
			_part(head, Props.cyl_mesh(0.025, 0.03, 0.12, 6), Vector3(0, 0.29, 0.03), hair, Vector3(-0.9, 0, 0))
		_:
			pass


func _build_helmet(head: Node3D, armor: Material, armor2: Material, trim: Material) -> void:
	match str(cfg.helmet):
		"jingasa", "straw":
			var big: bool = cfg.helmet == "straw"
			var hat := _m(Color(0.32, 0.24, 0.14) if not big else Color(0.12, 0.1, 0.09), 0.85)
			var r := 0.34 if not big else 0.46
			_part(head, Props.cyl_mesh(0.02, r, 0.17 if not big else 0.2, 20), Vector3(0, 0.3, 0), hat, Vector3(0.08 if big else 0.0, 0, 0))
			for k in 6:
				_part(head, Props.box_mesh(Vector3(0.006, 0.19, r * 1.02)), Vector3(0, 0.3, 0), _m(Color(0.0, 0.0, 0.0, 1.0).lerp(hat.albedo_color, 0.6)), Vector3(0.95, k * PI / 6.0, 0))
			_part(head, Props.cyl_mesh(r, r, 0.012, 20), Vector3(0, 0.215, 0), _m(Color(0.1, 0.07, 0.05)))
		"hood":
			# capuz escuro com rosto na sombra (inspirado no guerreiro encapuzado)
			var hood := _m(cfg.get("hood_color", Color(0.06, 0.06, 0.08)), 0.95)
			_part(head, _sph(), Vector3(0, 0.15, 0.03), hood, Vector3.ZERO, Vector3(0.16, 0.18, 0.17))
			_part(head, Props.prism_mesh(Vector3(0.22, 0.2, 0.2)), Vector3(0, 0.3, 0.02), hood, Vector3(-0.2, 0, 0))
			_part(head, _sph(), Vector3(0, 0.11, -0.06), _m(Color(0.0, 0.0, 0.0), 1.0), Vector3.ZERO, Vector3(0.1, 0.11, 0.08))
			_cloth(head, Vector3(0, 0.05, 0.12), Vector3(0.26, 0.4, 0.02), hood, Vector3(0.2, 0, 0), 0.8, true)
		"kabuto", "oni":
			_part(head, _sph(16, 8), Vector3(0, 0.19, 0.01), armor, Vector3.ZERO, Vector3(0.15, 0.13, 0.158))
			for k in 3:
				_part(head, Props.cyl_mesh(0.17 + k * 0.025, 0.19 + k * 0.025, 0.05, 16), Vector3(0, 0.12 - k * 0.05, 0.03), armor if k % 2 == 0 else trim)
			for x in [-1.0, 1.0]:
				_part(head, Props.box_mesh(Vector3(0.1, 0.09, 0.02)), Vector3(x * 0.17, 0.16, -0.09), armor2, Vector3(0, x * 0.5, 0))
			_part(head, Props.box_mesh(Vector3(0.3, 0.02, 0.08)), Vector3(0, 0.23, -0.13), armor)
			var crest := _m(cfg.crest, 0.3, 0.7, 0.4)
			if cfg.helmet == "oni":
				for x in [-1.0, 1.0]:
					var horn := _part(head, Props.cyl_mesh(0.005, 0.035, 0.32, 6), Vector3(x * 0.1, 0.4, -0.04), crest, Vector3(-0.2, 0, -x * 0.45))
					horn.name = "horn"
			else:
				for x in [-1.0, 1.0]:
					_part(head, Props.box_mesh(Vector3(0.025, 0.28, 0.015)), Vector3(x * 0.09, 0.39, -0.12), crest, Vector3(-0.15, 0, -x * 0.35))
				_part(head, Props.cyl_mesh(0.04, 0.04, 0.015, 10), Vector3(0, 0.3, -0.14), crest, Vector3(PI / 2, 0, 0))
		"oni_crown":
			# tiara com chifres sobre o cabelo solto (Lorde Akuma)
			var crest := _m(cfg.crest, 0.3, 0.7, 0.6)
			_part(head, Props.cyl_mesh(0.14, 0.14, 0.03, 16), Vector3(0, 0.2, 0), _m(Color(0.1, 0.05, 0.05), 0.4, 0.6))
			for x in [-1.0, 1.0]:
				_part(head, Props.cyl_mesh(0.004, 0.03, 0.26, 6), Vector3(x * 0.09, 0.32, -0.05), crest, Vector3(-0.35, 0, -x * 0.5))
	if cfg.mask:
		var mask_col: Color = cfg.trim if cfg.helmet != "oni" else Color(0.55, 0.04, 0.05)
		_part(head, Props.box_mesh(Vector3(0.2, 0.11, 0.06)), Vector3(0, 0.06, -0.1), _m(mask_col, 0.5, 0.2))
		_part(head, Props.box_mesh(Vector3(0.12, 0.015, 0.01)), Vector3(0, 0.055, -0.132), _m(Color(0.9, 0.88, 0.8)))


func _build_weapon(metal: Material, trim: Material) -> void:
	var hand: Node3D = j["hand_r"]
	var wpn := _joint("wpn", hand, Vector3(0, -0.03, 0))
	weapon_node = wpn
	var wt := str(cfg.weapon)
	var handle_m := _m(Color(0.08, 0.06, 0.06), 0.8)
	var bc: Color = cfg.blade_color
	blade_mat = Props.mat(bc, 0.2, 0.9, float(cfg.blade_glow))
	weapon_tip = Node3D.new()
	wpn.add_child(weapon_tip)
	match wt:
		"katana", "odachi":
			var bl := 0.85 if wt == "katana" else 1.25
			_part(wpn, Props.box_mesh(Vector3(0.035, 0.035, 0.26)), Vector3(0, 0, 0.02), handle_m)
			for k in 4:
				_part(wpn, Props.box_mesh(Vector3(0.04, 0.04, 0.012)), Vector3(0, 0, 0.12 - k * 0.07), trim)
			_part(wpn, Props.cyl_mesh(0.06, 0.06, 0.015, 10), Vector3(0, 0, -0.12), _m(Color(0.2, 0.17, 0.1), 0.4, 0.7), Vector3(PI / 2, 0, 0))
			# lâmina levemente curva (dois segmentos)
			_part(wpn, Props.box_mesh(Vector3(0.012, 0.045, bl * 0.55)), Vector3(0, 0, -0.13 - bl * 0.275), blade_mat)
			_part(wpn, Props.box_mesh(Vector3(0.011, 0.04, bl * 0.47)), Vector3(0, 0.012, -0.13 - bl * 0.55 - bl * 0.22), blade_mat, Vector3(-0.06, 0, 0))
			weapon_tip.position = Vector3(0, 0.02, -0.13 - bl)
			# bainha (saya) na cintura
			var saya := Node3D.new()
			saya.position = Vector3(-0.2, 0.02, 0.0)
			saya.rotation = Vector3(-1.2, 0.0, 0.25)
			(j["pelvis"] as Node3D).add_child(saya)
			_part(saya, Props.box_mesh(Vector3(0.045, 0.06, bl + 0.05)), Vector3(0, 0, -bl * 0.35), _m(Color(0.05, 0.04, 0.05), 0.4, 0.2))
			_part(saya, Props.box_mesh(Vector3(0.05, 0.065, 0.03)), Vector3(0, 0, 0.1), trim)
			if wt == "katana":
				# wakizashi (espada curta) também na cintura
				_part(saya, Props.box_mesh(Vector3(0.035, 0.05, 0.55)), Vector3(0.05, 0.03, -0.15), _m(Color(0.07, 0.05, 0.05), 0.4, 0.2))
				_part(saya, Props.box_mesh(Vector3(0.03, 0.03, 0.16)), Vector3(0.05, 0.03, 0.2), trim)
		"scimitar":
			# lâminas curvas ornamentadas (empunhadura dupla)
			for hn in (["hand_r", "hand_l"] if cfg.get("dual", false) else ["hand_r"]):
				var holder: Node3D = wpn
				if hn == "hand_l":
					holder = Node3D.new()
					(j["hand_l"] as Node3D).add_child(holder)
					holder.position = Vector3(0, -0.03, 0)
					holder.rotation = Vector3(-0.9, 0, 0)
				_part(holder, Props.box_mesh(Vector3(0.035, 0.035, 0.22)), Vector3(0, 0, 0.03), handle_m)
				_part(holder, Props.box_mesh(Vector3(0.14, 0.03, 0.03)), Vector3(0, 0, -0.09), _m(cfg.crest, 0.3, 0.8))
				for k in 5:
					var t := float(k) / 5.0
					_part(holder, Props.box_mesh(Vector3(0.012, 0.075 - t * 0.035, 0.26)), Vector3(0, t * t * 0.26, -0.22 - t * 0.19), blade_mat, Vector3(-t * 0.5, 0, 0))
			weapon_tip.position = Vector3(0, 0.3, -1.0)
		"spear":
			_part(wpn, Props.cyl_mesh(0.02, 0.02, 2.2, 6), Vector3(0, 0, -0.5), _m(Color(0.25, 0.15, 0.08)), Vector3(PI / 2, 0, 0))
			_part(wpn, Props.prism_mesh(Vector3(0.06, 0.3, 0.015)), Vector3(0, 0, -1.75), blade_mat, Vector3(-PI / 2, 0, 0))
			weapon_tip.position = Vector3(0, 0, -1.9)
		"bow":
			# arco na mão esquerda, aljava nas costas
			var lh: Node3D = j["hand_l"]
			var bow := Node3D.new()
			bow.name = "bow"
			bow.position = Vector3(0, -0.03, 0)
			lh.add_child(bow)
			var wood := _m(Color(0.3, 0.12, 0.08), 0.6)
			for k in 7:
				var a := -0.9 + k * 0.3
				_part(bow, Props.box_mesh(Vector3(0.025, 0.25, 0.03)), Vector3(0, sin(a) * 0.75, -cos(a) * 0.2 + 0.2), wood, Vector3(a * 0.35, 0, 0))
			_part(bow, Props.box_mesh(Vector3(0.004, 1.4, 0.004)), Vector3(0, 0, 0.2), _m(Color(0.9, 0.9, 0.85)))
			var quiver := _part(j["torso"], Props.cyl_mesh(0.06, 0.06, 0.55, 8), Vector3(0.1, 0.3, 0.17), _m(Color(0.25, 0.15, 0.08)), Vector3(0, 0, 0.35))
			for k in 4:
				_part(quiver, Props.cyl_mesh(0.006, 0.006, 0.2, 4), Vector3(-0.02 + k * 0.015, 0.35, 0), _m(Color(0.85, 0.82, 0.75)))
			# faca curta na mão direita (tantō) para defesa
			_part(wpn, Props.box_mesh(Vector3(0.03, 0.03, 0.12)), Vector3(0, 0, 0.02), handle_m)
			_part(wpn, Props.box_mesh(Vector3(0.01, 0.035, 0.28)), Vector3(0, 0, -0.18), blade_mat)
			weapon_tip.position = Vector3(0, 0, -0.32)


# ------------------------------------------------------------------- controle
func play(name: String, duration := 0.5, looped := false) -> void:
	action = name
	action_time = 0.0
	action_dur = maxf(duration, 0.01)
	loop_action = looped


func clear_action() -> void:
	action = ""


func progress() -> float:
	return clampf(action_time / action_dur, 0.0, 1.0)


func flash(color := Color(1, 1, 1), time := 0.1) -> void:
	_flash_mat.albedo_color = Color(color.r, color.g, color.b, 0.6)
	_flash_time = time
	for mi in meshes:
		if is_instance_valid(mi):
			mi.material_overlay = _flash_mat


func set_aura(on: bool, color := Color(0.9, 0.1, 0.1)) -> void:
	if on and aura == null:
		aura = CPUParticles3D.new()
		aura.amount = 40
		aura.lifetime = 1.2
		var qm := QuadMesh.new()
		qm.size = Vector2(0.18, 0.18)
		aura.mesh = qm
		aura.material_override = Props.unshaded(Color.WHITE, true, true)
		aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		aura.emission_box_extents = Vector3(0.4, 0.9, 0.3)
		aura.position = Vector3(0, 1.0, 0)
		aura.direction = Vector3.UP
		aura.spread = 20
		aura.gravity = Vector3(0, 2.5, 0)
		aura.initial_velocity_min = 0.3
		aura.initial_velocity_max = 1.0
		var g := Gradient.new()
		g.set_color(0, Color(color.r, color.g, color.b, 0.9))
		g.set_color(1, Color(color.r * 0.3, 0, 0, 0))
		aura.color_ramp = g
		aura.local_coords = false
		add_child(aura)
	elif not on and aura:
		aura.queue_free()
		aura = null


# ------------------------------------------------------------------- animação
func _process(delta: float) -> void:
	_t += delta
	if action != "":
		action_time += delta
		if action_time >= action_dur:
			if loop_action:
				action_time = fmod(action_time, action_dur)
			elif not _is_hold_action(action):
				action = ""
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			for mi in meshes:
				if is_instance_valid(mi):
					mi.material_overlay = _outline_mat
	var target := _compute_pose(delta)
	var blend := 22.0 if action != "" else 11.0
	var k := clampf(blend * delta, 0.0, 1.0)
	for name in JOINTS:
		var tv: Vector3 = target.get(name, Vector3.ZERO)
		var cv: Vector3 = cur[name]
		cv = cv.lerp(tv, k)
		cur[name] = cv
		var node: Node3D = j[name]
		if name == "root" and action != "special" and action != "spin":
			cv.y = wrapf(cv.y, -PI, PI)
			cur[name] = cv
		node.rotation = cv
	_cur_lift = lerpf(_cur_lift, lift, k)
	_update_cloth(delta)
	(j["pelvis"] as Node3D).position.y = PELVIS_H + _cur_lift


func _is_hold_action(a: String) -> bool:
	return a in ["block", "dead", "stunned", "aim", "charge", "cast", "kneel", "guard_break"]


func _base_pose() -> Dictionary:
	var p := {}
	for name in JOINTS:
		p[name] = Vector3.ZERO
	return p


func _compute_pose(delta: float) -> Dictionary:
	var p := _base_pose()
	lift = 0.0
	# --- locomoção / descanso
	var spd := move_speed
	if spd > 0.3:
		var run_t := clampf((spd - 2.5) / 3.0, 0.0, 1.0)
		var freq := lerpf(7.5, 11.5, run_t)
		_phase += delta * freq * clampf(spd / 3.0, 0.6, 1.4)
		var s := sin(_phase)
		var amp := lerpf(0.55, 0.95, run_t)
		p.hip_r = Vector3(s * amp, 0, 0)
		p.hip_l = Vector3(-s * amp, 0, 0)
		p.kn_r = Vector3(-maxf(0.0, -cos(_phase)) * (0.6 + run_t * 0.8) - 0.1, 0, 0)
		p.kn_l = Vector3(-maxf(0.0, cos(_phase)) * (0.6 + run_t * 0.8) - 0.1, 0, 0)
		lift = -0.03 - abs(cos(_phase)) * 0.05 * (1.0 + run_t)
		p.torso = Vector3(-0.08 - run_t * 0.3, s * 0.12, 0)
		p.pelvis = Vector3(0, -s * 0.08, 0)
		p.head = Vector3(run_t * 0.2, -s * 0.08, 0)
		if stance == "bow":
			p.sh_l = Vector3(-s * 0.5, 0, -0.1)
			p.el_l = Vector3(0.4, 0, 0)
			p.sh_r = Vector3(s * 0.5, 0, 0.1)
			p.el_r = Vector3(0.4, 0, 0)
		else:
			p.sh_l = Vector3(-s * amp * 0.8, 0, -0.12)
			p.el_l = Vector3(0.5 + run_t * 0.6, 0, 0)
			p.sh_r = Vector3(lerpf(0.35, -0.5, run_t) + s * 0.2, 0, 0.15)
			p.el_r = Vector3(lerpf(0.6, 0.4, run_t), 0, 0)
			p.wpn = Vector3(lerpf(-0.6, 0.9, run_t), 0, 0)
		# sons de passos
		var sg := signf(s)
		if sg != _last_step_sign:
			_last_step_sign = sg
			if step_callback.is_valid():
				step_callback.call()
	else:
		var b := sin(_t * 2.0)
		lift = b * 0.008 - 0.02
		p.torso = Vector3(0.03 + b * 0.015, 0.25, 0)
		p.head = Vector3(-0.05, -0.2, 0)
		p.pelvis = Vector3(0, -0.15, 0)
		p.hip_r = Vector3(0.1, 0, 0.05)
		p.hip_l = Vector3(-0.15, 0, -0.08)
		p.kn_r = Vector3(-0.15, 0, 0)
		p.kn_l = Vector3(-0.1, 0, 0)
		if stance == "bow":
			p.sh_l = Vector3(0.3, 0, -0.15)
			p.el_l = Vector3(0.3, 0, 0)
			p.sh_r = Vector3(0.0, 0, 0.12)
			p.el_r = Vector3(0.2, 0, 0)
		else:
			# kamae relaxado: espada baixa à frente
			p.sh_r = Vector3(0.5 + b * 0.02, 0.0, 0.05)
			p.el_r = Vector3(0.55, 0, 0)
			p.sh_l = Vector3(0.55 + b * 0.02, 0.0, 0.45)
			p.el_l = Vector3(0.9, 0, 0)
			p.wpn = Vector3(-0.95, 0, 0)

	if action == "":
		return p
	var t := progress()
	match action:
		"attack1":
			_pose_attack1(p, t)
		"attack2":
			_pose_attack2(p, t)
		"attack3":
			_pose_attack3(p, t)
		"heavy":
			_pose_heavy(p, t)
		"block":
			_pose_block(p)
		"parry":
			_pose_parry(p, t)
		"dodge":
			_pose_dodge(p, t)
		"hurt":
			_pose_hurt(p, t)
		"dead":
			_pose_dead(p, t)
		"special":
			_pose_special(p, t)
		"stunned", "guard_break":
			_pose_stunned(p)
		"aim":
			_pose_aim(p, t)
		"shoot":
			_pose_shoot(p, t)
		"charge":
			_pose_charge(p)
		"cast":
			_pose_cast(p)
		"slam":
			_pose_slam(p, t)
		"kneel":
			_pose_kneel(p)
		"thrust_dash":
			_pose_attack3(p, clampf(t * 1.4, 0.0, 1.0))
		"spin":
			_pose_special(p, t)
		"interact":
			_pose_interact(p, t)
		"victory":
			_pose_victory(p, t)
		"idle_guard":
			pass
	return p


static func _seg(t: float, a: float, b: float) -> float:
	return clampf((t - a) / maxf(b - a, 0.0001), 0.0, 1.0)


static func _ease(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


func _lerp_pose(p: Dictionary, a: Dictionary, b: Dictionary, k: float) -> void:
	var keys := a.keys()
	for key in b.keys():
		if not a.has(key):
			keys.append(key)
	for key in keys:
		var base: Vector3 = p.get(key, Vector3.ZERO)
		var va: Vector3 = a.get(key, base)
		var vb: Vector3 = b.get(key, va)
		p[key] = va.lerp(vb, k)


func _keyframes(p: Dictionary, t: float, frames: Array) -> void:
	## frames: [[tempo, {pose}], ...] — interpola entre quadros-chave.
	for i in range(frames.size() - 1):
		var f0: Array = frames[i]
		var f1: Array = frames[i + 1]
		if t <= f1[0] or i == frames.size() - 2:
			var k := _seg(t, f0[0], f1[0])
			k = _ease(k)
			_lerp_pose(p, f0[1], f1[1], k)
			var l0: float = (f0[1] as Dictionary).get("_lift", Vector3.ZERO).y
			var l1: float = (f1[1] as Dictionary).get("_lift", Vector3.ZERO).y
			lift = lerpf(l0, l1, k)
			p.erase("_lift")
			return


func _pose_attack1(p: Dictionary, t: float) -> void:
	# corte diagonal descendente (kesagiri)
	var wind := {"torso": Vector3(0.05, 0.7, 0.05), "sh_r": Vector3(2.6, 0, -0.25), "el_r": Vector3(0.5, 0, 0), "sh_l": Vector3(2.2, 0, 0.5), "el_l": Vector3(0.9, 0, 0), "wpn": Vector3(0.2, 0, 0), "hip_r": Vector3(-0.2, 0, 0), "hip_l": Vector3(0.3, 0, 0), "kn_l": Vector3(-0.3, 0, 0), "_lift": Vector3(0, -0.05, 0)}
	var strike := {"torso": Vector3(-0.25, -0.6, -0.1), "sh_r": Vector3(0.7, 0, 0.55), "el_r": Vector3(0.1, 0, 0), "sh_l": Vector3(0.6, 0, 0.7), "el_l": Vector3(0.6, 0, 0), "wpn": Vector3(-0.5, 0, 0), "hip_r": Vector3(-0.4, 0, 0), "hip_l": Vector3(0.6, 0, 0), "kn_l": Vector3(-0.6, 0, 0), "kn_r": Vector3(-0.3, 0, 0), "_lift": Vector3(0, -0.12, 0)}
	var rec := {"torso": Vector3(-0.1, -0.3, 0), "sh_r": Vector3(0.6, 0, 0.3), "el_r": Vector3(0.4, 0, 0), "sh_l": Vector3(0.6, 0, 0.5), "el_l": Vector3(0.8, 0, 0), "wpn": Vector3(-0.4, 0, 0), "hip_r": Vector3(-0.2, 0, 0), "hip_l": Vector3(0.3, 0, 0), "kn_l": Vector3(-0.3, 0, 0), "kn_r": Vector3(-0.1, 0, 0), "_lift": Vector3(0, -0.06, 0)}
	_keyframes(p, t, [[0.0, wind], [0.3, wind], [0.5, strike], [1.0, rec]])


func _pose_attack2(p: Dictionary, t: float) -> void:
	# corte horizontal (yokogiri) da direita para a esquerda
	var wind := {"torso": Vector3(0, -1.0, 0), "sh_r": Vector3(1.4, 0, 1.2), "el_r": Vector3(0.3, 0, 0), "sh_l": Vector3(1.0, 0, 0.9), "el_l": Vector3(1.2, 0, 0), "wpn": Vector3(-1.4, 0.6, 0), "hip_r": Vector3(0.3, 0, 0), "hip_l": Vector3(-0.2, 0, 0), "_lift": Vector3(0, -0.08, 0)}
	var strike := {"torso": Vector3(-0.1, 0.9, 0), "sh_r": Vector3(1.4, 0, -0.3), "el_r": Vector3(0.0, 0, 0), "sh_l": Vector3(0.8, 0, -0.2), "el_l": Vector3(0.6, 0, 0), "wpn": Vector3(-1.4, -0.4, 0), "hip_r": Vector3(-0.3, 0, 0), "hip_l": Vector3(0.5, 0, 0), "kn_l": Vector3(-0.5, 0, 0), "_lift": Vector3(0, -0.12, 0)}
	var rec := {"torso": Vector3(0, 0.4, 0), "sh_r": Vector3(0.8, 0, 0.1), "el_r": Vector3(0.4, 0, 0), "sh_l": Vector3(0.7, 0, 0.4), "el_l": Vector3(0.8, 0, 0), "wpn": Vector3(-0.6, 0, 0), "hip_l": Vector3(0.3, 0, 0), "kn_l": Vector3(-0.3, 0, 0), "_lift": Vector3(0, -0.06, 0)}
	_keyframes(p, t, [[0.0, wind], [0.25, wind], [0.48, strike], [1.0, rec]])


func _pose_attack3(p: Dictionary, t: float) -> void:
	# estocada (tsuki)
	var wind := {"torso": Vector3(0.1, 0.5, 0), "sh_r": Vector3(0.1, 0, 0.3), "el_r": Vector3(1.8, 0, 0), "sh_l": Vector3(0.4, 0, 0.6), "el_l": Vector3(1.6, 0, 0), "wpn": Vector3(-1.6, 0, 0), "hip_r": Vector3(0.2, 0, 0), "hip_l": Vector3(-0.3, 0, 0), "kn_r": Vector3(-0.5, 0, 0), "_lift": Vector3(0, -0.12, 0)}
	var strike := {"torso": Vector3(-0.35, -0.15, 0), "sh_r": Vector3(1.55, 0, 0.0), "el_r": Vector3(0.0, 0, 0), "sh_l": Vector3(1.4, 0, 0.35), "el_l": Vector3(0.3, 0, 0), "wpn": Vector3(-1.55, 0, 0), "hip_r": Vector3(-0.5, 0, 0), "hip_l": Vector3(0.9, 0, 0), "kn_l": Vector3(-0.9, 0, 0), "kn_r": Vector3(-0.2, 0, 0), "_lift": Vector3(0, -0.2, 0)}
	var rec := {"torso": Vector3(-0.1, 0.1, 0), "sh_r": Vector3(0.7, 0, 0.1), "el_r": Vector3(0.5, 0, 0), "sh_l": Vector3(0.7, 0, 0.45), "el_l": Vector3(0.8, 0, 0), "wpn": Vector3(-0.5, 0, 0), "hip_l": Vector3(0.3, 0, 0), "kn_l": Vector3(-0.3, 0, 0), "_lift": Vector3(0, -0.05, 0)}
	_keyframes(p, t, [[0.0, wind], [0.3, wind], [0.45, strike], [0.7, strike], [1.0, rec]])


func _pose_heavy(p: Dictionary, t: float) -> void:
	# golpe pesado acima da cabeça (karatake-wari)
	var wind := {"torso": Vector3(0.25, 0.1, 0), "sh_r": Vector3(3.0, 0, 0.1), "el_r": Vector3(0.4, 0, 0), "sh_l": Vector3(3.0, 0, 0.35), "el_l": Vector3(0.5, 0, 0), "wpn": Vector3(0.4, 0, 0), "hip_r": Vector3(-0.3, 0, 0), "hip_l": Vector3(0.2, 0, 0), "kn_l": Vector3(-0.2, 0, 0), "head": Vector3(-0.2, 0, 0), "_lift": Vector3(0, -0.02, 0)}
	var strike := {"torso": Vector3(-0.55, 0, 0), "sh_r": Vector3(0.45, 0, 0.1), "el_r": Vector3(0.0, 0, 0), "sh_l": Vector3(0.5, 0, 0.35), "el_l": Vector3(0.2, 0, 0), "wpn": Vector3(-0.3, 0, 0), "hip_r": Vector3(-0.5, 0, 0), "hip_l": Vector3(1.0, 0, 0), "kn_l": Vector3(-1.1, 0, 0), "kn_r": Vector3(-0.5, 0, 0), "head": Vector3(0.3, 0, 0), "_lift": Vector3(0, -0.28, 0)}
	var rec := {"torso": Vector3(-0.2, 0.1, 0), "sh_r": Vector3(0.6, 0, 0.1), "el_r": Vector3(0.4, 0, 0), "sh_l": Vector3(0.6, 0, 0.45), "el_l": Vector3(0.8, 0, 0), "wpn": Vector3(-0.4, 0, 0), "hip_l": Vector3(0.4, 0, 0), "kn_l": Vector3(-0.4, 0, 0), "_lift": Vector3(0, -0.08, 0)}
	_keyframes(p, t, [[0.0, rec], [0.12, wind], [0.45, wind], [0.58, strike], [0.75, strike], [1.0, rec]])


func _pose_block(p: Dictionary) -> void:
	p.torso = Vector3(0.05, 0.35, 0)
	p.head = Vector3(0.05, -0.3, 0)
	p.sh_r = Vector3(1.25, 0, 0.6)
	p.el_r = Vector3(0.9, 0, 0)
	p.sh_l = Vector3(1.2, 0, 0.2)
	p.el_l = Vector3(1.1, 0, 0)
	p.wpn = Vector3(-1.2, 1.2, 0.0)
	p.hip_r = Vector3(0.35, 0, 0)
	p.hip_l = Vector3(-0.35, 0, 0)
	p.kn_r = Vector3(-0.45, 0, 0)
	p.kn_l = Vector3(-0.3, 0, 0)
	lift = -0.1


func _pose_parry(p: Dictionary, t: float) -> void:
	var a := {"torso": Vector3(0, 0.6, 0), "sh_r": Vector3(1.0, 0, 0.9), "el_r": Vector3(0.9, 0, 0), "sh_l": Vector3(0.9, 0, 0.5), "el_l": Vector3(1.0, 0, 0), "wpn": Vector3(-0.8, 1.0, 0), "_lift": Vector3(0, -0.1, 0)}
	var b := {"torso": Vector3(-0.1, -0.4, 0), "sh_r": Vector3(2.0, 0, -0.3), "el_r": Vector3(0.3, 0, 0), "sh_l": Vector3(0.7, 0, 0.3), "el_l": Vector3(0.8, 0, 0), "wpn": Vector3(-0.5, -0.5, 0), "hip_l": Vector3(0.3, 0, 0), "_lift": Vector3(0, -0.12, 0)}
	var c := {"torso": Vector3(0, 0.2, 0), "sh_r": Vector3(0.6, 0, 0.1), "el_r": Vector3(0.5, 0, 0), "sh_l": Vector3(0.6, 0, 0.45), "el_l": Vector3(0.9, 0, 0), "wpn": Vector3(-0.4, 0, 0), "_lift": Vector3(0, -0.04, 0)}
	_keyframes(p, t, [[0.0, a], [0.35, a], [0.6, b], [1.0, c]])


func _pose_dodge(p: Dictionary, t: float) -> void:
	var tuck := {"torso": Vector3(-0.9, 0, 0), "head": Vector3(-0.3, 0, 0), "hip_r": Vector3(1.4, 0, 0), "hip_l": Vector3(1.1, 0, 0), "kn_r": Vector3(-1.8, 0, 0), "kn_l": Vector3(-1.7, 0, 0), "sh_r": Vector3(0.9, 0, 0.3), "el_r": Vector3(1.4, 0, 0), "sh_l": Vector3(0.8, 0, 0.5), "el_l": Vector3(1.4, 0, 0), "wpn": Vector3(0.6, 0, 0), "_lift": Vector3(0, -0.38, 0)}
	var land := {"torso": Vector3(-0.3, 0, 0), "hip_r": Vector3(0.6, 0, 0), "hip_l": Vector3(-0.2, 0, 0), "kn_r": Vector3(-0.9, 0, 0), "kn_l": Vector3(-0.4, 0, 0), "sh_r": Vector3(0.4, 0, 0.3), "el_r": Vector3(0.6, 0, 0), "sh_l": Vector3(0.3, 0, -0.4), "el_l": Vector3(0.5, 0, 0), "wpn": Vector3(-0.3, 0, 0), "_lift": Vector3(0, -0.22, 0)}
	_keyframes(p, t, [[0.0, land], [0.2, tuck], [0.7, tuck], [1.0, land]])


func _pose_hurt(p: Dictionary, t: float) -> void:
	var k := sin(clampf(t, 0.0, 1.0) * PI)
	p.torso = Vector3(0.45 * k, 0.2 * k, 0.1 * k)
	p.head = Vector3(0.4 * k, 0, 0)
	p.sh_r = Vector3(0.3, 0, 0.6 * k + 0.1)
	p.el_r = Vector3(0.5, 0, 0)
	p.sh_l = Vector3(0.3, 0, -0.6 * k)
	p.el_l = Vector3(0.5, 0, 0)
	p.hip_r = Vector3(-0.3 * k, 0, 0)
	p.hip_l = Vector3(0.3 * k, 0, 0)
	p.kn_l = Vector3(-0.3 * k, 0, 0)
	p.wpn = Vector3(-0.2, 0, 0)
	lift = -0.06 * k


func _pose_dead(p: Dictionary, t: float) -> void:
	var k := _ease(_seg(t, 0.0, 1.0))
	p.root = Vector3(1.48 * k, 0, 0)
	p.torso = Vector3(0.2 * k, 0, 0)
	p.head = Vector3(0.3 * k, 0.4 * k, 0)
	p.sh_r = Vector3(0.4, 0, 1.2 * k)
	p.el_r = Vector3(0.3, 0, 0)
	p.sh_l = Vector3(0.4, 0, -1.1 * k)
	p.el_l = Vector3(0.6, 0, 0)
	p.hip_r = Vector3(0.3 * k, 0, 0.15 * k)
	p.hip_l = Vector3(0.1 * k, 0, -0.1 * k)
	p.kn_r = Vector3(-0.4 * k, 0, 0)
	p.wpn = Vector3(0.0, 0.5 * k, 0)
	lift = -0.75 * k


func _pose_special(p: Dictionary, t: float) -> void:
	# giro completo com lâmina estendida (Corte da Lua Crescente)
	var wind := {"torso": Vector3(0.1, -1.2, 0), "sh_r": Vector3(1.0, 0, 1.4), "el_r": Vector3(0.6, 0, 0), "sh_l": Vector3(1.0, 0, 0.5), "el_l": Vector3(1.0, 0, 0), "wpn": Vector3(-1.2, 1.0, 0), "hip_r": Vector3(0.5, 0, 0), "kn_r": Vector3(-0.8, 0, 0), "hip_l": Vector3(-0.3, 0, 0), "kn_l": Vector3(-0.5, 0, 0), "_lift": Vector3(0, -0.3, 0)}
	var spin := {"torso": Vector3(-0.2, 0.8, 0), "sh_r": Vector3(1.5, 0, 0.1), "el_r": Vector3(0.0, 0, 0), "sh_l": Vector3(0.5, 0, -1.2), "el_l": Vector3(0.2, 0, 0), "wpn": Vector3(-1.5, -0.3, 0), "hip_l": Vector3(0.8, 0, 0), "kn_l": Vector3(-0.8, 0, 0), "hip_r": Vector3(-0.3, 0, 0), "_lift": Vector3(0, -0.25, 0)}
	var fin := {"torso": Vector3(-0.3, 0.3, 0), "sh_r": Vector3(0.4, 0, 0.6), "el_r": Vector3(0.1, 0, 0), "sh_l": Vector3(0.3, 0, -0.3), "el_l": Vector3(0.4, 0, 0), "wpn": Vector3(-0.8, 0, 0), "hip_l": Vector3(0.9, 0, 0), "kn_l": Vector3(-1.0, 0, 0), "hip_r": Vector3(-0.6, 0, 0), "kn_r": Vector3(-0.6, 0, 0), "_lift": Vector3(0, -0.35, 0)}
	_keyframes(p, t, [[0.0, wind], [0.3, wind], [0.55, spin], [0.8, fin], [1.0, fin]])
	var sk := _seg(t, 0.3, 0.75)
	p.root = Vector3(0, -sk * TAU, 0)


func _pose_stunned(p: Dictionary) -> void:
	var sway := sin(_t * 5.0) * 0.1
	p.torso = Vector3(-0.5, sway, 0)
	p.head = Vector3(0.5, sway, 0)
	p.sh_r = Vector3(-0.1, 0, 0.3)
	p.el_r = Vector3(0.2, 0, 0)
	p.sh_l = Vector3(-0.1, 0, -0.3)
	p.el_l = Vector3(0.2, 0, 0)
	p.wpn = Vector3(-1.2, 0, 0)
	p.kn_r = Vector3(-0.5, 0, 0)
	p.kn_l = Vector3(-0.4, 0, 0)
	p.hip_r = Vector3(0.3, 0, 0)
	p.hip_l = Vector3(0.2, 0, 0)
	lift = -0.15


func _pose_aim(p: Dictionary, t: float) -> void:
	var k := _ease(_seg(t, 0.0, 0.6))
	p.torso = Vector3(0, -1.2, 0)
	p.head = Vector3(0, 1.1, 0)
	p.sh_l = Vector3(1.55, 1.2, 0)
	p.el_l = Vector3(0.05, 0, 0)
	p.sh_r = Vector3(1.4, 1.1, 0).lerp(Vector3(1.5, 1.6, 0), k)
	p.el_r = Vector3(0.6, 0, 0).lerp(Vector3(2.2, 0, 0), k)
	p.wpn = Vector3(0.5, 0, 0)
	p.hip_r = Vector3(0.2, 0, 0)
	p.hip_l = Vector3(-0.2, 0, 0)


func _pose_shoot(p: Dictionary, t: float) -> void:
	_pose_aim(p, 1.0)
	var k := _ease(_seg(t, 0.0, 0.3))
	p.sh_r = (p.sh_r as Vector3).lerp(Vector3(1.4, 1.9, 0.4), k)
	p.el_r = (p.el_r as Vector3).lerp(Vector3(0.6, 0, 0), k)


func _pose_charge(p: Dictionary) -> void:
	var sh := sin(_t * 30.0) * 0.02
	p.torso = Vector3(-0.2, -0.8, 0)
	p.sh_r = Vector3(0.6 + sh, 0, 1.0)
	p.el_r = Vector3(0.2, 0, 0)
	p.sh_l = Vector3(1.0, 0, -0.4)
	p.el_l = Vector3(1.0, 0, 0)
	p.wpn = Vector3(-1.0, 1.4, 0)
	p.hip_r = Vector3(-0.5, 0, 0)
	p.hip_l = Vector3(0.8, 0, 0)
	p.kn_l = Vector3(-1.0, 0, 0)
	p.kn_r = Vector3(-0.3, 0, 0)
	lift = -0.3


func _pose_cast(p: Dictionary) -> void:
	var s := sin(_t * 3.0) * 0.05
	p.torso = Vector3(0.25, 0, 0)
	p.head = Vector3(-0.4, 0, 0)
	p.sh_r = Vector3(2.9 + s, 0, 0.2)
	p.el_r = Vector3(0.1, 0, 0)
	p.sh_l = Vector3(2.6 - s, 0, -0.5)
	p.el_l = Vector3(0.2, 0, 0)
	p.wpn = Vector3(0.0, 0, 0)
	lift = 0.0


func _pose_slam(p: Dictionary, t: float) -> void:
	_pose_heavy(p, t)


func _pose_kneel(p: Dictionary) -> void:
	p.torso = Vector3(-0.3, 0, 0)
	p.head = Vector3(0.4, 0, 0)
	p.hip_r = Vector3(1.4, 0, 0)
	p.kn_r = Vector3(-1.5, 0, 0)
	p.hip_l = Vector3(-0.2, 0, 0)
	p.kn_l = Vector3(-1.9, 0, 0)
	p.sh_r = Vector3(0.4, 0, 0.1)
	p.el_r = Vector3(0.3, 0, 0)
	p.sh_l = Vector3(0.2, 0, -0.1)
	p.el_l = Vector3(0.5, 0, 0)
	p.wpn = Vector3(-1.4, 0, 0)
	lift = -0.5


func _pose_interact(p: Dictionary, t: float) -> void:
	var k := sin(clampf(t, 0.0, 1.0) * PI)
	p.torso = Vector3(-0.5 * k, 0, 0)
	p.sh_l = Vector3(1.2 * k, 0, 0)
	p.el_l = Vector3(0.3, 0, 0)
	p.kn_r = Vector3(-0.6 * k, 0, 0)
	p.kn_l = Vector3(-0.6 * k, 0, 0)
	p.hip_r = Vector3(0.5 * k, 0, 0)
	p.hip_l = Vector3(0.5 * k, 0, 0)
	lift = -0.2 * k


func _pose_victory(p: Dictionary, t: float) -> void:
	# embainha a espada e faz reverência
	var k := _ease(_seg(t, 0.0, 0.5))
	p.sh_r = Vector3(2.8, 0, 0.2).lerp(Vector3(0.4, 0, 0.6), k)
	p.el_r = Vector3(0.3, 0, 0).lerp(Vector3(1.4, 0, 0), k)
	p.wpn = Vector3(0.0, 0, 0).lerp(Vector3(-1.2, -0.6, 0), k)
	p.torso = Vector3(-0.35 * _seg(t, 0.6, 1.0), 0, 0)
	p.head = Vector3(0.3 * _seg(t, 0.6, 1.0), 0, 0)
	p.sh_l = Vector3(0.2, 0, -0.1)
	p.el_l = Vector3(0.4, 0, 0)


func _update_cloth(delta: float) -> void:
	if cloth.is_empty() or not is_inside_tree():
		return
	var gp := global_position
	if _last_pos != Vector3.INF and delta > 0.0:
		_vel = _vel.lerp((gp - _last_pos) / delta, clampf(delta * 6.0, 0, 1))
	_last_pos = gp
	var local := global_transform.basis.inverse() * _vel
	var spd := Vector2(local.x, local.z).length()
	var spin := 1.0 if action in ["special", "spin", "dodge"] else 0.0
	for c in cloth:
		var n: Node3D = c[0]
		if not is_instance_valid(n):
			continue
		var rest: Vector3 = c[1]
		var amp: float = c[2]
		var ph: float = c[3]
		var flutter := sin(_t * (5.0 + spd) + ph) * 0.06 * amp * (0.4 + spd * 0.3 + spin)
		var tx := rest.x + clampf(local.z * 0.09, -0.9, 0.5) * amp + flutter - spin * 0.6
		var tz := rest.z + clampf(-local.x * 0.06, -0.5, 0.5) * amp + flutter * 0.5
		n.rotation.x = lerpf(n.rotation.x, tx, clampf(delta * 8.0, 0, 1))
		n.rotation.z = lerpf(n.rotation.z, tz, clampf(delta * 8.0, 0, 1))
