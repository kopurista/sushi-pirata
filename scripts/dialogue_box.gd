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
##   "pablo"    → el capitán del nivel 5, también a la DERECHA (comparte cuadro
##                con David).
## El que NO habla se queda en pantalla apagado y un poco más abajo.
##
## Una línea puede llevar `side` ("left"/"right") para forzar el lado SOLO en
## esa escena: Saverio y Pablo son los dos de la derecha y juntos se turnaban
## el mismo hueco, así que en la tienda Pablo pasa a la izquierda.
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
	# Capitán del nivel 5. Sale a la DERECHA porque comparte pantalla con David,
	# que ocupa siempre la izquierda.
	"pablo": {
		"dir": "res://assets/characters/pablo", "file": "pablo",
		"name": "Pablo el Rubio", "side": "right", "plate": "left", "mood": "serio",
	},
	# CAI, el pirata-pescador japonés de la Isla de Gades. Habla poco y mal
	# (solo sabe japonés), así que sus líneas son cortas y a veces son un "..."
	# — para eso está su expresión `callado`. Como Saverio y Pablo, sale a la
	# DERECHA: la izquierda es siempre de David.
	"cai": {
		"dir": "res://assets/characters/cai", "file": "cai",
		"name": "Cai", "side": "right", "plate": "left", "mood": "serio",
	},
}
const DEFAULT_SPEAKER := "david"

## GEOMETRÍA de la caja y los retratos, en offsets desde el borde INFERIOR.
## Van en constantes porque el alto de la caja y el apoyo de los retratos tienen
## que moverse juntos: subir solo la caja dejaba a los personajes flotando.
const PANEL_TOP := -406.0
const PANEL_BOTTOM := -12.0
const PORTRAIT_TOP := -860.0
const PORTRAIT_BOTTOM := -390.0
## Cuerpo del texto y margen a cada lado. El margen tiene que dejar fuera los
## rodillos dibujados del pergamino (~52 px) y algo de aire; más allá de eso,
## cuanto más estrecho mejor, porque cada píxel que se le quita al margen es
## ancho de renglón. Medido con la fuente real: a cuerpo 34 y margen 76 la
## línea más larga del guion cabe en 6 renglones (264 px), y la caja da 282.
const TEXT_SIZE := 34
const TEXT_MARGIN := 76.0

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
## Cuánto se oscurece lo que hay detrás mientras se habla. Es el mismo gesto
## que hace el foco de los guiones (story_director), para que hablar se vea
## igual en todo el juego: el fondo baja y la caja se lee sola.
const VEIL_ALPHA := 0.42
## Entrada y salida de la caja. La salida es más corta: al despedirse encadena
## con el fundido a negro de la pantalla y alargarla se hacía pesado.
const FADE_IN := 0.22
const FADE_OUT := 0.16
## Lo que sube la caja entera al entrar (y baja al salir), en píxeles.
const FADE_RISE := 34.0

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
var _raise_amount := RAISE
## Con esto puesto, agotar la cola no oculta la caja (ver say()).
var _keep_open := false

var _panel: Control
var _name_plate: Control
var _name_label: Label
var _text: RichTextLabel
var _next_hint: TextureRect
var _hint_tween: Tween = null
var _raise_tween: Tween = null

