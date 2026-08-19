extends "res://scripts/level_select3d.gd"
## Menú principal Y mapa de campaña en UNA SOLA ESCENA.
##
## Hereda el mapa marítimo entero (mar, ruta, nodos de campaña, barco, cámara
## y su interfaz) y le añade el estado "menú": el barco fondeado en mar abierto
## MUY POR DEBAJO del nivel 1 —fuera del encuadre—, con el logotipo, los
## botones de modo, gaviotas y nubes.
##
## Así la transición a Aventura es de verdad: no se cambia de escena, el barco
## navega desde su fondeadero hasta el último nivel abierto y la interfaz del
## mapa entra en su sitio. Volver atrás desanda el camino.

## Fondeadero del menú, en píxeles de mapa: lo bastante por debajo del nivel 1
## como para que ningún nodo de campaña asome por arriba.
## Fondeadero del barco en modo MENÚ: muy por debajo del nivel 1 para que
## ningún nodo del mapa asome. Va atado a `CampaignData.MAP_POS["nivel_1"]`:
## al entrar el nivel 10 la ruta entera bajó un MAP_STEP (215 px) y este ancla
## bajó lo mismo, o el nivel 1 asomaba por arriba estando en el menú.
const MENU_ANCHOR := Vector2(360.0, 4424.0)
## Cuánto se sube la vista respecto al barco cuando manda el menú. POSITIVO =
## el barco queda por ENCIMA del centro de pantalla: desde que el logotipo se
## quedó en la portada, el barco es quien ocupa su hueco de arriba y los
## botones suben tras él.
const MENU_BAND_OFF := 130.0

## LA PORTADA ("pulsa para zarpar") vive en ESTA MISMA ESCENA: es un tercer
## estado, con el barco atracado en un puerto a la IZQUIERDA del fondeadero.
## Al zarpar no hay fundido: la cámara viaja con el barco hasta el menú, igual
## que el viaje a Aventura. `PORT_OFF` va por `cam_side`, que ya es el
## desplazamiento lateral del encuadre (lo usa la transición a la tienda).
## Punto DEL BARCO (coordenadas locales suyas) del que cuelga el sedal de la
## pesca. Despejado contra `FishingGame.ROD_TIP` con el barco en reposo: es esa
## misma punta, pero atada al casco en vez de al lienzo (ver `_process`).
const ROD_LOCAL := Vector3(0.0, -0.537, 1.744)

const PORT_OFF := -1500.0
const PORT_PX := MENU_ANCHOR + Vector2(PORT_OFF, 0.0)
## En la portada la vista se centra por ENCIMA del barco (px de mapa): arriba
## manda el logotipo y el barco queda en el tercio de abajo, contra el muelle.
const START_CAM_LIFT := 380.0
## Lo que dura el viaje del muelle al fondeadero al zarpar.
const START_SAIL := 1.9
const OUT_TIME := 0.55
## Distancia (en px de mapa) que recorre el barco al entrar o salir de escena.
const OFFSCREEN := 1500.0
## Segundos que tarda en armarse el botón "¡Ese soy yo!" del cartel de
## tripulación: se llega hasta ahí pasando diálogo a toques y el toque de
## inercia se saltaba la ficha entera.
const FICHA_ARMADO := 0.9
## En el menú el barco es el protagonista y se ve mucho más grande que como
## ficha del mapa.
const MENU_SHIP_SCALE := 2.75
## Tienda: dónde acaba el muelle (u), lo que navega el barco a su encuentro y
## dónde queda el encuadre al cerrar el zoom (px de mapa; 85.3 px = 1 u).
## Calibrado para que en el zoom quepan el barco entero Y el muelle: el barco
## del menú es grande y con `size` 7.5 el puerto se quedaba fuera de cuadro.
const SHOP_DOCK_AT := 7.9
const SHOP_SAIL := 300.0
const SHOP_ZOOM_SIDE := 430.0
const SHOP_ZOOM_SIZE := 9.4
## SUBMENÚ inferior: la barra de madera oscura con cuerda (`submenu_barra.png`,
## estilo propio, distinto de los tablones) con los CINCO accesos del jugador:
## Logros, Inventario, Perfil, Bonificadores y Opciones. Sustituye a los dos
## botones redondos de esquina que hubo antes.
## La textura se exporta al alto EXACTO al que se dibuja (148) y va con margen
## vertical CERO: la regla de los botones con icono (los márgenes 9-slice son
## téxeles 1:1). Solo estira a lo ancho.
## Tablón del menú: menu_panel.png se exporta a 520x711 y se dibuja a
## MENU_PANEL_W. El hueco interior (donde van los botones) está MEDIDO sobre
## el PNG por barrido de filas; si se regenera el panel hay que volver a
## medirlo. El timón asoma WHEEL_PEEK por encima del banner.
const MENU_PANEL_W := 400.0
const MENU_PANEL_RATIO := 748.0 / 520.0
## El hueco llega hasta la franja donde vivía el ANCLA pintada (~0.845): con
## CUATRO pergaminos (entró "Pesca") los 0.66 de antes se quedaban cortos
## (426 px de botones en 380 de hueco) y el ancla se retiró — existía
## justamente porque esa franja quedaba vacía.
const MENU_PANEL_INNER := Rect2(0.085, 0.10, 0.83, 0.745)
const WHEEL_SIZE := 172.0
## Alto y rollos del pergamino de los botones de modo (boton_pergamino.png,
## exportado a 96 con los rollos midiendo ~46 en el PNG).
const MODE_BTN_H := 96.0
const MODE_BTN_ROLL := 46
const WHEEL_PEEK := 86.0

const SUB_BAR_H := 148.0
const SUB_BAR_MARGIN := 56
const SUB_ICON := 62.0
const SUB_LABEL := 24.0
## Margen bajo la barra. `safe_bottom()` vale 0 en la build web (que es como se
## juega en el iPhone), así que lleva su propio aire.
const SUB_BOTTOM := 10.0
## Aire de los contadores de arriba respecto al área segura.
const RES_TOP := 16.0

var logo: TextureRect
## El logotipo vive dentro de este contenedor: el balanceo mueve el logo y las
## transiciones mueven el contenedor, para que no peleen por `position:y`.
var logo_holder: Control = null
var logo_float: Tween = null
var logo_sway: Tween = null
var ui_layer: CanvasLayer = null
var button_box: VBoxContainer = null
## El pergamino de AVENTURA, guardado aparte: la guía post-tutorial lo señala
## (ver _guiar_a_aventura).
var aventura_btn: Control = null
## Botones redondos de las esquinas: la rueda de ajustes abajo a la derecha y
## la medalla de los logros arriba a la izquierda.
var submenu_bar: Control = null
## El tablón del menú (los tres modos dentro) y el timón del huevo de pascua.
var menu_panel: Control = null
var wheel: TextureRect = null
var wheel_grab := false
var wheel_last_ang := 0.0
var wheel_vel := 0.0
## Radianes girados acumulados (da igual el sentido): cada vuelta completa se
## abona a la estadística "helm_turns", de la que sale el COLECCIONABLE del
## timón (5 vueltas, cuentan también las de la inercia y las de otros días).
var wheel_turn_acc := 0.0
## Contadores de arriba (dinero y arroz). Son los MISMOS en el menú y en el
## mapa: solo cambian de sitio (ver `_place_resources`).
var money_box: Control = null
var rice_box: Control = null
var ingot_box: Control = null
## Cuenta atrás del próximo saco, debajo de la caja del arroz.
var rice_timer_label: Label = null
var res_y := 0.0
var res_tween: Tween = null
## Acumulador para refrescar la cuenta atrás del arroz una vez por segundo.
var _rice_tick := 0.0
## true mientras se ve el menú (con el mapa fuera de pantalla).
var in_menu := true
## Mientras hay una transición en marcha no se aceptan más pulsaciones.
var leaving := false
## La PESCA montada sobre el menú (misma escena, ver `_go_fishing`).
var fishing_ui: Control = null
## EL TIRON DEL PEZ SACUDE LA CAMARA (senal `FishingGame.rush_changed`):
## `cam_shake` son pixeles de lienzo de temblor y `cam_zoom` va de 0 a 1
## para acercarla un pelin. `cam_size_base` guarda el encuadre de antes,
## que el menu cambia `cam.size` en sus transiciones y no se puede
## suponer cual era.
var cam_shake := 0.0
var cam_zoom := 0.0
var cam_size_base := 0.0
var rush_tween: Tween = null
var birds: Array = []
var clouds: Array = []
## Mientras las gaviotas y las nubes se retiran, `_process` deja de colocarlas.
var sky_leaving := false
## Metros de MÁS por encima de su sitio (la entrada del cielo). `_process` lo
## SUMA al colocarlas cada fotograma y un tween lo funde a cero: así entran
## planeando desde arriba sin que el tween pelee con la colocación por frame
## (la misma trampa que obligó a `sky_leaving` en la salida, resuelta al revés:
## en vez de parar la colocación, se anima el desvío que se le suma).
var sky_drop := 0.0
var _mt := 0.0
## Tween de entrada/salida de la interfaz del menú (uno solo a la vez).
var ui_tween: Tween = null
## Posición de reposo de cada bloque de interfaz. Hay que guardarla al
## construirla: después de una salida, la posición actual ya está desplazada.
var home_logo_y := 96.0
var home_box_y := 0.0
var home_sub_y := 0.0
## 1 = encuadre de menú, 0 = encuadre de mapa. Se interpola durante el viaje
## para que la cámara no dé un salto al cambiar de estado.
var menu_blend := 1.0
## true mientras se ve la PORTADA (el puerto y "Pulsa para zarpar").
var start_mode := false
## El "Pulsa para zarpar", latiendo bajo el logotipo.
var start_hint: Label = null
## Desplazamiento lateral del encuadre (px de mapa). Lo usa la transición a la
## tienda para que la cámara siga al barco mientras atraca.
var cam_side := 0.0


func _ready() -> void:
	var trans := GameState.take_transition()
	# Sin portada por delante, quien vuelva al menú SIN tutorial va a la
	# bienvenida de David. Solo puede pasar por un camino raro: el arranque
	# normal de una partida nueva pasa por la portada, que ya manda allí.
	# ("ficha" es justo el caso contrario: se viene de la intro del caos a
	# rellenar el cartel de tripulación SOBRE este menú, y el tutorial se da por
	# hecho al aplicarlo. Sin esta salvedad, rebotaba de vuelta al caos.)
	if not GameState.tutorial_done and GameState.booted and trans != "ficha":
		GameState.fade_out(0.0)
		# DIFERIDO a propósito: cambiar de escena dentro de _ready pilla al árbol
		# montando nodos y el motor suelta "Parent node is busy adding/removing
		# children".
		_ir_a_la_intro.call_deferred()
		return
	# El padre monta el mundo del mapa entero y su interfaz.
	super._ready()
	# El puerto de la portada, alrededor de su ancla. Se construye SIEMPRE
	# (también al volver de otras pantallas): queda fuera del encuadre del
	# menú y así el estado de portada nunca depende de por dónde se entró.
	var port := StartPort.build(self, _world(PORT_PX))
	GeometryBatch.bake(port, "PortBatch")
	_setup_birds()
	_setup_clouds()
	_setup_menu_ui()
	# Un frame para que el layout resuelva y `home_*` valga algo: las
	# animaciones de entrada lo necesitan.
	await get_tree().process_frame
	# Posición REAL de reposo, ya con el layout hecho (`Control.position` es
	# relativo a la esquina superior izquierda del padre, no al ancla: guardar
	# lo que se le PASA al ancla hacía que la salida tirara hacia arriba).
	home_sub_y = submenu_bar.position.y
	home_box_y = menu_panel.position.y
	# ARRANQUE EN FRÍO (sin transición y sin haber zarpado en esta sesión):
	# la PORTADA. `GameState.booted` es de sesión, no se guarda: al volver de
	# cualquier pantalla ya no se pasa otra vez por el puerto.
	if trans == "" and not GameState.booted:
		_show_start()
		return
	match trans:
		"mapa":
			# Se vuelve del selector de recetas de aventura: directo al mapa.
			_enter_map(false)
		"ficha":
			# Se viene de la intro del caos: David se presenta AQUÍ, sobre el
			# mismo mar del menú, y la interfaz no aparece hasta que el cartel
			# de tripulación está relleno.
			_show_ficha()
			return
		"menu":
			_show_menu(false)
			_play_menu_intro()
		_:
			_show_menu(false)
	_menu_popups()


## Carteles del menú (recetas nuevas y bonus diario). En la PORTADA no salen:
## se enseñan al LLEGAR al menú, que es cuando el jugador está en casa.
func _menu_popups() -> void:
	# La GUÍA post-tutorial va la primera: David señala el pergamino de
	# Aventura y no suelta al jugador hasta que lo toca. Los demás carteles
	# esperan a la siguiente visita (la guía acaba saliendo del menú).
	if GameState.tutorial_done and not GameState.menu_intro_done:
		_guiar_a_aventura.call_deferred()
		return
	# Recetas recién ganadas (tutorial o nivel): el menú las anuncia. Se espera
	# a que termine de entrar la interfaz para no montar dos animaciones juntas.
	if not GameState.pending_reveal.is_empty():
		var nuevas: Array = GameState.pending_reveal.duplicate()
		GameState.pending_reveal.clear()
		await get_tree().create_timer(0.9).timeout
		_show_reveal(nuevas)
	# TRAS SUPERAR EL NIVEL 1: David felicita, explica las estrellas y sus
	# recompensas, e invita al puerto siguiente. Va ANTES del bonus diario.
	if GameState.tutorial_done and not GameState.level1_outro_done \
			and int(GameState.level_stars.get("nivel_1", 0)) >= 2:
		await get_tree().create_timer(0.7).timeout
		await _felicitar_nivel_1()
		# Y AQUÍ el arroz, con el contador ya en 19: es el momento en que el
		# gasto se puede señalar en vez de anunciarse.
		await _explicar_arroz()
	# EL NIVEL DE COCINERO SE EXPLICA AL LLEGAR AL 2, no en un escenario
	# concreto: es la primera vez que la barra ha subido de verdad y hay algo
	# que señalar. Va antes que las maestrías, que llegan en el 5.
	if GameState.tutorial_done and not GameState.nivel_intro_done \
			and GameState.chef_level >= 2:
		await get_tree().create_timer(0.7).timeout
		await _explicar_nivel_cocinero()
	# LAS MAESTRÍAS SE PRESENTAN AL LLEGAR AL NIVEL 5 DE COCINERO, no antes: es
	# cuando el jugador tiene ya un puñado de puntos sin gastar y la pantalla
	# tiene algo que enseñar. Al cerrar, David lo lleva DIRECTO al árbol (mismo
	# patrón que Saverio con su puesto).
	if GameState.tutorial_done and not GameState.skills_intro_done \
			and GameState.chef_level >= SKILLS_INTRO_LEVEL:
		await get_tree().create_timer(0.7).timeout
		await _presentar_maestrias()
		return
	# PABLO PAGA LO QUE COMIÓ. La promesa se hace en su nivel y el pago se cobra
	# AQUÍ, con las tres cajas de recursos a la vista: es la primera vez que el
	# jugador oye hablar de los lingotes y David puede señalarle el contador de
	# arriba mientras se lo cuenta.
	if GameState.pending_ingots > 0:
		await get_tree().create_timer(0.7).timeout
		await _pagar_pablo()
	# ESCENAS DE COLECCIONABLE que se quedaran a medias (el jugador cerró el
	# juego con una pendiente): normalmente las cuenta `_on_fishing_closed`.
	while not GameState.pending_col_scenes.is_empty():
		await get_tree().create_timer(0.7).timeout
		await _escena_coleccionable(GameState.pending_col_scenes[0])
	# ALICE SE ENROLA, y con ella LLEGAN LOS BONIFICADORES. Es la escena que
	# los abre: hasta aquí el jugador no ha visto ninguno, y el primero que
	# tiene es ella misma (el bonificador del `ayudante`). Va antes que la de
	# Cai porque su escenario es posterior.
	if GameState.perks_unlocked() and not GameState.alice_intro_done:
		await get_tree().create_timer(0.7).timeout
		await _presentar_alice()
		return
	# CAI SE UNE A LA TRIPULACIÓN: al volver del puerto que abre la PESCA. Como
	# Saverio, al cerrar el diálogo lleva al jugador de la mano a su pantalla —
	# que aquí es la clase entera de pescar.
	if GameState.fishing_unlocked() and not GameState.cai_intro_done:
		await get_tree().create_timer(0.7).timeout
		await _presentar_cai()
		return
	# SAVERIO Y LA TIENDA: al VOLVER AL MAPA tras superar el puerto que la abre.
	# Encadenado al cierre del turno se comía el cartel de resultados.
	if GameState.shop_unlocked() and not GameState.shop_intro_done:
		await get_tree().create_timer(0.7).timeout
		await _presentar_saverio()
		return
	# BONUS DIARIO: después del anuncio de recetas, para no apilar carteles.
	if GameState.tutorial_done and GameState.daily_available():
		await get_tree().create_timer(0.9).timeout
		# La PRIMERA vez, David explica antes de qué va el mapa del tesoro.
		if not GameState.daily_intro_done and GameState.level1_outro_done:
			await _explicar_bonus_diario()
		# El premio NO se cobra aquí: lo cobra el jugador tocando el cofre.
		_show_daily()


## TRAS SUPERAR EL NIVEL 1: qué son las estrellas, qué se gana con ellas y a
## dónde se va ahora. Una sola vez en la vida de la partida.
func _felicitar_nivel_1() -> void:
	GameState.level1_outro_done = true
	GameState.save_game()
	var caja := DialogueBox.new()
	caja.z_index = 200
	ui_layer.add_child(caja)
	var lineas: Array = [
		{ "text": "¡Turno cerrado, %s! Tu primera jornada al mando de mi cocina." % GameState.player_title(), "mood": "riendo" },
		# NI LAS ESTRELLAS NI SUS RECOMPENSAS SE EXPLICAN AQUÍ (pedido por el
		# usuario): el cartel de resultados las acaba de enseñar una por una y
		# la ficha del puerto las lleva escritas. Contarlo otra vez era gastar
		# líneas en lo que el jugador acaba de ver.
		# LA RECOMPENSA DE LAS 3 ESTRELLAS YA NO SE EXPLICA: el cartel de
		# resultados y la ficha del puerto la enseñan solas, y decirla aquí era
		# gastar dos líneas en algo evidente. En su hueco entra lo que de
		# verdad no se ve por ningún lado: el NIVEL DE COCINERO.
		# (La charla del NIVEL DE COCINERO ya no va aquí: la dispara la subida
		# al nivel 2, ver `_explicar_nivel_cocinero`. Contada en el escenario 2
		# llegaba antes de que la barra se hubiera movido nunca.)
	]
	lineas.append({ "text": "¡AL SIGUIENTE PUERTO! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" })
	lineas.append({ "text": "Ya lo has oído. Te espero en **Playa del Coco**: allí te enseño el truco que separa a un cocinero de un friegaplatos.", "mood": "hablando" })
	caja.say(lineas)
	await caja.finished
	await caja.close_and_free()


