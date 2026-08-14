class_name FishData
## Catálogo del MINIJUEGO DE PESCA: los 40 peces del álbum y la tabla del
## cofre. Aquí solo hay DATOS y sorteos puros; el estado (álbum, monedero,
## coleccionables) vive en GameState, y el juego es `fishing_game.gd`,
## montado SOBRE el propio menú (no hay pantalla aparte).
##
## ECONOMÍA (para no re-litigar): cada intento cuesta FISHING_COST (50)
## doblones, se cobra AL APARECER LA SOMBRA (los relanzamientos del sedal
## dentro del intento son gratis) y saca UNA de dos cosas:
## · Un PEZ (75%): apunta el álbum SIEMPRE. Si corresponde a un ingrediente
##   real de la despensa, da FISH_INGREDIENT_USES (5) usos EN CADA captura
##   (la pesca es la fuente de despensa). Y además, DESDE LA SEGUNDA captura
##   de esa especie (la 2ª incluida), paga las monedas de su rareza: común 20
##   · raro 40 · épico 75 · legendario 100. La PRIMERA captura de un pez sin
##   ingrediente solo da la entrada del álbum, a propósito: el descubrimiento
##   es el premio.
## · Un COFRE (25%): ver CHEST_TABLE. El coleccionable REPETIDO paga
##   DUP_COINS (50): el intento sale gratis, pero no da nada nuevo.
##
## EL SORTEO OCURRE ANTES DE VER LA SOMBRA (`GameState.fishing_roll()`): el
## juego ya sabe qué va a caer (pez o cofre Y el contenido del cofre) y de ahí
## sale la DIFICULTAD de la pelea (tier 0..3): cuanto mejor el premio, más
## fácil se rompe el sedal, más fuerte tira la presa y más fases de velocidad.
##
## RAREZA por pesos POR PEZ (no por rareza entera): común 24 · raro 10 ·
## épico 4 · legendario 1. Con 16/12/8/4 peces por escalón, un legendario
## cualquiera sale 1 de cada ~135 intentos con pez.
##
## Los ICONOS son `assets/ui/fish_<id>.png` (Ludo item-icon, procesados por
## `build_fishing()` de tools/ui2_prep.py); mientras falte el arte,
## `get_icon` cae a la moneda como los coleccionables.

const FISHING_COST := 50
const FISH_INGREDIENT_USES := 5
const DUP_COINS := 50
## Probabilidad de que el intento saque COFRE en vez de pez.
const CHEST_CHANCE := 0.25
## Las monedas de rareza se pagan desde esta captura de la especie (inclusive).
const REPEAT_COINS_FROM := 2

## Rarezas: nombre para la ficha, color de acento, peso de sorteo POR PEZ,
## monedas (desde la 2ª captura) y `tier` de dificultad de la pelea.
const RARITIES: Dictionary = {
	"comun": { "name": "Común", "weight": 24,
		"color": Color(0.55, 0.62, 0.68), "coins": 20, "tier": 0 },
	"raro": { "name": "Raro", "weight": 10,
		"color": Color(0.30, 0.55, 0.85), "coins": 40, "tier": 1 },
	"epico": { "name": "Épico", "weight": 4,
		"color": Color(0.62, 0.35, 0.80), "coins": 75, "tier": 2 },
	"legendario": { "name": "Legendario", "weight": 1,
		"color": Color(0.95, 0.72, 0.20), "coins": 100, "tier": 3 },
}

