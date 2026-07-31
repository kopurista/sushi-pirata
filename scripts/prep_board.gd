extends Control
## Tabla de preparación gráfica: cada receta avanza por etapas visuales
## (bola de arroz → lámina → relleno → rollo → plato) sin textos.
## Los ingredientes desaparecen de la tabla cuando ya no se van a usar.
## El guardado funciona por pilas: cada caja apila hasta stack_max platos
## IGUALES (x2, x3...). Emite craft_event para que el chef reaccione.

signal dish_served(recipe_id: String)
signal craft_event(kind: String, stage_id: String)
## Contenido de las cajas de guardado tras cada cambio: array paralelo a las
## cajas con {"id", "count"} o null si esa caja está vacía. El nivel lo usa
## para reflejar lo guardado en las cajas 3D que hay junto al chef.
signal storage_changed(slots: Array)

enum State { IDLE, CRAFTING, READY }

const SWIPE_THRESHOLD := 70.0
## Recorrido horizontal (px) que debe cubrir el corte lento, de izquierda a
## derecha, por todo el ancho de la tabla.
const SLICE_SWEEP := 360.0
const DISH_SIZE := Vector2(132, 120)
## Tamaño de cada ingrediente en la fila de la tabla.
const ING_SIZE := Vector2(88, 76)

var state := State.IDLE
var current_recipe: String = ""
var steps: Array = []
var step_index: int = 0

var taps_done: int = 0
var swipes_done: int = 0
var hold_time: float = 0.0
var holding := false
var swipe_active := false
var swipe_counted := false
var swipe_start := Vector2.ZERO
## stir_board: vueltas completadas y ángulo acumulado de la vuelta en curso.
var stir_turns: int = 0
var stir_angle: float = 0.0
var stir_last_angle: float = 0.0
var stirring := false
## slice_board: cortes hechos y datos del corte en curso (inicio y tiempo).
var slices_done: int = 0
var slice_active := false
var slice_start := Vector2.ZERO
var slice_start_ms := 0
## Avance horizontal (px) del corte lento en curso, para llenar la barra.
var slice_progress: float = 0.0
## Mensaje momentáneo sobre la tabla ("¡Más lento!").
var message_label: Label = null
var message_tween: Tween = null
## drag_stage: fantasma del sprite de etapa mientras se arrastra al prop.
## Igual que en las cajas: exige arrastre real, un toque no completa el paso.
var stage_ghost: Control = null
var stage_drag_start := Vector2.ZERO
var stage_drag_moved := false
## Utensilio (sartén, arroz moldeado...) que aparece a la derecha de la tabla
## en los pasos drag_stage.
var prop_rect: TextureRect = null
var prop_tween: Tween = null
## Posición final del prop (el sprite entra animado; la mano de gestos debe
## apuntar aquí, no a la posición intermedia de la animación).
var prop_target := Vector2.ZERO

var cooldowns: Dictionary = {}
## Elaboraciones instantáneas restantes por receta dominada (id → usos).
var free_uses: Dictionary = {}
var buttons: Dictionary = {}
var button_badges: Dictionary = {}
var button_cooldown_labels: Dictionary = {}
var ingredient_nodes: Dictionary = {}
var ghost: Control = null

## Platos terminados sobre la tabla (1, o 2 con "Doble plato").
var dishes: Array = []
var ready_recipe: String = ""
var dragging_dish: Control = null
var drag_offset := Vector2.ZERO

## Cajas de guardado: índice de caja → { "id", "count", "node", "count_label" }.
var stacks: Dictionary = {}
var storage_slots := 2
var storage_panels: Array = []
## Máximo de platos iguales por caja ("Más almacén" lo sube a 5).
var stack_max := 3
var stack_drag_index := -1
var stack_ghost: Control = null
## Punto donde empezó el arrastre desde la caja y si hubo movimiento real
## (un simple toque NO debe mandar el plato a la cinta).
var stack_drag_start := Vector2.ZERO
var stack_drag_moved := false

# --- Efectos de potenciadores ---
var instant_recipes: int = 0
var skip_next_cooldown: bool = false
var easy_next: bool = false
## "Doble plato": la siguiente receta produce 2 platos.
var double_next: bool = false
var cooldown_mult: float = 1.0
var cooldown_mult_timer: float = 0.0
## Potenciador PERMANENTE "Cocina veloz" (PerkData): multiplica el cooldown
## durante toda la partida. Va aparte de cooldown_mult, que es temporal y
## vuelve a 1.0 al expirar.
var cooldown_perm_mult: float = 1.0

var stage_tween: Tween = null
var instruction_tween: Tween = null
## Mano de gestos: muestra semitransparente cómo ejecutar cada interacción
## (pulsar, mantener, arrastrar, deslizar, círculo) con dos poses.
var hand: TextureRect = null
var hand_up_tex: Texture2D = null
var hand_down_tex: Texture2D = null
## Fantasma semitransparente del objeto que se arrastra en el ejemplo.
var ghost_hint: TextureRect = null
## Flecha que acompaña a la mano en los gestos de deslizamiento.
var arrow_hint: TextureRect = null
## Anillo que late sobre el punto donde hay que pulsar/mantener.
var touch_ring: Panel = null
var ring_tween: Tween = null
var indicator_tween: Tween = null

@onready var board_panel: Panel = $BoardPanel
@onready var ingredients_row: HBoxContainer = $BoardPanel/Ingredients
@onready var stage_rect: TextureRect = $BoardPanel/StageRect
@onready var tap_zone: Control = $BoardPanel/TapZone
@onready var tap_bar: ProgressBar = $BoardPanel/TapBar
@onready var instruction_label: Label = $Instruction
@onready var cancel_button: Button = $CancelButton
@onready var buttons_box: HBoxContainer = $Buttons
@onready var serve_slot: Control = $ServeSlot
@onready var belt_sprite: TextureRect = $ServeSlot/BeltSprite
@onready var storage_box: GridContainer = $StorageBox

## Desplazamiento de la cinta del panel (misma velocidad que la de la cubierta).
var panel_belt_scroll := 0.0


## Fondo 9-patch pirata para un Control.
static func make_nine_patch(tex_path: String, margin: int) -> NinePatchRect:
	var np := NinePatchRect.new()
	np.name = "Skin"
	np.texture = load(tex_path)
	np.patch_margin_left = margin
	np.patch_margin_top = margin
	np.patch_margin_right = margin
	np.patch_margin_bottom = margin
	np.set_anchors_preset(Control.PRESET_FULL_RECT)
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	np.show_behind_parent = true
	return np


## Textura y margen 9-slice del botón de madera con marco dorado que usa TODO
## el juego (menú, tienda, resultados, "Zarpar"...).
const BUTTON_TEX := "res://assets/ui/boton_madera.png"
const BUTTON_MARGIN := 52


