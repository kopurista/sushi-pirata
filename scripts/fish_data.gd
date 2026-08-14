class_name FishData
## Catálogo del MINIJUEGO DE PESCA: los peces del álbum y la tabla del cofre.
## Aquí solo hay DATOS y sorteos puros; el estado (álbum, récords, monedero,
## coleccionables) vive en GameState, y el juego es `fishing_game.gd`,
## montado SOBRE el propio menú (no hay pantalla aparte).
##
## ECONOMÍA (para no re-litigar): cada intento cuesta FISHING_COST (50)
## doblones, se cobra AL APARECER LA SOMBRA (los relanzamientos del sedal
## dentro del intento son gratis) y saca UNA de dos cosas:
## · Un PEZ (75%): cada captura trae un TAMAÑO al azar (size 0..1, sorteado
##   ANTES de ver la sombra) que decide sus doblones dentro de la horquilla
##   de su rareza — común 40–70 · raro 70–100 · épico 100–150 · legendario
##   150–250 — y el largo en cm de la ficha. El álbum guarda el RÉCORD de
##   tamaño por especie (GameState.fish_best) y la ficha enseña el mayor
##   pescado. Las monedas se pagan DESDE LA SEGUNDA captura de la especie
##   (la 1ª de un pez sin ingrediente es solo el descubrimiento). Los
##   peces-ingrediente dan además sus usos de despensa EN CADA captura
##   (`uses_of`: 5, y 10 el salmón real — la pesca es LA fuente de despensa).
## · Un COFRE (25%): ver CHEST_TABLE. El coleccionable REPETIDO paga
##   DUP_COINS (50).
## · El PEZ LAPA no pica nunca (`no_catch`): con LAPA_CHANCE puede venir
##   PEGADO al pez pescado y entonces se cobra el valor del pez MÁS el de la
##   lapa (que también entra al álbum con su tamaño).
##
## EL SORTEO OCURRE ANTES DE VER LA SOMBRA (`GameState.fishing_roll()`): el
## juego ya sabe qué va a caer (pez, tamaño, lapa o cofre y su contenido) y
## de ahí salen la DIFICULTAD de la pelea (tier 0..3) y el tamaño de la
## sombra. En la pelea, la FUERZA del pez escala además con su tamaño y con
## la distancia al barco (ver fishing_game).
##
## RAREZA por pesos POR PEZ: común 24 · raro 10 · épico 4 · legendario 1.
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
## Probabilidad de que el pez pescado traiga un PEZ LAPA pegado.
const LAPA_CHANCE := 0.07

## Rarezas: nombre para la ficha, color de acento, peso de sorteo POR PEZ,
## horquilla de DOBLONES por tamaño, horquilla de LARGO (cm) para la ficha y
## `tier` de dificultad de la pelea.
const RARITIES: Dictionary = {
	"comun": { "name": "Común", "weight": 24,
		"color": Color(0.55, 0.62, 0.68), "tier": 0,
		"coins": Vector2i(40, 70), "len": Vector2i(15, 40) },
	"raro": { "name": "Raro", "weight": 10,
		"color": Color(0.30, 0.55, 0.85), "tier": 1,
		"coins": Vector2i(70, 100), "len": Vector2i(30, 80) },
	"epico": { "name": "Épico", "weight": 4,
		"color": Color(0.62, 0.35, 0.80), "tier": 2,
		"coins": Vector2i(100, 150), "len": Vector2i(60, 150) },
	"legendario": { "name": "Legendario", "weight": 1,
		"color": Color(0.95, 0.72, 0.20), "tier": 3,
		"coins": Vector2i(150, 250), "len": Vector2i(100, 300) },
}

