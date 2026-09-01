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
## GRAFICO PROPIO de la ventana del escenario: pergamino con marco de CUERDA y
## argollas de laton, distinto del tablon de madera del resto del juego. Su
## marco mide ~46 texeles a 340 de ancho, asi que el margen 9-slice va a 56
## para que las argollas de las esquinas caigan enteras dentro.
const FICHA_TEX := "res://assets/ui/panel_ficha.png"
const FICHA_MARGIN := 56
## Lado del aspa que la cierra, cabalgando la esquina de arriba a la derecha.
const FICHA_ASPA := 76.0

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

## El tope de scroll llega hasta la CUEVA menos un margen (ver su MAP_POS).
## Se mueve con ella: al separar los escenarios, la cueva subio de -700 a
## -1664 y con el tope viejo se quedaba fuera de alcance.
## El tope de arriba llega hasta el jefe del MAR 2 (m2_25, y=-7286) con su
## margen; el de abajo se queda JUSTO bajo el escenario 1 — sin el panel de
## informacion de antes, bajar mas solo ensenaba un hueco de mar vacio.
## Tope de scroll: la jefa del mar 2 (m2_25) menos su margen. Ha bajado dos
## veces por el mismo motivo — cada escenario que se añade al mar 1 corre
## hacia arriba TODO lo que hay por encima de la Cueva del Kappa: 1.872 px al
## pasar de 20 a 25 escenarios y otros 1.872 al pasar de 25 a 30. Si no se
## baja con ellos, la mitad norte del mapa queda fuera de alcance.
## EL MAPA MONTA UN MAR CADA VEZ (ver CLAUDE.md, "dividir el mapa por mares").
## Con la campaña entera a la vez son 2,5 millones de triángulos y ~206 MB de
## vídeo — medido —, y el móvil no llega. Así que los topes del scroll ya no
## son constantes de toda la travesía: los calcula `_limites_del_mar()` con los
## escenarios del mar que se está enseñando.
##
## Los dos de abajo se quedan como TOPES ABSOLUTOS: el plano del agua tiene que
## cubrir el mapa entero (el barco viaja de un mar a otro) y el fondeadero del
## menú, que está muy por debajo.
const SCROLL_TOPE := -18076.0
const SCROLL_SUELO := CampaignData.MAP_HEIGHT - 560.0
## El mar que se está enseñando, y los topes que le tocan.
var mar_actual := 1
var scroll_min := SCROLL_TOPE
var scroll_max := SCROLL_SUELO
## Todo lo que se monta POR MAR va en el grupo de SU MAR. Es un grupo por mar y
## no uno solo a propósito: al cruzar hacen falta LOS DOS montados a la vez un
## par de segundos (ver `cambiar_de_mar`), o los escenarios del mar nuevo
## aparecen de golpe en mitad de la travesía.
func _grupo(mar: int) -> String:
	return "mapa_mar_%d" % mar
## RESPIRO MINIMO por encima y por debajo del mar: lo justo para que el cartel
## de paso quepa ENTERO en cuadro, y ni un pixel mas ("sin que sobre espacio
## por arriba o por abajo"). Estuvo a 0 y el cartel de SUBIR se quedaba pegado
## a la barra de arriba, sin poder llegar a verlo (dicho por el usuario).
const MARGEN_MAR := 200.0
## A que distancia del ultimo escenario se clava el cartel que lleva al mar
## siguiente. Va MAS CERCA que el margen, para que se vea antes de llegar.
const PASO_CARTEL := 330.0
## LA TRAVESÍA ENTRE MARES, en segundos: primero hasta el cartel (agua abierta,
## donde el cambiazo no se ve) y después hacia dentro del mar nuevo.
const PASO_VIAJE := 0.85
const ENTRADA_VIAJE := 1.05
## Mientras dura, ni se toca otro nodo ni se vuelve a cambiar de mar.
var cambiando_mar := false
## EL CARTEL QUE ESTÁ POR GIRAR durante una travesía (el mar al que lleva, o 0
## si no hay ninguno). Nace enseñando la cara de ANTES y lo voltea el barco al
## pasar por debajo; sin esto, `_refrescar_carteles` lo dejaría ya volteado al
## empezar el viaje y la flecha cambiaría sola.
var cartel_por_girar := 0
## El mar cuyos nodos se están construyendo AHORA (lo leen los `add_to_group`
## repartidos por `_setup_nodes`, `_setup_route` y `_carteles_de_mar`). Casi
## siempre es `mar_actual`; solo cambia mientras se monta el mar de destino de
## una travesía, con el viejo todavía en pie.
var mar_montando := 1

## EL PLANO DEL MAR TIENE QUE CUBRIR TAMBIÉN EL FONDEADERO DEL MENÚ, que está
## muy por debajo del mapa (`main_menu.MENU_ANCHOR`), y el puerto de la portada,
## que además se corre 1500 px a la izquierda. Estuvo dimensionado solo contra
## el mapa y en la portada se veía el borde del agua abajo a la izquierda.
## Van en píxeles de mapa y en unidades de mundo respectivamente.
const SEA_BOTTOM_PX := 5200.0
## El plano tiene que llegar del fondeadero del menu (abajo del todo) hasta el
## tope de scroll, y su medida SE CALCULA: (SEA_BOTTOM_PX + 640 - SCROLL_TOPE +
## 640) / PPU_Y, con un 2% de holgura. Hoy son 23.336 px = 474 u. Quedandose
## corto, la mitad norte del mar flota sobre el vacio (azul liso sin espuma).
const SEA_SIZE := 516.0

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
## Madera del cartel del nivel (el numero trae la suya horneada).
const NUM_TEX_MADERA := "res://assets/props/madera_cartel.webp"
## EL CARTEL DEL NUMERO, el mismo para los cuatro tipos. Va a la DERECHA del
## escenario y algo hacia la camara, en fracciones de su huella: lo bastante
## afuera para caer siempre sobre el agua.
const CARTEL_X := 0.46
## El ABORDAJE aparta mas su cartel: el barco enemigo es ancho y con la
## fraccion general el cartel quedaba DETRAS del casco (con el paso del mapa
## subido a 268 hay sitio de sobra para sacarlo).
const CARTEL_X_KIND := {
	"abordaje": 0.68, "isla": 0.58, "cueva": 0.66,
	# El PUERTO tambien se aparta: su modelo (el faro y sus pantalanes) tapaba
	# el cartel por un lado y se comia la primera estrella.
	"puerto": 0.62,
}
const CARTEL_Z := 0.34
## Lo que se hunde por debajo del mar. El pivote del nodo esta a −0.10, asi que
## esto es lo que baja el cartel DESDE ahi: la linea de flotacion cruza los
## postes a media altura y la tabla queda limpia por encima.
const CARTEL_CALADO := 0.26
const CARTEL_ALTO := 1.66
const CARTEL_ANCHO := 1.30
## EL TABLERO DEL MODELO, MEDIDO (`cartel_mar.glb`, sobre un modelo de 1,0 de
## alto): ocupa X -0,389..0,391 e Y -0,083..0,417, y su cara está en z 0,0630.
## De aquí sale todo lo que se coloca encima; el cartel se escala por el ANCHO,
## que es lo que tiene que seguir midiendo `CARTEL_ANCHO`.
const TABLA_ANCHO := 0.775
const TABLA_ALTO := 0.500
const TABLA_CY := 0.167
## Un pelo por delante del PICO de la cara (0,0630): la tabla es madera
## modelada a mano y a ras se comería el número.
const TABLA_CARA := 0.068
## Reparto de la tabla: el numero arriba y las estrellas debajo, en fracciones
## de su alto.
const NUM_EN_TABLA := 0.42
const NUM_SUBE := 0.14
const ESTRELLAS_EN_TABLA := 0.24
const ESTRELLAS_BAJA := 0.23

## Huella de cada modelo en el mapa. La ISLA es la mas grande porque su numero
## va ESCRITO EN LA ARENA: a 2.6 la playa no daba para una cifra legible.
## Huella de cada modelo en el mapa. TODOS crecieron con el numero metido
## dentro: la isla porque su cifra va escrita en la playa, y el puerto y el
## barco porque el cartel y la vela tienen que dar para dos y tres cifras.
const KIND_FOOT := { "isla": 3.5, "puerto": 3.9, "abordaje": 3.4, "cueva": 3.0 }
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
var cam_center := SCROLL_SUELO
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
## GRADOS QUE EL BARCO SE APARTA DE SU RUMBO DE CASA, y el ÚNICO sitio desde el
## que se le tuerce. Esta función escribe `ship_pivot.rotation_degrees` ENTERO
## cada fotograma, así que cualquiera que quiera girar el barco por su cuenta
## —el timón del menú, por ejemplo— pierde: se lo pisa al fotograma siguiente.
## Pasó de verdad, y se vivía como que el barco no se enderezaba al zarpar.
var rumbo_extra := 0.0
## EL BARCO VIRA ANTES DE NAVEGAR, SOPLA VIENTO Y ENTONCES SE MUEVE (pedido por
## el usuario), y al llegar vuelve a su rumbo de casa. `rumbo_extra` = 0 es
## "proa a la derecha del mapa"; de ahí sale `_rumbo_de`.
const VIRAJE := 0.42
## El viento: cuánto tarda en levantarse y en caer, y con qué viaje llega a
## soplar del todo. Un salto de un escenario al de al lado son ~312 px y una
## travesía entre mares pasa de 1.500: por eso la fuerza va por DISTANCIA.
const VIENTO_SUBE := 0.30
const VIENTO_BAJA := 0.55
const VIENTO_LEJOS := 1400.0
const VIENTO_MIN := 0.28
## Rachas del viento: cuántas, cuánto miden y cuánto se apartan del barco.
const VIENTO_RACHAS := 3
const VIENTO_LARGO := 3.4
const VIENTO_ANCHO := 5.6
const VIENTO_VEL := 9.0
## Cuánto se hincha la vela a viento pleno (unidades del modelo del barco).
const VELA_COMBA := 0.050
var viento_dir := Vector2.RIGHT
var viento_fuerza := 0.0
var viento_root: Node3D = null
var velas_mat: ShaderMaterial = null
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
## "Fase N", el numero del escenario escrito en claro.
var info_fase: Label
## Bloque del coleccionable que se puede conseguir aquí (si lo hay).
var info_tesoro: VBoxContainer = null
var info_tesoro_row: Container = null
## La franja de abajo del mapa: mapas del tesoro, tienda y opciones.
var map_submenu: Control = null
## EL BOTON DE VOLVER AL BARCO (ver `_build_boton_barco`).
var boton_barco: Button = null
var _barco_visible := false
## Hacia donde queda el barco: arriba (el jugador explora el sur del mapa) o
## abajo. Decide en que canto se pega el bocadillo y hacia donde va su rabo.
var _barco_arriba := false
var _barco_tween: Tween = null
## Lo lejos que hay que irse para que salga: mas de un paso de la travesia,
## para que no asome por un empujoncito del dedo.
const BARCO_LEJOS := 420.0
const BARCO_BTN := 104.0
## Alto de la banda de arriba del mapa (ver `_build_top_bar`): por debajo de
## ella se pega el bocadillo cuando el barco queda al norte.
const TOP_BAR_H := 190.0
## Piezas de la ficha que hay que remedir cuando cambia su contenido.
var ficha_panel: PanelContainer = null
var ficha_cuerpo: VBoxContainer = null
var ficha_aspa: TextureButton = null
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
	# EL MAR QUE TOCA: el del escenario en el que estaba el jugador. Se decide
	# ANTES de montar nada, porque la ruta, los nodos y los topes del scroll
	# salen todos de él.
	mar_actual = CampaignData.sea_of(_puerto_de_partida())
	_limites_del_mar()
	# POR `_montar_mar` Y NO A PELO: es quien pone `mar_montando`, que es de
	# donde sacan su grupo todos los `add_to_group` del montaje. Llamando a las
	# tres funciones sueltas, `mar_montando` se quedaba en su valor inicial (1)
	# y los nodos del mar 2 acababan etiquetados como del 1 — así que al cruzar
	# no se liberaba ninguno y el mapa se quedaba con los dos mares puestos.
	# SOLO LA VENTANA alrededor del escenario de partida: el resto lo monta
	# `completar_mar()` al llegar al mapa. Desde el menú no se ve más que eso,
	# y así el arranque no paga la campaña entera.
	_montar_ventana(_puerto_de_partida(), VENTANA_MENU)
	_rehacer_ruta()
	_setup_ship()
	_setup_camera()
	# El fusionado de la ruta y su apunte en `flotantes` los hace ya
	# `_montar_mar` (LA RUTA VA PINTADA SOBRE EL AGUA y sube con la marea: sus
	# guiones están a 0.025 de altura y la marea llega a 0.10, así que sin eso
	# la línea de puntos desaparecía bajo el agua en cada pleamar).
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
		cam_center = clampf(CampaignData.map_pos(start_id).y, scroll_min, scroll_max)
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


