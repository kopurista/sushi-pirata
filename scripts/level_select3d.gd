extends Node3D
## Aventura: MAPA MARÍTIMO en 3D low poly (port de level_select.gd con la
## misma lógica). El barco del jugador navega por un mar animado por shader
## entre los nodos de la campaña (modelos 3D: isla / puerto / barco enemigo).
##
## COORDENADAS: el mapa vive en el plano X/Z y se sigue trabajando en los
## "píxeles de mapa" 2D de CampaignData.MAP_POS (lienzo 720 x MAP_HEIGHT):
## _world() los convierte a mundo con la misma cámara isométrica del nivel
## (yaw 45: pantalla-derecha = (1,0,-1)/√2, pantalla-abajo = (1,0,1)/√2).
## Así los carriles, anclas del barco y el scroll del 2D valen tal cual.
##
## La UI (barra superior, panel de información, estrellas, carteles con el
## número y el botón táctil de cada nodo) sigue siendo 2D: los overlays de los
## nodos se reproyectan cada fotograma con la cámara.

const PrepBoard := preload("res://scripts/prep_board.gd")
const DARK := Color(0.26, 0.16, 0.08)
const FADED := Color(0.42, 0.3, 0.18)

## Rótulo del mapa: tiene que caber en el hueco que dejan los dos contadores de
## arriba (el dinero pegado a la izquierda y el arroz a la derecha). El ALTO es
## fijo a propósito: estirándolo, la cinta se pegaba al canto superior y el
## texto quedaba descolgado respecto al dibujo de la tela.
const TITLE_W := 322.0
const TITLE_H := 88.0

## Píxeles por unidad de mundo con la cámara orto (size 15, viewport 1280 alto)
## en horizontal de pantalla, y su proyección sobre el suelo en vertical.
const PPU_X := 1280.0 / 15.0
const PPU_Y := PPU_X * 0.57735            ## * sin(35.264°)
const R_HAT := Vector3(0.70710678, 0.0, -0.70710678)
const D_HAT := Vector3(0.70710678, 0.0, 0.70710678)

const CAM_PITCH := -35.264
const CAM_YAW := 45.0
const CAM_SIZE := 15.0
## La franja visible del mapa queda entre la barra superior (76 px) y el panel
## de información (1280-356 = 924 px): su centro está en y=500, es decir 140 px
## por encima del centro de la pantalla (640).
const BAND_CENTER_OFF := 140.0
## Límites del scroll (centro de la franja, en px de mapa).
const SCROLL_MIN := 424.0
const SCROLL_MAX := CampaignData.MAP_HEIGHT - 300.0

## Modelo 3D de cada tipo de nodo y huella horizontal objetivo (u).
const KIND_MODELS := {
	"isla": "res://assets/models/map_isla.glb",
	"puerto": "res://assets/models/map_puerto.glb",
	"abordaje": "res://assets/models/map_enemigo.glb",
}
const KIND_FOOT := { "isla": 2.6, "puerto": 2.9, "abordaje": 2.5 }
const SHIP_FOOT := 2.3
## Orientación base del barco (navega hacia la parte alta del mapa).
const SHIP_YAW := 205.0

var cam: Camera3D
var ui: CanvasLayer
## Piezas de la interfaz del mapa, para poder apagarlas cuando la escena hace
## de menú principal (main_menu.gd hereda de este script).
var map_ui_root: Control = null
var map_top_bar: Control = null
var map_info_panel: Control = null
var selected_id: String = ""
## Centro de la franja visible, en px de mapa (el equivalente del scroll 2D).
var cam_center := SCROLL_MAX
var scroll_tween: Tween = null
## Inercia del arrastre del mapa (px de mapa por segundo) y cómo se apaga.
var scroll_speed := 0.0
var scroll_dragging := false
const SCROLL_FRICTION := 0.05
const SCROLL_STOP := 14.0
const DRAG_SMOOTH := 0.7
## Posición del barco en px de mapa; un tween la anima al viajar.
var ship_px := Vector2(360, 1560)
var ship_pivot: Node3D
var ship_blob: MeshInstance3D = null
var ship_tween: Tween = null
var ship_roll := 0.0
var _t := 0.0

## Overlays 2D por nodo: { id: {root, unlocked} } reposicionados por frame.
var node_overlays: Dictionary = {}
var node_world: Dictionary = {}
## Con la escena en modo menú, los carteles de nivel no se dibujan.
var map_visible := true

