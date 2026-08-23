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
## OJO: las medidas del movimiento van en FRACCIONES del propio cuerpo, no en
## unidades fijas. Los personajes salen del generador con proporciones muy
## distintas (el capitan tiene las piernas largas, el VIP casi estiradas del
## todo en reposo), y una zancada en unidades absolutas le queda corta a uno y
## fuera de alcance a otro. Al medirlo sobre su propia pierna, el mismo codigo
## anda bien con cualquiera.
const STRIDE_F := 0.83        ## zancada, en fracciones de la pierna
const STANCE_FRAC := 0.55     ## parte del ciclo con el pie en el suelo
## Altura del pie en el aire. Muy bajo el pie roza el suelo y el paso parece
## un arrastre; muy alto se ve de marcha militar.
const FOOT_LIFT_F := 0.137
## En que momento del vuelo queda el punto mas alto. Adelantado (menos de la
## mitad) el pie sube pronto y luego BAJA PLANEANDO hasta posarse, en vez de
## caer en vertical como si pisoteara.
const LIFT_PEAK_AT := 0.36
## Cuanto baja el cuerpo con las piernas abiertas. Ademas de dar vida, es lo
## que permite a la pierna ALCANZAR el suelo en la zancada abierta: si se sube
## STRIDE hay que subir esto, o la pierna se queda corta y el pie patina.
const BODY_BOB_F := 0.052     ## sube y baja del cuerpo, fraccion de la pierna
## El cuerpo va SIEMPRE algo flexionado sobre las piernas. No es estetica: si
## la pierna trabaja casi estirada, la cinematica inversa se vuelve inestable
## —cerca de la extension total el acos tiene derivada infinita— y la rodilla
## pega un CHASQUIDO en cada paso: se ve como un tiron al final de la zancada
## y como un pisoton al apoyar. Con el cuerpo un poco mas bajo la rodilla
## trabaja siempre en una zona estable y el paso sale suave.
const CROUCH_F := 0.118
## Cuanto se separa el brazo del costado EN REPOSO, en grados desde la
## vertical. Los modelos vienen generados en pose de A —brazos muy abiertos,
## comodo para riguear pero pesimo como reposo— y unos abren mucho mas que
## otros: el chef neutro llegaba a 1.2 u de ancho y se metia dentro del
## ayudante. Se mide la apertura de CADA personaje y se le recoge lo que le
## sobre hasta este objetivo, asi que todos acaban con la misma silueta.
const IDLE_ARM_SPREAD := 9.0
## Lo minimo que puede medir un miembro para darlo por bueno, en fracciones del
## alto del personaje. Los brazos sanos miden entre el 25% y el 35%; los rigs
## fallidos dejan el brazo entero en el 1-2%. Ver _measure().
const MIN_LIMB_FRAC := 0.15
## Lo mismo para las PIERNAS, con su propio liston: unas piernas sanas miden
## el 43-55% del alto (medido en los 13 rigs del reparto). Por debajo de 0.32
## las rotaciones del andar y del sentado, pensadas para ese largo, arrastran
## media carne del cuerpo: el KAPPA (27%) salia con una cuna verde enorme
## detras, tanto andando como sentado. Un rig asi conserva sus piernas como se
## modelaron y anda solo con el vaiven del cuerpo y los brazos.
const MIN_LEG_FRAC := 0.32
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
## Por donde pasa la mano, en FRACCIONES DEL BRAZO y respecto a un hueso del
## personaje (la cadera, el hombro o la boca). Con puntos fijos, al pirata —de
## brazos mas cortos— la comida se le quedaba a 26 cm de la boca.
const LAP_OFF := Vector3(0.23, 0.10, 0.29)      ## desde la cadera: sobre el muslo
const PLATE_OFF := Vector3(-0.04, -0.70, 0.77)  ## desde el hombro: la comida
## Desde la boca: la mano se queda algo por debajo y los dedos apuntan hacia
## arriba. Va bastante separada del eje del cuerpo, porque con la mano pegada
## al centro el ANTEBRAZO cruza el pecho aunque la mano quede fuera.
const MOUTH_OFF := Vector3(0.39, -0.24, 0.16)
## Punto de paso obligado al ir y volver del plato, desde el hombro. Sin el, la
## mano viaja en LINEA RECTA entre el muslo y el plato, y esa recta atraviesa
## el mostrador: al ir sube en diagonal y entra por delante de la mesa; al
## volver la barre. Con este punto la mano sale primero al costado, ya por
## encima de la mesa, y solo entonces avanza. Va muy hacia el lado y algo
## adelantado: llevarlo hacia atras metia el antebrazo en el torso.
const SIDE_OFF := Vector3(0.47, -0.43, 0.30)
## La mano se queda por ENCIMA de la comida, no en el punto exacto: si va al
## mismo sitio, el puño atraviesa el plato y la mesa. Son los dedos los que
## bajan hasta la comida, que para eso apuntan hacia ella.
const GRAB_CLEARANCE_F := 0.26
## Donde cae la boca dentro de la cabeza, hacia delante y bajando desde su
## centro (en fracciones del alto de la cabeza).
const MOUTH_IN_HEAD := Vector2(0.55, 0.30)
## Cuanto se abre el codo hacia fuera y hacia delante. Con poco, el brazo se
## dobla pegado al costado y se mete dentro del torso.
const ELBOW_OUT := 2.8
const ELBOW_FWD := 0.5
## La mano no se deja a merced del giro del brazo: APUNTA a algo, igual que
## una mano de verdad. Los dedos miran al plato mientras lo coge y a la boca
## mientras se lleva la comida; sin esto la mano conserva la orientacion de
## brazo colgando y llega de lado a la cara.
const MOUTH := Vector3(0.0, 0.355, 0.070)   ## donde esta la boca en el rig
## Cuanto se proyecta la mirada de los dedos hacia abajo, en fracciones del brazo.
const LOOK_DOWN_F := 0.80