## ------------------------------------------------------ LA DIVISIÓN POR MARES
##
## El mapa monta UN MAR CADA VEZ. Medido con la campaña de hoy: 60 escenarios
## son 1.069 nodos, 551.789 triángulos y 45,4 MB de vídeo — y lo caro NO es el
## fotograma (38 draw calls: el culling se lleva el 90%, porque en pantalla
## caben tres o cuatro escenarios) sino la CARGA y la MEMORIA, que se pagan
## enteras aunque no se vea nada. Con los 250 de la campaña completa serían 2,5
## millones de triángulos y ~206 MB: el mismo muro contra el que ya se chocó
## con los sprites 2D.
##
## Y hay una razón que no es de rendimiento y pesa igual: 35 escenarios ya son
## ~11.000 px de scroll y 250 serían ~78.000. Eso no es navegar, es dragar.


## Los topes del scroll para el mar en curso: de su primer escenario a su
## último, con un respiro a cada lado para que quepan los carteles de paso.
func _limites_del_mar() -> void:
	var lista := CampaignData.ports_of_sea(mar_actual)
	if lista.is_empty():
		scroll_min = SCROLL_TOPE
		scroll_max = SCROLL_SUELO
		return
	var arriba := INF
	var abajo := -INF
	for p in lista:
		var y: float = CampaignData.map_pos(str(p["id"])).y
		arriba = minf(arriba, y)
		abajo = maxf(abajo, y)
	scroll_min = arriba - MARGEN_MAR
	scroll_max = abajo + MARGEN_MAR
	# El mar 1 llega hasta el fondeadero del menú, que está muy por debajo de
	# su primer escenario: sin esto, "Atrás" no podría bajar hasta el barco.
	if mar_actual == 1:
		scroll_max = maxf(scroll_max, SCROLL_SUELO)


## ¿Se puede pasar a ese mar? El SIGUIENTE pide tenerlo abierto (o sea, haber
## superado el jefe del anterior); el ANTERIOR siempre, que ya se jugó.
func _mar_alcanzable(mar: int) -> bool:
	if mar < 1 or mar > CampaignData.sea_count():
		return false
	if mar < mar_actual:
		return true
	var primero := CampaignData.first_port_of_sea(mar)
	return primero != "" and GameState.is_port_unlocked(primero)


## LOS CARTELES DE PASO, uno en cada punta de la travesía: son la única forma
## de cambiar de mar, y por eso se ven desde lejos. Van sobre el agua, en el
## carril del centro, con el nombre del mar al que llevan.
func _carteles_de_mar(mar := mar_actual) -> void:
	var lista := CampaignData.ports_of_sea(mar)
	if lista.is_empty():
		return
	var y_arriba: float = INF
	var y_abajo: float = -INF
	for p in lista:
		var y: float = CampaignData.map_pos(str(p["id"])).y
		y_arriba = minf(y_arriba, y)
		y_abajo = maxf(y_abajo, y)
	if _mar_alcanzable(mar + 1):
		_cartel_de_paso(mar + 1, _frontera(mar, mar + 1), mar)
	if _mar_alcanzable(mar - 1):
		_cartel_de_paso(mar - 1, _frontera(mar - 1, mar), mar)


## EL CARTEL DE PASO ES **UN SOLO MODELO** PARA LOS DOS SENTIDOS, con la flecha
## PINTADA encima. Hubo dos modelos, uno por sentido, y no valía: salieron de
## dos generaciones distintas de Meshy y no eran el mismo objeto —madera de
## otro tono (medido: 90,57,42 contra 114,70,51 de media en el atlas, 24 puntos
## de rojo), otro reparto de tablas, otros clavos y otro poste—. Los dos se ven
## en la misma frontera y en el mismo cruce, así que la diferencia no se leía
## como "otro cartel" sino como que la escena hubiera cambiado de luz.
##
## Voltear el modelo entero tampoco vale (el poste se iría arriba), y voltear
## la flecha DENTRO de su atlas se probó y se descartó: la UV de estos modelos
## viene TROCEADA por triángulos —la flecha ocupa de u 0,005 a 0,981 y de v
## 0,015 a 0,970, o sea el atlas entero—, así que hay que deshacer la
## interpolación baricéntrica de cada texel para saber a qué punto del modelo
## corresponde. Se llegó a hacer, y en el modelo la textura salía correcta pero
## en pantalla se veía deshilachada.
## Con la flecha aparte, los dos carteles son literalmente el mismo objeto y lo
## único que puede cambiar entre ellos es hacia dónde mira la flecha.
const CARTEL_MODELO := "res://assets/models/cartel_mar.glb"
## La flecha, pintada a mano con brocha (`assets/map/flecha_mar.png`).
const FLECHA_TEX := "res://assets/map/flecha_mar.png"
## Dónde va, MEDIDO sobre el modelo: el tablero ocupa Y -0,083..0,417 (alto
## 0,500) y X -0,389..0,391 (ancho 0,775), así que su centro es (0,001, 0,167).
## La z va por delante del PICO de la cara (0,0630), no de su media (0,0272):
## la tabla es madera modelada a mano y a ras se comería la flecha, dejando
## asomar solo sus bordes por los huecos entre tablas.
const FLECHA_CENTRO := Vector3(0.001, 0.167, 0.068)
const FLECHA_ALTO := 0.34
## Cara de la tabla al frente (yaw 45, como el chef y su mesa en el nivel): el
## modelo mira a su propio -Z y con la cámara isométrica salía de tres cuartos,
## con la flecha escorzada — que es lo único que hay que leer de un vistazo.
const CARTEL_YAW := 45.0
## EL GIRO DEL CARTEL AL CRUZAR: el barco pasa por debajo y lo "golpea", y el
## cartel da media vuelta enseñando su otra cara. No es un adorno — es lo que
## explica por qué la flecha ahora apunta al revés.
const CARTEL_GIRO := 0.9
## Cuánto se aparta el barco del carril al pasar por la frontera (píxeles de
## mapa). Por el centro le pasaba por ENCIMA al cartel; apartado se ve pasar a
## su lado, que es lo que hace creíble el empujón.
const CARTEL_ROCE := 95.0
## El chapuzón del NOMBRE del mar: cuánto espera a que el barco acabe de pasar,
## cuánto se hunde y lo que tarda en bajar y en volver a salir.
## LOS TRES SUMAN MENOS DE LO QUE QUEDA DE TRAVESÍA tras el golpe (~0,85 s de
## los 1,9 totales), y tiene que ser así: al llegar, el mapa REHACE los
## carteles, y el nuevo nace ya con su nombre puesto — así que una animación
## más larga se queda a medias y no se le ve emerger.
const ROTULO_ESPERA := 0.16
const ROTULO_CALADO := 0.85
const ROTULO_BAJA := 0.28
const ROTULO_SUBE := 0.32
## Huella a la que se normaliza (unidades de mundo). Se midió contra el nodo
## de escenario más pequeño: el cartel tiene que leerse sin competir con él.
## **NO ES 3,1 POR CAPRICHO: fija el ALTO en pantalla, y ese alto está
## calibrado** — `PASO_CARTEL` y `MARGEN_MAR` se midieron para que el cartel de
## subir quepa entero bajo la barra de arriba (cae entre la y 231 y la 454).
## `_spawn_model` normaliza por HUELLA, así que al cambiar de modelo hay que
## rehacer esta cifra o el cartel cambia de tamaño: el modelo nuevo tiene una
## huella de 0,7773 contra los 0,8418 del anterior, así que con 3,1 saldría un
## 8% más alto (3,988 contra 3,683) y se metería debajo de la barra. 2,862 es
## lo que le devuelve el alto de antes: 1,0 × 2,862 / 0,7773 = 3,683.
const CARTEL_FOOT := 2.862


func _cartel_de_paso(mar: int, y_px: float, desde := mar_actual) -> void:
	var pos := _world(Vector2(CampaignData.LANE_CENTER, y_px))
	var raiz := Node3D.new()
	raiz.name = "PasoMar%d" % mar
	raiz.position = pos
	# NO VA EN EL GRUPO DE NINGÚN MAR: su vida la lleva `_refrescar_carteles`.
	# Metido en uno, `mar_montando` ya estaba restaurado cuando se creaba, así
	# que caía en el grupo equivocado y `_limpiar_mar` se lo llevaba por
	# delante — al volver de cruzar no quedaba ni un cartel.
	raiz.add_to_group("paso_mar")
	raiz.set_meta("mar", mar)
	add_child(raiz)
	var sube := mar > desde
	# EL CARTEL QUE SE ESTÁ CRUZANDO NACE COMO ESTABA ANTES: con la flecha del
	# viaje que se está haciendo y con el nombre del mar al que se va. Lo cambia
	# todo el barco al pasar (`golpear_cartel`). Puesto ya en su sitio, la
	# flecha y el nombre cambiarían solos al empezar la travesía.
	var cruzando := mar == cartel_por_girar
	var alto := 1.4
	if ResourceLoader.exists(CARTEL_MODELO):
		var pivot := _spawn_model(load(CARTEL_MODELO), pos, CARTEL_FOOT)
		# Los carteles no dan sombra, como los nodos: son geometría de adorno.
		for m in pivot.find_children("*", "MeshInstance3D", true, false):
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		alto = float(pivot.get_meta("alto", 1.4))
		raiz.set_meta("flecha", _pintar_flecha(pivot, sube != cruzando))
		# El cartel MIRA SIEMPRE DE FRENTE: lo que cambia al cruzar no es su
		# cara, es la flecha — y se cambia en mitad de la vuelta, con la tabla
		# de canto.
		pivot.rotation_degrees.y = CARTEL_YAW
		# Medio hundido en el agua, como los carteles de escenario: un poste
		# clavado en el mar no se apoya en él.
		pivot.position.y = -0.16
		raiz.set_meta("pivot", pivot)
	# EL NOMBRE DEL MAR va DEBAJO del letrero, no encima de la tabla: ahí está
	# la flecha, que es lo que tiene que leerse primero.
	var rot := Label3D.new()
	rot.text = CampaignData.sea_name(mar_actual if cruzando else mar)
	raiz.set_meta("nombre", CampaignData.sea_name(mar))
	rot.font_size = 66
	rot.outline_size = 22
	rot.modulate = Color(1.0, 0.95, 0.80)
	rot.outline_modulate = Color(0.20, 0.12, 0.06)
	rot.pixel_size = 0.0042
	rot.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	rot.rotation_degrees = Vector3(0.0, 45.0, 0.0)
	rot.position = Vector3(0.0, -0.62, 0.0) - D_HAT * 0.42
	rot.no_depth_test = true
	raiz.add_child(rot)
	raiz.set_meta("rotulo", rot)
	node_world["__mar%d" % mar] = pos + Vector3(0.0, alto * 0.55, 0.0)


## LAS FLECHAS VAN PINTADAS SOBRE LA TABLA, una por CARA, y no talladas en el
## modelo: es lo que permite que los dos sentidos sean el MISMO cartel. Cuelgan
## del modelo (no del pivote), así que sus medidas son las del propio `.glb` y
## no hay que deshacer la escala que le pone `_spawn_model`.
## LA FLECHA VA EN UNA SOLA CARA. Hubo una por cara y el reverso no convencía
## (lo dijo el usuario): el modelo viene de imagen→3D y su trasera es una tabla
## sin gracia, así que enseñarla era enseñar lo peor del cartel. Ahora el cartel
## da la vuelta ENTERA (360°) y la flecha se cambia a mitad de giro, con la
## tabla de canto: se ve girar, y al volver a mirar de frente apunta al revés.
func _pintar_flecha(pivot: Node3D, sube: bool) -> Node3D:
	if pivot.get_child_count() == 0 or not ResourceLoader.exists(FLECHA_TEX):
		return null
	var tex: Texture2D = load(FLECHA_TEX)
	var quad := QuadMesh.new()
	quad.size = Vector2(FLECHA_ALTO * tex.get_width() / float(tex.get_height()), FLECHA_ALTO)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	# Recorte por alfa y no mezcla: la pincelada tiene el canto bastante duro y
	# así el cartel no entra en la cola de transparentes.
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.4
	mat.roughness = 0.95
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.position = FLECHA_CENTRO
	# Media vuelta sobre su propio eje para que apunte abajo, NO una escala
	# negativa: la escala le da la vuelta al triángulo y el descarte de caras
	# traseras se lo come.
	if not sube:
		mi.rotation_degrees.z = 180.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.get_child(0).add_child(mi)
	return mi


