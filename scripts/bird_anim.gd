class_name BirdAnim
extends RefCounted
## Animacion procedural de un ave posada (Gigi en el hombro de David).
##
## Un loro posado NO se mueve como un personaje: se queda QUIETO y de pronto
## PEGA UN GIRO de cabeza, rapidisimo, a un sitio que no viene a cuento. Eso es
## lo que hay que imitar, y por eso la cabeza no va con senos como el resto del
## juego: va a SALTOS. Cada cierto rato se sortea una postura nueva, se llega a
## ella en menos de dos decimas y ahi se queda hasta el siguiente golpe. El
## contraste entre el golpe y la quietud es TODO el efecto; con una
## interpolacion suave el bicho parece un peluche meciendose.
##
## El cuerpo, la cola y las alas si van con ondas, que eso si es continuo: el
## ave respira, la cola pesa y las alas se acomodan de vez en cuando.

## Cuanto tarda la cabeza en llegar a la postura nueva. Muy corto a proposito.
const GOLPE := 0.11
## Entre golpe y golpe, en reposo y hablando su dueño (hablando mira mas).
const ESPERA_QUIETO := Vector2(0.9, 2.6)
const ESPERA_HABLA := Vector2(0.45, 1.4)
## Hasta donde llega cada golpe (grados).
const YAW_MAX := 46.0
const PITCH_MAX := 20.0
const ROLL_MAX := 26.0
## De vez en cuando LADEA la cabeza en vez de girarla: es el gesto que mas se
## lee como "pajaro mirando algo".
const PROB_LADEO := 0.35
## Sacudida de alas: cada cuanto y cuanto dura.
const ALA_CADA := Vector2(3.5, 9.0)
const ALA_DURA := 0.42

var _skel: Skeleton3D
var _idx := {}
var _t := 0.0
var _rng := RandomNumberGenerator.new()
## Postura de la cabeza: de donde viene, a donde va y cuando cambia.
var _desde := Vector3.ZERO
var _hasta := Vector3.ZERO
var _golpe_en := 0.0
var _cambia_en := 0.0
var _ala_en := 0.0
var _ala_hasta := -1.0


func _init(skeleton: Skeleton3D, semilla := 0) -> void:
	_skel = skeleton
	for i in _skel.get_bone_count():
		_idx[_skel.get_bone_name(i)] = i
	_rng.seed = semilla if semilla != 0 else randi()
	_cambia_en = _rng.randf_range(0.3, 1.0)
	_ala_en = _rng.randf_range(ALA_CADA.x, ALA_CADA.y)


func tiene_huesos() -> bool:
	return _idx.has("Cabeza") and _idx.has("Cuerpo")


## `hablando` (0..1) es cuanto esta hablando su dueño: con voz al lado, el loro
## mira mas veces y se mueve mas.
func tick(delta: float, hablando := 0.0) -> void:
	_t += delta
	_reset()
	if _t >= _cambia_en:
		_desde = _postura_ahora()
		_hasta = _sortear()
		_golpe_en = _t + GOLPE
		var e := ESPERA_HABLA if hablando > 0.5 else ESPERA_QUIETO
		_cambia_en = _t + _rng.randf_range(e.x, e.y)
	var cab := _postura_ahora()
	# temblor minimo constante: ni posado esta del todo quieto
	cab += Vector3(sin(_t * 11.3) * 0.5, sin(_t * 9.1) * 0.7, sin(_t * 13.7) * 0.4)
	_rot("Cabeza", cab)

	var respira := sin(_t * 2.1)
	_rot("Cuerpo", Vector3(respira * 1.6, sin(_t * 1.3) * 2.2, sin(_t * 1.7) * 2.6) * (0.6 + hablando * 0.8))
	# la cola PESA: sigue a la cabeza con retardo y al reves
	_rot("Cola", Vector3(sin(_t * 1.9 + 1.2) * 4.0, -cab.y * 0.22, -cab.z * 0.18))

	if _t >= _ala_en:
		_ala_hasta = _t + ALA_DURA
		_ala_en = _t + _rng.randf_range(ALA_CADA.x, ALA_CADA.y)
	if _t < _ala_hasta:
		var u: float = 1.0 - (_ala_hasta - _t) / ALA_DURA
		var abre := sin(u * PI) * 26.0
		_rot("L_Ala", Vector3(0.0, 0.0, -abre))
		_rot("R_Ala", Vector3(0.0, 0.0, abre))


func _sortear() -> Vector3:
	var yaw := _rng.randf_range(-YAW_MAX, YAW_MAX)
	var pitch := _rng.randf_range(-PITCH_MAX, PITCH_MAX * 0.6)
	var roll := 0.0
	if _rng.randf() < PROB_LADEO:
		roll = _rng.randf_range(ROLL_MAX * 0.5, ROLL_MAX) * (1.0 if _rng.randf() < 0.5 else -1.0)
		yaw *= 0.5
	return Vector3(pitch, yaw, roll)


func _postura_ahora() -> Vector3:
	if _t >= _golpe_en:
		return _hasta
	var u: float = 1.0 - (_golpe_en - _t) / GOLPE
	# el golpe frena al final (no rebota: un pajaro clava la mirada)
	return _desde.lerp(_hasta, u * u * (3.0 - 2.0 * u))


func _reset() -> void:
	for n in _idx:
		_skel.set_bone_pose_rotation(_idx[n], Quaternion.IDENTITY)


func _rot(hueso: String, grados: Vector3) -> void:
	if not _idx.has(hueso):
		return
	var i: int = _idx[hueso]
	var q := Quaternion.from_euler(Vector3(
		deg_to_rad(grados.x), deg_to_rad(grados.y), deg_to_rad(grados.z)))
	_skel.set_bone_pose_rotation(i, _skel.get_bone_rest(i).basis.get_rotation_quaternion() * q)
