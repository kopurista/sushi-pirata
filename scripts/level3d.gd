extends Node3D
## Orquestador del nivel en 3D (port de level.gd con la MISMA logica de juego):
## cinta, spawner de clientes, HUD, propinas, potenciadores y puntuacion.
## El mundo (cubierta, mostrador, cinta, atrezzo) se construye por codigo; el
## HUD es el CanvasLayer 2D del juego original, sin cambios (level3d.tscn).
##
## CONTRATO DE COORDENADAS (derivado del layout 2D para reproducirlo):
## - Camara isometrica ortogonal: pitch -35.264, yaw 45, size 15.
##   Con el viewport 720x1280 eso da ~85.3 px por unidad de mundo.
## - La cinta 2D era un rombo de 436x256 px = un CUADRADO de lado 3.6 u en
##   verdadera isometria (el juego 2D ya dibujaba iso real: 256/436 = 0.587 =
##   sin(35.264)). El circuito es un cuadrado centrado en el origen, ejes X/Z.
## - Velocidad de platos convertida: 75 px/s -> 0.9 u/s. Los clientes andan a
##   la velocidad natural de su ciclo de marcha (~1.2 u/s, mas lenta que los
##   2.2 del 2D: decision tomada para que los pies no patinen).

const CLIENT3D := preload("res://scripts/client3d.gd")
const PLATE3D := preload("res://scripts/plate3d.gd")

const TOTAL_CLIENTS := 10
## Duracion de una partida (2 min 30 s). El reloj no corre durante la fase de
## preparacion inicial.
const TIME_LIMIT := 150.0
## Margen antes del final en el que ya no llega ningun cliente.
const ARRIVAL_TAIL := 22.0
## Umbrales de dinero para 1★/2★/3★ en el modo prueba (en aventura los define
## cada nivel de la campaña con "star_money").
const DEFAULT_STAR_MONEY := [16, 30, 45]
## Incrementos del bote de propinas (acumulado: 10, 22, 36, 52...).
const TIP_INCREMENTS := [10, 12, 14, 16, 18, 20, 24, 28, 32, 36, 40, 48, 60]

# --- Camara ---
const CAM_PITCH := -35.264
const CAM_YAW := 45.0
const CAM_SIZE := 15.0
## Objetivo desplazado por el suelo para que el centro de la cinta caiga en el
## centro de la banda visible (y~450 px), no en el centro de la pantalla.
const CAM_TARGET := Vector3(2.35, 0.0, 2.35)

# --- Circuito de la cinta ---
const BELT_SIDE := 3.6        ## lado del cuadrado (linea central de la banda)
const BELT_W := 0.6           ## ancho de la banda movil
const BELT_TOP := 0.8         ## altura del mostrador / banda
const COUNTER_W := 1.1        ## ancho del mostrador de madera bajo la banda
const CORNER := 0.78          ## lado de la placa metalica de cada esquina
const PLATE_SPEED := 0.9      ## u/s (75 px/s en el juego 2D)
## Los platos salen por la esquina inferior de pantalla (+X+Z), la mas cercana
## a la tabla del jugador: dos lados desde el inicio del Path3D.
const SPAWN_PROGRESS := BELT_SIDE * 2.0

# --- Actores ---
const CHEF_H := 1.75
const STOOL_H := 0.47
const SEAT_ALONG := 0.9       ## separacion de cada taburete del centro del lado
const SEAT_OUT := 2.8         ## distancia del taburete al centro del circuito
## Radio del "pasillo" exterior por el que los clientes rodean el mostrador
## para llegar a su asiento sin pisar taburetes ni atrezzo.
const WALK_R := 3.7
## Entrada/salida: el hueco de embarque de la barandilla.
const ENTRY := Vector3(-4.2, 0.0, -4.2)

## Asientos: 2 por lado, como los 8 del juego 2D. "n" = normal exterior.
## Lados en pantalla: -Z arriba-dcha, +X abajo-dcha, +Z abajo-izda, -X arriba-izda.
const SEAT_DEFS := [
	{ "n": Vector3(0, 0, -1), "along": Vector3(1, 0, 0) },
	{ "n": Vector3(1, 0, 0), "along": Vector3(0, 0, 1) },
	{ "n": Vector3(0, 0, 1), "along": Vector3(1, 0, 0) },
	{ "n": Vector3(-1, 0, 0), "along": Vector3(0, 0, 1) },
]

# --- Estado de partida (identico al 2D) ---
var elapsed := 0.0
var money_earned := 0
var clients_spawned := 0
var clients_finished := 0
var client_reports: Array = []
var seat_clients: Array = []
var arrival_queue: Array[float] = []
var ended := false
var results_shown := false
## Con el andar lento la salida es larga: los resultados no esperan a que el
## ultimo cliente cruce la borda, solo a verlos levantarse.
var end_grace := 0.0

var total_clients := TOTAL_CLIENTS
var time_limit := TIME_LIMIT
var star_money: Array = DEFAULT_STAR_MONEY
var client_weights: Dictionary = {}
var type_queue: Array[String] = []
var forced_types: Array[String] = []

