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
##   · vela             → NO SE LUCE (retirado por el usuario el 1-9-2026):
##                        el emblema se probo como calcomania en la vela y de
##                        canto se leia como una pegatina flotando; en la
##                        mesana tapaba el paño. No hay sitio que funcione.
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
## LA CUBIERTA, MEDIDA (no a ojo): las caras hacia arriba del casco caen en
## y de modelo -0.18, o sea la fraccion 0.298 del alto. Todo lo que se APOYE
## en el barco va aqui — el primer intento puso el huevo y el cañon a ojo y
## salieron FLOTANDO delante del casco (dicho por el usuario).
const CUBIERTA := 0.298
## La cubierta del CASTILLO DE POPA, mas alta que la de proa. MEDIDA con el
## mapa de caras hacia arriba: entre x 0.45 y 0.50 sale plana a y -0.080 para
## todas las z, que es el unico tramo de popa donde la cubierta es CONTINUA
## (mas adelante la parten el palo y las escaleras).
const POPA_CUBIERTA := 0.409
## La cubierta A MEDIA ESLORA, que va entre la de proa y la de popa: y de
## modelo -0.12. Es donde se apoya el cañon.
const MEDIA_CUBIERTA := 0.365
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
	# LA CARPA, EN VOLUMEN (pedido por el usuario): un cuerpo OVALADO de
	# verdad, no el cartel con el dibujo pegado que hubo antes — a esta camara
	# el quad se veia de canto la mitad del tiempo y se leia como una pegatina
	# flotando. Un koinobori es una manga de viento: boca ancha por delante,
	# cuerpo que se afina y cola abierta.
	# A alto*0.74 y no mas arriba: por encima de eso la carpa queda DETRAS de
	# la barra de experiencia del menu, que es interfaz y se dibuja encima.
	# EN LO ALTO DEL PALO DE PROA (pedido por el usuario, señalado en captura):
	# MEDIDO, ese palo corona en y +0.354, o sea alto*0.89. Y MAS PEQUEÑA que
	# antes: a 0.20 de largo se comia media jarcia.
	var p := _prop(pivot, Vector3(-0.100 * s, alto * 0.855, 0.0), 12.0, 2.4)
	var largo := 0.135 * s
	# Colores VIVOS y poco sensibles a la luz: vuela a la altura de las velas
	# y con el material corriente le caia su sombra encima y se veia negro.
	var naranja := _mat(Color(0.96, 0.45, 0.14))
	naranja.roughness = 0.55
	naranja.emission_enabled = true
	naranja.emission = Color(0.55, 0.20, 0.05)
	naranja.emission_energy_multiplier = 0.35
	var crema := _mat(Color(0.98, 0.96, 0.90))
	crema.roughness = 0.55
	crema.emission_enabled = true
	crema.emission = Color(0.45, 0.44, 0.40)
	crema.emission_energy_multiplier = 0.30
	# CUERPO: una esfera estirada a lo largo de -x (vuela al contrario que la
	# bandera, que va a +x, para que cada tela quede a un lado del palo).
	var cuerpo := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.5
	esfera.height = 1.0
	esfera.radial_segments = 12
	esfera.rings = 7
	cuerpo.mesh = esfera
	cuerpo.scale = Vector3(largo, largo * 0.46, largo * 0.46)
	cuerpo.position = Vector3(-largo * 0.62, 0.0, 0.0)
	# LA TEXTURA DEL PROPIO COLECCIONABLE, que es la que trae las escamas y el
	# ojo (el usuario: "ha perdido su textura, que era perfecta"). Va en
	# TRIPLANAR: la UV de una esfera enrolla el dibujo por el ecuador y la
	# carpa saldria retorcida; proyectada, el costado del pez cae en el
	# costado del cuerpo, que es donde se mira.
	if ResourceLoader.exists("res://assets/ui/col_koinobori.png"):
		naranja.albedo_texture = load("res://assets/ui/col_koinobori.png")
		naranja.albedo_color = Color(1, 1, 1)
		naranja.uv1_triplanar = true
		naranja.uv1_scale = Vector3.ONE / maxf(largo * 1.6, 0.001)
		naranja.emission_enabled = false
	cuerpo.material_override = naranja
	p.add_child(cuerpo)
	# BOCA: el aro por el que entra el viento, en la punta de delante.
	var boca := MeshInstance3D.new()
	var aro := TorusMesh.new()
	aro.inner_radius = largo * 0.15
	aro.outer_radius = largo * 0.22
	aro.rings = 12
	aro.ring_segments = 8
	boca.mesh = aro
	boca.rotation_degrees.z = 90.0
	boca.position = Vector3(-largo * 0.12, 0.0, 0.0)
	boca.material_override = crema
	p.add_child(boca)
	# COLA: se abre al final, como la de un pez.
	var cola := MeshInstance3D.new()
	var cono := CylinderMesh.new()
	cono.top_radius = largo * 0.20
	cono.bottom_radius = largo * 0.03
	cono.height = largo * 0.30
	cono.radial_segments = 10
	cola.mesh = cono
	cola.rotation_degrees.z = 90.0
	cola.position = Vector3(-largo * 1.28, 0.0, 0.0)
	cola.material_override = crema
	p.add_child(cola)
	# Y EL OJO, que es lo que lo hace leerse como un PEZ y no como un globo.
	for lado in [1.0, -1.0]:
		var ojo := MeshInstance3D.new()
		var e2 := SphereMesh.new()
		e2.radius = 0.5
		e2.height = 1.0
		e2.radial_segments = 8
		e2.rings = 5
		ojo.mesh = e2
		ojo.scale = Vector3.ONE * largo * 0.115
		ojo.position = Vector3(-largo * 0.30, largo * 0.10,
			largo * 0.19 * lado)
		ojo.material_override = _mat(Color(0.10, 0.09, 0.11))
		p.add_child(ojo)


