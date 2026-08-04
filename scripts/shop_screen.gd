extends Node3D
## Tienda: el TENDERO saca cada día un surtido de 8 ingredientes y vende USOS
## (un uso = poder llevar recetas con ese ingrediente a UN nivel).
##
## - El surtido se renueva solo al cambiar el día (fecha real). El botón
##   "Recargar artículos" vuelve a sortearlo pagando (GameState.SHOP_REROLL_COST).
## - Al tocar un artículo se abre un cartel que pregunta CUÁNTOS quieres,
##   con el total y el dinero que te quedaría.
##
## El fondo es 3D (muelle sobre el mar) con el tendero tras su mostrador; toda
## la interfaz va en un CanvasLayer por delante.

const PrepBoard := preload("res://scripts/prep_board.gd")
const DARK := Color(0.26, 0.16, 0.08)
const COLS := 4

var money_label: Label = null
var reroll_button: Button = null
var grid: GridContainer = null
var extras_row: HBoxContainer = null
var ui: CanvasLayer = null
var shopkeeper: Node3D = null
## Sprites del género expuesto en el mostrador (se rehacen al recargar).
var goods_root: Node3D = null
var _t := 0.0




func _ready() -> void:
	# Las pantallas de menu van a la mitad de fotogramas que el juego
	# (GameState.fps_for): aqui no se juega y renderizar mas gasta bateria.
	Engine.max_fps = GameState.fps_for(false)
	GameState.refresh_shop_if_new_day()
	SceneBackdrop.build(self, "puerto", 16.0, 372.0, 5.0)
	_setup_shopkeeper()
	# El mostrador y los cajones son fijos: una malla por color.
	GeometryBatch.bake(self, "ShopBatch")
	_setup_ui()
	_refresh()
	# Se llega desde el negro del menú: el velo es del autoload y lo abre él
	# solo, aquí solo se consume la marca de transición.
	GameState.take_transition()


## El tendero, en su puesto, MONTADO SOBRE UN MUELLE: antes el mostrador
## flotaba sobre el agua y parecía que vendía a nado.
func _setup_shopkeeper() -> void:
	var deck_c := Color(0.55, 0.41, 0.25)
	var deck_dark := Color(0.47, 0.34, 0.20)
	# Entarimado de tablones bajo todo el puesto.
	var plank_n := 11
	for i in plank_n:
		var z := -1.7 + i * 0.62
		_box(Vector3(7.4, 0.16, 0.6), Vector3(1.1, -0.05, z),
			deck_c if i % 2 == 0 else deck_dark)
	# Postes que bajan al agua por el borde del muelle.
	for px in [-2.3, 0.4, 3.1, 4.4]:
		for pz in [-1.85, 4.55]:
			_box(Vector3(0.22, 1.5, 0.22), Vector3(px, -0.75, pz),
				Color(0.38, 0.27, 0.16))

	shopkeeper = SceneBackdrop._spawn_model(self,
		load("res://assets/models/tendero.glb"), 1.5)
	shopkeeper.position = Vector3(1.2, 0.03, 1.2)
	shopkeeper.rotation_degrees.y = 0.0

	# Mostrador: tablero MÁS LARGO y hondo, que es donde se expone el género.
	_box(Vector3(4.6, 0.92, 1.5), Vector3(1.15, 0.46, 2.75), Color(0.44, 0.29, 0.15))
	_box(Vector3(4.9, 0.12, 1.7), Vector3(1.15, 0.98, 2.75), Color(0.63, 0.46, 0.27))
	# Cajones de mercancía al costado.
	_box(Vector3(0.7, 0.7, 0.7), Vector3(4.2, 0.38, 1.7), Color(0.5, 0.36, 0.2))
	_box(Vector3(0.58, 0.58, 0.58), Vector3(4.14, 1.02, 1.62), Color(0.56, 0.41, 0.23))
	_place_goods()


## El género EN EL PUESTO: los ocho artículos del día, en dos filas sobre el
## tablero. Así se ve lo que vende antes de tocar nada.
func _place_goods() -> void:
	if goods_root != null:
		goods_root.queue_free()
	goods_root = Node3D.new()
	add_child(goods_root)
	var stock := GameState.shop_stock
	for i in stock.size():
		var tex := RecipeData.get_ingredient_texture(str(stock[i]))
		if tex == null:
			continue
		var s := Sprite3D.new()
		s.texture = tex
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.shaded = false
		s.transparent = true
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		# 0.62 u de alto: caben ocho en el tablero sin amontonarse.
		s.pixel_size = 0.62 / float(maxi(tex.get_height(), 1))
		var col := i % 4
		var row := i / 4
		s.position = Vector3(-0.55 + col * 1.15, 1.32, 2.35 + row * 0.78)
		goods_root.add_child(s)


