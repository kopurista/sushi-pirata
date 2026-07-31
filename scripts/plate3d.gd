extends PathFollow3D
## Plato 3D sobre la cinta transportadora (port de plate.gd). Avanza en bucle
## por el Path3D del circuito hasta que un cliente lo coge; si completa
## MAX_LAPS vueltas sin ser cogido, se desecha. No usa fisica: los clientes
## sondean el grupo "plates" y comparan distancias (ver client3d.gd).
## La velocidad se multiplica por level.belt_mult (potenciador "Cinta rápida").

signal discarded(recipe_id: String)

const MAX_LAPS := 2
## Huella horizontal del modelo del plato (la tabla de madera), igual que en
## el resto de la cinta.
const DISH_FOOT := 0.62

var recipe_id: String = ""
var speed: float = 0.9
var taken: bool = false
var traveled: float = 0.0
var belt_length: float = 0.0
var level_ref: Node = null


func _ready() -> void:
	add_to_group("plates")
	loop = true
	rotation_mode = PathFollow3D.ROTATION_NONE
	var parent := get_parent()
	if parent is Path3D:
		if parent.curve != null:
			belt_length = parent.curve.get_baked_length()
		level_ref = parent.get_parent()
	var path := "res://assets/models/%s.glb" % recipe_id
	if ResourceLoader.exists(path):
		_spawn_dish(load(path))


## Instancia el modelo normalizado por su HUELLA horizontal (la tabla), no por
## altura: un sashimi plano y una sopa alta deben ocupar la misma tabla.
func _spawn_dish(scene: PackedScene) -> void:
	var inst: Node3D = scene.instantiate()
	add_child(inst)
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
	var step := speed * mult * delta
	progress += step
	traveled += step
	if belt_length > 0.0 and traveled >= MAX_LAPS * belt_length:
		discarded.emit(recipe_id)
		queue_free()
