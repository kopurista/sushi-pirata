extends Control
## PESCA: el minijuego del pergamino "Pesca", montado DENTRO del propio menú
## (misma escena, como Aventura): `main_menu._go_fishing` aparta la interfaz
## con `_ui_out(false)` —las cajas de recursos se quedan— y cuelga este
## Control del `ui_layer`; al cerrar, `closed` la devuelve con `_ui_in`.
## El mar y el barco son los del menú, quietos donde estaban.
##
## FLUJO (estilo Animal Crossing): el botón ÚNICO "Pulsa para pescar" (tablón
## con boya, `boton_pesca.png`, con la MONEDA del juego y el 50) cobra el
## intento (FishData.FISHING_COST) y aparece la SOMBRA de un pez —con forma
## de pez— que NADA por el agua entre rumbos al azar (hay que apuntar
## adelantándose) → el jugador TOCA EL AGUA para lanzar el sedal; si el
## anzuelo no interesa, la ÚNICA forma de recuperarlo es MANTENER la pantalla
## para recogerlo y volver a lanzar (gratis dentro del intento) → cuando el
## anzuelo entra en su CAMPO DE VISIÓN, la sombra se acerca y FINTA de 2 a 5
## veces (tocar durante una finta la ESPANTA y el intento se pierde) → en la
## picada real el flotador se hunde con "¡Ha picado!" y hay BITE_WINDOW (1 s)
## para tocar → PELEA: caña grande a un lado con dos barras VERTICALES — el
## SEDAL sube al mantener (a tope se rompe) y la PRESA empieza al 50–80%
## según el premio y hay que vaciarla; si llega al 100%, ESCAPA. En las FASES
## DE VELOCIDAD la presa tira (recupera deprisa) y hay que pulsar rápido y
## repetidamente — pero CADA TOQUE también tensa el sedal, que puede romperse
## igual si se pulsa a lo loco con la barra roja alta.
##
## EL PREMIO SE SORTEA ANTES DE VER LA SOMBRA (`GameState.fishing_roll()`):
## de su `tier` (0..3) sale la dificultad — el sedal se tensa más deprisa, la
## presa recupera más y las fases de velocidad son más largas y frecuentes.
## El tamaño de la sombra también crece con el tier (la pista del jugador).
## Solo al lograr la captura se toca estado (`GameState.fishing_apply`).
##
## El sedal, el flotador y la sombra se DIBUJAN POR CÓDIGO (señal `draw` del
## panel táctil): cero assets, y así la sombra puede mecerse por fotograma.

const PrepBoard := preload("res://scripts/prep_board.gd")

const DARK := Color(0.26, 0.16, 0.08)
const FADED := Color(0.45, 0.34, 0.2)

signal closed
## El monedero cambió (cobro del intento o premio): el menú refresca sus cajas.
signal money_changed
## Se enciende en cuanto el intento está EN JUEGO (del lanzamiento hasta que se
## resuelve) y se apaga al volver a la calma. El menú lo usa para apagar los
## botones "+" de las cajas de recursos: abrir un panel de compra con el pez
## enganchado no para el reloj de la pesca, así que costaba el intento entero.
signal busy_changed(on: bool)
## Experiencia de cocinero de una captura: el menú la enseña subiendo en la
## BARRA DE NIVEL, con su "+N exp" flotando. Se emite al ENTREGAR el premio
## (`GameState.fishing_apply` ya la ha sumado y devuelve cuánta fue).
signal xp_gained(amount: int)
## El ÁLBUM se abre o se cierra. La BARRA DE NIVEL vive en el `ui_layer` del
## menú y va por ENCIMA de la pesca a propósito (ver `main_menu._go_fishing`),
## así que se colaba sobre las fichas del álbum: con esto el menú la aparta
## mientras el álbum está puesto.
signal album_abierto(on: bool)
## EL PEZ ESTÁ TIRANDO: lo escucha `main_menu` para temblar la cámara y
## acercarla un pelín. Se apaga al terminar el tirón (o la pelea).
signal rush_changed(on: bool)

## Una pieza de coleccionable CON ESCENA acaba de salir del agua. Se representa
## aquí mismo, con la pesca todavía en pantalla: contarla al volver al menú
## dejaba a David bromeando sobre un tenedor que el jugador había pescado tres
## pantallas atrás.
signal escena_coleccionable

enum State { READY, SHADOW, APPROACH, FEINT, BITE, FIGHT, REVEAL, ESCAPED }

## Punta de la caña (borde derecho del barco DEL MENÚ, medido sobre captura)
## y rectángulo de agua útil para lanzar y para la sombra.
const ROD_TIP := Vector2(505, 395)
## PUNTA DE LA CAÑA VIGENTE. `ROD_TIP` es la medida de reposo con la pose que
## tiene el barco cuando cabecea; el barco es 3D y con "menos animaciones" se
## queda plano, así que la borda se dibuja unos píxeles más arriba y la línea
## blanca nacía FUERA del casco. `main_menu` la reescribe por fotograma
## proyectando un punto del propio barco (ver `ROD_LOCAL` allí), así que el
## sedal queda pegado a la borda con cualquier ajuste de gráficos. Si nadie la
## toca (una pantalla que no sea el menú), se queda en la medida de reposo.
var rod_tip := ROD_TIP
const WATER := Rect2(50.0, 545.0, 620.0, 550.0)
const SHADOW_MARGIN := 70.0
## Radio del campo de visión del pez: el anzuelo tiene que caer a esto.
const VISION_R := 120.0
const CAST_TIME := 0.38
const BITE_WINDOW := 1.0
## Fintas: cuántas (2..5) y sus tiempos. El pez espera RETIRADO unos píxeles
## del anzuelo y en cada intento AVANZA hasta tocarlo con la BOCA y vuelve.
const FEINT_DIP := 7.0
const FEINT_ANIM := 0.3
const FEINT_RETREAT := 26.0
const BITE_SINK := 24.0
## La sombra NADA entre rumbos al azar (hay que apuntar adelantándose) y el
## sedal se RECOGE manteniendo la pantalla.
const FISH_SPEED := 62.0
const RETRIEVE_SPEED := 620.0

## --- Pelea. Base para tier 0; cada tier suma su parte (mejor premio, pelea
## más dura). La PRESA empieza a ENERGY_START (50–80% según tier), se vacía
## para capturar y ESCAPA si llega al 100%. En la fase de velocidad recupera
## SPEED_REGAIN y cada toque le resta TAP_CHUNK pero TENSA el sedal
## TAP_TENSION: pulsar a lo loco con la barra roja alta también lo rompe. ---
const TENSION_BASE := 0.30
const TENSION_TIER := 0.28
const TENSION_RELIEF := 0.85
const DRAIN_HOLD := 0.20
## --- CONTRA EL SPAM DE PULSACIONES (era el agujero que rompía la pesca:
## dando toquecitos se recogía al pez sin que el sedal llegara a tensarse).
## Tres reglas juntas: 1) el sedal recibe un PICO en cada pulsación, así que
## machacar la pantalla lo revienta; 2) la presa NO empieza a ceder hasta
## llevar HOLD_MIN segundos de dedo apoyado, o sea que el toque suelto no
## recoge nada; 3) suelto, el pez recupera CADA VEZ MÁS DEPRISA (rampa por
## `idle_time`), y quedarse mirando sale caro. ---
const TAP_TENSION_KICK := 0.07
const HOLD_MIN := 0.20
## LO QUE RECUPERA LA PRESA CON EL SEDAL EN DESCANSO. Está CALIBRADO, no
## puesto a ojo: hay que soltar para que el sedal no reviente, así que si el
## pez recupera en ese descanso más de lo que se le drena mientras se recoge,
## la barra sube en cada ciclo y la captura es IMPOSIBLE por mucho que se
## juegue bien. Pasó: con 0.10+0.03/tier, un épico grande y TODOS los
## legendarios no se podían pescar (simulado ciclo a ciclo con el jugador
## óptimo). Con estos números la pelea dura de 4 s (común pequeño) a 17 s
## (legendario grande). Al tocarlos, VOLVER A SIMULAR el ciclo entero, que a
## ojo no se ve: solo se nota jugando veinte veces.
const REGAIN_BASE := 0.055
const REGAIN_TIER := 0.015
## Cuánto acelera la recuperación por segundo sin mantener, y su tope.
const REGAIN_RAMP := 0.55
const REGAIN_RAMP_MAX := 2.2
const ENERGY_START_BASE := 0.6
const ENERGY_START_TIER := 0.1
## En la fase de velocidad la presa SIEMPRE intenta subir a este ritmo
## (0.31–0.5/s según el premio: aquí se puede PERDER de verdad); cada toque
## NO la baja: le abre una ventana de TAP_RELIEF s en la que el subidón queda
## FRENADO y solo entonces cae un poquito (SPEED_DRAIN_TAPPING). Pulsando más
## rápido que la ventana, la barra baja despacito; pulsando lento, sube entre
## toque y toque.
## En VELOCIDAD la presa tira de verdad, y MUCHO más cuanto mejor es el
## premio: de 0.34/s (un común) a 0.94/s (un legendario), o sea que ignorar
## un tirón de una pieza gorda la pierde en poco más de un segundo.
const SPEED_REGAIN_BASE := 0.34
const SPEED_REGAIN_TIER := 0.13
## El tirón NO se dispara con la barra casi llena: con la presa por encima de
## esto no habría margen para reaccionar (a tier 3 sube 0.73/s, así que un
## tirón con la barra al 90% la perdería en una décima) y la fase se viviría
## como una muerte súbita en vez de como una amenaza. Con este techo siempre
## quedan ~0.4 s de reacción en lo peor, y encima narra mejor: el pez tira
## con todo justo cuando se ve perdiendo.
const SPEED_MAX_ENERGY := 0.72
const SPEED_TIME_BASE := 1.1
const SPEED_TIME_TIER := 0.35
const SPEED_TENSION_DECAY := 0.25
const TAP_RELIEF := 0.3
const SPEED_DRAIN_TAPPING := 0.03
const TAP_TENSION := 0.045
## --- El TIRA Y AFLOJA: la boya (con el pez debajo) VIAJA por el sedal, y su
## distancia al barco ES la lectura visual de la ENERGÍA de la presa — llena
## la tiene lejos (LINE_T_FAR), vacía la trae pegada al casco (LINE_T_NEAR).
## `line_t` persigue ese destino con retardo (LINE_FOLLOW) para que el viaje
## se vea, y la FUERZA del pez escala con su TAMAÑO y con esa distancia
## (lejos y grande = recupera más), ver `_fish_strength`.
const LINE_T_NEAR := 0.16
const LINE_T_FAR := 1.12
const LINE_FOLLOW := 0.55
## La manivela de la caña: gira despacio al recoger y AL REVÉS y MUCHO más
## rápido cuando el pez se lleva sedal (en la fase de velocidad se desboca).
const CRANK_REEL_SPEED := 2.6
const CRANK_BACK_SPEED := 7.0
const CRANK_BACK_FAST := 26.0

var state: int = State.READY
var _t := 0.0

## El sorteo del intento en curso (GameState.fishing_roll) y su dificultad.
var roll: Dictionary = {}
var tier := 0
## Tamaño del pez sorteado (0..1): agranda la sombra, sube sus doblones y da
## fuerza a la pelea.
var catch_size := 0.5

# Sombra y sedal.
var shadow_base := Vector2.ZERO
var shadow_pos := Vector2.ZERO
## Rumbo del pez (radianes) y punto del agua al que nada ahora mismo.
var heading := 0.0
var wander_target := Vector2.ZERO
## true mientras se MANTIENE la pantalla recogiendo el sedal.
var retrieving := false
var casting := false
var cast_t := 0.0
var cast_from := Vector2.ZERO
var cast_to := Vector2.ZERO
var bobber := Vector2.ZERO
var bobber_out := false
var feints_left := 0
var feint_timer := 0.0
var feint_anim := 0.0
## Intentos de picada YA HECHOS en este intento: la medida de seguridad — un
## toque durante el acercamiento o antes de la PRIMERA finta no espanta.
var feints_done := 0
var bite_t := 0.0
var bite_sink := 0.0

# Pelea.
var holding := false
## Segundos con el dedo apoyado SIN soltar (la presa no cede hasta HOLD_MIN)
## y segundos sin mantener (rampa de recuperación del pez).
var hold_time := 0.0
var idle_time := 0.0
var tension := 0.0
var energy := 1.0
## CLASE DE CAI EN CURSO: el intento va amañado (ver `_clase_de_pesca`). El pez
## es el más fácil que existe, no se cobra, el sedal perdona, la presa no se
## escapa y hay UNA fase de velocidad garantizada y floja.
var clase := false
## Cai esta diciendo una leccion: la pelea se queda congelada (ver `_leccion`).
var leccion_en_curso := false
## Cuánto perdona el sedal y cuánto tira la presa mientras Cai enseña.
## Tope de las barras en la clase y en el tutorial: ni el sedal se rompe ni la
## presa se suelta, pero por debajo hay recorrido de sobra que ver moverse.
const CLASE_TOPE := 0.9
const CLASE_TENSION := 0.4
const CLASE_TIRON := 0.35
## Intentos que da la clase antes de rendirse: si el pez se escapa, se
## vuelve a empezar en vez de dejar al jugador sin aprender la pelea.
const CLASE_INTENTOS := 3
var phases_left := 0
var speed_left := 0.0
var speed_next := 0.0
## Ventana abierta por el ÚLTIMO toque de la fase de velocidad: mientras dura,
## la subida de la presa está frenada.
var speed_relief := 0.0
## Dónde picó el pez y en qué punto del sedal va la boya (el tira y afloja).
var fight_far := Vector2.ZERO
var line_t := 1.0
## Ángulo acumulado de la manivela de la caña.
var crank_angle := 0.0

var zone: Control = null
var cast_btn: Button = null
var instruction: Label = null
## Cifra del coste en el botón de pescar (dice GRATIS con las tiradas que
## regala Cai al terminar su clase).
var cast_cost_label: Label = null
## La moneda que acompaña al precio: en la clase de Cai se esconde, porque
## esa tirada no cuesta nada y el "100" hacia creer que si.
var cast_coin: TextureRect = null
var back_btn: Button = null
var album_btn: Button = null
var fight_box: Control = null
var tension_bar: ProgressBar = null
var energy_bar: ProgressBar = null
var rod: TextureRect = null
var crank: TextureRect = null
## El relleno del SEDAL, guardado para teñirlo por fotograma (ver
## `_tension_color`): verde → naranja → rojo según la tensión.
var tension_fill: StyleBoxTexture = null
## --- EL TIRÓN, EN PANTALLA. Cuando la presa tira con fuerza no basta con
## que cambie un número: se enciende un velo de LÍNEAS DE ACCIÓN de cómic
## centradas en el pez, la caña se va de lado a lado, la escena se acerca
## un pelín y la cámara tiembla (eso último lo hace el menú, ver la señal
## `rush_changed`). Todo vuelve a su sitio al acabar el tirón. ---
var rush_fx: ColorRect = null
var rush_mat: ShaderMaterial = null
var rush_on := false
## EL TUTORIAL GUIADO en curso (ver `_tutorial_guiado`). Comparte con la
## clase de Cai el amaño del intento (`clase`), pero aquí no habla nadie:
## el cartel y los focos lo cuentan todo mientras se juega.
## Lo que se deja leer un paso del tutorial antes de dejarlo pasar.
const TUTOR_MIN_LEER := 1.1
## Lo que se adelanta el aro a la BOCA del pez (px de lienzo).
const TUTOR_DELANTE := 54.0
## Cada cuánto insiste el cartel cuando el jugador no hace lo que toca.
const TUTOR_INSISTE := 6.0
## Lo que dura el TIRÓN dentro del tutorial. Uno de verdad dura 3-4 s y ahí no
## da tiempo ni a leer el cartel: es la única mecánica de la pesca que no se
## entiende sin haberla hecho, así que en la clase se alarga.
const TUTOR_TIRON := 11.0
## Salto de linea de los carteles del tutorial. Va por `char(10)` y no
## por una secuencia de escape: los parches automaticos de este repo se
## comen las barras invertidas (ver el aviso de CLAUDE.md).
const TUTOR_NL := char(10)
var tutor := false
## El jugador ya ha MANTENIDO de verdad (mas de `HOLD_MIN`) durante la pelea
## del tutorial, y ya ha SOLTADO despues. Son los dos gestos que el tutorial
## no puede dar por sabidos: hasta que no ocurren, no se pasa de paso.
var tutor_mantuvo := false
var tutor_solto := false
## El jugador ha pulsado "Salir del tutorial": el guion se corta donde este.
var tutor_abandonar := false
## El intento del tutorial se ha perdido (ver `_tutor_roto`).
var tutor_perdido := false
var salir_tutor_btn: Button = null
## En el TUTORIAL la presa no se puede cobrar hasta haber explicado el
## TIRON: jugando bien la barra se vaciaba en cuatro segundos y la
## leccion mas importante se quedaba sin dar (medido con un jugador
## simulado). Se libera en cuanto el tiron termina.
var tutor_falta_tiron := false
var tutor_card: Control = null
var tutor_label: Label = null
var ayuda_btn: Button = null
## El banco de efectos de la pesca (ver `SND` y `_setup_audio`).
var snd: SoundBank = null
## Lo que se mueve la barra de la presa, en barra/s y ya suavizado: es lo que
## marca la velocidad del carrete (ver `VEL_REF`).
var vel_barra := 0.0
var energy_prev := 0.0
var tension_prev := 0.0
## Cruce entre los dos bucles de la pelea: 0 es el arrastre del jugador
## recogiendo y 1 el carrete que se lleva el pez (ver `MEZCLA_VEL`).
var mezcla_pez := 0.0
## Cruce con el carrete del TIRÓN: 0 pelea normal, 1 el pez llevándose todo.
var mezcla_tiron := 0.0
## Lo que EMPUJA el pez en el tirón (barra/s), aunque el jugador lo frene.
var tiron_tasa := 0.0
## Opacidad MAXIMA de las lineas. Casi opaca: con los parametros suaves
## (lineas largas y difusas) el velo no tapa nada, y a media opacidad el
## tiron apenas se notaba.
const RUSH_FADE := 0.95
## Vaivén de la caña durante el tirón (píxeles y velocidad).
const RUSH_ROD_SWAY := 16.0
const RUSH_ROD_HZ := 11.0


