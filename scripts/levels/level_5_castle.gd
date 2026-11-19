extends LevelBase
## FASE 5 — O Último Duelo (chefe final, ~10–14 min)
## Shin invade o castelo, vence os guardas do pátio e enfrenta Lorde Akuma,
## o guerreiro da Lua Sangrenta, em duas etapas de combate. Ao vencer, a paz retorna.

const ARENA := Vector3(0, 0, -125)
var gate: Dictionary = {}
var akuma: Boss
var akuma_dead := false
var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D


func _init() -> void:
	ambience = "amb_castle"
	ambient_fx = "ash"
	music_explore = "music_explore"


func _build_world() -> void:
	sun = Props.environment(self, {
		"sky_top": Color(0.08, 0.01, 0.03), "sky_horizon": Color(0.45, 0.06, 0.08), "sky_bottom": Color(0.1, 0.02, 0.03),
		"moon_dir": Vector3(0.0, 0.42, -1.0), "moon_color": Color(1.0, 0.12, 0.08), "moon_size": 0.16, "moon_glow": 1.6,
		"stars": 0.3, "clouds": 0.45,
		"fog_color": Color(0.32, 0.06, 0.08), "fog_density": 0.018, "fog_sky": 0.15,
		"ambient": Color(0.55, 0.3, 0.35), "ambient_energy": 0.6, "sun_color": Color(1.0, 0.35, 0.3), "sun_energy": 0.9,
		"sun_rot": Vector3(-30, 180, 0), "exposure": 1.05,
	})
	for c in get_children():
		if c is WorldEnvironment:
			env = (c as WorldEnvironment).environment
			sky_mat = env.sky.sky_material as ShaderMaterial
	ground_plane(Vector2(120, 260), Vector3(0, 0, -70), Color(0.2, 0.18, 0.18))
	var stone_c := Color(0.36, 0.34, 0.33)
	# muralhas externas e do pátio
	Props.stone_wall(self, Vector3(-26, 0, 30), Vector3(-4, 0, 30), 5.0, 2.0, stone_c)
	Props.stone_wall(self, Vector3(4, 0, 30), Vector3(26, 0, 30), 5.0, 2.0, stone_c)
	Props.stone_wall(self, Vector3(-26, 0, 30), Vector3(-26, 0, -40), 5.0, 2.0, stone_c)
	Props.stone_wall(self, Vector3(26, 0, 30), Vector3(26, 0, -40), 5.0, 2.0, stone_c)
	Props.stone_wall(self, Vector3(-26, 0, -40), Vector3(-4.2, 0, -40), 5.0, 2.0, stone_c)
	Props.stone_wall(self, Vector3(4.2, 0, -40), Vector3(26, 0, -40), 5.0, 2.0, stone_c)
	gate = Props.gate(self, Vector3(0, 0, -40), 0.0, 6.5, Color(0.2, 0.08, 0.06))
	# caminho de entrada
	path_strip([Vector3(0, 0, 48), Vector3(0, 0, -40)], 6.0, Color(0.42, 0.4, 0.38))
	Props.wall(self, Vector3(1, 10, 22), Vector3(-6, 5, 41))
	Props.wall(self, Vector3(1, 10, 22), Vector3(6, 5, 41))
	Props.wall(self, Vector3(14, 10, 1), Vector3(0, 5, 52))
	Props.torii(self, Vector3(0, 0, 36), 0.0, 1.0, Color(0.15, 0.05, 0.05))
	# passarelas elevadas com escadas (arqueiros)
	var wood := Props.mat(Color(0.25, 0.15, 0.1))
	for sx in [-1.0, 1.0]:
		Props.solid_box(self, Vector3(5.0, 0.4, 30.0), Vector3(sx * 22.5, 3.0, -5), wood)
		Props.stairs(self, Vector3(sx * 18.4, 0, 14), 0.0, 2.0, 10, 0.3, 0.6, wood)
		for z in [-18.0, -5.0, 8.0]:
			Props.mesh(self, Props.box_mesh(Vector3(0.3, 3.0, 0.3)), Vector3(sx * 20.2, 1.5, z), wood)
		Props.wall(self, Vector3(0.3, 1.2, 30), Vector3(sx * 20.1, 3.8, -5))
	# decoração do pátio
	for i in 8:
		Props.stone_lantern(self, Vector3((-1 if i % 2 == 0 else 1) * 8.0, 0, 24 - i * 8), true, i % 3 == 0)
	for i in 6:
		Props.banner(self, Vector3((-1 if i % 2 == 0 else 1) * 12.0, 0, 18 - i * 10), Color(0.08, 0.02, 0.03) if i % 2 == 0 else Color(0.6, 0.04, 0.06), PI / 2 if i % 2 == 0 else -PI / 2)
	for i in 10:
		var p := Vector3(rnd.randf_range(-20, 20), 0, rnd.randf_range(-36, 26))
		if absf(p.x) > 5:
			if rnd.randf() < 0.5:
				Props.crate(self, p, 1.0, rnd.randf() * TAU)
			else:
				Props.barrel(self, p)
	Props.cherry_tree(self, Vector3(-14, 0, -30), rnd, 1.1, Color(0.7, 0.2, 0.3))
	Props.cherry_tree(self, Vector3(14, 0, -30), rnd, 1.1, Color(0.7, 0.2, 0.3))
	# pátio interno
	path_strip([Vector3(0, 0, -40), Vector3(0, 0, -108)], 6.0, Color(0.42, 0.4, 0.38))
	for z in range(-46, -106, -10):
		for sx in [-1.0, 1.0]:
			Props.hanging_lantern(self, Vector3(sx * 4.5, 3.0, z), Color(1.0, 0.25, 0.15), z % 20 == 6)
			Props.mesh(self, Props.box_mesh(Vector3(0.2, 3.4, 0.2)), Vector3(sx * 4.5, 1.7, z), wood)
	Props.wall(self, Vector3(1, 10, 66), Vector3(-9, 5, -73))
	Props.wall(self, Vector3(1, 10, 66), Vector3(9, 5, -73))
	for z in range(-44, -106, -8):
		for sx in [-1.0, 1.0]:
			Props.batch_add("hedge", Props.box_mesh(Vector3(1.6, 1.6, 7.6)), Props.mat(Color(0.1, 0.12, 0.08)), Props.xf(Vector3(sx * 10.0, 0.8, z)))
	# arena do duelo
	Props.mesh(self, Props.cyl_mesh(19.0, 19.5, 0.6, 40), ARENA + Vector3(0, 0.3, 0), Props.mat(Color(0.3, 0.28, 0.28), 1.0))
	Props.mesh(self, Props.cyl_mesh(6.0, 6.0, 0.05, 32), ARENA + Vector3(0, 0.62, 0), Props.mat(Color(0.45, 0.06, 0.08), 0.9))
	var floor_b := Props.body(self, ARENA + Vector3(0, 0.3, 0))
	Props.add_cyl_shape(floor_b, 19.5, 0.6)
	Props.ramp(self, ARENA + Vector3(0, 0, 21.5), ARENA + Vector3(0, 0.6, 19.0), 6.0, Props.mat(Color(0.3, 0.28, 0.28), 1.0))
	var n := 28
	for i in n:
		var a := float(i) / n * TAU
		var dir := Vector3(cos(a), 0, sin(a))
		if dir.z > 0.95:
			continue
		Props.solid_box(self, Vector3(1.0, 1.4, 4.4), ARENA + dir * 19.8 + Vector3(0, 1.3, 0), Props.mat(Color(0.25, 0.23, 0.23), 1.0), Vector3(0, atan2(dir.x, dir.z) + PI / 2, 0))
		Props.wall(self, Vector3(1.0, 10, 4.6), ARENA + dir * 19.8 + Vector3(0, 5, 0), Vector3(0, atan2(dir.x, dir.z) + PI / 2, 0))
		if i % 4 == 0:
			Props.stone_lantern(self, ARENA + dir * 17.5 + Vector3(0, 0.6, 0), true, i % 8 == 0)
	for sx in [-1.0, 1.0]:
		seg_wall(Vector3(sx * 9, 0, -106), Vector3(sx * 5.5, 0, -106))
		seg_wall(Vector3(sx * 5.5, 0, -106), Vector3(sx * 5.5, 0, -110))
	# castelo
	Props.castle_keep(self, Vector3(0, 0, -178), 0.0, 1.3)
	Props.stone_wall(self, Vector3(-60, 0, -150), Vector3(60, 0, -150), 7.0, 3.0, stone_c)
	for i in 10:
		var a := rnd.randf_range(-PI, 0)
		Props.mountain(self, Vector3(cos(a) * rnd.randf_range(150, 220), 0, -100 + sin(a) * rnd.randf_range(170, 240)), rnd.randf_range(50, 80), rnd.randf_range(60, 110), Color(0.16, 0.06, 0.08))
	for i in 20:
		Props.pine_tree(self, Vector3((-1 if i % 2 == 0 else 1) * rnd.randf_range(30, 55), 0, rnd.randf_range(-140, 40)), rnd, 1.2, Color(0.1, 0.08, 0.08))
	shrine(Vector3(5, 0, -48), 2)
	shrine(Vector3(5.5, 0, -100), 3)