## Los peces del álbum, ORDENADOS COMO LA VITRINA: por rareza ascendente y,
## dentro de cada rareza, los peces-ingrediente al final (cierran su escalón).
## Campos opcionales: `ingredient` (id de despensa: da `uses` o 5 usos por
## captura), `uses` (usos que entrega, si no 5), `len` (horquilla de cm
## propia, si la de su rareza no le hace justicia), `no_catch` (no pica el
## anzuelo: solo aparece pegado, el pez lapa) y `desc` (renglón de la ficha).
const FISH: Array = [
	# --- Comunes (26) --------------------------------------------------------
	{ "id": "sardina", "name": "Sardina", "rarity": "comun" },
	{ "id": "anchoa", "name": "Anchoa", "rarity": "comun" },
	{ "id": "boqueron", "name": "Boquerón", "rarity": "comun" },
	{ "id": "arenque", "name": "Arenque", "rarity": "comun" },
	{ "id": "caballa", "name": "Caballa", "rarity": "comun" },
	{ "id": "jurel", "name": "Jurel", "rarity": "comun" },
	{ "id": "salmonete", "name": "Salmonete", "rarity": "comun" },
	{ "id": "palometa", "name": "Palometa", "rarity": "comun" },
	{ "id": "sargo", "name": "Sargo", "rarity": "comun" },
	{ "id": "lisa", "name": "Lisa", "rarity": "comun" },
	{ "id": "gallo", "name": "Pez gallo", "rarity": "comun" },
	{ "id": "bacaladilla", "name": "Bacaladilla", "rarity": "comun" },
	{ "id": "ayu", "name": "Ayu", "rarity": "comun" },
	{ "id": "barbo", "name": "Barbo", "rarity": "comun" },
	{ "id": "pejesapo", "name": "Pejesapo", "rarity": "comun" },
	{ "id": "remora", "name": "Rémora", "rarity": "comun" },
	{ "id": "pez_cirujano", "name": "Pez cirujano", "rarity": "comun" },
	{ "id": "pez_mariposa", "name": "Pez mariposa", "rarity": "comun" },
	{ "id": "pez_payaso", "name": "Pez payaso", "rarity": "comun" },
	{ "id": "medusa", "name": "Medusa", "rarity": "comun" },
	{ "id": "lata_basura", "name": "Lata de basura", "rarity": "comun",
		"len": Vector2i(25, 40),
		"desc": "El mar devuelve lo que se le tira." },
	{ "id": "bota", "name": "Bota", "rarity": "comun",
		"len": Vector2i(20, 35),
		"desc": "A juego con la otra, si algún día pica." },
	{ "id": "mata_wakame", "name": "Mata de wakame", "rarity": "comun",
		"ingredient": "wakame" },
	{ "id": "gamba_real", "name": "Gamba real", "rarity": "comun",
		"ingredient": "gamba" },
	{ "id": "salmon", "name": "Salmón", "rarity": "comun",
		"ingredient": "salmon" },
	{ "id": "atun", "name": "Atún", "rarity": "comun",
		"ingredient": "atun" },
	# --- Raros (29) ----------------------------------------------------------
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
	{ "id": "pirana", "name": "Piraña", "rarity": "raro" },
	{ "id": "carpa_koi", "name": "Carpa koi", "rarity": "raro" },
	{ "id": "lampuga", "name": "Lampuga", "rarity": "raro" },
	{ "id": "pargo_rojo", "name": "Pargo rojo", "rarity": "raro" },
	{ "id": "pez_volador", "name": "Pez volador", "rarity": "raro" },
	{ "id": "pez_balon", "name": "Pez balón", "rarity": "raro" },
	{ "id": "pez_erizo", "name": "Pez erizo", "rarity": "raro" },
	{ "id": "caballito_mar", "name": "Caballito de mar", "rarity": "raro",
		"len": Vector2i(8, 18) },
	{ "id": "bogavante", "name": "Bogavante", "rarity": "raro" },
	{ "id": "tortuga", "name": "Tortuga", "rarity": "raro" },
	{ "id": "amia_calva", "name": "Amia calva", "rarity": "raro" },
	{ "id": "barbo_oloroso", "name": "Barbo oloroso", "rarity": "raro",
		"desc": "Rojo y apestoso. Huele a otra aventura." },
	{ "id": "pez_rana_pintado", "name": "Pez rana pintado", "rarity": "raro" },
	{ "id": "pez_ojo_celestial", "name": "Pez ojo celestial", "rarity": "raro" },
	{ "id": "jikin", "name": "Jikin", "rarity": "raro" },
	{ "id": "oranda", "name": "Oranda", "rarity": "raro",
		"desc": "La boina roja no se la quita ni en el agua." },
	{ "id": "pez_lapa", "name": "Pez lapa", "rarity": "raro",
		"no_catch": true, "len": Vector2i(10, 25),
		"desc": "No pica nunca: aparece PEGADO a otros peces,\ny entonces su valor se suma al de la captura." },
	{ "id": "pulpo", "name": "Pulpo", "rarity": "raro",
		"ingredient": "pulpo" },
	{ "id": "anguila", "name": "Anguila", "rarity": "raro",
		"ingredient": "unagi" },
	# --- Épicos (17) ---------------------------------------------------------
	{ "id": "pez_espada", "name": "Pez espada", "rarity": "epico" },
	{ "id": "mero", "name": "Mero imperial", "rarity": "epico" },
	{ "id": "corvina", "name": "Corvina real", "rarity": "epico" },
	{ "id": "tiburon", "name": "Tiburón martillo", "rarity": "epico" },
	{ "id": "pez_luna", "name": "Pez luna", "rarity": "epico" },
	{ "id": "mantarraya", "name": "Mantarraya", "rarity": "epico" },
	{ "id": "pez_leon", "name": "Pez león", "rarity": "epico" },
	{ "id": "pez_napoleon", "name": "Pez napoleón", "rarity": "epico" },
	{ "id": "pez_sierra", "name": "Pez sierra", "rarity": "epico" },
	{ "id": "pez_cabeza_transparente", "name": "Pez cabeza transparente",
		"rarity": "epico" },
	{ "id": "arowana", "name": "Arowana", "rarity": "epico" },
	{ "id": "siluro", "name": "Siluro", "rarity": "epico" },
	{ "id": "bata_bata", "name": "Bata-Bata", "rarity": "epico",
		"desc": "Una piraña de hojalata. Alguien la fabricó\ny el mar se la quedó." },
	{ "id": "froggy", "name": "Froggy", "rarity": "epico",
		"len": Vector2i(20, 40),
		"desc": "Una rana con una cola larguísima.\nParece buscar a alguien." },
	{ "id": "atun_rojo", "name": "Atún rojo", "rarity": "epico",
		"ingredient": "atun_rojo" },
	{ "id": "fugu", "name": "Pez globo", "rarity": "epico",
		"ingredient": "fugu" },
	{ "id": "salmon_real", "name": "Salmón real", "rarity": "epico",
		"ingredient": "salmon", "uses": 10, "len": Vector2i(90, 160),
		"desc": "El doble de grande que un salmón,\ny el doble de salmón en la despensa." },
	# --- Legendarios (6) -----------------------------------------------------
	{ "id": "marlin", "name": "Marlín azul", "rarity": "legendario" },
	{ "id": "pez_remo", "name": "Pez remo", "rarity": "legendario" },
	{ "id": "celacanto", "name": "Celacanto", "rarity": "legendario" },
	{ "id": "tiburon_ballena", "name": "Tiburón ballena", "rarity": "legendario",
		"len": Vector2i(500, 1000) },
	{ "id": "caballito_dorado", "name": "Caballito de mar dorado",
		"rarity": "legendario", "len": Vector2i(10, 25) },
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


## Doblones que paga ESTA captura según su tamaño (size 0..1 dentro de la
## horquilla de su rareza).
static func coins_for(id: String, size: float) -> int:
	var c: Vector2i = rarity_of(id).get("coins", Vector2i.ZERO)
	return int(roundf(lerpf(float(c.x), float(c.y), clampf(size, 0.0, 1.0))))


## Largo en cm para la ficha y el cartel (horquilla propia del pez o la de su
## rareza).
static func length_cm(id: String, size: float) -> int:
	var l: Vector2i = get_fish(id).get("len",
		rarity_of(id).get("len", Vector2i(10, 50)))
	return int(roundf(lerpf(float(l.x), float(l.y), clampf(size, 0.0, 1.0))))


## Usos de despensa que entrega un pez-ingrediente (el salmón real da 10).
static func uses_of(id: String) -> int:
	return int(get_fish(id).get("uses", FISH_INGREDIENT_USES))


## Texto del premio para la ficha del álbum: usos siempre (si es ingrediente)
## y las monedas por tamaño desde la segunda captura.
static func reward_text(id: String) -> String:
	var f := get_fish(id)
	var c: Vector2i = rarity_of(id).get("coins", Vector2i.ZERO)
	var ing := str(f.get("ingredient", ""))
	if ing != "":
		var data: Dictionary = RecipeData.INGREDIENTS.get(ing, {})
		return "%d usos de %s\n(+%d–%d doblones desde la 2ª)" % [
			uses_of(id), str(data.get("name", ing)), c.x, c.y]
	if f.get("no_catch", false):
		return "%d–%d doblones al venir pegado" % [c.x, c.y]
	return "%d–%d doblones según tamaño\n(desde la 2ª captura)" % [c.x, c.y]


## Las monedas de un cofre: franja baja casi siempre, alta de vez en cuando.
static func roll_chest_coins() -> int:
	if randf() < CHEST_COINS_HIGH_CHANCE:
		return randi_range(CHEST_COINS_HIGH.x, CHEST_COINS_HIGH.y)
	return randi_range(CHEST_COINS_LOW.x, CHEST_COINS_LOW.y)


## Sorteo de UN pez por los pesos de rareza. El pez lapa (`no_catch`) no
## entra: solo aparece pegado a otros.
static func roll_fish() -> String:
	var total_w := 0
	for f in FISH:
		if f.get("no_catch", false):
			continue
		total_w += int(RARITIES[f["rarity"]]["weight"])
	var pick := randi() % total_w
	for f in FISH:
		if f.get("no_catch", false):
			continue
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
