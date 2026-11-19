extends LevelBase
## FASE 3 — O Templo das Sombras (exploração, ~10–12 min)
## Floresta escura iluminada por lanternas, corredor de armadilhas, ponte com
## lâminas pendulares, escadaria do templo, samurai de elite e a espada lendária.

const TOP_Y := 6.0
var barrier_a: Node
var sword_item: WorldObjects.Interactable
var sword_node: Node3D
var sword_taken := false
var kuroha: Enemy
var arrow_traps: Array = []


func _init() -> void:
	ambience = "amb_night"
	ambient_fx = "fireflies"


func _build_world() -> void:
	Props.environment(self, {
		"sky_top": Color(0.02, 0.03, 0.08), "sky_horizon": Color(0.1, 0.13, 0.22), "sky_bottom": Color(0.03, 0.03, 0.05),
		"moon_dir": Vector3(-0.3, 0.45, -1.0), "moon_color": Color(0.85, 0.9, 1.0), "moon_size": 0.045, "moon_glow": 0.7,
		"stars": 0.9, "clouds": 0.2,
		"fog_color": Color(0.08, 0.14, 0.18), "fog_density": 0.022, "fog_sky": 0.2,
		"cloud_light": Color(0.5, 0.58, 0.7), "cloud_shadow": Color(0.06, 0.08, 0.14),
		"ambient": Color(0.26, 0.36, 0.5), "ambient_energy": 0.6, "sun_color": Color(0.6, 0.72, 1.0), "sun_energy": 0.6,
		"sun_rot": Vector3(-45, 20, 0), "exposure": 1.15,
		"grade": {"lift": Vector3(0.0, 0.025, 0.05), "gain": Vector3(0.95, 1.02, 1.08), "saturation": 1.05, "contrast": 1.12, "bloom": 0.5, "threshold": 0.55},
	})
	var ter := make_terrain(Vector2(160, 300), Vector3(0, 0, -115), {"grass_a": Color(0.03, 0.06, 0.06), "grass_b": Color(0.06, 0.11, 0.09), "dirt": Color(0.2, 0.18, 0.15), "rock": Color(0.28, 0.3, 0.34), "moss": Color(0.08, 0.2, 0.1)})
	ter.segs.append([Vector3(0, 0, 12), Vector3(0, 0, -115), 9.5])
	ter.rects.append([Vector2(-26, -242), Vector2(26, -147)])
	ter.pits.append([Vector2(-80, -146.5), Vector2(80, -115.6)])
	ter.paths.append([Vector3(0, 0, 6), Vector3(0, 0, -58), 2.0])
	ter.rise = 9.0
	ter.hill = 18.0
	ter.build(self)
	ter.scatter_grass(self, 9000, Color(0.02, 0.05, 0.05), Color(0.08, 0.15, 0.14), [Color(0.6, 0.8, 1.0), Color(0.85, 0.75, 1.0)], 0.08, 30.0)
	Nature.mountain_range(self, Vector3(0, 0, -115), 230.0, 380.0, 150.0, [Color(0.04, 0.08, 0.08), Color(0.16, 0.18, 0.24), Color(0.6, 0.66, 0.78)], 17)
	Nature.light_shafts(self, Vector3(0, 0, -30), Vector2(7, 30), 12, Vector3(-45, 20, 0), Color(0.55, 0.7, 1.0), 0.14)
	for i in 110:
		var cz := rnd.randf_range(-240, 15)
		if cz < -114.0 and cz > -148.0:
			continue
		var side := -1.0 if rnd.randf() < 0.5 else 1.0
		var cx := side * rnd.randf_range(11.0 if cz > -114.0 else 28.0, 60.0)
		Nature.cedar(self, Vector3(cx, 0, cz), rnd, rnd.randf_range(0.9, 1.3), "night", false)
	var dirt := Color(0.12, 0.13, 0.1)
	# chão em partes: há um abismo sob a ponte (z -116 a -146)
	Props.ground(self, Vector2(200, 400), Vector3(0, -40, -120), Props.mat(Color(0.02, 0.02, 0.03)))
	# névoa no fundo do abismo
	Props.mesh(self, Props.box_mesh(Vector3(90, 0.1, 30)), Vector3(0, -6, -131), Props.unshaded(Color(0.4, 0.45, 0.6, 0.25)))
	# limites
	Props.wall(self, Vector3(40, 12, 1), Vector3(0, 6, 8))
	Props.wall(self, Vector3(1, 12, 120), Vector3(-9, 6, -55))
	Props.wall(self, Vector3(1, 12, 120), Vector3(9, 6, -55))
	# --- Seção A: floresta escura com torii em sequência
	path_strip([Vector3(0, 0, 6), Vector3(0, 0, -58)], 3.5, Color(0.28, 0.27, 0.25))
	for z in range(-4, -56, -5):
		Props.torii(self, Vector3(0, 0, z), 0.0, 0.8, Color(0.55, 0.08, 0.06))
	for z in range(0, -60, -8):
		Props.stone_lantern(self, Vector3(-3.4, 0, z - 2), true, (z / 8) % 2 == 0)
		Props.stone_lantern(self, Vector3(3.4, 0, z - 6), true, (z / 8) % 2 == 1)
	for i in 80:
		var z := rnd.randf_range(-62, 10)
		var side := -1.0 if rnd.randf() < 0.5 else 1.0
		Props.pine_tree(self, Vector3(side * rnd.randf_range(10, 40), 0, z), rnd, rnd.randf_range(0.9, 1.4), Color(0.06, 0.12, 0.1))
	for i in 40:
		Props.bush(Vector3((-1 if i % 2 == 0 else 1) * rnd.randf_range(5, 8.5), 0, rnd.randf_range(-58, 4)), rnd, Color(0.08, 0.15, 0.1))
	# --- Seção B: corredor de armadilhas (paredes de pedra)
	var stone_c := Color(0.3, 0.3, 0.33)
	Props.stone_wall(self, Vector3(-4, 0, -60), Vector3(-4, 0, -112), 4.0, 1.0, stone_c, false)
	Props.stone_wall(self, Vector3(4, 0, -60), Vector3(4, 0, -112), 4.0, 1.0, stone_c, false)
	Props.stone_wall(self, Vector3(-9, 0, -60), Vector3(-4.5, 0, -60), 4.0, 1.0, stone_c, false)
	Props.stone_wall(self, Vector3(4.5, 0, -60), Vector3(9, 0, -60), 4.0, 1.0, stone_c, false)
	Props.torii(self, Vector3(0, 0, -60), 0.0, 0.85, Color(0.2, 0.2, 0.22))
	path_strip([Vector3(0, 0, -60), Vector3(0, 0, -114)], 7.0, Color(0.22, 0.22, 0.24))
	var spikes := [[-68.0, 0.0], [-74.0, 1.0], [-80.0, 2.0], [-86.0, 0.5], [-92.0, 1.5]]
	for s in spikes:
		var t := WorldObjects.SpikeTrap.new()
		t.size = Vector2(7.0, 3.0)
		t.period = 3.0
		t.offset = s[1]
		add_child(t)
		t.global_position = Vector3(0, 0, s[0])
	for k in 4:
		var at := WorldObjects.ArrowTrap.new()
		at.interval = 2.4
		at.offset = k * 0.6
		add_child(at)
		var side := -1.0 if k % 2 == 0 else 1.0
		at.global_position = Vector3(side * 4.0, 0, -98 - k * 3.5)
		at.rotation.y = -side * PI / 2
		arrow_traps.append(at)
	for z in range(-64, -112, -6):
		Props.hanging_lantern(self, Vector3(-3.3, 3.2, z), Color(1.0, 0.5, 0.2), z % 12 == 0)
		Props.hanging_lantern(self, Vector3(3.3, 3.2, z - 3), Color(1.0, 0.5, 0.2), false)
	# --- Seção C: ponte sobre o abismo com lâminas pendulares
	var plank := Props.mat(Color(0.35, 0.24, 0.15))
	var bridge := Props.solid_box(self, Vector3(3.2, 0.3, 34), Vector3(0, -0.15, -131), plank)
	for i in 17:
		Props.mesh(bridge, Props.box_mesh(Vector3(3.4, 0.06, 0.15)), Vector3(0, 0.17, -16 + i * 2.0), Props.mat(Color(0.2, 0.13, 0.08)))
	for x in [-1.7, 1.7]:
		Props.mesh(self, Props.box_mesh(Vector3(0.08, 0.08, 34)), Vector3(x, 1.0, -131), Props.mat(Color(0.55, 0.45, 0.3)))
		for i in 9:
			Props.mesh(self, Props.box_mesh(Vector3(0.12, 1.1, 0.12)), Vector3(x, 0.5, -115 - i * 4.0), plank)
	Props.wall(self, Vector3(0.3, 3, 34), Vector3(-1.75, 1.5, -131))
	Props.wall(self, Vector3(0.3, 3, 34), Vector3(1.75, 1.5, -131))
	for k in 3:
		var pz := -122.0 - k * 9.0
		var frame := Node3D.new()
		add_child(frame)
		frame.position = Vector3(0, 0, pz)
		Props.mesh(frame, Props.box_mesh(Vector3(0.4, 7.0, 0.4)), Vector3(-2.4, 3.0, 0), plank)
		Props.mesh(frame, Props.box_mesh(Vector3(0.4, 7.0, 0.4)), Vector3(2.4, 3.0, 0), plank)
		var pen := WorldObjects.Pendulum.new()
		pen.length = 5.2
		pen.speed = 1.5 + k * 0.25
		pen.offset = k * 1.3
		pen.amp = 1.0
		add_child(pen)
		pen.global_position = Vector3(0, 6.4, pz)
		pen.rotation.y = PI / 2
	# --- Seção D: escadaria e plataforma do templo
	var stone := Props.mat(Color(0.36, 0.36, 0.38), 1.0)
	Props.stairs(self, Vector3(0, 0, -150), 0.0, 8.0, 24, TOP_Y / 24.0, 0.75, stone)
	var plat := Props.solid_box(self, Vector3(44, TOP_Y, 48), Vector3(0, TOP_Y / 2, -192), stone)
	Props.mesh(plat, Props.box_mesh(Vector3(44.6, 0.3, 48.6)), Vector3(0, TOP_Y / 2, 0), Props.mat(Color(0.28, 0.28, 0.3)))
	Props.wall(self, Vector3(44, 8, 1), Vector3(0, TOP_Y + 4, -216.5))
	Props.wall(self, Vector3(1, 8, 48), Vector3(-22, TOP_Y + 4, -192))
	Props.wall(self, Vector3(1, 8, 48), Vector3(22, TOP_Y + 4, -192))
	Props.wall(self, Vector3(1, 8, 24), Vector3(-4.3, 3, -158))
	Props.wall(self, Vector3(1, 8, 24), Vector3(4.3, 3, -158))
	for x in [-18.0, -10.0, 10.0, 18.0]:
		Props.wall(self, Vector3(6.5, 3, 0.6), Vector3(x, TOP_Y + 1.5, -168.2))
	for x in [-5.0, 5.0]:
		Props.stone_lantern(self, Vector3(x, TOP_Y, -172), true, true)
	for i in 6:
		Props.stone_lantern(self, Vector3(-15 + i * 6, TOP_Y, -186), true, i % 2 == 0)
	Props.temple(self, Vector3(0, TOP_Y, -204), 0.0, 1.0)
	for x in [-16.0, 16.0]:
		Props.cherry_tree(self, Vector3(x, TOP_Y, -180), rnd, 1.0, Color(0.85, 0.75, 0.9))
		Props.banner(self, Vector3(x * 0.6, TOP_Y, -175), Color(0.3, 0.05, 0.4))
	for i in 20:
		Props.pine_tree(self, Vector3((-1 if i % 2 == 0 else 1) * rnd.randf_range(25, 45), 0, rnd.randf_range(-150, -230)), rnd, 1.3, Color(0.06, 0.12, 0.1))
	# altar com a espada lendária
	var altar := Props.solid_box(self, Vector3(1.6, 1.0, 0.9), Vector3(0, TOP_Y + 1.5, -206.5), Props.mat(Color(0.12, 0.1, 0.1)))
	Props.mesh(altar, Props.box_mesh(Vector3(1.8, 0.1, 1.1)), Vector3(0, 0.55, 0), Props.mat(Color(0.5, 0.08, 0.06)))
	sword_node = Node3D.new()
	add_child(sword_node)
	sword_node.position = Vector3(0, TOP_Y + 2.6, -206.5)
	Props.mesh(sword_node, Props.box_mesh(Vector3(0.025, 1.0, 0.07)), Vector3(0, -0.1, 0), Props.mat(Color(0.7, 0.85, 1.0), 0.2, 0.9, 2.5))
	Props.mesh(sword_node, Props.box_mesh(Vector3(0.04, 0.3, 0.04)), Vector3(0, 0.55, 0), Props.mat(Color(0.05, 0.05, 0.08)))
	Props.mesh(sword_node, Props.cyl_mesh(0.08, 0.08, 0.02, 10), Vector3(0, 0.4, 0), Props.mat(Color(0.8, 0.7, 0.3), 0.3, 0.8))
	var sl := OmniLight3D.new()
	sl.light_color = Color(0.5, 0.7, 1.0)
	sl.light_energy = 2.5
	sl.omni_range = 7.0
	sword_node.add_child(sl)
	# barreira antes do pátio
	barrier_a = Props.barrier(self, Vector3(0, TOP_Y, -169), 9.0, 0.0, Color(0.4, 0.2, 0.8))
	shrine(Vector3(4.5, 0, -112), 3)
	shrine(Vector3(3.2, TOP_Y, -172), 5)


