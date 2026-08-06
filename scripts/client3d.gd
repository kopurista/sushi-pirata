extends Node3D
## Cliente pirata en 3D (port de client.gd con la MISMA logica de juego).
## Entra andando desde la borda, rodea el mostrador por fuera, se sienta en su
## taburete, coge platos de la cinta, come y se marcha andando.
## Se queda hasta que su barra de PACIENCIA se agota (no hay saciedad objetivo):
## cada plato comido recarga paciencia segun su nivel, pero repetirle el mismo
## plato rinde cada vez menos. La propina depende del Nº de platos (TIP_RULES).
##
## Presentacion: modelo GLB riggeado + CharacterAnim (andar/sentarse/comer
## proceduralmente). Sin fisica: la deteccion de platos sondea el grupo
## "plates" comparando distancias con su punto de la cinta. Las barras de
## paciencia/comida y los textos flotantes son Controles 2D en level.world_ui,
## anclados proyectando la cabeza del cliente con la camara (que es fija).

signal finished(report: Dictionary)
## Se emite al terminar CADA plato: el precio del plato y la propina de ese
## plato (0 si no la deja). El nivel suma ambos al instante, no al marcharse.
signal plate_served(food: int, tip: int)

enum State { ARRIVING, WAITING, EATING, LEAVING, DONE }

## Radio (en el plano del suelo) alrededor del punto de cinta del cliente en el
## que un plato se considera "a su alcance". Los puntos de cinta de dos
## asientos vecinos distan 1.8 u, asi que 0.45 no se solapa nunca.
const TAKE_RADIUS := 0.45

## Altura (u) por tipo de cliente. En la misma proporcion que las escalas 2D
## (0.095 / 0.115 / 0.13 con el pirata en 1.75). El MODELO ya no vive aqui: lo
## resuelve CharacterData segun el tipo y el genero de este cliente.
const TYPE_HEIGHTS: Dictionary = { "E": 1.45, "A": 1.75, "G": 1.95 }

## Probabilidad de coger un plato segun tipo de cliente y nivel del plato.
const TAKE_CHANCES: Dictionary = {
	"E": { 1: 0.95, 2: 0.20, 3: 0.10 },
	"A": { 1: 0.45, 2: 0.95, 3: 0.25 },
	"G": { 1: 0.10, 2: 0.55, 3: 0.95 },
}

const FAVORITE_TIER: Dictionary = { "E": 1, "A": 2, "G": 3 }

## Rango de tiempo de comida (s) por tipo de cliente Y nivel del plato.
## Subidos ~20% respecto al 2D: en 3D el ritmo general es mas pausado.
const EAT_TIMES: Dictionary = {
	"E": { 1: [3.5, 6.0], 2: [8.0, 11.5], 3: [12.5, 17.0] },
	"A": { 1: [4.0, 6.5], 2: [6.0, 9.5], 3: [10.5, 14.0] },
	"G": { 1: [2.5, 4.0], 2: [5.0, 7.5], 3: [9.0, 13.5] },
}

## Castigo (doblones) si el cliente se marcha SIN haber probado NADA: cuanto
## mas importante es el cliente, mas cuesta desatenderlo. Se cobra tanto si se
## le agoto la paciencia como si le pillo el fin del TIEMPO; la unica excepcion
## es cerrar el turno por haber alcanzado el objetivo (ver force_leave).
const LEAVE_PENALTY: Dictionary = { "E": 5, "A": 8, "G": 12 }

## Al recibir un plato la paciencia sube (fraccion del maximo) segun el nivel.
## Rebajado (antes 0.12/0.30/0.50): cada plato retiene menos al cliente.
const PATIENCE_FOOD: Dictionary = { 1: 0.09, 2: 0.22, 3: 0.38 }
## Repetir el MISMO plato recarga MENOS de la mitad cada vez (endurecido desde
## 0.5); cambiar de plato solo retrocede UN nivel de aburrimiento.
const REPEAT_DECAY := 0.4
## Cada plato comido acelera el drenaje de paciencia en este factor.
const PATIENCE_DRAIN_PER_PLATE := 0.025
## Mientras NO ha comido nada, la paciencia baja a esta fracción del ritmo
## normal: da margen para que todo cliente llegue a catar su primer plato.
const FIRST_PLATE_DRAIN := 0.45
## Cuando el nivel ya ha terminado, el bocado que quedaba a medias corre a esta
## velocidad: el jugador solo espera a cobrarlo, no tiene sentido hacerle mirar.
const END_BITE_SPEED := 5.0
## Doblones extra que deja un plato de PICOTEO ("snack" en recipe_data, como el
## edamame) cuando el cliente lo coge SIN dejar de comer el plato que tenia.
const SNACK_BONUS := 1
## El picoteo RELLENA LA BARRA DE COMER (no la de paciencia): alarga la comida
## en curso esta fraccion de su duracion. Mientras come, la paciencia no se
## drena, asi que alargar el bocado es lo que retiene al cliente en la mesa.
const SNACK_EAT_REFILL := 0.35

