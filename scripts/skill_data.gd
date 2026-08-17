class_name SkillData
## MAESTRÍAS DEL COCINERO: el catálogo de los 15 nodos (3 árboles × 5
## habilidades × 5 rangos) y la economía de experiencia. Aquí SOLO hay datos y
## helpers puros; el estado (XP, nivel, rangos comprados) vive en GameState.
##
## Cómo funciona, de punta a punta:
##  1. Cada ESCENARIO superado paga experiencia (ver `scenario_xp` en
##     GameState): 15 × su número, por estrellas (×0.5/×1/×1.5) y ×3 contra el
##     RÉCORD — mejorar de 2★ a 3★ cobra solo la diferencia, así que un
##     escenario deja siempre lo mismo se borde al primer intento o al quinto.
##  2. Subir del nivel n al n+1 cuesta 60 + 20·(n−1). El nivel 1 ya trae su
##     punto: 450 niveles = 450 puntos, que es EXACTO lo que cuestan los tres
##     árboles al máximo (150 cada uno).
##  3. Comprar una habilidad cuesta 5 puntos y cada rango extra otros 5; la
##     QUINTA de cada árbol cuesta 10 en los dos casos. La 3ª pide tener las
##     dos primeras, la 4ª pide la 3ª y la 5ª pide la 4ª.
##
## EL TECHO DE PRODUCCIÓN ES ×2,5 (decidido, no re-litigar): los tres árboles
## al máximo multiplican el oro por ~2,45 (cuchillo ×1,36 · cliente ×1,20 ·
## chef ×1,50). Al añadir o retocar una habilidad hay que rehacer esa cuenta:
## los `star_money` de los escenarios futuros se escalan contra este techo.
##
## Los EFECTOS no se aplican aquí: cada uno se cablea donde ocurre su suceso
## (prep_board para los gestos, client3d para la barra, plate3d para la
## cinta), consultando `GameState.skill_value(id)` / `skill_rank(id)`.

## Nivel máximo del cocinero. Empezando con 1 punto en el nivel 1, da los 450
## puntos que cuesta el catálogo entero.
const MAX_LEVEL := 450
const MAX_RANK := 5

## Curva de experiencia: subir de n a n+1 cuesta XP_BASE + XP_STEP·(n−1).
## Es una RECTA a propósito: con 450 niveles, una exponencial deja el último
## tercio inalcanzable y el jugador deja de mirarlo.
const XP_BASE := 60
const XP_STEP := 20

## Tarifa de los escenarios: base = XP_SCENARIO × número del escenario,
## multiplicada por STAR_MULT[estrellas] y ×FIRST_MULT contra el récord.
## Calibrada contra el jugador que da DOS pasadas por escenario (a 30 llegaba
## al 450 en el escenario 150, con dos mares por delante y nada que ganar).
const XP_SCENARIO := 15
const STAR_MULT := [0.0, 0.5, 1.0, 1.5]
const FIRST_MULT := 3.0

## El ARCADE paga por oleada superada: ARCADE_WAVE_XP × número de la oleada.
## Generoso porque cuesta despensa POR OLEADA: el freno es la apuesta.
const ARCADE_WAVE_XP := 15

## Coste en puntos: las cuatro primeras habilidades de un árbol valen
## COST_NORMAL por rango (compra incluida); la quinta, COST_FINAL.
const COST_NORMAL := 5
const COST_FINAL := 10

const TREES: Array = [
	{ "id": "cuchillo", "name": "Maestría del cuchillo", "short": "Cuchillo",
		"icon": "res://assets/ui/tab_cuchillo.png",
		"desc": "Las manos: abarata los gestos de la tabla." },
	{ "id": "cliente", "name": "Maestría del cliente", "short": "Cliente",
		"icon": "res://assets/ui/tab_cliente.png",
		"desc": "La barra: saca más de cada boca que se sienta." },
	{ "id": "chef", "name": "Maestría del chef", "short": "Chef",
		"icon": "res://assets/ui/tab_chef.png",
		"desc": "El plato: cuántos salen y cuánto viven en la cinta." },
]

