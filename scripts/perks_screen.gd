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
## Los mismos dos tintes que usa Maestrias para sus marcos: verde para lo
## conseguido y ORO para lo que ya esta al maximo.
const VERDE := Color(0.24, 0.52, 0.22)
const ORO := Color(0.85, 0.66, 0.16)

var ui: CanvasLayer = null
var content: Control = null
var money_label: Label = null
var backdrop: Node3D = null
var _t := 0.0


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


## (Re)pinta la pantalla entera. Tras una compra se vuelve a llamar: repintar
## de golpe es más simple que actualizar la tarjeta y aquí no hay animación que
## perder.
##
## LA PANTALLA HABLA EL IDIOMA DE MAESTRÍAS (rejilla de tarjetas, icono grande
## con marco por ESTADO y el nivel en ESTRELLAS) y no el de una lista de la
## compra, que es lo que era: filas de alto libre, una debajo de otra, con el
## texto compitiendo con un botón. Son las dos pantallas donde el jugador
## reparte oro en mejoras permanentes, así que se leen igual.
func _refresh() -> void:
	for c in content.get_children():
		c.queue_free()
	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	scroll.add_child(col)

	# CABECERA con el recuento, al modo de la de Maestrías: de un vistazo se ve
	# cuánto queda de catálogo sin tener que contar tarjetas.
	col.add_child(_cabecera())

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	col.add_child(grid)
	for id in PerkData.ids():
		grid.add_child(_build_perk_card(str(id)))

	var pie := Label.new()
	pie.text = "Se eligen antes de zarpar y cada jornada gasta un uso."
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pie.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pie.add_theme_font_size_override("font_size", 18)
	pie.add_theme_color_override("font_color", FADED)
	col.add_child(pie)


## Cuántos bonificadores se llevan ganados y cuánta mejora queda por delante.
func _cabecera() -> Control:
	var caja := HBoxContainer.new()
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 12)
	caja.custom_minimum_size = Vector2(0, 52)
	var ganados := 0
	var niveles := 0
	for id in PerkData.ids():
		if GameState.is_perk_unlocked(str(id)):
			ganados += 1
			niveles += GameState.get_perk_level(str(id))
	var l := Label.new()
	l.text = "%d de %d conseguidos" % [ganados, PerkData.ids().size()]
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 25)
	l.add_theme_color_override("font_color", DARK)
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		l.add_theme_font_override("font", negrita)
	caja.add_child(l)
	var tope := PerkData.ids().size() * PerkData.MAX_LEVEL
	var n := Label.new()
	n.text = "·  %d / %d niveles" % [niveles, tope]
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.add_theme_font_size_override("font_size", 20)
	n.add_theme_color_override("font_color", FADED)
	caja.add_child(n)
	return caja