func _spawn_point(i: int) -> Array:
	if i >= 5:
		return [Vector3(0, TOP_Y + 0.2, -172), 0.0]
	if i >= 3:
		return [Vector3(0, 0.1, -112), 0.0]
	return [Vector3(0, 0.1, 4), 0.0]


func _begin_stage(i: int) -> void:
	match i:
		0:
			say([
				["Shin", "A floresta das sombras. Dizem que nenhum soldado comum ousa atravessá-la à noite."],
				["Shin", "Mas os homens de Akuma já passaram por aqui. Sigo as lanternas."],
			], func():
				spawn("soldier", Vector3(-2, 0, -40), 0.0, [Vector3(-2, 0, -36), Vector3(2, 0, -46)])
				spawn("soldier", Vector3(2, 0, -48), PI, [Vector3(2, 0, -50), Vector3(-2, 0, -42)])
				spawn("archer", Vector3(0, 0, -55), 0.0, [Vector3(-2, 0, -55), Vector3(2, 0, -55)])
				started("Atravesse a floresta escura.", Vector3(0, 0, -60)))
		1:
			started("Atravesse a floresta escura.", Vector3(0, 0, -60))
		2:
			started("Atravesse o corredor de armadilhas.", Vector3(0, 0, -110))
			hint("Espinhos tremem antes de subir: observe o ritmo. A esquiva deixa você invulnerável por um instante. Defenda as flechas das paredes!")
		3:
			checkpoint(3)
			for at in arrow_traps:
				at.active = false
			started("Cruze a ponte desviando das lâminas.", Vector3(0, 0, -149))
			hint("Espere a lâmina passar e corra (ou esquive) pelo espaço livre.")
		4:
			started("Suba a escadaria do templo.", Vector3(0, TOP_Y, -171))
		5:
			checkpoint(5)
			kuroha = spawn("elite", Vector3(0, TOP_Y, -190), 0.0)
			kuroha.display_name = "Kuroha, Lâmina de Akuma"
			kuroha.max_hp = 190.0
			kuroha.hp = 190.0
			kuroha.data = kuroha.data.duplicate()
			kuroha.data.leash = 40.0
			kuroha.data.poise = 40.0
			spawn("soldier", Vector3(-6, TOP_Y, -186), 0.0)
			spawn("soldier", Vector3(6, TOP_Y, -186), 0.0)
			Props.remove_barrier(barrier_a)
			say([
				["Kuroha", "Então o último Kurogane veio morrer diante do altar dos seus ancestrais."],
				["Kuroha", "Lorde Akuma me deu uma ordem: trazer a Tsukikage. E a sua cabeça, se possível."],
				["Shin", "Esta espada pertence ao meu clã. Você não dará mais nenhum passo."],
			], func():
				kuroha.alert()
				started("Derrote Kuroha, o samurai de elite (e seus soldados).", null))
		6:
			sword_item = interactable(Vector3(0, TOP_Y + 1, -204.8), "Empunhar a espada Tsukikage", func(_p): _take_sword(), 2.6)
			started("Recupere a espada lendária no altar do templo.", Vector3(0, TOP_Y, -205))
		7:
			for k in 4:
				var a := float(k) / 4.0 * TAU
				spawn("soldier", Vector3(cos(a) * 8.0, TOP_Y, -186 + sin(a) * 6.0), 0.0, [], true)
			started("Use o Corte da Lua contra a emboscada (4).", null)
			tutorial("Ki cheio! Pressione Q para o CORTE DA LUA CRESCENTE: um giro que atinge todos ao redor e lança uma onda cortante.", "Ki cheio! Toque em ESPECIAL para o CORTE DA LUA CRESCENTE: atinge todos ao redor e lança uma onda cortante.")
		8:
			started("Siga pela trilha atrás do templo rumo às montanhas.", Vector3(18, TOP_Y, -212))


