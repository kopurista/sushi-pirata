class_name WantedPoster
extends Control
## CARTEL DE RECOMPENSA: la ficha del jugador, y el ÚNICO sitio donde se elige
## quién es. Lo usan dos pantallas:
##   · la bienvenida de David (`main_menu._show_ficha`), donde se rellena por
##     primera vez
##     y el nombre SÍ se puede escribir;
##   · la pantalla PERFIL del submenú (`profile_screen`), donde se cambia
##     todo MENOS el nombre.
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
const QUILL_TEX := "res://assets/ui/wanted_pluma.png"
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
## Lo que ocupa el bloque de la mano dominante, debajo de la hoja (con el
## rótulo "Zurda"/"Diestra" bajo cada dibujo).
const HANDS_H := 182.0
## El bloque de COCINERO / COCINERA, entre la hoja y las manos: rotulo mas el
## selector segmentado.
const GENDER_H := 100.0
const GEN_SEG_W := 340.0
const GEN_SEG_H := 58.0


## Lo que mide el cartel montado de una manera o de la otra. Las pantallas que
## lo usan reservan el hueco con esto, no con un número a mano.
## CON TABLÓN se suma el pad también POR ABAJO: el marco dibujado del pergamino
## come ~54 px de canto, y sin ese aire las empuñaduras de las manos caían
## ENCIMA del marco y parecían salirse del panel.
static func panel_size(con_tablon := true) -> Vector2:
	var ancho: float = SHEET_W_BOARD if con_tablon else SHEET_W_PLAIN
	var pad: Vector2 = BOARD_PAD if con_tablon else Vector2.ZERO
	return Vector2(ancho + pad.x * 2.0,
		pad.y * 2.0 + ancho * SHEET_RATIO + GENDER_H + HANDS_H)

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
## Los modelos ya miran hacia +Z, que es de donde mira la cámara: NO hay que
## girarlos. Con los 180º que parecían lo lógico salían de espaldas.
const MODEL_YAW := 0.0

## Separador de millares de la recompensa. Se escribe la cifra TAL CUAL, sin
## rellenar con ceros por delante: estuvo saliendo a diez dígitos fijos
## ("0,000,005,118" para 5.118) buscando el aire de un cartel de verdad, y lo
## que se leía era un número roto.
const BOUNTY_SEP := "."

@export var editable_name := true
## ¿Se dibuja el tablón de madera detrás de la hoja? (ver BOARD_PAD).
@export var show_board := true

var g_draft: String = CharacterData.MALE
var hand_draft: String = "R"
## El aspecto del chef en borrador (ver `ChefLook`). Solo se edita en la ficha
## de tripulación; en el Perfil se enseña el guardado y no hay forma de tocarlo.
var look_draft: Dictionary = ChefLook.por_defecto()
var _editor: ChefEditor = null
var _gender_btns: Array[Button] = []
## La placa de oro que marca el genero elegido (se desliza entre las dos
## mitades del selector) y el propio selector.
var _gen_placa: Control = null
var _gen_seg: Control = null

var _sheet: TextureRect = null
var _viewport: SubViewport = null
var _cam: Camera3D = null
var _model_root: Node3D = null
var _anim: CharacterAnim = null
var _t := 0.0
## Ancho visible del encuadre, en unidades de mundo (lo deja `_frame_camera`).
var _frame_w := 1.0
var _name_edit: LineEdit = null
var _hands: Array[Button] = []
var _quill: TextureRect = null

## Salta cuando cambia algo (Opciones lo usa para encender "Aplicar cambios").
signal edited


