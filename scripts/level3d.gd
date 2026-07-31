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

## Fotogramas por segundo jugando (los menus se conforman con la mitad).
const GAME_FPS := 60

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
## Un poco mas alejada que el 1:1 con el 2D (15.0) para ver mas escenario.
const CAM_SIZE := 17.0
## Objetivo desplazado por el suelo para que el centro de la cinta caiga en el
## centro de la banda visible, no en el centro de la pantalla. La banda va
## desde el borde superior (el HUD ya no tiene barra opaca) hasta la tabla de
## preparación, que ahora es más alta: su centro está en y~395 px.
const CAM_TARGET := Vector3(3.25, 0.0, 3.25)

# --- Circuito de la cinta ---
const BELT_SIDE := 3.6        ## lado del cuadrado (linea central de la banda)
const BELT_W := 0.6           ## ancho de la banda movil
const BELT_TOP := 0.8         ## altura del mostrador / banda
const COUNTER_W := 1.1        ## ancho del mostrador de madera bajo la banda
const CORNER := 0.78          ## lado de la placa metalica de cada esquina
## Lado del icono de cabeza del contador de clientes del HUD.
const HEAD_ICON := 54.0
## Cajas de guardado 3D junto al chef (gemelas de las del HUD).
const CRATE_W := 0.46
const CRATE_H := 0.30
const CRATE_DISH := 0.34   ## huella del plato apilado dentro de la caja
const CRATE_LIFT := 0.72   ## alto del banco que sube las cajas sobre el mostrador
## Texturas de madera del escenario (tileadas por triplanar, ver _wood_mat).
const DECK_TEX := "res://assets/props/madera_desgastada.webp"
const CRATE_TEX := "res://assets/props/madera_caja.webp"
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
## Entradas/salidas: DOS huecos de embarque. Los clientes de las sillas
## superiores (lados -Z/-X) entran por la borda superior y los de las sillas
## inferiores (+X/+Z) por la inferior — el andar 3D es lento y cruzar todo el
## barco tardaba demasiado. Cada cliente se marcha por donde entro.
const ENTRY := Vector3(-4.2, 0.0, -4.2)
const ENTRY_BOTTOM := Vector3(4.2, 0.0, 4.2)

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
var exit_button: TextureButton = null
## Fila de cabezas del HUD: un icono por TIPO de cliente presente en la barra,
## con "xN" si hay varios (ver _update_client_heads).
var heads_row: HBoxContainer = null
## Nodos donde se apilan los platos guardados de cada caja 3D del chef.
var chef_crates: Array[Node3D] = []
var chef_pivot: Node3D
## Ayudante de cocina: solo existe con el potenciador permanente "ayudante".
var helper_pivot: Node3D = null
var helper_anim: CharacterAnim = null
var helper_tween: Tween = null
## Platos servidos por el jugador (para el ayudante y para desbloquear perks).
var dishes_served := 0
var chef_anim: CharacterAnim = null
var chef_tween: Tween = null
var chef_prop: Sprite3D
## Gesto de cocina en curso del chef: se dispara UNO por evento del jugador
## (craft_event), asi que el chef trabaja al ritmo del dedo del usuario.
var chef_gesture := ""
var chef_gesture_t := 0.0
var chef_gesture_dur := 0.4
var chef_gesture_end := 0.4
## Utensilios en la mano derecha (cuchillo/cazo), visibles segun el gesto.
var chef_knife: Node3D = null
var chef_ladle: Node3D = null
var chef_tool_linger := 0.0
var _t := 0.0

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


## Tipo de escenario del nivel: "isla", "puerto" o "abordaje" (barco pirata).
var scenery_kind := "abordaje"


func _ready() -> void:
	# Los menus bajan el tope a 30 fps para no gastar bateria; jugando hacen
	# falta los 60 (aqui si importa la respuesta al dedo).
	Engine.max_fps = GAME_FPS
	world_ui = CanvasLayer.new()
	world_ui.layer = 0
	add_child(world_ui)
	if GameState.is_adventure():
		scenery_kind = CampaignData.get_kind(GameState.current_port)
	_setup_environment()
	_setup_camera()
	_setup_scenery()
	_setup_counter_and_belt()
	_setup_belt_path()
	_setup_seats()
	_setup_chef()
	# Todo el escenario (cubierta, mostrador, taburetes, atrezzo) es geometria
	# de color plano que no se mueve: se funde en UNA malla. Va aqui, cuando ya
	# esta todo colocado, y antes de que aparezca ningun cliente.
	GeometryBatch.bake(self, "SceneryBatch")
	_setup_exit_button()
	_setup_heads_row()

	seat_clients.resize(seats.size())
	prep_board.dish_served.connect(_on_player_dish_served)
	prep_board.craft_event.connect(_on_craft_event)
	prep_board.storage_changed.connect(_on_storage_changed)
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
		# Los potenciadores permanentes elegidos gastan 1 uso por partida (solo
		# en aventura: el modo Arcade no toca el progreso).
		GameState.consume_perks_for_level()
	else:
		GameState.selected_perks = []
	_apply_perks()
	# Llegadas escalonadas con azar (ver level.gd 2D para la explicacion).
	var last := (time_limit - ARRIVAL_TAIL) * arrival_scale
	var step := (last - 5.0) / float(total_clients - 1)
	for i in total_clients:
		var center := 5.0 + i * step
		arrival_queue.append(clampf(center + randf_range(-6.0, 6.0) * arrival_scale, 2.0, last))
	arrival_queue.sort()
	_update_hud()


# ------------------------------------------ potenciadores permanentes (perks)

## Aplica los potenciadores elegidos antes de empezar (ver PerkData).
func _apply_perks() -> void:
	if GameState.has_perk("cocina_veloz"):
		prep_board.cooldown_perm_mult = 0.5
	if GameState.has_perk("ayudante"):
		_setup_helper()


## Avatar del ayudante: solo aparece si se ha activado su potenciador. Se
## coloca al lado del chef, dentro del circuito, mirando al mismo sitio.
func _setup_helper() -> void:
	helper_pivot = _spawn_model(load("res://assets/models/ayudante_rig.glb"),
		Vector3(-1.15, 0.0, -0.15), 1.62, self)
	helper_pivot.rotation_degrees.y = 0.0
	_box(Vector3(0.72, 0.78, 0.56), Vector3(-1.15, 0.39, 0.72),
		Color(0.40, 0.27, 0.14))
	var skels := helper_pivot.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		helper_anim = CharacterAnim.new(skels[0])
		if not helper_anim.has_humanoid_bones():
			helper_anim = null


## Combos de la partida que desbloquean potenciadores permanentes. Devuelve
## los ids recién conseguidos, para anunciarlos en los resultados.
func _check_perk_unlocks() -> Array:
	var newly: Array = []
	var most := 0
	for r in client_reports:
		most = maxi(most, int(r.get("eaten", []).size()))
	if most >= PerkData.UNLOCK_PLATES_ONE_CLIENT \
			and GameState.unlock_perk("cocina_veloz"):
		newly.append("cocina_veloz")
	if dishes_served >= PerkData.UNLOCK_PLATES_TOTAL \
			and GameState.unlock_perk("ayudante"):
		newly.append("ayudante")
	return newly


## El ayudante manda un plato a la cinta por su cuenta: da un saltito y sirve
## una de las recetas elegidas.
func _helper_cook() -> void:
	if GameState.selected_recipes.is_empty() or ended:
		return
	var rid: String = GameState.selected_recipes.pick_random()
	_on_dish_served(rid)
	if helper_pivot == null:
		return
	if helper_tween != null:
		helper_tween.kill()
	helper_tween = create_tween()
	helper_tween.tween_property(helper_pivot, "position:y", 0.16, 0.12)
	helper_tween.tween_property(helper_pivot, "position:y", 0.0, 0.16)


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


