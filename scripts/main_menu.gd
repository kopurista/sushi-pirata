extends Node3D
## Menú principal: ESCENA 3D ANIMADA (el barco del jugador cabeceando en mar
## abierto, con gaviotas dando vueltas) más un CanvasLayer 2D con el logotipo
## y los botones de modo.
##
## COORDENADAS: misma cámara isométrica que el nivel y el mapa (pitch
## -35.264 / yaw 45 / orto), así que pantalla-derecha = R_HAT y
## pantalla-abajo = D_HAT.
##
## DECISIÓN: en el mar SOLO va el barco. Se probaron islas/puertos/barcos
## pasando de largo, sombras de nubes cruzando el agua y gaviotas en círculos,
## y todo ello ensuciaba el encuadre: se quitó.

const PrepBoard := preload("res://scripts/prep_board.gd")

const CAM_PITCH := -35.264
const CAM_YAW := 45.0
const CAM_SIZE := 15.0
const R_HAT := Vector3(0.70710678, 0.0, -0.70710678)
const D_HAT := Vector3(0.70710678, 0.0, 0.70710678)
## Píxeles por unidad en vertical de pantalla (viewport 1280 / size 15, por
## el seno del pitch): sirve para encuadrar el barco a la altura que queremos.
const PPU_Y := (1280.0 / CAM_SIZE) * 0.57735
## El barco debe quedar en el hueco entre el logotipo y los botones, algo por
## DEBAJO del centro de la pantalla (valor negativo = baja la escena).
const BAND_OFF := -80.0

const SHIP_FOOT := 6.4
## El barco navega hacia la parte alta de la pantalla (mismo criterio que el
## mapa de campaña).
const SHIP_YAW := 205.0

var cam: Camera3D
var ship_pivot: Node3D
var ship_base_y := 0.0
var logo: TextureRect
var _t := 0.0


## Tope de fotogramas de las pantallas sin juego.
const MENU_FPS := 30


func _ready() -> void:
	# Las pantallas de menu se conforman con 30 fps: aqui no se juega y
	# renderizar el doble de fotogramas solo gasta bateria.
	Engine.max_fps = MENU_FPS
	_setup_environment()
	_setup_sea()
	_setup_ship()
	_setup_camera()
	_setup_ui()


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.46, 0.66, 0.80)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.82, 0.92)
	env.ambient_light_energy = 0.95
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -125.0, 0.0)
	sun.light_energy = 1.2
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	add_child(sun)