func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	mi.material_override = m
	add_child(mi)


func _process(delta: float) -> void:
	_t += delta
	if shopkeeper != null and GameState.animations_on():
		# Respira y se balancea: no tiene esqueleto, así que la vida se la da
		# el propio pivote.
		shopkeeper.position.y = sin(_t * 1.6) * 0.03
		shopkeeper.rotation_degrees.y = sin(_t * 0.5) * 7.0
		shopkeeper.rotation_degrees.z = sin(_t * 0.9 + 0.6) * 1.2


# ----------------------------------------------------------------------- UI

func _setup_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	# Barra superior: volver + título + monedero.
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 18.0
	bar.offset_top = 20.0
	bar.offset_right = -18.0
	bar.offset_bottom = 88.0
	bar.add_theme_constant_override("separation", 10)
	root.add_child(bar)
	var back := Button.new()
	back.text = "Atrás"
	back.custom_minimum_size = Vector2(150, 62)
	PrepBoard.skin_button(back)
	back.add_theme_font_size_override("font_size", 26)
	# Se vuelve con un fundido a negro normal y corriente, igual que el
	# inventario: deshacer el atraque no aportaba nada y se hacía largo.
	back.pressed.connect(func() -> void:
		GameState.fade_to_scene("res://scenes/main_menu.tscn", 0.35, 0.45))
	bar.add_child(back)
	var title := Label.new()
	title.text = "Tienda"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.82))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 10)
	bar.add_child(title)
	bar.add_child(_make_money_box())

	# Rótulo del tendero, sobre el 3D.
	var hint := Label.new()
	hint.text = "El tendero trae género nuevo cada día"
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 96.0
	hint.offset_bottom = 132.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.98, 0.9, 0.72))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 8)
	root.add_child(hint)

	# Mostrador de artículos: 8 huecos en 2 filas sobre un pergamino.
	var shelf := Control.new()
	shelf.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shelf.offset_left = 14.0
	shelf.offset_right = -14.0
	shelf.offset_top = -900.0
	shelf.offset_bottom = -128.0
	root.add_child(shelf)
	shelf.add_child(PrepBoard.make_nine_patch("res://assets/ui/panel.png", 40))
	grid = GridContainer.new()
	grid.columns = COLS
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.offset_left = 44.0
	grid.offset_top = 44.0
	grid.offset_right = -44.0
	grid.offset_bottom = -237.0
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 10)
	shelf.add_child(grid)
	# Los tres EXTRAS de siempre, pequeños y centrados en su propia balda: no
	# cambian nunca, no compiten con el género del día.
	extras_row = HBoxContainer.new()
	extras_row.alignment = BoxContainer.ALIGNMENT_CENTER
	extras_row.add_theme_constant_override("separation", 26)
	extras_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	extras_row.offset_left = 44.0
	extras_row.offset_right = -44.0
	extras_row.offset_top = -227.0
	extras_row.offset_bottom = -87.0
	shelf.add_child(extras_row)

	# Recargar el surtido pagando.
	reroll_button = Button.new()
	reroll_button.custom_minimum_size = Vector2(420, 88)
	PrepBoard.skin_button(reroll_button)
	reroll_button.add_theme_font_size_override("font_size", 26)
	reroll_button.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	reroll_button.offset_left = 150.0
	reroll_button.offset_right = -150.0
	reroll_button.offset_top = -110.0
	reroll_button.offset_bottom = -22.0
	reroll_button.pressed.connect(_on_reroll)
	root.add_child(reroll_button)


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
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_label.add_theme_font_size_override("font_size", 30)
	money_label.add_theme_color_override("font_color", Color(1, 0.86, 0.4))
	money_label.add_theme_color_override("font_outline_color", Color.BLACK)
	money_label.add_theme_constant_override("outline_size", 8)
	box.add_child(money_label)
	return box


