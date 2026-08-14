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
## Pestaña con la que se abre la pantalla. Estuvo apuntando a "clientela", un
## apartado que ya no existe, así que al entrar la lista salía VACÍA y ninguna
## pestaña encendida.
var current_group := "cocina"
var backdrop: Node3D = null
var claim_btn: Button = null
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
	# SIN cinta de título: el marcador de medallas que va justo debajo ya dice
	# de sobra en qué pantalla estamos, y la cinta solo robaba ancho al botón.
	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(hueco)
	# "Reclamar todo": cobra de golpe TODAS las medallas pendientes (25/50/100
	# por bronce/plata/oro). Cada tarjeta se puede cobrar por separado tocándola.
	claim_btn = Button.new()
	claim_btn.text = "Reclamar todo"
	claim_btn.custom_minimum_size = Vector2(210, 0)
	PrepBoard.skin_button(claim_btn)
	claim_btn.add_theme_font_size_override("font_size", 20)
	claim_btn.pressed.connect(_open_claim)
	bar.add_child(claim_btn)
	_refresh_claim_button()

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
	_refresh_tab_badges()

	content = Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_top = 222.0
	content.offset_left = 12.0
	content.offset_right = -12.0
	content.offset_bottom = -16.0
	root.add_child(content)
	content.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))

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


## Globo rojo en cada PESTAÑA con lo que le queda por reclamar dentro.
func _refresh_tab_badges() -> void:
	for g in tab_buttons:
		var b: Button = tab_buttons[g]
		var viejo := b.get_node_or_null("Badge")
		if viejo != null:
			viejo.queue_free()
			b.remove_child(viejo)
		PrepBoard.attach_badge(b, GameState.unclaimed_in_group(str(g)), 28.0)


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
	# Logro de una receta AÚN SIN DESBLOQUEAR: tarjeta oculta, sin nombre ni
	# plato, para no desvelar qué recetas hay en el juego.
	if a.has("recipe") and not GameState.is_recipe_unlocked(str(a["recipe"])):
		return _build_hidden_card(a)
	var value := GameState.achievement_value(a)
	var medal := AchievementData.medal_for(a, value)
	var target := AchievementData.next_target(a, value)
	var done := medal >= AchievementData.MEDALS.size()

	# LA TARJETA ES UN BOTÓN: con medallas pendientes, tocarla las cobra ahí
	# mismo (sin tener que ir al "Reclamar todo" de arriba). Sin nada pendiente
	# queda inerte, para que pulsar no dé un falso "algo ha pasado".
	var pend := GameState.unclaimed_for(a)
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 116)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		card.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	card.disabled = pend <= 0
	if pend > 0:
		PrepBoard.add_press_feedback(card, 0.97)
		card.pressed.connect(_claim_one.bind(str(a["id"]), card))
	var skin := PrepBoard.make_nine_patch(PrepBoard.BUTTON_TEX, PrepBoard.BUTTON_MARGIN)
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

	# CADA LOGRO CON SU ICONO (AchievementData.icon_for): el plato si es de
	# receta, la ficha del álbum si es de pez y el suyo propio en los demás.
	# Antes casi todos compartían la misma moneda y en una lista larga no había
	# manera de distinguirlos de un vistazo. El metal conseguido lo siguen
	# contando las tres chapas de la derecha.
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = AchievementData.icon_for(a)
	ic.custom_minimum_size = Vector2(78, 78)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.modulate = Color(1, 1, 1, 1.0 if medal > 0 else 0.55)
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
	# Globo rojo: cuántas medallas de este logro están sin cobrar.
	PrepBoard.attach_badge(card, pend, 32.0)
	return card


## Tarjeta de logro OCULTO: la silueta del plato en negro y "???" en vez del
## nombre. Ni barra ni pista: la receta se descubre jugando.
func _build_hidden_card(a: Dictionary) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(0, 116)
	var skin := PrepBoard.make_nine_patch(PrepBoard.BUTTON_TEX, PrepBoard.BUTTON_MARGIN)
	skin.modulate = Color(1, 1, 1, 0.4)
	card.add_child(skin)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20.0
	row.offset_top = 12.0
	row.offset_right = -28.0
	row.offset_bottom = -12.0
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var dish := TextureRect.new()
	dish.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dish.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dish.texture = RecipeData.get_dish_texture(str(a["recipe"]))
	dish.custom_minimum_size = Vector2(78, 78)
	dish.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# En NEGRO: la silueta no debe dejar adivinar el plato de un vistazo.
	dish.modulate = Color(0.07, 0.05, 0.04, 0.85)
	row.add_child(dish)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var name_l := Label.new()
	name_l.text = "???"
	name_l.add_theme_font_size_override("font_size", 23)
	name_l.add_theme_color_override("font_color", Color(0.8, 0.74, 0.62))
	name_l.add_theme_color_override("font_outline_color", Color(0.13, 0.07, 0.02))
	name_l.add_theme_constant_override("outline_size", 6)
	col.add_child(name_l)
	var desc := Label.new()
	desc.text = "Descubre esta receta para desvelar su logro."
	desc.add_theme_font_size_override("font_size", 17)
	desc.add_theme_color_override("font_color", Color(0.72, 0.66, 0.54))
	desc.add_theme_color_override("font_outline_color", Color(0.13, 0.07, 0.02))
	desc.add_theme_constant_override("outline_size", 5)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(desc)
	return card


