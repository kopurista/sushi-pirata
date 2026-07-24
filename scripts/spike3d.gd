extends Node3D
# ESCENA DE PRUEBA TEMPORAL — validar look low poly, camara isometrica y
# animacion procedural de mallas SIN rig.
# Borrar junto con scenes/spike3d.tscn cuando termine la validacion.

const GRUMETE := preload("res://assets/models/grumete.glb")
const GRUMETE_SIT := preload("res://assets/models/grumete_sentado.glb")
const NIGIRI := preload("res://assets/models/nigiri_salmon.glb")

const CAM_ROT := Vector3(-35.264, 45.0, 0.0)
const BODY_H := 1.75
const SEAT_H := 1.30      # altura de la figura sentada, de pies a cabeza

# --- Dos estilos de animacion a comparar ---
# SOFT: imita un paso humano. Discreto, pero con las piernas estaticas lee
#       como "flotar" mas que como andar.
# HOP:  renuncia a imitar el paso y salta. La pierna quieta deja de ser un
#       error y pasa a ser parte del lenguaje visual (estilo Crossy Road).
const STYLE_SOFT := {
	"step_hz": 1.9, "bob": 0.055, "squash": 0.07, "stretch": 0.0,
	"roll": 5.0, "yaw": 3.0, "pitch": 6.0, "hang": 1.0,
}
const STYLE_HOP := {
	"step_hz": 1.55, "bob": 0.135, "squash": 0.20, "stretch": 0.07,
	"roll": 8.0, "yaw": 4.0, "pitch": 8.0, "hang": 0.62,
}

var _walker: Node3D
var _shots := 0
var _t := 0.0
var _strip_done := false


# Poner a true para el diagnostico del modelo sentado que sale oscuro.
const DIAG := false


func _ready() -> void:
	if DIAG:
		_setup_diag()
		return
	_setup_world(self)
	_setup_camera(self, Vector3(9.0, 9.0, 9.0), 7.5)
	_setup_deck()
	_setup_belt()
	_setup_dishes()
	_setup_seated()
	# Un caminante recorriendo la cubierta, visto desde la camara del juego.
	_walker = _spawn(GRUMETE, Vector3(-3.0, 0.0, 2.4), BODY_H)
	_build_phase_strip("StripSoft", STYLE_SOFT)
	_build_phase_strip("StripHop", STYLE_HOP)


# ---------------------------------------------------------------- escenario

func _setup_world(root: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.62, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.78, 0.88)
	env.ambient_light_energy = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -125.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	root.add_child(sun)


func _setup_camera(root: Node, pos: Vector3, size: float) -> Camera3D:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = CAM_ROT
	cam.position = pos
	cam.size = size
	root.add_child(cam)
	cam.make_current()
	return cam


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	m.metallic = 0.0
	return m