## Los 40 peces del álbum, ORDENADOS COMO LA VITRINA: por rareza ascendente,
## y dentro de cada rareza los peces-ingrediente al final (son los que el
## jugador busca y así cierran cada escalón). `ingredient` es el id de
## `RecipeData.INGREDIENTS` cuyo premio son FISH_INGREDIENT_USES usos; sin
## él, el pez paga las monedas de su rareza.
const FISH: Array = [
	# --- Comunes (16) --------------------------------------------------------
	{ "id": "sardina", "name": "Sardina", "rarity": "comun" },
	{ "id": "anchoa", "name": "Anchoa", "rarity": "comun" },
	{ "id": "arenque", "name": "Arenque", "rarity": "comun" },
	{ "id": "caballa", "name": "Caballa", "rarity": "comun" },
	{ "id": "jurel", "name": "Jurel", "rarity": "comun" },
	{ "id": "salmonete", "name": "Salmonete", "rarity": "comun" },
	{ "id": "palometa", "name": "Palometa", "rarity": "comun" },
	{ "id": "sargo", "name": "Sargo", "rarity": "comun" },
	{ "id": "lisa", "name": "Lisa", "rarity": "comun" },
	{ "id": "gallo", "name": "Pez gallo", "rarity": "comun" },
	{ "id": "bacaladilla", "name": "Bacaladilla", "rarity": "comun" },
	{ "id": "medusa", "name": "Medusa", "rarity": "comun" },
	{ "id": "mata_wakame", "name": "Mata de wakame", "rarity": "comun",
		"ingredient": "wakame" },
	{ "id": "gamba_real", "name": "Gamba real", "rarity": "comun",
		"ingredient": "gamba" },
	{ "id": "salmon", "name": "Salmón", "rarity": "comun",
		"ingredient": "salmon" },
	{ "id": "atun", "name": "Atún", "rarity": "comun",
		"ingredient": "atun" },
	# --- Raros (12) ----------------------------------------------------------
	{ "id": "dorada", "name": "Dorada", "rarity": "raro" },
	{ "id": "lubina", "name": "Lubina", "rarity": "raro" },
	{ "id": "besugo", "name": "Besugo", "rarity": "raro" },
	{ "id": "lenguado", "name": "Lenguado", "rarity": "raro" },
	{ "id": "rodaballo", "name": "Rodaballo", "rarity": "raro" },
	{ "id": "merluza", "name": "Merluza", "rarity": "raro" },
	{ "id": "rape", "name": "Rape", "rarity": "raro" },
	{ "id": "congrio", "name": "Congrio", "rarity": "raro" },
	{ "id": "morena", "name": "Morena", "rarity": "raro" },
	{ "id": "calamar", "name": "Calamar", "rarity": "raro" },
	{ "id": "pulpo", "name": "Pulpo", "rarity": "raro",
		"ingredient": "pulpo" },
	{ "id": "anguila", "name": "Anguila", "rarity": "raro",
		"ingredient": "unagi" },
	# --- Épicos (8) ----------------------------------------------------------
	{ "id": "pez_espada", "name": "Pez espada", "rarity": "epico" },
	{ "id": "mero", "name": "Mero imperial", "rarity": "epico" },
	{ "id": "corvina", "name": "Corvina real", "rarity": "epico" },
	{ "id": "tiburon", "name": "Tiburón martillo", "rarity": "epico" },
	{ "id": "pez_luna", "name": "Pez luna", "rarity": "epico" },
	{ "id": "mantarraya", "name": "Mantarraya", "rarity": "epico" },
	{ "id": "atun_rojo", "name": "Atún rojo", "rarity": "epico",
		"ingredient": "atun_rojo" },
	{ "id": "fugu", "name": "Pez globo", "rarity": "epico",
		"ingredient": "fugu" },
	# --- Legendarios (4) -----------------------------------------------------
	{ "id": "marlin", "name": "Marlín azul", "rarity": "legendario" },
	{ "id": "pez_remo", "name": "Pez remo", "rarity": "legendario" },
	{ "id": "celacanto", "name": "Celacanto", "rarity": "legendario" },
	{ "id": "koi_dorado", "name": "Koi dorado", "rarity": "legendario" },
]

