extends LevelBase
## FASE 4 — O Caminho da Lua Vermelha (desafio, ~8–12 min)
## Trilha montanhosa entre cerejeiras: ondas de guerreiros e arqueiros numa
## arena de pedra e o duelo contra o miniboss General Raiga.

const ARENA := Vector3(0, 0, -120)
const BOSS_ARENA := Vector3(0, 0, -205)
var bar_in: Node
var bar_out: Node
var bar_boss: Node
var raiga: Boss
var raiga_dead := false
var _wave_started := false


func _init() -> void:
	ambience = "amb_mountain"
	ambient_fx = "petals"


func px(z: float) -> float:
	if z < -95.0:
		return 0.0
	return sin(z * 0.05) * 8.0


func _build_world() -> void:
	Props.environment(self, {
		"sky_top": Color(0.16, 0.22, 0.48), "sky_horizon": Color(1.0, 0.55, 0.42), "sky_bottom": Color(0.2, 0.1, 0.1),
		"moon_dir": Vector3(0.2, 0.3, -1.0), "moon_color": Color(1.0, 0.3, 0.22), "moon_size": 0.1, "moon_glow": 1.4,
		"stars": 0.3, "clouds": 0.6, "cloud_light": Color(1.0, 0.72, 0.62), "cloud_shadow": Color(0.42, 0.3, 0.45),
		"fog_color": Color(0.6, 0.5, 0.55), "fog_density": 0.006, "fog_sky": 0.2,
		"ambient": Color(0.5, 0.5, 0.6), "ambient_energy": 0.6, "sun_color": Color(1.0, 0.75, 0.6), "sun_energy": 1.05,
		"sun_rot": Vector3(-24, 175, 0), "exposure": 0.95,
		"grade": {"lift": Vector3(0.0, 0.0, 0.02), "gain": Vector3(1.02, 1.0, 0.98), "saturation": 1.05, "contrast": 1.1, "bloom": 0.32, "threshold": 0.66},
	})
	var t := make_terrain(Vector2(200, 330), Vector3(0, 0, -115), {"grass_a": Color(0.12, 0.24, 0.08), "grass_b": Color(0.34, 0.46, 0.14), "dirt": Color(0.38, 0.28, 0.2)})
	var tz := 14.0
	while tz > -96.0:
		t.segs.append([Vector3(px(tz), 0, tz), Vector3(px(tz - 6.0), 0, tz - 6.0), 10.5])
		t.paths.append([Vector3(px(tz), 0, tz), Vector3(px(tz - 6.0), 0, tz - 6.0), 2.0])
		tz -= 6.0
	t.circles.append([ARENA, 20.0])
	t.circles.append([BOSS_ARENA, 19.0])
	t.segs.append([Vector3(0, 0, -100), Vector3(0, 0, -190), 7.5])
	t.segs.append([Vector3(0, 0, -215), Vector3(0, 0, -256), 7.0])
	t.paths.append([Vector3(0, 0, -138), Vector3(0, 0, -188), 2.0])
	t.paths.append([Vector3(0, 0, -222), Vector3(0, 0, -255), 2.0])
	t.rise = 12.0
	t.hill = 26.0
	t.ramp = 16.0
	t.rivers.append([Vector3(-70, 0, 30), Vector3(-40, 0, -280), 2.6])
	t.build(self)
	t.build_rivers(self)
	t.scatter_grass(self, 18000, Color(0.08, 0.16, 0.05), Color(0.4, 0.52, 0.16), [Color(0.95, 0.12, 0.08), Color(1.0, 0.45, 0.15), Color(0.95, 0.75, 0.85), Color(1, 1, 0.95)], 0.28, 35.0)
	Nature.mountain_range(self, Vector3(0, 0, -115), 230.0, 400.0, 210.0, [Color(0.16, 0.3, 0.16), Color(0.5, 0.48, 0.5), Color(1.0, 0.96, 0.96)], 23)
	for i in 80:
		var cz := rnd.randf_range(-260, 20)
		var side := -1.0 if rnd.randf() < 0.5 else 1.0
		var cx := px(cz) + side * rnd.randf_range(22.0, 70.0)
		var kind := rnd.randf()
		if kind < 0.35:
			Nature.big_tree(self, Vector3(cx, 0, cz), rnd, rnd.randf_range(1.0, 1.5), "maple", false)
		elif kind < 0.6:
			Nature.big_tree(self, Vector3(cx, 0, cz), rnd, rnd.randf_range(1.0, 1.5), "cherry", false)
		else:
			Nature.pine(self, Vector3(cx, 0, cz), rnd, rnd.randf_range(1.0, 1.5), "deep", false)
	# trilha
	var pts := []
	var z := 8.0
	while z > -250:
		pts.append(Vector3(px(z), 0, z))
		z -= 6.0
	path_strip(pts, 4.0, Color(0.42, 0.34, 0.3))
	# encostas: rochas formam paredes naturais ao longo da trilha
	z = 8.0
	while z > -96.0:
		for side in [-1.0, 1.0]:
			Props.rock(self, Vector3(px(z) + side * rnd.randf_range(9.5, 12.0), 0.5, z + rnd.randf_range(-1, 1)), Vector3(rnd.randf_range(2.2, 3.5), rnd.randf_range(2.0, 4.0), rnd.randf_range(2.2, 3.5)), rnd, Color(0.3, 0.26, 0.26))
			if rnd.randf() < 0.65:
				Props.cherry_tree(self, Vector3(px(z) + side * rnd.randf_range(5.0, 8.0), 0, z), rnd, rnd.randf_range(0.8, 1.2))
			if rnd.randf() < 0.6:
				Props.grass_patch(Vector3(px(z) + side * rnd.randf_range(2.5, 7.0), 0, z), rnd, Color(0.4, 0.35, 0.2), 5)
		z -= 4.0
	z = 8.0
	while z > -96.0:
		var z2 := z - 6.0
		for side in [-1.0, 1.0]:
			var a := Vector3(px(z) + side * 9.5, 0, z)
			var b := Vector3(px(z2) + side * 9.5, 0, z2)
			var d := b - a
			Props.wall(self, Vector3(1, 10, d.length() + 0.5), (a + b) * 0.5 + Vector3(0, 5, 0), Vector3(0, atan2(d.x, d.z), 0))
		z = z2
	Props.wall(self, Vector3(30, 10, 1), Vector3(px(8), 5, 10))
	# arena de ondas
	_arena(ARENA, 17.0, Color(0.35, 0.32, 0.32))
	bar_out = Props.barrier(self, ARENA + Vector3(0, 0, -17.5), 12.0)
	for sx in [-1.0, 1.0]:
		seg_wall(Vector3(sx * 9.5, 0, -95), Vector3(sx * 5.2, 0, -103.5))
		seg_wall(Vector3(sx * 5.2, 0, -136.5), Vector3(sx * 6.5, 0, -139))
		seg_wall(Vector3(sx * 6.5, 0, -187), Vector3(sx * 4.6, 0, -190.5))
		seg_wall(Vector3(sx * 4.6, 0, -219.5), Vector3(sx * 6.0, 0, -222))
	# corredor entre arenas
	for zz in range(-140, -186, -4):
		for side in [-1.0, 1.0]:
			Props.rock(self, Vector3(side * rnd.randf_range(6.5, 8.0), 0.5, zz), Vector3(2.5, rnd.randf_range(2.5, 4.0), 2.5), rnd, Color(0.3, 0.26, 0.26))
			if rnd.randf() < 0.5:
				Props.cherry_tree(self, Vector3(side * rnd.randf_range(3.5, 5.0), 0, zz + 2), rnd, 0.8)
	Props.wall(self, Vector3(1, 10, 50), Vector3(-6.5, 5, -163))
	Props.wall(self, Vector3(1, 10, 50), Vector3(6.5, 5, -163))
	# arena do miniboss
	_arena(BOSS_ARENA, 16.0, Color(0.3, 0.28, 0.3))
	Props.torii(self, BOSS_ARENA + Vector3(0, 0, 16.5), 0.0, 1.2, Color(0.75, 0.1, 0.08))
	Props.torii(self, BOSS_ARENA + Vector3(0, 0, -16.5), 0.0, 1.2, Color(0.75, 0.1, 0.08))
	bar_boss = Props.barrier(self, BOSS_ARENA + Vector3(0, 0, -16.5), 11.0)
	for i in 8:
		var a := float(i) / 8.0 * TAU + 0.2
		Props.banner(self, BOSS_ARENA + Vector3(cos(a) * 14.5, 0, sin(a) * 14.5), Color(0.1, 0.14, 0.35) if i % 2 == 0 else Color(0.85, 0.65, 0.2), -a)
	# saída para o castelo
	for zz in range(-224, -252, -4):
		for side in [-1.0, 1.0]:
			Props.rock(self, Vector3(side * rnd.randf_range(6.0, 8.0), 0.5, zz), Vector3(2.5, 3.0, 2.5), rnd, Color(0.3, 0.26, 0.26))
	Props.wall(self, Vector3(1, 10, 34), Vector3(-6.0, 5, -238))
	Props.wall(self, Vector3(1, 10, 34), Vector3(6.0, 5, -238))
	Props.wall(self, Vector3(14, 10, 1), Vector3(0, 5, -255))
	# montanhas e castelo ao longe
	Props.castle_keep(self, Vector3(25, 0, -420), 0.3, 1.4)
	shrine(Vector3(px(-98) + 4, 0, -98), 2)
	shrine(Vector3(4, 0, -148), 6)


