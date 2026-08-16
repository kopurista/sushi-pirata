extends Node3D
## Tienda: el TENDERO saca cada día un surtido de 8 ingredientes y vende USOS
## (un uso = poder llevar recetas con ese ingrediente a UN nivel).
##
## - El surtido se renueva solo al cambiar el día (fecha real). El botón
##   "Recargar artículos" vuelve a sortearlo pagando (GameState.SHOP_REROLL_COST).
## - Al tocar un artículo se abre un cartel que pregunta CUÁNTOS quieres,
##   con el total y el dinero que te quedaría.
##
## El fondo es 3D (muelle sobre el mar) con el tendero tras su mostrador; toda
## la interfaz va en un CanvasLayer por delante.

const PrepBoard := preload("res://scripts/prep_board.gd")
const DARK := Color(0.26, 0.16, 0.08)
const COLS := 4

## Saverio SALUDA al entrar y se DESPIDE al salir, con una frase al azar. El
## "%s" es como se llame el jugador (`GameState.player_title`: su nombre si lo
## puso, y si no el título que le corresponda por género).
##
## Cada frase lleva su expresión, que es la mitad del chiste: las de guasa van
## con "riendo" y las de faena con "hablando". Para añadir más, basta con una
## línea; el sorteo no repite la última dicha (`_last_line`), que con diez
## frases salía dos veces seguidas más de lo que parece razonable.
const SALUDOS := [
	{ "text": "¡Bienvenido, %s! Echa un vistazo a lo que traigo hoy.", "mood": "feliz" },
	{ "text": "¡Al loro! Hola, %s, ¿qué te trae hoy por aquí?", "mood": "hablando" },
	{ "text": "¡%s! Justo estaba colocando el género fresco. Llegas de perlas.", "mood": "feliz" },
	{ "text": "Vaya, vaya... si es %s. ¿Vienes a gastar o solo a mirar?", "mood": "riendo" },
	{ "text": "Buenas, %s. Hoy el mar ha sido generoso, mira, mira.", "mood": "explicando" },
	{ "text": "¡Cuánto bueno por el muelle! ¿Qué necesitas, %s?", "mood": "feliz" },
	{ "text": "Pasa, pasa, %s, que no muerdo. El género sí, según cuál.", "mood": "riendo" },
	{ "text": "Te esperaba, %s. Tengo cosas que te van a interesar.", "mood": "hablando" },
	{ "text": "¡Ah, %s! Tú siempre con hambre de despensa, ¿eh?", "mood": "riendo" },
	{ "text": "Adelante, %s. Aquí se mira gratis y se compra barato.", "mood": "explicando" },
	{ "text": "Hola, %s. Si buscas algo raro, has venido al puesto correcto.", "mood": "explicando" },
	{ "text": "¡%s! Descarga esos doblones, que pesan mucho para navegar.", "mood": "riendo" },
]
const DESPEDIDAS := [
	{ "text": "¡Gracias y hasta la próxima, %s!", "mood": "feliz" },
	{ "text": "Buen viaje, %s. Y no me marees el pescado por el camino.", "mood": "riendo" },
	{ "text": "Que la cinta te vaya llena, %s. ¡Aquí te espero!", "mood": "hablando" },
	{ "text": "Hasta luego, %s. Mañana traigo cosas nuevas, no lo olvides.", "mood": "explicando" },
	{ "text": "¡Vuelve cuando quieras, %s! El puesto no se mueve de aquí.", "mood": "feliz" },
	{ "text": "Ale, %s, a cocinar. Que se te enfría el arroz.", "mood": "hablando" },
	{ "text": "Suerte ahí fuera, %s. Y cuidado con los que van armados.", "mood": "serio" },
	{ "text": "Adiós, %s. Si algo sale mal, no fue culpa de mi género.", "mood": "riendo" },
	{ "text": "¡Hasta la vista, %s! Dile a David que me debe una.", "mood": "riendo" },
	{ "text": "Nos vemos, %s. Trae hambre... y monedas.", "mood": "feliz" },
	{ "text": "Ve con viento a favor, %s.", "mood": "hablando" },
	{ "text": "Cierro ya, %s, que el sol se va. ¡A tus fogones!", "mood": "explicando" },
]

## Última frase dicha, para no repetirla justo después.
var _last_line := ""

var money_label: Label = null
var reroll_button: Button = null
## Lado del botón redondo de recargar el surtido.
const REROLL_SIZE := 108.0
var grid: GridContainer = null
var extras_row: HBoxContainer = null
var ui: CanvasLayer = null
## Raíz de la interfaz 2D, para colgar de ella los carteles modales.
var ui_root: Control = null
var shopkeeper: Node3D = null
## Sprites del género expuesto en el mostrador (se rehacen al recargar).
var goods_root: Node3D = null
var _t := 0.0




func _ready() -> void:
	# Las pantallas de menu van a la mitad de fotogramas que el juego
	# (GameState.fps_for): aqui no se juega y renderizar mas gasta bateria.
	Engine.max_fps = GameState.fps_for(false)
	GameState.refresh_shop_if_new_day()
	# El escenario es el MISMO muelle del nivel de puerto (mar animado + tarima
	# girada 45º con pilotes, norays y farol); lo que cambia es el centro: en
	# vez de la cinta y el chef, el puesto de Saverio. Por eso el fondo se pide
	# con kind "mar" (solo agua) y el muelle se construye aquí.
	SceneBackdrop.build(self, "mar", 13.0, 232.0, 5.0)
	_build_dock()
	_setup_shopkeeper()
	# El mostrador y los cajones son fijos: una malla por color.
	GeometryBatch.bake(self, "ShopBatch")
	_setup_ui()
	_refresh()
	# Se llega desde el negro del menú: el velo es del autoload y lo abre él
	# solo, aquí solo se consume la marca de transición.
	GameState.take_transition()
	# La presentación de Saverio ya NO vive aquí: ocurre en el puerto del nivel
	# 2, que es donde él está. Lo que sí puede pasar al entrar es la visita de
	# Pablo el Rubio, una vez superado su nivel.
	if _toca_pablo():
		_pablo_y_saverio.call_deferred()
	else:
		_saludar.call_deferred()


