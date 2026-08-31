class_name ColVisibles
extends RefCounted
## COLECCIONABLES QUE SE VEN EN EL JUEGO (pedido por el usuario): algunas
## piezas de la vitrina dejan huella física — en el barco del menú/mapa o en
## los personajes — en cuanto se consiguen. La vitrina las guarda; esto las
## LUCE, que es lo que hace que ganar una se note al volver al barco.
##
## EL REPARTO PENSADO, pieza a pieza (las marcadas ✔ están implementadas; el
## resto espera su hueco o su modelo — la regla es que solo entra lo que se
## puede construir con geometría y quedar BIEN a la escala del mapa, nada de
## pegatinas 2D flotando sobre el 3D):
##   ✔ bandera          → BANDERA PIRATA negra ondeando en lo alto del mástil
##   ✔ koinobori        → la carpa de tela al viento en un asta de popa
##   ✔ farol_fantasma   → farol de luz ESPECTRAL verde encendido en proa
##   ✔ arpon            → arpón apoyado contra la borda
##   ✔ sombrero_paja    → el CHEF lo lleva puesto en el nivel (hueso Head)
##   · timon            → dorar el timón del menú (pide tintar el modelo)
##   · ancla            → un ancla de respeto colgada del casco (pide modelo)
##   · canon            → cañón pequeño en cubierta (pide modelo)
##   · catalejo         → en la cofa, apuntando al horizonte (pide cofa)
##   · maneki_neko      → sobre el mostrador de la TIENDA de Saverio
##   · daruma / omamori → estantería de la tienda, junto a los tarros
##   · farol_aceite     → farol cálido de popa (pareja del fantasma)
##   · tricornio        → percha del camarote (cuando exista el interior)
##   · gorro_chef       → alternativa de gorro para el chef (como el de paja)
##   · lata_espinacas / grog / botella_sake → botellas en la mesa del chef
##   · calavera_alada   → mascarón de proa (pide modelo digno)
##   · koinobori dorado, banderines de One Piece... → más astas de popa
## Los tesoros pequeños (monedas, anillos, gafas, palillos...) NO se lucen:
## a la escala del mapa serían un píxel, y su sitio es la vitrina.

const PROP_SCRIPT := preload("res://scripts/col_prop.gd")
## El cráneo de la bandera pirata: el mismo dibujo del contador de vacíos.
const CALAVERA_TEX := "res://assets/ui/calavera_vacio.png"

## GEOMETRÍA DEL BARCO DEL MAPA, medida sobre `map_barco.glb` normalizado
## (sonda de vértices): el mástil sube en x≈0.098 del centro y el AABB mide
## 1.00 × 0.897 × 0.376. Todo lo demás se coloca en fracciones de eso, así
## que vale a cualquier escala del barco.
const MASTIL_X := 0.0986
const ALTO_MESH := 0.897


## Cuelga del barco del mapa los adornos de las piezas YA conseguidas. El
## `pivot` es el de `_spawn_model` (base en el origen, meta "alto" con la
## altura escalada); se llama al montar el barco, así que una pieza nueva
## luce al volver al menú.
static func decorar_barco(pivot: Node3D) -> void:
	if pivot == null or not pivot.has_meta("alto"):
		return
	var alto: float = pivot.get_meta("alto")
	var s := alto / ALTO_MESH

	if GameState.has_collectible("bandera"):
		_bandera_pirata(pivot, s, alto)
	if GameState.has_collectible("koinobori"):
		_koinobori(pivot, s, alto)
	if GameState.has_collectible("farol_fantasma"):
		_farol_fantasma(pivot, s, alto)
	if GameState.has_collectible("arpon"):
		_arpon(pivot, s, alto)


