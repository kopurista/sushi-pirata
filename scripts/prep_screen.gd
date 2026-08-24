extends Node3D
## Fase de preparación: elegir 4 recetas de todas las disponibles.
## El fondo es el ESCENARIO 3D del nivel elegido (isla, puerto o barco
## enemigo) meciéndose sobre el mar; la selección va en un CanvasLayer 2D.
## Las recetas se agrupan por nivel de estrellas (progresión de descubrimiento),
## con 4 tarjetas compactas por fila. TODAS comparten un único pergamino largo:
## el pergamino forma parte del contenido scrolleable (no es un fondo fijo), con
## la altura de todo el contenido, así al desplazarse el borde superior se pierde
## y el inferior aparece, dando la sensación de recorrer un pergamino entero.

const PrepBoard := preload("res://scripts/prep_board.gd")

const MAX_RECIPES := 4
## Huecos de receta de ESTE nivel: algunos puertos dan menos (el 3 solo da 3).
var slots := MAX_RECIPES
const DARK := Color(0.26, 0.16, 0.08)
const CARDS_PER_ROW := 4
## Grosor del marco de cuerda del pergamino: hueco que se deja alrededor del
## contenido para que nada (estrellas, platos ni nombres) se salga del interior
## utilizable del pergamino. El inferior es mayor para que los nombres de dos
## líneas nunca queden por encima de la cuerda de abajo.
const FRAME_SIDE := 52.0
const FRAME_TOP := 44.0
const FRAME_BOTTOM := 54.0

var selected: Array[String] = []
## Potenciadores permanentes marcados para esta travesía.
var perks_selected: Array[String] = []
## Pivote del modelo 3D del fondo (se mece con el oleaje).
var backdrop: Node3D = null
var leaving := false
## Fila de bonificadores (se rehace si el aviso previo regala uno).
var perk_bar: Control = null
## Gigi ya ha avisado de que la carta no lleva platos de dos estrellas.
var _avisado_piratas := false
## Tarjetas ELEGIBLES por id, para poder apagarlas cuando la carta se llena.
var recipe_cards: Dictionary = {}
## CARTA CERRADA de una isla. Con esto puesto la pantalla no deja elegir
## recetas —salen las del escenario, marcadas y apagadas— y lo único que se
## decide aquí es el bonificador.
var carta_fija: Array[String] = []
var _t := 0.0

@onready var content: Control = $UI/Root/Margin/VBox/Scroll/Content
@onready var sections: VBoxContainer = $UI/Root/Margin/VBox/Scroll/Content/Sections
@onready var count_label: Label = $UI/Root/Margin/VBox/CountLabel
@onready var start_button: Button = $UI/Root/StartButton




func _ready() -> void:
	Engine.max_fps = GameState.fps_for(false)
	var board_script := load("res://scripts/prep_board.gd")
	# En Arcade el fondo es SOLO EL MAR ("mar"): el barco acaba de salir por la
	# derecha en la transición del menú, así que verlo aquí otra vez rompía el
	# encadenado. En aventura, el escenario del nivel elegido.
	var kind := CampaignData.get_kind(GameState.current_port) \
			if GameState.is_adventure() else "mar"
	# EL SELECTOR YA SUENA AL SITIO AL QUE SE VA. Elegir carta es parte del
	# viaje, no un menú aparte: con el tema del destino puesto desde aquí, la
	# transición al nivel no corta la música y el jugador ya sabe si le espera
	# una playa o un abordaje antes de pulsar "¡Zarpar!".
	Audio.musica("arcade" if GameState.is_arcade()
			else (kind if Audio.TEMAS.has(kind) else "menu"))
	# El escenario va CENTRADO en la pantalla (band_off 0): arriba lo tapaba el
	# pergamino con la parrilla de recetas.
	backdrop = SceneBackdrop.build(self, kind, 19.0, -230.0)
	if GameState.is_adventure():
		# El recorte de huecos de un puerto (`recipe_slots`) es parte de su
		# reto la PRIMERA vez; al repetirlo ya superado se juega con los cuatro
		# de siempre.
		var puerto := CampaignData.get_port(GameState.current_port)
		slots = MAX_RECIPES if GameState.port_beaten(GameState.current_port) \
				else int(puerto.get("recipe_slots", MAX_RECIPES))
		# Las ISLAS traen la carta puesta por el diseño (ver `fixed_recipes`).
		carta_fija.assign(CampaignData.fixed_recipes_for(GameState.current_port,
				GameState.port_beaten(GameState.current_port)))
		if not carta_fija.is_empty():
			slots = carta_fija.size()
	# La lista de recetas se recorre con el DEDO (con inercia): el
	# ScrollContainer de Godot no se arrastra con eventos táctiles.
	TouchScroll.attach($UI/Root/Margin/VBox/Scroll)
	# Bajo el notch del movil: el contenido baja el area segura y el velo se
	# estira hacia arriba para cubrir tambien esa franja.
	$UI/Root/Margin.offset_top += GameState.safe_top()
	$UI/Root/Shade.offset_top = -GameState.safe_top()
	_add_shared_parchment()
	# Solo las recetas DESBLOQUEADAS, también en el arcade: desde que el modo
	# gasta arroz y despensa es una jornada de verdad, y jugar con recetas que
	# no son tuyas rompía además el fondo de fichajes de sus mejoras.
	var available: Array = []
	for id in RecipeData.RECIPES:
		# El barco combinado no se elige aquí: se monta en partida con los
		# platos que haya en las cajas.
		if RecipeData.RECIPES[id].get("hidden", false):
			continue
		if GameState.is_recipe_unlocked(id):
			available.append(id)
	# En aventura cada puerto tiene su carta: las islas de menú cerrado solo
	# dejan sus recetas, y el resto no adelanta las de puertos posteriores.
	if GameState.is_adventure():
		var permitidas := CampaignData.recipes_for_port(GameState.current_port,
				GameState.port_beaten(GameState.current_port))
		var filtradas: Array = []
		for id in available:
			if id in permitidas:
				filtradas.append(id)
		available = filtradas
		# RED DE SEGURIDAD DE LA ESCUELA: mientras no haya TIENDA (nivel 4) el
		# jugador no tiene dónde reponer, así que quedarse sin NINGUNA receta
		# jugable sería un callejón sin salida. David rellena lo que falte.
		# Con carta cerrada, la parrilla enseña SOLO lo que se lleva hoy: el
		# resto del recetario no pinta nada cuando no se puede elegir.
		if not carta_fija.is_empty():
			available = carta_fija.duplicate()
		if not GameState.shop_unlocked() and not available.is_empty():
			var jugable := false
			for id in available:
				if GameState.has_ingredients_for(id):
					jugable = true
					break
			if not jugable:
				_rescate_de_david(available)
	# Agrupadas por nivel (1★, 2★, 3★); dentro de cada grupo, por precio.
	var by_level: Dictionary = {}
	for id in available:
		var lv: int = int(RecipeData.RECIPES[id].get("level", 1))
		by_level.get_or_add(lv, []).append(id)
	for lv in [1, 2, 3]:
		if not by_level.has(lv):
			continue
		var ids: Array = by_level[lv]
		ids.sort_custom(func(a: String, b: String) -> bool:
			return RecipeData.RECIPES[a].price < RecipeData.RECIPES[b].price)
		sections.add_child(_build_section_header(board_script, lv))
		var grid := GridContainer.new()
		grid.columns = CARDS_PER_ROW
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 14)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for id in ids:
			grid.add_child(_build_card(id, board_script))
		sections.add_child(grid)
	_add_top_bar(board_script)
	# CON LA CARTA CERRADA NO SE ELIGE NADA: el subtitulo de siempre ("elige
	# las recetas...") mandaba a hacer algo que la pantalla no deja hacer.
	if not carta_fija.is_empty():
		var sub: Label = $UI/Root/Margin/VBox/Subtitle
		sub.text = "La carta la manda la isla: elige tu bonificador"
	_build_info_row()
	# La selección automática no pinta nada con la carta cerrada: no hay nada
	# que seleccionar.
	if carta_fija.is_empty():
		_add_auto_button(board_script)
	else:
		_marcar_carta_fija()
	_add_perk_bar(board_script)
	_skin_start_button(board_script)
	start_button.pressed.connect(_on_start_pressed)
	# El pergamino debe crecer con el contenido; se reajusta cada vez que la
	# lista cambia de tamaño (envoltura de nombres, etc.).
	sections.resized.connect(_update_content_size)
	call_deferred("_update_content_size")
	_update_ui()
	if GameState.take_transition() == "arcade":
		call_deferred("_play_intro")
	_aviso_antes_de_zarpar.call_deferred()


