extends Node3D
## OPCIONES, en tres pestañas:
##
## - PERFIL: el CARTEL DE RECOMPENSA del jugador (`wanted_poster.gd`), el mismo
##   de la bienvenida de David. Aquí se cambian personaje, mano y título; el
##   nombre NO, que se pone una sola vez. El personaje decide qué modelo 3D sale
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
var current_tab := "graficos"
var backdrop: Node3D = null
var _t := 0.0

# --- Cambios pendientes de aplicar (no tocan GameState hasta el botón) ---
var draft_graphics: Dictionary = {}
var apply_graphics_btn: Button = null

# --- Borrado del progreso: barra que se llena mientras se mantiene pulsado ---
var wipe_bar: ProgressBar = null
var wipe_holding := false
var wipe_time := 0.0


func _ready() -> void:
	# Las pantallas de casa (inventario, opciones, logros, maestrías,
	# bonificadores y perfil) siguen con el tema del menú: se entra y se sale
	# de ellas todo el rato y cortar la música en cada una sería un tajo.
	Audio.musica("menu")
	Engine.max_fps = GameState.fps_for(false)
	backdrop = SceneBackdrop.build(self, "", 17.0, 40.0, 6.0)
	_reset_drafts()
	_setup_ui()
	_show_tab(current_tab)
	GameState.take_transition()


func _reset_drafts() -> void:
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
	var title := PrepBoard.make_title("Opciones")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	# CUATRO tablones en 720 px: los rótulos van cortos y a cuerpo 22, que es lo
	# que deja el marco dorado del botón sin comerse las letras.
	# El PERFIL ya no es una pestaña: es su propia pantalla (profile_screen,
	# botón "Perfil" del submenú del menú principal).
	#
	# SONIDO entra como CUARTA pestaña y no metido en Gráficos: allí no cabía
	# —los cuatro bloques de calidad más las cuatro filas a medida y el botón
	# de aplicar ya llenan la hoja— y además no es lo mismo. Los cuatro
	# rótulos siguen siendo cortos, así que se quedan a cuerpo 26.
	for def in [["graficos", "Gráficos"], ["sonido", "Sonido"],
			["guia", "Guía"], ["progreso", "Progreso"]]:
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
	sheet.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))

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
		"graficos":
			_build_graphics(box)
		"sonido":
			_build_sound(box)
		"guia":
			_build_guide(box)
		"progreso":
			_build_progress(box)


# --------------------------------------------------------------- GUÍA

## Manual del juego, por secciones PLEGABLES: la lista entera de un tirón son
## varias pantallas de scroll y no se encuentra nada. Se ve el índice completo y
## se abre solo lo que interesa; al abrir una se cierra la anterior, para no
## acabar con un muro de texto otra vez.
##
## El texto vive en `guide_data.gd`.
var _guia_abierta := -1


func _build_guide(box: VBoxContainer) -> void:
	_note(box, "Todo lo que hay que saber para cocinar en alta mar. Toca un "
		+ "apartado para abrirlo.")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	TouchScroll.attach(scroll)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 10)
	scroll.add_child(lista)
	_guia_abierta = -1
	for i in GuideData.SECTIONS.size():
		_guide_section(lista, int(i))