func _ready() -> void:
	# TRAMPA de CanvasLayer: anclas a cero y tamaño explícito (ver CLAUDE.md).
	position = Vector2.ZERO
	size = GameState.canvas_size()
	_setup_ui()
	_set_state(State.READY)
	# CAI recibe al jugador: la primera vez con su clase entera, y a partir de
	# ahí con un saludo distinto cada visita.
	_cai_entrada.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	# Los anillos del tutorial siguen a lo que senalan (y laten), asi que se
	# repintan SIEMPRE — tambien con la leccion parada, que ahi el latido es
	# lo unico que dice "mira aqui".
	for i in range(_anillos.size() - 1, -1, -1):
		var a := _anillos[i]
		if a == null or not is_instance_valid(a):
			_anillos.remove_at(i)
		else:
			a.queue_redraw()
	# El botón del tablón RESPIRA suavemente mientras espera (el latido del
	# viejo texto de la portada, en versión botón).
	if state == State.READY and cast_btn != null and not cast_btn.disabled \
			and not cast_btn.button_pressed:
		var k := 1.0 + 0.015 * sin(_t * 2.4)
		cast_btn.scale = Vector2(k, k)
	# MIENTRAS CAI HABLA NO CORRE NADA. La caja se traga todos los toques, asi
	# que cualquier cosa que avance por debajo es tiempo que el jugador no
	# puede jugar: explicando la finta, el pez se llevaba el cebo en mitad de
	# la frase que decia como evitarlo.
	if leccion_en_curso:
		zone.queue_redraw()
		return
	match state:
		State.SHADOW, State.APPROACH, State.FEINT:
			_tick_precast(delta)
			zone.queue_redraw()
		State.BITE:
			bite_t -= delta
			bite_sink = minf(bite_sink + delta * 160.0, BITE_SINK)
			zone.queue_redraw()
			if bite_t <= 0.0:
				_escaped("Se ha llevado el cebo...")
		State.FIGHT:
			_tick_fight(delta)
			zone.queue_redraw()


# ------------------------------------------------------------------ interfaz

func _setup_ui() -> void:
	var st := GameState.safe_top()
	zone = Control.new()
	zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	zone.mouse_filter = Control.MOUSE_FILTER_STOP
	zone.gui_input.connect(_on_zone_input)
	zone.draw.connect(_draw_sea)
	add_child(zone)

	back_btn = PrepBoard.make_back_button()
	back_btn.position = Vector2(18.0, 96.0 + st)
	back_btn.pressed.connect(func() -> void:
		await _cai_salida()
		closed.emit())
	add_child(back_btn)
	# (Sin lazo de título: el tablón del botón ya dice dónde estamos.)

	# EL BOTÓN DE PESCAR: tablón único con cuerdas y boya (`boton_pesca.png`,
	# sprite fijo — su marco es irregular), con el rótulo y la MONEDA del
	# juego encima. Sustituye al viejo texto latiente.
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	cast_btn = Button.new()
	for bst in ["normal", "hover", "pressed", "disabled", "focus"]:
		cast_btn.add_theme_stylebox_override(bst, StyleBoxEmpty.new())
	cast_btn.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	cast_btn.offset_left = 125.0
	cast_btn.offset_right = -125.0
	cast_btn.offset_top = -218.0 - GameState.safe_bottom()
	cast_btn.offset_bottom = -56.0 - GameState.safe_bottom()
	PrepBoard.add_press_feedback(cast_btn, 0.94)
	cast_btn.pressed.connect(_start_attempt)
	add_child(cast_btn)
	var tabla := TextureRect.new()
	tabla.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tabla.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tabla.texture = load("res://assets/ui/boton_pesca.png")
	tabla.set_anchors_preset(Control.PRESET_FULL_RECT)
	tabla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cast_btn.add_child(tabla)
	var contenido := VBoxContainer.new()
	contenido.set_anchors_preset(Control.PRESET_FULL_RECT)
	contenido.offset_left = 70.0
	contenido.offset_right = -70.0
	contenido.offset_top = 26.0
	contenido.offset_bottom = -34.0
	contenido.alignment = BoxContainer.ALIGNMENT_CENTER
	contenido.add_theme_constant_override("separation", 0)
	contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cast_btn.add_child(contenido)
	var rotulo := Label.new()
	rotulo.text = "Pulsa para pescar"
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.add_theme_font_size_override("font_size", 29)
	rotulo.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	rotulo.add_theme_color_override("font_outline_color", Color(0.24, 0.13, 0.05))
	rotulo.add_theme_constant_override("outline_size", 9)
	if negrita != null:
		rotulo.add_theme_font_override("font", negrita)
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenido.add_child(rotulo)
	var fila_coste := HBoxContainer.new()
	fila_coste.alignment = BoxContainer.ALIGNMENT_CENTER
	fila_coste.add_theme_constant_override("separation", 6)
	fila_coste.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenido.add_child(fila_coste)
	var moneda := TextureRect.new()
	moneda.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	moneda.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	moneda.texture = load("res://assets/ui/moneda.png")
	moneda.custom_minimum_size = Vector2(32, 32)
	moneda.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	moneda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cast_coin = moneda
	fila_coste.add_child(moneda)
	var coste := Label.new()
	cast_cost_label = coste
	# El texto lo pone `_refresh_cast_label` al final del montaje: escribiendo
	# aquí el precio a pelo, la PRIMERA tirada de una visita con regalos de Cai
	# pendientes decía "100" (y la de después ya decía "GRATIS x2"), como si el
	# juego hubiera cobrado el intento que en realidad salía gratis.
	coste.text = ""
	coste.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coste.add_theme_font_size_override("font_size", 26)
	coste.add_theme_color_override("font_color", Color(1, 0.86, 0.4))
	coste.add_theme_color_override("font_outline_color", Color(0.24, 0.13, 0.05))
	coste.add_theme_constant_override("outline_size", 8)
	if negrita != null:
		coste.add_theme_font_override("font", negrita)
	coste.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila_coste.add_child(coste)

	# Rótulo de estado ("¡Ha picado!", "¡Mantén!"...), grande, bajo el agua.
	instruction = Label.new()
	instruction.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	instruction.offset_top = -340.0 - GameState.safe_bottom()
	instruction.offset_bottom = -220.0 - GameState.safe_bottom()
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instruction.add_theme_font_size_override("font_size", 40)
	instruction.add_theme_color_override("font_color", Color(1, 0.95, 0.84))
	instruction.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.04))
	instruction.add_theme_constant_override("outline_size", 11)
	if negrita != null:
		instruction.add_theme_font_override("font", negrita)
	instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(instruction)

	# El ÁLBUM: botón con su propio icono (ic_album), ARRIBA A LA DERECHA.
	album_btn = Button.new()
	for bst in ["normal", "hover", "pressed", "disabled", "focus"]:
		album_btn.add_theme_stylebox_override(bst, StyleBoxEmpty.new())
	album_btn.position = Vector2(size.x - 116.0, 88.0 + st)
	album_btn.size = Vector2(96.0, 96.0)
	PrepBoard.add_press_feedback(album_btn)
	var album_ic := TextureRect.new()
	album_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	album_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	album_ic.texture = load("res://assets/ui/ic_album.png")
	album_ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	album_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	album_btn.add_child(album_ic)
	album_btn.pressed.connect(_open_album)
	add_child(album_btn)

	_setup_audio()
	_setup_tutor_card()
	_setup_ayuda_btn()
	_setup_rush_fx()
	_setup_fight_ui()
	_refresh_cast_label()


## Dónde se dibuja la CAÑA-HUD y dónde caen, EN FRACCIONES de su rectángulo,
## el canal del sedal y el eje del carrete. El RECT calca la proporción de la
## textura (76x460) para que las fracciones del rect sean las del dibujo.
## Medidos por barrido de alfa sobre `pesca_cana_hud.png` (mástil centrado en
## x 0.49, carrete en y 0.746): si se regenera, volver a medir.
const ROD_RECT := Rect2(600.0, 462.0, 74.0, 448.0)
const ROD_TRACK_X := 0.49
## El canal NO llega al extremo del mástil: deja asomar la punta de la caña
## por arriba y su madera por abajo, o el instrumento se leía como dos barras
## sueltas con un carrete debajo.
const ROD_TRACK_TOP := 0.10
const ROD_TRACK_BOTTOM := 0.60
const ROD_REEL := Vector2(0.493, 0.746)
## Grosor de las dos barras del instrumento y dónde cae la de la PRESA (en
## píxeles del rectángulo de la caña; negativo = a la izquierda del mástil).
## El sedal va MÁS GORDO que antes (14) pero sin comerse el mástil, que mide
## 16-19 px: así la madera asoma por los lados y la barra parece embutida.
const TENSION_BAR_W := 20.0
const ENERGY_BAR_W := 24.0
const ENERGY_BAR_X := -38.0


## La CAÑA-HUD de la pelea: una caña VERTICAL tan larga como las barras, con
## la barra del SEDAL integrada en el propio mástil (un listón fino sobre su
## canal, HIJO de la caña: se dobla y tiembla con ella) y la MANIVELA del
## carrete girando — despacio al recoger, al revés y más deprisa cuando el
## pez se lleva sedal (`_animate_rod`). Al lado, la barra de la PRESA
## (textura horizontal del set girada -90°: el 9-slice se dibuja en
## horizontal y la rotación lo pone de pie sin deformar los topes).
## EL VELO DE LÍNEAS DE ACCIÓN del tirón (`shaders/action_lines.gdshader`).
## Va por encima del agua y de la caña, pero POR DEBAJO de los carteles del
## botín (z 200) y del velo de los focos (150): es un efecto, no una capa que
## deba tapar lo que hay que leer. Y no recibe toques, que justo entonces hay
## que estar pulsando como un poseso.
## EL CARTEL DEL TUTORIAL: una tarjeta de pergamino ARRIBA, bajo la fila de
## botones. Va arriba y no abajo a propósito — abajo están el agua donde se
## pesca, el rótulo de estado y el botón de lanzar, y taparlos mientras se
## explica cómo usarlos sería una broma pesada.
func _setup_tutor_card() -> void:
	if tutor_card != null and is_instance_valid(tutor_card):
		return
	tutor_card = Control.new()
	tutor_card.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tutor_card.offset_left = 26.0
	tutor_card.offset_right = -26.0
	tutor_card.offset_top = 258.0 + GameState.safe_top()
	tutor_card.offset_bottom = 398.0 + GameState.safe_top()
	tutor_card.z_index = 170
	tutor_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutor_card.visible = false
	add_child(tutor_card)
	var fondo := PrepBoard.make_nine_patch(PrepBoard.CARD_TEX,
		PrepBoard.CARD_MARGIN)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutor_card.add_child(fondo)
	tutor_label = Label.new()
	tutor_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	tutor_label.offset_left = 24.0
	tutor_label.offset_right = -24.0
	tutor_label.offset_top = 14.0
	tutor_label.offset_bottom = -14.0
	tutor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutor_label.add_theme_font_size_override("font_size", 25)
	tutor_label.add_theme_color_override("font_color", DARK)
	tutor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutor_card.add_child(tutor_label)


## El botón que repite el TUTORIAL, bajo el álbum: madera con aro dorado
## y la interrogación tallada (`boton_ayuda.png`, generado a juego con el
## resto del set). Sprite FIJO y no 9-slice: es redondo, y estirarlo lo
## deformaría.
func _setup_ayuda_btn() -> void:
	if ayuda_btn != null and is_instance_valid(ayuda_btn):
		return
	ayuda_btn = Button.new()
	for bst in ["normal", "hover", "pressed", "disabled", "focus"]:
		ayuda_btn.add_theme_stylebox_override(bst, StyleBoxEmpty.new())
	ayuda_btn.position = Vector2(size.x - 112.0, 196.0 + GameState.safe_top())
	ayuda_btn.size = Vector2(88.0, 88.0)
	PrepBoard.add_press_feedback(ayuda_btn)
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = load("res://assets/ui/boton_ayuda.png")
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ayuda_btn.add_child(ic)
	ayuda_btn.pressed.connect(_preguntar_tutorial)
	add_child(ayuda_btn)


func _setup_rush_fx() -> void:
	if rush_fx != null and is_instance_valid(rush_fx):
		return
	rush_mat = ShaderMaterial.new()
	rush_mat.shader = load("res://shaders/action_lines.gdshader")
	rush_mat.set_shader_parameter("fade", 0.0)
	rush_fx = ColorRect.new()
	rush_fx.color = Color.WHITE
	rush_fx.material = rush_mat
	rush_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	rush_fx.z_index = 120
	rush_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rush_fx.visible = false
	add_child(rush_fx)


## Enciende o apaga TODO el aparato del tirón: líneas de acción, acercamiento
## de la escena y aviso al menú para que tiemble la cámara.
func _set_rush(on: bool) -> void:
	if on == rush_on:
		return
	rush_on = on
	rush_changed.emit(on)
	# Un golpe seco AL EMPEZAR, encima del carrete: el tirón es un cambio de
	# fase y las líneas de acción entran con un fundido de 0.18 s, así que
	# sin él el momento exacto en que hay que empezar a pulsar no suena.
	if on and snd != null:
		snd.play("tiron", SND_TIRON)
	if rush_fx != null and is_instance_valid(rush_fx):
		if on:
			rush_fx.visible = true
		# El fundido va por METODO, no por lambda multilinea dentro de la
		# llamada: GDScript no las digiere bien ahi.
		var tw := rush_fx.create_tween()
		tw.tween_method(_set_rush_fade, _rush_fade(),
			RUSH_FADE if on else 0.0, 0.18 if on else 0.3)
		if not on:
			tw.tween_callback(_hide_rush_fx)
	# EL ACERCAMIENTO lo hace SOLO la camara 3D (ver la senal, en el
	# menu). Estuvo tambien escalando `zone` con el pivote en el pez, y
	# no vale: el SEDAL se dibuja dentro de `zone`, asi que al escalarlo
	# su nacimiento se despegaba del barco y la linea quedaba flotando.


func _set_rush_fade(v: float) -> void:
	if rush_mat != null:
		rush_mat.set_shader_parameter("fade", v)


func _hide_rush_fx() -> void:
	if rush_fx != null and is_instance_valid(rush_fx):
		rush_fx.visible = false


func _rush_fade() -> float:
	if rush_mat == null:
		return 0.0
	return float(rush_mat.get_shader_parameter("fade"))


