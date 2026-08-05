extends StoryDirector
## Guion de David Jones DENTRO de los primeros niveles de la campaña. A
## diferencia del tutorial, aquí el jugador juega de verdad: el director solo
## se asoma en momentos concretos (y al hacerlo pausa el juego entero, igual
## que en el tutorial) para presentar mecánicas nuevas.
##
## Qué nivel se narra lo dice el campo `director` del puerto en CampaignData.
## Un puerto sin ese campo no monta director ninguno.

## Fracción del dinero objetivo a partir de la cual se consideran "bien
## encaminados" y saltan las explicaciones que no dependen de un suceso.
const AVISO_PROGRESO := 0.7
## Cuánto sube la caja para hablar de los EXTRAS: viven en la esquina alta de
## la tabla, más arriba que la fila de recetas.
const EXTRAS_RAISE := 470.0
## Usos que regala David de cada extra que le falte al jugador.
const EXTRAS_REGALO := 2

var guion := ""
## Clientes ya revisados en client_reports (para pillar al que se va de vacío).
var _vistos := 0


func _run() -> void:
	guion = str(CampaignData.get_port(GameState.current_port).get("director", ""))
	match guion:
		"nivel_1":
			await _nivel_1()
		"nivel_2":
			await _nivel_2()
		"nivel_3":
			await _nivel_3()


# ------------------------------------------------------------------ utilidades

## Espera a que se cumpla una condición, sin bloquear el juego.
func _esperar(cond: Callable) -> void:
	while not bool(cond.call()):
		await get_tree().process_frame


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


# ------------------------------------------------------------------- nivel 1

