extends Node2D
## Orquestador del nivel: cinta, spawner de clientes, HUD, propinas,
## potenciadores y puntuación.

const PLATE_SCENE := preload("res://scenes/plate.tscn")
const CLIENT_SCENE := preload("res://scenes/client.tscn")

const TOTAL_CLIENTS := 10
const TIME_LIMIT := 240.0
## Incrementos del bote de propinas: el primer potenciador cuesta 10$, y cada
## siguiente exige más (acumulado: 10, 22, 36, 52, 70, 90, 114...). Al agotar
## la lista, cada potenciador extra cuesta +60$.
const TIP_INCREMENTS := [10, 12, 14, 16, 18, 20, 24, 28, 32, 36, 40, 48, 60]

## Capas de dibujado (la cubierta va en -5, definida en la escena).
const Z_BELT := -1
const Z_CLIENT_BEHIND := -2
const Z_PLATE := 1
const Z_CLIENT_FRONT := 2

## Cinta isométrica: un rombo (proyección 2:1 de un cuadrado en el suelo) con
## los vértices arriba/derecha/abajo/izquierda. Cada lado mide ~253 px, así que
## el perímetro es ~1011 px. El cocinero va en el centro (diseño kaiten).
const BELT_POINTS := [Vector2(360, 292), Vector2(578, 420), Vector2(360, 548), Vector2(142, 420)]
## Centro del rombo: ahí van el cocinero y su mesa.
const BELT_CENTER := Vector2(360, 420)
## Entrada de los platos: vértice inferior (360, 548), el más cercano al chef.
## Tramos: arriba-dcha 0-253 · abajo-dcha 253-506 · abajo-izq 506-759 · arriba-izq 759-1011.
const SPAWN_PROGRESS := 506.0

## Asientos alrededor del rombo, dos por lado, desplazados hacia afuera.
## "behind": se sienta al otro lado de la cinta (se dibuja detrás de ella).
## "flip": mira hacia la derecha (los del lado izquierdo).
const SEATS := [
	{ "pos": Vector2(475, 271), "belt": Vector2(436, 337), "behind": true },
	{ "pos": Vector2(555, 319), "belt": Vector2(517, 384), "behind": true },
	{ "pos": Vector2(555, 521), "belt": Vector2(517, 456) },
	{ "pos": Vector2(475, 569), "belt": Vector2(436, 503) },
	{ "pos": Vector2(245, 569), "belt": Vector2(284, 503), "flip": true },
	{ "pos": Vector2(164, 521), "belt": Vector2(203, 456), "flip": true },
	{ "pos": Vector2(164, 319), "belt": Vector2(203, 384), "behind": true, "flip": true },
	{ "pos": Vector2(245, 271), "belt": Vector2(284, 337), "behind": true, "flip": true },
]

## Punto por el que entran y salen los clientes (parte superior del barco).
const ENTRY_POINT := Vector2(360, 108)
## Pasillos verticales para llegar a los asientos sin pisar la cinta.
const CORRIDOR_LEFT_X := 86.0
const CORRIDOR_RIGHT_X := 634.0

var elapsed := 0.0
var money_earned := 0
var clients_spawned := 0
var clients_finished := 0
var satisfactions: Array[float] = []
## Resumen de cada cliente que ha venido (para el desglose final).
var client_reports: Array = []
var all_fed := true
var seat_clients: Array = []
## Horario aleatorio de llegadas (el último siempre antes de T-45 s).
var arrival_queue: Array[float] = []
var ended := false
var results_shown := false

## Velocidad base de los platos (debe coincidir con plate.gd).
const PLATE_SPEED := 75.0
## Ancho de la banda de la cinta.
const BELT_WIDTH := 52.0
## Tramos rectos de la banda y su fase inicial (para que el dibujo no salte
## al doblar en las esquinas).
var belt_segments: Array[Line2D] = []
var belt_phases: Array[float] = []
## Placas giratorias de las esquinas (ruedan acorde al avance de la banda).
var belt_tile_px := 1.0
var belt_scroll := 0.0
var total_clients := TOTAL_CLIENTS
var time_limit := TIME_LIMIT
## Tipos forzados pendientes de spawn (potenciadores de clientes extra).
var forced_types: Array[String] = []

