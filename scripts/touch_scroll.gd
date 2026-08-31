class_name TouchScroll
extends Node
## Arrastre con el DEDO (con inercia) para un `ScrollContainer`.
##
## Hace falta porque el `ScrollContainer` de Godot NO se arrastra con eventos
## táctiles en este proyecto: se comprobó inyectando `InputEventScreenTouch` +
## `ScreenDrag` sobre el selector de recetas y `scroll_vertical` se quedaba en 0
## con 1.842 px de contenido. Con `emulate_touch_from_mouse` activado el ratón
## sí lo mueve, pero el dedo en el móvil no, que es donde se juega.
##
## Se engancha con `TouchScroll.attach(mi_scroll)` y ya está.
##
## Detalles que importan:
##  - Los eventos se cogen en `_input`, ANTES que la interfaz, para poder
##    tragarse el toque de soltar cuando ha habido arrastre: si no, al deslizar
##    por encima de una tarjeta de receta se acababa seleccionando.
##  - Hasta `DEADZONE` px no se considera arrastre, así que un toque limpio
##    sigue llegando entero al botón que haya debajo.
##  - Al soltar, la velocidad sigue corriendo y se apaga sola (`FRICTION`):
##    un tirón fuerte recorre más pantalla que uno suave.

## Píxeles que hay que mover el dedo antes de que cuente como arrastre.
const DEADZONE := 12.0
## Fracción de la velocidad que queda tras un segundo (cuanto más bajo, antes
## se para). 0.06 da un frenado suave de algo menos de un segundo.
const FRICTION := 0.06
## Por debajo de esta velocidad (px/s) se para del todo.
const STOP_SPEED := 12.0
## Peso del último movimiento en la velocidad: suaviza los tirones del dedo.
const VEL_SMOOTH := 0.75

var _scroll: ScrollContainer = null
## En horizontal el arrastre mueve `scroll_horizontal` (la vitrina de
## trofeos); lo de siempre es vertical.
var _horizontal := false
var _touching := false
var _dragging := false
var _start := Vector2.ZERO
var _velocity := 0.0


## Le da arrastre táctil e inercia a este ScrollContainer.
static func attach(scroll: ScrollContainer, horizontal := false) -> TouchScroll:
	var ts := TouchScroll.new()
	ts.name = "TouchScroll"
	ts._scroll = scroll
	ts._horizontal = horizontal
	scroll.add_child(ts)
	return ts


func _input(event: InputEvent) -> void:
	if _scroll == null or not _scroll.is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			# Solo manda el dedo que empieza DENTRO de la zona de scroll.
			if not _scroll.get_global_rect().has_point(event.position):
				return
			_touching = true
			_dragging = false
			_start = event.position
			_velocity = 0.0
		elif _touching:
			_touching = false
			# Si hubo arrastre, este toque no es para nadie más: se traga para
			# que no dispare el botón que quedara debajo del dedo.
			if _dragging:
				get_viewport().set_input_as_handled()
			_dragging = false
	elif event is InputEventScreenDrag and _touching:
		if not _dragging and _start.distance_to(event.position) < DEADZONE:
			return
		_dragging = true
		var paso: float = -event.relative.x if _horizontal else -event.relative.y
		_move(paso)
		var dt := maxf(get_process_delta_time(), 0.0001)
		_velocity = lerpf(_velocity, paso / dt, VEL_SMOOTH)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Con el dedo apoyado manda el dedo, pero la velocidad NO se toca: es la
	# que hay que conservar para el impulso al soltar (borrarla aquí dejaba la
	# inercia siempre a cero, que es justo lo que pasaba).
	if _dragging:
		return
	if absf(_velocity) < STOP_SPEED:
		_velocity = 0.0
		return
	_move(_velocity * delta)
	_velocity *= pow(FRICTION, delta)


## Mueve el scroll y frena la inercia al llegar a un extremo.
func _move(amount: float) -> void:
	if _horizontal:
		var antes := _scroll.scroll_horizontal
		_scroll.scroll_horizontal = int(round(antes + amount))
		if _scroll.scroll_horizontal == antes and absf(amount) >= 1.0:
			_velocity = 0.0
		return
	var before := _scroll.scroll_vertical
	_scroll.scroll_vertical = int(round(before + amount))
	if _scroll.scroll_vertical == before and absf(amount) >= 1.0:
		_velocity = 0.0