## Propina segun el nº de platos comidos (ver client.gd 2D para el detalle).
const TIP_RULES: Dictionary = {
	"E": { "start": 1, "ramp": 3, "every": 1, "base": 0.20, "step": 0.01, "max": 0.65, "pct": 0.15 },
	"A": { "start": 1, "ramp": 3, "every": 1, "base": 0.23, "step": 0.015, "max": 0.60, "pct": 0.16 },
	"G": { "start": 1, "ramp": 3, "every": 1, "base": 0.25, "step": 0.02, "max": 0.50, "pct": 0.18 },
}

## Altura del asiento del taburete (debe coincidir con level3d.STOOL_H).
const STOOL_TOP := 0.47
## Huella del plato que come el cliente, algo menor que el de la cinta.
const HELD_DISH_FOOT := 0.45

var client_type: String = "E"
## Genero de ESTE cliente ("m"/"f"): lo sortea el nivel al sentarlo, asi que
## la clientela sale mezclada y distinta en cada partida.
var gender: String = CharacterData.MALE
var patience_scale: float = 1.0
var pay_mult: float = 1.0
var guaranteed_next: bool = false
## Multiplicador extra del tiempo de comer. Solo lo toca el guion del tutorial,
## que necesita bocados largos para poder explicar cosas mientras el cliente come.
var slow_eat: float = 1.0
## Personaje CONCRETO en vez del que le tocaría por tipo (`CharacterData.MODELS`):
## lo usa Pablo el Rubio en el nivel 5, que come como un capitán pero tiene su
## propio modelo. "" = el del tipo de siempre.
var who_override: String = ""
## Perdona el castigo de marcharse sin comer (ver force_leave).
var _sin_castigo := false
## Puntos de la ruta de entrada (el nivel los define; el ultimo es el asiento).
var route: Array = []
## Punto por el que desaparece al marcharse (la borda).
var exit_point := Vector3.ZERO
## Punto de la cinta (mundo) frente a su asiento, donde vigila los platos.
var belt_point := Vector3.ZERO
## Orientacion (grados Y) mirando a la cinta cuando esta sentado.
var seat_yaw := 0.0

var state: State = State.ARRIVING
var patience_max: float = 55.0
var patience: float = 55.0
var satiety_eaten: int = 0
var last_dish_id: String = ""
var boredom: int = 0
var money_earned: int = 0
var eat_timer: float = 0.0
var eat_duration: float = 1.0
## Un cliente solo pica UN plato de picoteo por cada plato que se está
## comiendo: se marca al cogerlo y se limpia al empezar el plato siguiente.
var snack_taken := false
## Segundos que la paciencia se queda CONGELADA (la deja el unagi glaseado).
var patience_frozen: float = 0.0
var tips_earned: int = 0
var current_price: int = 0
var current_satiety: int = 0
var current_id: String = ""
## Extras (jengibre / wasabi / soja) del plato que se está comiendo.
var current_extras: Array = []
## Tiempo de comida propio del plato en curso (0 = el de su receta). Lo trae el
## barco combinado, que tarda según cuántos platos lleve dentro.
var current_eat_mult: float = 0.0
var eaten_ids: Array[String] = []
var declined: Array[int] = []
## Se ha acabado el nivel mientras comia: se marchara al acabar el bocado.
var _leave_when_done := false
var level_ref: Node = null