## EL NIVEL DE COCINERO, explicado la primera vez que sube (al 2). Colgado del
## escenario 2 llegaba con la barra todavía quieta; ahora David habla justo
## cuando el jugador acaba de verla subir, y señala ARRIBA — que es donde está,
## bajo los contadores y no "debajo de las cajas" como decía antes.
func _explicar_nivel_cocinero() -> void:
	GameState.nivel_intro_done = true
	GameState.save_game()
	var caja := DialogueBox.new()
	caja.z_index = 200
	ui_layer.add_child(caja)
	caja.say([
		{ "text": "¡Alto ahí, %s! ¿Has visto eso?" % GameState.player_title(), "mood": "sorprendido" },
		{ "text": "Mira la **barra que tienes arriba**: acabas de subir a **nivel 2** de cocinero.", "mood": "feliz" },
		{ "text": "Cada jornada te deja **experiencia**, y cuando la barra se llena, subes. Cocinar te hace mejor cocinero: así de simple.", "mood": "hablando" },
		{ "text": "¡MÁS NIVEL, MÁS ORO! ¡RAAAK!", "who": "gigi", "mood": "loro" },
		{ "text": "Cuanto más alto cierres un puerto, más experiencia deja. Y subir de nivel trae premios... pero eso ya lo irás viendo.", "mood": "riendo" },
	])
	await caja.finished
	await caja.close_and_free()


## Nivel de cocinero al que David presenta las MAESTRÍAS. Cinco porque para
## entonces hay 5 puntos sin gastar: uno solo no deja ver de qué va el árbol.
const SKILLS_INTRO_LEVEL := 5


## LAS MAESTRÍAS, presentadas al llegar al nivel 5. David señala la barra, dice
## para qué sirven los puntos y abre la pantalla: la explicación de verdad la
## da el propio árbol, que ya se explica solo.
func _presentar_maestrias() -> void:
	GameState.skills_intro_done = true
	GameState.save_game()
	var caja := DialogueBox.new()
	caja.z_index = 200
	ui_layer.add_child(caja)
	caja.say([
		{ "text": "¡Nivel **%d**, %s! Ya no cocinas como el que llegó a este barco." % [GameState.chef_level, GameState.player_title()], "mood": "riendo" },
		{ "text": "Cada nivel te deja un **punto de maestría**, y llevas unos cuantos sin gastar. Eso es oficio guardado en el bolsillo.", "mood": "hablando" },
		{ "text": "Se gastan en tres **árboles**: el **cuchillo** afila tus manos, el **cliente** te saca más de cada boca y el **chef** manda en los platos.", "mood": "hablando" },
		{ "text": "¡GÁSTALOS YA! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
		{ "text": "Vamos, que te enseño la mesa donde se reparten. Se llega tocando tu **barra de nivel**, y ahí puedes cambiarlos de sitio cuando quieras.", "mood": "feliz" },
	])
	await caja.finished
	await caja.close_and_free()
	_go_skills()


## ALICE SE ENROLA (al volver al mapa tras superar su escenario, el 17). Es la
## escena que ESTRENA los bonificadores en toda la partida: le da al jugador el
## del AYUDANTE —que es ella— y de paso explica qué son. Como con Cai, la
## escena NO va dentro del nivel sino aquí, con el menú delante, que es donde
## el jugador puede ir luego a Bonificadores a verlos.
func _presentar_alice() -> void:
	GameState.alice_intro_done = true
	# El uso del ayudante se lo lleva puesto: es su regalo de bienvenida. Si ya
	# lo tuviera por haber cumplido su combo, `unlock_perk` solo suma otro uso.
	GameState.unlock_perk("ayudante")
	GameState.save_game()
	var caja := DialogueBox.new()
	caja.z_index = 200
	ui_layer.add_child(caja)
	# Si el jugador cerró el turno por objetivo sin llegar a darle los platos,
	# Alice se enrola igual —el escenario está superado— pero sin fingir una
	# comida que no hubo. Mismo criterio que con Cai.
	var comio := GameState.alice_saciada
	caja.say([
		{ "text": "He estado pensando lo que dijo." if comio
			else "Perdone. Antes no me atreví a decirlo.",
			"who": "alice", "mood": "callado" },
		# AQUI es donde suena el nombre por primera vez: en el nivel Alice solo
		# dijo "una persona", y este es el momento en que se abre con ellos.
		{ "text": "Mi maestra se llama **Miku**. No sé dónde está... pero mientras la busco, podría aprender.", "who": "alice", "mood": "serio" },
		{ "text": "¿Aprender? Chiquilla, esto es un barco pirata, no una escuela.", "mood": "sorprendido" },
		{ "text": "Fregaré. Cortaré. Lo que haga falta.", "who": "alice", "mood": "hablando" },
		{ "text": "¡QUE FRIEGUE! ¡RAAAK! ¡QUE FRIEGUE!", "who": "gigi", "mood": "loro_grito" },
		{ "text": "Por una vez, el loro tiene razón. Bienvenida a bordo, Alice.", "mood": "feliz" },
		{ "text": "Y esto, %s, te cambia la cocina: desde hoy tienes **bonificadores**." % GameState.player_title(), "mood": "hablando" },
		{ "text": "No son los potenciadores del bote: esos duran un turno y salen solos. Los **bonificadores** se eligen ANTES de zarpar y valen para toda la jornada.", "mood": "serio" },
		{ "text": "El primero es ella. Con el **ayudante de cocina** puesto, empiezas una receta, le pasas la tabla y la termina Alice mientras tú haces otra.", "mood": "feliz" },
		{ "text": "Cada uno se gana haciendo algo concreto en partida, y cada vez que lo repitas te llevas otro uso. Y se **mejoran con doblones** desde el menú, en **Bonificadores**.", "mood": "hablando" },
		{ "text": "No le romperé nada. Casi seguro.", "who": "alice", "mood": "feliz" },
	])
	await caja.finished
	await caja.close_and_free()


## CAI se enrola. Al superar la Isla de Gades quiere pagar con su caña, y David
## le hace una oferta mejor. Al cerrar, directo a su clase de pesca.
func _presentar_cai() -> void:
	GameState.cai_intro_done = true
	GameState.save_game()
	var caja := DialogueBox.new()
	caja.z_index = 200
	ui_layer.add_child(caja)
	# Si el jugador cerró el turno sin llegar a llenarle la barriga, Cai se
	# enrola igual —el nivel está superado— pero no finge un trato que no hubo.
	var lleno := GameState.cai_saciado
	caja.say([
		{ "text": "Barriga llena. Trato es trato. Toma: mi caña." if lleno
			else "Tú cocinas bien. Yo lo he visto. Toma: mi caña.",
			"who": "cai", "mood": "serio" },
		{ "text": "Quieto ahí, pescador. Un hombre no regala sus manos con su caña.", "mood": "hablando" },
		{ "text": "...", "who": "cai", "mood": "callado" },
		{ "text": "Lo que te ofrezco es un sitio en mi barco. Tú pescas, %s cocina, y comemos todos." % GameState.player_title(), "mood": "feliz" },
		{ "text": "¡OTRA BOCA! ¡RAAAK!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Sí. Yo voy.", "who": "cai", "mood": "feliz" },
		{ "text": "Cuando quieras, tú avisas. Yo enseño.", "who": "cai", "mood": "hablando" },
		{ "text": "Ya lo has oído: tienes **Pesca** en el menú, con los demás pergaminos. Cuando te apetezca, Cai te da la clase.", "mood": "hablando" },
	])
	await caja.finished
	await caja.close_and_free()
	# AQUÍ NO SE VA A NINGUNA PARTE. Esta escena arrastraba al jugador a la
	# pantalla de pesca nada más cerrar el diálogo (como hace Saverio con su
	# puesto), y eso le cambiaba de sitio justo cuando acababa de volver al
	# mapa. La clase de Cai sigue estando, pero la da cuando el jugador ENTRA
	# en Pesca por su cuenta (`fishing_game._clase_de_pesca`, con su bandera
	# `fishing_intro_done`), así que no se pierde nada.


## SAVERIO abre su puesto. Se ve al volver al mapa con el puerto de la tienda
## ya superado, y al cerrar el diálogo el juego lleva al jugador allí de la mano:
## David acaba de decirle que se pase, y hacerle buscar el botón en el menú justo
## después rompía la escena.
func _presentar_saverio() -> void:
	GameState.shop_intro_done = true
	GameState.save_game()
	var caja := DialogueBox.new()
	caja.z_index = 200
	ui_layer.add_child(caja)
	caja.say([
		{ "text": "¡Buen turno, %s! Y mira quién estaba descargando en el muelle mientras cocinabas..." % GameState.player_title(), "mood": "feliz" },
		{ "text": "**Saverio**, el mejor tendero de estos mares. Encantado, cocinero.", "who": "saverio", "mood": "explicando" },
		{ "text": "Yo vendo **usos** de ingredientes, y saco **género nuevo** cada día. A partir de hoy mi puesto es tuyo.", "who": "saverio", "mood": "hablando" },
		{ "text": "¡NEGOCIOS! ¡RAAAK!", "who": "gigi", "mood": "loro" },
		{ "text": "Anda, pásate por el puesto y échale un ojo. Lo tienes siempre en el **menú**, botón **Tienda**.", "mood": "hablando" },
	])
	await caja.finished
	await caja.close_and_free()
	GameState.fade_to_scene("res://scenes/shop_screen.tscn", 0.4, 0.5)


## PABLO PAGA. La deuda se apunta al cerrar su nivel (`GameState.pending_ingots`)
## y se cobra AQUÍ, ya de vuelta en el mapa: los lingotes entran en la caja de
## arriba mientras David los explica, con el contador a la vista y su botón "+"
## a un dedo. En el nivel no había ninguna caja en pantalla y la explicación
## señalaba a un sitio vacío.
func _pagar_pablo() -> void:
	var lingotes := GameState.pending_ingots
	GameState.pending_ingots = 0
	GameState.ingots_intro_done = true
	GameState.ingots += lingotes
	GameState.save_game()
	_refresh_resources()
	var caja := DialogueBox.new()
	caja.z_index = 200
	ui_layer.add_child(caja)
	# PAGA PABLO, EN PERSONA. Lo contaba David —"casi se me olvida, Pablo pagó
	# lo que comió"— y eso convertía en recado de tercero la única escena en la
	# que el capitán cumple su palabra. Ahora se acerca él, suelta los lingotes
	# y David solo explica para qué sirven, que es lo suyo.
	caja.say([
		{ "text": "¡Eh, cocinero! No te escapes, que Pablo el Rubio paga lo que come.", "who": "pablo", "mood": "guason" },
		{ "text": "**%d lingotes de oro**. Del bueno, no de ese que se dobla con los dientes." % lingotes, "who": "pablo", "mood": "riendo" },
		{ "text": "¡LINGOTES! ¡RAAAK! ¡BRILLAN MÁS QUE LAS MONEDAS!", "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "Y valen más, plumas. Los **lingotes** son la moneda de verdad: con ellos se compran **sacos de arroz** y bolsas de doblones cuando andas justo.", "mood": "hablando" },
		{ "text": "Mira arriba del todo, %s: ahí los tienes contados, con su botón **+** al lado. Gástalos con cabeza: no caen todos los días." % GameState.player_title(), "mood": "serio" },
		{ "text": "Y guárdame un sitio en la barra para la próxima. Con el cuchillo lejos, si puede ser.", "who": "pablo", "mood": "punal" },
	])
	await caja.finished
	await caja.close_and_free()


## LAS ESCENAS DE COLECCIONABLE (`CollectibleData.SCENE_ITEMS`): las piezas que
## tienen algo que decir al salir del mar. Espera a que se cierren los avisos
## globales (la propia ventana del coleccionable, la subida de nivel de la
## pesca) antes de hablar, porque si no el retrato sale por detrás de un cartel.
##
## La cola se vacía SIEMPRE, incluso si el id no trae guion: así una pieza que
## se apunte por error no deja el bucle de `_on_fishing_closed` girando.
func _escena_coleccionable(id: String) -> void:
	GameState.pending_col_scenes.erase(id)
	GameState.save_game()
	var lineas := _guion_coleccionable(id)
	if lineas.is_empty():
		return
	var topo := 0
	while GameState.notices_busy() and topo < 3600:
		topo += 1
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	var caja := DialogueBox.new()
	caja.z_index = 200
	ui_layer.add_child(caja)
	caja.say(lineas)
	await caja.finished
	await caja.close_and_free()


func _guion_coleccionable(id: String) -> Array:
	match id:
		"corazon_cofre":
			# El cofre del hombre muerto, con el apellido de David dentro.
			return [
				{ "text": "¡RAAAK! ¡DAVID! ¡ESO LATE! ¡LA CAJA LATE!",
					"who": "gigi", "mood": "loro_grito" },
				{ "text": "Déjalo en la mesa, %s. Despacio."
					% GameState.player_title(), "mood": "sorprendido" },
				{ "text": "Cofre pequeño, cerradura de hierro y un corazón "
					+ "dentro que no se está quieto. Esa historia me la sé.",
					"mood": "serio" },
				{ "text": "Un tipo con **mi apellido**, un barco que no volvió "
					+ "a puerto y una deuda de cien años. Dicen que se lo sacó "
					+ "él mismo para no sentir nada.", "mood": "hablando" },
				{ "text": "¿NO SERÁS TÚ? ¿EH? ¿EH? ¡NUNCA TE HE VISTO EL PECHO!",
					"who": "gigi", "mood": "loro_sorpresa" },
				{ "text": "Si lo fuera, plumas, no estaría fregando cazuelas "
					+ "contigo.", "mood": "loro_resignado" },
				{ "text": "Guárdalo en la vitrina y no le des conversación. Y "
					+ "si alguna noche lo oyes latir más fuerte... me "
					+ "despiertas.", "mood": "serio" },
			]
		"tenedor":
			# El chiste del peine: la pieza pesa poco, la escena es el premio.
			return [
				{ "text": "¿Un tenedor? ¿Hemos pescado un **tenedor**?",
					"mood": "sorprendido" },
				{ "text": "Dicen que hay quien los usa para peinarse, ¿sabes? "
					+ "Gente de debajo del agua.", "mood": "hablando" },
				{ "text": "Yo en todo caso lo usaría en la barba.",
					"mood": "riendo" },
				{ "text": "¡RAAAK! ¡TE LO VAS A DEJAR CLAVADO OTRA VEZ!",
					"who": "gigi", "mood": "loro_grito" },
			]
	return []


## Antes del PRIMER bonus diario, David explica de qué va el mapa del tesoro.
func _explicar_bonus_diario() -> void:
	GameState.daily_intro_done = true
	GameState.save_game()
	var caja := DialogueBox.new()
	caja.z_index = 200
	ui_layer.add_child(caja)
	caja.say([
		{ "text": "¡Ah! Y se me olvidaba lo mejor de enrolarse en esta tripulación.", "mood": "feliz" },
		{ "text": "Tengo un **mapa del tesoro** con siete paradas, y en cada una hay un **cofre**: uno por día. Lo abres, te llevas lo que haya y a navegar.", "mood": "hablando" },
		{ "text": "Pero la racha se cuenta por días **seguidos**: si te saltas uno, vuelta a la primera parada. Y en la séptima está el mejor botín de todos.", "mood": "serio" },
		{ "text": "¡TODOS LOS DÍAS, GRUMETE! ¡RAAAK!", "who": "gigi", "mood": "loro" },
	])
	await caja.finished
	await caja.close_and_free()


## Salto a la INTRO DEL CAOS (partida nueva), fuera del _ready: una partida
## imposible sobre level3d en modo tutorial — solo el maki, la barra llena y
## los clientes largándose — de la que David rescata al jugador
## (tutorial_director.gd). De ahí se vuelve a ESTE menú a rellenar la ficha
## de tripulación (`_show_ficha`), sin cambiar de escena.
func _ir_a_la_intro(out_time := 0.0) -> void:
	GameState.mode = "tutorial"
	GameState.current_port = ""
	var recs: Array[String] = ["maki_aguacate"]
	GameState.selected_recipes = recs
	GameState.selected_perks = []
	GameState.fade_to_scene("res://scenes/level3d.tscn", out_time, 0.5)


## En la PORTADA cualquier toque zarpa; fuera de ella manda el arrastre del
## mapa del padre.
func _unhandled_input(event: InputEvent) -> void:
	if start_mode:
		if not leaving and event is InputEventScreenTouch \
				and (event as InputEventScreenTouch).pressed:
			_zarpar_de_la_portada()
		return
	super._unhandled_input(event)


## Modo PORTADA: el barco amarrado al muelle, el logotipo y "Pulsa para
## zarpar". Ni botones, ni contadores, ni mapa.
func _show_start() -> void:
	start_mode = true
	in_menu = true
	map_visible = false
	_set_map_ui_visible(false)
	_set_menu_ui_visible(false)
	for caja in [ingot_box, money_box, rice_box, rice_timer_label]:
		if caja != null:
			caja.visible = false
	# La PORTADA es la única pantalla donde la barra de nivel no pinta nada
	# (ya no la apaga `_set_menu_ui_visible`, que ahora la deja viva en el mapa).
	if level_bar != null:
		level_bar.visible = false
	logo_holder.visible = true
	logo_holder.position.y = home_logo_y
	start_hint.visible = true
	menu_blend = 1.0
	cam_side = PORT_OFF
	ship_px = PORT_PX
	# La vista se centra por encima del barco: arriba el logotipo, abajo el
	# barco contra su muelle.
	cam_center = MENU_ANCHOR.y - START_CAM_LIFT
	if ship_pivot != null:
		ship_pivot.scale = Vector3.ONE * MENU_SHIP_SCALE
	if ship_blob != null:
		ship_blob.scale = Vector3.ONE * MENU_SHIP_SCALE
	_update_camera()
	_start_logo_idle()
	GameState.fade_in(0.5)


## Zarpe desde la portada: el logotipo se va por arriba y el barco sale del
## puerto hacia la DERECHA. Con el tutorial hecho, la cámara lo acompaña hasta
## el fondeadero del menú (misma escena, sin fundido); sin tutorial, el barco
## se pone en marcha y un fundido a negro lleva a la bienvenida de David.
func _zarpar_de_la_portada() -> void:
	if leaving:
		return
	leaving = true
	GameState.booted = true
	_stop_logo_idle()
	var tw_ui := create_tween().set_parallel(true) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_ui.tween_property(logo_holder, "position:y", -640.0, 0.55)
	tw_ui.tween_property(start_hint, "modulate:a", 0.0, 0.3)
	if ship_tween != null:
		ship_tween.kill()
	if not GameState.tutorial_done:
		# El barco arranca hacia la derecha y el telón cae a mitad de camino.
		ship_tween = create_tween().set_trans(Tween.TRANS_SINE) \
				.set_ease(Tween.EASE_IN)
		ship_tween.tween_property(self, "ship_px",
			PORT_PX + Vector2(700.0, 0.0), 1.2)
		get_tree().create_timer(0.55).timeout.connect(func() -> void:
			_ir_a_la_intro(0.55))
		return
	# El mismo viaje que el de Aventura: barco y cámara juntos, sin fundido.
	ship_tween = create_tween().set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
	ship_tween.tween_property(self, "ship_px", MENU_ANCHOR, START_SAIL)
	ship_tween.parallel().tween_property(self, "cam_side", 0.0, START_SAIL)
	ship_tween.parallel().tween_property(self, "cam_center", MENU_ANCHOR.y,
		START_SAIL)
	ship_tween.parallel().tween_property(self, "ship_roll", 6.0,
		START_SAIL * 0.4)
	ship_tween.parallel().tween_property(self, "ship_roll", 0.0,
		START_SAIL * 0.5).set_delay(START_SAIL * 0.5)
	ship_tween.tween_callback(_llegar_al_menu)


## El barco alcanza el fondeadero: entra la interfaz del menú de siempre (sin
## logotipo, que se quedó en la portada) y salen los carteles pendientes.
func _llegar_al_menu() -> void:
	start_mode = false
	leaving = false
	logo_holder.visible = false
	start_hint.visible = false
	for caja in [ingot_box, money_box, rice_box, rice_timer_label]:
		if caja != null:
			caja.visible = true
	_place_resources(false, false)
	_set_menu_ui_visible(true)
	_sky_in()
	_ui_in()
	_menu_popups()

# ------------------------------------------------- estados de la escena

## Modo MENÚ: barco en el fondeadero, mapa fuera de vista.
func _show_menu(animate: bool) -> void:
	in_menu = true
	_place_resources(false, animate)
	map_visible = false
	sky_leaving = false
	_set_map_ui_visible(false)
	if ship_tween != null:
		ship_tween.kill()
		ship_tween = null
	if not animate:
		menu_blend = 1.0
		ship_px = MENU_ANCHOR
		cam_center = MENU_ANCHOR.y
		_update_camera()
	if ship_pivot != null:
		ship_pivot.scale = Vector3.ONE * MENU_SHIP_SCALE
	if ship_blob != null:
		ship_blob.scale = Vector3.ONE * MENU_SHIP_SCALE
	_set_menu_ui_visible(true)
	_sky_in()


# ------------------------------------------------- ficha de tripulación
#
# LA PRESENTACIÓN DE DAVID OCURRE EN EL MENÚ, no en una escena aparte. Antes
# había un `david_intro.tscn` con su propio decorado; se retiró porque el fondo
# tenía que ser EXACTAMENTE este (el barco navegando) y, siéndolo, el fundido a
# negro y el cambio de escena por medio solo eran un corte de más. Ahora el
# jugador llega aquí desde la intro del caos y ve el mismo mar todo el rato: se
# rellena el cartel de tripulación, y solo entonces bajan el tablón, el submenú
# y los contadores. David sigue hablando ya con el camarote puesto.

## Estado FICHA: el mar del menú, pero SIN interfaz — solo David y el cartel.
func _show_ficha() -> void:
	in_menu = true
	map_visible = false
	sky_leaving = false
	_set_map_ui_visible(false)
	_set_menu_ui_visible(false)
	for caja in [ingot_box, money_box, rice_box, rice_timer_label]:
		if caja != null:
			caja.visible = false
	menu_blend = 1.0
	cam_side = 0.0
	ship_px = MENU_ANCHOR
	cam_center = MENU_ANCHOR.y
	if ship_pivot != null:
		ship_pivot.scale = Vector3.ONE * MENU_SHIP_SCALE
	if ship_blob != null:
		ship_blob.scale = Vector3.ONE * MENU_SHIP_SCALE
	_update_camera()
	_sky_in()
	_place_resources(false, false)
	# La ficha va SIN interfaz: solo David y el cartel (la barra de nivel la
	# vuelve a encender `_place_resources`, así que se apaga después).
	if level_bar != null:
		level_bar.visible = false
	_run_ficha.call_deferred()


func _run_ficha() -> void:
	var caja := DialogueBox.new()
	caja.z_index = 200
	ui_layer.add_child(caja)
	caja.say([
		{ "text": "Bienvenido a bordo, grumete. Ficha de **tripulación** nueva: escribe tu nombre y elige tu retrato.", "mood": "feliz" },
		{ "text": "El cartel de recompensa no se rellena solo. ¡RAAK!", "who": "gigi", "mood": "loro" },
	])
	# SIN `keep_open`: la caja tiene que RETIRARSE antes de que salga el cartel
	# de recompensa, o el retrato de David se queda tapándolo media pantalla.
	await caja.finished
	await get_tree().create_timer(DialogueBox.FADE_OUT + 0.05).timeout
	var pname := await _ask_identity()
	caja.say([
		{ "text": _pulla_de_gigi(pname), "who": "gigi", "mood": "loro_sorpresa" },
		{ "text": "No creo que seas el más indicado para hablar de nombres, Gigi. **%s**, el plan es navegar por los siete mares sirviendo el mejor sushi que un pirata podría probar." % pname, "mood": "serio" },
	])
	await caja.finished
	# El tutorial queda HECHO aquí: entrega el maki y su despensa.
	GameState.complete_tutorial()
	await caja.close_and_free()
	# Y AHORA aparece el camarote entero, con su animación de entrada de siempre.
	for c in [ingot_box, money_box, rice_box, rice_timer_label]:
		if c != null:
			c.visible = true
	_refresh_resources()
	_ui_in()
	await get_tree().create_timer(1.1).timeout
	if leaving:
		return
	# David sigue, ya con los pergaminos en pantalla.
	_menu_popups()


# --- LAS PULLAS DE GIGI AL NOMBRE ------------------------------------------
#
# Recién rellenado el cartel, Gigi suelta UNA broma con el nombre elegido. Hay
# tres sacos: diez para el chef masculino, diez para la femenina y cinco que
# valen para cualquiera, o sea veinticinco frases distintas. `%s` es el nombre.
# Se sortean con `pick_random`, así que dos partidas seguidas casi nunca dan la
# misma; el género sale de `GameState.player_gender`, que ya está aplicado
# cuando esto se llama (el cartel hace `aplicar()` antes de devolver).

const GIGI_PULLAS_M: Array = [
	"¡RAAAK! ¡**%s**! ¿Eso es un nombre o el ruido que hace un barril al caerse?",
	"¡**%s**! ¡RAAK! Conocí a un **%s** una vez. Se cayó por la borda a los dos días.",
	"¿**%s**? ¡RAAAK! Suena a alguien que se marea mirando el mar desde el muelle.",
	"¡**%s**! Con ese nombre no asustas ni a una gaviota dormida. ¡RAAK!",
	"¡RAAAK! **%s**... como el cocinero anterior. Y del anterior no volvimos a saber nada.",
	"¿**%s**? Yo habría puesto **Almirante Rascatripas**, pero nadie me pregunta. ¡RAAK!",
	"¡**%s**! ¡RAAK! Apúntalo en el barril, no se te olvide a mitad de travesía.",
	"¡RAAAK! **%s**. Tres sílabas para alguien que aún no sabe hervir arroz.",
	"¿**%s**? Vale, vale. Yo te llamaré **grumete** hasta nuevo aviso. ¡RAAK!",
	"¡**%s**! Ese nombre huele a fregar cubierta. ¡RAAAK!",
]

const GIGI_PULLAS_F: Array = [
	"¡RAAAK! ¡**%s**! ¿Eso es un nombre o el ruido que hace un barril al caerse?",
	"¿**%s**? ¡RAAK! Suena a alguien que le pone nombre a las gaviotas.",
	"¡**%s**! Conocí a una **%s**. Me robó una galleta. No te confío la despensa. ¡RAAK!",
	"¡RAAAK! **%s**... ¿segura? Todavía estás a tiempo de elegir uno que dé miedo.",
	"¡**%s**! Con ese nombre te van a pedir la carta en vez de la espada. ¡RAAK!",
	"¿**%s**? Yo habría puesto **Capitana Rascaplumas**, pero aquí nadie me escucha. ¡RAAAK!",
	"¡**%s**! ¡RAAK! Bonito. Demasiado bonito para alguien que va a oler a pescado.",
	"¡RAAAK! **%s**. Que conste que yo lo he oído primero y no me ha impresionado.",
	"¿**%s**? Vale. Yo te llamaré **grumete** hasta que sepas cocinar. ¡RAAK!",
	"¡**%s**! Ese nombre se pierde con el viento. ¡RAAAK! Grita más.",
]

const GIGI_PULLAS_ANY: Array = [
	"¡RAAAK! ¿**%s**? ¿Y ese nombre lo has elegido tú o te lo ha dado el mar?",
	"¡**%s**! ¡RAAK! Yo me llamo **Gigi**, que es mucho mejor y encima vuelo.",
	"¿**%s**? Ponlo bien grande en el cartel, que luego hay confusiones. ¡RAAAK!",
	"¡RAAAK! **%s**. Suena a alguien que va a quemar el primer plato.",
	"¡**%s**! Está bien, está bien. Total, aquí todos acabamos llamándonos \"¡EH, TÚ!\". ¡RAAK!",
]


## Una pulla al azar del saco que toque (género + las comunes). El nombre entra
## tantas veces como `%s` tenga la frase, así que se rellena por conteo.
func _pulla_de_gigi(pname: String) -> String:
	var saco: Array = GIGI_PULLAS_ANY.duplicate()
	saco.append_array(GIGI_PULLAS_F if GameState.player_gender == CharacterData.FEMALE
			else GIGI_PULLAS_M)
	var frase: String = str(saco.pick_random())
	var huecos := frase.count("%s")
	var datos: Array = []
	for i in huecos:
		datos.append(pname)
	return frase % datos


## CARTEL DE RECOMPENSA: la ficha del jugador (ver `wanted_poster.gd`). Se
## escribe el nombre en el propio cartel, se pasa de personaje con las flechas
## de la foto y se elige la mano; "¡Ese soy yo!" se enciende con el nombre
## puesto. Devuelve el nombre.
func _ask_identity() -> String:
	# ARRIBA, no centrado: centrado, el cartel (ya alto de por sí) empujaba el
	# botón hacia el borde y quedaba una franja muerta sobre el WANTED.
	var caja := Control.new()
	caja.set_anchors_preset(Control.PRESET_CENTER_TOP)
	var medida := WantedPoster.panel_size(true)
	var alto := medida.y + 104.0
	caja.offset_left = -medida.x * 0.5
	caja.offset_right = medida.x * 0.5
	caja.offset_top = 30.0 + GameState.safe_top()
	caja.offset_bottom = caja.offset_top + alto
	caja.z_index = 190
	ui_layer.add_child(caja)

	var cartel := WantedPoster.new()
	cartel.editable_name = true
	caja.add_child(cartel)

	var ok := Button.new()
	ok.text = "¡Ese soy yo!"
	# Ancho de sobra a propósito: con el botón justo, el texto se montaba sobre
	# las esquinas doradas del 9-slice.
	ok.position = Vector2((medida.x - 400.0) * 0.5, medida.y + 16.0)
	ok.size = Vector2(400, 82)
	PrepBoard.skin_button(ok)
	ok.add_theme_font_size_override("font_size", 30)
	caja.add_child(ok)

	# CLIC DE SEGURIDAD: el botón nace apagado y no se arma hasta FICHA_ARMADO
	# segundos. Se llega aquí pasando el diálogo a toques, y quien va rápido
	# encadenaba el último toque con el botón y se saltaba la ficha entera sin
	# verla; con el retardo, ese toque de inercia cae en un botón inerte.
	var armado := { "on": false }
	var refrescar := func() -> void:
		var listo: bool = cartel.listo() and bool(armado["on"])
		ok.disabled = not listo
		ok.modulate = Color.WHITE if listo else Color(0.62, 0.62, 0.62)
	cartel.edited.connect(func() -> void: refrescar.call())
	# El cartel se construye en su `_ready`, que corre al entrar en el árbol; la
	# primera comprobación tiene que ir DESPUÉS o `listo()` mira un LineEdit que
	# todavía no existe.
	await get_tree().process_frame
	refrescar.call()
	get_tree().create_timer(FICHA_ARMADO).timeout.connect(func() -> void:
		armado["on"] = true
		refrescar.call())

	await ok.pressed
	var pname := cartel.nombre()
	cartel.aplicar()
	# El cartel también se despide con fundido, no de golpe.
	var out := caja.create_tween().set_parallel(true)
	out.tween_property(caja, "modulate:a", 0.0, 0.22)
	out.tween_property(caja, "position:y", caja.position.y - 26.0, 0.22)
	out.chain().tween_callback(caja.queue_free)
	await get_tree().create_timer(0.24).timeout
	return pname


# ---------------------------------------------- velos de las explicaciones

## Velo oscuro de una explicación de David, que ENTRA con fundido. Los guiones
## sueltos del menú lo montaban de golpe (y a David con él), y el corte cantaba.
func _velo_guia(alpha := 0.72) -> ColorRect:
	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, alpha)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.z_index = 150
	velo.mouse_filter = Control.MOUSE_FILTER_STOP
	velo.modulate.a = 0.0
	ui_layer.add_child(velo)
	velo.create_tween().tween_property(velo, "modulate:a", 1.0, 0.3)
	return velo


func _quitar_velo(velo: Control) -> void:
	if velo == null or not is_instance_valid(velo):
		return
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := velo.create_tween()
	tw.tween_property(velo, "modulate:a", 0.0, 0.26)
	tw.tween_callback(velo.queue_free)


## Modo MAPA: el barco navega hasta el último nivel abierto y entra la
## interfaz de la campaña.
func _enter_map(animate: bool) -> void:
	in_menu = false
	# Con el mapa ya en pantalla: primero el arroz y, encadenada, la guía del
	# primer puerto (las dos solo la 1ª vez, cada una con su bandera).
	_presentar_mapa.call_deferred()
	# Los contadores se corren a la derecha y dejan hueco al botón "Atrás".
	_place_resources(true, animate)
	map_visible = true
	if not animate:
		_set_menu_ui_visible(false)
	_set_map_ui_visible(true)
	if animate:
		# Entra DESPUÉS de que el barco se ponga en camino: si aparece a la vez
		# que se van el logotipo y los botones, se pisan en pantalla.
		_map_ui_fade(true)
	if not animate:
		menu_blend = 0.0
		_focus_last_port(false)
		leaving = false
		return
	var target := last_open_port()
	var dest := _ship_anchor(target)
	var dur := 1.6
	# El barco recupera su tamaño de ficha del mapa mientras navega.
	var scale_tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	scale_tw.tween_property(ship_pivot, "scale", Vector3.ONE, dur * 0.8)
	scale_tw.tween_property(ship_blob, "scale", Vector3.ONE, dur * 0.8)
	if ship_tween != null:
		ship_tween.kill()
	# El encuadre pasa del alto del menú al del mapa POCO A POCO. Cambiarlo de
	# golpe (con un simple `if in_menu`) daba un salto de ~200 px justo al
	# arrancar el viaje, que es el "tirón" que se veía.
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(
		self, "menu_blend", 0.0, dur * 0.55)
	# La cámara acompaña al barco durante toda la travesía.
	ship_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ship_tween.tween_property(self, "ship_px", dest, dur)
	ship_tween.parallel().tween_property(self, "cam_center",
		clampf(CampaignData.map_pos(target).y, SCROLL_MIN, SCROLL_MAX), dur)
	ship_tween.parallel().tween_property(self, "ship_roll", 6.0, dur * 0.4)
	ship_tween.parallel().tween_property(self, "ship_roll", 0.0, dur * 0.5) \
			.set_delay(dur * 0.5)
	ship_tween.tween_callback(func() -> void:
		_select(target, false)
		leaving = false)


## Enciende o apaga la interfaz del mapa con un fundido.
func _map_ui_fade(show: bool) -> void:
	for node in [map_top_bar, map_info_panel]:
		if node == null:
			continue
		node.modulate.a = 0.0 if show else 1.0
		var tw := create_tween()
		if show:
			tw.tween_interval(0.45)
		tw.tween_property(node, "modulate:a", 1.0 if show else 0.0, 0.4)
	for id in node_overlays:
		var ov: Control = node_overlays[id]["root"]
		ov.modulate.a = 0.0 if show else 1.0
		var tw2 := create_tween()
		if show:
			tw2.tween_interval(0.6)
		tw2.tween_property(ov, "modulate:a", 1.0 if show else 0.0, 0.4)


## La cámara sigue al barco; en el menú se encuadra sobre su fondeadero.
func _update_camera() -> void:
	if cam == null:
		return
	var off := lerpf(BAND_CENTER_OFF, MENU_BAND_OFF, menu_blend)
	# El TEMBLOR del tiron se suma aqui, en pixeles de lienzo: asi
	# sacude el mar y el barco sin tocar nada mas.
	var sh := Vector2.ZERO
	if cam_shake > 0.01:
		sh = Vector2(randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)) * cam_shake
	var target := _world(Vector2(360.0 + cam_side + sh.x,
		cam_center + off + sh.y))
	cam.position = target + cam.transform.basis.z * 30.0