## Cala Tortuga: primer nivel libre. David deja jugar y solo interviene para
## explicar qué pasa cuando un plato da la vuelta entera sin que nadie lo coja.
func _nivel_1() -> void:
	await _say([
		{ "text": "¡Bienvenido a **Cala Tortuga**, tu primer trabajo de verdad! Cuatro grumetes y las cuatro recetas que te enseñé.", "mood": "feliz" },
		{ "text": "Hoy mando yo menos y cocinas tú más. Yo te aviso si veo algo que debas saber.", "mood": "hablando" },
		{ "text": "¡Y NO LA LÍES! ¡RAAAK!", "who": "gigi", "mood": "loro" },
	])
	# IMPRESCINDIBLE soltar el reloj antes de esperar a nada del nivel: con
	# `clock_hold` puesto `elapsed` no avanza, así que la fase de preparación no
	# terminaba nunca y el guion se quedaba colgado sin que llegara un cliente.
	_play()
	await _tras_la_preparacion()

	# Lo suyo es explicarlo EN CALIENTE, la primera vez que se pierde un plato;
	# si el jugador no tira ninguno, se cuenta igual a media partida.
	var desperdiciados: int = lv.plates_wasted
	await _esperar(func() -> bool:
		return lv.ended or lv.plates_wasted > desperdiciados \
				or lv.elapsed > lv.time_limit * 0.55)
	if lv.ended:
		return
	if lv.plates_wasted > desperdiciados:
		await _say([
			{ "text": "¡RAAAK! ¡A LA BASURA! ¡Ese plato ha ido derechito al cubo!", "who": "gigi", "mood": "loro_sorpresa" },
			{ "text": "Eso es lo que pasa cuando un plato da la **vuelta entera** a la cinta sin que nadie lo coja: acaba en la basura de la esquina.", "mood": "sorprendido" },
			{ "text": "Y no sale gratis: te llevas un mordisco en el oro por el género echado a perder. Sirve pensando en QUIÉN va a cogerlo, no por llenar la cinta.", "mood": "serio" },
		])
	else:
		await _say([
			{ "text": "Vas bien, cocinero. Un consejo antes de que te confíes.", "mood": "hablando" },
			{ "text": "Si un plato da la **vuelta entera** a la cinta sin que nadie lo coja, cae en la basura de la esquina... y te cuesta oro.", "mood": "serio" },
			{ "text": "Así que nada de inundar la cinta: cada plato, a un cliente que vaya a cogerlo.", "mood": "hablando" },
		])
	_play()

	# Si en algún momento el bote de propinas suelta un potenciador, se explica.
	var potes: int = lv.powerups_claimed
	await _esperar(func() -> bool:
		return lv.ended or lv.powerups_claimed > potes)
	if lv.ended:
		return
	await _say([
		{ "text": "¡RAAAK! ¡ALGO BRILLA! ¡LA CLIENTELA HA SOLTADO ALGO!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "¡Se ha llenado el bote de las **propinas**! Cuando eso pasa, la clientela agradecida te regala un **potenciador**.", "mood": "feliz" },
		{ "text": "Son ayudas de un solo uso para la faena: acelerar la **cinta**, cocinar sin esperas, sacar dos platos de golpe... Elige el que te saque del apuro en ese momento.", "mood": "hablando" },
		{ "text": "Y no lo guardes para luego: el turno se acaba y lo que no gastas no vale nada.", "mood": "serio" },
	])
	_play()


# ------------------------------------------------------------------- nivel 2

## Puerto Corona: el primer PUERTO. Mucha más afluencia, consejos de gestión,
## el castigo por dejar marchar a alguien de vacío y, al cerrar, las primas.
func _nivel_2() -> void:
	await _say([
		{ "text": "¡**Puerto Corona**! Esto ya son palabras mayores, %s." % GameState.player_title(), "mood": "feliz" },
		{ "text": "En un **puerto** no entra un cliente de vez en cuando: entra un **goteo constante**. Hoy son diez grumetes, y no te van a esperar en fila.", "mood": "serio" },
		{ "text": "Dos trucos de capitán. Uno: llena las **cajas** durante la preparación y suelta varios platos de golpe cuando se te junten los clientes.", "mood": "hablando" },
		{ "text": "Dos: si alguien se te atasca en la silla, dale un **mochi**. Se va contento, te deja la propina y libera el sitio para el siguiente.", "mood": "hablando" },
		{ "text": "¡SITIO PARA EL SIGUIENTE! ¡RAAAK!", "who": "gigi", "mood": "loro" },
	])
	_play()
	await _tras_la_preparacion()

	# Lo del cliente que se va de vacío se explica EN CALIENTE si pasa; si no
	# pasa, se cuenta en tono amable cuando ya se lleva buena parte del botín.
	_vistos = lv.client_reports.size()
	await _esperar(func() -> bool:
		return lv.ended or _alguien_se_fue_de_vacio() \
				or _progreso() >= AVISO_PROGRESO)
	if not lv.ended:
		if _progreso() < AVISO_PROGRESO:
			await _say([
				{ "text": "¡SE NOS VA UNO DE VACÍO! ¡RAAAK! ¡SIN PROBAR BOCADO! ¡QUÉ VERGÜENZA PARA ESTE BARCO!", "who": "gigi", "mood": "loro_grito" },
				{ "text": "Cálmate, plumas... pero tiene razón. Un cliente que se levanta **sin haber comido nada** no solo no paga: encima nos cuesta doblones.", "mood": "loro_resignado" },
				{ "text": "Cuanto más importante el cliente, más caro sale el desaire. Que no se te quede nadie mirando la cinta vacía.", "mood": "serio" },
			])
		else:
			await _say([
				{ "text": "¡Así se hace! Llevas ya buena parte del botín.", "mood": "riendo" },
				{ "text": "Ya que va bien, apunta esto para cuando venga mal dada: si un cliente se levanta **sin haber probado nada**, además de no pagar, nos cuesta doblones.", "mood": "hablando" },
				{ "text": "Más vale servirle algo barato que dejarlo marchar de vacío. Recuérdalo.", "mood": "serio" },
			])
		_play()

	# Cierre del turno: las primas por lo que ha sobrado.
	await _esperar(func() -> bool: return lv.ended)
	await _say([
		{ "text": "¡Turno cerrado! Y ahora la parte que más me gusta: la cuenta.", "mood": "feliz" },
		{ "text": "Cuando juntas el **oro objetivo** antes de tiempo, cerramos la caja ahí mismo... y todo lo que sobra se te paga igual.", "mood": "hablando" },
		{ "text": "Cada cliente al que ya **no hizo falta atender** cuenta como propina de despedida —cuanto más importante, más deja—, y cada trozo de **tiempo** que sobra también se paga.", "mood": "serio" },
		{ "text": "¡LOS CLIENTES NO ME GUSTAN, PERO SU DINERO SÍ! ¡RAAAK! ¡Y el dinero de los que ni vienen me gusta AÚN MÁS!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Por una vez, el bicho lo ha resumido mejor que yo. Ser rápido paga doble, %s." % GameState.player_title(), "mood": "loro_resignado" },
	])
	# El guion termina aquí: si no se cierra a mano, el retrato y el pergamino
	# se quedan clavados encima del panel de resultados.
	dialog.close()
	_clear_focus()


# ------------------------------------------------------------------- nivel 3

## Isla del Mono: llega el primer PIRATA. David presenta el tipo de cliente,
## regala el nigiri de atún en plena partida y explica el nivel de los platos.
func _nivel_3() -> void:
	await _say([
		{ "text": "**Isla del Mono**. Poca clientela hoy, pero fíjate bien en quién baja del bote.", "mood": "hablando" },
	])
	_play()

	# Los EXTRAS se explican con el plato RECIÉN TERMINADO en la tabla, antes de
	# que el jugador lo coloque: es el único momento en que se pueden usar.
	await _esperar(func() -> bool: return lv.ended or _hay_plato_hecho())
	if lv.ended:
		return
	_focus_extras()
	await _say_raised([
		{ "text": "¡Alto ahí, no lo sirvas todavía! Mira la esquina de tu tabla: los **extras**.", "mood": "hablando" },
		{ "text": "Se le echan a un plato **ya terminado**, justo antes de mandarlo a la cinta, y se gastan por plato servido.", "mood": "serio" },
		{ "text": "El **jengibre** limpia el paladar: ese plato no le cuenta al cliente como repetido, así que le sabe a nuevo.", "mood": "hablando" },
		{ "text": "El **wasabi** hace más **probable** que te dejen propina, y la **soja** hace que, cuando cae, caiga más **gorda**.", "mood": "hablando" },
		{ "text": "¡ECHA WASABI A TODO! ¡RAAAK! ¡A TODO!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "A todo no, plumas, que se gastan. Úsalos donde más renten.", "mood": "loro_resignado" },
	], -1.0, EXTRAS_RAISE)
	_play()
	await _tras_la_preparacion()

	# El pirata va el último en la cola; si el jugador va sobrado, se adelanta.
	await _esperar(func() -> bool:
		return lv.ended or _progreso() >= AVISO_PROGRESO or _hay_pirata())
	if lv.ended:
		return
	if not _hay_pirata():
		_adelantar_pirata()
		await _esperar(func() -> bool: return lv.ended or _hay_pirata())
	if lv.ended:
		return
	var pirata := _pirata()
	# Un momento para verlo entrar antes de que nadie hable.
	await get_tree().create_timer(1.4).timeout
	_focus_client(pirata)
	await _say([
		{ "text": "¡RAAAK! ¡ESE NO ES UN GRUMETE! ¡MIRA QUÉ PINTA! ¡UN **PIRATA** EN LA BARRA!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Tranquilo, plumas, que muerden poco. Pero tiene razón: eso es un **pirata**, y no come como un grumete.", "mood": "loro_resignado" },
		{ "text": "Tiene el paladar más fino: prefiere platos **más elaborados**, y por eso también paga bastante mejor.", "mood": "serio" },
	])

	# El regalo: una receta de nivel 2 que entra en la tabla en plena partida.
	if GameState.unlock_recipe("nigiri_atun"):
		GameState.gift_ingredients_for(["nigiri_atun"], GameState.PORT_GIFT)
		GameState.save_game()
	lv.prep_board.add_recipe("nigiri_atun")
	await _focus_node(lv.prep_board.buttons["nigiri_atun"], 12.0)
	await _say_raised([
		{ "text": "Por eso te traigo esto: el **nigiri de atún**. Tuyo desde ya, y te lo pongo en la tabla ahora mismo para que lo estrenes con él.", "mood": "feliz" },
		{ "text": "Fíjate en las **estrellas** de cada pergamino: son el nivel del plato.", "mood": "hablando" },
		{ "text": "Los **grumetes** van a lo suyo, a los platos de **1 estrella**. Los **piratas** prefieren los de **2**, aunque de vez en cuando pican de 1 o de 3.", "mood": "serio" },
		{ "text": "Y los **capitanes** —como un servidor— venimos por los de **3 estrellas**; los de 2 los cogemos, pero con menos ganas.", "mood": "riendo" },
		{ "text": "Así que mira siempre **quién está sentado y dónde**: el plato sale de tu tabla y va parando delante de cada silla. Manda el bueno al cliente bueno... y no dejes que el primero de la cinta se coma lo que era para el de atrás.", "mood": "hablando" },
	])
	_play("¡El **nigiri de atún**! Estrénalo con el pirata.")
	# El aviso solo vale hasta que sirva algo.
	await lv.prep_board.dish_served
	_play()

	# Y el truco de la casa: como solo hay UN plato de 2 estrellas para el
	# pirata, el jengibre evita que se le haga repetitivo. Si al jugador le
	# faltan extras, David se los pone.
	var regalados := _reponer_extras()
	_focus_extras()
	var consejo: Array = [
		{ "text": "Un consejo de capitán para este puerto: hoy solo llevas **un plato de 2 estrellas** para el pirata, así que se lo vas a repetir sí o sí.", "mood": "serio" },
		{ "text": "Échale **jengibre** al **nigiri de atún** y el plato no le contará como repetido: le sabrá a nuevo cada vez.", "mood": "hablando" },
		{ "text": "Y si encima le pones **wasabi** o **soja**, la propina será más probable y más gorda. Ahí es donde se hace el dinero de verdad.", "mood": "feliz" },
	]
	if regalados:
		consejo.append({ "text": "¿Que andas corto de extras? Toma de mi despensa, invita la casa. ¡Pero no te acostumbres!", "mood": "riendo" })
		consejo.append({ "text": "¡NO TE ACOSTUMBRES! ¡RAAAK!", "who": "gigi", "mood": "loro" })
	await _say_raised(consejo, -1.0, EXTRAS_RAISE)
	_play()


func _pirata() -> Node3D:
	for c in lv.seat_clients:
		if c is Node3D and is_instance_valid(c) and c.client_type == "A":
			return c
	return null


func _hay_pirata() -> bool:
	return _pirata() != null


## Saca al pirata de la cola y lo manda al principio, para que entre ya.
func _adelantar_pirata() -> void:
	for i in lv.type_queue.size():
		if lv.type_queue[i] == "A":
			lv.type_queue.remove_at(i)
			lv.type_queue.push_front("A")
			break
	lv._try_spawn_client()


## ¿Hay un plato TERMINADO esperando en la tabla?
func _hay_plato_hecho() -> bool:
	return not lv.prep_board.dishes.is_empty()


## Foco sobre la fila de extras de la tabla.
func _focus_extras() -> void:
	var botones: Dictionary = lv.prep_board.extra_buttons
	var r := Rect2()
	var primero := true
	for id in botones:
		var b: Control = botones[id]
		if not is_instance_valid(b):
			continue
		r = b.get_global_rect() if primero else r.merge(b.get_global_rect())
		primero = false
	if not primero:
		_focus_screen_rect(r.grow(14.0))


## Repone los extras que le falten al jugador. Devuelve true si ha regalado algo.
func _reponer_extras() -> bool:
	var dado := false
	for ing in RecipeData.EXTRAS:
		if GameState.get_ingredient_uses(ing) <= 0:
			GameState.add_ingredient_uses(ing, EXTRAS_REGALO)
			dado = true
	if dado:
		GameState.save_game()
		lv.prep_board.refresh_extra_ui()
	return dado


# ------------------------------------------------------------------- nivel 4

## Arrecife del Ron: se estrena el BARCO combinado. David lo presenta en cuanto
## el jugador tiene platos guardados suficientes como para que le interese.
func _nivel_4() -> void:
	await _say([
		{ "text": "**Arrecife del Ron**. Dos piratas hoy, y vienen por el **atún**.", "mood": "hablando" },
		{ "text": "Antes de nada: si te falta algún ingrediente, date una vuelta por la **tienda** de Saverio antes de zarpar. Sin género no hay plato.", "mood": "serio" },
	])
	# El barco se presenta de entrada, con el foco en su botón: es la novedad
	# del nivel y hay que verla ANTES de ponerse a cocinar.
	_focus_boat()
	await _say_raised([
		{ "text": "¡Oye! ¿Has visto esta función nueva? Ese icono redondo de ahí abajo es el **barco combinado**, y hoy lo estrenas.", "mood": "feliz" },
		{ "text": "Junta **cuatro platos** en las cajas, de al menos **dos clases distintas**, y el botón se enciende.", "mood": "hablando" },
		{ "text": "Al pulsarlo te saca los platos a la tabla: solo tienes que **arrastrarlos a la bandeja** uno a uno. Cuando esté cargada, sale a la cinta como un solo plato.", "mood": "hablando" },
		{ "text": "Y aquí está el truco: el barco se paga por la **variedad**. Cuantas más clases distintas lleve, más prima. Cuatro clases valen mucho más que cuatro platos iguales.", "mood": "serio" },
		{ "text": "¡BARCO! ¡BARCO! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Guarda variado durante la preparación y suéltalo cuando se te junte la clientela. Es la mejor forma de servir a varios de golpe.", "mood": "hablando" },
	], -1.0, EXTRAS_RAISE)
	_play()


## Cuántos platos hay guardados en las cajas (`stacks` va por hueco: cada uno
## con su receta y cuántas unidades apila).
func _platos_guardados() -> int:
	var n := 0
	var cajas: Dictionary = lv.prep_board.stacks
	for hueco in cajas:
		n += int(cajas[hueco].count)
	return n


## Foco sobre el botón del barco combinado.
func _focus_boat() -> void:
	var b: Control = lv.prep_board.boat_button
	if b != null and is_instance_valid(b):
		_focus_screen_rect(b.get_global_rect().grow(14.0))
