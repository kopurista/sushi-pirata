class_name StoryDirector
extends Node
## Base de los guiones narrados sobre level3d: el del TUTORIAL
## (tutorial_director.gd) y los de los primeros niveles de la campaña
## (level_director.gd). Aquí vive todo lo que comparten.
##
## MIENTRAS ALGUIEN HABLA EL JUEGO ENTERO SE PAUSA (get_tree().paused):
## clientes quietos, platos quietos, cinta quieta y reloj retenido. La caja de
## diálogo y el director van en PROCESS_MODE_ALWAYS, así que el guion sigue
## corriendo con el árbol parado.
##
## Además ilumina con un FOCO CIRCULAR degradado el elemento del que se habla
## (todo lo demás se oscurece) y, si el jugador se queda quieto INACTIVIDAD
## segundos con un aviso puesto, Gigi le pega un grito.
##
## Las clases hijas solo tienen que implementar `_run()`.

## Segundos de quietud antes de que Gigi espabile al jugador.
const INACTIVIDAD := 10.0
## Respiro antes de que alguien hable cuando se venía de jugar: que una acción
## del jugador no dispare un diálogo en el mismo fotograma.
const PAUSA_ANTES := 0.3
## Cuánto se oscurece la pantalla: FUERTE alrededor del foco, SUAVE cuando solo
## se está hablando (ahí no se señala nada, solo se baja el ruido de fondo).
const DIM_FOCO := 0.62
const DIM_SUAVE := 0.34

var lv: Node3D
var dialog: DialogueBox
var focus_rect: ColorRect
var focus_mat: ShaderMaterial

## Aviso que suelta Gigi si el jugador se queda parado ("" = vigía apagado).
var _recordatorio := ""
var _quieto := 0.0
var _regañando := false
## Fundido del oscurecido (ver `_fade_dim`).
var _dim_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	lv = get_parent()
	# Foco circular: un solo paño a pantalla completa con agujero degradado.
	var focus_layer := CanvasLayer.new()
	focus_layer.layer = 90
	add_child(focus_layer)
	focus_rect = ColorRect.new()
	# SIN anclas a propósito: bajo un CanvasLayer, FULL_RECT se resuelve contra
	# la VENTANA física (p. ej. 1450×2560 en una pantalla 2x) y pisa el tamaño
	# al entrar al árbol. Con anclas a cero, posición y tamaño de DISEÑO se
	# quedan como están y el estiramiento del proyecto los lleva a pantalla.
	# Tamaño del LIENZO VISIBLE, no 720×1280: en un iPhone el lienzo es más
	# alto y el paño dejaba una franja SIN oscurecer abajo (con la caja de
	# diálogo levantada se veía clarísimo).
	focus_rect.position = Vector2.ZERO
	focus_rect.size = GameState.canvas_size()
	focus_rect.color = Color.WHITE
	focus_mat = ShaderMaterial.new()
	focus_mat.shader = load("res://shaders/tutorial_focus.gdshader")
	focus_rect.material = focus_mat
	# Los uniformes se fijan YA: si el paño se hacía visible antes de que
	# llegaran, el primer fotograma se dibujaba con los valores por defecto del
	# shader (pantalla oscura con un agujero en el centro) y se veía un
	# parpadeo negro justo al aparecer el primer foco.
	_apagar_velo()
	focus_rect.visible = true
	focus_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_layer.add_child(focus_rect)

	var dialog_layer := CanvasLayer.new()
	dialog_layer.layer = 95
	add_child(dialog_layer)
	dialog = DialogueBox.new()
	# Aquí el oscurecido lo lleva el guion (el foco circular, o `_soft_dim`
	# cuando no hay foco), así que la caja no pone el suyo: se sumaban los dos
	# y hablar dejaba el nivel casi negro.
	dialog.veil_on = false
	dialog_layer.add_child(dialog)
	_run.call_deferred()


## El guion. Lo implementa cada director.
func _run() -> void:
	pass


## Gancho por fotograma para las clases hijas (el tutorial clava la paciencia).
func _tick(_delta: float) -> void:
	pass


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag \
			or event is InputEventMouseButton or event is InputEventMouseMotion:
		_quieto = 0.0


func _process(delta: float) -> void:
	_tick(delta)
	_vigilar_inactividad(delta)


## Gigi despierta al jugador si lleva un buen rato sin tocar nada. No salta si
## hay alguien hablando ni a media faena (un gesto sostenido se arruinaría).
func _vigilar_inactividad(delta: float) -> void:
	if _recordatorio == "" or _regañando or dialog.is_talking():
		_quieto = 0.0
		return
	if lv.prep_board.is_gesture_locked():
		_quieto = 0.0
		return
	_quieto += delta
	if _quieto < INACTIVIDAD:
		return
	_quieto = 0.0
	_espabila()


