extends Node3D
## OPCIONES, en tres pestañas:
##
## - PERFIL: nombre y género del cocinero. El género decide QUÉ MODELO 3D sale
##   en el nivel (ver CharacterData) y cómo se dirige el juego al jugador.
## - GRÁFICOS: bloques alta / media / baja, o "personalizado" para tocar los
##   cuatro ajustes por separado.
## - PROGRESO: horas jugadas de verdad (solo dentro de partidas) y el borrado,
##   que exige MANTENER pulsado cinco segundos.
##
## Perfil y Gráficos se aplican con su botón, no al vuelo: así se puede probar
## una combinación y arrepentirse sin haberla guardado. Lo que se ve al entrar
## es siempre lo que está guardado.

const PrepBoard := preload("res://scripts/prep_board.gd")
const DARK := Color(0.26, 0.16, 0.08)
const FADED := Color(0.45, 0.34, 0.2)
## Lo que hay que mantener pulsado para borrar el progreso.
const WIPE_HOLD := 5.0
## Tarjeta de género: los retratos son 300x440, así que la tarjeta guarda esa
## proporción y reserva abajo el hueco del nombre.
const CARD_W := 168.0
const CARD_H := 282.0
const CARD_LABEL := 40.0

var ui: CanvasLayer = null
var content: Control = null
var tab_buttons: Dictionary = {}
var current_tab := "perfil"
var backdrop: Node3D = null
var _t := 0.0

# --- Cambios pendientes de aplicar (no tocan GameState hasta el botón) ---
var draft_name := ""
var draft_gender := ""
var draft_graphics: Dictionary = {}
var apply_profile: Button = null
var apply_graphics_btn: Button = null

# --- Borrado del progreso: barra que se llena mientras se mantiene pulsado ---
var wipe_bar: ProgressBar = null
var wipe_holding := false
var wipe_time := 0.0


func _ready() -> void:
	Engine.max_fps = GameState.fps_for(false)
	backdrop = SceneBackdrop.build(self, "", 17.0, 40.0, 6.0)
	_reset_drafts()
	_setup_ui()
	_show_tab(current_tab)
	GameState.take_transition()


func _reset_drafts() -> void:
	draft_name = GameState.player_name
	draft_gender = GameState.player_gender
	draft_graphics = {
		"preset": GameState.current_preset(),
		"quality": int(GameState.get_setting("quality")),
		"fps": int(GameState.get_setting("fps")),
		"shadows": bool(GameState.get_setting("shadows")),
		"anim": bool(GameState.get_setting("anim")),
	}


func _process(delta: float) -> void:
	_t += delta
	if backdrop != null and GameState.animations_on():
		backdrop.rotation_degrees.y = 205.0 + sin(_t * 0.25) * 8.0
		backdrop.rotation_degrees.z = sin(_t * 0.8) * 2.2
		backdrop.position.y = -0.1 + sin(_t * 1.2) * 0.1
	if wipe_holding:
		wipe_time += delta
		if wipe_bar != null:
			wipe_bar.value = minf(wipe_time / WIPE_HOLD, 1.0) * 100.0
		if wipe_time >= WIPE_HOLD:
			wipe_holding = false
			_do_wipe()


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
	title.text = "Opciones"
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

	var tabs := HBoxContainer.new()
	tabs.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tabs.offset_left = 14.0
	tabs.offset_top = 96.0
	tabs.offset_right = -14.0
	tabs.offset_bottom = 168.0
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	for def in [["perfil", "Perfil"], ["graficos", "Gráficos"],
			["progreso", "Progreso"]]:
		var b := Button.new()
		b.text = def[1]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 72)
		PrepBoard.skin_button(b)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(_show_tab.bind(def[0]))
		tabs.add_child(b)
		tab_buttons[def[0]] = b

	var sheet := Control.new()
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.offset_top = 178.0
	sheet.offset_left = 14.0
	sheet.offset_right = -14.0
	sheet.offset_bottom = -20.0
	root.add_child(sheet)
	sheet.add_child(PrepBoard.make_nine_patch("res://assets/ui/panel.png", 40))

	# El marco del pergamino se come ~40 px por lado: el contenido entra por
	# dentro de él o los rótulos quedan medio tapados por la madera.
	content = Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 78.0
	content.offset_top = 70.0
	content.offset_right = -78.0
	content.offset_bottom = -56.0
	sheet.add_child(content)