var prep_phase := true
var prep_time_left := 10.0
var frozen := false
var freeze_timer := 0.0

# --- Estado de propinas y potenciadores ---
var tips_total := 0
var powerups_claimed := 0
var pending_powerups := 0
var aroma_active := false
var recycle_active := false
var tip_chance_bonus := 0.0
var tip_amount_mult := 1.0
var belt_mult := 1.0
var patience_mult := 1.0
var next_client_pay_mult := 1.0
var belt_timer := 0.0
var tip_chance_timer := 0.0
var tip_amount_timer := 0.0

# --- Mundo 3D ---
var cam: Camera3D
## CanvasLayer BAJO el HUD donde los clientes cuelgan sus barras de paciencia
## y textos flotantes (proyectados con la camara, que es fija).
var world_ui: CanvasLayer
var belt_path: Path3D
var band_mat: ShaderMaterial
var band_tile_len := 1.0
var belt_scroll := 0.0
## Metadatos de cada asiento: pos, yaw, belt_point, ring (punto del pasillo).
var seats: Array = []
var chef_pivot: Node3D
var chef_anim: CharacterAnim = null
var chef_tween: Tween = null
var chef_prop: Sprite3D
var _t := 0.0
## Capturas de verificacion: vacio = juego normal. Con tiempos, captura y sale.
var _shots_at := []
var _shot_idx := 0

@onready var time_label: Label = $HUD/TopRow/TimeBox/TimeLabel
@onready var money_label: Label = $HUD/TopRow/MoneyBox/MoneyRow/MoneyLabel
@onready var clients_label: Label = $HUD/TopRow/ClientsBox/ClientsLabel
@onready var jar_label: Label = $HUD/TopRow/MoneyBox/JarRow/JarLabel
@onready var phase_label: Label = $HUD/PhaseLabel
@onready var prep_board: Control = $HUD/PrepBoard
@onready var manual_box: HBoxContainer = $HUD/ManualPowerups
@onready var powerup_panel: Panel = $HUD/PowerupPanel
@onready var powerup_options: VBoxContainer = $HUD/PowerupPanel/VBox/Options
@onready var results_panel: Panel = $HUD/ResultsPanel
@onready var stars_label: Label = $HUD/ResultsPanel/VBox/StarsLabel
var stars_row: HBoxContainer = null
@onready var score_label: Label = $HUD/ResultsPanel/VBox/ScoreLabel
@onready var earn_label: Label = $HUD/ResultsPanel/VBox/EarnLabel
@onready var breakdown_box: VBoxContainer = $HUD/ResultsPanel/VBox/Scroll/Breakdown
@onready var retry_button: Button = $HUD/ResultsPanel/VBox/BtnBox/RetryButton
@onready var menu_button: Button = $HUD/ResultsPanel/VBox/BtnBox/MenuButton


func _ready() -> void:
	world_ui = CanvasLayer.new()
	world_ui.layer = 0
	add_child(world_ui)
	_setup_environment()
	_setup_camera()
	_setup_deck()
	_setup_ship_props()
	_setup_counter_and_belt()
	_setup_belt_path()
	_setup_seats()
	_setup_chef()

	seat_clients.resize(seats.size())
	prep_board.dish_served.connect(_on_dish_served)
	prep_board.craft_event.connect(_on_craft_event)
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	results_panel.visible = false
	powerup_panel.visible = false
	_skin_panels()
	GameState.reset_run()
	# Configuracion del nivel de campaña (clientes, ritmo, umbrales de dinero).
	var arrival_scale := 1.0
	if GameState.is_adventure():
		var port := CampaignData.get_port(GameState.current_port)
		time_limit = float(port.get("time_limit", TIME_LIMIT))
		patience_mult = float(port.get("patience_mult", 1.0))
		arrival_scale = float(port.get("arrival_scale", 1.0))
		star_money = port.get("star_money", DEFAULT_STAR_MONEY)
		client_weights = port.get("client_weights", {})
		# "client_mix" define el recuento EXACTO de cada tipo: cola barajada.
		var mix: Dictionary = port.get("client_mix", {})
		if mix.is_empty():
			total_clients = int(port.get("total_clients", TOTAL_CLIENTS))
		else:
			type_queue.clear()
			for t in mix:
				for i in int(mix[t]):
					type_queue.append(t)
			type_queue.shuffle()
			total_clients = type_queue.size()
		# Jugar un nivel consume 1 uso de cada ingrediente de las recetas
		# elegidas; si no alcanzan, vuelta a la seleccion.
		if not GameState.consume_ingredients_for_level(GameState.selected_recipes):
			get_tree().change_scene_to_file.call_deferred("res://scenes/prep_screen.tscn")
			return
	# Llegadas escalonadas con azar (ver level.gd 2D para la explicacion).
	var last := (time_limit - ARRIVAL_TAIL) * arrival_scale
	var step := (last - 5.0) / float(total_clients - 1)
	for i in total_clients:
		var center := 5.0 + i * step
		arrival_queue.append(clampf(center + randf_range(-6.0, 6.0) * arrival_scale, 2.0, last))
	arrival_queue.sort()
	_update_hud()


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
	cam = Camera3D.new()
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


