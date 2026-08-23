extends Node3D
## Aventura: MAPA MARÍTIMO en 3D low poly (port de level_select.gd con la
## misma lógica). El barco del jugador navega por un mar animado por shader
## entre los nodos de la campaña (modelos 3D: isla / puerto / barco enemigo).
##
## COORDENADAS: el mapa vive en el plano X/Z y se sigue trabajando en los
## "píxeles de mapa" 2D de CampaignData.MAP_POS (lienzo 720 x MAP_HEIGHT):
## _world() los convierte a mundo con la misma cámara isométrica del nivel
## (yaw 45: pantalla-derecha = (1,0,-1)/√2, pantalla-abajo = (1,0,1)/√2).
## Así los carriles, anclas del barco y el scroll del 2D valen tal cual.
##
## La UI (barra superior, panel de información, estrellas, carteles con el
## número y el botón táctil de cada nodo) sigue siendo 2D: los overlays de los
## nodos se reproyectan cada fotograma con la cámara.

const PrepBoard := preload("res://scripts/prep_board.gd")
## El scroll de la ficha se arrastra con el DEDO: en el móvil un
## ScrollContainer a pelo no se mueve (ver `touch_scroll.gd`).
const TouchScroll := preload("res://scripts/touch_scroll.gd")
const DARK := Color(0.26, 0.16, 0.08)
const FADED := Color(0.42, 0.3, 0.18)

## El mapa YA NO LLEVA RÓTULO (se quitó el lazo de "Aventura": ocupaba la
## franja en la que hoy va la barra de nivel del cocinero y no decía nada que
## el propio mapa no dijera). Las medidas se quedan por si vuelve un rótulo.
const TITLE_W := 322.0
const TITLE_H := 88.0

## Píxeles por unidad de mundo con la cámara orto (size 15, viewport 1280 alto)
## en horizontal de pantalla, y su proyección sobre el suelo en vertical.
const PPU_X := 1280.0 / 15.0
const PPU_Y := PPU_X * 0.57735            ## * sin(35.264°)
const R_HAT := Vector3(0.70710678, 0.0, -0.70710678)
const D_HAT := Vector3(0.70710678, 0.0, 0.70710678)

const CAM_PITCH := -35.264
const CAM_YAW := 45.0
const CAM_SIZE := 15.0
## La franja visible del mapa queda entre la barra superior (76 px) y el panel
## de información (1280-356 = 924 px): su centro está en y=500, es decir 140 px
## por encima del centro de la pantalla (640).
const BAND_CENTER_OFF := 140.0
## Límites del scroll (centro de la franja, en px de mapa).
## LA CUEVA VIVE POR ENCIMA DEL LIENZO DEL MAPA (y negativa), a un tramo de
## mar vacío del resto: por eso el tope de scroll no es el borde del mapa sino
## su posición menos un margen. Con esto, al llegar arriba del todo en pantalla
## NO se ve ningún escenario anterior — que es de lo que va la cueva.
## LA FICHA, EN VENTANA. Ancho casi de pantalla y ALTO A MEDIDA: se estira con
## lo que lleve dentro (una isla cuenta menos que la cueva del jefe) entre un
## suelo y un techo. Con alto fijo, la mitad de las fichas salían con media
## hoja en blanco.
const FICHA_W := 660.0
const FICHA_H := 900.0
const FICHA_MIN := 560.0
const FICHA_MAX := 980.0
## Lo que ocupa TODO lo que no es el cuerpo: nombre, tipo, estrellas, los dos
## botones del pie y los márgenes del pergamino.
const FICHA_EXTRA := 350.0
## Y BAJA un poco del centro: arriba están los contadores y la barra de nivel,
## y centrada del todo la ventana les caía encima.
const FICHA_BAJADA := 40.0

const SCROLL_MIN := -560.0
const SCROLL_MAX := CampaignData.MAP_HEIGHT - 300.0

## EL PLANO DEL MAR TIENE QUE CUBRIR TAMBIÉN EL FONDEADERO DEL MENÚ, que está
## muy por debajo del mapa (`main_menu.MENU_ANCHOR`), y el puerto de la portada,
## que además se corre 1500 px a la izquierda. Estuvo dimensionado solo contra
## el mapa y en la portada se veía el borde del agua abajo a la izquierda.
## Van en píxeles de mapa y en unidades de mundo respectivamente.
const SEA_BOTTOM_PX := 5200.0
const SEA_SIZE := 190.0

## Modelo 3D de cada tipo de nodo y huella horizontal objetivo (u).
const KIND_MODELS := {
	"isla": "res://assets/models/map_isla.glb",
	"puerto": "res://assets/models/map_puerto.glb",
	"abordaje": "res://assets/models/map_enemigo.glb",
	"cueva": "res://assets/models/map_cueva.glb",
}
## --- EL NUMERO DEL ESCENARIO, DENTRO DEL DECORADO (ver `_numero_del_nodo`) ---
## Escala de la fuente a mundo: tamano en unidades = font_size * NUM_PIXEL.
const NUM_PIXEL := 0.0042
## ISLA: tumbado en la arena, hacia la mitad delantera de la playa.
const ISLA_NUM_CUERPO := 280
const ISLA_NUM_COLOR := Color(0.52, 0.36, 0.18)
const ISLA_NUM_Y := 0.52
const ISLA_NUM_W := 0.30
## ABORDAJE: pintado en la vela, a media altura del palo.
const VELA_NUM_CUERPO := 210
## CREMA, no tinta oscura: las velas de este barco son OSCURAS y furladas,
## asi que un numero marron se perdia en ellas. Pintado en claro se lee.
const VELA_NUM_COLOR := Color(0.95, 0.91, 0.80)
const VELA_NUM_Y := 0.72
const VELA_NUM_Z := 0.14
## CUEVA: esculpido en la cara de la roca.
const CUEVA_NUM_CUERPO := 185
const CUEVA_NUM_COLOR := Color(0.20, 0.19, 0.18)
const CUEVA_NUM_Y := 0.62
const CUEVA_NUM_Z := 0.36
## PUERTO: el cartel de madera clavado en el muelle.
const CARTEL_Z := 0.34
const CARTEL_X := 0.02
const CARTEL_ALTO := 0.95
const CARTEL_ANCHO := 0.78
const CARTEL_TABLA := 0.50
const CARTEL_POSTE := 0.09
const CARTEL_CUERPO := 190

## Huella de cada modelo en el mapa. La ISLA es la mas grande porque su numero
## va ESCRITO EN LA ARENA: a 2.6 la playa no daba para una cifra legible.
const KIND_FOOT := { "isla": 3.5, "puerto": 3.0, "abordaje": 2.6, "cueva": 2.8 }
## Sitio y tamaño de la sombra de la boca de la cueva, en fracciones de su
## huella (medido sobre captura, ver `_base_cueva`).
const BOCA_U := -0.274
const BOCA_W := 0.111
const BOCA_Y := 0.132
## LA MAREA. El mar entero sube y baja muy despacio, y lo que la hace creíble
## no es el agua moviéndose: es que las ISLAS NO se muevan con ella (se mojan
## más o menos, y la línea de flotación les recorre la roca) mientras que lo
## que FLOTA —el barco del jugador y los barcos enemigos de los abordajes— sube
## y baja con el agua. Sin esto, un nodo del mapa parece una pegatina puesta
## encima del mar.
## OJO: la marea solo SUBE (0..MAREA_AMP), nunca baja del nivel de siempre. Si
## bajara, los modelos —que tienen su base a -0.10— se quedarían flotando por
## encima del agua con un palmo de aire debajo, que es justo lo contrario de lo
## que se busca.
const MAREA_AMP := 0.10
const MAREA_PERIODO := 24.0
const BOCA_ANCHO := 0.60
const BOCA_ALTO := 0.44
const SHIP_FOOT := 2.3
## Orientación base del barco (navega hacia la parte alta del mapa).
const SHIP_YAW := 205.0

var cam: Camera3D
var ui: CanvasLayer
## Piezas de la interfaz del mapa, para poder apagarlas cuando la escena hace
## de menú principal (main_menu.gd hereda de este script).
var map_ui_root: Control = null
var map_top_bar: Control = null
var map_info_panel: Control = null
var selected_id: String = ""
## Centro de la franja visible, en px de mapa (el equivalente del scroll 2D).
var cam_center := SCROLL_MAX
var scroll_tween: Tween = null
## Inercia del arrastre del mapa (px de mapa por segundo) y cómo se apaga.
var scroll_speed := 0.0
var scroll_dragging := false
const SCROLL_FRICTION := 0.05
const SCROLL_STOP := 14.0
const DRAG_SMOOTH := 0.7
## Posición del barco en px de mapa; un tween la anima al viajar.
var ship_px := Vector2(360, 1560)
var ship_pivot: Node3D
var ship_blob: MeshInstance3D = null
var ship_tween: Tween = null
var ship_roll := 0.0
var _t := 0.0
## Material del mar (para pasarle la marea) y lo que flota con ella.
var sea_mat: ShaderMaterial = null
var flotantes: Array[Node3D] = []
## Jirones de niebla de la cueva. Cada uno guarda en sus metadatos su órbita
## (centro, radio, velocidad, fase, altura y balanceo); los mueve `_process`.
var nieblas: Array[Node3D] = []

## Overlays 2D por nodo: { id: {root, unlocked} } reposicionados por frame.
var node_overlays: Dictionary = {}
var node_world: Dictionary = {}
## Con la escena en modo menú, los carteles de nivel no se dibujan.
var map_visible := true

# --- Widgets del panel de información (idénticos al 2D) ---
var info_title: Label
var info_kind: Label
var info_desc: Label
var info_time: Label
var info_goal: Label
var info_record: Label
## Filas de iconos: clientes (cabeza + xN), recetas utilizables y recompensas.
## Van en HFlowContainer y no en HBox: en una columna estrecha, una fila de
## iconos que no cabe tiene que SALTAR de línea en vez de desbordarse.
var info_clients_row: Container
var info_recipes_row: Container
var info_stars_box: Control
## Cómo se cierra la jornada y qué castiga el TIPO de escenario.
var info_cierre: Label
## Bloque del coleccionable que se puede conseguir aquí (si lo hay).
var info_tesoro: VBoxContainer = null
var info_tesoro_row: Container = null
## La franja de abajo del mapa: mapas del tesoro, tienda y opciones.
var map_submenu: Control = null
## Piezas de la ficha que hay que remedir cuando cambia su contenido.
var ficha_panel: PanelContainer = null
var ficha_cuerpo: VBoxContainer = null
## Atado al primer puerto: en la primera visita al mapa el "Atrás" no vale
## hasta que se zarpa (ver `_guiar_primer_nivel` y `_on_map_back`).
var _atado_al_puerto := false
var _regana_atras := false
## Filas gráficas del objetivo (estrellas + moneda + cifra).
var goal_box: VBoxContainer = null
## Fila del récord (moneda + cifra).
var record_box: HBoxContainer = null
var sail_button: Button


## Px de mapa (lienzo 2D de CampaignData) -> punto del mundo en el plano del mar.
func _world(p: Vector2) -> Vector3:
	return R_HAT * ((p.x - 360.0) / PPU_X) + D_HAT * (p.y / PPU_Y)


func _ready() -> void:
	# Las pantallas de menu van a la mitad de fotogramas que el juego
	# (GameState.fps_for): aqui no se juega y renderizar mas gasta bateria.
	Engine.max_fps = GameState.fps_for(false)
	_setup_environment()
	_setup_sea()
	_setup_route()
	_setup_nodes()
	_setup_ship()
	_setup_camera()
	# Los ~100 guiones de la ruta son geometría fija: se funden en una malla.
	GeometryBatch.bake(self, "RouteBatch")
	# LA RUTA VA PINTADA SOBRE EL AGUA, así que SUBE CON LA MAREA. Los guiones
	# están a 0.025 de altura y la marea llega a 0.10: sin esto, la línea de
	# puntos entre escenarios desaparecía bajo el agua en cada pleamar.
	for hijo in get_children():
		if hijo is MeshInstance3D and String(hijo.name).begins_with("RouteBatch"):
			var mi: MeshInstance3D = hijo
			mi.set_meta("y0", mi.position.y)
			flotantes.append(mi)
	_setup_ui()

	_focus_last_port(false)


