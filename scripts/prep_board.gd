extends Control
## Tabla de preparación gráfica: cada receta avanza por etapas visuales
## (bola de arroz → lámina → relleno → rollo → plato) sin textos.
## Los ingredientes desaparecen de la tabla cuando ya no se van a usar.
## El guardado funciona por pilas: cada caja apila hasta stack_max platos
## IGUALES (x2, x3...). Emite craft_event para que el chef reaccione.

## price_override > 0 cuando el plato no vale lo que dice su receta (el barco
## combinado se cotiza por los platos con los que se montó).
## extras: ids de los añadidos (jengibre/wasabi/soja) que lleva ESE plato.
signal dish_served(recipe_id: String, price_override: int, extras: Array,
	level_override: int, eat_mult_override: float)
signal craft_event(kind: String, stage_id: String)
## Un gesto mal hecho cuesta dinero (cortes de fugu y atún rojo). El nivel lo
## descuenta del monedero sin bajar de 0.
signal money_penalty(amount: int)
## Corte lento hecho DEMASIADO RÁPIDO. Va aparte de `money_penalty` porque el
## guion del nivel 5 perdona el dinero mientras enseña el corte, pero Gigi
## tiene que regañar igual.
signal slice_failed
## Contenido de las cajas de guardado tras cada cambio: array paralelo a las
## cajas con {"id", "count"} o null si esa caja está vacía. El nivel lo usa
## para reflejar lo guardado en las cajas 3D que hay junto al chef.
signal storage_changed(slots: Array)
## El jugador le ha pasado la receta al ayudante: el nivel le hace dar un
## saltito para que se vea quién ha cocinado ese plato.
signal helper_used

enum State { IDLE, CRAFTING, READY }

const SWIPE_THRESHOLD := 70.0
## Cuánto se ve la etapa del paso anterior antes de cambiarla por el sprite
## "from" de un drag_stage (ver _swap_stage_from).
const FROM_SWAP_DELAY := 0.5
## Recorrido horizontal (px) que debe cubrir el corte lento, de izquierda a
## derecha, por todo el ancho de la tabla.
const SLICE_SWEEP := 360.0
## Recorrido del corte VERTICAL (`direction: "v"`, el dorayaki). Más corto que
## el horizontal porque la tabla mide 312 px de alto y 520 de ancho.
const SLICE_SWEEP_V := 150.0
## Hueco entre los iconos redondos de debajo de las cajas (cancelar, barco,
## combinar). Apretado de 14 a 6 px para que la fila entera quepa más a la
## derecha y no quede pegada al borde de la mesa de elaboración.
const BUTTON_GAP := 6.0
const DISH_SIZE := Vector2(132, 120)
## Tamaño de cada ingrediente en la fila de la tabla.
const ING_SIZE := Vector2(88, 76)

var state := State.IDLE
var current_recipe: String = ""
var steps: Array = []
var step_index: int = 0

var taps_done: int = 0
var swipes_done: int = 0
var hold_time: float = 0.0
var holding := false
## hold_board con "move": hay que MANTENER Y MOVER (soplete). Se marca en cada
## arrastre y se consume en _process, así que si el dedo se para, se para todo.
var hold_moving := false
var hold_last_pos := Vector2.ZERO
var swipe_active := false
var swipe_counted := false
var swipe_start := Vector2.ZERO
## stir_board: vueltas completadas y ángulo acumulado de la vuelta en curso.
var stir_turns: int = 0
var stir_angle: float = 0.0
var stir_last_angle: float = 0.0
var stirring := false
## slice_board: cortes hechos y datos del corte en curso (inicio y tiempo).
var slices_done: int = 0
var slice_active := false
var slice_start := Vector2.ZERO
var slice_start_ms := 0
## Avance horizontal (px) del corte lento en curso, para llenar la barra.
var slice_progress: float = 0.0
## Avance (0-1) del deslizamiento EN CURSO, para la barra de progreso.
var swipe_progress: float = 0.0
## fry_board: reloj de la fritura y sprite del plato que saldrá (según el
## punto en que se soltó: crudo, bien o quemado).
var frying := false
var fry_time: float = 0.0
var fry_dish: String = ""
## drag_choice: identidad del plato según el pescado elegido (aburi de atún).
var choice_dish: String = ""
## drag_choice: opción marcada con un toque. La elección se puede hacer en DOS
## tiempos (tocar para elegir y luego arrastrar) o de una (arrastrar directo).
var choice_selected: String = ""
## Punto donde empezó el gesto sobre una opción, para distinguir toque de
## arrastre de verdad.
var choice_press_at := Vector2.ZERO
var choice_moved := false
## Lo mismo para los arrastres normales de ingrediente: la zona activa cubre
## toda la mesa (fila de ingredientes incluida), así que hace falta el umbral
## para que un toque no cuente como soltar.
var drag_press_at := Vector2.ZERO
var drag_moved := false
## Receta ELEGIDA por el jugador, para el cooldown (el plato puede acabar
## siendo otra: tempura poco hecha, aburi de atún...).
var ready_base: String = ""
## Tiempo de comida propio del plato listo (0 = el de su receta). Solo lo usa
## el barco combinado, que tarda según los platos que lleve.
var ready_eat_mult: float = 0.0
## Mensaje momentáneo sobre la tabla ("¡Más lento!").
var message_label: Label = null
var message_tween: Tween = null
## drag_stage: fantasma del sprite de etapa mientras se arrastra al prop.
## Igual que en las cajas: exige arrastre real, un toque no completa el paso.
var stage_ghost: Control = null
var stage_drag_start := Vector2.ZERO
var stage_drag_moved := false
## Utensilio (sartén, arroz moldeado...) que aparece a la derecha de la tabla
## en los pasos drag_stage.
var prop_rect: TextureRect = null
var prop_tween: Tween = null
## Posición final del prop (el sprite entra animado; la mano de gestos debe
## apuntar aquí, no a la posición intermedia de la animación).
var prop_target := Vector2.ZERO

var cooldowns: Dictionary = {}
## Elaboraciones instantáneas restantes por receta dominada (id → usos).
var free_uses: Dictionary = {}
var buttons: Dictionary = {}
var button_badges: Dictionary = {}
var button_cooldown_labels: Dictionary = {}
var ingredient_nodes: Dictionary = {}
var ghost: Control = null

## Platos terminados sobre la tabla (1, o 2 con "Doble plato").
var dishes: Array = []
var ready_recipe: String = ""
var dragging_dish: Control = null
var drag_offset := Vector2.ZERO

## Cajas de guardado: índice de caja → { "id", "count", "node", "count_label" }.
var stacks: Dictionary = {}
var storage_slots := 2
var storage_panels: Array = []
## Máximo de platos iguales por caja ("Más almacén" lo sube a 5).
var stack_max := 3
var stack_drag_index := -1
var stack_ghost: Control = null
## Punto donde empezó el arrastre desde la caja y si hubo movimiento real
## (un simple toque NO debe mandar el plato a la cinta).
var stack_drag_start := Vector2.ZERO
var stack_drag_moved := false

# --- Efectos de potenciadores ---
var instant_recipes: int = 0
var skip_next_cooldown: bool = false
var easy_next: bool = false
## "Doble plato": la siguiente receta produce 2 platos.
var double_next: bool = false
var cooldown_mult: float = 1.0
var cooldown_mult_timer: float = 0.0
## Potenciador PERMANENTE "Cocina veloz" (PerkData): multiplica el cooldown
## durante toda la partida. Va aparte de cooldown_mult, que es temporal y
## vuelve a 1.0 al expirar.
var cooldown_perm_mult: float = 1.0

var stage_tween: Tween = null
var instruction_tween: Tween = null
## Segundos sin tocar nada tras los que aparece la guía (mano + texto): la
## primera vez de cada receta se espera más, en los pasos siguientes menos.
const GUIDE_DELAY_FIRST := 2.0
const GUIDE_DELAY_NEXT := 1.5
const GUIDE_FADE := 0.35
## El cartel del gesto va inclinado y pegado al borde derecho de la tabla. Con
## 80° quedaba casi vertical y costaba leerlo de un vistazo; 30° se lee de
## corrido y sigue pareciendo un letrero clavado en la tabla.
const INSTRUCTION_ANGLE := 30.0
## Margen entre el cartel YA GIRADO y el borde derecho de la tabla. Se mide
## sobre la huella del texto inclinado, que con poco ángulo es mucho más ancha.
const INSTRUCTION_MARGIN := 16.0
var idle_time := 0.0
var guide_shown := true
var guide_delay := GUIDE_DELAY_FIRST
## Mano de gestos: muestra semitransparente cómo ejecutar cada interacción
## (pulsar, mantener, arrastrar, deslizar, círculo) con dos poses.
var hand: TextureRect = null
var hand_up_tex: Texture2D = null
var hand_down_tex: Texture2D = null
## Fantasma semitransparente del objeto que se arrastra en el ejemplo.
var ghost_hint: TextureRect = null
## Flecha que acompaña a la mano en los gestos de deslizamiento.
var arrow_hint: TextureRect = null
## Anillo que late sobre el punto donde hay que pulsar/mantener.
var touch_ring: Panel = null
var ring_tween: Tween = null
var indicator_tween: Tween = null

## Nodo que agrupa mano, flecha, fantasma, anillo y texto para fundirlos a la vez.
var hint_root: Control = null
var hint_tween: Tween = null

@onready var board_panel: Panel = $BoardPanel
@onready var ingredients_row: HBoxContainer = $BoardPanel/Ingredients
@onready var stage_rect: TextureRect = $BoardPanel/StageRect
@onready var tap_zone: Control = $BoardPanel/TapZone
@onready var tap_bar: ProgressBar = $BoardPanel/TapBar
@onready var instruction_label: Label = $Instruction
@onready var cancel_button: Button = $CancelButton
@onready var buttons_box: HBoxContainer = $Buttons
@onready var serve_slot: Control = $ServeSlot
@onready var belt_sprite: TextureRect = $ServeSlot/BeltSprite
@onready var storage_box: GridContainer = $StorageBox

## Desplazamiento de la cinta del panel (misma velocidad que la de la cubierta).
var panel_belt_scroll := 0.0

## Fondo 9-patch pirata para un Control.
static func make_nine_patch(tex_path: String, margin: int) -> NinePatchRect:
	var np := NinePatchRect.new()
	np.name = "Skin"
	np.texture = load(tex_path)
	np.patch_margin_left = margin
	np.patch_margin_top = margin
	np.patch_margin_right = margin
	np.patch_margin_bottom = margin
	np.set_anchors_preset(Control.PRESET_FULL_RECT)
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	np.show_behind_parent = true
	return np


## Textura y margen 9-slice del botón de madera con marco dorado que usa TODO
## el juego (menú, tienda, resultados, "Zarpar"...).
const BUTTON_TEX := "res://assets/ui/boton_madera.png"
const BUTTON_MARGIN := 44

## PERGAMINO: el fondo de todos los carteles, paneles y cajas del juego.
##
## El margen NO es libre: Godot dibuja la esquina del 9-slice a `patch_margin`
## PÍXELES DE TEXTURA, sin escalar el arte. Si el margen se queda por debajo
## del grosor del marco de madera (50 px en esta textura), la madera sobrante
## cae en la banda que se estira y se derrama hacia dentro del panel. De ahí
## que haya UNA constante y no el número suelto que había en cada pantalla
## (iban de 34 a 60, y con el marco nuevo los de 34 se veían derramados).
const PANEL_TEX := "res://assets/ui/panel.png"
const PANEL_MARGIN := 54

## Pergamino LISO, sin marco de madera, para las tarjetas PEQUEÑAS (botones de
## receta, artículos de la tienda): con el marco de 54 px un botón de 172×144
## se quedaba sin interior donde enseñar el plato.
const CARD_TEX := "res://assets/ui/panel_liso.png"
const CARD_MARGIN := 22

## CINTA de tela para el rótulo de cada pantalla (Opciones, Tienda, Logros...).
const RIBBON_TEX := "res://assets/ui/cinta_titulo.png"
const RIBBON_MARGIN := 76

## Cinta de título CABALGANDO sobre el borde superior de un panel, como los
## carteles de "Victoria" o "Salir" de un juego de tablero: la tela sobresale
## por los dos lados del pergamino y lo remata.
##
## `box` tiene que ser el Control del panel (el que lleva el pergamino). La
## cinta se añade como hija suya, así que se mueve y se oculta con él.
## `vuelo` es cuánto sobresale la tela por cada lado del pergamino. En un panel
## casi tan ancho como la pantalla hay que dejarlo en 0, o las colas del lazo se
## salen del móvil y se ven cortadas a cuchillo.
static func add_panel_banner(box: Control, text: String, font_size := 34,
		vuelo := 26.0) -> Control:
	var banner := make_title(text, font_size)
	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	# Sobresale por los lados y se sube media cinta por encima del canto.
	banner.offset_left = -vuelo
	banner.offset_right = vuelo
	banner.offset_top = -40.0
	banner.offset_bottom = 36.0
	box.add_child(banner)
	return banner


## RÓTULO GRANDE dentro de un panel, sin cinta ni tablón: letras doradas con
## contorno grueso y sombra, del tamaño de un titular. Es lo que remata los
## carteles cortos ("¿Salir?", "Jornada acabada"), donde una cinta con una
## frase larga pesaba más que el propio mensaje.
static func make_big_title(text: String, font_size := 64) -> Label:
	var l := Label.new()
	l.name = "BigTitle"
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(1, 0.82, 0.28))
	l.add_theme_color_override("font_outline_color", Color(0.28, 0.11, 0.03))
	l.add_theme_constant_override("outline_size", 16)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 5)
	# INTERLINEADO MUY NEGATIVO: la Exo 2 reserva ~1.9x el cuerpo por línea, así
	# que un titular de dos líneas salía con medio cartel de hueco en medio (el
	# mismo problema que el cartel del gesto de la tabla).
	l.add_theme_constant_override("line_spacing", -int(font_size * 0.62))
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		l.add_theme_font_override("font", negrita)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## TABLILLA con el nombre de quien habla, en la caja de diálogo. Antes era el
## mismo tablón que un botón cualquiera y se leía como un botón de más.
const PLATE_TEX := "res://assets/ui/placa_nombre.png"
## Zona de los clavos de los extremos: no se estira nunca.
const PLATE_CAP := 44
## Alto EXACTO al que se dibuja (= alto de la textura, para no deformarla).
const PLATE_H := 56


## 9-slice que se estira SOLO A LO ANCHO: la textura se exporta ya al alto al
## que se dibuja, así que en vertical va 1:1 y no se deforma nada.
static func make_hstretch_patch(tex_path: String, cap: int) -> NinePatchRect:
	var np := NinePatchRect.new()
	np.name = "Skin"
	np.texture = load(tex_path)
	np.patch_margin_left = cap
	np.patch_margin_right = cap
	np.patch_margin_top = 0
	np.patch_margin_bottom = 0
	np.set_anchors_preset(Control.PRESET_FULL_RECT)
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	np.show_behind_parent = true
	return np


## CAJA DE RECURSO del marcador (dinero, arroz): icono a la izquierda montado
## sobre el canto y la cifra dentro. Se estira solo a lo ancho, así que va al
## alto exacto al que se dibuja.
const RESOURCE_TEX := "res://assets/ui/caja_recurso.png"
const RESOURCE_H := 60
const RESOURCE_CAP := 30


## Contador de recurso: caja + icono + cifra. Devuelve el Control; la etiqueta
## se llama "Valor" para poder reescribirla.
##
## Con `barra` (0..1) la caja lleva además una BARRA que se va gastando por
## detrás de la cifra: es lo que hace el arroz, que tiene tope (20) y se
## consume, a diferencia del dinero, que no tiene techo.
static func make_resource_box(icon_path: String, text: String,
		ancho := 168.0, barra := -1.0) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(ancho, RESOURCE_H)
	holder.add_child(make_hstretch_patch(RESOURCE_TEX, RESOURCE_CAP))
	if barra >= 0.0:
		# La barra es LA PROPIA CAJA rellenándose, no una barrita metida dentro:
		# ocupa todo el hueco interior de la madera, de canto a canto, y el
		# número queda encima. Una barra pequeña dentro de la caja se leía como
		# dos cosas distintas apiladas.
		var pb := ProgressBar.new()
		pb.name = "Barra"
		pb.show_percentage = false
		pb.max_value = 1.0
		pb.value = barra
		pb.set_anchors_preset(Control.PRESET_FULL_RECT)
		pb.offset_left = 10.0
		pb.offset_right = -10.0
		pb.offset_top = 9.0
		pb.offset_bottom = -9.0
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pb.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		pb.add_theme_stylebox_override("fill", make_bar_box(
			"res://assets/ui/barra_oro_relleno.png",
			Color(0.98, 0.97, 0.94), 16))
		holder.add_child(pb)
	# El icono CABALGA sobre el borde izquierdo, medio dentro y medio fuera:
	# así se lee como una chapa clavada en la caja y no como un dibujo metido
	# dentro, que es como se ven estos contadores en los juegos del género.
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = load(icon_path)
	ic.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	ic.offset_left = -14.0
	ic.offset_right = 56.0
	ic.offset_top = -8.0
	ic.offset_bottom = 8.0
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(ic)
	var l := Label.new()
	l.name = "Valor"
	l.text = text
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_left = 58.0
	l.offset_right = -14.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	l.add_theme_color_override("font_outline_color", Color(0.16, 0.08, 0.02))
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(l)
	return holder


## BARRA de progreso: canal de madera y relleno, del mismo set.
const BAR_BG_TEX := "res://assets/ui/barra_fondo.png"
const BAR_FILL_TEX := "res://assets/ui/barra_relleno.png"
## Ancho del tope redondeado de la cápsula, en TEXELES.
const BAR_CAP := 12


