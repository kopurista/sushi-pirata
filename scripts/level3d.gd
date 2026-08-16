extends Node3D
## Orquestador del nivel en 3D (port de level.gd con la MISMA logica de juego):
## cinta, spawner de clientes, HUD, propinas, potenciadores y puntuacion.
## El mundo (cubierta, mostrador, cinta, atrezzo) se construye por codigo; el
## HUD es el CanvasLayer 2D del juego original, sin cambios (level3d.tscn).
##
## CONTRATO DE COORDENADAS (derivado del layout 2D para reproducirlo):
## - Camara isometrica ortogonal: pitch -35.264, yaw 45, size 15.
##   Con el viewport 720x1280 eso da ~85.3 px por unidad de mundo.
## - La cinta 2D era un rombo de 436x256 px = un CUADRADO de lado 3.6 u en
##   verdadera isometria (el juego 2D ya dibujaba iso real: 256/436 = 0.587 =
##   sin(35.264)). El circuito es un cuadrado centrado en el origen, ejes X/Z.
## - Velocidad de platos: 0.9 u/s en la conversion del 2D (75 px/s), subida
##   despues a 1.35 por ritmo (ver PLATE_SPEED). Los clientes andan a
##   la velocidad natural de su ciclo de marcha (~1.2 u/s, mas lenta que los
##   2.2 del 2D: decision tomada para que los pies no patinen).

const PrepBoard := preload("res://scripts/prep_board.gd")

const CLIENT3D := preload("res://scripts/client3d.gd")
const PLATE3D := preload("res://scripts/plate3d.gd")

## Fotogramas por segundo jugando (los menus se conforman con la mitad).
const GAME_FPS := 60

const TOTAL_CLIENTS := 10
## Duracion de una partida en los niveles CON reloj (modo prueba y abordajes;
## la campaña manda el suyo). El reloj no corre durante la fase de preparacion.
const TIME_LIMIT := 150.0
## Ventana por defecto sobre la que se reparten las llegadas (ver arrival_span).
const ARRIVAL_SPAN := 150.0
## Margen antes del final en el que ya no llega ningun cliente.
const ARRIVAL_TAIL := 22.0
## Momento de la primera llegada, en segundos desde que arranca el turno. Un
## puerto puede adelantarla con `first_arrival` (el nivel 1 la pone a 0: el
## primer grumete entra en cuanto se acaba la preparación, sin espera muerta).
const FIRST_ARRIVAL := 5.0
var first_arrival := FIRST_ARRIVAL
## Tope de espera del cartel de fin mientras alguien termina su ultimo bocado
## (un plato de nivel 3 puede llevar 17 s): red de seguridad, no debe hacer falta.
const END_BITE_MAX := 25.0
## Margen tras el ultimo cobro para que se lea el "+$N" antes del cartel.
const END_PAY_LINGER := 1.6
## Umbrales de dinero para 1★/2★/3★ en el modo prueba (en aventura los define
## cada nivel de la campaña con "star_money").
const DEFAULT_STAR_MONEY := [16, 30, 45]
## Incrementos del bote de propinas (acumulado: 10, 22, 36, 52...).
const TIP_INCREMENTS := [10, 12, 14, 16, 18, 20, 24, 28, 32, 36, 40, 48, 60]

# --- Camara ---
const CAM_PITCH := -35.264
const CAM_YAW := 45.0
## Un poco mas alejada que el 1:1 con el 2D (15.0) para ver mas escenario.
const CAM_SIZE := 17.0
## Objetivo desplazado por el suelo para que el centro de la cinta caiga en el
## centro de la banda visible, no en el centro de la pantalla. La banda va
## desde el borde superior (el HUD ya no tiene barra opaca) hasta la tabla de
## preparación, que ahora es más alta: su centro está en y~395 px.
const CAM_TARGET := Vector3(3.25, 0.0, 3.25)

# --- Circuito de la cinta ---
const BELT_SIDE := 3.6        ## lado del cuadrado (linea central de la banda)
const BELT_W := 0.6           ## ancho de la banda movil
const BELT_TOP := 0.8         ## altura del mostrador / banda
const COUNTER_W := 1.1        ## ancho del mostrador de madera bajo la banda
const CORNER := 0.78          ## lado de la placa metalica de cada esquina
## Lado del icono de cabeza del contador de clientes del HUD.
const HEAD_ICON := 54.0
## Cajas de guardado 3D junto al chef (gemelas de las del HUD).
const CRATE_H := 0.30
const CRATE_LIFT := 0.72   ## alto del banco que sube las cajas sobre el mostrador
## Texturas de madera del escenario (tileadas por triplanar, ver _wood_mat).
const DECK_TEX := "res://assets/props/madera_desgastada.webp"
## Tablones del MUELLE: madera blanqueada por el sol, distinta de la cubierta
## del barco (antes compartían textura y los dos escenarios se parecían).
const DOCK_TEX := "res://assets/props/madera_muelle.webp"
const CRATE_TEX := "res://assets/props/madera_caja.webp"
## Tinte de las cajas de modelo: apaga el naranja de fabrica a madera vieja.
const CRATE_TINT := Color(0.58, 0.50, 0.44)
## Velocidad de los platos por la cinta, en u/s. Subida desde 0.9: el circuito
## mide 14.4 u (4 lados de BELT_SIDE), así que a 0.9 una vuelta duraba 16 s de
## los 150 del nivel y con ~30 platos por partida la cinta enseñaba 3 de media
## — una cinta kaiten con tres platos no parece una cinta. A 1.25 la vuelta
## baja a ~11.5 s. NO toca el equilibrio: el dado de coger un plato se tira UNA
## vez al entrar en el radio del cliente (ver client3d._scan_belt y `declined`),
## así que la velocidad solo cambia el ritmo, no las probabilidades.
## Se probó a 1.35 y va justo por encima de lo cómodo para decidir.
const PLATE_SPEED := 1.25     ## u/s (0.9 hasta la revisión del ritmo)
## Los platos salen por la esquina inferior de pantalla (+X+Z), la mas cercana
## a la tabla del jugador: dos lados desde el inicio del Path3D.
const SPAWN_PROGRESS := BELT_SIDE * 2.0

# --- Actores ---
## Huella (ancho) de la palmera del escenario de isla.
const PALM_FOOT := 3.4

const CHEF_H := 1.75
const STOOL_H := 0.47
const SEAT_ALONG := 0.9       ## separacion de cada taburete del centro del lado
const SEAT_OUT := 2.8         ## distancia del taburete al centro del circuito
## Radio del "pasillo" exterior por el que los clientes rodean el mostrador
## para llegar a su asiento sin pisar taburetes ni atrezzo.
const WALK_R := 3.7
## Entradas/salidas: DOS huecos de embarque. Los clientes de las sillas
## superiores (lados -Z/-X) entran por la borda superior y los de las sillas
## inferiores (+X/+Z) por la inferior — el andar 3D es lento y cruzar todo el
## barco tardaba demasiado. Cada cliente se marcha por donde entro.
const ENTRY := Vector3(-4.2, 0.0, -4.2)
const ENTRY_BOTTOM := Vector3(4.2, 0.0, 4.2)

## Asientos: 2 por lado, como los 8 del juego 2D. "n" = normal exterior.
## Lados en pantalla: -Z arriba-dcha, +X abajo-dcha, +Z abajo-izda, -X arriba-izda.
const SEAT_DEFS := [
	{ "n": Vector3(0, 0, -1), "along": Vector3(1, 0, 0) },
	{ "n": Vector3(1, 0, 0), "along": Vector3(0, 0, 1) },
	{ "n": Vector3(0, 0, 1), "along": Vector3(1, 0, 0) },
	{ "n": Vector3(-1, 0, 0), "along": Vector3(0, 0, 1) },
]

# --- Estado de partida (identico al 2D) ---
var elapsed := 0.0
var money_earned := 0
var clients_spawned := 0
var clients_finished := 0
## Clientes que se han ido DE VACÍO en esta partida: cada uno encarece el
## castigo del siguiente (ver client3d.EMPTY_LEAVE_STEP).
var empty_leavers := 0
## Potenciador "Sobremesa dulce": el próximo postre cobra el doble. Lo consume
## el cliente al cobrarlo (client3d._finish_plate), solo si había multiplicador.
var dessert_boost := false
## Potenciador "Manos libres": mientras corre, CUALQUIER plato se puede coger
## sin soltar el que se está comiendo, como si todos fueran de picoteo.
var snack_all_timer := 0.0
## Potenciador "Nada se tira": los platos no caen al cubo — dan otra vuelta y
## todo el mundo vuelve a tener ocasión de cogerlos (ver _forget_declined).
var no_waste_timer := 0.0
## Potenciador "Doble variedad": los multiplicadores, y su tope, valen el doble.
var variety_x2_timer := 0.0
## Clientes que han llegado al tope base del multiplicador en esta partida, y si
## ha habido dos cajas con la pila llena a la vez. Son las condiciones de los
## bonificadores "Paladar de capitán" y "Barco" (ver PerkData).
var clients_maxed := 0
var boxes_stacked := false
var client_reports: Array = []
var seat_clients: Array = []
var arrival_queue: Array[float] = []
var ended := false
var results_shown := false
## Con el andar lento la salida es larga: los resultados no esperan a que el
## ultimo cliente cruce la borda, solo a verlos levantarse.
var end_grace := 0.0
## Margen que queda tras el ultimo cobro para leer el "+$N" (ver END_PAY_LINGER).
var pay_linger := 0.0
## TUTORIAL: con el reloj retenido `elapsed` no avanza (el guion de David lo
## suelta solo cuando el jugador tiene que jugar de verdad).
var clock_hold := false

var total_clients := TOTAL_CLIENTS
var time_limit := TIME_LIMIT
## ¿Este turno va CONTRA RELOJ? Solo los abordajes (y el modo prueba). En las
## islas y los puertos manda la clientela: no hay cuenta atrás y el HUD ni
## siquiera enseña el reloj (ver CampaignData.is_timed).
var timed := true
## Clientela SIN TOPE: en los abordajes sigue entrando gente mientras quede
## reloj, así que el nivel no puede terminar por haberse ido el último.
var unlimited := false
## Ventana sobre la que se reparten las llegadas. NO es la duración del nivel:
## marca el RITMO al que entra la clientela, también donde no hay reloj.
var arrival_span := ARRIVAL_SPAN
## SIN bote de propinas ni potenciadores de partida (niveles 1-4, la escuela):
## el HUD esconde el bote y las propinas ni se tiran (los clientes salen con
## `tips_enabled` a false, así que tampoco hay "+$N" verde que explicar).
var no_powerups := false
## JEFE del nivel ("" = ninguno). Con jefe, superar el nivel exige cumplir su
## condición (el guion pone `boss_done` al lograrla): sin jefe rendido las
## estrellas se quedan en 1 como mucho, y con él rendido caen al menos las 2
## del aprobado. La 3ª sigue siendo cosa del dinero.
var boss_id := ""
var boss_done := false
## Sin botón de "Salir" (la primera jornada: no hay de qué escaparse todavía).
var no_exit := false
## Sin el aparato de la VARIEDAD en los clientes: ni bocadillo de platos
## comidos ni chapa del "x2". El multiplicador se sigue calculando por dentro,
## solo que no se enseña hasta que David lo explica.
var no_variety_ui := false
## Sin BONIFICADORES permanentes: este puerto no los reparte aunque se cumpla
## su combo (la primera jornada, que todavía no sabe qué son).
var no_perks := false
## La clientela ocupa las sillas por orden de CINTA en vez de al azar (ver
## `_compute_seat_order`). Es de la escuela: con cuatro clientes sueltos, uno
## sentado justo detrás del punto de salida espera una vuelta entera.
var near_seats := false
## Índices de asiento ordenados por cercanía de cinta (se calcula al vuelo).
var seat_order: Array[int] = []
## Clientes por llegada (1 = de uno en uno). Ver el reparto del horario.
var arrival_batch := 1
## Multiplicador del BOCADO de todo el puerto (>1 = mastican más deprisa, así
## que vuelven antes a pedir y hay que cocinar más rápido). Lo usa el nivel 11.
var bite_speed_mult := 1.0
## CLIENTE QUE PAGA CON UN TESORO: {who, type, item, plates}. Uno de ese tipo
## sale con su modelo propio y, si se le sirven `plates` platos, suelta un
## COLECCIONABLE en vez de más oro. Se presenta en el nivel 12.
var collectible_client: Dictionary = {}
## El cliente del tesoro de esta partida (ya sentado), y si ya lo ha pagado.
var treasure_client: Node3D = null
var treasure_given := false
## Segundos entre llegada y llegada (se deduce de arrival_span y la clientela).
var arrival_step := 12.0
var star_money: Array = DEFAULT_STAR_MONEY
var client_weights: Dictionary = {}
var type_queue: Array[String] = []
var forced_types: Array[String] = []

var prep_phase := true
var prep_time_left := 10.0
var frozen := false
var freeze_timer := 0.0

# --- Estado de propinas y potenciadores ---
var tips_total := 0
## El turno se cerró por haber alcanzado el objetivo, no por reloj ni clientes.
var goal_reached := false
## Primas del cierre, calculadas en _finalize_results y mostradas en el desglose.
var bonus_clients := 0
var bonus_time := 0

## Lo que cuesta que un plato dé la vuelta entera sin que nadie lo coja: una
## parte de su precio (el marcador nunca baja de 0).
const WASTE_PENALTY := 0.20
## Prima por cada cliente que se queda SIN VENIR al cerrar antes el turno: los
## clientes gordos valen más porque son los que más se dejan.
const LEFTOVER_BONUS := { "E": 3, "A": 8, "G": 15 }
## Prima por cada bloque completo de 10 s que sobra en el reloj.
const TIME_BONUS := 3
const TIME_BONUS_BLOCK := 10.0
var powerups_claimed := 0
var pending_powerups := 0
var aroma_active := false
var tip_chance_bonus := 0.0
var tip_amount_mult := 1.0
var belt_mult := 1.0
var patience_mult := 1.0
var belt_timer := 0.0
var tip_chance_timer := 0.0
var tip_amount_timer := 0.0

# --- Mundo 3D ---
var cam: Camera3D
## CanvasLayer BAJO el HUD donde los clientes cuelgan sus barras de paciencia
## y textos flotantes (proyectados con la camara, que es fija).
var world_ui: CanvasLayer
var belt_path: Path3D
var band_mat: ShaderMaterial
## Material gemelo para los codos (mismo shader, otras repeticiones).
var corner_mat: ShaderMaterial
var band_tile_len := 1.0
var belt_scroll := 0.0
## Metadatos de cada asiento: pos, yaw, belt_point, ring (punto del pasillo).
var seats: Array = []
var exit_button: Button = null
## Fila de cabezas del HUD: un icono por TIPO de cliente presente en la barra,
## con "xN" si hay varios (ver _update_client_heads).
var heads_row: HBoxContainer = null
## Nodos donde se apilan los platos guardados de cada caja 3D del chef.
var chef_pivot: Node3D
## Ayudante de cocina: solo existe con el potenciador permanente "ayudante".
var helper_pivot: Node3D = null
var helper_anim: CharacterAnim = null
var helper_tween: Tween = null
## Lo que le queda de "amasado" al ayudante tras encargarle un plato; en reposo
## vale 0 y entonces solo respira.
const HELPER_GESTURE_DUR := 1.1
var helper_gesture_t := 0.0
## Platos servidos por el jugador (para el ayudante y para desbloquear perks).
var dishes_served := 0
## Platos que se han ido por la cinta sin que nadie los cogiera (logros).
var plates_wasted := 0
## Segundos de esta partida (van al contador de horas jugadas de GameState).
var play_time := 0.0
## Cara que usa la fila de cabezas del HUD para cada tipo: la del PRIMER cliente
## de ese tipo que ha llegado. tipo -> genero.
var head_gender: Dictionary = {}
## Y el PERSONAJE de cada tipo: normalmente el que le toca por tipo, pero si el
## puerto trae un cliente especial (Pablo el Rubio) la fila enseña SU cara.
var head_who: Dictionary = {}
## Cliente ESPECIAL del puerto (`special_client` en CampaignData): un personaje
## con nombre y modelo propios que sustituye a UNO de los clientes de su tipo.
## De momento solo Pablo el Rubio, en el nivel 5.
var special_who := ""
var special_type := ""
var special_spawned := false
## Platos reservados a un personaje concreto en esta partida (receta → who).
## Ver `exclusive_dishes` del puerto: solo mientras el guion está en marcha.
var exclusive_dishes: Dictionary = {}
var chef_anim: CharacterAnim = null
var chef_tween: Tween = null
var chef_prop: Sprite3D
## Gesto de cocina en curso del chef: se dispara UNO por evento del jugador
## (craft_event), asi que el chef trabaja al ritmo del dedo del usuario.
var chef_gesture := ""
var chef_gesture_t := 0.0
var chef_gesture_dur := 0.4
var chef_gesture_end := 0.4
## Utensilios en la mano derecha (cuchillo/cazo), visibles segun el gesto.
var chef_knife: Node3D = null
var chef_ladle: Node3D = null
var chef_tool_linger := 0.0
var _t := 0.0

@onready var time_label: Label = $HUD/TopRow/TimeBox/TimeLabel
@onready var money_label: Label = $HUD/TopRow/MoneyBox/MoneyRow/MoneyLabel
@onready var clients_label: Label = $HUD/TopRow/ClientsBox/ClientsLabel
@onready var jar_label: Label = $HUD/TopRow/MoneyBox/JarRow/JarLabel
## Relleno que ocupa el hueco del reloj en los niveles que no lo llevan, para
## que el oro siga cayendo en el centro de la pantalla (ver _apply_hud_layout).
var time_gap: Control = null
@onready var phase_label: Label = $HUD/PhaseLabel
@onready var prep_board: Control = $HUD/PrepBoard
@onready var powerup_panel: Panel = $HUD/PowerupPanel
@onready var powerup_options: VBoxContainer = $HUD/PowerupPanel/VBox/Options
@onready var results_panel: Panel = $HUD/ResultsPanel
@onready var stars_label: Label = $HUD/ResultsPanel/VBox/StarsLabel
var stars_row: HBoxContainer = null
## Mientras se enseña el cartel de "¿Comenzamos?", la cuenta atrás no corre.
var awaiting_start := false
## Tablilla de madera con la cuenta atrás: ENTRA por la izquierda y SALE por la
## derecha (no se queda meciéndose en su sitio).
var phase_sign: Control = null
var phase_home_x := 0.0
var phase_shown := false
var phase_tween: Tween = null
## Hoja aparte con el desglose largo del turno, y el botón que la abre.
var detail_panel: Control = null
var detail_button: Button = null
## Las dos barras del marcador: el oro que llevas y el bote de propinas.
var money_bar: ProgressBar = null
var tip_bar: ProgressBar = null
## Cifras del OBJETIVO de cada barra, clavadas a su extremo derecho. Las que
## suben (`money_label` / `jar_label`) viajan con el relleno; ver
## `_place_bar_value`.
var money_meta: Label = null
var tip_meta: Label = null
@onready var score_label: Label = $HUD/ResultsPanel/VBox/ScoreLabel
@onready var earn_label: Label = $HUD/ResultsPanel/VBox/EarnLabel
@onready var breakdown_box: VBoxContainer = $HUD/ResultsPanel/VBox/Scroll/Breakdown
@onready var retry_button: Button = $HUD/ResultsPanel/VBox/BtnBox/RetryButton
@onready var menu_button: Button = $HUD/ResultsPanel/VBox/BtnBox/MenuButton


## Tipo de escenario del nivel: "isla", "puerto" o "abordaje" (barco pirata).
var scenery_kind := "abordaje"


