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


## LA TARJETA CRECE CON SU CONTENIDO. Estuvo montada como una FILA de alto fijo
## (168 px) con el botón de mejorar a la derecha: entre el icono, los dos
## márgenes y un botón de 180 px, a los textos les quedaban ~260 px de ancho,
## así que el nombre, lo que hace el nivel y la condición se partían en cinco o
## seis renglones y se salían por abajo de la tarjeta. Ahora va en dos plantas
## —cabecera arriba, botón abajo a la derecha— y sin alto fijo: cada
## bonificador ocupa lo que necesita y no se corta nada.
func _build_perk_row(id: String) -> Control:
	var data := PerkData.get_perk(id)
	var known := GameState.is_perk_unlocked(id)
	var nivel := GameState.get_perk_level(id)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# Tarjeta con el pergamino LISO: dentro de la hoja grande, el pergamino con
	# marco parecía un cuadro colgado dentro de otro cuadro.
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.CARD_TEX,
		PrepBoard.CARD_MARGIN))

	var margen := MarginContainer.new()
	for lado in ["left", "right"]:
		margen.add_theme_constant_override("margin_%s" % lado, 24)
	margen.add_theme_constant_override("margin_top", 18)
	margen.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margen)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 8)
	margen.add_child(caja)

	# --- Cabecera: icono + nombre y nivel ---
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 14)
	caja.add_child(cab)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(str(data.get("icon", "")))
	icon.custom_minimum_size = Vector2(84, 84)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not known:
		icon.modulate = Color(0.15, 0.12, 0.1, 0.7)
	cab.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 4)
	cab.add_child(col)
	var name_l := Label.new()
	name_l.text = "%s  ·  Nivel %d" % [str(data.get("name", id)), nivel] if known \
			else "Bonificador por descubrir"
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.add_theme_font_size_override("font_size", 24)
	name_l.add_theme_color_override("font_color", DARK)
	col.add_child(name_l)
	var desc := Label.new()
	# Ya conseguido, lo que interesa es QUÉ HACE HOY (con su nivel), no la
	# descripción genérica; sin conseguir, CÓMO se consigue.
	desc.text = PerkData.level_text(id, nivel) if known \
			else "Cómo conseguirlo: %s" % str(data.get("unlock", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 17)
	desc.add_theme_color_override("font_color", FADED)
	col.add_child(desc)
	if not known:
		return panel

	# --- Usos y cómo se ganan más ---
	var uses := Label.new()
	# Los usos NO se compran: se ganan repitiendo el combo del bonificador,
	# así que la tarjeta recuerda cuál es.
	uses.text = "Usos: %d  ·  %s" % [GameState.get_perk_uses(id),
		str(data.get("unlock", ""))]
	uses.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	uses.add_theme_font_size_override("font_size", 16)
	uses.add_theme_color_override("font_color", Color(0.2, 0.45, 0.12))
	caja.add_child(uses)

	# --- EL BOTÓN COMPRA NIVELES, NO USOS ---
	var pie := HBoxContainer.new()
	pie.alignment = BoxContainer.ALIGNMENT_END
	caja.add_child(pie)
	var cost := PerkData.upgrade_cost(nivel)
	if cost <= 0:
		var tope := Label.new()
		tope.text = "Nivel máximo"
		tope.add_theme_font_size_override("font_size", 20)
		tope.add_theme_color_override("font_color", FADED)
		pie.add_child(tope)
		return panel
	var buy := _make_upgrade_button(cost)
	buy.disabled = GameState.money < cost
	buy.pressed.connect(func() -> void: _confirmar_mejora(id))
	pie.add_child(buy)
	return panel


## BOTÓN DE MEJORAR, con su precio dibujado dentro: "Mejorar" arriba y la
## MONEDA del juego con la cifra debajo. El rótulo iba antes en tres renglones
## de texto pelado ("Mejorar\na nivel 3\n$2000") dentro de un botón de 180x90 y
## no cabía. La moneda es la misma que en el resto de contadores del juego, así
## que la cifra se lee como dinero sin tener que decirlo.
func _make_upgrade_button(cost: int) -> Button:
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(226, 96)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	PrepBoard.skin_button(buy)
	buy.text = ""
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 12.0
	col.offset_bottom = -14.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buy.add_child(col)
	var titulo := Label.new()
	titulo.text = "Mejorar"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 24)
	titulo.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	titulo.add_theme_color_override("font_outline_color", Color(0.24, 0.13, 0.05))
	titulo.add_theme_constant_override("outline_size", 7)
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(titulo)
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 6)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(fila)
	var coin := TextureRect.new()
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture = load("res://assets/ui/moneda.png")
	coin.custom_minimum_size = Vector2(28, 28)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(coin)
	var precio := Label.new()
	precio.text = "%d" % cost
	precio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	precio.add_theme_font_size_override("font_size", 24)
	precio.add_theme_color_override("font_color", Color(1, 0.86, 0.4))
	precio.add_theme_color_override("font_outline_color", Color(0.24, 0.13, 0.05))
	precio.add_theme_constant_override("outline_size", 7)
	precio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(precio)
	return buy


## MEJORAR PREGUNTA ANTES. Son de 500 a 10.000 doblones y el botón estaba
## cobrando al primer toque, sin decir siquiera qué se llevaba a cambio: el
## cartel enseña lo que hace HOY el bonificador y lo que hará con la mejora,
## uno debajo del otro, para que la diferencia se vea.
func _confirmar_mejora(id: String) -> void:
	var data := PerkData.get_perk(id)
	var nivel := GameState.get_perk_level(id)
	var cost := PerkData.upgrade_cost(nivel)
	if cost <= 0 or GameState.money < cost:
		return
	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0.55)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.z_index = 160
	ui.get_child(0).add_child(velo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.add_child(centro)
	var cartel := Control.new()
	cartel.custom_minimum_size = Vector2(560, 386)
	centro.add_child(cartel)
	cartel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))
	PrepBoard.add_panel_banner(cartel, "¿Mejorar?", 30)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 56.0
	vb.offset_top = 86.0
	vb.offset_right = -56.0
	vb.offset_bottom = -40.0
	vb.add_theme_constant_override("separation", 12)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	cartel.add_child(vb)
	for linea in [
		["%s, de nivel %d a nivel %d." % [str(data.get("name", id)), nivel,
			nivel + 1], 23, DARK],
		["Ahora: %s" % PerkData.level_text(id, nivel), 18, FADED],
		["Con la mejora: %s" % PerkData.level_text(id, nivel + 1), 20,
			Color(0.2, 0.45, 0.12)],
		["Cuesta %d doblones. Te quedarán %d." % [cost, GameState.money - cost],
			18, FADED],
	]:
		var l := Label.new()
		l.text = str(linea[0])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", int(linea[1]))
		l.add_theme_color_override("font_color", linea[2])
		vb.add_child(l)

	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", 26)
	vb.add_child(botones)
	var no := Button.new()
	no.custom_minimum_size = Vector2(120, 92)
	PrepBoard.skin_action_button(no, false)
	no.pressed.connect(velo.queue_free)
	botones.add_child(no)
	var si := Button.new()
	si.custom_minimum_size = Vector2(120, 92)
	PrepBoard.skin_action_button(si, true)
	si.pressed.connect(func() -> void:
		velo.queue_free()
		if not GameState.upgrade_perk(id):
			return
		money_label.text = "%d" % GameState.money
		_refresh())
	botones.add_child(si)
