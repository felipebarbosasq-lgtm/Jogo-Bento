class_name Shaders
extends RefCounted
## Shaders do visual cinematográfico: terreno pintado, folhagem e capim com
## vento, água, raios de luz, contorno estilo ilustração e pós-processamento.
## Todos compatíveis com o renderizador "Compatibilidade" (PC, Android e Web).

static var _cache := {}


static func _shader(key: String, code: String) -> Shader:
	if _cache.has("S_" + key):
		return _cache["S_" + key]
	var s := Shader.new()
	s.code = code
	_cache["S_" + key] = s
	return s


# ------------------------------------------------------------------ terreno
const TERRAIN := """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform vec3 grass_a : source_color = vec3(0.22, 0.42, 0.14);
uniform vec3 grass_b : source_color = vec3(0.42, 0.58, 0.18);
uniform vec3 grass_dry : source_color = vec3(0.62, 0.6, 0.3);
uniform vec3 dirt : source_color = vec3(0.45, 0.33, 0.2);
uniform vec3 rock : source_color = vec3(0.4, 0.4, 0.42);
uniform vec3 moss : source_color = vec3(0.25, 0.4, 0.15);
uniform float scale = 0.08;
varying vec3 wpos;
varying vec3 wnorm;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * n2(p); p *= 2.07; a *= 0.5; } return v; }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = wpos.xz * scale;
	float n = fbm(p);
	float n_fine = n2(wpos.xz * 1.7);
	vec3 g = mix(grass_a, grass_b, smoothstep(0.35, 0.75, n));
	g = mix(g, grass_dry, smoothstep(0.68, 0.9, fbm(p * 0.5 + 7.0)) * 0.6);
	g *= 0.85 + n_fine * 0.25;
	float slope = 1.0 - wnorm.y;
	float rk = smoothstep(0.32, 0.55, slope + (n - 0.5) * 0.25);
	vec3 r = rock * (0.75 + 0.45 * fbm(wpos.xz * 0.4 + wpos.y * 0.3));
	r = mix(r, moss, smoothstep(0.4, 0.8, fbm(wpos.xz * 0.25)) * 0.5 * wnorm.y);
	vec3 col = mix(g, r, rk);
	float path = COLOR.r;
	vec3 d = dirt * (0.8 + 0.4 * n_fine) * (0.9 + 0.2 * n);
	col = mix(col, d, smoothstep(0.15, 0.6, path + (n_fine - 0.5) * 0.35));
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
"""


# ------------------------------------------------------------------ folhagem
const FOLIAGE := """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;
uniform vec3 color_dark : source_color = vec3(0.08, 0.22, 0.1);
uniform vec3 color_light : source_color = vec3(0.45, 0.66, 0.22);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.95, 0.6);
uniform float wind = 0.12;
uniform float wind_speed = 1.3;
varying float vh;
varying vec3 wpos;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ph = TIME * wind_speed + w.x * 0.15 + w.z * 0.11;
	float k = clamp(VERTEX.y * 0.5 + 0.5, 0.0, 1.0);
	VERTEX.x += sin(ph) * wind * k;
	VERTEX.z += cos(ph * 0.8) * wind * 0.6 * k;
	vh = VERTEX.y;
	wpos = w;
}

void fragment() {
	float n = n2(wpos.xz * 0.9 + wpos.y * 0.6) * 0.6 + n2(wpos.xz * 3.1) * 0.4;
	float up = clamp(dot(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz) * 0.5 + 0.5, 0.0, 1.0);
	float t = clamp(up * 0.75 + n * 0.45 + clamp(vh, -1.0, 1.0) * 0.15, 0.0, 1.0);
	vec3 col = mix(color_dark, color_light, smoothstep(0.25, 0.85, t));
	col = mix(col, col * sun_tint * 1.15, smoothstep(0.82, 1.0, t));
	ALBEDO = col * (COLOR.rgb * 0.0 + 1.0);
	ROUGHNESS = 1.0;
	BACKLIGHT = vec3(0.12, 0.16, 0.05);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = col * rim * 0.12;
}
"""