## Algunos puertos traen un aviso de David ANTES de elegir la carta
## (`prep_dialog` en CampaignData). Como los guiones dentro del nivel, solo
## suena la primera vez: si el puerto ya está superado, el jugador sabe de sobra
## a lo que va.
func _aviso_antes_de_zarpar() -> void:
	if not GameState.is_adventure():
		return
	var port := CampaignData.get_port(GameState.current_port)
	var guion := str(port.get("prep_dialog", ""))
	if guion == "":
		return
	var superado: bool = int(GameState.level_stars.get(GameState.current_port, 0)) \
			>= int(port.get("goal_stars", 1))
	if superado:
		return
	var lineas: Array = []
	match guion:
		"nivel_13":
			# NADA de bonificadores aqui: todavia no existen. Se abren DESPUES de
			# este escenario, cuando Alice se enrola (ver `main_menu._presentar_alice`).
			lineas = [
				{ "text": "Un abordaje de los gordos, %s: reloj corriendo y gente subiendo sin parar. Hoy vas a echar de menos un segundo par de manos." % GameState.player_title(), "mood": "serio" },
				{ "text": "Llévate una carta VARIADA: con esta clientela vas a repetir plato antes de darte cuenta.", "mood": "hablando" },
			]
		"nivel_14":
			# NADA DEL BARCO AQUÍ: se aprende en el mar 2. Lo que este puerto
			# estrena es la fila de BONIFICADORES de esta misma pantalla, que
			# hasta que llegó Alice no existía.
			lineas = [
				{ "text": "Fíjate ahí abajo, %s: desde que Alice se enroló tienes la fila de **bonificadores**." % GameState.player_title(), "mood": "hablando" },
				{ "text": "Se eligen aquí, junto con la carta, y cada uno gasta **un uso** por jornada. Ponte el que te convenga antes de zarpar.", "mood": "serio" },
				{ "text": "¡QUE TE LO PONGAS! ¡RAAAK!", "who": "gigi", "mood": "loro" },
			]
		"nivel_4":
			# La primera vez que el jugador PISA el selector: hasta aquí las
			# tres islas venían con la carta puesta.
			lineas = [
				{ "text": "¡Tu primera **carta a elegir**! En los puertos decides tú qué recetas llevas: toca un pergamino para subirlo al barco.", "mood": "feliz" },
				{ "text": "Hoy solo caben **tres**, y vas a servir a ocho grumetes. Piénsatelo: con pocas recetas se repite mucho.", "mood": "serio" },
				{ "text": "Cada receta que embarques gasta **un uso** de sus ingredientes de la despensa, así que mira también lo que te queda.", "mood": "hablando" },
				{ "text": "¡ELIGE BIEN! ¡RAAAK!", "who": "gigi", "mood": "loro" },
			]
		"nivel_10":
			lineas = [
				{ "text": "Antes de zarpar, escúchame bien: hoy abordamos la **flota de Pablo el Rubio**.", "mood": "serio" },
				{ "text": "Pablo es un viejo amigo mío, pero de los que se ríen mientras te cobran. Y es **capitán**, así que come de tres estrellas.", "mood": "hablando" },
				{ "text": "Solo puedes llevar **tres recetas**. Carga sobre todo platos de **una y dos estrellas**: son los que sacas rápido y los que van a comer los grumetes y los piratas.", "mood": "hablando" },
				{ "text": "De lo gordo ya me encargo yo cuando llegue Pablo. Tú confía y cocina.", "mood": "feliz" },
				{ "text": "¡CONFÍA Y COCINA! ¡RAAAK!", "who": "gigi", "mood": "loro" },
			]
		"nivel_15":
			lineas = [
				{ "text": "Estas aguas... las conozco. Aquí vive el **Kappa**: un espíritu del río con más hambre que toda mi tripulación junta.", "mood": "serio" },
				{ "text": "Come de TODO — una, dos y tres estrellas — pero se **aburre rapidísimo**. Llévale la carta más **variada** que puedas.", "mood": "hablando" },
				{ "text": "Y ni se te ocurra ofrecerle postre: al Kappa no se le despide. Se le **alimenta**.", "mood": "sorprendido" },
				{ "text": "¡DIEZ PLATOS O AL AGUA! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
			]
		_:
			return
	var caja := DialogueBox.new()
	$UI.add_child(caja)
	caja.say(lineas)
	await caja.finished
	caja.queue_free()


# ------------------------------------------------------- entrada y salida

## Viniendo del menú (Arcade), el panel de recetas BAJA desde arriba, el botón
## de zarpar sube desde abajo y los textos se encienden.
##
## Se anima `Margin` (hijo directo de Root) y el botón, que está FUERA del
## VBox: un contenedor recoloca a sus hijos cada frame, así que animarles la
## posición no sirve de nada — el panel se quedaba fuera de la pantalla.
func _play_intro() -> void:
	# Se llega con la pantalla EN NEGRO: el velo es del autoload (GameState) y
	# sigue puesto durante la carga, así que aquí no hace falta ninguno propio.
	# Él solo se abre; esto es lo que entra por debajo.
	var panel: Control = $UI/Root/Margin
	var shade: ColorRect = $UI/Root/Shade
	panel.position.y -= 1500.0
	start_button.position.y += 340.0
	shade.color.a = 0.0

	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "position:y", 1500.0, 0.8).as_relative() 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(start_button, "position:y", -340.0, 0.6).as_relative() 			.set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(shade, "color:a", 0.42, 0.5)


