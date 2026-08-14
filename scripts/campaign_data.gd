class_name CampaignData
## Datos estáticos de la campaña (modo Aventura): lista ORDENADA de niveles.
##
## Cada nivel es una partida de ~4 min. La puntuación es POR DINERO generado:
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
##       carta que se puede llevar. Al tocar precios, se reescalan por el
##       cambio de ese $/s.
##     · Las ISLAS y los PUERTOS los limita la CLIENTELA (cupo cerrado): su
##       techo es clientes × platos por cliente × PRECIO medio de la carta. Al
##       tocar precios, se reescalan por el cambio de precio medio, NO de $/s —
##       con el $/s salían cifras imposibles (el nivel 2 pedía 127 doblones con
##       un techo real de ~75).
##    En los dos casos 1★/2★ quedan al 35% y al 62% del 3★, que es la forma que
##    ya tenía la campaña.
##    OJO al recalibrar: la carta dejó de mejorar mucho con el avance (todas las
##    recetas rinden parecido por segundo desde que se aplanó, ver CLAUDE.md),
##    así que del nivel 6 en adelante el dinero alcanzable apenas sube. Lo que
##    escala en los últimos abordajes es el PORCENTAJE de ese techo que se pide,
##    no el techo: por eso el 7 y el 9 llevan las cifras levantadas a mano sobre
##    lo que daba el reescalado puro (que dejaba el 9 por debajo del 6).
##  - fixed_recipes: carta CERRADA (las islas). El jugador no elige: se juega
##    con esas recetas y punto, también al repetir el puerto.
##    `fixed_recipes_replay` es la lista para cuando ya está superado (en el
##    nivel 3 entra el nigiri de atún que regaló David la primera vez).
##  - reward_recipes: recetas que se desbloquean al SUPERARLO (goal_stars, que
##    son 2 estrellas: con 2★ el puerto queda pasado y se abre el siguiente).
##  - reward_recipes_3 / reward_ingots_3 / reward_rice_3: el premio GORDO, solo
##    al sacar las 3 estrellas. Las 3★ piden bastante más dinero que las 2★, así
##    que son un reto aparte y no un trámite; se pueden conseguir volviendo al
##    puerto más adelante, con mejor carta.
##    (Los potenciadores NO se desbloquean por campaña: los PERMANENTES se
##    ganan con combos dentro de una partida, ver PerkData.)
##    El reparto sigue a la CLIENTELA del puerto: donde solo hay
##    grumetes se sueltan recetas de nivel 1, los piratas traen las de
##    nivel 2 y los capitanes las de nivel 3. Los postres caen en el
##    puerto donde ya se sientan clientes de su tipo (`only_type`).
##    Entre las iniciales y las recompensas quedan cubiertas 33 de las 34
##    recetas visibles: la que falta es el DRAGON ROLL, que solo se consigue
##    con el día 7 del bonus diario. Las `hidden` (barco, combinados,
##    variantes de fritura) no se desbloquean, salen de sus mecánicas.
##
## CÓMO TERMINA UN NIVEL (depende del TIPO, ver KINDS):
##  - "abordaje": es el único que lleva RELOJ, y son SHIP_TIME (3 min) para
##    todos. No hay tope de clientes: entran mientras quede tiempo. Acaba al
##    agotarse el reloj o al llegar al oro objetivo.
##  - "isla" y "puerto": SIN reloj. Lo que los acota es la CLIENTELA: acaban
##    cuando se ha ido el último cliente de `client_mix` o al llegar al oro
##    objetivo. Su HUD no enseña contador de tiempo.

## Duración de los niveles de ABORDAJE, los únicos con reloj.
const SHIP_TIME := 150.0

## Con lo que arranca una partida nueva.
## Las 4 recetas del tutorial de David Jones: se DESBLOQUEAN al completarlo
## (GameState.complete_tutorial), no al crear la partida.
const INITIAL_RECIPES: Array = ["maki_aguacate", "nigiri_salmon", "te_verde", "mochi"]
## Usos de ingredientes iniciales (suficientes para varias partidas del nivel 1,
## incluidos los de las recetas del tutorial).
const INITIAL_INGREDIENTS: Dictionary = {
	"aguacate": 5, "salmon": 5, "te": 3, "masa_mochi": 3, "matcha": 3,
}