var _skel: Skeleton3D
var _idx := {}                ## nombre de hueso -> indice, solo los existentes
var _legs := {}               ## "L"/"R" -> geometria de reposo de esa pierna
var _fingers := {}            ## "L"/"R" -> indices de los huesos de los dedos

# Medidas de ESTE personaje, sacadas de su esqueleto en _measure().
var _leg_len := 1.0           ## muslo + espinilla
var legs_ok := true           ## si las piernas se pueden animar (ver arriba)
var _arm_len := 1.0           ## brazo + antebrazo
var stride := 0.0             ## las cuatro de arriba, ya en unidades del rig
var foot_lift := 0.0
var body_bob := 0.0
var crouch := 0.0
var hand_lap := Vector3.ZERO  ## y los puntos por donde pasa la mano
var hand_plate := Vector3.ZERO
var hand_mouth := Vector3.ZERO
var hand_side := Vector3.ZERO
var mouth := Vector3.ZERO
var grab_clearance := 0.0
## Grados que hay que recoger el brazo de ESTE personaje para dejarlo a
## IDLE_ARM_SPREAD del costado (0 si ya lo tiene pegado).
var arm_tuck := 0.0
## Si los huesos del brazo forman un brazo de verdad (ver _measure).
var arms_ok := false


func _init(skeleton: Skeleton3D) -> void:
	_skel = skeleton
	for i in _skel.get_bone_count():
		_idx[_skel.get_bone_name(i)] = i
	# El auto-rig NO siempre nombra los huesos: de cinco personajes solo uno
	# salio con nombres anatomicos y el resto con bone_0, bone_1... Asi que la
	# anatomia se deduce de la FORMA del esqueleto y se registra bajo los
	# nombres logicos que usa el resto del codigo. Si el rig ya venia nombrado,
	# los nombres detectados coinciden con los suyos y no pasa nada.
	_detect_bones()
	for side in ["L", "R"]:
		_cache_leg(side)
		_cache_fingers(side)
	_measure()


