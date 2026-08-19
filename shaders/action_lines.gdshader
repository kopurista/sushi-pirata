// LINEAS DE ACCION de comic/anime para el TIRON del pez en la pesca.
//
// PORT del shader "Actionlines Comic - Anime" de EriNixie (godotshaders.com,
// CC0), a su vez basado en https://www.shadertoy.com/view/wsfcDM
//
// Cambios respecto al original, por lo que pide este juego:
// · Va de OVERLAY: el original MEZCLA con la textura y devuelve alfa 1, o sea
//   que tapa la pantalla entera. Aqui las lineas salen opacas y el resto
//   TRANSPARENTE, para poder ponerlo por encima del minijuego.
// · CENTRO MOVIL (`center`, en UV de pantalla): las lineas convergen en EL
//   PEZ, no en el centro del lienzo — es a el a quien hay que mirar.
// · `fade` para entrar y salir con un tween en vez de aparecer de golpe.
// · El ruido baja de 6 OCTAVAS A 4: esto se dibuja a pantalla completa y en
//   movil corre justo en el momento en que hay que pulsar rapido, asi que el
//   fotograma es lo ultimo que se puede permitir un tiron.
shader_type canvas_item;

uniform float speed : hint_range(0.0, 5.0) = 1.02;
uniform float line_length : hint_range(0.0, 4.0) = 2.18;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float softness : hint_range(0.0, 1.0) = 0.8;
uniform float weirdness : hint_range(0.0, 1.0) = 0.11;
// Radio del HUECO LIMPIO del centro. Con `line_length` alto y `softness`
// alta, las lineas salen LARGAS Y DIFUSAS y solo asoman por los bordes: es
// el ajuste suave que se quiere aqui, no el latigazo del original.
uniform float radius : hint_range(0.0, 2.0) = 2.0;
uniform float freq : hint_range(3.0, 50.0) = 10.56;
uniform vec2 center = vec2(0.5, 0.5);
uniform float fade : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 v) {
	return fract(sin(dot(v, vec2(89.44, 19.36))) * 22189.22);
}

float iHash(vec2 v, vec2 r) {
	vec4 h = vec4(
		hash(floor(v * r + vec2(0.0, 0.0)) / r),
		hash(floor(v * r + vec2(0.0, 1.0)) / r),
		hash(floor(v * r + vec2(1.0, 0.0)) / r),
		hash(floor(v * r + vec2(1.0, 1.0)) / r)
	);
	vec2 ip = smoothstep(vec2(0.0), vec2(1.0), mod(v * r, 1.0));
	return mix(mix(h.x, h.y, ip.y), mix(h.z, h.w, ip.y), ip.x);
}

float noise(vec2 v) {
	float sum = 0.0;
	for (int i = 1; i < 5; i++) {
		sum += iHash(v + vec2(float(i)),
			vec2(2.0 * pow(2.0, float(i)))) / pow(2.0, float(i));
	}
	return sum;
}

void fragment() {
	if (fade <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		// Centrado en el PEZ. La escala es la del original (-1..1 en los
		// DOS ejes, sin corregir aspecto): los parametros vienen afinados
		// contra ella, y corrigiendo el aspecto un `radius` de 2.0 dejaba
		// la pantalla sin una sola linea.
		vec2 uv = (UV - center) * 2.0;
		vec2 puv = vec2(weirdness * length(uv) + speed * TIME,
			freq * atan(uv.y, uv.x));
		float value = noise(puv);
		value = length(uv) - radius - line_length * (value - 0.5);
		value = smoothstep(-softness, softness, value);
		COLOR = vec4(line_color.rgb, value * line_color.a * fade);
	}
}
