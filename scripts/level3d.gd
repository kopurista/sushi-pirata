extends Node3D
# ESQUELETO del nivel en 3D — define la estructura y el sistema de coordenadas
# sobre los que la tarea de port montara la logica real de level.gd.
#
# CONTRATO DE COORDENADAS (derivado del layout 2D para reproducirlo):
# - Camara isometrica ortogonal: pitch -35.264, yaw 45, size 15.
#   Con el viewport 720x1280 eso da ~85.3 px por unidad de mundo.
# - La cinta 2D era un rombo de 436x256 px = un CUADRADO de lado 3.6 u en
#   verdadera isometria (el juego 2D ya dibujaba iso real: 256/436 = 0.587 =
#   sin(35.264)). El circuito es un cuadrado centrado en el origen, ejes X/Z.
# - Alturas: banda de la cinta 0.8 (mostrador), taburete 0.47, cliente de pie
#   1.75, cliente sentado 1.30 (cadera a 0.36 de su altura).
# - Velocidades convertidas: platos 75 px/s -> 0.9 u/s; andar 190 -> 2.2 u/s.
# - El HUD 2D (CanvasLayer) queda por encima del mundo 3D sin cambios: banda
#   visible del mundo entre el borde del TopBar (110 px) y la tabla (790 px).

const GRUMETE := preload("res://assets/models/grumete.glb")
const GRUMETE_SIT := preload("res://assets/models/grumete_sentado.glb")

# Los 12 platos, uno por receta (assets/models/<recipe_id>.glb). Cada modelo
# incluye su propia tabla de madera: la tabla ES el plato, no hay base extra.
const DISH_IDS := [
	"maki_aguacate", "nigiri_salmon", "gunkan_wakame", "maki_atun",
	"sopa_miso", "futomaki_salmon", "nigiri_atun", "nigiri_inari",
	"sashimi_tamago", "sashimi_atun_rojo", "nigiri_ebi", "gunkan_tartar",
]
const DISH_FOOT := 0.62   # huella horizontal objetivo de la tabla del plato

# --- Camara ---
const CAM_PITCH := -35.264
const CAM_YAW := 45.0
const CAM_SIZE := 15.0
# Objetivo desplazado por el suelo para que el centro de la cinta caiga en el
# centro de la banda visible (y~450 px), no en el centro de la pantalla.
const CAM_TARGET := Vector3(2.35, 0.0, 2.35)

# --- Circuito de la cinta ---
const BELT_SIDE := 3.6        # lado del cuadrado (linea central de la banda)
const BELT_W := 0.6           # ancho de la banda movil
const BELT_TOP := 0.8         # altura del mostrador / banda
const COUNTER_W := 1.1        # ancho del mostrador de madera bajo la banda
const CORNER := 0.78          # lado de la placa metalica de cada esquina
const PLATE_SPEED := 0.9      # u/s (75 px/s en el juego 2D)

# --- Actores ---
const BODY_H := 1.75
const SEAT_BODY_H := 1.30
const STOOL_H := 0.47
const SEAT_ALONG := 0.9       # separacion de cada taburete respecto al centro del lado
const SEAT_OUT := 2.8         # distancia del taburete al centro del circuito
const WALK_SPEED := 2.2       # u/s (190 px/s en el juego 2D)
# La entrada esta EN el hueco de embarque de la barandilla (misma linea
# diagonal): el cliente aparece cruzando la borda. Equivale al ENTRY_POINT 2D.
const ENTRY := Vector3(-4.2, 0.0, -4.2)

# Asientos: 2 por lado, como los 8 del juego 2D. "n" = normal exterior del lado.
# Lados en pantalla: -Z arriba-dcha, +X abajo-dcha, +Z abajo-izda, -X arriba-izda.
const SEAT_DEFS := [
	{ "n": Vector3(0, 0, -1), "along": Vector3(1, 0, 0) },
	{ "n": Vector3(1, 0, 0), "along": Vector3(0, 0, 1) },
	{ "n": Vector3(0, 0, 1), "along": Vector3(1, 0, 0) },
	{ "n": Vector3(-1, 0, 0), "along": Vector3(0, 0, 1) },
]

# Salto de desplazamiento validado en el spike (estilo Crossy Road).
const HOP := {
	"step_hz": 1.55, "bob": 0.135, "squash": 0.20, "stretch": 0.07,
	"roll": 8.0, "yaw": 4.0, "pitch": 8.0, "hang": 0.62,
}