## EL BARCO PASA POR DEBAJO Y LE DA MEDIA VUELTA AL CARTEL, que es lo que
## explica que la flecha pase a apuntar al revés: no cambia el cartel, cambia
## la cara que se ve. Va SIN await a propósito — el barco sigue su camino
## mientras el cartel gira detrás, que es lo que se lee como un golpe al pasar.
func golpear_cartel(mar: int) -> void:
	for raiz in get_tree().get_nodes_in_group("paso_mar"):
		if not is_instance_valid(raiz) or int(raiz.get_meta("mar", 0)) != mar:
			continue
		var pivot = raiz.get_meta("pivot", null)
		if pivot == null or not is_instance_valid(pivot):
			return
		# Madera crujiendo, y AGUDA: es el crujido del casco (`barco_cruje`) con
		# el tono subido, porque lo que gira aquí es una tabla en su poste, no
		# un barco entero.
		Audio.sfx("barco_cruje", 0.0, randf_range(1.18, 1.34))
		# VUELTA ENTERA (360°) Y LA FLECHA SE CAMBIA A MITAD DE GIRO, con la
		# tabla de canto: así el cartel acaba mirando de frente otra vez —nunca
		# se le ve el reverso, que es lo que no convencía— y lo que ha cambiado
		# es lo que está pintado.
		# EL TWEEN CUELGA DEL PROPIO CARTEL, no del mapa: al terminar la
		# travesía los carteles se rehacen, y un tween del mapa seguiría vivo
		# apuntando a un nodo liberado ("Lambda capture at index 0 was freed").
		var tw: Tween = pivot.create_tween()
		# TRANS_BACK a la salida: se pasa un poco de la vuelta y vuelve, como
		# una tabla que sigue oscilando en su poste después del empujón. Con una
		# interpolación suave se leía como un giro motorizado.
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(pivot, "rotation_degrees:y",
			pivot.rotation_degrees.y + 360.0, CARTEL_GIRO)
		var flecha = raiz.get_meta("flecha", null)
		if flecha != null and is_instance_valid(flecha):
			# A un cuarto de la vuelta la tabla está de canto y no se lee nada:
			# ese es el hueco por el que se cambia la flecha sin que se vea.
			var giro: float = float(flecha.rotation_degrees.z) + 180.0
			var tf: Tween = flecha.create_tween()
			tf.tween_interval(CARTEL_GIRO * 0.25)
			tf.tween_property(flecha, "rotation_degrees:z", giro, 0.0)
		_cambiar_rotulo(raiz)
		return


## EL NOMBRE DEL MAR SE SUMERGE Y VUELVE A EMERGER YA CAMBIADO (pedido por el
## usuario): no cambia de golpe, se hunde en el agua mientras el barco termina
## de pasar y sale con el nombre del mar que queda atrás. El rótulo va con
## `no_depth_test`, así que el mar no lo tapa por sí solo: lo que vende el
## chapuzón es que se hunda Y se apague a la vez.
func _cambiar_rotulo(raiz: Node3D) -> void:
	var rot = raiz.get_meta("rotulo", null)
	if rot == null or not is_instance_valid(rot):
		return
	var nombre := str(raiz.get_meta("nombre", rot.text))
	if nombre == rot.text:
		return
	var y0: float = rot.position.y
	var tw: Tween = rot.create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	# Se espera a que el barco haya pasado del todo antes de hundirlo.
	tw.tween_interval(ROTULO_ESPERA)
	tw.set_parallel(true)
	tw.tween_property(rot, "position:y", y0 - ROTULO_CALADO, ROTULO_BAJA)
	tw.tween_property(rot, "modulate:a", 0.0, ROTULO_BAJA)
	tw.chain().tween_callback(rot.set_text.bind(nombre))
	tw.set_parallel(true)
	tw.tween_property(rot, "position:y", y0, ROTULO_SUBE)
	tw.tween_property(rot, "modulate:a", 1.0, ROTULO_SUBE)


