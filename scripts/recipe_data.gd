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
##  - stir_board: remover en círculos sin soltar sobre la etapa. { "count": vueltas }
##  - slice_board: corte LENTO de izquierda a derecha por todo el ancho de la
##    tabla; la barra se llena según el avance horizontal del cursor. Debe
##    tardar AL MENOS "duration" s en recorrerlo; si va más rápido aparece
##    "¡Más lento!" y hay que repetir. { "count": N, "duration": s }
##  - drag_stage: aparece un utensilio ("prop", sprite de assets/stages) a la
##    derecha de la tabla y hay que arrastrar el sprite de etapa hasta él. { "prop": id }
##
## "vegetarian": true marca las recetas aptas para clientes vegetarianos.
## "patience_mult": escala cuánta paciencia recarga el plato al comerlo
##   (client.gd::PATIENCE_FOOD). 1.0 por defecto; makis/futomaki 0.8 (recargan
##   x0.2 menos), sopa de miso 1.2, gunkan de tartar 1.1.
## "eat_mult": escala el tiempo que tarda el cliente en comer el plato
##   (client.gd::EAT_TIMES). 1.0 por defecto; sopa de miso tarda más (1.5).
## "tip_chance_bonus": suma a la probabilidad de propina del cliente la 1ª vez
##   que come este plato; cada repetición del MISMO plato suma la MITAD que la
##   anterior (tartar 3% > 1.5% > 0.75%...). Se aplica en client.gd::_roll_tip.

## "cost": precio en doblones de 1 USO en la tienda (un uso = un nivel jugado
## con recetas que lleven ese ingrediente). El arroz es infinito (cost 0, no se
## vende ni consume usos).
const INGREDIENTS: Dictionary = {
	"arroz": { "name": "Arroz", "short": "Arroz", "color": Color(0.93, 0.92, 0.85), "cost": 0 },
	"aguacate": { "name": "Aguacate", "short": "Aguac", "color": Color(0.45, 0.75, 0.35), "cost": 15 },
	"salmon": { "name": "Salmón", "short": "Salm", "color": Color(1.0, 0.55, 0.45), "cost": 23 },
	"wakame": { "name": "Wakame", "short": "Wak", "color": Color(0.2, 0.5, 0.35), "cost": 15 },
	"atun": { "name": "Atún", "short": "Atún", "color": Color(0.85, 0.3, 0.35), "cost": 23 },
	"agua": { "name": "Agua", "short": "Agua", "color": Color(0.45, 0.65, 1.0), "cost": 3 },
	"miso": { "name": "Pasta miso", "short": "Miso", "color": Color(0.65, 0.5, 0.3), "cost": 8 },
	"tofu": { "name": "Tofu", "short": "Tofu", "color": Color(0.97, 0.94, 0.86), "cost": 15 },
	"huevo": { "name": "Huevo", "short": "Huevo", "color": Color(0.9, 0.78, 0.55), "cost": 3 },
	"gamba": { "name": "Gamba", "short": "Gamba", "color": Color(1.0, 0.6, 0.45), "cost": 8 },
	"tofu_frito": { "name": "Tofu frito", "short": "Inari", "color": Color(0.85, 0.65, 0.35), "cost": 5 },
	"atun_rojo": { "name": "Atún rojo", "short": "AtRojo", "color": Color(0.55, 0.12, 0.18), "cost": 30 },
	"nori": { "name": "Alga nori", "short": "Nori", "color": Color(0.12, 0.22, 0.14), "cost": 8 },
	"pepino": { "name": "Pepino", "short": "Pepino", "color": Color(0.35, 0.62, 0.28), "cost": 8 },
}