## "Atrás" en Arcade: justo lo contrario, y el menú recoge el testigo para
## traer de vuelta el barco, el logotipo y sus botones.
func _leave_to_menu() -> void:
	if leaving:
		return
	leaving = true
	var panel: Control = $UI/Root/Margin
	var shade: ColorRect = $UI/Root/Shade
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "position:y", -1500.0, 0.55).as_relative() 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(start_button, "position:y", 340.0, 0.5).as_relative() 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(shade, "color:a", 0.0, 0.5)
	tw.chain().tween_callback(func() -> void:
		GameState.transition = "menu"
		GameState.fade_to_scene("res://scenes/main_menu.tscn", 0.3, 0.45))


## Barra superior: botón de volver a la pantalla anterior y, en aventura, el
## nombre del nivel.
func _add_top_bar(board_script: GDScript) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	# Flecha DIBUJADA en la madera (PrepBoard.make_back_button): es el
	# único botón del juego con icono propio, para no confundirlo con
	# un botón normal más.
	var back := PrepBoard.make_back_button()
	# La pantalla anterior es el mapa en aventura y el menú en Arcade; al menú
	# se vuelve con la transición animada, deshaciendo la de entrada.
	back.pressed.connect(func() -> void:
		if GameState.is_adventure():
			GameState.transition = "mapa"
			GameState.fade_to_scene("res://scenes/main_menu.tscn", 0.3, 0.45)
		else:
			_leave_to_menu())
	bar.add_child(back)
	if GameState.is_adventure():
		var port := CampaignData.get_port(GameState.current_port)
		var title := Label.new()
		title.text = port.get("name", "")
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 28)
		title.add_theme_color_override("font_color", Color(1, 0.95, 0.82))
		title.add_theme_color_override("font_outline_color", Color(0.2, 0.12, 0.05))
		title.add_theme_constant_override("outline_size", 6)
		bar.add_child(title)
		# Hueco simétrico al botón para que el título quede centrado.
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(150, 0)
		bar.add_child(spacer)
	var vbox: VBoxContainer = $UI/Root/Margin/VBox
	vbox.add_child(bar)
	vbox.move_child(bar, 0)


## El escenario del fondo se mece con el oleaje.
func _process(delta: float) -> void:
	_t += delta
	if backdrop != null and GameState.animations_on():
		backdrop.rotation_degrees.y = sin(_t * 0.18) * 6.0
		backdrop.rotation_degrees.z = sin(_t * 0.7) * 1.4
		backdrop.position.y = -0.1 + sin(_t * 0.9) * 0.07


## Potenciadores permanentes disponibles para esta travesía: se eligen a la vez
## que las recetas y gastan 1 uso al zarpar. Solo en aventura (el modo Arcade
## no toca el progreso).
func _add_perk_bar(board_script: GDScript) -> void:
	# También en el ARCADE: desde que cobra arroz y despensa es una jornada de
	# verdad y se juega con todo puesto — bonificadores incluidos, con sus
	# usos gastados.
	if not (GameState.is_adventure() or GameState.is_arcade()):
		return
	var ids: Array = []
	for id in PerkData.ids():
		if GameState.is_perk_unlocked(id) and GameState.get_perk_uses(id) > 0:
			ids.append(id)
	if ids.is_empty():
		return

	var box := VBoxContainer.new()
	perk_bar = box
	box.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "Bonificadores"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 7)
	box.add_child(title)

	# LA FILA SE ENVUELVE (HFlowContainer), no es un HBox. Con cuatro
	# bonificadores desbloqueados, cuatro chapas de 216 miden 900 px: el HBox no
	# encoge a sus hijos por debajo de su minimo, asi que estiraba el VBox de
	# toda la pantalla y DESCUADRABA la parrilla de recetas hacia la izquierda
	# ademas de salirse por los dos cantos. Envolviendo caben tres por renglon.
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 8)
	box.add_child(row)
	for id in ids:
		row.add_child(_build_perk_card(id, board_script))

	var vbox: VBoxContainer = $UI/Root/Margin/VBox
	vbox.add_child(box)