## Los 15 nodos. `row` 1..5 dentro de su árbol (la 5 es la final).
## `values` son los cinco rangos; `text` es la plantilla de la ficha (un %v
## por valor) y `texts` la variante con una frase POR RANGO (paladar).
## `extra` documenta los efectos secundarios que no caben en un número.
const SKILLS: Dictionary = {
	# ------------------------------------------------ árbol 1: el cuchillo
	"fuego_constante": {
		"tree": "cuchillo", "row": 1, "name": "Fuego constante",
		"desc": "Los enfriamientos de todas las recetas duran menos.",
		"values": [4, 8, 12, 16, 20],
		"text": "Enfriamientos un %v%% más cortos.",
	},
	"pulso_firme": {
		"tree": "cuchillo", "row": 2, "name": "Pulso firme",
		"desc": "Mantener y remover piden menos aguante, y el punto bueno de la fritura se ensancha.",
		"values": [8, 15, 22, 29, 35],
		"text": "Mantener pide un %v%% menos de tiempo.",
		# Cuánto se ENSANCHA la ventana de la fritura por rango (se aplica
		# comprimiendo el tiempo medido hacia el punto perfecto).
		"fry_widen": [8, 16, 24, 32, 40],
	},
	"corte_maestro": {
		"tree": "cuchillo", "row": 3, "name": "Corte de maestro",
		"desc": "El corte lento admite más velocidad antes de darse por fallado.",
		"values": [10, 20, 30, 40, 50],
		"text": "El corte lento admite un %v%% más de velocidad.",
		# Rango III: el castigo del corte rápido se parte por la mitad.
		# Rango V: el primer fallo de cada jornada sale gratis.
		"half_penalty_rank": 3,
		"free_fail_rank": 5,
	},
	"manos_ligeras": {
		"tree": "cuchillo", "row": 4, "name": "Manos ligeras",
		"desc": "Los deslizamientos piden menos recorrido y remover, menos vuelta.",
		"values": [10, 20, 30, 40, 40],
		"text": "Deslizar pide un %v%% menos de recorrido.",
		# El rango V no acorta más: convierte los pasos de 3 golpes en pasos
		# de 2. Nunca baja de 2, o deja de haber minijuego.
		"tap_discount_rank": 5,
	},
	"golpe_vista": {
		"tree": "cuchillo", "row": 5, "name": "Golpe de vista",
		"desc": "Cada tantos platos, el siguiente sale hecho sin un solo gesto. Contador a la vista, no dado.",
		"values": [10, 8, 6, 4, 3],
		"text": "Uno de cada %v platos sale hecho solo.",
	},
	# ------------------------------------------------- árbol 2: el cliente
	"buen_anfitrion": {
		"tree": "cliente", "row": 1, "name": "Buen anfitrión",
		"desc": "Cada plato recarga más paciencia de la que le tocaría.",
		"values": [8, 15, 22, 29, 35],
		"text": "Los platos recargan un %v%% más de paciencia.",
	},
	"buen_precio": {
		"tree": "cliente", "row": 2, "name": "Buen precio",
		"desc": "Cada plato paga más de lo que dice su ficha.",
		"values": [3, 6, 9, 12, 15],
		"text": "Los platos pagan un %v%% más.",
	},
	"mano_suelta": {
		"tree": "cliente", "row": 3, "name": "Mano suelta",
		"desc": "Las propinas que caen son más gordas.",
		"values": [10, 18, 26, 34, 40],
		"text": "Propinas un %v%% más gordas.",
	},
	"buena_cara": {
		"tree": "cliente", "row": 4, "name": "Buena cara",
		"desc": "Cae propina más a menudo (respetando el tope de cada tipo de cliente).",
		"values": [5, 9, 13, 17, 20],
		"text": "+%v puntos de probabilidad de propina.",
	},
	"fama": {
		"tree": "cliente", "row": 5, "name": "Fama del cocinero",
		"desc": "Nadie le hace ascos a tu cocina: probabilidad mínima de coger cualquier plato, sea cual sea el cliente.",
		"values": [30, 40, 50, 60, 70],
		"text": "Todo plato se coge al menos al %v%%.",
	},
	# ---------------------------------------------------- árbol 3: el chef
	"cocina_abundante": {
		"tree": "chef", "row": 1, "name": "Cocina abundante",
		"desc": "Cada tantos platos, de una elaboración salen dos.",
		"values": [10, 8, 7, 6, 4],
		"text": "Uno de cada %v platos sale doble.",
	},
	"buena_mano": {
		"tree": "chef", "row": 2, "name": "Buena mano",
		"desc": "Las cajas guardan más platos por pila.",
		"values": [4, 5, 6, 7, 8],
		"text": "Las cajas guardan %v platos.",
	},
	"segunda_vuelta": {
		"tree": "chef", "row": 3, "name": "Segunda vuelta",
		"desc": "Tus platos aguantan más vueltas en la cinta antes de caer al cubo, y tirarlos cuesta menos.",
		"values": [2, 2, 3, 3, 3],
		"text": "Los platos aguantan %v vueltas.",
		# Castigo del cubo por rango (en % del precio; sin rango es el 20).
		"waste": [20, 15, 15, 15, 5],
		# Desde este rango, cada vuelta nueva borra los RECHAZOS del plato:
		# todo el mundo vuelve a tener ocasión de cogerlo.
		"forget_rank": 4,
	},
	"golpe_suerte": {
		"tree": "chef", "row": 4, "name": "Golpe de suerte",
		"desc": "Cada tantos platos, el siguiente sube un punto extra de multiplicador al cliente que lo coja.",
		"values": [10, 8, 7, 6, 5],
		"text": "Uno de cada %v platos sube un punto extra.",
	},
	"paladar_generoso": {
		"tree": "chef", "row": 5, "name": "Paladar generoso",
		"desc": "Un plato admite una repetición antes de contar como repetido: la carta rinde como si fuera el doble de grande.",
		"values": [1, 2, 3, 4, 5],
		"texts": [
			"El primer plato de cada cliente admite una repetición.",
			"Los platos de 1★ admiten una repetición.",
			"Los platos de 1★ y 2★ admiten una repetición.",
			"Todos los platos admiten una repetición.",
			"Todos admiten una repetición; los de 1★, dos.",
		],
	},
}


