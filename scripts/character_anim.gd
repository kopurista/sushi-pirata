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
const STRIDE := 0.35          ## lo que recorre el pie apoyado, unidades del rig
const STANCE_FRAC := 0.55     ## parte del ciclo con el pie en el suelo
## Altura del pie en el aire. Muy bajo el pie roza el suelo y el paso parece
## un arrastre; muy alto se ve de marcha militar.
const FOOT_LIFT := 0.058
## En que momento del vuelo queda el punto mas alto. Adelantado (menos de la
## mitad) el pie sube pronto y luego BAJA PLANEANDO hasta posarse, en vez de
## caer en vertical como si pisoteara.
const LIFT_PEAK_AT := 0.36
## Cuanto baja el cuerpo con las piernas abiertas. Ademas de dar vida, es lo
## que permite a la pierna ALCANZAR el suelo en la zancada abierta: si se sube
## STRIDE hay que subir esto, o la pierna se queda corta y el pie patina.
const BODY_BOB := 0.022       ## sube y baja del cuerpo, unidades del rig
## El cuerpo va SIEMPRE algo flexionado sobre las piernas. No es estetica: si
## la pierna trabaja casi estirada, la cinematica inversa se vuelve inestable
## —cerca de la extension total el acos tiene derivada infinita— y la rodilla
## pega un CHASQUIDO en cada paso: se ve como un tiron al final de la zancada
## y como un pisoton al apoyar. Con el cuerpo un poco mas bajo la rodilla
## trabaja siempre en una zona estable y el paso sale suave.
const CROUCH := 0.050
const ARM_SWING := 22.0       ## balanceo de hombro (opuesto a su pierna)
const ELBOW_BEND := 16.0      ## flexion fija de codo, da naturalidad
## La clavicula mueve el hombro entero, no solo el brazo: acompaña al brazo
## hacia delante y lo encoge un poco al ir hacia atras. Es sutil, pero es la
## diferencia entre un cuerpo vivo y un torso rigido con dos brazos colgando.
const COLLAR_SWING := 9.0     ## el hombro va y viene con su brazo
const COLLAR_LIFT := 4.5      ## y sube ligeramente al llevarlo atras
## Cierre de los puños, en grados POR FALANGE (son tres por dedo, asi que el
## dedo se dobla el triple). Con la mano abierta parece que lleve algo cogido.
const FIST_CURL := 46.0
const THUMB_CURL := 34.0      ## el pulgar, sobre su propio eje
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

# --- Sentado ---
const SIT_HIP := 82.0         ## muslo casi horizontal hacia delante
const SIT_KNEE := 84.0        ## espinilla de vuelta a la vertical
const SIT_SPREAD := 5.0       ## las rodillas se abren un poco
const SIT_LEAN := 6.0         ## el tronco se inclina algo hacia delante

