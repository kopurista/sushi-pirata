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
## EL TECHO CONTRA EL QUE SE CALIBRA ES ×2,0, NO ×2,5 (revisado el 18-8-2026).
## Los tres árboles al máximo multiplican el oro por ~2,45 (cuchillo ×1,36 ·
## cliente ×1,20 · chef ×1,50), pero ESE JUGADOR NO EXISTE: con los 250
## escenarios previstos, bordarlos todos y sumarles el ×2 de los jefes deja al
## cocinero sobre el nivel 304 — 304 puntos, el 68% del catálogo—, y el 450
## solo se alcanza moliendo arcade y pesca durante muchísimo tiempo.
##
## Así que los `star_money` de los escenarios futuros se escalan contra **×2,0**
## (lo que da un reparto realista de ~300 puntos). Calibrar contra el 2,45
## afinaría los últimos mares para alguien que no va a llegar. El 450 se queda
## como techo de COMPLETISTA, que es coherente con tener un arcade sin fin.
## Al añadir o retocar una habilidad hay que rehacer las dos cuentas.
##
## Los EFECTOS no se aplican aquí: cada uno se cablea donde ocurre su suceso
## (prep_board para los gestos, client3d para la barra, plate3d para la
## cinta), consultando `GameState.skill_value(id)` / `skill_rank(id)`.

## Nivel máximo del cocinero. Empezando con 1 punto en el nivel 1, da los 450
## puntos que cuesta el catálogo entero.
const MAX_LEVEL := 450
const MAX_RANK := 5

## Curva de experiencia: subir de n a n+1 cuesta
##     XP_BASE + XP_STEP·(n−1) + XP_ACCEL·(n−1)²
##
## EL TÉRMINO CUADRÁTICO ES LO QUE HACE QUE SUBIR CUESTE CADA VEZ MÁS. Fue una
## RECTA (60 + 20·(n−1)) y estaba rota por diseño: un escenario paga 27 más que
## el anterior y un nivel solo pedía 20 más, así que bordando la campaña se
## subía de nivel en TODOS y cada uno de los escenarios, pasara lo que pasara.
## Con el cuadrático, el coste de un nivel crece más deprisa que lo que aporta
## un escenario y el ritmo se frena solo: ya no es automático, y quien quiera
## más nivel repetirá escenarios a por mejor récord (que es justo lo que la
## tarifa contra el récord premia).
##
## Medido sobre los 250 escenarios previstos, bordándolo todo: nivel 2 en el
## escenario 3, 8 en el 10, 16 en el 20 (fin del primer mar), 30 en el 40, 62
## en el 100 y 122 en el 250. Aprobando justo (2★), 13 al acabar el primer mar.
## Antes eran 20 y 304 — o sea, uno por escenario clavado.
const XP_BASE := 100
const XP_STEP := 30
const XP_ACCEL := 1.2

## Tarifa de los escenarios: base = XP_SCENARIO × número del escenario,
## multiplicada por STAR_MULT[estrellas] y ×FIRST_MULT contra el récord.
##
## CALIBRADA CONTRA `chef_rec` (el nivel recomendado del escenario, que es
## ceil(n × 1.09)): bordando TODOS los escenarios hasta el n, el jugador se
## queda justo por debajo de esa recomendación, y lo que le falta lo ponen la
## PESCA y el ARCADE. Con eso, el nivel recomendado no es un número inventado:
## es lo que se tiene jugando bien y usando las dos fuentes.
##
## Estuvo en 15 y era MUCHÍSIMO: tres escenarios bordados dejaban al cocinero
## en el nivel 5 (medido: 68 + 135 + 203 = 406 XP contra los 360 del nivel 5).
## Con 6 esos mismos tres escenarios dan 162 XP, o sea nivel 3, y el escenario
## 15 deja el cocinero en 16 contra los 17 que recomienda.
const XP_SCENARIO := 6
const STAR_MULT := [0.0, 0.5, 1.0, 1.5]
const FIRST_MULT := 3.0

