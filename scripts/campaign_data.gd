class_name CampaignData
## Datos estáticos de la campaña (modo Aventura): lista ORDENADA de niveles.
##
## LA CAMPAÑA ES TAMBIÉN EL TUTORIAL. Los 10 primeros niveles presentan las
## mecánicas de una en una, jugando (el "tutorial" clásico se redujo a una
## escena de rescate: ver tutorial_director.gd). El reparto:
##   n1  paciencia, bocado y oro — jornada NORMAL con maki + nigiri de salmón
##   n2  las CAJAS de guardado (y desde aquí la despensa SE GASTA)
##   n3  el PICOTEO: regalo del edamame
##   n4  MULTIPLICADOR, hastío y paladar (regalo del té verde);
##       superarlo abre la TIENDA y lleva al jugador allí
##   n5  POSTRES (regalo del mochi) y, con ellos, PROPINAS y potenciadores
##   n6  los EXTRAS (jengibre, wasabi, soja)
##   n7  primer ABORDAJE (reloj y clientela sin fin) y primeros PIRATAS y
##       CAPITANES: regalo del nigiri de atún
##   n8  Pablo el Rubio (cliente especial + salmón tsuke don y el CORTE LENTO)
##   n9  consolidación sin guion: el puerto más bravo hasta la fecha
##   n10 JEFE: el Kappa (ver el bloque del jefe en level_director/client3d)
##
## LOS SEIS PRIMEROS NIVELES SON TODOS DE GRUMETES a propósito: se aprende a
## cocinar antes de aprender a leer paladares. Piratas y capitanes entran en el
## 7, que es también el primer abordaje.
##
## Los BONIFICADORES permanentes (PerkData) no se reparten hasta el nivel 8
## (`no_perks`); los POTENCIADORES de partida y las propinas se estrenan en el 5.
##
## Lo que no cabe aquí (barco combinado, la mayor parte de la carta) queda para
## los niveles 11+ — la campaña larga prevé jefes cada 10 niveles, y este es el
## primero.
##
## Cada nivel es una partida corta. La puntuación es POR DINERO generado:
## "star_money" = [1★, 2★, 3★] doblones mínimos. Superar el nivel (alcanzar
## "goal_stars") desbloquea el siguiente y concede sus recompensas la 1ª vez.
##
## Campos de cada nivel:
##  - id, name, desc: identificación y texto para la pantalla de niveles.
##  - client_mix: en ISLAS y PUERTOS, el recuento EXACTO de clientes {E,A,G}
##    (E grumete, A pirata, G capitán): el nivel construye una cola barajada con
##    exactamente esos clientes y total_clients sale de la suma. En los
##    ABORDAJES no hay tope de clientes, así que la mezcla es solo la PRIMERA
##    tanda (en el orden que fije `late_type`) y, agotada, las llegadas siguen
##    sorteándose con esas mismas proporciones hasta que se acabe el reloj.
##  - arrival_span: ventana en segundos sobre la que se reparten las llegadas.
##    NO es la duración del nivel (ver más abajo): solo marca el RITMO al que
##    entra la clientela, y por eso lo llevan también los niveles sin reloj.
##  - patience_mult: multiplicador de paciencia (<1 = más difícil).
##  - arrival_scale: comprime el horario de llegadas (<1 = vienen más rápido).
##  - goal_stars: estrellas mínimas para superar el nivel y avanzar.
##  - star_money: [dinero para 1★, 2★, 3★] — SOLO precio de platos (sin propinas),
##    calibrado al techo de producción de cada nivel.
##    CADA TIPO DE NIVEL SE CALIBRA CONTRA LO QUE DE VERDAD LO LIMITA, y son
##    cosas distintas:
##     · Los ABORDAJES los limita el RELOJ (siempre hay a quien servir), así que
##       su techo es 150 s × los doblones por segundo de atención que rinde la
##       carta que se puede llevar.
##     · Las ISLAS y los PUERTOS los limita la CLIENTELA (cupo cerrado): su
##       techo es clientes × platos por cliente × PRECIO medio de la carta. Al
##       tocar precios, se reescalan por el cambio de precio medio, NO de $/s —
##       con el $/s salían cifras imposibles (el antiguo nivel 2 pedía 127
##       doblones con un techo real de ~75).
##    En los dos casos 1★/2★ quedan al ~35% y al ~62% del 3★. Y en estos 10
##    niveles-escuela las cifras van BAJAS a propósito (el usuario lo pidió
##    así): aquí se aprende; la exigencia llega con la campaña larga.
##  - fixed_recipes: carta CERRADA (las islas). El jugador no elige: se juega
##    con esas recetas y punto, también al repetir el puerto.
##    `fixed_recipes_replay` es la lista para cuando ya está superado (entran
##    los regalos de David de la primera pasada).
##    `optional_recipes` se SUMAN a la carta cerrada si el jugador las tiene
##    desbloqueadas (el gunkan de wakame del nivel 2: es premio de 3 estrellas
##    del 1, así que puede tenerlo o no).
##    `alt_recipes` es una lista por PREFERENCIA de la que entra SOLO LA
##    PRIMERA que esté desbloqueada (en el 3: el maki de pepino si lo tiene y,
##    si no, el gunkan de wakame). Así la carta cerrada mantiene su tamaño
##    tenga el jugador lo que tenga.
##  - free_ingredients: este puerto NO gasta usos de despensa (solo el nivel 1,
##    que es la jornada de práctica; el ARROZ sí se gasta desde el primer día).
##  - no_powerups: sin bote de propinas ni potenciadores de partida (el HUD
##    esconde el bote y las propinas no se acumulan). Niveles 1-4: el bote se
##    estrena en el 5, con los postres.
##  - no_perks: este puerto no reparte BONIFICADORES permanentes aunque se
##    cumpla su combo. Niveles 1-7: se estrenan en el 8.
##  - near_seats: la clientela ocupa las sillas por orden de CINTA en vez de al
##    azar (la escuela: con cuatro clientes sueltos, uno sentado justo detrás
##    del punto de salida se comería una vuelta entera de espera).
##  - arrival_batch: cuántos clientes entran DE GOLPE en cada llegada (el 4 va
##    de dos en dos y el 6 en dos tandas de cuatro).
##  - no_storage: sin cajas de guardado (solo el nivel 1: se enseñan en el 2).
##  - boss: id del JEFE del nivel ("kappa"). El guion lo trae cuando la primera
##    tanda ha comido y el nivel no se supera sin cumplir su condición (ver
##    level3d._finalize_results).
##  - reward_recipes: recetas que se desbloquean al SUPERARLO (goal_stars, que
##    son 2 estrellas: con 2★ el puerto queda pasado y se abre el siguiente).
##  - reward_recipes_3 / reward_ingots_3 / reward_rice_3: el premio GORDO, solo
##    al sacar las 3 estrellas; se puede volver a por él con mejor carta.
##    Estos 10 niveles NO cubren la carta entera a propósito: el jugador
##    aprende ~la mitad de las recetas y el resto (más el barco combinado y
##    los bonificadores) queda para los niveles futuros. El DRAGON ROLL sigue
##    siendo exclusivo del día 7 del bonus diario.
##
## CÓMO TERMINA UN NIVEL (depende del TIPO, ver KINDS):
##  - "abordaje": es el único que lleva RELOJ, y son SHIP_TIME (2:30) para
##    todos. No hay tope de clientes: entran mientras quede tiempo. Acaba al
##    agotarse el reloj o al llegar al oro objetivo. (En el nivel del JEFE el
##    guion para el reloj cuando el jefe entra: manda su paciencia.)
##  - "isla" y "puerto": SIN reloj. Lo que los acota es la CLIENTELA: acaban
##    cuando se ha ido el último cliente de `client_mix` o al llegar al oro
##    objetivo. Su HUD no enseña contador de tiempo.