var _plates: Array[PathFollow3D] = []
var _walker: Node3D
var _walker_route: Array = []
var _walker_leg := 0
var _walker_dist := 0.0
var _walker_wait := 0.0
var _walker_seat: Node3D
var _t := 0.0
# Capturas de verificacion: vacio = modo demo (no captura ni cierra).
# Para verificar por captura, poner p.ej. [0.4, 2.6] y correr la escena.
var _shots_at := []
var _shot_idx := 0


func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_setup_deck()
	_setup_ship_props()
	_setup_counter_and_belt()
	_setup_belt_path()
	_setup_seats()
	_setup_chef()
	_setup_walker()
	_setup_hud_mock()


# ------------------------------------------------------------------- mundo

func _setup_environment() -> void:
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
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	add_child(sun)


func _setup_camera() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(CAM_PITCH, CAM_YAW, 0.0)
	cam.size = CAM_SIZE
	add_child(cam)
	# basis.z apunta hacia atras de la camara: alejarse del objetivo por ahi.
	cam.position = CAM_TARGET + cam.transform.basis.z * 25.0
	cam.make_current()


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	m.metallic = 0.0
	return m


func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _mat(color)
	add_child(mi)
	return mi


func _setup_deck() -> void:
	for i in range(38):
		var tone := 0.0 if i % 2 == 0 else 0.04
		_box(Vector3(24.0, 0.2, 0.62), Vector3(0.5, -0.1, -11.0 + i * 0.62),
			Color(0.52 + tone, 0.35 + tone, 0.20 + tone))


# Atrezzo que da identidad de barco: mar bajo la cubierta, mastil, barandilla
# con hueco de embarque frente a la entrada, y carga apilada junto a el.
func _setup_ship_props() -> void:
	# Mar: plano enorme bajo el nivel de la cubierta (asoma en las esquinas).
	var sea := MeshInstance3D.new()
	var sea_mesh := PlaneMesh.new()
	sea_mesh.size = Vector2(90.0, 90.0)
	sea.mesh = sea_mesh
	sea.position = Vector3(0.0, -0.55, 0.0)
	sea.material_override = _mat(Color(0.22, 0.42, 0.55))
	add_child(sea)

	# Mastil en la zona superior derecha, con base y cuerda enrollada.
	var mast_pos := Vector3(2.6, 0.0, -3.2)
	var mast := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.20
	cyl.bottom_radius = 0.26
	cyl.height = 9.0
	mast.mesh = cyl
	mast.position = mast_pos + Vector3(0.0, 4.5, 0.0)
	mast.material_override = _mat(Color(0.40, 0.27, 0.15))
	add_child(mast)
	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.33
	ring_mesh.bottom_radius = 0.36
	ring_mesh.height = 0.22
	ring.mesh = ring_mesh
	ring.position = mast_pos + Vector3(0.0, 0.11, 0.0)
	ring.material_override = _mat(Color(0.72, 0.62, 0.44))
	add_child(ring)

	# Barandilla de borda tras la entrada. Corre por la DIAGONAL del mundo
	# (1,0,-1), que en camara iso yaw-45 es la horizontal de pantalla: la
	# eslora del barco a lo ancho de la vista. Hueco de embarque centrado en
	# la vertical de la entrada (los clientes suben a bordo por ahi).
	_railing_diag(-6.5, -0.8)
	_railing_diag(0.8, 7.5)

	# Carga junto al hueco de embarque: cajas apiladas (por delante de la
	# linea de barandilla para no solaparse con los travesanos).
	_box(Vector3(0.72, 0.72, 0.72), Vector3(-5.3, 0.36, -2.5), Color(0.55, 0.40, 0.22))
	_box(Vector3(0.58, 0.58, 0.58), Vector3(-5.15, 1.01, -2.4), Color(0.60, 0.45, 0.26))
	_box(Vector3(0.62, 0.62, 0.62), Vector3(-6.2, 0.31, -2.15), Color(0.50, 0.36, 0.20))

	# Barriles (modelo Ludo): dos de pie y uno tumbado junto al mastil.
	var barrel_path := "res://assets/models/barril.glb"
	if ResourceLoader.exists(barrel_path):
		var barrel: PackedScene = load(barrel_path)
		_spawn_model(barrel, Vector3(-6.6, 0.0, -1.5), 0.95, self)
		_spawn_model(barrel, Vector3(2.0, 0.0, -2.7), 0.95, self)
		var tipped := _spawn_model(barrel, Vector3(2.9, 0.0, -2.2), 0.95, self)
		tipped.rotation_degrees = Vector3(90.0, 25.0, 0.0)
		tipped.position.y = 0.33


