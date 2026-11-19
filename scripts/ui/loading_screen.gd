class_name LoadingScreen
extends Control
## Tela cinematográfica de transição entre fases: arte da fase, título,
## sinopse e dica. Exibida enquanto a fase é construída.

const ART := [
	"res://assets/art/fase1_floresta.jpg",
	"res://assets/art/fase2_aldeia.jpg",
	"res://assets/art/fase3_mata_escura.jpg",
	"res://assets/art/fase4_montanhas.jpg",
	"res://assets/art/fase5_castelo_vale.jpg",
]
const CARD := ["res://assets/art/shin.jpg", "res://assets/art/trilha_mata.jpg", "res://assets/art/elite.jpg", "res://assets/art/raiga.jpg", "res://assets/art/akuma.jpg"]
const SYNOPSIS := [
	"Shin desperta numa floresta de bambu e cedros milenares. A aldeia caiu sob a Lua Sangrenta.",
	"Entre casas em chamas, as patrulhas de Akuma caçam sobreviventes. O ancião Genzo guarda um segredo.",
	"Além da floresta escura, um templo esquecido protege Tsukikage, a Espada da Sombra da Lua.",
	"Na trilha das cerejeiras rumo às montanhas, o General Raiga e suas lâminas gêmeas aguardam.",
	"O castelo de Akuma ergue-se sob a lua vermelha. O último duelo decidirá o destino do vale.",
]
const TIPS := [
	"Apare (F) no instante exato do golpe para atordoar o inimigo.",
	"Ataques pesados quebram a guarda de quem está defendendo.",
	"A esquiva deixa você invulnerável por um instante.",
	"Arqueiros atacam de longe — elimine-os primeiro.",
	"Círculos vermelhos no chão não podem ser defendidos: saia deles!",
]

var level_index := 0
var _bg: TextureRect
var _t := 0.0


static func tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var black := ColorRect.new()
	black.color = Color(0.02, 0.015, 0.02)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	_bg = TextureRect.new()
	_bg.texture = tex(ART[level_index])
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.modulate = Color(0.55, 0.55, 0.6)
	add_child(_bg)
	add_child(UIStyle.gradient_shade(true))
	# cartão vertical com a arte
	var card := TextureRect.new()
	card.texture = tex(CARD[level_index])
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	card.anchor_left = 0.62
	card.anchor_right = 0.9
	card.anchor_top = 0.1
	card.anchor_bottom = 0.9
	add_child(card)
	var frame := Panel.new()
	frame.anchor_left = 0.62
	frame.anchor_right = 0.9
	frame.anchor_top = 0.1
	frame.anchor_bottom = 0.9
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(0.75, 0.6, 0.35, 0.9)
	sb.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", sb)
	add_child(frame)

	var v := VBoxContainer.new()
	v.anchor_left = 0.07
	v.anchor_right = 0.56
	v.anchor_top = 0.28
	v.anchor_bottom = 0.9
	v.add_theme_constant_override("separation", 18)
	add_child(v)
	var parts := str(Game.LEVEL_TITLES[level_index]).split(" — ")
	v.add_child(UIStyle.label(parts[0].to_upper(), 24, Color(0.9, 0.25, 0.22)))
	var title := UIStyle.title(parts[1] if parts.size() > 1 else parts[0], 64)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	var line := ColorRect.new()
	line.color = Color(0.75, 0.6, 0.35, 0.8)
	line.custom_minimum_size = Vector2(260, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(line)
	var syn := UIStyle.label(SYNOPSIS[level_index], 24, Color(0.92, 0.9, 0.86))
	syn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(syn)
	var tip := UIStyle.label("◆ " + TIPS[level_index], 18, Color(0.85, 0.75, 0.55))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tip)


func _process(delta: float) -> void:
	_t += delta
	var s := 1.0 + _t * 0.012
	_bg.scale = Vector2(s, s)
	_bg.pivot_offset = _bg.size * 0.5
