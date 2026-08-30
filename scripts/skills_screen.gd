extends Node3D
## MAESTRÍAS DEL COCINERO: el árbol de habilidades, en TRES SECCIONES — una
## pestaña con icono propio por árbol (cuchillo, cliente, chef) y, dentro, sus
## cinco habilidades en tarjetas grandes. Se enseña un árbol cada vez, y eso
## es justo lo que deja sitio para que los iconos sean GRANDES y quepan con
## sus estrellas y sus botones (con los tres árboles a la vez, cada icono se
## quedaba en 88 px y las cifras no se leían).
##
## EN CADA TARJETA hay dos cifras distintas a propósito: las ESTRELLAS son el
## RANGO de la habilidad, y el "x/N" de debajo son los PUNTOS ENTREGADOS hacia
## el rango siguiente. Debajo, los botones de reparto: ROJO con el "−" y VERDE
## con el "+" (los mismos discos de las cajas de recursos).
##
## EL REPARTO DE PUNTOS ES LIBRE Y CONTINUO: el jugador cambia de estrategia
## cuando quiera, punto a punto, desde la tarjeta o desde la ficha. Quitar el
## punto que sostiene una habilidad PREGUNTA antes; cada SUBIDA DE RANGO se
## celebra con su ventana, que canta el cambio (un 4% que pasa a 8%). El [−]
## solo se bloquea cuando ese punto sostiene a otra habilidad aprendida
## (GameState.can_refund_skill).
##
## Se llega aquí desde la BARRA DE NIVEL del menú (no hay icono en el submenú).

const PrepBoard := preload("res://scripts/prep_board.gd")
const DARK := Color(0.26, 0.16, 0.08)
const FADED := Color(0.45, 0.34, 0.2)
const AZUL := Color(0.30, 0.48, 0.72)

## Tinte de cada árbol (columna, marcos y popup): teja, azul y verde.
const TREE_COLORS := {
	"cuchillo": Color(0.72, 0.30, 0.20),
	"cliente": Color(0.25, 0.52, 0.68),
	"chef": Color(0.38, 0.62, 0.30),
}
const ORO := Color(0.85, 0.65, 0.15)

var ui: CanvasLayer = null
var content: Control = null
var puntos_label: Label = null
var puntos_chapa: Control = null
var nivel_label: Label = null
var xp_bar: ProgressBar = null
var xp_label: Label = null
## Pestañas de sección (una por árbol) y el lienzo donde viven sus tarjetas.
var tab_buttons: Dictionary = {}
var current_tree := "cuchillo"
var cols_root: Control = null
## Botones de icono por habilidad, para repintar estados sin reconstruir.
var icon_buttons: Dictionary = {}
## El popup abierto (null si no hay). Se repinta en cada + / −.
var popup: Control = null
var popup_id := ""
var backdrop: Node3D = null
var _t := 0.0
## El latido de la chapa de puntos, para poder matarlo al repintar.
var _chapa_tween: Tween = null
## Los tramos de RAMA de la sección abierta: { nodo, hacia }.
var ramas: Array = []
## El botón de reiniciar el árbol, para poder apagarlo sin reconstruir.
var reset_btn: Button = null


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
	# SIN cinta de título: la pantalla ya se identifica por su cabecera ("Nivel
	# de cocinero N") y el lazo rojo solo robaba alto a las columnas.
	var back := PrepBoard.make_back_button()
	# VUELVE A DONDE SE ENTRO, no siempre al menu: a esta pantalla se llega
	# por la BARRA DE NIVEL, que vive tambien en el mapa y en la pesca.
	back.pressed.connect(func() -> void:
		GameState.transition = GameState.skills_from
		GameState.fade_to_scene("res://scenes/main_menu.tscn", 0.35, 0.45))
	bar.add_child(back)

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
	content.offset_left = 42.0
	content.offset_top = 36.0
	content.offset_right = -42.0
	content.offset_bottom = -36.0
	sheet.add_child(content)

	_build_header()
	_build_tabs()
	cols_root = Control.new()
	cols_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	cols_root.offset_top = 226.0
	content.add_child(cols_root)
	_build_section()
	_refresh_header()


## Cabecera SIN el rótulo "Nivel de cocinero": la ESTRELLA con el número lo
## dice todo, la barra lleva la experiencia ESCRITA DENTRO ("210/350") y a la
## derecha va la CHAPA de puntos libres, que es la cifra con la que el jugador
## está jugando.
const CHAPA := 88.0
## La chapa de puntos (`chapa_puntos.png`): medalla de oro con el disco azul
## vacío dentro. Su dibujo NO está centrado en el lienzo — el laurel del pie
## baja el conjunto —, así que la cifra se coloca contra estas fracciones,
## MEDIDAS sobre el PNG, y no contra el centro geométrico.
const CHAPA_P_W := 88.0
const CHAPA_P_RATIO := 120.0 / 112.0
const CHAPA_P_CY := 0.458

## LO QUE MIDE `content` DE ANCHO. No se puede leer de `content.size` al
## construir (los contenedores aún no se han asentado) y tampoco vale un 720
## clavado: en el móvil el lienzo mide otra cosa. Estuvo a 636 a mano y la
## chapa de puntos se salía por detrás del marco del pergamino.
func _ancho() -> float:
	return GameState.canvas_size().x - 112.0


## El centro VISUAL de la estrella, que NO es el de su caja: una estrella tiene
## las puntas fuera y su masa cae por debajo del medio (medido sobre el alfa de
## `estrella_llena.png`: 0.536 de su alto). Alineando contra el centro
## geométrico, la barra quedaba visiblemente alta.
const ESTRELLA_CY := 0.536


