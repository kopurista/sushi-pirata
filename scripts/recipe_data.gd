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

## "cost": precio en doblones de 1 USO en la tienda (un uso = un nivel jugado
## con recetas que lleven ese ingrediente). El arroz es infinito (cost 0, no se
## vende ni consume usos).
const INGREDIENTS: Dictionary = {
	"arroz": { "name": "Arroz", "short": "Arroz", "color": Color(0.93, 0.92, 0.85), "cost": 0 },
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
		"cost": 5 },
	"matcha": { "name": "Té matcha", "short": "Matcha", "color": Color(0.42, 0.68, 0.28),
		"cost": 10 },
	"katsuobushi": { "name": "Bonito seco", "short": "Bonito", "color": Color(0.80, 0.55, 0.42),
		"cost": 6 },
	"kanikama": { "name": "Palitos de cangrejo", "short": "Kanik", "color": Color(0.95, 0.52, 0.38),
		"cost": 10 },
	"pulpo": { "name": "Pulpo", "short": "Pulpo", "color": Color(0.68, 0.30, 0.38), "cost": 20 },
	"wagyu": { "name": "Wagyu", "short": "Wagyu", "color": Color(0.72, 0.22, 0.24), "cost": 38 },
	# Gratis como el arroz (cost 0): no se compra ni gasta usos.
	"sesamo": { "name": "Sésamo", "short": "Sésamo", "color": Color(0.92, 0.88, 0.78), "cost": 0 },
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

## Franjas del YAKI ONIGIRI a la plancha (paso "fry_board" con "windows").
## Mucho más indulgente que la tempura: quedarse corto o pasarse NO tira el
## plato, solo lo deja en 3 doblones. El punto exacto (2.00 s) paga 14.
const YAKI_WINDOWS := [
	{ "to": 1.25, "price": 3, "dish": "yaki_onigiri", "label": "Crudito",
		"color": Color(1.0, 0.72, 0.30) },
	{ "to": 1.99, "price": 8, "dish": "yaki_onigiri", "label": "¡Buen punto!",
		"color": Color(0.45, 0.95, 0.45) },
	{ "to": 2.01, "price": 14, "dish": "yaki_onigiri", "label": "¡Perfecto!",
		"color": Color(1.0, 0.85, 0.25) },
	{ "to": 2.75, "price": 8, "dish": "yaki_onigiri", "label": "¡Buen punto!",
		"color": Color(0.45, 0.95, 0.45) },
	{ "to": 999.0, "price": 3, "dish": "yaki_onigiri", "label": "Tostado",
		"color": Color(1.0, 0.72, 0.30) },
]

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
			# UN solo corte, y lento: lo que queda es el sashimi de salmón.
			{ "type": "slice_board", "count": 1, "duration": 0.7, "direction": "right",
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
	"yaki_onigiri": {
		"label": "Yaki",
		"name": "Yaki onigiri",
		"level": 1,
		"satiety": 1,
		"cooldown": 4.0,
		# El precio REAL lo pone el punto de la plancha (ver "windows"); este es
		# el de referencia para las tarjetas.
		"price": 8,
		# Es el onigiri de siempre pasado por la sartén: mismos ingredientes y
		# el mismo reparto por tipo de cliente.
		"take_chance": { "E": 0.85, "A": 0.70, "G": 0.70 },
		"patience_mult": 1.4,
		"steps": [
			{ "type": "tap_ingredient", "ingredient": "arroz" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "atun_cocido" },
			{ "type": "tap_board", "count": 3 },
			{ "type": "drag_ingredient", "ingredient": "nori" },
			# A la plancha 2 s. Mucho más indulgente que la tempura: pasarse o
			# quedarse corto NO tira el plato, solo lo deja en 2 doblones.
			{ "type": "fry_board", "target": 2.0, "windows": YAKI_WINDOWS },
		],
		"stages": ["arroz_bola", "arroz_plano", "onigiri_relleno", "onigiri_forma",
			"yaki_sarten", ""],
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
		# (el gari lo deja casi a cero).
		f.append("**Picoteo**: se coge sin soltar el plato en curso y alarga el bocado un **%d%%**."
			% int(round(float(r.get("snack_refill", 0.35)) * 100.0)))
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
	if libres > 0:
		f.append("**Maestría**: %d piezas por elaboración (haces la primera; las otras %d salen hechas)."
			% [libres + 1, libres])

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