## Retratos por lado y quién ocupa cada uno ("" = vacío).
var _portraits := {}
var _stage := { "left": "", "right": "" }
var _portrait_home_y := 0.0
var _panel_home_y := 0.0
## Velo que oscurece el fondo mientras se habla, y el tween de entrada/salida.
var _veil: ColorRect = null
var _fade_tween: Tween = null
## Mientras se va, la caja YA NO se queda con el puntero: si no, los ~0.16 s de
## la salida se comían el primer toque del jugador justo cuando el guion le
## acaba de dar el turno (`story_director._play`).
var _closing := false
## Los guiones ponen su PROPIO velo (o el foco circular), así que ahí este se
## apaga para no oscurecer dos veces.
var veil_on := true:
	set(value):
		veil_on = value
		if _veil != null:
			_veil.visible = value


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# SIN anclas a propósito (anclas a cero + tamaño explícito): bajo un
	# CanvasLayer, FULL_RECT se resuelve contra la VENTANA física y en una
	# pantalla escalada pisa el tamaño (o lo deja a 0×0 y el texto sale en
	# columna). El tamaño es el LIENZO VISIBLE, no el 720×1280 de diseño: en un
	# iPhone (pantalla más alta, aspect expand) el lienzo mide ~720×1560 y con
	# el alto fijo la caja quedaba flotando a media cuarta del borde.
	position = Vector2.ZERO
	size = GameState.canvas_size()
	# Se traga los toques de TODA la pantalla mientras esté visible (ver _input).
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	modulate.a = 0.0

	# VELO: oscurece lo que hay detrás mientras se habla. Va el primero de
	# todos, así que queda por debajo de los retratos y de la caja.
	_veil = ColorRect.new()
	_veil.color = Color(0, 0, 0, VEIL_ALPHA)
	_veil.position = Vector2.ZERO
	_veil.size = GameState.canvas_size()
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.visible = veil_on
	add_child(_veil)

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
		p.offset_top = PORTRAIT_TOP
		p.offset_bottom = PORTRAIT_BOTTOM
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.visible = false
		add_child(p)
		_portraits[side] = p
	_portrait_home_y = PORTRAIT_TOP

	# La caja: pergamino a lo ancho de la parte inferior.
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 10.0
	_panel.offset_right = -10.0
	_panel.offset_top = PANEL_TOP
	_panel.offset_bottom = PANEL_BOTTOM
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))
	_panel_home_y = _panel.offset_top

	# Tablón con el nombre, montado sobre el borde superior de la caja. Cambia
	# de lado según hable el de la izquierda o el de la derecha.
	_name_plate = Control.new()
	_name_plate.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_name_plate.offset_top = -26.0
	_name_plate.offset_bottom = PrepBoard.PLATE_H - 26.0
	_name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_name_plate)
	# Tablilla con clavos, no el tablón de un botón: se estira SOLO a lo ancho,
	# así que los clavos de los extremos se quedan en su sitio y la madera crece
	# o encoge con la cantidad de letras del nombre (ver `_fit_plate`).
	_name_plate.add_child(PrepBoard.make_hstretch_patch(
		PrepBoard.PLATE_TEX, PrepBoard.PLATE_CAP))
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
	_text.offset_left = TEXT_MARGIN
	_text.offset_top = 56.0
	_text.offset_right = -TEXT_MARGIN
	_text.offset_bottom = -50.0
	_text.add_theme_font_size_override("normal_font_size", TEXT_SIZE)
	_text.add_theme_font_size_override("bold_font_size", TEXT_SIZE)
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
	# ICONO DIBUJADO, no el carácter "▶": como glifo dependía de la fuente del
	# sistema y en el móvil salía como un cuadro o no se veía.
	#
	# EL LATIDO VA DENTRO DE UN HUECO PROPIO, y con valores ABSOLUTOS. Antes el
	# tween movía `position:x` con `as_relative()` sobre el nodo anclado: si se
	# mataba a mitad de la ida (cada línea nueva lo rehace) la flecha se quedaba
	# desplazada y el siguiente latido partía de ahí, así que iba escapándose
	# hacia la derecha hasta salirse del pergamino. Es la misma lección que las
	# transiciones del menú: nada de `as_relative()` en algo que se repite.
	var hueco := Control.new()
	hueco.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hueco.offset_left = -TEXT_MARGIN - 56.0
	hueco.offset_top = -110.0
	hueco.offset_right = -TEXT_MARGIN
	hueco.offset_bottom = -54.0
	hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hueco.clip_contents = false
	_panel.add_child(hueco)
	_next_hint = TextureRect.new()
	_next_hint.texture = load("res://assets/ui/ic_siguiente.png")
	_next_hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_next_hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_next_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_next_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hueco.add_child(_next_hint)


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
	_fade(true)
	_advance()


## Cierra la caja y saca a los personajes de escena.
func close() -> void:
	_fade(false)
	clear_stage()


## Cierra CON su fundido y espera a que termine antes de soltar el nodo.
##
## Lo necesitan las explicaciones sueltas del menú y del mapa, que montan una
## caja por bloque: hacían `queue_free()` en cuanto llegaba `finished` y David
## desaparecía de golpe, sin el fundido que sí tienen los guiones de nivel.
func close_and_free() -> void:
	close()
	await get_tree().create_timer(FADE_OUT + 0.05).timeout
	queue_free()


