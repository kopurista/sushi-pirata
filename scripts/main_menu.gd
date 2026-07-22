extends Control
## Menú principal: Aventura (niveles de campaña), Tienda (comprar usos de
## ingredientes) y Prueba (partida libre con todas las recetas).

const PrepBoard := preload("res://scripts/prep_board.gd")


func _ready() -> void:
	# Fondo de madera oscura de camarote.
	var bg := ColorRect.new()
	bg.color = Color(0.14, 0.09, 0.055)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

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
	add_child(money_box)

	# Título del juego.
	var title := Label.new()
	title.text = "Sushi Pirata"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 170.0
	title.offset_bottom = 300.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 82)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.82))
	title.add_theme_color_override("font_outline_color", Color(0.32, 0.18, 0.06))
	title.add_theme_constant_override("outline_size", 14)
	add_child(title)

	# Botones de modo, centrados en vertical.
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -210.0
	box.offset_right = 210.0
	box.offset_top = -60.0
	box.add_theme_constant_override("separation", 30)
	add_child(box)
	box.add_child(_make_mode_button("Aventura", func() -> void:
		get_tree().change_scene_to_file("res://scenes/level_select.tscn")))
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
	b.custom_minimum_size = Vector2(420, 116)
	PrepBoard.skin_button(b)
	b.add_theme_font_size_override("font_size", 42)
	b.pressed.connect(action)
	return b