## Duración de los niveles de ABORDAJE, los únicos con reloj.
const SHIP_TIME := 150.0

## Con lo que arranca una partida nueva. El tutorial (la escena del rescate)
## entrega SOLO el maki de aguacate: el resto de la carta se gana nivel a nivel
## (el nigiri lo regala David en el 1, el té y el mochi en el 2...).
const INITIAL_RECIPES: Array = ["maki_aguacate"]
## Usos de ingredientes iniciales: NINGUNO a mano. La despensa la reparte
## `GameState.complete_tutorial`, que da `TUTORIAL_GIFT` (10) usos de todo lo
## que piden las recetas de inicio — la misma regla que cualquier receta que
## regale David después. Poner cifras aquí sumaba encima de ese regalo.
const INITIAL_INGREDIENTS: Dictionary = {}

const PORTS: Array = [
	{
		"id": "nivel_1",
		"name": "Cala Tortuga",
		"desc": "Tu primer turno de verdad: cuatro grumetes y dos recetas sencillas.",
		"client_mix": { "E": 4 },
		# Medido: con 110 el cuarto grumete no entraba hasta el segundo 88 y el
		# nivel se iba a tres minutos con un solo cliente en la barra casi todo
		# el rato. Con 75, las llegadas caen en 5 · 21 · 37 · 53 s.
		"arrival_span": 75.0,
		# Paciencia generosa: el primer cliente es la pizarra de David (paciencia,
		# bocado y oro se explican sobre él).
		"patience_mult": 1.15,
		"arrival_scale": 1.0,
		"goal_stars": 2,
		# Umbrales del usuario: 10 · 25 · 40 doblones.
		"star_money": [10, 25, 40],
		"reward_recipes": [],
		"reward_recipes_3": ["gunkan_wakame"],
		# UNA JORNADA CORRIENTE: el nigiri de salmón está en la carta DESDE EL
		# PRIMER FOTOGRAMA, tanto en el estreno como al repetir el nivel desde el
		# mapa o desde el botón "Repetir" del cartel de resultados. David solo lo
		# presenta; ya no hay que esperar a que lo saque a media partida.
		"fixed_recipes": ["maki_aguacate", "nigiri_salmon"],
		"gift_recipes": ["nigiri_salmon"],
		# Única jornada que no gasta DESPENSA (el arroz sí: es la energía y hay
		# que verla bajar desde el primer día).
		"free_ingredients": true,
		"no_powerups": true,
		# Las cajas son la lección del nivel 2: aquí ni aparecen.
		"no_storage": true,
		"no_extras": true,
		# Chapas de multiplicador: se explican en el 4.
		"no_variety_ui": true,
		"no_perks": true,
		# Sin botón de Salir en el ESTRENO (de la primera jornada no se huye);
		# a partir del segundo intento sale como en cualquier otro nivel, y de
		# eso se encarga level3d mirando si el puerto ya se ha jugado.
		"no_exit": true,
		# Cuatro clientes en las sillas que la cinta alcanza antes.
		"near_seats": true,
		"director": "nivel_1",
	},
	{
		"id": "nivel_2",
		"name": "Playa del Coco",
		"desc": "Se junta la clientela: hoy aprendes a guardar platos en las cajas.",
		"client_mix": { "E": 4 },
		"arrival_span": 120.0,
		"patience_mult": 1.1,
		"arrival_scale": 0.9,
		"goal_stars": 2,
		"star_money": [14, 26, 40],
		"reward_recipes": [],
		"reward_recipes_3": ["maki_pepino"],
		# El primero entra solo; el guion trae a los otros TRES DE GOLPE cuando
		# se ha comido su segundo plato (ver level_director._nivel_2), que es lo
		# que justifica las cajas.
		"fixed_recipes": ["maki_aguacate", "nigiri_salmon"],
		# El gunkan es premio de 3 estrellas del nivel 1: entra en la carta solo
		# si el jugador se lo ganó.
		"optional_recipes": ["gunkan_wakame"],
		"no_powerups": true,
		"no_extras": true,
		"no_variety_ui": true,
		"no_perks": true,
		"near_seats": true,
		# Las cajas aparecen A MEDIA PARTIDA, con la lección. NO va aquí sino en
		# el guion (`level_director._nivel_2` las esconde al arrancar): así, al
		# repetir el nivel —donde el guion ya no corre— salen desde el principio.
		"director": "nivel_2",
	},
	{
		"id": "nivel_3",
		"name": "Isla del Bambú",
		"desc": "Cinco grumetes hambrientos y un plato que se come sin soltar el otro.",
		"client_mix": { "E": 5 },
		"arrival_span": 120.0,
		"patience_mult": 1.05,
		"arrival_scale": 0.85,
		"goal_stars": 2,
		"star_money": [18, 32, 50],
		"reward_recipes": [],
		"reward_recipes_3": ["sunomono"],
		# TRES recetas de carta: la cuarta la trae David al empezar (el edamame,
		# con la lección del picoteo).
		"fixed_recipes": ["maki_aguacate", "nigiri_salmon"],
		# La tercera sale de lo que el jugador se haya ganado, por preferencia.
		"alt_recipes": ["maki_pepino", "gunkan_wakame"],
		"gift_recipes": ["edamame"],
		"no_powerups": true,
		"no_extras": true,
		"no_variety_ui": true,
		"no_perks": true,
		"near_seats": true,
		"director": "nivel_3",
	},
	{
		"id": "nivel_4",
		"name": "Arrecife del Ron",
		"desc": "Ocho bocas de dos en dos. Y corre la voz de que hay tienda en el puerto.",
		"client_mix": { "E": 8 },
		"arrival_span": 140.0,
		"patience_mult": 1.0,
		"arrival_scale": 0.8,
		# De dos en dos: es lo que obliga a variar en vez de repetir el mismo
		# plato, que es la lección del nivel.
		"arrival_batch": 2,
		"goal_stars": 2,
		"star_money": [26, 46, 72],
		"reward_recipes": [],
		"reward_recipes_3": ["onigiri"],
		# Primer PUERTO: carta libre, pero solo TRES huecos.
		"recipe_slots": 3,
		# Primer paso por el selector: David lo explica antes de zarpar.
		"prep_dialog": "nivel_4",
		"gift_recipes": ["te_verde"],
		# Superarlo abre la TIENDA, y el guion lleva al jugador allí de la mano.
		"unlocks_shop": true,
		"director": "nivel_4",
		"no_powerups": true,
		"no_extras": true,
		"no_perks": true,
	},
	{
		"id": "nivel_5",
		"name": "Cala del Calamar",
		"desc": "El postre es la cuenta: aprende a despedir clientes y a llenar el bote.",
		"client_mix": { "E": 5 },
		"arrival_span": 120.0,
		"patience_mult": 1.0,
		"arrival_scale": 0.85,
		"goal_stars": 2,
		"star_money": [20, 38, 58],
		"reward_recipes": [],
		"reward_recipes_3": ["caldo_dashi"],
		# Isla: carta cerrada con lo aprendido. El mochi lo regala David dentro.
		"fixed_recipes": ["maki_aguacate", "nigiri_salmon", "te_verde"],
		"gift_recipes": ["mochi"],
		# PRIMER NIVEL CON BOTE DE PROPINAS: aquí se estrenan los potenciadores
		# de partida. Y superarlo abre la PESCA del menú.
		"unlocks_fishing": true,
		"director": "nivel_5",
		"no_extras": true,
		"no_perks": true,
	},
	{
		"id": "nivel_6",
		"name": "Bahía del Kraken",
		"desc": "Saverio saca los extras: jengibre, wasabi y soja sobre el plato hecho.",
		"client_mix": { "E": 8 },
		# Con solo DOS tandas la ventana se reparte entre ellas, así que un
		# `arrival_span` largo dejaba un desierto en medio: con 90, las dos
		# oleadas caen a los 5 y a los 54 s.
		"arrival_span": 90.0,
		"patience_mult": 0.95,
		"arrival_scale": 0.8,
		# Dos tandas de cuatro: la barra se llena de golpe dos veces.
		"arrival_batch": 4,
		"goal_stars": 2,
		"star_money": [28, 52, 82],
		"reward_recipes": [],
		"reward_recipes_3": ["sopa_miso"],
		"director": "nivel_6",
		"no_perks": true,
	},
	{
		"id": "nivel_7",
		"name": "Estrecho del Rayo",
		"desc": "¡Abordaje! Reloj, clientela sin fin y paladares que no son de grumete.",
		"client_mix": { "E": 3, "A": 2, "G": 1 },
		"arrival_span": 100.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.8,
		"goal_stars": 2,
		# Primer abordaje: 150 s con carta media ~$5 → techo ~90.
		"star_money": [32, 55, 88],
		"reward_recipes": ["sashimi_atun_rojo"],
		"reward_recipes_3": ["nigiri_ebi"],
		# Primeros PIRATAS y CAPITANES del juego: David presenta los paladares y
		# regala una receta de 2 estrellas para estrenarla con el pirata.
		"gift_recipes": ["nigiri_atun"],
		"late_type": "A",
		"reward_rice_3": 2,
		"director": "nivel_7",
		"no_perks": true,
	},
	{
		"id": "nivel_8",
		"name": "Flota del capitán Pablo el Rubio",
		"desc": "Abordaje a la flota de un viejo conocido de David.",
		"client_mix": { "E": 2, "A": 2, "G": 1 },
		"arrival_span": 120.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.7,
		"goal_stars": 2,
		"star_money": [36, 62, 95],
		"boat": true,
		# Carta LIBRE, pero solo tres huecos LA PRIMERA VEZ: al repetir el
		# puerto se juega con los cuatro de siempre (ver prep_screen).
		"recipe_slots": 3,
		# El capitán del nivel es Pablo el Rubio: mismo comportamiento que un
		# capitán normal, pero con su propio modelo (ver CharacterData).
		"special_client": { "who": "pablo", "type": "G" },
		# Pablo entra el ÚLTIMO; si el jugador va sobrado, el guion lo adelanta.
		"late_type": "G",
		"director": "nivel_8",
		# David avisa en el selector de recetas antes de zarpar.
		"prep_dialog": "nivel_8",
		"gift_recipes": ["salmon_tsuke_don"],
		# Mientras corre el guion, el tsuke don es SOLO para Pablo (es su
		# regalo); al repetir el puerto ya se le puede servir a cualquiera.
		"exclusive_dishes": { "salmon_tsuke_don": "pablo" },
		"reward_recipes": [],
		"reward_recipes_3": ["aburi"],
		"reward_ingots_3": 2,
	},
	{
		"id": "nivel_9",
		"name": "Puerto Tormenta",
		"desc": "El puerto más bravo del mar: once bocas sin tregua.",
		"client_mix": { "E": 6, "A": 3, "G": 2 },
		"arrival_span": 150.0,
		"patience_mult": 0.85,
		"arrival_scale": 0.65,
		"goal_stars": 2,
		# SIN GUION a propósito: el examen de todo lo aprendido antes del jefe.
		"star_money": [40, 68, 105],
		"boat": true,
		"reward_recipes": ["udon"],
		"reward_recipes_3": ["taiyaki"],
		"reward_rice_3": 2,
	},
	{
		"id": "nivel_10",
		"name": "Guarida del Kappa",
		"desc": "Algo enorme y hambriento ronda estas aguas...",
		"client_mix": { "E": 3, "A": 2, "G": 1 },
		"arrival_span": 90.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.8,
		"goal_stars": 2,
		# JEFE: superar el nivel exige que el Kappa coma BOSS_PLATES platos (ver
		# level_director._nivel_10). El dinero solo decide la 3ª estrella.
		"star_money": [30, 55, 90],
		"boss": "kappa",
		"boat": true,
		"director": "nivel_10",
		"prep_dialog": "nivel_10",
		"reward_recipes": ["tempura"],
		"reward_recipes_3": ["temaki"],
		"reward_ingots_3": 2,
	},
]