## Estilo de una barra de progreso con el canal de madera del set.
##
## El 9-slice es SOLO HORIZONTAL (márgenes vertical a cero) a propósito: en una
## cápsula los topes redondos miden media altura, así que un margen vertical
## igual al tope dejaría la banda central en 0 px de alto. Dejando que la
## textura se escale a lo alto, el canal encaja a cualquier altura de barra.
## `cap` es el tope redondo EN TÉXELES, que siempre vale la mitad del alto de
## la textura: cada barra del juego tiene su propia textura a su propia altura
## (la del tablero 24, la del oro 32, la de propinas 20) justo por esto.
static func make_bar_box(tex_path: String, tint := Color.WHITE,
		cap := BAR_CAP) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(tex_path)
	sb.texture_margin_left = cap
	sb.texture_margin_right = cap
	sb.texture_margin_top = 0
	sb.texture_margin_bottom = 0
	sb.modulate_color = tint
	return sb


## Rótulo de pantalla sobre su cinta de tela roja.
##
## La cinta se estira SOLO A LO ANCHO (márgenes verticales a cero) porque las
## dos colas del lazo cuelgan por debajo de la banda: con un 9-slice vertical
## se estiraban a lo alto y el lazo se leía como un trapo.
static func make_title(text: String, font_size := 34) -> Control:
	var holder := Control.new()
	holder.name = "Title"
	holder.custom_minimum_size = Vector2(0, 76)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ribbon := NinePatchRect.new()
	ribbon.texture = load(RIBBON_TEX)
	ribbon.patch_margin_left = RIBBON_MARGIN
	ribbon.patch_margin_right = RIBBON_MARGIN
	ribbon.set_anchors_preset(Control.PRESET_FULL_RECT)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(ribbon)
	var l := Label.new()
	# Con nombre a proposito: hay rotulos que se reescriben en marcha (el de
	# resultados lleva el tratamiento del jugador).
	l.name = "TitleText"
	l.text = text
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# La cola del lazo baja unos píxeles más que la banda: sin subir el texto,
	# el rótulo se ve descentrado hacia abajo dentro de la tela.
	l.offset_bottom = -10.0
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.82))
	l.add_theme_color_override("font_outline_color", Color(0.18, 0.04, 0.04))
	l.add_theme_constant_override("outline_size", 9)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(l)
	return holder


## Aspecto pirata para un botón: tabla de madera con marco dorado y remaches,
## sombra proyectada para despegarlo del fondo y hundido al pulsarlo.
## Botón de ACEPTAR o de CANCELAR. Mismo tablón de madera, pero teñido de verde
## o de rojo y con su marca delante, para que se distingan de un vistazo cuál
## confirma y cuál echa atrás.
## BOTONES CON EL ICONO YA DIBUJADO EN LA MADERA (atrás, aceptar, cancelar).
##
## El icono es parte de la textura, no un carácter: antes el botón de aceptar
## era el tablón de siempre teñido de verde con un "✔" delante, y se leía como
## un botón normal con un emoticono.
##
## ALTURA CLAVADA A PROPÓSITO. Los márgenes 9-slice son TÉXELES que Godot
## dibuja 1:1, así que la única forma de que la flecha (o el aspa) no salga
## aplastada es que la textura mida de alto justo lo que el botón. Por eso el
## margen vertical es CERO y las tres texturas se exportan ya a 64 px.
const ICON_BTN_H := 64
## Ancho reservado al icono en la textura (no se estira nunca).
const ICON_BTN_ZONE := 68
## Tope redondeado del otro extremo.
const ICON_BTN_CAP := 34
const BACK_TEX := "res://assets/ui/boton_atras.png"
const OK_TEX := "res://assets/ui/boton_si.png"
const NO_TEX := "res://assets/ui/boton_no.png"
## Placa de oro con ribete rojo del botón que ARRANCA la partida ("¡Zarpar!").
## Ese sí es un 9-slice normal: no lleva icono que deformar.
const START_TEX := "res://assets/ui/boton_zarpar.png"
const START_MARGIN := 54


static func _icon_patch(tex_path: String) -> NinePatchRect:
	var np := NinePatchRect.new()
	np.name = "Skin"
	np.texture = load(tex_path)
	np.patch_margin_left = ICON_BTN_ZONE
	np.patch_margin_right = ICON_BTN_CAP
	np.patch_margin_top = 0
	np.patch_margin_bottom = 0
	np.set_anchors_preset(Control.PRESET_FULL_RECT)
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	np.show_behind_parent = true
	return np


static func skin_icon_button(b: Button, tex_path: String,
		left_pad := ICON_BTN_ZONE + 8.0) -> void:
	# El rótulo arranca DESPUÉS del icono, o se le montaría encima.
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var pad := StyleBoxEmpty.new()
		pad.content_margin_left = left_pad
		pad.content_margin_right = 18
		b.add_theme_stylebox_override(st, pad)
	b.custom_minimum_size.y = ICON_BTN_H
	b.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 0.94))
	b.add_theme_color_override("font_outline_color", Color(0.13, 0.07, 0.02))
	b.add_theme_constant_override("outline_size", 8)
	if b.has_node("Skin"):
		return
	var shadow := _icon_patch(tex_path)
	shadow.name = "SkinShadow"
	shadow.modulate = Color(0, 0, 0, 0.35)
	shadow.offset_left = 3.0
	shadow.offset_top = 5.0
	shadow.offset_right = 3.0
	shadow.offset_bottom = 5.0
	b.add_child(shadow)
	b.add_child(_icon_patch(tex_path))
	add_press_feedback(b, 0.95)


## Botón de ACEPTAR o CANCELAR (comprar/cancelar, salir/seguir).
static func skin_action_button(b: Button, ok: bool) -> void:
	skin_icon_button(b, OK_TEX if ok else NO_TEX)


## Botón de VOLVER: el único con la flecha dibujada en la propia madera.
static func make_back_button(text := "Atrás") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, ICON_BTN_H)
	# El rótulo va PEGADO a la flecha y alineado a la izquierda: centrado en el
	# hueco que queda a la derecha del icono se iba al borde del botón y dejaba
	# la mitad izquierda vacía.
	skin_icon_button(b, BACK_TEX, ICON_BTN_ZONE - 12.0)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 26)
	return b


## BOTÓN PEQUEÑO de madera (el "Salir" del nivel). Necesita su propia textura,
## más baja: `skin_button` encoge el margen 9-slice en los botones bajos
## (`min(lado)*0.44`), y con 46 px de alto el margen caía a 20 téxeles sobre una
## textura cuyo tope redondo mide 44 — o sea, cortaba el tope por la mitad y el
## botón salía como un recuadro raro. Esta va al alto exacto y con margen
## vertical CERO, así que el tope se dibuja entero.
const SMALL_TEX := "res://assets/ui/boton_madera_bajo.png"
const SMALL_H := 46
const SMALL_CAP := 18


static func skin_small_button(b: Button) -> void:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var pad := StyleBoxEmpty.new()
		pad.content_margin_left = SMALL_CAP
		pad.content_margin_right = SMALL_CAP
		b.add_theme_stylebox_override(st, pad)
	b.custom_minimum_size.y = SMALL_H
	b.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	b.add_theme_color_override("font_outline_color", Color(0.13, 0.07, 0.02))
	b.add_theme_constant_override("outline_size", 7)
	if b.has_node("Skin"):
		return
	var shadow := make_hstretch_patch(SMALL_TEX, SMALL_CAP)
	shadow.name = "SkinShadow"
	shadow.modulate = Color(0, 0, 0, 0.35)
	shadow.offset_left = 2.0
	shadow.offset_top = 4.0
	shadow.offset_right = 2.0
	shadow.offset_bottom = 4.0
	b.add_child(shadow)
	b.add_child(make_hstretch_patch(SMALL_TEX, SMALL_CAP))
	add_press_feedback(b, 0.94)


## Botón GRANDE que arranca la partida ("¡Zarpar!"): placa de oro, aparte del
## resto para que se vea de un vistazo que es EL botón de la pantalla.
## Cuánto BAJA el rótulo dentro de la placa de oro. La cara dorada no está
## centrada en la textura (el ribete rojo asoma más por abajo), así que el texto
## centrado a lo geométrico se leía descolocado hacia arriba.
const START_TEXT_DROP := 9.0


static func skin_start_button(b: Button) -> void:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_top = START_TEXT_DROP
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color(0.32, 0.16, 0.05))
	b.add_theme_color_override("font_hover_color", Color(0.2, 0.09, 0.02))
	# APAGADO = el MISMO texto, con la placa entera atenuada (ver `set_dimmed`).
	# Aclarar la letra sobre el oro la dejaba ilegible.
	b.add_theme_color_override("font_disabled_color", Color(0.32, 0.16, 0.05))
	b.add_theme_color_override("font_outline_color", Color(1, 0.93, 0.68))
	b.add_theme_constant_override("outline_size", 7)
	if b.has_node("Skin"):
		return
	var shadow := make_nine_patch(START_TEX, START_MARGIN)
	shadow.name = "SkinShadow"
	shadow.modulate = Color(0, 0, 0, 0.38)
	shadow.offset_left = 4.0
	shadow.offset_top = 7.0
	shadow.offset_right = 4.0
	shadow.offset_bottom = 7.0
	b.add_child(shadow)
	b.add_child(make_nine_patch(START_TEX, START_MARGIN))
	add_press_feedback(b, 0.96)


## Apaga (o enciende) un botón bajando su OPACIDAD, sin tocar el color de la
## letra. Es lo que quiere la placa de oro: aclarar el texto lo hacía
## ilegible sobre el dorado.
static func set_dimmed(b: Button, dim: bool) -> void:
	b.modulate = Color(1, 1, 1, 0.45) if dim else Color.WHITE


static func skin_button(b: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, empty)
	b.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 0.94))
	b.add_theme_color_override("font_pressed_color", Color(0.92, 0.86, 0.74))
	b.add_theme_color_override("font_disabled_color", Color(0.7, 0.65, 0.58))
	b.add_theme_color_override("font_outline_color", Color(0.13, 0.07, 0.02))
	b.add_theme_constant_override("outline_size", 8)
	if b.has_node("Skin"):
		return
	var shadow := make_nine_patch(BUTTON_TEX, BUTTON_MARGIN)
	shadow.name = "SkinShadow"
	shadow.modulate = Color(0, 0, 0, 0.35)
	b.add_child(shadow)
	var skin := make_nine_patch(BUTTON_TEX, BUTTON_MARGIN)
	b.add_child(skin)
	# Se hunde al pulsarlo (el pivote sigue al centro) y, en botones pequeños,
	# el marco 9-slice se encoge: con el margen fijo los cuatro trozos de
	# esquina no cabían y el dorado salía aplastado.
	b.resized.connect(func() -> void:
		b.pivot_offset = b.size / 2.0
		var m := mini(BUTTON_MARGIN, int(minf(b.size.x, b.size.y) * 0.44))
		for np in [skin, shadow]:
			np.patch_margin_left = m
			np.patch_margin_top = m
			np.patch_margin_right = m
			np.patch_margin_bottom = m
		# La sombra se desplaza en PROPORCIÓN al botón: con un valor fijo, en
		# los botones bajos asomaba tanto por debajo que el rótulo parecía
		# descolocado hacia arriba.
		var off := clampf(b.size.y * 0.055, 2.0, 7.0)
		shadow.offset_left = off * 0.6
		shadow.offset_top = off
		shadow.offset_right = off * 0.6
		shadow.offset_bottom = off)
	b.button_down.connect(func() -> void: b.scale = Vector2(0.965, 0.94))
	b.button_up.connect(func() -> void: b.scale = Vector2.ONE)


## Hundido al pulsar para botones que NO usan skin_button (los de imagen,
## como las flechas de cantidad y de página).
static func add_press_feedback(b: BaseButton, amount := 0.88) -> void:
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)
	b.button_down.connect(func() -> void: b.scale = Vector2(amount, amount))
	b.button_up.connect(func() -> void: b.scale = Vector2.ONE)


## Hace que un `LineEdit` saque el TECLADO DEL MÓVIL al tocarlo.
##
## No sale solo: en el móvil el campo no llegaba a coger el foco al tocarlo (el
## mismo motivo por el que el ScrollContainer no se arrastra con el dedo, ver
## touch_scroll.gd), así que aquí se le da el foco a mano y se pide el teclado
## explícitamente. En escritorio las llamadas al teclado no hacen nada.
static func enable_mobile_keyboard(edit: LineEdit) -> void:
	# Toda la maña vive en `mobile_keyboard.gd`: escucha en `_input` (antes que
	# la interfaz) y mira si el toque cae dentro del campo, en vez de esperar a
	# que el evento llegue al `gui_input` del propio LineEdit — que es lo que
	# fallaba en el iPhone.
	MobileKeyboard.attach(edit)
	edit.text_submitted.connect(func(_t: String) -> void:
		edit.release_focus())


## MODO DIESTRO: espejo horizontal del panel inferior. Cada bloque de primer
## nivel (tabla, cajas y la columna de discos) se recoloca en su posición
## reflejada; lo que cuelga de ellos (ingredientes, extras, TapZone, etapa) va
## dentro y no hay que tocarlo. Los guiones enfocan por NODO, así que el foco
## del tutorial cae bien sin cambiar una línea.
func _mirror_layout() -> void:
	var w := size.x
	for n in [board_panel, storage_box, cancel_button, boat_button,
			combo_button, helper_button]:
		if n != null:
			n.position.x = w - n.position.x - n.size.x
	# El ARTE de la tabla también se voltea: su marco de madera solo está
	# dibujado en el lado derecho (el izquierdo nace sangrado fuera de
	# pantalla), así que en espejo el lado visible quedaba a corte vivo.
	var sb := board_panel.get_theme_stylebox("panel")
	if sb is StyleBoxTexture and sb.texture != null:
		var img: Image = sb.texture.get_image()
		if img != null:
			img.flip_x()
			var flipped: StyleBoxTexture = sb.duplicate()
			flipped.texture = ImageTexture.create_from_image(img)
			board_panel.add_theme_stylebox_override("panel", flipped)


## Margen de tolerancia al TOCAR ingredientes, platos y la etapa en curso. El
## dedo tapa lo que señala y en el móvil se fallaban toques justos; con este
## colchón alrededor del icono se acierta sin tener que apuntar.
const TOUCH_PAD := 22.0


## ¿El dedo ha caído sobre este nodo (con el colchón de TOUCH_PAD)?
func _touched(node: Control, pos: Vector2) -> bool:
	return node != null and node.visible \
		and node.get_global_rect().grow(TOUCH_PAD).has_point(pos)


## De varios ingredientes a la vez (los de un paso de ELECCIÓN), el que tenga
## el centro más cerca del dedo de entre los que caen dentro del margen.
func _nearest_ingredient(options: Array, pos: Vector2) -> String:
	var best := ""
	var best_d := INF
	for ing_id in options:
		var node: Control = ingredient_nodes.get(ing_id)
		if not _touched(node, pos):
			continue
		var d: float = node.get_global_rect().get_center().distance_to(pos)
		if d < best_d:
			best_d = d
			best = str(ing_id)
	return best


## FLECHA de madera (las del recetario y las de cantidad de la tienda): es el
## único sitio donde se define, para que todas las flechas del juego sean la
## misma. `dir` es "<" o ">".
static func make_arrow(dir: String, size := 76.0) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = load("res://assets/ui/boton_flecha_der.png" if dir == ">"
		else "res://assets/ui/boton_flecha_izq.png")
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(size, size)
	add_press_feedback(b)
	return b