func _ready() -> void:
	g_draft = GameState.player_gender
	hand_draft = GameState.player_hand
	look_draft = ChefLook.validar(GameState.player_look)
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
	# La pluma de la línea de escritura late, invitando a tocar.
	if _quill != null:
		_quill.modulate.a = 0.62 + 0.38 * (0.5 + 0.5 * sin(_t * 2.6))
		_quill.rotation = sin(_t * 2.6) * 0.05


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
	_build_gender()
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

	# LAS FLECHAS DE LOS LADOS SE FUERON con el chef modular: cambiaban de
	# modelo, y ahora el cuerpo es uno solo y el aspecto se elige en el
	# PERSONALIZADOR. El genero, que siguen usando los dialogos, va en su
	# propia fila bajo la recompensa (`_build_gender`).
	if not editable_name:
		return
	# El boton del personalizador, cabalgando el canto de abajo de la foto:
	# solo en la ficha de tripulacion, que el aspecto no se cambia despues.
	var b := Button.new()
	b.text = "Personalizar"
	b.size = Vector2(236.0, 46.0)
	b.position = Vector2(
		_sheet.position.x + r.position.x + (r.size.x - b.size.x) * 0.5,
		_sheet.position.y + r.position.y + r.size.y - b.size.y * 0.55)
	PrepBoard.skin_small_button(b)
	PrepBoard.add_press_feedback(b)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(_abrir_editor)
	add_child(b)


## Abre el PERSONALIZADOR encima del cartel. Va en un CanvasLayer propio, por
## encima de la capa de la interfaz que lo abre, y a pantalla completa aunque
## el cartel vaya escalado (en el Perfil lo va).
func _abrir_editor() -> void:
	if _editor != null:
		return
	var capa := CanvasLayer.new()
	capa.layer = 125
	add_child(capa)
	_editor = ChefEditor.new()
	_editor.look = look_draft.duplicate()
	_editor.cerrado.connect(func() -> void:
		look_draft = ChefLook.validar(_editor.look)
		_editor = null
		capa.queue_free()
		_swap_model()
		edited.emit())
	capa.add_child(_editor)


## Monta el chef con el aspecto en borrador. Con `soltar_viejo` en false NO se
## lleva por delante el que habia (lo dejo el carrusel de generos, hoy sin uso).
func _swap_model(soltar_viejo := true) -> void:
	if _model_root != null and soltar_viejo:
		_model_root.queue_free()
	_model_root = null
	if not ResourceLoader.exists(ChefLook.DIR + "chef_cuerpo.glb"):
		return
	_model_root = Node3D.new()
	_viewport.add_child(_model_root)
	var m: Node3D = ChefLook.montar(look_draft)
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
	# Por el CUERPO, no por el conjunto: un peinado alto no puede mover el
	# encuadre de la cara.
	var medir: Node = _model_root
	if _model_root.get_child_count() > 0 and _model_root.get_child(0).has_meta("cuerpo"):
		medir = _model_root.get_child(0).get_meta("cuerpo")
	var caja := _merged_aabb(medir)
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
	# Al COGER EL FOCO se selecciona todo: el campo llega prerrelleno con el
	# nombre guardado, y sin esto el toque dejaba el cursor EN MEDIO y lo
	# escrito se incrustaba dentro ("Kopu" -> "KoAnapu") hasta chocar con el
	# tope de 14 letras — que es lo que se vivía como "no me deja escribir
	# otro nombre". Así, la primera tecla SUSTITUYE el nombre entero.
	_name_edit.select_all_on_focus = true
	# CENTRADO en la banda entre el "DEAD OR ALIVE" y la recompensa (el
	# subtítulo que había debajo se retiró, así que la banda entera es suya).
	_name_edit.position = _sheet.position + Vector2(56.0, _sheet.size.y * 0.685)
	_name_edit.size = Vector2(_sheet.size.x - 112.0, 66.0)
	_name_edit.add_theme_font_size_override("font_size", 50)
	var gorda := load("res://fonts/static/Exo2-Bold.ttf")
	if gorda != null:
		_name_edit.add_theme_font_override("font", gorda)
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
	if not editable_name:
		return
	# En el móvil el LineEdit no coge el foco al tocarlo y no sale el
	# teclado: hay que pedirlo a mano.
	PrepBoard.enable_mobile_keyboard(_name_edit)
	_name_edit.text_changed.connect(func(_t: String) -> void:
		edited.emit())

	# LA SEÑAL DE "AQUÍ SE ESCRIBE": una línea de escritura a tinta bajo el
	# nombre y una pluma latiendo a su lado. Sin ellas, el nombre parecía
	# impreso en el cartel y nadie adivinaba que se podía tocar. Solo cuando
	# el nombre es editable (en el Perfil va bloqueado y sobraban).
	var linea := ColorRect.new()
	linea.color = Color(TINTA.r, TINTA.g, TINTA.b, 0.32)
	linea.position = _name_edit.position + Vector2(58.0, 60.0)
	linea.size = Vector2(_name_edit.size.x - 116.0, 3.0)
	linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(linea)
	_quill = TextureRect.new()
	_quill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_quill.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_quill.texture = load(QUILL_TEX)
	# La punta de la pluma apunta abajo-izquierda: se planta con el plumín
	# tocando el FINAL de la línea, como a punto de escribir.
	_quill.position = linea.position + Vector2(linea.size.x - 8.0, -46.0)
	_quill.size = Vector2(44.0, 50.0)
	_quill.pivot_offset = Vector2(6.0, 46.0)
	_quill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_quill)


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