func _build_header() -> void:
	var w := _ancho()
	var eje := CHAPA * ESTRELLA_CY      # la línea sobre la que se alinea todo

	# La chapa del nivel: la estrella del juego con la cifra dentro, en NEGRITA
	# de verdad (Exo2-Bold) y con contorno: es el número que da nombre a la
	# pantalla y en regular se leía como un dato más.
	var estrella := TextureRect.new()
	estrella.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	estrella.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	estrella.texture = load("res://assets/ui/estrella_llena.png")
	estrella.position = Vector2(0.0, 0.0)
	estrella.size = Vector2(CHAPA, CHAPA)
	estrella.pivot_offset = Vector2(CHAPA, CHAPA) * 0.5
	estrella.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(estrella)
	nivel_label = Label.new()
	nivel_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	nivel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nivel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nivel_label.offset_top = (ESTRELLA_CY - 0.5) * CHAPA * 2.0
	nivel_label.add_theme_font_size_override("font_size", 36)
	nivel_label.add_theme_color_override("font_color", Color(1, 0.97, 0.86))
	nivel_label.add_theme_color_override("font_outline_color",
		Color(0.42, 0.22, 0.03))
	nivel_label.add_theme_constant_override("outline_size", 10)
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		nivel_label.add_theme_font_override("font", negrita)
	nivel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	estrella.add_child(nivel_label)

	# La barra, entre la estrella y la chapa, CENTRADA en el mismo eje.
	var barra_h := 36.0
	var chapa_h := CHAPA_P_W * CHAPA_P_RATIO
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.position = Vector2(CHAPA + 8.0, eje - barra_h * 0.5)
	xp_bar.size = Vector2(w - CHAPA - CHAPA_P_W - 26.0, barra_h)
	xp_bar.add_theme_stylebox_override("background",
		PrepBoard.make_bar_box(PrepBoard.BAR_BG_TEX))
	xp_bar.add_theme_stylebox_override("fill",
		PrepBoard.make_bar_box(PrepBoard.BAR_FILL_TEX, AZUL))
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(xp_bar)
	xp_label = Label.new()
	xp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_label.add_theme_font_size_override("font_size", 21)
	xp_label.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	xp_label.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.02))
	xp_label.add_theme_constant_override("outline_size", 7)
	if negrita != null:
		xp_label.add_theme_font_override("font", negrita)
	xp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_bar.add_child(xp_label)

	# LA CHAPA DE PUNTOS: medalla de oro con disco azul, no el círculo liso que
	# había (se leía como un marcador de posición al lado del resto del set).
	puntos_chapa = Control.new()
	puntos_chapa.position = Vector2(w - CHAPA_P_W, eje - chapa_h * CHAPA_P_CY)
	puntos_chapa.size = Vector2(CHAPA_P_W, chapa_h)
	puntos_chapa.pivot_offset = puntos_chapa.size * 0.5
	puntos_chapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(puntos_chapa)
	var dibujo := TextureRect.new()
	dibujo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dibujo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dibujo.texture = load("res://assets/ui/chapa_puntos.png")
	dibujo.set_anchors_preset(Control.PRESET_FULL_RECT)
	dibujo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	puntos_chapa.add_child(dibujo)
	puntos_label = Label.new()
	puntos_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	puntos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	puntos_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	puntos_label.offset_top = (CHAPA_P_CY - 0.5) * chapa_h * 2.0
	puntos_label.add_theme_font_size_override("font_size", 36)
	puntos_label.add_theme_color_override("font_color", Color(1, 0.98, 0.9))
	puntos_label.add_theme_color_override("font_outline_color",
		Color(0.06, 0.14, 0.26))
	puntos_label.add_theme_constant_override("outline_size", 8)
	if negrita != null:
		puntos_label.add_theme_font_override("font", negrita)
	puntos_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	puntos_chapa.add_child(puntos_label)
	var pie := Label.new()
	pie.text = "puntos"
	pie.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pie.offset_top = 0.0
	pie.offset_bottom = 24.0
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pie.add_theme_font_size_override("font_size", 16)
	pie.add_theme_color_override("font_color", FADED)
	pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	puntos_chapa.add_child(pie)


func _refresh_header() -> void:
	nivel_label.text = str(GameState.chef_level)
	var nivel := GameState.chef_level
	if nivel >= SkillData.MAX_LEVEL:
		xp_bar.max_value = 1
		xp_bar.value = 1
		xp_label.text = "MÁXIMO"
	else:
		var suelo := SkillData.xp_at_level(nivel)
		var falta := SkillData.xp_for_next(nivel)
		xp_bar.max_value = falta
		xp_bar.value = GameState.chef_xp - suelo
		xp_label.text = "%d / %d" % [GameState.chef_xp - suelo, falta]
	var libres := GameState.chef_points_free()
	puntos_label.text = str(libres)
	# La chapa se apaga cuando no queda nada que gastar, y RESPIRA cuando sí:
	# es la cifra que dice "aquí tienes algo que repartir".
	puntos_chapa.modulate = Color.WHITE if libres > 0 \
			else Color(0.72, 0.72, 0.72, 0.85)
	if _chapa_tween != null and _chapa_tween.is_valid():
		_chapa_tween.kill()
		_chapa_tween = null
	puntos_chapa.scale = Vector2.ONE
	if libres > 0 and GameState.animations_on():
		_chapa_tween = puntos_chapa.create_tween().set_loops()
		_chapa_tween.tween_property(puntos_chapa, "scale", Vector2(1.07, 1.07),
			0.7).set_trans(Tween.TRANS_SINE)
		_chapa_tween.tween_property(puntos_chapa, "scale", Vector2.ONE, 0.7) \
				.set_trans(Tween.TRANS_SINE)


