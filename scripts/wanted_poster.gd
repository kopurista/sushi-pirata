class_name WantedPoster
extends Control
## CARTEL DE RECOMPENSA: la ficha del jugador, y el ÚNICO sitio donde se elige
## quién es. Lo usan dos pantallas:
##   · la bienvenida de David (`david_intro`), donde se rellena por primera vez
##     y el nombre SÍ se puede escribir;
##   · la pantalla PERFIL del submenú (`profile_screen`), donde se cambia todo
##     MENOS el nombre y además se elige el título entre los desbloqueados.
##
## La "foto" del cartel no es un retrato pintado: es el MODELO 3D del chef
## metido en un SubViewport, y las flechas de los lados cambian de género
## cambiando el modelo. Es la excepción a la regla de `chef_portraits.gd` (que
## rinde los retratos a PNG para no tener escenas 3D vivas en un menú): allí
## eran TRES retratos a la vez en una pantalla llena de cosas, y aquí es UNO
## solo en una pantalla que no hace nada más. A cambio, el día que haya skins
## el cartel las enseña sin regenerar ningún PNG.
##
## Nada de lo que se toca aquí entra en `GameState` hasta que alguien llama a
## `aplicar()`: así el jugador puede probar combinaciones y arrepentirse, igual
## que los `draft_*` de Opciones.

const PrepBoard := preload("res://scripts/prep_board.gd")

const SHEET_TEX := "res://assets/ui/wanted_hoja.png"
const COIN_TEX := "res://assets/ui/wanted_moneda.png"
## La MISMA punta de flecha que la caja de diálogo usa para "toca para seguir",
## y su espejo exacto (lo genera `build_wanted` de tools/ui2_prep.py, igual que
## ic_mano_der sale de ic_mano_izq).
const ARROW_R := "res://assets/ui/ic_siguiente.png"
const ARROW_L := "res://assets/ui/ic_siguiente_esp.png"
const ARROW_SIZE := Vector2(86, 86)

const TINTA := Color(0.24, 0.15, 0.08)

## El cartel se monta de DOS maneras:
##  · CON TABLÓN (la bienvenida de David): la hoja va sobre un pergamino de
##    madera, porque ahí no hay nada más en pantalla.
##  · SIN TABLÓN: para pantallas que ya ponen su propio pergamino detrás,
##    y dos marcos uno dentro de otro solo comían sitio. Quitándolo la hoja pasa
##    de 520 a 640 de ancho, o sea un 23% más grande.
const BOARD_PAD := Vector2(60.0, 54.0)
const SHEET_W_BOARD := 520.0
const SHEET_W_PLAIN := 640.0
## `wanted_hoja.png` se exporta a 600x806.
const SHEET_RATIO := 806.0 / 600.0
## Lo que ocupa el bloque de la mano dominante, debajo de la hoja.
const HANDS_H := 152.0


## Lo que mide el cartel montado de una manera o de la otra. Las pantallas que
## lo usan reservan el hueco con esto, no con un número a mano.
static func panel_size(con_tablon := true) -> Vector2:
	var ancho: float = SHEET_W_BOARD if con_tablon else SHEET_W_PLAIN
	var pad: Vector2 = BOARD_PAD if con_tablon else Vector2.ZERO
	return Vector2(ancho + pad.x * 2.0, pad.y + ancho * SHEET_RATIO + HANDS_H)

## Hueco de la FOTO dentro de la hoja, en FRACCIONES de la hoja. Medido sobre
## el PNG generado (x 104..546, y 216..505 de 648x864) con el barrido de
## `tools/ui2_prep.py`. Si se regenera la hoja hay que volver a medirlo.
const PHOTO := Rect2(0.1605, 0.25, 0.6821, 0.3345)

