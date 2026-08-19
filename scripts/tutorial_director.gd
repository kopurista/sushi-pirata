extends StoryDirector

const PrepBoard := preload("res://scripts/prep_board.gd")
const CLIENT3D := preload("res://scripts/client3d.gd")
## INTRO DEL CAOS: la primera escena del juego es una partida IMPOSIBLE.
##
## El jugador aparece en mitad de un turno ya empezado, con una sola receta
## (el maki de aguacate), la barra LLENA de clientes de todos los tipos y cero
## indicaciones (la mano de la tabla sigue ahí, pero nadie explica nada). Los
## piratas y capitanes rechazan los makis, la paciencia viene mermada y la
## clientela empieza a largarse decepcionada: no se puede ganar A PROPÓSITO.
## Cuando el desastre es evidente entran David y Gigi, le ofrecen unirse a la
## tripulación y se vuelve al MENÚ, donde se rellena la ficha (nombre y
## género) sobre el mismo mar (`main_menu._show_ficha`). La ENSEÑANZA de verdad va integrada en los niveles 1-10
## (level_director.gd): este guion solo vende el problema.
##
## Arriba a la derecha hay un botón "Saltar tutorial" que corta el teatro y
## va directo a la ficha. El tutorial se marca hecho igual (complete_tutorial
## corre al cerrar la ficha, ya en el menú).

## SEGUNDO EN EL QUE SE LEVANTA CADA CLIENTE. La escena entera dura 15 s y se
## van de dos en dos al final, para que el desastre se acelere y David entre
## con la barra ya vacía. No se programa un temporizador de salida — a cada uno
## se le da el DRENAJE justo (ver `_drenaje_para`) para que su barra llegue a
## cero en su segundo, así que lo que se ve bajar en pantalla es la verdad y no
## una animación por encima.
const CHAOS_EXITS := [3.0, 5.0, 8.0, 10.0, 12.0, 12.0, 14.0, 14.0]
## Red de seguridad por si alguno se queda enganchado: pasado esto, David
## entra igual.
const CHAOS_TIME := 22.0

