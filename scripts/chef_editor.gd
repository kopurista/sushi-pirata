class_name ChefEditor
extends Control
## EL PERSONALIZADOR DEL CHEF: la ventana donde se elige piel, peinado, color,
## nariz, barba y gafas, con el busto del chef vivo arriba para ver cada cambio
## al momento. Se abre desde el cartel de recompensa (`WantedPoster`) la
## primera vez —la ficha de tripulación de David— y lo elegido NO se puede
## cambiar después (decidido por el usuario).
##
## Va en un CanvasLayer propio, por encima de la interfaz que lo abre, y a
## pantalla completa con `GameState.canvas_size()`: el cartel que lo abre
## puede ir ESCALADO (en el Perfil) y un hijo suyo heredaría esa escala.
##
## No toca `GameState`: trabaja sobre su propio diccionario (`look`) y quien lo
## abre lo recoge al cerrarse (señal `cerrado`).

const PrepBoard := preload("res://scripts/prep_board.gd")

const TINTA := Color(0.24, 0.15, 0.08)
const ARROW_R := "res://assets/ui/ic_siguiente.png"
const ARROW_L := "res://assets/ui/ic_siguiente_esp.png"
const ARROW := 46.0
const PANEL_W := 660.0
const PANEL_H := 950.0
const PREVIEW := Vector2(300.0, 300.0)
## Encuadre del busto, como en el cartel: la banda de arriba del personaje.
const CAM_FOV := 34.0
const CAM_BAND := 0.42
const CAM_AIR := 0.04
const FILA_H := 66.0
const MUESTRA := 50.0

signal cerrado

var look: Dictionary = ChefLook.por_defecto()

var _viewport: SubViewport = null
var _cam: Camera3D = null
var _modelo: Node3D = null
var _anim: CharacterAnim = null
var _t := 0.0
## Los rótulos y las muestras que hay que repintar al cambiar algo.
var _rotulos: Dictionary = {}
var _muestras: Dictionary = {}
var _gafas_btn: Button = null


func _ready() -> void:
	look = ChefLook.validar(look)
	var lienzo := GameState.canvas_size()
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = lienzo
	# El velo se traga TODO el toque: mientras se personaliza no se puede
	# escribir el nombre ni pulsar nada de lo que hay debajo.
	var velo := ColorRect.new()
	velo.color = Color(0.0, 0.0, 0.0, 0.62)
	velo.position = Vector2.ZERO
	velo.size = lienzo
	velo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(velo)

	var panel := PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN)
	var alto: float = minf(PANEL_H, lienzo.y - GameState.safe_top() - 40.0)
	panel.position = Vector2((lienzo.x - PANEL_W) * 0.5,
		GameState.safe_top() + (lienzo.y - GameState.safe_top() - alto) * 0.5)
	panel.size = Vector2(PANEL_W, alto)
	add_child(panel)

	var titulo := Label.new()
	titulo.text = "Tu aspecto"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.position = Vector2(0.0, 34.0)
	titulo.size = Vector2(PANEL_W, 44.0)
	titulo.add_theme_font_size_override("font_size", 36)
	titulo.add_theme_color_override("font_color", TINTA)
	var gorda := load("res://fonts/static/Exo2-Bold.ttf")
	if gorda != null:
		titulo.add_theme_font_override("font", gorda)
	panel.add_child(titulo)

	_build_preview(panel, Vector2((PANEL_W - PREVIEW.x) * 0.5, 84.0))

	var y := 84.0 + PREVIEW.y + 16.0
	_fila_muestras(panel, y, "Piel", "piel", ChefLook.PIELES, ChefLook.PIELES_MUESTRA)
	y += FILA_H
	_fila_flechas(panel, y, "Peinado", "pelo", ChefLook.PELOS, ChefLook.PELOS_NOMBRE)
	y += FILA_H
	_fila_muestras(panel, y, "Color", "color", ChefLook.COLORES, ChefLook.COLORES_RGB)
	y += FILA_H
	_fila_flechas(panel, y, "Nariz", "nariz", ChefLook.NARICES, ChefLook.NARICES_NOMBRE)
	y += FILA_H
	_fila_flechas(panel, y, "Barba", "barba", ChefLook.BARBAS, ChefLook.BARBAS_NOMBRE)
	y += FILA_H
	_fila_gafas(panel, y)
	y += FILA_H + 12.0

	var ok := Button.new()
	ok.text = "¡Así soy yo!"
	ok.position = Vector2((PANEL_W - 340.0) * 0.5, alto - 62.0 - 82.0)
	ok.size = Vector2(340.0, 82.0)
	PrepBoard.skin_button(ok)
	PrepBoard.add_press_feedback(ok)
	ok.add_theme_font_size_override("font_size", 30)
	ok.pressed.connect(_cerrar)
	panel.add_child(ok)
	_repintar()


