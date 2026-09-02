class_name RecipeData
## Datos estáticos de las recetas del prototipo.
##
## Cada receta tiene un nivel (1 sencillo, 2 medio, 3 elaborado) que define
## sus puntos de saciedad, y una secuencia de pasos de elaboración.
## "free_uses": al completar la receta manualmente, las siguientes N
## elaboraciones de esa misma receta son instantáneas (receta dominada).
##
## Tipos de paso:
##  - tap_ingredient: pulsar un ingrediente. { "ingredient": id }
##  - tap_board: pulsar la tabla N veces. { "count": N }
##  - drag_ingredient: arrastrar un ingrediente a la preparación. { "ingredient": id }
##  - swipe_board: deslizar sobre la tabla N veces. { "count": N, "direction": "down"|"up" }
##  - hold_board: mantener pulsada la tabla. { "duration": segundos }
##  - stir_board: remover en círculos sin soltar sobre la etapa. { "count": vueltas }
##  - slice_board: corte LENTO de izquierda a derecha por todo el ancho de la
##    tabla; la barra se llena según el avance horizontal del cursor. Debe
##    tardar AL MENOS "duration" s en recorrerlo; si va más rápido aparece
##    "¡Más lento!" y hay que repetir. { "count": N, "duration": s }
##  - drag_stage: aparece un utensilio ("prop", sprite de assets/stages) a la
##    derecha de la tabla y hay que arrastrar el sprite de etapa hasta él. { "prop": id }
##    Con "from" se arrastra OTRO sprite en vez del resultado del paso anterior:
##    en el tsuke don el paso previo deja montado el cuenco de arroz (que es el
##    destino) y lo que se coge es el salmón que reposaba en la soja. La etapa
##    del paso anterior se ve un instante y luego cambia sola al sprite "from".
##  - use_stored: montar un combinado con platos YA GUARDADOS: hay que arrastrar
##    N platos desde las cajas hasta la tabla. { "count": N, "prop"?: bandeja }
##
## Extras de algunos pasos:
##  - "prop" en drag_ingredient: el ingrediente se suelta SOBRE ese utensilio
##    (el cuenco del edamame), no sobre la tabla entera.
##  - "direction": "diag" en swipe_board: enrollado en cono (temaki), exige
##    bajar y avanzar a la vez.
##  - "fail_cancels" en slice_board: cortar deprisa ARRUINA el plato (fugu);
##    se pierde la elaboración y entra el cooldown.
##
## "patience_mult": escala cuánta paciencia recarga el plato al comerlo
##   (client.gd::PATIENCE_FOOD). 1.0 por defecto; makis/futomaki 0.8 (recargan
##   x0.2 menos), sopa de miso 1.2, gunkan de tartar 1.1.
## "eat_mult": escala el tiempo que tarda el cliente en comer el plato
##   (client.gd::EAT_TIMES). 1.0 por defecto; sopa de miso tarda más (1.5).
## "tip_chance_bonus": suma a la probabilidad de propina del cliente la 1ª vez
##   que come este plato; cada repetición del MISMO plato suma la MITAD que la
##   anterior (tartar 3% > 1.5% > 0.75%...). Se aplica en client.gd::_roll_tip.
## "snack": true = plato de PICOTEO. El cliente puede cogerlo aunque esté
##   comiendo otro plato: le recarga la paciencia al instante sin interrumpir
##   la comida en curso y paga +SNACK_BONUS doblones extra (client3d.gd).
## "take_chance": fuerza la probabilidad de coger el plato, ignorando la matriz
##   TAKE_CHANCES. Admite un número (igual para los tres tipos: el edamame es un
##   acompañamiento que pica todo el mundo) o un diccionario {E,A,G} con uno por
##   tipo (el onigiri lo comen los tres, pero es plato de grumete).
## "take_chances": sustituye la matriz ENTERA por tipo × nivel. Lo usa el barco
##   combinado (BOAT_TAKE_CHANCES), que se coge mucho más que un plato suelto
##   del mismo nivel. Se indexa por el nivel REAL del plato, así que el barco
##   usa el que sale de su contenido.
## "snack_refill": cuánto alarga el bocado en curso un picoteo, como fracción
##   de su duración (por defecto client3d.SNACK_EAT_REFILL). El gari lo deja
##   casi a cero porque su gracia es la propina, no el tiempo.
## "clears_boredom": el picoteo REINICIA el arco de variedad (té verde): el
##   historial del cliente se limpia — todos los platos vuelven a contar como
##   nuevos — pero el multiplicador cae a cero. Reconstruir, no continuar.
## "variety_worth": cuántos puntos de variedad suma este plato al arco del
##   cliente (1 por defecto; el barco combinado vale 2).
##
## Un cliente solo pica UN plato de picoteo por cada plato que se come; hasta
## que no termina ese plato no vuelve a coger otro (client3d.snack_taken).
##
## Campos de la TANDA DEL MAR 2 (24-8-2026):
## "snack_price": lo que paga el plato cuando se come DE PICOTEO, en vez de
##   price + SNACK_BONUS. El edamame vale 1 como plato suelto y 3 picoteado:
##   su sitio es acompañar, y el juego paga por usarlo bien.
## "extra_snack": este picoteo NO gasta el turno de picoteo del bocado — entra
##   ADEMÁS del picoteo normal, en cualquier orden (el bol de arroz). Él
##   también es uno por bocado (client3d.extra_snack_taken).
## "next_take_bonus": quien lo come suma esa probabilidad al dado del
##   SIGUIENTE plato que le pase por delante, hasta que coja uno (la caballa).
## "neighbor_mult": al empezar a comerlo, los clientes de las sillas PEGADAS
##   suben/bajan esos puntos de multiplicador (el barbo ahumado: -3, y el que
##   lo come gana +3 via variety_worth).
## "servings": plato COMPARTIDO — tras cogerlo un cliente se queda en la
##   cinta (menguado) hasta que lo rematan N clientes; cada uno paga "price"
##   (el takoyaki).
##
## Las SEIS mecanicas de la segunda tanda (todas en client3d._scan_belt y
## _apply_meal_patience; las llevan sobre todo las MEJORAS de receta):
## "frescura": el precio baja con la cinta recorrida — recien servido paga
##   x1,3, a media vuelta x1,0 y al final de la vuelta x0,7. Cogido por el
##   primer cliente que alcanza paga lo maximo; por el octavo, lo minimo.
## "marinado": lo contrario — el plato REPOSA en la cinta y gana valor:
##   x0,7 recien hecho, x1,0 a media vuelta, x1,3 al final.
## "contagio": fraccion (con signo) de la paciencia MAXIMA que ganan o
##   pierden TODOS los demas sentados cuando alguien lo come (-0.08 = el
##   resto pierde un 8%: reconforta tanto que da envidia).
## "maridaje": { "con": [ids], "bono": N } — si el ULTIMO plato que comio el
##   cliente esta en la lista, este paga N doblones extra.
## "talla": "<pez del album>" — el precio escala con el RECORD de talla de
##   ese pez (hasta +50% con el record al maximo): la pesca alimenta la carta.
## "riesgo": el cliente que FALLA el dado pierde paciencia (RIESGO_DESPRECIO
##   de su maximo); el que lo coge la rellena ENTERA.
##
## "fama" / "fama_max" (idea del usuario, 25-8-2026): LA REPUTACION DEL PLATO.
##   Cada plato de esta receta SERVIDO en la jornada sube su propio dado un
##   `fama` (0.005 = medio punto), con tope `fama_max`. Es la respuesta al
##   "mejor dado" plano de las coronas, que era un premio invisible: aqui el
##   dado MEJORA MIENTRAS JUEGAS y se ve en la barra (a los 20 platos, el
##   nigiri de salmon lo coge el 100% de los grumetes).
##   · Va POR RECETA y POR JORNADA (level3d.platos_receta), no por cliente.
##   · Y es la TENSION con el hastio, que es lo que la hace interesante: la
##     fama premia servir MUCHO el mismo plato, el hastio castiga
##     REPETIRSELO al mismo comensal. La jugada buena es repartirlo entre
##     bocas, que es justo la lectura que el juego quiere ensenar.