func _arena(c: Vector3, r: float, col: Color) -> void:
	Props.mesh(self, Props.cyl_mesh(r, r, 0.1, 32), c + Vector3(0, 0.03, 0), Props.mat(col, 1.0))
	Props.mesh(self, Props.cyl_mesh(r * 0.3, r * 0.3, 0.12, 24), c + Vector3(0, 0.04, 0), Props.mat(col.darkened(0.2), 1.0))
	var n := 22
	for i in n:
		var a := float(i) / n * TAU
		var dir := Vector3(cos(a), 0, sin(a))
		if absf(dir.z) > 0.93:
			continue  # aberturas norte/sul
		Props.rock(self, c + dir * (r + 1.5) + Vector3(0, 0.6, 0), Vector3(2.4, rnd.randf_range(3.0, 5.0), 2.4), rnd, Color(0.28, 0.24, 0.25))
		var b := Props.body(self, c + dir * (r + 1.2))
		Props.add_box_shape(b, Vector3(1.0, 8.0, 5.2), Vector3(0, 4, 0))
		b.rotation.y = atan2(dir.x, dir.z) + PI / 2
	for i in 6:
		var a := float(i) / 6.0 * TAU + 0.5
		Props.stone_lantern(self, c + Vector3(cos(a), 0, sin(a)) * (r - 1.5), true, i % 2 == 0)