func _setup_fight_ui() -> void:
	# Idempotente: la clase de Cai la monta antes de tiempo para poder
	# enseñarla, y sin esta salida montaba una segunda caña encima.
	if fight_box != null and is_instance_valid(fight_box):
		return
	fight_box = Control.new()
	fight_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	fight_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fight_box.visible = false
	add_child(fight_box)

	rod = TextureRect.new()
	rod.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rod.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rod.texture = load("res://assets/ui/pesca_cana_hud.png")
	rod.position = ROD_RECT.position
	rod.size = ROD_RECT.size
	# La caña se dobla desde su EMPUÑADURA (abajo), como una caña de verdad.
	rod.pivot_offset = Vector2(ROD_RECT.size.x * 0.5, ROD_RECT.size.y)
	rod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fight_box.add_child(rod)

	# LAS DOS BARRAS van DENTRO de la caña (hijas suyas): así se inclinan y
	# tiemblan con ella y el conjunto se lee como UN solo instrumento.
	# · SEDAL sobre el mástil, GRUESA para que se vea de un vistazo y con el
	#   color puesto por fotograma (verde → naranja → rojo, `_tension_color`).
	# · PRESA en paralelo, a la izquierda del mástil.
	var track_len := ROD_RECT.size.y * (ROD_TRACK_BOTTOM - ROD_TRACK_TOP)
	tension_fill = PrepBoard.make_bar_box(PrepBoard.BAR_FILL_TEX,
		_tension_color(0.0))
	tension_bar = _make_rod_bar(track_len, TENSION_BAR_W,
		ROD_RECT.size.x * ROD_TRACK_X, tension_fill)
	energy_bar = _make_rod_bar(track_len, ENERGY_BAR_W, ENERGY_BAR_X,
		PrepBoard.make_bar_box(PrepBoard.BAR_FILL_TEX, Color(0.95, 0.72, 0.20)))
	_rod_label("Sedal", ROD_RECT.size.x * ROD_TRACK_X)
	_rod_label("Presa", ENERGY_BAR_X)

	# La MANIVELA, clavada en el eje del carrete de la caña.
	crank = TextureRect.new()
	crank.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crank.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crank.texture = load("res://assets/ui/pesca_manivela.png")
	crank.size = Vector2(52.0, 52.0)
	crank.position = Vector2(ROD_RECT.size.x * ROD_REEL.x - 26.0,
		ROD_RECT.size.y * ROD_REEL.y - 26.0)
	crank.pivot_offset = Vector2(26.0, 26.0)
	crank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rod.add_child(crank)


## Una barra VERTICAL montada en la caña: se construye horizontal (el 9-slice
## del set solo se puede estirar a lo ancho, y así los topes redondos no se
## deforman) y se gira -90° para ponerla de pie. `x` es el centro que ocupa
## dentro del rectángulo de la caña.
func _make_rod_bar(largo: float, grosor: float, x: float,
		fill: StyleBoxTexture) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0.0
	p.max_value = 1.0
	p.show_percentage = false
	p.size = Vector2(largo, grosor)
	p.rotation = -PI / 2.0
	p.position = Vector2(x - grosor * 0.5,
		ROD_RECT.size.y * ROD_TRACK_BOTTOM)
	p.add_theme_stylebox_override("background",
		PrepBoard.make_bar_box(PrepBoard.BAR_BG_TEX))
	p.add_theme_stylebox_override("fill", fill)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rod.add_child(p)
	return p


## Rótulo al pie de una de las barras de la caña (también hijo de la caña:
## se inclina con ella, que es lo que hace que el conjunto se lea como uno).
func _rod_label(texto: String, x: float) -> void:
	var l := Label.new()
	l.text = texto
	l.position = Vector2(x - 44.0, ROD_RECT.size.y * ROD_TRACK_BOTTOM + 6.0)
	l.size = Vector2(88.0, 28.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.84))
	l.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.04))
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rod.add_child(l)


## El color del SEDAL según su tensión: verde tranquilo, naranja a media y
## rojo cuando está a punto de romperse.
func _tension_color(v: float) -> Color:
	var verde := Color(0.42, 0.78, 0.30)
	var naranja := Color(0.98, 0.64, 0.13)
	var rojo := Color(0.94, 0.20, 0.14)
	if v < 0.5:
		return verde.lerp(naranja, v / 0.5)
	return naranja.lerp(rojo, (v - 0.5) / 0.5)


## La manivela gira con quien manda en el sedal, y la caña se dobla y tiembla.
func _animate_rod(delta: float, en_velocidad: bool) -> void:
	if en_velocidad:
		crank_angle -= CRANK_BACK_FAST * delta
	elif holding:
		crank_angle += CRANK_REEL_SPEED * delta
	else:
		crank_angle -= CRANK_BACK_SPEED * delta
	if crank != null:
		crank.rotation = crank_angle
	if rod != null:
		# Poca inclinación a propósito: las barras y sus rótulos CUELGAN de
		# la caña, y un ángulo grande dejaba el texto tumbado.
		var destino := -0.055 if holding else -0.02
		if en_velocidad:
			destino = -0.085
		var temblor := sin(_t * 26.0) * (0.014 if en_velocidad else 0.005)
		rod.rotation = lerpf(rod.rotation, destino,
			minf(delta * 6.0, 1.0)) + temblor
		# Y CON EL TIRON SE VA DE LADO A LADO: la cana entera baila, que
		# es lo que se ve desde lejos. Vuelve a su sitio al aflojar.
		var sway := 0.0
		if en_velocidad:
			sway = sin(_t * RUSH_ROD_HZ) * RUSH_ROD_SWAY
		rod.position.x = lerpf(rod.position.x,
			ROD_RECT.position.x + sway, minf(delta * 14.0, 1.0))


# ------------------------------------------------------------ estados y bucle

## ¿Hay un intento EN JUEGO? Los 50 doblones ya están apostados desde que se
## lanza el sedal, así que cuenta todo lo que no sea la calma del principio ni
## el cartel del botín. Es la misma condición con la que se esconde el "Atrás".
func is_busy() -> bool:
	return not (state == State.READY or state == State.REVEAL)



func _set_state(s: int) -> void:
	# Ningun bucle sobrevive a un cambio de estado: el carrete sonando
	# sobre el cartel del botin (o sobre el menu al salir) canta muchisimo.
	if snd != null and s != State.FIGHT and s != State.SHADOW:
		snd.todos_los_bucles_off()
	var antes := is_busy()
	state = s
	if is_busy() != antes:
		busy_changed.emit(is_busy())
	cast_btn.visible = s == State.READY
	album_btn.visible = s == State.READY
	if ayuda_btn != null and is_instance_valid(ayuda_btn):
		# El "?" solo en reposo: en plena pelea no se cambia de tema.
		ayuda_btn.visible = s == State.READY and not tutor
	# En plena faena no hay "Atrás": los 50 ya están apostados.
	back_btn.visible = s == State.READY or s == State.REVEAL
	fight_box.visible = s == State.FIGHT
	if s == State.READY:
		instruction.text = ""
		bobber_out = false
		casting = false
		retrieving = false
		cast_btn.scale = Vector2.ONE
		var falta := GameState.money < FishData.FISHING_COST
		cast_btn.disabled = falta
		PrepBoard.set_dimmed(cast_btn, falta)
		if falta:
			instruction.text = "Sin doblones para el cebo..."
	zone.queue_redraw()
	# LA ESCENA DE LA PIEZA, en cuanto se cierra el cartel del botín y antes
	# de volver a lanzar. En diferido porque quien llama a `_set_state` suele
	# estar dentro de la lambda de un botón que se está liberando.
	if s == State.READY and not clase and not tutor 			and not GameState.pending_col_scenes.is_empty():
		escena_coleccionable.emit.call_deferred()


func _start_attempt() -> void:
	# EN LA CLASE PAGA CAI y el pez está elegido: el más fácil que existe, para
	# que la primera pelea de la vida del jugador no pueda salir mal.
	if clase:
		roll = GameState.fishing_roll()
		roll["tier"] = 0
		# En el TUTORIAL, ademas, nunca sale cofre: se aprende a pelear
		# con un pez, y un cofre dejaria la leccion a medias.
		if tutor:
			while str(roll.get("type", "")) != "fish":
				roll = GameState.fishing_roll()
			roll["tier"] = 0
			roll["practica"] = true
		tier = 0
		catch_size = 0.2
	else:
		if not GameState.fishing_pay():
			instruction.text = "Sin doblones para el cebo..."
			return
		money_changed.emit()
		_refresh_cast_label()
		# EL SORTEO, ANTES DE VER LA SOMBRA: el premio ya está decidido y de él
		# sale la dificultad de la pelea (y el tamaño de la sombra).
		roll = GameState.fishing_roll()
		tier = int(roll.get("tier", 0))
		catch_size = clampf(float(roll.get("size", 0.5)), 0.0, 1.0)
	var inner := WATER.grow(-SHADOW_MARGIN)
	shadow_base = Vector2(randf_range(inner.position.x, inner.end.x),
		randf_range(inner.position.y, inner.end.y))
	shadow_pos = shadow_base
	heading = randf_range(0.0, TAU)
	wander_target = _pick_wander()
	bobber_out = false
	casting = false
	retrieving = false
	feints_done = 0
	snd.play("cebo", SND_EFECTO)
	instruction.text = "Toca el agua para lanzar el sedal"
	_set_state(State.SHADOW)


func _pick_wander() -> Vector2:
	var inner := WATER.grow(-SHADOW_MARGIN)
	return Vector2(randf_range(inner.position.x, inner.end.x),
		randf_range(inner.position.y, inner.end.y))


## Lanza (o relanza) el sedal al punto tocado. Relanzar es gratis: el intento
## ya está cobrado.
func _cast_to(punto: Vector2) -> void:
	cast_from = rod_tip
	cast_to = Vector2(clampf(punto.x, WATER.position.x, WATER.end.x),
		clampf(punto.y, WATER.position.y, WATER.end.y))
	snd.play("lanzar", SND_EFECTO)
	casting = true
	cast_t = 0.0
	bobber_out = true
	instruction.text = ""


func _tick_precast(delta: float) -> void:
	if state == State.SHADOW:
		_swim(delta)
		# RECOGER el sedal: solo MANTENIENDO la pantalla (la única forma de
		# volver a lanzar si el pez pasa del anzuelo).
		if retrieving and bobber_out and not casting:
			snd.loop_on("recoger", SND_BUCLE)
			bobber = bobber.move_toward(rod_tip, RETRIEVE_SPEED * delta)
			if bobber.distance_to(rod_tip) < 26.0:
				bobber_out = false
				retrieving = false
				snd.loop_off("recoger")
				instruction.text = "Toca el agua para lanzar el sedal"
	if casting:
		cast_t += delta / CAST_TIME
		if cast_t >= 1.0:
			casting = false
			snd.play("boya", SND_EFECTO)
			bobber = cast_to
			if state == State.SHADOW \
					and shadow_pos.distance_to(bobber) > VISION_R:
				instruction.text = "Mantén para recoger el sedal"
		else:
			# Vuelo en parábola: recta + comba de altura.
			var k := cast_t
			bobber = cast_from.lerp(cast_to, k) \
				+ Vector2(0.0, -130.0 * sin(k * PI))
		return
	# El campo de visión se mira CADA fotograma: el pez nada, así que puede
	# entrar él solo en el radio del anzuelo (o alejarse antes de tiempo).
	if state == State.SHADOW and bobber_out and not retrieving \
			and shadow_pos.distance_to(bobber) <= VISION_R:
		_start_approach()
		return
	match state:
		State.APPROACH:
			# La sombra nada hasta quedarse con la BOCA a un palmo del
			# anzuelo (el cuerpo queda DETRÁS, retirado FEINT_RETREAT).
			heading = lerp_angle(heading, (bobber - shadow_pos).angle(),
				minf(delta * 5.0, 1.0))
			var destino := _feint_rest()
			shadow_pos = shadow_pos.lerp(destino, minf(delta * 2.4, 1.0))
			if shadow_pos.distance_to(destino) < 6.0:
				feints_left = randi_range(2, 5)
				feint_timer = randf_range(0.55, 1.1)
				_set_state(State.FEINT)
		State.FEINT:
			# Mirando al anzuelo desde su puesto retirado; en cada intento
			# EMBISTE hacia delante (la boca llega al anzuelo justo cuando el
			# flotador se hunde) y vuelve a retroceder.
			heading = lerp_angle(heading, (bobber - shadow_pos).angle(),
				minf(delta * 4.0, 1.0))
			var avance := 0.0
			if feint_anim > 0.0:
				feint_anim = maxf(feint_anim - delta, 0.0)
				avance = sin(feint_anim / FEINT_ANIM * PI) \
					* (FEINT_RETREAT + 3.0)
			shadow_pos = _feint_rest() \
				+ Vector2.from_angle(heading) * avance \
				+ Vector2.from_angle(heading + PI * 0.5) * sin(_t * 1.4) * 3.0
			if feint_anim > 0.0:
				return
			feint_timer -= delta
			if feint_timer <= 0.0:
				if feints_left > 0:
					# Finta: embiste y mordisquea sin tragar. Tocar desde
					# AHORA (ya ha habido un intento) espanta al pez.
					feints_left -= 1
					feints_done += 1
					feint_anim = FEINT_ANIM
					snd.play("amago", SND_AMAGO)
					feint_timer = randf_range(0.55, 1.1)
				else:
					_enter_bite()


## Radio de la silueta del pez: la rareza pone la base y el TAMAÑO sorteado
## la escala (la sombra ya chiva si es un ejemplar grande).
## Cuanto se agranda la sombra del pez en el tiron. Va sobre el DIBUJO y
## no escalando `zone` a proposito: el sedal se dibuja ahi dentro y al
## escalarlo se despegaba del barco (ver `_set_rush`).
const RUSH_FISH_ZOOM := 0.18


## 0 en calma y 1 con el tiron a pleno: sale del fundido de las lineas,
## asi que todo el efecto entra y sale acompasado.
func _rush_k() -> float:
	return clampf(_rush_fade() / RUSH_FADE, 0.0, 1.0)


func _fish_r() -> float:
	return (26.0 + 7.0 * tier) * (0.75 + 0.5 * catch_size) \
		* (1.0 + RUSH_FISH_ZOOM * _rush_k())


## El puesto del pez frente al anzuelo: el CENTRO del cuerpo queda de forma
## que la BOCA (el morro de la silueta, a ~1.35 radios del centro) apunte al
## flotador desde FEINT_RETREAT píxeles de distancia.
func _feint_rest() -> Vector2:
	var nariz := _fish_r() * 1.35 + 4.0
	return bobber - Vector2.from_angle(heading) * (nariz + FEINT_RETREAT) \
		+ Vector2(0, 6.0)


## La FUERZA del pez en la pelea: su tamaño y lo lejos que está del barco.
## Multiplica lo que recupera la presa (suelto y en velocidad).
func _fish_strength() -> float:
	return (0.85 + 0.3 * catch_size) \
		* (0.75 + 0.45 * clampf(line_t / LINE_T_FAR, 0.0, 1.0))


## El pez NADA de rumbo en rumbo (no se queda clavado: hay que apuntar
## adelantándose), con un culebreo suave superpuesto.
func _swim(delta: float) -> void:
	if shadow_base.distance_to(wander_target) < 14.0:
		wander_target = _pick_wander()
	var dir := (wander_target - shadow_base).angle()
	heading = lerp_angle(heading, dir, minf(delta * 1.8, 1.0))
	shadow_base += Vector2.from_angle(heading) * FISH_SPEED * delta
	# El culebreo va PERPENDICULAR al rumbo, como un pez de verdad.
	var lado := Vector2.from_angle(heading + PI * 0.5)
	shadow_pos = shadow_base + lado * sin(_t * 3.1) * 7.0


func _start_approach() -> void:
	instruction.text = ""
	_set_state(State.APPROACH)


func _enter_bite() -> void:
	snd.play("chapoteo", SND_EFECTO, PITCH_PICADA)
	bite_t = BITE_WINDOW
	bite_sink = 0.0
	# La picada de verdad: el pez se queda ADELANTADO, con la boca en el
	# anzuelo (sin el retiro de las fintas).
	shadow_pos = bobber - Vector2.from_angle(heading) * (_fish_r() * 1.35) \
		+ Vector2(0, 6.0)
	instruction.text = "¡Ha picado!"
	_set_state(State.BITE)


func _start_fight() -> void:
	holding = true
	hold_time = 0.0
	idle_time = 0.0
	tension = 0.0
	speed_relief = 0.0
	# El tira y afloja arranca donde picó: la boya viajará por ese sedal.
	fight_far = bobber
	crank_angle = 0.0
	# La presa empieza entre el 60% (tier 0) y el 90% (tier 3), con un pelín
	# más si el ejemplar es grande: cuanto mejor el premio, menos margen
	# hasta el 100% que la deja escapar.
	energy = minf(ENERGY_START_BASE + ENERGY_START_TIER * tier \
		+ 0.06 * (catch_size - 0.5), 0.93)
	# El carrete arranca callado: sin esto, el primer fotograma mide el salto
	# desde la energía de la pelea ANTERIOR y suena un acelerón de la nada.
	energy_prev = energy
	tension_prev = tension
	vel_barra = 0.0
	mezcla_pez = 0.0
	mezcla_tiron = 0.0
	# La distancia SALE de la energía (ver `_tick_fight`): con la barra casi
	# llena, el pez arranca la pelea lejos del casco.
	line_t = lerpf(LINE_T_NEAR, LINE_T_FAR, energy)
	# Fases de velocidad: más y más largas cuanto mejor es el premio.
	match tier:
		0: phases_left = randi_range(0, 1)
		1: phases_left = 1
		2: phases_left = randi_range(1, 2)
		_: phases_left = randi_range(2, 3)
	speed_left = 0.0
	speed_next = randf_range(1.2, 2.6)
	# EN LA CLASE, UNA fase de velocidad y ni una más: el tirón es lo único que
	# no se puede explicar sin verlo, y en un intento normal de tier 0 puede no
	# salir ninguno. El guion la provoca cuando le toca (`speed_next = 0`), no
	# antes, para que Cai llegue a avisar. Y la presa arranca a media barra:
	# hay pelea que sentir, pero no un muro.
	if clase:
		phases_left = 1
		speed_next = 999.0
		energy = 0.7
		line_t = lerpf(LINE_T_NEAR, LINE_T_FAR, energy)
	instruction.text = "¡Mantén para recoger!\nSuelta si el sedal sufre"
	_set_state(State.FIGHT)


