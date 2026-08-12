extends Node3D
## BONIFICADORES: los potenciadores permanentes de `PerkData`, en pantalla
## propia. Vivían como pestaña "Mejoras" dentro del Inventario y se mudaron
## aquí al entrar el SUBMENÚ inferior del menú principal: el inventario se
## queda con lo que se lleva encima (recetario y despensa) y esta pantalla con
## lo que se ES.
##
## Los no conseguidos enseñan cómo se ganan; los conseguidos, sus usos y un
## botón para comprar más con doblones.

const PrepBoard := preload("res://scripts/prep_board.gd")
const DARK := Color(0.26, 0.16, 0.08)
const FADED := Color(0.45, 0.34, 0.2)

var ui: CanvasLayer = null
var content: Control = null
var money_label: Label = null
var backdrop: Node3D = null
var _t := 0.0


func _ready() -> void:
	Engine.max_fps = GameState.fps_for(false)
	backdrop = SceneBackdrop.build(self, "", 17.0, 40.0, 6.0)
	_setup_ui()
	GameState.take_transition()


func _process(delta: float) -> void:
	_t += delta
	if backdrop != null and GameState.animations_on():
		backdrop.rotation_degrees.y = 205.0 + sin(_t * 0.25) * 8.0
		backdrop.rotation_degrees.z = sin(_t * 0.8) * 2.2
		backdrop.position.y = -0.1 + sin(_t * 1.2) * 0.1


func _setup_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	var back := PrepBoard.make_back_button()
	back.pressed.connect(func() -> void:
		GameState.fade_to_scene("res://scenes/main_menu.tscn", 0.35, 0.45))
	bar.add_child(back)
	var title := PrepBoard.make_title("Bonificadores")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	bar.add_child(_make_money_box())

	# La hoja de pergamino con la lista dentro.
	var sheet := Control.new()
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.offset_top = 100.0
	sheet.offset_left = 14.0
	sheet.offset_right = -14.0
	sheet.offset_bottom = -20.0
	root.add_child(sheet)
	sheet.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))
	content = Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 54.0
	content.offset_top = 56.0
	content.offset_right = -54.0
	content.offset_bottom = -50.0
	sheet.add_child(content)
	_refresh()


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


## (Re)pinta la lista entera. Tras una compra se vuelve a llamar: repintar de
## golpe es más simple que actualizar la fila y aquí no hay animación que
## perder.
func _refresh() -> void:
	for c in content.get_children():
		c.queue_free()
	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)

	var hint := Label.new()
	hint.text = "Elígelos antes de zarpar; cada partida gasta un uso."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 21)
	hint.add_theme_color_override("font_color", FADED)
	list.add_child(hint)

	for id in PerkData.ids():
		list.add_child(_build_perk_row(str(id)))


func _build_perk_row(id: String) -> Control:
	var data := PerkData.get_perk(id)
	var known := GameState.is_perk_unlocked(id)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# Tarjeta con el pergamino LISO: dentro de la hoja grande, el pergamino con
	# marco parecía un cuadro colgado dentro de otro cuadro.
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.CARD_TEX,
		PrepBoard.CARD_MARGIN))

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 168)
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(20, 0)
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
		buy.custom_minimum_size = Vector2(180, 78)
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		PrepBoard.skin_button(buy)
		buy.add_theme_font_size_override("font_size", 20)
		buy.text = "+1 uso\n$%d" % cost
		buy.disabled = GameState.money < cost
		buy.pressed.connect(func() -> void:
			if GameState.money < cost:
				return
			GameState.money -= cost
			GameState.bump_stat("money_spent", cost)
			GameState.add_perk_uses(id, 1)
			GameState.save_game()
			money_label.text = "%d" % GameState.money
			_refresh())
		row.add_child(buy)
	var pad_r := Control.new()
	pad_r.custom_minimum_size = Vector2(26, 0)
	row.add_child(pad_r)
	return panel
