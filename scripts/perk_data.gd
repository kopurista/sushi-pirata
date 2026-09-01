class_name PerkData
## Interruptor general de los potenciadores permanentes. Estuvo en `false`
## mientras no estaba decidido su sitio en la progresión; se abrió al entrar el
## BARCO como bonificador, que sin esto sería inalcanzable y desaparecería del
## juego.
const UNLOCKS_ENABLED := true

## BONIFICADORES PERMANENTES (distintos de los potenciadores de
## `powerup_data.gd`, que salen del bote de propinas dentro de un nivel).
##
## Cómo funcionan, de punta a punta:
##  1. Se GANAN haciendo una acción concreta dentro de una partida. La acción es
##     REPETIBLE: cada vez que se cumple, el jugador se lleva OTRO uso (la
##     primera vez, además, desbloquea el bonificador).
##  2. Se ELIGEN antes de zarpar, junto con las recetas, y cada partida jugada
##     gasta 1 uso.
##  3. Se MEJORAN con doblones en la pantalla de Bonificadores del menú. Cinco
##     niveles: el 1 es el de salida y los cuatro siguientes cuestan
##     `UPGRADE_COSTS`. Lo que hace cada nivel lo dice `LEVELS` de cada
##     bonificador, y cada uno tiene su unidad (segundos de descanso del
##     ayudante, tope del multiplicador...).
##
## LA PANTALLA DE BONIFICADORES NO VENDE USOS: los usos se ganan jugando. Lo que
## se compra ahí son NIVELES. Vendía usos hasta el rediseño del 16-8-2026, y
## eso convertía el sistema en "paga y llévate otro turno con ventaja" en vez de
## "juega bien y ganarás la ventaja".

## Lo que cuesta subir a cada nivel (el índice 0 es el salto del 1 al 2).
const UPGRADE_COSTS: Array = [500, 2000, 5000, 10000]
## Nivel máximo de cualquier bonificador.
const MAX_LEVEL := 5

const PERKS: Dictionary = {
	"cocina_veloz": {
		"name": "Cocina veloz",
		"desc": "Los enfriamientos de todas las recetas duran menos durante toda la partida.",
		"icon": "res://assets/ui/perk_veloz.png",
		"unlock": "Consigue que un mismo cliente se coma 5 platos en una partida.",
		# PORCENTAJE al que queda el enfriamiento (60 = un 60% de lo normal).
		# Va en porcentaje y no en fracción porque su rótulo lo enseña así y
		# "%d%%" de 0.6 imprimía "0%". Quien lo aplica divide entre 100.
		"levels": [60, 55, 50, 45, 40],
		"level_text": "Enfriamientos al %d%% de lo normal.",
		"short_text": "Enfriamiento %d%%",
	},
	"ayudante": {
		"name": "Ayudante de cocina",
		"desc": "Alice se suma a la cocina: al empezar una receta puedes pasársela con su botón y la termina ella sola.",
		# SU CARA, no un cofre. El ayudante ES Alice desde que se enrola, y el
		# icono de `ic_inventario` (un arcon) no decia nada de eso.
		"icon": "res://assets/ui/perk_ayudante.png",
		"unlock": "Dale de comer 4 platos a 4 clientes distintos en una partida.",
		# Segundos de descanso entre plato y plato.
		"levels": [60.0, 54.0, 48.0, 40.0, 30.0],
		"level_text": "Descansa %d s entre plato y plato.",
		"short_text": "Descanso %d s",
	},
	# EXPERIENCIA: devuelve —con creces— el 20% de XP que se recortó a toda la
	# campaña (ver SkillData.XP_GANANCIA). Se gana BORDANDO un escenario: no
	# basta con las 3 estrellas, hay que pasarse de largo del listón.
	"experiencia": {
		"name": "Cuaderno de bitácora",
		"desc": "Todo lo que aprendes en una jornada cunde más: la experiencia que deja cada escenario sube.",
		"icon": "res://assets/ui/perk_experiencia.png",
		"unlock": "Cierra un escenario con un 30% más de oro del que piden sus 3 estrellas.",
		# Porcentaje EXTRA de experiencia.
		"levels": [25, 32, 40, 50, 65],
		"level_text": "Ganas un %d%% más de experiencia.",
		"short_text": "Experiencia +%d%%",
	},
	"paladar": {
		"name": "Paladar de capitán",
		"desc": "Sube el TOPE del multiplicador de variedad de cada cliente, así que rinden más por plato y más al despedirlos con postre.",
		"icon": "res://assets/ui/perk_limite.png",
		"unlock": "Consigue que un cliente llegue a x5 de variedad en una partida.",
		# Tope del multiplicador.
		"levels": [6, 7, 8, 9, 10],
		"level_text": "El multiplicador puede llegar a x%d.",
		"short_text": "Multiplicador x%d",
	},
	# El BARCO es el único bonificador que no AÑADE algo nuevo, sino que habilita
	# una mecánica que ya existía: sin él, su botón no aparece ni en los puertos
	# que lo permiten (`boat` en CampaignData). Se pidieron las dos llaves a la
	# vez para no desmontar la campaña: el puerto dice si el barco pinta algo ahí
	# y el bonificador si el jugador se lo ha ganado.
	"barco": {
		"name": "Barco de sushi",
		"desc": "Habilita el barco combinado: junta platos guardados de clases distintas y sal a la cinta con una bandeja que casi nadie deja pasar.",
		"icon": "res://assets/ui/perk_barco.png",
		"unlock": "Ten 3 platos guardados en 2 cajas distintas en una misma partida.",
		# Prima EXTRA (en %) sobre lo que paga el barco por su variedad.
		"levels": [0, 15, 30, 50, 75],
		"level_text": "El barco paga un %d%% más de prima por variedad.",
		"short_text": "Prima +%d%%",
		# EL NIVEL 1 DEL BARCO NO SUMA NADA: lo que da es el barco EN SÍ, que sin
		# este bonificador no existe. Con la plantilla general decía "paga un 0%
		# más de prima", que se lee como un bonificador roto.
		"level_text_1": "Habilita el barco combinado en los puertos que lo permiten.",
		# EL BARCO ESPERA AL MAR 2 (decidido por el usuario). Ningun escenario
		# del mar 1 lo presenta ya, y con `needs_port` puesto eso significa que
		# NO se puede ganar todavia: sin esta linea, `perk_gate_open` daria por
		# abierta la compuerta de cualquier bonificador que no ate puerto y el
		# barco volveria a caer en el 18 sin escena detras.
		"needs_port": true,
	},
}

