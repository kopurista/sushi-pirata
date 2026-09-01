extends Node3D
## BONIFICADORES: los potenciadores permanentes de `PerkData`, en pantalla
## propia (el botón "Bonificadores" del submenú del menú y del mapa).
##
## REDISEÑO del 1-9-2026 (pedido por el usuario: "nuevos gráficos y arte...
## un rediseño exhaustivo"). La pantalla habla el idioma de Maestrías —marcos
## por estado, el nivel en estrellas, ficha al tocar— pero con ARTE PROPIO:
##  · Cada bonificador es una PLACA de madera oscura de nogal con ribete de
##    latón (`carta_perk.png`), a lo ancho de la hoja: sobre la madera oscura
##    el texto va en CREMA, que es lo que hace a estas tarjetas leerse
##    distintas de una ficha de pergamino más.
##  · El icono vive en un MEDALLÓN de latón (aro de portillo,
##    `medallon_perk.png`) y el ESTADO lo dice el aro: gris sin ganar, latón
##    ganado, encendido en oro al nivel máximo.
##  · La cabecera lleva el recuento y una BARRA de niveles totales, como la
##    cabecera de Maestrías lleva la de experiencia.
##
## La usabilidad se conserva entera: los USOS (se ganan repitiendo la hazaña y
## se compra uno más con LINGOTES), los niveles (se compran con DOBLONES, con
## confirmación), y los no conseguidos en silueta con su condición — o con un
## "más adelante" si su compuerta de campaña sigue cerrada (`perk_gate_open`):
## enseñar la hazaña exacta de algo que aún no se puede ganar era una trampa.

const PrepBoard := preload("res://scripts/prep_board.gd")
const DARK := Color(0.26, 0.16, 0.08)
const FADED := Color(0.45, 0.34, 0.2)
## Texto sobre la MADERA OSCURA de la placa: crema y tostado, no los marrones
## del pergamino (sobre nogal no se leían).
const CREMA := Color(1.0, 0.95, 0.82)
const TOSTADO := Color(0.93, 0.83, 0.66)
const VERDE := Color(0.24, 0.52, 0.22)
const VERDE_CLARO := Color(0.62, 0.86, 0.5)
const ORO := Color(0.85, 0.66, 0.16)

## La placa de cada bonificador. El margen 9-slice (34) cubre el ribete de
## latón y los cuatro remaches de las esquinas, MEDIDO sobre el PNG a 440 de
## ancho; por debajo, el estirado partía un remache.
const CARTA_TEX := "res://assets/ui/carta_perk.png"
const CARTA_MARGIN := 34
## El aro de latón que enmarca el icono.
const MEDALLON_TEX := "res://assets/ui/medallon_perk.png"
## Lado del medallón en la tarjeta y en la ficha.
const MEDALLON := 132.0
const MEDALLON_FICHA := 150.0
## Tintes del ARO por estado. El de "máximo" va por encima de 1: `modulate`
## multiplica, así que ENCIENDE el latón hacia el oro en vez de teñirlo.
const ARO_BLOQUEADO := Color(0.58, 0.60, 0.66)
const ARO_MAX := Color(1.3, 1.08, 0.62)
## Alto de una tarjeta. Se CUENTA: nombre 30 + estrellas 26 + efecto 44 +
## botonera 93, con sus aires. El medallón (132) queda centrado en el resto.
const CARTA_ALTO := 248.0

var ui: CanvasLayer = null
var content: Control = null
var money_label: Label = null
var ingot_label: Label = null
var backdrop: Node3D = null
var _t := 0.0
## La cascada de entrada solo suena la primera vez: `_refresh` se llama
## también tras cada compra y ahí repetirla sería un mareo.
var _estreno := true
## Ficha abierta (para reabrirla al día tras una compra hecha desde ella).
var ficha_overlay: Control = null
var ficha_id := ""


