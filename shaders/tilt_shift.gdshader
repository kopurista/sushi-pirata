shader_type canvas_item;
render_mode unshaded;

// TILT-SHIFT CIRCULAR: deja nitido un CIRCULO en el centro de la accion y
// desenfoca hacia fuera en todas las direcciones. Es lo que hace que el mundo
// parezca una maqueta — el truco del remake de Link's Awakening.
//
// Empezo siendo una banda horizontal (nitido en medio, borroso arriba y
// abajo) y se paso a circular porque el corte recto se notaba: con una banda,
// las esquinas de la franja nitida quedaban tan afiladas como el centro y el
// ojo encontraba la linea. En redondo no hay linea que encontrar.
//
// NO es profundidad de campo de verdad y no lo pretende: el desenfoque va por
// la POSICION EN PANTALLA, no por la distancia a la camara. Ademas la
// profundidad de campo del Environment de Godot NO existe bajo GL
// Compatibility, que es el renderer de este juego.
//
// El desenfoque se pide como MIPMAP de la pantalla (`textureLod`), no con una
// tanda de muestreos: son dos texturas por pixel en vez de nueve o mas, y esto
// corre a pantalla completa en un movil. MEDIDO: +0,07 ms/fotograma.

uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;

// Centro del circulo nitido, en fracciones de pantalla.
uniform vec2 foco_centro = vec2(0.5, 0.52);
// Radio de lo que se queda nitido del todo, en fracciones del ANCHO.
uniform float foco_radio : hint_range(0.0, 1.5) = 0.42;
// Cuanto tarda en llegar al desenfoque maximo saliendo del circulo.
uniform float caida : hint_range(0.01, 1.0) = 0.38;
// Desenfoque maximo, en niveles de mipmap.
uniform float fuerza : hint_range(0.0, 6.0) = 1.7;
// ALTO / ANCHO del lienzo. Sin esto el circulo sale ELIPSE: la pantalla del
// juego es 720x1280, asi que un radio igual en UV mide casi el doble en
// vertical. Lo rellena `TiltShift.montar` con el lienzo de verdad.
uniform float aspecto = 1.777;

void fragment() {
	vec2 d = SCREEN_UV - foco_centro;
	d.y *= aspecto;
	float k = smoothstep(foco_radio, foco_radio + caida, length(d));
	COLOR = textureLod(pantalla, SCREEN_UV, k * fuerza);
}