## Aspecto pirata para un botón: tabla de madera con marco dorado y remaches,
## sombra proyectada para despegarlo del fondo y hundido al pulsarlo.
static func skin_button(b: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, empty)
	b.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 0.94))
	b.add_theme_color_override("font_pressed_color", Color(0.92, 0.86, 0.74))
	b.add_theme_color_override("font_disabled_color", Color(0.7, 0.65, 0.58))
	b.add_theme_color_override("font_outline_color", Color(0.13, 0.07, 0.02))
	b.add_theme_constant_override("outline_size", 8)
	if b.has_node("Skin"):
		return
	var shadow := make_nine_patch(BUTTON_TEX, BUTTON_MARGIN)
	shadow.name = "SkinShadow"
	shadow.modulate = Color(0, 0, 0, 0.35)
	shadow.offset_left = 4.0
	shadow.offset_top = 7.0
	shadow.offset_right = 4.0
	shadow.offset_bottom = 7.0
	b.add_child(shadow)
	var skin := make_nine_patch(BUTTON_TEX, BUTTON_MARGIN)
	b.add_child(skin)
	# Se hunde al pulsarlo (el pivote sigue al centro) y, en botones pequeños,
	# el marco 9-slice se encoge: con el margen fijo los cuatro trozos de
	# esquina no cabían y el dorado salía aplastado.
	b.resized.connect(func() -> void:
		b.pivot_offset = b.size / 2.0
		var m := mini(BUTTON_MARGIN, int(minf(b.size.x, b.size.y) * 0.44))
		for np in [skin, shadow]:
			np.patch_margin_left = m
			np.patch_margin_top = m
			np.patch_margin_right = m
			np.patch_margin_bottom = m)
	b.button_down.connect(func() -> void: b.scale = Vector2(0.965, 0.94))
	b.button_up.connect(func() -> void: b.scale = Vector2.ONE)


## Fila de estrellas con las imágenes propias del juego (llenas y vacías).
## Con shadow=true cada estrella lleva una sombra leve desplazada, para
## diferenciarla del fondo.
static func make_star_row(count: int, total: int, star_size: float, shadow := false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in total:
		var tex: Texture2D = load("res://assets/ui/estrella_llena.png" if i < count
				else "res://assets/ui/estrella_vacia.png")
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(star_size, star_size)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if shadow:
			var sh := TextureRect.new()
			sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sh.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sh.texture = tex
			sh.set_anchors_preset(Control.PRESET_FULL_RECT)
			sh.offset_left = 2.0
			sh.offset_top = 3.0
			sh.offset_right = 2.0
			sh.offset_bottom = 3.0
			sh.modulate = Color(0, 0, 0, 0.38)
			sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(sh)
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = tex
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(ic)
		row.add_child(holder)
	return row


func _ready() -> void:
	if GameState.selected_recipes.is_empty():
		# Fallback para poder probar level.tscn directamente sin pasar por la selección.
		var fallback: Array[String] = ["maki_aguacate", "nigiri_salmon", "maki_atun", "futomaki_salmon"]
		GameState.selected_recipes = fallback
	# Recetas ordenadas de menor a mayor: primero por estrellas, luego precio.
	var sorted_ids := GameState.selected_recipes.duplicate()
	sorted_ids.sort_custom(func(a: String, b: String) -> bool:
		var da := RecipeData.get_recipe(a)
		var db := RecipeData.get_recipe(b)
		if da.level != db.level:
			return da.level < db.level
		return da.price < db.price)
	for id in sorted_ids:
		_build_recipe_button(id)
	for i in storage_slots:
		_add_storage_panel()
	skin_button(cancel_button)
	cancel_button.pressed.connect(_cancel_prep)
	# Al desaparecer un ingrediente ya usado, la fila se reordena y los que
	# quedan se desplazan; hay que recolocar la mano de gestos sobre el nuevo
	# objetivo o quedaría desajustada (recetas con 3+ ingredientes).
	ingredients_row.sort_children.connect(_on_ingredients_sorted)
	# Utensilio de los pasos drag_stage (se crea antes que la mano para que
	# los indicadores queden por encima).
	prop_rect = TextureRect.new()
	prop_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prop_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prop_rect.size = Vector2(168, 134)
	prop_rect.visible = false
	prop_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prop_rect)
	# Mensaje momentáneo sobre la tabla (p. ej. "¡Más lento!" al cortar rápido).
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 40)
	message_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 8)
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_label.visible = false
	add_child(message_label)
	# La instrucción del paso ("¡Pulsa x4!", "Mantén pulsado"...) se enciende
	# sola desde _update_instruction() mientras se elabora.
	instruction_label.visible = false
	# Anillo del punto de toque (debajo de la mano en orden de dibujo).
	touch_ring = Panel.new()
	var ring_sb := StyleBoxFlat.new()
	ring_sb.bg_color = Color(1.0, 0.86, 0.3, 0.14)
	ring_sb.border_color = Color(1.0, 0.88, 0.35, 0.95)
	ring_sb.set_border_width_all(7)
	ring_sb.set_corner_radius_all(int(RING_SIZE.x / 2.0))
	touch_ring.add_theme_stylebox_override("panel", ring_sb)
	touch_ring.size = RING_SIZE
	touch_ring.pivot_offset = RING_SIZE / 2.0
	touch_ring.visible = false
	touch_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(touch_ring)
	# Mano de gestos: grande y bien visible, es la guía principal del jugador.
	hand_up_tex = load("res://assets/ui/mano_arriba.png")
	hand_down_tex = load("res://assets/ui/mano_abajo.png")
	hand = TextureRect.new()
	# expand_mode ANTES que texture: si no, el tamaño mínimo salta al de la
	# textura (421x546) y la mano sale gigante.
	hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hand.texture = hand_up_tex
	hand.size = HAND_SIZE
	hand.modulate = Color(1, 1, 1, HAND_ALPHA)
	hand.visible = false
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hand)
	# Flecha de dirección para los gestos de deslizamiento.
	arrow_hint = TextureRect.new()
	arrow_hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow_hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow_hint.texture = load("res://assets/ui/flecha.png")
	arrow_hint.size = ARROW_SIZE
	arrow_hint.pivot_offset = ARROW_SIZE / 2.0
	arrow_hint.modulate = Color(1, 1, 1, 0.9)
	arrow_hint.visible = false
	arrow_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(arrow_hint)
	# Fantasma semitransparente de ejemplo para los gestos de arrastre.
	ghost_hint = TextureRect.new()
	ghost_hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost_hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost_hint.modulate = Color(1, 1, 1, 0.7)
	ghost_hint.visible = false
	ghost_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ghost_hint)
	# Barra de progreso vistosa: borde dorado y relleno verde.
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.08, 0.06, 0.04, 0.92)
	bar_bg.set_corner_radius_all(10)
	bar_bg.set_border_width_all(3)
	bar_bg.border_color = Color(0.95, 0.8, 0.3)
	tap_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.3, 0.88, 0.35)
	bar_fill.set_corner_radius_all(8)
	tap_bar.add_theme_stylebox_override("fill", bar_fill)
	# La cinta del panel se mueve continuamente, igual que la de la cubierta.
	var belt_mat := ShaderMaterial.new()
	belt_mat.shader = load("res://shaders/belt_scroll.gdshader")
	belt_sprite.material = belt_mat
	_update_ui()