func _process(delta: float) -> void:
	if _anim == null or not GameState.animations_on():
		return
	_t += delta
	_anim.reset()
	_anim.idle(_t)


# ------------------------------------------------------------ el busto vivo

func _build_preview(panel: Control, pos: Vector2) -> void:
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.size = Vector2i(PREVIEW)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_cam = Camera3D.new()
	_cam.fov = CAM_FOV
	_viewport.add_child(_cam)
	# La luz floja del cartel de recompensa: con la del nivel las caras claras
	# se queman y el personaje sale sin rasgos.
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-32.0, 38.0, 0.0)
	sol.light_energy = 0.62
	sol.shadow_enabled = false
	_viewport.add_child(sol)
	var relleno := DirectionalLight3D.new()
	relleno.rotation_degrees = Vector3(-12.0, -128.0, 0.0)
	relleno.light_energy = 0.26
	relleno.shadow_enabled = false
	_viewport.add_child(relleno)

	var marco := PrepBoard.make_nine_patch(PrepBoard.CARD_TEX, PrepBoard.CARD_MARGIN)
	marco.position = pos - Vector2(10.0, 10.0)
	marco.size = PREVIEW + Vector2(20.0, 20.0)
	panel.add_child(marco)
	var pic := TextureRect.new()
	pic.texture = _viewport.get_texture()
	pic.position = pos
	pic.size = PREVIEW
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(pic)
	_montar()


## Rehace el busto con el aspecto de ahora mismo. Es barato (un cuerpo y cinco
## piezas), así que cada cambio lo rehace entero en vez de cambiar una pieza.
func _montar() -> void:
	if _modelo != null:
		_modelo.queue_free()
	_modelo = ChefLook.montar(look)
	_viewport.add_child(_modelo)
	_anim = null
	var skels := _modelo.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		var a := CharacterAnim.new(skels[0])
		if a.has_humanoid_bones():
			_anim = a
			_anim.reset()
			_anim.idle(_t)
	_encuadrar()


## La cámara, sobre el AABB del CUERPO (no del pelo: una melena alta cambiaría
## el encuadre de un peinado a otro y la cara bailaría al elegir).
func _encuadrar() -> void:
	var medir: Node = _modelo.get_meta("cuerpo") if _modelo.has_meta("cuerpo") else _modelo
	var caja := _aabb(medir)
	if caja.size.y <= 0.0:
		return
	var banda: float = caja.size.y * CAM_BAND
	var arriba: float = caja.position.y + caja.size.y
	var centro_y: float = arriba - banda * (0.5 - CAM_AIR)
	var d: float = banda / (2.0 * tan(deg_to_rad(CAM_FOV) * 0.5))
	var c := caja.get_center()
	_cam.position = Vector3(c.x, centro_y, caja.position.z + caja.size.z + d)
	_cam.rotation_degrees = Vector3.ZERO


func _aabb(n: Node, acc := AABB()) -> AABB:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var suya: AABB = mi.global_transform * mi.get_aabb()
		acc = suya if acc.size == Vector3.ZERO else acc.merge(suya)
	for c in n.get_children():
		acc = _aabb(c, acc)
	return acc


# ---------------------------------------------------------------- las filas