## Fila de estrellas con las imágenes propias del juego (llenas y vacías).
## Con shadow=true cada estrella lleva una sombra leve desplazada, para
## diferenciarla del fondo.
static func make_star_row(count: int, total: int, star_size: float, shadow := false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in total:
		var tex: Texture2D = load("res://assets/ui/estrella_llena.png" if i < count
				else "res://assets/ui/estrella_vacia.png")
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(star_size, star_size)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if shadow:
			var sh := TextureRect.new()
			sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sh.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sh.texture = tex
			sh.set_anchors_preset(Control.PRESET_FULL_RECT)
			sh.offset_left = 2.0
			sh.offset_top = 3.0
			sh.offset_right = 2.0
			sh.offset_bottom = 3.0
			sh.modulate = Color(0, 0, 0, 0.38)
			sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(sh)
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = tex
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(ic)
		row.add_child(holder)
	return row


#
func _ready() -> void:
	tutorial_mode = GameState.is_tutorial()
	if GameState.selected_recipes.is_empty():
		# Fallback para poder probar level.tscn directamente sin pasar por la selección.
		var fallback: Array[String] = ["maki_aguacate", "nigiri_salmon", "maki_atun", "futomaki_salmon"]
		GameState.selected_recipes = fallback
	# Recetas ordenadas de menor a mayor: primero por estrellas, luego precio.
	var sorted_ids := GameState.selected_recipes.duplicate()
	sorted_ids.sort_custom(func(a: String, b: String) -> bool:
		var da := RecipeData.get_recipe(a)
		var db := RecipeData.get_recipe(b)
		if da.level != db.level:
			return da.level < db.level
		return da.price < db.price)
	for id in sorted_ids:
		_build_recipe_button(id)
	for i in storage_slots:
		_add_storage_panel()
	_skin_cancel_button()
	cancel_button.pressed.connect(_cancel_prep)
	_build_boat_button()
	_build_combo_button()
	if GameState.has_perk("ayudante"):
		_build_helper_button()
	_build_extra_buttons()
	_update_extra_buttons()
	# Con la mano DERECHA dominante el panel entero se voltea en espejo: la
	# tabla pegada a la derecha (cerca del pulgar) y cajas/botones a la
	# izquierda (donde el pulgar no los tapa). Va DESPUÉS de construirlo todo,
	# así cada pieza se voltea ya colocada.
	if GameState.right_handed():
		_mirror_layout()
	# Al desaparecer un ingrediente ya usado, la fila se reordena y los que
	# quedan se desplazan; hay que recolocar la mano de gestos sobre el nuevo
	# objetivo o quedaría desajustada (recetas con 3+ ingredientes).
	ingredients_row.sort_children.connect(_on_ingredients_sorted)
	# Utensilio de los pasos drag_stage (se crea antes que la mano para que
	# los indicadores queden por encima).
	prop_rect = TextureRect.new()
	prop_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prop_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prop_rect.size = Vector2(168, 134)
	prop_rect.visible = false
	prop_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prop_rect)
	# Mensaje momentáneo sobre la tabla (p. ej. "¡Más lento!" al cortar rápido).
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 40)
	message_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 8)
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_label.visible = false
	# Por encima de TODO lo que haya sobre la tabla: los platos terminados y el
	# barco combinado se añaden después, así que sin esto el aviso ("¡Buen
	# punto!", "¡Barco! $34") quedaba tapado justo cuando hay que leerlo.
	message_label.z_index = 90
	add_child(message_label)
	# Todos los indicadores de ayuda cuelgan de un mismo nodo para poder
	# aparecer y desaparecer JUNTOS con un solo fundido.
	# La zona activa de la mesa solo se consulta por RECTÁNGULO desde `_input`
	# (`tap_zone.get_global_rect()`), nunca por el sistema de interfaz. Si se
	# queda en STOP se traga los toques de los botones de extras, que van
	# DEBAJO de ella en el árbol.
	tap_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_root = Control.new()
	hint_root.name = "Hints"
	hint_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hint_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Por encima de la fila de cabezas de cliente del HUD, que se añade después
	# que la tabla y tapaba la mano justo cuando indica llevar el plato a la
	# cinta. Los carteles modales van en 120, así que siguen por delante.
	hint_root.z_index = 110
	add_child(hint_root)
	# La instrucción del paso ("¡Pulsa!") se enciende sola tras unos segundos
	# de inactividad, junto con la mano.
	instruction_label.visible = false
	instruction_label.reparent(hint_root)
	instruction_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# Anillo del punto de toque (debajo de la mano en orden de dibujo).
	touch_ring = Panel.new()
	var ring_sb := StyleBoxFlat.new()
	ring_sb.bg_color = Color(1.0, 0.86, 0.3, 0.14)
	ring_sb.border_color = Color(1.0, 0.88, 0.35, 0.95)
	ring_sb.set_border_width_all(7)
	ring_sb.set_corner_radius_all(int(RING_SIZE.x / 2.0))
	touch_ring.add_theme_stylebox_override("panel", ring_sb)
	touch_ring.size = RING_SIZE
	touch_ring.pivot_offset = RING_SIZE / 2.0
	touch_ring.visible = false
	touch_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_root.add_child(touch_ring)
	# Mano de gestos: grande y bien visible, es la guía principal del jugador.
	hand_up_tex = load("res://assets/ui/mano_arriba.png")
	hand_down_tex = load("res://assets/ui/mano_abajo.png")
	hand = TextureRect.new()
	# expand_mode ANTES que texture: si no, el tamaño mínimo salta al de la
	# textura (421x546) y la mano sale gigante.
	hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hand.texture = hand_up_tex
	hand.size = HAND_SIZE
	hand.modulate = Color(1, 1, 1, HAND_ALPHA)
	hand.visible = false
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_root.add_child(hand)
	# Flecha de dirección para los gestos de deslizamiento.
	arrow_hint = TextureRect.new()
	arrow_hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow_hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow_hint.texture = load("res://assets/ui/flecha.png")
	arrow_hint.size = ARROW_SIZE
	arrow_hint.pivot_offset = ARROW_SIZE / 2.0
	arrow_hint.modulate = Color(1, 1, 1, 0.9)
	arrow_hint.visible = false
	arrow_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_root.add_child(arrow_hint)
	# Fantasma semitransparente de ejemplo para los gestos de arrastre.
	ghost_hint = TextureRect.new()
	ghost_hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost_hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost_hint.modulate = Color(1, 1, 1, 0.7)
	ghost_hint.visible = false
	ghost_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_root.add_child(ghost_hint)
	# Barra de progreso: canal de madera con el relleno verde dentro.
	tap_bar.add_theme_stylebox_override("background", make_bar_box(BAR_BG_TEX))
	tap_bar.add_theme_stylebox_override("fill",
		make_bar_box(BAR_FILL_TEX, Color(0.36, 0.88, 0.38)))
	# La cinta del panel se mueve continuamente, igual que la de la cubierta.
	var belt_mat := ShaderMaterial.new()
	belt_mat.shader = load("res://shaders/belt_scroll.gdshader")
	belt_sprite.material = belt_mat
	_update_ui()



func _process(delta: float) -> void:
	_tick_guide(delta)
	# Cinta del panel siempre en marcha (sincronizada con la de la cubierta).
	if belt_sprite.material != null:
		var tex := belt_sprite.texture
		var tile_px: float = tex.get_width() * (belt_sprite.size.y / tex.get_height())
		panel_belt_scroll += 75.0 * delta / maxf(tile_px, 1.0)
		belt_sprite.material.set_shader_parameter("scroll_offset", panel_belt_scroll)

	if frying:
		fry_time += delta
		_update_tap_bar()
	if boat_cooldown > 0.0:
		boat_cooldown = maxf(boat_cooldown - delta, 0.0)
		# El contador de segundos se refresca solo (repintar el botón entero
		# cada frame obligaría a recorrer las cajas 60 veces por segundo).
		var boat_timer: Label = boat_button.get_node_or_null("Timer") \
				if boat_button != null else null
		if boat_timer != null:
			boat_timer.text = "%d" % ceili(boat_cooldown)
		if boat_cooldown <= 0.0:
			_update_boat_button()
	if helper_cooldown > 0.0:
		helper_cooldown = maxf(helper_cooldown - delta, 0.0)
		_update_helper_button()
	if cooldown_mult_timer > 0.0:
		cooldown_mult_timer -= delta
		if cooldown_mult_timer <= 0.0:
			cooldown_mult = 1.0
	for id in cooldowns:
		if cooldowns[id] > 0.0:
			cooldowns[id] = maxf(cooldowns[id] - delta, 0.0)
	for id in buttons:
		var b: Button = buttons[id]
		var badge: Label = button_badges[id]
		var cd: Label = button_cooldown_labels[id]
		if cooldowns[id] > 0.0:
			b.disabled = true
			b.modulate = Color(0.55, 0.55, 0.55)
			cd.visible = true
			cd.text = "%d" % ceili(cooldowns[id])
		else:
			cd.visible = false
			b.disabled = state != State.IDLE and state != State.READY
			b.modulate = Color.WHITE if not b.disabled else Color(0.75, 0.75, 0.75)
		# En el tutorial solo se puede tocar la receta que el guion permite;
		# las demás quedan apagadas hasta que David las presente.
		if not allowed_recipes.is_empty() and not id in allowed_recipes:
			b.disabled = true
			b.modulate = Color(0.4, 0.4, 0.4)
		badge.text = "x%d" % free_uses[id] if free_uses.get(id, 0) > 0 else ""

	if state == State.CRAFTING and holding:
		var step := _current_step()
		if step.get("type", "") == "hold_board":
			# Con "move" (soplete del aburi) no basta con dejar el dedo quieto:
			# hay que ir paseándolo. hold_moving lo pone a true cada arrastre y
			# se consume aquí, así que parar el dedo detiene el progreso.
			if step.get("move", false):
				if not hold_moving:
					return
				hold_moving = false
			hold_time += delta
			var duration: float = step.get("duration", 1.0)
			if hold_time >= duration:
				holding = false
				_advance_step()
			else:
				_update_ui()


## Botón de receta: sprite grande del plato + estrellas de nivel.
## El cooldown aparece en grande ENCIMA del plato.
func _build_recipe_button(id: String) -> void:
	var data := RecipeData.get_recipe(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(172, 144)
	# Fondo de pergamino desgastado (en lugar de madera) para que el plato y
	# las estrellas destaquen.
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.add_child(make_nine_patch(CARD_TEX, CARD_MARGIN))

	# El plato ocupa casi todo el botón (grande y uniforme), dejando abajo una
	# franja para las estrellas.
	var tex := RecipeData.get_dish_texture(id)
	if tex != null:
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = tex
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 8.0
		ic.offset_top = 8.0
		ic.offset_right = -8.0
		ic.offset_bottom = -34.0
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)

	# Estrellas en la franja inferior, algo subidas y con sombra leve para
	# que se distingan bien del pergamino.
	var stars := make_star_row(int(data.get("level", 1)), int(data.get("level", 1)), 26, true)
	stars.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	stars.offset_top = -40.0
	stars.offset_bottom = -14.0
	b.add_child(stars)

	# Insignia de maestría/reciclaje: "x2", "x3"...
	var badge := Label.new()
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -84.0
	badge.offset_top = 0.0
	badge.offset_right = -6.0
	badge.offset_bottom = 44.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Grande a propósito: en el móvil, con 20 px, el "x2" de los makis no se
	# leía sobre el pergamino.
	badge.add_theme_font_size_override("font_size", 34)
	badge.add_theme_color_override("font_color", Color(0.6, 1.0, 0.55))
	badge.add_theme_color_override("font_outline_color", Color.BLACK)
	badge.add_theme_constant_override("outline_size", 9)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(badge)

	# Cooldown grande y visible encima de la receta.
	var cd := Label.new()
	cd.set_anchors_preset(Control.PRESET_FULL_RECT)
	cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd.add_theme_font_size_override("font_size", 44)
	cd.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
	cd.add_theme_color_override("font_outline_color", Color.BLACK)
	cd.add_theme_constant_override("outline_size", 8)
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd.visible = false
	b.add_child(cd)

	b.pressed.connect(_start_prep.bind(id))
	buttons_box.add_child(b)
	buttons[id] = b
	button_badges[id] = badge
	button_cooldown_labels[id] = cd
	cooldowns[id] = 0.0



func _add_storage_panel() -> void:
	var p := Control.new()
	p.custom_minimum_size = Vector2(90, 90)
	var slot_tex := "res://assets/ui/slot.png"
	if ResourceLoader.exists(slot_tex):
		var t := TextureRect.new()
		t.texture = load(slot_tex)
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(t)
	storage_box.add_child(p)
	storage_panels.append(p)


## Potenciador "Guardar un plato más": una caja extra.
func add_storage_slot() -> void:
	storage_slots += 1
	_add_storage_panel()


## Potenciador "Reciclaje de platos": vuelve como uso instantáneo (xN).
## Repasa los botones de barco, combinar y extras. Hay que llamarlo cuando
## `hide_extras` se pone DESPUÉS del _ready de la tabla (lo hace level3d al leer
## el puerto): si no, los botones se quedan como se construyeron, visibles.
func refresh_extra_ui() -> void:
	_update_boat_button()
	_update_combo_button()
	_update_extra_buttons()


## Añade una receta a la tabla EN PLENA PARTIDA: la usa el guion del nivel 3,
## donde David regala el nigiri de atún al aparecer el primer pirata.
func add_recipe(id: String) -> void:
	if buttons.has(id) or not RecipeData.RECIPES.has(id):
		return
	_build_recipe_button(id)
	if not allowed_recipes.is_empty() and not id in allowed_recipes:
		allowed_recipes.append(id)
	_update_ui()


func recycle_recipe(recipe_id: String) -> void:
	if recipe_id in cooldowns:
		free_uses[recipe_id] = free_uses.get(recipe_id, 0) + 1



func _current_step() -> Dictionary:
	if step_index >= 0 and step_index < steps.size():
		return steps[step_index]
	return {}



func _current_stage_id() -> String:
	var stages: Array = RecipeData.get_recipe(current_recipe).get("stages", [])
	var idx := step_index - 1
	if idx >= 0 and idx < stages.size():
		return stages[idx]
	return ""



func _start_prep(id: String) -> void:
	if state != State.IDLE or cooldowns[id] > 0.0:
		return
	# Restos de la elaboración anterior que no deben contaminar esta.
	fry_dish = ""
	choice_dish = ""
	choice_selected = ""
	ready_eat_mult = 0.0
	extras_chosen.clear()
	current_recipe = id
	if instant_recipes > 0:
		instant_recipes -= 1
		_finish_prep(false)
		return
	if free_uses.get(id, 0) > 0:
		free_uses[id] -= 1
		_finish_prep(false)
		return
	state = State.CRAFTING
	steps = RecipeData.get_recipe(id).steps
	if easy_next:
		easy_next = false
		steps = _simplify_steps(steps)
	step_index = 0
	_reset_guide(GUIDE_DELAY_FIRST)
	_reset_step_progress()
	_set_stage("")
	_build_ingredients(id)
	_update_prop()
	craft_event.emit("select", "")
	_update_ui()


## ¿Hay un gesto EN CURSO que no se puede interrumpir? El dedo está apoyado en
## mitad de un mantener / remover / cortar lento / freír, o arrastrando un
## plato. El nivel consulta esto antes de sacar el cartel de potenciador: si
## salta a media faena, el gesto se corta y la receta se arruina.
func is_gesture_locked() -> bool:
	return holding or stirring or slice_active or frying or dragging_dish != null


## Cancelable en cualquier momento mientras se está elaborando.
func _can_cancel() -> bool:
	return state == State.CRAFTING



func _cancel_prep() -> void:
	if not _can_cancel():
		return
	# Cancelar el montaje del barco DEVUELVE los platos a sus cajas.
	if current_recipe == BOAT_RECIPE:
		_return_boat_parts()
	state = State.IDLE
	current_recipe = ""
	steps = []
	_reset_step_progress()
	# Limpia cualquier arrastre de ejemplo en curso.
	if ghost != null:
		ghost.queue_free()
		ghost = null
	if stage_ghost != null:
		stage_ghost.queue_free()
		stage_ghost = null
	_set_stage("")
	_clear_ingredients()
	_update_prop()
	craft_event.emit("cancel", "")
	_update_ui()


# --- Barco combinado ---
## Platos "de carta" que admite la bandeja (ni picoteos ni sopas).
const BOAT_DISHES := ["maki_aguacate", "nigiri_salmon", "gunkan_wakame",
	"nigiri_atun", "maki_atun", "gunkan_ikura", "futomaki_salmon",
	"nigiri_ebi", "hana_maki"]
## Mínimo para armar un barco y tope que cabe en la bandeja. La prima por
## número de clases DISTINTAS es lo que dispara el precio.
const BOAT_MIN := 4
const BOAT_MAX := 12
const BOAT_VARIETY_BONUS := { 2: 10, 3: 24, 4: 52, 5: 88, 6: 132 }
const BOAT_RECIPE := "moriawase"
## Un barco por minuto: es la jugada gorda de la partida, no algo continuo.
const BOAT_COOLDOWN := 60.0
## Cuánto ocupa al cliente un barco, según CUÁNTOS platos lleve dentro: son
## varios platos de una sentada, así que cuantos más, más rato masticando.
## eat_mult = BASE + POR_PLATO x platos, o sea 2.0 con los 4 mínimos, 2.2 con
## 6 (el barco típico) y 2.8 con los 12 del tope. No es proporcional de verdad
## —cuatro platos sueltos de nivel 3 serían casi un minuto— sino MUY comprimido:
## triplicar el contenido solo añade un 40% de tiempo, porque con la pendiente
## anterior (0.15) un barco lleno aparcaba a un grumete casi un minuto entero,
## más de un tercio de la partida.
const BOAT_EAT_BASE := 1.6
const BOAT_EAT_PER_DISH := 0.10
## Doblones que cuesta echar a perder una fritura (cruda o carbonizada).
const FRY_WASTE_PENALTY := 5
## Icono bajo las cajas; solo aparece cuando el barco se puede montar.
var boat_button: Button = null
var boat_cooldown: float = 0.0
## Botón de COMBINAR (udon + tempura): al lado del barco.
var combo_button: Button = null
## TUTORIAL: con `tutorial_mode` los botones del barco, combinar y extras no
## existen para el jugador, y `allowed_recipes` (si no está vacío) apaga todas
## las recetas menos las que el guion de David permite en cada fase.
var tutorial_mode := false
## Lo mismo, pero para NIVELES de campaña que todavía no han presentado esas
## mecánicas (`no_extras` en CampaignData): los primeros puertos se juegan solo
## con la tabla y la cinta.
var hide_extras := false
## El BARCO combinado y el botón de COMBINAR tienen su propia compuerta: el
## barco se presenta en el nivel 4 y los combinados aún más tarde, así que no
## pueden ir atados a la misma bandera que los extras.
## Por defecto NO ocultan nada: en Arcade y en las pruebas está todo. Es cada
## puerto de campaña el que las levanta (level3d las fija al leer el nivel).
var hide_boat := false
var hide_combo := false
## Mientras un guion ESTÁ ENSEÑANDO un gesto, equivocarse no cuesta dinero (el
## corte del salmón que explica David en el nivel 5). El aviso y el destello
## rojo siguen saliendo: lo único que se perdona es el bolsillo.
var free_mistakes := false
## Sin tipar a Array[String] a propósito: el director asigna literales de
## Array y el tipado estricto rechazaba la asignación.
var allowed_recipes: Array = []

