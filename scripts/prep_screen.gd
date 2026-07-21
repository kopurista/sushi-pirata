extends Control
## Fase de preparación: elegir 4 recetas de las 6 disponibles.
## Tarjetas de pergamino sobre la cubierta del barco: plato en grande,
## estrellas de dificultad, nombre y precio con moneda bien legibles.
## Al seleccionar aparece el check verde y la tarjeta se ilumina.

const MAX_RECIPES := 4
const DARK := Color(0.26, 0.16, 0.08)

var selected: Array[String] = []

@onready var grid: GridContainer = $Margin/VBox/Grid
@onready var count_label: Label = $Margin/VBox/CountLabel
@onready var start_button: Button = $Margin/VBox/StartButton


func _ready() -> void:
	var board_script := load("res://scripts/prep_board.gd")
	for id in RecipeData.RECIPES:
		grid.add_child(_build_card(id, board_script))
	_skin_start_button(board_script)
	start_button.pressed.connect(_on_start_pressed)
	_update_ui()


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
	b.custom_minimum_size = Vector2(310, 250)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	# Tarjeta de pergamino, como los paneles del resto del juego.
	b.add_child(board_script.make_nine_patch("res://assets/ui/panel.png", 38))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 14.0
	vb.offset_top = 12.0
	vb.offset_right = -14.0
	vb.offset_bottom = -22.0
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 3)

	var tex := RecipeData.get_dish_texture(id)
	if tex != null:
		var ic := TextureRect.new()
		ic.texture = tex
		ic.custom_minimum_size = Vector2(0, 106)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(ic)

	# Estrellas de dificultad.
	vb.add_child(board_script.make_star_row(int(data.get("level", 1)),
			int(data.get("level", 1)), 26))

	# Nombre en marrón oscuro, legible sobre el pergamino.
	var nl := Label.new()
	nl.text = data.name
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.add_theme_font_size_override("font_size", 20)
	nl.add_theme_color_override("font_color", DARK)
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nl)

	b.add_child(vb)

	# Precio como insignia en la esquina superior izquierda (simétrica al
	# check): moneda + cantidad, siempre visible sobre el pergamino.
	var price_box := HBoxContainer.new()
	price_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	price_box.offset_left = 16.0
	price_box.offset_top = 12.0
	price_box.offset_right = 120.0
	price_box.offset_bottom = 46.0
	price_box.add_theme_constant_override("separation", 5)
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
	pl.add_theme_font_size_override("font_size", 25)
	pl.add_theme_color_override("font_color", Color(0.45, 0.3, 0.03))
	pl.add_theme_color_override("font_outline_color", Color(1, 0.97, 0.88))
	pl.add_theme_constant_override("outline_size", 6)
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_box.add_child(pl)
	b.add_child(price_box)

	# Check verde de selección (esquina superior derecha).
	var check := TextureRect.new()
	check.name = "Check"
	check.visible = false
	check.texture = load("res://assets/ui/check.png") if ResourceLoader.exists("res://assets/ui/check.png") else null
	check.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	check.offset_left = -64.0
	check.offset_top = 6.0
	check.offset_right = -8.0
	check.offset_bottom = 62.0
	check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(check)

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
	# La tarjeta elegida se ilumina; las demás quedan neutras.
	button.modulate = Color(1.06, 1.04, 0.9) if button.button_pressed else Color.WHITE
	_update_ui()


func _update_ui() -> void:
	count_label.text = "%d/%d elegidas" % [selected.size(), MAX_RECIPES]
	start_button.disabled = selected.size() != MAX_RECIPES


func _on_start_pressed() -> void:
	GameState.selected_recipes = selected.duplicate()
	get_tree().change_scene_to_file("res://scenes/level.tscn")