func _ready() -> void:
	# Las pantallas de casa (inventario, opciones, logros, maestrías,
	# bonificadores y perfil) siguen con el tema del menú: se entra y se sale
	# de ellas todo el rato y cortar la música en cada una sería un tajo.
	Audio.musica("menu")
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
	bar.add_theme_constant_override("separation", 8)
	root.add_child(bar)
	var back := PrepBoard.make_back_button()
	back.pressed.connect(func() -> void:
		# VUELVE AL MAPA si se entró desde su submenú (el mismo patrón que la
		# tienda y las maestrías): allí es donde vive hoy su acceso.
		if GameState.perks_from != "":
			GameState.transition = GameState.perks_from
			GameState.perks_from = ""
		GameState.fade_to_scene("res://scenes/main_menu.tscn", 0.35, 0.45))
	bar.add_child(back)
	var title := PrepBoard.make_title("Bonificadores")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	# LAS DOS MONEDAS de la pantalla, a la vista: los NIVELES se compran con
	# doblones y los USOS con lingotes, así que las dos cifras tienen que
	# estar delante mientras se decide.
	var monedas := _chip_recurso("res://assets/ui/moneda.png")
	money_label = monedas.get_node("Valor")
	bar.add_child(monedas)
	var lingotes := _chip_recurso("res://assets/ui/ic_lingote.png")
	ingot_label = lingotes.get_node("Valor")
	bar.add_child(lingotes)

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


## Icono + cifra, compacto para la barra de arriba (con las dos monedas y el
## "Atrás", la cinta del título ya va justa de sitio).
func _chip_recurso(icono: String) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = load(icono)
	ic.custom_minimum_size = Vector2(36, 36)
	box.add_child(ic)
	var l := Label.new()
	l.name = "Valor"
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(1, 0.86, 0.4))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	box.add_child(l)
	return box


## (Re)pinta la pantalla entera. Tras una compra se vuelve a llamar: repintar
## de golpe es más simple que actualizar la tarjeta y aquí no hay animación que
## perder (la cascada de entrada solo corre en el estreno).
func _refresh() -> void:
	money_label.text = "%d" % GameState.money
	ingot_label.text = "%d" % GameState.ingots
	for c in content.get_children():
		c.queue_free()
	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 14)
	scroll.add_child(col)

	var i := 0
	for id in PerkData.ids():
		var carta := _build_perk_card(str(id))
		col.add_child(carta)
		if _estreno and GameState.animations_on():
			_entrada(carta, i)
		i += 1
	_estreno = false

	var pie := Label.new()
	pie.text = "Se eligen antes de zarpar y cada jornada gasta un uso."
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pie.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pie.add_theme_font_size_override("font_size", 18)
	pie.add_theme_color_override("font_color", FADED)
	col.add_child(pie)


## Las placas ENTRAN en cascada, como las tarjetas de Maestrías: cada una
## sube unos píxeles con su retardo. Solo en el estreno de la pantalla.
func _entrada(carta: Control, i: int) -> void:
	carta.modulate.a = 0.0
	var tw := carta.create_tween()
	tw.tween_interval(0.06 * i)
	tw.tween_property(carta, "modulate:a", 1.0, 0.28)


## EL MEDALLÓN: el aro de latón con el icono dentro. El ESTADO lo dice el aro
## — gris sin ganar, latón ganado, encendido en oro al máximo — y sin ganar el
## icono va además en SILUETA: la pantalla dice que existe, no cómo es.
func _medallon(id: String, lado: float) -> Control:
	var data := PerkData.get_perk(id)
	var known := GameState.is_perk_unlocked(id)
	var nivel := GameState.get_perk_level(id)
	var host := Control.new()
	host.custom_minimum_size = Vector2(lado, lado)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Al MÁXIMO, un resplandor suave por detrás del aro: es el mismo aviso que
	# el marco dorado de Maestrías, contado con luz en vez de con un panel.
	if known and nivel >= PerkData.MAX_LEVEL:
		var halo := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.85, 0.35, 0.35)
		sb.set_corner_radius_all(int(lado * 0.5))
		halo.add_theme_stylebox_override("panel", sb)
		halo.set_anchors_preset(Control.PRESET_FULL_RECT)
		halo.offset_left = -6.0
		halo.offset_top = -6.0
		halo.offset_right = 6.0
		halo.offset_bottom = 6.0
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(halo)
	# El icono va DEBAJO del aro en el árbol, así que el latón lo recorta por
	# el borde y el dibujo parece metido en el portillo, no pegado encima.
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = load(str(data.get("icon", "")))
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	var borde := lado * 0.20
	ic.offset_left = borde
	ic.offset_top = borde
	ic.offset_right = -borde
	ic.offset_bottom = -borde
	ic.modulate = Color.WHITE if known else Color(0.13, 0.11, 0.10, 0.9)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(ic)
	var aro := TextureRect.new()
	aro.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	aro.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	aro.texture = load(MEDALLON_TEX)
	aro.set_anchors_preset(Control.PRESET_FULL_RECT)
	if not known:
		aro.modulate = ARO_BLOQUEADO
	elif nivel >= PerkData.MAX_LEVEL:
		aro.modulate = ARO_MAX
	aro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(aro)
	return host