## El modelo cuelga de "body": el bob del andar y el ajuste de sentado van en
## body.position.y, y el giro de orientacion en la raiz.
var _body: Node3D
var _anim: CharacterAnim = null
var _model_scale := 1.0
var _height := 1.75
## Mancha de sombra que acompaña al cliente.
var _blob: MeshInstance3D = null
var _t := 0.0                 ## reloj local para respirar/sentado
var _walk_t := 0.0            ## reloj del ciclo de marcha (solo avanza andando)
var _eat_t := 0.0             ## reloj del bocado (solo avanza comiendo)
var _walk_speed := 1.2
var _leg := 0
var _leg_dist := 0.0
var _dish_spot := Vector3.ZERO
var _held_dish: Node3D = null

var _patience_bar: ProgressBar = null
var _eat_bar: ProgressBar = null


func _ready() -> void:
	add_to_group("clients")
	level_ref = get_parent()
	# Paciencia base ajustada a partidas de 2:30.
	patience_max = randf_range(30.0, 40.0) * patience_scale
	patience = patience_max
	_height = float(TYPE_HEIGHTS.get(client_type, 1.75))
	_spawn_model()
	_make_blob()
	_make_bars()
	if not route.is_empty():
		position = route[0] if position == Vector3.ZERO else position
	_face_leg()


## Mancha de sombra bajo los pies: el juego no usa sombras proyectadas (ver
## SceneBackdrop.blob_shadow), así que sin esto los clientes flotan sobre la
## cubierta. Cuelga del propio cliente, así que le sigue sola.
func _make_blob() -> void:
	var w := _height * 0.5
	_blob = SceneBackdrop.blob_shadow(w, w * 0.68)
	_blob.position = Vector3(0.0, 0.03, 0.0)
	add_child(_blob)


func _spawn_model() -> void:
	_body = Node3D.new()
	add_child(_body)
	var quien: String = who_override if who_override != "" \
			else CharacterData.who_for_type(client_type)
	var path := CharacterData.model(quien, gender)
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	_body.add_child(inst)
	var aabb := _merged_aabb(inst)
	_model_scale = _height / maxf(aabb.size.y, 0.0001)
	inst.scale = Vector3.ONE * _model_scale
	inst.position = -Vector3(
		aabb.position.x + aabb.size.x * 0.5,
		aabb.position.y,
		aabb.position.z + aabb.size.z * 0.5) * _model_scale
	var skels := inst.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		_anim = CharacterAnim.new(skels[0])
		if not _anim.has_humanoid_bones():
			_anim = null
	# La velocidad sale del propio ciclo de marcha: con ella el pie apoyado
	# queda clavado en el suelo (cero patinaje). Es mas lenta que la del juego
	# 2D (~1.2 u/s frente a 2.2), decision tomada a proposito.
	if _anim != null:
		_walk_speed = _anim.ground_speed(_model_scale)


func _merged_aabb(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = m.transform * m.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


# ------------------------------------------------------------ barras y HUD

## Las barras viven en level.world_ui (CanvasLayer bajo el HUD) y se anclan
## proyectando un punto sobre la cabeza; la camara es fija, asi que basta con
## recolocarlas cuando el cliente se sienta.
func _make_bars() -> void:
	_patience_bar = ProgressBar.new()
	_patience_bar.show_percentage = false
	_patience_bar.size = Vector2(76, 13)
	_patience_bar.max_value = patience_max
	_patience_bar.value = patience
	_patience_bar.visible = false
	_eat_bar = ProgressBar.new()
	_eat_bar.show_percentage = false
	_eat_bar.size = Vector2(76, 13)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1, 0.65, 0.2)
	fill.set_corner_radius_all(4)
	_eat_bar.add_theme_stylebox_override("fill", fill)
	_eat_bar.visible = false
	var ui := _world_ui()
	if ui != null:
		ui.add_child(_patience_bar)
		ui.add_child(_eat_bar)


func _world_ui() -> Node:
	if level_ref != null and "world_ui" in level_ref:
		return level_ref.world_ui
	return null


## Posicion en pantalla del punto sobre la cabeza del cliente.
func _head_screen() -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector2.ZERO
	return cam.unproject_position(global_position + Vector3.UP * (_height + 0.22))


func _place_bars() -> void:
	var p := _head_screen() + Vector2(-38, -10)
	_patience_bar.position = p
	_eat_bar.position = p


func _exit_tree() -> void:
	for bar in [_patience_bar, _eat_bar]:
		if bar != null:
			bar.queue_free()


# ------------------------------------------------------------------ estados