## Saverio saluda al entrar, con una frase al azar. Es solo un apunte: la caja
## se cierra sola al tocarla y no bloquea nada de la tienda.
func _saludar() -> void:
	# DOS FOTOGRAMAS de margen: el primero después de montar la escena trae un
	# delta enorme (todo lo que ha tardado en cargar) y el tween de entrada de
	# la caja se lo saltaba de golpe, así que el fundido no se veía nunca.
	await get_tree().process_frame
	await get_tree().process_frame
	var caja := DialogueBox.new()
	ui.add_child(caja)
	caja.say([_pick(SALUDOS)])
	await caja.finished
	caja.queue_free()


## Y se despide al salir. La salida ESPERA a la frase: si se fundiera a negro a
## la vez, se leería media línea.
func _despedir() -> void:
	var caja := DialogueBox.new()
	ui.add_child(caja)
	caja.say([_pick(DESPEDIDAS)])
	await caja.finished
	caja.queue_free()
	GameState.fade_to_scene("res://scenes/main_menu.tscn", 0.35, 0.45)


## Una frase al azar de la lista, con el nombre del jugador ya puesto y sin
## repetir la anterior.
func _pick(lista: Array) -> Dictionary:
	var elegida: Dictionary = lista[randi() % lista.size()]
	for _intento in 4:
		if str(elegida["text"]) != _last_line:
			break
		elegida = lista[randi() % lista.size()]
	_last_line = str(elegida["text"])
	return {
		"text": str(elegida["text"]) % GameState.player_title(),
		"who": "saverio", "mood": str(elegida["mood"]),
	}


## David lleva al jugador a conocer a Saverio. David habla desde la IZQUIERDA y
## Saverio desde la DERECHA (los dos en pantalla a la vez, ver DialogueBox).
## Al terminar quedan desbloqueados los EXTRAS, con 5 usos de regalo de cada uno.
## ¿Toca la escena de Pablo? Solo una vez, y solo con SU nivel (el 8, el de
## la flota) superado.
func _toca_pablo() -> bool:
	if GameState.pablo_shop_done:
		return false
	var p8 := CampaignData.get_port("nivel_8")
	return int(GameState.level_stars.get("nivel_8", 0)) 			>= int(p8.get("goal_stars", 2))


## Pablo el Rubio se pasa por el puesto. Los dos hablan desde la DERECHA (es su
## lado en DialogueBox), así que se van turnando el retrato: David no está en
## esta escena y el sitio de la izquierda queda vacío a propósito.
func _pablo_y_saverio() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var caja := DialogueBox.new()
	ui.add_child(caja)
	# PABLO A LA IZQUIERDA solo aquí: su lado de siempre es la derecha porque
	# comparte pantalla con David, pero Saverio también sale por la derecha y
	# los dos se turnaban el mismo hueco con media pantalla vacía.
	caja.say([
		{ "text": "¡Saveriooo! Cuánto tiempo sin dejarme robar nada.", "who": "pablo", "mood": "riendo", "side": "left" },
		{ "text": "Pablo. Como te acerques a mis barriles te clavo el remo.", "who": "saverio", "mood": "serio" },
		{ "text": "Tranquilo, hoy vengo de cliente. Este de aquí me abordó la flota entera y me dejó la tripulación llena hasta las cejas.", "who": "pablo", "mood": "guason", "side": "left" },
		{ "text": "¿Este? ¿El de David? Vaya, vaya... entonces sí que sabe cocinar.", "who": "saverio", "mood": "feliz" },
		{ "text": "Sabe. Y por eso vengo a avisarte: si le vendes barato, me lo llevo yo de cocinero.", "who": "pablo", "mood": "punal", "side": "left" },
		{ "text": "Ni lo sueñes. Anda, toma tu té y déjame trabajar.", "who": "saverio", "mood": "riendo" },
		{ "text": "Vendré a verte, cocinero. Y no traeré el puñal... casi seguro.", "who": "pablo", "mood": "riendo", "side": "left" },
	])
	await caja.finished
	caja.queue_free()
	GameState.pablo_shop_done = true
	GameState.save_game()
	_refresh()


## El tendero, en su puesto, MONTADO SOBRE UN MUELLE: antes el mostrador
## flotaba sobre el agua y parecía que vendía a nado.
## Muelle del nivel de puerto: tarima girada 45º con su canto, pilotes, norays
## y farol. Misma madera gris azulada que en el nivel (el marrón cálido es la
## del barco, y con ella los dos escenarios se confundían).
## Madera del muelle: la textura clara de tablas del puerto, tintada de gris
## azulado (la marrón cálida es la del barco y los dos escenarios se confundían).
func _wood(tinte: Color, uv: float, cual := "madera_muelle") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tinte
	m.roughness = 0.95
	var ruta := "res://assets/props/%s.webp" % cual
	if ResourceLoader.exists(ruta):
		m.albedo_texture = load(ruta)
		m.uv1_scale = Vector3(uv, uv, 1.0)
	return m