# --- Widgets del panel de información (idénticos al 2D) ---
var info_title: Label
var info_kind: Label
var info_desc: Label
var info_time: Label
var info_goal: Label
var info_record: Label
## Filas de iconos: clientes (cabeza + xN), recetas utilizables y recompensas.
var info_clients_row: HBoxContainer
var info_recipes_row: HBoxContainer
var info_reward_row: HBoxContainer
var info_stars_box: Control
## Filas gráficas del objetivo (estrellas + moneda + cifra).
var goal_box: VBoxContainer = null
## Fila del récord (moneda + cifra).
var record_box: HBoxContainer = null
var sail_button: Button


## Px de mapa (lienzo 2D de CampaignData) -> punto del mundo en el plano del mar.
func _world(p: Vector2) -> Vector3:
	return R_HAT * ((p.x - 360.0) / PPU_X) + D_HAT * (p.y / PPU_Y)


func _ready() -> void:
	# Las pantallas de menu van a la mitad de fotogramas que el juego
	# (GameState.fps_for): aqui no se juega y renderizar mas gasta bateria.
	Engine.max_fps = GameState.fps_for(false)
	_setup_environment()
	_setup_sea()
	_setup_route()
	_setup_nodes()
	_setup_ship()
	_setup_camera()
	# Los ~100 guiones de la ruta son geometría fija: se funden en una malla.
	GeometryBatch.bake(self, "RouteBatch")
	_setup_ui()

	_focus_last_port(false)


## Coloca la vista y el barco en el nivel más avanzado disponible.
func _focus_last_port(animate: bool) -> void:
	var start_id := last_open_port()
	if not animate:
		ship_px = _ship_anchor(start_id)
		cam_center = clampf(CampaignData.map_pos(start_id).y, SCROLL_MIN, SCROLL_MAX)
		_update_camera()
	_select(start_id, animate)


## Último nivel de la campaña que el jugador tiene abierto.
func last_open_port() -> String:
	var start_id := CampaignData.first_port_id()
	for p in CampaignData.PORTS:
		if GameState.is_port_unlocked(p.id):
			start_id = p.id
	return start_id


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.12, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.80, 0.92)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -125.0, 0.0)
	sun.light_energy = 1.1
	sun.light_color = Color(1.0, 0.96, 0.9)
	# Sin sombras proyectadas en todo el juego: cada cosa lleva su mancha
	# fija (SceneBackdrop.blob_shadow).
	sun.shadow_enabled = false
	add_child(sun)


## Mar: plano enorme con el shader de agua (deriva + senos cruzados), tileado
## a la misma escala 1:1 que en el 2D (el tamaño del tile sale de la textura).
func _setup_sea() -> void:
	var tex: Texture2D = load("res://assets/map/mar.png")
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(98.0, 98.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = D_HAT * ((CampaignData.MAP_HEIGHT * 0.5 + 640.0) / PPU_Y)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water_map_3d.gdshader")
	mat.set_shader_parameter("sea_tex", tex)
	# Tiles algo mayores que en 2D; el shader ademas aplana el mosaico contra
	# un azul profundo (a pelo, el enrejado de rombos leia como una manta).
	var tile_u := float(tex.get_width()) / PPU_X * 1.25
	mat.set_shader_parameter("tile_scale", Vector2(98.0 / tile_u, 98.0 / tile_u))
	mat.set_shader_parameter("tint", Vector3(0.55, 0.68, 0.9))
	# El plano del mar no proyecta sombra sobre nada: fuera del pase de sombras.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = mat
	add_child(mi)


## Ruta discontinua entre niveles consecutivos: guiones planos sobre el agua.
func _setup_route() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.32)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(CampaignData.PORTS.size() - 1):
		var a := _world(CampaignData.map_pos(CampaignData.PORTS[i].id))
		var b := _world(CampaignData.map_pos(CampaignData.PORTS[i + 1].id))
		var seg := b - a
		var total := seg.length()
		var dir := seg / total
		var t := 0.35
		while t < total - 0.3:
			var e := minf(t + 0.24, total)
			var dash := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3((e - t), 0.02, 0.07)
			dash.mesh = box
			dash.material_override = mat
			dash.position = a + dir * ((t + e) * 0.5) + Vector3(0.0, 0.025, 0.0)
			dash.rotation_degrees.y = rad_to_deg(atan2(dir.x, dir.z)) - 90.0
			add_child(dash)
			t = e + 0.2