## Material de madera con textura tileada. Usa mapeo TRIPLANAR (por posicion
## de mundo, no por UV del mesh): las cajas del escenario tienen tamaños muy
## dispares —una cubierta de 24x0.2 y un poste de 0.1x0.9— y con las UV del
## BoxMesh la textura saldria estirada en unas y diminuta en otras. Con
## triplanar todas comparten la MISMA escala de veta.
## `tint` recolorea la misma textura: la cubierta del barco va marron y el
## muelle del puerto gris salino, sin duplicar el asset.
func _wood_mat(tex_path: String, tint: Color, uv_scale := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if ResourceLoader.exists(tex_path):
		m.albedo_texture = load(tex_path)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	m.roughness = 0.95
	m.metallic = 0.0
	return m


## Caja del escenario con material compartido (una sola instancia de material
## para todo un grupo: menos cambios de estado que un material por caja).
func _box_mat(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi


func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _mat(color)
	add_child(mi)
	return mi


# --------------------------------------------------------------- escenarios
## El mostrador con la cinta es el mismo en todos los niveles; lo que cambia
## alrededor es el escenario segun el TIPO del nivel (CampaignData.KINDS):
## una isla, un puerto o el barco pirata (viejo y castigado) del abordaje.

func _setup_scenery() -> void:
	_add_sea()
	match scenery_kind:
		"isla":
			_scenery_island()
		"puerto":
			_scenery_port()
		_:
			_scenery_ship()


## Mar EN MOVIMIENTO alrededor del escenario: el mismo shader de agua del mapa
## de campaña (deriva + dos senos cruzados), asi el nivel no se ve congelado.
func _add_sea() -> void:
	var sea := MeshInstance3D.new()
	var sea_mesh := PlaneMesh.new()
	sea_mesh.size = Vector2(90.0, 90.0)
	sea.mesh = sea_mesh
	sea.position = Vector3(0.0, -0.55, 0.0)
	# Un plano de 90x90 bajo todo lo demas no proyecta ninguna sombra visible,
	# pero se dibujaba entero en el pase de sombras.
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tex_path := "res://assets/map/mar.png"
	if ResourceLoader.exists(tex_path):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/water_map_3d.gdshader")
		mat.set_shader_parameter("sea_tex", load(tex_path))
		mat.set_shader_parameter("tile_scale", Vector2(11.0, 11.0))
		mat.set_shader_parameter("tint", Vector3(0.62, 0.76, 0.95))
		mat.set_shader_parameter("deep_color", Vector3(0.10, 0.26, 0.42))
		mat.set_shader_parameter("flatten", 0.62)
		sea.material_override = mat
	else:
		sea.material_override = _mat(Color(0.22, 0.42, 0.55))
	add_child(sea)


func _cyl(top_r: float, bottom_r: float, h: float, pos: Vector3,
		color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = h
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _mat(color)
	add_child(mi)
	return mi


func _spawn_barrels(spots: Array, tipped_idx: int = -1) -> void:
	var barrel_path := "res://assets/models/barril.glb"
	if not ResourceLoader.exists(barrel_path):
		return
	var barrel: PackedScene = load(barrel_path)
	for i in spots.size():
		var b := _spawn_model(barrel, spots[i], 0.95, self)
		if i == tipped_idx:
			b.rotation_degrees = Vector3(90.0, 25.0, 0.0)
			b.position.y = 0.33


## ISLA: arenal rodeado de mar, palmeras, rocas y algo de carga varada.
func _scenery_island() -> void:
	# Dos discos de arena (el de abajo mas oscuro hace de orilla mojada). Radio
	# contenido para que el MAR asome por los bordes de la pantalla.
	# La arena va MATE y en tono tostado: en blanco crudo deslumbraba y se
	# comia el contraste de los personajes y los platos.
	_cyl(7.4, 7.8, 0.30, Vector3(0.0, -0.42, 0.0), Color(0.52, 0.44, 0.30))
	var sand := _cyl(6.9, 7.3, 0.28, Vector3(0.0, -0.14, 0.0),
		Color(0.63, 0.55, 0.39))
	sand.material_override.roughness = 1.0
	sand.material_override.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# Palmeras fuera del pasillo de los clientes (radio 3.7, bordas en ±4.2)
	# pero DENTRO del encuadre (la pantalla es estrecha a los lados).
	_palm(Vector3(-5.2, 0.0, -2.4), 0.0)
	_palm(Vector3(1.2, 0.0, -5.2), 140.0)
	# Esta se aparto hacia +X: en su sitio anterior la copa caia justo encima
	# de los taburetes de ese lado y tapaba al cliente sentado alli.
	_palm(Vector3(5.2, 0.0, -2.0), 250.0)
	_palm(Vector3(-1.4, 0.0, 5.1), 60.0)
	# Cabaña de playa en la zona alta: de ahi bajan los clientes de esa borda
	# (antes aparecian de la nada al borde del arenal).
	_beach_hut(Vector3(-5.2, 0.0, -5.2))
	# Rocas y carga varada.
	for r in [[Vector3(-4.9, 0.0, 0.4), 0.5], [Vector3(0.8, 0.0, -5.6), 0.42],
			[Vector3(4.6, 0.0, -0.6), 0.3]]:
		var rock := _box(Vector3(r[1] * 2.0, r[1], r[1] * 1.5),
			r[0] + Vector3(0.0, r[1] * 0.4, 0.0), Color(0.55, 0.50, 0.44))
		rock.rotation_degrees.y = r[0].x * 37.0
	_box_mat(Vector3(0.66, 0.66, 0.66), Vector3(-5.4, 0.33, -2.2),
		_wood_mat(CRATE_TEX, Color(0.92, 0.86, 0.74), 1.4))
	_spawn_barrels([Vector3(-5.9, 0.0, -1.2), Vector3(5.0, 0.0, 3.2)], 1)


## Cabaña de playa con techo de palma: el punto del que "vienen" los clientes
## de la borda alta de la isla.
func _beach_hut(pos: Vector3) -> void:
	var wall := _wood_mat(CRATE_TEX, Color(0.86, 0.78, 0.62), 1.0)
	var body := _box_mat(Vector3(3.2, 2.0, 2.4), pos + Vector3(0.0, 1.0, 0.0), wall)
	body.rotation_degrees.y = 45.0
	# Techo de hojas de palma: cuatro faldones superpuestos.
	for i in 4:
		var thatch := _box(Vector3(3.9 - i * 0.35, 0.16, 2.9 - i * 0.3),
			pos + Vector3(0.0, 2.12 + i * 0.22, 0.0), Color(0.52, 0.42, 0.20))
		thatch.rotation_degrees.y = 45.0
	var inward := -pos.normalized()
	var door := _box(Vector3(1.1, 1.5, 0.1),
		pos + inward * 1.25 + Vector3(0.0, 0.75, 0.0), Color(0.28, 0.20, 0.12))
	door.rotation_degrees.y = 45.0


## Palmera low poly: tronco inclinado + corona de hojas + cocos.
func _palm(pos: Vector3, yaw: float) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation_degrees.y = yaw
	add_child(pivot)
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.09
	cyl.bottom_radius = 0.15
	cyl.height = 3.1
	trunk.mesh = cyl
	trunk.material_override = _mat(Color(0.52, 0.38, 0.22))
	trunk.position = Vector3(0.25, 1.5, 0.0)
	trunk.rotation_degrees.z = -10.0
	pivot.add_child(trunk)
	var crown := Node3D.new()
	crown.position = Vector3(0.52, 3.05, 0.0)
	pivot.add_child(crown)
	for i in 6:
		var leaf_pivot := Node3D.new()
		leaf_pivot.rotation_degrees.y = i * 60.0
		crown.add_child(leaf_pivot)
		var leaf := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(1.5, 0.05, 0.4)
		leaf.mesh = lb
		leaf.material_override = _mat(Color(0.22, 0.48, 0.24))
		leaf.position = Vector3(0.68, 0.0, 0.0)
		leaf.rotation_degrees.z = -16.0
		leaf_pivot.add_child(leaf)
	for c in [Vector3(0.38, 2.9, 0.14), Vector3(0.6, 2.85, -0.12)]:
		var coco := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.1
		sph.height = 0.2
		coco.mesh = sph
		coco.material_override = _mat(Color(0.38, 0.28, 0.16))
		coco.position = c
		pivot.add_child(coco)


## PUERTO: muelle de tablones grises sobre el mar, norays, farol y mercancia.
func _scenery_port() -> void:
	# Misma textura de tablones que el barco, tintada de gris salino: es un
	# muelle castigado por el agua, no madera nueva.
	var dock_mat := _wood_mat(DECK_TEX, Color(0.80, 0.80, 0.74), 0.17)
	var post_mat := _wood_mat(DECK_TEX, Color(0.55, 0.46, 0.34), 0.9)
	var crate_mat := _wood_mat(CRATE_TEX, Color(0.92, 0.86, 0.74), 1.4)
	# Tarima GIRADA 45 y recortada, no un cuadrado que llenaba la pantalla:
	# cubre de sobra el anillo de paso y las dos bordas de entrada, pero deja
	# ver el MAR por encima del muelle. Antes acababa justo donde llegaban los
	# clientes de arriba y parecian aparecer de la nada.
	var deck := _box_mat(Vector3(14.0, 0.22, 13.2), Vector3(0.0, -0.11, 0.0), dock_mat)
	deck.rotation_degrees.y = 45.0
	# Canto del muelle: la tarima tiene grosor y se apoya sobre el agua.
	var edge := _box_mat(Vector3(13.4, 0.55, 12.6), Vector3(0.0, -0.42, 0.0), post_mat)
	edge.rotation_degrees.y = 45.0
	# Almacen del puerto al fondo (zona alta): de su porton salen los clientes
	# de esa borda, asi la entrada tiene de donde venir. Justo detras de la
	# borda: mas al fondo se le comia la barra superior del HUD.
	_port_warehouse(Vector3(-5.2, 0.0, -5.2), dock_mat, post_mat)
	# Pilotes del muelle asomando por los bordes.
	for p in [Vector3(-7.4, 0.0, -3.4), Vector3(-3.6, 0.0, -7.6),
			Vector3(7.4, 0.0, 3.0), Vector3(3.0, 0.0, 7.6),
			Vector3(-7.6, 0.0, 3.8), Vector3(6.4, 0.0, -6.2)]:
		_cyl(0.16, 0.18, 1.15, p + Vector3(0.0, 0.45, 0.0), Color(0.35, 0.26, 0.15))
		var knob := _cyl(0.20, 0.22, 0.14, p + Vector3(0.0, 1.08, 0.0),
			Color(0.30, 0.22, 0.13))
		knob.rotation_degrees.y = p.x * 20.0
	# Norays de amarre con su cabo enrollado.
	for b in [Vector3(-2.2, 0.0, 6.6), Vector3(5.6, 0.0, -2.0)]:
		_cyl(0.17, 0.21, 0.5, b + Vector3(0.0, 0.25, 0.0), Color(0.22, 0.20, 0.19))
		_cyl(0.26, 0.26, 0.09, b + Vector3(0.0, 0.16, 0.0), Color(0.52, 0.42, 0.26))
	# Farol de muelle: poste alto con caja de luz calida.
	_cyl(0.07, 0.09, 2.6, Vector3(-3.4, 1.3, -4.9), Color(0.25, 0.20, 0.14))
	var lamp := _box(Vector3(0.30, 0.34, 0.30), Vector3(-3.4, 2.72, -4.9),
		Color(1.0, 0.85, 0.45))
	lamp.material_override.emission_enabled = true
	lamp.material_override.emission = Color(1.0, 0.8, 0.35)
	lamp.material_override.emission_energy_multiplier = 0.7
	# Mercancia del muelle: cajas apiladas y barriles.
	_box_mat(Vector3(0.72, 0.72, 0.72), Vector3(-5.2, 0.36, -2.3), crate_mat)
	_box_mat(Vector3(0.58, 0.58, 0.58), Vector3(-5.05, 1.01, -2.2), crate_mat)
	_box_mat(Vector3(0.62, 0.62, 0.62), Vector3(5.2, 0.31, 2.0), crate_mat)
	_box_mat(Vector3(0.55, 0.55, 0.55), Vector3(2.0, 0.28, 6.4), crate_mat)
	_spawn_barrels([Vector3(-6.4, 0.0, -1.2), Vector3(1.6, 0.0, -6.4),
		Vector3(6.2, 0.0, 0.9)], 2)


## Cobertizo del muelle con su porton: sirve de "de donde vienen" los clientes
## de la borda alta y de tope visual para que el muelle no acabe en el vacio.
func _port_warehouse(pos: Vector3, wall_mat: Material, trim_mat: Material) -> void:
	var body := _box_mat(Vector3(4.6, 2.5, 3.0), pos + Vector3(0.0, 1.25, 0.0), wall_mat)
	body.rotation_degrees.y = 45.0
	# Tejado a dos aguas, en dos planos inclinados.
	for side in [-1.0, 1.0]:
		var roof := _box_mat(Vector3(4.9, 0.16, 1.85),
			pos + Vector3(0.0, 2.72, 0.0)
			+ (Vector3(1.0, 0.0, 1.0) / sqrt(2.0)) * side * 0.78, trim_mat)
		roof.rotation_degrees = Vector3(0.0, 45.0, 0.0)
		roof.rotate_object_local(Vector3.RIGHT, deg_to_rad(-side * 22.0))
	# Porton oscuro mirando al circuito (hacia el centro).
	var inward := -pos.normalized()
	var door := _box(Vector3(1.5, 1.8, 0.12), pos + inward * 1.55 + Vector3(0.0, 0.9, 0.0),
		Color(0.24, 0.17, 0.10))
	door.rotation_degrees.y = 45.0


## ABORDAJE: el barco pirata de siempre, pero viejo y castigado — tablones
## descoloridos y arrancados (se ve el mar), barandilla rota, manchas,
## restos de carga y velas rasgadas en el mastil central.
func _scenery_ship() -> void:
	var deck_mat := _wood_mat(DECK_TEX, Color(0.72, 0.56, 0.38), 0.17)
	var trim_mat := _wood_mat(DECK_TEX, Color(0.58, 0.42, 0.26), 0.7)
	var crate_mat := _wood_mat(CRATE_TEX, Color(0.90, 0.82, 0.70), 1.4)

	# Cubierta: UNA losa con la textura de tablones desgastados en vez de 38
	# cajas de color plano. Antes tres tablones "arrancados" cruzaban la
	# cubierta de lado a lado y dejaban el mar asomando justo bajo un
	# taburete (la silla parecia flotar); ahora los desperfectos son locales
	# y estan SIEMPRE fuera del anillo por el que andan los clientes.
	#
	# Va GIRADA 45 y recortada por la proa: asi es un BARCO con eslora y manga
	# —el costado y el mar asoman por encima de la borda alta— en vez de una
	# habitacion de madera que llenaba la pantalla de lado a lado.
	var deck := _box_mat(Vector3(14.0, 0.22, 13.2), Vector3(0.0, -0.11, 0.0), deck_mat)
	deck.rotation_degrees.y = 45.0
	# Costado del casco bajo la cubierta: se hunde por debajo del nivel del mar
	# (y=-0.55), asi el barco flota en vez de posarse sobre el agua.
	var hull := _box_mat(Vector3(13.4, 1.10, 12.6), Vector3(0.0, -0.75, 0.0),
		_wood_mat(DECK_TEX, Color(0.42, 0.30, 0.19), 0.17))
	hull.rotation_degrees.y = 45.0
	# Boquete real en la cubierta, en una esquina alejada del juego: se ve el
	# mar por el hueco y quedan dos tablas partidas asomando.
	_hull_hole(Vector3(-7.4, 0.0, 5.6), 1.5)
	_hull_hole(Vector3(6.8, 0.0, -6.4), 1.1)
	# Manchas oscuras de humedad/polvora.
	for m in [[Vector3(-3.4, 0.0, -4.6), 1.5], [Vector3(4.6, 0.0, 3.2), 1.1],
			[Vector3(-4.8, 0.0, 4.6), 0.9]]:
		var stain := _box(Vector3(m[1], 0.012, m[1] * 0.7),
			m[0] + Vector3(0.0, 0.012, 0.0), Color(0.26, 0.19, 0.12))
		stain.rotation_degrees.y = m[0].z * 31.0
	# Bordas: sobre la linea de barandilla va una regala de madera, para que el
	# barco tenga costado y no parezca una balsa plana.
	for base in [ENTRY, ENTRY_BOTTOM]:
		var gunwale := _box_mat(Vector3(17.0, 0.30, 0.26),
			base + Vector3(0.0, 0.15, 0.0), trim_mat)
		gunwale.rotation_degrees.y = 45.0
	# Barandillas rotas en ambas bordas, con huecos de embarque.
	_railing_diag(ENTRY, -6.5, -0.8, true)
	_railing_diag(ENTRY, 0.8, 7.5, true)
	_railing_diag(ENTRY_BOTTOM, -7.5, -0.8, true)
	_railing_diag(ENTRY_BOTTOM, 0.8, 6.5, true)
	# Escalera de toldilla en el hueco de embarque de ARRIBA: de ahi suben los
	# clientes de esa borda, en vez de materializarse en mitad de la cubierta.
	_deck_stairs(ENTRY, trim_mat)
	# Mastil TRONCHADO, sin velas y a media altura. Un palo entero (o incluso
	# uno roto de 3 m con la vela colgando) se iba por el borde superior de la
	# pantalla y chocaba con el HUD; el tocon astillado cabe de sobra, no tapa
	# nada y cuenta lo mismo: a este barco lo han abordado.
	_broken_mast(Vector3(-1.4, 0.0, -5.4))
	# Cañones asomando por la borda alta: identidad de barco a ras de cubierta,
	# que es la unica altura libre en un encuadre tan bajo.
	for t in [-3.4, 2.9]:
		_deck_cannon(ENTRY + Vector3(1.0, 0.0, -1.0) / sqrt(2.0) * t)
	# Carga y destrozos: cajas junto a cada embarque, caja rota y barriles.
	_box_mat(Vector3(0.72, 0.72, 0.72), Vector3(-5.3, 0.36, -2.5), crate_mat)
	_box_mat(Vector3(0.58, 0.58, 0.58), Vector3(-5.15, 1.01, -2.4), crate_mat)
	_box_mat(Vector3(0.62, 0.62, 0.62), Vector3(5.4, 0.31, 2.3), crate_mat)
	var broken_a := _box_mat(Vector3(0.6, 0.1, 0.5), Vector3(2.4, 0.05, 6.1), crate_mat)
	broken_a.rotation_degrees.y = 24.0
	var broken_b := _box_mat(Vector3(0.5, 0.4, 0.09), Vector3(2.75, 0.2, 6.35), crate_mat)
	broken_b.rotation_degrees = Vector3(0.0, -18.0, 74.0)
	# Barriles apartados de la linea de barandilla (uno la atravesaba).
	_spawn_barrels([Vector3(-6.6, 0.0, -0.4), Vector3(5.9, 0.0, -1.0)], 1)


## Boquete en la cubierta: agujero oscuro con el mar al fondo y un par de
## tablas partidas en el borde. Se usa lejos del anillo de paso.
func _hull_hole(pos: Vector3, size: float) -> void:
	var hole := _box(Vector3(size, 0.03, size * 0.8), pos + Vector3(0.0, 0.005, 0.0),
		Color(0.05, 0.12, 0.18))
	hole.rotation_degrees.y = pos.x * 23.0
	for s in [[-0.5, 0.42, 18.0], [0.44, -0.3, -26.0]]:
		var splinter := _box(Vector3(size * 0.5, 0.07, 0.14),
			pos + Vector3(s[0] * size, 0.05, s[1] * size), Color(0.40, 0.28, 0.16))
		splinter.rotation_degrees = Vector3(0.0, s[2], 12.0)


## Escalera de subida a cubierta en el hueco de embarque: cuatro peldaños que
## bajan hacia el costado, para que los clientes lleguen "desde el barco" y no
## aparezcan de la nada. Se alinea con la diagonal de la borda.
func _deck_stairs(base: Vector3, mat: Material) -> void:
	# Los peldaños SUBEN hacia fuera hasta un rellano: bajando por el costado
	# quedaban tapados por la regala y no se veia nada. Subiendo, el rellano
	# asoma por encima de la borda y se lee de donde baja el cliente.
	var out := base.normalized()
	for i in 4:
		var step := _box_mat(Vector3(1.7, 0.16, 0.36),
			base + out * (0.36 + i * 0.36) + Vector3(0.0, 0.08 + i * 0.16, 0.0), mat)
		step.rotation_degrees.y = 45.0
	var landing := _box_mat(Vector3(2.4, 0.18, 1.5),
		base + out * 2.55 + Vector3(0.0, 0.72, 0.0), mat)
	landing.rotation_degrees.y = 45.0
	# Barandal a los lados de la escalera, siguiendo la pendiente.
	for side in [-1.0, 1.0]:
		var lateral: Vector3 = Vector3(out.z, 0.0, -out.x) * side * 0.85
		var rail := _box_mat(Vector3(0.10, 0.10, 2.0),
			base + lateral + out * 1.1 + Vector3(0.0, 0.72, 0.0), mat)
		rail.rotation_degrees = Vector3(0.0, 45.0, 0.0)
		rail.rotate_object_local(Vector3.RIGHT, deg_to_rad(-22.0))
		for k in 2:
			_box_mat(Vector3(0.09, 0.55, 0.09),
				base + lateral + out * (0.5 + k * 1.3)
				+ Vector3(0.0, 0.28 + k * 0.30, 0.0), mat)


## Tocon de mastil tronchado, con la base y un rollo de cabo alrededor. Sin
## verga ni velas: ver _scenery_ship para por que se quitaron.
func _broken_mast(pos: Vector3) -> void:
	var h := 1.55
	_cyl(0.20, 0.24, h, pos + Vector3(0.0, h * 0.5, 0.0), Color(0.36, 0.24, 0.13))
	_cyl(0.34, 0.37, 0.20, pos + Vector3(0.0, 0.10, 0.0), Color(0.55, 0.45, 0.31))
	# Astillas del tronchazo, arriba del todo.
	for s in [[-0.10, 0.26, 14.0], [0.11, 0.36, -18.0], [0.02, 0.18, 6.0]]:
		var chip := _box(Vector3(0.11, s[1], 0.11),
			pos + Vector3(s[0], h + s[1] * 0.42, s[0] * 0.7), Color(0.44, 0.31, 0.17))
		chip.rotation_degrees.z = s[2]
	# Cabo enrollado en la base.
	_cyl(0.44, 0.44, 0.09, pos + Vector3(0.0, 0.24, 0.0), Color(0.62, 0.52, 0.34))


## Cañon de cubierta apuntando a la borda, sobre su cureña de madera.
func _deck_cannon(pos: Vector3) -> void:
	var out := pos.normalized()
	var yaw := rad_to_deg(atan2(out.x, out.z))
	var carriage := _box_mat(Vector3(0.46, 0.20, 0.62), pos + Vector3(0.0, 0.10, 0.0),
		_wood_mat(CRATE_TEX, Color(0.62, 0.50, 0.36), 1.6))
	carriage.rotation_degrees.y = yaw
	var barrel := _cyl(0.09, 0.13, 0.86, pos + Vector3(0.0, 0.30, 0.0) + out * 0.14,
		Color(0.17, 0.17, 0.19))
	barrel.rotation_degrees = Vector3(0.0, yaw, 0.0)
	barrel.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
	for side in [-1.0, 1.0]:
		var lateral: Vector3 = Vector3(out.z, 0.0, -out.x) * side * 0.20
		_cyl(0.10, 0.10, 0.06, pos + lateral + Vector3(0.0, 0.07, 0.0),
			Color(0.30, 0.21, 0.12)).rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))


## Tramo de barandilla sobre la diagonal p(t) = base + t*(1,0,-1)/v2 (la
## eslora a lo ancho de la vista), del parametro t0 a t1. En el barco del
## abordaje ("worn") faltan postes, otros estan torcidos y el liston va roto.
func _railing_diag(base: Vector3, t0: float, t1: float, worn: bool = false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(base.x * 13.0 + t0 * 7.0)
	var dir := Vector3(1.0, 0.0, -1.0) / sqrt(2.0)
	var length := t1 - t0
	var posts := int(round(length / 1.1))
	for i in range(posts + 1):
		if worn and rng.randf() < 0.22:
			continue
		var p := base + dir * (t0 + length * float(i) / float(posts))
		var post := _box(Vector3(0.10, 0.88, 0.10), p + Vector3(0.0, 0.44, 0.0),
			Color(0.38, 0.26, 0.14))
		if worn and rng.randf() < 0.3:
			post.rotation_degrees.z = rng.randf_range(-14.0, 14.0)
	var rails := [[0.88, 0.09, 0.13], [0.48, 0.07, 0.10]]
	for rail in rails:
		if worn and rail[0] < 0.5 and length > 4.0:
			# El liston bajo va partido: dos trozos con un hueco en medio.
			_rail_piece(base, t0, t0 + length * 0.42, rail, -3.0)
			_rail_piece(base, t0 + length * 0.58, t1, rail, 2.0)
		else:
			_rail_piece(base, t0, t1, rail, 0.0)


func _rail_piece(base: Vector3, t0: float, t1: float, rail: Array,
		tilt: float) -> void:
	var dir := Vector3(1.0, 0.0, -1.0) / sqrt(2.0)
	var mid := base + dir * ((t0 + t1) * 0.5)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(t1 - t0 + 0.1, rail[1], rail[2])
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = mid + Vector3(0.0, rail[0], 0.0)
	mi.rotation_degrees.y = 45.0
	mi.rotation_degrees.z = tilt
	mi.material_override = _mat(Color(0.46, 0.32, 0.17))
	add_child(mi)


## Mostrador de madera + banda MOVIL encima + placa metalica en cada esquina
## (el codo por donde los platos doblan). La banda avanza empujando el uniform
## "scroll_tiles" desde _process, para poder pararla al congelar y acelerarla
## con "Cinta rapida".
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

	# Placa metalica de esquina: tapa el codo entre dos tramos de banda, donde
	# el plato dobla. Va con un canto oscuro debajo para que tenga grosor.
	for corner in [Vector3(h, 0, h), Vector3(h, 0, -h),
			Vector3(-h, 0, h), Vector3(-h, 0, -h)]:
		_box(Vector3(CORNER + 0.04, 0.045, CORNER + 0.04),
			corner + Vector3(0.0, BELT_TOP + 0.022, 0.0), Color(0.13, 0.14, 0.16))
		# Acero MATE: con brillo especular la placa horizontal reventaba a
		# blanco puro bajo el sol y se comia la esquina.
		var plate := _box(Vector3(CORNER, 0.03, CORNER),
			corner + Vector3(0.0, BELT_TOP + 0.052, 0.0), Color(0.42, 0.45, 0.50))
		plate.material_override.roughness = 1.0
		plate.material_override.specular_mode = BaseMaterial3D.SPECULAR_DISABLED


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
			# Sillas de los lados inferiores de pantalla (+X/+Z) usan la borda
			# inferior; las superiores (-Z/-X), la superior.
			var lower := n.x > 0.5 or n.z > 0.5
			seats.append({
				"pos": pos,
				"yaw": rad_to_deg(atan2(-n.x, -n.z)),
				"belt": n * (BELT_SIDE * 0.5) + offset + Vector3(0.0, BELT_TOP, 0.0),
				"ring": n * WALK_R + offset,
				"entry": ENTRY_BOTTOM if lower else ENTRY,
			})


func _add_stool(pos: Vector3) -> void:
	_box(Vector3(0.46, 0.09, 0.46), pos + Vector3(0.0, STOOL_H - 0.045, 0.0),
		Color(0.40, 0.26, 0.15))
	_box(Vector3(0.11, STOOL_H - 0.09, 0.11),
		pos + Vector3(0.0, (STOOL_H - 0.09) * 0.5, 0.0), Color(0.34, 0.22, 0.13))


## El chef vive DENTRO del circuito, como en 2D, detras de su mesa: mesa y
## chef estan orientados hacia el MISMO lado (la esquina inferior de pantalla,
## de cara a la camara). Respira y reacciona a cada gesto del jugador (tweens).
func _setup_chef() -> void:
	# Chef y mesa miran a +Z, que con la camara iso (yaw 45) es la diagonal
	# ABAJO-IZQUIERDA de la pantalla: se le ve la cara y trabaja de lado, sin
	# darle la espalda al jugador ni taparse la mesa con el cuerpo.
	var c_pos := Vector3(-0.45, 0.0, -0.60)
	var t_pos := c_pos + Vector3(0.0, 0.0, 0.92)
	_box(Vector3(0.90, 0.78, 0.60), t_pos + Vector3(0.0, 0.39, 0.0),
		Color(0.40, 0.27, 0.14))
	_box(Vector3(1.02, 0.07, 0.72), t_pos + Vector3(0.0, 0.815, 0.0),
		Color(0.62, 0.45, 0.26))
	chef_pivot = _spawn_model(load("res://assets/models/chef_rig.glb"),
		c_pos, CHEF_H, self)
	chef_pivot.rotation_degrees.y = 0.0
	_setup_chef_crates(c_pos)
	var skels := chef_pivot.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		chef_anim = CharacterAnim.new(skels[0])
		if not chef_anim.has_humanoid_bones():
			chef_anim = null
		else:
			var inst: Node3D = chef_pivot.get_child(0)
			_make_chef_tools(skels[0], inst.scale.x)
	# El ingrediente/etapa en curso se muestra sobre la mesa del chef.
	chef_prop = Sprite3D.new()
	chef_prop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	chef_prop.position = t_pos + Vector3(0.0, 1.12, 0.0)
	chef_prop.visible = false
	add_child(chef_prop)


## Cajas de guardado JUNTO AL CHEF: el gemelo 3D de las cajas del HUD. Lo que
## el jugador guarda en la interfaz aparece tambien aqui (mismo modelo de plato
## que va por la cinta), asi la barra cuenta lo que pasa sin mirar el HUD.
func _setup_chef_crates(chef_pos: Vector3) -> void:
	# Van SOBRE UN BANCO, no en el suelo: el mostrador mide 0.8 de alto y desde
	# la camara isometrica tapaba por completo cualquier cosa puesta al ras del
	# suelo dentro del circuito. Encaramadas al banco asoman por encima.
	var bench := chef_pos + Vector3(1.05, 0.0, -0.15)
	var wood := _wood_mat(CRATE_TEX, Color(0.80, 0.72, 0.60), 1.4)
	_box_mat(Vector3(0.62, 0.08, 1.30), bench + Vector3(0.0, CRATE_LIFT, 0.0), wood)
	for lx in [-0.22, 0.22]:
		_box_mat(Vector3(0.09, CRATE_LIFT, 0.09),
			bench + Vector3(0.0, CRATE_LIFT * 0.5, lx * 2.4), wood)
	var spots := [bench + Vector3(0.0, CRATE_LIFT + 0.04, -0.32),
		bench + Vector3(0.0, CRATE_LIFT + 0.04, 0.32),
		bench + Vector3(0.0, CRATE_LIFT + 0.04, 0.0)]
	for i in spots.size():
		var crate := Node3D.new()
		crate.position = spots[i]
		crate.rotation_degrees.y = i * 6.0
		add_child(crate)
		# Cajon de madera: suelo, cuatro paredes bajas y un canto mas claro.
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(CRATE_W, CRATE_H, CRATE_W)
		body.mesh = bm
		body.position = Vector3(0.0, CRATE_H * 0.5, 0.0)
		body.material_override = wood
		crate.add_child(body)
		var rim := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(CRATE_W + 0.04, 0.05, CRATE_W + 0.04)
		rim.mesh = rm
		rim.position = Vector3(0.0, CRATE_H, 0.0)
		rim.material_override = _mat(Color(0.58, 0.42, 0.24))
		crate.add_child(rim)
		# Nodo vacio donde se apilan los platos guardados de esa caja.
		var slot := Node3D.new()
		slot.position = Vector3(0.0, CRATE_H + 0.03, 0.0)
		crate.add_child(slot)
		chef_crates.append(slot)


## Refleja en las cajas 3D lo que hay en las cajas del HUD (prep_board).
func _on_storage_changed(slots: Array) -> void:
	for i in chef_crates.size():
		var holder: Node3D = chef_crates[i]
		for c in holder.get_children():
			c.queue_free()
		if i >= slots.size() or slots[i] == null:
			continue
		var id: String = slots[i]["id"]
		var path := "res://assets/models/%s.glb" % id
		if not ResourceLoader.exists(path):
			continue
		# Se apilan hasta 3 platos aunque la pila sea mayor: mas no caben en la
		# caja y el numero exacto ya lo canta el "xN" del HUD.
		var shown: int = mini(int(slots[i]["count"]), 3)
		for k in shown:
			var p := _spawn_model(load(path), Vector3(0.0, k * 0.09, 0.0),
				CRATE_DISH, holder)
			# El plato normaliza por ALTURA en _spawn_model; aqui interesa que
			# quepa en la caja, asi que se reescala por su huella.
			var inst: Node3D = p.get_child(0)
			var aabb := _merged_aabb(inst)
			var foot := maxf(maxf(aabb.size.x, aabb.size.z), 0.0001)
			inst.scale *= CRATE_DISH / foot
			inst.position *= CRATE_DISH / foot
			p.rotation_degrees.y = -30.0 + k * 24.0


## Utensilios low poly del chef, construidos por codigo y colgados de la
## MUÑECA derecha con un BoneAttachment3D: siguen la mano alla donde la lleve
## la animacion. Se autoran en unidades de mundo (el nodo raiz deshace la
## escala del modelo) con el filo/mango a lo largo de +Z, la linea de los
## nudillos del puño cerrado (empuñadura de martillo).
func _make_chef_tools(skel: Skeleton3D, model_scale: float) -> void:
	var wrist := chef_anim.bone("R_Wrist")
	if wrist < 0:
		return
	var att := BoneAttachment3D.new()
	skel.add_child(att)
	att.bone_name = skel.get_bone_name(wrist)

	# La hoja corre a lo largo de +X local (cruzada respecto al cuerpo): con
	# +Z apuntaba al frente del chef y desde la camara se veia como un palillo.
	chef_knife = Node3D.new()
	att.add_child(chef_knife)
	chef_knife.scale = Vector3.ONE / model_scale
	chef_knife.position = Vector3(0.0, -0.05, 0.0) / model_scale
	chef_knife.rotation_degrees.y = 90.0
	_tool_box(chef_knife, Vector3(0.05, 0.06, 0.16), Vector3(0.0, 0.0, -0.055),
		Color(0.34, 0.21, 0.11))
	_tool_box(chef_knife, Vector3(0.02, 0.10, 0.34), Vector3(0.0, -0.012, 0.20),
		Color(0.82, 0.84, 0.88))
	chef_knife.visible = false

	chef_ladle = Node3D.new()
	att.add_child(chef_ladle)
	chef_ladle.scale = Vector3.ONE / model_scale
	chef_ladle.position = Vector3(0.0, -0.05, 0.0) / model_scale
	chef_ladle.rotation_degrees.y = 90.0
	_tool_box(chef_ladle, Vector3(0.038, 0.038, 0.36), Vector3(0.0, 0.0, 0.11),
		Color(0.46, 0.30, 0.16))
	var cup := MeshInstance3D.new()
	var cup_mesh := CylinderMesh.new()
	cup_mesh.top_radius = 0.075
	cup_mesh.bottom_radius = 0.055
	cup_mesh.height = 0.06
	cup.mesh = cup_mesh
	cup.position = Vector3(0.0, -0.03, 0.32)
	cup.material_override = _mat(Color(0.35, 0.36, 0.40))
	chef_ladle.add_child(cup)
	chef_ladle.visible = false


func _tool_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _mat(color)
	parent.add_child(mi)


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


## Reacciones del chef a cada gesto del jugador: dispara la animacion de
## cocina correspondiente (brazos por IK, ver chef_* en CharacterAnim) y pone
## el utensilio que toque en su mano. Un evento = una ejecucion del gesto, asi
## que el chef pica, corta o remueve al MISMO ritmo que el dedo del usuario.
func _on_craft_event(kind: String, stage_id: String) -> void:
	var tex := RecipeData.get_stage_texture(stage_id)
	chef_prop.texture = tex
	chef_prop.visible = tex != null
	if tex != null:
		chef_prop.pixel_size = 0.55 / tex.get_width()

	match kind:
		"tap", "stage":
			_chef_gesture("pat", 0.30, "")
		"cut":
			_chef_gesture("chop", 0.26, "knife")
		"slice":
			# El evento llega al TERMINAR el corte lento; el chef lo replica
			# con su propio corte pausado.
			_chef_gesture("slice", 0.8, "knife")
		"swipe":
			_chef_gesture("roll", 0.45, "")
		"hold":
			_chef_gesture("stir", 0.9, "ladle")
		"stir":
			# Un evento por vuelta completa del jugador: el cazo del chef da
			# una vuelta por cada una, y encadena sin salto si vienen seguidas.
			_chef_gesture("stir", 0.6, "ladle")
		"drag", "select":
			_chef_gesture("place", 0.5, "")
		"serve":
			_chef_gesture("place", 0.45, "")
		"cancel":
			_chef_gesture("clear", 0.5, "")
		"done":
			# Plato terminado: brazos arriba y saltito del pivote.
			_chef_gesture("cheer", 0.7, "")
			if chef_tween != null:
				chef_tween.kill()
				chef_pivot.position.y = 0.0
			chef_tween = create_tween()
			chef_tween.tween_property(chef_pivot, "position:y", 0.14, 0.12)
			chef_tween.tween_property(chef_pivot, "position:y", 0.0, 0.15)


## Arranca (o encadena) un gesto de cocina. "stir" es ciclico: si llega otro
## evento con el gesto aun en marcha, EXTIENDE el giro en vez de reiniciarlo
## (reiniciar daba un salto de fase visible del cazo).
func _chef_gesture(name: String, dur: float, tool: String) -> void:
	_show_chef_tool(tool)
	chef_tool_linger = 0.0
	if name == chef_gesture and name == "stir":
		chef_gesture_end = chef_gesture_t + dur
		return
	chef_gesture = name
	chef_gesture_t = 0.0
	chef_gesture_dur = dur
	chef_gesture_end = dur


func _show_chef_tool(tool: String) -> void:
	if chef_knife != null:
		chef_knife.visible = tool == "knife"
	if chef_ladle != null:
		chef_ladle.visible = tool == "ladle"


# ------------------------------------------------------------------- bucle

func _process(delta: float) -> void:
	_t += delta
	# El ayudante trabaja a su ritmo, desfasado del chef para que no parezcan
	# dos copias del mismo muñeco.
	if helper_anim != null:
		helper_anim.reset()
		helper_anim.chef_pat(fmod(_t * 1.35, 1.0))
	if chef_anim != null:
		chef_anim.reset()
		if chef_gesture != "":
			chef_gesture_t += delta
			if chef_gesture_t >= chef_gesture_end:
				chef_gesture = ""
				# El utensilio se queda un momento en la mano por si el
				# jugador encadena otro gesto igual (evita el parpadeo).
				chef_tool_linger = 0.9
				chef_anim.idle(_t)
			else:
				# "stir" cicla con fase continua; el resto son de una pasada.
				var u := fmod(chef_gesture_t, chef_gesture_dur) / chef_gesture_dur \
					if chef_gesture == "stir" else chef_gesture_t / chef_gesture_dur
				match chef_gesture:
					"pat": chef_anim.chef_pat(u)
					"chop": chef_anim.chef_chop(u)
					"slice": chef_anim.chef_slice(u)
					"roll": chef_anim.chef_roll(u)
					"stir": chef_anim.chef_stir(u)
					"place": chef_anim.chef_place(u)
					"clear": chef_anim.chef_clear(u)
					"cheer": chef_anim.chef_cheer(u)
		else:
			if chef_tool_linger > 0.0:
				chef_tool_linger -= delta
				if chef_tool_linger <= 0.0:
					_show_chef_tool("")
			chef_anim.idle(_t)

	if ended:
		# Los reportes ya estan (force_leave es inmediato). Se esperan 4 s con
		# todo parado (cinta, platos y tabla) para ver a los clientes irse
		# antes de mostrar el cartel de fin de nivel.
		if not results_shown:
			end_grace += delta
			if end_grace >= 4.0:
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
	# Entra andando por la borda mas cercana a su asiento, rodea el mostrador
	# y llega a su taburete; al marcharse saldra por esa misma borda.
	var entry: Vector3 = seats[idx]["entry"]
	c.position = entry
	c.route = _route_for_seat(idx)
	c.exit_point = entry
	c.belt_point = seats[idx]["belt"]
	c.seat_yaw = seats[idx]["yaw"]
	add_child(c)
	c.finished.connect(_on_client_finished.bind(idx))
	c.plate_served.connect(_on_client_served)
	seat_clients[idx] = c
	clients_spawned += 1
	_update_client_heads()
	return true


## Ruta de entrada: desde SU borda (la esquina superior para las sillas de
## arriba, la inferior para las de abajo), por el pasillo exterior (cuadrado de
## radio WALK_R), doblando por las esquinas que toque en el sentido mas corto,
## hasta el punto tras su asiento y de ahi al taburete.
func _route_for_seat(idx: int) -> Array:
	var ring: Vector3 = seats[idx]["ring"]
	var entry: Vector3 = seats[idx]["entry"]
	var r := WALK_R
	var perim := 8.0 * r
	var corners := [Vector3(-r, 0, -r), Vector3(r, 0, -r),
		Vector3(r, 0, r), Vector3(-r, 0, r)]
	# Parametro de perimetro de la esquina de entrada (la superior (-r,-r) es 0,
	# la inferior (r,r) es 4r) y del punto destino tras el asiento.
	var s_e := 0.0 if entry == ENTRY else 4.0 * r
	var s_b := _ring_param(ring)
	var route: Array = [entry]
	var fwd := fposmod(s_b - s_e, perim)
	# Esquinas cruzadas en el sentido mas corto, ordenadas por distancia
	# recorrida desde la entrada.
	var crossed: Array = []
	if fwd <= perim - fwd:
		for k in 4:
			var d := fposmod(2.0 * r * k - s_e, perim)
			if d > 0.01 and d < fwd - 0.01:
				crossed.append([d, corners[k]])
	else:
		var back := perim - fwd
		for k in 4:
			var d := fposmod(s_e - 2.0 * r * k, perim)
			if d > 0.01 and d < back - 0.01:
				crossed.append([d, corners[k]])
	crossed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for c in crossed:
		route.append(c[1])
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
	_update_client_heads()
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


## Plato que sale de la TABLA del jugador: cuenta para el ayudante (que cocina
## uno por su cuenta cada PerkData.HELPER_EVERY) y para desbloquear perks.
func _on_player_dish_served(recipe_id: String) -> void:
	dishes_served += 1
	_on_dish_served(recipe_id)
	if helper_pivot != null and dishes_served % PerkData.HELPER_EVERY == 0:
		_helper_cook()


## Un plato desechado (2 vueltas sin cogerse) cuesta el 30% de su precio.
## Con "Reciclaje de platos" vuelve a la receta como uso instantaneo.
func _on_plate_discarded(recipe_id: String) -> void:
	if recycle_active:
		prep_board.recycle_recipe(recipe_id)
		return
	var price: int = RecipeData.get_recipe(recipe_id).get("price", 0)
	money_earned -= int(round(price * 0.3))


# -------------------------------------------------------------- resultados

## Marca el fin del nivel: desaloja a los que queden, para los platos de la
## cinta (la banda deja de avanzar sola al estar "ended") y bloquea la tabla.
func _end_level() -> void:
	if ended:
		return
	ended = true
	# Se acabo: ya no hay nada que abandonar, manda el panel de resultados.
	if exit_button != null:
		exit_button.visible = false
	for i in seats.size():
		var c = seat_clients[i]
		if c != null:
			c.force_leave()
	for p in get_tree().get_nodes_in_group("plates"):
		p.set_process(false)
	prep_board.process_mode = Node.PROCESS_MODE_DISABLED


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
		# Los potenciadores permanentes se ganan por combos, no por estrellas.
		for p in _check_perk_unlocks():
			new_recipes.append({ "perk": p })
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
	_setup_results_scroll()
	powerup_panel.visible = false
	# Con el cartel puesto, el HUD de partida sobra y ademas se colaba por
	# encima del pergamino.
	if heads_row != null:
		heads_row.visible = false
	if exit_button != null:
		exit_button.visible = false
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
	# La cola trae ids de receta (String) y potenciadores permanentes
	# recién conseguidos ({"perk": id}).
	var item: Variant = queue.pop_front()
	var is_perk: bool = item is Dictionary
	var id: String = str(item["perk"]) if is_perk else str(item)
	var data: Dictionary = PerkData.get_perk(id) if is_perk else RecipeData.get_recipe(id)
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
	title.text = "¡Nuevo potenciador!" if is_perk else "¡Nueva receta!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", dark)
	vb.add_child(title)

	var dish := TextureRect.new()
	dish.texture = load(str(data.get("icon", ""))) if is_perk \
			else RecipeData.get_dish_texture(id)
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

	if is_perk:
		# El potenciador explica qué hace y llega con 1 uso de regalo.
		var desc := Label.new()
		desc.text = str(data.get("desc", ""))
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 20)
		desc.add_theme_color_override("font_color", Color(0.42, 0.3, 0.18))
		vb.add_child(desc)
		var gift := Label.new()
		gift.text = "Llévate 1 uso de regalo. Compra más en el Inventario."
		gift.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gift.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gift.add_theme_font_size_override("font_size", 18)
		gift.add_theme_color_override("font_color", Color(0.2, 0.45, 0.12))
		vb.add_child(gift)
	else:
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
## Arrastrar por CUALQUIER punto del pergamino de resultados desplaza la lista.
## El ScrollContainer solo se desplaza con gestos que caen en su propio hueco y
## que ningun hijo se haya tragado; en la practica el jugador arrastra encima
## de una cabecera o de una fila y no pasaba nada. Aqui el panel entero
## escucha el arrastre y mueve el scroll a mano.
func _setup_results_scroll() -> void:
	var scroll: ScrollContainer = $HUD/ResultsPanel/VBox/Scroll
	results_panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenDrag:
			scroll.scroll_vertical -= int(event.relative.y))
	# Con MOUSE_FILTER_STOP el panel se come el arrastre antes de que llegue
	# a los botones; PASS deja que ambos funcionen.
	results_panel.mouse_filter = Control.MOUSE_FILTER_PASS


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

		# Cabecera del grupo: chapa de madera con la CARA del tipo de cliente.
		var head := _breakdown_header(type,
			"%s  x%d" % [TYPE_NAMES.get(type, type), reports.size()])

		var rows := VBoxContainer.new()
		rows.visible = false
		rows.add_theme_constant_override("separation", 6)
		for r in reports:
			rows.add_child(_breakdown_row(r))
		breakdown_box.add_child(head)
		breakdown_box.add_child(rows)
		var caret: Label = head.get_meta("caret")
		head.pressed.connect(func() -> void:
			rows.visible = not rows.visible
			caret.text = "▼" if rows.visible else "▶")