## Atrezzo que da identidad de barco: mar bajo la cubierta, mastil, barandilla
## con hueco de embarque frente a la entrada, y carga apilada junto a el.
func _setup_ship_props() -> void:
	var sea := MeshInstance3D.new()
	var sea_mesh := PlaneMesh.new()
	sea_mesh.size = Vector2(90.0, 90.0)
	sea.mesh = sea_mesh
	sea.position = Vector3(0.0, -0.55, 0.0)
	sea.material_override = _mat(Color(0.22, 0.42, 0.55))
	add_child(sea)

	# Mastil en la zona superior derecha, con base.
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

	# Barandilla de borda con hueco de embarque en la vertical de la entrada.
	_railing_diag(-6.5, -0.8)
	_railing_diag(0.8, 7.5)

	# Carga junto al hueco de embarque.
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


## Tramo de barandilla sobre la diagonal p(t) = ENTRY + t*(1,0,-1)/v2 (la
## eslora del barco a lo ancho de la vista), del parametro t0 a t1.
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


## Mostrador de madera + banda MOVIL encima + placas de esquina estaticas.
## La banda avanza empujando el uniform "scroll_tiles" desde _process, para
## poder pararla al congelar y acelerarla con "Cinta rapida".
func _setup_counter_and_belt() -> void:
	var h := BELT_SIDE * 0.5
	var seg := BELT_SIDE - CORNER

	var band_tex: Texture2D = load("res://assets/props/cinta_trad_banda.png")
	band_tile_len = BELT_W * float(band_tex.get_width()) / float(band_tex.get_height())
	band_mat = ShaderMaterial.new()
	band_mat.shader = load("res://shaders/belt_scroll_3d.gdshader")
	band_mat.set_shader_parameter("band_tex", band_tex)
	band_mat.set_shader_parameter("repeat_x", seg / band_tile_len)
	band_mat.set_shader_parameter("scroll_tiles", 0.0)

	var sides := [
		[Vector3(0, 0, -h), 0.0, true],
		[Vector3(h, 0, 0), -90.0, false],
		[Vector3(0, 0, h), 180.0, true],
		[Vector3(-h, 0, 0), 90.0, false],
	]
	for s in sides:
		var center: Vector3 = s[0]
		var c_size := Vector3(BELT_SIDE + COUNTER_W, BELT_TOP, COUNTER_W) \
			if s[2] else Vector3(COUNTER_W, BELT_TOP, BELT_SIDE + COUNTER_W)
		_box(c_size, center + Vector3(0.0, BELT_TOP * 0.5, 0.0),
			Color(0.48, 0.33, 0.18))
		var b_size := Vector3(seg, 0.04, BELT_W) if s[2] \
			else Vector3(BELT_W, 0.04, seg)
		_box(b_size, center + Vector3(0.0, BELT_TOP + 0.02, 0.0),
			Color(0.13, 0.14, 0.16))
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


## Path3D cuadrado sobre la banda; los platos (plate3d.gd) son PathFollow3D.
func _setup_belt_path() -> void:
	var h := BELT_SIDE * 0.5
	var y := BELT_TOP + 0.05
	var curve := Curve3D.new()
	for p in [Vector3(-h, y, -h), Vector3(h, y, -h), Vector3(h, y, h),
			Vector3(-h, y, h), Vector3(-h, y, -h)]:
		curve.add_point(p)
	belt_path = Path3D.new()
	belt_path.curve = curve
	add_child(belt_path)


func _setup_seats() -> void:
	for def in SEAT_DEFS:
		for along_sign in [-1.0, 1.0]:
			var n: Vector3 = def["n"]
			var offset: Vector3 = def["along"] * SEAT_ALONG * along_sign
			var pos: Vector3 = n * SEAT_OUT + offset
			_add_stool(pos)
			seats.append({
				"pos": pos,
				"yaw": rad_to_deg(atan2(-n.x, -n.z)),
				"belt": n * (BELT_SIDE * 0.5) + offset + Vector3(0.0, BELT_TOP, 0.0),
				"ring": n * WALK_R + offset,
			})


func _add_stool(pos: Vector3) -> void:
	_box(Vector3(0.46, 0.09, 0.46), pos + Vector3(0.0, STOOL_H - 0.045, 0.0),
		Color(0.40, 0.26, 0.15))
	_box(Vector3(0.11, STOOL_H - 0.09, 0.11),
		pos + Vector3(0.0, (STOOL_H - 0.09) * 0.5, 0.0), Color(0.34, 0.22, 0.13))


## El chef vive DENTRO del circuito, como en 2D, junto a su mesa. Respira con
## la animacion de reposo y reacciona a cada gesto del jugador (tweens).
func _setup_chef() -> void:
	_box(Vector3(0.90, 0.78, 0.60), Vector3(0.6, 0.39, 0.3), Color(0.40, 0.27, 0.14))
	_box(Vector3(1.02, 0.07, 0.72), Vector3(0.6, 0.815, 0.3), Color(0.62, 0.45, 0.26))
	chef_pivot = _spawn_model(load("res://assets/models/chef_rig.glb"),
		Vector3(-0.5, 0.0, -0.1), CHEF_H, self)
	chef_pivot.rotation_degrees.y = 145.0
	var skels := chef_pivot.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		chef_anim = CharacterAnim.new(skels[0])
		if not chef_anim.has_humanoid_bones():
			chef_anim = null
	# El ingrediente/etapa en curso se muestra sobre la mesa del chef.
	chef_prop = Sprite3D.new()
	chef_prop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	chef_prop.position = Vector3(0.6, 1.12, 0.3)
	chef_prop.visible = false
	add_child(chef_prop)


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
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = m.transform * m.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


