extends Node3D
## Fase de preparación: elegir 4 recetas de todas las disponibles.
## El fondo es el ESCENARIO 3D del nivel elegido (isla, puerto o barco
## enemigo) meciéndose sobre el mar; la selección va en un CanvasLayer 2D.
## Las recetas se agrupan por nivel de estrellas (progresión de descubrimiento),
## con 4 tarjetas compactas por fila. TODAS comparten un único pergamino largo:
## el pergamino forma parte del contenido scrolleable (no es un fondo fijo), con
## la altura de todo el contenido, así al desplazarse el borde superior se pierde
## y el inferior aparece, dando la sensación de recorrer un pergamino entero.

const MAX_RECIPES := 4
const DARK := Color(0.26, 0.16, 0.08)
const CARDS_PER_ROW := 4
## Grosor del marco de cuerda del pergamino: hueco que se deja alrededor del
## contenido para que nada (estrellas, platos ni nombres) se salga del interior
## utilizable del pergamino. El inferior es mayor para que los nombres de dos
## líneas nunca queden por encima de la cuerda de abajo.
const FRAME_SIDE := 52.0
const FRAME_TOP := 44.0
const FRAME_BOTTOM := 54.0

var selected: Array[String] = []
## Potenciadores permanentes marcados para esta travesía.
var perks_selected: Array[String] = []
## Pivote del modelo 3D del fondo (se mece con el oleaje).
var backdrop: Node3D = null
var _t := 0.0

@onready var content: Control = $UI/Root/Margin/VBox/Scroll/Content
@onready var sections: VBoxContainer = $UI/Root/Margin/VBox/Scroll/Content/Sections
@onready var count_label: Label = $UI/Root/Margin/VBox/CountLabel
@onready var start_button: Button = $UI/Root/Margin/VBox/StartButton


## Tope de fotogramas: aquí aún no se juega, 30 bastan y ahorran batería.
const MENU_FPS := 30


func _ready() -> void:
	Engine.max_fps = MENU_FPS
	var board_script := load("res://scripts/prep_board.gd")
	var kind := CampaignData.get_kind(GameState.current_port) \
			if GameState.is_adventure() else ""
	backdrop = SceneBackdrop.build(self, kind)
	_add_shared_parchment()
	# En aventura solo se listan las recetas desbloqueadas; en prueba, todas.
	var available: Array = []
	for id in RecipeData.RECIPES:
		if GameState.mode == "test" or GameState.is_recipe_unlocked(id):
			available.append(id)
	# Agrupadas por nivel (1★, 2★, 3★); dentro de cada grupo, por precio.
	var by_level: Dictionary = {}
	for id in available:
		var lv: int = int(RecipeData.RECIPES[id].get("level", 1))
		by_level.get_or_add(lv, []).append(id)
	for lv in [1, 2, 3]:
		if not by_level.has(lv):
			continue
		var ids: Array = by_level[lv]
		ids.sort_custom(func(a: String, b: String) -> bool:
			return RecipeData.RECIPES[a].price < RecipeData.RECIPES[b].price)
		sections.add_child(_build_section_header(board_script, lv))
		var grid := GridContainer.new()
		grid.columns = CARDS_PER_ROW
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 14)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for id in ids:
			grid.add_child(_build_card(id, board_script))
		sections.add_child(grid)
	_add_top_bar(board_script)
	_add_perk_bar(board_script)
	_skin_start_button(board_script)
	start_button.pressed.connect(_on_start_pressed)
	# El pergamino debe crecer con el contenido; se reajusta cada vez que la
	# lista cambia de tamaño (envoltura de nombres, etc.).
	sections.resized.connect(_update_content_size)
	call_deferred("_update_content_size")
	_update_ui()


## Barra superior: botón de volver a la pantalla anterior y, en aventura, el
## nombre del nivel.
func _add_top_bar(board_script: GDScript) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	var back := Button.new()
	back.text = "Atrás"
	back.custom_minimum_size = Vector2(150, 62)
	board_script.skin_button(back)
	back.add_theme_font_size_override("font_size", 26)
	# La pantalla anterior es el mapa en aventura y el menú en Arcade.
	var prev := "res://scenes/level_select3d.tscn" if GameState.is_adventure() \
			else "res://scenes/main_menu.tscn"
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(prev))
	bar.add_child(back)
	if GameState.is_adventure():
		var port := CampaignData.get_port(GameState.current_port)
		var title := Label.new()
		title.text = port.get("name", "")
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 28)
		title.add_theme_color_override("font_color", Color(1, 0.95, 0.82))
		title.add_theme_color_override("font_outline_color", Color(0.2, 0.12, 0.05))
		title.add_theme_constant_override("outline_size", 6)
		bar.add_child(title)
		# Hueco simétrico al botón para que el título quede centrado.
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(150, 0)
		bar.add_child(spacer)
	var vbox: VBoxContainer = $UI/Root/Margin/VBox
	vbox.add_child(bar)
	vbox.move_child(bar, 0)


