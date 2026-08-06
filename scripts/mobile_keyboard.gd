class_name MobileKeyboard
extends Node
## Saca el TECLADO DEL MÓVIL al tocar un `LineEdit`.
##
## Por qué existe, y por qué no basta con `virtual_keyboard_enabled`:
## en este proyecto la interfaz de Godot NO responde al dedo como al ratón (es
## el mismo motivo por el que existe `touch_scroll.gd`). Se intentó primero
## desde el `gui_input` del propio campo y seguía sin salir el teclado en el
## iPhone, así que aquí se deja de depender de que el evento llegue al campo:
##
##  - Se escucha en **`_input`**, ANTES que la interfaz, y se mira si el toque
##    cae dentro del rectángulo del campo. Si cae, se le da el foco y se pide
##    el teclado a mano. Así da igual quién se trague el evento después.
##  - Se atienden LOS DOS tipos de evento (`ScreenTouch` y `MouseButton`):
##    `emulate_mouse_from_touch` viene activado por defecto, así que un dedo
##    llega como evento de ratón, no como táctil.
##  - La petición va **DIFERIDA un fotograma**. Pedir el teclado en el mismo
##    evento que el foco hacía que el propio `LineEdit`, al reaccionar después,
##    lo cerrara de vuelta.
##  - NO se esconde el teclado en `focus_exited`. Godot ya lo hace solo, y
##    hacerlo aquí lo cerraba en cuanto el foco daba un salto.
##
## Se engancha con `MobileKeyboard.attach(mi_campo)` y ya está. En escritorio
## las llamadas al teclado no hacen nada, así que es inofensivo.

var _edit: LineEdit = null


static func attach(edit: LineEdit) -> MobileKeyboard:
	edit.virtual_keyboard_enabled = true
	# Explícito: sin foco no hay teclado, y un `focus_mode` a NONE heredado de
	# un tema lo dejaría mudo sin dar ningún aviso.
	edit.focus_mode = Control.FOCUS_ALL
	var mk := MobileKeyboard.new()
	mk.name = "MobileKeyboard"
	mk._edit = edit
	edit.add_child(mk)
	return mk


func _input(event: InputEvent) -> void:
	if _edit == null or not _edit.is_visible_in_tree() or not _edit.editable:
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	if not _edit.get_global_rect().has_point(event.position):
		return
	_edit.grab_focus()
	_show.call_deferred()


func _show() -> void:
	if _edit == null or not is_instance_valid(_edit):
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return
	DisplayServer.virtual_keyboard_show(_edit.text, Rect2(),
		DisplayServer.KEYBOARD_TYPE_DEFAULT, _edit.max_length,
		_edit.caret_column, _edit.caret_column)
