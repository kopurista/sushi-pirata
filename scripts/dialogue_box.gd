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
	# Capitán del escenario 23. Sale a la DERECHA porque comparte pantalla con David,
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
	# ALICE, la aprendiza de cocinera: gótica y mona a la vez (kimono negro con
	# ribete violeta, obi granate, delantal blanco y un lirio en el pelo). Busca
	# a su maestra, Miku. Sale como CLIENTA en su escenario y al superarlo se
	# enrola, y desde entonces es LA AYUDANTE de la tabla.
	#
	# Es tímida, así que tiene `callado` como Cai: para las líneas en las que se
	# queda sin contestar. Como todos menos David, sale a la DERECHA.
	"alice": {
		"dir": "res://assets/characters/alice", "file": "alice",
		"name": "Alice", "side": "right", "plate": "left", "mood": "serio",
	},
	# LOS CLIENTES DE SIEMPRE, sin nombre propio: cuando a un guion le hace
	# falta que hable el que está sentado en la barra (el pirata del 15 y
	# su bandera). Como Saverio, Pablo y Cai salen a la DERECHA: la izquierda es
	# siempre de David.
	#
	# CADA TIPO TIENE SUS DOS GÉNEROS, con el mismo diseño que su modelo 3D. El
	# hablante femenino se pide con el sufijo "_f" y quien lo saca de un guion
	# NO lo escribe a mano: `speaker_for(tipo, genero)` lo compone, así que el
	# retrato de la caja siempre es el del cliente que hay en el taburete.
	"grumete": {
		"dir": "res://assets/characters/grumete", "file": "grumete",
		"name": "Grumete", "side": "right", "plate": "left", "mood": "serio",
	},
	"grumete_f": {
		"dir": "res://assets/characters/grumete_f", "file": "grumete_f",
		"name": "Grumete", "side": "right", "plate": "left", "mood": "serio",
	},
	"pirata": {
		"dir": "res://assets/characters/pirata", "file": "pirata",
		"name": "Pirata", "side": "right", "plate": "left", "mood": "serio",
	},
	"pirata_f": {
		"dir": "res://assets/characters/pirata_f", "file": "pirata_f",
		"name": "Pirata", "side": "right", "plate": "left", "mood": "serio",
	},
	"capitan": {
		"dir": "res://assets/characters/capitan", "file": "capitan",
		"name": "Capitán", "side": "right", "plate": "left", "mood": "serio",
	},
	"capitan_f": {
		"dir": "res://assets/characters/capitan_f", "file": "capitan_f",
		"name": "Capitana", "side": "right", "plate": "left", "mood": "serio",
	},
	# EL JEFE del mar 1. Entrañable pero con un hambre terrible: serio,
	# hablando, enfadado, feliz y dormido (le encanta dormir después de comer).
	"kappa": {
		"dir": "res://assets/characters/kappa", "file": "kappa",
		"name": "Kappa", "side": "right", "plate": "left", "mood": "serio",
	},
	# MAR 2 --- MIKU, la maestra de Alice: chef japonesa, gafas y flequillo,
	# muy buena persona. Enseña el SUSHI RUSH a cambio de un barco de sushi.
	"miku": {
		"dir": "res://assets/characters/miku", "file": "miku",
		"name": "Miku", "side": "right", "plate": "left", "mood": "serio",
	},
	# --- NACH, capitán pirata orgulloso (calvo, solo bigote). Conoce a Alice
	# y enseña el bonificador del barco combinado.
	"nach": {
		"dir": "res://assets/characters/nach", "file": "nach",
		"name": "Nach", "side": "right", "plate": "left", "mood": "serio",
	},
	# --- LA SIRENA, la jefa del mar 2: orgullosa y de voz hipnótica. Seis
	# moods, y "cantando" (ojos cerrados, notas al aire) es el suyo propio.
	"sirena": {
		"dir": "res://assets/characters/sirena", "file": "sirena",
		"name": "Sirena", "side": "right", "plate": "left", "mood": "serio",
	},
}