func _spawn_point(i: int) -> Array:
	if i >= 3:
		return [Vector3(0, 0.1, -100), 0.0]
	if i >= 2:
		return [Vector3(0, 0.1, -46), 0.0]
	return [Vector3(0, 0.1, 44), 0.0]


func _begin_stage(i: int) -> void:
	match i:
		0:
			say([
				["Shin", "O castelo de Akuma. A Lua Sangrenta está quase completa."],
				["Shin", "Mestre Hideo, ancião Genzo, todos da aldeia... Esta noite, a lâmina Kurogane encerra esta guerra."],
			], func(): started("Invada o pátio do castelo.", Vector3(0, 0, 22)))
		1:
			spawn("elite", Vector3(-5, 0, 2), 0.0, [Vector3(-6, 0, 6), Vector3(6, 0, -2)])
			spawn("elite", Vector3(6, 0, -12), PI, [Vector3(6, 0, -16), Vector3(-6, 0, -8)])
			spawn("soldier", Vector3(0, 0, -24), 0.0)
			var a1 := spawn("archer", Vector3(-22.5, 3.3, -8), PI / 2)
			a1.stationary = true
			var a2 := spawn("archer", Vector3(22.5, 3.3, 0), -PI / 2)
			a2.stationary = true
			started("Derrote os guardas do pátio (5).", null)
			hint("Arqueiros nas passarelas: suba pelas escadas laterais para alcançá-los.")
		2:
			checkpoint(2)
			Props.open_gate(gate)
			started("Avance até a arena diante da torre.", Vector3(0, 0, -104))
		3:
			checkpoint(3)
			akuma = spawn_boss("akuma", ARENA + Vector3(0, 0.6, -8), 0.0)
			akuma.died.connect(func(_e): akuma_dead = true)
			akuma.phase_changed.connect(_on_akuma_phase)
			if hud:
				hud.set_boss(akuma)
			Sfx.play("gong", 0.0, 0.0)
			Sfx.stop_music(1.5)
			player.cinematic(ARENA + Vector3(-6, 3.0, 4), akuma.global_position + Vector3(0, 2.0, 0), 2.5, 1.5)
			say([
				["Lorde Akuma", "Shin Kurogane. Eu esperava você. A Tsukikage canta na sua mão... posso ouvi-la daqui."],
				["Lorde Akuma", "Seu mestre também se ajoelhou diante desta lua. Ele implorou pela aldeia."],
				["Shin", "Mentira. Mestre Hideo nunca se ajoelhou para ninguém."],
				["Lorde Akuma", "Então lute como ele lutou... e caia como ele caiu!"],
			], func():
				akuma.activate()
				Sfx.play_music("music_boss", 0.5)
				started("Derrote Lorde Akuma.", null)
				hint("Apare os combos de Akuma para atordoá-lo. Esquive das investidas e defenda as ondas de sangue."))
		4:
			started("", null)


