class_name SceneryLA
extends RefCounted
## ESCENARIOS EN ESTILO LINK'S AWAKENING (7-9-2026, pedido por el usuario): los
## props son conceptos de Ludo pasados por Meshy (`assets/models/la_*.glb`),
## las texturas de suelo salen de Ludo (`assets/props/la_*.webp`, tileables) y
## el mostrador de la cinta es un anillo biselado hecho en Blender
## (`la_mostrador.glb`, `tools/blender/la_mostrador.py`). Se monta desde
## level3d con el interruptor `ESTILO_LA`; con el apagado vuelve todo lo de
## antes sin tocar nada mas.
##
## Cada escenario REPLICA su concepto (`_gen/la_esc/concepto_*.webp`): isla
## redonda de arena clara con parches de hierba, palmeras de tronco escamado,
## rocas con musgo, cabaña de paja, barriles y cajas; muelle de tablones
## claros con norays, farola, cajas apiladas, redes y una caseta de tejado
## azul; cubierta oscura con mastil de velas rasgadas, barandillas rotas,
## cañon y cabos; cueva de adoquin azul con estalagmitas y cristales verdes.

const ON := true
const DIR := "res://assets/models/"
## Las paredes de la cueva, montadas y horneadas en Blender
## (`tools/blender/cueva_escenario.py`).
const CUEVA_GLB := DIR + "la_cueva_escenario.glb"
const TEX := "res://assets/props/"
## Tinte de los cabos enrollados: el modelo de Meshy sale color crema y en
## cubierta se leia como un bollo; a cañamo tostado se lee como cuerda.
const CABO := Color(0.80, 0.64, 0.46)


