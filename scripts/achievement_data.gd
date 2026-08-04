class_name AchievementData
## Catálogo de LOGROS con tres medallas (bronce, plata, oro).
##
## Aquí solo están los DATOS. El progreso lo calcula `GameState.achievement_value()`
## leyendo el diccionario de estadísticas persistente (`GameState.stats`), porque
## el catálogo es estático y el progreso es estado de la partida guardada.
##
## Para añadir un logro: una entrada en `ACHIEVEMENTS` con su `stat` y sus tres
## metas. Si la estadística no existe todavía hay que subirla desde donde ocurra
## el suceso (`GameState.bump_stat` / `max_stat`); los logros de recetas salen
## solos de `RecipeData.RECIPES`.

## Las tres medallas, de menos a más.
const MEDALS := ["bronce", "plata", "oro"]
const MEDAL_NAMES := ["Bronce", "Plata", "Oro"]
const MEDAL_COLORS := [
	Color(0.80, 0.50, 0.26),
	Color(0.78, 0.80, 0.85),
	Color(1.00, 0.80, 0.25),
]

## Apartados en los que se agrupan en la pantalla de logros.
const GROUPS := ["clientela", "cocina", "fortuna", "travesia", "recetario"]
const GROUP_NAMES := {
	"clientela": "Clientela",
	"cocina": "Cocina",
	"fortuna": "Fortuna",
	"travesia": "Travesía",
	"recetario": "Recetario",
}
## Rótulo de la PESTAÑA: cinco tablones de madera en 720 px dejan ~84 px de
## hueco entre las esquinas doradas, así que ahí van los nombres cortos.
const GROUP_TABS := {
	"clientela": "Barra",
	"cocina": "Cocina",
	"fortuna": "Oro",
	"travesia": "Viaje",
	"recetario": "Platos",
}

## Metas de los logros "prepara N platos de X" (uno por receta no oculta).
const RECIPE_TIERS := [25, 100, 500]

