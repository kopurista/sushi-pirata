class_name RecipeData
## Datos estáticos de las recetas del prototipo.
##
## Cada receta tiene un nivel (1 sencillo, 2 medio, 3 elaborado) que define
## sus puntos de saciedad, y una secuencia de pasos de elaboración.
## "free_uses": al completar la receta manualmente, las siguientes N
## elaboraciones de esa misma receta son instantáneas (receta dominada).
##
## Tipos de paso:
##  - tap_ingredient: pulsar un ingrediente. { "ingredient": id }
##  - tap_board: pulsar la tabla N veces. { "count": N }
##  - drag_ingredient: arrastrar un ingrediente a la preparación. { "ingredient": id }
##  - swipe_board: deslizar sobre la tabla N veces. { "count": N, "direction": "down"|"up" }
##  - hold_board: mantener pulsada la tabla. { "duration": segundos }

const INGREDIENTS: Dictionary = {
	"arroz": { "name": "Arroz", "short": "Arroz", "color": Color(0.93, 0.92, 0.85) },
	"aguacate": { "name": "Aguacate", "short": "Aguac", "color": Color(0.45, 0.75, 0.35) },
	"salmon": { "name": "Salmón", "short": "Salm", "color": Color(1.0, 0.55, 0.45) },
	"wakame": { "name": "Wakame", "short": "Wak", "color": Color(0.2, 0.5, 0.35) },
	"atun": { "name": "Atún", "short": "Atún", "color": Color(0.85, 0.3, 0.35) },
	"agua": { "name": "Agua", "short": "Agua", "color": Color(0.45, 0.65, 1.0) },
	"miso": { "name": "Pasta miso", "short": "Miso", "color": Color(0.65, 0.5, 0.3) },
	"tofu": { "name": "Tofu", "short": "Tofu", "color": Color(0.97, 0.94, 0.86) },
}

const RECIPES: Dictionary = {
	"maki_aguacate": {
		"label": "MaGua",
		"name": "Maki de aguacate",
		"level": 1,
		"satiety": 1,
		"cooldown": 2.0,
		"price": 7,
		"free_uses": 2,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "aguacate" },
			{ "type": "swipe_board", "count": 2, "direction": "down" },
			{ "type": "tap_board", "count": 3, "cutting": true },
		],
		"stages": ["arroz_bola", "arroz_plano", "plano_aguacate", "rollo_aguacate", "corte_aguacate"],
	},
	"nigiri_salmon": {
		"label": "NiSal",
		"name": "Nigiri de salmón",
		"level": 1,
		"satiety": 1,
		"cooldown": 3.0,
		"price": 8,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "salmon" },
		],
		"stages": ["arroz_bola", "nigiri_base", ""],
	},
	"gunkan_wakame": {
		"label": "GuWak",
		"name": "Gunkan de wakame",
		"level": 1,
		"satiety": 1,
		"cooldown": 4.0,
		"price": 12,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 5 },
			{ "type": "drag_ingredient", "ingredient": "wakame" },
		],
		"stages": ["arroz_bola", "gunkan_base", ""],
	},
	"maki_atun": {
		"label": "MaAtu",
		"name": "Maki de atún",
		"level": 2,
		"satiety": 2,
		"cooldown": 3.0,
		"price": 12,
		"free_uses": 2,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "atun" },
			{ "type": "swipe_board", "count": 3, "direction": "down" },
			{ "type": "tap_board", "count": 3, "cutting": true },
		],
		"stages": ["arroz_bola", "arroz_plano", "plano_atun", "rollo_atun", "corte_atun"],
	},
	"sopa_miso": {
		"label": "SoMis",
		"name": "Sopa de miso",
		"level": 1,
		"satiety": 1,
		"cooldown": 2.0,
		"price": 10,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "agua" },
			{ "type": "hold_board", "duration": 2.0 },
			{ "type": "drag_ingredient", "ingredient": "miso" },
			{ "type": "tap_ingredient", "ingredient": "tofu" },
			{ "type": "tap_board", "count": 2 },
		],
		"stages": ["bol_agua", "bol_agua", "bol_miso", "bol_miso", "bol_miso"],
	},
	"futomaki_salmon": {
		"label": "FuSal",
		"name": "Futomaki de salmón",
		"level": 3,
		"satiety": 3,
		"cooldown": 5.0,
		"price": 20,
		"free_uses": 2,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 5 },
			{ "type": "drag_ingredient", "ingredient": "salmon" },
			{ "type": "drag_ingredient", "ingredient": "wakame" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "swipe_board", "count": 3, "direction": "up" },
			{ "type": "tap_board", "count": 5, "cutting": true },
		],
		"stages": ["arroz_bola", "arroz_plano", "plano_salmon", "plano_futomaki", "plano_futomaki", "rollo_futomaki", "corte_futomaki"],
	},
}


## Textura de una etapa de elaboración, o null si no existe.
static func get_stage_texture(stage_id: String) -> Texture2D:
	if stage_id == "":
		return null
	var path := "res://assets/stages/%s.png" % stage_id
	return load(path) if ResourceLoader.exists(path) else null


## Textura del plato terminado.
static func get_dish_texture(recipe_id: String) -> Texture2D:
	var path := "res://assets/dishes/%s.webp" % recipe_id
	return load(path) if ResourceLoader.exists(path) else null


static func get_recipe(id: String) -> Dictionary:
	return RECIPES.get(id, {})


static func get_ingredient(id: String) -> Dictionary:
	return INGREDIENTS.get(id, {})


## Ingredientes únicos que usa una receta, en orden de aparición.
static func get_recipe_ingredients(id: String) -> Array[String]:
	var result: Array[String] = []
	for step in get_recipe(id).get("steps", []):
		var ing: String = step.get("ingredient", "")
		if ing != "" and not ing in result:
			result.append(ing)
	return result