## Mar: el mismo shader animado del mapa de campaña (deriva + senos cruzados).
func _setup_sea() -> void:
	var tex: Texture2D = load("res://assets/map/mar.png")
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(90.0, 90.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water_map_3d.gdshader")
	mat.set_shader_parameter("sea_tex", tex)
	mat.set_shader_parameter("tile_scale", Vector2(7.0, 7.0))
	mat.set_shader_parameter("tint", Vector3(0.62, 0.76, 0.96))
	mat.set_shader_parameter("deep_color", Vector3(0.10, 0.24, 0.45))
	mat.set_shader_parameter("flatten", 0.80)
	mat.set_shader_parameter("drift_speed", 0.055)
	# El plano del mar no proyecta sombra sobre nada: fuera del pase de sombras.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = mat
	add_child(mi)


func _setup_ship() -> void:
	ship_pivot = _spawn_model(load("res://assets/models/map_barco.glb"),
		Vector3.ZERO, SHIP_FOOT)
	ship_pivot.position.y = -0.12
	ship_base_y = ship_pivot.position.y
	ship_pivot.rotation_degrees.y = SHIP_YAW


func _setup_camera() -> void:
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(CAM_PITCH, CAM_YAW, 0.0)
	cam.size = CAM_SIZE
	add_child(cam)
	cam.make_current()
	_update_camera(0.0)


## El objetivo se desplaza por el suelo para subir el barco en pantalla; el
## leve vaivén simula el propio balanceo de la cubierta.
func _update_camera(sway: float) -> void:
	var target := D_HAT * (BAND_OFF / PPU_Y) + R_HAT * sway
	cam.position = target + cam.transform.basis.z * 30.0


## Instancia un GLB normalizado por su HUELLA horizontal (igual que el mapa).
func _spawn_model(scene: PackedScene, ground_pos: Vector3, target_foot: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = ground_pos
	add_child(pivot)
	var inst: Node3D = scene.instantiate()
	pivot.add_child(inst)
	var aabb := _merged_aabb(inst)
	var foot := maxf(maxf(aabb.size.x, aabb.size.z), 0.0001)
	var s := target_foot / foot
	inst.scale = Vector3.ONE * s
	inst.position = -Vector3(
		aabb.position.x + aabb.size.x * 0.5,
		aabb.position.y,
		aabb.position.z + aabb.size.z * 0.5) * s
	return pivot


func _merged_aabb(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = m.transform * m.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


func _process(delta: float) -> void:
	_t += delta

	# Cabeceo, balanceo y flotación del barco sobre las olas.
	if ship_pivot != null:
		ship_pivot.rotation_degrees.x = sin(_t * 1.15) * 3.2
		ship_pivot.rotation_degrees.z = sin(_t * 0.83 + 1.1) * 4.0
		ship_pivot.position.y = ship_base_y + sin(_t * 1.35) * 0.14

	_update_camera(sin(_t * 0.55) * 0.22)


# ------------------------------------------------------------------- UI 2D

func _setup_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	# Monedero arriba a la derecha.
	var money_box := HBoxContainer.new()
	money_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	money_box.offset_left = -220.0
	money_box.offset_top = 24.0
	money_box.offset_right = -24.0
	money_box.offset_bottom = 76.0
	money_box.alignment = BoxContainer.ALIGNMENT_END
	money_box.add_theme_constant_override("separation", 8)
	var coin := TextureRect.new()
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture = load("res://assets/ui/moneda.png")
	coin.custom_minimum_size = Vector2(44, 44)
	money_box.add_child(coin)
	var money_label := Label.new()
	money_label.text = "%d" % GameState.money
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_label.add_theme_font_size_override("font_size", 34)
	money_label.add_theme_color_override("font_color", Color(1, 0.86, 0.4))
	money_label.add_theme_color_override("font_outline_color", Color.BLACK)
	money_label.add_theme_constant_override("outline_size", 6)
	money_box.add_child(money_label)
	ui.add_child(money_box)

	# Logotipo 3D del juego, flotando sobre el mar.
	logo = TextureRect.new()
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture = load("res://assets/ui/logo_sushi_pirata.webp")
	logo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	logo.offset_left = 26.0
	logo.offset_right = -26.0
	logo.offset_top = 96.0
	logo.offset_bottom = 436.0
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(logo)
	logo.pivot_offset = Vector2(334, 170)
	var lt := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	lt.tween_property(logo, "position:y", 14.0, 1.9).as_relative()
	lt.tween_property(logo, "position:y", -14.0, 1.9).as_relative()
	var rt := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	rt.tween_property(logo, "rotation", deg_to_rad(1.4), 2.6)
	rt.tween_property(logo, "rotation", deg_to_rad(-1.4), 2.6)

	# Botones de modo, anclados abajo. Aventura destaca (es el modo principal).
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = 110.0
	box.offset_right = -110.0
	box.offset_top = -486.0
	box.offset_bottom = -54.0
	box.add_theme_constant_override("separation", 16)
	ui.add_child(box)
	box.add_child(_make_mode_button("Aventura", "ic_aventura", 118, 44,
		func() -> void:
			get_tree().change_scene_to_file("res://scenes/level_select3d.tscn")))
	box.add_child(_make_mode_button("Arcade", "ic_arcade", 96, 36,
		func() -> void:
			GameState.mode = "test"
			GameState.current_port = ""
			GameState.selected_recipes = []
			get_tree().change_scene_to_file("res://scenes/prep_screen.tscn")))
	box.add_child(_make_mode_button("Tienda", "ic_tienda", 96, 36,
		func() -> void:
			get_tree().change_scene_to_file("res://scenes/shop_screen.tscn")))
	box.add_child(_make_mode_button("Inventario", "ic_inventario", 96, 36,
		func() -> void:
			get_tree().change_scene_to_file("res://scenes/inventory_screen.tscn")))


## Botón del menú: tabla de madera con marco dorado, icono a la izquierda y
## rótulo centrado sobre el conjunto.
func _make_mode_button(text: String, icon: String, height: int, font_size: int,
		action: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(500, height)
	PrepBoard.skin_button(b)
	b.pressed.connect(action)

	var icon_rect := TextureRect.new()
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = load("res://assets/ui/%s.png" % icon)
	icon_rect.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	icon_rect.offset_left = 22.0
	icon_rect.offset_right = 22.0 + height * 0.78
	icon_rect.offset_top = height * 0.12
	icon_rect.offset_bottom = -height * 0.12
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon_rect)

	var label := Label.new()
	label.text = text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = height * 0.9
	label.offset_right = -20.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	label.add_theme_color_override("font_outline_color", Color(0.13, 0.07, 0.02))
	label.add_theme_constant_override("outline_size", 9)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(label)
	return b
