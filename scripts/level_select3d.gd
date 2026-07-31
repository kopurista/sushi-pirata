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
const SCROLL_MAX := CampaignData.MAP_HEIGHT - 424.0

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
var selected_id: String = ""
## Centro de la franja visible, en px de mapa (el equivalente del scroll 2D).
var cam_center := SCROLL_MAX
var scroll_tween: Tween = null
## Posición del barco en px de mapa; un tween la anima al viajar.
var ship_px := Vector2(360, 1560)
var ship_pivot: Node3D
var ship_tween: Tween = null
var ship_roll := 0.0
var _t := 0.0
var _shots_at := []
var _shot_idx := 0

## Overlays 2D por nodo: { id: {root, unlocked} } reposicionados por frame.
var node_overlays: Dictionary = {}
var node_world: Dictionary = {}

# --- Widgets del panel de información (idénticos al 2D) ---
var info_title: Label
var info_kind: Label
var info_desc: Label
var info_clients: Label
var info_time: Label
var info_goal: Label
var info_record: Label
var info_stars_box: Control
var info_reward: Label
var sail_button: Button


## Px de mapa (lienzo 2D de CampaignData) -> punto del mundo en el plano del mar.
func _world(p: Vector2) -> Vector3:
	return R_HAT * ((p.x - 360.0) / PPU_X) + D_HAT * (p.y / PPU_Y)


func _ready() -> void:
	_setup_environment()
	_setup_sea()
	_setup_route()
	_setup_nodes()
	_setup_ship()
	_setup_camera()
	_setup_ui()

	# Arranca en el nivel más avanzado disponible.
	var start_id := CampaignData.first_port_id()
	for p in CampaignData.PORTS:
		if GameState.is_port_unlocked(p.id):
			start_id = p.id
	ship_px = _ship_anchor(start_id)
	cam_center = clampf(CampaignData.map_pos(start_id).y, SCROLL_MIN, SCROLL_MAX)
	_update_camera()
	_select(start_id, false)


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
	sun.shadow_enabled = true
	add_child(sun)


## Mar: plano enorme con el shader de agua (deriva + senos cruzados), tileado
## a la misma escala 1:1 que en el 2D (el tamaño del tile sale de la textura).
func _setup_sea() -> void:
	var tex: Texture2D = load("res://assets/map/mar.png")
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(46.0, 46.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = D_HAT * (CampaignData.MAP_HEIGHT * 0.5 / PPU_Y)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water_map_3d.gdshader")
	mat.set_shader_parameter("sea_tex", tex)
	# Tiles algo mayores que en 2D; el shader ademas aplana el mosaico contra
	# un azul profundo (a pelo, el enrejado de rombos leia como una manta).
	var tile_u := float(tex.get_width()) / PPU_X * 1.25
	mat.set_shader_parameter("tile_scale", Vector2(46.0 / tile_u, 46.0 / tile_u))
	mat.set_shader_parameter("tint", Vector3(0.55, 0.68, 0.9))
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
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(vbox)
	vbox.add_child(_build_top_bar())
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(gap)
	vbox.add_child(_build_info_panel())


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

	var sign := Control.new()
	sign.position = Vector2(-50, 44)
	sign.size = Vector2(100, 48)
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.add_child(PrepBoard.make_nine_patch("res://assets/ui/boton.png", 26))
	var num := Label.new()
	num.text = "%d" % (idx + 1)
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", 28)
	num.add_theme_color_override("font_color",
		Color(1, 0.94, 0.82) if unlocked else Color(0.62, 0.58, 0.52))
	num.add_theme_color_override("font_outline_color", Color.BLACK)
	num.add_theme_constant_override("outline_size", 5)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.add_child(num)
	root.add_child(sign)

	return { "root": root }


func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 76)
	bar.add_theme_constant_override("separation", 10)
	var pad_l := Control.new()
	pad_l.custom_minimum_size = Vector2(16, 0)
	bar.add_child(pad_l)
	var back := Button.new()
	back.text = "Menú"
	back.custom_minimum_size = Vector2(130, 52)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	PrepBoard.skin_button(back)
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	bar.add_child(back)
	var title := Label.new()
	title.text = "La travesía"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.82))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03))
	title.add_theme_constant_override("outline_size", 7)
	bar.add_child(title)
	bar.add_child(_make_money_label())
	var pad_r := Control.new()
	pad_r.custom_minimum_size = Vector2(16, 0)
	bar.add_child(pad_r)
	return bar


func _make_money_label() -> Control:
	var box := HBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 6)
	var coin := TextureRect.new()
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture = load("res://assets/ui/moneda.png")
	coin.custom_minimum_size = Vector2(34, 34)
	box.add_child(coin)
	var l := Label.new()
	l.text = "%d" % GameState.money
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(1, 0.86, 0.4))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	box.add_child(l)
	return box


