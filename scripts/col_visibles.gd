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
const MASTIL_X := 0.1099
## LA CUBIERTA, MEDIDA (no a ojo): las caras hacia arriba del casco caen en
## y de modelo -0.18, o sea la fraccion 0.298 del alto. Todo lo que se APOYE
## en el barco va aqui — el primer intento puso el huevo y el cañon a ojo y
## salieron FLOTANDO delante del casco (dicho por el usuario).
const CUBIERTA := 0.298
## La VELA DE MESANA (la de mas a popa) es el panel de x=0.262: abarca
## y[0.045,0.239] y z[-0.146,0.144]. Sale de la sonda de paneles claros.
const MESANA_X := 0.2921
const MESANA_Y := 0.657     ## fraccion del alto = centro de la vela
## La ANDANA BAJA: la franja BAJA del costado (y de modelo -0.32). Medida
## contra la captura, no a ojo: a la altura de la borda el arpon se recortaba
## contra el CIELO por encima del casco, que es justo lo contrario de estar
## tendido en la andana.
const ANDANA := 0.208
## Y LA BORDA, el canto de arriba del costado: lo que se apoye en la CUBIERTA
## queda TAPADO por el propio casco desde esta camara (medido: a media eslora
## el costado llega a z 0.16 y la cubierta esta a 0.08), asi que el cañon va
## montado sobre la borda, con la boca asomando por fuera.
const BORDA := 0.365
## Las medidas de aqui van en FRACCIONES DEL ALTO del barco, no en unidades
## del modelo: asi sobreviven a un cambio de barco. Estuvieron en unidades del
## `map_barco.glb` viejo (que medía 0.897 de alto) y al entrar el galeon de
## Kenney —9.96 de alto— la escala se iba por un factor de once y los adornos
## salian por el aire.
const ALTO_MESH := 1.0


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
	cil.top_radius = 0.0089 * s
	cil.bottom_radius = 0.0111 * s
	cil.height = 0.1338 * s
	palo.mesh = cil
	palo.position = Vector3(0.0, 0.0334 * s, 0.0)
	palo.material_override = _mat(Color(0.24, 0.16, 0.09))
	p.add_child(palo)
	var pano := MeshInstance3D.new()
	var caja := BoxMesh.new()
	# Mas pequena que el primer intento (0.30 x 0.17): a esa talla competia
	# con las velas y el usuario la bajo.
	caja.size = Vector3(0.2341 * s, 0.1338 * s, 0.0111 * s)
	pano.mesh = caja
	pano.position = Vector3(0.1282 * s, 0.0167 * s, 0.0)
	pano.material_override = _mat(Color(0.07, 0.07, 0.09))
	p.add_child(pano)
	# El cráneo, una calcomanía por cada cara del paño.
	if ResourceLoader.exists(CALAVERA_TEX):
		for lado in [1.0, -1.0]:
			var cara := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(0.0870 * s, 0.0870 * s)
			cara.mesh = quad
			cara.position = pano.position + Vector3(0.0, 0.0, 0.0078 * s * lado)
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
	# EL DIBUJO DEL PROPIO COLECCIONABLE en un quad a dos caras, meciendose
	# bajo la bandera. El cono naranja del primer intento no tenia textura y
	# no se distinguia que fuera un koinobori (dicho por el usuario): el
	# dibujo trae las escamas, el ojo y hasta su asta.
	if not ResourceLoader.exists("res://assets/ui/col_koinobori.png"):
		return
	# A alto*0.83: a 0.90 quedaba justo detras del paño de la bandera (que
	# vuela a +x) y en captura solo asomaba una esquina.
	var p := _prop(pivot,
		Vector3(MASTIL_X * s, alto * 0.83, 0.0), 12.0, 2.4)
	for lado in [1.0, -1.0]:
		var cara := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.2118 * s, 0.2118 * s)
		cara.mesh = quad
		cara.position = Vector3(-0.1282 * s, 0.0, 0.0011 * s * lado)
		if lado < 0.0:
			cara.rotation_degrees.y = 180.0
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/ui/col_koinobori.png")
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cara.material_override = m
		p.add_child(cara)