# --- Mapa marítimo (pantalla de selección de nivel) -------------------------
#
# El selector es un mar por el que navega el barco del jugador entre nodos.
# Cada nivel es de un TIPO: "isla", "puerto" o "abordaje" (asaltar otro barco).
# De momento el tipo es solo identidad visual; más adelante cada tipo dará una
# característica única al nivel (añadir tipos nuevos = ampliar estos diccionarios).

const KINDS: Dictionary = {
	"nivel_1": "isla",
	"nivel_2": "isla",
	"nivel_3": "isla",
	"nivel_4": "puerto",
	"nivel_5": "isla",
	"nivel_6": "puerto",
	"nivel_7": "abordaje",
	"nivel_8": "abordaje",
	"nivel_9": "puerto",
	"nivel_10": "abordaje",
}

const KIND_NAMES: Dictionary = {
	"isla": "Isla",
	"puerto": "Puerto",
	"abordaje": "Abordaje",
}

const KIND_TEXTURES: Dictionary = {
	"isla": "res://assets/map/isla.png",
	"puerto": "res://assets/map/puerto.png",
	"abordaje": "res://assets/map/barco_enemigo.png",
}

## Alto del lienzo del mapa (el ancho es el de la pantalla).
##
## La travesía va de ABAJO ARRIBA: el nivel 1 es el más bajo y el último el más
## alto, así que el barco avanza hacia el norte a medida que progresas. Los
## nodos alternan entre TRES carriles (izquierda, centro y derecha) para que la
## ruta serpentee y no caiga siempre en el mismo lado.
## AL PASAR DE 9 A 10 NIVELES el lienzo creció un MAP_STEP (2180 → 2395) y toda
## la ruta se corrió +215 hacia abajo, con el nivel 10 estrenando lo alto; el
## fondeadero del menú (`main_menu.MENU_ANCHOR`) bajó otro tanto, o el nivel 1
## asomaba por arriba estando en el menú.
const MAP_HEIGHT := 2395

