class_name ColVisibles
extends RefCounted
## COLECCIONABLES QUE SE VEN EN EL JUEGO (pedido por el usuario): algunas
## piezas de la vitrina dejan huella física — en el barco del menú/mapa o en
## los personajes — en cuanto se consiguen. La vitrina las guarda; esto las
## LUCE, que es lo que hace que ganar una se note al volver al barco.
##
## EL REPARTO DECIDIDO, pieza a pieza (tanda del 31-8-2026, pedida por el
## usuario; ✔ = implementado, · = pendiente de su sistema o de su modelo):
##   ✔ bandera          → BANDERA PIRATA negra ondeando en lo alto del mástil
##   ✔ koinobori        → la carpa de tela al viento bajo la bandera
##   ✔ farol_fantasma   → farol de luz ESPECTRAL verde colgado de popa
##   ✔ arpon            → arpón apoyado contra el castillo
##   ✔ ancla            → RECOGIDA contra el costado del casco (cara cámara)
##   ✔ canon            → en cubierta y SE PUEDE TOCAR: con `bala_canon`
##                        dispara (main_menu._disparar_canon) y sin ella Gigi
##                        protesta. La pieza saldrá de una misión de mapa del
##                        tesoro (sistema pendiente).
##   ✔ huevo_montana    → el HUEVO del Pez del Viento, enorme, coronando popa
##   ✔ vela             → el emblema de Wind Waker calcado en la vela del
##                        mástil (por las dos caras: el timón gira el barco)
##   ✔ peluche_morsa    → dormido sobre una caja en las ISLAS del nivel
##                        (morsa_en_isla, la llama _scenery_island)
##   ✔ sombrero_paja    → lo lleva CAI EN SU ARTE 2D desde que cae la pieza
##                        (variante `_sombrero` de DialogueBox._variante_de;
##                        el chef ya NO se lo pone — reasignado por el usuario)
##   ✔ timon            → SE GANA A LAS 45 ESTRELLAS y desde entonces corona
##                        el tablón del menú: girarlo GIRA EL BARCO (mirador)
##   · tricornio        → SE LO QUEDA GIGI: variante `_tricornio` del arte de
##                        David (mecanismo listo, ARTE pendiente de generar —
##                        12 moods por editImage, la vía de Cai)
##   · panuelo          → lo estrenará DAVID en su arte (misión de mapa del
##                        tesoro; mismo mecanismo de variantes)
##   · maneki_neko      → sobre el mostrador de la TIENDA de Saverio
##   · daruma / omamori → estantería de la tienda, junto a los tarros
##   · catalejo         → en la cofa, apuntando al horizonte (pide cofa)
##   · farol_aceite     → farol cálido de popa (pareja del fantasma)
##   · gorro_chef       → alternativa de gorro para el chef
##   · lata_espinacas / grog / botella_sake → botellas en la mesa del chef
##   · calavera_alada   → mascarón de proa (pide modelo digno)
## Con EFECTO de juego (no visual): tapones_cera → cada canto de sirena dura
## un tercio menos (level3d._empezar_canto).
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
	if GameState.has_collectible("ancla"):
		_ancla(pivot, s, alto)
	if GameState.has_collectible("canon"):
		_canon(pivot, s, alto)
	if GameState.has_collectible("huevo_montana"):
		_huevo(pivot, s, alto)
	if GameState.has_collectible("vela"):
		_vela_ww(pivot, s, alto)


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


## EL ANCLA de respeto, RECOGIDA contra el costado del casco que mira a la
## cámara: caña vertical con su argolla, cepo cruzado y los dos brazos con
## sus uñas. Hierro oscuro.
static func _ancla(pivot: Node3D, s: float, alto: float) -> void:
	var p := Node3D.new()
	p.position = Vector3(-0.10 * s, alto * 0.17, 0.185 * s)
	p.add_to_group("no_batch")
	pivot.add_child(p)
	var hierro := _mat(Color(0.16, 0.17, 0.20))
	var cana := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.008 * s
	cil.bottom_radius = 0.008 * s
	cil.height = 0.14 * s
	cana.mesh = cil
	cana.material_override = hierro
	p.add_child(cana)
	var cepo := MeshInstance3D.new()
	var barra := CylinderMesh.new()
	barra.top_radius = 0.007 * s
	barra.bottom_radius = 0.007 * s
	barra.height = 0.075 * s
	cepo.mesh = barra
	cepo.rotation_degrees.x = 90.0
	cepo.position = Vector3(0.0, 0.05 * s, 0.0)
	cepo.material_override = hierro
	p.add_child(cepo)
	var aro := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.008 * s
	toro.outer_radius = 0.016 * s
	aro.mesh = toro
	aro.position = Vector3(0.0, 0.078 * s, 0.0)
	aro.material_override = hierro
	p.add_child(aro)
	for lado in [-1.0, 1.0]:
		var brazo := MeshInstance3D.new()
		var bc := CylinderMesh.new()
		bc.top_radius = 0.007 * s
		bc.bottom_radius = 0.009 * s
		bc.height = 0.07 * s
		brazo.mesh = bc
		brazo.rotation_degrees.x = 55.0 * lado
		brazo.position = Vector3(0.0, -0.058 * s, 0.026 * s * lado)
		brazo.material_override = hierro
		p.add_child(brazo)
		var una := MeshInstance3D.new()
		var cono := CylinderMesh.new()
		cono.top_radius = 0.0
		cono.bottom_radius = 0.013 * s
		cono.height = 0.030 * s
		una.mesh = cono
		una.position = Vector3(0.0, -0.075 * s, 0.052 * s * lado)
		una.material_override = hierro
		p.add_child(una)