## EL FAROL FANTASMA, encendido en proa con su luz ESPECTRAL verde — la del
## Holandés Errante. Emisivo y sin luz de verdad: el mapa no gasta focos.
static func _farol_fantasma(pivot: Node3D, s: float, alto: float) -> void:
	# COLGADO DEL CANTO DE POPA, bajo la borda (donde señaló el usuario), y
	# MAS PEQUEÑO: el cubo verde del primer intento era enorme y flotaba a
	# media altura. Ahora es un farol de verdad — tapa y base de hierro,
	# cristal emisivo en medio — con su DESTELLO (un quad aditivo con el
	# gradiente radial `destello_farol.png`) y una luz corta de verdad.
	var p := Node3D.new()
	p.position = Vector3(0.5295 * s, alto * 0.47, 0.0)
	p.add_to_group("no_batch")
	pivot.add_child(p)
	var hierro := _mat(Color(0.15, 0.14, 0.13))
	var gancho := MeshInstance3D.new()
	var gc := CylinderMesh.new()
	gc.top_radius = 0.0056 * s
	gc.bottom_radius = 0.0056 * s
	gc.height = 0.0502 * s
	gancho.mesh = gc
	gancho.position = Vector3(0.0, 0.0580 * s, 0.0)
	gancho.material_override = hierro
	p.add_child(gancho)
	var tapa := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = 0.0111 * s
	tc.bottom_radius = 0.0245 * s
	tc.height = 0.0156 * s
	tapa.mesh = tc
	tapa.position = Vector3(0.0, 0.0312 * s, 0.0)
	tapa.material_override = hierro
	p.add_child(tapa)
	var cristal := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.0178 * s
	cc.bottom_radius = 0.0201 * s
	cc.height = 0.0401 * s
	cristal.mesh = cc
	var mv := _mat(Color(0.62, 0.98, 0.76))
	mv.emission_enabled = true
	mv.emission = Color(0.30, 0.95, 0.55)
	mv.emission_energy_multiplier = 1.0
	cristal.material_override = mv
	p.add_child(cristal)
	var base := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.0223 * s
	bc.bottom_radius = 0.0156 * s
	bc.height = 0.0111 * s
	base.mesh = bc
	base.position = Vector3(0.0, -0.0256 * s, 0.0)
	base.material_override = hierro
	p.add_child(base)
	# EL DESTELLO: cartel aditivo que siempre mira a camara.
	if ResourceLoader.exists("res://assets/ui/destello_farol.png"):
		var glow := MeshInstance3D.new()
		var gq := QuadMesh.new()
		gq.size = Vector2(0.1784 * s, 0.1784 * s)
		glow.mesh = gq
		var mg := StandardMaterial3D.new()
		mg.albedo_texture = load("res://assets/ui/destello_farol.png")
		mg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mg.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mg.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		glow.material_override = mg
		p.add_child(glow)
	# Y LUZ de verdad, corta y sin sombras: enciende la madera de popa.
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.45, 1.0, 0.65)
	luz.light_energy = 1.4
	luz.omni_range = 0.6132 * s
	luz.shadow_enabled = false
	p.add_child(luz)


