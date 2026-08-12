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
## Lo mismo para el PIRATA del nivel 3, que entra el último de la cola: se le
## adelanta antes que al resto de avisos, que su plato es media partida.
const PIRATA_PROGRESO := 0.6
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
		"nivel_4":
			await _nivel_4()
		"nivel_5":
			await _nivel_5()


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
		{ "text": "¡**Cala Tortuga**, tu primer trabajo! Cuatro grumetes y tus cuatro recetas. Hoy cocinas tú.", "mood": "feliz" },
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
				or lv.elapsed > lv.arrival_span * 0.55)
	if lv.ended:
		return
	if lv.plates_wasted > desperdiciados:
		await _say([
			{ "text": "¡A LA BASURA! ¡RAAAK! ¡Derechito al cubo!", "who": "gigi", "mood": "loro_sorpresa" },
			{ "text": "El plato que da la **vuelta entera** sin que nadie lo coja acaba en la basura, y cuesta oro. Sirve pensando en QUIÉN va a cogerlo.", "mood": "serio" },
		])
	else:
		await _say([
			{ "text": "Vas bien. Un aviso: el plato que da la **vuelta entera** sin que nadie lo coja acaba en la basura y cuesta oro.", "mood": "serio" },
			{ "text": "Nada de inundar la cinta: cada plato, a un cliente que vaya a cogerlo.", "mood": "hablando" },
		])
	_play()

	# Si en algún momento el bote de propinas suelta un potenciador, se explica.
	var potes: int = lv.powerups_claimed
	await _esperar(func() -> bool:
		return lv.ended or lv.powerups_claimed > potes)
	if lv.ended:
		return
	await _say([
		{ "text": "¡ALGO BRILLA! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "El bote de **propinas** se ha llenado: te regalan un **potenciador**. Es de un solo uso, así que gástalo.", "mood": "feliz" },
	])
	_play()


# ------------------------------------------------------------------- nivel 2

## Puerto Corona: el primer PUERTO. Mucha más afluencia, consejos de gestión,
## el castigo por dejar marchar a alguien de vacío y, al cerrar, las primas.
func _nivel_2() -> void:
	await _say([
		{ "text": "¡**Puerto Corona**, %s! Aquí no entra un cliente de vez en cuando: es un goteo constante." % GameState.player_title(), "mood": "feliz" },
		{ "text": "Llena las **cajas** en la preparación, y al que se te atasque en la silla, dale un **mochi**.", "mood": "hablando" },
		{ "text": "¡SITIO PARA EL SIGUIENTE! ¡RAAAK!", "who": "gigi", "mood": "loro" },
	])
	# SAVERIO vive en este puerto: David lo presenta aquí, no al entrar en la
	# tienda. Así el tendero es alguien a quien has conocido antes de comprarle.
	await _say([
		{ "text": "Mira quién descarga en el muelle: **Saverio**, el mejor tendero de estos mares.", "mood": "feliz" },
		{ "text": "Encantado, cocinero. Yo vendo **usos** de ingredientes, y saco género nuevo cada día.", "who": "saverio", "mood": "explicando" },
		{ "text": "Apunta esto: **un uso = una jornada**. Da igual que hagas un nigiri o veinte.", "mood": "serio" },
		{ "text": "Luego habláis, que hoy tienes diez bocas esperando. ¡A la cinta!", "mood": "riendo" },
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
				{ "text": "¡SE NOS VA UNO DE VACÍO! ¡SIN PROBAR BOCADO! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
				{ "text": "Y tiene razón: quien se levanta **sin comer nada** no paga y encima nos cuesta doblones.", "mood": "loro_resignado" },
			])
		else:
			await _say([
				{ "text": "¡Buen botín! Apunta esto: quien se levanta **sin probar nada** no paga y encima cuesta doblones.", "mood": "riendo" },
				{ "text": "Más vale servirle algo barato que dejarlo marchar de vacío.", "mood": "serio" },
			])
		_play()

	# Cierre del turno: las primas por lo que ha sobrado.
	await _esperar(func() -> bool: return lv.ended)
	await _say([
		{ "text": "¡Turno cerrado! Al llegar al **oro objetivo** se cierra la caja... y lo que sobra se paga igual.", "mood": "feliz" },
		{ "text": "Cada cliente al que ya no hizo falta atender cuenta como propina de despedida. Ser rápido paga doble, %s." % GameState.player_title(), "mood": "serio" },
	])
	# Y al cerrar el turno, Saverio invita a su puesto: es el momento en que la
	# TIENDA queda abierta, y de paso deja los extras de regalo.
	await _say([
		{ "text": "¡Buen turno! Mi puesto está aquí al lado: pásate a ver el género cuando quieras.", "who": "saverio", "mood": "feliz" },
		{ "text": "Y llévate mis **extras**. Con cualquiera de los tres, un plato repetido le sabe a **nuevo** al cliente.", "who": "saverio", "mood": "explicando" },
		{ "text": "Pero ojo, que todo se paga: el **jengibre** le limpia el paladar y te cuesta multiplicador; el **wasabi** da propina y le quita paciencia; la **soja** paga mejor y le hace masticar deprisa.", "who": "saverio", "mood": "hablando" },
		{ "text": "Cinco usos de cada uno. Van sobre un plato ya terminado, antes de mandarlo a la cinta.", "who": "saverio", "mood": "hablando" },
		{ "text": "¡Eso es hacer amigos! Ya tienes **tienda**, %s." % GameState.player_title(), "mood": "riendo" },
	])
	for ing in RecipeData.EXTRAS:
		GameState.add_ingredient_uses(ing, GameState.TUTORIAL_GIFT)
	GameState.shop_intro_done = true
	GameState.save_game()
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
	await _focus_extras()
	await _say_raised([
		{ "text": "¡No lo sirvas todavía! Esa esquina de la tabla son los **extras**: van sobre un plato ya terminado.", "mood": "hablando" },
		{ "text": "**Jengibre**: no cuenta como repetido. **Wasabi**: propina más probable. **Soja**: más gorda.", "mood": "serio" },
		{ "text": "¡ECHA WASABI A TODO! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "A todo no, que se gastan. Úsalos donde más renten.", "mood": "loro_resignado" },
	], -1.0, EXTRAS_RAISE)
	_play()
	await _tras_la_preparacion()

	# El pirata va el último en la cola; en cuanto el jugador se lleva el 60% del
	# objetivo, el guion lo adelanta para que dé tiempo a estrenar su receta.
	await _esperar(func() -> bool:
		return lv.ended or _progreso() >= PIRATA_PROGRESO or _hay_pirata())
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
		{ "text": "¡ESE NO ES UN GRUMETE! ¡UN **PIRATA** EN LA BARRA! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Paladar más fino: quiere platos **más elaborados**, y paga bastante mejor.", "mood": "loro_resignado" },
	])

	# El regalo: una receta de nivel 2 que entra en la tabla en plena partida.
	if GameState.unlock_recipe("nigiri_atun"):
		GameState.gift_ingredients_for(["nigiri_atun"], GameState.PORT_GIFT)
		GameState.save_game()
	lv.prep_board.add_recipe("nigiri_atun")
	await _focus_node(lv.prep_board.buttons["nigiri_atun"], 12.0)
	await _say_raised([
		{ "text": "Por eso te traigo el **nigiri de atún**. Tuyo, y te lo pongo en la tabla para que lo estrenes con él.", "mood": "feliz" },
		{ "text": "Las **estrellas** del pergamino son el nivel del plato: grumetes de **1**, piratas de **2**, capitanes de **3**.", "mood": "serio" },
		{ "text": "Mira siempre quién está sentado y dónde: el primero de la cinta se come lo que era para el de atrás.", "mood": "hablando" },
	])
	_play("¡El **nigiri de atún**! Estrénalo con el pirata.")
	# El aviso solo vale hasta que sirva algo.
	await lv.prep_board.dish_served
	_play()

	# Y el truco de la casa: como solo hay UN plato de 2 estrellas para el
	# pirata, el jengibre evita que se le haga repetitivo. Si al jugador le
	# faltan extras, David se los pone.
	var regalados := _reponer_extras()
	await _focus_extras()
	var consejo: Array = [
		{ "text": "Hoy solo llevas **un plato de 2 estrellas**, así que se lo vas a repetir: échale un **extra** y le sabrá a nuevo.", "mood": "serio" },
		{ "text": "El **jengibre** le limpia el paladar entero. El **wasabi** y la **soja** engordan la propina. Ninguno es gratis, pero un plato repetido sin nada encima no vale nada.", "mood": "feliz" },
	]
	if regalados:
		consejo.append({ "text": "¿Andas corto de extras? Toma de mi despensa. ¡Pero no te acostumbres!", "mood": "riendo" })
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
	_adelantar_tipo("A")


## ¿Hay un plato TERMINADO esperando en la tabla?
func _hay_plato_hecho() -> bool:
	return not lv.prep_board.dishes.is_empty()


## Foco sobre la fila de extras de la tabla.
## OJO: espera DOS FOTOGRAMAS antes de medir, igual que `_focus_node`. Los
## contenedores de Godot recolocan a sus hijos de forma DIFERIDA, así que medir
## en el acto daba el rectángulo VIEJO y el círculo caía al lado de los extras.
func _focus_extras() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
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
	])
	# El barco se presenta de entrada, con el foco en su botón: es la novedad
	# del nivel y hay que verla ANTES de ponerse a cocinar. PERO el barco pide
	# su bonificador (ver PerkData "barco"), así que sin él no hay botón que
	# enfocar: David cuenta entonces CÓMO ganárselo, que es lo útil.
	if lv.prep_board.hide_boat:
		await _say([
			{ "text": "Aquí se estrena el **barco combinado**: una bandeja de platos variados que casi nadie deja pasar.", "mood": "feliz" },
			{ "text": "Pero eso hay que ganárselo. Llena **dos cajas con tres platos** cada una en una partida y el barco será tuyo para siempre.", "mood": "serio" },
			{ "text": "Luego lo llevas puesto antes de zarpar, como el resto de mejoras.", "mood": "hablando" },
			{ "text": "¡CAJAS! ¡LLENA LAS CAJAS! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		])
		_play()
		return
	await _focus_boat()
	await _say_raised([
		{ "text": "Ese icono redondo es el **barco combinado**, y hoy lo estrenas.", "mood": "feliz" },
		{ "text": "Junta **cuatro platos** en las cajas, de **dos clases distintas** por lo menos, y se enciende. Luego los arrastras a la bandeja.", "mood": "hablando" },
		{ "text": "Se paga por la **variedad**, y entretiene mucho: mientras come, al cliente no se le acaba la paciencia.", "mood": "serio" },
		{ "text": "Solo admite **nigiris**, **gunkan** y **makis**.", "mood": "hablando" },
		{ "text": "¡BARCO! ¡BARCO! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
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
## Igual que `_focus_extras`: dos fotogramas antes de medir, o el foco cae
## fuera del botón del barco.
func _focus_boat() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var b: Control = lv.prep_board.boat_button
	if b != null and is_instance_valid(b):
		_focus_screen_rect(b.get_global_rect().grow(14.0))


# ------------------------------------------------------------------- nivel 5

## Regalo de David cuando aparece Pablo el Rubio.
const RECETA_PABLO := "salmon_tsuke_don"
## Fracción del objetivo a la que Pablo se adelanta si el jugador va sobrado
## (en este puerto entra el último, y sería una pena que no diera tiempo).
const AVISO_PABLO := 0.8
## Aviso que repite Gigi si el jugador se queda parado con la receta nueva.
const AVISO_TSUKE := "¡El **tsuke don**! ¡Que se lo pongas al de las gafas!"

## ¿Se está enseñando el corte del salmón? Mientras dure, cortar deprisa no
## cuesta dinero (`prep_board.free_mistakes`) y Gigi explica cómo se hace.
var _ensenando_corte := false
var _regano_corte := false
var _tsuke_servido := false


## Flota del capitán Pablo el Rubio: abordaje exprés. Al empezar se presenta
## Pablo (viejo amigo de David, y muy pesado con la broma del puñal), y cuando
## por fin se sienta a la barra David regala el salmón tsuke don.
func _nivel_5() -> void:
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

	# Pablo entra el ÚLTIMO de la cola; si el jugador va sobrado, se adelanta
	# para que dé tiempo a estrenar su receta con él.
	await _esperar(func() -> bool:
		return lv.ended or _hay_pablo() or _progreso() >= AVISO_PABLO)
	if lv.ended:
		return
	if not _hay_pablo():
		_adelantar_tipo("G")
		await _esperar(func() -> bool: return lv.ended or _hay_pablo())
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

	# El regalo: una receta de 3 estrellas que entra en la tabla en marcha.
	if GameState.unlock_recipe(RECETA_PABLO):
		GameState.gift_ingredients_for([RECETA_PABLO], GameState.PORT_GIFT)
		GameState.save_game()
	lv.prep_board.add_recipe(RECETA_PABLO)
	await _focus_node(lv.prep_board.buttons[RECETA_PABLO], 12.0)
	await _say_raised([
		{ "text": "Para eso te traigo el **salmón tsuke don**. Tres estrellas, guardado para una ocasión así.", "mood": "feliz" },
		{ "text": "Lo suyo es el corte del salmón: **despacio**. Si vas con prisa, destrozas el lomo.", "mood": "serio" },
		{ "text": "¡DESPACIO CON EL CUCHILLO! ¡RAAAK!", "who": "gigi", "mood": "loro" },
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

	# El perdón dura hasta que sirve el primer tsuke don (o hasta el final).
	await _esperar(func() -> bool: return lv.ended or _tsuke_servido)
	_ensenando_corte = false
	lv.prep_board.free_mistakes = false
	if lv.ended or not _tsuke_servido:
		return
	await _say([
		{ "text": "¡Vaya, vaya! Esto no me lo esperaba en un barco de este tamaño.", "who": "pablo", "mood": "sorprendido" },
		{ "text": "¿Lo ves? Te lo dije: el chico vale. Y ahora, si me disculpas, voy a cobrarte la broma del puñal.", "mood": "riendo" },
	])
	_play()


## Gigi regaña la PRIMERA vez que el corte del salmón sale demasiado rápido.
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


func _hay_pablo() -> bool:
	return _pablo() != null


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
