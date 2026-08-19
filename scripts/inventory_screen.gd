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
## Retratos sacados de los MODELOS 3D del juego (tools/head_icons.gd), los
## mismos que usa el HUD del nivel: nada de sprites antiguos.
const CLIENT_SPRITES := {
	"E": "res://assets/ui/head_E.png",
	"A": "res://assets/ui/head_A.png",
	"G": "res://assets/ui/head_G.png",
}

var ui: CanvasLayer = null
var content: Control = null
## Bloques que entran por lados distintos en la transición desde el menú.
var top_bar: Control = null
var tabs_row: Control = null
var tab_buttons: Dictionary = {}
var current_tab := "recetario"
var money_label: Label = null

# --- Estado del recetario ---
var search_text := ""
var filter_veg := false
var filter_client := ""
var recipe_page := 0
var pantry_page := 0
## Huecos del recetario que se repintan sin tocar el buscador.
var recipe_book_host: Control = null
var recipe_pager_host: Control = null
var filter_refreshers: Array[Callable] = []

var backdrop: Node3D = null
var _t := 0.0




func _ready() -> void:
	# Las pantallas de menu van a la mitad de fotogramas que el juego
	# (GameState.fps_for): aqui no se juega y renderizar mas gasta bateria.
	Engine.max_fps = GameState.fps_for(false)
	backdrop = SceneBackdrop.build(self, "", 17.0, 40.0, 6.0)
	_setup_ui()
	_show_tab("recetario")
	# La PRIMERA visita la explica David (recetario, despensa y vitrina).
	_explicar_inventario.call_deferred()
	if GameState.take_transition() == "inventario":
		call_deferred("_play_intro")


## Entrada desde el menú: la pantalla llega ya oscurecida y cada bloque entra
## por un lado distinto (barra desde arriba, pestañas desde la izquierda,
## contenido desde abajo).
func _play_intro() -> void:
	var pieces := [
		[top_bar, Vector2(0, -220)],
		[tabs_row, Vector2(-820, 0)],
		[content, Vector2(0, 700)],
	]
	var tw := create_tween().set_parallel(true)
	for p in pieces:
		var node: Control = p[0]
		if node == null:
			continue
		var home: Vector2 = node.position
		node.position = home + (p[1] as Vector2)
		node.modulate.a = 0.0
		tw.tween_property(node, "position", home, 0.55) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "modulate:a", 1.0, 0.4)


func _process(delta: float) -> void:
	_t += delta
	if backdrop != null and GameState.animations_on():
		backdrop.rotation_degrees.y = 205.0 + sin(_t * 0.25) * 8.0
		backdrop.rotation_degrees.z = sin(_t * 0.8) * 2.2
		backdrop.position.y = -0.1 + sin(_t * 1.2) * 0.1


# ----------------------------------------------------------------- armazón

func _setup_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Bajo el notch del movil: todo el contenido baja el area segura y el velo
	# se estira hacia arriba para que no quede una franja clara.
	root.offset_top = GameState.safe_top()
	ui.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.06, 0.09, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.offset_top = -GameState.safe_top()
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
	# Flecha DIBUJADA en la madera (PrepBoard.make_back_button): es el
	# único botón del juego con icono propio, para no confundirlo con
	# un botón normal más.
	var back := PrepBoard.make_back_button()
	back.pressed.connect(func() -> void:
		GameState.fade_to_scene("res://scenes/main_menu.tscn", 0.35, 0.45))
	bar.add_child(back)
	# El rótulo va sobre su CINTA de tela (PrepBoard.make_title):
	# el mismo aire de cartel que el resto del set.
	var title := PrepBoard.make_title("Inventario")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	bar.add_child(_make_money_box())
	top_bar = bar

	# Pestañas.
	var tabs := HBoxContainer.new()
	tabs.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tabs.offset_left = 14.0
	tabs.offset_top = 96.0
	tabs.offset_right = -14.0
	tabs.offset_bottom = 168.0
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	# Las MEJORAS ya no viven aquí: se mudaron a su propia pantalla
	# (perks_screen, el botón "Bonificadores" del submenú del menú principal).
	# El inventario se queda con lo que se lleva encima.
	for def in [["recetario", "Recetario"], ["despensa", "Despensa"],
			["coleccion", "Colección"]]:
		var b := Button.new()
		b.text = def[1]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 72)
		PrepBoard.skin_button(b)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(_show_tab.bind(def[0]))
		tabs.add_child(b)
		tab_buttons[def[0]] = b
	tabs_row = tabs

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
		"coleccion":
			content.add_child(_build_collection())


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