func _set_map_ui_visible(on: bool) -> void:
	if map_top_bar != null:
		map_top_bar.visible = on
	if map_info_panel != null:
		map_info_panel.visible = on
	for id in node_overlays:
		node_overlays[id]["root"].visible = on


## El logotipo NO está en la lista: desde que hay portada vive allí y en el
## menú no vuelve a aparecer (lo enseña `_show_start` y nadie más).
func _set_menu_ui_visible(on: bool) -> void:
	for node in [menu_panel, submenu_bar]:
		if node != null:
			node.visible = on
	# LA BARRA DE NIVEL YA NO SE APAGA DESDE AQUÍ: vive también en el MAPA
	# (corrida a la derecha, ver `_level_bar_spot`), y este método se llama con
	# `false` justo al entrar en él. La coloca y la enciende `_place_resources`,
	# y solo la portada la apaga a mano.
	if on and level_bar != null:
		_refresh_level_bar()
	# El cielo solo se APAGA desde aquí. Encenderlo es trabajo de `_sky_in`,
	# que recoloca antes: encendido desde este lado, gaviotas y nubes se
	# renderizaban un fotograma en su posición vieja (el parpadeo).
	if not on:
		for b in birds:
			b["node"].visible = false
		for c in clouds:
			c["node"].visible = false


# ------------------------------------------------------------ menú: mundo

## Gaviotas: cuerpo claro y alas en V que baten, dando vueltas sobre el barco.
## La V y el cuerpo hacen falta: con las alas planas y alineadas, desde la
## cámara isométrica solo se veía una barra blanca.
func _setup_birds() -> void:
	# Con "menos animaciones" ni se crean: son adorno y cada una es geometría
	# que se mueve por frame.
	if not GameState.animations_on():
		return
	var wing_mat := StandardMaterial3D.new()
	wing_mat.albedo_color = Color(0.98, 0.98, 0.96)
	wing_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.88, 0.89, 0.93)
	body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 4:
		var pivot := Node3D.new()
		add_child(pivot)
		var body := MeshInstance3D.new()
		var body_box := BoxMesh.new()
		body_box.size = Vector3(0.12, 0.1, 0.34)
		body.mesh = body_box
		body.material_override = body_mat
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(body)
		var wings: Array = []
		for sgn in [-1.0, 1.0]:
			var hinge := Node3D.new()
			pivot.add_child(hinge)
			var mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.66, 0.04, 0.17)
			mi.mesh = box
			mi.position = Vector3(sgn * 0.33, 0.0, 0.0)
			mi.material_override = wing_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			hinge.add_child(mi)
			wings.append(hinge)
		birds.append({
			"node": pivot, "wings": wings, "radius": 3.6 + i * 1.5,
			"phase": i * (TAU / 4.0) + randf_range(-0.3, 0.3),
			"speed": 0.13 + i * 0.02, "y": 3.4 + i * 0.75, "flap": 4.6 + i * 0.7,
		})


## Nubes bajas y TRANSLÚCIDAS que cruzan por delante del barco. Van en 3D, así
## que el logotipo y los botones (CanvasLayer) siempre quedan por encima.
func _setup_clouds() -> void:
	if not GameState.animations_on():
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.42)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 3:
		var pivot := Node3D.new()
		add_child(pivot)
		for p in [Vector3(0, 0, 0), Vector3(0.85, -0.14, 0.2),
				Vector3(-0.8, -0.16, -0.16), Vector3(0.14, 0.26, -0.1)]:
			var mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(1.5, 0.5, 1.15) if p == Vector3.ZERO \
					else Vector3(1.05, 0.4, 0.85)
			mi.mesh = box
			mi.position = p
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pivot.add_child(mi)
		clouds.append({
			"node": pivot, "side": -10.0 + i * 7.5, "along": 5.0 + i * 2.0,
			"y": 5.6 + randf_range(0.0, 1.2), "speed": 0.3 + randf() * 0.18,
		})


