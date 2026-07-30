extends Node3D
## BANCO DE PRUEBAS TEMPORAL de la animacion de personajes.
## Borrar junto con scenes/spike_rig.tscn cuando el port a client.gd termine.
##
## Verifica el ciclo de marcha procedural de CharacterAnim con la MISMA medida
## que tools/gait_check.py aplica a los clips de IA: trayectoria de cada pie
## respecto a la cadera, y correlacion entre ambas. Un andar correcto exige
## correlacion muy negativa (los pies alternan) y recorrido parecido en los dos.

const RIGGED := preload("res://assets/models/grumete_rig.glb")
const BODY_H := 1.75

# true = anda sin avanzar, para comparar las piernas fotograma a fotograma.
const WALK_IN_PLACE := false

var _anim: CharacterAnim
var _skel: Skeleton3D
var _pivot: Node3D
var _speed := 0.0             # se deduce del ciclo, para que los pies no patinen
var _model_scale := 1.0
var _t := 0.0
var _shots := []
var _idx := 0


func _ready() -> void:
	_setup_world()
	_pivot = _spawn(Vector3.ZERO)
	_skel = _pivot.find_children("*", "Skeleton3D", true, false)[0]
	_anim = CharacterAnim.new(_skel)
	if not _anim.has_humanoid_bones():
		push_error("el rig no trae huesos humanoides con nombre")
	_speed = _anim.ground_speed(_model_scale)
	print(_gait_report())
	print("                 avance sin patinar: %.2f u/s" % _speed)


# ---------------------------------------------------------------- escenario

func _setup_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.62, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.78, 0.88)
	env.ambient_light_energy = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -125.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(-35.264, 45.0, 0.0)
	cam.size = 4.0
	add_child(cam)
	cam.position = Vector3(0.0, 0.85, 0.0) + cam.transform.basis.z * 20.0
	cam.make_current()

	# Suelo a rayas: da referencia para juzgar el avance de los pies.
	for i in range(24):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(14.0, 0.2, 0.45)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = Vector3(0.0, -0.1, -5.4 + i * 0.45)
		var m := StandardMaterial3D.new()
		var tone := 0.0 if i % 2 == 0 else 0.05
		m.albedo_color = Color(0.52 + tone, 0.35 + tone, 0.20 + tone)
		m.roughness = 0.95
		mi.material_override = m
		add_child(mi)


