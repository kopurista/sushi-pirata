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

## Fracción del dinero objetivo a partir de la cual el cliente TARDÍO del
## nivel (el pirata del 3, el capitán del 6, Pablo en el 8) se adelanta para
## que dé tiempo a estrenar su lección.
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


# ------------------------------------------------------------------ utilidades

## Espera a que se cumpla una condición, sin bloquear el juego.
func _esperar(cond: Callable) -> void:
	while not bool(cond.call()):
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


# ------------------------------------------------------------------- nivel 1
# Cala Tortuga: la clase completa sobre el PRIMER cliente — paciencia, bocado,
# regalo del nigiri, multiplicador de variedad y el oro. Guion del usuario.

func _nivel_1() -> void:
	await _say([
		{ "text": "¡**Cala Tortuga**, tu primer turno de verdad! Cuatro grumetes, y hoy invita la casa: sin gastos.", "mood": "feliz" },
		{ "text": "Empieza con lo que dominas: el **maki de aguacate**. Yo te voy soplando el resto.", "mood": "hablando" },
	])
	_play()
	await _tras_la_preparacion()

	# --- El maki servido → la barra de PACIENCIA ---
	var servido := { "on": false }
	lv.prep_board.dish_served.connect(
		func(_r: String, _p: int, _e: Array, _n: int, _m: float) -> void:
			servido["on"] = true,
		CONNECT_ONE_SHOT)
	await _esperar(func() -> bool:
		return lv.ended or (bool(servido["on"]) and _cliente_tipo() != null))
	if lv.ended:
		return
	var alumno := _cliente_tipo()
	# Que se le vea la barra (sentado y esperando) antes de señalarla.
	await _esperar(func() -> bool:
		return lv.ended or not is_instance_valid(alumno) \
				or alumno.patience_bar().visible)
	if lv.ended or not is_instance_valid(alumno):
		return
	_focus_bar(alumno.patience_bar())
	await _say([
		{ "text": "¿Ves esa barra? Es su **paciencia**: si no come, baja... y al fondo, se larga sin pagar.", "mood": "serio" },
		{ "text": "Cada plato que se come se la rellena. Que ninguna barra llegue al fondo: esa es la mitad del oficio.", "mood": "hablando" },
	])
	_play()

	# --- Comiendo → la barra de BOCADO ---
	await _esperar(func() -> bool:
		return lv.ended or not is_instance_valid(alumno) or alumno.is_eating())
	if lv.ended or not is_instance_valid(alumno):
		return
	_focus_bar(alumno.eat_bar())
	await _say([
		{ "text": "¡RAAK! La barra **azul** es su **bocado**: mientras baja, mastica y NO gasta paciencia.", "who": "gigi", "mood": "loro" },
		{ "text": "Ese rato es tuyo: mientras uno mastica, tú adelantas el siguiente plato.", "mood": "loro_resignado" },
	], 0.6)

	# --- Regalo del NIGIRI: y por ahora, SOLO el nigiri ---
	_regalar_receta("nigiri_salmon")
	lv.prep_board.allowed_recipes = ["nigiri_salmon"]
	await _focus_node(lv.prep_board.buttons["nigiri_salmon"], 12.0)
	await _say_raised([
		{ "text": "Regalo de bienvenida: el **nigiri de salmón**. Más trabajo que el maki... y mejor pagado.", "mood": "feliz" },
		{ "text": "Olvida el maki un momento: ahora quiero verte SOLO con el nigiri. ¡Manos a la obra!", "mood": "hablando" },
	])
	_play("¡El **nigiri de salmón**! Prepáralo y mándalo a la cinta.")

	# --- El x2 → multiplicador y paladar ---
	# El "x2" salta cuando un cliente empieza un plato NUNCA probado teniendo ya
	# otro en el cuerpo: con la tabla limitada al nigiri acaba pasando solo (si
	# el primer nigiri se lo lleva un recién llegado, ese queda a x1 y el guion
	# sigue esperando al que repite mesa).
	var estrella: Node3D = null
	await _esperar(func() -> bool:
		if lv.ended:
			return true
		for c in lv.seat_clients:
			if c is Node3D and is_instance_valid(c) and c.variety >= 2:
				estrella = c
				return true
		return false)
	if lv.ended or estrella == null:
		return
	# El respiro que pidió el diseño: el x2 acaba de aparecer en su chapa.
	await get_tree().create_timer(0.2).timeout
	_focus_client(estrella)
	await _say([
		{ "text": "¡Mira su chapa: **x2**! Es el **multiplicador de variedad**: cada plato que ese cliente prueba POR PRIMERA VEZ lo sube.", "mood": "feliz" },
		{ "text": "Con la chapa alta, cada plato nuevo paga **oro extra** y recarga más paciencia. Repetirle plato, en cambio, lo aburre.", "mood": "serio" },
		{ "text": "Aún sabes pocas recetas, así que no te agobies con esto: ya crecerá tu carta... y con ella, las rachas.", "mood": "riendo" },
	])
	_play()

	# --- El pago → el ORO ---
	if is_instance_valid(estrella) and estrella.is_eating():
		await estrella.plate_served
	await _focus_node(lv.money_label, 24.0)
	await _say([
		{ "text": "¡Y ahí está el **oro**! Cada plato comido suma su precio; la cifra de al lado es el **objetivo** del turno.", "mood": "feliz" },
		{ "text": "Al alcanzarlo, turno cerrado y a otra cosa. El oro compra ingredientes en los puertos: es la sangre del barco.", "mood": "serio" },
	])
	# Clase terminada: tabla libre (maki y nigiri) y a jugar.
	lv.prep_board.allowed_recipes = []
	await _say([
		{ "text": "El resto del turno es tuyo, y el maki vuelve a la tabla. ¡A por esos grumetes!", "mood": "gritando" },
		{ "text": "¡Y NO LA LÍES! ¡RAAAK!", "who": "gigi", "mood": "loro" },
	])
	_play()