# --- Comer sentado, en cuatro fases ---
## Duracion de cada fase, en segundos. Un bocado completo es la suma.
const BITE_REACH := 0.55      ## 1. el brazo va al plato y coge la comida
const BITE_LIFT := 0.40       ## 2. sube la mano a la boca
const BITE_CHEW := 0.90       ## 3. mastica con la mano arriba
const BITE_LOWER := 0.50      ## 4. baja el brazo a la postura de sentado
const CHEW_ANGLE := 4.5       ## cuanto cabecea al masticar
const CHEW_SPEED := 9.0       ## y a que ritmo
## Por donde pasa la MANO, en coordenadas del esqueleto y para el brazo
## izquierdo (el derecho usa lo mismo con la X cambiada de signo). Se anima la
## mano y no los angulos del brazo: asi se puede apuntar a un sitio concreto
## —el plato, la boca— y el hombro y el codo se resuelven solos.
const HAND_LAP := Vector3(0.135, 0.010, 0.120)    ## descansando en el muslo
const HAND_PLATE := Vector3(0.105, 0.055, 0.235)  ## donde esta LA COMIDA
## La mano se queda por ENCIMA de la comida, no encima del punto exacto: si va
## al mismo sitio, el puño atraviesa el plato y la mesa. Son los dedos los que
## bajan hasta la comida, que para eso apuntan hacia ella.
const GRAB_CLEARANCE := 0.080
## Delante de la boca. La cabeza va de y=0.33 a y=0.49 en este rig, asi que la
## mano se queda algo por debajo y los dedos apuntan hacia arriba, a la boca.
## Va bastante separada del eje del cuerpo: con la mano pegada al centro, el
## ANTEBRAZO cruza el pecho aunque la mano quede fuera.
const HAND_MOUTH := Vector3(0.120, 0.280, 0.120)
## Punto de paso obligado al ir y volver del plato. Sin el, la mano viaja en
## LINEA RECTA entre el muslo y el plato, y esa recta atraviesa el mostrador:
## al ir sube en diagonal y entra por delante de la mesa; al volver la barre.
## Con este punto la mano sale primero al costado, ya por encima de la mesa, y
## solo entonces avanza. Va muy hacia el lado y algo adelantado: llevarlo
## hacia atras metia el antebrazo en el torso.
const HAND_SIDE := Vector3(0.265, 0.140, 0.090)
## Cuanto se abre el codo hacia fuera y hacia delante. Con poco, el brazo se
## dobla pegado al costado y se mete dentro del torso.
const ELBOW_OUT := 2.8
const ELBOW_FWD := 0.5
## La mano no se deja a merced del giro del brazo: APUNTA a algo, igual que
## una mano de verdad. Los dedos miran al plato mientras lo coge y a la boca
## mientras se lleva la comida; sin esto la mano conserva la orientacion de
## brazo colgando y llega de lado a la cara.
const MOUTH := Vector3(0.0, 0.355, 0.070)   ## donde esta la boca en el rig
const LOOK_DOWN := Vector3(0.0, -0.25, 0.0) ## para que los dedos miren abajo

var _skel: Skeleton3D
var _idx := {}                ## nombre de hueso -> indice, solo los existentes
var _legs := {}               ## "L"/"R" -> geometria de reposo de esa pierna
var _fingers := {}            ## "L"/"R" -> indices de los huesos de los dedos


func _init(skeleton: Skeleton3D) -> void:
	_skel = skeleton
	for i in _skel.get_bone_count():
		_idx[_skel.get_bone_name(i)] = i
	for side in ["L", "R"]:
		_cache_leg(side)
		_cache_fingers(side)


func has_humanoid_bones() -> bool:
	return _legs.has("L") and _legs.has("R")


## Ciclo de marcha. `t` es tiempo en segundos; el ciclo se repite solo.
func walk(t: float) -> void:
	var cycle := fmod(t / WALK_PERIOD, 1.0)
	var bob := _bob_rig(cycle)
	# Las dos piernas hacen lo mismo con media vuelta de diferencia.
	_leg(&"L", cycle, bob)
	_leg(&"R", fmod(cycle + 0.5, 1.0), bob)
	# El brazo acompaña a la pierna CONTRARIA y CON SU MISMO RITMO: se le pasa
	# lo adelantada que va esa pierna, no un seno. Con un seno los extremos del
	# brazo caian un cuarto de ciclo despues que los de la pierna (la pierna ya
	# no sigue un seno: tiene fase de apoyo y fase de vuelo), y el balanceo se
	# veia descoordinado del paso.
	var phase := cycle * TAU
	_arm("L", _leg_swing(fmod(cycle + 0.5, 1.0)))
	_arm("R", _leg_swing(cycle))
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


## Postura de sentado: caderas y rodillas dobladas casi en angulo recto, con
## las rodillas ligeramente abiertas y el tronco algo inclinado. No incluye los
## brazos, que los pone quien llame (comer, esperar...).
func sit() -> void:
	for side in ["L", "R"]:
		var out := 1.0 if side == "L" else -1.0
		_pitch("%s_Hip" % side, -SIT_HIP)
		_roll("%s_Hip" % side, out * SIT_SPREAD)
		_pitch("%s_Knee" % side, SIT_KNEE)
		# El pie queda plano en el suelo pese al giro de cadera y rodilla.
		_pitch("%s_Ankle" % side, SIT_HIP - SIT_KNEE)
	_pitch("Spine1", SIT_LEAN * 0.5)
	_pitch("Spine2", SIT_LEAN * 0.5)


