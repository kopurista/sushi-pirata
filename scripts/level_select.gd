extends Control
## Aventura: MAPA MARÍTIMO. El barco del jugador navega por el mar entre los
## nodos de la campaña, que pueden ser islas, puertos o barcos que abordar
## (el tipo lo define CampaignData.KINDS; en el futuro cada tipo aportará una
## característica única al nivel).
##
## Cada nodo lleva un cartel de madera con el NÚMERO del nivel. Al tocarlo, el
## barco "viaja" navegando hasta él y abajo se despliega el nombre del nivel y
## todas sus características, con el botón para zarpar.

const PrepBoard := preload("res://scripts/prep_board.gd")
const DARK := Color(0.26, 0.16, 0.08)
const FADED := Color(0.42, 0.3, 0.18)

## Tamaño de cada nodo (sprite + cartel) y del barco del jugador. El barco se
## dibuja en un marco mayor porque el sprite ocupa solo el centro del fotograma.
const NODE_SIZE := Vector2(184, 240)
const SPRITE_H := 150.0
const SHIP_SIZE := Vector2(205, 205)

## Spritesheet del barco con las velas empujadas por el viento (rejilla 4x4 =
## 16 fotogramas, generado con Ludo). El tamaño de fotograma se deduce de la
## textura, así no hay que tocar nada si se regenera con otra resolución.
const SHIP_SHEET_COLS := 4
const SHIP_SHEET_ROWS := 4
const SHIP_FRAMES := 16
const SHIP_FPS := 11.0

var scroll: ScrollContainer = null
var map_canvas: Control = null
var ship: TextureRect = null
var ship_tween: Tween = null
var selected_id: String = ""
## Fotogramas recortados del spritesheet y avance de la animación.
var ship_textures: Array = []
var ship_frame := 0.0

# --- Widgets del panel de información ---
var info_title: Label = null
var info_kind: Label = null
var info_desc: Label = null
var info_clients: Label = null
var info_time: Label = null
var info_goal: Label = null
var info_record: Label = null
var info_stars_box: Control = null
var info_reward: Label = null
var sail_button: Button = null


## Línea de ruta discontinua que une los nodos, como una carta de navegación.
class RouteLine extends Control:
	var points: PackedVector2Array = PackedVector2Array()
	func _draw() -> void:
		for i in range(points.size() - 1):
			_dashed(points[i], points[i + 1])
	func _dashed(a: Vector2, b: Vector2) -> void:
		var delta := b - a
		var total := delta.length()
		if total <= 0.0:
			return
		var dir := delta / total
		var t := 0.0
		while t < total:
			var e := minf(t + 18.0, total)
			draw_line(a + dir * t, a + dir * e, Color(1, 1, 1, 0.32), 6.0)
			t = e + 14.0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.12, 0.22)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	vbox.add_child(_build_top_bar())

	# El mapa se desplaza verticalmente entre la barra y el panel de datos.
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	map_canvas = Control.new()
	map_canvas.custom_minimum_size = Vector2(0, CampaignData.MAP_HEIGHT)
	map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(map_canvas)
	_build_map()

	vbox.add_child(_build_info_panel())

	# Arranca en el nivel más avanzado que el jugador tiene disponible.
	var start_id := CampaignData.first_port_id()
	for p in CampaignData.PORTS:
		if GameState.is_port_unlocked(p.id):
			start_id = p.id
	_select(start_id, false)
	# El mapa se abre centrado en ese nivel (abajo del todo si acabas de empezar).
	_center_now.call_deferred(start_id)


## Centra el mapa en un nivel al instante (sin animar), ya con el layout hecho.
func _center_now(id: String) -> void:
	await get_tree().process_frame
	var view_h := scroll.size.y
	scroll.scroll_vertical = int(clampf(
			CampaignData.map_pos(id).y - view_h / 2.0,
			0.0, maxf(CampaignData.MAP_HEIGHT - view_h, 0.0)))


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


# --- Mapa ------------------------------------------------------------------

func _build_map() -> void:
	# Mar de fondo ANIMADO: el shader repite la textura voxel por todo el lienzo
	# y la hace derivar y ondular continuamente (movimiento lento y suave).
	var sea := TextureRect.new()
	var sea_tex: Texture2D = load("res://assets/map/mar.png")
	sea.texture = sea_tex
	sea.stretch_mode = TextureRect.STRETCH_SCALE
	sea.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sea.set_anchors_preset(Control.PRESET_FULL_RECT)
	sea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Se oscurece un poco para que la retícula del mosaico no compita con los
	# nodos y el mar lea como agua profunda.
	sea.modulate = Color(0.72, 0.82, 0.98)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water_map.gdshader")
	# El tileado sale del tamaño real de la textura: así se ve a escala 1:1
	# aunque se regenere el gráfico del mar con otra resolución.
	mat.set_shader_parameter("tile_scale", Vector2(
			720.0 / float(sea_tex.get_width()),
			float(CampaignData.MAP_HEIGHT) / float(sea_tex.get_height())))
	sea.material = mat
	map_canvas.add_child(sea)

	# Ruta discontinua entre niveles consecutivos.
	var route := RouteLine.new()
	route.set_anchors_preset(Control.PRESET_FULL_RECT)
	route.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for p in CampaignData.PORTS:
		route.points.append(CampaignData.map_pos(p.id))
	map_canvas.add_child(route)

	for p in CampaignData.PORTS:
		map_canvas.add_child(_build_node(p))

	# El barco del jugador va por encima de todo, con las velas ondeando.
	var sheet: Texture2D = load("res://assets/map/barco_anim.webp")
	var fw := float(sheet.get_width()) / float(SHIP_SHEET_COLS)
	var fh := float(sheet.get_height()) / float(SHIP_SHEET_ROWS)
	ship_textures.clear()
	for i in SHIP_FRAMES:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2((i % SHIP_SHEET_COLS) * fw, (i / SHIP_SHEET_COLS) * fh, fw, fh)
		ship_textures.append(at)
	ship = TextureRect.new()
	ship.texture = ship_textures[0]
	ship.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ship.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ship.size = SHIP_SIZE
	ship.pivot_offset = SHIP_SIZE / 2.0
	ship.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_canvas.add_child(ship)


