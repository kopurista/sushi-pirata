shader_type canvas_item;
// Mar animado del mapa de niveles: la textura voxel del agua se repite por todo
// el lienzo, deriva lentamente en diagonal y ondula con dos senos desfasados,
// para un movimiento continuo, suave y sin cortes.

// Cuántas veces se repite la textura a lo ancho y a lo alto del lienzo.
uniform vec2 tile_scale = vec2(2.0, 4.5);
// Velocidad de la deriva general del oleaje.
uniform float drift_speed = 0.030;
// Amplitud y frecuencia de la ondulación (en unidades de UV de tile).
uniform float wave_amp = 0.018;
uniform float wave_freq = 5.0;
uniform float wave_speed = 0.85;

void fragment() {
	vec2 uv = UV * tile_scale;
	// Deriva lenta: el mar avanza hacia arriba, como si el barco navegara.
	uv += vec2(TIME * drift_speed * 0.5, -TIME * drift_speed);
	// Ondulación cruzada para que el agua no sea un simple desplazamiento.
	uv.x += sin(uv.y * wave_freq + TIME * wave_speed) * wave_amp;
	uv.y += cos(uv.x * wave_freq * 0.8 + TIME * wave_speed * 0.75) * wave_amp;
	COLOR = texture(TEXTURE, uv);
}