## EL FAROL FANTASMA, encendido en proa con su luz ESPECTRAL verde — la del
## Holandés Errante. Emisivo y sin luz de verdad: el mapa no gasta focos.
static func _farol_fantasma(pivot: Node3D, s: float, alto: float) -> void:
	# COLGADO DEL CANTO DE POPA, bajo la borda (donde señaló el usuario), y
	# MAS PEQUEÑO: el cubo verde del primer intento era enorme y flotaba a
	# media altura. Ahora es un farol de verdad — tapa y base de hierro,
	# cristal emisivo en medio — con su DESTELLO (un quad aditivo con el
	# gradiente radial `destello_farol.png`) y una luz corta de verdad.
	# COLGANDO POR FUERA DE LA POPA Y BAJO (pedido por el usuario: "mas abajo,
	# justo donde esta ahora el ancla"). +x es la popa; a 0.545 el gancho queda
	# ya fuera del casco, que llega a 0.50.
	var p := Node3D.new()
	p.position = Vector3(0.545 * s, alto * 0.300, -0.020 * s)
	p.add_to_group("no_batch")
	pivot.add_child(p)
	var hierro := _mat(Color(0.15, 0.14, 0.13))
	var gancho := MeshInstance3D.new()
	var gc := CylinderMesh.new()
	gc.top_radius = 0.005 * s
	gc.bottom_radius = 0.005 * s
	gc.height = 0.045 * s
	gancho.mesh = gc
	gancho.position = Vector3(0.0, 0.052 * s, 0.0)
	gancho.material_override = hierro
	p.add_child(gancho)
	var tapa := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = 0.010 * s
	tc.bottom_radius = 0.022 * s
	tc.height = 0.014 * s
	tapa.mesh = tc
	tapa.position = Vector3(0.0, 0.028 * s, 0.0)
	tapa.material_override = hierro
	p.add_child(tapa)
	var cristal := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.016 * s
	cc.bottom_radius = 0.018 * s
	cc.height = 0.036 * s
	cristal.mesh = cc
	var mv := _mat(Color(0.62, 0.98, 0.76))
	mv.emission_enabled = true
	mv.emission = Color(0.30, 0.95, 0.55)
	mv.emission_energy_multiplier = 1.0
	cristal.material_override = mv
	p.add_child(cristal)
	var base := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.020 * s
	bc.bottom_radius = 0.014 * s
	bc.height = 0.010 * s
	base.mesh = bc
	base.position = Vector3(0.0, -0.023 * s, 0.0)
	base.material_override = hierro
	p.add_child(base)
	# EL DESTELLO: cartel aditivo que siempre mira a camara.
	if ResourceLoader.exists("res://assets/ui/destello_farol.png"):
		var glow := MeshInstance3D.new()
		var gq := QuadMesh.new()
		gq.size = Vector2(0.16 * s, 0.16 * s)
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
	luz.omni_range = 0.55 * s
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
	p.position = Vector3(0.18 * s, alto * ANDANA, 0.185 * s)
	# El cilindro nace con su eje en +Y; girando 90º en Z pasa a -X, o sea
	# que la punta mira a PROA.
	p.rotation_degrees.z = 90.0
	p.add_to_group("no_batch")
	pivot.add_child(p)
	var asta := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.010 * s
	cil.bottom_radius = 0.012 * s
	cil.height = 0.30 * s
	asta.mesh = cil
	asta.position = Vector3(0.0, 0.15 * s, 0.0)
	# Madera OSCURA: sobre el costado del barco, un asta del tono de la
	# cubierta se perdia contra ella.
	asta.material_override = _mat(Color(0.20, 0.13, 0.07))
	p.add_child(asta)
	var punta := MeshInstance3D.new()
	var cono := CylinderMesh.new()
	cono.top_radius = 0.0
	cono.bottom_radius = 0.016 * s
	cono.height = 0.07 * s
	punta.mesh = cono
	punta.position = Vector3(0.0, 0.33 * s, 0.0)
	punta.material_override = _mat(Color(0.72, 0.74, 0.78))
	p.add_child(punta)
	# Las dos ligaduras de cuerda que lo amarran al costado.
	for d in [0.06, 0.26]:
		var lazo := MeshInstance3D.new()
		var tc := CylinderMesh.new()
		tc.top_radius = 0.014 * s
		tc.bottom_radius = 0.014 * s
		tc.height = 0.016 * s
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
	# REHECHA (el usuario: "no tiene forma de ancla"). Lo que le faltaba era la
	# silueta: la de antes eran dos cilindros rectos abiertos en V, y un ancla
	# se reconoce por el ARCO de la cruz y por las UÑAS TRIANGULARES del final,
	# no por los brazos. Ahora los brazos son una curva de cuatro tramos y las
	# uñas prismas de tres lados, aplastados como palas.
	#
	# COLGADA DE UN COSTADO, EN LA AMURA DE PROA. Se probaron media eslora y la
	# banda del trinquete y las dos fallan por el mismo motivo: con esta camara
	# isometrica adelantar en z sube en pantalla igual que retroceder en x, asi
	# que el costado central cae JUSTO DETRAS del velamen y mas a proa lo tapa
	# el castillo, que ahi es alto. La amura es el unico tramo de costado que
	# queda despejado, y es donde un ancla va de verdad.
	var p := Node3D.new()
	p.name = "ColAncla"
	p.position = Vector3(-0.280 * s, alto * 0.290, 0.120 * s)
	# TRINCADA DE LADO, no colgando a plomo: derecha, los brazos y las uñas
	# —que es lo que hace que se lea "ancla"— quedaban SIEMPRE por debajo de la
	# linea del casco, tapados. Ladeada, la cruz se recorta contra el cielo. Y
	# ademas es como va un ancla estibada de verdad.
	p.rotation_degrees.x = -42.0
	p.rotation_degrees.z = 14.0
	p.add_to_group("no_batch")
	pivot.add_child(p)
	var hierro := _mat(Color(0.16, 0.17, 0.20))
	# La ARGOLLA de arriba, por donde se amarra.
	var aro := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.012 * s
	toro.outer_radius = 0.024 * s
	toro.rings = 10
	toro.ring_segments = 6
	aro.mesh = toro
	aro.position = Vector3(0.0, 0.098 * s, 0.0)
	aro.material_override = hierro
	p.add_child(aro)
	# LA CAÑA, de la argolla a la cruz.
	var cana := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.010 * s
	cil.bottom_radius = 0.013 * s
	cil.height = 0.175 * s
	cil.radial_segments = 8
	cana.mesh = cil
	cana.position = Vector3(0.0, 0.0, 0.0)
	cana.material_override = hierro
	p.add_child(cana)
	# EL CEPO: la barra cruzada de arriba, PERPENDICULAR a los brazos. Es la
	# que hace que de lejos se lea "ancla" y no "cruz".
	var cepo := MeshInstance3D.new()
	var barra := BoxMesh.new()
	barra.size = Vector3(0.010, 0.010, 0.150) * s
	cepo.mesh = barra
	cepo.position = Vector3(0.0, 0.072 * s, 0.0)
	cepo.material_override = hierro
	p.add_child(cepo)
	# LOS BRAZOS, en ARCO: cuatro tramos cortos que bajan y se abren.
	for lado in [-1.0, 1.0]:
		var tramos := [
			[Vector3(0.014, -0.090, 0.0), 20.0, 0.040],
			[Vector3(0.040, -0.108, 0.0), 48.0, 0.040],
			[Vector3(0.070, -0.115, 0.0), 74.0, 0.036],
		]
		for tr in tramos:
			var seg := MeshInstance3D.new()
			var sc := CylinderMesh.new()
			sc.top_radius = 0.009 * s
			sc.bottom_radius = 0.010 * s
			sc.height = float(tr[2]) * s
			sc.radial_segments = 6
			seg.mesh = sc
			var q: Vector3 = tr[0]
			seg.position = Vector3(q.x * s * lado, q.y * s, 0.0)
			seg.rotation_degrees.z = float(tr[1]) * -lado
			seg.material_override = hierro
			p.add_child(seg)
		# LA UÑA: prisma triangular aplastado, la pala que muerde el fondo.
		var una := MeshInstance3D.new()
		var pris := CylinderMesh.new()
		pris.top_radius = 0.0
		pris.bottom_radius = 0.034 * s
		pris.height = 0.052 * s
		pris.radial_segments = 3
		una.mesh = pris
		una.scale = Vector3(1.0, 1.0, 0.45)
		una.position = Vector3(0.098 * s * lado, -0.100 * s, 0.0)
		una.rotation_degrees.z = -58.0 * lado
		una.material_override = hierro
		p.add_child(una)


