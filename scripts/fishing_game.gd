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

enum State { READY, SHADOW, APPROACH, FEINT, BITE, FIGHT, REVEAL, ESCAPED }

## Punta de la caña (borde derecho del barco DEL MENÚ, medido sobre captura)
## y rectángulo de agua útil para lanzar y para la sombra.
const ROD_TIP := Vector2(505, 395)
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
const DRAIN_HOLD := 0.16
const REGAIN_BASE := 0.045
const REGAIN_TIER := 0.02
const ENERGY_START_BASE := 0.6
const ENERGY_START_TIER := 0.1
## En la fase de velocidad la presa SIEMPRE intenta subir a este ritmo; cada
## toque NO la baja: le abre una ventana de TAP_RELIEF s en la que el subidón
## queda FRENADO y solo entonces cae un poquito (SPEED_DRAIN_TAPPING).
## Pulsando más rápido que la ventana, la barra baja despacito; pulsando
## lento, sube entre toque y toque.
const SPEED_REGAIN_BASE := 0.22
const SPEED_REGAIN_TIER := 0.05
const SPEED_TIME_BASE := 1.1
const SPEED_TIME_TIER := 0.35
const SPEED_TENSION_DECAY := 0.25
const TAP_RELIEF := 0.3
const SPEED_DRAIN_TAPPING := 0.03
const TAP_TENSION := 0.045

var state: int = State.READY
var _t := 0.0

## El sorteo del intento en curso (GameState.fishing_roll) y su dificultad.
var roll: Dictionary = {}
var tier := 0

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
var tension := 0.0
var energy := 1.0
var phases_left := 0
var speed_left := 0.0
var speed_next := 0.0
## Ventana abierta por el ÚLTIMO toque de la fase de velocidad: mientras dura,
## la subida de la presa está frenada.
var speed_relief := 0.0

var zone: Control = null
var cast_btn: Button = null
var instruction: Label = null
var back_btn: Button = null
var album_btn: Button = null
var fight_box: Control = null
var tension_bar: ProgressBar = null
var energy_bar: ProgressBar = null


func _ready() -> void:
	# TRAMPA de CanvasLayer: anclas a cero y tamaño explícito (ver CLAUDE.md).
	position = Vector2.ZERO
	size = GameState.canvas_size()
	_setup_ui()
	_set_state(State.READY)


func _process(delta: float) -> void:
	_t += delta
	# El botón del tablón RESPIRA suavemente mientras espera (el latido del
	# viejo texto de la portada, en versión botón).
	if state == State.READY and cast_btn != null and not cast_btn.disabled \
			and not cast_btn.button_pressed:
		var k := 1.0 + 0.015 * sin(_t * 2.4)
		cast_btn.scale = Vector2(k, k)
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
	back_btn.pressed.connect(func() -> void: closed.emit())
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
	fila_coste.add_child(moneda)
	var coste := Label.new()
	coste.text = "%d" % FishData.FISHING_COST
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

	_setup_fight_ui()


## La caña grande con las DOS barras verticales de la pelea: el SEDAL (roja,
## sube al mantener, a tope se rompe) y la PRESA (ámbar, empieza llena y hay
## que vaciarla). Las barras usan la textura horizontal del set GIRADA -90°:
## el 9-slice se dibuja en horizontal y la rotación lo pone de pie, así que
## los topes redondos no se deforman.
func _setup_fight_ui() -> void:
	fight_box = Control.new()
	fight_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	fight_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fight_box.visible = false
	add_child(fight_box)

	var rod := TextureRect.new()
	rod.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rod.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rod.texture = load("res://assets/ui/pesca_cana.png")
	rod.position = Vector2(546.0, 520.0)
	rod.size = Vector2(170.0, 300.0)
	rod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fight_box.add_child(rod)

	# Separadas lo bastante para que sus rótulos no se toquen (se montaban).
	tension_bar = _make_vbar(424.0, "Sedal", Color(0.92, 0.34, 0.26))
	energy_bar = _make_vbar(512.0, "Presa", Color(0.95, 0.72, 0.20))


