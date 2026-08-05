class_name DialogueBox
extends Control
## Caja de diálogo del juego: pergamino en la parte inferior, el retrato del que
## habla asomando por encima, y su nombre en un tablón de madera.
##
## HABLANTES (`who` de cada línea):
##   "david"    → David Jones, retrato a la IZQUIERDA.
##   "gigi"     → el loro. Comparte el retrato de David (es el mismo dibujo, con
##                el loro chillando con las alas abiertas), pero el tablón pone
##                "Gigi". Por eso sus moods son los `loro*`.
##   "saverio"  → el tendero, retrato a la DERECHA (para la escena de la tienda,
##                donde los dos están en pantalla a la vez).
## El que NO habla se queda en pantalla apagado y un poco más abajo.
##
## El texto se escribe letra a letra; un toque mientras escribe lo completa, y
## con la línea completa (flecha ▶ latiendo) el siguiente toque avanza. Al
## agotar la cola emite `finished`.
##
## Las PALABRAS CLAVE van entre asteriscos dobles en el guion (**cinta**) y se
## pintan en negrita y color teja, nunca en mayúsculas.
##
## `set_raised(true)` sube la caja y los retratos (~330 px): para cuando se
## habla de los pergaminos de recetas, que quedan justo debajo y los taparía.
##
## Uso:  box.say([{ "text": "...", "mood": "feliz" },
##                 { "text": "...", "who": "gigi", "mood": "loro_grito" }])
##       await box.finished
##
## Mientras está visible se traga TODOS los toques (pantalla completa) y
## funciona con el árbol en pausa (PROCESS_MODE_ALWAYS): los guiones PAUSAN el
## nivel entero al hablar (clientes y platos quietos).

signal advanced(index: int)
signal finished

const PrepBoard := preload("res://scripts/prep_board.gd")

## Ficha de cada hablante: carpeta de retratos, prefijo de archivo, nombre en el
## tablón, lado de la pantalla y expresión por defecto.
const SPEAKERS := {
	"david": {
		"dir": "res://assets/characters/david", "file": "david",
		"name": "David Jones", "side": "left", "plate": "right", "mood": "serio",
	},
	"gigi": {
		"dir": "res://assets/characters/david", "file": "david",
		"name": "Gigi", "side": "left", "plate": "left", "mood": "loro",
	},
	"saverio": {
		"dir": "res://assets/characters/saverio", "file": "saverio",
		"name": "Saverio", "side": "right", "plate": "left", "mood": "serio",
	},
}
const DEFAULT_SPEAKER := "david"

## Velocidad de la máquina de escribir (caracteres por segundo).
const CHARS_PER_SEC := 45.0
## Cuánto sube la caja en modo elevado (deja ver la fila de recetas).
const RAISE := 330.0

const DARK := Color(0.26, 0.16, 0.08)
## Color de las palabras clave (teja oscura, legible sobre pergamino).
const KEYWORD_BB := "[b][color=#a03c0e]%s[/color][/b]"
## Tinte del retrato de quien NO está hablando.
const IDLE_TINT := Color(0.52, 0.5, 0.55)
## Cuánto se hunde y se encoge el retrato de quien no habla.
const IDLE_SINK := 26.0
const IDLE_SCALE := 0.9

var _queue: Array = []
var _index := -1
var _visible_chars := 0.0
## Longitud de la línea en curso SIN los marcadores **: se calcula a mano
## porque RichTextLabel.get_total_character_count() devuelve 0 hasta que ha
## maquetado, y comparar contra 0 daba la línea por escrita en el primer
## fotograma (la máquina de escribir no llegaba a verse nunca).
var _total_chars := 0
var _typing := false
var _raised := false
## Con esto puesto, agotar la cola no oculta la caja (ver say()).
var _keep_open := false

var _panel: Control
var _name_plate: Control
var _name_label: Label
var _text: RichTextLabel
var _next_hint: Label
var _hint_tween: Tween = null
var _raise_tween: Tween = null