## EL CAÑÓN PIRATA, en cubierta y apuntando al mar por el costado de la
## cámara. Se puede TOCAR en el menú: con la bala de cañón en la vitrina
## DISPARA (ver `main_menu._disparar_canon`), y sin ella Gigi protesta.
static func _canon(pivot: Node3D, s: float, alto: float) -> Node3D:
	# EN CUBIERTA (`CUBIERTA`, medida) Y APUNTANDO AL MAR por el costado que
	# mira a la camara, que es como se coloca un cañon de andanada. Estuvo
	# tumbado a lo largo del barco y flotando delante del casco: ni apuntaba
	# a ninguna parte ni se apoyaba en nada, y el humo del disparo salia por
	# detras de la madera. Con la boca asomando por encima de la borda, el
	# fogonazo cae en cielo abierto.
	var p := Node3D.new()
	p.name = "ColCanon"
	# A MEDIA ESLORA, EN LA CUBIERTA Y PEGADO AL SUELO, asomando al mar por el
	# costado que mira a la camara (pedido por el usuario). MEDIDO: a media
	# eslora la cubierta cae en y -0.12 y la borda solo sube hasta -0.03/-0.09,
	# o sea que un cañon apoyado en las tablas asoma por encima de ella. En la
	# proa, que es donde estuvo, la cubierta va mucho mas baja (-0.18) y el
	# costado se lo tragaba.
	p.position = Vector3(-0.020 * s, alto * MEDIA_CUBIERTA, 0.100 * s)
	p.add_to_group("no_batch")
	pivot.add_child(p)
	var hierro := _mat(Color(0.24, 0.25, 0.29))
	var bronce := _mat(Color(0.55, 0.42, 0.20))
	var madera := _mat(Color(0.34, 0.23, 0.12))
	# ELEVACION: el eje del tubo es (0, sin, cos) — 8º de alza sobre el mar.
	var alza := 8.0
	var eje := Vector3(0.0, sin(deg_to_rad(alza)), cos(deg_to_rad(alza)))
	var giro := 90.0 - alza
	var centro := Vector3(0.0, 0.050 * s, 0.010 * s)
	var tubo := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.019 * s
	cil.bottom_radius = 0.026 * s
	cil.height = 0.135 * s
	tubo.mesh = cil
	tubo.rotation_degrees.x = giro
	tubo.position = centro
	tubo.material_override = hierro
	p.add_child(tubo)
	# Anillos de refuerzo y labio de la boca, repartidos por el eje del tubo.
	for datos in [[0.060, 0.024], [-0.008, 0.028], [-0.058, 0.030]]:
		var anillo := MeshInstance3D.new()
		var ac := CylinderMesh.new()
		ac.top_radius = float(datos[1]) * s
		ac.bottom_radius = float(datos[1]) * s
		ac.height = 0.010 * s
		anillo.mesh = ac
		anillo.rotation_degrees.x = giro
		anillo.position = centro + eje * (float(datos[0]) * s)
		anillo.material_override = bronce
		p.add_child(anillo)
	# La cureña, mas larga en z que ancha en x: sigue al tubo.
	var cure := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(0.070, 0.038, 0.090) * s
	cure.mesh = caja
	cure.position = Vector3(0.0, 0.017 * s, 0.006 * s)
	cure.material_override = madera
	p.add_child(cure)
	for lado in [-1.0, 1.0]:
		for atras in [-1.0, 1.0]:
			var rueda := MeshInstance3D.new()
			var rc := CylinderMesh.new()
			rc.top_radius = 0.017 * s
			rc.bottom_radius = 0.017 * s
			rc.height = 0.012 * s
			rueda.mesh = rc
			rueda.rotation_degrees.z = 90.0
			rueda.position = Vector3(0.040 * s * lado, 0.012 * s,
				0.030 * s * atras)
			rueda.material_override = madera
			p.add_child(rueda)
	# La direccion LOCAL de la boca y el sitio de reposo, que es lo que
	# necesita `main_menu._disparar_canon` para el fogonazo y el RETROCESO.
	p.set_meta("dir_boca", eje)
	p.set_meta("reposo", p.position)
	p.set_meta("boca", centro + eje * (0.085 * s))
	return p


