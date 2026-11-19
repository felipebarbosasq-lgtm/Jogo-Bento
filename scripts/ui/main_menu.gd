class_name MainMenu
extends Control
## Menu inicial: Jogar, Continuar, Configurações e Sair.
## Exibe o protagonista em 3D (SubViewport) diante da lua vermelha.

signal play_pressed
signal continue_pressed
signal settings_pressed
signal quit_pressed

var btn_continue: Button
var _model: CharacterModel
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.16, 0.03, 0.05))
	grad.set_color(1, Color(0.02, 0.01, 0.02))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.7, 0.35)
	gt.fill_to = Vector2(0.0, 1.1)
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(bg)

	var moon := MoonDraw.new()
	moon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	moon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(moon)

	_add_petals()
	_add_hero_view()

	var left := VBoxContainer.new()
	left.anchor_top = 0.0
	left.anchor_bottom = 1.0
	left.offset_left = 70
	left.offset_top = 60
	left.offset_right = 640
	left.add_theme_constant_override("separation", 14)
	add_child(left)
	var title := UIStyle.label("SHIN", 120, Color(0.96, 0.94, 0.9))
	title.add_theme_constant_override("outline_size", 12)
	left.add_child(title)
	left.add_child(UIStyle.label("A LENDA DO SAMURAI DAS SOMBRAS", 26, Color(0.9, 0.2, 0.2)))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	left.add_child(spacer)
	var b_play := UIStyle.button("Jogar")
	b_play.pressed.connect(func(): play_pressed.emit())
	left.add_child(b_play)
	btn_continue = UIStyle.button("Continuar")
	btn_continue.pressed.connect(func(): continue_pressed.emit())
	left.add_child(btn_continue)
	var b_set := UIStyle.button("Configurações")
	b_set.pressed.connect(func(): settings_pressed.emit())
	left.add_child(b_set)
	var b_quit := UIStyle.button("Sair")
	b_quit.pressed.connect(func(): quit_pressed.emit())
	left.add_child(b_quit)
	b_play.grab_focus.call_deferred()

	var foot := UIStyle.label("v1.0 • Godot 4 • Arte, modelos e música procedurais originais", 14, Color(0.6, 0.55, 0.55))
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = 24
	foot.offset_top = -36
	add_child(foot)
	refresh()


func refresh() -> void:
	if btn_continue:
		btn_continue.disabled = not Game.has_save()


func _add_petals() -> void:
	var p := CPUParticles2D.new()
	p.amount = 60
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = Vector2(700, -20)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(900, 10)
	p.direction = Vector2(-0.3, 1)
	p.spread = 20
	p.gravity = Vector2(-10, 30)
	p.initial_velocity_min = 20
	p.initial_velocity_max = 60
	p.angular_velocity_min = -90
	p.angular_velocity_max = 90
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = Color(1.0, 0.65, 0.78, 0.85)
	add_child(p)


func _add_hero_view() -> void:
	var svc := SubViewportContainer.new()
	svc.anchor_left = 0.5
	svc.anchor_right = 1.0
	svc.anchor_top = 0.0
	svc.anchor_bottom = 1.0
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	svc.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var cam := Camera3D.new()
	cam.position = Vector3(0.15, 1.15, 4.4)
	cam.fov = 40
	world.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 1.05, 0), Vector3.UP)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 35, 0)
	key.light_energy = 1.1
	key.light_color = Color(1.0, 0.9, 0.85)
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 200, 0)
	rim.light_energy = 2.2
	rim.light_color = Color(1.0, 0.2, 0.15)
	world.add_child(rim)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.3, 0.4)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	_model = CharacterModel.new()
	world.add_child(_model)
	_model.setup(Player.SHIN_LOOK)
	_model.rotation.y = PI + 0.5


func _process(delta: float) -> void:
	_t += delta
	if _model:
		_model.rotation.y = PI + 0.45 + sin(_t * 0.4) * 0.25


class MoonDraw:
	extends Control
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.72, size.y * 0.36)
		var r := size.y * 0.27
		for i in 6:
			draw_circle(c, r * (1.0 + i * 0.12), Color(0.8, 0.05, 0.08, 0.05))
		draw_circle(c, r, Color(0.78, 0.07, 0.1))
		draw_circle(c + Vector2(r * 0.25, -r * 0.2), r * 0.18, Color(0.7, 0.05, 0.08))
		draw_circle(c + Vector2(-r * 0.35, r * 0.3), r * 0.12, Color(0.68, 0.05, 0.08))
		# silhueta de castelo e montanhas
		var base := size.y
		var mount := PackedVector2Array([Vector2(size.x * 0.35, base), Vector2(size.x * 0.5, base * 0.72), Vector2(size.x * 0.62, base * 0.8), Vector2(size.x * 0.78, base * 0.62), Vector2(size.x * 0.95, base * 0.78), Vector2(size.x, base * 0.74), Vector2(size.x, base)])
		draw_colored_polygon(mount, Color(0.05, 0.02, 0.03))
		var cx := size.x * 0.86
		var cy := base * 0.62
		for k in 3:
			var w := 120.0 - k * 32.0
			var y := cy - k * 46.0
			draw_rect(Rect2(cx - w * 0.4, y - 34, w * 0.8, 34), Color(0.03, 0.01, 0.02))
			draw_colored_polygon(PackedVector2Array([Vector2(cx - w * 0.6, y - 30), Vector2(cx + w * 0.6, y - 30), Vector2(cx + w * 0.3, y - 50), Vector2(cx - w * 0.3, y - 50)]), Color(0.03, 0.01, 0.02))