## AYUDANTE (potenciador permanente): botón con su cara que termina de golpe la
## receta recién empezada. Solo existe si el jugador lo lleva a la partida; se
## enciende en el PRIMER paso de una elaboración y luego enfría medio minuto.
const HELPER_COOLDOWN := 30.0
## Trozo del retrato de cuerpo entero que se ve en el disco del ayudante, en
## fracciones de la imagen: la cabeza y algo de hombros.
const HELPER_FACE := Rect2(0.28, 0.03, 0.44, 0.30)
var helper_button: Button = null
var helper_cooldown: float = 0.0
## Montaje en curso: platos que faltan por colocar y sus nodos en la tabla.
var boat_parts: Array = []
var boat_pending: Array = []
var boat_nodes: Array = []
## Plato del montaje que se está arrastrando (-1 = ninguno).
var boat_drag_index: int = -1
## Overlay del barco cargado sobre la bandeja (se rellena plato a plato).
var boat_fill: TextureRect = null
## Nivel del plato listo cuando NO es el de su receta (barco combinado).
var ready_level: int = 0
## Precio del plato listo cuando NO vale el de su receta (barco combinado).
var ready_price: int = 0
## Latido de la llama del soplete mientras se está flameando.
var flame_tween: Tween = null
## Latido de la llama del soplete mientras se esta flameando.


## --- Extras del plato (jengibre / wasabi / soja) ---
## Botones que salen arriba a la izquierda de la tabla con el plato ya hecho.
var extra_buttons: Dictionary = {}
var extras_chosen: Dictionary = {}


# --- Barco combinado -------------------------------------------------------
# No es una receta que se elija: aparece como icono bajo las cajas cuando hay
# guardados BOAT_MIN platos válidos de AL MENOS dos clases distintas. Al
# pulsarlo, TODOS los platos guardados salen a la tabla y hay que ir
# arrastrándolos al barco uno a uno.

## Recuento por id de los platos guardados que valen para el barco.
func _boat_stock() -> Dictionary:
	var stock := {}
	for i in stacks:
		var id: String = stacks[i].id
		if id in BOAT_DISHES:
			stock[id] = stock.get(id, 0) + int(stacks[i].count)
	return stock


## Todos los platos válidos guardados (hasta BOAT_MAX), de más caro a más
## barato. [] si no llegan al mínimo o son todos de la misma clase.
func _boat_pick() -> Array:
	var stock := _boat_stock()
	if stock.size() < 2:
		return []   # nunca un barco de un solo plato repetido
	var kinds: Array = stock.keys()
	kinds.sort_custom(func(a: String, b: String) -> bool:
		return int(RecipeData.get_recipe(a).get("price", 0)) 			> int(RecipeData.get_recipe(b).get("price", 0)))
	var picked: Array = []
	# Ronda a ronda para que entren de todas las clases antes de repetir.
	var left := true
	while left and picked.size() < BOAT_MAX:
		left = false
		for k in kinds:
			if picked.size() >= BOAT_MAX:
				break
			if stock[k] > 0:
				stock[k] -= 1
				picked.append(k)
				left = true
	return picked if picked.size() >= BOAT_MIN else []


## Precio del barco: lo que valen sus platos más una prima por variedad.
func _boat_price(picked: Array) -> int:
	var total := 0
	var kinds := {}
	for id in picked:
		total += int(RecipeData.get_recipe(id).get("price", 0))
		kinds[id] = true
	return total + int(BOAT_VARIETY_BONUS.get(kinds.size(), 0))


## Nivel (estrellas) del barco: la MEDIA de los niveles de sus platos,
## redondeada hacia abajo. Así un barco de 1★+3★ sale de 2★ (lo cata todo el
## mundo) y uno de puros 3★ sigue siendo cosa de capitanes.
func _boat_level(picked: Array) -> int:
	if picked.is_empty():
		return 1
	var total := 0
	for id in picked:
		total += int(RecipeData.get_recipe(id).get("level", 1))
	return clampi(int(floor(float(total) / picked.size())), 1, 3)


## Pulsar el icono: saca los platos de las cajas a la tabla y empieza el
## montaje. Todavía no hay barco: hay que arrastrarlos a la bandeja.
func _make_boat() -> void:
	if state != State.IDLE or boat_cooldown > 0.0:
		return
	var picked := _boat_pick()
	if picked.is_empty():
		_flash_message("¡Faltan platos!")
		return
	for id in picked:
		_consume_stored(id)
	boat_parts = picked.duplicate()
	boat_pending = picked.duplicate()
	state = State.CRAFTING
	current_recipe = BOAT_RECIPE
	steps = []
	step_index = 0
	_set_stage("")
	# Los platos rescatados se reparten por la tabla, listos para arrastrar.
	_layout_boat_parts()
	_update_prop_boat()
	# La mano va DESPUÉS de colocar la bandeja: antes apuntaba a donde estaba
	# el utensilio en la receta anterior.
	_boat_hint()
	craft_event.emit("select", "")
	_update_ui()


## Coloca en la tabla los platos que aún faltan por montar.
func _layout_boat_parts() -> void:
	for n in boat_nodes:
		if is_instance_valid(n):
			n.queue_free()
	boat_nodes.clear()
	var area := tap_zone.get_global_rect()
	var cols := 4
	for i in boat_pending.size():
		var d := _make_dish_node(boat_pending[i])
		d.scale = Vector2(0.62, 0.62)
		add_child(d)
		var col := i % cols
		var row := i / cols
		d.global_position = area.position + Vector2(18.0 + col * 84.0, 10.0 + row * 62.0)
		boat_nodes.append(d)


## Mano guía del BARCO: mientras queden platos sueltos en la tabla, señala uno
## y enseña el arrastre hasta la bandeja. Sin esto, al pulsar el botón salían
## los platos y no había forma de saber qué hacer con ellos.
## Va SEÑALANDO UNO A UNO todos los platos que quedan por cargar, con el
## fantasma de cada plato: con un solo destino fijo (el primero de la lista) la
## mano repetía siempre el mismo viaje y el dibujo que arrastraba no se
## correspondía con el plato que tocaba coger.
func _boat_hint() -> void:
	_hide_indicator()
	var desde: Array[Vector2] = []
	var texs: Array[Texture2D] = []
	for i in boat_nodes.size():
		var d: Control = boat_nodes[i]
		if not is_instance_valid(d):
			continue
		desde.append(_local_center(d))
		texs.append(RecipeData.get_dish_texture(str(boat_pending[i])))
	if desde.is_empty():
		return
	_hand_drag_cycle(desde, texs, DISH_SIZE * 0.62, _local_center(prop_rect))


## La bandeja vacía a la que hay que llevar los platos. Encima lleva un
## overlay del barco YA CARGADO que va apareciendo plato a plato.
func _update_prop_boat() -> void:
	prop_rect.texture = RecipeData.get_stage_texture("barco_vacio")
	prop_rect.scale = Vector2.ONE
	prop_target = board_panel.position + board_panel.size - prop_rect.size - Vector2(8, 10)
	prop_rect.position = prop_target
	prop_rect.modulate.a = 1.0
	prop_rect.visible = true
	if boat_fill == null:
		boat_fill = TextureRect.new()
		boat_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		boat_fill.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		boat_fill.texture = RecipeData.get_dish_texture(BOAT_RECIPE)
		boat_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		boat_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prop_rect.add_child(boat_fill)
	boat_fill.modulate.a = 0.0
	boat_fill.visible = true


## Cancelar el montaje: los platos VUELVEN a las cajas tal cual estaban.
func _return_boat_parts() -> void:
	_hide_indicator()
	if boat_fill != null:
		boat_fill.visible = false
	for n in boat_nodes:
		if is_instance_valid(n):
			n.queue_free()
	boat_nodes.clear()
	for id in boat_pending:
		var slot := _slot_for(id)
		if slot >= 0:
			if stacks.has(slot):
				stacks[slot].count += 1
				stacks[slot].count_label.text = "x%d" % stacks[slot].count
			else:
				_create_stack(slot, id)
	boat_pending.clear()
	boat_parts.clear()
	_emit_storage()


## Caja donde cabe un plato de ese tipo (la suya con hueco, o una vacía).
func _slot_for(id: String) -> int:
	for i in storage_panels.size():
		if stacks.has(i) and stacks[i].id == id and stacks[i].count < stack_max:
			return i
	for i in storage_panels.size():
		if not stacks.has(i):
			return i
	return -1


## ELECCIÓN de ingrediente (aburi): salen varios pescados y hay que llevar UNO
## a la tabla; el elegido fija la etapa siguiente y la identidad del plato
## (result_by), y el resto desaparece al avanzar (la poda hace su parte).
##
## Vale de las DOS maneras: arrastrando el pescado a la tabla de una, o
## tocándolo primero (queda marcado y los demás se apagan) y arrastrándolo
## después. Un toque suelto NUNCA lo lleva a la tabla: solo lo marca.
func _handle_choice_drag(event: InputEvent, step: Dictionary) -> void:
	var options: Array = step.get("options", [])
	if event is InputEventScreenTouch:
		if event.pressed:
			# Con margen de toque las opciones vecinas se solapan, así que se
			# queda con la MÁS CERCANA al dedo, no con la primera de la lista.
			var picked := _nearest_ingredient(options, event.position)
			if picked != "" and ghost == null:
				ghost = _make_ghost(picked)
				ghost.set_meta("ing", picked)
				add_child(ghost)
				ghost.global_position = event.position - ghost.size / 2.0
				choice_press_at = event.position
				choice_moved = false
		elif ghost != null:
			var dropped := tap_zone.get_global_rect().intersects(
					Rect2(ghost.global_position, ghost.size))
			var chosen := str(ghost.get_meta("ing"))
			ghost.queue_free()
			ghost = null
			# El orden importa: la zona activa cubre la fila de ingredientes, así
			# que sin mirar primero si hubo arrastre, un toque para MARCAR
			# contaría como haberlo soltado ya en la tabla.
			if dropped and choice_moved:
				choice_dish = str(step.get("result_by", {}).get(chosen, ""))
				var stage_over := str(step.get("stage_by", {}).get(chosen, ""))
				craft_event.emit("drag", _current_stage_id())
				_advance_step()
				if stage_over != "":
					_set_stage(stage_over)
			elif not choice_moved:
				# Toque limpio: se queda marcado y la guía pasa a señalarlo solo.
				choice_selected = "" if choice_selected == chosen else chosen
				craft_event.emit("select", _current_stage_id())
				_update_choice_highlight(options)
				_update_ui()
	elif event is InputEventScreenDrag and ghost != null:
		if choice_press_at.distance_to(event.position) > 24.0:
			choice_moved = true
		ghost.global_position = event.position - ghost.size / 2.0


## Marca la opción elegida y apaga las demás. Sin esto, tocar un pescado no
## daba ninguna señal de que hubiera pasado algo.
func _update_choice_highlight(options: Array) -> void:
	for ing_id in options:
		var node: Control = ingredient_nodes.get(ing_id)
		if node == null:
			continue
		if choice_selected == "" or choice_selected == ing_id:
			node.modulate = Color.WHITE
		else:
			node.modulate = Color(0.62, 0.62, 0.62, 0.55)


## FREÍR: mantener pulsado sobre la sartén y soltar en el punto justo. El
## contador corre a la vista (con milésimas) y al soltar se mira en qué franja
## de RecipeData.FRY_WINDOWS cayó: de ahí salen el precio, el sprite y el aviso.
func _handle_fry(event: InputEvent, step: Dictionary) -> void:
	# Con "prop" el paso lleva utensilio a mano (el soplete del wagyu): se
	# enciende al pulsar y sigue al dedo, igual que en hold_board.
	var has_prop: bool = step.get("prop", "") != ""
	if event is InputEventScreenDrag and frying and has_prop:
		_move_prop_to(event.position)
		return
	if not (event is InputEventScreenTouch):
		return
	if event.pressed and tap_zone.get_global_rect().has_point(event.position):
		frying = true
		fry_time = 0.0
		if has_prop:
			_set_prop_lit(true)
			_move_prop_to(event.position)
		craft_event.emit("hold", _current_stage_id())
	elif not event.pressed and frying:
		frying = false
		if has_prop:
			_release_prop()
		var windows := _fry_windows(step)
		var best := 0
		for w in windows:
			best = maxi(best, int(w["price"]))
		for w in windows:
			if fry_time <= float(w["to"]):
				_finish_fry(w, best)
				return


## Franjas de tiempo del paso: por defecto las de la tempura, pero cada receta
## puede traer las suyas ("windows"), más o menos exigentes.
func _fry_windows(step: Dictionary) -> Array:
	var w: Array = step.get("windows", [])
	return w if not w.is_empty() else RecipeData.FRY_WINDOWS


## Resuelve la fritura: si la franja no paga nada, el plato va a la basura
## (se desliza fuera de la pantalla por abajo) y encima cuesta 5 doblones.
func _finish_fry(window: Dictionary, best_price: int = 0) -> void:
	var price := int(window["price"])
	var color: Color = window.get("color", Color(1.0, 0.86, 0.3))
	_flash_message("%s%s" % [window["label"],
		("" if price <= 0 else "  $%d" % price)], color)
	if price <= 0:
		# Ni crudo ni carbonizado se sirven: se pierde la elaboración, el
		# plato malogrado se escurre por abajo y el descuido cuesta dinero.
		_slide_out_dish(str(window["dish"]))
		money_penalty.emit(FRY_WASTE_PENALTY)
		var lost := current_recipe
		_cancel_prep()
		_apply_cooldown(lost)
		return
	fry_dish = str(window["dish"])
	ready_price = price
	# Logro: la franja del punto exacto es la que más paga de ESE paso (cada
	# receta tiene sus propias franjas: la tempura, el yaki y el wagyu).
	var top: int = best_price if best_price > 0 else RecipeData.FRY_BEST_PRICE
	if price >= top:
		GameState.bump_stat("fry_perfect")
	_advance_step()


## El plato arruinado aparece un instante y cae fuera de la pantalla.
func _slide_out_dish(recipe_id: String) -> void:
	var d := _make_dish_node(recipe_id)
	add_child(d)
	d.position = _dish_rest_position(0)
	d.pivot_offset = DISH_SIZE / 2.0
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.35)
	tw.tween_property(d, "position:y", size.y + DISH_SIZE.y, 0.55)
	tw.parallel().tween_property(d, "rotation_degrees", 24.0, 0.55)
	tw.tween_callback(d.queue_free)


## Empieza a arrastrar uno de los platos del montaje del barco.
func _try_start_boat_drag(event: InputEventScreenTouch) -> bool:
	if state != State.CRAFTING or current_recipe != BOAT_RECIPE:
		return false
	for i in range(boat_nodes.size() - 1, -1, -1):
		var d: Control = boat_nodes[i]
		if is_instance_valid(d) and d.get_global_rect().has_point(event.position):
			boat_drag_index = i
			dragging_dish = d
			drag_offset = event.position - d.global_position
			return true
	return false


## Un plato del montaje llega a la bandeja: la bandeja da un pequeño BOTE y
## el contenido del barco se va viendo más lleno con cada plato.
func _boat_part_placed(node: Control, index: int) -> void:
	node.queue_free()
	boat_nodes.remove_at(index)
	boat_pending.remove_at(index)
	craft_event.emit("drag", "")
	# La mano pasa al siguiente plato (y se apaga sola con el último).
	_boat_hint.call_deferred()
	var placed := boat_parts.size() - boat_pending.size()
	if boat_fill != null:
		boat_fill.modulate.a = float(placed) / maxf(boat_parts.size(), 1.0)
	prop_rect.pivot_offset = prop_rect.size / 2.0
	if prop_tween != null:
		prop_tween.kill()
	prop_rect.scale = Vector2(1.14, 0.88)
	prop_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	prop_tween.tween_property(prop_rect, "scale", Vector2.ONE, 0.4)
	if boat_pending.is_empty():
		_finish_boat()
	else:
		_update_ui()


## Con todos los platos dentro, el barco sale listo para servir.
func _finish_boat() -> void:
	if boat_fill != null:
		boat_fill.visible = false
	ready_recipe = BOAT_RECIPE
	ready_price = _boat_price(boat_parts)
	ready_level = _boat_level(boat_parts)
	ready_eat_mult = BOAT_EAT_BASE + BOAT_EAT_PER_DISH * boat_parts.size()
	state = State.READY
	current_recipe = ""
	prop_rect.visible = false
	boat_cooldown = BOAT_COOLDOWN
	var d := _make_dish_node(BOAT_RECIPE)
	add_child(d)
	d.position = _dish_rest_position(0)
	d.pivot_offset = DISH_SIZE / 2.0
	d.scale = Vector2(0.5, 0.5)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) 		.tween_property(d, "scale", Vector2.ONE, 0.3)
	dishes.append(d)
	_flash_message("¡Barco!  $%d" % ready_price)
	craft_event.emit("done", "")
	_update_ui()


## Saca UN plato de ese tipo de las cajas.
func _consume_stored(id: String) -> void:
	for i in stacks:
		if stacks[i].id != id:
			continue
		stacks[i].count -= 1
		if stacks[i].count <= 0:
			stacks[i].node.queue_free()
			stacks.erase(i)
		else:
			stacks[i].count_label.text = "x%d" % stacks[i].count
		_emit_storage()
		return


## El icono del barco solo se ofrece cuando de verdad se puede montar.
## El barco está SIEMPRE a la vista (si no, nadie descubre que existe), pero
## apagado mientras no se pueda montar. Durante el enfriamiento enseña los
## segundos que faltan encima del icono.
func _update_boat_button() -> void:
	if boat_button == null:
		return
	if tutorial_mode or hide_boat:
		boat_button.visible = false
		return
	var cooling := boat_cooldown > 0.0
	var can_build: bool = state == State.IDLE and not cooling \
			and not _boat_pick().is_empty()
	boat_button.visible = true
	boat_button.disabled = not can_build
	boat_button.modulate = Color.WHITE if can_build else Color(0.72, 0.72, 0.72, 0.42)
	var timer: Label = boat_button.get_node_or_null("Timer")
	if timer != null:
		timer.visible = cooling
		if cooling:
			timer.text = "%d" % ceili(boat_cooldown)


