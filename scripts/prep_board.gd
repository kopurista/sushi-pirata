extends Control
## Tabla de preparación gráfica: cada receta avanza por etapas visuales
## (bola de arroz → lámina → relleno → rollo → plato) sin textos.
## Los ingredientes desaparecen de la tabla cuando ya no se van a usar.
## El guardado funciona por pilas: cada caja apila hasta stack_max platos
## IGUALES (x2, x3...). Emite craft_event para que el chef reaccione.

signal dish_served(recipe_id: String)
signal craft_event(kind: String, stage_id: String)

enum State { IDLE, CRAFTING, READY }

const SWIPE_THRESHOLD := 70.0
const DISH_SIZE := Vector2(120, 110)

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

var stage_tween: Tween = null
## Mano de gestos: muestra semitransparente cómo ejecutar cada interacción
## (pulsar, mantener, arrastrar, deslizar, círculo) con dos poses.
var hand: TextureRect = null
var hand_up_tex: Texture2D = null
var hand_down_tex: Texture2D = null
## Fantasma semitransparente del objeto que se arrastra en el ejemplo.
var ghost_hint: TextureRect = null
## Flecha que acompaña a la mano en los gestos de deslizamiento.
var arrow_hint: TextureRect = null
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


## Aspecto pirata para un botón: fondo de madera y tipografía clara.
static func skin_button(b: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, empty)
	b.add_theme_color_override("font_color", Color(1, 0.94, 0.82))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 0.92))
	b.add_theme_color_override("font_pressed_color", Color(0.9, 0.84, 0.72))
	b.add_theme_color_override("font_disabled_color", Color(0.68, 0.63, 0.56))
	b.add_theme_color_override("font_outline_color", Color.BLACK)
	b.add_theme_constant_override("outline_size", 5)
	if b.has_node("Skin"):
		return
	b.add_child(make_nine_patch("res://assets/ui/boton.png", 30))


## Fila de estrellas con las imágenes propias del juego (llenas y vacías).
static func make_star_row(count: int, total: int, star_size: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in total:
		var ic := TextureRect.new()
		ic.texture = load("res://assets/ui/estrella_llena.png" if i < count
				else "res://assets/ui/estrella_vacia.png")
		ic.custom_minimum_size = Vector2(star_size, star_size)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
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
	# Sin textos ni contadores: todo se comunica con indicadores visuales.
	instruction_label.visible = false
	# Mano de gestos: pequeña y semitransparente para no tapar la interfaz.
	hand_up_tex = load("res://assets/ui/mano_arriba.png")
	hand_down_tex = load("res://assets/ui/mano_abajo.png")
	hand = TextureRect.new()
	# expand_mode ANTES que texture: si no, el tamaño mínimo salta al de la
	# textura (421x546) y la mano sale gigante.
	hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hand.texture = hand_up_tex
	hand.size = Vector2(56, 72)
	hand.modulate = Color(1, 1, 1, 0.65)
	hand.visible = false
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hand)
	# Flecha de dirección para los gestos de deslizamiento.
	arrow_hint = TextureRect.new()
	arrow_hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow_hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow_hint.texture = load("res://assets/ui/flecha.png")
	arrow_hint.size = Vector2(44, 58)
	arrow_hint.pivot_offset = Vector2(22, 29)
	arrow_hint.modulate = Color(1, 1, 1, 0.7)
	arrow_hint.visible = false
	arrow_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(arrow_hint)
	# Fantasma semitransparente de ejemplo para los gestos de arrastre.
	ghost_hint = TextureRect.new()
	ghost_hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost_hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost_hint.modulate = Color(1, 1, 1, 0.55)
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
	b.custom_minimum_size = Vector2(170, 154)
	skin_button(b)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 0)

	var tex := RecipeData.get_dish_texture(id)
	if tex != null:
		var ic := TextureRect.new()
		ic.texture = tex
		ic.custom_minimum_size = Vector2(0, 108)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(ic)
	b.add_child(vb)

	# Estrellas ancladas cerca del borde inferior, pero subidas para que no
	# queden pegadas al marco y se vean bien.
	var stars := make_star_row(int(data.get("level", 1)), int(data.get("level", 1)), 28)
	stars.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	stars.offset_top = -42.0
	stars.offset_bottom = -12.0
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
	p.custom_minimum_size = Vector2(100, 100)
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
	craft_event.emit("select", "")
	_update_ui()


## Cancelable solo mientras no se haya completado el primer paso.
func _can_cancel() -> bool:
	return state == State.CRAFTING and step_index == 0


