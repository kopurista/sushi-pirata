class_name NoticeLayer
extends CanvasLayer
## Capa GLOBAL de avisos, colgada del autoload GameState (como el velo de los
## fundidos): así sobrevive a los cambios de escena y funciona igual en el
## menú, en el mapa o en mitad de un nivel.
##
## Dos cosas distintas viven aquí:
## · TOAST de logro: banda pequeña que baja desde arriba, se lee y se va sola.
##   NO es interactiva (MOUSE_FILTER_IGNORE en todo): es una notificación que
##   pasa desapercibida, no un cartel que haya que cerrar.
## · VENTANA de coleccionable: modal con velo que PAUSA el árbol mientras está
##   puesta (si ya estaba pausado —cartel de resultados— se respeta y no se
##   despausa al cerrar). Se cierra con su botón "Continuar".
##
## Las dos van EN COLA: si caen varios avisos seguidos (medalla de bronce y
## plata del mismo golpe), salen de uno en uno.
##
## TRAMPA de CanvasLayer (ver CLAUDE.md): nada de set_anchors_preset en los
## Controls de raíz — anclas a cero y position/size explícitos con
## GameState.canvas_size().

const PrepBoard := preload("res://scripts/prep_board.gd")

## Por debajo del velo de fundido del autoload (128) y por encima de cualquier
## cartel del juego (los modales de nivel van a z_index 120 en su propia capa).
const NOTICE_LAYER := 126

const TOAST_TIME := 2.8
const TOAST_H := 96.0
const TOAST_W := 520.0

## DOS CANALES INDEPENDIENTES, y por eso hay dos colas.
##  · MODALES (subida de nivel, coleccionable): se pisan entre sí, así que van
##    de uno en uno — son ventanas que hay que cerrar.
##  · TOASTS de logro: una banda que baja, se va sola y no recibe ni un toque.
## Estuvieron en la MISMA cola y la ventana de subida de nivel se quedaba
## detrás de TODAS las notificaciones: con media docena de logros eran ~17 s
## mirando banderitas antes de ver lo que habías ganado. Como el toast vive
## arriba y el modal en el centro, no se estorban: pueden ir a la vez.
var _queue: Array = []
var _busy := false
var _toasts: Array = []
var _toast_busy := false
var _paused_by_us := false


func _init() -> void:
	layer = NOTICE_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


## Notificación de LOGRO: icono + "¡Logro!" + nombre y medalla. No interactiva.
func toast_achievement(icon: Texture2D, tint: Color, title: String,
		subtitle: String) -> void:
	_toasts.append({ "kind": "toast", "icon": icon, "tint": tint,
		"title": title, "subtitle": subtitle })
	_pump_toasts()


## Ventana de COLECCIONABLE conseguido. `extra` añade un renglón (el regalo de
## doblones del triángulo dorado).
func announce_collectible(id: String, extra := "") -> void:
	_queue.append({ "kind": "collectible", "id": id, "extra": extra })
	_pump()


## SUBIDA DE NIVEL DEL COCINERO: ventana modal con el nivel alcanzado y TODO
## lo que ha soltado (punto de maestría, oro, lingotes, despensa...). Se llama
## desde donde el jugador esté mirando — el cartel de fin de nivel o la barra
## del menú—, no desde `add_chef_xp`, para que no salte a media animación.
func announce_level_up(resumen: Dictionary) -> void:
	if resumen.is_empty():
		return
	_queue.append({ "kind": "level", "data": resumen })
	_pump()


func _pump() -> void:
	if _busy or _queue.is_empty():
		return
	_busy = true
	var item: Dictionary = _queue.pop_front()
	match str(item["kind"]):
		"level":
			_show_level_up(item["data"])
		_:
			_show_collectible(item)


func _done() -> void:
	_busy = false
	_pump()


