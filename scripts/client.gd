extends Node2D
## Cliente pirata: entra andando desde la zona superior del barco, se sienta,
## coge platos de la cinta (con animación), come y se marcha andando.
## Su estado de ánimo se muestra en un bocadillo: triste (no ha comido),
## neutral (a medias) o feliz (último plato / saciado).

signal finished(report: Dictionary)

enum State { ARRIVING, WAITING, EATING, LEAVING, DONE }

const WALK_SPEED := 190.0

## Probabilidad de coger un plato según tipo de cliente y saciedad del plato.
const TAKE_CHANCES: Dictionary = {
	"E": { 1: 0.95, 2: 0.15, 3: 0.10 },
	"A": { 1: 0.25, 2: 0.92, 3: 0.25 },
	"G": { 1: 0.0, 2: 0.50, 3: 0.95 },
}

const FAVORITE_TIER: Dictionary = { "E": 1, "A": 2, "G": 3 }

## Rango de tiempo de comida por plato según tipo (segundos).
const EAT_TIMES: Dictionary = {
	"E": [3.0, 5.0],
	"A": [5.0, 8.0],
	"G": [8.0, 12.0],
}

const TYPE_SPRITES: Dictionary = {
	"E": "res://assets/characters/grumete.webp",
	"A": "res://assets/characters/pirata.webp",
	"G": "res://assets/characters/capitan.webp",
}

const TYPE_SCALES: Dictionary = { "E": 0.095, "A": 0.115, "G": 0.13 }

## Al recibir un plato la paciencia sube un poco (fracción del máximo).
const PATIENCE_REWARD := 0.15

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
var satiety_needed: int = 2
var satiety_left: int = 2
var satiety_eaten: int = 0
var money_earned: int = 0
var eat_timer: float = 0.0
var eat_duration: float = 1.0
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
@onready var bubble: TextureRect = $Bubble
@onready var patience_bar: ProgressBar = $PatienceBar
@onready var eat_bar: ProgressBar = $EatBar
@onready var zone: Area2D = $Zone


func _ready() -> void:
	add_to_group("clients")
	level_ref = get_parent()
	patience_max = randf_range(50.0, 65.0) * patience_scale
	patience = patience_max
	match client_type:
		"E":
			satiety_needed = randi_range(2, 3)
		"A":
			satiety_needed = randi_range(4, 5)
		"G":
			satiety_needed = 5
	satiety_left = satiety_needed
	var tex_path: String = TYPE_SPRITES.get(client_type, "")
	if tex_path != "" and ResourceLoader.exists(tex_path):
		body.texture = load(tex_path)
	var s: float = TYPE_SCALES.get(client_type, 0.11)
	body.scale = Vector2(s, s)
	body.flip_h = face_flip
	eat_bar.visible = false
	patience_bar.visible = false
	bubble.visible = false
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
	bubble.visible = true
	_update_bubble()


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
			patience -= delta
			patience_bar.value = patience
			if patience <= 0.0:
				_leave()
		State.EATING:
			eat_timer -= delta
			eat_bar.value = maxf(eat_timer, 0.0)
			if eat_timer <= 0.0:
				_finish_plate()


## Bocadillo de ánimo:
##  triste  → aún no ha comido nada
##  feliz   → está comiendo el plato que le sacia (o ya está saciado)
##  neutral → ha comido algo pero le falta
func _update_bubble() -> void:
	var tex_name := "bubble_neutral"
	if satiety_eaten <= 0 and state != State.EATING:
		tex_name = "bubble_triste"
	elif state == State.EATING and satiety_left - current_satiety <= 0:
		tex_name = "bubble_feliz"
	elif satiety_left <= 0:
		tex_name = "bubble_feliz"
	elif satiety_eaten == 0:
		tex_name = "bubble_triste"
	var path := "res://assets/ui/%s.png" % tex_name
	if ResourceLoader.exists(path):
		bubble.texture = load(path)


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
	eat_duration = randf_range(EAT_TIMES[client_type][0], EAT_TIMES[client_type][1])
	eat_timer = eat_duration
	eat_bar.max_value = eat_duration
	eat_bar.value = eat_duration
	eat_bar.visible = true
	patience_bar.visible = false
	patience = minf(patience + PATIENCE_REWARD * patience_max, patience_max)
	_update_bubble()

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


func _finish_plate() -> void:
	satiety_eaten += current_satiety
	satiety_left -= current_satiety
	money_earned += current_price
	eaten_ids.append(current_id)
	_stop_eating_anim()
	eat_bar.visible = false
	if satiety_left <= 0:
		_leave()
	else:
		state = State.WAITING
		patience_bar.visible = true
		_update_bubble()


func force_leave() -> void:
	_leave()


func _leave() -> void:
	if state == State.DONE or state == State.LEAVING:
		return
	if walk_tween != null:
		walk_tween.kill()
	_stop_eating_anim()
	var ratio := clampf(float(satiety_eaten) / float(satiety_needed), 0.0, 1.0)
	var satisfaction := 1.0 + 4.0 * ratio
	var tip := 0
	if satiety_left <= 0:
		tip = _roll_tip()
	finished.emit({
		"type": client_type,
		"money": money_earned,
		"tip": tip,
		"satisfaction": satisfaction,
		"eaten": eaten_ids.duplicate(),
		"satiety_eaten": satiety_eaten,
		"satiety_needed": satiety_needed,
		"filled": satiety_left <= 0,
	})
	state = State.LEAVING
	zone.monitoring = false
	patience_bar.visible = false
	eat_bar.visible = false
	bubble.visible = false
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


## Propina según tipo y exceso de saciedad (surplus = comido - necesitado).
func _roll_tip() -> int:
	var surplus := satiety_eaten - satiety_needed
	var tip_chance := 0.0
	var tip_pct := 0.3
	match client_type:
		"E":
			tip_pct = 0.1
			if surplus >= 1:
				tip_chance = 0.55
			else:
				tip_chance = 0.35
		"A":
			if surplus >= 2:
				tip_chance = 1.0
				tip_pct = 0.35
			elif surplus == 1:
				tip_chance = 0.4
				tip_pct = 0.3
			else:
				tip_chance = 0.35
				tip_pct = 0.2
		"G":
			if surplus >= 1:
				tip_chance = 1.0
				tip_pct = 0.5
			else:
				tip_chance = 0.45
				tip_pct = 0.3
	var amount_mult := 1.0
	if level_ref != null:
		if "tip_chance_bonus" in level_ref:
			tip_chance += level_ref.tip_chance_bonus
		if "tip_amount_mult" in level_ref:
			amount_mult = level_ref.tip_amount_mult
	if randf() < tip_chance:
		return maxi(int(round(money_earned * tip_pct * amount_mult)), 1)
	return 0