## Repinta el surtido y los contadores.
func _refresh() -> void:
	money_label.text = "%d" % GameState.money
	reroll_button.text = "Recargar artículos  $%d" % GameState.SHOP_REROLL_COST
	reroll_button.disabled = GameState.money < GameState.SHOP_REROLL_COST
	for c in grid.get_children():
		c.queue_free()
	for ing in GameState.shop_stock:
		grid.add_child(_build_item(ing))
	# Los EXTRAS (jengibre, wasabi, soja) no entran en el sorteo del día: el
	# tendero los tiene SIEMPRE, pequeños y centrados en su propia balda.
	for c in extras_row.get_children():
		c.queue_free()
	for ing in RecipeData.EXTRAS:
		extras_row.add_child(_build_item(ing, true))


## Un artículo del mostrador: icono, nombre, precio unitario y usos que ya
## tienes. Al pulsarlo se pregunta cuántos quieres.
## Tarjeta compacta de EXTRA: icono, nombre y precio · cantidad debajo.
## SIN fondo propio (el botón trae un panel oscuro del tema por defecto que
## sobre el pergamino parecía una mancha y tapaba lo que era el artículo).
func _fill_small_item(b: Button, ing: String, data: Dictionary, cost: int) -> Button:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = RecipeData.get_ingredient_texture(ing)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 8.0
	icon.offset_top = 2.0
	icon.offset_right = -8.0
	icon.offset_bottom = -58.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var name_l := Label.new()
	name_l.text = str(data.get("name", ing))
	name_l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_l.offset_top = -56.0
	name_l.offset_bottom = -30.0
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 16)
	name_l.add_theme_color_override("font_color", DARK)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name_l)
	var info := Label.new()
	info.text = "$%d · x%d" % [cost, GameState.get_ingredient_uses(ing)]
	info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	info.offset_top = -28.0
	info.offset_bottom = -2.0
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 18)
	info.add_theme_color_override("font_color", Color(0.45, 0.33, 0.2))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(info)
	b.pressed.connect(_open_buy_dialog.bind(ing))
	return b


func _build_item(ing: String, small: bool = false) -> Button:
	var data: Dictionary = RecipeData.INGREDIENTS.get(ing, {})
	var cost := int(data.get("cost", 0))
	var b := Button.new()
	b.custom_minimum_size = Vector2(124, 140) if small else Vector2(150, 226)
	if small:
		return _fill_small_item(b, ing, data, cost)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())

	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = RecipeData.get_ingredient_texture(ing)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 12.0
	icon.offset_top = 6.0
	icon.offset_right = -12.0
	icon.offset_bottom = -98.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)

	var name_l := Label.new()
	name_l.text = str(data.get("name", ing))
	name_l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	# Alto para DOS líneas: "Huevas de salmón" partía en dos y la segunda se
	# comía la fila del precio.
	name_l.offset_top = -96.0
	name_l.offset_bottom = -50.0
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.add_theme_font_size_override("font_size", 16)
	name_l.add_theme_color_override("font_color", DARK)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name_l)

	var price := HBoxContainer.new()
	price.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	price.offset_top = -48.0
	price.offset_bottom = -22.0
	price.alignment = BoxContainer.ALIGNMENT_CENTER
	price.add_theme_constant_override("separation", 3)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := TextureRect.new()
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture = load("res://assets/ui/moneda.png")
	coin.custom_minimum_size = Vector2(26, 26)
	price.add_child(coin)
	var pl := Label.new()
	pl.text = "%d" % cost
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pl.add_theme_font_size_override("font_size", 22)
	pl.add_theme_color_override("font_color", Color(0.4, 0.26, 0.02))
	price.add_child(pl)
	b.add_child(price)

	var uses := Label.new()
	uses.text = "Tienes %d" % GameState.get_ingredient_uses(ing)
	uses.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	uses.offset_top = -22.0
	uses.offset_bottom = -2.0
	uses.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	uses.add_theme_font_size_override("font_size", 15)
	uses.add_theme_color_override("font_color", Color(0.45, 0.33, 0.2))
	uses.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(uses)

	b.pressed.connect(_open_buy_dialog.bind(ing))
	return b


func _on_reroll() -> void:
	if GameState.reroll_shop():
		_refresh()
		_place_goods()


# ------------------------------------------------- cartel de "¿cuántos?"