## Hablante de un CLIENTE por tipo y género: "pirata" o "pirata_f". Se pasa el
## `gender` del propio `client3d`, así que el retrato de la caja es siempre el
## del que está sentado en la barra. Si faltara el femenino, cae al masculino en
## vez de dejar la caja sin retrato.
## LA LETRA DEL TIPO DE CLIENTE ("E"/"A"/"G") NO ES EL NOMBRE DEL HABLANTE.
## `client3d.client_type` guarda la letra, y quien le pasaba esa letra a
## `speaker_for` se llevaba el hablante por defecto -o sea DAVID- sin ningun
## error: en el escenario 16 era David quien decia el "yo no pago con oro" del
## capitan del tesoro. Se traduce aqui y no en cada llamada, para que ningun
## sitio nuevo vuelva a pisar la misma piedra.
const CLIENT_SPEAKERS := { "E": "grumete", "A": "pirata", "G": "capitan" }


static func speaker_for(tipo: String, genero: String) -> String:
	tipo = str(CLIENT_SPEAKERS.get(tipo, tipo))
	var fem := "%s_f" % tipo
	if genero == CharacterData.FEMALE and SPEAKERS.has(fem):
		return fem
	return tipo if SPEAKERS.has(tipo) else DEFAULT_SPEAKER
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