## Botón de receta: sprite grande del plato + estrellas de nivel.
## El cooldown aparece en grande ENCIMA del plato.
func _build_recipe_button(id: String) -> void:
	var data := RecipeData.get_recipe(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(165, 132)
	# Fondo de pergamino desgastado (en lugar de madera) para que el plato y
	# las estrellas destaquen.
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.add_child(make_nine_patch("res://assets/ui/panel.png", 34))

	# El plato ocupa casi todo el botón (grande y uniforme), dejando abajo una
	# franja para las estrellas.
	var tex := RecipeData.get_dish_texture(id)
	if tex != null:
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = tex
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 8.0
		ic.offset_top = 8.0
		ic.offset_right = -8.0
		ic.offset_bottom = -34.0
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)

	# Estrellas en la franja inferior, algo subidas y con sombra leve para
	# que se distingan bien del pergamino.
	var stars := make_star_row(int(data.get("level", 1)), int(data.get("level", 1)), 26, true)
	stars.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	stars.offset_top = -40.0
	stars.offset_bottom = -14.0
	b.add_child(stars)

	# Insignia de maestría/reciclaje: "x2", "x3"...
	var badge := Label.new()
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -66.0
	badge.offset_top = 2.0
	badge.offset_right = -8.0
	badge.offset_bottom = 30.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.add_theme_font_size_override("font_size", 20)
	badge.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	badge.add_theme_color_override("font_outline_color", Color.BLACK)
	badge.add_theme_constant_override("outline_size", 5)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(badge)

	# Cooldown grande y visible encima de la receta.
	var cd := Label.new()
	cd.set_anchors_preset(Control.PRESET_FULL_RECT)
	cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd.add_theme_font_size_override("font_size", 44)
	cd.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
	cd.add_theme_color_override("font_outline_color", Color.BLACK)
	cd.add_theme_constant_override("outline_size", 8)
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd.visible = false
	b.add_child(cd)

	b.pressed.connect(_start_prep.bind(id))
	buttons_box.add_child(b)
	buttons[id] = b
	button_badges[id] = badge
	button_cooldown_labels[id] = cd
	cooldowns[id] = 0.0


func _add_storage_panel() -> void:
	var p := Control.new()
	p.custom_minimum_size = Vector2(90, 90)
	var slot_tex := "res://assets/ui/slot.png"
	if ResourceLoader.exists(slot_tex):
		var t := TextureRect.new()
		t.texture = load(slot_tex)
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(t)
	storage_box.add_child(p)
	storage_panels.append(p)


## Potenciador "Guardar un plato más": una caja extra.
func add_storage_slot() -> void:
	storage_slots += 1
	_add_storage_panel()


## Potenciador "Reciclaje de platos": vuelve como uso instantáneo (xN).
func recycle_recipe(recipe_id: String) -> void:
	if recipe_id in cooldowns:
		free_uses[recipe_id] = free_uses.get(recipe_id, 0) + 1


func _process(delta: float) -> void:
	# Cinta del panel siempre en marcha (sincronizada con la de la cubierta).
	if belt_sprite.material != null:
		var tex := belt_sprite.texture
		var tile_px: float = tex.get_width() * (belt_sprite.size.y / tex.get_height())
		panel_belt_scroll += 75.0 * delta / maxf(tile_px, 1.0)
		belt_sprite.material.set_shader_parameter("scroll_offset", panel_belt_scroll)

	if cooldown_mult_timer > 0.0:
		cooldown_mult_timer -= delta
		if cooldown_mult_timer <= 0.0:
			cooldown_mult = 1.0
	for id in cooldowns:
		if cooldowns[id] > 0.0:
			cooldowns[id] = maxf(cooldowns[id] - delta, 0.0)
	for id in buttons:
		var b: Button = buttons[id]
		var badge: Label = button_badges[id]
		var cd: Label = button_cooldown_labels[id]
		if cooldowns[id] > 0.0:
			b.disabled = true
			b.modulate = Color(0.55, 0.55, 0.55)
			cd.visible = true
			cd.text = "%d" % ceili(cooldowns[id])
		else:
			cd.visible = false
			b.disabled = state != State.IDLE and state != State.READY
			b.modulate = Color.WHITE if not b.disabled else Color(0.75, 0.75, 0.75)
		badge.text = "x%d" % free_uses[id] if free_uses.get(id, 0) > 0 else ""

	if state == State.CRAFTING and holding:
		var step := _current_step()
		if step.get("type", "") == "hold_board":
			hold_time += delta
			var duration: float = step.get("duration", 1.0)
			if hold_time >= duration:
				holding = false
				_advance_step()
			else:
				_update_ui()


func _current_step() -> Dictionary:
	if step_index >= 0 and step_index < steps.size():
		return steps[step_index]
	return {}


func _current_stage_id() -> String:
	var stages: Array = RecipeData.get_recipe(current_recipe).get("stages", [])
	var idx := step_index - 1
	if idx >= 0 and idx < stages.size():
		return stages[idx]
	return ""


func _start_prep(id: String) -> void:
	if state != State.IDLE or cooldowns[id] > 0.0:
		return
	current_recipe = id
	if instant_recipes > 0:
		instant_recipes -= 1
		_finish_prep(false)
		return
	if free_uses.get(id, 0) > 0:
		free_uses[id] -= 1
		_finish_prep(false)
		return
	state = State.CRAFTING
	steps = RecipeData.get_recipe(id).steps
	if easy_next:
		easy_next = false
		steps = _simplify_steps(steps)
	step_index = 0
	_reset_step_progress()
	_set_stage("")
	_build_ingredients(id)
	_update_prop()
	craft_event.emit("select", "")
	_update_ui()


## Cancelable en cualquier momento mientras se está elaborando.
func _can_cancel() -> bool:
	return state == State.CRAFTING


func _cancel_prep() -> void:
	if not _can_cancel():
		return
	state = State.IDLE
	current_recipe = ""
	steps = []
	_reset_step_progress()
	# Limpia cualquier arrastre de ejemplo en curso.
	if ghost != null:
		ghost.queue_free()
		ghost = null
	if stage_ghost != null:
		stage_ghost.queue_free()
		stage_ghost = null
	_set_stage("")
	_clear_ingredients()
	_update_prop()
	craft_event.emit("cancel", "")
	_update_ui()


## "Manos rápidas": deja solo los pasos de ingredientes.
func _simplify_steps(source: Array) -> Array:
	var result: Array = []
	for step in source:
		var t: String = step.get("type", "")
		if t == "tap_ingredient" or t == "drag_ingredient":
			result.append(step)
	if result.is_empty():
		result.append(source[0])
	return result


func _reset_step_progress() -> void:
	taps_done = 0
	swipes_done = 0
	hold_time = 0.0
	holding = false
	swipe_active = false
	swipe_counted = false
	stir_turns = 0
	stir_angle = 0.0
	stirring = false
	slices_done = 0
	slice_active = false
	slice_progress = 0.0


func _clear_ingredients() -> void:
	for child in ingredients_row.get_children():
		child.queue_free()
	ingredient_nodes.clear()