## `stat`: clave de `GameState.stats`, un Array de claves que se SUMAN, o una
## clave "derived:*" que GameState calcula del progreso guardado.
const ACHIEVEMENTS: Array = [
	# --- Clientela -----------------------------------------------------------
	{
		"id": "grumetes", "group": "clientela", "name": "Pan de grumetes",
		"desc": "Da de comer a %d grumetes.",
		"stat": "clients_E", "tiers": [100, 500, 2000],
	},
	{
		"id": "piratas", "group": "clientela", "name": "Rancho de la tripulación",
		"desc": "Da de comer a %d piratas.",
		"stat": "clients_A", "tiers": [100, 500, 2000],
	},
	{
		"id": "capitanes", "group": "clientela", "name": "Mesa de capitanes",
		"desc": "Da de comer a %d capitanes.",
		"stat": "clients_G", "tiers": [100, 500, 2000],
	},
	{
		"id": "clientes", "group": "clientela", "name": "La barra nunca duerme",
		"desc": "Da de comer a %d clientes.",
		"stat": "clients_total", "tiers": [1000, 5000, 20000],
	},
	{
		"id": "cliente_fiel", "group": "clientela", "name": "Cliente de la casa",
		"desc": "Consigue que un mismo cliente coma %d platos seguidos.",
		"stat": "best_client_plates", "tiers": [5, 8, 12],
	},
	{
		"id": "despedidas", "group": "clientela", "name": "La cuenta, por favor",
		"desc": "Prepara %d postres de los que despiden al cliente.",
		"stat": ["dish_mochi", "dish_dorayaki", "dish_taiyaki"],
		"tiers": [25, 150, 600],
	},

	# --- Cocina --------------------------------------------------------------
	{
		"id": "platos", "group": "cocina", "name": "Manos de cocinero",
		"desc": "Prepara %d platos.",
		"stat": "dishes_made", "tiers": [500, 3000, 15000],
	},
	{
		"id": "platos_partida", "group": "cocina", "name": "Turno de locura",
		"desc": "Sirve %d platos en una sola partida.",
		"stat": "best_dishes_run", "tiers": [20, 35, 50],
	},
	{
		"id": "cortes", "group": "cocina", "name": "Pulso de cirujano",
		"desc": "Completa %d cortes lentos sin pasarte de rápido.",
		"stat": "slices_ok", "tiers": [50, 300, 1500],
	},
	{
		"id": "tempura_perfecta", "group": "cocina", "name": "Tres segundos clavados",
		"desc": "Borda %d tempuras en el punto exacto.",
		"stat": "fry_perfect", "tiers": [5, 25, 100],
	},
	{
		"id": "barcos", "group": "cocina", "name": "Armador de barcos",
		"desc": "Sirve %d barcos combinados.",
		"stat": "dish_moriawase", "tiers": [10, 50, 250],
	},
	{
		"id": "combos", "group": "cocina", "name": "Maridajes",
		"desc": "Sirve %d platos combinados.",
		"stat": "dish_udon_tempura", "tiers": [10, 50, 200],
	},
	{
		"id": "extras", "group": "cocina", "name": "Con su jengibre",
		"desc": "Acompaña %d platos con jengibre, wasabi o soja.",
		"stat": "extras_used", "tiers": [50, 250, 1000],
	},
	{
		"id": "sin_desperdicio", "group": "cocina", "name": "Aquí no se tira nada",
		"desc": "Termina %d partidas sin que se desperdicie ni un plato.",
		"stat": "clean_runs", "tiers": [1, 10, 50],
	},

	# --- Fortuna -------------------------------------------------------------
	{
		"id": "dinero_nivel", "group": "fortuna", "name": "Caja del día",
		"desc": "Gana %d doblones en un nivel de la campaña.",
		"stat": "best_money_level", "tiers": [60, 100, 150],
	},
	{
		"id": "dinero_arcade", "group": "fortuna", "name": "Récord de Arcade",
		"desc": "Gana %d doblones en una partida de Arcade.",
		"stat": "best_money_arcade", "tiers": [80, 140, 220],
	},
	{
		"id": "dinero_total", "group": "fortuna", "name": "Cofre del tesoro",
		"desc": "Gana %d doblones en total.",
		"stat": "money_total", "tiers": [1000, 10000, 50000],
	},
	{
		"id": "propinas", "group": "fortuna", "name": "Quédate el cambio",
		"desc": "Reúne %d doblones en propinas.",
		"stat": "tips_total", "tiers": [500, 3000, 15000],
	},
	{
		"id": "gastado", "group": "fortuna", "name": "Cliente del tendero",
		"desc": "Gástate %d doblones en la tienda.",
		"stat": "money_spent", "tiers": [200, 1500, 8000],
	},

	# --- Travesía ------------------------------------------------------------
	{
		"id": "estrellas", "group": "travesia", "name": "Cielo estrellado",
		"desc": "Reúne %d estrellas en la campaña.",
		"stat": "derived:estrellas", "tiers": [9, 18, 27],
	},
	{
		"id": "niveles", "group": "travesia", "name": "Rumbo fijo",
		"desc": "Supera %d puertos de la campaña.",
		"stat": "derived:niveles", "tiers": [3, 6, 9],
	},
	{
		"id": "recetario_completo", "group": "travesia", "name": "Recetario completo",
		"desc": "Aprende %d recetas.",
		"stat": "derived:recetas", "tiers": [4, 8, 12],
	},
	{
		"id": "partidas", "group": "travesia", "name": "Lobo de mar",
		"desc": "Juega %d partidas.",
		"stat": "runs", "tiers": [25, 150, 600],
	},
	{
		"id": "dias", "group": "travesia", "name": "Fiel a la cocina",
		"desc": "Juega en %d días distintos.",
		"stat": "days_played", "tiers": [5, 30, 100],
	},
]


## Catálogo completo: los de arriba MÁS uno por cada receta que el jugador puede
## elaborar (las ocultas —barco, combinados, tempuras fallidas— tienen los suyos
## propios arriba, así que no se repiten aquí).
static var _all: Array = []


static func all() -> Array:
	if not _all.is_empty():
		return _all
	_all = ACHIEVEMENTS.duplicate(true)
	for id in RecipeData.RECIPES:
		var r: Dictionary = RecipeData.RECIPES[id]
		if r.get("hidden", false):
			continue
		_all.append({
			"id": "receta_%s" % id,
			"group": "recetario",
			"name": str(r.get("name", id)),
			"desc": "Prepara %d raciones.",
			"stat": "dish_%s" % id,
			"tiers": RECIPE_TIERS,
			"recipe": id,
		})
	return _all


static func get_achievement(id: String) -> Dictionary:
	for a in all():
		if a["id"] == id:
			return a
	return {}


static func in_group(group: String) -> Array:
	var out: Array = []
	for a in all():
		if a["group"] == group:
			out.append(a)
	return out


## Medalla conseguida con ese progreso: 0 ninguna, 1 bronce, 2 plata, 3 oro.
static func medal_for(a: Dictionary, value: int) -> int:
	var got := 0
	for t in a["tiers"]:
		if value >= int(t):
			got += 1
	return got


## Meta que toca ahora (la del oro si ya está todo conseguido).
static func next_target(a: Dictionary, value: int) -> int:
	for t in a["tiers"]:
		if value < int(t):
			return int(t)
	return int(a["tiers"][a["tiers"].size() - 1])


## Texto del logro con la cantidad de la meta en curso metida en su hueco.
static func describe(a: Dictionary, value: int) -> String:
	return str(a["desc"]) % next_target(a, value)
