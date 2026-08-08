extends StoryDirector
## Director del TUTORIAL: guion de David Jones (y su loro Gigi) sobre level3d.
## Todo lo común con los guiones de los niveles (pausar el juego al hablar, el
## foco circular, el vigía de inactividad) vive en StoryDirector; aquí solo
## queda el guion y lo propio del tutorial.
##
## El nivel en modo tutorial no termina solo (_end_level ignora reloj y
## clientes): termina este guion, que entrega las 4 recetas
## (GameState.complete_tutorial) y devuelve al menú.

## Asiento del cliente del tutorial: el de ARRIBA A LA IZQUIERDA. Con la cámara
## isométrica (yaw 45) la altura en pantalla es -(x+z) y la horizontal es x-z,
## así que los asientos 0 y 6 empatan en lo más alto pero el 0 cae a la derecha
## y el 6 a la izquierda. Se usa el 6 porque el plato le llega ANTES: los platos
## nacen en el vértice +X/+Z y la vuelta pasa por su punto de cinta mucho antes
## que por el del 0. También entra por la borda de arriba.
const SEAT := 6
## Lo que se alarga el nigiri del tutorial: da tiempo a explicar el té mientras
## el grumete sigue masticando.
## El nigiri del tutorial se come LENTÍSIMO a propósito: tiene que durar lo
## bastante como para explicar el té verde, prepararlo y que llegue a la mesa.
## En cuanto el cliente pica el té, vuelve al ritmo normal.
const NIGIRI_LENTO := 14.0

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
	# UNA FRASE POR IDEA. El tutorial se probó con parrafadas de tres y cuatro
	# líneas por foco y se hacía lento y pesado: aquí lo que enseña es el foco,
	# no el texto.
	await _say([
		{ "text": "¡Mi **cocina flotante**! La cinta da la vuelta al barco y los platos llegan solos.", "mood": "feliz" },
	])
	await _focus_node(lv.money_label, 24.0)
	await _say([
		{ "text": "El **oro**: cada plato comido lo engorda. La cifra de al lado es el botín del turno.", "mood": "serio" },
	])
	await _focus_node(lv.jar_label, 24.0)
	await _say([
		{ "text": "Debajo, el bote de **propinas**. Al llenarse te regalan un **potenciador**.", "mood": "feliz" },
	])
	await _focus_node(lv.clients_label, 24.0)
	await _say([
		{ "text": "Y los **clientes** que quedan. Cuando pasen todos, se acabó el trabajo.", "mood": "hablando" },
	])

	# ---- Elegir el maki ----
	# Mientras David habla de las recetas EN GENERAL, la fila entera se enciende
	# (`allowed_recipes` vacío = todas) y el foco las abarca todas: apagadas
	# menos una, el jugador veía tres siluetas grises justo cuando le estaban
	# diciendo "estos son tus pergaminos". Se vuelven a apagar en cuanto toca
	# elegir el maki.
	#
	# La caja se sube UNA vez para las dos tandas (en vez de dos `_say_raised`
	# seguidos): bajándola y volviéndola a subir entre frase y frase, el
	# pergamino daba un bote a media explicación.
	pb.allowed_recipes = []
	dialog.set_raised(true)
	await _focus_nodes(pb.buttons.values(), 16.0)
	await _say([
		{ "text": "Esos pergaminos son tus **recetas**. Navegando aprenderás muchas más.", "mood": "hablando" },
	])
	pb.allowed_recipes = ["maki_aguacate"]
	await _focus_node(pb.buttons["maki_aguacate"], 12.0)
	await _say([
		{ "text": "Empezamos por la favorita de los grumetes: el **maki de aguacate**.", "mood": "hablando" },
	])
	dialog.set_raised(false)
	# PRIMERO `_play` y DESPUÉS el foco: `_play` llama a `_clear_focus`,
	# así que enfocando antes se borraba solo y el jugador se quedaba
	# sin ver señalada ni una receta (poner `focus_rect.visible` no
	# servía de nada: el velo seguía con `dim` a 0).
	_play("¡El pergamino del **maki de aguacate**! ¡Ese de ahí abajo!")
	await _focus_node(pb.buttons["maki_aguacate"], 12.0)
	await _wait_craft("select")

	# ---- Elaboración guiada del maki ----
	# SIN CORTES A MEDIA ELABORACIÓN: David dice una sola cosa —sigue la mano— y
	# se calla hasta que el rollo está hecho. Antes iba comentando paso a paso, y
	# quien cocinaba deprisa terminaba el maki mientras él seguía explicando el
	# paso anterior; el guion se perdía el gesto que esperaba y hacía falta un
	# segundo maki para desatascarlo.
	await _say([
		{ "text": "¡Eso es! La **mano** y el **cartel** te cantan el paso que toca. Síguelos.", "mood": "feliz" },
	])
	_play("Sigue la mano hasta terminar el rollo.")
	await _wait_craft("done")

	# ---- Cinta y cajas ----
	# 0,4 s de margen: felicitarle en el mismo fotograma en que suelta el
	# gesto se sentía atropellado.
	await _say([
		{ "text": "¡Tu primer maki! Ahora, o lo subes a la **cinta**, o lo guardas en una **caja**.", "mood": "riendo" },
		{ "text": "Las cajas apilan platos **iguales**: sueltas varios de golpe y llegas a los clientes de más atrás.", "mood": "hablando" },
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
	# LAS RECETAS SE APAGAN MIENTRAS EL GRUMETE SE SIENTA: si no, el jugador se
	# pone a hacer makis en ese hueco muerto y llega a la explicación siguiente
	# con la tabla y las cajas llenas de platos que el guion no espera.
	pb.allowed_recipes = ["__nada__"]
	await get_tree().create_timer(1.5).timeout
	_spawn_client()
	# Un momento para verlo caminar antes de que nadie hable.
	await get_tree().create_timer(1.6).timeout
	_focus_client(client)
	var llegada: Array = [
		{ "text": "¡Ahí llega tu **primer cliente**! Un grumete hambriento.", "mood": "sorprendido" },
	]
	if to_belt:
		llegada.append({ "text": "Tu maki ya navega hacia él. Mientras, tú puedes ir adelantando otro plato.", "mood": "hablando" })
		await _say(llegada)
	else:
		llegada.append({ "text": "Sácalo de la caja **arrastrándolo a la cinta**: desde las cajas se sirve así.", "mood": "hablando" })
		await _say(llegada)
		# Solo el maki, que es lo que tiene que arrastrar.
		pb.allowed_recipes = ["maki_aguacate"]
		_play("Arrastra el maki de la **caja** a la **cinta**.")
		await _wait_served()
	if _cliente_vivo():
		client.guaranteed_next = true
	# El maki se queda ENCENDIDO: es de lo que se está hablando (con la receta
	# apagada el "x2" se leía sobre un pergamino gris) y además es lo que puede
	# tocar el jugador ahora, que es justo lo que vigila `_vigilar_repeticion`.
	pb.allowed_recipes = ["maki_aguacate"]
	await _focus_node(pb.buttons["maki_aguacate"], 12.0)
	await _say_raised([
		{ "text": "¿Ves el **x2** del maki? Hay platos que rinden **varios usos**: los dos siguientes salen solos.", "mood": "feliz" },
	])
	_play()

	# TRES DESENLACES, y ninguno obliga a nada: el jugador tiene un maki gratis
	# entre las manos y el grumete comiendo. Si no hace nada, el guion sigue sin
	# comentar nada; si lo manda a la cinta, Gigi le corta; y si lo guarda,
	# David le da la razón. Es la primera decisión que toma solo.
	var vigilante := { "on": true }
	_vigilar_maki_libre(pb, vigilante)
	_vigilar_maki_a_la_cinta(pb, vigilante)

	# Espera a que el grumete coma y pague su primer plato.
	if _cliente_vivo():
		await client.plate_served
	vigilante["on"] = false
	await _focus_node(lv.money_label, 24.0)
	await _say([
		{ "text": "¡El **oro** sube! Plato comido, doblón ganado... y cuanto mejor el plato, más deja.", "mood": "riendo" },
	])

	# ---- Nigiri de salmón (se lo comerá MUY despacio) ----
	pb.allowed_recipes = ["maki_aguacate", "nigiri_salmon"]
	await _focus_node(pb.buttons["nigiri_salmon"], 12.0)
	await _say_raised([
		{ "text": "Ahora el clásico: **nigiri de salmón**. Más trabajo, más oro. ¡Demuéstrame esas manos!", "mood": "feliz" },
	])
	# PRIMERO `_play` y DESPUÉS el foco: `_play` llama a `_clear_focus`,
	# así que enfocando antes se borraba solo y el jugador se quedaba
	# sin ver señalada ni una receta (poner `focus_rect.visible` no
	# servía de nada: el velo seguía con `dim` a 0).
	_play("¡El **nigiri de salmón**! Toca su pergamino.")
	await _focus_node(pb.buttons["nigiri_salmon"], 12.0)
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
		{ "text": "¡RAAK! Esa barra **azul** es su **bocado**. Mientras baja, no coge nada más de la cinta.", "who": "gigi", "mood": "loro" },
		{ "text": "Aprovecha: mientras uno mastica, tú adelantas el siguiente plato. Ahí está el oficio.", "mood": "loro_resignado" },
	], 0.8)

	# ---- Té verde (sigue comiendo: da tiempo de sobra) ----
	pb.allowed_recipes = ["maki_aguacate", "nigiri_salmon", "te_verde"]
	await _focus_node(pb.buttons["te_verde"], 12.0)
	await _say_raised([
		{ "text": "Mientras mastica, el **té verde**: es un **picoteo**, se coge sin soltar el plato.", "mood": "hablando" },
		{ "text": "Y quita el **hastío**: repetirle un plato a un cliente lo harta, y el té le limpia el paladar.", "mood": "serio" },
	])
	# PRIMERO `_play` y DESPUÉS el foco: `_play` llama a `_clear_focus`,
	# así que enfocando antes se borraba solo y el jugador se quedaba
	# sin ver señalada ni una receta (poner `focus_rect.visible` no
	# servía de nada: el velo seguía con `dim` a 0).
	_play("¡El **té verde**! Toca su pergamino y sigue la mano.")
	await _focus_node(pb.buttons["te_verde"], 12.0)
	await _wait_craft("select")
	# En cuanto elige la receta el foco sobra: lo que toca ya está en la tabla.
	_clear_focus()
	_recordatorio = "Sigue la mano hasta terminar el té."
	await _wait_craft("done")
	_play("Manda el té a la **cinta**.")
	await _wait_served()
	_play()
	pb.allowed_recipes = ["__nada__"]
	# EL BOCADO AGUANTA HASTA QUE LE LLEGA EL TÉ. Es justo lo que hay que
	# enseñar: un picoteo se coge SIN soltar lo que ya se está comiendo. Antes
	# se cortaba en cuanto el té salía a la cinta y el jugador no llegaba a ver
	# al cliente cogerlo (`snack_taken` es la marca de que lo ha pillado).
	while _cliente_vivo() and client.is_eating() and not client.snack_taken:
		await get_tree().process_frame

	# ---- La barra de paciencia (ya ha terminado de comer) ----
	# CON EL TÉ YA PICADO, el bocado se acelera. El nigiri se sirvió con
	# `slow_eat` altísimo para que diera tiempo a explicar el té, pero eso solo
	# se aplica al EMPEZAR el plato: en cuanto el picoteo ha cumplido su papel
	# quedaba casi un minuto de barra bajando a cámara lenta. `bite_speed` sí
	# actúa sobre el bocado en marcha, así que la barra se vacía a buen ritmo en
	# vez de pegar un salto.
	if _cliente_vivo():
		client.slow_eat = 1.0
		client.bite_speed = 10.0
	while _cliente_vivo() and client.is_eating():
		await get_tree().process_frame
	await get_tree().create_timer(0.7).timeout
	if _cliente_vivo():
		_focus_bar(client.patience_bar())
	await _say([
		{ "text": "Esa otra barra es su **paciencia**. Si no come, baja: verde, ámbar, roja... y se larga.", "mood": "hablando" },
		{ "text": "Cada plato se la rellena, y cuanto mejor es, más. Que ninguna llegue al fondo.", "mood": "serio" },
	])

	# ---- Mochi ----
	pb.allowed_recipes = ["maki_aguacate", "nigiri_salmon", "te_verde", "mochi"]
	await _focus_node(pb.buttons["mochi"], 12.0)
	await _say_raised([
		{ "text": "¡MOCHI! ¡Al comérselo se LARGAN! ¡ADIÓS, PESADOS! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "...a su manera, sí. Es un **postre**: propina segura y el cliente se despide. ¡Al lío!", "mood": "loro_resignado" },
	])
	# PRIMERO `_play` y DESPUÉS el foco: `_play` llama a `_clear_focus`,
	# así que enfocando antes se borraba solo y el jugador se quedaba
	# sin ver señalada ni una receta (poner `focus_rect.visible` no
	# servía de nada: el velo seguía con `dim` a 0).
	_play("¡El **mochi de matcha**! Toca su pergamino.")
	await _focus_node(pb.buttons["mochi"], 12.0)
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
		{ "text": "Barriga llena, propina en el bote y **silla libre**. Echar clientes a tiempo es BUENO.", "mood": "riendo" },
		{ "text": "¡Y TANTO! ¡Un pesado al principio de la cinta se zampa todo lo que pasa! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Lo que dudes de una receta, míralo en el **recetario** del **Inventario**.", "mood": "hablando" },
	], -1.0, false)

	# ---- Fin del tutorial ----
	GameState.complete_tutorial()
	await _say([
		{ "text": "¡De maravilla, %s! Estas **4 recetas** son tuyas, con ingredientes para estrenarlas." % pname, "mood": "riendo" },
		{ "text": "¡Leva anclas! En la **Aventura** desbloquearás muchas más.", "mood": "gritando" },
		{ "text": "¡RAAAK! ¡Y no quemes nada!", "who": "gigi", "mood": "loro" },
	])
	GameState.transition = "menu"
	GameState.fade_to_scene("res://scenes/main_menu.tscn", 0.35, 0.45)


