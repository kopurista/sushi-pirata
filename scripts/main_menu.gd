extends "res://scripts/level_select3d.gd"
## Menú principal Y mapa de campaña en UNA SOLA ESCENA.
##
## Hereda el mapa marítimo entero (mar, ruta, nodos de campaña, barco, cámara
## y su interfaz) y le añade el estado "menú": el barco fondeado en mar abierto
## MUY POR DEBAJO del nivel 1 —fuera del encuadre—, con el logotipo, los
## botones de modo, gaviotas y nubes.
##
## Así la transición a Aventura es de verdad: no se cambia de escena, el barco
## navega desde su fondeadero hasta el último nivel abierto y la interfaz del
## mapa entra en su sitio. Volver atrás desanda el camino.

## Fondeadero del menú, en píxeles de mapa: lo bastante por debajo del nivel 1
## como para que ningún nodo de campaña asome por arriba.
const MENU_ANCHOR := Vector2(360.0, 2680.0)
## Cuánto se sube la vista respecto al barco cuando manda el menú: deja hueco
## al logotipo arriba y a los botones abajo.
const MENU_BAND_OFF := -70.0
const OUT_TIME := 0.55
## Distancia (en px de mapa) que recorre el barco al entrar o salir de escena.
const OFFSCREEN := 1500.0
## En el menú el barco es el protagonista y se ve mucho más grande que como
## ficha del mapa.
const MENU_SHIP_SCALE := 2.3
## Tienda: dónde acaba el muelle (u), lo que navega el barco a su encuentro y
## dónde queda el encuadre al cerrar el zoom (px de mapa; 85.3 px = 1 u).
## Calibrado para que en el zoom quepan el barco entero Y el muelle: el barco
## del menú es grande y con `size` 7.5 el puerto se quedaba fuera de cuadro.
const SHOP_DOCK_AT := 7.9
const SHOP_SAIL := 300.0
const SHOP_ZOOM_SIDE := 430.0
const SHOP_ZOOM_SIZE := 9.4
## Botones redondos de las esquinas: la medalla de Logros arriba a la izquierda
## y la rueda de Opciones arriba a la derecha, en el hueco que dejó el monedero
## (el dinero solo se enseña donde se puede ganar o gastar). El rótulo va
## DENTRO del alto del botón: colgándolo por debajo se salía de la pantalla.
const ROUND_SIZE := 112.0
const ROUND_LABEL := 32.0
const ROUND_MARGIN := 16.0

var logo: TextureRect
## El logotipo vive dentro de este contenedor: el balanceo mueve el logo y las
## transiciones mueven el contenedor, para que no peleen por `position:y`.
var logo_holder: Control = null
var logo_float: Tween = null
var logo_sway: Tween = null
var ui_layer: CanvasLayer = null
var button_box: VBoxContainer = null
## Botones redondos de las esquinas: la rueda de ajustes abajo a la derecha y
## la medalla de los logros arriba a la izquierda.
var gear_button: Control = null
var medal_button: Control = null
## true mientras se ve el menú (con el mapa fuera de pantalla).
var in_menu := true
## Mientras hay una transición en marcha no se aceptan más pulsaciones.
var leaving := false
var birds: Array = []
var clouds: Array = []
## Mientras las gaviotas y las nubes se retiran, `_process` deja de colocarlas.
var sky_leaving := false
var _mt := 0.0
## Tween de entrada/salida de la interfaz del menú (uno solo a la vez).
var ui_tween: Tween = null
## Posición de reposo de cada bloque de interfaz. Hay que guardarla al
## construirla: después de una salida, la posición actual ya está desplazada.
var home_logo_y := 96.0
var home_box_y := 0.0
var home_medal_y := 0.0
var home_gear_y := 0.0
## 1 = encuadre de menú, 0 = encuadre de mapa. Se interpola durante el viaje
## para que la cámara no dé un salto al cambiar de estado.
var menu_blend := 1.0
## Desplazamiento lateral del encuadre (px de mapa). Lo usa la transición a la
## tienda para que la cámara siga al barco mientras atraca.
var cam_side := 0.0