# ------------------------------------------------------------------- nivel 2
# Playa del Coco: las CAJAS de guardado, el HASTÍO, el té verde y el mochi.

func _nivel_2() -> void:
	# Las cajas son la novedad visible: se presentan antes de cocinar nada.
	await _focus_node(lv.prep_board.storage_box, 16.0)
	await _say([
		{ "text": "¡**Playa del Coco**! Hoy estrenas herramienta: esas son tus **cajas de guardado**.", "mood": "feliz" },
		{ "text": "Cada caja apila platos **iguales**: cocina de más en los ratos tranquilos y suéltalos cuando se junte la clientela.", "mood": "hablando" },
		{ "text": "Un plato terminado se **arrastra** a la caja; desde la caja, se arrastra a la cinta. Úsalas en la preparación.", "mood": "serio" },
	])
	_play()
	await _tras_la_preparacion()

	# --- El primer plato REPETIDO → el hastío y el té verde ---
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
		{ "text": "¿Has visto? Ese plato era **repetido** y apenas le ha recargado paciencia: es el **hastío**.", "mood": "serio" },
		{ "text": "Repetir una vez recarga poco; a la tercera, nada; y de ahí en adelante hasta le QUITA barra.", "mood": "hablando" },
	])
	# El remedio, recién salido de mi despensa: el té verde.
	_regalar_receta("te_verde")
	await _focus_node(lv.prep_board.buttons["te_verde"], 12.0)
	await _say_raised([
		{ "text": "El remedio: **té verde**. Es un **picoteo** — lo cogen SIN soltar el plato que comen — y les limpia el **paladar**.", "mood": "feliz" },
		{ "text": "Con el paladar limpio, todo vuelve a contar como nuevo. Barato y milagroso.", "mood": "hablando" },
	])
	_play()

	# --- La silla atascada → el mochi ---
	await _esperar(func() -> bool:
		if lv.ended:
			return true
		if lv.clients_finished >= 2:
			return true
		for c in lv.seat_clients:
			if c is Node3D and is_instance_valid(c) \
					and c.patience < c.patience_max * 0.5:
				return true
		return false)
	if lv.ended:
		return
	_regalar_receta("mochi")
	await _focus_node(lv.prep_board.buttons["mochi"], 12.0)
	await _say_raised([
		{ "text": "Última lección de hoy: el **mochi**. Es un **postre**: al comérselo, el cliente paga, deja propina segura... y **se despide**.", "mood": "hablando" },
		{ "text": "¡FUERA! ¡SITIO PARA EL SIGUIENTE! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Eso. Un cliente que ya te dio lo suyo ocupa una silla que otro pagaría: el postre es la cuenta.", "mood": "loro_resignado" },
	])
	_play()


