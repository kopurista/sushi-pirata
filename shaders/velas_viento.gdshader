shader_type spatial;
// LAS VELAS SE HINCHAN CON EL VIENTO (pedido por el usuario).
//
// EL BARCO ES UNA SOLA MALLA CON UN SOLO MATERIAL: no hay un nodo "vela" que
// inclinar, asi que la vela se reconoce POR COLOR, muestreando el albedo en el
// vertice. Medido sobre `map_barco_0.png`: el 21% del atlas pasa de 170 de
// luminancia y ese 21% es blanco (217,215,214) — la lona; la madera queda muy
// por debajo. Es la misma idea con la que `atlas_fix.py` distingue las velas
// para repintarlas, solo que aqui se usa para DEFORMARLAS.
//
// Y SE HINCHA HACIA DONDE EMPUJA EL VIENTO, con TODA la lona moviendose en la
// MISMA direccion. Se probo antes a combarla a lo largo de su NORMAL —que es
// como se comba una vela de verdad— y NO VALE en una malla facetada y
// decimada: cada cara tiene su normal, asi que los vertices vecinos se van a
// un lado distinto y el barco se DESHACE EN ESQUIRLAS (se vio en captura).
// `empuje` llega en coordenadas del MODELO, y lo calcula `level_select3d`
// pasando la direccion del viento por la inversa de la base del barco: asi
// vale para cualquier rumbo sin tener que averiguar cual es la proa.
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 albedo_col : source_color = vec4(1.0);
// Cuanto se hincha (0 = en calma). Lo escribe `level_select3d` con la fuerza
// del viaje: mucho si es largo, poco si es de un escenario al de al lado.
uniform float fuerza = 0.0;
// Umbrales de "esto es lona". Van con holgura entre la madera y la vela.
uniform float vela_min = 0.58;
uniform float vela_max = 0.74;
uniform vec3 empuje = vec3(0.0, 0.0, 1.0);


void vertex() {
	if (fuerza > 0.001) {
		vec3 c = textureLod(albedo_tex, UV, 0.0).rgb;
		float lona = smoothstep(vela_min, vela_max, dot(c, vec3(0.3333)));
		// La comba no es uniforme: ondula despacio a lo alto del paño, como una
		// lona que respira con la racha.
		// LA COMBA VA MUY DESIGUAL A LO ALTO DEL PAÑO, y eso es lo que se ve:
		// con un empuje parejo la vela se limita a DESPLAZARSE (y encima se
		// despega de su verga), mientras que moviendo mucho el centro y poco
		// los extremos la lona se CURVA, que es lo que se lee como hinchada.
		float alto = clamp(VERTEX.y * 1.9, -1.0, 1.0);
		float panza = 1.0 - alto * alto;
		float onda = 0.75 + 0.25 * sin(TIME * 2.0 + VERTEX.y * 2.4);
		VERTEX += empuje * lona * fuerza * panza * onda;
	}
}


void fragment() {
	vec4 c = texture(albedo_tex, UV) * albedo_col;
	ALBEDO = c.rgb;
	ROUGHNESS = 0.95;
	SPECULAR = 0.0;
}
