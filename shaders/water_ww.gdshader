// EL MAR DEL JUEGO, al estilo Wind Waker.
//
// Portado de "Wind Waker style water (no textures needed)" de NekotoArts
// (godotshaders.com), que a su vez viene de shadertoy.com/view/3tKBDz. Se
// conserva su matemática: el warp con fbm, la distorsión con dos senos
// cruzados y las TRES capas de color (agua, agua oscura y espuma) que salen de
// mezclar el mismo patrón consigo mismo del revés.
//
// DOS CAMBIOS, los dos por el móvil:
//  1. La capa de espuma va HORNEADA en una textura (`tools/foam_ww.py`). El
//     original la construye sumando 75 círculos POR PÍXEL y la evalúa DOS
//     veces por fragmento: unas 2.500 operaciones por píxel, con el mar
//     cubriendo la pantalla entera. El dibujo no depende del tiempo y tilea
//     solo, así que hornearlo da el MISMO resultado por dos texture().
//  2. El fbm baja de 6 octavas a 3: a la escala a la que se ve el mar aquí,
//     las tres últimas no se distinguen.
shader_type spatial;
render_mode specular_disabled;

uniform vec4 WATER_COL : source_color = vec4(0.05, 0.21, 0.48, 1.0);
uniform vec4 WATER2_COL : source_color = vec4(0.07, 0.27, 0.58, 1.0);
uniform vec4 FOAM_COL : source_color = vec4(0.60, 0.80, 0.90, 1.0);
/// Cuánta espuma se deja ver. El dibujo horneado cubre ~1/3 del mar y a
/// plena fuerza el agua se lee como una vaca; a 0.8 sigue siendo espuma.
uniform float foam_amount : hint_range(0.0, 1.0) = 0.72;
uniform sampler2D espuma : hint_default_white, filter_linear_mipmap, repeat_enable;
/// Cuántas veces se repite el dibujo a lo largo del plano (x0.25 por dentro,
/// como en el original).
uniform vec2 tile = vec2(40.0, 40.0);
uniform float distortion_speed = 1.1;
/// Oleaje del VÉRTICE: el plano necesita subdivisiones o no se nota.
uniform float height = 0.10;
uniform vec2 wave_size = vec2(6.0, 6.0);
uniform float wave_speed = 0.9;
/// LA MAREA: el mapa se la pasa cada fotograma. Sube y baja el plano entero,
/// así que el agua le trepa por la roca a las islas (que no se mueven) y los
/// barcos suben con ella (el mapa les suma esta misma altura).
uniform float marea = 0.0;

const float M_2PI = 6.283185307;
const float M_6PI = 18.84955592;

float random(vec2 uv) {
	return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 uv) {
	vec2 uv_index = floor(uv);
	vec2 uv_fract = fract(uv);
	float a = random(uv_index);
	float b = random(uv_index + vec2(1.0, 0.0));
	float c = random(uv_index + vec2(0.0, 1.0));
	float d = random(uv_index + vec2(1.0, 1.0));
	vec2 blur = smoothstep(0.0, 1.0, uv_fract);
	return mix(a, b, blur.x) + (c - a) * blur.y * (1.0 - blur.x)
		+ (d - b) * blur.x * blur.y;
}

float fbm(vec2 uv) {
	float amplitude = 0.5;
	float frequency = 3.0;
	float value = 0.0;
	for (int i = 0; i < 3; i++) {
		value += amplitude * noise(frequency * uv);
		amplitude *= 0.5;
		frequency *= 2.0;
	}
	return value;
}

/// La distorsión que mueve el dibujo del agua (y, en el vértice, la ola).
vec2 vaiven(vec2 uv, float t) {
	float d1 = mod(uv.x + uv.y, M_2PI);
	float d2 = mod((uv.x + uv.y + 0.25) * 1.3, M_6PI);
	d1 = t * 0.07 + d1;
	d2 = t * 0.5 + d2;
	return vec2(sin(d1) * 0.15 + sin(d2) * 0.05,
		cos(d1) * 0.15 + cos(d2) * 0.05);
}

void vertex() {
	VERTEX.y += vaiven(UV * wave_size, TIME * wave_speed).y * height + marea;
}

void fragment() {
	float t = TIME * distortion_speed;
	vec2 uv = UV * tile * 0.25;
	uv += fbm(uv) * 0.2;
	vec2 dist = vaiven(uv, t);
	vec3 col = mix(WATER_COL.rgb, WATER2_COL.rgb, texture(espuma, uv + dist).r);
	col = mix(col, FOAM_COL.rgb,
		texture(espuma, vec2(1.0) - uv - dist.yx).r * foam_amount);
	ALBEDO = col;
	ROUGHNESS = 0.78;
	METALLIC = 0.0;
}
