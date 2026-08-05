shader_type canvas_item;
// Foco del tutorial: oscurece toda la pantalla salvo un CÍRCULO con borde
// difuminado en degradado. Lo usa tutorial_director sobre un ColorRect a
// pantalla completa; center/radius van en píxeles de diseño (720x1280).

uniform vec2 center = vec2(360.0, 640.0);
uniform float radius = 150.0;
uniform float feather = 130.0;
uniform float dim : hint_range(0.0, 1.0) = 0.78;

void fragment() {
	vec2 p = UV * vec2(720.0, 1280.0);
	float d = distance(p, center);
	float a = smoothstep(radius, radius + feather, d) * dim;
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