## Potenciadores permanentes disponibles para esta travesía: se eligen a la vez
## que las recetas y gastan 1 uso al zarpar. Solo en aventura (el modo Arcade
## no toca el progreso).
func _add_perk_bar(board_script: GDScript) -> void:
	if not GameState.is_adventure():
		return
	var ids: Array = []
	for id in PerkData.ids():
		if GameState.is_perk_unlocked(id) and GameState.get_perk_uses(id) > 0:
			ids.append(id)
	if ids.is_empty():
		return

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "Potenciadores"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 7)
	box.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for id in ids:
		row.add_child(_build_perk_card(id, board_script))

	var vbox: VBoxContainer = $UI/Root/Margin/VBox
	vbox.add_child(box)
	vbox.move_child(box, vbox.get_child_count() - 2)


func _build_perk_card(id: String, board_script: GDScript) -> Button:
	var data := PerkData.get_perk(id)
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(210, 78)
	b.tooltip_text = str(data.get("desc", ""))
	board_script.skin_button(b)

	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(str(data.get("icon", "")))
	icon.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	icon.offset_left = 16.0
	icon.offset_right = 62.0
	icon.offset_top = 12.0
	icon.offset_bottom = -12.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)

	var name_l := Label.new()
	name_l.text = "%s\nx%d" % [data.get("name", id), GameState.get_perk_uses(id)]
	name_l.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_l.offset_left = 66.0
	name_l.offset_right = -10.0
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 17)
	name_l.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	name_l.add_theme_color_override("font_outline_color", Color(0.13, 0.07, 0.02))
	name_l.add_theme_constant_override("outline_size", 6)
	name_l.add_theme_constant_override("line_spacing", -2)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name_l)

	# Marco verde cuando está activado.
	var hl := Panel.new()
	hl.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.9, 0.35, 0.16)
	sb.set_border_width_all(4)
	sb.border_color = Color(0.4, 1.0, 0.45)
	sb.set_corner_radius_all(10)
	hl.add_theme_stylebox_override("panel", sb)
	hl.visible = false
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hl)

	b.toggled.connect(func(on: bool) -> void:
		hl.visible = on
		if on:
			if not id in perks_selected:
				perks_selected.append(id)
		else:
			perks_selected.erase(id))
	return b


## El escenario del fondo se mece con el oleaje.
func _process(delta: float) -> void:
	_t += delta
	if backdrop != null:
		backdrop.rotation_degrees.y = sin(_t * 0.18) * 6.0
		backdrop.rotation_degrees.z = sin(_t * 0.7) * 1.4
		backdrop.position.y = -0.1 + sin(_t * 0.9) * 0.07


## Pergamino único y alargado (mismo estilo que el panel de fin de nivel) que
## enmarca TODAS las recetas. Va DENTRO del contenido scrolleable, con la altura
## total del contenido: el marco superior/inferior solo se ve en los extremos y
## el centro se estira, así al desplazarse se recorre todo el pergamino.
func _add_shared_parchment() -> void:
	var parch := NinePatchRect.new()
	parch.name = "Parchment"
	parch.texture = load("res://assets/ui/panel.png")
	parch.patch_margin_left = 40
	parch.patch_margin_top = 40
	parch.patch_margin_right = 40
	parch.patch_margin_bottom = 40
	parch.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Tinte cálido leve para un aire de pergamino viejo y desgastado.
	parch.modulate = Color(0.97, 0.93, 0.85)
	parch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(parch)
	content.move_child(parch, 0)


## Ajusta la altura del contenido (y por tanto del pergamino) a la de la lista
## de recetas más el marco de cuerda arriba y abajo.
func _update_content_size() -> void:
	var h := sections.get_combined_minimum_size().y
	content.custom_minimum_size = Vector2(0, h + FRAME_TOP + FRAME_BOTTOM)