## "cost": precio en doblones de 1 USO en la tienda (un uso = un nivel jugado
## con recetas que lleven ese ingrediente). El arroz es infinito (cost 0, no se
## vende ni consume usos).
const INGREDIENTS: Dictionary = {
	"arroz": { "name": "Arroz", "short": "Arroz", "color": Color(0.93, 0.92, 0.85), "cost": 0 },
	# LA HARINA Y LA MASA DE TEMPURA no estaban declaradas y las usan la
	# tempura y el takoyaki: sin ficha, su chapa en la tabla salia con el id
	# crudo ("¡Sin harina!" en vez de "¡Sin Harina!") y sin color. Van a
	# COSTE 0, que es como se comportaban ya: al no estar en la tabla,
	# `ingredients_for_selection` las trataba como gratis.
	"harina": { "name": "Harina", "short": "Harin", "color": Color(0.95, 0.92, 0.82), "cost": 0 },
	"masa_tempura": { "name": "Masa de tempura", "short": "Masa", "color": Color(0.96, 0.90, 0.70), "cost": 0 },
	"aguacate": { "name": "Aguacate", "short": "Aguac", "color": Color(0.45, 0.75, 0.35), "cost": 15 },
	"salmon": { "name": "Salmón", "short": "Salm", "color": Color(1.0, 0.55, 0.45), "cost": 23 },
	"wakame": { "name": "Wakame", "short": "Wak", "color": Color(0.2, 0.5, 0.35), "cost": 15 },
	"atun": { "name": "Atún", "short": "Atún", "color": Color(0.85, 0.3, 0.35), "cost": 23 },
	"agua": { "name": "Agua", "short": "Agua", "color": Color(0.45, 0.65, 1.0), "cost": 3 },
	"miso": { "name": "Pasta miso", "short": "Miso", "color": Color(0.65, 0.5, 0.3), "cost": 8 },
	"tofu": { "name": "Tofu", "short": "Tofu", "color": Color(0.97, 0.94, 0.86), "cost": 15 },
	"huevo": { "name": "Huevo", "short": "Huevo", "color": Color(0.9, 0.78, 0.55), "cost": 3 },
	"gamba": { "name": "Gamba", "short": "Gamba", "color": Color(1.0, 0.6, 0.45), "cost": 8 },
	"tofu_frito": { "name": "Tofu frito", "short": "Inari", "color": Color(0.85, 0.65, 0.35), "cost": 5 },
	"atun_rojo": { "name": "Atún rojo", "short": "AtRojo", "color": Color(0.55, 0.12, 0.18), "cost": 30 },
	"nori": { "name": "Alga nori", "short": "Nori", "color": Color(0.12, 0.22, 0.14), "cost": 8 },
	"pepino": { "name": "Pepino", "short": "Pepino", "color": Color(0.35, 0.62, 0.28), "cost": 8 },
	"huevas": { "name": "Huevas de salmón", "short": "Huevas", "color": Color(0.95, 0.45, 0.12), "cost": 23 },
	"edamame": { "name": "Edamame", "short": "Edam", "color": Color(0.48, 0.75, 0.25), "cost": 5 },
	"fideos": { "name": "Fideos udon", "short": "Fideos", "color": Color(0.94, 0.92, 0.84), "cost": 8 },
	# --- EXTRAS: no son platos, se añaden ENCIMA de un plato ya emplatado y
	# gastan una unidad POR PLATO (no por partida como el resto). Ver EXTRAS.
	"jengibre": { "name": "Jengibre", "short": "Jengib", "color": Color(0.95, 0.72, 0.72),
		"cost": 10, "extra": true },
	"wasabi": { "name": "Wasabi", "short": "Wasabi", "color": Color(0.55, 0.8, 0.3),
		"cost": 10, "extra": true },
	"soja": { "name": "Salsa de soja", "short": "Soja", "color": Color(0.3, 0.18, 0.1),
		"cost": 10, "extra": true },
	"te": { "name": "Hojas de té", "short": "Té", "color": Color(0.42, 0.68, 0.3), "cost": 3 },
	"fugu": { "name": "Pez globo", "short": "Fugu", "color": Color(0.85, 0.85, 0.88), "cost": 45 },
	# "stock_id": gasta usos de OTRO ingrediente. El atún cocido sale de la
	# misma lata que el crudo, así que en la despensa no ocupa una línea aparte.
	"atun_cocido": { "name": "Atún cocido", "short": "AtCoc", "color": Color(0.78, 0.6, 0.42),
		"cost": 15, "stock_id": "atun" },
	# --- Postres y anguila (mochi, dorayaki, taiyaki, unagi) ---
	"masa_mochi": { "name": "Masa de mochi", "short": "Masa", "color": Color(0.95, 0.94, 0.90),
		"cost": 8 },
	"judias_rojas": { "name": "Judías rojas", "short": "Judías", "color": Color(0.45, 0.12, 0.16),
		"cost": 8 },
	"bollo_dorayaki": { "name": "Bollo de dorayaki", "short": "Bollo",
		"color": Color(0.83, 0.60, 0.30), "cost": 12 },
	"masa_taiyaki": { "name": "Masa de taiyaki", "short": "MasaT",
		"color": Color(0.95, 0.88, 0.62), "cost": 8 },
	"chocolate": { "name": "Chocolate", "short": "Choco", "color": Color(0.28, 0.16, 0.10),
		"cost": 15 },
	"unagi": { "name": "Anguila", "short": "Unagi", "color": Color(0.45, 0.24, 0.12),
		"cost": 26 },
	"salsa_unagi": { "name": "Salsa tare", "short": "Tare", "color": Color(0.22, 0.12, 0.06),
		"cost": 2 },
	"matcha": { "name": "Té matcha", "short": "Matcha", "color": Color(0.42, 0.68, 0.28),
		"cost": 10 },
	"katsuobushi": { "name": "Bonito seco", "short": "Bonito", "color": Color(0.80, 0.55, 0.42),
		"cost": 3 },
	"kanikama": { "name": "Palitos de cangrejo", "short": "Kanik", "color": Color(0.95, 0.52, 0.38),
		"cost": 10 },
	"pulpo": { "name": "Pulpo", "short": "Pulpo", "color": Color(0.68, 0.30, 0.38), "cost": 20 },
	"wagyu": { "name": "Wagyu", "short": "Wagyu", "color": Color(0.72, 0.22, 0.24), "cost": 38 },
	# --- Pescado y género de la tanda del MAR 2 ---
	"caballa": { "name": "Caballa", "short": "Cabal", "color": Color(0.55, 0.62, 0.72), "cost": 12 },
	"besugo": { "name": "Besugo", "short": "Besu", "color": Color(0.88, 0.55, 0.50), "cost": 15 },
	"pargo": { "name": "Pargo", "short": "Pargo", "color": Color(0.85, 0.35, 0.30), "cost": 25 },
	"jurel": { "name": "Jurel", "short": "Jurel", "color": Color(0.60, 0.68, 0.60), "cost": 10 },
	"barbo": { "name": "Barbo", "short": "Barbo", "color": Color(0.62, 0.45, 0.30), "cost": 14 },
	"shiitake": { "name": "Seta shiitake", "short": "Shiit", "color": Color(0.55, 0.40, 0.28), "cost": 8 },
	"masa_gyoza": { "name": "Masa de gyoza", "short": "MasaG", "color": Color(0.93, 0.90, 0.82), "cost": 6 },
	"carne_picada": { "name": "Carne picada", "short": "Carne", "color": Color(0.72, 0.38, 0.35), "cost": 12 },
	# La ventresca sale de la misma lata que el atun (stock_id, como el cocido).
	"toro": { "name": "Toro de aleta amarilla", "short": "Toro", "color": Color(0.95, 0.62, 0.55),
		"cost": 23, "stock_id": "atun" },
	# Gratis como el arroz (cost 0): no se compra ni gasta usos.
	"sesamo": { "name": "Sésamo", "short": "Sésamo", "color": Color(0.92, 0.88, 0.78), "cost": 0 },
	"sal": { "name": "Sal", "short": "Sal", "color": Color(0.96, 0.96, 0.94), "cost": 0 },
	# --- Ingredientes de MEJORA (ver UPGRADES): solo coronan platos hechos ---
	# CUESTAN 3 (o menos), y no es un capricho: la coronacion gasta 1 uso POR
	# PLATO, no por jornada como el resto de la despensa, asi que un
	# ingrediente de 10-23 hacia que coronar PERDIERA dinero en 11 de las 13
	# coronas. Un ingrediente de coronacion nuevo entra en este escalon.
	# Por lo mismo NINGUNA corona usa ya un ingrediente compartido y caro (las
	# huevas de 23, o los extras de 10): tienen gemelo barato propio.
	"mayonesa_japonesa": { "name": "Mayonesa japonesa", "short": "Mayo", "color": Color(0.96, 0.93, 0.82), "cost": 2 },
	"cebolla_frita": { "name": "Cebolla frita", "short": "CebFr", "color": Color(0.82, 0.6, 0.3), "cost": 2 },
	"soja_cocina": { "name": "Soja de cocinar", "short": "SojaC", "color": Color(0.34, 0.20, 0.11), "cost": 2 },
	# La TIRA de nori de coronar, distinta del alga de 8 con la que se lian
	# los makis: aquella se gasta 1 uso por JORNADA y esta 1 por PLATO, asi
	# que no pueden compartir precio (con el alga cara, coronar perdia 5).
	"nori_tira": { "name": "Tira de nori", "short": "TiraN", "color": Color(0.12, 0.22, 0.14), "cost": 2 },
	"huevas_capelan": { "name": "Huevas de capelán", "short": "Masago", "color": Color(0.98, 0.58, 0.20), "cost": 2 },
	"vinagre_arroz": { "name": "Vinagre de arroz", "short": "Vinag", "color": Color(0.94, 0.90, 0.76), "cost": 2 },
	"sal_yuzu": { "name": "Sal de yuzu", "short": "SalYu", "color": Color(0.95, 0.92, 0.62), "cost": 2 },
}

## COMBINACIONES: dos platos YA GUARDADOS en las cajas que se funden en uno
## solo. A diferencia del barco combinado (que admite cualquier surtido de
## BOAT_DISHES), cada combo exige una pareja EXACTA, una unidad de cada parte.
## El precio del resultado es la SUMA de las partes más `bonus`.
const COMBOS: Dictionary = {
	"udon_tempura": { "parts": ["udon", "tempura"], "bonus": 3 },
}

## EXTRAS que el jugador puede añadir a CUALQUIER plato justo antes de
## mandarlo a la cinta. No dan dinero: cambian cómo reacciona el cliente.
## Se gastan por PLATO servido, no por partida, y cuestan 10 doblones el uso.
const EXTRAS := ["jengibre", "wasabi", "soja"]

## MEJORAS DE RECETA (mar 2): una receta TERMINADA sobre la tabla puede
## CORONARSE con dos ingredientes extra que la transforman en su version
## mejorada — otra receta (oculta: no se elige, se fabrica transformando),
## con mas precio y mejor dado en TODOS los tipos de cliente. La mejorada
## cuenta como PLATO DISTINTO para la variedad y el hastio (id propio), y el
## cooldown sigue siendo el de la receta base (via ready_base, como el aburi).
## Cada mejora se GANA en un escenario (campo `reward_upgrade_3` del puerto) y
## la presenta Alice en el mapa (main_menu._presentar_mejora).
## Una mejora puede coronar con UNO o DOS ingredientes: los botones de la
## tabla y la transformacion recorren la lista, sea del largo que sea.
const UPGRADES := {
	"maki_aguacate": {
		"id": "maki_aguacate_mejorado",
		"ingredients": ["mayonesa_japonesa", "cebolla_frita"],
	},
	"nigiri_salmon": {
		"id": "nigiri_salmon_mejorado",
		"ingredients": ["huevas_capelan"],
	},
	"nigiri_pulpo": {
		"id": "nigiri_pulpo_mejorado",
		"ingredients": ["nori_tira"],
	},
	"bol_arroz": {
		"id": "bol_arroz_mejorado",
		"ingredients": ["nori_tira"],
	},
	# El yaki onigiri ES la corona del onigiri (con soja y a la plancha).
	"onigiri": {
		"id": "yaki_onigiri",
		"ingredients": ["soja_cocina"],
	},
	# --- MEJORAS CON MECANICA (tanda 2 del 24-8-2026): cada una sube el
	# precio Y estrena una de las seis mecanicas nuevas. Las cuatro ultimas
	# aun no tienen puerto que las regale: quedan para el MAR 3.
	"maki_pepino": {
		"id": "maki_pepino_sesamo",
		"ingredients": ["soja_cocina", "sesamo"],
	},
	"nigiri_atun": {
		"id": "zuke_atun",
		"ingredients": ["soja_cocina"],
	},
	"caldo_dashi": {
		"id": "dashi_ahumado",
		"ingredients": ["katsuobushi"],
	},
	"fugu": {
		"id": "fugu_valiente",
		"ingredients": ["sal"],
	},
	"nigiri_caballa": {
		"id": "shime_saba",
		"ingredients": ["vinagre_arroz"],
	},
	"tempura": {
		"id": "tempura_dorada",
		"ingredients": ["sal"],
	},
	"nigiri_anguila": {
		"id": "unagi_doble",
		"ingredients": ["salsa_unagi"],
	},
	"sashimi_atun_rojo": {
		"id": "sashimi_patron",
		"ingredients": ["sal_yuzu"],
	},
}


## La mejora de una receta, o {} si no tiene (o no esta ganada: el filtro del
## desbloqueo lo pone GameState.upgrade_unlocked, no estos datos).
static func upgrade_of(recipe_id: String) -> Dictionary:
	return UPGRADES.get(recipe_id, {})
## LOS TRES hacen que el plato cuente como NUEVO aunque el cliente ya lo haya
## probado (alarga la racha de variedad y cobra el bono de oro), y LOS TRES
## traen una contrapartida que va justo contra lo que el sistema premia. Se
## aplican en client3d (ver su bloque EXTRAS):
##  - jengibre  → reinicia el PALADAR entero (todo vuelve a ser nuevo, este
##                plato incluido), pero BAJA un punto de multiplicador.
##  - wasabi    → +15% de PROBABILIDAD de propina; a cambio, en vez de
##                recargar paciencia, DRENA lo que habría recargado.
##  - soja      → +15% de CUANTÍA de la propina; a cambio, el bocado corre
##                más (SOJA_BITE_SPEED) y el cliente vuelve antes a la cola.
const EXTRA_TIP_CHANCE := 0.15
const EXTRA_TIP_AMOUNT := 1.15