## UNA PLACA: medallón a la izquierda y, a su derecha, nombre, nivel en
## estrellas, lo que hace HOY y la botonera (usos + mejorar). Sin conseguir,
## la silueta y su condición — o un "más adelante" si la campaña todavía no lo
## ha presentado. Tocar la placa abre la ficha.
func _build_perk_card(id: String) -> Control:
	var data := PerkData.get_perk(id)
	var known := GameState.is_perk_unlocked(id)
	var nivel := GameState.get_perk_level(id)

	var card := Button.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, CARTA_ALTO)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		card.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var madera := PrepBoard.make_nine_patch(CARTA_TEX, CARTA_MARGIN)
	# La placa de un bonificador sin ganar va APAGADA entera, como las
	# tarjetas bloqueadas de Maestrías.
	if not known:
		madera.modulate = Color(0.72, 0.72, 0.76)
	card.add_child(madera)
	card.pressed.connect(func() -> void: _abrir_ficha(id))
	PrepBoard.add_press_feedback(card, 0.97)

	card.add_child(_medallon_en_carta(id))

	# --- La columna de texto, a la derecha del medallón ---
	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_FULL_RECT)
	caja.offset_left = MEDALLON + 40.0
	caja.offset_right = -22.0
	caja.offset_top = 16.0
	caja.offset_bottom = -20.0
	caja.add_theme_constant_override("separation", 3)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(caja)

	var nom := Label.new()
	nom.text = str(data.get("name", id)) if known else "Por descubrir"
	nom.add_theme_font_size_override("font_size", 22)
	nom.add_theme_color_override("font_color",
		CREMA if known else Color(0.86, 0.84, 0.80))
	nom.add_theme_color_override("font_outline_color", Color(0.16, 0.08, 0.02))
	nom.add_theme_constant_override("outline_size", 6)
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		nom.add_theme_font_override("font", negrita)
	nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(nom)

	# EL NIVEL EN ESTRELLAS: cinco niveles, cinco estrellas, el mismo lenguaje
	# que el rango de una maestría. Sin ganar salen vacías, que también cuenta.
	var est := HBoxContainer.new()
	est.mouse_filter = Control.MOUSE_FILTER_IGNORE
	est.add_child(PrepBoard.make_star_row(nivel if known else 0,
		PerkData.MAX_LEVEL, 22, true))
	caja.add_child(est)

	var txt := Label.new()
	if known:
		txt.text = PerkData.level_text(id, nivel)
	elif not GameState.perk_gate_open(id):
		# SU COMPUERTA SIGUE CERRADA: la hazaña exacta todavía no se puede
		# cumplir, así que enseñarla sería mandar al jugador a por un premio
		# que no puede caer.
		txt.text = "Se presenta más adelante en la travesía."
	else:
		txt.text = str(data.get("unlock", ""))
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	txt.add_theme_font_size_override("font_size", 15)
	txt.add_theme_color_override("font_color",
		TOSTADO if known else Color(0.80, 0.78, 0.74))
	txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(txt)

	if not known:
		return card

	# --- La botonera: los usos con su "+1" (lingotes) y Mejorar (doblones).
	# Son dos monedas y dos cosas distintas — el nivel sube lo que HACE el
	# bonificador y el uso solo lo pone otra vez en la mochila — así que el
	# "+1" va PEGADO a la cifra de usos que incrementa, y Mejorar aparte.
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	caja.add_child(fila)
	var usos := Label.new()
	var n_usos := GameState.get_perk_uses(id)
	usos.text = "Usos: %d" % n_usos
	usos.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	usos.add_theme_font_size_override("font_size", 19)
	usos.add_theme_color_override("font_color", VERDE_CLARO)
	usos.add_theme_color_override("font_outline_color", Color(0.10, 0.14, 0.05))
	usos.add_theme_constant_override("outline_size", 6)
	usos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(usos)
	fila.add_child(_boton_uso(id))
	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(hueco)
	var cost := PerkData.upgrade_cost(nivel)
	if cost <= 0:
		var tope := Label.new()
		tope.text = "NIVEL MÁXIMO"
		tope.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tope.add_theme_font_size_override("font_size", 18)
		tope.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))
		tope.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.02))
		tope.add_theme_constant_override("outline_size", 6)
		if negrita != null:
			tope.add_theme_font_override("font", negrita)
		tope.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila.add_child(tope)
	else:
		var buy := _make_upgrade_button(cost)
		buy.disabled = GameState.money < cost
		PrepBoard.set_dimmed(buy, buy.disabled)
		buy.pressed.connect(func() -> void: _confirmar_mejora(id))
		fila.add_child(buy)
	return card