## La recompensa, con sus millares separados y NADA de ceros por delante.
static func _bounty_text(n: int) -> String:
	var s := str(maxi(n, 0))
	var out := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			out += BOUNTY_SEP
		out += s[i]
	return out


## Con qué mano se empuña el cuchillo. Se elige TOCANDO LA MANO (el mismo
## dibujo espejado), con la palabra debajo de cada una: el dibujo solo obligaba
## a pararse a pensar cuál era cuál. Y de aquí sale el título por defecto del
## cartel ("el zurdo").
func _build_hands() -> void:
	var titulo := Label.new()
	titulo.text = "¿Con qué mano empuñas el cuchillo?"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.position = Vector2(50.0,
		_sheet.position.y + _sheet.size.y + GENDER_H + 4.0)
	titulo.size = Vector2(size.x - 100.0, 32.0)
	titulo.add_theme_font_size_override("font_size", 24)
	titulo.add_theme_color_override("font_color", TINTA)
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(titulo)

	var manos := HBoxContainer.new()
	manos.alignment = BoxContainer.ALIGNMENT_CENTER
	manos.add_theme_constant_override("separation", 40)
	manos.position = Vector2(50.0, titulo.position.y + 36.0)
	manos.size = Vector2(size.x - 100.0, 138.0)
	add_child(manos)

	for def in [["L", "ic_mano_izq", "Zurda"], ["R", "ic_mano_der", "Diestra"]]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(132, 138)
		b.set_meta("h", def[0])
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = load("res://assets/ui/%s.png" % def[1])
		ic.position = Vector2.ZERO
		ic.size = Vector2(132.0, 104.0)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		# La palabra bajo el dibujo. Es HIJA del botón: hereda el atenuado de
		# la mano no elegida sin más cuentas.
		var rotulo := Label.new()
		rotulo.text = str(def[2])
		rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rotulo.position = Vector2(0.0, 106.0)
		rotulo.size = Vector2(132.0, 28.0)
		rotulo.add_theme_font_size_override("font_size", 22)
		rotulo.add_theme_color_override("font_color", TINTA)
		rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(rotulo)
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