func _tick_fight(delta: float) -> void:
	var fuerza := _fish_strength()
	# EN LA CLASE el sedal perdona y el pez tira flojo: la primera pelea de
	# la vida del jugador no se puede perder, solo entender.
	var k_ten := CLASE_TENSION if clase else 1.0
	var k_tiron := CLASE_TIRON if clase else 1.0
	var en_velocidad := speed_left > 0.0
	if en_velocidad:
		speed_left -= delta
		speed_relief = maxf(speed_relief - delta, 0.0)
		if holding:
			hold_time += delta
		else:
			hold_time = 0.0
		# MANTENER NO VALE EN LA FASE DE VELOCIDAD: aquí hay que PULSAR. Si
		# el dedo se queda apoyado (pasado HOLD_MIN, para no confundirlo con
		# un toque normal), el freno de los toques se CANCELA —así que la
		# presa sube a plena fuerza— y encima el sedal se tensa igual que
		# recogiendo. Aguantar el tirón a pulso rompe el sedal.
		var manteniendo := holding and hold_time >= HOLD_MIN
		if manteniendo:
			speed_relief = 0.0
			tension += TENSION_BASE * (1.0 + TENSION_TIER * tier) * k_ten * delta
		else:
			tension = maxf(tension - SPEED_TENSION_DECAY * delta, 0.0)
		# La presa SIEMPRE intenta subir todo lo posible; cada toque no la
		# baja, le FRENA la subida durante TAP_RELIEF s (y tensa el sedal en
		# _on_zone_input). Solo pulsando más rápido que la ventana la barra
		# baja, y muy poco.
		# Lo que EMPUJA el pez, lo frene el jugador o no: es lo que manda en el
		# sonido del tirón (ver `_audio_pelea`).
		tiron_tasa = k_tiron * (SPEED_REGAIN_BASE + SPEED_REGAIN_TIER * tier) \
			* fuerza
		if speed_relief > 0.0:
			energy -= SPEED_DRAIN_TAPPING * delta
		else:
			energy += tiron_tasa * delta
		if speed_left <= 0.0:
			instruction.text = "¡Mantén para recoger!\nSuelta si el sedal sufre"
	else:
		tiron_tasa = 0.0
		if phases_left > 0:
			speed_next -= delta
			# Con la barra casi llena el tirón se APLAZA (ver SPEED_MAX_ENERGY):
			# ahí no habría margen de reacción y sería una muerte súbita.
			if speed_next <= 0.0 and energy <= SPEED_MAX_ENERGY:
				phases_left -= 1
				speed_left = SPEED_TIME_BASE + SPEED_TIME_TIER * tier
				speed_next = randf_range(2.2, 4.0)
				instruction.text = "¡Tira con fuerza!\n¡PULSA RÁPIDO!"
		if holding:
			hold_time += delta
			idle_time = 0.0
			if hold_time >= HOLD_MIN:
				tutor_mantuvo = true
			# La presa NO cede hasta que el dedo lleva HOLD_MIN apoyado: un
			# toque suelto tensa el sedal (ver el pico de `_on_zone_input`)
			# pero no recoge ni un palmo.
			if hold_time >= HOLD_MIN:
				energy -= DRAIN_HOLD * delta
			tension += TENSION_BASE * (1.0 + TENSION_TIER * tier) * k_ten * delta
		else:
			hold_time = 0.0
			idle_time += delta
			if tutor_mantuvo:
				tutor_solto = true
			# Cuanto más tiempo sin recoger, más deprisa recupera el pez.
			var rampa := minf(1.0 + idle_time * REGAIN_RAMP, REGAIN_RAMP_MAX)
			energy += k_tiron * (REGAIN_BASE + REGAIN_TIER * tier) * fuerza \
				* rampa * delta
			tension -= TENSION_RELIEF * delta
	energy = clampf(energy, 0.0, 1.0)
	tension = clampf(tension, 0.0, 1.0)
	# LO QUE SE MUEVEN LAS DOS BARRAS es lo que manda en el sonido del
	# carrete. Se mide DESPUÉS de los topes, no de las fórmulas: con una
	# barra a cero o a tope el pez tira igual pero ESA barra ya no se mueve,
	# y el carrete tiene que enterarse.
	var mov := absf(energy - energy_prev) + absf(tension - tension_prev)
	vel_barra = lerpf(vel_barra, mov / maxf(delta, 0.001),
		minf(delta * VEL_SUAVIZADO, 1.0))
	energy_prev = energy
	tension_prev = tension
	# EL TIRA Y AFLOJA: la DISTANCIA del pez al barco la manda su ENERGÍA —
	# cuanta menos le queda, más cerca lo tenemos; si la recupera, se aleja.
	# `line_t` persigue ese destino con retardo para que el viaje se vea.
	var destino_t := lerpf(LINE_T_NEAR, LINE_T_FAR, energy)
	line_t = move_toward(line_t, destino_t, LINE_FOLLOW * delta)
	bobber = rod_tip + (fight_far - rod_tip) * line_t
	bobber.y = maxf(bobber.y, WATER.position.y + 14.0)
	_audio_pelea(delta, en_velocidad)
	_animate_rod(delta, en_velocidad)
	tension_bar.value = tension
	energy_bar.value = energy
	# El SEDAL se tiñe con su propio nivel: verde tranquilo, naranja a media
	# tensión y rojo cuando está a punto de romperse.
	if tension_fill != null:
		tension_fill.modulate_color = _tension_color(tension)
	# La barra de la presa parpadea en la fase de velocidad: es el aviso.
	energy_bar.modulate = Color(1, 0.7, 0.7) \
		if en_velocidad and fmod(_t, 0.22) < 0.11 else Color.WHITE
	# EL TIRON EN PANTALLA: lineas de accion, acercamiento y temblor.
	_set_rush(en_velocidad)
	if rush_on and rush_mat != null:
		# Las lineas convergen EN EL PEZ, que va debajo de la boya y se
		# mueve: el centro se refresca por fotograma, en UV del lienzo.
		var cs := GameState.canvas_size()
		rush_mat.set_shader_parameter("center",
			Vector2(bobber.x / maxf(cs.x, 1.0), bobber.y / maxf(cs.y, 1.0)))
	# EN LA CLASE NO SE PIERDE: el sedal se queda a un pelo de romperse y la
	# presa a un pelo de soltarse, para que el susto se vea sin castigo.
	# EN LA CLASE NO SE PIERDE, PERO LAS BARRAS TIENEN QUE MOVERSE: con los
	# topes clavados a 0.93 el jugador soltaba, volvía a mantener y no veía
	# cambiar nada — leía el amaño como que el juego no le hacía caso (le pasó
	# al usuario). Se deja un margen de juego POR DEBAJO del tope para que el
	# gesto siempre tenga respuesta visible.
	if clase:
		tension = minf(tension, CLASE_TOPE)
		energy = minf(energy, CLASE_TOPE)
	if tutor and tutor_falta_tiron:
		# Ver `tutor_falta_tiron`: aguanta hasta la leccion del tiron. El suelo
		# va bastante por debajo del tope, así que entre uno y otro queda barra
		# de sobra que ver moverse.
		energy = maxf(energy, 0.12)
	if tension >= 1.0:
		GameState.bump_stat("fish_line_broken")
		_escaped("¡El sedal se ha roto!")
		return
	# Recuperada del todo, la presa se suelta del anzuelo y se va.
	if energy >= 1.0:
		GameState.bump_stat("fish_escaped")
		_escaped("¡Se ha escapado!")
		return
	if energy <= 0.0:
		_land_catch()


func _escaped(motivo: String) -> void:
	# El sedal roto tiene su latigazo; lo demas (se solto, se llevo el
	# cebo) es un chapoteo: no se ha roto nada.
	if snd != null:
		snd.todos_los_bucles_off()
		if motivo.contains("sedal"):
			snd.play("rotura", SND_EFECTO)
		else:
			snd.play("chapoteo", SND_EFECTO, PITCH_SUELTA)
	holding = false
	_set_rush(false)
	# EN EL TUTORIAL, un intento perdido no lo termina: lo repite. Se apunta
	# aqui porque este es el embudo de TODAS las formas de perder el pez.
	if tutor:
		tutor_perdido = true
	instruction.text = motivo
	_set_state(State.ESCAPED)
	zone.queue_redraw()
	var timer := get_tree().create_timer(1.6)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self) and state == State.ESCAPED:
			_set_state(State.READY))


## Captura lograda: AHORA se entrega el premio sorteado al empezar.
func _land_catch() -> void:
	# El pez sale del agua: chapoteo grave y ancho.
	if snd != null:
		snd.todos_los_bucles_off()
		snd.play("chapoteo", SND_EFECTO + 2.0, PITCH_COBRADO)
	holding = false
	_set_rush(false)
	instruction.text = ""
	_set_state(State.REVEAL)
	# EL TUTORIAL NO APUNTA NADA: es una practica con un pez de mentira,
	# asi que no toca el album, ni los records, ni el monedero, ni los
	# coleccionables. Solo se ensena el cartel y se sigue.
	if bool(roll.get("practica", false)):
		_show_fish_reveal({
			"type": "fish", "fish_id": str(roll.get("fish_id", "sardina")),
			"veces": 0, "size": float(roll.get("size", 0.3)),
			"practica": true,
		})
		return
	if str(roll.get("type", "")) == "fish":
		var premio := GameState.fishing_apply(roll)
		money_changed.emit()
		xp_gained.emit(int(premio.get("xp", 0)))
		_show_fish_reveal(premio)
	else:
		# El cofre NO se abre solo: sale CERRADO y lo abre el jugador. El
		# premio se entrega (y el coleccionable se anuncia con su ventana)
		# al terminar la animación de apertura, nunca antes.
		_show_chest_reveal()


# ------------------------------------------------------- entrada del jugador

func _on_zone_input(ev: InputEvent) -> void:
	# Solo eventos TÁCTILES: el ratón llega también como toque sintetizado
	# (emulate_touch_from_mouse), el patrón del resto del juego.
	if not (ev is InputEventScreenTouch):
		return
	if ev.pressed:
		match state:
			State.SHADOW:
				# Sin anzuelo en el agua, un toque LANZA; con él fuera, la
				# única salida es MANTENER para recogerlo.
				if casting:
					pass
				elif not bobber_out:
					_cast_to(ev.position)
				else:
					retrieving = true
			State.APPROACH, State.FEINT:
				# Tirar antes de tiempo espanta al pez: intento perdido.
				# MEDIDA DE SEGURIDAD: solo cuenta si YA ha intentado picar
				# al menos una vez — un toque nada más lanzar (o mientras se
				# acerca) se ignora y no cuesta el intento.
				if feints_done > 0:
					_escaped("¡Se ha asustado!")
			State.BITE:
				_start_fight()
			State.FIGHT:
				holding = true
				hold_time = 0.0
				if speed_left > 0.0:
					# El toque FRENA la subida (no baja la barra)...
					speed_relief = TAP_RELIEF
					# ...y también TENSA el sedal: pulsar a lo loco con la
					# barra roja alta lo rompe igual.
					tension = minf(tension + TAP_TENSION, 1.0)
				else:
					# CADA pulsación da un TIRÓN al sedal (fuera de la fase
					# de velocidad). Es lo que impide recoger a base de
					# toquecitos: el pico se acumula y revienta el sedal.
					tension = minf(tension + TAP_TENSION_KICK, 1.0)
	else:
		retrieving = false
		if snd != null:
			snd.loop_off("recoger")
		if state == State.FIGHT:
			holding = false


# --------------------------------------------- sombra, sedal y flotador

func _draw_sea() -> void:
	var con_sombra := state == State.SHADOW or state == State.APPROACH \
		or state == State.FEINT or state == State.BITE or state == State.FIGHT
	if not con_sombra:
		return
	# La SOMBRA: silueta de PEZ vista desde arriba (cuerpo, cola y aletas),
	# orientada a su rumbo y más grande cuanto mejor el botín (la pista de
	# rareza del jugador). En la pelea tiembla bajo el anzuelo. Se pinta dos
	# veces: un halo grande difuso y la silueta encima.
	var spos := shadow_pos
	if state == State.FIGHT:
		# Enganchado: DEBAJO de la boya, tirando mar adentro (de espaldas al
		# barco), y viaja con ella por el sedal.
		heading = (bobber - rod_tip).angle()
		spos = bobber + Vector2(0.0, _fish_r() * 0.55 + 10.0) \
			+ Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0))
	var r := _fish_r()
	_draw_fish(spos, heading, r * 1.22, Color(0.02, 0.05, 0.09, 0.16))
	_draw_fish(spos, heading, r, Color(0.02, 0.05, 0.09, 0.38))
	if not bobber_out:
		return
	# El SEDAL: comba en reposo, tenso en la pelea; durante el vuelo sigue al
	# flotador.
	var pos := bobber
	if state == State.BITE:
		pos += Vector2(0.0, bite_sink)
	elif state == State.FEINT and feint_anim > 0.0:
		pos += Vector2(0.0, FEINT_DIP * sin(feint_anim / FEINT_ANIM * PI))
	elif state == State.FIGHT:
		pos += Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0))
	var sag := 10.0 if state == State.FIGHT or casting else 56.0
	var mid := (rod_tip + pos) * 0.5 + Vector2(0.0, sag)
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		var a := rod_tip.lerp(mid, t)
		var b := mid.lerp(pos, t)
		pts.append(a.lerp(b, t))
	zone.draw_polyline(pts, Color(0.93, 0.93, 0.88, 0.85), 2.4, true)
	# Ondas: al picar (crecen con la ventana) y chapoteo en la pelea.
	if state == State.BITE:
		var k := 1.0 - bite_t / BITE_WINDOW
		zone.draw_arc(pos, 20.0 + k * 46.0, 0.0, TAU, 28,
			Color(1, 1, 1, 0.75 * (1.0 - k)), 3.0, true)
	elif state == State.FIGHT:
		var k2 := fmod(_t * 1.4, 1.0)
		zone.draw_arc(pos, 16.0 + k2 * 30.0, 0.0, TAU, 24,
			Color(1, 1, 1, 0.5 * (1.0 - k2)), 2.5, true)
	# El FLOTADOR: bola roja con casquete blanco; hundido en la picada.
	var alpha := 0.55 if state == State.BITE else 1.0
	zone.draw_circle(pos, 17.0, Color(0.16, 0.10, 0.06, alpha))
	zone.draw_circle(pos, 15.0, Color(0.88, 0.22, 0.16, alpha))
	zone.draw_circle(pos + Vector2(0, -6.5), 7.5, Color(0.96, 0.94, 0.88, alpha))
	if state == State.BITE:
		_dibujar_picada(pos)


## EL "!" DE LA PICADA, sobre el anzuelo (pedido por el usuario). El rótulo de
## "¡Ha picado!" vive abajo, en la franja de instrucciones, y en el segundo que
## dura la ventana el jugador está mirando el flotador, no el pie de pantalla.
## Se DIBUJA (bocadillo redondo + barra + punto), no es un asset: son cuatro
## primitivas y así late con la ventana que se agota.
func _dibujar_picada(pos: Vector2) -> void:
	# Crece de golpe y se queda: la urgencia la marca el aro de ondas, que ya
	# se abre con la cuenta atrás.
	var k: float = clampf((BITE_WINDOW - bite_t) / 0.10, 0.0, 1.0)
	var salto := 1.0 + 0.12 * sin(_t * 18.0)
	var c := pos + Vector2(0.0, -94.0 - 10.0 * k)
	var r := 30.0 * k * salto
	if r < 1.0:
		return
	zone.draw_circle(c, r + 3.0, Color(0.16, 0.10, 0.06, 0.9))
	zone.draw_circle(c, r, Color(1.0, 0.84, 0.22, 0.98))
	# El rabito del bocadillo, apuntando al flotador.
	zone.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 0.42, r * 0.72), c + Vector2(r * 0.42, r * 0.72),
		c + Vector2(0.0, r * 1.72)]), Color(1.0, 0.84, 0.22, 0.98))
	# La admiración: barra y punto.
	var tinta := Color(0.22, 0.12, 0.04)
	zone.draw_rect(Rect2(c + Vector2(-r * 0.16, -r * 0.62),
		Vector2(r * 0.32, r * 0.78)), tinta)
	zone.draw_circle(c + Vector2(0.0, r * 0.44), r * 0.17, tinta)


