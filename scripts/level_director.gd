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

## --- JEFE (Cueva del Kappa) ---
## Platos de la FASE 1 del duelo (el resto de constantes, junto al guion).
const BOSS_PLATES := 10

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
		"mar2_viento":
			await _mar2_viento()
		"mar2_sirena":
			await _mar2_sirena()
		"mar2_sirena_jefa":
			await _mar2_sirena_jefa()
		"mar2_despertar":
			await _mar2_despertar()
		"mar2_miku":
			await _mar2_miku()
		"mar2_nach":
			await _mar2_nach()
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
		"nivel_16":
			await _nivel_16()
		"nivel_17":
			await _nivel_17()
		"nivel_21":
			await _nivel_21()
		"nivel_22":
			await _nivel_22()
		_:
			# RED DE SEGURIDAD. Un `director` declarado en CampaignData SIN su
			# rama aquí no da ningún error: el match no casa, `_run` devuelve
			# sin llamar a `_play()` y `narrating` se queda en true para
			# siempre — así que `level3d._ask_start` se planta esperando su
			# tope de 90 s y el nivel NO ARRANCA (ni cartel de "¿Comenzamos?",
			# ni cuenta atrás, ni clientes). Pasó de verdad con los dos
			# escenarios nuevos del mar 1. Con esto, lo peor que puede ocurrir
			# es quedarse sin guion; el turno se juega igual y el aviso queda
			# en consola. `tools/auditar.gd` lo caza además antes de correr.
			push_warning("Guion declarado sin rama en _run(): %s" % guion)
			_play()


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
	var despreciado := { "plato": null, "sitio": Vector3.ZERO }
	var conexion := func(plato: Node3D) -> void:
		despreciado["plato"] = plato
		despreciado["sitio"] = plato.global_position
	lv.plato_ignorado.connect(conexion)
	await _esperar(func() -> bool:
		return lv.ended or despreciado["plato"] != null)
	if lv.plato_ignorado.is_connected(conexion):
		lv.plato_ignorado.disconnect(conexion)
	if lv.ended:
		return
	# EL DADO SE TIRA CUANDO EL PLATO ENTRA EN EL RADIO DEL CLIENTE, o sea
	# ANTES de que le pase por delante: hablando en ese instante, David contaba
	# algo que en pantalla todavía no había ocurrido (le pasó al usuario). Se
	# espera a que el plato termine de cruzar y SE ENFOCA DONDE ESTÁ ENTONCES,
	# no donde estaba al tirar el dado.
	await _pausa(DESPRECIO_ESPERA)
	if lv.ended:
		return
	var sitio: Vector3 = despreciado["sitio"]
	var plato: Node3D = despreciado["plato"]
	if plato != null and is_instance_valid(plato):
		sitio = plato.global_position
	_focus_screen_rect(Rect2(lv.cam.unproject_position(sitio) - Vector2(90, 90),
		Vector2(180, 180)))
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

## Lo que se deja al plato despreciado para que CRUCE por delante del cliente
## antes de que David lo cuente (a 1.35 u/s cubre de sobra el radio de toma).
const DESPRECIO_ESPERA := 1.5

## Platos que hay que tener guardados para que la lección de cajas dé el paso.
const CAJAS_PEDIDAS := 4
## Fracción de paciencia del primer cliente a la que entra el refuerzo si aún
## no ha llegado a su segundo plato.
const REFUERZO_PACIENCIA := 2.0 / 3.0
## CUÁNTO SUBE LA CAJA DE DIÁLOGO AL HABLAR DE LAS CAJAS. Las cajas viven en la
## tabla, entre la y 780 y la 968 del lienzo, y la caja de diálogo subida lo
## de siempre (330) sigue ocupando de la 544 a la 938: las tapaba de lleno
## mientras se explicaban (le pasó al usuario). MEDIDO en captura: con 470
## terminaba en la 798 y su marco todavía mordía los 18 px de arriba de las
## cajas; con 490 termina en la 778 y las deja enteras. El retrato de David
## pierde 70 px por arriba, que son el aire y el filo de su pañuelo.
const CAJAS_RAISE := 490.0

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
	# SUBIDA (`_say_raised`) Y MÁS QUE DE COSTUMBRE (`CAJAS_RAISE`): las cajas
	# viven abajo del todo y la caja de diálogo, a su altura de siempre, las
	# tapaba justo mientras se explican.
	await _say_raised([
		{ "text": "Estas dos **cajas** son tuyas desde hoy. Guardan platos ya hechos y los mantienen calientes hasta que tú digas.", "mood": "hablando" },
		{ "text": "Sirve para adelantar trabajo: cocinas cuando tienes hueco y sueltas cuando hace falta.", "mood": "serio" },
		{ "text": "¡CAJAS! ¡RAAAK!", "who": "gigi", "mood": "loro" },
		{ "text": "Y otra cosa: desde hoy la **despensa se gasta**. Cada receta que embarques consume un uso de sus ingredientes.", "mood": "serio" },
		{ "text": "Empieza tranquilo, que de momento solo hay una boca. Ya te avisaré yo cuando toque.", "mood": "hablando" },
	], -1.0, CAJAS_RAISE)
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
	await _say_raised([
		{ "text": "¡Ahora sí! Se nos llena la barra, y un plato en la cinta se lo queda **el primero que pase**, no el que tú quieras.", "mood": "sorprendido" },
		{ "text": "Aquí es donde las cajas valen su peso en oro: cocinas de antemano y los sueltas TODOS DE GOLPE, uno para cada boca.", "mood": "hablando" },
		{ "text": "Prepara **%d platos** y mételos en las cajas. Yo te espero: hoy nadie se me impacienta." % CAJAS_PEDIDAS, "mood": "serio" },
	], -1.0, CAJAS_RAISE)
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
	# (EL MARIDAJE YA NO SE ADELANTA AQUÍ: se enseña entero en el 12, y contado
	# dos veces el jugador oía la misma lección en dos escenarios seguidos —
	# le pasó al usuario.)
	_play("¡Súbele la chapa y despídelo con un **mochi**!")

	# --- El primer potenciador: la lección se da CON EL CARTEL DELANTE ---
	# (pedido por el usuario). Antes David hablaba en cuanto el bote cruzaba
	# el umbral —con la barra aún a medio pintar y sin cartel en pantalla—,
	# porque `powerups_claimed` sube en ese mismo instante y el cartel tarda
	# un respiro en salir. Ahora se espera al cartel, se enfoca, y se explica
	# encima de él con las tres cartas a la vista (`_say_sobre_cartel`, que ni
	# lo aplaza ni le quita la pausa). El jugador elige cuando David calla.
	await _esperar(func() -> bool:
		return lv.ended or lv.powerup_panel.visible)
	if lv.ended:
		return
	await _focus_node(lv.powerup_panel, 6.0)
	await _say_sobre_cartel([
		{ "text": "¡Bote lleno! Y ahí lo tienes: tres **potenciadores** a elegir. Coge UNO, y vale para el resto del turno.", "mood": "feliz" },
		{ "text": "El sorteo cambia cada vez que se llena el bote, así que gástalos sin pena. Elige.", "mood": "hablando" },
	])
	_play()


# ------------------------------------------------------- los tres EXTRAS
# LOS EXTRAS YA NO LLEGAN LOS TRES DE GOLPE (pedido por el usuario): cada uno
# tiene SU escenario —el 15 el wasabi, el 16 el jengibre y el 17 la soja—, y
# esos tres NO llevan práctica detrás porque cada uno YA es su práctica.
#
# Antes era una sola jornada con Saverio soltando los tres seguidos: cuatro
# frases con tres reglas distintas, y al salir el jugador tenía tres botones
# nuevos sin haber usado ninguno. Ahora entra uno por jornada y hay un turno
# entero para gastarlo.
#
# LA PLANTILLA ES COMÚN (`_escena_extra`) y lo único que cambia es quién habla
# y qué se dice: los tres regalan `TUTORIAL_GIFT` usos SOLO la primera vez
# (repetir el escenario vuelve a correr el guion, porque el puerto no queda
# narrado hasta aprobarlo, y sin la guarda se rellenaría la despensa en cada
# intento).

## El armazón de las tres jornadas: esconde el extra, lo presenta, lo enciende,
## lo enfoca y devuelve el turno. `intro` son las líneas de antes de sacarlo y
## `detalle` las de después, con el botón ya en la mesa.
func _escena_extra(id: String, intro: Array, detalle: Array, aviso: String) -> void:
	var pb: Control = lv.prep_board
	await _say(intro)
	var primera := GameState.unlock_extra(id)
	if primera:
		GameState.add_ingredient_uses(id, GameState.TUTORIAL_GIFT)
		GameState.save_game()
	# HAY QUE BAJAR `hide_extras` A MANO. level3d lo fijó al montar el nivel
	# mirando `extras_unlocked()`, que en la jornada del WASABI todavía era
	# false: sin esto, la esquina de la tabla seguiría apagada justo después
	# de que Saverio saque el primero.
	pb.hide_extras = false
	pb.refresh_extra_ui()
	# Los botones son hijos sueltos del panel de la mesa (no hay fila que
	# enfocar), así que se enfoca el suyo directamente.
	if pb.extra_buttons.has(id):
		await _focus_node(pb.extra_buttons[id], 16.0)
	await _say(detalle)
	_play(aviso)
	_vigilar_basura()


# ------------------------------------------------------------------- nivel 6
# Bahía del Kraken (escenario 15): EL WASABI, y con él el sistema de extras.

func _nivel_6() -> void:
	await _escena_extra("wasabi", [
		{ "text": "**Bahía del Kraken**. Traigo compañía, %s." % GameState.player_title(), "mood": "hablando" },
		{ "text": "¡Cocinero! Vengo a enseñarte lo que llevo en el fondo de la caja.", "who": "saverio", "mood": "feliz" },
		{ "text": "Los **extras**. Van sobre el plato YA TERMINADO, en la esquina de la tabla, y hacen una cosa que no hace nada más:", "who": "saverio", "mood": "explicando" },
		{ "text": "con un extra encima, un plato **repetido cuenta como nuevo**. No rompe la chapa: la sube.", "who": "saverio", "mood": "hablando" },
		{ "text": "Hoy te dejo el primero, y de uno en uno, que si te suelto los tres no te acuerdas de ninguno.", "who": "saverio", "mood": "feliz" },
	], [
		{ "text": "El **wasabi**. Sube la **probabilidad** de propina, pero en vez de dar paciencia la **quita**: no se lo pongas al que va justo.", "who": "saverio", "mood": "explicando" },
		{ "text": "Diez usos, invita la casa. Gástalos hoy, %s: para eso te los doy." % GameState.player_title(), "who": "saverio", "mood": "hablando" },
	], "Prueba el **wasabi** en un plato que ya le hayas servido a alguien.")