func _ready() -> void:
	# Los menus bajan el tope a la mitad para no gastar bateria; jugando manda
	# el ajuste del usuario (aqui si importa la respuesta al dedo).
	Engine.max_fps = GameState.fps_for(true)
	# Logros de constancia.
	GameState.bump_stat("runs")
	GameState.mark_day_played()
	world_ui = CanvasLayer.new()
	world_ui.layer = 0
	add_child(world_ui)
	# En el export nativo la ventana llega hasta el borde físico: el HUD de
	# arriba se mete debajo del notch si no se aparta (en Safari no pasa).
	var st := GameState.safe_top()
	if st > 0.0:
		for n in [$HUD/TopRow, $HUD/PhaseLabel]:
			n.offset_top += st
			n.offset_bottom += st
	if GameState.is_adventure():
		scenery_kind = CampaignData.get_kind(GameState.current_port)
	_setup_environment()
	_setup_camera()
	_setup_scenery()
	_setup_counter_and_belt()
	_setup_belt_path()
	_setup_seats()
	_setup_chef()
	# Todo el escenario (cubierta, mostrador, taburetes, atrezzo) es geometria
	# de color plano que no se mueve: se funde en UNA malla. Va aqui, cuando ya
	# esta todo colocado, y antes de que aparezca ningun cliente.
	GeometryBatch.bake(self, "SceneryBatch")
	_setup_exit_button()
	_setup_heads_row()

	seat_clients.resize(seats.size())
	prep_board.dish_served.connect(_on_player_dish_served)
	prep_board.craft_event.connect(_on_craft_event)
	prep_board.money_penalty.connect(_on_money_penalty)
	prep_board.storage_changed.connect(_on_storage_changed)
	prep_board.helper_used.connect(helper_cheer)
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	results_panel.visible = false
	powerup_panel.visible = false
	# Los carteles modales van POR ENCIMA de todo el HUD. La fila de cabezas se
	# añade por código y era el último hijo, así que se dibujaba sobre el
	# selector de potenciadores.
	powerup_panel.z_index = 120
	results_panel.z_index = 120
	_skin_panels()
	GameState.reset_run()
	# Configuracion del nivel de campaña (clientes, ritmo, umbrales de dinero).
	var arrival_scale := 1.0
	if GameState.is_adventure():
		var port := CampaignData.get_port(GameState.current_port)
		# El reloj es cosa del TIPO de nivel, no del puerto: solo los abordajes
		# lo llevan, y todos con la misma duración. Lo que sí trae cada puerto es
		# la ventana de llegadas, que es otra cosa (el ritmo de la clientela).
		timed = CampaignData.is_timed(GameState.current_port)
		unlimited = CampaignData.unlimited_clients(GameState.current_port)
		time_limit = CampaignData.time_limit_for(GameState.current_port)
		arrival_span = float(port.get("arrival_span", ARRIVAL_SPAN))
		patience_mult = float(port.get("patience_mult", 1.0))
		arrival_scale = float(port.get("arrival_scale", 1.0))
		star_money = port.get("star_money", DEFAULT_STAR_MONEY)
		client_weights = port.get("client_weights", {})
		# "client_mix" define el recuento EXACTO de cada tipo: cola barajada.
		# En un ABORDAJE esa cola es solo la primera tanda —no hay cupo— y, en
		# cuanto se agota, las llegadas siguen sorteándose con esas mismas
		# proporciones (si el puerto no trae pesos propios).
		var mix: Dictionary = port.get("client_mix", {})
		# Los pesos se rellenan SIEMPRE con la mezcla, no solo en los abordajes:
		# en un nivel de cupo cerrado no deciden las llegadas (para eso está
		# `type_queue`), pero sí de qué tipo es la clientela de regalo del
		# potenciador "Más clientela", que sin esto salía con la mezcla genérica
		# y podía plantar un capitán en un puerto de solo grumetes.
		if client_weights.is_empty():
			client_weights = mix
		if mix.is_empty():
			total_clients = int(port.get("total_clients", TOTAL_CLIENTS))
		else:
			type_queue.clear()
			for t in mix:
				for i in int(mix[t]):
					type_queue.append(t)
			# `client_order` fija el ORDEN EXACTO de llegada en vez de barajar.
			# Lo piden los niveles cuyo guion depende de quién entra cuándo: en
			# el 7 el pirata tiene que ser el TERCERO (para que dé tiempo a
			# darle de comer), y en el 9 cada tanda es de tres grumetes y dos
			# piratas. Barajando, esas dos cosas salían a suertes.
			var orden: Array = port.get("client_order", [])
			if not orden.is_empty():
				type_queue.clear()
				for t in orden:
					type_queue.append(str(t))
			else:
				type_queue.shuffle()
			# `late_type`: ese tipo entra SIEMPRE el último (el pirata del
			# nivel 3, que David presenta al final de la partida).
			var tarde := str(port.get("late_type", ""))
			if tarde != "":
				var resto: Array[String] = []
				var tardios: Array[String] = []
				for t in type_queue:
					if t == tarde:
						tardios.append(t)
					else:
						resto.append(t)
				type_queue = resto
				type_queue.append_array(tardios)
			total_clients = type_queue.size()
		# Cliente con nombre propio de este puerto (Pablo el Rubio en el 5):
		# el primero de su tipo que se siente sale con SU modelo.
		var especial: Dictionary = port.get("special_client", {})
		special_who = str(especial.get("who", ""))
		special_type = str(especial.get("type", ""))
		# La escuela (niveles 1-4): sin bote de propinas ni potenciadores.
		no_powerups = bool(port.get("no_powerups", false))
		# Y en la primera jornada, sin botón de Salir y sin el aparato de la
		# VARIEDAD (bocadillos y chapas): son cosas que aún no se han contado.
		# El botón de Salir se esconde SOLO EN EL ESTRENO del puerto: quien ya lo
		# ha jugado una vez (aunque no lo aprobara) puede irse cuando quiera.
		no_exit = bool(port.get("no_exit", false)) \
				and not GameState.level_stars.has(GameState.current_port)
		no_variety_ui = bool(port.get("no_variety_ui", false))
		no_perks = bool(port.get("no_perks", false))
		# Escuela: la clientela ocupa las sillas por orden de cinta, no al azar.
		near_seats = bool(port.get("near_seats", false))
		# Cuántos entran DE GOLPE en cada llegada (1 = de uno en uno).
		arrival_batch = maxi(int(port.get("arrival_batch", 1)), 1)
		# Cuándo entra el PRIMERO (el nivel 1 lo pone a 0: en cuanto acaba la
		# preparación, sin espera muerta mirando la cinta vacía).
		first_arrival = float(port.get("first_arrival", FIRST_ARRIVAL))
		# BOCADO ACELERADO de todo el puerto (el 11: comen con un hambre que no
		# es normal, así que el hueco entre plato y plato se encoge).
		bite_speed_mult = float(port.get("bite_speed", 1.0))
		# CLIENTE QUE PAGA CON UN TESORO (el 12 en adelante).
		collectible_client = port.get("collectible_client", {})
		# El botón de Salir se monta ANTES de leer el puerto (va con el resto
		# del HUD), así que aquí ya está construido: hay que retirarlo a mano.
		if no_exit and exit_button != null:
			exit_button.queue_free()
			exit_button = null
		# El JEFE del nivel, si lo hay (el Kappa del 10).
		boss_id = str(port.get("boss", ""))
		# Puertos que aún no han presentado extras, combinados ni barco.
		# Los EXTRAS necesitan las DOS llaves: que el puerto los permita y que
		# Saverio ya los haya sacado (nivel 6). Sin la segunda, un puerto
		# posterior repetido los enseñaría antes de que existan.
		prep_board.hide_extras = bool(port.get("no_extras", false)) \
				or not GameState.extras_unlocked()
		# Las cajas de guardado se enseñan en el nivel 2: el 1 va sin ellas.
		prep_board.hide_storage = bool(port.get("no_storage", false))
		# El barco se estrena en el nivel 4 y desde ahí sale siempre; los
		# combinados todavía no se presentan en ningún puerto.
		# El barco pide DOS llaves: que el puerto lo permita (es la novedad del
		# nivel 4 y antes no pinta nada) y que el jugador lleve puesto su
		# bonificador. Si falta cualquiera de las dos, su botón ni aparece.
		prep_board.hide_boat = not (bool(port.get("boat", false)) \
				and GameState.has_perk("barco"))
		prep_board.hide_combo = not bool(port.get("combo", false))
		# Los botones ya se construyeron en el _ready de la tabla, así que hay
		# que repasarlos SIEMPRE: haciéndolo solo cuando se ocultaban los
		# extras, un puerto con extras pero sin barco (el 4) se quedaba con el
		# botón de combinar tal y como lo dejó _ready, o sea visible.
		prep_board.refresh_extra_ui()
		# Puertos NARRADOS: David se asoma en momentos concretos del nivel.
		# El guion solo la PRIMERA vez: repetir un nivel ya superado se juega
		# sin interrupciones.
		var ya_superado: bool = int(GameState.level_stars.get(GameState.current_port, 0)) 				>= int(port.get("goal_stars", 1))
		# Y tampoco si ya se vio en un intento anterior: quedarse corto de
		# estrellas obligaba a tragarse el guion entero otra vez al repetir.
		var ya_narrado: bool = ya_superado \
			or GameState.port_narrated(GameState.current_port)
		# OJO: un nivel con JEFE monta su director SIEMPRE, narrado o no — el
		# director es quien TRAE al jefe y vigila su duelo, y sin él el nivel
		# sería infranqueable al reintentarlo. El propio guion consulta
		# `port_narrated` para callarse los diálogos en las repeticiones.
		if str(port.get("director", "")) != "" \
				and (not ya_narrado or boss_id != ""):
			var guia := preload("res://scripts/level_director.gd").new()
			guia.name = "LevelDirector"
			add_child.call_deferred(guia)
			# Platos que en la PRIMERA pasada solo come el cliente especial:
			# el tsuke don es el regalo de David para Pablo, y servírselo a un
			# grumete le quitaría la gracia a la escena. Al repetir el puerto
			# ya no hay guion y el plato vale para todo el mundo.
			if not ya_narrado:
				exclusive_dishes = port.get("exclusive_dishes", {})
		# Jugar un nivel consume 1 uso de cada ingrediente de las recetas
		# elegidas; si no alcanzan, vuelta a la seleccion.
		if not GameState.consume_ingredients_for_level(GameState.selected_recipes):
			get_tree().change_scene_to_file.call_deferred("res://scenes/prep_screen.tscn")
			return
		# Los potenciadores permanentes elegidos gastan 1 uso por partida (solo
		# en aventura: el modo Arcade no toca el progreso).
		GameState.consume_perks_for_level()
	else:
		GameState.selected_perks = []
	_apply_perks()
	# TUTORIAL: sin horario de llegadas ni fase de preparación — manda el guion
	# de David (tutorial_director), que trae clientes y arranca o para el reloj.
	if GameState.is_tutorial():
		# Objetivo de muestra: se enseña en el marcador, pero el tutorial no
		# termina por dinero (lo cierra su guion).
		star_money = [10]
		# El tutorial no lleva reloj: ni cuenta atrás ni contador en el HUD.
		# Termina cuando lo dice su guion, y punto.
		timed = false
		time_limit = 0.0
		# La intro del CAOS se juega pelada: ni bote, ni cajas, ni extras — solo
		# la tabla, el maki y una barra llena de bocas imposibles de contentar.
		# El repaso de la interfaz hay que pedirlo A MANO: en la rama de
		# aventura lo dispara la lectura del puerto, pero aquí no hay puerto
		# (sin él, las cajas se quedaban dibujadas).
		no_powerups = true
		prep_board.hide_storage = true
		prep_board.refresh_extra_ui()
		total_clients = 1
		prep_phase = false
		_show_phase(false)
		clock_hold = true
		var director := preload("res://scripts/tutorial_director.gd").new()
		director.name = "TutorialDirector"
		add_child(director)
		_apply_hud_layout()
		_mark_star_steps()
		_update_hud()
		return
	# Llegadas escalonadas con azar (ver level.gd 2D para la explicacion). El
	# paso sale de repartir la clientela del puerto por su ventana de llegadas:
	# eso es lo que da el RITMO, y se respeta haya reloj o no.
	var last := (arrival_span - ARRIVAL_TAIL) * arrival_scale
	# Suelo del sorteo: con `first_arrival` a 0 (el nivel 1) un mínimo fijo de
	# 2 s habría devuelto la espera muerta que se quería quitar.
	var pronto := minf(first_arrival, 2.0)
	arrival_step = maxf((last - first_arrival) / float(maxi(total_clients - 1, 1)), 1.5)
	if unlimited:
		# Abordaje: no hay cupo de clientes. Se sigue llamando a gente con ese
		# mismo paso mientras quede reloj para que les dé tiempo a comer algo
		# (nadie entra en los ultimos ARRIVAL_TAIL segundos). Si la barra esta
		# llena las llegadas se acumulan y entran segun se libere un taburete.
		var tope := time_limit - ARRIVAL_TAIL
		var t := first_arrival
		while t <= tope:
			arrival_queue.append(clampf(t + randf_range(-3.0, 3.0) * arrival_scale, pronto, tope))
			t += arrival_step
	elif arrival_batch > 1:
		# LLEGADAS EN TANDAS (el nivel 4 de dos en dos, el 6 de cuatro en
		# cuatro): la ventana se reparte entre TANDAS, no entre clientes, y
		# dentro de una tanda el azar es mínimo para que se lean como un grupo
		# que entra junto. Si no hay sillas libres, el spawner los va soltando
		# según se vacían.
		var tandas: int = maxi(ceili(float(total_clients) / float(arrival_batch)), 1)
		arrival_step = maxf((last - first_arrival) / float(maxi(tandas - 1, 1)), 4.0)
		for i in total_clients:
			var center := first_arrival + float(i / arrival_batch) * arrival_step
			arrival_queue.append(clampf(center + randf_range(-1.0, 1.0), pronto, last))
	else:
		for i in total_clients:
			var center := first_arrival + i * arrival_step
			arrival_queue.append(clampf(center + randf_range(-6.0, 6.0) * arrival_scale, pronto, last))
	arrival_queue.sort()
	_apply_hud_layout()
	_mark_star_steps()
	_update_hud()
	# El nivel NO arranca solo: primero el cartel de "¿Comenzamos?". La bandera
	# se pone AQUÍ y no dentro: entre el _ready y la llamada diferida corrían
	# unos fotogramas de cuenta atrás.
	awaiting_start = true
	_ask_start.call_deferred()


# ------------------------------------------ potenciadores permanentes (perks)

## Aplica los potenciadores elegidos antes de empezar (ver PerkData).
## Cada bonificador aplica el valor de SU NIVEL de mejora (ver PerkData): el
## nivel 1 es el de salida y los cuatro siguientes se compran con doblones.
func _apply_perks() -> void:
	if GameState.has_perk("cocina_veloz"):
		prep_board.cooldown_perm_mult = GameState.perk_value("cocina_veloz") / 100.0
	if GameState.has_perk("ayudante"):
		prep_board.helper_rest = GameState.perk_value("ayudante")
		_setup_helper()


## Avatar del ayudante: solo aparece si se ha activado su potenciador. Va al
## OTRO lado del chef, mirando como él. Ojo con la X: el mostrador de la cinta
## ocupa de -2.35 a -1.25, así que el interior libre del circuito va de -1.25 a
## 1.25 — con x=-1.42 el ayudante salía metido dentro del mostrador.
func _setup_helper() -> void:
	var h_pos := Vector3(0.72, 0.0, -0.60)
	helper_pivot = _spawn_model(
		load(CharacterData.model("ayudante", GameState.helper_gender())),
		h_pos, 1.62, self)
	helper_pivot.rotation_degrees.y = 0.0
	_add_blob_shadow(h_pos + Vector3(0.1, 0.02, 0.1), 1.05, 0.72)
	_box(Vector3(0.72, 0.78, 0.56), h_pos + Vector3(0.0, 0.39, 0.92),
		Color(0.40, 0.27, 0.14))
	var skels := helper_pivot.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		helper_anim = CharacterAnim.new(skels[0])
		if not helper_anim.has_humanoid_bones():
			helper_anim = null


## Combos de la partida que desbloquean potenciadores permanentes. Devuelve
## los ids recién conseguidos, para anunciarlos en los resultados.
func _check_perk_unlocks() -> Array:
	# Los puertos-escuela que aún no han presentado los BONIFICADORES no los
	# reparten: ganar uno sin saber qué es ni de dónde ha salido solo genera
	# preguntas (`no_perks` del puerto; hoy lo lleva el nivel 1).
	if no_perks:
		return []
	# Los potenciadores permanentes están APAGADOS a propósito: se abrirán
	# cuando el diseño de la campaña lo pida (ver PerkData.UNLOCKS_ENABLED).
	if not PerkData.UNLOCKS_ENABLED:
		return []
	# LAS CONDICIONES SON REPETIBLES: `unlock_perk` regala un uso CADA VEZ que se
	# cumplen, y solo devuelve true la primera (que es cuando además se anuncia).
	# Así los usos se ganan jugando, que es de donde salen — la pantalla de
	# Bonificadores vende NIVELES, no usos.
	var newly: Array = []
	var most := 0
	var bien_servidos := 0
	for r in client_reports:
		var n: int = int(r.get("eaten", []).size())
		most = maxi(most, n)
		if n >= PerkData.UNLOCK_HELPER_PLATES:
			bien_servidos += 1
	for c in seat_clients:
		if c is Node3D and is_instance_valid(c) \
				and c.eaten_ids.size() >= PerkData.UNLOCK_HELPER_PLATES:
			bien_servidos += 1
			most = maxi(most, int(c.eaten_ids.size()))
	if most >= PerkData.UNLOCK_PLATES_ONE_CLIENT \
			and GameState.unlock_perk("cocina_veloz"):
		newly.append("cocina_veloz")
	# El AYUDANTE sigue bloqueado hasta el puerto que lo presenta (el 13): sin
	# esa escena, aparecería un muñeco en la cocina sin que nadie lo explique.
	if bien_servidos >= PerkData.UNLOCK_HELPER_CLIENTS \
			and GameState.perk_gate_open("ayudante") \
			and GameState.unlock_perk("ayudante"):
		newly.append("ayudante")
	if clients_maxed >= PerkData.UNLOCK_VARIETY_CLIENTS \
			and GameState.perk_gate_open("paladar") \
			and GameState.unlock_perk("paladar"):
		newly.append("paladar")
	if boxes_stacked and GameState.perk_gate_open("barco") \
			and GameState.unlock_perk("barco"):
		newly.append("barco")
	return newly


## Un cliente ha llegado al tope BASE del multiplicador. Lo cuenta el propio
## cliente (una vez por cliente) y es la condición del bonificador "Paladar de
## capitán". Se mide contra el tope base y no contra el vigente: si contara el
## vigente, llevar ya el bonificador puesto haría casi imposible volver a
## ganarlo, porque habría que llegar a x10.
func note_variety_maxed() -> void:
	clients_maxed += 1


## Cajas con la pila llena a la vez: condición del bonificador "Barco". Lo
## avisa prep_board con cada cambio de almacén, y basta con que haya ocurrido
## UNA vez en la partida.
func _on_storage_changed(slots: Array) -> void:
	if boxes_stacked:
		return
	var llenas := 0
	for s in slots:
		if s != null and int(s.get("count", 0)) >= PerkData.UNLOCK_BOAT_STACK:
			llenas += 1
	if llenas >= PerkData.UNLOCK_BOAT_BOXES:
		boxes_stacked = true


## El ayudante se pone manos a la obra (lo llama prep_board al pulsar su
## boton): da un saltito para que se vea quien ha hecho el plato.
func helper_cheer() -> void:
	if helper_pivot == null:
		return
	helper_gesture_t = HELPER_GESTURE_DUR
	if helper_tween != null:
		helper_tween.kill()
	helper_tween = create_tween()
	helper_tween.tween_property(helper_pivot, "position:y", 0.16, 0.12)
	helper_tween.tween_property(helper_pivot, "position:y", 0.0, 0.16)


# ------------------------------------------------------------------- mundo

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.62, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.80, 0.85, 0.94)
	env.ambient_light_energy = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -125.0, 0.0)
	sun.light_energy = 1.45
	sun.light_color = Color(1.0, 0.97, 0.9)
	# SIN sombras proyectadas: cada elemento lleva su mancha fija (ver
	# SceneBackdrop.blob_shadow). Con personajes que se mecen y palmeras de
	# decenas de piezas, la sombra dinámica bailaba y costaba un pase entero.
	sun.shadow_enabled = false
	add_child(sun)


func _setup_camera() -> void:
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(CAM_PITCH, CAM_YAW, 0.0)
	cam.size = CAM_SIZE
	add_child(cam)
	# basis.z apunta hacia atras de la camara: alejarse del objetivo por ahi.
	cam.position = CAM_TARGET + cam.transform.basis.z * 25.0
	cam.make_current()


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	m.metallic = 0.0
	return m


