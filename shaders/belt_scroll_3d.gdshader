shader_type spatial;
render_mode specular_disabled;
// Version 3D del belt_scroll: desplaza la textura de la banda a lo largo del
// tramo (UV.x) para que se mueva a la vez que los platos del Path3D.
// Cada tramo es un PlaneMesh orientado con su +X local en el sentido de la
// marcha, asi el desplazamiento siempre es positivo.
//
// repeat_x     = cuantas veces se repite la textura a lo largo del tramo.
// scroll_tiles = desplazamiento acumulado en tiles. Lo empuja level3d.gd cada
//                fotograma en vez de usar TIME: asi la banda se para al
//                congelar el nivel y acelera con el potenciador "Cinta rapida",
//                siempre a la velocidad real de los platos.
uniform sampler2D band_tex : source_color, filter_linear, repeat_enable;
uniform float repeat_x = 4.0;
uniform float scroll_tiles = 0.0;

void fragment() {
	vec2 uv = vec2(UV.x * repeat_x - scroll_tiles, UV.y);
	vec4 tex = texture(band_tex, uv);
	ALBEDO = tex.rgb;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
}
