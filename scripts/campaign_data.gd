class_name CampaignData
## Datos estáticos de la campaña (modo Aventura): lista ORDENADA de niveles.
##
## Cada nivel es una partida de ~4 min. La puntuación es POR DINERO generado:
## "star_money" = [1★, 2★, 3★] doblones mínimos. Superar el nivel (alcanzar
## "goal_stars") desbloquea el siguiente y concede sus recompensas la 1ª vez.
##
## Campos de cada nivel:
##  - id, name, desc: identificación y texto para la pantalla de niveles.
##  - client_mix: recuento EXACTO de clientes {E,A,G} (E grumete, A pirata,
##    G capitán). El nivel construye una cola barajada con exactamente esos
##    clientes; total_clients se deriva de la suma.
##  - time_limit: duración en segundos.
##  - patience_mult: multiplicador de paciencia (<1 = más difícil).
##  - arrival_scale: comprime el horario de llegadas (<1 = vienen más rápido).
##  - goal_stars: estrellas mínimas para superar el nivel y avanzar.
##  - star_money: [dinero para 1★, 2★, 3★] — SOLO precio de platos (sin propinas),
##    calibrado al techo de producción de cada nivel.
##  - reward_recipes: recetas que se desbloquean al SUPERARLO (goal_stars, que
##    son 2 estrellas: con 2★ el puerto queda pasado y se abre el siguiente).
##  - reward_recipes_3 / reward_ingots_3 / reward_rice_3: el premio GORDO, solo
##    al sacar las 3 estrellas. Las 3★ piden bastante más dinero que las 2★, así
##    que son un reto aparte y no un trámite; se pueden conseguir volviendo al
##    puerto más adelante, con mejor carta.
##    (Los potenciadores NO se desbloquean por campaña de momento.)
##    El reparto sigue a la CLIENTELA del puerto: donde solo hay
##    grumetes se sueltan recetas de nivel 1, los piratas traen las de
##    nivel 2 y los capitanes las de nivel 3. Los postres caen en el
##    puerto donde ya se sientan clientes de su tipo (`only_type`).
##    Entre las iniciales y las recompensas quedan cubiertas las 34
##    recetas visibles; las `hidden` (barco, combinados, variantes de
##    fritura) no se desbloquean, salen de sus mecánicas.

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
		"time_limit": 150.0,
		"patience_mult": 1.0,
		"arrival_scale": 1.0,
		"goal_stars": 2,
		# 4 grumetes con platos de $1-3 y el maki rindiendo 3 piezas.
		"star_money": [18, 30, 40],
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
		"time_limit": 180.0,
		"patience_mult": 0.85,
		"arrival_scale": 0.65,
		"goal_stars": 2,
		# 10 clientes es MUCHA rotación aunque solo sean grumetes.
		"star_money": [45, 75, 100],
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
		"time_limit": 150.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.8,
		"goal_stars": 2,
		# Pocos clientes pero uno come L2, y a media partida se suma el nigiri
		# de atún que regala David.
		"star_money": [30, 50, 75],
		"reward_recipes": ["maki_atun"],
		"reward_recipes_3": ["dorayaki"],
		# Isla: carta cerrada. La CUARTA la regala David en plena partida.
		"fixed_recipes": ["maki_aguacate", "nigiri_salmon", "onigiri"],
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
		"time_limit": 150.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.8,
		"goal_stars": 2,
		"star_money": [42, 70, 90],
		"reward_recipes": ["caldo_dashi"],
		"reward_recipes_3": ["sopa_miso"],
		# Isla: carta cerrada con los dos escalones de la carta, salmón y atún.
		"fixed_recipes": ["maki_aguacate", "nigiri_salmon", "maki_atun",
			"nigiri_atun"],
		# El BARCO combinado se estrena aquí y a partir de ahora sale siempre.
		"boat": true,
		"director": "nivel_4",
	},
	{
		"id": "nivel_5",
		"name": "Flota del capitán Pablo el Rubio",
		"desc": "Abordaje a la flota de un viejo conocido de David.",
		"client_mix": { "E": 2, "A": 2, "G": 1 },
		"time_limit": 120.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.7,
		"goal_stars": 2,
		# Dos minutos con cinco bocas, una de ellas un capitán que come de 3
		# estrellas: el techo lo marca la producción, no la clientela.
		"star_money": [42, 70, 80],
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
		"time_limit": 150.0,
		"patience_mult": 0.8,
		"arrival_scale": 0.65,
		"goal_stars": 2,
		# 11 clientes y 2 capitanes.
		"star_money": [40, 70, 115],
		"boat": true,
		"reward_recipes": ["yaki_onigiri", "futomaki_salmon", "sashimi_tamago",
			"nigiri_inari"],
		"reward_recipes_3": ["uramaki_california", "nigiri_pulpo"],
		"reward_rice_3": 2,
	},
	{
		"id": "nivel_7",
		"name": "Estrecho del Rayo",
		"desc": "¡Escala relámpago! Solo 1:30 para servir a 8 clientes.",
		"client_mix": { "E": 4, "A": 2, "G": 2 },
		"time_limit": 90.0,
		"patience_mult": 0.85,
		"arrival_scale": 0.7,
		"goal_stars": 2,
		# Partida de 1:30, o sea ~60% de la producción de una normal.
		"star_money": [28, 48, 82],
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
		"time_limit": 180.0,
		"patience_mult": 0.75,
		"arrival_scale": 0.6,
		"goal_stars": 2,
		# Más clientes que asientos (8): rotación constante.
		"star_money": [45, 80, 130],
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
		"time_limit": 150.0,
		"patience_mult": 0.7,
		"arrival_scale": 0.55,
		"goal_stars": 2,
		# Final: 17 clientes, más del doble que asientos.
		"star_money": [50, 92, 145],
		"boat": true,
		"reward_recipes": ["fugu", "dragon_roll", "sashimi_variado"],
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
## `superado` (el puerto ya está pasado y se está REPITIENDO) suelta las dos
## ataduras, igual que los huecos de receta: la carta cerrada deja de serlo y
## entran también las recompensas del propio puerto. Volver a por las 3
## estrellas se hace con lo que uno ya se ha ganado ahí — en el nivel 3, con
## los platos de 2 estrellas que pide el pirata.
static func recipes_for_port(port_id: String, superado := false) -> Array[String]:
	var out: Array[String] = []
	var port := get_port(port_id)
	var fijas: Array = port.get("fixed_recipes", [])
	if not fijas.is_empty() and not superado:
		for r in fijas:
			out.append(str(r))
		return out
	for r in INITIAL_RECIPES:
		out.append(str(r))
	var idx := port_index(port_id)
	for i in PORTS.size():
		if idx >= 0 and i > idx:
			break
		# Las recompensas cuentan de los puertos ANTERIORES, y también de este
		# mismo cuando se repite (lo que se gana aquí se puede traer aquí).
		if idx < 0 or i < idx or superado:
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