## Coloca la vista y el barco donde estaba el jugador: en el escenario que
## dejo elegido (`GameState.map_port`) y, si no hay ninguno o ya no vale, en el
## mas avanzado disponible. Volver de Maestrias o de la tienda y encontrarse el
## barco en otro sitio es perder el hilo de lo que se estaba mirando.
func _focus_last_port(animate: bool) -> void:
	var start_id := _puerto_de_partida()
	if not animate:
		ship_px = _ship_anchor(start_id)
		cam_center = clampf(CampaignData.map_pos(start_id).y, SCROLL_MIN, SCROLL_MAX)
		_update_camera()
	_select(start_id, animate)


## El que hay que enfocar al entrar: el recordado si sigue siendo jugable, y
## si no el ultimo abierto.
func _puerto_de_partida() -> String:
	var guardado := GameState.map_port
	if guardado != "" and not CampaignData.get_port(guardado).is_empty() \
			and GameState.is_port_unlocked(guardado):
		return guardado
	return last_open_port()


## Último nivel de la campaña que el jugador tiene abierto.
func last_open_port() -> String:
	var start_id := CampaignData.first_port_id()
	for p in CampaignData.PORTS:
		if GameState.is_port_unlocked(p.id):
			start_id = p.id
	return start_id


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.12, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.80, 0.92)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -125.0, 0.0)
	sun.light_energy = 1.1
	sun.light_color = Color(1.0, 0.96, 0.9)
	# Sin sombras proyectadas en todo el juego: cada cosa lleva su mancha
	# fija (SceneBackdrop.blob_shadow).
	sun.shadow_enabled = false
	add_child(sun)


## Mar: plano enorme con el shader de agua (deriva + senos cruzados), tileado
## a la misma escala 1:1 que en el 2D (el tamaño del tile sale de la textura).
func _setup_sea() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(SEA_SIZE, SEA_SIZE)
	# El oleaje del agua es un desplazamiento de VÉRTICE: sin subdividir, el
	# plano son dos triángulos y no se mueve nada.
	mesh.subdivide_width = 48
	mesh.subdivide_depth = 48
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	# El plano se centra entre el TOPE DEL MAPA y el fondeadero del menú, que
	# es el punto más bajo al que llega la cámara (y desde la PORTADA se corre
	# además PORT_OFF hacia la izquierda). Centrado solo en el mapa, la esquina
	# inferior izquierda de la portada se salía del agua y se veía el vacío.
	var hasta := maxf(CampaignData.MAP_HEIGHT, SEA_BOTTOM_PX)
	mi.position = D_HAT * ((hasta * 0.5 + 640.0) / PPU_Y)
	var mat := ShaderMaterial.new()
	# EL MAR VA CON `water_ww.gdshader`. Se probó también el "Toon Water Shader"
	# (`shaders/water_toon.gdshader`, aquí es cambiar estas dos líneas) y se
	# MIDIÓ: cuesta el doble o el triple —lee la profundidad de pantalla— y
	# encima aquí su gracia principal no se ve, porque este mar NO TIENE FONDO:
	# sin nada debajo, el degradado por profundidad sale plano y la orla de
	# espuma pinta de blanco toda la roca sumergida de cada isla.
	mat.shader = load("res://shaders/water_ww.gdshader")
	mat.set_shader_parameter("espuma", load("res://assets/map/espuma_ww.webp"))
	sea_mat = mat
	# Una baldosa de espuma cada ~2.5 u de mundo, aquí y en las otras dos
	# pantallas con mar, para que el dibujo tenga el mismo tamaño se vea donde
	# se vea. OJO con la escala: la cámara del juego enseña solo 9.5 u de ancho,
	# así que la espuma a tamaño "de verdad" salía en manchas de medio palmo y
	# el mar parecía una vaca.
	mat.set_shader_parameter("tile", Vector2(SEA_SIZE * 1.0, SEA_SIZE * 1.0))
	# El plano del mar no proyecta sombra sobre nada: fuera del pase de sombras.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = mat
	add_child(mi)


## Ruta discontinua entre niveles consecutivos: guiones planos sobre el agua.
func _setup_route() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.32)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(CampaignData.PORTS.size() - 1):
		var a := _world(CampaignData.map_pos(CampaignData.PORTS[i].id))
		var b := _world(CampaignData.map_pos(CampaignData.PORTS[i + 1].id))
		var seg := b - a
		var total := seg.length()
		var dir := seg / total
		var t := 0.35
		while t < total - 0.3:
			var e := minf(t + 0.24, total)
			var dash := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3((e - t), 0.02, 0.07)
			dash.mesh = box
			dash.material_override = mat
			dash.position = a + dir * ((t + e) * 0.5) + Vector3(0.0, 0.025, 0.0)
			dash.rotation_degrees.y = rad_to_deg(atan2(dir.x, dir.z)) - 90.0
			add_child(dash)
			t = e + 0.2


func _setup_nodes() -> void:
	for p in CampaignData.PORTS:
		var id: String = p.id
		var kind := CampaignData.get_kind(id)
		var pos := _world(CampaignData.map_pos(id))
		node_world[id] = pos
		var pivot := _spawn_model(load(KIND_MODELS[kind]), pos,
			float(KIND_FOOT.get(kind, 2.5)))
		# Los barcos se hunden un poco en el agua; las islas asientan su base.
		pivot.position.y = -0.10 if kind != "abordaje" else -0.06
		# Y LO QUE FLOTA, FLOTA: un barco enemigo sube y baja con la marea; una
		# isla se queda donde está y deja que el agua le trepe por la roca.
		if kind == "abordaje":
			pivot.set_meta("y0", pivot.position.y)
			flotantes.append(pivot)
		# LA CUEVA lleva su propia BASE de piedra (el modelo es un peñasco sin
		# suelo y flotaba sobre el agua a corte vivo).
		var base_cueva: Node3D = null
		if kind == "cueva":
			base_cueva = _base_cueva(pos, float(KIND_FOOT.get(kind, 2.5)),
				_textura_de(pivot))
			_niebla_cueva(pos, float(KIND_FOOT.get(kind, 2.5)))
		# Los nodos NO proyectan sombra: son 9 modelos de ~40k triangulos y el
		# pase de sombras los dibujaba otra vez enteros, para una mancha que
		# desde esta camara casi no se ve.
		for m in pivot.find_children("*", "MeshInstance3D", true, false):
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var foot: float = float(KIND_FOOT.get(kind, 2.5))
		var blob := SceneBackdrop.blob_shadow(foot * 0.95, foot * 0.62)
		blob.position = pos + Vector3(0.15, 0.03, 0.1)
		add_child(blob)
		# La mancha es una sombra EN EL AGUA: sube con ella o se hunde.
		blob.set_meta("y0", blob.position.y)
		flotantes.append(blob)
		_numero_del_nodo(kind, pivot, foot, CampaignData.port_index(id) + 1,
			GameState.is_port_unlocked(id))
		if not GameState.is_port_unlocked(id):
			_dim_model(pivot)
			if base_cueva != null:
				_dim_model(base_cueva)


## EL NUMERO DEL ESCENARIO VA DENTRO DEL DECORADO, no en una chapa delante.
## Cada tipo lo lleva donde lo llevaria de verdad: la ISLA lo tiene escrito en
## la arena, el PUERTO en un cartel clavado en el muelle, el ABORDAJE pintado
## en la vela y la CUEVA esculpido en la roca. Un disco con el numero flotando
## sobre el nodo se leia como un boton mas de la interfaz; asi el mapa se lee
## como un sitio.
##
## Los cuatro son `Label3D`, no texturas horneadas: el texto sale con la fuente
## del juego, se puede cambiar el numero sin regenerar nada y no cuesta un
## `.png` por escenario.
## OJO CON LA ORIENTACION. La camara mira con yaw 45, asi que:
##  · un rotulo DE PIE mirando a la camara va a `rotation.y = 45`;
##  · uno TUMBADO en el suelo va a (-90, 45, 0) — con el -90 su cara apunta
##    arriba y con el 45 su eje X cae sobre el "derecha" de la pantalla
##    (`R_HAT`), que es lo que lo hace legible en vez de salir torcido.
func _numero_del_nodo(kind: String, pivot: Node3D, foot: float, n: int,
		unlocked: bool) -> void:
	var alto := float(pivot.get_meta("alto", 1.0))
	match kind:
		"isla":
			# ESCRITO EN LA ARENA: tumbado sobre la playa y en el tono de la
			# propia arena mojada, sin contorno claro — una cifra con marco
			# volveria a parecer una chapa.
			var l := _label3d(n, ISLA_NUM_CUERPO, ISLA_NUM_COLOR,
				Color(0.30, 0.22, 0.12, 0.55), 22, unlocked)
			l.rotation_degrees = Vector3(-90.0, 45.0, 0.0)
			l.position = Vector3(0.0, ISLA_NUM_Y, 0.0) + D_HAT * (foot * ISLA_NUM_W)
			pivot.add_child(l)
		"puerto":
			_cartel_puerto(pivot, foot, alto, n, unlocked)
		"abordaje":
			# EN LA VELA: de pie, mirando a la camara, con la tinta oscura de
			# un numero pintado sobre lona.
			var lv := _label3d(n, VELA_NUM_CUERPO, VELA_NUM_COLOR,
				Color(0.22, 0.13, 0.06, 0.9), 18, unlocked)
			lv.rotation_degrees = Vector3(0.0, 45.0, 0.0)
			lv.position = Vector3(0.0, alto * VELA_NUM_Y, 0.0) \
				+ D_HAT * (foot * VELA_NUM_Z)
			pivot.add_child(lv)
		"cueva":
			# ESCULPIDO: letra oscura con un reborde CLARO por debajo, que es
			# como se lee un bajorrelieve — la luz le entra por el canto de
			# arriba y la talla queda en sombra.
			var lc := _label3d(n, CUEVA_NUM_CUERPO, CUEVA_NUM_COLOR,
				Color(0.62, 0.60, 0.56, 0.85), 20, unlocked)
			lc.rotation_degrees = Vector3(0.0, 45.0, 0.0)
			lc.position = Vector3(0.0, alto * CUEVA_NUM_Y, 0.0) \
				+ D_HAT * (foot * CUEVA_NUM_Z)
			pivot.add_child(lc)


## Un rotulo 3D con la fuente del juego. `alpha_cut` en DISCARD a proposito: el
## texto no tiene que ordenarse contra el mar ni contra la niebla, y asi no
## parpadea al pasar un jiron por delante.
func _label3d(n: int, cuerpo: int, color: Color, borde: Color, ancho: int,
		unlocked: bool) -> Label3D:
	var l := Label3D.new()
	l.text = "%d" % n
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		l.font = negrita
	l.font_size = cuerpo
	l.pixel_size = NUM_PIXEL
	l.modulate = color if unlocked else color.lerp(Color(0.42, 0.44, 0.5), 0.75)
	l.outline_modulate = borde
	l.outline_size = ancho
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.shaded = false
	l.double_sided = true
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# `GeometryBatch.bake` funde la geometria estatica del mapa y LIBERA los
	# originales: sin esto el numero se iria con ellos.
	l.add_to_group("no_batch")
	return l