# Tramo de barandilla sobre la linea diagonal p(t) = (-4.2,0,-4.2) + t*(1,0,-1)/v2
# (constante en pantalla-y, la misma linea que ENTRY), del parametro t0 a t1:
# postes cada ~1.1 y dos travesanos girados 45 para alinearse con la diagonal.
func _railing_diag(t0: float, t1: float) -> void:
	var dir := Vector3(1.0, 0.0, -1.0) / sqrt(2.0)
	var base := ENTRY
	var length := t1 - t0
	var posts := int(round(length / 1.1))
	for i in range(posts + 1):
		var p := base + dir * (t0 + length * float(i) / float(posts))
		_box(Vector3(0.10, 0.88, 0.10), p + Vector3(0.0, 0.44, 0.0),
			Color(0.38, 0.26, 0.14))
	var mid := base + dir * ((t0 + t1) * 0.5)
	for rail in [[0.88, 0.09, 0.13], [0.48, 0.07, 0.10]]:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(length + 0.1, rail[1], rail[2])
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = mid + Vector3(0.0, rail[0], 0.0)
		mi.rotation_degrees.y = 45.0
		mi.material_override = _mat(Color(0.46, 0.32, 0.17))
		add_child(mi)


# Mostrador de madera + banda MOVIL encima + placas de esquina estaticas
# (equivalente 3D de las Line2D con belt_scroll del juego 2D). Cada tramo de
# banda es un PlaneMesh con su +X local en el sentido de la marcha del Path3D
# ((-h,-h) -> (h,-h) -> (h,h) -> (-h,h)), con el shader desplazando la UV.
func _setup_counter_and_belt() -> void:
	var h := BELT_SIDE * 0.5
	var seg := BELT_SIDE - CORNER

	var band_tex: Texture2D = load("res://assets/props/cinta_trad_banda.png")
	var tile_len := BELT_W * float(band_tex.get_width()) / float(band_tex.get_height())
	var band_mat := ShaderMaterial.new()
	band_mat.shader = load("res://shaders/belt_scroll_3d.gdshader")
	band_mat.set_shader_parameter("band_tex", band_tex)
	band_mat.set_shader_parameter("repeat_x", seg / tile_len)
	band_mat.set_shader_parameter("tiles_per_sec", PLATE_SPEED / tile_len)

	# centro del lado, rotacion Y que alinea +X con el sentido de la marcha,
	# y si el mostrador es horizontal (a lo largo de X) o vertical.
	var sides := [
		[Vector3(0, 0, -h), 0.0, true],
		[Vector3(h, 0, 0), -90.0, false],
		[Vector3(0, 0, h), 180.0, true],
		[Vector3(-h, 0, 0), 90.0, false],
	]
	for s in sides:
		var center: Vector3 = s[0]
		# Mostrador (todo el lado, hasta la esquina).
		var c_size := Vector3(BELT_SIDE + COUNTER_W, BELT_TOP, COUNTER_W) \
			if s[2] else Vector3(COUNTER_W, BELT_TOP, BELT_SIDE + COUNTER_W)
		_box(c_size, center + Vector3(0.0, BELT_TOP * 0.5, 0.0),
			Color(0.48, 0.33, 0.18))
		# Cuerpo oscuro bajo la banda (deja hueco para la placa de esquina).
		var b_size := Vector3(seg, 0.04, BELT_W) if s[2] \
			else Vector3(BELT_W, 0.04, seg)
		_box(b_size, center + Vector3(0.0, BELT_TOP + 0.02, 0.0),
			Color(0.13, 0.14, 0.16))
		# Banda movil.
		var plane := PlaneMesh.new()
		plane.size = Vector2(seg, BELT_W)
		var mi := MeshInstance3D.new()
		mi.mesh = plane
		mi.material_override = band_mat
		mi.position = center + Vector3(0.0, BELT_TOP + 0.045, 0.0)
		mi.rotation_degrees.y = s[1]
		add_child(mi)

	for corner in [Vector3(h, 0, h), Vector3(h, 0, -h),
			Vector3(-h, 0, h), Vector3(-h, 0, -h)]:
		_box(Vector3(CORNER, 0.06, CORNER),
			corner + Vector3(0.0, BELT_TOP + 0.03, 0.0), Color(0.42, 0.44, 0.48))


