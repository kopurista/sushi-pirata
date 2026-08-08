extends Node2D
## Cliente pirata: entra andando desde la zona superior del barco, se sienta,
## coge platos de la cinta (con animación), come y se marcha andando.
## Se queda hasta que su barra de PACIENCIA se agota (no hay saciedad objetivo):
## cada plato comido recarga paciencia según su nivel, así que darle de comer
## es lo que alarga su estancia — pero repetirle el mismo plato rinde cada vez
## menos. La propina depende del Nº DE PLATOS comidos (ver TIP_RULES).

signal finished(report: Dictionary)
## Se emite al terminar CADA plato: el precio del plato y la propina de ese
## plato (0 si no la deja). El nivel suma ambos al instante, no al marcharse.
signal plate_served(food: int, tip: int)

enum State { ARRIVING, WAITING, EATING, LEAVING, DONE }

const WALK_SPEED := 190.0

## Probabilidad de coger un plato según tipo de cliente y nivel del plato.
## Los piratas pican bastante con nivel 1 y los capitanes con nivel 2.
const TAKE_CHANCES: Dictionary = {
	"E": { 1: 0.95, 2: 0.15, 3: 0.10 },
	"A": { 1: 0.45, 2: 0.92, 3: 0.25 },
	"G": { 1: 0.0, 2: 0.70, 3: 0.95 },
}

const FAVORITE_TIER: Dictionary = { "E": 1, "A": 2, "G": 3 }

## Rango de tiempo de comida (s) por tipo de cliente Y nivel del plato:
##  - Grumete: rápido con nivel 1, lento con los superiores.
##  - Pirata: menos con nivel 1 que con nivel 2; nivel 3 más que nivel 2.
##  - Capitán: muy poco con nivel 1, algo más con nivel 2, normal con nivel 3.
const EAT_TIMES: Dictionary = {
	"E": { 1: 7.0, 2: 12.0, 3: 18.0 },
	"A": { 1: 6.0, 2: 10.0, 3: 15.0 },
	"G": { 1: 5.0, 2: 8.0, 3: 12.0 },
}
const EAT_JITTER := 0.05

const TYPE_SPRITES: Dictionary = {
	"E": "res://assets/characters/grumete.webp",
	"A": "res://assets/characters/pirata.webp",
	"G": "res://assets/characters/capitan.webp",
}

const TYPE_SCALES: Dictionary = { "E": 0.095, "A": 0.115, "G": 0.13 }

## Al recibir un plato la paciencia sube (fracción del máximo) según el nivel
## del plato: los de nivel alto alargan mucho más la estancia del cliente.
const PATIENCE_FOOD: Dictionary = { 1: 0.09, 2: 0.22, 3: 0.32 }
## Si el MISMO plato se repite seguido, cada repetición recarga MENOS de la
## mitad que la anterior (el cliente se aburre del plato). Cambiar de plato NO
## reinicia del todo: retrocede UN nivel de aburrimiento (`boredom`).
const REPEAT_DECAY := 0.4
## Cada plato comido acelera el drenaje de paciencia en este factor (x0.025).
const PATIENCE_DRAIN_PER_PLATE := 0.025

## Propina, según el nº de platos comidos por el cliente:
##  - desde "start" platos ya puede haber propina, con "base" de probabilidad;
##  - hasta "ramp" platos la probabilidad se mantiene en "base";
##  - a partir de "ramp" sube "step" por cada "every" platos, con tope "max".
##  - "pct": cuantía de la propina = ese % del precio del plato.
const TIP_RULES: Dictionary = {
	"E": { "start": 1, "ramp": 3, "every": 1, "base": 0.20, "step": 0.01, "max": 0.65, "pct": 0.15 },
	"A": { "start": 1, "ramp": 3, "every": 1, "base": 0.23, "step": 0.015, "max": 0.60, "pct": 0.16 },
	"G": { "start": 1, "ramp": 3, "every": 1, "base": 0.25, "step": 0.02, "max": 0.50, "pct": 0.18 },
}

var client_type: String = "E"
var patience_scale: float = 1.0
var pay_mult: float = 1.0
var guaranteed_next: bool = false
var face_flip: bool = false
## Puntos de la ruta de entrada (el nivel los define; el último es el asiento).
var route: Array = []