func _process(delta: float) -> void:
	super._process(delta)
	# La cuenta atrás del arroz corre SIEMPRE (también en el mapa) y una vez por
	# segundo: repintarla a 30 fps no aporta nada y el texto es el mismo.
	_rice_tick += delta
	if _rice_tick >= 1.0:
		_rice_tick = 0.0
		if rice_timer_label != null:
			var antes := GameState.rice
			rice_timer_label.text = GameState.rice_time_text()
			# Si acaba de caer un saco, se repinta la caja entera.
			if GameState.rice != antes:
				_refresh_resources()
	# La punta de la caña VIAJA CON EL BARCO. Estaba clavada en píxeles de
	# lienzo (`FishingGame.ROD_TIP`), medida con el barco cabeceando; con
	# "menos animaciones" el barco se queda plano, la borda sube unos píxeles
	# y la línea blanca del sedal nacía fuera del casco. `ROD_LOCAL` es el
	# punto del BARCO que cae en esa medida cuando está en reposo (despejado
	# con la base de proyección de la cámara), así que proyectarlo por
	# fotograma vale para cualquier pose y cualquier ajuste de gráficos.
	if fishing_ui != null and is_instance_valid(fishing_ui) \
			and ship_pivot != null and cam != null:
		# MIENTRAS EL PEZ TIRA hay que recolocar la camara por fotograma:
		# el temblor es aleatorio y el zoom va interpolado, y si no nadie
		# los aplicaria (el menu solo mueve la camara en sus viajes).
		if cam_shake > 0.01 or cam_zoom > 0.001:
			if cam_size_base > 0.0:
				cam.size = lerpf(cam_size_base,
					cam_size_base * RUSH_ZOOM_IN, cam_zoom)
			_update_camera()
		elif cam_size_base > 0.0:
			# Tiron terminado: se devuelve el encuadre exacto de antes.
			cam.size = cam_size_base
			cam_size_base = 0.0
			_update_camera()
		# LA PUNTA SE PROYECTA AL FINAL, con la camara YA colocada: el
		# temblor del tiron la mueve justo aqui arriba, y calculandola
		# antes el sedal nacia donde estaba el barco el fotograma pasado
		# — se le veia despegado del casco.
		fishing_ui.rod_tip = cam.unproject_position(
			ship_pivot.global_transform * ROD_LOCAL)
	if not in_menu:
		return
	_mt += delta
	# El "Pulsa para zarpar" late mientras espera el toque.
	if start_mode and start_hint != null and not leaving:
		start_hint.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(_mt * 2.4))
	# La inercia del timón: suelto, sigue girando y se va frenando.
	if wheel != null and not wheel_grab and absf(wheel_vel) > 0.02:
		wheel.rotation += wheel_vel * delta
		_bank_wheel_turns(absf(wheel_vel) * delta)
		wheel_vel = lerpf(wheel_vel, 0.0, minf(delta * 1.6, 1.0))
	# Mientras se retiran del encuadre las mueve su tween, no esta función.
	if sky_leaving:
		return
	# Gaviotas y nubes viven alrededor del barco, esté donde esté. Las nubes
	# avanzan aquí (dependen de delta); la COLOCACIÓN va aparte para que
	# `_sky_in` pueda recolocar antes de encender la visibilidad.
	for c in clouds:
		c["side"] = float(c["side"]) + float(c["speed"]) * delta
		if float(c["side"]) > 11.0:
			c["side"] = -11.0
			c["along"] = randf_range(3.0, 9.0)
	_place_sky()


## Coloca gaviotas y nubes en su sitio de ESTE fotograma (con `sky_drop`
## sumado). Es función aparte por el PARPADEO: al llegar al menú, la
## visibilidad se encendía en un callback de tween que corre DESPUÉS del
## `_process` del fotograma, así que se renderizaban una vez en su posición
## vieja (sin el desvío puesto) antes de que la colocación los alcanzara.
## `_sky_in` pone el desvío, RECOLOCA con esta función y solo entonces los
## hace visibles: ya no hay fotograma con la posición vieja.
func _place_sky() -> void:
	var here := _world(ship_px)
	for b in birds:
		var ang := _mt * float(b["speed"]) * TAU + float(b["phase"])
		var n: Node3D = b["node"]
		var r: float = b["radius"]
		n.position = here + R_HAT * (cos(ang) * r) \
				+ D_HAT * (sin(ang) * r * 0.55) \
				+ Vector3(0.0, float(b["y"]) + sky_drop
					+ sin(_mt * 1.4 + float(b["phase"])) * 0.3, 0.0)
		n.rotation.y = -ang
		var flap := 0.32 + sin(_mt * float(b["flap"])) * 0.42
		b["wings"][0].rotation.z = flap
		b["wings"][1].rotation.z = -flap
	for c in clouds:
		var n2: Node3D = c["node"]
		n2.position = here + R_HAT * float(c["side"]) \
				+ D_HAT * float(c["along"]) \
				+ Vector3(0.0, float(c["y"]) + sky_drop, 0.0)


# --------------------------------------------------------------- menú: UI

func _setup_menu_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	# En el MENÚ no se enseña el monedero: el dinero solo importa donde se
	# puede gastar o ganar (mapa de aventura, tienda e inventario). Su hueco de
	# la esquina superior derecha lo ocupa ahora la rueda de Opciones.


	# Logotipo, flotando sobre el mar. Va dentro de un contenedor propio.
	logo_holder = Control.new()
	logo_holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	logo_holder.offset_left = 26.0
	logo_holder.offset_right = -26.0
	logo_holder.offset_top = 96.0
	logo_holder.offset_bottom = 436.0
	logo_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(logo_holder)
	logo = TextureRect.new()
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture = load("res://assets/ui/logo_sushi_pirata.webp")
	logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_holder.add_child(logo)
	logo.pivot_offset = Vector2(334, 170)
	# El logotipo SOLO sale en la portada: aquí se deja montado y escondido, y
	# `_show_start` lo enciende. Su balanceo se arranca allí.
	logo_holder.visible = false

	# "Pulsa para zarpar", latiendo en el tercio de abajo de la portada.
	start_hint = Label.new()
	start_hint.text = "Pulsa para zarpar"
	start_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	start_hint.offset_top = -190.0 - GameState.safe_bottom()
	start_hint.offset_bottom = -130.0 - GameState.safe_bottom()
	start_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_hint.add_theme_font_size_override("font_size", 38)
	start_hint.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	start_hint.add_theme_color_override("font_outline_color",
		Color(0.16, 0.08, 0.03))
	start_hint.add_theme_constant_override("outline_size", 11)
	start_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		start_hint.add_theme_font_override("font", negrita)
	start_hint.visible = false
	ui_layer.add_child(start_hint)

	# EL TABLÓN DEL MENÚ: los tres modos van DENTRO de un panel de madera con
	# banner tallado y cuerdas (menu_panel.png, sprite FIJO — su marco es
	# irregular y un 9-slice lo deformaría), con el TIMÓN asomando por detrás
	# del banner. El timón se puede GIRAR con el dedo: no hace nada, es el
	# huevo de pascua del menú.
	menu_panel = Control.new()
	menu_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	menu_panel.offset_left = (720.0 - MENU_PANEL_W) * 0.5
	menu_panel.offset_right = -(720.0 - MENU_PANEL_W) * 0.5
	menu_panel.offset_bottom = -SUB_BOTTOM - SUB_BAR_H - 14.0 \
			- GameState.safe_bottom()
	menu_panel.offset_top = menu_panel.offset_bottom \
			- MENU_PANEL_W * MENU_PANEL_RATIO
	ui_layer.add_child(menu_panel)

	var tabla := TextureRect.new()
	tabla.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tabla.stretch_mode = TextureRect.STRETCH_SCALE
	tabla.texture = load("res://assets/ui/menu_panel.png")
	tabla.set_anchors_preset(Control.PRESET_FULL_RECT)
	tabla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel.add_child(tabla)

	# El timón va DESPUÉS de la textura del panel en el árbol: se dibuja POR
	# DELANTE, superpuesto al tablón, cabalgando su canto superior.
	var wheel_holder := Control.new()
	wheel_holder.position = Vector2((MENU_PANEL_W - WHEEL_SIZE) * 0.5,
		-WHEEL_PEEK)
	wheel_holder.size = Vector2(WHEEL_SIZE, WHEEL_SIZE)
	wheel_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	wheel_holder.gui_input.connect(_on_wheel_input)
	menu_panel.add_child(wheel_holder)
	wheel = TextureRect.new()
	wheel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wheel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wheel.texture = load("res://assets/ui/timon.png")
	wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	wheel.pivot_offset = Vector2(WHEEL_SIZE, WHEEL_SIZE) * 0.5
	wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel_holder.add_child(wheel)

	# Los botones, en el hueco interior del tablón (medido sobre el PNG:
	# x 0.10..0.90, y 0.245..0.845 — ver MENU_PANEL_INNER).
	var alto_panel := MENU_PANEL_W * MENU_PANEL_RATIO
	var box := VBoxContainer.new()
	box.position = Vector2(MENU_PANEL_W * MENU_PANEL_INNER.position.x,
		alto_panel * MENU_PANEL_INNER.position.y)
	box.size = Vector2(MENU_PANEL_W * MENU_PANEL_INNER.size.x,
		alto_panel * MENU_PANEL_INNER.size.y)
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_panel.add_child(box)
	button_box = box

	# (El ANCLA pintada que adornaba el pie del tablón se retiró al entrar el
	# cuarto pergamino: la Pesca ocupa ahora esa franja.)

	aventura_btn = _make_mode_button("Aventura", "ic_aventura", 96, 42,
		func() -> void: _go_adventure())
	box.add_child(aventura_btn)
	var arcade_btn := _make_mode_button("Arcade", "ic_arcade", 96, 42,
		func() -> void: _go_arcade())
	box.add_child(arcade_btn)
	# El Arcade se gana venciendo al jefe del nivel 10: hasta entonces el
	# botón queda apagado (pulsarlo explica cómo abrirlo).
	if not GameState.arcade_unlocked():
		arcade_btn.modulate = Color(0.52, 0.52, 0.52)
	var fish_btn := _make_mode_button("Pesca", "ic_pesca", 96, 42,
		func() -> void: _go_fishing())
	box.add_child(fish_btn)
	# La pesca se gana superando el nivel 5: hasta entonces, apagada con aviso.
	if not GameState.fishing_unlocked():
		fish_btn.modulate = Color(0.52, 0.52, 0.52)
	var shop_btn := _make_mode_button("Tienda", "ic_tienda", 96, 42,
		func() -> void: _go_shop())
	box.add_child(shop_btn)
	# La tienda no existe hasta que David presenta a Saverio, al superar el
	# puerto que la trae (nivel 2).
	if not GameState.shop_unlocked():
		shop_btn.modulate = Color(0.52, 0.52, 0.52)
	# (Inventario ya no está aquí: vive en el SUBMENÚ de abajo. El menú se
	# queda con los CUATRO modos: Aventura, Arcade, Pesca y Tienda.)

	_setup_submenu()
	_setup_resource_bar(GameState.safe_top())

	home_logo_y = 96.0
	# `home_box_y` y `home_sub_y` se MIDEN en `_ready` con el layout resuelto,
	# no se calculan aquí: `Control.position` es relativo al padre, no al ancla.


## Contadores de DINERO y ARROZ en la banda de arriba del menú.
##
## El arroz es la "energía" del juego: cada nivel gasta 1 uso, y el botón de "+"
## abrirá la compra (con dinero real) cuando esa parte exista.
## Ancho de cada contador y hueco entre los dos cuando van juntos (menú).
## La caja del arroz es ESTRECHA a propósito: en el mapa tiene que dejar sitio
## para que el rótulo de "Aventura" quepa CENTRADO EN LA PANTALLA, y el límite
## lo pone ella (el saco asoma además por su izquierda).
## Las tres cajas son IGUALES y entre ellas cubren el ancho de la pantalla.
## El hueco tiene que tragarse dos voladizos: el "+" que asoma por la derecha
## de una caja y el icono que asoma por la izquierda de la siguiente.
const RES_INGOT_W := 182.0
const RES_MONEY_W := 182.0
const RES_RICE_W := 182.0
## Hueco entre cajas. Tiene que dar para DOS voladizos: el "+" que asoma por la
## derecha de una caja y el icono que asoma por la izquierda de la siguiente.
## Con 12 px, el "+" de los lingotes se montaba sobre la moneda.
const RES_GAP := 58.0
## Margen IZQUIERDO de la banda. No es el de siempre (16): el icono de la
## primera caja asoma 26 px por su izquierda, y pegada al canto se salía de la
## pantalla.
const RES_LEFT := 32.0
## Lo que sobresale el botón "+" por la derecha de la caja del arroz. Hay que
## contarlo o la caja se sale de la pantalla: el "+" mide 52 y va anclado a
## -30 del borde derecho, así que asoma 22.
const RES_PLUS_BLEED := 22.0


func _setup_resource_bar(st: float) -> void:
	res_y = RES_TOP + st
	# TRES contadores centrados arriba: lingotes, monedas y arroz. Se quedan
	# QUIETOS al entrar en Aventura (antes viajaban a los extremos para dejar
	# sitio al rótulo; ahora el rótulo es el que baja).
	ingot_box = PrepBoard.make_resource_box(
		"res://assets/ui/ic_lingote.png", str(GameState.ingots), RES_INGOT_W)
	ui_layer.add_child(ingot_box)
	_add_plus(ingot_box, _on_buy_ingots)

	money_box = PrepBoard.make_resource_box(
		"res://assets/ui/moneda.png", str(GameState.money), RES_MONEY_W)
	ui_layer.add_child(money_box)
	_add_plus(money_box, _on_buy_coins)

	# El arroz SÍ tiene techo, así que además de la cifra lleva su barra.
	# SIN barra: la cifra y la cuenta atrás ya dicen cuánto queda, y el blanco
	# de la barra competía con el saco y con el "+".
	rice_box = PrepBoard.make_resource_box(
		"res://assets/ui/ic_arroz.png", str(GameState.rice), RES_RICE_W)
	ui_layer.add_child(rice_box)
	_add_plus(rice_box, _on_buy_rice)

	# Cuenta atrás del próximo saco, colgando de la caja del arroz.
	rice_timer_label = Label.new()
	rice_timer_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	rice_timer_label.offset_top = 4.0
	rice_timer_label.offset_bottom = 34.0
	rice_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rice_timer_label.add_theme_font_size_override("font_size", 19)
	rice_timer_label.add_theme_color_override("font_color", Color(1, 0.94, 0.78))
	rice_timer_label.add_theme_color_override("font_outline_color", Color(0.14, 0.06, 0.02))
	rice_timer_label.add_theme_constant_override("outline_size", 6)
	rice_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rice_box.add_child(rice_timer_label)
	_refresh_resources()
	_place_resources(false, false)
	_setup_level_bar(st)


# --- Barra de NIVEL DEL COCINERO --------------------------------------------
# Centrada bajo las cajas de recursos y sobre el barco: es el marcador del
# nivel Y el ACCESO a la pantalla de Maestrías (por eso el submenú no lleva
# icono propio). Aparece cuando hay experiencia que enseñar, y al volver de
# una jornada ANIMA el relleno con lo recién ganado, con fogonazo y "¡Nivel N!"
# en cada subida (GameState.xp_anim_from guarda desde dónde arrancar).

const LVL_BAR_W := 420.0
const LVL_BAR_H := 34.0
const LVL_BAR_Y := 96.0
## Cuánto baja la barra en la PESCA, para dejar libre la fila del "Atrás" y del
## álbum (uno en cada esquina de arriba).
const LVL_BAR_PESCA := 76.0

var level_bar: Button = null
var level_bar_fill: ProgressBar = null
var level_bar_label: Label = null
var level_bar_badge_host: Control = null
## La estrella del canto y el "+" que lleva dentro (rojo con puntos libres).
var level_star: TextureRect = null
var level_plus: Label = null
var level_plus_tween: Tween = null
var home_lvl_y := 0.0
## XP que la barra está ENSEÑANDO (la mueve el tween de la animación).
var _xp_shown := 0.0


func _setup_level_bar(st: float) -> void:
	level_bar = Button.new()
	for est in ["normal", "hover", "pressed", "disabled", "focus"]:
		level_bar.add_theme_stylebox_override(est, StyleBoxEmpty.new())
	level_bar.position = _level_bar_spot(false)
	home_lvl_y = level_bar.position.y
	level_bar.size = Vector2(LVL_BAR_W, LVL_BAR_H + 14.0)
	level_bar.pivot_offset = level_bar.size * 0.5
	ui_layer.add_child(level_bar)

	level_bar_fill = ProgressBar.new()
	level_bar_fill.show_percentage = false
	level_bar_fill.set_anchors_preset(Control.PRESET_TOP_WIDE)
	level_bar_fill.offset_top = 7.0
	level_bar_fill.offset_bottom = 7.0 + LVL_BAR_H
	level_bar_fill.offset_left = 0.0
	level_bar_fill.offset_right = 0.0
	level_bar_fill.add_theme_stylebox_override("background",
		PrepBoard.make_bar_box(PrepBoard.BAR_BG_TEX))
	level_bar_fill.add_theme_stylebox_override("fill",
		PrepBoard.make_bar_box(PrepBoard.BAR_FILL_TEX, Color(0.42, 0.62, 0.95)))
	level_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_bar.add_child(level_bar_fill)

	# La estrella del juego cabalga el canto izquierdo, como los iconos de las
	# cajas de recursos, y lleva un "+" DENTRO: es lo que dice que ahí se
	# mejoran las maestrías. El "+" se pone ROJO cuando hay puntos que gastar.
	var estrella := TextureRect.new()
	estrella.name = "Estrella"
	estrella.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	estrella.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	estrella.texture = load("res://assets/ui/estrella_llena.png")
	estrella.position = Vector2(-22.0, 0.0)
	estrella.size = Vector2(48, 48)
	estrella.pivot_offset = Vector2(24, 24)
	estrella.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_bar.add_child(estrella)
	level_star = estrella
	level_plus = Label.new()
	level_plus.text = "+"
	level_plus.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# La estrella tiene el hueco útil algo por encima de su centro geométrico
	# (las dos puntas de abajo se abren): el "+" baja un pelo para caer en la
	# panza del dibujo y no sobre el pico.
	level_plus.offset_top = 2.0
	level_plus.add_theme_font_size_override("font_size", 30)
	level_plus.add_theme_color_override("font_outline_color",
		Color(0.28, 0.14, 0.02))
	level_plus.add_theme_constant_override("outline_size", 6)
	level_plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	estrella.add_child(level_plus)

	level_bar_label = Label.new()
	level_bar_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	level_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_bar_label.add_theme_font_size_override("font_size", 22)
	level_bar_label.add_theme_color_override("font_color", Color(1, 0.96, 0.85))
	level_bar_label.add_theme_color_override("font_outline_color",
		Color(0.14, 0.07, 0.02))
	level_bar_label.add_theme_constant_override("outline_size", 8)
	level_bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_bar_label.pivot_offset = Vector2(LVL_BAR_W * 0.5, (LVL_BAR_H + 14.0) * 0.5)
	level_bar.add_child(level_bar_label)

	# El globo de los puntos libres, cabalgando la esquina superior derecha.
	# POSICIÓN Y TAMAÑO EXPLÍCITOS, sin `set_anchors_preset`: el preset no toca
	# los offsets y con un anfitrión de tamaño cero el globo no llegaba a
	# dibujarse (la trampa de siempre; ver CLAUDE.md).
	level_bar_badge_host = Control.new()
	level_bar_badge_host.position = Vector2(LVL_BAR_W - 34.0, -6.0)
	level_bar_badge_host.size = Vector2(34, 34)
	level_bar_badge_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_bar.add_child(level_bar_badge_host)

	PrepBoard.add_press_feedback(level_bar)
	level_bar.pressed.connect(_go_skills)
	_xp_shown = float(GameState.chef_xp)
	_refresh_level_bar()