# Path3D cuadrado sobre la banda; los platos son PathFollow3D, igual que en 2D
# eran nodos sobre un Path2D (mismo contrato: progress_ratio 0..1).
func _setup_belt_path() -> void:
	var h := BELT_SIDE * 0.5
	var y := BELT_TOP + 0.05
	var curve := Curve3D.new()
	for p in [Vector3(-h, y, -h), Vector3(h, y, -h), Vector3(h, y, h),
			Vector3(-h, y, h), Vector3(-h, y, -h)]:
		curve.add_point(p)
	var path := Path3D.new()
	path.curve = curve
	add_child(path)

	for i in DISH_IDS.size():
		var follow := PathFollow3D.new()
		follow.loop = true
		follow.rotation_mode = PathFollow3D.ROTATION_NONE
		path.add_child(follow)
		# progress_ratio solo funciona cuando el follow ya cuelga del Path3D.
		follow.progress_ratio = float(i) / DISH_IDS.size()
		var scene: PackedScene = load("res://assets/models/%s.glb" % DISH_IDS[i])
		_spawn_dish(scene, follow)
		_plates.append(follow)


# Normaliza el plato por su HUELLA horizontal (la tabla), no por altura:
# un sashimi plano y una sopa alta deben ocupar la misma tabla en la cinta.
func _spawn_dish(scene: PackedScene, parent: Node) -> Node3D:
	var inst: Node3D = scene.instantiate()
	parent.add_child(inst)
	var aabb := _merged_aabb(inst)
	var foot := maxf(maxf(aabb.size.x, aabb.size.z), 0.0001)
	var s := DISH_FOOT / foot
	inst.scale = Vector3(s, s, s)
	inst.position = -Vector3(
		aabb.position.x + aabb.size.x * 0.5,
		aabb.position.y,
		aabb.position.z + aabb.size.z * 0.5) * s
	return inst


func _setup_seats() -> void:
	var seat_i := 0
	for def in SEAT_DEFS:
		for along_sign in [-1.0, 1.0]:
			var pos: Vector3 = def["n"] * SEAT_OUT \
				+ def["along"] * SEAT_ALONG * along_sign
			_add_stool(pos)
			# Deja libres dos taburetes: uno es el destino del caminante.
			var facing := rad_to_deg(atan2(-def["n"].x, -def["n"].z))
			if seat_i == 6:
				_walker_seat = _spawn_model(GRUMETE_SIT, pos, SEAT_BODY_H, self)
				_walker_seat.rotation_degrees.y = facing
				_walker_seat.visible = false
			elif seat_i != 3:
				var client := _spawn_model(GRUMETE_SIT, pos, SEAT_BODY_H, self)
				client.rotation_degrees.y = facing
			seat_i += 1


func _add_stool(pos: Vector3) -> void:
	_box(Vector3(0.46, 0.09, 0.46), pos + Vector3(0.0, STOOL_H - 0.045, 0.0),
		Color(0.40, 0.26, 0.15))
	_box(Vector3(0.11, STOOL_H - 0.09, 0.11),
		pos + Vector3(0.0, (STOOL_H - 0.09) * 0.5, 0.0), Color(0.34, 0.22, 0.13))


# El chef vive DENTRO del circuito, como en 2D (chef en 334,398 y mesa en
# 380,452 -> aprox (-0.5,0,-0.1) y (0.6,0,0.3) en mundo).
func _setup_chef() -> void:
	# Mesa: cuerpo oscuro + tablero claro que sobresale.
	_box(Vector3(0.90, 0.78, 0.60), Vector3(0.6, 0.39, 0.3), Color(0.40, 0.27, 0.14))
	_box(Vector3(1.02, 0.07, 0.72), Vector3(0.6, 0.815, 0.3), Color(0.62, 0.45, 0.26))
	var chef := _spawn_model(GRUMETE, Vector3(-0.5, 0.0, -0.1), BODY_H, self)
	chef.rotation_degrees.y = 145.0


func _setup_walker() -> void:
	_walker = _spawn_model(GRUMETE, ENTRY, BODY_H, self)
	# Ruta: entra por arriba, bordea el circuito por fuera y llega a su
	# taburete (el 6: lado -X, el de arriba-izda).
	_walker_route = [
		ENTRY,
		Vector3(-3.6, 0.0, -3.4),
		Vector3(-3.6, 0.0, 0.9),
		Vector3(-2.8, 0.0, 0.9),
	]