func _on_akuma_phase(_ph: int) -> void:
	say([
		["Lorde Akuma", "Basta! Lua Sangrenta, conceda-me seu poder!"],
		["Shin", "(A aura dele... está mais forte. Os pilares vermelhos surgem onde estou — preciso continuar em movimento!)"],
	])
	if env:
		var tw := create_tween()
		tw.tween_property(env, "fog_light_color", Color(0.5, 0.04, 0.05), 2.0)
	if sky_mat:
		sky_mat.set_shader_parameter("moon_glow", 2.4)
		sky_mat.set_shader_parameter("moon_size", 0.2)
	hint("Segunda etapa! Akuma agora se teleporta para as suas costas e invoca pilares (círculos vermelhos). Continue em movimento!")


func _check_stage(i: int) -> bool:
	match i:
		0:
			return near(Vector3(0, 0, 22), 5.0)
		1:
			return alive_count() == 0
		2:
			return near(Vector3(0, 0, -104), 4.0)
		3:
			return akuma_dead
		4:
			return false
	return false


func _end_stage(i: int) -> void:
	match i:
		3:
			if hud:
				hud.set_boss(null)
			Sfx.stop_music(2.0)
			_dawn()
			player.controls_locked = true
			player.cinematic(akuma.global_position + Vector3(3.5, 2.0, 4.0), akuma.global_position + Vector3(0, 1.2, 0), 3.0, 2.0)
			say([
				["Lorde Akuma", "A lua... está se apagando... Como um único samurai..."],
				["Shin", "Você lutou pelo poder. Eu lutei por todos que você tirou de mim."],
				["Lorde Akuma", "Então... a lenda do Samurai das Sombras... é real..."],
				["Shin", "Descanse, Akuma. A noite acabou."],
			], func():
				player.model.play("victory", 2.5)
				Sfx.play_music("music_victory", 1.0)
				await get_tree().create_timer(3.0).timeout
				say([
					["Ancião Genzo", "(dias depois) A aldeia está sendo reconstruída, Shin. As crianças já contam a sua história."],
					["Shin", "Que contem. Mas que lembrem também do mestre Hideo... e de todos que caíram."],
				], func():
					player.controls_locked = false
					complete_level()))