func _mat_simple(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


## MONTA UN MAR ENTERO: su ruta, sus escenarios y sus carteles de paso. Todo
## queda en el grupo de ESE mar, así que se puede tener más de uno a la vez.
func _montar_mar(mar: int, solo: Array = []) -> void:
	var antes := mar_montando
	mar_montando = mar
	_setup_nodes(mar, solo)
	mar_montando = antes


## LA RUTA SE REHACE ENTERA cada vez que cambia lo que hay montado, y ese es el
## único sitio que la dibuja. Se intentó antes montarla por mar y no funciona
## por dos motivos que se midieron:
##   - `GeometryBatch.bake` funde TODOS los guiones que cuelguen de la raíz en
##     UNA malla, vengan del mar que vengan. Esa malla acababa en el grupo del
##     último mar montado, así que al soltar el otro se iba la ruta ENTERA (se
##     midió: 0 triángulos de ruta después de cruzar).
##   - Y volviendo a fusionar sobre lo ya fusionado, las líneas se repetían
##     (5.004 triángulos pasaban a 17.268 tras un par de cruces).
## Rehaciéndola de cero contra `montados`, la ruta siempre es exactamente la de
## lo que está puesto.
func _rehacer_ruta() -> void:
	# SE BARRE TODO Y SE VUELVE A DIBUJAR. Y con `free()`, no `queue_free()`:
	# el fusionado corre en esta misma llamada y con el borrado diferido se
	# encontraba la ruta vieja todavía colgada de la raíz.
	for h in get_children():
		if h is MeshInstance3D and String(h.name).begins_with("RouteBatch"):
			remove_child(h)
			h.free()
	for d in get_tree().get_nodes_in_group("route_dash"):
		if is_instance_valid(d):
			d.get_parent().remove_child(d)
			d.free()
	var vivos: Array[Node3D] = []
	for f in flotantes:
		if is_instance_valid(f) and not f.is_queued_for_deletion():
			vivos.append(f)
	flotantes = vivos
	for mar in range(1, CampaignData.sea_count() + 1):
		_setup_route(mar)
	GeometryBatch.bake(self, "RouteBatch")
	for hijo in get_children():
		if hijo is MeshInstance3D and String(hijo.name).begins_with("RouteBatch") 				and not hijo.is_in_group("no_batch"):
			var mi: MeshInstance3D = hijo
			mi.set_meta("y0", mi.position.y)
			# FUERA DEL PRÓXIMO FUSIONADO, o el siguiente `bake` se la traga y
			# la vuelve a fundir sobre sí misma.
			mi.add_to_group("no_batch")
			flotantes.append(mi)


## Suelta todo lo de ESE mar. Los nodos van marcados con su grupo desde que se
## crean, así que no hay que llevar listas paralelas — solo limpiar de las
## que sí existen (flotantes, nieblas y los overlays) lo que se acaba de ir.
func _limpiar_mar(mar: int) -> void:
	for n in get_tree().get_nodes_in_group(_grupo(mar)):
		if is_instance_valid(n):
			n.queue_free()
	# LAS LISTAS SE REHACEN A MANO, no con `filter`: su lambda recibe los
	# elementos como Object y una anotación `Node3D` revienta en tiempo de
	# ejecución ("Cannot convert argument 1 from Object to Object"), que además
	# dejaba la travesía a medias.
	var vivos: Array[Node3D] = []
	for f in flotantes:
		if is_instance_valid(f) and not f.is_queued_for_deletion():
			vivos.append(f)
	flotantes = vivos
	var nieblas_vivas: Array[Node3D] = []
	for n2 in nieblas:
		if is_instance_valid(n2) and not n2.is_queued_for_deletion():
			nieblas_vivas.append(n2)
	nieblas = nieblas_vivas
	for p in CampaignData.ports_of_sea(mar):
		var pid := str(p["id"])
		if str(montados.get(pid, "")) == _grupo(mar):
			montados.erase(pid)
			node_world.erase(pid)




## CUÁNTOS ESCENARIOS SE MONTAN ALREDEDOR DEL DESTINO mientras se está en el
## MENÚ (pedido por el usuario). Con tres arriba y tres abajo está cubierto lo
## que cabe en cuadro —el encuadre da para unos cuatro escenarios—, así que al
## llegar el mapa ya parece entero; el resto se monta entonces, ya fuera de
## cuadro, y no se le ve aparecer.
const VENTANA_MENU := 3


## Monta la ventana alrededor de ese escenario y nada más. Es lo que hay puesto
## mientras el jugador está en el menú.
func _montar_ventana(id: String, n: int) -> void:
	var mar := CampaignData.sea_of(id)
	var lista := CampaignData.ports_of_sea(mar)
	var i := -1
	for k in lista.size():
		if str(lista[k]["id"]) == id:
			i = k
			break
	if i < 0:
		_montar_mar(mar)
		return
	var ids: Array = []
	for k in range(maxi(i - n, 0), mini(i + n + 1, lista.size())):
		ids.append(str(lista[k]["id"]))
	_montar_mar(mar, ids)


## COMPLETA EL MAR EN CURSO: lo que faltaba por montar, los bordes de los
## vecinos, la ruta y los carteles. Se llama al LLEGAR al mapa — hasta entonces
## solo está la ventana de `_montar_ventana`, y lo que se añade aquí cae fuera
## de cuadro, así que no se ve aparecer nada.
func completar_mar() -> void:
	_montar_mar(mar_actual)
	_montar_bordes()
	_rehacer_ruta()
	_refrescar_carteles()
	_rehacer_overlays()


## CUÁNTOS ESCENARIOS DEL MAR VECINO se dejan puestos aunque no toque
## (pedido por el usuario). Estando en el mar de los grumetes, las dos primeras
## islas del de las sirenas ya están ahí; estando en el de las sirenas, las dos
## últimas del de los grumetes. Así, al cruzar, los escenarios que se ven al
## otro lado de la frontera **no aparecen**: ya estaban.
const BORDE_VECINO := 2


## Monta el BORDE de los mares vecinos: sus `BORDE_VECINO` escenarios más
## cercanos a la frontera con el mar en curso. Van en el grupo de SU mar, así
## que si luego se cruza a él, `_montar_mar` completa el resto y estos ya no se
## vuelven a montar (`montados` lo impide).
func _montar_bordes() -> void:
	for vecino: int in [mar_actual - 1, mar_actual + 1]:
		if vecino < 1 or vecino > CampaignData.sea_count():
			continue
		_montar_mar(vecino, _borde_de(vecino, mar_actual))


## Los ids de los `BORDE_VECINO` escenarios de `mar` más cercanos a `hacia`.
func _borde_de(mar: int, hacia: int) -> Array:
	var lista := CampaignData.ports_of_sea(mar)
	if lista.is_empty():
		return []
	# El mar de número MAYOR está al NORTE: su borde con el del sur son sus
	# PRIMEROS escenarios; el del sur da los ÚLTIMOS.
	var ids: Array = []
	if mar > hacia:
		for i in mini(BORDE_VECINO, lista.size()):
			ids.append(str(lista[i]["id"]))
	else:
		for i in mini(BORDE_VECINO, lista.size()):
			ids.append(str(lista[lista.size() - 1 - i]["id"]))
	return ids


## LOS CARTELES DE PASO SE REHACEN ENTEROS, y son los del mar EN CURSO y de
## nadie más. Colgaban del montaje de cada mar, y con dos montados a la vez
## (que es lo que pasa al cruzar) salían DOS en la misma frontera, uno encima
## del otro — el de bajar de un mar y el de subir del otro.
func _refrescar_carteles() -> void:
	for n in get_tree().get_nodes_in_group("paso_mar"):
		if is_instance_valid(n):
			var pv = n.get_meta("pivot", null)
			if pv != null and is_instance_valid(pv):
				pv.queue_free()
			n.queue_free()
	node_world.erase("__mar%d" % (mar_actual - 1))
	node_world.erase("__mar%d" % (mar_actual + 1))
	node_world.erase("__mar%d" % (mar_actual - 2))
	node_world.erase("__mar%d" % (mar_actual + 2))
	_carteles_de_mar(mar_actual)


## CAMBIA EL MAPA AL OTRO MAR. Es toda la división: el mapa, la cámara, los
## carriles y el barco no cambian — lo único que cambia es CUÁNTO se monta.
##
## `destino_id` fuerza en qué escenario se entra. Sin él manda el sentido del
## viaje. Lo usa `_select` cuando el escenario pedido es de otro mar —al cerrar
## la jornada del jefe, por ejemplo— para no aterrizar en otro sitio.
func cambiar_de_mar(mar: int, destino_id := "") -> void:
	if mar == mar_actual or not _mar_alcanzable(mar) or cambiando_mar:
		return
	var viejo := mar_actual
	var subiendo := mar > viejo
	cambiando_mar = true
	var y_frontera: float = _frontera(viejo, mar)
	# --- LOS DOS MARES A LA VEZ, y esto es lo que quita el parpadeo --------
	# El mar de destino se monta AHORA, con el barco todavía en el suyo y sus
	# escenarios lejísimos fuera de cuadro. Así, cuando la cámara cruza la
	# frontera, los primeros escenarios del mar nuevo YA ESTABAN ahí: no
	# aparecen de golpe, entran en cuadro navegando. El mar viejo se suelta al
	# final, cuando ya ha quedado atrás. Tenerlos los dos montados cuesta un
	# par de segundos lo que costaba el mapa entero antes de dividirlo — que es
	# exactamente el rato en el que hace falta.
	mar_actual = mar
	# EL BORDE DEL MAR NUEVO YA ESTABA PUESTO (lo dejó `_montar_bordes` al
	# llegar al mar viejo), así que esto solo completa el resto — y esos son
	# justo los que quedan fuera de cuadro durante toda la travesía.
	_montar_mar(mar)
	_montar_bordes()
	_rehacer_ruta()
	# El cartel de la frontera que se va a cruzar es el del mar VIEJO (visto
	# desde el nuevo, señala de vuelta). Nace todavía con la cara de antes y lo
	# gira el barco al pasar.
	cartel_por_girar = viejo
	_refrescar_carteles()
	cartel_por_girar = 0
	_limites_del_mar()
	# El scroll tiene que abarcar los DOS mares mientras dura la travesía, o
	# sus topes cortarían el viaje por la mitad.
	scroll_min = minf(scroll_min,
		minf(_extremo_del_mar(viejo, true) - MARGEN_MAR, y_frontera))
	scroll_max = maxf(scroll_max,
		maxf(_extremo_del_mar(viejo, false) + MARGEN_MAR, y_frontera))
	_rehacer_overlays([viejo, mar])
	# --- 1) HASTA LA FRONTERA ---------------------------------------------
	# EL BARCO NO SE PARA EN EL CARTEL Y NO LE PASA POR EN MEDIO (pedido por el
	# usuario): la frontera es un punto de PASO, no una parada. Va apartado
	# `CARTEL_ROCE` a un lado —así se lee que le ha dado un empujón al pasar— y
	# los dos tramos se encadenan con `EASE_IN` y `EASE_OUT`, o sea que el
	# primero acelera y el segundo frena, sin el frenazo de en medio que dejaba
	# el `EASE_IN_OUT` de serie.
	#
	# Y EL REPARTO DEL TIEMPO SALE DE LAS DISTANCIAS, no de dos constantes.
	# Con 0,85 s para el primer tramo y 1,05 para el segundo el barco llegaba
	# al cartel a 331 px por cuatro fotogramas y salía a 100: no se paraba, pero
	# el frenazo se veía igual — y es lo que se sentía como una parada junto al
	# poste. Repartiendo el tiempo total en proporción al camino, la velocidad
	# es la misma a un lado y a otro del cartel.
	var lista := CampaignData.ports_of_sea(mar)
	if lista.is_empty():
		cambiando_mar = false
		return
	var destino := str(lista[0]["id"]) if subiendo else str(lista.back()["id"])
	if destino_id != "" and CampaignData.sea_of(destino_id) == mar:
		destino = destino_id
	var paso := Vector2(CampaignData.LANE_CENTER + CARTEL_ROCE, y_frontera)
	var meta := _ship_anchor(destino)
	var d1 := ship_px.distance_to(paso)
	var d2 := paso.distance_to(meta)
	var total := PASO_VIAJE + ENTRADA_VIAJE
	var frac: float = clampf(d1 / maxf(d1 + d2, 1.0), 0.15, 0.85)
	await _viajar_barco(paso, y_frontera, total * frac, Tween.EASE_IN)
	if not is_inside_tree():
		return
	# El barco está pasando justo al lado del cartel: aquí es donde lo golpea.
	golpear_cartel(viejo)
	# --- 2) DENTRO DEL MAR NUEVO, hasta el ANCLAJE de su escenario ---------
	# Al SUBIR se entra por su primer escenario; al BAJAR, por el último — que
	# es de donde se venía, así que se lee como dar media vuelta. Y se viaja
	# hasta su ANCLAJE, no hasta el carril: así el barco llega ya aparcado y no
	# hay que colocarlo de golpe al final.
	await _viajar_barco(meta, CampaignData.map_pos(destino).y,
		total * (1.0 - frac), Tween.EASE_OUT)
	if not is_inside_tree():
		return
	# --- 3) SOLTAR EL MAR VIEJO, que ya ha quedado atrás -------------------
	# Se suelta el mar viejo ENTERO y se le vuelve a dejar su borde: dos
	# escenarios al otro lado de la frontera, para que al volver tampoco
	# aparezcan de la nada.
	_limpiar_mar(viejo)
	_montar_bordes()
	_rehacer_ruta()
	_refrescar_carteles()
	_limites_del_mar()
	_rehacer_overlays([mar, viejo])
	cambiando_mar = false
	_select(destino, false)


## LA FRONTERA ENTRE DOS MARES ES UN SOLO PUNTO, y de ahí sale todo lo demás:
## el sitio del cartel de paso y el sitio donde se cruza.
##
## POR QUÉ IMPORTA QUE SEA UNO Y NO DOS: el primer intento tenía un borde por
## mar (cada uno a `PASO_CARTEL` de su escenario extremo) y, con el hueco de
## 1.000 px, esos dos bordes distaban 340 — así que al cambiar de mar la cámara
## daba un salto de 340 px. Eso era EL CORTE. Ahora el hueco entre mares vale
## exactamente `2 × PASO_CARTEL` (`CampaignData.MAP_POS`), el punto medio está
## a `PASO_CARTEL` de los dos y `_frontera` devuelve el mismo número se venga
## del mar que se venga.
func _frontera(mar_a: int, mar_b: int) -> float:
	# LA TRAVESÍA VA DE SUR A NORTE Y EN EL MAPA MÁS `y` ES MÁS AL SUR, así que
	# el mar de número MAYOR es el del NORTE (el 1 arranca en y=3220 y el 2
	# acaba en y=-17922). Tenerlo del revés ponía la frontera en el punto medio
	# de la campaña ENTERA: medido, la cámara se iba a -7.354 en vez de -8.560.
	var norte := maxi(mar_a, mar_b)
	var sur := mini(mar_a, mar_b)
	var y_sur := _extremo_del_mar(sur, true)
	var y_norte := _extremo_del_mar(norte, false)
	if is_inf(y_sur) or is_inf(y_norte):
		return cam_center
	return (y_sur + y_norte) * 0.5


## El escenario más al norte (`arriba`) o al sur de ese mar, en píxeles de mapa.
func _extremo_del_mar(mar: int, arriba: bool) -> float:
	var y := INF if arriba else -INF
	for p in CampaignData.ports_of_sea(mar):
		var v: float = CampaignData.map_pos(str(p["id"])).y
		y = minf(y, v) if arriba else maxf(y, v)
	return y


## Lleva cámara y barco a la vez y espera a que lleguen. El barco va a un PUNTO
## del mapa (no a un carril fijo): así el último tramo de una travesía entre
## mares termina en el ANCLAJE del escenario y no hay que colocarlo de golpe al
## final, que era otro de los saltos que se veían.
## EL RUMBO PARA UNA DIRECCIÓN DEL MAPA. `rumbo_extra` = 0 es proa a la derecha
## (así descansa el barco), y girar Δ° sobre Y lleva la proa de (1,0) a
## (cos Δ, −sen Δ) en coordenadas de mapa —el signo sale de que `R_HAT` y
## `D_HAT` son perpendiculares y `D_HAT` cae hacia el sur—. Despejando: para
## apuntar a (dx, dy) hace falta Δ = atan2(−dy, dx).
## LAS VELAS SE HINCHAN DE VERDAD: se le cambia el material al barco por
## `velas_viento.gdshader`, que reconoce la lona POR COLOR en el vértice (el
## modelo es UNA malla con UN material, así que no hay un nodo "vela" que
## inclinar) y la comba a lo largo de su normal.
##
## EN HEADLESS NO SE TOCA: el renderer dummy escupe "Parameter material is
## null" al sustituir el material de ciertas mallas de `.glb`, y ahí es donde
## se miran los errores del proyecto ("sin salida = OK").
func _velas_al_viento(pivot: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for m: MeshInstance3D in pivot.find_children("*", "MeshInstance3D", true, false):
		for i in m.mesh.get_surface_count():
			var base: Material = m.mesh.surface_get_material(i)
			if base is ShaderMaterial:
				continue
			var mat := ShaderMaterial.new()
			mat.shader = load("res://shaders/velas_viento.gdshader")
			if base is StandardMaterial3D:
				var sm: StandardMaterial3D = base
				mat.set_shader_parameter("albedo_tex", sm.albedo_texture)
				mat.set_shader_parameter("albedo_col", sm.albedo_color)
			mat.set_shader_parameter("fuerza", 0.0)
			m.set_surface_override_material(i, mat)
			velas_mat = mat


## EL VIENTO QUE SE VE: unas rachas de cómic (`assets/map/viento.png`) cruzando
## alrededor del barco en la dirección del viaje. Van SIN SOMBREAR y sin
## profundidad, así que se leen igual sobre el mar y sobre una isla.
func _montar_viento() -> void:
	if viento_root != null and is_instance_valid(viento_root):
		return
	if not ResourceLoader.exists("res://assets/map/viento.png"):
		return
	viento_root = Node3D.new()
	viento_root.name = "Viento"
	viento_root.add_to_group("no_batch")
	add_child(viento_root)
	var tex: Texture2D = load("res://assets/map/viento.png")
	var quad := QuadMesh.new()
	quad.size = Vector2(VIENTO_LARGO, VIENTO_LARGO * tex.get_height() / float(tex.get_width()))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# CON PRUEBA DE PROFUNDIDAD: sin ella las rachas se dibujaban POR ENCIMA del
	# barco y lo tapaban. A la altura a la que van (0,9 sobre el agua) el mar no
	# las corta, pero el casco y las velas sí, que es lo que toca.
	mat.no_depth_test = false
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in VIENTO_RACHAS:
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = mat.duplicate()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Cada racha lleva su carril, su fase y su velocidad: en fila y a la vez
		# se leerían como una reja, no como viento.
		mi.set_meta("carril", randf_range(-1.0, 1.0))
		mi.set_meta("fase", randf())
		mi.set_meta("vel", randf_range(0.8, 1.35))
		mi.set_meta("alto", randf_range(-0.25, 0.55))
		mi.visible = false
		viento_root.add_child(mi)


## Coloca las rachas cada fotograma: nacen por detrás del barco y cruzan hacia
## donde sopla, apagándose en las dos puntas del recorrido.
func _tick_viento(delta: float) -> void:
	if viento_root == null or not is_instance_valid(viento_root):
		return
	if velas_mat != null:
		velas_mat.set_shader_parameter("fuerza", viento_fuerza * VELA_COMBA)
		# El empuje va en coordenadas del MODELO: la direccion del viento pasada
		# por la inversa de la base del barco. Asi la lona se comba hacia donde
		# sopla sea cual sea el rumbo, sin tener que saber cual es la proa.
		if ship_pivot != null and is_instance_valid(ship_pivot):
			var mundo := R_HAT * viento_dir.x + D_HAT * viento_dir.y
			velas_mat.set_shader_parameter("empuje",
				ship_pivot.global_transform.basis.inverse() * mundo)
	var encendido := viento_fuerza > 0.01
	viento_root.visible = encendido
	if not encendido:
		return
	# LOS VECTORES SE DESPEJAN DE `_world`, que mapea la x del mapa a `R_HAT` y
	# la y a `D_HAT`: la dirección del viento en el mundo es `R_HAT·dx +
	# D_HAT·dy`, y su perpendicular sale de girar (dx, dy) 90° en el mapa, o sea
	# (−dy, dx). Puestos a ojo —con los signos cambiados— las rachas salían
	# todas amontonadas a un lado del barco en vez de rodearlo.
	var d3 := R_HAT * viento_dir.x + D_HAT * viento_dir.y
	var p3 := R_HAT * -viento_dir.y + D_HAT * viento_dir.x
	# Y la racha se dibuja TUMBADA sobre el agua (−90° en X) y girada para que
	# su eje largo siga a `d3`. Con el giro en X puesto, el eje largo del quad
	# sigue siendo el +X del mundo, así que el ángulo sale de ahí.
	var yaw := rad_to_deg(atan2(-d3.z, d3.x))
	var centro := _world(ship_px)
	# EL VIENTO CRECE CON EL BARCO. En el menú y en la portada va a escala 2,3,
	# así que unas rachas de tamaño de mapa se le quedaban debajo y no se veían:
	# medían un tercio de su eslora y se escondían tras el casco.
	var esc := 1.0
	if ship_pivot != null and is_instance_valid(ship_pivot):
		esc = maxf(ship_pivot.scale.x, 0.2)
	for mi: MeshInstance3D in viento_root.get_children():
		var f: float = fposmod(float(mi.get_meta("fase"))
			+ _t * float(mi.get_meta("vel")) * VIENTO_VEL / VIENTO_ANCHO, 1.0)
		var avance := (f - 0.5) * VIENTO_ANCHO
		var lado := float(mi.get_meta("carril")) * VIENTO_ANCHO * 0.42
		mi.position = centro + (d3 * avance + p3 * lado) * esc \
			+ Vector3(0.0, (0.9 + float(mi.get_meta("alto"))) * esc, 0.0)
		mi.rotation_degrees = Vector3(-90.0, yaw, 0.0)
		mi.scale = Vector3.ONE * esc
		mi.visible = true
		# Se apaga en las dos puntas: entra, cruza y se va.
		var a: float = sin(f * PI)
		var m2: StandardMaterial3D = mi.material_override
		m2.albedo_color = Color(1, 1, 1, a * a * 0.25 * viento_fuerza)


func _rumbo_de(dir: Vector2) -> float:
	if dir.length_squared() < 0.0001:
		return rumbo_extra
	return rad_to_deg(atan2(-dir.y, dir.x))


## VIRA HACIA UNA DIRECCIÓN POR EL CAMINO CORTO y levanta el viento en ese
## sentido. Se espera a que termine: primero se gira, y luego se navega.
func virar_a(dir: Vector2, fuerza := 1.0, seg := VIRAJE) -> void:
	if dir.length_squared() > 0.0001:
		viento_dir = dir.normalized()
	# El camino corto sale de normalizar la diferencia a ±180: sin eso, ir de
	# 170° a −170° daba una vuelta de 340 en vez de 20.
	var delta := wrapf(_rumbo_de(dir) - rumbo_extra, -180.0, 180.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "rumbo_extra", rumbo_extra + delta, seg)
	tw.tween_property(self, "viento_fuerza", clampf(fuerza, 0.0, 1.0), VIENTO_SUBE)
	await tw.finished


## Y AL LLEGAR VUELVE A SU RUMBO DE CASA, con el viento cayendo.
func enderezar_rumbo(seg := VIRAJE) -> void:
	var delta := wrapf(-rumbo_extra, -180.0, 180.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "rumbo_extra", rumbo_extra + delta, seg)
	tw.tween_property(self, "viento_fuerza", 0.0, VIENTO_BAJA)


## Cuánto viento pide un viaje: mucho si es largo, poco si es de un escenario
## al de al lado. Nunca cero, o el barco navegaría sin que nada lo empuje.
func _fuerza_de(px: float) -> float:
	return clampf(VIENTO_MIN + (1.0 - VIENTO_MIN) * px / VIENTO_LEJOS,
		VIENTO_MIN, 1.0)


func _viajar_barco(destino: Vector2, y_camara: float, seg: float,
		suavizado := Tween.EASE_IN_OUT) -> void:
	if scroll_tween != null:
		scroll_tween.kill()
		scroll_tween = null
	if ship_tween != null:
		ship_tween.kill()
		ship_tween = null
	scroll_speed = 0.0
	# PRIMERO VIRA Y LEVANTA EL VIENTO, y solo entonces navega.
	var rumbo := destino - ship_px
	await virar_a(rumbo, _fuerza_de(rumbo.length()))
	if not is_inside_tree():
		return
	Audio.sfx_suave("barco_mover", 0.0, minf(seg * 0.3, 0.3),
		randf_range(0.88, 1.12), seg, randf_range(0.45, 1.30))
	var subiendo := destino.y < ship_px.y
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(suavizado)
	tw.tween_property(self, "cam_center", y_camara, seg)
	tw.tween_property(self, "ship_px", destino, seg)
	# EL BALANCEO VA EN SU PROPIO TWEEN, y esto es lo que quitaba la PARADA del
	# barco al llegar al cartel. Estaba encadenado con `chain()` a los de
	# arriba, así que su vuelta a cero empezaba en el segundo `seg` y duraba
	# otro 0,4·seg — y `await tw.finished` esperaba a ESO. O sea que el barco
	# terminaba su viaje y se quedaba quieto casi medio segundo antes de que
	# arrancara el tramo siguiente. Suelto, el viaje acaba cuando acaba.
	var balanceo := create_tween()
	balanceo.set_trans(Tween.TRANS_SINE)
	balanceo.tween_property(self, "ship_roll", 6.0 if subiendo else -6.0, seg * 0.35)
	balanceo.tween_property(self, "ship_roll", 0.0, seg * 0.4)
	await tw.finished
	if is_inside_tree():
		enderezar_rumbo()


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
	# La malla crece CON el plano (48 para 340 u): el oleaje va por vertice,
	# asi que agrandando el mar sin subdividir mas, las olas se estiraban.
	mesh.subdivide_width = 64
	mesh.subdivide_depth = 64
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	# El plano se centra entre el TOPE DEL MAPA y el fondeadero del menú, que
	# es el punto más bajo al que llega la cámara (y desde la PORTADA se corre
	# además PORT_OFF hacia la izquierda). Centrado solo en el mapa, la esquina
	# inferior izquierda de la portada se salía del agua y se veía el vacío.
	# CENTRADO ENTRE LOS DOS TOPES DEL SCROLL, no contra el lienzo del mapa:
	# con el mar 2 la travesía sube hasta y=-7286 y el centrado viejo dejaba
	# la mitad norte flotando sobre el vacío (azul liso sin espuma).
	var abajo := maxf(CampaignData.MAP_HEIGHT, SEA_BOTTOM_PX) + 640.0
	var arriba := SCROLL_TOPE - 640.0
	mi.position = D_HAT * (((abajo + arriba) * 0.5) / PPU_Y)
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
func _setup_route(mar := mar_actual) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.32)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var lista := CampaignData.ports_of_sea(mar)
	for i in range(lista.size() - 1):
		# SOLO ENTRE LOS QUE ESTÁN PUESTOS: con el borde de un mar vecino
		# montado (dos escenarios sueltos), una línea hacia el tercero saldría
		# de la nada y se perdería en el vacío.
		if not montados.has(str(lista[i].id)) 				or not montados.has(str(lista[i + 1].id)):
			continue
		var a := _world(CampaignData.map_pos(lista[i].id))
		var b := _world(CampaignData.map_pos(lista[i + 1].id))
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
			# MARCADOS, para que `_rehacer_ruta` pueda barrer los que el
			# fusionado no se haya llevado: si queda alguno suelto, la pasada
			# siguiente lo funde OTRA VEZ junto a los nuevos y las líneas se
			# van doblando (medido: 5.628 triángulos pasaban a 18.072).
			dash.add_to_group("route_dash")
			add_child(dash)
			t = e + 0.2


## LOS ESCENARIOS SE MONTAN DE UNO EN UNO Y SE APUNTAN, para poder tener a la
## vez un mar entero y el BORDE del vecino (ver `_montar_bordes`). `montados`
## dice qué grupo tiene cada uno, así que montar dos veces el mismo es
## imposible por construcción.
var montados: Dictionary = {}


func _setup_nodes(mar := mar_actual, solo: Array = []) -> void:
	for p in CampaignData.ports_of_sea(mar):
		var id: String = p.id
		if montados.has(id) or (not solo.is_empty() and not id in solo):
			continue
		montados[id] = _grupo(mar_montando)
		var kind := CampaignData.get_kind(id)
		var pos := _world(CampaignData.map_pos(id))
		node_world[id] = pos
		var pivot := _spawn_model(load(KIND_MODELS[kind]), pos,
			float(KIND_FOOT.get(kind, 2.5)))
		pivot.add_to_group(_grupo(mar_montando))
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
			base_cueva.add_to_group(_grupo(mar_montando))
			_niebla_cueva(pos, float(KIND_FOOT.get(kind, 2.5)))
		# Los nodos NO proyectan sombra: son 9 modelos de ~40k triangulos y el
		# pase de sombras los dibujaba otra vez enteros, para una mancha que
		# desde esta camara casi no se ve.
		for m in pivot.find_children("*", "MeshInstance3D", true, false):
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var foot: float = float(KIND_FOOT.get(kind, 2.5))
		var blob := SceneBackdrop.blob_shadow(foot * 0.95, foot * 0.62)
		blob.position = pos + Vector3(0.15, 0.03, 0.1)
		blob.add_to_group(_grupo(mar_montando))
		add_child(blob)
		# La mancha es una sombra EN EL AGUA: sube con ella o se hunde.
		blob.set_meta("y0", blob.position.y)
		flotantes.append(blob)
		_cartel_nivel(pivot, foot, CampaignData.port_index(id) + 1,
			int(GameState.level_stars.get(id, 0)),
			GameState.is_port_unlocked(id), _lado_del_cartel(id), kind)
		if not GameState.is_port_unlocked(id):
			_dim_model(pivot)
			if base_cueva != null:
				_dim_model(base_cueva)


## A QUE LADO DEL ESCENARIO VA SU CARTEL. Manda el CANTO DE LA PANTALLA: en el
## carril de la derecha, un cartel a la derecha se salia de cuadro, asi que ahi
## se pone a la izquierda. En el carril del medio tambien va a la izquierda,
## que es donde NO esta el barco (`_ship_anchor` lo manda a la derecha de todo
## lo que no este en el carril derecho).
func _lado_del_cartel(id: String) -> float:
	return -1.0 if CampaignData.map_pos(id).x >= 360.0 else 1.0


## EL CARTEL: dos postes y una tabla, construidos aqui y no en un modelo,
## porque tiene que poder cambiar de numero y de estrellas. Va al lado del
## escenario, SIEMPRE SOBRE EL AGUA y medio sumergido.
##
## Y va HACIA ARRIBA en pantalla (−D_HAT), no hacia la camara: el barco del
## jugador se ancla SIEMPRE por debajo del nodo (`_ship_anchor`, +72 px), asi
## que subiendo el cartel los dos no pueden pisarse aunque caigan del mismo
## lado. Con el cartel abajo, el barco lo tapaba en cuanto se seleccionaba el
## escenario.
func _cartel_nivel(pivot: Node3D, foot: float, n: int, estrellas: int,
		unlocked: bool, lado: float, kind := "isla") -> void:
	var cartel := Node3D.new()
	cartel.rotation_degrees.y = 45.0
	# MEDIO SUMERGIDO: la base baja bien por debajo del mar (el pivote del nodo
	# esta a −0.10, asi que en local hay que bajar otro tanto) y la linea de
	# flotacion cruza los postes a media altura.
	var fx: float = float(CARTEL_X_KIND.get(kind, CARTEL_X))
	cartel.position = R_HAT * (lado * foot * fx) \
		- D_HAT * (foot * CARTEL_Z) + Vector3(0.0, -CARTEL_CALADO, 0.0)
	pivot.add_child(cartel)
	# ES EL MISMO LETRERO DE MADERA QUE EL CARTEL DE PASO (pedido por el
	# usuario): un modelo de verdad en vez de las tres cajas con una trama de
	# madera que había antes. Se escala por el ANCHO de su tablero, que es lo
	# que tiene que seguir midiendo `CARTEL_ANCHO` para no pisar al escenario.
	var s := CARTEL_ANCHO / TABLA_ANCHO
	var inst: Node3D = load(CARTEL_MODELO).instantiate()
	inst.scale = Vector3.ONE * s
	# El modelo va centrado en su origen (Y -0,5..0,5), así que se sube media
	# altura para que su base caiga en el pie del cartel.
	inst.position = Vector3(0.0, 0.5 * s, 0.0)
	cartel.add_child(inst)
	# Bloqueado, la madera se apaga a gris azulado. Se tiñe el material del
	# modelo (el `albedo_color` MULTIPLICA la textura), no se sustituye: con un
	# material plano se perdían la veta y los clavos.
	# EN HEADLESS NO SE TIÑE: el renderer dummy escupe "Parameter material is
	# null" al sustituir el material de ciertas mallas de `.glb`, y
	# `--headless --quit-after` es justo donde se miran los errores del
	# proyecto ("sin salida = OK"). Ahí no se dibuja nada, así que no se pierde.
	var dummy := DisplayServer.get_name() == "headless"
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if unlocked or dummy:
			continue
		for i in m.mesh.get_surface_count():
			var base: Material = m.mesh.surface_get_material(i)
			var mat: StandardMaterial3D = base.duplicate() if base is StandardMaterial3D \
					else StandardMaterial3D.new()
			mat.albedo_color = Color(0.46, 0.50, 0.62)
			m.set_surface_override_material(i, mat)
	# EL NUMERO, PINTADO A BROCHA EN LA TABLA, y DEBAJO LAS ESTRELLAS. Van aquí
	# y no flotando sobre el nodo (pedido por el usuario): con la hilera 2D
	# encima, las estrellas de un escenario caían al lado del vecino y no había
	# forma de saber de quién eran. Las medidas van en fracciones del tablero
	# MEDIDO del modelo, no en las de las cajas de antes.
	var tabla_y := (0.5 + TABLA_CY) * s
	var tabla_h := TABLA_ALTO * s
	var cara := TABLA_CARA * s
	var l := _num_quad(n, tabla_h * NUM_EN_TABLA, unlocked)
	l.position = Vector3(0.0, tabla_y + tabla_h * NUM_SUBE, cara)
	cartel.add_child(l)
	var e := _estrellas_quad(estrellas, tabla_h * ESTRELLAS_EN_TABLA, unlocked)
	e.position = Vector3(0.0, tabla_y - tabla_h * ESTRELLAS_BAJA, cara)
	cartel.add_child(e)


## EL NUMERO ES UNA IMAGEN HORNEADA, no texto. `tools/num_map.py` dibuja uno
## por escenario con la TRAMA de su material (arena, lona, madera o piedra)
## recortada por la silueta y con el RELIEVE ya pintado —luz por el canto de
## arriba y sombra por el de abajo—, que es lo que lo hace parecer incrustado.
##
## Se intento antes con `TextMesh` (geometria extruida de verdad) y Godot no
## puede con esta fuente: "Convex decomposing failed. Make sure the font doesn't
## contain self-intersecting lines", con la Exo 2 tanto Bold como Regular. El
## numero salia sin malla ninguna.
## LAS ESTRELLAS DE LA TABLA: la misma hilera de tres del juego, horneada en
## cuatro versiones (0 a 3 llenas) por `tools/num_map.py`.
func _estrellas_quad(k: int, alto: float, unlocked: bool) -> MeshInstance3D:
	var tex: Texture2D = load("res://assets/map/estrellas_%d.png"
		% clampi(k, 0, 3))
	var q := QuadMesh.new()
	var prop := 3.2
	if tex != null and tex.get_height() > 0:
		prop = float(tex.get_width()) / float(tex.get_height())
	q.size = Vector2(alto * prop, alto)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if not unlocked:
		m.albedo_color = Color(0.46, 0.48, 0.54)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group("no_batch")
	return mi


func _num_quad(n: int, alto: float, unlocked: bool) -> MeshInstance3D:
	var tex: Texture2D = load("res://assets/map/num_%d.png" % n)
	var q := QuadMesh.new()
	var prop := 1.0
	if tex != null and tex.get_height() > 0:
		prop = float(tex.get_width()) / float(tex.get_height())
	q.size = Vector2(alto * prop, alto)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	# ALPHA_SCISSOR y no transparencia normal: el numero no tiene que ordenarse
	# contra el mar ni contra la niebla de la cueva, y asi no parpadea al pasar
	# un jiron por delante.
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	# SIN SOMBREAR: el relieve viene HORNEADO en la imagen, asi que dejar que
	# el sol del mapa vuelva a iluminarlo solo servia para aplastarlo — en la
	# cara en sombra del cartel del puerto el numero desaparecia del todo.
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Un escenario bloqueado tiene su numero apagado, como su modelo.
	if not unlocked:
		m.albedo_color = Color(0.46, 0.48, 0.54)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# `GeometryBatch.bake` funde la geometria estatica del mapa y LIBERA los
	# originales: sin esto el numero se iria con ellos.
	mi.add_to_group("no_batch")
	return mi


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
		mi.add_to_group(_grupo(mar_montando))
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
		mi.add_to_group(_grupo(mar_montando))
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
	# LOS COLECCIONABLES QUE SE LUCEN: la bandera pirata en el mastil, el
	# koinobori, el farol fantasma... (ver `ColVisibles`). Se montan aqui, al
	# construir el barco, asi que una pieza nueva luce al volver al menu.
	ColVisibles.decorar_barco(ship_pivot)
	_velas_al_viento(ship_pivot)
	_montar_viento()
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
	_rehacer_overlays()

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
	boton_barco = _build_boton_barco()
	ui.add_child(boton_barco)


## EL BOCADILLO DE "VOLVER AL BARCO" (pedido por el usuario): en cuanto el
## jugador se aleja de donde esta su barco, aparece meciendose un bocadillo
## REDONDO con el rabo hacia abajo y el barco dentro; al tocarlo, la camara
## vuelve de un viaje a donde esta.
##
## VA SIEMPRE EN EL MISMO SITIO (abajo, centrado sobre el submenu) y no
## persiguiendo al barco: es un boton que se pulsa, y uno que cambia de sitio
## se falla. El rabo hacia abajo lo ata al canto de la pantalla en vez de
## dejarlo flotando en mitad del mar.
func _build_boton_barco() -> Button:
	var b := Button.new()
	b.name = "BotonBarco"
	b.custom_minimum_size = Vector2(BARCO_BTN, BARCO_BTN * 1.25)
	b.size = b.custom_minimum_size
	b.visible = false
	b.modulate.a = 0.0
	b.tooltip_text = "Volver al barco"
	# Sin crujido: aquí no navega el barco, se mueve la CÁMARA.
	b.set_meta("snd", "click")
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var globo := TextureRect.new()
	globo.name = "Globo"
	globo.texture = load("res://assets/ui/bocadillo_barco.png")
	globo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	globo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	globo.set_anchors_preset(Control.PRESET_FULL_RECT)
	globo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(globo)
	# El barco va dentro del CIRCULO, que ocupa el lado del bocadillo
	# CONTRARIO al rabo (`_orientar_boton_barco` lo recoloca al voltearse).
	var ic := TextureRect.new()
	ic.name = "Barco"
	ic.texture = load("res://assets/ui/ic_barco.png")
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	PrepBoard.add_press_feedback(b)
	b.pressed.connect(func() -> void:
		_scroll_to(ship_px)
		scroll_speed = 0.0)
	return b


## Aparece o se retira segun lo lejos que ande la camara del barco, y se mece
## mientras esta puesto. El vaiven va en VALORES ABSOLUTOS (nada de
## `as_relative`, la leccion de la flecha del dialogo: un tween en bucle que
## acumula se escapa de la pantalla).
func _actualizar_boton_barco() -> void:
	if boton_barco == null or not is_instance_valid(boton_barco):
		return
	# La distancia se mide contra el punto al que la cámara PUEDE llegar: el
	# barco del escenario 1 queda más al sur que el tope, así que estando
	# encima el bocadillo salía igual (le pasó al usuario).
	var alcanzable: float = clampf(ship_px.y, scroll_min, scroll_max)
	# SOLO EN EL MAPA. La misma escena hace de menú y de portada, y allí el
	# barco está fondeado MUY por debajo del mapa (`MENU_ANCHOR`): recortarlo
	# al tope del scroll lo dejaba a 2.000 px de la cámara y el bocadillo
	# salía en la pantalla de inicio (le pasó al usuario).
	var lejos: bool = _mapa_activo() 		and absf(cam_center - alcanzable) > BARCO_LEJOS
	# EN EL MAPA, MAS `y` ES MAS ABAJO (el escenario 1 es el de mas y, ver
	# CampaignData.MAP_POS): con el barco en una `y` MENOR que la camara, el
	# barco queda por ARRIBA y el bocadillo se va al canto de arriba con el
	# rabo vuelto (pedido por el usuario).
	var arriba: bool = ship_px.y < cam_center
	# Se mira TAMBIÉN lo que el botón está enseñando: quien lo apaga por fuera
	# (`_set_map_ui_visible` al salir del mapa) dejaba la bandera diciendo que
	# seguía puesto, y al volver ya no se encendía nunca.
	if lejos == _barco_visible and boton_barco.visible == lejos 			and (not lejos or arriba == _barco_arriba):
		return
	_barco_visible = lejos
	_barco_arriba = arriba
	if _barco_tween != null and _barco_tween.is_valid():
		_barco_tween.kill()
	if not lejos:
		var sal := create_tween()
		sal.tween_property(boton_barco, "modulate:a", 0.0, 0.18)
		sal.tween_callback(func() -> void: boton_barco.visible = false)
		return
	var y0 := _orientar_boton_barco(arriba)
	if not boton_barco.visible:
		boton_barco.visible = true
		create_tween().tween_property(boton_barco, "modulate:a", 1.0, 0.22)
	# El vaiven va SIEMPRE hacia el centro de la pantalla, o sea al reves
	# segun el canto en el que este pegado.
	var d := 12.0 if arriba else -12.0
	_barco_tween = create_tween().set_loops()
	_barco_tween.tween_property(boton_barco, "position:y", y0 + d, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_barco_tween.tween_property(boton_barco, "position:y", y0, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## ¿Estamos EN EL MAPA de aventura? En `level_select3d` a pelo, siempre; en
## `main_menu`, que hereda de aquí y es además menú y portada, solo cuando la
## cámara ya está en el mapa (lo redefine).
func _mapa_activo() -> bool:
	return true


## Pega el bocadillo al canto que toca y le da la vuelta al rabo. Devuelve la
## `y` de reposo (la del vaiven). El GLOBO se voltea con `flip_v` y el BARCO
## no: el dibujo del barco tiene que seguir derecho, asi que lo unico que
## cambia es a que mitad del bocadillo se ancla (la del circulo).
func _orientar_boton_barco(arriba: bool) -> float:
	var lienzo := GameState.canvas_size()
	var alto: float = boton_barco.size.y
	var y0: float = (GameState.safe_top() + TOP_BAR_H + 10.0) if arriba \
		else (lienzo.y - SUBMENU_H - alto - 18.0)
	boton_barco.position = Vector2((lienzo.x - boton_barco.size.x) * 0.5, y0)
	var globo: TextureRect = boton_barco.get_node("Globo")
	globo.flip_v = arriba
	var ic: TextureRect = boton_barco.get_node("Barco")
	ic.set_anchors_preset(Control.PRESET_BOTTOM_WIDE if arriba
		else Control.PRESET_TOP_WIDE)
	ic.offset_left = BARCO_BTN * 0.19
	ic.offset_right = -BARCO_BTN * 0.19
	if arriba:
		ic.offset_top = -BARCO_BTN * 0.81
		ic.offset_bottom = -BARCO_BTN * 0.19
	else:
		ic.offset_top = BARCO_BTN * 0.19
		ic.offset_bottom = BARCO_BTN * 0.81
	return y0


## Overlay 2D de un nodo: botón táctil transparente, estrellas conseguidas y
## cartel de madera con el número. Se reposiciona cada frame con la cámara.
## Los overlays 2D de los nodos DEL MAR EN CURSO, mas el de cada cartel de
## paso. Se rehacen enteros al cambiar de mar: son los botones con los que se
## toca el mapa, así que tienen que corresponderse con lo que hay montado.
func _rehacer_overlays(mares: Array = []) -> void:
	if ui == null:
		return
	if mares.is_empty():
		mares = [mar_actual]
	for id in node_overlays:
		var r: Node = node_overlays[id]["root"]
		if is_instance_valid(r):
			r.queue_free()
	node_overlays.clear()
	# EL ORDEN IMPORTA, y por partida doble: en una capa de Control el toque se
	# lo lleva el ÚLTIMO hijo, o sea el que se dibuja encima.
	#   1) LOS CARTELES DE PASO VAN PRIMERO, así que el escenario pegado a uno
	#      le gana el toque donde se solapen. El botón del cartel mide 400×330
	#      —se agrandó porque había que acertar en una zona muy concreta— y el
	#      escenario del extremo está a `PASO_CARTEL` (330 px): con el cartel
	#      después, pulsar esa isla cambiaba de mar en vez de entrar en ella.
	#   2) Y TODOS ELLOS AL PRINCIPIO DE `ui`, por debajo de la interfaz.
	#      `add_child` los pone al FINAL, así que tras rehacerlos quedaban por
	#      encima del "Atrás" y del panel: con un escenario debajo, el botón no
	#      respondía.
	var creados: Array[Control] = []
	for nodo in get_tree().get_nodes_in_group("paso_mar"):
		if not is_instance_valid(nodo) or not nodo.has_meta("mar"):
			continue
		var mar_c: int = int(nodo.get_meta("mar"))
		var clave := "__mar%d" % mar_c
		if not node_world.has(clave):
			continue
		var ov2 := _build_paso_overlay(mar_c)
		node_overlays[clave] = ov2
		creados.append(ov2["root"])
	for mar: int in mares:
		for p in CampaignData.ports_of_sea(mar):
			# SOLO LOS QUE ESTÁN MONTADOS. `_process` coloca cada overlay con
			# `node_world[id]`, y el borde de un mar vecino deja ahí unos ids
			# puestos y otros no: pidiendo uno que no está, revienta.
			if not montados.has(str(p.id)):
				continue
			var ov := _build_node_overlay(p)
			node_overlays[p.id] = ov
			creados.append(ov["root"])
	for i in creados.size():
		ui.add_child(creados[i])
		ui.move_child(creados[i], i)


func _build_paso_overlay(mar: int) -> Dictionary:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# EL BOTÓN CUBRE EL CARTEL ENTERO Y SU RÓTULO. El primero medía 260×150 y
	# había que acertar en una zona muy concreta (dicho por el usuario): el
	# letrero mide unos 300 px de ancho en pantalla y su nombre cuelga otros 90
	# por debajo, así que el área se midió contra eso y no a ojo.
	var b := Button.new()
	b.custom_minimum_size = Vector2(400, 330)
	b.size = Vector2(400, 330)
	b.position = Vector2(-200, -215)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.set_meta("snd", "velas")
	b.pressed.connect(cambiar_de_mar.bind(mar))
	root.add_child(b)
	return { "root": root, "unlocked": true }


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

	# SIN HILERA DE ESTRELLAS FLOTANDO: viven en el CARTEL del escenario, bajo
	# su numero (ver `_cartel_nivel`). Sueltas sobre el nodo, las de uno caian
	# al lado del vecino y no habia forma de saber de quien eran.

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
## Tablon propio del mapa (madera de deriva con amarres de cuerda). Su margen
## 9-slice cubre los dos amarres, que son lo unico que no se puede estirar.
const SUBMENU_TEX := "res://assets/ui/submenu_mapa.png"
const SUBMENU_MARGIN := 76
## Lo que se deja libre a cada lado: el tablón no ocupa la pantalla entera.
const SUBMENU_MARGEN := 96.0
## Tinte de la madera del tablon (se genero en gris de deriva).
const SUBMENU_TINTE := Color(1.22, 0.94, 0.66)
## EL SUBMENU DEL MAPA. Los BONIFICADORES viven aquí y no en el menú principal
## (pedido por el usuario): es donde se llevan puestos. Y su acceso NO SALE
## hasta tener el primero — un botón a una pantalla vacía no explica nada.
const SUBMENU_BOTONES := [
	["tesoro", "res://assets/ui/ic_mapa_tesoro.png", "Mapas"],
	["perks", "res://assets/ui/ic_perks.png", "Bonific."],
	["tienda", "res://assets/ui/ic_tienda.png", "Tienda"],
	["opciones", "res://assets/ui/ic_opciones.png", "Opciones"],
]


func _build_submenu() -> Control:
	var barra := Control.new()
	barra.custom_minimum_size = Vector2(0, SUBMENU_H)
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# EL TABLON: madera de deriva amarrada con cuerda en los dos extremos
	# (`submenu_mapa.png`). Es 9-slice SOLO horizontal — los amarres van en los
	# margenes y la madera del medio es lo unico que se estira.
	var tablon := NinePatchRect.new()
	tablon.texture = load(SUBMENU_TEX)
	tablon.patch_margin_left = SUBMENU_MARGIN
	tablon.patch_margin_right = SUBMENU_MARGIN
	tablon.patch_margin_top = 0
	tablon.patch_margin_bottom = 0
	# ESTRECHO Y CENTRADO: son tres accesos, no seis, y un tablón de punta a
	# punta de la pantalla para tres iconos se lee como una barra vacía.
	tablon.set_anchors_preset(Control.PRESET_FULL_RECT)
	tablon.offset_left = SUBMENU_MARGEN
	tablon.offset_right = -SUBMENU_MARGEN
	tablon.offset_top = 6.0
	tablon.offset_bottom = -10.0
	# OTRO COLOR que el gris de deriva con el que se genero: un tono de madera
	# CALIDA, que es la paleta del juego, y asi no se confunde con la barra
	# oscura del menu principal ni desaparece contra el azul del mar.
	tablon.modulate = SUBMENU_TINTE
	tablon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra.add_child(tablon)

	var fila := HBoxContainer.new()
	fila.set_anchors_preset(Control.PRESET_FULL_RECT)
	fila.offset_left = SUBMENU_MARGEN + 30.0
	fila.offset_right = -SUBMENU_MARGEN - 30.0
	# Los iconos, CENTRADOS en la madera: el tablon tiene su cuerda arriba y
	# abajo, asi que la banda util no es la caja entera.
	fila.offset_top = 10.0
	fila.offset_bottom = -32.0
	fila.add_theme_constant_override("separation", 6)
	barra.add_child(fila)
	for def in SUBMENU_BOTONES:
		# Sin ningún bonificador ganado, el suyo ni se monta.
		if str(def[0]) == "perks" and not GameState.tiene_algun_perk():
			continue
		fila.add_child(_boton_submenu(str(def[0]), str(def[1]), str(def[2])))
	return barra


## Un acceso del submenu: icono arriba y rotulo debajo, DIRECTAMENTE sobre el
## tablon. Sin el boton de madera del resto del juego: aqui el fondo ya lo pone
## el tablon, y un boton dentro de otro se leia como dos marcos encajados.
func _boton_submenu(id: String, icono: String, rotulo: String) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 92)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.set_meta("snd", "submenu")
	b.text = ""
	PrepBoard.add_press_feedback(b, 0.9)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var ic := TextureRect.new()
	ic.texture = load(icono)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(0, 50)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(ic)
	var l := Label.new()
	l.text = rotulo
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 19)
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
		"perks":
			GameState.perks_from = "mapa"
			GameState.fade_to_scene("res://scenes/perks_screen.tscn", 0.35, 0.45)
		"tienda":
			# CERRADA HASTA QUE SAVERIO ABRA SU PUESTO (nivel 4): el submenú
			# del mapa se saltaba la compuerta que sí respeta el menú.
			if not GameState.shop_unlocked():
				ui.add_child(_aviso_simple("La tienda",
					"Todavía no hay dónde comprar. **Saverio** montará su puesto más adelante en la travesía."))
				return
			GameState.shop_from = "mapa"
			GameState.fade_to_scene("res://scenes/shop_screen.tscn", 0.35, 0.45)
		"opciones":
			GameState.options_from = "mapa"
			GameState.fade_to_scene("res://scenes/options_screen.tscn", 0.35, 0.45)


## LOS MAPAS DEL TESORO son las MISIONES SECUNDARIAS (`TreasureData`): se
## abren en su propia pantalla, que es una MESA con los mapas desplegados.
func _mapas_del_tesoro() -> void:
	GameState.fade_to_scene("res://scenes/treasure_screen.tscn", 0.35, 0.45)


## LA VENTANA DEL ESCENARIO. Lleva GRAFICO PROPIO —pergamino con marco de
## CUERDA y argollas de laton (`panel_ficha.png`)— y no el tablon de madera del
## resto del juego: es la ventana que se abre desde el mapa y tenia que
## distinguirse de una pantalla mas (pedido por el usuario).
##
## SE CIERRA CON UN ASPA en la esquina, no con un boton de "Cerrar" al pie:
## abajo solo queda "Viajar", que es lo unico que se hace de verdad aqui.
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
	# CENTRADA POR OFFSETS, no por `position`. `Control.position` es ABSOLUTA
	# en el espacio del padre, asi que con las anclas al 0.5 hay que escribir
	# los cuatro offsets: con `position = -tamano/2` solo salia centrada por
	# casualidad (el padre medía 0 al construirla) y al recolocarla con el
	# padre ya medido se iba al cuadrante de arriba a la izquierda.
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.add_child(PrepBoard.make_nine_patch(FICHA_TEX, FICHA_MARGIN))
	overlay.add_child(panel)
	ficha_panel = panel
	_ficha_offsets(panel, FICHA_H)

	var margin := MarginContainer.new()
	# El marco de cuerda mide ~46 texeles y las argollas de las esquinas se
	# meten hacia dentro: hace falta mas aire del que parece por el dibujo.
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 46)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 40)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	margin.add_child(vb)

	var negrita := load("res://fonts/static/Exo2-Bold.ttf")

	info_title = Label.new()
	info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_title.add_theme_font_size_override("font_size", 32)
	info_title.add_theme_color_override("font_color", Color(0.42, 0.24, 0.06))
	if negrita != null:
		info_title.add_theme_font_override("font", negrita)
	vb.add_child(info_title)

	# "Fase N": el numero del escenario, que en el mapa va escrito en la propia
	# arena o en la vela y aqui hay que poder leerlo en claro.
	info_fase = Label.new()
	info_fase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_fase.add_theme_font_size_override("font_size", 22)
	info_fase.add_theme_color_override("font_color", Color(0.58, 0.40, 0.16))
	vb.add_child(info_fase)

	info_kind = Label.new()
	info_kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_kind.add_theme_font_size_override("font_size", 19)
	info_kind.add_theme_color_override("font_color", FADED)
	vb.add_child(info_kind)

	# ESTRELLAS GRANDES: son lo primero que se mira de un escenario ya jugado.
	info_stars_box = HBoxContainer.new()
	(info_stars_box as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	info_stars_box.custom_minimum_size = Vector2(0, 62)
	vb.add_child(info_stars_box)

	info_desc = Label.new()
	info_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_desc.add_theme_font_size_override("font_size", 18)
	info_desc.add_theme_color_override("font_color", Color(0.62, 0.22, 0.12))
	vb.add_child(info_desc)

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

	# EL OBJETIVO: como se cierra la jornada y que castiga este tipo.
	var obj := _seccion(cuerpo, "Objetivo")
	info_cierre = Label.new()
	info_cierre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_cierre.add_theme_font_size_override("font_size", 17)
	info_cierre.add_theme_color_override("font_color", DARK)
	obj.add_child(info_cierre)

	# SIN el rotulo "Clientes:" delante: la seccion ya se llama "La clientela"
	# y repetirlo en la fila era decir dos veces lo mismo.
	var quien := _seccion(cuerpo, "La clientela")
	info_clients_row = _icon_row(quien, "")
	info_time = _stat_label(quien)

	var carta := _seccion(cuerpo, "La carta")
	info_recipes_row = _icon_row(carta, "")

	var premios := _seccion(cuerpo, "Objetivos y premios")
	info_goal = _stat_label(premios)
	info_record = _stat_label(premios)

	info_tesoro = _seccion(cuerpo, "Tesoro")
	info_tesoro_row = _icon_row(info_tesoro, "")

	sail_button = Button.new()
	sail_button.custom_minimum_size = Vector2(282, 100)
	sail_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Placa de oro: es el boton que arranca la partida. SIN desplazamiento del
	# rotulo (ver `skin_start_button`): a esta altura la placa llena el
	# rectangulo del boton, asi que "Viajar" se centra en el.
	PrepBoard.skin_start_button(sail_button, 0.0)
	var gorda := load("res://fonts/static/Exo2-Bold.ttf")
	if gorda != null:
		sail_button.add_theme_font_override("font", gorda)
	sail_button.add_theme_font_size_override("font_size", 42)
	sail_button.text = "Viajar"
	sail_button.set_meta("snd", "velas")
	sail_button.pressed.connect(_on_sail_pressed)
	vb.add_child(sail_button)

	# EL ASPA, cabalgando la esquina de arriba a la derecha del pergamino.
	var aspa := TextureButton.new()
	aspa.texture_normal = load("res://assets/ui/boton_cerrar.png")
	aspa.ignore_texture_size = true
	aspa.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	# VA COLGADA DEL OVERLAY, NO DEL PANEL.  es un CONTENEDOR:
	# estira a todos sus hijos hasta llenarlo, asi que el aspa metida dentro
	# salia del tamano del pergamino entero, tapandolo. Su sitio lo pone
	# , que es quien sabe el alto que tiene la ventana.
	aspa.anchor_left = 0.5
	aspa.anchor_top = 0.5
	aspa.anchor_right = 0.5
	aspa.anchor_bottom = 0.5
	aspa.set_meta("snd", "atras")
	aspa.pressed.connect(_cerrar_ficha)
	PrepBoard.add_press_feedback(aspa, 0.9)
	overlay.add_child(aspa)
	ficha_aspa = aspa
	return overlay


## Un bloque de la ficha: su rotulo y debajo su contenido. Devuelve la CAJA del
## contenido, y le deja apuntada la seccion entera en un meta: quien quiera
## esconder el bloque tiene que esconder ESA, no el padre.
##
## Costo un fallo feo: `_fill_tesoro` hacia `info_tesoro.get_parent().visible`,
## y como las tres piezas (separador, rotulo y caja) colgaban del CUERPO, el
## padre de la caja era el cuerpo entero — los escenarios sin coleccionable
## abrian la ficha COMPLETAMENTE VACIA.
func _seccion(padre: VBoxContainer, titulo: String) -> VBoxContainer:
	var sec := VBoxContainer.new()
	sec.add_theme_constant_override("separation", 2)
	padre.add_child(sec)
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 10)
	sec.add_child(sep)
	var t := Label.new()
	t.text = titulo
	t.add_theme_font_size_override("font_size", 21)
	t.add_theme_color_override("font_color", Color(0.55, 0.34, 0.08))
	var negrita2 := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita2 != null:
		t.add_theme_font_override("font", negrita2)
	sec.add_child(t)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 3)
	sec.add_child(caja)
	caja.set_meta("seccion", sec)
	return caja


