extends Node3D
## Inventario del jugador, en tres libros:
##
## - RECETARIO: todas las recetas del juego (desbloqueadas y bloqueadas), 4 por
##   página, con buscador y filtros (vegetariana / tipo de cliente). Al tocar
##   una receta se abre su ficha: propiedades, ingredientes, qué clientes se la
##   comerán y una DEMOSTRACIÓN paso a paso de cómo se prepara.
## - DESPENSA: los ingredientes y los usos que quedan de cada uno.
## - POTENCIADORES: los permanentes conseguidos por combos (ver PerkData), con
##   sus usos y la compra de más usos con doblones.
##
## El fondo es 3D (el barco sobre el mar) y toda la interfaz va en un
## CanvasLayer por delante.

const PrepBoard := preload("res://scripts/prep_board.gd")
## Las probabilidades de que cada tipo de cliente coja un plato salen del
## cliente REAL del juego, para que la ficha nunca mienta.
const Client3D := preload("res://scripts/client3d.gd")
const DARK := Color(0.26, 0.16, 0.08)
const FADED := Color(0.45, 0.34, 0.2)

const RECIPES_PER_PAGE := 4
const INGREDIENTS_PER_PAGE := 8
## Nombre y sprite de cada tipo de cliente (para los filtros y las fichas).
const CLIENT_TYPES := ["E", "A", "G"]
const CLIENT_NAMES := { "E": "Grumete", "A": "Pirata", "G": "Capitán" }
const CLIENT_SPRITES := {
	"E": "res://assets/characters/grumete.webp",
	"A": "res://assets/characters/pirata.webp",
	"G": "res://assets/characters/capitan.webp",
}

var ui: CanvasLayer = null
var content: Control = null
var tab_buttons: Dictionary = {}
var current_tab := "recetario"
var money_label: Label = null

# --- Estado del recetario ---
var search_text := ""
var filter_veg := false
var filter_client := ""
var recipe_page := 0
var pantry_page := 0

var backdrop: Node3D = null
var _t := 0.0


func _ready() -> void:
	backdrop = SceneBackdrop.build(self, "", 17.0, 40.0, 6.0)
	_setup_ui()
	_show_tab("recetario")


func _process(delta: float) -> void:
	_t += delta
	if backdrop != null:
		backdrop.rotation_degrees.y = 205.0 + sin(_t * 0.25) * 8.0
		backdrop.rotation_degrees.z = sin(_t * 0.8) * 2.2
		backdrop.position.y = -0.1 + sin(_t * 1.2) * 0.1


# ----------------------------------------------------------------- armazón

func _setup_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.06, 0.09, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 18.0
	bar.offset_top = 18.0
	bar.offset_right = -18.0
	bar.offset_bottom = 86.0
	bar.add_theme_constant_override("separation", 10)
	root.add_child(bar)
	var back := Button.new()
	back.text = "Atrás"
	back.custom_minimum_size = Vector2(150, 62)
	PrepBoard.skin_button(back)
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	bar.add_child(back)
	var title := Label.new()
	title.text = "Inventario"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.82))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 10)
	bar.add_child(title)
	bar.add_child(_make_money_box())

	# Pestañas.
	var tabs := HBoxContainer.new()
	tabs.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tabs.offset_left = 14.0
	tabs.offset_top = 96.0
	tabs.offset_right = -14.0
	tabs.offset_bottom = 168.0
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	for def in [["recetario", "Recetario"], ["despensa", "Despensa"],
			["potenciadores", "Mejoras"]]:
		var b := Button.new()
		b.text = def[1]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 72)
		PrepBoard.skin_button(b)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(_show_tab.bind(def[0]))
		tabs.add_child(b)
		tab_buttons[def[0]] = b

	content = Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_top = 178.0
	content.offset_left = 10.0
	content.offset_right = -10.0
	content.offset_bottom = -14.0
	root.add_child(content)