## Un bote de la cifra de puntos al gastarse o recuperarse.
func _pop_puntos() -> void:
	puntos_label.pivot_offset = puntos_label.size * 0.5
	var tw := puntos_label.create_tween()
	tw.tween_property(puntos_label, "scale", Vector2(1.25, 1.25), 0.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(puntos_label, "scale", Vector2.ONE, 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------ las secciones

## UNA SECCION POR ARBOL, con su pestana de icono propio. Se ensena un arbol
## cada vez, y eso es lo que deja sitio para que los ICONOS SEAN GRANDES y
## quepan con sus estrellas y sus botones debajo: con las tres columnas a la
## vez, cada icono se quedaba en 88 px y las cifras no se leian.
const CARD_W := 290.0
const CARD_H := 236.0
const BIG_ICON := 128.0
## Grosor de las RAMAS que unen las habilidades y su tinte apagado.
const RAMA_GRUESO := 8.0
const RAMA_APAGADA := Color(0.55, 0.45, 0.33, 0.55)


func _build_tabs() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	row.offset_top = 132.0
	row.offset_bottom = 216.0
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	for tree in SkillData.TREES:
		var id := str(tree["id"])
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		PrepBoard.skin_button(b)
		b.pressed.connect(func() -> void:
			if current_tree == id:
				return
			current_tree = id
			_build_section()
			_paint_tabs())
		row.add_child(b)
		# El ICONO del arbol arriba y su nombre corto debajo.
		var ic := TextureRect.new()
		ic.name = "Icono"
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var ruta := str(tree.get("icon", ""))
		if ResourceLoader.exists(ruta):
			ic.texture = load(ruta)
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_top = 6.0
		ic.offset_bottom = -34.0
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		var l := Label.new()
		l.text = str(tree.get("short", ""))
		l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		l.offset_top = -34.0
		l.offset_bottom = -8.0
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
		l.add_theme_color_override("font_outline_color", Color(0.16, 0.08, 0.02))
		l.add_theme_constant_override("outline_size", 6)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
		tab_buttons[id] = b
	_paint_tabs()


## La pestana ABIERTA va a plena luz y algo mas grande; las otras, apagadas.
func _paint_tabs() -> void:
	for id in tab_buttons:
		var b: Button = tab_buttons[id]
		var activa: bool = str(id) == current_tree
		PrepBoard.set_dimmed(b, not activa)
		b.pivot_offset = b.size * 0.5
		b.scale = Vector2(1.06, 1.06) if activa else Vector2.ONE


## Las CINCO tarjetas del arbol abierto, en dos columnas.
func _build_section() -> void:
	for c in cols_root.get_children():
		c.queue_free()
	icon_buttons.clear()
	var color: Color = TREE_COLORS.get(current_tree, DARK)
	# El pano tintado del arbol, detras de sus tarjetas.
	var pano := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.14)
	sb.border_color = Color(color.r, color.g, color.b, 0.5)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	pano.add_theme_stylebox_override("panel", sb)
	pano.set_anchors_preset(Control.PRESET_FULL_RECT)
	pano.offset_bottom = -6.0
	pano.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols_root.add_child(pano)

	var w := _ancho()
	var ids := SkillData.tree_skills(current_tree)
	var hueco := (w - CARD_W * 2.0) / 3.0
	var pos: Array[Vector2] = []
	for i in ids.size():
		# Las cuatro primeras en dos columnas; la FINAL, sola y centrada.
		var fila: int = i / 2
		var col: int = i % 2
		var x := hueco + float(col) * (CARD_W + hueco)
		if i == 4:
			x = (w - CARD_W) * 0.5
		pos.append(Vector2(x, 12.0 + float(fila) * (CARD_H + 6.0)))
	# LAS RAMAS VAN ANTES QUE LAS TARJETAS en el árbol de nodos: el orden de
	# hijos es el orden de dibujado, así que puestas después taparían los
	# iconos.
	_dibujar_ramas(ids, pos)
	for i in ids.size():
		_add_card(str(ids[i]), pos[i], color)
	_boton_reiniciar(pos[pos.size() - 1].y + CARD_H + 16.0)
	_entrada_animada()


## LAS RAMAS DEL ÁRBOL: una barra que une las dos primeras habilidades, un
## tronco que baja por el pasillo central hasta la barra de la 3ª y la 4ª, y
## ese mismo tronco siguiendo hasta la 5ª, que va centrada.
##
## Va por el PASILLO entre columnas a propósito: es la única franja vertical
## libre de la sección (bajando por el eje de una tarjeta, la rama cruzaría su
## nombre, sus estrellas y sus botones).
func _dibujar_ramas(ids: Array, pos: Array[Vector2]) -> void:
	if pos.size() < 5:
		return
	var cx := func(i: int) -> float: return pos[i].x + CARD_W * 0.5
	var cy := func(i: int) -> float: return pos[i].y + BIG_ICON * 0.5
	var medio: float = (cx.call(0) + cx.call(1)) * 0.5
	# Una rama se ENCIENDE cuando la habilidad a la que lleva ya es alcanzable
	# (sus prerrequisitos están aprendidos): así el camino se ve abrirse.
	ramas.clear()
	# 1 ↔ 2: siempre encendida, son las dos de entrada del árbol.
	_rama(Vector2(cx.call(0), cy.call(0)), Vector2(cx.call(1), cy.call(1)), "")
	# El tronco hasta la altura de la 3ª y la 4ª, y su barra.
	_rama(Vector2(medio, cy.call(0)), Vector2(medio, cy.call(2)), str(ids[2]))
	_rama(Vector2(cx.call(2), cy.call(2)), Vector2(cx.call(3), cy.call(3)),
		str(ids[2]))
	# Y el tronco hasta la FINAL.
	_rama(Vector2(medio, cy.call(3)), Vector2(medio, cy.call(4)), str(ids[4]))
	_paint_ramas()


## Un tramo recto de rama (horizontal o vertical) con sus puntas redondeadas.
## `hacia` es la habilidad a la que lleva ("" = siempre encendida).
func _rama(a: Vector2, b: Vector2, hacia: String) -> void:
	var p := Panel.new()
	var r := Rect2(a, Vector2.ZERO).expand(b).grow(RAMA_GRUESO * 0.5)
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols_root.add_child(p)
	ramas.append({ "nodo": p, "hacia": hacia })


## Una rama se ENCIENDE cuando la habilidad a la que lleva ya es alcanzable
## (sus prerrequisitos están aprendidos): así el camino se ve abrirse solo.
func _paint_ramas() -> void:
	var color: Color = TREE_COLORS.get(current_tree, DARK)
	for r in ramas:
		var p: Panel = r["nodo"]
		if not is_instance_valid(p):
			continue
		var viva := true
		var hacia := str(r["hacia"])
		if hacia != "":
			for pre in SkillData.prereqs(hacia):
				if GameState.skill_rank(str(pre)) <= 0:
					viva = false
		var sb := StyleBoxFlat.new()
		sb.bg_color = color if viva else RAMA_APAGADA
		sb.set_corner_radius_all(int(RAMA_GRUESO * 0.5))
		p.add_theme_stylebox_override("panel", sb)


## "Reiniciar maestría": devuelve TODOS los puntos de este árbol de golpe, para
## replantearlo sin ir habilidad por habilidad. Pregunta antes.
func _boton_reiniciar(y: float) -> void:
	var w := _ancho()
	var b := Button.new()
	b.text = "Reiniciar maestría"
	PrepBoard.skin_small_button(b)
	b.add_theme_font_size_override("font_size", 22)
	b.position = Vector2((w - 300.0) * 0.5, y)
	b.size = Vector2(300.0, 56.0)
	var puestos := GameState.tree_points(current_tree)
	b.disabled = puestos <= 0
	PrepBoard.set_dimmed(b, b.disabled)
	b.pressed.connect(_confirmar_reinicio.bind(current_tree))
	cols_root.add_child(b)
	reset_btn = b


## Una tarjeta: icono GRANDE (abre la ficha), estrellas del RANGO, los puntos
## entregados hacia el rango siguiente y los botones rojo y verde debajo.
func _add_card(id: String, pos: Vector2, color: Color) -> void:
	var card := Control.new()
	card.position = pos
	card.size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols_root.add_child(card)

	# El icono es un BOTON: tocarlo abre la ficha de la habilidad.
	var b := Button.new()
	for est in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(est, StyleBoxEmpty.new())
	b.position = Vector2((CARD_W - BIG_ICON) * 0.5, 0.0)
	b.size = Vector2(BIG_ICON, BIG_ICON)
	b.pivot_offset = b.size * 0.5
	card.add_child(b)
	var marco := Panel.new()
	marco.name = "Marco"
	marco.set_anchors_preset(Control.PRESET_FULL_RECT)
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(marco)
	var papel := PrepBoard.make_nine_patch(PrepBoard.CARD_TEX,
		PrepBoard.CARD_MARGIN)
	papel.set_anchors_preset(Control.PRESET_FULL_RECT)
	papel.offset_left = 5.0
	papel.offset_top = 5.0
	papel.offset_right = -5.0
	papel.offset_bottom = -5.0
	papel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(papel)
	var ic := TextureRect.new()
	ic.name = "Dibujo"
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = SkillData.icon(id)
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 16.0
	ic.offset_top = 14.0
	ic.offset_right = -16.0
	ic.offset_bottom = -14.0
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	b.pressed.connect(_open_popup.bind(id))
	b.set_meta("tree_color", color)
	icon_buttons[id] = b

	var nom := Label.new()
	nom.name = "Nombre"
	nom.text = str(SkillData.get_skill(id).get("name", id))
	nom.position = Vector2(0.0, BIG_ICON + 2.0)
	nom.size = Vector2(CARD_W, 24.0)
	nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nom.add_theme_font_size_override("font_size", 18)
	nom.add_theme_color_override("font_color", DARK)
	nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(nom)

	# LAS ESTRELLAS son el RANGO; el "x/N" de debajo son los PUNTOS ENTREGADOS
	# hacia el rango siguiente. Dos cosas distintas, a proposito.
	var est_host := Control.new()
	est_host.name = "Estrellas"
	est_host.position = Vector2(0.0, BIG_ICON + 28.0)
	est_host.size = Vector2(CARD_W, 28.0)
	est_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(est_host)

	# EL REPARTO EN UNA SOLA FILA: [−] x/5 [+]. Los discos flanquean la cifra
	# que mueven, que es lo que hace evidente para qué sirven; en su propia
	# fila debajo eran dos botones sueltos sin dueño, y grandes de más.
	var fila := HBoxContainer.new()
	fila.name = "Botones"
	fila.position = Vector2(0.0, BIG_ICON + 56.0)
	fila.size = Vector2(CARD_W, PM_SIZE)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 12)
	card.add_child(fila)
	fila.add_child(_make_pm_button(id, false))
	# LOS PUNTOS ENTREGADOS VAN EN PUNTITOS, no en un "0/5" (pedido por el
	# usuario): una fila de bolitas que se van llenando se lee de un vistazo y
	# sin contar, como las barras de los Sims. El Label sigue existiendo —
	# oculto— para el "MÁX." del rango tope, que sí es una palabra.
	var pts := Label.new()
	pts.name = "Puntos"
	pts.custom_minimum_size = Vector2(96.0, PM_SIZE)
	pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pts.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pts.add_theme_font_size_override("font_size", 22)
	pts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pts.visible = false
	fila.add_child(pts)
	var bolas := Control.new()
	bolas.name = "Bolas"
	bolas.custom_minimum_size = Vector2(96.0, PM_SIZE)
	bolas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bolas.draw.connect(_dibujar_bolas.bind(bolas))
	fila.add_child(bolas)
	fila.add_child(_make_pm_button(id, true))
	_paint_icon(id)


