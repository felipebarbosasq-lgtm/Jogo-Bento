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
		"sky_top": Color(0.14, 0.05, 0.12), "sky_horizon": Color(0.75, 0.3, 0.32), "sky_bottom": Color(0.2, 0.08, 0.1),
		"moon_dir": Vector3(0.2, 0.32, -1.0), "moon_color": Color(1.0, 0.25, 0.2), "moon_size": 0.11, "moon_glow": 1.2,
		"stars": 0.4, "clouds": 0.35,
		"fog_color": Color(0.5, 0.25, 0.3), "fog_density": 0.016, "fog_sky": 0.25,
		"ambient": Color(0.6, 0.45, 0.5), "ambient_energy": 0.6, "sun_color": Color(1.0, 0.55, 0.5), "sun_energy": 0.9,
		"sun_rot": Vector3(-25, 175, 0), "exposure": 1.0, "saturation": 1.1,
	})
	ground_plane(Vector2(140, 300), Vector3(0, 0, -110), Color(0.26, 0.2, 0.18))
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
	for i in 14:
		var a := rnd.randf_range(-PI, 0)
		Props.mountain(self, Vector3(cos(a) * rnd.randf_range(130, 200), 0, -110 + sin(a) * rnd.randf_range(150, 230)), rnd.randf_range(40, 80), rnd.randf_range(50, 110), Color(0.22, 0.12, 0.16), rnd.randf() < 0.5)
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