# ---------------------------------------------------------- paneles y chef

## Viste los paneles emergentes con el pergamino enmarcado en cuerda.
func _skin_panels() -> void:
	var path := "res://assets/ui/panel.png"
	if ResourceLoader.exists(path):
		for p in [powerup_panel, results_panel]:
			p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			p.add_child(prep_board.make_nine_patch(path, 38))
	var dark := Color(0.26, 0.16, 0.08)
	for l in [$HUD/ResultsPanel/VBox/TitleLabel, score_label, earn_label,
			$HUD/PowerupPanel/VBox/Title]:
		l.add_theme_color_override("font_color", dark)
	stars_label.add_theme_color_override("font_color", Color(0.78, 0.55, 0.08))
	stars_label.visible = false
	stars_row = HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 12)
	var vbox := $HUD/ResultsPanel/VBox
	vbox.add_child(stars_row)
	vbox.move_child(stars_row, stars_label.get_index() + 1)
	for b in [retry_button, menu_button]:
		prep_board.skin_button(b)


## Reacciones del chef a cada gesto del jugador en la tabla, ahora sobre el
## pivote del modelo 3D (squash de escala, cabeceos y balanceos).
func _on_craft_event(kind: String, stage_id: String) -> void:
	var tex := RecipeData.get_stage_texture(stage_id)
	chef_prop.texture = tex
	chef_prop.visible = tex != null
	if tex != null:
		chef_prop.pixel_size = 0.55 / tex.get_width()

	if chef_tween != null:
		chef_tween.kill()
		chef_pivot.scale = Vector3.ONE
		chef_pivot.rotation_degrees.x = 0.0
		chef_pivot.rotation_degrees.z = 0.0
		chef_pivot.position.y = 0.0
	chef_tween = create_tween()
	match kind:
		"tap", "stage":
			# Picar: el chef se agacha un instante.
			chef_tween.tween_property(chef_pivot, "scale", Vector3(1.04, 0.90, 1.04), 0.07)
			chef_tween.tween_property(chef_pivot, "scale", Vector3.ONE, 0.09)
		"cut":
			# Cortar: golpe de cuchillo (cabeceo seco).
			chef_tween.tween_property(chef_pivot, "rotation_degrees:x", 9.0, 0.06)
			chef_tween.tween_property(chef_pivot, "rotation_degrees:x", 0.0, 0.12)
		"slice":
			# Corte lento de sashimi: cabeceo amplio y pausado.
			chef_tween.tween_property(chef_pivot, "rotation_degrees:x", 7.0, 0.25)
			chef_tween.tween_property(chef_pivot, "rotation_degrees:x", 0.0, 0.3)
		"swipe":
			# Enrollar: balanceo lateral.
			chef_tween.tween_property(chef_pivot, "rotation_degrees:z", 7.0, 0.1)
			chef_tween.tween_property(chef_pivot, "rotation_degrees:z", -7.0, 0.14)
			chef_tween.tween_property(chef_pivot, "rotation_degrees:z", 0.0, 0.1)
		"hold", "stir":
			# Remover la olla: vaiven suave.
			chef_tween.tween_property(chef_pivot, "rotation_degrees:z", 4.0, 0.3)
			chef_tween.tween_property(chef_pivot, "rotation_degrees:z", -4.0, 0.3)
			chef_tween.tween_property(chef_pivot, "rotation_degrees:z", 0.0, 0.2)
		"drag":
			chef_tween.tween_property(chef_pivot, "scale", Vector3(1.02, 0.95, 1.02), 0.1)
			chef_tween.tween_property(chef_pivot, "scale", Vector3.ONE, 0.12)
		"done":
			# Plato terminado: pequeño salto de celebracion.
			chef_tween.tween_property(chef_pivot, "position:y", 0.14, 0.12)
			chef_tween.tween_property(chef_pivot, "position:y", 0.0, 0.15)
		_:
			chef_tween.kill()
			chef_tween = null


# ------------------------------------------------------------------- bucle