func is_waiting() -> bool:
	return state == State.WAITING


func boost_patience(fraction: float) -> void:
	patience += fraction * patience_max
	patience_bar_update()


## ¿Está con un plato entre manos? Lo consulta el guion del tutorial.
func is_eating() -> bool:
	return state == State.EATING


## Las dos barras flotantes, para que el guion del tutorial pueda enfocarlas.
func patience_bar() -> ProgressBar:
	return _patience_bar


func eat_bar() -> ProgressBar:
	return _eat_bar


func patience_bar_update() -> void:
	if _patience_bar != null:
		_patience_bar.value = patience


func _process(delta: float) -> void:
	if _time_frozen():
		return
	_t += delta
	match state:
		State.ARRIVING:
			_advance_route(delta)
		State.WAITING:
			_pose_sit_idle()
			# "patience_freeze" (unagi): la barra se congela unos segundos y no
			# baja nada. Se tiñe de azul para que se vea que está parada.
			if patience_frozen > 0.0:
				patience_frozen = maxf(patience_frozen - delta, 0.0)
				_patience_bar.modulate = Color(0.55, 0.85, 1.0)
				patience_bar_update()
				_scan_belt()
				return
			_patience_bar.modulate = Color.WHITE
			# Cuanto mas ha comido, mas rapido se agota la paciencia.
			var drain := 1.0 + PATIENCE_DRAIN_PER_PLATE * eaten_ids.size()
			# Recién sentado la paciencia baja MUCHO más despacio: casi todo el
			# mundo debe llegar a probar su primer plato. En cuanto come algo,
			# el drenaje pasa a ser el normal.
			if eaten_ids.is_empty():
				drain *= FIRST_PLATE_DRAIN
			patience -= delta * drain
			patience_bar_update()
			if patience <= 0.0:
				_leave()
				return
			_scan_belt()
		State.EATING:
			# Tras el fin del nivel el ultimo bocado va MUY deprisa: el jugador
			# ya no puede hacer nada y solo espera a ver lo que le dejan.
			var speed := END_BITE_SPEED if _leave_when_done else 1.0
			_eat_t += delta * speed
			if _anim != null:
				_anim.reset()
				_anim.bite(_eat_t)
			eat_timer -= delta * speed
			_eat_bar.value = maxf(eat_timer, 0.0)
			# Sin dejar de comer puede picar un plato de "snack" (edamame).
			if not _leave_when_done:
				_scan_belt(true)
			if eat_timer <= 0.0:
				_finish_plate()
		State.LEAVING:
			_advance_route(delta)


## Recorre la ruta actual andando. Al agotar la ruta: sentarse (llegada) o
## desaparecer (salida). El avance y el bob salen del propio ciclo de marcha.
func _advance_route(delta: float) -> void:
	_walk_t += delta
	if _anim != null:
		_anim.reset()
		_anim.walk(_walk_t)
		_body.position.y = _anim.walk_bob(_walk_t, _model_scale)
	_leg_dist += _walk_speed * delta
	while _leg < route.size() - 1:
		var a: Vector3 = route[_leg]
		var b: Vector3 = route[_leg + 1]
		var leg_len := a.distance_to(b)
		if _leg_dist < leg_len:
			position = a.lerp(b, _leg_dist / leg_len)
			return
		_leg_dist -= leg_len
		_leg += 1
		_face_leg()
	# Ruta agotada.
	position = route.back()
	if state == State.ARRIVING:
		_seat()
	else:
		state = State.DONE
		queue_free()


func _face_leg() -> void:
	if _leg >= route.size() - 1:
		return
	var dir: Vector3 = route[_leg + 1] - route[_leg]
	if dir.length() > 0.001:
		rotation_degrees.y = rad_to_deg(atan2(dir.x, dir.z))


func _seat() -> void:
	if state != State.ARRIVING:
		return
	state = State.WAITING
	rotation_degrees.y = seat_yaw
	_sit_on_stool()
	_place_bars()
	_patience_bar.visible = true


