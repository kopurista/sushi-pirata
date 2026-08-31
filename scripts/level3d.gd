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
## Los que YA SE HAN SENTADO. Es lo que enseña el contador del HUD y lo que
## cuenta la fila de cabezas: contando desde que APARECEN, un cliente que
## todavía venía andando ya salía en la cuenta y se leía como si estuviera
## atendido — y en el nivel 1, con David explicando que a veces dejan pasar un
## plato, el jugador miraba al que aún caminaba en vez de al que lo despreció.
var clients_seated := 0
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
## SILLAS FORZADAS para los primeros clientes (`first_seats` del puerto).
## El nivel 1 sienta al primero en la SEGUNDA silla y al segundo en la
## primera: asi el jugador ve que la cinta reparte por orden de paso y no
## por orden de llegada, que es la primera intuicion que hay que romper.
var first_seats: Array = []
## EL GUION PUEDE FORZAR UN DESPRECIO. El nivel 1 lo usa para enseñar el
## dado de coger plato: el jugador tiene que VER a un cliente dejar pasar
## algo antes de que David le cuente que eso puede ocurrir. Puesto a true,
## el siguiente plato que un cliente fuera a coger se rechaza (una sola
## vez) y el nivel avisa por `plato_ignorado` con la posicion del plato,
## para que el guion pueda ponerle el foco encima antes de que siga su
## camino.
var forzar_desprecio := false
## Lleva el PLATO y no su posición: entre el desprecio y el momento en que
## David lo cuenta, el plato SIGUE VIAJANDO, así que con una posición
## congelada el foco caía donde el plato ya no estaba.
signal plato_ignorado(plato: Node3D)
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
## Respiro ANTES de abrir el cartel de potenciador. Se pone al ganar uno y
## corre en `_process`: sin él, `_add_tip` abría el cartel EN LA MISMA llamada
## en que sumaba la propina, el cartel pausaba el árbol y `_update_hud` nunca
## llegaba a pintar la barra — el jugador veía saltar el premio con el bote a
## medio llenar. Con el respiro, primero se VE la barra llegar y luego sale.
var powerup_delay := 0.0
var aroma_active := false
var tip_chance_bonus := 0.0
var tip_amount_mult := 1.0
var belt_mult := 1.0
## HÁNDICAP DE ISLA DEL MAR 3: platos como mucho a la vez en la cinta (0 = sin
## tope). Con el tope alcanzado, la tabla no deja servir y el plato espera.
var cinta_max := 0
## Cuántos caben cuando el hándicap está puesto. Son SEIS y no ocho: con ocho
## (uno por asiento) el tope no se alcanzaría nunca y el hándicap no existiría.
const CINTA_MAX_ISLA := 6
# ----------------------------- EL VIENTO (mar 2) -----------------------------
# Un vendaval que OSCILA: la velocidad sube y baja hacia objetivos sorteados, y
# para cambiar de sentido tiene que pasar por 0 (nunca salta de izquierda a
# derecha en seco). Cuando sopla HACIA LA IZQUIERDA y pasa del umbral, LA CINTA
# SE INVIERTE — con una transición en la que se va frenando hasta pararse y
# arranca al revés. El viento hacia la derecha, por fuerte que sople, no toca
# la cinta (es su sentido natural). Todo sorteado por partida: nunca hay dos
# jornadas con el mismo viento (pedido por el usuario).

## ¿Este nivel lleva viento? (campo `viento` del puerto, mar 2).
var wind_on := false
## Velocidad que marca el anemómetro, en km/h.
var wind_kmh := 0.0
## Sentido del viento: +1 derecha (natural), -1 izquierda (el peligroso).
var wind_dir := 1
## Objetivo de la racha en curso y pausa entre rachas.
var wind_target := 0.0
var wind_dwell := 0.0
var wind_rate := 10.0
## Umbral que invierte la cinta y techo del anemómetro POR TIPO de escenario
## (isla suave, puerto media, abordaje fuerte): el jugador aprende el viento
## poco a poco, como los hándicaps.
const WIND_UMBRAL := 40.0
var wind_max := 46.0
## Direccion EFECTIVA de la cinta (-1..1): es la que se anima. `belt_dir` pasa
## por 0 en cada giro — la cinta se frena, se para y arranca al revés.
var belt_dir := 1.0
var belt_dir_objetivo := 1.0
## Segundos que tarda el giro completo de la cinta (1 → -1).
const BELT_TURN_T := 1.7
## El "!" del aviso ya ha saltado en esta subida (se rearma al aflojar).
var _wind_avisado := false
## HUD del viento.
var wind_label: Label = null
var wind_warn: Label = null
var _banderin_mat: ShaderMaterial = null
var _cinta_aviso: Label = null
## Velocidad BASE de la cinta a la que vuelve belt_mult al expirar el
## potenciador. El arcade la toca (estorbo "la cinta acelera" y la mejora "la
## cinta va más despacio"); fuera del arcade es 1 y todo queda como siempre.
var belt_base := 1.0
var patience_mult := 1.0
var belt_timer := 0.0
var tip_chance_timer := 0.0
var tip_amount_timer := 0.0

# --- Maestrías del cocinero: efectos del NIVEL (ver skill_data.gd) ---
## "Segunda vuelta": vueltas de los platos, castigo del cubo y si cada vuelta
## nueva borra los rechazos. Neutros sin la habilidad.
var plate_laps := 1
var plate_forget_lap := false
var waste_frac := WASTE_PENALTY
## Experiencia pagada por esta jornada (la enseña el cartel de resultados).
var last_xp := 0
## De esa experiencia, cuánta es PRIMA por el oro de más (para el cartel).
var last_xp_extra := 0

# --- ARCADE SIN FIN (GameState.is_arcade(); ver el documento del modo) ---
## Oleadas de WAVE_TIME segundos. Se pierde a los VACIOS_MAX clientes que se
## van sin probar bocado, o cuando la despensa deja la carta vacía y los
## vacíos llegan solos. Cada oleada cuesta 1 uso de cada ingrediente de la
## carta; cada 3 hay carta de mejora; cada 10, un estorbo permanente avisado
## una oleada antes.
const WAVE_TIME := 45.0
## La barra del oro no tiene objetivo en el arcade: es un hito que se renueva
## cada vez que se alcanza (y su estrella brilla, que cruzar hitos alegra).
const ARCADE_META_STEP := 150
const VACIOS_MAX := 3
## Segundos de reloj que roba cada vacío en un ABORDAJE.
const CASTIGO_VACIO_SEG := 15.0
var arcade := false
var wave := 1
var wave_t := 0.0
var next_spawn := 0.0
## Hueco entre llegadas de la oleada 1; el pellizco lo comprime un 2% por
## oleada (las sillas libres son el tope natural del aluvión).
var arcade_spawn_gap := 11.0
## Carta VIGENTE del arcade: los fichajes la agrandan y los ingredientes
## agotados la encogen (las recetas caídas se quedan apagadas en la fila).
var carta: Array[String] = []
## Estorbos ya aplicados (se sortean sin repetir) y el anunciado para la
## próxima decena.
var estorbos_usados: Array[String] = []
var estorbo_anunciado := ""
## El estorbo del fogón: cada FOGON_EVERY s una receta se apaga un rato.
const FOGON_EVERY := 40.0
const FOGON_OFF := 12.0
var fogon_activo := false
var fogon_t := 0.0
## Mejoras de partida pendientes de elegir (cada 3 oleadas cae una).
var pending_upgrades := 0
## Mejoras NO repetibles ya cogidas (no vuelven a salir en el sorteo).
var upgrades_cogidas: Array[String] = []
## Postres con el cobro del multiplicador doblado toda la partida (mejora).
var dessert_boost_perm := false
## Postres que PAGAN doble su precio: no existe (regla del modo: ninguna
## mejora toca el precio de los platos).
## Fila del HUD del arcade: oleada, despensa restante y vacíos.
var arcade_row: HBoxContainer = null
var oleada_label: Label = null
var despensa_label: Label = null
var vacios_label: Label = null

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
## Dónde cayó el último plato al cubo (el guion del nivel 1 lo enfoca).
var trash_pos := Vector3.ZERO
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
## Igual, pero reservando por TIPO de cliente (`exclusive_types` del puerto).
var exclusive_types: Dictionary = {}
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

## CONTADORES DE MAESTRÍA del HUD, bajo el número de clientes. Las tres
## habilidades deterministas del cocinero ("cada N platos, el siguiente sale
## gratis / doble / con suerte") son CONTADOR y no dado justamente para poder
## planearlas, y planear con un número escondido no se puede: aquí se ve
## cuántos platos faltan, con el icono de la habilidad al lado.
## El del "golpe de vista" vivía clavado en una esquina de la tabla; se movió
## aquí para que los tres estén juntos y en el mismo sitio.
const SKILL_COUNTERS := ["golpe_vista", "cocina_abundante", "golpe_suerte"]
var skill_counter_row: HBoxContainer = null
## id -> Label de la cifra, y lo último que se pintó (para no repintar por frame).
var _skill_chip: Dictionary = {}
## Tweens del TEMBLOR de cada chip (ver `_vibrar_chip`), aparte del latido del
## "¡YA!": uno anima el chip y el otro la cifra, y matarlos juntos dejaba al
## chip torcido.
var _skill_shake: Dictionary = {}
var _skill_drawn: Dictionary = {}
var _skill_tween: Dictionary = {}
## Relleno que ocupa el hueco del reloj en los niveles que no lo llevan, para
## que el oro siga cayendo en el centro de la pantalla (ver _apply_hud_layout).
var time_gap: Control = null
@onready var phase_label: Label = $HUD/PhaseLabel
@onready var prep_board: Control = $HUD/PrepBoard
@onready var powerup_panel: Panel = $HUD/PowerupPanel
## OJO: es un `BoxContainer` PELADO y no un VBox, porque el cartel cambia de
## orientacion (`_montar_cartel_potenciadores`): VBoxContainer y HBoxContainer
## llevan la suya CLAVADA (`is_fixed`) y `vertical = ...` falla en ellos.
@onready var powerup_options: BoxContainer = $HUD/PowerupPanel/VBox/Options
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
## HÁNDICAPS POR TIPO (solo aventura, nunca en el tutorial ni en el arcade):
## en un PUERTO, 3 clientes que se van sin comer pierden el escenario; en un
## ABORDAJE, cada vacío resta CASTIGO_VACIO_SEG al reloj. En los dos, el vacío
## NO cuesta oro (el castigo en doblones queda para las islas): el jugador ya
## pierde por la vía principal de su tipo.
var vacio_pierde := false
var vacio_roba_reloj := false
var lost_by_leavers := false
## Fila de las tres CALAVERAS del contador de vacíos (fue un Label con el
## texto "Vacíos N/3"; el guion del hándicap le pone el foco, y para eso le
## vale cualquier Control).
var vacios_puerto_label: Control = null


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
		# EL VIENTO lo declara el puerto (aparcado para el MAR 3; el codigo
		# entero se queda esperando a que un puerto vuelva a declararlo).
		wind_on = bool(port_cfg_viento())
		if wind_on:
			match scenery_kind:
				"isla":
					wind_max = 46.0
				"puerto":
					wind_max = 52.0
				_:
					wind_max = 60.0
		# EL CANTO DE SIRENA lo declara el puerto (mar 2). La frecuencia y el
		# largo del canto los pone el TIPO, como la intensidad del viento:
		# isla suave, puerto media, abordaje fuerte (alli ademas hay reloj y
		# cada canto se come un trozo del turno).
		canto_on = bool(CampaignData.get_port(GameState.current_port) 				.get("sirena", false)) and not GameState.is_tutorial()
		if canto_on:
			match scenery_kind:
				"isla":
					canto_gap = Vector2(46.0, 70.0)
					canto_dur = Vector2(6.0, 9.0)
				"puerto":
					canto_gap = Vector2(34.0, 55.0)
					canto_dur = Vector2(8.0, 12.0)
				_:
					canto_gap = Vector2(26.0, 42.0)
					canto_dur = Vector2(10.0, 14.0)
			canto_espera = randf_range(16.0, 28.0)
		# LOS CASTIGOS POR VACÍO EMPIEZAN EN EL MAR 2 (pedido por el usuario):
		# el mar 1 es la escuela y allí un cliente que se va sin comer no
		# cuesta nada — ni oro en la isla, ni calavera en el puerto, ni reloj
		# en el abordaje. El TUTORIAL va aparte: su marcador del caos necesita
		# los castigos de oro y los conserva (ver client3d.penaliza_vacio).
		if not GameState.is_tutorial() \
				and CampaignData.sea_of(GameState.current_port) >= 2:
			vacio_pierde = scenery_kind == "puerto"
			vacio_roba_reloj = scenery_kind == "abordaje"
		# LOS HÁNDICAPS DEL MAR 3 SE SUMAN A LOS DEL 2 (cada mar aprieta por
		# su lado, y el TIPO sigue mandando cuál te toca):
		#  · ISLA     → la cinta tiene TOPE de platos (`cinta_max`): producir
		#               a lo loco deja de valer, hay que elegir qué sale.
		#  · PUERTO   → NO se pueden hacer dos recetas iguales seguidas
		#               (`sin_repetir`): la carta hay que rotarla de verdad.
		#  · ABORDAJE → la cinta va al DOBLE (`belt_base` 2.0): el plato pasa
		#               por delante de cada boca la mitad de tiempo, así que
		#               fallar el sitio se paga.
		if not GameState.is_tutorial() \
				and CampaignData.sea_of(GameState.current_port) >= 3:
			match scenery_kind:
				"isla":
					cinta_max = CINTA_MAX_ISLA
				"puerto":
					prep_board.sin_repetir = true
				"abordaje":
					belt_base = 2.0
					belt_mult = maxf(belt_mult, belt_base)
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
	_musica_del_nivel()
	# EL MAR SIGUE SONANDO EN EL NIVEL, aún más bajo que en el menú: aquí
	# hay una cocina entera por delante y el fondo no puede robarle sitio.
	Audio.ambiente("mar", 1.5, AMB_NIVEL)

	seat_clients.resize(seats.size())
	prep_board.dish_served.connect(_on_player_dish_served)
	prep_board.craft_event.connect(_on_craft_event)
	prep_board.money_penalty.connect(_on_money_penalty)
	# Un corte fallado es un "error" que rompe la cadena del SUSHI RUSH.
	prep_board.money_penalty.connect(func(_c: int) -> void: note_rush_fail())
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
		first_seats = (port.get("first_seats", []) as Array).duplicate()
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
		# `boat_lesson`: el guion ESTRENA el barco (Nach en m2_18), así que el
		# botón sale aunque el bonificador todavía no se tenga — la lección es
		# justo esa.
		prep_board.hide_boat = not (bool(port.get("boat", false)) \
				and (GameState.has_perk("barco")
					or bool(port.get("boat_lesson", false))))
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
		# Y TAMBIÉN sin guion propio, si está pendiente explicar los CONTADORES
		# DE MAESTRÍA: esas habilidades se compran cuando al jugador le da la
		# gana, así que su explicación no se puede colgar de ningún escenario.
		# En ese caso el director se monta solo para eso y se va.
		var toca_contadores: bool = not GameState.skill_counters_intro_done \
				and not GameState.is_tutorial() \
				and not GameState.skills.is_empty()
		# Y un puerto con CLIENTE DEL TESORO monta director SIEMPRE, narrado o
		# no: es quien canta el encargo al sentarse, y sin esa frase la pieza
		# saldría por cumplir una condición que nadie ha dicho en voz alta.
		var hay_tesoro: bool = not (port.get("collectible_client", {}) as Dictionary).is_empty()
		# Y el HÁNDICAP del tipo: el primer puerto y el primer abordaje de la
		# partida lo explican aunque el escenario no tenga guion propio.
		var toca_handicap: bool = not GameState.is_tutorial() 				and CampaignData.sea_of(GameState.current_port) >= 2 and (
			(scenery_kind == "isla" and not GameState.isla_handicap_done)
			or (scenery_kind == "puerto" and not GameState.puerto_handicap_done)
			or (scenery_kind == "abordaje" and not GameState.abordaje_handicap_done))
		# El guion de MIKU (m2_14) corre TAMBIEN en repeticiones mientras el
		# SUSHI RUSH no se haya aprendido: su barco solo se puede servir
		# volviendo con el bonificador puesto, y sin escena no habria trato.
		var miku_pendiente: bool = str(port.get("director", "")) == "mar2_miku" 				and not GameState.sushi_rush_unlocked
		if (str(port.get("director", "")) != "" 				and (not ya_narrado or boss_id != "" or miku_pendiente)) 				or toca_contadores or toca_handicap or hay_tesoro:
			var guia := preload("res://scripts/level_director.gd").new()
			guia.name = "LevelDirector"
			add_child.call_deferred(guia)
			# Platos que en la PRIMERA pasada solo come el cliente especial:
			# el tsuke don es el regalo de David para Pablo, y servírselo a un
			# grumete le quitaría la gracia a la escena. Al repetir el puerto
			# ya no hay guion y el plato vale para todo el mundo.
			if not ya_narrado:
				exclusive_dishes = port.get("exclusive_dishes", {})
				exclusive_types = port.get("exclusive_types", {})
		# Jugar un nivel consume 1 uso de cada ingrediente de las recetas
		# elegidas; si no alcanzan, vuelta a la seleccion.
		if not GameState.consume_ingredients_for_level(GameState.selected_recipes):
			get_tree().change_scene_to_file.call_deferred("res://scenes/prep_screen.tscn")
			return
		# Los potenciadores permanentes elegidos gastan 1 uso por partida.
		GameState.consume_perks_for_level()
	elif GameState.is_arcade():
		# ARCADE SIN FIN: una jornada de verdad, no una prueba. Cobra su saco
		# de arroz y la primera oleada de despensa al zarpar, y se juega con
		# todo puesto: maestrías, bonificadores y sus usos gastados.
		arcade = true
		timed = false
		unlimited = true
		total_clients = 0
		star_money = [ARCADE_META_STEP]
		carta = GameState.selected_recipes.duplicate()
		client_weights = _arcade_weights()
		if not GameState.consume_ingredients_for_level(GameState.selected_recipes):
			get_tree().change_scene_to_file.call_deferred("res://scenes/prep_screen.tscn")
			return
		GameState.consume_perks_for_level()
		_setup_arcade_hud()
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
	if arcade:
		# Las llegadas del ARCADE las gobierna _tick_arcade (continuas, con el
		# pellizco por oleada): el horario clásico aquí duplicaría la clientela.
		pass
	elif unlimited:
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
	# MAESTRÍAS que viven en el nivel (las de la tabla las lee prep_board y las
	# del cliente cada client3d; en el tutorial todo queda en neutro).
	if not GameState.is_tutorial():
		plate_laps = maxi(int(GameState.skill_value("segunda_vuelta")), 1)
		# EN EL MAR 1 EL PLATO AGUANTA DOS VUELTAS (pedido por el usuario): la
		# escuela perdona, y del mar 2 en adelante cae en la primera. La
		# maestría "Segunda vuelta" sigue sumando por encima de eso.
		if CampaignData.sea_of(GameState.current_port) < 2:
			plate_laps += 1
		plate_forget_lap = GameState.skill_rank("segunda_vuelta") >= 4
		waste_frac = GameState.skill_aux("segunda_vuelta", "waste",
			WASTE_PENALTY * 100.0) / 100.0


