class_name TreasureData
extends RefCounted
## LOS MAPAS DEL TESORO: las MISIONES SECUNDARIAS del juego (montadas el
## 1-9-2026 a peticion del usuario). Solo datos y ayudas puras — el estado
## (que mapas se tienen, cuales se han cumplido) vive en `GameState` y la
## pantalla es `treasure_screen.gd`.
##
## QUE LAS SEPARA DE LA CAMPAÑA, que es lo que las justifica: un escenario de
## aventura se gana con ORO, y aqui el oro da igual. Una mision del mapa pide
## una FORMA de jugar — llevar a alguien al x5, servir a destajo contra el
## reloj, no tirar ni un plato, encadenar maridajes... — asi que se cumplen
## JUGANDO ESCENARIOS QUE YA EXISTEN, con otro objetivo en la cabeza. No hacen
## falta escenarios nuevos y no compiten con la campaña: la reinterpretan.
##
## COMO SE JUEGAN: se elige un mapa en la pantalla de Mapas, queda ARMADO
## (`GameState.treasure_active`), y a partir de ahi cualquier jornada de
## aventura o arcade cuenta para el. Al cumplirse se cobra su recompensa.
##
## HAY 50 MAPAS (pedido por el usuario). Sus objetivos salen de este catalogo
## de TIPOS; cada mapa es un tipo con su cifra y su recompensa.

## ---------------------------------------------------------------- OBJETIVOS
##
## Cada tipo dice QUE se mide y en que unidad. La cuenta la lleva
## `GameState.treasure_progress`, que `level3d` alimenta con los sucesos que
## YA emitia el juego (no hay contadores nuevos en la partida).
##
##   mult_cliente     — llevar UN cliente al multiplicador N
##   platos_tiempo    — servir N platos en M segundos (la jornada entera)
##   sin_basura       — cerrar una jornada sin que se pierda NI UN plato
##   sin_vacios       — cerrar una jornada sin que nadie se vaya sin comer
##   maridajes        — encadenar N maridajes en una jornada
##   propina_jornada  — juntar N doblones de propina en una jornada
##   extras_jornada   — usar N extras en una jornada
##   postres          — despedir a N clientes con postre
##   picoteos         — servir N picoteos
##   variedad_carta   — servir al menos una vez CADA receta de la carta
##   un_cliente       — que un mismo cliente coma N platos
##   sin_repetir      — servir N platos seguidos sin repetirle plato a nadie
##   corte_perfecto   — clavar N cortes lentos sin fallar uno
##   punto_perfecto   — clavar el punto de N frituras
##   cliente_lleno    — que un capitan se vaya habiendo comido N platos
##   racha_limpia     — N platos servidos sin un solo fallo (ni cubo ni corte)
##
## AL AÑADIR UN TIPO: una entrada aqui, su texto en `texto_objetivo` y su
## cuenta en `GameState.treasure_bump`. Nada mas.
const TIPOS := [
	"mult_cliente", "platos_tiempo", "sin_basura", "sin_vacios", "maridajes",
	"propina_jornada", "extras_jornada", "postres", "picoteos",
	"variedad_carta", "un_cliente", "sin_repetir", "corte_perfecto",
	"punto_perfecto", "cliente_lleno", "racha_limpia",
]


## Frase del objetivo, para la ficha del mapa y para el aviso en partida.
## Lleva las palabras clave entre `**` (`DialogueBox.format_keywords`).
static func texto_objetivo(m: Dictionary) -> String:
	var n := int(m.get("n", 1))
	var t := int(m.get("t", 0))
	match str(m.get("tipo", "")):
		"mult_cliente":
			return "Lleva a un cliente hasta el multiplicador **x%d**." % n
		"platos_tiempo":
			return "Sirve **%d platos** en menos de **%d segundos**." % [n, t]
		"sin_basura":
			return "Cierra una jornada **sin tirar ni un plato** al cubo."
		"sin_vacios":
			return "Cierra una jornada **sin que nadie se vaya de vacio**."
		"maridajes":
			return "Encadena **%d maridajes** en una misma jornada." % n
		"propina_jornada":
			return "Junta **%d doblones de propina** en una jornada." % n
		"extras_jornada":
			return "Usa **%d extras** en una misma jornada." % n
		"postres":
			return "Despide a **%d clientes con postre**." % n
		"picoteos":
			return "Sirve **%d picoteos**." % n
		"variedad_carta":
			return "Sirve al menos una vez **cada receta de la carta**."
		"un_cliente":
			return "Que un mismo cliente se coma **%d platos**." % n
		"sin_repetir":
			return "Sirve **%d platos seguidos** sin repetirle plato a nadie." % n
		"corte_perfecto":
			return "Clava **%d cortes lentos** sin fallar ninguno." % n
		"punto_perfecto":
			return "Clava el punto de **%d frituras**." % n
		"cliente_lleno":
			return "Que un **capitan** se vaya habiendo comido **%d platos**." % n
		"racha_limpia":
			return "**%d platos** servidos sin un solo fallo." % n
	return "Objetivo desconocido."


