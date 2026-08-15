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
		"nivel_10":
			await _nivel_10()


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
## El `is_inside_tree()` no sobra: al cambiar de escena (salir del nivel, o el
## cartel de resultados) el director se va del árbol con la corrutina a medias,
## y `get_tree()` devolvía null en el siguiente fotograma.
func _esperar(cond: Callable) -> void:
	while is_inside_tree() and not bool(cond.call()):
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
func _adelantar_tipo(tipo: String) -> void:
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
	await _focus_node(lv.prep_board.buttons["nigiri_salmon"], 12.0)
	await _say_raised([
		{ "text": "¡**Cala Tortuga**, tu primer turno de verdad! Cuatro grumetes, y tú al mando de la cinta.", "mood": "feliz" },
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
	await get_tree().create_timer(0.5).timeout
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
	await get_tree().create_timer(0.5).timeout
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
		{ "text": "Llega al objetivo y el turno se cierra solo. Es todo tuyo: ¡a cocinar!", "mood": "riendo" },
	])
	_play()


# ------------------------------------------------------------------- nivel 2
# Playa del Coco: LAS CAJAS DE GUARDADO, y nada más. El primer grumete entra
# solo; cuando se ha comido su SEGUNDO plato (o su paciencia ha bajado un
# tercio) entran los otros TRES DE GOLPE, que es lo que hace evidente el
# problema: un plato en la cinta se lo queda el primero que pase.

## Platos que hay que tener guardados para que la lección de cajas dé el paso.
const CAJAS_PEDIDAS := 3
## Fracción de paciencia del primer cliente a la que entra el refuerzo si aún
## no ha llegado a su segundo plato.
const REFUERZO_PACIENCIA := 2.0 / 3.0

var _cajas_regano := false


