class_name RecipeSheet
extends RefCounted
## LA FICHA DE UNA RECETA, en su propio archivo porque la abren DOS pantallas:
## el RECETARIO del inventario y el SELECTOR de antes de zarpar (pedido por el
## usuario: tocar el panel de un plato elegido tiene que contar el plato
## entero). Duplicarla habria sido garantizar que tarde o temprano las dos
## versiones dijeran cosas distintas del mismo plato.
##
## Todo lo de aqui es ESTATICO y se dibuja solo con datos: la ficha no puede
## contradecir a la cinta porque lee los mismos campos que `client3d`.

const PrepBoard := preload("res://scripts/prep_board.gd")
const Client3D := preload("res://scripts/client3d.gd")
const DARK := Color(0.26, 0.16, 0.08)
const FADED := Color(0.45, 0.34, 0.2)
const CLIENT_TYPES := ["E", "A", "G"]
const CLIENT_NAMES := { "E": "Grumete", "A": "Pirata", "G": "Capitán" }
## Retratos sacados de los MODELOS 3D del juego (tools/head_icons.gd), los
## mismos que usa el HUD del nivel: nada de sprites antiguos.
const CLIENT_SPRITES := {
	"E": "res://assets/ui/head_E.png",
	"A": "res://assets/ui/head_A.png",
	"G": "res://assets/ui/head_G.png",
}


static func abrir(host: Node, id: String) -> void:
	var data: Dictionary = RecipeData.RECIPES[id]
	var known := GameState.is_recipe_unlocked(id)

	var overlay := ColorRect.new()
	Audio.ventana(overlay)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(overlay)

	var box := Control.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 24.0
	box.offset_top = 90.0
	box.offset_right = -24.0
	box.offset_bottom = -60.0
	overlay.add_child(box)
	box.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 56.0
	vb.offset_top = 52.0
	vb.offset_right = -56.0
	vb.offset_bottom = -44.0
	vb.add_theme_constant_override("separation", 8)
	box.add_child(vb)

	var name_l := Label.new()
	name_l.text = str(data.get("name", id)) if known else "Receta por descubrir"
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.add_theme_font_size_override("font_size", 32)
	name_l.add_theme_color_override("font_color", DARK)
	vb.add_child(name_l)
	var lvl := int(data.get("level", 1))
	vb.add_child(PrepBoard.make_star_row(lvl, lvl, 28))

	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)

	var dish := TextureRect.new()
	dish.texture = RecipeData.get_dish_texture(id)
	dish.custom_minimum_size = Vector2(0, 190)
	dish.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dish.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not known:
		dish.modulate = Color(0.12, 0.1, 0.09, 0.8)
	body.add_child(dish)

	if not known:
		var locked := Label.new()
		locked.text = "Aún no la conoces. Supera niveles de la campaña para aprenderla."
		locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		locked.add_theme_font_size_override("font_size", 20)
		locked.add_theme_color_override("font_color", FADED)
		body.add_child(locked)
	else:
		# QUÉ HACE ESTE PLATO, lo primero de la ficha. Es el mismo texto que sale
		# en la ventana de "¡Receta nueva!" y se DEDUCE de los datos
		# (`RecipeData.summary`), así que las dos pantallas no pueden discrepar.
		var resumen := RecipeData.summary(id)
		if resumen != "":
			var desc := RichTextLabel.new()
			desc.bbcode_enabled = true
			desc.fit_content = true
			desc.scroll_active = false
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			desc.text = DialogueBox.format_keywords(resumen)
			desc.add_theme_font_size_override("normal_font_size", 20)
			desc.add_theme_font_size_override("bold_font_size", 20)
			desc.add_theme_color_override("default_color", DARK)
			body.add_child(desc)
		body.add_child(_bloque_datos(data))
		body.add_child(_titulo("Ingredientes"))
		body.add_child(_bloque_ingredientes(id))
		body.add_child(_titulo("Preferencias"))
		body.add_child(_bloque_clientes(data))
		# LA VERSIÓN MEJORADA, si esta receta tiene corona (RecipeData.UPGRADES):
		# ganada se enseña entera — dibujo, coronación, precio y mañas nuevas —
		# y sin ganar solo se insinúa en silueta, sin desvelar nada.
		var mejora := RecipeData.upgrade_of(id)
		if not mejora.is_empty():
			body.add_child(_titulo("Versión mejorada"))
			body.add_child(_bloque_mejora(id, mejora))

	var close := Button.new()
	close.text = "Cerrar"
	close.custom_minimum_size = Vector2(210, 74)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	PrepBoard.skin_button(close)
	close.add_theme_font_size_override("font_size", 25)
	close.pressed.connect(overlay.queue_free)
	vb.add_child(close)