## FREÍR (paso "fry_board"): el jugador mantiene pulsado y suelta cuando cree
## que está en su punto. Cada franja da un resultado distinto; fuera de todas
## ellas el plato se tira. Se lee de arriba abajo, la primera que encaja gana.
##  "to": límite superior de la franja · "price": lo que vale (0 = a la basura)
##  "dish": sprite del plato resultante · "label": aviso al jugador
## "color": del aviso que aparece sobre el plato (verde = bien, dorado =
## perfecto, naranja = regular, rojo = a la basura).
## El punto bueno está en 2.00 s, no en 3.00: tres segundos con el dedo pegado
## a la sartén eran tres segundos de las 150 del turno con el ÚNICO hueco de
## cocina ocupado sin hacer nada, y salían de la propia tempura (era la receta
## con peor rendimiento de la carta). Las franjas se reescalaron enteras a 2/3.
const FRY_WINDOWS := [
	{ "to": 1.20, "price": 0, "dish": "tempura_cruda", "label": "¡Cruda!",
		"color": Color(1.0, 0.36, 0.30) },
	{ "to": 1.67, "price": 7, "dish": "tempura_cruda", "label": "Poco hecha",
		"color": Color(1.0, 0.72, 0.30) },
	{ "to": 1.99, "price": 12, "dish": "tempura", "label": "¡Buen punto!",
		"color": Color(0.45, 0.95, 0.45) },
	{ "to": 2.01, "price": 20, "dish": "tempura", "label": "¡Perfecto!",
		"color": Color(1.0, 0.85, 0.25) },
	{ "to": 2.16, "price": 12, "dish": "tempura", "label": "¡Buen punto!",
		"color": Color(0.45, 0.95, 0.45) },
	{ "to": 3.00, "price": 7, "dish": "tempura_quemada", "label": "Pasada",
		"color": Color(1.0, 0.72, 0.30) },
	{ "to": 999.0, "price": 0, "dish": "tempura_quemada", "label": "¡Quemada!",
		"color": Color(1.0, 0.36, 0.30) },
]
## Lo que paga la franja del punto EXACTO (la mejor de todas). El logro de la
## tempura perfecta lo mira para no depender del orden de la lista.
const FRY_BEST_PRICE := 20

## Franjas del SOPLETE del nigiri de wagyu. Mismo trato: nunca se pierde el
## plato, solo cambia lo que paga. Clavarlo en 2.00 s dobla el precio bueno.
const WAGYU_WINDOWS := [
	{ "to": 1.50, "price": 12, "dish": "nigiri_wagyu", "label": "Poco hecho",
		"color": Color(1.0, 0.72, 0.30) },
	{ "to": 1.99, "price": 16, "dish": "nigiri_wagyu", "label": "¡Buen punto!",
		"color": Color(0.45, 0.95, 0.45) },
	{ "to": 2.01, "price": 30, "dish": "nigiri_wagyu", "label": "¡Perfecto!",
		"color": Color(1.0, 0.85, 0.25) },
	{ "to": 2.50, "price": 16, "dish": "nigiri_wagyu", "label": "¡Buen punto!",
		"color": Color(0.45, 0.95, 0.45) },
	{ "to": 999.0, "price": 12, "dish": "nigiri_wagyu", "label": "Muy hecho",
		"color": Color(1.0, 0.72, 0.30) },
]

## Franjas del SOPLETE del nigiri de besugo (punto en 1,5 s, no en 2). Aquí el
## punto no mueve tanto el PRECIO como la PROPINA: cada franja sirve una
## variante con su propio `tip_chance_bonus` (+8% → +15% → +25% clavándolo),
## el mismo truco de las variantes de la tempura, así que acercarse al punto
## hace la propina más probable sin una gota de plomería nueva. Pasarse o
## quedarse corto no tira el plato: lo deja a 4 doblones y sin bono.
const BESUGO_WINDOWS := [
	{ "to": 1.00, "price": 4, "dish": "nigiri_besugo_palido", "label": "Crudo",
		"color": Color(1.0, 0.72, 0.30) },
	{ "to": 1.30, "price": 7, "dish": "nigiri_besugo", "label": "¡Buen punto!",
		"color": Color(0.45, 0.95, 0.45) },
	{ "to": 1.44, "price": 8, "dish": "nigiri_besugo_dorado", "label": "¡Casi perfecto!",
		"color": Color(0.45, 0.95, 0.45) },
	{ "to": 1.56, "price": 9, "dish": "nigiri_besugo_perfecto", "label": "¡Perfecto!",
		"color": Color(1.0, 0.85, 0.25) },
	{ "to": 1.70, "price": 8, "dish": "nigiri_besugo_dorado", "label": "¡Casi perfecto!",
		"color": Color(0.45, 0.95, 0.45) },
	{ "to": 2.00, "price": 7, "dish": "nigiri_besugo", "label": "¡Buen punto!",
		"color": Color(0.45, 0.95, 0.45) },
	{ "to": 999.0, "price": 4, "dish": "nigiri_besugo_palido", "label": "Quemado",
		"color": Color(1.0, 0.72, 0.30) },
]

## EL RITMO DEL JUEGO (25-8-2026, pedido por el usuario: "que el juego sea
## más lento, que dé tiempo a pararse a pensar qué hacer y cómo hacerlo").
##
## `RITMO_COOLDOWN` estira TODOS los enfriamientos de la carta a la vez, y va
## aquí y no en cada receta para que la escala por nivel documentada (L1 3-4 s,
## L2 4.5-5.5, L3 6.5-7.5) siga siendo la de los datos y solo se multiplique.
##
## OJO CON LO QUE HACE Y LO QUE NO: con CUATRO recetas en la carta el jugador
## rota, así que un cooldown por debajo de ~4x el tiempo de gestos NO recorta
## la producción — lo que recorta es la posibilidad de SPAMEAR una sola receta.
## Eso es justo lo que se busca ("pararse a pensar QUÉ se hace") y es también
## la razón de que el reloj del abordaje y los `star_money` NO haya que
## recalibrarlos: el número de platos por turno apenas se mueve.
## Sus hermanas viven en client3d (RITMO_PACIENCIA y RITMO_BOCADO), que son
## las que de verdad quitan la prisa.
const RITMO_COOLDOWN := 1.4


## El enfriamiento REAL de una receta (su dato por el ritmo del juego). Lo
## usan la tabla, la ficha del recetario y el selector: si alguien leyera el
## campo a pelo, la ficha mentiría.
static func cooldown_of(recipe_id: String) -> float:
	return float(get_recipe(recipe_id).get("cooldown", 0.0)) * RITMO_COOLDOWN


## Matriz PROPIA del barco combinado (campo "take_chances" de la receta). Un
## barco no es un plato más: es una bandeja para compartir, así que entra por
## los ojos a todo el mundo y casi nadie la deja pasar. Se indexa por el nivel
## REAL del barco, que sale de los platos que lleva dentro (level_override),
## no por el nivel nominal de la receta.
const BOAT_TAKE_CHANCES: Dictionary = {
	"E": { 1: 1.00, 2: 0.60, 3: 0.30 },
	"A": { 1: 0.80, 2: 1.00, 3: 0.70 },
	"G": { 1: 0.60, 2: 0.80, 3: 1.00 },
}