## Sienta al personaje SOBRE el taburete: con la pose de sentado puesta, se
## sube/baja el cuerpo para que los gluteos (algo por debajo del hueso de la
## cadera) apoyen en el asiento. En personajes bajitos los pies quedan
## colgando, que es justo lo que hace un niño en un taburete de bar.
func _sit_on_stool() -> void:
	if _anim == null:
		return
	_anim.reset()
	_anim.sit()
	var skel: Skeleton3D = _body.find_children("*", "Skeleton3D", true, false)[0]
	var hip_w: Vector3 = skel.global_transform \
		* skel.get_bone_global_pose(_anim.bone("Pelvis")).origin
	var glute_drop := 0.10 * (_height / 1.75)
	var dy := (STOOL_TOP + glute_drop) - hip_w.y
	_body.position.y = dy
	# El plato ira donde la mano derecha va a buscar la comida (hand_plate es
	# un punto en espacio del esqueleto; el bocado come con la derecha: -X).
	var hp: Vector3 = _anim.hand_plate
	_dish_spot = skel.global_transform * Vector3(-hp.x, hp.y, hp.z) \
		+ Vector3(0.0, dy - 0.08, 0.0)
	_anim.reset()


func _pose_sit_idle() -> void:
	if _anim != null:
		_anim.reset()
		_anim.sit_idle(_t)


# ------------------------------------------------------------ coger platos

## Sondea los platos de la cinta: el que pase por su punto de la cinta a menos
## de TAKE_RADIUS (en el plano del suelo) puede ser cogido. Sustituye al Area2D
## del juego 2D sin necesitar fisica 3D.
## Con snack_only solo mira los platos de PICOTEO: es la pasada que se hace
## mientras el cliente esta comiendo, para que pueda picar sin interrumpirse.
func _scan_belt(snack_only: bool = false) -> void:
	for plate in get_tree().get_nodes_in_group("plates"):
		if plate.taken:
			continue
		var d := Vector2(plate.global_position.x - belt_point.x,
			plate.global_position.z - belt_point.z)
		if d.length() > TAKE_RADIUS:
			continue
		var pid: int = plate.get_instance_id()
		if pid in declined:
			continue
		var data: Dictionary = RecipeData.get_recipe(plate.recipe_id)
		# "only_type": postres que SOLO come un tipo de cliente (el mochi es de
		# grumetes, el dorayaki de piratas, el taiyaki de capitanes). Ni con
		# potenciadores lo cogen los demás: se descarta antes de tirar el dado.
		var only: String = data.get("only_type", "")
		if only != "" and only != client_type:
			continue
		# Solo un picoteo por plato en curso: hasta que no termine el que está
		# comiendo no vuelve a picar (al empezar el siguiente se rearma).
		if snack_only and (snack_taken or not data.get("snack", false)):
			continue
		# El barco se cataloga por lo que lleva dentro, no por su receta.
		var plate_satiety: int = int(data.get("satiety", 1))
		if plate.level_override > 0:
			plate_satiety = plate.level_override
		# "take_chance" salta la matriz por nivel. Admite las DOS formas: un
		# número, que vale igual para todos (el edamame lo pica cualquiera), o
		# un diccionario {E,A,G} con uno por tipo (el onigiri gusta a los tres,
		# pero no por igual).
		# "take_chances": matriz PROPIA de la receta (el barco combinado). Se
		# indexa igual, por tipo y nivel, solo que con otros números.
		var table: Dictionary = data.get("take_chances", TAKE_CHANCES)
		var chance: float = table.get(client_type, {}).get(plate_satiety, 0.0)
		var forced: Variant = data.get("take_chance", null)
		if forced is Dictionary:
			chance = float(forced.get(client_type, chance))
		elif forced != null:
			chance = float(forced)
		if _aroma_active() and plate_satiety == FAVORITE_TIER.get(client_type, 0):
			chance = maxf(chance, 0.95)
		if guaranteed_next and not snack_only:
			chance = 1.0
		if randf() < chance:
			var rid: String = plate.recipe_id
			var plate_pos: Vector3 = plate.global_position
			plate.taken = true
			plate.queue_free()
			if snack_only:
				_eat_snack(rid, data)
				return
			guaranteed_next = false
			# El plato puede traer su propio precio (barco combinado).
			var base_price: int = plate.price_override if plate.price_override > 0 \
				else int(data.get("price", 0))
			current_price = int(round(base_price * pay_mult))
			current_satiety = plate_satiety
			current_id = rid
			current_extras = plate.extras.duplicate()
			current_eat_mult = plate.eat_mult_override
			_start_eating(plate_pos)
			return
		declined.append(pid)