## Material de madera con textura tileada. Usa mapeo TRIPLANAR (por posicion
## de mundo, no por UV del mesh): las cajas del escenario tienen tamaños muy
## dispares —una cubierta de 24x0.2 y un poste de 0.1x0.9— y con las UV del
## BoxMesh la textura saldria estirada en unas y diminuta en otras. Con
## triplanar todas comparten la MISMA escala de veta.
## `tint` recolorea la misma textura: la cubierta del barco va marron y el
## muelle del puerto gris salino, sin duplicar el asset.
func _wood_mat(tex_path: String, tint: Color, uv_scale := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if ResourceLoader.exists(tex_path):
		m.albedo_texture = load(tex_path)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	m.roughness = 0.95
	m.metallic = 0.0
	return m


## Caja del escenario con material compartido (una sola instancia de material
## para todo un grupo: menos cambios de estado que un material por caja).
func _box_mat(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi


func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _mat(color)
	add_child(mi)
	return mi


# --------------------------------------------------------------- escenarios
## El mostrador con la cinta es el mismo en todos los niveles; lo que cambia
## alrededor es el escenario segun el TIPO del nivel (CampaignData.KINDS):
## una isla, un puerto o el barco pirata (viejo y castigado) del abordaje.

func _setup_scenery() -> void:
	_add_sea()
	match scenery_kind:
		"isla":
			_scenery_island()
		"puerto":
			_scenery_port()
		_:
			_scenery_ship()


## Mar EN MOVIMIENTO alrededor del escenario: el mismo shader de agua del mapa
## de campaña (deriva + dos senos cruzados), asi el nivel no se ve congelado.
func _add_sea() -> void:
	var sea := MeshInstance3D.new()
	var sea_mesh := PlaneMesh.new()
	sea_mesh.size = Vector2(90.0, 90.0)
	sea.mesh = sea_mesh
	sea.position = Vector3(0.0, -0.55, 0.0)
	# Un plano de 90x90 bajo todo lo demas no proyecta ninguna sombra visible,
	# pero se dibujaba entero en el pase de sombras.
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tex_path := "res://assets/map/mar.png"
	if ResourceLoader.exists(tex_path):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/water_map_3d.gdshader")
		mat.set_shader_parameter("sea_tex", load(tex_path))
		mat.set_shader_parameter("tile_scale", Vector2(11.0, 11.0))
		mat.set_shader_parameter("tint", Vector3(0.62, 0.76, 0.95))
		mat.set_shader_parameter("deep_color", Vector3(0.10, 0.26, 0.42))
		mat.set_shader_parameter("flatten", 0.62)
		sea.material_override = mat
	else:
		sea.material_override = _mat(Color(0.22, 0.42, 0.55))
	add_child(sea)


## Mancha de sombra fija en el suelo, bajo un objeto del escenario.
func _add_blob_shadow(pos: Vector3, size_x: float, size_z: float) -> MeshInstance3D:
	var mi := SceneBackdrop.blob_shadow(size_x, size_z)
	mi.position = pos
	add_child(mi)
	return mi


func _cyl(top_r: float, bottom_r: float, h: float, pos: Vector3,
		color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = h
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _mat(color)
	add_child(mi)
	return mi


func _spawn_barrels(spots: Array, tipped_idx: int = -1) -> void:
	var barrel_path := "res://assets/models/barril.glb"
	if not ResourceLoader.exists(barrel_path):
		return
	var barrel: PackedScene = load(barrel_path)
	for i in spots.size():
		var b := _spawn_model(barrel, spots[i], 0.95, self)
		if i == tipped_idx:
			b.rotation_degrees = Vector3(90.0, 25.0, 0.0)
			b.position.y = 0.33


## ISLA: arenal rodeado de mar, palmeras, rocas y algo de carga varada.
func _scenery_island() -> void:
	# Dos discos de arena (el de abajo mas oscuro hace de orilla mojada). Radio
	# contenido para que el MAR asome por los bordes de la pantalla.
	# La arena va MATE y en tono tostado: en blanco crudo deslumbraba y se
	# comia el contraste de los personajes y los platos.
	_cyl(7.4, 7.8, 0.30, Vector3(0.0, -0.42, 0.0), Color(0.52, 0.44, 0.30))
	var sand := _cyl(6.9, 7.3, 0.28, Vector3(0.0, -0.14, 0.0),
		Color(0.63, 0.55, 0.39))
	sand.material_override.roughness = 1.0
	sand.material_override.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# Palmeras fuera del pasillo de los clientes (radio 3.7, bordas en ±4.2)
	# pero DENTRO del encuadre (la pantalla es estrecha a los lados).
	_palm(Vector3(-5.2, 0.0, -2.4), 0.0)
	_palm(Vector3(1.2, 0.0, -5.2), 140.0)
	# Esta se aparto hacia +X: en su sitio anterior la copa caia justo encima
	# de los taburetes de ese lado y tapaba al cliente sentado alli.
	_palm(Vector3(5.2, 0.0, -2.0), 250.0)
	_palm(Vector3(-1.4, 0.0, 5.1), 60.0)
	# Cabaña de playa en la zona alta: de ahi bajan los clientes de esa borda
	# (antes aparecian de la nada al borde del arenal).
	_beach_hut(Vector3(-5.2, 0.0, -5.2))
	# Rocas: MODELO con su textura (antes eran cajas grises sin más).
	# La de la izquierda iba a 1.7 y se comia parte del pasillo de paso: los
	# clientes la ATRAVESABAN al rodear el mostrador. Reducida y apartada.
	for r in [[Vector3(-5.4, 0.0, 0.4), 1.0], [Vector3(0.8, 0.0, -5.6), 1.35],
			[Vector3(4.6, 0.0, -0.6), 1.0]]:
		var rocks := _spawn_model(load("res://assets/models/rocas.glb"),
			r[0], float(r[1]), self)
		rocks.rotation_degrees.y = r[0].x * 37.0
		_add_blob_shadow(r[0] + Vector3(0.2, 0.02, 0.12),
			float(r[1]) * 1.15, float(r[1]) * 0.75)
	# (Aqui habia una caja en (-5.4,-2.2): caia dentro del tronco de la palmera
	# de arriba-izquierda y se veian atravesados. Se quita en vez de moverla:
	# el arenal ya tiene barriles y rocas de sobra.)
	_spawn_barrels([Vector3(-6.0, 0.0, -1.0), Vector3(5.0, 0.0, 3.2)], 1)


## Cabaña de playa: MODELO 3D con su textura. Es el punto del que "vienen" los
## clientes de la borda alta de la isla. Antes se montaba con cajas y faldones
## de techo, y al lado de las palmeras y las rocas con textura desentonaba.
func _beach_hut(pos: Vector3) -> void:
	var hut := _spawn_model(load("res://assets/models/cabana.glb"), pos, 3.6, self)
	hut.rotation_degrees.y = 45.0
	_add_blob_shadow(pos + Vector3(0.35, 0.02, 0.25), 4.0, 2.6)
## Palmera low poly: tronco inclinado + corona de hojas + cocos.
## Palmera: MODELO 3D (Ludo), no geometría por código. Se intentó montarla con
## cilindros y tablillas —tronco curvo y frondas articuladas— y desde la cámara
## isométrica siempre se leía como una estrella plana con las hojas de punta,
## por muy arqueadas que estuvieran. El modelo trae la copa cerrada, los cocos
## y el anillado del tronco de una pieza.
func _palm(pos: Vector3, yaw: float) -> void:
	var pivot := _spawn_model(load("res://assets/models/palmera.glb"),
		pos, PALM_FOOT, self)
	pivot.rotation_degrees.y = yaw
	# Cada una con su porte: si todas miden igual cantan como copias.
	var s := randf_range(0.88, 1.12)
	pivot.scale = Vector3.ONE * s
	# Mancha de sombra fija en la base (el juego no usa sombras proyectadas).
	_add_blob_shadow(pos + Vector3(0.4 * s, 0.02, 0.25 * s), 2.6 * s, 1.7 * s)


## PUERTO: muelle de tablones grises sobre el mar, norays, farol y mercancia.
func _scenery_port() -> void:
	# Madera de muelle: gris azulado de la mar, NO el marron calido del barco
	# (el usuario los veia iguales y el puerto no se distinguia).
	var dock_mat := _wood_mat(DOCK_TEX, Color(0.74, 0.78, 0.80), 0.15)
	var post_mat := _wood_mat(DOCK_TEX, Color(0.48, 0.50, 0.52), 0.9)
	var crate_mat := _wood_mat(CRATE_TEX, Color(0.92, 0.86, 0.74), 1.4)
	# Tarima GIRADA 45 y recortada, no un cuadrado que llenaba la pantalla:
	# cubre de sobra el anillo de paso y las dos bordas de entrada, pero deja
	# ver el MAR por encima del muelle.
	var deck := _box_mat(Vector3(14.0, 0.22, 13.2), Vector3(0.0, -0.11, 0.0), dock_mat)
	deck.rotation_degrees.y = 45.0
	# Canto del muelle: la tarima tiene grosor y se apoya sobre el agua.
	var edge := _box_mat(Vector3(13.4, 0.55, 12.6), Vector3(0.0, -0.42, 0.0), post_mat)
	edge.rotation_degrees.y = 45.0
	# PUENTE en la zona alta: por ahi llegan los clientes de esa borda, cruzando
	# desde tierra firme. Sustituye al cobertizo, que tapaba mas de lo que
	# contaba y se le comia la barra del HUD.
	_port_bridge(ENTRY, dock_mat, post_mat)
	# Valla corrida por toda la borda alta para que nadie se caiga al agua, con
	# el hueco justo del puente.
	_port_railing(ENTRY, -7.0, -1.3, post_mat)
	_port_railing(ENTRY, 1.3, 7.0, post_mat)
	# Pilotes del muelle asomando por los bordes.
	for p in [Vector3(-7.4, 0.0, -3.4), Vector3(-3.6, 0.0, -7.6),
			Vector3(7.4, 0.0, 3.0), Vector3(3.0, 0.0, 7.6),
			Vector3(-7.6, 0.0, 3.8), Vector3(6.4, 0.0, -6.2)]:
		_cyl(0.16, 0.18, 1.15, p + Vector3(0.0, 0.45, 0.0), Color(0.35, 0.26, 0.15))
		var knob := _cyl(0.20, 0.22, 0.14, p + Vector3(0.0, 1.08, 0.0),
			Color(0.30, 0.22, 0.13))
		knob.rotation_degrees.y = p.x * 20.0
	# Norays de amarre con su cabo enrollado.
	for b in [Vector3(-2.2, 0.0, 6.6), Vector3(5.6, 0.0, -2.0)]:
		_cyl(0.17, 0.21, 0.5, b + Vector3(0.0, 0.25, 0.0), Color(0.22, 0.20, 0.19))
		_cyl(0.26, 0.26, 0.09, b + Vector3(0.0, 0.16, 0.0), Color(0.52, 0.42, 0.26))
	# Farol de muelle: poste alto con caja de luz calida.
	_cyl(0.07, 0.09, 2.6, Vector3(-3.4, 1.3, -4.9), Color(0.25, 0.20, 0.14))
	var lamp := _box(Vector3(0.30, 0.34, 0.30), Vector3(-3.4, 2.72, -4.9),
		Color(1.0, 0.85, 0.45))
	lamp.material_override.emission_enabled = true
	lamp.material_override.emission = Color(1.0, 0.8, 0.35)
	lamp.material_override.emission_energy_multiplier = 0.7
	# Carga APILADA (un puerto no deja las cajas sueltas) pero repartida por
	# todo el muelle: dos montones grandes, dos pequeños y barriles arrimados
	# en otros rincones. Todo fuera del anillo de paso de los clientes.
	_cargo_pile(Vector3(-5.5, 0.0, -3.0), crate_mat, true)
	_cargo_pile(Vector3(5.4, 0.0, 2.4), crate_mat, true)
	_cargo_pile(Vector3(-4.7, 0.0, 1.4), crate_mat, false)
	_cargo_pile(Vector3(1.0, 0.0, -5.4), crate_mat, false)
	_spawn_barrels([Vector3(-1.9, 0.0, 4.7), Vector3(-2.4, 0.0, 5.3)])
	_spawn_barrels([Vector3(4.6, 0.0, -1.4)], 0)


## Monton de carga: cajas apiladas y, si es grande, barriles arrimados.
func _cargo_pile(pos: Vector3, crate_mat: Material, big: bool = true) -> void:
	var crate := "res://assets/models/caja.glb"
	if ResourceLoader.exists(crate):
		var scene: PackedScene = load(crate)
		# Base de dos y una encima, algo giradas para que no parezca un molde.
		_tint_model(_spawn_model(scene, pos + Vector3(-0.34, 0.0, 0.0), 0.66, self),
			CRATE_TINT)
		if big:
			_tint_model(_spawn_model(scene, pos + Vector3(0.34, 0.0, 0.10), 0.66, self),
				CRATE_TINT)
			var top := _spawn_model(scene, pos + Vector3(-0.02, 0.66, 0.04), 0.56, self)
			top.rotation_degrees.y = 22.0
			_tint_model(top, CRATE_TINT)
		else:
			var lean := _spawn_model(scene, pos + Vector3(0.42, 0.0, 0.18), 0.52, self)
			lean.rotation_degrees.y = -28.0
			_tint_model(lean, CRATE_TINT)
	else:
		_box_mat(Vector3(0.66, 0.66, 0.66), pos + Vector3(-0.34, 0.33, 0.0), crate_mat)
	if big:
		_spawn_barrels([pos + Vector3(0.95, 0.0, -0.55), pos + Vector3(1.15, 0.0, 0.25)])


## Puente de madera por el que se entra al muelle desde tierra: dos largueros,
## tablero y barandillas a los lados. Se aleja del centro siguiendo la borda.
func _port_bridge(base: Vector3, deck_mat: Material, post_mat: Material) -> void:
	# RECTO hacia fuera, perpendicular a la borda. Se probo sesgado para que no
	# quedara detras del marcador del HUD y salio TORCIDO: los tablones seguian
	# alineados a la diagonal del muelle (yaw 45) mientras el puente corria en
	# otra direccion, asi que la madera cruzaba el puente en diagonal. Ahora la
	# orientacion se DEDUCE de la direccion, y no puede volver a descuadrarse.
	var out := base.normalized()
	var lateral := Vector3(out.z, 0.0, -out.x)
	# Los tablones van perpendiculares a la marcha: su eje largo es "lateral".
	var yaw := rad_to_deg(atan2(lateral.x, lateral.z)) + 90.0
	# Corto a proposito: mas largo se metia bajo la barra superior del HUD.
	# El tablero va en madera OSCURA (la del poste), no en la clara del muelle:
	# del mismo tono se fundia con la tarima y el puente no se distinguia.
	for i in 4:
		var step := _box_mat(Vector3(2.3, 0.16, 0.58),
			base + out * (0.45 + i * 0.56) + Vector3(0.0, 0.12 + i * 0.05, 0.0),
			post_mat)
		step.rotation_degrees.y = yaw
	# Pilotes que bajan al agua bajo el tablero: sin ellos el puente parecia
	# flotar sobre el mar.
	for side in [-1.0, 1.0]:
		for i in 2:
			_cyl(0.11, 0.13, 1.5,
				base + out * (0.8 + i * 1.1) + lateral * side * 0.95
				+ Vector3(0.0, -0.55, 0.0), Color(0.34, 0.30, 0.26))
	# Barandillas a ambos lados, con sus postes y el pasamanos en la pendiente.
	for side in [-1.0, 1.0]:
		for i in 3:
			_box_mat(Vector3(0.11, 0.66, 0.11),
				base + out * (0.6 + i * 0.78) + lateral * side * 1.05
				+ Vector3(0.0, 0.36 + i * 0.04, 0.0), post_mat)
		var rail := _box_mat(Vector3(0.10, 0.10, 2.3),
			base + out * 1.4 + lateral * side * 1.05 + Vector3(0.0, 0.72, 0.0),
			post_mat)
		rail.rotation_degrees.y = yaw + 90.0


## Valla de puerto: postes gruesos y dos travesaños, sobre la diagonal de la
## borda, del parametro t0 al t1.
func _port_railing(base: Vector3, t0: float, t1: float, mat: Material) -> void:
	var dir := Vector3(1.0, 0.0, -1.0) / sqrt(2.0)
	var length := t1 - t0
	var posts := int(round(length / 1.15))
	for i in range(posts + 1):
		var p := base + dir * (t0 + length * float(i) / float(posts))
		_box_mat(Vector3(0.13, 0.95, 0.13), p + Vector3(0.0, 0.48, 0.0), mat)
	var mid := base + dir * ((t0 + t1) * 0.5)
	for y in [0.88, 0.52]:
		var rail := _box_mat(Vector3(length + 0.1, 0.10, 0.14),
			mid + Vector3(0.0, y, 0.0), mat)
		rail.rotation_degrees.y = 45.0


## Cobertizo del muelle con su porton: sirve de "de donde vienen" los clientes
## de la borda alta y de tope visual para que el muelle no acabe en el vacio.
func _port_warehouse(pos: Vector3, wall_mat: Material, trim_mat: Material) -> void:
	var body := _box_mat(Vector3(4.6, 2.5, 3.0), pos + Vector3(0.0, 1.25, 0.0), wall_mat)
	body.rotation_degrees.y = 45.0
	# Tejado a dos aguas, en dos planos inclinados.
	for side in [-1.0, 1.0]:
		var roof := _box_mat(Vector3(4.9, 0.16, 1.85),
			pos + Vector3(0.0, 2.72, 0.0)
			+ (Vector3(1.0, 0.0, 1.0) / sqrt(2.0)) * side * 0.78, trim_mat)
		roof.rotation_degrees = Vector3(0.0, 45.0, 0.0)
		roof.rotate_object_local(Vector3.RIGHT, deg_to_rad(-side * 22.0))
	# Porton oscuro mirando al circuito (hacia el centro).
	var inward := -pos.normalized()
	var door := _box(Vector3(1.5, 1.8, 0.12), pos + inward * 1.55 + Vector3(0.0, 0.9, 0.0),
		Color(0.24, 0.17, 0.10))
	door.rotation_degrees.y = 45.0


## ABORDAJE: el barco pirata de siempre, pero viejo y castigado — tablones
## descoloridos y arrancados (se ve el mar), barandilla rota, manchas,
## restos de carga y velas rasgadas en el mastil central.
func _scenery_ship() -> void:
	var deck_mat := _wood_mat(DECK_TEX, Color(0.72, 0.56, 0.38), 0.17)
	var trim_mat := _wood_mat(DECK_TEX, Color(0.58, 0.42, 0.26), 0.7)
	var crate_mat := _wood_mat(CRATE_TEX, Color(0.90, 0.82, 0.70), 1.4)

	# Cubierta: UNA losa con la textura de tablones desgastados en vez de 38
	# cajas de color plano. Antes tres tablones "arrancados" cruzaban la
	# cubierta de lado a lado y dejaban el mar asomando justo bajo un
	# taburete (la silla parecia flotar); ahora los desperfectos son locales
	# y estan SIEMPRE fuera del anillo por el que andan los clientes.
	#
	# Va GIRADA 45 y recortada por la proa: asi es un BARCO con eslora y manga
	# —el costado y el mar asoman por encima de la borda alta— en vez de una
	# habitacion de madera que llenaba la pantalla de lado a lado.
	var deck := _box_mat(Vector3(14.0, 0.22, 13.2), Vector3(0.0, -0.11, 0.0), deck_mat)
	deck.rotation_degrees.y = 45.0
	# Costado del casco bajo la cubierta: se hunde por debajo del nivel del mar
	# (y=-0.55), asi el barco flota en vez de posarse sobre el agua.
	var hull := _box_mat(Vector3(13.4, 1.10, 12.6), Vector3(0.0, -0.75, 0.0),
		_wood_mat(DECK_TEX, Color(0.42, 0.30, 0.19), 0.17))
	hull.rotation_degrees.y = 45.0
	# Boquete real en la cubierta, en una esquina alejada del juego: se ve el
	# mar por el hueco y quedan dos tablas partidas asomando.
	_hull_hole(Vector3(-7.4, 0.0, 5.6), 1.5)
	_hull_hole(Vector3(6.8, 0.0, -6.4), 1.1)
	# Manchas oscuras de humedad/polvora.
	for m in [[Vector3(-3.4, 0.0, -4.6), 1.5], [Vector3(4.6, 0.0, 3.2), 1.1],
			[Vector3(-4.8, 0.0, 4.6), 0.9]]:
		var stain := _box(Vector3(m[1], 0.012, m[1] * 0.7),
			m[0] + Vector3(0.0, 0.012, 0.0), Color(0.26, 0.19, 0.12))
		stain.rotation_degrees.y = m[0].z * 31.0
	# Bordas: sobre la linea de barandilla va una regala de madera, para que el
	# barco tenga costado y no parezca una balsa plana.
	for base in [ENTRY, ENTRY_BOTTOM]:
		var gunwale := _box_mat(Vector3(17.0, 0.30, 0.26),
			base + Vector3(0.0, 0.15, 0.0), trim_mat)
		gunwale.rotation_degrees.y = 45.0
	# Barandillas rotas en ambas bordas, con huecos de embarque.
	_railing_diag(ENTRY, -6.5, -0.8, true)
	_railing_diag(ENTRY, 0.8, 7.5, true)
	_railing_diag(ENTRY_BOTTOM, -7.5, -0.8, true)
	_railing_diag(ENTRY_BOTTOM, 0.8, 6.5, true)
	# Escalera de toldilla en el hueco de embarque de ARRIBA: de ahi suben los
	# clientes de esa borda, en vez de materializarse en mitad de la cubierta.
	_deck_stairs(ENTRY, trim_mat)
	# Mastil TRONCHADO, sin velas y a media altura. Un palo entero (o incluso
	# uno roto de 3 m con la vela colgando) se iba por el borde superior de la
	# pantalla y chocaba con el HUD; el tocon astillado cabe de sobra, no tapa
	# nada y cuenta lo mismo: a este barco lo han abordado.
	_broken_mast(Vector3(-1.4, 0.0, -5.4))
	# Cañones asomando por la borda alta: identidad de barco a ras de cubierta,
	# que es la unica altura libre en un encuadre tan bajo.
	for t in [-3.4, 2.9]:
		_deck_cannon(ENTRY + Vector3(1.0, 0.0, -1.0) / sqrt(2.0) * t)
	# Carga y destrozos: cajas junto a cada embarque, caja rota y barriles.
	# Cajas de verdad (modelo con listones y refuerzos): antes eran cubos de
	# madera lisos que se leian como bloques sueltos.
	var crate_scene: PackedScene = load("res://assets/models/caja.glb")
	_tint_model(_spawn_model(crate_scene, Vector3(-5.3, 0.0, -2.5), 0.72, self),
		CRATE_TINT)
	var stacked := _spawn_model(crate_scene, Vector3(-5.15, 0.72, -2.4), 0.58, self)
	stacked.rotation_degrees.y = 18.0
	_tint_model(stacked, CRATE_TINT)
	var side_crate := _spawn_model(crate_scene, Vector3(5.4, 0.0, 2.3), 0.62, self)
	side_crate.rotation_degrees.y = -25.0
	_tint_model(side_crate, CRATE_TINT)
	# El botin del abordaje: un cofre junto a la carga.
	var chest := _spawn_model(load("res://assets/models/cofre.glb"),
		Vector3(-6.1, 0.0, -1.35), 0.58, self)
	chest.rotation_degrees.y = 28.0
	var broken_a := _box_mat(Vector3(0.6, 0.1, 0.5), Vector3(2.4, 0.05, 6.1), crate_mat)
	broken_a.rotation_degrees.y = 24.0
	var broken_b := _box_mat(Vector3(0.5, 0.4, 0.09), Vector3(2.75, 0.2, 6.35), crate_mat)
	broken_b.rotation_degrees = Vector3(0.0, -18.0, 74.0)
	# Barriles apartados de la linea de barandilla (uno la atravesaba).
	_spawn_barrels([Vector3(-6.6, 0.0, -0.4), Vector3(5.9, 0.0, -1.0)], 1)


## Boquete en la cubierta: agujero oscuro con el mar al fondo y un par de
## tablas partidas en el borde. Se usa lejos del anillo de paso.
func _hull_hole(pos: Vector3, size: float) -> void:
	var hole := _box(Vector3(size, 0.03, size * 0.8), pos + Vector3(0.0, 0.005, 0.0),
		Color(0.05, 0.12, 0.18))
	hole.rotation_degrees.y = pos.x * 23.0
	for s in [[-0.5, 0.42, 18.0], [0.44, -0.3, -26.0]]:
		var splinter := _box(Vector3(size * 0.5, 0.07, 0.14),
			pos + Vector3(s[0] * size, 0.05, s[1] * size), Color(0.40, 0.28, 0.16))
		splinter.rotation_degrees = Vector3(0.0, s[2], 12.0)


## Escalera de subida a cubierta en el hueco de embarque: cuatro peldaños que
## bajan hacia el costado, para que los clientes lleguen "desde el barco" y no
## aparezcan de la nada. Se alinea con la diagonal de la borda.
func _deck_stairs(base: Vector3, mat: Material) -> void:
	# Los peldaños SUBEN hacia fuera hasta un rellano: bajando por el costado
	# quedaban tapados por la regala y no se veia nada. Subiendo, el rellano
	# asoma por encima de la borda y se lee de donde baja el cliente.
	var out := base.normalized()
	for i in 4:
		var step := _box_mat(Vector3(1.7, 0.16, 0.36),
			base + out * (0.36 + i * 0.36) + Vector3(0.0, 0.08 + i * 0.16, 0.0), mat)
		step.rotation_degrees.y = 45.0
	var landing := _box_mat(Vector3(2.4, 0.18, 1.5),
		base + out * 2.55 + Vector3(0.0, 0.72, 0.0), mat)
	landing.rotation_degrees.y = 45.0
	# Barandal a los lados de la escalera, siguiendo la pendiente.
	for side in [-1.0, 1.0]:
		var lateral: Vector3 = Vector3(out.z, 0.0, -out.x) * side * 0.85
		var rail := _box_mat(Vector3(0.10, 0.10, 2.0),
			base + lateral + out * 1.1 + Vector3(0.0, 0.72, 0.0), mat)
		rail.rotation_degrees = Vector3(0.0, 45.0, 0.0)
		rail.rotate_object_local(Vector3.RIGHT, deg_to_rad(-22.0))
		for k in 2:
			_box_mat(Vector3(0.09, 0.55, 0.09),
				base + lateral + out * (0.5 + k * 1.3)
				+ Vector3(0.0, 0.28 + k * 0.30, 0.0), mat)


## Tocon de mastil tronchado, con la base y un rollo de cabo alrededor. Sin
## verga ni velas: ver _scenery_ship para por que se quitaron.
func _broken_mast(pos: Vector3) -> void:
	var h := 1.55
	_cyl(0.20, 0.24, h, pos + Vector3(0.0, h * 0.5, 0.0), Color(0.36, 0.24, 0.13))
	_cyl(0.34, 0.37, 0.20, pos + Vector3(0.0, 0.10, 0.0), Color(0.55, 0.45, 0.31))
	# Astillas del tronchazo, arriba del todo.
	for s in [[-0.10, 0.26, 14.0], [0.11, 0.36, -18.0], [0.02, 0.18, 6.0]]:
		var chip := _box(Vector3(0.11, s[1], 0.11),
			pos + Vector3(s[0], h + s[1] * 0.42, s[0] * 0.7), Color(0.44, 0.31, 0.17))
		chip.rotation_degrees.z = s[2]
	# Cabo enrollado en la base.
	_cyl(0.44, 0.44, 0.09, pos + Vector3(0.0, 0.24, 0.0), Color(0.62, 0.52, 0.34))


## Cañon de cubierta apuntando a la borda, sobre su cureña de madera.
func _deck_cannon(pos: Vector3) -> void:
	var out := pos.normalized()
	var yaw := rad_to_deg(atan2(out.x, out.z))
	var carriage := _box_mat(Vector3(0.46, 0.20, 0.62), pos + Vector3(0.0, 0.10, 0.0),
		_wood_mat(CRATE_TEX, Color(0.62, 0.50, 0.36), 1.6))
	carriage.rotation_degrees.y = yaw
	var barrel := _cyl(0.09, 0.13, 0.86, pos + Vector3(0.0, 0.30, 0.0) + out * 0.14,
		Color(0.17, 0.17, 0.19))
	barrel.rotation_degrees = Vector3(0.0, yaw, 0.0)
	barrel.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
	for side in [-1.0, 1.0]:
		var lateral: Vector3 = Vector3(out.z, 0.0, -out.x) * side * 0.20
		_cyl(0.10, 0.10, 0.06, pos + lateral + Vector3(0.0, 0.07, 0.0),
			Color(0.30, 0.21, 0.12)).rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))


## Tramo de barandilla sobre la diagonal p(t) = base + t*(1,0,-1)/v2 (la
## eslora a lo ancho de la vista), del parametro t0 a t1. En el barco del
## abordaje ("worn") faltan postes, otros estan torcidos y el liston va roto.
func _railing_diag(base: Vector3, t0: float, t1: float, worn: bool = false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(base.x * 13.0 + t0 * 7.0)
	var dir := Vector3(1.0, 0.0, -1.0) / sqrt(2.0)
	var length := t1 - t0
	var posts := int(round(length / 1.1))
	for i in range(posts + 1):
		if worn and rng.randf() < 0.22:
			continue
		var p := base + dir * (t0 + length * float(i) / float(posts))
		var post := _box(Vector3(0.10, 0.88, 0.10), p + Vector3(0.0, 0.44, 0.0),
			Color(0.38, 0.26, 0.14))
		if worn and rng.randf() < 0.3:
			post.rotation_degrees.z = rng.randf_range(-14.0, 14.0)
	var rails := [[0.88, 0.09, 0.13], [0.48, 0.07, 0.10]]
	for rail in rails:
		if worn and rail[0] < 0.5 and length > 4.0:
			# El liston bajo va partido: dos trozos con un hueco en medio.
			_rail_piece(base, t0, t0 + length * 0.42, rail, -3.0)
			_rail_piece(base, t0 + length * 0.58, t1, rail, 2.0)
		else:
			_rail_piece(base, t0, t1, rail, 0.0)


func _rail_piece(base: Vector3, t0: float, t1: float, rail: Array,
		tilt: float) -> void:
	var dir := Vector3(1.0, 0.0, -1.0) / sqrt(2.0)
	var mid := base + dir * ((t0 + t1) * 0.5)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(t1 - t0 + 0.1, rail[1], rail[2])
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = mid + Vector3(0.0, rail[0], 0.0)
	mi.rotation_degrees.y = 45.0
	mi.rotation_degrees.z = tilt
	mi.material_override = _mat(Color(0.46, 0.32, 0.17))
	add_child(mi)


## Mostrador de madera + banda MOVIL encima + placa metalica en cada esquina
## (el codo por donde los platos doblan). La banda avanza empujando el uniform
## "scroll_tiles" desde _process, para poder pararla al congelar y acelerarla
## con "Cinta rapida".
func _setup_counter_and_belt() -> void:
	var h := BELT_SIDE * 0.5
	# Los tramos rectos dejan libre justo el ANCHO de la banda en cada esquina:
	# ese hueco lo cubre otro trozo de banda, no una placa. Asi el codo tiene la
	# misma pinta y el mismo movimiento que el resto de la cinta.
	var seg := BELT_SIDE - BELT_W

	var band_tex: Texture2D = load("res://assets/props/cinta_trad_banda.png")
	band_tile_len = BELT_W * float(band_tex.get_width()) / float(band_tex.get_height())
	band_mat = ShaderMaterial.new()
	band_mat.shader = load("res://shaders/belt_scroll_3d.gdshader")
	band_mat.set_shader_parameter("band_tex", band_tex)
	band_mat.set_shader_parameter("repeat_x", seg / band_tile_len)
	band_mat.set_shader_parameter("scroll_tiles", 0.0)
	# Las esquinas son cuadradas: mismo shader, pero con las repeticiones que
	# les tocan por su lado.
	corner_mat = ShaderMaterial.new()
	corner_mat.shader = band_mat.shader
	corner_mat.set_shader_parameter("band_tex", band_tex)
	corner_mat.set_shader_parameter("repeat_x", BELT_W / band_tile_len)
	corner_mat.set_shader_parameter("scroll_tiles", 0.0)

	var sides := [
		[Vector3(0, 0, -h), 0.0, true],
		[Vector3(h, 0, 0), -90.0, false],
		[Vector3(0, 0, h), 180.0, true],
		[Vector3(-h, 0, 0), 90.0, false],
	]
	for s in sides:
		var center: Vector3 = s[0]
		var c_size := Vector3(BELT_SIDE + COUNTER_W, BELT_TOP, COUNTER_W) \
			if s[2] else Vector3(COUNTER_W, BELT_TOP, BELT_SIDE + COUNTER_W)
		_box(c_size, center + Vector3(0.0, BELT_TOP * 0.5, 0.0),
			Color(0.48, 0.33, 0.18))
		var b_size := Vector3(seg, 0.04, BELT_W) if s[2] \
			else Vector3(BELT_W, 0.04, seg)
		_box(b_size, center + Vector3(0.0, BELT_TOP + 0.02, 0.0),
			Color(0.13, 0.14, 0.16))
		var plane := PlaneMesh.new()
		plane.size = Vector2(seg, BELT_W)
		var mi := MeshInstance3D.new()
		mi.mesh = plane
		mi.material_override = band_mat
		mi.position = center + Vector3(0.0, BELT_TOP + 0.045, 0.0)
		mi.rotation_degrees.y = s[1]
		add_child(mi)

	# El conjunto del mostrador apoya en su propia mancha (sin sombras
	# proyectadas, si no, el circuito parecía flotar sobre la cubierta).
	_add_blob_shadow(Vector3(0.25, 0.03, 0.3), BELT_SIDE + 2.4, BELT_SIDE + 2.4)

	# El codo por donde el plato dobla: un cuadrado de la MISMA banda, con su
	# mismo canto oscuro debajo. Antes era una placa de acero quieta y cortaba
	# el movimiento de la cinta en seco cuatro veces por vuelta.
	for corner in [Vector3(h, 0, h), Vector3(h, 0, -h),
			Vector3(-h, 0, h), Vector3(-h, 0, -h)]:
		_box(Vector3(BELT_W, 0.04, BELT_W),
			corner + Vector3(0.0, BELT_TOP + 0.02, 0.0), Color(0.13, 0.14, 0.16))
		var plane := PlaneMesh.new()
		plane.size = Vector2(BELT_W, BELT_W)
		var mi := MeshInstance3D.new()
		mi.mesh = plane
		mi.material_override = corner_mat
		mi.position = corner + Vector3(0.0, BELT_TOP + 0.045, 0.0)
		# Cada codo sigue la direccion del tramo que llega a el, para que los
		# listones entren y salgan alineados.
		mi.rotation_degrees.y = 0.0 if corner.z < 0.0 else 180.0
		add_child(mi)


## Path3D cuadrado sobre la banda; los platos (plate3d.gd) son PathFollow3D.
func _setup_belt_path() -> void:
	var h := BELT_SIDE * 0.5
	var y := BELT_TOP + 0.05
	var curve := Curve3D.new()
	for p in [Vector3(-h, y, -h), Vector3(h, y, -h), Vector3(h, y, h),
			Vector3(-h, y, h), Vector3(-h, y, -h)]:
		curve.add_point(p)
	belt_path = Path3D.new()
	belt_path.curve = curve
	add_child(belt_path)
	_add_trash_bin(h)


## Cubo de basura en la esquina INFERIOR del circuito (+X/+Z, la más baja en
## pantalla). Es justo donde nacen los platos y, con una sola vuelta de cinta,
## también donde vuelven a pasar si nadie los ha cogido: ahí caen.
func _add_trash_bin(h: float) -> void:
	var c := Vector3(h + 0.62, 0.0, h + 0.62)
	var duela := Color(0.46, 0.33, 0.19)
	var aro := Color(0.32, 0.34, 0.38)
	# Cuerpo troncocónico, más ancho arriba.
	_cyl(0.46, 0.35, 0.80, c + Vector3(0.0, 0.40, 0.0), duela)
	# Dos aros metálicos.
	_cyl(0.475, 0.475, 0.07, c + Vector3(0.0, 0.72, 0.0), aro)
	_cyl(0.385, 0.385, 0.07, c + Vector3(0.0, 0.16, 0.0), aro)
	# Boca oscura: el hueco por el que se ve caer la comida.
	_cyl(0.41, 0.41, 0.04, c + Vector3(0.0, 0.795, 0.0), Color(0.07, 0.06, 0.05))
	# Tapa apoyada de lado contra el cubo.
	var tapa := _cyl(0.42, 0.42, 0.06, c + Vector3(0.52, 0.34, 0.20), duela)
	tapa.rotation_degrees = Vector3(0.0, 0.0, 74.0)
	var sombra := SceneBackdrop.blob_shadow(1.15, 1.15)
	sombra.position = c + Vector3(0.0, 0.02, 0.0)
	add_child(sombra)


func _setup_seats() -> void:
	for def in SEAT_DEFS:
		for along_sign in [-1.0, 1.0]:
			var n: Vector3 = def["n"]
			var offset: Vector3 = def["along"] * SEAT_ALONG * along_sign
			var pos: Vector3 = n * SEAT_OUT + offset
			_add_stool(pos)
			# Sillas de los lados inferiores de pantalla (+X/+Z) usan la borda
			# inferior; las superiores (-Z/-X), la superior.
			var lower := n.x > 0.5 or n.z > 0.5
			seats.append({
				"pos": pos,
				"yaw": rad_to_deg(atan2(-n.x, -n.z)),
				"belt": n * (BELT_SIDE * 0.5) + offset + Vector3(0.0, BELT_TOP, 0.0),
				"ring": n * WALK_R + offset,
				"entry": ENTRY_BOTTOM if lower else ENTRY,
			})


func _add_stool(pos: Vector3) -> void:
	_box(Vector3(0.46, 0.09, 0.46), pos + Vector3(0.0, STOOL_H - 0.045, 0.0),
		Color(0.40, 0.26, 0.15))
	_box(Vector3(0.11, STOOL_H - 0.09, 0.11),
		pos + Vector3(0.0, (STOOL_H - 0.09) * 0.5, 0.0), Color(0.34, 0.22, 0.13))


## El chef vive DENTRO del circuito, como en 2D, detras de su mesa: mesa y
## chef estan orientados hacia el MISMO lado (la esquina inferior de pantalla,
## de cara a la camara). Respira y reacciona a cada gesto del jugador (tweens).
func _setup_chef() -> void:
	# Chef y mesa miran a +Z, que con la camara iso (yaw 45) es la diagonal
	# ABAJO-IZQUIERDA de la pantalla: se le ve la cara y trabaja de lado, sin
	# darle la espalda al jugador ni taparse la mesa con el cuerpo.
	var c_pos := Vector3(-0.45, 0.0, -0.60)
	var t_pos := c_pos + Vector3(0.0, 0.0, 0.92)
	_box(Vector3(0.90, 0.78, 0.60), t_pos + Vector3(0.0, 0.39, 0.0),
		Color(0.40, 0.27, 0.14))
	_box(Vector3(1.02, 0.07, 0.72), t_pos + Vector3(0.0, 0.815, 0.0),
		Color(0.62, 0.45, 0.26))
	chef_pivot = _spawn_model(
		load(CharacterData.model("chef", GameState.player_gender)),
		c_pos, CHEF_H, self)
	chef_pivot.rotation_degrees.y = 0.0
	_add_blob_shadow(c_pos + Vector3(0.12, 0.02, 0.1), 1.25, 0.85)
	var skels := chef_pivot.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		chef_anim = CharacterAnim.new(skels[0])
		if not chef_anim.has_humanoid_bones():
			chef_anim = null
		else:
			var inst: Node3D = chef_pivot.get_child(0)
			_make_chef_tools(skels[0], inst.scale.x)
	# El ingrediente/etapa en curso se muestra sobre la mesa del chef.
	chef_prop = Sprite3D.new()
	chef_prop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	chef_prop.position = t_pos + Vector3(0.0, 1.12, 0.0)
	chef_prop.visible = false
	add_child(chef_prop)


## Utensilios low poly del chef, construidos por codigo y colgados de la
## MUÑECA derecha con un BoneAttachment3D: siguen la mano alla donde la lleve
## la animacion. Se autoran en unidades de mundo (el nodo raiz deshace la
## escala del modelo) con el filo/mango a lo largo de +Z, la linea de los
## nudillos del puño cerrado (empuñadura de martillo).
func _make_chef_tools(skel: Skeleton3D, model_scale: float) -> void:
	var wrist := chef_anim.bone("R_Wrist")
	if wrist < 0:
		return
	var att := BoneAttachment3D.new()
	skel.add_child(att)
	att.bone_name = skel.get_bone_name(wrist)

	# La hoja corre a lo largo de +X local (cruzada respecto al cuerpo): con
	# +Z apuntaba al frente del chef y desde la camara se veia como un palillo.
	chef_knife = Node3D.new()
	att.add_child(chef_knife)
	chef_knife.scale = Vector3.ONE / model_scale
	chef_knife.position = Vector3(0.0, -0.05, 0.0) / model_scale
	chef_knife.rotation_degrees.y = 90.0
	_tool_box(chef_knife, Vector3(0.05, 0.06, 0.16), Vector3(0.0, 0.0, -0.055),
		Color(0.34, 0.21, 0.11))
	_tool_box(chef_knife, Vector3(0.02, 0.10, 0.34), Vector3(0.0, -0.012, 0.20),
		Color(0.82, 0.84, 0.88))
	chef_knife.visible = false

	chef_ladle = Node3D.new()
	att.add_child(chef_ladle)
	chef_ladle.scale = Vector3.ONE / model_scale
	chef_ladle.position = Vector3(0.0, -0.05, 0.0) / model_scale
	chef_ladle.rotation_degrees.y = 90.0
	_tool_box(chef_ladle, Vector3(0.038, 0.038, 0.36), Vector3(0.0, 0.0, 0.11),
		Color(0.46, 0.30, 0.16))
	var cup := MeshInstance3D.new()
	var cup_mesh := CylinderMesh.new()
	cup_mesh.top_radius = 0.075
	cup_mesh.bottom_radius = 0.055
	cup_mesh.height = 0.06
	cup.mesh = cup_mesh
	cup.position = Vector3(0.0, -0.03, 0.32)
	cup.material_override = _mat(Color(0.35, 0.36, 0.40))
	chef_ladle.add_child(cup)
	chef_ladle.visible = false


func _tool_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _mat(color)
	parent.add_child(mi)


# ------------------------------------------------------- instanciacion GLB

func _spawn_model(scene: PackedScene, ground_pos: Vector3, target_h: float,
		parent: Node) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = ground_pos
	parent.add_child(pivot)
	var inst: Node3D = scene.instantiate()
	pivot.add_child(inst)
	var aabb := _merged_aabb(inst)
	var s := target_h / maxf(aabb.size.y, 0.0001)
	inst.scale = Vector3(s, s, s)
	inst.position = -Vector3(
		aabb.position.x + aabb.size.x * 0.5,
		aabb.position.y,
		aabb.position.z + aabb.size.z * 0.5) * s
	return pivot


## Recolorea un modelo ya instanciado multiplicando su albedo. La caja sale de
## fabrica con un naranja muy subido que a pleno sol cantaba como terracota
## entre tanta madera apagada.
func _tint_model(root: Node3D, tint: Color) -> Node3D:
	for m in root.find_children("*", "MeshInstance3D", true, false):
		for i in m.mesh.get_surface_count():
			var base: Material = m.mesh.surface_get_material(i)
			var mat: StandardMaterial3D = base.duplicate() if base is StandardMaterial3D 				else StandardMaterial3D.new()
			mat.albedo_color = tint
			m.set_surface_override_material(i, mat)
	return root


func _merged_aabb(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = m.transform * m.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


# ---------------------------------------------------- cartel de fin de turno

## Tamaño del cartel de resultados: un cartel PEQUEÑO con lo justo (estrellas,
## nivel, oro y los dos botones), en vez del panel casi a pantalla completa de
## antes. El desglose se va a su propia hoja, detrás del botón del lateral.
const RESULT_SIZE := Vector2(548, 472)


## Convierte el panel de resultados en un cartel compacto con cuerdas en las
## esquinas, y se lleva el desglose largo a una hoja aparte.
func _restyle_results_panel() -> void:
	var lienzo := GameState.canvas_size()
	results_panel.offset_left = (lienzo.x - RESULT_SIZE.x) * 0.5
	results_panel.offset_right = results_panel.offset_left + RESULT_SIZE.x
	results_panel.offset_top = (lienzo.y - RESULT_SIZE.y) * 0.5
	results_panel.offset_bottom = results_panel.offset_top + RESULT_SIZE.y
	var vb: VBoxContainer = $HUD/ResultsPanel/VBox
	vb.offset_left = 54.0
	vb.offset_top = 76.0
	vb.offset_right = -54.0
	vb.offset_bottom = -48.0
	# Centrado: el contenido es corto y pegado arriba dejaba medio cartel vacío.
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	# Titular del cartel, arriba del todo.
	# En DOS LÍNEAS: en una sola, para que cupiera a lo ancho del cartel, el
	# cuerpo tenía que bajar tanto que dejaba de leerse como un titular.
	var titular := PrepBoard.make_big_title("Jornada
Acabada", 52)
	# Interlineado AÚN MÁS corto que el de `make_big_title`, y solo aquí: es el
	# único titular de dos líneas del juego, y con el general las dos palabras
	# seguían leyéndose como dos carteles sueltos.
	titular.add_theme_constant_override("line_spacing", -int(52 * 0.54))
	titular.custom_minimum_size = Vector2(0, 106)
	vb.add_child(titular)
	vb.move_child(titular, 0)
	# El titular sube hacia el canto del cartel: debajo va el recuento animado
	# del dinero, y centrado se le comía el sitio.
	vb.alignment = BoxContainer.ALIGNMENT_BEGIN
	vb.offset_top = 44.0
	# La cifra del total va GRANDE y con su moneda al lado. `earn_label` sale
	# del VBox y se mete en esa fila.
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 10)
	var mon := TextureRect.new()
	mon.texture = load("res://assets/ui/moneda.png")
	mon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mon.custom_minimum_size = Vector2(62, 62)
	mon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(mon)
	var idx := earn_label.get_index()
	vb.remove_child(earn_label)
	# Naranja fuerte, no el dorado del titular: sobre el crema del pergamino el
	# oro se confundía con el papel y la cifra no destacaba.
	earn_label.add_theme_font_size_override("font_size", 58)
	earn_label.add_theme_color_override("font_color", Color(1, 0.99, 0.9))
	earn_label.add_theme_color_override("font_outline_color", Color(0.34, 0.13, 0.02))
	earn_label.add_theme_constant_override("outline_size", 13)
	earn_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	earn_label.add_theme_constant_override("shadow_offset_x", 2)
	earn_label.add_theme_constant_override("shadow_offset_y", 4)
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		earn_label.add_theme_font_override("font", negrita)
	earn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Pivote al CENTRO: el latido del recuento la escala, y con el pivote por
	# defecto (esquina superior izquierda) la cifra se iba hacia abajo-derecha
	# en vez de hincharse en su sitio.
	earn_label.resized.connect(func() -> void:
		earn_label.pivot_offset = earn_label.size * 0.5)
	fila.add_child(earn_label)
	vb.add_child(fila)
	vb.move_child(fila, idx)

	# El DESGLOSE largo (clientes, qué comió cada uno, de dónde sale el dinero)
	# sale del cartel y se va a su propia hoja, oculta. En el cartel solo queda
	# el resumen.
	var scroll: Control = $HUD/ResultsPanel/VBox/Scroll
	vb.remove_child(scroll)
	detail_panel = Control.new()
	detail_panel.name = "DetailPanel"
	detail_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Algo más recogido que la pantalla entera: es una hoja que se consulta, no
	# otra pantalla, y a sangre de los bordes no se leía como algo que se cierra.
	detail_panel.offset_left = 52.0
	detail_panel.offset_top = 228.0
	detail_panel.offset_right = -52.0
	detail_panel.offset_bottom = -228.0
	detail_panel.visible = false
	detail_panel.z_index = 130
	# `_show_results` PAUSA el árbol, así que sin esto la hoja del desglose no
	# recibía ni un toque: ni scroll, ni el botón de cerrar.
	detail_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	$HUD.add_child(detail_panel)
	detail_panel.add_child(prep_board.make_nine_patch(
		PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))
	PrepBoard.add_panel_banner(detail_panel, "El turno, al detalle", 28, 0.0)
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 44.0
	scroll.offset_top = 76.0
	scroll.offset_right = -44.0
	scroll.offset_bottom = -118.0
	detail_panel.add_child(scroll)
	TouchScroll.attach(scroll)
	# El botón se sube del canto y se ensancha lo justo para su texto: pegado
	# abajo parecía caído fuera del pergamino, y con 200 px de margen a cada
	# lado la palabra "Cerrar" nadaba dentro de un tablón enorme.
	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	cerrar.offset_left = 214.0
	cerrar.offset_right = -214.0
	cerrar.offset_top = -104.0
	cerrar.offset_bottom = -104.0 + PrepBoard.SMALL_H
	PrepBoard.skin_small_button(cerrar)
	cerrar.add_theme_font_size_override("font_size", 26)
	cerrar.pressed.connect(func() -> void: detail_panel.visible = false)
	detail_panel.add_child(cerrar)

	# Botón pequeño en el LATERAL del cartel que abre ese desglose.
	detail_button = Button.new()
	detail_button.text = "?"
	detail_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	detail_button.offset_left = -74.0
	detail_button.offset_top = 74.0
	detail_button.offset_right = -8.0
	detail_button.offset_bottom = 74.0 + PrepBoard.SMALL_H
	PrepBoard.skin_small_button(detail_button)
	detail_button.add_theme_font_size_override("font_size", 30)
	detail_button.process_mode = Node.PROCESS_MODE_ALWAYS
	detail_button.pressed.connect(func() -> void: detail_panel.visible = true)
	results_panel.add_child(detail_button)

	_add_rope_corners(results_panel)


## Las cuatro cuerdas de las esquinas del cartel. El dibujo es UNA sola espiral
## que mira abajo-derecha; las otras tres son la misma girada, así que las
## cuatro son idénticas y no hay que dibujar cuatro veces.
func _add_rope_corners(box: Control) -> void:
	const R := 82.0
	var esquinas := [
		[Control.PRESET_TOP_LEFT, Vector2(-18, -18), Vector2(1, 1)],
		[Control.PRESET_TOP_RIGHT, Vector2(-R + 18, -18), Vector2(-1, 1)],
		[Control.PRESET_BOTTOM_LEFT, Vector2(-18, -R + 18), Vector2(1, -1)],
		[Control.PRESET_BOTTOM_RIGHT, Vector2(-R + 18, -R + 18), Vector2(-1, -1)],
	]
	for e in esquinas:
		var t := TextureRect.new()
		t.texture = load("res://assets/ui/cuerda_esquina.png")
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.set_anchors_preset(e[0])
		t.size = Vector2(R, R)
		t.position = e[1]
		# El pivote al centro: si no, el volteo se lleva la cuerda de la esquina.
		t.pivot_offset = Vector2(R, R) * 0.5
		t.scale = e[2]
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(t)


# ------------------------------------------------- arranque y cuenta atrás

## CARTEL DE ARRANQUE: el nivel ya no empieza solo. Entre elegir la carta y la
## cuenta atrás de preparación se pregunta "¿Comenzamos?", para que el jugador
## entre en la partida cuando quiera y no le pille el reloj andando.
func _ask_start() -> void:
	awaiting_start = true
	# Si un guion está presentando el puerto (David en los primeros niveles), el
	# cartel ESPERA a que termine de hablar: salir a la vez le tapaba la
	# conversación y había que quitárselo de encima para poder leerla.
	for hijo in get_children():
		if not (hijo is StoryDirector):
			continue
		# Se espera a `narrating` (se apaga en el primer `_play` del guion), no
		# a `is_talking()`: los dos arrancan en diferido y aquí el guion aún
		# está midiendo su foco, así que lo encontraba callado y el cartel salía
		# encima con su paño negro, oscureciendo lo que el foco iluminaba.
		var tope := 0.0
		while is_instance_valid(hijo) and hijo.narrating and tope < 90.0:
			tope += get_process_delta_time()
			await get_tree().process_frame
	var overlay := ColorRect.new()
	overlay.name = "StartGate"
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 150
	$HUD.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := Control.new()
	box.custom_minimum_size = Vector2(470, 290)
	center.add_child(box)
	box.add_child(prep_board.make_nine_patch(
		PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))
	PrepBoard.add_panel_banner(box, "¿Comenzamos?", 30)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 52.0
	vb.offset_top = 74.0
	vb.offset_right = -52.0
	vb.offset_bottom = -44.0
	vb.add_theme_constant_override("separation", 18)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(vb)

	var msg := Label.new()
	msg.text = "Tendrás %d s para adelantar platos antes de que llegue el primer cliente." \
			% int(prep_time_left)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 22)
	msg.add_theme_color_override("font_color", Color(0.42, 0.3, 0.18))
	vb.add_child(msg)

	var go := Button.new()
	go.text = "¡Empezar!"
	go.custom_minimum_size = Vector2(300, 80)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	PrepBoard.skin_start_button(go)
	go.add_theme_font_size_override("font_size", 40)
	go.pressed.connect(func() -> void:
		awaiting_start = false
		overlay.queue_free())
	vb.add_child(go)


## Enciende o apaga el cartel de la cuenta atrás. Se toca el CARTEL y no la
## etiqueta, que ahora vive dentro de él (ocultar la etiqueta dejaría la
## tablilla vacía a la vista).
## De cuánto es el viaje del cartel al entrar y al salir (px de lienzo).
const PHASE_TRAVEL := 620.0


## El cartel ENTRA por la izquierda y SALE por la derecha. Antes se quedaba
## meciéndose en su sitio, que no es lo mismo que una transición.
func _show_phase(on: bool) -> void:
	if phase_sign == null or on == phase_shown:
		return
	phase_shown = on
	if phase_tween != null and phase_tween.is_valid():
		phase_tween.kill()
	phase_tween = create_tween()
	if on:
		phase_sign.position.x = phase_home_x - PHASE_TRAVEL
		phase_sign.visible = true
		phase_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		phase_tween.tween_property(phase_sign, "position:x", phase_home_x, 0.55)
	else:
		phase_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		phase_tween.tween_property(phase_sign, "position:x",
			phase_home_x + PHASE_TRAVEL, 0.45)
		phase_tween.tween_callback(func() -> void: phase_sign.visible = false)


## CARTEL de la cuenta atrás: la misma tablilla de madera que lleva el nombre
## de quien habla en los diálogos, meciéndose de un lado a otro. Antes era un
## texto suelto sobre el 3D.
## Ancho y alto del cartel. MÁS GRANDE que la tablilla del nombre de un
## diálogo: es una cuenta atrás que hay que leer de reojo mientras se cocina.
const PHASE_W := 430.0
const PHASE_H := 78.0


func _setup_phase_sign() -> void:
	var padre := phase_label.get_parent()
	var sign := Control.new()
	sign.name = "PhaseSign"
	sign.custom_minimum_size = Vector2(PHASE_W, PHASE_H)
	sign.set_anchors_preset(Control.PRESET_TOP_LEFT)
	sign.size = sign.custom_minimum_size
	# JUSTO ENCIMA DE LA CINTA de la tabla de elaboración, no arriba del todo:
	# ahí es donde el jugador tiene los ojos mientras cocina, y arriba competía
	# con el reloj y el marcador. Se apoya sobre la fila de cabezas de cliente.
	sign.position = Vector2((GameState.canvas_size().x - PHASE_W) * 0.5,
		GameState.canvas_size().y - 588.0 - HEAD_ICON - 12.0 - PHASE_H)
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.visible = false
	padre.add_child(sign)
	sign.add_child(PrepBoard.make_hstretch_patch(
		PrepBoard.PLATE_TEX, PrepBoard.PLATE_CAP))
	phase_label.get_parent().remove_child(phase_label)
	# ...Y OFFSETS. `set_anchors_preset` a secas NO los toca, y esta etiqueta
	# viene de la escena con los suyos (60/120/660/175): el texto se dibujaba
	# fuera de la tablilla y el cartel salía en blanco.
	phase_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 36)
	phase_label.add_theme_color_override("font_color", Color(1, 0.96, 0.84))
	phase_label.add_theme_constant_override("outline_size", 9)
	sign.add_child(phase_label)
	phase_sign = sign
	phase_home_x = sign.position.x
	sign.position.x = phase_home_x - PHASE_TRAVEL


# ---------------------------------------------------------- marcador de oro

## El dinero y el bote de propinas dejan de ser "moneda + 0/30" y pasan a ser
## DOS BARRAS que se van llenando: una verde y ancha con el oro del turno, y
## otra azul y más fina con las propinas.
##
## Las etiquetas NO se rehacen: se REPARENTAN encima de su barra. Así todo el
## código que ya les escribía el texto (`_update_hud`) sigue valiendo igual, y
## la cifra queda superpuesta a la barra, que es como se pidió.
func _setup_money_bars() -> void:
	var box: VBoxContainer = $HUD/TopRow/MoneyBox
	var money_row: Control = money_label.get_parent()
	var jar_row: Control = jar_label.get_parent()

	# MÁS LARGA que la del bote: es la que tiene que dar cabida a objetivos de
	# tres y cuatro cifras sin que el número de la meta se monte sobre las
	# muescas de estrella.
	money_bar = _make_hud_bar("barra_oro", 16, Vector2(266, 32),
		Color(0.36, 0.86, 0.36), money_label, 26)
	# La de propinas era de 20 px con letra de 17 y no se leía: sube a la misma
	# textura que la del oro (32) con cuerpo 22.
	tip_bar = _make_hud_bar("barra_oro", 16, Vector2(178, 32),
		Color(0.42, 0.68, 1.0), jar_label, 22)
	money_meta = _make_meta_label(money_bar, 26)
	tip_meta = _make_meta_label(tip_bar, 22)
	box.add_child(_with_icon(money_bar, "moneda", 44))
	box.add_child(_with_icon(tip_bar, "ic_propina", 40))
	# Las filas viejas (icono + etiqueta) se quedan vacías: fuera.
	money_row.queue_free()
	jar_row.queue_free()


## Mete la barra en una fila con SU icono a la izquierda (la moneda para el oro,
## el saquito para el bote). Al pasar a barras se habían perdido los dos.
##
## LOS DOS VAN EN `SIZE_SHRINK_CENTER` VERTICAL. Un HBoxContainer estira a sus
## hijos al alto de la fila si no se le dice lo contrario, y como la moneda mide
## 44 y la barra 32, la barra se estiraba a 44: además de deformar una textura
## que solo se puede estirar a lo ancho, dejaba la moneda y la barra descuadradas
## entre sí. Con SHRINK_CENTER cada uno conserva su alto y quedan centrados.
func _with_icon(bar: Control, icono: String, lado: float) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := TextureRect.new()
	ic.texture = load("res://assets/ui/%s.png" % icono)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(lado, lado)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(ic)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(bar)
	return fila


## Las separaciones de la barra del oro son LAS ESTRELLAS DEL JUEGO
## (`estrella_vacia/llena.png`, las mismas del cartel de resultados), no unas
## muescas dibujadas: así el jugador ve DE QUÉ va cada tramo sin tener que
## saberlo. Empiezan apagadas y se encienden al alcanzar su umbral.
const STAR_MARK_TEX := "res://assets/ui/estrella_%s.png"
## Un pelo más alta que el canal: la estrella CABALGA la barra, que es lo que
## la separa del relleno y la hace legible sobre los dos fondos por los que
## pasa (el verde lleno y el canal oscuro).
const STAR_MARK_H := 1.34
## La ÚLTIMA va CENTRADA EN EL FINAL de la barra, medio cuerpo por fuera: es la
## meta del turno, y dentro lleva escrito el oro que cuesta. Un pelo mayor que
## las otras dos, lo justo para que quepa esa cifra sin encogerla.
const STAR_GOAL_H := 1.62
## La cifra del objetivo va SIEMPRE a este cuerpo, y es la ESTRELLA la que da de
## sí si hace falta -nunca al revés-: con el cuerpo remedido, el mismo número se
## leía de un tamaño en un nivel y de otro en el siguiente. El objetivo más
## largo de la campaña es 135, de tres cifras.
const STAR_GOAL_FONT := 20
## Hueco de la cifra dentro de la estrella, en fracción de su lado: una
## estrella tiene las puntas fuera y solo el cuerpo central sirve de papel.
const STAR_GOAL_TEXT := 0.62
## Apagada se ACLARA, no se oscurece: `estrella_vacia.png` ya es marrón oscuro
## (111/76/38) y atenuándola encima se hundía en el canal de la barra —parecía
## un agujero, no una estrella por ganar—. Aclarada se ve la silueta y sigue
## sin competir con la conseguida, que va dorada y a más brillo.
const STAR_MARK_OFF := Color(1.55, 1.55, 1.55, 0.9)
const STAR_MARK_ON := Color(1.25, 1.20, 0.85)

## Estrellas de la barra del oro: `{ nodo, frac, meta, on }`. Se recolocan por
## fotograma en `_place_star_marks` porque el ancho de la barra cambia con el
## lienzo, y el encendido se repasa ahí mismo.
var star_marks: Array = []


## LAS TRES ESTRELLAS de la barra del oro, cada una en su umbral: la barra se
## lee entonces como tres tramos, uno por estrella, y de un vistazo se ve
## cuánto falta para la siguiente en vez de solo "cuánto llevo del total". La
## tercera cae al final, porque su umbral ES la barra llena.
##
## Se llama al final de `_ready`, no desde `_setup_money_bars`: los umbrales
## salen del puerto y todavía no están puestos cuando se visten los paneles.
func _mark_star_steps() -> void:
	star_marks.clear()
	if money_bar == null or star_money.size() < 2:
		return
	# SIN recorte: la estrella sobresale del canal a propósito y con
	# `clip_contents` se le comía la punta de arriba y la de abajo.
	money_bar.clip_contents = false
	var meta := float(star_money.back())
	if meta <= 0.0:
		return
	# La cifra del objetivo deja de vivir pegada al canto: se mete DENTRO de la
	# estrella de la meta, así que pasa a colocarse a mano por fotograma en
	# `_place_star_marks`.
	if money_meta != null:
		money_meta.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		money_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		money_meta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# Contorno FINO: el de 10 px se comía la cifra dentro de la estrella.
		money_meta.add_theme_constant_override("outline_size", 4)
		money_meta.add_theme_color_override("font_color", Color(0.24, 0.14, 0.05))
		money_meta.add_theme_color_override("font_outline_color", Color(1, 0.96, 0.84))
	# La cifra que SUBE, la última de todas: tiene que dibujarse por encima de
	# las estrellas y de la del objetivo, porque en el tramo final se le echa
	# encima a la tercera estrella hasta que la alcanza y desaparece.
	if money_label != null:
		money_bar.move_child(money_label, -1)
	for i in star_money.size():
		var marca := TextureRect.new()
		marca.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		marca.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		marca.texture = load(STAR_MARK_TEX % "vacia")
		marca.modulate = STAR_MARK_OFF
		marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
		money_bar.add_child(marca)
		# Por debajo de las etiquetas, que van las últimas.
		money_bar.move_child(marca, 0)
		star_marks.append({
			"nodo": marca,
			"frac": clampf(float(star_money[i]) / meta, 0.0, 1.0),
			"meta": float(star_money[i]),
			"on": false,
		})


func _place_star_marks() -> void:
	if money_bar == null or star_marks.is_empty():
		return
	var ancho := money_bar.size.x
	var alto := money_bar.size.y
	if ancho <= 0.0:
		return
	var oro := _score_money()
	for i in star_marks.size():
		var m: Dictionary = star_marks[i]
		var meta_star: bool = i == star_marks.size() - 1
		var lado := _goal_star_side(alto) if meta_star else alto * STAR_MARK_H
		var n: TextureRect = m["nodo"]
		n.size = Vector2(lado, lado)
		# El pivote va al centro para que el bote de encendido crezca desde la
		# estrella y no desde su esquina.
		n.pivot_offset = n.size * 0.5
		# CADA ESTRELLA VA CENTRADA EN SU FRACCIÓN EXACTA, sin corregir nada: es
		# lo que hace que el relleno verde llegue justo a la estrella al alcanzar
		# su umbral y ni un pixel antes. Y como la cifra que sube va CENTRADA en
		# la punta del relleno (`_place_bar_value`), esa misma fracción hace que
		# el número aterrice clavado en el centro de la estrella. Se probó a
		# correrlas a la izquierda para cuadrar el número y era peor: el verde se
		# pasaba de largo antes de haberse ganado la estrella.
		n.position = Vector2(float(m["frac"]) * ancho - lado * 0.5,
			(alto - lado) * 0.5)
		if meta_star:
			_place_goal_value(n, lado)
		var ganada: bool = oro >= float(m["meta"])
		if ganada != bool(m["on"]):
			m["on"] = ganada
			_light_star_mark(n, ganada, meta_star)


## Lo que mide la estrella de la meta: su tamaño base, y si el objetivo del
## nivel no cabe dentro a `STAR_GOAL_FONT`, lo que haga falta para que quepa.
## Se mide contra la cifra del OBJETIVO, no contra el texto que la etiqueta
## lleve puesto: al llenarse la barra pasa a enseñar lo conseguido, y si la
## estrella se dimensionara con eso daría un salto de tamaño al cerrar el turno.
func _goal_star_side(alto: float) -> float:
	var base := alto * STAR_GOAL_H
	if money_meta == null or star_money.is_empty():
		return base
	var f := money_meta.get_theme_font("font")
	if f == null:
		return base
	var ancho_txt := f.get_string_size(str(int(star_money.back())),
		HORIZONTAL_ALIGNMENT_LEFT, -1, STAR_GOAL_FONT).x
	return maxf(base, ancho_txt / STAR_GOAL_TEXT)


## La cifra del objetivo, CENTRADA DENTRO de la estrella de la meta y siempre
## al mismo cuerpo (quien se adapta es la estrella, ver `_goal_star_side`).
func _place_goal_value(estrella: TextureRect, lado: float) -> void:
	if money_meta == null:
		return
	money_meta.size = Vector2(lado, lado)
	money_meta.position = estrella.position
	money_meta.add_theme_font_size_override("font_size", STAR_GOAL_FONT)


## Encender una estrella de la barra: se rellena Y BRILLA con un fogonazo que
## se apaga, porque cruzar un umbral es la noticia del turno y sin el golpe se
## pasaba sin verla. El `modulate` por encima de 1 es a propósito: multiplica,
## así que sube el brillo en vez de teñir.
##
## **NINGUNA ESTRELLA CAMBIA DE TAMAÑO AL GANARSE.** El bote elástico que
## llevaban las dos primeras se quitó: son marcas de una escala, y una marca
## que crece y encoge mueve la referencia justo cuando el jugador la está
## mirando para saber por dónde va. Solo la de la META lo conserva, que ahí no
## hay escala que mover: es el final del turno.
##
## Se apaga también (con el castigo por plato tirado o por cliente que se va de
## vacío el oro BAJA), pero sin bote: perder una estrella no se celebra.
func _light_star_mark(n: TextureRect, ganada: bool, bote: bool = false) -> void:
	n.texture = load(STAR_MARK_TEX % ("llena" if ganada else "vacia"))
	n.modulate = STAR_MARK_ON if ganada else STAR_MARK_OFF
	if not ganada:
		n.scale = Vector2.ONE
		return
	var tw := create_tween()
	tw.set_parallel(true)
	if bote:
		tw.tween_property(n, "scale", Vector2(1.55, 1.55), 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "scale", Vector2.ONE, 0.26) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT).set_delay(0.12)
	tw.tween_property(n, "modulate", Color(2.2, 2.1, 1.6), 0.10)
	tw.tween_property(n, "modulate", STAR_MARK_ON, 0.30).set_delay(0.10)