func _build_info_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 356)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.add_child(PrepBoard.make_nine_patch("res://assets/ui/panel.png", 38))

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 62)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 34)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)

	info_title = Label.new()
	info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_title.add_theme_font_size_override("font_size", 28)
	info_title.add_theme_color_override("font_color", DARK)
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

	info_clients = _stat_label(vb)
	info_time = _stat_label(vb)
	info_goal = _stat_label(vb)
	info_record = _stat_label(vb)
	info_reward = _stat_label(vb)

	sail_button = Button.new()
	sail_button.custom_minimum_size = Vector2(300, 72)
	sail_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	PrepBoard.skin_button(sail_button)
	sail_button.add_theme_font_size_override("font_size", 30)
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


## Vuelca en el panel el nombre del nivel y TODAS sus características.
func _update_info(id: String) -> void:
	var port := CampaignData.get_port(id)
	if port.is_empty():
		return
	var idx := CampaignData.port_index(id)
	var unlocked := GameState.is_port_unlocked(id)
	var best: int = int(GameState.level_stars.get(id, 0))

	info_title.text = "Nivel %d — %s" % [idx + 1, port.get("name", id)]
	info_kind.text = CampaignData.kind_name(id)
	info_desc.text = port.get("desc", "") if unlocked \
		else "Bloqueado: supera el nivel anterior para navegar hasta aquí."

	for c in info_stars_box.get_children():
		c.queue_free()
	info_stars_box.add_child(PrepBoard.make_star_row(best, 3, 30, true))

	var mix: Dictionary = port.get("client_mix", {})
	info_clients.text = "Clientes: %d   (%s)" % [_mix_total(mix), _mix_text(mix)]
	var t := int(port.get("time_limit", 150.0))
	info_time.text = "Tiempo: %d:%02d" % [t / 60, t % 60]
	var thresholds: Array = port.get("star_money", [])
	var goal := int(port.get("goal_stars", 1))
	var goal_money: int = int(thresholds[goal - 1]) if thresholds.size() >= goal else 0
	info_goal.text = "Objetivo: %d estrellas  ($%d)" % [goal, goal_money]
	var rec := GameState.get_level_score(id)
	info_record.text = "Récord: $%d" % rec if rec > 0 else "Récord: sin jugar"

	var rewards: Array = port.get("reward_recipes", [])
	if rewards.is_empty():
		info_reward.text = ""
		info_reward.visible = false
	else:
		var names: Array[String] = []
		for r in rewards:
			names.append(RecipeData.get_recipe(r).get("name", r))
		info_reward.text = "Recompensa: %s" % ", ".join(names)
		info_reward.visible = true

	sail_button.disabled = not unlocked
	sail_button.text = "¡Zarpar!" if unlocked else "Bloqueado"


func _mix_total(mix: Dictionary) -> int:
	var n := 0
	for k in mix:
		n += int(mix[k])
	return n


func _mix_text(mix: Dictionary) -> String:
	var parts: Array[String] = []
	var names := { "E": "grumetes", "A": "piratas", "G": "capitanes" }
	for k in ["E", "A", "G"]:
		if int(mix.get(k, 0)) > 0:
			parts.append("%d %s" % [int(mix[k]), names[k]])
	return " · ".join(parts)


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
	if event is InputEventScreenDrag:
		if scroll_tween != null:
			scroll_tween.kill()
			scroll_tween = null
		cam_center = clampf(cam_center - event.relative.y, SCROLL_MIN, SCROLL_MAX)


func _on_sail_pressed() -> void:
	if selected_id == "" or not GameState.is_port_unlocked(selected_id):
		return
	GameState.mode = "adventure"
	GameState.current_port = selected_id
	GameState.selected_recipes = []
	get_tree().change_scene_to_file("res://scenes/prep_screen.tscn")


# ------------------------------------------------------------------- bucle

func _process(delta: float) -> void:
	_t += delta
	_update_camera()

	# Balanceo del barco sobre las olas (sustituye a las velas animadas del
	# spritesheet 2D) + el rolido extra del viaje.
	if ship_pivot != null:
		ship_pivot.position = _world(ship_px) \
			+ Vector3(0.0, -0.06 + sin(_t * 1.4) * 0.03, 0.0)
		ship_pivot.rotation_degrees = Vector3(
			sin(_t * 1.1) * 2.0, SHIP_YAW, sin(_t * 1.7) * 2.5 + ship_roll)

	# Overlays 2D anclados a sus nodos 3D.
	for id in node_overlays:
		var scr := cam.unproject_position(node_world[id] + Vector3(0.0, 0.55, 0.0))
		node_overlays[id]["root"].position = scr

	if _shot_idx < _shots_at.size() and _t >= _shots_at[_shot_idx]:
		get_viewport().get_texture().get_image().save_png(
			"res://map3d_shot_%d.png" % _shot_idx)
		_shot_idx += 1
		print("SHOT %d OK" % _shot_idx)
		if _shot_idx == _shots_at.size():
			get_tree().quit()