# -------------------------------------------------------- reclamar medallas

## Cuántas monedas salen volando y cuánto dura la lluvia.
const COINS_N := 12
## La del "Reclamar todo" es mucho mayor: son todas las medallas de golpe.
const COINS_ALL := 34
const COIN_FLY := 0.85


## Cobra las medallas de UN logro (se ha tocado su tarjeta). Celebra con una
## lluvia de monedas que sale de la propia tarjeta y sube hacia el marcador, y
## la cifra ganada encima. Luego repinta: la tarjeta pierde su globo, la
## pestaña recalcula el suyo y el botón de "Reclamar todo" se apaga si ya no
## queda nada.
func _claim_one(id: String, card: Control) -> void:
	var ganado := GameState.claim_achievement(id)
	if ganado <= 0:
		return
	var centro := card.get_global_rect().get_center()
	_coin_burst(centro, ganado)
	_refresh_claim_button()
	_refresh_tab_badges()
	# Repintar en DIFERIDO: se está dentro del `pressed` de la propia tarjeta,
	# y liberarla en mitad de su señal deja el botón a medio procesar.
	_show_group.bind(current_group).call_deferred()


## Monedas que salen disparadas del punto que se toca, describen su arco y se
## desvanecen, con el "+N" subiendo por el medio. Va en el CanvasLayer de la
## pantalla (no en la tarjeta) para que puedan salirse de ella.
func _coin_burst(desde: Vector2, cantidad: int, cuantas := COINS_N,
		con_cifra := true) -> void:
	var capa := Control.new()
	capa.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.z_index = 200
	ui.add_child(capa)
	var tex: Texture2D = load("res://assets/ui/moneda.png")
	for i in cuantas:
		var c := TextureRect.new()
		c.texture = tex
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c.size = Vector2(44, 44)
		c.pivot_offset = Vector2(22, 22)
		c.position = desde - Vector2(22, 22)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		capa.add_child(c)
		# Cada moneda a su aire: abanico hacia arriba y su propio retardo.
		var ang := deg_to_rad(-90.0 + randf_range(-62.0, 62.0))
		var dist := randf_range(120.0, 260.0)
		var destino := c.position + Vector2(cos(ang), sin(ang)) * dist
		var d := i * 0.035
		var t := c.create_tween().set_parallel(true)
		t.tween_property(c, "position", destino, COIN_FLY).set_delay(d) 				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(c, "rotation_degrees", randf_range(-220.0, 220.0),
			COIN_FLY).set_delay(d)
		t.tween_property(c, "scale", Vector2(0.5, 0.5), COIN_FLY * 0.45) 				.set_delay(d + COIN_FLY * 0.55)
		t.tween_property(c, "modulate:a", 0.0, COIN_FLY * 0.45) 				.set_delay(d + COIN_FLY * 0.55)

	# La cifra, en grande, subiendo desde el mismo punto. En el cobro EN BLOQUE
	# no se dibuja: el cartel del cofre ya canta el total, y superpuesta le caía
	# justo encima del rótulo.
	if not con_cifra:
		capa.create_tween().tween_callback(capa.queue_free) 				.set_delay(COIN_FLY + COINS_N * 0.04 + 0.5)
		return
	var l := Label.new()
	l.text = "+%d" % cantidad
	l.add_theme_font_size_override("font_size", 52)
	l.add_theme_color_override("font_color", Color(1, 0.92, 0.5))
	l.add_theme_color_override("font_outline_color", Color(0.28, 0.11, 0.03))
	l.add_theme_constant_override("outline_size", 12)
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		l.add_theme_font_override("font", negrita)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = desde - Vector2(50, 30)
	l.scale = Vector2(0.5, 0.5)
	l.pivot_offset = Vector2(50, 30)
	capa.add_child(l)
	var tl := l.create_tween().set_parallel(true)
	tl.tween_property(l, "scale", Vector2.ONE, 0.28) 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tl.tween_property(l, "position:y", l.position.y - 120.0, 1.1) 			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tl.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.75)
	tl.chain().tween_callback(capa.queue_free)


func _refresh_claim_button() -> void:
	if claim_btn == null:
		return
	var n := GameState.unclaimed_medals()
	claim_btn.disabled = n <= 0
	PrepBoard.set_dimmed(claim_btn, n <= 0)