func _build_dock() -> void:
	var tabla := Color(0.74, 0.78, 0.80)
	var poste := Color(0.48, 0.50, 0.52)
	# OJO con la altura: el plano del mar del fondo está en y=0, así que una
	# tarima con la cara superior justo en 0 pelea por profundidad y sale a
	# franjas. Se levanta un poco sobre el agua.
	var deck := _box_ret(Vector3(13.0, 0.30, 12.4), Vector3(1.1, 0.06, 1.3), tabla)
	deck.rotation_degrees.y = 45.0
	deck.material_override = _wood(Color(0.86, 0.88, 0.90), 3.2)
	var canto := _box_ret(Vector3(12.4, 0.62, 11.8), Vector3(1.1, -0.35, 1.3), poste)
	canto.rotation_degrees.y = 45.0
	# Pilotes asomando por los bordes.
	for pp in [Vector3(-5.3, 0.0, -1.6), Vector3(-1.9, 0.0, -5.4),
			Vector3(7.5, 0.0, 4.2), Vector3(4.1, 0.0, 8.0),
			Vector3(-5.5, 0.0, 5.2), Vector3(7.1, 0.0, -3.4)]:
		_cyl_ret(0.16, 0.18, 1.15, pp + Vector3(0.0, 0.45, 0.0), Color(0.35, 0.26, 0.15))
		_cyl_ret(0.20, 0.22, 0.14, pp + Vector3(0.0, 1.08, 0.0), Color(0.30, 0.22, 0.13))
	# Norays de amarre con su cabo enrollado.
	for bb in [Vector3(-3.4, 0.0, 4.9), Vector3(6.0, 0.0, -0.6)]:
		_cyl_ret(0.17, 0.21, 0.5, bb + Vector3(0.0, 0.25, 0.0), Color(0.22, 0.20, 0.19))
		_cyl_ret(0.26, 0.26, 0.09, bb + Vector3(0.0, 0.16, 0.0), Color(0.52, 0.42, 0.26))
	_dock_railing()
	# Farol de muelle. Va apartado del puesto: en el sitio de antes, el toldo le
	# tapaba el poste y solo se veía la caja de la luz, flotando en el aire.
	var fx := Vector3(-4.3, 0.0, -1.7)
	_cyl_ret(0.09, 0.12, 2.6, fx + Vector3(0.0, 1.3, 0.0), Color(0.30, 0.30, 0.32))
	_box(Vector3(0.34, 0.42, 0.34), fx + Vector3(0.0, 2.75, 0.0), Color(0.33, 0.30, 0.20))
	var luz := OmniLight3D.new()
	luz.position = fx + Vector3(0.0, 2.75, 0.0)
	luz.light_color = Color(1.0, 0.82, 0.5)
	luz.light_energy = 1.2
	luz.omni_range = 5.0
	luz.shadow_enabled = false
	add_child(luz)


## Valla en el BORDE DE ARRIBA del muelle, para que la tarima no acabe al aire
## y nadie parezca a punto de caerse al agua.
##
## La tarima es un cuadrado GIRADO 45°, así que sus cuatro esquinas caen en los
## ejes de la pantalla y el borde de arriba es UNA sola arista recta que cruza
## de lado a lado: por eso basta una valla y va en horizontal, no en diagonal.
## Sus dos extremos son las esquinas de la tarima, calculadas con los mismos
## semiejes girados que usa `deck` (13.0 x 12.4 centrada en 1.1, 1.3).
func _dock_railing() -> void:
	var madera := Color(0.42, 0.31, 0.20)
	var a := Vector3(-7.55, 0.21, 1.35)     ## esquina de la izquierda
	var b := Vector3(1.15, 0.21, -7.35)     ## esquina de la derecha
	var largo := a.distance_to(b)
	var dir := (b - a).normalized()
	var n := 11
	for i in n + 1:
		var p := a + dir * (largo * i / float(n))
		_box(Vector3(0.16, 1.0, 0.16), p + Vector3(0.0, 0.5, 0.0), madera)
	# Dos travesaños, girados para seguir la arista.
	for y in [0.86, 0.50]:
		var rail := _box_ret(Vector3(largo, 0.11, 0.09),
			(a + b) * 0.5 + Vector3(0.0, y, 0.0), Color(0.50, 0.37, 0.24))
		rail.rotation_degrees.y = 45.0