## LOS PUNTITOS: uno por punto que pide el rango, llenos los entregados. El
## lleno es el oro del set y el vacío un hueco hundido, para que se distingan
## también sin color (la misma pareja que las estrellas del cartel del mapa).
func _dibujar_bolas(c: Control) -> void:
	var total: int = int(c.get_meta("total", 5))
	var dados: int = int(c.get_meta("dados", 0))
	if total <= 0:
		return
	var r := 7.0
	var hueco := 6.0
	var ancho: float = total * r * 2.0 + (total - 1) * hueco
	var x: float = (c.size.x - ancho) * 0.5 + r
	var y: float = c.size.y * 0.5
	for i in total:
		var cx := Vector2(x + i * (r * 2.0 + hueco), y)
		if i < dados:
			c.draw_circle(cx, r, Color(0.96, 0.76, 0.24))
			c.draw_arc(cx, r, 0.0, TAU, 20, Color(0.42, 0.26, 0.06), 2.0, true)
		else:
			c.draw_circle(cx, r, Color(0.72, 0.63, 0.48, 0.45))
			c.draw_arc(cx, r, 0.0, TAU, 20, Color(0.45, 0.34, 0.18, 0.55), 2.0, true)


## Lado de los discos de reparto. Van PEQUEÑOS: solo tienen que dejarse pulsar
## con el pulgar, y la cifra del medio es la que manda en la fila.
const PM_SIZE := 46.0
## Los mismos discos en la FICHA de la habilidad, donde hay sitio de sobra.
const PM_POPUP := 76.0


## Boton redondo de reparto: el VERDE con el "+" (el mismo `boton_mas` de las
## cajas de recursos) y el ROJO con el "-", que es ese MISMO dibujo teñido y
## con el brazo vertical quitado (ver tools/, `make_menos`): antes era un disco
## plano generado aparte y se veía que no eran pareja.
func _make_pm_button(id: String, mas: bool) -> TextureButton:
	var b := TextureButton.new()
	b.name = "Mas" if mas else "Menos"
	b.texture_normal = load("res://assets/ui/boton_%s.png"
		% ("mas" if mas else "menos"))
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(PM_SIZE, PM_SIZE)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	PrepBoard.add_press_feedback(b)
	b.pressed.connect(_on_mas.bind(id) if mas else _on_menos.bind(id))
	return b