## EL ARPÓN, apoyado contra la borda con la punta al cielo: asta larga y
## cabeza de metal con su lengüeta.
static func _arpon(pivot: Node3D, s: float, alto: float) -> void:
	# TENDIDO A LO LARGO DE LA ANDANA BAJA (pedido por el usuario), de popa a
	# proa y con la punta hacia delante, apoyado contra el costado por fuera
	# del casco. De pie sobre el castillo de popa —donde estuvo— no se
	# entendia que fuera un arpon ni por que estaba ahi.
	var p := Node3D.new()
	p.position = Vector3(0.2007 * s, alto * ANDANA, 0.2062 * s)
	# El cilindro nace con su eje en +Y; girando 90º en Z pasa a -X, o sea
	# que la punta mira a PROA.
	p.rotation_degrees.z = 90.0
	p.add_to_group("no_batch")
	pivot.add_child(p)
	var asta := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.0111 * s
	cil.bottom_radius = 0.0134 * s
	cil.height = 0.3344 * s
	asta.mesh = cil
	asta.position = Vector3(0.0, 0.1672 * s, 0.0)
	# Madera OSCURA: sobre el costado del barco, un asta del tono de la
	# cubierta se perdia contra ella.
	asta.material_override = _mat(Color(0.20, 0.13, 0.07))
	p.add_child(asta)
	var punta := MeshInstance3D.new()
	var cono := CylinderMesh.new()
	cono.top_radius = 0.0
	cono.bottom_radius = 0.0178 * s
	cono.height = 0.0780 * s
	punta.mesh = cono
	punta.position = Vector3(0.0, 0.3679 * s, 0.0)
	punta.material_override = _mat(Color(0.72, 0.74, 0.78))
	p.add_child(punta)
	# Las dos ligaduras de cuerda que lo amarran al costado.
	for d in [0.06, 0.26]:
		var lazo := MeshInstance3D.new()
		var tc := CylinderMesh.new()
		tc.top_radius = 0.0156 * s
		tc.bottom_radius = 0.0156 * s
		tc.height = 0.0178 * s
		lazo.mesh = tc
		lazo.position = Vector3(0.0, d * s, 0.0)
		lazo.material_override = _mat(Color(0.62, 0.52, 0.34))
		p.add_child(lazo)


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
	# ESTIBADA EN LA AMURA DE PROA, contra la tabla y por FUERA del casco
	# (ahi el casco llega a z 0.07-0.10, asi que a 0.11 se ve entera). Estuvo
	# a media eslora y se la comia el escorzo del propio casco: "el ancla
	# desaparece a la mitad", dicho por el usuario.
	var p := Node3D.new()
	p.position = Vector3(-0.3122 * s, alto * 0.253, 0.1226 * s)
	p.add_to_group("no_batch")
	pivot.add_child(p)
	var hierro := _mat(Color(0.16, 0.17, 0.20))
	var cana := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.0123 * s
	cil.bottom_radius = 0.0123 * s
	cil.height = 0.1895 * s
	cana.mesh = cil
	cana.material_override = hierro
	p.add_child(cana)
	var cepo := MeshInstance3D.new()
	var barra := CylinderMesh.new()
	barra.top_radius = 0.0078 * s
	barra.bottom_radius = 0.0078 * s
	barra.height = 0.0836 * s
	cepo.mesh = barra
	# El cepo tambien en el plano del casco (tumbado en x, no saliendo en z).
	cepo.rotation_degrees.z = 90.0
	cepo.position = Vector3(0.0, 0.0557 * s, 0.0)
	cepo.material_override = hierro
	p.add_child(cepo)
	var aro := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.0089 * s
	toro.outer_radius = 0.0178 * s
	aro.mesh = toro
	aro.position = Vector3(0.0, 0.0870 * s, 0.0)
	aro.material_override = hierro
	p.add_child(aro)
	# PLANA CONTRA EL CASCO (pedido por el usuario): los brazos se abren en
	# el plano X-Y, pegados a la tabla, no hacia fuera en z.
	for lado in [-1.0, 1.0]:
		var brazo := MeshInstance3D.new()
		var bc := CylinderMesh.new()
		bc.top_radius = 0.0078 * s
		bc.bottom_radius = 0.0100 * s
		bc.height = 0.0780 * s
		brazo.mesh = bc
		brazo.rotation_degrees.z = 55.0 * lado
		brazo.position = Vector3(0.0290 * s * lado, -0.0647 * s, 0.0)
		brazo.material_override = hierro
		p.add_child(brazo)
		var una := MeshInstance3D.new()
		var cono := CylinderMesh.new()
		cono.top_radius = 0.0
		cono.bottom_radius = 0.0145 * s
		cono.height = 0.0334 * s
		una.mesh = cono
		una.position = Vector3(0.0580 * s * lado, -0.0836 * s, 0.0)
		una.material_override = hierro
		p.add_child(una)