## Entrada/salida suave: la caja aparece subiendo un poco y se va bajando, y el
## velo del fondo la acompaña. Antes se encendía y se apagaba de golpe, y con
## Saverio saludando en cada visita a la tienda el corte cantaba mucho.
##
## OJO: `visible` se apaga AL FINAL de la salida, no al empezar, porque
## `is_talking()` mira ese flag y quien espera a `finished` seguiría creyendo
## que ya no hay nadie hablando mientras la caja aún se ve.
func _fade(entra: bool) -> void:
	if _fade_tween != null:
		_fade_tween.kill()
	_closing = not entra
	if entra:
		# DESDE CERO cuando la caja no estaba puesta: el nodo nace con
		# `modulate.a` a 1, así que la PRIMERA aparición tweenaba de 1 a 1 y
		# David entraba de golpe (solo se le veía deslizarse los 34 px). Se
		# notaba en todas las explicaciones sueltas del menú, que crean una caja
		# nueva por bloque.
		if not visible:
			modulate.a = 0.0
		visible = true
		position.y = FADE_RISE
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_fade_tween.tween_property(self, "modulate:a", 1.0 if entra else 0.0,
		FADE_IN if entra else FADE_OUT)
	_fade_tween.tween_property(self, "position:y", 0.0 if entra else FADE_RISE,
		FADE_IN if entra else FADE_OUT)
	if not entra:
		_fade_tween.chain().tween_callback(func() -> void: visible = false)


func is_talking() -> bool:
	return visible


## Saca a un personaje de escena (su retrato desaparece).
func clear_stage() -> void:
	for side in _stage.keys():
		_stage[side] = ""
		_portraits[side].visible = false


## Sube (o baja) la caja y los retratos para dejar ver la fila de recetas.
## `alto` permite subirla MÁS de lo normal: para hablar de los extras, que
## viven en la esquina superior de la tabla y quedan más arriba que las recetas.
func set_raised(on: bool, alto := RAISE) -> void:
	if _raised == on and is_equal_approx(_raise_amount, alto):
		return
	_raised = on
	_raise_amount = alto
	var dy := -alto if on else 0.0
	if _raise_tween != null:
		_raise_tween.kill()
	_raise_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	_raise_tween.tween_property(_panel, "offset_top", _panel_home_y + dy, 0.25)
	_raise_tween.tween_property(_panel, "offset_bottom", PANEL_BOTTOM + dy, 0.25)
	for side in _portraits.keys():
		var p: TextureRect = _portraits[side]
		var sink: float = 0.0 if _is_speaking_side(side) else IDLE_SINK
		_raise_tween.tween_property(p, "offset_top",
				_portrait_home_y + dy + sink, 0.25)
		_raise_tween.tween_property(p, "offset_bottom", PORTRAIT_BOTTOM + dy + sink, 0.25)


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


## Ancho de la tablilla MEDIDO sobre el nombre que lleva puesto.
##
## Antes era fijo (288 px), así que "Gigi" nadaba en madera y un nombre largo
## se acercaba al borde. Se mide la cadena con la fuente y el cuerpo reales y se
## le suman los dos clavos, con un mínimo para que los nombres muy cortos no
## dejen una tablilla ridícula.
const PLATE_PAD := 34.0
const PLATE_MIN := 150.0