## Estados del icono: apagado (prerrequisito sin cumplir), disponible (marco
## neutro), aprendido (marco del color del arbol) y al maximo (marco DORADO).
func _paint_icon(id: String) -> void:
	var b: Button = icon_buttons.get(id)
	if b == null or not is_instance_valid(b):
		return
	var card: Control = b.get_parent()
	var color: Color = b.get_meta("tree_color")
	var rank := GameState.skill_rank(id)
	var bloqueada := false
	for p in SkillData.prereqs(id):
		if GameState.skill_rank(p) <= 0:
			bloqueada = true
	var marco: Panel = b.get_node("Marco")
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(18)
	if rank >= SkillData.MAX_RANK:
		sb.bg_color = ORO
	elif rank > 0:
		sb.bg_color = color
	elif bloqueada:
		sb.bg_color = Color(0.30, 0.26, 0.22)
	else:
		sb.bg_color = Color(0.55, 0.46, 0.34)
	marco.add_theme_stylebox_override("panel", sb)
	var ic: TextureRect = b.get_node("Dibujo")
	ic.modulate = Color(0.35, 0.35, 0.35) if bloqueada else Color.WHITE
	card.modulate.a = 0.62 if bloqueada else 1.0

	var est_host: Control = card.get_node("Estrellas")
	for c in est_host.get_children():
		c.queue_free()
	var fila := PrepBoard.make_star_row(rank, SkillData.MAX_RANK, 26, true)
	fila.set_anchors_preset(Control.PRESET_FULL_RECT)
	est_host.add_child(fila)

	var coste := SkillData.rank_cost(id)
	var fila_b: HBoxContainer = card.get_node("Botones")
	var pts_l: Label = fila_b.get_node("Puntos")
	var bolas: Control = fila_b.get_node("Bolas")
	if rank >= SkillData.MAX_RANK:
		pts_l.text = "MÁX."
		pts_l.add_theme_color_override("font_color", ORO)
		pts_l.visible = true
		bolas.visible = false
	else:
		pts_l.visible = false
		bolas.visible = true
		bolas.set_meta("dados", GameState.skill_points(id) % coste)
		bolas.set_meta("total", coste)
		bolas.queue_redraw()

	var mas: TextureButton = fila_b.get_node("Mas")
	var menos: TextureButton = fila_b.get_node("Menos")
	mas.disabled = not GameState.can_buy_skill(id)
	mas.modulate = Color(1, 1, 1, 0.35) if mas.disabled else Color.WHITE
	menos.disabled = not GameState.can_refund_skill(id)
	menos.modulate = Color(1, 1, 1, 0.35) if menos.disabled else Color.WHITE


func _refresh_all_icons() -> void:
	for id in icon_buttons:
		_paint_icon(str(id))
	# Las ramas y el botón de reinicio dependen del árbol ENTERO, no de una
	# tarjeta: se repintan aquí o se quedan mintiendo tras cada [+] / [−].
	_paint_ramas()
	if reset_btn != null and is_instance_valid(reset_btn):
		reset_btn.disabled = GameState.tree_points(current_tree) <= 0
		PrepBoard.set_dimmed(reset_btn, reset_btn.disabled)


## Las tarjetas ENTRAN en cascada, con un bote cada una.
func _entrada_animada() -> void:
	if not GameState.animations_on():
		return
	var i := 0
	for id in SkillData.tree_skills(current_tree):
		var b: Button = icon_buttons.get(str(id))
		if b == null:
			continue
		var card: Control = b.get_parent()
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(0.2, 0.2)
		var t := card.create_tween()
		t.tween_property(card, "scale", Vector2.ONE, 0.32) \
				.set_delay(0.05 * i).set_trans(Tween.TRANS_BACK) \
				.set_ease(Tween.EASE_OUT)
		i += 1


# ------------------------------------------------------------------ popup

## La ventana de una habilidad: dibujo, nombre, descripción, el efecto de hoy
## y el del siguiente rango, y el reparto con [−] y [+].
func _open_popup(id: String) -> void:
	_close_popup()
	popup_id = id
	popup = Control.new()
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(popup)
	var velo := ColorRect.new()
	Audio.ventana(velo)
	velo.color = Color(0, 0, 0, 0.0)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.add_child(velo)
	velo.create_tween().tween_property(velo, "color:a", 0.55, 0.2)
	# Tocar FUERA cierra (el gesto natural del popup).
	velo.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch and ev.pressed:
			_close_popup())

	var caja := Control.new()
	caja.name = "Caja"
	caja.custom_minimum_size = Vector2(600, 620)
	caja.size = Vector2(600, 620)
	caja.position = Vector2(60.0, (GameState.canvas_size().y - 620.0) * 0.5)
	caja.pivot_offset = caja.size * 0.5
	popup.add_child(caja)
	caja.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))
	# Entrada con rebote, como los carteles del juego.
	caja.scale = Vector2(0.6, 0.6)
	caja.modulate.a = 0.0
	var tw := caja.create_tween().set_parallel(true)
	tw.tween_property(caja, "scale", Vector2.ONE, 0.32) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(caja, "modulate:a", 1.0, 0.16)
	_fill_popup()