static func _titulo(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 23)
	l.add_theme_color_override("font_color", Color(0.5, 0.3, 0.1))
	return l


## Precio, saciedad, cooldown y rasgos (maestría...).
static func _bloque_datos(data: Dictionary) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 2)
	var rows := [
		["Precio", "%d doblones" % int(data.get("price", 0))],
		["Espera", "%.1f s de cooldown" % (float(data.get("cooldown", 0.0))
			* RecipeData.RITMO_COOLDOWN)],
	]
	# "USOS EXTRA", no "maestria" (pedido por el usuario), y en singular
	# cuando es uno: el onigiri decia "las 1 siguientes salen solas".
	var libres := int(data.get("free_uses", 0))
	if libres == 1:
		rows.append(["Uso extra", "Haces una y sale otra ya hecha"])
	elif libres > 1:
		rows.append(["Usos extra", "Haces una y salen %d más ya hechas" % libres])
	if float(data.get("eat_mult", 1.0)) > 1.0:
		rows.append(["Ojo", "Se come más despacio de lo normal"])
	if float(data.get("tip_chance_bonus", 0.0)) > 0.0:
		rows.append(["Propinas", "Anima a dejar propina"])
	# EL MARIDAJE VA EN SU PROPIA FILA, no colgado del resumen (pedido por el
	# usuario): `RecipeData.summary` corta a SUMMARY_MAX frases y el maridaje
	# es lo primero que se caía — y es justo lo que hay que saber ANTES de
	# armar la carta, porque obliga a llevar las dos recetas.
	var mar: Dictionary = data.get("maridaje", {})
	if not mar.is_empty():
		var nombres: Array[String] = []
		for mid in mar.get("con", []):
			var md: Dictionary = RecipeData.get_recipe(str(mid))
			if md.is_empty() or bool(md.get("hidden", false)):
				continue
			nombres.append(str(md.get("name", mid)))
		if not nombres.is_empty():
			rows.append(["Maridaje", "+%d doblones si se sirve justo después de: %s"
				% [int(mar.get("bono", 0)), ", ".join(nombres)]])
	if float(data.get("fama", 0.0)) > 0.0:
		rows.append(["Gusta más", "Cada plato que sirves sube un %.1f%% la probabilidad de que un cliente lo coja (tope +%d%% por jornada)"
			% [float(data["fama"]) * 100.0,
			int(round(float(data.get("fama_max", 0.10)) * 100.0))]])
	for r in rows:
		var k := Label.new()
		k.text = str(r[0])
		k.add_theme_font_size_override("font_size", 19)
		k.add_theme_color_override("font_color", Color(0.5, 0.35, 0.15))
		grid.add_child(k)
		var v := Label.new()
		v.text = str(r[1])
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_font_size_override("font_size", 19)
		v.add_theme_color_override("font_color", DARK)
		grid.add_child(v)
	return grid