func _guide_section(lista: VBoxContainer, idx: int) -> void:
	var sec: Dictionary = GuideData.SECTIONS[idx]
	var caja := VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_theme_constant_override("separation", 6)
	lista.add_child(caja)

	# Cabecera: tablón de madera con el icono de la mecánica y su nombre.
	var cab := Button.new()
	cab.text = "   " + str(sec["title"])
	cab.alignment = HORIZONTAL_ALIGNMENT_LEFT
	cab.custom_minimum_size = Vector2(0, 66)
	PrepBoard.skin_button(cab)
	cab.add_theme_font_size_override("font_size", 25)
	# Hueco a la izquierda para el icono, que va montado dentro del botón.
	var sb: StyleBox = cab.get_theme_stylebox("normal")
	if sb != null:
		var pad: StyleBox = sb.duplicate()
		pad.content_margin_left = 74.0
		for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
			cab.add_theme_stylebox_override(estado, pad)
	var ruta := str(sec.get("icon", ""))
	if ruta != "" and ResourceLoader.exists(ruta):
		var ic := TextureRect.new()
		ic.texture = load(ruta)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		ic.size = Vector2(46, 46)
		ic.position = Vector2(18, -23)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cab.add_child(ic)
	caja.add_child(cab)

	# Cuerpo: oculto hasta que se toca la cabecera.
	var cuerpo := RichTextLabel.new()
	cuerpo.bbcode_enabled = true
	cuerpo.fit_content = true
	cuerpo.scroll_active = false
	cuerpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cuerpo.text = DialogueBox.format_keywords(str(sec["body"]))
	cuerpo.add_theme_font_size_override("normal_font_size", 21)
	cuerpo.add_theme_font_size_override("bold_font_size", 21)
	cuerpo.add_theme_color_override("default_color", Color(0.34, 0.24, 0.13))
	cuerpo.add_theme_constant_override("line_separation", 4)
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		cuerpo.add_theme_font_override("bold_font", negrita)
	cuerpo.visible = false
	caja.add_child(cuerpo)

	cab.pressed.connect(func() -> void: _toggle_guide(idx, cuerpo))


## Abre una sección y cierra la que estuviera abierta.
func _toggle_guide(idx: int, cuerpo: RichTextLabel) -> void:
	var abrir := not cuerpo.visible
	for c in _guide_bodies():
		c.visible = false
	cuerpo.visible = abrir
	_guia_abierta = idx if abrir else -1


func _guide_bodies() -> Array:
	var out: Array = []
	if content == null:
		return out
	for caja in content.get_children():
		for hijo in caja.get_children():
			if not (hijo is ScrollContainer):
				continue
			for lista in hijo.get_children():
				for sec in lista.get_children():
					for n in sec.get_children():
						if n is RichTextLabel:
							out.append(n)
	return out


# -------------------------------------------------------------- PERFIL

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


# --------------------------------------------------------------- SONIDO

## Los tres volúmenes del juego. Se aplican EN EL ACTO al soltar la barra (no
## hay botón de "aplicar" como en gráficos) porque el sonido se juzga oyéndolo:
## un volumen que hay que confirmar para escuchar se ajusta a ciegas.
##
## Y cada barra suena AL MOVERLA con algo de SU bus —la música con la música,
## los efectos con un clic, las voces con David—, que es la única forma de
## saber dónde la estás dejando.
const VOL_FILAS := [
	["vol_musica", "Música", "Los temas de cada sitio."],
	["vol_efectos", "Efectos", "La cocina, la barra y la interfaz."],
	["vol_voces", "Voces", "Lo que dicen los personajes al hablar."],
]


func _build_sound(box: VBoxContainer) -> void:
	_header(box, "Volumen")
	for fila in VOL_FILAS:
		_slider_row(box, str(fila[0]), str(fila[1]), str(fila[2]))
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 16)
	box.add_child(pad)
	_note(box, "Con la barra a cero el canal se calla del todo.")