## EL CARTEL DEL PUERTO: dos postes y una tabla, construidos aqui y no en el
## modelo, porque el `.glb` del puerto es el mismo para los seis y el cartel
## tiene que poder cambiar de numero. Va en la punta del muelle y de cara a la
## camara, que es donde se pondria uno de verdad para que lo lea quien llega
## navegando.
func _cartel_puerto(pivot: Node3D, foot: float, alto: float, n: int,
		unlocked: bool) -> void:
	var cartel := Node3D.new()
	cartel.rotation_degrees.y = 45.0
	# HACIA LA CAMARA (+D_HAT): puesto por detras, la roca del faro se lo
	# comia entero.
	cartel.position = D_HAT * (foot * CARTEL_Z) \
		+ R_HAT * (foot * CARTEL_X)
	pivot.add_child(cartel)
	var madera := StandardMaterial3D.new()
	madera.albedo_color = Color(0.44, 0.28, 0.14) if unlocked \
			else Color(0.24, 0.25, 0.30)
	madera.roughness = 0.95
	for dx in [-CARTEL_ANCHO * 0.34, CARTEL_ANCHO * 0.34]:
		var poste := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(CARTEL_POSTE, CARTEL_ALTO, CARTEL_POSTE)
		poste.mesh = pm
		poste.material_override = madera
		poste.position = Vector3(dx, CARTEL_ALTO * 0.5, 0.0)
		poste.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cartel.add_child(poste)
	var tabla := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(CARTEL_ANCHO, CARTEL_TABLA, CARTEL_POSTE * 0.7)
	tabla.mesh = tm
	var tinta := StandardMaterial3D.new()
	tinta.albedo_color = Color(0.62, 0.42, 0.20) if unlocked \
			else Color(0.30, 0.31, 0.36)
	tinta.roughness = 0.95
	tabla.material_override = tinta
	tabla.position = Vector3(0.0, CARTEL_ALTO - CARTEL_TABLA * 0.6, 0.0)
	tabla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cartel.add_child(tabla)
	var l := _label3d(n, CARTEL_CUERPO, Color(1.0, 0.90, 0.55),
		Color(0.16, 0.09, 0.03, 0.9), 18, unlocked)
	l.position = tabla.position + Vector3(0.0, 0.0, CARTEL_POSTE * 0.5)
	cartel.add_child(l)


## EL ISLOTE DE LA CUEVA. Estuvo resuelto con dos discos lisos de color plano y
## se leía como un plato: un peñasco no se apoya en una tarta. Van TRES
## plataformas FACETADAS (pocos lados y giradas entre sí, para que la silueta
## sea irregular desde cualquier ángulo), con la MISMA piedra que se ve dentro
## de la cueva, unos pedruscos rompiendo el canto y un anillo de rompiente a
## ras de agua para que la roca no salga recortada sobre el mar.
## NIEBLA ALREDEDOR DE LA CUEVA (pedido por el usuario): la guarida del jefe
## tiene que dar respeto desde el mapa, y el peñasco solo no lo daba.
##
## Va en DOS PIEZAS, y hacen falta las dos:
##  · El MANTO: dos planos TUMBADOS sobre el agua, centrados en el peñasco y
##    girando muy despacio en sentidos contrarios. Es lo que se lee como bruma
##    de verdad: una sábana que abraza la roca. Con solo carteles sueltos, la
##    niebla parecían manchas de suciedad flotando en el mar (probado).
##  · Los JIRONES: carteles (billboard) que orbitan bajos y ALGUNOS por delante
##    de la roca (`NIEBLA_DENTRO`, hacia la cámara), que es lo que de verdad la
##    difumina. La niebla que solo pasa por detrás no tapa nada.
##
## Detalles pagados:
##  · Los nodos van en el grupo `no_batch`: `GeometryBatch.bake` funde la
##    geometría estática del mapa y LIBERA los originales — los diez jirones
##    salían como "previously freed" y no se movían nunca.
##  · Sin escritura de profundidad, o dos jirones que se cruzan se recortan
##    entre ellos con un canto duro.
##  · Suben con la MAREA, como todo lo que se pinta a ras de agua.
##
## EL DIBUJO LO PONE UN SHADER DE PERLIN (`shaders/niebla_perlin.gdshader`,
## portado del "Customizable Perlin Fog" de cookiemonster_nz), no una textura:
## cada plano es una VENTANA a un campo de niebla 3D que existe en el mundo, así
## que la bruma se desliza POR DENTRO del cartel mientras este orbita, en vez de
## viajar pegada a él como haría un sprite. Eso es lo que la hace parecer niebla
## de verdad y no una calcomanía dando vueltas.
const NIEBLA_SHADER := "res://shaders/niebla_perlin.gdshader"

## --- El manto tumbado sobre el agua ---
## Planos del manto (giran en sentidos contrarios) y su lado, en fracciones de
## la huella del nodo.
## OJO CON EL TAMAÑO DEL MANTO: la huella de la cueva son 2.7 u, así que un
## lado de 3.6 daba planos de 9.7 u — 830 px, la pantalla entera — y la niebla
## salía como una sábana blanca que se tragaba el mar y la isla.
const MANTO_LADO := [2.4, 1.8]
## El manto es el VELO DE BASE: tiene que aguantar solo. Los jirones que
## orbitan van y vienen, así que si el manto es flojo hay instantes en los que
## la cueva se queda a la vista y limpia (medido comparando dos capturas con
## 7 s de diferencia: de niebla espesa a casi nada).
## El manto sale MÁS DENSO que los jirones: es una loncha horizontal del campo
## de ruido vista casi de canto (la cámara pica 35°), así que aporta mucho menos
## de lo que su número sugiere.
const MANTO_ALFA := [0.7, 0.55]
const MANTO_Y := [0.05, 0.12]
## Segundos que tarda cada plano en dar una vuelta sobre sí mismo.
const MANTO_VUELTA := 90.0

## --- Los jirones que orbitan ---
const NIEBLA_N := 6
## Segundos de una vuelta completa a la roca.
const NIEBLA_VUELTA := 52.0
## Radio de la órbita y lado del cartel, en fracciones de la huella.
const NIEBLA_R := 0.72
const NIEBLA_LADO := 1.9
const NIEBLA_ALFA := 0.45
## Proporción alto/ancho del jirón. BAJO a propósito: son cartas de pie, y a
## 0.58 medían 2.4-3.6 u de alto — con su centro casi en la línea de flotación,
## eso dejaba su mitad inferior DEBAJO DEL MAR, y el plano opaco del agua las
## cortaba en una raya horizontal perfecta que cruzaba la pantalla. Aplanados
## y subidos (ver `y0`), la niebla se apoya en el agua en vez de hundirse.
const NIEBLA_APLANE := 0.36
## Fracción de su propio alto a la que flota el centro del jirón: con 0.42 su
## canto de abajo queda justo bajo el agua, así que el corte cae donde la
## densidad ya se está muriendo y no se ve.
const NIEBLA_Y := 0.42
const NIEBLA_DENTRO := 0.45
## Tinte de toda la niebla: blanco FRÍO, que es lo que la separa del blanco
## cálido de la espuma del mar.
const NIEBLA_TINTE := Color(0.84, 0.89, 0.98)


func _niebla_cueva(pos: Vector3, foot: float) -> void:
	var sh := load(NIEBLA_SHADER)
	if sh == null:
		return
	var quad := QuadMesh.new()

	# --- EL MANTO: planos tumbados, girando sobre sí mismos ---
	for i in MANTO_LADO.size():
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = _mat_niebla(sh, float(MANTO_ALFA[i]))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_to_group("no_batch")
		var lado: float = foot * float(MANTO_LADO[i])
		mi.scale = Vector3(lado, lado, 1.0)
		# Tumbado: el quad nace de pie, mirando a +Z.
		mi.rotation_degrees.x = -90.0
		add_child(mi)
		mi.position = pos + Vector3(0.0, float(MANTO_Y[i]) * foot, 0.0)
		mi.set_meta("manto", true)
		mi.set_meta("centro", mi.position)
		mi.set_meta("giro", (1.0 if i == 0 else -1.0) * TAU / MANTO_VUELTA)
		mi.set_meta("y0", float(MANTO_Y[i]) * foot)
		nieblas.append(mi)

	# --- LOS JIRONES: carteles en órbita ---
	for i in NIEBLA_N:
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = _mat_niebla(sh, NIEBLA_ALFA, true)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_to_group("no_batch")
		# Cada jirón, de su tamaño: todos iguales se leen como una rueda.
		var escala: float = foot * NIEBLA_LADO * (0.8 + 0.2 * float(i % 3))
		var alto: float = escala * NIEBLA_APLANE
		mi.scale = Vector3(escala, alto, 1.0)
		add_child(mi)
		mi.set_meta("centro", pos)
		mi.set_meta("radio", foot * NIEBLA_R)
		mi.set_meta("fase", TAU * float(i) / float(NIEBLA_N))
		mi.set_meta("giro", TAU / NIEBLA_VUELTA)
		mi.set_meta("y0", alto * NIEBLA_Y)
		# Los pares pasan POR DELANTE de la roca; los impares, por detrás.
		mi.set_meta("dentro", (NIEBLA_DENTRO * foot) if i % 2 == 0 else 0.0)
		# Balanceo vertical propio, para que no suban y bajen a la vez.
		mi.set_meta("bob", 0.9 + 0.35 * float(i % 3))
		nieblas.append(mi)
	# Colocados YA, sin esperar al primer `_process`: con "menos animaciones"
	# ese bucle no corre y se quedarían amontonados en el origen del mundo.
	_mover_niebla()


## LA ESCALA DEL RUIDO VA EN VUELTAS POR UNIDAD DE MUNDO, así que la manda el
## tamaño de lo que se quiere ver: la cueva mide 2.7 u de huella, y con la
## escala a 1 (la del original, pensada para volúmenes grandes) toda la niebla
## de aquí cabría dentro de una sola celda de ruido y saldría de un gris plano.
const NIEBLA_ESCALA := 0.55
## Deriva del campo de niebla, en unidades por segundo. Muy lenta: es bruma,
## no humo de una chimenea.
const NIEBLA_DERIVA := Vector3(0.035, 0.012, 0.028)