## Cuanto hay que DESPLAZAR al personaje al sentarlo para que los pies sigan
## tocando el suelo, en unidades de mundo (sale negativo: al doblar las piernas
## los pies suben dentro del modelo, asi que el conjunto tiene que bajar).
func sit_offset(model_scale: float) -> float:
	var ankle := _skel.find_bone("L_Ankle")
	if ankle < 0:
		return 0.0
	reset()
	var standing: float = _skel.get_bone_global_pose(ankle).origin.y
	sit()
	var seated: float = _skel.get_bone_global_pose(ankle).origin.y
	reset()
	return (standing - seated) * model_scale


## Un bocado completo, en las cuatro fases: coger del plato, subir a la boca,
## masticar y bajar el brazo. Se repite solo mientras el cliente coma.
func bite(t: float) -> void:
	sit()
	var total := BITE_REACH + BITE_LIFT + BITE_CHEW + BITE_LOWER
	var u := fmod(t, total)
	var hand: Vector3
	# `focus` es adonde miran los DEDOS: al plato al cogerlo, a la boca al
	# llevarse la comida. Va interpolandose junto con la mano.
	var focus: Vector3
	var chew := 0.0
	# La mano se para sobre la comida; los dedos son los que llegan a ella.
	var over_plate := HAND_PLATE + Vector3(0.0, GRAB_CLEARANCE, 0.0)
	if u < BITE_REACH:
		var w := smoothstep(0.0, 1.0, u / BITE_REACH)
		# Sale al costado y por encima de la mesa antes de avanzar al plato.
		hand = _bezier(HAND_LAP, HAND_SIDE, over_plate, w)
		focus = (HAND_LAP + LOOK_DOWN).lerp(HAND_PLATE, w)
	elif u < BITE_REACH + BITE_LIFT:
		var w := smoothstep(0.0, 1.0, (u - BITE_REACH) / BITE_LIFT)
		hand = over_plate.lerp(HAND_MOUTH, w)
		focus = HAND_PLATE.lerp(MOUTH, w)
	elif u < BITE_REACH + BITE_LIFT + BITE_CHEW:
		hand = HAND_MOUTH
		focus = MOUTH
		chew = sin((u - BITE_REACH - BITE_LIFT) * CHEW_SPEED) * CHEW_ANGLE
	else:
		var w := smoothstep(0.0, 1.0,
			(u - BITE_REACH - BITE_LIFT - BITE_CHEW) / BITE_LOWER)
		# Curva de Bezier en vez de recta: la mano se retira hacia el cuerpo
		# antes de bajar, y asi no barre el plato ni el mostrador.
		hand = _bezier(HAND_MOUTH, HAND_SIDE, HAND_LAP, w)
		focus = MOUTH.lerp(HAND_LAP + LOOK_DOWN, w)
	# Come con la derecha; la izquierda descansa en el muslo.
	_arm_ik("R", Vector3(-hand.x, hand.y, hand.z),
		Vector3(-focus.x, focus.y, focus.z))
	_arm_ik("L", HAND_LAP, HAND_LAP + LOOK_DOWN)
	# Al masticar la cabeza cabecea y la mandibula no existe en el rig, asi
	# que el gesto se hace con el cuello.
	_pitch("Neck", chew)
	_fist("L")
	_fist("R")


## Sentado sin comer: respira y descansa las manos en los muslos.
func sit_idle(t: float) -> void:
	sit()
	var breath := sin(t / IDLE_PERIOD * TAU) * IDLE_BREATH
	_pitch("Spine2", SIT_LEAN * 0.5 + breath * 0.4)
	_pitch("Neck", -breath * 0.3)
	_arm_ik("L", HAND_LAP, HAND_LAP + LOOK_DOWN)
	_arm_ik("R", Vector3(-HAND_LAP.x, HAND_LAP.y, HAND_LAP.z),
		Vector3(-HAND_LAP.x, HAND_LAP.y, HAND_LAP.z) + LOOK_DOWN)
	_fist("L")
	_fist("R")


