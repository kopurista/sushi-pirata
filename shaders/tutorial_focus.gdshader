shader_type canvas_item;
// Foco de los guiones: oscurece toda la pantalla salvo una ELIPSE con borde
// difuminado en degradado. Lo usa story_director sobre un ColorRect a pantalla
// completa; center/radius van en pixeles de LIENZO.
//
// El radio es un vec2 a proposito: la fila de recetas es mucho mas ancha que
// alta, y con un circulo que la cubriera entera el foco se comia media tabla de
// elaboracion.
//
// `screen` TIENE que llegar con el tamano real del lienzo. Estaba clavado a
// 720x1280 y en un movil (lienzo ~720x1560 por el aspect expand) el UV se
// multiplicaba por el alto equivocado, asi que el foco caia muy por encima de
// lo que senalaba.

uniform vec2 center = vec2(360.0, 640.0);
uniform vec2 radius = vec2(150.0, 150.0);
uniform float feather = 130.0;
uniform float dim : hint_range(0.0, 1.0) = 0.0;
uniform vec2 screen = vec2(720.0, 1280.0);

void fragment() {
	vec2 p = UV * screen;
	vec2 r = max(radius, vec2(1.0));
	// Distancia NORMALIZADA: 1.0 justo en el borde de la elipse.
	float d = length((p - center) / r);
	// El difuminado se mide sobre el eje menor, para que se vea del mismo
	// grosor por todo el contorno.
	float f = max(feather / max(min(r.x, r.y), 1.0), 0.001);
	float a = smoothstep(1.0, 1.0 + f, d) * dim;
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
