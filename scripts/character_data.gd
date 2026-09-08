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
	# EL REPARTO ES EL DE FIGURITAS (Link's Awakening, cadena Ludo -> Meshy ->
	# Blender, 5-9-2026). Las variantes FEMENINAS de la clientela todavia no
	# existen en ese estilo: `model()` cae al masculino, que es lo que hay. Las
	# viejas low poly no se mezclan con las nuevas a proposito (dos estilos en
	# la misma barra cantan mas que un solo genero).
	# LAS CLIENTAS (7-9-2026): variante femenina de cada tipo, por la misma
	# cadena (concepto editado del masculino -> Meshy multi-vista -> Blender).
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
	# del escenario 23. Come como un capitán, pero con su propio modelo (y su navaja
	# en lugar de mano derecha). No tiene variante femenina: es un personaje
	# concreto, no un tipo de cliente.
	"pablo": {
		MALE: "res://assets/models/pablo_rig.glb",
	},
	# El JEFE del escenario 35: el Kappa. Come como un capitán (a su manera: ver
	# client3d.make_boss) y, como Pablo, es un personaje concreto sin variantes.
	"kappa": {
		MALE: "res://assets/models/kappa_rig.glb",
	},
	# CAI, el pescador de la Isla de Gades. En el escenario 21 no se queda mirando
	# desde la orilla: se sienta en la barra y hay que darle de comer, así que
	# necesita su propio modelo. Come como un PIRATA (2 estrellas), que es lo
	# que le pega a un pescador; el tipo lo pone el puerto, no este modelo.
	# Como Pablo y el Kappa, es un personaje concreto y no tiene variante
	# femenina.
	"cai": {
		MALE: "res://assets/models/cai_rig.glb",
	},
	# Cai CON EL SOMBRERO DE PAJA: el mismo personaje con el coleccionable
	# puesto. `model()` lo elige solo cuando el jugador tiene la pieza.
	"cai_sombrero": {
		MALE: "res://assets/models/cai_sombrero_rig.glb",
	},
	# (El CHEF ya no esta aqui: es modular y lo monta `ChefLook`.)
	# DAVID y SAVERIO tienen modelo propio para el retrato 3D del dialogo y,
	# Saverio, para su puesto de la tienda.
	"david": {
		MALE: "res://assets/models/david_rig.glb",
	},
	"saverio": {
		MALE: "res://assets/models/saverio_rig.glb",
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
	# MAR 2: la maestra de Alice y el capitan que ensena el barco combinado.
	"miku": {
		MALE: "res://assets/models/miku_rig.glb",
	},
	"nach": {
		MALE: "res://assets/models/nach_rig.glb",
	},
	# LA SIRENA, la jefa del mar 2. Su rig tiene las "piernas" dentro de la
	# cola (21% del alto): `CharacterAnim.legs_ok` las deja en paz, asi que
	# NADA con el vaiven del cuerpo en vez de andar, que es lo que toca.
	"sirena": {
		MALE: "res://assets/models/sirena_rig.glb",
	},
}

## Iconos de cabeza del HUD (tools/head_icons.gd los saca de estos modelos).
const HEADS := {
	# (Sin variante femenina: la clientela v5 solo tiene modelo masculino, y
	# el icono tiene que ser la cara que se dibuja en la barra.)
	"grumete": { MALE: "res://assets/ui/head_E.png", FEMALE: "res://assets/ui/head_E_f.png" },
	"pirata": { MALE: "res://assets/ui/head_A.png", FEMALE: "res://assets/ui/head_A_f.png" },
	"capitan": { MALE: "res://assets/ui/head_G.png", FEMALE: "res://assets/ui/head_G_f.png" },
	"vip": { MALE: "res://assets/ui/head_V.png", FEMALE: "res://assets/ui/head_V_f.png" },
	"pablo": { MALE: "res://assets/ui/head_P.png" },
	"kappa": { MALE: "res://assets/ui/head_K.png" },
	"cai": { MALE: "res://assets/ui/head_C.png" },
	"cai_sombrero": { MALE: "res://assets/ui/head_CS.png" },
	"alice": { MALE: "res://assets/ui/head_AL.png" },
	"miku": { MALE: "res://assets/ui/head_MI.png" },
	"nach": { MALE: "res://assets/ui/head_NA.png" },
	"sirena": { MALE: "res://assets/ui/head_SI.png" },
}

## Tipo de cliente (el de client_mix / TAKE_CHANCES) -> personaje.
const TYPE_TO_WHO := { "E": "grumete", "A": "pirata", "G": "capitan", "V": "vip" }


## Ruta del modelo de ese personaje en ese género, con caída al masculino si
## la variante todavía no está en disco (ver cabecera).
static func model(who: String, gender: String) -> String:
	# Cai lleva el sombrero de paja en cuanto el jugador lo tiene (el mismo
	# criterio que su retrato 2D, ver `DialogueBox._variante_de`).
	if who == "cai" and GameState.has_collectible("sombrero_paja") \
			and MODELS.has("cai_sombrero"):
		return _pick(MODELS, "cai_sombrero", gender)
	return _pick(MODELS, who, gender)


## Icono de cabeza para el contador de clientes del HUD.
static func head(who: String, gender: String) -> String:
	# el mismo criterio que `model()`: Cai con su sombrero de paja
	if who == "cai" and GameState.has_collectible("sombrero_paja") 			and HEADS.has("cai_sombrero"):
		return _pick(HEADS, "cai_sombrero", gender)
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