## Marco del icono por ESTADO, calcado de Maestrías: gris apagado sin conseguir,
## neutro conseguido, y ORO al llegar al nivel máximo. Es lo que deja ver de un
## vistazo qué está exprimido y qué no.
func _marco_estado(known: bool, nivel: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(18)
	if not known:
		sb.bg_color = Color(0.30, 0.26, 0.22)
	elif nivel >= PerkData.MAX_LEVEL:
		sb.bg_color = ORO
	else:
		sb.bg_color = VERDE
	return sb


## UNA TARJETA: icono grande enmarcado, nombre, el nivel en ESTRELLAS, lo que
## hace HOY y el botón de mejorar con su precio. Sin conseguir enseña la
## silueta y la condición, como las piezas de la vitrina.
func _build_perk_card(id: String) -> Control:
	var data := PerkData.get_perk(id)
	var known := GameState.is_perk_unlocked(id)
	var nivel := GameState.get_perk_level(id)

	var card := Button.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# El alto se CUENTA, no se tantea: icono 104 + nombre + estrellas 20 +
	# texto (hasta dos renglones) + usos + la chapa de Mejorar (93) con sus
	# separaciones y sus margenes. Estuvo en 268 y luego en 340, y las dos
	# veces la chapa se salia por el canto inferior en las tarjetas de dos
	# renglones de texto — que son justo las de abajo, donde mas canta.
	card.custom_minimum_size = Vector2(0, 376)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		card.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	card.add_child(PrepBoard.make_nine_patch(PrepBoard.CARD_TEX,
		PrepBoard.CARD_MARGIN))
	card.pressed.connect(func() -> void: _abrir_ficha(id))
	PrepBoard.add_press_feedback(card, 0.95)

	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_FULL_RECT)
	caja.offset_left = 14.0
	caja.offset_right = -14.0
	caja.offset_top = 12.0
	caja.offset_bottom = -12.0
	caja.add_theme_constant_override("separation", 4)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(caja)

	# --- Icono enmarcado ---
	var host := Control.new()
	host.custom_minimum_size = Vector2(0, 104)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(host)
	var marco := Panel.new()
	marco.add_theme_stylebox_override("panel", _marco_estado(known, nivel))
	# CENTRADO A MANO: anclas al 0.5 y offsets a media anchura del marco.
	# `set_anchors_preset(PRESET_CENTER_TOP, true)` NO centra nada — conserva
	# los offsets tal cual y, al llevarse el ancla al 0.5, empuja el marco
	# MEDIA TARJETA a la derecha. Peor todavia porque en ese momento el
	# anfitrion mide 0 (el contenedor aun no ha repartido), asi que el calculo
	# de "conservar la posicion" no tiene contra que compensar. Es la trampa
	# del preset ya documentada con el globo de la barra de nivel.
	marco.anchor_left = 0.5
	marco.anchor_right = 0.5
	marco.offset_left = -50.0
	marco.offset_right = 50.0
	marco.offset_top = 2.0
	marco.offset_bottom = 102.0
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(marco)
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = load(str(data.get("icon", "")))
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 8.0
	ic.offset_top = 8.0
	ic.offset_right = -8.0
	ic.offset_bottom = -8.0
	# Sin conseguir, SILUETA: la pantalla dice que existe y qué pide, no cómo es.
	ic.modulate = Color.WHITE if known else Color(0.14, 0.11, 0.09, 0.85)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco.add_child(ic)

	# --- Nombre ---
	var nom := Label.new()
	nom.text = str(data.get("name", id)) if known else "Por descubrir"
	nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nom.add_theme_font_size_override("font_size", 19)
	nom.add_theme_color_override("font_color", DARK if known else FADED)
	nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(nom)

	# --- EL NIVEL, EN ESTRELLAS. Cinco niveles, cinco estrellas: el mismo
	# lenguaje que el rango de una maestría, y se cuenta sin leer.
	var est := HBoxContainer.new()
	est.alignment = BoxContainer.ALIGNMENT_CENTER
	est.mouse_filter = Control.MOUSE_FILTER_IGNORE
	est.add_child(PrepBoard.make_star_row(nivel if known else 0,
		PerkData.MAX_LEVEL, 20, true))
	caja.add_child(est)

	# --- Qué hace hoy, o qué pide ---
	var txt := Label.new()
	txt.text = PerkData.level_text(id, nivel) if known \
			else str(data.get("unlock", ""))
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	txt.add_theme_font_size_override("font_size", 15)
	txt.add_theme_color_override("font_color", FADED)
	txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(txt)

	if not known:
		return card

	# --- Usos y mejora ---
	var usos := Label.new()
	var n_usos := GameState.get_perk_uses(id)
	usos.text = "%d uso%s" % [n_usos, "" if n_usos == 1 else "s"]
	usos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	usos.add_theme_font_size_override("font_size", 16)
	usos.add_theme_color_override("font_color", Color(0.2, 0.45, 0.12))
	usos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(usos)

	var cost := PerkData.upgrade_cost(nivel)
	if cost <= 0:
		var tope := Label.new()
		tope.text = "Nivel máximo"
		tope.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tope.add_theme_font_size_override("font_size", 17)
		tope.add_theme_color_override("font_color", ORO)
		tope.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caja.add_child(tope)
		return card
	var buy := _make_upgrade_button(cost)
	buy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buy.disabled = GameState.money < cost
	buy.pressed.connect(func() -> void: _confirmar_mejora(id))
	caja.add_child(buy)
	return card