## Cabecera plegable de un tipo de cliente. Antes era un pergamino de 9-slice
## estirado a lo ancho del panel: con los rodillos fijos a 190 px por lado, el
## papel del centro quedaba aplastado y el conjunto se veia forzado. Ahora es
## una chapa lisa de madera con la CARA del cliente (el mismo icono del HUD),
## su nombre y un triangulo que dice si esta abierta.
##
## `mouse_filter = PASS` es importante: con STOP el boton se tragaba el
## arrastre y el ScrollContainer no podia desplazarse si el dedo caia sobre una
## cabecera, que es justo donde el jugador suele arrastrar.
func _breakdown_header(type: String, label_text: String) -> Button:
	var head := Button.new()
	head.custom_minimum_size = Vector2(0, 62)
	head.mouse_filter = Control.MOUSE_FILTER_PASS
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		head.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var plank := Panel.new()
	plank.set_anchors_preset(Control.PRESET_FULL_RECT)
	plank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plank.show_behind_parent = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.47, 0.33, 0.19)
	sb.border_color = Color(0.30, 0.20, 0.11)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	plank.add_theme_stylebox_override("panel", sb)
	head.add_child(plank)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12.0
	row.offset_right = -14.0
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(row)

	var face := TextureRect.new()
	face.texture = load("res://assets/ui/head_%s.png" % type)
	face.custom_minimum_size = Vector2(46, 46)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(face)

	var name_l := Label.new()
	name_l.text = label_text
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 24)
	name_l.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	name_l.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.04))
	name_l.add_theme_constant_override("outline_size", 5)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_l)

	var caret := Label.new()
	caret.text = "▶"
	caret.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caret.add_theme_font_size_override("font_size", 22)
	caret.add_theme_color_override("font_color", Color(1, 0.88, 0.6))
	caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caret)
	# Cuelga de la fila, no del boton: se guarda en un meta para que quien
	# conecta el plegado pueda darle la vuelta al triangulo.
	head.set_meta("caret", caret)
	return head


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