static func get_skill(id: String) -> Dictionary:
	return SKILLS.get(id, {})


## Icono propio de la habilidad (assets/ui/skill_<id>.png, cadena
## `build_skills` de ui2_prep). Si faltara el arte, la moneda: nada crashea.
static func icon(id: String) -> Texture2D:
	var ruta := "res://assets/ui/skill_%s.png" % id
	if ResourceLoader.exists(ruta):
		return load(ruta)
	return load("res://assets/ui/moneda.png")


## Ids de las habilidades de un árbol, ordenadas por fila (1..5).
static func tree_skills(tree_id: String) -> Array[String]:
	var out: Array[String] = []
	for row in range(1, 6):
		for id in SKILLS:
			var s: Dictionary = SKILLS[id]
			if str(s.get("tree", "")) == tree_id and int(s.get("row", 0)) == row:
				out.append(str(id))
	return out


## Puntos que pide CADA RANGO de esta habilidad. OJO: los puntos se invierten
## DE UNO EN UNO (ver `rank_for_points`), no de golpe — el rango sube cuando la
## inversión acumulada llega a este listón.
static func rank_cost(id: String) -> int:
	return COST_FINAL if int(get_skill(id).get("row", 1)) >= 5 else COST_NORMAL


## Puntos que cuesta la habilidad ENTERA (los cinco rangos).
static func max_points(id: String) -> int:
	return rank_cost(id) * MAX_RANK


## RANGO que dan `points` puntos invertidos. La inversión es continua y el
## rango es su escalón: con coste 5, cuatro puntos NO desbloquean nada y el
## quinto sube al rango 1.
static func rank_for_points(id: String, points: int) -> int:
	return clampi(points / rank_cost(id), 0, MAX_RANK)


## Puntos que faltan para el siguiente rango (0 si ya está al máximo).
static func points_to_next(id: String, points: int) -> int:
	if points >= max_points(id):
		return 0
	return rank_cost(id) - (points % rank_cost(id))


## Habilidades que hay que TENER (rango ≥ 1) antes de comprar esta. La 3ª pide
## las dos primeras del árbol; la 4ª, la 3ª; la 5ª, la 4ª.
static func prereqs(id: String) -> Array[String]:
	var s := get_skill(id)
	var row := int(s.get("row", 1))
	var tree := str(s.get("tree", ""))
	var out: Array[String] = []
	if row <= 2:
		return out
	var todos := tree_skills(tree)
	if row == 3:
		out.append(todos[0])
		out.append(todos[1])
	else:
		out.append(todos[row - 2])
	return out


## Valor del efecto a ese rango (0 = sin comprar: valor neutro 0).
static func value_at(id: String, rank: int) -> float:
	if rank <= 0:
		return 0.0
	var vals: Array = get_skill(id).get("values", [])
	if vals.is_empty():
		return 0.0
	return float(vals[clampi(rank - 1, 0, vals.size() - 1)])


## Valor de una serie SECUNDARIA de la habilidad ("fry_widen", "waste"...).
static func aux_at(id: String, key: String, rank: int, fallback: float) -> float:
	if rank <= 0:
		return fallback
	var vals: Array = get_skill(id).get(key, [])
	if vals.is_empty():
		return fallback
	return float(vals[clampi(rank - 1, 0, vals.size() - 1)])