## Como _box/_cyl pero devolviendo el nodo, para poder girarlo.
func _box_ret(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	mi.material_override = m
	add_child(mi)
	return mi


func _cyl_ret(rt: float, rb: float, hh: float, pos: Vector3,
		color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = rt
	mesh.bottom_radius = rb
	mesh.height = hh
	mesh.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	mi.material_override = m
	add_child(mi)
	return mi


func _setup_shopkeeper() -> void:
	shopkeeper = SceneBackdrop._spawn_model(self,
		load("res://assets/models/tendero.glb"), 1.5)
	shopkeeper.position = Vector3(1.2, 0.03, 1.2)
	shopkeeper.rotation_degrees.y = 0.0
	_build_stall()
	_place_goods()


## EL PUESTO DE SAVERIO. Antes era literalmente una caja marrón lisa con dos
## cubos al lado y no se leía como una tienda, sino como una mesa.
##
## Todo va con MADERA DE VERDAD (las tres texturas de `assets/props`), no con
## colores planos, y los cajones y el barril son los MODELOS que ya existen
## (`caja.glb`, `barril.glb`), que traen su textura y su presupuesto.
##
## EL TOLDO VA AL REVÉS QUE UN TOLDO DE VERDAD, y es a propósito. Con el picado
## isométrico de 35°, un toldo que caiga hacia el espectador —lo normal— se
## dibuja JUSTO ENCIMA del tendero y lo deja en sombra: se probó y solo se le
## veían las piernas. Aquí sube hacia delante, como una marquesina abierta, así
## que su borde queda por encima de la cabeza y se ve al tendero entero. Además
## el techo termina ANTES del mostrador (z=1.9 frente a 2.75), o taparía el
## género que se expone encima.
const STALL_X := 1.15          ## eje del puesto
const COUNTER_Z := 2.75        ## dónde se apoya el cliente
const AWNING_FRONT := 1.9      ## hasta dónde llega el techo (ver arriba)


func _build_stall() -> void:
	_counter()
	_frame_and_awning()
	_back_shelf()
	_stall_props()


## Mostrador: cuerpo de tablas, tablero de encima más claro y un zócalo que lo
## despega del suelo. El tablero sobresale por los cuatro lados, que es lo que
## hace que parezca un mueble y no un bloque.
func _counter() -> void:
	var frente := _wood(Color(0.60, 0.40, 0.22), 2.2, "madera_caja")
	var tablero := _wood(Color(0.82, 0.66, 0.44), 1.6, "madera_muelle")
	var oscuro := _wood(Color(0.40, 0.27, 0.15), 1.4, "madera_desgastada")

	var cuerpo := _box_ret(Vector3(4.5, 0.86, 1.35),
		Vector3(STALL_X, 0.47, COUNTER_Z), Color.WHITE)
	cuerpo.material_override = frente
	# Zócalo retranqueado: da sombra propia bajo el mueble.
	var pie := _box_ret(Vector3(4.2, 0.12, 1.1),
		Vector3(STALL_X, 0.06, COUNTER_Z), Color.WHITE)
	pie.material_override = oscuro
	var tabla := _box_ret(Vector3(4.9, 0.14, 1.72),
		Vector3(STALL_X, 0.97, COUNTER_Z), Color.WHITE)
	tabla.material_override = tablero
	# Listón de canto al frente, para que el tablero no sea una loncha.
	var canto := _box_ret(Vector3(4.9, 0.10, 0.12),
		Vector3(STALL_X, 0.88, COUNTER_Z + 0.80), Color.WHITE)
	canto.material_override = oscuro


## Cuatro postes, viga delantera, el TOLDO A RAYAS y su faldón. Las rayas son
## listones alternos: en low poly sale mejor que una textura rayada, que a esta
## distancia se vería emborronada.
func _frame_and_awning() -> void:
	var poste_mat := _wood(Color(0.46, 0.31, 0.17), 1.0, "madera_desgastada")
	var back_z := -0.15
	var alto_atras := 2.45
	var alto_delante := 3.05
	for px in [STALL_X - 2.45, STALL_X + 2.45]:
		var p1 := _box_ret(Vector3(0.17, alto_atras, 0.17),
			Vector3(px, alto_atras * 0.5, back_z), Color.WHITE)
		p1.material_override = poste_mat
		var p2 := _box_ret(Vector3(0.17, alto_delante, 0.17),
			Vector3(px, alto_delante * 0.5, AWNING_FRONT), Color.WHITE)
		p2.material_override = poste_mat
	# Vigas que unen los postes por arriba.
	var v1 := _box_ret(Vector3(5.15, 0.15, 0.15),
		Vector3(STALL_X, alto_atras, back_z), Color.WHITE)
	v1.material_override = poste_mat
	var v2 := _box_ret(Vector3(5.15, 0.15, 0.15),
		Vector3(STALL_X, alto_delante, AWNING_FRONT), Color.WHITE)
	v2.material_override = poste_mat

	# El techo: listones alternos rojo/crema, inclinados de atrás a delante.
	var largo := AWNING_FRONT - back_z
	var pend := atan2(alto_atras - alto_delante, largo)
	var n := 12
	for i in n:
		var t := (i + 0.5) / float(n)
		var col := Color(0.72, 0.20, 0.18) if i % 2 == 0 else Color(0.94, 0.90, 0.80)
		var slat := _box_ret(Vector3(5.3, 0.09, largo / float(n) + 0.01),
			Vector3(STALL_X, lerpf(alto_atras, alto_delante, t) + 0.10,
				lerpf(back_z, AWNING_FRONT, t)), col)
		slat.rotation_degrees.x = -rad_to_deg(pend)
	# Faldón: pestañas colgando del borde BAJO del techo, que con esta cámara es
	# el de atrás y es el único que se ve de canto. Colgadas del borde alto
	# quedaban detrás del propio toldo y solo asomaba una, suelta, como un
	# trapo pegado al poste.
	for i in 11:
		var col := Color(0.72, 0.20, 0.18) if i % 2 == 0 else Color(0.94, 0.90, 0.80)
		_box(Vector3(0.42, 0.24, 0.06),
			Vector3(STALL_X - 2.3 + i * 0.46, alto_atras - 0.02, back_z - 0.08), col)


## Estantería a la espalda del tendero. Da fondo al puesto: sin ella se veía el
## mar por detrás y el tendero parecía suelto. Aquí van solo las TABLAS; lo que
## se guarda en ellas lo pone `_place_goods`, porque cambia con el surtido.
const SHELF_Z := 0.09          ## fondo de las baldas
const SHELF_Y := [0.86, 1.56]  ## altura de cada balda (la cara de arriba)


func _back_shelf() -> void:
	var mat := _wood(Color(0.50, 0.34, 0.19), 1.8, "madera_desgastada")
	var back_z := -0.05
	var pared := _box_ret(Vector3(4.4, 1.9, 0.12),
		Vector3(STALL_X, 0.95, back_z - 0.12), Color.WHITE)
	pared.material_override = mat
	for y in SHELF_Y:
		var balda := _box_ret(Vector3(4.3, 0.09, 0.44),
			Vector3(STALL_X, y - 0.045, SHELF_Z), Color.WHITE)
		balda.material_override = _wood(Color(0.70, 0.52, 0.30), 1.4, "madera_muelle")


## Tiñe un modelo ya instanciado sin tocar el original: `albedo_color`
## MULTIPLICA a la textura, así que la madera conserva sus vetas y solo cambia
## de tono. Hay que DUPLICAR el material o se tiñen también las cajas del nivel
## del barco, que comparten el mismo `.glb`.
func _tint(node: Node3D, tinte: Color) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		for s in m.get_surface_count():
			var mat := m.surface_get_material(s)
			if mat is StandardMaterial3D:
				var copia: StandardMaterial3D = mat.duplicate()
				copia.albedo_color = copia.albedo_color * tinte
				(mi as MeshInstance3D).set_surface_override_material(s, copia)


## Cajones y barril del costado: los MODELOS con textura, no cubos de color.
##
## Las cajas van TEÑIDAS porque de fábrica tiran a terracota y al lado del
## barril parecían de barro cocido. El tinte NO está puesto a ojo: se midió el
## tono medio de las dos texturas —caja (0.53, 0.24, 0.15), barril (0.49, 0.31,
## 0.07)— y esto es la proporción entre ambos, normalizada para no pasar de 1.
## Un tinte gris "más oscuro" no valía: `albedo_color` MULTIPLICA, así que
## oscurece sin corregir el TONO, y la caja seguía igual de naranja.
const CRATE_TINT := Color(0.70, 1.00, 0.37)


func _stall_props() -> void:
	# La tarima del muelle tiene su cara superior en y=0.21: los modelos van
	# apoyados AHÍ, no en y=0, o se hunden un palmo en las tablas.
	var suelo := 0.21
	for d in [{"m": "caja", "p": Vector3(4.30, suelo, 2.60), "f": 0.80, "r": 18.0},
			{"m": "caja", "p": Vector3(4.20, suelo + 0.80, 2.52), "f": 0.62, "r": -24.0},
			{"m": "barril", "p": Vector3(4.70, suelo, 1.55), "f": 0.82, "r": 0.0}]:
		var ruta: String = "res://assets/models/%s.glb" % d["m"]
		if not ResourceLoader.exists(ruta):
			continue
		var n := SceneBackdrop._spawn_model(self, load(ruta), float(d["f"]))
		n.position = d["p"]
		n.rotation_degrees.y = float(d["r"])
		if d["m"] == "caja":
			_tint(n, CRATE_TINT)


## El género EN EL PUESTO: los ocho artículos del día sobre el tablero y, en
## las baldas de atrás, EL MISMO GÉNERO como reserva. Antes las baldas llevaban
## cilindros y cajitas de color, que a la vista eran figuras geométricas sin
## significado; ahora se ve lo que vende también en la trastienda.
##
## Va todo aquí, y no en `_back_shelf`, porque el surtido cambia al recargarlo
## y esto se reconstruye entero en cada `_refresh`.
func _place_goods() -> void:
	if goods_root != null:
		goods_root.queue_free()
	goods_root = Node3D.new()
	add_child(goods_root)
	var stock := GameState.shop_stock
	for i in stock.size():
		# 0.62 u de alto: caben ocho en el tablero sin amontonarse.
		_good(str(stock[i]), Vector3(-0.55 + (i % 4) * 1.15, 1.32,
			2.35 + (i / 4) * 0.78), 0.62)
	# La reserva de las baldas: cuatro por balda, más pequeña, y empezando por
	# el final del surtido para que no se repita el mismo orden que el tablero.
	if stock.is_empty():
		return
	for b in SHELF_Y.size():
		for i in 4:
			var id := str(stock[(stock.size() - 1 - (b * 4 + i)) % stock.size()])
			_good(id, Vector3(STALL_X - 1.55 + i * 1.03,
				SHELF_Y[b] + 0.21, SHELF_Z), 0.42)


func _good(id: String, pos: Vector3, alto: float) -> void:
	var tex := RecipeData.get_ingredient_texture(id)
	if tex == null:
		return
	var s := Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.transparent = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.pixel_size = alto / float(maxi(tex.get_height(), 1))
	s.position = pos
	goods_root.add_child(s)


func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	mi.material_override = m
	add_child(mi)


func _process(delta: float) -> void:
	_t += delta
	if shopkeeper != null and GameState.animations_on():
		# Respira y se balancea: no tiene esqueleto, así que la vida se la da
		# el propio pivote.
		shopkeeper.position.y = sin(_t * 1.6) * 0.03
		shopkeeper.rotation_degrees.y = sin(_t * 0.5) * 7.0
		shopkeeper.rotation_degrees.z = sin(_t * 0.9 + 0.6) * 1.2


# ----------------------------------------------------------------------- UI

func _setup_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	ui_root = root
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Bajo el notch del movil (la balda de abajo ancla al borde inferior y no
	# se mueve).
	root.offset_top = GameState.safe_top()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	# Barra superior: volver + título + monedero.
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 18.0
	bar.offset_top = 20.0
	bar.offset_right = -18.0
	bar.offset_bottom = 88.0
	bar.add_theme_constant_override("separation", 10)
	root.add_child(bar)
	# Flecha DIBUJADA en la madera (PrepBoard.make_back_button): es el
	# único botón del juego con icono propio, para no confundirlo con
	# un botón normal más.
	var back := PrepBoard.make_back_button()
	# Se vuelve con un fundido a negro normal y corriente, igual que el
	# inventario: deshacer el atraque no aportaba nada y se hacía largo. Antes
	# del fundido, Saverio se despide (y el fundido lo lanza él al acabar).
	back.pressed.connect(_despedir)
	bar.add_child(back)
	# El rótulo va sobre su CINTA de tela (PrepBoard.make_title):
	# el mismo aire de cartel que el resto del set.
	var title := PrepBoard.make_title("Tienda")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	bar.add_child(_make_money_box())

	# Aviso del tendero, en una TABLILLA CON CLAVOS (la misma del nombre de
	# quien habla) en vez de un texto suelto sobre el 3D.
	var hint_sign := Control.new()
	hint_sign.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint_sign.offset_left = 96.0
	hint_sign.offset_right = -96.0
	hint_sign.offset_top = 104.0
	hint_sign.offset_bottom = 104.0 + PrepBoard.PLATE_H
	hint_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint_sign)
	hint_sign.add_child(PrepBoard.make_hstretch_patch(
		PrepBoard.PLATE_TEX, PrepBoard.PLATE_CAP))
	var hint := Label.new()
	hint.text = "Saverio trae género nuevo cada día"
	hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 21)
	hint.add_theme_color_override("font_color", Color(1, 0.96, 0.84))
	hint.add_theme_color_override("font_outline_color", Color(0.16, 0.07, 0.02))
	hint.add_theme_constant_override("outline_size", 7)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_sign.add_child(hint)

	# Mostrador de artículos: 8 huecos en 2 filas sobre un pergamino.
	var shelf := Control.new()
	shelf.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shelf.offset_left = 14.0
	shelf.offset_right = -14.0
	# Más abajo Y más alta: el género entra más grande y se lee mejor.
	# Pegada abajo (el hueco dejaba ver el agua) y RECORTADA por arriba: con
	# -700 sobraba pergamino vacío sobre la primera fila de género.
	shelf.offset_top = -640.0
	shelf.offset_bottom = -30.0
	root.add_child(shelf)
	shelf.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))
	# La parrilla va dentro de un centrador: con anclas a los lados las tarjetas
	# se apelotonaban a la izquierda y quedaban descentradas en la balda.
	var grid_box := CenterContainer.new()
	grid_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_box.offset_left = 52.0
	grid_box.offset_top = 36.0
	grid_box.offset_right = -52.0
	grid_box.offset_bottom = -158.0
	grid_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shelf.add_child(grid_box)
	grid = GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 10)
	grid_box.add_child(grid)
	# Los tres EXTRAS de siempre, pequeños y centrados en su propia balda: no
	# cambian nunca, no compiten con el género del día.
	extras_row = HBoxContainer.new()
	extras_row.alignment = BoxContainer.ALIGNMENT_CENTER
	extras_row.add_theme_constant_override("separation", 26)
	extras_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	extras_row.offset_left = 44.0
	extras_row.offset_right = -44.0
	extras_row.offset_top = -150.0
	extras_row.offset_bottom = -62.0
	shelf.add_child(extras_row)

	# Recargar el surtido: un icono PEQUEÑO sobrepuesto en la parte baja de la
	# balda, no un botón a lo ancho que se comía media pantalla.
	# Recargar el surtido: botón REDONDO con icono, al estilo de los del barco y
	# el combinado, en la esquina inferior derecha de la balda.
	reroll_button = Button.new()
	reroll_button.custom_minimum_size = Vector2(REROLL_SIZE, REROLL_SIZE)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		reroll_button.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	reroll_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	reroll_button.offset_left = -REROLL_SIZE - 30.0
	reroll_button.offset_right = -30.0
	reroll_button.offset_top = -REROLL_SIZE - 14.0
	reroll_button.offset_bottom = -14.0
	reroll_button.pressed.connect(func() -> void:
		# Bote al pulsar: el disco no se hunde solo como el tablón de madera.
		reroll_button.pivot_offset = reroll_button.size * 0.5
		var tw := reroll_button.create_tween()
		tw.tween_property(reroll_button, "scale", Vector2(0.86, 0.86), 0.08)
		tw.tween_property(reroll_button, "scale", Vector2.ONE, 0.16) 				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_on_reroll())
	shelf.add_child(reroll_button)
	var disco := TextureRect.new()
	disco.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	disco.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	disco.texture = _disc_texture()
	disco.set_anchors_preset(Control.PRESET_FULL_RECT)
	disco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reroll_button.add_child(disco)
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists("res://assets/ui/ic_recargar.png"):
		ic.texture = load("res://assets/ui/ic_recargar.png")
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 16.0
	ic.offset_top = 10.0
	ic.offset_right = -16.0
	ic.offset_bottom = -30.0
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reroll_button.add_child(ic)
	# El precio, con la MONEDA del juego en vez del símbolo del dólar.
	var precio := HBoxContainer.new()
	precio.alignment = BoxContainer.ALIGNMENT_CENTER
	precio.add_theme_constant_override("separation", 2)
	precio.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	precio.offset_top = -32.0
	precio.offset_bottom = -6.0
	precio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reroll_button.add_child(precio)
	var mon := TextureRect.new()
	mon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mon.texture = load("res://assets/ui/moneda.png")
	mon.custom_minimum_size = Vector2(22, 22)
	precio.add_child(mon)
	var pl2 := Label.new()
	pl2.text = "%d" % GameState.SHOP_REROLL_COST
	pl2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pl2.add_theme_font_size_override("font_size", 20)
	pl2.add_theme_color_override("font_color", Color(1.0, 0.93, 0.72))
	pl2.add_theme_color_override("font_outline_color", Color.BLACK)
	pl2.add_theme_constant_override("outline_size", 6)
	precio.add_child(pl2)