const RECIPES: Dictionary = {
	"maki_aguacate": {
		"label": "MaGua",
		"name": "Maki de aguacate",
		"level": 1,
		"satiety": 1,
		"cooldown": 3.0,
		"price": 3,
		"patience_mult": 0.8,
		"free_uses": 2,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "aguacate" },
			{ "type": "swipe_board", "count": 2, "direction": "down" },
			{ "type": "tap_board", "count": 2, "cutting": true },
		],
		"stages": ["arroz_bola", "arroz_plano", "plano_aguacate", "rollo_aguacate", "corte_aguacate"],
	},
	"maki_pepino": {
		"label": "MaPep",
		"name": "Maki de pepino",
		"level": 1,
		"satiety": 1,
		"cooldown": 3.0,
		# CUATRO piezas por elaboración (la de mano + 3 de maestría) frente a las
		# tres del maki de aguacate, a cambio de pagar 2 en vez de 3. Es la ÚNICA
		# receta con `free_uses` 3 de toda la carta: por eso su precio POR PIEZA es
		# el más bajo que hay (8 doblones por elaboración, contra los 9 del maki de
		# aguacate, y con un paso más de trabajo). Ver el calibrado por $/s.
		"price": 2,
		"patience_mult": 0.8,
		"free_uses": 3,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "tap_ingredient", "ingredient": "pepino" },
			# Aquí está la diferencia con el maki de aguacate: el pepino NO se
			# arrastra entero, se CORTA en bastones sobre el arroz.
			{ "type": "tap_board", "count": 3, "cutting": true },
			{ "type": "swipe_board", "count": 2, "direction": "down" },
			{ "type": "tap_board", "count": 2, "cutting": true },
		],
		"stages": ["arroz_bola", "arroz_plano", "plano_pepino", "plano_pepino_cort",
			"rollo_pepino", ""],
	},
	"nigiri_salmon": {
		"label": "NiSal",
		"name": "Nigiri de salmón",
		"level": 1,
		"satiety": 1,
		"cooldown": 3.0,
		"price": 4,
		# FAMA: el plato de la casa. Cada uno que sale sube su propio dado, y
		# a los 20 servidos ningun grumete lo deja pasar. Es el primer plato
		# "de verdad" del juego, asi que es el que ensena la tension entre
		# servir mucho de lo mismo (fama) y repetirselo a uno (hastio).
		"fama": 0.005,
		"fama_max": 0.10,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "salmon" },
		],
		"stages": ["arroz_bola", "nigiri_base", ""],
	},
	"gunkan_wakame": {
		"label": "GuWak",
		"name": "Gunkan de wakame",
		"level": 1,
		"satiety": 1,
		"cooldown": 3.5,
		"price": 4,
		# EL BARATO QUE LLENA: recarga un 25% mas que un plato de su nivel.
		# Es el plato de rescate — el que se le sirve al que esta en rojo.
		"patience_mult": 1.25,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "wakame" },
		],
		"stages": ["arroz_bola", "gunkan_base", ""],
	},
	"maki_atun": {
		"label": "MaAtu",
		"name": "Maki de atún",
		"level": 2,
		"satiety": 2,
		"cooldown": 4.5,
		"price": 5,
		"patience_mult": 0.8,
		"free_uses": 2,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "nori" },
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "atun" },
			{ "type": "swipe_board", "count": 3, "direction": "down" },
			{ "type": "tap_board", "count": 3, "cutting": true },
		],
		"stages": ["nori_tabla", "nori_arroz_bola", "nori_arroz", "nori_atun", "rollo_atun", ""],
	},
	"sopa_miso": {
		"label": "SoMis",
		"name": "Sopa de miso",
		"level": 1,
		"satiety": 1,
		"cooldown": 5.5,
		"price": 7,
		"patience_mult": 1.2,
		"eat_mult": 1.5,
		# LIMPIA EL PALADAR como el té verde (todo vuelve a contar como nuevo)
		# pero NO sube el multiplicador: es el reinicio en versión plato
		# principal — cuesta un hueco de carta y una elaboración larga, y a
		# cambio se cobra como plato en vez de valer 1 doblón.
		"clears_boredom": true,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "agua" },
			{ "type": "hold_board", "duration": 1.2 },
			{ "type": "drag_ingredient", "ingredient": "miso" },
			{ "type": "tap_ingredient", "ingredient": "tofu" },
			{ "type": "tap_board", "count": 2 },
		],
		"stages": ["bol_agua", "bol_agua", "bol_miso", "bol_miso", "bol_miso"],
	},
	"futomaki_salmon": {
		"label": "FuSal",
		"name": "Futomaki de salmón",
		"level": 3,
		"satiety": 3,
		"cooldown": 6.5,
		"price": 6,
		"patience_mult": 0.8,
		"free_uses": 2,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "salmon" },
			{ "type": "drag_ingredient", "ingredient": "wakame" },
			{ "type": "swipe_board", "count": 3, "direction": "up" },
			{ "type": "tap_board", "count": 3, "cutting": true },
		],
		"stages": ["arroz_bola", "arroz_plano", "plano_salmon", "plano_futomaki", "rollo_futomaki", "corte_futomaki"],
	},
	"nigiri_atun": {
		"label": "NiAtu",
		"name": "Nigiri de atún",
		"level": 2,
		"satiety": 2,
		"cooldown": 5.0,
		"price": 5,
		# EL CLASICO CUENTA DOBLE: sube DOS puntos de multiplicador, como el
		# barco. Tres pasos y una herramienta de variedad de verdad — es lo
		# que hace que el nigiri mas soso de la carta valga un hueco.
		"variety_worth": 2,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "atun" },
		],
		"stages": ["arroz_bola", "nigiri_base", ""],
	},
	"nigiri_inari": {
		"label": "NiIna",
		"name": "Nigiri de tofu frito",
		"level": 2,
		"satiety": 2,
		"cooldown": 5.0,
		"price": 5,
		# CONGELA LA PACIENCIA 3 s (la anguila la congela 5, pero cuesta el
		# doble y llega mucho mas tarde): el inari es la version barata y
		# temprana de esa jugada, y da un segundo uso a una mecanica que
		# tenia un solo plato en todo el juego.
		"patience_freeze": 3.0,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "tofu_frito" },
		],
		"stages": ["arroz_bola", "nigiri_base", ""],
	},
	"sashimi_tamago": {
		"label": "SaTam",
		"name": "Sashimi de tortilla tamago",
		"level": 2,
		"satiety": 2,
		"cooldown": 5.5,
		"price": 5,
		"free_uses": 2,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "huevo" },
			{ "type": "tap_board", "count": 2 },
			{ "type": "stir_board", "count": 2 },
			{ "type": "drag_stage", "prop": "sarten" },
			{ "type": "hold_board", "duration": 1.0 },
			{ "type": "tap_board", "count": 3, "cutting": true },
		],
		"stages": ["cuenco_huevo", "cuenco_huevo", "cuenco_batido", "sarten_tamago", "tamago_entero", ""],
	},
	"sashimi_atun_rojo": {
		"label": "SaAtu",
		"name": "Sashimi de atún rojo",
		"level": 3,
		"satiety": 3,
		"cooldown": 7.5,
		"price": 8,
		"tip_chance_bonus": 0.04,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "atun_rojo" },
			{ "type": "slice_board", "count": 2, "duration": 0.7, "direction": "right",
				"cut_stage": "corte_atun_rojo", "fail_penalty": 5 },
		],
		"stages": ["bloque_atun_rojo", ""],
	},
	"nigiri_ebi": {
		"label": "NiEbi",
		"name": "Nigiri de gamba ebi",
		"level": 1,
		"satiety": 1,
		"cooldown": 3.5,
		"price": 6,
		# EL L1 DE LAS PROPINAS: es el mas caro y largo de su nivel, y el
		# unico de 1 estrella que toca el bote. Con los potenciadores abiertos
		# ya hay motivo para llevarlo aunque haya nigiris mas baratos.
		"tip_chance_bonus": 0.03,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "tap_ingredient", "ingredient": "gamba" },
			{ "type": "swipe_board", "count": 1, "direction": "down" },
			{ "type": "drag_stage", "prop": "nigiri_base" },
		],
		"stages": ["arroz_bola", "nigiri_base", "gamba_tabla", "gamba_abierta", ""],
	},
	"gunkan_tartar": {
		"label": "GuTar",
		"name": "Tartar de salmón y pepino",
		"level": 2,
		"satiety": 2,
		"cooldown": 5.0,
		"price": 5,
		"free_uses": 1,
		"tip_chance_bonus": 0.03,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "pepino" },
			{ "type": "tap_board", "count": 3, "cutting": true },
			{ "type": "tap_ingredient", "ingredient": "salmon" },
			{ "type": "tap_board", "count": 3, "cutting": true },
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "drag_stage", "prop": "gunkan_base" },
		],
		"stages": ["pepino_tabla", "pepino_cubos", "salmon_pepino", "tartar_mont", "arroz_bola", ""],
	},
	"gunkan_ikura": {
		"label": "GuIku",
		"name": "Gunkan de huevas de salmón",
		"level": 2,
		"satiety": 2,
		"cooldown": 5.5,
		"price": 7,
		# EL LUJO DE SU NIVEL: las huevas son el ingrediente mas caro de la
		# despensa (23 el uso), asi que lo que devuelven es bote.
		"tip_chance_bonus": 0.05,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "nori" },
			{ "type": "drag_ingredient", "ingredient": "huevas" },
		],
		"stages": ["arroz_bola", "arroz_bola", "gunkan_base", ""],
	},
	"hana_maki": {
		"label": "HaMak",
		"name": "Hana maki",
		"level": 3,
		"satiety": 3,
		"cooldown": 7.0,
		"price": 6,
		"free_uses": 2,
		"patience_mult": 1.3,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "aguacate" },
			{ "type": "swipe_board", "count": 2, "direction": "down" },
			{ "type": "drag_ingredient", "ingredient": "salmon" },
			{ "type": "drag_ingredient", "ingredient": "huevas" },
		],
		"stages": ["arroz_bola", "arroz_plano", "plano_aguacate", "rollo_aguacate",
			"hana_salmon", ""],
	},
	"edamame": {
		"label": "Edam",
		"name": "Edamame",
		"level": 1,
		"satiety": 1,
		"cooldown": 2.0,
		"price": 1,
		# Comido como plato suelto paga 1; PICOTEADO (mientras se come otro
		# plato) paga 3. Su sitio es acompañar, y usarlo bien se premia.
		"snack_price": 3,
		"snack": true,
		"take_chance": 0.9,
		"steps": [
			# El cuenco vacío aparece como utensilio y hay que soltarle encima
			# las vainas (con "prop" el destino del arrastre es el cuenco, no
			# la tabla entera).
			{ "type": "drag_ingredient", "ingredient": "edamame", "prop": "cuenco_vacio" },
		],
		"stages": [""],
	},
	"sunomono": {
		"label": "Suno",
		"name": "Sunomono",
		"level": 1,
		"satiety": 1,
		"cooldown": 3.0,
		"price": 2,
		"snack": true,
		"take_chance": 0.9,
		# EL ÚNICO PICOTEO QUE SUMA VARIEDAD. El edamame y el té no tocan la racha
		# del cliente (ni la suben ni la rompen, que son aperitivos); este sí, así
		# que es la manera barata de estirar un multiplicador cuando la carta ya
		# está agotada — y encima se puede picar sin soltar el plato en curso.
		"variety_snack": true,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "pepino" },
			{ "type": "tap_board", "count": 3, "cutting": true },
			{ "type": "drag_stage", "prop": "cuenco_vacio" },
		],
		"stages": ["pepino_tabla", "pepino_rodajas", ""],
	},
	"tempura": {
		"label": "Tempu",
		"name": "Tempura de gamba",
		"level": 2,
		"satiety": 2,
		"cooldown": 5.5,
		"price": 12,
		# MARIDAJE con el udon: ya son pareja de combo, y asi se premia
		# tambien servirlos seguidos sin gastar dos cajas en montarlo.
		"maridaje": { "con": ["udon", "udon_tempura"], "bono": 5 },
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "gamba" },
			{ "type": "swipe_board", "count": 1, "direction": "down" },
			{ "type": "drag_ingredient", "ingredient": "harina" },
			{ "type": "tap_ingredient", "ingredient": "masa_tempura" },
			{ "type": "drag_stage", "prop": "sarten" },
			# FREÍR: el contador corre y hay que soltar en el punto justo.
			# Fuera de las ventanas buenas el plato se tira (ver FRY_WINDOWS).
			{ "type": "fry_board", "target": 2.0 },
		],
		"stages": ["gamba_tabla", "gamba_cortada", "gamba_harina", "gamba_masa",
			"sarten_frito", ""],
	},
	# Variantes de la tempura según el punto de fritura. No se eligen ni
	# aparecen en el selector: las sirve el paso "fry_board" con su precio.
	# MEJORA del maki de aguacate (mayonesa japonesa + cebolla frita por
	# encima): no se elige ni se cocina — se TRANSFORMA desde el maki hecho
	# (ver UPGRADES). Paga mas y lo coge mejor TODO el mundo.
	"maki_aguacate_mejorado": {
		"label": "MaGu+",
		"name": "Maki de aguacate supremo",
		"level": 1, "satiety": 1, "cooldown": 3.0, "price": 7,
		"patience_mult": 0.8,
		# La primera corona del juego, asi que su premio tiene que VERSE: el
		# maki supremo vale DOS puntos de multiplicador, como el barco. Es
		# ademas lo que de verdad hace un maki coronado — estirar la racha.
		"variety_worth": 2,
		"hidden": true, "steps": [], "stages": [],
	},
	"tempura_cruda": {
		"label": "TempC",
		"name": "Tempura poco hecha",
		"level": 2, "satiety": 2, "cooldown": 5.5, "price": 7,
		"hidden": true, "steps": [], "stages": [],
	},
	"tempura_quemada": {
		"label": "TempQ",
		"name": "Tempura pasada",
		"level": 2, "satiety": 2, "cooldown": 5.5, "price": 7,
		"hidden": true, "steps": [], "stages": [],
	},
	"onigiri": {
		"label": "Onigi",
		"name": "Onigiri",
		"level": 1,
		"satiety": 1,
		"cooldown": 3.5,
		"price": 4,
		# Salen DOS bolas en total: la que se hace a mano y una gratis.
		"free_uses": 1,
		# Comida de a bordo: la comen los tres tipos, pero es plato de grumete.
		"take_chance": { "E": 0.85, "A": 0.70, "G": 0.70 },
		# Llena más que un plato de su nivel: es contundente.
		"patience_mult": 1.4,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "atun_cocido" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "nori" },
		],
		"stages": ["arroz_bola", "arroz_plano", "onigiri_relleno", "onigiri_forma", ""],
	},
	"temaki": {
		"label": "Temak",
		"name": "Temaki de salmón",
		"level": 3,
		"satiety": 3,
		"cooldown": 7.0,
		"price": 13,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "nori" },
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "salmon" },
			# El pepino entra ya en bastones: cortarlo aparte eran dos pasos más
			# para un cono que se define por el enrollado, no por el pepino.
			{ "type": "drag_ingredient", "ingredient": "pepino" },
			# Enrollar en CONO: diagonal y con un recorrido largo.
			{ "type": "swipe_board", "count": 2, "direction": "diag", "distance": 190.0 },
		],
		"stages": ["nori_tabla", "nori_arroz_bola", "nori_arroz", "temaki_relleno",
			"temaki_relleno", ""],
	},
	"aburi": {
		"label": "Aburi",
		"name": "Nigiri flambeado",
		"level": 3,
		"satiety": 3,
		"cooldown": 7.0,
		# Precio y efecto de la variante de SALMÓN; eligiendo atún el plato
		# sale como "aburi_atun" (15, propina más gorda).
		"price": 13,
		"tip_chance_bonus": 0.04,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			# ELECCIÓN: salen los dos pescados y se arrastra UNO; el otro
			# desaparece. El elegido decide la identidad del plato final.
			{ "type": "drag_choice", "options": ["salmon", "atun"],
				"stage_by": { "salmon": "aburi_crudo", "atun": "aburi_crudo_atun" },
				"result_by": { "salmon": "", "atun": "aburi_atun" } },
			# El soplete sigue al dedo: hay que MANTENER Y MOVER para tostar.
			{ "type": "hold_board", "duration": 2.0, "prop": "soplete", "move": true },
		],
		"stages": ["arroz_bola", "nigiri_base", "aburi_crudo", ""],
	},
	# Variante del flambeado con atún: no se elige en el selector, sale del
	# paso drag_choice del aburi. Más cara y con la propina más GORDA (el de
	# salmón la hace más PROBABLE).
	"aburi_atun": {
		"label": "AbuAt",
		"name": "Nigiri flambeado de atún",
		"level": 3, "satiety": 3, "cooldown": 7.0, "price": 16,
		"tip_amount_mult": 1.15,
		"hidden": true, "steps": [], "stages": [],
	},
	"chirashi": {
		"label": "Chira",
		"name": "Chirashi",
		"level": 3,
		"satiety": 3,
		"cooldown": 8.0,
		"price": 12,
		# EL PLATO QUE RESUCITA: cinco ingredientes en un cuenco, la recarga
		# de paciencia mas alta del juego. Ningun 3 estrellas llenaba de
		# verdad, y este es el que tiene la ficha para hacerlo.
		"patience_mult": 1.5,
		"steps": [
			# Primero la bola de arroz, y al moldearla queda dentro del cuenco.
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "salmon" },
			{ "type": "drag_ingredient", "ingredient": "atun" },
			{ "type": "drag_ingredient", "ingredient": "wakame" },
			# El pepino salió de la receta al recortarla: eran TRES pasos (cogerlo,
			# trocearlo y volcarlo al cuenco) para un plato que ya se define por
			# los tres pescados de encima.
			{ "type": "drag_ingredient", "ingredient": "huevas" },
		],
		"stages": ["arroz_bola", "bol_arroz", "chirashi_medio", "chirashi_atun",
			"chirashi_wakame", ""],
	},
	# Regalo de David en el nivel 5, cuando aparece Pablo el Rubio. El salmón
	# se corta LENTO, reposa en un cuenco de soja y al final se vuelca sobre el
	# cuenco de arroz: por eso el último paso lleva "from" (lo que se arrastra
	# es el cuenco de soja, no el resultado del paso anterior, que es justamente
	# el destino). Es la ÚNICA receta que usa "from", así que al recortarla a
	# seis pasos se conservaron el corte lento y el reposo en la soja, que son
	# lo que la distingue, y se cayeron el wakame y el pepino del cuenco.
	"salmon_tsuke_don": {
		"label": "Tsuke",
		"name": "Salmón Tsuke Don",
		"level": 3,
		"satiety": 3,
		"cooldown": 7.5,
		"price": 14,
		"tip_chance_bonus": 0.03,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "tap_ingredient", "ingredient": "salmon" },
			# DOS cortes lentos (eran uno): es un plato de 3★ y su elaboración
			# tiene que pesar lo que cobra.
			{ "type": "slice_board", "count": 2, "duration": 0.7, "direction": "right",
				"fail_penalty": 4 },
			# El salmón se queda reposando en la soja y la tabla vuelve a enseñar
			# el CUENCO DE ARROZ, que es el destino del último paso.
			{ "type": "drag_stage", "prop": "cuenco_soja" },
			# Y al final se recoge el salmón de la soja y se vuelca en el cuenco.
			{ "type": "drag_stage", "prop": "cuenco_pepino", "from": "soja_salmon" },
		],
		"stages": ["arroz_bola", "bol_arroz", "sashimi_salmon", "salmon_lonchas",
			"bol_arroz", ""],
	},
	"udon": {
		"label": "Udon",
		"name": "Udon",
		"level": 2,
		"satiety": 2,
		"cooldown": 5.0,
		"price": 10,
		# Ocupa al cliente MUCHO rato pero le retiene poco: sirve para aparcar
		# a un cliente pesado sin alargarle la estancia.
		"eat_mult": 1.8,
		"patience_mult": 0.7,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "agua" },
			{ "type": "hold_board", "duration": 1.2 },
			{ "type": "drag_ingredient", "ingredient": "fideos" },
			{ "type": "stir_board", "count": 2 },
		],
		"stages": ["bol_agua", "bol_agua", "bol_udon", ""],
	},
	"te_verde": {
		"label": "TeVer",
		"name": "Té verde",
		"level": 1,
		"satiety": 1,
		"cooldown": 2.0,
		"price": 1,
		"snack": true,
		"take_chance": 0.9,
		"snack_refill": 0.2,
		# Limpia el aburrimiento: el cliente vuelve a disfrutar el plato que
		# le venías repitiendo.
		"clears_boredom": true,
		"steps": [
			{ "type": "drag_ingredient", "ingredient": "te", "prop": "cuenco_vacio" },
			{ "type": "hold_board", "duration": 1.2 },
		],
		"stages": ["bol_agua", ""],
	},
	"fugu": {
		"label": "Fugu",
		"name": "Sashimi de fugu",
		"level": 3,
		"satiety": 3,
		"cooldown": 9.0,
		"price": 9,
		# Hermano del atún rojo: aquí la propina es MÁS GORDA cuando cae
		# (+15% de cuantía), mientras que el atún rojo la hace más probable.
		"tip_amount_mult": 1.15,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "fugu" },
			# Cortar deprisa cuesta 5 doblones por fallo (el corte se repite).
			{ "type": "slice_board", "count": 2, "duration": 0.9,
				"cut_stage": "corte_fugu", "fail_penalty": 5 },
		],
		"stages": ["bloque_fugu", ""],
	},
	# --- POSTRES QUE LIBERAN EL ASIENTO ------------------------------------
	# Los tres funcionan igual: SOLO los coge un tipo de cliente ("only_type"),
	# y en cuanto se lo termina paga, COBRA el multiplicador de variedad del
	# cliente (client3d.VARIETY_TIP_PER_STEP doblones por punto, al bote) y SE
	# VA, dejando la silla libre para el siguiente. Es la única manera de echar
	# a un cliente sin esperar a su paciencia, y el cierre natural de un arco
	# de variedad bien llevado.
	"mochi": {
		"label": "Mochi",
		"name": "Mochi de matcha",
		"level": 1,
		"satiety": 1,
		"cooldown": 4.0,
		"price": 3,
		"only_type": "E",
		# MARIDAJE de cierre: servido tras limpiar el paladar, el postre
		# paga 3 mas. Es la secuencia con la que se despide bien a un
		# cliente: te/tsukemono y detras el dulce.
		"maridaje": { "con": ["te_verde", "tsukemono", "sopa_miso"], "bono": 3 },
		"leaves_seat": true,
		"tip_always": true,
		"no_extras": true,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "masa_mochi" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "matcha" },
			# Cerrar la bola: se recoge la masa hacia arriba y luego hacia abajo.
			# El recorrido es MÁS LARGO que el de un deslizamiento normal.
			{ "type": "swipe_board", "count": 1, "direction": "up", "distance": 130.0 },
			{ "type": "swipe_board", "count": 1, "direction": "down", "distance": 130.0 },
		],
		"stages": ["mochi_masa", "mochi_masa", "mochi_matcha", "mochi_matcha", ""],
	},
	"dorayaki": {
		"label": "Dora",
		"name": "Dorayaki",
		"level": 2,
		"satiety": 2,
		"cooldown": 5.5,
		"price": 5,
		"only_type": "A",
		# MARIDAJE de cierre: servido tras limpiar el paladar, el postre
		# paga 3 mas. Es la secuencia con la que se despide bien a un
		# cliente: te/tsukemono y detras el dulce.
		"maridaje": { "con": ["te_verde", "tsukemono", "sopa_miso"], "bono": 3 },
		"leaves_seat": true,
		"tip_always": true,
		"no_extras": true,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "bollo_dorayaki" },
			{ "type": "drag_ingredient", "ingredient": "judias_rojas" },
			{ "type": "tap_board", "count": 3 },
			# Corte VERTICAL (de arriba abajo), no el barrido lateral de los
			# pescados: parte el dorayaki por la mitad.
			{ "type": "slice_board", "count": 1, "duration": 0.5, "direction": "v" },
		],
		"stages": ["dorayaki_bollo", "dorayaki_relleno", "dorayaki_relleno", ""],
	},
	"taiyaki": {
		"label": "Taiya",
		"name": "Taiyaki de chocolate",
		"level": 3,
		"satiety": 3,
		"cooldown": 7.0,
		"price": 10,
		"only_type": "G",
		# MARIDAJE de cierre: servido tras limpiar el paladar, el postre
		# paga 3 mas. Es la secuencia con la que se despide bien a un
		# cliente: te/tsukemono y detras el dulce.
		"maridaje": { "con": ["te_verde", "tsukemono", "sopa_miso"], "bono": 3 },
		"leaves_seat": true,
		"tip_always": true,
		"no_extras": true,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "masa_taiyaki" },
			{ "type": "stir_board", "count": 2 },
			{ "type": "drag_stage", "prop": "molde_taiyaki" },
			{ "type": "drag_ingredient", "ingredient": "chocolate" },
			{ "type": "hold_board", "duration": 1.2 },
		],
		"stages": ["cuenco_batido", "cuenco_batido", "taiyaki_masa",
			"taiyaki_choco", ""],
	},
	# --- ANGUILA: se come volando y CONGELA la paciencia -------------------
	"nigiri_anguila": {
		"label": "Anguila",
		"name": "Nigiri de anguila",
		"level": 2,
		"satiety": 2,
		"cooldown": 5.5,
		"price": 10,
		# Se despacha en menos de la mitad de tiempo, y al terminarlo la barra
		# de paciencia se queda CONGELADA 5 s: da margen para colarle otro
		# plato sin que la espera le cueste nada.
		"eat_mult": 0.45,
		"patience_freeze": 5.0,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "unagi" },
			# Coger la salsa y GLASEAR con el pincel: dos pasadas lentas, ida y
			# vuelta ("alt" alterna el sentido en cada pasada).
			{ "type": "tap_ingredient", "ingredient": "salsa_unagi" },
			{ "type": "slice_board", "count": 2, "duration": 0.55,
				"direction": "alt", "brush": true, "prop": "pincel" },
		],
		"stages": ["arroz_bola", "nigiri_base", "nigiri_anguila",
			"nigiri_anguila", ""],
	},
	# --- TANDA NUEVA -------------------------------------------------------
	# MEJORA del onigiri (rediseno del 24-8-2026, pedido por el usuario): el
	# yaki YA NO se cocina con su plancha — se CORONA un onigiri hecho con
	# salsa de soja y sale tostado. Sus ventanas de fritura se fueron con el
	# cambio (YAKI_WINDOWS ya no existe).
	"yaki_onigiri": {
		"label": "Yaki",
		"name": "Yaki onigiri",
		"level": 1, "satiety": 1, "cooldown": 3.5, "price": 9,
		# EL PLATO UNIVERSAL: aqui el dado SI es el papel — es el unico plato
		# del juego que los tres tipos cogen casi igual de bien, asi que
		# nunca se queda en la cinta. Y llena como ningun otro (x1,7).
		"take_chance": { "E": 0.90, "A": 0.80, "G": 0.80 },
		"patience_mult": 1.7,
		"hidden": true, "steps": [], "stages": [],
	},
	"caldo_dashi": {
		"label": "Dashi",
		"name": "Caldo dashi",
		"level": 1,
		"satiety": 1,
		"cooldown": 3.5,
		"price": 6,
		# Caldo caliente: se toma despacio y reconforta, así que aguanta al
		# cliente sentado mucho más de lo que cuesta.
		"eat_mult": 1.4,
		"patience_mult": 1.3,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "agua" },
			{ "type": "hold_board", "duration": 1.2 },
			{ "type": "drag_ingredient", "ingredient": "katsuobushi" },
			{ "type": "stir_board", "count": 1 },
		],
		"stages": ["bol_agua", "bol_agua", "bol_dashi", ""],
	},
	"uramaki_california": {
		"label": "Cali",
		"name": "Uramaki California",
		"level": 2,
		"satiety": 2,
		"cooldown": 5.0,
		"price": 4,
		"patience_mult": 0.8,
		# Como los makis: sale UNA pieza y las 2 siguientes salen ya hechas.
		"free_uses": 2,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "kanikama" },
			# El aguacate entra y el rollo se cierra en el mismo gesto: el rollo
			# suelto era un paso más para llegar a lo que define este uramaki,
			# que es el rebozado en sésamo.
			{ "type": "drag_ingredient", "ingredient": "aguacate" },
			# Rebozado en sésamo: se coge el bote y se rueda el rollo de un lado
			# a otro. Recorrido LARGO pero a velocidad normal (no es un corte).
			{ "type": "tap_ingredient", "ingredient": "sesamo" },
			{ "type": "swipe_board", "count": 2, "direction": "alt", "distance": 210.0 },
		],
		"stages": ["arroz_bola", "arroz_plano", "cali_relleno", "rollo_cali",
			"rollo_cali_sesamo", ""],
	},
	"nigiri_pulpo": {
		"label": "Pulpo",
		"name": "Nigiri de pulpo",
		"level": 2,
		"satiety": 2,
		"cooldown": 4.5,
		"price": 8,
		# El pulpo se mastica: ocupa al cliente más rato que un nigiri normal.
		"eat_mult": 1.35,
		# TEMPORAL: sin modelo 3D propio todavía (Ludo no lo sacó). Toma
		# prestada la malla del nigiri de atún para no salir invisible en la
		# cinta; quitar "model" en cuanto exista nigiri_pulpo.glb.
		"model": "nigiri_atun",
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "tap_ingredient", "ingredient": "pulpo" },
			{ "type": "slice_board", "count": 1, "duration": 0.6, "direction": "v" },
			{ "type": "drag_ingredient", "ingredient": "pulpo" },
		],
		"stages": ["arroz_bola", "nigiri_base", "pulpo_tabla", "pulpo_cortado", ""],
	},
	"dragon_roll": {
		"label": "Dragon",
		"name": "Dragon roll",
		"level": 3,
		"satiety": 3,
		"cooldown": 7.0,
		"price": 6,
		"tip_chance_bonus": 0.04,
		# Como los makis: sale UNA pieza y las 2 siguientes salen ya hechas.
		# Eran 4, pero la receta pasó de ONCE pasos a seis: con la maestría
		# intacta habría quedado como la receta más rentable del juego con
		# diferencia (era ya la que más doblones daba por segundo de atención).
		"free_uses": 2,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			# Se conserva UN corte de los tres que llevaba (salmón, gamba y
			# pepino, cada uno con su tajo): el gesto se entiende igual con uno.
			{ "type": "tap_ingredient", "ingredient": "salmon" },
			{ "type": "slice_board", "count": 1, "duration": 0.6, "direction": "v" },
			{ "type": "swipe_board", "count": 3, "direction": "up" },
			# Las escamas de aguacate son lo que hace al dragón, y cierran el rollo.
			{ "type": "drag_ingredient", "ingredient": "aguacate" },
		],
		"stages": ["arroz_bola", "arroz_plano", "dragon_salmon", "dragon_salmon_cort",
			"rollo_dragon", ""],
	},
	"nigiri_wagyu": {
		"label": "Wagyu",
		"name": "Nigiri de wagyu flameado",
		"level": 3,
		"satiety": 3,
		"cooldown": 7.5,
		# Precio de referencia; el REAL lo pone el punto del soplete.
		"price": 16,
		"tip_amount_mult": 1.2,
		# MARIDAJE con el shiitake: la seta se come en nada, asi que
		# encadenarlos pide cronometrar de verdad. Es el maridaje mas caro
		# del juego y el que mas manos pide.
		"maridaje": { "con": ["gunkan_shiitake"], "bono": 6 },
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "tap_ingredient", "ingredient": "wagyu" },
			{ "type": "slice_board", "count": 1, "duration": 0.6 },
			{ "type": "drag_ingredient", "ingredient": "wagyu" },
			# Soplete CRONOMETRADO (por segundos, no por barra): 2 s clavados.
			{ "type": "fry_board", "target": 2.0, "windows": WAGYU_WINDOWS,
				"prop": "soplete" },
		],
		"stages": ["arroz_bola", "nigiri_base", "wagyu_tabla", "wagyu_cortado",
			"wagyu_crudo", ""],
	},
	"sashimi_variado": {
		"label": "SashVar",
		"name": "Sashimi variado",
		"level": 3,
		"satiety": 3,
		"cooldown": 6.5,
		"price": 12,
		# Sin arroz: se come rápido pero recarga poco.
		"eat_mult": 0.8,
		"patience_mult": 0.85,
		# TEMPORAL: igual que el nigiri de pulpo, sin malla propia todavía.
		"model": "sashimi_atun_rojo",
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "salmon" },
			{ "type": "slice_board", "count": 1, "duration": 0.55 },
			{ "type": "tap_ingredient", "ingredient": "atun" },
			{ "type": "slice_board", "count": 1, "duration": 0.55 },
			{ "type": "tap_ingredient", "ingredient": "pulpo" },
			{ "type": "slice_board", "count": 1, "duration": 0.55 },
		],
		"stages": ["sashimi_salmon", "sashimi_salmon_cort", "sashimi_atun",
			"sashimi_atun_cort", "sashimi_tres", ""],
	},
	# --- TANDA DEL MAR 2 (24-8-2026): picoteos de oficio y pescado nuevo ----
	"tsukemono": {
		"label": "Gari",
		"name": "Tsukemono",
		"level": 1,
		"satiety": 1,
		"cooldown": 4.0,
		"price": 2,
		"snack": true,
		"take_chance": 0.9,
		# No alarga el bocado NADA: su gracia es el paladar y el multiplicador.
		"snack_refill": 0.0,
		# Jengibre encurtido: limpia el paladar (como el té) Y ADEMÁS sube un
		# punto de multiplicador (variety_snack) — el reinicio con premio.
		"clears_boredom": true,
		"variety_snack": true,
		"steps": [
			{ "type": "drag_ingredient", "ingredient": "jengibre", "prop": "cuenco_vacio" },
			{ "type": "tap_ingredient", "ingredient": "sal" },
			# Espolvorear la sal: varios toques sobre el cuenco.
			{ "type": "tap_board", "count": 3 },
		],
		"stages": ["cuenco_jengibre", "cuenco_jengibre", ""],
	},
	"bol_arroz": {
		"label": "BolAr",
		"name": "Bol de arroz",
		"level": 1,
		"satiety": 1,
		"cooldown": 1.5,
		"price": 1,
		"snack": true,
		"take_chance": 0.9,
		"snack_refill": 0.1,
		# PICOTEO EXTRA: no gasta el turno de picoteo del bocado — el cliente
		# puede comer su picoteo normal Y ADEMÁS un bol de arroz, en cualquier
		# orden (ver client3d.extra_snack_taken).
		"extra_snack": true,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_stage", "prop": "cuenco_vacio" },
		],
		"stages": ["arroz_bola", "arroz_bola", ""],
	},
	# MEJORA del bol (un trozo de alga nori por encima): mas bocado y mas
	# precio, y conserva la gracia del picoteo extra. Ver UPGRADES.
	"bol_arroz_mejorado": {
		"label": "BolA+",
		"name": "Bol de arroz con nori",
		"level": 1, "satiety": 1, "cooldown": 1.5, "price": 3,
		# El 0.9 NO es "mejor dado": es el dado plano que llevan TODOS los
		# picoteos (sin el, la matriz por nivel le daria 10% con un capitan).
		"snack": true, "take_chance": 0.9, "snack_refill": 0.25,
		"extra_snack": true,
		"model": "bol_arroz",
		"hidden": true, "steps": [], "stages": [],
	},
	"ensalada_wakame": {
		"label": "EnsWa",
		"name": "Ensalada de wakame",
		"level": 1,
		"satiety": 1,
		# GRAN cooldown a proposito: su +50% de bocado es el mayor de todos
		# los picoteos, y barato no puede ser tambien constante.
		"cooldown": 9.0,
		"price": 3,
		"snack": true,
		"take_chance": 0.9,
		"snack_refill": 0.5,
		"steps": [
			{ "type": "drag_ingredient", "ingredient": "wakame", "prop": "cuenco_vacio" },
		],
		"stages": [""],
	},
	"gunkan_shiitake": {
		"label": "GuShi",
		"name": "Gunkan de shiitake",
		"level": 1,
		"satiety": 1,
		"cooldown": 2.5,
		"price": 3,
		# Bocado RAPIDISIMO: el cliente vuelve enseguida a la cinta.
		"eat_mult": 0.4,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "shiitake" },
		],
		"stages": ["arroz_bola", "gunkan_base", ""],
	},
	"nigiri_caballa": {
		"label": "NiCab",
		"name": "Nigiri de caballa",
		"level": 2,
		"satiety": 2,
		"cooldown": 5.0,
		"price": 6,
		# Quien lo come tira el dado del SIGUIENTE plato que le pase con un
		# +10% (client3d.next_take_bonus): abre la puerta al plato caro.
		"next_take_bonus": 0.1,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "caballa" },
		],
		"stages": ["arroz_bola", "nigiri_base", ""],
	},
	"nigiri_besugo": {
		"label": "NiBes",
		"name": "Nigiri de besugo flambeado",
		"level": 2,
		"satiety": 2,
		"cooldown": 5.5,
		# Precio de referencia (el del buen punto); el REAL lo pone el soplete.
		"price": 7,
		"tip_chance_bonus": 0.08,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "besugo" },
			# Soplete cronometrado con el punto en 1,5 s (no en 2): cuanto MAS
			# CERCA del punto, mas probable la propina (ver BESUGO_WINDOWS).
			{ "type": "fry_board", "target": 1.5, "windows": BESUGO_WINDOWS,
				"prop": "soplete", "punto_propina": true },
		],
		"stages": ["arroz_bola", "nigiri_base", "nigiri_besugo_crudo", ""],
	},
	# Variantes por punto de flambeado del besugo: no se eligen, las sirve el
	# soplete con su precio y su bono de propina (ver BESUGO_WINDOWS).
	"nigiri_besugo_dorado": {
		"label": "NiBe+", "name": "Nigiri de besugo dorado",
		"level": 2, "satiety": 2, "cooldown": 5.5, "price": 8,
		"tip_chance_bonus": 0.15, "model": "nigiri_besugo",
		"hidden": true, "steps": [], "stages": [],
	},
	"nigiri_besugo_perfecto": {
		"label": "NiBe*", "name": "Nigiri de besugo en su punto",
		"level": 2, "satiety": 2, "cooldown": 5.5, "price": 9,
		"tip_chance_bonus": 0.25, "model": "nigiri_besugo",
		"hidden": true, "steps": [], "stages": [],
	},
	"nigiri_besugo_palido": {
		"label": "NiBe-", "name": "Nigiri de besugo sin punto",
		"level": 2, "satiety": 2, "cooldown": 5.5, "price": 4,
		"model": "nigiri_besugo",
		"hidden": true, "steps": [], "stages": [],
	},
	"nigiri_pargo": {
		"label": "NiPar",
		"name": "Nigiri de pargo",
		"level": 2,
		"satiety": 2,
		"cooldown": 5.5,
		# LA APUESTA DE LA CARTA (subido de 12 a 20 por el usuario): el dado
		# es bajo en los TRES tipos, y desde el mar 2 dejar un plato sin que
		# nadie lo coja ya no es gratis — se lo come el cubo, y con `riesgo`
		# en la carta encima castiga al que lo desprecia. Si el riesgo tiene
		# precio, la recompensa tiene que merecerlo: 20 es el plato mejor
		# pagado de 2 estrellas con diferencia.
		"price": 20,
		"take_chance": { "E": 0.10, "A": 0.55, "G": 0.35 },
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "pargo" },
		],
		"stages": ["arroz_bola", "nigiri_base", ""],
	},
	"gunkan_jurel": {
		"label": "GuJur",
		"name": "Gunkan de jurel",
		"level": 2,
		"satiety": 2,
		"cooldown": 5.0,
		"price": 6,
		# Ni mas ni menos propina que cualquiera: su gracia es el bocado
		# LENTO, que aparca al cliente un buen rato.
		"eat_mult": 1.5,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "jurel" },
			{ "type": "tap_board", "count": 3, "cutting": true },
			{ "type": "drag_ingredient", "ingredient": "wakame" },
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "drag_stage", "prop": "gunkan_base" },
		],
		"stages": ["jurel_tabla", "jurel_cubos", "jurel_wakame", "arroz_bola", ""],
	},
	"barbo_ahumado": {
		"label": "Barbo",
		"name": "Barbo oloroso ahumado",
		"level": 2,
		"satiety": 2,
		"cooldown": 6.0,
		"price": 8,
		# Quien lo come sube +3 de multiplicador de golpe (variety_worth)...
		"variety_worth": 3,
		# ...pero su humo baja 3 al vecino de cada lado (level3d.aplicar_olor_vecinos).
		"neighbor_mult": -3,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "barbo" },
			{ "type": "slice_board", "count": 1, "duration": 0.6 },
			{ "type": "drag_stage", "prop": "ahumador" },
		],
		"stages": ["barbo_tabla", "barbo_lomos", ""],
	},
	"takoyaki_pulpo": {
		"label": "Tako",
		"name": "Takoyaki de pulpo",
		"level": 2,
		"satiety": 2,
		"cooldown": 6.0,
		# Precio POR CLIENTE: el plato se COMPARTE ("servings") — tras el
		# primer cliente se queda en la cinta, menguado, y otro lo remata.
		"price": 5,
		"servings": 2,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "pulpo" },
			{ "type": "tap_board", "count": 3, "cutting": true },
			{ "type": "tap_ingredient", "ingredient": "harina" },
			{ "type": "stir_board", "count": 2 },
			{ "type": "drag_stage", "prop": "sarten" },
		],
		"stages": ["pulpo_tabla", "pulpo_cortado", "takoyaki_masa", "takoyaki_masa", ""],
	},
	# MEJORA del nigiri de salmon (huevas de salmon por encima). Ver UPGRADES.
	"nigiri_salmon_mejorado": {
		"label": "NiSa+",
		"name": "Nigiri de salmón con huevas",
		"level": 1, "satiety": 1, "cooldown": 3.0, "price": 8,
		# FAMA ACELERADA: la base sube medio punto de dado por plato servido
		# (tope +10%); coronado sube el DOBLE y llega a +15%. Es la unica
		# corona cuyo premio ES el dado, y se nota porque MEJORA JUGANDO.
		"fama": 0.01,
		"fama_max": 0.15,
		"model": "nigiri_salmon",
		"hidden": true, "steps": [], "stages": [],
	},
	# MEJORA del nigiri de pulpo (alga nori alrededor). Ver UPGRADES.
	"nigiri_pulpo_mejorado": {
		"label": "Pulp+",
		"name": "Nigiri de pulpo con nori",
		"level": 2, "satiety": 2, "cooldown": 4.5, "price": 12,
		# El nori lo hace aun mas de mascar: de x1,35 a x1,6. Su papel es
		# APARCAR al cliente, y coronarlo lo aparca la mitad de un bocado mas.
		"eat_mult": 1.6,
		# TEMPORAL: el nigiri de pulpo tampoco tiene malla propia todavia.
		"model": "nigiri_atun",
		"hidden": true, "steps": [], "stages": [],
	},
	"gyozas": {
		"label": "Gyoza",
		"name": "Gyozas a la plancha",
		"level": 2,
		"satiety": 2,
		"cooldown": 5.5,
		"price": 6,
		# Salen DOS tandas por elaboracion (la de mano y una de maestria).
		"free_uses": 1,
		# RECIEN HECHAS: pagan hasta un 30% mas si las coge el primer cliente
		# que alcanzan, y se abaratan con cada vuelta de cinta.
		"frescura": true,
		# Y maridan con la sopa: caldo caliente y empanadilla recien hecha.
		"maridaje": { "con": ["sopa_miso", "caldo_dashi", "dashi_ahumado"], "bono": 4 },
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "masa_gyoza" },
			{ "type": "drag_ingredient", "ingredient": "carne_picada" },
			# Plegar la empanadilla: dos pasadas.
			{ "type": "swipe_board", "count": 2, "direction": "down" },
			{ "type": "drag_stage", "prop": "sarten" },
		],
		"stages": ["gyoza_masa", "gyoza_rellena", "gyoza_plegada", ""],
	},
	"toro_aleta": {
		"label": "Toro",
		"name": "Toro de aleta amarilla",
		"level": 3,
		"satiety": 3,
		"cooldown": 7.0,
		# BASE 10 y la TALLA hace el resto: el atun de aleta amarilla es
		# EPICO, o sea que su horquilla de album va de 60 a 150 cm. Con el
		# record al maximo el toro paga 20 — el plato mejor pagado del juego,
		# y no se compra: se pesca.
		"price": 10,
		# La ventresca: la propina cae mas GORDA...
		"tip_amount_mult": 1.3,
		"talla": "atun_amarillo",
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "toro" },
			{ "type": "slice_board", "count": 2, "duration": 0.7,
				"cut_stage": "corte_toro", "fail_penalty": 5 },
		],
		"stages": ["bloque_toro", ""],
	},
	"tataki_atun_rojo": {
		"label": "Tatak",
		"name": "Tataki de atún rojo",
		"level": 3,
		"satiety": 3,
		"cooldown": 7.0,
		"price": 13,
		# MARIDAJE: servido justo despues de un caldo, paga 5 doblones extra.
		"maridaje": { "con": ["caldo_dashi", "dashi_ahumado", "sopa_miso"], "bono": 5 },
		# Y el bol de arroz abre cualquier sashimi: es su papel de aperitivo.
		"variety_worth": 1,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "atun_rojo" },
			# Sellado por fuera con el soplete (crudo por dentro)...
			{ "type": "hold_board", "duration": 1.0, "prop": "soplete", "move": true },
			# ...y laminado despacio.
			{ "type": "slice_board", "count": 2, "duration": 0.6 },
		],
		"stages": ["bloque_atun_rojo", "tataki_sellado", ""],
	},
	# --- MEJORAS CON MECANICA (ver UPGRADES): ninguna se cocina, todas se
	# CORONAN desde su receta base. Cada una estrena una mecanica nueva.
	"maki_pepino_sesamo": {
		"label": "MaPe+",
		"name": "Maki de pepino al sésamo",
		"level": 1, "satiety": 1, "cooldown": 3.0, "price": 5,
		"patience_mult": 0.8,
		"frescura": true,
		"model": "maki_pepino",
		"hidden": true, "steps": [], "stages": [],
	},
	"zuke_atun": {
		"label": "Zuke",
		"name": "Zuke de atún",
		"level": 2, "satiety": 2, "cooldown": 5.0, "price": 9,
		# El zuke ES atun marinado: REPOSA en la cinta y gana valor.
		"marinado": true,
		"model": "nigiri_atun",
		"hidden": true, "steps": [], "stages": [],
	},
	"dashi_ahumado": {
		"label": "Dash+",
		"name": "Dashi ahumado",
		"level": 1, "satiety": 1, "cooldown": 3.5, "price": 10,
		"eat_mult": 1.4,
		"patience_mult": 1.5,
		# Reconforta tanto que DA ENVIDIA: el resto de la mesa pierde un 8%.
		"contagio": -0.08,
		"model": "caldo_dashi",
		"hidden": true, "steps": [], "stages": [],
	},
	"fugu_valiente": {
		"label": "Fugu+",
		"name": "Fugu del valiente",
		"level": 3, "satiety": 3, "cooldown": 9.0, "price": 14,
		"tip_amount_mult": 1.15,
		# RIESGO: quien lo deja pasar pierde paciencia; quien se atreve, la
		# rellena ENTERA.
		"riesgo": true,
		"model": "fugu",
		"hidden": true, "steps": [], "stages": [],
	},
	"shime_saba": {
		"label": "Shime",
		"name": "Shime saba",
		"level": 2, "satiety": 2, "cooldown": 5.0, "price": 10,
		# La caballa curada abre el apetito el DOBLE que la fresca.
		"next_take_bonus": 0.2,
		"model": "nigiri_caballa",
		"hidden": true, "steps": [], "stages": [],
	},
	"tempura_dorada": {
		"label": "Temp+",
		"name": "Tempura dorada",
		"level": 2, "satiety": 2, "cooldown": 5.5, "price": 16,
		# Recien frita o nada: paga mas cuanto antes la cojan.
		"frescura": true,
		"model": "tempura",
		"hidden": true, "steps": [], "stages": [],
	},
	"unagi_doble": {
		"label": "Unag+",
		"name": "Unagi doble glaseado",
		"level": 2, "satiety": 2, "cooldown": 5.5, "price": 14,
		"eat_mult": 0.45,
		"patience_freeze": 5.0,
		# Anguila y dashi son pareja de casa: tras un caldo paga extra.
		"maridaje": { "con": ["caldo_dashi", "dashi_ahumado"], "bono": 4 },
		"model": "nigiri_anguila",
		"hidden": true, "steps": [], "stages": [],
	},
	"sashimi_patron": {
		"label": "SaPa+",
		"name": "Sashimi del patrón",
		"level": 3, "satiety": 3, "cooldown": 7.5, "price": 12,
		"tip_chance_bonus": 0.04,
		# El precio crece con el RECORD de talla del atun rojo del album.
		"talla": "atun_rojo",
		"model": "sashimi_atun_rojo",
		"hidden": true, "steps": [], "stages": [],
	},
	# --- COMBINACIÓN (ver COMBOS): no se elabora, se monta juntando un udon
	# y una tempura que ya estén GUARDADOS en las cajas.
	"udon_tempura": {
		"label": "UdonT",
		"name": "Udon con tempura",
		"level": 3,
		"satiety": 3,
		"cooldown": 6.0,
		# Referencia para las tarjetas; el precio REAL lo calcula prep_board
		# sumando las dos partes más el bonus del combo.
		"price": 25,
		"hidden": true,
		# Hereda lo de los dos: retiene poco (udon) y ocupa AÚN MÁS rato.
		"eat_mult": 2.2,
		"patience_mult": 0.7,
		"steps": [],
		"stages": [],
	},
	"moriawase": {
		"label": "Moria",
		"name": "Barco combinado",
		"level": 3,
		"satiety": 3,
		"cooldown": 8.0,
		# El precio REAL lo pone prep_board según los platos con los que se
		# monte (suma + prima por variedad); este es solo el mínimo de
		# referencia para las tarjetas.
		"price": 26,
		# NO se elige en el selector: aparece como icono bajo las cajas cuando
		# hay 4 platos guardados de al menos dos clases distintas.
		"hidden": true,
		# Se cogen mucho más que un plato suelto del mismo nivel (ver arriba).
		"take_chances": BOAT_TAKE_CHANCES,
		# La bandeja de la variedad vale DOBLE en el arco del cliente.
		"variety_worth": 2,
		# Lo que tarda en comerse NO sale de aquí: lo calcula prep_board al
		# montarlo, según cuántos platos lleve dentro (BOAT_EAT_BASE y
		# BOAT_EAT_PER_DISH), y viaja con el plato. Como la paciencia no se
		# drena mientras se come, un barco aparca al cliente un buen rato.
		"steps": [],
		"stages": [],
	},
}