## Frase de lo que hace a ese rango, para las fichas de la pantalla.
static func rank_text(id: String, rank: int) -> String:
	var s := get_skill(id)
	var textos: Array = s.get("texts", [])
	if not textos.is_empty():
		return str(textos[clampi(rank - 1, 0, textos.size() - 1)])
	var plantilla := str(s.get("text", ""))
	if plantilla == "" or rank <= 0:
		return ""
	# %v = el valor del rango. Se pasa por String para admitir enteros limpios.
	return plantilla.replace("%v", str(int(value_at(id, rank)))) \
		.replace("%%", "%")


# ------------------------------------------------------ premios por nivel

## PREMIO DE SUBIR AL NIVEL `n`. Además del punto de maestría (que va SIEMPRE),
## cada nivel suelta algo distinto: subir de nivel tiene que sentirse como
## abrir un cofre, no como un contador que avanza.
##
## Cómo se reparte, y por qué así:
##  · El PUNTO de maestría es el premio de verdad y no falta nunca.
##  · Los LINGOTES solo caen en los múltiplos de 5, y suben en los de 10 y de
##    25: son la moneda de pago, así que tienen que leerse como un HITO y no
##    como calderilla de todos los niveles.
##  · El resto ROTA con el resto de dividir entre 4 (oro / ingredientes /
##    arroz / extras), de modo que dos niveles seguidos nunca dan lo mismo.
##  · Las cantidades escalan con el nivel: a estas alturas de la progresión un
##    puñado fijo de doblones dejaría de significar nada.
static func level_reward(n: int) -> Dictionary:
	var out := { "points": 1 }
	var oro := 30 + n * 6
	if n % 25 == 0:
		out["ingots"] = 3
	elif n % 10 == 0:
		out["ingots"] = 2
	elif n % 5 == 0:
		out["ingots"] = 1
	match n % 4:
		0:
			out["extras"] = 2 + n / 50
		1:
			out["gold"] = oro
		2:
			out["ingredients"] = 3 + n / 40
		_:
			out["rice"] = 1
	# En los hitos el oro cae ADEMÁS de lo que tocara, a lo grande.
	if out.has("ingots"):
		out["gold"] = int(out.get("gold", 0)) + oro * 2
	return out


## Rótulo y icono de cada clase de premio, para la ventana que los anuncia.
const REWARD_LABELS := {
	"points": ["punto de maestría", "puntos de maestría",
		"res://assets/ui/ic_maestrias.png"],
	"gold": ["doblón", "doblones", "res://assets/ui/moneda.png"],
	"ingots": ["lingote", "lingotes", "res://assets/ui/ic_lingote.png"],
	"rice": ["saco de arroz", "sacos de arroz", "res://assets/ui/ic_arroz.png"],
	"ingredients": ["uso de despensa", "usos de despensa",
		"res://assets/ingredients/salmon.png"],
	"extras": ["uso de cada extra", "usos de cada extra",
		"res://assets/ingredients/jengibre.png"],
}


## "3 lingotes", "1 saco de arroz"... con su singular bien puesto.
static func reward_text(clave: String, cantidad: int) -> String:
	var d: Array = REWARD_LABELS.get(clave, ["", "", ""])
	return "%d %s" % [cantidad, str(d[0]) if cantidad == 1 else str(d[1])]


static func reward_icon(clave: String) -> String:
	var d: Array = REWARD_LABELS.get(clave, ["", "", ""])
	return str(d[2])


## Experiencia que cuesta subir del nivel n al n+1.
static func xp_for_next(level: int) -> int:
	return XP_BASE + XP_STEP * maxi(level - 1, 0)


## Nivel que corresponde a esta experiencia acumulada (1..MAX_LEVEL).
static func level_for_xp(xp: int) -> int:
	var nivel := 1
	var resto := xp
	while nivel < MAX_LEVEL:
		var coste := xp_for_next(nivel)
		if resto < coste:
			break
		resto -= coste
		nivel += 1
	return nivel


## XP acumulada al ENTRAR en ese nivel (para la barra de progreso).
static func xp_at_level(level: int) -> int:
	var n := clampi(level, 1, MAX_LEVEL)
	# Suma de una progresión aritmética: (n−1) términos desde XP_BASE.
	return (n - 1) * XP_BASE + XP_STEP * (n - 1) * (n - 2) / 2