## EL CAÑÓN PIRATA, en cubierta y apuntando al mar por el costado de la
## cámara. Se puede TOCAR en el menú: con la bala de cañón en la vitrina
## DISPARA (ver `main_menu._disparar_canon`), y sin ella Gigi protesta.
static func _canon(pivot: Node3D, s: float, alto: float) -> Node3D:
	var p := Node3D.new()
	p.name = "ColCanon"
	p.position = Vector3(-0.10 * s, alto * 0.30, 0.06 * s)
	p.add_to_group("no_batch")
	pivot.add_child(p)
	var bronce := _mat(Color(0.23, 0.20, 0.16))
	var madera := _mat(Color(0.34, 0.23, 0.12))
	var tubo := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.016 * s
	cil.bottom_radius = 0.022 * s
	cil.height = 0.11 * s
	tubo.mesh = cil
	# Tumbado y apuntando a +z (hacia la cámara), con la boca algo alzada.
	tubo.rotation_degrees.x = 78.0
	tubo.position = Vector3(0.0, 0.035 * s, 0.02 * s)
	tubo.material_override = bronce
	p.add_child(tubo)
	var cureña := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(0.055, 0.03, 0.07) * s
	cureña.mesh = caja
	cureña.position = Vector3(0.0, 0.012 * s, 0.0)
	cureña.material_override = madera
	p.add_child(cureña)
	for lado in [-1.0, 1.0]:
		var rueda := MeshInstance3D.new()
		var rc := CylinderMesh.new()
		rc.top_radius = 0.016 * s
		rc.bottom_radius = 0.016 * s
		rc.height = 0.012 * s
		rueda.mesh = rc
		rueda.rotation_degrees.z = 90.0
		rueda.position = Vector3(0.030 * s * lado, 0.008 * s, 0.0)
		rueda.material_override = madera
		p.add_child(rueda)
	return p


## EL HUEVO DEL PEZ DEL VIENTO (Link's Awakening): enorme, crema con motas,
## coronando el castillo de popa como corona su montaña.
static func _huevo(pivot: Node3D, s: float, alto: float) -> void:
	var p := Node3D.new()
	p.position = Vector3(0.36 * s, alto * 0.80, 0.0)
	p.add_to_group("no_batch")
	pivot.add_child(p)
	var huevo := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.055 * s
	esfera.height = 0.15 * s
	huevo.mesh = esfera
	huevo.position = Vector3(0.0, 0.075 * s, 0.0)
	huevo.material_override = _mat(Color(0.93, 0.89, 0.78))
	p.add_child(huevo)
	# Las motas moradas del huevo, que son toda la referencia: unas lentejas
	# hundidas a medias en la cáscara.
	for datos in [[0.0, 0.10, 1.0], [2.1, 0.06, 0.72], [4.2, 0.085, 0.85],
			[1.1, 0.045, 0.55], [3.3, 0.075, 0.62], [5.2, 0.055, 0.9]]:
		var mota := MeshInstance3D.new()
		var me := SphereMesh.new()
		me.radius = 0.013 * s
		me.height = 0.02 * s
		mota.mesh = me
		var ang: float = datos[0]
		var alto_m: float = datos[2]
		mota.position = Vector3(cos(ang) * 0.049 * s, alto_m * 0.14 * s,
			sin(ang) * 0.049 * s)
		mota.material_override = _mat(Color(0.48, 0.32, 0.55))
		p.add_child(mota)


## LA VELA DE WIND WAKER: su emblema, calcado del propio coleccionable, como
## calcomanía sobre la vela del MASTIL (por las dos caras, que el timón ya
## deja ver el barco por detrás).
static func _vela_ww(pivot: Node3D, s: float, alto: float) -> void:
	if not ResourceLoader.exists("res://assets/ui/col_vela.png"):
		return
	for lado in [1.0, -1.0]:
		var cara := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.16 * s, 0.19 * s)
		cara.mesh = quad
		cara.position = Vector3(MASTIL_X * s, alto * 0.62, 0.052 * s * lado)
		if lado < 0.0:
			cara.rotation_degrees.y = 180.0
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/ui/col_vela.png")
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cara.material_override = m
		cara.add_to_group("no_batch")
		pivot.add_child(cara)


## EL PELUCHE DE MORSA (Link's Awakening), dormido encima de una caja en las
## ISLAS del nivel: un Sprite3D con su propio dibujo, que a escala de nivel
## un peluche es un dibujo. Lo llama `level3d._scenery_island`.
static func morsa_en_isla(nivel: Node3D, caja_pos: Vector3) -> void:
	if not GameState.has_collectible("peluche_morsa"):
		return
	if not ResourceLoader.exists("res://assets/ui/col_peluche_morsa.png"):
		return
	var spr := Sprite3D.new()
	spr.texture = load("res://assets/ui/col_peluche_morsa.png")
	spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spr.pixel_size = 0.0016
	spr.position = caja_pos + Vector3(0.0, 0.9, 0.0)
	spr.add_to_group("no_batch")
	nivel.add_child(spr)


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