func _mat_niebla(sh: Shader, alfa: float, cartel := false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("noise_scale", NIEBLA_ESCALA)
	mat.set_shader_parameter("movement_dir", NIEBLA_DERIVA)
	mat.set_shader_parameter("density_mult", alfa)
	mat.set_shader_parameter("albedo_color", NIEBLA_TINTE)
	mat.set_shader_parameter("cartel", cartel)
	# Los jirones de pie se deshilachan por arriba; los planos tumbados no
	# (todos sus píxeles están a la misma altura y la caída no haría nada).
	# Umbrales de densidad: solo los GRUMOS del ruido pintan. Con el umbral
	# bajo en 0.30 (el del original) pintaba más de media pasada de ruido y
	# la niebla salía de un blanco plano en vez de en jirones.
	mat.set_shader_parameter("umbral_bajo", 0.45)
	mat.set_shader_parameter("umbral_alto", 0.95)
	# La muerte hacia el canto empieza pronto: el plano es grande y si el
	# núcleo a plena densidad ocupa medio cartel, se ve el rectángulo.
	mat.set_shader_parameter("borde", 0.22)
	mat.set_shader_parameter("fade_alto", foot_fade(cartel))
	mat.set_shader_parameter("fade_dist", 1.2)
	return mat


## Altura a la que empieza a deshilacharse un jirón de pie (0 = sin caída).
func foot_fade(cartel: bool) -> float:
	return 0.35 if cartel else 0.0



## Coloca la niebla para el instante `_t`: el manto gira sobre sí mismo y los
## jirones recorren su órbita alrededor del peñasco.
func _mover_niebla() -> void:
	var m := marea()
	for n in nieblas:
		if not is_instance_valid(n):
			continue
		var giro: float = float(n.get_meta("giro", 0.0))
		if bool(n.get_meta("manto", false)):
			var c0: Vector3 = n.get_meta("centro", Vector3.ZERO)
			n.position.y = c0.y + m
			# Tumbado: su giro propio es el eje Z del quad (ya rotado -90 en X).
			n.rotation_degrees.z = rad_to_deg(_t * giro)
			continue
		var a: float = float(n.get_meta("fase", 0.0)) + _t * giro
		var r: float = float(n.get_meta("radio", 1.0))
		var c: Vector3 = n.get_meta("centro", Vector3.ZERO)
		# El adelanto hacia la CÁMARA es +D_HAT (lo que baja en pantalla).
		n.position = c + R_HAT * (cos(a) * r) + D_HAT * (sin(a) * r) 			+ D_HAT * float(n.get_meta("dentro", 0.0)) 			+ Vector3(0.0, float(n.get_meta("y0", 0.0)) + m
				+ sin(_t * float(n.get_meta("bob", 1.0))) * 0.05, 0.0)


## La primera textura de albedo que encuentre un modelo. Con ella, la roca que
## se construye por código sale de la MISMA piedra que el modelo, en vez de
## parecerle un pegote de otro juego.
func _textura_de(root: Node3D) -> Texture2D:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var mat: Material = mi.get_active_material(i)
			if mat is StandardMaterial3D:
				var sm: StandardMaterial3D = mat
				if sm.albedo_texture != null:
					return sm.albedo_texture
	return null


func _base_cueva(pos: Vector3, foot: float, tex_modelo: Texture2D) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	# LA PIEDRA DE LAS PLATAFORMAS ES LA DEL PEÑASCO, sacada de su propio
	# material: con la piedra gris azulada de la cueva del NIVEL, el islote y el
	# modelo parecían de dos juegos distintos.
	var tex: Texture2D = tex_modelo
	if tex == null:
		tex = load("res://assets/props/piedra_cueva.webp")
	# NADA DE ROMPIENTE NI DE BAJÍO: el plano del mar es opaco, así que lo que
	# quede por debajo de y=0 no se ve, y el aro claro que se probó a ras de
	# agua rodeaba la roca con una fuente blanca. La roca corta el agua a
	# cuchillo, igual que los modelos de las islas.
	# Las tres plataformas, de la más ancha (al agua) a la más alta. LAS DOS DE
	# ARRIBA VAN CORRIDAS HACIA EL FONDO (`ATRAS`, en la diagonal que se aleja
	# de la cámara) y algo más bajas: centradas y a su altura anterior le
	# tapaban al peñasco la BOCA DE LA CUEVA, que está en su cara delantera y
	# a ras de base. Así el islote sigue en terrazas por detrás y por los lados
	# y la entrada queda despejada.
	var atras := -Vector3(0.70710678, 0.0, 0.70710678)
	_roca_facetada(pivot, Vector3(0.0, -0.42, 0.0), foot * 0.90, 0.66, 7, 14.0,
		tex, Color(0.62, 0.64, 0.66))
	_roca_facetada(pivot, atras * 0.34 + Vector3(0.0, -0.22, 0.0), foot * 0.73,
		0.48, 6, -27.0, tex, Color(0.78, 0.80, 0.82))
	_roca_facetada(pivot, atras * 0.58 + Vector3(0.0, -0.08, 0.0), foot * 0.56,
		0.38, 9, 41.0, tex, Color(0.92, 0.94, 0.96))
	# LA BOCA DE LA CUEVA, ENSOMBRECIDA: el modelo trae su entrada tallada en la
	# cara delantera, pero a este tamaño se pierde entre la roca. Una tarjeta
	# oscura de canto fundido (el mismo shader que ilumina la boca DENTRO del
	# nivel, aquí en negro) la va oscureciendo hacia dentro y la hace leerse
	# como un agujero. Va mirando a la cámara, como todo en este mapa.
	var boca := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(foot * BOCA_ANCHO, foot * BOCA_ALTO)
	boca.mesh = quad
	boca.position = R_HAT * (BOCA_U * foot) + D_HAT * (BOCA_W * foot) \
		+ Vector3(0.0, BOCA_Y * foot, 0.0)
	boca.rotation_degrees = Vector3(0.0, 45.0, 0.0)
	var mat_b := ShaderMaterial.new()
	mat_b.shader = load("res://shaders/portal_cueva.gdshader")
	mat_b.set_shader_parameter("color", Color(0.01, 0.02, 0.03))
	mat_b.set_shader_parameter("fuerza", 0.95)
	mat_b.set_shader_parameter("borde", 0.85)
	mat_b.set_shader_parameter("latido", 0.0)
	boca.material_override = mat_b
	boca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(boca)
	# Pedruscos del canto: son los que quitan del todo la silueta de disco.
	# Sin pedruscos en la cara DELANTERA (la de la boca): hacían de tapón.
	var puntos := [2.35, 3.05, 3.60, 4.30, 4.95, 5.60]
	for i in puntos.size():
		var a: float = puntos[i]
		var r := foot * (0.62 + 0.08 * float(i % 3) * 0.5)
		_roca_facetada(pivot, Vector3(cos(a) * r, -0.10 + 0.06 * float(i % 2),
			sin(a) * r), foot * (0.15 + 0.05 * float(i % 3)),
			0.34 + 0.12 * float(i % 2), 5, a * 40.0, tex,
			Color(0.70, 0.72, 0.74))
	return pivot


## Un prisma de roca: cilindro de POCOS lados (facetado) y girado, con la
## piedra triplanar. Sin textura queda de color plano (la rompiente).
func _roca_facetada(padre: Node3D, off: Vector3, radio: float, alto: float,
		lados: int, giro: float, tex: Texture2D, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radio * 0.86
	mesh.bottom_radius = radio
	mesh.height = alto
	mesh.radial_segments = lados
	mi.mesh = mesh
	mi.position = off
	mi.rotation_degrees.y = giro
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	if tex != null:
		mat.albedo_texture = tex
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.95, 0.95, 0.95)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
	return mi


## Oscurece un modelo bloqueado con una pasada extra translúcida (el modulate
## de los sprites 2D no existe en 3D).
func _dim_model(root: Node3D) -> void:
	var shade := StandardMaterial3D.new()
	shade.albedo_color = Color(0.08, 0.12, 0.22, 0.55)
	shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for m in root.find_children("*", "MeshInstance3D", true, false):
		m.material_overlay = shade


func _setup_ship() -> void:
	ship_pivot = _spawn_model(load("res://assets/models/map_barco.glb"),
		_world(ship_px), SHIP_FOOT)
	ship_pivot.position.y = -0.06
	ship_pivot.set_meta("y0", -0.06)
	ship_pivot.rotation_degrees.y = SHIP_YAW
	# El barco lleva su mancha, que viaja con él (ver _update_ship_visual).
	# MÁS PEQUEÑA QUE LA HUELLA DEL BARCO, a propósito. Es una sombra plana a
	# ras de agua y, con la cámara isométrica, lo que está BAJO y CERCA queda
	# por delante en profundidad de lo que está ALTO y AL FONDO: con la mancha
	# a la medida del casco, su esquina cercana ganaba el test de profundidad
	# a las velas y se veía un borrón oscuro sobre la vela de arriba (en el
	# menú, donde el barco va a escala 2.3, saltaba a la vista).
	ship_blob = SceneBackdrop.blob_shadow(SHIP_FOOT * 0.62, SHIP_FOOT * 0.36)
	add_child(ship_blob)


func _setup_camera() -> void:
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(CAM_PITCH, CAM_YAW, 0.0)
	cam.size = CAM_SIZE
	add_child(cam)
	cam.make_current()
	_update_camera()


func _update_camera() -> void:
	var target := _world(Vector2(360.0, cam_center + BAND_CENTER_OFF))
	cam.position = target + cam.transform.basis.z * 30.0


## Instancia un GLB normalizado por su HUELLA horizontal máxima.
func _spawn_model(scene: PackedScene, ground_pos: Vector3, target_foot: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = ground_pos
	add_child(pivot)
	var inst: Node3D = scene.instantiate()
	pivot.add_child(inst)
	var aabb := _merged_aabb(inst)
	var foot := maxf(maxf(aabb.size.x, aabb.size.z), 0.0001)
	var s := target_foot / foot
	inst.scale = Vector3.ONE * s
	inst.position = -Vector3(
		aabb.position.x + aabb.size.x * 0.5,
		aabb.position.y,
		aabb.position.z + aabb.size.z * 0.5) * s
	# El ALTO ya escalado: lo necesita quien cuelgue algo del modelo (el numero
	# del escenario), y calcularlo fuera obligaria a volver a fusionar el AABB.
	pivot.set_meta("alto", aabb.size.y * s)
	return pivot


func _merged_aabb(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = m.transform * m.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


# --- UI 2D -------------------------------------------------------------------

func _setup_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	# Overlays de nodo (debajo de la barra y el panel en orden de dibujo).
	for p in CampaignData.PORTS:
		var ov := _build_node_overlay(p)
		ui.add_child(ov["root"])
		node_overlays[p.id] = ov

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Bajo el notch del móvil: la barra superior del mapa baja el área segura.
	vbox.offset_top = GameState.safe_top()
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(vbox)
	map_ui_root = vbox
	map_top_bar = _build_top_bar()
	vbox.add_child(map_top_bar)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(gap)
	# LA FRANJA DE ABAJO YA NO ES LA FICHA: es el SUBMENU del mapa. La ficha
	# se abre en una VENTANA al tocar un escenario (`_abrir_ficha`), que es lo
	# que le da sitio para contarlo todo en vez de repartirse en dos columnas
	# apretadas contra el canto de la pantalla.
	map_submenu = _build_submenu()
	vbox.add_child(map_submenu)
	map_info_panel = _build_ficha()
	ui.add_child(map_info_panel)


## Overlay 2D de un nodo: botón táctil transparente, estrellas conseguidas y
## cartel de madera con el número. Se reposiciona cada frame con la cámara.
func _build_node_overlay(port: Dictionary) -> Dictionary:
	var id: String = port.id
	var idx := CampaignData.port_index(id)
	var unlocked := GameState.is_port_unlocked(id)
	var best: int = int(GameState.level_stars.get(id, 0))

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var b := Button.new()
	b.custom_minimum_size = Vector2(170, 190)
	b.size = Vector2(170, 190)
	b.position = Vector2(-85, -108)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(_select.bind(id, true))
	root.add_child(b)

	var stars: HBoxContainer = PrepBoard.make_star_row(best, 3, 24, true)
	# MAS ARRIBA que antes (-104): el numero vive ahora dentro del modelo y
	# en el barco queda alto, asi que las estrellas le caian encima.
	stars.position = Vector2(-42, -132)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stars)

	# SIN CHAPA CON EL NUMERO: el numero vive ahora DENTRO del decorado del
	# nodo (ver `_numero_del_nodo`) — escrito en la arena, en el cartel del
	# muelle, en la vela o esculpido en la roca. Un disco flotando delante se
	# leia como un boton mas de la interfaz.
	return { "root": root, "unlocked": unlocked }


## Barra de arriba del MAPA. No es un HBox: el dinero y el arroz son los
## contadores del menú, que viajan hasta los extremos (main_menu), así que aquí
## solo van el rótulo —centrado en el hueco que dejan— y el botón de volver,
## DEBAJO del contador de la izquierda.
func _build_top_bar() -> Control:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 190)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := GameState.safe_top()

	# SIN cinta de título. El lazo rojo de "Aventura" ocupaba justo la franja
	# en la que ahora vive la BARRA DE NIVEL del cocinero, y además no decía
	# nada que el mapa entero no dijera ya. La banda queda para el botón de
	# volver (izquierda) y la barra de nivel (derecha).

	# Flecha DIBUJADA en la madera: el único botón del juego con icono propio.
	var back := PrepBoard.make_back_button()
	back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back.size = Vector2(150, PrepBoard.ICON_BTN_H)
	# DEBAJO de los contadores, que ocupan toda la banda de arriba y ya no se
	# apartan al entrar en Aventura.
	back.position = Vector2(16.0, 16.0 + st + PrepBoard.RESOURCE_H + 34.0)
	back.pressed.connect(_on_map_back)
	bar.add_child(back)
	return bar


## "Atrás" desde el mapa. En la escena fundida (main_menu.gd hereda de aquí)
## no se cambia de escena: el barco vuelve navegando a su fondeadero.
func _on_map_back() -> void:
	# Antes de la primera jornada no se vuelve al menú: Gigi lo impide (ver
	# _guiar_primer_nivel). El botón sigue vivo y respondiendo — apagarlo no
	# habría explicado nada.
	if _atado_al_puerto:
		_gigi_no_te_vas()
		return
	if has_method("_back_to_menu"):
		call("_back_to_menu")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")




## SUBMENU DEL MAPA. Va con un diseño DISTINTO al del menú principal (pedido
## por el usuario): allí son cinco iconos sobre una barra de madera oscura y
## aquí son tres TABLONES anchos con su icono y su rótulo, apoyados en el canto
## de la pantalla. Son dos sitios distintos y tienen que sentirse distintos.
##
## Los tres llevan al jugador FUERA del mapa y los tres vuelven a donde estaba
## (ver `GameState.map_port`): la tienda y las opciones apuntan su origen para
## que "Atrás" devuelva al mapa, no al menú.
const SUBMENU_H := 132.0
const SUBMENU_BOTONES := [
	["tesoro", "res://assets/ui/daily_cofre.png", "Mapas"],
	["tienda", "res://assets/ui/ic_tienda.png", "Tienda"],
	["opciones", "res://assets/ui/ic_opciones.png", "Opciones"],
]


func _build_submenu() -> Control:
	var barra := Control.new()
	barra.custom_minimum_size = Vector2(0, SUBMENU_H)
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fila := HBoxContainer.new()
	fila.set_anchors_preset(Control.PRESET_FULL_RECT)
	fila.offset_left = 18.0
	fila.offset_right = -18.0
	fila.offset_top = 10.0
	fila.offset_bottom = -22.0
	fila.add_theme_constant_override("separation", 14)
	barra.add_child(fila)
	for def in SUBMENU_BOTONES:
		fila.add_child(_boton_submenu(str(def[0]), str(def[1]), str(def[2])))
	return barra


## Un tablón del submenú: icono arriba y rótulo debajo, sobre la madera del
## juego. El icono va DENTRO del botón (no en su `icon`) para poder ponerlo
## encima del rótulo: `Button` solo sabe ponerlo al lado.
func _boton_submenu(id: String, icono: String, rotulo: String) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 100)
	PrepBoard.skin_button(b)
	b.set_meta("snd", "submenu")
	b.text = ""
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 8.0
	col.offset_bottom = -8.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var ic := TextureRect.new()
	ic.texture = load(icono)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(0, 46)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(ic)
	var l := Label.new()
	l.text = rotulo
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 21)
	l.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	l.add_theme_color_override("font_outline_color", Color(0.13, 0.07, 0.02))
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(l)
	b.pressed.connect(_on_submenu.bind(id))
	return b