func _ingredient_texture(ing_id: String) -> Texture2D:
	var path := "res://assets/ingredients/%s.png" % ing_id
	return load(path) if ResourceLoader.exists(path) else null


func _build_ingredients(recipe_id: String) -> void:
	_clear_ingredients()
	for ing_id in RecipeData.get_recipe_ingredients(recipe_id):
		var holder := Control.new()
		holder.custom_minimum_size = ING_SIZE
		var tex := _ingredient_texture(ing_id)
		if tex != null:
			var t := TextureRect.new()
			t.texture = tex
			t.set_anchors_preset(Control.PRESET_FULL_RECT)
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(t)
		ingredients_row.add_child(holder)
		ingredient_nodes[ing_id] = holder


## Elimina de la tabla los ingredientes que ya no se van a usar.
func _prune_ingredients() -> void:
	var needed := {}
	for i in range(step_index, steps.size()):
		var ing: String = steps[i].get("ingredient", "")
		if ing != "":
			needed[ing] = true
	for ing_id in ingredient_nodes.keys():
		if not needed.has(ing_id):
			var node: Control = ingredient_nodes[ing_id]
			ingredient_nodes.erase(ing_id)
			var tw := create_tween()
			tw.tween_property(node, "modulate:a", 0.0, 0.25)
			tw.tween_callback(node.queue_free)


## La fila de ingredientes se ha reordenado (uno desapareció y los demás se
## desplazan): si el paso actual apunta a un ingrediente, recolocamos la mano
## sobre su nueva posición. Diferido para leer los rects ya reposicionados.
func _on_ingredients_sorted() -> void:
	if state != State.CRAFTING:
		return
	var t: String = _current_step().get("type", "")
	if t == "tap_ingredient" or t == "drag_ingredient":
		call_deferred("_refresh_indicator")


## Cambia el sprite de la etapa en la tabla con una animación de aparición.
func _set_stage(stage_id: String) -> void:
	var tex := RecipeData.get_stage_texture(stage_id)
	stage_rect.texture = tex
	stage_rect.visible = tex != null
	if tex != null:
		stage_rect.pivot_offset = stage_rect.size / 2.0
		if stage_tween != null:
			stage_tween.kill()
		stage_rect.scale = Vector2(0.6, 0.6)
		stage_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		stage_tween.tween_property(stage_rect, "scale", Vector2.ONE, 0.25)


## Pequeña sacudida del sprite de etapa (feedback de cada gesto).
func _bump_stage(rotate_deg: float = 0.0) -> void:
	if not stage_rect.visible:
		return
	stage_rect.pivot_offset = stage_rect.size / 2.0
	if stage_tween != null:
		stage_tween.kill()
	stage_rect.scale = Vector2(1.12, 0.88)
	stage_rect.rotation_degrees = rotate_deg
	stage_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	stage_tween.tween_property(stage_rect, "scale", Vector2.ONE, 0.3)
	stage_tween.parallel().tween_property(stage_rect, "rotation_degrees", 0.0, 0.3)


func _advance_step() -> void:
	_reset_step_progress()
	step_index += 1
	_prune_ingredients()
	if step_index >= steps.size():
		# El plato recién hecho es el mismo voxel que el emplatado.
		_finish_prep(true)
		return
	var stages: Array = RecipeData.get_recipe(current_recipe).get("stages", [])
	var stage_id: String = stages[step_index - 1] if step_index - 1 < stages.size() else ""
	_set_stage(stage_id)
	_update_prop()
	craft_event.emit("stage", stage_id)
	_update_ui()


func _input(event: InputEvent) -> void:
	if stack_drag_index >= 0:
		_continue_stack_drag(event)
		return
	if dragging_dish != null:
		_continue_dish_drag(event)
		return
	if event is InputEventScreenTouch and event.pressed:
		if _try_start_dish_drag(event):
			return
		if _try_start_stack_drag(event):
			return
	if state == State.CRAFTING:
		_handle_craft_input(event)


# --- Arrastre de platos terminados (sobre la tabla) ---

func _try_start_dish_drag(event: InputEventScreenTouch) -> bool:
	if state != State.READY:
		return false
	for i in range(dishes.size() - 1, -1, -1):
		var d: Control = dishes[i]
		if d.get_global_rect().has_point(event.position):
			dragging_dish = d
			drag_offset = event.position - d.global_position
			return true
	return false