## COCINERO / COCINERA: un SELECTOR SEGMENTADO bajo la hoja —FUERA del
## cartel de recompensa, como la mano— y no dos palabras sueltas dentro del
## pergamino. La elegida va sobre una PLACA DE ORO que se DESLIZA de una mitad
## a la otra; la que no, en letra crema sobre la madera. Antes las dos iban en
## tinta y la elegida solo se distinguia por un atenuado (dicho por el usuario:
## "no queda clara cual es la eleccion escogida"). El genero ya no cambia el
## modelo (el cuerpo es uno), pero los dialogos lo siguen usando.
func _build_gender() -> void:
	var titulo := Label.new()
	titulo.text = "¿Cocinero o cocinera?"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.position = Vector2(50.0, _sheet.position.y + _sheet.size.y + 4.0)
	titulo.size = Vector2(size.x - 100.0, 32.0)
	titulo.add_theme_font_size_override("font_size", 24)
	titulo.add_theme_color_override("font_color", TINTA)
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(titulo)

	var seg := Control.new()
	seg.size = Vector2(GEN_SEG_W, GEN_SEG_H)
	seg.position = Vector2((size.x - GEN_SEG_W) * 0.5, titulo.position.y + 36.0)
	add_child(seg)
	_gen_seg = seg
	# El carril: el tablon de madera de siempre, con el margen del 9-slice
	# encogido a su alto (la misma regla que `skin_button`).
	var carril := PrepBoard.make_nine_patch(PrepBoard.BUTTON_TEX, PrepBoard.BUTTON_MARGIN)
	var m := int(GEN_SEG_H * 0.44)
	for np in [carril]:
		np.patch_margin_left = m
		np.patch_margin_top = m
		np.patch_margin_right = m
		np.patch_margin_bottom = m
	seg.add_child(carril)
	# La placa de oro (la de "¡Zarpar!"), UN solo nodo que viaja a la mitad
	# elegida: asi el cambio se ve como un deslizamiento y no como dos
	# botones que se encienden y se apagan.
	var placa := PrepBoard.make_nine_patch(PrepBoard.START_TEX, PrepBoard.START_MARGIN)
	placa.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# LOS MARGENES ANTES QUE LA TALLA: el minimo de un NinePatchRect es la
	# suma de sus margenes, y con los 54 de fabrica una placa de 48 de alto
	# se quedaba en 108 (medido: salia el doble de alta y pisaba las manos).
	var mp := int((GEN_SEG_H - 10.0) * 0.44)
	placa.patch_margin_left = mp
	placa.patch_margin_top = mp
	placa.patch_margin_right = mp
	placa.patch_margin_bottom = mp
	placa.position = Vector2(5.0, 5.0)
	placa.size = Vector2(GEN_SEG_W * 0.5 - 10.0, GEN_SEG_H - 10.0)
	seg.add_child(placa)
	_gen_placa = placa
	var gorda := load("res://fonts/static/Exo2-Bold.ttf")
	var i := 0
	for g in CharacterData.PLAYER_GENDERS:
		var b := Button.new()
		b.text = str(CharacterData.GENDER_TITLES.get(g, g))
		b.position = Vector2(GEN_SEG_W * 0.5 * i, 0.0)
		b.size = Vector2(GEN_SEG_W * 0.5, GEN_SEG_H)
		b.set_meta("g", g)
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.add_theme_font_size_override("font_size", 25)
		b.add_theme_constant_override("outline_size", 6)
		if gorda != null:
			b.add_theme_font_override("font", gorda)
		b.pressed.connect(func() -> void:
			if g_draft == str(g):
				return
			g_draft = str(g)
			_refresh()
			edited.emit())
		_gender_btns.append(b)
		seg.add_child(b)
		i += 1
	_refresh_genero(false)


## Coloca la placa bajo el genero elegido y pinta cada rotulo segun le toque:
## tinta oscura sobre el oro, crema sobre la madera.
func _refresh_genero(animar := true) -> void:
	if _gen_placa == null:
		return
	var i := CharacterData.PLAYER_GENDERS.find(g_draft)
	if i < 0:
		i = 0
	var destino := Vector2(5.0 + GEN_SEG_W * 0.5 * i, 5.0)
	if animar:
		var tw := _gen_placa.create_tween()
		tw.tween_property(_gen_placa, "position", destino, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_gen_placa.position = destino
	for b in _gender_btns:
		var elegido: bool = b.get_meta("g") == g_draft
		for col in ["font_color", "font_pressed_color", "font_hover_color",
				"font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(col,
				Color(0.32, 0.16, 0.05) if elegido else Color(1.0, 0.95, 0.84))
		b.add_theme_color_override("font_outline_color",
			Color(1.0, 0.93, 0.68) if elegido else Color(0.30, 0.17, 0.07))
		if elegido and animar:
			UIFx.bump(b, 1.10, 0.24)


func _refresh() -> void:
	for b in _hands:
		b.modulate = Color.WHITE if b.get_meta("h") == hand_draft \
				else Color(0.5, 0.5, 0.52)
	_refresh_genero()


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
	# El aspecto solo se fija en la ficha de tripulacion; despues no se toca.
	if editable_name:
		GameState.player_look = ChefLook.validar(look_draft)


## ¿Hay algo distinto de lo que ya está guardado? (Opciones lo usa para saber
## si "Aplicar cambios" tiene que estar encendido.)
func hay_cambios() -> bool:
	return g_draft != GameState.player_gender \
			or hand_draft != GameState.player_hand \
			or (editable_name and look_draft != ChefLook.validar(GameState.player_look))