func _on_submenu(id: String) -> void:
	match id:
		"tesoro":
			_mapas_del_tesoro()
		"tienda":
			GameState.shop_from = "mapa"
			GameState.fade_to_scene("res://scenes/shop_screen.tscn", 0.35, 0.45)
		"opciones":
			GameState.options_from = "mapa"
			GameState.fade_to_scene("res://scenes/options_screen.tscn", 0.35, 0.45)


## LOS MAPAS DEL TESORO son las misiones secundarias, que todavía no existen:
## el botón está desde ya para que se sepa que van a estar, y lo dice él mismo
## en vez de quedarse mudo (un botón que no hace nada se lee como roto).
func _mapas_del_tesoro() -> void:
	var cartel := _aviso_simple("Mapas del tesoro",
		"Aquí guardarás los mapas que encuentres en tus viajes. Todavía no has\nconseguido ninguno.")
	ui.add_child(cartel)


func _build_ficha() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 140
	overlay.visible = false
	var velo := Button.new()
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.06, 0.09, 0.62)
		velo.add_theme_stylebox_override(st, sb)
	velo.set_meta("snd", "")
	velo.pressed.connect(_cerrar_ficha)
	overlay.add_child(velo)

	var panel := PanelContainer.new()
	# MÁS BAJO que antes (470): con la ficha repartida en dos columnas la misma
	# información cabe en mucho menos, y el mapa —que es lo que se está mirando
	# para elegir— recupera un tercio de la pantalla.
	# CENTRADA Y GRANDE: la ficha ya no comparte sitio con el mapa, así que
	# puede contarlo todo de una vez y en una sola columna.
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(FICHA_W, FICHA_H)
	panel.size = Vector2(FICHA_W, FICHA_H)
	panel.position = Vector2(-FICHA_W * 0.5, -FICHA_H * 0.5)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))
	overlay.add_child(panel)
	ficha_panel = panel

	var margin := MarginContainer.new()
	# Los rodillos y las esquinas del pergamino tapaban el texto por los cuatro
	# lados: hace falta más aire del que parece por el dibujo. Y ABAJO hace
	# falta más que arriba, que el marco de madera mide ~50 px (PANEL_MARGIN).
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 52)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 46)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	margin.add_child(vb)

	info_title = Label.new()
	info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_title.add_theme_font_size_override("font_size", 30)
	info_title.add_theme_color_override("font_color", Color(1, 0.82, 0.28))
	info_title.add_theme_color_override("font_outline_color", Color(0.28, 0.11, 0.03))
	info_title.add_theme_constant_override("outline_size", 12)
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		info_title.add_theme_font_override("font", negrita)
	vb.add_child(info_title)

	info_kind = Label.new()
	info_kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_kind.add_theme_font_size_override("font_size", 20)
	info_kind.add_theme_color_override("font_color", Color(0.55, 0.34, 0.08))
	vb.add_child(info_kind)

	info_stars_box = HBoxContainer.new()
	(info_stars_box as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(info_stars_box)

	info_desc = Label.new()
	info_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_desc.add_theme_font_size_override("font_size", 18)
	info_desc.add_theme_color_override("font_color", FADED)
	vb.add_child(info_desc)

	# UNA SOLA COLUMNA, dentro de un SCROLL. Estuvo repartida en dos columnas
	# estrechas porque la ficha vivía pegada al canto de la pantalla y solo
	# tenía 372 px de alto; en ventana cabe entera y se lee de arriba abajo,
	# que es como se lee una ficha.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	TouchScroll.attach(scroll)
	var cuerpo := VBoxContainer.new()
	cuerpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 4)
	scroll.add_child(cuerpo)
	ficha_cuerpo = cuerpo

	var quien := _seccion(cuerpo, "La clientela")
	info_clients_row = _icon_row(quien, "Clientes")
	info_time = _stat_label(quien)
	info_cierre = Label.new()
	info_cierre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_cierre.add_theme_font_size_override("font_size", 17)
	info_cierre.add_theme_color_override("font_color", FADED)
	quien.add_child(info_cierre)

	var carta := _seccion(cuerpo, "La carta")
	info_recipes_row = _icon_row(carta, "Recetas")

	var premios := _seccion(cuerpo, "Objetivos y premios")
	# `goal_box` y `record_box` se cuelgan del PADRE de estas dos etiquetas
	# (ver `_fill_goal_rows`), así que basta con ponerlas aquí.
	info_goal = _stat_label(premios)
	info_record = _stat_label(premios)

	info_tesoro = _seccion(cuerpo, "Tesoro")
	info_tesoro_row = _icon_row(info_tesoro, "Aquí se consigue")

	sail_button = Button.new()
	# Con los premios metidos en la línea de su escalón, la columna derecha
	# perdió una fila entera y el botón puede volver a ser alto: a 62-80 se
	# veía estrecho, que es justo lo que la placa de oro no aguanta (su 9-slice
	# pide 108 para no encogerse — ver `skin_start_button`).
	sail_button.custom_minimum_size = Vector2(282, 100)
	sail_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Placa de oro, igual que el de Arcade: es el botón que arranca la partida.
	# SIN el desplazamiento del rótulo (ver `skin_start_button`): a esta altura
	# la placa llena el rectángulo del botón, así que "Viajar" se centra en él.
	PrepBoard.skin_start_button(sail_button, 0.0)
	# EN NEGRITA DE VERDAD (Exo2-Bold), no con contorno: sobre el oro de la
	# placa la Regular se leia fina al lado del resto de rotulos del mapa.
	var gorda := load("res://fonts/static/Exo2-Bold.ttf")
	if gorda != null:
		sail_button.add_theme_font_override("font", gorda)
	# A la medida de la placa: con 30 sobre un botón de 100 de alto el rótulo
	# nadaba en oro.
	sail_button.add_theme_font_size_override("font_size", 42)
	# EN EL MAPA SE VIAJA, no se zarpa: zarpar es lo que se hace al salir
	# del selector de recetas, y allí suenan las campanas. Aquí, las velas.
	sail_button.text = "Viajar"
	sail_button.set_meta("snd", "velas")
	sail_button.pressed.connect(_on_sail_pressed)

	var pie := HBoxContainer.new()
	pie.alignment = BoxContainer.ALIGNMENT_CENTER
	pie.add_theme_constant_override("separation", 14)
	vb.add_child(pie)
	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.custom_minimum_size = Vector2(160, 76)
	cerrar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	PrepBoard.skin_button(cerrar)
	cerrar.set_meta("snd", "atras")
	cerrar.add_theme_font_size_override("font_size", 24)
	cerrar.pressed.connect(_cerrar_ficha)
	pie.add_child(cerrar)
	pie.add_child(sail_button)
	return overlay


## Un bloque de la ficha: su rótulo a la izquierda y debajo su contenido.
func _seccion(padre: VBoxContainer, titulo: String) -> VBoxContainer:
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 10)
	padre.add_child(sep)
	var t := Label.new()
	t.text = titulo
	t.add_theme_font_size_override("font_size", 21)
	t.add_theme_color_override("font_color", Color(0.55, 0.34, 0.08))
	var negrita2 := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita2 != null:
		t.add_theme_font_override("font", negrita2)
	padre.add_child(t)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 3)
	padre.add_child(caja)
	return caja


## Abre la ficha del escenario. Solo se llama cuando el jugador TOCA un nodo:
## el mapa se coloca solo al entrar y ahí no hay que abrir nada.
func _abrir_ficha() -> void:
	if map_info_panel == null:
		return
	map_info_panel.visible = true
	map_info_panel.modulate.a = 0.0
	create_tween().tween_property(map_info_panel, "modulate:a", 1.0, 0.18)


func _cerrar_ficha() -> void:
	if map_info_panel == null or not map_info_panel.visible:
		return
	var tw := create_tween()
	tw.tween_property(map_info_panel, "modulate:a", 0.0, 0.14)
	tw.tween_callback(func() -> void: map_info_panel.visible = false)


func _stat_label(parent: VBoxContainer) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", DARK)
	parent.add_child(l)
	return l


## Fila "rótulo + iconos" del panel de nivel. El rótulo va a la izquierda y los
## iconos se van añadiendo a la derecha; si no caben, saltan de línea (por eso
## es un HFlowContainer y no un HBox: las columnas son estrechas).
func _icon_row(parent: VBoxContainer, titulo: String) -> Container:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 2)
	row.set_meta("titulo", titulo)
	parent.add_child(row)
	return row


func _row_reset(row: Container) -> void:
	for c in row.get_children():
		c.queue_free()
	var l := Label.new()
	l.text = "%s:" % str(row.get_meta("titulo", ""))
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", DARK)
	row.add_child(l)


## Icono cuadrado con un texto pequeño debajo-derecha ("x4", por ejemplo).
## `hecho` marca una recompensa YA CONSEGUIDA: se le pone un VISTO VERDE encima
## (`ic_hecho.png`, un dibujo del set, no un carácter ✔). Antes se tachaba con
## una raya roja y se leía como "esto no lo tienes", justo lo contrario.
## `apagado` atenúa el icono sin más: lo usan las recetas para las que faltan
## ingredientes.
func _row_icon(row: Container, tex: Texture2D, pie := "", lado := 38,
		hecho := false, apagado := false) -> void:
	if tex == null:
		return
	var caja := Control.new()
	caja.custom_minimum_size = Vector2(lado + (18 if pie != "" else 0), lado)
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = tex
	ic.size = Vector2(lado, lado)
	caja.add_child(ic)
	if pie != "":
		var l := Label.new()
		l.text = pie
		l.position = Vector2(lado - 2, lado * 0.42)
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", DARK)
		caja.add_child(l)
	if apagado:
		ic.modulate = Color(1, 1, 1, 0.38)
	if hecho:
		ic.modulate = Color(1, 1, 1, 0.55)
		var visto := TextureRect.new()
		visto.texture = load("res://assets/ui/ic_hecho.png")
		visto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		visto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		visto.size = Vector2(lado * 0.78, lado * 0.78)
		visto.position = Vector2(lado * 0.24, lado * 0.24)
		visto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caja.add_child(visto)
	row.add_child(caja)


## Clientes del nivel: una cabeza por tipo con su "xN".
func _fill_clients_row(mix: Dictionary, sin_cupo := false) -> void:
	_row_reset(info_clients_row)
	for t in ["E", "A", "G"]:
		var n := int(mix.get(t, 0))
		if n <= 0:
			continue
		var ruta := "res://assets/ui/head_%s.png" % t
		if ResourceLoader.exists(ruta):
			_row_icon(info_clients_row, load(ruta), "" if sin_cupo else "x%d" % n)
	if sin_cupo:
		var l := Label.new()
		l.text = "sin fin"
		l.add_theme_font_size_override("font_size", 19)
		l.add_theme_color_override("font_color", Color(0.55, 0.34, 0.08))
		info_clients_row.add_child(l)


