extends Node3D
## Menú principal: ESCENA 3D ANIMADA (el barco del jugador navegando en mar
## abierto, con islas y nubes que van quedando atrás, gaviotas y oleaje) más
## un CanvasLayer 2D con el logotipo y los botones de modo.
##
## COORDENADAS: misma cámara isométrica que el nivel y el mapa (pitch
## -35.264 / yaw 45 / orto), así que pantalla-derecha = R_HAT y
## pantalla-abajo = D_HAT. El barco está en el origen y todo lo demás se
## mueve hacia +D_HAT (hacia el espectador) para simular que avanzamos.

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
## Velocidad a la que el paisaje queda atrás (u/s).
const SCROLL_SPEED := 0.9
## Recorrido del decorado antes de reciclarse, medido sobre D_HAT.
const SCENERY_FAR := -22.0
const SCENERY_NEAR := 8.0

var cam: Camera3D
var ship_pivot: Node3D
var ship_base_y := 0.0
## Decorado en movimiento: { node, along, side, y, spin }.
var scenery: Array = []
var birds: Array = []
var logo: TextureRect
var _t := 0.0
## Capturas de verificación: vacío = juego normal.
var _shots_at := []
var _shot_idx := 0


func _ready() -> void:
	_setup_environment()
	_setup_sea()
	_setup_scenery()
	_setup_ship()
	_setup_birds()
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
	mi.material_override = mat
	add_child(mi)


## Islas, un barco enemigo lejano y nubes: van quedando atrás y se reciclan.
func _setup_scenery() -> void:
	# Escalonados en profundidad y siempre a los lados: el barco nunca queda
	# tapado y en la banda visible hay algo casi todo el rato.
	var defs := [
		{ "model": "res://assets/models/map_isla.glb", "foot": 5.0, "side": -10.0, "along": 2.0, "y": -0.1 },
		{ "model": "res://assets/models/map_isla.glb", "foot": 3.6, "side": 10.5, "along": -6.0, "y": -0.1 },
		{ "model": "res://assets/models/map_enemigo.glb", "foot": 3.0, "side": 8.5, "along": -13.0, "y": -0.06 },
		{ "model": "res://assets/models/map_puerto.glb", "foot": 4.4, "side": -11.0, "along": -20.0, "y": -0.1 },
	]
	for d in defs:
		var pivot := _spawn_model(load(d["model"]), Vector3.ZERO, float(d["foot"]))
		scenery.append({
			"node": pivot, "along": float(d["along"]), "side": float(d["side"]),
			"y": float(d["y"]), "cloud": false,
		})
	# Las nubes vuelan ALTO: en ortogonal eso las saca del encuadre y lo que
	# cruza el mar es su sombra, que es justo el efecto que se busca.
	for i in 5:
		scenery.append({
			"node": _make_cloud(), "along": -26.0 + i * 7.0,
			"side": randf_range(-13.0, 13.0), "y": randf_range(9.5, 12.0), "cloud": true,
		})
	_place_scenery()


## Nube low poly: cajas blancas apiladas en modo SOLO SOMBRA. La caja en sí
## no se dibuja (en ortogonal entraba en el encuadre como un bloque blanco
## raro); lo que se ve es su sombra cruzando el mar, que es lo que hace
## creíble que el barco avance.
func _make_cloud() -> Node3D:
	var pivot := Node3D.new()
	add_child(pivot)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.97, 0.97, 1.0)
	mat.roughness = 1.0
	for p in [Vector3(0, 0, 0), Vector3(1.6, -0.3, 0.4), Vector3(-1.5, -0.35, -0.3),
			Vector3(0.2, 0.55, -0.2)]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.9, 1.1, 2.2) if p == Vector3.ZERO else Vector3(2.0, 0.85, 1.6)
		mi.mesh = box
		mi.position = p
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		pivot.add_child(mi)
	return pivot


func _place_scenery() -> void:
	for s in scenery:
		var n: Node3D = s["node"]
		n.position = R_HAT * float(s["side"]) + D_HAT * float(s["along"]) \
				+ Vector3(0.0, float(s["y"]), 0.0)


func _setup_ship() -> void:
	ship_pivot = _spawn_model(load("res://assets/models/map_barco.glb"),
		Vector3.ZERO, SHIP_FOOT)
	ship_pivot.position.y = -0.12
	ship_base_y = ship_pivot.position.y
	ship_pivot.rotation_degrees.y = SHIP_YAW