func _cancel_prep() -> void:
	if not _can_cancel():
		return
	state = State.IDLE
	current_recipe = ""
	steps = []
	_reset_step_progress()
	_set_stage("")
	_clear_ingredients()
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
		holder.custom_minimum_size = Vector2(76, 66)
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
		elif serve_slot.get_global_rect().has_point(center):
			# La cinta solo si se suelta sobre su tramo (lejos de las cajas).
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
	_after_dish_consumed()


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
		# Solo se sirve si hubo arrastre real Y el dedo terminó en la cinta.
		var served: bool = stack_drag_moved 				and serve_slot.get_global_rect().has_point(event.position)
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


## Copia del ingrediente que sigue al dedo mientras se arrastra.
func _make_ghost(ing_id: String) -> Control:
	var g := Control.new()
	g.size = Vector2(76, 66)
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
		base.x += -70.0 + 140.0 * index
	return base


func _apply_cooldown(recipe_id: String) -> void:
	var cd: float = RecipeData.get_recipe(recipe_id).cooldown * cooldown_mult
	if skip_next_cooldown:
		skip_next_cooldown = false
		cd = 0.0
	cooldowns[recipe_id] = cd


func _update_ui() -> void:
	cancel_button.visible = _can_cancel()
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


# --- Mano de gestos: indicador animado del paso actual ---

## Punto de anclaje de la mano respecto a su esquina: la mano queda POR
## ENCIMA del objetivo, con la base a la altura del objeto, para que nunca
## lo tape ni cuelgue por debajo.
const HAND_TIP := Vector2(28, 80)

func _hide_indicator() -> void:
	if indicator_tween != null:
		indicator_tween.kill()
		indicator_tween = null
	if hand != null:
		hand.visible = false
	if ghost_hint != null:
		ghost_hint.visible = false
	if arrow_hint != null:
		arrow_hint.visible = false


func _local_center(node: Control) -> Vector2:
	var r := node.get_global_rect()
	return r.position + r.size / 2.0 - global_position


## Prepara la mano para una nueva animación en el punto de contacto dado.
func _hand_begin(tip_pos: Vector2, down: bool = false) -> void:
	hand.texture = hand_down_tex if down else hand_up_tex
	hand.size = Vector2(56, 72)
	hand.scale = Vector2.ONE
	hand.position = tip_pos - HAND_TIP
	hand.modulate.a = 0.65
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
			_hand_swipe(stage_center, dir)
		"drag_ingredient":
			var node: Control = ingredient_nodes.get(step.get("ingredient", ""))
			if node == null:
				return
			ghost_hint.texture = _ingredient_texture(step.get("ingredient", ""))
			ghost_hint.size = Vector2(76, 66)
			_hand_drag(_local_center(node), stage_center)


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
		hand.modulate.a = 0.65
		ghost_hint.position = from_pos - ghost_hint.size / 2.0
		ghost_hint.modulate.a = 0.0)
	indicator_tween.tween_property(ghost_hint, "modulate:a", 0.5, 0.15)
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


## Deslizamiento: dedo abajo y movimiento rápido en la dirección dada.
func _hand_swipe(center: Vector2, dir: Vector2) -> void:
	var a := center - dir * 70.0
	var b := center + dir * 70.0
	_hand_begin(a, true)
	# La flecha propia apunta en la dirección del gesto y viaja con la mano.
	arrow_hint.rotation = dir.angle() + PI / 2.0
	arrow_hint.visible = true
	var arrow_off := Vector2(48, -6)
	indicator_tween = create_tween().set_loops()
	indicator_tween.tween_callback(func() -> void:
		hand.texture = hand_down_tex
		hand.position = _hand_at(a)
		hand.modulate.a = 0.65
		arrow_hint.position = _hand_at(a) + arrow_off
		arrow_hint.modulate.a = 0.7)
	indicator_tween.tween_interval(0.15)
	indicator_tween.tween_property(hand, "position", _hand_at(b), 0.4) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	indicator_tween.parallel().tween_property(arrow_hint, "position", _hand_at(b) + arrow_off, 0.4) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	indicator_tween.tween_property(hand, "modulate:a", 0.0, 0.15)
	indicator_tween.parallel().tween_property(arrow_hint, "modulate:a", 0.0, 0.15)
	indicator_tween.tween_interval(0.25)


## Círculo: el dedo recorre una circunferencia (para gestos rotatorios).
func _hand_circle_at(center: Vector2, radius: float = 55.0) -> void:
	_hand_begin(center + Vector2(radius, 0), true)
	indicator_tween = create_tween().set_loops()
	indicator_tween.tween_method(func(ang: float) -> void:
		hand.position = _hand_at(center + Vector2(cos(ang), sin(ang)) * radius),
		0.0, TAU, 1.4)


func _update_tap_bar() -> void:
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
		_:
			tap_bar.visible = false