## Recetas que se pueden llevar. Los puertos y los abordajes son de LIBRE
## ELECCIÓN; las islas pueden traer una carta cerrada (`fixed_recipes`).
func _fill_recipes_row(port: Dictionary, id: String) -> void:
	_row_reset(info_recipes_row)
	# Las ISLAS traen carta cerrada también al repetirlas; lo que puede cambiar
	# es la lista (ver CampaignData.fixed_recipes_for).
	var superado: bool = GameState.port_beaten(id)
	var fijas := CampaignData.fixed_recipes_for(id, superado)
	if fijas.is_empty():
		var l := Label.new()
		l.text = "Libre elección"
		l.add_theme_font_size_override("font_size", 19)
		l.add_theme_color_override("font_color", Color(0.55, 0.34, 0.08))
		info_recipes_row.add_child(l)
		var huecos := 4 if superado else int(port.get("recipe_slots", 4))
		if huecos != 4:
			var h := Label.new()
			h.text = "(solo %d)" % huecos
			h.add_theme_font_size_override("font_size", 18)
			h.add_theme_color_override("font_color", DARK)
			info_recipes_row.add_child(h)
		return
	# Una receta para la que NO hay ingredientes sale atenuada: en las islas la
	# carta la manda el diseño, así que conviene ver antes de zarpar cuál de los
	# platos no se va a poder cocinar.
	var faltan: Array = GameState.missing_ingredients(fijas)
	for r in fijas:
		var sin_genero := false
		for ing in RecipeData.get_ingredients(r):
			if ing in faltan:
				sin_genero = true
				break
		_row_icon(info_recipes_row, RecipeData.get_dish_texture(r), "", 40,
				false, sin_genero)


func _reward_label(texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", Color(0.55, 0.34, 0.08))
	return l


## OBJETIVOS Y PREMIOS EN LA MISMA LÍNEA, una por escalón de estrellas:
## "tantas monedas ➜ tantas estrellas ➜ esto te llevas". Estuvieron en dos
## bloques separados —los umbrales arriba y las recompensas debajo, cada uno
## con su hilera de estrellas—, así que las estrellas se dibujaban dos veces y
## había que emparejar a ojo qué premio caía en qué escalón. Juntos, cada
## renglón se lee entero de izquierda a derecha y la columna derecha pierde una
## fila (que es la que le devuelve el alto al botón de Viajar).
##
## UN ESCALÓN YA CONSEGUIDO SE QUEDA SOLO EN SU PREMIO: ni umbral ni estrellas.
## No es un objetivo, es un recuerdo — las estrellas que se tienen ya salen
## arriba, bajo el nombre del escenario, y repetir la cifra de oro de algo que
## se superó hace tres jornadas no ayuda a decidir nada. En un escenario
## exprimido la columna derecha se queda con lo único que sigue vivo: el récord
## y lo que dejó.
func _fill_goal_rows(port: Dictionary, id: String, goal: int, goal_money: int,
		thresholds: Array) -> void:
	if goal_box == null:
		goal_box = VBoxContainer.new()
		goal_box.add_theme_constant_override("separation", 4)
		info_goal.get_parent().add_child(goal_box)
		info_goal.get_parent().move_child(goal_box, info_goal.get_index() + 1)
	for c in goal_box.get_children():
		c.queue_free()
	goal_box.visible = true
	var logradas := int(GameState.level_stars.get(id, 0))
	var escalones: Array = [[goal, goal_money]]
	if thresholds.size() >= 3 and goal < 3:
		escalones.append([3, int(thresholds[2])])
	# HFlow y no HBox: con el umbral, las estrellas y hasta tres premios en el
	# mismo renglón, lo que no quepa en una columna estrecha tiene que SALTAR
	# de línea en vez de estirar la columna.
	for e in escalones:
		var n := int(e[0])
		var fila := HFlowContainer.new()
		fila.add_theme_constant_override("h_separation", 6)
		fila.add_theme_constant_override("v_separation", 2)
		goal_box.add_child(fila)
		if logradas < n:
			fila.add_child(_money_chip(int(e[1])))
			var flecha := TextureRect.new()
			flecha.texture = load("res://assets/ui/ic_siguiente.png")
			flecha.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			flecha.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			flecha.custom_minimum_size = Vector2(30, 26)
			fila.add_child(flecha)
			fila.add_child(PrepBoard.make_star_row(n, 3, 26, true))
		_premios_de(fila, port, n, goal, logradas)
		# Un escalón conseguido y SIN premio no deja nada que enseñar: su línea
		# se queda vacía y solo abriría un hueco en la columna.
		if fila.get_child_count() == 0:
			fila.queue_free()


## Los premios de UN escalón, pegados detrás de sus estrellas. Lo ya conseguido
## va con el VISTO VERDE encima (`_row_icon`), no tachado: una raya roja se leía
## como "esto no lo tienes", justo lo contrario.
func _premios_de(fila: Container, port: Dictionary, escalon: int, meta: int,
		logradas: int) -> void:
	if escalon == meta:
		var hecho := logradas >= meta
		for r in port.get("reward_recipes", []):
			_row_icon(fila, RecipeData.get_dish_texture(r), "", 40, hecho)
		if bool(port.get("unlocks_shop", false)):
			_row_icon(fila, load("res://assets/ui/ic_tienda.png"), "", 40, hecho)
	# Un puerto cuyo objetivo YA son 3 estrellas cobra los dos lotes en la
	# misma línea, que es la única que tiene.
	if escalon != 3:
		return
	var hecho3 := logradas >= 3
	for r in port.get("reward_recipes_3", []):
		_row_icon(fila, RecipeData.get_dish_texture(r), "", 40, hecho3)
	var lingotes := int(port.get("reward_ingots_3", 0))
	if lingotes > 0:
		_row_icon(fila, load("res://assets/ui/ic_lingote.png"),
				"x%d" % lingotes, 34, hecho3)
	var sacos := int(port.get("reward_rice_3", 0))
	if sacos > 0:
		_row_icon(fila, load("res://assets/ui/ic_arroz.png"),
				"x%d" % sacos, 34, hecho3)
	# Usos de despensa (ingredientes o extras) y cebo, los premios de las
	# prácticas: cada ingrediente con su icono y su xN.
	var usos: Dictionary = port.get("reward_ingredients_3", {})
	for ing in usos:
		_row_icon(fila, RecipeData.get_ingredient_texture(str(ing)),
				"x%d" % int(usos[ing]), 34, hecho3)
	var cebos := int(port.get("reward_bait_3", 0))
	if cebos > 0:
		_row_icon(fila, load("res://assets/ui/ic_cebo.png"),
				"x%d" % cebos, 34, hecho3)


## Moneda + cifra, que es como se enseña el dinero en toda la ficha.
func _money_chip(cantidad: int, cuerpo := 24) -> HBoxContainer:
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 5)
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	var mon := TextureRect.new()
	mon.texture = load("res://assets/ui/moneda.png")
	mon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mon.custom_minimum_size = Vector2(cuerpo + 6, cuerpo + 6)
	caja.add_child(mon)
	var l := Label.new()
	l.text = str(cantidad)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", cuerpo)
	l.add_theme_color_override("font_color", DARK)
	caja.add_child(l)
	return caja


## El récord, con su moneda al lado en vez de "Récord: 61".
## Con el puerto ya EXPRIMIDO (3 estrellas) el récord pasa a ser lo único que
## queda por mejorar, así que se enseña en grande.
## SIN JUGAR NO SALE NADA. Estaba escribiendo "Récord: sin jugar", que es un
## renglón para decir que no hay nada que decir: la ficha de un escenario nuevo
## ya se entiende sin él, y el hueco se lo queda el botón.
func _fill_record_row(rec: int, grande := false) -> void:
	if record_box == null:
		record_box = HBoxContainer.new()
		record_box.alignment = BoxContainer.ALIGNMENT_BEGIN
		record_box.add_theme_constant_override("separation", 8)
		info_record.get_parent().add_child(record_box)
		info_record.get_parent().move_child(record_box, info_record.get_index() + 1)
	info_record.visible = false
	for c in record_box.get_children():
		c.queue_free()
	record_box.visible = rec > 0
	if rec <= 0:
		return
	# MAS PEQUENO que antes (30/20): esta fila y las dos de objetivos empujaban
	# la columna derecha hacia abajo y el boton de "Viajar" se salia por el
	# canto del pergamino.
	var cuerpo := 25 if grande else 17
	var l := Label.new()
	l.text = "Récord:"
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", cuerpo)
	l.add_theme_color_override("font_color", DARK if grande else FADED)
	record_box.add_child(l)
	record_box.add_child(_money_chip(rec, 28 if grande else 19))


## Vuelca en el panel el nombre del nivel y TODAS sus características.
func _update_info(id: String) -> void:
	var port := CampaignData.get_port(id)
	if port.is_empty():
		return
	var idx := CampaignData.port_index(id)
	var unlocked := GameState.is_port_unlocked(id)
	var best: int = int(GameState.level_stars.get(id, 0))

	# Solo el NOMBRE del puerto, estilizado: el "Nivel N" no aportaba nada que
	# no dijera ya el cartel del propio nodo en el mapa.
	info_title.text = str(port.get("name", id))
	info_kind.text = CampaignData.kind_name(id)
	# NIVEL DE COCINERO RECOMENDADO (`chef_rec` del puerto): es lo que permite
	# distinguir "voy corto de nivel" de "lo estoy jugando mal". SIN el
	# "(llevas N)" que llevaba detrás: el jugador tiene su nivel escrito en la
	# barra, justo encima, y repetirlo aquí solo sonaba a reproche.
	var rec_chef := int(port.get("chef_rec", 0))
	if rec_chef > 0:
		info_kind.text += "  ·  Nivel recomendado: %d" % rec_chef
	# La frase descriptiva sobra: la ficha ya lo cuenta todo con sus iconos.
	# Solo queda el aviso de nivel bloqueado.
	info_desc.text = "" if unlocked \
		else "Bloqueado: supera el nivel anterior para navegar hasta aquí."
	info_desc.visible = not unlocked

	for c in info_stars_box.get_children():
		c.queue_free()
	info_stars_box.add_child(PrepBoard.make_star_row(best, 3, 30, true))

	var mix: Dictionary = port.get("client_mix", {})
	# En un abordaje la clientela no tiene cupo: la mezcla solo dice QUIÉN se
	# sienta, no cuántos, así que las cabezas van sin su "xN".
	_fill_clients_row(mix, CampaignData.unlimited_clients(id))
	_fill_recipes_row(port, id)
	# El reloj solo lo llevan los abordajes; las islas y los puertos los cierra
	# la clientela, y una línea de "Tiempo" ahí sería mentira.
	var t := int(CampaignData.time_limit_for(id))
	info_time.visible = t > 0
	info_time.text = "Tiempo: %d:%02d" % [t / 60, t % 60]
	var thresholds: Array = port.get("star_money", [])
	var goal := int(port.get("goal_stars", 1))
	var goal_money: int = int(thresholds[goal - 1]) if thresholds.size() >= goal else 0
	# El objetivo se enseña EN GRÁFICO (estrellas + moneda + cifra) en vez de
	# la línea "Objetivo: 2★ (30)", que se leía como una ficha técnica.
	# Con las TRES ESTRELLAS ya en el bolsillo no queda escalón que alcanzar:
	# desaparecen los objetivos y el récord pasa a primer plano, que es lo único
	# que se puede seguir mejorando en ese puerto.
	info_cierre.text = _texto_cierre(id)
	_fill_tesoro(id)
	var exprimido := best >= 3
	info_goal.visible = false
	_fill_goal_rows(port, id, goal, goal_money, thresholds)
	var rec := GameState.get_level_score(id)
	_fill_record_row(rec, exprimido)

	sail_button.disabled = not unlocked
	sail_button.text = "Viajar" if unlocked else "Bloqueado"
	PrepBoard.set_dimmed(sail_button, sail_button.disabled)
	_ajustar_ficha()


