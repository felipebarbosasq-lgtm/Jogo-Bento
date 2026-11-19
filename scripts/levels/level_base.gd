class_name LevelBase
extends Node3D
## Base de todas as fases: cenário, jogador, sistema de etapas (objetivos),
## pontos de salvamento, diálogos, música dinâmica e transições.
##
## Cada fase define uma lista de etapas. Ao morrer, o jogador retorna ao início
## da última etapa salva; as etapas anteriores são "puladas" (portões abertos,
## inimigos já derrotados não reaparecem).

signal level_completed
signal player_died

var level_index := 0
var start_stage := 0
var stage := 0
var player: Player
var hud: Node          # HUD (definido pelo main)
var music_explore := "music_explore"
var music_combat := "music_combat"
var ambience := ""
var ambient_fx := ""
var rnd := RandomNumberGenerator.new()
var _ambient_node: CPUParticles3D
var _stage_enemies: Array = []
var _beacon: Node3D
var _boss: Boss
var _completed := false
var _dialog_queue: Array = []
var _dialog_cb: Callable
var _stage_started := false
var _shrines := {}


# ------------------------------------------------------------- ciclo de vida
func setup(idx: int, from_stage: int, hud_ref: Node) -> void:
	level_index = idx
	start_stage = from_stage
	hud = hud_ref


func _exit_tree() -> void:
	if Terrain.active and is_instance_valid(self):
		Terrain.active = null


func _ready() -> void:
	Game.level = self
	Terrain.active = null
	rnd.seed = 1000 + level_index
	_build_world()
	Props.batch_flush(self)
	player = Player.new()
	add_child(player)
	player.died.connect(_on_player_died)
	if ambient_fx != "":
		_ambient_node = Fx.ambient(ambient_fx)
		add_child(_ambient_node)
	for i in start_stage:
		_skip_stage(i)
	stage = start_stage
	var sp := _spawn_point(stage)
	player.global_position = sp[0]
	player.face(float(sp[1]))
	player.snap_camera()
	Sfx.play_ambience(ambience)
	Sfx.play_music(music_explore)
	Game.cutscene = false
	if hud:
		hud.set_boss(null)
	_intro()


func _intro() -> void:
	## Cinemática de abertura: câmera panorâmica + título da fase.
	var p := player.global_position
	var back := player.global_transform.basis.z
	player.cinematic(p + back * -7.0 + Vector3(4, 4.5, 0), p + Vector3(0, 1.2, 0), 1.2, 2.2)
	if hud and start_stage == 0:
		hud.title_card(Game.LEVEL_TITLES[level_index])
	_begin_stage(stage)


func _process(delta: float) -> void:
	if is_instance_valid(_ambient_node) and is_instance_valid(player):
		_ambient_node.global_position = player.global_position + Vector3(0, 3, 0)
	if _completed or not is_instance_valid(player):
		return
	if _stage_started and not Game.cutscene and _check_stage(stage):
		_stage_started = false
		_end_stage(stage)
		stage += 1
		_begin_stage(stage)
	_update_music()
	_update_prompt()
	_level_process(delta)


func _update_music() -> void:
	if is_instance_valid(_boss) and _boss.active and not _boss.is_dead():
		return
	var fighting := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and (e as Enemy).aggro and not (e as Enemy).is_dead():
			fighting = true
			break
	Sfx.play_music(music_combat if fighting else music_explore, 2.0)


func _update_prompt() -> void:
	if hud == null:
		return
	var it := _nearest_interactable()
	hud.set_prompt(it.prompt if it else "")


func _nearest_interactable() -> WorldObjects.Interactable:
	var best: WorldObjects.Interactable = null
	var bd := 999.0
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as WorldObjects.Interactable
		if it == null or not it.enabled:
			continue
		var d := it.global_position.distance_to(player.global_position)
		if d < it.radius and d < bd:
			best = it
			bd = d
	return best


func try_interact(p: Node) -> bool:
	if Game.cutscene:
		return false
	var it := _nearest_interactable()
	if it:
		it.use(p)
		return true
	return false


# ---------------------------------------------------- etapas (sobrescrever)
func _build_world() -> void:
	pass


func _spawn_point(_stage_idx: int) -> Array:
	## Retorna [posição, yaw] para iniciar na etapa indicada.
	return [Vector3.ZERO, 0.0]


func _begin_stage(_i: int) -> void:
	pass


func _check_stage(_i: int) -> bool:
	return false


func _end_stage(_i: int) -> void:
	pass


func _skip_stage(_i: int) -> void:
	pass


func _level_process(_delta: float) -> void:
	pass


# ------------------------------------------------------------ utilitários
func started(objective: String, beacon_pos = null) -> void:
	## Marca o início de uma etapa com objetivo e marcador opcional.
	_stage_started = true
	if hud:
		hud.set_objective(objective)
	set_beacon(beacon_pos)


func set_beacon(pos) -> void:
	if is_instance_valid(_beacon):
		_beacon.queue_free()
		_beacon = null
	if pos is Vector3:
		_beacon = WorldObjects.Beacon.new()
		add_child(_beacon)
		_beacon.global_position = pos