func _slider_row(box: Control, clave: String, titulo: String,
		nota: String) -> void:
	var fila := VBoxContainer.new()
	fila.add_theme_constant_override("separation", 2)
	box.add_child(fila)
	var arriba := HBoxContainer.new()
	arriba.custom_minimum_size = Vector2(0, 46)
	arriba.add_child(_row_label(titulo))
	var cifra := Label.new()
	cifra.custom_minimum_size = Vector2(84, 0)
	cifra.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cifra.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cifra.add_theme_font_size_override("font_size", 25)
	cifra.add_theme_color_override("font_color", DARK)
	arriba.add_child(cifra)
	fila.add_child(arriba)

	var barra := HSlider.new()
	barra.min_value = 0.0
	barra.max_value = 1.0
	barra.step = 0.05
	barra.value = float(GameState.get_setting(clave))
	barra.custom_minimum_size = Vector2(0, 44)
	# El canal de madera y el relleno del resto del juego, para que no parezca
	# un control del tema por defecto de Godot en mitad del pergamino.
	barra.add_theme_stylebox_override("slider",
		PrepBoard.make_bar_box(PrepBoard.BAR_BG_TEX))
	barra.add_theme_stylebox_override("grabber_area",
		PrepBoard.make_bar_box(PrepBoard.BAR_FILL_TEX, Color(0.36, 0.88, 0.38)))
	fila.add_child(barra)
	_note(fila, nota)

	cifra.text = "%d%%" % int(round(barra.value * 100.0))
	barra.value_changed.connect(func(v: float) -> void:
		cifra.text = "%d%%" % int(round(v * 100.0))
		# Se guarda al vuelo: `set_setting` aplica y guarda, y aplicar es lo
		# que hace que se OIGA mientras se arrastra.
		GameState.set_setting(clave, v)
		_muestra_de(clave))


## Un pellizco del canal que se está tocando, para oír dónde queda la barra.
## Con reposo: arrastrando el dedo llegan decenas de cambios por segundo y sin
## el freno sonaría una ametralladora (los efectos ya lo tienen por dentro,
## pero la música y la voz no).
var _ultima_muestra := 0.0


func _muestra_de(clave: String) -> void:
	if clave == "vol_efectos":
		Audio.sfx("click")
		return
	var ahora := float(Time.get_ticks_msec()) / 1000.0
	if ahora - _ultima_muestra < 0.45:
		return
	_ultima_muestra = ahora
	if clave == "vol_voces":
		Audio.voz("david", "hablando")


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

	_header(box, "Tutorial")
	_note(box, "Vuelve a jugar la clase de David Jones. No toca el progreso: "
		+ "ni el dinero, ni las recetas, ni las estrellas.")
	var again := Button.new()
	again.text = "Repetir tutorial"
	again.custom_minimum_size = Vector2(0, 78)
	PrepBoard.skin_button(again)
	again.add_theme_font_size_override("font_size", 28)
	again.pressed.connect(_on_repeat_tutorial)
	box.add_child(again)

	var pad2 := Control.new()
	pad2.custom_minimum_size = Vector2(0, 20)
	box.add_child(pad2)

	_header(box, "Modo debug")
	_note(box, "Herramienta de pruebas: toca el progreso guardado a mano. "
		+ "Pide contraseña.")
	var dbg := Button.new()
	dbg.text = "Modo debug"
	dbg.custom_minimum_size = Vector2(0, 78)
	PrepBoard.skin_button(dbg)
	PrepBoard.add_press_feedback(dbg)
	dbg.add_theme_font_size_override("font_size", 28)
	dbg.pressed.connect(_ask_debug_password)
	box.add_child(dbg)

	var pad3 := Control.new()
	pad3.custom_minimum_size = Vector2(0, 20)
	box.add_child(pad3)

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
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))

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
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))

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


# --------------------------------------------------------------- MODO DEBUG

## No es seguridad —está escrita en el propio código—, es un PESTILLO:
## que nadie entre aquí sin querer y se encuentre el progreso cambiado.
const DEBUG_PASS := "sushi123"

## id -> { campo: LineEdit, antes: int }. Se rellena al abrir el panel.
var debug_fields: Dictionary = {}


## Paño oscuro + pergamino centrado, que es el patrón de los otros dos
## carteles de esta pantalla. Devuelve [overlay, caja] para lo de cada uno.
func _modal(alto: float, ancho := 620.0) -> Array:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	overlay.create_tween().tween_property(overlay, "color:a", 0.68, 0.2)

	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -ancho * 0.5
	panel.offset_right = ancho * 0.5
	panel.offset_top = -alto * 0.5
	panel.offset_bottom = alto * 0.5
	overlay.add_child(panel)
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 50.0
	vb.offset_top = 42.0
	vb.offset_right = -50.0
	vb.offset_bottom = -42.0
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	return [overlay, vb]