func _build_perk_card(id: String, board_script: GDScript) -> Button:
	var data := PerkData.get_perk(id)
	var b := Button.new()
	b.toggle_mode = true
	# DOS POR RENGLÓN, no tres. La chapa lleva 36 téxeles de marco por cada
	# lado, así que de un botón de 216 solo quedan ~120 px de cara útil y
	# "Ayudante de cocina" se salía por encima del latón. A 336 caben dos por
	# renglón (672 + separación) y el nombre entra de una pieza.
	b.custom_minimum_size = Vector2(336, 86)
	b.tooltip_text = str(data.get("desc", ""))
	board_script.skin_perk_button(b)

	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(str(data.get("icon", "")))
	icon.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	# Por DENTRO del marco de la chapa (36 téxeles), no encima de él.
	icon.offset_left = 30.0
	icon.offset_right = 82.0
	icon.offset_top = 14.0
	icon.offset_bottom = -14.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)

	var name_l := Label.new()
	name_l.text = "%s\nx%d" % [data.get("name", id), GameState.get_perk_uses(id)]
	name_l.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_l.offset_left = 90.0
	name_l.offset_right = -26.0
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 18)
	# GRABADO sobre el latón: letra oscura con reborde claro. En crema, como
	# sobre la madera, se perdía en la chapa.
	name_l.add_theme_color_override("font_color", Color(0.27, 0.15, 0.04))
	name_l.add_theme_color_override("font_outline_color", Color(1, 0.93, 0.70))
	name_l.add_theme_constant_override("outline_size", 5)
	name_l.add_theme_constant_override("line_spacing", -2)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name_l)

	# Marco verde cuando está activado.
	var hl := Panel.new()
	hl.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.9, 0.35, 0.16)
	sb.set_border_width_all(4)
	sb.border_color = Color(0.4, 1.0, 0.45)
	sb.set_corner_radius_all(10)
	hl.add_theme_stylebox_override("panel", sb)
	hl.visible = false
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hl)

	b.toggled.connect(func(on: bool) -> void:
		hl.visible = on
		if on:
			if not id in perks_selected:
				perks_selected.append(id)
		else:
			perks_selected.erase(id))
	return b


## Pergamino único y alargado (mismo estilo que el panel de fin de nivel) que
## enmarca TODAS las recetas. Va DENTRO del contenido scrolleable, con la altura
## total del contenido: el marco superior/inferior solo se ve en los extremos y
## el centro se estira, así al desplazarse se recorre todo el pergamino.
func _add_shared_parchment() -> void:
	var parch := NinePatchRect.new()
	parch.name = "Parchment"
	parch.texture = load(PrepBoard.PANEL_TEX)
	parch.patch_margin_left = PrepBoard.PANEL_MARGIN
	parch.patch_margin_top = PrepBoard.PANEL_MARGIN
	parch.patch_margin_right = PrepBoard.PANEL_MARGIN
	parch.patch_margin_bottom = PrepBoard.PANEL_MARGIN
	parch.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Tinte cálido leve para un aire de pergamino viejo y desgastado.
	parch.modulate = Color(0.97, 0.93, 0.85)
	parch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(parch)
	content.move_child(parch, 0)


## Ajusta la altura del contenido (y por tanto del pergamino) a la de la lista
## de recetas más el marco de cuerda arriba y abajo.
func _update_content_size() -> void:
	var h := sections.get_combined_minimum_size().y
	content.custom_minimum_size = Vector2(0, h + FRAME_TOP + FRAME_BOTTOM)


