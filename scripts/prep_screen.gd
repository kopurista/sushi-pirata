extends Control
## Fase de preparación: elegir 4 recetas de todas las disponibles.
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

@onready var content: Control = $Margin/VBox/Scroll/Content
@onready var sections: VBoxContainer = $Margin/VBox/Scroll/Content/Sections
@onready var count_label: Label = $Margin/VBox/CountLabel
@onready var start_button: Button = $Margin/VBox/StartButton


func _ready() -> void:
	var board_script := load("res://scripts/prep_board.gd")
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
	_skin_start_button(board_script)
	start_button.pressed.connect(_on_start_pressed)
	# El pergamino debe crecer con el contenido; se reajusta cada vez que la
	# lista cambia de tamaño (envoltura de nombres, etc.).
	sections.resized.connect(_update_content_size)
	call_deferred("_update_content_size")
	_update_ui()


## Barra superior: botón de volver al menú y, en aventura, el nombre del nivel.
func _add_top_bar(board_script: GDScript) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	var back := Button.new()
	back.text = "Menú"
	back.custom_minimum_size = Vector2(130, 52)
	board_script.skin_button(back)
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
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
		spacer.custom_minimum_size = Vector2(130, 0)
		bar.add_child(spacer)
	var vbox: VBoxContainer = $Margin/VBox
	vbox.add_child(bar)
	vbox.move_child(bar, 0)


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


## Botón de zarpar acorde al menú: pergamino con letras marrones grandes.
func _skin_start_button(board_script: GDScript) -> void:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		start_button.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	start_button.add_child(board_script.make_nine_patch("res://assets/ui/panel.png", 38))
	start_button.add_theme_font_size_override("font_size", 34)
	start_button.add_theme_color_override("font_color", DARK)
	start_button.add_theme_color_override("font_hover_color", Color(0.16, 0.1, 0.05))
	start_button.add_theme_color_override("font_pressed_color", Color(0.16, 0.1, 0.05))
	start_button.add_theme_color_override("font_disabled_color", Color(0.55, 0.48, 0.4))


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
	get_tree().change_scene_to_file("res://scenes/level.tscn")
