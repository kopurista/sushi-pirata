class_name CharacterAnim
extends RefCounted
## Animacion procedural por huesos para los personajes low poly del juego.
##
## POR QUE NO USAMOS LOS CLIPS DE IA: se midieron 32 clips de "andar" generados
## con Ludo (animate3DModel) usando tools/gait_check.py, que hace cinematica
## directa y compara las trayectorias de los dos pies. En TODOS las piernas
## salian en fase (correlacion hasta +1.00: ambas piernas haciendo lo mismo a
## la vez) en vez de alternarse, con clips de 1.25 s que ademas no cierran
## ciclo. Aqui la alternancia es exacta POR CONSTRUCCION y ademas cicla
## perfecto, se ajusta al personaje y no cuesta creditos.
##
## COMO SE MUEVE (importante): NO se balancean las caderas con un seno y luego
## se arrastra el cuerpo a una velocidad inventada; asi el pie apoyado nunca
## queda quieto y siempre resbala. Aqui es al reves, como al andar de verdad:
## primero se decide DONDE VA EL PIE —clavado en el suelo mientras pisa,
## describiendo un arco por el aire mientras vuela— y las piernas se resuelven
## por cinematica inversa para alcanzarlo. El cuerpo avanza exactamente lo que
## el pie apoyado empuja hacia atras, asi que el patinaje es CERO por
## definicion y el movimiento nace de los pies, no de un empujon externo.
##
## Necesita un rig "humanoid" de Ludo (huesos con nombre anatomico: Pelvis,
## L_Hip, R_Knee, L_Shoulder...). Los huesos que no existan se ignoran, asi
## que el mismo codigo vale para rigs incompletos.
##
## CONVENIO DE SIGNOS (es facil equivocarse y flexionar al reves): el personaje
## MIRA HACIA +Z (su lado izquierdo, L_Hip, cae en +X) y las bases de los
## huesos son identidad, asi que rotar en X local es cabecear. Como una
## rotacion positiva en X inclina el eje -Y hacia -Z, un angulo POSITIVO lleva
## el miembro HACIA ATRAS: cadera negativa = pierna adelante, rodilla positiva
## = flexion natural, codo negativo = flexion natural.

# --- Ciclo de marcha ---
const WALK_PERIOD := 0.92     ## segundos por ciclo completo (dos pasos)
const STRIDE := 0.30          ## lo que recorre el pie apoyado, unidades del rig
const STANCE_FRAC := 0.55     ## parte del ciclo con el pie en el suelo
const FOOT_LIFT := 0.055      ## altura del pie al pasar por el aire
## Cuanto baja el cuerpo con las piernas abiertas. Ademas de dar vida, es lo
## que permite a la pierna ALCANZAR el suelo en la zancada abierta: si se sube
## STRIDE hay que subir esto, o la pierna se queda corta y el pie patina.
const BODY_BOB := 0.022       ## sube y baja del cuerpo, unidades del rig
const ARM_SWING := 14.0       ## balanceo de hombro (opuesto a su pierna)
const ELBOW_BEND := 14.0      ## flexion fija de codo, da naturalidad
const TORSO_TWIST := 5.0      ## contragiro del tronco
## Movimiento de cadera: gira acompañando a la pierna que avanza, cae un poco
## del lado de la pierna que va en el aire y el cuerpo se carga sobre la que
## apoya. Son los tres gestos que separan un andar de un deslizar.
const PELVIS_YAW := 4.0
const PELVIS_ROLL := 1.8
const PELVIS_SWAY := 0.003

# --- Reposo de pie ---
const IDLE_PERIOD := 3.4
const IDLE_BREATH := 2.2

var _skel: Skeleton3D
var _idx := {}                ## nombre de hueso -> indice, solo los existentes
var _legs := {}               ## "L"/"R" -> geometria de reposo de esa pierna


func _init(skeleton: Skeleton3D) -> void:
	_skel = skeleton
	for i in _skel.get_bone_count():
		_idx[_skel.get_bone_name(i)] = i
	for side in ["L", "R"]:
		_cache_leg(side)


func has_humanoid_bones() -> bool:
	return _legs.has("L") and _legs.has("R")


