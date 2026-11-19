extends LevelBase
## FASE 2 — A Aldeia Esquecida (combate, ~8–12 min)
## Shin explora a aldeia destruída, enfrenta patrulhas, sobrevive a uma
## emboscada e resgata o ancião Genzo, que revela onde está a espada.

var gate: Dictionary = {}
var house_clue: WorldObjects.Interactable
var cage_item: WorldObjects.Interactable
var cage_bars: Node3D
var elder: CharacterModel
var clue_found := false
var elder_freed := false
const CAGE_POS := Vector3(-24, 0, -36)


func _init() -> void:
	ambience = "amb_village"
	ambient_fx = "embers"


func _build_world() -> void:
	Props.environment(self, {
		"sky_top": Color(0.18, 0.12, 0.22), "sky_horizon": Color(0.85, 0.42, 0.22), "sky_bottom": Color(0.2, 0.1, 0.08),
		"moon_dir": Vector3(0.6, 0.12, -1.0), "moon_color": Color(1.0, 0.55, 0.3), "moon_size": 0.06, "moon_glow": 0.9,
		"fog_color": Color(0.45, 0.28, 0.22), "fog_density": 0.022, "fog_sky": 0.3,
		"ambient": Color(0.55, 0.4, 0.38), "ambient_energy": 0.55, "sun_color": Color(1.0, 0.6, 0.35), "sun_energy": 1.0,
		"sun_rot": Vector3(-18, -125, 0), "clouds": 0.5, "exposure": 0.95,
	})
	ground_plane(Vector2(130, 150), Vector3(0, 0, -5), Color(0.24, 0.2, 0.15))
	bounds(Vector2(-48, -66), Vector2(48, 52))
	# ruas de terra
	path_strip([Vector3(0, 0, 50), Vector3(0, 0, 10), Vector3(0, 0, -10), Vector3(0, 0, -60)], 6.0, Color(0.34, 0.27, 0.2))
	path_strip([Vector3(-40, 0, 0), Vector3(40, 0, 0)], 5.0, Color(0.34, 0.27, 0.2))
	path_strip([Vector3(0, 0, -20), Vector3(-24, 0, -32)], 4.0, Color(0.34, 0.27, 0.2))
	# casas destruídas
	var houses := [
		[Vector3(-12, 0, 26), PI / 2, true, false], [Vector3(12, 0, 30), -PI / 2, true, true],
		[Vector3(-13, 0, 12), PI / 2, false, true], [Vector3(13, 0, 13), -PI / 2, true, true],
		[Vector3(-18, 0, -8), 0.0, true, true], [Vector3(18, 0, -9), 0.0, true, false],
		[Vector3(-32, 0, 8), PI / 2, true, true], [Vector3(32, 0, 9), -PI / 2, false, true],
		[Vector3(14, 0, -28), PI, true, true], [Vector3(28, 0, -26), PI, true, true],
		[Vector3(-36, 0, -16), PI / 2, true, false], [Vector3(-10, 0, -46), PI, true, true],
		[Vector3(12, 0, -46), PI, true, true], [Vector3(34, 0, 28), -PI / 2, true, true],
	]
	for h in houses:
		Props.house(self, h[0], h[1], rnd.randf_range(5.5, 7.0), rnd.randf_range(4.5, 5.5), h[2], h[3], rnd)
	# fogo, fumaça e destroços
	var fires := [Vector3(-10, 0, 22), Vector3(13, 0.5, 27), Vector3(-15, 0, -5), Vector3(16, 0, 15), Vector3(26, 0, -24), Vector3(-30, 0, 6), Vector3(10, 0, -44), Vector3(-4, 0, -2)]
	for i in fires.size():
		Fx.fire(self, fires[i], rnd.randf_range(0.8, 1.4), i % 2 == 0)
	for i in 26:
		var p := Vector3(rnd.randf_range(-40, 40), 0, rnd.randf_range(-58, 45))
		if absf(p.x) < 4 or absf(p.z) < 3:
			continue
		if rnd.randf() < 0.5:
			Props.crate(self, p, rnd.randf_range(0.8, 1.2), rnd.randf() * TAU)
		else:
			Props.barrel(self, p)
	for i in 12:
		var a := Vector3(rnd.randf_range(-44, 44), 0, rnd.randf_range(-60, 48))
		Props.fence(self, a, a + Vector3(rnd.randf_range(-6, 6), 0, rnd.randf_range(-6, 6)), Color(0.22, 0.15, 0.1))
	for i in 18:
		Props.grass_patch(Vector3(rnd.randf_range(-45, 45), 0, rnd.randf_range(-60, 48)), rnd, Color(0.35, 0.3, 0.15), 5)
	for i in 10:
		Props.pine_tree(self, Vector3(rnd.randf_range(-46, 46), 0, -62 + rnd.randf_range(-2, 2)), rnd, 1.0, Color(0.15, 0.2, 0.15))
		Props.pine_tree(self, Vector3(-46 + rnd.randf_range(-2, 2), 0, rnd.randf_range(-60, 48)), rnd)
		Props.pine_tree(self, Vector3(46 + rnd.randf_range(-2, 2), 0, rnd.randf_range(-60, 48)), rnd)
	for i in 6:
		Props.mountain(self, Vector3(rnd.randf_range(-160, 160), 0, -150 - rnd.randf_range(0, 60)), rnd.randf_range(40, 70), rnd.randf_range(40, 70), Color(0.18, 0.12, 0.12))
	# entrada da aldeia
	Props.torii(self, Vector3(0, 0, 40), 0.0, 1.1, Color(0.35, 0.1, 0.08))
	Props.banner(self, Vector3(-4.5, 0, 36), Color(0.15, 0.1, 0.1))
	Props.banner(self, Vector3(4.5, 0, 36), Color(0.6, 0.05, 0.08), PI)
	# poço central
	var well := Props.body(self, Vector3(-4, 0, -4))
	Props.mesh(well, Props.cyl_mesh(1.1, 1.2, 0.9, 10), Vector3(0, 0.45, 0), Props.mat(Color(0.4, 0.38, 0.36), 1.0))
	Props.add_cyl_shape(well, 1.2, 0.9, Vector3(0, 0.45, 0))
	# torre de vigia (com escada para o jogador subir)
	_watchtower(Vector3(20, 0, -2))
	# jaula do ancião
	cage_bars = Node3D.new()
	add_child(cage_bars)
	cage_bars.position = CAGE_POS
	var wood := Props.mat(Color(0.25, 0.16, 0.1))
	Props.mesh(cage_bars, Props.box_mesh(Vector3(2.6, 0.15, 2.6)), Vector3(0, 2.4, 0), wood)
	for i in 8:
		var a := float(i) / 8.0 * TAU
		Props.mesh(cage_bars, Props.cyl_mesh(0.05, 0.05, 2.4, 5), Vector3(cos(a) * 1.2, 1.2, sin(a) * 1.2), wood)
	var cb := Props.body(cage_bars, Vector3.ZERO)
	Props.add_cyl_shape(cb, 1.3, 2.4, Vector3(0, 1.2, 0))
	elder = CharacterModel.new()
	add_child(elder)
	elder.setup({"skin": Color(0.8, 0.66, 0.55), "hair": Color(0.85, 0.85, 0.85), "armor": Color(0.35, 0.3, 0.25), "armor2": Color(0.4, 0.35, 0.3), "trim": Color(0.3, 0.25, 0.2), "cloth": Color(0.55, 0.5, 0.42), "hakama": Color(0.35, 0.3, 0.25), "hair_style": "topknot", "weapon": "none", "mon": false})
	elder.position = CAGE_POS
	elder.rotation.y = PI * 0.25
	elder.play("kneel", 999.0)
	# portão norte
	gate = Props.gate(self, Vector3(0, 0, -58), 0.0, 6.0)
	Props.stone_wall(self, Vector3(-48, 0, -58), Vector3(-4.2, 0, -58), 3.5, 1.2, Color(0.35, 0.32, 0.3))
	Props.stone_wall(self, Vector3(4.2, 0, -58), Vector3(48, 0, -58), 3.5, 1.2, Color(0.35, 0.32, 0.3))
	shrine(Vector3(6, 0, 7), 2)
	shrine(Vector3(5, 0, -12), 4)


