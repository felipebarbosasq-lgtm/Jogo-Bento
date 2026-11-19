class_name TouchControls
extends Control
## Controles de tela sensível ao toque: joystick virtual (esquerda), câmera por
## arraste (direita) e botões de ação. Os botões acionam as mesmas ações do
## InputMap usadas pelo teclado/controle.

signal pause_pressed

const BUTTONS := [
	{"id": "attack", "label": "ATAQUE", "sub": "segure: pesado", "pos": Vector2(-140, -140), "r": 74.0, "col": Color(0.8, 0.12, 0.12)},
	{"id": "dodge", "label": "ESQUIVA", "sub": "", "pos": Vector2(-300, -95), "r": 52.0, "col": Color(0.3, 0.5, 0.8)},
	{"id": "block", "label": "DEFESA", "sub": "", "pos": Vector2(-125, -310), "r": 52.0, "col": Color(0.55, 0.55, 0.6)},
	{"id": "parry", "label": "APARAR", "sub": "", "pos": Vector2(-280, -255), "r": 46.0, "col": Color(0.9, 0.75, 0.3)},
	{"id": "special", "label": "ESPECIAL", "sub": "", "pos": Vector2(-430, -110), "r": 44.0, "col": Color(0.45, 0.7, 1.0)},
	{"id": "interact", "label": "AGIR", "sub": "", "pos": Vector2(-140, -450), "r": 40.0, "col": Color(0.9, 0.9, 0.85)},
]

var _fingers := {}          # índice -> "joy" / "look" / id do botão
var _joy_center := Vector2.ZERO
var _joy_vec := Vector2.ZERO
var _joy_active := false
var _pressed := {}
const JOY_R := 90.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _btn_center(b: Dictionary) -> Vector2:
	var p: Vector2 = b.pos
	return Vector2(size.x + p.x, size.y + p.y)


func _pause_center() -> Vector2:
	return Vector2(size.x * 0.5, 44)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_on_press(t.index, t.position)
		else:
			_on_release(t.index)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		var role = _fingers.get(d.index, "")
		if role == "joy":
			var v := d.position - _joy_center
			if v.length() > JOY_R:
				# o joystick acompanha o dedo
				_joy_center = d.position - v.normalized() * JOY_R
				v = v.normalized() * JOY_R
			_joy_vec = v / JOY_R
			Game.touch_move = _joy_vec
			queue_redraw()
		elif role == "look":
			Game.touch_look += d.relative


func _on_press(idx: int, pos: Vector2) -> void:
	if pos.distance_to(_pause_center()) < 40.0:
		pause_pressed.emit()
		return
	for b in BUTTONS:
		if pos.distance_to(_btn_center(b)) < float(b.r) * 1.15:
			_fingers[idx] = b.id
			_pressed[b.id] = true
			Input.action_press(str(b.id))
			return
	if pos.x < size.x * 0.42:
		_fingers[idx] = "joy"
		_joy_center = pos
		_joy_vec = Vector2.ZERO
		_joy_active = true
	else:
		_fingers[idx] = "look"


func _on_release(idx: int) -> void:
	var role = _fingers.get(idx, "")
	_fingers.erase(idx)
	if role == "joy":
		_joy_active = false
		_joy_vec = Vector2.ZERO
		Game.touch_move = Vector2.ZERO
	elif role != "look" and role != "":
		_pressed.erase(role)
		Input.action_release(str(role))


func release_all() -> void:
	for id in _pressed.keys():
		Input.action_release(str(id))
	_pressed.clear()
	_fingers.clear()
	_joy_active = false
	_joy_vec = Vector2.ZERO
	Game.touch_move = Vector2.ZERO
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		release_all()


func _draw() -> void:
	var font := get_theme_default_font()
	# joystick
	var jc := _joy_center if _joy_active else Vector2(170, size.y - 170)
	draw_circle(jc, JOY_R, Color(1, 1, 1, 0.08))
	draw_arc(jc, JOY_R, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
	draw_circle(jc + _joy_vec * JOY_R, 38, Color(1, 1, 1, 0.35 if _joy_active else 0.2))
	if not _joy_active:
		draw_string(font, jc + Vector2(-50, JOY_R + 26), "MOVER", HORIZONTAL_ALIGNMENT_CENTER, 100, 16, Color(1, 1, 1, 0.5))
	# botões
	for b in BUTTONS:
		if b.id == "special" and not Game.special_unlocked:
			continue
		var c := _btn_center(b)
		var r: float = b.r
		var col: Color = b.col
		var on: bool = _pressed.has(b.id)
		draw_circle(c, r, Color(col.r, col.g, col.b, 0.55 if on else 0.28))
		draw_arc(c, r, 0, TAU, 40, Color(col.r, col.g, col.b, 0.9), 3.0)
		var fs := 18 if r > 45 else 14
		draw_string(font, c + Vector2(-r, fs * 0.35), str(b.label), HORIZONTAL_ALIGNMENT_CENTER, r * 2, fs, Color(1, 1, 1, 0.95))
		if str(b.sub) != "":
			draw_string(font, c + Vector2(-r, fs * 0.35 + 20), str(b.sub), HORIZONTAL_ALIGNMENT_CENTER, r * 2, 11, Color(1, 1, 1, 0.6))
		if b.id == "special" and is_instance_valid(Game.player):
			var k: float = Game.player.ki / Game.player.max_ki
			draw_arc(c, r + 6, -PI / 2, -PI / 2 + TAU * k, 40, Color(0.5, 0.8, 1.0, 0.9), 4.0)
	# pausa
	var pc := _pause_center()
	draw_circle(pc, 26, Color(0, 0, 0, 0.35))
	draw_rect(Rect2(pc + Vector2(-9, -10), Vector2(6, 20)), Color(1, 1, 1, 0.8))
	draw_rect(Rect2(pc + Vector2(3, -10), Vector2(6, 20)), Color(1, 1, 1, 0.8))


func _process(_delta: float) -> void:
	if Game.special_unlocked:
		queue_redraw()