## RETRATOS EN 3D (prototipo del 2-9-2026, pedido por el usuario: "dejar de
## utilizar arte dibujado" en los diálogos). El hablante que TIENE RIG se
## dibuja VIVO dentro de un SubViewport del tamaño del retrato, con la misma
## luz floja y el mismo encuadre de busto del cartel de recompensa; el
## TextureRect de siempre recibe la textura del viewport, así que el tinte,
## el hundido y la escala del que escucha siguen funcionando igual. Los que no
## tienen modelo (David, Gigi, Saverio) siguen con su dibujo.
const RETRATO_3D := true
## Hablante → [personaje de CharacterData.MODELS, género].
const RETRATO_3D_QUIEN := {
	"cai": ["cai", "m"], "pablo": ["pablo", "m"], "alice": ["alice", "f"],
	"miku": ["miku", "f"], "nach": ["nach", "m"], "kappa": ["kappa", "m"],
	"sirena": ["sirena", "f"],
	"grumete": ["grumete", "m"], "grumete_f": ["grumete", "f"],
	"pirata": ["pirata", "m"], "pirata_f": ["pirata", "f"],
	"capitan": ["capitan", "m"], "capitan_f": ["capitan", "f"],
}
## Hablantes que NO se llaman como su personaje en CharacterData.MODELS: Gigi
## habla con el retrato de David (es su loro, va posada en su hombro) y el
## tendero se llama Saverio.
## (R3D_YAW_VUELTA, el giro al reves de David para enseñar el hombro del
## loro, se retiro: con el giro bien puesto, el de la izquierda gira hacia
## la derecha y su hombro derecho —el de Gigi— viene HACIA la camara.)
const RETRATO_3D_QUIEN_EXTRA := {
	"gigi": ["david", "m"], "david": ["david", "m"], "saverio": ["saverio", "m"],
}
## Hablantes con modelo PROPIO fuera de CharacterData.MODELS. Hoy ninguno: el
## David de juguete (Meshy sin rig, `david_toy.glb`) se sustituyo por el David
## de la cadena v5, que esta rigueado y gesticula como el resto.
const RETRATO_3D_RUTA := {}
## Acompañantes que van POSADOS en un hueso del personaje. Gigi es un modelo
## APARTE y no parte del de David: en el paso a 3D el loro del concepto se
## perdía (Meshy lo fundía con el hombro), y separada se le puede dar su propio
## movimiento. Va colgada del hueso, así que sigue al hombro cuando David se
## mueve, con un desvío medido en fracciones del alto del personaje.
const RETRATO_3D_POSADO := {
	"gigi": "david",
	"david": {
		"escena": "res://assets/models/gigi_toy.glb",
		# MEDIDO sobre el David v5 con `tools/_probe_gigi.gd` (5-9-2026): con
		# 0.30 medía 0.42 del alto de David en pantalla —tanto como su cara— y
		# caía en x=-0.55 del retrato, fuera de cuadro. A 0.22 y sobre el
		# hombro derecho (que la sonda sitúa en 0.27, 0.73 del viewport) se ve
		# entera y se lee como un loro posado.
		"alto": 0.22,                       # del alto de David
		# MEDIDO con un barrido de cuatro sitios sobre el retrato real (la sonda
		# tiene que reescribir "gigi_base", no `position`: el _process recoloca
		# a Gigi desde ahí cada fotograma). Más abajo o más adelante se hunde en
		# la barba, que en esta figurita es ancha y llega hasta el hombro.
		# MEDIDO con un barrido de cuatro sitios sobre el retrato real (la sonda
		# tiene que reescribir "gigi_base", no `position`: el _process recoloca
		# a Gigi desde ahí cada fotograma). Más abajo o más adelante se hunde en
		# la barba, que en esta figurita es ancha y llega hasta el hombro.
		"desvio": Vector3(-0.165, 0.245, -0.050),  # del centro del modelo
		"giro": -14.0,
	},
}
## Encuadre de BUSTO, el del cartel de recompensa: fov vertical, banda de
## altura del modelo que se ve y aire sobre la coronilla.
const R3D_FOV := 34.0
## Cuánto levanta el ambiente las sombras del retrato. SUBIDO con el rebake
## (7-9-2026): los modelos de Meshy traían la EMISIÓN encendida con el propio
## albedo, o sea que se iluminaban solos y la luz de aquí se afinó contra eso;
## re-horneados y sin emisión salían con media cara en sombra.
const R3D_AMBIENTE := 0.46
const R3D_BAND := 0.42
## Banda por hablante, por si a alguno le hace falta mas o menos encuadre que
## al resto (el David de juguete, con la cabeza a media altura, pedia 0.85; el
## nuevo tiene las proporciones del reparto).
## David (y Gigi, que habla con su retrato) va con algo más de banda: así
## entra la línea de los hombros y el loro que va posado en uno de ellos.
## El KAPPA lleva el plato en la coronilla y el pico muy abajo: con la banda
## general se le veia el plato y los ojos, y el pico quedaba cortado.
const R3D_BANDA_QUIEN := { "david": 0.48, "gigi": 0.48, "kappa": 0.62 }
const R3D_AIR := 0.05
## El hablante mira hacia la caja: unos grados de guiñada hacia el centro.
const R3D_YAW := 24.0
## El viewport se dibuja al DOBLE y el TextureRect lo encoge (supermuestreo), con
## MSAA 4x: cuesta GPU en un rectángulo de 380×470, no pesa nada en el paquete.
const R3D_SS := 2
## side → { "vp", "cam", "root", "anim", "who", "mood" }
var _r3d := {}
var _r3d_t := 0.0
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


## El hablante de la linea en curso ("" si no hay ninguna).
func hablante_actual() -> String:
	if _index < 0 or _index >= _queue.size():
		return ""
	var line: Variant = _queue[_index]
	return DEFAULT_SPEAKER if line is String else str(line.get("who", DEFAULT_SPEAKER))


func is_talking() -> bool:
	return visible


## SIN RETRATOS: solo el pergamino y el tablón del nombre. Lo enciende el
## guion cuando lo que hay que VER está justo donde cae el retrato — las tres
## cartas de potenciador del 10 quedaban una y media detrás de David (medido
## en captura: el retrato ocupa la x 0-370 desde la y 420, y las cartas la
## 60-660 desde la 520). La voz y el nombre siguen diciendo quién habla.
var sin_retratos := false


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