func _watchtower(pos: Vector3) -> void:
	var wood := Props.mat(Color(0.3, 0.2, 0.12))
	var h := 3.0
	var top := Props.solid_box(self, Vector3(4.0, 0.3, 4.0), pos + Vector3(0, h, 0), wood)
	for x in [-1.8, 1.8]:
		for z in [-1.8, 1.8]:
			Props.mesh(self, Props.box_mesh(Vector3(0.25, h + 2.0, 0.25)), pos + Vector3(x, (h + 2.0) / 2, z), wood)
	Props.mesh(top, Props.prism_mesh(Vector3(4.6, 1.2, 4.6)), Vector3(0, 2.6, 0), Props.mat(Color(0.25, 0.2, 0.15)))
	for side in [Vector3(0, 0.6, 1.95), Vector3(0, 0.6, -1.95)]:
		Props.mesh(top, Props.box_mesh(Vector3(4.0, 0.9, 0.1)), side, wood)
	Props.stairs(self, pos + Vector3(-2.0, 0, 0), PI / 2, 1.6, 10, h / 10.0, 0.5, wood)


func _spawn_point(i: int) -> Array:
	if i >= 4:
		return [Vector3(3, 0.1, -10), 0.0]
	if i >= 2:
		return [Vector3(4, 0.1, 9), 0.0]
	return [Vector3(0, 0.1, 46), 0.0]