## La silueta del pez, construida a lo largo de +x y girada a `ang`: cuerpo
## fusiforme (elipse), cola en abanico y aletas pectorales a los lados.
func _draw_fish(pos: Vector2, ang: float, r: float, col: Color) -> void:
	zone.draw_set_transform(pos, ang, Vector2.ONE)
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * r * 1.25, sin(a) * r * 0.52))
	zone.draw_colored_polygon(pts, col)
	var tail := PackedVector2Array([
		Vector2(-r * 1.0, 0.0), Vector2(-r * 1.85, -r * 0.6),
		Vector2(-r * 1.6, 0.0), Vector2(-r * 1.85, r * 0.6)])
	zone.draw_colored_polygon(tail, col)
	var fin_l := PackedVector2Array([
		Vector2(r * 0.25, -r * 0.4), Vector2(-r * 0.35, -r * 0.95),
		Vector2(-r * 0.45, -r * 0.35)])
	zone.draw_colored_polygon(fin_l, col)
	var fin_r := PackedVector2Array([
		Vector2(r * 0.25, r * 0.4), Vector2(-r * 0.35, r * 0.95),
		Vector2(-r * 0.45, r * 0.35)])
	zone.draw_colored_polygon(fin_r, col)
	zone.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------- carteles del botín

func _reveal_panel(alto: float) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.45)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(veil)
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -260.0
	panel.offset_right = 260.0
	panel.offset_top = -alto * 0.5
	panel.offset_bottom = alto * 0.5
	panel.pivot_offset = Vector2(260.0, alto * 0.5)
	overlay.add_child(panel)
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))
	panel.scale = Vector2(0.7, 0.7)
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	return panel


## Botón de cerrar del cartel. Si la captura traía un PEZ LAPA pegado, al
## cerrar NO se vuelve a la pesca: sale su cartel sorpresa (`premio` lleva
## `lapa_coins`), que es lo que hace que la lapa se descubra DESPUÉS.
func _reveal_close_button(panel: Control, overlay_alto: float,
		premio := {}) -> void:
	var seguir := Button.new()
	seguir.text = "Continuar"
	PrepBoard.skin_button(seguir)
	seguir.add_theme_font_size_override("font_size", 26)
	seguir.set_anchors_preset(Control.PRESET_TOP_WIDE)
	seguir.offset_left = 140.0
	seguir.offset_right = -140.0
	seguir.offset_top = overlay_alto - 98.0
	seguir.offset_bottom = overlay_alto - 32.0
	panel.add_child(seguir)
	seguir.pressed.connect(func() -> void:
		panel.get_parent().queue_free()
		if premio.has("lapa_coins"):
			_show_lapa_reveal(premio)
		else:
			_set_state(State.READY))


## LA SORPRESA DEL PEZ LAPA: se descubre al cerrar el cartel de la captura,
## nunca antes — venía pegado al pez y nadie lo había visto.
func _show_lapa_reveal(premio: Dictionary) -> void:
	var alto := 620.0
	var panel := _reveal_panel(alto)
	var title := PrepBoard.make_big_title("¡Venía\nacompañado!", 42)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 34.0
	title.offset_bottom = 150.0
	panel.add_child(title)

	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = FishData.get_icon("pez_lapa")
	ic.position = Vector2((520.0 - 170.0) * 0.5, 160.0)
	ic.size = Vector2(170, 170)
	ic.pivot_offset = Vector2(85, 85)
	panel.add_child(ic)
	ic.scale = Vector2(0.2, 0.2)
	create_tween().tween_property(ic, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.1)

	var ls := float(premio.get("lapa_size", 0.5))
	_centered_label(panel, "Pez lapa", 34, 350.0)
	_centered_label(panel, "Iba pegado a tu captura  ·  %s"
		% FishData.size_text("pez_lapa", ls), 21, 396.0, FADED)
	_centered_label(panel, "+%d doblones" % int(premio["lapa_coins"]),
		26, 436.0, Color(0.2, 0.45, 0.12))
	var veces := int(GameState.fish_album.get("pez_lapa", 1))
	if veces > 1:
		_centered_label(panel, "Pescado " + FishData.times_text(veces),
			19, 480.0, FADED)
	_reveal_close_button(panel, alto)


func _centered_label(panel: Control, texto: String, size_f: int, y: float,
		color := DARK) -> Label:
	var l := Label.new()
	l.text = texto
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = y
	l.offset_bottom = y + size_f * 1.6
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size_f)
	l.add_theme_color_override("font_color", color)
	panel.add_child(l)
	return l


func _show_fish_reveal(premio: Dictionary) -> void:
	# El cartel de la captura. El chapoteo del pez saliendo del agua ya lo ha
	# puesto `_cobrar`; esto es la ficha, y suena a premio.
	Audio.sfx("premio")
	var fish_id := str(premio["fish_id"])
	# LA FICHA DEL BICHO VA TAMBIÉN AQUÍ, no solo en el álbum: al sacarlo del
	# agua es cuando el jugador quiere saber qué acaba de pescar. El cartel
	# CRECE con el texto (se estima por caracteres: medirlo de verdad pide un
	# fotograma y el cartel se monta ya colocado).
	var ficha := str(FishData.get_fish(fish_id).get("desc", ""))
	var ficha_h := 0.0
	if ficha != "":
		ficha_h = clampf(ceili(ficha.length() / 42.0) * 28.0 + 10.0, 38.0, 152.0)
	var alto := 700.0 + ficha_h
	var panel := _reveal_panel(alto)
	var rareza := FishData.rarity_of(fish_id)
	var title := PrepBoard.make_big_title("¡Pescado!", 52)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 40.0
	title.offset_bottom = 120.0
	panel.add_child(title)

	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = FishData.get_icon(fish_id)
	ic.position = Vector2((520.0 - 190.0) * 0.5, 138.0)
	ic.size = Vector2(190, 190)
	ic.pivot_offset = Vector2(95, 95)
	panel.add_child(ic)
	ic.scale = Vector2(0.2, 0.2)
	create_tween().tween_property(ic, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)

	_centered_label(panel, str(FishData.get_fish(fish_id).get("name", fish_id)),
		34, 340.0)
	# Rareza + la TALLA de este ejemplar (el tamaño decide sus doblones), en
	# su unidad: centímetros, o número de calzado para la bota. La lata y la
	# rueda no tienen talla y solo enseñan la rareza.
	var size := float(premio.get("size", 0.5))
	var talla := FishData.size_text(fish_id, size)
	var linea := str(rareza.get("name", ""))
	if talla != "":
		linea += " · " + talla
	_centered_label(panel, linea, 24, 386.0,
		Color(rareza.get("color", Color.GRAY)))
	# La FICHA del álbum, entre la rareza y el premio.
	var y := 426.0
	if ficha != "":
		var f := Label.new()
		f.text = ficha
		f.set_anchors_preset(Control.PRESET_TOP_WIDE)
		f.offset_left = 44.0
		f.offset_right = -44.0
		f.offset_top = 424.0
		f.offset_bottom = 424.0 + ficha_h
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		f.add_theme_font_size_override("font_size", 20)
		f.add_theme_color_override("font_color", Color(0.30, 0.20, 0.10))
		panel.add_child(f)
		y = 424.0 + ficha_h + 8.0
	# Las líneas del premio: usos de despensa (peces-ingrediente, siempre) y
	# monedas por tamaño (desde la 2ª captura). La 1ª de un pez sin
	# ingrediente es el descubrimiento y lo dice.
	if premio.has("ingredient"):
		var data: Dictionary = RecipeData.INGREDIENTS.get(
			premio["ingredient"], {})
		_centered_label(panel, "+%d usos de %s" % [int(premio["uses"]),
			str(data.get("name", premio["ingredient"]))], 26, y,
			Color(0.2, 0.45, 0.12))
		y += 40.0
	if premio.has("coins"):
		_centered_label(panel, "+%d doblones" % int(premio["coins"]), 26, y,
			Color(0.2, 0.45, 0.12))
		y += 40.0
	if bool(premio.get("practica", false)):
		_centered_label(panel, "Práctica: esta no cuenta", 24, y, FADED)
		y += 40.0
	elif not premio.has("ingredient") and not premio.has("coins"):
		_centered_label(panel, "¡Nuevo en el álbum!", 26, y,
			Color(0.2, 0.45, 0.12))
		y += 40.0
	# (El PEZ LAPA que venía pegado NO se menciona aquí: es una sorpresa y
	# sale en su propio cartel al cerrar este, ver `_reveal_close_button`.)
	var veces := int(premio.get("veces", 1))
	if veces > 1:
		_centered_label(panel, "Pescado " + FishData.times_text(veces),
			19, y, FADED)
	_reveal_close_button(panel, alto, premio)


## El cartel del COFRE: sale CERRADO y con un botón "¡Abrir!". El premio del
## `roll` no se entrega hasta que el jugador lo abre (ver el botón), así que
## la ventana del coleccionable llega DESPUÉS de ver el cofre abrirse.
func _show_chest_reveal() -> void:
	Audio.sfx("recurso")
	var alto := 620.0
	var panel := _reveal_panel(alto)
	var title := PrepBoard.make_big_title("¡Un cofre\ndel mar!", 44)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 34.0
	title.offset_bottom = 150.0
	panel.add_child(title)

	# El cofre del bonus diario, CERRADO y meciéndose: lo abre el jugador.
	var cofre := TextureRect.new()
	cofre.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cofre.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cofre.texture = load("res://assets/ui/daily_cofre.png")
	cofre.position = Vector2((520.0 - 170.0) * 0.5, 160.0)
	cofre.size = Vector2(170, 170)
	cofre.pivot_offset = Vector2(85, 100)
	panel.add_child(cofre)
	var espera := create_tween().set_loops()
	espera.tween_property(cofre, "rotation_degrees", 4.0, 0.5) \
		.set_trans(Tween.TRANS_SINE)
	espera.tween_property(cofre, "rotation_degrees", -4.0, 0.5) \
		.set_trans(Tween.TRANS_SINE)

	# El botín va en esta fila, vacía hasta que se abra el cofre.
	var fila := HBoxContainer.new()
	fila.set_anchors_preset(Control.PRESET_TOP_WIDE)
	fila.offset_left = 60.0
	fila.offset_right = -60.0
	fila.offset_top = 360.0
	fila.offset_bottom = 500.0
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 14)
	panel.add_child(fila)
	var pista := _centered_label(panel, "¿Qué habrá dentro?", 24, 386.0, FADED)

	# El botón hace DOS papeles: primero abre el cofre y después cierra el
	# cartel. La caja `estado` es un diccionario porque las lambdas de
	# GDScript capturan por VALOR: un bool suelto no se vería mutado.
	var estado := { "abierto": false }
	var btn := Button.new()
	btn.text = "¡Abrir!"
	PrepBoard.skin_button(btn)
	btn.add_theme_font_size_override("font_size", 26)
	btn.set_anchors_preset(Control.PRESET_TOP_WIDE)
	btn.offset_left = 140.0
	btn.offset_right = -140.0
	btn.offset_top = alto - 98.0
	btn.offset_bottom = alto - 32.0
	panel.add_child(btn)
	btn.pressed.connect(func() -> void:
		if estado["abierto"]:
			panel.get_parent().queue_free()
			_set_state(State.READY)
			return
		estado["abierto"] = true
		# La tapa del cofre. Va aquí, en la pulsación que lo ABRE, y no en la
		# que cierra el cartel: el botón hace los dos papeles.
		Audio.sfx("cofre_llave")
		Audio.sfx("cofre")
		espera.kill()
		btn.disabled = true
		PrepBoard.set_dimmed(btn, true)
		# SE ESCONDE, NO SE LIBERA. Este botón hace DOS papeles y su lambda se
		# llama dos veces; Godot resuelve TODAS las capturas en cada llamada,
		# así que con la pista liberada en la primera pulsación, la segunda
		# soltaba un "Lambda capture at index 4 was freed". No rompía nada —esa
		# rama ni la toca— pero es un error en la consola por un nodo que de
		# todas formas muere con el cartel.
		pista.visible = false
		var tw := create_tween()
		tw.tween_property(cofre, "rotation_degrees", 9.0, 0.08)
		tw.tween_property(cofre, "rotation_degrees", -9.0, 0.08)
		tw.tween_property(cofre, "rotation_degrees", 6.0, 0.07)
		tw.tween_property(cofre, "rotation_degrees", 0.0, 0.07)
		tw.tween_callback(func() -> void:
			cofre.texture = load("res://assets/ui/daily_cofre_abierto.png"))
		tw.tween_callback(func() -> void:
			snd.play("cebo", SND_EFECTO + 2.0, 0.9))
		tw.tween_property(cofre, "scale", Vector2(1.12, 1.12), 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(cofre, "scale", Vector2.ONE, 0.12)
		# Y SOLO ENTONCES se entrega el premio: si es un coleccionable, su
		# ventana sale AHORA, con el cofre ya abierto detrás.
		tw.tween_callback(func() -> void:
			var premio := GameState.fishing_apply(roll)
			money_changed.emit()
			_fill_chest_loot(fila, premio)
			btn.text = "Continuar"
			btn.disabled = false
			PrepBoard.set_dimmed(btn, false)))


## Pinta el botín dentro del cartel del cofre YA ABIERTO. Sin fundido a
## propósito: el coleccionable pausa el árbol con su ventana y un tween aquí
## se quedaría congelado a medias.
func _fill_chest_loot(fila: HBoxContainer, premio: Dictionary) -> void:
	# LA PRIMERA VEZ QUE SALE UN COLECCIONABLE, Cai explica qué es. Aquí y no
	# en el menú: es el momento en que el jugador tiene la pieza delante.
	if str(premio.get("kind", "")) == "collectible" and not GameState.col_intro_done:
		_cai_explica_coleccion.call_deferred()
	var texto := ""
	var icon_tex: Texture2D = null
	match str(premio.get("kind", "")):
		"coins":
			texto = "+%d doblones" % int(premio["coins"])
			icon_tex = load("res://assets/ui/moneda.png")
		"collectible":
			texto = "¡Coleccionable!\n%s" \
				% CollectibleData.item_name(str(premio["collectible"]))
			icon_tex = CollectibleData.get_icon(str(premio["collectible"]))
		"dup":
			texto = "%s...\n¡ya lo tenías! +%d doblones" \
				% [CollectibleData.item_name(str(premio["collectible"])),
					int(premio["coins"])]
			icon_tex = CollectibleData.get_icon(str(premio["collectible"]))
		"triforce":
			texto = "Fragmento del triángulo dorado\n(%d/%d)" \
				% [int(premio["pieces"]), CollectibleData.TRIFORCE_PIECES]
			icon_tex = CollectibleData.get_icon("trifuerza")
		"dup_triforce":
			texto = "El triángulo ya está completo:\n+%d doblones" \
				% int(premio["coins"])
			icon_tex = load("res://assets/ui/moneda.png")
		"recipe":
			texto = "¡Receta nueva!\n%s" % str(RecipeData.RECIPES.get(
				premio["recipe"], {}).get("name", premio["recipe"]))
			icon_tex = RecipeData.get_dish_texture(str(premio["recipe"]))

	if icon_tex != null:
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = icon_tex
		ic.custom_minimum_size = Vector2(96, 96)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fila.add_child(ic)
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(280, 0)
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", DARK)
	fila.add_child(l)


# ------------------------------------------------------------------- álbum

func _open_album() -> void:
	if state != State.READY:
		return
	album_abierto.emit(true)
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.5)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(veil)

	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 20.0
	panel.offset_right = -20.0
	panel.offset_top = 110.0 + GameState.safe_top()
	panel.offset_bottom = -36.0 - GameState.safe_bottom()
	overlay.add_child(panel)
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))

	# Se cuentan las especies DEL CATÁLOGO, no las claves del guardado: un id
	# renombrado dejaría una entrada huérfana y el contador se pasaría.
	var pescados := FishData.caught_count(GameState.fish_album)
	var title := PrepBoard.make_title("Álbum: %d/%d" % [pescados,
		FishData.total()])
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 90.0
	title.offset_right = -90.0
	title.offset_top = -26.0
	panel.add_child(title)

	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 48.0
	scroll.offset_top = 66.0
	scroll.offset_right = -48.0
	scroll.offset_bottom = -108.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	for f in FishData.FISH:
		grid.add_child(_album_cell(str(f["id"]), overlay))

	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	PrepBoard.skin_button(cerrar)
	cerrar.add_theme_font_size_override("font_size", 24)
	cerrar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	cerrar.offset_left = 160.0
	cerrar.offset_right = -160.0
	cerrar.offset_top = -96.0
	cerrar.offset_bottom = -34.0
	panel.add_child(cerrar)
	cerrar.pressed.connect(func() -> void:
		album_abierto.emit(false)
		overlay.queue_free())


func _album_cell(fish_id: String, overlay: Control) -> Control:
	var caught := GameState.fish_album.has(fish_id)
	var cell := Button.new()
	cell.custom_minimum_size = Vector2(136, 150)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		cell.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(col)
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = FishData.get_icon(fish_id)
	ic.custom_minimum_size = Vector2(104, 104)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not caught:
		# Silueta oscura y sin nombre: como la vitrina de coleccionables, el
		# álbum no desvela lo que queda por pescar.
		ic.modulate = Color(0.12, 0.10, 0.09, 0.85)
	col.add_child(ic)
	var l := Label.new()
	l.text = str(FishData.get_fish(fish_id).get("name", fish_id)) \
		if caught else "???"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", DARK if caught else FADED)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(l)
	if caught:
		cell.pressed.connect(func() -> void: _open_ficha(fish_id, overlay))
	return cell