# ------------------------------------------------------- instanciacion GLB

func _spawn_model(scene: PackedScene, ground_pos: Vector3, target_h: float,
		parent: Node) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = ground_pos
	parent.add_child(pivot)
	var inst: Node3D = scene.instantiate()
	pivot.add_child(inst)
	var aabb := _merged_aabb(inst)
	var s := target_h / maxf(aabb.size.y, 0.0001)
	inst.scale = Vector3(s, s, s)
	inst.position = -Vector3(
		aabb.position.x + aabb.size.x * 0.5,
		aabb.position.y,
		aabb.position.z + aabb.size.z * 0.5) * s
	return pivot


func _merged_aabb(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in _find_meshes(node):
		var a: AABB = m.transform * m.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


func _find_meshes(node: Node) -> Array:
	var found: Array = []
	if node is MeshInstance3D:
		found.append(node)
	for c in node.get_children():
		found.append_array(_find_meshes(c))
	return found


# ------------------------------------------------------------ animaciones

func _apply_hop(pivot: Node3D, facing_yaw: float, t: float) -> void:
	var phase: float = t * HOP["step_hz"] * TAU
	var lift: float = pow(absf(sin(phase)), HOP["hang"])
	var stride := sin(phase * 0.5)
	var land := pow(1.0 - lift, 2.5)
	pivot.position.y = lift * HOP["bob"] * BODY_H
	var sy: float = 1.0 + HOP["stretch"] * lift - HOP["squash"] * land
	pivot.scale = Vector3(1.0 / sqrt(sy), sy, 1.0 / sqrt(sy))
	pivot.rotation_degrees = Vector3(HOP["pitch"],
		facing_yaw + stride * HOP["yaw"], stride * HOP["roll"])


func _process(delta: float) -> void:
	_t += delta

	for follow in _plates:
		follow.progress += PLATE_SPEED * delta

	_update_walker(delta)

	if _shot_idx < _shots_at.size() and _t >= _shots_at[_shot_idx]:
		get_viewport().get_texture().get_image().save_png(
			"res://l3d_shot_%d.png" % _shot_idx)
		_shot_idx += 1
		print("SHOT %d OK" % _shot_idx)
		if _shot_idx == _shots_at.size():
			get_tree().quit()


func _update_walker(delta: float) -> void:
	if _walker_wait > 0.0:
		_walker_wait -= delta
		if _walker_wait <= 0.0:
			_walker.visible = true
			_walker_seat.visible = false
			_walker_leg = 0
			_walker_dist = 0.0
		return
	if _walker_leg >= _walker_route.size() - 1:
		# Ha llegado: se sienta (cambia al modelo sentado) y espera.
		_walker.visible = false
		_walker_seat.visible = true
		_walker_wait = 1.6
		return
	var a: Vector3 = _walker_route[_walker_leg]
	var b: Vector3 = _walker_route[_walker_leg + 1]
	var leg_len := a.distance_to(b)
	_walker_dist += WALK_SPEED * delta
	if _walker_dist >= leg_len:
		_walker_dist -= leg_len
		_walker_leg += 1
		return
	var p := a.lerp(b, _walker_dist / leg_len)
	_walker.position.x = p.x
	_walker.position.z = p.z
	var dir := b - a
	var yaw := rad_to_deg(atan2(dir.x, dir.z))
	_apply_hop(_walker, yaw, _t)


# ------------------------------------------------------------------- HUD

# Maqueta del HUD real (mismas franjas y colores que level.tscn) solo para
# validar el encuadre; el port reutilizara el CanvasLayer autentico tal cual.
# Con anclas, como el HUD real: con aspect=expand el lienzo puede ser mas
# ancho/alto que 720x1280 y las franjas deben estirarse con el.
func _setup_hud_mock() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	var cs := get_viewport().get_visible_rect().size
	_rect(hud, Rect2(0, 0, cs.x, 110), Color(0.13, 0.09, 0.05))
	_rect(hud, Rect2(0, 104, cs.x, 6), Color(0.5, 0.36, 0.14))
	_rect(hud, Rect2(0, cs.y - 490, cs.x, 490), Color(0.16, 0.11, 0.07))
	_rect(hud, Rect2(0, cs.y - 490, cs.x, 6), Color(0.34, 0.23, 0.13))


func _rect(parent: Node, r: Rect2, color: Color) -> void:
	var cr := ColorRect.new()
	cr.color = color
	parent.add_child(cr)
	cr.position = r.position
	cr.size = r.size