## Sufijo de arte que le toca a este hablante por sus coleccionables.
## Gigi comparte dibujo con David, así que el tricornio y el pañuelo cambian
## el MISMO retrato: cuatro estados en total (nada / pañuelo de David /
## tricornio de Gigi / los dos). OJO AL SENTIDO: el arte ORIGINAL del juego
## traía a Gigi CON tricornio, así que ese pasó a ser la variante
## `_tricornio` (copiado tal cual) y el arte BASE nuevo es la serie con el
## loro a pelo, regenerada por editImage.
static func _variante_de(who: String) -> String:
	if who == "cai" and GameState.has_collectible("sombrero_paja"):
		return "sombrero"
	if who == "david" or who == "gigi":
		var panuelo := GameState.has_collectible("panuelo")
		var tricornio := GameState.has_collectible("tricornio")
		if panuelo and tricornio:
			return "panuelo_tricornio"
		if tricornio:
			return "tricornio"
		if panuelo:
			return "panuelo"
	return ""


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
	# EL ARTE CAMBIA CON ALGUNOS COLECCIONABLES (pedido por el usuario): Cai
	# se pone el SOMBRERO DE PAJA al ganarse esa pieza, y Gigi el TRICORNIO.
	# La variante es el mismo dibujo con sufijo (cai_serio_sombrero.png): si
	# el archivo del mood no existe todavia, se cae al arte de siempre.
	var sufijo := _variante_de(who)
	var path := ""
	if sufijo != "":
		path = "%s/%s_%s_%s.png" % [info["dir"], info["file"], mood, sufijo]
	if sufijo == "" or not ResourceLoader.exists(path):
		path = "%s/%s_%s.png" % [info["dir"], info["file"], mood]
	if not ResourceLoader.exists(path):
		path = "%s/%s_%s.png" % [info["dir"], info["file"], info["mood"]]
	var p: TextureRect = _portraits[side]
	if RETRATO_3D and _retrato_3d(side, who, mood):
		pass
	else:
		_apagar_3d(side)
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
		if sin_retratos:
			q.visible = false


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
	# LA VOZ DEL PERSONAJE, con la expresión que trae la línea. No lee el
	# texto: suelta uno de los tres sonidos que tiene para esa cara (ver
	# `Audio.VOCES`), como en una aventura clásica.
	Audio.voz(who, mood)
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