func _rotulo_fila(panel: Control, y: float, texto: String) -> void:
	var l := Label.new()
	l.text = texto
	l.position = Vector2(48.0, y)
	l.size = Vector2(150.0, FILA_H - 8.0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", TINTA)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(l)


## Una fila de MUESTRAS de color (piel, color de pelo): un botón por opción.
func _fila_muestras(panel: Control, y: float, texto: String, campo: String,
		opciones: Array, colores: Dictionary) -> void:
	_rotulo_fila(panel, y, texto)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 18)
	fila.position = Vector2(206.0, y + (FILA_H - 8.0 - MUESTRA) * 0.5)
	fila.size = Vector2(PANEL_W - 206.0 - 40.0, MUESTRA)
	panel.add_child(fila)
	var botones: Array[Button] = []
	for op in opciones:
		var b := Button.new()
		b.custom_minimum_size = Vector2(MUESTRA, MUESTRA)
		b.set_meta("op", op)
		var st := StyleBoxFlat.new()
		st.bg_color = colores[op]
		st.set_corner_radius_all(int(MUESTRA * 0.5))
		st.set_border_width_all(3)
		st.border_color = TINTA
		for k in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(k, st)
		PrepBoard.add_press_feedback(b, 0.86)
		b.pressed.connect(func() -> void: _poner(campo, op))
		fila.add_child(b)
		botones.append(b)
	_muestras[campo] = botones


## Una fila con FLECHAS a los lados y el nombre de la opción en medio.
func _fila_flechas(panel: Control, y: float, texto: String, campo: String,
		opciones: Array, nombres: Dictionary) -> void:
	_rotulo_fila(panel, y, texto)
	var x0 := 206.0
	var w := PANEL_W - x0 - 40.0
	var nombre := Label.new()
	nombre.position = Vector2(x0 + ARROW, y)
	nombre.size = Vector2(w - ARROW * 2.0, FILA_H - 8.0)
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nombre.add_theme_font_size_override("font_size", 26)
	nombre.add_theme_color_override("font_color", TINTA)
	nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(nombre)
	_rotulos[campo] = { "label": nombre, "nombres": nombres }
	for der in [false, true]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(ARROW, ARROW)
		b.size = Vector2(ARROW, ARROW)
		b.position = Vector2(x0 + (w - ARROW if der else 0.0),
			y + (FILA_H - 8.0 - ARROW) * 0.5)
		for k in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(k, StyleBoxEmpty.new())
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = load(ARROW_R if der else ARROW_L)
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		PrepBoard.add_press_feedback(b, 0.84)
		var paso := 1 if der else -1
		b.pressed.connect(func() -> void:
			var i: int = opciones.find(look[campo])
			_poner(campo, opciones[posmod(i + paso, opciones.size())]))
		panel.add_child(b)


func _fila_gafas(panel: Control, y: float) -> void:
	_rotulo_fila(panel, y, "Gafas")
	_gafas_btn = Button.new()
	_gafas_btn.position = Vector2(206.0, y + 4.0)
	_gafas_btn.size = Vector2(PANEL_W - 206.0 - 40.0, FILA_H - 16.0)
	PrepBoard.skin_small_button(_gafas_btn)
	PrepBoard.add_press_feedback(_gafas_btn)
	_gafas_btn.add_theme_font_size_override("font_size", 24)
	_gafas_btn.pressed.connect(func() -> void:
		look["gafas"] = not bool(look["gafas"])
		_cambiado())
	panel.add_child(_gafas_btn)


func _poner(campo: String, valor: String) -> void:
	if look[campo] == valor:
		return
	look[campo] = valor
	_cambiado()


func _cambiado() -> void:
	_repintar()
	_montar()


## Rótulos, muestra elegida y el botón de las gafas, al día con `look`.
func _repintar() -> void:
	for campo in _rotulos:
		var r: Dictionary = _rotulos[campo]
		(r["label"] as Label).text = str(r["nombres"].get(look[campo], look[campo]))
	for campo in _muestras:
		for b in _muestras[campo]:
			var elegida: bool = b.get_meta("op") == look[campo]
			b.modulate = Color.WHITE if elegida else Color(0.78, 0.78, 0.78)
			b.scale = Vector2.ONE * (1.14 if elegida else 1.0)
			b.pivot_offset = Vector2(MUESTRA, MUESTRA) * 0.5
	if _gafas_btn != null:
		_gafas_btn.text = "Con gafas" if bool(look["gafas"]) else "Sin gafas"


func _cerrar() -> void:
	cerrado.emit()
	queue_free()