## El monedero, en la MISMA caja que el menú principal: el dinero se lee igual
## en todas las pantallas donde se puede ganar o gastar.
func _make_money_box() -> Control:
	var box := PrepBoard.make_resource_box(
		"res://assets/ui/moneda.png", str(GameState.money), 158.0)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	money_label = box.get_node("Valor")
	return box


## Repinta el surtido y los contadores.
func _refresh() -> void:
	money_label.text = "%d" % GameState.money
	reroll_button.disabled = GameState.money < GameState.SHOP_REROLL_COST
	for c in grid.get_children():
		c.queue_free()
	for ing in GameState.shop_stock:
		grid.add_child(_build_item(ing))
	# Los EXTRAS (jengibre, wasabi, soja) no entran en el sorteo del día: el
	# tendero los tiene SIEMPRE, pequeños y centrados en su propia balda.
	for c in extras_row.get_children():
		c.queue_free()
	if GameState.extras_unlocked():
		for ing in RecipeData.EXTRAS:
			extras_row.add_child(_build_item(ing, true))


## Un artículo del mostrador: icono, nombre, precio unitario y usos que ya
## tienes. Al pulsarlo se pregunta cuántos quieres.
## Tarjeta compacta de EXTRA: icono, nombre y precio · cantidad debajo.
## SIN fondo propio (el botón trae un panel oscuro del tema por defecto que
## sobre el pergamino parecía una mancha y tapaba lo que era el artículo).
func _fill_small_item(b: Button, ing: String, data: Dictionary, cost: int) -> Button:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = RecipeData.get_ingredient_texture(ing)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 8.0
	icon.offset_top = 2.0
	icon.offset_right = -8.0
	icon.offset_bottom = -58.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var name_l := Label.new()
	name_l.text = str(data.get("name", ing))
	name_l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_l.offset_top = -56.0
	name_l.offset_bottom = -30.0
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 16)
	name_l.add_theme_color_override("font_color", DARK)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name_l)
	var info := Label.new()
	info.text = "%d · x%d" % [cost, GameState.get_ingredient_uses(ing)]
	info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	info.offset_top = -28.0
	info.offset_bottom = -2.0
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 18)
	info.add_theme_color_override("font_color", Color(0.45, 0.33, 0.2))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(info)
	b.pressed.connect(_open_buy_dialog.bind(ing))
	return b