func _open_ficha(fish_id: String, album_overlay: Control) -> void:
	var rareza := FishData.rarity_of(fish_id)
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.45)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	album_overlay.add_child(veil)
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -234.0
	panel.offset_right = 234.0
	panel.offset_top = -320.0
	panel.offset_bottom = 320.0
	veil.add_child(panel)
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = FishData.get_icon(fish_id)
	ic.position = Vector2((468.0 - 150.0) * 0.5, 38.0)
	ic.size = Vector2(150, 150)
	panel.add_child(ic)
	_centered_label(panel, str(FishData.get_fish(fish_id).get("name", fish_id)),
		32, 194.0)
	_centered_label(panel, str(rareza.get("name", "")), 22, 236.0,
		Color(rareza.get("color", Color.GRAY)))
	# LA DESCRIPCIÓN: qué es el bicho. Es lo que llena la ficha, así que se
	# le da todo el hueco del centro.
	var ficha := _centered_label(panel,
		str(FishData.get_fish(fish_id).get("desc", "")), 18, 276.0, DARK)
	ficha.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ficha.offset_left = 44.0
	ficha.offset_right = -44.0
	ficha.offset_bottom = 276.0 + 132.0
	ficha.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var premio := _centered_label(panel, FishData.reward_text(fish_id),
		21, 414.0, Color(0.2, 0.45, 0.12))
	premio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	premio.offset_left = 40.0
	premio.offset_right = -40.0
	premio.offset_bottom = 414.0 + 60.0
	# El RÉCORD: la ficha enseña el mayor ejemplar pescado de la especie (en
	# su unidad; la lata y la rueda no tienen talla y solo llevan la cuenta).
	var best := float(GameState.fish_best.get(fish_id, 0.0))
	var veces := int(GameState.fish_album.get(fish_id, 0))
	var pie := "Pescado " + FishData.times_text(veces)
	var record := FishData.size_text(fish_id, best)
	if record != "":
		pie = "Récord: %s  ·  %s" % [record, pie]
	_centered_label(panel, pie, 19, 478.0, FADED)
	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	PrepBoard.skin_button(cerrar)
	cerrar.add_theme_font_size_override("font_size", 24)
	cerrar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	cerrar.offset_left = 130.0
	cerrar.offset_right = -130.0
	cerrar.offset_top = 528.0
	cerrar.offset_bottom = 590.0
	panel.add_child(cerrar)
	cerrar.pressed.connect(func() -> void: veil.queue_free())


# ============================================================== CAI Y SU CLASE
#
# CAI, el pescador de la Isla de Gades, es la voz de esta pantalla: da la clase
# la primera vez y saluda y se despide cada visita. Habla poco y mal (solo sabe
# japonés), así que sus frases son cortas, con fallos de concordancia y sin
# artículos — no es un descuido de escritura, es su acento.

## SALUDOS al entrar a pescar. Se sortea uno y no se repite el anterior.
const CAI_SALUDOS: Array = [
	"Mar tranquilo hoy. Bueno para pescar.",
	"Ah. Cocinero. Tú vienes. Bien.",
	"Hoy pican. Yo lo huelo.",
	"Agua fría. Peces con hambre.",
	"Silencio. Pez escucha ruido.",
	"Caña lista. Manos tuyas.",
	"Yo miro. Tú pescas.",
	"Pescado grande hoy, quizá. Quizá no. Mar decide.",
	"Buen día. Mucha agua, mucho pez.",
	"...  Ah. Perdona. Yo pensaba en pez.",
]
## DESPEDIDAS al salir.
const CAI_DESPEDIDAS: Array = [
	"Vuelve. Pez espera.",
	"Buen brazo. Mejor cada día.",
	"Yo guardo caña. Tú guardas pescado.",
	"Mar te recuerda. Vuelve pronto.",
	"Hasta luego, cocinero.",
	"Hoy suficiente. Mañana más.",
	"...  Adiós.",
	"Cuidado con sedal. Sedal enfada rápido.",
	"Yo aquí. Siempre aquí.",
	"Come bien. Pesca mejor.",
]
## La última frase dicha, para no repetirla dos veces seguidas.
static var _cai_ultima := ""

## Tiradas que regala Cai al acabar su clase.
const CAI_TIRADAS_GRATIS := 3


static func _cai_frase(saco: Array) -> String:
	var f: String = str(saco.pick_random())
	if f == _cai_ultima and saco.size() > 1:
		f = str(saco.pick_random())
	_cai_ultima = f
	return f


## Caja de diálogo de Cai sobre la pantalla de pesca. Sin velo propio: aquí lo
## pone la propia clase cuando hace falta señalar algo.
func _cai_caja() -> DialogueBox:
	var caja := DialogueBox.new()
	caja.z_index = 220
	add_child(caja)
	return caja


## Saludo de entrada (o la CLASE, la primera vez).
func _cai_entrada() -> void:
	if not GameState.fishing_intro_done:
		await _clase_de_pesca()
		return
	var caja := _cai_caja()
	caja.say([{ "text": _cai_frase(CAI_SALUDOS), "who": "cai", "mood": "serio" }])
	await caja.finished
	await caja.close_and_free()


## Despedida al salir. La llama el botón "Atrás" antes de cerrar la pantalla.
func _cai_salida() -> void:
	if not GameState.fishing_intro_done:
		return
	var caja := _cai_caja()
	caja.say([{ "text": _cai_frase(CAI_DESPEDIDAS), "who": "cai", "mood": "serio" }])
	await caja.finished
	await caja.close_and_free()


## Velo oscuro con UN control por encima (mismo apaño que las guías del menú: el
## z_index no cambia quién recibe el toque, pero aquí el velo se lo traga todo a
## propósito — durante la clase no se juega).
## Con `pasa_toques` el velo NO se traga la pulsacion. Hace falta cuando lo
## que se explica se juega DEBAJO del velo: en la leccion de la pelea el foco
## cae sobre la cana mientras el jugador tiene que seguir pulsando el agua, y
## con el velo tragandose los toques la barra del sedal no subia ni la de la
## presa bajaba hasta que el tutorial pasaba de paso. Pasaba de verdad, y se
## vivia como que el juego se habia quedado tonto: el primer aguante SI valia
## —lo enciende `_start_fight`, no el jugador— y ninguno de los siguientes.
func _foco_pesca(nodo: Control, pasa_toques := false) -> ColorRect:
	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0.7)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.z_index = 150
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE if pasa_toques \
			else Control.MOUSE_FILTER_STOP
	velo.modulate.a = 0.0
	add_child(velo)
	velo.create_tween().tween_property(velo, "modulate:a", 1.0, 0.25)
	if nodo != null and is_instance_valid(nodo):
		nodo.z_index = 180
		# Y SE SUBE AL FINAL DEL ARBOL: el z_index solo cambia el orden de
		# DIBUJADO, no quien recibe el toque — el picking va por orden de
		# arbol, asi que el velo (anadido despues) se tragaba la pulsacion
		# y el boton enfocado no respondia. Es la misma trampa del velo
		# del menu, ya documentada en CLAUDE.md.
		nodo.set_meta("foco_idx", nodo.get_index())
		nodo.get_parent().move_child(nodo, -1)
	return velo


func _quitar_foco(velo: ColorRect, nodo: Control, z: int) -> void:
	if nodo != null and is_instance_valid(nodo):
		nodo.z_index = z
		if nodo.has_meta("foco_idx"):
			nodo.get_parent().move_child(nodo, int(nodo.get_meta("foco_idx")))
			nodo.remove_meta("foco_idx")
	if velo == null or not is_instance_valid(velo):
		return
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := velo.create_tween()
	tw.tween_property(velo, "modulate:a", 0.0, 0.22)
	tw.tween_callback(velo.queue_free)
## LA CLASE DE PESCA, DE PRACTICA. Cai no suelta la teoria de un tiron: dice UNA
## cosa, se quita de en medio y el jugador la HACE; solo entonces viene la
## siguiente. Cada leccion se cierra sola cuando el jugador cumple, asi que no
## hay forma de quedarse escuchando sin tocar nada.
##
## EL INTENTO VA AMANADO (`clase`): el pez es el mas facil que existe, el sedal
## perdona, el pez no se escapa y hay UNA fase de velocidad GARANTIZADA y floja
## — porque el tiron es lo unico que no se puede explicar sin verlo, y en una
## partida normal puede no salir. Cai paga la clase, asi que tampoco cuesta
## doblones. Al acabar deja `CAI_TIRADAS_GRATIS` lanzamientos gratis.
func _clase_de_pesca() -> void:
	GameState.fishing_intro_done = true
	GameState.bait = maxi(GameState.bait, CAI_TIRADAS_GRATIS)
	GameState.save_game()
	clase = true
	_refresh_cast_label()

	await _leccion([
		{ "text": "Yo enseño poco. Tú haces mucho. Asi se aprende.", "who": "cai", "mood": "serio" },
		{ "text": "Hoy pago yo. Tú mira y toca.", "who": "cai", "mood": "hablando" },
	])

	# 1) EL BOTON. Se enfoca y no se sigue hasta que lo pulsa.
	var z_btn := cast_btn.z_index
	var velo := _foco_pesca(cast_btn)
	await _leccion([
		{ "text": "Esto es caña. Tocas ahí y empieza. Tócalo.", "who": "cai", "mood": "hablando" },
	])
	_quitar_foco(velo, cast_btn, z_btn)

	# EL INTENTO SE REPITE SI SALE MAL. Con todo congelado mientras Cai habla no
	# deberia escaparse ninguno, pero si pasa, la clase NO se queda a medias:
	# Cai se encoge de hombros y se vuelve a empezar. Antes se cortaba ahi y el
	# jugador se quedaba sin aprender la pelea.
	var intentos := 0
	while intentos < CLASE_INTENTOS:
		intentos += 1
		if state != State.READY:
			await _esperar_pesca(func() -> bool: return state == State.READY, 12.0)
		if intentos > 1:
			await _leccion([
				{ "text": "Se fue. Pasa. Otra vez.", "who": "cai", "mood": "callado" },
			])
		await _tutor_espera(func() -> bool: return state != State.READY)

		# 2) LA SOMBRA. Que la vea nadar y lance por delante.
		await _leccion([
			{ "text": "Eso es **sombra**. Sombra grande, premio grande.", "who": "cai", "mood": "hablando" },
			{ "text": "Tocas agua **delante** de sombra. No encima. Prueba.", "who": "cai", "mood": "serio" },
		])
		await _esperar_pesca(func() -> bool: return bobber_out or state == State.READY)
		if state == State.READY:
			continue

		# 3) LA FINTA Y LA PICADA, avisadas ANTES de que el pez amague.
		await _leccion([
			{ "text": "Ahora espera. Pez hace trampa: viene, se va. Eso no es picada.", "who": "cai", "mood": "hablando" },
			{ "text": "Picada de verdad: flotador se **hunde**. Ahí tocas, rápido.", "who": "cai", "mood": "sorprendido" },
		])
		await _esperar_pesca(func() -> bool:
			return state == State.FIGHT or state == State.READY or state == State.ESCAPED)
		if state != State.FIGHT:
			continue

		# 4) LA PELEA. Foco en la caña y a recoger de verdad.
		var z_cana := fight_box.z_index if fight_box != null else 0
		velo = _foco_pesca(fight_box)
		await _leccion([
			{ "text": "Enganchado. Dos barras: **sedal** y **fuerza de pez**.", "who": "cai", "mood": "serio" },
			{ "text": "Aprietas y **mantienes**: pez se cansa. Sedal rojo, sueltas.", "who": "cai", "mood": "hablando" },
		])
		_quitar_foco(velo, fight_box, z_cana)
		await _esperar_pesca(func() -> bool:
			return energy <= 0.55 or state != State.FIGHT)
		if state != State.FIGHT:
			continue

		# 5) EL TIRON. Se provoca AQUI para que Cai lo explique con el delante.
		speed_next = 0.0
		await _esperar_pesca(func() -> bool:
			return speed_left > 0.0 or state != State.FIGHT)
		if state != State.FIGHT:
			continue
		await _leccion([
			{ "text": "¡Corre! Ahora no mantienes. Ahora **tocas rápido**.", "who": "cai", "mood": "sorprendido" },
		])
		await _esperar_pesca(func() -> bool:
			return speed_left <= 0.0 or state != State.FIGHT)

		# 6) EL REMATE.
		if state == State.FIGHT:
			await _leccion([
				{ "text": "Ya pasó. Aprieta otra vez. Acaba tú.", "who": "cai", "mood": "hablando" },
			])
		await _esperar_pesca(func() -> bool:
			return state == State.REVEAL or state == State.READY or state == State.ESCAPED)
		if state == State.REVEAL:
			break

	clase = false
	_refresh_cast_label()
	await _leccion([
		{ "text": "Eso. Ya sabes pescar.", "who": "cai", "mood": "feliz" },
		{ "text": "Tres tiradas mías. Regalo. Después pagas tú.", "who": "cai", "mood": "hablando" },
	])


## Una leccion: Cai dice lo suyo y SE QUITA. La caja se traga todos los toques
## mientras esta puesta, asi que no puede quedarse en pantalla mientras el
## jugador practica: se monta una por leccion y se cierra al acabarla.
func _leccion(lineas: Array) -> void:
	# LA PELEA SE PARA MIENTRAS CAI HABLA. La caja se traga todos los toques,
	# asi que con el pez enganchado el jugador no puede hacer NADA mientras
	# lee — y el tiron seguia corriendo: medido, la presa se soltaba durante
	# la propia frase que explicaba como aguantarla.
	leccion_en_curso = true
	var caja := _cai_caja()
	caja.say(lineas)
	await caja.finished
	await caja.close_and_free()
	leccion_en_curso = false


## Espera a que se cumpla algo del minijuego sin bloquear el juego (el jugador
## tiene que poder tocar). Con tope: si algo se tuerce, la clase sigue en vez
## de dejar al jugador encerrado sin poder salir.
func _esperar_pesca(cond: Callable, tope := 90.0) -> void:
	var t := 0.0
	while is_inside_tree() and t < tope and not bool(cond.call()):
		t += get_process_delta_time()
		await get_tree().process_frame


## El botón de pescar dice GRATIS mientras queden tiradas de regalo de Cai: si
## siguiera enseñando el precio, el jugador creería que le están cobrando.
func _refresh_cast_label() -> void:
	if cast_cost_label == null or not is_instance_valid(cast_cost_label):
		return
	# EN LA CLASE PAGA CAI: ni precio ni moneda, solo lo que hay que hacer.
	if cast_coin != null and is_instance_valid(cast_coin):
		cast_coin.visible = not clase
	if clase:
		cast_cost_label.text = "Lanzar caña"
	elif GameState.bait > 0:
		# Con CEBO no se cobra: el botón enseña el cebo en vez de la moneda,
		# para que se vea de dónde sale la tirada gratis.
		if cast_coin != null and is_instance_valid(cast_coin):
			cast_coin.texture = load("res://assets/ui/ic_cebo.png")
		cast_cost_label.text = "x%d" % GameState.bait
	else:
		if cast_coin != null and is_instance_valid(cast_coin):
			cast_coin.texture = load("res://assets/ui/moneda.png")
		cast_cost_label.text = "%d" % FishData.FISHING_COST


## Cai explica los COLECCIONABLES la primera vez que sale uno del cofre. Espera
## a que la ventana modal de la pieza se cierre: si hablara encima, se pisarían
## dos carteles.
func _cai_explica_coleccion() -> void:
	if GameState.col_intro_done:
		return
	GameState.col_intro_done = true
	GameState.save_game()
	while get_tree().paused:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	var caja := _cai_caja()
	caja.say([
		{ "text": "Eso no se come. Eso se **guarda**.", "who": "cai", "mood": "serio" },
		{ "text": "**Coleccionables**. Mar los esconde, gente los pierde. Tú los encuentras.", "who": "cai", "mood": "hablando" },
		{ "text": "No dan oro. No dan comida. Solo... están. En vitrina de tu camarote, en **Inventario**.", "who": "cai", "mood": "hablando" },
		{ "text": "A mí me gusta mirarlos. ...  Es bonito.", "who": "cai", "mood": "feliz" },
	])
	await caja.finished
	await caja.close_and_free()


# ------------------------------------------------- TUTORIAL GUIADO (repetible)