func _process(delta: float) -> void:
	_t += delta
	if chef_anim != null:
		chef_anim.reset()
		chef_anim.idle(_t)

	if _shot_idx < _shots_at.size() and _t >= _shots_at[_shot_idx]:
		get_viewport().get_texture().get_image().save_png(
			"res://l3d_shot_%d.png" % _shot_idx)
		_shot_idx += 1
		print("SHOT %d OK" % _shot_idx)
		if _shot_idx == _shots_at.size():
			get_tree().quit()
			return

	if ended:
		# Los reportes ya estan (force_leave es inmediato); solo se deja un
		# instante para ver a los clientes levantarse antes del cartel.
		if not results_shown:
			end_grace += delta
			if end_grace >= 2.0 or get_tree().get_nodes_in_group("clients").is_empty():
				_finalize_results()
		return

	# La banda de la cinta avanza a la velocidad real de los platos (tambien
	# durante la fase de preparacion, pero no congelada).
	if not frozen:
		belt_scroll = fmod(belt_scroll + PLATE_SPEED * belt_mult * delta / band_tile_len, 1.0)
		band_mat.set_shader_parameter("scroll_tiles", belt_scroll)

	# Fase de preparacion: el reloj no corre y no vienen clientes.
	if prep_phase:
		prep_time_left -= delta
		phase_label.visible = true
		phase_label.text = "Preparación: %d s" % ceili(maxf(prep_time_left, 0.0))
		if prep_time_left <= 0.0:
			prep_phase = false
			phase_label.visible = false
		_update_hud()
		return

	# "Tiempo de preparacion extra": todo congelado salvo la tabla.
	if frozen:
		freeze_timer -= delta
		phase_label.visible = true
		phase_label.text = "Cortesía: %d s" % ceili(maxf(freeze_timer, 0.0))
		if freeze_timer <= 0.0:
			frozen = false
			phase_label.visible = false
		_update_hud()
		return

	elapsed += delta
	if elapsed >= time_limit:
		_end_level()
		return

	if belt_timer > 0.0:
		belt_timer -= delta
		if belt_timer <= 0.0:
			belt_mult = 1.0
	if tip_chance_timer > 0.0:
		tip_chance_timer -= delta
		if tip_chance_timer <= 0.0:
			tip_chance_bonus = 0.0
	if tip_amount_timer > 0.0:
		tip_amount_timer -= delta
		if tip_amount_timer <= 0.0:
			tip_amount_mult = 1.0

	if not arrival_queue.is_empty() and elapsed >= arrival_queue[0]:
		# Si no hay asiento libre lo reintenta cada frame hasta que lo haya.
		if _try_spawn_client():
			arrival_queue.pop_front()
	_update_hud()


# ---------------------------------------------------------------- clientes

func _try_spawn_client() -> bool:
	var free_seats: Array = []
	for i in seats.size():
		if seat_clients[i] == null:
			free_seats.append(i)
	if free_seats.is_empty():
		return false
	var idx: int = free_seats.pick_random()
	var c: Node3D = CLIENT3D.new()
	if not forced_types.is_empty():
		c.client_type = forced_types.pop_front()
	else:
		c.client_type = _pick_client_type()
	c.patience_scale = patience_mult
	c.pay_mult = next_client_pay_mult
	next_client_pay_mult = 1.0
	# Entra andando desde la borda, rodea el mostrador y llega a su taburete.
	c.position = ENTRY
	c.route = _route_for_seat(idx)
	c.exit_point = ENTRY
	c.belt_point = seats[idx]["belt"]
	c.seat_yaw = seats[idx]["yaw"]
	add_child(c)
	c.finished.connect(_on_client_finished.bind(idx))
	c.plate_served.connect(_on_client_served)
	seat_clients[idx] = c
	clients_spawned += 1
	return true


## Ruta de entrada: desde la borda, por el pasillo exterior (un cuadrado de
## radio WALK_R alrededor del mostrador), doblando por las esquinas que toque
## en el sentido mas corto, hasta el punto tras su asiento y de ahi al taburete.
## Equivale a los pasillos verticales del juego 2D.
func _route_for_seat(idx: int) -> Array:
	var ring: Vector3 = seats[idx]["ring"]
	var route: Array = [ENTRY]
	var r := WALK_R
	# Parametro de perimetro del punto destino (la entrada esta en la esquina
	# (-r,-r), parametro 0; el perimetro crece en sentido horario de pantalla).
	var s_b := _ring_param(ring)
	var perim := 8.0 * r
	var corners := [Vector3(-r, 0, -r), Vector3(r, 0, -r),
		Vector3(r, 0, r), Vector3(-r, 0, r)]
	if s_b <= perim - s_b:
		# Hacia delante: cruza las esquinas de parametro menor que el destino.
		for k in [1, 2, 3]:
			if 2.0 * r * k < s_b:
				route.append(corners[k])
	else:
		# Hacia atras: cruza las esquinas de parametro mayor, en orden inverso.
		for k in [3, 2, 1]:
			if 2.0 * r * k > s_b:
				route.append(corners[k])
	route.append(ring)
	route.append(seats[idx]["pos"])
	return route


## Parametro de perimetro (0..8r) de un punto del anillo de paseo.
func _ring_param(p: Vector3) -> float:
	var r := WALK_R
	if absf(p.z + r) < 0.01:
		return p.x + r
	if absf(p.x - r) < 0.01:
		return 2.0 * r + (p.z + r)
	if absf(p.z - r) < 0.01:
		return 4.0 * r + (r - p.x)
	return 6.0 * r + (r - p.z)


