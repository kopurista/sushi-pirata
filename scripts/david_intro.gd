extends Node3D
## Introducción de David Jones (primera vez que se juega): el capitán da la
## bienvenida DESDE LA CUBIERTA de su barco, pregunta el NOMBRE y el GÉNERO del
## jugador (los dos en la MISMA pantalla) y lo manda al nivel de tutorial.
##
## LA CUBIERTA es un decorado 3D construido por código, visto DE FRENTE (no con
## la cámara isométrica del resto del juego): tablones, escotilla, bordas a los
## lados, barandilla de balaustres al fondo con el mar y una isla detrás, dos
## cañones, barriles, cofre, jarcias, farol y la bandera pirata ondeando. La
## versión anterior era un arenal de cajas y no se leía como un barco.
##
## Casi todo el decorado se fusiona con GeometryBatch al terminar de montarlo;
## lo que se mueve (bandera, nubes, farol) y lo que lleva TEXTURA queda fuera,
## porque el fusionado agrupa por COLOR y mezclaría dos texturas distintas.

const PrepBoard := preload("res://scripts/prep_board.gd")
const DARK := Color(0.26, 0.16, 0.08)

## Encuadre: cámara de frente, algo picada, con el horizonte en el tercio alto
## para que la barandilla y la isla no queden bajo el pergamino del diálogo.
## En vertical (720×1280) el campo de visión HORIZONTAL es estrechísimo —con 62°
## de fov vertical se queda en 37°—, así que a 8 unidades solo se ven ~5.5 de
## ancho: todo el decorado va MUCHO más cerca del eje de lo que pediría una
## composición apaisada, o los barriles y el cofre se quedan fuera de cuadro.
const CAM_POS := Vector3(0.0, 2.35, 8.2)
const CAM_PITCH := -4.5
const CAM_FOV := 62.0

var ui: CanvasLayer
var dialog: DialogueBox
var _flag: Node3D = null
var _lantern: OmniLight3D = null
var _clouds: Array[Node3D] = []
var _t := 0.0


func _ready() -> void:
	Engine.max_fps = GameState.fps_for(false)
	_build_deck()

	ui = CanvasLayer.new()
	add_child(ui)
	# Velo suave para que el pergamino y el texto se lean sobre el 3D.
	var veil := ColorRect.new()
	veil.color = Color(0.05, 0.08, 0.12, 0.24)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(veil)

	dialog = DialogueBox.new()
	ui.add_child(dialog)
	_run_intro()


# ------------------------------------------------------------ construcción