# ------------------------------------------------------------------- nivel 3
# Puerto Corona: el primer PIRATA (y, vía prep_dialog, el primer selector y el
# primer nivel que gasta despensa).

func _nivel_3() -> void:
	await _say([
		{ "text": "**Puerto Corona**. Fíjate bien en quién baja del bote hoy...", "mood": "hablando" },
		{ "text": "¡HUELO A PIRATA! ¡RAAAK!", "who": "gigi", "mood": "loro" },
	])
	_play()
	await _tras_la_preparacion()

	# El pirata va el último en la cola; si el jugador va sobrado, se adelanta
	# para que dé tiempo a estrenar su receta con él.
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
	_focus_client(pirata)
	await _say([
		{ "text": "¡ESE NO ES UN GRUMETE! ¡UN **PIRATA** EN LA BARRA! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Cada cliente tiene su paladar: los **grumetes** comen de 1 estrella, los **piratas** de 2... y pagan bastante mejor.", "mood": "loro_resignado" },
	])

	# El regalo: una receta de nivel 2 que entra en la tabla en plena partida.
	_regalar_receta("nigiri_atun")
	await _focus_node(lv.prep_board.buttons["nigiri_atun"], 12.0)
	await _say_raised([
		{ "text": "Por eso te traigo el **nigiri de atún**. Tuyo, y te lo pongo en la tabla para que lo estrenes con él.", "mood": "feliz" },
		{ "text": "Las **estrellas** del pergamino son el nivel del plato. Mira siempre quién está sentado antes de servir.", "mood": "serio" },
	])
	_play("¡El **nigiri de atún**! Estrénalo con el pirata.")
	await lv.prep_board.dish_served
	_play()


# ------------------------------------------------------------------- nivel 4
# Arrecife del Ron: el puerto grande. Saverio se presenta, el castigo por
# dejar marchar a alguien de vacío, y al cerrar: la TIENDA y los EXTRAS.