func _make_money_box() -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var coin := TextureRect.new()
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture = load("res://assets/ui/moneda.png")
	coin.custom_minimum_size = Vector2(38, 38)
	box.add_child(coin)
	money_label = Label.new()
	money_label.text = "%d" % GameState.money
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_label.add_theme_font_size_override("font_size", 30)
	money_label.add_theme_color_override("font_color", Color(1, 0.86, 0.4))
	money_label.add_theme_color_override("font_outline_color", Color.BLACK)
	money_label.add_theme_constant_override("outline_size", 8)
	box.add_child(money_label)
	return box


func _show_tab(tab: String) -> void:
	current_tab = tab
	for id in tab_buttons:
		var b: Button = tab_buttons[id]
		b.modulate = Color.WHITE if id == tab else Color(0.66, 0.62, 0.56)
	for c in content.get_children():
		c.queue_free()
	match tab:
		"recetario":
			content.add_child(_build_recipe_book())
		"despensa":
			content.add_child(_build_pantry_book())
		"potenciadores":
			content.add_child(_build_perks_panel())


## Libro abierto: la textura de fondo y el hueco útil de sus dos páginas.
func _make_book(host: Control) -> Control:
	var book := TextureRect.new()
	book.texture = load("res://assets/ui/libro.png")
	book.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	book.stretch_mode = TextureRect.STRETCH_SCALE
	book.set_anchors_preset(Control.PRESET_FULL_RECT)
	book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(book)
	var pages := Control.new()
	pages.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Márgenes de la tapa de cuero y los cantos dorados.
	pages.offset_left = 54.0
	pages.offset_top = 46.0
	pages.offset_right = -54.0
	pages.offset_bottom = -66.0
	host.add_child(pages)
	return pages


# --------------------------------------------------------------- recetario

func _build_recipe_book() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Buscador y filtros.
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 140.0
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)

	var search := LineEdit.new()
	search.placeholder_text = "Buscar receta..."
	search.text = search_text
	search.custom_minimum_size = Vector2(0, 56)
	search.add_theme_font_size_override("font_size", 24)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.94, 0.84)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.55, 0.4, 0.22)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	search.add_theme_stylebox_override("normal", sb)
	search.add_theme_stylebox_override("focus", sb)
	search.add_theme_color_override("font_color", DARK)
	search.add_theme_color_override("font_placeholder_color", Color(0.55, 0.45, 0.32))
	search.add_theme_color_override("caret_color", DARK)
	search.text_changed.connect(func(t: String) -> void:
		search_text = t
		recipe_page = 0
		_show_tab("recetario"))
	top.add_child(search)

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	filters.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(filters)
	filters.add_child(_make_filter_chip("Vegetarianas", filter_veg,
		func() -> void:
			filter_veg = not filter_veg
			recipe_page = 0
			_show_tab("recetario")))
	for t in CLIENT_TYPES:
		var on: bool = filter_client == t
		filters.add_child(_make_filter_chip(str(CLIENT_NAMES[t]), on,
			func() -> void:
				filter_client = "" if filter_client == t else t
				recipe_page = 0
				_show_tab("recetario")))

	# Libro con 4 recetas por página.
	var book_host := Control.new()
	book_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	book_host.offset_top = 150.0
	book_host.offset_bottom = -96.0
	root.add_child(book_host)
	var pages := _make_book(book_host)

	var ids := _filtered_recipes()
	var total_pages := maxi(1, ceili(float(ids.size()) / float(RECIPES_PER_PAGE)))
	recipe_page = clampi(recipe_page, 0, total_pages - 1)

	if ids.is_empty():
		var empty := Label.new()
		empty.text = "No hay recetas que encajen con la búsqueda."
		empty.set_anchors_preset(Control.PRESET_FULL_RECT)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 24)
		empty.add_theme_color_override("font_color", FADED)
		pages.add_child(empty)
	else:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.set_anchors_preset(Control.PRESET_FULL_RECT)
		# Hueco central para el lomo del libro.
		grid.add_theme_constant_override("h_separation", 34)
		grid.add_theme_constant_override("v_separation", 8)
		pages.add_child(grid)
		var start := recipe_page * RECIPES_PER_PAGE
		for i in range(start, mini(start + RECIPES_PER_PAGE, ids.size())):
			grid.add_child(_build_recipe_entry(ids[i]))

	root.add_child(_make_pager(total_pages, recipe_page,
		func(delta: int) -> void:
			recipe_page = clampi(recipe_page + delta, 0, total_pages - 1)
			_show_tab("recetario")))
	return root


