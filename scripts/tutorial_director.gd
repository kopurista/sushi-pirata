extends StoryDirector

const PrepBoard := preload("res://scripts/prep_board.gd")
## INTRO DEL CAOS: la primera escena del juego es una partida IMPOSIBLE.
##
## El jugador aparece en mitad de un turno ya empezado, con una sola receta
## (el maki de aguacate), la barra LLENA de clientes de todos los tipos y cero
## indicaciones (la mano de la tabla sigue ahí, pero nadie explica nada). Los
## piratas y capitanes rechazan los makis, la paciencia viene mermada y la
## clientela empieza a largarse decepcionada: no se puede ganar A PROPÓSITO.
## Cuando el desastre es evidente entran David y Gigi, le ofrecen unirse a la
## tripulación y se pasa a la ficha (nombre y género, `david_intro`) y de ahí
## al menú. La ENSEÑANZA de verdad va integrada en los niveles 1-10
## (level_director.gd): este guion solo vende el problema.
##
## Arriba a la derecha hay un botón "Saltar tutorial" que corta el teatro y
## va directo a la ficha. El tutorial se marca hecho igual (complete_tutorial
## corre al cerrar la ficha, en david_intro).

## La escena se rinde sola: con este número de abandonos (o pasados
## CHAOS_TIME segundos) entra David a rescatar al jugador.
const CHAOS_LEAVERS := 2
const CHAOS_TIME := 38.0
## Fracciones de paciencia con las que llega sentada la clientela del caos:
## escalonadas para que los abandonos goteen en vez de salir en tromba.
const CHAOS_PATIENCE := [0.22, 0.30, 0.38, 0.46, 0.56, 0.68, 0.80, 0.92]

var _skip_btn: Button = null
var _saliendo := false


func _run() -> void:
	var pb: Control = lv.prep_board
	# Solo existe el maki (selected_recipes ya llega así), todas encendidas.
	pb.allowed_recipes = []
	_build_skip_button()
	# La partida CORRE desde el primer fotograma: nada de reloj retenido.
	lv.clock_hold = false
	# La barra entera de golpe: dos de cada tipo, barajados. `total_clients`
	# se sube antes para que el contador del HUD no cante "8/1".
	var tipos: Array[String] = ["E", "E", "E", "A", "A", "G", "G", "E"]
	tipos.shuffle()
	lv.total_clients = tipos.size()
	for i in tipos.size():
		# El recién sentado se identifica comparando los asientos ANTES y
		# DESPUÉS: el spawner elige silla al azar, así que "el último del
		# array" era un cliente cualquiera y las paciencias mermadas caían
		# todas en el mismo (nadie llegaba a irse antes del rescate).
		var antes := {}
		for j in lv.seat_clients.size():
			if lv.seat_clients[j] != null:
				antes[j] = true
		lv.forced_types.append(tipos[i])
		if lv._try_spawn_client():
			for j in lv.seat_clients.size():
				if lv.seat_clients[j] != null and not antes.has(j):
					# Paciencia YA MERMADA y escalonada: los primeros abandonos
					# llegan en ~25 s sin que la marea sea instantánea.
					var c: Node3D = lv.seat_clients[j]
					c.patience = c.patience_max * float(CHAOS_PATIENCE[i])
					break
	# Se deja jugar (y fracasar) hasta que el desastre es innegable.
	var t0: float = lv.elapsed
	await _esperar(func() -> bool:
		return _saliendo or lv.clients_finished >= CHAOS_LEAVERS \
				or lv.elapsed - t0 > CHAOS_TIME)
	if _saliendo:
		return
	if _skip_btn != null:
		_skip_btn.visible = false

	# ---- El rescate ----
	await _say([
		{ "text": "¡RAAAK! ¡MOTÍN! ¡Clientes saltando por la borda!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "¡¿Pero qué naufragio es este?! ¿Una barra llena de bocas... y UNA receta?", "mood": "sorprendido" },
		{ "text": "Tranquilo, grumete. Esta partida no la gana nadie. Ni yo, y eso que soy yo.", "mood": "riendo" },
		{ "text": "Soy **David Jones**, capitán de este barco. Y este plumero con opiniones es **Gigi**.", "mood": "mira_loro" },
		{ "text": "¡GIGI EL TEMIBLE! ¡RAAK!", "who": "gigi", "mood": "loro" },
		{ "text": "Me falta un cocinero... y a ti te sobra hambre de aprender. Únete a mi **tripulación** y te enseñaré a ser el mejor cocinero de barco pirata de los siete mares.", "mood": "serio" },
		{ "text": "Cada puerto, una lección. Cada lección, más **oro**. Ese es el trato.", "mood": "hablando" },
		{ "text": "¡FIRMA O AL AGUA! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
		{ "text": "...que es su manera de decir \"bienvenido a bordo\". Primero lo primero: dime quién eres.", "mood": "loro_resignado" },
	])
	_ir_a_la_ficha()


## El grumete recién sentado (el de mayor instancia en seat_clients).
func _ultimo_cliente() -> Node3D:
	var mejor: Node3D = null
	for c in lv.seat_clients:
		if c is Node3D and is_instance_valid(c):
			mejor = c
	return mejor


## Botón "Saltar tutorial", arriba a la derecha (bajo el área segura). Corta
## el teatro entero y planta al jugador en la ficha de tripulación.
func _build_skip_button() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 96
	add_child(capa)
	_skip_btn = Button.new()
	_skip_btn.text = "Saltar tutorial"
	# DEBAJO de la fila del HUD (que ocupa hasta y~104): pegado al borde de
	# arriba pisaba el contador de clientes.
	_skip_btn.position = Vector2(720.0 - 244.0 - 18.0, 112.0 + GameState.safe_top())
	_skip_btn.size = Vector2(244, 64)
	_skip_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	PrepBoard.skin_small_button(_skip_btn)
	_skip_btn.add_theme_font_size_override("font_size", 24)
	_skip_btn.pressed.connect(func() -> void:
		if _saliendo:
			return
		_saliendo = true
		_ir_a_la_ficha())
	capa.add_child(_skip_btn)


## A la ficha de tripulación (nombre y género). El tutorial se dará por hecho
## allí, al aplicar el cartel (complete_tutorial).
func _ir_a_la_ficha() -> void:
	_saliendo = true
	get_tree().paused = false
	GameState.fade_to_scene("res://scenes/david_intro.tscn", 0.45, 0.5)


## Espera activa con el árbol en marcha.
func _esperar(cond: Callable) -> void:
	while not cond.call():
		await get_tree().process_frame