## LA BANDERA PIRATA, en lo alto del mástil: paño negro con el cráneo por las
## dos caras, meciéndose con `ColProp`. El pivote va EN el mástil para que el
## vaivén gire alrededor del palo, como una bandera de verdad.
static func _bandera_pirata(pivot: Node3D, s: float, alto: float) -> void:
	var p := _prop(pivot, Vector3(MASTIL_X * s, alto * 0.985, 0.0), 10.0, 1.4)
	# Un palmo más de palo, para que el paño no nazca del vacío.
	var palo := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.008 * s
	cil.bottom_radius = 0.010 * s
	cil.height = 0.12 * s
	palo.mesh = cil
	palo.position = Vector3(0.0, 0.03 * s, 0.0)
	palo.material_override = _mat(Color(0.24, 0.16, 0.09))
	p.add_child(palo)
	var pano := MeshInstance3D.new()
	var caja := BoxMesh.new()
	# Mas pequena que el primer intento (0.30 x 0.17): a esa talla competia
	# con las velas y el usuario la bajo.
	caja.size = Vector3(0.21 * s, 0.12 * s, 0.010 * s)
	pano.mesh = caja
	pano.position = Vector3(0.115 * s, 0.015 * s, 0.0)
	pano.material_override = _mat(Color(0.07, 0.07, 0.09))
	p.add_child(pano)
	# El cráneo, una calcomanía por cada cara del paño.
	if ResourceLoader.exists(CALAVERA_TEX):
		for lado in [1.0, -1.0]:
			var cara := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(0.078 * s, 0.078 * s)
			cara.mesh = quad
			cara.position = pano.position + Vector3(0.0, 0.0, 0.007 * s * lado)
			if lado < 0.0:
				cara.rotation_degrees.y = 180.0
			var m := StandardMaterial3D.new()
			m.albedo_texture = load(CALAVERA_TEX)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			cara.material_override = m
			p.add_child(cara)


## EL KOINOBORI: la carpa de tela en un asta de popa, hinchada por el viento
## hacia atrás. La carpa es un cilindro cónico naranja con el ojo pintado.
static func _koinobori(pivot: Node3D, s: float, alto: float) -> void:
	# CUELGA DEL MASTIL, bajo la bandera: es el unico punto del barco medido
	# de verdad. En popa no hay cubierta que medir y el primer intento salio
	# flotando fuera del casco (visto en captura), ademas de enorme — una
	# carpa de tela no puede medir un cuarto del barco.
	var p := _prop(pivot,
		Vector3(MASTIL_X * s, alto * 0.91, 0.0), 13.0, 2.4)
	var carpa := MeshInstance3D.new()
	var cono := CylinderMesh.new()
	cono.top_radius = 0.012 * s
	cono.bottom_radius = 0.030 * s
	cono.height = 0.15 * s
	carpa.mesh = cono
	# Tumbada con la boca pegada al palo y la cola volando a -x (la bandera
	# vuela a +x: cada tela a un lado del palo, que ademas se lee mejor).
	carpa.rotation_degrees.z = 90.0
	carpa.position = Vector3(-0.09 * s, 0.0, 0.0)
	carpa.material_override = _mat(Color(0.86, 0.42, 0.16))
	p.add_child(carpa)
	var ojo := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.012 * s
	esfera.height = 0.024 * s
	ojo.mesh = esfera
	ojo.position = Vector3(-0.035 * s, 0.0, 0.026 * s)
	ojo.material_override = _mat(Color(0.96, 0.94, 0.88))
	p.add_child(ojo)


## EL FAROL FANTASMA, encendido en proa con su luz ESPECTRAL verde — la del
## Holandés Errante. Emisivo y sin luz de verdad: el mapa no gasta focos.
static func _farol_fantasma(pivot: Node3D, s: float, alto: float) -> void:
	# FAROL DE POPA, como los de verdad: cuelga de un brazo que SOBRESALE del
	# castillo por +x, fuera del casco — dentro del castillo (el primer
	# intento) solo se le veia el resplandor por una ventana. La popa sube
	# hasta ~0.8 del alto (perfil medido por bandas de x).
	var pos := Vector3(0.50 * s, alto * 0.58, 0.0)
	var brazo := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.008 * s
	cil.bottom_radius = 0.008 * s
	cil.height = 0.10 * s
	brazo.mesh = cil
	brazo.rotation_degrees.z = 90.0
	brazo.position = pos + Vector3(-0.04 * s, 0.055 * s, 0.0)
	brazo.material_override = _mat(Color(0.22, 0.15, 0.09))
	brazo.add_to_group("no_batch")
	pivot.add_child(brazo)
	var farol := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(0.055, 0.07, 0.055) * s
	farol.mesh = caja
	farol.position = pos
	var m := _mat(Color(0.55, 0.95, 0.72))
	m.emission_enabled = true
	m.emission = Color(0.30, 0.95, 0.55)
	m.emission_energy_multiplier = 0.9
	farol.material_override = m
	farol.add_to_group("no_batch")
	pivot.add_child(farol)