## Recetas que pasan el buscador y los filtros, ordenadas por nivel y precio.
func _filtered_recipes() -> Array:
	var out: Array = []
	var needle := search_text.strip_edges().to_lower()
	for id in RecipeData.RECIPES:
		var data: Dictionary = RecipeData.RECIPES[id]
		if needle != "" and not str(data.get("name", "")).to_lower().contains(needle):
			continue
		if filter_veg and not data.get("vegetarian", false):
			continue
		if filter_client != "":
			# Se listan las recetas que ese tipo de cliente coge con ganas.
			var tier := int(data.get("satiety", data.get("level", 1)))
			if _take_chance(filter_client, tier) < 0.4:
				continue
		out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool:
		var da: Dictionary = RecipeData.RECIPES[a]
		var db: Dictionary = RecipeData.RECIPES[b]
		if int(da.get("level", 1)) != int(db.get("level", 1)):
			return int(da.get("level", 1)) < int(db.get("level", 1))
		return int(da.get("price", 0)) < int(db.get("price", 0)))
	return out


## Una receta en el libro: plato, nombre, estrellas y candado si no se tiene.
func _build_recipe_entry(id: String) -> Button:
	var data: Dictionary = RecipeData.RECIPES[id]
	var known := GameState.is_recipe_unlocked(id)
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 180)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())

	var dish := TextureRect.new()
	dish.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dish.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dish.texture = RecipeData.get_dish_texture(id)
	dish.set_anchors_preset(Control.PRESET_FULL_RECT)
	dish.offset_left = 16.0
	dish.offset_top = 6.0
	dish.offset_right = -16.0
	dish.offset_bottom = -62.0
	dish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not known:
		# Bloqueada: silueta oscura, como una página aún por escribir.
		dish.modulate = Color(0.12, 0.1, 0.09, 0.75)
	b.add_child(dish)

	var name_l := Label.new()
	name_l.text = str(data.get("name", id)) if known else "???"
	name_l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_l.offset_top = -60.0
	name_l.offset_bottom = -26.0
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.add_theme_color_override("font_color", DARK if known else FADED)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name_l)

	var lvl := int(data.get("level", 1))
	var stars := PrepBoard.make_star_row(lvl, lvl, 22)
	stars.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	stars.offset_top = -26.0
	stars.offset_bottom = -2.0
	b.add_child(stars)

	if data.get("vegetarian", false):
		# En la esquina de DENTRO de la página: pegada al borde derecho de la
		# tarjeta caía justo sobre el lomo del libro y parecía suelta.
		var leaf := TextureRect.new()
		leaf.texture = load("res://assets/ui/hoja.png")
		leaf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		leaf.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		leaf.set_anchors_preset(Control.PRESET_TOP_LEFT)
		leaf.offset_left = 4.0
		leaf.offset_top = 2.0
		leaf.offset_right = 34.0
		leaf.offset_bottom = 32.0
		leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(leaf)

	b.pressed.connect(_open_recipe_sheet.bind(id))
	return b


# ---------------------------------------------------------------- despensa