func _setup_nodes() -> void:
	for p in CampaignData.PORTS:
		var id: String = p.id
		var kind := CampaignData.get_kind(id)
		var pos := _world(CampaignData.map_pos(id))
		node_world[id] = pos
		var pivot := _spawn_model(load(KIND_MODELS[kind]), pos,
			float(KIND_FOOT.get(kind, 2.5)))
		# Los barcos se hunden un poco en el agua; las islas asientan su base.
		pivot.position.y = -0.10 if kind != "abordaje" else -0.06
		# Los nodos NO proyectan sombra: son 9 modelos de ~40k triangulos y el
		# pase de sombras los dibujaba otra vez enteros, para una mancha que
		# desde esta camara casi no se ve.
		for m in pivot.find_children("*", "MeshInstance3D", true, false):
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var foot: float = float(KIND_FOOT.get(kind, 2.5))
		var blob := SceneBackdrop.blob_shadow(foot * 0.95, foot * 0.62)
		blob.position = pos + Vector3(0.15, 0.03, 0.1)
		add_child(blob)
		if not GameState.is_port_unlocked(id):
			_dim_model(pivot)


## Oscurece un modelo bloqueado con una pasada extra translúcida (el modulate
## de los sprites 2D no existe en 3D).
func _dim_model(root: Node3D) -> void:
	var shade := StandardMaterial3D.new()
	shade.albedo_color = Color(0.08, 0.12, 0.22, 0.55)
	shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for m in root.find_children("*", "MeshInstance3D", true, false):
		m.material_overlay = shade


func _setup_ship() -> void:
	ship_pivot = _spawn_model(load("res://assets/models/map_barco.glb"),
		_world(ship_px), SHIP_FOOT)
	ship_pivot.position.y = -0.06
	ship_pivot.rotation_degrees.y = SHIP_YAW
	# El barco lleva su mancha, que viaja con él (ver _update_ship_visual).
	# MÁS PEQUEÑA QUE LA HUELLA DEL BARCO, a propósito. Es una sombra plana a
	# ras de agua y, con la cámara isométrica, lo que está BAJO y CERCA queda
	# por delante en profundidad de lo que está ALTO y AL FONDO: con la mancha
	# a la medida del casco, su esquina cercana ganaba el test de profundidad
	# a las velas y se veía un borrón oscuro sobre la vela de arriba (en el
	# menú, donde el barco va a escala 2.3, saltaba a la vista).
	ship_blob = SceneBackdrop.blob_shadow(SHIP_FOOT * 0.62, SHIP_FOOT * 0.36)
	add_child(ship_blob)


func _setup_camera() -> void:
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(CAM_PITCH, CAM_YAW, 0.0)
	cam.size = CAM_SIZE
	add_child(cam)
	cam.make_current()
	_update_camera()


func _update_camera() -> void:
	var target := _world(Vector2(360.0, cam_center + BAND_CENTER_OFF))
	cam.position = target + cam.transform.basis.z * 30.0


## Instancia un GLB normalizado por su HUELLA horizontal máxima.
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


# --- UI 2D -------------------------------------------------------------------

func _setup_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	# Overlays de nodo (debajo de la barra y el panel en orden de dibujo).
	for p in CampaignData.PORTS:
		var ov := _build_node_overlay(p)
		ui.add_child(ov["root"])
		node_overlays[p.id] = ov

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Bajo el notch del móvil: la barra superior del mapa baja el área segura.
	vbox.offset_top = GameState.safe_top()
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(vbox)
	map_ui_root = vbox
	map_top_bar = _build_top_bar()
	vbox.add_child(map_top_bar)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(gap)
	map_info_panel = _build_info_panel()
	vbox.add_child(map_info_panel)