func _make_hud_bar(tex: String, cap: int, tamano: Vector2, tinte: Color,
		etiqueta: Label, cuerpo: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = tamano
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", PrepBoard.make_bar_box(
		"res://assets/ui/%s_fondo.png" % tex, Color.WHITE, cap))
	bar.add_theme_stylebox_override("fill", PrepBoard.make_bar_box(
		"res://assets/ui/%s_relleno.png" % tex, tinte, cap))
	etiqueta.get_parent().remove_child(etiqueta)
	# La cifra que sube es la MÓVIL: va anclada arriba a la izquierda y se
	# recoloca por fotograma (ver `_place_bar_value`), así que aquí solo se le
	# quita el ancho completo que traía de la escena.
	# Anclas Y OFFSETS: las etiquetas vienen de la escena y conservan los suyos.
	etiqueta.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_skin_bar_label(etiqueta, cuerpo)
	bar.add_child(etiqueta)
	return bar


## La cifra del OBJETIVO, clavada al extremo derecho de la barra. Es la que se
## queda sola cuando la móvil llega a ella.
func _make_meta_label(bar: ProgressBar, cuerpo: int) -> Label:
	var l := Label.new()
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.offset_right = -12.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_skin_bar_label(l, cuerpo)
	# Trazo MÁS GRUESO que el de la cifra móvil: esta acaba sola sobre el
	# relleno lleno (verde o azul), y con el contorno fino se emborronaba.
	l.add_theme_constant_override("outline_size", 10)
	bar.add_child(l)
	return l


