extends PathFollow3D
## Plato 3D sobre la cinta transportadora (port de plate.gd). Avanza en bucle
## por el Path3D del circuito hasta que un cliente lo coge; si completa
## MAX_LAPS vueltas sin ser cogido, se desecha. No usa fisica: los clientes
## sondean el grupo "plates" y comparan distancias (ver client3d.gd).
## La velocidad se multiplica por level.belt_mult (potenciador "Cinta rápida").

signal discarded(recipe_id: String)

## UNA vuelta: el plato nace en la esquina inferior del circuito (donde está la
## basura) y si vuelve a pasar por ahí sin que nadie lo haya cogido, se tira.
const MAX_LAPS := 1
## Cuánto se desplaza el plato hacia la basura al caer (diagonal hacia fuera y
## abajo). Con ROTATION_NONE el sistema local del PathFollow es el del mundo.
const CAIDA := Vector3(0.62, -0.34, 0.62)
## Huella horizontal del modelo del plato (la tabla de madera), igual que en
## el resto de la cinta.
const DISH_FOOT := 0.62

var recipe_id: String = ""
## Precio de ESTE plato concreto cuando no vale el de la receta (el barco
## combinado se cotiza según los platos con los que se montó). 0 = usar receta.
var price_override: int = 0
## Extras que lleva ESTE plato (jengibre / wasabi / soja).
var extras: Array = []
## Nivel de ESTE plato cuando no vale el de la receta (el barco combinado se
## cataloga por lo que lleva dentro). 0 = usar el de la receta.
var level_override: int = 0
## Tiempo de comida propio (0 = el de la receta). El barco tarda según cuántos
## platos lleve dentro, así que no vale el de su ficha.
var eat_mult_override: float = 0.0
## Personaje al que está RESERVADO este plato ("" = para quien lo pille). Lo usa
## el tsuke don que David regala en el nivel 5: mientras corre el guion es de
## Pablo el Rubio y nadie más lo toca.
var only_who: String = ""
## Plato RESERVADO a un TIPO de cliente (E/A/G) mientras corre el guion del
## puerto (`exclusive_types`). Lo necesita el nivel 7: su nigiri de atun es el
## regalo para EL pirata, y con 4 grumetes delante el dado de coger (0.20 cada
## uno) se lo comia antes de llegar el 59% de las veces, asi que la leccion se
## perdia. Es hermano de `only_who`, pero por tipo en vez de por personaje.
var only_type: String = ""
var speed: float = 1.25   ## por defecto; el nivel lo fija con level3d.PLATE_SPEED
var taken: bool = false
var traveled: float = 0.0
var belt_length: float = 0.0
var level_ref: Node = null
## Vueltas que aguanta ESTE plato antes de caer al cubo. La maestría "Segunda
## vuelta" lo sube a 2 o 3; sin ella, MAX_LAPS de siempre.
var max_laps: int = MAX_LAPS
## Con el rango IV de esa maestría, cada vuelta NUEVA borra los rechazos del
## plato: todos los clientes vuelven a tener ocasión de cogerlo (el mismo
## olvido que regala el potenciador "Nada se tira").
var forget_each_lap := false
## Plato marcado por "Golpe de suerte": sube un punto extra de multiplicador
## al cliente que lo coja (lo lee client3d._scan_belt).
var variety_bonus := false
## Raciones que le quedan al plato ("servings" de la receta, el takoyaki):
## cada cliente que lo coge come UNA, y solo la última se lo lleva de la cinta.
var servings: int = 1
## Vueltas ya completadas (para saber cuándo toca el olvido o el cubo).
var _laps_done := 0
## Pasadas por el punto de la papelera (el plato nace ahí; nacer no cuenta).
var _pases := 0
## Progreso del punto de la papelera sobre el camino (donde nació el plato).
var _papelera_progress := -1.0


## ¿El tramo `desde` → `hasta` cruza el punto de la papelera? Se mira en
## coordenadas RELATIVAS a ese punto: al avanzar, la posición relativa solo
## puede dar un salto grande envolviéndose (de casi L a casi 0, o al revés
## marchando atrás), y ese salto ES el cruce. Robusto con pasos pequeños y con
## los dos sentidos de la cinta.
func _cruza_papelera(desde: float, hasta: float) -> bool:
	if _papelera_progress < 0.0:
		_papelera_progress = desde
		return false
	var r0 := fposmod(desde - _papelera_progress, belt_length)
	var r1 := fposmod(hasta - _papelera_progress, belt_length)
	if hasta > desde:
		return r1 < r0 - belt_length * 0.5
	return r1 > r0 + belt_length * 0.5


func _ready() -> void:
	add_to_group("plates")
	loop = true
	rotation_mode = PathFollow3D.ROTATION_NONE
	var parent := get_parent()
	if parent is Path3D:
		if parent.curve != null:
			belt_length = parent.curve.get_baked_length()
		level_ref = parent.get_parent()
	# "model" permite que una variante reaproveche la malla de otra receta (la
	# tempura pasada usa la de la tempura buena, solo que tostada con "tint").
	var data := RecipeData.get_recipe(recipe_id)
	servings = int(data.get("servings", 1))
	var model_id: String = str(data.get("model", recipe_id))
	var path := "res://assets/models/%s.glb" % model_id
	if ResourceLoader.exists(path):
		_spawn_dish(load(path), data.get("tint", Color.WHITE))