## (Re)pinta el contenido del popup con el estado vigente. Se llama al abrir y
## tras cada [+] o [−]: así la ventana no parpadea entera, solo cambia.
func _fill_popup() -> void:
	if popup == null:
		return
	var caja: Control = popup.get_node("Caja")
	for hijo in caja.get_children():
		if hijo.name != "Skin":
			hijo.queue_free()
	var id := popup_id
	var s := SkillData.get_skill(id)
	var color: Color = TREE_COLORS.get(str(s.get("tree", "")), DARK)
	var rank := GameState.skill_rank(id)

	# Cabecera: el dibujo grande con su marco de color + nombre + rangos.
	var marco := Panel.new()
	var sbm := StyleBoxFlat.new()
	sbm.bg_color = ORO if rank >= SkillData.MAX_RANK else color
	sbm.set_corner_radius_all(16)
	marco.add_theme_stylebox_override("panel", sbm)
	marco.position = Vector2(48.0, 42.0)
	marco.size = Vector2(120, 120)
	caja.add_child(marco)
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = SkillData.icon(id)
	ic.position = Vector2(58.0, 50.0)
	ic.size = Vector2(100, 100)
	caja.add_child(ic)

	var nombre := Label.new()
	nombre.text = str(s.get("name", id))
	nombre.position = Vector2(186.0, 46.0)
	nombre.size = Vector2(370.0, 44.0)
	nombre.add_theme_font_size_override("font_size", 30)
	nombre.add_theme_color_override("font_color", DARK)
	caja.add_child(nombre)
	var estrellas := PrepBoard.make_star_row(rank, SkillData.MAX_RANK, 26, true)
	estrellas.position = Vector2(186.0, 96.0)
	estrellas.size = Vector2(200.0, 30.0)
	estrellas.alignment = BoxContainer.ALIGNMENT_BEGIN
	caja.add_child(estrellas)
	# LO QUE FALTA PARA EL SIGUIENTE RANGO, en puntos: es la cuenta que el
	# jugador está haciendo mientras pulsa el [+] de uno en uno.
	var pts := GameState.skill_points(id)
	var coste_l := Label.new()
	if rank >= SkillData.MAX_RANK:
		coste_l.text = "Al máximo (%d puntos)" % pts
	else:
		var faltan := SkillData.points_to_next(id, pts)
		coste_l.text = "%d punto%s para %s" % [faltan, "" if faltan == 1 else "s",
			"aprenderla" if rank == 0 else "el rango %d" % (rank + 1)]
	coste_l.position = Vector2(186.0, 130.0)
	coste_l.size = Vector2(370.0, 30.0)
	coste_l.add_theme_font_size_override("font_size", 18)
	coste_l.add_theme_color_override("font_color", FADED)
	caja.add_child(coste_l)

	var desc := Label.new()
	desc.text = str(s.get("desc", ""))
	desc.position = Vector2(48.0, 186.0)
	# 470 y no más: el marco del pergamino come por la derecha y a 504 la
	# última palabra se le metía debajo (visto en captura).
	desc.size = Vector2(470.0, 84.0)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 20)
	desc.add_theme_color_override("font_color", FADED)
	caja.add_child(desc)

	# Efecto de HOY y del SIGUIENTE rango.
	var y := 278.0
	if rank > 0:
		var hoy := Label.new()
		hoy.text = "Ahora: %s" % SkillData.rank_text(id, rank)
		hoy.position = Vector2(48.0, y)
		hoy.size = Vector2(504.0, 56.0)
		hoy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hoy.add_theme_font_size_override("font_size", 21)
		hoy.add_theme_color_override("font_color", Color(0.24, 0.5, 0.22))
		caja.add_child(hoy)
		y += 62.0
	var bloqueada := false
	var faltan: Array[String] = []
	for p in SkillData.prereqs(id):
		if GameState.skill_rank(p) <= 0:
			bloqueada = true
			faltan.append(str(SkillData.get_skill(p).get("name", p)))
	if bloqueada:
		var req := Label.new()
		req.text = "Requiere: %s" % ", ".join(faltan)
		req.position = Vector2(48.0, y)
		req.size = Vector2(504.0, 56.0)
		req.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		req.add_theme_font_size_override("font_size", 21)
		req.add_theme_color_override("font_color", Color(0.7, 0.3, 0.2))
		caja.add_child(req)
	elif rank < SkillData.MAX_RANK:
		var prox := Label.new()
		prox.text = "%s: %s" % ["Al aprender" if rank == 0 else "Siguiente",
			SkillData.rank_text(id, rank + 1)]
		prox.position = Vector2(48.0, y)
		prox.size = Vector2(504.0, 56.0)
		prox.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		prox.add_theme_font_size_override("font_size", 21)
		prox.add_theme_color_override("font_color", AZUL)
		caja.add_child(prox)

	# El REPARTO: [−]  n/5  [+], con los puntos libres debajo.
	var fila := HBoxContainer.new()
	fila.set_anchors_preset(Control.PRESET_TOP_WIDE)
	fila.offset_top = 428.0
	fila.offset_bottom = 500.0
	fila.offset_left = 90.0
	fila.offset_right = -90.0
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 26)
	caja.add_child(fila)

	# LOS MISMOS DISCOS QUE LA REJILLA (`_make_pm_button`), no botones de madera
	# con un signo escrito: eran dos mandos distintos para lo mismo y el
	# jugador que venía de la tarjeta no los reconocía. Aquí van más grandes,
	# que hay sitio de sobra.
	var puede_quitar := GameState.can_refund_skill(id)
	var menos := _make_pm_button(id, false)
	menos.custom_minimum_size = Vector2(PM_POPUP, PM_POPUP)
	menos.disabled = not puede_quitar
	menos.modulate = Color(1, 1, 1, 0.35) if menos.disabled else Color.WHITE
	fila.add_child(menos)

	# En el centro, los PUNTOS invertidos sobre el total (es lo que mueve el
	# [+]); el rango, debajo en pequeño, es su consecuencia.
	var centro := VBoxContainer.new()
	centro.custom_minimum_size = Vector2(150, 0)
	centro.alignment = BoxContainer.ALIGNMENT_CENTER
	centro.add_theme_constant_override("separation", -2)
	fila.add_child(centro)
	var pts_l := Label.new()
	pts_l.text = "%d / %d" % [pts, SkillData.max_points(id)]
	pts_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pts_l.add_theme_font_size_override("font_size", 36)
	pts_l.add_theme_color_override("font_color",
		ORO if rank >= SkillData.MAX_RANK else DARK)
	centro.add_child(pts_l)
	var rango_l := Label.new()
	rango_l.text = "rango %d de %d" % [rank, SkillData.MAX_RANK]
	rango_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rango_l.add_theme_font_size_override("font_size", 17)
	rango_l.add_theme_color_override("font_color", FADED)
	centro.add_child(rango_l)

	var mas := _make_pm_button(id, true)
	mas.custom_minimum_size = Vector2(PM_POPUP, PM_POPUP)
	mas.disabled = not GameState.can_buy_skill(id)
	mas.modulate = Color(1, 1, 1, 0.35) if mas.disabled else Color.WHITE
	fila.add_child(mas)

	var libres := Label.new()
	libres.text = "Te quedan %d puntos de maestría" % GameState.chef_points_free()
	libres.set_anchors_preset(Control.PRESET_TOP_WIDE)
	libres.offset_top = 506.0
	libres.offset_bottom = 536.0
	libres.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	libres.add_theme_font_size_override("font_size", 19)
	libres.add_theme_color_override("font_color", FADED)
	caja.add_child(libres)
	# El motivo de un [−] apagado, dicho en corto.
	if rank > 0 and not puede_quitar:
		var pista := Label.new()
		pista.text = "Sostiene a otra habilidad aprendida."
		pista.set_anchors_preset(Control.PRESET_TOP_WIDE)
		pista.offset_top = 536.0
		pista.offset_bottom = 562.0
		pista.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pista.add_theme_font_size_override("font_size", 17)
		pista.add_theme_color_override("font_color", Color(0.7, 0.3, 0.2))
		caja.add_child(pista)

	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.custom_minimum_size = Vector2(200, 58)
	PrepBoard.skin_small_button(cerrar)
	cerrar.add_theme_font_size_override("font_size", 22)
	cerrar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	cerrar.offset_left = 200.0
	cerrar.offset_right = -200.0
	cerrar.offset_top = 548.0
	cerrar.offset_bottom = 596.0
	cerrar.pressed.connect(_close_popup)
	caja.add_child(cerrar)