## Corre en paralelo al guion mientras el grumete come su primer maki y el
## jugador tiene el segundo (el del "x2") libre. Reacciona A LO QUE HAGA:
##
##   · lo manda a la CINTA  → Gigi le corta: el cliente ya está comiendo.
##   · lo guarda en la CAJA → David le da la razón: eso es tener cabeza.
##   · no hace nada         → ni una palabra, el guion sigue.
##
## Solo habla UNA vez (`estado["on"]` se apaga al hablar y el guion lo apaga
## también al terminar el plato): repetir el aviso con cada maki convertía un
## consejo en una regañina.
func _vigilar_maki_libre(pb: Control, estado: Dictionary) -> void:
	var guardados: int = pb.stored_count("maki_aguacate")
	while bool(estado["on"]):
		await get_tree().process_frame
		if not bool(estado["on"]):
			return
		if pb.stored_count("maki_aguacate") > guardados:
			estado["on"] = false
			await _say([
				{ "text": "¡Muy bien pensado! A la **caja**, que ahí espera sin estropearse.", "mood": "feliz" },
				{ "text": "Cuando se te junte la clientela, ese maki ya está hecho y sale en un suspiro.", "mood": "hablando" },
			])
			_play()
			return


## Y si en vez de guardarlo lo suelta a la cinta, Gigi salta. Va aparte porque
## se engancha a `dish_served`, no al fotograma.
func _vigilar_maki_a_la_cinta(pb: Control, estado: Dictionary) -> void:
	while bool(estado["on"]):
		await pb.dish_served
		if not bool(estado["on"]):
			return
		if not _cliente_vivo() or not client.is_eating():
			continue
		estado["on"] = false
		await _say([
			{ "text": "¡EH, EH, EH! ¡RAAAK! ¡Que ese ya está masticando! ¡No necesita otro!", "who": "gigi", "mood": "loro_grito" },
			{ "text": "El plumas tiene razón: guárdalo en una **caja** y sírvelo cuando haga falta.", "mood": "loro_resignado" },
		])
		_play()
		return