func _show_tab(tab: String) -> void:
	current_tab = tab
	for id in tab_buttons:
		var b: Button = tab_buttons[id]
		b.modulate = Color.WHITE if id == tab else Color(0.66, 0.62, 0.56)
	for c in content.get_children():
		c.queue_free()
	wipe_holding = false
	wipe_bar = null
	# Al cambiar de pestaña se olvidan los cambios sin aplicar: si no, el
	# botón se quedaba encendido con algo que ya no se está viendo.
	_reset_drafts()
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 14)
	content.add_child(box)
	match tab:
		"perfil":
			_build_profile(box)
		"graficos":
			_build_graphics(box)
		"progreso":
			_build_progress(box)


# -------------------------------------------------------------- PERFIL

func _build_profile(box: VBoxContainer) -> void:
	_header(box, "El cocinero")
	_note(box, "Así te llama el juego y así sale el chef en la cocina.")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 70)
	row.add_child(_row_label("Nombre"))
	var edit := LineEdit.new()
	edit.text = draft_name
	edit.placeholder_text = "Sin nombre"
	edit.max_length = 14
	edit.custom_minimum_size = Vector2(300, 62)
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.add_theme_font_size_override("font_size", 26)
	# El recuadro gris del tema por defecto sobre el pergamino parecía una
	# mancha: se le pone su propia caja de papel con borde de tinta.
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(0.99, 0.93, 0.78)
	paper.border_color = Color(0.44, 0.31, 0.16)
	paper.set_border_width_all(3)
	paper.set_corner_radius_all(10)
	paper.set_content_margin_all(8)
	edit.add_theme_stylebox_override("normal", paper)
	edit.add_theme_stylebox_override("focus", paper)
	edit.add_theme_color_override("font_color", DARK)
	edit.add_theme_color_override("font_placeholder_color", Color(0.55, 0.45, 0.32))
	edit.add_theme_color_override("caret_color", DARK)
	edit.text_changed.connect(func(t: String) -> void:
		draft_name = t
		_refresh_apply())
	PrepBoard.enable_mobile_keyboard(edit)
	row.add_child(edit)
	box.add_child(row)

	_header(box, "Género")
	# Se elige TOCANDO AL PERSONAJE, no un botón con su nombre: el retrato es el
	# propio modelo 3D del chef (tools/chef_portraits.gd lo rinde a PNG; tres
	# SubViewports vivos en un menú serían tres escenas 3D de más).
	var choices := HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 8)
	box.add_child(choices)
	var cards: Dictionary = {}
	for g in CharacterData.PLAYER_GENDERS:
		var card := _gender_card(g, func() -> void:
			draft_gender = g
			for id in cards:
				_paint_gender_card(cards[id], id == draft_gender)
			_refresh_apply())
		choices.add_child(card)
		cards[g] = card
		_paint_gender_card(card, g == draft_gender)

	apply_profile = _apply_button(box, func() -> void:
		GameState.player_name = draft_name.strip_edges()
		GameState.player_gender = draft_gender
		GameState.save_game()
		_refresh_apply()
		_flash("Perfil guardado"))
	_refresh_apply()


## Tarjeta de un género: el retrato del chef, su nombre debajo y un marco que
## se enciende al elegirlo.
func _gender_card(gender: String, action: Callable) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.name = "card_%s" % gender

	var frame := Panel.new()
	frame.name = "Frame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.30, 0.19, 0.09, 0.35)
	box.border_color = Color(0.95, 0.76, 0.28)
	box.set_border_width_all(4)
	box.set_corner_radius_all(14)
	frame.add_theme_stylebox_override("panel", box)
	card.add_child(frame)

	var b := TextureButton.new()
	b.name = "Pic"
	b.texture_normal = load("res://assets/ui/chef_%s.png" % gender)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.offset_top = 6.0
	b.offset_bottom = -CARD_LABEL
	b.pressed.connect(action)
	PrepBoard.add_press_feedback(b, 0.94)
	card.add_child(b)

	var l := Label.new()
	l.name = "Name"
	l.text = str(CharacterData.GENDER_NAMES[gender])
	l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	l.offset_top = -CARD_LABEL
	l.offset_bottom = -4.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", DARK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(l)
	return card


## El elegido va a plena luz con su marco; los otros, apagados y sin marco.
func _paint_gender_card(card: Control, chosen: bool) -> void:
	card.get_node("Frame").visible = chosen
	card.get_node("Pic").modulate = Color.WHITE if chosen \
			else Color(1, 1, 1, 0.45)
	card.get_node("Name").add_theme_color_override("font_color",
		DARK if chosen else FADED)


# ------------------------------------------------------------- GRÁFICOS