## EL ARPÓN, apoyado contra la borda con la punta al cielo: asta larga y
## cabeza de metal con su lengüeta.
static func _arpon(pivot: Node3D, s: float, alto: float) -> void:
	var p := Node3D.new()
	# Apoyado en la cara DELANTERA del castillo de popa (la que mira a la
	# camara), asomando por encima de la borda: a media popa y bajo quedaba
	# dentro del casco y no se veia.
	p.position = Vector3(0.26 * s, alto * 0.30, 0.13 * s)
	p.rotation_degrees.z = 22.0
	p.rotation_degrees.x = -8.0
	p.add_to_group("no_batch")
	pivot.add_child(p)
	var asta := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.008 * s
	cil.bottom_radius = 0.010 * s
	cil.height = 0.34 * s
	asta.mesh = cil
	asta.position = Vector3(0.0, 0.17 * s, 0.0)
	asta.material_override = _mat(Color(0.36, 0.25, 0.14))
	p.add_child(asta)
	var punta := MeshInstance3D.new()
	var cono := CylinderMesh.new()
	cono.top_radius = 0.0
	cono.bottom_radius = 0.016 * s
	cono.height = 0.07 * s
	punta.mesh = cono
	punta.position = Vector3(0.0, 0.375 * s, 0.0)
	punta.material_override = _mat(Color(0.72, 0.74, 0.78))
	p.add_child(punta)


## EL SOMBRERO DE PAJA, puesto en la cabeza del CHEF dentro del nivel: copa y
## ala de paja colgadas del hueso Head con un BoneAttachment3D, el mismo
## camino que los utensilios de la muñeca. Se autora en unidades de MUNDO y
## el nodo raíz deshace la escala del modelo.
static func sombrero_de_paja(skel: Skeleton3D, model_scale: float) -> void:
	if skel == null or not GameState.has_collectible("sombrero_paja"):
		return
	var head := skel.find_bone("Head")
	if head < 0:
		head = skel.find_bone("Neck")
	if head < 0:
		return
	var att := BoneAttachment3D.new()
	skel.add_child(att)
	att.bone_name = skel.get_bone_name(head)
	var raiz := Node3D.new()
	raiz.scale = Vector3.ONE / maxf(model_scale, 0.0001)
	att.add_child(raiz)
	var paja := _mat(Color(0.89, 0.76, 0.42))
	var ala := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 0.155
	disco.bottom_radius = 0.165
	disco.height = 0.018
	ala.mesh = disco
	# A 0.150 el moño del chef asomaba por el ala (visto en captura), y
	# centrado le seguia asomando por detras: el sombrero va un pelo alto y
	# CORRIDO A LA NUCA, que es como se lleva un sombrero de paja.
	ala.position = Vector3(0.0, 0.178, -0.015)
	ala.material_override = paja
	raiz.add_child(ala)
	var copa := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.095
	cil.bottom_radius = 0.115
	cil.height = 0.085
	copa.mesh = cil
	copa.position = ala.position + Vector3(0.0, 0.045, 0.0)
	copa.material_override = paja
	raiz.add_child(copa)
	# La cinta roja del sombrero de Luffy, que es toda la referencia.
	var cinta := MeshInstance3D.new()
	var aro := CylinderMesh.new()
	aro.top_radius = 0.112
	aro.bottom_radius = 0.115
	aro.height = 0.028
	cinta.mesh = aro
	cinta.position = ala.position + Vector3(0.0, 0.02, 0.0)
	cinta.material_override = _mat(Color(0.72, 0.16, 0.12))
	raiz.add_child(cinta)


## Pivote con el vaivén de `ColProp` ya puesto.
static func _prop(pivot: Node3D, pos: Vector3, amp: float, vel: float) -> Node3D:
	var p: Node3D = PROP_SCRIPT.new()
	p.position = pos
	p.amp = amp
	p.vel = vel
	p.add_to_group("no_batch")
	pivot.add_child(p)
	return p


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m