## Avatar del ayudante: solo aparece si se ha activado su potenciador. Va al
## OTRO lado del chef, mirando como él. Ojo con la X: el mostrador de la cinta
## ocupa de -2.35 a -1.25, así que el interior libre del circuito va de -1.25 a
## 1.25 — con x=-1.42 el ayudante salía metido dentro del mostrador.
func _setup_helper() -> void:
	var h_pos := Vector3(0.72, 0.0, -0.60)
	helper_pivot = _spawn_model(
		load(CharacterData.model("alice", CharacterData.FEMALE)),
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
	# TODOS pasan por `perk_gate_open`, que exige primero que los bonificadores
	# existan como sistema (llegan con Alice). `cocina_veloz` se quedó sin esa
	# comprobación y se ganaba desde el escenario 1, o sea antes de que nadie
	# hubiera explicado qué era un bonificador.
	if most >= PerkData.UNLOCK_PLATES_ONE_CLIENT \
			and GameState.perk_gate_open("cocina_veloz") \
			and GameState.unlock_perk("cocina_veloz"):
		newly.append("cocina_veloz")
	# El AYUDANTE es Alice, así que su puerto es justo el que abre el sistema:
	# sin esa escena, aparecería un muñeco en la cocina sin que nadie lo explique.
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
		# BORDAR EL ESCENARIO: cerrar con un 30% MAS de lo que piden las 3
	# estrellas. Es la unica condicion que no mira COMO has cocinado sino
	# CUANTO, asi que es la que premia exprimir un escenario ya aprendido.
	if not star_money.is_empty():
		var tope: float = float(star_money.back()) * PerkData.UNLOCK_XP_FRAC
		if float(_star_money()) >= tope \
				and GameState.perk_gate_open("experiencia") \
				and GameState.unlock_perk("experiencia"):
			newly.append("experiencia")
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
	# DENTRO DE LA CUEVA no entra el sol: fondo casi negro y un ambiente MUY
	# escaso, lo justo para que nada quede en negro puro. Quien ilumina de
	# verdad son los CRISTALES, cada uno con su OmniLight3D: si el ambiente
	# sube, sus charcos de luz dejan de verse y la cueva vuelve a parecer un
	# escenario con filtro azul.
	if scenery_kind == "cueva":
		env.background_color = Color(0.030, 0.040, 0.058)
		env.ambient_light_color = Color(0.50, 0.57, 0.68)
		env.ambient_light_energy = 0.90
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -125.0, 0.0)
	sun.light_energy = 1.45
	sun.light_color = Color(1.0, 0.97, 0.9)
	if scenery_kind == "cueva":
		# Una "luna de cueva" muy tenue y azulada: solo marca los relieves para
		# que la piedra no salga plana; la luz de trabajo la ponen los cristales.
		sun.light_energy = 0.38
		sun.light_color = Color(0.58, 0.68, 0.84)
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
	# La CUEVA es interior: nada de mar alrededor — suelo de roca hasta donde
	# alcanza la vista y paredes cerrando el fondo.
	if scenery_kind != "cueva":
		_add_sea()
	match scenery_kind:
		"cueva":
			_scenery_cueva()
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
	sea_mesh.subdivide_width = 36
	sea_mesh.subdivide_depth = 36
	sea.mesh = sea_mesh
	sea.position = Vector3(0.0, -0.55, 0.0)
	# Un plano de 90x90 bajo todo lo demas no proyecta ninguna sombra visible,
	# pero se dibujaba entero en el pase de sombras.
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water_ww.gdshader")
	mat.set_shader_parameter("espuma", load("res://assets/map/espuma_ww.webp"))
	mat.set_shader_parameter("tile", Vector2(90.0, 90.0))
	sea.material_override = mat
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
## LA CUEVA: la guarida de los jefes (el Kappa). Caverna de piedra oscura,
## cerrada por muros con su BOCA DE ENTRADA arriba, con estalagmitas y
## CRISTALES que brillan y ALUMBRAN de verdad. Todo con los modelos y helpers
## de siempre: rocas.glb entenebrecido y geometría por código para el resto
## (GeometryBatch la funde al final, como en los demás).
## COORDENADAS DE PANTALLA (u, w) PARA MONTAR LA CUEVA. La cámara es
## isométrica con yaw 45, así que los ejes del MUNDO no son los de la PANTALLA:
## a la derecha se va por (1,0,-1)/√2 (eje `u`) y hacia el fondo por
## -(1,0,1)/√2 (eje `w`, negativo = lejos = arriba en pantalla). Colocando los
## muros en coordenadas de mundo salían en diagonal y uno se metía en cuadro
## por abajo a la derecha, tapando la barra; en (u, w) el muro del fondo es una
## banda limpia en lo alto y los laterales, dos columnas en los cantos.
##
## El pasillo por el que pasean los clientes (el cuadrado de radio WALK_R) es
## en (u, w) un ROMBO: |u| + |w| = WALK_R·√2 ≈ 5.23. Todo el decorado va por
## fuera de 6.3 para no pisarlo.
func _uw(u: float, w: float) -> Vector3:
	return Vector3(0.70710678, 0.0, -0.70710678) * u \
		+ Vector3(0.70710678, 0.0, 0.70710678) * w


## Muro de cueva alineado con la PANTALLA: `size` es (ancho en u, alto, fondo
## en w), `base` la altura del pie y `tilt` el vuelco lateral — que es lo que
## saca a la roca de la escuadra: con todas las piezas a plomo, la cueva se lee
## como una fila de cajas.
func _muro_cueva(u: float, w: float, size: Vector3, tex: Texture2D, tinte: Color,
		base := -0.6, tilt := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = size
	mi.mesh = caja
	mi.position = _uw(u, w) + Vector3(0.0, base + size.y * 0.5, 0.0)
	mi.rotation_degrees = Vector3(0.0, 45.0, tilt)
	mi.material_override = _mat_piedra(tex, tinte, 0.45)
	add_child(mi)
	return mi


func _scenery_cueva() -> void:
	var suelo_tex: Texture2D = load("res://assets/props/piedra_cueva.webp")
	var pared_tex: Texture2D = load("res://assets/props/pared_cueva.webp")
	# SUELO de roca hasta donde alcanza la vista (aquí no hay mar). La textura
	# va GRANDE —una baldosa cada ~3 u— y de poco contraste a propósito:
	# estuvo a 6 repeticiones POR UNIDAD y en pantalla se leía como una rejilla.
	var suelo := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(90.0, 90.0)
	suelo.mesh = plano
	suelo.position = Vector3(0.0, -0.55, 0.0)
	suelo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	suelo.material_override = _mat_piedra(suelo_tex, Color(0.24, 0.27, 0.34), 0.34)
	add_child(suelo)
	_cyl_tex(7.4, 7.8, 0.30, Vector3(0.0, -0.42, 0.0), suelo_tex,
		Color(0.20, 0.22, 0.28), 0.26)
	_cyl_tex(6.9, 7.3, 0.28, Vector3(0.0, -0.14, 0.0), suelo_tex,
		Color(0.30, 0.33, 0.41), 0.30)
	# MURO DEL FONDO, con el HUECO DE LA ENTRADA justo en medio (u entre -1.8 y
	# 1.8): ahí es donde aparecen los clientes de la borda de arriba (ENTRY cae
	# exactamente en u=0), así que salen de la cueva por su boca en vez de
	# brotar del suelo.
	#
	# VA EN PIEZAS DESIGUALES, no en dos cajas largas: cada trozo tiene su
	# ancho, su fondo y su vuelco, así que la pared avanza y retrocede y no
	# hay ni una arista larga en toda la cueva.
	for p in [[-8.4, -7.9, 5.4, 9.4, 2.8, 1.5], [-4.7, -7.5, 3.8, 8.6, 2.4, -2.0],
			[-2.2, -8.0, 3.0, 9.2, 3.0, 1.0], [2.2, -7.9, 3.0, 9.0, 2.8, -1.2],
			[4.8, -7.4, 3.8, 8.4, 2.3, 1.8], [8.4, -7.9, 5.4, 9.4, 2.8, -1.5]]:
		_muro_cueva(float(p[0]), float(p[1]),
			Vector3(float(p[2]), float(p[3]), float(p[4])), pared_tex,
			Color(0.82, 0.86, 0.97), -0.6, float(p[5]))
	# LATERALES: dos columnas que bajan por los cantos de la pantalla, cada una
	# en dos piezas a distinta profundidad. Su cara interior va a |u| = 4.1 (el
	# ancho visible es 4.78) y arrancan en w = -2.2, que es lo que las deja a la
	# vista SIN meterse en el rombo del pasillo.
	for p in [[-6.5, -6.4, 4.8, 9.0, 4.6, 1.2], [-6.9, -3.2, 5.6, 8.4, 3.4, -1.6],
			[6.5, -6.4, 4.8, 9.0, 4.6, -1.2], [6.9, -3.2, 5.6, 8.4, 3.4, 1.6]]:
		_muro_cueva(float(p[0]), float(p[1]),
			Vector3(float(p[2]), float(p[3]), float(p[4])), pared_tex,
			Color(0.74, 0.78, 0.90), -0.6, float(p[5]))
	_entrada_cueva(pared_tex)
	# CASCOTES al pie del muro: sin ellos, la junta pared-suelo es una recta
	# perfecta de lado a lado y la cueva parece un decorado de cartón.
	for k in [[-4.4, -6.2, 0.9, 6.0], [-2.9, -6.3, 0.65, -8.0], [2.9, -6.3, 0.7, 7.0],
			[4.5, -6.1, 0.85, -5.0], [-4.6, -4.9, 0.6, 9.0], [4.7, -4.7, 0.65, -7.0]]:
		var cascote := _muro_cueva(float(k[0]), float(k[1]),
			Vector3(float(k[2]) * 2.2, float(k[2]) * 1.5, float(k[2]) * 1.8),
			pared_tex, Color(0.70, 0.74, 0.86), -0.55, float(k[3]))
		cascote.rotation_degrees.y = 45.0 + float(k[0]) * 19.0
	# ROCAS: la textura de rocas.glb es la roca de las islas AL SOL, gris clara,
	# y sin oscurecerla parecían montones de nieve.
	for r in [[-3.5, -4.3, 1.5], [3.3, -4.6, 1.4]]:
		var pos := _uw(float(r[0]), float(r[1]))
		var rocas := _spawn_model(load("res://assets/models/rocas.glb"),
			pos, float(r[2]), self)
		rocas.rotation_degrees.y = float(r[0]) * 53.0 + float(r[1]) * 17.0
		_entenebrecer(rocas, Color(0.46, 0.50, 0.62))
	# ESTALAGMITAS del suelo, cada una con su inclinación. NO hay estalactitas
	# colgando: sin techo a la vista, unos conos flotando por el borde de arriba
	# no se leen como nada.
	for e in [[-2.2, -5.2, 1.5, 5.0], [2.0, -5.3, 1.3, -6.0], [-3.6, 3.6, 1.2, -4.0],
			[3.7, 3.5, 1.0, 6.0]]:
		_estalagmita(_uw(float(e[0]), float(e[1])), float(e[2]), pared_tex,
			float(e[3]))
	# CRISTALES: la luz del sitio. Los cuatro grandes llevan LUZ DE VERDAD.
	#
	# EL DECORADO VA CONTADO Y SEPARADO. Llegó a haber ocho estalagmitas, nueve
	# cristales, seis rocas y ocho cascotes, y el sitio donde caben —la franja
	# entre el rombo del pasillo (|u|+|w| >= 6.3) y el borde de la pantalla
	# (|u| <= 4.7)— es tan estrecha que se amontonaban y se atravesaban unos a
	# otros. Con esta lista NINGÚN par baja de ~1.3 u de separación.
	for c in [[-4.3, -2.3, 1.8, true], [4.4, -2.0, 1.6, true],
			[-4.2, 2.4, 1.5, true], [4.3, 2.2, 1.3, true],
			[-4.8, -4.9, 0.8, false], [4.6, -4.4, 0.7, false]]:
		_cristal(float(c[0]), float(c[1]), float(c[2]), bool(c[3]))


## LA BOCA DE LA CUEVA, en lo alto de la pantalla: el hueco entre las piezas del
## muro del fondo. NADA DE MARCO DE PUERTA — la boca de una cueva no tiene forma
## exacta, así que el contorno lo dibujan piezas de roca de tamaños, fondos y
## VUELCOS distintos: el dintel son seis bloques ladeados a alturas diferentes,
## las jambas otras seis y abajo cascotes que rompen la línea del suelo. Por
## aquí entran los clientes de la borda de arriba.
func _entrada_cueva(pared_tex: Texture2D) -> void:
	# Dintel a trozos: cada bloque arranca a su altura, con su vuelco y a su
	# profundidad, así que el canto de abajo sale dentado y no escalonado.
	for d in [[-1.20, 0.72, 0.8, -7.7, 11.0], [-0.72, 1.24, 0.65, -7.4, -7.0],
			[-0.24, 1.62, 0.7, -7.8, 5.0], [0.26, 1.55, 0.65, -7.5, -9.0],
			[0.74, 1.16, 0.7, -7.9, 8.0], [1.22, 0.66, 0.8, -7.5, -12.0]]:
		_muro_cueva(float(d[0]), float(d[3]),
			Vector3(float(d[2]), 6.0, 2.6), pared_tex,
			Color(0.78, 0.82, 0.94), float(d[1]), float(d[4]))
	# Jambas: pilastras ladeadas, tres por lado y a distinta profundidad.
	for j in [[-1.70, -6.35, 0.95, 2.4, 8.0], [-1.48, -5.95, 0.6, 1.5, -9.0],
			[-1.62, -7.0, 0.8, 2.0, 5.0],
			[1.74, -6.35, 1.0, 2.2, -9.0], [1.52, -5.95, 0.55, 1.35, 8.0],
			[1.66, -7.0, 0.7, 1.8, -6.0]]:
		_muro_cueva(float(j[0]), float(j[1]),
			Vector3(float(j[2]), float(j[3]), 1.0), pared_tex,
			Color(0.72, 0.76, 0.88), -0.6, float(j[4]))
	# Y cascotes al pie, que quitan la recta del suelo de la boca.
	for k in [[-1.18, -6.15, 0.75, 1.05, 10.0], [-0.42, -6.25, 0.5, 0.40, -7.0],
			[1.10, -6.18, 0.68, 0.88, -11.0], [0.45, -6.3, 0.45, 0.32, 8.0]]:
		_muro_cueva(float(k[0]), float(k[1]),
			Vector3(float(k[2]), float(k[3]), 0.7), pared_tex,
			Color(0.66, 0.70, 0.82), -0.55, float(k[4]))
	# EL PASADIZO: suelo oscuro y paredes que se cierran detrás del hueco, para
	# que por la boca se vea un túnel y no el mismo suelo de fuera.
	_muro_cueva(0.0, -11.0, Vector3(5.2, 0.14, 7.0), pared_tex,
		Color(0.09, 0.10, 0.14), -0.52)
	for lado in [-1.0, 1.0]:
		_muro_cueva(lado * 3.1, -11.0, Vector3(1.6, 6.0, 7.0), pared_tex,
			Color(0.14, 0.16, 0.21))
	# LA LUZ DEL DÍA: una tarjeta plana con el shader del portal (ver
	# `shaders/portal_cueva.gdshader`). Va JUSTO DETRÁS de la boca, no al fondo
	# del túnel: cuanto más atrás, menos se ve por el hueco y más parece niebla.
	var tarjeta := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(3.0, 2.3)
	tarjeta.mesh = quad
	tarjeta.position = _uw(0.0, -6.85) + Vector3(0.0, 0.55, 0.0)
	tarjeta.rotation_degrees.y = 45.0
	var mat_p := ShaderMaterial.new()
	mat_p.shader = load("res://shaders/portal_cueva.gdshader")
	mat_p.set_shader_parameter("fuerza", 0.70)
	mat_p.set_shader_parameter("borde", 0.50)
	tarjeta.material_override = mat_p
	tarjeta.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tarjeta)
	# Y SU LUZ, que no se queda en la boca: ALUMBRA la cueva. Son DOS focos
	# fríos —uno en el umbral y otro ya dentro, más suave y de más alcance—,
	# los únicos que en esta cueva no son verdes. Van sin sombras, como todo el
	# juego, así que el de dentro se coloca por delante del muro para que no lo
	# atraviese y encienda el suelo de lado a lado.
	for l in [[-6.2, 1.15, 2.6, 6.0], [-4.2, 1.6, 1.9, 9.5]]:
		var dia := OmniLight3D.new()
		dia.position = _uw(0.0, float(l[0])) + Vector3(0.0, float(l[1]), 0.0)
		dia.light_color = Color(0.62, 0.78, 0.98)
		dia.light_energy = float(l[2])
		dia.omni_range = float(l[3])
		dia.omni_attenuation = 1.1
		dia.shadow_enabled = false
		add_child(dia)