## Enseña o esconde el BLOQUE entero de una seccion (rotulo incluido).
func _ver_seccion(caja: Control, on: bool) -> void:
	var sec: Control = caja.get_meta("seccion", null)
	if sec != null:
		sec.visible = on


## Cuando se abrio la ficha, para ARMAR sus botones: en el ordenador un clic
## genera DOS eventos (raton + toque sintetizado) y el que abria la ficha
## pulsaba de propina el "Viajar" que acababa de aparecer bajo el cursor — con
## genero faltando, el aviso de David salia detras de la propia ficha.
var _ficha_abierta_ms := 0


func _abrir_ficha() -> void:
	if map_info_panel == null:
		return
	_ficha_abierta_ms = Time.get_ticks_msec()
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
	# SIN ROTULO cuando la fila no lo pide: en la ficha del escenario las
	# secciones ya se llaman "La clientela" y "La carta", asi que repetirlo
	# delante de los iconos era decir dos veces lo mismo — y con el titulo
	# vacio quedaba un ":" suelto.
	var titulo := str(row.get_meta("titulo", ""))
	if titulo == "":
		return
	var l := Label.new()
	l.text = "%s:" % titulo
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
## LA LÍNEA ENTERA SIEMPRE (pedido por el usuario, no re-litigar): "tantas
## monedas ➜ tantas estrellas ➜ esto te llevas", esté el escalón conseguido o
## no. Se probó a dejar los conseguidos solo con su premio, y en una ventana
## con sitio de sobra lo que se pierde —cuánto oro pide cada estrella— vale más
## que los dos renglones que se ahorran: al repetir un escenario, ese umbral es
## justo lo que hay que volver a batir.
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
		# SIN FLECHA entre el oro y las estrellas (pedido por el usuario): la
		# línea ya se lee de izquierda a derecha sola, y con premio o sin él la
		# flecha solo era un icono más que colocar.
		fila.add_child(_money_chip(int(e[1])))
		fila.add_child(PrepBoard.make_star_row(n, 3, 26, true))
		_premios_de(fila, port, n, goal, logradas)


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
	# MEJORA DE RECETA: se ensena el plato ya coronado, que es lo que se gana.
	var mejora_base := str(port.get("reward_upgrade_3", ""))
	if mejora_base != "":
		var mejora: Dictionary = RecipeData.upgrade_of(mejora_base)
		if not mejora.is_empty():
			_row_icon(fila, RecipeData.get_dish_texture(str(mejora.get("id", ""))),
					"", 40, hecho3)
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
	info_fase.text = "Fase %d" % (idx + 1)
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
	# GRANDES: 52 px de estrella. Son lo primero que se mira de un escenario.
	info_stars_box.add_child(PrepBoard.make_star_row(best, 3, 52, true))

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
	_ficha_offsets(ficha_panel, clampf(
		ficha_cuerpo.get_combined_minimum_size().y + FICHA_EXTRA,
		FICHA_MIN, FICHA_MAX))


