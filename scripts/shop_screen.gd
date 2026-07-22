extends Control
## Tienda: compra de USOS de ingredientes con el dinero acumulado.
## Un uso = poder llevar recetas con ese ingrediente a UN nivel. Solo se
## listan los ingredientes de las recetas ya desbloqueadas (el arroz es
## infinito y no se vende). Las recetas se desbloquean por campaña, no aquí.
## El jugador ajusta cuánto quiere de cada ingrediente con el selector (◄ N ►)
## y compra TODO de una vez con el botón inferior, que muestra el total.

const PrepBoard := preload("res://scripts/prep_board.gd")
const DARK := Color(0.26, 0.16, 0.08)

var money_label: Label = null
## Cantidad seleccionada por ingrediente (el "carrito"). id -> cantidad.
var cart: Dictionary = {}
## Coste unitario por ingrediente (para el total).
var costs: Dictionary = {}
## Refrescos por fila (usos + cantidad) tras cambiar cantidades o comprar.
var refreshers: Array[Callable] = []
var total_label: Label = null
var buy_button: Button = null


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.14, 0.09, 0.055)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Barra superior: volver + título + monedero.
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	var back := Button.new()
	back.text = "Menú"
	back.custom_minimum_size = Vector2(130, 52)
	PrepBoard.skin_button(back)
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	bar.add_child(back)
	var title := Label.new()
	title.text = "Tienda"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.82))
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.12, 0.05))
	title.add_theme_constant_override("outline_size", 7)
	bar.add_child(title)
	bar.add_child(_make_money_box())
	vbox.add_child(bar)

	# Explicación breve del sistema de usos.
	var hint := Label.new()
	hint.text = "Elige cuántos usos quieres de cada ingrediente y compra todo abajo."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 19)
	hint.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65))
	vbox.add_child(hint)

	# Lista de ingredientes: solo selector de cantidad, sin botón de compra.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	for ing in _sellable_ingredients():
		cart[ing] = 0
		costs[ing] = int(RecipeData.INGREDIENTS[ing].cost)
		list.add_child(_build_row(ing))

	# Barra inferior fija: total del carrito + único botón de compra.
	vbox.add_child(_make_footer())
	_refresh_all()


## Ingredientes de las recetas desbloqueadas (sin arroz), ordenados por coste.
func _sellable_ingredients() -> Array[String]:
	var out: Array[String] = []
	for rid in GameState.unlocked_recipes:
		for ing in RecipeData.get_ingredients(rid):
			if not ing in out:
				out.append(ing)
	out.sort_custom(func(a: String, b: String) -> bool:
		return int(RecipeData.INGREDIENTS[a].cost) < int(RecipeData.INGREDIENTS[b].cost))
	return out


func _make_money_box() -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var coin := TextureRect.new()
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture = load("res://assets/ui/moneda.png")
	coin.custom_minimum_size = Vector2(36, 36)
	box.add_child(coin)
	money_label = Label.new()
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_label.add_theme_font_size_override("font_size", 28)
	money_label.add_theme_color_override("font_color", Color(1, 0.86, 0.4))
	money_label.add_theme_color_override("font_outline_color", Color.BLACK)
	money_label.add_theme_constant_override("outline_size", 5)
	box.add_child(money_label)
	return box


## Fila de un ingrediente: icono, nombre, usos que quedan, coste unitario y
## selector de cantidad (◄ N ►). La compra es global, desde la barra inferior.
func _build_row(ing: String) -> Control:
	var data: Dictionary = RecipeData.INGREDIENTS[ing]
	var cost := int(data.cost)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.add_child(PrepBoard.make_nine_patch("res://assets/ui/panel.png", 34))
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 96)
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var pad_l := Control.new()
	pad_l.custom_minimum_size = Vector2(28, 0)
	row.add_child(pad_l)

	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = RecipeData.get_ingredient_texture(ing)
	icon.custom_minimum_size = Vector2(64, 64)
	row.add_child(icon)

	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_l := Label.new()
	name_l.text = data.name
	name_l.add_theme_font_size_override("font_size", 24)
	name_l.add_theme_color_override("font_color", DARK)
	name_box.add_child(name_l)
	var uses_l := Label.new()
	uses_l.add_theme_font_size_override("font_size", 20)
	uses_l.add_theme_color_override("font_color", Color(0.42, 0.3, 0.18))
	name_box.add_child(uses_l)
	row.add_child(name_box)

	# Precio unitario, para que se vea el coste antes de sumar cantidades.
	var price := _icon_price(cost)
	row.add_child(price)

	# Cantidad a comprar de ESTE ingrediente (guardada en el carrito).
	var minus := _make_arrow("<")
	var qty_l := Label.new()
	qty_l.custom_minimum_size = Vector2(52, 0)
	qty_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qty_l.add_theme_font_size_override("font_size", 30)
	qty_l.add_theme_color_override("font_color", DARK)
	var plus := _make_arrow(">")
	row.add_child(minus)
	row.add_child(qty_l)
	row.add_child(plus)
	var pad_r := Control.new()
	pad_r.custom_minimum_size = Vector2(28, 0)
	row.add_child(pad_r)

	var refresh := func() -> void:
		uses_l.text = "Usos: %d" % GameState.get_ingredient_uses(ing)
		qty_l.text = "%d" % int(cart[ing])
		# La cantidad seleccionada se resalta para verla de un vistazo.
		qty_l.add_theme_color_override("font_color",
				Color(0.2, 0.45, 0.12) if int(cart[ing]) > 0 else DARK)
		minus.disabled = int(cart[ing]) <= 0
		# La flecha de restar se atenúa cuando no se puede bajar más (0).
		minus.modulate = Color(1, 1, 1, 0.4) if int(cart[ing]) <= 0 else Color.WHITE
	refreshers.append(refresh)
	minus.pressed.connect(func() -> void:
		cart[ing] = maxi(int(cart[ing]) - 1, 0)
		refresh.call()
		_refresh_total())
	plus.pressed.connect(func() -> void:
		cart[ing] = mini(int(cart[ing]) + 1, 99)
		refresh.call()
		_refresh_total())
	return panel


