class_name PerkData
## Interruptor general de los potenciadores permanentes. Estuvo en `false`
## mientras no estaba decidido su sitio en la progresión; se abrió al entrar el
## BARCO como bonificador, que sin esto sería inalcanzable y desaparecería del
## juego.
const UNLOCKS_ENABLED := true

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
		"desc": "Un ayudante se suma a la cocina: al empezar una receta puedes pasársela con su botón y la termina él solo. Descansa 30 s entre plato y plato.",
		"icon": "res://assets/ui/ic_inventario.png",
		"cost": 70,
		"unlock": "Sirve 18 platos en una misma partida.",
	},
	"paladar": {
		"name": "Paladar de capitán",
		"desc": "El multiplicador de variedad de cada cliente puede llegar a x10 en vez de x5, así que rinden el doble por plato y el doble al despedirlos con postre.",
		"icon": "res://assets/ui/perk_limite.png",
		"cost": 90,
		"unlock": "Consigue que 4 clientes lleguen a x5 de variedad en una misma partida.",
	},
	# El BARCO es el único bonificador que no AÑADE algo nuevo, sino que habilita
	# una mecánica que ya existía: sin él, su botón no aparece ni en los puertos
	# que lo permiten (`boat` en CampaignData). Se pidieron las dos llaves a la
	# vez para no desmontar la campaña: el puerto dice si el barco pinta algo ahí
	# y el bonificador si el jugador se lo ha ganado.
	"barco": {
		"name": "Barco de sushi",
		"desc": "Habilita el barco combinado: junta cuatro platos guardados de clases distintas y sal a la cinta con una bandeja que casi nadie deja pasar.",
		"icon": "res://assets/ui/perk_barco.png",
		"cost": 60,
		"unlock": "Ten 3 platos guardados en 2 cajas distintas en una misma partida.",
	},
}

## Platos que debe comer UN cliente para desbloquear "cocina_veloz".
const UNLOCK_PLATES_ONE_CLIENT := 5
## Platos servidos en una partida para desbloquear "ayudante".
const UNLOCK_PLATES_TOTAL := 18
## Clientes que deben llegar al multiplicador tope para desbloquear "paladar".
const UNLOCK_VARIETY_CLIENTS := 4
## Cajas con al menos UNLOCK_BOAT_STACK platos para desbloquear "barco".
const UNLOCK_BOAT_BOXES := 2
const UNLOCK_BOAT_STACK := 3


static func get_perk(id: String) -> Dictionary:
	return PERKS.get(id, {})


static func ids() -> Array:
	return PERKS.keys()