# ------------------------------------------------------------- salir del nivel

## Boton de salida, pegado al borde izquierdo bajo el reloj. Es una FLECHA de
## volver (boton_flecha_izq) en vez de un boton de texto: ocupa mucho menos,
## no compite con el HUD y se lee igual en cualquier idioma. Desaparece al
## terminar el nivel, donde manda el panel de resultados.
## Pide confirmacion: en la fase de preparacion se sale sin coste (se DEVUELVEN
## los usos de ingredientes ya descontados); en partida se avisa de la perdida.
func _setup_exit_button() -> void:
	exit_button = TextureButton.new()
	exit_button.texture_normal = load("res://assets/ui/boton_flecha_izq.png")
	exit_button.ignore_texture_size = true
	exit_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	exit_button.custom_minimum_size = Vector2(84, 68)
	exit_button.size = Vector2(84, 68)
	exit_button.position = Vector2(10, 108)
	exit_button.modulate = Color(1, 1, 1, 0.92)
	exit_button.pressed.connect(_on_exit_pressed)
	$HUD.add_child(exit_button)


# ------------------------------------------------- cabezas de los clientes

## Fila de cabezas justo ENCIMA de la cinta de la mesa de trabajo: de un
## vistazo se ve QUIEN hay en la barra sin recorrer el 3D con la mirada. Los
## iconos salen de los propios modelos 3D (tools/head_icons.gd).
func _setup_heads_row() -> void:
	heads_row = HBoxContainer.new()
	heads_row.alignment = BoxContainer.ALIGNMENT_CENTER
	heads_row.add_theme_constant_override("separation", 10)
	heads_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heads_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	# Sobre la tabla, y por ENCIMA de la instruccion escrita (que se movio ahi
	# desde debajo del tablero: abajo la tapaba el propio dedo en movil).
	heads_row.offset_top = -588.0 - 72.0 - HEAD_ICON - 6.0
	heads_row.offset_bottom = -588.0 - 72.0 - 6.0
	$HUD.add_child(heads_row)
	_update_client_heads()


