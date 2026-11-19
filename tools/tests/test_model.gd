extends Node3D
## Cena de teste: renderiza os personagens e salva uma captura (SHOT).
var models := []
var frame := 0
func _ready() -> void:
	var post_layer := CanvasLayer.new()
	add_child(post_layer)
	var post := ColorRect.new()
	post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	post.material = Shaders.post()
	post_layer.add_child(post)
	Game.post_mat = post.material
	Props.environment(self, {"sky_top": Color(0.25,0.45,0.7), "sky_horizon": Color(0.75,0.82,0.85), "sun_rot": Vector3(-35, 150, 0), "fog_density": 0.002, "ambient_energy": 0.6, "clouds": 0.6})
	Props.ground(self, Vector2(40, 40), Vector3.ZERO, Props.mat(Color(0.25,0.32,0.18)))
	var cfgs := [Player.SHIN_LOOK, Enemy.TYPES.soldier.look, Enemy.TYPES.elite.look, Enemy.TYPES.archer.look, Boss.BOSSES.raiga.look, Boss.BOSSES.akuma.look]
	var scales := [1.0, 1.0, 1.0, 1.0, 1.2, 1.3]
	var pose := OS.get_environment("POSE")
	for i in cfgs.size():
		var m := CharacterModel.new()
		add_child(m)
		var c: Dictionary = cfgs[i].duplicate()
		c["scale"] = scales[i]
		m.setup(c)
		m.position = Vector3(i * 1.5 - 3.75, 0, 0)
		m.rotation.y = PI + 0.35
		if pose != "":
			m.play(pose, 1.0)
		models.append(m)
	Props.batch_flush(self)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.0, 1.5, 6.2)
	cam.fov = 45
	cam.look_at(Vector3(0, 1.1, 0))
func _process(delta: float) -> void:
	frame += 1
	for m in models:
		if m.action != "":
			m.action_time = 0.5
	if frame == 50:
		get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT"))
		get_tree().quit()