func _espabila() -> void:
	_regañando = true
	var aviso := _recordatorio
	await _say([
		{ "text": "¡ESPABILA, grumete! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
		{ "text": aviso, "who": "gigi", "mood": "loro" },
	])
	# `_say` deja la caja ABIERTA (keep_open) porque los guiones encadenan
	# tandas; aquí no viene ninguna detrás, así que hay que cerrarla a mano o se
	# queda puesta tapando el juego.
	dialog.close()
	_regañando = false


# ------------------------------------------------------------------ helpers

## Alguien habla: el juego ENTERO se pausa (clientes y platos parados) y el
## reloj queda retenido para cuando se reanude.
## `espera` sustituye al respiro por defecto (algunos momentos piden más).
## `congelar` a false deja el juego CORRIENDO mientras se habla: para cuando lo
## interesante es justo lo que está pasando detrás (un cliente que se marcha).
func _say(lines: Array, espera := -1.0, congelar := true) -> void:
	# Si veníamos de jugar, un respiro antes de hablar.
	if not lv.clock_hold:
		await get_tree().create_timer(
				PAUSA_ANTES if espera < 0.0 else espera).timeout
	# El reloj se retiene SIEMPRE mientras alguien habla; `congelar` solo decide
	# si además se para el árbol (a veces interesa ver lo que pasa detrás).
	lv.clock_hold = true
	get_tree().paused = congelar
	# Sin foco puesto, el fondo se oscurece un poco igualmente mientras hablan.
	var velo_propio: bool = float(focus_mat.get_shader_parameter("dim")) <= 0.0
	if velo_propio:
		_soft_dim()
	# `keep_open`: la caja NO se oculta al agotar la tanda. Entre dos tandas
	# seguidas se recoloca el foco, y ocultarla dejaba un parpadeo en el que
	# desaparecían el retrato y el pergamino.
	dialog.say(lines, true)
	await dialog.finished
	get_tree().paused = false
	if velo_propio:
		_apagar_velo()


## Como _say pero con la caja ELEVADA: para hablar de los pergaminos de
## recetas, que quedan justo debajo de la caja y el retrato.
func _say_raised(lines: Array, espera := -1.0,
		alto := DialogueBox.RAISE) -> void:
	dialog.set_raised(true, alto)
	await _say(lines, espera)
	dialog.set_raised(false, alto)


## Suelta el reloj: fase interactiva. `aviso` es lo que recordará Gigi si el
## jugador se queda parado.
func _play(aviso := "") -> void:
	lv.clock_hold = false
	_recordatorio = aviso
	_quieto = 0.0
	dialog.close()
	_clear_focus()


## FOCO circular sobre un rectángulo de pantalla (en píxeles de diseño).
## El radio sale del LADO MAYOR, no de la diagonal: con la diagonal un botón de
## receta pedía 135 px de radio y el círculo se comía media tabla.
func _focus_screen_rect(r: Rect2) -> void:
	var c := r.position + r.size * 0.5
	var radius: float = clampf(maxf(r.size.x, r.size.y) * 0.5 + 10.0, 48.0, 150.0)
	focus_mat.set_shader_parameter("center", c)
	focus_mat.set_shader_parameter("radius", radius)
	focus_mat.set_shader_parameter("feather", clampf(radius * 0.55, 34.0, 100.0))
	_fade_dim(DIM_FOCO)


## Velo LEVE de pantalla completa, sin agujero: solo para hablar.
func _soft_dim() -> void:
	focus_mat.set_shader_parameter("center", Vector2(-999.0, -999.0))
	focus_mat.set_shader_parameter("radius", 0.0)
	focus_mat.set_shader_parameter("feather", 0.001)
	_fade_dim(DIM_SUAVE)


## Foco sobre un Control. ESPERA DOS FOTOGRAMAS antes de medirlo: los
## contenedores de Godot recolocan a sus hijos de forma DIFERIDA, así que justo
## después de tocar `allowed_recipes` el botón sigue en su sitio VIEJO — de ahí
## que el círculo del nigiri y el del té cayeran al lado del pergamino en vez
## de encima.
func _focus_node(c: Control, pad := 10.0) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_focus_screen_rect(c.get_global_rect().grow(pad))


## Foco sobre un cliente 3D: se proyecta su posición con la cámara (fija).
func _focus_client(c: Node3D) -> void:
	if c == null or not is_instance_valid(c):
		return
	var p: Vector2 = lv.cam.unproject_position(
		c.global_position + Vector3.UP * 0.9)
	_focus_screen_rect(Rect2(p - Vector2(95, 130), Vector2(190, 260)))


## Foco sobre una de las barras flotantes de un cliente (viven en `world_ui`,
## así que su posición ya está en píxeles de pantalla).
func _focus_bar(bar: Control) -> void:
	if bar == null:
		return
	_focus_screen_rect(Rect2(bar.position - Vector2(30, 30),
			bar.size + Vector2(60, 60)))


func _clear_focus() -> void:
	_apagar_velo()


## Deja el paño transparente (sigue en el árbol, para no volver a estrenar el
## shader y provocar otro parpadeo).
func _apagar_velo() -> void:
	focus_mat.set_shader_parameter("center", Vector2(-9999.0, -9999.0))
	focus_mat.set_shader_parameter("radius", 0.0)
	focus_mat.set_shader_parameter("feather", 0.001)
	focus_mat.set_shader_parameter("dim", 0.0)
	if _dim_tween != null and _dim_tween.is_valid():
		_dim_tween.kill()


## El oscurecido entra y sale CON FUNDIDO. Saltando de 0 a 0.78 de golpe se veía
## como un fogonazo negro cada vez que cambiaba el foco.
func _fade_dim(target: float) -> void:
	if _dim_tween != null and _dim_tween.is_valid():
		_dim_tween.kill()
	var actual := float(focus_mat.get_shader_parameter("dim"))
	_dim_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_dim_tween.tween_method(
		func(v: float) -> void: focus_mat.set_shader_parameter("dim", v),
		actual, target, 0.22)


## Espera N gestos de un tipo concreto de la tabla (craft_event).
func _wait_craft(kind: String, count := 1) -> void:
	var left := count
	while left > 0:
		var args: Array = await lv.prep_board.craft_event
		if args[0] == kind:
			left -= 1