func _nivel_4() -> void:
	await _say([
		{ "text": "**Arrecife del Ron**: siete bocas, el turno más largo hasta la fecha. Llena las cajas en la preparación.", "mood": "hablando" },
		{ "text": "Y mira quién descarga en el muelle: **Saverio**, el mejor tendero de estos mares.", "mood": "feliz" },
		{ "text": "Encantado, cocinero. Yo vendo **usos** de ingredientes. Supera este puerto y hablamos de negocios.", "who": "saverio", "mood": "explicando" },
		{ "text": "¡NEGOCIOS! ¡RAAAK!", "who": "gigi", "mood": "loro" },
	])
	_play()
	await _tras_la_preparacion()

	# El cliente que se va de vacío se explica EN CALIENTE si pasa; si no, en
	# tono amable cuando ya se lleva buena parte del botín.
	_vistos = lv.client_reports.size()
	await _esperar(func() -> bool:
		return lv.ended or _alguien_se_fue_de_vacio() or _progreso() >= 0.7)
	if not lv.ended:
		if _progreso() < 0.7:
			await _say([
				{ "text": "¡SE NOS VA UNO DE VACÍO! ¡SIN PROBAR BOCADO! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
				{ "text": "Y sale caro: quien se levanta **sin comer nada** no paga y encima cuesta doblones. Un plato barato a tiempo lo evita.", "mood": "loro_resignado" },
			])
		else:
			await _say([
				{ "text": "¡Buen botín! Apunta: quien se va **sin probar nada** no paga y encima cuesta doblones. Que nadie se quede a cero.", "mood": "serio" },
			])
		_play()

	# Al cerrar el turno, Saverio abre su puesto: la TIENDA queda presentada y
	# los EXTRAS, regalados (la compuerta de verdad es shop_intro_done).
	await _esperar(func() -> bool: return lv.ended)
	await _say([
		{ "text": "¡Buen turno, cocinero! Trato hecho: mi puesto queda abierto. Lo tienes en el **menú**, botón **Tienda**.", "who": "saverio", "mood": "feliz" },
		{ "text": "Cada día saco **género nuevo**; los usos que me compres van a tu despensa.", "who": "saverio", "mood": "explicando" },
		{ "text": "Y de estreno, mis **extras**: jengibre, wasabi y soja. Con cualquiera de los tres, un plato repetido cuenta como **nuevo**.", "who": "saverio", "mood": "hablando" },
		{ "text": "Van sobre el plato ya terminado, en la esquina de la tabla. Cinco usos de cada, invita la casa.", "who": "saverio", "mood": "hablando" },
		{ "text": "¡Eso es hacer amigos! Ya tienes **tienda**, %s." % GameState.player_title(), "mood": "riendo" },
	])
	for ing in RecipeData.EXTRAS:
		GameState.add_ingredient_uses(ing, GameState.TUTORIAL_GIFT)
	GameState.shop_intro_done = true
	GameState.save_game()
	# Si no se cierra a mano, el retrato se queda encima del panel de resultados.
	dialog.close()
	_clear_focus()


# ------------------------------------------------------------------- nivel 5
# Cala del Calamar: el BOTE DE PROPINAS y los potenciadores de partida.

func _nivel_5() -> void:
	await _focus_node(lv.tip_bar, 20.0)
	await _say([
		{ "text": "¿Ves esa barra azul nueva? Es el **bote de propinas**. Desde hoy, los clientes contentos dejan algo extra.", "mood": "feliz" },
		{ "text": "La propina NO es oro del objetivo: va al bote. Y cuando el bote se llena...", "mood": "hablando" },
		{ "text": "¡REGALO! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "...te dan a elegir un **potenciador**: una ayuda para el resto del turno. Sirve bien y el bote se llena solo.", "mood": "riendo" },
	])
	_play()
	await _tras_la_preparacion()

	# La primera vez que el bote suelta potenciador (y ya está elegido).
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
# Bahía del Kraken: el primer CAPITÁN, el sashimi de atún rojo y el CORTE
# LENTO (con las equivocaciones perdonadas mientras se aprende).

const RECETA_CAPITAN := "sashimi_atun_rojo"
const AVISO_SASHIMI := "¡El **sashimi de atún rojo**! ¡Córtalo DESPACIO y a la cinta!"

var _ensenando_corte := false
var _regano_corte := false
var _sashimi_servido := false


func _nivel_6() -> void:
	await _say([
		{ "text": "**Bahía del Kraken**. Hoy atraca alguien con galones... y con paladar de oro.", "mood": "hablando" },
	])
	_play()
	await _tras_la_preparacion()

	# El capitán entra el último; si el jugador va sobrado, se adelanta.
	await _esperar(func() -> bool:
		return lv.ended or _progreso() >= TARDIO_PROGRESO \
				or _cliente_tipo("G") != null)
	if lv.ended:
		return
	if _cliente_tipo("G") == null:
		_adelantar_tipo("G")
		await _esperar(func() -> bool:
			return lv.ended or _cliente_tipo("G") != null)
	if lv.ended:
		return
	var capitan := _cliente_tipo("G")
	await get_tree().create_timer(1.4).timeout
	_focus_client(capitan)
	await _say([
		{ "text": "¡FIRMES! ¡UN **CAPITÁN** EN LA BARRA! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
		{ "text": "Paladar de tres estrellas: los platos de menos casi ni los mira. Pero cuando come... paga como nadie.", "mood": "serio" },
	])

	# El regalo: la primera receta de 3 estrellas, con corte LENTO.
	_regalar_receta(RECETA_CAPITAN)
	await _focus_node(lv.prep_board.buttons[RECETA_CAPITAN], 12.0)
	await _say_raised([
		{ "text": "Para él, el **sashimi de atún rojo**: tu primera receta de **tres estrellas**.", "mood": "feliz" },
		{ "text": "Su secreto es el **corte lento**: de izquierda a derecha, SIN prisa, hasta llenar la barra. Correr destroza el lomo.", "mood": "serio" },
		{ "text": "Hoy, si te sale mal, no te cuesta oro: estás aprendiendo.", "mood": "riendo" },
	])
	# Mientras aprende el corte, equivocarse sale gratis (pero Gigi regaña).
	_ensenando_corte = true
	lv.prep_board.free_mistakes = true
	if not lv.prep_board.slice_failed.is_connected(_on_corte_fallado):
		lv.prep_board.slice_failed.connect(_on_corte_fallado)
	if not lv.prep_board.dish_served.is_connected(_on_plato_servido):
		lv.prep_board.dish_served.connect(_on_plato_servido)
	_play(AVISO_SASHIMI)

	# El perdón dura hasta que sirve el primer sashimi (o hasta el final).
	await _esperar(func() -> bool: return lv.ended or _sashimi_servido)
	_ensenando_corte = false
	lv.prep_board.free_mistakes = false
	if lv.ended or not _sashimi_servido:
		return
	await _say([
		{ "text": "¡Corte de cocinero de verdad! A partir de ahora, ojo: el corte con prisa SÍ cuesta oro.", "mood": "feliz" },
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
	_play(AVISO_SASHIMI)


func _on_plato_servido(recipe_id: String, _precio: int, _extras: Array,
		_nivel: int, _comer: float = 0.0) -> void:
	if recipe_id == RECETA_CAPITAN:
		_sashimi_servido = true
	if recipe_id == RECETA_PABLO:
		_tsuke_servido = true


# ------------------------------------------------------------------- nivel 7
# Estrecho del Rayo: el primer ABORDAJE — reloj, clientela sin fin y la prima
# por el tiempo sobrante.

func _nivel_7() -> void:
	await _focus_node(lv.time_label, 24.0)
	await _say([
		{ "text": "¡Esto es un **ABORDAJE**, %s! Aquí sí corre el **reloj**: dos minutos y medio de asalto." % GameState.player_title(), "mood": "gritando" },
		{ "text": "Y la clientela **no se acaba**: mientras quede tiempo, sigue subiendo gente por la borda.", "mood": "serio" },
		{ "text": "Se cierra al agotarse el reloj... o al llegar al **objetivo**. Y cada 10 segundos que sobren, prima extra.", "mood": "hablando" },
		{ "text": "¡AL ABORDAJE! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
	])
	_play()


# ------------------------------------------------------------------- nivel 8
# Flota de Pablo el Rubio: cliente especial, tsuke don y su corte aprendido.

const RECETA_PABLO := "salmon_tsuke_don"
const AVISO_TSUKE := "¡El **tsuke don**! ¡Que se lo pongas al de las gafas!"

var _tsuke_servido := false


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
	_focus_client(pablo)
	await _say([
		{ "text": "¡Qué barco tan mono tenéis! Se ve pequeñito desde el mío.", "who": "pablo", "mood": "guason" },
		{ "text": "Tú sirve, %s: a este lo conozco, come de **tres estrellas** o no come." % GameState.player_title(), "mood": "hablando" },
	])

	# El regalo: el tsuke don, con el corte lento que ya domina del nivel 6.
	_regalar_receta(RECETA_PABLO)
	await _focus_node(lv.prep_board.buttons[RECETA_PABLO], 12.0)
	await _say_raised([
		{ "text": "Para eso te traigo el **salmón tsuke don**. Tres estrellas, guardado para una ocasión así.", "mood": "feliz" },
		{ "text": "Lleva el **corte lento** que ya dominas... y un reposo en soja que lo borda. ¡A la tabla!", "mood": "serio" },
	])
	if not lv.prep_board.dish_served.is_connected(_on_plato_servido):
		lv.prep_board.dish_served.connect(_on_plato_servido)
	_play(AVISO_TSUKE)

	await _esperar(func() -> bool: return lv.ended or _tsuke_servido)
	if lv.ended or not _tsuke_servido:
		return
	await _say([
		{ "text": "¡Vaya, vaya! Esto no me lo esperaba en un barco de este tamaño.", "who": "pablo", "mood": "sorprendido" },
		{ "text": "¿Lo ves? Te lo dije: el chico vale. Y ahora, si me disculpas, voy a cobrarte la broma del puñal.", "mood": "riendo" },
	])
	_play()


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
