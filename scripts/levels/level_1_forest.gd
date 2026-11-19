extends LevelBase
## FASE 1 — O Despertar da Floresta (tutorial, ~8–10 min)
## Shin acorda numa floresta de bambu, aprende a correr, saltar (esquiva),
## atacar, defender e aparar; enfrenta três soldados e encontra o primeiro pergaminho.

const END_Z := -215.0
var barrier_a: Node
var barrier_b: Node
var dummies: Array = []
var scroll_item: WorldObjects.Interactable
var scroll_mesh: Node3D


func _init() -> void:
	ambience = "amb_forest"
	ambient_fx = "leaves"


func px(z: float) -> float:
	return sin(z * 0.03) * 6.0


func half_width(z: float) -> float:
	if z < -66.0 and z > -96.0:
		return 15.0
	if z < -160.0 and z > -195.0:
		return 13.0
	return 8.5


func _build_world() -> void:
	Props.environment(self, {
		"sky_top": Color(0.2, 0.48, 0.72), "sky_horizon": Color(0.72, 0.86, 0.86), "sky_bottom": Color(0.2, 0.3, 0.2),
		"moon_dir": Vector3(-0.35, 0.55, -1.0), "moon_color": Color(1.0, 0.95, 0.8), "moon_size": 0.025, "moon_glow": 1.0,
		"fog_color": Color(0.42, 0.58, 0.62), "fog_density": 0.012, "fog_sky": 0.35, "clouds": 0.55,
		"ambient": Color(0.38, 0.5, 0.58), "ambient_energy": 0.55, "sun_color": Color(1.0, 0.9, 0.7), "sun_energy": 1.05, "exposure": 0.9,
		"sun_rot": Vector3(-42, 160, 0),
		"grade": {"lift": Vector3(0.0, 0.015, 0.035), "gain": Vector3(1.02, 1.0, 0.95), "saturation": 0.98, "contrast": 1.12, "bloom": 0.22, "threshold": 0.72},
	})
	# terreno: a trilha é plana; fora dela o chão sobe em encostas cobertas de mata
	var t := make_terrain(Vector2(150, 280), Vector3(0, 0, -110), {"grass_a": Color(0.1, 0.22, 0.08), "grass_b": Color(0.24, 0.38, 0.11), "dirt": Color(0.3, 0.24, 0.16), "grass_dry": Color(0.4, 0.4, 0.2)})
	t.rise = 7.0
	t.hill = 14.0
	t.ramp = 12.0
	var tz := 14.0
	while tz > END_Z - 14:
		var tz2 := tz - 6.0
		t.segs.append([Vector3(px(tz), 0, tz), Vector3(px(tz2), 0, tz2), minf(half_width(tz), half_width(tz2)) + 1.5])
		t.paths.append([Vector3(px(tz), 0, tz), Vector3(px(tz2), 0, tz2), 1.6])
		tz = tz2
	t.rivers.append([Vector3(-60, 0, -118), Vector3(60, 0, -126), 2.2])
	t.build(self)
	t.build_rivers(self)
	t.scatter_grass(self, 20000, Color(0.06, 0.16, 0.05), Color(0.3, 0.46, 0.14), [Color(1, 1, 0.95), Color(1.0, 0.85, 0.3), Color(0.95, 0.55, 0.75)], 0.1, 24.0)
	Nature.mountain_range(self, Vector3(0, 0, -110), 230.0, 380.0, 170.0, [Color(0.12, 0.3, 0.2), Color(0.4, 0.45, 0.5), Color(0.95, 0.97, 1.0)], 3)
	Nature.light_shafts(self, Vector3(0, 0, -100), Vector2(10, 110), 26, Vector3(-42, 160, 0), Color(1.0, 0.95, 0.7), 0.16)
	# trilha de pedras musgosas
	var stone := Props.mat(Color(0.4, 0.4, 0.36), 1.0)
	var z := 4.0
	while z > END_Z - 4:
		var x := px(z) + rnd.randf_range(-0.4, 0.4)
		if rnd.randf() < 0.55:
			Props.batch_add("stone_tile", Nature.rock_mesh(rnd.randi() % 4), Nature.rock_mat(Color(0.48, 0.47, 0.44)), Props.xf(Vector3(x, Terrain.ground_y(x, z) - 0.02, z), Vector3(0, rnd.randf() * TAU, 0), Vector3(rnd.randf_range(0.45, 0.7), 0.08, rnd.randf_range(0.35, 0.55))))
		z -= 1.25
	# cedros gigantes atrás do bambuzal e nas encostas
	for i in 150:
		var cz := rnd.randf_range(END_Z - 15, 15)
		var side := -1.0 if rnd.randf() < 0.5 else 1.0
		Nature.cedar(self, Vector3(px(cz) + side * rnd.randf_range(half_width(cz) + 6.0, 55.0), 0, cz), rnd, rnd.randf_range(0.9, 1.4), "cedar", false)
	for i in 70:
		var cz := rnd.randf_range(END_Z, 10)
		var side := -1.0 if rnd.randf() < 0.5 else 1.0
		Nature.fern(Vector3(px(cz) + side * rnd.randf_range(half_width(cz) - 1.0, half_width(cz) + 4.0), 0, cz), rnd, "green", rnd.randf_range(0.8, 1.5))
	# bambuzal denso + paredes invisíveis seguindo a trilha
	z = 8.0
	while z > END_Z - 10:
		var hw := half_width(z)
		for side in [-1.0, 1.0]:
			for k in 3:
				var off: float = hw + 0.5 + k * 2.2 + rnd.randf_range(-0.6, 0.6)
				var bp := Vector3(px(z) + side * off, 0, z + rnd.randf_range(-1.2, 1.2))
				Props.bamboo(self, bp, rnd)
			if rnd.randf() < 0.5:
				Props.bush(Vector3(px(z) + side * (hw - rnd.randf_range(0.0, 1.5)), 0, z), rnd)
			if rnd.randf() < 0.7:
				Props.grass_patch(Vector3(px(z) + side * rnd.randf_range(2.0, hw), 0, z), rnd, Color(0.35, 0.5, 0.2), 5)
		z -= 2.2
	# bambus distantes (fundo)
	for i in 90:
		var zz := rnd.randf_range(END_Z - 20, 15)
		var side := -1.0 if rnd.randf() < 0.5 else 1.0
		Props.bamboo(self, Vector3(px(zz) + side * rnd.randf_range(12, 30), 0, zz), rnd)
	z = 10.0
	while z > END_Z - 10:
		var z2 := z - 6.0
		var hw2 := minf(half_width(z), half_width(z2))
		for side in [-1.0, 1.0]:
			var a := Vector3(px(z) + side * (half_width(z) + 0.6), 0, z)
			var b := Vector3(px(z2) + side * (half_width(z2) + 0.6), 0, z2)
			var mid := (a + b) * 0.5
			var d := b - a
			Props.wall(self, Vector3(1.0, 10, d.length() + 0.6), mid + Vector3(0, 5, 0), Vector3(0, atan2(d.x, d.z), 0))
		z = z2
	Props.wall(self, Vector3(30, 10, 1), Vector3(px(8), 5, 9))
	Props.wall(self, Vector3(30, 10, 1), Vector3(px(END_Z - 6), 5, END_Z - 7))
	# rochas e troncos decorativos
	for i in 30:
		var zz := rnd.randf_range(END_Z, 0)
		var side := -1.0 if rnd.randf() < 0.5 else 1.0
		Props.rock(self, Vector3(px(zz) + side * (half_width(zz) - rnd.randf_range(0.2, 1.5)), 0.1, zz), Vector3(1, 0.6, 0.9) * rnd.randf_range(0.4, 0.9), rnd)
	# local do despertar
	Props.mesh(self, Props.box_mesh(Vector3(1.6, 0.05, 0.9)), Vector3(px(2) + 1.2, 0.03, 2.0), Props.mat(Color(0.45, 0.12, 0.1)), Vector3(0, 0.3, 0))
	Props.stone_lantern(self, Vector3(px(-6) - 3.0, 0, -6))
	Props.stone_lantern(self, Vector3(px(-6) + 3.0, 0, -6))
	# troncos caídos (saltar com a esquiva)
	var log_m := Props.mat(Color(0.5, 0.56, 0.3), 0.8)
	for lz in [-38.0, -48.0]:
		var lb := Props.solid_box(self, Vector3(half_width(lz) * 2 + 2, 0.55, 0.55), Vector3(px(lz), 0.275, lz), log_m, Vector3(0, -0.05, 0))
		for k in 5:
			Props.mesh(lb, Props.cyl_mesh(0.3, 0.3, 0.05, 8), Vector3(-half_width(lz) + k * half_width(lz) * 0.5, 0, 0), Props.mat(Color(0.4, 0.45, 0.25)), Vector3(0, 0, PI / 2))
	# clareira de treino
	Props.torii(self, Vector3(px(-66), 0, -66), 0.0, 0.9)
	for i in 6:
		var a := float(i) / 6.0 * TAU
		Props.stone_lantern(self, Vector3(px(-81) + cos(a) * 11.0, 0, -81 + sin(a) * 9.0), true, i % 2 == 0)
	Props.fence(self, Vector3(px(-72) - 12, 0, -72), Vector3(px(-72) - 12, 0, -90), Color(0.45, 0.33, 0.2), false)
	Props.banner(self, Vector3(px(-90) + 12, 0, -90), Color(0.6, 0.06, 0.08), PI)
	# barreiras místicas (abrem ao concluir os objetivos)
	barrier_a = Props.barrier(self, Vector3(px(-102), 0, -102), half_width(-102) * 2 + 1)
	barrier_b = Props.barrier(self, Vector3(px(-152), 0, -152), half_width(-152) * 2 + 1)
	# santuário do pergaminho
	var sz := -182.0
	Props.torii(self, Vector3(px(-165), 0, -165), 0.0, 1.0)
	var altar := Props.solid_box(self, Vector3(2.2, 0.9, 1.2), Vector3(px(sz), 0.45, sz - 4), Props.mat(Color(0.42, 0.4, 0.38), 1.0))
	Props.mesh(altar, Props.box_mesh(Vector3(2.4, 0.12, 1.4)), Vector3(0, 0.5, 0), Props.mat(Color(0.25, 0.12, 0.08)))
	scroll_mesh = Node3D.new()
	add_child(scroll_mesh)
	scroll_mesh.position = Vector3(px(sz), 1.08, sz - 4)
	Props.mesh(scroll_mesh, Props.cyl_mesh(0.07, 0.07, 0.55, 10), Vector3.ZERO, Props.mat(Color(0.9, 0.85, 0.7)), Vector3(0, 0, PI / 2))
	Props.mesh(scroll_mesh, Props.cyl_mesh(0.03, 0.03, 0.65, 6), Vector3.ZERO, Props.mat(Color(0.55, 0.08, 0.08)), Vector3(0, 0, PI / 2))
	Props.stone_lantern(self, Vector3(px(sz) - 3, 0, sz - 4))
	Props.stone_lantern(self, Vector3(px(sz) + 3, 0, sz - 4))
	for i in 5:
		Props.cherry_tree(self, Vector3(px(sz) + (-1 if i % 2 == 0 else 1) * rnd.randf_range(6, 10), 0, sz + rnd.randf_range(-8, 8)), rnd, 0.8)
	# portal de saída
	Props.torii(self, Vector3(px(-205), 0, -205), 0.0, 1.3)
	Props.hanging_lantern(self, Vector3(px(-205) - 2.2, 4.4, -205), Color(1, 0.6, 0.3), true)
	Props.hanging_lantern(self, Vector3(px(-205) + 2.2, 4.4, -205), Color(1, 0.6, 0.3), true)
	# santuários de salvamento
	shrine(Vector3(px(-110) + 4.5, 0, -110), 4)
	shrine(Vector3(px(-160) + 4.0, 0, -160), 5)