static func _bloque_ingredientes(id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for ing in RecipeData.get_recipe_ingredients(id):
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = RecipeData.get_ingredient_texture(ing)
		icon.custom_minimum_size = Vector2(74, 66)
		col.add_child(icon)
		var l := Label.new()
		l.text = str(RecipeData.INGREDIENTS.get(ing, {}).get("name", ing))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(78, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", DARK)
		col.add_child(l)
		row.add_child(col)
	return row


## Qué cliente es más probable que coja este plato de la cinta.
static func _bloque_clientes(data: Dictionary) -> Control:
	var tier := int(data.get("satiety", data.get("level", 1)))
	# "only_type": los postres SOLO los coge un tipo; los demás ni lo miran,
	# así que la ficha tiene que decirlo (si no, mentiría).
	var only: String = data.get("only_type", "")
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	for t in CLIENT_TYPES:
		var chance: float = 0.0
		if only == "" or only == t:
			chance = forced_chance(data, t, tier)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(CLIENT_SPRITES[t])
		icon.custom_minimum_size = Vector2(46, 56)
		row.add_child(icon)
		var l := Label.new()
		# Con el PORCENTAJE al lado (pedido por el usuario): la frase orienta
		# y la cifra deja comparar dos platos sin adivinar.
		l.text = "%s: %s · %d%%" % [CLIENT_NAMES[t], _texto_dado(chance),
			int(round(chance * 100.0))]
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 19)
		l.add_theme_color_override("font_color",
			DARK if chance >= 0.4 else FADED)
		row.add_child(l)
		col.add_child(row)
	return col


## La ficha de la VERSIÓN MEJORADA dentro de la ficha de su receta base.
## Ganada: dibujo, con qué se corona, precio y sus mañas (el mismo summary
## deducido de los datos, así que no puede mentir) y las preferencias con su
## porcentaje. Sin ganar: la silueta y una frase, que el premio es del mapa.
static func _bloque_mejora(base_id: String, mejora: Dictionary) -> Control:
	var up_id := str(mejora.get("id", ""))
	var up: Dictionary = RecipeData.get_recipe(up_id)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var dish := TextureRect.new()
	dish.texture = RecipeData.get_dish_texture(up_id)
	dish.custom_minimum_size = Vector2(0, 130)
	dish.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dish.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	col.add_child(dish)
	if not GameState.upgrade_unlocked(base_id):
		dish.modulate = Color(0.12, 0.1, 0.09, 0.8)
		var teaser := Label.new()
		teaser.text = "Esta receta tiene una versión mejorada. Su corona se gana navegando la aventura."
		teaser.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		teaser.add_theme_font_size_override("font_size", 19)
		teaser.add_theme_color_override("font_color", FADED)
		col.add_child(teaser)
		return col
	var nombre := Label.new()
	nombre.text = str(up.get("name", up_id))
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre.add_theme_font_size_override("font_size", 22)
	nombre.add_theme_color_override("font_color", Color(0.5, 0.3, 0.1))
	col.add_child(nombre)
	# Cómo se corona, con los nombres de verdad de los ingredientes.
	var nombres: Array[String] = []
	for ing in mejora.get("ingredients", []):
		nombres.append("**%s**" % str(RecipeData.get_ingredient(ing).get("name", ing)).to_lower())
	var como := RichTextLabel.new()
	como.bbcode_enabled = true
	como.fit_content = true
	como.scroll_active = false
	como.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	como.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var texto := "Corónala al terminar el plato con %s. Paga **%d doblones** (la base, %d) y para el paladar del cliente es un plato **nuevo**." % [
		" y ".join(nombres), int(up.get("price", 0)),
		int(RecipeData.get_recipe(base_id).get("price", 0))]
	var extra := RecipeData.summary(up_id)
	if extra != "":
		texto += " " + extra
	como.text = DialogueBox.format_keywords(texto)
	como.add_theme_font_size_override("normal_font_size", 19)
	como.add_theme_font_size_override("bold_font_size", 19)
	como.add_theme_color_override("default_color", DARK)
	col.add_child(como)
	col.add_child(_bloque_clientes(up))
	return col


## La probabilidad REAL de que ese tipo coja el plato, con la misma cuenta que
## hace el cliente: matriz propia de la receta si la trae ("take_chances", el
## barco), y encima el "take_chance" (número para todos o {E,A,G} por tipo).
static func forced_chance(data: Dictionary, client_type: String, tier: int) -> float:
	var table: Dictionary = data.get("take_chances", Client3D.TAKE_CHANCES)
	var base: float = float(table.get(client_type, {}).get(tier, 0.0))
	var forced: Variant = data.get("take_chance", null)
	if forced is Dictionary:
		return float(forced.get(client_type, base))
	if forced != null:
		return float(forced)
	return base


## La probabilidad, en cristiano.
static func _texto_dado(chance: float) -> String:
	if chance >= 0.7:
		return "Es de sus favoritos"
	if chance >= 0.3:
		return "Puede apetecerle"
	return "No le interesa"