## Fase de preparación previa: 10 s sin clientes para adelantar platos.
var prep_phase := true
var prep_time_left := 10.0
## "Tiempo de preparación extra": todo se congela mientras frozen sea true.
var frozen := false
var freeze_timer := 0.0

# --- Estado de propinas y potenciadores ---
var tips_total := 0
var powerups_claimed := 0
var pending_powerups := 0
var aroma_active := false
## "Reciclaje de platos": los platos desechados vuelven a la receta.
var recycle_active := false
var tip_chance_bonus := 0.0
var tip_amount_mult := 1.0
var belt_mult := 1.0
var patience_mult := 1.0
var next_client_pay_mult := 1.0
var belt_timer := 0.0
var tip_chance_timer := 0.0
var tip_amount_timer := 0.0

@onready var belt: Path2D = $Belt
@onready var chef: Sprite2D = $Chef
@onready var chef_prop: Sprite2D = $ChefProp
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
## Fila de estrellas-imagen del panel de resultados.
var stars_row: HBoxContainer = null
@onready var score_label: Label = $HUD/ResultsPanel/VBox/ScoreLabel
@onready var earn_label: Label = $HUD/ResultsPanel/VBox/EarnLabel
@onready var breakdown_box: VBoxContainer = $HUD/ResultsPanel/VBox/Scroll/Breakdown
@onready var retry_button: Button = $HUD/ResultsPanel/VBox/BtnBox/RetryButton
@onready var menu_button: Button = $HUD/ResultsPanel/VBox/BtnBox/MenuButton


func _ready() -> void:
	_build_belt()
	seat_clients.resize(SEATS.size())
	prep_board.dish_served.connect(_on_dish_served)
	prep_board.craft_event.connect(_on_craft_event)
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	results_panel.visible = false
	powerup_panel.visible = false
	_skin_panels()
	GameState.reset_run()
	# Llegadas escalonadas con azar: cada cliente tiene una franja centrada y
	# aplica jitter. Así el primero llega pronto (~6 s) y hay ritmo constante,
	# pero el orden y los momentos exactos varían. El último nunca con <45 s.
	var last := TIME_LIMIT - 45.0
	var step := (last - 6.0) / float(TOTAL_CLIENTS - 1)
	for i in TOTAL_CLIENTS:
		var center := 6.0 + i * step
		arrival_queue.append(clampf(center + randf_range(-8.0, 8.0), 2.0, last))
	arrival_queue.sort()
	_update_hud()


## Viste los paneles emergentes con el pergamino enmarcado en cuerda.
## El pergamino es claro: todos sus textos van en marrón oscuro.
func _skin_panels() -> void:
	var path := "res://assets/ui/panel.png"
	if ResourceLoader.exists(path):
		for p in [powerup_panel, results_panel]:
			p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			# Panel plano sin rodillos: solo la cuerda fina del borde.
			p.add_child(prep_board.make_nine_patch(path, 38))
	var dark := Color(0.26, 0.16, 0.08)
	for l in [$HUD/ResultsPanel/VBox/TitleLabel, score_label, earn_label,
			$HUD/PowerupPanel/VBox/Title]:
		l.add_theme_color_override("font_color", dark)
	stars_label.add_theme_color_override("font_color", Color(0.78, 0.55, 0.08))
	# Las estrellas del resultado son imágenes propias, no texto.
	stars_label.visible = false
	stars_row = HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 12)
	var vbox := $HUD/ResultsPanel/VBox
	vbox.add_child(stars_row)
	vbox.move_child(stars_row, stars_label.get_index() + 1)
	for b in [retry_button, menu_button]:
		prep_board.skin_button(b)


