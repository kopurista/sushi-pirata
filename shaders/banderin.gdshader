shader_type spatial;
render_mode cull_disabled, shadows_disabled, specular_disabled;

// EL BANDERIN DEL VIENTO (mar 2). La tela ondea por VERTICE: una onda que
// viaja del asta a la punta, con amplitud proporcional a la FUERZA del viento
// que le pasa level3d cada fotograma. El asta (UV.x = 0) queda clavada y la
// punta es la que se agita — el factor UV.x * UV.x es lo que hace que la onda
// crezca hacia el extremo libre, como una tela de verdad.
//
// Con el viento en calma la tela ademas CUELGA (el `caida`): un banderin
// planchado y quieto parecia de hojalata.

uniform sampler2D tela : source_color, filter_linear;
// Fuerza del viento, 0..1. La pone level3d desde su simulador.
uniform float fuerza = 0.5;

void vertex() {
	float u = UV.x;
	float amp = (0.06 + 0.30 * fuerza) * u * u;
	float vel = 4.0 + 9.0 * fuerza;
	VERTEX.z += sin(TIME * vel + u * 7.0) * amp;
	VERTEX.z += sin(TIME * vel * 1.7 + u * 13.0) * amp * 0.35;
	// La caida en calma: la punta se descuelga cuando no sopla nada.
	VERTEX.y -= (1.0 - clamp(fuerza * 2.5, 0.0, 1.0)) * 0.30 * u * u;
}

void fragment() {
	vec4 t = texture(tela, UV);
	if (t.a < 0.5) {
		discard;
	}
	ALBEDO = t.rgb;
	ROUGHNESS = 0.9;
}