## Los toasts corren por su cuenta, en paralelo con los modales.
func _pump_toasts() -> void:
	if _toast_busy or _toasts.is_empty():
		return
	_toast_busy = true
	_show_toast(_toasts.pop_front())


func _toast_done() -> void:
	_toast_busy = false
	_pump_toasts()


## ¿Queda alguna VENTANA en pantalla o en la cola? Lo pregunta quien tiene que
## hablar DESPUÉS de un cartel: el guion del nivel 7 espera a que el jugador
## cierre la ventana de la bandera antes de soltar a David, porque si no las
## dos cosas se pisaban en la misma pantalla. Los TOASTS no cuentan: son una
## banda que se va sola y no tapa a nadie.
func is_busy() -> bool:
	return _busy or not _queue.is_empty()


# ------------------------------------------------------------------- toast

func _show_toast(item: Dictionary) -> void:
	# La medalla de un logro. Va aquí y no en quien la consigue porque los
	# logros saltan desde media docena de sitios y todos acaban en esta banda.
	Audio.sfx("logro")
	var cw := GameState.canvas_size().x
	var box := Control.new()
	box.position = Vector2((cw - TOAST_W) * 0.5,
		GameState.safe_top() + 14.0 - TOAST_H - 30.0)
	box.size = Vector2(TOAST_W, TOAST_H)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var skin := PrepBoard.make_nine_patch(PrepBoard.CARD_TEX, PrepBoard.CARD_MARGIN)
	skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(skin)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20.0
	row.offset_top = 10.0
	row.offset_right = -20.0
	row.offset_bottom = -10.0
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)

	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = item["icon"]
	ic.modulate = item["tint"]
	ic.custom_minimum_size = Vector2(56, 56)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	col.add_child(_label(str(item["title"]), 22, Color(0.42, 0.26, 0.10)))
	col.add_child(_label(str(item["subtitle"]), 18, Color(0.30, 0.20, 0.10)))

	# Baja, espera y vuelve a subir. Todo con destino ABSOLUTO (nada de
	# as_relative: la lección de la flecha del diálogo).
	var y_in := GameState.safe_top() + 14.0
	var tw := create_tween()
	tw.tween_property(box, "position:y", y_in, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(TOAST_TIME)
	tw.tween_property(box, "position:y", y_in - TOAST_H - 30.0, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		box.queue_free()
		_toast_done())


# ------------------------------------------------- ventana de coleccionable

func _show_collectible(item: Dictionary) -> void:
	# Una pieza de la vitrina: suena a tesoro, no a logro.
	Audio.sfx("premio")
	var id := str(item["id"])
	var cs := GameState.canvas_size()
	var root := Control.new()
	root.position = Vector2.ZERO
	root.size = cs
	add_child(root)

	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(veil)
	create_tween().tween_property(veil, "color:a", 0.55, 0.25)

	# Se pausa el árbol mientras la ventana está puesta; si YA estaba pausado
	# (cartel de resultados, guion hablando) no lo tocamos al cerrar.
	var tree := get_tree()
	_paused_by_us = tree != null and not tree.paused
	if _paused_by_us:
		tree.paused = true

	# LA FICHA VA EN LA PROPIA VENTANA, no solo en la vitrina: el momento en
	# que se consigue la pieza es cuando el jugador quiere saber QUÉ es. El
	# panel CRECE con el texto (se estima por caracteres: medirlo de verdad
	# pide un fotograma y el cartel se monta ya colocado).
	var desc := CollectibleData.describe(id)
	var extra_txt := str(item["extra"])
	var desc_h := 0.0
	if desc != "":
		desc_h = clampf(ceili(desc.length() / 40.0) * 30.0 + 10.0, 40.0, 136.0)
	var extra_h := 34.0 if extra_txt != "" else 0.0
	var panel_w := 520.0
	var panel_h := 434.0 + desc_h + extra_h + 110.0
	var panel := Control.new()
	panel.position = Vector2((cs.x - panel_w) * 0.5, (cs.y - panel_h) * 0.5)
	panel.size = Vector2(panel_w, panel_h)
	panel.pivot_offset = panel.size * 0.5
	root.add_child(panel)
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))

	var title := PrepBoard.make_big_title("¡Coleccionable\nconseguido!", 44)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 42.0
	title.offset_bottom = 150.0
	panel.add_child(title)

	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = CollectibleData.get_icon(id)
	ic.position = Vector2((panel_w - 200.0) * 0.5, 168.0)
	ic.size = Vector2(200, 200)
	ic.pivot_offset = Vector2(100, 100)
	panel.add_child(ic)
	# El objeto entra con un golpe de rebote.
	ic.scale = Vector2(0.2, 0.2)
	create_tween().tween_property(ic, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)

	var nombre := _label(CollectibleData.item_name(id), 32, Color(0.42, 0.26, 0.10))
	nombre.set_anchors_preset(Control.PRESET_TOP_WIDE)
	nombre.offset_top = 382.0
	nombre.offset_bottom = 424.0
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(nombre)

	var y := 428.0
	if desc != "":
		var ficha := _label(desc, 21, Color(0.30, 0.20, 0.10))
		ficha.set_anchors_preset(Control.PRESET_TOP_WIDE)
		ficha.offset_left = 46.0
		ficha.offset_right = -46.0
		ficha.offset_top = y
		ficha.offset_bottom = y + desc_h
		ficha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ficha.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(ficha)
		y += desc_h

	if extra_txt != "":
		var extra := _label(extra_txt, 22, Color(0.42, 0.26, 0.10))
		extra.set_anchors_preset(Control.PRESET_TOP_WIDE)
		extra.offset_left = 30.0
		extra.offset_right = -30.0
		extra.offset_top = y
		extra.offset_bottom = y + extra_h
		extra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(extra)
		y += extra_h

	var seguir := Button.new()
	seguir.text = "Continuar"
	PrepBoard.skin_button(seguir)
	seguir.add_theme_font_size_override("font_size", 26)
	seguir.set_anchors_preset(Control.PRESET_TOP_WIDE)
	seguir.offset_left = 140.0
	seguir.offset_right = -140.0
	seguir.offset_top = y + 12.0
	seguir.offset_bottom = y + 78.0
	panel.add_child(seguir)
	seguir.pressed.connect(func() -> void:
		if _paused_by_us and get_tree() != null:
			get_tree().paused = false
		root.queue_free()
		_done())

	panel.scale = Vector2(0.7, 0.7)
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)


