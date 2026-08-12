class_name TitleData
extends RefCounted
## TÍTULOS del jugador: el renglón que va DEBAJO del nombre en el cartel de
## recompensa ("el diestro", "la zurda", y más adelante "el rubio", "el chef"...).
##
## Cada título trae su forma en masculino y en femenino, porque el cartel se lee
## como una frase ("Kopu, el zurdo") y un texto único quedaría mal en uno de los
## dos. `text()` elige por el género del jugador.
##
## `MANO` es el título POR DEFECTO y el único que existe de salida. Es especial:
## su texto no está escrito aquí sino que sale de la mano con la que el jugador
## empuña el cuchillo, así que cambia solo al cambiarla en el perfil. Los demás
## son fijos y hay que DESBLOCKEARLOS (`GameState.unlocked_titles`); de momento
## ninguno se gana en ningún sitio, están puestos para que el selector del
## perfil tenga catálogo el día que se enganchen a un logro o a una recompensa.

## El título de salida, calculado a partir de la mano dominante.
const MANO := "mano"

## id -> { m, f, how }. `how` es cómo se consigue, para enseñarlo bloqueado.
const TITLES := {
	MANO: {
		"m": "el diestro", "f": "la diestra",
		"how": "Se ajusta solo con tu mano dominante",
	},
	"chef": {
		"m": "el chef", "f": "la chef",
		"how": "Todavía no se puede conseguir",
	},
	"rubio": {
		"m": "el rubio", "f": "la rubia",
		"how": "Todavía no se puede conseguir",
	},
}

## Las dos formas del título de la mano, por mano y género.
const MANO_TEXT := {
	"L": { "m": "el zurdo", "f": "la zurda" },
	"R": { "m": "el diestro", "f": "la diestra" },
}


static func exists(id: String) -> bool:
	return TITLES.has(id)


## El renglón que se pinta en el cartel.
static func text(id: String, gender: String, hand: String) -> String:
	if id == MANO:
		var par: Dictionary = MANO_TEXT.get(hand, MANO_TEXT["R"])
		return str(par.get(gender, par["m"]))
	var t: Dictionary = TITLES.get(id, TITLES[MANO])
	return str(t.get(gender, t.get("m", "")))


## Cómo se consigue, para la ficha bloqueada del perfil.
static func how(id: String) -> String:
	return str((TITLES.get(id, {}) as Dictionary).get("how", ""))
