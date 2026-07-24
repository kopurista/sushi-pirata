shader_type spatial;
render_mode specular_disabled;
// Version 3D del belt_scroll: desplaza la textura de la banda a lo largo del
// tramo (UV.x) para que se mueva a la vez que los platos del Path3D.
// Cada tramo es un PlaneMesh orientado con su +X local en el sentido de la
// marcha, asi el desplazamiento siempre es positivo.
//
// repeat_x      = cuantas veces se repite la textura a lo largo del tramo.
// tiles_per_sec = PLATE_SPEED / longitud_mundo_de_un_tile (se calcula en
//                 level3d.gd para que la banda avance igual que los platos).
uniform sampler2D band_tex : source_color, filter_linear, repeat_enable;
uniform float repeat_x = 4.0;
uniform float tiles_per_sec = 1.0;

void fragment() {
	vec2 uv = vec2(UV.x * repeat_x - tiles_per_sec * TIME, UV.y);
	vec4 tex = texture(band_tex, uv);
	ALBEDO = tex.rgb;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
}