## Pasa los fotogramas del barco (velas al viento) en PING-PONG: va del primero
## al último y vuelve. Así el ciclo es continuo por construcción y nunca hay el
## salto brusco que se veía al reiniciar el bucle (sobre todo en la sombra).
func _process(delta: float) -> void:
	if ship == null or ship_textures.is_empty():
		return
	var cycle := float(SHIP_FRAMES * 2 - 2)
	ship_frame = fmod(ship_frame + delta * SHIP_FPS, cycle)
	var idx := int(ship_frame)
	if idx >= SHIP_FRAMES:
		idx = SHIP_FRAMES * 2 - 2 - idx
	ship.texture = ship_textures[idx]


## Nodo del mapa: estrellas conseguidas, sprite del tipo (isla/puerto/barco)
## y cartel de madera con el número del nivel.
func _build_node(port: Dictionary) -> Control:
	var id: String = port.id
	var idx := CampaignData.port_index(id)
	var unlocked := GameState.is_port_unlocked(id)
	var best: int = int(GameState.level_stars.get(id, 0))

	var b := Button.new()
	b.name = "node_%s" % id
	b.custom_minimum_size = NODE_SIZE
	b.size = NODE_SIZE
	b.position = CampaignData.map_pos(id) - NODE_SIZE / 2.0
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())

	# Estrellas ya conseguidas, arriba del todo.
	var stars: HBoxContainer = PrepBoard.make_star_row(best, 3, 24, true)
	stars.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stars.offset_top = 0.0
	stars.offset_bottom = 26.0
	b.add_child(stars)

	# Sprite isométrico del tipo de nivel.
	var ic := TextureRect.new()
	ic.texture = load(CampaignData.kind_texture(id))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_top = 28.0
	ic.offset_bottom = -(NODE_SIZE.y - 28.0 - SPRITE_H)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked:
		ic.modulate = Color(0.45, 0.5, 0.6, 0.85)
	b.add_child(ic)

	# Cartel de madera con el número del nivel.
	var sign := Control.new()
	sign.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sign.offset_left = 42.0
	sign.offset_top = -50.0
	sign.offset_right = -42.0
	sign.offset_bottom = -2.0
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.add_child(PrepBoard.make_nine_patch("res://assets/ui/boton.png", 26))
	var num := Label.new()
	num.text = "%d" % (idx + 1)
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", 28)
	num.add_theme_color_override("font_color", Color(1, 0.94, 0.82) if unlocked else Color(0.62, 0.58, 0.52))
	num.add_theme_color_override("font_outline_color", Color.BLACK)
	num.add_theme_constant_override("outline_size", 5)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.add_child(num)
	b.add_child(sign)

	b.pressed.connect(_select.bind(id, true))
	return b


## Punto donde se coloca el barco al llegar a un nivel: al costado del nodo,
## siempre hacia el centro del mapa para que no se salga por los bordes.
func _ship_anchor(id: String) -> Vector2:
	var p := CampaignData.map_pos(id)
	var side := -1.0 if p.x > 360.0 else 1.0
	return p + Vector2(side * 118.0, 46.0) - SHIP_SIZE / 2.0


# --- Selección y viaje del barco -------------------------------------------

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
			ship.position = target
		return
	# Viaje: la duración crece con la distancia, con un leve balanceo.
	var dist := ship.position.distance_to(target)
	var dur := clampf(dist / 420.0, 0.35, 1.4)
	ship_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ship_tween.tween_property(ship, "position", target, dur)
	ship_tween.parallel().tween_property(ship, "rotation_degrees", 5.0, dur * 0.5)
	ship_tween.parallel().tween_property(ship, "rotation_degrees", 0.0, dur * 0.5).set_delay(dur * 0.5)
	_scroll_to(CampaignData.map_pos(id))


## Centra el mapa en un punto (sin pasarse de los extremos).
func _scroll_to(point: Vector2) -> void:
	var view_h := scroll.size.y
	var target := clampf(point.y - view_h / 2.0, 0.0, maxf(CampaignData.MAP_HEIGHT - view_h, 0.0))
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(scroll, "scroll_vertical", int(target), 0.5)


# --- Panel de información --------------------------------------------------

func _build_info_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 356)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))

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
	info_desc.text = port.get("desc", "") if unlocked else "Bloqueado: supera el nivel anterior para navegar hasta aquí."

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


func _on_sail_pressed() -> void:
	if selected_id == "" or not GameState.is_port_unlocked(selected_id):
		return
	GameState.mode = "adventure"
	GameState.current_port = selected_id
	GameState.selected_recipes = []
	get_tree().change_scene_to_file("res://scenes/prep_screen.tscn")