func _build_item(ing: String, small: bool = false) -> Button:
	var data: Dictionary = RecipeData.INGREDIENTS.get(ing, {})
	var cost := int(data.get("cost", 0))
	var b := Button.new()
	b.custom_minimum_size = Vector2(96, 104) if small else Vector2(126, 168)
	if small:
		return _fill_small_item(b, ing, data, cost)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())

	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = RecipeData.get_ingredient_texture(ing)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 6.0
	icon.offset_top = 4.0
	icon.offset_right = -6.0
	icon.offset_bottom = -74.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)

	var name_l := Label.new()
	name_l.text = str(data.get("name", ing))
	name_l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	# Alto para DOS líneas: "Huevas de salmón" partía en dos y la segunda se
	# comía la fila del precio.
	name_l.offset_top = -68.0
	name_l.offset_bottom = -32.0
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.add_theme_font_size_override("font_size", 16)
	name_l.add_theme_color_override("font_color", DARK)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name_l)

	var price := HBoxContainer.new()
	price.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	price.offset_top = -30.0
	price.offset_bottom = -4.0
	price.alignment = BoxContainer.ALIGNMENT_CENTER
	price.add_theme_constant_override("separation", 3)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := TextureRect.new()
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture = load("res://assets/ui/moneda.png")
	coin.custom_minimum_size = Vector2(22, 22)
	price.add_child(coin)
	var pl := Label.new()
	pl.text = "%d · x%d" % [cost, GameState.get_ingredient_uses(ing)]
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pl.add_theme_font_size_override("font_size", 18)
	pl.add_theme_color_override("font_color", Color(0.4, 0.26, 0.02))
	price.add_child(pl)
	b.add_child(price)


	b.pressed.connect(_open_buy_dialog.bind(ing))
	return b