## Reacciones del chef del centro a cada gesto del jugador en la tabla.
func _on_craft_event(kind: String, stage_id: String) -> void:
	# El ingrediente/etapa actual se ve también en la mesa del chef.
	var tex := RecipeData.get_stage_texture(stage_id)
	chef_prop.texture = tex
	chef_prop.visible = tex != null
	if tex != null:
		chef_prop.scale = Vector2(56.0 / tex.get_width(), 56.0 / tex.get_width())

	var tw := create_tween()
	match kind:
		"tap", "stage":
			# Picar: el chef se agacha un instante.
			tw.tween_property(chef, "scale", Vector2(0.115, 0.098), 0.07)
			tw.tween_property(chef, "scale", Vector2(0.108, 0.108), 0.09)
		"cut":
			# Cortar: golpe de cuchillo (giro seco).
			tw.tween_property(chef, "rotation_degrees", -9.0, 0.06)
			tw.tween_property(chef, "rotation_degrees", 0.0, 0.12)
		"swipe":
			# Enrollar: balanceo lateral.
			tw.tween_property(chef, "rotation_degrees", 7.0, 0.1)
			tw.tween_property(chef, "rotation_degrees", -7.0, 0.14)
			tw.tween_property(chef, "rotation_degrees", 0.0, 0.1)
		"hold":
			# Remover la olla: vaivén suave.
			tw.tween_property(chef, "rotation_degrees", 4.0, 0.3)
			tw.tween_property(chef, "rotation_degrees", -4.0, 0.3)
			tw.tween_property(chef, "rotation_degrees", 0.0, 0.2)
		"drag":
			tw.tween_property(chef, "scale", Vector2(0.113, 0.103), 0.1)
			tw.tween_property(chef, "scale", Vector2(0.108, 0.108), 0.12)
		"done":
			# Plato terminado: pequeño salto de celebración.
			tw.tween_property(chef, "position:y", chef.position.y - 10.0, 0.12)
			tw.tween_property(chef, "position:y", chef.position.y, 0.15)
		_:
			tw.kill()


func _build_belt() -> void:
	var curve := Curve2D.new()
	for p in BELT_POINTS:
		curve.add_point(p)
	curve.add_point(BELT_POINTS[0])
	belt.curve = curve

	# La barra isométrica se dibuja por capas, de abajo a arriba: sombra en el
	# suelo, canto de madera (da la profundidad del bloque), tapa de madera,
	# raíl de acero y, encima, la banda de la cinta en movimiento.
	# closed=true cierra el anillo (con el punto duplicado quedaba una muesca).
	var ring := PackedVector2Array(BELT_POINTS)

	_add_belt_layer(ring, 104.0, Color(0, 0, 0, 0.30), Vector2(0, 26))
	_add_belt_layer(ring, 96.0, Color(0.24, 0.15, 0.08), Vector2(0, 18))
	_add_belt_layer(ring, 96.0, Color(0.34, 0.22, 0.12), Vector2(0, 10))
	_add_belt_layer(ring, 96.0, Color(0.55, 0.38, 0.21), Vector2.ZERO)
	_add_belt_layer(ring, 62.0, Color(0.70, 0.73, 0.77), Vector2.ZERO)

	# La banda se dibuja como CUATRO TRAMOS RECTOS independientes en vez de un
	# anillo cerrado: una Line2D con juntas genera geometría extra en los
	# vértices cuyas UV se desplazan con el scroll, y eso hacía parpadear las
	# esquinas. Sin juntas no hay geometría problemática.
	var belt_tex: Texture2D = load("res://assets/props/cinta_trad_banda.png")
	var shader: Shader = load("res://shaders/belt_scroll.gdshader")
	belt_tile_px = belt_tex.get_width() * (BELT_WIDTH / belt_tex.get_height())

	var travelled := 0.0
	for i in BELT_POINTS.size():
		var a: Vector2 = BELT_POINTS[i]
		var b: Vector2 = BELT_POINTS[(i + 1) % BELT_POINTS.size()]
		var seg := Line2D.new()
		seg.points = PackedVector2Array([a, b])
		seg.width = BELT_WIDTH
		seg.texture = belt_tex
		seg.texture_mode = Line2D.LINE_TEXTURE_TILE
		# Sin esto la textura no se repite: se estira y sale una banda plana.
		seg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		seg.z_index = Z_BELT
		var mat := ShaderMaterial.new()
		mat.shader = shader
		seg.material = mat
		# Fase propia de cada tramo para que el dibujo sea continuo al doblar.
		belt_phases.append(travelled / belt_tile_px)
		travelled += a.distance_to(b)
		add_child(seg)
		move_child(seg, belt.get_index())
		belt_segments.append(seg)

	# Placa de esquina ISOMÉTRICA: un rombo de metal (proporción 2:1, como el
	# resto de la mesa) tapa el codo donde se juntan dos tramos rectos. Es
	# estática — el disco giratorio de antes se veía circular y rompía el estilo.
	var diamond := PackedVector2Array([
		Vector2(0, -BELT_WIDTH * 0.55),
		Vector2(BELT_WIDTH * 1.05, 0),
		Vector2(0, BELT_WIDTH * 0.55),
		Vector2(-BELT_WIDTH * 1.05, 0),
	])
	for p in BELT_POINTS:
		# Canto oscuro del codo (da volumen) + tapa metálica encima.
		var edge := Polygon2D.new()
		edge.polygon = diamond
		edge.color = Color(0.34, 0.22, 0.12)
		edge.position = p + Vector2(0, 6)
		edge.z_index = Z_BELT
		add_child(edge)
		move_child(edge, belt.get_index())

		var plate := Polygon2D.new()
		plate.polygon = diamond
		plate.color = Color(0.62, 0.65, 0.70)
		plate.position = p
		plate.z_index = Z_BELT
		add_child(plate)
		move_child(plate, belt.get_index())