func _nivel_2() -> void:
	var pb: Control = lv.prep_board
	# Las cajas se esconden AQUÍ y no en el puerto: así, al repetir el nivel
	# —donde este guion ya no corre— salen desde el primer fotograma.
	pb.hide_storage = true
	pb.refresh_extra_ui()
	await _say([
		{ "text": "**Playa del Coco**. Hoy te voy a enseñar el truco que separa a un cocinero de un friegaplatos.", "mood": "feliz" },
		{ "text": "Ah, y aviso: ayer invitaba la casa. Desde hoy cada receta que embarques gasta **un uso** de sus ingredientes de la **despensa**.", "mood": "serio" },
		{ "text": "Los usos se ganan con cada receta nueva... y más adelante habrá dónde comprarlos. Empieza tranquilo, que de momento solo hay una boca.", "mood": "hablando" },
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

	# --- ...y entran los otros TRES a la vez ---
	for i in 3:
		_adelantar_tipo("E")
	await get_tree().create_timer(1.4).timeout
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
	# Las cajas aparecen AHORA: hasta aquí el nivel iba sin ellas.
	pb.hide_storage = false
	pb.refresh_extra_ui()
	await _focus_node(pb.storage_box, 16.0)
	await _say([
		{ "text": "¡Se nos llena la barra! Y un plato en la cinta se lo queda **el primero que pase**, no el que tú quieras.", "mood": "sorprendido" },
		{ "text": "Para eso están estas dos **cajas**: guardas platos hechos y los sueltas TODOS DE GOLPE cuando te interesa.", "mood": "hablando" },
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
		{ "text": "**Arrecife del Ron**: ocho bocas y de dos en dos. Aquí ya eliges tú la carta... pero solo **tres** recetas.", "mood": "hablando" },
		{ "text": "Con tres recetas y ocho clientes vas a tener que repetir plato. Fíjate en lo que pasa cuando lo hagas.", "mood": "serio" },
	])
	_play()
	_vigilar_basura()
	await _tras_la_preparacion()

	# --- El primer x2 → EL MULTIPLICADOR ---
	await _esperar(func() -> bool: return lv.ended or _mejor_variedad() >= 2)
	if lv.ended:
		return
	var lucido := _cliente_tipo()
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

	# --- Al cerrar el turno: Saverio y la TIENDA ---
	# SOLO SI SE HA APROBADO. El puesto lo abre `unlocks_shop` mirando las
	# estrellas del puerto, así que presentarlo tras un intento fallido dejaba
	# a Saverio invitando a una tienda que sigue cerrada (y `pending_shop_visit`
	# llevaría a una pantalla a la que aún no se puede entrar). Se mide igual
	# que `_finalize_results`: dinero base + propinas contra el umbral de 2★.
	await _esperar(func() -> bool: return lv.ended)
	var aprobado: bool = lv.star_money.size() > 1 \
			and lv._star_money() >= int(lv.star_money[1])
	if aprobado and not GameState.shop_intro_done:
		await _say([
			{ "text": "¡Buen turno! Y mira quién ha estado descargando en el muelle mientras cocinabas...", "mood": "feliz" },
			{ "text": "**Saverio**, el mejor tendero de estos mares. Encantado, cocinero.", "who": "saverio", "mood": "explicando" },
			{ "text": "Yo vendo **usos** de ingredientes, y saco **género nuevo** cada día. A partir de hoy mi puesto es tuyo.", "who": "saverio", "mood": "hablando" },
			{ "text": "¡NEGOCIOS! ¡RAAAK!", "who": "gigi", "mood": "loro" },
			{ "text": "Hasta ahora te he ido surtiendo yo la despensa, %s. Desde este puerto, el género se compra." % GameState.player_title(), "mood": "serio" },
			{ "text": "Anda, pásate por el puesto y échale un ojo. Lo tienes siempre en el **menú**, botón **Tienda**.", "mood": "hablando" },
		])
		GameState.shop_intro_done = true
		# Y el juego lleva al jugador al puesto en cuanto cierre el cartel de
		# resultados (level3d lo mira al salir).
		GameState.pending_shop_visit = true
		GameState.save_game()
	# Si no se cierra a mano, el retrato se queda encima del panel de resultados.
	dialog.close()
	_clear_focus()


# ------------------------------------------------------------------- nivel 5
# Cala del Calamar: LOS POSTRES (el mochi) y, con ellos, las PROPINAS y los
# potenciadores de partida — que se estrenan justo en este nivel.

func _nivel_5() -> void:
	await _focus_node(lv.tip_bar, 20.0)
	await _say([
		{ "text": "¿Ves esa barra azul nueva? Es el **bote de propinas**. Desde hoy, los clientes contentos dejan algo extra.", "mood": "feliz" },
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
# primeros PIRATAS y CAPITANES del juego, con el nigiri de atún para estrenar.

func _nivel_7() -> void:
	await _focus_node(lv.time_label, 24.0)
	await _say([
		{ "text": "¡Esto es un **ABORDAJE**, %s! Aquí sí corre el **reloj**: dos minutos y medio de asalto." % GameState.player_title(), "mood": "gritando" },
		{ "text": "Y la clientela **no se acaba**: mientras quede tiempo, sigue subiendo gente por la borda.", "mood": "serio" },
		{ "text": "Se cierra al agotarse el reloj... o al llegar al **objetivo**. Y cada 10 segundos que sobren, prima extra.", "mood": "hablando" },
		{ "text": "¡AL ABORDAJE! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
	])
	_play()
	await _tras_la_preparacion()

	# --- El primer PIRATA de la campaña ---
	await _esperar(func() -> bool:
		return lv.ended or _progreso() >= TARDIO_PROGRESO \
				or _cliente_tipo("A") != null)
	if lv.ended:
		return
	if _cliente_tipo("A") == null:
		_adelantar_tipo("A")
		await _esperar(func() -> bool:
			return lv.ended or _cliente_tipo("A") != null)
	if lv.ended:
		return
	var pirata := _cliente_tipo("A")
	# Un momento para verlo entrar antes de que nadie hable.
	await get_tree().create_timer(1.4).timeout
	if pirata != null and is_instance_valid(pirata):
		_focus_client(pirata)
	await _say([
		{ "text": "¡ESE NO ES UN GRUMETE! ¡UN **PIRATA** EN LA BARRA! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Hasta hoy solo te habían venido **grumetes**, que comen de **1 estrella**. Se acabó lo fácil.", "mood": "serio" },
		{ "text": "Los **piratas** comen de **2 estrellas** y los **capitanes** de **3**. Cada uno mira las estrellas del plato antes de cogerlo... y pagan en la misma proporción.", "mood": "hablando" },
	])

	# El regalo: una receta de nivel 2 que entra en la tabla en plena partida.
	_regalar_receta("nigiri_atun")
	await _focus_node(lv.prep_board.buttons["nigiri_atun"], 12.0)
	await _say_raised([
		{ "text": "Por eso te traigo el **nigiri de atún**: **dos estrellas**. Tuyo, y te lo pongo en la tabla para que lo estrenes con él.", "mood": "feliz" },
		{ "text": "Las **estrellas** del pergamino son el nivel del plato. Mira siempre quién está sentado antes de servir.", "mood": "serio" },
	])
	_play("¡El **nigiri de atún**! Estrénalo con el pirata.")
	await lv.prep_board.dish_served
	_play()


# ------------------------------------------------------------------- nivel 8
# Flota de Pablo el Rubio: cliente especial, tsuke don y el CORTE LENTO (que
# hasta el rediseño de la escuela se enseñaba con el sashimi del viejo nivel 6).

const RECETA_PABLO := "salmon_tsuke_don"
const AVISO_TSUKE := "¡El **tsuke don**! ¡Córtalo DESPACIO y que se lo pongas al de las gafas!"

var _tsuke_servido := false
var _ensenando_corte := false
var _regano_corte := false


func _nivel_8() -> void:
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
	await get_tree().create_timer(1.4).timeout
	if pablo != null and is_instance_valid(pablo):
		_focus_client(pablo)
	await _say([
		{ "text": "¡Qué barco tan mono tenéis! Se ve pequeñito desde el mío.", "who": "pablo", "mood": "guason" },
		{ "text": "Tú sirve, %s: a este lo conozco, come de **tres estrellas** o no come." % GameState.player_title(), "mood": "hablando" },
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


## El cliente especial del puerto (Pablo el Rubio), si ya está en la barra.
func _pablo() -> Node3D:
	for c in lv.seat_clients:
		if c is Node3D and is_instance_valid(c) and c.who_override == "pablo":
			return c
	return null


# ------------------------------------------------------------------- nivel 10
# Guarida del Kappa: el JEFE. Primero se da de comer a la tripulación; cuando
# hay suficientes barrigas llenas, el Kappa vacía la barra y empieza el duelo:
# BOSS_PLATES platos antes de que su paciencia (que corre deprisa) toque fondo.
# Esta coreografía corre TAMBIÉN en las repeticiones (en mudo): sin ella no
# habría jefe al que ganar.

func _nivel_10() -> void:
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
	await get_tree().create_timer(1.2).timeout
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