## Barra inferior con el total del carrito y el único botón de compra.
func _make_footer() -> Control:
	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	footer.add_child(PrepBoard.make_nine_patch("res://assets/ui/panel.png", 34))
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 92)
	row.add_theme_constant_override("separation", 14)
	footer.add_child(row)

	var pad_l := Control.new()
	pad_l.custom_minimum_size = Vector2(50, 0)
	row.add_child(pad_l)

	var total_box := HBoxContainer.new()
	total_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_box.add_theme_constant_override("separation", 6)
	var tl := Label.new()
	tl.text = "Total:"
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.add_theme_font_size_override("font_size", 26)
	tl.add_theme_color_override("font_color", DARK)
	total_box.add_child(tl)
	var coin := TextureRect.new()
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture = load("res://assets/ui/moneda.png")
	coin.custom_minimum_size = Vector2(34, 34)
	total_box.add_child(coin)
	total_label = Label.new()
	total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	total_label.add_theme_font_size_override("font_size", 30)
	total_label.add_theme_color_override("font_color", DARK)
	total_box.add_child(total_label)
	row.add_child(total_box)

	buy_button = Button.new()
	buy_button.custom_minimum_size = Vector2(220, 68)
	PrepBoard.skin_button(buy_button)
	buy_button.add_theme_font_size_override("font_size", 26)
	buy_button.text = "Comprar"
	buy_button.pressed.connect(_buy_cart)
	row.add_child(buy_button)

	var pad_r := Control.new()
	pad_r.custom_minimum_size = Vector2(34, 0)
	row.add_child(pad_r)
	return footer


func _cart_total() -> int:
	var total := 0
	for ing in cart:
		total += int(costs[ing]) * int(cart[ing])
	return total


func _refresh_total() -> void:
	var total := _cart_total()
	total_label.text = "%d" % total
	buy_button.disabled = total <= 0 or GameState.money < total
	# Aviso cuando no llega el dinero para lo seleccionado.
	buy_button.text = "Comprar" if GameState.money >= total or total == 0 else "Sin dinero"


func _icon_price(cost: int) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var coin := TextureRect.new()
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture = load("res://assets/ui/moneda.png")
	coin.custom_minimum_size = Vector2(30, 30)
	box.add_child(coin)
	var l := Label.new()
	l.text = "%d" % cost
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", DARK)
	box.add_child(l)
	return box


## Botón de flecha con imagen propia (madera + marco de oro), sin texto.
## "<" usa la flecha izquierda; ">" la derecha.
func _make_arrow(dir: String) -> TextureButton:
	var b := TextureButton.new()
	var path := "res://assets/ui/boton_flecha_der.png" if dir == ">" \
			else "res://assets/ui/boton_flecha_izq.png"
	b.texture_normal = load(path)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(66, 66)
	return b


## Compra de golpe todo lo seleccionado en el carrito y lo reinicia.
func _buy_cart() -> void:
	var total := _cart_total()
	if total <= 0 or GameState.money < total:
		return
	GameState.money -= total
	for ing in cart:
		var amount := int(cart[ing])
		if amount > 0:
			GameState.add_ingredient_uses(ing, amount)
			cart[ing] = 0
	GameState.save_game()
	_refresh_all()


func _refresh_all() -> void:
	money_label.text = "%d" % GameState.money
	for r in refreshers:
		r.call()
	_refresh_total()