const LANE_LEFT := 175.0
const LANE_CENTER := 360.0
const LANE_RIGHT := 545.0

## Separación vertical entre puertos, IGUAL para todos. La medida no es a ojo:
## `level_select3d._setup_route` dibuja un guión cada 0.44 unidades de mundo, y
## el tramo más corto (un salto de carril, 185 px en horizontal) tiene que dar
## al menos 8. Con 215 px salen 10 en el corto y 13 en el largo.
## Si se cambia este paso hay que bajar `main_menu.MENU_ANCHOR` otro tanto, o el
## nivel 1 asoma por arriba estando en el menú.
const MAP_STEP := 215.0

const MAP_POS: Dictionary = {
	"nivel_1": Vector2(LANE_CENTER, 2145.0),
	"nivel_2": Vector2(LANE_LEFT, 1930.0),
	"nivel_3": Vector2(LANE_RIGHT, 1715.0),
	"nivel_4": Vector2(LANE_CENTER, 1500.0),
	"nivel_5": Vector2(LANE_LEFT, 1285.0),
	"nivel_6": Vector2(LANE_RIGHT, 1070.0),
	"nivel_7": Vector2(LANE_CENTER, 855.0),
	"nivel_8": Vector2(LANE_LEFT, 640.0),
	"nivel_9": Vector2(LANE_RIGHT, 425.0),
	"nivel_10": Vector2(LANE_CENTER, 210.0),
}