func _box(root: Node, size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _mat(color)
	root.add_child(mi)


func _setup_deck() -> void:
	for i in range(22):
		var tone := 0.0 if i % 2 == 0 else 0.04
		_box(self, Vector3(13.0, 0.2, 0.44), Vector3(0.0, -0.1, -4.84 + i * 0.44),
			Color(0.52 + tone, 0.35 + tone, 0.20 + tone))


func _setup_belt() -> void:
	_box(self, Vector3(11.0, 0.16, 1.1), Vector3(0.0, 0.08, 0.0), Color(0.16, 0.17, 0.20))
	_box(self, Vector3(11.0, 0.10, 0.12), Vector3(0.0, 0.16, 0.61), Color(0.60, 0.62, 0.66))
	_box(self, Vector3(11.0, 0.10, 0.12), Vector3(0.0, 0.16, -0.61), Color(0.60, 0.62, 0.66))


func _setup_dishes() -> void:
	for i in range(4):
		_spawn(NIGIRI, Vector3(-3.2 + i * 1.9, 0.16, 0.0), 0.17)


# Clientes sentados al otro lado de la cinta, cada uno sobre un taburete.
# Se prueban cuatro giros distintos porque el modelo se genero a partir de
# una vista lateral y hay que ver hacia donde mira de verdad.
func _setup_seated() -> void:
	# El taburete se coloca a la altura de la cadera de la figura sentada
	# (~0.36 de su altura total), para que apoye en vez de flotar.
	var seat_top := SEAT_H * 0.36
	for i in range(4):
		var x := -3.3 + i * 2.2
		var seat := Vector3(x, 0.0, -1.75)
		_box(self, Vector3(0.46, 0.09, 0.46),
			seat + Vector3(0.0, seat_top - 0.045, 0.0), Color(0.40, 0.26, 0.15))
		_box(self, Vector3(0.11, seat_top - 0.09, 0.11),
			seat + Vector3(0.0, (seat_top - 0.09) * 0.5, 0.0), Color(0.34, 0.22, 0.13))
		var pivot := _spawn(GRUMETE_SIT, seat, SEAT_H)
		pivot.rotation_degrees.y = [0.0, 90.0, 180.0, 270.0][i]


# ------------------------------------------------------------ instanciacion

# Devuelve un PIVOTE situado en el suelo, con el modelo ya centrado en XZ,
# apoyado en y=0 y escalado a target_h. Animar SIEMPRE el pivote: asi el
# squash ocurre desde los pies y no desde el centro del cuerpo.
func _spawn(scene: PackedScene, ground_pos: Vector3, target_h: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = ground_pos
	add_child(pivot)
	_fill_pivot(pivot, scene, target_h)
	return pivot


func _fill_pivot(pivot: Node3D, scene: PackedScene, target_h: float) -> void:
	var inst: Node3D = scene.instantiate()
	pivot.add_child(inst)
	var aabb := _merged_aabb(inst)
	var s := target_h / maxf(aabb.size.y, 0.0001)
	inst.scale = Vector3(s, s, s)
	inst.position = -Vector3(
		aabb.position.x + aabb.size.x * 0.5,
		aabb.position.y,
		aabb.position.z + aabb.size.z * 0.5) * s


func _merged_aabb(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in _all_meshes(node):
		var a: AABB = m.transform * m.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out


func _all_meshes(node: Node) -> Array:
	var found: Array = []
	if node is MeshInstance3D:
		found.append(node)
	for c in node.get_children():
		found.append_array(_all_meshes(c))
	return found


# -------------------------------------------------------------- el caminado

# Aplica un ciclo de marcha a una malla ESTATICA. La idea: el cuerpo rebota
# una vez por paso, se comprime al apoyar y se balancea una vez por zancada
# (= cada dos pasos). Las piernas no se mueven, pero el modelo ya viene con
# una pierna adelantada, y eso basta para leerlo como marcha.
func _apply_walk(pivot: Node3D, ground_y: float, facing_yaw: float, t: float,
		st: Dictionary) -> void:
	var phase: float = t * st["step_hz"] * TAU
	# hang < 1 hace que el cuerpo se quede mas tiempo arriba: da sensacion de
	# salto en vez de rebote sinusoidal.
	var lift: float = pow(absf(sin(phase)), st["hang"])
	var stride := sin(phase * 0.5)          # una oscilacion por zancada
	var land := pow(1.0 - lift, 2.5)        # pico brusco solo al aterrizar

	# Rebote vertical.
	pivot.position.y = ground_y + lift * st["bob"] * BODY_H

	# Squash al aterrizar + stretch en el aire, conservando volumen.
	var sy: float = 1.0 + st["stretch"] * lift - st["squash"] * land
	var sxz := 1.0 / sqrt(sy)
	pivot.scale = Vector3(sxz, sy, sxz)

	# Balanceo lateral + oscilacion del giro + inclinacion hacia delante.
	pivot.rotation_degrees = Vector3(
		st["pitch"],
		facing_yaw + stride * st["yaw"],
		stride * st["roll"])


# Tira de fotogramas: seis copias congeladas en seis fases del ciclo, para
# juzgar el rango de poses de un vistazo en una sola imagen.
func _build_phase_strip(vp_name: String, st: Dictionary) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1440, 560)
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	vp.name = vp_name

	var root := Node3D.new()
	vp.add_child(root)
	_setup_world(root)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = CAM_ROT
	# Subir la camara para centrar el encuadre en el torso, no en los pies.
	cam.position = Vector3(9.0, 10.0, 9.0)
	cam.size = 3.7
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	root.add_child(cam)
	cam.make_current()

	# Direccion horizontal EN PANTALLA para una camara con yaw 45.
	var screen_right := Vector3(1.0, 0.0, -1.0).normalized()
	var period: float = 1.0 / st["step_hz"]

	for i in range(6):
		var pivot := Node3D.new()
		root.add_child(pivot)
		_fill_pivot(pivot, GRUMETE, BODY_H)
		var base := screen_right * (float(i) - 2.5) * 1.6
		# Suelo bajo cada copia, para ver el rebote contra una referencia.
		_box(root, Vector3(1.1, 0.16, 1.1), base + Vector3(0.0, -0.08, 0.0),
			Color(0.52, 0.35, 0.20))
		pivot.position = base
		# Medio ciclo basta: la otra mitad es el mismo salto con el balanceo
		# invertido, asi se aprovechan las 6 casillas en el rango util.
		_apply_walk(pivot, 0.0, 200.0, (float(i) / 6.0) * period * 0.5, st)


# Cuatro variantes del mismo modelo para aislar por que sale oscuro:
# 0 = tal cual se importa
# 1 = material propio con la textura y SIN descarte de caras traseras
# 2 = material propio con la textura y SIN sombreado (unshaded)
# 3 = blanco liso con sombreado, para ver las normales sin la textura
func _setup_diag() -> void:
	_setup_world(self)
	var cam := _setup_camera(self, Vector3(9.0, 9.6, 9.0), 3.4)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT

	var tex: Texture2D = load("res://assets/models/grumete_sentado_0.png")
	var screen_right := Vector3(1.0, 0.0, -1.0).normalized()

	for i in range(4):
		var pivot := Node3D.new()
		add_child(pivot)
		_fill_pivot(pivot, GRUMETE_SIT, SEAT_H)
		pivot.position = screen_right * (float(i) - 1.5) * 1.5

		if i == 0:
			continue
		var m := StandardMaterial3D.new()
		if i < 3:
			m.albedo_texture = tex
		else:
			m.albedo_color = Color(0.85, 0.85, 0.85)
		if i == 1:
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if i == 2:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for mi in _all_meshes(pivot):
			mi.material_override = m


func _process(delta: float) -> void:
	if DIAG:
		_t += delta
		if _t > 0.4 and _shots == 0:
			_shots = 1
			get_viewport().get_texture().get_image().save_png("res://spike_diag.png")
			print("DIAG OK")
			get_tree().quit()
		return
	_t += delta

	# El caminante avanza en bucle por la cubierta.
	var travel := fmod(_t * 1.35, 6.4)
	var p := _walker.position
	p.x = -3.2 + travel
	_walker.position = p
	_apply_walk(_walker, 0.0, 200.0, _t, STYLE_HOP)

	if not _strip_done and _t > 0.35:
		_strip_done = true
		for pair in [["StripSoft", "soft"], ["StripHop", "hop"]]:
			var strip: SubViewport = get_node(pair[0])
			strip.get_texture().get_image().save_png(
				"res://spike_phases_%s.png" % pair[1])
		print("STRIPS OK")

	# Cuatro fotogramas seguidos del caminante en contexto.
	if _strip_done and _shots < 4 and fmod(_t, 0.14) < delta:
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://spike_walk_%d.png" % _shots)
		_shots += 1
		if _shots == 4:
			print("FRAMES OK")
			get_tree().quit()