func _ready() -> void:
	# El padre monta el mundo del mapa entero y su interfaz.
	super._ready()
	_setup_birds()
	_setup_clouds()
	_setup_menu_ui()
	# Un frame para que el layout resuelva y `home_*` valga algo: las
	# animaciones de entrada lo necesitan.
	await get_tree().process_frame
	match GameState.take_transition():
		"mapa":
			# Se vuelve del selector de recetas de aventura: directo al mapa.
			_enter_map(false)
		"menu":
			_show_menu(false)
			_play_menu_intro()
		_:
			_show_menu(false)


# ------------------------------------------------- estados de la escena

## Modo MENÚ: barco en el fondeadero, mapa fuera de vista.
func _show_menu(animate: bool) -> void:
	in_menu = true
	map_visible = false
	sky_leaving = false
	_set_map_ui_visible(false)
	if ship_tween != null:
		ship_tween.kill()
		ship_tween = null
	if not animate:
		menu_blend = 1.0
		ship_px = MENU_ANCHOR
		cam_center = MENU_ANCHOR.y
		_update_camera()
	if ship_pivot != null:
		ship_pivot.scale = Vector3.ONE * MENU_SHIP_SCALE
	if ship_blob != null:
		ship_blob.scale = Vector3.ONE * MENU_SHIP_SCALE
	_set_menu_ui_visible(true)


## Modo MAPA: el barco navega hasta el último nivel abierto y entra la
## interfaz de la campaña.
func _enter_map(animate: bool) -> void:
	in_menu = false
	map_visible = true
	if not animate:
		_set_menu_ui_visible(false)
	_set_map_ui_visible(true)
	if animate:
		# Entra DESPUÉS de que el barco se ponga en camino: si aparece a la vez
		# que se van el logotipo y los botones, se pisan en pantalla.
		_map_ui_fade(true)
	if not animate:
		menu_blend = 0.0
		_focus_last_port(false)
		leaving = false
		return
	var target := last_open_port()
	var dest := _ship_anchor(target)
	var dur := 1.6
	# El barco recupera su tamaño de ficha del mapa mientras navega.
	var scale_tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	scale_tw.tween_property(ship_pivot, "scale", Vector3.ONE, dur * 0.8)
	scale_tw.tween_property(ship_blob, "scale", Vector3.ONE, dur * 0.8)
	if ship_tween != null:
		ship_tween.kill()
	# El encuadre pasa del alto del menú al del mapa POCO A POCO. Cambiarlo de
	# golpe (con un simple `if in_menu`) daba un salto de ~200 px justo al
	# arrancar el viaje, que es el "tirón" que se veía.
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(
		self, "menu_blend", 0.0, dur * 0.55)
	# La cámara acompaña al barco durante toda la travesía.
	ship_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ship_tween.tween_property(self, "ship_px", dest, dur)
	ship_tween.parallel().tween_property(self, "cam_center",
		clampf(CampaignData.map_pos(target).y, SCROLL_MIN, SCROLL_MAX), dur)
	ship_tween.parallel().tween_property(self, "ship_roll", 6.0, dur * 0.4)
	ship_tween.parallel().tween_property(self, "ship_roll", 0.0, dur * 0.5) \
			.set_delay(dur * 0.5)
	ship_tween.tween_callback(func() -> void:
		_select(target, false)
		leaving = false)


## Enciende o apaga la interfaz del mapa con un fundido.
func _map_ui_fade(show: bool) -> void:
	for node in [map_top_bar, map_info_panel]:
		if node == null:
			continue
		node.modulate.a = 0.0 if show else 1.0
		var tw := create_tween()
		if show:
			tw.tween_interval(0.45)
		tw.tween_property(node, "modulate:a", 1.0 if show else 0.0, 0.4)
	for id in node_overlays:
		var ov: Control = node_overlays[id]["root"]
		ov.modulate.a = 0.0 if show else 1.0
		var tw2 := create_tween()
		if show:
			tw2.tween_interval(0.6)
		tw2.tween_property(ov, "modulate:a", 1.0 if show else 0.0, 0.4)