var state: State = State.ARRIVING
var patience_max: float = 55.0
var patience: float = 55.0
var satiety_eaten: int = 0
## Último plato comido y nivel de "aburrimiento" (0 = plato fresco, recarga
## plena): sube +1 al repetir el mismo plato y baja -1 al cambiar de plato.
var last_dish_id: String = ""
var boredom: int = 0
var money_earned: int = 0
var eat_timer: float = 0.0
var eat_duration: float = 1.0
## Propina acumulada (suma de las propinas de cada plato), para el desglose final.
var tips_earned: int = 0
var current_price: int = 0
var current_satiety: int = 0
var current_id: String = ""
## Ids de receta de los platos comidos (para el desglose con iconos).
var eaten_ids: Array[String] = []
var declined: Array[int] = []
var level_ref: Node = null

var walk_tween: Tween = null
var bob_tween: Tween = null
var eat_anim_tween: Tween = null
var held_dish: Sprite2D = null
## Punto de la cinta (global) asignado por el nivel; la zona de detección se
## coloca al SENTARSE, no antes (el cliente aún está caminando desde la entrada).
var belt_point_global := Vector2.ZERO

@onready var body: Sprite2D = $Body
@onready var patience_bar: ProgressBar = $PatienceBar
@onready var eat_bar: ProgressBar = $EatBar
@onready var zone: Area2D = $Zone


func _ready() -> void:
	add_to_group("clients")
	level_ref = get_parent()
	# Paciencia base ajustada a partidas de 2:30 (antes 4 min): estancias más
	# cortas para que la rotación de clientes siga teniendo ritmo.
	patience_max = randf_range(30.0, 40.0) * patience_scale
	patience = patience_max
	var tex_path: String = TYPE_SPRITES.get(client_type, "")
	if tex_path != "" and ResourceLoader.exists(tex_path):
		body.texture = load(tex_path)
	var s: float = TYPE_SCALES.get(client_type, 0.11)
	body.scale = Vector2(s, s)
	body.flip_h = face_flip
	eat_bar.visible = false
	patience_bar.visible = false
	patience_bar.max_value = patience_max
	patience_bar.value = patience
	zone.monitoring = false
	zone.area_entered.connect(_on_zone_area_entered)
	_walk_route()


## Recorre la ruta de entrada andando; al llegar al asiento empieza a esperar.
func _walk_route() -> void:
	if route.is_empty():
		_seat()
		return
	_start_bob()
	walk_tween = create_tween()
	var from: Vector2 = position
	for point in route:
		var dist: float = from.distance_to(point)
		walk_tween.tween_property(self, "position", point, dist / WALK_SPEED)
		from = point
	walk_tween.finished.connect(_seat)


## Balanceo mientras camina.
func _start_bob() -> void:
	bob_tween = create_tween().set_loops()
	bob_tween.tween_property(body, "rotation_degrees", 4.0, 0.18)
	bob_tween.tween_property(body, "rotation_degrees", -4.0, 0.18)


func _stop_bob() -> void:
	if bob_tween != null:
		bob_tween.kill()
		bob_tween = null
	body.rotation_degrees = 0.0


func _seat() -> void:
	if state != State.ARRIVING:
		return
	state = State.WAITING
	_stop_bob()
	# Ahora sí: la posición es la del asiento, la zona apunta a la cinta.
	zone.position = belt_point_global - position
	zone.monitoring = true
	patience_bar.visible = true


## Guarda el punto de la cinta; la zona se coloca al llegar al asiento.
func set_belt_point(global_point: Vector2) -> void:
	belt_point_global = global_point


func is_waiting() -> bool:
	return state == State.WAITING


func boost_patience(fraction: float) -> void:
	patience += fraction * patience_max
	patience_bar.value = patience


func _process(delta: float) -> void:
	if _time_frozen():
		return
	match state:
		State.WAITING:
			# Cuanto más ha comido el cliente, más rápido se le agota la
			# paciencia: cada plato acelera el drenaje (+PATIENCE_DRAIN_PER_PLATE).
			var drain := 1.0 + PATIENCE_DRAIN_PER_PLATE * eaten_ids.size()
			patience -= delta * drain
			patience_bar.value = patience
			if patience <= 0.0:
				_leave()
		State.EATING:
			eat_timer -= delta
			eat_bar.value = maxf(eat_timer, 0.0)
			if eat_timer <= 0.0:
				_finish_plate()


