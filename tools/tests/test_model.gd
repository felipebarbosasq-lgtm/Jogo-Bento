extends Node3D
## Cena de teste: renderiza o modelo em várias poses e salva capturas.
var models := []
var frame := 0
func _ready() -> void:
	Props.environment(self, {"sky_top": Color(0.3,0.4,0.6), "sun_rot": Vector3(-40, 150, 0), "fog_density": 0.002, "ambient_energy": 0.8})
	Props.ground(self, Vector2(40, 40), Vector3.ZERO, Props.mat(Color(0.3,0.35,0.25)))
	var poses := ["", "walk", "attack1", "attack2", "attack3", "heavy", "block", "dodge", "aim", "dead"]
	var cfgs := [{}, {"helmet":"jingasa","hair_style":"none","armor":Color(0.35,0.28,0.2),"trim":Color(0.2,0.25,0.4),"mon":false}, {"helmet":"kabuto","mask":true,"armor":Color(0.4,0.05,0.06)}, {"helmet":"oni","mask":true,"cape":true,"weapon":"odachi","eyes":Color(1,0.1,0.1),"blade_glow":1.5,"blade_color":Color(0.9,0.1,0.1)}, {"weapon":"bow","helmet":"jingasa","hair_style":"none"}]
	for i in poses.size():
		var m := CharacterModel.new()
		add_child(m)
		m.setup(cfgs[i % cfgs.size()])
		m.position = Vector3((i % 5) * 1.6 - 3.2, 0, -(i / 5) * 2.2)
		m.rotation.y = PI * float(OS.get_environment("ROT"))
		models.append([m, poses[i]])
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(float(OS.get_environment("CX")), 1.5, float(OS.get_environment("CZ")))
	cam.look_at(Vector3(float(OS.get_environment("CX")), 1.0, 0)); cam.fov = float(OS.get_environment("FOV"))
func _process(delta: float) -> void:
	frame += 1
	for e in models:
		var m: CharacterModel = e[0]
		var pose: String = e[1]
		if pose == "walk":
			m.move_speed = 3.0
		elif pose != "" and frame == 2:
			m.play(pose, 1.0 if pose != "dead" else 0.8)
		if pose != "" and pose != "walk" and pose != "dead" and pose != "block" and pose != "aim":
			m.action_time = 0.5 if pose != "heavy" else 0.62
			m.action_dur = 1.0
	if frame == 60:
		get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT"))
		get_tree().quit()
