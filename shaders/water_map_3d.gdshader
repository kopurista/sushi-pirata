shader_type spatial;
render_mode specular_disabled;
// Version 3D del mar del mapa de niveles (water_map.gdshader): la textura del
// agua se repite por el plano del mar, deriva lentamente en diagonal y ondula
// con dos senos desfasados. Mismo movimiento y parametros que la version 2D;
// el mar NO se anima con sprites (decision documentada en CLAUDE.md).

uniform sampler2D sea_tex : source_color, filter_linear, repeat_enable;
// Cuantas veces se repite la textura a lo largo y ancho del plano.
uniform vec2 tile_scale = vec2(8.0, 8.0);
uniform float drift_speed = 0.030;
uniform float wave_amp = 0.018;
uniform float wave_freq = 5.0;
uniform float wave_speed = 0.85;
// Tinte que en el 2D aplicaba el modulate del TextureRect.
uniform vec3 tint = vec3(0.72, 0.82, 0.98);
// La textura voxel del agua tiene un enrejado de rombos muy contrastado que a
// esta escala lee como una colcha: se APLANA mezclandola con un azul de mar
// profundo y dejando solo un destello sutil del mosaico en movimiento.
uniform vec3 deep_color = vec3(0.13, 0.28, 0.50);
uniform float flatten = 0.72;

// La animacion del agua avanza a ANIM_FPS pasos por segundo en vez de a cada
// fotograma: el mar es una superficie enorme y a 60 su vaiven no aporta nada
// que se note, mientras que a 30 el movimiento se lee igual. Se cuantiza el
// TIEMPO, no el dibujado, asi que el coste por pixel es el mismo: lo que se
// gana es que la textura deja de recalcularse dos veces por paso visible y el
// agua deja de "hervir" en pantallas de alto refresco.
uniform float anim_fps = 30.0;

void fragment() {
	float T = floor(TIME * anim_fps) / anim_fps;
	vec2 uv = UV * tile_scale;
	uv += vec2(T * drift_speed * 0.5, -T * drift_speed);
	uv.x += sin(uv.y * wave_freq + T * wave_speed) * wave_amp;
	uv.y += cos(uv.x * wave_freq * 0.8 + T * wave_speed * 0.75) * wave_amp;
	ALBEDO = mix(texture(sea_tex, uv).rgb * tint, deep_color, flatten);
	ROUGHNESS = 0.85;
	METALLIC = 0.0;
}
