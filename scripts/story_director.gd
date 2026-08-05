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

var lv: Node3D
var dialog: DialogueBox
var focus_rect: ColorRect
var focus_mat: ShaderMaterial

## Aviso que suelta Gigi si el jugador se queda parado ("" = vigía apagado).
var _recordatorio := ""
var _quieto := 0.0
var _regañando := false


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
	focus_rect.position = Vector2.ZERO
	focus_rect.size = Vector2(720.0, 1280.0)
	focus_rect.color = Color.WHITE
	focus_mat = ShaderMaterial.new()
	focus_mat.shader = load("res://shaders/tutorial_focus.gdshader")
	focus_rect.material = focus_mat
	focus_rect.visible = false
	focus_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_layer.add_child(focus_rect)

	var dialog_layer := CanvasLayer.new()
	dialog_layer.layer = 95
	add_child(dialog_layer)
	dialog = DialogueBox.new()
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
	_regañando = false


# ------------------------------------------------------------------ helpers

## Alguien habla: el juego ENTERO se pausa (clientes y platos parados) y el
## reloj queda retenido para cuando se reanude.
func _say(lines: Array) -> void:
	lv.clock_hold = true
	get_tree().paused = true
	dialog.say(lines)
	await dialog.finished
	get_tree().paused = false


## Como _say pero con la caja ELEVADA: para hablar de los pergaminos de
## recetas, que quedan justo debajo de la caja y el retrato.
func _say_raised(lines: Array) -> void:
	dialog.set_raised(true)
	await _say(lines)
	dialog.set_raised(false)


## Suelta el reloj: fase interactiva. `aviso` es lo que recordará Gigi si el
## jugador se queda parado.
func _play(aviso := "") -> void:
	lv.clock_hold = false
	_recordatorio = aviso
	_quieto = 0.0
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
	focus_rect.visible = true


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
	focus_rect.visible = false


## Espera N gestos de un tipo concreto de la tabla (craft_event).
func _wait_craft(kind: String, count := 1) -> void:
	var left := count
	while left > 0:
		var args: Array = await lv.prep_board.craft_event
		if args[0] == kind:
			left -= 1