# -------------------------------------------------------------------- capim
const GRASS := """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;
uniform vec3 base_color : source_color = vec3(0.12, 0.28, 0.08);
uniform vec3 tip_color : source_color = vec3(0.55, 0.72, 0.25);
uniform float wind = 0.25;
uniform float fade_dist = 60.0;
varying float vy;
varying vec3 wpos;
varying float flower;
varying vec3 fcol;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	flower = COLOR.b;
	fcol = INSTANCE_CUSTOM.rgb;
	float k = clamp(VERTEX.y / 0.6, 0.0, 1.0);
	float ph = TIME * 1.8 + w.x * 0.35 + w.z * 0.27;
	float gust = sin(TIME * 0.6 + w.x * 0.05) * 0.5 + 0.5;
	VERTEX.x += sin(ph) * wind * k * k * (0.5 + gust);
	VERTEX.z += cos(ph * 0.7) * wind * 0.5 * k * k;
	vy = k;
	wpos = w;
}

void fragment() {
	float var_n = fract(sin(dot(floor(wpos.xz * 0.7), vec2(12.9, 78.2))) * 4375.5);
	vec3 tip = tip_color * (0.85 + 0.3 * var_n);
	ALBEDO = flower > 0.5 ? fcol : mix(base_color, tip, vy);
	ROUGHNESS = 1.0;
	BACKLIGHT = vec3(0.1, 0.12, 0.03) * vy;
	float d = length(wpos - CAMERA_POSITION_WORLD);
	if (d > fade_dist) { discard; }
}
"""


# -------------------------------------------------------------------- água
const WATER := """
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, cull_disabled;
uniform vec3 deep : source_color = vec3(0.05, 0.3, 0.38);
uniform vec3 shallow : source_color = vec3(0.35, 0.75, 0.8);
uniform vec3 foam : source_color = vec3(0.92, 0.97, 1.0);
uniform vec2 flow = vec2(0.0, -0.6);
varying vec3 wpos;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 2.0 + wpos.x * 1.3 + wpos.z * 0.7) * 0.02;
}

void fragment() {
	vec2 p = wpos.xz * 0.8 + flow * TIME;
	float a = n2(p);
	float b = n2(p * 2.3 - flow * TIME * 0.7 + 3.0);
	float edge = COLOR.r;
	vec3 col = mix(shallow, deep, smoothstep(0.0, 1.0, edge));
	float f = smoothstep(0.62, 0.78, a * 0.6 + b * 0.4) + smoothstep(0.6, 0.95, 1.0 - edge) * 0.6;
	col = mix(col, foam, clamp(f, 0.0, 1.0) * 0.8);
	ALBEDO = col;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	NORMAL_MAP = normalize(vec3(a - 0.5, b - 0.5, 1.0)) * 0.5 + 0.5;
	ALPHA = 0.88;
}
"""


# ------------------------------------------------------------ raios de luz
const SHAFT := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 color : source_color = vec3(1.0, 0.95, 0.75);
uniform float strength = 0.22;
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n1(float x) { float i = floor(x); float f = fract(x); return mix(h2(vec2(i, 0.0)), h2(vec2(i + 1.0, 0.0)), f * f * (3.0 - 2.0 * f)); }
void fragment() {
	float edge = sin(UV.x * 3.14159);
	float vfade = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.55, UV.y);
	float streak = 0.6 + 0.4 * n1(UV.x * 9.0 + TIME * 0.15);
	float view = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = color * edge * edge * vfade * streak * strength * (0.4 + 0.6 * (1.0 - view));
}
"""


# ---------------------------------------------------------------- contorno
const OUTLINE := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform vec4 color : source_color = vec4(0.02, 0.015, 0.02, 1.0);
uniform float width = 0.012;
void vertex() {
	VERTEX += normalize(VERTEX + vec3(0.0001)) * width;
}
void fragment() {
	ALBEDO = color.rgb;
}
"""