## Los escenarios de JEFE (uno cada 10) pagan ×1,5 (estuvo en el doble y el
## usuario lo bajó: con 20 escenarios en el mar, el doble hacía del jefe un
## salto de golpe). Multiplica la BASE en `GameState.scenario_xp`, así que el
## plus llega igual al estreno, a la repetición y a la mejora de récord. Sobre
## los 250 escenarios previstos son ~44.000 XP extra (+5%). MEDIDO: con él, el
## mar 1 bordado entero deja al cocinero en el nivel 16 clavado.
const XP_BOSS_MULT := 1.5

## PRIMA POR ORO DE MÁS. Cerrar un escenario pasándose del objetivo paga
## experiencia extra, y la tarifa sale del propio escenario: si paga X de
## experiencia y su objetivo son Y monedas, cada moneda vale X/Y. De esa tarifa
## se cobran DOS TERCIOS, así que pasarse mucho renta, pero nunca tanto como
## volver a jugarlo mejor.
##
## Que la tarifa salga del escenario es lo que la hace CRECER con la campaña:
## la base de experiencia sube con el número de escenario, así que la misma
## moneda de más vale cada vez más adelante.
const XP_EXTRA_FRAC := 2.0 / 3.0
## Tope de seguridad: la prima no puede pasar de lo que paga el escenario.
const XP_EXTRA_CAP := 1.0

## El ARCADE paga por oleada superada: ARCADE_WAVE_XP × número de la oleada.
## Baja con la tarifa de los escenarios (estaba en 15, con ellos a 15): dejarlo
## arriba habría hecho del arcade la ÚNICA forma sensata de subir de nivel.
## Aun así paga bien porque cuesta despensa POR OLEADA — el freno es la apuesta.
const ARCADE_WAVE_XP := 6

## La PESCA paga por CAPTURA, y lo que manda es el TAMAÑO del ejemplar: la
## tabla es el suelo por rareza y la talla lo estira hasta ×1,5. Un común
## canijo deja 4 y un legendario de récord, 39. Con el intento a 100 doblones
## es una fuente de goteo, no un atajo: cerrar un escenario del 5 paga 135.
const FISH_XP_TIER := [8, 12, 18, 26]
const FISH_XP_SIZE := 0.6      # lo que vale el ejemplar más canijo de su clase
const FISH_XP_GROW := 0.9      # y lo que suma la talla hasta el récord

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
## CADENCIA DE CADA PREMIO: en qué nivel arranca su serie y con qué ciclo de
## huecos avanza. "Cada 5, 6 y 7 niveles desde el 7" es el ciclo [5, 6, 7]
## empezando en el 7 → 7, 12, 18, 25, 30, 36, 43... El ciclo de tres huecos
## está pensado para que las series NO se sincronicen entre sí: con un hueco
## fijo, dos premios con el mismo período caerían siempre juntos y habría
## niveles cargados y niveles pelados.
##
## El nivel de arranque es la PRIMERA compuerta; la segunda es que el juego ya
## haya EXPLICADO ese premio (ver `GameState.reward_gates`), porque un regalo
## que el jugador no entiende no se vive como un regalo — que es justo por lo
## que estos cuatro estuvieron un tiempo desactivados.
const REWARD_CADENCIA := {
	"bait": { "desde": 7, "huecos": [5, 6, 7] },
	"rice": { "desde": 4, "huecos": [10, 11, 12] },
	"ingots": { "desde": 7, "huecos": [11, 12, 13] },
	"extras": { "desde": 6, "huecos": [6, 7, 8] },
	"ingredients": { "desde": 6, "huecos": [7, 8, 9] },
}