func _build_graphics(box: VBoxContainer) -> void:
	_header(box, "Calidad general")
	var preset_buttons: Dictionary = {}
	var custom_rows: VBoxContainer = null

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)

	var repaint := func() -> void:
		for id in preset_buttons:
			preset_buttons[id].modulate = Color.WHITE \
					if id == str(draft_graphics["preset"]) else Color(0.62, 0.58, 0.52)
		if custom_rows != null:
			# Los ajustes sueltos solo se tocan en "personalizado"; en los
			# bloques se ven, apagados, para saber qué trae cada uno.
			custom_rows.modulate = Color.WHITE \
					if str(draft_graphics["preset"]) == "custom" else Color(1, 1, 1, 0.55)
		_refresh_apply()

	for id in GameState.PRESET_ORDER:
		var b := Button.new()
		b.text = str(GameState.PRESET_NAMES[id])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 74)
		PrepBoard.skin_button(b)
		PrepBoard.add_press_feedback(b)
		b.add_theme_font_size_override("font_size", 23)
		b.pressed.connect(func() -> void:
			draft_graphics["preset"] = id
			var p: Dictionary = GameState.GRAPHICS_PRESETS.get(id, {})
			for k in p:
				draft_graphics[k] = p[k]
			_show_graphics_values()
			repaint.call())
		grid.add_child(b)
		preset_buttons[id] = b

	custom_rows = VBoxContainer.new()
	custom_rows.add_theme_constant_override("separation", 8)
	box.add_child(custom_rows)
	_header(custom_rows, "A medida")
	_choice_row(custom_rows, "Resolución", GameState.QUALITY_NAMES,
		int(draft_graphics["quality"]),
		func(i: int) -> void: _set_custom("quality", i, repaint))
	_choice_row(custom_rows, "Fotogramas", GameState.FPS_CHOICES.map(
			func(f: int) -> String: return "%d fps" % f),
		GameState.FPS_CHOICES.find(int(draft_graphics["fps"])),
		func(i: int) -> void:
			_set_custom("fps", GameState.FPS_CHOICES[i], repaint))
	_toggle_row(custom_rows, "Sombras", "shadows", repaint)
	_toggle_row(custom_rows, "Animaciones", "anim", repaint)

	apply_graphics_btn = _apply_button(box, func() -> void:
		if str(draft_graphics["preset"]) == "custom":
			for k in ["quality", "fps", "shadows", "anim"]:
				GameState.settings[k] = draft_graphics[k]
			GameState.settings["preset"] = "custom"
			GameState.apply_graphics()
		else:
			GameState.apply_preset(str(draft_graphics["preset"]))
		GameState.save_game()
		Engine.max_fps = GameState.fps_for(false)
		_refresh_apply()
		_flash("Gráficos aplicados"))
	repaint.call()


## Tocar un ajuste suelto pasa el bloque a "personalizado": si no, el cartel
## diría "Alta" con la resolución a la mitad.
func _set_custom(key: String, value: Variant, repaint: Callable) -> void:
	draft_graphics[key] = value
	draft_graphics["preset"] = "custom"
	repaint.call()


## Refresca la pestaña de gráficos entera (al elegir un bloque cambian los
## cuatro ajustes de golpe y hay que repintar sus filas).
func _show_graphics_values() -> void:
	var keep := draft_graphics.duplicate()
	for c in content.get_children():
		c.queue_free()
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 14)
	content.add_child(box)
	draft_graphics = keep
	_build_graphics(box)


# ------------------------------------------------------------- PROGRESO

func _build_progress(box: VBoxContainer) -> void:
	_header(box, "Tiempo de juego")
	var time_row := HBoxContainer.new()
	time_row.custom_minimum_size = Vector2(0, 90)
	time_row.add_child(_row_label("Horas jugadas"))
	var t := Label.new()
	t.text = GameState.play_time_text()
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", DARK)
	time_row.add_child(t)
	box.add_child(time_row)
	_note(box, "Solo cuenta el tiempo dentro de una partida (aventura y "
		+ "arcade); los menús no suman.")

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 20)
	box.add_child(pad)

	_header(box, "Borrar progreso")
	_note(box, "Se pierden el dinero, las recetas, las estrellas, la despensa "
		+ "y los logros. El perfil y los gráficos se conservan.")
	var wipe := Button.new()
	wipe.text = "Borrar progreso"
	wipe.custom_minimum_size = Vector2(0, 78)
	PrepBoard.skin_button(wipe)
	PrepBoard.add_press_feedback(wipe)
	wipe.add_theme_font_size_override("font_size", 27)
	wipe.modulate = Color(1.0, 0.72, 0.66)
	wipe.pressed.connect(_ask_wipe)
	box.add_child(wipe)


