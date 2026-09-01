extends Node3D
## LA PANTALLA DE MAPAS DEL TESORO: las misiones secundarias (`TreasureData`).
##
## Se llega desde el submenu del MAPA de aventura. Todo ocurre SOBRE UNA MESA
## de madera (pedido por el usuario), no sobre el pergamino del resto del
## juego: esto no es un menu mas, es el camarote donde se despliegan los mapas.
##
## Tres estados en la misma pantalla:
##   1. LA MESA con los mapas ABIERTOS en rejilla, cada uno con su mision, mas
##      la pila de mapas SIN ABRIR si quedan.
##   2. Al tocar un rollo sin abrir, se ABRE: descubre la siguiente mision del
##      catalogo (van EN ORDEN, asi que la dificultad sube sola).
##   3. Al tocar un mapa abierto, se despliega GRANDE con su objetivo, su
##      recompensa y el boton de ARMARLO — solo hay uno armado a la vez, que
##      es lo que hace que cumplir uno se sienta ganado y no de carambola.

const PrepBoard := preload("res://scripts/prep_board.gd")
const MESA := "res://assets/ui/mesa_madera.png"
const ROLLO := "res://assets/ui/mapa_rollo.png"

## Rejilla de la mesa.
const COLS := 3
## La tarjeta va ALTA: el nombre de un mapa ocupa dos renglones y con 150 de
## alto se salia por el canto de arriba.
const CARTA := Vector2(196.0, 186.0)
const HUECO := Vector2(16.0, 18.0)

var ui: CanvasLayer = null
var raiz: Control = null
var lista: VBoxContainer = null
var scroll: ScrollContainer = null


func _ready() -> void:
	Audio.musica("menu")
	Engine.max_fps = GameState.fps_for(false)
	SceneBackdrop.build(self, "mar", 13.0, 232.0, 5.0)
	_montar()
	GameState.take_transition()


func _montar() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	raiz = Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(raiz)

	# LA MESA: la textura en mosaico, no estirada — estirada, la veta se
	# convierte en unas rayas larguisimas que cantan.
	var mesa := TextureRect.new()
	mesa.texture = load(MESA)
	mesa.stretch_mode = TextureRect.STRETCH_TILE
	mesa.set_anchors_preset(Control.PRESET_FULL_RECT)
	mesa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(mesa)
	# Un velo oscuro por los cantos, para que la mesa no compita con lo que
	# se apoya en ella.
	var velo := ColorRect.new()
	velo.color = Color(0.06, 0.04, 0.02, 0.30)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(velo)

	var atras := PrepBoard.make_back_button()
	atras.position = Vector2(24.0, 24.0 + GameState.safe_top())
	atras.pressed.connect(_volver)
	raiz.add_child(atras)

	var titulo := PrepBoard.make_title("Mapas del tesoro")
	titulo.position = Vector2(160.0, 20.0 + GameState.safe_top())
	titulo.size = Vector2(400.0, 74.0)
	raiz.add_child(titulo)

	scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 128.0 + GameState.safe_top()
	scroll.offset_bottom = -24.0 - GameState.safe_bottom()
	scroll.offset_left = 20.0
	scroll.offset_right = -20.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	raiz.add_child(scroll)
	TouchScroll.attach(scroll)
	lista = VBoxContainer.new()
	lista.add_theme_constant_override("separation", 18)
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)
	_rellenar()


## Rehace el contenido. Se llama al entrar y cada vez que algo cambia (abrir
## un mapa, armarlo, cobrarlo), que es mas simple y mas seguro que ir tocando
## las tarjetas sueltas.
func _rellenar() -> void:
	for h in lista.get_children():
		h.queue_free()

	# --- LA PILA DE MAPAS SIN ABRIR
	if GameState.treasure_maps > 0:
		lista.add_child(_rotulo("Sin abrir (%d)" % GameState.treasure_maps))
		var fila := HFlowContainer.new()
		fila.add_theme_constant_override("h_separation", int(HUECO.x))
		fila.add_theme_constant_override("v_separation", int(HUECO.y))
		lista.add_child(fila)
		# No se dibuja uno por mapa: con veinte encima la mesa seria un
		# almacen. Se enseñan hasta tres rollos y el numero lo dice el rotulo.
		for i in mini(3, GameState.treasure_maps):
			fila.add_child(_rollo_cerrado())

	# --- LOS ABIERTOS
	var abiertos: Array = GameState.treasure_open
	if abiertos.is_empty() and GameState.treasure_maps <= 0:
		lista.add_child(_rotulo("Todavía no tienes ningún mapa"))
		var p := _parrafo("Los encontrarás en los cofres de la **pesca**, en "
			+ "el **bonus diario** y en manos de algún cliente. Cada uno trae "
			+ "una misión y su recompensa.")
		lista.add_child(p)
		return
	if not abiertos.is_empty():
		lista.add_child(_rotulo("Tus mapas (%d/%d)"
			% [abiertos.size(), TreasureData.total()]))
		var rejilla := HFlowContainer.new()
		rejilla.add_theme_constant_override("h_separation", int(HUECO.x))
		rejilla.add_theme_constant_override("v_separation", int(HUECO.y))
		lista.add_child(rejilla)
		for id in abiertos:
			rejilla.add_child(_carta(TreasureData.por_id(str(id))))