func _check_stage(i: int) -> bool:
	match i:
		0:
			return near(Vector3(0, 0, -36), 8.0)
		1:
			return alive_count() == 0 and near(Vector3(0, 0, -60), 5.0)
		2:
			return near(Vector3(0, 0, -110), 3.5)
		3:
			return near(Vector3(0, 0, -149), 3.5)
		4:
			return near(Vector3(0, TOP_Y, -171), 3.0) and player.global_position.y > TOP_Y - 1.0
		5, 7:
			return alive_count() == 0
		6:
			return sword_taken
		8:
			return near(Vector3(18, TOP_Y, -212), 3.0)
	return false


func _end_stage(i: int) -> void:
	match i:
		8:
			complete_level()


func _skip_stage(i: int) -> void:
	match i:
		3:
			for at in arrow_traps:
				at.active = false
		4:
			Props.remove_barrier(barrier_a)


func _take_sword() -> void:
	sword_taken = true
	Game.special_unlocked = true
	player.ki = player.max_ki
	Sfx.play("special", 0.0, 0.0)
	Sfx.play("gong", -4.0, 0.0)
	Fx.burst(sword_node.global_position, Color(0.6, 0.8, 1.0), 60, 6.0)
	Fx.ring(player.global_position, 8.0, Color(0.5, 0.75, 1.0, 0.9), 0.8)
	sword_node.queue_free()
	player.model.blade_mat.albedo_color = Color(0.75, 0.88, 1.0)
	var glow_mat := Props.mat(Color(0.7, 0.85, 1.0), 0.2, 0.9, 1.6)
	for mi in player.model.weapon_node.get_children():
		if mi is MeshInstance3D and mi.material_override == player.model.blade_mat:
			mi.material_override = glow_mat
	player.cinematic(player.global_position + Vector3(2.5, 2.0, 3.0), player.global_position + Vector3(0, 1.4, 0), 2.0, 1.5)
	say([
		["Shin", "A lâmina... está fria como a luz da lua. Sinto o espírito dos meus ancestrais nela."],
		["Voz da Tsukikage", "Sangue de Kurogane... Aceito o seu juramento. Corte as sombras, e a lua lhe emprestará a força."],
		["Shin", "Passos na escadaria. Eles ouviram o gongo."],
	])