## Mide el cuerpo de ESTE personaje y traduce las proporciones del movimiento
## a sus unidades. Todo lo que hace la animacion sale de aqui, asi que el mismo
## codigo vale para un grumete menudo y para un capitan de piernas largas.
func _measure() -> void:
	if not has_humanoid_bones():
		return
	var leg: Dictionary = _legs["L"]
	_leg_len = leg["l1"] + leg["l2"]
	var sh := _rest(_idx["R_Shoulder"])
	_arm_len = _limb_len("R_Shoulder", "R_Elbow", "R_Wrist")
	# El brazo izquierdo se mide aparte: hay rigs que resuelven bien uno y
	# dejan el otro degenerado, y con medir solo el derecho pasaban por buenos.
	var arm_l := _limb_len("L_Shoulder", "L_Elbow", "L_Wrist")

	stride = STRIDE_F * _leg_len
	foot_lift = FOOT_LIFT_F * _leg_len
	body_bob = BODY_BOB_F * _leg_len
	crouch = CROUCH_F * _leg_len

	# La boca: dentro de la cabeza, algo por debajo de su centro y hacia
	# delante. Si el rig no trae cabeza, se usa el cuello como referencia.
	var head_i: int = _idx.get("Head", _idx.get("Neck", -1))
	var neck := _rest(_idx["Neck"]) if _idx.has("Neck") else sh
	var head := _rest(head_i) if head_i >= 0 else neck
	var head_h: float = maxf(absf(head.y - neck.y), _leg_len * 0.12)
	mouth = Vector3(0.0, head.y - head_h * MOUTH_IN_HEAD.y,
		head.z + head_h * MOUTH_IN_HEAD.x)

	var hip := _rest(_idx["L_Hip"])
	hand_lap = hip + LAP_OFF * _arm_len
	# El hombro izquierdo, para dejar los puntos en el lado +X como el resto.
	var sh_l := Vector3(absf(sh.x), sh.y, sh.z)
	hand_plate = sh_l + PLATE_OFF * _arm_len
	hand_side = sh_l + SIDE_OFF * _arm_len
	hand_mouth = mouth + MOUTH_OFF * _arm_len
	grab_clearance = GRAB_CLEARANCE_F * _arm_len

	# Un brazo tiene que MEDIR como un brazo. Hay rigs de Ludo que devuelven el
	# hombro, el codo y la muñeca AMONTONADOS dentro del pecho, a un centimetro
	# unos de otros: pasan por humanoides, pero animarlos gira la carne del
	# brazo alrededor de un punto del torso y el personaje agita los brazos de
	# forma imposible. Le paso al chef neutro, cuyos "brazos" median el 1% de su
	# altura. Cuando se detecta, los brazos se dejan como se modelaron.
	var height: float = _skeleton_height()
	arms_ok = minf(_arm_len, arm_l) > height * MIN_LIMB_FRAC
	legs_ok = _leg_len > height * MIN_LEG_FRAC
	if not arms_ok:
		return

	# Apertura del brazo en reposo: angulo del brazo respecto a la vertical,
	# visto de frente. Lo que pase de IDLE_ARM_SPREAD se recoge al animar.
	var el := _rest(_idx["R_Elbow"])
	var dx: float = absf(el.x - sh.x)
	var dy: float = sh.y - el.y
	var spread := rad_to_deg(atan2(dx, maxf(dy, 0.0001)))
	arm_tuck = maxf(spread - IDLE_ARM_SPREAD, 0.0)


## Largo de un miembro de tres huesos, o 0 si al rig le falta alguno.
func _limb_len(a: String, b: String, c: String) -> float:
	for n in [a, b, c]:
		if not _idx.has(n):
			return 0.0
	return _rest(_idx[a]).distance_to(_rest(_idx[b])) \
		+ _rest(_idx[b]).distance_to(_rest(_idx[c]))


## Alto total del esqueleto, de la coronilla a la planta.
func _skeleton_height() -> float:
	var top := -INF
	var bottom := INF
	for i in _skel.get_bone_count():
		var y := _rest(i).y
		top = maxf(top, y)
		bottom = minf(bottom, y)
	return maxf(top - bottom, 0.0001)


func has_humanoid_bones() -> bool:
	return _legs.has("L") and _legs.has("R") \
		and _idx.has("L_Wrist") and _idx.has("R_Wrist")


## Si ademas de existir, los brazos de este rig son brazos de verdad y se
## pueden animar. Ver la explicacion en _measure().
func has_usable_arms() -> bool:
	return arms_ok


## Lo mismo con las piernas (el kappa las tiene al 27% del alto y animarlas lo
## desfiguraba). Sin piernas animables el personaje anda de una pieza, a
## bandazos, que a un bicho rechoncho ademas le pega.
func has_usable_legs() -> bool:
	return legs_ok


## Si la deteccion encontro ese hueso. Util para comprobar un rig nuevo.
func resolved(logical_name: String) -> bool:
	return _idx.has(logical_name)


## Longitud del brazo de este personaje.
func arm_length() -> float:
	return _arm_len


## Indice real del hueso que hace ese papel, o -1. Lo usa la verificacion.
func bone(logical_name: String) -> int:
	return _idx.get(logical_name, -1)


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
	return stride * model_scale / (STANCE_FRAC * WALK_PERIOD)


## Distancia recorrida desde t=0, en unidades de mundo.
func walk_advance(t: float, model_scale: float) -> float:
	return ground_speed(model_scale) * t


## Reposo de pie: respiracion lenta, sin desplazar los pies.
func idle(t: float) -> void:
	var breath := sin(t / IDLE_PERIOD * TAU)
	# Dos ritmos distintos: el pecho respira lento y el cuerpo se balancea aun
	# mas lento. Con un solo seno todo subia y bajaba a la vez y se notaba el
	# bucle; desfasados, el reposo no se repite a simple vista.
	var sway := sin(t / (IDLE_PERIOD * 1.7) * TAU)
	_pitch("Spine1", 2.0 + breath * IDLE_BREATH * 0.5)
	_pitch("Spine2", breath * IDLE_BREATH * 0.3)
	_roll("Spine1", sway * 1.1)
	_yaw("Spine2", sway * 1.6)
	_pitch("Neck", -breath * IDLE_BREATH * 0.4)
	_yaw("Neck", -sway * 2.2)
	_arms_at_rest(breath)