## El medallón de la tarjeta, centrado a la altura de la placa.
func _medallon_en_carta(id: String) -> Control:
	var m := _medallon(id, MEDALLON)
	m.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	m.offset_left = 20.0
	m.offset_right = 20.0 + MEDALLON
	m.offset_top = (CARTA_ALTO - MEDALLON) * 0.5
	m.offset_bottom = -(CARTA_ALTO - MEDALLON) * 0.5
	return m


## "+1 uso" por un LINGOTE: el DISCO DE MÁS del juego, el mismo con el que se
## compra en las cajas de recursos — que es exactamente lo que hace este botón.
## Se probó con la chapa de latón pequeña y NO encoge (su margen 9-slice es 36
## contra 54 de alto): los remaches se amontonaban y el "+1" caía sobre uno.
## El lingote va montado en la esquina del disco, diciendo la moneda.
func _boton_uso(id: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(52, 52)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.set_meta("snd", "recurso")
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var disco := TextureRect.new()
	disco.texture = load("res://assets/ui/boton_mas.png")
	disco.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	disco.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	disco.set_anchors_preset(Control.PRESET_FULL_RECT)
	disco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(disco)
	var ic := TextureRect.new()
	ic.texture = load("res://assets/ui/ic_lingote.png")
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ic.offset_left = -32.0
	ic.offset_top = -24.0
	ic.offset_right = 8.0
	ic.offset_bottom = 4.0
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	b.disabled = GameState.ingots < GameState.PERK_USO_LINGOTES
	b.modulate = Color(1, 1, 1, 0.45) if b.disabled else Color.WHITE
	PrepBoard.add_press_feedback(b, 0.9)
	b.pressed.connect(func() -> void: _confirmar_uso(id))
	return b


## FICHA de un bonificador: el medallón en grande, la descripción, la ESCALERA
## de niveles con el vigente marcado y el precio de los que faltan, cómo se
## ganan los usos, y las dos compras también desde aquí. Se abre tocando la
## placa, igual que en Maestrías se abre tocando el icono.
func _abrir_ficha(id: String) -> void:
	var data := PerkData.get_perk(id)
	var known := GameState.is_perk_unlocked(id)
	var nivel := GameState.get_perk_level(id)
	ficha_id = id

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 150
	ui.add_child(overlay)
	ficha_overlay = overlay
	var velo := Button.new()
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		velo.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.6)
	sombra.set_anchors_preset(Control.PRESET_FULL_RECT)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	velo.add_child(sombra)
	velo.set_meta("snd", "")
	velo.pressed.connect(_cerrar_ficha)
	overlay.add_child(velo)

	var cs := GameState.canvas_size()
	var pw := 580.0
	var ph := 760.0 if known else 560.0
	var panel := Control.new()
	panel.position = Vector2((cs.x - pw) * 0.5, (cs.y - ph) * 0.5)
	panel.size = Vector2(pw, ph)
	overlay.add_child(panel)
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))

	# EL ASPA, cabalgando la esquina — la misma salida que la ficha del mapa.
	var aspa := TextureButton.new()
	aspa.texture_normal = load("res://assets/ui/boton_cerrar.png")
	aspa.ignore_texture_size = true
	aspa.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	aspa.position = Vector2(panel.position.x + pw - 52.0,
		panel.position.y - 18.0)
	aspa.size = Vector2(72, 72)
	aspa.set_meta("snd", "atras")
	aspa.pressed.connect(_cerrar_ficha)
	PrepBoard.add_press_feedback(aspa, 0.9)
	overlay.add_child(aspa)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 52.0
	vb.offset_right = -52.0
	vb.offset_top = 42.0
	vb.offset_bottom = -44.0
	vb.add_theme_constant_override("separation", 7)
	panel.add_child(vb)

	var med := _medallon(id, MEDALLON_FICHA)
	var host := CenterContainer.new()
	host.custom_minimum_size = Vector2(0, MEDALLON_FICHA + 4.0)
	host.add_child(med)
	vb.add_child(host)

	var nom := Label.new()
	nom.text = str(data.get("name", id)) if known else "Por descubrir"
	nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nom.add_theme_font_size_override("font_size", 27)
	nom.add_theme_color_override("font_color", DARK)
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		nom.add_theme_font_override("font", negrita)
	vb.add_child(nom)

	var est := HBoxContainer.new()
	est.alignment = BoxContainer.ALIGNMENT_CENTER
	est.add_child(PrepBoard.make_star_row(nivel if known else 0,
		PerkData.MAX_LEVEL, 28, true))
	vb.add_child(est)

	# La DESCRIPCIÓN general: qué es este bonificador. La tarjeta solo dice el
	# efecto del nivel vigente; el "para qué sirve" vive aquí.
	if known:
		var desc := Label.new()
		desc.text = str(data.get("desc", ""))
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 16)
		desc.add_theme_color_override("font_color", FADED)
		vb.add_child(desc)

	var lista := VBoxContainer.new()
	lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 4)
	vb.add_child(lista)
	if not known:
		var como := Label.new()
		como.text = "Cómo conseguirlo:\n%s" % (
			"Se presenta más adelante en la travesía."
			if not GameState.perk_gate_open(id)
			else str(data.get("unlock", "")))
		como.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		como.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		como.add_theme_font_size_override("font_size", 19)
		como.add_theme_color_override("font_color", FADED)
		lista.add_child(como)
	else:
		for n in range(1, PerkData.MAX_LEVEL + 1):
			lista.add_child(_fila_nivel(id, n, nivel))
		var gana := Label.new()
		# La condición viene ya redactada como frase con su punto, así que se
		# enseña tal cual y el "ganas un uso" va detrás: encajarla dentro de
		# otra frase dejaba dos puntos seguidos y la persona cambiada.
		gana.text = "%s Cada vez que se cumple, ganas un uso." \
			% str(data.get("unlock", ""))
		gana.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gana.add_theme_font_size_override("font_size", 15)
		gana.add_theme_color_override("font_color", Color(0.2, 0.45, 0.12))
		lista.add_child(gana)

		# LAS DOS COMPRAS TAMBIÉN DESDE LA FICHA: aquí es donde se acaba de
		# leer la escalera entera, así que es donde más sentido tiene pagar.
		var fila := HBoxContainer.new()
		fila.alignment = BoxContainer.ALIGNMENT_CENTER
		fila.add_theme_constant_override("separation", 14)
		vb.add_child(fila)
		var usos := Label.new()
		usos.text = "Usos: %d" % GameState.get_perk_uses(id)
		usos.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		usos.add_theme_font_size_override("font_size", 19)
		usos.add_theme_color_override("font_color", Color(0.2, 0.45, 0.12))
		fila.add_child(usos)
		fila.add_child(_boton_uso(id))
		var cost := PerkData.upgrade_cost(nivel)
		if cost > 0:
			var buy := _make_upgrade_button(cost)
			buy.disabled = GameState.money < cost
			PrepBoard.set_dimmed(buy, buy.disabled)
			buy.pressed.connect(func() -> void: _confirmar_mejora(id))
			fila.add_child(buy)


