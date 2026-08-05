extends StoryDirector
## Director del TUTORIAL: guion de David Jones (y su loro Gigi) sobre level3d.
## Todo lo común con los guiones de los niveles (pausar el juego al hablar, el
## foco circular, el vigía de inactividad) vive en StoryDirector; aquí solo
## queda el guion y lo propio del tutorial.
##
## El nivel en modo tutorial no termina solo (_end_level ignora reloj y
## clientes): termina este guion, que entrega las 4 recetas
## (GameState.complete_tutorial) y devuelve al menú.

## Asiento del cliente del tutorial: el MÁS ALTO de la pantalla. Con la cámara
## isométrica (yaw 45) la altura en pantalla es -(x+z), y los asientos 0 y 6
## empatan en lo más alto; el 0 está en la cara -Z, que entra por la borda de
## ARRIBA. Los platos tardan lo justo en llegarle desde el emplatado.
const SEAT := 0
## Lo que se alarga el nigiri del tutorial: da tiempo a explicar el té mientras
## el grumete sigue masticando.
const NIGIRI_LENTO := 4.5

var client: Node3D = null


## El cliente del tutorial no se marcha nunca por paciencia: la barra se
## mantiene llena (solo el mochi, que despide, lo hará levantarse).
func _tick(_delta: float) -> void:
	if _cliente_vivo():
		client.patience = client.patience_max
		client.patience_bar_update()


## Espera a que un plato salga a la CINTA. Al salir, el cliente del tutorial
## lo cogerá seguro (sin tirada de dado: aquí no puede fallar el guion).
func _wait_served() -> void:
	await lv.prep_board.dish_served
	if _cliente_vivo():
		client.guaranteed_next = true


## Trae al grumete del tutorial a un asiento FIJO (los demás se tapan un
## instante para que no elija otro).
func _spawn_client() -> void:
	for i in lv.seats.size():
		if i != SEAT and lv.seat_clients[i] == null:
			lv.seat_clients[i] = true
	lv.forced_types.append("E")
	lv._try_spawn_client()
	for i in lv.seats.size():
		if i != SEAT and lv.seat_clients[i] is bool:
			lv.seat_clients[i] = null
	client = lv.seat_clients[SEAT]


func _cliente_vivo() -> bool:
	return client != null and is_instance_valid(client)


# -------------------------------------------------------------------- guion