## Repinta la barra con la XP que toque enseñar (la vigente o la del tween).
func _refresh_level_bar() -> void:
	if level_bar == null:
		return
	# LA BARRA ESTÁ DESDE EL PRIMER DÍA, aunque la experiencia sea 0. Estuvo
	# colgada de `chef_xp > 0` y en una partida nueva no había barra ni en el
	# menú ni en el mapa: el jugador no sabía que existía hasta después de su
	# primera jornada, y encima aparecía de la nada. Lo único que la esconde es
	# no haber pasado el tutorial.
	level_bar.visible = GameState.tutorial_done
	if not level_bar.visible:
		return
	var xp := int(_xp_shown)
	var nivel := SkillData.level_for_xp(xp)
	if nivel >= SkillData.MAX_LEVEL:
		level_bar_fill.max_value = 1
		level_bar_fill.value = 1
		level_bar_label.text = "Nivel %d  ·  MÁXIMO" % nivel
	else:
		var suelo := SkillData.xp_at_level(nivel)
		level_bar_fill.max_value = SkillData.xp_for_next(nivel)
		level_bar_fill.value = xp - suelo
		level_bar_label.text = "Nivel %d" % nivel
	for hijo in level_bar_badge_host.get_children():
		hijo.queue_free()
	# EL "+" DE LA ESTRELLA: crema mientras no hay nada que gastar, ROJO y
	# latiendo en cuanto hay UN punto libre (ahora basta uno: los puntos se
	# invierten de uno en uno). Y el globo con la cifra, para saber cuántos.
	var libres := GameState.chef_points_free()
	if level_plus != null:
		if level_plus_tween != null and level_plus_tween.is_valid():
			level_plus_tween.kill()
			level_star.scale = Vector2.ONE
		if libres > 0:
			level_plus.add_theme_color_override("font_color",
				Color(1.0, 0.25, 0.20))
			level_star.pivot_offset = level_star.size * 0.5
			level_plus_tween = level_star.create_tween().set_loops()
			level_plus_tween.tween_property(level_star, "scale",
				Vector2(1.16, 1.16), 0.6).set_trans(Tween.TRANS_SINE)
			level_plus_tween.tween_property(level_star, "scale", Vector2.ONE,
				0.6).set_trans(Tween.TRANS_SINE)
		else:
			level_plus.add_theme_color_override("font_color",
				Color(1, 0.96, 0.86, 0.85))
	if libres > 0:
		PrepBoard.attach_badge(level_bar_badge_host, libres)


## Anima el relleno con la XP pendiente: la barra da un respingo, el relleno
## sube por tramos y cada nivel cruzado suelta su fogonazo con "¡Nivel N!".
func _play_xp_anim_if_pending() -> void:
	if level_bar == null or GameState.xp_anim_from < 0:
		_refresh_level_bar()
		return
	var desde := GameState.xp_anim_from
	GameState.xp_anim_from = -1
	var hasta := GameState.chef_xp
	if hasta <= desde:
		_refresh_level_bar()
		return
	_xp_shown = float(desde)
	_refresh_level_bar()
	# Respingo de atención antes de empezar a llenar.
	var tw := level_bar.create_tween()
	tw.tween_property(level_bar, "scale", Vector2(1.06, 1.06), 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(level_bar, "scale", Vector2.ONE, 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# El relleno viaja por NIVELES: cada tramo termina en la frontera del
	# siguiente y ahí estalla el fogonazo. La duración se reparte por tramo.
	var t2 := level_bar.create_tween()
	t2.tween_interval(0.35)
	# Al terminar de llenar, la ventana con lo que han soltado las subidas (si
	# el jugador no pasó por el cartel de fin, que es quien la enseña primero).
	t2.finished.connect(func() -> void:
		var subida := GameState.take_level_up()
		if not subida.is_empty():
			GameState.announce_level_up(subida))
	var actual := desde
	while actual < hasta:
		var nivel := SkillData.level_for_xp(actual)
		var frontera := SkillData.xp_at_level(nivel + 1) \
			if nivel < SkillData.MAX_LEVEL else hasta
		var tramo: int = mini(frontera, hasta)
		t2.tween_method(_set_xp_shown, float(actual), float(tramo),
			clampf(0.9 * float(tramo - actual) / float(hasta - desde), 0.18, 0.9))
		if tramo < hasta or (tramo == frontera and tramo > actual):
			# Frontera cruzada: nivel nuevo.
			var nuevo := SkillData.level_for_xp(tramo)
			if nuevo > nivel:
				t2.tween_callback(_level_up_burst.bind(nuevo))
				t2.tween_interval(0.45)
		actual = tramo


func _set_xp_shown(v: float) -> void:
	_xp_shown = v
	_refresh_level_bar()


## El fogonazo de la subida: destello sobre la barra, "¡Nivel N!" que salta y
## una corona de estrellas que salen despedidas.
func _level_up_burst(nivel: int) -> void:
	if level_bar == null or not level_bar.visible:
		return
	# Destello blanco sobre la barra.
	var flash := ColorRect.new()
	flash.color = Color(1, 0.95, 0.7, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_bar.add_child(flash)
	var tf := flash.create_tween()
	tf.tween_property(flash, "color:a", 0.75, 0.08)
	tf.tween_property(flash, "color:a", 0.0, 0.4)
	tf.tween_callback(flash.queue_free)
	# La barra da un bote.
	var tb := level_bar.create_tween()
	tb.tween_property(level_bar, "scale", Vector2(1.12, 1.12), 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tb.tween_property(level_bar, "scale", Vector2.ONE, 0.26) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# "¡Nivel N!" salta desde la barra y se desvanece subiendo.
	var pop := Label.new()
	pop.text = "¡Nivel %d!" % nivel
	pop.add_theme_font_size_override("font_size", 34)
	pop.add_theme_color_override("font_color", Color(1.0, 0.86, 0.25))
	pop.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.02))
	pop.add_theme_constant_override("outline_size", 10)
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.position = Vector2(LVL_BAR_W * 0.5 - 70.0, -6.0)
	pop.pivot_offset = Vector2(70.0, 20.0)
	pop.scale = Vector2(0.3, 0.3)
	level_bar.add_child(pop)
	var tp := pop.create_tween()
	tp.tween_property(pop, "scale", Vector2.ONE, 0.28) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tp.tween_interval(0.35)
	tp.set_parallel(true)
	tp.tween_property(pop, "position:y", -64.0, 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tp.tween_property(pop, "modulate:a", 0.0, 0.6)
	tp.chain().tween_callback(pop.queue_free)
	# Corona de estrellas despedidas desde el centro.
	for i in 7:
		var e := TextureRect.new()
		e.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		e.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		e.texture = load("res://assets/ui/estrella_llena.png")
		e.size = Vector2(26, 26)
		e.position = Vector2(LVL_BAR_W * 0.5 - 13.0, LVL_BAR_H * 0.5)
		e.pivot_offset = Vector2(13, 13)
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		level_bar.add_child(e)
		var ang := TAU * float(i) / 7.0 + randf_range(-0.2, 0.2)
		var destino := e.position + Vector2(cos(ang), sin(ang) * 0.7) \
			* randf_range(90.0, 150.0)
		var te := e.create_tween().set_parallel(true)
		te.tween_property(e, "position", destino, 0.6) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		te.tween_property(e, "rotation_degrees", randf_range(-200.0, 200.0), 0.6)
		te.tween_property(e, "modulate:a", 0.0, 0.6).set_delay(0.15)
		te.chain().tween_callback(e.queue_free)


## El botón "+" que cabalga sobre el borde derecho de una caja.
func _add_plus(caja: Control, accion: Callable) -> void:
	var mas := TextureButton.new()
	mas.texture_normal = load("res://assets/ui/boton_mas.png")
	mas.ignore_texture_size = true
	mas.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	# A la DERECHA, cabalgando sobre el canto de la caja.
	mas.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	mas.custom_minimum_size = Vector2(48, 48)
	mas.size = Vector2(48, 48)
	mas.position = Vector2(-26.0, -24.0)
	mas.name = "Mas"
	PrepBoard.add_press_feedback(mas)
	mas.pressed.connect(accion)
	caja.add_child(mas)


## Apaga (o enciende) los tres botones "+" de las cajas de recursos. Lo usa la
## PESCA mientras hay un intento en juego: el panel de compra no para su reloj,
## así que abrirlo con el pez enganchado costaba los 50 doblones apostados.
func _set_plus_enabled(ocupado: bool) -> void:
	for caja in [ingot_box, money_box, rice_box]:
		if caja == null:
			continue
		var mas: Node = caja.get_node_or_null("Mas")
		if mas is TextureButton:
			var b := mas as TextureButton
			b.disabled = ocupado
			b.modulate = Color(1, 1, 1, 0.4 if ocupado else 1.0)


## Repinta las tres cifras, la barra del arroz y su cuenta atrás.
func _refresh_resources() -> void:
	if money_box == null:
		return
	GameState.tick_rice()
	(ingot_box.get_node("Valor") as Label).text = str(GameState.ingots)
	(money_box.get_node("Valor") as Label).text = str(GameState.money)
	(rice_box.get_node("Valor") as Label).text = str(GameState.rice)
	if rice_timer_label != null:
		var t := GameState.rice_time_text()
		rice_timer_label.text = t


## Dónde va cada contador. En el MENÚ los dos juntos y centrados; en el MAPA,
## el dinero pegado a la izquierda y el arroz a la derecha, dejando el hueco
## del medio para el rótulo de "Aventura".
## Las tres cajas van CENTRADAS arriba, y en el mismo sitio tanto en el menú
## como en el mapa: ya no viajan a los extremos (el rótulo de "Aventura" es el
## que baja para no colarse). `en_mapa` se conserva por si hiciera falta
## diferenciarlas más adelante.
## Dónde va cada caja. SIEMPRE LO MISMO: las tres cubren la banda de arriba y
## no se mueven al entrar en Aventura (el botón "Atrás" del mapa aparece
## DEBAJO de ellas, no a su lado). `en_mapa` se conserva por si alguna vez
## hiciera falta diferenciarlas.
func _resource_spots(_en_mapa: bool) -> Array:
	var x0 := RES_LEFT
	return [Vector2(x0, res_y),
		Vector2(x0 + RES_INGOT_W + RES_GAP, res_y),
		Vector2(x0 + RES_INGOT_W + RES_MONEY_W + RES_GAP * 2.0, res_y)]


func _place_resources(en_mapa: bool, animate: bool) -> void:
	if money_box == null:
		return
	var spots := _resource_spots(en_mapa)
	var cajas := [ingot_box, money_box, rice_box]
	# La BARRA DE NIVEL viaja con ellas: en el menú va centrada bajo los
	# contadores y en el mapa se corre a la DERECHA, a la altura del botón
	# "Atrás", que es la franja que dejó libre el lazo de "Aventura".
	var lvl := _level_bar_spot(en_mapa)
	home_lvl_y = lvl.y
	var mover_lvl: bool = level_bar != null and level_bar.visible
	if not animate:
		for i in cajas.size():
			cajas[i].position = spots[i]
		if level_bar != null:
			level_bar.position = lvl
			_refresh_level_bar()
		return
	if res_tween != null and res_tween.is_valid():
		res_tween.kill()
	res_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD) 			.set_ease(Tween.EASE_IN_OUT)
	for i in cajas.size():
		res_tween.tween_property(cajas[i], "position", spots[i], 0.75)
	if level_bar != null:
		_refresh_level_bar()
		if mover_lvl:
			res_tween.tween_property(level_bar, "position", lvl, 0.75)
		else:
			level_bar.position = lvl


## Dónde va la barra de nivel según la pantalla. En el MAPA se aparta a la
## derecha para no montarse con el botón "Atrás", que vive bajo los contadores.
func _level_bar_spot(en_mapa: bool) -> Vector2:
	var ancho := GameState.canvas_size().x
	var st := GameState.safe_top()
	if en_mapa:
		# CENTRADA EN EL HUECO que deja el botón "Atrás", no pegada al canto
		# derecho: así la barra sigue leyéndose como parte de la fila y no como
		# algo arrinconado.
		var libre := 16.0 + 150.0 + 16.0
		return Vector2((libre + ancho - LVL_BAR_W) * 0.5,
			16.0 + st + PrepBoard.RESOURCE_H + 40.0)
	return Vector2((ancho - LVL_BAR_W) * 0.5, LVL_BAR_Y + st)


## PAQUETES de lingotes (dinero real) y de arroz (a cambio de lingotes).
## `n` es lo que se lleva, `precio` el rótulo y `coste` lo que cuesta en
## lingotes (0 = se paga con dinero real, todavía sin implementar).
const PACKS_LINGOTES := [
	{ "n": 1, "icon": "ic_lingote", "precio": "1,00 €" },
	{ "n": 5, "icon": "pack_lingote_5", "precio": "4,50 €" },
	{ "n": 10, "icon": "pack_lingote_10", "precio": "8,00 €" },
]
## Monedas de oro a cambio de LINGOTES.
const PACKS_MONEDAS := [
	{ "n": 100, "icon": "pack_moneda_100", "coste": 1 },
	{ "n": 500, "icon": "pack_moneda_500", "coste": 4 },
	{ "n": 1000, "icon": "pack_moneda_1000", "coste": 8 },
]
const PACKS_ARROZ := [
	{ "n": 1, "icon": "ic_arroz", "coste": 1 },
	{ "n": 5, "icon": "pack_arroz_5", "coste": 3 },
	{ "n": 10, "icon": "pack_arroz_10", "coste": 7 },
]


## Al elegir el PRIMER puerto, David explica para qué sirve el arroz, con el
## foco puesto en su caja. Solo la primera vez (`rice_intro_done`).
##
## El foco es un velo oscuro con la caja del arroz POR ENCIMA (subiéndole el
## z_index un momento): en el mapa no está el paño con agujero de los guiones
## de nivel, y para señalar una sola cosa esto basta y no arrastra el shader.
## Las dos explicaciones del mapa, EN ORDEN: el arroz (que es de la barra de
## arriba) y después el primer puerto (que ya es del mapa). Encadenadas a mano
## porque las dos montan su propio velo y, lanzadas a la vez, se pisaban.
## LAS DOS EXPLICACIONES DEL MAPA VAN ENCADENADAS EN LA MISMA CAJA: David pasa
## del arroz a los tipos de nivel sin cerrar el pergamino y volver a entrar, que
## era un corte en mitad de una idea. `_explicar_arroz` devuelve su caja (o
## null) y la guía del primer puerto la reaprovecha.
## EL ARROZ YA NO SE EXPLICA AQUÍ. Se contaba antes de zarpar por primera vez,
## con los 20 sacos intactos, así que David tenía que hablar en futuro de algo
## que no se veía pasar. Ahora la charla va al VOLVER del nivel 1
## (`_menu_popups`), con el contador en 19: se señala el hueco y se entiende de
## una. Antes de zarpar solo se explica QUÉ es cada tipo de escenario.
func _presentar_mapa() -> void:
	_guiar_primer_nivel()


func _explicar_arroz() -> DialogueBox:
	if GameState.rice_intro_done or rice_box == null:
		return null
	GameState.rice_intro_done = true
	GameState.save_game()
	var velo := _velo_guia()
	var z_antes := rice_box.z_index
	rice_box.z_index = 180

	var caja := DialogueBox.new()
	caja.z_index = 200
	# El velo lo pone ESTA escena (con el saco por encima); el de la caja
	# oscurecería también el saco y el foco se perdería. Mismo apaño que hacen
	# los guiones de nivel (`story_director`).
	caja.veil_on = false
	ui_layer.add_child(caja)
	# SE CUENTA CON EL SACO YA GASTADO. Antes iba delante del primer nivel, con
	# los 20 intactos: David hablaba en futuro de algo invisible. Ahora sale al
	# volver de la primera jornada y el contador marca 19, así que lo que se
	# señala es el HUECO — la lección se ve, no se promete.
	caja.say([
		{ "text": "Antes de nada, %s: mira ese saco de ahí arriba." % GameState.player_title(), "mood": "hablando" },
		{ "text": "¿Lo ves? Ya no marca veinte. Es **arroz**, y cada jornada que sales a cocinar se lleva **un saco**.", "mood": "serio" },
		{ "text": "Sin arroz no hay sushi, y sin sushi no hay oro. Ese contador es lo que te dice cuántas jornadas te quedan.", "mood": "hablando" },
		{ "text": "¡SIN ARROZ NO SE NAVEGA! ¡RAAAK!", "who": "gigi", "mood": "loro" },
		{ "text": "Tranquilo, que se repone solo con el tiempo. Y por el camino conseguirás más de los que gastas.", "mood": "feliz" },
	])
	await caja.finished
	rice_box.z_index = z_antes
	_quitar_velo(velo)
	await caja.close_and_free()
	return null


## GUÍA POST-TUTORIAL: la primera vez que se pisa el menú, David señala el
## pergamino de AVENTURA y espera a que el jugador lo toque. Mismo apaño de
## foco que _explicar_arroz (velo oscuro + nodo por encima vía z_index); el
## z_index no cambia QUIÉN recibe el toque (el picking va por orden de árbol,
## y el velo, añadido el último, se lo queda todo), así que es el PROPIO VELO
## quien escucha y dispara la Aventura cuando el toque cae sobre el pergamino.
func _guiar_a_aventura() -> void:
	if GameState.menu_intro_done or aventura_btn == null:
		return
	# EL VELO VA LO PRIMERO, sin esperar. Antes se dejaban 0,8 s para que la
	# interfaz terminara de entrar y en ese hueco el menú estaba vivo: daba
	# tiempo de sobra a abrir la Tienda o los Logros antes de que David llegara
	# a decir nada. El velo traga los toques desde el primer fotograma, así que
	# ahora la espera se hace CON la puerta cerrada.
	if leaving or start_mode:
		return
	var velo := _velo_guia()
	await get_tree().create_timer(0.55).timeout
	if leaving or start_mode or not is_instance_valid(velo):
		return
	# El tablón entero por debajo del velo salvo el pergamino de Aventura.
	var z_antes := aventura_btn.z_index
	aventura_btn.z_index = 180

	var caja := DialogueBox.new()
	caja.z_index = 200
	caja.veil_on = false
	ui_layer.add_child(caja)
	caja.say([
		{ "text": "Este es tu **camarote de mando**, %s. De aquí se zarpa a todas partes." % GameState.player_title(), "mood": "feliz" },
		{ "text": "¿Ves ese pergamino iluminado? Es la **Aventura**: nuestra travesía de puerto en puerto. Lo demás ya caerá.", "mood": "hablando" },
		{ "text": "¡TÓCALO Y ZARPAMOS! ¡RAAAK!", "who": "gigi", "mood": "loro_grito" },
	])
	await caja.finished
	await caja.close_and_free()
	# El velo se queda puesto haciendo de compuerta: solo el toque que caiga
	# sobre el pergamino iluminado pasa, y pasa directo a la Aventura.
	velo.gui_input.connect(func(ev: InputEvent) -> void:
		var toque: bool = ev is InputEventScreenTouch and ev.pressed
		if not toque:
			return
		if not aventura_btn.get_global_rect().grow(10.0).has_point(ev.position):
			return
		GameState.menu_intro_done = true
		GameState.save_game()
		aventura_btn.z_index = z_antes
		_quitar_velo(velo)
		_go_adventure())


func _on_buy_ingots() -> void:
	_open_pack_panel("Lingotes de oro", PACKS_LINGOTES, true)


func _on_buy_coins() -> void:
	_open_pack_panel("Monedas de oro", PACKS_MONEDAS, false, true)


func _on_buy_rice() -> void:
	_open_pack_panel("Sacos de arroz", PACKS_ARROZ, false)


## Cartel de compra con TRES paquetes en fila. Es el mismo pergamino y la misma
## cinta que el resto de carteles del juego; lo que cambia son las tres cartas.
func _open_pack_panel(titulo: String, packs: Array, real: bool,
		monedas := false) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 160
	ui_layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := Control.new()
	box.custom_minimum_size = Vector2(680, 440)
	center.add_child(box)
	# Panel PROPIO de tienda (madera con toldo a rayas), no el pergamino de los
	# carteles normales: es su sitio y se dibuja a tamaño fijo, sin 9-slice.
	var fondo := TextureRect.new()
	fondo.texture = load("res://assets/ui/panel_tienda.png")
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_SCALE
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(fondo)
	# Titular estilizado DENTRO del toldo, no una cinta encima: el panel ya
	# tiene su propio remate y la tela sobraba.
	var rotulo := PrepBoard.make_big_title(titulo, 34)
	rotulo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	rotulo.offset_top = 18.0
	rotulo.offset_bottom = 92.0
	box.add_child(rotulo)

	var fila := HBoxContainer.new()
	fila.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Por DEBAJO del toldo, que se come el cuarto de arriba del dibujo.
	fila.offset_left = 44.0
	fila.offset_top = 118.0
	fila.offset_right = -44.0
	fila.offset_bottom = -96.0
	fila.add_theme_constant_override("separation", 10)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(fila)
	for pack in packs:
		fila.add_child(_pack_card(pack, real, overlay, monedas))

	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	cerrar.offset_left = 210.0
	cerrar.offset_right = -210.0
	cerrar.offset_top = -74.0
	cerrar.offset_bottom = -74.0 + PrepBoard.SMALL_H
	PrepBoard.skin_small_button(cerrar)
	cerrar.add_theme_font_size_override("font_size", 24)
	cerrar.pressed.connect(func() -> void: overlay.queue_free())
	box.add_child(cerrar)


## Una carta: pergamino liso, el montón, cuánto llevas y lo que cuesta.
func _pack_card(pack: Dictionary, real: bool, overlay: Control,
		monedas := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(172, 226)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.add_child(PrepBoard.make_nine_patch(
		PrepBoard.CARD_TEX, PrepBoard.CARD_MARGIN))
	PrepBoard.add_press_feedback(b, 0.96)

	var ic := TextureRect.new()
	ic.texture = load("res://assets/ui/%s.png" % pack["icon"])
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 12.0
	ic.offset_top = 10.0
	ic.offset_right = -12.0
	ic.offset_bottom = -98.0
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)

	var cuanto := Label.new()
	cuanto.text = "x%d" % int(pack["n"])
	cuanto.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	cuanto.offset_top = -100.0
	cuanto.offset_bottom = -58.0
	cuanto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cuanto.add_theme_font_size_override("font_size", 32)
	cuanto.add_theme_color_override("font_color", DARK)
	cuanto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cuanto)

	# El precio va en su propio botoncito, para que se lea como "esto se pulsa".
	var precio := Button.new()
	precio.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	precio.offset_left = 12.0
	precio.offset_right = -12.0
	precio.offset_top = -54.0
	precio.offset_bottom = -54.0 + PrepBoard.SMALL_H
	precio.text = str(pack["precio"]) if real else "%d" % int(pack["coste"])
	PrepBoard.skin_small_button(precio)
	# Es el número que decide la compra: con 22 px se leía como una nota al pie.
	precio.add_theme_font_size_override("font_size", 30)
	precio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(precio)
	# En el arroz, el precio va en LINGOTES: se enseña la moneda al lado.
	if not real:
		var mon := TextureRect.new()
		mon.texture = load("res://assets/ui/ic_lingote.png")
		mon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mon.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		mon.size = Vector2(34, 34)
		mon.position = Vector2(26.0, -17.0)
		mon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		precio.add_child(mon)
		precio.alignment = HORIZONTAL_ALIGNMENT_RIGHT

	b.pressed.connect(func() -> void: _comprar(pack, real, overlay, monedas))
	return b


func _comprar(pack: Dictionary, real: bool, overlay: Control,
		monedas := false) -> void:
	if monedas:
		_comprar_monedas(pack, overlay)
		return
	if real:
		# La compra con dinero real todavía no existe: el cartel está montado
		# para poder verlo, pero no cobra nada.
		_aviso("Las tiendas de verdad todavía no están abiertas, %s. "
			+ "Pronto podrás traer lingotes de tierra firme.")
		return
	# CON EL SACO LLENO no se vende nada: ni se cobra ni se pierde el paquete.
	if GameState.rice >= GameState.RICE_START:
		_aviso_gigi("¡RAAAK! ¿Más arroz? ¡Si no te cabe ni un grano más, %s! "
			+ "Guárdate los lingotes para cuando hagan falta.")
		return
	# El cobro es PROPORCIONAL a lo que de verdad cabe (ver GameState.rice_deal),
	# y se confirma SIEMPRE: gastar lingotes no puede ser un toque despistado.
	var trato := GameState.rice_deal(int(pack["n"]), int(pack["coste"]))
	_confirmar_arroz(pack, trato, overlay)


## Cartel de confirmación de la compra de arroz. Avisa cuando el paquete se
## recorta por el tope ("solo te caben 3 de los 5").
func _confirmar_arroz(pack: Dictionary, trato: Dictionary, overlay: Control) -> void:
	var sacos := int(trato["sacos"])
	var coste := int(trato["coste"])
	var recortado: bool = sacos < int(pack["n"])
	var texto := "¿Cambias %d lingote%s por %d saco%s de arroz?" % [
		coste, "" if coste == 1 else "s", sacos, "" if sacos == 1 else "s"]
	if recortado:
		texto += "
Solo te caben %d de los %d, así que se cobra la parte." % [
			sacos, int(pack["n"])]
	if GameState.ingots < coste:
		_aviso("No te llegan los **lingotes**, %s. Ese saco cuesta más de lo "
			+ "que llevas encima.")
		return

	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0.5)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.z_index = 170
	ui_layer.add_child(velo)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.add_child(center)
	var box := Control.new()
	box.custom_minimum_size = Vector2(520, 320)
	center.add_child(box)
	box.add_child(PrepBoard.make_nine_patch(
		PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))
	PrepBoard.add_panel_banner(box, "¿Trato hecho?", 28)

	var msg := Label.new()
	msg.text = texto
	msg.set_anchors_preset(Control.PRESET_FULL_RECT)
	msg.offset_left = 56.0
	msg.offset_top = 82.0
	msg.offset_right = -56.0
	msg.offset_bottom = -118.0
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 23)
	msg.add_theme_color_override("font_color", DARK)
	box.add_child(msg)

	var btns := HBoxContainer.new()
	btns.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	btns.offset_left = 40.0
	btns.offset_right = -40.0
	btns.offset_top = -102.0
	btns.offset_bottom = -34.0
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	box.add_child(btns)
	var no := Button.new()
	no.text = "No"
	no.custom_minimum_size = Vector2(176, PrepBoard.ICON_BTN_H)
	PrepBoard.skin_action_button(no, false)
	no.add_theme_font_size_override("font_size", 26)
	no.pressed.connect(func() -> void: velo.queue_free())
	btns.add_child(no)
	var si := Button.new()
	si.text = "¡Trato!"
	si.custom_minimum_size = Vector2(216, PrepBoard.ICON_BTN_H)
	PrepBoard.skin_action_button(si, true)
	si.add_theme_font_size_override("font_size", 26)
	si.pressed.connect(func() -> void:
		GameState.buy_rice(sacos, coste)
		_refresh_resources()
		velo.queue_free()
		overlay.queue_free())
	btns.add_child(si)