## Cabecera de sección: fila de estrellas que separa cada nivel de dificultad.
func _build_section_header(board_script: GDScript, level: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var stars: HBoxContainer = board_script.make_star_row(level, level, 26)
	stars.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(stars)
	return row


## Botón de zarpar con el mismo tablón de madera y marco dorado del resto del
## juego, en grande.
func _skin_start_button(board_script: GDScript) -> void:
	# Placa de ORO, no el tablón de siempre: es el botón que arranca la partida
	# y tiene que destacar por encima de todo lo demás de la pantalla.
	board_script.skin_start_button(start_button)
	# Este SÍ zarpa, pero su sonido lo pone `_on_start_pressed` (campanas más
	# el casco crujiendo): sin esto sonarían las campanas dos veces.
	start_button.set_meta("snd", "")
	# EN NEGRITA DE VERDAD (Exo2-Bold), no con contorno: sobre el oro de la
	# placa la Regular se leía fina al lado del resto de rótulos.
	var gorda := load("res://fonts/static/Exo2-Bold.ttf")
	if gorda != null:
		start_button.add_theme_font_override("font", gorda)
	start_button.add_theme_font_size_override("font_size", 44)


func _build_card(id: String, board_script: GDScript) -> Button:
	var data: Dictionary = RecipeData.RECIPES[id]
	var b := Button.new()
	b.name = id
	b.toggle_mode = true
	# Tarjetas compactas (4 por fila) SIN fondo propio: todas comparten el mismo
	# pergamino de detrás. Solo llevan el plato, el nombre y las insignias.
	# Estrechas a propósito para caber dentro del interior del pergamino.
	b.custom_minimum_size = Vector2(118, 168)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())

	# Resalte de selección: marco dorado tenue, oculto por defecto.
	var hl := Panel.new()
	hl.name = "Highlight"
	hl.set_anchors_preset(Control.PRESET_FULL_RECT)
	hl.offset_left = 3.0
	hl.offset_top = 3.0
	hl.offset_right = -3.0
	hl.offset_bottom = -3.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.85, 0.35, 0.14)
	sb.set_border_width_all(3)
	sb.border_color = Color(1.0, 0.82, 0.28)
	sb.set_corner_radius_all(12)
	hl.add_theme_stylebox_override("panel", sb)
	hl.visible = false
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hl)

	# El plato, grande y centrado, sobre el pergamino compartido.
	var tex := RecipeData.get_dish_texture(id)
	if tex != null:
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = tex
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		# Plato algo más pequeño y bajado: más cerca del nombre y dejando arriba
		# aire limpio para la moneda y la hoja.
		ic.offset_left = 20.0
		ic.offset_top = 32.0
		ic.offset_right = -20.0
		ic.offset_bottom = -48.0
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)

	# Nombre en letra grande y oscura directamente sobre el pergamino
	# (legible, aunque ocupe dos líneas).
	var nl := Label.new()
	nl.text = data.name
	nl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	nl.offset_left = 3.0
	nl.offset_top = -46.0
	nl.offset_right = -3.0
	nl.offset_bottom = -4.0
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.add_theme_font_size_override("font_size", 18)
	nl.add_theme_color_override("font_color", DARK)
	nl.add_theme_color_override("font_outline_color", Color(1, 0.97, 0.86))
	nl.add_theme_constant_override("outline_size", 4)
	nl.add_theme_constant_override("line_spacing", -3)
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(nl)

	# Insignia de precio (moneda + cantidad), arriba a la izquierda.
	var price_box := HBoxContainer.new()
	price_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	price_box.offset_left = 5.0
	price_box.offset_top = 3.0
	price_box.offset_right = 116.0
	price_box.offset_bottom = 34.0
	price_box.add_theme_constant_override("separation", 4)
	price_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := TextureRect.new()
	coin.texture = load("res://assets/ui/moneda.png")
	coin.custom_minimum_size = Vector2(30, 30)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_box.add_child(coin)
	var pl := Label.new()
	pl.text = "%d" % data.price
	pl.add_theme_font_size_override("font_size", 23)
	pl.add_theme_color_override("font_color", Color(0.4, 0.26, 0.02))
	pl.add_theme_color_override("font_outline_color", Color(1, 0.97, 0.88))
	pl.add_theme_constant_override("outline_size", 5)
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_box.add_child(pl)
	# AL QUITAR LA HOJA VEGETARIANA SE FUE CON ELLA ESTE `add_child`, que
	# estaba justo detrás: la insignia se montaba entera y no se colgaba de
	# ningún sitio, así que las tarjetas se quedaron SIN PRECIO y cada una
	# dejaba tres nodos huérfanos. Salió midiendo fugas en la sonda, no
	# mirando la pantalla — un precio que falta no da ningún error.
	b.add_child(price_box)

	# Check verde de selección (esquina superior derecha).
	var check := TextureRect.new()
	check.name = "Check"
	check.visible = false
	check.texture = load("res://assets/ui/check.png") if ResourceLoader.exists("res://assets/ui/check.png") else null
	check.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	check.offset_left = -40.0
	check.offset_top = 3.0
	check.offset_right = -5.0
	check.offset_bottom = 38.0
	check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(check)

	# Sin usos de algún ingrediente la receta no puede llevarse: tarjeta
	# apagada y aviso para pasar por la tienda. También en el arcade, que
	# cobra despensa por oleada: al arcade se va con el granero cargado.
	if (GameState.is_adventure() or GameState.is_arcade()) \
			and not GameState.has_ingredients_for(id):
		b.disabled = true
		b.modulate = Color(1, 1, 1, 0.45)
		var warn := Label.new()
		warn.text = "Sin ingredientes"
		warn.set_anchors_preset(Control.PRESET_CENTER)
		warn.offset_left = -55.0
		warn.offset_right = 55.0
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warn.add_theme_font_size_override("font_size", 16)
		warn.add_theme_color_override("font_color", Color(0.75, 0.15, 0.1))
		warn.add_theme_color_override("font_outline_color", Color(1, 0.97, 0.88))
		warn.add_theme_constant_override("outline_size", 5)
		warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(warn)
		return b

	b.toggled.connect(_on_recipe_toggled.bind(id, b))
	# Solo se apuntan las tarjetas ELEGIBLES: las que se quedaron sin
	# ingredientes salen antes por su propia rama y ya van marcadas.
	recipe_cards[id] = b
	return b


## Deja la carta cerrada MARCADA y sin tocar: las tarjetas salen elegidas, con
## su resalte, y apagadas para el toque. Las que se quedaron sin ingredientes ni
## siquiera están en `recipe_cards` (salen por su propia rama con el aviso), y
## aun así viajan en `selected`: la carta la manda el escenario, no la despensa.
func _marcar_carta_fija() -> void:
	selected = carta_fija.duplicate()
	for id in recipe_cards:
		var carta: Button = recipe_cards[id]
		if not is_instance_valid(carta):
			continue
		carta.set_pressed_no_signal(true)
		carta.get_node("Check").visible = true
		carta.get_node("Highlight").visible = true
		carta.disabled = true


func _on_recipe_toggled(pressed: bool, id: String, button: Button) -> void:
	if pressed:
		if selected.size() >= slots:
			button.set_pressed_no_signal(false)
			return
		selected.append(id)
	else:
		selected.erase(id)
	button.get_node("Check").visible = button.button_pressed
	# La receta elegida se enmarca con el resalte dorado.
	button.get_node("Highlight").visible = button.button_pressed
	_update_ui()


## El botón de SELECCIÓN AUTOMÁTICA, en la misma fila que el contador: es
## donde el jugador está mirando cuando duda de su carta. Va pequeño y a la
## derecha — es un atajo, no la acción principal (esa es ¡Zarpar!).
func _add_auto_button(board_script) -> void:
	var vb: VBoxContainer = $UI/Root/Margin/VBox
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 16)
	vb.add_child(fila)
	vb.move_child(fila, count_label.get_index())
	# El contador se muda DENTRO de la fila, para que compartan renglón.
	count_label.reparent(fila)
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var b := Button.new()
	b.text = "Selección automática"
	board_script.skin_small_button(b)
	b.add_theme_font_size_override("font_size", 19)
	b.custom_minimum_size = Vector2(250, 46)
	b.pressed.connect(_auto_seleccion)
	fila.add_child(b)