## Monta (o reutiliza) el viewport 3D de ese lado con el modelo de `who` y le
## pone la pose del `mood`. Devuelve false si el hablante no tiene modelo.
func _retrato_3d(side: String, who: String, mood: String) -> bool:
	var ruta := ""
	if RETRATO_3D_RUTA.has(who):
		ruta = str(RETRATO_3D_RUTA[who])
	elif RETRATO_3D_QUIEN.has(who) or RETRATO_3D_QUIEN_EXTRA.has(who):
		var par: Array = RETRATO_3D_QUIEN.get(who, RETRATO_3D_QUIEN_EXTRA.get(who))
		ruta = CharacterData.model(str(par[0]), str(par[1]))
	else:
		return false
	if ruta == "" or not ResourceLoader.exists(ruta):
		return false
	var p: TextureRect = _portraits[side]
	if not _r3d.has(side):
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.size = Vector2i(int(p.offset_right - p.offset_left) if side == "left"
			else int(p.offset_right - p.offset_left), int(PORTRAIT_BOTTOM - PORTRAIT_TOP)) * R3D_SS
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var cam := Camera3D.new()
		cam.fov = R3D_FOV
		vp.add_child(cam)
		# ENTORNO PROPIO: con `own_world_3d` y sin él, el viewport hereda el
		# entorno por defecto del proyecto y el personaje sale QUEMADO (la piel
		# y la barba a blanco). Aquí la luz la ponen las tres direccionales de
		# abajo y el ambiente solo levanta las sombras.
		var ent := Environment.new()
		ent.background_mode = Environment.BG_CANVAS
		ent.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		ent.ambient_light_color = Color(0.55, 0.58, 0.66)
		ent.ambient_light_energy = R3D_AMBIENTE
		var we := WorldEnvironment.new()
		we.environment = ent
		vp.add_child(we)
		# Luz FLOJA, la lección del cartel de recompensa: con la del nivel las
		# caras claras se queman y el personaje sale sin rasgos.
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-32.0, 38.0 if side == "right" else -38.0, 0.0)
		sun.light_energy = 0.80
		sun.shadow_enabled = false
		vp.add_child(sun)
		var relleno := DirectionalLight3D.new()
		relleno.rotation_degrees = Vector3(-12.0, -128.0 if side == "right" else 128.0, 0.0)
		relleno.light_energy = 0.38
		relleno.shadow_enabled = false
		vp.add_child(relleno)
		# Luz de CANTO por detrás y arriba: es lo que enciende el borde de una
		# figurita de vinilo y la despega del fondo (estilo Link's Awakening);
		# con solo clave y relleno el juguete salía plano.
		var canto := DirectionalLight3D.new()
		canto.rotation_degrees = Vector3(-40.0, 150.0 if side == "right" else -150.0, 0.0)
		canto.light_energy = 0.42
		canto.light_color = Color(0.85, 0.92, 1.0)
		canto.shadow_enabled = false
		vp.add_child(canto)
		_r3d[side] = { "vp": vp, "cam": cam, "root": null, "anim": null,
			"who": "", "mood": "serio", "habla": 0.0, "gigi": null,
			"gigi_base": Vector3.ZERO }
	var r: Dictionary = _r3d[side]
	var vp: SubViewport = r["vp"]
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if r["who"] != who:
		if r["root"] != null and is_instance_valid(r["root"]):
			r["root"].queue_free()
		var root := Node3D.new()
		vp.add_child(root)
		var m: Node3D = (load(ruta) as PackedScene).instantiate()
		# SE MIRAN: el de la izquierda gira hacia la derecha y al reves. El
		# modelo mira a +Z y girar +yaw sobre Y lleva su frente hacia +X (la
		# derecha de la pantalla), asi que el de la IZQUIERDA lleva +yaw.
		# Estuvo con el signo al reves —el de la izquierda miraba a la
		# izquierda, dandole la espalda al otro— y David, que llevaba el
		# giro "de vuelta" para enseñar el hombro de Gigi, era el unico que
		# salia bien por casualidad (lo vio el usuario, 7-9-2026).
		var yaw: float = R3D_YAW if side == "left" else -R3D_YAW
		m.rotation_degrees = Vector3(0.0, yaw, 0.0)
		root.add_child(m)
		r["root"] = root
		_posar_acompanante(m, who, r, side)
		r["anim"] = null
		var skels := m.find_children("*", "Skeleton3D", true, false)
		if not skels.is_empty():
			var a := CharacterAnim.new(skels[0])
			if a.has_humanoid_bones():
				r["anim"] = a
				a.reset()
				a.idle(0.0)
		r["who"] = who
		_encuadrar_3d(side)
	r["mood"] = mood
	p.texture = vp.get_texture()
	return true


