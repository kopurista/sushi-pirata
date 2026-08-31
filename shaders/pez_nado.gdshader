shader_type canvas_item;

// EL NADO DE UN PEZ DE LA PECERA: ondulación de cola sobre el propio sprite.
// La amplitud crece hacia la COLA (los iconos del álbum miran a la
// IZQUIERDA, así que la cola es u = 1) y la cabeza apenas se mueve, que es
// como nada un pez de verdad. Cada especie trae sus perillas: una anguila
// lleva `ondas` altas y mucha `amp`, un tiburón casi nada, la basura cero.
//
// `voltear` acompaña al flip_h del nodo: con el sprite volteado la cola pasa
// al otro lado de la UV y sin esto el que nadaba hacia la derecha batía la
// CABEZA en vez de la cola.

uniform float amp = 0.030;
uniform float ondas = 1.6;
uniform float vel = 3.2;
uniform float fase = 0.0;
uniform float voltear = 0.0;

void fragment() {
	float u = mix(UV.x, 1.0 - UV.x, voltear);
	float fuerza = mix(0.12, 1.0, u * u);
	float onda = sin(u * ondas * TAU - TIME * vel + fase);
	// La Y se comprime un pelo para que la onda nunca muerda el borde del
	// sprite (sin esto las aletas se cortaban en el pico del vaivén).
	vec2 uv = UV;
	uv.y = 0.5 + (UV.y - 0.5) * (1.0 + 2.4 * amp) + onda * amp * fuerza;
	if (uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, uv);
	}
}
