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
## El cartel al que se le voltea la textura, su media anchura, y los HILOS que
## lo atan al barco. La boca del pez cae en el canto que mire al mástil, y ese
## canto cambia de lado con el volteo — así que los hilos NO pueden ser
## geometría fija: se redibujan cada fotograma desde el anclaje hasta la boca.
var veleta_cara: MeshInstance3D = null
var veleta_semi := 0.0
var hilos: MeshInstance3D = null
var hilos_ancla := Vector3.ZERO      ## en coordenadas del BARCO
const HILOS_N := 3
const HILOS_ABRE := 0.22             ## cuánto se abre el abanico en la boca
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
	if flip != _veleta_flip:
		_veleta_flip = flip
		# El volteo va por UV y no por escala del nodo: con
		# `billboard_keep_scale` puesto, una escala negativa deja el cartel del
		# revés en profundidad.
		veleta_mat.uv1_scale.x = -1.0 if flip == 1 else 1.0
		veleta_mat.uv1_offset.x = 1.0 if flip == 1 else 0.0
	_tender_hilos(cam)


## Los HILOS de la boca al barco. Se redibujan por fotograma porque sus DOS
## extremos se mueven: el anclaje va en el barco (que cabecea y gira con el
## timón) y la boca está en un cartel que mira siempre a la cámara, así que
## cambia de canto cada vez que la proa cruza el eje de la pantalla.
func _tender_hilos(cam: Camera3D) -> void:
	if hilos == null or veleta_cara == null:
		return
	var im: ImmediateMesh = hilos.mesh as ImmediateMesh
	if im == null:
		return
	# La boca cae en el canto del cartel que MIRA AL MÁSTIL. Como el volteo ya
	# deja la cola del lado de la proa, la boca es siempre el canto contrario.
	var derecha := cam.global_transform.basis.x.normalized()
	var signo := 1.0 if _veleta_flip == 1 else -1.0
	var boca := veleta_cara.global_position + derecha * veleta_semi * signo
	# Los dos extremos, al espacio LOCAL de los hilos (que cuelgan del barco).
	var inv := hilos.global_transform.affine_inverse()
	var a := inv * (hilos.get_parent_node_3d().global_transform * hilos_ancla)
	var b := inv * boca
	# El abanico se abre en la BOCA (que es un aro) y se junta en el anclaje,
	# como los tres cabos de un koinobori de verdad.
	var lado := (b - a).cross(Vector3.UP)
	if lado.length() < 0.0001:
		lado = derecha
	lado = lado.normalized() * (a.distance_to(b) * HILOS_ABRE)
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in HILOS_N:
		var f := (float(i) / float(maxi(HILOS_N - 1, 1))) - 0.5
		im.surface_add_vertex(a)
		im.surface_add_vertex(b + lado * f + Vector3.UP * (f * 0.35 * lado.length()))
	im.surface_end()