## Centra la ventana con las anclas al 0.5 y le da el alto pedido.
func _ficha_offsets(panel: Control, alto: float) -> void:
	panel.custom_minimum_size = Vector2(FICHA_W, alto)
	panel.offset_left = -FICHA_W * 0.5
	panel.offset_right = FICHA_W * 0.5
	panel.offset_top = -alto * 0.5 + FICHA_BAJADA
	panel.offset_bottom = alto * 0.5 + FICHA_BAJADA
	if ficha_aspa != null:
		# Cabalgando la esquina de arriba a la derecha del pergamino.
		ficha_aspa.offset_left = FICHA_W * 0.5 - FICHA_ASPA + 20.0
		ficha_aspa.offset_right = FICHA_W * 0.5 + 20.0
		ficha_aspa.offset_top = panel.offset_top - 20.0
		ficha_aspa.offset_bottom = panel.offset_top - 20.0 + FICHA_ASPA


## CÓMO SE CIERRA LA JORNADA Y QUÉ CASTIGA EL TIPO. Es la información que el
## jugador necesita ANTES de zarpar y que hasta ahora solo estaba en la guía:
## un abordaje no se juega como una isla, y el panel no lo decía en ninguna
## parte. Sale de los mismos datos que gobiernan el nivel, así que no puede
## contradecirlo.
func _texto_cierre(id: String) -> String:
	var sin_fin := CampaignData.unlimited_clients(id)
	# LOS CASTIGOS POR VACÍO SON DEL MAR 2 EN ADELANTE: la ficha de un
	# escenario del mar 1 no puede amenazar con un castigo que alli no existe.
	var castigos := CampaignData.sea_of(id) >= 2
	match CampaignData.get_kind(id):
		"isla":
			return "Acaba cuando se va el último cliente. Quien se marche sin probar bocado te cuesta oro." \
				if castigos else "Acaba cuando se va el último cliente."
		"puerto":
			return "Acaba cuando se va el último cliente. Si TRES se marchan sin probar bocado, pierdes la jornada." \
				if castigos else "Acaba cuando se va el último cliente."
		"abordaje":
			return "Clientela sin fin contra el reloj. Cada cliente que se marcha sin probar bocado te quita 15 s." \
				if castigos else "Clientela sin fin contra el reloj."
		"cueva":
			return "La guarida del jefe: clientela sin fin hasta que él aparece. Ahí manda su paciencia, no el reloj."
	return "Clientela sin fin." if sin_fin else ""