## Ciclo de marcha. `t` es tiempo en segundos; el ciclo se repite solo.
func walk(t: float) -> void:
	var cycle := fmod(t / WALK_PERIOD, 1.0)
	var bob := _bob_rig(cycle)
	# Las dos piernas hacen lo mismo con media vuelta de diferencia.
	_leg(&"L", cycle, bob)
	_leg(&"R", fmod(cycle + 0.5, 1.0), bob)
	# El brazo acompaña a la pierna CONTRARIA, como en la marcha humana.
	var phase := cycle * TAU
	_arm("L", phase + PI)
	_arm("R", phase)
	_pelvis(phase)
	# El tronco contragira respecto a la cadera, para que los hombros queden
	# mirando al frente en vez de irse con ella.
	_pitch("Spine1", 3.0)
	_yaw("Spine2", -sin(phase) * (PELVIS_YAW * 0.8))
	_yaw("Neck", sin(phase) * TORSO_TWIST * 0.3)


## Desplazamiento vertical del cuerpo durante la marcha, en unidades de mundo.
## Lo aplica quien llama, sobre el pivote del personaje.
func walk_bob(t: float, model_scale: float) -> float:
	return _bob_rig(fmod(t / WALK_PERIOD, 1.0)) * model_scale


## Velocidad de avance en unidades de mundo por segundo. Sale del propio paso:
## el pie apoyado recorre STRIDE mientras dura el apoyo, asi que el cuerpo tiene
## que avanzar exactamente eso en ese tiempo. Con esta velocidad el pie que pisa
## queda CLAVADO en el suelo; con cualquier otra, resbala.
func ground_speed(model_scale: float) -> float:
	return STRIDE * model_scale / (STANCE_FRAC * WALK_PERIOD)


## Distancia recorrida desde t=0, en unidades de mundo.
func walk_advance(t: float, model_scale: float) -> float:
	return ground_speed(model_scale) * t


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
	for bone in _idx:
		_skel.reset_bone_pose(_idx[bone])


# ------------------------------------------------------------------ internos

## Guarda la geometria de reposo de una pierna: de ahi salen las longitudes de
## muslo y espinilla y los angulos de partida que necesita la cinematica.
func _cache_leg(side: String) -> void:
	var names := ["%s_Hip" % side, "%s_Knee" % side, "%s_Ankle" % side]
	for n in names:
		if not _idx.has(n):
			return
	var hip := _skel.get_bone_global_rest(_idx[names[0]]).origin
	var knee := _skel.get_bone_global_rest(_idx[names[1]]).origin
	var ankle := _skel.get_bone_global_rest(_idx[names[2]]).origin
	# Se trabaja en el plano sagital (Z hacia delante, Y hacia arriba): las
	# rotaciones en X no cambian la X de los huesos, asi que el problema es
	# plano y se resuelve exacto con el teorema del coseno.
	var thigh := Vector2(knee.z - hip.z, knee.y - hip.y)
	var shin := Vector2(ankle.z - knee.z, ankle.y - knee.y)
	_legs[side] = {
		"hip": Vector2(hip.z, hip.y),
		"l1": thigh.length(),
		"l2": shin.length(),
		"thigh_rest": _sag_angle(thigh),
		"shin_rest": _sag_angle(shin),
		"ground": ankle.y,
	}


## Angulo de un vector del plano sagital medido desde "hacia abajo": 0 = el
## hueso cuelga vertical, positivo = apunta hacia delante (+Z).
func _sag_angle(v: Vector2) -> float:
	return atan2(v.x, -v.y)


func _bob_rig(cycle: float) -> float:
	# Dos rebotes por ciclo: el cuerpo baja con las piernas abiertas y sube al
	# pasar una junto a la otra. Ademas de dar vida, ese descenso es lo que
	# permite a la pierna llegar al suelo con el paso abierto.
	return -absf(sin(cycle * TAU)) * BODY_BOB