## Brazos colgando pegados al cuerpo, con el codo algo flexionado y un vaiven
## suave. `breath` (-1..1) le da el movimiento.
##
## El recogido va en el HOMBRO y sobre su eje Z: girar ahi mueve el brazo en el
## plano frontal, que es justo abrir y cerrar respecto al costado. En el lado
## izquierdo (+X) un giro NEGATIVO lo baja hacia el cuerpo, y el derecho es su
## espejo.
func _arms_at_rest(breath: float) -> void:
	if not arms_ok:
		return
	for side in ["L", "R"]:
		var mirror := -1.0 if side == "L" else 1.0
		_roll("%s_Shoulder" % side, mirror * arm_tuck)
		_pitch("%s_Shoulder" % side, breath * 1.5)
		_pitch("%s_Elbow" % side, -ELBOW_BEND * 0.6)
		# Las manos descansan cerradas, no con los dedos estirados.
		_fist(side)


## Postura de sentado: caderas y rodillas dobladas casi en angulo recto, con
## las rodillas ligeramente abiertas y el tronco algo inclinado. No incluye los
## brazos, que los pone quien llame (comer, esperar...).
func sit() -> void:
	# Con piernas que no se pueden animar, sentarse es solo inclinar el tronco:
	# doblar unas piernas del 27% del alto convertia al kappa en una cuna.
	if legs_ok:
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
	if ankle < 0 or not legs_ok:
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
	var over_plate := hand_plate + Vector3(0.0, grab_clearance, 0.0)
	if u < BITE_REACH:
		var w := smoothstep(0.0, 1.0, u / BITE_REACH)
		# Sale al costado y por encima de la mesa antes de avanzar al plato.
		hand = _bezier(hand_lap, hand_side, over_plate, w)
		focus = (hand_lap + look_down()).lerp(hand_plate, w)
	elif u < BITE_REACH + BITE_LIFT:
		var w := smoothstep(0.0, 1.0, (u - BITE_REACH) / BITE_LIFT)
		hand = over_plate.lerp(hand_mouth, w)
		focus = hand_plate.lerp(mouth, w)
	elif u < BITE_REACH + BITE_LIFT + BITE_CHEW:
		hand = hand_mouth
		focus = mouth
		chew = sin((u - BITE_REACH - BITE_LIFT) * CHEW_SPEED) * CHEW_ANGLE
	else:
		var w := smoothstep(0.0, 1.0,
			(u - BITE_REACH - BITE_LIFT - BITE_CHEW) / BITE_LOWER)
		# Curva de Bezier en vez de recta: la mano se retira hacia el cuerpo
		# antes de bajar, y asi no barre el plato ni el mostrador.
		hand = _bezier(hand_mouth, hand_side, hand_lap, w)
		focus = mouth.lerp(hand_lap + look_down(), w)
	# Come con la derecha; la izquierda descansa en el muslo.
	_arm_ik("R", Vector3(-hand.x, hand.y, hand.z),
		Vector3(-focus.x, focus.y, focus.z))
	_arm_ik("L", hand_lap, hand_lap + look_down())
	# Al masticar la cabeza cabecea y la mandibula no existe en el rig, asi
	# que el gesto se hace con el cuello.
	_pitch("Neck", chew)
	_fist("L")
	_fist("R")


# --- Gestos de cocina del chef (de pie frente a su mesa) --------------------
## El chef trabaja con las manos sobre la mesa que tiene delante, a la altura
## de la cintura. Cada gesto recibe `u` (0..1, su progreso) y posa brazos,
## tronco y mirada; quien llama lo dispara UNA VEZ POR EVENTO del jugador, asi
## que el chef cocina exactamente al ritmo del dedo del usuario. Todos son
## deliberadamente sutiles: parten de la postura de trabajo y vuelven a ella.

## Punto de trabajo de cada mano sobre la mesa, en fracciones del brazo y
## desde su hombro (x hacia dentro del cuerpo, y hacia abajo, z al frente).
## MUY adelantado a proposito: el chef es orondo y con barba hasta la panza, y
## con menos avance las manos (y el cuchillo) quedaban DENTRO del cuerpo. La
## distancia total queda en ~0.9 brazos: cerca de la extension completa la IK
## del codo se vuelve inestable (misma leccion que la rodilla al andar).
const CHEF_WORK := Vector3(0.24, -0.32, 0.78)
const CHEF_LEAN := 5.0        ## inclinacion del tronco al trabajar
const CHEF_LOOK := 12.0       ## el cuello baja: mira lo que hace


func _chef_work(side: String) -> Vector3:
	var m := 1.0 if side == "L" else -1.0
	var sh := _rest(_idx["%s_Shoulder" % side])
	return Vector3(m * CHEF_WORK.x * _arm_len, sh.y + CHEF_WORK.y * _arm_len,
		sh.z + CHEF_WORK.z * _arm_len)