func _build_pantry_book() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var hint := Label.new()
	hint.text = "Cada uso permite llevar ese ingrediente a un nivel"
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_bottom = 44.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 21)
	hint.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 7)
	root.add_child(hint)

	var book_host := Control.new()
	book_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	book_host.offset_top = 54.0
	book_host.offset_bottom = -96.0
	root.add_child(book_host)
	var pages := _make_book(book_host)

	var ids: Array = RecipeData.INGREDIENTS.keys()
	var total_pages := maxi(1, ceili(float(ids.size()) / float(INGREDIENTS_PER_PAGE)))
	pantry_page = clampi(pantry_page, 0, total_pages - 1)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 6)
	pages.add_child(grid)
	var start := pantry_page * INGREDIENTS_PER_PAGE
	for i in range(start, mini(start + INGREDIENTS_PER_PAGE, ids.size())):
		grid.add_child(_build_pantry_entry(str(ids[i])))

	root.add_child(_make_pager(total_pages, pantry_page,
		func(delta: int) -> void:
			pantry_page = clampi(pantry_page + delta, 0, total_pages - 1)
			_show_tab("despensa")))
	return root


func _build_pantry_entry(ing: String) -> Control:
	var data: Dictionary = RecipeData.INGREDIENTS[ing]
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Reparten la altura de la página entre todos, en vez de amontonarse
	# arriba y dejar media hoja en blanco.
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, 96)
	row.add_theme_constant_override("separation", 8)

	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = RecipeData.get_ingredient_texture(ing)
	icon.custom_minimum_size = Vector2(88, 88)
	row.add_child(icon)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	var name_l := Label.new()
	name_l.text = str(data.get("name", ing))
	name_l.add_theme_font_size_override("font_size", 20)
	name_l.add_theme_color_override("font_color", DARK)
	col.add_child(name_l)
	var uses_l := Label.new()
	# El arroz no se compra ni se gasta: es infinito.
	var infinite := int(data.get("cost", 0)) <= 0
	uses_l.text = "Siempre disponible" if infinite \
			else "Usos: %d" % GameState.get_ingredient_uses(ing)
	uses_l.add_theme_font_size_override("font_size", 18)
	uses_l.add_theme_color_override("font_color",
		Color(0.2, 0.45, 0.12) if infinite or GameState.get_ingredient_uses(ing) > 0
		else Color(0.7, 0.18, 0.12))
	col.add_child(uses_l)
	row.add_child(col)
	return row


# ----------------------------------------------------------- potenciadores

func _build_perks_panel() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)

	var hint := Label.new()
	hint.text = "Elígelos antes de zarpar; cada partida gasta un uso."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 21)
	hint.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 7)
	list.add_child(hint)

	for id in PerkData.ids():
		list.add_child(_build_perk_row(str(id)))
	return root