## EL CAÑÓN PIRATA, en cubierta y apuntando al mar por el costado de la
## cámara. Se puede TOCAR en el menú: con la bala de cañón en la vitrina
## DISPARA (ver `main_menu._disparar_canon`), y sin ella Gigi protesta.
static func _canon(pivot: Node3D, s: float, alto: float) -> Node3D:
	# MODELO DE VERDAD (`canon_pirata.glb`, el primero generado con MESHY):
	# tubo de hierro con sus aros de laton y cureña de madera con ruedas de
	# radios. Antes se montaba con cilindros y cajas y se veia lo que era, un
	# monton de primitivas de color plano.
	#
	# Va EN LA BORDA y apuntando AL MAR: apoyado en la cubierta se lo tragaba
	# el propio costado (medido), y tumbado a lo largo del barco no apuntaba a
	# ninguna parte. Medidas del modelo, sacadas con sonda de vertices: mide
	# 1.899 de largo por el eje X, la boca cae en (-0.802, 0.659, 0.014) y el
	# eje del tubo es (-0.911, 0.412, 0.017), o sea 24º de alza.
	if not ResourceLoader.exists("res://assets/models/canon_pirata.glb"):
		return null
	const LARGO := 0.155         ## cuanto mide el cañon en unidades del barco
	const CAJA_X := 1.899        ## largo del modelo por su eje X
	const SUELO_Y := -0.657      ## su vertice mas bajo (para que apoye)
	const BOCA := Vector3(-0.802, 0.659, 0.014)
	const EJE := Vector3(-0.911, 0.412, 0.017)
	var k := LARGO * s / CAJA_X
	var p := Node3D.new()
	p.name = "ColCanon"
	p.position = Vector3(-0.2230 * s, alto * BORDA - SUELO_Y * k, 0.0780 * s)
	p.add_to_group("no_batch")
	pivot.add_child(p)
	var m := (load("res://assets/models/canon_pirata.glb") as PackedScene) 		.instantiate()
	# El tubo nace apuntando a -X; girando 90º en Y la boca mira a +Z, que es
	# el costado por el que se ve el barco (y por donde queda el mar).
	m.rotation_degrees.y = 90.0
	m.scale = Vector3.ONE * k
	p.add_child(m)
	# El mismo giro, aplicado a mano a la boca y al eje, es lo que necesita
	# `main_menu._disparar_canon` para el fogonazo y el RETROCESO: asi mover o
	# reorientar el cañon no descoloca el disparo.
	var gira := func(v: Vector3) -> Vector3: return Vector3(v.z, v.y, -v.x)
	p.set_meta("dir_boca", (gira.call(EJE) as Vector3).normalized())
	p.set_meta("boca", (gira.call(BOCA) as Vector3) * k)
	p.set_meta("reposo", p.position)
	return p


## EL HUEVO DEL PEZ DEL VIENTO (Link's Awakening): enorme, crema con motas,
## coronando el castillo de popa como corona su montaña.
static func _huevo(pivot: Node3D, s: float, alto: float) -> void:
	# APOYADO EN LA CUBIERTA de verdad (`CUBIERTA`, medida), en el lado de
	# dentro para no pelearse con el cañon, y con las motas moradas EN LA
	# TEXTURA (`huevo_moteado.png`, pintada por PIL y envuelta por la UV de
	# la esfera) — las lentejas 3D del primer intento sobresalian de la
	# cascara, y el huevo entero FLOTABA delante del casco.
	var p := Node3D.new()
	p.position = Vector3(-0.1895 * s, alto * CUBIERTA, -0.0557 * s)
	p.add_to_group("no_batch")
	pivot.add_child(p)
	var huevo := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.0613 * s
	esfera.height = 0.1672 * s
	huevo.mesh = esfera
	huevo.position = Vector3(0.0, 0.0803 * s, 0.0)
	var m := _mat(Color(1, 1, 1))
	if ResourceLoader.exists("res://assets/ui/huevo_moteado.png"):
		m.albedo_texture = load("res://assets/ui/huevo_moteado.png")
	else:
		m.albedo_color = Color(0.93, 0.89, 0.78)
	huevo.material_override = m
	p.add_child(huevo)


## LA VELA DE WIND WAKER: su emblema, calcado del propio coleccionable, como
## calcomanía sobre la vela del MASTIL (por las dos caras, que el timón ya
## deja ver el barco por detrás).
static func _vela_ww(pivot: Node3D, s: float, alto: float) -> void:
	if not ResourceLoader.exists("res://assets/ui/col_vela_emblema.png"):
		return
	# SOLO EL EMBLEMA (`col_vela_emblema.png`, el disco con la medialuna y la
	# ola recortado del propio coleccionable), calcado en la VELA DE MESANA
	# (la de mas a popa, `MESANA_X`, localizada con la sonda de paneles
	# claros). El primer intento pegaba el coleccionable ENTERO —una vela con
	# su marco rojo— y el segundo lo puso en un x donde NO HAY VELA, asi que
	# el emblema flotaba entre dos palos. Va por las dos caras.
	for lado in [1.0, -1.0]:
		var cara := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.1449 * s, 0.1449 * s)
		cara.mesh = quad
		cara.position = Vector3((MESANA_X + 0.008 * lado) * s,
			alto * MESANA_Y, 0.0)
		cara.rotation_degrees.y = 90.0 * lado
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/ui/col_vela_emblema.png")
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
	# GRANDE: ocupa la parte de arriba de la caja entera (pedido por el
	# usuario — a 0.0016 de pixel_size casi no se veia).
	var spr := Sprite3D.new()
	spr.texture = load("res://assets/ui/col_peluche_morsa.png")
	spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spr.pixel_size = 0.0028
	spr.position = caja_pos + Vector3(0.0, 1.05, 0.0)
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
