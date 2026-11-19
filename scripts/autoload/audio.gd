extends Node
## Gerenciador de áudio: efeitos (2D e posicionais), ambiente e música com crossfade.
## Todos os arquivos em res://assets/audio foram gerados por tools/gen_audio.py.

const SFX_NAMES := [
	"swing_light", "swing_heavy", "clash", "block", "parry", "hit", "hurt", "step",
	"dodge", "bow", "arrow_hit", "fall", "special", "pickup", "checkpoint", "gong",
	"ui_click", "ui_select", "trap", "transition", "slam", "roar",
]

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_cur: AudioStreamPlayer
var _music_name := ""
var _amb: AudioStreamPlayer
var _amb_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in SFX_NAMES:
		_streams[n] = _load(n)
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_a = _make_loop_player("Music")
	_music_b = _make_loop_player("Music")
	_music_cur = _music_a
	_amb = _make_loop_player("SFX")


func _load(n: String) -> AudioStream:
	var path := "res://assets/audio/%s.wav" % n
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _make_loop_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	# Garantia de loop mesmo se o arquivo não tiver ponto de loop importado
	p.finished.connect(func():
		if p.has_meta("loop") and p.get_meta("loop"):
			p.play())
	return p


func _stream(n: String) -> AudioStream:
	if not _streams.has(n):
		_streams[n] = _load(n)
	return _streams[n]


## Toca um efeito não-posicional.
func play(n: String, volume_db := 0.0, pitch_var := 0.08) -> void:
	var s := _stream(n)
	if s == null:
		return
	var p: AudioStreamPlayer = null
	for c in _pool:
		if not c.playing:
			p = c
			break
	if p == null:
		p = _pool[0]
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


## Toca um efeito posicional no mundo 3D.
func play_at(n: String, pos: Vector3, volume_db := 0.0, pitch_var := 0.1) -> void:
	var s := _stream(n)
	if s == null:
		return
	var root: Node = Game.level if is_instance_valid(Game.level) else get_tree().current_scene
	if root == null or not (root is Node3D):
		play(n, volume_db, pitch_var)
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = "SFX"
	p.volume_db = volume_db
	p.unit_size = 6.0
	p.max_distance = 60.0
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	root.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


func play_music(n: String, fade_time := 1.5) -> void:
	if n == _music_name:
		return
	_music_name = n
	var old := _music_cur
	var nxt := _music_b if _music_cur == _music_a else _music_a
	_music_cur = nxt
	_kill_fade(old)
	_kill_fade(nxt)
	if old.playing:
		old.set_meta("loop", false)
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -60.0, fade_time)
		tw.tween_callback(old.stop)
		old.set_meta("tween", tw)
	if n == "":
		return
	var s := _stream(n)
	if s == null:
		return
	nxt.stream = s
	nxt.set_meta("loop", not n.begins_with("music_victory") and not n.begins_with("music_defeat"))
	nxt.volume_db = -40.0
	nxt.play()
	var tw2 := create_tween()
	tw2.tween_property(nxt, "volume_db", 0.0, fade_time)
	nxt.set_meta("tween", tw2)


func _kill_fade(p: AudioStreamPlayer) -> void:
	if p.has_meta("tween"):
		var t = p.get_meta("tween")
		if t is Tween and t.is_valid():
			t.kill()
		p.remove_meta("tween")


func stop_music(fade_time := 1.0) -> void:
	play_music("", fade_time)


func play_ambience(n: String) -> void:
	if n == _amb_name:
		return
	_amb_name = n
	if n == "":
		_amb.stop()
		return
	var s := _stream(n)
	if s == null:
		return
	_amb.stream = s
	_amb.set_meta("loop", true)
	_amb.volume_db = -6.0
	_amb.play()


func current_music() -> String:
	return _music_name