## Monedas a cambio de lingotes. No hay tope de monedas, así que aquí no hay
## recorte proporcional: o se paga entero o no se compra.
func _comprar_monedas(pack: Dictionary, overlay: Control) -> void:
	var coste := int(pack["coste"])
	if GameState.ingots < coste:
		_aviso("No te llegan los **lingotes**, %s. Ese puñado de monedas "
			+ "cuesta más de lo que llevas encima.")
		return
	GameState.ingots -= coste
	GameState.money += int(pack["n"])
	GameState.save_game()
	_refresh_resources()
	overlay.queue_free()


## Aviso en boca de GIGI (el loro es quien regaña en este juego).
func _aviso_gigi(texto: String) -> void:
	var caja := DialogueBox.new()
	caja.z_index = 200
	ui_layer.add_child(caja)
	caja.say([{ "text": texto % GameState.player_title(),
		"who": "gigi", "mood": "loro_grito" }])
	await caja.finished
	caja.queue_free()


func _aviso(texto: String) -> void:
	var caja := DialogueBox.new()
	# Por DELANTE del cartel de compra (z_index 160/170): sin esto el aviso
	# salía detrás de la tienda y no se leía.
	caja.z_index = 200
	ui_layer.add_child(caja)
	caja.say([{ "text": texto % GameState.player_title(), "mood": "hablando" }])
	await caja.finished
	caja.queue_free()


## EL TIMÓN del menú: se agarra y se gira con el dedo, y al soltarlo sigue
## girando con la inercia que lleve. No hace NADA — es el huevo de pascua del
## menú. El giro se mide por el CAMBIO de ángulo respecto al centro
## (`wrapf` a ±PI, o el salto de -179° a +179° pegaba un latigazo).
func _on_wheel_input(e: InputEvent) -> void:
	var c := Vector2(WHEEL_SIZE, WHEEL_SIZE) * 0.5
	if e is InputEventScreenTouch:
		var toque := e as InputEventScreenTouch
		if toque.pressed:
			wheel_grab = true
			wheel_last_ang = (toque.position - c).angle()
			wheel_vel = 0.0
		else:
			wheel_grab = false
	elif e is InputEventScreenDrag and wheel_grab:
		var a := ((e as InputEventScreenDrag).position - c).angle()
		var d := wrapf(a - wheel_last_ang, -PI, PI)
		wheel_last_ang = a
		wheel.rotation += d
		_bank_wheel_turns(absf(d))
		var dt := maxf(get_process_delta_time(), 0.001)
		wheel_vel = lerpf(wheel_vel, d / dt, 0.45)


## Abona a la estadística cada VUELTA COMPLETA del timón. A las 5,
## `GameState._run_achievement_check` suelta el coleccionable "timón".
func _bank_wheel_turns(rad: float) -> void:
	wheel_turn_acc += rad
	while wheel_turn_acc >= TAU:
		wheel_turn_acc -= TAU
		GameState.bump_stat("helm_turns")


## El SUBMENÚ inferior: la barra de madera con cuerda y sus cinco accesos.
func _setup_submenu() -> void:
	submenu_bar = Control.new()
	submenu_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	submenu_bar.offset_left = 6.0
	submenu_bar.offset_right = -6.0
	submenu_bar.offset_bottom = -SUB_BOTTOM - GameState.safe_bottom()
	submenu_bar.offset_top = -SUB_BOTTOM - SUB_BAR_H - GameState.safe_bottom()
	ui_layer.add_child(submenu_bar)

	var np := NinePatchRect.new()
	np.texture = load("res://assets/ui/submenu_barra.png")
	np.patch_margin_left = SUB_BAR_MARGIN
	np.patch_margin_right = SUB_BAR_MARGIN
	np.set_anchors_preset(Control.PRESET_FULL_RECT)
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	submenu_bar.add_child(np)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Por dentro de la cuerda del canto y de los extremos redondeados.
	row.offset_left = 24.0
	row.offset_right = -24.0
	row.offset_top = 18.0
	row.offset_bottom = -10.0
	submenu_bar.add_child(row)
	# SOLO ICONOS, sin rótulo: con los cinco rehechos al estilo del cartel de
	# Perfil ya se explican solos, y el texto a cuerpo 15 solo ensuciaba.
	# Las MAESTRÍAS no tienen icono aquí: su acceso es la BARRA DE NIVEL del
	# centro del menú (`_setup_level_bar`), que además enseña el progreso.
	for def in [
			["ic_logros", func() -> void: _go_achievements()],
			["ic_inventario", func() -> void: _go_inventory()],
			["ic_perfil", func() -> void: _go_profile()],
			["ic_perks", func() -> void: _go_perks()],
			["ic_opciones", func() -> void: _go_options()]]:
		var sub := _make_sub_button(str(def[0]), def[1])
		row.add_child(sub)
		# GLOBO ROJO sobre Logros: medallas conseguidas y aún sin reclamar.
		if str(def[0]) == "ic_logros":
			_attach_badge(sub, GameState.unclaimed_medals())


## Globo rojo con número (medallas por reclamar) cabalgando la esquina superior
## derecha del icono. Con 0 no se monta nada.
func _attach_badge(host: Control, count: int) -> void:
	# El dibujo vive en el set de interfaz (PrepBoard): el mismo globo lo usa la
	# pantalla de Logros sobre cada tarjeta y sobre cada pestaña.
	PrepBoard.attach_badge(host, count)


## Un acceso del submenú: el icono solo, centrado, sin tablón propio (la barra
## es el fondo de los cinco).
func _make_sub_button(icon: String, action: Callable) -> Control:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = load("res://assets/ui/%s.png" % icon)
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_top = 8.0
	ic.offset_bottom = -8.0
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	b.pressed.connect(action)
	PrepBoard.add_press_feedback(b, 0.9)
	return b


## Flotación y balanceo del logotipo. Se guardan para poder PARARLOS: si siguen
## corriendo durante una transición, tiran del logotipo hacia su sitio y no
## llega a salir de la pantalla.
func _start_logo_idle() -> void:
	if leaving or not in_menu or not GameState.animations_on():
		return
	logo.position.y = 0.0
	logo_float = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	logo_float.tween_property(logo, "position:y", 14.0, 1.9)
	logo_float.tween_property(logo, "position:y", -14.0, 1.9)
	logo_sway = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	logo_sway.tween_property(logo, "rotation", deg_to_rad(1.4), 2.6)
	logo_sway.tween_property(logo, "rotation", deg_to_rad(-1.4), 2.6)


func _stop_logo_idle() -> void:
	for t in [logo_float, logo_sway]:
		if t != null and t.is_valid():
			t.kill()
	logo_float = null
	logo_sway = null


## Botón del menú: tabla de madera con marco dorado, icono a la izquierda y
## rótulo centrado sobre el conjunto.
## Botón de modo = un PERGAMINO (`boton_pergamino.png`, 9-slice SOLO
## horizontal: los rollos de los extremos van en el margen y la banda de papel
## es lo único que se estira; la textura se exporta al alto EXACTO de dibujo,
## MODE_BTN_H, con margen vertical CERO — la regla de los botones con icono).
## El icono va PINTADO en el papel (versión a tinta, pequeña) y el rótulo en
## tinta oscura con sombra, como escrito a pincel.
func _make_mode_button(text: String, icon: String, _height: int,
		font_size: int, action: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, MODE_BTN_H)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	PrepBoard.add_press_feedback(b, 0.94)
	b.pressed.connect(action)

	var papel := NinePatchRect.new()
	papel.texture = load("res://assets/ui/boton_pergamino.png")
	papel.patch_margin_left = MODE_BTN_ROLL
	papel.patch_margin_right = MODE_BTN_ROLL
	papel.set_anchors_preset(Control.PRESET_FULL_RECT)
	papel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(papel)

	var icon_rect := TextureRect.new()
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = load("res://assets/ui/%s.png" % icon)
	# Dentro del papel, pasado el rollo izquierdo, y CONTENIDO: pintado en el
	# pergamino, no cabalgando el botón como el emblema de antes.
	icon_rect.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	icon_rect.offset_left = MODE_BTN_ROLL + 6.0
	icon_rect.offset_right = MODE_BTN_ROLL + 6.0 + 54.0
	icon_rect.offset_top = 17.0
	icon_rect.offset_bottom = -17.0
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon_rect)

	var label := Label.new()
	label.text = text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = MODE_BTN_ROLL + 58.0
	label.offset_right = -MODE_BTN_ROLL - 8.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	# Letra CLARA con el trazo OSCURO (se probó al revés — tinta oscura con
	# sombra clara — y pesaba poco sobre el papel).
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.84))
	label.add_theme_color_override("font_outline_color", Color(0.30, 0.17, 0.07))
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_shadow_color", Color(0.42, 0.27, 0.12, 0.5))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 3)
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		label.add_theme_font_override("font", negrita)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(label)
	return b


# ------------------------------------------------------------ transiciones

## Aparta la interfaz del menú: logotipo arriba, botones abajo, monedero arriba.
## Aparta la interfaz del menú: logotipo arriba, botones abajo, monedero
## arriba. Se anima el CONTENEDOR del logotipo (no el logotipo, que lo mueve
## su balanceo) y siempre contra posiciones ABSOLUTAS de reposo: con valores
## relativos, cada salida acumulaba desplazamiento y la entrada devolvía los
## botones a un sitio equivocado.
## `con_recursos` a false deja QUIETOS los contadores de dinero y arroz: al ir
## a Aventura no se van de la pantalla, viajan a los extremos del mapa
## (`_place_resources`). Si se los llevaba esta salida, los dos tweens peleaban
## por la misma propiedad y las cajas se quedaban a medio camino.
## `con_nivel` a false deja la BARRA DE NIVEL quieta: al ir al mapa no se va,
## se queda y la corre `_place_resources` hacia la derecha. Si se fuera aquí
## arriba, los dos tweens pelearían por su `position`.
func _ui_out(con_recursos := true, con_nivel := true) -> void:
	if ui_tween != null and ui_tween.is_valid():
		ui_tween.kill()
	# (El logotipo ya no viaja con el menú: se quedó en la portada.)
	ui_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_IN)
	ui_tween.tween_property(menu_panel, "position:y", home_box_y + 660.0, OUT_TIME)
	ui_tween.tween_property(submenu_bar, "position:y", home_sub_y + 260.0, OUT_TIME)
	# La barra de nivel se va SIEMPRE hacia arriba (es del menú, no del mapa
	# ni de la pesca), aunque las cajas de recursos se queden.
	if con_nivel and level_bar != null and level_bar.visible:
		ui_tween.tween_property(level_bar, "position:y", home_lvl_y - 220.0,
			OUT_TIME)
	if con_recursos:
		for caja in [ingot_box, money_box, rice_box]:
			if caja != null:
				ui_tween.tween_property(caja, "position:y", res_y - 220.0, OUT_TIME)
	# Y AL FINAL SE OCULTAN DEL TODO. El tablón mide ~575 px y solo baja 660
	# desde su sitio, así que un buen palmo suyo —y el timón, que sobresale por
	# arriba— se quedaba ASOMANDO por el canto inferior durante toda la
	# transición. Se veía clarísimo al ir a la Tienda, donde la cámara viaja
	# despacio y no hay fundido a negro que lo tape.
	ui_tween.chain().tween_callback(func() -> void:
		menu_panel.visible = false
		submenu_bar.visible = false)


## Nubes y gaviotas ENTRAN planeando desde arriba (ver `sky_drop`): sin esto
## aparecían de golpe al llegar al menú.
func _sky_in() -> void:
	sky_leaving = false
	sky_drop = 9.0
	# RECOLOCAR ANTES DE ENCENDER (ver `_place_sky`): al revés se veían un
	# fotograma en su posición vieja, el parpadeo.
	_place_sky()
	for b in birds:
		b["node"].visible = true
	for c in clouds:
		c["node"].visible = true
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT) \
			.tween_property(self, "sky_drop", 0.0, 1.3)