## El buscador y los filtros se construyen UNA VEZ y solo se repinta el libro:
## reconstruir la pestaña entera a cada pulsación le quitaba el foco al
## LineEdit y había que volver a tocarlo por cada letra escrita.
func _build_recipe_book() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	filter_refreshers.clear()

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
		_refresh_recipe_pages())
	PrepBoard.enable_mobile_keyboard(search)
	top.add_child(search)

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	filters.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(filters)
	filters.add_child(_make_filter_chip("Vegetarianas",
		func() -> bool: return filter_veg,
		func() -> void:
			filter_veg = not filter_veg
			recipe_page = 0
			_refresh_recipe_pages()))
	for t in CLIENT_TYPES:
		var type_id := str(t)
		filters.add_child(_make_filter_chip(str(CLIENT_NAMES[type_id]),
			func() -> bool: return filter_client == type_id,
			func() -> void:
				filter_client = "" if filter_client == type_id else type_id
				recipe_page = 0
				_refresh_recipe_pages()))

	# Huecos que se repintan solos: el libro y el pie de página.
	recipe_book_host = Control.new()
	recipe_book_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	recipe_book_host.offset_top = 150.0
	recipe_book_host.offset_bottom = -96.0
	root.add_child(recipe_book_host)
	recipe_pager_host = Control.new()
	recipe_pager_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	recipe_pager_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(recipe_pager_host)
	# Se pasa página deslizando el dedo sobre el libro, como en uno de verdad.
	# Cuelga de `root`, no del libro: sus hijos se borran en cada repintado.
	SwipePages.attach(recipe_book_host, func(delta: int) -> void:
		var pages := maxi(1, ceili(float(_filtered_recipes().size())
			/ float(RECIPES_PER_PAGE)))
		var want := clampi(recipe_page + delta, 0, pages - 1)
		if want != recipe_page:
			recipe_page = want
			_refresh_recipe_pages(), root)
	_refresh_recipe_pages()
	return root


## Repinta SOLO las páginas del libro y el pie; el buscador se queda como está
## (con su texto y su foco).
func _refresh_recipe_pages() -> void:
	if recipe_book_host == null:
		return
	for c in recipe_book_host.get_children():
		c.queue_free()
	for c in recipe_pager_host.get_children():
		c.queue_free()
	for r in filter_refreshers:
		r.call()

	var pages := _make_book(recipe_book_host)
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

	recipe_pager_host.add_child(_make_pager(total_pages, recipe_page,
		func(delta: int) -> void:
			recipe_page = clampi(recipe_page + delta, 0, total_pages - 1)
			_refresh_recipe_pages()))


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
			var only_f: String = data.get("only_type", "")
			if only_f != "" and only_f != filter_client:
				continue
			if _forced_chance(data, filter_client, tier) < 0.4:
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

	# PRIMERO lo que sirve para algo. Un ingrediente cuya receta aún no se sabe
	# cocinar no se puede comprar ni gastar, así que va detrás y en silueta:
	# está en el libro para que se vea que existe, no para consultarlo.
	var conocidos: Array = []
	var por_saber: Array = []
	for ing in RecipeData.INGREDIENTS:
		if _ingredient_known(str(ing)):
			conocidos.append(ing)
		else:
			por_saber.append(ing)
	var ids: Array = conocidos + por_saber
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
	# La despensa es el mismo libro: también se pasa página deslizando.
	SwipePages.attach(book_host, func(delta: int) -> void:
		var want := clampi(pantry_page + delta, 0, total_pages - 1)
		if want != pantry_page:
			pantry_page = want
			_show_tab("despensa"))
	return root


## ¿Este ingrediente lo pide alguna receta YA DESBLOQUEADA? Los EXTRAS
## (jengibre, wasabi, soja) no salen en ninguna receta, así que se miran aparte:
## existen desde que Saverio los presenta.
func _ingredient_known(ing: String) -> bool:
	# Los GRATIS (arroz, sésamo) están siempre: no se compran ni se gastan, y
	# `RecipeData.get_ingredients` los salta a propósito, así que buscarlos en
	# las recetas no los encontraría nunca.
	if int(RecipeData.INGREDIENTS.get(ing, {}).get("cost", 0)) <= 0:
		return true
	if ing in RecipeData.EXTRAS:
		return GameState.extras_unlocked()
	for rid in GameState.unlocked_recipes:
		if ing in RecipeData.get_ingredients(str(rid)):
			return true
	return false