## FICHA de un bonificador: el dibujo grande, qué hace en CADA nivel y cómo se
## gana. Se abre tocando la tarjeta, igual que en Maestrías se abre tocando el
## icono de una habilidad.
func _abrir_ficha(id: String) -> void:
	var data := PerkData.get_perk(id)
	var known := GameState.is_perk_unlocked(id)
	var nivel := GameState.get_perk_level(id)

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 150
	ui.add_child(overlay)
	var velo := Button.new()
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		velo.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.6)
	sombra.set_anchors_preset(Control.PRESET_FULL_RECT)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	velo.add_child(sombra)
	velo.pressed.connect(overlay.queue_free)
	overlay.add_child(velo)

	var cs := GameState.canvas_size()
	var pw := 560.0
	var ph := 620.0
	var panel := Control.new()
	panel.position = Vector2((cs.x - pw) * 0.5, (cs.y - ph) * 0.5)
	panel.size = Vector2(pw, ph)
	overlay.add_child(panel)
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 54.0
	vb.offset_right = -54.0
	vb.offset_top = 46.0
	vb.offset_bottom = -44.0
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var host := Control.new()
	host.custom_minimum_size = Vector2(0, 140)
	vb.add_child(host)
	var marco := Panel.new()
	marco.add_theme_stylebox_override("panel", _marco_estado(known, nivel))
	# CENTRADO A MANO: anclas al 0.5 y offsets a media anchura del marco.
	# `set_anchors_preset(PRESET_CENTER_TOP, true)` NO centra nada — conserva
	# los offsets tal cual y, al llevarse el ancla al 0.5, empuja el marco
	# MEDIA TARJETA a la derecha. Peor todavia porque en ese momento el
	# anfitrion mide 0 (el contenedor aun no ha repartido), asi que el calculo
	# de "conservar la posicion" no tiene contra que compensar. Es la trampa
	# del preset ya documentada con el globo de la barra de nivel.
	marco.anchor_left = 0.5
	marco.anchor_right = 0.5
	marco.offset_left = -66.0
	marco.offset_right = 66.0
	marco.offset_top = 0.0
	marco.offset_bottom = 132.0
	host.add_child(marco)
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = load(str(data.get("icon", "")))
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 10.0
	ic.offset_top = 10.0
	ic.offset_right = -10.0
	ic.offset_bottom = -10.0
	ic.modulate = Color.WHITE if known else Color(0.14, 0.11, 0.09, 0.85)
	marco.add_child(ic)

	var nom := Label.new()
	nom.text = str(data.get("name", id)) if known else "Bonificador por descubrir"
	nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nom.add_theme_font_size_override("font_size", 27)
	nom.add_theme_color_override("font_color", DARK)
	vb.add_child(nom)

	var est := HBoxContainer.new()
	est.alignment = BoxContainer.ALIGNMENT_CENTER
	est.add_child(PrepBoard.make_star_row(nivel if known else 0,
		PerkData.MAX_LEVEL, 26, true))
	vb.add_child(est)

	var lista := VBoxContainer.new()
	lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 3)
	vb.add_child(lista)
	if not known:
		var como := Label.new()
		como.text = "Cómo conseguirlo:\n%s" % str(data.get("unlock", ""))
		como.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		como.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		como.add_theme_font_size_override("font_size", 19)
		como.add_theme_color_override("font_color", FADED)
		lista.add_child(como)
	else:
		# TODOS los niveles, con el vigente marcado: es lo que deja decidir si
		# la mejora vale sus doblones antes de pagarlos.
		for n in range(1, PerkData.MAX_LEVEL + 1):
			var fila := Label.new()
			fila.text = "%s %d ·  %s" % ["▶" if n == nivel else "  ", n,
				PerkData.level_text(id, n)]
			fila.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			fila.add_theme_font_size_override("font_size", 16)
			fila.add_theme_color_override("font_color",
				DARK if n == nivel else FADED)
			lista.add_child(fila)
		var gana := Label.new()
		# La condicion viene ya redactada como frase con su punto, asi que se
		# ensena tal cual y el "ganas un uso" va detras: encajarla dentro de
		# otra frase dejaba dos puntos seguidos y la persona cambiada.
		gana.text = "%s Cada vez que se cumple, ganas un uso." \
			% str(data.get("unlock", ""))
		gana.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gana.add_theme_font_size_override("font_size", 15)
		gana.add_theme_color_override("font_color", Color(0.2, 0.45, 0.12))
		lista.add_child(gana)

	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.custom_minimum_size = Vector2(0, 66)
	PrepBoard.skin_button(cerrar)
	PrepBoard.add_press_feedback(cerrar)
	cerrar.add_theme_font_size_override("font_size", 24)
	cerrar.pressed.connect(overlay.queue_free)
	vb.add_child(cerrar)


## BOTÓN DE MEJORAR, con su precio dibujado dentro: "Mejorar" arriba y la
## MONEDA del juego con la cifra debajo. El rótulo iba antes en tres renglones
## de texto pelado ("Mejorar\na nivel 3\n$2000") dentro de un botón de 180x90 y
## no cabía. La moneda es la misma que en el resto de contadores del juego, así
## que la cifra se lee como dinero sin tener que decirlo.
func _make_upgrade_button(cost: int) -> Button:
	var buy := Button.new()
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Mejorar cuesta DOBLONES: suena como las cajas de recurso, no como un
	# botón cualquiera. Su cartel de confirmación cierra el círculo — grave al
	# cancelar y agudo al aceptar (ver `Audio.TONO`).
	buy.set_meta("snd", "recurso")
	# CHAPA PROPIA, no el tablón de madera de todos los botones del juego: es
	# la única acción de la pantalla y cuesta hasta 10.000 doblones, así que
	# tenía que distinguirse de un "Cerrar". El galón grabado en cada extremo
	# es lo que dice "sube de nivel" sin escribirlo.
	PrepBoard.skin_upgrade_button(buy, 204.0)
	buy.text = ""
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Por dentro del marco de madera de la chapa y entre los dos galones, que
	# ocupan los extremos.
	col.offset_left = 34.0
	col.offset_right = -34.0
	col.offset_top = 10.0
	col.offset_bottom = -12.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buy.add_child(col)
	var titulo := Label.new()
	titulo.text = "Mejorar"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 23)
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
	Audio.ventana(velo)
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
