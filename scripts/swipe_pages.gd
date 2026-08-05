class_name SwipePages
extends Node
## Pasar página DESLIZANDO el dedo sobre una zona (los libros del inventario).
##
## De derecha a izquierda = página siguiente; al revés, la anterior, como en un
## libro de verdad. Se engancha con `SwipePages.attach(zona, callable)`, donde
## el callable recibe +1 o -1.
##
## Igual que `TouchScroll`, escucha en `_input` (antes que la interfaz) para
## poder tragarse el toque de soltar cuando ha habido deslizamiento: si no, al
## pasar página con el dedo por encima de una receta se abría su ficha.

## Recorrido horizontal mínimo para que cuente como pasar página.
const THRESHOLD := 70.0
## El gesto tiene que ser claramente horizontal: si baja más de lo que avanza,
## es un scroll y no un pase de página.
const H_RATIO := 1.2

var _area: Control = null
var _turn: Callable = Callable()
var _touching := false
var _start := Vector2.ZERO
var _moved := Vector2.ZERO


## `host` es de quién cuelga el nodo; por defecto, la propia zona. Hace falta
## cuando esa zona se vacía al repintar (el recetario borra a TODOS sus hijos
## al cambiar de página, y se llevaba por delante este nodo).
static func attach(area: Control, turn: Callable, host: Node = null) -> SwipePages:
	var sp := SwipePages.new()
	sp.name = "SwipePages"
	sp._area = area
	sp._turn = turn
	(host if host != null else area).add_child(sp)
	return sp


func _input(event: InputEvent) -> void:
	if _area == null or not _area.is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touching = _area.get_global_rect().has_point(event.position)
			_start = event.position
			_moved = Vector2.ZERO
		elif _touching:
			_touching = false
			var dx := _moved.x
			if absf(dx) >= THRESHOLD and absf(dx) > absf(_moved.y) * H_RATIO:
				# Arrastrar hacia la IZQUIERDA trae la página siguiente.
				_turn.call(-1 if dx > 0.0 else 1)
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _touching:
		_moved += event.relative
