extends StoryDirector
## Guion de David Jones DENTRO de los niveles de la campaña. La campaña ES el
## tutorial: cada nivel del 1 al 10 presenta una mecánica jugando, y David solo
## se asoma en los momentos justos (al hablar pausa el juego entero, como
## siempre). La regla de oro: poco texto, mucho juego — una idea por tanda.
##
## Qué nivel se narra lo dice el campo `director` del puerto en CampaignData.
## Un puerto sin ese campo no monta director. Los guiones suenan SOLO la
## primera vez (GameState.narrated_ports)... con una excepción: el nivel del
## JEFE monta director SIEMPRE (es quien trae al Kappa), y es el guion quien
## se calla los diálogos en las repeticiones (`_mudo`).
##
## OJO CON LAS LAMBDAS DE `_esperar`: capturan POR VALOR, así que asignar
## dentro una variable de FUERA no sale del closure. La condición MIRA; el dato
## se pide FUERA.

## Fracción del dinero objetivo a partir de la cual el cliente TARDÍO del
## nivel (el pirata del 7, Pablo en el 8) se adelanta para que dé tiempo a
## estrenar su lección.
const TARDIO_PROGRESO := 0.6
## Lo mismo para Pablo, que llega en abordaje (sin cupo): algo más tarde.
const AVISO_PABLO := 0.8

## --- JEFE (nivel 10) ---
## Platos que tiene que comer el Kappa para rendirse.
const BOSS_PLATES := 10
## Clientes ALIMENTADOS (≥1 plato) que piden la entrada del jefe...
const KAPPA_FED := 3
## ...o el reloj de la primera tanda que la fuerza aunque falten.
const KAPPA_TIME := 60.0

var guion := ""
## Clientes ya revisados en client_reports (para pillar al que se va de vacío).
var _vistos := 0
## Guion en modo MUDO (repeticiones del nivel del jefe): coreografía sí,
## diálogos no. Se captura al ARRANCAR, porque level3d marca el puerto como
## narrado en cuanto acaba la fase de preparación de esta misma partida.
var _mudo := false
## Mientras una lección congela la barra: los clientes que lleguen entran
## también con la paciencia retenida.
var _paciencia_quieta := false


func _run() -> void:
	guion = str(CampaignData.get_port(GameState.current_port).get("director", ""))
	_mudo = GameState.port_narrated(GameState.current_port)
	# LOS CONTADORES DE MAESTRÍA se explican en la primera jornada que se juegue
	# con una de esas habilidades puesta, sea el escenario que sea: se compran
	# cuando el jugador quiere, así que no se pueden colgar de ningún puerto.
	# Va lo PRIMERO, antes del guion del escenario, porque señala una chapa del
	# HUD que ya está en pantalla desde el primer fotograma.
	await _explicar_contadores()
	# EL HÁNDICAP DEL TIPO, la primera vez que se pisa un puerto o un abordaje:
	# se contó en el mapa al presentar los tipos, pero aquí está el contador (o
	# el reloj) delante y es donde se entiende de verdad.
	await _explicar_handicap()
	# EL CLIENTE DEL TESORO canta su encargo en cuanto se sienta, lo lleve el
	# escenario que lo lleve. Va SIN `await`: es un vigía que se queda mirando,
	# no un paso del guion.
	_vigilar_tesoro()
	# Un escenario sin guion propio monta el director SOLO para lo de arriba.
	# HAY QUE SOLTAR EL RELOJ IGUAL: `narrating` nace en true y solo lo apaga
	# `_play()`. Sin esto, `level3d._ask_start` se quedaba esperando (con tope
	# de 90 s) a un guion que no existía y el nivel NO ARRANCABA: ni cartel de
	# "¿Comenzamos?", ni cuenta atrás, ni clientes. Pasaba en cualquier
	# escenario sin guion cuyas dos explicaciones de arriba ya estuvieran
	# dadas — el 16, por ejemplo, que monta director por el vigía del tesoro.
	if guion == "":
		_play()
		return
	match guion:
		"nivel_1":
			await _nivel_1()
		"nivel_2":
			await _nivel_2()
		"nivel_3":
			await _nivel_3()
		"nivel_4":
			await _nivel_4()
		"nivel_5":
			await _nivel_5()
		"nivel_6":
			await _nivel_6()
		"nivel_7":
			await _nivel_7()
		"nivel_8":
			await _nivel_8()
		"nivel_9":
			await _nivel_9()
		"nivel_10":
			await _nivel_10()
		"nivel_11":
			await _nivel_11()
		"nivel_13":
			await _nivel_13()
		"nivel_14":
			await _nivel_14()
		"nivel_15":
			await _nivel_15()


## Mientras una lección está en curso, TODO el que se siente entra con la
## paciencia retenida: si no, los clientes que llegan en mitad de la
## explicación empiezan a impacientarse mientras David habla.
func _tick(_delta: float) -> void:
	if not _paciencia_quieta:
		return
	for c in lv.seat_clients:
		if c is Node3D and is_instance_valid(c) and not c.patience_hold:
			c.patience_hold = true


# ------------------------------------------------------------------ utilidades

## Espera a que se cumpla una condición, sin bloquear el juego.
##
## SI EL NIVEL SE HA IDO, NO VUELVE NUNCA. Salía del bucle con un simple
## `is_inside_tree()` y devolvía el control al guion, que daba por hecho que
## había vuelto porque su CONDICIÓN se cumplió y seguía con la línea siguiente
## sobre un nivel que ya no existía: al pulsar **Salir** en mitad del nivel 7,
## el `create_timer` de después reventaba con `get_tree()` a null y el guion
## moría a gritos en la consola. Aparcar la corrutina para siempre es la única
## forma de pararla —GDScript no deja matarlas— y no filtra nada: cuando el
## director se libera con su nivel, la corrutina se va con él.
func _esperar(cond: Callable) -> void:
	while true:
		if not _vivo():
			await _jamas
			return
		if bool(cond.call()):
			return
		await get_tree().process_frame


## Como _say, pero se calla en modo mudo (las repeticiones del nivel del jefe).
func _decir(lines: Array, espera := -1.0, congelar := true) -> void:
	if _mudo:
		return
	await _say(lines, espera, congelar)


## Dinero objetivo del nivel (el umbral de las 3 estrellas).
func _objetivo() -> int:
	if lv.star_money.is_empty():
		return 1
	return int(lv.star_money.back())


func _progreso() -> float:
	return float(lv.money_earned) / maxf(float(_objetivo()), 1.0)


## ¿Se ha ido algún cliente SIN comer nada desde la última vez que se miró?
func _alguien_se_fue_de_vacio() -> bool:
	while _vistos < lv.client_reports.size():
		var r: Dictionary = lv.client_reports[_vistos]
		_vistos += 1
		if int(r.get("penalty", 0)) > 0:
			return true
	return false


## Espera a que termine la fase de preparación (los guiones no interrumpen los
## segundos de adelantar platos, que son parte del ritmo del nivel).
func _tras_la_preparacion() -> void:
	await _esperar(func() -> bool: return not lv.prep_phase)


## El primer cliente SENTADO de ese tipo ("" = de cualquier tipo).
func _cliente_tipo(tipo := "") -> Node3D:
	for c in lv.seat_clients:
		if c is Node3D and is_instance_valid(c) \
				and (tipo == "" or c.client_type == tipo):
			return c
	return null


## El primer cliente que esté MASTICANDO ahora mismo, o null.
func _comiendo() -> Node3D:
	for c in lv.seat_clients:
		if c is Node3D and is_instance_valid(c) and c.is_eating():
			return c
	return null


## Cuántos clientes hay sentados ahora mismo.
func _sentados() -> int:
	var n := 0
	for c in lv.seat_clients:
		if c is Node3D and is_instance_valid(c):
			n += 1
	return n


## ¿Ha comido ALGUIEN esta receta (sentado o ya ido)?
func _alguien_comio(recipe_id: String) -> bool:
	for c in lv.seat_clients:
		if c is Node3D and is_instance_valid(c) and recipe_id in c.eaten_ids:
			return true
	for r in lv.client_reports:
		if recipe_id in (r.get("eaten", []) as Array):
			return true
	return false


## El multiplicador de variedad más alto que hay ahora mismo en la barra.
func _mejor_variedad() -> int:
	var m := 0
	for c in lv.seat_clients:
		if c is Node3D and is_instance_valid(c):
			m = maxi(m, int(c.variety))
	return m


## Saca de la cola al primer cliente de ese tipo y lo manda al principio.
##
## EN UN NIVEL CON CUPO NO SE ADELANTA A NADIE SI YA NO QUEDAN LLEGADAS
## APUNTADAS: adelantar gasta un hueco del horario, y si el horario está vacío
## lo que se hace es INVENTAR un cliente. Pasó en el nivel 2 — si el segundo
## grumete ya había entrado por su cuenta antes de que saltara el refuerzo, los
## tres adelantos solo podían gastar dos huecos y la isla acababa con CINCO
## clientes en vez de cuatro.
func _adelantar_tipo(tipo: String) -> void:
	if not lv.unlimited and lv.arrival_queue.is_empty():
		return
	for i in lv.type_queue.size():
		if lv.type_queue[i] == tipo:
			lv.type_queue.remove_at(i)
			lv.type_queue.push_front(tipo)
			break
	# Adelantarlo GASTA su hueco del horario: sin esto el reloj seguía teniendo
	# todas las llegadas apuntadas y entraba un cliente de más, así que el
	# contador del HUD pasaba del total del nivel.
	if lv._try_spawn_client() and not lv.arrival_queue.is_empty():
		lv.arrival_queue.pop_front()


## Regala una receta EN PLENA PARTIDA: la desbloquea con su despensa y la
## planta en la tabla. El desbloqueo de verdad lo garantiza complete_port
## (gift_recipes) por si el turno se cierra antes de llegar aquí.
func _regalar_receta(id: String) -> void:
	if GameState.unlock_recipe(id):
		GameState.gift_ingredients_for([id], GameState.PORT_GIFT)
		GameState.save_game()
	lv.prep_board.add_recipe(id)