## --- EL MARCADOR ES DE MENTIRA ---
## La primera pantalla del juego tiene que dar la impresión de un turno ENORME
## yéndose al garete, así que el HUD enseña cifras de escaparate: un objetivo
## imposible, una clientela de 120 y 15 segundos de reloj. Nada de esto afecta
## a la partida — el nivel en modo tutorial no termina ni por reloj ni por
## clientes, lo cierra este guion.
const TEATRO_ORO := 180
const TEATRO_META := 3000
const TEATRO_CLIENTES := 120
const TEATRO_RELOJ := 15.0
## Lo que se acorta el BOCADO aquí: si el jugador acierta a servir algo, el
## cliente lo engulle y se va igual (su paciencia no se detiene al comer, ver
## `client3d.always_drain`).
const TEATRO_BOCADO := 0.14

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
					var c: Node3D = lv.seat_clients[j]
					# YA SENTADOS, sin el paseo: la escena empieza con el
					# desastre montado, no montándose.
					c.sit_now()
					# Barra llena pero cayendo a plomo, cada uno con el ritmo
					# justo para levantarse en su segundo. Y aquí la paciencia
					# NO se detiene al comer: servirle algo no lo salva, solo
					# hace que se vaya masticando.
					c.drain_scale = _drenaje_para(c.patience_max,
						float(CHAOS_EXITS[i]))
					c.always_drain = true
					c.slow_eat = TEATRO_BOCADO
					break
	_montar_marcador()
	# El desastre corre hasta que se ha levantado TODO EL MUNDO (o hasta la red
	# de seguridad). David entra con la barra vacía, que es la estampa.
	var t0: float = lv.elapsed
	await _esperar(func() -> bool:
		return _saliendo or lv.clients_finished >= CHAOS_EXITS.size() \
				or lv.elapsed - t0 > CHAOS_TIME)
	if _saliendo:
		return
	if _skip_btn != null:
		_skip_btn.visible = false

	# ---- El rescate ----
	# `congelar` a FALSE (el último argumento de `_say`): el árbol sigue
	# corriendo mientras David habla, así que los que quedan terminan de cruzar
	# la cubierta y se van por la borda. Con el juego en pausa se quedaban
	# clavados a medio paso, que es lo contrario de lo que cuenta la escena.
	await _say([
		{ "text": "¡RAAAK! ¡MOTÍN! ¡Clientes saltando por la borda!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "¡¿Pero qué clase de naufragio es este?! ¡No hay ni un solo pirata que quiera comer aquí!", "mood": "sorprendido" },
		{ "text": "Me parece que hay un grumete por aquí que necesita unas **clases de cocina**.", "mood": "riendo" },
		{ "text": "Soy **David Jones**, capitán del barco **\"La Calva Blanca\"**. Y este de mi hombro que se quejará en cualquier momento es **Gigi**.", "mood": "mira_loro" },
		{ "text": "¡GIGI EL TEMIBLE! ¡RAAK!", "who": "gigi", "mood": "loro" },
		{ "text": "Me falta un cocinero... y a ti te falta alguien que te enseñe. Únete a mi **tripulación** y conseguiré que te conviertas en el mejor cocinero pirata de los siete mares.", "mood": "serio" },
		{ "text": "¡FIRMA O AL AGUA! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
		{ "text": "...que es su manera de decir \"bienvenido a bordo\". Vamos a mi barco, que tenemos que hacerte un **cartel de recompensa**.", "mood": "loro_resignado" },
	], -1.0, false)
	_ir_a_la_ficha()


## Drenaje que hace que una barra LLENA llegue a cero en `t` segundos. La
## cuenta sale del propio `_process` del cliente: mientras no ha comido nada,
## la paciencia baja `FIRST_PLATE_DRAIN` × `drain_scale` por segundo, así que
## con la barra al máximo el tiempo de vida es `patience_max / esa tasa`.
func _drenaje_para(pmax: float, t: float) -> float:
	return pmax / maxf(t * CLIENT3D.FIRST_PLATE_DRAIN, 0.001)


## EL MARCADOR DE ESCAPARATE. Pone el HUD con las cifras de mentira (ver las
## constantes TEATRO_*): un turno enorme, 120 bocas y 15 segundos de reloj.
## No hay nada falso en el mecanismo — se rellenan los MISMOS campos que usa un
## nivel de verdad, solo que con valores puestos a mano:
##  · `money_earned` y `star_money` dan el "180 / 3000" del oro. El objetivo es
##    inalcanzable, así que la partida no puede cerrarse por dinero.
##    **EL ORO DE SALIDA ES LO ÚNICO PUESTO A MANO: a partir de ahí la cuenta
##    es REAL.** Cada cliente que se larga sin comer cobra su `LEAVE_PENALTY`
##    escalado y cada plato que da la vuelta entera se descuenta, así que los
##    180 se desmoronan delante del jugador — que es exactamente lo que la
##    escena tiene que hacerle sentir. (Estuvo CLAVADO por fotograma para que
##    la cifra no se moviera; se quitó a propósito.)
##  · `clients_seated`/`total_clients` dan el "120/120". El nivel en modo
##    tutorial no termina por clientes (lo cierra este guion), así que subir el
##    contador no dispara nada.
##  · `timed` + `time_limit` encienden el reloj y lo dejan corriendo de 15 a 0.
##    En tutorial `_end_level` sale sin hacer nada, así que llegar a cero no
##    cierra la partida: solo remata la sensación de desastre.
func _montar_marcador() -> void:
	lv.money_earned = TEATRO_ORO
	lv.star_money = [TEATRO_META]
	lv.clients_seated = TEATRO_CLIENTES
	lv.total_clients = TEATRO_CLIENTES
	lv.timed = true
	lv.time_limit = TEATRO_RELOJ
	lv.elapsed = 0.0
	lv._apply_hud_layout()
	lv._update_hud()


## Botón "Saltar tutorial", arriba a la IZQUIERDA. Corta el teatro entero y
## planta al jugador en la ficha de tripulación.
func _build_skip_button() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 96
	add_child(capa)
	_skip_btn = Button.new()
	_skip_btn.text = "Saltar tutorial"
	# DEBAJO de la fila del HUD (que ocupa hasta y~104): pegado al borde de
	# arriba pisaba el marcador. El rótulo va a cuerpo 26 en un tablón de 214,
	# que es lo justo para que llene el botón sin montarse en el marco dorado.
	_skip_btn.position = Vector2(18.0, 112.0 + GameState.safe_top())
	_skip_btn.size = Vector2(214, 56)
	_skip_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	PrepBoard.skin_small_button(_skip_btn)
	_skip_btn.add_theme_font_size_override("font_size", 26)
	_skip_btn.pressed.connect(func() -> void:
		if _saliendo:
			return
		_confirmar_saltar(capa))
	capa.add_child(_skip_btn)


## Saltarse el tutorial es una decisión, no un resbalón: se pregunta antes. El
## cartel es el pergamino de siempre con su cinta y los dos botones de acción
## del juego (visto verde / aspa roja), y PAUSA el árbol mientras está puesto.
func _confirmar_saltar(capa: CanvasLayer) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.z_index = 150
	capa.add_child(overlay)
	var antes := get_tree().paused
	get_tree().paused = true

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := Control.new()
	box.custom_minimum_size = Vector2(500, 300)
	center.add_child(box)
	box.add_child(PrepBoard.make_nine_patch(
		PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))
	PrepBoard.add_panel_banner(box, "¿Saltar tutorial?", 28)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 54.0
	vb.offset_top = 84.0
	vb.offset_right = -54.0
	vb.offset_bottom = -44.0
	vb.add_theme_constant_override("separation", 22)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(vb)

	var msg := Label.new()
	msg.text = "David te enseña a cocinar jugando. Si lo saltas, empezarás la aventura por tu cuenta."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 22)
	msg.add_theme_color_override("font_color", Color(0.42, 0.3, 0.18))
	vb.add_child(msg)

	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 30)
	vb.add_child(fila)
	var si := Button.new()
	si.text = "Saltar"
	si.custom_minimum_size = Vector2(190, 76)
	PrepBoard.skin_action_button(si, true)
	si.add_theme_font_size_override("font_size", 26)
	fila.add_child(si)
	var no := Button.new()
	no.text = "Seguir"
	no.custom_minimum_size = Vector2(190, 76)
	PrepBoard.skin_action_button(no, false)
	no.add_theme_font_size_override("font_size", 26)
	fila.add_child(no)

	no.pressed.connect(func() -> void:
		get_tree().paused = antes
		overlay.queue_free())
	si.pressed.connect(func() -> void:
		if _saliendo:
			return
		_saliendo = true
		overlay.queue_free()
		_ir_a_la_ficha())


## A la ficha de tripulación (nombre y género). Ya NO es una escena aparte: se
## rellena SOBRE EL MENÚ, con el barco navegando de fondo (`main_menu._show_ficha`),
## que es donde David sigue hablando después. El tutorial se da por hecho allí,
## al aplicar el cartel (complete_tutorial).
func _ir_a_la_ficha() -> void:
	_saliendo = true
	get_tree().paused = false
	GameState.mode = ""
	GameState.current_port = ""
	GameState.transition = "ficha"
	GameState.fade_to_scene("res://scenes/main_menu.tscn", 0.45, 0.5)


## Espera activa con el árbol en marcha.
func _esperar(cond: Callable) -> void:
	while not cond.call():
		await get_tree().process_frame
