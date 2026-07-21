extends Node
## Autoload: estado compartido entre la pantalla de preparación y el nivel.

## Ids de las recetas elegidas en la fase de preparación (máx. 4).
var selected_recipes: Array[String] = []

## Dinero total acumulado por el jugador (persiste entre partidas de la sesión).
var money: int = 0

## Resultado de la última partida (para el panel de resultados).
var last_score: float = 0.0
var last_stars: int = 0
var last_money_earned: int = 0


func reset_run() -> void:
	last_score = 0.0
	last_stars = 0
	last_money_earned = 0