## Textura de una etapa de elaboración, o null si no existe.
static func get_stage_texture(stage_id: String) -> Texture2D:
	if stage_id == "":
		return null
	var path := "res://assets/stages/%s.png" % stage_id
	return load(path) if ResourceLoader.exists(path) else null


## Textura del plato terminado.
static func get_dish_texture(recipe_id: String) -> Texture2D:
	var path := "res://assets/dishes/%s.webp" % recipe_id
	return load(path) if ResourceLoader.exists(path) else null


static func get_recipe(id: String) -> Dictionary:
	return RECIPES.get(id, {})


## Ingredientes DISTINTOS que consume una receta (según sus pasos), excluyendo
## el arroz, que es infinito. Son los que gastan usos del inventario por nivel.
static func get_ingredients(recipe_id: String) -> Array[String]:
	var out: Array[String] = []
	for step in get_recipe(recipe_id).get("steps", []):
		# Un paso de elección (aburi) ofrece varios pescados: hay que llevar
		# usos de TODOS, porque en partida se puede elegir cualquiera.
		var cands: Array = step.get("options", [step.get("ingredient", "")])
		for ing in cands:
			if ing == "" or ing == "arroz":
				continue
			# Los que comparten despensa gastan usos del ingrediente "padre"
			# (el atún cocido descuenta del atún).
			ing = get_ingredient(ing).get("stock_id", ing)
			if not ing in out:
				out.append(ing)
	return out