## Platos que debe comer UN cliente para desbloquear "cocina_veloz".
const UNLOCK_PLATES_ONE_CLIENT := 5
## Clientes DISTINTOS a los que hay que darles `UNLOCK_HELPER_PLATES` platos
## para desbloquear (o volver a ganar) el "ayudante".
const UNLOCK_HELPER_CLIENTS := 4
const UNLOCK_HELPER_PLATES := 4
## Clientes que deben llegar al multiplicador tope para desbloquear "paladar".
## Cuánto hay que pasarse del objetivo de 3 estrellas para llevarse el
## bonificador de experiencia (1.3 = un 30% más).
const UNLOCK_XP_FRAC := 1.3
const UNLOCK_VARIETY_CLIENTS := 1
## Cajas con al menos UNLOCK_BOAT_STACK platos para desbloquear "barco".
const UNLOCK_BOAT_BOXES := 2
const UNLOCK_BOAT_STACK := 3


static func get_perk(id: String) -> Dictionary:
	return PERKS.get(id, {})


static func ids() -> Array:
	return PERKS.keys()


## Valor del efecto en ese nivel (1..MAX_LEVEL). Fuera de rango se acota, así
## que un guardado con un nivel raro no rompe nada.
static func value_at(id: String, level: int) -> float:
	var niveles: Array = get_perk(id).get("levels", [])
	if niveles.is_empty():
		return 0.0
	var i := clampi(level - 1, 0, niveles.size() - 1)
	return float(niveles[i])


## Frase de lo que hace en ese nivel ("Descansa 48 s entre plato y plato").
static func level_text(id: String, level: int) -> String:
	# Un bonificador puede traer una frase PROPIA para su nivel de salida, si en
	# ese nivel su efecto todavía no suma nada (el barco).
	var suyo := str(get_perk(id).get("level_text_%d" % level, ""))
	if suyo != "":
		return suyo
	var plantilla := str(get_perk(id).get("level_text", ""))
	if plantilla == "":
		return ""
	return plantilla % value_at(id, level)


## EL EFECTO EN CORTO ("Enfriamiento 55%"), para el cartel de confirmación:
## ahí lo que se compara son DOS niveles uno al lado del otro, y con la frase
## entera ("Los enfriamientos duran un 55% de lo normal") la comparación se
## perdía dentro de dos párrafos casi iguales.
static func short_text(id: String, level: int) -> String:
	var plantilla := str(get_perk(id).get("short_text", ""))
	if plantilla == "":
		return level_text(id, level)
	return plantilla % value_at(id, level)


## Lo que cuesta pasar de `level` al siguiente (0 = ya está al máximo).
static func upgrade_cost(level: int) -> int:
	if level >= MAX_LEVEL or level < 1:
		return 0
	return int(UPGRADE_COSTS[level - 1])
