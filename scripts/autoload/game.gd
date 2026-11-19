extends Node
## Estado global do jogo: controles, configurações, salvamento e progresso.

signal settings_changed

const SAVE_PATH := "user://shin_save.json"
const SETTINGS_PATH := "user://shin_settings.json"

const LEVEL_SCRIPTS := [
	"res://scripts/levels/level_1_forest.gd",
	"res://scripts/levels/level_2_village.gd",
	"res://scripts/levels/level_3_temple.gd",
	"res://scripts/levels/level_4_redmoon.gd",
	"res://scripts/levels/level_5_castle.gd",
]
const LEVEL_TITLES := [
	"Fase 1 — O Despertar da Floresta",
	"Fase 2 — A Aldeia Esquecida",
	"Fase 3 — O Templo das Sombras",
	"Fase 4 — O Caminho da Lua Vermelha",
	"Fase 5 — O Último Duelo",
]

# Camadas de física
const L_WORLD := 1
const L_PLAYER := 2
const L_ENEMY := 4
const L_TRIGGER := 8

var settings := {
	"master": 0.85,
	"music": 0.6,
	"sfx": 0.9,
	"sensitivity": 1.0,
	"invert_y": false,
	"touch": "auto",      # auto / on / off
	"quality": "high",    # low / medium / high
	"fullscreen": false,
	"show_fps": false,
}

# Progresso da campanha atual
var level_index := 0
var stage_index := 0
var special_unlocked := false
var deaths := 0
var play_time := 0.0
var scrolls := 0

# Estado de sessão
var cutscene := false          # true durante diálogos/cinemáticas (IA e jogador pausam)
var player: Node = null        # referência ao jogador ativo
var level: Node = null         # referência à fase ativa
var in_game := false

# Entrada virtual (touchscreen)
var touch_move := Vector2.ZERO
var touch_look := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_setup_audio_buses()
	load_settings()
	apply_settings()


func _process(delta: float) -> void:
	if in_game and not get_tree().paused:
		play_time += delta


# ------------------------------------------------------------------ controles
func _add_action(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for ev in events:
		InputMap.action_add_event(action, ev)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _joy_btn(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	return e


func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e


func _setup_input() -> void:
	# Teclado + mouse (botões do mouse são lidos diretamente pelo jogador
	# para não confundir com toques emulados no celular) + controle.
	_add_action("move_forward", [_key(KEY_W), _key(KEY_UP), _joy_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add_action("move_back", [_key(KEY_S), _key(KEY_DOWN), _joy_axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add_action("move_left", [_key(KEY_A), _key(KEY_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0)])
	_add_action("move_right", [_key(KEY_D), _key(KEY_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0)])
	_add_action("sprint", [_key(KEY_SHIFT), _joy_btn(JOY_BUTTON_LEFT_STICK)])
	_add_action("dodge", [_key(KEY_SPACE), _joy_btn(JOY_BUTTON_A)])
	_add_action("parry", [_key(KEY_F), _joy_btn(JOY_BUTTON_LEFT_SHOULDER)])
	_add_action("special", [_key(KEY_Q), _joy_btn(JOY_BUTTON_Y)])
	_add_action("interact", [_key(KEY_E), _joy_btn(JOY_BUTTON_B)])
	_add_action("attack", [_joy_btn(JOY_BUTTON_X), _joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_add_action("block", [_joy_btn(JOY_BUTTON_RIGHT_SHOULDER), _joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_add_action("pause", [_key(KEY_ESCAPE), _key(KEY_P), _joy_btn(JOY_BUTTON_START)])
	_add_action("advance", [_key(KEY_ENTER), _key(KEY_KP_ENTER)])


# ---------------------------------------------------------------------- áudio
func _setup_audio_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _vol(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(idx, v <= 0.001)


# --------------------------------------------------------------- configurações
func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		for k in data.keys():
			if settings.has(k):
				settings[k] = data[k]


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings, "\t"))


func apply_settings() -> void:
	_vol("Master", float(settings.master))
	_vol("Music", float(settings.music))
	_vol("SFX", float(settings.sfx))
	if not is_mobile():
		var want_fs: bool = settings.fullscreen
		var mode := DisplayServer.window_get_mode()
		var is_fs := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if want_fs != is_fs and DisplayServer.get_name() != "headless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_fs else DisplayServer.WINDOW_MODE_WINDOWED)
	var vp := get_viewport()
	if vp:
		match str(settings.quality):
			"low":
				vp.scaling_3d_scale = 0.75
				vp.msaa_3d = Viewport.MSAA_DISABLED
			"medium":
				vp.scaling_3d_scale = 1.0
				vp.msaa_3d = Viewport.MSAA_DISABLED
			_:
				vp.scaling_3d_scale = 1.0
				vp.msaa_3d = Viewport.MSAA_2X
	settings_changed.emit()


func quality_level() -> int:
	match str(settings.quality):
		"low":
			return 0
		"medium":
			return 1
	return 2


func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func is_touch() -> bool:
	match str(settings.touch):
		"on":
			return true
		"off":
			return false
	return is_mobile() or DisplayServer.is_touchscreen_available()


# ------------------------------------------------------------------ salvamento
func new_game() -> void:
	level_index = 0
	stage_index = 0
	special_unlocked = false
	deaths = 0
	play_time = 0.0
	scrolls = 0


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_checkpoint(lvl: int, stage: int) -> void:
	level_index = lvl
	stage_index = stage
	var data := {
		"version": 1,
		"level": lvl,
		"stage": stage,
		"special": special_unlocked,
		"deaths": deaths,
		"time": play_time,
		"scrolls": scrolls,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func load_save() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		return false
	level_index = clampi(int(data.get("level", 0)), 0, LEVEL_SCRIPTS.size() - 1)
	stage_index = maxi(int(data.get("stage", 0)), 0)
	special_unlocked = bool(data.get("special", false))
	deaths = int(data.get("deaths", 0))
	play_time = float(data.get("time", 0.0))
	scrolls = int(data.get("scrolls", 0))
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


# ------------------------------------------------------------ tempo de jogo
var _ts_id := 0


func hitstop(duration: float, time_scale := 0.05) -> void:
	## Congela brevemente o tempo para dar peso aos golpes.
	_ts_id += 1
	var id := _ts_id
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if id == _ts_id:
		Engine.time_scale = 1.0


func reset_time_scale() -> void:
	_ts_id += 1
	Engine.time_scale = 1.0


func format_time(t: float) -> String:
	var s := int(t)
	return "%02d:%02d" % [s / 60, s % 60]
