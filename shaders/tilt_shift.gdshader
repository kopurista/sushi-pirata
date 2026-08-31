shader_type canvas_item;
render_mode unshaded;

// TILT-SHIFT: desenfoca los bordes de ARRIBA y de ABAJO y deja nitida una
// banda horizontal. Es lo que hace que el mundo parezca una maqueta —
// el truco del remake de Link's Awakening.
//
// NO es profundidad de campo de verdad y no lo pretende: el desenfoque va por
// la POSICION EN PANTALLA, no por la distancia a la camara. Eso es justo lo
// que describe el efecto ("desenfoque en los bordes superior e inferior"), y
// ademas la profundidad de campo del Environment de Godot NO existe bajo GL
// Compatibility, que es el renderer de este juego.
//
// El desenfoque se hace pidiendo MIPMAPS de la pantalla (`textureLod`), no con
// una tanda de muestreos: son dos texturas por pixel en vez de nueve o mas, y
// esto corre a pantalla completa en un movil.

uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;

// Centro de la banda nitida, en fraccion del alto (0 arriba, 1 abajo).
uniform float foco_centro : hint_range(0.0, 1.0) = 0.52;
// Media altura de la banda que se queda nitida del todo.
uniform float foco_alto : hint_range(0.0, 0.5) = 0.16;
// Cuanto tarda en llegar al desenfoque maximo, saliendo de la banda.
uniform float caida : hint_range(0.01, 0.6) = 0.26;
// Desenfoque maximo, en niveles de mipmap.
uniform float fuerza : hint_range(0.0, 6.0) = 2.6;
// Los bordes se pueden desenfocar distinto: una maqueta se mira desde arriba,
// asi que el borde de ABAJO (lo que esta mas cerca) suele ir mas suave.
uniform float peso_arriba : hint_range(0.0, 2.0) = 1.0;
uniform float peso_abajo : hint_range(0.0, 2.0) = 0.85;

void fragment() {
	float d = SCREEN_UV.y - foco_centro;
	float peso = d < 0.0 ? peso_arriba : peso_abajo;
	float k = smoothstep(foco_alto, foco_alto + caida, abs(d)) * peso;
	COLOR = textureLod(pantalla, SCREEN_UV, k * fuerza);
}