func _on_zone_area_entered(area: Area2D) -> void:
	if state != State.WAITING:
		return
	var plate = area.get_parent()
	if plate == null or not plate is PathFollow2D:
		return
	if plate.taken:
		return
	var pid := plate.get_instance_id()
	if pid in declined:
		return
	var data := RecipeData.get_recipe(plate.recipe_id)
	var plate_satiety: int = data.get("satiety", 1)
	var chance: float = TAKE_CHANCES.get(client_type, {}).get(plate_satiety, 0.0)
	if _aroma_active() and plate_satiety == FAVORITE_TIER.get(client_type, 0):
		chance = maxf(chance, 0.95)
	if guaranteed_next:
		chance = 1.0
	if randf() < chance:
		guaranteed_next = false
		plate.taken = true
		current_price = int(round(data.get("price", 0) * pay_mult))
		current_satiety = plate_satiety
		current_id = plate.recipe_id
		var plate_pos: Vector2 = plate.global_position
		plate.queue_free()
		_start_eating(plate_pos)
	else:
		declined.append(pid)


## Animación de coger el plato de la cinta y comérselo.
func _start_eating(plate_global: Vector2) -> void:
	state = State.EATING
	var recipe := RecipeData.get_recipe(current_id)
	var base: float = float(EAT_TIMES[client_type].get(current_satiety,
		EAT_TIMES[client_type][1]))
	# "eat_mult": algunos platos (p. ej. la sopa de miso) se comen más despacio.
	eat_duration = base * randf_range(1.0 - EAT_JITTER, 1.0 + EAT_JITTER) \
			* float(recipe.get("eat_mult", 1.0))
	eat_timer = eat_duration
	eat_bar.max_value = eat_duration
	eat_bar.value = eat_duration
	eat_bar.visible = true
	patience_bar.visible = false
	# La comida recarga paciencia según el nivel del plato. Repetirle el MISMO
	# plato aburre (sube el nivel y recarga la mitad cada vez); cambiar de plato
	# NO reinicia del todo, solo retrocede un nivel de aburrimiento. Ej.: mismo
	# plato 12%→6%→3%; al cambiar sube a 6%, y otro cambio vuelve a 12%.
	if current_id == last_dish_id:
		boredom += 1
	else:
		boredom = maxi(boredom - 1, 0)
	last_dish_id = current_id
	# "patience_mult": los makis/futomaki recargan x0.2 menos; la sopa de miso
	# y el gunkan de tartar recargan de más.
	var pat_mult := float(recipe.get("patience_mult", 1.0))
	var boost: float = PATIENCE_FOOD.get(current_satiety, 0.12) * pow(REPEAT_DECAY, boredom) * pat_mult
	patience = minf(patience + boost * patience_max, patience_max)

	# El plato viaja de la cinta a las manos del cliente...
	held_dish = Sprite2D.new()
	held_dish.texture = RecipeData.get_dish_texture(current_id)
	held_dish.scale = Vector2(0.045, 0.045)
	held_dish.z_index = 3
	add_child(held_dish)
	held_dish.global_position = plate_global
	var grab := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	grab.tween_property(held_dish, "position", Vector2(0, 8), 0.3)

	# ...y el cliente mastica (balanceo suave del cuerpo y del plato).
	eat_anim_tween = create_tween().set_loops()
	eat_anim_tween.tween_property(body, "scale", body.scale * Vector2(1.04, 0.94), 0.22)
	eat_anim_tween.tween_property(body, "scale", body.scale, 0.22)


func _stop_eating_anim() -> void:
	if eat_anim_tween != null:
		eat_anim_tween.kill()
		eat_anim_tween = null
	var s: float = TYPE_SCALES.get(client_type, 0.11)
	body.scale = Vector2(s, s)
	if held_dish != null:
		held_dish.queue_free()
		held_dish = null


func _aroma_active() -> bool:
	return level_ref != null and "aroma_active" in level_ref and level_ref.aroma_active


func _time_frozen() -> bool:
	return level_ref != null and "frozen" in level_ref and level_ref.frozen


## Sin saciedad objetivo: el cliente NUNCA se va por comer; vuelve a esperar
## y solo se marcha cuando la paciencia se agota. El pago del plato y su posible
## propina se abonan al nivel AQUÍ mismo (no al marcharse).
func _finish_plate() -> void:
	satiety_eaten += current_satiety
	money_earned += current_price
	eaten_ids.append(current_id)
	var tip := _roll_plate_tip()
	tips_earned += tip
	plate_served.emit(current_price, tip)
	# Aviso flotante: precio del plato en amarillo y, si la deja, la propina en
	# verde justo encima.
	_float_text("+$%d" % current_price, Color(1.0, 0.86, 0.2))
	if tip > 0:
		_float_text("+$%d" % tip, Color(0.4, 1.0, 0.45), -50.0)
	_stop_eating_anim()
	eat_bar.visible = false
	state = State.WAITING
	patience_bar.visible = true