func _make_vbar(x: float, texto: String, tint: Color) -> ProgressBar:
	var holder := Control.new()
	holder.position = Vector2(x, 900.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fight_box.add_child(holder)
	var p := ProgressBar.new()
	p.min_value = 0.0
	p.max_value = 1.0
	p.show_percentage = false
	p.size = Vector2(360.0, 34.0)
	p.rotation = -PI / 2.0
	p.add_theme_stylebox_override("background",
		PrepBoard.make_bar_box(PrepBoard.BAR_BG_TEX))
	p.add_theme_stylebox_override("fill",
		PrepBoard.make_bar_box(PrepBoard.BAR_FILL_TEX, tint))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(p)
	var l := Label.new()
	l.text = texto
	l.position = Vector2(-24.0, 10.0)
	l.size = Vector2(82.0, 30.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.84))
	l.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.04))
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(l)
	return p


# ------------------------------------------------------------ estados y bucle

func _set_state(s: int) -> void:
	state = s
	cast_btn.visible = s == State.READY
	album_btn.visible = s == State.READY
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


func _start_attempt() -> void:
	if not GameState.fishing_pay():
		instruction.text = "Sin doblones para el cebo..."
		return
	money_changed.emit()
	# EL SORTEO, ANTES DE VER LA SOMBRA: el premio ya está decidido y de él
	# sale la dificultad de la pelea (y el tamaño de la sombra).
	roll = GameState.fishing_roll()
	tier = int(roll.get("tier", 0))
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
	instruction.text = "Toca el agua para lanzar el sedal"
	_set_state(State.SHADOW)


func _pick_wander() -> Vector2:
	var inner := WATER.grow(-SHADOW_MARGIN)
	return Vector2(randf_range(inner.position.x, inner.end.x),
		randf_range(inner.position.y, inner.end.y))


## Lanza (o relanza) el sedal al punto tocado. Relanzar es gratis: el intento
## ya está cobrado.
func _cast_to(punto: Vector2) -> void:
	cast_from = ROD_TIP
	cast_to = Vector2(clampf(punto.x, WATER.position.x, WATER.end.x),
		clampf(punto.y, WATER.position.y, WATER.end.y))
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
			bobber = bobber.move_toward(ROD_TIP, RETRIEVE_SPEED * delta)
			if bobber.distance_to(ROD_TIP) < 26.0:
				bobber_out = false
				retrieving = false
				instruction.text = "Toca el agua para lanzar el sedal"
	if casting:
		cast_t += delta / CAST_TIME
		if cast_t >= 1.0:
			casting = false
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
					feint_timer = randf_range(0.55, 1.1)
				else:
					_enter_bite()


## El puesto del pez frente al anzuelo: el CENTRO del cuerpo queda de forma
## que la BOCA (el morro de la silueta, a ~1.35 radios del centro) apunte al
## flotador desde FEINT_RETREAT píxeles de distancia.
func _feint_rest() -> Vector2:
	var nariz := (26.0 + 7.0 * tier) * 1.35 + 4.0
	return bobber - Vector2.from_angle(heading) * (nariz + FEINT_RETREAT) \
		+ Vector2(0, 6.0)


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
	bite_t = BITE_WINDOW
	bite_sink = 0.0
	# La picada de verdad: el pez se queda ADELANTADO, con la boca en el
	# anzuelo (sin el retiro de las fintas).
	var nariz := (26.0 + 7.0 * tier) * 1.35
	shadow_pos = bobber - Vector2.from_angle(heading) * nariz + Vector2(0, 6.0)
	instruction.text = "¡Ha picado!"
	_set_state(State.BITE)


func _start_fight() -> void:
	holding = true
	tension = 0.0
	speed_relief = 0.0
	# La presa empieza entre el 60% (tier 0) y el 90% (tier 3): cuanto mejor
	# el premio, menos margen hasta el 100% que la deja escapar.
	energy = ENERGY_START_BASE + ENERGY_START_TIER * tier
	# Fases de velocidad: más y más largas cuanto mejor es el premio.
	match tier:
		0: phases_left = randi_range(0, 1)
		1: phases_left = 1
		2: phases_left = randi_range(1, 2)
		_: phases_left = randi_range(2, 3)
	speed_left = 0.0
	speed_next = randf_range(1.2, 2.6)
	instruction.text = "¡Mantén para recoger!\nSuelta si el sedal sufre"
	_set_state(State.FIGHT)