## Una fila de la ESCALERA de niveles: la bolita con el número (verde ya
## superado, ORO el vigente, hueca lo que falta), el efecto, y a la derecha lo
## ya pagado con su visto o el PRECIO del salto. Es lo que deja decidir si la
## mejora vale sus doblones antes de pagarlos.
func _fila_nivel(id: String, n: int, vigente: int) -> Control:
	var fila := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	# El VIGENTE lleva su cama de oro suave; el resto va transparente.
	sb.bg_color = Color(0.95, 0.78, 0.35, 0.32) if n == vigente \
			else Color(0, 0, 0, 0)
	fila.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	fila.add_child(h)

	var bola := Label.new()
	bola.text = "%d" % n
	bola.custom_minimum_size = Vector2(34, 34)
	bola.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bola.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bola.add_theme_font_size_override("font_size", 17)
	bola.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	var bsb := StyleBoxFlat.new()
	bsb.set_corner_radius_all(17)
	if n < vigente:
		bsb.bg_color = VERDE
	elif n == vigente:
		bsb.bg_color = ORO
	else:
		bsb.bg_color = Color(0.62, 0.54, 0.42)
	bola.add_theme_stylebox_override("normal", bsb)
	h.add_child(bola)

	var txt := Label.new()
	txt.text = PerkData.level_text(id, n)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	txt.add_theme_font_size_override("font_size", 16)
	txt.add_theme_color_override("font_color", DARK if n == vigente else FADED)
	h.add_child(txt)

	if n <= vigente:
		var visto := TextureRect.new()
		visto.texture = load("res://assets/ui/ic_hecho.png")
		visto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		visto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		visto.custom_minimum_size = Vector2(28, 28)
		h.add_child(visto)
	else:
		# Lo que costará LLEGAR a este nivel desde el anterior.
		var coin := TextureRect.new()
		coin.texture = load("res://assets/ui/moneda.png")
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.custom_minimum_size = Vector2(22, 22)
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(coin)
		var precio := Label.new()
		precio.text = "%d" % PerkData.upgrade_cost(n - 1)
		precio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		precio.add_theme_font_size_override("font_size", 15)
		precio.add_theme_color_override("font_color", FADED)
		h.add_child(precio)
	return fila