## Una capa del bloque isométrico de la cinta.
func _add_belt_layer(ring: PackedVector2Array, width: float, color: Color,
		offset: Vector2) -> void:
	var l := Line2D.new()
	l.points = ring
	l.closed = true
	l.width = width
	l.default_color = color
	l.position = offset
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.round_precision = 12
	l.antialiased = true
	l.z_index = Z_BELT
	add_child(l)
	move_child(l, belt.get_index())


func _process(delta: float) -> void:
	if ended:
		# El cartel de fin espera a que el último cliente haya desaparecido.
		if not results_shown and get_tree().get_nodes_in_group("clients").is_empty():
			_finalize_results()
		return

	# La banda de la cinta se desplaza a la velocidad de los platos
	# (también durante la fase de preparación, pero no congelada).
	if not frozen:
		belt_scroll += PLATE_SPEED * belt_mult * delta / belt_tile_px
		# fmod evita que el desplazamiento crezca sin límite y pierda precisión.
		belt_scroll = fmod(belt_scroll, 1.0)
		for i in belt_segments.size():
			belt_segments[i].material.set_shader_parameter(
					"scroll_offset", belt_scroll - belt_phases[i])

	# Fase de preparación: el reloj no corre y no vienen clientes.
	if prep_phase:
		prep_time_left -= delta
		phase_label.visible = true
		phase_label.text = "Preparación: %d s" % ceili(maxf(prep_time_left, 0.0))
		if prep_time_left <= 0.0:
			prep_phase = false
			phase_label.visible = false
		_update_hud()
		return

	# "Tiempo de preparación extra": todo congelado salvo la tabla.
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


func _try_spawn_client() -> bool:
	var free_seats: Array = []
	for i in SEATS.size():
		if seat_clients[i] == null:
			free_seats.append(i)
	if free_seats.is_empty():
		return false
	var idx: int = free_seats.pick_random()
	var c = CLIENT_SCENE.instantiate()
	if not forced_types.is_empty():
		c.client_type = forced_types.pop_front()
	else:
		c.client_type = _pick_client_type()
	c.patience_scale = patience_mult
	c.pay_mult = next_client_pay_mult
	next_client_pay_mult = 1.0
	# Entra andando desde la parte superior del barco hasta su asiento.
	c.position = ENTRY_POINT
	c.route = _route_for_seat(idx)
	# Profundidad: la fila de arriba se sienta al otro lado de la cinta, así que
	# va detrás de ella; los laterales van delante de los platos.
	c.z_index = Z_CLIENT_BEHIND if SEATS[idx].get("behind", false) else Z_CLIENT_FRONT
	# Los de la izquierda miran a la derecha (hacia la cinta) y viceversa.
	c.face_flip = SEATS[idx].get("flip", false)
	add_child(c)
	c.set_belt_point(SEATS[idx].belt)
	c.finished.connect(_on_client_finished.bind(idx))
	seat_clients[idx] = c
	clients_spawned += 1
	return true