## Overlay 2D de un nodo: botón táctil transparente, estrellas conseguidas y
## cartel de madera con el número. Se reposiciona cada frame con la cámara.
func _build_node_overlay(port: Dictionary) -> Dictionary:
	var id: String = port.id
	var idx := CampaignData.port_index(id)
	var unlocked := GameState.is_port_unlocked(id)
	var best: int = int(GameState.level_stars.get(id, 0))

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var b := Button.new()
	b.custom_minimum_size = Vector2(170, 190)
	b.size = Vector2(170, 190)
	b.position = Vector2(-85, -108)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(_select.bind(id, true))
	root.add_child(b)

	var stars: HBoxContainer = PrepBoard.make_star_row(best, 3, 24, true)
	stars.position = Vector2(-42, -104)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stars)

	# Chapa REDONDA con el número: un doblón clavado en el mapa. El cartel
	# rectangular de madera competía con los botones del juego y se leía como
	# uno más en el que se podía pulsar.
	var sign := Control.new()
	sign.position = Vector2(-33, 42)
	sign.size = Vector2(66, 66)
	sign.pivot_offset = Vector2(33, 33)
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sign)

	var disc := Panel.new()
	disc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.30, 0.20, 0.10, 0.95) if unlocked \
			else Color(0.16, 0.17, 0.22, 0.9)
	sb.set_corner_radius_all(33)
	sb.set_border_width_all(5)
	sb.border_color = Color(0.98, 0.78, 0.28) if unlocked else Color(0.4, 0.42, 0.48)
	sb.shadow_size = 6
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_offset = Vector2(0, 3)
	disc.add_theme_stylebox_override("panel", sb)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.add_child(disc)

	var num := Label.new()
	num.text = "%d" % (idx + 1)
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", 34)
	num.add_theme_color_override("font_color",
		Color(1, 0.88, 0.42) if unlocked else Color(0.55, 0.57, 0.62))
	num.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.02))
	num.add_theme_constant_override("outline_size", 7)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.add_child(num)

	return { "root": root, "sign": sign, "unlocked": unlocked }


## Barra de arriba del MAPA. No es un HBox: el dinero y el arroz son los
## contadores del menú, que viajan hasta los extremos (main_menu), así que aquí
## solo van el rótulo —centrado en el hueco que dejan— y el botón de volver,
## DEBAJO del contador de la izquierda.
func _build_top_bar() -> Control:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 190)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := GameState.safe_top()

	# El rótulo va con ALTO FIJO y bajado unos píxeles. Antes se estiraba a todo
	# el alto de la barra: el gráfico de la cinta se pegaba al canto de arriba y
	# el texto, centrado en un rectángulo mucho más alto que el dibujo, quedaba
	# descolgado respecto a la tela.
	var title := PrepBoard.make_title("Aventura", 38)
	title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title.size = Vector2(TITLE_W, TITLE_H)
	# CENTRADO EN LA PANTALLA. Cabe porque la caja del arroz se estrechó para
	# dejarle sitio (main_menu.RES_RICE_W). Y 34 px de aire por arriba: se baja
	# el GRÁFICO entero, no el texto de dentro (ese va centrado en la tela).
	var ancho := GameState.canvas_size().x
	title.position = Vector2((ancho - TITLE_W) * 0.5, 104.0 + st)
	bar.add_child(title)

	# Flecha DIBUJADA en la madera: el único botón del juego con icono propio.
	var back := PrepBoard.make_back_button()
	back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back.size = Vector2(150, PrepBoard.ICON_BTN_H)
	# A la MISMA ALTURA que los contadores: en el mapa se corren a la derecha
	# (main_menu._resource_spots) justo para dejarle este hueco.
	back.position = Vector2(16.0, 16.0 + st)
	back.pressed.connect(_on_map_back)
	bar.add_child(back)
	return bar


## "Atrás" desde el mapa. En la escena fundida (main_menu.gd hereda de aquí)
## no se cambia de escena: el barco vuelve navegando a su fondeadero.
func _on_map_back() -> void:
	if has_method("_back_to_menu"):
		call("_back_to_menu")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")




