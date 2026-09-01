shader_type spatial;
// CURVATURA DEL MUNDO ("rolling log", el efecto de Animal Crossing): la
// geometria se hunde segun se aleja del punto que mira la camara, asi que el
// mapa se lee como la superficie de un mundo redondo y lo lejano cae por
// debajo del horizonte en vez de cortarse contra el borde de la pantalla.
//
// SE CURVA A LO LARGO DEL EJE DE SCROLL, no de la profundidad de camara: esta
// camara es ORTOGONAL y el mapa es una cinta vertical, asi que lo que hay que
// doblar es la direccion por la que se navega. `centro` es el punto que la
// camara tiene enfocado y `eje` la direccion del scroll en el mundo.
//
// `world_vertex_coords` evita tener que invertir la MODEL_MATRIX por vertice.
render_mode world_vertex_coords;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 albedo_col : source_color = vec4(1.0);
uniform bool usa_tex = true;
uniform float alpha_corte = 0.5;
uniform bool recorta_alpha = false;

// LOS PARAMETROS DE LA CURVA VAN DE GLOBALES (`project.godot`,
// `[shader_globals]`): los comparten este shader y el del mar, y cambian el
// centro CADA FOTOGRAMA con el scroll. Puestos por material habria que
// escribir en 269 materiales por fotograma.
global uniform vec3 curva_centro;
global uniform vec3 curva_eje;
global uniform float curva_fuerza;
// Tope de caida: sin el, un escenario a 6.000 px se hunde kilometros y el
// motor tiene que seguir procesandolo igual.
global uniform float curva_tope;


void vertex() {
	if (curva_fuerza > 0.0) {
		float d = dot(VERTEX - curva_centro, curva_eje);
		VERTEX.y -= min(curva_fuerza * d * d, curva_tope);
	}
}


void fragment() {
	vec4 c = albedo_col;
	if (usa_tex) {
		c *= texture(albedo_tex, UV);
	}
	if (recorta_alpha && c.a < alpha_corte) {
		discard;
	}
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ROUGHNESS = 0.9;
	SPECULAR = 0.0;
}