const RECIPES: Dictionary = {
	"maki_aguacate": {
		"label": "MaGua",
		"name": "Maki de aguacate",
		"level": 1,
		"satiety": 1,
		"cooldown": 3.0,
		"price": 2,
		"vegetarian": true,
		"patience_mult": 0.8,
		"free_uses": 2,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "aguacate" },
			{ "type": "swipe_board", "count": 2, "direction": "down" },
			{ "type": "tap_board", "count": 2, "cutting": true },
		],
		"stages": ["arroz_bola", "arroz_plano", "plano_aguacate", "rollo_aguacate", "corte_aguacate"],
	},
	"nigiri_salmon": {
		"label": "NiSal",
		"name": "Nigiri de salmón",
		"level": 1,
		"satiety": 1,
		"cooldown": 3.0,
		"price": 3,
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
		"cooldown": 3.5,
		"price": 3,
		"vegetarian": true,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 4 },
			{ "type": "drag_ingredient", "ingredient": "wakame" },
		],
		"stages": ["arroz_bola", "gunkan_base", ""],
	},
	"maki_atun": {
		"label": "MaAtu",
		"name": "Maki de atún",
		"level": 2,
		"satiety": 2,
		"cooldown": 4.5,
		"price": 5,
		"patience_mult": 0.8,
		"free_uses": 2,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "nori" },
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 4 },
			{ "type": "drag_ingredient", "ingredient": "atun" },
			{ "type": "swipe_board", "count": 3, "direction": "down" },
			{ "type": "tap_board", "count": 3, "cutting": true },
		],
		"stages": ["nori_tabla", "nori_arroz_bola", "nori_arroz", "nori_atun", "rollo_atun", ""],
	},
	"sopa_miso": {
		"label": "SoMis",
		"name": "Sopa de miso",
		"level": 1,
		"satiety": 1,
		"cooldown": 4.0,
		"price": 4,
		"vegetarian": true,
		"patience_mult": 1.2,
		"eat_mult": 1.5,
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
		"cooldown": 6.5,
		"price": 10,
		"patience_mult": 0.8,
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
	"nigiri_atun": {
		"label": "NiAtu",
		"name": "Nigiri de atún",
		"level": 2,
		"satiety": 2,
		"cooldown": 5.0,
		"price": 6,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 4 },
			{ "type": "drag_ingredient", "ingredient": "atun" },
		],
		"stages": ["arroz_bola", "nigiri_base", ""],
	},
	"nigiri_inari": {
		"label": "NiIna",
		"name": "Nigiri de tofu frito",
		"level": 2,
		"satiety": 2,
		"cooldown": 5.0,
		"price": 6,
		"vegetarian": true,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 4 },
			{ "type": "drag_ingredient", "ingredient": "tofu_frito" },
		],
		"stages": ["arroz_bola", "nigiri_base", ""],
	},
	"sashimi_tamago": {
		"label": "SaTam",
		"name": "Sashimi de tortilla tamago",
		"level": 2,
		"satiety": 2,
		"cooldown": 5.5,
		"price": 6,
		"free_uses": 4,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "huevo" },
			{ "type": "tap_board", "count": 2 },
			{ "type": "stir_board", "count": 2 },
			{ "type": "drag_stage", "prop": "sarten" },
			{ "type": "hold_board", "duration": 1.0 },
			{ "type": "tap_board", "count": 6, "cutting": true },
		],
		"stages": ["cuenco_huevo", "cuenco_huevo", "cuenco_batido", "sarten_tamago", "tamago_entero", ""],
	},
	"sashimi_atun_rojo": {
		"label": "SaAtu",
		"name": "Sashimi de atún rojo",
		"level": 3,
		"satiety": 3,
		"cooldown": 7.5,
		"price": 11,
		"tip_chance_bonus": 0.04,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "atun_rojo" },
			{ "type": "slice_board", "count": 2, "duration": 0.7, "direction": "right",
				"cut_stage": "corte_atun_rojo" },
		],
		"stages": ["bloque_atun_rojo", ""],
	},
	"nigiri_ebi": {
		"label": "NiEbi",
		"name": "Nigiri de gamba ebi",
		"level": 3,
		"satiety": 3,
		"cooldown": 7.0,
		"price": 11,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 5 },
			{ "type": "tap_ingredient", "ingredient": "gamba" },
			{ "type": "swipe_board", "count": 1, "direction": "down" },
			{ "type": "drag_stage", "prop": "nigiri_base" },
		],
		"stages": ["arroz_bola", "nigiri_base", "gamba_tabla", "gamba_abierta", ""],
	},
	"gunkan_tartar": {
		"label": "GuTar",
		"name": "Tartar de salmón y pepino",
		"level": 2,
		"satiety": 2,
		"cooldown": 5.0,
		"price": 7,
		"free_uses": 1,
		"tip_chance_bonus": 0.03,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "pepino" },
			{ "type": "tap_board", "count": 4, "cutting": true },
			{ "type": "tap_ingredient", "ingredient": "salmon" },
			{ "type": "tap_board", "count": 4, "cutting": true },
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_stage", "prop": "gunkan_base" },
		],
		"stages": ["pepino_tabla", "pepino_cubos", "salmon_pepino", "tartar_mont", "arroz_bola", "tartar_mont", ""],
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


## Ingredientes DISTINTOS que consume una receta (según sus pasos), excluyendo
## el arroz, que es infinito. Son los que gastan usos del inventario por nivel.
static func get_ingredients(recipe_id: String) -> Array[String]:
	var out: Array[String] = []
	for step in get_recipe(recipe_id).get("steps", []):
		var ing: String = step.get("ingredient", "")
		if ing != "" and ing != "arroz" and not ing in out:
			out.append(ing)
	return out


## Icono de un ingrediente, o null si no existe.
static func get_ingredient_texture(ingredient_id: String) -> Texture2D:
	var path := "res://assets/ingredients/%s.png" % ingredient_id
	return load(path) if ResourceLoader.exists(path) else null


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