func _begin_stage(i: int) -> void:
	match i:
		0:
			say([
				["Shin", "A aldeia... reduzida a cinzas. As casas onde cresci, o templo do mestre..."],
				["Shin", "Ainda há soldados de Akuma por aqui. Preciso encontrar o ancião Genzo."],
			], func(): started("Entre na aldeia.", Vector3(0, 0, 24)))
		1:
			spawn("soldier", Vector3(-3, 0, 14), PI, [Vector3(-4, 0, 18), Vector3(4, 0, 8), Vector3(-2, 0, 4)])
			spawn("soldier", Vector3(4, 0, 10), 0.0, [Vector3(6, 0, 4), Vector3(-5, 0, 12)])
			started("Derrote a patrulha na entrada da aldeia (2).", null)
			hint("Ataque pelas costas de um inimigo distraído para começar o combate com vantagem.")
		2:
			checkpoint(2)
			house_clue = interactable(Vector3(-13, 0, 3.0), "Vasculhar a casa", func(_p): _search_house(), 2.6)
			started("Procure pistas do ancião Genzo nas casas.", Vector3(-13, 0, 3.0))
		3:
			spawn("soldier", Vector3(-24, 0, 0), PI / 2, [], true)
			spawn("soldier", Vector3(-6, 0, -12), 0.0, [], true)
			var a := spawn("archer", Vector3(20, 3.3, -2), PI / 2, [], true)
			a.stationary = true
			spawn("archer", Vector3(-28, 0, -10), PI / 2, [], true)
			started("Sobreviva à emboscada (4 inimigos).", null)
			hint("Arqueiros mantêm distância. Defenda as flechas e aproxime-se — a torre de vigia tem uma escada.")
		4:
			checkpoint(4)
			started("Siga para o norte: o ancião está sob guarda.", Vector3(-20, 0, -28))
		5:
			var e := spawn("elite", CAGE_POS + Vector3(3.5, 0, 3.5), PI * 0.25, [CAGE_POS + Vector3(4, 0, 4), CAGE_POS + Vector3(5, 0, -1)])
			spawn("soldier", CAGE_POS + Vector3(-3, 0, 4), 0.0)
			spawn("soldier", CAGE_POS + Vector3(5, 0, 1), PI / 2)
			say([
				["Samurai de Elite", "Mais um rato do clã Kurogane. O velho não vai a lugar nenhum."],
				["Shin", "Solte-o. Agora."],
				["Samurai de Elite", "Venha tentar, garoto."],
			], func():
				e.alert()
				started("Derrote os guardas do ancião (3).", null)
				hint("Samurais de elite defendem com frequência e não recuam com golpes leves. Use o ataque PESADO para quebrar a guarda — ou apare o golpe dele!"))
		6:
			cage_item = interactable(CAGE_POS + Vector3(1.6, 0, 1.6), "Libertar o ancião Genzo", func(_p): _free_elder(), 2.8)
			started("Liberte o ancião Genzo.", CAGE_POS)
		7:
			started("Siga até o portão norte da aldeia.", Vector3(0, 0, -55))


func _check_stage(i: int) -> bool:
	match i:
		0:
			return near(Vector3(0, 0, 24), 5.0)
		1, 3, 5:
			return alive_count() == 0
		2:
			return clue_found
		4:
			return near(Vector3(-20, 0, -28), 7.0)
		6:
			return elder_freed
		7:
			return near(Vector3(0, 0, -55), 4.0)
	return false


func _end_stage(i: int) -> void:
	match i:
		7:
			complete_level()


func _skip_stage(i: int) -> void:
	match i:
		2:
			clue_found = true


func _search_house() -> void:
	clue_found = true
	Sfx.play("pickup", -4.0)
	say([
		["Shin", "Marcas de arrasto... e um bastão de bambu quebrado. É do ancião Genzo."],
		["Shin", "Eles o levaram para o norte, perto do portão. Espere... passos!"],
		["Soldado", "Lá está ele! Cerquem o samurai!"],
	])


func _free_elder() -> void:
	elder_freed = true
	Sfx.play("clash", 0.0)
	var tw := create_tween()
	tw.tween_property(cage_bars, "position:y", -3.0, 1.2)
	for c in cage_bars.get_children():
		if c is StaticBody3D:
			c.queue_free()
	elder.clear_action()
	say([
		["Ancião Genzo", "Shin... você vive! Os deuses ainda olham por este vale."],
		["Ancião Genzo", "Akuma procura a Tsukikage, a Espada da Sombra da Lua. Ela está selada no Templo das Sombras, além da floresta escura ao norte."],
		["Ancião Genzo", "O templo é cheio de armadilhas, e um samurai de elite de Akuma já está a caminho. A lâmina só aceita alguém de sangue Kurogane."],
		["Shin", "Então ela me aceitará. Fique escondido, ancião. Eu volto quando a lua voltar a ser branca."],
	], func():
		Props.open_gate(gate)
		Game.scrolls += 1
		hint("Portão norte aberto."))