func _build_perk_row(id: String) -> Control:
	var data := PerkData.get_perk(id)
	var known := GameState.is_perk_unlocked(id)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.add_child(PrepBoard.make_nine_patch("res://assets/ui/panel.png", 40))

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 190)
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(30, 0)
	row.add_child(pad)

	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(str(data.get("icon", "")))
	icon.custom_minimum_size = Vector2(96, 96)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not known:
		icon.modulate = Color(0.15, 0.12, 0.1, 0.7)
	row.add_child(icon)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	var name_l := Label.new()
	name_l.text = str(data.get("name", id)) if known else "Potenciador por descubrir"
	name_l.add_theme_font_size_override("font_size", 24)
	name_l.add_theme_color_override("font_color", DARK)
	col.add_child(name_l)
	var desc := Label.new()
	desc.text = str(data.get("desc", "")) if known \
			else "Cómo conseguirlo: %s" % str(data.get("unlock", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(240, 0)
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", FADED)
	col.add_child(desc)
	if known:
		var uses := Label.new()
		uses.text = "Usos: %d" % GameState.get_perk_uses(id)
		uses.add_theme_font_size_override("font_size", 19)
		uses.add_theme_color_override("font_color", Color(0.2, 0.45, 0.12))
		col.add_child(uses)
	row.add_child(col)

	if known:
		var cost := int(data.get("cost", 0))
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(190, 78)
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		PrepBoard.skin_button(buy)
		buy.add_theme_font_size_override("font_size", 20)
		buy.text = "+1 uso\n$%d" % cost
		buy.disabled = GameState.money < cost
		buy.pressed.connect(func() -> void:
			if GameState.money < cost:
				return
			GameState.money -= cost
			GameState.add_perk_uses(id, 1)
			GameState.save_game()
			money_label.text = "%d" % GameState.money
			_show_tab("potenciadores"))
		row.add_child(buy)
	var pad_r := Control.new()
	pad_r.custom_minimum_size = Vector2(36, 0)
	row.add_child(pad_r)
	return panel


# --------------------------------------------------------- ficha de receta

## Ficha de una receta: qué es, qué lleva, quién se la come y cómo se hace.
func _open_recipe_sheet(id: String) -> void:
	var data: Dictionary = RecipeData.RECIPES[id]
	var known := GameState.is_recipe_unlocked(id)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)

	var box := Control.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 24.0
	box.offset_top = 90.0
	box.offset_right = -24.0
	box.offset_bottom = -60.0
	overlay.add_child(box)
	box.add_child(PrepBoard.make_nine_patch("res://assets/ui/panel.png", 60))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 56.0
	vb.offset_top = 52.0
	vb.offset_right = -56.0
	vb.offset_bottom = -44.0
	vb.add_theme_constant_override("separation", 8)
	box.add_child(vb)

	var name_l := Label.new()
	name_l.text = str(data.get("name", id)) if known else "Receta por descubrir"
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.add_theme_font_size_override("font_size", 32)
	name_l.add_theme_color_override("font_color", DARK)
	vb.add_child(name_l)
	var lvl := int(data.get("level", 1))
	vb.add_child(PrepBoard.make_star_row(lvl, lvl, 28))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)

	var dish := TextureRect.new()
	dish.texture = RecipeData.get_dish_texture(id)
	dish.custom_minimum_size = Vector2(0, 190)
	dish.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dish.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not known:
		dish.modulate = Color(0.12, 0.1, 0.09, 0.8)
	body.add_child(dish)

	if not known:
		var locked := Label.new()
		locked.text = "Aún no la conoces. Supera niveles de la campaña para aprenderla."
		locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		locked.add_theme_font_size_override("font_size", 20)
		locked.add_theme_color_override("font_color", FADED)
		body.add_child(locked)
	else:
		body.add_child(_build_stats_block(data))
		body.add_child(_section_title("Ingredientes"))
		body.add_child(_build_ingredients_block(id))
		body.add_child(_section_title("Quién se lo come"))
		body.add_child(_build_clients_block(data))
		body.add_child(_section_title("Cómo se prepara"))
		body.add_child(_build_demo_block(id))

	var close := Button.new()
	close.text = "Cerrar"
	close.custom_minimum_size = Vector2(210, 74)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	PrepBoard.skin_button(close)
	close.add_theme_font_size_override("font_size", 25)
	close.pressed.connect(overlay.queue_free)
	vb.add_child(close)


func _section_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 23)
	l.add_theme_color_override("font_color", Color(0.5, 0.3, 0.1))
	return l