## QUÉ ESCENARIO ES Y QUIÉN VIENE, bajo el rótulo. El jugador estaba eligiendo
## la carta sin saber ni el número del escenario ni a quién iba a servir, que
## es justo lo que decide qué recetas hacen falta: los grumetes comen de 1★,
## los piratas de 2★ y los capitanes de 3★.
func _build_info_row() -> void:
	if not GameState.is_adventure():
		return
	var port := CampaignData.get_port(GameState.current_port)
	if port.is_empty():
		return
	var caja := VBoxContainer.new()
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 2)
	var vb: VBoxContainer = $UI/Root/Margin/VBox
	vb.add_child(caja)
	vb.move_child(caja, count_label.get_index())

	var n := CampaignData.port_index(GameState.current_port) + 1
	var titulo := Label.new()
	titulo.text = "Escenario %d  ·  %s" % [n, str(port.get("name", ""))]
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", Color(1, 0.93, 0.78))
	titulo.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	titulo.add_theme_constant_override("outline_size", 7)
	caja.add_child(titulo)

	# LA CLIENTELA, con las mismas caras que el HUD y el mapa. En un ABORDAJE
	# no hay cupo, así que se enseñan los tipos sin cifra: lo que importa es
	# QUIÉN viene, no cuántos.
	var mix: Dictionary = port.get("client_mix", {})
	var sin_fin := CampaignData.unlimited_clients(GameState.current_port)
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 14)
	caja.add_child(fila)
	for t in ["E", "A", "G"]:
		var cuantos := int(mix.get(t, 0))
		if cuantos <= 0:
			continue
		var par := HBoxContainer.new()
		par.add_theme_constant_override("separation", 2)
		fila.add_child(par)
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var ruta := "res://assets/ui/head_%s.png" % t
		if ResourceLoader.exists(ruta):
			ic.texture = load(ruta)
		ic.custom_minimum_size = Vector2(38, 38)
		par.add_child(ic)
		var l := Label.new()
		l.text = "sin fin" if sin_fin else "x%d" % cuantos
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 21)
		l.add_theme_color_override("font_color", Color(1, 0.88, 0.6))
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		l.add_theme_constant_override("outline_size", 6)
		par.add_child(l)


## "Selección automática": rellena la carta con lo mejor que se puede llevar a
## ESTE escenario. No es un atajo tonto — puntúa cada receta por lo que de
## verdad va a rendir aquí (ver `_puntuar_receta`) y va cogiendo la mejor,
## penalizando repetir nivel de estrella para que la carta cubra a todos los
## que vienen: con el sistema de hastío, una carta de cuatro platos del mismo
## nivel se agota en el mismo cliente.
func _auto_seleccion() -> void:
	selected.clear()
	# POR CUPOS, no por puntuación a secas. Con una lista única el picoteo se
	# lo comía todo — es baratísimo de hacer y de enfriar, así que su
	# rendimiento por segundo es enorme, pero NO ALIMENTA: una carta de tres
	# picoteos y un maki deja a los piratas y a los capitanes mirando la cinta.
	# Los cupos garantizan que lo primero sea comida de verdad.
	var principales: Array[String] = []
	var postres: Array[String] = []
	var picoteos: Array[String] = []
	for id in recipe_cards:
		var r := RecipeData.get_recipe(str(id))
		if r.get("snack", false):
			picoteos.append(str(id))
		elif r.get("leaves_seat", false):
			postres.append(str(id))
		else:
			principales.append(str(id))
	# Un POSTRE (libera la silla y cobra el multiplicador) y un PICOTEO (limpia
	# paladar sin gastar turno) como mucho, y solo si la carta da para ellos:
	# con 3 huecos o menos, todo a comida.
	var hueco_postre: int = 1 if slots >= 4 and not postres.is_empty() else 0
	var hueco_picoteo: int = 1 if slots >= 4 and not picoteos.is_empty() else 0
	var para_principales := slots - hueco_postre - hueco_picoteo

	var niveles: Dictionary = {}
	while selected.size() < para_principales:
		var mejor := _mejor_de(principales, niveles)
		if mejor == "":
			break
		selected.append(mejor)
		var lv := int(RecipeData.get_recipe(mejor).get("level", 1))
		niveles[lv] = int(niveles.get(lv, 0)) + 1
	if hueco_postre > 0:
		var pos := _mejor_de(postres, {})
		if pos != "":
			selected.append(pos)
	if hueco_picoteo > 0:
		var pic := _mejor_de(picoteos, {})
		if pic != "":
			selected.append(pic)
	# Si algún cupo se quedó vacío (no había postres, por ejemplo), se rellena
	# con lo mejor que quede de cualquier clase antes que dejar hueco libre.
	var todas := principales + postres + picoteos
	while selected.size() < slots:
		var extra := _mejor_de(todas, niveles)
		if extra == "":
			break
		selected.append(extra)
		var lv2 := int(RecipeData.get_recipe(extra).get("level", 1))
		niveles[lv2] = int(niveles.get(lv2, 0)) + 1
	# COBERTURA POR TIPO DE CLIENTE. La puntuación mide rendimiento MEDIO, y con
	# un solo capitán entre ocho bocas ningún plato de 3★ gana nunca el reparto:
	# salía una carta entera de 1★ que dejaba al capitán mirando la cinta toda
	# la jornada — y que el propio selector regaña por boca de Gigi. Si el
	# escenario trae piratas o capitanes, se les garantiza UN plato de su nivel.
	_asegurar_nivel(2, "A", principales)
	_asegurar_nivel(3, "G", principales)
	# Se refleja en las tarjetas (el toggle emite y volvería a entrar por
	# `_on_recipe_toggled`, así que se pone la marca a mano).
	for id in recipe_cards:
		var carta: Button = recipe_cards[id]
		if not is_instance_valid(carta):
			continue
		var on: bool = str(id) in selected
		carta.set_pressed_no_signal(on)
		carta.get_node("Check").visible = on
		carta.get_node("Highlight").visible = on
	_update_ui()


