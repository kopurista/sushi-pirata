class_name CharacterData
extends RefCounted
## Catálogo de PERSONAJES y su variante por género. Es la ÚNICA tabla que hay
## que tocar para cambiar qué modelo sale: ni el nivel ni el cliente saben
## nombres de archivo.
##
## Cada personaje tiene hasta dos rutas: "m" y "f". Una variante puede NO
## existir todavía (los modelos están hechos pero sin riguear, y sin esqueleto
## no se pueden animar): `model()` comprueba el archivo y CAE al masculino si
## falta. Gracias a eso el juego ya funciona con el género cableado, y el día
## que aparezca un `*_rig.glb` nuevo entra solo.
##
## EL NEUTRO SE RETIRÓ al entrar el cartel de recompensa: ahí el género es el
## MODELO que se ve en la foto y se pasa con flechas, así que una tercera
## opción "sin especificar" no tenía nada que enseñar. `NEUTRAL` sigue aquí
## SOLO para reconocer los guardados viejos (`GameState._load` los pasa a
## masculino); ni está en `PLAYER_GENDERS` ni tiene modelo.

const MALE := "m"
const FEMALE := "f"
## Solo para leer guardados anteriores al cartel de recompensa. No se elige.
const NEUTRAL := "x"
## Los que puede elegir el jugador, en el orden en que las flechas los recorren.
const PLAYER_GENDERS := [MALE, FEMALE]
const GENDER_NAMES := {
	MALE: "Masculino", FEMALE: "Femenino",
}
## Cómo se dirige el juego al jugador cuando no ha puesto nombre.
const GENDER_TITLES := {
	MALE: "Cocinero", FEMALE: "Cocinera",
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
	# El JEFE del nivel 10: el Kappa. Come como un capitán (a su manera: ver
	# client3d.make_boss) y, como Pablo, es un personaje concreto sin variantes.
	"kappa": {
		MALE: "res://assets/models/kappa_rig.glb",
	},
	# CAI, el pescador de la Isla de Gades. En el nivel 8 no se queda mirando
	# desde la orilla: se sienta en la barra y hay que darle de comer, así que
	# necesita su propio modelo. Come como un PIRATA (2 estrellas), que es lo
	# que le pega a un pescador; el tipo lo pone el puerto, no este modelo.
	# Como Pablo y el Kappa, es un personaje concreto y no tiene variante
	# femenina.
	"cai": {
		MALE: "res://assets/models/cai_rig.glb",
	},
	"chef": {
		MALE: "res://assets/models/chef_rig.glb",
		FEMALE: "res://assets/models/chef_fem_rig.glb",
	},
	# ALICE. Un solo modelo para sus DOS papeles: la clienta de su escenario y
	# la AYUDANTE de cocina en cuanto se enrola. Es la misma persona y el rig es
	# el mismo, así que dos modelos serían dos veces los mismos triángulos.
	# Con ella desaparecieron `ayudante_rig` y `ayudante_fem_rig`, los dos
	# ayudantes genéricos que se elegían por el género CONTRARIO al del jugador:
	# el ayudante ya no es un figurante, es un personaje con nombre.
	"alice": {
		MALE: "res://assets/models/alice_rig.glb",
	},
}

## Iconos de cabeza del HUD (tools/head_icons.gd los saca de estos modelos).
const HEADS := {
	"grumete": { MALE: "res://assets/ui/head_E.png", FEMALE: "res://assets/ui/head_E_f.png" },
	"pirata": { MALE: "res://assets/ui/head_A.png", FEMALE: "res://assets/ui/head_A_f.png" },
	"capitan": { MALE: "res://assets/ui/head_G.png", FEMALE: "res://assets/ui/head_G_f.png" },
	"vip": { MALE: "res://assets/ui/head_V.png", FEMALE: "res://assets/ui/head_V_f.png" },
	"pablo": { MALE: "res://assets/ui/head_P.png" },
	"kappa": { MALE: "res://assets/ui/head_K.png" },
	"cai": { MALE: "res://assets/ui/head_C.png" },
	"alice": { MALE: "res://assets/ui/head_AL.png" },
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


## El género contrario. Lo usó el ayudante genérico, que ya no existe (hoy la
## ayudante es Alice); se queda como utilidad de la tabla.
static func opposite(gender: String) -> String:
	return MALE if gender == FEMALE else FEMALE


## Género al azar, para los clientes de cada partida.
static func random_gender() -> String:
	return FEMALE if randf() < 0.5 else MALE


static func _pick(table: Dictionary, who: String, gender: String) -> String:
	var entry: Dictionary = table.get(who, {})
	var wanted: String = entry.get(gender, "")
	if wanted != "" and ResourceLoader.exists(wanted):
		return wanted
	var macho: String = entry.get(MALE, "")
	if macho != "":
		return macho
	# RED DE SEGURIDAD PARA LOS PERSONAJES DE UN SOLO PUERTO. Un `who` que no
	# esté en la tabla devolvía "" y quien lo cargara se quedaba con un hueco
	# —le pasaría a la fila de cabezas del HUD con un cliente especial sin
	# icono propio—, así que se cae al del GRUMETE, que existe siempre.
	return table.get("grumete", {}).get(MALE, "")