## Nubes y gaviotas se van hacia arriba, fuera del encuadre.
##
## `sky_leaving` PARA su colocación por frame mientras dura la subida: `_process`
## les fija la posición entera cada fotograma (viven alrededor del barco), así
## que peleaba con el tween y se las veía desaparecer y reaparecer de golpe.
func _sky_out(time := 0.8) -> void:
	sky_leaving = true
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN)
	for c in clouds:
		tw.tween_property(c["node"], "position:y", 16.0, time).as_relative()
	for b in birds:
		tw.tween_property(b["node"], "position:y", 18.0, time).as_relative()


## TUTORIAL: repite la clase de David cuando se quiera. Va DIRECTO al nivel
## guiado (la bienvenida con nombre y género es solo de la primera vez); al
## terminar vuelve aquí. No toca el progreso: solo re-entrega las 4 recetas
## del tutorial, que ya se tienen.
func _go_tutorial() -> void:
	if leaving:
		return
	leaving = true
	GameState.mode = "tutorial"
	GameState.current_port = ""
	var recs: Array[String] = []
	for r in CampaignData.INITIAL_RECIPES:
		recs.append(r)
	GameState.selected_recipes = recs
	GameState.selected_perks = []
	_ui_out()
	_sky_out(0.75)
	var tw := create_tween()
	tw.tween_interval(OUT_TIME + 0.08)
	tw.tween_callback(func() -> void:
		GameState.fade_to_scene("res://scenes/level3d.tscn", 0.3, 0.45))


## AVENTURA: sin cambiar de escena. El barco leva anclas y navega hasta el
## último nivel abierto mientras la interfaz del menú se retira.
func _go_adventure() -> void:
	if leaving:
		return
	leaving = true
	# Los contadores NO salen: se quedan y viajan a los extremos del mapa, y la
	# BARRA DE NIVEL tampoco — se queda y se corre a la derecha con ellos.
	_ui_out(false, false)
	_sky_out(0.9)
	var tw := create_tween()
	# El barco no leva anclas hasta que el logotipo y los botones han SALIDO
	# del todo; si no, se ven irse a la vez que entra el mapa.
	tw.tween_interval(OUT_TIME + 0.08)
	tw.tween_callback(func() -> void:
		_set_menu_ui_visible(false)
		_enter_map(true))


## Vuelta del mapa al menú: el barco desanda el camino y todo reaparece.
func _back_to_menu() -> void:
	if leaving:
		return
	leaving = true
	_map_ui_fade(false)
	map_visible = false
	in_menu = true
	if ship_tween != null:
		ship_tween.kill()
	var dur := 1.5
	var scale_tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	scale_tw.tween_property(ship_pivot, "scale",
		Vector3.ONE * MENU_SHIP_SCALE, dur * 0.8).set_delay(dur * 0.2)
	scale_tw.tween_property(ship_blob, "scale",
		Vector3.ONE * MENU_SHIP_SCALE, dur * 0.8).set_delay(dur * 0.2)
	ship_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ship_tween.tween_property(self, "ship_px", MENU_ANCHOR, dur)
	ship_tween.parallel().tween_property(self, "cam_center", MENU_ANCHOR.y, dur)
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(
		self, "menu_blend", 1.0, dur * 0.7)
	# La interfaz vuelve con su propio temporizador: colgarla del tween del
	# barco (que va en paralelo con la cámara) se comía la animación.
	get_tree().create_timer(dur * 0.55).timeout.connect(func() -> void:
		leaving = false
		# Gaviotas y nubes vuelven a colgar del barco (se habían apartado).
		_set_map_ui_visible(false)
		_set_menu_ui_visible(true)
		_sky_in()
		# Los contadores DESANDAN el viaje: de los extremos del mapa al centro.
		# Sin esto se quedaban donde los dejó Aventura. La BARRA DE NIVEL
		# vuelve CON ellos, y por eso `_ui_in` no la toca: si no, el tween de
		# la entrada y el del viaje pelearían por su `position`.
		_ui_in(false, false)
		_place_resources(false, true))


## ARCADE: el barco se va por la derecha y deja SOLO EL MAR de fondo; el
## selector de recetas entrará desde arriba.
func _go_arcade() -> void:
	if leaving:
		return
	if not GameState.arcade_unlocked():
		_show_locked_notice("El Arcade sin fin se abre al vencer al Kappa\nen la Cueva del Kappa (escenario 20).")
		return
	leaving = true
	GameState.mode = "test"
	GameState.current_port = ""
	GameState.selected_recipes = []
	_ui_out()
	_sky_out(0.75)
	# Se mueve el barco en píxeles de mapa y la cámara se queda quieta: al
	# final del viaje, en pantalla solo queda el agua.
	var tw := create_tween()
	tw.tween_property(self, "ship_px", ship_px + Vector2(OFFSCREEN, 0.0), 0.85) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# El cambio de escena va por el fundido del autoload: el velo SOBREVIVE a la
	# carga, que es lo único que tapa los fotogramas grises del motor.
	tw.tween_callback(func() -> void:
		GameState.transition = "arcade"
		GameState.fade_to_scene("res://scenes/prep_screen.tscn", 0.3, 0.45))


## Aviso de modo bloqueado: pergamino centrado que aparece con un bote, se
## queda un par de segundos y se desvanece solo.
## La PESCA no cambia de escena: como Aventura, se juega SOBRE el propio menú
## (mismo mar, barco quieto donde está). La interfaz se aparta con
## `_ui_out(false)` —las cajas de recursos SE QUEDAN, que el intento cuesta
## dinero y hay que verlo— y `FishingGame` se cuelga del ui_layer; su señal
## `closed` deshace el camino. `leaving` solo cubre el tránsito: con la pesca
## puesta vuelve a false para que el mar y el barco sigan animando.
func _go_fishing() -> void:
	if leaving or fishing_ui != null:
		return
	if not GameState.fishing_unlocked():
		_show_locked_notice("La Pesca se abre al superar\nla Isla de Gades (nivel 8).")
		return
	leaving = true
	# La BARRA DE NIVEL se queda: en la pesca cada captura paga experiencia y
	# hay que VERLA subir. Se queda solo de escaparate — `MOUSE_FILTER_IGNORE`,
	# porque el panel táctil de la pesca cubre la pantalla entera y una barra
	# pulsable encima sería una trampa para irse a Maestrías con el pez cogido.
	_ui_out(false, false)
	if level_bar != null:
		level_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# UNA FILA MÁS ABAJO que en el menú: arriba están el "Atrás" de la
		# pesca y el botón del álbum, uno en cada esquina, y la barra les caía
		# justo encima. Al cerrar, `_ui_in` la devuelve a su altura de siempre.
		level_bar.position.y = home_lvl_y + LVL_BAR_PESCA
	var tw := create_tween()
	tw.tween_interval(OUT_TIME + 0.05)
	tw.tween_callback(func() -> void:
		leaving = false
		# (`_ui_out` ya ha escondido el tablón y el submenú al acabar de bajarlos.)
		fishing_ui = preload("res://scripts/fishing_game.gd").new()
		ui_layer.add_child(fishing_ui)
		fishing_ui.closed.connect(_on_fishing_closed)
		fishing_ui.money_changed.connect(_refresh_resources)
		fishing_ui.busy_changed.connect(_set_plus_enabled)
		fishing_ui.xp_gained.connect(_xp_en_la_barra)
		fishing_ui.rush_changed.connect(_on_pesca_rush)
		# CON EL ÁLBUM ABIERTO, LA BARRA SE QUITA DE EN MEDIO: va por encima de
		# la pesca (para que no se la trague su panel táctil) y por eso se
		# dibujaba sobre las fichas de los peces.
		fishing_ui.album_abierto.connect(func(on: bool) -> void:
			if level_bar != null and is_instance_valid(level_bar):
				level_bar.visible = not on)
		# La barra, POR ENCIMA de la pesca (mismo motivo que las cajas).
		if level_bar != null:
			ui_layer.move_child(level_bar, -1)
		# LAS CAJAS DE RECURSOS, POR ENCIMA DE LA PESCA. Su panel táctil ocupa
		# la pantalla entera con MOUSE_FILTER_STOP, y como se cuelga DESPUÉS que
		# las cajas se llevaba también los toques de sus botones "+": pulsarlos
		# no hacía nada. El reparto de toques va por orden de árbol, así que
		# basta con mandarlas al final.
		for caja in [ingot_box, money_box, rice_box]:
			if caja != null:
				ui_layer.move_child(caja, -1))


## "+N exp" flotando sobre la BARRA DE NIVEL y la barra llenándose, con cada
## captura. Es lo que hace que la experiencia de la pesca se vea: sin esto se
## sumaba en silencio y el jugador solo notaba el salto al volver al menú.
func _xp_en_la_barra(cantidad: int) -> void:
	if level_bar == null or cantidad <= 0:
		return
	# La barra puede estar aún oculta (primera experiencia de la partida).
	_refresh_level_bar()
	if not level_bar.visible:
		return
	var l := Label.new()
	l.text = "+%d exp" % cantidad
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color(0.62, 0.86, 1))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.12, 0.24))
	l.add_theme_constant_override("outline_size", 9)
	var negrita := load("res://fonts/static/Exo2-Bold.ttf")
	if negrita != null:
		l.add_theme_font_override("font", negrita)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size = Vector2(LVL_BAR_W, 40.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0.0, LVL_BAR_H * 0.5)
	level_bar.add_child(l)
	var t := l.create_tween().set_parallel(true)
	# DURA MÁS (0.9 s se leía a medias, sobre todo con el cartel del pez
	# encima): sube despacio y se va al final.
	t.tween_property(l, "position:y", -46.0, 2.2) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.5)
	t.chain().tween_callback(l.queue_free)
	# Y la barra sube de verdad (con su fogonazo si cruza un nivel).
	_play_xp_anim_if_pending()


## EL PEZ TIRA CON FUERZA: la camara TIEMBLA y se acerca un pelin, y al
## aflojar vuelve sola a su sitio. El aviso llega de `FishingGame` (senal
## `rush_changed`), que ademas enciende las lineas de accion y mueve la cana.
##
## `cam_size_base` se GUARDA al empezar el tiron y NO se supone: el menu
## cambia `cam.size` en sus transiciones (el atraque de la tienda), y clavar
## aqui la constante dejaria el encuadre torcido si algo se solapa.
const RUSH_SHAKE := 5.0
const RUSH_ZOOM_IN := 0.965


func _on_pesca_rush(on: bool) -> void:
	if cam == null:
		return
	if on and cam_size_base <= 0.0:
		cam_size_base = cam.size
	if rush_tween != null and rush_tween.is_valid():
		rush_tween.kill()
	rush_tween = create_tween().set_parallel()
	rush_tween.tween_property(self, "cam_shake",
		RUSH_SHAKE if on else 0.0, 0.18 if on else 0.35)
	rush_tween.tween_property(self, "cam_zoom", 1.0 if on else 0.0,
		0.22 if on else 0.35)



func _on_fishing_closed() -> void:
	if fishing_ui == null:
		return
	fishing_ui.queue_free()
	fishing_ui = null
	if level_bar != null:
		level_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_plus_enabled(false)
	_refresh_resources()
	# (`_ui_in` vuelve a encender el tablón y el submenú, y de paso anima la
	# experiencia pendiente y anuncia la subida: la pesca PAGA XP por captura.)
	_ui_in(false)
	# LAS ESCENAS DE COLECCIONABLE que hayan caído en esta visita (el corazón
	# con el apellido de David, el tenedor...). Se cuentan al SALIR de la
	# pesca, no al sacarlos: allí el jugador está peleando con la caña.
	while not GameState.pending_col_scenes.is_empty():
		await _escena_coleccionable(GameState.pending_col_scenes[0])


func _show_locked_notice(text: String) -> void:
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280.0
	panel.offset_top = -110.0
	panel.offset_right = 280.0
	panel.offset_bottom = 110.0
	panel.pivot_offset = Vector2(280.0, 110.0)
	ui_layer.add_child(panel)
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))
	var l := Label.new()
	l.text = text
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_left = 40.0
	l.offset_right = -40.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(0.26, 0.16, 0.08))
	panel.add_child(l)
	panel.scale = Vector2(0.6, 0.6)
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.28) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(panel, "modulate:a", 1.0, 0.18)
	tw.tween_interval(2.2)
	tw.tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(panel.queue_free)


## Icono y cifra de cada cosa que puede caer en un premio diario.
const DAILY_ICONS: Dictionary = {
	"money": "res://assets/ui/moneda.png",
	"rice": "res://assets/ui/ic_arroz.png",
	"ingots": "res://assets/ui/ic_lingote.png",
	"extras": "res://assets/ingredients/jengibre.png",
}

## Los CUATRO estados del cofre. Los dos de "mapa" son el MISMO dibujo pasado a
## tinta por `inkify` de tools/ui2_prep.py, no otro cofre: si el de hoy tuviera
## otra silueta que sus vecinos, encenderse parecería cambiar de objeto.
const DAILY_CHEST_TEX: Dictionary = {
	"cerrado": "res://assets/ui/daily_cofre.png",
	"abierto": "res://assets/ui/daily_cofre_abierto.png",
	"mapa": "res://assets/ui/daily_cofre_mapa.png",
	"mapa_abierto": "res://assets/ui/daily_cofre_mapa_abierto.png",
}
const DAILY_MAP_TEX := "res://assets/ui/daily_mapa.png"

## El alto sale de sumar: 66 de aire + el mapa + el pie + el botón "Continuar".
## Con 840 el pie caía ENCIMA del mapa, que no cabía por 20 px.
const DAILY_PANEL := Vector2(640, 900)
const DAILY_MAP := Vector2(500, 665)

## Cartel del botín. Es más estrecho que el panel del mapa A PROPÓSITO: con 600
## sobre 640 parecía un pergamino pegado sobre otro en vez de un cartel encima.
const DAILY_REWARD_W := 560.0
## Fichas por fila y alto de cada fila. `_daily_chip` mide DAILY_CHIP de ancho,
## así que cuatro más sus separaciones (430) entran justas en el interior del
## pergamino (560 - 2 x 54 = 452).
const DAILY_CHIP := 100
const DAILY_CHIPS_ROW := 4
const DAILY_ROW_H := 142.0
## Hueco de cada parada: el cofre se dibuja dentro con KEEP_ASPECT_CENTERED, así
## que el cerrado (160x136) y el abierto (160x147) caben los dos sin saltar de
## tamaño al abrirse.
const DAILY_SPOT := Vector2(104, 96)

## Los siete sitios de la ruta, en FRACCIONES del mapa. Suben desde abajo
## repartidos a PARTES IGUALES por todo el alto (0.845 -> 0.135, un escalón de
## 0.118 cada uno): la primera versión los amontonaba en el tercio de abajo y
## dejaba la mitad de arriba vacía.
##
## El zigzag es AMPLIO por obligación, no por gusto. Con las siete alturas
## repartidas quedan ~78 px entre filas y el hueco del cofre mide 96 de alto,
## así que dos cofres seguidos SIEMPRE se solapan en vertical: lo único que los
## separa es la horizontal, y ahí tienen que distanciarse más que el ancho del
## hueco (104 px) o las cajas se pisan. Todos los saltos van de 110 px arriba.
##
## Dentro de eso, la columna de cada fila esquiva lo que el pergamino ya trae
## dibujado: la rosa de los vientos arriba a la izquierda, la voluta de la
## esquina superior derecha, el barco a media altura por la derecha, la isla de
## la palmera por la izquierda, y la palmera y el peñasco de abajo.
const DAILY_ROUTE: Array = [
	Vector2(0.630, 0.845),
	Vector2(0.390, 0.727),
	Vector2(0.610, 0.608),
	Vector2(0.370, 0.490),
	Vector2(0.620, 0.372),
	Vector2(0.320, 0.253),
	Vector2(0.540, 0.135),
]

## La tinta del propio pergamino, para que la ruta se lea como parte del mapa.
const DAILY_INK := Color(0.37, 0.24, 0.14)
const DAILY_DOT := 3.0
const DAILY_DOT_STEP := 15.0
## La raya se recorta por los dos extremos: sin esto los primeros puntos se
## meten debajo del cofre y la ruta parece salir de su tapa.
const DAILY_ROUTE_GAP := 44.0


## Ruta de puntos entre las siete paradas, pintada por código y no en la
## textura: es la única forma de que los cofres caigan CLAVADOS sobre la línea
## (con la ruta dibujada en el mapa, cualquier retoque del encuadre la
## descoloca). Mismo criterio que la barra de progreso o las chapas.
func _draw_daily_route(c: Control) -> void:
	var puntos: Array[Vector2] = []
	for f in DAILY_ROUTE:
		puntos.append((f as Vector2) * DAILY_MAP)
	for i in range(puntos.size() - 1):
		var a: Vector2 = puntos[i]
		var b: Vector2 = puntos[i + 1]
		var largo := a.distance_to(b)
		if largo <= DAILY_ROUTE_GAP * 2.0:
			continue
		var dir := (b - a) / largo
		var d := DAILY_ROUTE_GAP
		while d < largo - DAILY_ROUTE_GAP:
			c.draw_circle(a + dir * d, DAILY_DOT, DAILY_INK)
			d += DAILY_DOT_STEP