## Botón de COMBINAR (udon + tempura): mismas reglas que el barco, pero la
## pareja es exacta. También está siempre puesto y apagado cuando no toca.
func _update_combo_button() -> void:
	if combo_button == null:
		return
	if tutorial_mode or hide_combo:
		combo_button.visible = false
		return
	var combo := _combo_ready()
	var can_build: bool = state == State.IDLE and combo != ""
	combo_button.visible = true
	combo_button.disabled = not can_build
	combo_button.modulate = Color.WHITE if can_build else Color(0.72, 0.72, 0.72, 0.42)
	if combo != "":
		combo_button.tooltip_text = RecipeData.get_recipe(combo).get("name", combo)


## Primer combo de RecipeData.COMBOS cuyas dos partes estén guardadas, o "".
func _combo_ready() -> String:
	for id in RecipeData.COMBOS:
		var parts: Array = RecipeData.COMBOS[id].get("parts", [])
		var ok := true
		for part in parts:
			if _stored_count(part) <= 0:
				ok = false
				break
		if ok and not parts.is_empty():
			return id
	return ""


## Cuántas unidades de esa receta hay en las cajas.
func _stored_count(id: String) -> int:
	var n := 0
	for i in stacks:
		if stacks[i].id == id:
			n += int(stacks[i].count)
	return n


## Monta el combo: gasta una unidad de cada parte y deja el plato resultante
## sobre la tabla, con el precio sumado más el bonus.
func _make_combo() -> void:
	var id := _combo_ready()
	if id == "" or state != State.IDLE:
		return
	var combo: Dictionary = RecipeData.COMBOS[id]
	var parts: Array = combo.get("parts", [])
	var total := int(combo.get("bonus", 0))
	for part in parts:
		total += int(RecipeData.get_recipe(part).get("price", 0))
		_consume_stored(part)
	ready_recipe = id
	ready_base = id
	ready_price = total
	ready_level = int(RecipeData.get_recipe(id).get("level", 1))
	state = State.READY
	current_recipe = ""
	extras_chosen.clear()
	var d := _make_dish_node(id)
	add_child(d)
	d.position = _dish_rest_position(0)
	d.pivot_offset = DISH_SIZE / 2.0
	d.scale = Vector2(0.5, 0.5)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(d, "scale", Vector2.ONE, 0.3)
	dishes.append(d)
	_flash_message("¡%s!  $%d" % [RecipeData.get_recipe(id).get("label", id), total])
	craft_event.emit("done", "")
	_update_ui()


## "Manos rápidas": deja solo los pasos de ingredientes.
func _simplify_steps(source: Array) -> Array:
	var result: Array = []
	for step in source:
		var t: String = step.get("type", "")
		if t == "tap_ingredient" or t == "drag_ingredient":
			result.append(step)
	if result.is_empty():
		result.append(source[0])
	return result


func _reset_step_progress() -> void:
	taps_done = 0
	swipes_done = 0
	hold_time = 0.0
	holding = false
	hold_moving = false
	swipe_active = false
	swipe_counted = false
	swipe_progress = 0.0
	stir_turns = 0
	stir_angle = 0.0
	stirring = false
	slices_done = 0
	slice_active = false
	slice_progress = 0.0
	frying = false
	fry_time = 0.0


func _clear_ingredients() -> void:
	for child in ingredients_row.get_children():
		child.queue_free()
	ingredient_nodes.clear()


func _ingredient_texture(ing_id: String) -> Texture2D:
	var path := "res://assets/ingredients/%s.png" % ing_id
	return load(path) if ResourceLoader.exists(path) else null


func _build_ingredients(recipe_id: String) -> void:
	_clear_ingredients()
	for ing_id in RecipeData.get_recipe_ingredients(recipe_id):
		var holder := Control.new()
		holder.custom_minimum_size = ING_SIZE
		# Los ingredientes se detectan por rectángulo desde `_input`, no por el
		# sistema de interfaz: dejando pasar el toque, los botones de extras que
		# van DEBAJO de la fila siguen siendo pulsables.
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex := _ingredient_texture(ing_id)
		if tex != null:
			var t := TextureRect.new()
			t.texture = tex
			t.set_anchors_preset(Control.PRESET_FULL_RECT)
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(t)
		ingredients_row.add_child(holder)
		ingredient_nodes[ing_id] = holder


## Elimina de la tabla los ingredientes que ya no se van a usar.
func _prune_ingredients() -> void:
	var needed := {}
	for i in range(step_index, steps.size()):
		for ing in steps[i].get("options", [steps[i].get("ingredient", "")]):
			if ing != "":
				needed[ing] = true
	for ing_id in ingredient_nodes.keys():
		if not needed.has(ing_id):
			var node: Control = ingredient_nodes[ing_id]
			ingredient_nodes.erase(ing_id)
			var tw := create_tween()
			tw.tween_property(node, "modulate:a", 0.0, 0.25)
			tw.tween_callback(node.queue_free)


## La fila de ingredientes se ha reordenado (uno desapareció y los demás se
## desplazan): si el paso actual apunta a un ingrediente, recolocamos la mano
## sobre su nueva posición. Diferido para leer los rects ya reposicionados.
func _on_ingredients_sorted() -> void:
	if state != State.CRAFTING:
		return
	var t: String = _current_step().get("type", "")
	if t == "tap_ingredient" or t == "drag_ingredient":
		call_deferred("_refresh_indicator")


## Cambia el sprite de la etapa en la tabla con una animación de aparición.
func _set_stage(stage_id: String) -> void:
	var tex := RecipeData.get_stage_texture(stage_id)
	stage_rect.texture = tex
	stage_rect.visible = tex != null
	if tex != null:
		stage_rect.pivot_offset = stage_rect.size / 2.0
		if stage_tween != null:
			stage_tween.kill()
		stage_rect.scale = Vector2(0.6, 0.6)
		stage_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		stage_tween.tween_property(stage_rect, "scale", Vector2.ONE, 0.25)


## Pequeña sacudida del sprite de etapa (feedback de cada gesto).
func _bump_stage(rotate_deg: float = 0.0) -> void:
	if not stage_rect.visible:
		return
	stage_rect.pivot_offset = stage_rect.size / 2.0
	if stage_tween != null:
		stage_tween.kill()
	stage_rect.scale = Vector2(1.12, 0.88)
	stage_rect.rotation_degrees = rotate_deg
	stage_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	stage_tween.tween_property(stage_rect, "scale", Vector2.ONE, 0.3)
	stage_tween.parallel().tween_property(stage_rect, "rotation_degrees", 0.0, 0.3)


func _advance_step() -> void:
	_reset_step_progress()
	step_index += 1
	_prune_ingredients()
	# Paso nuevo: la guía se retira y vuelve a contar (menos que la 1ª vez).
	_reset_guide(GUIDE_DELAY_NEXT)
	if step_index >= steps.size():
		# El plato recién hecho es el mismo voxel que el emplatado.
		_finish_prep(true)
		return
	var stages: Array = RecipeData.get_recipe(current_recipe).get("stages", [])
	var stage_id: String = stages[step_index - 1] if step_index - 1 < stages.size() else ""
	_set_stage(stage_id)
	_update_prop()
	_swap_stage_from()
	craft_event.emit("stage", stage_id)
	_update_ui()


## "from" de un paso drag_stage: lo que se arrastra NO es el resultado del paso
## anterior. Se enseña ese resultado un instante (el cuenco de arroz recién
## montado, que es a donde hay que llevar el salmón) y después la etapa cambia
## sola al sprite indicado, que es lo que el dedo va a coger.
func _swap_stage_from() -> void:
	var desde: String = str(_current_step().get("from", ""))
	if desde == "":
		return
	var paso := step_index
	var t := create_tween()
	t.tween_interval(FROM_SWAP_DELAY)
	t.tween_callback(func() -> void:
		# Si mientras tanto se ha cancelado o se ha avanzado, no tocar nada.
		if state == State.CRAFTING and step_index == paso:
			_set_stage(desde)
			# Y la mano guía se repinta: se montó con la etapa ANTERIOR (el
			# repintado va diferido, en el mismo fotograma que el cambio de
			# paso), así que arrastraba el cuenco de destino en vez del salmón.
			_refresh_indicator())


## Botón de cancelar: una CRUZ roja redonda en vez del botón de madera con la
## palabra "Cancelar", que con el mismo aspecto que los botones de receta
## parecía una receta más y encima se comía media esquina de la tabla.
## Botones de EXTRAS (jengibre / wasabi / soja): salen arriba a la izquierda de
## la tabla cuando el plato ya está hecho, con una "+" en su esquina. Al
## pulsarlos se marcan con un check y ese extra viaja con el plato.
func _build_extra_buttons() -> void:
	var i := 0
	for id in RecipeData.EXTRAS:
		var b := Button.new()
		b.name = "Extra_" + id
		# Esquina superior izquierda de la MESA, pero colgando del propio
		# BoardPanel y colocados DELANTE de la fila de ingredientes en el árbol
		# (`move_child` más abajo): así se dibujan sobre la madera pero POR
		# DEBAJO de los ingredientes, la etapa y el plato, que nunca quedan
		# tapados. La fila de ingredientes va en MOUSE_FILTER_IGNORE para que
		# los toques sigan llegando a estos botones.
		b.size = Vector2(64, 64)
		b.position = Vector2(10.0 + i * 72.0, 10.0)
		b.pivot_offset = b.size / 2.0
		b.tooltip_text = RecipeData.get_ingredient(id).get("name", id)
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var disc := Panel.new()
		disc.set_anchors_preset(Control.PRESET_FULL_RECT)
		disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		disc.show_behind_parent = true
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.20, 0.14, 0.08, 0.92)
		sb.border_color = Color(0.95, 0.82, 0.40)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(14)
		disc.add_theme_stylebox_override("panel", sb)
		b.add_child(disc)
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = RecipeData.get_ingredient_texture(id)
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 4.0
		ic.offset_top = 4.0
		ic.offset_right = -4.0
		ic.offset_bottom = -4.0
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		# "+" en la esquina inferior derecha, montado sobre el propio botón.
		var plus := Label.new()
		plus.name = "Plus"
		plus.text = "+"
		plus.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		plus.offset_left = -20.0
		plus.offset_top = -24.0
		plus.offset_right = 4.0
		plus.offset_bottom = 4.0
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.add_theme_font_size_override("font_size", 26)
		plus.add_theme_color_override("font_color", Color(1, 0.95, 0.55))
		plus.add_theme_color_override("font_outline_color", Color.BLACK)
		plus.add_theme_constant_override("outline_size", 6)
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(plus)
		# Check verde que aparece al elegirlo (tapa la "+").
		var check := TextureRect.new()
		check.name = "Check"
		check.visible = false
		check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		check.texture = load("res://assets/ui/check.png")
		check.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		check.offset_left = -26.0
		check.offset_top = -26.0
		check.offset_right = 4.0
		check.offset_bottom = 4.0
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(check)
		b.pressed.connect(_toggle_extra.bind(id))
		board_panel.add_child(b)
		# Delante de la fila de ingredientes en el árbol = detrás en el dibujo.
		board_panel.move_child(b, i)
		extra_buttons[id] = b
		i += 1
	# Los iconos de ingrediente se manejan desde `_input` comparando rectángulos,
	# no por el sistema de interfaz, así que la fila puede dejar pasar los
	# toques: sin esto tapaba los botones de extras que ahora van debajo.
	ingredients_row.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Marca o desmarca un extra para el plato que está sobre la tabla.
func _toggle_extra(id: String) -> void:
	if state != State.READY:
		return
	if extras_chosen.get(id, false):
		extras_chosen.erase(id)
	else:
		# Solo se puede echar si queda en la despensa.
		if GameState.get_ingredient_uses(id) <= 0:
			_flash_message("¡Sin %s!" % RecipeData.get_ingredient(id).get("short", id))
			return
		extras_chosen[id] = true
	_bump_extra(extra_buttons.get(id, null))
	_update_extra_buttons()


## Golpecito al pulsar: se encoge y rebota. Sin esto el único aviso de que el
## toque ha entrado era el check, que en un botón de 64 px se pierde.
func _bump_extra(b: Button) -> void:
	if b == null or not is_instance_valid(b):
		return
	# `get_meta` con valor por defecto sigue avisando por consola si la clave no
	# existe: hay que preguntar antes con `has_meta`.
	var t: Tween = null
	if b.has_meta("bump"):
		t = b.get_meta("bump") as Tween
	if t != null and t.is_valid():
		t.kill()
	b.scale = Vector2.ONE
	t = create_tween()
	t.tween_property(b, "scale", Vector2(0.82, 0.82), 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "scale", Vector2(1.14, 1.14), 0.11) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "scale", Vector2.ONE, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	b.set_meta("bump", t)


## Los extras están SIEMPRE a la vista (así se sabe que existen desde el primer
## momento), pero apagados y sin responder mientras no haya un plato terminado
## sobre la tabla o no quede existencia en la despensa.
func _update_extra_buttons() -> void:
	# "no_extras": a los postres (mochi, dorayaki, taiyaki) no se les echa nada.
	# En el tutorial los extras no existen todavía: interfaz mínima.
	if tutorial_mode or hide_extras:
		for id in extra_buttons:
			extra_buttons[id].visible = false
		return
	var usable: bool = state == State.READY 			and not RecipeData.get_recipe(ready_recipe).get("no_extras", false)
	for id in extra_buttons:
		var b: Button = extra_buttons[id]
		var stock: int = GameState.get_ingredient_uses(id)
		var picked: bool = extras_chosen.get(id, false)
		var on: bool = usable and (stock > 0 or picked)
		b.visible = true
		b.disabled = not on
		b.get_node("Check").visible = picked
		b.get_node("Plus").visible = not picked
		b.modulate = Color.WHITE if on else Color(0.75, 0.75, 0.75, 0.38)


## Icono del barco combinado: va justo al lado del botón de cancelar, debajo
## de las cajas, y solo se ve cuando hay platos de sobra para montarlo.
func _build_boat_button() -> void:
	boat_button = Button.new()
	boat_button.name = "BoatButton"
	boat_button.size = cancel_button.size
	boat_button.position = cancel_button.position - Vector2(cancel_button.size.x + BUTTON_GAP, 0.0)
	boat_button.tooltip_text = "Barco combinado"
	boat_button.visible = false
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		boat_button.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var disc := Panel.new()
	disc.set_anchors_preset(Control.PRESET_FULL_RECT)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.show_behind_parent = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.36, 0.24, 0.11)
	sb.border_color = Color(0.98, 0.82, 0.35)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(28)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 5
	disc.add_theme_stylebox_override("panel", sb)
	boat_button.add_child(disc)
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = RecipeData.get_stage_texture("barco_vacio")
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 6.0
	ic.offset_top = 6.0
	ic.offset_right = -6.0
	ic.offset_bottom = -6.0
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boat_button.add_child(ic)
	# Segundos que faltan de enfriamiento, encima del icono.
	var timer := Label.new()
	timer.name = "Timer"
	timer.visible = false
	timer.set_anchors_preset(Control.PRESET_FULL_RECT)
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer.add_theme_font_size_override("font_size", 28)
	timer.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	timer.add_theme_color_override("font_outline_color", Color.BLACK)
	timer.add_theme_constant_override("outline_size", 8)
	# El botón entero se atenúa mientras enfría; el contador compensa esa
	# atenuación para seguir leyéndose (el modulate del padre multiplica).
	timer.modulate = Color(1, 1, 1, 2.4)
	timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boat_button.add_child(timer)
	boat_button.pressed.connect(_make_boat)
	add_child(boat_button)


## Botón del AYUDANTE: disco con su cara, DEBAJO del botón de combinar (a la
## izquierda de la fila de discos, lejos del de cancelar: pegado a él se pulsaba
## uno por otro). Apagado salvo en el PRIMER paso de una elaboración; al pulsarlo
## el ayudante termina el plato él solo y se toma HELPER_COOLDOWN de descanso.
func _build_helper_button() -> void:
	helper_button = Button.new()
	helper_button.name = "HelperButton"
	helper_button.size = cancel_button.size
	helper_button.position = combo_button.position \
			+ Vector2(0.0, cancel_button.size.y + BUTTON_GAP)
	helper_button.tooltip_text = "Que lo haga el ayudante"
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		helper_button.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var disc := Panel.new()
	disc.set_anchors_preset(Control.PRESET_FULL_RECT)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.show_behind_parent = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.28, 0.44)
	sb.border_color = Color(0.98, 0.82, 0.35)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(28)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 5
	disc.add_theme_stylebox_override("panel", sb)
	helper_button.add_child(disc)
	# La cara del ayudante es la del género CONTRARIO al del jugador. Los
	# retratos son de CUERPO ENTERO (los del selector de Opciones), así que se
	# recorta la cabeza: metido entero en un disco de 56 px no se le veía.
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var face := "res://assets/ui/chef_%s.png" % GameState.helper_gender()
	if ResourceLoader.exists(face):
		var full: Texture2D = load(face)
		var atlas := AtlasTexture.new()
		atlas.atlas = full
		var w := float(full.get_width())
		var h := float(full.get_height())
		atlas.region = Rect2(w * HELPER_FACE.position.x, h * HELPER_FACE.position.y,
			w * HELPER_FACE.size.x, h * HELPER_FACE.size.y)
		ic.texture = atlas
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 4.0
	ic.offset_top = 4.0
	ic.offset_right = -4.0
	ic.offset_bottom = -4.0
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	helper_button.add_child(ic)
	# Segundos que faltan de descanso, encima de la cara (igual que el barco).
	var timer := Label.new()
	timer.name = "Timer"
	timer.visible = false
	timer.set_anchors_preset(Control.PRESET_FULL_RECT)
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer.add_theme_font_size_override("font_size", 28)
	timer.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	timer.add_theme_color_override("font_outline_color", Color.BLACK)
	timer.add_theme_constant_override("outline_size", 8)
	timer.modulate = Color(1, 1, 1, 2.4)
	timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	helper_button.add_child(timer)
	helper_button.pressed.connect(_helper_take_over)
	add_child(helper_button)
	_update_helper_button()