## Icono de un ingrediente, o null si no existe.
static func get_ingredient_texture(ingredient_id: String) -> Texture2D:
	var path := "res://assets/ingredients/%s.png" % ingredient_id
	return load(path) if ResourceLoader.exists(path) else null


static func get_ingredient(id: String) -> Dictionary:
	return INGREDIENTS.get(id, {})


## Ingredientes únicos que usa una receta, en orden de aparición (incluye las
## opciones de los pasos de elección, para que salgan en la fila de la tabla).
static func get_recipe_ingredients(id: String) -> Array[String]:
	var result: Array[String] = []
	for step in get_recipe(id).get("steps", []):
		var cands: Array = step.get("options", [step.get("ingredient", "")])
		for ing in cands:
			if ing != "" and not ing in result:
				result.append(ing)
	return result


## --- QUÉ HACE ESTA RECETA, en una frase -------------------------------------
##
## Se DEDUCE de los datos, no se escribe a mano receta por receta: así una
## ficha nunca puede mentir (si mañana el mochi deja de liberar la silla, su
## descripción cambia sola) y una receta nueva llega descrita sin trabajo
## extra. Lo usan la ventana de "¡Receta nueva!" y la ficha del recetario.
##
## Devuelve de una a tres frases cortas, con las palabras clave entre
## `**asteriscos**` (el mismo marcador que los diálogos, ver
## `DialogueBox.format_keywords`). Solo se cuentan las particularidades: lo que
## ya se ve en la ficha (estrellas, precio, ingredientes) no se repite.