## Cartel del BONUS DIARIO: un mapa del tesoro con los siete días. Los días
## pasados salen con el cofre ABIERTO y los que faltan CERRADO, los dos
## dibujados a tinta como parte del mapa; el de hoy es el único a COLOR y se
## mece esperando que lo abran.
##
## A diferencia de la versión anterior, el premio NO se cobra al abrir el
## cartel: se cobra al TOCAR el cofre. Por eso el cartel no se puede cerrar
## hasta entonces (no hay X ni toque fuera), o sería posible saltárselo sin
## querer y perder el día.
func _show_daily() -> void:
	var dia := GameState.daily_next_day()

	# Velo a pantalla completa: oscurece el menú y, sobre todo, se traga los
	# toques. Sin él los botones de detrás siguen respondiendo y se puede
	# navegar fuera con el cofre a medio abrir.
	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0.55)
	velo.size = GameState.canvas_size()
	velo.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(velo)

	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -DAILY_PANEL.x * 0.5
	panel.offset_top = -DAILY_PANEL.y * 0.5
	panel.offset_right = DAILY_PANEL.x * 0.5
	panel.offset_bottom = DAILY_PANEL.y * 0.5
	panel.pivot_offset = DAILY_PANEL * 0.5
	velo.add_child(panel)
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))
	# El rótulo sale DESDE UN LAZO: la cinta del juego cabalgando sobre el canto
	# superior del pergamino, que es justo lo que hace `add_panel_banner`.
	PrepBoard.add_panel_banner(panel, "Bonus diario", 36, 20.0)

	var mapa := TextureRect.new()
	mapa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mapa.stretch_mode = TextureRect.STRETCH_SCALE
	mapa.texture = load(DAILY_MAP_TEX)
	mapa.position = Vector2((DAILY_PANEL.x - DAILY_MAP.x) * 0.5, 66.0)
	mapa.size = DAILY_MAP
	mapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(mapa)

	var ruta := Control.new()
	ruta.set_anchors_preset(Control.PRESET_FULL_RECT)
	ruta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mapa.add_child(ruta)
	ruta.draw.connect(_draw_daily_route.bind(ruta))

	var pie := Label.new()
	pie.text = "Toca el cofre para abrirlo"
	pie.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pie.offset_left = 44.0
	pie.offset_right = -44.0
	# Sitio FIJO para los dos textos (el de antes de abrir y el de después): si
	# el pie se moviera al cobrar, el cartel daría un salto justo cuando el
	# jugador está mirando el botín.
	pie.offset_top = -150.0
	pie.offset_bottom = -104.0
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pie.add_theme_font_size_override("font_size", 24)
	pie.add_theme_color_override("font_color", Color(0.42, 0.28, 0.14))
	panel.add_child(pie)

	for n in range(1, DailyData.day_count() + 1):
		var caja := Control.new()
		caja.size = DAILY_SPOT
		caja.position = (DAILY_ROUTE[n - 1] as Vector2) * DAILY_MAP \
				- DAILY_SPOT * 0.5
		# El pivote va en la BASE, no en el centro: así el cofre se mece como
		# algo apoyado en el suelo en vez de girar sobre su ombligo.
		caja.pivot_offset = Vector2(DAILY_SPOT.x * 0.5, DAILY_SPOT.y)
		caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mapa.add_child(caja)

		var cofre := TextureRect.new()
		cofre.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cofre.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cofre.set_anchors_preset(Control.PRESET_FULL_RECT)
		cofre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var estado := "mapa"
		if n < dia:
			estado = "mapa_abierto"
		elif n == dia:
			estado = "cerrado"
		cofre.texture = load(DAILY_CHEST_TEX[estado])
		caja.add_child(cofre)

		var num := Label.new()
		num.text = "%d" % n
		num.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		num.offset_top = -6.0
		num.offset_bottom = 30.0
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.add_theme_font_size_override("font_size", 22)
		num.add_theme_color_override("font_color", DAILY_INK)
		# Contorno CREMA: los números de abajo caen sobre la arena y el peñasco
		# que el pergamino trae dibujados, y en marrón sobre marrón no se leían.
		num.add_theme_color_override("font_outline_color", Color(0.98, 0.94, 0.84))
		num.add_theme_constant_override("outline_size", 6)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caja.add_child(num)

		if n != dia:
			continue
		# El cofre de HOY: se mece esperando y es lo único que se puede tocar.
		caja.mouse_filter = Control.MOUSE_FILTER_STOP
		var mecer := caja.create_tween().set_loops()
		mecer.tween_property(caja, "rotation", 0.10, 0.55) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		mecer.tween_property(caja, "rotation", -0.10, 0.55) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var hecho := { "on": false }
		caja.gui_input.connect(func(e: InputEvent) -> void:
			if not (e is InputEventScreenTouch and e.pressed) or hecho["on"]:
				return
			hecho["on"] = true
			mecer.kill()
			_open_daily_chest(velo, panel, caja, cofre, pie))

	velo.modulate.a = 0.0
	panel.scale = Vector2(0.7, 0.7)
	var tw := velo.create_tween()
	tw.tween_property(velo, "modulate:a", 1.0, 0.22)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.34) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## El cofre de hoy se abre: cobra el premio, cambia al cofre abierto con un
## bote, suelta unas monedas y saca el cartel del botín.
func _open_daily_chest(velo: Control, panel: Control, caja: Control,
		cofre: TextureRect, pie: Label) -> void:
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pie.text = ""
	# EL PREMIO SE COBRA CUANDO EL COFRE SE ABRE, no al tocarlo. Cobrando antes,
	# las cajas de la cabecera ya traían sumado el saco de arroz con el cofre
	# todavía cerrado: parecía que el nivel no había gastado su arroz y que el
	# bonus tampoco daba ninguno. El botín viaja en un DICCIONARIO porque las
	# lambdas de GDScript capturan por VALOR.
	var botin := {}

	var tw := caja.create_tween()
	tw.tween_property(caja, "rotation", 0.0, 0.10)
	tw.parallel().tween_property(caja, "scale", Vector2(1.28, 1.28), 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		cofre.texture = load(DAILY_CHEST_TEX["abierto"])
		botin["dado"] = GameState.claim_daily()
		_refresh_resources()
		_daily_coin_burst(caja))
	tw.tween_property(caja, "scale", Vector2.ONE, 0.26) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.18)
	tw.tween_callback(func() -> void:
		_show_daily_reward(botin.get("dado", {}), velo, panel, pie))


## Puñado de monedas saliendo del cofre al abrirlo.
func _daily_coin_burst(caja: Control) -> void:
	var moneda: Texture2D = load("res://assets/ui/moneda.png")
	for i in range(9):
		var m := TextureRect.new()
		m.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		m.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		m.texture = moneda
		m.size = Vector2(30, 30)
		m.position = Vector2(DAILY_SPOT.x * 0.5 - 15.0, 22.0)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caja.add_child(m)
		var lado := (float(i) / 8.0 - 0.5) * 120.0
		var alto := -70.0 - randf() * 46.0
		var t := m.create_tween()
		t.tween_property(m, "position", m.position + Vector2(lado, alto), 0.34) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(m, "position", m.position + Vector2(lado * 1.35, 40.0),
				0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(m, "modulate:a", 0.0, 0.42)
		t.tween_callback(m.queue_free)


## Segundo cartel: TODO lo que ha soltado el cofre, en fichas de icono + cifra.
func _show_daily_reward(dado: Dictionary, velo: Control, panel: Control,
		pie: Label) -> void:
	var fichas: Array[Control] = []
	for clave in ["money", "rice", "ingots", "extras"]:
		if not dado.has(clave):
			continue
		fichas.append(_daily_chip(load(DAILY_ICONS[clave]),
			"x%d" % int(dado[clave])))
	for k in dado.get("ingredients", {}):
		fichas.append(_daily_chip(RecipeData.get_ingredient_texture(str(k)),
			"x%d" % int(dado["ingredients"][k])))
	if dado.has("recipe"):
		fichas.append(_daily_chip(RecipeData.get_dish_texture(str(dado["recipe"])),
			str(RecipeData.get_recipe(str(dado["recipe"])).get("name", ""))))

	# El cartel CRECE con lo que haya caído: el día 3 son dos fichas y el 7 son
	# siete. Con alto fijo, los días flojos salían con medio pergamino vacío.
	var filas: int = maxi(1, ceili(float(fichas.size()) / DAILY_CHIPS_ROW))
	var alto := 96.0 + filas * DAILY_ROW_H + 112.0
	var caja := Control.new()
	caja.set_anchors_preset(Control.PRESET_CENTER)
	caja.offset_left = -DAILY_REWARD_W * 0.5
	caja.offset_top = -alto * 0.5
	caja.offset_right = DAILY_REWARD_W * 0.5
	caja.offset_bottom = alto * 0.5
	caja.pivot_offset = Vector2(DAILY_REWARD_W * 0.5, alto * 0.5)
	caja.mouse_filter = Control.MOUSE_FILTER_STOP
	velo.add_child(caja)
	caja.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX,
		PrepBoard.PANEL_MARGIN))
	var dia := int(dado.get("day", 1))
	PrepBoard.add_panel_banner(caja, "¡Día %d seguido!" % dia, 32, 20.0)

	# El mapa se queda atenuado detrás mientras se lee el botín: sin esto los
	# dos pergaminos pesan igual y no se sabe cuál manda.
	panel.modulate = Color(0.5, 0.5, 0.5)

	# HFlowContainer y no HBox: el día 7 suelta SIETE fichas y en una sola fila
	# se salen del pergamino.
	var fila := HFlowContainer.new()
	fila.alignment = FlowContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("h_separation", 10)
	fila.add_theme_constant_override("v_separation", 6)
	fila.set_anchors_preset(Control.PRESET_FULL_RECT)
	fila.offset_left = 46.0
	fila.offset_right = -46.0
	fila.offset_top = 92.0
	fila.offset_bottom = -108.0
	caja.add_child(fila)
	for f in fichas:
		fila.add_child(f)

	var seguir := Button.new()
	seguir.text = "¡Genial!"
	seguir.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	seguir.offset_left = 150.0
	seguir.offset_right = -150.0
	seguir.offset_top = -92.0
	seguir.offset_bottom = -26.0
	PrepBoard.skin_button(seguir)
	seguir.add_theme_font_size_override("font_size", 30)
	caja.add_child(seguir)

	caja.scale = Vector2(0.6, 0.6)
	caja.modulate.a = 0.0
	var tw := caja.create_tween()
	tw.tween_property(caja, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(caja, "modulate:a", 1.0, 0.2)
	for f in fichas:
		f.pivot_offset = Vector2(DAILY_CHIP * 0.5, 60)
		f.scale = Vector2(0.4, 0.4)
		f.modulate.a = 0.0
		tw.tween_property(f, "modulate:a", 1.0, 0.12)
		tw.parallel().tween_property(f, "scale", Vector2.ONE, 0.26) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	seguir.pressed.connect(func() -> void:
		var out := caja.create_tween().set_parallel(true)
		out.tween_property(caja, "scale", Vector2(0.72, 0.72), 0.2) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		out.tween_property(caja, "modulate:a", 0.0, 0.2)
		# Al cerrar el botín se vuelve al mapa, con el cofre de hoy ya abierto:
		# es la foto que se lleva el jugador de por dónde va la racha.
		out.chain().tween_callback(caja.queue_free)
		out.chain().tween_callback(func() -> void: _daily_done(velo, panel, pie)))


## Cerrado el botín: el mapa se queda con el cofre abierto y aparece el botón
## de salir, que hasta ahora no existía a propósito.
func _daily_done(velo: Control, panel: Control, pie: Label) -> void:
	panel.modulate = Color.WHITE
	var ultimo := GameState.daily_day >= DailyData.day_count()
	pie.text = "¡Racha completa! Mañana vuelve a empezar." if ultimo \
			else "¡Vuelve mañana para seguir la racha!"

	var salir := Button.new()
	salir.text = "Continuar"
	salir.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	salir.offset_left = 170.0
	salir.offset_right = -170.0
	salir.offset_top = -92.0
	salir.offset_bottom = -26.0
	PrepBoard.skin_button(salir)
	salir.add_theme_font_size_override("font_size", 30)
	panel.add_child(salir)
	salir.modulate.a = 0.0
	salir.create_tween().tween_property(salir, "modulate:a", 1.0, 0.24)

	salir.pressed.connect(func() -> void:
		salir.disabled = true
		var out := velo.create_tween().set_parallel(true)
		out.tween_property(panel, "scale", Vector2(0.76, 0.76), 0.22) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		out.tween_property(velo, "modulate:a", 0.0, 0.24)
		out.chain().tween_callback(velo.queue_free))


## Una ficha del cartel diario: dibujo arriba y cantidad debajo.
func _daily_chip(tex: Texture2D, texto: String) -> Control:
	var caja := VBoxContainer.new()
	caja.custom_minimum_size = Vector2(DAILY_CHIP, 0)
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = tex
	ic.custom_minimum_size = Vector2(DAILY_CHIP - 8, 96)
	caja.add_child(ic)
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.26, 0.16, 0.08))
	caja.add_child(l)
	return caja


## RECETAS NUEVAS: al volver de un nivel (o del tutorial) el menú las anuncia
## con un pergamino en el que cada plato entra dando un bote, uno detrás de
## otro. Se cierra tocando la pantalla.
func _show_reveal(ids: Array) -> void:
	if ids.is_empty():
		return
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -318.0
	panel.offset_top = -250.0
	panel.offset_right = 318.0
	panel.offset_bottom = 250.0
	panel.pivot_offset = Vector2(318.0, 250.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(panel)
	panel.add_child(PrepBoard.make_nine_patch(PrepBoard.PANEL_TEX, PrepBoard.PANEL_MARGIN))

	var titulo := Label.new()
	titulo.text = "¡Recetas nuevas!" if ids.size() > 1 else "¡Receta nueva!"
	titulo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	titulo.offset_top = 56.0
	titulo.offset_bottom = 106.0
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 32)
	titulo.add_theme_color_override("font_color", Color(0.26, 0.16, 0.08))
	panel.add_child(titulo)

	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 14)
	fila.set_anchors_preset(Control.PRESET_FULL_RECT)
	fila.offset_left = 56.0
	fila.offset_right = -56.0
	fila.offset_top = 116.0
	fila.offset_bottom = -128.0
	panel.add_child(fila)

	var fichas: Array[Control] = []
	for id in ids:
		var caja := VBoxContainer.new()
		caja.custom_minimum_size = Vector2(126, 0)
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = RecipeData.get_dish_texture(str(id))
		ic.custom_minimum_size = Vector2(120, 120)
		caja.add_child(ic)
		var l := Label.new()
		l.text = str(RecipeData.get_recipe(str(id)).get("name", id))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", Color(0.26, 0.16, 0.08))
		caja.add_child(l)
		caja.modulate.a = 0.0
		fila.add_child(caja)
		fichas.append(caja)

	# CON UNA SOLA RECETA, el pie cuenta QUÉ HACE (deducido de sus datos, ver
	# `RecipeData.summary`): es el momento en que el jugador la ve por primera
	# vez y mandarlo al recetario a averiguarlo no tenía sentido. Con varias no
	# cabe una descripción por plato, así que se queda el aviso de la despensa.
	var resumen := RecipeData.summary(str(ids[0])) if ids.size() == 1 else ""
	var pie := RichTextLabel.new()
	pie.bbcode_enabled = true
	pie.scroll_active = false
	pie.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pie.text = "[center]%s[/center]" % (DialogueBox.format_keywords(resumen)
			if resumen != ""
			else "Ya tienes ingredientes en la despensa para estrenarlas.")
	pie.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pie.offset_left = 44.0
	pie.offset_right = -44.0
	pie.offset_top = -140.0
	pie.offset_bottom = -34.0
	pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pie.add_theme_font_size_override("normal_font_size", 20)
	pie.add_theme_font_size_override("bold_font_size", 20)
	pie.add_theme_color_override("default_color", Color(0.42, 0.28, 0.14))
	panel.add_child(pie)

	panel.scale = Vector2(0.6, 0.6)
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(panel, "modulate:a", 1.0, 0.2)
	# Los platos van entrando de uno en uno, con su bote.
	for f in fichas:
		f.pivot_offset = Vector2(63, 70)
		f.scale = Vector2(0.4, 0.4)
		tw.tween_property(f, "modulate:a", 1.0, 0.14)
		tw.parallel().tween_property(f, "scale", Vector2.ONE, 0.28) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Al tocarlo se cierra con su animación (encoge y se desvanece), no de golpe.
	var cerrando := { "on": false }
	panel.gui_input.connect(func(e: InputEvent) -> void:
		if not (e is InputEventScreenTouch and e.pressed) or cerrando["on"]:
			return
		cerrando["on"] = true
		var out := panel.create_tween().set_parallel(true)
		out.tween_property(panel, "scale", Vector2(0.72, 0.72), 0.22) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		out.tween_property(panel, "modulate:a", 0.0, 0.22)
		out.chain().tween_callback(panel.queue_free))


## TIENDA: entra un puerto por la derecha, el barco navega hasta él con la
## CÁMARA DETRÁS, atraca, zoom sobre el atraque y a negro.
func _go_shop() -> void:
	if leaving:
		return
	if not GameState.shop_unlocked():
		_show_locked_notice("La tienda abre cuando superes
el nivel 2 de la Aventura.")
		return
	leaving = true
	# Los contadores NO salen: se quedan y viajan a los extremos del mapa.
	_ui_out(false)
	_sky_out(0.9)

	var here := _world(ship_px)
	var dock := SceneBackdrop._spawn_model(self,
		load("res://assets/models/map_puerto.glb"), 7.0)
	dock.position = here + R_HAT * 20.0 + Vector3(0.0, -0.1, 0.0)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(dock, "position", here + R_HAT * SHOP_DOCK_AT
		+ Vector3(0, -0.1, 0), 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "ship_px", ship_px + Vector2(SHOP_SAIL, 0.0), 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# La cámara ACOMPAÑA al barco mientras se acerca al muelle: quieta, el barco
	# se salía del encuadre y el zoom caía sobre mar vacío.
	tw.tween_property(self, "cam_side", SHOP_SAIL, 1.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# El zoom cierra sobre el atraque: entre el barco y el puesto del tendero.
	tw.chain().tween_property(cam, "size", SHOP_ZOOM_SIZE, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "cam_side", SHOP_ZOOM_SIDE, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_interval(0.15)
	tw.chain().tween_callback(func() -> void:
		GameState.transition = "tienda"
		GameState.fade_to_scene("res://scenes/shop_screen.tscn", 0.45, 0.5))


## LOGROS y OPCIONES: la interfaz se retira y se funde a negro. No traen
## coreografía propia (no son un sitio al que se navegue por mar).
func _go_achievements() -> void:
	_leave_to("res://scenes/achievements_screen.tscn")


func _go_options() -> void:
	_leave_to("res://scenes/options_screen.tscn")


func _go_profile() -> void:
	_leave_to("res://scenes/profile_screen.tscn")


func _go_perks() -> void:
	_leave_to("res://scenes/perks_screen.tscn")


func _go_skills() -> void:
	_leave_to("res://scenes/skills_screen.tscn")


func _leave_to(path: String) -> void:
	if leaving:
		return
	leaving = true
	_ui_out()
	var tw := create_tween()
	tw.tween_interval(OUT_TIME * 0.6)
	tw.tween_callback(func() -> void:
		GameState.fade_to_scene(path, 0.4, 0.4))


## INVENTARIO: la interfaz se retira y la pantalla se apaga.
func _go_inventory() -> void:
	if leaving:
		return
	leaving = true
	_ui_out()
	var tw := create_tween()
	tw.tween_interval(OUT_TIME * 0.6)
	tw.tween_callback(func() -> void:
		GameState.transition = "inventario"
		GameState.fade_to_scene("res://scenes/inventory_screen.tscn", 0.45, 0.4))


## Devuelve el logotipo, los botones y el monedero a su sitio.
## `con_recursos` a false deja quietos los contadores: al volver del mapa los
## mueve `_place_resources`, y si los tocan los dos pelean por `position`.
func _ui_in(con_recursos := true, con_nivel := true) -> void:
	if ui_tween != null and ui_tween.is_valid():
		ui_tween.kill()
	# `_ui_out` los deja ocultos al terminar de bajarlos (ahí se explica por qué).
	menu_panel.visible = true
	submenu_bar.visible = true
	menu_panel.position.y = home_box_y + 660.0
	submenu_bar.position.y = home_sub_y + 260.0
	if con_recursos:
		for caja in [ingot_box, money_box, rice_box]:
			if caja != null:
				caja.position.y = res_y - 220.0
	ui_tween = create_tween().set_parallel(true)
	ui_tween.tween_property(submenu_bar, "position:y", home_sub_y, 0.55) \
			.set_delay(0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ui_tween.tween_property(menu_panel, "position:y", home_box_y, 0.6) 			.set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if con_recursos:
		for caja in [ingot_box, money_box, rice_box]:
			if caja != null:
				ui_tween.tween_property(caja, "position:y", res_y, 0.55) 						.set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


	# La barra de nivel vuelve con el resto y, ya en su sitio, anima la
	# experiencia que traiga pendiente (con su fogonazo por cada subida).
	if con_nivel and level_bar != null:
		_refresh_level_bar()
		if level_bar.visible:
			level_bar.position.y = home_lvl_y - 220.0
			ui_tween.tween_property(level_bar, "position:y", home_lvl_y, 0.55) \
					.set_delay(0.22).set_trans(Tween.TRANS_BACK) \
					.set_ease(Tween.EASE_OUT)
			ui_tween.chain().tween_callback(_play_xp_anim_if_pending)


## Entrada del menú viniendo de otra pantalla: el barco llega navegando desde
## la IZQUIERDA hasta su fondeadero y la interfaz baja detrás.
func _play_menu_intro() -> void:
	_set_menu_ui_visible(true)
	_sky_in()
	ship_px = MENU_ANCHOR - Vector2(OFFSCREEN, 0.0)
	create_tween().tween_property(self, "ship_px", MENU_ANCHOR, 0.95) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ui_in()
