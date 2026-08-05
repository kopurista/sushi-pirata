extends Node3D
## LOGROS: el catálogo de `AchievementData` con el progreso de `GameState`.
##
## Cada logro tiene TRES metas (bronce, plata, oro) y se muestra con la medalla
## más alta conseguida, la barra de lo que falta para la siguiente y tres chapas
## que dicen de un vistazo cuáles ya están.
##
## Las pestañas son los apartados del catálogo; el de recetas sale solo, con una
## entrada por plato (y su propio sprite como icono).

const PrepBoard := preload("res://scripts/prep_board.gd")
const DARK := Color(0.26, 0.16, 0.08)
const FADED := Color(0.52, 0.42, 0.30)
## Medalla sin conseguir: la misma chapa, apagada.
const LOCKED_COLOR := Color(0.42, 0.38, 0.34)

var ui: CanvasLayer = null
var content: Control = null
var list_host: VBoxContainer = null
var tab_buttons: Dictionary = {}
var current_group := "clientela"
var backdrop: Node3D = null
var _t := 0.0


func _ready() -> void:
	Engine.max_fps = GameState.fps_for(false)
	backdrop = SceneBackdrop.build(self, "", 17.0, 40.0, 6.0)
	_setup_ui()
	_show_group(current_group)
	GameState.take_transition()


func _process(delta: float) -> void:
	_t += delta
	if backdrop != null and GameState.animations_on():
		backdrop.rotation_degrees.y = 205.0 + sin(_t * 0.25) * 8.0
		backdrop.rotation_degrees.z = sin(_t * 0.8) * 2.2
		backdrop.position.y = -0.1 + sin(_t * 1.2) * 0.1


# ----------------------------------------------------------------------- UI

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
		GameState.fade_to_scene("res://scenes/main_menu.tscn", 0.35, 0.45))
	bar.add_child(back)
	var title := Label.new()
	title.text = "Logros"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.82))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 10)
	bar.add_child(title)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(150, 0)
	bar.add_child(pad)

	# Marcador de medallas: cuántas de cada clase sobre el total del catálogo.
	var counts := GameState.medal_counts()
	var tally := HBoxContainer.new()
	tally.alignment = BoxContainer.ALIGNMENT_CENTER
	tally.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tally.offset_top = 92.0
	tally.offset_bottom = 140.0
	tally.add_theme_constant_override("separation", 26)
	root.add_child(tally)
	for i in AchievementData.MEDALS.size():
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 6)
		chip.add_child(_medal_icon(i + 1, 38.0))
		var n := Label.new()
		n.text = "%d/%d" % [int(counts[AchievementData.MEDALS[i]]),
			int(counts["total"])]
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		n.add_theme_font_size_override("font_size", 26)
		n.add_theme_color_override("font_color", Color(1, 0.93, 0.75))
		n.add_theme_color_override("font_outline_color", Color.BLACK)
		n.add_theme_constant_override("outline_size", 8)
		chip.add_child(n)
		tally.add_child(chip)

	# Pestañas por apartado.
	var tabs := HBoxContainer.new()
	tabs.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tabs.offset_left = 12.0
	tabs.offset_top = 148.0
	tabs.offset_right = -12.0
	tabs.offset_bottom = 212.0
	tabs.add_theme_constant_override("separation", 6)
	root.add_child(tabs)
	for g in AchievementData.GROUPS:
		var b := Button.new()
		# Rótulo CORTO: el tablón de madera solo deja ~84 px libres entre sus
		# esquinas doradas y "Clientela" se salía del marco.
		b.text = str(AchievementData.GROUP_TABS[g])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 60)
		PrepBoard.skin_button(b)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_show_group.bind(g))
		tabs.add_child(b)
		tab_buttons[g] = b

	content = Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_top = 222.0
	content.offset_left = 12.0
	content.offset_right = -12.0
	content.offset_bottom = -16.0
	root.add_child(content)
	content.add_child(PrepBoard.make_nine_patch("res://assets/ui/panel.png", 40))

	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 26.0
	scroll.offset_top = 26.0
	scroll.offset_right = -26.0
	scroll.offset_bottom = -26.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	list_host = VBoxContainer.new()
	list_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_host.add_theme_constant_override("separation", 10)
	scroll.add_child(list_host)