func _close_popup() -> void:
	if popup != null:
		popup.queue_free()
		popup = null
		popup_id = ""


## [+]: invierte UN punto. El rango sube solo cuando la inversión cruza su
## listón, y CADA SUBIDA se celebra con su ventana (la del rango 1 dice
## "aprendida"; las demás cantan el cambio, un 4% que pasa a 8%).
func _on_mas(id: String) -> void:
	var era := GameState.skill_rank(id)
	if not GameState.buy_skill(id):
		return
	_pop_puntos()
	_refresh_header()
	_refresh_all_icons()
	_fill_popup()
	_burst_icon(id)
	var ahora := GameState.skill_rank(id)
	if ahora > era:
		_celebrar_rango(id, era, ahora)


## [−]: recupera UN punto. Si ESE punto es el que sostiene el rango 1, pregunta
## antes: perder la habilidad es una decisión, no un resbalón.
func _on_menos(id: String) -> void:
	if GameState.skill_points(id) == SkillData.rank_cost(id):
		_confirmar_perdida(id)
		return
	if GameState.refund_skill(id):
		_pop_puntos()
		_refresh_header()
		_refresh_all_icons()
		_fill_popup()


func _confirmar_perdida(id: String) -> void:
	var s := SkillData.get_skill(id)
	var overlay := ColorRect.new()
	Audio.ventana(overlay)
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := Control.new()
	box.custom_minimum_size = Vector2(540, 320)
	center.add_child(box)
	box.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 50.0
	vb.offset_top = 42.0
	vb.offset_right = -50.0
	vb.offset_bottom = -42.0
	vb.add_theme_constant_override("separation", 16)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(vb)
	var titulo := PrepBoard.make_big_title("¿Perderla?", 46)
	titulo.custom_minimum_size = Vector2(0, 62)
	vb.add_child(titulo)
	var msg := Label.new()
	msg.text = "Vas a perder %s: este punto es el que la sostiene.\n¿Estás seguro?" \
		% str(s.get("name", id))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 21)
	msg.add_theme_color_override("font_color", FADED)
	vb.add_child(msg)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 20)
	vb.add_child(btns)
	var si := Button.new()
	si.text = "Perderla"
	si.custom_minimum_size = Vector2(190, 62)
	PrepBoard.skin_action_button(si, false)
	si.add_theme_font_size_override("font_size", 22)
	si.pressed.connect(func() -> void:
		overlay.queue_free()
		if GameState.refund_skill(id):
			_pop_puntos()
			_refresh_header()
			_refresh_all_icons()
			_fill_popup())
	btns.add_child(si)
	var no := Button.new()
	no.text = "Quedármela"
	no.custom_minimum_size = Vector2(190, 62)
	PrepBoard.skin_action_button(no, true)
	no.add_theme_font_size_override("font_size", 22)
	no.pressed.connect(overlay.queue_free)
	btns.add_child(no)


## "Reiniciar maestría": PREGUNTA, y diciendo cuántos puntos se recuperan — es
## un botón que deshace media hora de reparto de un toque.
func _confirmar_reinicio(tree: String) -> void:
	var puestos := GameState.tree_points(tree)
	if puestos <= 0:
		return
	var nombre := ""
	for t in SkillData.TREES:
		if str(t["id"]) == tree:
			nombre = str(t.get("name", tree))
	var overlay := ColorRect.new()
	Audio.ventana(overlay)
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := Control.new()
	box.custom_minimum_size = Vector2(540, 340)
	center.add_child(box)
	box.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 50.0
	vb.offset_top = 42.0
	vb.offset_right = -50.0
	vb.offset_bottom = -42.0
	vb.add_theme_constant_override("separation", 16)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(vb)
	var titulo := PrepBoard.make_big_title("¿Reiniciar?", 46)
	titulo.custom_minimum_size = Vector2(0, 62)
	vb.add_child(titulo)
	var msg := Label.new()
	msg.text = ("Se van a quitar TODAS las habilidades de %s.\n"
		+ "Recuperas %d punto%s para repartirlos como quieras.") \
		% [nombre.to_lower(), puestos, "" if puestos == 1 else "s"]
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 21)
	msg.add_theme_color_override("font_color", FADED)
	vb.add_child(msg)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 20)
	vb.add_child(btns)
	var si := Button.new()
	si.text = "Reiniciar"
	si.custom_minimum_size = Vector2(190, 62)
	PrepBoard.skin_action_button(si, false)
	si.add_theme_font_size_override("font_size", 22)
	si.pressed.connect(func() -> void:
		overlay.queue_free()
		if GameState.reset_skill_tree(tree) > 0:
			_close_popup()
			_pop_puntos()
			_refresh_header()
			# Se reconstruye la sección entera: con el árbol a cero cambian
			# también los marcos y las RAMAS, que no se repintan solas.
			_build_section())
	btns.add_child(si)
	var no := Button.new()
	no.text = "Dejarlo"
	no.custom_minimum_size = Vector2(190, 62)
	PrepBoard.skin_action_button(no, true)
	no.add_theme_font_size_override("font_size", 22)
	no.pressed.connect(overlay.queue_free)
	btns.add_child(no)