## Tabla del COFRE (pesos). El sorteo Y la resolución contra el estado viven
## en `GameState.fishing_roll()` / `fishing_apply()`:
## · "coins": 10–100 doblones, con dos franjas — lo normal es la baja
##   (10–50) y solo CHEST_COINS_HIGH_CHANCE de las veces cae la alta (51–100).
## · "collectible": uno al azar de FISHING_COLLECTIBLES, tengas o no:
##   el repetido paga DUP_COINS. Es lo que pide el diseño — pre-filtrar los
##   conseguidos dejaría la regla de las 50 monedas sin usar.
## · "recipe": una receta BLOQUEADA al azar (ni ocultas ni dragon_roll, que
##   es exclusiva del día 7 del bonus diario); sin ninguna pendiente,
##   RECIPE_FALLBACK doblones (mismo criterio que el bonus diario).
## · "triforce": un fragmento del triángulo dorado (POR FIN tiene fuente);
##   con la trifuerza completa, paga DUP_COINS como un repetido.
## (Los USOS DE INGREDIENTE se cayeron del cofre a propósito: la despensa
## solo sale de PESCAR el pez correspondiente.)
const CHEST_TABLE: Array = [
	{ "kind": "coins", "weight": 50 },
	{ "kind": "collectible", "weight": 25 },
	{ "kind": "triforce", "weight": 15 },
	{ "kind": "recipe", "weight": 10 },
]
const CHEST_COINS_LOW := Vector2i(10, 50)
const CHEST_COINS_HIGH := Vector2i(51, 100)
const CHEST_COINS_HIGH_CHANCE := 0.3
const RECIPE_FALLBACK := 200

## Coleccionables que se pueden PESCAR: la botella (su mecánica prometida) y
## lo que uno se imagina dragando el fondo del mar. Lo que huele a tierra
## firme (tricornio, pistola, sartén...) queda para mecánicas futuras.
const FISHING_COLLECTIBLES: Array = [
	"botella", "ancla", "bala_canon", "calavera", "hueso", "pata_palo",
	"tentaculo", "perla_negra", "moneda_azteca", "garfio", "brujula",
	"catalejo", "grog", "reloj_arena", "mascara_zora",
]


static func get_fish(id: String) -> Dictionary:
	for f in FISH:
		if f["id"] == id:
			return f
	return {}


static func total() -> int:
	return FISH.size()


static func rarity_of(id: String) -> Dictionary:
	return RARITIES.get(str(get_fish(id).get("rarity", "comun")), {})


## Tier de dificultad de la pelea de un pez (0..3, por rareza).
static func tier_of(id: String) -> int:
	return int(rarity_of(id).get("tier", 0))


## Texto del premio para la ficha del álbum: usos siempre (si es ingrediente)
## y las monedas de rareza desde la segunda captura.
static func reward_text(id: String) -> String:
	var f := get_fish(id)
	var coins := int(rarity_of(id).get("coins", 0))
	var ing := str(f.get("ingredient", ""))
	if ing != "":
		var data: Dictionary = RecipeData.INGREDIENTS.get(ing, {})
		return "%d usos de %s\n(+%d doblones desde la 2ª)" % [
			FISH_INGREDIENT_USES, str(data.get("name", ing)), coins]
	return "%d doblones desde la 2ª captura" % coins


## Las monedas de un cofre: franja baja casi siempre, alta de vez en cuando.
static func roll_chest_coins() -> int:
	if randf() < CHEST_COINS_HIGH_CHANCE:
		return randi_range(CHEST_COINS_HIGH.x, CHEST_COINS_HIGH.y)
	return randi_range(CHEST_COINS_LOW.x, CHEST_COINS_LOW.y)


## Sorteo de UN pez por los pesos de rareza.
static func roll_fish() -> String:
	var total_w := 0
	for f in FISH:
		total_w += int(RARITIES[f["rarity"]]["weight"])
	var pick := randi() % total_w
	for f in FISH:
		pick -= int(RARITIES[f["rarity"]]["weight"])
		if pick < 0:
			return str(f["id"])
	return str(FISH[0]["id"])


## Sorteo de la CLASE de premio del cofre (la resolución vive en GameState).
static func roll_chest_kind() -> String:
	var total_w := 0
	for e in CHEST_TABLE:
		total_w += int(e["weight"])
	var pick := randi() % total_w
	for e in CHEST_TABLE:
		pick -= int(e["weight"])
		if pick < 0:
			return str(e["kind"])
	return "coins"


static func get_icon(id: String) -> Texture2D:
	var path := "res://assets/ui/fish_%s.png" % id
	if ResourceLoader.exists(path):
		return load(path)
	# Sin arte todavía: la moneda como comodín, igual que los coleccionables.
	return load("res://assets/ui/moneda.png")
