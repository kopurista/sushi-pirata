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
##  - reward_recipes: recetas que se desbloquean al superarlo la 1ª vez.
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
		"goal_stars": 3,
		# 4 grumetes con platos de $1-3 y el maki rindiendo 3 piezas: ~$50 de techo.
		"star_money": [14, 26, 40],
		"reward_recipes": ["edamame", "gunkan_wakame"],
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
		"goal_stars": 3,
		# 10 clientes es MUCHA rotación aunque solo sean grumetes: techo ~$110.
		"star_money": [24, 42, 60],
		"reward_recipes": ["onigiri"],
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
		"goal_stars": 3,
		# Pocos clientes pero uno come L2, y a mitad se suma el nigiri de atún.
		"star_money": [20, 38, 55],
		"reward_recipes": ["dorayaki", "maki_atun"],
		# Toda la carta disponible, pero solo TRES huecos que llevar.
		"recipe_slots": 3,
		# El pirata llega el último; David lo aprovecha para regalar el nigiri
		# de atún en plena partida (ver level_director.gd).
		"late_type": "A",
		"director": "nivel_3",
	},
	{
		"id": "nivel_4",
		"name": "Arrecife del Ron",
		"desc": "Doble tripulación: 6 grumetes y 4 piratas sedientos.",
		"client_mix": { "E": 6, "A": 4 },
		"time_limit": 150.0,
		"patience_mult": 0.85,
		"arrival_scale": 0.7,
		"goal_stars": 3,
		# 10 clientes con 4 piratas de L2: techo ~$90-100.
		"star_money": [24, 45, 65],
		"reward_recipes": ["sopa_miso", "sashimi_tamago", "udon", "tempura"],
	},
	{
		"id": "nivel_5",
		"name": "Cabo del Capitán",
		"desc": "Baja a tierra el primer capitán: exige lo mejor de la carta.",
		"client_mix": { "E": 4, "A": 3, "G": 1 },
		"time_limit": 180.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.75,
		"goal_stars": 3,
		# Menos clientes pero de más nivel (el capitán come L2-L3): techo ~$95.
		"star_money": [25, 48, 70],
		"reward_recipes": ["nigiri_inari", "caldo_dashi", "gunkan_tartar",
			"gunkan_ikura"],
	},
	{
		"id": "nivel_6",
		"name": "Bahía del Kraken",
		"desc": "11 bocas: 6 grumetes, 3 piratas y 2 capitanes impacientes.",
		"client_mix": { "E": 6, "A": 3, "G": 2 },
		"time_limit": 150.0,
		"patience_mult": 0.8,
		"arrival_scale": 0.65,
		"goal_stars": 3,
		# 11 clientes y 2 capitanes: techo ~$110.
		"star_money": [28, 55, 80],
		"reward_recipes": ["yaki_onigiri", "futomaki_salmon",
			"uramaki_california", "nigiri_pulpo"],
	},
	{
		"id": "nivel_7",
		"name": "Estrecho del Rayo",
		"desc": "¡Escala relámpago! Solo 1:30 para servir a 8 clientes.",
		"client_mix": { "E": 4, "A": 2, "G": 2 },
		"time_limit": 90.0,
		"patience_mult": 0.85,
		"arrival_scale": 0.7,
		"goal_stars": 3,
		# Partida de 1:30 (~60% de producción) con futomaki L3 disponible: ~$65.
		"star_money": [20, 40, 58],
		"reward_recipes": ["sashimi_atun_rojo", "nigiri_anguila", "temaki"],
	},
	{
		"id": "nivel_8",
		"name": "Puerto Tormenta",
		"desc": "14 clientes al abordaje: la cinta no puede parar.",
		"client_mix": { "E": 8, "A": 4, "G": 2 },
		"time_limit": 180.0,
		"patience_mult": 0.75,
		"arrival_scale": 0.6,
		"goal_stars": 3,
		# Más clientes que asientos (8): rotación constante, techo ~$120-130.
		"star_money": [32, 62, 90],
		"reward_recipes": ["nigiri_ebi", "aburi", "hana_maki", "taiyaki"],
	},
	{
		"id": "nivel_9",
		"name": "Mar del Leviatán",
		"desc": "La gran travesía final: 17 clientes y toda la carta en juego.",
		"client_mix": { "E": 9, "A": 5, "G": 3 },
		"time_limit": 150.0,
		"patience_mult": 0.7,
		"arrival_scale": 0.55,
		"goal_stars": 3,
		# Final: 17 clientes (más del doble que asientos), techo ~$140.
		"star_money": [36, 70, 100],
		"reward_recipes": ["fugu", "chirashi", "dragon_roll",
			"nigiri_wagyu", "sashimi_variado"],
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
	"nivel_5": "puerto",
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
const MAP_HEIGHT := 1720

const LANE_LEFT := 175.0
const LANE_CENTER := 360.0
const LANE_RIGHT := 545.0

const MAP_POS: Dictionary = {
	"nivel_1": Vector2(LANE_CENTER, 1476.0),
	"nivel_2": Vector2(LANE_LEFT, 1390.0),
	"nivel_3": Vector2(LANE_RIGHT, 1220.0),
	"nivel_4": Vector2(LANE_CENTER, 1050.0),
	"nivel_5": Vector2(LANE_LEFT, 880.0),
	"nivel_6": Vector2(LANE_RIGHT, 710.0),
	"nivel_7": Vector2(LANE_CENTER, 540.0),
	"nivel_8": Vector2(LANE_LEFT, 370.0),
	"nivel_9": Vector2(LANE_RIGHT, 200.0),
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
static func recipes_for_port(port_id: String) -> Array[String]:
	var out: Array[String] = []
	var port := get_port(port_id)
	var fijas: Array = port.get("fixed_recipes", [])
	if not fijas.is_empty():
		for r in fijas:
			out.append(str(r))
		return out
	for r in INITIAL_RECIPES:
		out.append(str(r))
	var idx := port_index(port_id)
	for i in PORTS.size():
		if idx >= 0 and i >= idx:
			break
		for r in PORTS[i].get("reward_recipes", []):
			if not str(r) in out:
				out.append(str(r))
	return out