# ------------------------------------------------------ borrado en dos pasos

## Primero se pregunta; después hay que MANTENER pulsado cinco segundos. Dos
## pasos porque esto no tiene vuelta atrás.
func _ask_wipe() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	overlay.create_tween().tween_property(overlay, "color:a", 0.62, 0.2)

	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -310.0
	panel.offset_right = 310.0
	panel.offset_top = -210.0
	panel.offset_bottom = 210.0
	overlay.add_child(panel)
	panel.add_child(PrepBoard.make_nine_patch("res://assets/ui/panel.png", 40))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 52.0
	vb.offset_top = 44.0
	vb.offset_right = -52.0
	vb.offset_bottom = -44.0
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)
	var msg := Label.new()
	msg.text = "¿Echar el progreso por la borda?\n\nNo hay vuelta atrás."
	msg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 25)
	msg.add_theme_color_override("font_color", DARK)
	vb.add_child(msg)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 18)
	vb.add_child(btns)
	var yes := Button.new()
	yes.text = "Sí, borrar"
	yes.custom_minimum_size = Vector2(210, 68)
	PrepBoard.skin_button(yes)
	PrepBoard.add_press_feedback(yes)
	yes.add_theme_font_size_override("font_size", 25)
	yes.modulate = Color(1.0, 0.72, 0.66)
	yes.pressed.connect(func() -> void:
		overlay.queue_free()
		_hold_to_wipe())
	btns.add_child(yes)
	var no := Button.new()
	no.text = "Cancelar"
	no.custom_minimum_size = Vector2(210, 68)
	PrepBoard.skin_button(no)
	PrepBoard.add_press_feedback(no)
	no.add_theme_font_size_override("font_size", 25)
	no.pressed.connect(overlay.queue_free)
	btns.add_child(no)


## Segundo paso: el botón solo borra si se mantiene pulsado hasta que la barra
## roja se llena; al soltar antes, la barra se vacía y no pasa nada.
func _hold_to_wipe() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	overlay.create_tween().tween_property(overlay, "color:a", 0.7, 0.2)

	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -310.0
	panel.offset_right = 310.0
	panel.offset_top = -220.0
	panel.offset_bottom = 220.0
	overlay.add_child(panel)
	panel.add_child(PrepBoard.make_nine_patch("res://assets/ui/panel.png", 40))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 52.0
	vb.offset_top = 44.0
	vb.offset_right = -52.0
	vb.offset_bottom = -44.0
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)
	var msg := Label.new()
	msg.text = "Mantén pulsado 5 segundos\npara borrarlo todo"
	msg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 26)
	msg.add_theme_color_override("font_color", DARK)
	vb.add_child(msg)

	var hold := Button.new()
	hold.text = "Mantén pulsado"
	hold.custom_minimum_size = Vector2(0, 86)
	PrepBoard.skin_button(hold)
	hold.add_theme_font_size_override("font_size", 26)
	hold.modulate = Color(1.0, 0.66, 0.58)
	vb.add_child(hold)

	wipe_bar = ProgressBar.new()
	wipe_bar.custom_minimum_size = Vector2(0, 34)
	wipe_bar.max_value = 100.0
	wipe_bar.value = 0.0
	wipe_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.22, 0.12, 0.08, 0.85)
	bg.set_corner_radius_all(10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.86, 0.16, 0.12)
	fill.set_corner_radius_all(10)
	wipe_bar.add_theme_stylebox_override("background", bg)
	wipe_bar.add_theme_stylebox_override("fill", fill)
	vb.add_child(wipe_bar)

	var cancel := Button.new()
	cancel.text = "Cancelar"
	cancel.custom_minimum_size = Vector2(0, 62)
	PrepBoard.skin_button(cancel)
	PrepBoard.add_press_feedback(cancel)
	cancel.add_theme_font_size_override("font_size", 24)
	cancel.pressed.connect(func() -> void:
		wipe_holding = false
		wipe_bar = null
		overlay.queue_free())
	vb.add_child(cancel)

	wipe_time = 0.0
	hold.button_down.connect(func() -> void:
		wipe_holding = true)
	hold.button_up.connect(func() -> void:
		# Al soltar antes de tiempo la barra se vacía: hay que empezar de nuevo.
		wipe_holding = false
		wipe_time = 0.0
		if wipe_bar != null:
			wipe_bar.value = 0.0)