func near(pos: Vector3, radius: float) -> bool:
	return is_instance_valid(player) and Vector2(player.global_position.x - pos.x, player.global_position.z - pos.z).length() < radius


func spawn(t: String, pos: Vector3, yaw := 0.0, points: Array = [], aggro := false) -> Enemy:
	var e := Enemy.new()
	e.configure(t, pos, points, yaw)
	add_child(e)
	_stage_enemies.append(e)
	if aggro:
		e.call_deferred("alert", false)
	return e


func spawn_boss(id: String, pos: Vector3, yaw := 0.0) -> Boss:
	var b := Boss.new()
	b.setup_boss(id, pos, yaw)
	add_child(b)
	_boss = b
	return b


func alive_count() -> int:
	var n := 0
	for e in _stage_enemies:
		if is_instance_valid(e) and not (e as Enemy).is_dead():
			n += 1
	return n


func clear_stage_enemies() -> void:
	_stage_enemies = _stage_enemies.filter(func(e): return is_instance_valid(e) and not e.is_dead())


func checkpoint(stage_idx: int) -> void:
	## Salva o progresso: ao morrer, o jogador volta para esta etapa.
	Game.save_checkpoint(level_index, stage_idx)
	if is_instance_valid(player):
		player.heal_full()
	if hud:
		hud.toast("Progresso salvo")


func shrine(pos: Vector3, stage_idx: int) -> WorldObjects.Shrine:
	## Santuário: ponto de salvamento físico — ativa ao se aproximar.
	var s := WorldObjects.Shrine.new()
	add_child(s)
	s.global_position = pos
	_shrines[stage_idx] = s
	if stage_idx <= start_stage:
		s.activate(true)
	s.activated.connect(func(): checkpoint(stage))
	return s


func interactable(pos: Vector3, prompt: String, cb: Callable, radius := 2.4) -> WorldObjects.Interactable:
	var it := WorldObjects.Interactable.new()
	it.prompt = prompt
	it.on_use = cb
	it.radius = radius
	add_child(it)
	it.global_position = pos
	return it


func say(lines: Array, cb: Callable = Callable(), lock := true) -> void:
	## Exibe diálogo: lines = [["Nome", "Texto"], ...].
	if hud == null:
		if cb.is_valid():
			cb.call()
		return
	if lock:
		Game.cutscene = true
	hud.show_dialog(lines, func():
		Game.cutscene = false
		if cb.is_valid():
			cb.call())


func hint(text: String) -> void:
	if hud:
		hud.hint(text)


func tutorial(pc_text: String, touch_text: String) -> void:
	hint(touch_text if Game.is_touch() else pc_text)


func complete_level() -> void:
	if _completed:
		return
	_completed = true
	set_beacon(null)
	Sfx.play("transition", 0.0, 0.0)
	level_completed.emit()


func _on_player_died() -> void:
	player_died.emit()


func on_player_hurt(_amount: float) -> void:
	if hud:
		hud.damage_flash()


func on_player_parry() -> void:
	pass


# ---------------------------------------------------------- construção comum
func ground_plane(size: Vector2, center: Vector3, col: Color) -> void:
	Props.ground(self, size, center, Props.mat(col, 1.0))


func bounds(min_c: Vector2, max_c: Vector2, h := 12.0) -> void:
	## Paredes invisíveis ao redor da área jogável.
	var cx := (min_c.x + max_c.x) * 0.5
	var cz := (min_c.y + max_c.y) * 0.5
	var w := max_c.x - min_c.x
	var d := max_c.y - min_c.y
	Props.wall(self, Vector3(w + 2, h, 1), Vector3(cx, h / 2, min_c.y))
	Props.wall(self, Vector3(w + 2, h, 1), Vector3(cx, h / 2, max_c.y))
	Props.wall(self, Vector3(1, h, d + 2), Vector3(min_c.x, h / 2, cz))
	Props.wall(self, Vector3(1, h, d + 2), Vector3(max_c.x, h / 2, cz))


func make_terrain(size: Vector2, center: Vector3, colors: Dictionary = {}, cell := 1.5) -> Terrain:
	## Cria o terreno com relevo; registre as zonas planas antes de chamar build().
	var t := Terrain.new()
	t.size = size
	t.center = center
	t.cell = cell if Game.quality_level() > 0 else cell * 1.4
	Terrain.active = t
	return t


func seg_wall(a: Vector3, b: Vector3, h := 10.0) -> void:
	## Parede invisível entre dois pontos (no plano XZ).
	var d := b - a
	d.y = 0
	Props.wall(self, Vector3(1.0, h, d.length() + 0.6), (a + b) * 0.5 + Vector3(0, h * 0.5, 0), Vector3(0, atan2(d.x, d.z), 0))


func path_strip(points: Array, width: float, col: Color, y := 0.02) -> void:
	## Caminho visual (sem colisão) ligando pontos.
	var m := Props.mat(col, 1.0)
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var d := b - a
		var mid := (a + b) * 0.5
		Props.batch_add("path", Props.box_mesh(Vector3(1, 0.04, 1)), m, Props.xf(Vector3(mid.x, y, mid.z), Vector3(0, atan2(d.x, d.z), 0), Vector3(width, 1, d.length() + width * 0.5)))