## Retratos por lado y quién ocupa cada uno ("" = vacío).
var _portraits := {}
var _stage := { "left": "", "right": "" }
var _portrait_home_y := 0.0
var _panel_home_y := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# SIN anclas a propósito (anclas a cero + tamaño de diseño explícito): bajo
	# un CanvasLayer, FULL_RECT se resuelve contra la VENTANA física y en una
	# pantalla escalada pisa el tamaño (o lo deja a 0×0 y el texto sale en
	# columna). El viewport de diseño del juego es fijo: 720×1280.
	position = Vector2.ZERO
	size = Vector2(720.0, 1280.0)
	# Se traga los toques de TODA la pantalla mientras esté visible.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	# Los dos retratos, apoyados sobre el borde superior de la caja.
	for side in ["left", "right"]:
		var p := TextureRect.new()
		p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT if side == "left"
				else Control.PRESET_BOTTOM_RIGHT)
		if side == "left":
			p.offset_left = 6.0
			p.offset_right = 386.0
		else:
			p.offset_left = -386.0
			p.offset_right = -6.0
		p.offset_top = -804.0
		p.offset_bottom = -334.0
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.visible = false
		add_child(p)
		_portraits[side] = p
	_portrait_home_y = -804.0

	# La caja: pergamino a lo ancho de la parte inferior.
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 10.0
	_panel.offset_right = -10.0
	_panel.offset_top = -350.0
	_panel.offset_bottom = -12.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_panel.add_child(PrepBoard.make_nine_patch("res://assets/ui/panel.png", 44))
	_panel_home_y = _panel.offset_top

	# Tablón con el nombre, montado sobre el borde superior de la caja. Cambia
	# de lado según hable el de la izquierda o el de la derecha.
	_name_plate = Control.new()
	_name_plate.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_name_plate.offset_top = -30.0
	_name_plate.offset_bottom = 34.0
	_name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_name_plate)
	_name_plate.add_child(PrepBoard.make_nine_patch("res://assets/ui/boton_madera.png", 26))
	_name_label = Label.new()
	_name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 27)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.8))
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 9)
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_name_label.add_theme_constant_override("shadow_offset_x", 3)
	_name_label.add_theme_constant_override("shadow_offset_y", 3)
	# Negrita CURSIVA: la Exo 2 trae su propio archivo BoldItalic.
	var plate_font := load("res://fonts/static/Exo2-BoldItalic.ttf")
	if plate_font != null:
		_name_label.add_theme_font_override("font", plate_font)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_plate.add_child(_name_label)
	_set_plate_side("left")

	# El texto de la línea en curso, bien alejado de los rodillos laterales del
	# pergamino (con 52 px los bordes dibujados tapaban el texto).
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text.offset_left = 95.0
	_text.offset_top = 56.0
	_text.offset_right = -95.0
	_text.offset_bottom = -50.0
	_text.add_theme_font_size_override("normal_font_size", 27)
	_text.add_theme_font_size_override("bold_font_size", 27)
	_text.add_theme_color_override("default_color", DARK)
	_text.add_theme_constant_override("line_separation", 3)
	# Maqueta el texto ENTERO y luego lo va destapando. Con el modo por
	# defecto el salto de línea se recalcula a cada carácter, así que una
	# palabra empezaba en un renglón y saltaba de golpe al siguiente.
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	var bold := load("res://fonts/static/Exo2-Bold.ttf")
	if bold != null:
		_text.add_theme_font_override("bold_font", bold)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_text)
	_text.visible_characters = 0

	# Flecha de "toca para seguir" (▶), latiendo hacia la derecha. Va DENTRO de
	# los márgenes del pergamino: pegada al borde se metía bajo el rodillo
	# dibujado y no se veía.
	_next_hint = Label.new()
	_next_hint.text = "▶"
	_next_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_next_hint.offset_left = -142.0
	_next_hint.offset_top = -104.0
	_next_hint.offset_right = -102.0
	_next_hint.offset_bottom = -64.0
	_next_hint.add_theme_font_size_override("font_size", 30)
	_next_hint.add_theme_color_override("font_color", Color(0.63, 0.4, 0.1))
	_next_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_next_hint)


## Muestra una tanda de líneas. Cada línea puede ser un String o un Dictionary
## { "text": String, "mood": String, "who": String }. Al terminar la tanda, la
## caja se oculta y se emite `finished`.
## `keep_open`: al agotar la cola la caja NO se oculta, solo emite `finished`.
## Lo usan los guiones para encadenar tandas sin que la caja y el retrato
## parpadeen un par de fotogramas mientras se recoloca el foco.
func say(lines: Array, keep_open := false) -> void:
	_queue = lines.duplicate()
	_index = -1
	_keep_open = keep_open
	visible = true
	_advance()


## Cierra la caja y saca a los personajes de escena.
func close() -> void:
	visible = false
	clear_stage()


func is_talking() -> bool:
	return visible


## Saca a un personaje de escena (su retrato desaparece).
func clear_stage() -> void:
	for side in _stage.keys():
		_stage[side] = ""
		_portraits[side].visible = false


## Sube (o baja) la caja y los retratos para dejar ver la fila de recetas.
func set_raised(on: bool) -> void:
	if _raised == on:
		return
	_raised = on
	var dy := -RAISE if on else 0.0
	if _raise_tween != null:
		_raise_tween.kill()
	_raise_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	_raise_tween.tween_property(_panel, "offset_top", _panel_home_y + dy, 0.25)
	_raise_tween.tween_property(_panel, "offset_bottom", -12.0 + dy, 0.25)
	for side in _portraits.keys():
		var p: TextureRect = _portraits[side]
		var sink: float = 0.0 if _is_speaking_side(side) else IDLE_SINK
		_raise_tween.tween_property(p, "offset_top",
				_portrait_home_y + dy + sink, 0.25)
		_raise_tween.tween_property(p, "offset_bottom", -334.0 + dy + sink, 0.25)