## Ruta de entrada hasta el asiento: baja por el pasillo lateral que le
## corresponde y entra en horizontal, sin cruzar nunca el rombo de la cinta.
func _route_for_seat(idx: int) -> Array:
	var seat: Vector2 = SEATS[idx].pos
	var corridor := CORRIDOR_LEFT_X if seat.x < BELT_CENTER.x else CORRIDOR_RIGHT_X
	return [
		Vector2(corridor, ENTRY_POINT.y),
		Vector2(corridor, seat.y),
		seat,
	]


## Mezcla de tipos para esta prueba: 60% estudiante, 30% adulto, 10% gourmet.
func _pick_client_type() -> String:
	var r := randf()
	if r < 0.6:
		return "E"
	elif r < 0.9:
		return "A"
	return "G"


func _on_client_finished(report: Dictionary, seat_idx: int) -> void:
	seat_clients[seat_idx] = null
	money_earned += report.money + report.tip
	satisfactions.append(report.satisfaction)
	client_reports.append(report)
	if report.satiety_eaten <= 0:
		all_fed = false
	if report.tip > 0:
		_add_tip(report.tip)
	clients_finished += 1
	_update_hud()
	if clients_finished >= total_clients:
		_end_level()


## Umbral acumulado de propinas para el potenciador n+1.
func _tip_threshold(claimed: int) -> int:
	var total := 0
	for i in claimed + 1:
		total += TIP_INCREMENTS[i] if i < TIP_INCREMENTS.size() else 60
	return total


## Acumula la propina total; cada umbral alcanzado da una elección de
## potenciador, y el siguiente umbral es mayor (progresión exponencial).
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


func _on_dish_served(recipe_id: String) -> void:
	var p = PLATE_SCENE.instantiate()
	p.recipe_id = recipe_id
	p.z_index = Z_PLATE
	belt.add_child(p)
	p.progress = SPAWN_PROGRESS
	p.discarded.connect(_on_plate_discarded)


## Un plato desechado (2 vueltas sin cogerse) cuesta el 30% de su precio.
## Afecta al dinero generado, no a la puntuación.
## Con "Reciclaje de platos" el plato no se pierde: vuelve a la receta como
## uso instantáneo (se acumula con la maestría de makis/futomakis) y sin coste.
func _on_plate_discarded(recipe_id: String) -> void:
	if recycle_active:
		prep_board.recycle_recipe(recipe_id)
		return
	var price: int = RecipeData.get_recipe(recipe_id).get("price", 0)
	money_earned -= int(round(price * 0.3))


## Marca el fin del nivel y desaloja a los que queden; los resultados se
## calculan y muestran cuando el último cliente ha desaparecido (_process).
func _end_level() -> void:
	if ended:
		return
	ended = true
	all_served_at_end = clients_finished >= total_clients
	for i in SEATS.size():
		var c = seat_clients[i]
		if c != null:
			c.force_leave()


var all_served_at_end := false