## Tipo de nivel ("isla", "puerto", "abordaje").
static func get_kind(id: String) -> String:
	return KINDS.get(id, "isla")


## ¿Este nivel se juega CONTRA RELOJ? Solo los abordajes: las islas y los
## puertos los acota la clientela, no el tiempo.
static func is_timed(id: String) -> bool:
	return get_kind(id) == "abordaje"


## Segundos de partida (0 = sin reloj: manda la clientela).
static func time_limit_for(id: String) -> float:
	return SHIP_TIME if is_timed(id) else 0.0


## ¿Entran clientes sin tope? Los abordajes no tienen cupo: mientras quede
## reloj, sigue llegando gente.
static func unlimited_clients(id: String) -> bool:
	return is_timed(id)


## Nombre legible del tipo de nivel.
static func kind_name(id: String) -> String:
	return KIND_NAMES.get(get_kind(id), "Isla")


## Textura del nodo en el mapa según el tipo.
static func kind_texture(id: String) -> String:
	return KIND_TEXTURES.get(get_kind(id), KIND_TEXTURES["isla"])


## Posición del nivel en el lienzo del mapa.
static func map_pos(id: String) -> Vector2:
	return MAP_POS.get(id, Vector2.ZERO)


## Devuelve el diccionario del nivel con ese id, o {} si no existe.
static func get_port(id: String) -> Dictionary:
	for p in PORTS:
		if p.id == id:
			return p
	return {}