## Nombre en plural de cada tipo de cliente, para los platos de un solo paladar.
const TYPE_PLURAL: Dictionary = {
	"E": "grumetes", "A": "piratas", "G": "capitanes",
}
## Cuántas frases como mucho: más de tres y deja de ser una descripción.
## Frases del resumen. CUATRO desde que son cortas y con cifras: antes eran
## parrafos y con tres ya se llenaba la ficha.
const SUMMARY_MAX := 4


static func summary(id: String) -> String:
	var r := get_recipe(id)
	if r.is_empty():
		return ""
	var f: Array[String] = []

	if bool(r.get("snack", false)):
		# El 0.35 es el `SNACK_EAT_REFILL` de client3d, que no es clase global y
		# no se puede leer desde aqui; la receta puede pisarlo con `snack_refill`
		# (el tsukemono lo deja a cero).
		var refill := float(r.get("snack_refill", 0.35))
		if refill <= 0.0:
			f.append("**Picoteo**: se coge sin soltar el plato en curso, aunque este no alarga el bocado.")
		else:
			f.append("**Picoteo**: se coge sin soltar el plato en curso y alarga el bocado un **%d%%**."
				% int(round(refill * 100.0)))
	if r.has("snack_price"):
		f.append("De **picoteo paga %d**; como plato suelto, solo %d."
			% [int(r.get("snack_price", 0)), int(r.get("price", 0))])
	if bool(r.get("extra_snack", false)):
		f.append("**No gasta el turno de picoteo**: entra además del picoteo normal del bocado.")
	if int(r.get("servings", 1)) > 1:
		f.append("**Se comparte**: da para %d clientes — tras el primero se queda en la cinta."
			% int(r.get("servings", 1)))
	if int(r.get("variety_worth", 1)) > 1:
		f.append("Vale **+%d de multiplicador** para quien lo come."
			% int(r.get("variety_worth", 1)))
	if int(r.get("neighbor_mult", 0)) < 0:
		f.append("Pero su humo **baja %d puntos** de multiplicador al vecino de cada lado."
			% -int(r.get("neighbor_mult", 0)))
	if float(r.get("next_take_bonus", 0.0)) > 0.0:
		f.append("Quien lo come tiene un **+%d%%** de probabilidad de coger el **siguiente plato** que le pase."
			% int(round(float(r.get("next_take_bonus", 0.0)) * 100.0)))
	if bool(r.get("frescura", false)):
		f.append("**Recién hecho paga hasta un 30% más**: cada vuelta de cinta lo abarata.")
	if bool(r.get("marinado", false)):
		f.append("**Marinado**: reposa en la cinta y gana valor — cogido tarde paga hasta un 30% más.")
	var contagio := float(r.get("contagio", 0.0))
	if contagio < 0.0:
		f.append("Reconforta tanto que **da envidia**: el resto de la mesa pierde un %d%% de paciencia."
			% int(round(-contagio * 100.0)))
	var mar_d: Dictionary = r.get("maridaje", {})
	if not mar_d.is_empty():
		var mar_nombres: Array[String] = []
		for mid in mar_d.get("con", []):
			var nom := str(get_recipe(str(mid)).get("name", mid))
			if not bool(get_recipe(str(mid)).get("hidden", false)):
				mar_nombres.append(nom.to_lower())
		f.append("**Maridaje**: servido justo después de %s paga **+%d doblones**."
			% [" o ".join(mar_nombres), int(mar_d.get("bono", 0))])
	if r.has("talla"):
		f.append("El precio crece con tu **récord de pesca** de esa especie (hasta un 50% más).")
	if bool(r.get("riesgo", false)):
		f.append("**Plato de valientes**: quien lo deja pasar pierde paciencia; quien lo coge la rellena ENTERA.")
	var fama := float(r.get("fama", 0.0))
	if fama > 0.0:
		# EN CRISTIANO (pedido por el usuario): "se hace famoso" y "sube su
		# probabilidad" no decian probabilidad DE QUE. Lo que sube es la
		# probabilidad de que un cliente lo coja de la cinta.
		var tope := float(r.get("fama_max", 0.10))
		f.append("**Gusta más cuanto más lo sirves**: cada plato de estos que sirvas sube un **%.1f%%** la probabilidad de que un cliente lo coja, hasta **+%d%%** en la jornada."
			% [fama * 100.0, int(round(tope * 100.0))])
	if bool(r.get("variety_snack", false)):
		f.append("Y **sube el multiplicador**, cosa que los demás picoteos no hacen.")
	if bool(r.get("leaves_seat", false)):
		var quien := str(TYPE_PLURAL.get(str(r.get("only_type", "")), ""))
		f.append("**Postre**: propina segura, cobra el multiplicador y **libera la silla**%s."
			% ("" if quien == "" else " (solo lo cogen los %s)" % quien))
	if bool(r.get("clears_boredom", false)) and not bool(r.get("snack", false)):
		f.append("**Limpia el paladar**: todo vuelve a contar como nuevo, sin subir el multiplicador.")
	elif bool(r.get("clears_boredom", false)):
		f.append("Además **limpia el paladar**: todo vuelve a contar como nuevo.")

	var libres := int(r.get("free_uses", 0))
	if libres == 1:
		f.append("**Uso extra**: preparas uno y sale **otro** ya hecho.")
	elif libres > 1:
		f.append("**Usos extra**: preparas uno y salen **%d más** ya hechos." % libres)

	var congela := float(r.get("patience_freeze", 0.0))
	if congela > 0.0:
		f.append("**Congela la paciencia** del cliente %d segundos." % int(congela))

	# CON LA CIFRA, no con un adjetivo: "se come un 80% mas despacio" se puede
	# comparar con otra receta y "muy despacio" no.
	var comer := float(r.get("eat_mult", 1.0))
	if comer >= 1.1:
		f.append("Se come un **%d%% más despacio**: aparta al cliente ese rato."
			% int(round((comer - 1.0) * 100.0)))
	elif comer <= 0.9:
		f.append("Se come un **%d%% más rápido**: el cliente vuelve antes a pedir."
			% int(round((1.0 - comer) * 100.0)))

	var llena := float(r.get("patience_mult", 1.0))
	if llena >= 1.05:
		f.append("Recarga un **%d%% más** de paciencia." % int(round((llena - 1.0) * 100.0)))
	elif llena <= 0.95:
		f.append("Recarga un **%d%% menos** de paciencia." % int(round((1.0 - llena) * 100.0)))

	var cuantia := float(r.get("tip_amount_mult", 1.0))
	if cuantia > 1.0:
		f.append("La propina cae un **%d%% más gorda**." % int(round((cuantia - 1.0) * 100.0)))
	var prob := float(r.get("tip_chance_bonus", 0.0))
	if prob > 0.0:
		f.append("**+%d%%** de probabilidad de propina." % int(round(prob * 100.0)))

	# Gestos que el jugador tiene que saber ANTES de meterse en la receta.
	for step in r.get("steps", []):
		match str(step.get("type", "")):
			"slice_board":
				if int(step.get("fail_penalty", 0)) > 0:
					f.append("**Corte lento**, y correr cuesta **%d doblones** por fallo."
						% int(step.get("fail_penalty", 0)))
				else:
					f.append("Lleva **corte lento**: de lado a lado y sin correr.")
			"fry_board":
				if bool(step.get("punto_propina", false)):
					f.append("**Punto de flambeado**: cuanto más cerca del punto justo, más probable la propina.")
				else:
					f.append("**Punto de fritura**: clavarlo paga el triple que pasarse.")
			"drag_choice":
				f.append("Se **elige el pescado** al prepararlo, y el plato cambia con él.")

	var take: Variant = r.get("take_chance", null)
	if take is float and float(take) >= 0.85:
		f.append("Lo coge **cualquier paladar**: %d%% con los tres tipos."
			% int(round(float(take) * 100.0)))

	if f.is_empty():
		return ""
	var out := ""
	for i in mini(f.size(), SUMMARY_MAX):
		out += ("" if out == "" else " ") + f[i]
	return out