## ¿Puede el ayudante hacerse cargo? Solo con una receta recién empezada (el
## primer paso aún sin dar) y con su descanso terminado.
func _helper_ready() -> bool:
	return helper_button != null and helper_cooldown <= 0.0 \
			and state == State.CRAFTING and step_index == 0 \
			and current_recipe != BOAT_RECIPE


func _update_helper_button() -> void:
	if helper_button == null:
		return
	var can := _helper_ready()
	helper_button.disabled = not can
	helper_button.modulate = Color.WHITE if can else Color(0.72, 0.72, 0.72, 0.42)
	var timer: Label = helper_button.get_node_or_null("Timer")
	if timer != null:
		timer.visible = helper_cooldown > 0.0
		if helper_cooldown > 0.0:
			timer.text = "%d" % ceili(helper_cooldown)


## El ayudante termina la receta en curso: el plato sale hecho sin gastar más
## gestos. Cuenta como bien hecha, así que DA MAESTRÍA igual que si la hubiera
## cocinado el jugador (las recetas con `free_uses` sueltan sus platos extra).
func _helper_take_over() -> void:
	if not _helper_ready():
		return
	helper_cooldown = HELPER_COOLDOWN
	helper_used.emit()
	_finish_prep(true)
	# El plato aparece hecho de golpe: los ingredientes que había preparados
	# para elaborarlo ya no pintan nada en la tabla.
	_clear_ingredients()
	_update_helper_button()


## Icono de COMBINAR: al lado del barco, con el plato resultante dentro.
func _build_combo_button() -> void:
	combo_button = Button.new()
	combo_button.name = "ComboButton"
	combo_button.size = cancel_button.size
	combo_button.position = boat_button.position \
			- Vector2(cancel_button.size.x + BUTTON_GAP, 0.0)
	combo_button.tooltip_text = "Combinar platos"
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		combo_button.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var disc := Panel.new()
	disc.set_anchors_preset(Control.PRESET_FULL_RECT)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.show_behind_parent = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.34, 0.28)
	sb.border_color = Color(0.98, 0.82, 0.35)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(28)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 5
	disc.add_theme_stylebox_override("panel", sb)
	combo_button.add_child(disc)
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = RecipeData.get_dish_texture(RecipeData.COMBOS.keys()[0])
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 4.0
	ic.offset_top = 4.0
	ic.offset_right = -4.0
	ic.offset_bottom = -4.0
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_button.add_child(ic)
	combo_button.pressed.connect(_make_combo)
	add_child(combo_button)


func _skin_cancel_button() -> void:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		cancel_button.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	cancel_button.text = ""
	cancel_button.tooltip_text = "Cancelar la elaboración"
	var disc := Panel.new()
	disc.name = "Disc"
	disc.set_anchors_preset(Control.PRESET_FULL_RECT)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.show_behind_parent = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.62, 0.16, 0.12)
	sb.border_color = Color(0.96, 0.86, 0.70)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(28)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 5
	disc.add_theme_stylebox_override("panel", sb)
	cancel_button.add_child(disc)
	# La equis, dos barras cruzadas (una fuente con "X" quedaba descentrada).
	for ang in [45.0, -45.0]:
		var bar := ColorRect.new()
		bar.color = Color(1, 0.95, 0.90)
		bar.size = Vector2(30, 6)
		bar.pivot_offset = bar.size / 2.0
		bar.rotation_degrees = ang
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_CENTER)
		bar.position = Vector2(-15, -3)
		cancel_button.add_child(bar)


# --- Guía diferida (mano + texto) ---

## La guía (mano + texto) está SIEMPRE puesta: se probó a mostrarla solo tras
## unos segundos de inactividad y se descartó — es la referencia de qué toca
## hacer en cada paso y esconderla dejaba al jugador a ciegas.
func _tick_guide(_delta: float) -> void:
	pass


## Cualquier gesto del jugador. Ya no oculta nada, pero se conserva el punto
## de entrada por si vuelve a hacer falta.
func _touch_activity() -> void:
	idle_time = 0.0


## Al cambiar de paso o de receta se vuelve a dibujar la guía del paso nuevo.
func _reset_guide(_delay := 0.0) -> void:
	idle_time = 0.0
	guide_shown = true
	if hint_root != null:
		hint_root.modulate.a = 1.0


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch_activity()
	if stack_drag_index >= 0:
		_continue_stack_drag(event)
		return
	if dragging_dish != null:
		_continue_dish_drag(event)
		return
	if event is InputEventScreenTouch and event.pressed:
		# Montando el barco: los platos rescatados se arrastran a la bandeja.
		if _try_start_boat_drag(event):
			return
		if _try_start_dish_drag(event):
			return
		if _try_start_stack_drag(event):
			return
	if state == State.CRAFTING:
		_handle_craft_input(event)


# --- Arrastre de platos terminados (sobre la tabla) ---

func _try_start_dish_drag(event: InputEventScreenTouch) -> bool:
	if state != State.READY:
		return false
	for i in range(dishes.size() - 1, -1, -1):
		var d: Control = dishes[i]
		if _touched(d, event.position):
			dragging_dish = d
			drag_offset = event.position - d.global_position
			return true
	return false