func _mat(color: Color, rough := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


## Material con textura. Va SIEMPRE con no_batch: el fusionado agrupa por color
## y juntaría dos maderas distintas en una sola malla.
func _tex_mat(path: String, uv: Vector3, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = 0.95
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.uv1_scale = uv
	return m


func _box(size: Vector3, pos: Vector3, color: Color, yaw := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees.y = yaw
	mi.material_override = _mat(color)
	add_child(mi)
	return mi


func _cyl(r_top: float, r_bot: float, h: float, pos: Vector3, color: Color,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bot
	mesh.height = h
	mesh.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = _mat(color)
	add_child(mi)
	return mi


func _build_deck() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.24, 0.55, 0.85)
	sky_mat.sky_horizon_color = Color(0.74, 0.88, 0.96)
	sky_mat.ground_horizon_color = Color(0.74, 0.88, 0.96)
	sky_mat.ground_bottom_color = Color(0.35, 0.55, 0.68)
	sky_mat.sun_angle_max = 30.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.76, 0.81, 0.9)
	env.ambient_light_energy = 0.95
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = false
	add_child(sun)

	_build_sea()
	_build_island()
	_build_clouds()
	_build_floor()
	_build_bulwarks()
	_build_railing()
	_build_cannon(-2.55, true)
	_build_cannon(2.55, false)
	_build_cargo()
	_build_mast()
	_build_lantern()

	var cam := Camera3D.new()
	cam.fov = CAM_FOV
	cam.position = CAM_POS
	cam.rotation_degrees.x = CAM_PITCH
	cam.far = 400.0
	add_child(cam)
	cam.make_current()

	# Todo lo estático de color plano en una malla por color.
	GeometryBatch.bake(self, "Cubierta")


func _build_sea() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(400.0, 400.0)
	var sea := MeshInstance3D.new()
	sea.mesh = mesh
	sea.position = Vector3(0.0, -1.35, -60.0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water_map_3d.gdshader")
	mat.set_shader_parameter("sea_tex", load("res://assets/map/mar.png"))
	mat.set_shader_parameter("tile_scale", Vector2(26.0, 26.0))
	mat.set_shader_parameter("tint", Vector3(0.62, 0.76, 0.96))
	mat.set_shader_parameter("deep_color", Vector3(0.10, 0.24, 0.45))
	mat.set_shader_parameter("flatten", 0.80)
	mat.set_shader_parameter("drift_speed", 0.05)
	sea.material_override = mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.add_to_group(GeometryBatch.NO_BATCH_GROUP)
	add_child(sea)


## Isla al fondo, más allá de la barandilla: arenal, palmeras y unas rocas.
func _build_island() -> void:
	var sand := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 9.0
	dome.height = 5.0
	dome.radial_segments = 16
	dome.rings = 6
	sand.mesh = dome
	sand.position = Vector3(-1.0, -1.5, -40.0)
	sand.scale = Vector3(1.0, 0.42, 0.7)
	sand.material_override = _mat(Color(0.88, 0.8, 0.58))
	add_child(sand)

	# Hundidas en la cúpula de arena: con y=0 flotaban por encima de la isla.
	for spot in [Vector3(-4.4, -0.62, -38.0), Vector3(0.4, -0.5, -39.5),
			Vector3(3.0, -0.66, -41.0)]:
		_spawn_prop("res://assets/models/palmera.glb", spot, 5.4,
				randf_range(-40.0, 40.0))
	_spawn_prop("res://assets/models/rocas.glb", Vector3(-7.2, -0.95, -39.0), 2.6, 20.0)


func _build_clouds() -> void:
	if not GameState.animations_on():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(5):
		var pivot := Node3D.new()
		pivot.position = Vector3(rng.randf_range(-34.0, 34.0),
				rng.randf_range(9.0, 17.0), rng.randf_range(-70.0, -40.0))
		add_child(pivot)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 1.0, 1.0, 0.86)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for j in range(3):
			var puff := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = rng.randf_range(1.6, 2.8)
			s.height = s.radius * 1.5
			s.radial_segments = 10
			s.rings = 5
			puff.mesh = s
			puff.position = Vector3((j - 1) * rng.randf_range(1.8, 2.6),
					rng.randf_range(-0.3, 0.3), 0.0)
			puff.material_override = m
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pivot.add_child(puff)
		_clouds.append(pivot)


## Suelo de tablones + escotilla central.
func _build_floor() -> void:
	var deck := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(11.0, 16.0)
	deck.mesh = plane
	deck.position = Vector3(0.0, 0.0, 0.5)
	# Tablones de verdad. NO vale assets/scenery/cubierta.webp: esa textura trae
	# barriles, escotillas y cofres DIBUJADOS dentro, así que al repetirla el
	# suelo salía como un collage de atrezzo falso.
	deck.material_override = _tex_mat("res://assets/props/madera_desgastada.webp",
			Vector3(3.0, 4.5, 1.0), Color(1.5, 1.28, 1.0))
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	deck.add_to_group(GeometryBatch.NO_BATCH_GROUP)
	add_child(deck)

	# Escotilla: marco de madera clara con el hueco oscuro dentro.
	var hz := -1.7
	_box(Vector3(2.4, 0.14, 0.26), Vector3(0.0, 0.07, hz - 0.82), Color(0.55, 0.38, 0.21))
	_box(Vector3(2.4, 0.14, 0.26), Vector3(0.0, 0.07, hz + 0.82), Color(0.55, 0.38, 0.21))
	_box(Vector3(0.26, 0.14, 1.9), Vector3(-1.07, 0.07, hz), Color(0.55, 0.38, 0.21))
	_box(Vector3(0.26, 0.14, 1.9), Vector3(1.07, 0.07, hz), Color(0.55, 0.38, 0.21))
	_box(Vector3(2.0, 0.06, 1.5), Vector3(0.0, 0.04, hz), Color(0.3, 0.2, 0.12))


## Bordas (los costados del casco) subiendo a izquierda y derecha.
func _build_bulwarks() -> void:
	for s: float in [-1.0, 1.0]:
		var wall := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.34, 2.0, 15.0)
		wall.mesh = mesh
		wall.position = Vector3(s * 3.75, 0.85, -0.5)
		wall.rotation_degrees.z = s * 7.0
		wall.material_override = _tex_mat("res://assets/props/madera_desgastada.webp",
				Vector3(4.0, 1.4, 1.0), Color(1.25, 1.1, 0.92))
		wall.add_to_group(GeometryBatch.NO_BATCH_GROUP)
		add_child(wall)
		# Pasamanos superior redondeado.
		_box(Vector3(0.5, 0.2, 15.0), Vector3(s * 3.97, 1.9, -0.5),
			Color(0.44, 0.3, 0.16))


## Antepecho de proa: un murete corrido de tablones con dos TRONERAS por donde
## asoman los cañones, rematado con balaustres a los lados. Antes era una simple
## barandilla y los cañones apuntaban contra ella.
func _build_railing() -> void:
	var z := -6.4
	var trona := [-2.55, 2.55]   # centros de las troneras
	# Murete por tramos, dejando el hueco de cada tronera.
	var tramos := [[-4.7, -3.25], [-1.85, 1.85], [3.25, 4.7]]
	for t: Array in tramos:
		var a: float = t[0]
		var b: float = t[1]
		var w := b - a
		var mur := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(w, 1.05, 0.26)
		mur.mesh = mesh
		mur.position = Vector3((a + b) * 0.5, 0.52, z)
		mur.material_override = _tex_mat("res://assets/props/madera_desgastada.webp",
				Vector3(w * 0.5, 0.7, 1.0), Color(1.2, 1.06, 0.9))
		mur.add_to_group(GeometryBatch.NO_BATCH_GROUP)
		add_child(mur)
	# Dintel sobre cada tronera, para que el hueco se lea como una portilla.
	for cx: float in trona:
		_box(Vector3(1.4, 0.22, 0.3), Vector3(cx, 0.94, z), Color(0.42, 0.29, 0.15))
	# Pasamanos corrido y balaustres a los extremos.
	_box(Vector3(9.6, 0.16, 0.34), Vector3(0.0, 1.13, z), Color(0.48, 0.33, 0.17))
	for i in range(5):
		_box(Vector3(0.11, 0.5, 0.11), Vector3(-4.6 + i * 0.34, 1.38, z),
			Color(0.4, 0.27, 0.14))
		_box(Vector3(0.11, 0.5, 0.11), Vector3(4.6 - i * 0.34, 1.38, z),
			Color(0.4, 0.27, 0.14))
	for s2: float in [-1.0, 1.0]:
		_box(Vector3(0.3, 1.75, 0.3), Vector3(s2 * 4.85, 0.87, z),
			Color(0.36, 0.24, 0.12))


## Cañón sobre su cureña, apuntando A PROA por una tronera de la barandilla.
## Antes miraban al costado y la boca quedaba clavada contra la borda.
func _build_cannon(x: float, _izq: bool) -> void:
	var z := -5.1
	# Cureña de tablones.
	_box(Vector3(0.78, 0.30, 1.05), Vector3(x, 0.25, z), Color(0.42, 0.26, 0.13))
	_box(Vector3(0.60, 0.24, 0.86), Vector3(x, 0.50, z), Color(0.36, 0.22, 0.11))
	for dz in [-0.36, 0.36]:
		for dx in [-0.32, 0.32]:
			_cyl(0.17, 0.17, 0.09, Vector3(x + dx, 0.17, z + dz),
				Color(0.3, 0.2, 0.1), Vector3(0.0, 0.0, 90.0))
	# Tubo tumbado a lo largo de Z, con la boca asomando por la tronera.
	_cyl(0.15, 0.21, 1.6, Vector3(x, 0.76, z - 0.42),
		Color(0.17, 0.18, 0.2), Vector3(90.0, 0.0, 0.0))
	_cyl(0.24, 0.24, 0.18, Vector3(x, 0.76, z + 0.40),
		Color(0.14, 0.15, 0.17), Vector3(90.0, 0.0, 0.0))
	# Pila de balas al lado.
	for b in [Vector3(0.0, 0.0, 0.0), Vector3(0.25, 0.0, 0.06),
			Vector3(0.12, 0.20, 0.03)]:
		var ball := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.24
		sm.radial_segments = 8
		sm.rings = 5
		ball.mesh = sm
		ball.position = Vector3(x + 0.72, 0.12, z + 0.55) + b
		ball.material_override = _mat(Color(0.16, 0.17, 0.19))
		add_child(ball)


func _build_cargo() -> void:
	_spawn_prop("res://assets/models/cofre.glb", Vector3(-2.65, 0.0, 1.4), 1.05, 24.0)
	_spawn_prop("res://assets/models/barril.glb", Vector3(2.7, 0.0, 0.7), 1.0, 0.0)
	_spawn_prop("res://assets/models/barril.glb", Vector3(2.95, 0.0, 1.9), 1.0, 40.0)
	_spawn_prop("res://assets/models/caja.glb", Vector3(-2.85, 0.0, -1.0), 0.9, -18.0)
	_spawn_prop("res://assets/models/caja.glb", Vector3(-2.7, 0.9, -0.9), 0.68, 12.0)


## Mástil de babor con su verga, la vela recogida, las jarcias que bajan al
## costado y la bandera pirata arriba. Antes la bandera colgaba de un asta
## suelta (y se salía por arriba) y las jarcias no llegaban a ninguna parte.
func _build_mast() -> void:
	var mx := -2.15
	var mz := -3.9
	var alto := 6.6
	# Palo, con textura de madera.
	var palo := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.11
	cil.bottom_radius = 0.17
	cil.height = alto
	cil.radial_segments = 10
	palo.mesh = cil
	palo.position = Vector3(mx, alto * 0.5, mz)
	palo.material_override = _tex_mat("res://assets/props/madera_desgastada.webp",
			Vector3(1.0, 3.0, 1.0), Color(1.15, 1.0, 0.85))
	palo.add_to_group(GeometryBatch.NO_BATCH_GROUP)
	add_child(palo)
	# Cofa y verga.
	_box(Vector3(0.9, 0.1, 0.9), Vector3(mx, 4.45, mz), Color(0.4, 0.27, 0.14))
	_box(Vector3(2.1, 0.13, 0.13), Vector3(mx, 4.9, mz), Color(0.42, 0.29, 0.15))
	# Vela recogida sobre la verga.
	var vela := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(1.8, 0.32, 0.28)
	vela.mesh = vm
	vela.position = Vector3(mx, 4.72, mz)
	vela.material_override = _mat(Color(0.86, 0.83, 0.72))
	add_child(vela)
	# Jarcias: de la cofa BAJAN hasta el pasamanos de la borda, que es donde
	# van amarradas de verdad.
	var pie_x := -3.55
	for i in range(5):
		var top := Vector3(mx - 0.35 + i * 0.18, 4.4, mz)
		var bot := Vector3(pie_x, 1.9, mz - 0.9 + i * 0.45)
		var mid := (top + bot) * 0.5
		var largo := top.distance_to(bot)
		var cuerda := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.045, largo, 0.045)
		cuerda.mesh = bm
		cuerda.position = mid
		cuerda.look_at_from_position(mid, bot, Vector3.UP)
		cuerda.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		cuerda.material_override = _mat(Color(0.72, 0.64, 0.47))
		add_child(cuerda)
	# Bandera pirata al tope, ENTERA dentro del encuadre.
	_flag = Node3D.new()
	_flag.position = Vector3(mx, alto - 0.55, mz)
	_flag.add_to_group(GeometryBatch.NO_BATCH_GROUP)
	add_child(_flag)
	var cloth := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.5, 1.0)
	cloth.mesh = mesh
	cloth.position = Vector3(0.78, 0.0, 0.0)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/props/bandera_pirata.png")
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	cloth.material_override = m
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flag.add_child(cloth)