## Congela (o suelta) la paciencia de todos los sentados, y de los que lleguen
## mientras dure la lección.
func _congelar(on: bool) -> void:
	_paciencia_quieta = on
	for c in lv.seat_clients:
		if c is Node3D and is_instance_valid(c):
			c.patience_hold = on


## Cuántos platos hay guardados en las cajas.
func _platos_guardados() -> int:
	var n := 0
	var cajas: Dictionary = lv.prep_board.stacks
	for hueco in cajas:
		n += int(cajas[hueco].count)
	return n


## Gigi explica el CUBO DE BASURA la primera vez que un plato da la vuelta
## entera sin que nadie lo coja. Corre en paralelo al guion.
##
## SE CUENTA UNA VEZ EN TODA LA PARTIDA, no una por nivel: la bandera es
## PERSISTENTE (`GameState.trash_intro_done`). Con la lección atada al nivel,
## David y Gigi soltaban la misma parrafada en el 1, en el 2, en el 3... cada
## vez que se colaba un plato, que es justo cuando el jugador menos quiere que
## le paren el juego.
func _vigilar_basura() -> void:
	if GameState.trash_intro_done:
		return
	var perdidos: int = lv.plates_wasted
	while not lv.ended and is_inside_tree():
		await get_tree().process_frame
		if lv.plates_wasted <= perdidos:
			continue
		if dialog.is_talking():
			continue
		GameState.trash_intro_done = true
		GameState.save_game()
		# UN RESPIRO ANTES DE HABLAR, y el FOCO en el cubo: el aviso saltaba en
		# el mismo fotograma en que el plato se volcaba, así que el jugador leía
		# "¡a la basura!" sin haber visto nada caer. 0,1 s bastan para que la
		# caída se registre, y el foco dice DÓNDE ha sido.
		await _pausa(0.1)
		if lv.trash_pos != Vector3.ZERO:
			_focus_screen_rect(Rect2(
				lv.cam.unproject_position(lv.trash_pos) - Vector2(95, 110),
				Vector2(190, 220)))
		await _say([
			{ "text": "¡A LA BASURA! ¡RAAAK! ¡Derechito al cubo!", "who": "gigi", "mood": "loro_sorpresa" },
			{ "text": "El plato que da la **vuelta entera** sin que nadie lo coja acaba en el cubo de la esquina... y te descuenta oro.", "mood": "serio" },
			{ "text": "Sirve pensando en QUIÉN va a cogerlo, no por llenar la cinta.", "mood": "hablando" },
		])
		_play()
		return


# ------------------------------------------------------------------- nivel 1
# Cala Tortuga: LA PRIMERA JORNADA, y es una jornada corriente. Cuatro grumetes
# a ritmo normal, dos recetas en la tabla desde el primer fotograma y la clase
# completa sobre el primer cliente: paciencia, bocado y oro. Las cajas son la
# lección del nivel 2 y aquí ni aparecen.

func _nivel_1() -> void:
	# LA PRIMERA LÍNEA VA SIN FOCO: habla de Cala Tortuga, no del nigiri, y con
	# el foco puesto desde el principio el jugador miraba un pergamino de la
	# tabla mientras le presentaban la isla. El foco entra con la línea que lo
	# menciona, que es la segunda.
	await _say([
		{ "text": "¡**Cala Tortuga**, tu primer turno de verdad! Cuatro grumetes, y tú al mando de la cinta.", "mood": "feliz" },
	])
	await _focus_node(lv.prep_board.buttons["nigiri_salmon"], 12.0)
	await _say_raised([
		{ "text": "Te he dejado en la tabla una receta nueva, el **nigiri de salmón**: menos trabajo que el maki y mejor pagado.", "mood": "hablando" },
		{ "text": "Pero el **maki** te saca más platos de una sola preparación. Ya lo irás pillando.", "mood": "hablando" },
	])
	_play()
	# Gigi salta la PRIMERA vez que un plato acaba en el cubo (corre en
	# paralelo al resto del guion: puede pasar en cualquier momento).
	_vigilar_basura()
	await _tras_la_preparacion()

	# --- El cliente se sienta → la barra de PACIENCIA (a los 0,5 s) ---
	await _esperar(func() -> bool:
		var c := _cliente_tipo()
		return lv.ended or (c != null and c.state == c.State.WAITING))
	if lv.ended:
		return
	var alumno := _cliente_tipo()
	if alumno == null:
		return
	await _pausa(0.5)
	if not is_instance_valid(alumno):
		return
	_focus_bar(alumno.patience_bar())
	await _say([
		{ "text": "¿Ves esa barra? Es su **paciencia**: si no come, baja... y al fondo, se larga sin pagar.", "mood": "serio" },
		{ "text": "Cada plato que se come se la rellena. Que ninguna barra llegue al fondo: esa es la mitad del oficio.", "mood": "hablando" },
	])
	_play("¡Prepárale un plato y mándalo a la **cinta**!")

	# --- Le llega el plato → la barra de BOCADO (a los 0,5 s) ---
	# NADA DE ATARSE A `alumno` AQUÍ: si ese cliente se marcha sin probar
	# bocado (y puede pasar, es el primero y el jugador está aprendiendo), el
	# guion se quedaba esperando un `is_eating()` que ya no iba a llegar nunca
	# y el nivel se jugaba entero sin una explicación más. Vale CUALQUIERA que
	# se ponga a comer.
	await _esperar(func() -> bool: return lv.ended or _comiendo() != null)
	if lv.ended:
		return
	var comensal := _comiendo()
	await _pausa(0.5)
	if comensal == null or not is_instance_valid(comensal):
		comensal = _comiendo()
	if comensal != null:
		_focus_bar(comensal.eat_bar())
	await _say([
		{ "text": "¡RAAK! La barra **azul** es su **bocado**: mientras baja, está masticando.", "who": "gigi", "mood": "loro" },
		{ "text": "Y mientras mastica NO coge nada más de la cinta. Ese rato es tuyo: adelanta el siguiente plato.", "mood": "loro_resignado" },
	])
	_play()

	# --- Alguien paga → el ORO ---
	# Por lo mismo: se espera a que el MARCADOR suba, venga de quien venga.
	await _esperar(func() -> bool: return lv.ended or lv.money_earned > 0)
	if lv.ended:
		return
	await _focus_node(lv.money_label, 24.0)
	await _say([
		{ "text": "¡Y ahí está el **oro**! Cada plato comido suma su precio; la cifra de al lado es el **objetivo** del turno.", "mood": "feliz" },
		{ "text": "Llega al objetivo y el turno se cierra solo.", "mood": "riendo" },
	])
	_play()

	# --- EL DADO: el SEGUNDO plato que iba a comerse alguien se ignora ---
	# El jugador tiene que VER a un cliente dejar pasar un plato antes de que
	# nadie le cuente que eso puede ocurrir; si no, la primera vez que le pase
	# de verdad —y le pasará— lo vivirá como un fallo del juego. Así que el
	# nivel provoca el desprecio a propósito y David lo explica con el plato
	# despreciado todavía en la cinta.
	lv.forzar_desprecio = true
	var sitio := Vector3.ZERO
	var visto := [false]
	var conexion := func(pos: Vector3) -> void:
		sitio = pos
		visto[0] = true
	lv.plato_ignorado.connect(conexion)
	await _esperar(func() -> bool: return lv.ended or visto[0])
	if lv.plato_ignorado.is_connected(conexion):
		lv.plato_ignorado.disconnect(conexion)
	if lv.ended:
		return
	_focus_screen_rect(Rect2(lv.cam.unproject_position(sitio) - Vector2(80, 80),
		Vector2(160, 160)))
	await _say([
		{ "text": "¡Ojo a eso! Ha dejado pasar el plato. No siempre les apetece lo que ven: a veces uno mira y sigue a lo suyo.", "mood": "sorprendido" },
		{ "text": "No es culpa tuya. Cada cliente tiene su momento, y un plato que hoy no quiere puede querérselo el de al lado.", "mood": "hablando" },
		{ "text": "Por eso no conviene servir a uno solo: llena la cinta pensando en TODA la barra.", "mood": "serio" },
	])
	_play()


# ------------------------------------------------------------------- nivel 2
# Playa del Coco: LAS CAJAS DE GUARDADO, y nada más. El primer grumete entra
# solo; cuando se ha comido su SEGUNDO plato (o su paciencia ha bajado un
# tercio) entran los otros TRES DE GOLPE, que es lo que hace evidente el
# problema: un plato en la cinta se lo queda el primero que pase.

## Platos que hay que tener guardados para que la lección de cajas dé el paso.
const CAJAS_PEDIDAS := 4
## Fracción de paciencia del primer cliente a la que entra el refuerzo si aún
## no ha llegado a su segundo plato.
const REFUERZO_PACIENCIA := 2.0 / 3.0

var _cajas_regano := false


func _nivel_2() -> void:
	var pb: Control = lv.prep_board
	# LAS CAJAS SE ENTREGAN Y SE EXPLICAN AL EMPEZAR, no cuando aprieta. Antes
	# aparecían de golpe con la marabunta encima, así que la herramienta nueva
	# y el apuro llegaban en el mismo segundo y no había manera de mirarlas con
	# calma. Ahora se presentan con la barra tranquila —solo hay una boca— y lo
	# que trae la marabunta es la OBLIGACIÓN de usarlas, que es otra lección.
	await _say([
		{ "text": "**Playa del Coco**. Hoy te voy a enseñar el truco que separa a un cocinero de un friegaplatos.", "mood": "feliz" },
	])
	await _focus_node(pb.storage_box, 16.0)
	await _say([
		{ "text": "Estas dos **cajas** son tuyas desde hoy. Guardan platos ya hechos y los mantienen calientes hasta que tú digas.", "mood": "hablando" },
		{ "text": "Sirve para adelantar trabajo: cocinas cuando tienes hueco y sueltas cuando hace falta.", "mood": "serio" },
		{ "text": "¡CAJAS! ¡RAAAK!", "who": "gigi", "mood": "loro" },
		{ "text": "Y otra cosa: desde hoy la **despensa se gasta**. Cada receta que embarques consume un uso de sus ingredientes.", "mood": "serio" },
		{ "text": "Empieza tranquilo, que de momento solo hay una boca. Ya te avisaré yo cuando toque.", "mood": "hablando" },
	])
	_play()
	_vigilar_basura()
	await _tras_la_preparacion()

	# --- El primero come DOS platos (o pierde un tercio de paciencia) ---
	await _esperar(func() -> bool:
		var c := _cliente_tipo()
		return lv.ended or (c != null and c.state == c.State.WAITING))
	if lv.ended:
		return
	var alumno := _cliente_tipo()
	if alumno == null:
		return
	await _esperar(func() -> bool:
		if lv.ended or not is_instance_valid(alumno):
			return true
		if alumno.eaten_ids.size() >= 2:
			return true
		return alumno.patience <= alumno.patience_max * REFUERZO_PACIENCIA)
	if lv.ended:
		return

	# --- ...y entra DE GOLPE toda la clientela que quede ---
	# Se traen los que FALTAN, no un 3 clavado: si el segundo grumete ya había
	# entrado por su cuenta, tres adelantos habrían dejado la isla con cinco
	# clientes en un nivel diseñado para cuatro.
	for i in maxi(int(lv.total_clients) - int(lv.clients_spawned), 0):
		_adelantar_tipo("E")
	await _pausa(1.4)
	if lv.ended:
		return
	await _leccion_cajas()