## Tipo de cliente: cola exacta del nivel; si no, pesos de campaña, o la
## mezcla del modo prueba (60% grumete, 30% pirata, 10% capitan).
func _pick_client_type() -> String:
	if not type_queue.is_empty():
		return type_queue.pop_front()
	if client_weights.is_empty():
		var r := randf()
		if r < 0.6:
			return "E"
		elif r < 0.9:
			return "A"
		return "G"
	var total := 0.0
	for t in client_weights:
		total += float(client_weights[t])
	var pick := randf() * maxf(total, 0.0001)
	for t in ["E", "A", "G"]:
		pick -= float(client_weights.get(t, 0.0))
		if pick <= 0.0:
			return t
	return "E"


## El dinero y las propinas ya se abonaron plato a plato (_on_client_served);
## al marcharse solo se registra el resumen para el desglose final.
func _on_client_finished(report: Dictionary, seat_idx: int) -> void:
	seat_clients[seat_idx] = null
	client_reports.append(report)
	clients_finished += 1
	_update_hud()
	if clients_finished >= total_clients:
		_end_level()


## Cada plato comido: solo el PRECIO cuenta como dinero generado (estrellas y
## monedero). La propina va unicamente al bote de potenciadores.
func _on_client_served(food: int, tip: int) -> void:
	money_earned += food
	if tip > 0:
		_add_tip(tip)
	_update_hud()


# ------------------------------------------------- propinas y potenciadores

## Umbral acumulado de propinas para el potenciador n+1.
func _tip_threshold(claimed: int) -> int:
	var total := 0
	for i in claimed + 1:
		total += TIP_INCREMENTS[i] if i < TIP_INCREMENTS.size() else 60
	return total


func _add_tip(amount: int) -> void:
	tips_total += amount
	while tips_total >= _tip_threshold(powerups_claimed):
		powerups_claimed += 1
		pending_powerups += 1
	if pending_powerups > 0 and not powerup_panel.visible and not ended:
		_open_powerup_choice()


func _open_powerup_choice() -> void:
	for child in powerup_options.get_children():
		child.queue_free()
	var ids: Array = PowerupData.POWERUPS.keys()
	ids.shuffle()
	for i in 3:
		var id: String = ids[i]
		var data := PowerupData.get_powerup(id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 140)
		b.add_theme_font_size_override("font_size", 24)
		var kind := "(elige cuándo usarlo)" if data.get("manual", false) else "(automático)"
		b.text = "%s %s\n%s" % [data.name, kind, data.desc]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		prep_board.skin_button(b)
		b.pressed.connect(_on_powerup_chosen.bind(id))
		powerup_options.add_child(b)
	powerup_panel.visible = true
	get_tree().paused = true


func _on_powerup_chosen(id: String) -> void:
	pending_powerups -= 1
	_apply_powerup(id)
	if pending_powerups > 0:
		_open_powerup_choice()
	else:
		powerup_panel.visible = false
		get_tree().paused = false


func _apply_powerup(id: String) -> void:
	if PowerupData.get_powerup(id).get("manual", false):
		_add_manual_icon(id)
		return
	match id:
		"aroma":
			aroma_active = true
		"receta_instantanea":
			prep_board.instant_recipes += 3
		"clientes_pacientes":
			patience_mult *= 1.2
			for c in seat_clients:
				if c != null:
					c.boost_patience(0.2)
		"menos_cooldown":
			prep_board.cooldown_mult = 0.6
			prep_board.cooldown_mult_timer = 20.0
		"mas_propinas":
			tip_chance_bonus = 0.1
			tip_chance_timer = 30.0
		"mejores_propinas":
			tip_amount_mult = 1.2
			tip_amount_timer = 30.0
		"cliente_satisfecho":
			next_client_pay_mult = 1.2
		"hora_feliz":
			_add_extra_clients("E")
		"cena_empresa":
			_add_extra_clients("A")
		"noche_gourmet":
			_add_extra_clients("G")
		"horas_extra":
			time_limit += 60.0
		"reciclaje":
			recycle_active = true
		"guardar_extra":
			prep_board.add_storage_slot()
		"doble_plato":
			prep_board.double_next = true
		"mas_almacen":
			prep_board.stack_max = 5
		"tiempo_extra_prep":
			frozen = true
			freeze_timer = 10.0


func _add_extra_clients(type: String) -> void:
	for i in 3:
		forced_types.append(type)
		arrival_queue.append(elapsed + 1.0 + i * 6.0)
	arrival_queue.sort()
	total_clients += 3


