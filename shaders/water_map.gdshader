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
	// Deriva lenta: el mar avanza hacia arriba, como si el barco navegara.
	uv += vec2(T * drift_speed * 0.5, -T * drift_speed);
	// Ondulación cruzada para que el agua no sea un simple desplazamiento.
	uv.x += sin(uv.y * wave_freq + T * wave_speed) * wave_amp;
	uv.y += cos(uv.x * wave_freq * 0.8 + T * wave_speed * 0.75) * wave_amp;
	COLOR = texture(TEXTURE, uv);
}