func _continue_dish_drag(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		dragging_dish.global_position = event.position - drag_offset
	elif event is InputEventScreenTouch and not event.pressed:
		var d := dragging_dish
		dragging_dish = null
		var center := d.get_global_rect().get_center()
		# Guardado con MUCHO margen (arriba, abajo y a los lados de las cajas):
		# se comprueba primero, así soltar cerca de las cajas siempre guarda
		# aunque también toque la franja de la cinta que pasa por encima.
		if storage_box.get_global_rect().grow(90.0).has_point(center):
			var slot := _auto_store_index()
			if slot >= 0:
				_store_dish(d, slot)
			else:
				d.position = _dish_rest_position(dishes.find(d))
		elif center.y <= serve_slot.get_global_rect().end.y:
			# La cinta está en el borde superior de la tabla: soltar sobre su
			# tramo O en cualquier zona por encima (la cubierta) cuenta como
			# servir. El guardado ya se comprobó antes, así que aquí solo llega
			# lo que se suelta lejos de las cajas.
			_serve_dish(d)
		else:
			d.position = _dish_rest_position(dishes.find(d))


func _serve_dish(d: Control) -> void:
	dishes.erase(d)
	d.queue_free()
	dish_served.emit(ready_recipe)
	_after_dish_consumed()


func _after_dish_consumed() -> void:
	if dishes.is_empty():
		_apply_cooldown(ready_recipe)
		ready_recipe = ""
		state = State.IDLE
		_clear_ingredients()
		_set_stage("")
		craft_event.emit("serve", "")
		_update_ui()


# --- Cajas de guardado por pilas ---

## Caja elegida automáticamente al soltar en la zona de guardado: primero
## una pila del mismo plato con hueco (así nunca ocupan dos cajas), después
## la primera caja vacía. -1 si no hay sitio.
func _auto_store_index() -> int:
	for i in storage_panels.size():
		if stacks.has(i) and stacks[i].id == ready_recipe and stacks[i].count < stack_max:
			return i
	for i in storage_panels.size():
		if not stacks.has(i):
			return i
	return -1


func _store_dish(d: Control, panel_index: int) -> void:
	dishes.erase(d)
	d.queue_free()
	if stacks.has(panel_index):
		stacks[panel_index].count += 1
		stacks[panel_index].count_label.text = "x%d" % stacks[panel_index].count
	else:
		_create_stack(panel_index, ready_recipe)
	_emit_storage()
	_after_dish_consumed()


## Vuelca el estado de las cajas para quien lo quiera reflejar fuera.
func _emit_storage() -> void:
	var slots: Array = []
	for i in storage_panels.size():
		slots.append({ "id": stacks[i].id, "count": stacks[i].count } \
			if stacks.has(i) else null)
	storage_changed.emit(slots)


func _create_stack(panel_index: int, recipe_id: String) -> void:
	var p: Control = storage_panels[panel_index]
	var node := Control.new()
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := TextureRect.new()
	t.texture = RecipeData.get_dish_texture(recipe_id)
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.offset_left = 6.0
	t.offset_top = 6.0
	t.offset_right = -6.0
	t.offset_bottom = -6.0
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(t)
	var cl := Label.new()
	cl.text = "x1"
	cl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	cl.offset_left = -44.0
	cl.offset_top = -30.0
	cl.offset_right = -4.0
	cl.offset_bottom = -2.0
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cl.add_theme_font_size_override("font_size", 20)
	cl.add_theme_color_override("font_color", Color(1, 0.94, 0.6))
	cl.add_theme_color_override("font_outline_color", Color.BLACK)
	cl.add_theme_constant_override("outline_size", 6)
	node.add_child(cl)
	p.add_child(node)
	stacks[panel_index] = { "id": recipe_id, "count": 1, "node": node, "count_label": cl }


## Arrastrar DESDE una caja: saca un solo plato de la pila.
func _try_start_stack_drag(event: InputEventScreenTouch) -> bool:
	for i in stacks.keys():
		var p: Control = storage_panels[i]
		if p.get_global_rect().has_point(event.position):
			stack_drag_index = i
			stack_drag_start = event.position
			stack_drag_moved = false
			stack_ghost = _make_dish_node(stacks[i].id)
			add_child(stack_ghost)
			stack_ghost.global_position = event.position - DISH_SIZE / 2.0
			return true
	return false


func _continue_stack_drag(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		stack_ghost.global_position = event.position - DISH_SIZE / 2.0
		if event.position.distance_to(stack_drag_start) > 24.0:
			stack_drag_moved = true
	elif event is InputEventScreenTouch and not event.pressed:
		var i := stack_drag_index
		stack_drag_index = -1
		# Solo se sirve si hubo arrastre real Y el dedo terminó sobre la cinta
		# o por encima de ella (la cubierta).
		var served: bool = stack_drag_moved \
				and event.position.y <= serve_slot.get_global_rect().end.y
		stack_ghost.queue_free()
		stack_ghost = null
		if served:
			dish_served.emit(stacks[i].id)
			stacks[i].count -= 1
			if stacks[i].count <= 0:
				stacks[i].node.queue_free()
				stacks.erase(i)
			else:
				stacks[i].count_label.text = "x%d" % stacks[i].count
			_emit_storage()


# --- Interacción de elaboración ---

func _handle_craft_input(event: InputEvent) -> void:
	var step := _current_step()
	var step_type: String = step.get("type", "")
	match step_type:
		"tap_ingredient":
			if event is InputEventScreenTouch and event.pressed:
				var node: Control = ingredient_nodes.get(step.get("ingredient", ""))
				if node != null and node.get_global_rect().has_point(event.position):
					craft_event.emit("tap", _current_stage_id())
					_advance_step()
		"tap_board":
			if event is InputEventScreenTouch and event.pressed \
					and tap_zone.get_global_rect().has_point(event.position):
				taps_done += 1
				var cutting: bool = step.get("cutting", false)
				craft_event.emit("cut" if cutting else "tap", _current_stage_id())
				_bump_stage(6.0 if cutting else 0.0)
				if taps_done >= int(step.get("count", 1)):
					_advance_step()
				else:
					_update_ui()
		"hold_board":
			if event is InputEventScreenTouch:
				if event.pressed and tap_zone.get_global_rect().has_point(event.position):
					holding = true
					craft_event.emit("hold", _current_stage_id())
				elif not event.pressed:
					holding = false
					hold_time = 0.0
					_update_ui()
		"swipe_board":
			_handle_swipe(event, step)
		"drag_ingredient":
			_handle_ingredient_drag(event, step)
		"stir_board":
			_handle_stir(event, step)
		"slice_board":
			_handle_slice(event, step)
		"drag_stage":
			_handle_stage_drag(event)


func _handle_swipe(event: InputEvent, step: Dictionary) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and board_panel.get_global_rect().has_point(event.position):
			swipe_active = true
			swipe_counted = false
			swipe_start = event.position
		elif not event.pressed:
			swipe_active = false
	elif event is InputEventScreenDrag and swipe_active and not swipe_counted:
		var dy: float = event.position.y - swipe_start.y
		var direction: String = step.get("direction", "down")
		var done := false
		if direction == "down" and dy >= SWIPE_THRESHOLD:
			done = true
		elif direction == "up" and dy <= -SWIPE_THRESHOLD:
			done = true
		if done:
			swipe_counted = true
			swipes_done += 1
			craft_event.emit("swipe", _current_stage_id())
			_bump_stage(10.0 if direction == "down" else -10.0)
			if swipes_done >= int(step.get("count", 1)):
				_advance_step()
			else:
				_update_ui()


func _handle_ingredient_drag(event: InputEvent, step: Dictionary) -> void:
	var ing_id: String = step.get("ingredient", "")
	if event is InputEventScreenTouch:
		if event.pressed:
			var node: Control = ingredient_nodes.get(ing_id)
			if node != null and node.get_global_rect().has_point(event.position) and ghost == null:
				ghost = _make_ghost(ing_id)
				add_child(ghost)
				ghost.global_position = event.position - ghost.size / 2.0
		elif ghost != null:
			var dropped_on_board := tap_zone.get_global_rect().intersects(
					Rect2(ghost.global_position, ghost.size))
			ghost.queue_free()
			ghost = null
			if dropped_on_board:
				craft_event.emit("drag", _current_stage_id())
				_advance_step()
	elif event is InputEventScreenDrag and ghost != null:
		ghost.global_position = event.position - ghost.size / 2.0


## stir_board: remover en círculos manteniendo pulsado sobre la tabla.
## Se acumula el ángulo recorrido alrededor del centro de la etapa; cada
## vuelta completa (en cualquier sentido) cuenta una.
func _handle_stir(event: InputEvent, step: Dictionary) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and tap_zone.get_global_rect().has_point(event.position):
			stirring = true
			stir_angle = 0.0
			stir_last_angle = _angle_around_stage(event.position)
		elif not event.pressed:
			stirring = false
	elif event is InputEventScreenDrag and stirring:
		var ang := _angle_around_stage(event.position)
		stir_angle += wrapf(ang - stir_last_angle, -PI, PI)
		stir_last_angle = ang
		if absf(stir_angle) >= TAU:
			stir_angle = 0.0
			stir_turns += 1
			craft_event.emit("stir", _current_stage_id())
			_bump_stage(8.0)
			if stir_turns >= int(step.get("count", 1)):
				_advance_step()
				return
		_update_tap_bar()


func _angle_around_stage(pos: Vector2) -> float:
	return (pos - stage_rect.get_global_rect().get_center()).angle()


## slice_board: corte LENTO de izquierda a derecha que puede empezar en
## CUALQUIER punto de la tabla (no solo sobre el bloque). La barra se llena
## entera con cada corte y se vacía para el siguiente. El recorrido completo
## debe tardar AL MENOS "duration" s; si va más rápido aparece "¡Más lento!"
## y hay que repetir. Tras cada corte intermedio se muestra "cut_stage"
## (p. ej. el bloque con una lámina ya cortada).
func _handle_slice(event: InputEvent, step: Dictionary) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and board_panel.get_global_rect().has_point(event.position):
			slice_active = true
			slice_start = event.position
			slice_start_ms = Time.get_ticks_msec()
			slice_progress = 0.0
		elif not event.pressed:
			slice_active = false
			slice_progress = 0.0
			_update_tap_bar()
	elif event is InputEventScreenDrag and slice_active:
		# Retroceso a la izquierda: el corte se reinicia desde aquí.
		if event.position.x < slice_start.x:
			slice_start = event.position
			slice_start_ms = Time.get_ticks_msec()
			slice_progress = 0.0
			_update_tap_bar()
			return
		slice_progress = event.position.x - slice_start.x
		if slice_progress < SLICE_SWEEP:
			_update_tap_bar()
			return
		# Recorrido completo: se evalúa la velocidad.
		slice_active = false
		slice_progress = 0.0
		var elapsed := (Time.get_ticks_msec() - slice_start_ms) / 1000.0
		if elapsed < float(step.get("duration", 0.7)):
			_flash_message("¡Más lento!")
			_slice_fail_feedback()
			_update_tap_bar()
			return
		slices_done += 1
		craft_event.emit("slice", _current_stage_id())
		if slices_done >= int(step.get("count", 1)):
			_advance_step()
		else:
			# Corte intermedio: se ve la lámina ya cortada junto al bloque.
			var cut_stage: String = step.get("cut_stage", "")
			if cut_stage != "":
				_set_stage(cut_stage)
			else:
				_bump_stage(-6.0)
			_update_ui()


## Muestra un mensaje grande sobre el centro de la tabla que se desvanece.
func _flash_message(text: String) -> void:
	message_label.text = text
	message_label.reset_size()
	var center := board_panel.position + board_panel.size / 2.0
	message_label.position = center - message_label.size / 2.0 - Vector2(0, 20)
	message_label.modulate = Color(1, 1, 1, 1)
	message_label.scale = Vector2(0.7, 0.7)
	message_label.pivot_offset = message_label.size / 2.0
	message_label.visible = true
	if message_tween != null:
		message_tween.kill()
	message_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	message_tween.tween_property(message_label, "scale", Vector2.ONE, 0.18)
	message_tween.tween_interval(0.5)
	message_tween.tween_property(message_label, "modulate:a", 0.0, 0.3)
	message_tween.tween_callback(func() -> void: message_label.visible = false)


## Corte demasiado rápido: sacudida y destello rojo de la etapa.
func _slice_fail_feedback() -> void:
	if not stage_rect.visible:
		return
	stage_rect.pivot_offset = stage_rect.size / 2.0
	if stage_tween != null:
		stage_tween.kill()
	stage_rect.modulate = Color(1.0, 0.45, 0.45)
	stage_rect.rotation_degrees = -4.0
	stage_tween = create_tween()
	stage_tween.tween_property(stage_rect, "rotation_degrees", 4.0, 0.06)
	stage_tween.tween_property(stage_rect, "rotation_degrees", 0.0, 0.08)
	stage_tween.tween_property(stage_rect, "modulate", Color.WHITE, 0.25)


## drag_stage: arrastrar el sprite de etapa (cuenco, gamba...) hasta el prop.
## Exige arrastre REAL (>24 px) y soltar el dedo sobre el prop: un simple
## toque sobre la etapa no debe completar el paso.
func _handle_stage_drag(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and stage_rect.visible and stage_ghost == null \
				and stage_rect.get_global_rect().has_point(event.position):
			stage_ghost = TextureRect.new()
			stage_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			stage_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			stage_ghost.texture = stage_rect.texture
			stage_ghost.size = stage_rect.size
			stage_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(stage_ghost)
			stage_ghost.global_position = event.position - stage_ghost.size / 2.0
			stage_rect.visible = false
			stage_drag_start = event.position
			stage_drag_moved = false
		elif not event.pressed and stage_ghost != null:
			var hit: bool = stage_drag_moved and prop_rect.visible \
					and prop_rect.get_global_rect().grow(20.0).has_point(event.position)
			stage_ghost.queue_free()
			stage_ghost = null
			if hit:
				craft_event.emit("drag", _current_stage_id())
				_advance_step()
			else:
				stage_rect.visible = true
	elif event is InputEventScreenDrag and stage_ghost != null:
		stage_ghost.global_position = event.position - stage_ghost.size / 2.0
		if event.position.distance_to(stage_drag_start) > 24.0:
			stage_drag_moved = true


## Muestra u oculta el utensilio del paso actual (clave "prop"). Entra
## animado desde abajo hasta su sitio en la esquina derecha de la tabla.
func _update_prop() -> void:
	var prop_id: String = _current_step().get("prop", "") if state == State.CRAFTING else ""
	var tex := RecipeData.get_stage_texture(prop_id)
	if tex == null:
		if prop_tween != null:
			prop_tween.kill()
			prop_tween = null
		prop_rect.visible = false
		return
	prop_rect.texture = tex
	var target := board_panel.position + board_panel.size - prop_rect.size - Vector2(8, 10)
	prop_target = target
	prop_rect.position = target + Vector2(0, 240)
	prop_rect.modulate.a = 0.0
	prop_rect.visible = true
	if prop_tween != null:
		prop_tween.kill()
	prop_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	prop_tween.tween_property(prop_rect, "position", target, 0.45)
	prop_tween.parallel().tween_property(prop_rect, "modulate:a", 1.0, 0.3)


## Copia del ingrediente que sigue al dedo mientras se arrastra.
func _make_ghost(ing_id: String) -> Control:
	var g := Control.new()
	g.size = ING_SIZE
	var tex := _ingredient_texture(ing_id)
	if tex != null:
		var t := TextureRect.new()
		t.texture = tex
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.add_child(t)
	return g


func _make_dish_node(recipe_id: String) -> Control:
	var d := Control.new()
	d.size = DISH_SIZE
	var t := TextureRect.new()
	t.texture = RecipeData.get_dish_texture(recipe_id)
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.add_child(t)
	return d


func _finish_prep(grant_mastery: bool) -> void:
	state = State.READY
	ready_recipe = current_recipe
	current_recipe = ""
	if grant_mastery:
		var uses: int = RecipeData.get_recipe(ready_recipe).get("free_uses", 0)
		if uses > 0:
			free_uses[ready_recipe] = uses
	_set_stage("")
	_update_prop()
	var count := 2 if double_next else 1
	double_next = false
	for i in count:
		var d := _make_dish_node(ready_recipe)
		add_child(d)
		d.position = _dish_rest_position(i)
		d.pivot_offset = DISH_SIZE / 2.0
		d.scale = Vector2(0.5, 0.5)
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(d, "scale", Vector2.ONE, 0.3)
		dishes.append(d)
	craft_event.emit("done", "")
	_update_ui()


func _dish_rest_position(index: int = 0) -> Vector2:
	var base := board_panel.position + (board_panel.size - DISH_SIZE) / 2.0
	if dishes.size() > 1 or index > 0:
		base.x += -80.0 + 160.0 * index
	return base


func _apply_cooldown(recipe_id: String) -> void:
	var cd: float = RecipeData.get_recipe(recipe_id).cooldown * cooldown_mult \
			* cooldown_perm_mult
	if skip_next_cooldown:
		skip_next_cooldown = false
		cd = 0.0
	cooldowns[recipe_id] = cd


func _update_ui() -> void:
	cancel_button.visible = _can_cancel()
	_update_instruction()
	match state:
		State.IDLE:
			tap_bar.visible = false
			_hide_indicator()
		State.CRAFTING:
			_update_tap_bar()
			call_deferred("_refresh_indicator")
		State.READY:
			tap_bar.visible = false
			call_deferred("_refresh_indicator_ready")


# --- Instrucción escrita del paso actual ---

## Nombre legible de un ingrediente para los textos de ayuda.
func _ingredient_name(ing_id: String) -> String:
	var d: Dictionary = RecipeData.INGREDIENTS.get(ing_id, {})
	return str(d.get("name", ing_id))


## Qué tiene que hacer el jugador AHORA MISMO, con las repeticiones que le
## quedan ("¡Pulsa x4!" va bajando a x3, x2...).
func _instruction_text() -> String:
	if state == State.READY:
		return "¡Arrastra el plato a la cinta!"
	if state != State.CRAFTING:
		return ""
	var step := _current_step()
	var total := int(step.get("count", 1))
	var left := 1
	match step.get("type", ""):
		"tap_ingredient":
			return "¡Toca %s!" % _ingredient_name(step.get("ingredient", ""))
		"drag_ingredient":
			return "¡Arrastra %s a la tabla!" % _ingredient_name(step.get("ingredient", ""))
		"tap_board":
			left = maxi(total - taps_done, 1)
			var verb := "Corta" if bool(step.get("cutting", false)) else "Pulsa"
			if total <= 1:
				return "¡%s la tabla!" % verb
			return "¡%s x%d!" % [verb, left]
		"hold_board":
			return "¡Mantén pulsado!"
		"swipe_board":
			left = maxi(total - swipes_done, 1)
			var dir := "abajo" if step.get("direction", "down") == "down" else "arriba"
			if total <= 1:
				return "¡Desliza hacia %s!" % dir
			return "¡Desliza hacia %s x%d!" % [dir, left]
		"stir_board":
			left = maxi(total - stir_turns, 1)
			if total <= 1:
				return "¡Remueve en círculos!"
			return "¡Remueve en círculos x%d!" % left
		"slice_board":
			left = maxi(total - slices_done, 1)
			if total <= 1:
				return "¡Corta despacio!"
			return "¡Corta despacio x%d!" % left
		"drag_stage":
			return "¡Arrástralo hasta el utensilio!"
	return ""


func _update_instruction() -> void:
	var txt := _instruction_text()
	if txt == "":
		instruction_label.visible = false
		return
	if instruction_label.text != txt:
		instruction_label.text = txt
		_pop_instruction()
	instruction_label.visible = true


## Rebote al cambiar el texto (que se note que queda una repetición menos).
func _pop_instruction() -> void:
	instruction_label.pivot_offset = instruction_label.size / 2.0
	if instruction_tween != null:
		instruction_tween.kill()
	instruction_label.scale = Vector2(1.16, 1.16)
	instruction_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	instruction_tween.tween_property(instruction_label, "scale", Vector2.ONE, 0.22)


# --- Mano de gestos: indicador animado del paso actual ---

## Mano y flecha grandes: son la guía del jugador y tienen que leerse de un
## vistazo en el móvil.
const HAND_SIZE := Vector2(116, 150)
const HAND_ALPHA := 0.85
const ARROW_SIZE := Vector2(68, 90)
## Anillo que late en el punto exacto donde hay que tocar: la mano sola se
## perdía sobre las etapas claras (el arroz es casi del mismo color).
const RING_SIZE := Vector2(128, 128)
## Punto de anclaje de la mano respecto a su esquina: la mano queda POR
## ENCIMA del objetivo, con la base a la altura del objeto, para que nunca
## lo tape ni cuelgue por debajo.
const HAND_TIP := Vector2(58, 164)

func _hide_indicator() -> void:
	if indicator_tween != null:
		indicator_tween.kill()
		indicator_tween = null
	if ring_tween != null:
		ring_tween.kill()
		ring_tween = null
	if hand != null:
		hand.visible = false
	if ghost_hint != null:
		ghost_hint.visible = false
	if arrow_hint != null:
		arrow_hint.visible = false
	if touch_ring != null:
		touch_ring.visible = false


## Late un anillo en el punto de contacto (pulsar y mantener).
func _ring_pulse(center: Vector2, period: float) -> void:
	touch_ring.position = center - RING_SIZE / 2.0
	touch_ring.visible = true
	ring_tween = create_tween().set_loops()
	ring_tween.tween_callback(func() -> void:
		touch_ring.scale = Vector2(0.45, 0.45)
		touch_ring.modulate.a = 0.95)
	ring_tween.tween_property(touch_ring, "scale", Vector2(1.1, 1.1), period) \
			.set_trans(Tween.TRANS_SINE)
	ring_tween.parallel().tween_property(touch_ring, "modulate:a", 0.0, period)


func _local_center(node: Control) -> Vector2:
	var r := node.get_global_rect()
	return r.position + r.size / 2.0 - global_position


## Prepara la mano para una nueva animación en el punto de contacto dado.
func _hand_begin(tip_pos: Vector2, down: bool = false) -> void:
	hand.texture = hand_down_tex if down else hand_up_tex
	hand.size = HAND_SIZE
	hand.scale = Vector2.ONE
	hand.position = tip_pos - HAND_TIP
	hand.modulate.a = HAND_ALPHA
	hand.visible = true


func _hand_at(tip_pos: Vector2) -> Vector2:
	return tip_pos - HAND_TIP


func _refresh_indicator() -> void:
	if state != State.CRAFTING:
		return
	_hide_indicator()
	var step := _current_step()
	var board_center := board_panel.position + board_panel.size / 2.0
	var stage_center := board_center
	if stage_rect.visible:
		stage_center = board_panel.position + stage_rect.position + stage_rect.size / 2.0
	match step.get("type", ""):
		"tap_ingredient":
			var node: Control = ingredient_nodes.get(step.get("ingredient", ""))
			if node == null:
				return
			_hand_tap_at(_local_center(node), false)
		"tap_board":
			_hand_tap_at(stage_center, true)
		"hold_board":
			_hand_hold_at(stage_center)
		"swipe_board":
			var dir := Vector2(0, 1) if step.get("direction", "down") == "down" else Vector2(0, -1)
			# Algo por debajo de la etapa: con la mano grande, arrancar en el
			# centro exacto la sacaba por encima de la tabla.
			_hand_swipe(stage_center + Vector2(0, 46), dir)
		"drag_ingredient":
			var node: Control = ingredient_nodes.get(step.get("ingredient", ""))
			if node == null:
				return
			ghost_hint.texture = _ingredient_texture(step.get("ingredient", ""))
			ghost_hint.size = ING_SIZE
			_hand_drag(_local_center(node), stage_center)
		"stir_board":
			_hand_circle_at(stage_center)
		"slice_board":
			# Corte lento de izquierda a derecha: deslizar pausado y ancho.
			_hand_swipe(board_center, Vector2(1, 0), 1.2, 175.0)
		"drag_stage":
			if not prop_rect.visible:
				return
			ghost_hint.texture = stage_rect.texture
			ghost_hint.size = stage_rect.size
			_hand_drag(stage_center, prop_target + prop_rect.size / 2.0)


## Plato listo: la mano arrastra un fantasma del plato hasta la cinta.
func _refresh_indicator_ready() -> void:
	if state != State.READY or dishes.is_empty():
		return
	_hide_indicator()
	ghost_hint.texture = RecipeData.get_dish_texture(ready_recipe)
	ghost_hint.size = DISH_SIZE
	var a: Vector2 = dishes[0].position + DISH_SIZE / 2.0
	var b: Vector2 = serve_slot.position + serve_slot.size / 2.0
	_hand_drag(a, b)


## Pulsación: la mano baja el dedo sobre el punto (rápida si es repetida).
func _hand_tap_at(tip_pos: Vector2, fast: bool) -> void:
	_hand_begin(tip_pos)
	_ring_pulse(tip_pos, 0.52 if fast else 0.8)
	var up_t := 0.16 if fast else 0.38
	var down_t := 0.10 if fast else 0.16
	indicator_tween = create_tween().set_loops()
	indicator_tween.tween_callback(func() -> void: hand.texture = hand_up_tex)
	indicator_tween.tween_interval(up_t)
	indicator_tween.tween_callback(func() -> void: hand.texture = hand_down_tex)
	indicator_tween.tween_property(hand, "position:y", _hand_at(tip_pos).y + 6.0, down_t)
	indicator_tween.tween_property(hand, "position:y", _hand_at(tip_pos).y, down_t)


## Mantener pulsado: dedo abajo con un latido suave.
func _hand_hold_at(tip_pos: Vector2) -> void:
	_hand_begin(tip_pos, true)
	_ring_pulse(tip_pos, 0.95)
	hand.pivot_offset = HAND_TIP
	indicator_tween = create_tween().set_loops()
	indicator_tween.tween_property(hand, "scale", Vector2(1.12, 1.12), 0.45)
	indicator_tween.tween_property(hand, "scale", Vector2.ONE, 0.45)


## Arrastre: pulsa sobre el objeto, lo lleva hasta el destino (con su
## fantasma), lo suelta y repite.
func _hand_drag(from_pos: Vector2, to_pos: Vector2) -> void:
	_hand_begin(from_pos)
	ghost_hint.visible = true
	ghost_hint.position = from_pos - ghost_hint.size / 2.0
	ghost_hint.modulate.a = 0.0
	indicator_tween = create_tween().set_loops()
	indicator_tween.tween_callback(func() -> void:
		hand.texture = hand_up_tex
		hand.position = _hand_at(from_pos)
		hand.modulate.a = HAND_ALPHA
		ghost_hint.position = from_pos - ghost_hint.size / 2.0
		ghost_hint.modulate.a = 0.0)
	indicator_tween.tween_property(ghost_hint, "modulate:a", 0.7, 0.15)
	indicator_tween.tween_callback(func() -> void: hand.texture = hand_down_tex)
	indicator_tween.tween_interval(0.12)
	indicator_tween.tween_property(hand, "position", _hand_at(to_pos), 0.9) \
			.set_trans(Tween.TRANS_SINE)
	indicator_tween.parallel().tween_property(ghost_hint, "position",
			to_pos - ghost_hint.size / 2.0, 0.9).set_trans(Tween.TRANS_SINE)
	indicator_tween.tween_callback(func() -> void: hand.texture = hand_up_tex)
	indicator_tween.tween_interval(0.25)
	indicator_tween.tween_property(hand, "modulate:a", 0.0, 0.2)
	indicator_tween.parallel().tween_property(ghost_hint, "modulate:a", 0.0, 0.2)


## Deslizamiento: dedo abajo y movimiento en la dirección dada (rápido por
## defecto; travel_time/span mayores para los cortes lentos).
func _hand_swipe(center: Vector2, dir: Vector2, travel_time := 0.4, span := 88.0) -> void:
	var a := center - dir * span
	var b := center + dir * span
	_hand_begin(a, true)
	# La flecha propia apunta en la dirección del gesto y viaja con la mano.
	arrow_hint.rotation = dir.angle() + PI / 2.0
	arrow_hint.visible = true
	var arrow_off := Vector2(72, -10)
	indicator_tween = create_tween().set_loops()
	indicator_tween.tween_callback(func() -> void:
		hand.texture = hand_down_tex
		hand.position = _hand_at(a)
		hand.modulate.a = HAND_ALPHA
		arrow_hint.position = _hand_at(a) + arrow_off
		arrow_hint.modulate.a = 0.9)
	indicator_tween.tween_interval(0.15)
	indicator_tween.tween_property(hand, "position", _hand_at(b), travel_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	indicator_tween.parallel().tween_property(arrow_hint, "position", _hand_at(b) + arrow_off, travel_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	indicator_tween.tween_property(hand, "modulate:a", 0.0, 0.15)
	indicator_tween.parallel().tween_property(arrow_hint, "modulate:a", 0.0, 0.15)
	indicator_tween.tween_interval(0.25)


## Círculo: el dedo recorre una circunferencia (para gestos rotatorios).
func _hand_circle_at(center: Vector2, radius: float = 74.0) -> void:
	_hand_begin(center + Vector2(radius, 0), true)
	indicator_tween = create_tween().set_loops()
	indicator_tween.tween_method(func(ang: float) -> void:
		hand.position = _hand_at(center + Vector2(cos(ang), sin(ang)) * radius),
		0.0, TAU, 1.4)


func _update_tap_bar() -> void:
	_update_instruction()
	var step := _current_step()
	match step.get("type", ""):
		"tap_board":
			tap_bar.visible = true
			tap_bar.max_value = int(step.get("count", 1))
			tap_bar.value = taps_done
		"swipe_board":
			tap_bar.visible = true
			tap_bar.max_value = int(step.get("count", 1))
			tap_bar.value = swipes_done
		"hold_board":
			tap_bar.visible = true
			tap_bar.max_value = step.get("duration", 1.0)
			tap_bar.value = hold_time
		"stir_board":
			tap_bar.visible = true
			tap_bar.max_value = int(step.get("count", 1))
			# Progreso continuo: vueltas completas más la fracción en curso.
			tap_bar.value = stir_turns + absf(stir_angle) / TAU
		"slice_board":
			# La barra representa SOLO el corte en curso: se llena entera con
			# cada corte y vuelve a vaciarse para el siguiente.
			tap_bar.visible = true
			tap_bar.max_value = 1.0
			tap_bar.value = clampf(slice_progress / SLICE_SWEEP, 0.0, 1.0)
		_:
			tap_bar.visible = false