## La mejor receta de una lista que no esté ya elegida. `niveles` penaliza
## repetir estrella: la segunda receta del mismo nivel vale la mitad y la
## tercera un tercio, porque con el sistema de hastío una carta de cuatro
## platos del mismo nivel se le agota al primer cliente que se siente.
func _mejor_de(lista: Array, niveles: Dictionary) -> String:
	var mejor := ""
	var mejor_p := -1.0
	for id in lista:
		var sid := str(id)
		if sid in selected:
			continue
		var p := _puntuar_receta(sid)
		var lv := int(RecipeData.get_recipe(sid).get("level", 1))
		p /= 1.0 + float(niveles.get(lv, 0))
		if p > mejor_p:
			mejor_p = p
			mejor = sid
	return mejor


## Lo que se espera sacar de una receta EN ESTE escenario: doblones por segundo
## de atención, ponderados por quién viene de verdad. El coste real de un plato
## es el tiempo que ocupa el único hueco de elaboración, así que el enfriamiento
## es el divisor (ver el bloque de balance de CLAUDE.md).
## Garantiza un plato de `nivel` estrellas en la carta si el escenario trae
## clientes del tipo `tipo`. Cambia el PEOR principal de la selección, nunca el
## postre ni el picoteo (que están ahí por lo que hacen, no por lo que rinden).
func _asegurar_nivel(nivel: int, tipo: String, candidatos: Array) -> void:
	var mix: Dictionary = CampaignData.get_port(
		GameState.current_port).get("client_mix", {})
	if int(mix.get(tipo, 0)) <= 0:
		return
	for id in selected:
		if int(RecipeData.get_recipe(str(id)).get("level", 1)) == nivel:
			return
	var mejor := ""
	var mejor_p := -1.0
	for id in candidatos:
		if int(RecipeData.get_recipe(str(id)).get("level", 1)) != nivel:
			continue
		if str(id) in selected:
			continue
		var p := _puntuar_receta(str(id))
		if p > mejor_p:
			mejor_p = p
			mejor = str(id)
	if mejor == "":
		return
	var peor := ""
	var peor_p := INF
	for id in selected:
		var r := RecipeData.get_recipe(str(id))
		if r.get("snack", false) or r.get("leaves_seat", false):
			continue
		var p2 := _puntuar_receta(str(id))
		if p2 < peor_p:
			peor_p = p2
			peor = str(id)
	if peor == "":
		return
	selected[selected.find(peor)] = mejor


func _puntuar_receta(id: String) -> float:
	var r := RecipeData.get_recipe(id)
	var port := CampaignData.get_port(GameState.current_port)
	var mix: Dictionary = port.get("client_mix", {})
	var total := 0.0
	for t in mix:
		total += float(mix[t])
	if total <= 0.0:
		total = 1.0
	var nivel := int(r.get("level", 1))
	var precio := float(r.get("price", 1))
	# Las recetas con MAESTRÍA sueltan varias piezas por elaboración: su precio
	# es POR PIEZA, así que rinden mucho más de lo que dice la ficha.
	var piezas := 1.0 + float(r.get("free_uses", 0))
	var enfriamiento := maxf(float(r.get("cooldown", 4.0))
		* RecipeData.RITMO_COOLDOWN, 1.0)
	# Cuánto la va a querer la clientela que viene.
	var querida := 0.0
	for t in mix:
		var peso := float(mix[t]) / total
		querida += peso * _take_chance(str(t), nivel, id)
	var p := precio * piezas * querida / enfriamiento
	# Los PICOTEOS no ocupan el turno del cliente y limpian paladar: valen más
	# de lo que dice su precio de 1 doblón.
	if r.get("snack", false):
		p *= 2.4
	return p


## Probabilidad de que un cliente de ese tipo coja el plato, respetando el
## `take_chance` propio de la receta (el edamame y el onigiri lo llevan).
func _take_chance(tipo: String, nivel: int, id: String) -> float:
	var r := RecipeData.get_recipe(id)
	var propio: Variant = r.get("take_chance", null)
	if propio != null:
		if propio is Dictionary:
			return float(propio.get(tipo, 0.5))
		return float(propio)
	var solo := str(r.get("only_type", ""))
	if solo != "" and solo != tipo:
		return 0.0
	var tabla: Dictionary = {
		"E": [0.95, 0.20, 0.10],
		"A": [0.45, 0.95, 0.25],
		"G": [0.10, 0.55, 0.95],
	}
	var fila: Array = tabla.get(tipo, [0.5, 0.5, 0.5])
	return float(fila[clampi(nivel - 1, 0, 2)])


func _update_ui() -> void:
	count_label.text = "Carta del escenario" if not carta_fija.is_empty() \
			else "%d/%d elegidas" % [selected.size(), slots]
	# Basta con 1 receta: en los primeros niveles no hay 4 disponibles.
	start_button.disabled = selected.is_empty()
	# Apagado por OPACIDAD, no aclarando la letra: sobre el oro no se leía.
	PrepBoard.set_dimmed(start_button, start_button.disabled)
	# CON LA CARTA LLENA, LO QUE NO CABE SE APAGA. Tocar una receta más no hacía
	# nada (`_on_recipe_toggled` la devuelve a su sitio) y no había forma de
	# saber por qué: parecía que la tarjeta no respondía. Atenuadas se lee de un
	# vistazo que ya no queda hueco, y las elegidas siguen a plena luz para
	# poder soltar una y cambiarla.
	var llena := selected.size() >= slots
	for id in recipe_cards:
		var carta: Button = recipe_cards[id]
		if not is_instance_valid(carta):
			continue
		PrepBoard.set_dimmed(carta, llena and not (id in selected))


## ¿Lleva la selección algún plato de N estrellas o más?
func _lleva_estrellas(n: int) -> bool:
	for id in selected:
		if int(RecipeData.get_recipe(id).get("level", 1)) >= n:
			return true
	return false