func _cerrar_ficha() -> void:
	if ficha_overlay != null and is_instance_valid(ficha_overlay):
		ficha_overlay.queue_free()
	ficha_overlay = null
	ficha_id = ""


## Tras una compra se repinta TODO y, si había ficha abierta, se reabre al
## día: sus filas y botones acaban de quedarse viejos.
func _tras_compra() -> void:
	var reabrir := ficha_id
	_cerrar_ficha()
	_refresh()
	if reabrir != "":
		_abrir_ficha(reabrir)


## BOTÓN DE MEJORAR, con su precio dibujado dentro: "Mejorar" arriba y la
## MONEDA del juego con la cifra debajo, sobre su chapa de latón con galones
## (`skin_upgrade_button`). La moneda es la misma que en el resto de
## contadores, así que la cifra se lee como dinero sin tener que decirlo.
func _make_upgrade_button(cost: int) -> Button:
	var buy := Button.new()
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Mejorar cuesta DOBLONES: suena como las cajas de recurso, no como un
	# botón cualquiera. Su cartel de confirmación cierra el círculo — grave al
	# cancelar y agudo al aceptar (ver `Audio.TONO`).
	buy.set_meta("snd", "recurso")
	PrepBoard.skin_upgrade_button(buy, 196.0)
	buy.text = ""
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Por dentro del marco de madera de la chapa y entre los dos galones, que
	# ocupan los extremos.
	col.offset_left = 33.0
	col.offset_right = -33.0
	col.offset_top = 9.0
	col.offset_bottom = -11.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buy.add_child(col)
	var titulo := Label.new()
	titulo.text = "Mejorar"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 22)
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
	coin.custom_minimum_size = Vector2(26, 26)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(coin)
	var precio := Label.new()
	precio.text = "%d" % cost
	precio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	precio.add_theme_font_size_override("font_size", 23)
	precio.add_theme_color_override("font_color", Color(1, 0.86, 0.4))
	precio.add_theme_color_override("font_outline_color", Color(0.24, 0.13, 0.05))
	precio.add_theme_constant_override("outline_size", 7)
	precio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(precio)
	return buy


## LOS DOS CARTELES DE COMPRA VAN EN CORTO (rediseño pedido por el usuario).
## Antes eran cuatro renglones de prosa —"Cuesta 2000 doblones. Te quedarán
## 1774"— y lo que el jugador necesita es COMPARAR: qué tiene ahora, qué tendrá
## después y qué le queda en la bolsa. Así que todo va en filas de chips con la
## flecha del juego en medio, el ANTES en rojo y el DESPUÉS en verde, y del
## texto solo queda el nombre.
const ROJO := Color(0.72, 0.24, 0.16)
const VERDE_OK := Color(0.20, 0.50, 0.16)
## Lado de los botones de confirmar. Son CUADRADOS y del tamaño de su glifo
## (`boton_ok` / `boton_cerrar`): las píldoras de `skin_action_button` están
## pensadas para llevar rótulo al lado y sin texto quedaban medio vacías.
const CONFIRMA := 96.0


