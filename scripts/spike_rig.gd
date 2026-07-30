extends Node3D
# BANCO DE PRUEBAS TEMPORAL del pipeline de rigging de Ludo:
# fusionar el clip de un GLB solo-animacion con el modelo rigueado.
# Borrar junto con scenes/spike_rig.tscn al terminar la validacion.
#
# Hallazgo del diagnostico: el GLB de animacion trae los huesos como NODOS
# (sin skin) y pistas por ruta de nodo (bone_0/bone_1/...); el modelo
# rigueado tiene Skeleton3D con huesos del mismo nombre. El retarget mapea
# cada ruta de nodo a "Skeleton3D:<hueso>" (el nombre hoja), manteniendo el
# tipo de pista: la semantica coincide (transform local respecto al padre).

# Rig de PIE (pesos limpios) y sus clips: la generacion actual.
const RIGGED := preload("res://assets/models/grumete_rig.glb")
const ANIM_EAT_A := preload("res://assets/models/anim_sit_eat.glb")
const ANIM_EAT_B := preload("res://assets/models/anim_sit_eat_b.glb")
const ANIM_WALK_A := preload("res://assets/models/anim_walk.glb")

const SEAT_H := 1.75    # el rig es el modelo DE PIE; los clips lo sientan
const DIAG := false

var _t := 0.0
# Vacio = modo demo (no captura ni cierra); para verificar por captura,
# poner p.ej. [0.2, 0.6, 1.0, 1.4, 1.8, 2.2].
var _shots := [0.15, 0.45, 0.75, 1.05, 1.35, 1.65]
var _idx := 0


func _ready() -> void:
	if DIAG:
		var inst: Node3D = RIGGED.instantiate()
		add_child(inst)
		var skel: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
		for i in [BONE_SHOULDER, BONE_ELBOW, BONE_HEAD]:
			var b := skel.get_bone_global_rest(i).basis
			print("hueso %d %s:" % [i, skel.get_bone_name(i)])
			print("  X local -> esqueleto (%.2f, %.2f, %.2f)" % [b.x.x, b.x.y, b.x.z])
			print("  Y local -> esqueleto (%.2f, %.2f, %.2f)" % [b.y.x, b.y.y, b.y.z])
			print("  Z local -> esqueleto (%.2f, %.2f, %.2f)" % [b.z.x, b.z.y, b.z.z])
		get_tree().quit()
		return

	_setup_world()
	var right := Vector3(1.0, 0.0, -1.0) / sqrt(2.0)
	if AXIS_TEST == "grid":
		# Rejilla de poses candidatas [hombro, codo] sobre X (negativo =
		# adelante/arriba): buscar la que deja la mano en la boca.
		var combos := [[-35.0, -70.0], [-50.0, -80.0], [-60.0, -95.0],
			[-45.0, -110.0], [-70.0, -60.0]]
		for i in combos.size():
			var fig := _spawn_rigged(right * (i - 2) * 1.5, null, "")
			var skel: Skeleton3D = fig.find_children("*", "Skeleton3D", true, false)[0]
			_pose_bone_local(skel, BONE_SHOULDER, Vector3(1, 0, 0), combos[i][0])
			_pose_bone_local(skel, BONE_ELBOW, Vector3(1, 0, 0), combos[i][1])
		return
	# Diagnostico de brillo: original SIN rig vs rigueado, misma escena.
	var original: Node3D = (load("res://assets/models/grumete.glb") as PackedScene).instantiate()
	add_child(original)
	var aabb0 := _merged_aabb(original)
	var s0 := SEAT_H / maxf(aabb0.size.y, 0.0001)
	original.scale = Vector3(s0, s0, s0)
	original.position = right * -1.55 - Vector3(aabb0.position.x + aabb0.size.x * 0.5,
		aabb0.position.y, aabb0.position.z + aabb0.size.z * 0.5) * s0
	original.rotation_degrees.y = 30.0
	_spawn_rigged(Vector3.ZERO, null, "")
	_spawn_rigged(right * 1.55, ANIM_WALK_A, "The character walks forward at 6")


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
	cam.size = 9.5
	add_child(cam)
	cam.position = Vector3(0.0, 0.6, 0.0) + cam.transform.basis.z * 20.0
	cam.make_current()

	# Suelo de referencia.
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(12.0, 0.2, 12.0)
	var mi := MeshInstance3D.new()
	mi.mesh = floor_mesh
	mi.position = Vector3(0.0, -0.1, 0.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.52, 0.35, 0.20)
	m.roughness = 0.95
	mi.material_override = m
	add_child(mi)


# --- Bocado procedural: 4 fases sobre hombro (bone_4), codo (bone_5) y
# --- cabeza (bone_7), rotando en espacio del personaje. Sin loteria de IA.
const BONE_SHOULDER := 4
const BONE_ELBOW := 5
const BONE_HEAD := 7
const BITE_LEN := 1.7      # duracion de un bocado completo
# "grid" = rejilla de poses hombro/codo; "" = comparativa de animaciones.
const AXIS_TEST := ""
# Fases (fraccion del ciclo): alcanzar 0-0.25, subir 0.25-0.45,
# masticar 0.45-0.78, bajar 0.78-1.
# Poses clave [angulo_hombro, (reservado), angulo_codo] en grados.
const POSE_REST := [0.0, 0.0, 0.0]
const POSE_REACH := [48.0, 0.0, -12.0]
const POSE_MOUTH := [14.0, 0.0, -108.0]
# Ejes locales de bisagra por hueso (se determinan con AXIS_TEST).
const SHOULDER_AXIS := Vector3(1, 0, 0)
const ELBOW_AXIS := Vector3(1, 0, 0)
const HEAD_AXIS := Vector3(1, 0, 0)