## La ventana de SUBIDA DE RANGO: el dibujo entra con un golpe de rebote y una
## corona de estrellas, como el cartel del coleccionable. La del rango 1 dice
## "aprendida"; las demás CANTAN EL CAMBIO, con el efecto de antes tachado y el
## nuevo debajo — que es lo que el jugador quiere saber al gastar un punto.
func _celebrar_rango(id: String, antes: int, ahora: int) -> void:
	Audio.sfx("habilidad")
	var s := SkillData.get_skill(id)
	var color: Color = TREE_COLORS.get(str(s.get("tree", "")), DARK)
	# Las dos variantes acaban en el mismo sitio (efecto + botón), así que el
	# cartel mide lo mismo: el botón tiene que caer DENTRO del papel, no sobre
	# el canto de madera.
	var alto := 552.0
	var overlay := ColorRect.new()
	Audio.ventana(overlay)
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	var box := Control.new()
	box.custom_minimum_size = Vector2(520, alto)
	box.size = Vector2(520, alto)
	box.position = Vector2(100.0, (GameState.canvas_size().y - alto) * 0.5)
	box.pivot_offset = box.size * 0.5
	overlay.add_child(box)
	box.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))
	var titulo := PrepBoard.make_big_title(
		"¡Habilidad\naprendida!" if antes <= 0 else "¡Rango %d!" % ahora, 40)
	titulo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	titulo.offset_top = 36.0
	titulo.offset_bottom = 140.0
	box.add_child(titulo)
	var marco := Panel.new()
	var sbm := StyleBoxFlat.new()
	sbm.bg_color = color
	sbm.set_corner_radius_all(18)
	marco.add_theme_stylebox_override("panel", sbm)
	marco.position = Vector2((520.0 - 136.0) * 0.5, 152.0)
	marco.size = Vector2(136, 136)
	marco.pivot_offset = Vector2(68, 68)
	box.add_child(marco)
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = SkillData.icon(id)
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 10.0
	ic.offset_top = 10.0
	ic.offset_right = -10.0
	ic.offset_bottom = -10.0
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco.add_child(ic)
	marco.scale = Vector2(0.2, 0.2)
	marco.create_tween().tween_property(marco, "scale", Vector2.ONE, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.1)
	# Corona de estrellas alrededor del marco.
	for i in 8:
		var e := TextureRect.new()
		e.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		e.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		e.texture = load("res://assets/ui/estrella_llena.png")
		e.size = Vector2(30, 30)
		e.position = Vector2(245.0, 205.0)
		e.pivot_offset = Vector2(15, 15)
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(e)
		var ang := TAU * float(i) / 8.0
		var te := e.create_tween().set_parallel(true)
		te.tween_property(e, "position",
			e.position + Vector2(cos(ang), sin(ang)) * randf_range(120.0, 170.0),
			0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.14)
		te.tween_property(e, "rotation_degrees", randf_range(-220.0, 220.0), 0.7) \
				.set_delay(0.14)
		te.tween_property(e, "modulate:a", 0.0, 0.55).set_delay(0.3)
		te.chain().tween_callback(e.queue_free)
	var nombre := Label.new()
	nombre.text = str(s.get("name", id))
	nombre.set_anchors_preset(Control.PRESET_TOP_WIDE)
	nombre.offset_top = 298.0
	nombre.offset_bottom = 336.0
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre.add_theme_font_size_override("font_size", 28)
	nombre.add_theme_color_override("font_color", DARK)
	box.add_child(nombre)
	# EL CAMBIO, cuando lo hay: lo que hacía y lo que hace ahora, uno debajo
	# del otro. En el rango 1 no hay "antes" que enseñar, así que lo que va es
	# QUÉ HACE la habilidad recién aprendida — el nombre solo no lo dice, y es
	# justo lo que el jugador acaba de comprar sin verlo.
	var y_boton := 352.0
	if antes <= 0:
		var estreno := Label.new()
		estreno.text = SkillData.rank_text(id, ahora)
		estreno.set_anchors_preset(Control.PRESET_TOP_WIDE)
		estreno.offset_left = 40.0
		estreno.offset_right = -40.0
		estreno.offset_top = 340.0
		estreno.offset_bottom = 400.0
		estreno.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		estreno.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		estreno.add_theme_font_size_override("font_size", 22)
		estreno.add_theme_color_override("font_color", Color(0.20, 0.48, 0.18))
		box.add_child(estreno)
		var pie := Label.new()
		pie.text = str(s.get("desc", ""))
		pie.set_anchors_preset(Control.PRESET_TOP_WIDE)
		pie.offset_left = 44.0
		pie.offset_right = -44.0
		pie.offset_top = 402.0
		pie.offset_bottom = 448.0
		pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pie.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pie.add_theme_font_size_override("font_size", 18)
		pie.add_theme_color_override("font_color", FADED)
		box.add_child(pie)
		y_boton = 452.0
	if antes > 0:
		var viejo := Label.new()
		viejo.text = SkillData.rank_text(id, antes)
		viejo.set_anchors_preset(Control.PRESET_TOP_WIDE)
		viejo.offset_left = 40.0
		viejo.offset_right = -40.0
		viejo.offset_top = 340.0
		viejo.offset_bottom = 376.0
		viejo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		viejo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		viejo.add_theme_font_size_override("font_size", 19)
		viejo.add_theme_color_override("font_color", Color(0.55, 0.45, 0.35))
		box.add_child(viejo)
		var flecha := Label.new()
		flecha.text = "▼"
		flecha.set_anchors_preset(Control.PRESET_TOP_WIDE)
		flecha.offset_top = 378.0
		flecha.offset_bottom = 402.0
		flecha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		flecha.add_theme_font_size_override("font_size", 20)
		flecha.add_theme_color_override("font_color", Color(0.24, 0.5, 0.22))
		box.add_child(flecha)
		var nuevo := Label.new()
		nuevo.text = SkillData.rank_text(id, ahora)
		nuevo.set_anchors_preset(Control.PRESET_TOP_WIDE)
		nuevo.offset_left = 40.0
		nuevo.offset_right = -40.0
		nuevo.offset_top = 404.0
		nuevo.offset_bottom = 448.0
		nuevo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nuevo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nuevo.add_theme_font_size_override("font_size", 22)
		nuevo.add_theme_color_override("font_color", Color(0.20, 0.48, 0.18))
		box.add_child(nuevo)
		y_boton = 452.0
	var seguir := Button.new()
	seguir.text = "Continuar"
	PrepBoard.skin_button(seguir)
	seguir.add_theme_font_size_override("font_size", 24)
	seguir.set_anchors_preset(Control.PRESET_TOP_WIDE)
	seguir.offset_left = 150.0
	seguir.offset_right = -150.0
	seguir.offset_top = y_boton
	seguir.offset_bottom = y_boton + 62.0
	seguir.pressed.connect(overlay.queue_free)
	box.add_child(seguir)
	box.scale = Vector2(0.6, 0.6)
	box.modulate.a = 0.0
	var tw := box.create_tween().set_parallel(true)
	tw.tween_property(box, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "modulate:a", 1.0, 0.18)


## Bote del icono de la rejilla al subirle un rango (se ve detrás del popup).
func _burst_icon(id: String) -> void:
	var b: Button = icon_buttons.get(id)
	if b == null:
		return
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(1.3, 1.3), 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