## Frase de la recompensa, en el mismo formato.
static func texto_premio(m: Dictionary) -> String:
	var p: Dictionary = m.get("premio", {})
	var trozos: Array[String] = []
	if int(p.get("oro", 0)) > 0:
		trozos.append("**%d doblones**" % int(p["oro"]))
	if int(p.get("lingotes", 0)) > 0:
		var n := int(p["lingotes"])
		trozos.append("**%d lingote%s**" % [n, "" if n == 1 else "s"])
	if int(p.get("cebo", 0)) > 0:
		trozos.append("**%d cebos**" % int(p["cebo"]))
	if int(p.get("arroz", 0)) > 0:
		var a := int(p["arroz"])
		trozos.append("**%d saco%s de arroz**" % [a, "" if a == 1 else "s"])
	if int(p.get("extras", 0)) > 0:
		trozos.append("**%d usos de cada extra**" % int(p["extras"]))
	if str(p.get("ingrediente", "")) != "":
		var ing: Dictionary = RecipeData.get_ingredient(str(p["ingrediente"]))
		trozos.append("**%d de %s**" % [int(p.get("ingrediente_n", 3)),
			str(ing.get("name", p["ingrediente"]))])
	if str(p.get("coleccionable", "")) != "":
		trozos.append("**%s**" % CollectibleData.item_name(
			str(p["coleccionable"])))
	if trozos.is_empty():
		return "Nada."
	return ", ".join(trozos)