## Donde tiene que estar el pie en este instante del ciclo, en el plano
## sagital y respecto al esqueleto. `cycle01` 0 = el talon acaba de posarse.
func _foot_target(side: String, cycle01: float, bob: float) -> Vector2:
	var leg: Dictionary = _legs[side]
	var ground: float = leg["ground"]
	if cycle01 < STANCE_FRAC:
		# APOYO: el pie va del frente a la espalda a ritmo constante y sin
		# despegar. Se resta el balanceo del cuerpo para que, al bajar la
		# cadera, el pie siga exactamente a la misma altura del suelo.
		var u := cycle01 / STANCE_FRAC
		return Vector2(lerpf(STRIDE * 0.5, -STRIDE * 0.5, u), ground - bob)
	# VUELO: vuelve al frente describiendo un arco, arrancando y aterrizando
	# suave para que no de tirones al cambiar de fase.
	var v := (cycle01 - STANCE_FRAC) / (1.0 - STANCE_FRAC)
	return Vector2(
		lerpf(-STRIDE * 0.5, STRIDE * 0.5, smoothstep(0.0, 1.0, v)),
		ground - bob + sin(PI * v) * FOOT_LIFT)


## Resuelve la pierna para que el tobillo caiga sobre su objetivo.
func _leg(side: StringName, cycle01: float, bob: float) -> void:
	var s := String(side)
	if not _legs.has(s):
		return
	var leg: Dictionary = _legs[s]
	var l1: float = leg["l1"]
	var l2: float = leg["l2"]
	var hip: Vector2 = leg["hip"]
	var target := _foot_target(s, cycle01, bob) - hip
	# Nunca se pide mas de lo que la pierna da: si el objetivo queda fuera de
	# alcance se acerca, y asi no aparecen angulos imposibles.
	var d: float = clampf(target.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var to_target := _sag_angle(target)
	# Teorema del coseno: apertura entre el muslo y la linea cadera-tobillo.
	var alpha := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	# La rodilla sobresale HACIA DELANTE, que es como dobla una rodilla humana.
	var thigh_angle := to_target + alpha
	var knee_pos := Vector2(sin(thigh_angle), -cos(thigh_angle)) * l1
	var shin_angle := _sag_angle(target - knee_pos)

	# De angulos del plano a rotaciones de hueso (una rotacion de +X resta
	# angulo, de ahi los signos cambiados).
	_pitch("%s_Hip" % s, -rad_to_deg(thigh_angle - leg["thigh_rest"]))
	_pitch("%s_Knee" % s, -rad_to_deg(
		(shin_angle - thigh_angle) - (leg["shin_rest"] - leg["thigh_rest"])))
	# El tobillo deshace el giro de la espinilla para que la planta siga
	# mirando al suelo en vez de irse con la pierna.
	_pitch("%s_Ankle" % s, rad_to_deg(shin_angle - leg["shin_rest"]))


## Cadera: los tres gestos que la hacen parecer viva. `phase` es el de la
## pierna izquierda, asi que en fase 0 esa pierna acaba de posarse.
func _pelvis(phase: float) -> void:
	_yaw("Pelvis", sin(phase) * PELVIS_YAW)
	# Cae del lado de la pierna en vuelo (positivo en Z sube el lado +X, que
	# es el izquierdo, asi que se resta para que ese lado baje).
	_roll("Pelvis", -cos(phase) * PELVIS_ROLL)
	_translate("Pelvis", Vector3(-cos(phase) * PELVIS_SWAY, 0.0, 0.0))


func _arm(side: String, phase: float) -> void:
	_pitch("%s_Shoulder" % side, -ARM_SWING * sin(phase))
	_pitch("%s_Elbow" % side, -ELBOW_BEND - maxf(0.0, sin(phase)) * ELBOW_BEND)


func _pitch(bone: String, deg: float) -> void:
	_rotate(bone, Vector3(1, 0, 0), deg)


func _yaw(bone: String, deg: float) -> void:
	_rotate(bone, Vector3(0, 1, 0), deg)


func _roll(bone: String, deg: float) -> void:
	_rotate(bone, Vector3(0, 0, 1), deg)


func _rotate(bone: String, axis: Vector3, deg: float) -> void:
	if not _idx.has(bone):
		return
	var i: int = _idx[bone]
	var rest := _skel.get_bone_rest(i).basis.get_rotation_quaternion()
	_skel.set_bone_pose_rotation(i, rest * Quaternion(axis, deg_to_rad(deg)))


func _translate(bone: String, offset: Vector3) -> void:
	if not _idx.has(bone):
		return
	var i: int = _idx[bone]
	_skel.set_bone_pose_position(i, _skel.get_bone_rest(i).origin + offset)
