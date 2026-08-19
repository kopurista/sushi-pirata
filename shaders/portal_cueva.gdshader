// LA LUZ QUE ENTRA POR LA BOCA DE LA CUEVA: una "tarjeta de portal" al estilo
// N64 — un plano plano y sin sombrear, metido en la garganta del túnel, que se
// ve a través del hueco irregular de la entrada y hace de día lejano.
//
// Referencia: "Portal Card (N64 Entrance)" de godotshaders.com (sweetbabyalaska,
// CC0). El original resuelve el borde leyendo la PROFUNDIDAD de la pantalla
// (`hint_depth_texture`), y este juego se dibuja con el renderer COMPATIBILITY,
// que no sirve esa textura: el borde se funde aquí con la propia UV de la
// tarjeta, que para una boca fija como esta da el mismo resultado y cuesta
// cuatro instrucciones.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.56, 0.75, 0.99, 1.0);
/// Cuánta luz entra. OJO: es una boca al fondo de una cueva, no un foco.
uniform float fuerza : hint_range(0.0, 1.0) = 0.42;
/// Anchura del fundido del borde (1 = todo degradado).
uniform float borde : hint_range(0.05, 1.0) = 0.55;
uniform float latido = 0.05;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// Óvalo con el canto fundido: la tarjeta no puede tener bordes rectos o se
	// ve el rectángulo detrás de la roca.
	float d = length(vec2(p.x * 1.25, p.y));
	float a = 1.0 - smoothstep(1.0 - borde, 1.0, d);
	// MAS VIVA POR ABAJO, que es por donde se ve: lo de arriba de la tarjeta
	// queda detrás del dintel, y la luz tiene que encenderse justo sobre la
	// línea del suelo del pasadizo.
	a *= mix(0.42, 1.0, clamp(UV.y, 0.0, 1.0));
	float t = 1.0 + latido * sin(TIME * 0.6);
	ALBEDO = color.rgb;
	ALPHA = clamp(a * fuerza * t, 0.0, 1.0);
}
