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

var _queue: Array = []
var _busy := false
var _paused_by_us := false


func _init() -> void:
	layer = NOTICE_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


## Notificación de LOGRO: icono + "¡Logro!" + nombre y medalla. No interactiva.
func toast_achievement(icon: Texture2D, tint: Color, title: String,
		subtitle: String) -> void:
	_queue.append({ "kind": "toast", "icon": icon, "tint": tint,
		"title": title, "subtitle": subtitle })
	_pump()


## Ventana de COLECCIONABLE conseguido. `extra` añade un renglón (el regalo de
## doblones del triángulo dorado).
func announce_collectible(id: String, extra := "") -> void:
	_queue.append({ "kind": "collectible", "id": id, "extra": extra })
	_pump()


func _pump() -> void:
	if _busy or _queue.is_empty():
		return
	_busy = true
	var item: Dictionary = _queue.pop_front()
	if item["kind"] == "toast":
		_show_toast(item)
	else:
		_show_collectible(item)


func _done() -> void:
	_busy = false
	_pump()


# ------------------------------------------------------------------- toast

func _show_toast(item: Dictionary) -> void:
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
		_done())


# ------------------------------------------------- ventana de coleccionable

func _show_collectible(item: Dictionary) -> void:
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

	var panel_w := 520.0
	var panel_h := 560.0
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

	if str(item["extra"]) != "":
		var extra := _label(str(item["extra"]), 22, Color(0.30, 0.20, 0.10))
		extra.set_anchors_preset(Control.PRESET_TOP_WIDE)
		extra.offset_top = 424.0
		extra.offset_bottom = 454.0
		extra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(extra)

	var seguir := Button.new()
	seguir.text = "Continuar"
	PrepBoard.skin_button(seguir)
	seguir.add_theme_font_size_override("font_size", 26)
	seguir.set_anchors_preset(Control.PRESET_TOP_WIDE)
	seguir.offset_left = 140.0
	seguir.offset_right = -140.0
	seguir.offset_top = 462.0
	seguir.offset_bottom = 528.0
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