## Cabecera de sección: fila de estrellas que separa cada nivel de dificultad.
func _build_section_header(board_script: GDScript, level: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var stars: HBoxContainer = board_script.make_star_row(level, level, 26)
	stars.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(stars)
	return row


## Botón de zarpar con el mismo tablón de madera y marco dorado del resto del
## juego, en grande.
func _skin_start_button(board_script: GDScript) -> void:
	board_script.skin_button(start_button)
	start_button.add_theme_font_size_override("font_size", 36)


func _build_card(id: String, board_script: GDScript) -> Button:
	var data: Dictionary = RecipeData.RECIPES[id]
	var b := Button.new()
	b.name = id
	b.toggle_mode = true
	# Tarjetas compactas (4 por fila) SIN fondo propio: todas comparten el mismo
	# pergamino de detrás. Solo llevan el plato, el nombre y las insignias.
	# Estrechas a propósito para caber dentro del interior del pergamino.
	b.custom_minimum_size = Vector2(118, 168)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())

	# Resalte de selección: marco dorado tenue, oculto por defecto.
	var hl := Panel.new()
	hl.name = "Highlight"
	hl.set_anchors_preset(Control.PRESET_FULL_RECT)
	hl.offset_left = 3.0
	hl.offset_top = 3.0
	hl.offset_right = -3.0
	hl.offset_bottom = -3.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.85, 0.35, 0.14)
	sb.set_border_width_all(3)
	sb.border_color = Color(1.0, 0.82, 0.28)
	sb.set_corner_radius_all(12)
	hl.add_theme_stylebox_override("panel", sb)
	hl.visible = false
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hl)

	# El plato, grande y centrado, sobre el pergamino compartido.
	var tex := RecipeData.get_dish_texture(id)
	if tex != null:
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = tex
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		# Plato algo más pequeño y bajado: más cerca del nombre y dejando arriba
		# aire limpio para la moneda y la hoja.
		ic.offset_left = 20.0
		ic.offset_top = 32.0
		ic.offset_right = -20.0
		ic.offset_bottom = -48.0
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)

	# Nombre en letra grande y oscura directamente sobre el pergamino
	# (legible, aunque ocupe dos líneas).
	var nl := Label.new()
	nl.text = data.name
	nl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	nl.offset_left = 3.0
	nl.offset_top = -46.0
	nl.offset_right = -3.0
	nl.offset_bottom = -4.0
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.add_theme_font_size_override("font_size", 18)
	nl.add_theme_color_override("font_color", DARK)
	nl.add_theme_color_override("font_outline_color", Color(1, 0.97, 0.86))
	nl.add_theme_constant_override("outline_size", 4)
	nl.add_theme_constant_override("line_spacing", -3)
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(nl)

	# Insignia de precio (moneda + cantidad) arriba-izquierda; la hoja
	# vegetariana se añade al lado si aplica.
	var price_box := HBoxContainer.new()
	price_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	price_box.offset_left = 5.0
	price_box.offset_top = 3.0
	price_box.offset_right = 116.0
	price_box.offset_bottom = 34.0
	price_box.add_theme_constant_override("separation", 4)
	price_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := TextureRect.new()
	coin.texture = load("res://assets/ui/moneda.png")
	coin.custom_minimum_size = Vector2(30, 30)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_box.add_child(coin)
	var pl := Label.new()
	pl.text = "%d" % data.price
	pl.add_theme_font_size_override("font_size", 23)
	pl.add_theme_color_override("font_color", Color(0.4, 0.26, 0.02))
	pl.add_theme_color_override("font_outline_color", Color(1, 0.97, 0.88))
	pl.add_theme_constant_override("outline_size", 5)
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_box.add_child(pl)
	if data.get("vegetarian", false):
		var leaf := TextureRect.new()
		leaf.texture = load("res://assets/ui/hoja.png")
		leaf.custom_minimum_size = Vector2(24, 24)
		leaf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		leaf.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		leaf.tooltip_text = "Vegetariano"
		leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price_box.add_child(leaf)
	b.add_child(price_box)

	# Check verde de selección (esquina superior derecha).
	var check := TextureRect.new()
	check.name = "Check"
	check.visible = false
	check.texture = load("res://assets/ui/check.png") if ResourceLoader.exists("res://assets/ui/check.png") else null
	check.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	check.offset_left = -40.0
	check.offset_top = 3.0
	check.offset_right = -5.0
	check.offset_bottom = 38.0
	check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(check)

	# En aventura, sin usos de algún ingrediente la receta no puede llevarse:
	# tarjeta apagada y aviso para pasar por la tienda.
	if GameState.is_adventure() and not GameState.has_ingredients_for(id):
		b.disabled = true
		b.modulate = Color(1, 1, 1, 0.45)
		var warn := Label.new()
		warn.text = "Sin ingredientes"
		warn.set_anchors_preset(Control.PRESET_CENTER)
		warn.offset_left = -55.0
		warn.offset_right = 55.0
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warn.add_theme_font_size_override("font_size", 16)
		warn.add_theme_color_override("font_color", Color(0.75, 0.15, 0.1))
		warn.add_theme_color_override("font_outline_color", Color(1, 0.97, 0.88))
		warn.add_theme_constant_override("outline_size", 5)
		warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(warn)
		return b

	b.toggled.connect(_on_recipe_toggled.bind(id, b))
	return b


func _on_recipe_toggled(pressed: bool, id: String, button: Button) -> void:
	if pressed:
		if selected.size() >= MAX_RECIPES:
			button.set_pressed_no_signal(false)
			return
		selected.append(id)
	else:
		selected.erase(id)
	button.get_node("Check").visible = button.button_pressed
	# La receta elegida se enmarca con el resalte dorado.
	button.get_node("Highlight").visible = button.button_pressed
	_update_ui()


func _update_ui() -> void:
	count_label.text = "%d/%d elegidas" % [selected.size(), MAX_RECIPES]
	# Basta con 1 receta: en los primeros niveles no hay 4 disponibles.
	start_button.disabled = selected.is_empty()


func _on_start_pressed() -> void:
	GameState.selected_recipes = selected.duplicate()
	GameState.selected_perks = perks_selected.duplicate()
	# Nivel 3D low poly (el level.tscn 2D queda como referencia hasta acabar
	# la conversion completa del juego).
	get_tree().change_scene_to_file("res://scenes/level3d.tscn")