## Farol de aceite colgado a estribor.
func _build_lantern() -> void:
	var p := Vector3(3.4, 2.55, -5.0)
	_cyl(0.06, 0.06, 2.6, Vector3(p.x, 1.3, p.z), Color(0.36, 0.24, 0.12))
	_box(Vector3(0.5, 0.08, 0.08), Vector3(p.x - 0.22, 2.58, p.z), Color(0.32, 0.21, 0.1))
	_box(Vector3(0.34, 0.42, 0.34), Vector3(p.x - 0.44, 2.3, p.z), Color(0.33, 0.26, 0.12))
	var glow := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.13
	sm.height = 0.26
	sm.radial_segments = 8
	sm.rings = 5
	glow.mesh = sm
	glow.position = Vector3(p.x - 0.44, 2.3, p.z)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1.0, 0.85, 0.5)
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.78, 0.38)
	gm.emission_energy_multiplier = 2.0
	glow.material_override = gm
	glow.add_to_group(GeometryBatch.NO_BATCH_GROUP)
	add_child(glow)
	_lantern = OmniLight3D.new()
	_lantern.position = Vector3(p.x - 0.44, 2.3, p.z)
	_lantern.light_color = Color(1.0, 0.8, 0.45)
	_lantern.light_energy = 1.4
	_lantern.omni_range = 4.5
	_lantern.shadow_enabled = false
	add_child(_lantern)