## Material de piedra texturizada TRIPLANAR: el mapeado cae por las tres caras
## sin depender de las UV, que es lo que deja tilear la misma textura en cajas,
## conos y cilindros hechos por código. `escala` va en REPETICIONES POR UNIDAD
## de mundo, así que son números PEQUEÑOS (0.2 ≈ una baldosa cada 5 u): con
## valores altos la piedra se convierte en una rejilla de puntos.
func _mat_piedra(tex: Texture2D, tinte: Color, escala: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = tinte
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(escala, escala, escala)
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat


## Cilindro texturizado (los discos del montículo).
func _cyl_tex(r_top: float, r_bottom: float, alto: float, pos: Vector3,
		tex: Texture2D, tinte: Color, escala: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bottom
	mesh.height = alto
	mesh.radial_segments = 24
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _mat_piedra(tex, tinte, escala)
	add_child(mi)
	return mi


## Un cono de piedra texturizada: una estalagmita del suelo, con su vuelco
## (`tilt`) para que no salgan todas a plomo. Tuvo un modo `colgante` para
## las ESTALACTITAS y se fue con ellas: colgadas de un techo que esta cámara
## no enseña, eran conos flotando en el borde de arriba.
func _estalagmita(pos: Vector3, alto: float, tex: Texture2D, tilt := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var cono := CylinderMesh.new()
	cono.top_radius = 0.03
	cono.bottom_radius = alto * 0.32
	cono.height = alto
	cono.radial_segments = 7
	mi.mesh = cono
	mi.position = pos + Vector3(0.0, alto * 0.5 - 0.05, 0.0)
	mi.rotation_degrees = Vector3(tilt * 0.6, pos.x * 37.0, tilt)
	mi.material_override = _mat_piedra(tex, Color(0.62, 0.66, 0.76), 1.15)
	add_child(mi)


## UN CRISTAL: un racimo de agujas con el shader de cristal (`shaders/
## crystal.gdshader`: translúcidas, con gradiente a lo largo y el canto
## encendido por fresnel) y, las grandes, con su propia LUZ.
##
## LA LUZ ES DE VERDAD, un OmniLight3D. Antes cada cristal llevaba un charco
## emisivo pintado a sus pies: se veía la mancha, pero no iluminaba nada — ni
## la piedra de al lado ni a los clientes que pasaban por delante. En una cueva
## a oscuras la única fuente de luz no puede ser una calcomanía.
func _cristal(u: float, w: float, alto: float, con_luz: bool) -> void:
	var pos := _uw(u, w)
	var color_luz := Color(0.22, 0.88, 0.66)
	var giro := u * 47.0 + w * 23.0
	# Racimo: la aguja grande y dos esquirlas apoyadas, cada una con su vuelco.
	for p in [[Vector2.ZERO, 1.0, 0.0], [Vector2(0.26, 0.10), 0.55, 21.0],
			[Vector2(-0.22, -0.14), 0.42, -26.0]]:
		var off: Vector2 = p[0] * alto
		var h := alto * float(p[1])
		var mi := MeshInstance3D.new()
		var prisma := CylinderMesh.new()
		prisma.top_radius = 0.02
		prisma.bottom_radius = h * 0.26
		prisma.height = h
		prisma.radial_segments = 6
		mi.mesh = prisma
		mi.position = pos + Vector3(off.x, h * 0.44, off.y)
		mi.rotation_degrees = Vector3(float(p[2]), giro, float(p[2]) * 0.6)
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/crystal.gdshader")
		mat.set_shader_parameter("media_altura", h * 0.5)
		mat.set_shader_parameter("color_luz", color_luz)
		mat.set_shader_parameter("brillo", 1.55 if con_luz else 1.15)
		# El latido se apaga con el ajuste de Animaciones, como el resto del
		# adorno del juego.
		mat.set_shader_parameter("pulso", 0.10 if GameState.animations_on() else 0.0)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	if not con_luz:
		return
	var luz := OmniLight3D.new()
	luz.position = pos + Vector3(0.0, alto * 1.05, 0.0)
	luz.light_color = color_luz
	luz.light_energy = 1.9 + alto * 0.85
	luz.omni_range = 4.2 + alto * 1.7
	luz.omni_attenuation = 1.05
	luz.shadow_enabled = false
	add_child(luz)


## Multiplica el albedo de TODAS las superficies de un modelo (el color de un
## StandardMaterial3D multiplica su textura). Duplica los materiales para no
## tenebrecer al resto de instancias del mismo GLB en otras escenas.
func _entenebrecer(pivot: Node3D, tinte: Color) -> void:
	for m in pivot.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = m.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var mat: Material = m.get_active_material(i)
			if mat is StandardMaterial3D:
				var copia: StandardMaterial3D = mat.duplicate()
				copia.albedo_color = tinte
				m.set_surface_override_material(i, copia)


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
	# EL PELUCHE DE MORSA (coleccionable), dormido sobre una caja del arenal:
	# la caja se pone aqui SOLO si el peluche es tuyo — una caja vacia porque
	# si ya se quito una vez de esta escena (chocaba con una palmera).
	if GameState.has_collectible("peluche_morsa") \
			and ResourceLoader.exists("res://assets/models/caja.glb"):
		var caja_morsa := _spawn_model(load("res://assets/models/caja.glb"),
			Vector3(4.9, 0.0, 1.6), 0.66, self)
		_tint_model(caja_morsa, CRATE_TINT)
		ColVisibles.morsa_en_isla(self, Vector3(4.9, 0.0, 1.6))


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


## Alto de la farola del muelle. El poste dibujado que hubo antes medía 2,86
## (2,6 de palo y su caja de luz), así que la de verdad se pone a esa talla.
const PORT_LAMP_H := 2.9


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
	# FAROLA DE VERDAD, la misma del puerto de la portada (pedido por el
	# usuario): `farola.glb`. Era un cilindro con una caja de luz encima y al
	# lado del resto del muelle —que ya va con modelos— se leia como un
	# andamio. Se queda el poste dibujado de respaldo por si falta el archivo.
	var farola := "res://assets/models/farola.glb"
	if ResourceLoader.exists(farola):
		# Y SE MUDA AL CANTO DERECHO: el poste dibujado medía lo mismo pero
		# la farola de verdad lleva su cabeza de cristal arriba del todo, y
		# en el sitio de antes (-3.4, -4.9) esa cabeza caía detrás de la
		# barra del HUD. Medido con `unproject_position`: aquí queda a media
		# altura de la banda visible y con su pie por encima de la tabla.
		var f := _spawn_model(load(farola), Vector3(6.6, 0.0, 1.2),
			PORT_LAMP_H, self)
		# Girada como en la portada: de frente a esta camara (yaw 45), o su
		# cara buena queda mirando al mar.
		f.rotation_degrees.y = 45.0
		f.add_to_group("no_batch")
	else:
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
## EL TEMA DE LA JORNADA LO DECIDE EL TIPO DE ESCENARIO, no el escenario: una
## isla suena a isla y un abordaje a abordaje, aquí y en el mar 7. La CUEVA es
## la excepción del jefe y el ARCADE tiene el suyo, que no es una travesía sino
## una carrera.
##
## El TUTORIAL tiene SU tema (`tutorial`). Sonó un tiempo al de abordaje —una
## cubierta desbordada contra el reloj— y no es lo mismo: en un abordaje el
## jugador pelea, y aquí pierde a propósito. El suyo es de pánico de cocina.
## Volumen del mar de fondo dentro de un nivel, sobre `Audio.AMB_DB`.
const AMB_NIVEL := -20.0


func _musica_del_nivel() -> void:
	if GameState.is_arcade():
		Audio.musica("arcade")
		return
	if GameState.is_tutorial():
		# EL TUTORIAL SUENA AL ABORDAJE YA LANZADO (pedido por el usuario): es
		# una cocina desbordada, así que se le pone el tema de los abordajes
		# con el tempo que ese tema solo alcanza en sus últimos segundos.
		Audio.musica("abordaje")
		Audio.tempo(TEMPO_MAX)
		return
	var kind := scenery_kind
	Audio.musica(kind if Audio.TEMAS.has(kind) else "isla")


## EL ABORDAJE SE ACELERA SEGÚN SE ACABA EL RELOJ (pedido por el usuario). No
## es un efecto: es información. `pitch_scale` sube la velocidad Y el tono, así
## que la música se va poniendo nerviosa sola y el jugador nota la prisa antes
## de mirar el cronómetro.
##
## Va SOLO donde hay reloj de verdad y el tema es el de abordaje: en una isla o
## un puerto no hay cuenta atrás que acompañar, y la cueva es del jefe (allí el
## reto no es el tiempo).
##
## Y NO ARRANCA HASTA `TEMPO_DESDE`: acelerar desde el primer segundo se oye
## como que el tema está mal, no como que queda poco. El último tercio es donde
## la prisa significa algo.
const TEMPO_MAX := 1.12
const TEMPO_DESDE := 0.55


func _tempo_del_abordaje() -> void:
	if not timed or scenery_kind != "abordaje" or time_limit <= 0.0:
		return
	if GameState.is_arcade() or GameState.is_tutorial():
		return
	var gastado := clampf(elapsed / time_limit, 0.0, 1.0)
	var t := clampf((gastado - TEMPO_DESDE) / (1.0 - TEMPO_DESDE), 0.0, 1.0)
	# Curva suave: entra despacio y aprieta al final, en vez de una rampa
	# recta que se nota como un motor subiendo de vueltas.
	Audio.tempo(lerpf(1.0, TEMPO_MAX, t * t))


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
	# Un botón de cartel corriente: zarpar ya sonó en el selector. Esto YA
	# estaba puesto y no servía de nada: `skin_start_button` corre DESPUÉS y
	# le pisaba el papel con el suyo. El skinner ya no toca el sonido.
	go.set_meta("snd", "click")
	# 112 y no 80: la placa de oro tiene su marco 9-slice a 54, así que por
	# debajo de 108 se encoge y el botón se ve apretado a lo alto, sin sitio
	# para el cuerpo de letra que lleva (ver `PrepBoard.skin_start_button`).
	go.custom_minimum_size = Vector2(300, 112)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# `drop` a 0: el desplazamiento de serie sube el rótulo 9 px (ver
	# `START_TEXT_DROP`) y en este botón, que es alto, se veía descentrado.
	PrepBoard.skin_start_button(go, 0.0)
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


## Altura del cartel de fase. Los contadores de maestría ya no comparten su
## banda (viven abajo a la derecha, a la altura de las cabezas), así que vuelve
## a ser fija: apoyado sobre la fila de cabezas.
func _phase_sign_y() -> float:
	return GameState.canvas_size().y - 588.0 - HEAD_ICON - 12.0 - PHASE_H


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
		_phase_sign_y())
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
		# CON EL JEFE EN ESCENA la estrella de la meta es SU CARA y se gana
		# rindiéndolo, no con oro: ni la cifra ni el repintado por dinero.
		if meta_star and boss_star_face:
			continue
		if meta_star:
			_place_goal_value(n, lado)
		var ganada: bool = oro >= float(m["meta"])
		if ganada != bool(m["on"]):
			m["on"] = ganada
			_light_star_mark(n, ganada, i)


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
## EL BOTE VA EN SU PROPIO TWEEN Y EN SECUENCIA, no en paralelo con retardo.
## Con `set_parallel` los dos tramos de `scale` arrancan a la vez y el segundo
## **captura su valor de partida al empezar el paso, no al vencer su retardo**:
## interpolaba de 1 a 1, mandaba el primero y la estrella se QUEDABA AGRANDADA
## para siempre. El fogonazo va aparte, en otro tween, que así corre a la vez
## sin tener que mezclarlos.
##
## Se apaga también (con el castigo por plato tirado o por cliente que se va de
## vacío el oro BAJA), pero sin bote: perder una estrella no se celebra.
## `cual` es la estrella (0, 1 o 2). Las dos primeras comparten toma —la
## primera mas grave— y la tercera tiene la suya: es la meta del turno.
func _light_star_mark(n: TextureRect, ganada: bool, cual := 0) -> void:
	# Solo suena al ENCENDERSE. Apagarse también pasa (los castigos bajan el
	# oro) y ahí no hay nada que celebrar, igual que tampoco hay bote.
	if ganada and n != null and not n.get_meta("encendida", false):
		if cual >= 2:
			Audio.sfx("bar_estrella3")
		else:
			Audio.sfx("bar_estrella", 0.0, 0.88 if cual == 0 else 1.0)
	if n != null:
		n.set_meta("encendida", ganada)
	n.texture = load(STAR_MARK_TEX % ("llena" if ganada else "vacia"))
	n.modulate = STAR_MARK_ON if ganada else STAR_MARK_OFF
	# Un bote a medias que se quedara colgado dejaría la estrella de otro
	# tamaño: se mata antes de empezar el siguiente y se vuelve al tamaño bueno.
	# Con `has_meta` antes: `get_meta` con valor por defecto SIGUE gritando por
	# consola si la clave no existe, y aquí no existe la primera vez de cada
	# estrella.
	if n.has_meta("bote"):
		var previo: Tween = n.get_meta("bote") as Tween
		if previo != null and previo.is_valid():
			previo.kill()
	n.scale = Vector2.ONE
	if not ganada:
		return
	var ts := create_tween()
	ts.tween_property(n, "scale", Vector2(1.55, 1.55), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ts.tween_property(n, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	n.set_meta("bote", ts)
	var tm := create_tween()
	tm.tween_property(n, "modulate", Color(2.2, 2.1, 1.6), 0.10)
	tm.tween_property(n, "modulate", STAR_MARK_ON, 0.30)


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
		results_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		results_panel.add_child(prep_board.make_nine_patch(
			PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))
	# EL CARTEL DE POTENCIADORES VA SIN FONDO (pedido por el usuario): las
	# cartas se sostienen solas sobre la partida, sin un segundo panel detrás.
	# El Panel se queda —invisible— porque es quien se traga los toques
	# mientras se elige, que es media función de un cartel modal.
	powerup_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# El rótulo es un TITULAR grande DENTRO del cartel, no una cinta: el panel
	# ya lleva cuerdas en las cuatro esquinas y una tela encima lo cargaba.
	$HUD/ResultsPanel/VBox/TitleLabel.visible = false
	var dark := Color(0.26, 0.16, 0.08)
	# `earn_label` NO va aquí: `_restyle_results_panel` ya le pone su crema
	# claro y este bucle, que corre después, se lo pisaba y lo dejaba marrón.
	for l in [$HUD/ResultsPanel/VBox/TitleLabel, score_label]:
		l.add_theme_color_override("font_color", dark)
	# El título del cartel de potenciadores va sobre MADERA OSCURA, así que
	# es crema con reborde, no la tinta parda del resto de ventanas.
	var pot_title: Label = $HUD/PowerupPanel/VBox/Title
	pot_title.add_theme_color_override("font_color", Color(1, 0.93, 0.78))
	pot_title.add_theme_color_override("font_outline_color", Color(0.20, 0.11, 0.03))
	pot_title.add_theme_constant_override("outline_size", 8)
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		pot_title.add_theme_font_override("font", negrita)
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
	# Contadores de maestria del HUD. Es una comparacion de tres enteros: solo
	# toca las etiquetas cuando una cifra cambia de verdad.
	_refresh_skill_counters()
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

	# EL VIENTO corre siempre (también en la preparación: da ambiente y deja
	# ver el banderín moverse antes de abrir).
	if wind_on and not ended:
		_tick_viento(delta)
	# EL CANTO solo con la barra abierta: en la preparación no hay a quién
	# atontar (y un canto forzado por el guion de la jefa corre igual).
	if (canto_on or canto_activo) and not ended and not prep_phase:
		_tick_canto(delta)
	_tick_rush(delta)
	_refresh_pot_row()

	# La banda de la cinta avanza a la velocidad real de los platos (tambien
	# durante la fase de preparacion, pero no congelada). `belt_dir` es el
	# sentido con su transición: al girar, la banda se frena y arranca al revés.
	if not frozen:
		belt_scroll = fposmod(belt_scroll + PLATE_SPEED * belt_mult * belt_dir * delta / band_tile_len, 1.0)
	# CINTA LLENA (hándicap de isla del mar 3): la tabla necesita saberlo para
	# rechazar el servicio, y se lo decimos desde aquí porque el recuento es
	# del NIVEL. Con `cinta_max` a 0 (todo lo demás) nunca se enciende.
	if cinta_max > 0 and prep_board != null:
		prep_board.belt_full = get_tree().get_nodes_in_group("plates").size() >= cinta_max
	# EL EMPUJE DEL SHADER VA FUERA DE ESE `if`. Se coló dentro al meter el
	# tope de platos del mar 3, así que la banda solo se movía en escenarios
	# con `cinta_max` — o sea, en ninguno: LA CINTA SE VEÍA PARADA EN TODO EL
	# JUEGO aunque los platos siguieran viajando por encima.
	band_mat.set_shader_parameter("scroll_tiles", belt_scroll)
	if corner_mat != null:
		corner_mat.set_shader_parameter("scroll_tiles", belt_scroll)

	# La cinta dibujada en la mesa de preparación gira CON la de cubierta.
	if prep_board != null and "belt_dir" in prep_board:
		prep_board.belt_dir = belt_dir

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
			# LA CAMPANA QUE ABRE Y CIERRA LA JORNADA: la misma que suena al
			# acabar el turno (pedido por el usuario). Lo que se confundía con
			# esto eran las campanas de ZARPAR y el botón de "¡Empezar!", que
			# ya suenan a otra cosa; el servicio empieza y termina igual.
			Audio.sfx("fin_turno")
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
	_tempo_del_abordaje()
	if timed and elapsed >= time_limit:
		_end_level()
		return

	if arcade:
		_tick_arcade(delta)
		if ended:
			return
	if belt_timer > 0.0:
		belt_timer -= delta
		if belt_timer <= 0.0:
			belt_mult = belt_base
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
	# levanta el dedo (y tras su respiro, para que la barra se vea llegar).
	powerup_delay = maxf(powerup_delay - delta, 0.0)
	_try_open_powerup_choice()
	_update_hud()


# -------------------------------------------------------------- SUSHI RUSH
# La habilidad de MIKU (m2_14): encadena RUSH_CHAIN platos SIN FALLO — cada
# plato que un cliente come y que NO había probado suma; un plato repetido, un
# plato al cubo o un corte fallado ROMPEN la cadena — y se enciende el rush:
# los platos elegidos se hacen SOLOS y el enfriamiento cae a RUSH_COOLDOWN.
# Dura hasta que un plato se repite o cae a la basura. Mientras está activo,
# cuelga el cartel de "SUSHI RUSH" balanceándose, la pantalla vibra y entran
# las líneas de acción de la pesca.

const RUSH_CHAIN := 10
const RUSH_COOLDOWN := 0.45

var rush_chain := 0
var rush_active := false
var _rush_sign: Control = null
var _rush_lines: ColorRect = null
var _rush_shake := 0.0


## Un plato COME-Y-CUENTA (lo llama client3d al terminar cada plato, con si el
## cliente lo había probado ya). Los picoteos y postres cuentan como el resto:
## la cadena es de platos ENTREGADOS, no de principales.
func note_rush_plate(nuevo: bool) -> void:
	if not GameState.sushi_rush_unlocked or arcade:
		return
	if not nuevo:
		_rush_break()
		return
	if rush_active:
		return
	rush_chain += 1
	if rush_chain >= RUSH_CHAIN:
		_rush_on()


## Un plato al cubo (o un corte fallado) rompe la cadena — y apaga el rush.
func note_rush_fail() -> void:
	if not GameState.sushi_rush_unlocked:
		return
	_rush_break()


func _rush_break() -> void:
	rush_chain = 0
	if rush_active:
		_rush_off()


func _rush_on() -> void:
	rush_active = true
	if prep_board != null:
		prep_board.rush = true
	Audio.sfx("habilidad")
	_montar_rush_sign()
	_montar_rush_lines()


func _rush_off() -> void:
	rush_active = false
	if prep_board != null:
		prep_board.rush = false
	if _rush_sign != null and is_instance_valid(_rush_sign):
		var s := _rush_sign
		_rush_sign = null
		var tw := s.create_tween()
		tw.tween_property(s, "position:y", s.position.y - 160.0, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(s.queue_free)
	if _rush_lines != null and is_instance_valid(_rush_lines):
		var l := _rush_lines
		_rush_lines = null
		var tw2 := l.create_tween()
		tw2.tween_property(l, "modulate:a", 0.0, 0.5)
		tw2.tween_callback(l.queue_free)


## EL CARTEL COLGANTE: una tabla que cae desde el borde de arriba colgada de
## dos cuerdas y se BALANCEA mientras el rush está vivo. Va aparte del cartel
## de fase a propósito (otro sitio, otro diseño): esto es un estado, no una
## cuenta atrás.
func _montar_rush_sign() -> void:
	if _rush_sign != null:
		return
	var raiz := Control.new()
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.z_index = 95
	$HUD.add_child(raiz)
	var w := 320.0
	var alto := 86.0
	raiz.position = Vector2((GameState.canvas_size().x - w) * 0.5, -alto - 60.0)
	raiz.size = Vector2(w, alto + 60.0)
	# El PIVOTE arriba y centrado: el balanceo es un péndulo desde las cuerdas.
	raiz.pivot_offset = Vector2(w * 0.5, 0.0)
	for lado in [-1.0, 1.0]:
		var cuerda := ColorRect.new()
		cuerda.color = Color(0.82, 0.72, 0.5)
		cuerda.size = Vector2(6.0, 62.0)
		cuerda.position = Vector2(w * 0.5 + lado * w * 0.32 - 3.0, 0.0)
		cuerda.mouse_filter = Control.MOUSE_FILTER_IGNORE
		raiz.add_child(cuerda)
	var tabla := Control.new()
	tabla.position = Vector2(0.0, 58.0)
	tabla.size = Vector2(w, alto)
	tabla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(tabla)
	var fondo := PrepBoard.make_nine_patch(PrepBoard.PERK_TEX,
		PrepBoard.PERK_MARGIN)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabla.add_child(fondo)
	var l := Label.new()
	l.text = "SUSHI RUSH"
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 34)
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		l.add_theme_font_override("font", negrita)
	l.add_theme_color_override("font_color", Color(0.32, 0.16, 0.03))
	l.add_theme_color_override("font_outline_color", Color(1, 0.93, 0.68))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabla.add_child(l)
	_rush_sign = raiz
	# Cae desde arriba con rebote y se queda meciéndose (el balanceo vive en
	# `_process`, que es quien puede moverlo también con el árbol vivo).
	var tw := raiz.create_tween()
	tw.tween_property(raiz, "position:y", 0.0, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Las líneas de acción de la pesca, a pantalla completa y suaves.
func _montar_rush_lines() -> void:
	if _rush_lines != null:
		return
	var l := ColorRect.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 90
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/action_lines.gdshader")
	mat.set_shader_parameter("center", Vector2(0.5, 0.45))
	l.material = mat
	l.modulate.a = 0.0
	$HUD.add_child(l)
	_rush_lines = l
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 0.55, 0.4)


## El balanceo del cartel y la vibración de cámara, por fotograma.
func _tick_rush(delta: float) -> void:
	if not rush_active:
		return
	if _rush_sign != null and is_instance_valid(_rush_sign):
		_rush_sign.rotation = sin(elapsed * 2.2) * 0.055
	_rush_shake += delta
	if cam != null:
		cam.h_offset = sin(_rush_shake * 31.0) * 0.02
		cam.v_offset = cos(_rush_shake * 27.0) * 0.02


# ------------------------------------------------------------------ viento

## ¿El puerto de hoy declara viento?
func port_cfg_viento() -> bool:
	if not GameState.is_adventure() or GameState.is_tutorial():
		return false
	return bool(CampaignData.get_port(GameState.current_port).get("viento", false))


## UN PASO DEL SIMULADOR. El viento persigue objetivos sorteados; al alcanzar
## uno, respira y sortea el siguiente. Para CAMBIAR DE SENTIDO tiene que pasar
## por 0: ahí es donde (a veces) se da la vuelta. Los sustos en falso salen
## solos: un objetivo de 36 km/h hacia la izquierda enciende el aviso y se
## queda sin llegar al umbral.
func _tick_viento(delta: float) -> void:
	if wind_dwell > 0.0:
		wind_dwell -= delta
	elif absf(wind_kmh - wind_target) < 0.5:
		wind_dwell = randf_range(0.7, 3.2)
		_nuevo_objetivo_viento()
	else:
		wind_kmh = move_toward(wind_kmh, wind_target, wind_rate * delta)
		if wind_kmh <= 0.05 and wind_target <= 0.05:
			# En la calma es donde el viento puede darse la vuelta.
			if randf() < 0.55:
				wind_dir = -wind_dir

	# ¿Toca invertir la cinta? Solo el viento FUERTE hacia la IZQUIERDA. La
	# vuelta a la normalidad lleva histéresis: si girase justo en el umbral,
	# una racha oscilando ahí haría bailar la cinta sin parar.
	var quiere := -1.0 if (wind_dir < 0 and wind_kmh >= WIND_UMBRAL) else 1.0
	if quiere < 0.0:
		pass
	elif belt_dir_objetivo < 0.0 and wind_dir < 0 \
			and wind_kmh >= WIND_UMBRAL * 0.85:
		quiere = -1.0
	if quiere != belt_dir_objetivo:
		belt_dir_objetivo = quiere
		_cinta_gira(quiere < 0.0)
	belt_dir = move_toward(belt_dir, belt_dir_objetivo, 2.0 * delta / BELT_TURN_T)

	# EL AVISO "!" — cuando el viento zurdo se acerca al umbral y sube. Puede
	# ser un susto en falso, y esa es la gracia: obliga a mirar el anemómetro.
	if wind_dir < 0 and wind_kmh >= WIND_UMBRAL * 0.78 and belt_dir_objetivo > 0.0:
		if not _wind_avisado:
			_wind_avisado = true
			_aviso_viento()
	elif wind_kmh < WIND_UMBRAL * 0.6:
		_wind_avisado = false

	_refresh_viento_hud()


func _nuevo_objetivo_viento() -> void:
	# Un tercio de las rachas vuelven a la calma (que es el único camino para
	# cambiar de sentido); el resto sopla a algo entre flojo y el techo.
	if randf() < 0.36:
		wind_target = 0.0
	else:
		wind_target = randf_range(8.0, wind_max)
	wind_rate = randf_range(7.0, 16.0)


# ---------------------------------------------------------- canto de sirena
# El hándicap del MAR 2: a ratos suena un canto y los clientes que ESPERAN se
# atontan mirando al mar — no cogen NI UN plato mientras dura (su dado se
# APLAZA: `client3d._scan_belt` sale sin tirar, así que el plato sigue vivo
# para cuando despierten) y su paciencia sigue bajando. El que COME se libra:
# la comida es lo único que puede más que el canto, y por eso anticiparse
# (un plato a cada boca antes del canto) es la jugada buena. A un atontado se
# le DESPIERTA CON UN TOQUE (`_unhandled_input` → `client3d.despertar`), y ya
# no recae hasta el canto siguiente.
# La JEFA del mar (m2_25) usa este mismo aparato a dedo: su guion llama a
# `_empezar_canto`/`_terminar_canto` sin planificador (canto_on false).

## ¿Este nivel lleva el canto? (campo `sirena` del puerto, mar 2).
var canto_on := false
## Ahora mismo SUENA el canto (los atontados se refrescan por fotograma).
var canto_activo := false
## Cuenta atrás del aviso previo ("~ ¡La sirena canta! ~"): 2 s de margen
## para colocar platos, el gemelo del "!" del viento.
var canto_aviso := 0.0
## Lo que queda de canto / hasta el próximo aviso.
var canto_t := 0.0
var canto_espera := 0.0
## Horquillas por TIPO de escenario (espera entre cantos y duración).
var canto_gap := Vector2(46.0, 70.0)
var canto_dur := Vector2(6.0, 9.0)
## Cuántos cantos han sonado ya (lo sondean las lecciones del director).
var canto_total := 0
## Cuántos atontados ha despertado el jugador (ídem).
var despertados := 0


func _tick_canto(delta: float) -> void:
	if canto_activo:
		canto_t -= delta
		_aplicar_canto()
		if canto_t <= 0.0:
			_terminar_canto()
	elif canto_on:
		if canto_aviso > 0.0:
			canto_aviso -= delta
			if canto_aviso <= 0.0:
				_empezar_canto()
		else:
			canto_espera -= delta
			if canto_espera <= 0.0:
				canto_aviso = 2.0
				_aviso_canto()


## El aviso previo: la señal para REPARTIR PLATOS ya — quien esté comiendo
## cuando arranque el canto se libra de él.
func _aviso_canto() -> void:
	Audio.sfx("sirena_aviso")
	_texto_cinta("~ ¡La sirena canta! ~")


func _empezar_canto(dur := -1.0) -> void:
	canto_activo = true
	canto_t = dur if dur > 0.0 else randf_range(canto_dur.x, canto_dur.y)
	# LOS TAPONES DE CERA de Ulises (coleccionable): con ellos en el barco,
	# cada canto de sirena dura un tercio menos. Es el primer coleccionable
	# con efecto de juego, y va aqui y no en el planificador para que recorte
	# tambien los cantos que fuerza un guion.
	if GameState.has_collectible("tapones_cera"):
		canto_t *= CollectibleData.TAPONES_CANTO
	canto_total += 1
	Audio.loop_on("sirena_canto", -4.0)


func _terminar_canto() -> void:
	canto_activo = false
	canto_espera = randf_range(canto_gap.x, canto_gap.y)
	Audio.loop_off("sirena_canto")
	for c in seat_clients:
		if c != null and is_instance_valid(c):
			c.set_atontado(false)
			c.canto_despierto = false


## Por fotograma mientras suena: atonta a los que esperan (los despertados y
## los inmunes no) y suelta a quien haya dejado de esperar (p. ej. el que un
## guion sentó a comer a dedo).
func _aplicar_canto() -> void:
	for c in seat_clients:
		if c == null or not is_instance_valid(c):
			continue
		if c.state == c.State.WAITING and c.ya_sentado() 				and not c.canto_despierto and not c.canto_inmune:
			c.set_atontado(true)
		elif c.atontado and c.state != c.State.WAITING:
			c.set_atontado(false)


## EL TOQUE QUE DESPIERTA: un dedo sobre (o cerca de) un cliente atontado le
## rompe el trance hasta el fin de este canto. Va en _unhandled_input para no
## robarle nada a la interfaz: si el toque cayó en un botón, no llega aquí.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch and event.pressed):
		return
	if ended or prep_phase or cam == null:
		return
	var mejor: Node3D = null
	var mejor_d := 95.0
	for c in seat_clients:
		if c == null or not is_instance_valid(c) or not c.atontado:
			continue
		# Al JEFE no se le despierta: la que canta es ella, y su "trance" es
		# la mecánica de sus fases, no un cliente embobado que rescatar.
		if c.boss:
			continue
		var pp: Vector2 = cam.unproject_position(
			c.global_position + Vector3.UP * c._height * 0.6)
		var d: float = pp.distance_to(event.position)
		if d < mejor_d:
			mejor_d = d
			mejor = c
	if mejor != null:
		mejor.despertar()
		despertados += 1


## EL GIRO DE LA CINTA. Los platos en marcha RECUPERAN SU SEGUNDA OPORTUNIDAD
## (se olvidan todos los rechazos): el dado de "¿lo cojo?" se tira una vez por
## cliente y plato, y sin este olvido un plato invertido era un plato muerto —
## el viento tiene que quitar Y dar.
func _cinta_gira(invertida: bool) -> void:
	for p in get_tree().get_nodes_in_group("plates"):
		_forget_declined(p.get_instance_id())
	_texto_cinta("¡La cinta cambia de sentido!" if invertida
		else "La cinta vuelve a su sentido")
	Audio.sfx("viento_alerta", -4.0, 0.8 if invertida else 1.1)


## El "!" y su campanilla sutil: el viento se acerca al umbral.
func _aviso_viento() -> void:
	Audio.sfx("viento_alerta")
	if wind_warn == null:
		return
	wind_warn.visible = true
	wind_warn.pivot_offset = wind_warn.size * 0.5
	var tw := create_tween()
	tw.tween_property(wind_warn, "scale", Vector2(1.5, 1.5), 0.12)
	tw.tween_property(wind_warn, "scale", Vector2.ONE, 0.2)
	tw.tween_interval(2.2)
	tw.tween_callback(func() -> void:
		if wind_warn != null and belt_dir_objetivo > 0.0:
			wind_warn.visible = false)


## Texto flotante SOBRE LA CINTA de cubierta, para que el cambio se lea ahí
## donde pasa. Sube un poco y se desvanece.
func _texto_cinta(texto: String) -> void:
	if _cinta_aviso != null and is_instance_valid(_cinta_aviso):
		_cinta_aviso.queue_free()
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", 30)
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		l.add_theme_font_override("font", negrita)
	l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = GameState.canvas_size().y - 588.0 - 210.0
	$HUD.add_child(l)
	_cinta_aviso = l
	var tw := l.create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(l, "offset_top", l.offset_top - 40.0, 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
	tw.tween_callback(l.queue_free)


## EL ANEMÓMETRO (bajo el botón de Salir) y el BANDERÍN 3D del mástil.
func _setup_viento() -> void:
	# El número. Verde en calma y ROJO según se acerca al umbral (lo pinta
	# `_refresh_viento_hud`, que también lo engorda).
	wind_label = Label.new()
	wind_label.add_theme_font_size_override("font_size", 24)
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		wind_label.add_theme_font_override("font", negrita)
	wind_label.add_theme_color_override("font_outline_color", Color.BLACK)
	wind_label.add_theme_constant_override("outline_size", 8)
	wind_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(wind_label)
	var y := 176.0 + GameState.safe_top()
	if exit_button != null and is_instance_valid(exit_button):
		y = exit_button.position.y + exit_button.size.y + 10.0
	wind_label.position = Vector2(20.0, y)
	# El "!" del aviso, pegado al número.
	wind_warn = Label.new()
	wind_warn.text = "!"
	wind_warn.add_theme_font_size_override("font_size", 40)
	if negrita != null:
		wind_warn.add_theme_font_override("font", negrita)
	wind_warn.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	wind_warn.add_theme_color_override("font_outline_color", Color(1, 0.96, 0.85))
	wind_warn.add_theme_constant_override("outline_size", 8)
	wind_warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wind_warn.position = wind_label.position + Vector2(150.0, -8.0)
	wind_warn.visible = false
	$HUD.add_child(wind_warn)
	_montar_banderin()
	# El bucle del viento arranca en silencio; el volumen lo lleva el HUD.
	Audio.loop_on("viento", -80.0)
	_refresh_viento_hud()


## Color, grosor y cifra del anemómetro + banderín + volumen del bucle.
func _refresh_viento_hud() -> void:
	if wind_label != null:
		var f := clampf(wind_kmh / WIND_UMBRAL, 0.0, 1.0)
		var flecha := "←" if wind_dir < 0 else "→"
		wind_label.text = "%s %d km/h" % [flecha, roundi(wind_kmh)]
		# De verde (calma) a rojo (umbral); el cuerpo crece con el peligro.
		wind_label.add_theme_color_override("font_color",
			Color(0.35, 0.9, 0.4).lerp(Color(1.0, 0.22, 0.16), f))
		wind_label.add_theme_font_size_override("font_size", 24 + int(f * 6.0))
	if _banderin_mat != null:
		_banderin_mat.set_shader_parameter("fuerza",
			clampf(wind_kmh / wind_max, 0.0, 1.0))
	if _banderin != null and is_instance_valid(_banderin):
		# La tela apunta ADONDE VA el viento: a la derecha de pantalla en el
		# sentido natural, a la izquierda con el zurdo.
		_banderin.scale.x = absf(_banderin.scale.x) * float(wind_dir)
	# El bucle del viento sube con la velocidad (por debajo de 6 km/h calla).
	var v := clampf((wind_kmh - 6.0) / (wind_max - 6.0), 0.0, 1.0)
	Audio.loop_on("viento", -80.0 if v <= 0.0 else lerpf(-26.0, 0.0, v))


var _banderin: MeshInstance3D = null


## El MÁSTIL DEL BANDERÍN: un poste alto en la esquina superior del encuadre
## con el gallardete al viento. Es la señal DIEGÉTICA del sistema: el
## anemómetro da el número y la tela lo cuenta de un vistazo.
func _montar_banderin() -> void:
	# Coordenadas de PANTALLA (u = derecha, w = hacia la cámara), las mismas
	# de la cueva: el poste va arriba a la derecha del encuadre, fuera del
	# pasillo de paseo.
	# Medido en captura: a w=-5.9 el mástil se salía por el canto de arriba y
	# solo asomaba la puntita de la tela.
	var u := 3.45
	var w := -4.15
	var x := (u + w) * 0.70710678
	var z := (w - u) * 0.70710678
	var alto := 3.1
	var palo := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.07
	cil.bottom_radius = 0.09
	cil.height = alto
	palo.mesh = cil
	var mat_palo := StandardMaterial3D.new()
	mat_palo.albedo_color = Color(0.52, 0.36, 0.2)
	palo.material_override = mat_palo
	palo.position = Vector3(x, alto * 0.5, z)
	palo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(palo)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.15, 0.5)
	quad.center_offset = Vector3(1.15 * 0.5, 0.0, 0.0)
	# Más subdivisiones = la onda del shader se ve curva y no a tramos.
	quad.subdivide_width = 16
	quad.subdivide_depth = 2
	_banderin = MeshInstance3D.new()
	_banderin.mesh = quad
	_banderin_mat = ShaderMaterial.new()
	_banderin_mat.shader = load("res://shaders/banderin.gdshader")
	_banderin_mat.set_shader_parameter("tela",
		load("res://assets/props/banderin.png"))
	_banderin_mat.set_shader_parameter("fuerza", 0.0)
	_banderin.material_override = _banderin_mat
	_banderin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_banderin.position = Vector3(x, alto - 0.32, z)
	# +X local cae sobre el "derecha" de la pantalla (R_HAT).
	_banderin.rotation_degrees.y = 45.0
	add_child(_banderin)


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
	# Las sillas FORZADAS mandan sobre todo lo demás, mientras queden. Si la
	# que toca ya está ocupada se descarta y se sigue con la siguiente: la
	# lista es una preferencia, no una reserva.
	var forzada := false
	while not first_seats.is_empty():
		var quiere: int = int(first_seats.pop_front())
		if quiere in free_seats:
			idx = quiere
			forzada = true
			break
	if not forzada and near_seats:
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
		# El JEFE mide lo que diga su guion, no lo que mida su tipo.
		if special_height > 0.0:
			c.height_override = special_height
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
	# En puertos y abordajes el vacío no cuesta oro: cobra en derrota o reloj.
	# Y EN EL MAR 1 no cobra NADIE (la escuela no castiga el vacío); el
	# tutorial sí, que su marcador del caos vive de esos castigos.
	c.penaliza_vacio = not (vacio_pierde or vacio_roba_reloj) \
			and (GameState.is_tutorial() or not GameState.is_adventure()
				or CampaignData.sea_of(GameState.current_port) >= 2)
	# En las islas del mar 2+ el castigo en oro va DOBLADO (pedido por el
	# usuario): tiene que doler tanto como la calavera del puerto o los 15 s
	# del abordaje, y con la tarifa de la escuela se ignoraba.
	if GameState.is_adventure() and not GameState.is_tutorial() \
			and CampaignData.sea_of(GameState.current_port) >= 2:
		c.leave_penalty_mult = 2.0
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
	# Estorbo del arcade "la clientela llega quemada": entran con la paciencia
	# ya empezada (la barra nace al 80%).
	if estorbo_impacientes:
		c.patience = c.patience_max * 0.8
	if not collectible_client.is_empty() and treasure_client == null \
			and c.who_override == str(collectible_client.get("who", "")):
		treasure_client = c
	clients_spawned += 1
	# El contador y la fila de cabezas suben cuando el cliente SE SIENTA.
	c.seated.connect(func() -> void:
		clients_seated += 1
		_update_client_heads())
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
	# El VACÍO se cuenta aparte del castigo en oro: en puertos y abordajes el
	# oro no se toca (penalty 0) pero el vacío sigue contando para su hándicap.
	# El cliente calculó su castigo con el contador de ANTES de irse; el
	# siguiente que se marche de vacío pagará un escalón más.
	if bool(report.get("vacio", penalty > 0)):
		empty_leavers += 1
		# PUERTO: al tercer vacío se pierde el escenario, como en el arcade.
		if vacio_pierde:
			_update_vacios_puerto()
			if empty_leavers >= VACIOS_MAX and not ended:
				lost_by_leavers = true
				_end_level()
				return
		# ABORDAJE: cada vacío roba reloj, y se canta junto al contador.
		if vacio_roba_reloj and timed and not ended:
			time_limit = maxf(time_limit - CASTIGO_VACIO_SEG, elapsed)
			_flash_castigo_reloj()
	clients_finished += 1
	_update_client_heads()
	_update_hud()
	# ARCADE: la vida son los vacíos. Al tercero que se va sin probar bocado,
	# se acabó la partida (no hay reloj que agotar: se pierde el control).
	if arcade:
		_update_arcade_hud()
		if empty_leavers >= VACIOS_MAX and not ended:
			_end_level()
			return
	# En las islas y los puertos el turno lo acota la CLIENTELA: cuando se va el
	# último, se acabó el trabajo. En los abordajes no, que siguen entrando.
	if not unlimited and clients_finished >= total_clients:
		_end_level()


## Cada plato comido: solo el PRECIO cuenta como dinero generado (estrellas y
## monedero). La propina va unicamente al bote de potenciadores.
func _on_client_served(food: int, tip: int) -> void:
	money_earned += food
	Audio.sfx("moneda")
	if tip > 0:
		# La propina NO suena aparte: cae en el mismo instante que el pago del
		# plato y se oían dos monedas encima de la otra.
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
	if not _reto_cumplido():
		return
	_entregar_tesoro()


## ¿Ha cumplido el cliente del tesoro lo que pedía? Sin `reto` en el puerto es
## "N platos", que es como funcionaba antes de que existieran los encargos.
## `hasta_el_final` NO se mira aquí: ese se resuelve al cerrar el turno.
func _reto_cumplido() -> bool:
	var cfg := collectible_client
	var reto := str(cfg.get("reto", "platos"))
	var n := int(cfg.get("n", cfg.get("plates", 3)))
	var comidos: Array = treasure_client.eaten_ids
	match reto:
		"distintos":
			var vistos := {}
			for id in comidos:
				vistos[id] = true
			return vistos.size() >= n
		"mismo":
			var cuenta := {}
			for id in comidos:
				cuenta[id] = int(cuenta.get(id, 0)) + 1
				if int(cuenta[id]) >= n:
					return true
			return false
		"mismo_caro":
			# N veces el plato MAS CARO de la carta de hoy (el del capitan del
			# mapa, m2_05). El plato objetivo es el mismo que canta el guion.
			var caro := GameState.plato_mas_caro_de_la_carta()
			return comidos.count(caro) >= n
		"receta":
			return str(cfg.get("recipe", "")) in comidos
		"postre_solo":
			# Su ÚNICO plato tiene que ser un postre: en cuanto le entra otra
			# cosa, el encargo se pierde para esta jornada.
			return comidos.size() == 1 and _es_postre(str(comidos[0]))
		"platos_y_postre":
			var principales := 0
			var postre := false
			for id in comidos:
				if _es_postre(str(id)):
					postre = true
				elif not _es_picoteo(str(id)):
					principales += 1
			return postre and principales >= n
		"picoteos":
			return _contar_picoteos(comidos) >= n
		"picoteos_sin_plato":
			# Los picoteos tienen que ir ANTES de cualquier plato: en cuanto
			# aparece uno que no lo es, se corta la cuenta.
			var picos := 0
			for id in comidos:
				if not _es_picoteo(str(id)):
					break
				picos += 1
			return picos >= n
		_:
			return comidos.size() >= n


func _es_postre(id: String) -> bool:
	var r: Dictionary = RecipeData.RECIPES.get(id, {})
	return bool(r.get("leaves_seat", false)) or bool(r.get("tip_always", false))


func _es_picoteo(id: String) -> bool:
	return bool(RecipeData.RECIPES.get(id, {}).get("snack", false))


func _contar_picoteos(ids: Array) -> int:
	var n := 0
	for id in ids:
		if _es_picoteo(str(id)):
			n += 1
	return n


## Suelta la pieza. La anuncia `unlock_collectible` por la capa global de
## avisos, que ya sabe esperar a que el árbol esté en un momento razonable.
func _entregar_tesoro() -> void:
	if treasure_given:
		return
	treasure_given = true
	# El capitán del MAPA (m2_05) paga con un mapa del tesoro, no con pieza de
	# vitrina: suma al contador persistente y se anuncia con un toast.
	if bool(collectible_client.get("mapa", false)):
		GameState.treasure_maps += 1
		GameState.save_game()
		GameState._ensure_notices().toast_achievement(
			load("res://assets/ui/col_mapa_tesoro.png"), Color(1, 0.9, 0.6),
			"¡Mapa del tesoro!", "El capitán ha pagado con un mapa")
		return
	var pieza := str(collectible_client.get("item", ""))
	if pieza != "":
		GameState.unlock_collectible(pieza)


## El reto `hasta_el_final` se resuelve al CERRAR el turno: pide que el cliente
## siga sentado, así que no se puede comprobar antes de que se acabe.
func _check_treasure_al_cerrar() -> void:
	if treasure_given or collectible_client.is_empty():
		return
	if str(collectible_client.get("reto", "platos")) != "hasta_el_final":
		return
	if treasure_client == null or not is_instance_valid(treasure_client):
		return
	if not treasure_client in seat_clients:
		return
	_entregar_tesoro()


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
	# En el arcade el oro no cierra nada: la barra es un hito que se renueva
	# (ver _update_hud), y la partida solo la terminan los vacíos o el jugador.
	if arcade:
		return
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


# --------------------------------------------------------- ARCADE SIN FIN

## Mezcla de clientela por tramo de oleadas: el TONO sube cada cinco — piratas
## desde la 6, capitanes desde la 11 — y es el eje que obliga a subir la carta.
func _arcade_weights() -> Dictionary:
	if wave < 6:
		return { "E": 1 }
	if wave < 11:
		return { "E": 3, "A": 1 }
	if wave < 16:
		return { "E": 2, "A": 2 }
	if wave < 21:
		return { "E": 2, "A": 3, "G": 1 }
	return { "E": 1, "A": 2, "G": 2 }


## El corazón del modo: llegadas continuas, el reloj de la oleada y el fogón.
func _tick_arcade(delta: float) -> void:
	if prep_phase or frozen or ended or clock_hold:
		return
	wave_t += delta
	next_spawn -= delta
	if next_spawn <= 0.0 and _try_spawn_client():
		# El pellizco: cada oleada comprime las llegadas un 2%. Las sillas
		# libres son el tope natural (nadie entra sin taburete).
		next_spawn = arcade_spawn_gap * pow(0.98, wave - 1)
	# Estorbo del FOGÓN: cada tanto, una receta disponible se apaga un rato.
	if fogon_activo:
		fogon_t -= delta
		if fogon_t <= 0.0:
			fogon_t = FOGON_EVERY
			_apagar_fogon()
	if wave_t >= WAVE_TIME:
		_next_wave()
	_try_open_upgrade()


func _next_wave() -> void:
	wave_t = 0.0
	wave += 1
	GameState.bump_stat("arcade_waves")
	# El pellizco de la paciencia (afecta a los que lleguen desde ahora).
	patience_mult *= 0.985
	client_weights = _arcade_weights()
	# LA DESPENSA DE LA OLEADA: 1 uso de cada ingrediente de la carta. Lo que
	# se agote tira sus recetas — la segunda forma de perder.
	var agotados := GameState.consume_wave_ingredients(carta)
	if not agotados.is_empty():
		_drop_recipes_for(agotados)
	# Cada 3 oleadas cae una carta de mejora; cada 10, un estorbo (anunciado
	# una oleada antes, para que dé tiempo a colocarse).
	if wave % 3 == 0:
		pending_upgrades += 1
	if wave % 10 == 9:
		_anunciar_estorbo()
	elif wave % 10 == 0 and estorbo_anunciado != "":
		_aplicar_estorbo(estorbo_anunciado)
		estorbo_anunciado = ""
	else:
		_cartel_oleada("¡Oleada %d!" % wave)
	next_spawn = 0.0
	_update_arcade_hud()


## La tablilla de fase hace de megáfono del arcade: entra, se lee y se va.
func _cartel_oleada(texto: String) -> void:
	phase_label.text = texto
	_show_phase(true)
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.tween_callback(func() -> void:
		# Si mientras tanto ha salido otro cartel, no se pisa.
		if not prep_phase and not frozen:
			_show_phase(false))


## Los ESTORBOS: lastres permanentes sorteados sin repetir. Son la razón de
## que el modo acabe siendo imposible en vez de solo largo, y cada uno usa una
## perilla que el juego ya tenía.
const ESTORBOS: Dictionary = {
	"cinta_rapida": "¡La cinta acelera!",
	"bocado_rapido": "¡Bocados más rápidos!",
	"fogon": "¡Un fogón se apaga a ratos!",
	"cubo_caro": "¡El cubo cobra el doble!",
	"cajas_menos": "¡Las cajas encogen!",
	"impacientes": "¡La clientela llega quemada!",
	"mas_drenaje": "¡La paciencia vuela!",
}
## Clientes que llegan con la paciencia ya empezada (estorbo "impacientes").
var estorbo_impacientes := false


func _anunciar_estorbo() -> void:
	var pool: Array = []
	for id in ESTORBOS:
		if not str(id) in estorbos_usados:
			pool.append(str(id))
	if pool.is_empty():
		_cartel_oleada("¡Oleada %d!" % wave)
		return
	estorbo_anunciado = str(pool[randi() % pool.size()])
	_cartel_oleada("Se acerca: %s" % str(ESTORBOS[estorbo_anunciado]).to_lower())


func _aplicar_estorbo(id: String) -> void:
	estorbos_usados.append(id)
	_cartel_oleada(str(ESTORBOS.get(id, "¡Estorbo!")))
	match id:
		"cinta_rapida":
			belt_base = 1.3
			belt_mult = maxf(belt_mult, belt_base)
		"bocado_rapido":
			bite_speed_mult *= 1.2
		"fogon":
			fogon_activo = true
			fogon_t = FOGON_EVERY * 0.5
		"cubo_caro":
			waste_frac *= 2.0
		"cajas_menos":
			prep_board.stack_max = maxi(prep_board.stack_max - 1, 2)
		"impacientes":
			estorbo_impacientes = true
		"mas_drenaje":
			patience_mult *= 0.9


## El fogón apagado: una receta DISPONIBLE entra en enfriamiento forzoso.
func _apagar_fogon() -> void:
	var vivas: Array[String] = []
	for id in carta:
		if prep_board.cooldowns.get(id, 0.0) <= 0.0:
			vivas.append(id)
	if vivas.is_empty():
		return
	var id: String = vivas[randi() % vivas.size()]
	prep_board.cooldowns[id] = maxf(float(prep_board.cooldowns.get(id, 0.0)),
		FOGON_OFF)
	prep_board._flash_message("¡Fogón apagado!", Color(1.0, 0.5, 0.35))


## Ingredientes agotados → sus recetas se CAEN de la carta (se quedan apagadas
## en la fila, como las vetadas del tutorial). Sin carta no hay variedad, y
## sin variedad llegan los vacíos: la partida se desmorona, no se apaga.
func _drop_recipes_for(agotados: Array) -> void:
	var fuera: Array[String] = []
	for id in carta:
		for ing in RecipeData.get_ingredients(id):
			if str(ing) in agotados:
				fuera.append(id)
				break
	if fuera.is_empty():
		return
	for id in fuera:
		carta.erase(id)
	prep_board._flash_message("¡Despensa agotada: fuera %s!"
		% str(RecipeData.get_recipe(fuera[0]).get("name", fuera[0])),
		Color(1.0, 0.5, 0.35))
	# La lista de permitidas gobierna el apagado de los botones. Con la carta
	# vacía se pone un centinela: una lista vacía significa "todas".
	prep_board.allowed_recipes = carta.duplicate() if not carta.is_empty() \
			else ["__ninguna__"]


# ---------------------------------------------- mejoras de partida (arcade)

## Cada 3 oleadas: tres cartas y eliges una, para TODA la partida. Reutiliza
## el cartel de potenciadores (pausa el juego, tres tarjetas, dibujo y
## título). Regla del modo: ninguna mejora toca el PRECIO de los platos.
func _try_open_upgrade() -> void:
	if pending_upgrades <= 0 or powerup_panel.visible or ended:
		return
	if prep_board.is_gesture_locked():
		return
	_open_upgrade_choice()


## El fondo de mejoras DISPONIBLES ahora mismo: cada entrada trae etiqueta,
## icono (se reciclan los dibujos de los potenciadores) y su efecto.
func _upgrade_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	var pot := func(pid: String) -> String:
		return str(PowerupData.get_powerup(pid).get("icon", ""))
	# FICHAJE: una receta del recetario que se pueda PAGAR (si falta su
	# ingrediente, no se ofrece). Desde su oleada, su despensa se cobra igual.
	var fichables: Array[String] = []
	for rid in GameState.unlocked_recipes:
		if rid in carta:
			continue
		var d := RecipeData.get_recipe(rid)
		if d.is_empty() or d.get("hidden", false):
			continue
		if not GameState.has_ingredients_for(rid):
			continue
		fichables.append(rid)
	if not fichables.is_empty():
		var rid: String = fichables[randi() % fichables.size()]
		pool.append({ "id": "fichaje:%s" % rid,
			"title": "Ficha: %s" % str(RecipeData.get_recipe(rid).get("name", rid)),
			"icon": "res://assets/dishes/%s.webp" % rid })
	# MAESTRÍA +1 de una receta de la carta que ya la tenga.
	var con_maestria: Array[String] = []
	for rid in carta:
		if int(RecipeData.get_recipe(rid).get("free_uses", 0)) > 0:
			con_maestria.append(rid)
	if not con_maestria.is_empty():
		var rid: String = con_maestria[randi() % con_maestria.size()]
		var uid := "maestria:%s" % rid
		if not uid in upgrades_cogidas:
			pool.append({ "id": uid,
				"title": "%s: una pieza más" % str(RecipeData.get_recipe(rid).get("name", rid)),
				"icon": "res://assets/dishes/%s.webp" % rid })
	# El resto del fondo, filtrado por disponibilidad.
	var fijos: Array[Dictionary] = [
		{ "id": "cd_l1", "title": "Platos de 1★ un 30% más rápidos",
			"icon": pot.call("receta_instantanea") },
		# El icono va a pelo: su potenciador ("Más almacén") se retiró porque
		# chocaba con la maestría de las cajas, pero el dibujo sigue valiendo.
		{ "id": "caja_extra", "title": "Una caja más",
			"icon": "res://assets/ui/pot_almacen.png" },
		{ "id": "pila_extra", "title": "Las cajas guardan uno más",
			"icon": "res://assets/ui/pot_almacen.png" },
		{ "id": "cinta_lenta", "title": "La cinta va más despacio",
			"icon": pot.call("cinta_rapida") },
		{ "id": "vuelta_extra", "title": "Los platos aguantan una vuelta más",
			"icon": pot.call("sin_basura") },
		{ "id": "paciencia", "title": "+15% de paciencia desde ahora",
			"icon": pot.call("clientes_pacientes") },
		{ "id": "postre_doble", "title": "Los postres cobran doble",
			"icon": pot.call("sobremesa") },
	]
	for f in fijos:
		if str(f["id"]) in upgrades_cogidas:
			continue
		pool.append(f)
	# El ayudante entra a trabajar (si no está ya), y su descanso se recorta.
	if helper_pivot == null and not "ayudante" in upgrades_cogidas:
		pool.append({ "id": "ayudante", "title": "El ayudante entra a trabajar",
			"icon": str(PerkData.get_perk("ayudante").get("icon", "")) })
	elif helper_pivot != null and not "ayudante_veloz" in upgrades_cogidas:
		pool.append({ "id": "ayudante_veloz",
			"title": "El ayudante descansa la mitad",
			"icon": str(PerkData.get_perk("ayudante").get("icon", "")) })
	# Un vacío perdonado: recuperar una calavera (repetible, solo si hay).
	if empty_leavers > 0:
		pool.append({ "id": "perdon", "title": "Un vacío perdonado",
			"icon": pot.call("variedad_extra") })
	return pool


func _open_upgrade_choice() -> void:
	for child in powerup_options.get_children():
		child.queue_free()
	var pool := _upgrade_pool()
	pool.shuffle()
	if pool.is_empty():
		# Sin nada que ofrecer (todo cogido): la mejora se pierde sin cartel.
		pending_upgrades -= 1
		return
	for i in mini(3, pool.size()):
		powerup_options.add_child(_make_upgrade_card(pool[i]))
	_montar_cartel_potenciadores(true)
	powerup_panel.visible = true
	Audio.sfx("potenciador")
	get_tree().paused = true
	_animate_powerup_panel()


## Tarjeta de mejora: mismo formato que las de potenciador (dibujo + título).
func _make_upgrade_card(entry: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, POWERUP_CARD_H)
	prep_board.skin_button(b)
	b.pressed.connect(_on_upgrade_chosen.bind(str(entry["id"])))
	var margen := (POWERUP_CARD_H - POWERUP_ICON) * 0.5
	var icono := TextureRect.new()
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var ruta := str(entry.get("icon", ""))
	if ResourceLoader.exists(ruta):
		icono.texture = load(ruta)
	icono.position = Vector2(margen, margen)
	icono.size = Vector2(POWERUP_ICON, POWERUP_ICON)
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icono)
	var titulo := Label.new()
	titulo.text = str(entry.get("title", ""))
	titulo.add_theme_font_size_override("font_size", 26)
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	titulo.offset_left = margen * 2.0 + POWERUP_ICON
	titulo.offset_right = -margen
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(titulo)
	return b


func _on_upgrade_chosen(uid: String) -> void:
	pending_upgrades -= 1
	_apply_upgrade(uid)
	_update_arcade_hud()
	if pending_upgrades > 0:
		_open_upgrade_choice()
	elif pending_powerups > 0:
		_open_powerup_choice()
	else:
		powerup_panel.visible = false
		get_tree().paused = false


func _apply_upgrade(uid: String) -> void:
	if uid.begins_with("fichaje:"):
		var rid := uid.substr(8)
		carta.append(rid)
		prep_board.add_recipe(rid)
		# Si la lista de permitidas está en marcha (hubo caídas), el fichaje
		# entra en ella o nacería apagado.
		if not prep_board.allowed_recipes.is_empty():
			prep_board.allowed_recipes = carta.duplicate()
		return
	if uid.begins_with("maestria:"):
		upgrades_cogidas.append(uid)
		var rid := uid.substr(9)
		prep_board.mastery_bonus[rid] = int(prep_board.mastery_bonus.get(rid, 0)) + 1
		return
	upgrades_cogidas.append(uid)
	match uid:
		"cd_l1":
			prep_board.cooldown_l1_mult = 0.7
		"caja_extra":
			prep_board.add_storage_slot()
		"pila_extra":
			prep_board.stack_max += 1
		"cinta_lenta":
			belt_base = minf(belt_base, 0.85)
			if belt_timer <= 0.0:
				belt_mult = belt_base
		"vuelta_extra":
			plate_laps += 1
		"paciencia":
			patience_mult *= 1.15
			for c in seat_clients:
				if c != null:
					c.boost_patience(0.15)
		"postre_doble":
			dessert_boost_perm = true
		"ayudante":
			prep_board.helper_rest = GameState.perk_value("ayudante") \
					if GameState.is_perk_unlocked("ayudante") else 30.0
			prep_board._build_helper_button()
			_setup_helper()
		"ayudante_veloz":
			prep_board.helper_rest *= 0.5
			# "perdon" es repetible: no entra en cogidas.
		"perdon":
			upgrades_cogidas.erase("perdon")
			empty_leavers = maxi(empty_leavers - 1, 0)


# ----------------------------------------------------- HUD y fin del arcade

## Fila propia bajo el marcador: oleada, oleadas de despensa que quedan y los
## vacíos. La despensa se enseña porque el jugador puede ACTUAR sobre ella
## (soltar una receta cara, fichar barato); los vacíos son la vida.
func _setup_arcade_hud() -> void:
	arcade_row = HBoxContainer.new()
	arcade_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	arcade_row.offset_top = 104.0 + GameState.safe_top()
	arcade_row.offset_bottom = 140.0 + GameState.safe_top()
	arcade_row.alignment = BoxContainer.ALIGNMENT_CENTER
	arcade_row.add_theme_constant_override("separation", 30)
	arcade_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(arcade_row)
	oleada_label = _arcade_hud_label(Color(1.0, 0.92, 0.6))
	despensa_label = _arcade_hud_label(Color(0.85, 0.95, 1.0))
	vacios_label = _arcade_hud_label(Color(1.0, 0.75, 0.7))
	for l in [oleada_label, despensa_label, vacios_label]:
		arcade_row.add_child(l)
	_update_arcade_hud()


func _arcade_hud_label(color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	l.add_theme_constant_override("outline_size", 9)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Última cifra pintada de cada marcador, para animar solo los CAMBIOS.
var _hud_wave_last := 1
var _hud_vacios_last := 0
var _hud_despensa_last := 999


func _update_arcade_hud() -> void:
	if oleada_label == null:
		return
	oleada_label.text = "Oleada %d" % wave
	# La oleada nueva da un bote (la cifra es la noticia del modo).
	if wave != _hud_wave_last:
		_hud_wave_last = wave
		_hud_pop(oleada_label)
	var quedan := GameState.pantry_waves_left(carta)
	despensa_label.text = "Despensa: %s" % ("∞" if quedan >= 999 else str(quedan))
	despensa_label.add_theme_color_override("font_color",
		Color(1.0, 0.55, 0.4) if quedan <= 2 else Color(0.85, 0.95, 1.0))
	# Al entrar en la reserva corta, un parpadeo de aviso.
	if quedan <= 2 and _hud_despensa_last > 2:
		_hud_blink(despensa_label)
	_hud_despensa_last = quedan
	vacios_label.text = "Vacíos %d/%d" % [empty_leavers, VACIOS_MAX]
	vacios_label.add_theme_color_override("font_color",
		Color(1.0, 0.35, 0.3) if empty_leavers >= VACIOS_MAX - 1
		else Color(1.0, 0.75, 0.7))
	# Cada vacío nuevo SACUDE su contador: es la vida bajando.
	if empty_leavers > _hud_vacios_last:
		_hud_vacios_last = empty_leavers
		_hud_shake(vacios_label)


func _hud_pop(l: Label) -> void:
	l.pivot_offset = l.size * 0.5
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(1.35, 1.35), 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hud_blink(l: Label) -> void:
	var tw := l.create_tween()
	for i in 3:
		tw.tween_property(l, "modulate:a", 0.25, 0.12)
		tw.tween_property(l, "modulate:a", 1.0, 0.12)


func _hud_shake(l: Label) -> void:
	# Sacudida por ROTACIÓN y escala, no por posición: el HBoxContainer es el
	# dueño de la posición de sus hijos y un tween sobre ella pelearía con él.
	l.pivot_offset = l.size * 0.5
	var tw := l.create_tween()
	tw.tween_property(l, "modulate", Color(1.6, 0.5, 0.4), 0.08)
	tw.parallel().tween_property(l, "scale", Vector2(1.35, 1.35), 0.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for ang in [8.0, -7.0, 5.0, -3.0, 0.0]:
		tw.tween_property(l, "rotation_degrees", ang, 0.05)
	tw.tween_property(l, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate", Color.WHITE, 0.3)


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
	var nuevos := false
	while tips_total >= _tip_threshold(powerups_claimed):
		powerups_claimed += 1
		pending_powerups += 1
		nuevos = true
	# NO se abre aquí: se deja el respiro para que la barra del bote se pinte
	# llena ANTES de que el cartel pause el juego (lo abre `_process`).
	if nuevos:
		powerup_delay = maxf(powerup_delay, 0.65)


## Saca el cartel de potenciador SOLO si no pilla al jugador en mitad de un
## gesto que hay que sostener (ver prep_board.is_gesture_locked): pausar el
## juego ahi le arruinaria la receta. Si toca esperar, `_process` lo reintenta
## en cuanto suelta el dedo.
func _try_open_powerup_choice() -> void:
	if pending_powerups <= 0 or powerup_panel.visible or ended:
		return
	if prep_board.is_gesture_locked():
		return
	# El respiro de la barra (ver `powerup_delay`).
	if powerup_delay > 0.0:
		return
	# NI ENCIMA DE UN DIÁLOGO NI DE UN AVISO MODAL: el cartel espera a que el
	# guion (o la ventana de coleccionable) termine y sale después.
	if GameState.notices_busy() or _guion_hablando():
		return
	_open_powerup_choice()


## ¿Está hablando algún guion de este nivel?
## (los enganches del rush viven donde ocurre cada suceso: el plato comido en
## client3d._apply_meal_patience, el cubo en _on_plate_discarded y el corte
## fallado en la señal money_penalty de la tabla.)
func _guion_hablando() -> bool:
	for hijo in get_children():
		if hijo is StoryDirector and hijo.dialog != null \
				and is_instance_valid(hijo.dialog) and hijo.dialog.is_talking():
			return true
	return false


## APLAZA el cartel de potenciador: lo cierra y lo vuelve a encolar. Lo llama
## el guion justo antes de hablar (`story_director._say`): un diálogo encima
## del cartel eran dos pausas peleando, y al terminar el guion despausaba el
## árbol con el cartel aún puesto — el juego corría por debajo de la elección.
func postpone_powerup_choice() -> void:
	if powerup_panel == null or not powerup_panel.visible:
		return
	powerup_panel.visible = false
	pending_powerups += 1
	powerup_delay = 0.8
	get_tree().paused = false


## Alto de cada tarjeta y tamaño del dibujo que la encabeza.
const POWERUP_CARD_H := 148.0
const POWERUP_ICON := 104.0
## Arte EXCLUSIVO del cartel de potenciadores (`tools/ui2_prep.build_potenciadores`):
## la caja de madera oscura con oro del bote y las cartas de pergamino.
const POT_CARTA_TEX := "res://assets/ui/pot_carta.png"
## Medida de la carta EN PANTALLA. Su proporción es la del dibujo (0.690), y
## el ancho sale del reparto: 600 de hueco − 2 huecos de 12, entre tres.
const POT_CARTA := Vector2(200.0, 290.0)


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
	_montar_cartel_potenciadores(false)
	powerup_panel.visible = true
	Audio.sfx("potenciador")
	get_tree().paused = true
	_animate_powerup_panel()
	_armar_powerups()


## LAS TARJETAS SE ARMAN CON RETARDO (pedido por el usuario): el cartel sale
## en mitad de la partida, y el jugador puede estar dando golpes en la tabla a
## toda velocidad — sin esto, el toque que llevaba en el aire elegía por él un
## potenciador que no había ni leído. Es la misma medida que el plato de la
## tabla (`prep_board.DISH_ARM`) y que los botones que nacen bajo el dedo.
##
## Y SE VE: mientras no están vivas, las tarjetas van a media luz y se
## encienden al armarse — así el retardo se lee como "espera, que están
## llegando" y no como un toque perdido. El temporizador va en modo SIEMPRE:
## el árbol está en pausa mientras el cartel está puesto.
func _armar_powerups() -> void:
	var cartas: Array = powerup_options.get_children()
	for c in cartas:
		if c is Button:
			c.disabled = true
			c.modulate = Color(1, 1, 1, 0.55)
	var t := get_tree().create_timer(POWERUP_ARM, true, false, true)
	t.timeout.connect(func() -> void:
		for c in cartas:
			if not is_instance_valid(c) or not (c is Button):
				continue
			c.disabled = false
			c.create_tween().tween_property(c, "modulate", Color.WHITE, 0.18))


## Lo que tarda el cartel de potenciador en aceptar un toque (ver
## `_armar_powerups`). Cuadra con su animación de entrada, que dura 0.42 s.
const POWERUP_ARM := 0.55


## UNA TARJETA DE POTENCIADOR, EN VERTICAL (rediseño pedido por el usuario):
## NOMBRE arriba, DIBUJO en medio y DESCRIPCIÓN debajo, en ese orden. Las tres
## van una junto a otra, así que se comparan de un vistazo: antes eran filas
## horizontales (dibujo a la izquierda, texto a la derecha) y con el juego
## parado se leían como tres renglones de menú.
##
## La carta tiene su propia textura (`POT_CARTA_TEX`, pergamino con marco de
## oro sobre la madera del panel), no el tablón de `skin_button`: lo que se
## elige aquí no es un botón más de la interfaz.
func _make_powerup_card(id: String) -> Button:
	var data := PowerupData.get_powerup(id)
	return _card_vertical(str(data.get("name", id)), str(data.get("icon", "")),
		str(data.get("desc", "")), _on_powerup_chosen.bind(id))


func _card_vertical(nombre: String, icono_ruta: String, desc: String,
		al_pulsar: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, POT_CARTA.y)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	# ENTERA Y A SU PROPORCIÓN, no 9-slice: sus herrajes sobresalen del marco
	# recto, así que estirar las bandas del medio dejaría franjas
	# transparentes por los cantos (ver `ui2_prep.build_pot_carta`). Por eso
	# la carta mide POT_CARTA (192x278), que es su proporción exacta.
	var fondo := TextureRect.new()
	fondo.texture = load(POT_CARTA_TEX)
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_SCALE
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(fondo)
	PrepBoard.add_press_feedback(b)
	b.pressed.connect(al_pulsar)

	# Los márgenes salen del MARCO de la carta (medido sobre el dibujo: 9.1%
	# del ancho por los lados y 7.7% del alto por arriba), para que el texto
	# caiga dentro del pergamino y no encima de la madera.
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 22.0
	col.offset_right = -22.0
	col.offset_top = 26.0
	col.offset_bottom = -26.0
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)

	var titulo := Label.new()
	titulo.text = nombre
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", Color(0.30, 0.18, 0.06))
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		titulo.add_theme_font_override("font", negrita)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo.custom_minimum_size = Vector2(0, 56)
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(titulo)

	var icono := TextureRect.new()
	# EXPAND_IGNORE_SIZE antes de asignar la textura, o el mínimo salta al
	# tamaño nativo del dibujo y deforma la tarjeta.
	icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(icono_ruta):
		icono.texture = load(icono_ruta)
	icono.custom_minimum_size = Vector2(0, POWERUP_ICON)
	icono.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icono)

	var l := Label.new()
	l.text = desc
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(0.42, 0.28, 0.14))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# TRES renglones de sitio: con dos, la última línea se cortaba a media
	# altura en las descripciones más largas (medido en captura).
	l.custom_minimum_size = Vector2(0, 86)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(l)
	return b


## COLOCA EL CARTEL según lo que lleve dentro. Los POTENCIADORES van en tres
## cartas VERTICALES, una al lado de otra (panel ancho y bajo); las MEJORAS
## del arcade siguen en filas horizontales —sus rótulos son frases enteras y
## en una carta estrecha no se leerían— y piden el panel alto de siempre.
func _montar_cartel_potenciadores(filas: bool) -> void:
	powerup_options.vertical = filas
	# El rótulo dice lo que se está eligiendo: el cartel es el mismo, pero el
	# bote de propinas y la mejora de oleada del arcade no son lo mismo.
	var t: Label = $HUD/PowerupPanel/VBox/Title
	t.text = "¡Mejora de oleada! Elige una" if filas 		else "¡Bote lleno! Elige un potenciador"
	powerup_options.add_theme_constant_override("separation", 18 if filas else 12)
	var vb: Control = $HUD/PowerupPanel/VBox
	vb.offset_left = 66.0 if filas else 18.0
	vb.offset_right = -66.0 if filas else -18.0
	# Sin panel de fondo, el alto solo tiene que dar para el rótulo y la fila
	# de cartas: 72 (margen del VBox) + 40 (título) + 18 + 290 + 60.
	var alto := 700.0 if filas else 480.0
	var medio: float = GameState.canvas_size().y * 0.5
	powerup_panel.offset_top = medio - alto * 0.5
	powerup_panel.offset_bottom = medio + alto * 0.5


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
	_marcar_potenciador(id)
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

## FAMA DEL PLATO: cuántos platos de cada receta han salido a la cinta en
## ESTA jornada. Lo lee `client3d._scan_belt` para subir el dado de las
## recetas con "fama" (el nigiri de salmón y su corona). Es de la jornada:
## nace vacío con el nivel y muere con él.
var platos_receta: Dictionary = {}


func _on_dish_served(recipe_id: String, price_override: int = 0, extras: Array = [],
		level_override: int = 0, eat_mult_override: float = 0.0) -> void:
	platos_receta[recipe_id] = int(platos_receta.get(recipe_id, 0)) + 1
	var p: PathFollow3D = PLATE3D.new()
	p.recipe_id = recipe_id
	# El barco combinado vale lo que valen los platos que lleva dentro.
	p.price_override = price_override
	p.extras = extras
	p.level_override = level_override
	p.eat_mult_override = eat_mult_override
	p.only_who = str(exclusive_dishes.get(recipe_id, ""))
	p.only_type = str(exclusive_types.get(recipe_id, ""))
	p.speed = PLATE_SPEED
	# Maestrías del plato en cinta: vueltas extra, olvido por vuelta y la marca
	# del "Golpe de suerte" (la tabla la expone solo durante su emit).
	p.max_laps = plate_laps
	p.forget_each_lap = plate_forget_lap
	p.variety_bonus = prep_board.serving_lucky
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


## EL OLOR DEL BARBO ("neighbor_mult"): baja (o sube) el multiplicador de los
## clientes sentados en las sillas PEGADAS a la de `origen` — una a cada lado,
## esquinas incluidas. Vecino = taburete a menos de OLOR_RADIO en el plano:
## dentro de un lado los taburetes distan 1,8 u y doblando la esquina 2,69,
## mientras que el siguiente ya se va a 4,2 — el corte en 3 separa limpio.
const OLOR_RADIO := 3.0
func aplicar_olor_vecinos(origen: Node, delta_mult: int) -> void:
	for c in seat_clients:
		if c == null or not is_instance_valid(c) or c == origen:
			continue
		if not c.ya_sentado():
			continue
		var d := Vector2(c.global_position.x - origen.global_position.x,
			c.global_position.z - origen.global_position.z)
		if d.length() > OLOR_RADIO:
			continue
		if delta_mult < 0 and c.variety <= 0:
			continue
		c._set_variety(maxi(c.variety + delta_mult, 0), delta_mult > 0)
		c._float_text("¡Puaj! %d" % delta_mult if delta_mult < 0
			else "+%d" % delta_mult, Color(0.72, 0.85, 0.42))


## CONTAGIO ("contagio" de la receta, el dashi ahumado): cuando alguien lo
## come, TODOS los demas sentados ganan o pierden esa fraccion de su paciencia
## maxima. A diferencia del olor del barbo (multiplicador, solo vecinos), esto
## toca la PACIENCIA y llega a la mesa entera.
func aplicar_contagio(origen: Node, frac: float) -> void:
	for c in seat_clients:
		if c == null or not is_instance_valid(c) or c == origen:
			continue
		if not c.ya_sentado():
			continue
		c.boost_patience(frac)


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
	# Un plato al cubo rompe la cadena del SUSHI RUSH (y apaga el rush).
	note_rush_fail()
	# El plato volcándose en el cubo. Suena aunque el castigo esté perdonado
	# ("Nada se tira"): lo que se oye es el plato cayendo, no la multa.
	Audio.sfx("basura")
	# Logro "aquí no se tira nada": la partida deja de ser limpia.
	plates_wasted += 1
	# DÓNDE ha caído, para que el guion del nivel 1 pueda enfocar el cubo
	# con el plato todavía volcándose dentro.
	if plate != null and is_instance_valid(plate):
		trash_pos = plate.global_position
	var price: int = RecipeData.get_recipe(recipe_id).get("price", 0)
	# Siempre cuesta algo: hasta el plato más barato se cobra un doblón. La
	# fracción sale de la maestría "Segunda vuelta" (y el estorbo del arcade
	# "el cubo cobra el doble" la duplica).
	var castigo: int = maxi(int(round(price * waste_frac)), 1)
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
	# La sirena de fin de jornada. Va la primera, antes de los cuatro segundos
	# con todo parado, para que se oiga sobre la partida y no sobre el cartel.
	if not ended:
		Audio.sfx("fin_turno")
		Audio.loops_off()
	if ended:
		return
	# El tutorial no termina ni por reloj ni por clientes: termina su guion
	# (tutorial_director cierra con complete_tutorial y vuelve al menú).
	if GameState.is_tutorial():
		return
	ended = true
	# El SUSHI RUSH muere con el turno (y la cámara vuelve a su sitio).
	if rush_active:
		_rush_off()
	# Y el canto también: nadie se queda atontado sobre el cartel de fin.
	if canto_activo:
		_terminar_canto()
	if cam != null:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
	# UN CARTEL DE POTENCIADOR ABIERTO MUERE CON EL TURNO: pausaba el árbol y,
	# con el nivel acabándose por debajo, el juego se quedaba clavado en la
	# elección — el jugador ya no tiene partida en la que gastar lo elegido.
	# Los pendientes se descartan por lo mismo.
	pending_powerups = 0
	if powerup_panel != null and powerup_panel.visible:
		powerup_panel.visible = false
		get_tree().paused = false
	# El encargo de "que siga sentado cuando acabe el turno" solo se puede
	# resolver AQUÍ, y antes de que la barra se vacíe.
	_check_treasure_al_cerrar()
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
	# En el arcade no hay estrellas: su marcador es la OLEADA (y el star_money
	# es el hito renovable de la barra, que aquí no significa nada).
	if not arcade:
		for threshold in star_money:
			if _star_money() >= int(threshold):
				stars += 1
	# NIVEL CON JEFE: la 3ª ESTRELLA ES EL JEFE, no un umbral de oro (pedido
	# por el usuario). Las dos primeras siguen siendo de dinero; rendirlo suma
	# la tercera. Perder el duelo (5 calaveras) pierde la jornada entera, y
	# cerrar sin haberlo rendido —el reloj, antes de que saliera— no aprueba.
	if boss_id != "":
		if boss_lost:
			stars = 0
		elif boss_done:
			stars = mini(stars, 2) + 1
		else:
			stars = mini(stars, 1)
	# DERROTA POR VACÍOS (el hándicap del puerto): da igual el oro que hubiera
	# en caja — tres clientes yéndose sin comer pierden la jornada entera.
	if lost_by_leavers:
		stars = 0

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
	last_xp = 0
	last_xp_extra = 0
	if GameState.is_adventure():
		# LA EXPERIENCIA SE PAGA CONTRA EL RÉCORD, así que se calcula con las
		# estrellas de ANTES de apuntarlas (complete_port las pisa después):
		# mejorar de 2★ a 3★ cobra solo la diferencia.
		var prev_stars := int(GameState.level_stars.get(GameState.current_port, 0))
		last_xp = GameState.scenario_xp(GameState.current_port, stars, prev_stars)
		# PRIMA POR EL ORO DE MÁS: lo que pase del objetivo paga experiencia
		# extra a la tarifa del propio escenario (ver `scenario_extra_xp`).
		last_xp_extra = GameState.scenario_extra_xp(
			GameState.current_port, last_xp, total_money)
		last_xp += last_xp_extra
		GameState.money += total_money
		GameState.record_level_score(GameState.current_port, total_money)
		# LOS BONIFICADORES SE MIRAN ANTES DE `complete_port`, y esto no es un
		# detalle: `complete_port` apunta las estrellas de ESTE escenario, y las
		# compuertas de los bonificadores se leen justo de ahí. Calculado
		# después, superar el escenario 17 abría el sistema y en el mismo
		# fotograma cobraba los combos hechos DENTRO del 17, así que el jugador
		# llegaba al 18 con "Cocina veloz" ya puesta sin haberla ganado con el
		# sistema abierto. Se gana A PARTIR del escenario que lo presenta.
		var perks_nuevos := _check_perk_unlocks()
		new_recipes = GameState.complete_port(GameState.current_port, stars)
		for p in perks_nuevos:
			new_recipes.append({ "perk": p })
	elif GameState.is_arcade():
		# ARCADE: el oro generado va ENTERO al monedero (es una jornada de
		# verdad, pagada con arroz y despensa) y la experiencia sale de las
		# oleadas SUPERADAS (la que estaba a medias no cuenta).
		var oleadas := maxi(wave - 1, 0)
		last_xp = GameState.arcade_xp(oleadas)
		GameState.money += total_money
		GameState.record_arcade_wave(oleadas)
	# Logros: los récords de dinero van por modo, el acumulado suma los dos.
	GameState.max_stat("best_money_%s" % ("level" if GameState.is_adventure()
		else "arcade"), total_money)
	GameState.bump_stat("money_total", total_money)
	GameState.max_stat("best_dishes_run", dishes_served)
	# Estas dos son las que sueltan sus COLECCIONABLES (ver CollectibleData):
	# el delantal chamuscado cuenta los platos tirados de toda la vida y la
	# campana el mejor bote de propinas de UNA jornada.
	GameState.bump_stat("plates_wasted", plates_wasted)
	GameState.max_stat("best_tips_run", tips_total)
	if plates_wasted == 0 and dishes_served > 0:
		GameState.bump_stat("clean_runs")
	# EL DIENTE DEL KAPPA: se cae cuando el jefe se rinde, no cuando el nivel
	# se cierra por objetivo — de ahí que cuelgue de `boss_done` y no de las
	# estrellas del puerto.
	if boss_done:
		GameState.bump_stat("bosses_beaten")
		# Y la stat DEL JEFE concreto, que es de la que cuelga su trofeo
		# (`CollectibleData.BOSS_ITEMS`).
		GameState.bump_stat("boss_%s" % boss_id)
		# EL KAPPA PAGA EN EL MAPA (pedido por el usuario): medio dormido, con
		# 2 lingotes y su diente. La escena la representa main_menu; hasta que
		# corra, el trofeo no cae por la vía de la stat (ver el filtro de
		# `_run_achievement_check`).
		if boss_id == "kappa" and not GameState.kappa_outro_done:
			GameState.pending_kappa = true
	# La experiencia del cocinero, con su toast de subida si toca. Va antes del
	# save para que el nivel nuevo viaje en el mismo guardado.
	GameState.add_chef_xp(last_xp)
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
	# La MISMA estrella, mas aguda con cada una: la primera al 75% de
	# velocidad, la segunda al 85% y la tercera a velocidad normal. Se oye
	# subir la jornada.
	Audio.sfx("estrella", 0.0, [0.75, 0.85, 1.0][clampi(idx, 0, 2)])
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


## NINGÚN GUION HABLA YA CON EL CARTEL DE RESULTADOS PUESTO. La caja del
## director solo la cierra su `_play`, y un guion que termine su última tanda
## sin llamarlo deja el pergamino encima del cartel tragándose TODOS los toques:
## el jugador no puede pulsar "Continuar" ni cerrar las ventanas de subida de
## nivel o de receta nueva. Pasó dos veces con el duelo del Kappa (la derrota y
## la victoria), así que se cierra aquí también: a estas alturas del turno no
## queda nada que decir, y esto cubre cualquier guion que se escriba mañana.
func _cerrar_cajas_de_guion() -> void:
	for hijo in get_children():
		if not (hijo is StoryDirector):
			continue
		if hijo.dialog != null and is_instance_valid(hijo.dialog):
			hijo.dialog.close()


func _show_results(stars: int, total_money: int, new_recipes: Array) -> void:
	_cerrar_cajas_de_guion()
	Audio.sfx("recurso")
	# LA JORNADA TIENE SU PROPIO TEMA. Se pide aquí y no al montar una
	# pantalla porque el cartel de resultados no es una pantalla: sale
	# encima del nivel, que sigue montado debajo.
	Audio.musica("resultados", Audio.CRUCE_FINAL)
	# El juego se dirige al jugador por su nombre (Opciones); sin nombre usa el
	# tratamiento que toque por el género elegido.
	for c in stars_row.get_children():
		c.queue_free()
	if arcade:
		# El cartel del arcade habla de OLEADAS, no de estrellas: la alcanzada
		# en grande y el récord debajo (con su "¡Récord!" si acaba de caer).
		star_slots.clear()
		var oleadas := maxi(wave - 1, 0)
		var l := Label.new()
		l.text = "Oleada %d" % oleadas if oleadas < GameState.arcade_best \
			else "Oleada %d  ·  ¡Récord!" % oleadas
		if oleadas < GameState.arcade_best:
			l.text += "   (récord: %d)" % GameState.arcade_best
		l.add_theme_font_size_override("font_size", 34)
		l.add_theme_color_override("font_color", Color(0.42, 0.26, 0.10))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.process_mode = Node.PROCESS_MODE_ALWAYS
		stars_row.add_child(l)
	else:
		_build_star_slots()
	_build_xp_row()
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
	# LA EXPERIENCIA SE LLENA AQUÍ, no en el menú: el jugador está mirando este
	# cartel. Al terminar se consume `xp_anim_from`, así que la barra del menú
	# aparecerá ya llena (antes se llenaba allí, con el jugador a otra cosa).
	await _play_xp_gain()
	_reveal_recipes(new_recipes)


# ------------------------------------------- experiencia del cartel de fin

## LA BARRA DE EXPERIENCIA DEL CARTEL: se monta bajo la cifra del oro, con el
## "+N de experiencia" DEBAJO. Se llena aquí y no en el menú porque aquí es
## donde el jugador está mirando; al acabar consume `GameState.xp_anim_from`,
## así que la barra del menú aparece ya llena.
##
## Va toda en PROCESS_MODE_ALWAYS: `_show_results` PAUSA el árbol y un tween
## sobre un nodo pausado no avanza ni un fotograma.
var xp_row: Control = null
var xp_bar: ProgressBar = null
var xp_bar_label: Label = null
var xp_gain_label: Label = null
## XP que la barra está enseñando (la mueve el tween).
var _xp_shown := 0.0


func _build_xp_row() -> void:
	var vb: VBoxContainer = $HUD/ResultsPanel/VBox
	var viejo := vb.get_node_or_null("XpRow")
	if viejo != null:
		vb.remove_child(viejo)
		viejo.queue_free()
	if last_xp <= 0:
		xp_row = null
		return
	xp_row = VBoxContainer.new()
	xp_row.name = "XpRow"
	xp_row.add_theme_constant_override("separation", 2)
	xp_row.process_mode = Node.PROCESS_MODE_ALWAYS
	xp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var caja := Control.new()
	caja.custom_minimum_size = Vector2(0, 30)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_row.add_child(caja)
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	xp_bar.offset_left = 46.0
	xp_bar.offset_right = -46.0
	xp_bar.add_theme_stylebox_override("background",
		PrepBoard.make_bar_box(PrepBoard.BAR_BG_TEX))
	xp_bar.add_theme_stylebox_override("fill",
		PrepBoard.make_bar_box(PrepBoard.BAR_FILL_TEX, Color(0.42, 0.62, 0.95)))
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(xp_bar)
	# El nivel, escrito DENTRO de la barra (como el marcador del oro).
	xp_bar_label = Label.new()
	xp_bar_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	xp_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_bar_label.add_theme_font_size_override("font_size", 19)
	xp_bar_label.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	xp_bar_label.add_theme_color_override("font_outline_color",
		Color(0.12, 0.06, 0.02))
	xp_bar_label.add_theme_constant_override("outline_size", 7)
	xp_bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(xp_bar_label)

	xp_gain_label = Label.new()
	# La PRIMA por el oro de más va sumada y sin desglosar (pedido por el
	# usuario): la cifra sale sola, sin una coletilla que leer.
	xp_gain_label.text = "+%d de experiencia" % last_xp
	xp_gain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_gain_label.add_theme_font_size_override("font_size", 21)
	xp_gain_label.add_theme_color_override("font_color", Color(0.30, 0.48, 0.72))
	xp_gain_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_row.add_child(xp_gain_label)

	# Justo debajo de la fila del oro (el HBox con la moneda y la cifra). OJO:
	# `earn_label` vive DENTRO de ese HBox (ver `_restyle_results_panel`), así
	# que hay que colgarse del PADRE — colgado del propio HBox, el "+N" salía
	# al lado de la cifra en vez de debajo.
	vb.add_child(xp_row)
	vb.move_child(xp_row, earn_label.get_parent().get_index() + 1)
	# El cartel crece lo que ocupa la fila: con el alto compacto de siempre,
	# la barra empujaba los botones fuera del pergamino.
	var alto := RESULT_SIZE.y + 62.0
	var lienzo := GameState.canvas_size()
	results_panel.offset_top = (lienzo.y - alto) * 0.5
	results_panel.offset_bottom = results_panel.offset_top + alto
	# Arranca donde estaba el jugador ANTES de la jornada.
	_xp_shown = float(GameState.xp_anim_from) if GameState.xp_anim_from >= 0 \
			else float(GameState.chef_xp)
	_paint_xp_bar()


func _paint_xp_bar() -> void:
	if xp_bar == null or not is_instance_valid(xp_bar):
		return
	var xp := int(_xp_shown)
	var nivel := SkillData.level_for_xp(xp)
	if nivel >= SkillData.MAX_LEVEL:
		xp_bar.max_value = 1
		xp_bar.value = 1
		xp_bar_label.text = "Cocinero %d · MÁXIMO" % nivel
		return
	xp_bar.max_value = SkillData.xp_for_next(nivel)
	xp_bar.value = xp - SkillData.xp_at_level(nivel)
	xp_bar_label.text = "Cocinero %d" % nivel


func _set_xp_shown(v: float) -> void:
	_xp_shown = v
	_paint_xp_bar()


## Llena la barra por TRAMOS DE NIVEL: cada frontera cruzada suelta su
## fogonazo con "¡Nivel N!". Devuelve cuando ha terminado.
func _play_xp_gain() -> void:
	if xp_row == null or not is_instance_valid(xp_row) or last_xp <= 0:
		return
	var desde: int = GameState.xp_anim_from if GameState.xp_anim_from >= 0 \
			else GameState.chef_xp - last_xp
	var hasta := GameState.chef_xp
	# Consumido: la barra del MENÚ ya no tiene que animar nada.
	GameState.xp_anim_from = -1
	if hasta <= desde:
		return
	await get_tree().create_timer(COUNT_PAUSE).timeout
	var actual := desde
	while actual < hasta:
		var nivel := SkillData.level_for_xp(actual)
		var frontera: int = SkillData.xp_at_level(nivel + 1) \
			if nivel < SkillData.MAX_LEVEL else hasta
		var tramo: int = mini(frontera, hasta)
		var dur := clampf(0.9 * float(tramo - actual) / float(hasta - desde),
			0.2, 0.9)
		# EL SONIDO DURA LO QUE DURE EL TRAMO: se calcula primero el viaje
		# de la barra y de ahi sale la velocidad del sonido, para que
		# empiece y acabe con ella (ver `Audio.sfx_dura`).
		Audio.sfx_dura("exp", dur)
		var t := xp_bar.create_tween()
		t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_method(_set_xp_shown, float(actual), float(tramo), dur)
		await t.finished
		if SkillData.level_for_xp(tramo) > nivel:
			_xp_level_burst(SkillData.level_for_xp(tramo))
			await get_tree().create_timer(0.5).timeout
		actual = tramo
	# Y AL FINAL, la ventana con lo que han soltado las subidas (una sola,
	# aunque hayan caído cinco niveles). Va por la capa global, que sabe
	# respetar la pausa que ya tiene puesta el cartel de resultados.
	var subida := GameState.take_level_up()
	if not subida.is_empty():
		GameState.announce_level_up(subida)


## Fogonazo de subida de nivel sobre la barra del cartel: destello, bote y
## "¡Nivel N!" saliendo hacia arriba.
func _xp_level_burst(nivel: int) -> void:
	Audio.sfx("levelup")
	if xp_bar == null or not is_instance_valid(xp_bar):
		return
	var flash := ColorRect.new()
	flash.color = Color(1, 0.95, 0.7, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.process_mode = Node.PROCESS_MODE_ALWAYS
	xp_bar.add_child(flash)
	var tf := flash.create_tween()
	tf.tween_property(flash, "color:a", 0.8, 0.08)
	tf.tween_property(flash, "color:a", 0.0, 0.42)
	tf.tween_callback(flash.queue_free)

	xp_bar.pivot_offset = xp_bar.size * 0.5
	var tb := xp_bar.create_tween()
	tb.tween_property(xp_bar, "scale", Vector2(1.1, 1.1), 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tb.tween_property(xp_bar, "scale", Vector2.ONE, 0.28) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var pop := Label.new()
	pop.text = "¡Nivel %d!" % nivel
	pop.add_theme_font_size_override("font_size", 30)
	pop.add_theme_color_override("font_color", Color(1.0, 0.86, 0.25))
	pop.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.02))
	pop.add_theme_constant_override("outline_size", 9)
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.process_mode = Node.PROCESS_MODE_ALWAYS
	pop.set_anchors_preset(Control.PRESET_FULL_RECT)
	pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pop.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pop.pivot_offset = xp_bar.size * 0.5
	pop.scale = Vector2(0.3, 0.3)
	xp_bar.add_child(pop)
	var tp := pop.create_tween()
	tp.tween_property(pop, "scale", Vector2.ONE, 0.26) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tp.tween_interval(0.3)
	tp.set_parallel(true)
	tp.tween_property(pop, "position:y", -52.0, 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tp.tween_property(pop, "modulate:a", 0.0, 0.5)
	tp.chain().tween_callback(pop.queue_free)


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
	Audio.sfx("premio")
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
	if is_perk:
		# Con la explicación de cómo funcionan, el cartel del bonificador pide
		# tanto sitio como el de una receta con resumen.
		alto = 700.0
	elif RecipeData.summary(id) != "":
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
		# CÓMO FUNCIONA UN BONIFICADOR, aquí mismo (pedido por el usuario): se
		# gana uno y hay que saber en el acto que se ELIGE antes de zarpar,
		# que se GASTA por jornada y dónde se consiguen más.
		gift.text = ("Llévate 1 uso de regalo.

Los bonificadores se eligen "
			+ "ANTES de zarpar, junto a la carta, y cada jornada gasta un uso. "
			+ "Repite su hazaña para ganar más, o cómpralos con lingotes en "
			+ "**Bonificadores**, en el mapa.")
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
	# En el arcade el botón no ABANDONA: TERMINA la partida y cobra lo ganado.
	# Un modo sin fin necesita una forma de parar y llevarse el botín.
	b.text = "Terminar" if GameState.is_arcade() else "Salir"
	# Mismo papel que los "Atrás" del juego: se sale de donde se está.
	b.set_meta("snd", "atras")
	# El tablón de madera de TODO el juego, no un recuadro propio: se había
	# quedado con un StyleBoxFlat suelto y era el único botón del juego que no
	# seguía el estilo. Algo más grande que antes (96×44) porque el 9-slice
	# encoge su marco en los botones pequeños y la madera no se leía.
	var ancho := 138.0 if GameState.is_arcade() else 112.0
	b.custom_minimum_size = Vector2(ancho, PrepBoard.SMALL_H)
	b.size = Vector2(ancho, PrepBoard.SMALL_H)
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
		# Los que todavía vienen andando NO cuentan: la fila dice quién está
		# EN LA BARRA, no quién ha entrado por la borda.
		if not c.ya_sentado():
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
	# en preparación se devuelve entero, y en marcha ya está gastado. En el
	# arcade EN MARCHA no se pierde nada: terminar es cobrar.
	if arcade and not prep_phase:
		msg.text = "Terminarás la partida aquí:\ncobrarás el oro y la experiencia de las oleadas superadas."
	else:
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
	quit.text = "Terminar" if (arcade and not prep_phase) else "Salir"
	quit.custom_minimum_size = Vector2(186, 66)
	# Rojo con aspa: es la opción que echa atrás la partida.
	prep_board.skin_action_button(quit, false)
	quit.add_theme_font_size_override("font_size", 24)
	if arcade and not prep_phase:
		# Terminar el arcade = cerrar el turno por el camino normal: los que
		# comen terminan su plato, se cobra todo y sale el cartel de oleadas.
		quit.pressed.connect(func() -> void:
			get_tree().paused = false
			overlay.queue_free()
			_end_level())
	else:
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
	Audio.sfx("recurso")
	# En la fase de preparacion la salida es gratis: se devuelve TODO lo que se
	# descuento al empezar el nivel (usos de ingredientes, potenciadores
	# permanentes Y EL SACO DE ARROZ). Aun no se ha jugado nada, asi que no se
	# pierde nada; la fase dura 10 s, asi que el margen es justo ese. En cuanto
	# entra el primer cliente, el saco ya esta gastado.
	# El arcade también devuelve lo suyo si se abandona EN PREPARACIÓN: paga
	# arroz y despensa como cualquier jornada, así que el arrepentimiento vale
	# lo mismo.
	if prep_phase and (GameState.is_adventure() or GameState.is_arcade()):
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
##
## Y el mapa se queda mirando al escenario SIGUIENTE al que se acaba de jugar,
## aunque ese ya estuviera superado: al terminar, lo que uno quiere ver es lo
## que viene ahora, no el punto mas lejano de la ruta.
func _on_menu_pressed() -> void:
	get_tree().paused = false
	if GameState.is_adventure():
		GameState.transition = "mapa"
		var siguiente := CampaignData.next_port_id(GameState.current_port)
		GameState.map_port = siguiente if siguiente != "" else GameState.current_port
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
## EL CONTADOR DE VACÍOS DEL PUERTO, bajo el número de clientes: el hándicap
## del tipo es "3 clientes que se van sin comer pierden la jornada", y una
## derrota que no se ve venir no es un reto, es una emboscada. Nace en crema y
## se pone ROJO y late al segundo vacío.
func _setup_vacios_puerto() -> void:
	if not vacio_pierde or arcade or GameState.is_tutorial():
		return
	if vacios_puerto_label != null and is_instance_valid(vacios_puerto_label):
		_colocar_vacios_puerto()
		return
	# TRES CALAVERAS en vez de un "Vacíos 0/3": apagadas de salida, y cada
	# cliente que se larga sin probar bocado enciende una de golpe (ver
	# `_update_vacios_puerto`). A la tercera se pierde la jornada, y eso se lee
	# de un vistazo mucho mejor que una cifra.
	vacios_puerto_label = _build_calaveras(VACIOS_MAX, _vacios_calaveras)
	$HUD.add_child(vacios_puerto_label)
	_colocar_vacios_puerto()
	_update_vacios_puerto()


## Una fila de N calaveras apagadas (la de la BANDERA PIRATA, no la
## `col_calavera` de la vitrina). La comparten el contador de vacíos del
## puerto (3) y el duelo del jefe (5); `lista` se rellena con los nodos.
func _build_calaveras(n: int, lista: Array) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 4)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lista.clear()
	for i in n:
		var cal := TextureRect.new()
		cal.texture = load("res://assets/ui/calavera_vacio.png")
		cal.custom_minimum_size = Vector2(CALAVERA, CALAVERA)
		cal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cal.pivot_offset = Vector2(CALAVERA, CALAVERA) * 0.5
		# Apagada = la calavera en sombra.
		cal.modulate = Color(0.10, 0.11, 0.16, 0.75)
		fila.add_child(cal)
		lista.append(cal)
	return fila


## El SPLASH de una calavera que acaba de encenderse: entra enorme, se aplasta
## y rebota hasta su tamaño. Es la señal de que se está más cerca de perder.
func _splash_calavera(cal: TextureRect) -> void:
	Audio.sfx("calavera")
	cal.scale = Vector2(2.6, 2.6)
	var t := create_tween()
	t.tween_property(cal, "scale", Vector2(0.82, 1.18), 0.13) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(cal, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _colocar_vacios_puerto() -> void:
	var caja: Control = $HUD/TopRow/ClientsBox
	vacios_puerto_label.position = Vector2(
		caja.global_position.x,
		caja.global_position.y + caja.size.y + 2.0)


var _vacios_puerto_last := 0
## Las tres calaveras del contador de vacíos (de izquierda a derecha).
var _vacios_calaveras: Array = []
## Lado de cada calavera.
const CALAVERA := 34

# ------------------------------- EL JEFE EN EL HUD ---------------------------
# Lo monta el GUION al traer al Kappa (`boss_hud_on`), no el nivel: hasta ese
# momento la tercera estrella es una estrella más y no hay nada que contar.

## Fallos que puede encajar el duelo. A las 5 calaveras la jornada se pierde.
const BOSS_SKULLS := 5
## Lado de la chapa del jefe (cara + platos restantes).
const BOSS_CHIP := 66

## Derrota del duelo: 5 calaveras. Fuerza 0 estrellas, como `lost_by_leavers`.
var boss_lost := false
## Alto a mano del cliente ESPECIAL (el jefe mide más que un capitán).
var special_height := 0.0
## Con el jefe en escena la 3ª estrella de la barra es SU CARA (se gana
## rindiéndolo, no con oro): `_place_star_marks` no debe repintarla.
var boss_star_face := false
var boss_chip: Control = null
var boss_chip_num: Label = null
var boss_skull_row: HBoxContainer = null
var _boss_skulls: Array = []
var boss_fails := 0


## ENTRA EL JEFE: la 3ª estrella pasa a ser su cara (la gana el duelo, no el
## oro — la cifra del objetivo se esconde con ella), aparece su CHAPA con los
## platos que faltan y las CINCO calaveras del duelo.
## La cara del JEFE de este nivel (la estrella de la meta y su chip): cada
## jefe trae la suya, y con head_K clavado la Sirena salia con cara de Kappa.
func _boss_face_path() -> String:
	const CARAS := {
		"kappa": "res://assets/ui/head_K.png",
		"sirena": "res://assets/ui/head_SI.png",
	}
	return CARAS.get(boss_id, "res://assets/ui/head_K.png")


func boss_hud_on() -> void:
	# La cara en la estrella de la meta.
	if not star_marks.is_empty():
		boss_star_face = true
		var n: TextureRect = star_marks.back()["nodo"]
		n.texture = load(_boss_face_path())
		n.modulate = Color(1, 1, 1)
		if money_meta != null:
			money_meta.visible = false
	# La chapa de platos, centrada bajo la fila de arriba.
	if boss_chip == null:
		boss_chip = Control.new()
		boss_chip.custom_minimum_size = Vector2(BOSS_CHIP, BOSS_CHIP)
		boss_chip.size = boss_chip.custom_minimum_size
		boss_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fondo := PrepBoard.make_nine_patch(PrepBoard.CARD_TEX,
			PrepBoard.CARD_MARGIN)
		fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boss_chip.add_child(fondo)
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = load(_boss_face_path())
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 7.0
		ic.offset_top = 5.0
		ic.offset_right = -7.0
		ic.offset_bottom = -9.0
		boss_chip.add_child(ic)
		boss_chip_num = Label.new()
		boss_chip_num.add_theme_font_size_override("font_size", 27)
		boss_chip_num.add_theme_color_override("font_outline_color", Color.BLACK)
		boss_chip_num.add_theme_constant_override("outline_size", 10)
		var negrita := load("res://fonts/static/Exo2-Bold.ttf")
		if negrita != null:
			boss_chip_num.add_theme_font_override("font", negrita)
		boss_chip_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boss_chip_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		boss_chip_num.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		boss_chip_num.set_anchors_preset(Control.PRESET_FULL_RECT)
		boss_chip_num.offset_right = 4.0
		boss_chip_num.offset_bottom = 6.0
		boss_chip.add_child(boss_chip_num)
		$HUD.add_child(boss_chip)
		var top: Control = $HUD/TopRow
		boss_chip.position = Vector2(
			(GameState.canvas_size().x - BOSS_CHIP) * 0.5,
			top.global_position.y + top.size.y + 10.0)
	# Las cinco calaveras, bajo el contador de clientes (ajustadas al canto:
	# cinco de 34 miden 186 px y desde la caja de clientes se salían).
	if boss_skull_row == null:
		boss_skull_row = _build_calaveras(BOSS_SKULLS, _boss_skulls)
		$HUD.add_child(boss_skull_row)
		var caja: Control = $HUD/TopRow/ClientsBox
		var ancho := BOSS_SKULLS * float(CALAVERA) + (BOSS_SKULLS - 1) * 4.0
		boss_skull_row.position = Vector2(
			minf(caja.global_position.x,
				GameState.canvas_size().x - ancho - 8.0),
			caja.global_position.y + caja.size.y + 2.0)


## Platos que le FALTAN al jefe en la fase en curso, en su chapa.
func boss_chip_set(n: int) -> void:
	if boss_chip_num == null:
		return
	boss_chip_num.text = str(maxi(n, 0))
	# Un botecito con cada cambio, para que el ojo lo pille de reojo.
	boss_chip.pivot_offset = boss_chip.size * 0.5
	var tw := create_tween()
	tw.tween_property(boss_chip, "scale", Vector2(1.18, 1.18), 0.08)
	tw.tween_property(boss_chip, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Un fallo del duelo: enciende su calavera con el splash. Devuelve las que
## quedan; a cero el nivel se da por PERDIDO (`boss_lost`) y el guion cierra.
func boss_lose_skull() -> int:
	boss_fails += 1
	if boss_fails - 1 < _boss_skulls.size():
		var cal: TextureRect = _boss_skulls[boss_fails - 1]
		if is_instance_valid(cal):
			cal.modulate = Color(1, 1, 1)
			_splash_calavera(cal)
	if boss_fails >= BOSS_SKULLS:
		boss_lost = true
	return BOSS_SKULLS - boss_fails


## EL PRECIO DE FALLARLE AL JEFE: el oro y las propinas de los platos que se
## le sirvieron en la fase en curso se pierden. Con suelo en 0, como todos los
## castigos del juego.
func boss_forfeit(oro: int, propinas: int) -> void:
	money_earned = maxi(money_earned - oro, 0)
	tips_total = maxi(tips_total - propinas, 0)
	_update_hud()


## La cara de la meta celebra la victoria: bote y fogonazo, como una estrella.
func boss_star_win() -> void:
	if star_marks.is_empty() or not boss_star_face:
		return
	var n: TextureRect = star_marks.back()["nodo"]
	var ts := create_tween()
	ts.tween_property(n, "scale", Vector2(1.7, 1.7), 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ts.tween_property(n, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var tm := create_tween()
	tm.tween_property(n, "modulate", Color(2.2, 2.1, 1.6), 0.12)
	tm.tween_property(n, "modulate", Color(1, 1, 1), 0.35)


func _update_vacios_puerto() -> void:
	if vacios_puerto_label == null or not is_instance_valid(vacios_puerto_label):
		return
	for i in _vacios_calaveras.size():
		var c: TextureRect = _vacios_calaveras[i]
		if not is_instance_valid(c):
			continue
		# Apagada = la sombra de la calavera; encendida = a plena luz.
		c.modulate = (Color(1, 1, 1) if i < empty_leavers
			else Color(0.10, 0.11, 0.16, 0.75))
	if empty_leavers > _vacios_puerto_last:
		var idx := _vacios_puerto_last
		_vacios_puerto_last = empty_leavers
		# EL SPLASH de la calavera que acaba de caer: entra enorme, se aplasta y
		# rebota hasta su tamaño. Es la única señal de que estás más cerca de
		# perder la jornada, así que no puede pasar desapercibida.
		if idx >= 0 and idx < _vacios_calaveras.size():
			var cal: TextureRect = _vacios_calaveras[idx]
			if is_instance_valid(cal):
				_splash_calavera(cal)


## El "-15 s" del ABORDAJE: sale del reloj y sube desvaneciéndose, en rojo.
## Es el único aviso del robo, así que va grande y pegado a la cifra del reloj.
func _flash_castigo_reloj() -> void:
	var caja: Control = $HUD/TopRow/TimeBox
	var aviso := Label.new()
	aviso.text = "-%d s" % int(CASTIGO_VACIO_SEG)
	aviso.add_theme_font_size_override("font_size", 34)
	aviso.add_theme_color_override("font_color", Color(1.0, 0.32, 0.26))
	aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	aviso.add_theme_constant_override("outline_size", 10)
	aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso.position = caja.global_position + Vector2(6.0, caja.size.y + 2.0)
	$HUD.add_child(aviso)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(aviso, "position:y", aviso.position.y + 46.0, 1.1)
	t.tween_property(aviso, "modulate:a", 0.0, 1.1).set_delay(0.25)
	t.chain().tween_callback(aviso.queue_free)


## Monta la fila de contadores de maestría. Solo salen los que el jugador
## LLEVA: sin habilidades no hay fila, y en el tutorial todo va en neutro.
## Lado del chip de un contador de maestría (chapa cuadrada con el icono).
const SKILL_CHIP := 58


func _setup_skill_counters() -> void:
	if skill_counter_row != null:
		return
	var periodos := _skill_periods()
	if periodos.is_empty():
		return
	skill_counter_row = HBoxContainer.new()
	skill_counter_row.name = "SkillCounters"
	skill_counter_row.add_theme_constant_override("separation", 14)
	skill_counter_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(skill_counter_row)
	for id in SKILL_COUNTERS:
		if not periodos.has(id):
			continue
		# EL CHIP ES UNA CHAPA: pergamino de fondo con su marco (el mismo
		# `CARD_TEX` del resto del juego), el icono dentro y la cuenta que falta
		# SUPERPUESTA abajo a la derecha. Suelto sobre el 3D, el icono se perdía
		# y el número parecía de otra cosa.
		var chip := Control.new()
		chip.custom_minimum_size = Vector2(SKILL_CHIP, SKILL_CHIP)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fondo := PrepBoard.make_nine_patch(PrepBoard.CARD_TEX,
			PrepBoard.CARD_MARGIN)
		fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(fondo)
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = SkillData.icon(id)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 7.0
		ic.offset_top = 5.0
		ic.offset_right = -7.0
		ic.offset_bottom = -9.0
		chip.add_child(ic)
		var num := Label.new()
		num.add_theme_font_size_override("font_size", 24)
		num.add_theme_color_override("font_outline_color", Color.BLACK)
		num.add_theme_constant_override("outline_size", 10)
		var negrita := load("res://fonts/static/Exo2-Bold.ttf")
		if negrita != null:
			num.add_theme_font_override("font", negrita)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		num.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		num.set_anchors_preset(Control.PRESET_FULL_RECT)
		num.offset_right = 3.0
		num.offset_bottom = 6.0
		chip.add_child(num)
		skill_counter_row.add_child(chip)
		_skill_chip[id] = num
		_skill_drawn[id] = -999
	_place_skill_counters()
	_refresh_skill_counters()


## Periodo de cada contador que el jugador lleve puesto (id -> platos).
func _skill_periods() -> Dictionary:
	var out := {}
	if prep_board == null:
		return out
	if prep_board.vista_period > 0:
		out["golpe_vista"] = prep_board.vista_period
	if prep_board.abundante_period > 0:
		out["cocina_abundante"] = prep_board.abundante_period
	if prep_board.suerte_period > 0:
		out["golpe_suerte"] = prep_board.suerte_period
	return out


## Margen al canto de la fila de contadores.
const SKILL_MARGIN := 10.0


## LOS CONTADORES VIVEN ABAJO A LA DERECHA, PEGADOS A LA CINTA de la tabla de
## elaboración (pedido por el usuario, que los bajó dos veces: primero del HUD
## de arriba y luego otro renglón más). Van a la MISMA altura que la fila de
## cabezas de cliente — la banda inmediatamente encima de la cinta — y por la
## derecha, donde las cabezas (centradas) no llegan. Su ancho se calcula del
## número de chips: es una fila suelta, no un contenedor anclado.
func _place_skill_counters() -> void:
	if skill_counter_row == null or not is_instance_valid(skill_counter_row):
		return
	var n := skill_counter_row.get_child_count()
	var ancho := n * float(SKILL_CHIP) + maxi(n - 1, 0) * 14.0
	skill_counter_row.position = Vector2(
		GameState.canvas_size().x - SKILL_MARGIN - ancho,
		GameState.canvas_size().y - 588.0 - 2.0 - float(SKILL_CHIP))


## Cifras que faltan. `left` es lo que queda para el próximo premio; a 0 el
## premio está EN LA MANO, así que el chip se enciende y late.
func _refresh_skill_counters() -> void:
	if skill_counter_row == null or prep_board == null:
		return
	var quedan := {
		"golpe_vista": prep_board.vista_left,
		"cocina_abundante": prep_board.abundante_left,
		"golpe_suerte": prep_board.suerte_left,
	}
	for id in _skill_chip:
		var v: int = int(quedan.get(id, 0))
		if _skill_drawn.get(id, -999) == v:
			continue
		_skill_drawn[id] = v
		var num: Label = _skill_chip[id]
		var latido: Tween = _skill_tween.get(id, null)
		if latido != null and latido.is_valid():
			latido.kill()
			num.scale = Vector2.ONE
		if v <= 0:
			num.text = "¡YA!"
			num.add_theme_color_override("font_color", Color(0.62, 0.92, 1.0))
			num.pivot_offset = num.size * 0.5
			var t := create_tween().set_loops()
			t.tween_property(num, "scale", Vector2(1.14, 1.14), 0.55) 					.set_trans(Tween.TRANS_SINE)
			t.tween_property(num, "scale", Vector2.ONE, 0.55) 					.set_trans(Tween.TRANS_SINE)
			_skill_tween[id] = t
		else:
			num.text = str(v)
			num.add_theme_color_override("font_color", Color(1, 0.95, 0.8, 0.85))
		_vibrar_chip(id, v)


## EL CHIP TIEMBLA SEGÚN SE ACERCA SU PLATO (pedido por el usuario): a tres
## que faltan tirita apenas, a dos se nota y al último se agita — así el
## jugador sabe SIN CONTAR que el siguiente plato sale doble (o gratis, o con
## suerte). Se anima la ROTACIÓN y no la posición: el chip vive en un
## contenedor, que le reescribiría el sitio cada fotograma.
func _vibrar_chip(id: String, quedan: int) -> void:
	if not _skill_chip.has(id):
		return
	var chip: Control = _skill_chip[id].get_parent()
	var viejo: Tween = _skill_shake.get(id, null)
	if viejo != null and viejo.is_valid():
		viejo.kill()
	chip.rotation_degrees = 0.0
	if quedan <= 0 or quedan > 3:
		return
	# 3 → un temblorcillo; 1 → sacudida de verdad.
	var amp: float = [0.0, 5.0, 3.0, 1.6][clampi(quedan, 1, 3)]
	var vel: float = [0.0, 0.07, 0.10, 0.14][clampi(quedan, 1, 3)]
	chip.pivot_offset = chip.size * 0.5
	var t := create_tween().set_loops()
	t.tween_property(chip, "rotation_degrees", amp, vel) \
		.set_trans(Tween.TRANS_SINE)
	t.tween_property(chip, "rotation_degrees", -amp, vel * 2.0) \
		.set_trans(Tween.TRANS_SINE)
	t.tween_property(chip, "rotation_degrees", 0.0, vel) \
		.set_trans(Tween.TRANS_SINE)
	# Un respiro entre sacudidas: temblando sin parar se volvía ruido.
	t.tween_interval(0.9 if quedan == 3 else (0.6 if quedan == 2 else 0.35))
	_skill_shake[id] = t


# ------------------------------------------- potenciadores EN MARCHA (HUD)
# Los potenciadores elegidos se apuntan ABAJO A LA IZQUIERDA (pedido por el
# usuario), en espejo de los contadores de maestría, que viven abajo a la
# derecha. Cada uno enseña su dibujo y LO QUE LE QUEDA: segundos si va por
# tiempo, platos si va por platos, y nada si es de efecto inmediato — un
# potenciador que ya hizo lo suyo no tiene por qué ocupar sitio.

## Alto de la chapa y hueco entre ellas (los mismos que los contadores).
const POT_CHIP := 62.0
const POT_CHIP_GAP := 6.0

var pot_row: HBoxContainer = null
## id -> { "num": Label, "chip": Control }
var _pot_chip: Dictionary = {}


## ¿Qué le queda a este potenciador? Devuelve el texto de su chapa, o "" si ya
## no está en marcha (entonces la chapa se retira).
func _pot_restante(id: String) -> String:
	match id:
		"cinta_rapida":
			return "%ds" % ceili(belt_timer) if belt_timer > 0.0 else ""
		"menos_cooldown":
			var t: float = prep_board.cooldown_mult_timer
			return "%ds" % ceili(t) if t > 0.0 else ""
		"mas_propinas":
			return "%ds" % ceili(tip_chance_timer) if tip_chance_timer > 0.0 else ""
		"todo_picoteo":
			return "%ds" % ceili(snack_all_timer) if snack_all_timer > 0.0 else ""
		"sin_basura":
			return "%ds" % ceili(no_waste_timer) if no_waste_timer > 0.0 else ""
		"doble_variedad":
			return "%ds" % ceili(variety_x2_timer) if variety_x2_timer > 0.0 else ""
		"receta_instantanea":
			var n: int = prep_board.instant_recipes
			return "x%d" % n if n > 0 else ""
		"doble_plato":
			return "x1" if prep_board.double_next else ""
		"sobremesa":
			return "x1" if dessert_boost else ""
		"aroma":
			# El aroma dura todo el turno: se queda puesto y sin cifra.
			return "•" if aroma_active else ""
	# Los de efecto inmediato (clientes de más, horas extra, variedad para
	# todos, tiempo muerto) no tienen nada que contar: su chapa aparece un
	# momento y se va sola.
	return ""


func _marcar_potenciador(id: String) -> void:
	if arcade and not PowerupData.POWERUPS.has(id):
		return
	if pot_row == null:
		pot_row = HBoxContainer.new()
		pot_row.add_theme_constant_override("separation", int(POT_CHIP_GAP))
		pot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$HUD.add_child(pot_row)
	if _pot_chip.has(id):
		# Repetido: se refresca su cifra y da un botecito para que se vea.
		var c: Control = _pot_chip[id]["chip"]
		var t := create_tween()
		t.tween_property(c, "scale", Vector2(1.18, 1.18), 0.09)
		t.tween_property(c, "scale", Vector2.ONE, 0.12)
		_place_pot_row()
		return
	var datos := PowerupData.get_powerup(id)
	var chip := Control.new()
	chip.custom_minimum_size = Vector2(POT_CHIP, POT_CHIP)
	chip.size = chip.custom_minimum_size
	chip.pivot_offset = chip.custom_minimum_size * 0.5
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# La misma chapa de pergamino que los contadores de maestría: son las dos
	# esquinas de lo mismo, lo que llevas puesto en esta jornada.
	var fondo := PrepBoard.make_nine_patch(PrepBoard.CARD_TEX, PrepBoard.CARD_MARGIN)
	chip.add_child(fondo)
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var ruta := str(datos.get("icon", ""))
	if ResourceLoader.exists(ruta):
		ic.texture = load(ruta)
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 6.0
	ic.offset_top = 5.0
	ic.offset_right = -6.0
	ic.offset_bottom = -7.0
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(ic)
	var num := Label.new()
	num.add_theme_font_size_override("font_size", 19)
	num.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	num.add_theme_color_override("font_outline_color", Color(0.16, 0.08, 0.02))
	num.add_theme_constant_override("outline_size", 7)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	num.offset_right = 3.0
	num.offset_bottom = 6.0
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(num)
	pot_row.add_child(chip)
	_pot_chip[id] = { "num": num, "chip": chip }
	# Entra con un golpe, como las chapas del multiplicador.
	chip.scale = Vector2(0.5, 0.5)
	var tw := create_tween()
	tw.tween_property(chip, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_place_pot_row()
	# OJO: NO se refresca aquí. `_apply_powerup` marca la chapa ANTES de correr
	# su `match`, así que en este instante el temporizador todavía vale 0 y la
	# chapa se daría por gastada nada más nacer. La pone al día el tick.


## ABAJO A LA IZQUIERDA, a la misma altura que los contadores de maestría (la
## banda que queda justo encima de la cinta de la tabla).
func _place_pot_row() -> void:
	if pot_row == null:
		return
	var n: int = pot_row.get_child_count()
	if n <= 0:
		return
	var ancho: float = n * POT_CHIP + (n - 1) * POT_CHIP_GAP
	pot_row.size = Vector2(ancho, POT_CHIP)
	# Misma banda que los contadores de maestría (588 es el alto de la tabla
	# de elaboración), pero pegada al canto IZQUIERDO.
	pot_row.position = Vector2(12.0,
		GameState.canvas_size().y - 588.0 - 2.0 - POT_CHIP)


## Por fotograma: refresca las cifras y retira lo que ya se ha gastado.
func _refresh_pot_row() -> void:
	if pot_row == null:
		return
	var fuera: Array = []
	for id in _pot_chip:
		var texto := _pot_restante(str(id))
		var num: Label = _pot_chip[id]["num"]
		if texto == "":
			# Los inmediatos se quedan un momento a la vista y se van; los de
			# duración desaparecen al agotarse.
			fuera.append(id)
			continue
		num.text = texto
	for id in fuera:
		var chip: Control = _pot_chip[id]["chip"]
		_pot_chip.erase(id)
		var tw := chip.create_tween()
		tw.tween_interval(1.4)
		tw.tween_property(chip, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func() -> void:
			if is_instance_valid(chip):
				chip.queue_free()
			_place_pot_row())


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
	if not get_viewport().size_changed.is_connected(_place_skill_counters):
		get_viewport().size_changed.connect(_place_skill_counters)
	_setup_vacios_puerto.call_deferred()
	_setup_skill_counters.call_deferred()
	if wind_on:
		_setup_viento.call_deferred()
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
	# ARCADE: la barra del oro no tiene meta fija — cada vez que se alcanza el
	# hito, se renueva ARCADE_META_STEP más allá (y su estrella brilla).
	if arcade and not star_money.is_empty() \
			and _score_money() >= int(star_money.back()):
		star_money = [int(star_money.back()) + ARCADE_META_STEP]
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
	clients_label.text = "%d" % clients_seated if unlimited \
			else "%d/%d" % [clients_seated, total_clients]