func _build_info_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 470)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))

	var margin := MarginContainer.new()
	# Los rodillos y las esquinas del pergamino tapaban el texto por los cuatro
	# lados: hace falta más aire del que parece por el dibujo.
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 84)
	margin.add_theme_constant_override("margin_top", 58)
	margin.add_theme_constant_override("margin_bottom", 52)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)

	info_title = Label.new()
	info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_title.add_theme_font_size_override("font_size", 34)
	info_title.add_theme_color_override("font_color", Color(1, 0.82, 0.28))
	info_title.add_theme_color_override("font_outline_color", Color(0.28, 0.11, 0.03))
	info_title.add_theme_constant_override("outline_size", 12)
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		info_title.add_theme_font_override("font", negrita)
	vb.add_child(info_title)

	info_kind = Label.new()
	info_kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_kind.add_theme_font_size_override("font_size", 20)
	info_kind.add_theme_color_override("font_color", Color(0.55, 0.34, 0.08))
	vb.add_child(info_kind)

	info_stars_box = HBoxContainer.new()
	(info_stars_box as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(info_stars_box)

	info_desc = Label.new()
	info_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_desc.add_theme_font_size_override("font_size", 18)
	info_desc.add_theme_color_override("font_color", FADED)
	vb.add_child(info_desc)

	info_clients_row = _icon_row(vb, "Clientes")
	info_recipes_row = _icon_row(vb, "Recetas")
	info_time = _stat_label(vb)
	info_goal = _stat_label(vb)
	info_record = _stat_label(vb)
	info_reward_row = _icon_row(vb, "Recompensa")

	sail_button = Button.new()
	sail_button.custom_minimum_size = Vector2(350, 86)
	sail_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Placa de oro, igual que el de Arcade: es el botón que arranca la partida.
	PrepBoard.skin_start_button(sail_button)
	sail_button.add_theme_font_size_override("font_size", 42)
	sail_button.text = "¡Zarpar!"
	sail_button.pressed.connect(_on_sail_pressed)
	vb.add_child(sail_button)
	return panel


func _stat_label(parent: VBoxContainer) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", DARK)
	parent.add_child(l)
	return l


## Fila "rótulo + iconos" del panel de nivel. El rótulo va a la izquierda y los
## iconos se van añadiendo a la derecha.
func _icon_row(parent: VBoxContainer, titulo: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.set_meta("titulo", titulo)
	parent.add_child(row)
	return row


func _row_reset(row: HBoxContainer) -> void:
	for c in row.get_children():
		c.queue_free()
	var l := Label.new()
	l.text = "%s:" % str(row.get_meta("titulo", ""))
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", DARK)
	row.add_child(l)


## Icono cuadrado con un texto pequeño debajo-derecha ("x4", por ejemplo).
## `tachado` marca una recompensa YA CONSEGUIDA: se apaga el icono y se le
## cruza una raya, para que se vea de un vistazo que en este puerto ya no
## queda nada que rascar.
func _row_icon(row: HBoxContainer, tex: Texture2D, pie := "", lado := 44,
		tachado := false) -> void:
	if tex == null:
		return
	var caja := Control.new()
	caja.custom_minimum_size = Vector2(lado + (18 if pie != "" else 0), lado)
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = tex
	ic.size = Vector2(lado, lado)
	caja.add_child(ic)
	if pie != "":
		var l := Label.new()
		l.text = pie
		l.position = Vector2(lado - 2, lado * 0.42)
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", DARK)
		caja.add_child(l)
	if tachado:
		ic.modulate = Color(1, 1, 1, 0.42)
		var raya := ColorRect.new()
		raya.color = Color(0.62, 0.13, 0.06, 0.92)
		raya.size = Vector2(lado * 1.08, 5.0)
		raya.position = Vector2(-lado * 0.04, lado * 0.5 - 2.5)
		raya.pivot_offset = raya.size * 0.5
		raya.rotation_degrees = -18.0
		raya.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caja.add_child(raya)
	row.add_child(caja)


## Clientes del nivel: una cabeza por tipo con su "xN".
func _fill_clients_row(mix: Dictionary) -> void:
	_row_reset(info_clients_row)
	for t in ["E", "A", "G"]:
		var n := int(mix.get(t, 0))
		if n <= 0:
			continue
		var ruta := "res://assets/ui/head_%s.png" % t
		if ResourceLoader.exists(ruta):
			_row_icon(info_clients_row, load(ruta), "x%d" % n)


## Recetas que se pueden llevar. Los puertos y los abordajes son de LIBRE
## ELECCIÓN; las islas pueden traer una carta cerrada (`fixed_recipes`).
func _fill_recipes_row(port: Dictionary, id: String) -> void:
	_row_reset(info_recipes_row)
	# La carta cerrada, como el recorte de huecos, solo ata la PRIMERA vez: al
	# repetir un puerto superado se elige carta (ver prep_screen).
	var superado: bool = GameState.port_beaten(id)
	var fijas: Array = port.get("fixed_recipes", [])
	if fijas.is_empty() or superado:
		var l := Label.new()
		l.text = "Libre elección"
		l.add_theme_font_size_override("font_size", 19)
		l.add_theme_color_override("font_color", Color(0.55, 0.34, 0.08))
		info_recipes_row.add_child(l)
		var huecos := 4 if superado else int(port.get("recipe_slots", 4))
		if huecos != 4:
			var h := Label.new()
			h.text = "(solo %d)" % huecos
			h.add_theme_font_size_override("font_size", 18)
			h.add_theme_color_override("font_color", DARK)
			info_recipes_row.add_child(h)
		return
	for r in fijas:
		_row_icon(info_recipes_row, RecipeData.get_dish_texture(r), "", 40)


## Lo que se gana al superarlo: el plato de cada receta nueva.
## Recompensas EN GRÁFICO: una fila por escalón de estrellas, con las estrellas
## delante y los premios detrás. Lo ya conseguido sale tachado.
func _fill_reward_row(port: Dictionary, id: String) -> void:
	_row_reset(info_reward_row)
	var logradas: int = int(GameState.level_stars.get(id, 0))
	var meta := int(port.get("goal_stars", 2))

	# Escalón de la META (2★ normalmente).
	var base: Array = port.get("reward_recipes", [])
	var tienda := bool(port.get("unlocks_shop", false))
	if not base.is_empty() or tienda:
		info_reward_row.add_child(PrepBoard.make_star_row(meta, 3, 22, true))
		for r in base:
			_row_icon(info_reward_row, RecipeData.get_dish_texture(r), "", 40,
					logradas >= meta)
		if tienda:
			_row_icon(info_reward_row, load("res://assets/ui/ic_tienda.png"),
					"", 40, logradas >= meta)

	# Escalón de las TRES estrellas.
	var extra: Array = port.get("reward_recipes_3", [])
	var lingotes := int(port.get("reward_ingots_3", 0))
	var sacos := int(port.get("reward_rice_3", 0))
	if extra.is_empty() and lingotes <= 0 and sacos <= 0:
		return
	var hecho := logradas >= 3
	info_reward_row.add_child(PrepBoard.make_star_row(3, 3, 22, true))
	for r in extra:
		_row_icon(info_reward_row, RecipeData.get_dish_texture(r), "", 40, hecho)
	if lingotes > 0:
		_row_icon(info_reward_row, load("res://assets/ui/ic_lingote.png"),
				"x%d" % lingotes, 34, hecho)
	if sacos > 0:
		_row_icon(info_reward_row, load("res://assets/ui/ic_arroz.png"),
				"x%d" % sacos, 34, hecho)


func _reward_label(texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", Color(0.55, 0.34, 0.08))
	return l


## Filas del objetivo: una por escalón de estrellas, con las estrellas delante
## y la moneda con la cifra detrás.
func _fill_goal_rows(goal: int, goal_money: int, thresholds: Array) -> void:
	if goal_box == null:
		goal_box = VBoxContainer.new()
		goal_box.add_theme_constant_override("separation", 2)
		info_goal.get_parent().add_child(goal_box)
		info_goal.get_parent().move_child(goal_box, info_goal.get_index() + 1)
	for c in goal_box.get_children():
		c.queue_free()
	var escalones: Array = [[goal, goal_money]]
	if thresholds.size() >= 3 and goal < 3:
		escalones.append([3, int(thresholds[2])])
	# Se lee como una FRASE: "tantas monedas -> tantas estrellas". Por eso el
	# dinero va primero y la flecha (la misma del paso de diálogo) hace de
	# "te da".
	for e in escalones:
		var fila := HBoxContainer.new()
		fila.alignment = BoxContainer.ALIGNMENT_CENTER
		fila.add_theme_constant_override("separation", 8)
		fila.add_child(_money_chip(int(e[1])))
		var flecha := TextureRect.new()
		flecha.texture = load("res://assets/ui/ic_siguiente.png")
		flecha.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flecha.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		flecha.custom_minimum_size = Vector2(30, 26)
		fila.add_child(flecha)
		fila.add_child(PrepBoard.make_star_row(int(e[0]), 3, 26, true))
		goal_box.add_child(fila)


## Moneda + cifra, que es como se enseña el dinero en toda la ficha.
func _money_chip(cantidad: int, cuerpo := 24) -> HBoxContainer:
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 5)
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	var mon := TextureRect.new()
	mon.texture = load("res://assets/ui/moneda.png")
	mon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mon.custom_minimum_size = Vector2(cuerpo + 6, cuerpo + 6)
	caja.add_child(mon)
	var l := Label.new()
	l.text = str(cantidad)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", cuerpo)
	l.add_theme_color_override("font_color", DARK)
	caja.add_child(l)
	return caja


## El récord, con su moneda al lado en vez de "Récord: 61".
func _fill_record_row(rec: int) -> void:
	if record_box == null:
		record_box = HBoxContainer.new()
		record_box.alignment = BoxContainer.ALIGNMENT_CENTER
		record_box.add_theme_constant_override("separation", 8)
		info_record.get_parent().add_child(record_box)
		info_record.get_parent().move_child(record_box, info_record.get_index() + 1)
	info_record.visible = false
	for c in record_box.get_children():
		c.queue_free()
	var l := Label.new()
	l.text = "Récord:"
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", FADED)
	record_box.add_child(l)
	if rec > 0:
		record_box.add_child(_money_chip(rec, 22))
	else:
		var sin := Label.new()
		sin.text = "sin jugar"
		sin.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sin.add_theme_font_size_override("font_size", 20)
		sin.add_theme_color_override("font_color", FADED)
		record_box.add_child(sin)


## Vuelca en el panel el nombre del nivel y TODAS sus características.
func _update_info(id: String) -> void:
	var port := CampaignData.get_port(id)
	if port.is_empty():
		return
	var idx := CampaignData.port_index(id)
	var unlocked := GameState.is_port_unlocked(id)
	var best: int = int(GameState.level_stars.get(id, 0))

	# Solo el NOMBRE del puerto, estilizado: el "Nivel N" no aportaba nada que
	# no dijera ya el cartel del propio nodo en el mapa.
	info_title.text = str(port.get("name", id))
	info_kind.text = CampaignData.kind_name(id)
	# La frase descriptiva sobra: la ficha ya lo cuenta todo con sus iconos.
	# Solo queda el aviso de nivel bloqueado.
	info_desc.text = "" if unlocked \
		else "Bloqueado: supera el nivel anterior para navegar hasta aquí."
	info_desc.visible = not unlocked

	for c in info_stars_box.get_children():
		c.queue_free()
	info_stars_box.add_child(PrepBoard.make_star_row(best, 3, 30, true))

	var mix: Dictionary = port.get("client_mix", {})
	_fill_clients_row(mix)
	_fill_recipes_row(port, id)
	var t := int(port.get("time_limit", 150.0))
	info_time.text = "Tiempo: %d:%02d" % [t / 60, t % 60]
	var thresholds: Array = port.get("star_money", [])
	var goal := int(port.get("goal_stars", 1))
	var goal_money: int = int(thresholds[goal - 1]) if thresholds.size() >= goal else 0
	# El objetivo se enseña EN GRÁFICO (estrellas + moneda + cifra) en vez de
	# la línea "Objetivo: 2★ (30)", que se leía como una ficha técnica.
	info_goal.visible = false
	_fill_goal_rows(goal, goal_money, thresholds)
	var rec := GameState.get_level_score(id)
	_fill_record_row(rec)

	_fill_reward_row(port, id)

	sail_button.disabled = not unlocked
	sail_button.text = "¡Zarpar!" if unlocked else "Bloqueado"
	PrepBoard.set_dimmed(sail_button, sail_button.disabled)


# --- Selección, viaje y scroll ----------------------------------------------

## Punto donde se coloca el barco al llegar a un nivel: al costado del nodo,
## siempre hacia el centro del mapa (en px de mapa, como en 2D).
func _ship_anchor(id: String) -> Vector2:
	var p := CampaignData.map_pos(id)
	var side := -1.0 if p.x > 360.0 else 1.0
	return p + Vector2(side * 158.0, 72.0)


func _select(id: String, animate: bool) -> void:
	selected_id = id
	_update_info(id)
	var target := _ship_anchor(id)
	if ship_tween != null:
		ship_tween.kill()
		ship_tween = null
	if not animate or not GameState.is_port_unlocked(id):
		# Los niveles bloqueados solo muestran su ficha: el barco no viaja.
		if not animate:
			ship_px = target
		return
	# Viaje: la duración crece con la distancia, con un leve balanceo extra.
	var dist := ship_px.distance_to(target)
	var dur := clampf(dist / 420.0, 0.35, 1.4)
	ship_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ship_tween.tween_property(self, "ship_px", target, dur)
	ship_tween.parallel().tween_property(self, "ship_roll", 5.0, dur * 0.5)
	ship_tween.parallel().tween_property(self, "ship_roll", 0.0, dur * 0.5) \
		.set_delay(dur * 0.5)
	_scroll_to(CampaignData.map_pos(id))


func _scroll_to(point: Vector2) -> void:
	var target := clampf(point.y, SCROLL_MIN, SCROLL_MAX)
	if scroll_tween != null:
		scroll_tween.kill()
	scroll_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scroll_tween.tween_property(self, "cam_center", target, 0.5)


## Arrastre vertical sobre el mar = scroll del mapa (los botones de los nodos
## capturan sus propios toques).
func _unhandled_input(event: InputEvent) -> void:
	# En el menú principal (la escena hace de las dos cosas) no se recorre el
	# mapa: arrastrando se llegaba a ver los niveles antes de tiempo.
	if not map_visible:
		return
	if event is InputEventScreenDrag:
		if scroll_tween != null:
			scroll_tween.kill()
			scroll_tween = null
		cam_center = clampf(cam_center - event.relative.y, SCROLL_MIN, SCROLL_MAX)
		# Velocidad del dedo, suavizada, para que al soltar el mapa siga
		# corriendo: un tirón fuerte recorre más ruta que un arrastre suave.
		scroll_dragging = true
		var dt := maxf(get_process_delta_time(), 0.0001)
		scroll_speed = lerpf(scroll_speed, -event.relative.y / dt, DRAG_SMOOTH)
	elif event is InputEventScreenTouch:
		# Al posar el dedo se para la inercia; al levantarlo, corre sola.
		if event.pressed:
			scroll_speed = 0.0
		scroll_dragging = event.pressed


func _on_sail_pressed() -> void:
	if selected_id == "" or not GameState.is_port_unlocked(selected_id):
		return
	GameState.mode = "adventure"
	GameState.current_port = selected_id
	GameState.selected_recipes = []
	# Los puertos de CARTA CERRADA (las islas) no pasan por el selector: se
	# juega con las recetas que manda el nivel y punto. Eso vale la PRIMERA
	# vez; al repetir un puerto ya superado se elige carta como en el resto.
	var fijas: Array = CampaignData.get_port(selected_id).get("fixed_recipes", [])
	if not fijas.is_empty() and not GameState.port_beaten(selected_id):
		var recs: Array[String] = []
		for r in fijas:
			recs.append(str(r))
		GameState.selected_recipes = recs
		GameState.selected_perks = []
		GameState.fade_to_scene("res://scenes/level3d.tscn", 0.35, 0.45)
		return
	GameState.fade_to_scene("res://scenes/prep_screen.tscn", 0.35, 0.45)


# ------------------------------------------------------------------- bucle

func _process(delta: float) -> void:
	_t += delta
	# Inercia del arrastre del mapa: la velocidad que llevaba el dedo al soltar
	# se va apagando sola. Con el dedo apoyado no se aplica (manda el dedo)
	# pero TAMPOCO se borra: es la que da el impulso al levantarlo. Cualquier
	# viaje del barco (`scroll_tween`) manda sobre las dos cosas.
	if scroll_dragging:
		pass
	elif absf(scroll_speed) > SCROLL_STOP and scroll_tween == null:
		var target := clampf(cam_center + scroll_speed * delta,
			SCROLL_MIN, SCROLL_MAX)
		if is_equal_approx(target, cam_center):
			scroll_speed = 0.0  # tope del mapa: se para en seco
		else:
			cam_center = target
			scroll_speed *= pow(SCROLL_FRICTION, delta)
	else:
		scroll_speed = 0.0
	_update_camera()

	# Balanceo del barco sobre las olas (sustituye a las velas animadas del
	# spritesheet 2D) + el rolido extra del viaje.
	if ship_pivot != null:
		# El cabeceo sobre las olas es adorno: con "menos animaciones" el barco
		# navega quieto (el rolido del viaje sí se mantiene, guía la mirada).
		var bob := GameState.animations_on()
		ship_pivot.position = _world(ship_px) \
			+ Vector3(0.0, -0.06 + (sin(_t * 1.4) * 0.03 if bob else 0.0), 0.0)
		ship_pivot.rotation_degrees = Vector3(
			sin(_t * 1.1) * 2.0 if bob else 0.0, SHIP_YAW,
			(sin(_t * 1.7) * 2.5 if bob else 0.0) + ship_roll)
		# La mancha sigue al barco pero NO cabecea con él: es una sombra en el
		# agua, no una copia del casco.
		# Y APARTADA DE LA CÁMARA (-x, -z), por lo mismo: acercarla la ponía
		# por delante del propio barco en el test de profundidad.
		if ship_blob != null:
			ship_blob.position = _world(ship_px) + Vector3(-0.30, 0.04, -0.26)

	# Overlays 2D anclados a sus nodos 3D.
	if not map_visible:
		return
	for id in node_overlays:
		var scr := cam.unproject_position(node_world[id] + Vector3(0.0, 0.55, 0.0))
		node_overlays[id]["root"].position = scr