## Encuadre del retrato. La cámara NO va en una posición fija: se calcula a
## partir del AABB del modelo (ver `_frame_camera`).
##
## Hace falta porque los chefs vienen NORMALIZADOS y CENTRADOS EN EL ORIGEN
## (miden 1.0 de alto, de y=-0.5 a y=+0.5), no de pie sobre el suelo. Con la
## cámara puesta a ojo "a la altura del pecho" (y=1.30) apuntaba a un palmo por
## encima de la cabeza y el cartel salía con la foto VACÍA.
const CAM_FOV := 34.0
## Fracción del alto del personaje que entra en la foto, de la cintura arriba.
## Cuanto MENOS, más grande sale el personaje.
const CAM_BAND := 0.40
## Aire por encima de la cabeza, en fracciones de esa banda. Va corto para que
## la coronilla casi toque el marco, pero NO a cero: el AABB es el del bind y la
## pose real puede sacar la cabeza un poco por encima.
const CAM_AIR := 0.035
## Lo que se desplaza el modelo al cambiar de personaje, en anchos de encuadre.
const SLIDE_OUT := 1.15
const SLIDE_TIME := 0.30
## Los modelos ya miran hacia +Z, que es de donde mira la cámara: NO hay que
## girarlos. Con los 180º que parecían lo lógico salían de espaldas.
const MODEL_YAW := 0.0

## La recompensa se escribe SIEMPRE con diez cifras y sus comas, como en los
## carteles de verdad: con el número pelado, un jugador nuevo veía un "0" suelto
## en medio de la hoja y no se leía como una recompensa.
const BOUNTY_DIGITS := 10

@export var editable_name := true
@export var show_titles := false
## ¿Se dibuja el tablón de madera detrás de la hoja? (ver BOARD_PAD).
@export var show_board := true

var g_draft: String = CharacterData.MALE
var hand_draft: String = "R"
var title_draft: String = TitleData.MANO

var _sheet: TextureRect = null
var _viewport: SubViewport = null
var _cam: Camera3D = null
var _model_root: Node3D = null
var _anim: CharacterAnim = null
var _t := 0.0
## Ancho visible del encuadre, en unidades de mundo (lo deja `_frame_camera`).
var _frame_w := 1.0
var _sliding := false
var _name_edit: LineEdit = null
var _subtitle: Label = null
var _hands: Array[Button] = []
var _title_arrows: Array[Button] = []

## Salta cuando cambia algo (Opciones lo usa para encender "Aplicar cambios").
signal edited


func _ready() -> void:
	g_draft = GameState.player_gender
	hand_draft = GameState.player_hand
	title_draft = GameState.player_title_id
	custom_minimum_size = panel_size(show_board)
	size = panel_size(show_board)
	_build()


func _process(delta: float) -> void:
	if _anim == null or not GameState.animations_on():
		return
	_t += delta
	# RESET OBLIGATORIO cada fotograma: `CharacterAnim._rotate_bone` ACUMULA
	# sobre lo que el hueso ya tenga (varios huesos reciben dos giros seguidos y
	# sustituyendo se borraba el primero), y da por hecho que el fotograma
	# empieza en reposo. Sin esto la pose se va retorciendo sola: la chef salía
	# ladeada y con un brazo en alto al cabo de un segundo.
	_anim.reset()
	_anim.idle(_t)


func _build() -> void:
	if show_board:
		add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
			PrepBoard.PANEL_MARGIN))

	var ancho: float = SHEET_W_BOARD if show_board else SHEET_W_PLAIN
	_sheet = TextureRect.new()
	_sheet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sheet.stretch_mode = TextureRect.STRETCH_SCALE
	_sheet.texture = load(SHEET_TEX)
	_sheet.position = BOARD_PAD if show_board else Vector2.ZERO
	_sheet.size = Vector2(ancho, ancho * SHEET_RATIO)
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sheet)

	_build_photo()
	_build_name()
	_build_bounty()
	_build_hands()