var _proc_skel: Skeleton3D


func _apply_bite(skel: Skeleton3D, t: float) -> void:
	var u := fmod(t, BITE_LEN) / BITE_LEN
	var pose: Array
	var nod := 0.0
	if u < 0.25:
		pose = _mix(POSE_REST, POSE_REACH, smoothstep(0.0, 1.0, u / 0.25))
	elif u < 0.45:
		pose = _mix(POSE_REACH, POSE_MOUTH, smoothstep(0.0, 1.0, (u - 0.25) / 0.2))
	elif u < 0.78:
		pose = POSE_MOUTH
		nod = sin((u - 0.45) * 34.0) * 6.0   # cabeceo al masticar
	else:
		pose = _mix(POSE_MOUTH, POSE_REST, smoothstep(0.0, 1.0, (u - 0.78) / 0.22))
	# Ejes locales por hueso: se fijan tras el test de ejes (AXIS_TEST).
	_pose_bone_local(skel, BONE_SHOULDER, SHOULDER_AXIS, pose[0])
	_pose_bone_local(skel, BONE_ELBOW, ELBOW_AXIS, pose[2])
	_pose_bone_local(skel, BONE_HEAD, HEAD_AXIS, nod)


func _mix(a: Array, b: Array, w: float) -> Array:
	return [lerpf(a[0], b[0], w), lerpf(a[1], b[1], w), lerpf(a[2], b[2], w)]


# Rota el hueso sobre su propio eje LOCAL respecto a la pose de reposo.
# Local puro: sin depender de la pose global del padre (que puede estar sin
# refrescar a mitad de frame) y sin giro parasito sobre el eje del hueso.
func _pose_bone_local(skel: Skeleton3D, idx: int, axis: Vector3, deg: float) -> void:
	var rest_rot := skel.get_bone_rest(idx).basis.get_rotation_quaternion()
	skel.set_bone_pose_rotation(idx,
		rest_rot * Quaternion(axis.normalized(), deg_to_rad(deg)))


func _spawn_rigged(pos: Vector3, anim_scene: PackedScene, clip: String) -> Node3D:
	var model: Node3D = RIGGED.instantiate()
	add_child(model)
	# Normalizar por altura como los personajes del esqueleto.
	var aabb := _merged_aabb(model)
	var s := SEAT_H / maxf(aabb.size.y, 0.0001)
	model.scale = Vector3(s, s, s)
	model.position = pos - Vector3(aabb.position.x + aabb.size.x * 0.5, aabb.position.y,
		aabb.position.z + aabb.size.z * 0.5) * s
	model.rotation_degrees.y = 30.0

	if anim_scene == null:
		return model
	var anim_root: Node = anim_scene.instantiate()
	var src_ap: AnimationPlayer = anim_root.find_children("*", "AnimationPlayer",
		true, false)[0]
	var anim: Animation = src_ap.get_animation(clip).duplicate(true)
	anim.loop_mode = Animation.LOOP_LINEAR
	for i in anim.get_track_count():
		var leaf := String(anim.track_get_path(i)).get_slice("/",
			String(anim.track_get_path(i)).get_slice_count("/") - 1)
		anim.track_set_path(i, NodePath("Skeleton3D:%s" % leaf))
	anim_root.free()

	var ap := AnimationPlayer.new()
	model.add_child(ap)
	ap.root_node = NodePath("..")
	var lib := AnimationLibrary.new()
	lib.add_animation("clip", anim)
	ap.add_animation_library("", lib)
	ap.play("clip")
	return model


func _merged_aabb(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = m.transform * m.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


func _print_tree(root: Node, label: String) -> void:
	print("=== %s ===" % label)
	_walk(root, 0)
	for ap in root.find_children("*", "AnimationPlayer", true, false):
		for anim_name in ap.get_animation_list():
			var anim: Animation = ap.get_animation(anim_name)
			print("  clip '%s' len %.2f pistas %d" % [anim_name, anim.length,
				anim.get_track_count()])
			for i in range(mini(anim.get_track_count(), 6)):
				print("    pista %d tipo %d ruta %s" % [i, anim.track_get_type(i),
					anim.track_get_path(i)])
	root.free()


func _walk(node: Node, depth: int) -> void:
	var extra := ""
	if node is Skeleton3D:
		extra = " [Skeleton3D, %d huesos]" % node.get_bone_count()
	print("%s%s (%s)%s" % ["  ".repeat(depth), node.name, node.get_class(), extra])
	for c in node.get_children():
		_walk(c, depth + 1)


func _process(delta: float) -> void:
	_t += delta
	if _proc_skel:
		_apply_bite(_proc_skel, _t)
	if _idx < _shots.size() and _t >= _shots[_idx]:
		get_viewport().get_texture().get_image().save_png(
			"res://rig_shot_%d.png" % _idx)
		_idx += 1
		if _idx == _shots.size():
			print("RIG SHOTS OK")
			get_tree().quit()