func _run() -> void:
	var pb: Control = lv.prep_board
	pb.allowed_recipes = ["__nada__"]
	var pname: String = GameState.player_name if GameState.player_name != "" else "grumete"

	# ---- Bienvenida a la cocina y paseo por el HUD ----
	await _say([
		{ "text": "¡Y esta es mi **cocina flotante**! La cinta da la vuelta entera al barco: los platos navegan solos hasta los clientes.", "mood": "feliz" },
		{ "text": "Antes de ponerte el delantal, un vistazo al puente de mando.", "mood": "hablando" },
	])
	await _focus_node(lv.time_label, 24.0)
	await _say([
		{ "text": "Ese reloj marca el **tiempo** del turno. Cada puerto nos deja un rato distinto... hoy lo paro y lo arranco yo a mi antojo, que para eso soy el capitán. ¡JA!", "mood": "riendo" },
	])
	await _focus_node(lv.money_label, 24.0)
	await _say([
		{ "text": "Aquí, el **oro** del turno. Cada plato que un cliente se come lo engorda, y la cifra de al lado es el botín que buscamos.", "mood": "serio" },
		{ "text": "Con ese oro compraremos **ingredientes** en los puertos: sin ingredientes no hay sushi, y sin sushi no hay leyenda.", "mood": "hablando" },
	])
	await _focus_node(lv.jar_label, 24.0)
	await _say([
		{ "text": "Este bote es el de las **propinas**. Cuando se llena, la clientela agradecida te regala un **potenciador**: una ayuda en plena faena. ¡No lo desprecies nunca!", "mood": "feliz" },
	])
	await _focus_node(lv.clients_label, 24.0)
	await _say([
		{ "text": "Y ahí cuento los **clientes** del turno: los atendidos y los que faltan. Cuando pasen todos, se acabó el trabajo.", "mood": "hablando" },
		{ "text": "Una cosa más: cada turno arranca con unos segundos de **preparación**, sin clientes, para ir adelantando platos. Úsalos siempre.", "mood": "serio" },
	])

	# ---- Elegir el maki ----
	pb.allowed_recipes = ["maki_aguacate"]
	await _focus_node(pb.buttons["maki_aguacate"], 12.0)
	await _say_raised([
		{ "text": "¿Ves esos pergaminos de ahí abajo? Son tus **recetas**. Empezaremos por la favorita de los grumetes: toca el **maki de aguacate**.", "mood": "hablando" },
	])
	await _focus_node(pb.buttons["maki_aguacate"], 12.0)
	_play("¡El pergamino del **maki de aguacate**! ¡Ese de ahí abajo!")
	focus_rect.visible = true
	await _wait_craft("select")

	# ---- Elaboración guiada del maki ----
	await _say([
		{ "text": "¡Eso es! Ahora sigue las indicaciones.", "mood": "feliz" },
		{ "text": "Fíjate bien: la **mano** y el **cartel** de la tabla siempre te cantan el paso que toca. Nunca cocinarás a ciegas.", "mood": "hablando" },
		{ "text": "Primero, toca el **arroz** para llevarlo a la tabla.", "mood": "hablando" },
	])
	_play("Toca el **arroz** de la fila de ingredientes.")
	await _wait_craft("tap")
	await _say([
		{ "text": "Ahora dale forma: pulsa **3 veces** sobre el arroz, como amasando.", "mood": "hablando" },
	])
	_play("Pulsa sobre el arroz hasta amasarlo.")
	await _wait_craft("tap", 3)
	await _say([
		{ "text": "¡Así se amasa! Ahora **arrastra** el aguacate hasta la tabla.", "mood": "feliz" },
	])
	_play("Arrastra el **aguacate** hasta la tabla.")
	await _wait_craft("drag")
	await _say([
		{ "text": "Ya casi está. Sigue tú solo las indicaciones de la mano hasta rematar el rollo.", "mood": "serio" },
	])
	_play("Sigue la mano hasta terminar el rollo.")
	await _wait_craft("done")

	# ---- Cinta y cajas ----
	# 0,4 s de margen: felicitarle en el mismo fotograma en que suelta el
	# gesto se sentía atropellado.
	await _say([
		{ "text": "¡Genial! Tu primer maki. Casi me caen las lágrimas.", "mood": "riendo" },
		{ "text": "Ahora tienes dos opciones. Una: arrastrarlo arriba, a la **cinta**, y que navegue hasta los clientes.", "mood": "hablando" },
		{ "text": "Dos: guardarlo en una **caja**, a la derecha. Cada caja apila varios platos **iguales**.", "mood": "hablando" },
		{ "text": "Y eso importa más de lo que parece: acumulando platos puedes soltar **varios de golpe** y llegar también a los clientes que están **lejos** en la cinta, no solo al primero de la fila.", "mood": "serio" },
		{ "text": "Cinta o caja, tú mandas. ¡Coloca ese maki!", "mood": "feliz" },
	], 0.4)
	_play("Lleva el maki a la **cinta** o guárdalo en una **caja**.")
	# ¿Cinta o caja? El guion se adapta a lo que haga el jugador.
	var to_belt := false
	var storage_before: int = pb.stacks.size()
	while true:
		if pb.dishes.is_empty():
			to_belt = pb.stacks.size() == storage_before
			break
		await get_tree().process_frame
	_recordatorio = ""

	# ---- Primer cliente: entra por la borda de abajo y se sienta a la derecha ----
	await get_tree().create_timer(1.5).timeout
	_spawn_client()
	# Un momento para verlo caminar antes de que nadie hable.
	await get_tree().create_timer(1.6).timeout
	_focus_client(client)
	var llegada: Array = [
		{ "text": "¡Atención! Ahí llega nuestro **primer cliente**: un grumete hambriento.", "mood": "sorprendido" },
	]
	if to_belt:
		llegada.append({ "text": "Tu maki ya navega por la cinta: espera a que le llegue... o sigue preparando platos mientras tanto. ¡El tiempo es oro!", "mood": "hablando" })
		await _say(llegada)
	else:
		llegada.append({ "text": "Tu maki espera en la caja: **arrástralo a la cinta** para que le llegue. Desde las cajas se sirve arrastrando, recuérdalo.", "mood": "hablando" })
		await _say(llegada)
		_play("Arrastra el maki de la **caja** a la **cinta**.")
		await _wait_served()
	if _cliente_vivo():
		client.guaranteed_next = true
	pb.allowed_recipes = ["__nada__"]
	await _focus_node(pb.buttons["maki_aguacate"], 12.0)
	await _say_raised([
		{ "text": "Y un secreto de cocina: hay platos que con una elaboración rinden **varios usos**. ¿Ves el **x2** en el pergamino del maki? Los dos siguientes saldrán solos, sin trabajo.", "mood": "feliz" },
	])
	_play()

	# Gigi salta si el jugador insiste con el maki mientras el grumete come.
	var vigilante := { "on": true }
	_vigilar_repeticion(pb, vigilante)

	# Espera a que el grumete coma y pague su primer plato.
	if _cliente_vivo():
		await client.plate_served
	vigilante["on"] = false
	await _focus_node(lv.money_label, 24.0)
	await _say([
		{ "text": "¿Has visto el **oro** subir? Así se hace fortuna: plato comido, doblón ganado.", "mood": "riendo" },
		{ "text": "Y cuanto más elaborado es el plato, más doblones deja. Pero eso lo iremos viendo, no corras.", "mood": "hablando" },
	])

	# ---- Nigiri de salmón (se lo comerá MUY despacio) ----
	pb.allowed_recipes = ["maki_aguacate", "nigiri_salmon"]
	await _focus_node(pb.buttons["nigiri_salmon"], 12.0)
	await _say_raised([
		{ "text": "Vamos con el clásico de los clásicos: el **nigiri de salmón**. Arroz, tres golpes de forma y el lomo encima. Rápido de hacer y deja buen oro.", "mood": "feliz" },
		{ "text": "¡Adelante, demuéstrame esas manos!", "mood": "gritando" },
	])
	await _focus_node(pb.buttons["nigiri_salmon"], 12.0)
	_play("¡El **nigiri de salmón**! Toca su pergamino.")
	focus_rect.visible = true
	await _wait_craft("select")
	_play("Sigue la mano hasta terminar el nigiri.")
	await _wait_craft("done")
	_play("Ahora llévalo a la **cinta**.")
	if _cliente_vivo():
		client.slow_eat = NIGIRI_LENTO
	await _wait_served()
	_play()
	pb.allowed_recipes = ["__nada__"]

	# ---- Gigi explica la barra de comida (el grumete está masticando) ----
	while _cliente_vivo() and not client.is_eating():
		await get_tree().process_frame
	if _cliente_vivo():
		_focus_bar(client.eat_bar())
	await _say([
		{ "text": "¡RAAK! ¿Ves esa barrita de ahí? Es lo que le queda de **bocado**. Mientras baja está comiendo, y no coge NADA más de la cinta.", "who": "gigi", "mood": "loro" },
		{ "text": "¡Cuanto más gordo el plato, más tarda! ¡Y este salmón se lo está tomando con calma, el muy zoquete!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Aprovecha ese rato: mientras uno mastica, tú adelantas el siguiente plato. Ahí está el oficio.", "mood": "loro_resignado" },
	], 0.8)

	# ---- Té verde (sigue comiendo: da tiempo de sobra) ----
	pb.allowed_recipes = ["maki_aguacate", "nigiri_salmon", "te_verde"]
	await _focus_node(pb.buttons["te_verde"], 12.0)
	await _say_raised([
		{ "text": "Y mientras mastica, te enseño el **té verde**. Arrastra las hojas al cuenco y mantén pulsado mientras reposa.", "mood": "hablando" },
		{ "text": "Es un **picoteo**: los clientes pueden cogerlo sin soltar el plato que estén comiendo.", "mood": "serio" },
		{ "text": "Y tiene magia: les quita el **hastío**. Porque repetirle el mismo plato a un cliente lo harta, y cada repetición le sabe a menos. Un té... y vuelve a disfrutarlo como el primer día.", "mood": "hablando" },
		{ "text": "¡Prepara un té y mándalo a la cinta!", "mood": "gritando" },
	])
	await _focus_node(pb.buttons["te_verde"], 12.0)
	_play("¡El **té verde**! Toca su pergamino y sigue la mano.")
	focus_rect.visible = true
	await _wait_craft("select")
	# En cuanto elige la receta el foco sobra: lo que toca ya está en la tabla.
	_clear_focus()
	_recordatorio = "Sigue la mano hasta terminar el té."
	await _wait_craft("done")
	_play("Manda el té a la **cinta**.")
	await _wait_served()
	_play()
	pb.allowed_recipes = ["__nada__"]

	# ---- La barra de paciencia (ya ha terminado de comer) ----
	# Con el té ya servido, el bocado vuelve a su ritmo normal para que el
	# cliente termine y aparezca la barra de paciencia que toca explicar.
	if _cliente_vivo():
		client.slow_eat = 1.0
	while _cliente_vivo() and client.is_eating():
		await get_tree().process_frame
	await get_tree().create_timer(0.7).timeout
	if _cliente_vivo():
		_focus_bar(client.patience_bar())
	await _say([
		{ "text": "Ahora fíjate en esa otra barra de encima de su cabeza: es su **paciencia**.", "mood": "hablando" },
		{ "text": "Cuando no está comiendo, la paciencia BAJA sola. Si se le agota, se levanta y se larga... y si se va sin haber probado nada, encima nos cuesta oro.", "mood": "serio" },
		{ "text": "Cada plato que se come se la vuelve a llenar, y cuanto mejor es el plato, más la llena. Ese es el juego: que ninguna paciencia llegue al fondo.", "mood": "hablando" },
		{ "text": "Y al revés: si lo que quieres es que un cliente **se vaya**, no hay nada como ofrecerle un **postre**. En su caso, un **mochi de matcha**.", "mood": "serio" },
		{ "text": "¡Y este ya lleva un buen rato ahí sentado! ¡RAAAK!", "who": "gigi", "mood": "loro" },
	])

	# ---- Mochi ----
	pb.allowed_recipes = ["maki_aguacate", "nigiri_salmon", "te_verde", "mochi"]
	await _focus_node(pb.buttons["mochi"], 12.0)
	await _say_raised([
		{ "text": "Pues cerremos la faena con el broche dulce: el **mochi de matcha**.", "mood": "feliz" },
		{ "text": "¡ME ENCANTA EL MOCHI! ¡Echa clientes al comerlo! ¡ADIÓS, CLIENTES PESADOS! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "...eso, a su manera. Es un **postre**: propina asegurada, y al terminarlo el cliente se **despide** con la barriga llena y deja la silla libre.", "mood": "loro_resignado" },
		{ "text": "Cada postre tiene su clientela, y el mochi es cosa de grumetes. Amasa la masa, el matcha por encima, y cierra la bola recogiéndola arriba y abajo. ¡Al lío!", "mood": "hablando" },
	])
	await _focus_node(pb.buttons["mochi"], 12.0)
	_play("¡El **mochi de matcha**! Toca su pergamino.")
	focus_rect.visible = true
	await _wait_craft("select")
	_play("Sigue la mano hasta cerrar la bola de mochi.")
	await _wait_craft("done")
	_play("Manda el mochi a la **cinta**.")
	await _wait_served()
	_play()
	pb.allowed_recipes = ["__nada__"]
	# El mochi despide al grumete: se espera a verlo levantarse e irse.
	if _cliente_vivo():
		await client.finished
	client = null
	# Un momento para verlo levantarse y echar a andar antes de hablar.
	await get_tree().create_timer(1.6).timeout
	await _say([
		{ "text": "¿Lo ves? Barriga llena, propina en el bote y silla libre. Un adiós de capitán.", "mood": "riendo" },
		{ "text": "¡Y BIEN QUE SE VA! ¡RAAAK! Escúchame, novato, que esto sí es importante: echar a un cliente antes de tiempo es BUENO.", "who": "gigi", "mood": "loro" },
		{ "text": "¡Uno! Te llevas su **propina** segura y el bote se llena antes: ¡potenciador para ti! ¡Y dos! Un pesado sentado al **principio de la cinta** se zampa todo lo que pasa, y los de más atrás se quedan mirando.", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Por una vez el plumas ha dicho algo sensato. Una silla libre es una silla que puedes volver a llenar.", "mood": "loro_resignado" },
		{ "text": "Y cada plato con truco lo tienes apuntado en el **recetario**, dentro del **Inventario**. Cuando dudes de una receta, consúltalo: ahí está todo.", "mood": "hablando" },
	], -1.0, false)

	# ---- Fin del tutorial ----
	GameState.complete_tutorial()
	await _say([
		{ "text": "¡Lo has hecho de maravilla, %s! Sabía que no me equivocaba contigo." % pname, "mood": "riendo" },
		{ "text": "Estas **4 recetas** ya son tuyas, y te he dejado ingredientes en la despensa para estrenarlas. Con la **Aventura** recorreremos los mares desbloqueando muchas más.", "mood": "feliz" },
		{ "text": "Cuando te veas con manos de veterano se abrirá también el modo **Arcade**: supera el **nivel 5** de la aventura y será tuyo.", "mood": "serio" },
		{ "text": "¡Leva anclas, cocinero! ¡Los siete mares tienen hambre!", "mood": "gritando" },
		{ "text": "¡RAAAK! ¡Y no quemes nada!", "who": "gigi", "mood": "loro" },
	])
	GameState.transition = "menu"
	GameState.fade_to_scene("res://scenes/main_menu.tscn", 0.35, 0.45)


## Corre en paralelo al guion: mientras `estado["on"]`, si el jugador vuelve a
## elegir el maki con el grumete masticando, Gigi le corta.
func _vigilar_repeticion(pb: Control, estado: Dictionary) -> void:
	while estado["on"]:
		var args: Array = await pb.craft_event
		if not estado["on"]:
			return
		if args[0] != "select" or pb.current_recipe != "maki_aguacate":
			continue
		if not _cliente_vivo() or not client.is_eating():
			continue
		await _say([
			{ "text": "¡NO TAN DEPRISA, MEQUETREFE! ¡RAAAK! ¡Que aún está masticando el anterior!", "who": "gigi", "mood": "loro_grito" },
			{ "text": "Tiene razón el plumas: un cliente solo come un plato a la vez. Míralo antes de amontonarle comida delante.", "mood": "loro_resignado" },
		])