## LA VENTANA SE AJUSTA A SU CONTENIDO. Hay que esperar DOS fotogramas: los
## contenedores de Godot reparten a sus hijos de forma diferida, así que justo
## después de rellenar la ficha el cuerpo sigue midiendo lo de la anterior.
func _ajustar_ficha() -> void:
	if ficha_panel == null or ficha_cuerpo == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if ficha_panel == null or not is_instance_valid(ficha_panel):
		return
	var alto := clampf(ficha_cuerpo.get_combined_minimum_size().y + FICHA_EXTRA,
		FICHA_MIN, FICHA_MAX)
	ficha_panel.size = Vector2(FICHA_W, alto)
	ficha_panel.position = Vector2(-FICHA_W * 0.5, -alto * 0.5 + FICHA_BAJADA)


## CÓMO SE CIERRA LA JORNADA Y QUÉ CASTIGA EL TIPO. Es la información que el
## jugador necesita ANTES de zarpar y que hasta ahora solo estaba en la guía:
## un abordaje no se juega como una isla, y el panel no lo decía en ninguna
## parte. Sale de los mismos datos que gobiernan el nivel, así que no puede
## contradecirlo.
func _texto_cierre(id: String) -> String:
	var sin_fin := CampaignData.unlimited_clients(id)
	match CampaignData.get_kind(id):
		"isla":
			return "Acaba cuando se va el último cliente. Quien se marche sin probar bocado te cuesta oro."
		"puerto":
			return "Acaba cuando se va el último cliente. Si TRES se marchan sin probar bocado, pierdes la jornada."
		"abordaje":
			return "Clientela sin fin contra el reloj. Cada cliente que se marcha sin probar bocado te quita 15 s."
		"cueva":
			return "La guarida del jefe: clientela sin fin hasta que él aparece. Ahí manda su paciencia, no el reloj."
	return "Clientela sin fin." if sin_fin else ""


## EL COLECCIONABLE QUE SE PUEDE CONSEGUIR AQUÍ, con una interrogación encima
## mientras no se tenga: dice que en este escenario hay algo que llevarse sin
## desvelar qué es. Ya conseguido sale a plena luz y con su visto.
func _fill_tesoro(id: String) -> void:
	var item := CampaignData.collectible_of(id)
	info_tesoro.get_parent().visible = item != ""
	if item == "":
		return
	_row_reset(info_tesoro_row)
	var tengo := GameState.has_collectible(item)
	var tex: Texture2D = CollectibleData.get_icon(item)
	if tex == null:
		return
	var caja := Control.new()
	caja.custom_minimum_size = Vector2(52, 48)
	var ic := TextureRect.new()
	ic.texture = tex
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size = Vector2(48, 48)
	# EN SILUETA mientras no se tenga, como en la vitrina: la pieza existe,
	# pero cuál es se descubre consiguiéndola.
	ic.modulate = Color.WHITE if tengo else Color(0.14, 0.11, 0.09, 0.9)
	caja.add_child(ic)
	if not tengo:
		var q := Label.new()
		q.text = "?"
		q.set_anchors_preset(Control.PRESET_FULL_RECT)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.add_theme_font_size_override("font_size", 32)
		q.add_theme_color_override("font_color", Color(1, 0.88, 0.42))
		q.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.02))
		q.add_theme_constant_override("outline_size", 8)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caja.add_child(q)
	info_tesoro_row.add_child(caja)
	# RichTextLabel y no Label: la pista trae palabras clave entre `**` y
	# `format_keywords` devuelve BBCode — con un Label se leían los asteriscos.
	var como := RichTextLabel.new()
	como.bbcode_enabled = true
	como.fit_content = true
	como.scroll_active = false
	como.text = DialogueBox.format_keywords(
		CampaignData.collectible_how(id, item))
	como.custom_minimum_size = Vector2(FICHA_W - 250.0, 0)
	como.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	como.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	como.add_theme_font_size_override("normal_font_size", 16)
	como.add_theme_font_size_override("bold_font_size", 16)
	como.add_theme_color_override("default_color", FADED)
	info_tesoro_row.add_child(como)


## Cartel simple de "esto todavía no existe", con su botón de cerrar. No usa el
## diálogo con retrato: aquí no habla nadie, solo se avisa.
func _aviso_simple(titulo: String, texto: String) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 150
	var velo := Button.new()
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.06, 0.09, 0.6)
		velo.add_theme_stylebox_override(st, sb)
	velo.set_meta("snd", "")
	velo.pressed.connect(overlay.queue_free)
	overlay.add_child(velo)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(600, 360)
	panel.size = Vector2(600, 360)
	panel.position = Vector2(-300, -180)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))
	overlay.add_child(panel)
	var mg := MarginContainer.new()
	for side in ["left", "right"]:
		mg.add_theme_constant_override("margin_%s" % side, 54)
	mg.add_theme_constant_override("margin_top", 40)
	mg.add_theme_constant_override("margin_bottom", 44)
	panel.add_child(mg)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	mg.add_child(vb)
	vb.add_child(PrepBoard.make_big_title(titulo))
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", DARK)
	vb.add_child(l)
	var b := Button.new()
	b.text = "Cerrar"
	b.custom_minimum_size = Vector2(0, 70)
	PrepBoard.skin_button(b)
	b.set_meta("snd", "atras")
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(overlay.queue_free)
	vb.add_child(b)
	Audio.ventana(overlay)
	return overlay


# --- Selección, viaje y scroll ----------------------------------------------

## Punto donde se coloca el barco al llegar a un nivel: al costado del nodo,
## siempre hacia el centro del mapa (en px de mapa, como en 2D).
func _ship_anchor(id: String) -> Vector2:
	var p := CampaignData.map_pos(id)
	var side := -1.0 if p.x > 360.0 else 1.0
	return p + Vector2(side * 158.0, 72.0)


func _select(id: String, animate: bool) -> void:
	selected_id = id
	# Se recuerda para cuando se vuelva de otra pantalla (ver
	# `_puerto_de_partida`).
	GameState.map_port = id
	_update_info(id)
	# La ventana se abre solo si el jugador ha TOCADO el nodo (`animate`): al
	# entrar en el mapa se coloca el barco sin abrir nada.
	if animate:
		_abrir_ficha()
	var target := _ship_anchor(id)
	if ship_tween != null:
		ship_tween.kill()
		ship_tween = null
	if not animate or not GameState.is_port_unlocked(id):
		# Los niveles bloqueados solo muestran su ficha: el barco no viaja.
		if not animate:
			ship_px = target
		return
	# Viaje: la duración crece con la distancia, con un leve balanceo extra.
	var dist := ship_px.distance_to(target)
	var dur := clampf(dist / 420.0, 0.35, 1.4)
	# EL CRUJIDO DURA LO QUE DURA EL VIAJE, con fundido a la entrada y a la
	# salida para que no empiece ni acabe a cuchillo, y con el TONO sorteado:
	# es el mismo crujido, y cambiando de nivel diez veces seguidas sonaba
	# siempre igual.
	# Y ARRANCA YA DENTRO DE LA MADERA, no en la cabeza de la toma: sus
	# primeras décimas son las más flojas y en un salto corto entre dos
	# niveles vecinos no daba tiempo a oír el crujido. El punto de
	# entrada también se sortea, que es variedad gratis.
	Audio.sfx_suave("barco_mover", 0.0, minf(dur * 0.35, 0.35),
		randf_range(0.86, 1.16), dur, randf_range(0.45, 1.30))
	ship_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ship_tween.tween_property(self, "ship_px", target, dur)
	ship_tween.parallel().tween_property(self, "ship_roll", 5.0, dur * 0.5)
	ship_tween.parallel().tween_property(self, "ship_roll", 0.0, dur * 0.5) \
		.set_delay(dur * 0.5)
	_scroll_to(CampaignData.map_pos(id))


## PRIMERA VISITA AL MAPA: David explica los tres tipos de nivel y ata al
## jugador al primer puerto — no hay velo ni foco, se ve el mapa entero, pero
## el botón "Atrás" no funciona hasta que zarpa (Gigi se encarga de decirlo).
## `caja` viene puesta cuando esto ENCADENA con la explicación del arroz
## (`main_menu._presentar_mapa`): David sigue hablando en el mismo pergamino en
## vez de cerrarlo y volver a entrar, que era un corte a mitad de idea. Sin
## caja, se monta una propia (camino que hoy no usa nadie, pero la guía tiene
## que poder salir sola).
func _guiar_primer_nivel(caja: DialogueBox = null) -> void:
	var primero := CampaignData.first_port_id()
	if GameState.map_intro_done or primero == "":
		if caja != null and is_instance_valid(caja):
			await caja.close_and_free()
		return
	_atado_al_puerto = true
	if caja == null:
		await get_tree().create_timer(0.5).timeout
		caja = DialogueBox.new()
		caja.z_index = 200
		# Sin velo: aquí no se señala nada, se explica el mapa entero.
		caja.veil_on = false
		ui.add_child(caja)
	caja.say([
		{ "text": "Nuestra primera parada es esa de ahí: **Cala Tortuga**, una **isla**.", "mood": "feliz" },
		# SOLO SE EXPLICA LA ISLA. Los otros dos tipos se cuentan cuando se
		# pisan (`level_director._explicar_handicap`): tres clases de parada de
		# golpe, antes de haber jugado ni una, es una lección que no se puede
		# aplicar a nada.
		{ "text": "Las **islas** son tranquilas: poca clientela y con la carta que yo te ponga... pero el que se vaya sin comer te cuesta oro.", "mood": "hablando" },
		{ "text": "Hay otras clases de parada, y ya las verás cuando toque. Dale a **¡Zarpar!** cuando quieras.", "mood": "feliz" },
	])
	await caja.finished
	await caja.close_and_free()


