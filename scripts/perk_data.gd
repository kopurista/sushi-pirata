class_name PerkData
## Potenciadores PERMANENTES (distintos de los de `powerup_data.gd`, que salen
## del bote de propinas dentro de un nivel).
##
## Se desbloquean logrando un combo concreto durante una partida, se eligen
## ANTES de empezar el nivel (junto con las recetas) y cada partida jugada
## gasta 1 uso. Los usos se compran con doblones desde el Inventario.

const PERKS: Dictionary = {
	"cocina_veloz": {
		"name": "Cocina veloz",
		"desc": "Todas las recetas tardan la MITAD en volver a estar listas durante toda la partida.",
		"icon": "res://assets/ui/ic_arcade.png",
		"cost": 45,
		"unlock": "Consigue que un mismo cliente se coma 5 platos en una partida.",
	},
	"ayudante": {
		"name": "Ayudante de cocina",
		"desc": "Un ayudante se suma a la cocina y prepara 1 de cada 4 platos por su cuenta, sin que tengas que elaborarlo.",
		"icon": "res://assets/ui/ic_inventario.png",
		"cost": 70,
		"unlock": "Sirve 18 platos en una misma partida.",
	},
}

## Platos que debe comer UN cliente para desbloquear "cocina_veloz".
const UNLOCK_PLATES_ONE_CLIENT := 5
## Platos servidos en una partida para desbloquear "ayudante".
const UNLOCK_PLATES_TOTAL := 18
## Cada cuántos platos servidos por el jugador cocina uno el ayudante.
const HELPER_EVERY := 4


static func get_perk(id: String) -> Dictionary:
	return PERKS.get(id, {})


static func ids() -> Array:
	return PERKS.keys()