## Precio, saciedad, cooldown y rasgos (vegetariana, maestría...).
func _build_stats_block(data: Dictionary) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 2)
	var rows := [
		["Precio", "$%d" % int(data.get("price", 0))],
		["Llena", "%d de saciedad" % int(data.get("satiety", 1))],
		["Espera", "%.1f s de cooldown" % float(data.get("cooldown", 0.0))],
		["Pasos", "%d gestos" % int(data.get("steps", []).size())],
	]
	if data.get("vegetarian", false):
		rows.append(["Dieta", "Apta para vegetarianos"])
	if int(data.get("free_uses", 0)) > 0:
		rows.append(["Maestría", "Tras hacerla, las %d siguientes salen solas"
			% int(data.get("free_uses", 0))])
	if float(data.get("eat_mult", 1.0)) > 1.0:
		rows.append(["Ojo", "Se come más despacio de lo normal"])
	if float(data.get("tip_chance_bonus", 0.0)) > 0.0:
		rows.append(["Propinas", "Anima a dejar propina"])
	for r in rows:
		var k := Label.new()
		k.text = str(r[0])
		k.add_theme_font_size_override("font_size", 19)
		k.add_theme_color_override("font_color", Color(0.5, 0.35, 0.15))
		grid.add_child(k)
		var v := Label.new()
		v.text = str(r[1])
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_font_size_override("font_size", 19)
		v.add_theme_color_override("font_color", DARK)
		grid.add_child(v)
	return grid


func _build_ingredients_block(id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for ing in RecipeData.get_recipe_ingredients(id):
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = RecipeData.get_ingredient_texture(ing)
		icon.custom_minimum_size = Vector2(74, 66)
		col.add_child(icon)
		var l := Label.new()
		l.text = str(RecipeData.INGREDIENTS.get(ing, {}).get("name", ing))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(78, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", DARK)
		col.add_child(l)
		row.add_child(col)
	return row


## Qué cliente es más probable que coja este plato de la cinta.
func _build_clients_block(data: Dictionary) -> Control:
	var tier := int(data.get("satiety", data.get("level", 1)))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	for t in CLIENT_TYPES:
		var chance := _take_chance(t, tier)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(CLIENT_SPRITES[t])
		icon.custom_minimum_size = Vector2(46, 56)
		row.add_child(icon)
		var l := Label.new()
		l.text = "%s: %s" % [CLIENT_NAMES[t], _chance_text(chance)]
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 19)
		l.add_theme_color_override("font_color",
			DARK if chance >= 0.4 else FADED)
		row.add_child(l)
		col.add_child(row)
	return col


## Probabilidad real de que un tipo de cliente coja un plato de ese nivel.
func _take_chance(client_type: String, tier: int) -> float:
	return float(Client3D.TAKE_CHANCES.get(client_type, {}).get(tier, 0.0))


## La probabilidad, en cristiano.
func _chance_text(chance: float) -> String:
	if chance >= 0.9:
		return "seguro que lo coge"
	if chance >= 0.6:
		return "muy probable"
	if chance >= 0.4:
		return "puede que sí"
	if chance >= 0.15:
		return "rara vez"
	return "no le interesa"


## Demostración: recorre los pasos de la receta mostrando la etapa y el gesto.
func _build_demo_block(id: String) -> Control:
	var steps: Array = RecipeData.RECIPES[id].get("steps", [])
	var stages: Array = RecipeData.RECIPES[id].get("stages", [])
	var host := Control.new()
	host.custom_minimum_size = Vector2(0, 280)

	var board := TextureRect.new()
	board.texture = load("res://assets/props/tabla_cortar.png")
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_SCALE
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.offset_bottom = -58.0
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(board)

	var stage_rect := TextureRect.new()
	stage_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stage_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_rect.offset_left = 60.0
	stage_rect.offset_top = 18.0
	stage_rect.offset_right = -60.0
	stage_rect.offset_bottom = -80.0
	stage_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(stage_rect)

	var step_l := Label.new()
	step_l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	step_l.offset_top = -56.0
	step_l.offset_bottom = -26.0
	step_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_l.add_theme_font_size_override("font_size", 24)
	step_l.add_theme_color_override("font_color", DARK)
	host.add_child(step_l)

	var count_l := Label.new()
	count_l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	count_l.offset_top = -26.0
	count_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_l.add_theme_font_size_override("font_size", 17)
	count_l.add_theme_color_override("font_color", FADED)
	host.add_child(count_l)

	# El bucle avanza solo: se ve la receta entera sin tocar nada.
	var idx := {"i": 0}
	var show_step := func() -> void:
		if steps.is_empty():
			return
		var i: int = int(idx["i"]) % steps.size()
		var step: Dictionary = steps[i]
		# La etapa que se ve es el resultado DE ESE paso.
		var stage_id: String = str(stages[i]) if i < stages.size() else ""
		stage_rect.texture = RecipeData.get_stage_texture(stage_id)
		step_l.text = _step_text(step)
		count_l.text = "Paso %d de %d" % [i + 1, steps.size()]
		stage_rect.pivot_offset = stage_rect.size / 2.0
		stage_rect.scale = Vector2(0.82, 0.82)
		var tw := stage_rect.create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(stage_rect, "scale", Vector2.ONE, 0.25)
	show_step.call()
	var timer := Timer.new()
	timer.wait_time = 1.7
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		idx["i"] = int(idx["i"]) + 1
		show_step.call())
	host.add_child(timer)
	return host


