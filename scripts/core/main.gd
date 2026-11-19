extends Node
## Nó principal: alterna entre menu e jogo, carrega as fases, controla pausa,
## telas de vitória/derrota, transições com fade e controles touch.
##
## Argumentos de linha de comando (após "--") úteis para testes:
##   --level=N   inicia direto na fase N (1 a 5)
##   --stage=S   etapa inicial dentro da fase

var world: Node3D
var ui: CanvasLayer
var hud: HUD
var touch: TouchControls
var menu: MainMenu
var overlay: CanvasLayer
var fade: ColorRect
var pause_menu: PauseMenu
var end_screen: EndScreen
var level: LevelBase
var _loading := false
var _ended := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)

	hud = HUD.new()
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hud)
	hud.visible = false

	var tl := CanvasLayer.new()
	tl.layer = 6
	add_child(tl)
	touch = TouchControls.new()
	touch.process_mode = Node.PROCESS_MODE_PAUSABLE
	tl.add_child(touch)
	touch.visible = false
	touch.pause_pressed.connect(toggle_pause)

	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)

	overlay = CanvasLayer.new()
	overlay.layer = 20
	add_child(overlay)
	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(fade)

	get_tree().set_auto_accept_quit(true)
	var args := _args()
	if args.has("autotest") and ResourceLoader.exists("res://tools/tests/autotest.gd"):
		var bot: Node = load("res://tools/tests/autotest.gd").new()
		bot.set("main", self)
		add_child(bot)
	if args.has("probe") and ResourceLoader.exists("res://tools/tests/combat_probe.gd"):
		add_child(load("res://tools/tests/combat_probe.gd").new())
	if args.has("level"):
		Game.new_game()
		var lv := clampi(int(args.level) - 1, 0, 4)
		Game.special_unlocked = lv >= 3 or args.has("special")
		_start_level(lv, int(args.get("stage", "0")))
	else:
		show_menu()


func _args() -> Dictionary:
	var d := {}
	for a in OS.get_cmdline_user_args():
		var s := str(a).trim_prefix("--")
		var kv := s.split("=")
		d[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return d


# ------------------------------------------------------------------- menu
func show_menu() -> void:
	_clear_ui()
	_unload_level()
	get_tree().paused = false
	Game.in_game = false
	Game.reset_time_scale()
	hud.visible = false
	touch.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu = MainMenu.new()
	ui.add_child(menu)
	menu.play_pressed.connect(_on_play)
	menu.continue_pressed.connect(_on_continue)
	menu.settings_pressed.connect(_open_settings)
	menu.quit_pressed.connect(func(): get_tree().quit())
	Sfx.play_ambience("")
	Sfx.play_music("music_menu")
	_fade_in(1.0)


func _on_play() -> void:
	Game.new_game()
	_start_level(0, 0)


func _on_continue() -> void:
	if Game.load_save():
		_start_level(Game.level_index, Game.stage_index)


func _open_settings() -> void:
	var s := SettingsMenu.new()
	ui.add_child(s)
	s.closed.connect(func():
		if is_instance_valid(pause_menu):
			pause_menu.visible = true
		if is_instance_valid(menu):
			menu.refresh())
	if is_instance_valid(pause_menu):
		pause_menu.visible = false


func _clear_ui() -> void:
	for c in ui.get_children():
		c.queue_free()
	menu = null
	pause_menu = null
	end_screen = null


# ------------------------------------------------------------------ fases
func _start_level(idx: int, stage: int) -> void:
	if _loading:
		return
	_loading = true
	await _fade_out(0.8)
	_clear_ui()
	_unload_level()
	await get_tree().process_frame
	get_tree().paused = false
	Game.reset_time_scale()
	Game.level_index = idx
	Game.stage_index = stage
	if stage == 0:
		Game.save_checkpoint(idx, 0)
	var script: GDScript = load(Game.LEVEL_SCRIPTS[idx])
	level = script.new()
	level.setup(idx, stage, hud)
	world.add_child(level)
	level.level_completed.connect(_on_level_completed)
	level.player_died.connect(_on_player_died)
	hud.visible = true
	touch.visible = Game.is_touch()
	touch.release_all()
	Game.in_game = true
	_ended = false
	if not Game.is_touch() and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_loading = false
	_fade_in(1.2)


func _unload_level() -> void:
	if is_instance_valid(level):
		level.queue_free()
	level = null
	Game.level = null
	Game.player = null
	Game.cutscene = false
	for c in world.get_children():
		c.queue_free()


func _on_level_completed() -> void:
	var idx := level.level_index
	if idx >= Game.LEVEL_SCRIPTS.size() - 1:
		_show_victory()
		return
	Game.save_checkpoint(idx + 1, 0)
	await get_tree().create_timer(1.0).timeout
	_start_level(idx + 1, 0)


func _on_player_died() -> void:
	if _ended:
		return
	_ended = true
	touch.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play_music("music_defeat", 0.5)
	end_screen = EndScreen.new()
	end_screen.victory = false
	ui.add_child(end_screen)
	end_screen.retry_pressed.connect(_retry)
	end_screen.menu_pressed.connect(show_menu)


func _retry() -> void:
	if Game.load_save():
		_start_level(Game.level_index, Game.stage_index)
	else:
		_start_level(level.level_index if is_instance_valid(level) else 0, 0)


func _show_victory() -> void:
	_ended = true
	print("[GAME] VITÓRIA — campanha concluída em %s" % Game.format_time(Game.play_time))
	await get_tree().create_timer(1.5).timeout
	Game.delete_save()
	touch.visible = false
	hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play_music("music_victory", 1.0)
	end_screen = EndScreen.new()
	end_screen.victory = true
	ui.add_child(end_screen)
	end_screen.menu_pressed.connect(show_menu)


# ------------------------------------------------------------------ pausa
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if is_instance_valid(pause_menu):
			_resume()
		else:
			toggle_pause()


func toggle_pause() -> void:
	if not Game.in_game or _ended or _loading or not is_instance_valid(level):
		return
	if get_tree().paused:
		_resume()
		return
	get_tree().paused = true
	Game.reset_time_scale()
	touch.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause_menu = PauseMenu.new()
	ui.add_child(pause_menu)
	pause_menu.resume_pressed.connect(_resume)
	pause_menu.settings_pressed.connect(_open_settings)
	pause_menu.restart_pressed.connect(func():
		_resume()
		_retry())
	pause_menu.menu_pressed.connect(show_menu)
	Sfx.play("ui_click", -6.0)


func _resume() -> void:
	if is_instance_valid(pause_menu):
		pause_menu.queue_free()
	pause_menu = null
	for c in ui.get_children():
		if c is SettingsMenu:
			c.queue_free()
	get_tree().paused = false
	touch.visible = Game.is_touch() and not _ended
	if not Game.is_touch() and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if Game.in_game and not get_tree().paused and Game.is_mobile():
				toggle_pause()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if Game.in_game:
				toggle_pause()


func _process(_delta: float) -> void:
	if Game.in_game and is_instance_valid(touch):
		var want := Game.is_touch() and not get_tree().paused and not _ended and not Game.cutscene
		if touch.visible != want:
			touch.visible = want


# ----------------------------------------------------------------- fades
func _fade_out(t: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, t)
	await tw.finished


func _fade_in(t: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, t)