## Posa al acompañante (Gigi) sobre el personaje. Va colgado de la RAÍZ del
## modelo y no del hueso del hombro: el espacio del hueso está girado 90° y su
## pose la mueve la animación, así que las coordenadas no se podían medir ni
## razonar (tres intentos y el loro acababa dentro del pecho). Colgado de la
## raíz, el desvío se lee en el sistema del propio modelo —el mismo en el que
## está medido el hombro— y basta con la altura y el ancho de David.
func _posar_acompanante(modelo: Node3D, who: String, r: Dictionary, side := "left") -> void:
	r["gigi"] = null
	if not RETRATO_3D_POSADO.has(who):
		return
	# un hablante puede APUNTAR a la ficha de otro ("gigi" -> la de David)
	var d: Variant = RETRATO_3D_POSADO[who]
	if d is String:
		d = RETRATO_3D_POSADO[str(d)]
	if not ResourceLoader.exists(str(d["escena"])):
		return
	var caja_p := _aabb_3d(modelo)
	var alto: float = caja_p.size.y if caja_p.size.y > 0.0 else 1.0
	var g: Node3D = (load(str(d["escena"])) as PackedScene).instantiate()
	var caja := _aabb_3d(g)
	if caja.size.y > 0.0:
		g.scale = Vector3.ONE * (float(d["alto"]) * alto / caja.size.y)
	# En el lado DERECHO el personaje gira hacia la izquierda y su hombro
	# derecho se va detras: el loro pasa al hombro izquierdo (desvio y giro
	# espejados), que es el que queda hacia la camara.
	var desvio: Vector3 = Vector3(d["desvio"])
	var giro: float = float(d["giro"])
	if side == "right":
		desvio.x = -desvio.x
		giro = -giro
	g.position = caja_p.get_center() + desvio * alto
	g.rotation_degrees = Vector3(0.0, giro, 0.0)
	modelo.add_child(g)
	r["gigi"] = g
	r["gigi_base"] = g.position
	# ANCLADA AL HOMBRO (7-9-2026): el desvio se mide en REPOSO y se expresa en
	# el espacio del hueso del hombro mas cercano, y cada fotograma se vuelve
	# a colocar desde la pose viva de ese hueso. Antes iba a un punto fijo del
	# modelo, asi que cuando David se echaba atras riendo o subia los brazos
	# el hombro se iba y Gigi se quedaba flotando (lo vio el usuario).
	r["gigi_skel"] = null
	var sks := modelo.find_children("*", "Skeleton3D", true, false)
	if not sks.is_empty():
		var sk: Skeleton3D = sks[0]
		var to_m: Transform3D = modelo.global_transform.affine_inverse() * sk.global_transform
		var mejor := -1
		var mejor_d := 1.0e9
		for nombre in ["L_Shoulder", "R_Shoulder"]:
			var i := sk.find_bone(nombre)
			if i < 0:
				continue
			var p_m: Vector3 = to_m * sk.get_bone_global_rest(i).origin
			var dist := p_m.distance_to(g.position)
			if dist < mejor_d:
				mejor_d = dist
				mejor = i
		if mejor >= 0:
			var rest: Transform3D = sk.get_bone_global_rest(mejor)
			r["gigi_skel"] = sk
			r["gigi_hueso"] = mejor
			r["gigi_to_m"] = to_m
			r["gigi_rest_inv_b"] = rest.basis.inverse()
			r["gigi_off"] = (to_m * rest).affine_inverse() * g.position
			r["gigi_esc"] = g.scale.x
	# la ficha YA RESUELTA (un alias como "gigi" -> "david" no vale para leerla
	# cada fotograma: `_tick_gigi` reventaba con 'giro' sobre un String)
	r["gigi_cfg"] = d
	r["gigi_giro"] = giro
	r["gigi_anim"] = null
	var sk_g := g.find_children("*", "Skeleton3D", true, false)
	if not sk_g.is_empty():
		var ba := BirdAnim.new(sk_g[0])
		if ba.tiene_huesos():
			r["gigi_anim"] = ba


func _alto_de(n: Node3D) -> float:
	var c := _aabb_3d(n)
	return c.size.y if c.size.y > 0.0 else 1.0