## QUÉ CLIENTELA SE VA A QUEDAR MIRANDO LA CINTA, si es que alguna: devuelve
## "A" (piratas sin platos de 2★), "G" (capitanes sin platos de 3★) o "".
##
## NO AVISA EN EL PUERTO QUE ESTRENA ESE TIPO DE CLIENTE. En el primer nivel con
## piratas el jugador no PUEDE llevar un plato de dos estrellas —todavía no
## tiene ninguno— y es David quien se lo regala dentro del nivel, así que el
## aviso solo servía para asustar por algo que ya está resuelto. Lo mismo con el
## primer capitán. A partir de ahí sí: ahí ya es un descuido del jugador.
func _clientela_desatendida() -> String:
	var mix: Dictionary = CampaignData.get_port(GameState.current_port) \
			.get("client_mix", {})
	for caso in [["G", 3], ["A", 2]]:
		var tipo: String = caso[0]
		if int(mix.get(tipo, 0)) <= 0:
			continue
		if GameState.current_port == CampaignData.first_port_with(tipo):
			continue
		if not _lleva_estrellas(int(caso[1])):
			return tipo
	return ""


func _on_start_pressed() -> void:
	# Las campanas del barco y el casco crujiendo al soltar amarras.
	Audio.sfx("zarpar")
	Audio.sfx("barco_cruje")
	# UNA CARTA DE SOLO GRUMETES NO DA DE COMER A UN PUERTO CON PIRATAS (o con
	# capitanes): comen de dos y de tres estrellas y sin un plato así se quedan
	# mirando la cinta. Gigi avisa, pero NO bloquea: si el jugador insiste, allá
	# él. Y NO avisa en el nivel que estrena cada tipo (ver
	# `_clientela_desatendida`).
	# Con la carta cerrada, el aviso de clientela no cabe: el jugador no puede
	# cambiar nada, así que solo sería un susto.
	var falta := "" if not GameState.is_adventure() or _avisado_piratas \
			or not carta_fija.is_empty() else _clientela_desatendida()
	if falta != "":
		_avisado_piratas = true
		var quien := "capitanes" if falta == "G" else "piratas"
		var estrellas := "tres" if falta == "G" else "dos"
		var aviso := DialogueBox.new()
		$UI.add_child(aviso)
		aviso.say([
			{ "text": "¡ALTO AHÍ! ¡RAAAK! ¡En ese puerto hay **%s**!" % quien,
				"who": "gigi", "mood": "loro_grito" },
			{ "text": "Y los %s comen de **%s estrellas**. No llevas ni un plato así: se te van a quedar mirando la cinta con cara de pocos amigos." % [quien, estrellas],
				"who": "gigi", "mood": "loro" },
			{ "text": "Hazle caso, %s. Cambia una receta o prepárate para verlos marchar." % GameState.player_title(), "mood": "loro_resignado" },
		])
		await aviso.finished
		await aviso.close_and_free()
		return
	# EL BONIFICADOR DE REGALO SE LLEVA PUESTO. En el nivel que lo presenta no
	# tiene sentido zarpar sin él: la lección entera va de eso.
	if GameState.is_adventure():
		var regalo := str(CampaignData.get_port(GameState.current_port)
				.get("unlocks_perk", ""))
		if regalo != "" and GameState.is_perk_unlocked(regalo) \
				and GameState.get_perk_uses(regalo) > 0 \
				and not regalo in perks_selected \
				and not GameState.port_beaten(GameState.current_port):
			var recado := DialogueBox.new()
			$UI.add_child(recado)
			recado.say([
				{ "text": "¡QUE TE LO PONGAS, HE DICHO! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
				{ "text": "Toca el **%s** de ahí abajo antes de zarpar. Para algo te lo he dado."
					% str(PerkData.get_perk(regalo).get("name", regalo)), "mood": "loro_resignado" },
			])
			await recado.finished
			await recado.close_and_free()
			return
	# SIN ARROZ NO SE ZARPA. Se avisa aquí y no al montar el nivel: allí ya
	# sería tarde y el jugador vería la pantalla parpadear.
	if not GameState.can_play():
		var caja := DialogueBox.new()
		$UI.add_child(caja)
		caja.say([{ "text": "¡SIN ARROZ NO HAY SUSHI! ¡RAAAK! Espera a que caiga "
			+ "el próximo saco, o cómprate unos cuantos.",
			"who": "gigi", "mood": "loro_grito" }])
		await caja.finished
		caja.queue_free()
		return
	GameState.selected_recipes = selected.duplicate()
	GameState.selected_perks = perks_selected.duplicate()
	# Nivel 3D low poly (el level.tscn 2D queda como referencia hasta acabar
	# la conversion completa del juego).
	GameState.fade_to_scene("res://scenes/level3d.tscn", 0.35, 0.45)


## RED DE SEGURIDAD DE LA ESCUELA: el jugador se ha quedado sin ingredientes
## para NINGUNA de sus recetas y la tienda todavía no ha abierto (nivel 4), así
## que no tiene dónde reponer. David le rellena la despensa y lo cuenta.
##
## Va aquí y no en el mapa porque este es el camino de los puertos de carta
## LIBRE; las islas de carta cerrada lo resuelven en `level_select3d`.
func _rescate_de_david(recetas: Array) -> void:
	var repuestos := GameState.gift_missing_ingredients(recetas)
	if repuestos.is_empty():
		return
	var caja := DialogueBox.new()
	$UI.add_child(caja)
	caja.say([
		{ "text": "¡RAAAK! ¡LA DESPENSA ESTÁ PELADA! ¡No queda NADA que cocinar!",
			"who": "gigi", "mood": "loro_grito" },
		{ "text": "Calma. Toma **%d usos** de cada cosa que te faltaba, de mi **reserva particular**."
			% GameState.RESCUE_GIFT, "mood": "feliz" },
	])
	await caja.finished
	await caja.close_and_free()
	# Las tarjetas ya se dibujaron con la despensa vieja: se repintan.
	get_tree().reload_current_scene()


## (El antiguo `_puerto_con_piratas` se fundió en `_clientela_desatendida`, que
## además distingue piratas de capitanes y calla en el nivel que los estrena.)