## EL HUEVO DEL PEZ DEL VIENTO (Link's Awakening): enorme, crema con motas,
## coronando el castillo de popa como corona su montaña.
static func _huevo(pivot: Node3D, s: float, alto: float) -> void:
	# APOYADO EN LA CUBIERTA de verdad (`CUBIERTA`, medida), en el lado de
	# dentro para no pelearse con el cañon, y con las motas moradas EN LA
	# TEXTURA (`huevo_moteado.png`, pintada por PIL y envuelta por la UV de
	# la esfera) — las lentejas 3D del primer intento sobresalian de la
	# cascara, y el huevo entero FLOTABA delante del casco.
	# EN LA CUBIERTA DE POPA (pedido por el usuario): +x es la popa, y ahi la
	# cubierta del castillo esta mas alta que la de proa.
	var p := Node3D.new()
	# Un pelo hacia dentro y CORRIDO HACIA LA CAMARA (pedido por el usuario):
	# centrado en z chocaba con el paño de la vela de mesana, que cruza el
	# barco de banda a banda; adelantado, pasa por delante de ella.
	p.position = Vector3(0.440 * s, alto * POPA_CUBIERTA, -0.095 * s)
	p.add_to_group("no_batch")
	pivot.add_child(p)
	var huevo := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.055 * s
	esfera.height = 0.15 * s
	huevo.mesh = esfera
	huevo.position = Vector3(0.0, 0.072 * s, 0.0)
	var m := _mat(Color(1, 1, 1))
	if ResourceLoader.exists("res://assets/ui/huevo_moteado.png"):
		m.albedo_texture = load("res://assets/ui/huevo_moteado.png")
	else:
		m.albedo_color = Color(0.93, 0.89, 0.78)
	huevo.material_override = m
	p.add_child(huevo)


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