## Coloca la MANO de ese brazo sobre un punto del espacio del esqueleto,
## resolviendo hombro y codo. Es el mismo problema de dos huesos que la
## pierna, pero en el espacio: la pierna solo cabecea, mientras que el brazo
## tiene que cruzarse hacia el centro del cuerpo para llegar a la boca.
## `target` es donde va la MANO y `focus` adonde miran los dedos.
func _arm_ik(side: String, target: Vector3, focus: Vector3) -> void:
	var names := ["%s_Shoulder" % side, "%s_Elbow" % side, "%s_Wrist" % side]
	for n in names:
		if not _idx.has(n):
			return
	var sh := _skel.get_bone_global_rest(_idx[names[0]]).origin
	var el := _skel.get_bone_global_rest(_idx[names[1]]).origin
	var wr := _skel.get_bone_global_rest(_idx[names[2]]).origin
	var l1 := sh.distance_to(el)
	var l2 := el.distance_to(wr)

	var to_target := target - sh
	var d: float = clampf(to_target.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.005)
	# Cuanto hay que doblar el codo respecto a tenerlo estirado, para que el
	# brazo mida justo lo que hay hasta el objetivo.
	var bend := acos(clampf((d * d - l1 * l1 - l2 * l2) / (2.0 * l1 * l2), -1.0, 1.0))
	# El codo dobla hacia delante: en este rig eso es girar en X negativo.
	var elbow_rot := Quaternion(Vector3(1, 0, 0), -bend)
	_skel.set_bone_pose_rotation(_idx[names[1]],
		_skel.get_bone_rest(_idx[names[1]]).basis.get_rotation_quaternion() * elbow_rot)

	# Con el codo ya doblado, se gira el hombro para que la muñeca caiga
	# encima del objetivo.
	var wrist_bent := (el - sh) + elbow_rot * (wr - el)
	var aim := Quaternion(wrist_bent.normalized(), to_target.normalized())

	# Aim deja libre el giro del brazo ALREDEDOR del eje hombro-mano, y por su
	# cuenta lo resuelve por el camino corto, que manda el codo hacia dentro
	# del cuerpo. Aqui se fija a donde tiene que apuntar el codo: hacia fuera
	# y hacia abajo, como en un brazo humano. Girar sobre ese eje no mueve la
	# mano, asi que el objetivo se sigue cumpliendo.
	var axis := to_target.normalized()
	var out := 1.0 if side == "L" else -1.0
	var pole := (Vector3(out * ELBOW_OUT, -1.0, ELBOW_FWD)).normalized()
	var elbow_now := (aim * (el - sh))
	var cur := (elbow_now - axis * elbow_now.dot(axis))
	var want := (pole - axis * pole.dot(axis))
	if cur.length() > 0.0001 and want.length() > 0.0001:
		cur = cur.normalized()
		want = want.normalized()
		var ang := atan2(cur.cross(want).dot(axis), cur.dot(want))
		aim = Quaternion(axis, ang) * aim

	_skel.set_bone_pose_rotation(_idx[names[0]],
		_skel.get_bone_rest(_idx[names[0]]).basis.get_rotation_quaternion() * aim)

	# La muñeca no se deja como la deje el brazo: se orienta para que los dedos
	# miren al punto indicado. Si no, la mano conserva la orientacion de brazo
	# colgando y llega de lado a la boca.
	var wrist_i: int = _idx[names[2]]
	var elbow_q := _skel.get_bone_global_pose(_idx[names[1]]).basis \
		.orthonormalized().get_rotation_quaternion()
	var wrist_pos := _skel.get_bone_global_pose(wrist_i).origin
	var look := focus - wrist_pos
	if look.length() < 0.001:
		_skel.set_bone_pose_rotation(wrist_i, elbow_q.inverse())
		return
	# En reposo los dedos salen de la muñeca hacia abajo (-Y).
	var hand_aim := Quaternion(Vector3(0, -1, 0), look.normalized())
	_skel.set_bone_pose_rotation(wrist_i, elbow_q.inverse() * hand_aim)


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