func _spawn_point(i: int) -> Array:
	if i >= 6:
		return [Vector3(0, 0.1, -146), 0.0]
	if i >= 2:
		return [Vector3(px(-98), 0.1, -97), 0.0]
	return [Vector3(px(4), 0.1, 4), 0.0]


func _begin_stage(i: int) -> void:
	match i:
		0:
			say([
				["Shin", "A lua está ficando vermelha... Akuma está reunindo seu poder."],
				["Shin", "O castelo fica além destas montanhas. Tsukikage, guie a minha lâmina."],
			], func(): started("Suba a trilha das cerejeiras.", Vector3(px(-30), 0, -30)))
		1:
			spawn("soldier", Vector3(px(-48) - 2, 0, -48), 0.0, [Vector3(px(-44) - 3, 0, -44), Vector3(px(-52) + 3, 0, -52)])
			spawn("soldier", Vector3(px(-52) + 2, 0, -52), 0.0)
			spawn("archer", Vector3(px(-62), 0, -62), 0.0)
			started("Elimine os batedores na trilha (3).", null)
		2:
			checkpoint(2)
			started("Siga até a arena de pedra.", ARENA + Vector3(0, 0, 4))
		3:
			bar_in = Props.barrier(self, ARENA + Vector3(0, 0, 17.5), 12.0)
			say([["Voz", "Você não passará deste círculo, samurai. Homens — ataquem em ondas!"]], func():
				for k in 4:
					var a := float(k) / 4.0 * TAU + 0.4
					spawn("soldier", ARENA + Vector3(cos(a), 0, sin(a)) * 10.0, 0.0, [], true)
				started("Arena — Onda 1 de 3: derrote os guerreiros (4).", null))
		4:
			spawn("soldier", ARENA + Vector3(-9, 0, -6), 0.0, [], true)
			spawn("soldier", ARENA + Vector3(9, 0, -6), 0.0, [], true)
			spawn("archer", ARENA + Vector3(-12, 0, -11), 0.0, [], true)
			spawn("archer", ARENA + Vector3(12, 0, -11), 0.0, [], true)
			started("Arena — Onda 2 de 3: guerreiros e arqueiros (4).", null)
			hint("Priorize os arqueiros — eles atacam de longe.")
		5:
			spawn("elite", ARENA + Vector3(-6, 0, -10), 0.0, [], true)
			spawn("elite", ARENA + Vector3(6, 0, -10), 0.0, [], true)
			spawn("archer", ARENA + Vector3(0, 0, -14), 0.0, [], true)
			started("Arena — Onda 3 de 3: samurais de elite (3).", null)
			hint("Use o Corte da Lua (Ki cheio) quando estiver cercado.")
		6:
			checkpoint(6)
			Props.remove_barrier(bar_out)
			Props.remove_barrier(bar_in)
			started("Siga até o círculo dos torii.", BOSS_ARENA + Vector3(0, 0, 12))
		7:
			raiga = spawn_boss("raiga", BOSS_ARENA + Vector3(0, 0, -6), 0.0)
			raiga.died.connect(func(_e): raiga_dead = true)
			raiga.phase_changed.connect(func(_ph):
				hint("General Raiga está furioso! Ele ficou mais rápido — atenção ao golpe sísmico (círculo vermelho)."))
			if hud:
				hud.set_boss(raiga)
			Sfx.play("gong", 0.0, 0.0)
			player.cinematic(BOSS_ARENA + Vector3(5, 3.5, 2), raiga.global_position + Vector3(0, 1.8, 0), 2.0, 1.5)
			say([
				["General Raiga", "Então você é o samurai que derrotou Kuroha. Ele era fraco. Eu sou o trovão."],
				["General Raiga", "Lorde Akuma me ordenou recuperar a Tsukikage. Entregue-a e talvez eu lhe dê uma morte rápida."],
				["Shin", "A lâmina escolheu seu portador. Se a quer, terá de tomá-la."],
			], func():
				raiga.activate()
				Sfx.play_music("music_boss", 1.0)
				started("Derrote o General Raiga.", null)
				hint("Investida: esquive para o lado. Golpe sísmico: saia do círculo vermelho ou esquive no momento do impacto. Apare seus combos para atordoá-lo!"))
		8:
			started("Siga em direção ao castelo de Akuma.", Vector3(0, 0, -246))


func _check_stage(i: int) -> bool:
	match i:
		0:
			return near(Vector3(px(-30), 0, -30), 5.0)
		1, 3, 4, 5:
			return alive_count() == 0
		2:
			return near(ARENA + Vector3(0, 0, 4), 5.0)
		6:
			return near(BOSS_ARENA + Vector3(0, 0, 12), 4.0)
		7:
			return raiga_dead
		8:
			return near(Vector3(0, 0, -246), 4.0)
	return false


func _end_stage(i: int) -> void:
	match i:
		7:
			if hud:
				hud.set_boss(null)
			Props.remove_barrier(bar_boss)
			say([
				["General Raiga", "Impossível... a lua... ainda... não está completa..."],
				["Shin", "Quando estiver, Akuma estará diante da minha lâmina."],
			])
		8:
			complete_level()


func _skip_stage(i: int) -> void:
	match i:
		5:
			Props.remove_barrier(bar_out)
		7:
			Props.remove_barrier(bar_boss)


func _level_process(_delta: float) -> void:
	# impede o jogador de sair da arena de ondas enquanto lutam
	pass