## Tronco inclinado sobre la mesa y mirada baja, comun a todos los gestos.
func _chef_lean() -> void:
	_pitch("Spine1", CHEF_LEAN * 0.5)
	_pitch("Spine2", CHEF_LEAN * 0.5)
	_pitch("Neck", CHEF_LOOK)


## Ambas manos en su punto de trabajo (postura base entre gestos).
func _chef_hands(r_off := Vector3.ZERO, l_off := Vector3.ZERO) -> void:
	var wr := _chef_work("R") + r_off
	var wl := _chef_work("L") + l_off
	_arm_ik("R", wr, wr + look_down())
	_arm_ik("L", wl, wl + look_down())
	_fist("L")
	_fist("R")


## Amasar/moldear (tap): la mano derecha palmea la masa; la izquierda sujeta.
func chef_pat(u: float) -> void:
	_chef_lean()
	var lift := 0.20 * _arm_len * absf(cos(PI * clampf(u, 0.0, 1.0)))
	_chef_hands(Vector3(0.0, lift, 0.0), Vector3(0.06 * _arm_len, 0.0, 0.0))


## Golpe de cuchillo (cut): la derecha sube y cae seca; la izquierda aguanta
## la pieza apartada del filo.
func chef_chop(u: float) -> void:
	_chef_lean()
	var v := clampf(u, 0.0, 1.0)
	# Sube suave y cae rapida: el pico esta pronto y el resto es la caida.
	var lift := 0.28 * _arm_len * sin(PI * pow(v, 0.7))
	_chef_hands(Vector3(-0.04 * _arm_len, lift, 0.02 * _arm_len),
		Vector3(0.14 * _arm_len, 0.0, 0.0))


## Corte LENTO de sashimi (slice): la derecha arrastra el cuchillo hacia su
## lado a la velocidad del gesto del jugador; la izquierda fija el lomo.
func chef_slice(u: float) -> void:
	_chef_lean()
	var v := smoothstep(0.0, 1.0, clampf(u, 0.0, 1.0))
	var draw := lerpf(0.14, -0.42, v) * _arm_len
	var sink := 0.04 * _arm_len * sin(PI * v)
	_chef_hands(Vector3(draw, -sink + 0.02 * _arm_len, 0.0),
		Vector3(0.16 * _arm_len, 0.02 * _arm_len, 0.0))


## Enrollar (swipe): las dos manos empujan la esterilla hacia delante y
## vuelven, con una pizca de descenso al empujar.
func chef_roll(u: float) -> void:
	_chef_lean()
	var v := sin(PI * clampf(u, 0.0, 1.0))
	var push := Vector3(0.0, -0.05 * _arm_len * v, 0.24 * _arm_len * v)
	_chef_hands(push, push)


## Remover la olla (stir/hold): la derecha describe un circulo con el cazo;
## la izquierda sujeta el borde de la olla.
func chef_stir(u: float) -> void:
	_chef_lean()
	var a := TAU * clampf(u, 0.0, 1.0)
	var r := 0.13 * _arm_len
	_chef_hands(Vector3(cos(a) * r, 0.10 * _arm_len, sin(a) * r * 0.7),
		Vector3(0.10 * _arm_len, 0.04 * _arm_len, -0.06 * _arm_len))


## Traer algo a la tabla (drag/select/serve): la derecha barre desde el
## costado hasta el centro pasando por lo alto; la izquierda espera.
func chef_place(u: float) -> void:
	_chef_lean()
	var v := smoothstep(0.0, 1.0, clampf(u, 0.0, 1.0))
	var side := Vector3(-0.45 * _arm_len, 0.10 * _arm_len, -0.25 * _arm_len)
	var via := Vector3(-0.22 * _arm_len, 0.26 * _arm_len, -0.10 * _arm_len)
	var off := _bezier(side, via, Vector3.ZERO, v)
	_chef_hands(off, Vector3(0.10 * _arm_len, 0.0, 0.0))


## Despejar la tabla (cancel): ambas manos barren hacia fuera.
func chef_clear(u: float) -> void:
	_chef_lean()
	var v := sin(PI * clampf(u, 0.0, 1.0))
	_chef_hands(Vector3(-0.30 * _arm_len * v, 0.06 * _arm_len * v, 0.0),
		Vector3(0.30 * _arm_len * v, 0.06 * _arm_len * v, 0.0))