## La foto: el modelo 3D vivo dentro de un SubViewport, con una flecha a cada
## lado para cambiar de personaje.
func _build_photo() -> void:
	var r := Rect2(PHOTO.position * _sheet.size, PHOTO.size * _sheet.size)

	_viewport = SubViewport.new()
	# Mundo PROPIO: sin esto el retrato hereda el 3D de la escena que lo abre
	# (la cubierta del barco en la intro, el mar en Opciones) y sale el chef
	# plantado en medio del decorado.
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.size = Vector2i(r.size)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	_cam = Camera3D.new()
	_cam.fov = CAM_FOV
	_viewport.add_child(_cam)
	# Luz FLOJA a propósito, la misma lección que `tools/chef_portraits.gd`: con
	# la luz del nivel las caras claras se QUEMAN y el personaje sale sin
	# rasgos. Pasó aquí igual: la chef salía con un óvalo liso por cara.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32.0, 38.0, 0.0)
	sun.light_energy = 0.62
	sun.shadow_enabled = false
	_viewport.add_child(sun)
	var relleno := DirectionalLight3D.new()
	relleno.rotation_degrees = Vector3(-12.0, -128.0, 0.0)
	relleno.light_energy = 0.26
	relleno.shadow_enabled = false
	_viewport.add_child(relleno)

	var pic := TextureRect.new()
	pic.texture = _viewport.get_texture()
	pic.position = _sheet.position + r.position
	pic.size = r.size
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pic)

	_swap_model()

	# Flechas: la MISMA punta de flecha de la caja de diálogo (`ic_siguiente`) y
	# su espejo, no un botón de madera. Van sobre los cantos de la foto, sin
	# tablón detrás, para no taparle la cara al personaje.
	for der in [false, true]:
		var b := Button.new()
		b.custom_minimum_size = ARROW_SIZE
		b.size = ARROW_SIZE
		var y := _sheet.position.y + r.position.y + r.size.y * 0.5 \
				- ARROW_SIZE.y * 0.5
		var x := _sheet.position.x + r.position.x - ARROW_SIZE.x * 0.62
		if der:
			x = _sheet.position.x + r.position.x + r.size.x - ARROW_SIZE.x * 0.38
		b.position = Vector2(x, y)
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = load(ARROW_R if der else ARROW_L)
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		# Hundido al pulsar, como el resto de botones del juego.
		PrepBoard.add_press_feedback(b, 0.84)
		b.pressed.connect(func() -> void: _cycle_gender(1 if der else -1))
		add_child(b)