func _build_pantry_entry(ing: String) -> Control:
	var data: Dictionary = RecipeData.INGREDIENTS[ing]
	var conocido := _ingredient_known(ing)
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
	if not conocido:
		# Silueta oscura, igual que una receta por aprender en el recetario.
		icon.modulate = Color(0.12, 0.1, 0.09, 0.75)
	row.add_child(icon)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	var name_l := Label.new()
	name_l.text = str(data.get("name", ing)) if conocido else "???"
	name_l.add_theme_font_size_override("font_size", 20)
	name_l.add_theme_color_override("font_color", DARK if conocido else FADED)
	col.add_child(name_l)
	var uses_l := Label.new()
	# El arroz no se compra ni se gasta: es infinito.
	var infinite := int(data.get("cost", 0)) <= 0
	if not conocido:
		uses_l.text = "Receta por aprender"
		uses_l.add_theme_color_override("font_color", FADED)
	else:
		uses_l.text = "Siempre disponible" if infinite \
				else "Usos: %d" % GameState.get_ingredient_uses(ing)
		uses_l.add_theme_color_override("font_color",
			Color(0.2, 0.45, 0.12) if infinite or GameState.get_ingredient_uses(ing) > 0
			else Color(0.7, 0.18, 0.12))
	uses_l.add_theme_font_size_override("font_size", 18)
	col.add_child(uses_l)
	row.add_child(col)
	return row


# --------------------------------------------------------- ficha de receta

## Ficha de una receta: qué es, qué lleva, quién se la come y cómo se hace.
# --------------------------------------------------------------- colección

## La vitrina de COLECCIONABLES: rejilla sobre pergamino con el recuento
## arriba. Los bloqueados van en SILUETA y con "???", sin ninguna pista de cómo
## conseguirlos; los conseguidos abren su ficha al tocarlos. El triángulo
## dorado enseña además cuántos fragmentos hay reunidos (si hay alguno).
func _build_collection() -> Control:
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))

	var header := Label.new()
	header.text = "Coleccionables: %d / %d" % [GameState.collectibles.size(),
		CollectibleData.total()]
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", Color(0.42, 0.26, 0.10))
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_top = 30.0
	header.offset_bottom = 64.0
	host.add_child(header)

	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 30.0
	scroll.offset_top = 72.0
	scroll.offset_right = -30.0
	scroll.offset_bottom = -30.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	for it in CollectibleData.ITEMS:
		grid.add_child(_collection_card(it))
	return host


func _collection_card(it: Dictionary) -> Control:
	var id := str(it["id"])
	var owned := GameState.has_collectible(id)
	var card := Button.new()
	card.custom_minimum_size = Vector2(152, 176)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		card.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var skin := PrepBoard.make_nine_patch(PrepBoard.CARD_TEX, PrepBoard.CARD_MARGIN)
	skin.modulate = Color.WHITE if owned else Color(1, 1, 1, 0.55)
	card.add_child(skin)

	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = CollectibleData.get_icon(id)
	ic.position = Vector2(29, 10)
	ic.size = Vector2(94, 94)
	# La silueta OSCURA es la única pista que dan los bloqueados.
	ic.modulate = Color.WHITE if owned else Color(0.12, 0.09, 0.07, 0.85)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(ic)

	# Fragmentos del triángulo reunidos: se enseñan solo si ya hay alguno.
	if id == "trifuerza" and not owned and GameState.triforce_pieces > 0:
		var frag := Label.new()
		frag.text = "%d/%d" % [GameState.triforce_pieces,
			CollectibleData.TRIFORCE_PIECES]
		frag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		frag.add_theme_font_size_override("font_size", 24)
		frag.add_theme_color_override("font_color", Color(1, 0.86, 0.4))
		frag.add_theme_color_override("font_outline_color", Color(0.13, 0.07, 0.02))
		frag.add_theme_constant_override("outline_size", 8)
		frag.set_anchors_preset(Control.PRESET_TOP_WIDE)
		frag.offset_top = 48.0
		frag.offset_bottom = 84.0
		frag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(frag)

	var nombre := str(it["name"]) if owned else "???"
	var name_l := Label.new()
	name_l.text = nombre
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# UN NOMBRE LARGO SE ENCOGE EN VEZ DE CORTARSE. "Peluche de un mono con 3
	# cabezas" pide TRES renglones y la Exo 2 reserva ~1.9x el cuerpo por
	# línea, así que a 15 el tercero se salía de la tarjeta y se leía
	# "Peluche de un mono con 3" con la palabra cortada por el canto. Con el
	# cuerpo menor Y el interlineado negativo (la misma perilla de
	# `make_big_title`) los tres renglones caben.
	var largo := nombre.length() > 20
	name_l.add_theme_font_size_override("font_size", 13 if largo else 15)
	name_l.add_theme_constant_override("line_spacing", -6)
	name_l.add_theme_color_override("font_color",
		Color(0.42, 0.26, 0.10) if owned else Color(0.55, 0.47, 0.36))
	name_l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_l.offset_left = 8.0
	name_l.offset_right = -8.0
	name_l.offset_top = -70.0
	name_l.offset_bottom = -10.0
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_l)

	# UNA PIEZA QUE SE ESCAPO NO SE QUEDA EN MISTERIO. Si su escenario ya esta
	# superado, la ficha se puede abrir para leer DONDE sale y QUE pide su
	# cliente: el jugador vio al tipo del tesoro, oyo el encargo y no lo cumplio,
	# asi que esconderselo despues solo seria castigarle dos veces.
	if owned or _pista_coleccionable(id) != "":
		card.pressed.connect(_open_collectible_sheet.bind(id))
		PrepBoard.add_press_feedback(card, 0.92)
	return card