func _spawn(ground_pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = ground_pos
	add_child(pivot)
	var inst: Node3D = RIGGED.instantiate()
	pivot.add_child(inst)
	var aabb := _merged_aabb(inst)
	var s := BODY_H / maxf(aabb.size.y, 0.0001)
	_model_scale = s
	inst.scale = Vector3(s, s, s)
	inst.position = -Vector3(aabb.position.x + aabb.size.x * 0.5, aabb.position.y,
		aabb.position.z + aabb.size.z * 0.5) * s
	return pivot


func _merged_aabb(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = m.transform * m.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


# ----------------------------------------------------------- verificacion

## Muestrea el ciclo y mide lo mismo que tools/gait_check.py.
func _gait_report(samples := 72) -> String:
	var li := _skel.find_bone("L_Ankle")
	var ri := _skel.find_bone("R_Ankle")
	var pi := _skel.find_bone("Pelvis")
	var hi := _skel.find_bone("L_Hip")
	var ki := _skel.find_bone("L_Knee")
	var lz: Array[float] = []
	var rz: Array[float] = []
	var ly: Array[float] = []
	var flex: Array[float] = []
	for i in samples:
		var t := CharacterAnim.WALK_PERIOD * float(i) / float(samples)
		_anim.reset()
		_anim.walk(t)
		var hip := _skel.get_bone_global_pose(pi).origin
		lz.append(_skel.get_bone_global_pose(li).origin.z - hip.z)
		rz.append(_skel.get_bone_global_pose(ri).origin.z - hip.z)
		ly.append(_skel.get_bone_global_pose(li).origin.y - hip.y)
		# Angulo con signo entre muslo y espinilla en el plano sagital. En una
		# rodilla humana la espinilla SOLO puede ir hacia atras respecto al
		# muslo: si este valor sale negativo, la rodilla dobla al reves.
		var thigh := _skel.get_bone_global_pose(ki).origin \
			- _skel.get_bone_global_pose(hi).origin
		var shin := _skel.get_bone_global_pose(li).origin \
			- _skel.get_bone_global_pose(ki).origin
		flex.append(rad_to_deg(atan2(thigh.y * shin.z - thigh.z * shin.y,
			thigh.y * shin.y + thigh.z * shin.z)))
	_anim.reset()

	var amp_l: float = lz.max() - lz.min()
	var amp_r: float = rz.max() - rz.min()
	var lift: float = ly.max() - ly.min()
	var corr := _pearson(lz, rz)
	var crossings := 0
	for i in range(1, samples):
		if (lz[i - 1] - rz[i - 1]) * (lz[i] - rz[i]) < 0.0:
			crossings += 1
	var flex_min: float = flex.min()
	var flex_max: float = flex.max()
	var slide := _stance_slide(samples)
	var jerk := _toe_off_jerk()
	# Velocidad angular maxima de la rodilla. Cerca de la extension completa
	# la cinematica inversa se vuelve inestable (la derivada del acos se
	# dispara) y la rodilla pega un chasquido: se ve aqui como un pico.
	var knee_rate := 0.0
	var dt_s := CharacterAnim.WALK_PERIOD / float(samples)
	for i in samples:
		knee_rate = maxf(knee_rate,
			absf(flex[(i + 1) % samples] - flex[i]) / dt_s)
	# La correlacion no llega a -1 aunque las piernas alternen perfectamente:
	# solo una trayectoria SENOIDAL da -1, y la del pie no lo es (empuja al
	# despegar y se recoge antes de posarse). Lo que garantiza la alternancia
	# es que las dos piernas van desfasadas medio ciclo por construccion, y
	# que se cruzan dos veces; el umbral se afloja en consecuencia.
	var ok := corr < -0.8 and minf(amp_l, amp_r) / maxf(amp_l, amp_r) > 0.9 \
		and crossings >= 2 and flex_min > -3.0 and flex_max > 20.0 \
		and slide < 0.06
	return ("CICLO DE MARCHA: recorrido pie L %.3f  pie R %.3f  elevacion %.3f\n"
		+ "                 antifase %+.2f  cruces %d\n"
		+ "                 rodilla: flexion de %+.1f a %+.1f grados%s\n"
		+ "                 patinaje del pie apoyado: %.3f u   tiron: %.2f\n"
		+ "                 chasquido de rodilla: %.0f grados/s\n"
		+ "                 -> %s") % [
		amp_l, amp_r, lift, corr, crossings, flex_min, flex_max,
		"  (NEGATIVO = dobla al reves)" if flex_min < -3.0 else "",
		slide, jerk, knee_rate, "CORRECTO" if ok else "REVISAR"]


## Salto de velocidad del pie en el instante en que deja de pisar y empieza a
## volar. Es EL sitio donde se percibe el tiron: si el pie viene retrocediendo
## a una velocidad y de golpe pasa a otra, se ve como una sacudida. Se mide con
## muestreo fino a los dos lados del relevo, en unidades de mundo por segundo.
func _toe_off_jerk() -> float:
	var la := _skel.find_bone("L_Ankle")
	var t_off := CharacterAnim.WALK_PERIOD * CharacterAnim.STANCE_FRAC
	var dt := CharacterAnim.WALK_PERIOD * 0.0005
	var before := (_foot_at(la, t_off - dt) - _foot_at(la, t_off - 2.0 * dt)) / dt
	var after := (_foot_at(la, t_off + 2.0 * dt) - _foot_at(la, t_off + dt)) / dt
	_anim.reset()
	return (after - before).length()


## Posicion del pie en el mundo (avance del cuerpo incluido) en el instante t.
func _foot_at(bone: int, t: float) -> Vector2:
	_anim.reset()
	_anim.walk(t)
	var p := _skel.get_bone_global_pose(bone).origin
	return Vector2(_anim.walk_advance(t, _model_scale) + p.z * _model_scale,
		_anim.walk_bob(t, _model_scale) + p.y * _model_scale)


## Cuanto se mueve por el suelo el pie que esta pisando, ya contando el avance
## del cuerpo. En un andar bien resuelto tiene que ser casi cero: el pie se
## queda clavado y es el cuerpo el que pasa por encima.
func _stance_slide(samples: int) -> float:
	var la := _skel.find_bone("L_Ankle")
	# Se mide el pie IZQUIERDO durante su apoyo, que por definicion del ciclo
	# va de 0 a STANCE_FRAC. Deducirlo de "que pie esta mas bajo" engaña: al
	# despegar suave el pie sigue cerca del suelo aunque ya vuele, y esos
	# fotogramas se contaban como patinaje que no existe.
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var n := int(samples * CharacterAnim.STANCE_FRAC)
	for i in n:
		var t := CharacterAnim.WALK_PERIOD * float(i) / float(samples)
		# Posicion del pie en el MUNDO, avance y altura del cuerpo incluidos.
		var p := _foot_at(la, t)
		lo = lo.min(p)
		hi = hi.max(p)
	_anim.reset()
	# Se devuelve el mayor de los dos: da igual que el pie derrape hacia
	# delante o que se hunda en la cubierta, las dos cosas se ven.
	return maxf(hi.x - lo.x, hi.y - lo.y)


func _pearson(a: Array[float], b: Array[float]) -> float:
	var n := a.size()
	var ma := 0.0
	var mb := 0.0
	for i in n:
		ma += a[i]
		mb += b[i]
	ma /= n
	mb /= n
	var num := 0.0
	var da := 0.0
	var db := 0.0
	for i in n:
		num += (a[i] - ma) * (b[i] - mb)
		da += (a[i] - ma) ** 2
		db += (b[i] - mb) ** 2
	return 0.0 if da == 0.0 or db == 0.0 else num / sqrt(da * db)


# ------------------------------------------------------------------ bucle

func _process(delta: float) -> void:
	_t += delta
	_anim.reset()
	_anim.walk(_t)
	# Avanza de verdad por la cubierta, con el rebote del ciclo.
	# El avance sale de las piernas, no de una velocidad impuesta.
	var travel := 0.0 if WALK_IN_PLACE \
		else fmod(_anim.walk_advance(_t, _model_scale), 7.0) - 3.5
	var dir := Vector3(1.0, 0.0, -1.0).normalized()
	_pivot.position = dir * travel + Vector3.UP * _anim.walk_bob(_t, _model_scale)
	_pivot.rotation_degrees.y = rad_to_deg(atan2(dir.x, dir.z))

	if _idx < _shots.size() and _t >= _shots[_idx]:
		get_viewport().get_texture().get_image().save_png(
			"res://rig_shot_%d.png" % _idx)
		_idx += 1
		if _idx == _shots.size():
			print("SHOTS OK")
			get_tree().quit()
