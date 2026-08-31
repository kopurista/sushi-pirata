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
		quad.size = Vector2(0.19 * s, 0.19 * s)
		cara.mesh = quad
		cara.position = Vector3(-0.115 * s, 0.0, 0.001 * s * lado)
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
	p.position = Vector3(0.475 * s, alto * 0.47, 0.0)
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
	# A z=0.20*s: a 0.185 quedaba EMBEBIDA en la tabla del casco y en captura
	# asomaba un pixel. Y un punto mas alta y gorda, que un ancla de respeto
	# se tiene que ver desde el mapa.
	var p := Node3D.new()
	p.position = Vector3(-0.18 * s, alto * 0.33, 0.19 * s)
	p.add_to_group("no_batch")
	pivot.add_child(p)
	var hierro := _mat(Color(0.16, 0.17, 0.20))
	var cana := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.011 * s
	cil.bottom_radius = 0.011 * s
	cil.height = 0.17 * s
	cana.mesh = cil
	cana.material_override = hierro
	p.add_child(cana)
	var cepo := MeshInstance3D.new()
	var barra := CylinderMesh.new()
	barra.top_radius = 0.007 * s
	barra.bottom_radius = 0.007 * s
	barra.height = 0.075 * s
	cepo.mesh = barra
	# El cepo tambien en el plano del casco (tumbado en x, no saliendo en z).
	cepo.rotation_degrees.z = 90.0
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
	# PLANA CONTRA EL CASCO (pedido por el usuario): los brazos se abren en
	# el plano X-Y, pegados a la tabla, no hacia fuera en z.
	for lado in [-1.0, 1.0]:
		var brazo := MeshInstance3D.new()
		var bc := CylinderMesh.new()
		bc.top_radius = 0.007 * s
		bc.bottom_radius = 0.009 * s
		bc.height = 0.07 * s
		brazo.mesh = bc
		brazo.rotation_degrees.z = 55.0 * lado
		brazo.position = Vector3(0.026 * s * lado, -0.058 * s, 0.0)
		brazo.material_override = hierro
		p.add_child(brazo)
		var una := MeshInstance3D.new()
		var cono := CylinderMesh.new()
		cono.top_radius = 0.0
		cono.bottom_radius = 0.013 * s
		cono.height = 0.030 * s
		una.mesh = cono
		una.position = Vector3(0.052 * s * lado, -0.075 * s, 0.0)
		una.material_override = hierro
		p.add_child(una)