## Convierte los marcadores **palabra** del guion en negrita de color.
static func format_keywords(t: String) -> String:
	var parts := t.split("**")
	var out := ""
	for i in parts.size():
		out += parts[i] if i % 2 == 0 else KEYWORD_BB % parts[i]
	return out


# ------------------------------------------------------------------ internos

func _is_speaking_side(side: String) -> bool:
	var p: TextureRect = _portraits[side]
	return p.visible and p.modulate.is_equal_approx(Color.WHITE)


func _set_plate_side(side: String) -> void:
	if side == "left":
		_name_plate.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_name_plate.offset_left = 30.0
		_name_plate.offset_right = 318.0
	else:
		_name_plate.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_name_plate.offset_left = -318.0
		_name_plate.offset_right = -30.0
	_name_plate.offset_top = -30.0
	_name_plate.offset_bottom = 34.0


## Coloca al hablante en su lado, le pone la expresión y apaga al otro.
func _set_speaker(who: String, mood: String) -> void:
	var info: Dictionary = SPEAKERS.get(who, SPEAKERS[DEFAULT_SPEAKER])
	var side: String = info["side"]
	_stage[side] = who
	var path := "%s/%s_%s.png" % [info["dir"], info["file"], mood]
	if not ResourceLoader.exists(path):
		path = "%s/%s_%s.png" % [info["dir"], info["file"], info["mood"]]
	var p: TextureRect = _portraits[side]
	if ResourceLoader.exists(path):
		p.texture = load(path)
	p.visible = true
	_name_label.text = str(info["name"])
	# Cada hablante tiene su lado de tablón FIJO (`plate`): David a la derecha,
	# Gigi a la izquierda. Así se distingue de un vistazo quién está hablando.
	_set_plate_side(str(info.get("plate", "right")))
	# El que habla, a plena luz y arriba; el otro, apagado y algo hundido.
	var dy := -RAISE if _raised else 0.0
	for s in _portraits.keys():
		var q: TextureRect = _portraits[s]
		var hablando: bool = (s == side)
		q.modulate = Color.WHITE if hablando else IDLE_TINT
		# El que escucha se ve algo más lejos: apagado y un punto más pequeño.
		q.pivot_offset = Vector2(q.size.x * 0.5, q.size.y)
		q.scale = Vector2.ONE if hablando else Vector2(IDLE_SCALE, IDLE_SCALE)
		var sink: float = 0.0 if hablando else IDLE_SINK
		q.offset_top = _portrait_home_y + dy + sink
		q.offset_bottom = -334.0 + dy + sink


func _advance() -> void:
	_index += 1
	if _index >= _queue.size():
		if not _keep_open:
			visible = false
		finished.emit()
		return
	var line: Variant = _queue[_index]
	var text: String = line if line is String else str(line.get("text", ""))
	var who: String = DEFAULT_SPEAKER if line is String \
			else str(line.get("who", DEFAULT_SPEAKER))
	if not SPEAKERS.has(who):
		who = DEFAULT_SPEAKER
	var mood: String = str(SPEAKERS[who]["mood"]) if line is String \
			else str(line.get("mood", SPEAKERS[who]["mood"]))
	_set_speaker(who, mood)
	_text.text = format_keywords(text)
	# El contador va sobre el texto SIN los marcadores: es lo que se ve.
	_total_chars = text.replace("**", "").length()
	_visible_chars = 0.0
	_text.visible_characters = 0
	_typing = _total_chars > 0
	_next_hint.visible = not _typing
	if not _typing:
		_finish_typing()
	advanced.emit(_index)


func _process(delta: float) -> void:
	if not visible or not _typing:
		return
	_visible_chars += CHARS_PER_SEC * delta
	_text.visible_characters = int(_visible_chars)
	if int(_visible_chars) >= _total_chars:
		_finish_typing()


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_next_hint.visible = true
	if _hint_tween != null:
		_hint_tween.kill()
	_hint_tween = _next_hint.create_tween().set_loops()
	_hint_tween.tween_property(_next_hint, "position:x", 7.0, 0.38) \
			.as_relative().set_trans(Tween.TRANS_SINE)
	_hint_tween.tween_property(_next_hint, "position:x", -7.0, 0.38) \
			.as_relative().set_trans(Tween.TRANS_SINE)


func _gui_input(event: InputEvent) -> void:
	# SOLO eventos táctiles. Con `pointing/emulate_touch_from_mouse` un clic
	# genera DOS eventos (el de ratón y el táctil sintetizado) y llegaban los
	# dos seguidos: el primero avanzaba de línea y el segundo la completaba de
	# golpe, así que solo la PRIMERA línea de cada tanda se veía escribirse.
	if not (event is InputEventScreenTouch and event.pressed):
		return
	accept_event()
	if _typing:
		# Primer toque: la línea se muestra entera de golpe.
		_visible_chars = float(_total_chars)
		_finish_typing()
	else:
		_advance()