## Una cabeza por TIPO presente, con "xN" cuando hay varios. Se llama al
## sentarse y al marcharse un cliente, asi que la fila sigue a la barra.
func _update_client_heads() -> void:
	if heads_row == null:
		return
	for c in heads_row.get_children():
		c.queue_free()
	# Cuenta por tipo respetando el orden E -> A -> G (de menor a mayor rango).
	var counts := { "E": 0, "A": 0, "G": 0 }
	for c in seat_clients:
		if c != null and is_instance_valid(c):
			counts[c.client_type] = int(counts.get(c.client_type, 0)) + 1
	for type in ["E", "A", "G"]:
		if counts[type] == 0:
			continue
		heads_row.add_child(_head_badge(type, counts[type]))


## Icono de cabeza con su contador. El "xN" va al lado, no encima, para que no
## tape la cara: a este tamaño la cara es justo lo que hay que reconocer.
func _head_badge(type: String, count: int) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = load("res://assets/ui/head_%s.png" % type)
	ic.custom_minimum_size = Vector2(HEAD_ICON, HEAD_ICON)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(ic)
	if count > 1:
		var l := Label.new()
		l.text = "x%d" % count
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 9)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
	return box


func _on_exit_pressed() -> void:
	if results_shown or ended:
		return
	var was_paused := get_tree().paused
	get_tree().paused = true

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.z_index = 150
	$HUD.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := Control.new()
	box.custom_minimum_size = Vector2(500, 360)
	center.add_child(box)
	box.add_child(prep_board.make_nine_patch("res://assets/ui/panel.png", 50))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 56.0
	vb.offset_top = 52.0
	vb.offset_right = -56.0
	vb.offset_bottom = -46.0
	vb.add_theme_constant_override("separation", 16)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(vb)

	var dark := Color(0.26, 0.16, 0.08)
	var title := Label.new()
	title.text = "¿Salir del nivel?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", dark)
	vb.add_child(title)

	var msg := Label.new()
	msg.text = "Aún estás preparando: no perderás nada." if prep_phase \
		else "¡La partida está en marcha!\nLos usos de ingredientes gastados se perderán."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 22)
	msg.add_theme_color_override("font_color", Color(0.42, 0.3, 0.18))
	vb.add_child(msg)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 20)
	vb.add_child(btns)
	var quit := Button.new()
	quit.text = "Salir"
	quit.custom_minimum_size = Vector2(170, 62)
	prep_board.skin_button(quit)
	quit.add_theme_font_size_override("font_size", 24)
	quit.pressed.connect(_confirm_exit)
	btns.add_child(quit)
	var stay := Button.new()
	stay.text = "Seguir"
	stay.custom_minimum_size = Vector2(170, 62)
	prep_board.skin_button(stay)
	stay.add_theme_font_size_override("font_size", 24)
	stay.pressed.connect(func() -> void:
		get_tree().paused = was_paused
		overlay.queue_free())
	btns.add_child(stay)


func _confirm_exit() -> void:
	# En la fase de preparacion la salida es gratis: se devuelven los usos de
	# ingredientes que se descontaron al empezar el nivel.
	if prep_phase and GameState.is_adventure():
		for ing in GameState.ingredients_for_selection(GameState.selected_recipes):
			GameState.add_ingredient_uses(ing, 1)
		GameState.save_game()
	get_tree().paused = false
	if GameState.is_adventure():
		get_tree().change_scene_to_file("res://scenes/level_select3d.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


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