# --------------------------------------------- ventana de subida de nivel

## Alto de cada renglón de botín y de la cabecera de la ventana.
const LVL_ROW_H := 52.0


func _show_level_up(data: Dictionary) -> void:
	Audio.sfx("trofeo")
	var desde := int(data.get("desde", 0))
	var hasta := int(data.get("hasta", 0))
	var premios: Dictionary = data.get("premios", {})
	# Orden fijo, de lo más gordo a lo más pequeño: la vista siempre lee igual.
	# Hoy `SkillData.level_reward` solo suelta points / gold / bait; los demás
	# se quedan en la lista para cuando el juego los explique y vuelvan.
	var orden := ["points", "ingots", "gold", "bait", "rice", "ingredients",
		"extras"]
	var filas: Array[String] = []
	for k in orden:
		if int(premios.get(k, 0)) > 0:
			filas.append(str(k))

	var cs := GameState.canvas_size()
	var root := Control.new()
	root.position = Vector2.ZERO
	root.size = cs
	add_child(root)
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(veil)
	create_tween().tween_property(veil, "color:a", 0.6, 0.25)

	var tree := get_tree()
	_paused_by_us = tree != null and not tree.paused
	if _paused_by_us:
		tree.paused = true

	var panel_w := 540.0
	# El alto sale de DÓNDE TERMINA el último renglón (los botines van de 1 a
	# 6 líneas): con una fórmula más corta, el botón se comía la última.
	var panel_h := 346.0 + LVL_ROW_H * float(filas.size())
	var panel := Control.new()
	panel.position = Vector2((cs.x - panel_w) * 0.5, (cs.y - panel_h) * 0.5)
	panel.size = Vector2(panel_w, panel_h)
	panel.pivot_offset = panel.size * 0.5
	root.add_child(panel)
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))

	# Titular: un nivel, o el tramo entero si cayeron varios de golpe.
	var titulo := PrepBoard.make_big_title(
		"¡Nivel %d!" % hasta if hasta - desde <= 1
		else "¡Niveles %d a %d!" % [desde + 1, hasta], 46)
	titulo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	titulo.offset_top = 34.0
	titulo.offset_bottom = 108.0
	panel.add_child(titulo)

	# La CHAPA del nivel: la estrella del juego con la cifra dentro.
	var chapa := TextureRect.new()
	chapa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chapa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chapa.texture = load("res://assets/ui/estrella_llena.png")
	chapa.position = Vector2((panel_w - 108.0) * 0.5, 112.0)
	chapa.size = Vector2(108, 108)
	chapa.pivot_offset = Vector2(54, 54)
	panel.add_child(chapa)
	var n_l := _label(str(hasta), 40, Color(0.36, 0.20, 0.04))
	n_l.set_anchors_preset(Control.PRESET_FULL_RECT)
	n_l.offset_top = 4.0
	n_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chapa.add_child(n_l)
	chapa.scale = Vector2(0.2, 0.2)
	chapa.rotation_degrees = -160.0
	var tc := chapa.create_tween().set_parallel(true)
	tc.tween_property(chapa, "scale", Vector2.ONE, 0.5).set_delay(0.1) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tc.tween_property(chapa, "rotation_degrees", 0.0, 0.5).set_delay(0.1) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# El botín, renglón a renglón, entrando en cascada.
	var y := 236.0
	var i := 0
	for k in filas:
		var fila := HBoxContainer.new()
		fila.alignment = BoxContainer.ALIGNMENT_CENTER
		fila.add_theme_constant_override("separation", 12)
		fila.set_anchors_preset(Control.PRESET_TOP_WIDE)
		fila.offset_top = y
		fila.offset_bottom = y + LVL_ROW_H
		panel.add_child(fila)
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var ruta := SkillData.reward_icon(k)
		if ResourceLoader.exists(ruta):
			ic.texture = load(ruta)
		ic.custom_minimum_size = Vector2(40, 40)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fila.add_child(ic)
		fila.add_child(_label(SkillData.reward_text(k, int(premios[k])), 26,
			Color(0.30, 0.19, 0.07)))
		fila.modulate.a = 0.0
		fila.position.x = -30.0
		var tf := fila.create_tween().set_parallel(true)
		tf.tween_property(fila, "modulate:a", 1.0, 0.25) \
				.set_delay(0.45 + 0.12 * i)
		tf.tween_property(fila, "position:x", 0.0, 0.35) \
				.set_delay(0.45 + 0.12 * i) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		y += LVL_ROW_H
		i += 1

	var seguir := Button.new()
	seguir.text = "¡Bien!"
	PrepBoard.skin_button(seguir)
	seguir.add_theme_font_size_override("font_size", 26)
	seguir.set_anchors_preset(Control.PRESET_TOP_WIDE)
	seguir.offset_left = 150.0
	seguir.offset_right = -150.0
	seguir.offset_top = panel_h - 94.0
	seguir.offset_bottom = panel_h - 28.0
	panel.add_child(seguir)
	seguir.pressed.connect(func() -> void:
		if _paused_by_us and get_tree() != null:
			get_tree().paused = false
		root.queue_free()
		_done())

	panel.scale = Vector2(0.7, 0.7)
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