## EL COLECCIONABLE QUE SE PUEDE CONSEGUIR AQUÍ, con una interrogación encima
## mientras no se tenga: dice que en este escenario hay algo que llevarse sin
## desvelar qué es. Ya conseguido sale a plena luz y con su visto.
func _fill_tesoro(id: String) -> void:
	var item := CampaignData.collectible_of(id)
	_ver_seccion(info_tesoro, item != "")
	if item == "":
		return
	for c in info_tesoro_row.get_children():
		c.queue_free()
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
	# YA CONSEGUIDO: a plena luz y con el VISTO VERDE encima, como las
	# recompensas. En silueta mientras no se tenga.
	ic.modulate = Color.WHITE if tengo else Color(0.14, 0.11, 0.09, 0.9)
	caja.add_child(ic)
	if tengo:
		var visto := TextureRect.new()
		visto.texture = load("res://assets/ui/ic_hecho.png")
		visto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		visto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		visto.position = Vector2(16, 14)
		visto.size = Vector2(36, 36)
		visto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caja.add_child(visto)
	info_tesoro_row.add_child(caja)
	# CON LA PIEZA YA EN LA VITRINA no hace falta decir cómo se consigue: eso
	# es una instrucción, y lo que queda ahí es un recuerdo.
	if tengo:
		return
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
	# UN ESCENARIO DE OTRO MAR obliga a cambiar de mapa primero: pasa al cerrar
	# la jornada del jefe, cuando `next_port_id` ya apunta al mar siguiente. Sin
	# esto, el mapa intentaba enfocar un nodo que no está montado y la cámara se
	# iba a mar abierto.
	# UNA TRAVESÍA ENTRE MARES EN CURSO manda: sus tweens llevan la cámara y el
	# barco, y un toque en un nodo por el camino los partiría en dos.
	if cambiando_mar:
		return
	var suyo := CampaignData.sea_of(id)
	if suyo != mar_actual and not CampaignData.get_port(id).is_empty():
		# La travesía es asíncrona y acaba llamando aquí otra vez, ya con el
		# mar nuevo montado y con ESTE escenario como destino.
		cambiar_de_mar(suyo, id)
		return
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
	# SIN CRUJIDO SI EL BARCO NO SE MUEVE (pedido por el usuario): reelegir el
	# escenario en el que ya está no es una travesía.
	if dist < 8.0:
		_scroll_to(CampaignData.map_pos(id))
		return
	# EL CRUJIDO DURA LO QUE DURA EL VIAJE, con fundido a la entrada y a la
	# salida para que no empiece ni acabe a cuchillo, y con el TONO sorteado:
	# es el mismo crujido, y cambiando de nivel diez veces seguidas sonaba
	# siempre igual.
	# Y ARRANCA YA DENTRO DE LA MADERA, no en la cabeza de la toma: sus
	# primeras décimas son las más flojas y en un salto corto entre dos
	# niveles vecinos no daba tiempo a oír el crujido. El punto de
	# entrada también se sortea, que es variedad gratis.
	# PRIMERO VIRA Y LEVANTA EL VIENTO, y solo entonces navega (pedido por el
	# usuario). La fuerza sale de la DISTANCIA: un salto al escenario de al lado
	# es una brisa y una travesía larga, un vendaval.
	await virar_a(target - ship_px, _fuerza_de(dist))
	if not is_inside_tree():
		return
	Audio.sfx_suave("barco_mover", 0.0, minf(dur * 0.35, 0.35),
		randf_range(0.86, 1.16), dur, randf_range(0.45, 1.30))
	ship_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ship_tween.tween_property(self, "ship_px", target, dur)
	ship_tween.parallel().tween_property(self, "ship_roll", 5.0, dur * 0.5)
	ship_tween.parallel().tween_property(self, "ship_roll", 0.0, dur * 0.5) \
		.set_delay(dur * 0.5)
	# Y al llegar vuelve a su rumbo de casa, con el viento cayendo.
	ship_tween.finished.connect(enderezar_rumbo.bind(VIRAJE),
		CONNECT_ONE_SHOT)
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
		{ "text": "Las **islas** son tranquilas: poca clientela y con la carta que yo te ponga. Perfectas para aprender el oficio.", "mood": "hablando" },
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
	var target := clampf(point.y, scroll_min, scroll_max)
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
	# Y MIENTRAS SE CRUZA DE MAR TAMPOCO (pedido por el usuario): la travesía
	# lleva la cámara y el barco con sus tweens, y un arrastre por el camino
	# los partiría en dos — el mapa se quedaría en un sitio y el barco en otro.
	if cambiando_mar:
		scroll_dragging = false
		scroll_speed = 0.0
		return
	if event is InputEventScreenDrag:
		if scroll_tween != null:
			scroll_tween.kill()
			scroll_tween = null
		cam_center = clampf(cam_center - event.relative.y, scroll_min, scroll_max)
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
	# El clic fantasma del ordenador (ver _abrir_ficha): un "Viajar" en los
	# primeros 400 ms es el mismo clic que abrio la ficha, no una decision.
	if Time.get_ticks_msec() - _ficha_abierta_ms < 400:
		return
	# La ficha se retira ANTES de cualquier aviso: el dialogo de la falta de
	# genero (y el cartel de la tienda) tienen que salir sobre el mapa, no
	# detras de la ventana.
	_cerrar_ficha()
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
	caja.z_index = 200
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
	caja.z_index = 200
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
			# La vuelta de la tienda cae en el MAPA, en el mismo escenario
			# (GameState.map_port ya lo recuerda): sin esto se volvia al menu
			# y habia que rehacer el camino entero.
			GameState.shop_from = "mapa"
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
	_tick_viento(delta)
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
			scroll_min, scroll_max)
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
			sin(_t * 1.1) * 2.0 if bob else 0.0, SHIP_YAW + rumbo_extra,
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

	_actualizar_boton_barco()

	# Overlays 2D anclados a sus nodos 3D.
	if not map_visible:
		return
	for id in node_overlays:
		var scr := cam.unproject_position(node_world[id] + Vector3(0.0, 0.55, 0.0))
		node_overlays[id]["root"].position = scr