## Instancia el modelo normalizado por su HUELLA horizontal (la tabla), no por
## altura: un sashimi plano y una sopa alta deben ocupar la misma tabla.
func _spawn_dish(scene: PackedScene, tint: Color = Color.WHITE) -> void:
	var inst: Node3D = scene.instantiate()
	add_child(inst)
	# Tinte de variante: se aplica como sobreescritura para no tocar el
	# material compartido del .glb (lo usan todos los platos de ese tipo).
	if tint != Color.WHITE:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.roughness = 1.0
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_overlay = mat
	var aabb := _merged_aabb(inst)
	var foot := maxf(maxf(aabb.size.x, aabb.size.z), 0.0001)
	var s := DISH_FOOT / foot
	inst.scale = Vector3(s, s, s)
	inst.position = -Vector3(
		aabb.position.x + aabb.size.x * 0.5,
		aabb.position.y,
		aabb.position.z + aabb.size.z * 0.5) * s


func _merged_aabb(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = m.transform * m.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


func _process(delta: float) -> void:
	if taken:
		return
	# Parado durante la congelacion ("Tiempo de preparacion extra") y al
	# terminar el nivel (los platos se quedan quietos en la cinta).
	if level_ref != null:
		if "frozen" in level_ref and level_ref.frozen:
			return
		if "ended" in level_ref and level_ref.ended:
			return
	var mult := 1.0
	if level_ref != null and "belt_mult" in level_ref:
		mult = level_ref.belt_mult
	# EL VIENTO puede invertir la cinta: `belt_dir` es el sentido con su
	# transición (pasa por 0 en cada giro, así que la cinta se frena de verdad).
	if level_ref != null and "belt_dir" in level_ref:
		mult *= level_ref.belt_dir
	var step := speed * mult * delta
	var antes := progress
	progress += step
	traveled += absf(step)
	# EL CUBO CUENTA PASADAS POR LA PAPELERA, no vueltas (rediseño del viento,
	# pedido por el usuario): el plato nace EN el punto del cubo, puede pasar
	# por delante UNA vez, y a la SEGUNDA pasada cae — da igual el sentido en
	# que llegue. La habilidad de las vueltas extra suma pasadas perdonadas.
	# Con la cinta invertible las vueltas dejaron de existir como concepto: un
	# plato puede ir y volver sin completar ninguna.
	if belt_length > 0.0 and absf(step) > 0.0 and _cruza_papelera(antes, progress):
		_pases += 1
		if _pases <= max_laps:
			# Pasada perdonada. "Segunda vuelta" (rango IV): borra los rechazos
			# al pasar, o el plato seguiría dando pasadas sin que nadie pudiera
			# cogerlo (el dado se tira UNA vez por cliente y plato).
			if forget_each_lap and level_ref != null \
					and level_ref.has_method("_forget_declined"):
				level_ref._forget_declined(get_instance_id())
			return
		# "Nada se tira" (potenciador): la cuenta vuelve a cero Y se le olvida
		# a todo el mundo que lo dejó pasar.
		if level_ref != null and "no_waste_timer" in level_ref \
				and level_ref.no_waste_timer > 0.0:
			_pases = 0
			level_ref._forget_declined(get_instance_id())
		else:
			_tirar_a_la_basura()


## Un cliente se lleva UNA ración. Con raciones de sobra el plato SIGUE en la
## cinta (menguado, para que se vea que está empezado) y devuelve true; con la
## última el cliente se lo lleva entero y devuelve false. Los platos normales
## (servings 1) pasan siempre por la segunda rama: es el "cogerlo" de siempre.
func consume_serving() -> bool:
	servings -= 1
	if servings > 0:
		_menguar()
		return true
	taken = true
	queue_free()
	return false


## El plato empezado: si existe el modelo "<id>_medio.glb" se cambia a él; si
## no, el de siempre se encoge, que desde esta cámara ya se lee como
## "queda menos".
func _menguar() -> void:
	var dish: Node3D = null
	for c in get_children():
		if c is Node3D:
			dish = c
			break
	var path := "res://assets/models/%s_medio.glb" % recipe_id
	if ResourceLoader.exists(path):
		if dish != null:
			dish.queue_free()
		_spawn_dish(load(path))
	elif dish != null:
		dish.scale *= 0.72


## El plato cae al cubo de la esquina en vez de desaparecer de golpe: se para,
## se vuelca hacia fuera y hacia abajo, y se apaga dentro.
func _tirar_a_la_basura() -> void:
	taken = true
	discarded.emit(recipe_id)
	var dish: Node3D = null
	for c in get_children():
		if c is Node3D:
			dish = c
			break
	if dish == null:
		queue_free()
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dish, "position", dish.position + CAIDA, 0.42) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(dish, "rotation_degrees:x", 62.0, 0.42)
	tw.tween_property(dish, "scale", dish.scale * 0.55, 0.42) \
			.set_delay(0.18)
	tw.chain().tween_callback(queue_free)