func _tick_fight(delta: float) -> void:
	var en_velocidad := speed_left > 0.0
	if en_velocidad:
		speed_left -= delta
		speed_relief = maxf(speed_relief - delta, 0.0)
		# La presa SIEMPRE intenta subir todo lo posible; cada toque no la
		# baja, le FRENA la subida durante TAP_RELIEF s (y tensa el sedal en
		# _on_zone_input). Solo pulsando más rápido que la ventana la barra
		# baja, y muy poco.
		if speed_relief > 0.0:
			energy -= SPEED_DRAIN_TAPPING * delta
		else:
			energy += (SPEED_REGAIN_BASE + SPEED_REGAIN_TIER * tier) * delta
		tension = maxf(tension - SPEED_TENSION_DECAY * delta, 0.0)
		if speed_left <= 0.0:
			instruction.text = "¡Mantén para recoger!\nSuelta si el sedal sufre"
	else:
		if phases_left > 0:
			speed_next -= delta
			if speed_next <= 0.0:
				phases_left -= 1
				speed_left = SPEED_TIME_BASE + SPEED_TIME_TIER * tier
				speed_next = randf_range(2.2, 4.0)
				instruction.text = "¡Tira con fuerza!\n¡PULSA RÁPIDO!"
		if holding:
			energy -= DRAIN_HOLD * delta
			tension += TENSION_BASE * (1.0 + TENSION_TIER * tier) * delta
		else:
			energy += (REGAIN_BASE + REGAIN_TIER * tier) * delta
			tension -= TENSION_RELIEF * delta
	energy = clampf(energy, 0.0, 1.0)
	tension = clampf(tension, 0.0, 1.0)
	tension_bar.value = tension
	energy_bar.value = energy
	# La barra de la presa parpadea en la fase de velocidad: es el aviso.
	energy_bar.modulate = Color(1, 0.7, 0.7) \
		if en_velocidad and fmod(_t, 0.22) < 0.11 else Color.WHITE
	if tension >= 1.0:
		_escaped("¡El sedal se ha roto!")
		return
	# Recuperada del todo, la presa se suelta del anzuelo y se va.
	if energy >= 1.0:
		_escaped("¡Se ha escapado!")
		return
	if energy <= 0.0:
		_land_catch()


func _escaped(motivo: String) -> void:
	holding = false
	instruction.text = motivo
	_set_state(State.ESCAPED)
	zone.queue_redraw()
	var timer := get_tree().create_timer(1.6)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self) and state == State.ESCAPED:
			_set_state(State.READY))


## Captura lograda: AHORA se entrega el premio sorteado al empezar.
func _land_catch() -> void:
	holding = false
	instruction.text = ""
	_set_state(State.REVEAL)
	var premio := GameState.fishing_apply(roll)
	money_changed.emit()
	if str(premio.get("type", "")) == "fish":
		_show_fish_reveal(premio)
	else:
		_show_chest_reveal(premio)


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
				if speed_left > 0.0:
					# El toque FRENA la subida (no baja la barra)...
					speed_relief = TAP_RELIEF
					# ...y también TENSA el sedal: pulsar a lo loco con la
					# barra roja alta lo rompe igual.
					tension = minf(tension + TAP_TENSION, 1.0)
	else:
		retrieving = false
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
		spos = bobber + Vector2(randf_range(-4.0, 4.0), 10.0 + randf_range(-3.0, 3.0))
	var r := 26.0 + 7.0 * tier
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
	var mid := (ROD_TIP + pos) * 0.5 + Vector2(0.0, sag)
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		var a := ROD_TIP.lerp(mid, t)
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