## EL TUTORIAL DE LA PESCA, EN TIEMPO REAL Y SIN NARRADOR. Lo abre el botón
## "?" de la esquina y se puede repetir siempre que se quiera.
##
## No es la clase de Cai (`_clase_de_pesca`) con otras frases: aquí NADIE
## habla. El juego corre, y lo único que hay es un cartel que dice lo que
## toca AHORA MISMO y un foco sobre lo que hay que mirar — el patrón del
## rótulo "Toca el agua para lanzar el sedal", pero llevado paso a paso. Cada
## paso se cierra SOLO cuando el jugador lo hace, así que no se puede leer
## sin tocar ni tocar sin leer.
##
## El intento va AMAÑADO con la misma bandera que la clase (`clase`): pez
## fácil, gratis, el sedal perdona y no se puede perder. Y el TIRÓN se
## provoca a mano (`speed_next = 0`) cuando toca explicarlo, porque en un
## intento de tier 0 puede no salir ninguno.
func _tutorial_guiado() -> void:
	if tutor or clase or state != State.READY:
		return
	tutor = true
	clase = true
	tutor_abandonar = false
	_refresh_cast_label()
	_montar_salir_tutorial()
	tutor_card.modulate.a = 0.0
	tutor_card.visible = true
	# EL TUTORIAL SE REPITE HASTA QUE SALE (pedido por el usuario). Antes era
	# una sola pasada: si el pez se escapaba —por no clavar la picada, por
	# tirar en una finta o por reventar el sedal— el guion seguia hablando
	# sobre un intento que ya no existia y terminaba felicitando al jugador
	# por algo que no habia hecho, dejandolo ademas SIN el boton del "?" para
	# volver a intentarlo. Ahora un intento perdido vuelve a empezar.
	var vuelta := 0
	while tutor and not tutor_abandonar:
		vuelta += 1
		var completo: bool = await _tutor_intento(vuelta)
		if completo or tutor_abandonar or not tutor:
			break
		# El intento se fue al traste: se espera a que la pesca vuelva a la
		# calma y se cuenta otra vez desde el principio.
		await _tutor_pausa(0.6)
		await _esperar_pesca(func() -> bool: return state == State.READY, 12.0)
	_tutor_fin()


## UNA PASADA del tutorial. Devuelve `true` solo si llego hasta el final; con
## `false` el intento se perdio por el camino y quien llama vuelve a empezar.
##
## TODAS las esperas de aqui se cortan solas con `_tutor_roto()` — el intento
## muerto, el jugador saliendose o el minijuego devuelto a la calma—, asi que
## no hay forma de quedarse colgado en un paso que ya no puede cumplirse.
func _tutor_intento(vuelta: int) -> bool:
	tutor_perdido = false
	if vuelta > 1:
		_tutor_di("No pasa nada, se escapan muchos." + TUTOR_NL
			+ "Vamos otra vez, desde el principio.")
		await _tutor_pausa(2.4)
		if _tutor_roto():
			return false

	# 1) EL BOTON. Con foco, y no se sigue hasta que lo pulsa.
	var z := cast_btn.z_index
	var velo := _foco_pesca(cast_btn)
	_tutor_di("Aquí empieza todo.\nPulsa para lanzar la caña.")
	await _esperar_pesca(func() -> bool:
		return state != State.READY or _tutor_roto(), 600.0)
	_quitar_foco(velo, cast_btn, z)
	if _tutor_roto():
		return false

	# 2) LA SOMBRA. El anillo va DELANTE DE SU BOCA y se mueve con ella: hay
	#    que adelantarse, que es toda la leccion. Y se queda puesto MIENTRAS
	#    NO HAYA SEDAL EN EL AGUA, asi que si el primer lanzamiento cae lejos
	#    y hay que recoger, el segundo vuelve a tener su aro (le paso al
	#    usuario: la segunda vez lanzaba a ciegas).
	var anillo := _anillo_en(_punto_de_lanzado,
		func() -> bool: return not bobber_out and not casting)
	_tutor_di("Esa sombra es tu presa.\nNada sin parar: no la esperes quieta.")
	await _tutor_pausa(3.0)
	# SIN TOPE: este paso no se puede saltar. Si el jugador se queda quieto,
	# el cartel le insiste en vez de seguir contando cosas que no han pasado.
	await _tutor_insistir(func() -> bool: return bobber_out and not casting,
		"Toca el agua donde marca el aro,\nPOR DELANTE de su boca.",
		"Tócala tú: hasta que no lances,\nel pez no se entera de que estás.")
	if _tutor_roto():
		_borrar_anillo(anillo)
		return false

	# 3) RECOGER. Solo si el sedal cayo LEJOS de verdad; si el pez ya va al
	#    anzuelo, esta leccion sobra y no se suelta.
	if state == State.SHADOW and bobber.distance_to(shadow_pos) > VISION_R:
		_tutor_di("Ha caído lejos: MANTÉN pulsado\npara recoger y vuelve a lanzar.")
	await _esperar_pesca(func() -> bool:
		return state == State.APPROACH or state == State.FEINT or _tutor_roto(),
		600.0)
	_borrar_anillo(anillo)
	if _tutor_roto():
		return false

	# 4) LAS FINTAS: la parte que mas intentos cuesta, y la unica que no se
	#    puede explicar despues de haberla fallado.
	var anillo2 := _anillo_en(func() -> Vector2: return bobber)
	_tutor_di("Ya viene. Dará mordisquitos de prueba:\nsi tocas en uno, lo espantas.")
	await _tutor_espera(func() -> bool:
		return feints_done >= 1 or state == State.FIGHT or _tutor_roto(), 30.0)
	if not _tutor_roto() and state != State.FIGHT:
		_tutor_di("Eso era un amago.\nEspera al «¡Ha picado!» y toca ENTONCES.")
	# SIN TOPE: hasta que no pique y se claven, no hay pelea que explicar.
	await _tutor_insistir(func() -> bool: return state == State.FIGHT,
		"Espera al «¡Ha picado!»\ny toca ENTONCES.",
		"Cuando salga el «!» sobre el flotador,\ntoca la pantalla.")
	_borrar_anillo(anillo2)
	if _tutor_roto():
		return false

	tutor_falta_tiron = true
	# 5) LA PELEA, barra por barra. El foco cae sobre la cana pero DEJA JUGAR
	#    (`pasa_toques`): aqui el jugador tiene que estar pulsando el agua.
	#    Y los dos pasos se cierran cuando LO HACE, no cuando pasan cuatro
	#    segundos: mantener y soltar son los dos gestos de toda la pelea.
	tutor_mantuvo = false
	tutor_solto = false
	var zs := rod.z_index
	var velo2 := _foco_pesca(rod, true)
	await _tutor_insistir(func() -> bool: return tutor_mantuvo,
		"MANTÉN pulsado para recoger." + TUTOR_NL
			+ "El sedal se tensa: verde, naranja... y rojo se rompe.",
		"Apoya el dedo en el agua y NO lo sueltes:" + TUTOR_NL
			+ "así recoges sedal.")
	await _tutor_insistir(func() -> bool: return tutor_solto,
		"Suelta de vez en cuando y el sedal descansa." + TUTOR_NL
			+ "Vacía la barra de la presa y será tuyo.",
		"Levanta el dedo un momento:" + TUTOR_NL
			+ "con el sedal en rojo se rompe.")
	_quitar_foco(velo2, rod, zs)
	if _tutor_roto():
		tutor_falta_tiron = false
		return false

	# 6) EL TIRON. Se PROVOCA aqui mismo (`speed_next = 0`) y no se deja al
	#    azar: jugando bien, la presa se vaciaba antes de que llegara ninguno
	#    y el tutorial terminaba sin explicar lo unico que de verdad se falla.
	if state == State.FIGHT:
		speed_next = 0.0
		await _esperar_pesca(func() -> bool:
			return speed_left > 0.0 or state != State.FIGHT or _tutor_roto(), 12.0)
	if not _tutor_roto() and state == State.FIGHT and speed_left > 0.0:
		# Y DURA MUCHO (pedido por el usuario): en un tiron de tres segundos
		# el jugador apenas llega a leer el cartel, y esto es justo lo unico
		# de la pesca que no se entiende sin haberlo hecho. Aqui se alarga a
		# `TUTOR_TIRON` para que le de tiempo a probar, equivocarse y ver que
		# pulsar rapido SI frena la barra.
		speed_left = maxf(speed_left, TUTOR_TIRON)
		# SIN TOPE: mientras `tutor_falta_tiron` esta puesto la presa no se
		# puede cobrar, asi que insistir es seguro.
		await _tutor_insistir(func() -> bool:
			return speed_left <= 0.0 or state != State.FIGHT,
			"¡AHORA! Pulsa rápido y sin parar." + TUTOR_NL
				+ "Aquí MANTENER no vale: rompe el sedal.",
			"Pulsa y suelta, pulsa y suelta." + TUTOR_NL
				+ "Cada toque le frena el tirón.")
		if not _tutor_roto():
			_tutor_di("Eso es. Cuando afloje, vuelve a mantener.")
			await _tutor_pausa(2.6)
	tutor_falta_tiron = false
	if _tutor_roto():
		return false

	# 7) FIN: se recoge todo pase lo que pase con el pez.
	_tutor_di("Ya sabes pescar.\nCuanto más grande, más doblones.")
	await _tutor_pausa(3.5)
	return true


## ¿SE HA IDO AL TRASTE EL INTENTO? Lo apunta `_escaped`, que es el embudo de
## TODAS las formas de perder el pez: no clavar la picada, tirar en una finta,
## dejar que se lleve el cebo y reventar el sedal. Se apunta con una BANDERA y
## no mirando el estado por dos razones: en el paso 1 el minijuego esta en
## READY a proposito (se espera a que el jugador pulse), y el ESCAPED dura
## 1,6 s — una pausa del guion podia dormirse encima y no llegar a verlo.
func _tutor_roto() -> bool:
	return not tutor or tutor_abandonar or tutor_perdido


## EL BOTON DE SALIRSE, arriba a la derecha y solo mientras dura el tutorial
## (pedido por el usuario). Sin el, quien ya sabe pescar se quedaba dentro de
## la clase hasta el final: el "Atras" se esconde en cuanto hay un intento en
## juego, que es media clase.
func _montar_salir_tutorial() -> void:
	if salir_tutor_btn != null and is_instance_valid(salir_tutor_btn):
		salir_tutor_btn.visible = true
		return
	var b := Button.new()
	b.text = "Salir del tutorial"
	b.custom_minimum_size = Vector2(250, 52)
	PrepBoard.skin_small_button(b)
	b.add_theme_font_size_override("font_size", 20)
	b.set_meta("snd", "atras")
	b.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	b.offset_left = -274.0
	b.offset_right = -24.0
	b.offset_top = 24.0 + GameState.safe_top()
	b.offset_bottom = 76.0 + GameState.safe_top()
	b.z_index = 170
	b.pressed.connect(func() -> void: tutor_abandonar = true)
	add_child(b)
	salir_tutor_btn = b


## Cierra el tutorial y devuelve el minijuego a la normalidad. Se llama
## también desde `_set_state` si el intento termina antes de tiempo: el
## cartel no puede quedarse colgado sobre una pantalla que ya no lo espera.
func _tutor_fin() -> void:
	if not tutor:
		return
	tutor = false
	tutor_falta_tiron = false
	tutor_abandonar = false
	clase = false
	_refresh_cast_label()
	if salir_tutor_btn != null and is_instance_valid(salir_tutor_btn):
		salir_tutor_btn.queue_free()
		salir_tutor_btn = null
	# EL "?" VUELVE. Su visibilidad la decide `_set_state`, que aquí ya no se
	# vuelve a llamar: si el pez se cobró ANTES de que el guion terminara de
	# hablar, el último `_set_state(READY)` corrió con `tutor` todavía puesto
	# y el botón se quedaba escondido para siempre — sin forma de repetir la
	# clase. Le pasó al usuario.
	if ayuda_btn != null and is_instance_valid(ayuda_btn):
		ayuda_btn.visible = state == State.READY
	if tutor_card != null and is_instance_valid(tutor_card):
		var tw := tutor_card.create_tween()
		tw.tween_property(tutor_card, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func() -> void: tutor_card.visible = false)


## ESPERA SIN TOPE a un paso que NO se puede saltar, y cada `TUTOR_INSISTE`
## segundos alterna el cartel entre la consigna y un empujón. Los topes de
## `_tutor_espera` valían para los pasos de adorno, pero en los obligatorios
## hacían avanzar el guion sin que el jugador hubiera hecho nada — y el
## tutorial acababa contando cosas que en pantalla no habían ocurrido.
func _tutor_insistir(cond: Callable, texto: String, empujon: String) -> void:
	if _tutor_roto():
		return
	# LO PRIMERO, DECIRLO: el bucle solo alterna a partir de `TUTOR_INSISTE`,
	# asi que sin esta linea el cartel se quedaba con la frase del paso
	# ANTERIOR durante seis segundos.
	_tutor_di(texto)
	await _tutor_pausa(TUTOR_MIN_LEER)
	var t := 0.0
	var alterna := false
	while tutor and is_inside_tree() and not cond.call():
		await get_tree().process_frame
		if _tutor_roto():
			# El intento se acabó por otro lado (se escapó, el jugador se
			# sale): que no se quede colgado esperando lo imposible.
			return
		t += get_process_delta_time()
		if t >= TUTOR_INSISTE:
			t = 0.0
			alterna = not alterna
			_tutor_di(empujon if alterna else texto)


## Espera a que se cumpla algo, PERO nunca antes de `TUTOR_MIN_LEER`
## segundos: un jugador que ya sabe pescar cumple el paso en el mismo
## fotograma en que sale el cartel, y el texto parpadeaba sin que diera
## tiempo a leerlo.
func _tutor_espera(cond: Callable, tope := 40.0) -> void:
	await _tutor_pausa(TUTOR_MIN_LEER)
	await _esperar_pesca(cond, tope)


## Escribe el paso actual en el cartel (y lo hace aparecer la primera vez).
func _tutor_di(texto: String) -> void:
	if tutor_label == null or not is_instance_valid(tutor_label):
		return
	tutor_label.text = texto
	tutor_card.visible = true
	var tw := tutor_card.create_tween()
	tw.tween_property(tutor_card, "modulate:a", 1.0, 0.18)


## Espera de tutorial: como `_esperar_pesca`, no bloquea el juego (el jugador
## tiene que poder seguir pescando mientras lee) y se corta sola si el
## tutorial se cierra antes.
func _tutor_pausa(segundos: float) -> void:
	var t := 0.0
	while is_inside_tree() and tutor and not tutor_abandonar and t < segundos:
		t += get_process_delta_time()
		await get_tree().process_frame


## ANILLO PULSANTE sobre un punto del agua que se MUEVE (el pez, el
## flotador). No se usa el foco con velo de `_foco_pesca` porque lo que hay
## que señalar aquí está DIBUJADO dentro de `zone`: oscurecerlo lo taparía
## justo a él. El anillo se dibuja encima y sigue al objetivo por fotograma.
## ADONDE HAY QUE LANZAR: por delante de la BOCA del pez, no encima de su
## sombra (pedido por el usuario). La sombra viaja, así que el anillo tiene
## que ir señalando el sitio al que llegará — que es justo lo que el jugador
## tiene que aprender a calcular.
func _punto_de_lanzado() -> Vector2:
	# La BOCA va por delante del centro del cuerpo (FEINT_RETREAT es lo que
	# el cuerpo queda retirado cuando embiste), y el aro se adelanta otro
	# tanto sobre su rumbo.
	return shadow_pos + Vector2.from_angle(heading) * (FEINT_RETREAT + TUTOR_DELANTE)


## Pregunta antes de soltar el tutorial: es largo, amaña el intento y quien
## solo quería mirar el álbum no tiene por qué tragárselo.
func _preguntar_tutorial() -> void:
	if tutor or clase or state != State.READY:
		return
	var velo := ColorRect.new()
	Audio.ventana(velo)
	velo.color = Color(0, 0, 0, 0.55)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.z_index = 200
	add_child(velo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.add_child(centro)
	var cartel := Control.new()
	cartel.custom_minimum_size = Vector2(540, 340)
	centro.add_child(cartel)
	cartel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))
	PrepBoard.add_panel_banner(cartel, "¿Repasamos?", 30)
	# EL TEXTO ARRIBA Y LOS BOTONES ABAJO, cada uno en su franja y sin
	# tocarse: el parrafo iba centrado en una caja que llegaba hasta los
	# botones, asi que la segunda frase aterrizaba encima de ellos.
	var l := Label.new()
	# UN SOLO SALTO entre las dos frases: con el renglón en blanco quedaban
	# tan separadas que no se leían como un mismo párrafo.
	l.text = ("Te guío paso a paso en una tirada de práctica.
"
		+ "No cuesta doblones y no puedes perder la presa.")
	l.add_theme_constant_override("line_spacing", 4)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# ANCHO Y CUERPO MEDIDOS para que cada frase entre en UN renglon: a
	# cuerpo 20 y con 54 de margen la primera se partia en dos, el parrafo
	# pasaba de tres renglones a cuatro y se desbordaba de su caja — que es
	# como acababa la segunda frase encima de los botones.
	l.offset_left = 36.0
	l.offset_top = 94.0
	l.offset_right = -36.0
	l.offset_bottom = -142.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", Color(0.42, 0.3, 0.18))
	cartel.add_child(l)
	# LOS BOTONES VAN EN UN `CenterContainer`, no en un HBox anclado: un
	# contenedor anclado a mano se centra respecto a sus OFFSETS, y bastaba
	# que uno de los dos botones midiera distinto para que la pareja quedara
	# descolgada. El centrador no puede equivocarse.
	var pie := CenterContainer.new()
	pie.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	pie.offset_top = -122.0
	pie.offset_bottom = -34.0
	cartel.add_child(pie)
	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", 18)
	pie.add_child(botones)
	# CON RÓTULO, no solo el aspa y el visto (pedido por el usuario): aquí no
	# se pregunta "¿sí o no?" sino qué se hace, y el icono va DIBUJADO en la
	# madera con el texto arrancando a su derecha (`skin_icon_button`), así
	# que basta con ensanchar el botón.
	var no := Button.new()
	no.custom_minimum_size = Vector2(216, 86)
	no.text = "Cancelar"
	no.add_theme_font_size_override("font_size", 24)
	PrepBoard.skin_action_button(no, false)
	no.pressed.connect(velo.queue_free)
	botones.add_child(no)
	var si := Button.new()
	si.custom_minimum_size = Vector2(216, 86)
	si.text = "Practicar"
	si.add_theme_font_size_override("font_size", 24)
	PrepBoard.skin_action_button(si, true)
	si.pressed.connect(func() -> void:
		velo.queue_free()
		_tutorial_guiado())
	botones.add_child(si)