## Texto flotante que PARPADEA sobre el cliente y sube desvaneciéndose. Se usa
## para el precio cobrado por cada plato (amarillo) y la propina (verde).
func _float_text(text: String, color: Color, y_offset: float = 0.0) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(140, 0)
	lbl.position = Vector2(-70, -96.0 + y_offset)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 34)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	lbl.add_theme_constant_override("outline_size", 7)
	lbl.z_index = 40
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.pivot_offset = Vector2(70, 18)
	add_child(lbl)
	lbl.scale = Vector2(0.5, 0.5)
	var tw := lbl.create_tween()
	# Aparición con "pop".
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Parpadeo.
	for i in 2:
		tw.tween_property(lbl, "modulate:a", 0.25, 0.09)
		tw.tween_property(lbl, "modulate:a", 1.0, 0.09)
	# Sube y se desvanece.
	tw.tween_property(lbl, "position:y", lbl.position.y - 66.0, 0.7) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.tween_callback(lbl.queue_free)


func force_leave() -> void:
	_leave()


func _leave() -> void:
	if state == State.DONE or state == State.LEAVING:
		return
	if walk_tween != null:
		walk_tween.kill()
	_stop_eating_anim()
	finished.emit({
		"type": client_type,
		"money": money_earned,
		"tip": tips_earned,
		"eaten": eaten_ids.duplicate(),
		"satiety_eaten": satiety_eaten,
	})
	state = State.LEAVING
	zone.monitoring = false
	patience_bar.visible = false
	eat_bar.visible = false
	_walk_out()


## Se marcha andando por la ruta inversa hasta la salida.
func _walk_out() -> void:
	_start_bob()
	var out_points: Array = route.duplicate()
	out_points.reverse()
	out_points.remove_at(0)  # ya está en el asiento
	out_points.append(Vector2(360, 100))
	walk_tween = create_tween()
	var from: Vector2 = position
	for point in out_points:
		var dist: float = from.distance_to(point)
		walk_tween.tween_property(self, "position", point, dist / WALK_SPEED)
		from = point
	walk_tween.finished.connect(queue_free)


## Propina de UN plato (se tira al terminar cada plato). La probabilidad crece
## con el nº de platos comidos por este cliente (ver TIP_RULES) hasta su tope;
## la cuantía es un % del dinero ACUMULADO que lleva gastado el cliente (no del
## precio de este plato suelto), así que crece con la cuenta total. Debe
## llamarse DESPUÉS de sumar current_price a money_earned y de añadir el plato
## a eaten_ids, para que ambos incluyan el plato recién comido.
func _roll_plate_tip() -> int:
	var rules: Dictionary = TIP_RULES.get(client_type, {})
	var plates := eaten_ids.size()
	if rules.is_empty() or plates < int(rules.start):
		return 0
	# La probabilidad no crece hasta "ramp" platos; antes se queda en "base".
	var ramp: int = int(rules.get("ramp", rules.start))
	var extra_steps := maxi(plates - ramp, 0) / int(rules.every)
	var tip_chance: float = minf(float(rules.base) + float(rules.step) * extra_steps, float(rules.max))
	var amount_mult := 1.0
	if level_ref != null:
		if "tip_chance_bonus" in level_ref:
			tip_chance += level_ref.tip_chance_bonus
		if "tip_amount_mult" in level_ref:
			amount_mult = level_ref.tip_amount_mult
	# Bono de propina por platos especiales (recetas con "tip_chance_bonus", como
	# el tartar): la 1ª vez que este cliente comió el plato suma su bono entero,
	# y cada repetición del MISMO plato suma la MITAD que la anterior
	# (3% > 1.5% > 0.75% ...).
	var seen := {}
	for id in eaten_ids:
		var rb: float = RecipeData.get_recipe(id).get("tip_chance_bonus", 0.0)
		if rb <= 0.0:
			continue
		var n: int = seen.get(id, 0)
		tip_chance += rb * pow(0.5, n)
		seen[id] = n + 1
	if randf() < tip_chance:
		return maxi(int(round(money_earned * float(rules.pct) * amount_mult)), 1)
	return 0