func _dawn() -> void:
	## A Lua Sangrenta se apaga e o amanhecer chega.
	if sky_mat:
		var tw := create_tween().set_parallel(true)
		tw.tween_method(func(c): sky_mat.set_shader_parameter("top_color", c), Color(0.08, 0.01, 0.03), Color(0.3, 0.45, 0.7), 5.0)
		tw.tween_method(func(c): sky_mat.set_shader_parameter("horizon_color", c), Color(0.45, 0.06, 0.08), Color(1.0, 0.75, 0.55), 5.0)
		tw.tween_method(func(c): sky_mat.set_shader_parameter("moon_color", c), Color(1.0, 0.12, 0.08), Color(1.0, 0.95, 0.85), 5.0)
		tw.tween_method(func(v): sky_mat.set_shader_parameter("moon_size", v), 0.2, 0.05, 5.0)
	if env:
		var tw2 := create_tween().set_parallel(true)
		tw2.tween_property(env, "fog_light_color", Color(0.75, 0.65, 0.6), 5.0)
		tw2.tween_property(env, "ambient_light_color", Color(0.75, 0.7, 0.65), 5.0)
	if sun:
		var tw3 := create_tween()
		tw3.tween_property(sun, "light_color", Color(1.0, 0.85, 0.65), 5.0)
	if is_instance_valid(_ambient_node):
		_ambient_node.emitting = false