func _show_group(group: String) -> void:
	current_group = group
	for g in tab_buttons:
		var b: Button = tab_buttons[g]
		b.modulate = Color.WHITE if g == group else Color(0.66, 0.62, 0.56)
	for c in list_host.get_children():
		c.queue_free()
	for a in AchievementData.in_group(group):
		list_host.add_child(_build_card(a))


# -------------------------------------------------------------- una tarjeta

func _build_card(a: Dictionary) -> Control:
	var value := GameState.achievement_value(a)
	var medal := AchievementData.medal_for(a, value)
	var target := AchievementData.next_target(a, value)
	var done := medal >= AchievementData.MEDALS.size()

	var card := Control.new()
	card.custom_minimum_size = Vector2(0, 116)
	var skin := PrepBoard.make_nine_patch("res://assets/ui/boton_madera.png", 40)
	skin.modulate = Color(1, 1, 1, 0.5) if medal == 0 else Color.WHITE
	card.add_child(skin)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20.0
	row.offset_top = 12.0
	row.offset_right = -28.0
	row.offset_bottom = -12.0
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	# Icono: el plato en los logros de receta, la medalla en los demás.
	if a.has("recipe"):
		var dish := TextureRect.new()
		dish.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dish.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dish.texture = RecipeData.get_dish_texture(str(a["recipe"]))
		dish.custom_minimum_size = Vector2(78, 78)
		dish.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dish.modulate = Color(1, 1, 1, 1.0 if medal > 0 else 0.55)
		row.add_child(dish)
	else:
		var ic := _medal_icon(medal, 72.0)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var name_l := Label.new()
	name_l.text = str(a["name"])
	name_l.add_theme_font_size_override("font_size", 23)
	name_l.add_theme_color_override("font_color", Color(1, 0.94, 0.8))
	name_l.add_theme_color_override("font_outline_color", Color(0.13, 0.07, 0.02))
	name_l.add_theme_constant_override("outline_size", 6)
	col.add_child(name_l)
	var desc := Label.new()
	desc.text = "¡Todas las medallas!" if done \
			else AchievementData.describe(a, value)
	desc.add_theme_font_size_override("font_size", 17)
	desc.add_theme_color_override("font_color", Color(0.94, 0.86, 0.7))
	desc.add_theme_color_override("font_outline_color", Color(0.13, 0.07, 0.02))
	desc.add_theme_constant_override("outline_size", 5)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(desc)
	col.add_child(_progress_bar(value, target, medal, done))

	# Las tres chapas: se encienden a medida que caen las medallas.
	var pips := VBoxContainer.new()
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.add_theme_constant_override("separation", 2)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in AchievementData.MEDALS.size():
		var p := _medal_icon(i + 1 if medal >= i + 1 else 0, 26.0)
		pips.add_child(p)
	row.add_child(pips)
	return card


## Chapa de medalla: la moneda del juego teñida del color de su metal (apagada
## si aún no está conseguida). `level` 0 = ninguna, 1 bronce, 2 plata, 3 oro.
func _medal_icon(level: int, size: float) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture = load("res://assets/ui/moneda.png")
	t.custom_minimum_size = Vector2(size, size)
	t.modulate = LOCKED_COLOR if level <= 0 \
			else AchievementData.MEDAL_COLORS[level - 1]
	return t


## Barra de lo que falta para la SIGUIENTE medalla, con el recuento encima.
func _progress_bar(value: int, target: int, medal: int, done: bool) -> Control:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 26)
	bar.max_value = maxf(float(target), 1.0)
	bar.value = float(mini(value, target))
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.16, 0.10, 0.05, 0.75)
	bg.set_corner_radius_all(8)
	var fill := StyleBoxFlat.new()
	# La barra se pinta del metal que se está persiguiendo (o del oro, si ya
	# están las tres).
	fill.bg_color = AchievementData.MEDAL_COLORS[mini(medal, 2)]
	fill.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)

	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, 26)
	wrap.add_child(bar)
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	var l := Label.new()
	l.text = "%d / %d" % [value, target] if not done else "%d" % value
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(1, 0.97, 0.9))
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	l.add_theme_constant_override("outline_size", 5)
	wrap.add_child(l)
	return wrap