# ------------------------------------------------------------------ nivel 21
# Rada del Paladar Limpio (escenario 16): EL JENGIBRE.

func _nivel_21() -> void:
	await _escena_extra("jengibre", [
		{ "text": "**Rada del Paladar Limpio**. Y Saverio otra vez en el muelle, con la caja abierta.", "mood": "hablando" },
		{ "text": "El de hoy es el más raro de los tres, así que escucha con las dos orejas.", "who": "saverio", "mood": "explicando" },
	], [
		{ "text": "El **jengibre** le **borra el paladar**: todo lo que ese cliente haya probado vuelve a contar como nuevo. Ese plato incluido.", "who": "saverio", "mood": "explicando" },
		{ "text": "Se paga con **un punto de chapa**. Pierdes uno y recuperas la carta entera: cuando alguien ya lo ha probado todo, es la única salida.", "who": "saverio", "mood": "hablando" },
		{ "text": "¡EL DE LA CHAPA! ¡ESE ES BUENO! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
	], "Gástale el **jengibre** a alguien que ya lo haya probado todo.")


# ------------------------------------------------------------------ nivel 22
# Ensenada de la Salazón (escenario 17): LA SOJA, y con ella los tres.

func _nivel_22() -> void:
	await _escena_extra("soja", [
		{ "text": "**Ensenada de la Salazón**. Última entrega, y ya tienes la caja entera.", "mood": "hablando" },
		{ "text": "La que faltaba, cocinero. Y esta tiene truco.", "who": "saverio", "mood": "feliz" },
	], [
		{ "text": "La **soja** engorda la propina: cuando cae, cae más gorda. Pero el que la lleva **mastica más deprisa**...", "who": "saverio", "mood": "explicando" },
		{ "text": "...y mientras se mastica la paciencia no baja, así que acortarle el bocado es devolverlo a la cola antes de tiempo. Tú verás.", "who": "saverio", "mood": "hablando" },
		{ "text": "Los tres son tu as en la manga cuando a un cliente ya no le quedan platos nuevos. Y los tres se compran en mi puesto.", "who": "saverio", "mood": "feliz" },
	], "Prueba la **soja** y fíjate en lo rápido que se lo termina.")


# ------------------------------------------------------------------- nivel 7
# Estrecho del Rayo (ESCENARIO 14): el primer ABORDAJE (reloj y clientela sin
# fin) y los primeros PIRATAS del juego. Los capitanes NO salen aquí: llegan
# con Pablo, en el 23. El pirata es el TERCER cliente (`client_order` del
# puerto), así que no hay que adelantar a nadie: solo esperar a que se siente.
#
# LA BANDERA PIRATA YA NO SE GANA AQUÍ (pedido por el usuario): el 14 presenta
# a los piratas y es en el 15, la práctica del abordaje, donde sube EL pirata
# que paga con su bandera. Aquel trato tenía guion propio en este nivel (la
# cuenta por señal, la entrega después de hablar); hoy va por el mecanismo
# general del cliente del tesoro (`_vigilar_tesoro`), que hace exactamente
# eso para cualquier escenario.

## QUÉ SON LOS COLECCIONABLES. Se cuenta UNA sola vez en toda la partida y
## SIEMPRE con una pieza recién ganada en la mano (`col_intro_done`): la bandera
## del pirata del 15, el tricornio del capitán del 27 o el primer cofre de la
## pesca, lo que llegue antes. Soltado a palo seco al empezar un puerto sonaba
## a folleto; con la pieza delante se explica solo.
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
	# UNA LÍNEA QUE PRESENTE EL SITIO antes de soltar la mecánica (pedido por
	# el usuario): entrar explicando el reloj era demasiado directo.
	await _say([
		{ "text": "**Estrecho del Rayo**. Hoy no atracamos en ningún puerto, %s: hoy **abordamos**." % GameState.player_title(), "mood": "serio" },
		{ "text": "Nos plantamos en la cubierta de otro barco, montamos la cocina y damos de comer a su tripulación antes de que se den cuenta.", "mood": "hablando" },
		{ "text": "Y de ahí lo importante: en un abordaje hay **prisa**. Mira ese reloj.", "mood": "serio" },
	])
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
		{ "text": "El **futomaki de salmón**: tres estrellas y con **usos extra**. Lo haces una vez y salen tres piezas.", "mood": "feliz" },
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
var _tesoro_cantado := false


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
	if lv.ended or lv.treasure_client == null \
			or not is_instance_valid(lv.treasure_client):
		return
	var quien := DialogueBox.speaker_for(
		str(lv.treasure_client.client_type), str(lv.treasure_client.gender))
	_focus_client(lv.treasure_client)
	# EL ENCARGO LO CANTA EL PROPIO CLIENTE (decidido por el usuario): David no
	# anuncia su presencia. Solo interviene después, y únicamente cuando el
	# encargo es una RECETA CONCRETA que hoy no va en la carta — para decir que
	# se puede volver otro día con ella, que sin esa frase el tesoro parecería
	# perdido para siempre.
	# Y DICE CON QUÉ PAGA (pedido por el usuario): "pago con esto" a secas no
	# decía nada. La frase sale de `CampaignData.pago_texto`, la misma que
	# luego lee la ficha del mapa.
	var lineas: Array = [
		{ "text": "Tú. Cocinero. Yo no pago con oro. Pago con esto: %s." % CampaignData.pago_texto(cfg), "who": quien, "mood": "serio" },
		{ "text": "Y solo lo suelto si me cumples el capricho: %s. Si no, me lo llevo por donde he venido." % CampaignData.reto_texto(cfg, true), "who": quien, "mood": "hablando" },
	]
	var receta := str(cfg.get("recipe", ""))
	var falta_receta: bool = str(cfg.get("reto", "")) in ["receta", "receta_n"] \
			and not receta in GameState.selected_recipes \
			and not lv.prep_board.buttons.has(receta)
	if falta_receta:
		var nombre := str(RecipeData.RECIPES.get(receta, {}).get("name", receta))
		lineas.append({ "text": "¿**%s**? Hoy no lo llevamos en la carta, %s..." % [nombre, GameState.player_title()], "mood": "sorprendido" })
		lineas.append({ "text": "Apúntatelo: cuando lo tengas, **vuelve aquí con él en la carta**. Este no parece de los que cambian de antojo.", "mood": "hablando" })
	await _say(lineas)
	_play("Encargo: **%s**." % CampaignData.reto_texto(cfg))
	# Bandera para los guiones que tienen algo que decir DESPUES del encargo
	# (el del mapa del tesoro): hablar encima del cliente le pisaria su escena.
	_tesoro_cantado = true

	# --- SE CUMPLE EL TRATO: LO ENTREGA ÉL, HABLANDO (pedido por el usuario)
	# La cuenta la lleva level3d (`treasure_ready`, que se enciende al plato
	# que cierra el encargo) y la ENTREGA es de este guion, después de que el
	# cliente diga lo suyo: si la hiciera level3d, la ventana del premio
	# saltaría antes de que abriera la boca. Si el turno se cierra con la
	# cuenta hecha, `_end_level` entrega igual y solo se pierde la escena.
	await _esperar(func() -> bool: return lv.ended or lv.treasure_ready)
	if lv.ended or not lv.treasure_ready:
		return
	if is_instance_valid(lv.treasure_client) and lv.treasure_client in lv.seat_clients:
		_focus_client(lv.treasure_client)
		await _say([
			{ "text": "Mmm. Trato es trato.", "who": quien, "mood": "feliz" },
			{ "text": "Toma: %s. Bien ganado." % CampaignData.pago_texto(cfg), "who": quien, "mood": "hablando" },
		])
		_play()
		await _pausa(0.4)
	if lv.ended:
		return
	lv._entregar_tesoro()
	# Con una pieza de VITRINA en la mano, David explica qué es un
	# coleccionable (una sola vez en toda la partida). Espera a que se cierre
	# la ventana del premio, que va por encima de todo.
	if str(cfg.get("item", "")) == "":
		return
	await _esperar(func() -> bool:
		return lv.ended or not GameState.notices_busy())
	if lv.ended:
		return
	await _pausa(0.35)
	await _explicar_coleccionables()
	_play()


## EL HÁNDICAP DEL TIPO DE ESCENARIO, una vez por tipo en toda la partida:
## PUERTO = tres clientes que se van sin comer pierden la jornada (con el foco
## en su contador); ABORDAJE = cada vacío roba 15 segundos de reloj (con el
## foco en el reloj). En los dos, el vacío ya no cuesta oro — se dice aquí para
## que el jugador no crea que se ha librado del castigo.
func _explicar_handicap() -> void:
	if GameState.is_tutorial() or lv == null:
		return
	# LOS CASTIGOS EMPIEZAN EN EL MAR 2: en el mar 1 no hay nada que explicar
	# (y explicarlo alli era amenazar con un castigo que no existia).
	if CampaignData.sea_of(GameState.current_port) < 2:
		return
	var kind := CampaignData.get_kind(GameState.current_port)
	if kind == "isla" and not GameState.isla_handicap_done:
		GameState.isla_handicap_done = true
		GameState.save_game()
		await _say([
			{ "text": "Ojo, %s: en este mar la clientela es más exigente que en el anterior." % GameState.player_title(), "mood": "serio" },
			{ "text": "En las **islas**, el que se marche **sin probar bocado** te cuesta ORO del bueno — y cada vacío encarece el siguiente.", "mood": "hablando" },
			{ "text": "¡QUE NADIE SE VAYA CON LA BARRIGA VACÍA! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
			{ "text": "Un plato de una estrella basta para librarte del castigo. Que nadie se quede a cero.", "mood": "loro_resignado" },
		])
		_play()
	elif kind == "puerto" and not GameState.puerto_handicap_done:
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
		# EL NOMBRE DE MIKU NO SE DICE AQUI (pedido por el usuario): Alice
		# acaba de conocerlos y todavia no se fia. Lo suelta despues, ya en el
		# mapa, cuando pide enrolarse (`main_menu._presentar_alice`).
		{ "text": "A una persona. Mi maestra. Cocinaba... como nadie.", "who": "alice", "mood": "triste" },
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
# Muelle de las Bandejas: ALICE explica QUE MAS BONIFICADORES HAY y como se
# ganan. Este puerto tuvo la leccion del BARCO COMBINADO y se la lleva el mar 2
# (decidido por el usuario, no re-litigar): el puerto sigue permitiendo el barco
# (`boat`) para cuando llegue, pero ya no ata su bonificador.
#
# La da ELLA y no David a proposito: acaba de enrolarse de ayudante, o sea que
# ella misma ES un bonificador, y explicar el sistema desde dentro es la unica
# forma de que la escena no sea otra parrafada del capitan.

func _nivel_14() -> void:
	await _say([
		{ "text": "**Muelle de las Bandejas**. Puerto grande, clientela larga y nadie con prisa. Buen día para probar cosas.", "mood": "hablando" },
		{ "text": "Capitán... ¿puedo decir yo una? Es sobre los **bonificadores**.", "who": "alice", "mood": "callado" },
		{ "text": "Para eso te enrolaste, muchacha. Suelta.", "mood": "feliz" },
		{ "text": "Yo soy uno. El **ayudante de cocina**. Pero hay más, y ninguno se compra: se **ganan jugando**.", "who": "alice", "mood": "hablando" },
		{ "text": "Cada uno pide una **hazaña** distinta dentro de una partida, y la suya la lleva escrita en su ficha, en **Bonificadores**. Ahí se ven todos, tengas el que tengas.", "who": "alice", "mood": "serio" },
		{ "text": "Y no es de una vez: cada vez que repitas esa hazaña te llevas **otro uso**. Un uso es un turno con él puesto.", "who": "alice", "mood": "hablando" },
		{ "text": "¡USOS! ¡RAAAK! ¡QUE SE GASTAN!", "who": "gigi", "mood": "loro_grito" },
		{ "text": "Lo que sí cuesta doblones es **mejorarlos**: cinco niveles cada uno, y cada nivel aprieta un poco más lo que hacen.", "mood": "hablando" },
		{ "text": "Así que hoy no hay lección de cocina, %s. Sirve, gana, y ve fijándote en cuáles te faltan." % GameState.player_title(), "mood": "serio" },
	])
	_play()
	_vigilar_basura()


# ------------------------------------------------------------------- nivel 16
# Ensenada del Maridaje (ESCENARIO 12): EL MARIDAJE, entero y por primera vez.
# Iba adelantado de pasada en el de los postres (el 10) y el usuario oía la
# misma lección dos veces: ahora el 10 no lo menciona y aquí se presenta y se
# practica con la pareja más a mano, el té y el mochi.
#
# Y los dos platos son REGALOS de guion (el té en el 5, el mochi en el 7), así
# que a estas alturas los tiene cualquiera. La sopa de miso, que era la pareja
# del primer borrador, ni siquiera existe todavía: es el premio de 3 estrellas
# del escenario 10.

const MARIDAJE_PICOTEO := "te_verde"
const MARIDAJE_POSTRE := "mochi"
const AVISO_MARIDAJE := "Sírvele el **té verde** y, en cuanto se lo termine, el **mochi**."


func _nivel_16() -> void:
	await _say([
		{ "text": "**Ensenada del Maridaje**. Pocas bocas y ninguna con prisa: hoy se cocina pensando, no corriendo.", "mood": "hablando" },
		{ "text": "Porque hay platos que **se buscan** entre ellos. Si le sirves uno justo detrás del otro al MISMO cliente, el segundo paga de más.", "mood": "serio" },
		{ "text": "¡DINERO GRATIS! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Gratis no, cabezota: por servir en el **orden** bueno. Y no hay que adivinarlo — cada plato lleva escrito con quién casa en su ficha del **recetario**.", "mood": "loro_resignado" },
	])
	_play()
	_vigilar_basura()
	await _tras_la_preparacion()

	# --- El ejercicio, con alguien ya sentado y comiendo ---
	await _esperar(func() -> bool:
		return lv.ended or _comiendo() != null or _progreso() >= 0.30)
	if lv.ended:
		return
	var pb: Control = lv.prep_board
	var botones: Array = []
	for rid: String in [MARIDAJE_PICOTEO, MARIDAJE_POSTRE]:
		if pb.buttons.has(rid):
			botones.append(pb.buttons[rid])
	if not botones.is_empty():
		await _focus_nodes(botones, 14.0)
	await _say_raised([
		{ "text": "Ahí tienes una pareja de las buenas: el **té verde** y el **mochi**. Ese postre casa con ese té.", "mood": "hablando" },
		{ "text": "Primero el té. Y cuando se lo haya **terminado** —terminado, no servido— le sacas el mochi.", "mood": "serio" },
		{ "text": "¡EL ORDEN! ¡QUE SE MIRA EL ÚLTIMO QUE COMIÓ! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
		{ "text": "Eso mismo: si le cuelas otro plato en medio, se rompe. Pruébalo con uno y verás saltar el aviso sobre su cabeza.", "mood": "feliz" },
	])
	_play(AVISO_MARIDAJE)

	# --- Hasta que lo consiga de verdad: la lección se cierra al verlo ---
	await _esperar(func() -> bool:
		return lv.ended or lv.maridajes_hechos >= 1)
	if lv.ended:
		return
	await _say([
		{ "text": "¡**Maridaje**! ¿Has visto el aviso? Eso son doblones que no estaban en la ficha del plato.", "mood": "feliz" },
		{ "text": "Apúntatelo para toda la travesía, %s: una carta bien armada no son cuatro platos buenos, son **platos que se llevan bien**." % GameState.player_title(), "mood": "hablando" },
	])
	_play()


# ------------------------------------------------------------------- nivel 17
# Caleta del Cartógrafo (ESCENARIO 20): LOS MAPAS DEL TESORO. Lo trae un
# GRUMETE (pedido por el usuario) que no pide un capricho de mesa sino la
# JORNADA: "si haces un buen servicio, el mapa es tuyo" — o sea las tres
# estrellas (`"reto": "estrellas"`).
#
# SU TRATO LO CANTA ÉL, no David: de eso se encarga `_vigilar_tesoro`, que
# `_run` monta para cualquier escenario con cliente del tesoro. Este guion
# ESPERA a que termine (`_tesoro_cantado`) y solo entonces explica el sistema —
# hablar encima le pisaría su escena, y explicarlo ANTES sería un folleto sobre
# algo que todavía no le han ofrecido a nadie.
#
# Y la lección va AQUÍ y no al cobrar el mapa: el mapa se cobra al CERRAR el
# turno, y a esas alturas el cartel de resultados ya cierra las cajas de
# cualquier guion (`level3d._show_results`). Con el trato encima de la mesa, el
# jugador tiene toda la jornada para saber qué está persiguiendo.

func _nivel_17() -> void:
	await _say([
		{ "text": "**Caleta del Cartógrafo**. Puerto pequeño, clientela rara: aquí no todos pagan en oro.", "mood": "hablando" },
		{ "text": "¿QUE NO PAGAN? ¡PUES QUE COMAN PIEDRAS! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
		{ "text": "Hay cosas que valen más que el oro, plumas. Tú sirve, y ya verás.", "mood": "loro_resignado" },
	])
	_play()
	_vigilar_basura()

	# --- El grumete ya ha soltado su trato: ahora sí, qué es un mapa ---
	await _esperar(func() -> bool: return lv.ended or _tesoro_cantado)
	if lv.ended:
		return
	await _pausa(0.7)
	if lv.ended:
		return
	await _say([
		{ "text": "Un **mapa del tesoro**, %s. Y no es un adorno de camarote: es un **encargo aparte** de la travesía." % GameState.player_title(), "mood": "hablando" },
		{ "text": "Un mapa no te manda a otro sitio: te manda a **cocinar de otra manera**. Dar tres platos a cuatro bocas distintas, encadenar maridajes, cerrar sin tirar nada...", "mood": "serio" },
		{ "text": "Lo cumples en la jornada que quieras y en el escenario que quieras. No es otra travesía: es la misma, mirando otra cosa.", "mood": "hablando" },
		{ "text": "¡Y LOS HAY FÁCILES Y LOS HAY BRUTALES! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Tres marcas: **fácil**, **medio** y **difícil**. Los difíciles te cambian la jornada por debajo —clientela impaciente, reloj encima, tropiezos que se pagan— y por eso pagan más **oro** y más **experiencia**.", "mood": "hablando" },
		{ "text": "Los llevas **sin abrir** hasta que los abras. Se abren en el **mapa de la travesía**, en el tablón de abajo, y ahí eliges cuál llevas armado — **uno cada vez**, o acabas persiguiendo seis cosas y no cumples ninguna.", "mood": "serio" },
	])
	_play("Cierra la jornada con **3 estrellas** y el mapa es tuyo.")


# ---------------------------------------------------------------- mar 2 (8)
# Cala del Banderín: EL VIENTO. La primera vez que la cinta puede cambiar de
# sentido, así que David presenta las tres piezas — el banderín, el anemómetro
# y la regla ("zurdo y en rojo = la cinta se gira") — con la isla en calma.

func _mar2_viento() -> void:
	await _say([
		{ "text": "¿Notas el aire, %s? En este mar el viento no es un adorno: es un cliente más." % GameState.player_title(), "mood": "serio" },
		{ "text": "¡MIRA EL BANDERÍN! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
	])
	if lv.wind_label != null:
		_focus_node(lv.wind_label, 20.0)
	await _say([
		{ "text": "Ese número es el **anemómetro**: la fuerza del viento. En calma está en **verde**; cuando se acerque al vendaval se pondrá **rojo**.", "mood": "hablando" },
		{ "text": "Y ahora la regla de oro: si el viento sopla **hacia la izquierda** y llega al rojo vivo... **la cinta se da la vuelta**.", "mood": "serio" },
		{ "text": "Verás un **\"!\"** y oirás la campanilla justo antes. La cinta se frena, se para... y arranca al revés, con todos los platos a bordo.", "mood": "hablando" },
		{ "text": "No todo es malo: al girar, los platos que nadie quiso pasan OTRA VEZ por delante de todos. El viento quita... y da.", "mood": "feliz" },
		{ "text": "¡Y EL QUE VA A LA DERECHA NO HACE NADA! ¡RAAAK! ¡ES EL BUENO!", "who": "gigi", "mood": "loro" },
	])
	_play("Con viento **zurdo en rojo**, la cinta se gira. ¡Vigila el anemómetro!")
	_vigilar_basura()


## ¿Hay algún cliente atontado por el canto sentado a la barra?
func _hay_atontado() -> Node3D:
	for c in lv.seat_clients:
		if c != null and is_instance_valid(c) and c.atontado:
			return c
	return null


# ---------------------------------------------------------------- mar 2 (8)
# Cala del Arrullo: el CANTO DE SIRENA se presenta aquí. David no suelta la
# teoría de golpe: la primera línea siembra la sospecha, y la lección de
# verdad llega CON el primer aviso sonando — el canto se explica mientras
# ocurre, que es cuando se puede mirar. El truco de DESPERTAR con un toque no
# se cuenta aquí a propósito: es la lección de m2_10 (ver _mar2_despertar).


func _mar2_sirena() -> void:
	await _say([
		{ "text": "Qué agua más quieta... y qué silencio. En este mar, el silencio es que ALGO está cogiendo aire.", "mood": "serio" },
	])
	_play()
	_vigilar_basura()
	await _tras_la_preparacion()

	# La lección llega con el PRIMER AVISO: 2 s antes de que arranque el canto.
	await _esperar(func() -> bool:
		return lv.ended or lv.canto_aviso > 0.0 or lv.canto_activo)
	if lv.ended:
		return
	await _say([
		{ "text": "¡RAAAK! ¡¿QUIÉN CANTA?!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Una **sirena**... Escúchame rápido: mientras suene ese canto, el que ESPERA se **atonta** — mira al mar y no coge NI UN plato.", "mood": "serio" },
		{ "text": "Y su paciencia sigue bajando, claro. Pero el que está **comiendo** se libra: la comida puede más que el canto.", "mood": "hablando" },
		{ "text": "Así que ya sabes: cuando avise el canto, un plato a cada boca. Y lo que no puedas servir... a las **cajas**, para soltarlo cuando calle.", "mood": "hablando" },
	])
	_play("Con el **canto** sonando, el que espera se atonta: dale de comer ANTES.")

	# Y cuando el canto atonta al primero, la coletilla con el foco puesto.
	await _esperar(func() -> bool:
		return lv.ended or _hay_atontado() != null)
	if lv.ended:
		return
	var ido := _hay_atontado()
	if ido != null and is_instance_valid(ido):
		_focus_client(ido)
		await _say([
			{ "text": "¿Lo ves? Ido del todo. Se le pasará cuando el canto calle... si para entonces le queda paciencia.", "mood": "hablando" },
		])
	_play("Con el **canto** sonando, el que espera se atonta: dale de comer ANTES.")


# ---------------------------------------------------------------- mar 2 (10)
# Puerto de la Caracola: el TRUCO contra el canto — a un atontado se le
# despierta con un TOQUE, y ya no recae hasta el canto siguiente. Se enseña
# dos niveles después de estrenar el canto, cuando el jugador ya ha sufrido
# un par de jornadas viendo a la clientela embobada sin poder hacer nada.


func _mar2_despertar() -> void:
	await _say([
		{ "text": "Puerto de la Caracola. Aquí el canto aprieta más... y por eso hoy te enseño un truco de a bordo.", "mood": "hablando" },
	])
	_play()
	_vigilar_basura()
	await _tras_la_preparacion()

	await _esperar(func() -> bool:
		return lv.ended or _hay_atontado() != null)
	if lv.ended:
		return
	var ido := _hay_atontado()
	if ido != null and is_instance_valid(ido):
		_focus_client(ido)
	await _say([
		{ "text": "¡Ahí! ¿Ves a ese, embobado mirando al mar? **Tócalo**: un buen meneo y vuelve en sí.", "mood": "hablando" },
		{ "text": "¡DESPIERTA, DORMILÓN! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
		{ "text": "Despierto se queda hasta que acabe ESTE canto. Con el siguiente, vuelta a empezar.", "mood": "serio" },
	])
	_play("**Toca** al cliente atontado para despertarlo.")

	await _esperar(func() -> bool:
		return lv.ended or lv.despertados > 0)
	if lv.ended:
		return
	await _say([
		{ "text": "¡Eso es! Un canto bien toreado no te roba ni un doblón.", "mood": "feliz" },
	])
	_play()


# --------------------------------------------------------------- mar 2 (14)
# Jardín de Miku: la maestra de Alice aparece de repente en mitad del nivel y
# pide POR FAVOR un barco de sushi. La primera visita el jugador no puede
# montarlo (el bonificador llega en m2_18), así que Miku emplaza a volver; al
# volver con él y servírselo, enseña el SUSHI RUSH. Este guion corre en CADA
# visita mientras el Rush no esté aprendido (filtro propio en level3d).

## Plato del encargo de Miku y de Nach: el barco combinado.
const PLATO_BARCO := "moriawase"

var _miku: Node3D = null


func _mar2_miku() -> void:
	# La escena es el punto: no se juega en mudo mientras el trato siga vivo.
	_mudo = false
	await _say([
		{ "text": "Qué isla más cuidada... setos podados, farolillos, ni una mala hierba. Aquí vive alguien con MANO.", "mood": "hablando" },
	])
	_play()
	_vigilar_basura()
	await _tras_la_preparacion()

	# --- MIKU aparece (es el cliente especial, entra la última) ---
	await _esperar(func() -> bool:
		return lv.ended or _cliente_who("miku") != null)
	if lv.ended:
		return
	_miku = _cliente_who("miku")
	if _miku == null:
		return
	await _pausa(1.0)
	if not is_instance_valid(_miku) or lv.ended:
		return
	# El barco es SUYO mientras dura la escena, y no lo deja pasar nunca.
	lv.exclusive_dishes[PLATO_BARCO] = "miku"
	_miku.eager_dish = PLATO_BARCO
	_focus_client(_miku)
	# ¿Se puede montar el barco HOY? Lo dice el botón de la tabla, que ya
	# resuelve las dos llaves (el puerto lo permite y el bonificador va puesto).
	var puede: bool = not lv.prep_board.hide_boat
	await _say([
		{ "text": "Buenas tardes. ¿Molesto? Huele de maravilla desde el muelle.", "who": "miku", "mood": "hablando" },
		{ "text": "¡Una clienta con delantal! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Cocinera, de hecho. Y hoy me apetece algo muy concreto: un **barco de sushi**, por favor. Platos variados, en su bandeja.", "who": "miku", "mood": "feliz" },
	])
	if puede:
		await _say([
			{ "text": "Ya sabes montarlo, %s: cuatro platos guardados, dos clases distintas, y el botón del barco bajo las cajas." % GameState.player_title(), "mood": "hablando" },
		])
		_play("El encargo de Miku: un **barco de sushi** (guarda 4 platos de 2 clases).")
	else:
		await _say([
			{ "text": "¿Una bandeja combinada? Eso... todavía no sabemos montarlo, señora.", "mood": "sorprendido" },
			{ "text": "Oh, no pasa nada. Volveré otro día... o volved vosotros cuando sepáis. Las cosas buenas se esperan.", "who": "miku", "mood": "feliz" },
			{ "text": "¡APÚNTALO, RAAAK! ¡LA DEL DELANTAL QUIERE BARCO!", "who": "gigi", "mood": "loro" },
		])
		_play()
		return

	# --- El barco servido: el trato ---
	await _esperar(func() -> bool:
		return lv.ended or not is_instance_valid(_miku) \
			or PLATO_BARCO in _miku.eaten_ids)
	if lv.ended or not is_instance_valid(_miku) \
			or not PLATO_BARCO in _miku.eaten_ids:
		return
	if GameState.sushi_rush_unlocked:
		return
	GameState.sushi_rush_unlocked = true
	GameState.save_game()
	_focus_client(_miku)
	await _say([
		{ "text": "...Delicioso. El arroz en su punto, y la bandeja montada con cariño. Hacía años que no comía así.", "who": "miku", "mood": "feliz" },
		{ "text": "Un trato es un trato: os enseño mi secreto. Lo llamo **SUSHI RUSH**.", "who": "miku", "mood": "hablando" },
		{ "text": "Encadena **10 platos seguidos sin un solo fallo** — sin repetirle plato a nadie, sin tirar ninguno al cubo, sin cortes malos.", "who": "miku", "mood": "serio" },
		{ "text": "Cuando lo logres, las manos van solas: los platos **se montan al instante** y el fogón casi no descansa... hasta que falles uno.", "who": "miku", "mood": "feliz" },
		{ "text": "¡¿LAS MANOS SOLAS?! ¡RAAAK! ¡BRUJERÍA!", "who": "gigi", "mood": "loro_grito" },
		{ "text": "Técnica, loro. Años de técnica. Gracias por la comida... y saludad a Alice de mi parte.", "who": "miku", "mood": "hablando" },
	])
	_play("¡SUSHI RUSH aprendido! Encadena **10 platos sin fallo** para encenderlo.")


# --------------------------------------------------------------- mar 2 (18)
# Fondeadero de Nach: el capitán Nach, viejo amigo de Alice, ve a su pequeña
# enrolada en nuestro barco y decide enseñarnos el BARCO COMBINADO. Pide que
# el primero se lo sirvamos a ÉL. Superar el puerto abre su bonificador.

var _nach: Node3D = null


func _mar2_nach() -> void:
	await _say([
		{ "text": "**Fondeadero de Nach**. El dueño es un viejo capitán con más orgullo que barco... y dicen que hoy come aquí.", "mood": "hablando" },
	])
	_play()
	_vigilar_basura()
	await _tras_la_preparacion()

	await _esperar(func() -> bool:
		return lv.ended or _cliente_who("nach") != null)
	if lv.ended:
		return
	_nach = _cliente_who("nach")
	if _nach == null:
		return
	await _pausa(1.0)
	if not is_instance_valid(_nach) or lv.ended:
		return
	lv.exclusive_dishes[PLATO_BARCO] = "nach"
	_nach.eager_dish = PLATO_BARCO
	_focus_client(_nach)
	await _say([
		{ "text": "Vaya, vaya. Conque este es el barquito del que habla todo el mar.", "who": "nach", "mood": "serio" },
		{ "text": "¡¿Capitán Nach?!", "who": "alice", "mood": "sorprendido" },
		{ "text": "¡ALICE! ¡La pequeña del fogón de Miku! ¿Enrolada aquí? Já... entonces esta cocina vale la pena.", "who": "nach", "mood": "riendo" },
		{ "text": "Me enseñó a atar nudos cuando era niña. Y a robar mochis de la despensa.", "who": "alice", "mood": "feliz" },
		{ "text": "¡LO DEL MOCHI NO SE CUENTA! Ejem. Cocinero: por la pequeña, hoy os regalo un secreto de capitán.", "who": "nach", "mood": "hablando" },
		{ "text": "El **BARCO COMBINADO**: guarda **4 platos** en tus cajas — de **2 clases distintas** por lo menos — y pulsa el botón del barco, bajo las cajas.", "who": "nach", "mood": "serio" },
		{ "text": "Sale una bandeja que no rechaza NADIE, paga sus platos y una prima por variedad. Y el primero... me lo sirves A MÍ, que para eso lo enseño.", "who": "nach", "mood": "riendo" },
		{ "text": "¡QUÉ MORRO! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
	])
	_play("El encargo de Nach: móntale un **barco de sushi** (4 platos, 2 clases).")

	await _esperar(func() -> bool:
		return lv.ended or not is_instance_valid(_nach) \
			or PLATO_BARCO in _nach.eaten_ids)
	if lv.ended or not is_instance_valid(_nach) \
			or not PLATO_BARCO in _nach.eaten_ids:
		return
	# El bonificador se entrega AQUÍ, con la escena (como el ayudante de
	# Alice): el combo de las cajas acaba de hacerse montando este barco, y
	# esperar a la compuerta del puerto dejaba la lección sin premio inmediato.
	GameState.unlock_perk("barco")
	_focus_client(_nach)
	await _say([
		{ "text": "¡JÁ! ¡Mirad qué bandeja! Ni en los banquetes del Rey del Coral. Aprobado, cocinero.", "who": "nach", "mood": "riendo" },
		{ "text": "Desde hoy, el **barco de sushi** es tuyo: lo llevas de bonificador donde el puerto lo permita.", "mood": "feliz" },
		{ "text": "Y una cosa más, pequeña... Miku anda por estos mares. Si la ves, dile que Nach sigue debiéndole una partida de cartas.", "who": "nach", "mood": "hablando" },
		{ "text": "...Lo haré.", "who": "alice", "mood": "callado" },
	])
	_play()


# --------------------------------------------------------------- mar 2 (25)
# Fosa de la Sirena: la JEFA del mar 2 convierte el CANTO en arma. Sale al
# ganarse la 2ª estrella (la señal que el jugador ya conoce del Kappa), su
# cara es la 3ª y comparte las cinco calaveras y el decomiso de fase — pero a
# diferencia del Kappa, LA CLIENTELA SIGUE LLEGANDO: es la presa de su canto.
# Tres fases:
#  · F1 — el banquete entre cantos: SIRENA_PLATOS platos, con ella cantando a
#    ratos (mientras canta ni ella ni nadie que espere coge un plato).
#  · F2 — el canto dirigido: le canta a UN cliente, que queda atontado SIN
#    canto de fondo; hay que DESPERTARLO con el toque y darle de comer.
#    SIRENA_PRESAS rescates; una presa que se marche es calavera.
#  · F3 — el gran canto: canta casi sin parar y solo come en los SILENCIOS.
#    SIRENA_FINAL platos; el dado aplazado hace que los platos servidos en
#    pleno canto sigan vivos en la cinta para el silencio siguiente.
# La victoria: se emociona, deja su LÁGRIMA (BOSS_ITEMS via stat boss_sirena)
# y se zambulle de vuelta a la fosa.

const SIRENA_ALTO := 2.2
const SIRENA_PLATOS := 8
const SIRENA_PRESAS := 3
const SIRENA_FINAL := 5
const SIRENA_RECUPERA := [0.75, 0.50, 0.30]
const SIRENA_PREMIO_F1 := 0.75
const SIRENA_PREMIO_F2 := 0.50
## Los relojes del canto por fase: F1 respira (silencios largos), F3 aprieta.
const SIRENA_F1_SILENCIO := Vector2(11.0, 15.0)
const SIRENA_F1_CANTO := 6.0
const SIRENA_F3_SILENCIO := Vector2(3.2, 4.2)
const SIRENA_F3_CANTO := 8.0
## La presa despierta que no come en este plazo recibe otro canto dirigido.
const SIRENA_RECANTO := 7.0

var _bucle_canto := false
## Generacion del bucle: el bucle viejo, dormido en un await cuando se paro,
## despertaria con `_bucle_canto` ya en true por la fase SIGUIENTE y cantarian
## dos a la vez. Cada arranque sube la generacion y el bucle solo sigue si la
## suya sigue vigente.
var _bucle_gen := 0


func _sirena_jefa() -> Node3D:
	for c in lv.seat_clients:
		if c is Node3D and is_instance_valid(c) and c.who_override == "sirena":
			return c
	return null


## El bucle de canto de una fase: silencio sorteado → aviso (2 s) → canto.
## Corre en paralelo al sondeo de la fase; `_bucle_canto` lo apaga. Con el
## árbol en pausa (diálogos) sus relojes se congelan solos.
func _cantar_bucle(silencio: Vector2, canto: float) -> void:
	_bucle_gen += 1
	var gen := _bucle_gen
	while _bucle_canto and gen == _bucle_gen 			and is_instance_valid(lv) and not lv.ended:
		await _pausa(randf_range(silencio.x, silencio.y))
		if not _bucle_canto or gen != _bucle_gen or lv.ended:
			return
		lv._aviso_canto()
		await _pausa(2.0)
		if not _bucle_canto or gen != _bucle_gen or lv.ended:
			return
		lv._empezar_canto(canto)
		await _pausa(canto + 0.2)


func _parar_canto() -> void:
	_bucle_canto = false
	if lv.canto_activo:
		lv._terminar_canto()


func _mar2_sirena_jefa() -> void:
	_cortes = _mudo
	_mudo = false
	if _cortes:
		await _say([
			{ "text": "La fosa otra vez... y esta vez el canto no me da miedo. Casi me lo sé.", "mood": "hablando" },
			{ "text": "¡QUE NO TE OIGA DECIR ESO! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		])
	else:
		await _say([
			{ "text": "La Fosa de la Sirena... Todo este mar cantaba, %s, y lo que cantaba VIVE aquí abajo." % GameState.player_title(), "mood": "serio" },
			{ "text": "¡EL AGUA HACE BURBUJAS! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		])
	_play()
	await _tras_la_preparacion()

	# LA JEFA SALE AL GANARSE LA 2ª ESTRELLA, como el Kappa: la señal está en
	# la propia barra del oro.
	var umbral: int = int(lv.star_money[1]) if lv.star_money.size() >= 2 else 95
	await _esperar(func() -> bool:
		return lv.ended or lv._score_money() >= umbral)
	if lv.ended:
		return

	# --- ENTRA LA SIRENA ---
	# El reloj se para (desde aquí manda su paciencia). A DIFERENCIA del
	# Kappa, la barra NO se vacía y la clientela SIGUE llegando: son la presa
	# de su canto, y la fosa se queda con su público. La cola de llegadas se
	# ALARGA porque la de serie solo cubría los 2:30 del reloj y el duelo
	# puede correr mucho más allá.
	lv.timed = false
	lv._apply_hud_layout()
	for i in 16:
		lv.arrival_queue.append(lv.elapsed + 14.0 + i * 16.0)
	if _cortes:
		await _say([
			{ "text": "Ahí sube. Derechos, que la señora canta con público.", "mood": "hablando" },
		])
	else:
		await _say([
			{ "text": "¡ALGO SUBE DE LA FOSA! ¡RAAAAAK!", "who": "gigi", "mood": "loro_grito" },
			{ "text": "¡La **SIRENA**! Tapaos los oídos... ¡no, mejor COCINAD!", "mood": "gritando" },
		])
	for i in lv.seats.size():
		if lv.seats[i]["entry"] == lv.ENTRY:
			lv.first_seats.append(i)
	lv.special_who = "sirena"
	lv.special_type = "G"
	lv.special_spawned = false
	lv.special_height = SIRENA_ALTO
	lv.forced_types.append("G")
	lv._try_spawn_client()
	var jefa := _sirena_jefa()
	if jefa == null:
		await _esperar(func() -> bool:
			lv.forced_types.append("G")
			return lv._try_spawn_client() and _sirena_jefa() != null)
		jefa = _sirena_jefa()
	jefa.make_boss()
	lv.boss_hud_on()
	jefa.plate_served.connect(_on_kappa_plato)
	jefa.boss_starved.connect(_on_kappa_hambre)
	await _pausa(1.2)
	_focus_client(jefa)
	if _cortes:
		await _say([
			{ "text": "Buenas noches, cocina. He vuelto... a CENAR, como prometí. Aunque igual canto un poco. Costumbres.", "who": "sirena", "mood": "feliz" },
			{ "text": "**%d platos**, para abrir boca. Ya sabéis cómo va esto." % SIRENA_PLATOS, "who": "sirena", "mood": "hablando" },
		])
	else:
		await _say([
			{ "text": "Conque vosotros sois los que llenan MI mar de olores...", "who": "sirena", "mood": "serio" },
			{ "text": "Voy a probar esa cocina. **%d platos**... y si me haces esperar, CANTO. Y cuando yo canto, tu clientela es mía." % SIRENA_PLATOS, "who": "sirena", "mood": "hablando" },
			{ "text": "Su cara es tu **tercera estrella**, y las **cinco calaveras** de siempre. Sirve ANTES de que abra la boca, cocinero.", "mood": "serio" },
		])
	var aviso1 := "¡**%d platos** para la Sirena — y sirve ANTES de cada canto!" % SIRENA_PLATOS
	_play(aviso1)

	# --- FASE 1: el banquete entre cantos ---
	_bucle_canto = true
	_cantar_bucle(SIRENA_F1_SILENCIO, SIRENA_F1_CANTO)
	if not await _fase_sirena(jefa, SIRENA_PLATOS, aviso1):
		_parar_canto()
		return
	_parar_canto()
	jefa.boss_patience_add(SIRENA_PREMIO_F1)
	_focus_client(jefa)
	if _cortes:
		await _say([
			{ "text": "Mmm. Sigue igual de rico. ¿Jugamos a lo de la otra vez?", "who": "sirena", "mood": "feliz" },
			{ "text": "Le canto a uno de los tuyos... y tú lo despiertas y le das de comer. **%d veces**." % SIRENA_PRESAS, "who": "sirena", "mood": "cantando" },
		])
	else:
		await _say([
			{ "text": "No está mal... para ser cocina de superficie. Juguemos a algo.", "who": "sirena", "mood": "feliz" },
			{ "text": "Voy a cantarle a UNO de tus clientes, solo para él. Despiértalo si puedes... y dale de comer delante de mí. **%d veces**." % SIRENA_PRESAS, "who": "sirena", "mood": "cantando" },
			{ "text": "¡TRAMPOSA! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
			{ "text": "El truco de siempre: **tócalo** para despertarlo, y a la boca. Si se nos va de la barra, calavera.", "mood": "serio" },
		])
	var aviso2 := "Fase 2: **despierta** al cliente que ella atonte y dale de comer (x%d)." % SIRENA_PRESAS
	_play(aviso2)

	# --- FASE 2: el canto dirigido ---
	if not await _fase_presas(jefa, aviso2):
		return
	jefa.boss_patience_add(SIRENA_PREMIO_F2)
	_focus_client(jefa)
	if _cortes:
		await _say([
			{ "text": "Y el final que ya conoces: el **gran canto**. Solo como en los silencios. **%d platos**." % SIRENA_FINAL, "who": "sirena", "mood": "hablando" },
		])
	else:
		await _say([
			{ "text": "Me estás gustando, humano. Última prueba: el **gran canto**.", "who": "sirena", "mood": "serio" },
			{ "text": "Cantaré casi sin parar... y solo comeré en los **silencios**. **%d platos**. A ver ese pulso." % SIRENA_FINAL, "who": "sirena", "mood": "cantando" },
			{ "text": "¡Ojo! Los platos que pasen de largo mientras canta NO se pierden: siguen en la cinta. ¡Suéltalos y espera al silencio!", "mood": "hablando" },
		])
	var aviso3 := "Fase 3: el gran canto — ¡**%d platos**, solo come en los SILENCIOS!" % SIRENA_FINAL
	_play(aviso3)

	# --- FASE 3: el gran canto ---
	_bucle_canto = true
	_cantar_bucle(SIRENA_F3_SILENCIO, SIRENA_F3_CANTO)
	if not await _fase_sirena(jefa, SIRENA_FINAL, aviso3):
		_parar_canto()
		return
	_parar_canto()

	# --- VICTORIA ---
	lv.boss_done = true
	lv.goal_reached = true
	lv.boss_star_win()
	lv.boss_chip_set(0)
	_focus_client(jefa)
	await _say([
		{ "text": "...", "who": "sirena", "mood": "sorprendido" },
		{ "text": "Nadie... nadie había cocinado así para mí. En mil años de fosa, NADIE se había quedado a terminar el menú.", "who": "sirena", "mood": "feliz" },
		{ "text": "Toma. Una **lágrima de sirena**. No preguntes cómo la he sacado sin llorar.", "who": "sirena", "mood": "hablando" },
		{ "text": "Volveré. A cenar... no a cantar.", "who": "sirena", "mood": "feliz" },
	])
	await _sirena_se_zambulle(jefa)
	await _say([
		{ "text": "¡Se rinde! ¡Y con propina de leyenda! ¡Este mar entero es tuyo, %s!" % GameState.player_title(), "mood": "riendo" },
		{ "text": "¡QUE ALGUIEN SEQUE LA BARRA! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
	])
	_play()
	lv._end_level()


## Una fase de PLATOS de la Sirena (F1 y F3): N platos cualesquiera, con las
## hambrunas por medio. El mismo sondeo de eaten_ids que _fase_kappa; aparte
## porque sus fallos hablan con SU voz y su propia escalera de recuperacion.
func _fase_sirena(jefa: Node3D, objetivo: int, aviso: String) -> bool:
	_oro_fase = 0
	_prop_fase = 0
	_hambre = false
	var progreso := 0
	var vistos: int = jefa.eaten_ids.size()
	lv.boss_chip_set(objetivo)
	while true:
		await _esperar(func() -> bool:
			return lv.ended or lv.boss_lost or _hambre \
				or not is_instance_valid(jefa) \
				or jefa.eaten_ids.size() > vistos)
		if lv.ended or lv.boss_lost or not is_instance_valid(jefa):
			return false
		if _hambre:
			_hambre = false
			if not await _hambruna_sirena(jefa, aviso):
				return false
			continue
		vistos += 1
		progreso += 1
		lv.boss_chip_set(objetivo - progreso)
		if progreso >= objetivo:
			return true
	return false


## FASE 2 — el canto dirigido: la Sirena elige una PRESA entre los sentados y
## la atonta SIN canto de fondo; hay que despertarla con el toque y que coma.
## La presa que se marcha cuesta calavera. La paciencia de la JEFA se RETIENE
## mientras dura: la fase mira a la barra, y que ella se muriera de hambre a
## la vez seria pelear en dos frentes.
func _fase_presas(jefa: Node3D, aviso: String) -> bool:
	jefa.patience_hold = true
	var salvados := 0
	lv.boss_chip_set(SIRENA_PRESAS)
	while salvados < SIRENA_PRESAS:
		var presa := _elegir_presa()
		if presa == null:
			await _esperar(func() -> bool:
				return lv.ended or lv.boss_lost or _elegir_presa() != null)
			if lv.ended or lv.boss_lost:
				jefa.patience_hold = false
				return false
			presa = _elegir_presa()
		presa.canto_despierto = false
		presa.set_atontado(true)
		var base: int = presa.eaten_ids.size()
		var reloj := 0.0
		while true:
			await _pausa(0.25)
			reloj += 0.25
			if lv.ended or lv.boss_lost or not is_instance_valid(jefa):
				if is_instance_valid(jefa):
					jefa.patience_hold = false
				return false
			if not is_instance_valid(presa) or not presa.ya_sentado() \
					or presa.state == presa.State.LEAVING:
				# La presa se nos fue de la barra: calavera y otra presa.
				if not await _fallo_sirena(jefa,
						("Uy... ese se me ha ido cantado. Perdona." if _cortes
						else "¿Lo ves? MÍO. Se ha ido con mi canto en la cabeza... y tú lo has dejado ir."),
						aviso):
					return false
				break
			if presa.eaten_ids.size() > base:
				salvados += 1
				lv.boss_chip_set(SIRENA_PRESAS - salvados)
				break
			# La presa despierta que no come vuelve a caer en el canto.
			if not presa.atontado and presa.state == presa.State.WAITING \
					and reloj >= SIRENA_RECANTO:
				reloj = 0.0
				presa.canto_despierto = false
				presa.set_atontado(true)
	jefa.patience_hold = false
	return true


## La presa del canto dirigido: un cliente sentado, esperando, que no sea la
## propia jefa. Se prefiere al de MAS paciencia (que el rescate de un
## moribundo no dependa de la suerte del sorteo).
func _elegir_presa() -> Node3D:
	var mejor: Node3D = null
	var mejor_p := -1.0
	for c in lv.seat_clients:
		if c == null or not is_instance_valid(c) or c.boss:
			continue
		if not c.ya_sentado() or c.state != c.State.WAITING or c.atontado:
			continue
		if c.patience > mejor_p:
			mejor_p = c.patience
			mejor = c
	return mejor


## La Sirena sin paciencia: calavera, decomiso y recupera cada vez menos.
func _hambruna_sirena(jefa: Node3D, aviso := "") -> bool:
	_hambres += 1
	var quedan: int = lv.boss_lose_skull()
	lv.boss_forfeit(_oro_fase, _prop_fase)
	_oro_fase = 0
	_prop_fase = 0
	if quedan <= 0:
		await _derrota_sirena()
		return false
	var frac: float = SIRENA_RECUPERA[mini(_hambres - 1, SIRENA_RECUPERA.size() - 1)]
	jefa.boss_patience_set(frac)
	_focus_client(jefa)
	await _say([{ "text": ("Disculpa... el estómago me está cantando a MÍ. ¿Un poco más de ritmo?"
			if _cortes else "Tengo **HAMBRE**, humano. ¿Quieres oírme cantar DE VERDAD?"),
		"who": "sirena", "mood": "enfadado" }])
	_play(aviso)
	return true


## Un fallo de fase de la Sirena: calavera, decomiso y su frase.
func _fallo_sirena(jefa: Node3D, frase: String, aviso := "") -> bool:
	var quedan: int = lv.boss_lose_skull()
	lv.boss_forfeit(_oro_fase, _prop_fase)
	_oro_fase = 0
	_prop_fase = 0
	if quedan <= 0:
		await _derrota_sirena()
		return false
	_focus_client(jefa)
	await _say([{ "text": frase, "who": "sirena", "mood": "enfadado" }])
	_play(aviso)
	return true


## La quinta calavera: la Sirena se vuelve a la fosa y la jornada se pierde.
func _derrota_sirena() -> void:
	if _cortes:
		await _say([
			{ "text": "Me voy con hambre... Otro día cantamos, cocinero.", "who": "sirena", "mood": "serio" },
			{ "text": "Se acabó por hoy. Volvemos: ya sabemos cómo respira.", "mood": "triste" },
		])
	else:
		await _say([
			{ "text": "QUÉ DECEPCIÓN. Me vuelvo a mi fosa... y tu clientela se viene un rato conmigo.", "who": "sirena", "mood": "enfadado" },
			{ "text": "La hemos perdido... El gran canto no perdona. ¡Volveremos con la lección aprendida!", "mood": "triste" },
		])
	_play()
	lv._end_level()


## LA VICTORIA SE VE: la Sirena se despide y SE ZAMBULLE de vuelta a la fosa —
## gira hacia delante y se hunde bajo el suelo de roca (el plano es opaco, asi
## que lo que baja de y=0 desaparece), con un "~" de remolino detras.
func _sirena_se_zambulle(jefa: Node3D) -> void:
	var idx: int = lv.seat_clients.find(jefa)
	if idx >= 0:
		lv.seat_clients[idx] = null
	jefa.set_process(false)
	jefa.hide_bars()
	var tw := create_tween()
	tw.tween_property(jefa, "rotation_degrees:x", -75.0, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(jefa, "position:y", jefa.position.y - 2.6, 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	var olas := Label.new()
	olas.text = "~ ~ ~"
	olas.add_theme_font_size_override("font_size", 34)
	olas.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	olas.add_theme_color_override("font_outline_color", Color.BLACK)
	olas.add_theme_constant_override("outline_size", 8)
	olas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lv.world_ui.add_child(olas)
	olas.position = lv.cam.unproject_position(jefa.global_position + Vector3.UP * 2.4) \
		- Vector2(34.0, 0.0)
	var ot := olas.create_tween()
	ot.tween_property(olas, "modulate:a", 0.0, 1.6)
	ot.tween_callback(olas.queue_free)
	jefa.visible = false
	await _pausa(0.5)


# ------------------------------------------------------------------- nivel 15
# Cueva del Kappa: el JEFE, en TRES FASES (rediseño del 20-8-2026, pedido por
# el usuario — no re-litigar):
#  · El Kappa sale al ganarse la 2ª ESTRELLA (no por barrigas ni por reloj), y
#    SIEMPRE por la boca de la cueva (la borda de arriba).
#  · La 3ª estrella ES el Kappa: su cara sustituye a la estrella de la meta y
#    se gana rindiéndolo. Su chapa con la cuenta de platos vive arriba.
#  · Fase 1: BOSS_PLATES platos. Si su paciencia toca fondo: una CALAVERA, el
#    oro y las propinas de los platos de la fase se pierden, y recupera el
#    75% → 50% → 30% de paciencia (cada hambruna perdona menos).
#  · Fase 2 (+75% de paciencia): KAPPA_DISTINTOS platos SIN repetir. Un
#    repetido = calavera + oro de la fase + su paladar se resetea y se empieza
#    de nuevo.
#  · Fase 3 (+50%): KAPPA_MISMO veces el plato MÁS CARO de la carta de hoy.
#    Cualquier otro plato = calavera + oro de la fase + cuenta a cero.
#  · CINCO calaveras. A la quinta, jornada perdida (0 estrellas).
#  · Victoria: el Kappa se cae del taburete y se queda DORMIDO en el suelo;
#    David felicita, y al volver al mapa el Kappa (medio dormido) paga
#    2 lingotes y su diente (`main_menu._presentar_kappa`).
# Esta coreografía corre TAMBIÉN en las repeticiones (en mudo): sin ella no
# habría jefe al que ganar.

## Alto del Kappa en unidades de mundo: más que un capitán (1.95). Es el jefe
## y tiene que verse desde la otra punta de la cubierta.
const KAPPA_ALTO := 2.5
## Platos distintos de la fase 2 y repeticiones del plato caro de la fase 3.
const KAPPA_DISTINTOS := 3
const KAPPA_MISMO := 5
## Paciencia que recupera tras cada hambruna: cada una perdona menos.
const KAPPA_RECUPERA := [0.75, 0.50, 0.30]
## Premio de paciencia al superar la fase 1 y la 2.
const KAPPA_PREMIO_F1 := 0.75
const KAPPA_PREMIO_F2 := 0.50

## Oro y propinas de los platos servidos al Kappa EN LA FASE EN CURSO: es lo
## que se pierde con cada fallo. Los rellena `_on_kappa_plato`.
var _oro_fase := 0
var _prop_fase := 0
## El Kappa se ha quedado sin paciencia (lo levanta su señal `boss_starved`;
## el bucle de fase lo recoge y cobra la calavera).
var _hambre := false
## Hambrunas encajadas, para la escalera de recuperaciones.
var _hambres := 0
## SEGUNDA VUELTA: el escenario ya está superado, así que el Kappa no es una
## amenaza que se estrena — es un vecino que vuelve a comer a su cueva. Sigue
## siendo un JEFE con sus tres fases y sus cinco calaveras, pero pide las cosas
## POR FAVOR en vez de exigirlas a gritos (pedido por el usuario). El duelo NO
## se juega en mudo: en las repeticiones habla igual, solo que con educación.
var _cortes := false


## El mood del Kappa para un fallo de la fase `n` (1, 2 o 3). Enfadándose más
## con cada fase la primera vez; sin perder las formas en la segunda vuelta.
func _ira_kappa(n: int) -> String:
	if _cortes:
		return "hablando" if n < 3 else "serio"
	return ["enfadado", "furioso", "colerico"][clampi(n - 1, 0, 2)]


func _nivel_15() -> void:
	# EL JEFE HABLA SIEMPRE, también al repetir: lo que cambia con `_cortes` no
	# es si habla, sino CÓMO pide las cosas.
	_cortes = _mudo
	_mudo = false
	if _cortes:
		await _say([
			{ "text": "Otra vez la cueva... Y esta vez sabemos quién vive dentro.", "mood": "hablando" },
			{ "text": "¡EL BICHO! ¡RAAAK! ¡QUE VIENE EL BICHO!", "who": "gigi", "mood": "loro_sorpresa" },
			{ "text": "Que venga. Hoy le tenemos la mesa puesta.", "mood": "feliz" },
		])
	else:
		await _say([
			{ "text": "Estas aguas están demasiado tranquilas... Sirve y mantén los ojos abiertos.", "mood": "serio" },
			{ "text": "¡GLUB, GLUB! ¡ALGO BURBUJEA! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		])
	_play()
	await _tras_la_preparacion()

	# EL KAPPA SALE AL GANARSE LA 2ª ESTRELLA: la señal está en la propia
	# barra del oro, así que el jugador sabe exactamente cuánto le falta.
	var umbral: int = int(lv.star_money[1]) if lv.star_money.size() >= 2 else 55
	await _esperar(func() -> bool:
		return lv.ended or lv._score_money() >= umbral)
	if lv.ended:
		return

	# --- ENTRA EL JEFE ---
	# El reloj se para (desde aquí manda su paciencia), no llega nadie más y
	# la barra se vacía sin castigos: el duelo es de uno contra uno.
	lv.timed = false
	lv._apply_hud_layout()
	lv.arrival_queue.clear()
	lv.type_queue.clear()
	lv.forced_types.clear()
	if _cortes:
		await _say([
			{ "text": "Ahí está. Puntual como el hambre.", "mood": "hablando" },
			{ "text": "Dejadle sitio, que este ya es de la casa.", "mood": "feliz" },
		])
	else:
		await _say([
			{ "text": "¡EL MAR! ¡EL MAR SE ABRE! ¡RAAAAAK!", "who": "gigi", "mood": "loro_grito" },
			{ "text": "Lo sabía... ¡el **KAPPA**! ¡Todo el mundo fuera de la barra!", "mood": "gritando" },
		])
	for c in lv.seat_clients:
		if c is Node3D and is_instance_valid(c):
			c.force_leave(false)
	# SIEMPRE POR ARRIBA: por la boca de la cueva (las sillas de la borda de
	# arriba, `ENTRY`, se fuerzan antes del sorteo). Salir del agua por la
	# borda de abajo rompía la escena: la boca está arriba.
	for i in lv.seats.size():
		if lv.seats[i]["entry"] == lv.ENTRY:
			lv.first_seats.append(i)
	lv.special_who = "kappa"
	lv.special_type = "G"
	lv.special_spawned = false
	lv.special_height = KAPPA_ALTO
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
	lv.boss_hud_on()
	kappa.plate_served.connect(_on_kappa_plato)
	kappa.boss_starved.connect(_on_kappa_hambre)
	await _pausa(1.2)
	_focus_client(kappa)
	if _cortes:
		# LO PRIMERO QUE DICE AL VOLVER (pedido por el usuario): entra pidiendo
		# permiso, porque esta es SU cueva y nosotros somos los invitados.
		await _say([
			{ "text": "Hola. Con permiso... Vengo a mi cueva, a comer. Gracias.", "who": "kappa", "mood": "hablando" },
			{ "text": "Adelante, grandullón. La cocina es tuya.", "mood": "feliz" },
			{ "text": "**%d platos**, por favor. Tengo mucha hambre... y se me pasa deprisa." % BOSS_PLATES, "who": "kappa", "mood": "hablando" },
			{ "text": "Ya sabes cómo va: su cara es la **tercera estrella**, y cinco fallos nos mandan a pique.", "mood": "hablando" },
		])
	else:
		await _say([
			{ "text": "HAMBRE.", "who": "kappa", "mood": "enfadado" },
			{ "text": "Escúchame rápido: el Kappa come de TODO, a una velocidad de escándalo... y se **impacienta** igual de rápido.", "mood": "serio" },
			{ "text": "**%d platos**, cocinero. Y que no se me vacíe la barriga... o nos enfadamos." % BOSS_PLATES, "who": "kappa", "mood": "hablando" },
			{ "text": "Su cara está en la barra de arriba: ¡esa es hoy tu **tercera estrella**! Y ojo a las **cinco calaveras**: cada fallo enciende una, y a la quinta nos vamos a pique.", "mood": "hablando" },
		])
	_play("¡**%d platos** para el Kappa, sin dejar que su barra toque fondo!" % BOSS_PLATES)

	# --- FASE 1: los platos ---
	if not await _fase_kappa(kappa, BOSS_PLATES, "platos", "", _ira_kappa(1),
			"¡**%d platos** para el Kappa, sin dejar que su barra toque fondo!" % BOSS_PLATES):
		return
	kappa.boss_patience_add(KAPPA_PREMIO_F1)
	_focus_client(kappa)
	if _cortes:
		await _say([
			{ "text": "Mmm... qué rico. Muchas gracias.", "who": "kappa", "mood": "feliz" },
			{ "text": "¿Podrías traerme **%d platos DISTINTOS** ahora? Repetidos no, por favor: me llenan y no me alimentan." % KAPPA_DISTINTOS, "who": "kappa", "mood": "hablando" },
		])
	else:
		await _say([
			{ "text": "Mmm. Bueno. MÁS.", "who": "kappa", "mood": "hablando" },
			{ "text": "Ahora, **%d platos DISTINTOS**. Si me repites plato... calavera." % KAPPA_DISTINTOS, "who": "kappa", "mood": "serio" },
		])
	_play("Fase 2: ¡**%d platos DISTINTOS**, sin repetir ninguno!" % KAPPA_DISTINTOS)

	# --- FASE 2: la variedad ---
	if not await _fase_kappa(kappa, KAPPA_DISTINTOS, "distintos", "", _ira_kappa(2),
			"Fase 2: ¡**%d platos DISTINTOS**, sin repetir ninguno!" % KAPPA_DISTINTOS):
		return
	kappa.boss_patience_add(KAPPA_PREMIO_F2)
	var plato := _plato_mas_caro()
	var nombre := str(RecipeData.get_recipe(plato).get("name", plato))
	_focus_client(kappa)
	if _cortes:
		await _say([
			{ "text": "Un último capricho, si no es molestia: lo mejor que lleves. El **%s**." % nombre, "who": "kappa", "mood": "hablando" },
			{ "text": "**%d veces** el mismo, por favor. Cuando algo me gusta, me gusta mucho." % KAPPA_MISMO, "who": "kappa", "mood": "feliz" },
		])
	else:
		await _say([
			{ "text": "Último antojo. Lo MEJOR de tu carta: **%s**." % nombre, "who": "kappa", "mood": "serio" },
			{ "text": "**%d veces**. Ni una más, ni una menos... ni OTRA COSA." % KAPPA_MISMO, "who": "kappa", "mood": "furioso" },
		])
	_play("Fase 3: ¡**%d veces** el **%s** y nada más!" % [KAPPA_MISMO, nombre])

	# --- FASE 3: el antojo ---
	if not await _fase_kappa(kappa, KAPPA_MISMO, "mismo", plato, _ira_kappa(3),
			"Fase 3: ¡**%d veces** el **%s** y nada más!" % [KAPPA_MISMO, nombre]):
		return

	# --- VICTORIA ---
	lv.boss_done = true
	lv.goal_reached = true
	lv.boss_star_win()
	lv.boss_chip_set(0)
	await _kappa_duerme(kappa)
	await _say([
		{ "text": ("Gracias, cocinero. De verdad. Kappa... lleno."
			if _cortes else "Kappa... lleno. Kappa... contento..."), "who": "kappa", "mood": "feliz" },
		{ "text": "Ahora... dormir...", "who": "kappa", "mood": "dormido" },
		{ "text": "¡Se rinde! ¡Mirad cómo ronca! ¡Eres el cocinero que las leyendas pedían, %s!" % GameState.player_title(), "mood": "riendo" },
		{ "text": "¡QUE ALGUIEN LO SAQUE DE LA BARRA! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
	])
	# Y LA VICTORIA CIERRA IGUAL QUE LA DERROTA: sin esto la última frase de
	# Gigi se quedaba clavada encima del cartel de resultados tragándose los
	# toques — ni "Continuar", ni la ventana de subida de nivel, ni la de
	# receta nueva.
	_play()
	lv._end_level()


## Una FASE del duelo. `modo`: "platos" (N cualesquiera), "distintos" (N sin
## repetir) o "mismo" (N del plato `target`, y solo ese). Devuelve false si el
## duelo murió por el camino: derrota por calaveras, fin del nivel o el propio
## Kappa desaparecido.
##
## VA POR SONDEO de `eaten_ids`, no por señal: el id del plato solo está ahí,
## y leerlo en el mismo bucle que decide serializa los fallos con las frases
## (un handler async podía hablar ENCIMA de la charla de cambio de fase).
func _fase_kappa(kappa: Node3D, objetivo: int, modo: String,
		target := "", ira := "enfadado", aviso := "") -> bool:
	_oro_fase = 0
	_prop_fase = 0
	_hambre = false
	var progreso := 0
	var distintos := {}
	var vistos: int = kappa.eaten_ids.size()
	lv.boss_chip_set(objetivo)
	while true:
		await _esperar(func() -> bool:
			return lv.ended or lv.boss_lost or _hambre \
				or not is_instance_valid(kappa) \
				or kappa.eaten_ids.size() > vistos)
		if lv.ended or lv.boss_lost or not is_instance_valid(kappa):
			return false
		if _hambre:
			_hambre = false
			if not await _hambruna_kappa(kappa, ira, aviso):
				return false
			continue
		vistos += 1
		var id := str(kappa.eaten_ids[vistos - 1])
		if modo == "distintos" and distintos.has(id):
			if not await _fallo_kappa(kappa, ("Perdona... eso ya me lo he comido. Te dije distintos. ¿Empezamos otra vez?"
					if _cortes else "Eso... YA LO HE COMIDO. ¡DISTINTOS he dicho! ¡Empezamos de nuevo!"), ira, aviso):
				return false
			distintos.clear()
			progreso = 0
			# Su paladar se resetea (pedido por el usuario): sin esto, la
			# escalera del hastío del intento fallido seguía cargada y el
			# reintento drenaba la paciencia como si nada se hubiera olvidado.
			kappa._limpiar_paladar()
			lv.boss_chip_set(objetivo)
			continue
		if modo == "mismo" and id != target:
			var nombre := str(RecipeData.get_recipe(target).get("name", target))
			if not await _fallo_kappa(kappa, (("Uy... yo pedí **%s**. No pasa nada, pero vuelvo a empezar la cuenta." % nombre)
					if _cortes else ("¡ESO NO! ¡He dicho **%s**! ¡La cuenta A CERO!" % nombre)), ira, aviso):
				return false
			progreso = 0
			lv.boss_chip_set(objetivo)
			continue
		if modo == "distintos":
			distintos[id] = true
		progreso += 1
		lv.boss_chip_set(objetivo - progreso)
		if progreso >= objetivo:
			return true
	# Inalcanzable (el bucle solo sale por return), pero el analizador de
	# GDScript exige que todos los caminos devuelvan algo.
	return false


## El Kappa se ha quedado sin paciencia: calavera, el oro de la fase se pierde
## y recupera un trozo de barra — cada vez menos (75% → 50% → 30%). Devuelve
## false si esa calavera era la quinta.
func _hambruna_kappa(kappa: Node3D, ira := "enfadado", aviso := "") -> bool:
	_hambres += 1
	var quedan: int = lv.boss_lose_skull()
	lv.boss_forfeit(_oro_fase, _prop_fase)
	_oro_fase = 0
	_prop_fase = 0
	if quedan <= 0:
		await _derrota_kappa()
		return false
	var frac: float = KAPPA_RECUPERA[mini(_hambres - 1, KAPPA_RECUPERA.size() - 1)]
	kappa.boss_patience_set(frac)
	_focus_client(kappa)
	await _say([{ "text": ("Disculpa... me he quedado con **hambre** otra vez. ¿Un poco más rápido, por favor?"
			if _cortes else "¡KAPPA TIENE **HAMBRE**! ¡Más deprisa, cocinero, o me como la cueva!"),
		"who": "kappa", "mood": ira }])
	# LA CAJA SOLO LA CIERRA `_play`: sin esta llamada el diálogo del hambre se
	# quedaba clavado en pantalla con todo el input tragado (softlock).
	_play(aviso)
	return true


## Un fallo de fase (plato repetido, plato equivocado): calavera, el oro de la
## fase se pierde y el Kappa lo canta. Devuelve false si era la quinta.
func _fallo_kappa(kappa: Node3D, frase: String, ira := "enfadado",
		aviso := "") -> bool:
	var quedan: int = lv.boss_lose_skull()
	lv.boss_forfeit(_oro_fase, _prop_fase)
	_oro_fase = 0
	_prop_fase = 0
	if quedan <= 0:
		await _derrota_kappa()
		return false
	_focus_client(kappa)
	await _say([{ "text": frase, "who": "kappa", "mood": ira }])
	_play(aviso)
	return true


## La quinta calavera: jornada perdida (0 estrellas, `boss_lost` ya puesto).
func _derrota_kappa() -> void:
	if _cortes:
		await _say([
			{ "text": "Lo siento... Me voy con hambre. Otro día será, cocinero.", "who": "kappa", "mood": "serio" },
			{ "text": "Se nos ha ido de vacío... y eso, con un Kappa, se paga. Volvemos mañana.", "mood": "triste" },
		])
	else:
		await _say([
			{ "text": "¡¡BASTA!! Kappa se harta. ¡KAPPA SE VA!", "who": "kappa", "mood": "colerico" },
			{ "text": "Se acabó la jornada... Un Kappa enfadado no perdona. ¡Volveremos: ahora ya sabes cómo mastica!", "mood": "triste" },
		])
	# Cerrar la caja ANTES de cerrar el turno: se quedaba abierta encima del
	# cartel de resultados tragándose los toques — el jugador no podía salir,
	# y sin llegar al cartel el oro de la jornada ni se cobraba.
	_play()
	lv._end_level()


## El plato MÁS CARO de la carta de hoy: el antojo de la fase 3. Ni postres
## (el jefe los descarta antes del dado) ni picoteos: tiene que ser un plato
## que el Kappa vaya a coger y que se pueda repetir cinco veces.
func _plato_mas_caro() -> String:
	var mejor := ""
	var precio := -1
	for id in GameState.selected_recipes:
		var r := RecipeData.get_recipe(id)
		if r.get("leaves_seat", false) or r.get("snack", false):
			continue
		if int(r.get("price", 0)) > precio:
			precio = int(r.get("price", 0))
			mejor = str(id)
	if mejor == "" and not GameState.selected_recipes.is_empty():
		mejor = str(GameState.selected_recipes[0])
	return mejor


## LA VICTORIA SE VE: el Kappa se cae del taburete y se queda DORMIDO en el
## suelo. Se le saca de la lógica del nivel (nadie lo cobra ni lo echa al
## cerrar: `_end_level` ya no lo encuentra en `seat_clients`) y un "Zzz"
## flotante lo remata.
func _kappa_duerme(kappa: Node3D) -> void:
	var idx: int = lv.seat_clients.find(kappa)
	if idx >= 0:
		lv.seat_clients[idx] = null
	kappa.set_process(false)
	kappa.hide_bars()
	# El tumbo: cae de lado con un rebote corto. Se anima la RAÍZ (el pivote
	# está en sus pies), así que vuelca sobre el suelo como un saco.
	var tw := create_tween()
	tw.tween_property(kappa, "rotation_degrees:z", 80.0, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(kappa, "rotation_degrees:z", 71.0, 0.16)
	tw.tween_property(kappa, "rotation_degrees:z", 76.0, 0.14)
	await tw.finished
	var z := Label.new()
	z.text = "Zzz"
	z.add_theme_font_size_override("font_size", 34)
	z.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	z.add_theme_color_override("font_outline_color", Color.BLACK)
	z.add_theme_constant_override("outline_size", 8)
	z.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lv.world_ui.add_child(z)
	z.position = lv.cam.unproject_position(
		kappa.global_position + Vector3(0.0, 1.0, 0.0)) - Vector2(20.0, 0.0)
	var alto0 := z.position.y
	var zt := z.create_tween().set_loops()
	zt.tween_property(z, "position:y", alto0 - 16.0, 1.1)
	zt.parallel().tween_property(z, "modulate:a", 0.15, 1.1)
	zt.tween_callback(func() -> void:
		z.position.y = alto0
		z.modulate.a = 1.0)
	await _pausa(0.7)


func _on_kappa_plato(food: int, tip: int) -> void:
	_oro_fase += food
	_prop_fase += tip


func _on_kappa_hambre() -> void:
	_hambre = true


## El jefe, si ya está en el nivel.
func _kappa() -> Node3D:
	for c in lv.seat_clients:
		if c is Node3D and is_instance_valid(c) and c.who_override == "kappa":
			return c
	return null