# ------------------------------------------------------- pós-processamento
const POST := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec3 lift = vec3(0.0);
uniform vec3 gain = vec3(1.0);
uniform float gamma = 1.0;
uniform float saturation = 1.08;
uniform float contrast = 1.06;
uniform float vignette = 0.38;
uniform float bloom = 0.32;
uniform float bloom_threshold = 0.62;
uniform float grain = 0.025;
uniform float aberration = 0.0012;
uniform vec3 tint : source_color = vec3(1.0);

float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dc = uv - 0.5;
	vec3 c;
	c.r = texture(screen_tex, uv + dc * aberration).r;
	c.g = texture(screen_tex, uv).g;
	c.b = texture(screen_tex, uv - dc * aberration).b;
	vec3 b = textureLod(screen_tex, uv, 2.5).rgb * 0.4 + textureLod(screen_tex, uv, 4.0).rgb * 0.35 + textureLod(screen_tex, uv, 5.5).rgb * 0.25;
	b = max(b - bloom_threshold, 0.0) / (1.0 - bloom_threshold);
	c += b * bloom;
	c = c * gain + lift * (1.0 - c);
	c = pow(max(c, vec3(0.0)), vec3(1.0 / gamma));
	c = (c - 0.5) * contrast + 0.5;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation) * tint;
	float v = smoothstep(0.85, 0.2, length(dc * vec2(1.0, 0.8)));
	c *= mix(1.0 - vignette, 1.0, v);
	c += (h(uv * 1000.0 + TIME) - 0.5) * grain;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
"""


static func terrain(cfg: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("terrain", TERRAIN)
	for k in cfg.keys():
		m.set_shader_parameter(k, cfg[k])
	return m


static func foliage(dark: Color, light: Color, wind := 0.12, key := "") -> ShaderMaterial:
	var ck := "F_%s_%s_%.2f_%s" % [dark.to_html(), light.to_html(), wind, key]
	if _cache.has(ck):
		return _cache[ck]
	var m := ShaderMaterial.new()
	m.shader = _shader("foliage", FOLIAGE)
	m.set_shader_parameter("color_dark", dark)
	m.set_shader_parameter("color_light", light)
	m.set_shader_parameter("wind", wind)
	_cache[ck] = m
	return m


static func grass(base: Color, tip: Color, fade := 60.0) -> ShaderMaterial:
	var ck := "G_%s_%s_%.0f" % [base.to_html(), tip.to_html(), fade]
	if _cache.has(ck):
		return _cache[ck]
	var m := ShaderMaterial.new()
	m.shader = _shader("grass", GRASS)
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("tip_color", tip)
	m.set_shader_parameter("fade_dist", fade)
	_cache[ck] = m
	return m


static func water(deep := Color(0.05, 0.3, 0.38), shallow := Color(0.35, 0.75, 0.8)) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("water", WATER)
	m.set_shader_parameter("deep", deep)
	m.set_shader_parameter("shallow", shallow)
	return m


static func shaft(col: Color, strength := 0.22) -> ShaderMaterial:
	var ck := "SH_%s_%.2f" % [col.to_html(), strength]
	if _cache.has(ck):
		return _cache[ck]
	var m := ShaderMaterial.new()
	m.shader = _shader("shaft", SHAFT)
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("strength", strength)
	_cache[ck] = m
	return m


static func outline(width := 0.012, col := Color(0.02, 0.015, 0.02)) -> ShaderMaterial:
	var ck := "O_%.3f_%s" % [width, col.to_html()]
	if _cache.has(ck):
		return _cache[ck]
	var m := ShaderMaterial.new()
	m.shader = _shader("outline", OUTLINE)
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("color", col)
	_cache[ck] = m
	return m


static func post() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("post", POST)
	return m