## La cámara sigue al barco; en el menú se encuadra sobre su fondeadero.
func _update_camera() -> void:
	if cam == null:
		return
	var off := lerpf(BAND_CENTER_OFF, MENU_BAND_OFF, menu_blend)
	var target := _world(Vector2(360.0 + cam_side, cam_center + off))
	cam.position = target + cam.transform.basis.z * 30.0


func _set_map_ui_visible(on: bool) -> void:
	if map_top_bar != null:
		map_top_bar.visible = on
	if map_info_panel != null:
		map_info_panel.visible = on
	for id in node_overlays:
		node_overlays[id]["root"].visible = on


func _set_menu_ui_visible(on: bool) -> void:
	for node in [logo_holder, button_box, gear_button, medal_button]:
		if node != null:
			node.visible = on
	for b in birds:
		b["node"].visible = on
	for c in clouds:
		c["node"].visible = on


# ------------------------------------------------------------ menú: mundo

## Gaviotas: cuerpo claro y alas en V que baten, dando vueltas sobre el barco.
## La V y el cuerpo hacen falta: con las alas planas y alineadas, desde la
## cámara isométrica solo se veía una barra blanca.
func _setup_birds() -> void:
	# Con "menos animaciones" ni se crean: son adorno y cada una es geometría
	# que se mueve por frame.
	if not GameState.animations_on():
		return
	var wing_mat := StandardMaterial3D.new()
	wing_mat.albedo_color = Color(0.98, 0.98, 0.96)
	wing_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.88, 0.89, 0.93)
	body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 4:
		var pivot := Node3D.new()
		add_child(pivot)
		var body := MeshInstance3D.new()
		var body_box := BoxMesh.new()
		body_box.size = Vector3(0.12, 0.1, 0.34)
		body.mesh = body_box
		body.material_override = body_mat
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(body)
		var wings: Array = []
		for sgn in [-1.0, 1.0]:
			var hinge := Node3D.new()
			pivot.add_child(hinge)
			var mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.66, 0.04, 0.17)
			mi.mesh = box
			mi.position = Vector3(sgn * 0.33, 0.0, 0.0)
			mi.material_override = wing_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			hinge.add_child(mi)
			wings.append(hinge)
		birds.append({
			"node": pivot, "wings": wings, "radius": 3.6 + i * 1.5,
			"phase": i * (TAU / 4.0) + randf_range(-0.3, 0.3),
			"speed": 0.13 + i * 0.02, "y": 3.4 + i * 0.75, "flap": 4.6 + i * 0.7,
		})


## Nubes bajas y TRANSLÚCIDAS que cruzan por delante del barco. Van en 3D, así
## que el logotipo y los botones (CanvasLayer) siempre quedan por encima.
func _setup_clouds() -> void:
	if not GameState.animations_on():
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.42)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 3:
		var pivot := Node3D.new()
		add_child(pivot)
		for p in [Vector3(0, 0, 0), Vector3(0.85, -0.14, 0.2),
				Vector3(-0.8, -0.16, -0.16), Vector3(0.14, 0.26, -0.1)]:
			var mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(1.5, 0.5, 1.15) if p == Vector3.ZERO \
					else Vector3(1.05, 0.4, 0.85)
			mi.mesh = box
			mi.position = p
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pivot.add_child(mi)
		clouds.append({
			"node": pivot, "side": -10.0 + i * 7.5, "along": 5.0 + i * 2.0,
			"y": 5.6 + randf_range(0.0, 1.2), "speed": 0.3 + randf() * 0.18,
		})