## Los 50 mapas. El ORDEN es el de la vitrina de mapas y sube en dificultad:
## los primeros se cumplen casi solos jugando la campaña y los ultimos piden
## proponerselo. Los coleccionables que reparten son PIEZAS QUE NO SE GANAN DE
## NINGUNA OTRA FORMA (ver `CollectibleData`: el cañon, el pañuelo, la pluma
## del loro, la de escribir, el saco de cafe, la marca negra y los tapones de
## cera estaban esperando exactamente a esto).
const MAPAS := [
	# --- los diez primeros: se cruzan con la campaña sin desviarse
	{ "id": "t01", "nombre": "Cala de la Primera Marca",
		"tipo": "mult_cliente", "n": 3,
		"premio": { "oro": 120 } },
	{ "id": "t02", "nombre": "Bajio del Cocinero Manco",
		"tipo": "picoteos", "n": 8,
		"premio": { "oro": 140, "cebo": 3 } },
	{ "id": "t03", "nombre": "Islote del Cubo Vacio",
		"tipo": "sin_basura", "n": 1,
		"premio": { "oro": 160, "arroz": 1 } },
	{ "id": "t04", "nombre": "Punta del Postre",
		"tipo": "postres", "n": 5,
		"premio": { "oro": 150, "extras": 3 } },
	{ "id": "t05", "nombre": "Roca del Buen Servicio",
		"tipo": "sin_vacios", "n": 1,
		"premio": { "oro": 180, "cebo": 3 } },
	{ "id": "t06", "nombre": "Cala del Pulso Firme",
		"tipo": "corte_perfecto", "n": 6,
		"premio": { "oro": 170, "ingrediente": "atun_rojo", "ingrediente_n": 3 } },
	{ "id": "t07", "nombre": "Arrecife del Comilon",
		"tipo": "un_cliente", "n": 5,
		"premio": { "oro": 190, "arroz": 1 } },
	{ "id": "t08", "nombre": "Ensenada de la Propina",
		"tipo": "propina_jornada", "n": 30,
		"premio": { "oro": 200, "lingotes": 1 } },
	{ "id": "t09", "nombre": "Farallon del Sazon",
		"tipo": "extras_jornada", "n": 6,
		"premio": { "oro": 180, "extras": 5 } },
	{ "id": "t10", "nombre": "Playa de las Cinco Bocas",
		"tipo": "platos_tiempo", "n": 12, "t": 90,
		"premio": { "oro": 220, "coleccionable": "canon" } },
	# --- del 11 al 25: ya hay que proponerselo
	{ "id": "t11", "nombre": "Rada del Maridaje", "tipo": "maridajes", "n": 3,
		"premio": { "oro": 220, "cebo": 5 } },
	{ "id": "t12", "nombre": "Cabo de la Carta Entera",
		"tipo": "variedad_carta", "n": 1,
		"premio": { "oro": 240, "arroz": 2 } },
	{ "id": "t13", "nombre": "Banco del Sin Repetir", "tipo": "sin_repetir", "n": 8,
		"premio": { "oro": 250, "lingotes": 1 } },
	{ "id": "t14", "nombre": "Caleta del Punto Justo",
		"tipo": "punto_perfecto", "n": 3,
		"premio": { "oro": 260, "extras": 5 } },
	{ "id": "t15", "nombre": "Isla del Capitan Harto",
		"tipo": "cliente_lleno", "n": 6,
		"premio": { "oro": 280, "coleccionable": "panuelo" } },
	{ "id": "t16", "nombre": "Escollo del x4", "tipo": "mult_cliente", "n": 4,
		"premio": { "oro": 260, "cebo": 5 } },
	{ "id": "t17", "nombre": "Barra de los Veinte",
		"tipo": "platos_tiempo", "n": 20, "t": 130,
		"premio": { "oro": 300, "lingotes": 1 } },
	{ "id": "t18", "nombre": "Laguna del Picoteo", "tipo": "picoteos", "n": 15,
		"premio": { "oro": 260, "arroz": 2 } },
	{ "id": "t19", "nombre": "Cala de la Racha", "tipo": "racha_limpia", "n": 12,
		"premio": { "oro": 320, "coleccionable": "pluma_escribir" } },
	{ "id": "t20", "nombre": "Morro del Dulce", "tipo": "postres", "n": 12,
		"premio": { "oro": 300, "extras": 8 } },
	{ "id": "t21", "nombre": "Veril de la Propina Larga",
		"tipo": "propina_jornada", "n": 60,
		"premio": { "oro": 340, "lingotes": 2 } },
	{ "id": "t22", "nombre": "Restinga del Cuchillo",
		"tipo": "corte_perfecto", "n": 15,
		"premio": { "oro": 330, "coleccionable": "saco_cafe" } },
	{ "id": "t23", "nombre": "Freu de los Dos Sabores",
		"tipo": "maridajes", "n": 6,
		"premio": { "oro": 350, "cebo": 8 } },
	{ "id": "t24", "nombre": "Placer del Servicio Limpio",
		"tipo": "sin_basura", "n": 1,
		"premio": { "oro": 300, "arroz": 3 } },
	{ "id": "t25", "nombre": "Seno del Comensal Eterno",
		"tipo": "un_cliente", "n": 8,
		"premio": { "oro": 380, "coleccionable": "pluma_loro" } },
	# --- del 26 al 40: exigen jugar bien de verdad
	{ "id": "t26", "nombre": "Bajo del x5", "tipo": "mult_cliente", "n": 5,
		"premio": { "oro": 400, "lingotes": 2 } },
	{ "id": "t27", "nombre": "Canal de las Treinta",
		"tipo": "platos_tiempo", "n": 30, "t": 150,
		"premio": { "oro": 420, "coleccionable": "marca_negra" } },
	{ "id": "t28", "nombre": "Golfo del Sazon Largo",
		"tipo": "extras_jornada", "n": 14,
		"premio": { "oro": 380, "extras": 10 } },
	{ "id": "t29", "nombre": "Punta de la Mesa Llena",
		"tipo": "sin_vacios", "n": 1,
		"premio": { "oro": 400, "lingotes": 1 } },
	{ "id": "t30", "nombre": "Bocana del Sin Fallo",
		"tipo": "racha_limpia", "n": 20,
		"premio": { "oro": 450, "coleccionable": "tapones_cera" } },
	{ "id": "t31", "nombre": "Arrecife de la Fritura",
		"tipo": "punto_perfecto", "n": 8,
		"premio": { "oro": 420, "arroz": 3 } },
	{ "id": "t32", "nombre": "Cala de la Carta Completa",
		"tipo": "variedad_carta", "n": 1,
		"premio": { "oro": 440, "lingotes": 2 } },
	{ "id": "t33", "nombre": "Estrecho del Sin Repetir",
		"tipo": "sin_repetir", "n": 15,
		"premio": { "oro": 460, "cebo": 10 } },
	{ "id": "t34", "nombre": "Rompiente del Capitan",
		"tipo": "cliente_lleno", "n": 9,
		"premio": { "oro": 480, "lingotes": 2 } },
	{ "id": "t35", "nombre": "Piedra del Bote Lleno",
		"tipo": "propina_jornada", "n": 100,
		"premio": { "oro": 500, "arroz": 4 } },
	{ "id": "t36", "nombre": "Sirte del Postre Infinito",
		"tipo": "postres", "n": 20,
		"premio": { "oro": 480, "extras": 12 } },
	{ "id": "t37", "nombre": "Cantil del Maridaje Doble",
		"tipo": "maridajes", "n": 10,
		"premio": { "oro": 520, "lingotes": 3 } },
	{ "id": "t38", "nombre": "Vado del Picoteo Sin Fin",
		"tipo": "picoteos", "n": 25,
		"premio": { "oro": 500, "cebo": 12 } },
	{ "id": "t39", "nombre": "Laja del Cuchillo Fino",
		"tipo": "corte_perfecto", "n": 25,
		"premio": { "oro": 540, "lingotes": 2 } },
	{ "id": "t40", "nombre": "Fondeadero de las Cuarenta",
		"tipo": "platos_tiempo", "n": 40, "t": 150,
		"premio": { "oro": 600, "lingotes": 3 } },
	# --- del 41 al 50: para cuando ya no queda campaña
	{ "id": "t41", "nombre": "Abismo del x6", "tipo": "mult_cliente", "n": 6,
		"premio": { "oro": 620, "lingotes": 3 } },
	{ "id": "t42", "nombre": "Sima del Servicio Perfecto",
		"tipo": "racha_limpia", "n": 30,
		"premio": { "oro": 650, "arroz": 5 } },
	{ "id": "t43", "nombre": "Fosa del Comilon",
		"tipo": "un_cliente", "n": 12,
		"premio": { "oro": 680, "lingotes": 3 } },
	{ "id": "t44", "nombre": "Veta del Sazon Total",
		"tipo": "extras_jornada", "n": 25,
		"premio": { "oro": 640, "extras": 20 } },
	{ "id": "t45", "nombre": "Talud del Bote Rebosante",
		"tipo": "propina_jornada", "n": 160,
		"premio": { "oro": 700, "lingotes": 4 } },
	{ "id": "t46", "nombre": "Cañon del Punto Clavado",
		"tipo": "punto_perfecto", "n": 15,
		"premio": { "oro": 700, "arroz": 5 } },
	{ "id": "t47", "nombre": "Fondo del Sin Repetir",
		"tipo": "sin_repetir", "n": 25,
		"premio": { "oro": 720, "lingotes": 4 } },
	{ "id": "t48", "nombre": "Barra del Maridaje Maestro",
		"tipo": "maridajes", "n": 18,
		"premio": { "oro": 760, "lingotes": 4 } },
	{ "id": "t49", "nombre": "Sondaleza del Capitan Lleno",
		"tipo": "cliente_lleno", "n": 12,
		"premio": { "oro": 800, "lingotes": 5 } },
	{ "id": "t50", "nombre": "Ultimo Fondeadero",
		"tipo": "platos_tiempo", "n": 50, "t": 150,
		"premio": { "oro": 1000, "lingotes": 6, "arroz": 5 } },
]


## Cuantos mapas hay en total (lo usan la pantalla y el contador del submenu).
static func total() -> int:
	return MAPAS.size()


## El mapa que ocupa esa posicion, o {} si no existe.
static func mapa(i: int) -> Dictionary:
	if i < 0 or i >= MAPAS.size():
		return {}
	return MAPAS[i]


## Busca por id.
static func por_id(id: String) -> Dictionary:
	for m in MAPAS:
		if str(m.get("id", "")) == id:
			return m
	return {}


## Cuanto hace falta de ese objetivo (la cifra que se compara con el progreso).
static func meta(m: Dictionary) -> int:
	return int(m.get("n", 1))