## Cobra todas las medallas pendientes y lo celebra con el COFRE: se abre, y
## del botín salen la cifra y el desglose por metales.
func _open_claim() -> void:
	var r := GameState.claim_achievement_rewards()
	if int(r["total"]) <= 0:
		return
	_refresh_claim_button()
	# Los globos rojos se van con el cobro: los de las pestañas y los de las
	# tarjetas que se estén viendo.
	_refresh_tab_badges()
	_show_group.bind(current_group).call_deferred()
	# Lluvia GRANDE, del centro de la pantalla: es el cobro gordo, y tiene que
	# notarse más que el de una tarjeta suelta.
	var lienzo := GameState.canvas_size()
	_coin_burst(Vector2(lienzo.x * 0.5, lienzo.y * 0.42), int(r["total"]),
		COINS_ALL, false)

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(veil)
	create_tween().tween_property(veil, "color:a", 0.6, 0.25)

	var pw := 520.0
	var ph := 600.0
	var panel := Control.new()
	var cs := GameState.canvas_size()
	panel.position = Vector2((cs.x - pw) * 0.5, (cs.y - ph) * 0.5)
	panel.size = Vector2(pw, ph)
	panel.pivot_offset = panel.size * 0.5
	overlay.add_child(panel)
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))

	var title := PrepBoard.make_big_title("¡Botín de logros!", 46)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 48.0
	title.offset_bottom = 120.0
	panel.add_child(title)

	# El cofre: cerrado, da un meneo y se ABRE soltando la cifra.
	var chest := TextureRect.new()
	chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chest.texture = load("res://assets/ui/daily_cofre.png")
	chest.position = Vector2((pw - 220.0) * 0.5, 150.0)
	chest.size = Vector2(220, 200)
	chest.pivot_offset = Vector2(110, 190)
	panel.add_child(chest)

	# La cifra con su moneda, y el desglose por metales debajo.
	var loot := HBoxContainer.new()
	loot.alignment = BoxContainer.ALIGNMENT_CENTER
	loot.add_theme_constant_override("separation", 10)
	loot.set_anchors_preset(Control.PRESET_TOP_WIDE)
	loot.offset_top = 366.0
	loot.offset_bottom = 430.0
	loot.modulate.a = 0.0
	panel.add_child(loot)
	var coin := TextureRect.new()
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture = load("res://assets/ui/moneda.png")
	coin.custom_minimum_size = Vector2(52, 52)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	loot.add_child(coin)
	var amount := Label.new()
	amount.text = "+%d" % int(r["total"])
	amount.add_theme_font_size_override("font_size", 50)
	amount.add_theme_color_override("font_color", Color(1, 0.86, 0.4))
	amount.add_theme_color_override("font_outline_color", Color(0.13, 0.07, 0.02))
	amount.add_theme_constant_override("outline_size", 10)
	loot.add_child(amount)

	var parts: Array[String] = []
	for i in AchievementData.MEDALS.size():
		var n := int(r[AchievementData.MEDALS[i]])
		if n > 0:
			parts.append("%d de %s" % [n, AchievementData.MEDAL_NAMES[i].to_lower()])
	var detail := Label.new()
	detail.text = " · ".join(parts)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 20)
	detail.add_theme_color_override("font_color", Color(0.38, 0.25, 0.10))
	detail.set_anchors_preset(Control.PRESET_TOP_WIDE)
	detail.offset_top = 434.0
	detail.offset_bottom = 464.0
	detail.modulate.a = 0.0
	panel.add_child(detail)

	var seguir := Button.new()
	seguir.text = "Continuar"
	PrepBoard.skin_button(seguir)
	seguir.add_theme_font_size_override("font_size", 26)
	seguir.set_anchors_preset(Control.PRESET_TOP_WIDE)
	seguir.offset_left = 150.0
	seguir.offset_right = -150.0
	seguir.offset_top = 486.0
	seguir.offset_bottom = 552.0
	seguir.modulate.a = 0.0
	panel.add_child(seguir)
	seguir.pressed.connect(func() -> void:
		overlay.queue_free()
		# Con lo reclamado ya cobrado, el marcador y las tarjetas no cambian
		# (miden lo CONSEGUIDO), solo el botón se apaga.
		_refresh_claim_button())

	panel.scale = Vector2(0.75, 0.75)
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.set_parallel(false)
	# Meneo del cofre cerrado... y APERTURA: cambia a la textura abierta con un
	# golpe de escala, y detrás entran cifra, desglose y botón.
	tw.tween_property(chest, "rotation", deg_to_rad(-5.0), 0.1)
	tw.tween_property(chest, "rotation", deg_to_rad(5.0), 0.1)
	tw.tween_property(chest, "rotation", deg_to_rad(-4.0), 0.09)
	tw.tween_property(chest, "rotation", 0.0, 0.09)
	tw.tween_callback(func() -> void:
		chest.texture = load("res://assets/ui/daily_cofre_abierto.png"))
	tw.tween_property(chest, "scale", Vector2(1.14, 1.14), 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(chest, "scale", Vector2.ONE, 0.14)
	tw.set_parallel()
	tw.tween_property(loot, "modulate:a", 1.0, 0.25)
	tw.tween_property(detail, "modulate:a", 1.0, 0.25).set_delay(0.1)
	tw.tween_property(seguir, "modulate:a", 1.0, 0.25).set_delay(0.2)


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