func _process(delta: float) -> void:
	super._process(delta)
	if not in_menu:
		return
	_mt += delta
	# Mientras se retiran del encuadre las mueve su tween, no esta función.
	if sky_leaving:
		return
	# Gaviotas y nubes viven alrededor del barco, esté donde esté.
	var here := _world(ship_px)
	for b in birds:
		var ang := _mt * float(b["speed"]) * TAU + float(b["phase"])
		var n: Node3D = b["node"]
		var r: float = b["radius"]
		n.position = here + R_HAT * (cos(ang) * r) \
				+ D_HAT * (sin(ang) * r * 0.55) \
				+ Vector3(0.0, float(b["y"])
					+ sin(_mt * 1.4 + float(b["phase"])) * 0.3, 0.0)
		n.rotation.y = -ang
		var flap := 0.32 + sin(_mt * float(b["flap"])) * 0.42
		b["wings"][0].rotation.z = flap
		b["wings"][1].rotation.z = -flap
	for c in clouds:
		c["side"] = float(c["side"]) + float(c["speed"]) * delta
		if float(c["side"]) > 11.0:
			c["side"] = -11.0
			c["along"] = randf_range(3.0, 9.0)
		var n2: Node3D = c["node"]
		n2.position = here + R_HAT * float(c["side"]) \
				+ D_HAT * float(c["along"]) + Vector3(0.0, float(c["y"]), 0.0)


# --------------------------------------------------------------- menú: UI

func _setup_menu_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	# En el MENÚ no se enseña el monedero: el dinero solo importa donde se
	# puede gastar o ganar (mapa de aventura, tienda e inventario). Su hueco de
	# la esquina superior derecha lo ocupa ahora la rueda de Opciones.


	# Logotipo, flotando sobre el mar. Va dentro de un contenedor propio.
	logo_holder = Control.new()
	logo_holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	logo_holder.offset_left = 26.0
	logo_holder.offset_right = -26.0
	logo_holder.offset_top = 96.0
	logo_holder.offset_bottom = 436.0
	logo_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(logo_holder)
	logo = TextureRect.new()
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture = load("res://assets/ui/logo_sushi_pirata.webp")
	logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_holder.add_child(logo)
	logo.pivot_offset = Vector2(334, 170)
	_start_logo_idle()

	# Botones de modo, anclados abajo.
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = 110.0
	box.offset_right = -110.0
	box.offset_top = -486.0
	box.offset_bottom = -54.0
	box.add_theme_constant_override("separation", 16)
	ui_layer.add_child(box)
	button_box = box
	box.add_child(_make_mode_button("Aventura", "ic_aventura", 118, 44,
		func() -> void: _go_adventure()))
	box.add_child(_make_mode_button("Arcade", "ic_arcade", 96, 36,
		func() -> void: _go_arcade()))
	box.add_child(_make_mode_button("Tienda", "ic_tienda", 96, 36,
		func() -> void: _go_shop()))
	box.add_child(_make_mode_button("Inventario", "ic_inventario", 96, 36,
		func() -> void: _go_inventory()))
	# Botones redondos de las esquinas. Van SUELTOS (no en el VBox) para poder
	# anclarlos a su esquina y animarlos por separado.
	medal_button = _make_round_button("ic_logros", "Logros",
		Control.PRESET_TOP_LEFT, Vector2(ROUND_MARGIN, ROUND_MARGIN),
		func() -> void: _go_achievements())
	gear_button = _make_round_button("ic_opciones", "Opciones",
		Control.PRESET_TOP_RIGHT,
		Vector2(-ROUND_MARGIN - ROUND_SIZE, ROUND_MARGIN),
		func() -> void: _go_options())

	# Las posiciones de reposo salen del propio layout (el que las anima no
	# puede leerlas más tarde: para entonces ya estarían desplazadas).
	var vp := get_viewport().get_visible_rect().size
	home_logo_y = 96.0
	home_box_y = vp.y - 486.0
	home_medal_y = ROUND_MARGIN
	home_gear_y = ROUND_MARGIN


