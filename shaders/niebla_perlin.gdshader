shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled,
	shadows_disabled, fog_disabled;

// NIEBLA DE PERLIN, portada del "Customizable Perlin Fog" de cookiemonster_nz
// (godotshaders.com, CC0).
//
// EL ORIGINAL ES `shader_type fog` Y AQUI NO PUEDE CORRER: los FogVolume son
// niebla volumetrica, que solo existe en Forward+, y este juego va en
// COMPATIBILITY. Asi que lo que se porta es su NUCLEO —el ruido de Perlin 3D
// muestreado en WORLD_POSITION y arrastrado por `movement_dir`— y se dibuja
// sobre carteles en vez de sobre froxels. El resultado se ve igual: el plano
// es una VENTANA a un campo de niebla que existe en el mundo, asi que la
// niebla se desliza por dentro del cartel en vez de moverse con el.
//
// Dos cosas del original que aqui sobran, y por que:
//  · El `gradient` (una textura para remapear la densidad) se sustituye por un
//    smoothstep entre dos umbrales: es la misma perilla de contraste sin
//    arrastrar un asset.
//  · El `colorRand` (vetas de color) pedia TRES muestreos de ruido mas por
//    pixel, y esta niebla es blanca fria de una pieza: no se porta.
//
// Y una cosa que hay que anadir: el original muere hacia el borde de su
// volumen (`fade_out_horiz`); aqui muere hacia el CANTO DEL CARTEL, con la
// distancia radial en UV. Sin eso se ve el rectangulo y se acabo el misterio.

uniform float noise_scale = 1.0;
uniform vec3 movement_dir = vec3(0.05, 0.0, 0.03);
uniform float density_mult = 0.5;
uniform vec3 albedo_color : source_color = vec3(0.84, 0.89, 0.98);
// Umbrales de densidad (el `gradient` del original): mas separados = niebla
// mas suave; mas juntos = jirones con mas cuerpo.
uniform float umbral_bajo = 0.30;
uniform float umbral_alto = 0.85;
// Desde que fraccion del radio del cartel empieza a morir la niebla.
uniform float borde = 0.45;
// Caida con la altura sobre el propio cartel (0 = sin caida). En los planos
// tumbados no hace nada —todos sus pixeles estan a la misma altura—, pero en
// los carteles de pie deshilacha la parte de arriba, que es de donde la
// niebla se escapa.
uniform float fade_alto = 0.0;
uniform float fade_dist = 1.0;
// Cartel que mira siempre a la camara. Se resuelve aqui y no con el
// `billboard_mode` de BaseMaterial3D porque eso es de los materiales
// estandar, no de los de shader.
uniform bool cartel = false;

vec3 random3D(vec3 uvw) {
	uvw = vec3(dot(uvw, vec3(127.1, 311.7, 513.7)),
		dot(uvw, vec3(269.5, 183.3, 396.5)),
		dot(uvw, vec3(421.3, 314.1, 119.7)));
	return -1.0 + 2.0 * fract(sin(uvw) * 43758.5453123);
}

float noise3D(vec3 uvw, vec3 noise_transform) {
	uvw *= noise_scale;
	uvw += noise_transform;

	vec3 gridIndex = floor(uvw);
	vec3 gridFract = fract(uvw);
	vec3 blur = smoothstep(0.0, 1.0, gridFract);

	vec3 blb = gridIndex + vec3(0.0, 0.0, 0.0);
	vec3 brb = gridIndex + vec3(1.0, 0.0, 0.0);
	vec3 tlb = gridIndex + vec3(0.0, 1.0, 0.0);
	vec3 trb = gridIndex + vec3(1.0, 1.0, 0.0);
	vec3 blf = gridIndex + vec3(0.0, 0.0, 1.0);
	vec3 brf = gridIndex + vec3(1.0, 0.0, 1.0);
	vec3 tlf = gridIndex + vec3(0.0, 1.0, 1.0);
	vec3 trf = gridIndex + vec3(1.0, 1.0, 1.0);

	float dotBLB = dot(random3D(blb), gridFract - vec3(0.0, 0.0, 0.0));
	float dotBRB = dot(random3D(brb), gridFract - vec3(1.0, 0.0, 0.0));
	float dotTLB = dot(random3D(tlb), gridFract - vec3(0.0, 1.0, 0.0));
	float dotTRB = dot(random3D(trb), gridFract - vec3(1.0, 1.0, 0.0));
	float dotBLF = dot(random3D(blf), gridFract - vec3(0.0, 0.0, 1.0));
	float dotBRF = dot(random3D(brf), gridFract - vec3(1.0, 0.0, 1.0));
	float dotTLF = dot(random3D(tlf), gridFract - vec3(0.0, 1.0, 1.0));
	float dotTRF = dot(random3D(trf), gridFract - vec3(1.0, 1.0, 1.0));

	return mix(
		mix(mix(dotBLB, dotBRB, blur.x), mix(dotTLB, dotTRB, blur.x), blur.y),
		mix(mix(dotBLF, dotBRF, blur.x), mix(dotTLF, dotTRF, blur.x), blur.y),
		blur.z) + 0.5;
}

varying vec3 mundo;
varying vec3 origen;

void vertex() {
	if (cartel) {
		// Billboard conservando la escala del nodo (si no, los jirones salen
		// todos del mismo tamano).
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2],
			MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	}
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	origen = MODEL_MATRIX[3].xyz;
}

void fragment() {
	float n = noise3D(mundo, TIME * movement_dir);
	float d = smoothstep(umbral_bajo, umbral_alto, n) * density_mult;
	// Muerte hacia el canto del cartel (el `fade_out_horiz` del original).
	float r = length(UV - vec2(0.5)) * 2.0;
	d *= 1.0 - smoothstep(borde, 1.0, r);
	if (fade_alto > 0.0) {
		d *= 1.0 - smoothstep(fade_alto, fade_alto + fade_dist,
			mundo.y - origen.y);
	}
	ALBEDO = albedo_color;
	ALPHA = clamp(d, 0.0, 1.0);
}