## Plato terminado (done): ambas manos suben en celebracion breve.
func chef_cheer(u: float) -> void:
	var v := sin(PI * clampf(u, 0.0, 1.0))
	for side in ["L", "R"]:
		var m := 1.0 if side == "L" else -1.0
		var sh := _rest(_idx["%s_Shoulder" % side])
		var tgt := sh + Vector3(m * 0.30, -0.35 + 0.65 * v, 0.30) * _arm_len
		_arm_ik(side, tgt, tgt + Vector3(0.0, 0.5 * _arm_len, 0.0))
	_pitch("Neck", -6.0 * v)
	_fist("L")
	_fist("R")


## Sentado sin comer: respira y descansa las manos en los muslos.
func sit_idle(t: float) -> void:
	sit()
	var breath := sin(t / IDLE_PERIOD * TAU) * IDLE_BREATH
	_pitch("Spine2", SIT_LEAN * 0.5 + breath * 0.4)
	_pitch("Neck", -breath * 0.3)
	_arm_ik("L", hand_lap, hand_lap + look_down())
	var lap_r := Vector3(-hand_lap.x, hand_lap.y, hand_lap.z)
	_arm_ik("R", lap_r, lap_r + look_down())
	_fist("L")
	_fist("R")


## CANTO DE SIRENA (mar 2): el cliente atontado gira la cabeza hacia lo
## lejos y la mece despacio, como quien escucha algo que nadie mas oye. Se
## llama DESPUES de sit_idle y ACUMULA sobre esa pose (reset() ya paso).
func embobado(t: float) -> void:
	_yaw("Neck", 30.0 + sin(t * 0.8) * 8.0)
	_yaw("Head", 14.0)
	_pitch("Head", -7.0)


## Coloca la MANO de ese brazo sobre un punto del espacio del esqueleto,
## resolviendo hombro y codo. Es el mismo problema de dos huesos que la
## pierna, pero en el espacio: la pierna solo cabecea, mientras que el brazo
## tiene que cruzarse hacia el centro del cuerpo para llegar a la boca.
## `target` es donde va la MANO y `focus` adonde miran los dedos.
func _arm_ik(side: String, target: Vector3, focus: Vector3) -> void:
	if not arms_ok:
		return
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


## Deduce que hueso es cada cosa mirando la FORMA del esqueleto, sin fiarse de
## los nombres. Se apoya en rasgos que cumple cualquier bipedo:
##   - de la raiz cuelgan dos cadenas que bajan hasta el suelo: las PIERNAS,
##   - y una que sube: la COLUMNA,
##   - la columna se bifurca arriba en dos ramas laterales (los BRAZOS) y una
##     central que sigue subiendo (cuello y cabeza),
##   - dentro de cada brazo, la MUÑECA es el hueso del que salen los dedos,
##     que es el unico con tres o mas hijos.
## El lado izquierdo es el de +X, como en el resto del codigo.
func _detect_bones() -> void:
	var root := -1
	for i in _skel.get_bone_count():
		if _skel.get_bone_parent(i) < 0:
			root = i
			break
	if root < 0:
		return
	# Si la raiz es un nodo suelto sin carne, se baja al primer hueso con
	# varias ramas, que es la cadera de verdad.
	while _children(root).size() == 1:
		root = _children(root)[0]
	_name(&"Pelvis", root)

	# Primero se aparta la COLUMNA. Hace falta apartarla antes de buscar las
	# piernas porque ella tambien baja mucho: de ella cuelgan los brazos, que
	# llegan por debajo de la cadera.
	#
	# La columna es la rama que se lleva CASI TODO EL ESQUELETO: de ella salen
	# los dos brazos con sus dedos, el cuello y la cabeza. Se elige por NUMERO
	# DE HUESOS y no por altura, que es lo que se hacia antes. Varios rigs de
	# Ludo cuelgan de la cadera un MUÑON suelto de dos huesos (una cinta del
	# delantal, un mechon) que sube MAS ALTO que la coronilla, y ese muñon
	# ganaba la puntuacion; al tomarlo por columna, la "bifurcacion" de arriba
	# era su punta, que no tiene hijos, asi que el personaje se quedaba SIN
	# BRAZOS Y SIN CUELLO. El ayudante era exactamente eso.
	var up := -1
	var best := -1
	for c in _children(root):
		if _subtree_y(c, false) <= _rest(root).y:
			continue
		var size := _subtree_size(c)
		if size > best:
			best = size
			up = c
	# De lo que queda, las piernas son las dos ramas que mas bajan, UNA DE CADA
	# LADO. Quedarse sencillamente con las dos que mas bajan colaba ese mismo
	# muñon como segunda pierna, y entonces las dos se registraban del mismo
	# lado: el personaje se quedaba con media cadera y sin la otra pierna.
	var down: Array[int] = []
	for c in _children(root):
		if c != up and _subtree_y(c, true) < _rest(root).y:
			down.append(c)
	down.sort_custom(func(a, b): return _subtree_y(a, true) < _subtree_y(b, true))
	var legs: Array[int] = []
	if not down.is_empty():
		legs.append(down[0])
		var first_x: float = _rest(down[0]).x - _rest(root).x
		for c in down.slice(1):
			if (_rest(c).x - _rest(root).x) * first_x < 0.0:
				legs.append(c)
				break
	for leg in legs:
		var side := "L" if _rest(leg).x >= _rest(root).x else "R"
		var chain := _chain(leg, 3)
		var parts := ["%s_Hip" % side, "%s_Knee" % side, "%s_Ankle" % side]
		for k in mini(chain.size(), 3):
			_name(parts[k], chain[k])

	# La columna sube hasta bifurcarse; ahi salen los brazos y el cuello.
	if up < 0:
		return
	var spine := _chain_to_branch(up)
	for k in spine.size():
		_name("Spine%d" % (k + 1), spine[k])
	var fork: int = spine[spine.size() - 1]
	var arms: Array[int] = []
	var neck := -1
	var neck_lat := INF
	for c in _children(fork):
		var lat: float = absf(_rest(c).x - _rest(fork).x)
		if lat < neck_lat:
			neck_lat = lat
			neck = c
	for c in _children(fork):
		if c != neck:
			arms.append(c)
	if neck >= 0:
		_name(&"Neck", neck)
		var head := _chain(neck, 9)
		_name(&"Head", head[head.size() - 1])

	for arm in arms:
		var side := "L" if _rest(arm).x >= _rest(fork).x else "R"
		# La muñeca es el hueso del que salen los dedos.
		var wrist := _find_hand(arm)
		if wrist < 0:
			continue
		_name("%s_Wrist" % side, wrist)
		var elbow := _skel.get_bone_parent(wrist)
		var shoulder := _skel.get_bone_parent(elbow)
		_name("%s_Elbow" % side, elbow)
		_name("%s_Shoulder" % side, shoulder)
		var collar := _skel.get_bone_parent(shoulder)
		if collar != fork:
			_name("%s_Collar" % side, collar)