## Picoteo cogido MIENTRAS come otro plato: RELLENA LA BARRA DE COMER (alarga
## el bocado en curso) y se cobra con SNACK_BONUS doblones extra, sin
## interrumpir el plato que tenia. Repetir el mismo picoteo rinde cada vez
## menos (mismo decaimiento que el aburrimiento), asi que no compensa inundar
## la cinta de edamame.
func _eat_snack(recipe_id: String, data: Dictionary) -> void:
	snack_taken = true
	var reps := 0
	for id in eaten_ids:
		if id == recipe_id:
			reps += 1
	var sat: int = data.get("satiety", 1)
	# "snack_refill": cuanto alarga el bocado (el gari casi nada, porque lo suyo
	# es la propina). Por defecto SNACK_EAT_REFILL.
	var refill: float = eat_duration * float(data.get("snack_refill", SNACK_EAT_REFILL)) \
		* pow(REPEAT_DECAY, reps)
	eat_timer += refill
	# La barra tiene que poder mostrar el tiempo extra: se ensancha el maximo.
	_eat_bar.max_value = maxf(_eat_bar.max_value, eat_timer)
	_eat_bar.value = eat_timer
	# "clears_boredom": el te verde limpia el paladar, asi que el cliente deja
	# de estar aburrido del plato que venia repitiendo.
	if data.get("clears_boredom", false):
		boredom = 0
		last_dish_id = ""
	var price: int = int(round(data.get("price", 0) * pay_mult)) + SNACK_BONUS
	satiety_eaten += sat
	money_earned += price
	eaten_ids.append(recipe_id)
	plate_served.emit(price, 0)
	_float_text("+$%d" % price, Color(1.0, 0.86, 0.2))


## El plato viaja de la cinta al mostrador frente al cliente, y este empieza a
## comer (coreografia de 4 fases de CharacterAnim.bite).
func _start_eating(plate_global: Vector3) -> void:
	state = State.EATING
	_eat_t = 0.0
	# Plato nuevo: vuelve a tener derecho a un picoteo.
	snack_taken = false
	var recipe := RecipeData.get_recipe(current_id)
	var range_s: Array = EAT_TIMES[client_type].get(current_satiety, EAT_TIMES[client_type][1])
	# "eat_mult": algunos platos (p. ej. la sopa de miso) se comen mas despacio.
	# `slow_eat` lo usa el guion del TUTORIAL para que un plato concreto dure
	# lo suficiente como para explicar otra receta mientras el cliente come.
	eat_duration = randf_range(range_s[0], range_s[1]) \
			* _eat_mult_of(recipe) * slow_eat
	eat_timer = eat_duration
	_eat_bar.max_value = eat_duration
	_eat_bar.value = eat_duration
	_eat_bar.visible = true
	_patience_bar.visible = false
	# La comida recarga paciencia segun el nivel del plato; repetir aburre
	# (recarga la mitad cada vez) y cambiar solo retrocede un nivel.
	# El JENGIBRE limpia el paladar: con él, este plato no cuenta como repetido
	# aunque sea el mismo de antes.
	if "jengibre" in current_extras:
		boredom = maxi(boredom - 1, 0)
		last_dish_id = ""
	elif current_id == last_dish_id:
		boredom += 1
		last_dish_id = current_id
	else:
		boredom = maxi(boredom - 1, 0)
		last_dish_id = current_id
	var pat_mult := float(recipe.get("patience_mult", 1.0))
	var boost: float = PATIENCE_FOOD.get(current_satiety, 0.12) * pow(REPEAT_DECAY, boredom) * pat_mult
	patience = minf(patience + boost * patience_max, patience_max)

	# El plato (modelo 3D) viaja de la cinta al mostrador, delante del cliente.
	_held_dish = Node3D.new()
	level_ref.add_child(_held_dish)
	_held_dish.global_position = plate_global
	var dish_path := "res://assets/models/%s.glb" % current_id
	if ResourceLoader.exists(dish_path):
		var inst: Node3D = (load(dish_path) as PackedScene).instantiate()
		_held_dish.add_child(inst)
		var aabb := _merged_aabb(inst)
		var foot := maxf(maxf(aabb.size.x, aabb.size.z), 0.0001)
		var s := HELD_DISH_FOOT / foot
		inst.scale = Vector3.ONE * s
		inst.position = -Vector3(
			aabb.position.x + aabb.size.x * 0.5,
			aabb.position.y,
			aabb.position.z + aabb.size.z * 0.5) * s
	var grab := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	grab.tween_property(_held_dish, "global_position", _dish_spot, 0.35)