func _spawn_point(i: int) -> Array:
	if i >= 5:
		return [Vector3(px(-158), 0.1, -158), 0.0]
	if i >= 4:
		return [Vector3(px(-108), 0.1, -108), 0.0]
	return [Vector3(px(2) + 1.2, 0.1, 2.0), 0.0]


func _begin_stage(i: int) -> void:
	match i:
		0:
			player.model.play("kneel", 99.0)
			player.controls_locked = true
			await get_tree().create_timer(2.6).timeout
			say([
				["Shin", "...Onde estou? Minha cabeça... A última coisa que lembro é o fogo na aldeia."],
				["Shin", "Lorde Akuma. Seus soldados vieram sob a Lua Sangrenta... e eu caí."],
				["Shin", "Ainda tenho minha katana. Preciso descobrir o que aconteceu."],
			], func():
				player.model.clear_action()
				player.controls_locked = false
				started("Siga a trilha de pedras pela floresta de bambu.", Vector3(px(-28), 0, -28))
				tutorial("Mova-se com W A S D e gire a câmera com o mouse.", "Use o joystick à esquerda para mover e arraste à direita para girar a câmera."))
		1:
			started("Corra e salte os troncos caídos.", Vector3(px(-60), 0, -60))
			tutorial("Segure SHIFT para correr. Pressione ESPAÇO para esquivar — a esquiva também salta sobre obstáculos baixos.", "Empurre o joystick até o fim para correr. Toque em ESQUIVA para saltar sobre os troncos.")
		2:
			say([["Shin", "Um antigo campo de treino do clã Kurogane. Hora de despertar os músculos."]], func():
				for k in 3:
					var d := WorldObjects.Dummy.new()
					add_child(d)
					d.global_position = Vector3(px(-82) + (k - 1) * 3.5, 0, -84 - (k % 2) * 2.0)
					d.rotation.y = 0.0
					dummies.append(d)
				started("Destrua os 3 bonecos de treino.", Vector3(px(-83), 0, -84))
				tutorial("CLIQUE ESQUERDO: ataque leve (até 3 golpes em sequência). SEGURE o clique esquerdo: ataque pesado.", "Toque em ATAQUE para golpes rápidos (combo de 3). SEGURE ATAQUE para um golpe pesado."))
		3:
			var e := spawn("training", Vector3(px(-95), 0, -95), 0.0)
			e.drop_chance = 1.0
			say([
				["Recruta", "Ei! Um sobrevivente do clã Kurogane! Lorde Akuma pagará bem pela sua cabeça!"],
				["Shin", "Então venha buscá-la."],
			], func():
				e.alert(false)
				started("Derrote o recruta.", null)
				tutorial("SEGURE o CLIQUE DIREITO para defender. Pressione F no instante do golpe para APARAR — o inimigo fica atordoado. Observe o brilho na lâmina inimiga!", "SEGURE DEFESA para bloquear. Toque em APARAR no instante do golpe — o brilho na lâmina inimiga avisa o ataque!"))
		4:
			checkpoint(4)
			spawn("soldier", Vector3(px(-128) - 3, 0, -128), PI, [Vector3(px(-124) - 4, 0, -124), Vector3(px(-136) + 3, 0, -136)])
			spawn("soldier", Vector3(px(-140) + 3, 0, -140), 0.0, [Vector3(px(-142) + 4, 0, -142), Vector3(px(-130) - 3, 0, -132)])
			started("Derrote os soldados que patrulham a floresta (2).", Vector3(px(-134), 0, -134))
			hint("Cuidado: soldados atacam em dupla. Recue, defenda e contra-ataque. Inimigos derrotados às vezes deixam orbes de cura.")
		5:
			checkpoint(5)
			scroll_item = interactable(Vector3(px(-182), 0, -182.5), "Pegar o pergaminho", func(_p):
				_take_scroll(), 2.6)
			started("Encontre o pergaminho no santuário antigo.", Vector3(px(-182), 0, -186))
		6:
			started("Atravesse o portal torii para deixar a floresta.", Vector3(px(-205), 0, -205))