## ¿Le toca a este premio en el nivel `n`? Se resuelve por MÓDULO del período
## (la suma del ciclo), no recorriendo la serie: es O(1) y no depende de lo
## alto que sea el nivel.
static func toca_premio(clave: String, n: int) -> bool:
	var c: Dictionary = REWARD_CADENCIA.get(clave, {})
	if c.is_empty() or n < int(c["desde"]):
		return false
	var huecos: Array = c["huecos"]
	var periodo := 0
	for h in huecos:
		periodo += int(h)
	var pos := (n - int(c["desde"])) % periodo
	var acc := 0
	for h in huecos:
		if pos == acc:
			return true
		acc += int(h)
	return false


## Lo que suelta subir AL nivel `n`. `puertas` dice qué premios están ya
## explicados (clave → bool); lo que falte en el diccionario se da por ABIERTO,
## que es lo que quieren las herramientas y las tablas de diseño.
static func level_reward(n: int, puertas := {}) -> Dictionary:
	var out := { "points": 1 }
	# EL ORO VA EN TODOS LOS NIVELES y es el premio de fondo; los hitos solo lo
	# realzan. Los multiplicadores son suaves a propósito (×1,2 · ×1,5 · ×2):
	# con la escalera anterior (×2 · ×3 · ×4) el nivel corriente se quedaba en
	# nada al lado del hito, y cada nivel ya paga de por sí.
	var oro := 30 + n * 5
	if n % 25 == 0:
		oro = int(round(oro * 2.0))
	elif n % 10 == 0:
		oro = int(round(oro * 1.5))
	elif n % 5 == 0:
		oro = int(round(oro * 1.2))
	out["gold"] = oro

	var abierta := func(clave: String) -> bool:
		return bool(puertas.get(clave, true))
	# El CEBO paga una tirada de pesca entera.
	if toca_premio("bait", n) and abierta.call("bait"):
		out["bait"] = 1
	if toca_premio("rice", n) and abierta.call("rice"):
		out["rice"] = 1
	if toca_premio("ingots", n) and abierta.call("ingots"):
		out["ingots"] = 1
	# Las cantidades de despensa y extras SUBEN MUY DESPACIO (un escalón cada
	# 100 niveles): lo que hace valioso el premio es que caiga, no que crezca.
	if toca_premio("extras", n) and abierta.call("extras"):
		out["extras"] = 2 + n / 100
	if toca_premio("ingredients", n) and abierta.call("ingredients"):
		out["ingredients"] = 3 + n / 100
	return out


## Rótulo y icono de cada clase de premio, para la ventana que los anuncia.
## HOY `level_reward` solo reparte points / gold / bait; el resto se queda
## descrito para cuando el juego explique esas cosas y puedan volver.
const REWARD_LABELS := {
	"points": ["punto de maestría", "puntos de maestría",
		"res://assets/ui/ic_maestrias.png"],
	"gold": ["doblón", "doblones", "res://assets/ui/moneda.png"],
	"bait": ["cebo", "cebos", "res://assets/ui/ic_cebo.png"],
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


## Experiencia de una captura: el suelo lo pone la RAREZA y la TALLA lo estira.
static func fishing_xp(tier: int, size: float) -> int:
	var base := float(FISH_XP_TIER[clampi(tier, 0, FISH_XP_TIER.size() - 1)])
	return maxi(1, int(round(base * (FISH_XP_SIZE
		+ FISH_XP_GROW * clampf(size, 0.0, 1.0)))))


static func reward_icon(clave: String) -> String:
	var d: Array = REWARD_LABELS.get(clave, ["", "", ""])
	return str(d[2])


## Experiencia que cuesta subir del nivel n al n+1.
static func xp_for_next(level: int) -> int:
	var k := float(maxi(level - 1, 0))
	return int(round(XP_BASE + XP_STEP * k + XP_ACCEL * k * k))


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


## XP acumulada al ENTRAR en ese nivel (para la barra de progreso). Con el
## término cuadrático ya no hay fórmula cerrada cómoda, así que se SUMA: son
## como mucho 450 vueltas y solo se llama al pintar una barra.
static func xp_at_level(level: int) -> int:
	var n := clampi(level, 1, MAX_LEVEL)
	var total := 0
	for k in range(1, n):
		total += xp_for_next(k)
	return total