## Texto del gesto de un paso, para la demostración del recetario.
func _step_text(step: Dictionary) -> String:
	var count := int(step.get("count", 1))
	match str(step.get("type", "")):
		"tap_ingredient":
			return "Toca %s" % _ing_name(step.get("ingredient", ""))
		"drag_ingredient":
			return "Arrastra %s a la tabla" % _ing_name(step.get("ingredient", ""))
		"tap_board":
			var verb := "Corta" if bool(step.get("cutting", false)) else "Pulsa"
			return "%s la tabla" % verb if count <= 1 else "%s x%d" % [verb, count]
		"hold_board":
			return "Mantén pulsado %.1f s" % float(step.get("duration", 1.0))
		"swipe_board":
			var dir := "abajo" if step.get("direction", "down") == "down" else "arriba"
			return "Desliza hacia %s x%d" % [dir, count]
		"stir_board":
			return "Remueve en círculos x%d" % count
		"slice_board":
			return "Corta despacio x%d" % count
		"drag_stage":
			return "Arrástralo hasta el utensilio"
	return ""


func _ing_name(ing: String) -> String:
	return str(RecipeData.INGREDIENTS.get(ing, {}).get("name", ing))


# ------------------------------------------------------------------ comunes

## Pie de página del libro: flechas y "Página X de Y".
func _make_pager(total_pages: int, page: int, turn: Callable) -> Control:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -86.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)

	var prev := _make_arrow("<")
	prev.disabled = page <= 0
	prev.modulate = Color(1, 1, 1, 0.35) if page <= 0 else Color.WHITE
	prev.pressed.connect(func() -> void: turn.call(-1))
	row.add_child(prev)

	var l := Label.new()
	l.text = "Página %d de %d" % [page + 1, total_pages]
	l.custom_minimum_size = Vector2(220, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.82))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 7)
	row.add_child(l)

	var next := _make_arrow(">")
	next.disabled = page >= total_pages - 1
	next.modulate = Color(1, 1, 1, 0.35) if page >= total_pages - 1 else Color.WHITE
	next.pressed.connect(func() -> void: turn.call(1))
	row.add_child(next)
	return row


func _make_arrow(dir: String) -> TextureButton:
	var b := TextureButton.new()
	var path := "res://assets/ui/boton_flecha_der.png" if dir == ">" \
			else "res://assets/ui/boton_flecha_izq.png"
	b.texture_normal = load(path)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(76, 76)
	return b


## Chip de filtro: se enciende en verde cuando está activo.
func _make_filter_chip(text: String, on: bool, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.24, 0.55, 0.2, 0.95) if on else Color(0.2, 0.14, 0.08, 0.85)
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(3)
		sb.border_color = Color(0.5, 1.0, 0.5) if on else Color(0.55, 0.4, 0.22)
		sb.content_margin_left = 10.0
		sb.content_margin_right = 10.0
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 0.94))
	b.pressed.connect(action)
	return b