func _ask_debug_password() -> void:
	var m := _modal(370.0)
	var overlay: ColorRect = m[0]
	var vb: VBoxContainer = m[1]

	var msg := Label.new()
	msg.text = "Modo debug"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 30)
	msg.add_theme_color_override("font_color", DARK)
	vb.add_child(msg)

	var aviso := Label.new()
	aviso.text = "Contraseña:"
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.add_theme_font_size_override("font_size", 22)
	aviso.add_theme_color_override("font_color", FADED)
	vb.add_child(aviso)

	var edit := LineEdit.new()
	edit.secret = true
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.custom_minimum_size = Vector2(0, 62)
	edit.add_theme_font_size_override("font_size", 28)
	# El teclado del móvil no sale solo al tocar un LineEdit: hace falta esto.
	PrepBoard.enable_mobile_keyboard(edit)
	vb.add_child(edit)

	var error := Label.new()
	error.text = ""
	error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error.add_theme_font_size_override("font_size", 21)
	error.add_theme_color_override("font_color", Color(0.72, 0.16, 0.12))
	vb.add_child(error)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 18)
	vb.add_child(btns)

	var entrar := func() -> void:
		if edit.text.strip_edges() == DEBUG_PASS:
			overlay.queue_free()
			_open_debug()
		else:
			error.text = "Contraseña incorrecta"
			edit.text = ""

	var ok := Button.new()
	ok.text = "Entrar"
	ok.custom_minimum_size = Vector2(200, 66)
	PrepBoard.skin_button(ok)
	PrepBoard.add_press_feedback(ok)
	ok.add_theme_font_size_override("font_size", 25)
	ok.pressed.connect(entrar)
	btns.add_child(ok)

	var no := Button.new()
	no.text = "Cancelar"
	no.custom_minimum_size = Vector2(200, 66)
	PrepBoard.skin_button(no)
	PrepBoard.add_press_feedback(no)
	no.add_theme_font_size_override("font_size", 25)
	no.pressed.connect(overlay.queue_free)
	btns.add_child(no)

	# Con INTRO también entra: en escritorio se teclea y se pulsa intro.
	edit.text_submitted.connect(func(_t: String) -> void: entrar.call())


func _open_debug() -> void:
	var m := _modal(720.0, 660.0)
	var overlay: ColorRect = m[0]
	var vb: VBoxContainer = m[1]
	debug_fields = {}

	var titulo := Label.new()
	titulo.text = "Modo debug"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 30)
	titulo.add_theme_color_override("font_color", DARK)
	vb.add_child(titulo)

	_debug_row(vb, "money", "Dinero", GameState.money, 0)
	_debug_row(vb, "collectibles", "Coleccionables",
		GameState.collectibles.size(), CollectibleData.ITEMS.size())
	_debug_row(vb, "chef_level", "Nivel de cocinero",
		GameState.chef_level, SkillData.MAX_LEVEL)
	_debug_row(vb, "fish", "Peces del álbum",
		FishData.caught_count(GameState.fish_album), FishData.FISH.size())
	_debug_row(vb, "ports", "Escenarios superados",
		GameState.debug_ports_beaten(), CampaignData.PORTS.size())

	var nota := Label.new()
	nota.text = ("El nivel de cocinero reparte sus puntos solo; bajarlo devuelve "
		+ "los ya gastados. Los escenarios se completan con 3 estrellas, con sus "
		+ "recetas y su despensa.")
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nota.add_theme_font_size_override("font_size", 19)
	nota.add_theme_color_override("font_color", FADED)
	vb.add_child(nota)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 18)
	vb.add_child(btns)

	var aplicar := Button.new()
	aplicar.text = "Aplicar"
	aplicar.custom_minimum_size = Vector2(230, 68)
	PrepBoard.skin_button(aplicar)
	PrepBoard.add_press_feedback(aplicar)
	aplicar.add_theme_font_size_override("font_size", 25)
	aplicar.pressed.connect(func() -> void:
		_apply_debug()
		overlay.queue_free())
	btns.add_child(aplicar)

	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.custom_minimum_size = Vector2(230, 68)
	PrepBoard.skin_button(cerrar)
	PrepBoard.add_press_feedback(cerrar)
	cerrar.add_theme_font_size_override("font_size", 25)
	cerrar.pressed.connect(func() -> void:
		debug_fields = {}
		overlay.queue_free())
	btns.add_child(cerrar)