## Recoge los huesos de los dedos: todo lo que cuelga de la muñeca. Se busca
## por jerarquia y no por nombre porque el auto-rig los deja sin nombrar
## (bone_21, bone_22...), pero siempre colgando de su muñeca.
##
## El PULGAR se separa del resto porque no se cierra igual: los otros cuatro
## dedos cuelgan hacia abajo y se doblan sobre la linea de los nudillos, pero
## el pulgar sale hacia delante y hay que llevarlo contra la palma girando
## sobre otro eje. Se identifica como el dedo cuya raiz apunta MENOS hacia
## abajo, que es lo que lo distingue en cualquier mano.
func _cache_fingers(side: String) -> void:
	var wrist: int = _idx.get("%s_Wrist" % side, -1)
	if wrist < 0:
		return
	var wrist_pos := _skel.get_bone_global_rest(wrist).origin
	var thumb_root := -1
	var least_down := -INF
	for i in _skel.get_bone_count():
		if _skel.get_bone_parent(i) != wrist:
			continue
		var dir := (_skel.get_bone_global_rest(i).origin - wrist_pos).normalized()
		if dir.y > least_down:
			least_down = dir.y
			thumb_root = i

	var thumb: Array[int] = []
	var fingers: Array[int] = []
	for i in _skel.get_bone_count():
		# Sube hasta encontrar de que dedo cuelga este hueso.
		var root := i
		var p := _skel.get_bone_parent(root)
		while p >= 0 and p != wrist:
			root = p
			p = _skel.get_bone_parent(root)
		if p != wrist:
			continue
		if root == thumb_root:
			thumb.append(i)
		else:
			fingers.append(i)
	_fingers[side] = {"thumb": thumb, "fingers": fingers}


## Angulo de un vector del plano sagital medido desde "hacia abajo": 0 = el
## hueso cuelga vertical, positivo = apunta hacia delante (+Z).
func _sag_angle(v: Vector2) -> float:
	return atan2(v.x, -v.y)


func _bob_rig(cycle: float) -> float:
	# Dos rebotes por ciclo sobre una flexion constante: el cuerpo baja con las
	# piernas abiertas y sube al pasar una junto a la otra. Ademas de dar vida,
	# ese descenso es lo que permite a la pierna llegar al suelo con el paso
	# abierto. Como el objetivo del pie descuenta este valor y quien mueve al
	# personaje lo aplica al pivote, los pies siguen pisando el suelo.
	return -CROUCH - absf(sin(cycle * TAU)) * BODY_BOB


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
	# VUELO: vuelve al frente describiendo un arco.
	var v := (cycle01 - STANCE_FRAC) / (1.0 - STANCE_FRAC)
	return Vector2(_swing_z(v), ground - bob + _swing_lift(v))


## Altura del pie durante el vuelo: una loma asimetrica, empinada al subir y
## tendida al bajar. Las dos mitades son medio coseno, que llega a los extremos
## con velocidad CERO; una curva tipo pow(v, 0.7) tambien adelanta el punto
## alto, pero sale del suelo con velocidad infinita y el pie pega un salto seco
## al despegar.
func _swing_lift(v: float) -> float:
	if v < LIFT_PEAK_AT:
		var up := v / LIFT_PEAK_AT
		return FOOT_LIFT * (0.5 - 0.5 * cos(PI * up))
	var down := (v - LIFT_PEAK_AT) / (1.0 - LIFT_PEAK_AT)
	return FOOT_LIFT * (0.5 + 0.5 * cos(PI * down))


## Avance del pie durante el vuelo. Es una curva de Hermite con las PENDIENTES
## de los extremos fijadas a la misma velocidad que lleva el pie mientras pisa.
## Con una interpolacion normal (o un smoothstep) el pie sale del suelo y
## aterriza con velocidad cero, asi que su velocidad da un salto brusco justo
## al despegar y al posarse: eso es el tiron que se veia al final de la
## zancada. Al igualar las pendientes el paso encadena sin costura.
##
## De regalo, la curva reproduce dos cosas que hace un pie de verdad: sigue
## empujando hacia atras un instante despues de despegar, y se adelanta un
## poco de mas antes de recogerse para posarse justo donde toca.
func _swing_z(v: float) -> float:
	var half := STRIDE * 0.5
	var slope := -STRIDE * (1.0 - STANCE_FRAC) / STANCE_FRAC
	var v2 := v * v
	var v3 := v2 * v
	return -half * (2.0 * v3 - 3.0 * v2 + 1.0) \
		+ slope * (v3 - 2.0 * v2 + v) \
		+ half * (-2.0 * v3 + 3.0 * v2) \
		+ slope * (v3 - v2)


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


