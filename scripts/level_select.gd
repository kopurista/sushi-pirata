extends Control
## Aventura: lista de niveles de la campaña. Cada tarjeta muestra nombre,
## descripción, mejores estrellas y objetivo; los niveles aún no alcanzados
## aparecen bloqueados. Tocar un nivel lleva a la selección de recetas.

const PrepBoard := preload("res://scripts/prep_board.gd")
const DARK := Color(0.26, 0.16, 0.08)


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
	vbox.add_theme_constant_override("separation", 18)
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
	title.text = "Aventura"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.82))
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.12, 0.05))
	title.add_theme_constant_override("outline_size", 7)
	bar.add_child(title)
	bar.add_child(_make_money_label())
	vbox.add_child(bar)

	# Lista de niveles.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)
	for port in CampaignData.PORTS:
		list.add_child(_build_level_card(port))


func _make_money_label() -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var coin := TextureRect.new()
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture = load("res://assets/ui/moneda.png")
	coin.custom_minimum_size = Vector2(36, 36)
	box.add_child(coin)
	var l := Label.new()
	l.text = "%d" % GameState.money
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", Color(1, 0.86, 0.4))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	box.add_child(l)
	return box


## Tarjeta de nivel: pergamino con número+nombre, descripción, estrellas
## conseguidas y objetivo. Bloqueada si el nivel anterior no está superado.
func _build_level_card(port: Dictionary) -> Control:
	var id: String = port.id
	var unlocked := GameState.is_port_unlocked(id)
	var best: int = int(GameState.level_stars.get(id, 0))
	var best_score: int = GameState.get_level_score(id)
	var idx := CampaignData.port_index(id)

	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 300)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.add_child(PrepBoard.make_nine_patch("res://assets/ui/panel.png", 38))

	# El marco de cuerda del pergamino ocupa ~45 px por lado: el contenido va
	# bien por dentro para no pisar los bordes enrollados.
	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 60.0
	inner.offset_right = -60.0
	inner.offset_top = 42.0
	inner.offset_bottom = -42.0
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)

	var name_l := Label.new()
	name_l.text = "Nivel %d — %s" % [idx + 1, port.get("name", id)]
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 30)
	name_l.add_theme_color_override("font_color", DARK)
	inner.add_child(name_l)

	var desc := Label.new()
	desc.text = port.get("desc", "") if unlocked else "Bloqueado: supera el nivel anterior."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 20)
	desc.add_theme_color_override("font_color", Color(0.42, 0.3, 0.18))
	inner.add_child(desc)

	inner.add_child(PrepBoard.make_star_row(best, 3, 34))

	# Puntuación máxima (dinero ganado) que el jugador ha hecho en el nivel.
	if unlocked:
		inner.add_child(_make_record_row(best_score))

	var goal := Label.new()
	var thresholds: Array = port.get("star_money", [])
	goal.text = "Objetivo: %d estrellas ($%d)" % [int(port.get("goal_stars", 1)),
			int(thresholds[int(port.get("goal_stars", 1)) - 1]) if not thresholds.is_empty() else 0]
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal.add_theme_font_size_override("font_size", 18)
	goal.add_theme_color_override("font_color", Color(0.42, 0.3, 0.18))
	inner.add_child(goal)

	if unlocked:
		b.pressed.connect(func() -> void:
			GameState.mode = "adventure"
			GameState.current_port = id
			GameState.selected_recipes = []
			get_tree().change_scene_to_file("res://scenes/prep_screen.tscn"))
	else:
		b.disabled = true
		b.modulate = Color(1, 1, 1, 0.5)
	return b


## Fila con la mejor puntuación (dinero ganado) del nivel: moneda + cifra
## dorada, o "sin jugar" si aún no se ha completado ninguna partida.
func _make_record_row(best_score: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag := Label.new()
	tag.text = "Récord:"
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 20)
	tag.add_theme_color_override("font_color", Color(0.5, 0.36, 0.14))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tag)
	if best_score > 0:
		var coin := TextureRect.new()
		coin.texture = load("res://assets/ui/moneda.png")
		coin.custom_minimum_size = Vector2(28, 28)
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(coin)
		var val := Label.new()
		val.text = "%d" % best_score
		val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		val.add_theme_font_size_override("font_size", 24)
		val.add_theme_color_override("font_color", Color(0.75, 0.52, 0.06))
		val.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(val)
	else:
		var none := Label.new()
		none.text = "sin jugar"
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		none.add_theme_font_size_override("font_size", 20)
		none.add_theme_color_override("font_color", Color(0.5, 0.36, 0.14))
		none.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(none)
	return row