## LA LECCIÓN DE LAS CAJAS. Con la barra llena, un plato suelto no llega a
## todos: hay que preparar de antemano y soltarlos de golpe.
##
## Mientras dura, las paciencias se CONGELAN (`patience_hold`) y la cinta se
## CIERRA (`prep_board.block_serve`): el jugador no puede resolverlo a su
## manera ni le corre prisa, que es lo que permite explicarlo con calma. Se
## abre en cuanto tiene los tres platos guardados.
func _leccion_cajas() -> void:
	var pb: Control = lv.prep_board
	_congelar(true)
	# (Las cajas ya están puestas y explicadas desde el principio del nivel: lo
	# que se enseña AQUÍ es para qué sirven de verdad cuando la barra aprieta.)
	await _focus_node(pb.storage_box, 16.0)
	await _say([
		{ "text": "¡Ahora sí! Se nos llena la barra, y un plato en la cinta se lo queda **el primero que pase**, no el que tú quieras.", "mood": "sorprendido" },
		{ "text": "Aquí es donde las cajas valen su peso en oro: cocinas de antemano y los sueltas TODOS DE GOLPE, uno para cada boca.", "mood": "hablando" },
		{ "text": "Prepara **%d platos** y mételos en las cajas. Yo te espero: hoy nadie se me impacienta." % CAJAS_PEDIDAS, "mood": "serio" },
	])
	# Si intenta mandarlo a la cinta, Gigi le corta (una sola vez).
	pb.block_serve = true
	if not pb.serve_blocked.is_connected(_on_cinta_cerrada):
		pb.serve_blocked.connect(_on_cinta_cerrada)
	_play("¡A las **cajas**! Guarda %d platos antes de servir." % CAJAS_PEDIDAS)
	await _esperar(func() -> bool:
		return lv.ended or _platos_guardados() >= CAJAS_PEDIDAS)
	if lv.ended:
		_congelar(false)
		pb.block_serve = false
		return

	# Con la despensa llena, se abre la cinta y se sueltan los tres seguidos.
	pb.block_serve = false
	await _say([
		{ "text": "¡Eso es! Ahora **suéltalos todos**: arrastra cada plato de la caja a la cinta, uno detrás de otro.", "mood": "feliz" },
		{ "text": "Tres platos seguidos llegan a los tres clientes. Uno suelto se lo habría comido el primero.", "mood": "hablando" },
	])
	_play("¡Arrastra los platos de las **cajas** a la **cinta**!")
	var guardados := _platos_guardados()
	await _esperar(func() -> bool:
		return lv.ended or _platos_guardados() <= maxi(guardados - CAJAS_PEDIDAS, 0))
	_congelar(false)
	if lv.ended:
		return
	await _say([
		{ "text": "¡Así se sirve una barra llena, %s! Cocina de más cuando puedas y suelta cuando haga falta." % GameState.player_title(), "mood": "riendo" },
		{ "text": "Una caja apila platos **iguales**, hasta tres. El resto del turno es tuyo: ¡a por esos grumetes!", "mood": "gritando" },
	])
	_play()


## Gigi corta al jugador la primera vez que intenta servir con la cinta
## cerrada: sin esto, el plato "no reacciona" y parece un fallo del juego.
func _on_cinta_cerrada() -> void:
	if _cajas_regano or dialog.is_talking():
		return
	_cajas_regano = true
	await _say([
		{ "text": "¡QUIETO AHÍ! ¡RAAAK! ¡A la cinta no, que se lo lleva el primero!", "who": "gigi", "mood": "loro_grito" },
		{ "text": "Hazle caso: **arrástralo a una caja**. Cuando tengas los tres, los sueltas juntos.", "mood": "loro_resignado" },
	])
	_play("¡A las **cajas**! Guarda %d platos antes de servir." % CAJAS_PEDIDAS)


# ------------------------------------------------------------------- nivel 3
# Isla del Bambú: EL PICOTEO. David entrega el edamame al empezar y explica lo
# que lo hace distinto — se coge SIN soltar el plato que se está comiendo.

const RECETA_PICOTEO := "edamame"


func _nivel_3() -> void:
	await _say([
		{ "text": "**Isla del Bambú**: cinco grumetes con hambre de verdad. Hoy te traigo un plato distinto a todos.", "mood": "feliz" },
	])
	_regalar_receta(RECETA_PICOTEO)
	await _focus_node(lv.prep_board.buttons[RECETA_PICOTEO], 12.0)
	await _say_raised([
		{ "text": "El **edamame**: unas vainas de soja, dos segundos de trabajo y a la cinta.", "mood": "hablando" },
		{ "text": "Es **PICOTEO**, y eso es lo importante: un cliente lo coge **sin soltar** el plato que está comiendo.", "mood": "serio" },
		{ "text": "¿Y para qué? Porque le alarga el **bocado**... y mientras mastica, su paciencia no baja. Regalas tiempo por un doblón.", "mood": "hablando" },
		{ "text": "¡PICOTEO PARA TODOS! ¡RAAAK!", "who": "gigi", "mood": "loro" },
	])
	_play()
	_vigilar_basura()
	await _tras_la_preparacion()

	# --- Alguien está masticando: momento de colarle el edamame ---
	# EL PRIMER GRUMETE NO FALLA EL DADO DEL PICOTEO: la lección es "se cuela
	# mientras come", y con el 0.9 de la receta había un 10% de que el jugador
	# lo hiciera todo bien y viera su edamame pasar de largo.
	await _esperar(func() -> bool: return lv.ended or _cliente_tipo() != null)
	var alumno := _cliente_tipo()
	if alumno != null and is_instance_valid(alumno):
		alumno.snack_sure = true
	await _esperar(func() -> bool:
		return lv.ended or _comiendo() != null or _alguien_comio(RECETA_PICOTEO))
	if lv.ended:
		return
	if not _alguien_comio(RECETA_PICOTEO):
		await _say([
			{ "text": "¡AHORA! Ese está masticando: mándale un **edamame** y verás cómo lo coge igual.", "mood": "gritando" },
		])
		_play("¡Un **edamame** a la cinta mientras alguien come!")
		await _esperar(func() -> bool:
			return lv.ended or _alguien_comio(RECETA_PICOTEO))
	if lv.ended:
		return
	await _say([
		{ "text": "¿Lo has visto? Ni ha soltado el plato. Eso es el picoteo: **se cuela** entre bocado y bocado.", "mood": "feliz" },
		{ "text": "Un picoteo no llena, pero mientras se pica no se espera. Y quien no espera, no se impacienta.", "mood": "hablando" },
	])
	_play()


# ------------------------------------------------------------------- nivel 4
# Arrecife del Ron: EL MULTIPLICADOR, el HASTÍO y el PALADAR. Ocho grumetes de
# dos en dos con solo TRES recetas: repetir es inevitable, y ahí entra el té
# verde. Al cerrar, Saverio abre la tienda y el juego lleva al jugador allí.