## Curva suave que pasa cerca de `via` al ir de `from` a `to`.
func _bezier(from: Vector3, via: Vector3, to: Vector3, w: float) -> Vector3:
	return from.lerp(via, w).lerp(via.lerp(to, w), w)


## Lo adelantada que va la pierna en este instante: +1 con el pie lo mas
## adelante posible, -1 lo mas atras. Es la misma curva que sigue el pie, asi
## que sirve para mover los brazos exactamente al ritmo de las piernas.
func _leg_swing(cycle01: float) -> float:
	var z: float
	if cycle01 < STANCE_FRAC:
		z = lerpf(STRIDE * 0.5, -STRIDE * 0.5, cycle01 / STANCE_FRAC)
	else:
		z = _swing_z((cycle01 - STANCE_FRAC) / (1.0 - STANCE_FRAC))
	return clampf(z / (STRIDE * 0.5), -1.0, 1.0)


## `swing`: +1 = ese brazo del todo hacia delante, -1 del todo hacia atras.
func _arm(side: String, swing: float) -> void:
	# El hombro entero acompaña al brazo, con el giro repartido entre la
	# clavicula y el hombro para que el movimiento salga del torso.
	_pitch("%s_Collar" % side, -COLLAR_SWING * swing)
	# La clavicula se levanta al llevar el brazo atras. El lado derecho es el
	# espejo del izquierdo, de ahi el cambio de signo.
	var mirror := 1.0 if side == "L" else -1.0
	_roll("%s_Collar" % side, mirror * COLLAR_LIFT * maxf(0.0, -swing))
	_pitch("%s_Shoulder" % side, -ARM_SWING * swing)
	_pitch("%s_Elbow" % side, -ELBOW_BEND - maxf(0.0, swing) * ELBOW_BEND)
	_fist(side)


## Cierra la mano. Al andar los puños van cerrados, no con los dedos
## estirados: abiertos parece que el personaje sujete algo.
func _fist(side: String) -> void:
	if not _fingers.has(side):
		return
	# Los cuatro dedos se alinean a lo largo de Z (la linea de los nudillos),
	# asi que doblan girando sobre Z. Se cierran hacia la palma, que mira
	# hacia dentro del cuerpo: en la mano izquierda eso es -X, giro negativo.
	var mirror := -1.0 if side == "L" else 1.0
	var hand: Dictionary = _fingers[side]
	for i in hand["fingers"]:
		_rotate_bone(i, Vector3(0, 0, 1), mirror * FIST_CURL)
	# El pulgar sale hacia DELANTE en vez de colgar, asi que sobre Z solo se
	# abanicaria: para llevarlo contra la palma hay que girarlo sobre Y.
	for i in hand["thumb"]:
		_rotate_bone(i, Vector3(0, 1, 0), mirror * THUMB_CURL)


func _pitch(bone: String, deg: float) -> void:
	_rotate(bone, Vector3(1, 0, 0), deg)


func _yaw(bone: String, deg: float) -> void:
	_rotate(bone, Vector3(0, 1, 0), deg)


func _roll(bone: String, deg: float) -> void:
	_rotate(bone, Vector3(0, 0, 1), deg)


func _rotate(bone: String, axis: Vector3, deg: float) -> void:
	if _idx.has(bone):
		_rotate_bone(_idx[bone], axis, deg)


## Gira un hueso ACUMULANDO sobre lo que ya tenga en este fotograma, no
## sustituyendolo. Es importante: varios huesos reciben dos giros seguidos (la
## cadera se dobla y ademas se abre, la clavicula va y viene y ademas se
## encoge), y sustituyendo, el segundo borraba al primero en silencio. Como
## reset() deja la pose en reposo al empezar cada fotograma, la primera
## llamada parte siempre del reposo.
func _rotate_bone(i: int, axis: Vector3, deg: float) -> void:
	_skel.set_bone_pose_rotation(i,
		_skel.get_bone_pose_rotation(i) * Quaternion(axis, deg_to_rad(deg)))


func _translate(bone: String, offset: Vector3) -> void:
	if not _idx.has(bone):
		return
	var i: int = _idx[bone]
	_skel.set_bone_pose_position(i, _skel.get_bone_rest(i).origin + offset)