func _finalize_results() -> void:
	results_shown = true
	var served := 0
	for r in client_reports:
		if r.satiety_eaten > 0:
			served += 1

	var score := 0.0
	var stars := 0
	var total_money := 0
	# Sin ningún cliente atendido: 0 puntos, 0 estrellas y nada de dinero.
	if served > 0:
		while satisfactions.size() < total_clients:
			satisfactions.append(1.0)
		var avg := 0.0
		for s in satisfactions:
			avg += s
		avg /= satisfactions.size()

		# Bonus de tiempo: requiere al menos 1 atendido, todos los que
		# vinieron comieron algo, y todos atendidos antes del límite.
		var bonus := 0.0
		if all_served_at_end and all_fed:
			var consumed := elapsed / time_limit
			if consumed <= 0.5:
				bonus = 0.20
			elif consumed <= 0.75:
				bonus = 0.15
			elif consumed <= 0.9:
				bonus = 0.10
			else:
				bonus = 0.05

		score = 0.8 * (avg / 5.0) + bonus
		stars = 1
		if score >= 0.85:
			stars = 3
		elif score >= 0.5:
			stars = 2
		var star_money: int = [0, 10, 25, 50][stars]
		total_money = money_earned + star_money

	GameState.money += total_money
	GameState.last_score = score
	GameState.last_stars = stars
	GameState.last_money_earned = total_money
	_show_results(score, stars, total_money)


const TYPE_NAMES := { "E": "Grumete", "A": "Pirata", "G": "Capitán" }


func _show_results(score: float, stars: int, total_money: int) -> void:
	for c in stars_row.get_children():
		c.queue_free()
	stars_row.add_child(prep_board.make_star_row(stars, 3, 58))
	# Con las estrellas basta: el porcentaje no se muestra.
	score_label.visible = false
	earn_label.text = "Dinero ganado: $%d" % total_money
	_build_breakdown()
	powerup_panel.visible = false
	results_panel.visible = true
	get_tree().paused = true


## Desglose agrupado por tipo de cliente. Cada cabecera (Grumete, Pirata,
## Capitán) se pliega/despliega; cada fila muestra iconos de los platos
## comidos, el dinero pagado (moneda) y la propina (cofre).
func _build_breakdown() -> void:
	for child in breakdown_box.get_children():
		child.queue_free()

	var served := 0
	for r in client_reports:
		if r.satiety_eaten > 0:
			served += 1
	var header := Label.new()
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

		# Cabecera con forma de pergamino: cerrado plegado, abierto desplegado.
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
		# 9-patch: los extremos enrollados conservan su forma y solo se
		# estira el papel central (sin pixelado por aplastamiento).
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


## Fila de un cliente: estrellas + iconos de platos + dinero + propina.
func _breakdown_row(r: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	# Estado de ánimo final en bocadillo (triste/neutral/feliz).
	var mood := "bubble_feliz"
	if r.satisfaction < 2.5:
		mood = "bubble_triste"
	elif r.satisfaction < 4.5:
		mood = "bubble_neutral"
	var mood_icon := TextureRect.new()
	mood_icon.texture = load("res://assets/ui/%s.png" % mood)
	mood_icon.custom_minimum_size = Vector2(52, 52)
	mood_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mood_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(mood_icon)

	var eaten: Array = r.eaten
	if eaten.is_empty():
		var none := Label.new()
		none.text = "—"
		none.add_theme_font_size_override("font_size", 22)
		none.add_theme_color_override("font_color", Color(0.45, 0.35, 0.25))
		row.add_child(none)
	else:
		for id in eaten:
			var ic := TextureRect.new()
			ic.texture = RecipeData.get_dish_texture(id)
			ic.custom_minimum_size = Vector2(64, 64)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(ic)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	row.add_child(_icon_amount("res://assets/ui/moneda.png", "$%d" % r.money))
	if r.tip > 0:
		row.add_child(_icon_amount("res://assets/ui/bolsa.png", "+$%d" % r.tip))
	return row


func _icon_amount(icon_path: String, text: String) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var ic := TextureRect.new()
	if ResourceLoader.exists(icon_path):
		ic.texture = load(icon_path)
	ic.custom_minimum_size = Vector2(34, 34)
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
	get_tree().change_scene_to_file("res://scenes/prep_screen.tscn")


func _update_hud() -> void:
	var remaining := maxf(time_limit - elapsed, 0.0)
	time_label.text = "%d:%02d" % [int(remaining) / 60, int(remaining) % 60]
	money_label.text = "$%d" % money_earned
	jar_label.text = "$%d / $%d" % [tips_total, _tip_threshold(powerups_claimed)]
	clients_label.text = "%d/%d" % [clients_finished, total_clients]