## Recargar cuesta dinero, así que se pregunta antes: el icono es pequeño y se
## pulsa sin querer con facilidad.
func _on_reroll() -> void:
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280.0
	panel.offset_top = -170.0
	panel.offset_right = 280.0
	panel.offset_bottom = 130.0
	panel.z_index = 120
	panel.pivot_offset = Vector2(280.0, 150.0)
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))
	ui_root.add_child(panel)
	panel.scale = Vector2(0.6, 0.6)
	panel.modulate.a = 0.0
	var entra := panel.create_tween().set_parallel(true)
	entra.tween_property(panel, "scale", Vector2.ONE, 0.26) 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entra.tween_property(panel, "modulate:a", 1.0, 0.18)

	var texto := Label.new()
	texto.text = "¿Recargar los artículos\npor %d doblones?" % GameState.SHOP_REROLL_COST
	texto.set_anchors_preset(Control.PRESET_TOP_WIDE)
	texto.offset_left = 56.0
	texto.offset_right = -56.0
	texto.offset_top = 62.0
	texto.offset_bottom = 180.0
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.add_theme_font_size_override("font_size", 26)
	texto.add_theme_color_override("font_color", Color(0.26, 0.16, 0.08))
	panel.add_child(texto)

	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 22)
	fila.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	fila.offset_left = 44.0
	fila.offset_right = -44.0
	fila.offset_top = -108.0
	fila.offset_bottom = -40.0
	panel.add_child(fila)
	for opcion in [["Sí", true], ["No", false]]:
		var b := Button.new()
		b.text = str(opcion[0])
		b.custom_minimum_size = Vector2(196, 72)
		var si: bool = bool(opcion[1])
		PrepBoard.skin_action_button(b, si)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(func() -> void:
			var sale := panel.create_tween().set_parallel(true)
			sale.tween_property(panel, "scale", Vector2(0.7, 0.7), 0.2) 					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			sale.tween_property(panel, "modulate:a", 0.0, 0.2)
			sale.chain().tween_callback(panel.queue_free)
			if si and GameState.reroll_shop():
				_refresh()
				_place_goods())
		fila.add_child(b)