func _rotulo(txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(1, 0.94, 0.80))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	return l


func _parrafo(txt: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.custom_minimum_size = Vector2(0.0, 90.0)
	r.text = DialogueBox.format_keywords(txt)
	r.add_theme_font_size_override("normal_font_size", 20)
	r.add_theme_color_override("default_color", Color(0.94, 0.89, 0.78))
	r.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	r.add_theme_constant_override("outline_size", 6)
	return r


## Un rollo sin abrir: se toca y se abre.
func _rollo_cerrado() -> Button:
	var b := Button.new()
	b.custom_minimum_size = CARTA
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var ic := TextureRect.new()
	ic.texture = load(ROLLO)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	var l := Label.new()
	l.text = "¡Ábrelo!"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	l.offset_top = -30.0
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(1, 0.92, 0.68))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	PrepBoard.add_press_feedback(b, 0.9)
	b.pressed.connect(_abrir_uno)
	return b


## Una tarjeta de mapa abierto: nombre, objetivo corto y estado.
func _carta(m: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = CARTA
	var hecho := str(m.get("id", "")) in GameState.treasure_done
	var armado := str(m.get("id", "")) == GameState.treasure_active
	PrepBoard.skin_button(b)
	b.text = ""
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14.0
	v.offset_right = -14.0
	v.offset_top = 12.0
	v.offset_bottom = -12.0
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var n := Label.new()
	n.text = str(m.get("nombre", "?"))
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_font_size_override("font_size", 16)
	n.add_theme_color_override("font_color", Color(1, 0.94, 0.80))
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(n)
	# Y una linea con lo que PIDE, que es por lo que se elige un mapa. Va
	# recortada: la frase entera vive en la ficha, aqui solo tiene que
	# distinguir un mapa de otro de un vistazo.
	var o := Label.new()
	var frase := TreasureData.texto_objetivo(m).replace("**", "")
	o.text = frase if frase.length() <= 46 else frase.substr(0, 44) + "..."
	o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	o.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	o.size_flags_vertical = Control.SIZE_EXPAND_FILL
	o.add_theme_font_size_override("font_size", 13)
	o.add_theme_color_override("font_color", Color(0.90, 0.84, 0.72))
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(o)
	# LA MARCA en la propia carta: entre cincuenta rollos, es lo que deja
	# escoger "hoy me apetece uno fácil" sin abrir ninguno.
	var d := Label.new()
	d.text = TreasureData.dif_nombre(m).to_upper()
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.add_theme_font_size_override("font_size", 13)
	d.add_theme_color_override("font_color", TreasureData.dif_color(m))
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(d)
	var e := Label.new()
	e.text = "Cumplido" if hecho else ("EN CURSO" if armado else "Pendiente")
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	e.add_theme_font_size_override("font_size", 16)
	e.add_theme_color_override("font_color",
		Color(0.55, 0.95, 0.55) if hecho
		else (Color(1, 0.85, 0.35) if armado else Color(0.85, 0.80, 0.70)))
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(e)
	if hecho:
		b.modulate = Color(1, 1, 1, 0.62)
	b.pressed.connect(func() -> void: _abrir_ficha(m))
	return b


## Abre un mapa sin abrir y enseña la misión que traía dentro.
func _abrir_uno() -> void:
	var m := GameState.open_treasure_map()
	if m.is_empty():
		return
	_rellenar()
	_abrir_ficha(m, true)


## LA FICHA: el mapa desplegado, con su objetivo, su recompensa y el botón de
## armarlo. Es una ventana modal sobre la mesa.
func _abrir_ficha(m: Dictionary, recien := false) -> void:
	if m.is_empty():
		return
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 150
	var velo := Button.new()
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		velo.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	velo.modulate = Color(0, 0, 0, 0.55)
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.55)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(fondo)
	overlay.add_child(velo)
	velo.pressed.connect(overlay.queue_free)

	var panel := PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var tam := Vector2(600.0, 470.0)
	panel.offset_left = -tam.x * 0.5
	panel.offset_right = tam.x * 0.5
	panel.offset_top = -tam.y * 0.5
	panel.offset_bottom = tam.y * 0.5
	overlay.add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 56.0
	v.offset_right = -56.0
	v.offset_top = 46.0
	v.offset_bottom = -46.0
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var t := Label.new()
	t.text = str(m.get("nombre", "?"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color(0.42, 0.26, 0.10))
	v.add_child(t)
	if recien:
		var nuevo := Label.new()
		nuevo.text = "¡Mapa nuevo!"
		nuevo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nuevo.add_theme_font_size_override("font_size", 19)
		nuevo.add_theme_color_override("font_color", Color(0.70, 0.42, 0.12))
		v.add_child(nuevo)

	# LA MARCA, justo bajo el nombre y con SU color: es lo primero que hay que
	# saber de un mapa, porque decide a la vez lo que paga y lo que le hace a
	# la jornada. En la mesa, con muchos rollos abiertos, el color la distingue
	# antes que la palabra.
	var marca := Label.new()
	marca.text = TreasureData.dif_nombre(m).to_upper()
	marca.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marca.add_theme_font_size_override("font_size", 21)
	marca.add_theme_color_override("font_color", TreasureData.dif_color(m))
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		marca.add_theme_font_override("font", negrita)
	v.add_child(marca)

	v.add_child(_ficha_bloque("La misión", TreasureData.texto_objetivo(m)))
	# LO QUE EL MAPA LE HACE A LA JORNADA solo sale si hace algo: los fáciles
	# no tocan nada y un bloque vacío haría creer que sí.
	var contra := TreasureData.texto_mods(m)
	if contra != "":
		v.add_child(_ficha_bloque("La cocina en contra", contra))
	v.add_child(_ficha_bloque("El tesoro", TreasureData.texto_premio(m)))

	var hecho := str(m.get("id", "")) in GameState.treasure_done
	var armado := str(m.get("id", "")) == GameState.treasure_active
	var pie := CenterContainer.new()
	pie.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	v.add_child(pie)
	if hecho:
		var ya := Label.new()
		ya.text = "Tesoro recogido"
		ya.add_theme_font_size_override("font_size", 22)
		ya.add_theme_color_override("font_color", Color(0.32, 0.52, 0.24))
		pie.add_child(ya)
	else:
		var b := Button.new()
		b.custom_minimum_size = Vector2(300.0, 100.0)
		PrepBoard.skin_start_button(b, 0.0)
		b.text = "Guardar mapa" if armado else "¡Seguir este mapa!"
		b.add_theme_font_size_override("font_size", 27)
		b.pressed.connect(func() -> void:
			GameState.set_treasure_active("" if armado else str(m["id"]))
			overlay.queue_free()
			_rellenar())
		pie.add_child(b)
	Audio.ventana(overlay)
	raiz.add_child(overlay)


func _ficha_bloque(titulo: String, cuerpo: String) -> Control:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	var t := Label.new()
	t.text = titulo
	t.add_theme_font_size_override("font_size", 19)
	t.add_theme_color_override("font_color", Color(0.58, 0.42, 0.22))
	caja.add_child(t)
	# RichTextLabel y no Label: los textos traen palabras entre ** y
	# `format_keywords` devuelve BBCode (con un Label saldrian los asteriscos).
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.custom_minimum_size = Vector2(0.0, 76.0)
	r.text = DialogueBox.format_keywords(cuerpo)
	r.add_theme_font_size_override("normal_font_size", 21)
	r.add_theme_color_override("default_color", Color(0.30, 0.20, 0.10))
	caja.add_child(r)
	return caja


func _volver() -> void:
	GameState.transition = "mapa"
	GameState.fade_to_scene("res://scenes/main_menu.tscn", 0.35, 0.45)