## El plato puede traer su propio tiempo de comida (el barco, según los platos
## que lleve); si no, manda el "eat_mult" de la receta.
func _eat_mult_of(recipe: Dictionary) -> float:
	if current_eat_mult > 0.0:
		return current_eat_mult
	return float(recipe.get("eat_mult", 1.0))


func _stop_eating_anim() -> void:
	if _held_dish != null:
		_held_dish.queue_free()
		_held_dish = null


func _aroma_active() -> bool:
	return level_ref != null and "aroma_active" in level_ref and level_ref.aroma_active


func _time_frozen() -> bool:
	return level_ref != null and "frozen" in level_ref and level_ref.frozen


## Sin saciedad objetivo: el cliente NUNCA se va por comer; vuelve a esperar.
## El pago del plato y su posible propina se abonan al nivel AQUI mismo.
func _finish_plate() -> void:
	satiety_eaten += current_satiety
	money_earned += current_price
	eaten_ids.append(current_id)
	var tip := _roll_plate_tip()
	tips_earned += tip
	plate_served.emit(current_price, tip)
	_float_text("+$%d" % current_price, Color(1.0, 0.86, 0.2))
	if tip > 0:
		_float_text("+$%d" % tip, Color(0.4, 1.0, 0.45), -50.0)
	var recipe := RecipeData.get_recipe(current_id)
	# "patience_freeze": la barra se queda QUIETA unos segundos (unagi). Como
	# el cliente puede coger otro plato mientras tanto, la espera le sale
	# gratis; es lo que hace que rente un plato que se come en un suspiro.
	patience_frozen = maxf(patience_frozen,
		float(recipe.get("patience_freeze", 0.0)))
	_stop_eating_anim()
	_eat_bar.visible = false
	# "leaves_seat": los postres despiden al cliente. Paga, redondea la propina
	# ACUMULADA con un extra y se va, dejando la silla libre en el acto.
	if recipe.get("leaves_seat", false):
		var bonus := int(round(tips_earned * float(recipe.get("leave_tip_bonus", 0.0))))
		if bonus > 0:
			tips_earned += bonus
			# La propina va SOLO al bote, igual que el resto (contrato de
			# plate_served): dinero 0, propina el extra.
			plate_served.emit(0, bonus)
			_float_text("+$%d" % bonus, Color(0.4, 1.0, 0.45), -95.0)
		_leave()
		return
	# El nivel se acabo mientras comia: ya ha cobrado este plato, ahora se va.
	if _leave_when_done:
		_leave()
		return
	state = State.WAITING
	_patience_bar.visible = true


## Texto flotante que PARPADEA sobre el cliente y sube desvaneciendose, en el
## CanvasLayer world_ui del nivel (la camara es fija: se ancla una vez).
func _float_text(text: String, color: Color, y_offset: float = 0.0,
		con_moneda := false) -> void:
	var ui := _world_ui()
	if ui == null:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(140, 0)
	lbl.position = _head_screen() + Vector2(-70, -30.0 + y_offset)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 34)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	lbl.add_theme_constant_override("outline_size", 7)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.pivot_offset = Vector2(70, 18)
	# Las cifras de dinero llevan la moneda del juego, nunca el símbolo del dólar.
	if con_moneda:
		var coin := TextureRect.new()
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.texture = load("res://assets/ui/moneda.png")
		coin.size = Vector2(26, 26)
		coin.position = Vector2(88, 6)
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_child(coin)
	ui.add_child(lbl)
	lbl.scale = Vector2(0.5, 0.5)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in 2:
		tw.tween_property(lbl, "modulate:a", 0.25, 0.09)
		tw.tween_property(lbl, "modulate:a", 1.0, 0.09)
	tw.tween_property(lbl, "position:y", lbl.position.y - 66.0, 0.7) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.tween_callback(lbl.queue_free)