## Botón REDONDO de esquina: el propio dibujo (rueda de timón, medalla) es el
## botón, con su mancha de sombra detrás y un rótulo pequeño debajo. No lleva
## tablón de madera: sobre el mar se lee mejor la silueta suelta.
func _make_round_button(icon: String, label: String, preset: int,
		offset: Vector2, action: Callable) -> Control:
	var holder := Control.new()
	holder.set_anchors_preset(preset)
	holder.position = offset
	holder.size = Vector2(ROUND_SIZE, ROUND_SIZE + ROUND_LABEL)
	holder.custom_minimum_size = holder.size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(holder)

	var tex: Texture2D = load("res://assets/ui/%s.png" % icon)
	var shadow := TextureRect.new()
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shadow.texture = tex
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow.offset_left = 4.0
	shadow.offset_top = 6.0
	shadow.offset_right = 4.0
	shadow.offset_bottom = 6.0 - ROUND_LABEL
	shadow.modulate = Color(0, 0, 0, 0.38)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(shadow)

	var b := TextureButton.new()
	b.texture_normal = tex
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.offset_bottom = -ROUND_LABEL
	b.pressed.connect(action)
	PrepBoard.add_press_feedback(b, 0.9)
	holder.add_child(b)

	var l := Label.new()
	l.text = label
	l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	l.offset_top = -ROUND_LABEL
	l.offset_bottom = 0.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.84))
	l.add_theme_color_override("font_outline_color", Color(0.11, 0.06, 0.02))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(l)
	return holder


## Flotación y balanceo del logotipo. Se guardan para poder PARARLOS: si siguen
## corriendo durante una transición, tiran del logotipo hacia su sitio y no
## llega a salir de la pantalla.
func _start_logo_idle() -> void:
	if leaving or not in_menu or not GameState.animations_on():
		return
	logo.position.y = 0.0
	logo_float = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	logo_float.tween_property(logo, "position:y", 14.0, 1.9)
	logo_float.tween_property(logo, "position:y", -14.0, 1.9)
	logo_sway = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	logo_sway.tween_property(logo, "rotation", deg_to_rad(1.4), 2.6)
	logo_sway.tween_property(logo, "rotation", deg_to_rad(-1.4), 2.6)


func _stop_logo_idle() -> void:
	for t in [logo_float, logo_sway]:
		if t != null and t.is_valid():
			t.kill()
	logo_float = null
	logo_sway = null


## Botón del menú: tabla de madera con marco dorado, icono a la izquierda y
## rótulo centrado sobre el conjunto.
func _make_mode_button(text: String, icon: String, height: int, font_size: int,
		action: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(500, height)
	PrepBoard.skin_button(b)
	b.pressed.connect(action)

	var icon_rect := TextureRect.new()
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = load("res://assets/ui/%s.png" % icon)
	icon_rect.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	icon_rect.offset_left = 22.0
	icon_rect.offset_right = 22.0 + height * 0.78
	icon_rect.offset_top = height * 0.12
	icon_rect.offset_bottom = -height * 0.12
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon_rect)

	var label := Label.new()
	label.text = text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = height * 0.9
	label.offset_right = -20.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	label.add_theme_color_override("font_outline_color", Color(0.13, 0.07, 0.02))
	label.add_theme_constant_override("outline_size", 9)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(label)
	return b


# ------------------------------------------------------------ transiciones

## Aparta la interfaz del menú: logotipo arriba, botones abajo, monedero arriba.
## Aparta la interfaz del menú: logotipo arriba, botones abajo, monedero
## arriba. Se anima el CONTENEDOR del logotipo (no el logotipo, que lo mueve
## su balanceo) y siempre contra posiciones ABSOLUTAS de reposo: con valores
## relativos, cada salida acumulaba desplazamiento y la entrada devolvía los
## botones a un sitio equivocado.
func _ui_out() -> void:
	_stop_logo_idle()
	if ui_tween != null and ui_tween.is_valid():
		ui_tween.kill()
	# Sin rebote: con TRANS_BACK el logotipo primero baja un poco (la
	# anticipación del easing) y parece que no llega a irse.
	ui_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_IN)
	ui_tween.tween_property(logo_holder, "position:y", -640.0, OUT_TIME)
	ui_tween.tween_property(button_box, "position:y", home_box_y + 660.0, OUT_TIME)
	# Los dos botones de esquina viven arriba: se van por el borde superior.
	ui_tween.tween_property(medal_button, "position:y", home_medal_y - 260.0, OUT_TIME)
	ui_tween.tween_property(gear_button, "position:y", home_gear_y - 260.0, OUT_TIME)