func _skin_bar_label(l: Label, cuerpo: int) -> void:
	l.add_theme_font_size_override("font_size", cuerpo)
	l.add_theme_color_override("font_color", Color(1, 0.98, 0.9))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


## LA CIFRA QUE SUBE VIAJA SOBRE LA BARRA: arranca pegada al principio y se
## queda en la PUNTA DEL RELLENO, que es justo donde el jugador está mirando.
## Al alcanzar el objetivo desaparece y deja sola la cifra de la meta: repetir
## "40 / 40" no aporta nada, y así se lee de un vistazo que ya está.
##
## El tope de la izquierda evita que la cifra se salga por el canto cuando aún
## no hay relleno; el de la derecha, que se monte encima de la meta.
func _place_bar_value(bar: ProgressBar, movil: Label, meta_l: Label,
		valor: int, meta: int) -> void:
	if movil == null or meta_l == null:
		return
	var lleno: bool = meta > 0 and valor >= meta
	# Con la barra llena la cifra que queda es LO CONSEGUIDO, no el objetivo:
	# pasado el umbral, repetir la meta escondía que se había cerrado con más.
	meta_l.text = str(valor if lleno else meta)
	movil.visible = not lleno
	if lleno:
		return
	movil.text = str(valor)
	var ancho := bar.size.x
	if ancho <= 0.0:
		return
	movil.size = Vector2(movil.get_minimum_size().x + 10.0, bar.size.y)
	var punta := clampf(float(valor) / float(maxi(meta, 1)), 0.0, 1.0) * ancho
	if bar == money_bar and not star_marks.is_empty():
		# BARRA DEL ORO: la cifra va CENTRADA en la punta del relleno, no
		# arrastrada por detrás. Es lo único que cumple las tres cosas a la vez:
		# el verde llega a la estrella justo al ganarla, y el número aterriza
		# clavado en su centro -las estrellas están en su fracción exacta, así
		# que centro del número = punta = centro de la estrella-.
		# Solo se acota por la izquierda, para que no se salga del canto cuando
		# todavía no hay relleno; por la derecha SE DEJA LLEGAR hasta el final,
		# que ahí es donde está la tercera estrella.
		var centro := clampf(punta, movil.size.x * 0.5 + 2.0, ancho)
		movil.position = Vector2(centro - movil.size.x * 0.5, 0.0)
		return
	# El resto de barras (el bote) no llevan estrellas: la cifra va DETRÁS de la
	# punta y frena antes de montarse sobre la meta, que sigue pegada al canto.
	var tope := ancho - meta_l.get_minimum_size().x - 18.0 - movil.size.x
	movil.position = Vector2(
		clampf(punta - movil.size.x - 2.0, 6.0, maxf(tope, 6.0)), 0.0)


# ---------------------------------------------------------- paneles y chef

## Viste los paneles emergentes con el pergamino enmarcado en cuerda.
func _skin_panels() -> void:
	_setup_money_bars()
	_setup_phase_sign()
	_restyle_results_panel()
	if ResourceLoader.exists(PrepBoard.PANEL_TEX):
		for p in [powerup_panel, results_panel]:
			p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			p.add_child(prep_board.make_nine_patch(
				PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))
	# El rótulo es un TITULAR grande DENTRO del cartel, no una cinta: el panel
	# ya lleva cuerdas en las cuatro esquinas y una tela encima lo cargaba.
	$HUD/ResultsPanel/VBox/TitleLabel.visible = false
	var dark := Color(0.26, 0.16, 0.08)
	# `earn_label` NO va aquí: `_restyle_results_panel` ya le pone su crema
	# claro y este bucle, que corre después, se lo pisaba y lo dejaba marrón.
	for l in [$HUD/ResultsPanel/VBox/TitleLabel, score_label,
			$HUD/PowerupPanel/VBox/Title]:
		l.add_theme_color_override("font_color", dark)
	stars_label.add_theme_color_override("font_color", Color(0.78, 0.55, 0.08))
	stars_label.visible = false
	stars_row = HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 12)
	var vbox := $HUD/ResultsPanel/VBox
	vbox.add_child(stars_row)
	vbox.move_child(stars_row, stars_label.get_index() + 1)
	# Cada uno con SU botón: la flecha circular (repetir) en madera azul y el
	# doble galón (continuar) en madera ámbar, con el icono dibujado dentro.
	retry_button.custom_minimum_size = Vector2(212, PrepBoard.ICON_BTN_H)
	PrepBoard.skin_icon_button(retry_button,
		"res://assets/ui/boton_repetir.png", PrepBoard.ICON_BTN_ZONE - 8.0)
	retry_button.add_theme_font_size_override("font_size", 25)
	menu_button.custom_minimum_size = Vector2(232, PrepBoard.ICON_BTN_H)
	PrepBoard.skin_icon_button(menu_button,
		"res://assets/ui/boton_continuar.png", PrepBoard.ICON_BTN_ZONE - 8.0)
	menu_button.add_theme_font_size_override("font_size", 25)
	menu_button.text = "Continuar"


## Reacciones del chef a cada gesto del jugador: dispara la animacion de
## cocina correspondiente (brazos por IK, ver chef_* en CharacterAnim) y pone
## el utensilio que toque en su mano. Un evento = una ejecucion del gesto, asi
## que el chef pica, corta o remueve al MISMO ritmo que el dedo del usuario.
func _on_craft_event(kind: String, stage_id: String) -> void:
	var tex := RecipeData.get_stage_texture(stage_id)
	chef_prop.texture = tex
	chef_prop.visible = tex != null
	if tex != null:
		chef_prop.pixel_size = 0.55 / tex.get_width()

	match kind:
		"tap", "stage":
			_chef_gesture("pat", 0.30, "")
		"cut":
			_chef_gesture("chop", 0.26, "knife")
		"slice":
			# El evento llega al TERMINAR el corte lento; el chef lo replica
			# con su propio corte pausado.
			_chef_gesture("slice", 0.8, "knife")
		"swipe":
			_chef_gesture("roll", 0.45, "")
		"hold":
			_chef_gesture("stir", 0.9, "ladle")
		"stir":
			# Un evento por vuelta completa del jugador: el cazo del chef da
			# una vuelta por cada una, y encadena sin salto si vienen seguidas.
			_chef_gesture("stir", 0.6, "ladle")
		"drag", "select":
			_chef_gesture("place", 0.5, "")
		"serve":
			_chef_gesture("place", 0.45, "")
		"cancel":
			_chef_gesture("clear", 0.5, "")
		"done":
			# Plato terminado: brazos arriba y saltito del pivote.
			_chef_gesture("cheer", 0.7, "")
			if chef_tween != null:
				chef_tween.kill()
				chef_pivot.position.y = 0.0
			chef_tween = create_tween()
			chef_tween.tween_property(chef_pivot, "position:y", 0.14, 0.12)
			chef_tween.tween_property(chef_pivot, "position:y", 0.0, 0.15)


## Arranca (o encadena) un gesto de cocina. "stir" es ciclico: si llega otro
## evento con el gesto aun en marcha, EXTIENDE el giro en vez de reiniciarlo
## (reiniciar daba un salto de fase visible del cazo).
func _chef_gesture(name: String, dur: float, tool: String) -> void:
	_show_chef_tool(tool)
	chef_tool_linger = 0.0
	if name == chef_gesture and name == "stir":
		chef_gesture_end = chef_gesture_t + dur
		return
	chef_gesture = name
	chef_gesture_t = 0.0
	chef_gesture_dur = dur
	chef_gesture_end = dur


func _show_chef_tool(tool: String) -> void:
	if chef_knife != null:
		chef_knife.visible = tool == "knife"
	if chef_ladle != null:
		chef_ladle.visible = tool == "ladle"


# ------------------------------------------------------------------- bucle