func _add_manual_icon(id: String) -> void:
	var data := PowerupData.get_powerup(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(70, 46)
	b.add_theme_font_size_override("font_size", 15)
	b.text = data.get("icon", "?")
	b.tooltip_text = data.get("desc", "")
	b.pressed.connect(_use_manual_powerup.bind(id, b))
	manual_box.add_child(b)


func _use_manual_powerup(id: String, button: Button) -> void:
	button.queue_free()
	match id:
		"cinta_rapida":
			belt_mult = 3.0
			belt_timer = 20.0
		"comida_segura":
			for c in seat_clients:
				if c != null and c.is_waiting():
					c.guaranteed_next = true
					break
		"sin_cooldown":
			prep_board.skip_next_cooldown = true
		"manos_rapidas":
			prep_board.easy_next = true


# ------------------------------------------------------------------ platos

func _on_dish_served(recipe_id: String) -> void:
	var p: PathFollow3D = PLATE3D.new()
	p.recipe_id = recipe_id
	p.speed = PLATE_SPEED
	belt_path.add_child(p)
	p.progress = SPAWN_PROGRESS
	p.discarded.connect(_on_plate_discarded)


## Un plato desechado (2 vueltas sin cogerse) cuesta el 30% de su precio.
## Con "Reciclaje de platos" vuelve a la receta como uso instantaneo.
func _on_plate_discarded(recipe_id: String) -> void:
	if recycle_active:
		prep_board.recycle_recipe(recipe_id)
		return
	var price: int = RecipeData.get_recipe(recipe_id).get("price", 0)
	money_earned -= int(round(price * 0.3))


# -------------------------------------------------------------- resultados

## Marca el fin del nivel y desaloja a los que queden.
func _end_level() -> void:
	if ended:
		return
	ended = true
	for i in seats.size():
		var c = seat_clients[i]
		if c != null:
			c.force_leave()


## Puntuacion POR DINERO: cada umbral de "star_money" alcanzado da una estrella.
func _finalize_results() -> void:
	results_shown = true
	var total_money := money_earned
	var stars := 0
	for threshold in star_money:
		if total_money >= int(threshold):
			stars += 1

	var new_recipes: Array = []
	if GameState.is_adventure():
		GameState.money += total_money
		GameState.record_level_score(GameState.current_port, total_money)
		new_recipes = GameState.complete_port(GameState.current_port, stars)
		GameState.save_game()
	GameState.last_score = float(total_money)
	GameState.last_stars = stars
	GameState.last_money_earned = total_money
	_show_results(stars, total_money, new_recipes)


const TYPE_NAMES := { "E": "Grumete", "A": "Pirata", "G": "Capitán" }


func _show_results(stars: int, total_money: int, new_recipes: Array) -> void:
	for c in stars_row.get_children():
		c.queue_free()
	stars_row.add_child(prep_board.make_star_row(stars, 3, 58))
	earn_label.text = "Dinero ganado: $%d" % total_money
	if stars < 3:
		score_label.text = "Siguiente estrella: $%d" % int(star_money[stars])
		score_label.visible = true
	else:
		score_label.visible = false
	_build_breakdown()
	powerup_panel.visible = false
	results_panel.visible = true
	get_tree().paused = true
	_reveal_recipes(new_recipes)


## Anuncia las recetas recien desbloqueadas con una animacion, de una en una.
func _reveal_recipes(recipes: Array) -> void:
	if recipes.is_empty():
		return
	var overlay := ColorRect.new()
	overlay.name = "RecipeReveal"
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.z_index = 200
	$HUD.add_child(overlay)
	var fade := overlay.create_tween()
	fade.tween_property(overlay, "color:a", 0.66, 0.2)
	_show_next_recipe(overlay, recipes.duplicate())


func _show_next_recipe(overlay: ColorRect, queue: Array) -> void:
	for c in overlay.get_children():
		c.queue_free()
	if queue.is_empty():
		var out := overlay.create_tween()
		out.tween_property(overlay, "color:a", 0.0, 0.2)
		out.tween_callback(overlay.queue_free)
		return
	var id: String = queue.pop_front()
	var data := RecipeData.get_recipe(id)
	var dark := Color(0.26, 0.16, 0.08)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var box := Control.new()
	box.custom_minimum_size = Vector2(470, 580)
	box.pivot_offset = Vector2(235, 290)
	center.add_child(box)
	box.add_child(prep_board.make_nine_patch("res://assets/ui/panel.png", 60))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 58.0
	vb.offset_top = 56.0
	vb.offset_right = -58.0
	vb.offset_bottom = -48.0
	vb.add_theme_constant_override("separation", 12)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(vb)

	var title := Label.new()
	title.text = "¡Nueva receta!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", dark)
	vb.add_child(title)

	var dish := TextureRect.new()
	dish.texture = RecipeData.get_dish_texture(id)
	dish.custom_minimum_size = Vector2(0, 250)
	dish.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dish.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dish.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(dish)

	var name_l := Label.new()
	name_l.text = data.get("name", id)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.add_theme_font_size_override("font_size", 30)
	name_l.add_theme_color_override("font_color", dark)
	vb.add_child(name_l)

	var lvl := int(data.get("level", 1))
	vb.add_child(prep_board.make_star_row(lvl, lvl, 34))

	if not queue.is_empty():
		var counter := Label.new()
		counter.text = "Quedan %d más" % queue.size()
		counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		counter.add_theme_font_size_override("font_size", 20)
		counter.add_theme_color_override("font_color", Color(0.5, 0.38, 0.22))
		vb.add_child(counter)

	var accept := Button.new()
	accept.text = "Aceptar"
	accept.custom_minimum_size = Vector2(210, 66)
	accept.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	prep_board.skin_button(accept)
	accept.add_theme_font_size_override("font_size", 26)
	accept.process_mode = Node.PROCESS_MODE_ALWAYS
	accept.pressed.connect(func() -> void: _show_next_recipe(overlay, queue))
	vb.add_child(accept)

	box.scale = Vector2(0.6, 0.6)
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "scale", Vector2.ONE, 0.35)
	tw.parallel().tween_property(box, "modulate:a", 1.0, 0.22)
	tw.tween_callback(func() -> void:
		var loop := box.create_tween().set_loops()
		loop.tween_property(box, "scale", Vector2(1.03, 1.03), 0.9).set_trans(Tween.TRANS_SINE)
		loop.tween_property(box, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE))