func _nivel_4() -> void:
	await _say([
		{ "text": "**Arrecife del Ron**: ocho bocas y de dos en dos. Y hoy la carta se te queda en **tres** huecos.", "mood": "hablando" },
		# SAVERIO SALUDA ANTES DE EMPEZAR. Al cerrar el turno abre su puesto, y
		# que su primera aparición fuera esa —vendiéndote algo— dejaba al
		# tendero convertido en un botón. Aquí es un vecino del puerto que ve
		# atracar el barco.
		{ "text": "¡Eh, los del barco! ¿Ese es el cocinero nuevo?", "who": "saverio", "mood": "hablando" },
		{ "text": "El mismo. Saverio lleva el puesto de este muelle; ya hablaréis cuando cierres.", "mood": "feliz" },
		{ "text": "Cocina bien y te hago precio, chaval. Cocina mal y te hago precio también, pero me río.", "who": "saverio", "mood": "riendo" },
		{ "text": "Con tres recetas y ocho clientes vas a tener que repetir plato. Fíjate en lo que pasa cuando lo hagas.", "mood": "serio" },
	])
	_play()
	_vigilar_basura()
	await _tras_la_preparacion()

	# --- EJERCICIO OBLIGADO: dos platos DISTINTOS al mismo cliente ---
	#
	# La lección de la chapa esperaba a que el multiplicador llegara a x2 por su
	# cuenta, y un jugador que sirva siempre la misma receta NO LLEGA NUNCA: se
	# jugaba el nivel entero —el que ESTRENA el multiplicador— sin oír una
	# palabra de él. Así que David lo pide a la cara y espera a que se haga.
	#
	# Al alumno se le RETIENE LA PACIENCIA mientras dura el ejercicio: no puede
	# irse a mitad de la clase y dejar al guion esperando a un cliente que ya
	# no está (el mismo apaño que el refuerzo del nivel 2).
	await _esperar(func() -> bool: return lv.ended or _cliente_tipo() != null)
	if lv.ended:
		return
	var alumno := _cliente_tipo()
	if alumno != null and is_instance_valid(alumno):
		alumno.patience_hold = true
		_focus_client(alumno)
	await _say([
		{ "text": "Ese de ahí. Vamos a hacer una prueba: sírvele **dos platos DISTINTOS**, uno detrás de otro.", "mood": "hablando" },
		{ "text": "Distintos de verdad, ¿eh? Nada de darle dos veces lo mismo. Y no le quites ojo a su cabeza.", "mood": "serio" },
	])
	_play("¡**Dos platos distintos** a ese cliente!")
	# El alumno puede ser otro si el jugador se adelanta con el de al lado: se
	# da por buena la lección de cualquiera que llegue a x2 (la condición MIRA;
	# el dato se recoge fuera, que las lambdas de `_esperar` capturan por valor).
	await _esperar(func() -> bool: return lv.ended or _mejor_variedad() >= 2)
	if alumno != null and is_instance_valid(alumno):
		alumno.patience_hold = false
	if lv.ended:
		return
	var lucido := alumno
	for c in lv.seat_clients:
		if c is Node3D and is_instance_valid(c) and int(c.variety) >= 2:
			lucido = c
			break
	if lucido != null and is_instance_valid(lucido):
		_focus_client(lucido)
	await _say([
		{ "text": "¡Mira esa **chapa dorada**! Le has servido dos platos DISTINTOS y su **multiplicador** ha subido a **x2**.", "mood": "feliz" },
		{ "text": "Cada plato que prueba por primera vez sube la chapa, le recarga más paciencia y te paga **un doblón extra por punto**.", "mood": "hablando" },
		{ "text": "¡VARIEDAD, GRUMETE! ¡RAAAK!", "who": "gigi", "mood": "loro" },
	])
	_play("¡Sírvele **platos distintos** y verás subir la chapa!")

	# --- El primer repetido → EL HASTÍO y el té verde ---
	await _esperar(func() -> bool:
		if lv.ended:
			return true
		for c in lv.seat_clients:
			if c is Node3D and is_instance_valid(c) and c.repeat_count >= 1:
				return true
		return false)
	if lv.ended:
		return
	await _say([
		{ "text": "Y ahí está la otra cara: ese plato era **repetido**, la chapa se ha caído a cero y apenas le ha recargado.", "mood": "serio" },
		{ "text": "Es el **hastío**. Repetir una vez recarga poco; a la tercera, nada; y de ahí en adelante hasta le QUITA barra.", "mood": "hablando" },
		{ "text": "Cada cliente lleva su propio **paladar**: lleva la cuenta de lo que ya ha probado.", "mood": "serio" },
	])
	# El remedio, recién salido de mi despensa.
	_regalar_receta("te_verde")
	await _focus_node(lv.prep_board.buttons["te_verde"], 12.0)
	await _say_raised([
		{ "text": "El remedio: **té verde**. Es picoteo, como el edamame, y además le **limpia el paladar**.", "mood": "feliz" },
		{ "text": "Un **paladar limpio** permite apreciar de nuevo cada plato. Ojo: la chapa se queda a cero, así que hay que reconstruirla.", "mood": "hablando" },
	])
	_play()

	# (La presentación de SAVERIO y la tienda NO va aquí: se ve al VOLVER AL
	# MAPA, en `main_menu._presentar_saverio`. Encadenada al cierre del turno se
	# comía el cartel de resultados, que es lo que el jugador quiere leer justo
	# después de una jornada.)


# ------------------------------------------------------------------- nivel 5
# Cala del Calamar: LOS POSTRES (el mochi) y, con ellos, las PROPINAS y los
# potenciadores de partida — que se estrenan justo en este nivel.