func _process(delta: float) -> void:
	_t += delta
	# `play_time` es el reloj DE ESTA PARTIDA (lo usa el desglose del cartel de
	# resultados). Las horas jugadas de toda la vida ya no se suman aquí: las
	# lleva el `_process` de GameState, que cuenta también los menús.
	if not ended:
		play_time += delta
	# El ayudante respira en reposo (desfasado del chef para que no parezcan dos
	# copias del mismo muñeco) y solo amasa cuando le toca cocinar un plato.
	if helper_anim != null:
		helper_anim.reset()
		if helper_gesture_t > 0.0:
			helper_gesture_t = maxf(helper_gesture_t - delta, 0.0)
			helper_anim.chef_pat(1.0 - helper_gesture_t / HELPER_GESTURE_DUR)
		else:
			helper_anim.idle(_t + 1.7)
	if chef_anim != null:
		chef_anim.reset()
		if chef_gesture != "":
			chef_gesture_t += delta
			if chef_gesture_t >= chef_gesture_end:
				chef_gesture = ""
				# El utensilio se queda un momento en la mano por si el
				# jugador encadena otro gesto igual (evita el parpadeo).
				chef_tool_linger = 0.9
				chef_anim.idle(_t)
			else:
				# "stir" cicla con fase continua; el resto son de una pasada.
				var u := fmod(chef_gesture_t, chef_gesture_dur) / chef_gesture_dur \
					if chef_gesture == "stir" else chef_gesture_t / chef_gesture_dur
				match chef_gesture:
					"pat": chef_anim.chef_pat(u)
					"chop": chef_anim.chef_chop(u)
					"slice": chef_anim.chef_slice(u)
					"roll": chef_anim.chef_roll(u)
					"stir": chef_anim.chef_stir(u)
					"place": chef_anim.chef_place(u)
					"clear": chef_anim.chef_clear(u)
					"cheer": chef_anim.chef_cheer(u)
		else:
			if chef_tool_linger > 0.0:
				chef_tool_linger -= delta
				if chef_tool_linger <= 0.0:
					_show_chef_tool("")
			chef_anim.idle(_t)

	if ended:
		# Se esperan 4 s con todo parado (cinta, platos y tabla) para ver a los
		# clientes irse antes del cartel. A quien le pillo COMIENDO se le deja
		# terminar el bocado —a toda prisa— y cobrarlo, asi que la espera se
		# alarga mientras alguien mastique; el tope evita quedarse colgado.
		# Tras el ULTIMO cobro se dejan END_PAY_LINGER s mas para que dé tiempo
		# a leer el "+$N" que sale flotando sobre el cliente.
		if not results_shown:
			end_grace += delta
			if _anyone_finishing_bite() and end_grace < END_BITE_MAX:
				pay_linger = END_PAY_LINGER
			else:
				pay_linger = maxf(pay_linger - delta, 0.0)
				if end_grace >= 4.0 and pay_linger <= 0.0:
					_finalize_results()
		return

	# La banda de la cinta avanza a la velocidad real de los platos (tambien
	# durante la fase de preparacion, pero no congelada).
	if not frozen:
		belt_scroll = fmod(belt_scroll + PLATE_SPEED * belt_mult * delta / band_tile_len, 1.0)
		band_mat.set_shader_parameter("scroll_tiles", belt_scroll)
		if corner_mat != null:
			corner_mat.set_shader_parameter("scroll_tiles", belt_scroll)

	# Fase de preparacion: el reloj no corre y no vienen clientes.
	if prep_phase:
		# La cuenta atrás no arranca hasta que el jugador pulsa "¡Empezar!".
		if awaiting_start:
			return
		prep_time_left -= delta
		_show_phase(true)
		phase_label.text = "Preparación: %d s" % ceili(maxf(prep_time_left, 0.0))
		if prep_time_left <= 0.0:
			prep_phase = false
			_show_phase(false)
			# (El guion del puerto se marca como visto al SUPERARLO, no aquí:
			# ver `_finalize_results`. Quien se quede corto de estrellas y
			# repita vuelve a tener a David explicándoselo todo.)
		_update_hud()
		return

	# "Tiempo de preparacion extra": todo congelado salvo la tabla.
	if frozen:
		freeze_timer -= delta
		_show_phase(true)
		phase_label.text = "Cortesía: %d s" % ceili(maxf(freeze_timer, 0.0))
		if freeze_timer <= 0.0:
			frozen = false
			_show_phase(false)
		_update_hud()
		return

	# Con el reloj retenido (los guiones, mientras David habla) el tiempo no
	# corre. `elapsed` cuenta SIEMPRE, tenga reloj el nivel o no: es lo que
	# marca las llegadas. Lo que solo pasa en los niveles con reloj es que se
	# acabe el turno al agotarse.
	if not clock_hold:
		elapsed += delta
	if timed and elapsed >= time_limit:
		_end_level()
		return

	if belt_timer > 0.0:
		belt_timer -= delta
		if belt_timer <= 0.0:
			belt_mult = 1.0
	if tip_chance_timer > 0.0:
		tip_chance_timer -= delta
		if tip_chance_timer <= 0.0:
			tip_chance_bonus = 0.0
	if tip_amount_timer > 0.0:
		tip_amount_timer -= delta
		if tip_amount_timer <= 0.0:
			tip_amount_mult = 1.0
	if snack_all_timer > 0.0:
		snack_all_timer -= delta
	if no_waste_timer > 0.0:
		no_waste_timer -= delta
	if variety_x2_timer > 0.0:
		variety_x2_timer -= delta
		if variety_x2_timer <= 0.0:
			# Al expirar, cada cliente vuelve a su multiplicador de verdad. Se
			# redondea HACIA ARRIBA para no castigar al que subió durante el
			# doblete: un x5 que llegó a x10 vuelve a x5, y un x9 impar vuelve
			# a x5 y no a x4.
			for c in seat_clients:
				if c != null and c.variety > 0:
					c._set_variety(int(ceil(c.variety / 2.0)), false)

	if not arrival_queue.is_empty() and elapsed >= arrival_queue[0]:
		# Si no hay asiento libre lo reintenta cada frame hasta que lo haya.
		if _try_spawn_client():
			arrival_queue.pop_front()
	# Potenciador ganado mientras el jugador sostenia un gesto: sale en cuanto
	# levanta el dedo.
	_try_open_powerup_choice()
	_update_hud()


# ---------------------------------------------------------------- clientes

func _try_spawn_client() -> bool:
	var free_seats: Array = []
	for i in seats.size():
		if seat_clients[i] == null:
			free_seats.append(i)
	if free_seats.is_empty():
		return false
	# LOS PRIMEROS ASIENTOS (`near_seats` del puerto, la escuela): en vez de
	# sortear silla, se ocupan por orden de CINTA — primero al que el plato
	# recién servido alcanza antes. Con pocos clientes y sillas al azar, uno
	# podía caer justo detrás del punto de salida y quedarse esperando una
	# vuelta entera, que es un castigo que el jugador no entiende y que en los
	# niveles de aprender no aporta nada.
	var idx: int = free_seats.pick_random()
	if near_seats:
		if seat_order.is_empty():
			_compute_seat_order()
		for s in seat_order:
			if s in free_seats:
				idx = s
				break
	var c: Node3D = CLIENT3D.new()
	if not forced_types.is_empty():
		c.client_type = forced_types.pop_front()
	else:
		c.client_type = _pick_client_type()
	# Cada cliente sale hombre o mujer al azar: la clientela cambia de una
	# partida a otra sin tocar la mezcla de TIPOS, que es lo que equilibra el
	# nivel (client_mix cuenta grumetes/piratas/capitanes, no generos).
	c.gender = CharacterData.random_gender()
	# El cliente ESPECIAL del puerto ocupa el primer hueco de su tipo que salga
	# (con `late_type` puesto, el último de la cola). Es un personaje concreto,
	# así que ni se sortea su género ni se repite.
	if special_who != "" and not special_spawned and c.client_type == special_type:
		special_spawned = true
		c.who_override = special_who
		c.gender = CharacterData.MALE
	# La fila de cabezas del HUD cuenta por TIPO, y la cara que enseña es la del
	# PRIMERO de ese tipo que ha pisado el barco en esta partida.
	if not head_gender.has(c.client_type):
		head_gender[c.client_type] = c.gender
	# `head_who` ya solo guarda el personaje GENÉRICO del tipo: los especiales
	# tienen chapa propia (ver `_update_heads_row`), así que colar su cara aquí
	# hacía que todos los de su tipo salieran con ella.
	if not head_who.has(c.client_type):
		head_who[c.client_type] = CharacterData.who_for_type(c.client_type)
	# EL CLIENTE DEL TESORO ocupa el primer hueco de su tipo que salga: sale con
	# su modelo propio (como el cliente especial) y, bien servido, paga con un
	# coleccionable. Se marca aquí para que el nivel pueda vigilarlo.
	if not collectible_client.is_empty() and treasure_client == null \
			and c.client_type == str(collectible_client.get("type", "")):
		c.who_override = str(collectible_client.get("who", ""))
		c.gender = CharacterData.MALE
	c.patience_scale = patience_mult
	c.bite_base = bite_speed_mult
	# En la escuela (sin bote) las propinas ni se tiran: sin esto el cliente
	# soltaba su "+$N" verde flotante hacia un bote que no está en pantalla.
	c.tips_enabled = not no_powerups
	c.variety_ui = not no_variety_ui
	# Entra andando por la borda mas cercana a su asiento, rodea el mostrador
	# y llega a su taburete; al marcharse saldra por esa misma borda.
	var entry: Vector3 = seats[idx]["entry"]
	c.position = entry
	c.route = _route_for_seat(idx)
	c.exit_point = entry
	c.belt_point = seats[idx]["belt"]
	c.seat_yaw = seats[idx]["yaw"]
	add_child(c)
	c.finished.connect(_on_client_finished.bind(idx))
	c.plate_served.connect(_on_client_served)
	seat_clients[idx] = c
	if not collectible_client.is_empty() and treasure_client == null \
			and c.who_override == str(collectible_client.get("who", "")):
		treasure_client = c
	clients_spawned += 1
	_update_client_heads()
	return true


## Orden de los asientos por CERCANÍA DE CINTA: cuánto recorre un plato recién
## nacido (en `SPAWN_PROGRESS`) hasta pasar por delante de cada silla. Lo usa
## `near_seats`; se calcula una vez porque el circuito no cambia.
func _compute_seat_order() -> void:
	var largo: float = belt_path.curve.get_baked_length()
	var pares: Array = []
	for i in seats.size():
		var off: float = belt_path.curve.get_closest_offset(seats[i]["belt"])
		pares.append({ "i": i, "d": fposmod(off - SPAWN_PROGRESS, largo) })
	pares.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["d"]) < float(b["d"]))
	seat_order.clear()
	for e in pares:
		seat_order.append(int(e["i"]))


## Ruta de entrada: desde SU borda (la esquina superior para las sillas de
## arriba, la inferior para las de abajo), por el pasillo exterior (cuadrado de
## radio WALK_R), doblando por las esquinas que toque en el sentido mas corto,
## hasta el punto tras su asiento y de ahi al taburete.
func _route_for_seat(idx: int) -> Array:
	var ring: Vector3 = seats[idx]["ring"]
	var entry: Vector3 = seats[idx]["entry"]
	var r := WALK_R
	var perim := 8.0 * r
	var corners := [Vector3(-r, 0, -r), Vector3(r, 0, -r),
		Vector3(r, 0, r), Vector3(-r, 0, r)]
	# Parametro de perimetro de la esquina de entrada (la superior (-r,-r) es 0,
	# la inferior (r,r) es 4r) y del punto destino tras el asiento.
	var s_e := 0.0 if entry == ENTRY else 4.0 * r
	var s_b := _ring_param(ring)
	var route: Array = [entry]
	var fwd := fposmod(s_b - s_e, perim)
	# Esquinas cruzadas en el sentido mas corto, ordenadas por distancia
	# recorrida desde la entrada.
	var crossed: Array = []
	if fwd <= perim - fwd:
		for k in 4:
			var d := fposmod(2.0 * r * k - s_e, perim)
			if d > 0.01 and d < fwd - 0.01:
				crossed.append([d, corners[k]])
	else:
		var back := perim - fwd
		for k in 4:
			var d := fposmod(s_e - 2.0 * r * k, perim)
			if d > 0.01 and d < back - 0.01:
				crossed.append([d, corners[k]])
	crossed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for c in crossed:
		route.append(c[1])
	route.append(ring)
	route.append(seats[idx]["pos"])
	return route


## Parametro de perimetro (0..8r) de un punto del anillo de paseo.
func _ring_param(p: Vector3) -> float:
	var r := WALK_R
	if absf(p.z + r) < 0.01:
		return p.x + r
	if absf(p.x - r) < 0.01:
		return 2.0 * r + (p.z + r)
	if absf(p.z - r) < 0.01:
		return 4.0 * r + (r - p.x)
	return 6.0 * r + (r - p.z)


## Tipo de cliente: cola exacta del nivel; si no, pesos de campaña, o la
## mezcla del modo prueba (60% grumete, 30% pirata, 10% capitan).
func _pick_client_type() -> String:
	if not type_queue.is_empty():
		return type_queue.pop_front()
	return _weighted_client_type()


## Tipo SORTEADO por los pesos del puerto, SIN tocar la cola exacta. Es lo que
## necesita la clientela de regalo del potenciador "Más clientela": son clientes
## DE MÁS, así que no pueden gastarse un hueco de la cola del nivel — con
## `_pick_client_type` se lo robaban y la mezcla del puerto salía descuadrada.
func _weighted_client_type() -> String:
	if client_weights.is_empty():
		var r := randf()
		if r < 0.6:
			return "E"
		elif r < 0.9:
			return "A"
		return "G"
	var total := 0.0
	for t in client_weights:
		total += float(client_weights[t])
	var pick := randf() * maxf(total, 0.0001)
	for t in ["E", "A", "G"]:
		pick -= float(client_weights.get(t, 0.0))
		if pick <= 0.0:
			return t
	return "E"


## El dinero y las propinas ya se abonaron plato a plato (_on_client_served);
## al marcharse solo queda registrar el resumen y, si se fue sin probar nada,
## cobrar el castigo (client3d.LEAVE_PENALTY).
func _on_client_finished(report: Dictionary, seat_idx: int) -> void:
	seat_clients[seat_idx] = null
	client_reports.append(report)
	# Logros: solo cuenta como "dar de comer" el cliente que se lleva algo.
	var eaten: Array = report.get("eaten", [])
	if not eaten.is_empty():
		GameState.bump_stat("clients_%s" % str(report.get("type", "E")))
		GameState.bump_stat("clients_total")
		GameState.max_stat("best_client_plates", eaten.size())
	var penalty := int(report.get("penalty", 0))
	if penalty > 0:
		money_earned = maxi(money_earned - penalty, 0)
		# El cliente calculó su castigo con el contador de ANTES de irse; el
		# siguiente que se marche de vacío pagará un escalón más.
		empty_leavers += 1
	clients_finished += 1
	_update_client_heads()
	_update_hud()
	# En las islas y los puertos el turno lo acota la CLIENTELA: cuando se va el
	# último, se acabó el trabajo. En los abordajes no, que siguen entrando.
	if not unlimited and clients_finished >= total_clients:
		_end_level()


## Cada plato comido: solo el PRECIO cuenta como dinero generado (estrellas y
## monedero). La propina va unicamente al bote de potenciadores.
func _on_client_served(food: int, tip: int) -> void:
	money_earned += food
	if tip > 0:
		_add_tip(tip)
	_check_treasure()
	_check_goal_reached()


## EL CLIENTE DEL TESORO paga con un COLECCIONABLE en vez de con más oro: en
## cuanto se le han servido los platos que pedía, suelta su pieza. Se anuncia
## por la capa global de avisos (`unlock_collectible`), que ya sabe esperar a
## que el árbol esté en un momento razonable.
func _check_treasure() -> void:
	if treasure_given or treasure_client == null \
			or not is_instance_valid(treasure_client):
		return
	var piden := int(collectible_client.get("plates", 3))
	if treasure_client.eaten_ids.size() < piden:
		return
	treasure_given = true
	var pieza := str(collectible_client.get("item", ""))
	if pieza != "":
		GameState.unlock_collectible(pieza)


## DINERO BASE: solo el precio de los platos. Es lo que marca el contador del
## HUD y lo ÚNICO que puede cerrar el turno antes de tiempo (ver
## `_check_goal_reached`): así el nivel nunca se corta por unas propinas que el
## jugador no controla.
func _score_money() -> int:
	return money_earned


## Lo que se mide contra los umbrales de ESTRELLA al cerrar la jornada: el
## dinero base MÁS las propinas. Es la misma cifra que se cobra (sin las primas
## de cierre), así que el total del cartel y las estrellas cuadran.
##
## Ojo con la asimetría, que es a propósito: las propinas SUMAN para las
## estrellas pero NO adelantan el final del turno.
func _star_money() -> int:
	return money_earned + tips_total


func _check_goal_reached() -> void:
	if ended or goal_reached or star_money.is_empty():
		return
	# Con un JEFE pendiente el turno no se cierra por dinero: cortar la partida
	# antes de que el jefe salga (o a mitad de su duelo) le robaría el nivel.
	if boss_id != "" and not boss_done:
		return
	if _score_money() >= int(star_money.back()):
		goal_reached = true
		_end_level()


## Clientes que se quedaron sin venir, contados por tipo.
func _leftover_clients() -> Dictionary:
	var out := { "E": 0, "A": 0, "G": 0 }
	for t in type_queue:
		out[t] = int(out.get(t, 0)) + 1
	for t in forced_types:
		out[t] = int(out.get(t, 0)) + 1
	return out
	_update_hud()


# ------------------------------------------------- propinas y potenciadores

## Umbral acumulado de propinas para el potenciador n+1.
func _tip_threshold(claimed: int) -> int:
	var total := 0
	for i in claimed + 1:
		total += TIP_INCREMENTS[i] if i < TIP_INCREMENTS.size() else 60
	return total


func _add_tip(amount: int) -> void:
	# Sin bote (niveles-escuela) las propinas no existen. Los clientes ya salen
	# con `tips_enabled` a false, así que aquí no debería llegar nada; el guard
	# cubre las que caen por otros canales (el bono de postre).
	if no_powerups:
		return
	tips_total += amount
	GameState.bump_stat("tips_total", amount)
	# SIN `_check_goal_reached()`: las propinas cuentan para las estrellas al
	# cerrar la jornada, pero no adelantan el final del turno.
	while tips_total >= _tip_threshold(powerups_claimed):
		powerups_claimed += 1
		pending_powerups += 1
	_try_open_powerup_choice()


## Saca el cartel de potenciador SOLO si no pilla al jugador en mitad de un
## gesto que hay que sostener (ver prep_board.is_gesture_locked): pausar el
## juego ahi le arruinaria la receta. Si toca esperar, `_process` lo reintenta
## en cuanto suelta el dedo.
func _try_open_powerup_choice() -> void:
	if pending_powerups <= 0 or powerup_panel.visible or ended:
		return
	if prep_board.is_gesture_locked():
		return
	_open_powerup_choice()


## Alto de cada tarjeta y tamaño del dibujo que la encabeza.
const POWERUP_CARD_H := 148.0
const POWERUP_ICON := 104.0


## Tres tarjetas: DIBUJO + TÍTULO, y nada más. Antes cada opción era un párrafo
## ("nombre (automático)\ndescripción" con ajuste de línea), o sea tres párrafos
## que leer con el juego parado para poder seguir jugando. El dibujo se
## reconoce de un vistazo y el título de powerup_data está escrito para
## sostenerse solo, sin la línea de apoyo.
##
## El cartel SIGUE PARANDO EL JUEGO ENTERO —cinta, reloj, paciencia y bocados—:
## lo que se ha recortado es lo que hay que leer, no el tiempo para leerlo.
func _open_powerup_choice() -> void:
	for child in powerup_options.get_children():
		child.queue_free()
	var ids: Array = PowerupData.POWERUPS.keys()
	# "Horas extra" alarga el reloj: en un nivel sin reloj no significaría nada.
	if not timed:
		ids.erase("horas_extra")
	ids.shuffle()
	for i in mini(3, ids.size()):
		powerup_options.add_child(_make_powerup_card(str(ids[i])))
	powerup_panel.visible = true
	get_tree().paused = true
	_animate_powerup_panel()


func _make_powerup_card(id: String) -> Button:
	var data := PowerupData.get_powerup(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, POWERUP_CARD_H)
	prep_board.skin_button(b)
	b.pressed.connect(_on_powerup_chosen.bind(id))
	var margen := (POWERUP_CARD_H - POWERUP_ICON) * 0.5
	var icono := TextureRect.new()
	# EXPAND_IGNORE_SIZE antes de asignar la textura, o el mínimo salta al
	# tamaño nativo del dibujo y deforma la tarjeta.
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var ruta: String = str(data.get("icon", ""))
	if ResourceLoader.exists(ruta):
		icono.texture = load(ruta)
	icono.position = Vector2(margen, margen)
	icono.size = Vector2(POWERUP_ICON, POWERUP_ICON)
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icono)
	var titulo := Label.new()
	titulo.text = str(data.get("name", id))
	titulo.add_theme_font_size_override("font_size", 30)
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	titulo.offset_left = margen * 2.0 + POWERUP_ICON
	titulo.offset_right = -margen
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(titulo)
	return b


## Entrada del cartel de potenciador: aparece de golpe desde pequeño con
## rebote, se balancea un instante y luego late despacio. El panel está en
## PROCESS_MODE_ALWAYS, así que el tween corre con el juego en pausa.
func _animate_powerup_panel() -> void:
	powerup_panel.pivot_offset = powerup_panel.size * 0.5
	powerup_panel.scale = Vector2(0.55, 0.55)
	powerup_panel.rotation = deg_to_rad(-5.0)
	powerup_panel.modulate.a = 0.0
	var tw := powerup_panel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(powerup_panel, "scale", Vector2.ONE, 0.42) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(powerup_panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(powerup_panel, "rotation", 0.0, 0.5) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void:
		var loop := powerup_panel.create_tween().set_loops()
		loop.tween_property(powerup_panel, "scale", Vector2(1.02, 1.02), 0.85) \
				.set_trans(Tween.TRANS_SINE)
		loop.tween_property(powerup_panel, "scale", Vector2.ONE, 0.85) \
				.set_trans(Tween.TRANS_SINE))


func _on_powerup_chosen(id: String) -> void:
	pending_powerups -= 1
	_apply_powerup(id)
	if pending_powerups > 0:
		_open_powerup_choice()
	else:
		powerup_panel.visible = false
		get_tree().paused = false


## Todos los potenciadores son AUTOMÁTICOS: se aplican aquí mismo al elegirlos
## (ver la cabecera de powerup_data.gd para por qué desapareció la mitad manual).
func _apply_powerup(id: String) -> void:
	match id:
		"cinta_rapida":
			belt_mult = 3.0
			belt_timer = 20.0
		"aroma":
			aroma_active = true
		"receta_instantanea":
			prep_board.instant_recipes += 3
		"clientes_pacientes":
			patience_mult *= 1.2
			for c in seat_clients:
				if c != null:
					c.boost_patience(0.2)
		# Absorbe al antiguo "sin cooldown": si va a ser el único potenciador de
		# enfriamiento, que se note (0.6 durante 20 s apenas se percibía).
		"menos_cooldown":
			prep_board.cooldown_mult = 0.4
			prep_board.cooldown_mult_timer = 25.0
		# Las dos mitades de propina van juntas: por separado eran dos opciones
		# del sorteo que el jugador no sabía distinguir.
		"mas_propinas":
			tip_chance_bonus = 0.1
			tip_chance_timer = 30.0
			tip_amount_mult = 1.2
			tip_amount_timer = 30.0
		"clientes_extra":
			_add_extra_clients()
		"horas_extra":
			time_limit += 60.0
		"doble_plato":
			prep_board.double_next = true
		# +1 de variedad a todos los que están en el barco (también a los que
		# vienen andando: llegan ya con el regalo puesto).
		"variedad_extra":
			for c in seat_clients:
				if c != null:
					c._set_variety(c.variety + 1, true)
		"sobremesa":
			dessert_boost = true
		"todo_picoteo":
			snack_all_timer = 30.0
		"sin_basura":
			no_waste_timer = 60.0
		# Dobla lo que ya tienen los sentados Y el tope, para que un x4 pueda
		# llegar de verdad a x8 (ver client3d.variety_cap).
		"doble_variedad":
			variety_x2_timer = 15.0
			for c in seat_clients:
				if c != null and c.variety > 0:
					c._set_variety(c.variety * 2, true)
		# Absorbe al antiguo "guardar un plato más": una caja más Y pilas de 5.
		"mas_almacen":
			prep_board.add_storage_slot()
			prep_board.stack_max = 5
		"tiempo_extra_prep":
			frozen = true
			freeze_timer = 10.0


## Los 3 clientes de regalo son clientela DE MÁS: suben el cupo del turno, o en
## un nivel sin reloj (donde el cupo es lo que lo cierra) el nivel podía darse
## por acabado antes de que llegaran a entrar.
##
## El TIPO ya no lo elige el potenciador (había uno por tipo, tres entradas de
## catálogo para el mismo efecto): se sortea con los pesos del puerto, así que
## la clientela extra sabe al nivel en el que aparece.
func _add_extra_clients() -> void:
	for i in 3:
		forced_types.append(_weighted_client_type())
		arrival_queue.append(elapsed + 1.0 + i * 6.0)
		# OJO: uno por cliente y ya está. Antes se sumaba aquí dentro Y otro +3
		# después, así que el cupo del turno subía de 6 en 6 y el contador de
		# clientes del HUD se quedaba con un total que no llegaba nunca.
		total_clients += 1
	arrival_queue.sort()
	_update_hud()


# ------------------------------------------------------------------ platos

func _on_dish_served(recipe_id: String, price_override: int = 0, extras: Array = [],
		level_override: int = 0, eat_mult_override: float = 0.0) -> void:
	var p: PathFollow3D = PLATE3D.new()
	p.recipe_id = recipe_id
	# El barco combinado vale lo que valen los platos que lleva dentro.
	p.price_override = price_override
	p.extras = extras
	p.level_override = level_override
	p.eat_mult_override = eat_mult_override
	p.only_who = str(exclusive_dishes.get(recipe_id, ""))
	p.speed = PLATE_SPEED
	belt_path.add_child(p)
	p.progress = SPAWN_PROGRESS
	p.discarded.connect(_on_plate_discarded.bind(p))