## Instancia un GLB normalizado por su altura, apoyado en el suelo.
func _spawn_prop(path: String, pos: Vector3, altura: float, yaw := 0.0) -> void:
	if not ResourceLoader.exists(path):
		return
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation_degrees.y = yaw
	add_child(pivot)
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	pivot.add_child(inst)
	var aabb := _merged_aabb(inst)
	var s := altura / maxf(aabb.size.y, 0.0001)
	inst.scale = Vector3.ONE * s
	inst.position = -Vector3(aabb.position.x + aabb.size.x * 0.5,
		aabb.position.y, aabb.position.z + aabb.size.z * 0.5) * s


func _merged_aabb(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = m.transform * m.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


func _process(delta: float) -> void:
	if not GameState.animations_on():
		return
	_t += delta
	if _flag != null:
		_flag.rotation_degrees.y = sin(_t * 1.6) * 7.0
		_flag.scale.x = 1.0 + sin(_t * 2.3) * 0.06
	if _lantern != null:
		_lantern.light_energy = 1.4 + sin(_t * 5.1) * 0.18
	for i in _clouds.size():
		var c: Node3D = _clouds[i]
		c.position.x += delta * (0.45 + i * 0.08)
		if c.position.x > 38.0:
			c.position.x = -38.0


# -------------------------------------------------------------------- guion

func _run_intro() -> void:
	dialog.say([
		{ "text": "¡¿Quién anda ahí?! ¿Un polizón en **mi barco**?", "mood": "gritando" },
		{ "text": "¡RAAAK! ¡Polizón! ¡Al agua! ¡AL AGUA!", "who": "gigi", "mood": "loro" },
		{ "text": "Quieto, plumas. Que es broma... ¡Bienvenido a bordo!", "mood": "riendo" },
		{ "text": "Soy **David Jones**, capitán de esta belleza flotante y el pirata más temido de estas aguas. Y este chillón del hombro es **Gigi**.", "mood": "mira_loro" },
		{ "text": "¡Gigi el TEMIBLE! ¡RAAK!", "who": "gigi", "mood": "loro" },
		{ "text": "Temible para las galletas, sobre todo.", "mood": "loro_resignado" },
		{ "text": "Te estarás preguntando qué haces aquí. Verás: mi tripulación es valiente como un tifón... pero come como un banco de pirañas.", "mood": "serio" },
		{ "text": "Mi último cocinero saltó por la borda. Dijo algo de \"vacaciones\"... y de \"no aguantar ni un asalto más\".", "mood": "triste" },
		{ "text": "¡TRABAJO! ¡HAY QUE TRABAJAR! ¡RAAAK! ¡Nadie quiere trabajar!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Necesito manos rápidas y estómago firme: ¡un **cocinero de sushi** para la cinta kaiten de mi barco!", "mood": "hablando" },
		{ "text": "Pero antes de nada... dime quién eres, marinero.", "mood": "feliz" },
	])
	await dialog.finished
	var pname := await _ask_identity()
	dialog.say([
		{ "text": "¡RAAAK! ¡**%s**! ¿Eso es un nombre o el ruido que hace un barril al caerse?" % pname, "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "¡Ignóralo! A mí me suena a nombre de leyenda.", "mood": "loro_grito" },
		{ "text": "El plan es simple, **%s**: navegaremos de puerto en puerto sirviendo el mejor sushi de los siete mares. Los clientes pagan, y con ese **oro** compraremos ingredientes para llegar aún más lejos." % pname, "mood": "serio" },
		{ "text": "¿Que no has cocinado en tu vida? ¡¿Ni un triste onigiri?!", "mood": "sorprendido" },
		{ "text": "Ja, ja... no sufras. Para eso me tienes a mí. Todo capitán fue grumete una vez.", "mood": "riendo" },
		{ "text": "¡Sígueme a la **cocina**! Te voy a enseñar los secretos del oficio.", "mood": "gritando" },
	])
	await dialog.finished
	# Al tutorial: partida guiada en el nivel 3D con las 4 recetas del guion.
	GameState.save_game()
	GameState.mode = "tutorial"
	GameState.current_port = ""
	var recs: Array[String] = []
	for r in CampaignData.INITIAL_RECIPES:
		recs.append(r)
	GameState.selected_recipes = recs
	GameState.selected_perks = []
	GameState.fade_to_scene("res://scenes/level3d.tscn", 0.35, 0.45)


## Pergamino ÚNICO con el nombre y el género: se escribe, se toca al pirata y
## "¡Ese soy yo!" se enciende cuando están las dos cosas. Devuelve el nombre.
func _ask_identity() -> String:
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -336.0
	# ALTO MEDIDO, no a ojo: título + campo + título + fila de géneros (224) +
	# título + fila de manos (196) + botón (86), con sus separaciones y los
	# márgenes del pergamino, salen ~900 px. Con los 688 de antes, la mano
	# dominante y el botón se salían por abajo.
	panel.offset_top = -560.0
	panel.offset_right = 336.0
	panel.offset_bottom = 340.0
	ui.add_child(panel)
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Márgenes por dentro del marco dibujado del pergamino (los rodillos y las
	# esquinas comen ~50 px y cortaban el primer título).
	vb.offset_left = 66.0
	vb.offset_top = 68.0
	vb.offset_right = -66.0
	vb.offset_bottom = -62.0
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	vb.add_child(_titulo("¿Cómo te llamas?"))

	var edit := LineEdit.new()
	edit.max_length = 14
	edit.text = GameState.player_name
	edit.placeholder_text = "Tu nombre pirata"
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.custom_minimum_size = Vector2(0, 64)
	edit.add_theme_font_size_override("font_size", 28)
	edit.add_theme_color_override("font_color", DARK)
	edit.add_theme_color_override("font_placeholder_color", Color(0.55, 0.44, 0.32))
	edit.add_theme_color_override("caret_color", DARK)
	# El estilo por defecto del tema es una caja gris oscura que sobre el
	# pergamino parece un parche: se le pone marco de madera clara.
	var caja := StyleBoxFlat.new()
	caja.bg_color = Color(0.97, 0.92, 0.78)
	caja.border_color = Color(0.45, 0.31, 0.17)
	caja.set_border_width_all(3)
	caja.set_corner_radius_all(8)
	caja.content_margin_left = 14.0
	caja.content_margin_right = 14.0
	for st in ["normal", "focus", "read_only"]:
		edit.add_theme_stylebox_override(st, caja)
	vb.add_child(edit)
	# En el móvil el LineEdit no coge el foco al tocarlo y no sale el teclado.
	PrepBoard.enable_mobile_keyboard(edit)

	vb.add_child(_titulo("¿Y cómo te dibujo?"))

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 232)
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)

	var ok := Button.new()
	ok.text = "¡Ese soy yo!"
	# Ancho de sobra a propósito: con el botón justo, el texto se montaba sobre
	# las esquinas doradas del 9-slice.
	ok.custom_minimum_size = Vector2(400, 86)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	PrepBoard.skin_button(ok)
	ok.add_theme_font_size_override("font_size", 26)

	# Los botones capturan `refrescar` POR VALOR (lambdas de GDScript), así que
	# tiene que nacer completo: también repinta la fila de la mano dominante.
	var elegido := { "g": "", "h": "" }
	var botones: Array[Button] = []
	var botones_mano: Array[Button] = []
	var refrescar := func() -> void:
		for b in botones:
			b.modulate = Color.WHITE if b.get_meta("g") == elegido["g"] \
					else Color(0.5, 0.5, 0.52)
		for bm in botones_mano:
			bm.modulate = Color.WHITE if bm.get_meta("h") == elegido["h"] \
					else Color(0.5, 0.5, 0.52)
		var listo: bool = elegido["g"] != "" and elegido["h"] != "" \
				and edit.text.strip_edges() != ""
		ok.disabled = not listo
		ok.modulate = Color.WHITE if listo else Color(0.62, 0.62, 0.62)

	for g in CharacterData.PLAYER_GENDERS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(160, 224)
		b.set_meta("g", g)
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var pic := TextureRect.new()
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var tex_path := "res://assets/ui/chef_%s.png" % g
		if ResourceLoader.exists(tex_path):
			pic.texture = load(tex_path)
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(pic)
		b.pressed.connect(func() -> void:
			elegido["g"] = g
			refrescar.call()
			b.pivot_offset = b.size / 2.0
			var tw := b.create_tween()
			tw.tween_property(b, "scale", Vector2(1.12, 1.12), 0.1)
			tw.tween_property(b, "scale", Vector2.ONE, 0.1))
		botones.append(b)
		row.add_child(b)

	# Mano dominante: decide de qué lado queda la tabla de cocinar (con la
	# derecha el panel entero se voltea para que el pulgar no tape nada).
	vb.add_child(_titulo("¿Con qué mano dominas el cuchillo?"))
	var manos := HBoxContainer.new()
	manos.alignment = BoxContainer.ALIGNMENT_CENTER
	manos.add_theme_constant_override("separation", 26)
	vb.add_child(manos)
	# Se elige TOCANDO LA MANO (la misma imagen espejada): más claro que un
	# botón con la palabra, que obligaba a pensar cuál era cuál.
	for def in [["L", "Izquierda", "ic_mano_izq"], ["R", "Derecha", "ic_mano_der"]]:
		var bm := Button.new()
		bm.custom_minimum_size = Vector2(180, 196)
		bm.set_meta("h", def[0])
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			bm.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var pic := TextureRect.new()
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture = load("res://assets/ui/%s.png" % def[2])
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.offset_bottom = -34.0
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bm.add_child(pic)
		var lm := Label.new()
		lm.text = def[1]
		lm.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		lm.offset_top = -32.0
		lm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lm.add_theme_font_size_override("font_size", 22)
		lm.add_theme_color_override("font_color", DARK)
		lm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bm.add_child(lm)
		bm.pressed.connect(func() -> void:
			elegido["h"] = def[0]
			refrescar.call()
			bm.pivot_offset = bm.size / 2.0
			var tw := bm.create_tween()
			tw.tween_property(bm, "scale", Vector2(1.12, 1.12), 0.1)
			tw.tween_property(bm, "scale", Vector2.ONE, 0.1))
		botones_mano.append(bm)
		manos.add_child(bm)

	vb.add_child(ok)
	edit.text_changed.connect(func(_t: String) -> void: refrescar.call())
	refrescar.call()

	await ok.pressed
	var pname := edit.text.strip_edges()
	if pname == "":
		pname = "Grumete"
	GameState.player_name = pname
	GameState.player_gender = elegido["g"]
	GameState.player_hand = elegido["h"]
	panel.queue_free()
	return pname


func _titulo(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", DARK)
	return l