## Pista de una pieza NO conseguida: el escenario donde sale y el encargo que
## pide, con el `reto` tal y como lo canta David. "" si no la da ningun cliente
## del tesoro o si su escenario aun no se ha superado.
func _pista_coleccionable(id: String) -> String:
	if GameState.has_collectible(id):
		return ""
	var port_id := CampaignData.port_for_collectible(id)
	if port_id == "" or not GameState.port_beaten(port_id):
		return ""
	var port := CampaignData.get_port(port_id)
	var n := CampaignData.PORTS.find(port) + 1
	return "Lo trae un cliente del escenario %d, **%s**.
Para que lo suelte, %s." % [
		n, str(port.get("name", "")),
		CampaignData.reto_texto(port.get("collectible_client", {}))]


## Ficha de un coleccionable YA conseguido: dibujo grande, nombre y cómo se
## consiguió. Se cierra con su botón o tocando el velo.
func _open_collectible_sheet(id: String) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 150
	ui.add_child(overlay)
	var veil := Button.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		veil.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(shade)
	veil.pressed.connect(overlay.queue_free)
	overlay.add_child(veil)

	var pw := 500.0
	var ph := 560.0
	var cs := GameState.canvas_size()
	var panel := Control.new()
	panel.position = Vector2((cs.x - pw) * 0.5, (cs.y - ph) * 0.5)
	panel.size = Vector2(pw, ph)
	overlay.add_child(panel)
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))

	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = CollectibleData.get_icon(id)
	ic.position = Vector2((pw - 220.0) * 0.5, 52.0)
	ic.size = Vector2(220, 220)
	# Sin conseguir sigue en SILUETA: la ficha dice como sacarla, no la desvela.
	var tengo := GameState.has_collectible(id)
	if not tengo:
		ic.modulate = Color(0.12, 0.09, 0.07, 0.85)
	panel.add_child(ic)

	var name_l := Label.new()
	name_l.text = CollectibleData.item_name(id)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 32)
	name_l.add_theme_color_override("font_color", Color(0.42, 0.26, 0.10))
	name_l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_l.offset_top = 290.0
	name_l.offset_bottom = 334.0
	panel.add_child(name_l)

	var desc := Label.new()
	desc.text = CollectibleData.describe(id) if tengo else _pista_coleccionable(id)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 21)
	desc.add_theme_color_override("font_color", Color(0.30, 0.20, 0.10))
	desc.set_anchors_preset(Control.PRESET_TOP_WIDE)
	desc.offset_left = 54.0
	desc.offset_right = -54.0
	desc.offset_top = 342.0
	desc.offset_bottom = 448.0
	panel.add_child(desc)

	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	PrepBoard.skin_button(cerrar)
	cerrar.add_theme_font_size_override("font_size", 24)
	cerrar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	cerrar.offset_left = 150.0
	cerrar.offset_right = -150.0
	cerrar.offset_top = 460.0
	cerrar.offset_bottom = 522.0
	cerrar.pressed.connect(overlay.queue_free)
	panel.add_child(cerrar)


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
	box.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))

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
	TouchScroll.attach(scroll)
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
		# QUÉ HACE ESTE PLATO, lo primero de la ficha. Es el mismo texto que sale
		# en la ventana de "¡Receta nueva!" y se DEDUCE de los datos
		# (`RecipeData.summary`), así que las dos pantallas no pueden discrepar.
		var resumen := RecipeData.summary(id)
		if resumen != "":
			var desc := RichTextLabel.new()
			desc.bbcode_enabled = true
			desc.fit_content = true
			desc.scroll_active = false
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			desc.text = DialogueBox.format_keywords(resumen)
			desc.add_theme_font_size_override("normal_font_size", 20)
			desc.add_theme_font_size_override("bold_font_size", 20)
			desc.add_theme_color_override("default_color", DARK)
			body.add_child(desc)
		body.add_child(_build_stats_block(data))
		body.add_child(_section_title("Ingredientes"))
		body.add_child(_build_ingredients_block(id))
		body.add_child(_section_title("Preferencias"))
		body.add_child(_build_clients_block(data))

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
		["Precio", "%d doblones" % int(data.get("price", 0))],
		["Espera", "%.1f s de cooldown" % float(data.get("cooldown", 0.0))],
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
	# "only_type": los postres SOLO los coge un tipo; los demás ni lo miran,
	# así que la ficha tiene que decirlo (si no, mentiría).
	var only: String = data.get("only_type", "")
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	for t in CLIENT_TYPES:
		var chance: float = 0.0
		if only == "" or only == t:
			chance = _forced_chance(data, t, tier)
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