## Plato que sale de la TABLA del jugador: cuenta para desbloquear perks y
## para los logros.
func _on_player_dish_served(recipe_id: String, price_override: int = 0,
		extras: Array = [], level_override: int = 0,
		eat_mult_override: float = 0.0) -> void:
	dishes_served += 1
	# Logros: platos elaborados por el jugador (los del ayudante no cuentan).
	GameState.bump_stat("dishes_made")
	GameState.bump_stat("dish_%s" % recipe_id)
	_on_dish_served(recipe_id, price_override, extras, level_override, eat_mult_override)


## Borra un plato de la lista de RECHAZADOS de todos los clientes, para que
## vuelva a tener una oportunidad con cada uno. Lo usa "Nada se tira" cuando le
## regala otra vuelta: sin este olvido el plato daría vueltas eternas sin que
## nadie pudiera cogerlo, porque el dado se tira UNA vez por cliente y plato y
## los que fallaron lo tienen en `declined` para siempre.
func _forget_declined(plate_id: int) -> void:
	for c in seat_clients:
		if c != null:
			c.declined.erase(plate_id)


## Un plato desechado (una vuelta entera sin que nadie lo coja) cuesta una parte
## de su precio (WASTE_PENALTY).
func _on_plate_discarded(recipe_id: String, plate: Node3D = null) -> void:
	# Logro "aquí no se tira nada": la partida deja de ser limpia.
	plates_wasted += 1
	var price: int = RecipeData.get_recipe(recipe_id).get("price", 0)
	# Siempre cuesta algo: hasta el plato más barato se cobra un doblón.
	var castigo: int = maxi(int(round(price * WASTE_PENALTY)), 1)
	# Como el resto de castigos, el marcador nunca baja de 0.
	money_earned = maxi(money_earned - castigo, 0)
	_waste_text(castigo, plate)
	_update_hud()


## Lo que cuesta el plato tirado, flotando sobre él mientras cae a la basura.
func _waste_text(castigo: int, plate: Node3D) -> void:
	if world_ui == null or plate == null or not is_instance_valid(plate):
		return
	var lbl := Label.new()
	lbl.text = "-%d" % castigo
	lbl.custom_minimum_size = Vector2(130, 0)
	lbl.position = cam.unproject_position(
		plate.global_position + Vector3.UP * 0.35) + Vector2(-65, -34)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.42, 0.35))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	lbl.add_theme_constant_override("outline_size", 7)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.pivot_offset = Vector2(65, 18)
	world_ui.add_child(lbl)
	var coin := TextureRect.new()
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture = load("res://assets/ui/moneda.png")
	coin.size = Vector2(26, 26)
	coin.position = Vector2(84, 6)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_child(coin)
	lbl.scale = Vector2(0.5, 0.5)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.14) 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", lbl.position.y - 54.0, 0.75) 			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.75)
	tw.tween_callback(lbl.queue_free)


## Castigo por un gesto mal hecho (cortar deprisa el pescado caro). Nunca deja
## el marcador en negativo: si no hay dinero, no se pierde más.
func _on_money_penalty(amount: int) -> void:
	money_earned = maxi(money_earned - amount, 0)
	_update_hud()


# -------------------------------------------------------------- resultados

## ¿Queda alguien terminando su ultimo bocado tras el fin del nivel?
func _anyone_finishing_bite() -> bool:
	for c in get_tree().get_nodes_in_group("clients"):
		if c.has_method("is_finishing_bite") and c.is_finishing_bite():
			return true
	return false


## Marca el fin del nivel: desaloja a los que queden, para los platos de la
## cinta (la banda deja de avanzar sola al estar "ended") y bloquea la tabla.
func _end_level() -> void:
	if ended:
		return
	# El tutorial no termina ni por reloj ni por clientes: termina su guion
	# (tutorial_director cierra con complete_tutorial y vuelve al menú).
	if GameState.is_tutorial():
		return
	ended = true
	# Se acabo: ya no hay nada que abandonar, manda el panel de resultados.
	if exit_button != null:
		exit_button.visible = false
	for i in seats.size():
		var c = seat_clients[i]
		if c != null:
			# Si el turno se cierra por haber alcanzado el OBJETIVO, los que
			# quedaban sentados NO se cobran: el trabajo ya estaba hecho y
			# cobrarlos podía dejar el marcador por debajo del objetivo otra
			# vez. Si se acaba el tiempo, el castigo sí cuenta.
			c.force_leave(not goal_reached)
	for p in get_tree().get_nodes_in_group("plates"):
		p.set_process(false)
	prep_board.process_mode = Node.PROCESS_MODE_DISABLED


## Puntuacion POR DINERO: cada umbral de "star_money" alcanzado da una estrella.
func _finalize_results() -> void:
	results_shown = true
	# Las ESTRELLAS salen del dinero base MÁS las propinas: es exactamente la
	# cifra que se lleva el jugador de la jornada, así que el total del cartel y
	# las estrellas cuentan la misma historia. Lo que NO cuenta aquí son las
	# primas de cierre, que son un premio por acabar pronto y no producción.
	var stars := 0
	for threshold in star_money:
		if _star_money() >= int(threshold):
			stars += 1
	# NIVEL CON JEFE: el aprobado es el jefe, no el oro. Sin rendirlo, las
	# estrellas se quedan en 1 como mucho (el nivel NO se supera por dinero);
	# con él rendido caen al menos las 2 del aprobado, y la 3ª sigue pidiendo
	# el umbral de dinero de siempre.
	if boss_id != "":
		stars = maxi(stars, 2) if boss_done else mini(stars, 1)

	# Lo que se cobra: platos + propinas + las primas por lo que ha sobrado.
	bonus_clients = 0
	# En un abordaje la clientela no se acaba nunca, así que no hay "clientes
	# que se han quedado sin venir" que premiar: la prima es solo de los niveles
	# con cupo, donde cerrar antes de tiempo SÍ deja gente en el muelle.
	if not unlimited:
		var leftover := _leftover_clients()
		for t in leftover:
			bonus_clients += int(LEFTOVER_BONUS.get(t, 0)) * int(leftover[t])
	bonus_time = 0
	if timed:
		bonus_time = int(floor(maxf(time_limit - elapsed, 0.0) / TIME_BONUS_BLOCK)) \
				* TIME_BONUS
	# El total INCLUYE las propinas: el desglose las listaba ("Dinero base" +
	# "Propinas" + primas) pero la cifra grande se las dejaba fuera, así que las
	# líneas del desglose no sumaban el titular.
	var total_money := _star_money() + bonus_clients + bonus_time

	# EL GUION SE QUEMA AL SUPERAR EL NIVEL, NO AL JUGARLO. Si el jugador se
	# queda corto de estrellas y repite, David vuelve a explicárselo todo; en
	# cuanto lo aprueba, las repeticiones son partidas limpias. (Estuvo
	# marcándose al acabar la fase de preparación, y entonces un intento
	# fallido dejaba al jugador sin la clase que aún necesitaba.)
	if GameState.is_adventure() and stars >= int(CampaignData.get_port(
			GameState.current_port).get("goal_stars", 2)):
		GameState.mark_port_narrated(GameState.current_port)

	var new_recipes: Array = []
	if GameState.is_adventure():
		GameState.money += total_money
		GameState.record_level_score(GameState.current_port, total_money)
		new_recipes = GameState.complete_port(GameState.current_port, stars)
		# Los potenciadores permanentes se ganan por combos, no por estrellas.
		for p in _check_perk_unlocks():
			new_recipes.append({ "perk": p })
	# Logros: los récords de dinero van por modo, el acumulado suma los dos.
	GameState.max_stat("best_money_%s" % ("level" if GameState.is_adventure()
		else "arcade"), total_money)
	GameState.bump_stat("money_total", total_money)
	GameState.max_stat("best_dishes_run", dishes_served)
	if plates_wasted == 0 and dishes_served > 0:
		GameState.bump_stat("clean_runs")
	GameState.save_game()
	GameState.last_score = float(total_money)
	GameState.last_stars = stars
	GameState.last_money_earned = total_money
	_show_results(stars, total_money, new_recipes)


const TYPE_NAMES := { "E": "Grumete", "A": "Pirata", "G": "Capitán" }

# ------------------------------------------------------- estrellas del cartel

## Tamaño de cada estrella del cartel de resultados y hueco entre ellas.
const STAR_SIZE := 58.0
## Lo que tarda en aparecer la primera y lo que se espera entre una y la
## siguiente. Se van cayendo de izquierda a derecha, no de golpe.
const STAR_DELAY := 0.34
const STAR_GAP := 0.42


## Las tres estrellas ENTRAN DE UNA EN UNA, y cada una cuenta lo suyo: la
## conseguida llega girando y dando un pisotón, con un destello y un rebote
## detrás; la que falta se deja caer desde arriba, apagada y torcida, y se queda
## hundida en su hueco. Enterarse de que te falta una estrella tiene que dar
## pena, no salir escrito en gris.
##
## Va todo en PROCESS_MODE_ALWAYS porque `_show_results` PAUSA el árbol: un
## tween creado sobre un nodo en pausa no avanza ni un fotograma.
## Huecos de las estrellas: cada uno con su estrella vacía de fondo y la llena
## encima, apagada, esperando su turno. `star_slots` guarda las llenas para
## poder encenderlas UNA A UNA según sube el recuento del dinero.
var star_slots: Array = []


func _build_star_slots() -> void:
	star_slots.clear()
	stars_row.process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 3:
		var hueco := Control.new()
		hueco.custom_minimum_size = Vector2(STAR_SIZE, STAR_SIZE)
		hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hueco.process_mode = Node.PROCESS_MODE_ALWAYS
		stars_row.add_child(hueco)
		# La estrella VACÍA se queda siempre debajo, como el hueco que hay que
		# llenar: sin ella, una estrella que aún no ha entrado deja un vacío y la
		# fila baila mientras se revelan.
		var fondo := _star_sprite("res://assets/ui/estrella_vacia.png")
		fondo.modulate = Color(1, 1, 1, 0.28)
		hueco.add_child(fondo)
		var ic := _star_sprite("res://assets/ui/estrella_llena.png")
		ic.modulate.a = 0.0
		hueco.add_child(ic)
		star_slots.append(ic)


## Enciende una estrella CONSEGUIDA: entra enorme y girada, se clava de golpe
## (BACK sobrepasa y vuelve), suelta un destello y remata con un latido.
## `especial` es la TERCERA: gira entera, tarda más y deja un fogonazo dorado
## que se abre detrás. Sacar las tres tiene que notarse.
func _pop_star(idx: int, especial := false) -> void:
	if idx < 0 or idx >= star_slots.size():
		return
	var ic: TextureRect = star_slots[idx]
	ic.scale = Vector2(3.4, 3.4) if especial else Vector2(2.6, 2.6)
	ic.rotation_degrees = -540.0 if especial else -210.0
	var dur := 0.62 if especial else 0.42
	if especial:
		# Fogonazo: una estrella gigante detrás que se abre y se apaga.
		var flash := _star_sprite("res://assets/ui/estrella_llena.png")
		flash.modulate = Color(1.8, 1.6, 0.9, 0.85)
		ic.get_parent().add_child(flash)
		ic.get_parent().move_child(flash, 0)
		var tf := flash.create_tween().set_parallel(true)
		tf.tween_property(flash, "scale", Vector2(3.6, 3.6), 0.55).set_delay(dur * 0.7) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tf.tween_property(flash, "modulate:a", 0.0, 0.55).set_delay(dur * 0.7)
		tf.chain().tween_callback(flash.queue_free)
	var t := ic.create_tween().set_parallel(true)
	t.tween_property(ic, "modulate:a", 1.0, 0.12)
	t.tween_property(ic, "scale", Vector2.ONE, dur) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(ic, "rotation_degrees", 0.0, dur) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(ic, "modulate", Color(2.4, 2.4, 2.0, 1.0), 0.08).set_delay(dur)
	t.tween_property(ic, "modulate", Color.WHITE, 0.24).set_delay(dur + 0.08)
	t.tween_property(ic, "scale", Vector2(1.22, 1.22), 0.14) \
			.set_delay(dur + 0.08).set_trans(Tween.TRANS_SINE)
	t.tween_property(ic, "scale", Vector2.ONE, 0.2) \
			.set_delay(dur + 0.22).set_trans(Tween.TRANS_SINE)


## La estrella que NO se ha conseguido: se descuelga desde arriba, sin fuerza, y
## aterriza torcida, hundida y a media luz. TRANS_QUAD entrando: cae y se para,
## sin rebote ninguno. Enterarse de que falta una tiene que dar pena.
func _drop_star(idx: int) -> void:
	if idx < 0 or idx >= star_slots.size():
		return
	var ic: TextureRect = star_slots[idx]
	ic.texture = load("res://assets/ui/estrella_vacia.png")
	ic.position.y -= 34.0
	ic.scale = Vector2(1.1, 1.1)
	var t := ic.create_tween().set_parallel(true)
	t.tween_property(ic, "modulate:a", 0.5, 0.5)
	t.tween_property(ic, "position:y", 5.0, 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(ic, "scale", Vector2(0.9, 0.9), 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(ic, "rotation_degrees", -10.0, 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Una estrella suelta, con el pivote en el centro para poder girarla y
## escalarla sin que se vaya de su hueco.
func _star_sprite(ruta: String) -> TextureRect:
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = load(ruta)
	ic.position = Vector2.ZERO
	ic.size = Vector2(STAR_SIZE, STAR_SIZE)
	ic.pivot_offset = Vector2(STAR_SIZE, STAR_SIZE) * 0.5
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


func _show_results(stars: int, total_money: int, new_recipes: Array) -> void:
	# El juego se dirige al jugador por su nombre (Opciones); sin nombre usa el
	# tratamiento que toque por el género elegido.
	for c in stars_row.get_children():
		c.queue_free()
	_build_star_slots()
	# La cifra del cartel es el TOTAL de la jornada (platos + propinas +
	# primas), en grande y con su moneda al lado. Ya no se enseña el
	# porcentaje ni el nombre del puerto: el desglose está a un botón.
	# Arranca en 0: la sube `_count_up_money` por tramos.
	earn_label.text = "0"
	score_label.visible = false
	_build_breakdown()
	_setup_results_scroll()
	powerup_panel.visible = false
	# Con el cartel puesto, el HUD de partida sobra y ademas se colaba por
	# encima del pergamino.
	if heads_row != null:
		heads_row.visible = false
	if exit_button != null:
		exit_button.visible = false
	results_panel.visible = true
	get_tree().paused = true
	await _count_up_money(stars)
	_reveal_recipes(new_recipes)


# --------------------------------------------------- recuento de la jornada

## Lo que tarda cada tramo del recuento y el respiro entre uno y otro.
const COUNT_BASE := 1.0
const COUNT_EXTRA := 0.65
const COUNT_PAUSE := 0.35
## Dónde nace la chapa del "+N" respecto a la cifra grande, y cuánto sube.
const CHIP_RISE := 96.0


## EL TOTAL SE CUENTA POR TRAMOS, no aparece hecho: primero sube el dinero de
## los PLATOS desde 0, después entra la chapa de las PROPINAS y su cifra se suma
## encima, y al final la de las PRIMAS de cierre. Cada chapa lleva su icono y
## sube flotando mientras el número de abajo la absorbe.
##
## LAS ESTRELLAS SE ENCIENDEN AL PASO del contador: cuando la suma cruza el
## umbral de una estrella, esa estrella entra. Se comprueba contra `stars`, que
## se calculó con base + propinas, para que las primas del último tramo no
## enciendan una estrella que no se ha ganado.
func _count_up_money(stars: int) -> void:
	var encendidas := { "n": 0 }
	await _count_leg(0, money_earned, COUNT_BASE, stars, encendidas)
	if tips_total > 0:
		await get_tree().create_timer(COUNT_PAUSE).timeout
		_money_chip(tips_total, "res://assets/ui/ic_propina.png")
		await _count_leg(money_earned, money_earned + tips_total,
			COUNT_EXTRA, stars, encendidas)
	var primas := bonus_clients + bonus_time
	if primas > 0:
		await get_tree().create_timer(COUNT_PAUSE).timeout
		_money_chip(primas, "res://assets/ui/reloj.png" if bonus_time > bonus_clients
			else "res://assets/ui/head_E.png")
		await _count_leg(money_earned + tips_total,
			money_earned + tips_total + primas, COUNT_EXTRA, stars, encendidas)
	# Las que no se han conseguido caen ahora, cuando ya no hay nada que sumar.
	await get_tree().create_timer(COUNT_PAUSE).timeout
	for i in range(int(encendidas["n"]), 3):
		_drop_star(i)
		await get_tree().create_timer(0.18).timeout


## Un tramo del contador. Sube la cifra de `desde` a `hasta` y va encendiendo
## las estrellas cuyo umbral se cruce por el camino.
func _count_leg(desde: int, hasta: int, dur: float, stars: int,
		encendidas: Dictionary) -> void:
	if hasta <= desde:
		return
	var t := earn_label.create_tween()
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_method(_count_tick.bind(stars, encendidas),
		float(desde), float(hasta), dur)
	# Un latido de la cifra al terminar el tramo, para que se note el salto.
	t.chain().tween_property(earn_label, "scale", Vector2(1.14, 1.14), 0.1)
	t.tween_property(earn_label, "scale", Vector2.ONE, 0.14)
	await t.finished


## Cada paso del contador: escribe la cifra y enciende las estrellas cuyo umbral
## se acabe de cruzar. `stars` acota cuántas pueden encenderse, para que las
## primas del último tramo no regalen una que no se ha ganado.
func _count_tick(v: float, stars: int, encendidas: Dictionary) -> void:
	var actual := int(round(v))
	earn_label.text = str(actual)
	while int(encendidas["n"]) < stars \
			and int(encendidas["n"]) < star_money.size() \
			and actual >= int(star_money[int(encendidas["n"])]):
		var idx := int(encendidas["n"])
		encendidas["n"] = idx + 1
		# La TERCERA lleva su propia entrada, más larga y con fogonazo.
		_pop_star(idx, idx == 2)


## Chapa flotante "+N" con su icono, que sale de la cifra grande y sube
## desvaneciéndose: es la que cuenta DE DÓNDE sale cada salto del contador.
func _money_chip(cantidad: int, icono: String) -> void:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 6)
	chip.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.process_mode = Node.PROCESS_MODE_ALWAYS
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.z_index = 5
	if ResourceLoader.exists(icono):
		var ic := TextureRect.new()
		ic.texture = load(icono)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(44, 44)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(ic)
	var l := Label.new()
	l.text = "+%d" % cantidad
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", Color(1, 0.94, 0.62))
	l.add_theme_color_override("font_outline_color", Color(0.28, 0.11, 0.03))
	l.add_theme_constant_override("outline_size", 10)
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		l.add_theme_font_override("font", negrita)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(l)
	results_panel.add_child(chip)
	# Nace sobre la cifra grande y sube desde ahí.
	var centro := earn_label.get_global_rect().get_center() \
		- results_panel.global_position
	# A la DERECHA de la cifra, no encima: subiendo por el centro, la chapa
	# cruzaba justo por delante de las estrellas y tapaba la que acababa de
	# encenderse.
	chip.position = centro + Vector2(72, -14)
	chip.modulate.a = 0.0
	chip.scale = Vector2(0.6, 0.6)
	var t := chip.create_tween().set_parallel(true)
	t.tween_property(chip, "modulate:a", 1.0, 0.14)
	t.tween_property(chip, "scale", Vector2.ONE, 0.26) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(chip, "position:y", chip.position.y - CHIP_RISE, 0.9) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(chip, "modulate:a", 0.0, 0.35).set_delay(0.55)
	t.chain().tween_callback(chip.queue_free)


## Anuncia las recetas recien desbloqueadas con una animacion, de una en una.
func _reveal_recipes(recipes: Array) -> void:
	if recipes.is_empty():
		return
	var overlay := ColorRect.new()
	overlay.name = "RecipeReveal"
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.z_index = 200
	$HUD.add_child(overlay)
	var fade := overlay.create_tween()
	fade.tween_property(overlay, "color:a", 0.66, 0.2)
	_show_next_recipe(overlay, recipes.duplicate())


func _show_next_recipe(overlay: ColorRect, queue: Array) -> void:
	for c in overlay.get_children():
		c.queue_free()
	if queue.is_empty():
		var out := overlay.create_tween()
		out.tween_property(overlay, "color:a", 0.0, 0.2)
		out.tween_callback(overlay.queue_free)
		return
	# La cola trae ids de receta (String) y potenciadores permanentes
	# recién conseguidos ({"perk": id}).
	var item: Variant = queue.pop_front()
	var is_perk: bool = item is Dictionary
	var id: String = str(item["perk"]) if is_perk else str(item)
	var data: Dictionary = PerkData.get_perk(id) if is_perk else RecipeData.get_recipe(id)
	var dark := Color(0.26, 0.16, 0.08)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var box := Control.new()
	# Con descripción el cartel crece: la ficha de una receta trae ahora un
	# párrafo de dos o tres renglones y con el alto de siempre se salía.
	var alto := 580.0
	if not is_perk and RecipeData.summary(id) != "":
		alto = 690.0
	box.custom_minimum_size = Vector2(470, alto)
	box.pivot_offset = Vector2(235, alto * 0.5)
	center.add_child(box)
	box.add_child(prep_board.make_nine_patch(PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 58.0
	vb.offset_top = 56.0
	vb.offset_right = -58.0
	vb.offset_bottom = -48.0
	vb.add_theme_constant_override("separation", 12)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(vb)

	var title := Label.new()
	title.text = "¡Nuevo potenciador!" if is_perk else "¡Nueva receta!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", dark)
	vb.add_child(title)

	var dish := TextureRect.new()
	dish.texture = load(str(data.get("icon", ""))) if is_perk \
			else RecipeData.get_dish_texture(id)
	dish.custom_minimum_size = Vector2(0, 250)
	dish.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dish.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dish.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(dish)

	var name_l := Label.new()
	name_l.text = data.get("name", id)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.add_theme_font_size_override("font_size", 30)
	name_l.add_theme_color_override("font_color", dark)
	vb.add_child(name_l)

	if is_perk:
		# El potenciador explica qué hace y llega con 1 uso de regalo.
		var desc := Label.new()
		desc.text = str(data.get("desc", ""))
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 20)
		desc.add_theme_color_override("font_color", Color(0.42, 0.3, 0.18))
		vb.add_child(desc)
		var gift := Label.new()
		gift.text = "Llévate 1 uso de regalo. Compra más en el Inventario."
		gift.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gift.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gift.add_theme_font_size_override("font_size", 18)
		gift.add_theme_color_override("font_color", Color(0.2, 0.45, 0.12))
		vb.add_child(gift)
	else:
		var lvl := int(data.get("level", 1))
		vb.add_child(prep_board.make_star_row(lvl, lvl, 34))
		# QUÉ HACE ESTA RECETA, aquí mismo: ganarla y no saber para qué sirve
		# obligaba a irse al recetario a buscarlo. El texto se DEDUCE de los
		# datos (`RecipeData.summary`), así que nunca se queda desfasado.
		var resumen := RecipeData.summary(id)
		if resumen != "":
			var desc := RichTextLabel.new()
			desc.bbcode_enabled = true
			desc.fit_content = true
			desc.scroll_active = false
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc.text = "[center]%s[/center]" % DialogueBox.format_keywords(resumen)
			desc.add_theme_font_size_override("normal_font_size", 19)
			desc.add_theme_font_size_override("bold_font_size", 19)
			desc.add_theme_color_override("default_color", Color(0.42, 0.3, 0.18))
			vb.add_child(desc)

	if not queue.is_empty():
		var counter := Label.new()
		# "Queda 1" en singular: con una sola receta pendiente ponía "Quedan 1".
		counter.text = ("Queda 1 más" if queue.size() == 1
				else "Quedan %d más" % queue.size())
		counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		counter.add_theme_font_size_override("font_size", 20)
		counter.add_theme_color_override("font_color", Color(0.5, 0.38, 0.22))
		vb.add_child(counter)

	var accept := Button.new()
	accept.text = "Aceptar"
	accept.custom_minimum_size = Vector2(210, 66)
	accept.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	prep_board.skin_button(accept)
	accept.add_theme_font_size_override("font_size", 26)
	accept.process_mode = Node.PROCESS_MODE_ALWAYS
	accept.pressed.connect(func() -> void: _show_next_recipe(overlay, queue))
	vb.add_child(accept)

	box.scale = Vector2(0.6, 0.6)
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "scale", Vector2.ONE, 0.35)
	tw.parallel().tween_property(box, "modulate:a", 1.0, 0.22)
	tw.tween_callback(func() -> void:
		var loop := box.create_tween().set_loops()
		loop.tween_property(box, "scale", Vector2(1.03, 1.03), 0.9).set_trans(Tween.TRANS_SINE)
		loop.tween_property(box, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE))


## El desglose YA NO VIVE EN EL CARTEL: `_restyle_results_panel` se lleva su
## `Scroll` a la hoja aparte (`detail_panel`), donde lo desplaza `TouchScroll`.
## Aquí quedaba el apaño de arrastrar por cualquier punto del pergamino, que
## buscaba `$HUD/ResultsPanel/VBox/Scroll` — un nodo que ya no está ahí, así que
## soltaba un error de get_node cada vez que se cerraba una jornada.
func _setup_results_scroll() -> void:
	# Con MOUSE_FILTER_STOP el panel se come el arrastre antes de que llegue
	# a los botones; PASS deja que ambos funcionen.
	results_panel.mouse_filter = Control.MOUSE_FILTER_PASS


func _build_breakdown() -> void:
	for child in breakdown_box.get_children():
		child.queue_free()

	var served := 0
	for r in client_reports:
		if r.satiety_eaten > 0:
			served += 1
	var header := Label.new()
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.26, 0.16, 0.08))
	header.text = "Clientes: %d · atendidos: %d" % [client_reports.size(), served]
	breakdown_box.add_child(header)

	# De dónde sale el dinero del turno: platos, propinas y las primas de cierre.
	# Primero lo que decide si el nivel se supera (platos + propinas) y luego,
	# separadas, las primas de cierre, que se suman DESPUÉS.
	_breakdown_note("Dinero base", money_earned)
	if tips_total > 0:
		_breakdown_note("Propinas", tips_total)
	if bonus_clients > 0 or bonus_time > 0:
		var extra := Label.new()
		extra.text = "— Extra —"
		extra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		extra.add_theme_font_size_override("font_size", 19)
		extra.add_theme_color_override("font_color", Color(0.55, 0.36, 0.12))
		breakdown_box.add_child(extra)
		if bonus_clients > 0:
			_breakdown_note("Por clientes sobrantes", bonus_clients)
		if bonus_time > 0:
			_breakdown_note("Por tiempo sobrante", bonus_time)

	for type in ["E", "A", "G"]:
		var reports: Array = []
		for r in client_reports:
			if r.type == type:
				reports.append(r)
		if reports.is_empty():
			continue

		# Cabecera del grupo: chapa de madera con la CARA del tipo de cliente.
		var head := _breakdown_header(type,
			"%s  x%d" % [TYPE_NAMES.get(type, type), reports.size()])

		var rows := VBoxContainer.new()
		rows.visible = false
		rows.add_theme_constant_override("separation", 6)
		for r in reports:
			rows.add_child(_breakdown_row(r))
		breakdown_box.add_child(head)
		breakdown_box.add_child(rows)
		var caret: Label = head.get_meta("caret")
		head.pressed.connect(func() -> void:
			rows.visible = not rows.visible
			caret.text = "▼" if rows.visible else "▶")