## Nubes y gaviotas se van hacia arriba, fuera del encuadre.
##
## `sky_leaving` PARA su colocación por frame mientras dura la subida: `_process`
## les fija la posición entera cada fotograma (viven alrededor del barco), así
## que peleaba con el tween y se las veía desaparecer y reaparecer de golpe.
func _sky_out(time := 0.8) -> void:
	sky_leaving = true
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN)
	for c in clouds:
		tw.tween_property(c["node"], "position:y", 16.0, time).as_relative()
	for b in birds:
		tw.tween_property(b["node"], "position:y", 18.0, time).as_relative()


## AVENTURA: sin cambiar de escena. El barco leva anclas y navega hasta el
## último nivel abierto mientras la interfaz del menú se retira.
func _go_adventure() -> void:
	if leaving:
		return
	leaving = true
	_ui_out()
	_sky_out(0.9)
	var tw := create_tween()
	# El barco no leva anclas hasta que el logotipo y los botones han SALIDO
	# del todo; si no, se ven irse a la vez que entra el mapa.
	tw.tween_interval(OUT_TIME + 0.08)
	tw.tween_callback(func() -> void:
		_set_menu_ui_visible(false)
		_enter_map(true))


## Vuelta del mapa al menú: el barco desanda el camino y todo reaparece.
func _back_to_menu() -> void:
	if leaving:
		return
	leaving = true
	_map_ui_fade(false)
	map_visible = false
	in_menu = true
	if ship_tween != null:
		ship_tween.kill()
	var dur := 1.5
	var scale_tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	scale_tw.tween_property(ship_pivot, "scale",
		Vector3.ONE * MENU_SHIP_SCALE, dur * 0.8).set_delay(dur * 0.2)
	scale_tw.tween_property(ship_blob, "scale",
		Vector3.ONE * MENU_SHIP_SCALE, dur * 0.8).set_delay(dur * 0.2)
	ship_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ship_tween.tween_property(self, "ship_px", MENU_ANCHOR, dur)
	ship_tween.parallel().tween_property(self, "cam_center", MENU_ANCHOR.y, dur)
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(
		self, "menu_blend", 1.0, dur * 0.7)
	# La interfaz vuelve con su propio temporizador: colgarla del tween del
	# barco (que va en paralelo con la cámara) se comía la animación.
	get_tree().create_timer(dur * 0.55).timeout.connect(func() -> void:
		leaving = false
		# Gaviotas y nubes vuelven a colgar del barco (se habían apartado).
		sky_leaving = false
		_set_map_ui_visible(false)
		_set_menu_ui_visible(true)
		_ui_in())


## ARCADE: el barco se va por la derecha y deja SOLO EL MAR de fondo; el
## selector de recetas entrará desde arriba.
func _go_arcade() -> void:
	if leaving:
		return
	leaving = true
	GameState.mode = "test"
	GameState.current_port = ""
	GameState.selected_recipes = []
	_ui_out()
	_sky_out(0.75)
	# Se mueve el barco en píxeles de mapa y la cámara se queda quieta: al
	# final del viaje, en pantalla solo queda el agua.
	var tw := create_tween()
	tw.tween_property(self, "ship_px", ship_px + Vector2(OFFSCREEN, 0.0), 0.85) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# El cambio de escena va por el fundido del autoload: el velo SOBREVIVE a la
	# carga, que es lo único que tapa los fotogramas grises del motor.
	tw.tween_callback(func() -> void:
		GameState.transition = "arcade"
		GameState.fade_to_scene("res://scenes/prep_screen.tscn", 0.3, 0.45))