## EL CAÑÓN PIRATA, en cubierta y apuntando al mar por el costado de la
## cámara. Se puede TOCAR en el menú: con la bala de cañón en la vitrina
## DISPARA (ver `main_menu._disparar_canon`), y sin ella Gigi protesta.
static func _canon(pivot: Node3D, s: float, alto: float) -> Node3D:
	# EN MITAD DE LA CUBIERTA, a la vista (donde señaló el usuario: el primer
	# sitio quedaba tragado por el aparejo) y MÁS GRANDE. Hierro oscuro con
	# anillos de bronce y boca marcada, sobre su cureña con ruedas.
	var p := Node3D.new()
	p.name = "ColCanon"
	# Sobre la borda del costado de camara, a media cubierta (donde señaló el
	# usuario) y DE PERFIL: apuntando a la camara el tubo se leia como un
	# circulo. Medido con tinte de sonda: mas adentro la borda se lo tragaba
	# y mas a proa se amontonaba con el ancla.
	p.position = Vector3(-0.02 * s, alto * 0.26, 0.175 * s)
	p.add_to_group("no_batch")
	pivot.add_child(p)
	var hierro := _mat(Color(0.28, 0.29, 0.34))
	var bronce := _mat(Color(0.55, 0.42, 0.20))
	var madera := _mat(Color(0.34, 0.23, 0.12))
	var tubo := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.030 * s
	cil.bottom_radius = 0.040 * s
	cil.height = 0.20 * s
	tubo.mesh = cil
	# DE PERFIL: el tubo a lo largo del eje del barco con la boca hacia PROA
	# (-x) y algo alzada — apuntando a la camara se veia un circulo.
	tubo.rotation_degrees.z = 78.0
	tubo.position = Vector3(-0.01 * s, 0.062 * s, 0.0)
	tubo.material_override = hierro
	p.add_child(tubo)
	# Los anillos de refuerzo y el labio de la boca, en bronce.
	for datos in [[0.085, 0.039], [-0.012, 0.042], [-0.085, 0.045]]:
		var anillo := MeshInstance3D.new()
		var ac := CylinderMesh.new()
		ac.top_radius = float(datos[1]) * s
		ac.bottom_radius = float(datos[1]) * s
		ac.height = 0.013 * s
		anillo.mesh = ac
		anillo.rotation_degrees.z = 78.0
		var d: float = datos[0]
		anillo.position = Vector3((-0.01 - d * 0.978) * s,
			(0.062 + d * 0.208) * s, 0.0)
		anillo.material_override = bronce
		p.add_child(anillo)
	# La direccion LOCAL de la boca, para que el disparo del menu salga por
	# donde apunta el tubo (main_menu._disparar_canon la lee de aqui).
	p.set_meta("dir_boca", Vector3(-0.978, 0.208, 0.25).normalized())
	var cureña := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(0.13, 0.05, 0.095) * s
	cureña.mesh = caja
	cureña.position = Vector3(0.0, 0.020 * s, 0.0)
	cureña.material_override = madera
	p.add_child(cureña)
	for lado in [-1.0, 1.0]:
		var rueda := MeshInstance3D.new()
		var rc := CylinderMesh.new()
		rc.top_radius = 0.028 * s
		rc.bottom_radius = 0.028 * s
		rc.height = 0.018 * s
		rueda.mesh = rc
		rueda.rotation_degrees.x = 90.0
		rueda.position = Vector3(0.054 * s * lado, 0.013 * s, 0.030 * s)
		rueda.material_override = madera
		p.add_child(rueda)
	return p


## EL HUEVO DEL PEZ DEL VIENTO (Link's Awakening): enorme, crema con motas,
## coronando el castillo de popa como corona su montaña.
static func _huevo(pivot: Node3D, s: float, alto: float) -> void:
	# ABAJO, EN CUBIERTA junto al pie del mástil (donde señaló el usuario: en
	# lo alto de popa flotaba), y con las motas moradas EN LA TEXTURA
	# (`huevo_moteado.png`, pintada por PIL y envuelta por la UV de la
	# esfera) — las lentejas 3D del primer intento sobresalían de la cáscara.
	var p := Node3D.new()
	p.position = Vector3(0.005 * s, alto * 0.30, -0.09 * s)
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


## LA VELA DE WIND WAKER: su emblema, calcado del propio coleccionable, como
## calcomanía sobre la vela del MASTIL (por las dos caras, que el timón ya
## deja ver el barco por detrás).
static func _vela_ww(pivot: Node3D, s: float, alto: float) -> void:
	if not ResourceLoader.exists("res://assets/ui/col_vela_emblema.png"):
		return
	# SOLO EL EMBLEMA (`col_vela_emblema.png`, el disco con la medialuna y la
	# ola recortado del propio coleccionable), como calcomania pequeña sobre
	# la vela de POPA. El primer intento pegaba el coleccionable ENTERO — una
	# vela con su marco rojo — y salia una segunda vela gigante tapando media
	# cubierta (visto en captura del usuario). Va en el plano de la vela
	# (normal en x, medido por bandas de vertices) y por las dos caras.
	for lado in [1.0, -1.0]:
		var cara := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.14 * s, 0.14 * s)
		cara.mesh = quad
		cara.position = Vector3((0.176 if lado > 0.0 else 0.064) * s,
			alto * 0.66, 0.0)
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