# ------------------------------------------------- cartel de "¿cuántos?"

## Cartel modal: cuántos usos quiere el jugador de ESE ingrediente.
func _open_buy_dialog(ing: String) -> void:
	var data: Dictionary = RecipeData.INGREDIENTS.get(ing, {})
	var cost := int(data.get("cost", 1))
	# La cantidad vive en un diccionario A PROPOSITO: las lambdas de GDScript
	# capturan las variables locales POR VALOR, asi que con un `var qty` las
	# flechas incrementaban su propia copia y el cartel no cambiaba nunca.
	var state := { "qty": 1 }

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var box := Control.new()
	box.custom_minimum_size = Vector2(560, 520)
	box.pivot_offset = Vector2(280, 260)
	center.add_child(box)
	box.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 62.0
	vb.offset_top = 54.0
	vb.offset_right = -62.0
	vb.offset_bottom = -46.0
	vb.add_theme_constant_override("separation", 10)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(vb)

	var title := Label.new()
	title.text = "¿Cuánto quieres?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", DARK)
	vb.add_child(title)

	var icon := TextureRect.new()
	icon.texture = RecipeData.get_ingredient_texture(ing)
	icon.custom_minimum_size = Vector2(0, 150)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(icon)

	# Selector de cantidad con las flechas de madera.
	var qty_row := HBoxContainer.new()
	qty_row.alignment = BoxContainer.ALIGNMENT_CENTER
	qty_row.add_theme_constant_override("separation", 16)
	var minus := _make_arrow("<")
	var qty_l := Label.new()
	qty_l.custom_minimum_size = Vector2(90, 0)
	qty_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qty_l.add_theme_font_size_override("font_size", 44)
	qty_l.add_theme_color_override("font_color", DARK)
	var plus := _make_arrow(">")
	qty_row.add_child(minus)
	qty_row.add_child(qty_l)
	qty_row.add_child(plus)
	vb.add_child(qty_row)

	var total_l := Label.new()
	total_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_l.add_theme_font_size_override("font_size", 27)
	total_l.add_theme_color_override("font_color", DARK)
	vb.add_child(total_l)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	var cancel := Button.new()
	cancel.text = "Cancelar"
	cancel.custom_minimum_size = Vector2(216, 80)
	PrepBoard.skin_action_button(cancel, false)
	cancel.add_theme_font_size_override("font_size", 23)
	cancel.pressed.connect(overlay.queue_free)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(216, 80)
	buy.text = "Comprar"
	# Moneda, no visto verde: es una COMPRA, no una confirmación cualquiera.
	buy.custom_minimum_size.y = PrepBoard.ICON_BTN_H
	PrepBoard.skin_icon_button(buy, "res://assets/ui/boton_comprar.png")
	buy.add_theme_font_size_override("font_size", 23)
	btn_row.add_child(cancel)
	btn_row.add_child(buy)
	vb.add_child(btn_row)

	var refresh := func() -> void:
		var qty: int = state["qty"]
		var total := cost * qty
		qty_l.text = "%d" % qty
		# Junto al total interesa saber CUÁNTO DE ESE INGREDIENTE tienes ya,
		# no el dinero (que sale arriba en el monedero).
		total_l.text = "Total: %d doblones   (tienes %d usos)" % [total, GameState.get_ingredient_uses(ing)]
		minus.modulate = Color(1, 1, 1, 0.4) if qty <= 1 else Color.WHITE
		buy.disabled = total > GameState.money
		# SIN el "✔" delante: el visto es parte del gráfico del botón, y aquí
		# además el botón lleva su moneda. Esto era un resto de cuando
		# `skin_action_button` prefijaba el texto.
		buy.text = "Comprar" if total <= GameState.money else "Sin dinero"
	minus.pressed.connect(func() -> void:
		state["qty"] = maxi(int(state["qty"]) - 1, 1)
		refresh.call())
	plus.pressed.connect(func() -> void:
		state["qty"] = mini(int(state["qty"]) + 1, 99)
		refresh.call())
	buy.pressed.connect(func() -> void:
		var qty: int = state["qty"]
		var total := cost * qty
		if total > GameState.money:
			return
		GameState.money -= total
		GameState.bump_stat("money_spent", total)
		GameState.bump_stat("shop_spent", total)
		GameState.add_ingredient_uses(ing, qty)
		GameState.save_game()
		overlay.queue_free()
		_refresh())
	refresh.call()

	box.scale = Vector2(0.7, 0.7)
	var tw := box.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "scale", Vector2.ONE, 0.22)


## Botón de flecha con imagen propia (madera + marco de oro), sin texto.
func _make_arrow(dir: String) -> TextureButton:
	var b := TextureButton.new()
	var path := "res://assets/ui/boton_flecha_der.png" if dir == ">" \
			else "res://assets/ui/boton_flecha_izq.png"
	b.texture_normal = load(path)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(76, 76)
	PrepBoard.add_press_feedback(b)
	return b


## Disco de madera del botón redondo: se dibuja una vez y se reutiliza.
static var _disc: Texture2D = null


func _disc_texture() -> Texture2D:
	if _disc != null:
		return _disc
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length() / c
			if d > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d > 0.88:
				img.set_pixel(x, y, Color(0.78, 0.61, 0.24))
			else:
				var t: float = 0.55 + 0.45 * (1.0 - d)
				img.set_pixel(x, y, Color(0.42 * t, 0.28 * t, 0.15 * t, 1.0))
	_disc = ImageTexture.create_from_image(img)
	return _disc