func _continue_dish_drag(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		dragging_dish.global_position = event.position - drag_offset
	elif event is InputEventScreenTouch and not event.pressed:
		var d := dragging_dish
		dragging_dish = null
		var center := d.get_global_rect().get_center()
		# Plato del montaje del barco: solo cuenta si cae en la bandeja.
		if boat_drag_index >= 0:
			var idx := boat_drag_index
			boat_drag_index = -1
			if prop_rect.visible and prop_rect.get_global_rect().grow(24.0).has_point(center):
				_boat_part_placed(d, idx)
			else:
				_layout_boat_parts()
			return
		# Guardado con MUCHO margen (arriba, abajo y a los lados de las cajas):
		# se comprueba primero, así soltar cerca de las cajas siempre guarda
		# aunque también toque la franja de la cinta que pasa por encima.
		if storage_box.get_global_rect().grow(90.0).has_point(center):
			var slot := _auto_store_index()
			if slot >= 0:
				_store_dish(d, slot)
			else:
				d.position = _dish_rest_position(dishes.find(d))
		elif center.y <= serve_slot.get_global_rect().end.y:
			# La cinta está en el borde superior de la tabla: soltar sobre su
			# tramo O en cualquier zona por encima (la cubierta) cuenta como
			# servir. El guardado ya se comprobó antes, así que aquí solo llega
			# lo que se suelta lejos de las cajas.
			_serve_dish(d)
		else:
			d.position = _dish_rest_position(dishes.find(d))


func _serve_dish(d: Control) -> void:
	dishes.erase(d)
	d.queue_free()
	# Los extras se gastan de la despensa AQUÍ, uno por plato servido; si al
	# final no quedaba, ese extra simplemente no viaja con el plato.
	var extras: Array = []
	for id in extras_chosen:
		if GameState.consume_extra(id):
			extras.append(id)
	dish_served.emit(ready_recipe, ready_price, extras, ready_level, ready_eat_mult)
	# Cada plato elige sus propios extras: el siguiente empieza limpio.
	extras_chosen.clear()
	_update_extra_buttons()
	_after_dish_consumed()


func _after_dish_consumed() -> void:
	if dishes.is_empty():
		_apply_cooldown(ready_base if ready_base != "" else ready_recipe)
		ready_base = ""
		ready_recipe = ""
		state = State.IDLE
		_clear_ingredients()
		_set_stage("")
		craft_event.emit("serve", "")
		_update_ui()


# --- Cajas de guardado por pilas ---

## Caja elegida automáticamente al soltar en la zona de guardado: primero
## una pila del mismo plato con hueco (así nunca ocupan dos cajas), después
## la primera caja vacía. -1 si no hay sitio.
func _auto_store_index() -> int:
	for i in storage_panels.size():
		if stacks.has(i) and stacks[i].id == ready_recipe and stacks[i].count < stack_max:
			return i
	for i in storage_panels.size():
		if not stacks.has(i):
			return i
	return -1


func _store_dish(d: Control, panel_index: int) -> void:
	dishes.erase(d)
	d.queue_free()
	if stacks.has(panel_index):
		stacks[panel_index].count += 1
		stacks[panel_index].count_label.text = "x%d" % stacks[panel_index].count
	else:
		_create_stack(panel_index, ready_recipe)
	_emit_storage()
	_after_dish_consumed()


## Vuelca el estado de las cajas para quien lo quiera reflejar fuera.
func _emit_storage() -> void:
	var slots: Array = []
	for i in storage_panels.size():
		slots.append({ "id": stacks[i].id, "count": stacks[i].count } \
			if stacks.has(i) else null)
	storage_changed.emit(slots)
	# Al cambiar las cajas se enciende (o se apaga) lo que se monta con ellas.
	_update_boat_button()
	_update_combo_button()


func _create_stack(panel_index: int, recipe_id: String) -> void:
	var p: Control = storage_panels[panel_index]
	var node := Control.new()
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := TextureRect.new()
	t.texture = RecipeData.get_dish_texture(recipe_id)
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.offset_left = 6.0
	t.offset_top = 6.0
	t.offset_right = -6.0
	t.offset_bottom = -6.0
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(t)
	var cl := Label.new()
	cl.text = "x1"
	cl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	cl.offset_left = -44.0
	cl.offset_top = -30.0
	cl.offset_right = -4.0
	cl.offset_bottom = -2.0
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cl.add_theme_font_size_override("font_size", 20)
	cl.add_theme_color_override("font_color", Color(1, 0.94, 0.6))
	cl.add_theme_color_override("font_outline_color", Color.BLACK)
	cl.add_theme_constant_override("outline_size", 6)
	node.add_child(cl)
	p.add_child(node)
	stacks[panel_index] = { "id": recipe_id, "count": 1, "node": node, "count_label": cl }


## Arrastrar DESDE una caja: saca un solo plato de la pila.
func _try_start_stack_drag(event: InputEventScreenTouch) -> bool:
	for i in stacks.keys():
		var p: Control = storage_panels[i]
		if p.get_global_rect().has_point(event.position):
			stack_drag_index = i
			stack_drag_start = event.position
			stack_drag_moved = false
			stack_ghost = _make_dish_node(stacks[i].id)
			add_child(stack_ghost)
			stack_ghost.global_position = event.position - DISH_SIZE / 2.0
			return true
	return false


func _continue_stack_drag(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		stack_ghost.global_position = event.position - DISH_SIZE / 2.0
		if event.position.distance_to(stack_drag_start) > 24.0:
			stack_drag_moved = true
	elif event is InputEventScreenTouch and not event.pressed:
		var i := stack_drag_index
		stack_drag_index = -1
		# Solo se sirve si hubo arrastre real Y el dedo terminó sobre la cinta
		# o por encima de ella (la cubierta).
		var served: bool = stack_drag_moved \
				and event.position.y <= serve_slot.get_global_rect().end.y
		stack_ghost.queue_free()
		stack_ghost = null
		if served:
			dish_served.emit(stacks[i].id, 0, [], 0, 0.0)
			stacks[i].count -= 1
			if stacks[i].count <= 0:
				stacks[i].node.queue_free()
				stacks.erase(i)
			else:
				stacks[i].count_label.text = "x%d" % stacks[i].count
			_emit_storage()



# --- Interacción de elaboración ---

func _handle_craft_input(event: InputEvent) -> void:
	var step := _current_step()
	var step_type: String = step.get("type", "")
	match step_type:
		"tap_ingredient":
			if event is InputEventScreenTouch and event.pressed:
				var node: Control = ingredient_nodes.get(step.get("ingredient", ""))
				if _touched(node, event.position):
					craft_event.emit("tap", _current_stage_id())
					_advance_step()
		"tap_board":
			if event is InputEventScreenTouch and event.pressed \
					and tap_zone.get_global_rect().has_point(event.position):
				taps_done += 1
				var cutting: bool = step.get("cutting", false)
				craft_event.emit("cut" if cutting else "tap", _current_stage_id())
				_bump_stage(6.0 if cutting else 0.0)
				if taps_done >= int(step.get("count", 1)):
					_advance_step()
				else:
					_update_ui()
		"hold_board":
			var movable: bool = step.get("move", false)
			if event is InputEventScreenTouch:
				if event.pressed and tap_zone.get_global_rect().has_point(event.position):
					holding = true
					hold_moving = false
					hold_last_pos = event.position
					_set_prop_lit(true)
					_move_prop_to(event.position)
					craft_event.emit("hold", _current_stage_id())
				elif not event.pressed:
					holding = false
					hold_moving = false
					# Con utensilio, soltar NO reinicia: la barra se queda
					# donde estaba y el soplete vuelve apagado a su rincón.
					if movable:
						_release_prop()
					else:
						hold_time = 0.0
					_update_ui()
			elif event is InputEventScreenDrag and holding:
				# Sacar el soplete de la tabla lo devuelve a su sitio, apagado.
				if movable and not tap_zone.get_global_rect().has_point(event.position):
					holding = false
					hold_moving = false
					_release_prop()
					_update_ui()
					return
				# El utensilio (soplete) va donde está el dedo.
				_move_prop_to(event.position)
				# Con "move" el paso EXIGE mover mientras se mantiene: el
				# temporizador solo corre si el dedo se está desplazando.
				if event.position.distance_to(hold_last_pos) > 3.0:
					hold_moving = true
					hold_last_pos = event.position
		"swipe_board":
			_handle_swipe(event, step)
		"drag_ingredient":
			_handle_ingredient_drag(event, step)
		"stir_board":
			_handle_stir(event, step)
		"slice_board":
			_handle_slice(event, step)
		"drag_stage":
			_handle_stage_drag(event)
		"drag_choice":
			_handle_choice_drag(event, step)
		"fry_board":
			_handle_fry(event, step)


func _handle_swipe(event: InputEvent, step: Dictionary) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and board_panel.get_global_rect().has_point(event.position):
			swipe_active = true
			swipe_counted = false
			swipe_start = event.position
		elif not event.pressed:
			swipe_active = false
	elif event is InputEventScreenDrag and swipe_active and not swipe_counted:
		var dx: float = event.position.x - swipe_start.x
		var dy: float = event.position.y - swipe_start.y
		var direction: String = _swipe_direction(step)
		# "distance": recorrido exigido; por defecto el umbral normal.
		var need: float = float(step.get("distance", SWIPE_THRESHOLD))
		# Avance del gesto EN CURSO, para que la barra se llene sobre la marcha
		# (con count 1 solo saltaba de 0 a 1 al terminar y parecía rota).
		var advance := 0.0
		match direction:
			"down": advance = dy
			"up": advance = -dy
			"right": advance = dx
			"left": advance = -dx
			"diag": advance = minf(dx, dy) / 0.7
		swipe_progress = clampf(advance / maxf(need, 1.0), 0.0, 1.0)
		var done: bool = advance >= need
		if direction == "diag":
			# Enrollado en cono (temaki): hay que bajar Y a la derecha a la vez,
			# así que se exigen las DOS componentes, no solo la distancia.
			done = dx >= need * 0.7 and dy >= need * 0.7
		if done:
			swipe_counted = true
			swipes_done += 1
			swipe_progress = 0.0
			craft_event.emit("swipe", _current_stage_id())
			_bump_stage(10.0 if direction != "up" else -10.0)
			if swipes_done >= int(step.get("count", 1)):
				_advance_step()
			else:
				_update_ui()
		else:
			_update_tap_bar()


## Dirección del deslizamiento en curso. Con "alt" se ALTERNA en cada pasada
## (el rebozado en sésamo del California: de izquierda a derecha y de vuelta).
func _swipe_direction(step: Dictionary) -> String:
	var d: String = step.get("direction", "down")
	if d == "alt":
		return "left" if swipes_done % 2 == 1 else "right"
	return d


func _handle_ingredient_drag(event: InputEvent, step: Dictionary) -> void:
	var ing_id: String = step.get("ingredient", "")
	if event is InputEventScreenTouch:
		if event.pressed:
			var node: Control = ingredient_nodes.get(ing_id)
			if ghost == null and _touched(node, event.position):
				ghost = _make_ghost(ing_id)
				add_child(ghost)
				ghost.global_position = event.position - ghost.size / 2.0
				drag_press_at = event.position
				drag_moved = false
		elif ghost != null:
			# Con "prop" en el paso (p. ej. el cuenco del edamame) hay que
			# soltar SOBRE el utensilio; si no, vale toda la tabla.
			var target: Rect2 = prop_rect.get_global_rect().grow(20.0) \
					if step.get("prop", "") != "" and prop_rect.visible \
					else tap_zone.get_global_rect()
			var dropped_on_target := target.intersects(
					Rect2(ghost.global_position, ghost.size))
			ghost.queue_free()
			ghost = null
			# La zona activa cubre TODA la mesa, incluida la fila de
			# ingredientes: sin exigir arrastre de verdad, un simple toque
			# sobre el ingrediente ya contaría como soltarlo en la tabla.
			if dropped_on_target and drag_moved:
				craft_event.emit("drag", _current_stage_id())
				_advance_step()
	elif event is InputEventScreenDrag and ghost != null:
		if drag_press_at.distance_to(event.position) > 24.0:
			drag_moved = true
		ghost.global_position = event.position - ghost.size / 2.0


## stir_board: remover en círculos manteniendo pulsado sobre la tabla.
## Se acumula el ángulo recorrido alrededor del centro de la etapa; cada
## vuelta completa (en cualquier sentido) cuenta una.
func _handle_stir(event: InputEvent, step: Dictionary) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and tap_zone.get_global_rect().has_point(event.position):
			stirring = true
			stir_angle = 0.0
			stir_last_angle = _angle_around_stage(event.position)
		elif not event.pressed:
			stirring = false
	elif event is InputEventScreenDrag and stirring:
		var ang := _angle_around_stage(event.position)
		stir_angle += wrapf(ang - stir_last_angle, -PI, PI)
		stir_last_angle = ang
		if absf(stir_angle) >= TAU:
			stir_angle = 0.0
			stir_turns += 1
			craft_event.emit("stir", _current_stage_id())
			_bump_stage(8.0)
			if stir_turns >= int(step.get("count", 1)):
				_advance_step()
				return
		_update_tap_bar()


func _angle_around_stage(pos: Vector2) -> float:
	return (pos - stage_rect.get_global_rect().get_center()).angle()


## slice_board: corte LENTO de izquierda a derecha que puede empezar en
## CUALQUIER punto de la tabla (no solo sobre el bloque). La barra se llena
## entera con cada corte y se vacía para el siguiente. El recorrido completo
## debe tardar AL MENOS "duration" s; si va más rápido aparece "¡Más lento!"
## y hay que repetir. Tras cada corte intermedio se muestra "cut_stage"
## (p. ej. el bloque con una lámina ya cortada).
func _handle_slice(event: InputEvent, step: Dictionary) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and board_panel.get_global_rect().has_point(event.position):
			slice_active = true
			slice_start = event.position
			slice_start_ms = Time.get_ticks_msec()
			slice_progress = 0.0
		elif not event.pressed:
			slice_active = false
			slice_progress = 0.0
			_update_tap_bar()
	elif event is InputEventScreenDrag and slice_active:
		# "direction": "v" corta de ARRIBA ABAJO (dorayaki partido por la
		# mitad); "alt" alterna el sentido en cada pasada (ida y vuelta del
		# pincel al glasear la anguila); por defecto es el barrido de izquierda
		# a derecha de los pescados. El recorrido exigido es más corto en
		# vertical porque la tabla es mucho menos alta que ancha.
		var mode: String = step.get("direction", "h")
		var vertical: bool = mode == "v"
		# En "alt", las pasadas impares van de DERECHA a izquierda.
		var way: float = -1.0 if (mode == "alt" and slices_done % 2 == 1) else 1.0
		var advance: float = (event.position.y - slice_start.y) * way if vertical \
				else (event.position.x - slice_start.x) * way
		# Retroceso: el corte se reinicia desde aquí.
		if advance < 0.0:
			slice_start = event.position
			slice_start_ms = Time.get_ticks_msec()
			slice_progress = 0.0
			_update_tap_bar()
			return
		var sweep: float = SLICE_SWEEP_V if vertical else SLICE_SWEEP
		slice_progress = advance * (SLICE_SWEEP / sweep)
		if advance < sweep:
			_update_tap_bar()
			return
		# Recorrido completo: se evalúa la velocidad.
		slice_active = false
		slice_progress = 0.0
		var elapsed := (Time.get_ticks_msec() - slice_start_ms) / 1000.0
		if elapsed < float(step.get("duration", 0.7)):
			# "fail_penalty": cortar deprisa el pescado caro cuesta dinero (el
			# corte se repite igual, pero cada fallo se paga).
			var penalty := int(step.get("fail_penalty", 0))
			if penalty > 0 and not free_mistakes:
				_flash_message("¡Más lento!  -$%d" % penalty)
				money_penalty.emit(penalty)
			else:
				_flash_message("¡Más lento!")
			_slice_fail_feedback()
			slice_failed.emit()
			_update_tap_bar()
			return
		slices_done += 1
		GameState.bump_stat("slices_ok")
		craft_event.emit("slice", _current_stage_id())
		if slices_done >= int(step.get("count", 1)):
			_advance_step()
		else:
			# Corte intermedio: se ve la lámina ya cortada junto al bloque.
			var cut_stage: String = step.get("cut_stage", "")
			if cut_stage != "":
				_set_stage(cut_stage)
			else:
				_bump_stage(-6.0)
			_update_ui()


## Muestra un mensaje grande sobre el centro de la tabla que se desvanece.
func _flash_message(text: String, color: Color = Color(1.0, 0.86, 0.3)) -> void:
	message_label.add_theme_color_override("font_color", color)
	message_label.text = text
	message_label.reset_size()
	# Centrado en horizontal, pero POR ENCIMA del hueco donde se emplata: si se
	# pone en el centro exacto, el plato (o el barco) se le monta encima.
	var center := board_panel.position + board_panel.size / 2.0
	message_label.position = Vector2(
		center.x - message_label.size.x / 2.0,
		maxi(int(center.y - DISH_SIZE.y / 2.0 - message_label.size.y - 6.0),
			int(board_panel.position.y + 8.0)))
	message_label.modulate = Color(1, 1, 1, 1)
	message_label.scale = Vector2(0.7, 0.7)
	message_label.pivot_offset = message_label.size / 2.0
	message_label.visible = true
	if message_tween != null:
		message_tween.kill()
	message_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	message_tween.tween_property(message_label, "scale", Vector2.ONE, 0.18)
	message_tween.tween_interval(0.5)
	message_tween.tween_property(message_label, "modulate:a", 0.0, 0.3)
	message_tween.tween_callback(func() -> void: message_label.visible = false)


## Corte demasiado rápido: sacudida y destello rojo de la etapa.
func _slice_fail_feedback() -> void:
	if not stage_rect.visible:
		return
	stage_rect.pivot_offset = stage_rect.size / 2.0
	if stage_tween != null:
		stage_tween.kill()
	stage_rect.modulate = Color(1.0, 0.45, 0.45)
	stage_rect.rotation_degrees = -4.0
	stage_tween = create_tween()
	stage_tween.tween_property(stage_rect, "rotation_degrees", 4.0, 0.06)
	stage_tween.tween_property(stage_rect, "rotation_degrees", 0.0, 0.08)
	stage_tween.tween_property(stage_rect, "modulate", Color.WHITE, 0.25)


## drag_stage: arrastrar el sprite de etapa (cuenco, gamba...) hasta el prop.
## Exige arrastre REAL (>24 px) y soltar el dedo sobre el prop: un simple
## toque sobre la etapa no debe completar el paso.
func _handle_stage_drag(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and stage_rect.visible and stage_ghost == null \
				and stage_rect.get_global_rect().has_point(event.position):
			stage_ghost = TextureRect.new()
			stage_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			stage_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			stage_ghost.texture = stage_rect.texture
			stage_ghost.size = stage_rect.size
			stage_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(stage_ghost)
			stage_ghost.global_position = event.position - stage_ghost.size / 2.0
			stage_rect.visible = false
			stage_drag_start = event.position
			stage_drag_moved = false
		elif not event.pressed and stage_ghost != null:
			var hit: bool = stage_drag_moved and prop_rect.visible \
					and prop_rect.get_global_rect().grow(20.0).has_point(event.position)
			stage_ghost.queue_free()
			stage_ghost = null
			if hit:
				craft_event.emit("drag", _current_stage_id())
				_advance_step()
			else:
				stage_rect.visible = true
	elif event is InputEventScreenDrag and stage_ghost != null:
		stage_ghost.global_position = event.position - stage_ghost.size / 2.0
		if event.position.distance_to(stage_drag_start) > 24.0:
			stage_drag_moved = true


## Muestra u oculta el utensilio del paso actual (clave "prop"). Entra
## animado desde abajo hasta su sitio en la esquina derecha de la tabla.
func _update_prop() -> void:
	var prop_id: String = _current_step().get("prop", "") if state == State.CRAFTING else ""
	var tex := RecipeData.get_stage_texture(prop_id)
	if tex == null:
		if prop_tween != null:
			prop_tween.kill()
			prop_tween = null
		prop_rect.visible = false
		return
	# Los utensilios que se cogen (soplete) empiezan APAGADOS en su rincón.
	var off := RecipeData.get_stage_texture(prop_id + "_off")
	prop_rect.texture = off if off != null else tex
	if flame_tween != null:
		flame_tween.kill()
		flame_tween = null
	prop_rect.scale = Vector2.ONE
	var target := board_panel.position + board_panel.size - prop_rect.size - Vector2(8, 10)
	prop_target = target
	prop_rect.position = target + Vector2(0, 240)
	prop_rect.modulate.a = 0.0
	prop_rect.visible = true
	if prop_tween != null:
		prop_tween.kill()
	prop_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	prop_tween.tween_property(prop_rect, "position", target, 0.45)
	prop_tween.parallel().tween_property(prop_rect, "modulate:a", 1.0, 0.3)


## Lleva el utensilio al dedo (soplete del aburi): la boquilla apunta al punto
## que se está tostando, así que el sprite se ancla por su esquina inferior
## izquierda, que es donde sale la llama.
func _move_prop_to(global_pos: Vector2) -> void:
	if not prop_rect.visible or not _current_step().get("move", false):
		return
	if prop_tween != null:
		prop_tween.kill()
		prop_tween = null
	prop_rect.modulate.a = 1.0
	prop_rect.global_position = global_pos - Vector2(prop_rect.size.x * 0.18,
		prop_rect.size.y * 0.72)


## Enciende o apaga el utensilio: el soplete tiene sprite con llama y sin ella,
## y encendido la llama LATE (se anima con un pulso rápido de escala).
func _set_prop_lit(lit: bool) -> void:
	var prop_id: String = _current_step().get("prop", "")
	if prop_id == "":
		return
	var tex := RecipeData.get_stage_texture(prop_id + ("_on" if lit else "_off"))
	if tex == null:
		tex = RecipeData.get_stage_texture(prop_id)
	if tex != null:
		prop_rect.texture = tex
	if flame_tween != null:
		flame_tween.kill()
		flame_tween = null
	prop_rect.pivot_offset = Vector2(prop_rect.size.x * 0.18, prop_rect.size.y * 0.72)
	if lit:
		# Llama viva: un latido continuo mientras se está flameando.
		flame_tween = create_tween().set_loops()
		flame_tween.tween_property(prop_rect, "scale", Vector2(1.08, 0.94), 0.09)
		flame_tween.tween_property(prop_rect, "scale", Vector2(0.96, 1.06), 0.09)
		flame_tween.tween_property(prop_rect, "scale", Vector2.ONE, 0.09)
	else:
		prop_rect.scale = Vector2.ONE


## Suelta el soplete: se apaga y vuelve a su rincón, pero el progreso de la
## barra se CONSERVA (no hay que empezar el tostado de cero).
func _release_prop() -> void:
	_set_prop_lit(false)
	if prop_tween != null:
		prop_tween.kill()
	prop_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	prop_tween.tween_property(prop_rect, "position", prop_target, 0.25)


## Copia del ingrediente que sigue al dedo mientras se arrastra.
func _make_ghost(ing_id: String) -> Control:
	var g := Control.new()
	g.size = ING_SIZE
	var tex := _ingredient_texture(ing_id)
	if tex != null:
		var t := TextureRect.new()
		t.texture = tex
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.add_child(t)
	return g


func _make_dish_node(recipe_id: String) -> Control:
	var d := Control.new()
	d.size = DISH_SIZE
	var t := TextureRect.new()
	t.texture = RecipeData.get_dish_texture(recipe_id)
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.add_child(t)
	return d


func _finish_prep(grant_mastery: bool) -> void:
	state = State.READY
	ready_recipe = current_recipe
	# El cooldown siempre es el de la receta ELEGIDA, aunque el plato salga
	# con otra identidad (tempura poco hecha, aburi de atún...).
	ready_base = current_recipe
	# La fritura ya fijó precio y sprite (crudo / bien / quemado); el resto de
	# recetas valen lo que dice su ficha.
	if fry_dish != "":
		ready_recipe = fry_dish
		fry_dish = ""
	else:
		ready_price = 0
	# La elección de pescado (aburi) también cambia la identidad del plato.
	if choice_dish != "":
		ready_recipe = choice_dish
		choice_dish = ""
	ready_level = 0
	# Cada plato empieza SIN extras, aunque el anterior los llevara.
	extras_chosen.clear()
	current_recipe = ""
	if grant_mastery:
		var uses: int = RecipeData.get_recipe(ready_recipe).get("free_uses", 0)
		if uses > 0:
			free_uses[ready_recipe] = uses
	_set_stage("")
	_update_prop()
	var count := 2 if double_next else 1
	double_next = false
	for i in count:
		var d := _make_dish_node(ready_recipe)
		add_child(d)
		d.position = _dish_rest_position(i, count)
		d.pivot_offset = DISH_SIZE / 2.0
		d.scale = Vector2(0.5, 0.5)
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(d, "scale", Vector2.ONE, 0.3)
		dishes.append(d)
	craft_event.emit("done", "")
	_update_ui()


## Sitio de reposo del plato terminado. Con varias piezas (recetas con "yield")
## se reparten por el ancho de la mesa, apretándose para que quepan todas.
func _dish_rest_position(index: int = 0, total: int = 0) -> Vector2:
	var base := board_panel.position + (board_panel.size - DISH_SIZE) / 2.0
	var n: int = maxi(maxi(total, dishes.size()), index + 1)
	if n <= 1:
		return base
	var span: float = minf(160.0, (board_panel.size.x - DISH_SIZE.x) / float(n - 1))
	base.x += (float(index) - float(n - 1) * 0.5) * span
	return base


func _apply_cooldown(recipe_id: String) -> void:
	var cd: float = RecipeData.get_recipe(recipe_id).cooldown * cooldown_mult \
			* cooldown_perm_mult
	if skip_next_cooldown:
		skip_next_cooldown = false
		cd = 0.0
	cooldowns[recipe_id] = cd


func _update_ui() -> void:
	cancel_button.visible = _can_cancel()
	_update_boat_button()
	_update_combo_button()
	_update_helper_button()
	_update_extra_buttons()
	# La guía (mano y texto) solo se dibuja si el jugador lleva un rato quieto;
	# la lleva _tick_guide. Aquí únicamente se refresca la que YA está puesta.
	if guide_shown:
		_update_instruction()
	match state:
		State.IDLE:
			tap_bar.visible = false
			_hide_indicator()
		State.CRAFTING:
			_update_tap_bar()
			# Mientras se sopletea NO se rehace la guía: el recorrido en ocho
			# tiene que seguir corriendo (si se reconstruye cada frame, la mano
			# se queda clavada en el primer punto).
			if guide_shown and not (holding and _current_step().get("move", false)):
				call_deferred("_refresh_indicator")
		State.READY:
			tap_bar.visible = false
			if guide_shown:
				call_deferred("_refresh_indicator_ready")


# --- Instrucción escrita del paso actual ---

## Nombre legible de un ingrediente para los textos de ayuda.
func _ingredient_name(ing_id: String) -> String:
	var d: Dictionary = RecipeData.INGREDIENTS.get(ing_id, {})
	return str(d.get("name", ing_id))


## Qué tiene que hacer el jugador AHORA MISMO, con las repeticiones que le
## quedan ("¡Pulsa x4!" va bajando a x3, x2...).
func _instruction_text() -> String:
	# Solo el VERBO: el cartel va rotado a un lado de la tabla y una frase
	# larga ahí no se lee de un vistazo. Las repeticiones que quedan van en
	# una segunda línea corta ("x3").
	if state == State.READY:
		return "¡A la cinta!"
	if state != State.CRAFTING:
		return ""
	var step := _current_step()
	var total := int(step.get("count", 1))
	var left := 1
	match step.get("type", ""):
		"tap_ingredient":
			return "¡Toca!"
		"drag_ingredient", "drag_stage":
			return "¡Arrastra!"
		"drag_choice":
			# Mientras no haya nada marcado se pide elegir; una vez elegido, lo
			# que falta es llevarlo a la tabla.
			return "¡Arrastra!" if choice_selected != "" else "¡Elige uno!"
		"tap_board":
			left = maxi(total - taps_done, 1)
			var verb := "¡Corta!" if bool(step.get("cutting", false)) else "¡Pulsa!"
			return verb if total <= 1 else "%s
x%d" % [verb, left]
		"hold_board":
			return "¡Tuesta!" if step.get("move", false) else "¡Mantén!"
		"fry_board":
			# Con las milésimas a la vista: el punto exacto vale el doble.
			if frying:
				return "%.2f s" % fry_time
			return "¡Fríe %ds!" % int(step.get("target", 3.0))
		"swipe_board":
			left = maxi(total - swipes_done, 1)
			return "¡Desliza!" if total <= 1 else "¡Desliza!
x%d" % left
		"stir_board":
			left = maxi(total - stir_turns, 1)
			return "¡Remueve!" if total <= 1 else "¡Remueve!
x%d" % left
		"slice_board":
			left = maxi(total - slices_done, 1)
			# "brush": el mismo gesto lento, pero pintando (glasear la anguila).
			var verb2: String = "¡Unta!" if bool(step.get("brush", false)) else "¡Corta!"
			return verb2 if total <= 1 else "%s
x%d" % [verb2, left]
	return ""


## Coloca el cartel del gesto en el LADO DERECHO de la tabla, inclinado: ahí no
## tapa ni la etapa ni la mano, y se lee como un letrero clavado.
##
## La distancia al borde se calcula sobre la HUELLA DEL TEXTO YA GIRADO, no con
## un margen fijo: al bajar la inclinación el cartel se ensancha mucho y con un
## número fijo se salía de la tabla.
func _update_instruction() -> void:
	var txt := _instruction_text()
	if txt == "":
		instruction_label.visible = false
		return
	if instruction_label.text != txt:
		instruction_label.text = txt
		instruction_label.reset_size()
		_pop_instruction()
	# En modo diestro el cartel va clavado en el borde IZQUIERDO de la tabla
	# (el pulgar derecho tapaba justo el lado derecho, que era su sitio), con
	# la inclinación espejada para que siga "cayendo" hacia el centro.
	var righty := GameState.right_handed()
	instruction_label.rotation_degrees = -INSTRUCTION_ANGLE if righty \
			else INSTRUCTION_ANGLE
	instruction_label.pivot_offset = instruction_label.size / 2.0
	var rad := deg_to_rad(INSTRUCTION_ANGLE)
	var half_w := (instruction_label.size.x * absf(cos(rad))
		+ instruction_label.size.y * absf(sin(rad))) * 0.5
	var edge_x := INSTRUCTION_MARGIN + half_w if righty \
			else board_panel.size.x - INSTRUCTION_MARGIN - half_w
	var anchor := board_panel.position + Vector2(edge_x, board_panel.size.y * 0.5)
	instruction_label.position = anchor - instruction_label.size / 2.0
	instruction_label.visible = true


## Rebote al cambiar el texto (que se note que queda una repetición menos).
func _pop_instruction() -> void:
	instruction_label.pivot_offset = instruction_label.size / 2.0
	if instruction_tween != null:
		instruction_tween.kill()
	instruction_label.scale = Vector2(1.16, 1.16)
	instruction_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	instruction_tween.tween_property(instruction_label, "scale", Vector2.ONE, 0.22)


# --- Mano de gestos: indicador animado del paso actual ---

## Mano y flecha grandes: son la guía del jugador y tienen que leerse de un
## vistazo en el móvil.
const HAND_SIZE := Vector2(116, 150)
## Bastante translucida: es una AYUDA, no parte del plato. Opaca competia con
## la etapa que hay debajo y ensuciaba la lectura de la tabla.
const HAND_ALPHA := 0.5
const ARROW_SIZE := Vector2(68, 90)
## Anillo que late en el punto exacto donde hay que tocar: la mano sola se
## perdía sobre las etapas claras (el arroz es casi del mismo color).
const RING_SIZE := Vector2(128, 128)
## Punto de anclaje de la mano respecto a su esquina: la mano queda POR
## ENCIMA del objetivo, con la base a la altura del objeto, para que nunca
## lo tape ni cuelgue por debajo.
const HAND_TIP := Vector2(58, 164)

func _hide_indicator() -> void:
	if indicator_tween != null:
		indicator_tween.kill()
		indicator_tween = null
	if ring_tween != null:
		ring_tween.kill()
		ring_tween = null
	if hand != null:
		hand.visible = false
	if ghost_hint != null:
		ghost_hint.visible = false
	if arrow_hint != null:
		arrow_hint.visible = false
	if touch_ring != null:
		touch_ring.visible = false


## Late un anillo en el punto de contacto (pulsar y mantener).
func _ring_pulse(center: Vector2, period: float) -> void:
	touch_ring.position = center - RING_SIZE / 2.0
	touch_ring.visible = true
	ring_tween = create_tween().set_loops()
	ring_tween.tween_callback(func() -> void:
		touch_ring.scale = Vector2(0.45, 0.45)
		touch_ring.modulate.a = 0.95)
	ring_tween.tween_property(touch_ring, "scale", Vector2(1.1, 1.1), period) \
			.set_trans(Tween.TRANS_SINE)
	ring_tween.parallel().tween_property(touch_ring, "modulate:a", 0.0, period)


func _local_center(node: Control) -> Vector2:
	var r := node.get_global_rect()
	return r.position + r.size / 2.0 - global_position


## Prepara la mano para una nueva animación en el punto de contacto dado.
func _hand_begin(tip_pos: Vector2, down: bool = false) -> void:
	hand.texture = hand_down_tex if down else hand_up_tex
	hand.size = HAND_SIZE
	hand.scale = Vector2.ONE
	hand.position = tip_pos - HAND_TIP
	hand.modulate.a = HAND_ALPHA
	hand.visible = true


func _hand_at(tip_pos: Vector2) -> Vector2:
	return tip_pos - HAND_TIP


func _refresh_indicator() -> void:
	if state != State.CRAFTING:
		return
	# El barco combinado no tiene `steps`: su guía es arrastrar los platos a la
	# bandeja. Sin esta rama, el repintado normal encontraba la lista de pasos
	# vacía y apagaba la mano que acababa de poner _layout_boat_parts.
	if current_recipe == BOAT_RECIPE:
		_boat_hint()
		return
	_hide_indicator()
	var step := _current_step()
	var board_center := board_panel.position + board_panel.size / 2.0
	var stage_center := board_center
	if stage_rect.visible:
		stage_center = board_panel.position + stage_rect.position + stage_rect.size / 2.0
	match step.get("type", ""):
		"tap_ingredient":
			var node: Control = ingredient_nodes.get(step.get("ingredient", ""))
			if node == null:
				return
			_hand_tap_at(_local_center(node), false)
		"tap_board":
			_hand_tap_at(stage_center, true)
		"hold_board":
			# Con "move" la mano recorre un OCHO sin parar: enseña que hay que
			# pasear el soplete, y sigue puesta aunque ya lo estés usando.
			if step.get("move", false):
				_hand_figure_eight(stage_center)
			else:
				_hand_hold_at(stage_center)
		"swipe_board":
			var sdir: String = _swipe_direction(step)
			var dir := Vector2(0, 1)
			if sdir == "up":
				dir = Vector2(0, -1)
			elif sdir == "right":
				dir = Vector2(1, 0)
			elif sdir == "left":
				dir = Vector2(-1, 0)
			elif sdir == "diag":
				dir = Vector2(1, 1).normalized()
			# Algo por debajo de la etapa: con la mano grande, arrancar en el
			# centro exacto la sacaba por encima de la tabla.
			# El recorrido de la mano acompaña al que se exige de verdad.
			var span: float = float(step.get("distance", SWIPE_THRESHOLD)) * 0.85
			_hand_swipe(stage_center + Vector2(0, 46), dir, 0.4, span)
		"drag_ingredient":
			var node: Control = ingredient_nodes.get(step.get("ingredient", ""))
			if node == null:
				return
			ghost_hint.texture = _ingredient_texture(step.get("ingredient", ""))
			ghost_hint.size = ING_SIZE
			# Si el paso trae utensilio, la mano lleva el ingrediente HASTA él.
			var drop_at := stage_center
			if step.get("prop", "") != "" and prop_rect.visible:
				drop_at = prop_target + prop_rect.size / 2.0
			_hand_drag(_local_center(node), drop_at)
		"stir_board":
			_hand_circle_at(stage_center)
		"slice_board":
			# Corte lento: de izquierda a derecha, de arriba abajo con
			# "direction": "v", o alternando el sentido en cada pasada con
			# "alt" (el pincel del glaseado). Deslizar pausado y ancho.
			var smode: String = step.get("direction", "h")
			if smode == "v":
				_hand_swipe(stage_center, Vector2(0, 1), 1.0, 70.0)
			elif smode == "alt":
				var way := Vector2(-1, 0) if slices_done % 2 == 1 else Vector2(1, 0)
				_hand_swipe(stage_center, way, 1.0, 150.0)
			else:
				_hand_swipe(board_center, Vector2(1, 0), 1.2, 175.0)
		"drag_choice":
			var opts: Array = step.get("options", [])
			if opts.is_empty():
				return
			# Si ya hay uno marcado, la mano deja de ofrecer y lleva ESE.
			if choice_selected != "" and choice_selected in opts:
				opts = [choice_selected]
			_hand_drag_choice(opts, stage_center)
		"drag_stage":
			if not prop_rect.visible:
				return
			ghost_hint.texture = stage_rect.texture
			ghost_hint.size = stage_rect.size
			_hand_drag(stage_center, prop_target + prop_rect.size / 2.0)


## Plato listo: la mano arrastra un fantasma del plato hasta la cinta.
func _refresh_indicator_ready() -> void:
	if state != State.READY or dishes.is_empty():
		return
	_hide_indicator()
	ghost_hint.texture = RecipeData.get_dish_texture(ready_recipe)
	ghost_hint.size = DISH_SIZE
	var a: Vector2 = dishes[0].position + DISH_SIZE / 2.0
	var b: Vector2 = serve_slot.position + serve_slot.size / 2.0
	_hand_drag(a, b)


## Pulsación: la mano baja el dedo sobre el punto (rápida si es repetida).
func _hand_tap_at(tip_pos: Vector2, fast: bool) -> void:
	_hand_begin(tip_pos)
	_ring_pulse(tip_pos, 0.52 if fast else 0.8)
	var up_t := 0.16 if fast else 0.38
	var down_t := 0.10 if fast else 0.16
	indicator_tween = create_tween().set_loops()
	indicator_tween.tween_callback(func() -> void: hand.texture = hand_up_tex)
	indicator_tween.tween_interval(up_t)
	indicator_tween.tween_callback(func() -> void: hand.texture = hand_down_tex)
	indicator_tween.tween_property(hand, "position:y", _hand_at(tip_pos).y + 6.0, down_t)
	indicator_tween.tween_property(hand, "position:y", _hand_at(tip_pos).y, down_t)


## Mantener pulsado: dedo abajo con un latido suave.
func _hand_hold_at(tip_pos: Vector2) -> void:
	_hand_begin(tip_pos, true)
	_ring_pulse(tip_pos, 0.95)
	hand.pivot_offset = HAND_TIP
	indicator_tween = create_tween().set_loops()
	indicator_tween.tween_property(hand, "scale", Vector2(1.12, 1.12), 0.45)
	indicator_tween.tween_property(hand, "scale", Vector2.ONE, 0.45)


## Arrastre: pulsa sobre el objeto, lo lleva hasta el destino (con su
## fantasma), lo suelta y repite.
func _hand_drag(from_pos: Vector2, to_pos: Vector2) -> void:
	_hand_begin(from_pos)
	ghost_hint.visible = true
	ghost_hint.position = from_pos - ghost_hint.size / 2.0
	ghost_hint.modulate.a = 0.0
	indicator_tween = create_tween().set_loops()
	indicator_tween.tween_callback(func() -> void:
		hand.texture = hand_up_tex
		hand.position = _hand_at(from_pos)
		hand.modulate.a = HAND_ALPHA
		ghost_hint.position = from_pos - ghost_hint.size / 2.0
		ghost_hint.modulate.a = 0.0)
	indicator_tween.tween_property(ghost_hint, "modulate:a", 0.7, 0.15)
	indicator_tween.tween_callback(func() -> void: hand.texture = hand_down_tex)
	indicator_tween.tween_interval(0.12)
	indicator_tween.tween_property(hand, "position", _hand_at(to_pos), 0.9) \
			.set_trans(Tween.TRANS_SINE)
	indicator_tween.parallel().tween_property(ghost_hint, "position",
			to_pos - ghost_hint.size / 2.0, 0.9).set_trans(Tween.TRANS_SINE)
	indicator_tween.tween_callback(func() -> void: hand.texture = hand_up_tex)
	indicator_tween.tween_interval(0.25)
	indicator_tween.tween_property(hand, "modulate:a", 0.0, 0.2)
	indicator_tween.parallel().tween_property(ghost_hint, "modulate:a", 0.0, 0.2)


## Elección entre varios ingredientes: la mano recorre TODAS las opciones, una
## por vuelta, para que se vea que sirve cualquiera. Con una sola opción (ya
## marcada) se comporta igual que un arrastre normal.
func _hand_drag_choice(opts: Array, to_pos: Vector2) -> void:
	var starts: Array[Vector2] = []
	var texs: Array[Texture2D] = []
	for ing_id in opts:
		var node: Control = ingredient_nodes.get(ing_id)
		if node == null:
			continue
		starts.append(_local_center(node))
		texs.append(_ingredient_texture(ing_id))
	if starts.is_empty():
		return
	_hand_drag_cycle(starts, texs, ING_SIZE, to_pos)


## Arrastre guiado que recorre VARIOS orígenes, uno por vuelta, cada uno con su
## propio dibujo: los ingredientes de un paso de elección y los platos que
## quedan por subir al barco combinado.
func _hand_drag_cycle(starts: Array[Vector2], texs: Array[Texture2D],
		tamano: Vector2, to_pos: Vector2) -> void:
	if starts.is_empty():
		return
	ghost_hint.size = tamano
	ghost_hint.texture = texs[0]
	_hand_begin(starts[0])
	ghost_hint.visible = true
	ghost_hint.position = starts[0] - ghost_hint.size / 2.0
	ghost_hint.modulate.a = 0.0
	indicator_tween = create_tween().set_loops()
	for i in starts.size():
		var from_pos: Vector2 = starts[i]
		var tex: Texture2D = texs[i]
		indicator_tween.tween_callback(func() -> void:
			ghost_hint.texture = tex
			hand.texture = hand_up_tex
			hand.position = _hand_at(from_pos)
			hand.modulate.a = HAND_ALPHA
			ghost_hint.position = from_pos - ghost_hint.size / 2.0
			ghost_hint.modulate.a = 0.0)
		indicator_tween.tween_property(ghost_hint, "modulate:a", 0.7, 0.15)
		indicator_tween.tween_callback(func() -> void: hand.texture = hand_down_tex)
		indicator_tween.tween_interval(0.12)
		indicator_tween.tween_property(hand, "position", _hand_at(to_pos), 0.9) \
				.set_trans(Tween.TRANS_SINE)
		indicator_tween.parallel().tween_property(ghost_hint, "position",
				to_pos - ghost_hint.size / 2.0, 0.9).set_trans(Tween.TRANS_SINE)
		indicator_tween.tween_callback(func() -> void: hand.texture = hand_up_tex)
		indicator_tween.tween_interval(0.25)
		indicator_tween.tween_property(hand, "modulate:a", 0.0, 0.2)
		indicator_tween.parallel().tween_property(ghost_hint, "modulate:a", 0.0, 0.2)


## Deslizamiento: dedo abajo y movimiento en la dirección dada (rápido por
## defecto; travel_time/span mayores para los cortes lentos).
func _hand_swipe(center: Vector2, dir: Vector2, travel_time := 0.4, span := 88.0) -> void:
	var a := center - dir * span
	var b := center + dir * span
	_hand_begin(a, true)
	# La flecha propia apunta en la dirección del gesto y viaja con la mano.
	arrow_hint.rotation = dir.angle() + PI / 2.0
	arrow_hint.visible = true
	var arrow_off := Vector2(72, -10)
	indicator_tween = create_tween().set_loops()
	indicator_tween.tween_callback(func() -> void:
		hand.texture = hand_down_tex
		hand.position = _hand_at(a)
		hand.modulate.a = HAND_ALPHA
		arrow_hint.position = _hand_at(a) + arrow_off
		arrow_hint.modulate.a = 0.9)
	indicator_tween.tween_interval(0.15)
	indicator_tween.tween_property(hand, "position", _hand_at(b), travel_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	indicator_tween.parallel().tween_property(arrow_hint, "position", _hand_at(b) + arrow_off, travel_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	indicator_tween.tween_property(hand, "modulate:a", 0.0, 0.15)
	indicator_tween.parallel().tween_property(arrow_hint, "modulate:a", 0.0, 0.15)
	indicator_tween.tween_interval(0.25)


## Círculo: el dedo recorre una circunferencia (para gestos rotatorios).
func _hand_circle_at(center: Vector2, radius: float = 74.0) -> void:
	_hand_begin(center + Vector2(radius, 0), true)
	indicator_tween = create_tween().set_loops()
	indicator_tween.tween_method(func(ang: float) -> void:
		hand.position = _hand_at(center + Vector2(cos(ang), sin(ang)) * radius),
		0.0, TAU, 1.4)


## Recorrido en OCHO (lemniscata) para el soplete: enseña que hay que pasear
## la llama por todo el pescado, no dejarla quieta en un punto.
func _hand_figure_eight(center: Vector2, rx: float = 86.0, ry: float = 42.0) -> void:
	_hand_begin(center, true)
	indicator_tween = create_tween().set_loops()
	indicator_tween.tween_method(func(t: float) -> void:
		hand.position = _hand_at(center + Vector2(sin(t) * rx, sin(t * 2.0) * ry * 0.5)),
		0.0, TAU, 2.0)


func _update_tap_bar() -> void:
	_update_instruction()
	var step := _current_step()
	match step.get("type", ""):
		"tap_board":
			tap_bar.visible = true
			tap_bar.max_value = int(step.get("count", 1))
			tap_bar.value = taps_done
		"swipe_board":
			tap_bar.visible = true
			tap_bar.max_value = int(step.get("count", 1))
			# Progreso CONTINUO: las pasadas hechas más lo que lleva la actual.
			tap_bar.value = swipes_done + swipe_progress
		"hold_board":
			tap_bar.visible = true
			tap_bar.max_value = step.get("duration", 1.0)
			tap_bar.value = hold_time
		"fry_board":
			# Sin barra: el contador con milésimas es la única guía (a pulso).
			tap_bar.visible = false
		"stir_board":
			tap_bar.visible = true
			tap_bar.max_value = int(step.get("count", 1))
			# Progreso continuo: vueltas completas más la fracción en curso.
			tap_bar.value = stir_turns + absf(stir_angle) / TAU
		"slice_board":
			# La barra representa SOLO el corte en curso: se llena entera con
			# cada corte y vuelve a vaciarse para el siguiente.
			tap_bar.visible = true
			tap_bar.max_value = 1.0
			tap_bar.value = clampf(slice_progress / SLICE_SWEEP, 0.0, 1.0)
		_:
			tap_bar.visible = false