## Cartel modal: cuántos usos quiere el jugador de ESE ingrediente.
func _open_buy_dialog(ing: String) -> void:
	var data: Dictionary = RecipeData.INGREDIENTS.get(ing, {})
	var cost := int(data.get("cost", 1))
	# La cantidad vive en un diccionario A PROPOSITO: las lambdas de GDScript
	# capturan las variables locales POR VALOR, asi que con un `var qty` las
	# flechas incrementaban su propia copia y el cartel no cambiaba nunca.
	var state := { "qty": 1 }

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var box := Control.new()
	box.custom_minimum_size = Vector2(560, 520)
	box.pivot_offset = Vector2(280, 260)
	center.add_child(box)
	box.add_child(PrepBoard.make_nine_patch("res://assets/ui/panel.png", 60))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 62.0
	vb.offset_top = 54.0
	vb.offset_right = -62.0
	vb.offset_bottom = -46.0
	vb.add_theme_constant_override("separation", 10)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(vb)

	var title := Label.new()
	title.text = "¿Cuánto quieres?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", DARK)
	vb.add_child(title)

	var icon := TextureRect.new()
	icon.texture = RecipeData.get_ingredient_texture(ing)
	icon.custom_minimum_size = Vector2(0, 150)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(icon)

	# Selector de cantidad con las flechas de madera.
	var qty_row := HBoxContainer.new()
	qty_row.alignment = BoxContainer.ALIGNMENT_CENTER
	qty_row.add_theme_constant_override("separation", 16)
	var minus := _make_arrow("<")
	var qty_l := Label.new()
	qty_l.custom_minimum_size = Vector2(90, 0)
	qty_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qty_l.add_theme_font_size_override("font_size", 44)
	qty_l.add_theme_color_override("font_color", DARK)
	var plus := _make_arrow(">")
	qty_row.add_child(minus)
	qty_row.add_child(qty_l)
	qty_row.add_child(plus)
	vb.add_child(qty_row)

	var total_l := Label.new()
	total_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_l.add_theme_font_size_override("font_size", 27)
	total_l.add_theme_color_override("font_color", DARK)
	vb.add_child(total_l)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	var cancel := Button.new()
	cancel.text = "Cancelar"
	cancel.custom_minimum_size = Vector2(216, 78)
	PrepBoard.skin_button(cancel)
	cancel.add_theme_font_size_override("font_size", 23)
	cancel.pressed.connect(overlay.queue_free)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(216, 78)
	PrepBoard.skin_button(buy)
	buy.add_theme_font_size_override("font_size", 23)
	btn_row.add_child(cancel)
	btn_row.add_child(buy)
	vb.add_child(btn_row)

	var refresh := func() -> void:
		var qty: int = state["qty"]
		var total := cost * qty
		qty_l.text = "%d" % qty
		# Junto al total interesa saber CUÁNTO DE ESE INGREDIENTE tienes ya,
		# no el dinero (que sale arriba en el monedero).
		total_l.text = "Total: $%d   (tienes %d)" % [total, GameState.get_ingredient_uses(ing)]
		minus.modulate = Color(1, 1, 1, 0.4) if qty <= 1 else Color.WHITE
		buy.disabled = total > GameState.money
		buy.text = "Comprar" if total <= GameState.money else "Sin dinero"
	minus.pressed.connect(func() -> void:
		state["qty"] = maxi(int(state["qty"]) - 1, 1)
		refresh.call())
	plus.pressed.connect(func() -> void:
		state["qty"] = mini(int(state["qty"]) + 1, 99)
		refresh.call())
	buy.pressed.connect(func() -> void:
		var qty: int = state["qty"]
		var total := cost * qty
		if total > GameState.money:
			return
		GameState.money -= total
		GameState.bump_stat("money_spent", total)
		GameState.add_ingredient_uses(ing, qty)
		GameState.save_game()
		overlay.queue_free()
		_refresh())
	refresh.call()

	box.scale = Vector2(0.7, 0.7)
	var tw := box.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "scale", Vector2.ONE, 0.22)


## Botón de flecha con imagen propia (madera + marco de oro), sin texto.
func _make_arrow(dir: String) -> TextureButton:
	var b := TextureButton.new()
	var path := "res://assets/ui/boton_flecha_der.png" if dir == ">" \
			else "res://assets/ui/boton_flecha_izq.png"
	b.texture_normal = load(path)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(76, 76)
	PrepBoard.add_press_feedback(b)
	return b