func _check_stage(i: int) -> bool:
	match i:
		0:
			return near(Vector3(px(-28), 0, -28), 4.0)
		1:
			return near(Vector3(px(-60), 0, -60), 5.0)
		2:
			return dummies.size() == 3 and dummies.all(func(d): return d.is_dead())
		3:
			return alive_count() == 0
		4:
			return alive_count() == 0
		5:
			return scroll_item != null and not scroll_item.enabled and not Game.cutscene
		6:
			return near(Vector3(px(-205), 0, -205), 3.5)
	return false


func _end_stage(i: int) -> void:
	match i:
		2:
			hint("Excelente! Ataques consomem resistência (barra amarela). Ela se recupera quando você para de agir.")
		3:
			Props.remove_barrier(barrier_a)
			hint("A barreira mística se desfez. Siga em frente.")
		4:
			Props.remove_barrier(barrier_b)
		6:
			complete_level()


func _skip_stage(i: int) -> void:
	match i:
		3:
			Props.remove_barrier(barrier_a)
		4:
			Props.remove_barrier(barrier_b)


func _take_scroll() -> void:
	Game.scrolls += 1
	Sfx.play("pickup", 0.0, 0.0)
	if is_instance_valid(scroll_mesh):
		scroll_mesh.queue_free()
	say([
		["Pergaminho", "\"Shin, se você lê isto, a aldeia caiu. Akuma busca a espada lendária Tsukikage, selada no Templo das Sombras.\""],
		["Pergaminho", "\"Somente o ancião Genzo conhece o caminho até o templo. Encontre-o na aldeia antes que os homens de Akuma o façam falar.\" — Mestre Hideo"],
		["Shin", "Mestre... Eu prometo. Akuma jamais tocará a Tsukikage."],
	])
