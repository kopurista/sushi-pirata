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
##   clientes_platos  — dar al menos P platos a N clientes DISTINTOS
##
## AL AÑADIR UN TIPO: una entrada aqui, su texto en `texto_objetivo` y su
## cuenta en `GameState.treasure_bump`. Nada mas.
const TIPOS := [
	"mult_cliente", "platos_tiempo", "sin_basura", "sin_vacios", "maridajes",
	"propina_jornada", "extras_jornada", "postres", "picoteos",
	"variedad_carta", "un_cliente", "sin_repetir", "corte_perfecto",
	"punto_perfecto", "cliente_lleno", "racha_limpia", "clientes_platos",
]


## ------------------------------------------------------------- DIFICULTAD
##
## TRES MARCAS (pedido por el usuario). Y no son una etiqueta: la marca decide
## lo que PAGA el mapa —oro y experiencia— y, en medio y dificil, tambien lo
## que el mapa le HACE A LA JORNADA mientras esta armado (ver `mods`).
##
## El oro y la XP salen de la marca y NO se escriben mapa a mapa: con dos
## fuentes de verdad, tarde o temprano un mapa dificil acaba pagando menos que
## uno facil. Lo que se escribe a mano es el premio ESPECIAL (lingotes, cebo,
## despensa, coleccionable), que es lo que distingue a un mapa de otro.
const DIFICULTADES := ["facil", "medio", "dificil"]
const DIF_NOMBRE := { "facil": "Fácil", "medio": "Medio", "dificil": "Difícil" }
const DIF_COLOR := {
	"facil": Color(0.42, 0.72, 0.36),
	"medio": Color(0.90, 0.70, 0.22),
	"dificil": Color(0.84, 0.32, 0.26),
}
const DIF_ORO := { "facil": 150, "medio": 340, "dificil": 700 }
const DIF_XP := { "facil": 40, "medio": 95, "dificil": 200 }


## -------------------------------------------------------- MODIFICADORES
##
## LO QUE UN MAPA LE HACE A LA JORNADA mientras esta armado. Es lo que separa
## de verdad las tres marcas: un mapa dificil no pide "lo mismo pero mas
## veces", pide lo mismo con la cocina en contra. Los aplica `level3d` al
## montar el nivel, sobre CUALQUIER escenario que se juegue con el mapa puesto.
##
##   paciencia — la barra de los clientes baja mas deprisa (1.3 = un 30% mas)
##   bocado    — mastican mas deprisa, o sea que vuelven antes a pedir
##   tiempo    — segundos de reloj para cumplir el objetivo (0 = sin reloj)
##   vidas     — tropiezos permitidos; al agotarlos, el mapa no cuenta hoy
##
## `vidas` se gasta con lo que diga `falla`: "maridaje" (servir un plato que
## rompe una pareja), "vacio" (un cliente que se va sin comer) o "cubo" (un
## plato al cubo). Sin `vidas` no hay tropiezos que contar.
static func mods(m: Dictionary) -> Dictionary:
	return m.get("mods", {})


static func dificultad(m: Dictionary) -> String:
	var d := str(m.get("dificultad", "facil"))
	return d if d in DIFICULTADES else "facil"


static func dif_nombre(m: Dictionary) -> String:
	return str(DIF_NOMBRE.get(dificultad(m), "Fácil"))


static func dif_color(m: Dictionary) -> Color:
	return DIF_COLOR.get(dificultad(m), DIF_COLOR["facil"])


## Doblones que paga el mapa (de su marca, no del mapa).
static func oro(m: Dictionary) -> int:
	return int(DIF_ORO.get(dificultad(m), 150))


## Experiencia que paga el mapa.
static func xp(m: Dictionary) -> int:
	return int(DIF_XP.get(dificultad(m), 40))


## Frase de lo que el mapa le hace a la jornada, o "" si no le hace nada.
static func texto_mods(m: Dictionary) -> String:
	var d := mods(m)
	if d.is_empty():
		return ""
	var trozos: Array[String] = []
	if float(d.get("paciencia", 1.0)) > 1.0:
		trozos.append("la clientela se impacienta un **%d%% más rápido**"
			% int(round((float(d["paciencia"]) - 1.0) * 100.0)))
	if float(d.get("bocado", 1.0)) > 1.0:
		trozos.append("**comen más deprisa** y vuelven antes a pedir")
	if int(d.get("tiempo", 0)) > 0:
		trozos.append("tienes **%d segundos**" % int(d["tiempo"]))
	if int(d.get("vidas", 0)) > 0:
		var n := int(d["vidas"])
		# CON QUÉ se gasta cada vida, que "solo 3 fallos" no decía de qué.
		var de := "al cubo" if str(d.get("falla", "")) == "cubo" \
			else ("de vacío" if str(d.get("falla", "")) == "vacio" else "")
		trozos.append("solo **%d fallo%s%s**" % [n, "" if n == 1 else "s",
			("" if de == "" else " " + de)])
	if trozos.is_empty():
		return ""
	return "Con este mapa armado: " + ", ".join(trozos) + "."


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
			return "Cierra una jornada **sin que nadie se vaya de vacío**."
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
			return "Que un **capitán** se vaya habiendo comido **%d platos**." % n
		"racha_limpia":
			return "**%d platos** servidos sin un solo fallo." % n
		"clientes_platos":
			return "Dale al menos **%d platos** a **%d clientes distintos**." \
				% [int(m.get("p", 3)), n]
	return "Objetivo desconocido."