## Material triplanar con una textura tileable de Ludo. `escala` son
## repeticiones por unidad de mundo.
static func mat_tex(nombre: String, tinte: Color, escala: float, rough := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var ruta := TEX + "la_%s.webp" % nombre
	if ResourceLoader.exists(ruta):
		m.albedo_texture = load(ruta)
	m.albedo_color = tinte
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(escala, escala, escala)
	m.roughness = rough
	m.metallic = 0.0
	return m


## COORDENADAS DE PANTALLA (u a la derecha, w hacia abajo), las mismas que
## `level3d._uw`. TODO EL DECORADO SE COLOCA ASI, no en x/z de mundo: con la
## camara a yaw 45 los ejes del mundo salen en diagonal y a ojo la mitad de los
## props caian bajo el HUD o fuera de cuadro (medido en la primera tanda: dos
## de las cuatro palmeras de la isla y el arbol entero estaban fuera de la
## pantalla). Lo que se ve: |u| <= 4.78, w de -7.8 (bajo el HUD) a 5.8 (la
## tabla); el pasillo de la clientela es el circulo de radio 3.7 y los dos
## corredores de entrada van por |u| < 1 (arriba w < -3.5, abajo w > 3.4).
## Un prop se dibuja hacia ARRIBA desde su base: 61.5 px por unidad de alto, y
## el suelo baja 43.5 px por unidad de w, asi que la cima de un prop cae en
## y = (w + 10.1) * 43.5 - 61.5 * alto, que tiene que quedar por debajo del
## HUD (y >= 100). Y el boton "Salir" ocupa x 20-125, y 110-160.
static func uw(u: float, w: float) -> Vector3:
	return Vector3(0.70710678, 0.0, -0.70710678) * u \
		+ Vector3(0.70710678, 0.0, 0.70710678) * w


## Un prop a escala de mundo (por su ALTO), con mancha de sombra opcional y un
## tinte que MULTIPLICA su textura (para levantar un modelo que en el sitio
## sale apagado, como las rocas de la cueva).
static func prop(lv: Node3D, id: String, pos: Vector3, alto: float, yaw := 0.0,
		sombra := Vector2.ZERO, tinte := Color(1.0, 1.0, 1.0)) -> Node3D:
	var ruta := DIR + "la_%s.glb" % id
	if not ResourceLoader.exists(ruta):
		push_warning("SceneryLA: falta " + ruta)
		return null
	var n: Node3D = lv._spawn_model(load(ruta), pos, alto, lv)
	n.rotation_degrees.y = yaw
	if tinte != Color(1.0, 1.0, 1.0):
		lv._tint_model(n, tinte)
	if sombra != Vector2.ZERO:
		lv._add_blob_shadow(pos + Vector3(sombra.x * 0.12, 0.02, sombra.y * 0.1), sombra.x, sombra.y)
	return n


## Cilindro con material propio (los `_cyl` de level3d solo admiten color).
static func cil(lv: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3,
		mat: Material, segs := 48) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bot
	mesh.height = h
	mesh.radial_segments = segs
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	lv.add_child(mi)
	return mi


# ------------------------------------------------------------- lo comun

## EL MOSTRADOR: el anillo biselado, a escala de mundo, con la madera clara
## del muelle. Sustituye a las cuatro cajas de `_setup_counter_and_belt`.
static func mostrador(lv: Node3D) -> void:
	var ruta := DIR + "la_mostrador.glb"
	if not ResourceLoader.exists(ruta):
		return
	var inst: Node3D = (load(ruta) as PackedScene).instantiate()
	lv.add_child(inst)
	var m := mat_tex("muelle", Color(1.0, 0.86, 0.66), 0.55, 0.85)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m


## Un taburete de madera en cada asiento.
static func taburete(lv: Node3D, pos: Vector3, alto: float) -> void:
	var n := prop(lv, "taburete", pos, alto, randf_range(0.0, 360.0))
	if n == null:
		lv._add_stool_viejo(pos)


## El cubo de basura donde caen los platos que dan la vuelta entera.
static func cubo(lv: Node3D, pos: Vector3) -> void:
	var n := prop(lv, "cubo", pos, 0.86, 30.0)
	if n == null:
		return
	var sombra := SceneBackdrop.blob_shadow(1.15, 1.15)
	sombra.position = pos + Vector3(0.0, 0.02, 0.0)
	lv.add_child(sombra)


## La mesa del chef (con su tabla de cortar encima). Devuelve false si no
## existe el modelo, y entonces level3d monta las cajas de siempre.
static func mesa_chef(lv: Node3D, pos: Vector3) -> bool:
	if not ResourceLoader.exists(DIR + "la_mesa_chef.glb"):
		return false
	prop(lv, "mesa_chef", pos, 0.86, 0.0)
	return true


# ------------------------------------------------------------------ isla

static func isla(lv: Node3D) -> void:
	# ARENA: dos discos, el de abajo mojado (mas oscuro) y encima el seco con
	# la textura de dunas; la orilla lleva un anillo de ESPUMA a ras de agua,
	# que es lo que en el concepto separa la playa del mar.
	var mojada := mat_tex("arena", Color(0.80, 0.72, 0.56), 0.26, 1.0)
	var seca := mat_tex("arena", Color(1.0, 0.96, 0.84), 0.26, 1.0)
	cil(lv, 7.6, 7.9, 0.30, Vector3(0.0, -0.42, 0.0), mojada)
	cil(lv, 7.0, 7.4, 0.28, Vector3(0.0, -0.14, 0.0), seca)
	var espuma := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 7.55
	toro.outer_radius = 8.5
	toro.rings = 64
	espuma.mesh = toro
	espuma.scale = Vector3(1.0, 0.05, 1.0)
	espuma.position = Vector3(0.0, -0.50, 0.0)
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(1.0, 1.0, 1.0, 0.78)
	em.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	espuma.material_override = em
	espuma.add_to_group("no_batch")
	lv.add_child(espuma)
	# PARCHES DE HIERBA bajo cada grupo de decorado (fuera del pasillo).
	var hierba := StandardMaterial3D.new()
	hierba.albedo_color = Color(0.46, 0.76, 0.30)
	hierba.roughness = 1.0
	for g in [[-3.2, -4.4, 2.0], [3.6, -4.6, 2.1], [3.4, 3.9, 1.8], [-3.6, 4.2, 1.8],
			[-4.6, 0.3, 1.0]]:
		var r: float = g[2]
		var c := cil(lv, r, r * 1.06, 0.10, uw(float(g[0]), float(g[1])) + Vector3(0.0, 0.03, 0.0), hierba, 40)
		c.scale = Vector3(1.0, 1.0, 0.78)
		c.rotation_degrees.y = float(g[0]) * 23.0
	# PALMERAS: una en cada esquina baja y una asomando por el canto derecho.
	# La de arriba a la izquierda va a 3.0 de alto y un poco mas abajo: a 3.3
	# y w -2.6 su copa se metia bajo el boton "Salir" (y 110-160).
	prop(lv, "palmera", uw(-3.9, -2.2), 3.0, 20.0, Vector2(2.2, 1.4))
	prop(lv, "palmera", uw(3.4, 3.6), 3.0, 250.0, Vector2(2.1, 1.4))
	prop(lv, "palmera", uw(4.9, -0.9), 2.9, 140.0, Vector2(2.0, 1.3))
	# LA CABAÑA arriba a la derecha, con la puerta a camara, y a 2.6 de alto:
	# mas alta, el tejado se mete bajo la barra del HUD (medido a 3.3: solo
	# asomaba la puerta).
	prop(lv, "cabana", uw(3.5, -4.0), 2.6, 45.0, Vector2(3.0, 2.0))
	# EL ARBOL de copa apilada abajo a la izquierda.
	prop(lv, "arbol", uw(-3.7, 3.8), 3.0, 30.0, Vector2(2.4, 1.6))
	# ROCAS con musgo: una arriba junto al corredor, dos en los flancos.
	prop(lv, "roca", uw(-1.9, -5.7), 1.3, 40.0, Vector2(1.8, 1.2))
	prop(lv, "roca", uw(4.4, 1.9), 1.0, 280.0, Vector2(1.4, 0.9))
	prop(lv, "roca", uw(-4.5, 0.4), 1.1, 200.0, Vector2(1.5, 1.0))
	# ARBUSTOS
	prop(lv, "arbusto", uw(-4.4, -4.6), 0.95, 0.0, Vector2(1.3, 0.85))
	prop(lv, "arbusto", uw(1.9, -6.2), 0.85, 90.0, Vector2(1.2, 0.8))
	prop(lv, "arbusto", uw(2.2, 4.9), 0.8, 200.0, Vector2(1.1, 0.75))
	# FLORES, cocos brotados y madera de deriva: lo pequeño que hace playa.
	prop(lv, "hibisco", uw(-2.6, -4.4), 0.7, 0.0, Vector2(0.9, 0.6))
	prop(lv, "hibisco", uw(1.6, 4.4), 0.65, 120.0, Vector2(0.8, 0.55))
	prop(lv, "coco", uw(-1.3, -6.9), 0.35, 40.0, Vector2(0.45, 0.35))
	prop(lv, "coco", uw(-2.7, 5.0), 0.34, 200.0, Vector2(0.45, 0.35))
	prop(lv, "tronco", uw(-1.7, 4.6), 0.42, 25.0, Vector2(1.3, 0.6))
	# BARRILES y CAJAS: mercancia de la playa, junto a la cabaña y en los
	# cantos.
	prop(lv, "barril", uw(1.7, -4.6), 0.92, 15.0, Vector2(0.9, 0.7))
	prop(lv, "barril", uw(-4.4, 4.8), 0.9, 70.0, Vector2(0.9, 0.7))
	prop(lv, "caja", uw(-4.3, -3.6), 0.7, 30.0, Vector2(0.95, 0.8))
	prop(lv, "caja", uw(4.0, 4.6), 0.66, 10.0, Vector2(0.9, 0.75))
	# EL CARTEL de madera junto al corredor de arriba, de cara a camara, y
	# MATAS DE HIERBA ALTA (la hierba cortable de Zelda) por los parches.
	prop(lv, "cartel", uw(1.3, -5.3), 1.25, 45.0, Vector2(0.6, 0.4))
	for h in [[-2.9, -5.4, 0.0], [-4.1, 2.0, 60.0], [2.7, 3.6, 120.0], [4.5, -2.6, 200.0],
			[-2.4, 4.9, 30.0]]:
		prop(lv, "hierba_alta", uw(float(h[0]), float(h[1])), 0.55, float(h[2]))


# ----------------------------------------------------------------- puerto

## Los props del muelle (la tarima, el puente y la valla los sigue montando
## level3d, con la textura de tablones claros).
static func puerto_props(lv: Node3D) -> void:
	# NORAYS en el canto del agua (delante de la valla) y uno en el flanco.
	for b in [[-1.7, -6.5, 30.0], [2.3, -6.5, 200.0], [-4.5, 1.6, 110.0]]:
		prop(lv, "noray", uw(float(b[0]), float(b[1])), 0.6, float(b[2]), Vector2(0.8, 0.6))
	# DOS FAROLAS en diagonal, una por esquina baja de cada flanco. Van a 2.4
	# de alto para que la cabeza de la de la izquierda quede por debajo del
	# boton "Salir".
	prop(lv, "farola", uw(-4.1, -2.9), 2.4, 45.0, Vector2(0.7, 0.5))
	prop(lv, "farola", uw(4.2, 2.3), 2.4, 45.0, Vector2(0.7, 0.5))
	# LA CASETA de tejado azul arriba a la derecha (el mismo sitio que la
	# cabaña de la isla, por lo mismo: es lo unico alto que cabe sin HUD).
	prop(lv, "caseta", uw(3.5, -4.0), 2.6, 45.0, Vector2(3.0, 2.0))
	# CAJAS APILADAS: un monton junto al puente y otro abajo a la derecha.
	for pila in [Vector2(-2.1, -5.9), Vector2(2.6, 4.9)]:
		prop(lv, "caja", uw(pila.x, pila.y), 0.72, 10.0, Vector2(1.0, 0.8))
		prop(lv, "caja", uw(pila.x + 0.55, pila.y + 0.05), 0.66, 35.0, Vector2(0.9, 0.75))
		prop(lv, "caja", uw(pila.x + 0.25, pila.y) + Vector3(0.0, 0.70, 0.0), 0.62, 55.0)
	# LA RED con sus boyas, colgada del canto de arriba, y los BARRILES.
	prop(lv, "red", uw(1.4, -6.6), 0.85, 20.0, Vector2(1.3, 0.9))
	for b in [[1.6, -5.2, 0.0], [-3.4, 4.5, 60.0], [-2.6, 5.2, 0.0]]:
		prop(lv, "barril", uw(float(b[0]), float(b[1])), 0.92, float(b[2]), Vector2(0.9, 0.7))
	prop(lv, "cuerda", uw(4.2, 4.6), 0.25, 0.0, Vector2(0.9, 0.9), CABO)
	prop(lv, "cuerda", uw(-4.3, 0.6), 0.22, 70.0, Vector2(0.8, 0.8), CABO)
	# LA CAJA DE PESCADO junto a la red (es un puerto pesquero), el ANCLA
	# apoyada en el canto izquierdo y el CARTEL del muelle bajo la farola.
	# (la caja estuvo en (2.6, -5.9) y quedaba DETRAS de la caseta; el ancla
	# en (-4.3, 2.8) se montaba sobre el cabo del flanco izquierdo)
	prop(lv, "caja_pescado", uw(-4.1, 3.6), 0.55, 20.0, Vector2(1.1, 0.8))
	prop(lv, "ancla", uw(4.6, -0.8), 1.0, 25.0, Vector2(0.8, 0.6))
	prop(lv, "cartel", uw(-3.6, -4.5), 1.25, 45.0, Vector2(0.6, 0.4))


# ------------------------------------------------------------------ barco

## Los props de la cubierta (el casco, los tablones y las bordas los monta
## level3d con la textura de cubierta oscura).
static func barco_props(lv: Node3D) -> void:
	# EL MASTIL VA EN EL CANTO DERECHO, medio fuera de cuadro. Es la unica
	# forma de que se vea una vela: en el centro tapaba a dos clientes con sus
	# barras (medido en la primera tanda), en las esquinas de arriba se metia
	# entero bajo el HUD y en las de abajo quedaba DELANTE de la clientela.
	# Ahi, la vela asoma por el borde como el resto del barco que no cabe.
	prop(lv, "mastil", uw(4.9, -0.8), 4.2, 45.0, Vector2(1.2, 1.0))
	# CAÑONES asomando por la borda alta, uno a cada lado del embarque.
	# (yaw 225 = boca hacia ARRIBA en pantalla, o sea fuera de la borda:
	# a 135 apuntaban las dos a la derecha, la de babor hacia el centro.)
	for c in [[-1.6, -5.4, 225.0], [2.4, -5.4, 225.0]]:
		prop(lv, "canon", uw(float(c[0]), float(c[1])), 1.0, float(c[2]), Vector2(1.4, 0.9))
	# EL MASTIL ROTO (el tocon con su cabo y el jiron de vela) en la borda
	# alta, a 1.5 de alto: es lo mas alto que cabe ahi sin meterse bajo el
	# HUD ni bajo el boton "Salir" (x 20-125). El TIMON en la esquina de
	# arriba a la derecha y el FAROL colgado en el flanco derecho.
	prop(lv, "mastil_roto", uw(-2.8, -5.6), 1.5, 30.0, Vector2(1.0, 0.8))
	prop(lv, "timon", uw(3.9, -5.3), 1.2, 45.0, Vector2(0.9, 0.6))
	prop(lv, "farol", uw(4.5, -4.0), 1.15, 45.0, Vector2(0.5, 0.4))
	for b in [[1.4, -4.9, 0.0], [-3.9, -4.5, 40.0]]:
		prop(lv, "barril", uw(float(b[0]), float(b[1])), 0.92, float(b[2]), Vector2(0.9, 0.7))
	prop(lv, "cuerda", uw(-2.6, 4.4), 0.22, 0.0, Vector2(0.9, 0.9), CABO)
	prop(lv, "cuerda", uw(3.7, 4.0), 0.2, 50.0, Vector2(0.8, 0.8), CABO)
	prop(lv, "caja", uw(-4.1, 3.9), 0.75, 20.0, Vector2(0.95, 0.8))
	prop(lv, "caja", uw(-3.4, 4.4), 0.6, 40.0, Vector2(0.85, 0.7))
	# el botin del abordaje: el cofre de siempre en el flanco izquierdo
	if ResourceLoader.exists("res://assets/models/cofre.glb"):
		var chest: Node3D = lv._spawn_model(load("res://assets/models/cofre.glb"),
			uw(-3.9, -3.5), 0.6, lv)
		chest.rotation_degrees.y = 28.0