func _plate_width() -> float:
	var font := _name_label.get_theme_font("font")
	var fs := _name_label.get_theme_font_size("font_size")
	if font == null:
		return PLATE_MIN
	var w := font.get_string_size(_name_label.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	return maxf(w + PLATE_PAD * 2.0, PLATE_MIN)


func _set_plate_side(side: String) -> void:
	var w := _plate_width()
	if side == "left":
		_name_plate.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_name_plate.offset_left = 30.0
		_name_plate.offset_right = 30.0 + w
	else:
		_name_plate.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_name_plate.offset_left = -30.0 - w
		_name_plate.offset_right = -30.0
	_name_plate.offset_top = -26.0
	_name_plate.offset_bottom = PrepBoard.PLATE_H - 26.0


## Coloca al hablante en su lado, le pone la expresión y apaga al otro.
##
## `lado` fuerza el lado SOLO para esta escena. Cada personaje tiene el suyo
## fijo porque casi siempre comparte pantalla con David (izquierda), pero
## Saverio y Pablo son los dos de la derecha: juntos se turnaban el mismo hueco
## y la mitad izquierda quedaba vacía. Ahí Pablo se pasa a la izquierda.
func _set_speaker(who: String, mood: String, lado := "") -> void:
	var info: Dictionary = SPEAKERS.get(who, SPEAKERS[DEFAULT_SPEAKER])
	var side: String = lado if lado in ["left", "right"] else str(info["side"])
	# Al cambiar de lado, el hueco de siempre se queda vacío (si no, el retrato
	# se vería a la vez en los dos sitios).
	var otro: String = "right" if side == "left" else "left"
	if _stage.get(otro, "") == who:
		_stage[otro] = ""
		_portraits[otro].visible = false
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
	# Con el lado forzado, el tablón se va al CONTRARIO del retrato: encima del
	# suyo le tapaba el pecho.
	_set_plate_side(("right" if side == "left" else "left") if lado != ""
			else str(info.get("plate", "right")))
	# El que habla, a plena luz y arriba; el otro, apagado y algo hundido.
	var dy := -_raise_amount if _raised else 0.0
	for s in _portraits.keys():
		var q: TextureRect = _portraits[s]
		var hablando: bool = (s == side)
		q.modulate = Color.WHITE if hablando else IDLE_TINT
		# El que escucha se ve algo más lejos: apagado y un punto más pequeño.
		q.pivot_offset = Vector2(q.size.x * 0.5, q.size.y)
		q.scale = Vector2.ONE if hablando else Vector2(IDLE_SCALE, IDLE_SCALE)
		var sink: float = 0.0 if hablando else IDLE_SINK
		q.offset_top = _portrait_home_y + dy + sink
		q.offset_bottom = PORTRAIT_BOTTOM + dy + sink


func _advance() -> void:
	_index += 1
	if _index >= _queue.size():
		if not _keep_open:
			_fade(false)
		finished.emit()
		return
	var line: Variant = _queue[_index]
	var text: String = line if line is String else str(line.get("text", ""))
	# (el cierre de la cola se resuelve arriba, con el fundido de salida)
	var who: String = DEFAULT_SPEAKER if line is String \
			else str(line.get("who", DEFAULT_SPEAKER))
	if not SPEAKERS.has(who):
		who = DEFAULT_SPEAKER
	var mood: String = str(SPEAKERS[who]["mood"]) if line is String \
			else str(line.get("mood", SPEAKERS[who]["mood"]))
	# `side` en la línea: lado forzado para esta escena (ver _set_speaker).
	var lado: String = "" if line is String else str(line.get("side", ""))
	_set_speaker(who, mood, lado)
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
	_next_hint.position.x = 0.0
	_hint_tween = _next_hint.create_tween().set_loops()
	_hint_tween.tween_property(_next_hint, "position:x", 8.0, 0.38) \
			.set_trans(Tween.TRANS_SINE)
	_hint_tween.tween_property(_next_hint, "position:x", 0.0, 0.38) \
			.set_trans(Tween.TRANS_SINE)


## Mientras se habla, la caja se queda con TODO el puntero: toques, clics y
## arrastres, pase por donde pase.
##
## Va en `_input` y no en `_gui_input` a propósito. Con `_gui_input` solo se
## consumían los eventos TÁCTILES, y un clic de ratón genera DOS (el suyo y el
## táctil que sintetiza `emulate_touch_from_mouse`): el táctil pasaba la línea
## y el de ratón seguía su camino hasta el botón de debajo, así que tocar un
## ingrediente de la tienda para pasar el texto abría de paso su panel de
## compra. Desde `_input` se marcan como manejados los dos, antes de que la
## interfaz los vea.
func _input(event: InputEvent) -> void:
	if not visible or _closing:
		return
	var puntero := event is InputEventScreenTouch or event is InputEventScreenDrag \
		or event is InputEventMouseButton or event is InputEventMouseMotion
	if not puntero:
		return
	get_viewport().set_input_as_handled()
	# Solo el TOQUE (pulsar) avanza; el resto únicamente se traga.
	if not (event is InputEventScreenTouch and event.pressed):
		return
	# Mientras entra o sale, los toques no cuentan: si no, un doble clic al
	# despedirse se comía la frase antes de que llegara a leerse.
	if _fade_tween != null and _fade_tween.is_running():
		return
	if _typing:
		# Primer toque: la línea se muestra entera de golpe.
		_visible_chars = float(_total_chars)
		_finish_typing()
	else:
		_advance()
