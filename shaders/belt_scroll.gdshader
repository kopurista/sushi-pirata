shader_type canvas_item;
// Desplaza la textura de la cinta a lo largo del recorrido para que la banda
// se mueva a la vez que los platos. El nivel actualiza scroll_offset cada frame.
uniform float scroll_offset = 0.0;

void fragment() {
	COLOR = texture(TEXTURE, vec2(UV.x - scroll_offset, UV.y));
}
