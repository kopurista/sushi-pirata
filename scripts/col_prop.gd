extends Node3D
## Vaivén de un adorno del barco (la bandera pirata, el koinobori): el pivote
## gira suave alrededor de su eje, como tela que toma y suelta el viento. Va
## en su propio script porque los adornos se montan por código
## (`ColVisibles`) y un tween en bucle no puede hacer un seno continuo.
class_name ColProp

## Amplitud (grados) y velocidad del vaivén; cada adorno pone las suyas.
var amp := 9.0
var vel := 1.6
var _t := 0.0
var _base := 0.0

## --------------------------------------------------------------- VELETA
##
## UN CALCETÍN DE VIENTO NO PUEDE VOLAR CONTRA EL VIENTO, y el koinobori lo
## hacía la mitad del tiempo. Su cartel mira SIEMPRE a la cámara (billboard de
## eje Y, que es lo que impide que desaparezca de canto cuando el timón gira el
## barco), y eso deja el dibujo clavado respecto a la PANTALLA: la cabeza
## siempre a la izquierda. Con el barco apuntando a la derecha, el pez volaba
## de morro contra el viento que empuja las velas.
##
## Aquí se corrige por donde toca, que es el DIBUJO y no la geometría: se mira
## hacia dónde cae la PROA en pantalla y, si hace falta, se voltea la textura
## para que la cola quede siempre del lado de la proa — o sea, a favor del
## mismo viento que hincha las velas.
##
## `veleta_dir` es la dirección de la proa EN EL ESPACIO DEL BARCO (-X en este
## modelo) y `veleta_mat` el material del cartel. Sin los dos, esto no corre.
var veleta_mat: StandardMaterial3D = null
var veleta_dir := Vector3.ZERO
## La textura viene con la CABEZA a la izquierda (medido sobre el alfa: el
## tercio izquierdo mide 105 px de alto de media y el derecho 68). Así que sin
## voltear, la cola cae a la derecha: correcto solo cuando la proa está a la
## derecha de la pantalla.
var _veleta_flip := 0


func _ready() -> void:
	_base = rotation_degrees.y
	# Cada adorno arranca en un punto distinto del vaivén, o la bandera y el
	# koinobori se mecerían clavados al unísono como un mecanismo.
	_t = fmod(float(get_instance_id()) * 0.37, TAU)


func _process(delta: float) -> void:
	# LA VELETA SE ACTUALIZA AUNQUE LAS ANIMACIONES ESTÉN APAGADAS: no es un
	# adorno que se mueva, es hacia dónde MIRA el dibujo, y con el timón se
	# puede girar el barco con los gráficos al mínimo.
	_orientar_veleta()
	if not GameState.animations_on():
		return
	_t += delta * vel
	rotation_degrees.y = _base + sin(_t) * amp
	rotation_degrees.z = cos(_t * 0.7) * amp * 0.25


func _orientar_veleta() -> void:
	if veleta_mat == null or veleta_dir == Vector3.ZERO:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	# La proa en coordenadas de MUNDO, proyectada sobre el "hacia la derecha"
	# de la cámara: positivo = la proa cae a la derecha de la pantalla.
	var proa := (global_transform.basis * veleta_dir).normalized()
	var a_la_derecha := proa.dot(cam.global_transform.basis.x)
	# Cerca de cero la proa apunta a la cámara (o al contrario) y el volteo no
	# significa nada: se deja como estaba en vez de parpadear entre las dos.
	if absf(a_la_derecha) < 0.08:
		return
	var flip := 1 if a_la_derecha < 0.0 else 0
	if flip == _veleta_flip:
		return
	_veleta_flip = flip
	# El volteo va por UV y no por escala del nodo: con `billboard_keep_scale`
	# puesto, una escala negativa deja el cartel del revés en profundidad.
	veleta_mat.uv1_scale.x = -1.0 if flip == 1 else 1.0
	veleta_mat.uv1_offset.x = 1.0 if flip == 1 else 0.0
