shader_type canvas_item;
// BRILLO DE BOTON (UIFx.brillo): una banda de luz diagonal que cruza el
// boton cada `periodo` segundos, como el "shine" de los botones de accion
// principal de los juegos moviles (Royal Match, Cooking Fever, Clash Royale).
// Se aplica al NinePatchRect que pinta el boton y RESPETA SU ALFA, asi que la
// luz no se sale de la madera ni de la placa. La posicion sale del VERTEX
// local (en pixeles) y no de la UV: en un 9-slice la UV es la de la textura y
// la banda salia a trompicones por los tramos estirados.
uniform float periodo : hint_range(1.0, 10.0) = 3.6;
uniform float ancho : hint_range(0.02, 0.5) = 0.13;
uniform float fuerza : hint_range(0.0, 1.0) = 0.55;
uniform vec2 tam = vec2(300.0, 90.0);

varying vec2 pos;

void vertex() {
	pos = VERTEX;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float t = fract(TIME / periodo);
	// la banda cruza de izquierda a derecha en el primer tercio del periodo y
	// el resto del tiempo descansa fuera del boton
	float centro = -0.4 + t * 3.0 * 1.6;
	float x = pos.x / max(tam.x, 1.0) + 0.35 * pos.y / max(tam.y, 1.0);
	float d = abs(x - centro);
	float a = smoothstep(ancho, 0.0, d) * fuerza;
	c.rgb += a * c.a;
	COLOR = c;
}
