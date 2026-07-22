extends Node
## Autoload: estado compartido entre pantallas + progreso persistente de la
## campaña (se guarda en disco en user://savegame.json).

const SAVE_PATH := "user://savegame.json"

## --- Estado de la partida en curso (NO se guarda a disco) ---
## Modo: "adventure" (nivel de campaña) o "test" (nivel de prueba libre).
var mode: String = "test"
## Ids de las recetas elegidas en la fase de preparación (máx. 4).
var selected_recipes: Array[String] = []
## Nivel de la campaña que se va a jugar (solo en modo adventure).
var current_port: String = ""

## --- Progreso persistente ---
## Dinero total acumulado por el jugador.
var money: int = 0
## Ids de recetas y potenciadores desbloqueados.
var unlocked_recipes: Array[String] = []
var unlocked_powerups: Array[String] = []
## Mejor resultado en estrellas (0-3) por nivel jugado. port_id -> int.
var level_stars: Dictionary = {}
## Mejor puntuación (dinero ganado) por nivel jugado. port_id -> int.
var level_scores: Dictionary = {}
## Inventario de ingredientes: id -> usos restantes. Un uso = un nivel jugado
## con alguna receta que lleve ese ingrediente (NO se gasta por plato).
var ingredients: Dictionary = {}

## --- Resultado de la última partida (para el panel de resultados) ---
var last_score: float = 0.0
var last_stars: int = 0
var last_money_earned: int = 0


func _ready() -> void:
	load_game()


func reset_run() -> void:
	last_score = 0.0
	last_stars = 0
	last_money_earned = 0


func is_adventure() -> bool:
	return mode == "adventure" and current_port != ""


# --- Desbloqueos -----------------------------------------------------------

## ¿Está desbloqueada esta receta?
func is_recipe_unlocked(id: String) -> bool:
	return id in unlocked_recipes


## Desbloquea una receta si no lo estaba. Devuelve true si era nueva.
func unlock_recipe(id: String) -> bool:
	if id in unlocked_recipes:
		return false
	unlocked_recipes.append(id)
	return true


# --- Inventario de ingredientes --------------------------------------------

func get_ingredient_uses(id: String) -> int:
	return int(ingredients.get(id, 0))


func add_ingredient_uses(id: String, amount: int) -> void:
	ingredients[id] = get_ingredient_uses(id) + amount


## ¿Hay al menos 1 uso de cada ingrediente de la receta?
func has_ingredients_for(recipe_id: String) -> bool:
	for ing in RecipeData.get_ingredients(recipe_id):
		if get_ingredient_uses(ing) <= 0:
			return false
	return true


## Ingredientes DISTINTOS que consumiría jugar un nivel con estas recetas.
func ingredients_for_selection(recipe_ids: Array) -> Array[String]:
	var out: Array[String] = []
	for rid in recipe_ids:
		for ing in RecipeData.get_ingredients(rid):
			if not ing in out:
				out.append(ing)
	return out


## Consume 1 uso de cada ingrediente distinto de la selección (al EMPEZAR un
## nivel de aventura). Devuelve false sin consumir nada si falta alguno.
func consume_ingredients_for_level(recipe_ids: Array) -> bool:
	var needed := ingredients_for_selection(recipe_ids)
	for ing in needed:
		if get_ingredient_uses(ing) <= 0:
			return false
	for ing in needed:
		ingredients[ing] = get_ingredient_uses(ing) - 1
	save_game()
	return true


# --- Progreso de la campaña ------------------------------------------------

## ¿Está desbloqueado este nivel? El primero siempre; el resto, si el nivel
## anterior se ha superado con su objetivo de estrellas.
func is_port_unlocked(port_id: String) -> bool:
	var prev_id := CampaignData.prev_port_id(port_id)
	if prev_id == "":
		return true
	var prev_port := CampaignData.get_port(prev_id)
	return int(level_stars.get(prev_id, 0)) >= int(prev_port.get("goal_stars", 1))


## Guarda la mejor puntuación (dinero ganado) de un nivel si supera la anterior.
func record_level_score(port_id: String, money: int) -> void:
	if money > int(level_scores.get(port_id, 0)):
		level_scores[port_id] = money
		save_game()


## Puntuación máxima (dinero ganado) registrada en un nivel; 0 si no se jugó.
func get_level_score(port_id: String) -> int:
	return int(level_scores.get(port_id, 0))


## Registra el resultado de un nivel y aplica sus recompensas la PRIMERA vez
## que se alcanza su objetivo. Guarda a disco. Devuelve las recetas nuevas
## desbloqueadas (Array de ids).
func complete_port(port_id: String, stars: int) -> Array:
	var newly: Array = []
	var port := CampaignData.get_port(port_id)
	if port.is_empty():
		return newly
	var goal := int(port.get("goal_stars", 1))
	var prev_best: int = int(level_stars.get(port_id, -1))
	# Guarda la mejor puntuación en estrellas.
	if stars > prev_best:
		level_stars[port_id] = stars
	# Recompensas solo al superar el objetivo por primera vez.
	if stars >= goal and prev_best < goal:
		for r in port.get("reward_recipes", []):
			if unlock_recipe(r):
				newly.append(r)
	save_game()
	return newly


# --- Guardado / carga ------------------------------------------------------

func save_game() -> void:
	var data := {
		"version": 3,
		"money": money,
		"unlocked_recipes": unlocked_recipes,
		"unlocked_powerups": unlocked_powerups,
		"level_stars": level_stars,
		"level_scores": level_scores,
		"ingredients": ingredients,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_new_game()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		_new_game()
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_new_game()
		return
	money = int(parsed.get("money", 0))
	unlocked_recipes = _to_string_array(parsed.get("unlocked_recipes", []))
	unlocked_powerups = _to_string_array(parsed.get("unlocked_powerups", []))
	level_stars = {}
	var stars_dict: Dictionary = parsed.get("level_stars", {})
	for k in stars_dict.keys():
		level_stars[str(k)] = int(stars_dict[k])
	level_scores = {}
	var scores_dict: Dictionary = parsed.get("level_scores", {})
	for k in scores_dict.keys():
		level_scores[str(k)] = int(scores_dict[k])
	ingredients = {}
	var ing_dict: Dictionary = parsed.get("ingredients", {})
	for k in ing_dict.keys():
		ingredients[str(k)] = int(ing_dict[k])
	# Garantiza las recetas iniciales aunque el save sea antiguo/parcial.
	for r in CampaignData.INITIAL_RECIPES:
		unlock_recipe(r)


## Borra el progreso y empieza de cero (útil para pruebas).
func reset_progress() -> void:
	_new_game()


func _new_game() -> void:
	money = 0
	unlocked_recipes = []
	unlocked_powerups = []
	level_stars = {}
	level_scores = {}
	ingredients = {}
	for r in CampaignData.INITIAL_RECIPES:
		unlock_recipe(r)
	# Los usos iniciales SOLO en partida nueva (si se diera también al cargar,
	# se rellenarían gratis en cada arranque).
	for ing in CampaignData.INITIAL_INGREDIENTS:
		ingredients[ing] = int(CampaignData.INITIAL_INGREDIENTS[ing])
	save_game()


func _to_string_array(arr: Variant) -> Array[String]:
	var out: Array[String] = []
	if arr is Array:
		for x in arr:
			out.append(str(x))
	return out