## Cambia de personaje con una transición de CARRUSEL: el que estaba se va por
## un lado y el nuevo entra por el otro. El recorte sale gratis: el SubViewport
## solo dibuja lo que cae dentro del marco de la foto, así que el modelo
## "desaparece por el borde" sin necesidad de máscara ninguna.
func _cycle_gender(paso: int) -> void:
	if _sliding or _model_root == null:
		return
	var i := CharacterData.PLAYER_GENDERS.find(g_draft)
	var n: int = CharacterData.PLAYER_GENDERS.size()
	g_draft = CharacterData.PLAYER_GENDERS[posmod(i + paso, n)]
	_sliding = true

	var viejo := _model_root
	# El nuevo se monta CENTRADO (el encuadre se calcula con él en el eje, o la
	# cámara se iría detrás del desplazamiento) y luego se aparta al lado.
	_swap_model(false)
	var salto := _slide_dist()
	_model_root.position.x = paso * salto
	viejo.position.x = 0.0

	var tw := create_tween().set_parallel(true)
	tw.tween_property(viejo, "position:x", -paso * salto, SLIDE_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_model_root, "position:x", 0.0, SLIDE_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_callback(viejo.queue_free)
	tw.chain().tween_callback(func() -> void: _sliding = false)

	_refresh()
	edited.emit()


## Lo que hay que apartar un modelo para que salga del encuadre. Sale del ancho
## visible, que lo deja calculado `_frame_camera`.
func _slide_dist() -> float:
	return _frame_w * SLIDE_OUT


## Monta el modelo del género elegido. Con `soltar_viejo` en false NO se lleva
## por delante el que había: durante el carrusel los dos conviven un momento y
## del viejo se encarga el tween.
func _swap_model(soltar_viejo := true) -> void:
	if _model_root != null and soltar_viejo:
		_model_root.queue_free()
	_model_root = null
	var ruta := CharacterData.model("chef", g_draft)
	if ruta == "" or not ResourceLoader.exists(ruta):
		return
	var esc: PackedScene = load(ruta)
	if esc == null:
		return
	_model_root = Node3D.new()
	_viewport.add_child(_model_root)
	var m: Node3D = esc.instantiate()
	m.rotation_degrees = Vector3(0.0, MODEL_YAW, 0.0)
	_model_root.add_child(m)

	# POSE DE REPOSO, no la de bind: los modelos vienen con los brazos abiertos
	# en cruz, y en un cartel de recompensa eso se lee como un espantapájaros.
	# `CharacterAnim.idle` se los baja al cuerpo y de paso los hace respirar,
	# así que el retrato no queda congelado.
	_anim = null
	var skels := m.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		var a := CharacterAnim.new(skels[0])
		if a.has_humanoid_bones():
			_anim = a
			_anim.reset()
			_anim.idle(0.0)
	# OJO al ajustar esto: el AABB de una malla con esqueleto NO refleja la
	# pose, Godot devuelve el del BIND. O sea que posarlo no mueve el encuadre
	# ni un píxel, y por el mismo motivo el aire de CAM_AIR tiene que ser
	# generoso: si la pose real saca la cabeza por encima del bind, el AABB no
	# se entera y el sombrero se corta.
	_frame_camera()


## Coloca la cámara a partir del AABB REAL del modelo, no a ojo (ver CAM_FOV).
func _frame_camera() -> void:
	var caja := _merged_aabb(_model_root)
	if caja.size.y <= 0.0:
		return
	var banda: float = caja.size.y * CAM_BAND
	var arriba: float = caja.position.y + caja.size.y
	# El centro del encuadre: la banda pegada a la coronilla, con su pellizco de
	# aire por encima para que la cabeza no salga a corte vivo.
	var centro_y: float = arriba - banda * (0.5 - CAM_AIR)
	# fov es el VERTICAL (keep_aspect por defecto es KEEP_HEIGHT), así que la
	# distancia sale de la banda que se quiere ver de alto.
	var d: float = banda / (2.0 * tan(deg_to_rad(CAM_FOV) * 0.5))
	var c := caja.get_center()
	_cam.position = Vector3(c.x, centro_y, caja.position.z + caja.size.z + d)
	_cam.rotation_degrees = Vector3.ZERO
	# Ancho visible, que es lo que necesita el carrusel para saber cuánto hay
	# que apartar un modelo para que se salga del marco.
	var prop := float(_viewport.size.x) / maxf(float(_viewport.size.y), 1.0)
	_frame_w = banda * prop


func _merged_aabb(n: Node, acc := AABB()) -> AABB:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var caja := mi.get_aabb()
		# En el espacio del retrato, no en el de la malla.
		var t := mi.global_transform
		var suya := t * caja
		acc = suya if acc.size == Vector3.ZERO else acc.merge(suya)
	for c in n.get_children():
		acc = _merged_aabb(c, acc)
	return acc


## El nombre y el título, escritos sobre la hoja.
func _build_name() -> void:
	_name_edit = LineEdit.new()
	_name_edit.max_length = 14
	_name_edit.text = GameState.player_name
	_name_edit.placeholder_text = "Tu nombre"
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.editable = editable_name
	_name_edit.position = _sheet.position + Vector2(56.0, _sheet.size.y * 0.665)
	_name_edit.size = Vector2(_sheet.size.x - 112.0, 58.0)
	_name_edit.add_theme_font_size_override("font_size", 40)
	_name_edit.add_theme_color_override("font_color", TINTA)
	_name_edit.add_theme_color_override("font_uneditable_color", TINTA)
	_name_edit.add_theme_color_override("font_placeholder_color",
		Color(0.52, 0.40, 0.28))
	_name_edit.add_theme_color_override("caret_color", TINTA)
	# SIN caja: tiene que parecer escrito EN el cartel. El estilo del tema es un
	# rectángulo gris que sobre el papel se lee como un parche pegado.
	for st in ["normal", "focus", "read_only"]:
		_name_edit.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	add_child(_name_edit)
	if editable_name:
		# En el móvil el LineEdit no coge el foco al tocarlo y no sale el
		# teclado: hay que pedirlo a mano.
		PrepBoard.enable_mobile_keyboard(_name_edit)
		_name_edit.text_changed.connect(func(_t: String) -> void:
			edited.emit())

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.position = _sheet.position + Vector2(96.0, _sheet.size.y * 0.735)
	_subtitle.size = Vector2(_sheet.size.x - 192.0, 40.0)
	_subtitle.add_theme_font_size_override("font_size", 26)
	_subtitle.add_theme_color_override("font_color", TINTA)
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle)

	if not show_titles:
		return
	# Selector de TÍTULO, solo en el perfil: flechitas pegadas al renglón. De
	# momento solo hay uno desbloqueado, así que salen apagadas.
	for der in [false, true]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(42, 42)
		b.size = Vector2(42, 42)
		b.position = Vector2(
			_subtitle.position.x - 46.0 if not der
			else _subtitle.position.x + _subtitle.size.x + 4.0,
			_subtitle.position.y - 2.0)
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = load(ARROW_R if der else ARROW_L)
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		b.pressed.connect(func() -> void: _cycle_title(1 if der else -1))
		_title_arrows.append(b)
		add_child(b)