func _reveal_close_button(panel: Control, overlay_alto: float) -> void:
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
		_set_state(State.READY))


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
	var fish_id := str(premio["fish_id"])
	var alto := 640.0
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
	_centered_label(panel, str(rareza.get("name", "")), 24, 386.0,
		Color(rareza.get("color", Color.GRAY)))
	# Las líneas del premio: usos de despensa (peces-ingrediente, siempre) y
	# monedas (desde la 2ª captura). La 1ª de un pez sin ingrediente es el
	# descubrimiento y lo dice.
	var y := 426.0
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
	if not premio.has("ingredient") and not premio.has("coins"):
		_centered_label(panel, "¡Nuevo en el álbum!", 26, y,
			Color(0.2, 0.45, 0.12))
		y += 40.0
	var veces := int(premio.get("veces", 1))
	if veces > 1:
		_centered_label(panel, "Pescado %d veces" % veces, 19, y, FADED)
	_reveal_close_button(panel, alto)


func _show_chest_reveal(premio: Dictionary) -> void:
	var alto := 620.0
	var panel := _reveal_panel(alto)
	var title := PrepBoard.make_big_title("¡Un cofre\ndel mar!", 44)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 34.0
	title.offset_bottom = 150.0
	panel.add_child(title)

	# El cofre del bonus diario: cerrado, se menea y se abre soltando el botín.
	var cofre := TextureRect.new()
	cofre.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cofre.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cofre.texture = load("res://assets/ui/daily_cofre.png")
	cofre.position = Vector2((520.0 - 170.0) * 0.5, 160.0)
	cofre.size = Vector2(170, 170)
	cofre.pivot_offset = Vector2(85, 100)
	panel.add_child(cofre)
	var tw := create_tween()
	tw.tween_property(cofre, "rotation_degrees", 7.0, 0.09)
	tw.tween_property(cofre, "rotation_degrees", -7.0, 0.09)
	tw.tween_property(cofre, "rotation_degrees", 5.0, 0.08)
	tw.tween_property(cofre, "rotation_degrees", 0.0, 0.07)
	tw.tween_callback(func() -> void:
		cofre.texture = load("res://assets/ui/daily_cofre_abierto.png"))
	tw.tween_property(cofre, "scale", Vector2(1.12, 1.12), 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(cofre, "scale", Vector2.ONE, 0.12)

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

	# El botín aparece cuando el cofre ya está abierto.
	var fila := HBoxContainer.new()
	fila.set_anchors_preset(Control.PRESET_TOP_WIDE)
	fila.offset_left = 60.0
	fila.offset_right = -60.0
	fila.offset_top = 360.0
	fila.offset_bottom = 500.0
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 14)
	fila.modulate.a = 0.0
	panel.add_child(fila)
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
	create_tween().tween_property(fila, "modulate:a", 1.0, 0.3).set_delay(0.55)
	_reveal_close_button(panel, alto)


# ------------------------------------------------------------------- álbum

func _open_album() -> void:
	if state != State.READY:
		return
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

	var pescados := GameState.fish_album.size()
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
	cerrar.pressed.connect(func() -> void: overlay.queue_free())


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
	panel.offset_left = -230.0
	panel.offset_right = 230.0
	panel.offset_top = -260.0
	panel.offset_bottom = 260.0
	veil.add_child(panel)
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = FishData.get_icon(fish_id)
	ic.position = Vector2((460.0 - 170.0) * 0.5, 42.0)
	ic.size = Vector2(170, 170)
	panel.add_child(ic)
	_centered_label(panel, str(FishData.get_fish(fish_id).get("name", fish_id)),
		32, 220.0)
	_centered_label(panel, str(rareza.get("name", "")), 22, 262.0,
		Color(rareza.get("color", Color.GRAY)))
	var premio := _centered_label(panel, "Premio: " + FishData.reward_text(fish_id),
		22, 300.0, Color(0.2, 0.45, 0.12))
	premio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	premio.offset_left = 40.0
	premio.offset_right = -40.0
	premio.offset_bottom = 300.0 + 76.0
	_centered_label(panel, "Pescado %d veces"
		% int(GameState.fish_album.get(fish_id, 0)), 19, 386.0, FADED)
	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	PrepBoard.skin_button(cerrar)
	cerrar.add_theme_font_size_override("font_size", 24)
	cerrar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	cerrar.offset_left = 130.0
	cerrar.offset_right = -130.0
	cerrar.offset_top = 424.0
	cerrar.offset_bottom = 486.0
	panel.add_child(cerrar)
	cerrar.pressed.connect(func() -> void: veil.queue_free())