func _nivel_5() -> void:
	await _focus_node(lv.tip_bar, 20.0)
	await _say([
		{ "text": "¿Ves esa barra nueva, la de debajo del oro? Es el **bote de propinas**. Desde hoy, los clientes contentos dejan algo extra.", "mood": "feliz" },
		{ "text": "La propina NO cuenta para el objetivo: va al bote. Y cuando el bote se llena...", "mood": "hablando" },
		{ "text": "¡REGALO! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "...te dan a elegir un **potenciador**: una ayuda para el resto del turno.", "mood": "riendo" },
	])
	_play()
	_vigilar_basura()
	await _tras_la_preparacion()

	# --- El mochi, cuando ya haya alguien con arco hecho (o a media faena) ---
	await _esperar(func() -> bool:
		return lv.ended or _mejor_variedad() >= 2 or _progreso() >= 0.35)
	if lv.ended:
		return
	_regalar_receta("mochi")
	await _focus_node(lv.prep_board.buttons["mochi"], 12.0)
	await _say_raised([
		{ "text": "La lección de hoy: el **mochi de matcha**. Es un **postre**, y un postre es **la cuenta**.", "mood": "hablando" },
		{ "text": "Al terminárselo, el cliente paga, deja propina segura, **cobra su multiplicador** al bote... y se despide.", "mood": "serio" },
		{ "text": "¡FUERA! ¡SITIO PARA EL SIGUIENTE! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Eso. Cuanto más alta lleve la chapa, más gorda la propina: súbele la variedad y **entonces** le sacas el postre.", "mood": "loro_resignado" },
	])
	_play("¡Súbele la chapa y despídelo con un **mochi**!")

	# --- El primer potenciador elegido ---
	await _esperar(func() -> bool:
		return lv.ended or (lv.powerups_claimed >= 1
				and not lv.powerup_panel.visible))
	if lv.ended:
		return
	await _say([
		{ "text": "¡Tu primer **potenciador**! Son de un solo turno y el sorteo cambia cada vez: gástalos sin pena.", "mood": "feliz" },
	])
	_play()


# ------------------------------------------------------------------- nivel 6
# Bahía del Kraken: LOS EXTRAS. Saverio los saca de la caja al empezar el turno
# y a partir de aquí existen en toda la campaña.

func _nivel_6() -> void:
	# Los extras aún no existen en la tabla: se encienden al regalarlos.
	var pb: Control = lv.prep_board
	pb.hide_extras = true
	pb.refresh_extra_ui()
	await _say([
		{ "text": "**Bahía del Kraken**: ocho bocas en dos oleadas de cuatro. Y traigo compañía.", "mood": "hablando" },
		{ "text": "¡Cocinero! Vengo a enseñarte lo que llevo en el fondo de la caja.", "who": "saverio", "mood": "feliz" },
		{ "text": "Mis **extras**: **jengibre**, **wasabi** y **soja**. Van sobre el plato YA TERMINADO, en la esquina de la tabla.", "who": "saverio", "mood": "explicando" },
		{ "text": "Con cualquiera de los tres, un plato **repetido cuenta como nuevo**: no rompe la chapa, la sube.", "who": "saverio", "mood": "hablando" },
	])
	# A partir de aquí los extras existen en todo el juego (tabla y tienda).
	# Los usos se regalan UNA sola vez: si el jugador no aprueba y repite, el
	# guion vuelve a correr (el puerto no queda narrado) y sin esta guarda se
	# rellenaría la despensa de extras en cada intento.
	var primera := not GameState.extras_done
	GameState.extras_done = true
	if primera:
		for ing in RecipeData.EXTRAS:
			GameState.add_ingredient_uses(ing, GameState.TUTORIAL_GIFT)
	GameState.save_game()
	pb.hide_extras = false
	pb.refresh_extra_ui()
	# Los tres botones son hijos sueltos del panel de la mesa (no hay fila que
	# enfocar), así que se enfoca su envolvente.
	var botones: Array[Control] = []
	for id in RecipeData.EXTRAS:
		if pb.extra_buttons.has(id):
			botones.append(pb.extra_buttons[id])
	if not botones.is_empty():
		await _focus_nodes(botones, 14.0)
	await _say([
		{ "text": "Pero cada uno se paga con lo suyo: el **jengibre** te baja un punto de chapa, el **wasabi** le quita paciencia en vez de dársela...", "who": "saverio", "mood": "explicando" },
		{ "text": "...y la **soja** hace que mastique más deprisa, o sea que vuelve antes a la cola. Diez usos de cada, invita la casa.", "who": "saverio", "mood": "hablando" },
		{ "text": "Son tu as en la manga cuando a un cliente ya no le quedan platos nuevos que probar. ¡A cocinar!", "mood": "riendo" },
	])
	_play()
	_vigilar_basura()


# ------------------------------------------------------------------- nivel 7
# Estrecho del Rayo: el primer ABORDAJE (reloj y clientela sin fin) y los
# primeros PIRATAS del juego. Los capitanes NO salen aquí: llegan con Pablo, en
# el 10. El pirata es el TERCER cliente (`client_order` del puerto), así que no
# hay que adelantar a nadie: solo esperar a que se siente.
#
# Y ES **EL** PIRATA: sube uno solo en todo el nivel (ver `client_weights` del
# puerto) porque es quien lleva encima la BANDERA PIRATA, y este es el único
# sitio del juego donde se consigue. Le pone precio él mismo, en su propio
# retrato: PLATOS_BANDERA platos y el trapo es tuyo.

## Platos que hay que servirle al pirata para que suelte su bandera. TRES, no
## cinco: en un abordaje de 2:30, con el pirata entrando el tercero y comiendo
## de dos estrellas, cinco eran casi todo el turno dedicado a un solo cliente.
const PLATOS_BANDERA := 3
## EL pirata del nivel 7 y su trato, que se resuelve por señal (ver
## `_on_pirata_come`).
var _pirata_bandera: Node3D = null
## La CUENTA está hecha (la apunta la señal) y el premio ya se ha ENTREGADO
## (lo hace el guion, después de que el pirata hable). Son dos cosas distintas
## a propósito: ver `_on_pirata_come` y `_entregar_bandera`.
var _bandera_dada := false
var _bandera_entregada := false


## QUÉ SON LOS COLECCIONABLES. Se cuenta UNA sola vez en toda la partida y
## SIEMPRE con una pieza recién ganada en la mano (`col_intro_done`): la bandera
## del pirata, el tesoro del cliente del nivel 12 o el primer cofre de la pesca,
## lo que llegue antes. Soltado a palo seco al empezar un puerto sonaba a
## folleto; con la pieza delante se explica solo.
func _explicar_coleccionables() -> void:
	if GameState.col_intro_done:
		return
	GameState.col_intro_done = true
	GameState.save_game()
	await _say([
		{ "text": "Eso que acabas de guardarte es un **coleccionable**.", "mood": "feliz" },
		{ "text": "No dan oro ni sirven para cocinar. Se tienen, y punto: van a la **vitrina** del Inventario, y ahí se quedan para toda la travesía.", "mood": "hablando" },
		{ "text": "¡PARA TODA LA TRAVESÍA! ¡RAAAK!", "who": "gigi", "mood": "loro" },
		{ "text": "Los hay repartidos por medio mar, y cada uno se consigue de una manera. Ese es el primero.", "mood": "serio" },
	])


func _nivel_7() -> void:
	await _focus_node(lv.time_label, 24.0)
	await _say([
		{ "text": "Se cierra al agotarse el reloj... o al llegar al **objetivo**. Y cada 10 segundos que sobren, prima extra.", "mood": "hablando" },
		{ "text": "¡AL ABORDAJE! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
	])
	_play()
	_vigilar_basura()
	await _tras_la_preparacion()

	# --- El primer PIRATA de la campaña (el tercero en subir a bordo) ---
	await _esperar(func() -> bool:
		return lv.ended or _cliente_tipo("A") != null)
	if lv.ended:
		return
	var pirata := _cliente_tipo("A")
	# Un momento para verlo sentarse antes de que nadie hable.
	await _pausa(1.2)
	if pirata != null and is_instance_valid(pirata):
		_focus_client(pirata)
	await _say([
		{ "text": "¡ESE NO ES UN GRUMETE! ¡UN **PIRATA** EN LA BARRA! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Hasta hoy solo te habían venido **grumetes**, que comen de **1 estrella**. Se acabó lo fácil.", "mood": "serio" },
		{ "text": "Un **pirata** come de **2 estrellas**. Mira las estrellas del pergamino antes de servir: de un plato de una, casi ni se entera.", "mood": "hablando" },
	])

	# El regalo: la primera receta de 2 estrellas, en la tabla y en marcha.
	_regalar_receta("nigiri_atun")
	await _focus_node(lv.prep_board.buttons["nigiri_atun"], 12.0)
	await _say_raised([
		{ "text": "Por eso te traigo el **nigiri de atún**: **dos estrellas**. Tuyo, y te lo pongo en la tabla para que lo estrenes con él.", "mood": "feliz" },
		{ "text": "Y ojo: paga bastante mejor que lo que venías sirviendo.", "mood": "serio" },
	])
	_play("¡El **nigiri de atún**! Estrénalo con el pirata.")
	await lv.prep_board.dish_served
	_play()

	# --- EL TRATO DE LA BANDERA ---
	# El pirata habla por sí mismo (retrato propio) y pone precio a su bandera.
	# Es el ÚNICO sitio del juego donde se consigue ese coleccionable, y por eso
	# este puerto trae un solo pirata: con dos no habría forma de saber a cuál
	# se le está sirviendo.
	if pirata == null or not is_instance_valid(pirata) or lv.ended:
		return
	await _pausa(1.0)
	if not is_instance_valid(pirata) or lv.ended:
		return
	# LA CUENTA LA LLEVA EL PROPIO PIRATA, POR SEÑAL. Estaba en un `_esperar`
	# que además de la cuenta miraba `lv.ended`, y eso perdía la bandera en el
	# caso más normal de todos: `eaten_ids` cuenta platos TERMINADOS, no
	# servidos, así que el último plato se estaba masticando cuando se acabó el
	# reloj del abordaje —o cuando al pirata se le agotó la paciencia— y el
	# guion salía por la puerta de atrás con la cuenta en N-1. Se le habían
	# servido los platos, pero el trato no se cumplía nunca.
	# Ahora el premio lo entrega `_on_pirata_come` en cuanto el plato baja, sin
	# preguntarle al nivel si sigue vivo. Lo único que se pierde si el turno se
	# cierra en ese instante es la escena de agradecimiento.
	_pirata_bandera = pirata
	if not pirata.plate_served.is_connected(_on_pirata_come):
		pirata.plate_served.connect(_on_pirata_come)
	# EL RETRATO ES EL DEL PIRATA QUE HAY SENTADO: si el spawner lo sacó
	# femenino, habla la pirata. Se compone con `DialogueBox.speaker_for`, nunca
	# a mano, para que no se pueda quedar desparejado del taburete.
	var quien := DialogueBox.speaker_for("pirata", str(pirata.gender))
	_focus_client(pirata)
	await _say([
		{ "text": "Eh, cocinero. Baja un momento.", "who": quien, "mood": "nervioso" },
		{ "text": "Mi capitán me manda a comer y vuelvo con el buche vacío... y esta noche me deja fregando la sentina.", "who": quien, "mood": "hablando" },
		{ "text": "Ponme **%d platos** y te doy mi **bandera**. La llevo desde el primer abordaje, pero prefiero cenar." % PLATOS_BANDERA,
			"who": quien, "mood": "serio" },
		{ "text": "¡%d PLATOS POR UN TRAPO! ¡RAAAK!" % PLATOS_BANDERA, "who": "gigi", "mood": "loro" },
		{ "text": "Ese trapo es un **coleccionable**, plumas. Tú sírvele, %s." % GameState.player_title(), "mood": "loro_resignado" },
	])
	_play("¡%d platos para el **pirata**! Lo demás ya vendrá." % PLATOS_BANDERA)

	# --- Se cumple el trato: la bandera en mano ---
	# LA SEÑAL SOLO APUNTA QUE LA CUENTA ESTÁ HECHA; QUIEN ENTREGA ES ESTE
	# GUION, Y DESPUÉS DE HABLAR. La ventana del coleccionable la saca
	# `GameState` en su capa global de avisos, así que entregándola desde la
	# señal se colaba ENCIMA del pirata antes de que le diera tiempo a decir
	# nada: primero salía el cartel del premio y después el "lo prometido".
	# El premio sigue sin depender de que al nivel le quede reloj: si el turno
	# se cierra con la cuenta hecha, se entrega igual (abajo), y lo único que
	# se pierde es la escena.
	await _esperar(func() -> bool: return lv.ended or _bandera_dada)
	if not _bandera_dada:
		return
	if not lv.ended and is_instance_valid(pirata):
		_focus_client(pirata)
		await _say([
			{ "text": "Uf. Hacía años que no comía así.", "who": quien, "mood": "feliz" },
			{ "text": "Lo prometido. Cuídala mejor que yo.", "who": quien, "mood": "hablando" },
		])
		_play()
		await _pausa(0.4)
	_entregar_bandera()
	if lv.ended:
		return
	# DAVID ESPERA A QUE SE CIERRE LA VENTANA DEL COLECCIONABLE. La saca
	# `GameState` en su capa global de avisos, que va por encima de todo: si
	# David arrancaba a hablar en el mismo momento, la caja de diálogo salía
	# debajo del cartel de la bandera y las dos cosas se pisaban.
	await _esperar(func() -> bool:
		return lv.ended or not GameState.notices_busy())
	if lv.ended:
		return
	await _pausa(0.35)
	await _explicar_coleccionables()
	_play()


## Entrega DE VERDAD el coleccionable (una sola vez, se llame desde donde se
## llame). Separado de la cuenta a propósito: ver `_on_pirata_come`.
func _entregar_bandera() -> void:
	if _bandera_entregada:
		return
	_bandera_entregada = true
	GameState.unlock_collectible("bandera")


## Cada plato que se termina EL pirata del nivel 7. Cumplida la cuenta, la
## bandera se entrega AQUÍ MISMO y no en el guion: así el premio no depende de
## que al nivel le quede reloj ni de que al pirata le quede paciencia. La
## ventana del coleccionable la saca `GameState` en su capa global de avisos,
## que sobrevive incluso al cartel de resultados.
func _on_pirata_come(_precio: int, _propina: int) -> void:
	if _bandera_dada or _pirata_bandera == null \
			or not is_instance_valid(_pirata_bandera):
		return
	if _pirata_bandera.eaten_ids.size() < PLATOS_BANDERA:
		return
	# AQUÍ SOLO SE APUNTA QUE LA CUENTA ESTÁ HECHA. La entrega (y con ella la
	# ventana del coleccionable) la hace el guion cuando el pirata ha terminado
	# de hablar; ver `_entregar_bandera`.
	_bandera_dada = true


# ------------------------------------------------------------------- nivel 8
# ISLA DE GADES: aquí espera CAI, el pirata-pescador japonés. Habla poco y mal
# —solo sabe japonés— así que sus líneas son cortas, con fallos, y a veces son
# un "..." (para eso tiene su expresión `callado`). Si el jugador lo sacia, se
# une a la tripulación y trae consigo la PESCA.

## Platos que hay que servirle a Cai para llenarle la barriga.
const PLATOS_CAI := 3

var _cai: Node3D = null
var _cai_lleno := false


func _nivel_8() -> void:
	await _say([
		{ "text": "**Isla de Gades**. Poca cosa: una playa, cuatro barcas... y ese de ahí, que lleva un rato mirando nuestra cinta.", "mood": "hablando" },
		{ "text": "...", "who": "cai", "mood": "callado" },
		{ "text": "Ni saluda. Habrá que echarle de comer a ver si suelta algo.", "mood": "mira_loro" },
		{ "text": "Un pescador. De los que comen pescado todos los días y nunca lo prueban bien hecho.", "mood": "serio" },
		{ "text": "¡PUES QUE SE SIENTE! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
		{ "text": "En eso estamos. Llénale la barriga, %s, que un pescador agradecido vale más que un cofre." % GameState.player_title(), "mood": "hablando" },
	])
	_play()
	_vigilar_basura()
	await _tras_la_preparacion()

	# --- CAI SE SIENTA. Es el primer pirata del puerto y trae su propio modelo
	#     (`special_client`), así que hay que esperar a que llegue a la barra.
	#     Y lo primero que dice no es nada: es su "..." —habla poco y mal— y
	#     por eso David tiene que romper el hielo por él.
	await _esperar(func() -> bool:
		return lv.ended or _cliente_who("cai") != null)
	if lv.ended:
		return
	_cai = _cliente_who("cai")
	if _cai == null:
		return
	await _pausa(1.2)
	if not is_instance_valid(_cai) or lv.ended:
		return
	if not _cai.plate_served.is_connected(_on_cai_come):
		_cai.plate_served.connect(_on_cai_come)
	_focus_client(_cai)
	await _say([
		{ "text": "...", "who": "cai", "mood": "callado" },
		{ "text": "Ehm. Buenas tardes. ¿Vienes a comer?", "mood": "sorprendido" },
		{ "text": "Me llamo Cai. Pescador. Mucho pescado, poca comida buena.", "who": "cai", "mood": "serio" },
		{ "text": "Tú cocinas. Si yo lleno... yo doy caña. Caña buena. Mi caña.", "who": "cai", "mood": "hablando" },
		{ "text": "¡RAAAK! ¡¿UNA CAÑA?! ¡Le damos de comer y nos da un PALO!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Cállate, plumas. Un pescador no regala su caña a cualquiera. **%d platos**, y a ver qué saca." % PLATOS_CAI, "mood": "loro_resignado" },
	])
	_play("¡**%d platos** para el pescador! Come de **dos estrellas**." % PLATOS_CAI)

	# --- Barriga llena: lo dice él, y el resto se cierra ya en el mapa ---
	await _esperar(func() -> bool: return lv.ended or _cai_lleno)
	if lv.ended or not _cai_lleno or not is_instance_valid(_cai):
		return
	_focus_client(_cai)
	await _say([
		{ "text": "...", "who": "cai", "mood": "callado" },
		{ "text": "Bueno. Muy bueno. Yo no como así nunca.", "who": "cai", "mood": "feliz" },
		{ "text": "Cuando acabes, hablamos tú y yo.", "who": "cai", "mood": "hablando" },
	])
	_play()


## Cada plato que termina Cai. `GameState.cai_saciado` se guarda porque el
## trato se cierra DESPUÉS, ya en el mapa (`main_menu._presentar_cai`): sin
## esto, quien le diera de comer y cerrase el turno con el objetivo llegaría al
## mapa y Cai le hablaría de una barriga que nadie le ha llenado.
func _on_cai_come(_precio: int, _propina: int) -> void:
	if _cai_lleno or _cai == null or not is_instance_valid(_cai):
		return
	if _cai.eaten_ids.size() < PLATOS_CAI:
		return
	_cai_lleno = true
	GameState.cai_saciado = true
	GameState.save_game()


## El cliente del puerto que lleva ese modelo especial (Cai, Pablo, el Kappa).
func _cliente_who(quien: String) -> Node3D:
	for c in lv.seat_clients:
		if c is Node3D and is_instance_valid(c) and c.who_override == quien:
			return c
	return null


# ------------------------------------------------------------------- nivel 9
# Puerto Tormenta: LOS BONIFICADORES. David los explica antes de cocinar y
# regala el del PALADAR, el único que se puede ganar todavía; el foco obliga a
# ponérselo antes de zarpar (lo hace `prep_screen`, ver `prep_dialog`).

func _nivel_9() -> void:
	await _say([
		{ "text": "**Puerto Tormenta**. Diez bocas en dos oleadas, y la mitad son **piratas**: sin platos de dos estrellas aquí no se come.", "mood": "serio" },
		# NADA DE BONIFICADORES AQUÍ (pedido por el usuario, no re-litigar): el
		# sistema entero llega con ALICE, en el escenario 17. Este puerto tuvo
		# la lección del "paladar de capitán" y sonaba a hablar de algo que el
		# jugador no tiene ni puede conseguir todavía.
		{ "text": "Sin lección hoy: esto es el examen. Enséñame lo que has aprendido.", "mood": "serio" },
	])
	_play()
	_vigilar_basura()


# ------------------------------------------------------------------- nivel 10
# Flota de Pablo el Rubio: los primeros CAPITANES, el tsuke don y el CORTE
# LENTO. Al cerrar, Pablo paga la broma con dos lingotes y David los explica.

const RECETA_PABLO := "salmon_tsuke_don"
const AVISO_TSUKE := "¡El **tsuke don**! ¡Córtalo DESPACIO y que se lo pongas al de las gafas!"

var _tsuke_servido := false
var _ensenando_corte := false
var _regano_corte := false


func _nivel_10() -> void:
	await _say([
		{ "text": "Eso de ahí enfrente no es un puerto, %s: es la **flota de Pablo el Rubio**." % GameState.player_title(), "mood": "hablando" },
		{ "text": "¡PIRATAS! ¡NOS ABORDAN! ¡ESCONDED EL ARROZ! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
		{ "text": "¡**David Jones**! ¡Cuánto bueno por estas aguas!", "who": "pablo", "mood": "feliz" },
		{ "text": "¡Pablo! Te presento a mi cocinero. Guarda eso an...", "mood": "hablando" },
		{ "text": "¡ZAS! ¡Te pillé! Que es de broma, hombre. **Casi** siempre.", "who": "pablo", "mood": "punal" },
		{ "text": "Hace la misma gracia desde hace quince años. Tú a lo tuyo: poco tiempo y **tres recetas**, así que suelta platos sin parar.", "mood": "loro_resignado" },
	])
	_play()
	await _tras_la_preparacion()

	# Pablo entra el ÚLTIMO de la primera tanda; si el jugador va sobrado, se
	# adelanta para que dé tiempo a estrenar su receta con él.
	await _esperar(func() -> bool:
		return lv.ended or _pablo() != null or _progreso() >= AVISO_PABLO)
	if lv.ended:
		return
	if _pablo() == null:
		_adelantar_tipo("G")
		await _esperar(func() -> bool: return lv.ended or _pablo() != null)
	if lv.ended:
		return
	var pablo := _pablo()
	# Un momento para verlo sentarse antes de que nadie hable.
	await _pausa(1.4)
	if pablo != null and is_instance_valid(pablo):
		_focus_client(pablo)
	await _say([
		{ "text": "¡Qué barco tan mono tenéis! Se ve pequeñito desde el mío.", "who": "pablo", "mood": "guason" },
		{ "text": "Ese es un **CAPITÁN**, %s: el paladar más fino que hay. Come de **tres estrellas** o no come." % GameState.player_title(), "mood": "hablando" },
	])

	# El regalo: el tsuke don, y con él el CORTE LENTO.
	_regalar_receta(RECETA_PABLO)
	await _focus_node(lv.prep_board.buttons[RECETA_PABLO], 12.0)
	await _say_raised([
		{ "text": "Para eso te traigo el **salmón tsuke don**. Tres estrellas, guardado para una ocasión así.", "mood": "feliz" },
		{ "text": "Trae un gesto nuevo: el **corte lento**. De izquierda a derecha, SIN prisa, hasta llenar la barra. Correr destroza el lomo.", "mood": "serio" },
		{ "text": "Hoy, si te sale mal, no te cuesta oro: estás aprendiendo.", "mood": "riendo" },
	])
	# Mientras aprende el corte, equivocarse sale gratis (pero Gigi regaña).
	_ensenando_corte = true
	lv.prep_board.free_mistakes = true
	if not lv.prep_board.slice_failed.is_connected(_on_corte_fallado):
		lv.prep_board.slice_failed.connect(_on_corte_fallado)
	if not lv.prep_board.dish_served.is_connected(_on_plato_servido):
		lv.prep_board.dish_served.connect(_on_plato_servido)
	_play(AVISO_TSUKE)

	await _esperar(func() -> bool: return lv.ended or _tsuke_servido)
	_ensenando_corte = false
	lv.prep_board.free_mistakes = false
	if lv.ended or not _tsuke_servido:
		return
	await _say([
		{ "text": "¡Vaya, vaya! Esto no me lo esperaba en un barco de este tamaño.", "who": "pablo", "mood": "sorprendido" },
		{ "text": "¿Lo ves? Te lo dije: el chico vale. Y ojo desde ahora: el corte con prisa SÍ cuesta oro.", "mood": "riendo" },
	])
	_play()

	# --- Al cerrar el turno: Pablo se despide y PROMETE la paga ---
	# LOS LINGOTES NO SE ENTREGAN AQUÍ. La entrega y la explicación de David
	# ocurren EN EL MAPA (`main_menu._pagar_pablo`), que es donde están a la
	# vista las tres cajas —lingotes, doblones y arroz— y donde señalar el
	# contador significa algo. Dentro del nivel no hay ninguna de las tres, así
	# que "los tienes arriba del todo, con su botón +" se decía sobre una
	# pantalla en la que no había nada que mirar.
	await _esperar(func() -> bool: return lv.ended)
	var aprobado: bool = lv.star_money.size() > 1 \
			and lv._star_money() >= int(lv.star_money[1])
	if aprobado and not GameState.ingots_intro_done:
		GameState.pending_ingots = LINGOTES_PABLO
		GameState.save_game()
		await _say([
			{ "text": "Se acabó el pescado. Y yo pago lo que como, David: esto vale bastante más que unas monedas.", "who": "pablo", "mood": "feliz" },
			{ "text": "¡QUE SUELTE YA! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
			{ "text": "Ya te lo dará cuando volvamos a bordo, plumas. Tú, %s, vete recogiendo." % GameState.player_title(), "mood": "loro_resignado" },
		])
	dialog.close()
	_clear_focus()


## Lingotes con los que Pablo paga la broma del puñal al cerrar su nivel.
const LINGOTES_PABLO := 2


## Gigi regaña la PRIMERA vez que el corte sale demasiado rápido.
func _on_corte_fallado() -> void:
	if not _ensenando_corte or _regano_corte or dialog.is_talking():
		return
	_regano_corte = true
	await _say([
		{ "text": "¡DEMASIADO RÁPIDO! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
		{ "text": "De **izquierda a derecha** y **sin correr**: cruza la tabla entera hasta que la barra se llene.", "who": "gigi", "mood": "loro" },
	])
	_play(AVISO_TSUKE)


func _on_plato_servido(recipe_id: String, _precio: int, _extras: Array,
		_nivel: int, _comer: float = 0.0) -> void:
	if recipe_id == RECETA_PABLO:
		_tsuke_servido = true
	if recipe_id == RECETA_RAPIDA:
		_futomaki_servido = true


## El cliente especial del puerto (Pablo el Rubio), si ya está en la barra.
func _pablo() -> Node3D:
	for c in lv.seat_clients:
		if c is Node3D and is_instance_valid(c) and c.who_override == "pablo":
			return c
	return null


# ------------------------------------------------------------------- nivel 11
# Cala del Hambre: tres bocas que mastican al doble de velocidad. El capitán
# pide tsuke don, que es la receta MÁS LENTA de la carta, y ahí está la lección:
# a veces no gana el plato que más paga, sino el que sale a tiempo.

const RECETA_RAPIDA := "futomaki_salmon"

var _futomaki_servido := false


func _nivel_11() -> void:
	await _say([
		{ "text": "**Cala del Hambre**. Solo tres clientes... pero fíjate en cómo mastican.", "mood": "hablando" },
		{ "text": "¡SE LO TRAGAN TODO! ¡RAAAK! ¡NO LES DA TIEMPO NI A SABOREARLO!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Aquí el **bocado** dura la mitad, así que vuelven a pedir enseguida. Sirve rápido o se te acumulan.", "mood": "serio" },
	])
	_play()
	_vigilar_basura()
	await _tras_la_preparacion()

	# --- El capitán se come su primer tsuke don → el futomaki ---
	await _esperar(func() -> bool:
		return lv.ended or _alguien_comio(RECETA_PABLO))
	if lv.ended:
		return
	await _pausa(0.6)
	await _say([
		{ "text": "¿Has visto lo que ha costado ese plato? El **tsuke don** paga como ninguno... pero se prepara despacio.", "mood": "serio" },
		{ "text": "Y con clientes así, un plato lento es un cliente vacío esperando. Hace falta algo que salga **rápido** y llene.", "mood": "hablando" },
	])
	_regalar_receta(RECETA_RAPIDA)
	await _focus_node(lv.prep_board.buttons[RECETA_RAPIDA], 12.0)
	await _say_raised([
		{ "text": "El **futomaki de salmón**: tres estrellas y **maestría**. Lo haces una vez y salen tres piezas.", "mood": "feliz" },
		{ "text": "Esa es la jugada: un plato caro para el capitán y un rollo rápido para tapar los huecos.", "mood": "riendo" },
	])
	if not lv.prep_board.dish_served.is_connected(_on_plato_servido):
		lv.prep_board.dish_served.connect(_on_plato_servido)
	_play("¡El **futomaki**! Tres piezas de una tacada.")


# ------------------------------------------------------------------- nivel 12
# Ensenada del Naufragio: hay clientes que no pagan en oro. El capitán del
# puerto lleva encima un COLECCIONABLE y lo suelta si se le sirve bien
# (`collectible_client` del puerto, que lo entrega solo en level3d).

# ------------------------------------------------------------------- nivel 13
# Rada de los Dos Fuegos: el AYUDANTE DE COCINA. Aquí se presenta y desde aquí
# se puede ganar (`unlocks_perk` del puerto).

## EL CLIENTE DEL TESORO ANUNCIA SU ENCARGO. Vigila hasta que se sienta y
## entonces le pone el FOCO encima y David canta lo que pide, tal cual lo dice
## `CampaignData.reto_texto`. Sin esto, la pieza salia sola al cumplir una
## condicion que nadie habia dicho en voz alta, y eso no es un reto: es un
## premio por casualidad.
##
## No bloquea: se lanza y se queda mirando, como `_vigilar_basura`.
func _vigilar_tesoro() -> void:
	if lv == null or lv.collectible_client.is_empty():
		return
	var cfg: Dictionary = lv.collectible_client
	while not lv.ended and is_inside_tree():
		await get_tree().process_frame
		if lv.treasure_client == null or not is_instance_valid(lv.treasure_client):
			continue
		if not lv.treasure_client in lv.seat_clients:
			continue
		if dialog.is_talking():
			continue
		break
	if lv == null or not is_instance_valid(lv) or lv.ended:
		return
	await _pausa(0.9)
	if lv.ended or lv.treasure_client == null 			or not is_instance_valid(lv.treasure_client):
		return
	var quien := DialogueBox.speaker_for(
		str(lv.treasure_client.client_type), str(lv.treasure_client.gender))
	_focus_client(lv.treasure_client)
	# EL ENCARGO LO CANTA EL PROPIO CLIENTE (decidido por el usuario): David no
	# anuncia su presencia. Solo interviene después, y únicamente cuando el
	# encargo es una RECETA CONCRETA que hoy no va en la carta — para decir que
	# se puede volver otro día con ella, que sin esa frase el tesoro parecería
	# perdido para siempre.
	var lineas: Array = [
		{ "text": "Tú. Cocinero. Yo no pago con oro: pago con esto.", "who": quien, "mood": "serio" },
		{ "text": "Y solo lo suelto si me cumples el capricho: %s. Si no, me lo llevo por donde he venido." % CampaignData.reto_texto(cfg), "who": quien, "mood": "hablando" },
	]
	var falta_receta := str(cfg.get("reto", "")) == "receta" 			and not str(cfg.get("recipe", "")) in GameState.selected_recipes
	if falta_receta:
		var nombre := str(RecipeData.RECIPES.get(str(cfg.get("recipe", "")), {})
				.get("name", cfg.get("recipe", "")))
		lineas.append({ "text": "¿**%s**? Hoy no lo llevamos en la carta, %s..." % [nombre, GameState.player_title()], "mood": "sorprendido" })
		lineas.append({ "text": "Apúntatelo: cuando lo tengas, **vuelve aquí con él en la carta**. Este no parece de los que cambian de antojo.", "mood": "hablando" })
	await _say(lineas)
	_play("Encargo: **%s**." % CampaignData.reto_texto(cfg))


## EL HÁNDICAP DEL TIPO DE ESCENARIO, una vez por tipo en toda la partida:
## PUERTO = tres clientes que se van sin comer pierden la jornada (con el foco
## en su contador); ABORDAJE = cada vacío roba 15 segundos de reloj (con el
## foco en el reloj). En los dos, el vacío ya no cuesta oro — se dice aquí para
## que el jugador no crea que se ha librado del castigo.
func _explicar_handicap() -> void:
	if GameState.is_tutorial() or lv == null:
		return
	var kind := CampaignData.get_kind(GameState.current_port)
	if kind == "puerto" and not GameState.puerto_handicap_done:
		GameState.puerto_handicap_done = true
		GameState.save_game()
		await _say([
			{ "text": "Una cosa antes de abrir, %s. Esto no es una isla: es un **puerto**." % GameState.player_title(), "mood": "serio" },
			{ "text": "Aquí entra mucha más gente, y las recetas las eliges **tú**. Pero en los puertos manda la fama.", "mood": "hablando" },
		])
		if lv.vacios_puerto_label != null and is_instance_valid(lv.vacios_puerto_label):
			_focus_node(lv.vacios_puerto_label, 14.0)
		await _say([
			{ "text": "Si **tres clientes** se marchan sin probar bocado, se corre la voz y la jornada se **pierde entera**. Ese contador de ahí lleva la cuenta.", "mood": "hablando" },
			{ "text": "¡NI UNO CON LA BARRIGA VACÍA! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
			{ "text": "A cambio, el que se vaya no te cuesta oro: aquí el castigo es la fama, no el bolsillo.", "mood": "loro_resignado" },
		])
		_play()
	elif kind == "abordaje" and not GameState.abordaje_handicap_done:
		GameState.abordaje_handicap_done = true
		GameState.save_game()
		await _say([
			{ "text": "Esto es un **abordaje**, %s: se asalta un barco y se cocina en su cubierta." % GameState.player_title(), "mood": "serio" },
			{ "text": "Aquí la clientela no se acaba nunca, así que no manda ella: manda el **reloj**.", "mood": "hablando" },
		])
		var reloj := lv.get_node_or_null("HUD/TopRow/TimeBox")
		if reloj is Control:
			_focus_node(reloj, 14.0)
		await _say([
			{ "text": "Y ojo: cada cliente que se marche **sin comer** nos roba **15 segundos** de ese reloj. En un turno de dos minutos y medio, tres vacíos son casi un tercio del botín.", "mood": "hablando" },
			{ "text": "¡QUE COMAN TODOS! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
			{ "text": "Lo bueno: el que se vaya no te cuesta oro. El reloj ya duele bastante.", "mood": "loro_resignado" },
		])
		_play()


## LOS CONTADORES DE MAESTRÍA del HUD, explicados UNA vez en toda la partida.
## Se llama al principio de todo guion y no hace nada si no toca: si el jugador
## no lleva ninguna habilidad de "cada N platos", si ya se le explico, o si es
## el tutorial (ahi todo va en neutro).
func _explicar_contadores() -> void:
	if GameState.skill_counters_intro_done or GameState.is_tutorial():
		return
	if lv == null or lv.skill_counter_row == null:
		return
	GameState.skill_counters_intro_done = true
	GameState.save_game()
	await _pausa(0.8)
	if lv == null or not is_instance_valid(lv) or lv.ended:
		return
	# El foco va DESPUES de `_play`, que llama a `_clear_focus`.
	await _say([
		{ "text": "Un momento antes de empezar. Eso de ahí arriba es nuevo.", "mood": "hablando" },
	])
	_focus_node(lv.skill_counter_row, 16.0)
	await _say([
		{ "text": "Tus **maestrías** de cocinero no van a suerte: van a **cuenta**. Cada una te avisa de cuántos platos faltan para su premio.", "mood": "serio" },
		{ "text": "Cuando una llega a cero, el **siguiente plato que hagas a mano** se lleva lo suyo. Tú decides cuál.", "mood": "feliz" },
		{ "text": "¡PUES MIRA EL NUMERITO, GRUMETE! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
	])
	_play()


## Platos que hay que servirle a ALICE para que se enrole.
const PLATOS_ALICE := 3

var _alice: Node3D = null
var _alice_llena := false


## RADA DE LOS DOS FUEGOS (escenario 17): llega ALICE. Se sienta de clienta, se
## le da de comer, y el trato se cierra DESPUES en el mapa
## (`main_menu._presentar_alice`), que es donde se enrola y donde se abren los
## BONIFICADORES. Aqui NO se explica ningun bonificador: todavia no existen.
func _nivel_13() -> void:
	await _say([
		{ "text": "**Rada de los Dos Fuegos**: abordaje, reloj corriendo y clientela que no se acaba. Lo de siempre... casi.", "mood": "serio" },
		{ "text": "Y una chica que lleva media hora en el muelle mirando la cinta sin sentarse.", "mood": "hablando" },
		{ "text": "¡PUES QUE MIRE DESDE OTRO LADO! ¡RAAAK! ¡ESTORBA!", "who": "gigi", "mood": "loro_grito" },
		{ "text": "O que se siente. Tú a lo tuyo, %s, que hoy hay faena." % GameState.player_title(), "mood": "loro_resignado" },
	])
	_play()
	_vigilar_basura()
	await _tras_la_preparacion()

	# --- ALICE SE SIENTA. Como Cai, lo primero que hace es no decir nada: es
	#     timida, y por eso David tiene que romper el hielo por ella.
	await _esperar(func() -> bool:
		return lv.ended or _cliente_who("alice") != null)
	if lv.ended:
		return
	_alice = _cliente_who("alice")
	if _alice == null:
		return
	await _pausa(1.2)
	if not is_instance_valid(_alice) or lv.ended:
		return
	if not _alice.plate_served.is_connected(_on_alice_come):
		_alice.plate_served.connect(_on_alice_come)
	_focus_client(_alice)
	await _say([
		{ "text": "...", "who": "alice", "mood": "callado" },
		{ "text": "Siéntate, muchacha, que no mordemos. ¿Buscas a alguien?", "mood": "hablando" },
		{ "text": "A mi maestra. Se llama **Miku**. Cocinaba... como nadie.", "who": "alice", "mood": "triste" },
		{ "text": "Llevo tres puertos preguntando. Nadie la ha visto.", "who": "alice", "mood": "serio" },
		{ "text": "¡PUES AQUÍ TAMPOCO! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
		{ "text": "Aquí lo que hay es comida. Come algo primero y luego hablamos, que con hambre no se busca a nadie.", "mood": "loro_resignado" },
		{ "text": "...Gracias.", "who": "alice", "mood": "callado" },
	])
	_play("¡**%d platos** para la chica del muelle!" % PLATOS_ALICE)

	# --- Barriga llena: lo dice ella, y el trato se cierra ya en el mapa ---
	await _esperar(func() -> bool: return lv.ended or _alice_llena)
	if lv.ended or not _alice_llena or not is_instance_valid(_alice):
		return
	_focus_client(_alice)
	await _say([
		{ "text": "Está muy bueno. De verdad.", "who": "alice", "mood": "feliz" },
		{ "text": "Yo también cocino. Un poco. Mi maestra decía que me falta mano, no cabeza.", "who": "alice", "mood": "hablando" },
		{ "text": "Mano se hace trabajando. Cuando cierres el turno, ven a verme.", "mood": "feliz" },
	])
	_play()


## Cada plato que termina Alice. `GameState.alice_saciada` se guarda porque la
## escena en la que se enrola ocurre DESPUES, en el mapa: sin esto, quien le
## diera de comer y cerrase por objetivo llegaria alli y ella hablaria de una
## comida que nadie recuerda. Mismo patron que Cai.
func _on_alice_come(_precio: int, _propina: int) -> void:
	if _alice_llena or _alice == null or not is_instance_valid(_alice):
		return
	if _alice.eaten_ids.size() < PLATOS_ALICE:
		return
	_alice_llena = true
	GameState.alice_saciada = true
	GameState.save_game()


# ------------------------------------------------------------------- nivel 14
# Muelle de las Bandejas: el BARCO COMBINADO. El puerto lo permite (`boat`) y
# aquí se gana su bonificador.

func _nivel_14() -> void:
	await _say([
		{ "text": "**Muelle de las Bandejas**. Aquí no se sirve plato a plato: se sirve por **bandejas**.", "mood": "feliz" },
		{ "text": "El **barco de sushi** junta cuatro platos que tengas guardados —de clases distintas— en una sola bandeja.", "mood": "hablando" },
		{ "text": "Y esa bandeja casi nadie la deja pasar: la cogen los tres paladares, paga lo que valen sus platos MÁS una prima por variedad...", "mood": "serio" },
		{ "text": "...y se come despacísimo, así que aparca al cliente un buen rato. Su botón está bajo las cajas.", "mood": "hablando" },
		{ "text": "¡BANDEJA! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Para ganártelo: ten **3 platos guardados en 2 cajas distintas** a la vez. Cocina de más, que hoy sobra clientela.", "mood": "riendo" },
	])
	_play()
	_vigilar_basura()


# ------------------------------------------------------------------- nivel 15
# Cueva del Kappa: el JEFE. Primero se da de comer a la tripulación; cuando
# hay suficientes barrigas llenas, el Kappa vacía la barra y empieza el duelo:
# BOSS_PLATES platos antes de que su paciencia (que corre deprisa) toque fondo.
# Esta coreografía corre TAMBIÉN en las repeticiones (en mudo): sin ella no
# habría jefe al que ganar.

func _nivel_15() -> void:
	await _decir([
		{ "text": "Estas aguas están demasiado tranquilas... Sirve y mantén los ojos abiertos.", "mood": "serio" },
		{ "text": "¡GLUB, GLUB! ¡ALGO BURBUJEA! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
	])
	_play()
	await _tras_la_preparacion()

	# Primera fase: alimentar a la tripulación (o el tiempo la corta).
	var t0: float = lv.elapsed
	await _esperar(func() -> bool:
		return lv.ended or _alimentados() >= KAPPA_FED \
				or lv.elapsed - t0 > KAPPA_TIME)
	if lv.ended:
		return

	# --- ENTRA EL JEFE ---
	# El reloj se para (manda la paciencia del Kappa), no llega nadie más y la
	# barra se vacía: el duelo es de uno contra uno.
	lv.timed = false
	lv._apply_hud_layout()
	lv.arrival_queue.clear()
	lv.type_queue.clear()
	lv.forced_types.clear()
	await _decir([
		{ "text": "¡EL MAR! ¡EL MAR SE ABRE! ¡RAAAAAK!", "who": "gigi", "mood": "loro_grito" },
		{ "text": "Lo sabía... ¡el **KAPPA**! ¡Todo el mundo fuera de la barra!", "mood": "gritando" },
	])
	for c in lv.seat_clients:
		if c is Node3D and is_instance_valid(c):
			c.force_leave(false)
	# El Kappa ocupa el mecanismo del cliente especial: modelo propio y su
	# cara en la fila de cabezas del HUD.
	lv.special_who = "kappa"
	lv.special_type = "G"
	lv.special_spawned = false
	lv.forced_types.append("G")
	lv._try_spawn_client()
	var kappa := _kappa()
	if kappa == null:
		# Red de seguridad: sin hueco libre no hay duelo (no debería pasar, la
		# barra se acaba de vaciar). Se reintenta cada fotograma.
		await _esperar(func() -> bool:
			lv.forced_types.append("G")
			return lv._try_spawn_client() and _kappa() != null)
		kappa = _kappa()
	kappa.make_boss()
	await _pausa(1.2)
	_focus_client(kappa)
	await _decir([
		{ "text": "Escúchame rápido: el Kappa come de TODO, a una velocidad de escándalo... y se **impacienta** igual de rápido.", "mood": "serio" },
		{ "text": "Tiene que comerse **%d platos** antes de que su paciencia toque fondo. Variedad, cajas llenas y cero pausas." % BOSS_PLATES, "mood": "hablando" },
		{ "text": "¡DALE DE COMER O NOS COME A NOSOTROS! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
	])
	# Marcador del duelo en la tablilla del nivel.
	lv._show_phase(true)
	lv.phase_label.text = "Kappa: 0/%d" % BOSS_PLATES
	kappa.plate_served.connect(func(_f: int, _t2: int) -> void:
		if is_instance_valid(kappa):
			lv.phase_label.text = "Kappa: %d/%d" \
					% [mini(kappa.eaten_ids.size(), BOSS_PLATES), BOSS_PLATES])
	_play("¡El **Kappa** espera! ¡Platos variados, sin parar!")

	# El duelo: o come BOSS_PLATES, o se harta y se va.
	await _esperar(func() -> bool:
		return lv.ended or not is_instance_valid(kappa) \
				or kappa.state == kappa.State.LEAVING \
				or kappa.state == kappa.State.DONE \
				or kappa.eaten_ids.size() >= BOSS_PLATES)
	if lv.ended:
		return
	if is_instance_valid(kappa) and kappa.eaten_ids.size() >= BOSS_PLATES:
		# --- VICTORIA ---
		lv.boss_done = true
		lv.goal_reached = true
		lv.phase_label.text = "¡Kappa rendido!"
		await _decir([
			{ "text": "¡GLUB! ¡GLUB-GLUB!", "who": "gigi", "mood": "loro_sorpresa" },
			{ "text": "¡Se rinde! ¡Barriga llena y de vuelta al fondo! ¡Eres el cocinero que las leyendas pedían, %s!" % GameState.player_title(), "mood": "riendo" },
		])
		if is_instance_valid(kappa):
			kappa.force_leave(false)
			if kappa.state != kappa.State.DONE:
				await kappa.finished
		lv._show_phase(false)
		lv._end_level()
		return
	# --- DERROTA: se hartó antes de tiempo ---
	lv._show_phase(false)
	await _decir([
		{ "text": "Se ha hartado... y un Kappa hambriento no paga. ¡Volveremos: ahora sabes cómo mastica!", "mood": "triste" },
		{ "text": "¡MÁS CAJAS! ¡MÁS VARIEDAD! ¡RAAAK!", "who": "gigi", "mood": "loro" },
	])
	lv._end_level()


## Clientes que han comido AL MENOS un plato en esta partida (sentados o idos).
func _alimentados() -> int:
	var n := 0
	for r in lv.client_reports:
		if not (r.get("eaten", []) as Array).is_empty():
			n += 1
	for c in lv.seat_clients:
		if c is Node3D and is_instance_valid(c) and not c.eaten_ids.is_empty():
			n += 1
	return n


## El jefe, si ya está en el nivel.
func _kappa() -> Node3D:
	for c in lv.seat_clients:
		if c is Node3D and is_instance_valid(c) and c.who_override == "kappa":
			return c
	return null