## Una fila del panel: rótulo, campo con el valor de AHORA y el tope a la
## derecha. El tope se enseña porque estos números tienen catálogo (120
## coleccionables, 100 peces, 20 escenarios) y a ciegas se pasa uno.
func _debug_row(box: Control, id: String, label: String, valor: int,
		tope: int) -> void:
	var fila := HBoxContainer.new()
	fila.custom_minimum_size = Vector2(0, 66)
	fila.add_theme_constant_override("separation", 10)
	fila.add_child(_row_label(label))

	var edit := LineEdit.new()
	edit.text = str(valor)
	edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	edit.custom_minimum_size = Vector2(140, 56)
	edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	edit.add_theme_font_size_override("font_size", 26)
	PrepBoard.enable_mobile_keyboard(edit)
	fila.add_child(edit)

	var tope_l := Label.new()
	tope_l.text = ("/ %d" % tope) if tope > 0 else ""
	tope_l.custom_minimum_size = Vector2(78, 0)
	tope_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tope_l.add_theme_font_size_override("font_size", 21)
	tope_l.add_theme_color_override("font_color", FADED)
	fila.add_child(tope_l)

	box.add_child(fila)
	debug_fields[id] = { "campo": edit, "antes": valor }


## Solo viaja lo que se haya CAMBIADO de verdad: así tocar el dinero no
## rehace de paso los veinte escenarios ni le devuelve los puntos al chef.
func _apply_debug() -> void:
	var vals: Dictionary = {}
	for id in debug_fields:
		var d: Dictionary = debug_fields[id]
		var edit: LineEdit = d["campo"]
		var txt := edit.text.strip_edges()
		if not txt.is_valid_int():
			continue
		var n := int(txt)
		if n != int(d["antes"]):
			vals[id] = n
	debug_fields = {}
	if vals.is_empty():
		return
	GameState.debug_apply(vals)
	# La pestaña se repinta para que los valores de AHORA sean los de verdad.
	_show_tab(current_tab)


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
	# Un interruptor no suena como un botón: tiene dos sonidos, y cuál suena
	# dice si se acaba de encender o de apagar.
	b.set_meta("snd", "")
	b.pressed.connect(func() -> void:
		var nuevo := not bool(draft_graphics[key])
		Audio.sfx("on" if nuevo else "off")
		_set_custom(key, nuevo, repaint)
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


## Enciende o apaga el botón de aplicar de gráficos según si queda algo
## pendiente. (El del perfil se fue con su pantalla: ver profile_screen.)
func _refresh_apply() -> void:
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


## Repite el tutorial: va DIRECTO al nivel guiado (sin la bienvenida de nombre
## y género) y no toca el progreso.
func _on_repeat_tutorial() -> void:
	GameState.mode = "tutorial"
	GameState.current_port = ""
	var recs: Array[String] = []
	for r in CampaignData.INITIAL_RECIPES:
		recs.append(r)
	GameState.selected_recipes = recs
	GameState.selected_perks = []
	GameState.fade_to_scene("res://scenes/level3d.tscn", 0.35, 0.45)