## El retrato de ese lado vuelve al dibujo: el viewport se para (no se libera,
## que el mismo hablante suele volver dos líneas después).
func _apagar_3d(side: String) -> void:
	if _r3d.has(side):
		var r: Dictionary = _r3d[side]
		(r["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
		r["who"] = ""


## Encuadre de busto: la banda pegada a la coronilla, como el cartel de
## recompensa (el AABB de un rig es el del BIND, por eso el aire es generoso).
func _encuadrar_3d(side: String) -> void:
	var r: Dictionary = _r3d[side]
	var caja := _aabb_3d(r["root"])
	if caja.size.y <= 0.0:
		return
	var banda: float = caja.size.y * float(R3D_BANDA_QUIEN.get(r["who"], R3D_BAND))
	var arriba: float = caja.position.y + caja.size.y
	var centro_y: float = arriba - banda * (0.5 - R3D_AIR)
	var d: float = banda / (2.0 * tan(deg_to_rad(R3D_FOV) * 0.5))
	var c := caja.get_center()
	var cam: Camera3D = r["cam"]
	cam.position = Vector3(c.x, centro_y, caja.position.z + caja.size.z + d)
	cam.rotation_degrees = Vector3.ZERO


## OJO: la transformada se ACUMULA por el camino en vez de pedir la global de
## cada malla. Aquí se mide también una escena RECIÉN INSTANCIADA (Gigi, antes
## de colgarla del modelo), y `global_transform` fuera del árbol devuelve
## identidad soltando un error por cada malla: la consola se llenaba de
## "Condition !is_inside_tree() is true" cada vez que David abría la boca.
func _aabb_3d(n: Node, acc := AABB()) -> AABB:
	var base := Transform3D.IDENTITY
	if n is Node3D:
		var n3 := n as Node3D
		base = n3.global_transform if n3.is_inside_tree() else n3.transform
	return _aabb_en(n, base, acc)


func _aabb_en(n: Node, t: Transform3D, acc: AABB) -> AABB:
	if n is MeshInstance3D:
		var suya: AABB = t * (n as MeshInstance3D).get_aabb()
		acc = suya if acc.size == Vector3.ZERO else acc.merge(suya)
	for c in n.get_children():
		var tc := t
		if c is Node3D:
			tc = t * (c as Node3D).transform
		acc = _aabb_en(c, tc, acc)
	return acc


## Los retratos 3D respiran y gesticulan. RESET obligatorio cada fotograma:
## `CharacterAnim._rotate_bone` acumula.
##
## Van SIEMPRE en marcha, hable quien hable: quieto, un personaje 3D se lee
## como una foto y delata que no es un dibujo. Encima del reposo va la POSTURA
## del humor de la línea, y encima de todo el movimiento de HABLA, que solo
## corre mientras ese personaje está soltando su frase — se enciende y se apaga
## con un fundido (`HABLA_VEL`), porque cortarlo en seco se ve como un tirón.
const HABLA_VEL := 4.5

func _tick_3d(delta: float) -> void:
	if _r3d.is_empty():
		return
	_r3d_t += delta
	for side in _r3d:
		var r: Dictionary = _r3d[side]
		if r["who"] == "" or r["anim"] == null:
			continue
		var quiere: float = 1.0 if (_typing and side == _stage_side()) else 0.0
		r["habla"] = move_toward(float(r["habla"]), quiere, HABLA_VEL * delta)
		var a: CharacterAnim = r["anim"]
		a.reset()
		a.idle(_r3d_t)
		# `hacia`: donde esta el OTRO (el de la izquierda lo tiene a la derecha)
		a.gesto(str(r["mood"]), _r3d_t, 1.0 if side == "left" else -1.0)
		a.hablar(_r3d_t, float(r["habla"]))
		_tick_gigi(r, delta)


## Gigi nunca se queda quieta. El cuerpo entero se mece en el hombro y, ADEMÁS,
## pega los GOLPES de cabeza de un loro.
##
## Esos golpes van sobre la TRANSFORMADA DEL NODO, no sobre huesos. El modelo
## bueno de Gigi es el crudo de Meshy y NO lleva rig: riguearlo le encogía la
## cabeza y le rompía la silueta —el bicho es un óvalo continuo de cabeza y
## cuerpo, y en cuanto se separan las dos mitades deja de leerse como un loro—.
## Girando el objeto entero es IMPOSIBLE que se desfigure, y a este tamaño (va
## posada en un hombro) se lee exactamente igual. Si algún día vuelve a tener
## esqueleto, `BirdAnim` toma el relevo y esto se queda de meneo de fondo.
const GIGI_GOLPE := 0.11        ## lo que tarda en llegar al giro nuevo
const GIGI_ESPERA := Vector2(0.9, 2.6)    ## quieta, callado
const GIGI_ESPERA_HABLA := Vector2(0.45, 1.4)
const GIGI_PROB_LADEO := 0.35   ## de las veces, ladea en vez de girar
const GIGI_GIRO := 22.0
const GIGI_LADEO := 18.0
func _tick_gigi(r: Dictionary, delta: float) -> void:
	var g = r.get("gigi")
	if g == null or not is_instance_valid(g):
		return
	var t := _r3d_t
	var f: float = 0.35 + 0.65 * float(r.get("habla", 0.0))
	var vaiven := Vector3(0.0, sin(t * 2.3) * 0.004 * f, 0.0)
	var sk = r.get("gigi_skel")
	var con_hueso: bool = sk != null and is_instance_valid(sk)
	var delta_b := Basis.IDENTITY
	if con_hueso:
		var pose: Transform3D = (sk as Skeleton3D).get_bone_global_pose(int(r["gigi_hueso"]))
		var to_m: Transform3D = r["gigi_to_m"]
		var xf: Transform3D = to_m * pose
		g.position = xf * Vector3(r["gigi_off"]) + vaiven
		delta_b = to_m.basis * pose.basis * Basis(r["gigi_rest_inv_b"]) * to_m.basis.inverse()
	else:
		g.position = Vector3(r["gigi_base"]) + vaiven
	var ba = r.get("gigi_anim")
	var golpe := Vector3.ZERO
	if ba != null:
		(ba as BirdAnim).tick(delta, float(r.get("habla", 0.0)))
	else:
		golpe = _gigi_golpe(r, delta)
	var eul := Vector3(
		sin(t * 3.1) * 2.0 * f + golpe.x,
		float(r.get("gigi_giro", r["gigi_cfg"]["giro"])) + sin(t * 1.9) * 5.0 * f + golpe.y,
		sin(t * 2.7 + 1.1) * 2.5 * f + golpe.z)
	if con_hueso:
		# el giro propio del loro va SOBRE el giro que lleve el hombro
		g.transform.basis = (delta_b * Basis.from_euler(eul * (PI / 180.0))) \
			.scaled(Vector3.ONE * float(r.get("gigi_esc", 1.0)))
	else:
		g.rotation_degrees = eul


## El golpe de cabeza: se sortea una postura, se llega a ella en un suspiro y se
## QUEDA CLAVADA hasta el siguiente. El contraste entre el golpe y la quietud es
## todo el efecto: con una interpolación suave el bicho parece un peluche
## meciéndose. Mira más veces mientras su dueño habla.
func _gigi_golpe(r: Dictionary, delta: float) -> Vector3:
	var espera: float = float(r.get("gigi_espera", 0.0)) - delta
	var v: Vector3 = r.get("gigi_dest", Vector3.ZERO)
	var de: Vector3 = r.get("gigi_de", Vector3.ZERO)
	var k: float = float(r.get("gigi_k", 1.0))
	if k < 1.0:
		k = minf(1.0, k + delta / GIGI_GOLPE)
		r["gigi_k"] = k
	elif espera <= 0.0:
		var hablando: bool = float(r.get("habla", 0.0)) > 0.5
		var rango: Vector2 = GIGI_ESPERA_HABLA if hablando else GIGI_ESPERA
		r["gigi_espera"] = randf_range(rango.x, rango.y)
		r["gigi_de"] = v
		r["gigi_k"] = 0.0
		if randf() < GIGI_PROB_LADEO:
			r["gigi_dest"] = Vector3(0.0, 0.0, randf_range(-GIGI_LADEO, GIGI_LADEO))
		else:
			r["gigi_dest"] = Vector3(randf_range(-6.0, 6.0),
				randf_range(-GIGI_GIRO, GIGI_GIRO), 0.0)
		return de
	else:
		r["gigi_espera"] = espera
	return de.lerp(v, k * k * (3.0 - 2.0 * k))


## De qué lado es el que tiene la palabra ahora mismo: el retrato que está a
## plena luz, que es el mismo criterio con el que se hunde y se atenúa el que
## escucha.
func _stage_side() -> String:
	return "left" if _is_speaking_side("left") else "right"


func _process(delta: float) -> void:
	_tick_3d(delta)
	if not visible or not _typing:
		return
	var antes := int(_visible_chars)
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