## Frase de la recompensa, en el mismo formato. El ORO y la EXPERIENCIA van
## SIEMPRE los primeros y salen de la marca del mapa, no de su ficha.
static func texto_premio(m: Dictionary) -> String:
	var p: Dictionary = m.get("premio", {})
	var trozos: Array[String] = []
	trozos.append("**%d doblones**" % oro(m))
	trozos.append("**%d de experiencia**" % xp(m))
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
	# EL PRIMERO ES EL DEL GRUMETE de la Caleta del Cartografo, y por eso pide
	# algo que ya se hace jugando: repartir en vez de volcarse en uno. Es la
	# misma mision que reaparece de MEDIO (t18) y de DIFICIL (t35), para que se
	# vea de un vistazo que las marcas no piden otra cosa: piden lo mismo con
	# la cocina en contra.
	{ "id": "t01", "nombre": "Cala de las Cuatro Bocas", "dificultad": "facil",
		"tipo": "clientes_platos", "n": 4, "p": 3,
		"premio": {} },
	{ "id": "t02", "nombre": "Bajío del Cocinero Manco", "dificultad": "facil",
		"tipo": "picoteos", "n": 8,
		"premio": { "cebo": 3 } },
	{ "id": "t03", "nombre": "Islote del Cubo Vacío", "dificultad": "facil",
		"tipo": "sin_basura", "n": 1,
		"premio": { "arroz": 1 } },
	{ "id": "t04", "nombre": "Punta del Postre", "dificultad": "facil",
		"tipo": "postres", "n": 5,
		"premio": { "extras": 3 } },
	{ "id": "t05", "nombre": "Roca del Buen Servicio", "dificultad": "facil",
		"tipo": "sin_vacios", "n": 1,
		"premio": { "cebo": 3 } },
	{ "id": "t06", "nombre": "Cala del Pulso Firme", "dificultad": "facil",
		"tipo": "corte_perfecto", "n": 6,
		"premio": { "ingrediente": "atun_rojo", "ingrediente_n": 3 } },
	{ "id": "t07", "nombre": "Arrecife del Comilón", "dificultad": "facil",
		"tipo": "un_cliente", "n": 5,
		"premio": { "arroz": 1 } },
	{ "id": "t08", "nombre": "Ensenada de la Propina", "dificultad": "facil",
		"tipo": "propina_jornada", "n": 30,
		"premio": { "lingotes": 1 } },
	{ "id": "t09", "nombre": "Farallón del Sazón", "dificultad": "facil",
		"tipo": "extras_jornada", "n": 6,
		"premio": { "extras": 5 } },
	{ "id": "t10", "nombre": "Playa de las Cinco Bocas", "dificultad": "facil",
		"tipo": "platos_tiempo", "n": 12, "t": 90,
		"premio": { "coleccionable": "canon" } },
	{ "id": "t11", "nombre": "Rada del Maridaje", "dificultad": "facil",
		"tipo": "maridajes", "n": 3,
		"premio": { "cebo": 5 } },
	{ "id": "t12", "nombre": "Cabo de la Carta Entera", "dificultad": "facil",
		"tipo": "variedad_carta", "n": 1,
		"premio": { "arroz": 2 } },
	{ "id": "t13", "nombre": "Banco del Sin Repetir", "dificultad": "facil",
		"tipo": "sin_repetir", "n": 8,
		"premio": { "lingotes": 1 } },
	{ "id": "t14", "nombre": "Caleta del Punto Justo", "dificultad": "facil",
		"tipo": "punto_perfecto", "n": 3,
		"premio": { "extras": 5 } },
	{ "id": "t15", "nombre": "Isla del Capitán Harto", "dificultad": "facil",
		"tipo": "cliente_lleno", "n": 6,
		"premio": { "coleccionable": "panuelo" } },
	{ "id": "t16", "nombre": "Escollo del x4", "dificultad": "facil",
		"tipo": "mult_cliente", "n": 4,
		"premio": { "cebo": 5 } },
	{ "id": "t17", "nombre": "Barra de los Veinte", "dificultad": "facil",
		"tipo": "platos_tiempo", "n": 20, "t": 130,
		"premio": { "lingotes": 1 } },
	{ "id": "t18", "nombre": "Rada de las Ocho Bocas", "dificultad": "medio",
		"tipo": "clientes_platos", "n": 8, "p": 3,
		"mods": { "paciencia": 1.3 },
		"premio": { "arroz": 2 } },
	{ "id": "t19", "nombre": "Cala de la Racha", "dificultad": "medio",
		"tipo": "racha_limpia", "n": 12,
		"mods": { "paciencia": 1.25 },
		"premio": { "coleccionable": "pluma_escribir" } },
	{ "id": "t20", "nombre": "Morro del Dulce", "dificultad": "medio",
		"tipo": "postres", "n": 12,
		"mods": { "bocado": 1.25 },
		"premio": { "extras": 8 } },
	{ "id": "t21", "nombre": "Veril de la Propina Larga", "dificultad": "medio",
		"tipo": "propina_jornada", "n": 60,
		"mods": { "paciencia": 1.2, "vidas": 3, "falla": "cubo" },
		"premio": { "lingotes": 2 } },
	{ "id": "t22", "nombre": "Restinga del Cuchillo", "dificultad": "medio",
		"tipo": "corte_perfecto", "n": 15,
		"mods": { "paciencia": 1.25 },
		"premio": { "coleccionable": "saco_cafe" } },
	{ "id": "t23", "nombre": "Freu de los Dos Sabores", "dificultad": "medio",
		"tipo": "maridajes", "n": 6,
		"mods": { "bocado": 1.25 },
		"premio": { "cebo": 8 } },
	{ "id": "t24", "nombre": "Placer del Servicio Limpio", "dificultad": "medio",
		"tipo": "sin_basura", "n": 1,
		# Sin vidas de cubo: el primer cubo ya rompe "sin tirar ni un plato".
		"mods": { "paciencia": 1.25 },
		"premio": { "arroz": 3 } },
	{ "id": "t25", "nombre": "Seno del Comensal Eterno", "dificultad": "medio",
		"tipo": "un_cliente", "n": 8,
		"mods": { "paciencia": 1.25 },
		"premio": { "coleccionable": "pluma_loro" } },
	{ "id": "t26", "nombre": "Bajo del x5", "dificultad": "medio",
		"tipo": "mult_cliente", "n": 5,
		"mods": { "bocado": 1.25 },
		"premio": { "lingotes": 2 } },
	{ "id": "t27", "nombre": "Canal de las Treinta", "dificultad": "medio",
		"tipo": "platos_tiempo", "n": 30, "t": 150,
		"mods": { "paciencia": 1.2, "vidas": 3, "falla": "cubo" },
		"premio": { "coleccionable": "marca_negra" } },
	{ "id": "t28", "nombre": "Golfo del Sazón Largo", "dificultad": "medio",
		"tipo": "extras_jornada", "n": 14,
		"mods": { "paciencia": 1.25 },
		"premio": { "extras": 10 } },
	{ "id": "t29", "nombre": "Punta de la Mesa Llena", "dificultad": "medio",
		"tipo": "sin_vacios", "n": 1,
		"mods": { "bocado": 1.25 },
		"premio": { "lingotes": 1 } },
	{ "id": "t30", "nombre": "Bocana del Sin Fallo", "dificultad": "medio",
		"tipo": "racha_limpia", "n": 20,
		# Sin vidas: la racha ya se rompe con cada cubo o corte fallado.
		"mods": { "paciencia": 1.25 },
		"premio": { "coleccionable": "tapones_cera" } },
	{ "id": "t31", "nombre": "Arrecife de la Fritura", "dificultad": "medio",
		"tipo": "punto_perfecto", "n": 8,
		"mods": { "paciencia": 1.25 },
		"premio": { "arroz": 3 } },
	{ "id": "t32", "nombre": "Cala de la Carta Completa", "dificultad": "medio",
		"tipo": "variedad_carta", "n": 1,
		"mods": { "bocado": 1.25 },
		"premio": { "lingotes": 2 } },
	{ "id": "t33", "nombre": "Estrecho del Sin Repetir", "dificultad": "medio",
		"tipo": "sin_repetir", "n": 15,
		"mods": { "paciencia": 1.2, "vidas": 3, "falla": "cubo" },
		"premio": { "cebo": 10 } },
	{ "id": "t34", "nombre": "Rompiente del Capitán", "dificultad": "medio",
		"tipo": "cliente_lleno", "n": 9,
		"mods": { "paciencia": 1.25 },
		"premio": { "lingotes": 2 } },
	{ "id": "t35", "nombre": "Fosa de las Ocho Bocas", "dificultad": "dificil",
		"tipo": "clientes_platos", "n": 8, "p": 5,
		"mods": { "paciencia": 1.5, "bocado": 1.3, "tiempo": 60 },
		"premio": { "arroz": 4 } },
	{ "id": "t36", "nombre": "Sirte del Postre Infinito", "dificultad": "dificil",
		"tipo": "postres", "n": 20,
		"mods": { "paciencia": 1.3, "bocado": 1.35, "vidas": 2, "falla": "cubo" },
		"premio": { "extras": 12 } },
	{ "id": "t37", "nombre": "Cantil del Maridaje Doble", "dificultad": "dificil",
		"tipo": "maridajes", "n": 10,
		"mods": { "paciencia": 1.45, "bocado": 1.25 },
		"premio": { "lingotes": 3 } },
	{ "id": "t38", "nombre": "Vado del Picoteo Sin Fin", "dificultad": "dificil",
		"tipo": "picoteos", "n": 25,
		"mods": { "paciencia": 1.35, "vidas": 1, "falla": "vacio" },
		"premio": { "cebo": 12 } },
	{ "id": "t39", "nombre": "Laja del Cuchillo Fino", "dificultad": "dificil",
		"tipo": "corte_perfecto", "n": 25,
		"mods": { "paciencia": 1.4, "tiempo": 90 },
		"premio": { "lingotes": 2 } },
	{ "id": "t40", "nombre": "Fondeadero de las Cuarenta", "dificultad": "dificil",
		"tipo": "platos_tiempo", "n": 40, "t": 150,
		"mods": { "paciencia": 1.3, "bocado": 1.35, "vidas": 2, "falla": "cubo" },
		"premio": { "lingotes": 3 } },
	{ "id": "t41", "nombre": "Abismo del x6", "dificultad": "dificil",
		"tipo": "mult_cliente", "n": 6,
		"mods": { "paciencia": 1.45, "bocado": 1.25 },
		"premio": { "lingotes": 3 } },
	{ "id": "t42", "nombre": "Sima del Servicio Perfecto", "dificultad": "dificil",
		"tipo": "racha_limpia", "n": 30,
		"mods": { "paciencia": 1.35, "vidas": 1, "falla": "vacio" },
		"premio": { "arroz": 5 } },
	{ "id": "t43", "nombre": "Fosa del Comilón", "dificultad": "dificil",
		"tipo": "un_cliente", "n": 12,
		"mods": { "paciencia": 1.4, "tiempo": 90 },
		"premio": { "lingotes": 3 } },
	{ "id": "t44", "nombre": "Veta del Sazón Total", "dificultad": "dificil",
		"tipo": "extras_jornada", "n": 25,
		"mods": { "paciencia": 1.3, "bocado": 1.35, "vidas": 2, "falla": "cubo" },
		"premio": { "extras": 20 } },
	{ "id": "t45", "nombre": "Talud del Bote Rebosante", "dificultad": "dificil",
		"tipo": "propina_jornada", "n": 160,
		"mods": { "paciencia": 1.45, "bocado": 1.25 },
		"premio": { "lingotes": 4 } },
	{ "id": "t46", "nombre": "Cañón del Punto Clavado", "dificultad": "dificil",
		"tipo": "punto_perfecto", "n": 15,
		"mods": { "paciencia": 1.35, "vidas": 1, "falla": "vacio" },
		"premio": { "arroz": 5 } },
	{ "id": "t47", "nombre": "Fondo del Sin Repetir", "dificultad": "dificil",
		"tipo": "sin_repetir", "n": 25,
		"mods": { "paciencia": 1.4, "tiempo": 90 },
		"premio": { "lingotes": 4 } },
	{ "id": "t48", "nombre": "Barra del Maridaje Maestro", "dificultad": "dificil",
		"tipo": "maridajes", "n": 18,
		"mods": { "paciencia": 1.3, "bocado": 1.35, "vidas": 2, "falla": "cubo" },
		"premio": { "lingotes": 4 } },
	{ "id": "t49", "nombre": "Sondaleza del Capitán Lleno", "dificultad": "dificil",
		"tipo": "cliente_lleno", "n": 12,
		"mods": { "paciencia": 1.45, "bocado": 1.25 },
		"premio": { "lingotes": 5 } },
	{ "id": "t50", "nombre": "Último Fondeadero", "dificultad": "dificil",
		"tipo": "platos_tiempo", "n": 50, "t": 150,
		"mods": { "paciencia": 1.35, "vidas": 1, "falla": "vacio" },
		"premio": { "lingotes": 6, "arroz": 5 } },
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