## Desalojo por fin de nivel. Si le pilla COMIENDO no se levanta a medias:
## termina su plato (y lo paga) y se marcha justo despues; el nivel espera.
## Desalojo por fin de nivel. `cobrar` a false perdona el castigo de irse de
## vacío: se usa cuando el turno se cierra porque YA se alcanzó el dinero
## objetivo, y sería absurdo penalizar por los clientes que sobraban.
func force_leave(cobrar := true) -> void:
	_sin_castigo = not cobrar
	if state == State.EATING:
		_leave_when_done = true
		return
	_leave()


## true si un cliente esta terminando su ultimo bocado tras el fin del nivel.
func is_finishing_bite() -> bool:
	return _leave_when_done and state == State.EATING


func _leave() -> void:
	if state == State.DONE or state == State.LEAVING:
		return
	_stop_eating_anim()
	# Irse sin haber probado NADA cuesta dinero, tanto si se le agoto la
	# paciencia como si le pillo el final del nivel.
	var penalty := 0
	if eaten_ids.is_empty() and not _sin_castigo:
		penalty = int(LEAVE_PENALTY.get(client_type, 0))
		if penalty > 0:
			_float_text("-%d" % penalty, Color(1.0, 0.34, 0.28), 0.0, true)
	finished.emit({
		"type": client_type,
		"money": money_earned,
		"tip": tips_earned,
		"penalty": penalty,
		"eaten": eaten_ids.duplicate(),
		"satiety_eaten": satiety_eaten,
	})
	state = State.LEAVING
	_patience_bar.visible = false
	_eat_bar.visible = false
	_body.position.y = 0.0
	_walk_out()


## Se marcha andando por la ruta inversa hasta la borda.
func _walk_out() -> void:
	var out_points: Array = route.duplicate()
	out_points.reverse()
	if not out_points.is_empty():
		out_points.remove_at(0)  # ya esta en el asiento
	out_points.push_front(position)
	out_points.append(exit_point)
	route = out_points
	_leg = 0
	_leg_dist = 0.0
	_face_leg()


## Propina de UN plato: probabilidad segun TIP_RULES (crece con los platos
## comidos), cuantia = % del dinero ACUMULADO del cliente. Debe llamarse
## DESPUES de sumar current_price a money_earned y del append a eaten_ids.
func _roll_plate_tip() -> int:
	var rules: Dictionary = TIP_RULES.get(client_type, {})
	var plates := eaten_ids.size()
	if rules.is_empty() or plates < int(rules.start):
		return 0
	var ramp: int = int(rules.get("ramp", rules.start))
	var extra_steps := maxi(plates - ramp, 0) / int(rules.every)
	var tip_chance: float = minf(float(rules.base) + float(rules.step) * extra_steps, float(rules.max))
	var amount_mult := 1.0
	if level_ref != null:
		if "tip_chance_bonus" in level_ref:
			tip_chance += level_ref.tip_chance_bonus
		if "tip_amount_mult" in level_ref:
			amount_mult = level_ref.tip_amount_mult
	# "tip_amount_mult" de la RECETA recién comida: el fugu no hace la propina
	# más probable, pero cuando cae es un 15% más gorda.
	amount_mult *= float(RecipeData.get_recipe(current_id).get("tip_amount_mult", 1.0))
	# EXTRAS de este plato: el wasabi hace la propina más PROBABLE y la soja
	# la hace más GORDA.
	if "wasabi" in current_extras:
		tip_chance += RecipeData.EXTRA_TIP_CHANCE
	if "soja" in current_extras:
		amount_mult *= RecipeData.EXTRA_TIP_AMOUNT
	# Bono por platos especiales (recetas con "tip_chance_bonus"): entero la 1ª
	# vez, y cada repeticion del MISMO plato suma la mitad que la anterior.
	var seen := {}
	for id in eaten_ids:
		var rb: float = RecipeData.get_recipe(id).get("tip_chance_bonus", 0.0)
		if rb <= 0.0:
			continue
		var n: int = seen.get(id, 0)
		tip_chance += rb * pow(0.5, n)
		seen[id] = n + 1
	# "tip_always": los postres SIEMPRE dejan propina (aunque sea 1 doblón).
	# Es lo que compensa que valgan tan poco: el dinero lo dan por el bote, no
	# por el precio.
	if RecipeData.get_recipe(current_id).get("tip_always", false):
		tip_chance = 1.0
	if randf() < tip_chance:
		return maxi(int(round(money_earned * float(rules.pct) * amount_mult)), 1)
	return 0
