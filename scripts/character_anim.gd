class_name CharacterAnim
extends RefCounted
## Animacion procedural por huesos para los personajes low poly del juego.
##
## POR QUE NO USAMOS LOS CLIPS DE IA: se midieron 32 clips de "andar" generados
## con Ludo (animate3DModel) usando tools/gait_check.py, que hace cinematica
## directa y compara las trayectorias de los dos pies. En TODOS las piernas
## salian en fase (correlacion hasta +1.00: ambas piernas haciendo lo mismo a
## la vez) en vez de alternarse, con clips de 1.25 s que ademas no cierran
## ciclo. Aqui la alternancia es exacta POR CONSTRUCCION: la pierna derecha
## recibe la misma onda que la izquierda desfasada media vuelta, asi que la
## correlacion entre pies es -1 por definicion. Ademas cicla perfecto, se
## ajusta a la velocidad real del personaje y no cuesta creditos.
##
## Necesita un rig "humanoid" de Ludo (huesos con nombre anatomico: Pelvis,
## L_Hip, R_Knee, L_Shoulder...). Los huesos que no existan se ignoran, asi
## que el mismo codigo vale para rigs incompletos.
##
## Todas las rotaciones son sobre el eje X local de cada hueso, que en estos
## rigs coincide con el eje lateral del esqueleto (bases identidad): rotar en
## X es cabecear hacia delante y hacia atras, que es lo que hacen piernas y
## brazos al andar.
##
## CONVENIO DE SIGNOS (importante, es facil equivocarse y flexionar al reves):
## el personaje MIRA HACIA +Z (su lado izquierdo, L_Hip, cae en +X). Como una
## rotacion positiva en X inclina el eje -Y hacia -Z, un angulo POSITIVO lleva
## el miembro HACIA ATRAS y uno negativo hacia delante. Por tanto:
##   - cadera: angulo negativo = pierna adelante,
##   - rodilla: angulo POSITIVO = flexion natural (el talon sube hacia atras);
##     en negativo la rodilla se dobla al reves,
##   - codo: angulo NEGATIVO = flexion natural (la mano sube hacia delante).

# --- Ciclo de marcha ---
const WALK_PERIOD := 0.9      ## segundos por ciclo completo (dos pasos)
const HIP_SWING := 26.0       ## amplitud del balanceo de cadera, grados
const KNEE_BEND := 52.0       ## flexion maxima de rodilla en la fase de vuelo
const KNEE_PEAK := TAU * 0.875 ## fase de flexion maxima (justo tras despegar)
const ANKLE_KEEP := 0.35      ## cuanto contrarresta el tobillo para no arrastrar
const ARM_SWING := 20.0       ## balanceo de hombro (opuesto a su pierna)
const ELBOW_BEND := 14.0      ## flexion fija de codo, da naturalidad
const BODY_BOB := 0.035       ## subida y bajada del cuerpo, en unidades de mundo
const TORSO_TWIST := 5.0      ## contragiro del tronco

# --- Reposo de pie ---
const IDLE_PERIOD := 3.4
const IDLE_BREATH := 2.2

var _skel: Skeleton3D
var _idx := {}                ## nombre de hueso -> indice, solo los existentes


func _init(skeleton: Skeleton3D) -> void:
	_skel = skeleton
	for i in _skel.get_bone_count():
		_idx[_skel.get_bone_name(i)] = i


func has_humanoid_bones() -> bool:
	return _idx.has("L_Hip") and _idx.has("R_Hip")


## Ciclo de marcha. `t` es tiempo en segundos; el ciclo se repite solo.
func walk(t: float) -> void:
	var phase := fmod(t, WALK_PERIOD) / WALK_PERIOD * TAU
	_leg("L", phase)
	_leg("R", phase + PI)
	# El brazo acompaña a la pierna CONTRARIA, como en la marcha humana.
	_arm("L", phase + PI)
	_arm("R", phase)
	# El tronco contragira respecto a las piernas.
	_pitch("Spine1", 3.0)
	_yaw("Spine2", sin(phase) * TORSO_TWIST * 0.5)
	_yaw("Neck", -sin(phase) * TORSO_TWIST * 0.4)


## Desplazamiento vertical del cuerpo durante la marcha: el cuerpo baja cuando
## las piernas estan abiertas y sube al pasar una junto a la otra (dos rebotes
## por ciclo). Lo aplica quien llama, sobre el pivote del personaje.
func walk_bob(t: float) -> float:
	var phase := fmod(t, WALK_PERIOD) / WALK_PERIOD * TAU
	return -absf(sin(phase)) * BODY_BOB


## Reposo de pie: respiracion lenta, sin desplazar los pies.
func idle(t: float) -> void:
	var breath := sin(t / IDLE_PERIOD * TAU)
	_pitch("Spine1", 2.0 + breath * IDLE_BREATH * 0.5)
	_pitch("Spine2", breath * IDLE_BREATH * 0.3)
	_pitch("Neck", -breath * IDLE_BREATH * 0.4)
	_pitch("L_Shoulder", breath * 1.5)
	_pitch("R_Shoulder", breath * 1.5)
	_pitch("L_Elbow", -ELBOW_BEND * 0.6)
	_pitch("R_Elbow", -ELBOW_BEND * 0.6)


## Devuelve todos los huesos a su pose de reposo.
func reset() -> void:
	for name in _idx:
		_skel.reset_bone_pose(_idx[name])


# ------------------------------------------------------------------ internos

## Una pierna completa. `phase` = PI/2 es la zancada maxima hacia delante y
## 3*PI/2 el despegue del pie hacia atras.
func _leg(side: String, phase: float) -> void:
	# Negativo = pierna hacia delante (ver convenio de signos arriba).
	var hip := -HIP_SWING * sin(phase)
	# La rodilla solo flexiona en la fase de VUELO: media onda centrada justo
	# despues de despegar el pie. Positiva, que es la flexion natural; en la
	# fase de apoyo queda en cero y la pierna va recta.
	var knee: float = KNEE_BEND * maxf(0.0, cos(phase - KNEE_PEAK))
	_pitch("%s_Hip" % side, hip)
	_pitch("%s_Knee" % side, knee)
	# El tobillo contrarresta a cadera y rodilla para que la planta no gire
	# de mas y el pie caiga plano.
	_pitch("%s_Ankle" % side, -(hip + knee) * ANKLE_KEEP)


func _arm(side: String, phase: float) -> void:
	# Mismo convenio que la cadera: negativo = brazo hacia delante.
	_pitch("%s_Shoulder" % side, -ARM_SWING * sin(phase))
	# El codo siempre algo flexionado (negativo), un poco mas al ir el brazo
	# hacia delante.
	_pitch("%s_Elbow" % side, -ELBOW_BEND - maxf(0.0, sin(phase)) * ELBOW_BEND)


func _pitch(bone: String, deg: float) -> void:
	_rotate(bone, Vector3(1, 0, 0), deg)


func _yaw(bone: String, deg: float) -> void:
	_rotate(bone, Vector3(0, 1, 0), deg)


func _rotate(bone: String, axis: Vector3, deg: float) -> void:
	if not _idx.has(bone):
		return
	var i: int = _idx[bone]
	var rest := _skel.get_bone_rest(i).basis.get_rotation_quaternion()
	_skel.set_bone_pose_rotation(i, rest * Quaternion(axis, deg_to_rad(deg)))