## Se borra y el juego ARRANCA DE CERO: se vuelve al menú con un fundido, que
## es lo más parecido a reiniciar sin cerrar la aplicación.
func _do_wipe() -> void:
	GameState.reset_progress()
	wipe_bar = null
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(veil)
	var l := Label.new()
	l.text = "Progreso borrado"
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 36)
	l.add_theme_color_override("font_color", Color(1, 0.93, 0.6))
	l.modulate.a = 0.0
	ui.add_child(l)
	var tw := create_tween()
	tw.tween_property(veil, "color:a", 1.0, 0.5)
	tw.parallel().tween_property(l, "modulate:a", 1.0, 0.5)
	tw.tween_interval(0.9)
	tw.tween_callback(func() -> void:
		GameState.fade_to_scene("res://scenes/main_menu.tscn", 0.0, 0.5))


# ------------------------------------------------------------- filas sueltas

func _header(box: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", DARK)
	l.custom_minimum_size = Vector2(0, 44)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	box.add_child(l)


func _note(box: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", Color(0.42, 0.31, 0.18))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)


func _row_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 25)
	l.add_theme_color_override("font_color", DARK)
	return l


## Fila de elección: ◄ valor ►. En móvil recorrer pocas opciones en bucle es
## más cómodo que una lista desplegable.
func _choice_row(box: Control, label: String, names: Array, index: int,
		apply: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 66)
	row.add_child(_row_label(label))
	# El índice vive en un diccionario: las lambdas de GDScript capturan las
	# variables locales POR VALOR y un entero suelto no se dejaría cambiar.
	var state := { "i": maxi(index, 0) }
	var value := Label.new()
	value.custom_minimum_size = Vector2(170, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 24)
	value.add_theme_color_override("font_color", DARK)
	value.text = str(names[state["i"]])
	for dir in [-1, 1]:
		# La flecha de madera del recetario, no un carácter en un tablón: los
		# ◄ ► de la fuente salían descolocados y diminutos en el móvil.
		var b := PrepBoard.make_arrow("<" if dir < 0 else ">", 62.0)
		b.pressed.connect(func() -> void:
			state["i"] = wrapi(int(state["i"]) + dir, 0, names.size())
			value.text = str(names[state["i"]])
			apply.call(int(state["i"])))
		row.add_child(b)
		if dir < 0:
			row.add_child(value)
	box.add_child(row)


## Interruptor sí/no.
func _toggle_row(box: Control, label: String, key: String,
		repaint: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 66)
	row.add_child(_row_label(label))
	var b := Button.new()
	b.custom_minimum_size = Vector2(170, 58)
	PrepBoard.skin_button(b)
	PrepBoard.add_press_feedback(b)
	b.add_theme_font_size_override("font_size", 24)
	var paint := func() -> void:
		var on := bool(draft_graphics[key])
		b.text = "Sí" if on else "No"
	paint.call()
	b.pressed.connect(func() -> void:
		_set_custom(key, not bool(draft_graphics[key]), repaint)
		paint.call())
	row.add_child(b)
	box.add_child(row)


## Botón "Aplicar cambios": apagado mientras no haya nada que aplicar.
func _apply_button(box: Control, action: Callable) -> Button:
	var pad := Control.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(pad)
	var b := Button.new()
	b.text = "Aplicar cambios"
	b.custom_minimum_size = Vector2(0, 80)
	PrepBoard.skin_button(b)
	PrepBoard.add_press_feedback(b)
	b.add_theme_font_size_override("font_size", 27)
	b.pressed.connect(action)
	box.add_child(b)
	return b


## Enciende o apaga los dos botones de aplicar según si queda algo pendiente.
func _refresh_apply() -> void:
	if apply_profile != null and is_instance_valid(apply_profile):
		var dirty := draft_name.strip_edges() != GameState.player_name \
				or draft_gender != GameState.player_gender
		apply_profile.disabled = not dirty
		apply_profile.modulate = Color.WHITE if dirty else Color(0.68, 0.64, 0.58)
	if apply_graphics_btn != null and is_instance_valid(apply_graphics_btn):
		var dirty2 := false
		for k in ["quality", "fps", "shadows", "anim"]:
			if draft_graphics[k] != GameState.get_setting(k):
				dirty2 = true
		apply_graphics_btn.disabled = not dirty2
		apply_graphics_btn.modulate = Color.WHITE if dirty2 \
				else Color(0.68, 0.64, 0.58)


## Aviso momentáneo en el centro de la pantalla.
func _flash(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.offset_left = -260.0
	l.offset_right = 260.0
	l.offset_top = -40.0
	l.offset_bottom = 40.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Color(1, 0.93, 0.6))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 10)
	ui.add_child(l)
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