## Gigi corta al jugador si intenta volverse al menú antes de su primera
## jornada. No es un botón apagado: es un loro gritando, que se entiende mejor.
func _gigi_no_te_vas() -> void:
	if _regana_atras:
		return
	_regana_atras = true
	var caja := DialogueBox.new()
	caja.z_index = 200
	caja.veil_on = false
	ui.add_child(caja)
	caja.say([
		{ "text": "¡¿A DÓNDE CREES QUE VAS?! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
		{ "text": "¡¿Abandonando el barco en tu primer día?! ¡Te tiro por la borda y que te coman los tiburones!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Déjalo, plumas... pero tiene razón: hoy se zarpa. **Cala Tortuga** te espera.", "mood": "loro_resignado" },
	])
	await caja.finished
	caja.queue_free()
	_regana_atras = false


func _scroll_to(point: Vector2) -> void:
	var target := clampf(point.y, SCROLL_MIN, SCROLL_MAX)
	if scroll_tween != null:
		scroll_tween.kill()
	scroll_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scroll_tween.tween_property(self, "cam_center", target, 0.5)


## Arrastre vertical sobre el mar = scroll del mapa (los botones de los nodos
## capturan sus propios toques).
func _unhandled_input(event: InputEvent) -> void:
	# En el menú principal (la escena hace de las dos cosas) no se recorre el
	# mapa: arrastrando se llegaba a ver los niveles antes de tiempo.
	if not map_visible:
		return
	if event is InputEventScreenDrag:
		if scroll_tween != null:
			scroll_tween.kill()
			scroll_tween = null
		cam_center = clampf(cam_center - event.relative.y, SCROLL_MIN, SCROLL_MAX)
		# Velocidad del dedo, suavizada, para que al soltar el mapa siga
		# corriendo: un tirón fuerte recorre más ruta que un arrastre suave.
		scroll_dragging = true
		var dt := maxf(get_process_delta_time(), 0.0001)
		scroll_speed = lerpf(scroll_speed, -event.relative.y / dt, DRAG_SMOOTH)
	elif event is InputEventScreenTouch:
		# Al posar el dedo se para la inercia; al levantarlo, corre sola.
		if event.pressed:
			scroll_speed = 0.0
		scroll_dragging = event.pressed


func _on_sail_pressed() -> void:
	if selected_id == "" or not GameState.is_port_unlocked(selected_id):
		return
	# Zarpar por primera vez cierra la guía del mapa: a la vuelta, el jugador
	# ya se mueve por donde quiera.
	if _atado_al_puerto:
		_atado_al_puerto = false
		GameState.map_intro_done = true
		GameState.save_game()
	GameState.mode = "adventure"
	GameState.current_port = selected_id
	GameState.selected_recipes = []
	# Los puertos de CARTA CERRADA (las islas) NO pasan por el selector, ni la
	# primera vez ni al repetirlos: se juega con las recetas que manda el nivel.
	# Como el jugador no elige, tampoco puede esquivar un ingrediente que le
	# falte, así que aquí es donde se le avisa antes de zarpar.
	var fijas := CampaignData.fixed_recipes_for(
			selected_id, GameState.port_beaten(selected_id))
	if fijas.is_empty():
		GameState.fade_to_scene("res://scenes/prep_screen.tscn", 0.35, 0.45)
		return
	var faltan := GameState.missing_ingredients(fijas)
	if faltan.is_empty():
		_zarpar_con(fijas)
		return
	# SIN TIENDA TODAVÍA (abre en el nivel 4) el jugador no tiene DÓNDE
	# reponer: quedarse a cero sería un callejón sin salida. Así que David le
	# rellena lo que le falte y se zarpa igual, tantas veces como haga falta.
	if not GameState.shop_unlocked():
		await _david_regala_genero(faltan)
		GameState.gift_missing_ingredients(fijas)
		_zarpar_con(fijas)
		return
	_avisar_falta_genero(fijas, faltan)


## David rellena la despensa cuando el jugador se queda a cero ANTES de que
## abra la tienda. No es un premio: es la red de seguridad de la escuela.
func _david_regala_genero(faltan: Array) -> void:
	var caja := DialogueBox.new()
	ui.add_child(caja)
	caja.say([
		{ "text": "¡RAAAK! ¡DESPENSA VACÍA! ¡Que no queda %s!"
			% _lista(_nombres_ingredientes(faltan)), "who": "gigi", "mood": "loro_grito" },
		{ "text": "Tranquilo, para eso está el capitán. Toma **%d usos** de cada cosa que te falte, de mi **reserva particular**."
			% GameState.RESCUE_GIFT, "mood": "feliz" },
	])
	await caja.finished
	await caja.close_and_free()


## ¿Puede el jugador llevarse hoy algún bonificador? (desbloqueado y con usos).
func _hay_bonificadores() -> bool:
	for id in PerkData.ids():
		if GameState.is_perk_unlocked(id) and GameState.get_perk_uses(id) > 0:
			return true
	return false


## Manda al nivel con una carta cerrada ya decidida.
func _zarpar_con(recetas: Array[String]) -> void:
	GameState.selected_recipes = recetas
	GameState.selected_perks = []
	# LA CARTA NO SE ELIGE, PERO EL BONIFICADOR SÍ (pedido por el usuario): con
	# alguno disponible, la isla pasa por el selector igual — allí la carta sale
	# puesta y sin tocar, y debajo la fila de bonificadores. Saltándose la
	# pantalla, quien tuviera a Alice no podía llevársela a ninguna isla.
	# Sin ninguno que elegir se va directo, como siempre: una pantalla entera
	# para pulsar "¡Zarpar!" no es una decisión.
	if _hay_bonificadores():
		GameState.fade_to_scene("res://scenes/prep_screen.tscn", 0.35, 0.45)
		return
	GameState.fade_to_scene("res://scenes/level3d.tscn", 0.35, 0.45)


## Gigi canta los ingredientes que faltan para la carta de esta isla y ofrece
## las tres salidas: jugar igualmente, pasarse por la tienda o volver al mapa.
func _avisar_falta_genero(recetas: Array[String], faltan: Array) -> void:
	var caja := DialogueBox.new()
	ui.add_child(caja)
	caja.say([
		{ "text": "¡RAAAK! ¡ALTO AHÍ! ¡Te falta género en la despensa!",
			"who": "gigi", "mood": "loro_grito" },
		{ "text": "No te queda %s, así que hoy no puedes preparar %s." % [
				_lista(_nombres_ingredientes(faltan)),
				_lista(_nombres_recetas(_recetas_afectadas(recetas, faltan)))],
			"who": "gigi", "mood": "loro" },
	])
	await caja.finished
	caja.queue_free()
	_panel_falta_genero(recetas)


func _panel_falta_genero(recetas: Array[String]) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 150
	ui.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := Control.new()
	box.custom_minimum_size = Vector2(540, 380)
	center.add_child(box)
	box.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 58.0
	vb.offset_top = 46.0
	vb.offset_right = -58.0
	vb.offset_bottom = -48.0
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(vb)

	var titulo := PrepBoard.make_big_title("¿Jugar igualmente?", 44)
	titulo.custom_minimum_size = Vector2(0, 76)
	vb.add_child(titulo)

	var msg := Label.new()
	msg.text = "Sin esos ingredientes esas recetas no se podrán cocinar en el nivel."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 21)
	msg.add_theme_color_override("font_color", Color(0.42, 0.3, 0.18))
	vb.add_child(msg)

	# Los dos botones EN UNA LÍNEA: apilados ocupaban media pantalla.
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 14)
	vb.add_child(btns)
	var jugar := Button.new()
	jugar.text = "Jugar"
	jugar.custom_minimum_size = Vector2(178, PrepBoard.ICON_BTN_H)
	PrepBoard.skin_action_button(jugar, true)
	jugar.add_theme_font_size_override("font_size", 22)
	jugar.pressed.connect(func() -> void: _zarpar_con(recetas))
	btns.add_child(jugar)
	# La tienda puede no estar abierta todavía (el nivel 1 es una isla y Saverio
	# aparece en el 2): entonces no se ofrece.
	if GameState.shop_unlocked():
		var tienda := Button.new()
		tienda.text = "Tienda"
		tienda.custom_minimum_size = Vector2(196, PrepBoard.ICON_BTN_H)
		PrepBoard.skin_button(tienda)
		tienda.add_theme_font_size_override("font_size", 22)
		# Con SU icono, como el "Jugar" lleva su visto: el rótulo se corre a la
		# derecha para dejarle sitio.
		var ic := TextureRect.new()
		ic.texture = load("res://assets/ui/ic_tienda.png")
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		ic.offset_left = 8.0
		ic.offset_right = 62.0
		ic.offset_top = -3.0
		ic.offset_bottom = 3.0
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tienda.add_child(ic)
		for st in ["normal", "hover", "pressed", "focus"]:
			var pad := StyleBoxEmpty.new()
			pad.content_margin_left = 66.0
			pad.content_margin_right = 12.0
			tienda.add_theme_stylebox_override(st, pad)
		tienda.pressed.connect(func() -> void:
			GameState.fade_to_scene("res://scenes/shop_screen.tscn", 0.35, 0.45))
		btns.add_child(tienda)

	# La X cierra y devuelve el mando al mapa, sin zarpar. Botón CUADRADO con
	# su propia textura: con el tablón ancho de `skin_action_button` la equis
	# quedaba pegada al borde izquierdo y no centrada.
	var cerrar := TextureButton.new()
	cerrar.texture_normal = load("res://assets/ui/boton_cerrar.png")
	cerrar.ignore_texture_size = true
	cerrar.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	cerrar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cerrar.offset_left = -76.0
	cerrar.offset_top = 12.0
	cerrar.offset_right = -12.0
	cerrar.offset_bottom = 76.0
	PrepBoard.add_press_feedback(cerrar)
	cerrar.pressed.connect(overlay.queue_free)
	box.add_child(cerrar)


## Recetas de la carta que se quedan sin poder cocinarse.
func _recetas_afectadas(recetas: Array[String], faltan: Array) -> Array[String]:
	var out: Array[String] = []
	for rid in recetas:
		for ing in RecipeData.get_ingredients(rid):
			if ing in faltan and not rid in out:
				out.append(rid)
	return out


func _nombres_ingredientes(ids: Array) -> Array[String]:
	var out: Array[String] = []
	for id in ids:
		out.append(str(RecipeData.get_ingredient(id).get("name", id)).to_lower())
	return out


func _nombres_recetas(ids: Array) -> Array[String]:
	var out: Array[String] = []
	for id in ids:
		out.append(str(RecipeData.get_recipe(id).get("name", id)).to_lower())
	return out


## "a", "a y b", "a, b y c".
func _lista(nombres: Array[String]) -> String:
	if nombres.is_empty():
		return ""
	if nombres.size() == 1:
		return "**%s**" % nombres[0]
	var marcados: Array[String] = []
	for n in nombres:
		marcados.append("**%s**" % n)
	return ", ".join(marcados.slice(0, marcados.size() - 1)) \
			+ " y " + marcados[-1]


# ------------------------------------------------------------------- bucle

## Altura del agua AHORA. La misma cuenta la hace el shader del mar por
## vértice, así que barcos y agua suben acompasados.
func marea() -> float:
	return (sin(_t * TAU / MAREA_PERIODO) * 0.5 + 0.5) * MAREA_AMP


func _process(delta: float) -> void:
	_t += delta
	var m := marea()
	if sea_mat != null:
		sea_mat.set_shader_parameter("marea", m)
	for f in flotantes:
		if is_instance_valid(f):
			f.position.y = f.get_meta("y0", 0.0) + m
	# LA NIEBLA DE LA CUEVA gira despacio alrededor del peñasco. Con "menos
	# animaciones" se queda quieta donde la dejó su colocación inicial: sigue
	# tapando, que es su oficio, pero deja de costar fotograma.
	if GameState.animations_on():
		_mover_niebla()
	# Inercia del arrastre del mapa: la velocidad que llevaba el dedo al soltar
	# se va apagando sola. Con el dedo apoyado no se aplica (manda el dedo)
	# pero TAMPOCO se borra: es la que da el impulso al levantarlo. Cualquier
	# viaje del barco (`scroll_tween`) manda sobre las dos cosas.
	if scroll_dragging:
		pass
	elif absf(scroll_speed) > SCROLL_STOP and scroll_tween == null:
		var target := clampf(cam_center + scroll_speed * delta,
			SCROLL_MIN, SCROLL_MAX)
		if is_equal_approx(target, cam_center):
			scroll_speed = 0.0  # tope del mapa: se para en seco
		else:
			cam_center = target
			scroll_speed *= pow(SCROLL_FRICTION, delta)
	else:
		scroll_speed = 0.0
	_update_camera()

	# Balanceo del barco sobre las olas (sustituye a las velas animadas del
	# spritesheet 2D) + el rolido extra del viaje.
	if ship_pivot != null:
		# El cabeceo sobre las olas es adorno: con "menos animaciones" el barco
		# navega quieto (el rolido del viaje sí se mantiene, guía la mirada).
		var bob := GameState.animations_on()
		ship_pivot.position = _world(ship_px) \
			+ Vector3(0.0, -0.06 + marea()
				+ (sin(_t * 1.4) * 0.03 if bob else 0.0), 0.0)
		ship_pivot.rotation_degrees = Vector3(
			sin(_t * 1.1) * 2.0 if bob else 0.0, SHIP_YAW,
			(sin(_t * 1.7) * 2.5 if bob else 0.0) + ship_roll)
		# La mancha sigue al barco pero NO cabecea con él: es una sombra en el
		# agua, no una copia del casco.
		# Y APARTADA DE LA CÁMARA (-x, -z), por lo mismo: acercarla la ponía
		# por delante del propio barco en el test de profundidad.
		if ship_blob != null:
			# EL DESPLAZAMIENTO ESCALA CON EL BARCO. La mancha se agranda con
			# `scale` (en el menú, ×2.75) pero el apartado iba en unidades fijas
			# de mapa, así que en el menú la mancha crecía y no se apartaba: su
			# esquina cercana pasaba por delante de las velas y dejaba un borrón
			# gris sobre el aparejo. Con el apartado escalado, la proporción es
			# la misma en el mapa y en el menú.
			var esc: float = ship_blob.scale.x
			ship_blob.position = _world(ship_px) \
					+ Vector3(-0.30, 0.04, -0.26) * esc \
					+ Vector3(0.0, marea(), 0.0)

	# Overlays 2D anclados a sus nodos 3D.
	if not map_visible:
		return
	for id in node_overlays:
		var scr := cam.unproject_position(node_world[id] + Vector3(0.0, 0.55, 0.0))
		node_overlays[id]["root"].position = scr