## El armazón común de los dos carteles: velo, pergamino, lazo y la columna
## centrada. Devuelve la columna, para que cada uno cuelgue sus filas.
func _cartel(titulo: String, alto: float) -> VBoxContainer:
	var velo := ColorRect.new()
	Audio.ventana(velo)
	velo.color = Color(0, 0, 0, 0.55)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.z_index = 160
	ui.get_child(0).add_child(velo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.add_child(centro)
	var cartel := Control.new()
	cartel.custom_minimum_size = Vector2(560, alto)
	centro.add_child(cartel)
	cartel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))
	PrepBoard.add_panel_banner(cartel, titulo, 30)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 52.0
	vb.offset_top = 84.0
	vb.offset_right = -52.0
	vb.offset_bottom = -38.0
	vb.add_theme_constant_override("separation", 10)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	cartel.add_child(vb)
	vb.set_meta("velo", velo)
	return vb


## El NOMBRE del bonificador, que es el título de verdad del cartel.
func _fila_nombre(texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", DARK)
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		l.add_theme_font_override("font", negrita)
	return l


## Una fila CENTRADA de piezas sueltas (etiquetas, chips y flechas).
func _fila() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	return h


## La flecha del juego (la misma del paso de diálogo) haciendo de "pasa a".
func _flecha(lado := 30.0) -> TextureRect:
	var f := TextureRect.new()
	f.texture = load("res://assets/ui/ic_siguiente.png")
	f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	f.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	f.custom_minimum_size = Vector2(lado, lado * 0.86)
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return f


func _texto(txt: String, cuerpo: int, color: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", cuerpo)
	l.add_theme_color_override("font_color", color)
	return l


## Icono de moneda + cifra, que es como se enseña cualquier precio del juego.
func _chip(icono: String, texto: String, cuerpo := 22,
		color := DARK) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic := TextureRect.new()
	ic.texture = load(icono)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(cuerpo + 6, cuerpo + 6)
	h.add_child(ic)
	h.add_child(_texto(texto, cuerpo, color))
	return h


## La botonera de los dos carteles: aspa y visto, CUADRADOS y centrados.
func _confirmar_botones(vb: VBoxContainer, al_aceptar: Callable) -> void:
	var velo: Control = vb.get_meta("velo")
	var fila := _fila()
	fila.add_theme_constant_override("separation", 30)
	vb.add_child(fila)
	for def in [[false, "res://assets/ui/boton_cerrar.png"],
			[true, "res://assets/ui/boton_ok.png"]]:
		var b := TextureButton.new()
		b.texture_normal = load(str(def[1]))
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(CONFIRMA, CONFIRMA)
		b.set_meta("snd", "recurso_ok" if bool(def[0]) else "recurso_off")
		PrepBoard.add_press_feedback(b, 0.9)
		if bool(def[0]):
			b.pressed.connect(func() -> void:
				velo.queue_free()
				al_aceptar.call())
		else:
			b.pressed.connect(velo.queue_free)
		fila.add_child(b)


## COMPRAR USOS CON LINGOTES. Lleva su propio "+" y "−": el cartel es el sitio
## donde se decide CUÁNTOS, así que pedir tres es tocar tres veces el más y no
## abrir el cartel tres veces.
func _confirmar_uso(id: String) -> void:
	var datos := PerkData.get_perk(id)
	if GameState.ingots < GameState.PERK_USO_LINGOTES:
		return
	var vb := _cartel("¿Más usos?", 360.0)
	vb.add_child(_fila_nombre(str(datos.get("name", id))))

	var tenia := GameState.get_perk_uses(id)
	var estado := { "n": 1 }
	var fila_usos := _fila()
	vb.add_child(fila_usos)
	fila_usos.add_child(_texto("Usos:", 22, DARK))
	fila_usos.add_child(_texto("%d" % tenia, 24, ROJO))
	fila_usos.add_child(_flecha())
	var tras := _texto("%d" % (tenia + 1), 24, VERDE_OK)
	fila_usos.add_child(tras)
	var menos := _pm(false)
	var mas := _pm(true)
	fila_usos.add_child(menos)
	fila_usos.add_child(mas)

	var fila_coste := _fila()
	vb.add_child(fila_coste)
	fila_coste.add_child(_texto("Coste:", 20, FADED))
	var coste := _chip("res://assets/ui/ic_lingote.png", "1", 22, DARK)
	fila_coste.add_child(coste)
	fila_coste.add_child(_texto("·", 20, FADED))
	fila_coste.add_child(_chip("res://assets/ui/ic_lingote.png",
		"%d" % GameState.ingots, 20, ROJO))
	fila_coste.add_child(_flecha(24.0))
	var quedan := _chip("res://assets/ui/ic_lingote.png",
		"%d" % (GameState.ingots - GameState.PERK_USO_LINGOTES), 20, VERDE_OK)
	fila_coste.add_child(quedan)

	# Un solo sitio que reescribe las tres cifras que dependen de la cantidad.
	var pintar := func() -> void:
		var n: int = estado["n"]
		var cuesta: int = GameState.PERK_USO_LINGOTES * n
		tras.text = "%d" % (tenia + n)
		(coste.get_child(1) as Label).text = "%d" % cuesta
		(quedan.get_child(1) as Label).text = "%d" % (GameState.ingots - cuesta)
		menos.disabled = n <= 1
		menos.modulate = Color(1, 1, 1, 0.35) if menos.disabled else Color.WHITE
		mas.disabled = GameState.PERK_USO_LINGOTES * (n + 1) > GameState.ingots
		mas.modulate = Color(1, 1, 1, 0.35) if mas.disabled else Color.WHITE
	menos.pressed.connect(func() -> void:
		estado["n"] = maxi(1, int(estado["n"]) - 1)
		pintar.call())
	mas.pressed.connect(func() -> void:
		estado["n"] = int(estado["n"]) + 1
		pintar.call())
	pintar.call()

	_confirmar_botones(vb, func() -> void:
		if GameState.comprar_uso_perk(id, int(estado["n"])):
			_tras_compra())


## Los discos de MÁS y MENOS del juego, los mismos del reparto de Maestrías.
func _pm(mas: bool) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = load("res://assets/ui/boton_mas.png" if mas
		else "res://assets/ui/boton_menos.png")
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(44, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.set_meta("snd", "click")
	PrepBoard.add_press_feedback(b, 0.88)
	return b


## MEJORAR PREGUNTA ANTES. Son de 500 a 10.000 doblones, así que el cartel
## enseña los dos niveles y los dos efectos uno al lado del otro: es lo que
## deja ver de un vistazo qué se compra.
func _confirmar_mejora(id: String) -> void:
	var data := PerkData.get_perk(id)
	var nivel := GameState.get_perk_level(id)
	var cost := PerkData.upgrade_cost(nivel)
	if cost <= 0 or GameState.money < cost:
		return
	var vb := _cartel("¿Mejorar?", 380.0)
	vb.add_child(_fila_nombre(str(data.get("name", id))))

	var fila_niv := _fila()
	vb.add_child(fila_niv)
	fila_niv.add_child(_texto("Nivel %d" % nivel, 22, ROJO))
	fila_niv.add_child(_flecha())
	fila_niv.add_child(_texto("Nivel %d" % (nivel + 1), 22, VERDE_OK))

	var fila_efecto := _fila()
	vb.add_child(fila_efecto)
	fila_efecto.add_child(_texto(PerkData.short_text(id, nivel), 21, ROJO))
	fila_efecto.add_child(_flecha())
	fila_efecto.add_child(_texto(PerkData.short_text(id, nivel + 1), 21,
		VERDE_OK))

	var fila_coste := _fila()
	vb.add_child(fila_coste)
	fila_coste.add_child(_texto("Coste:", 20, FADED))
	fila_coste.add_child(_chip("res://assets/ui/moneda.png", "%d" % cost, 22,
		DARK))
	fila_coste.add_child(_texto("·", 20, FADED))
	fila_coste.add_child(_chip("res://assets/ui/moneda.png",
		"%d" % GameState.money, 20, ROJO))
	fila_coste.add_child(_flecha(24.0))
	fila_coste.add_child(_chip("res://assets/ui/moneda.png",
		"%d" % (GameState.money - cost), 20, VERDE_OK))

	_confirmar_botones(vb, func() -> void:
		if GameState.upgrade_perk(id):
			_tras_compra())