## Registra un hueso bajo su papel logico, SIN pisar el nombre que ya trajera
## el rig: si el auto-rig lo nombro, su nombre manda sobre la deduccion.
##
## Se probo lo contrario (que mandara siempre la forma) porque hay rigs cuyos
## nombres MIENTEN: el VIP femenino trae un "L_Wrist" que es un mechon de pelo
## sobre la coronilla. Pero al invertirlo se rompio el PIRATA, cuyos nombres son
## buenos y cuya forma engaña —su rig no tiene dedos, y la muñeca se busca por
## ser el hueso del que salen—, asi que se quedo el brazo en el 6% de su altura.
## Ninguna de las dos fuentes es fiable por si sola; lo que si detecta los dos
## casos es MEDIR el resultado, que es lo que hace `arms_ok` en _measure().
func _name(logical: StringName, idx: int) -> void:
	if not _idx.has(logical):
		_idx[logical] = idx


func _children(i: int) -> Array[int]:
	var out: Array[int] = []
	for j in _skel.get_bone_count():
		if _skel.get_bone_parent(j) == i:
			out.append(j)
	return out


func _rest(i: int) -> Vector3:
	return _skel.get_bone_global_rest(i).origin


## Cuantos huesos cuelgan de este, contandolo a el. Sirve para distinguir el
## TRONCO (que se lleva brazos, dedos, cuello y cabeza) de un muñon suelto.
func _subtree_size(i: int) -> int:
	var n := 1
	for c in _children(i):
		n += _subtree_size(c)
	return n


## Altura minima (o maxima) que alcanza toda la rama que cuelga de este hueso.
func _subtree_y(i: int, lowest: bool) -> float:
	var best := _rest(i).y
	for c in _children(i):
		var v := _subtree_y(c, lowest)
		best = minf(best, v) if lowest else maxf(best, v)
	return best


## Los primeros `n` huesos de una cadena, siguiendo siempre el hijo que mas
## se aleja del padre (el que continua el miembro, no un apendice).
func _chain(start: int, n: int) -> Array[int]:
	var out: Array[int] = [start]
	var cur := start
	while out.size() < n:
		var kids := _children(cur)
		if kids.is_empty():
			break
		var next := kids[0]
		var far := -1.0
		for k in kids:
			var d := _rest(k).distance_to(_rest(cur))
			if d > far:
				far = d
				next = k
		out.append(next)
		cur = next
	return out


## Sube por la cadena hasta el hueso que se bifurca (donde nacen los brazos).
func _chain_to_branch(start: int) -> Array[int]:
	var out: Array[int] = [start]
	var cur := start
	while _children(cur).size() == 1:
		cur = _children(cur)[0]
		out.append(cur)
	return out