## LOS ANILLOS VIVOS, para repintarlos por fotograma (ver `_anillo_en`).
var _anillos: Array[Control] = []


## Con `visible_si` el anillo solo se pinta mientras esa condición se cumple:
## el del lanzamiento se queda puesto TODA la fase de sombra y desaparece
## mientras el sedal está en el agua, así que un segundo lanzamiento vuelve a
## tener su aro sin que el guion tenga que rehacerlo.
func _anillo_en(get_pos: Callable, visible_si := Callable()) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.z_index = 160
	c.set_meta("pos", get_pos)
	if visible_si.is_valid():
		c.set_meta("cond", visible_si)
	add_child(c)
	c.draw.connect(_dibujar_anillo.bind(c))
	# SE REPINTA POR FOTOGRAMA o el aro se queda clavado donde estuviera el
	# pez al crearlo: `draw` solo se emite cuando alguien pide `queue_redraw`,
	# y aqui lo que se senala se MUEVE (esa es toda la leccion).
	_anillos.append(c)
	return c


func _dibujar_anillo(c: Control) -> void:
	if c.has_meta("cond"):
		var cond: Callable = c.get_meta("cond")
		if not bool(cond.call()):
			return
	var get_pos: Callable = c.get_meta("pos")
	var p: Vector2 = get_pos.call()
	# Dos anillos que laten en contrafase: se ven sobre el agua clara y sobre
	# la sombra oscura del pez, que es justo lo que hay debajo.
	var k := 0.5 + 0.5 * sin(_t * 4.0)
	var r := 44.0 + 16.0 * k
	c.draw_arc(p, r, 0.0, TAU, 36, Color(1.0, 0.86, 0.35, 0.95 - 0.5 * k), 5.0, true)
	c.draw_arc(p, r + 5.0, 0.0, TAU, 36, Color(0.2, 0.12, 0.05, 0.55 - 0.3 * k), 2.0, true)


func _borrar_anillo(c: Control) -> void:
	_anillos.erase(c)
	if c != null and is_instance_valid(c):
		c.queue_free()


# ------------------------------------------------------------------- sonido

## LAS FAMILIAS DE SONIDO de la pesca (`sounds/pesca`). Las rutas van a mano
## y no por escaneo de carpeta: los .ogg se importan y en el export los
## originales no están (ver `SoundBank`).
##
## El reparto sale de lo que hace cada sonido, no de su nombre:
## · "Open Bait Box" abre el intento (se saca el cebo) y ABRE EL COFRE, que
##   es literalmente abrir una caja.
## · EL LANZAMIENTO VA RECORTADO A **0.594 s**, que es su LATIGAZO y nada
##   más. `tools/ogg_trim.py` lo deja ahí SIN RECODIFICAR (corta en un límite
##   de página, marca fin de flujo y recalcula el CRC), y el plof lo pone la
##   BOYA al tocar el agua, que además cae donde de verdad cae en pantalla
##   (`CAST_TIME` 0.38). "Casting Line - 4" entero dura 2.143 s y trae DOS
##   cosas de sobra, las dos localizadas en su curva de bitrate: su PROPIO
##   chapoteo (un estallido de 365 kbps desde 1.335 s, con la cola de las
##   ondas detrás a 33), que sonaba doble con el de la boya, y antes de él un
##   tramo flojo de línea saliendo del carrete (0.594-1.335 s, 45 kbps) que
##   seguía sonando casi un segundo DESPUÉS del plof y se oía como un sonido
##   aparte. Se probó cortando solo el chapoteo y por eso se sabe.
## · "Fish Biting" (tomas 2 y 3) son los AMAGOS y nada más: mordisqueos, y por
##   eso van flojitos. La PICADA de verdad NO es una boca, es AGUA: el mismo
##   chapoteo del pez que se suelta, que es lo que hace que los dos momentos
##   se reconozcan como la misma cosa vista al derecho y al revés.
## · "Reeling in Fishing Rod - 1" es el carrete: recoger el sedal antes de que
##   pique, y en el TIRÓN esa misma a más pitch (que en Godot corre además más
##   rápido), porque ahí es el pez quien se lleva la línea.
## · "Moving Line Closer - 1" es TODA la pelea, en un solo bucle que nunca se
##   corta: lo que cambia es la VELOCIDAD (`PITCH_MANTENIENDO` recogiendo,
##   `PITCH_SUELTO` con el dedo levantado). Comparten reproductor, así que el
##   cambio no reinicia nada y se oye acelerar y frenar.
## · "Frog Death - 1" es el golpe que marca el ARRANQUE del tirón, muy por
##   debajo del resto: las líneas de acción entran con un fundido de 0.18 s,
##   así que sin él el instante exacto del cambio de fase no suena.
## · "Line Break (With Throw)" para el sedal roto —la toma con el latigazo—
##   y el chapoteo de la boya para cuando la presa se suelta y para el pez
##   que sale del agua.
const SND := {
	"cebo": [
		"res://sounds/juego/pesca/Open Bait Box - 1.ogg",
		"res://sounds/juego/pesca/Open Bait Box - 2.ogg",
	],
	"lanzar": [
		"res://sounds/juego/pesca/Casting Line - 4 (corto).ogg",
	],
	# La boya tocando el agua: el plof del lanzamiento.
	"boya": [
		"res://sounds/juego/pesca/Bobber Lands in Water - 2.ogg",
	],
	# EL MISMO chapoteo para los tres momentos de agua removida, y lo que los
	# distingue es el TONO (ver `PITCH_*`): la PICADA, el pez que se SUELTA
	# —el mismo golpe pero más grave, que es lo que lo hace sonar a derrota— y
	# el pez que sale del agua al cobrarlo.
	"chapoteo": [
		"res://sounds/juego/pesca/Bobber Lands in Water - 1.ogg",
		"res://sounds/juego/pesca/Bobber Lands in Water - 2.ogg",
	],
	"amago": [
		"res://sounds/juego/pesca/Fish Biting - 3.ogg",
		"res://sounds/juego/pesca/Fish Biting - 4.ogg",
	],
	"recoger": [
		"res://sounds/juego/pesca/Reeling in Fishing Rod - 1.ogg",
	],
	"carrete": [
		"res://sounds/juego/pesca/Reeling in Fishing Rod - 1.ogg",
	],
	# LA PELEA SON DOS BUCLES QUE SUENAN A LA VEZ y se cruzan con el dedo:
	# el arrastre cuando el jugador recoge y el carrete del pez cuando lo
	# deja correr. Los dos van a la velocidad de las barras (ver `VEL_REF`).
	"arrastre": [
		"res://sounds/juego/pesca/Moving Line Closer - 1.ogg",
	],
	"sedal_pez": [
		"res://sounds/juego/pesca/Reeling in Fishing Rod - 2 (bucle).ogg",
	],
	# El golpe que anuncia el TIRÓN, encima del carrete acelerado.
	"tiron": [
		"res://sounds/juego/pesca/tiron.ogg",
	],
	# SOLO la toma 2 (decidido por el usuario).
	"rotura": [
		"res://sounds/juego/pesca/Line Break - 2.ogg",
	],
}

## Volúmenes, en dB. El carrete y la recogida van MÁS BAJOS que los golpes:
## son bucles que suenan segundos seguidos, y a la misma altura que un efecto
## puntual acaban tapando la partida.
const SND_EFECTO := -4.0
const SND_BUCLE := -11.0
const SND_AMAGO := -13.0

## Los tres chapoteos, por tono. La PICADA es la referencia; la presa que se
## SUELTA es el mismo golpe más grave (un plof pesado, de derrota) y el pez
## cobrado va entre medias y con más cuerpo.
const PITCH_PICADA := 0.85
const PITCH_SUELTA := 0.65
const PITCH_COBRADO := 0.8

## El golpe del tirón va MUY por debajo del resto: subraya el cambio de fase,
## no lo anuncia a gritos (el carrete acelerado y las líneas de acción ya lo
## dicen bastante alto).
const SND_TIRON := -14.0

## EL SONIDO DEL SEDAL CORRE A LA VELOCIDAD DE LAS BARRAS. No hay una
## velocidad "de recoger" y otra "de soltar": se suma lo que se MUEVEN LAS DOS
## —la de la presa y la del SEDAL— y de ahí sale el tono, así que el carrete
## acelera cuando pasan cosas y se arrastra cuando no pasa ninguna.
##
## **QUE SOLTAR SUENE MÁS RÁPIDO QUE RECOGER SALE SOLO DE AHÍ**, y es la
## razón de contar las dos barras: el sedal SE DESTENSA (0.85/s) mucho más
## deprisa de lo que se tensa (0.30 a 0.55/s según rareza). Sumando:
## recogiendo se mueven 0.50-0.75 barra/s y soltando 0.89-1.15. No hay ningún
## número puesto a mano para conseguirlo — es lo que hacen las barras.
const VEL_REF := 1.1
## En el TIRÓN la barra de la presa vuela ella sola (0.22 a 1.0/s según
## rareza y tamaño) y encima el sedal se destensa.
const VEL_REF_TIRON := 1.3
## Suavizado de la medida: sin él, cada cambio de dedo daba un salto de tono.
const VEL_SUAVIZADO := 8.0
## El carrete va SIEMPRE por encima de su velocidad natural: a 1.0 se
## arrastraba y la pelea sonaba parada aunque no lo estuviera.
const PITCH_MIN := 1.15
const PITCH_MAX := 1.5
## EL TIRÓN ES SIEMPRE EL MÁS RÁPIDO, pase lo que pase: su suelo va por
## encima del techo de los otros dos, así que ni el mejor tramo de recogida
## puede sonar tan acelerado como el pez llevándose el sedal.
const PITCH_TIRON_MIN := 1.6
const PITCH_TIRON_MAX := 2.05

## Y CUANDO TIRA EL PEZ SUENA OTRO CARRETE, no el mismo procesado. Hubo un
## `AudioEffectPitchShift` en un bus propio para bajarle el tono sin tocar la
## velocidad, Y NO VALE — es lo que sonaba mal en ese estado, por dos motivos
## que se suman: (1) un desplazador de tono trabaja por FFT y el carrete es
## RUIDO de banda ancha, justo lo que peor lleva (sale emborronado, con ese
## punto metálico de flanger), y (2) el efecto se encendía y se apagaba con
## `set_bus_effect_enabled` en CADA toque —`holding` cambia con cada dedo que
## sube o baja, varias veces por segundo— y meter y sacar una FFT con
## latencia propia de la cadena en caliente da saltos y chasquidos. Encima a
## 0.95 el tono casi no se notaba: todo el defecto y nada del efecto.
## Lo que sí distingue los dos estados sin procesar nada es que sean DOS
## GRABACIONES distintas, cruzadas por volumen (`MEZCLA_VEL`): el timbre
## cambia de verdad, no se reinicia nada y no hay DSP que pueda chasquear.
## EL CRUCE VA MÁS RÁPIDO EN UN SENTIDO QUE EN OTRO, a propósito: cuando el
## jugador APRIETA el sonido tiene que responderle CASI EN EL ACTO (es su
## gesto, y una transición ahí se oye como que el juego va por detrás), y
## cuando suelta el relevo puede ser más suave, porque quien toma el mando es
## el pez. Mismo criterio para entrar y salir del tirón.
const MEZCLA_A_RECOGER := 32.0
const MEZCLA_A_SOLTAR := 16.0
## El carrete del pez arranca despacio y coge ritmo: su primer tramo suena
## una vez y el bucle vuelve aquí (ver `SoundBank.loop_on`).
const SEDAL_PEZ_DESDE := 0.845


func _setup_audio() -> void:
	if snd != null and is_instance_valid(snd):
		return
	snd = SoundBank.new()
	# Por el bus de EFECTOS, como el resto del juego: así la barra de efectos
	# de Opciones también manda sobre la pesca (era el único audio anterior al
	# director y salía por Master, o sea sin control).
	snd.bus = Audio.BUS_EFECTOS
	add_child(snd)
	for familia in SND:
		snd.cargar(str(familia), SND[familia])


## El carrete de la PELEA. Los DOS bucles de la pelea suenan siempre a la vez
## y lo que se cruza es su VOLUMEN (`mezcla_pez`), así que ninguno se para ni
## se reinicia al levantar el dedo: solo se pasa de un timbre al otro. Los dos
## corren a la velocidad de las barras. En el TIRÓN mandan callar a los dos y
## entra el carrete acelerado. Se llama por fotograma desde `_tick_fight`.
func _audio_pelea(delta: float, en_velocidad: bool) -> void:
	if snd == null:
		return
	snd.loop_off("recoger")
	# NINGÚN bucle de la pelea se para ni se arranca a mitad: los TRES suenan
	# de principio a fin y lo único que se mueve es su volumen. Pararlos y
	# volver a lanzarlos es lo que se oía como un corte al pasar de un sonido
	# a otro —un `play()` empieza el archivo desde cero, y encima el tirón
	# entra y sale varias veces por pelea.
	var rapido := minf(delta * MEZCLA_A_RECOGER, 1.0)
	var suave := minf(delta * MEZCLA_A_SOLTAR, 1.0)
	mezcla_pez = lerpf(mezcla_pez, 0.0 if holding else 1.0,
		rapido if holding else suave)
	mezcla_tiron = lerpf(mezcla_tiron, 1.0 if en_velocidad else 0.0,
		rapido if en_velocidad else suave)
	var pitch := _pitch_sano(lerpf(PITCH_MIN, PITCH_MAX,
		clampf(vel_barra / VEL_REF, 0.0, 1.0)))
	# EN EL TIRÓN MANDA LA FUERZA DEL PEZ, NO LO QUE SE MUEVA LA BARRA. Cada
	# toque del jugador FRENA la barra (esa es la mecánica), así que pulsando
	# como hay que pulsar la barra casi se para y el carrete se venía abajo
	# —de x1.84 a x1.61, medido— justo en el momento más apretado: se oía como
	# si el tirón se hubiera acabado. El pez sigue tirando con todo, y eso es
	# lo que tiene que sonar.
	var pitch_tiron := _pitch_sano(lerpf(PITCH_TIRON_MIN, PITCH_TIRON_MAX,
		clampf(maxf(vel_barra, tiron_tasa) / VEL_REF_TIRON, 0.0, 1.0)))
	var normal := 1.0 - mezcla_tiron
	snd.loop_on("arrastre",
		SND_BUCLE + _mezcla_db(normal * (1.0 - mezcla_pez)), pitch)
	snd.loop_on("sedal_pez", SND_BUCLE + _mezcla_db(normal * mezcla_pez),
		pitch, SEDAL_PEZ_DESDE)
	snd.loop_on("carrete", SND_BUCLE + 2.0 + _mezcla_db(mezcla_tiron),
		pitch_tiron)


## Red de seguridad: un `pitch_scale` que no sea un número REVIENTA el mezclador
## y puede llevarse por delante TODO el audio, no solo ese sonido. Cuesta una
## comparación por fotograma y ahorra un fallo imposible de encontrar.
func _pitch_sano(p: float) -> float:
	return 1.0 if not is_finite(p) else clampf(p, 0.25, 4.0)


## Cuánto se baja un lado de la mezcla, en dB. Va por VOLUMEN LINEAL y no
## interpolando decibelios: en dB el cruce se oye como un bache en el medio,
## porque -6 dB ya es la mitad de señal.
func _mezcla_db(k: float) -> float:
	if not is_finite(k):
		return -80.0
	return linear_to_db(clampf(k, 0.0005, 1.0))