## Desglose agrupado por tipo de cliente (cabeceras de pergamino plegables).
func _build_breakdown() -> void:
	for child in breakdown_box.get_children():
		child.queue_free()

	var served := 0
	for r in client_reports:
		if r.satiety_eaten > 0:
			served += 1
	var header := Label.new()
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.26, 0.16, 0.08))
	header.text = "Clientes: %d · atendidos: %d" % [client_reports.size(), served]
	breakdown_box.add_child(header)

	for type in ["E", "A", "G"]:
		var reports: Array = []
		for r in client_reports:
			if r.type == type:
				reports.append(r)
		if reports.is_empty():
			continue

		var head := Button.new()
		head.custom_minimum_size = Vector2(0, 58)
		head.text = "%s (%d)" % [TYPE_NAMES.get(type, type), reports.size()]
		head.add_theme_font_size_override("font_size", 22)
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			head.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		head.add_theme_color_override("font_color", Color(0.26, 0.16, 0.08))
		head.add_theme_color_override("font_hover_color", Color(0.16, 0.1, 0.05))
		head.add_theme_color_override("font_pressed_color", Color(0.16, 0.1, 0.05))
		head.add_theme_color_override("font_outline_color", Color(1, 0.97, 0.88))
		head.add_theme_constant_override("outline_size", 4)
		var scroll_skin := NinePatchRect.new()
		scroll_skin.texture = load("res://assets/ui/pergamino_cerrado.png")
		scroll_skin.patch_margin_left = 190
		scroll_skin.patch_margin_right = 190
		scroll_skin.patch_margin_top = 6
		scroll_skin.patch_margin_bottom = 6
		scroll_skin.set_anchors_preset(Control.PRESET_FULL_RECT)
		scroll_skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scroll_skin.show_behind_parent = true
		head.add_child(scroll_skin)
		breakdown_box.add_child(head)

		var rows := VBoxContainer.new()
		rows.visible = false
		rows.add_theme_constant_override("separation", 6)
		for r in reports:
			rows.add_child(_breakdown_row(r))
		breakdown_box.add_child(rows)
		head.pressed.connect(func() -> void:
			rows.visible = not rows.visible
			if rows.visible:
				scroll_skin.texture = load("res://assets/ui/pergamino_abierto.png")
				scroll_skin.patch_margin_left = 210
				scroll_skin.patch_margin_right = 210
			else:
				scroll_skin.texture = load("res://assets/ui/pergamino_cerrado.png")
				scroll_skin.patch_margin_left = 190
				scroll_skin.patch_margin_right = 190)


## Fila de un cliente: iconos de platos comidos + dinero + propina.
func _breakdown_row(r: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var eaten: Array = r.eaten
	if eaten.is_empty():
		var none := Label.new()
		none.text = "—"
		none.add_theme_font_size_override("font_size", 22)
		none.add_theme_color_override("font_color", Color(0.45, 0.35, 0.25))
		row.add_child(none)
	else:
		var counts: Dictionary = {}
		var order: Array = []
		for id in eaten:
			if not id in counts:
				order.append(id)
			counts[id] = int(counts.get(id, 0)) + 1
		for id in order:
			row.add_child(_dish_count(id, counts[id]))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	row.add_child(_icon_amount("res://assets/ui/moneda.png", "$%d" % r.money))
	if r.tip > 0:
		row.add_child(_icon_amount("res://assets/ui/bolsa.png", "+$%d" % r.tip))
	return row


func _dish_count(id: String, count: int) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var ic := TextureRect.new()
	ic.texture = RecipeData.get_dish_texture(id)
	ic.custom_minimum_size = Vector2(44, 44)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(ic)
	if count > 1:
		var badge := Label.new()
		badge.text = "x%d" % count
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 22)
		badge.add_theme_color_override("font_color", Color(0.26, 0.16, 0.08))
		box.add_child(badge)
	return box


func _icon_amount(icon_path: String, text: String) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var ic := TextureRect.new()
	if ResourceLoader.exists(icon_path):
		ic.texture = load(icon_path)
	ic.custom_minimum_size = Vector2(30, 30)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(ic)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(0.3, 0.2, 0.1))
	box.add_child(l)
	return box


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _update_hud() -> void:
	var remaining := maxf(time_limit - elapsed, 0.0)
	time_label.text = "%d:%02d" % [int(remaining) / 60, int(remaining) % 60]
	money_label.text = "$%d / $%d" % [money_earned, int(star_money.back())]
	jar_label.text = "$%d / $%d" % [tips_total, _tip_threshold(powerups_claimed)]
	clients_label.text = "%d/%d" % [clients_finished, total_clients]