func _cycle_title(paso: int) -> void:
	var lista := GameState.unlocked_titles
	if lista.size() < 2:
		return
	var i := lista.find(title_draft)
	title_draft = lista[posmod(i + paso, lista.size())]
	_refresh()
	edited.emit()


## La recompensa: la moneda DIBUJADA en el cartel (la del juego pasada a tinta)
## y todo el oro que se ha ganado el jugador en su vida.
func _build_bounty() -> void:
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 10)
	fila.position = _sheet.position + Vector2(40.0, _sheet.size.y * 0.800)
	fila.size = Vector2(_sheet.size.x - 80.0, 62.0)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fila)

	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = load(COIN_TEX)
	ic.custom_minimum_size = Vector2(56, 56)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(ic)

	var cifra := Label.new()
	cifra.text = _bounty_text(GameState.bounty())
	cifra.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cifra.add_theme_font_size_override("font_size", 40)
	cifra.add_theme_color_override("font_color", TINTA)
	cifra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		cifra.add_theme_font_override("font", negrita)
	fila.add_child(cifra)


static func _bounty_text(n: int) -> String:
	var s := str(maxi(n, 0)).pad_zeros(BOUNTY_DIGITS)
	var out := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out


## Con qué mano se empuña el cuchillo. Se elige TOCANDO LA MANO (el mismo
## dibujo espejado), no un botón con la palabra: obligaba a pensar cuál era
## cuál. Y de aquí sale el título por defecto del cartel ("el zurdo").
func _build_hands() -> void:
	var titulo := Label.new()
	titulo.text = "¿Con qué mano empuñas el cuchillo?"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.position = Vector2(50.0,
		_sheet.position.y + _sheet.size.y + 4.0)
	titulo.size = Vector2(size.x - 100.0, 32.0)
	titulo.add_theme_font_size_override("font_size", 24)
	titulo.add_theme_color_override("font_color", TINTA)
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(titulo)

	var manos := HBoxContainer.new()
	manos.alignment = BoxContainer.ALIGNMENT_CENTER
	manos.add_theme_constant_override("separation", 40)
	manos.position = Vector2(50.0, titulo.position.y + 36.0)
	manos.size = Vector2(size.x - 100.0, 108.0)
	add_child(manos)

	for def in [["L", "ic_mano_izq"], ["R", "ic_mano_der"]]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(132, 108)
		b.set_meta("h", def[0])
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = load("res://assets/ui/%s.png" % def[1])
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		b.pressed.connect(func() -> void:
			hand_draft = str(def[0])
			_refresh()
			b.pivot_offset = b.size / 2.0
			var tw := b.create_tween()
			tw.tween_property(b, "scale", Vector2(1.12, 1.12), 0.1)
			tw.tween_property(b, "scale", Vector2.ONE, 0.1)
			edited.emit())
		_hands.append(b)
		manos.add_child(b)
	_refresh()


func _refresh() -> void:
	for b in _hands:
		b.modulate = Color.WHITE if b.get_meta("h") == hand_draft \
				else Color(0.5, 0.5, 0.52)
	if _subtitle != null:
		_subtitle.text = TitleData.text(title_draft, g_draft, hand_draft)
	for a in _title_arrows:
		a.modulate = Color.WHITE if GameState.unlocked_titles.size() > 1 \
				else Color(0.45, 0.45, 0.45)


## ¿Está el cartel relleno? (el nombre es lo único que puede faltar).
func listo() -> bool:
	return not editable_name or _name_edit.text.strip_edges() != ""


func nombre() -> String:
	var n := _name_edit.text.strip_edges()
	return n if n != "" else "Grumete"


## Vuelca lo elegido a `GameState`. NO guarda: eso lo decide quien lo llame.
func aplicar() -> void:
	if editable_name:
		GameState.player_name = nombre()
	GameState.player_gender = g_draft
	GameState.player_hand = hand_draft
	GameState.player_title_id = title_draft


## ¿Hay algo distinto de lo que ya está guardado? (Opciones lo usa para saber
## si "Aplicar cambios" tiene que estar encendido.)
func hay_cambios() -> bool:
	return g_draft != GameState.player_gender \
			or hand_draft != GameState.player_hand \
			or title_draft != GameState.player_title_id
