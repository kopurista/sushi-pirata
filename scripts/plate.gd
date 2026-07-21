extends PathFollow2D
## Plato sobre la cinta transportadora. Avanza en bucle hasta que un cliente
## lo coge; si completa MAX_LAPS vueltas sin ser cogido, se desecha.
## La velocidad se multiplica por level.belt_mult (potenciador "Cinta rápida").

signal discarded(recipe_id: String)

const MAX_LAPS := 2

var recipe_id: String = ""
var speed: float = 75.0
var taken: bool = false
var traveled: float = 0.0
var belt_length: float = 0.0
var level_ref: Node = null


func _ready() -> void:
	loop = true
	rotates = false
	var tex_path := "res://assets/dishes/%s.webp" % recipe_id
	if ResourceLoader.exists(tex_path):
		$Sprite.texture = load(tex_path)
	var parent := get_parent()
	if parent is Path2D:
		if parent.curve != null:
			belt_length = parent.curve.get_baked_length()
		level_ref = parent.get_parent()


func _process(delta: float) -> void:
	if taken:
		return
	if level_ref != null and "frozen" in level_ref and level_ref.frozen:
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