## La probabilidad REAL de que ese tipo coja el plato, con la misma cuenta que
## hace el cliente: matriz propia de la receta si la trae ("take_chances", el
## barco), y encima el "take_chance" (número para todos o {E,A,G} por tipo).
func _forced_chance(data: Dictionary, client_type: String, tier: int) -> float:
	var table: Dictionary = data.get("take_chances", Client3D.TAKE_CHANCES)
	var base: float = float(table.get(client_type, {}).get(tier, 0.0))
	var forced: Variant = data.get("take_chance", null)
	if forced is Dictionary:
		return float(forced.get(client_type, base))
	if forced != null:
		return float(forced)
	return base


## La probabilidad, en cristiano.
func _chance_text(chance: float) -> String:
	if chance >= 0.7:
		return "Es de sus favoritos"
	if chance >= 0.3:
		return "Puede apetecerle"
	return "No le interesa"


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
	return PrepBoard.make_arrow(dir)


## Chip de filtro: se enciende en verde cuando está activo. Se repinta solo
## (via filter_refreshers) para no tener que reconstruir la pestaña entera.
func _make_filter_chip(text: String, is_on: Callable, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 0.94))
	var repaint := func() -> void:
		var on: bool = is_on.call()
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.24, 0.55, 0.2, 0.95) if on \
					else Color(0.2, 0.14, 0.08, 0.85)
			sb.set_corner_radius_all(10)
			sb.set_border_width_all(3)
			sb.border_color = Color(0.5, 1.0, 0.5) if on else Color(0.55, 0.4, 0.22)
			sb.content_margin_left = 10.0
			sb.content_margin_right = 10.0
			b.add_theme_stylebox_override(st, sb)
	repaint.call()
	filter_refreshers.append(repaint)
	PrepBoard.add_press_feedback(b, 0.94)
	b.pressed.connect(action)
	return b


## Explicación de la pantalla, solo la primera vez que se entra.
func _explicar_inventario() -> void:
	if GameState.inventario_intro_done:
		return
	GameState.inventario_intro_done = true
	GameState.save_game()
	var caja := DialogueBox.new()
	caja.z_index = 220
	ui.add_child(caja)
	caja.say([
		{ "text": "Tu **camarote**, %s. Aquí está todo lo que llevas encima." % GameState.player_title(), "mood": "feliz" },
		{ "text": "El **recetario** es el libro de la izquierda: TODAS las recetas del juego. Las que aún no sabes salen en sombra, para que veas lo que te falta por aprender.", "mood": "hablando" },
		{ "text": "Toca una y te cuenta lo que hace, quién se la come y **cómo se prepara**, paso a paso. Si un gesto se te resiste, míralo aquí antes de zarpar.", "mood": "serio" },
		{ "text": "En la **despensa** están tus ingredientes y los usos que te quedan. Un uso es una jornada, no un plato.", "mood": "hablando" },
		{ "text": "¡Y LA VITRINA! ¡RAAAK! ¡LOS CACHIVACHES!", "who": "gigi", "mood": "loro" },
		{ "text": "La **colección**, plumas. Piezas que se pescan o que deja algún cliente agradecido. No sirven para nada... y aun así las quieres todas.", "mood": "riendo" },
	])
	await caja.finished
	await caja.close_and_free()