const PORTS: Array = [
	{
		"id": "nivel_1",
		"name": "Cala Tortuga",
		"desc": "Cuatro grumetes y las cuatro recetas que te enseñó David.",
		"client_mix": { "E": 4 },
		"arrival_span": 150.0,
		"patience_mult": 1.0,
		"arrival_scale": 1.0,
		"goal_stars": 2,
		# 4 grumetes con platos de $1-3 y el maki rindiendo 3 piezas.
		"star_money": [22, 37, 49],
		"reward_recipes": ["gunkan_wakame"],
		"reward_recipes_3": ["edamame"],
		# Primer nivel de verdad: carta CERRADA (las del tutorial) y sin extras,
		# combinados ni barco, que se presentan más adelante.
		"fixed_recipes": ["maki_aguacate", "nigiri_salmon", "te_verde", "mochi"],
		"no_extras": true,
		"director": "nivel_1",
	},
	{
		"id": "nivel_2",
		"name": "Puerto Corona",
		"desc": "Un puerto de verdad: diez grumetes sin parar de entrar.",
		"client_mix": { "E": 10 },
		"arrival_span": 180.0,
		"patience_mult": 0.85,
		"arrival_scale": 0.65,
		"goal_stars": 2,
		# 10 clientes es MUCHA rotación aunque solo sean grumetes.
		"star_money": [57, 95, 127],
		# Con 2★ se abre la TIENDA (y con ella la escena de Saverio); el onigiri
		# es el premio de las 3★.
		"reward_recipes": [],
		"reward_recipes_3": ["onigiri"],
		"no_extras": true,
		"unlocks_shop": true,
		"director": "nivel_2",
	},
	{
		"id": "nivel_3",
		"name": "Isla del Mono",
		"desc": "Llega el primer pirata: prefiere platos de 2 estrellas.",
		"client_mix": { "E": 3, "A": 1 },
		"arrival_span": 150.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.8,
		"goal_stars": 2,
		# Pocos clientes pero uno come L2, y a media partida se suma el nigiri
		# de atún que regala David.
		"star_money": [38, 63, 94],
		"reward_recipes": ["maki_atun"],
		"reward_recipes_3": ["dorayaki"],
		# Isla: carta cerrada. La CUARTA la regala David en plena partida, y al
		# repetir el puerto se vuelve ya con ella puesta.
		"fixed_recipes": ["maki_aguacate", "nigiri_salmon", "mochi"],
		"fixed_recipes_replay": ["maki_aguacate", "nigiri_salmon", "mochi",
			"nigiri_atun"],
		"no_extras": false,
		# El pirata llega SIEMPRE el último; si el jugador va sobrado, el guion
		# lo adelanta para que dé tiempo a estrenar con él el nigiri de atún
		# que regala David (ver level_director.gd).
		"late_type": "A",
		"director": "nivel_3",
		"gift_recipes": ["nigiri_atun"],
	},
	{
		"id": "nivel_4",
		"name": "Arrecife del Ron",
		"desc": "Cuatro grumetes y dos piratas con sed de atún.",
		"client_mix": { "E": 4, "A": 2 },
		"arrival_span": 150.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.8,
		"goal_stars": 2,
		"star_money": [45, 74, 96],
		"reward_recipes": ["caldo_dashi"],
		"reward_recipes_3": ["sopa_miso"],
		# Isla: carta cerrada con los dos escalones de la carta, salmón y atún.
		"fixed_recipes": ["maki_aguacate", "nigiri_salmon", "maki_atun",
			"nigiri_atun"],
		# El BARCO combinado se estrena aquí y a partir de ahora sale siempre.
		"boat": true,
		"director": "nivel_4",
		# Superarlo abre la PESCA del menú (GameState.fishing_unlocked):
		# a mitad de campaña ya hay monedero para apostar 50 por intento.
		"unlocks_fishing": true,
	},
	{
		"id": "nivel_5",
		"name": "Flota del capitán Pablo el Rubio",
		"desc": "Abordaje a la flota de un viejo conocido de David.",
		"client_mix": { "E": 2, "A": 2, "G": 1 },
		"arrival_span": 120.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.7,
		"goal_stars": 2,
		# Abordaje: 2:30 y clientela sin fin, con un capitán (Pablo) que come de 3
		# estrellas. Entran unos 8 clientes (paso de 15,9 s), así que la barra no
		# llega a llenarse: es el abordaje más tranquilo. Con SOLO 3 huecos y sin
		# recetas de 3★ desbloqueadas, la carta buena es nigiri de atún $6, maki
		# de atún $5 (con maestría, 3 piezas) y onigiri $4 → media $5.
		# 30 platos × $5 × 0.65 ≈ 100.
		"star_money": [38, 64, 99],
		"boat": true,
		# Carta LIBRE, pero solo tres huecos LA PRIMERA VEZ: al repetir el
		# puerto se juega con los cuatro de siempre (ver prep_screen).
		"recipe_slots": 3,
		# El capitán del nivel es Pablo el Rubio: mismo comportamiento que un
		# capitán normal, pero con su propio modelo (ver CharacterData).
		"special_client": { "who": "pablo", "type": "G" },
		# Pablo entra el ÚLTIMO; si el jugador va sobrado, el guion lo adelanta.
		"late_type": "G",
		"director": "nivel_5",
		# David avisa en el selector de recetas antes de zarpar.
		"prep_dialog": "nivel_5",
		"gift_recipes": ["salmon_tsuke_don"],
		# Mientras corre el guion, el tsuke don es SOLO para Pablo (es su
		# regalo); al repetir el puerto ya se le puede servir a cualquiera.
		"exclusive_dishes": { "salmon_tsuke_don": "pablo" },
		"reward_recipes": ["sashimi_atun_rojo"],
		"reward_recipes_3": ["aburi"],
		# Las 3★ pagan además en LINGOTES.
		"reward_ingots_3": 2,
	},
	{
		"id": "nivel_6",
		"name": "Bahía del Kraken",
		"desc": "11 bocas: 6 grumetes, 3 piratas y 2 capitanes impacientes.",
		"client_mix": { "E": 6, "A": 3, "G": 2 },
		"arrival_span": 150.0,
		"patience_mult": 0.8,
		"arrival_scale": 0.65,
		"goal_stars": 2,
		# Se estrenan las recetas de 3★ (aburi $12, sashimi de atún rojo $11) y
		# entran ~16 clientes, dos de ellos capitanes que las cogen al 95%:
		# media $6. 30 platos × $6 × 0.65 ≈ 120.
		"star_money": [41, 73, 118],
		"boat": true,
		"reward_recipes": ["yaki_onigiri", "futomaki_salmon", "sashimi_tamago",
			"nigiri_inari"],
		"reward_recipes_3": ["uramaki_california", "nigiri_pulpo"],
		"reward_rice_3": 2,
	},
	{
		"id": "nivel_7",
		"name": "Estrecho del Rayo",
		"desc": "¡Escala relámpago! La clientela entra sin darte respiro.",
		"client_mix": { "E": 4, "A": 2, "G": 2 },
		# La ventana de llegadas más corta de la campaña: en un abordaje eso no
		# acorta el nivel, lo llena — los clientes se pisan unos a otros.
		"arrival_span": 90.0,
		"patience_mult": 0.85,
		"arrival_scale": 0.7,
		"goal_stars": 2,
		# Misma carta que el 6 (media $6) pero con el doble de llegadas: ~21
		# clientes para 8 taburetes, así que la barra está SIEMPRE llena y no se
		# pierde ni un segundo de asiento. 30 platos × $6 × 0.68 ≈ 125.
		"star_money": [45, 79, 128],
		"boat": true,
		"reward_recipes": ["nigiri_anguila", "udon"],
		"reward_recipes_3": ["temaki", "tempura"],
		"reward_rice_3": 2,
	},
	{
		"id": "nivel_8",
		"name": "Puerto Tormenta",
		"desc": "14 clientes al abordaje: la cinta no puede parar.",
		"client_mix": { "E": 8, "A": 4, "G": 2 },
		"arrival_span": 180.0,
		"patience_mult": 0.75,
		"arrival_scale": 0.6,
		"goal_stars": 2,
		# Más clientes que asientos (8): rotación constante.
		"star_money": [59, 105, 171],
		"boat": true,
		"reward_recipes": ["nigiri_ebi", "taiyaki", "gunkan_tartar"],
		"reward_recipes_3": ["hana_maki", "gunkan_ikura"],
		"reward_ingots_3": 1,
	},
	{
		"id": "nivel_9",
		"name": "Mar del Leviatán",
		"desc": "La gran travesía final: 17 clientes y toda la carta en juego.",
		"client_mix": { "E": 9, "A": 5, "G": 3 },
		"arrival_span": 150.0,
		"patience_mult": 0.7,
		"arrival_scale": 0.55,
		"goal_stars": 2,
		# Final: la carta entera en juego (hasta $12-14, con la maestría del hana
		# maki dando 4 piezas) y tres capitanes en la mezcla → media $8.
		# 30 platos × $8 × 0.65 ≈ 155.
		"star_money": [51, 90, 145],
		"boat": true,
		# El DRAGON ROLL sale de la campaña: es el premio del día 7 del BONUS
		# DIARIO, la única receta que no se gana jugando niveles. Por eso este
		# puerto reparte una receta menos que antes y las visibles que cubre la
		# campaña bajan de 34 a 33.
		"reward_recipes": ["fugu", "sashimi_variado"],
		"reward_recipes_3": ["chirashi", "nigiri_wagyu"],
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
	"nivel_2": "puerto",
	"nivel_3": "isla",
	"nivel_4": "isla",
	"nivel_5": "abordaje",
	"nivel_6": "abordaje",
	"nivel_7": "abordaje",
	"nivel_8": "puerto",
	"nivel_9": "abordaje",
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
const MAP_HEIGHT := 2180

const LANE_LEFT := 175.0
const LANE_CENTER := 360.0
const LANE_RIGHT := 545.0

## Separación vertical entre puertos, IGUAL para todos. La medida no es a ojo:
## `level_select3d._setup_route` dibuja un guión cada 0.44 unidades de mundo, y
## el tramo más corto (un salto de carril, 185 px en horizontal) tiene que dar
## al menos 8. Con 215 px salen 10 en el corto y 13 en el largo. Antes el salto
## del nivel 1 al 2 eran 86 px y solo se veían 5 guiones.
## Si se cambia este paso hay que bajar `main_menu.MENU_ANCHOR` otro tanto, o el
## nivel 1 asoma por arriba estando en el menú.
const MAP_STEP := 215.0

const MAP_POS: Dictionary = {
	"nivel_1": Vector2(LANE_CENTER, 1930.0),
	"nivel_2": Vector2(LANE_LEFT, 1715.0),
	"nivel_3": Vector2(LANE_RIGHT, 1500.0),
	"nivel_4": Vector2(LANE_CENTER, 1285.0),
	"nivel_5": Vector2(LANE_LEFT, 1070.0),
	"nivel_6": Vector2(LANE_RIGHT, 855.0),
	"nivel_7": Vector2(LANE_CENTER, 640.0),
	"nivel_8": Vector2(LANE_LEFT, 425.0),
	"nivel_9": Vector2(LANE_RIGHT, 210.0),
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
## (`fixed_recipes_replay`): en el nivel 3 se vuelve con el nigiri de atún que
## regaló David la primera vez.
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
		# carta para siempre: el nigiri de atún del nivel 3 no salía luego en el
		# 5. La del puerto EN CURSO también entra, para cuando se repite un
		# nivel ya jugado (la primera vez no está desbloqueada y el selector la
		# descarta solo).
		for r in PORTS[i].get("gift_recipes", []):
			if not str(r) in out:
				out.append(str(r))
	return out