## Línea del desglose: "concepto  N 🪙", con la moneda del juego al final.
func _breakdown_note(concepto: String, cantidad: int) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var l := Label.new()
	l.text = "%s:  %d" % [concepto, cantidad]
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.34, 0.23, 0.12))
	row.add_child(l)
	var coin := TextureRect.new()
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture = load("res://assets/ui/moneda.png")
	coin.custom_minimum_size = Vector2(24, 24)
	row.add_child(coin)
	breakdown_box.add_child(row)


## Cabecera plegable de un tipo de cliente. Antes era un pergamino de 9-slice
## estirado a lo ancho del panel: con los rodillos fijos a 190 px por lado, el
## papel del centro quedaba aplastado y el conjunto se veia forzado. Ahora es
## una chapa lisa de madera con la CARA del cliente (el mismo icono del HUD),
## su nombre y un triangulo que dice si esta abierta.
##
## `mouse_filter = PASS` es importante: con STOP el boton se tragaba el
## arrastre y el ScrollContainer no podia desplazarse si el dedo caia sobre una
## cabecera, que es justo donde el jugador suele arrastrar.
func _breakdown_header(type: String, label_text: String) -> Button:
	var head := Button.new()
	head.custom_minimum_size = Vector2(0, 62)
	head.mouse_filter = Control.MOUSE_FILTER_PASS
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		head.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var plank := Panel.new()
	plank.set_anchors_preset(Control.PRESET_FULL_RECT)
	plank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plank.show_behind_parent = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.47, 0.33, 0.19)
	sb.border_color = Color(0.30, 0.20, 0.11)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	plank.add_theme_stylebox_override("panel", sb)
	head.add_child(plank)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12.0
	row.offset_right = -14.0
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(row)

	var face := TextureRect.new()
	# El desglose agrupa por TIPO (no por cliente concreto), asi que aqui la
	# cara hace de emblema del tipo y va siempre la misma.
	face.texture = load(CharacterData.head(
		CharacterData.who_for_type(type), CharacterData.MALE))
	face.custom_minimum_size = Vector2(46, 46)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(face)

	var name_l := Label.new()
	name_l.text = label_text
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 24)
	name_l.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	name_l.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.04))
	name_l.add_theme_constant_override("outline_size", 5)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_l)

	var caret := Label.new()
	caret.text = "▶"
	caret.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caret.add_theme_font_size_override("font_size", 22)
	caret.add_theme_color_override("font_color", Color(1, 0.88, 0.6))
	caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caret)
	# Cuelga de la fila, no del boton: se guarda en un meta para que quien
	# conecta el plegado pueda darle la vuelta al triangulo.
	head.set_meta("caret", caret)
	return head


## Fila de un cliente: iconos de platos comidos + dinero + propina.
func _breakdown_row(r: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var eaten: Array = r.eaten
	if eaten.is_empty():
		var none := Label.new()
		none.text = "—"
		none.add_theme_font_size_override("font_size", 22)
		none.add_theme_color_override("font_color", Color(0.45, 0.35, 0.25))
		row.add_child(none)
	else:
		var counts: Dictionary = {}
		var order: Array = []
		for id in eaten:
			if not id in counts:
				order.append(id)
			counts[id] = int(counts.get(id, 0)) + 1
		for id in order:
			row.add_child(_dish_count(id, counts[id]))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var penalty := int(r.get("penalty", 0))
	if penalty > 0:
		# Se fue sin probar nada: en vez del dinero se enseña lo que costo.
		var lost := _icon_amount("res://assets/ui/moneda.png", "-$%d" % penalty)
		for l in lost.find_children("*", "Label", true, false):
			l.add_theme_color_override("font_color", Color(0.72, 0.16, 0.12))
		row.add_child(lost)
		return row

	row.add_child(_icon_amount("res://assets/ui/moneda.png", "%d" % r.money))
	if r.tip > 0:
		row.add_child(_icon_amount("res://assets/ui/bolsa.png", "+$%d" % r.tip))
	return row


func _dish_count(id: String, count: int) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var ic := TextureRect.new()
	ic.texture = RecipeData.get_dish_texture(id)
	ic.custom_minimum_size = Vector2(44, 44)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(ic)
	if count > 1:
		var badge := Label.new()
		badge.text = "x%d" % count
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 22)
		badge.add_theme_color_override("font_color", Color(0.26, 0.16, 0.08))
		box.add_child(badge)
	return box


func _icon_amount(icon_path: String, text: String) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var ic := TextureRect.new()
	if ResourceLoader.exists(icon_path):
		ic.texture = load(icon_path)
	ic.custom_minimum_size = Vector2(30, 30)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(ic)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(0.3, 0.2, 0.1))
	box.add_child(l)
	return box


# ------------------------------------------------------------- salir del nivel

## Boton de salida, pegado al borde izquierdo bajo el reloj. Es una FLECHA de
## volver (boton_flecha_izq) en vez de un boton de texto: ocupa mucho menos,
## no compite con el HUD y se lee igual en cualquier idioma. Desaparece al
## terminar el nivel, donde manda el panel de resultados.
## Pide confirmacion: en la fase de preparacion se sale sin coste (se DEVUELVEN
## los usos de ingredientes ya descontados); en partida se avisa de la perdida.
## Boton de abandonar: DISEÑO PROPIO, pequeño y discreto — una chapa oscura
## con filo dorado. El tablon de madera del resto de botones pesaba demasiado
## para algo que no se toca casi nunca, y una flecha suelta no decia si vuelve
## al mapa, retrocede un paso o abandona la partida.
func _setup_exit_button() -> void:
	# En el tutorial no se puede abandonar: interfaz mínima, sin "Salir". En la
	# primera jornada de campaña tampoco (`no_exit` del puerto).
	if GameState.is_tutorial() or no_exit:
		return
	var b := Button.new()
	b.text = "Salir"
	# El tablón de madera de TODO el juego, no un recuadro propio: se había
	# quedado con un StyleBoxFlat suelto y era el único botón del juego que no
	# seguía el estilo. Algo más grande que antes (96×44) porque el 9-slice
	# encoge su marco en los botones pequeños y la madera no se leía.
	b.custom_minimum_size = Vector2(112, PrepBoard.SMALL_H)
	b.size = Vector2(112, PrepBoard.SMALL_H)
	b.position = Vector2(16, 112 + GameState.safe_top())
	# Botón PEQUEÑO con su textura propia: con `skin_button` el margen 9-slice
	# se encogía a 20 téxeles y partía por la mitad el tope redondo del tablón.
	PrepBoard.skin_small_button(b)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(_on_exit_pressed)
	$HUD.add_child(b)
	exit_button = b


# ------------------------------------------------- cabezas de los clientes

## Fila de cabezas justo ENCIMA de la cinta de la mesa de trabajo: de un
## vistazo se ve QUIEN hay en la barra sin recorrer el 3D con la mirada. Los
## iconos salen de los propios modelos 3D (tools/head_icons.gd).
func _setup_heads_row() -> void:
	heads_row = HBoxContainer.new()
	heads_row.alignment = BoxContainer.ALIGNMENT_CENTER
	heads_row.add_theme_constant_override("separation", 10)
	heads_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heads_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	# JUSTO encima de la cinta: mas arriba quedaba flotando en medio del 3D y
	# costaba relacionarlo con la barra.
	heads_row.offset_top = -588.0 - HEAD_ICON - 4.0
	heads_row.offset_bottom = -588.0 - 4.0
	$HUD.add_child(heads_row)
	_update_client_heads()


## Una cabeza por TIPO presente, con "xN" cuando hay varios. Se llama al
## sentarse y al marcharse un cliente, asi que la fila sigue a la barra.
func _update_client_heads() -> void:
	if heads_row == null:
		return
	for c in heads_row.get_children():
		c.queue_free()
	# Cuenta por TIPO, sin separar por genero: la fila dice CUANTOS grumetes,
	# piratas y capitanes hay, y separarlos en dos caras por cada tipo llenaba
	# la fila de iconos para no decir nada nuevo. La cara de cada tipo es la del
	# primero que llego (`head_gender`), y ahi se queda toda la partida.
	# LOS CLIENTES ESPECIALES VAN EN SU PROPIA CHAPA, aparte del recuento de su
	# tipo. Antes su cara se colaba en la insignia del tipo (era la del primero
	# que llegó), así que en la Isla de Gades TODOS los piratas de la fila salían
	# con la cara de Cai y parecía un error del juego. Ahora Cai —y Pablo, y el
	# Kappa— tienen su propio icono al lado del de los suyos.
	var counts := { "E": 0, "A": 0, "G": 0 }
	var propios: Array[String] = []
	for c in seat_clients:
		if c == null or not is_instance_valid(c):
			continue
		if str(c.who_override) != "":
			if not (str(c.who_override) in propios):
				propios.append(str(c.who_override))
			continue
		counts[c.client_type] = int(counts.get(c.client_type, 0)) + 1
	for type in ["E", "A", "G"]:
		if int(counts[type]) > 0:
			heads_row.add_child(_head_badge(
				CharacterData.who_for_type(type),
				str(head_gender.get(type, CharacterData.MALE)), int(counts[type])))
	for quien in propios:
		heads_row.add_child(_head_badge(quien, CharacterData.MALE, 1))


## Icono de cabeza con su contador. El "xN" va DEBAJO y superpuesto sobre el
## borde inferior de la cara: al lado, la fila se ensanchaba y se separaba del
## grupo de caras.
func _head_badge(who: String, gender: String, count: int) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(HEAD_ICON, HEAD_ICON)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = load(CharacterData.head(who, gender))
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(ic)
	if count > 1:
		var l := Label.new()
		l.text = "x%d" % count
		l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		l.offset_top = -24.0
		l.offset_bottom = 6.0
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 25)
		l.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 9)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
	return box


func _on_exit_pressed() -> void:
	if results_shown or ended:
		return
	var was_paused := get_tree().paused
	get_tree().paused = true

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.z_index = 150
	$HUD.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := Control.new()
	box.custom_minimum_size = Vector2(500, 360)
	center.add_child(box)
	box.add_child(prep_board.make_nine_patch(PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 56.0
	vb.offset_top = 44.0
	vb.offset_right = -56.0
	vb.offset_bottom = -46.0
	vb.add_theme_constant_override("separation", 16)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(vb)

	# Rótulo GRANDE dentro del propio panel (sin cinta): el cartel es corto y
	# una tela con una frase larga pesaba más que la pregunta.
	var titulo := PrepBoard.make_big_title("¿Salir?", 66)
	titulo.custom_minimum_size = Vector2(0, 86)
	vb.add_child(titulo)

	var msg := Label.new()
	# El aviso dice EXPRESAMENTE qué pasa con el saco de arroz, que es lo caro:
	# en preparación se devuelve entero, y en marcha ya está gastado.
	msg.text = "Aún estás preparando: recuperarás los ingredientes y el saco de arroz." \
		if prep_phase \
		else "¡La partida está en marcha!\nPerderás los ingredientes gastados y el saco de arroz."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 22)
	msg.add_theme_color_override("font_color", Color(0.42, 0.3, 0.18))
	vb.add_child(msg)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 20)
	vb.add_child(btns)
	var quit := Button.new()
	quit.text = "Salir"
	quit.custom_minimum_size = Vector2(186, 66)
	# Rojo con aspa: es la opción que echa atrás la partida.
	prep_board.skin_action_button(quit, false)
	quit.add_theme_font_size_override("font_size", 24)
	quit.pressed.connect(_confirm_exit)
	btns.add_child(quit)
	var stay := Button.new()
	stay.text = "Seguir"
	stay.custom_minimum_size = Vector2(186, 66)
	# Verde con visto: seguir jugando es la opción que confirma.
	prep_board.skin_action_button(stay, true)
	stay.add_theme_font_size_override("font_size", 24)
	stay.pressed.connect(func() -> void:
		get_tree().paused = was_paused
		overlay.queue_free())
	btns.add_child(stay)


func _confirm_exit() -> void:
	# En la fase de preparacion la salida es gratis: se devuelve TODO lo que se
	# descuento al empezar el nivel (usos de ingredientes, potenciadores
	# permanentes Y EL SACO DE ARROZ). Aun no se ha jugado nada, asi que no se
	# pierde nada; la fase dura 10 s, asi que el margen es justo ese. En cuanto
	# entra el primer cliente, el saco ya esta gastado.
	if prep_phase and GameState.is_adventure():
		for ing in GameState.ingredients_for_selection(GameState.selected_recipes):
			GameState.add_ingredient_uses(ing, 1)
		for perk in GameState.selected_perks:
			GameState.add_perk_uses(perk, 1)
		GameState.add_rice(1)
	# Se guarda aunque se abandone: el rato jugado hasta aquí cuenta igual.
	GameState.save_game()
	get_tree().paused = false
	if GameState.is_adventure():
		GameState.transition = "mapa"
	GameState.fade_to_scene("res://scenes/main_menu.tscn", 0.35, 0.45)


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


## "Siguiente" devuelve al MAPA de la campaña (no al menú principal), que es
## desde donde se elige el puerto siguiente. (La visita guiada a la tienda ya no
## se dispara aquí: la lleva el mapa, en `main_menu._presentar_saverio`.)
func _on_menu_pressed() -> void:
	get_tree().paused = false
	if GameState.is_adventure():
		GameState.transition = "mapa"
	GameState.fade_to_scene("res://scenes/main_menu.tscn", 0.35, 0.45)


## Copia del estilo del botón con unos píxeles de margen arriba, para bajar el
## texto hasta el centro real del tablón.
func _button_pad(b: Button, estado: String) -> StyleBox:
	var sb: StyleBox = b.get_theme_stylebox(estado)
	var out: StyleBox = sb.duplicate() if sb != null else StyleBoxEmpty.new()
	out.content_margin_top = 10.0
	out.content_margin_bottom = 0.0
	return out


## Coloca la barra superior segun lo que haya que enseñar. Sin reloj (islas,
## puertos y tutorial) el hueco de la izquierda queda vacio, asi que se pone un
## relleno del ANCHO del contador de clientes: el oro se queda centrado en la
## pantalla de verdad y la fila no se descuelga hacia un lado.
func _apply_hud_layout() -> void:
	var top: HBoxContainer = $HUD/TopRow
	var caja_reloj: Control = $HUD/TopRow/TimeBox
	caja_reloj.visible = timed
	# El lienzo puede cambiar de ancho después del arranque (ventana redimensionada,
	# rotación en móvil): sin esto el cuerpo del contador se quedaba con la medida
	# del primer fotograma y "120/120" salía cortado.
	if not get_viewport().size_changed.is_connected(_fit_top_row):
		get_viewport().size_changed.connect(_fit_top_row)
	# Sin potenciadores (la escuela), el BOTE entero desaparece del marcador:
	# una barra azul que nunca sube solo generaría preguntas.
	if tip_bar != null and is_instance_valid(tip_bar) \
			and tip_bar.get_parent() != null:
		tip_bar.get_parent().visible = not no_powerups
	if timed:
		if time_gap != null:
			time_gap.visible = false
		_fit_top_row.call_deferred()
		return
	if time_gap == null:
		time_gap = Control.new()
		time_gap.name = "TimeGap"
		time_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(time_gap)
		top.move_child(time_gap, 0)
	time_gap.visible = true
	# La primera medida NO puede tomarse aquí: en el _ready los contenedores aún
	# no han colocado a nadie y todo mide 0. Y si el nivel arranca con un guion
	# hablando, el árbol está en pausa y `_update_hud` no corre, así que el hueco
	# se quedaría a cero toda la presentación.
	_fit_top_row.call_deferred()


## Ajusta el relleno al ancho real del contador de clientes, un fotograma
## después (los contenedores de Godot recolocan a sus hijos de forma diferida).
func _medir_hueco() -> void:
	await get_tree().process_frame
	if time_gap != null and is_instance_valid(time_gap):
		time_gap.custom_minimum_size.x = clients_label.get_parent().size.x


## Cuerpos de letra del contador de clientes, de mayor a menor. El de diseño es
## 42, pero la fila de arriba NO SIEMPRE CABE: en un nivel sin reloj el relleno
## `time_gap` copia el ancho del contador, así que cada píxel del contador
## cuesta DOS. Con dos cifras a cada lado ("10/10", "17/17") la suma de mínimos
## igualaba JUSTO el ancho disponible, y en cuanto el lienzo es un poco más
## estrecho el contador sale cortado ("10/1").
const CLIENTS_FONTS := [42, 38, 34, 30, 26, 23, 20]

## Última medida aplicada (ancho de la fila, clientela): ver `_update_hud`.
var _row_fit_key := Vector2i(-1, -1)


## Elige el cuerpo más grande con el que la fila entra ENTERA, midiendo el peor
## texto posible del nivel ("N/N" con toda la clientela).
##
## SE REMIDE, no se decide una vez: la primera pasada del `_ready` corre con el
## lienzo aún asentándose (y en el tutorial, con un `total_clients` que el guion
## cambia después a 120), así que un único cálculo temprano elegía un cuerpo que
## luego NO cabía y el contador salía cortado por la derecha. Por eso espera DOS
## fotogramas (los contenedores recolocan en diferido) y se vuelve a llamar
## desde `size_changed` del viewport.
func _fit_top_row() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var top: HBoxContainer = $HUD/TopRow
	var caja: Control = clients_label.get_parent()
	var peor := "99" if unlimited else "%d/%d" % [total_clients, total_clients]
	var fuente := clients_label.get_theme_font("font")
	# Lo que ocupa TODO lo demás de la fila (sin el contador ni su relleno).
	var resto := float(top.get_theme_constant("separation")) \
			* float(maxi(top.get_child_count() - 1, 0))
	for h in top.get_children():
		if h is Control and h.visible and h != caja and h != time_gap:
			resto += h.get_combined_minimum_size().x
	# El contador cuenta DOBLE cuando hay relleno (lo copia para centrar el oro).
	var veces := 2.0 if (time_gap != null and time_gap.visible) else 1.0
	var sep_caja := float(caja.get_theme_constant("separation"))
	for cuerpo in CLIENTS_FONTS:
		var ancho: float = fuente.get_string_size(peor,
			HORIZONTAL_ALIGNMENT_LEFT, -1, cuerpo).x
		var icono := 58.0 * float(cuerpo) / 42.0
		var cabe: bool = resto + (icono + sep_caja + ancho) * veces <= top.size.x
		if cabe or cuerpo == int(CLIENTS_FONTS[CLIENTS_FONTS.size() - 1]):
			clients_label.add_theme_font_size_override("font_size", cuerpo)
			var ic: Control = caja.get_child(0)
			ic.custom_minimum_size = Vector2(icono, icono)
			break
	_medir_hueco()


func _update_hud() -> void:
	# El cuerpo del contador se REVISA cada vez que cambia el ancho de la fila o
	# la clientela del nivel. La medida diferida del arranque llega con el lienzo
	# todavía asentándose (y en el tutorial, antes de que el guion suba el total a
	# 120), así que decidirlo una sola vez dejaba "120/120" cortado por la derecha.
	var clave := Vector2i(int($HUD/TopRow.size.x), total_clients)
	if clave != _row_fit_key:
		_row_fit_key = clave
		_fit_top_row()
	if timed:
		var remaining := maxf(time_limit - elapsed, 0.0)
		time_label.text = "%d:%02d" % [int(remaining) / 60, int(remaining) % 60]
	elif time_gap != null:
		# El relleno sigue al ancho real del contador de clientes: con "0/10" y
		# con "10/10" el oro tiene que quedarse en el mismo sitio.
		time_gap.custom_minimum_size.x = clients_label.get_parent().size.x
	var meta := int(star_money.back())
	var umbral := _tip_threshold(powerups_claimed)
	if money_bar != null:
		money_bar.max_value = maxf(meta, 1)
		money_bar.value = clampf(_score_money(), 0, meta)
		tip_bar.max_value = maxf(umbral, 1)
		tip_bar.value = clampf(tips_total, 0, tip_bar.max_value)
		_place_bar_value(money_bar, money_label, money_meta, _score_money(), meta)
		_place_bar_value(tip_bar, jar_label, tip_meta, tips_total, umbral)
		_place_star_marks()
	# Cuenta los que YA HAN VENIDO, no los que se han ido: con los idos el
	# marcador se quedaba en 0 con la barra llena, que es justo cuando el
	# jugador quiere saber cuánta clientela le queda por llegar. En los
	# abordajes no hay cupo, así que se enseña solo cuántos han pasado.
	clients_label.text = "%d" % clients_spawned if unlimited \
			else "%d/%d" % [clients_spawned, total_clients]