## Gaviotas: cuerpo oscuro y dos alas en V que baten, describiendo círculos
## sobre el barco. La V y el cuerpo son necesarios: con las alas planas y
## alineadas, desde la cámara isométrica solo se veía una barra blanca.
func _setup_birds() -> void:
	var wing_mat := StandardMaterial3D.new()
	wing_mat.albedo_color = Color(0.97, 0.97, 0.95)
	wing_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.35, 0.36, 0.42)
	body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 3:
		var pivot := Node3D.new()
		add_child(pivot)
		var body := MeshInstance3D.new()
		var body_box := BoxMesh.new()
		body_box.size = Vector3(0.16, 0.12, 0.46)
		body.mesh = body_box
		body.material_override = body_mat
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(body)
		var wings: Array = []
		for sgn in [-1.0, 1.0]:
			var hinge := Node3D.new()
			pivot.add_child(hinge)
			var mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.52, 0.04, 0.2)
			mi.mesh = box
			mi.position = Vector3(sgn * 0.3, 0.0, 0.0)
			mi.material_override = wing_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			hinge.add_child(mi)
			wings.append(hinge)
		birds.append({
			"node": pivot, "wings": wings, "radius": 4.2 + i * 1.6,
			"phase": randf() * TAU, "speed": 0.34 - i * 0.06,
			"y": 4.6 + i * 0.9, "flap": 5.0 + i,
		})


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

	# El paisaje queda atrás y vuelve a aparecer por el horizonte.
	for s in scenery:
		s["along"] = float(s["along"]) + SCROLL_SPEED * delta
		if float(s["along"]) > SCENERY_NEAR:
			s["along"] = SCENERY_FAR
			# Las islas y barcos vuelven siempre por un lateral; las nubes
			# pueden cruzar por cualquier parte porque van por el aire.
			if bool(s["cloud"]):
				s["side"] = randf_range(-13.0, 13.0)
			else:
				s["side"] = randf_range(8.0, 12.0) * (1.0 if randf() < 0.5 else -1.0)
	_place_scenery()

	# Gaviotas: círculos lentos con aleteo.
	for b in birds:
		var ang := _t * float(b["speed"]) * TAU + float(b["phase"])
		var n: Node3D = b["node"]
		var r: float = b["radius"]
		n.position = R_HAT * (cos(ang) * r) + D_HAT * (sin(ang) * r * 0.6) \
				+ Vector3(0.0, float(b["y"]) + sin(_t * 1.6 + float(b["phase"])) * 0.35, 0.0)
		n.rotation.y = -ang
		# Alas siempre en V (base 0.32 rad) más el aleteo.
		var flap := 0.32 + sin(_t * float(b["flap"])) * 0.42
		b["wings"][0].rotation.z = flap
		b["wings"][1].rotation.z = -flap

	_update_camera(sin(_t * 0.55) * 0.22)
	_capture_step()


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

	# Botones de modo, anclados abajo.
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = 150.0
	box.offset_right = -150.0
	box.offset_top = -430.0
	box.offset_bottom = -70.0
	box.add_theme_constant_override("separation", 26)
	ui.add_child(box)
	box.add_child(_make_mode_button("Aventura", func() -> void:
		get_tree().change_scene_to_file("res://scenes/level_select3d.tscn")))
	box.add_child(_make_mode_button("Tienda", func() -> void:
		get_tree().change_scene_to_file("res://scenes/shop_screen.tscn")))
	box.add_child(_make_mode_button("Prueba", func() -> void:
		GameState.mode = "test"
		GameState.current_port = ""
		GameState.selected_recipes = []
		get_tree().change_scene_to_file("res://scenes/prep_screen.tscn")))


func _make_mode_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(420, 108)
	PrepBoard.skin_button(b)
	b.add_theme_font_size_override("font_size", 42)
	b.pressed.connect(action)
	return b


## Capturas automáticas para verificación visual (vacío en el juego normal).
func _capture_step() -> void:
	if _shot_idx >= _shots_at.size():
		return
	if _t < float(_shots_at[_shot_idx]):
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://_menu_shot%d.png" % _shot_idx)
	_shot_idx += 1
	if _shot_idx >= _shots_at.size():
		get_tree().quit()