## Índice del nivel en la ruta, o -1.
static func port_index(id: String) -> int:
	for i in PORTS.size():
		if PORTS[i].id == id:
			return i
	return -1


## Id del nivel anterior en la ruta ("" si es el primero o no existe).
static func prev_port_id(id: String) -> String:
	var i := port_index(id)
	if i <= 0:
		return ""
	return PORTS[i - 1].id


## Id del primer nivel de la ruta ("" si no hay niveles).
static func first_port_id() -> String:
	if PORTS.is_empty():
		return ""
	return PORTS[0].id


## Recetas que se pueden LLEVAR a este puerto.
##
## Si el puerto trae `fixed_recipes`, esa es la carta y punto (las islas con
## menú cerrado). Si no, valen las iniciales más las recompensas de los puertos
## ANTERIORES: aunque el jugador tenga media carta desbloqueada por haber
## avanzado, un puerto temprano no debe ofrecer recetas de más adelante.
##
## `superado` (el puerto ya está pasado y se está REPITIENDO) solo cambia la
## carta de las ISLAS, que pueden traer una lista distinta para la repetición
## (`fixed_recipes_replay`): en el nivel 1 se vuelve con el nigiri que regaló
## David la primera vez.
## Carta CERRADA de un puerto ([] si es de libre elección). Las ISLAS se juegan
## siempre con las recetas que manda el nivel, también al repetirlo; lo único
## que cambia es que pueden traer una lista propia para la repetición
## (`fixed_recipes_replay`), con lo que David regaló la primera vez.
static func fixed_recipes_for(port_id: String, superado := false) -> Array[String]:
	var port := get_port(port_id)
	var fijas: Array = port.get("fixed_recipes", [])
	if superado and not port.get("fixed_recipes_replay", []).is_empty():
		fijas = port.get("fixed_recipes_replay", [])
	var out: Array[String] = []
	for r in fijas:
		out.append(str(r))
	if out.is_empty():
		return out
	# EXTRAS DE LA CARTA CERRADA, que dependen de lo que el jugador se haya
	# ganado: `optional_recipes` entra entera si está desbloqueada, y de
	# `alt_recipes` entra SOLO LA PRIMERA que lo esté (lista por preferencia).
	# Así una isla mantiene el tamaño de carta que se diseñó tanto si el jugador
	# sacó las 3 estrellas del nivel anterior como si no.
	for r in port.get("optional_recipes", []):
		if GameState.is_recipe_unlocked(str(r)) and not str(r) in out:
			out.append(str(r))
	for r in port.get("alt_recipes", []):
		if GameState.is_recipe_unlocked(str(r)):
			if not str(r) in out:
				out.append(str(r))
			break
	return out


static func recipes_for_port(port_id: String, superado := false) -> Array[String]:
	var out: Array[String] = []
	var fijas := fixed_recipes_for(port_id, superado)
	if not fijas.is_empty():
		return fijas
	for r in INITIAL_RECIPES:
		out.append(str(r))
	var idx := port_index(port_id)
	for i in PORTS.size():
		if idx >= 0 and i > idx:
			break
		# Las recompensas solo cuentan de los puertos ANTERIORES.
		if idx < 0 or i < idx:
			for r in PORTS[i].get("reward_recipes", []):
				if not str(r) in out:
					out.append(str(r))
			for r in PORTS[i].get("reward_recipes_3", []):
				if not str(r) in out:
					out.append(str(r))
		# Las recetas que REGALA David en plena partida (`gift_recipes`) no
		# están en ninguna recompensa, así que sin esto se quedaban fuera de la
		# carta para siempre: el nigiri de atún del nivel 3 no salía luego en
		# los siguientes. La del puerto EN CURSO también entra, para cuando se
		# repite un nivel ya jugado (la primera vez no está desbloqueada y el
		# selector la descarta solo).
		for r in PORTS[i].get("gift_recipes", []):
			if not str(r) in out:
				out.append(str(r))
	return out
