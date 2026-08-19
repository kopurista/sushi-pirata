// MAR DE CARICATURA ("Toon Water Shader" de godotshaders.com, port a su vez
// del de Erik Roystan Ross). Dos ideas: el color del agua sale de la
// PROFUNDIDAD (claro donde hay poco fondo, oscuro donde hay mucho) y la ESPUMA
// aparece justo donde algo corta la superficie — la orilla de las islas, el
// casco de los barcos —, con su borde ondulado por un segundo ruido.
//
// Portado a Godot 4 (`hint_color` -> `source_color`, DEPTH_TEXTURE declarada
// como uniforme) y con las dos texturas de ruido dibujadas por
// `tools/toon_water_tex.py`.
//
// OJO: esto NECESITA leer la profundidad de pantalla. Si el renderer no la
// sirve, `profundidad_ok` se pone a false y el agua cae a un modo plano (color
// medio + espuma por ruido), que es feo pero no revienta.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled;

const float SMOOTHSTEP_AA = 0.01;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D ruido_espuma : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D ruido_distor : source_color, filter_linear_mipmap, repeat_enable;

uniform float beer_factor = 0.8;
uniform float foam_max_distance = 0.4;
uniform float foam_min_distance = 0.04;
uniform vec4 foam_color : source_color = vec4(1.0);

uniform vec2 surface_noise_tiling = vec2(12.0, 12.0);
uniform vec2 surface_noise_scroll = vec2(0.012, 0.009);
uniform float surface_noise_cutoff : hint_range(0.0, 1.0) = 0.74;
uniform float surface_distortion_amount : hint_range(0.0, 1.0) = 0.22;
uniform vec2 distort_tiling = vec2(4.0, 4.0);

uniform vec4 agua_baja : source_color = vec4(0.32, 0.78, 0.95, 1.0);
uniform vec4 agua_honda : source_color = vec4(0.07, 0.33, 0.72, 1.0);
uniform float profundidad_max = 1.4;

/// Oleaje del vertice, como en el otro mar (el plano va subdividido).
uniform float height = 0.10;
uniform vec2 wave_size = vec2(6.0, 6.0);
uniform float wave_speed = 0.9;

varying vec2 noiseUV;
varying vec2 distortUV;
varying vec3 viewNormal;

vec4 alphaBlend(vec4 top, vec4 bottom) {
	vec3 color = (top.rgb * top.a) + (bottom.rgb * (1.0 - top.a));
	float alpha = top.a + bottom.a * (1.0 - top.a);
	return vec4(color, alpha);
}

void vertex() {
	float t = TIME * wave_speed;
	vec2 uv = UV * wave_size;
	float d1 = mod(uv.x + uv.y, 6.283185307);
	float d2 = mod((uv.x + uv.y + 0.25) * 1.3, 18.84955592);
	VERTEX.y += (cos(t * 0.07 + d1) * 0.15 + cos(t * 0.5 + d2) * 0.05) * height;
	viewNormal = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	noiseUV = UV * surface_noise_tiling;
	distortUV = UV * distort_tiling;
}

void fragment() {
	// Profundidad de lo que hay DETRAS del agua, en metros por delante del
	// plano, pasada por Beer-Lambert.
	float depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float linear_depth = -upos.z / upos.w;
	float dist = linear_depth + VERTEX.z;
	float fondo = 1.0 - exp(-dist * beer_factor);

	// Cuanto mas de canto se ve la superficie, mas ancha la orla de espuma.
	vec3 existingNormal = vec3(dFdx(fondo), dFdy(fondo), 0.0);
	float normalDot = clamp(dot(existingNormal, viewNormal), 0.0, 1.0);
	float foamDistance = mix(foam_max_distance, foam_min_distance, normalDot);
	float foamDepth = clamp(fondo / foamDistance, 0.0, 1.0);
	float corte = foamDepth * surface_noise_cutoff;

	vec2 distorAmount = (texture(ruido_distor, distortUV).xy * 2.0 - 1.0)
		* surface_distortion_amount;
	vec2 uv_e = noiseUV + TIME * surface_noise_scroll + distorAmount;
	float muestra = texture(ruido_espuma, uv_e).r;
	float espuma = smoothstep(corte - SMOOTHSTEP_AA, corte + SMOOTHSTEP_AA, muestra);

	float wd = clamp(fondo / profundidad_max, 0.0, 1.0);
	vec4 color_agua = mix(agua_baja, agua_honda, wd);
	vec4 col_espuma = foam_color;
	col_espuma.a *= espuma;
	vec4 col = alphaBlend(col_espuma, color_agua);

	ALBEDO = col.rgb;
	ALPHA = 1.0;
	ROUGHNESS = 0.78;
	METALLIC = 0.0;
}
