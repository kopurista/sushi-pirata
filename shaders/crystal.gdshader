// CRISTAL DE LA CUEVA. Inspirado en el "Crystal Shader" de godotshaders.com:
// color por gradiente a lo largo de la pieza, transparencia y especular
// modulados por ruido. Aqui va todo PROCEDIMENTAL (sin texturas de ruido) y
// con FRESNEL, que es lo que de verdad lo hace leer como cristal desde esta
// camara: los cantos se encienden y el cuerpo deja ver el fondo.
//
// La LUZ que reparte por la cueva NO sale de aqui: cada cristal lleva ademas
// su OmniLight3D (`level3d._cristal`). La emision es el cuerpo brillante; la
// luz de verdad es la que pinta el suelo y a los clientes.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec3 color_base : source_color = vec3(0.06, 0.40, 0.42);
uniform vec3 color_punta : source_color = vec3(0.52, 1.0, 0.90);
uniform vec3 color_luz : source_color = vec3(0.22, 0.88, 0.66);
/// Media altura del prisma en coordenadas locales (la pone quien lo crea).
uniform float media_altura = 0.7;
uniform float brillo = 1.15;
uniform float alfa = 0.74;
uniform float fresnel_pow = 2.6;
/// 0 = sin latido (ajuste de "Animaciones" apagado).
uniform float pulso = 0.10;
uniform float veta = 0.40;

varying float v_alto;
varying vec3 v_mundo;

float hash13(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.11, 0.27, 0.53));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float ruido(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

void vertex() {
	v_alto = clamp(VERTEX.y / (2.0 * media_altura) + 0.5, 0.0, 1.0);
	v_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), fresnel_pow);
	float n = ruido(v_mundo * 5.5);
	// Gradiente a lo largo del cristal + vetas: la punta es la parte clara.
	float grad = clamp(v_alto * 1.2 - 0.12 + (n - 0.5) * veta, 0.0, 1.0);
	float latido = 1.0 + pulso * sin(TIME * 1.6 + v_mundo.x * 2.1 + v_mundo.z * 1.3);
	ALBEDO = mix(color_base, color_punta, grad);
	ALPHA = clamp(alfa + fres * 0.42 + grad * 0.12, 0.0, 1.0);
	EMISSION = color_luz * (0.30 + grad * 0.55 + fres * 0.45) * brillo * latido;
	ROUGHNESS = 0.10 + n * 0.12;
	SPECULAR = 0.85;
	METALLIC = 0.0;
}
