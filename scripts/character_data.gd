class_name CharacterData
extends RefCounted
## Catálogo de PERSONAJES y su variante por género. Es la ÚNICA tabla que hay
## que tocar para cambiar qué modelo sale: ni el nivel ni el cliente saben
## nombres de archivo.
##
## Cada personaje tiene hasta tres rutas: "m", "f" y "x" (neutro). Una variante
## puede NO existir todavía (los modelos están hechos pero sin riguear, y sin
## esqueleto no se pueden animar): `model()` comprueba el archivo y CAE al
## masculino si falta. Gracias a eso el juego ya funciona con el género
## cableado, y el día que aparezca un `*_rig.glb` nuevo entra solo.
##
## El NEUTRO solo existe para el chef y su ayudante (es el género que elige el
## jugador en Opciones); los clientes se sortean entre masculino y femenino.

const MALE := "m"
const FEMALE := "f"
const NEUTRAL := "x"
## Los tres que puede elegir el jugador, en el orden en que se recorren.
const PLAYER_GENDERS := [MALE, FEMALE, NEUTRAL]
const GENDER_NAMES := {
	MALE: "Masculino", FEMALE: "Femenino", NEUTRAL: "Sin especificar",
}
## Cómo se dirige el juego al jugador cuando no ha puesto nombre.
const GENDER_TITLES := {
	MALE: "Cocinero", FEMALE: "Cocinera", NEUTRAL: "Chef",
}

## personaje -> { genero: ruta del modelo RIGUEADO }
const MODELS := {
	"grumete": {
		MALE: "res://assets/models/grumete_rig.glb",
		FEMALE: "res://assets/models/grumete_fem_rig.glb",
	},
	"pirata": {
		MALE: "res://assets/models/pirata_rig.glb",
		FEMALE: "res://assets/models/pirata_fem_rig.glb",
	},
	"capitan": {
		MALE: "res://assets/models/capitan_rig.glb",
		FEMALE: "res://assets/models/capitan_fem_rig.glb",
	},
	"vip": {
		MALE: "res://assets/models/vip_rig.glb",
		FEMALE: "res://assets/models/vip_fem_rig.glb",
	},
	# Cliente ESPECIAL de un solo puerto: Pablo el Rubio, el capitán de la flota
	# del nivel 5. Come como un capitán, pero con su propio modelo (y su navaja
	# en lugar de mano derecha). No tiene variante femenina: es un personaje
	# concreto, no un tipo de cliente.
	"pablo": {
		MALE: "res://assets/models/pablo_rig.glb",
	},
	"chef": {
		MALE: "res://assets/models/chef_rig.glb",
		FEMALE: "res://assets/models/chef_fem_rig.glb",
		NEUTRAL: "res://assets/models/chef_neutro_rig.glb",
	},
	"ayudante": {
		MALE: "res://assets/models/ayudante_rig.glb",
		FEMALE: "res://assets/models/ayudante_fem_rig.glb",
		NEUTRAL: "res://assets/models/ayudante_rig.glb",
	},
}

## Iconos de cabeza del HUD (tools/head_icons.gd los saca de estos modelos).
const HEADS := {
	"grumete": { MALE: "res://assets/ui/head_E.png", FEMALE: "res://assets/ui/head_E_f.png" },
	"pirata": { MALE: "res://assets/ui/head_A.png", FEMALE: "res://assets/ui/head_A_f.png" },
	"capitan": { MALE: "res://assets/ui/head_G.png", FEMALE: "res://assets/ui/head_G_f.png" },
	"vip": { MALE: "res://assets/ui/head_V.png", FEMALE: "res://assets/ui/head_V_f.png" },
	"pablo": { MALE: "res://assets/ui/head_P.png" },
}

## Tipo de cliente (el de client_mix / TAKE_CHANCES) -> personaje.
const TYPE_TO_WHO := { "E": "grumete", "A": "pirata", "G": "capitan", "V": "vip" }


## Ruta del modelo de ese personaje en ese género, con caída al masculino si
## la variante todavía no está en disco (ver cabecera).
static func model(who: String, gender: String) -> String:
	return _pick(MODELS, who, gender)


## Icono de cabeza para el contador de clientes del HUD.
static func head(who: String, gender: String) -> String:
	return _pick(HEADS, who, gender)


## Personaje que le toca a un tipo de cliente ("E" -> "grumete").
static func who_for_type(type: String) -> String:
	return TYPE_TO_WHO.get(type, "grumete")


## El género contrario: el ayudante siempre es del otro (decisión de diseño).
## Con el jugador NEUTRO no hay contrario, y sortearlo hacía que el ayudante
## cambiara de una partida a otra sin motivo: se fija en FEMENINO.
static func opposite(gender: String) -> String:
	if gender == NEUTRAL:
		return FEMALE
	return MALE if gender == FEMALE else FEMALE


## Género al azar, para los clientes de cada partida.
static func random_gender() -> String:
	return FEMALE if randf() < 0.5 else MALE


static func _pick(table: Dictionary, who: String, gender: String) -> String:
	var entry: Dictionary = table.get(who, {})
	var wanted: String = entry.get(gender, "")
	if wanted != "" and ResourceLoader.exists(wanted):
		return wanted
	return entry.get(MALE, "")