## TIENDA: entra un puerto por la derecha, el barco navega hasta él con la
## CÁMARA DETRÁS, atraca, zoom sobre el atraque y a negro.
func _go_shop() -> void:
	if leaving:
		return
	leaving = true
	_ui_out()
	_sky_out(0.9)

	var here := _world(ship_px)
	var dock := SceneBackdrop._spawn_model(self,
		load("res://assets/models/map_puerto.glb"), 7.0)
	dock.position = here + R_HAT * 20.0 + Vector3(0.0, -0.1, 0.0)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(dock, "position", here + R_HAT * SHOP_DOCK_AT
		+ Vector3(0, -0.1, 0), 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "ship_px", ship_px + Vector2(SHOP_SAIL, 0.0), 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# La cámara ACOMPAÑA al barco mientras se acerca al muelle: quieta, el barco
	# se salía del encuadre y el zoom caía sobre mar vacío.
	tw.tween_property(self, "cam_side", SHOP_SAIL, 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# El zoom cierra sobre el atraque: entre el barco y el puesto del tendero.
	tw.chain().tween_property(cam, "size", SHOP_ZOOM_SIZE, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "cam_side", SHOP_ZOOM_SIDE, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_interval(0.15)
	tw.chain().tween_callback(func() -> void:
		GameState.transition = "tienda"
		GameState.fade_to_scene("res://scenes/shop_screen.tscn", 0.45, 0.5))


## LOGROS y OPCIONES: la interfaz se retira y se funde a negro. No traen
## coreografía propia (no son un sitio al que se navegue por mar).
func _go_achievements() -> void:
	_leave_to("res://scenes/achievements_screen.tscn")


func _go_options() -> void:
	_leave_to("res://scenes/options_screen.tscn")


func _leave_to(path: String) -> void:
	if leaving:
		return
	leaving = true
	_ui_out()
	var tw := create_tween()
	tw.tween_interval(OUT_TIME * 0.6)
	tw.tween_callback(func() -> void:
		GameState.fade_to_scene(path, 0.4, 0.4))


## INVENTARIO: la interfaz se retira y la pantalla se apaga.
func _go_inventory() -> void:
	if leaving:
		return
	leaving = true
	_ui_out()
	var tw := create_tween()
	tw.tween_interval(OUT_TIME * 0.6)
	tw.tween_callback(func() -> void:
		GameState.transition = "inventario"
		GameState.fade_to_scene("res://scenes/inventory_screen.tscn", 0.45, 0.4))


## Devuelve el logotipo, los botones y el monedero a su sitio.
func _ui_in() -> void:
	# El balanceo del logotipo arranca AL FINAL y con un temporizador aparte:
	# encadenarlo al mismo tween que la entrada (que va en paralelo) hacía que
	# los dos pelearan por position:y y el logotipo se quedaba a medio camino.
	_stop_logo_idle()
	if ui_tween != null and ui_tween.is_valid():
		ui_tween.kill()
	logo_holder.position.y = -640.0
	button_box.position.y = home_box_y + 660.0
	medal_button.position.y = home_medal_y - 260.0
	gear_button.position.y = home_gear_y - 260.0
	ui_tween = create_tween().set_parallel(true)
	ui_tween.tween_property(medal_button, "position:y", home_medal_y, 0.55) \
			.set_delay(0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ui_tween.tween_property(gear_button, "position:y", home_gear_y, 0.55) \
			.set_delay(0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ui_tween.tween_property(logo_holder, "position:y", home_logo_y, 0.6) 			.set_delay(0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ui_tween.tween_property(button_box, "position:y", home_box_y, 0.6) 			.set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(1.0).timeout.connect(_start_logo_idle)


## Entrada del menú viniendo de otra pantalla: el barco llega navegando desde
## la IZQUIERDA hasta su fondeadero y la interfaz baja detrás.
func _play_menu_intro() -> void:
	_set_menu_ui_visible(true)
	ship_px = MENU_ANCHOR - Vector2(OFFSCREEN, 0.0)
	create_tween().tween_property(self, "ship_px", MENU_ANCHOR, 0.95) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ui_in()