## Dentro de un brazo, la muñeca: el hueso del que salen los dedos, que es el
## unico con tres o mas hijos. Hay rigs sin dedos —el del pirata no los tiene—
## y entonces la muñeca es sencillamente el extremo del brazo: devolver su
## padre, como hacia antes, desplazaba TODA la cadena un hueso y dejaba el
## "hombro" a la altura de la mano.
func _find_hand(start: int) -> int:
	var stack: Array[int] = [start]
	var far := start
	var far_d := -1.0
	while not stack.is_empty():
		var cur: int = stack.pop_back()
		var kids := _children(cur)
		if kids.size() >= 3:
			return cur
		var d := _rest(cur).distance_to(_rest(start))
		if kids.is_empty() and d > far_d:
			far_d = d
			far = cur
		stack.append_array(kids)
	return far


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
	return -crouch - absf(sin(cycle * TAU)) * body_bob


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
		return Vector2(lerpf(stride * 0.5, -stride * 0.5, u), ground - bob)
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
		return foot_lift * (0.5 - 0.5 * cos(PI * up))
	var down := (v - LIFT_PEAK_AT) / (1.0 - LIFT_PEAK_AT)
	return foot_lift * (0.5 + 0.5 * cos(PI * down))


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
	var half := stride * 0.5
	var slope := -stride * (1.0 - STANCE_FRAC) / STANCE_FRAC
	var v2 := v * v
	var v3 := v2 * v
	return -half * (2.0 * v3 - 3.0 * v2 + 1.0) \
		+ slope * (v3 - 2.0 * v2 + v) \
		+ half * (-2.0 * v3 + 3.0 * v2) \
		+ slope * (v3 - v2)


## Resuelve la pierna para que el tobillo caiga sobre su objetivo.
func _leg(side: StringName, cycle01: float, bob: float) -> void:
	var s := String(side)
	if not _legs.has(s) or not legs_ok:
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


## Adonde miran los dedos cuando tienen que mirar hacia abajo.
func look_down() -> Vector3:
	return Vector3(0.0, -LOOK_DOWN_F * _arm_len, 0.0)


## Curva suave que pasa cerca de `via` al ir de `from` a `to`.
func _bezier(from: Vector3, via: Vector3, to: Vector3, w: float) -> Vector3:
	return from.lerp(via, w).lerp(via.lerp(to, w), w)


## Lo adelantada que va la pierna en este instante: +1 con el pie lo mas
## adelante posible, -1 lo mas atras. Es la misma curva que sigue el pie, asi
## que sirve para mover los brazos exactamente al ritmo de las piernas.
func _leg_swing(cycle01: float) -> float:
	var z: float
	if cycle01 < STANCE_FRAC:
		z = lerpf(stride * 0.5, -stride * 0.5, cycle01 / STANCE_FRAC)
	else:
		z = _swing_z((cycle01 - STANCE_FRAC) / (1.0 - STANCE_FRAC))
	return clampf(z / (stride * 0.5), -1.0, 1.0)


## `swing`: +1 = ese brazo del todo hacia delante, -1 del todo hacia atras.
func _arm(side: String, swing: float) -> void:
	if not arms_ok:
		return
	# El hombro entero acompaña al brazo, con el giro repartido entre la
	# clavicula y el hombro para que el movimiento salga del torso.
	_pitch("%s_Collar" % side, -COLLAR_SWING * swing)
	# La clavicula se levanta al llevar el brazo atras. El lado derecho es el
	# espejo del izquierdo, de ahi el cambio de signo.
	var mirror := 1.0 if side == "L" else -1.0
	_roll("%s_Collar" % side, mirror * COLLAR_LIFT * maxf(0.0, -swing))
	# Recogido al costado ANTES del balanceo: si no, la zancada de brazos
	# arrancaba desde la pose de A y el personaje andaba en cruz.
	var tuck := -1.0 if side == "L" else 1.0
	_roll("%s_Shoulder" % side, tuck * arm_tuck)
	_pitch("%s_Shoulder" % side, -ARM_SWING * swing)
	_pitch("%s_Elbow" % side, -ELBOW_BEND - maxf(0.0, swing) * ELBOW_BEND)
	_fist(side)


## Cierra la mano. Al andar los puños van cerrados, no con los dedos
## estirados: abiertos parece que el personaje sujete algo.
func _fist(side: String) -> void:
	if not _fingers.has(side):
		return
	# Si el auto-rig dejo la mano con menos dedos de los que se ven en la
	# malla, cerrar los pocos que hay deforma el puño en vez de cerrarlo: la
	# carne de los dedos sin hueso se queda estirada. En ese caso mas vale
	# dejar la mano como se modelo. Al pirata le rigueo solo dos dedos.
	if _fingers[side]["fingers"].size() < 6:
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
