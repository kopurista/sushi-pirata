class_name CampaignData
## Datos estáticos de la campaña (modo Aventura): lista ORDENADA de niveles.
##
## LA CAMPAÑA COMPLETA SON 250 ESCENARIOS en 7 mares, con un JEFE cada 10 y su
## escenario pagando ×1,5 de experiencia (`SkillData.XP_BOSS_MULT`). Aquí
## están escritos los **35 del PRIMER MAR**, que se cierra con el Kappa, y los
## 25 del segundo.
##
## EL ORDEN LO DA LA POSICIÓN EN `PORTS`, NO EL ID. Los ids (`nivel_7`,
## `practica_2`...) son NOMBRES, no números de escenario: los guiones, los
## avisos previos del selector y las compuertas los referencian por ese nombre,
## y renumerarlos rompería las partidas guardadas y obligaría a tocar decenas
## de sitios. Lo que el jugador ve como "Escenario 12" es `port_index + 1`. Por
## eso el Kappa sigue llamándose `nivel_15` aunque sea el escenario 30, y el
## del maridaje `nivel_16` aunque sea el 11.
##
## LECCIÓN, PRÁCTICA, LECCIÓN, PRÁCTICA, sin excepción (pedido por el usuario):
## cada una de las 13 lecciones tiene detrás su propio escenario de práctica, y
## los tres EXTRAS (17, 18 y 19) —que son lección y práctica a la vez— llevan
## además una cuarta jornada (la 20) para gastar los tres juntos.
##
## CINCO DE LAS PRÁCTICAS TRAEN UN CLIENTE CON NOMBRE que paga con algo que no
## es oro, y LO QUE PAGA DEPENDE DE POR DÓNDE VA LA CAMPAÑA: nadie regala un
## coleccionable antes de haber explicado qué es, ni un mapa antes del 28. Y NO
## TODOS PAGAN CON PIEZA DE VITRINA (pedido por el usuario: el primer mar iba
## demasiado cargado de desbloqueables): el 7 paga en ARROZ, el 16 con un COFRE
## DE DOBLONES, el 20 con USOS DE LOS TRES EXTRAS y el 30 con una RECETA. Solo
## la bandera (15), la espada (25) y el tricornio (27) son de vitrina.
##
## El reparto (entre paréntesis, el id):
##    1 paciencia, bocado y oro — jornada normal          (nivel_1)
##    2 PRÁCTICA                                          (practica_1)
##    3 las CAJAS; la despensa empieza a gastarse         (nivel_2)
##    4 PRÁCTICA de las cajas                             (practica_5)
##    5 el PICOTEO: regalo del edamame                    (nivel_3)
##    6 PRÁCTICA del picoteo                              (practica_2)
##    7 PRÁCTICA · grumete: 3 gunkan de wakame -> 3 sacos (practica_8)
##    8 MULTIPLICADOR, hastío y paladar; abre la TIENDA    (nivel_4)
##    9 PRÁCTICA con la carta y la tienda abiertas        (practica_6)
##   10 POSTRES, PROPINAS y potenciadores                 (nivel_5)
##   11 PRÁCTICA                                          (practica_3)
##   12 el MARIDAJE, con ejercicio (té verde -> mochi)    (nivel_16)
##   13 PRÁCTICA de postres, propinas y parejas           (practica_7)
##   14 primer ABORDAJE y los primeros PIRATAS            (nivel_7)
##   15 PRÁCTICA · pirata: 3 platos -> la BANDERA         (practica_4)
##   16 PRÁCTICA · pirata: 3 distintos -> cofre de oro    (practica_9)
##   17 el WASABI, y con él los extras                    (nivel_6)
##   18 el JENGIBRE                                       (nivel_21)
##   19 la SOJA                                           (nivel_22)
##   20 PRÁCTICA de los tres extras · pirata -> extras    (practica_10)
##   21 CAI y la PESCA                                    (nivel_8)
##   22 PRÁCTICA: el examen antes de Pablo                (nivel_9)
##   23 Pablo el Rubio, los CAPITANES y el corte lento    (nivel_10)
##   24 PRÁCTICA de los capitanes                         (nivel_19)
##   25 PRÁCTICA · capitán: 4 distintos -> la ESPADA      (practica_11)
##   26 bocado acelerado y el futomaki                    (nivel_11)
##   27 PRÁCTICA; el capitán del TESORO pide una receta   (nivel_12)
##   28 los MAPAS DEL TESORO: los trae un GRUMETE         (nivel_17)
##   29 PRÁCTICA con un mapa armado                       (nivel_18)
##   30 PRÁCTICA · capitán: lo más caro -> una RECETA     (practica_12)
##   31 ALICE se enrola: el AYUDANTE                      (nivel_13)
##   32 PRÁCTICA del ayudante                             (nivel_20)
##   33 ALICE explica los BONIFICADORES                   (nivel_14)
##   34 la víspera: sin lecciones, a pulso                (vispera_kappa)
##   35 JEFE: el Kappa                                    (nivel_15)
##
## LO QUE SE VE EN CADA ESCENARIO ES SOLO LO YA EXPLICADO, y son compuertas
## por escenario que hay que poner A MANO en cada práctica: `no_storage` hasta
## las cajas (3), `no_variety_ui` hasta el multiplicador (8), `no_powerups`
## hasta los postres (10), `no_extras` hasta el wasabi (17) y `no_perks` hasta
## Alice (31). Se pagaron de verdad: el 2 sacaba las cajas sin explicar y el 6
## los bocadillos y las chapas del multiplicador.
##
## LA DIFICULTAD SUBE A LO LARGO DEL MAR, y las PRÁCTICAS van por encima de su
## lección (pedido por el usuario). Los `star_money` se revisaron con un modelo
## de capacidad (clientes × 3 platos × el mejor precio de su nivel): con los
## umbrales de antes, un escenario del final del mar pedía el 44% de lo que la
## carta podía rendir y uno del principio el 83% — la dificultad BAJABA. Hoy
## el 1 se queda en su ancla (40) y el resto sube de forma gradual hasta los
## 196 del 34 (eran 145), con cada práctica un 10-15% por encima de la lección
## de al lado. El JEFE (35) no se toca: su segunda estrella es la que saca al
## Kappa, y subirla lo retrasaría.
##
## AL REORDENAR ESTO HAY QUE REHACER CINCO COSAS, y ninguna avisa si se olvida
## (todas se pagaron ampliando el mar: de 20 a 25, a 30 y a 35):
##   1. `MAP_POS` — la altura es 3220 - 312*(pos-1) y el carril sale del ciclo
##      [CENTRO, IZQUIERDA, DERECHA] contado desde el 1. La cueva va aparte.
##   2. `KINDS` — `get_kind` cae a "isla" en silencio: un abordaje se jugó SIN
##      RELOJ y dos puertos salieron con palmeras.
##   3. `client_mix` — los piratas no suben hasta el primer abordaje (el 14) y
##      los capitanes hasta Pablo (el 23).
##   4. `chef_rec` — se MIDE con `tools/medir_chef_rec.gd`.
##   5. Las texturas de número (`tools/num_pintado.py`) y, si el mar crece,
##      `SCROLL_MIN` y `SEA_SIZE` de `level_select3d`: todo lo que hay por
##      encima de la cueva se corre, el mar 2 entero incluido.
## Y después, `tools/auditar.gd`, que comprueba las cinco.
##
## Recorrido MEDIDO con la curva de experiencia vigente (`tools/
## medir_chef_rec.gd`): los `chef_rec` de cada puerto son exactamente esa
## cuenta, y se vuelven a pegar cada vez que se toca la curva.
##
## LOS PRIMEROS ESCENARIOS SON TODOS DE GRUMETES a propósito: se aprende a
## cocinar antes de aprender a leer paladares. Piratas y capitanes entran en el
## primer abordaje.
##
## Los BONIFICADORES permanentes (PerkData) no se reparten hasta que Alice se
## enrola, en el 31 (`no_perks` en todos los anteriores); los POTENCIADORES de
## partida y las propinas se estrenan en el 10, con los postres.
##
## Lo que no cabe aquí (barco combinado, la mayor parte de la carta) queda para
## el segundo mar.
##
## Cada nivel es una partida corta. La puntuación es POR DINERO generado:
## "star_money" = [1★, 2★, 3★] doblones mínimos. Superar el nivel (alcanzar
## "goal_stars") desbloquea el siguiente y concede sus recompensas la 1ª vez.
##
## Campos de cada nivel:
##  - id, name, desc: identificación y texto para la pantalla de niveles.
##  - client_mix: en ISLAS y PUERTOS, el recuento EXACTO de clientes {E,A,G}
##    (E grumete, A pirata, G capitán): el nivel construye una cola barajada con
##    exactamente esos clientes y total_clients sale de la suma. En los
##    ABORDAJES no hay tope de clientes, así que la mezcla es solo la PRIMERA
##    tanda (en el orden que fije `late_type`) y, agotada, las llegadas siguen
##    sorteándose con esas mismas proporciones hasta que se acabe el reloj.
##  - arrival_span: ventana en segundos sobre la que se reparten las llegadas.
##    NO es la duración del nivel (ver más abajo): solo marca el RITMO al que
##    entra la clientela, y por eso lo llevan también los niveles sin reloj.
##  - patience_mult: multiplicador de paciencia (<1 = más difícil).
##  - arrival_scale: comprime el horario de llegadas (<1 = vienen más rápido).
##  - goal_stars: estrellas mínimas para superar el nivel y avanzar.
##  - star_money: [dinero para 1★, 2★, 3★] — SOLO precio de platos (sin propinas),
##    calibrado al techo de producción de cada nivel. Los 20 de hoy están
##    hechos para cocinero de nivel 1; los de los mares siguientes se escalan
##    contra un techo de MAESTRÍAS de ×2,0, no de ×2,45 (ver la cabecera de
##    `skill_data.gd`): con 250 escenarios el jugador real acaba sobre los 300
##    puntos, no con los 450 del catálogo entero.
##  - chef_rec: nivel de cocinero recomendado. NO es una fórmula: se MIDE con
##    la curva de experiencia real (`SkillData`), y es el nivel con el que se
##    llega bordando todos los escenarios anteriores. Salía de ceil(nº × 1.09)
##    cuando la curva era una recta y se subía un nivel por escenario; con la
##    curva cuadrática el ritmo se frena y esa fórmula pedía imposibles.
##    CADA TIPO DE NIVEL SE CALIBRA CONTRA LO QUE DE VERDAD LO LIMITA, y son
##    cosas distintas:
##     · Los ABORDAJES los limita el RELOJ (siempre hay a quien servir), así que
##       su techo es 150 s × los doblones por segundo de atención que rinde la
##       carta que se puede llevar.
##     · Las ISLAS y los PUERTOS los limita la CLIENTELA (cupo cerrado): su
##       techo es clientes × platos por cliente × PRECIO medio de la carta. Al
##       tocar precios, se reescalan por el cambio de precio medio, NO de $/s —
##       con el $/s salían cifras imposibles (el antiguo nivel 2 pedía 127
##       doblones con un techo real de ~75).
##    En los dos casos 1★/2★ quedan al ~35% y al ~62% del 3★. Y en este
##    primer mar-escuela las cifras van BAJAS a propósito (el usuario lo pidió
##    así): aquí se aprende; la exigencia llega con la campaña larga.
##  - fixed_recipes: carta CERRADA (las islas). El jugador no elige: se juega
##    con esas recetas y punto, también al repetir el puerto.
##    `fixed_recipes_replay` es la lista para cuando ya está superado (entran
##    los regalos de David de la primera pasada).
##    `optional_recipes` se SUMAN a la carta cerrada si el jugador las tiene
##    desbloqueadas (el gunkan de wakame del nivel 2: es premio de 3 estrellas
##    del 1, así que puede tenerlo o no).
##    `alt_recipes` es una lista por PREFERENCIA de la que entra SOLO LA
##    PRIMERA que esté desbloqueada (en el 3: el maki de pepino si lo tiene y,
##    si no, el gunkan de wakame). Así la carta cerrada mantiene su tamaño
##    tenga el jugador lo que tenga.
##  - free_ingredients: este puerto NO gasta usos de despensa (solo el nivel 1,
##    que es la jornada de práctica; el ARROZ sí se gasta desde el primer día).
##  - no_powerups: sin bote de propinas ni potenciadores de partida (el HUD
##    esconde el bote y las propinas no se acumulan). Escenarios 1-6: el bote
##    se estrena en el 7, con los postres.
##  - no_perks: este puerto no reparte BONIFICADORES permanentes aunque se
##    cumpla su combo. Escenarios 1-11: se estrenan en el 12.
##  - near_seats: la clientela ocupa las sillas por orden de CINTA en vez de al
##    azar (la escuela: con cuatro clientes sueltos, uno sentado justo detrás
##    del punto de salida se comería una vuelta entera de espera).
##  - arrival_batch: cuántos clientes entran DE GOLPE en cada llegada (el 4 va
##    de dos en dos y el 6 en dos tandas de cuatro).
##  - no_storage: sin cajas de guardado (solo el escenario 1: se enseñan en el 2).
##  - boss: id del JEFE del nivel ("kappa"). El guion lo trae cuando la primera
##    tanda ha comido y el nivel no se supera sin cumplir su condición (ver
##    level3d._finalize_results).
##  - reward_recipes: recetas que se desbloquean al SUPERARLO (goal_stars, que
##    son 2 estrellas: con 2★ el puerto queda pasado y se abre el siguiente).
##  - reward_recipes_3 / reward_ingots_3 / reward_rice_3: el premio GORDO, solo
##    al sacar las 3 estrellas; se puede volver a por él con mejor carta.
##    Este primer mar NO cubre la carta entera a propósito: el jugador
##    aprende ~la mitad de las recetas y el resto (más el barco combinado y
##    los bonificadores) queda para los niveles futuros. El DRAGON ROLL sigue
##    siendo exclusivo del día 7 del bonus diario.
##
## CÓMO TERMINA UN NIVEL (depende del TIPO, ver KINDS):
##  - "abordaje": es el único que lleva RELOJ, y son SHIP_TIME (2:30) para
##    todos. No hay tope de clientes: entran mientras quede tiempo. Acaba al
##    agotarse el reloj o al llegar al oro objetivo. (En el nivel del JEFE el
##    guion para el reloj cuando el jefe entra: manda su paciencia.)
##  - "isla" y "puerto": SIN reloj. Lo que los acota es la CLIENTELA: acaban
##    cuando se ha ido el último cliente de `client_mix` o al llegar al oro
##    objetivo. Su HUD no enseña contador de tiempo.

## Duración de los niveles de ABORDAJE, los únicos con reloj.
const SHIP_TIME := 150.0

## Con lo que arranca una partida nueva. El tutorial (la escena del rescate)
## entrega SOLO el maki de aguacate: el resto de la carta se gana nivel a nivel
## (el nigiri lo regala David en el 1, el té y el mochi en el 2...).
const INITIAL_RECIPES: Array = ["maki_aguacate"]
## Usos de ingredientes iniciales: NINGUNO a mano. La despensa la reparte
## `GameState.complete_tutorial`, que da `TUTORIAL_GIFT` (10) usos de todo lo
## que piden las recetas de inicio — la misma regla que cualquier receta que
## regale David después. Poner cifras aquí sumaba encima de ese regalo.
const INITIAL_INGREDIENTS: Dictionary = {}

## RETOS DEL CLIENTE CON TESORO. Un `collectible_client` puede pedir algo mas
## que "N platos": lo que pide va en su campo `reto`, y con el la pieza deja de
## ser un peaje y pasa a ser un ENCARGO que hay que leer y resolver con la
## carta que se llevo.
##
## El texto es el que canta David al sentarse el cliente Y el que se queda en
## la ficha de la vitrina, para que quien no lo consiguiera sepa a que volver.
## `%d` se rellena con `n` y `%s` con el nombre de la receta de `recipe`.
const RETO_TEXTOS := {
	"platos": "sírvele **%d platos**",
	"distintos": "sírvele **%d platos DISTINTOS**",
	"mismo": "sírvele **%d veces el MISMO plato**",
	"receta": "sírvele un **%s**",
	# N platos de una receta CONCRETA (el grumete del 7 y sus tres gunkan). Es
	# lo que hace que el encargo se pueda FALLAR por la carta: si esa receta no
	# va hoy, hay que volver otro día con ella.
	"receta_n": "sírvele **%d %s**",
	"postre_solo": "que su ÚNICO plato sea un **postre**",
	"platos_y_postre": "sírvele **%d platos** y ciérralo con un **postre**",
	"picoteos": "sírvele **%d picoteos**",
	"picoteos_sin_plato": "sírvele **%d picoteos** ANTES de darle ningún plato",
	"hasta_el_final": "que siga sentado cuando acabe el turno",
	"mismo_caro": "sírvele **%d veces** el plato MÁS CARO de tu carta",
	# NO PIDE NADA SUYO: pide la JORNADA. Se resuelve al cerrar el turno, con
	# las estrellas ya contadas (`level3d._check_treasure_estrellas`).
	"estrellas": "cierra la jornada con **%d estrellas**",
	"extras_distintos": "sírvele **%d platos**, cada uno con un **extra distinto**",
}


## LO MISMO EN PRIMERA PERSONA, que es como lo canta EL PROPIO CLIENTE al
## sentarse. Las de arriba estan escritas para que las narre un tercero
## ("sirvele un sashimi"), y puestas en su boca sonaban a que hablaba de otro.
## Van en una tabla aparte y no con un reemplazo de "le" por "me": hay frases
## que cambian mas ("que su UNICO plato" -> "que mi UNICO plato").
const RETO_TEXTOS_YO := {
	"platos": "sírveme **%d platos**",
	"distintos": "sírveme **%d platos DISTINTOS**",
	"mismo": "sírveme **%d veces el MISMO plato**",
	"receta": "sírveme un **%s**",
	"receta_n": "sírveme **%d %s**",
	"postre_solo": "que mi ÚNICO plato sea un **postre**",
	"platos_y_postre": "sírveme **%d platos** y ciérrame con un **postre**",
	"picoteos": "sírveme **%d picoteos**",
	"picoteos_sin_plato": "sírveme **%d picoteos** ANTES de darme ningún plato",
	"hasta_el_final": "que siga aquí sentado cuando acabe el turno",
	"mismo_caro": "sírveme **%d veces** el plato MÁS CARO de tu carta",
	"estrellas": "cierra la jornada con **%d estrellas** y es tuyo",
	"extras_distintos": "sírveme **%d platos**, cada uno con un **extra distinto**",
}


## Frase del reto de ese cliente, ya rellena. Sin `reto` cae en "platos", que
## es como funcionaba antes de que existieran los encargos. Con `yo`, la
## version que dice el cliente en vez de la que narra David.
static func reto_texto(cfg: Dictionary, yo := false) -> String:
	var reto := str(cfg.get("reto", "platos"))
	var tabla: Dictionary = RETO_TEXTOS_YO if yo else RETO_TEXTOS
	var plantilla := str(tabla.get(reto, tabla["platos"]))
	var n := int(cfg.get("n", cfg.get("plates", 3)))
	if plantilla.contains("%s"):
		var id := str(cfg.get("recipe", ""))
		var nombre := str(RecipeData.RECIPES.get(id, {}).get("name", id))
		if plantilla.contains("%d"):
			# "3 gunkan de wakame": la receta va en minúscula detrás del número.
			return plantilla % [n, nombre.to_lower()]
		return plantilla % nombre
	if plantilla.contains("%d"):
		return plantilla % n
	return plantilla


## CON QUÉ PAGA EL CLIENTE DEL TESORO, dicho por él mismo ("Pago con esto:
## ..."). Un `collectible_client` paga de SEIS maneras y las seis se nombran
## aquí, porque "pago con esto" a secas no decía nada (le pasó al usuario en el
## 7 y en el 16): `item` (pieza de vitrina), `mapa`, `arroz` (sacos), `oro`
## (un cofre de doblones), `receta_premio` (una receta) e `ingredientes` (usos
## de despensa). La misma frase la usa la ficha del mapa.
static func pago_texto(cfg: Dictionary) -> String:
	if bool(cfg.get("mapa", false)):
		return "**un mapa del tesoro**"
	var sacos := int(cfg.get("arroz", 0))
	if sacos > 0:
		return "**%d sacos de arroz**" % sacos if sacos != 1 else "**un saco de arroz**"
	var oro := int(cfg.get("oro", 0))
	if oro > 0:
		return "**un cofre con %d doblones**" % oro
	var receta := str(cfg.get("receta_premio", ""))
	if receta != "":
		var nombre := str(RecipeData.RECIPES.get(receta, {}).get("name", receta))
		return "**la receta del %s**" % nombre.to_lower()
	var usos: Dictionary = cfg.get("ingredientes", {})
	if not usos.is_empty():
		var partes: Array[String] = []
		for ing in usos:
			var nom := str(RecipeData.INGREDIENTS.get(ing, {}).get("name", ing))
			partes.append("%d de %s" % [int(usos[ing]), nom.to_lower()])
		return "**%s**" % " y ".join(partes)
	var pieza := str(cfg.get("item", ""))
	if pieza != "":
		return "**%s**" % str(CollectibleData.get_item(pieza).get("name", pieza))
	return "**esto**"


## EL TESORO DE UN ESCENARIO, sea de la clase que sea: {kind, id, n}. Es lo
## que pinta la ficha del mapa. `kind` ∈ item / mapa / arroz / oro / receta /
## ingredientes, o vacío si el escenario no paga con nada especial. Mira las
## mismas tres vías que `collectible_of`: el cliente del tesoro, la pieza que
## entrega un guion y el trofeo del jefe.
static func tesoro_de(port_id: String) -> Dictionary:
	var p := get_port(port_id)
	if p.is_empty():
		return {}
	var cli: Dictionary = p.get("collectible_client", {})
	if not cli.is_empty():
		if bool(cli.get("mapa", false)):
			return { "kind": "mapa", "id": "", "n": 1 }
		if int(cli.get("arroz", 0)) > 0:
			return { "kind": "arroz", "id": "", "n": int(cli["arroz"]) }
		if int(cli.get("oro", 0)) > 0:
			return { "kind": "oro", "id": "", "n": int(cli["oro"]) }
		if str(cli.get("receta_premio", "")) != "":
			return { "kind": "receta", "id": str(cli["receta_premio"]), "n": 1 }
		if not (cli.get("ingredientes", {}) as Dictionary).is_empty():
			var primero := str((cli["ingredientes"] as Dictionary).keys()[0])
			return { "kind": "ingredientes", "id": primero, "n": 0 }
		if str(cli.get("item", "")) != "":
			return { "kind": "item", "id": str(cli["item"]), "n": 1 }
	var aqui := str(p.get("collectible_here", {}).get("item", ""))
	if aqui != "":
		return { "kind": "item", "id": aqui, "n": 1 }
	var jefe := str(p.get("boss", ""))
	if jefe != "":
		return { "kind": "item", "id": str(CollectibleData.BOSS_ITEMS.get(jefe, "")), "n": 1 }
	return {}


## QUÉ HAY QUE HACER para llevarse el tesoro de ese escenario, sea el que sea
## (el gemelo de `collectible_how` para las pagas que no son de vitrina).
static func tesoro_como(port_id: String) -> String:
	var p := get_port(port_id)
	if p.is_empty():
		return ""
	var cliente: Dictionary = p.get("collectible_client", {})
	if not cliente.is_empty():
		return reto_texto(cliente)
	var aqui: Dictionary = p.get("collectible_here", {})
	if not aqui.is_empty():
		return reto_texto(aqui)
	if str(p.get("boss", "")) != "":
		return "ríndele en su duelo"
	return ""


## El escenario que lleva puesta esa BANDERA (`unlocks_shop`, `unlocks_fishing`
## ...), o "" si ninguno. Lo usan los avisos de "esto se abre en el escenario
## N" del menú, que estaban escritos a mano y se quedaron con los números de
## antes de reordenar la campaña.
static func port_with(flag: String) -> String:
	for p in PORTS:
		if bool(p.get(flag, false)):
			return str(p["id"])
	return ""

## QUE PIEZA DE VITRINA se puede conseguir en este escenario, si es que hay
## alguna. Es el inverso de `port_for_collectible` y mira las MISMAS tres vias:
## el cliente del TESORO, la que entrega un guion y el TROFEO del jefe. Lo usa
## la ficha del mapa para poner el icono con su interrogacion.
static func collectible_of(port_id: String) -> String:
	var p := get_port(port_id)
	if p.is_empty():
		return ""
	var cli := str(p.get("collectible_client", {}).get("item", ""))
	if cli != "":
		return cli
	var aqui := str(p.get("collectible_here", {}).get("item", ""))
	if aqui != "":
		return aqui
	var jefe := str(p.get("boss", ""))
	if jefe != "":
		return str(CollectibleData.BOSS_ITEMS.get(jefe, ""))
	return ""




## El escenario que reparte ese coleccionable, o "" si no sale de ninguno. Lo
## usa la VITRINA para decir DONDE se consigue una pieza que aun no se tiene.
##
## Mira las TRES vías por las que un escenario entrega una pieza, para que
## añadir una no obligue a tocar la vitrina: el cliente del TESORO, la que
## entrega un guion (`collectible_here`, la bandera del pirata) y el TROFEO
## del jefe, que se deduce de `boss` y no se escribe en ningún sitio.
static func port_for_collectible(item: String) -> String:
	for p in PORTS:
		if str(p.get("collectible_client", {}).get("item", "")) == item:
			return str(p["id"])
		if str(p.get("collectible_here", {}).get("item", "")) == item:
			return str(p["id"])
		var jefe := str(p.get("boss", ""))
		if jefe != "" and str(CollectibleData.BOSS_ITEMS.get(jefe, "")) == item:
			return str(p["id"])
	return ""


## QUÉ hay que hacer en ese escenario para llevarse la pieza, ya redactado.
## Sale de los MISMOS datos con que lo canta el cliente o el guion, así que
## la pista de la vitrina no puede contradecir lo que se oye en el nivel.
static func collectible_how(port_id: String, item: String) -> String:
	var p := get_port(port_id)
	if p.is_empty():
		return ""
	var cliente: Dictionary = p.get("collectible_client", {})
	if str(cliente.get("item", "")) == item:
		return reto_texto(cliente)
	var aqui: Dictionary = p.get("collectible_here", {})
	if str(aqui.get("item", "")) == item:
		return reto_texto(aqui)
	if str(CollectibleData.BOSS_ITEMS.get(str(p.get("boss", "")), "")) == item:
		return "ríndele en su duelo"
	return ""


## MAR al que pertenece el escenario. Hoy solo existe el primero, así que
## todos valen 1; el día que entre el segundo basta con que sus puertos
## declaren `"sea": 2` y la vitrina se entera sola.
static func sea_of(port_id: String) -> int:
	return maxi(int(get_port(port_id).get("sea", 1)), 1)


## CUÁNTOS MARES hay escritos. El mapa monta uno cada vez (ver la sección de
## la división por mares en CLAUDE.md), así que esto es lo que decide cuántos
## carteles de "al mar siguiente" puede haber.
static func sea_count() -> int:
	var n := 1
	for p in PORTS:
		n = maxi(n, int(p.get("sea", 1)))
	return n


## Los escenarios de ESE mar, en orden. Es la lista que monta el mapa: con los
## 250 de la campaña completa a la vez son 2,5 millones de triángulos y ~206 MB
## de vídeo (medido), y el móvil no llega.
static func ports_of_sea(mar: int) -> Array:
	var out: Array = []
	for p in PORTS:
		if int(p.get("sea", 1)) == mar:
			out.append(p)
	return out


## El PRIMER escenario de ese mar, o "" si el mar no existe.
static func first_port_of_sea(mar: int) -> String:
	for p in PORTS:
		if int(p.get("sea", 1)) == mar:
			return str(p["id"])
	return ""


## El NOMBRE del mar, para el cartel que lleva de uno a otro.
const SEA_NAMES := {
	1: "Mar de los Grumetes",
	2: "Mar de las Sirenas",
}


static func sea_name(mar: int) -> String:
	return str(SEA_NAMES.get(mar, "Mar %d" % mar))


## El NÚMERO que ve el jugador: su posición en la lista, que es lo único
## que se le ha enseñado nunca (los ids no se renumeran).
static func port_number(port_id: String) -> int:
	for i in PORTS.size():
		if str(PORTS[i]["id"]) == port_id:
			return i + 1
	return 0


const PORTS: Array = [
	{
		"id": "nivel_1",
		# Nivel de COCINERO recomendado. NO es una formula: es el nivel al que
		# LLEGA quien ha bordado todo lo anterior, MEDIDO con la curva real
		# por `tools/medir_chef_rec.gd`. Al reordenar la campaña o tocar una
		# tarifa hay que volver a pasarlo y pegar sus cifras aqui. Lo ensena
		# la ficha del mapa, para distinguir "voy corto de nivel" de "lo
		# estoy jugando mal".
		"chef_rec": 1,
		"name": "Cala Tortuga",
		"desc": "Tu primer turno de verdad: cuatro grumetes y dos recetas sencillas.",
		"client_mix": { "E": 4 },
		# Medido: con 110 el cuarto grumete no entraba hasta el segundo 88 y el
		# nivel se iba a tres minutos con un solo cliente en la barra casi todo
		# el rato. Con 75, las llegadas caen en 5 · 21 · 37 · 53 s.
		"arrival_span": 75.0,
		# Paciencia generosa: el primer cliente es la pizarra de David (paciencia,
		# bocado y oro se explican sobre él).
		"patience_mult": 1.15,
		"arrival_scale": 1.0,
		"goal_stars": 2,
		# Umbrales del usuario: 10 · 25 · 40 doblones.
		"star_money": [10, 25, 40],
		"reward_recipes": [],
		"reward_recipes_3": ["gunkan_wakame"],
		# UNA JORNADA CORRIENTE: el nigiri de salmón está en la carta DESDE EL
		# PRIMER FOTOGRAMA, tanto en el estreno como al repetir el nivel desde el
		# mapa o desde el botón "Repetir" del cartel de resultados. David solo lo
		# presenta; ya no hay que esperar a que lo saque a media partida.
		"fixed_recipes": ["maki_aguacate", "nigiri_salmon"],
		"gift_recipes": ["nigiri_salmon"],
		# Única jornada que no gasta DESPENSA (el arroz sí: es la energía y hay
		# que verla bajar desde el primer día).
		"free_ingredients": true,
		"no_powerups": true,
		# Las cajas son la lección del nivel 2: aquí ni aparecen.
		"no_storage": true,
		"no_extras": true,
		# Chapas de multiplicador: se explican en el 4.
		"no_variety_ui": true,
		"no_perks": true,
		# Sin botón de Salir en el ESTRENO (de la primera jornada no se huye);
		# a partir del segundo intento sale como en cualquier otro nivel, y de
		# eso se encarga level3d mirando si el puerto ya se ha jugado.
		"no_exit": true,
		# El primer grumete entra EN CUANTO acaba la preparación: los 5 s de
		# rigor eran cinco segundos mirando una cinta vacía en la primera
		# jornada del juego.
		"first_arrival": 0.0,
		# Cuatro clientes en las sillas que la cinta alcanza antes.
		"near_seats": true,
		# EL PRIMERO SE SIENTA EN LA SEGUNDA SILLA y el segundo en la primera:
		# así se ve desde el minuto uno que la cinta reparte por orden de PASO
		# y no por orden de llegada.
		"first_seats": [1, 0],
		"director": "nivel_1",
	},
	{
		"id": "practica_1",
		"chef_rec": 1,
		"name": "Ensenada del Mero",
		"desc": "Sin lecciones: solo tu cocina y cinco grumetes.",
		"client_mix": { "E": 5 },
		"arrival_span": 120.0,
		"patience_mult": 1.05,
		"arrival_scale": 0.9,
		"goal_stars": 2,
		"star_money": [18, 32, 52],
		"reward_recipes": [],
		"reward_recipes_3": [],
		# SIN SACO DE ARROZ: los premios de escenario son RECETAS (regla del
		# usuario). Este daba uno y desentonaba con el resto del mar.
		"reward_ingredients_3": { "salmon": 3, "aguacate": 2 },
		# Carta cerrada con lo aprendido en el 1 y el 2. El maki de pepino entra
		# si se ganaron las 3 estrellas del 2; si no, el gunkan.
		"fixed_recipes": ["maki_aguacate", "nigiri_salmon"],
		"alt_recipes": ["maki_pepino", "gunkan_wakame"],
		"no_powerups": true,
		# SIN CAJAS: se explican en el 3 (le paso al usuario: aparecian aqui
		# sin que nadie hubiera dicho para que sirven).
		"no_storage": true,
		"no_extras": true,
		"no_variety_ui": true,
		"no_perks": true,
		"near_seats": true,
	},
	{
		"id": "nivel_2",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 2,
		"name": "Playa del Coco",
		"desc": "Se junta la clientela: hoy aprendes a guardar platos en las cajas.",
		"client_mix": { "E": 4 },
		"arrival_span": 120.0,
		"patience_mult": 1.1,
		"arrival_scale": 0.9,
		"goal_stars": 2,
		"star_money": [15, 26, 42],
		"reward_recipes": [],
		"reward_recipes_3": ["maki_pepino"],
		# El primero entra solo; el guion trae a los otros TRES DE GOLPE cuando
		# se ha comido su segundo plato (ver level_director._nivel_2), que es lo
		# que justifica las cajas.
		"fixed_recipes": ["maki_aguacate", "nigiri_salmon"],
		# El gunkan es premio de 3 estrellas del nivel 1: entra en la carta solo
		# si el jugador se lo ganó.
		"optional_recipes": ["gunkan_wakame"],
		"no_powerups": true,
		"no_extras": true,
		"no_variety_ui": true,
		"no_perks": true,
		"near_seats": true,
		# Las cajas aparecen A MEDIA PARTIDA, con la lección. NO va aquí sino en
		# el guion (`level_director._nivel_2` las esconde al arrancar): así, al
		# repetir el nivel —donde el guion ya no corre— salen desde el principio.
		"director": "nivel_2",
	},
	{
		"id": "practica_5",
		"chef_rec": 3,
		"name": "Playa de las Gaviotas",
		"desc": "Sin lecciones: tu cocina, cinco grumetes y las cajas recién aprendidas.",
		"client_mix": { "E": 5 },
		"arrival_span": 118.0,
		"patience_mult": 1.02,
		"arrival_scale": 0.9,
		"goal_stars": 2,
		"star_money": [19, 34, 55],
		"reward_recipes": [],
		"reward_recipes_3": [],
		"reward_ingredients_3": { "pepino": 3 },
		"fixed_recipes": ["maki_aguacate", "nigiri_salmon"],
		"alt_recipes": ["maki_pepino", "gunkan_wakame"],
		"no_powerups": true,
		"no_extras": true,
		"no_variety_ui": true,
		"no_perks": true,
	},
	{
		"id": "nivel_3",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 4,
		"name": "Isla del Bambú",
		"desc": "Cinco grumetes hambrientos y un plato que se come sin soltar el otro.",
		"client_mix": { "E": 5 },
		"arrival_span": 120.0,
		"patience_mult": 1.05,
		"arrival_scale": 0.85,
		"goal_stars": 2,
		"star_money": [18, 32, 52],
		"reward_recipes": [],
		"reward_recipes_3": ["caldo_dashi"],
		# TRES recetas de carta: la cuarta la trae David al empezar (el edamame,
		# con la lección del picoteo).
		"fixed_recipes": ["maki_aguacate", "nigiri_salmon"],
		# La tercera sale de lo que el jugador se haya ganado, por preferencia.
		"alt_recipes": ["maki_pepino", "gunkan_wakame"],
		"gift_recipes": ["edamame"],
		"no_powerups": true,
		"no_extras": true,
		"no_variety_ui": true,
		"no_perks": true,
		"near_seats": true,
		"director": "nivel_3",
	},
	{
		"id": "practica_2",
		"chef_rec": 5,
		"name": "Caleta del Farol",
		"desc": "Una cala tranquila para asentar lo aprendido.",
		"client_mix": { "E": 8 },
		"arrival_span": 130.0,
		"patience_mult": 1.0,
		"arrival_scale": 0.85,
		"goal_stars": 2,
		"star_money": [31, 55, 88],
		"reward_recipes": [],
		"reward_recipes_3": [],
		# Premio de 3 estrellas: DESPENSA para la pareja de la carta (decidido
		# por el usuario). Van por `reward_ingredients_3`, el campo generico de
		# usos de ingrediente.
		"reward_ingredients_3": { "aguacate": 3, "pepino": 2 },
		# Isla: carta CERRADA con lo aprendido hasta aqui. El hueco variable lo
		# ocupa lo mejor que el jugador se haya ganado.
		"fixed_recipes": ["maki_aguacate", "nigiri_salmon", "edamame"],
		"alt_recipes": ["onigiri", "maki_pepino", "gunkan_wakame"],
		"arrival_batch": 2,
		"near_seats": true,
		# TODO LO QUE AUN NO SE HA EXPLICADO, APAGADO: el bote y los potenciadores
		# llegan en el 10, el multiplicador (bocadillos y chapas) en el 8, los
		# extras en el 17 y los bonificadores en el 31. Le paso al usuario:
		# aqui salian ya los bocadillos y las chapas sin lección detras.
		"no_powerups": true,
		"no_extras": true,
		"no_variety_ui": true,
		"no_perks": true,
	},
	{
		"id": "practica_8",
		"chef_rec": 5,
		"name": "Cala del Saco Perdido",
		"desc": "Un grumete se ha quedado en tierra con su saco de arroz. Y tiene un antojo.",
		"client_mix": { "E": 6 },
		"arrival_span": 115.0,
		"patience_mult": 1.0,
		"arrival_scale": 0.88,
		"goal_stars": 2,
		"star_money": [25, 43, 70],
		# EL CLIENTE PAGA CON ARROZ, no con pieza de vitrina: aqui todavia no se
		# ha hablado de los coleccionables (eso llega con el pirata de la
		# bandera, en el 15) y un cofre sin explicar no seria un premio sino un
		# misterio. El arroz, en cambio, se entiende desde el primer turno y es
		# lo unico que hace falta para zarpar.
		# Y PIDE UNA RECETA CONCRETA, no "cuatro platos" (pedido por el
		# usuario: "pago con esto" sin decir que ni a cambio de que no era un
		# encargo). El gunkan de wakame es el premio de 3 estrellas del 1, asi
		# que quien no lo tenga NO PUEDE cumplirlo hoy: la ficha del mapa se lo
		# dice al salir y vuelve con el gunkan ganado. Por eso entra en la carta
		# por `optional_recipes` y no por `alt_recipes`: con la lista de
		# preferencia, quien tuviera el maki de pepino jamas veia el gunkan.
		"collectible_client": {
			"who": "grumete", "type": "E", "arroz": 3,
			"reto": "receta_n", "recipe": "gunkan_wakame", "n": 3,
		},
		"fixed_recipes": ["maki_aguacate", "nigiri_salmon", "edamame"],
		"optional_recipes": ["gunkan_wakame"],
		"alt_recipes": ["maki_pepino"],
		"reward_recipes": [],
		"reward_recipes_3": [],
		"reward_ingredients_3": { "salmon": 2, "aguacate": 2 },
		"no_powerups": true,
		"no_extras": true,
		"no_variety_ui": true,
		"no_perks": true,
	},
	{
		"id": "nivel_4",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 6,
		"name": "Arrecife del Ron",
		"desc": "Ocho bocas de dos en dos. Y corre la voz de que hay tienda en el puerto.",
		"client_mix": { "E": 8 },
		"arrival_span": 140.0,
		"patience_mult": 1.0,
		"arrival_scale": 0.8,
		# De dos en dos: es lo que obliga a variar en vez de repetir el mismo
		# plato, que es la lección del nivel.
		"arrival_batch": 2,
		"goal_stars": 2,
		"star_money": [27, 48, 78],
		"reward_recipes": [],
		"reward_recipes_3": ["onigiri"],
		# Primer PUERTO: carta libre, pero solo TRES huecos.
		"recipe_slots": 3,
		# Primer paso por el selector: David lo explica antes de zarpar.
		"prep_dialog": "nivel_4",
		"gift_recipes": ["te_verde"],
		# Superarlo abre la TIENDA, y el guion lleva al jugador allí de la mano.
		"unlocks_shop": true,
		"director": "nivel_4",
		"no_powerups": true,
		"no_extras": true,
		"no_perks": true,
	},
	{
		"id": "practica_6",
		"chef_rec": 7,
		"name": "Fondeadero del Tonel",
		"desc": "Practica con la carta que tu elijas y el puesto de Saverio recien abierto.",
		"client_mix": { "E": 8 },
		"arrival_span": 115.0,
		"patience_mult": 0.98,
		"arrival_scale": 0.85,
		"goal_stars": 2,
		"star_money": [32, 57, 92],
		"reward_recipes": [],
		"reward_recipes_3": [],
		# TE y BONITO SECO (pedido por el usuario): el atun que daba antes no
		# tenia receta todavia (el nigiri de atun llega en el 14). El te es el
		# del te verde recien regalado y el bonito el del caldo dashi del 5.
		"reward_ingredients_3": { "te": 3, "katsuobushi": 3 },
		"no_powerups": true,
		"no_extras": true,
		"no_perks": true,
	},
	{
		"id": "nivel_5",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 7,
		"name": "Cala del Calamar",
		"desc": "El postre es la cuenta: aprende a despedir clientes y a llenar el bote.",
		"client_mix": { "E": 5 },
		"arrival_span": 120.0,
		"patience_mult": 1.0,
		"arrival_scale": 0.85,
		"goal_stars": 2,
		"star_money": [21, 37, 60],
		"reward_recipes": [],
		"reward_recipes_3": ["sunomono"],
		# Isla: carta cerrada con lo aprendido. El mochi lo regala David dentro.
		"fixed_recipes": ["maki_aguacate", "nigiri_salmon", "te_verde"],
		"gift_recipes": ["mochi"],
		# PRIMER NIVEL CON BOTE DE PROPINAS: aquí se estrenan los potenciadores
		# de partida. La PESCA NO se abre aquí: la trae Cai en la Isla de Gades
		# (nivel 8), que es quien da la clase. Este puerto se quedó con el
		# `unlocks_fishing` de cuando la pesca era suya, y como
		# `GameState.fishing_unlocked` devuelve en el PRIMER puerto que lo
		# lleve, el nivel 8 no pintaba nada: la pesca se abría en el 5 y el
		# jugador llegaba a la pantalla sin haber recibido la clase.
		"director": "nivel_5",
		"no_extras": true,
		"no_perks": true,
	},
	{
		"id": "practica_3",
		"chef_rec": 8,
		"name": "Rada del Pulpo",
		"desc": "Postres y propinas: todo junto y sin ayuda.",
		"client_mix": { "E": 9 },
		"arrival_span": 135.0,
		"patience_mult": 0.98,
		"arrival_scale": 0.85,
		"goal_stars": 2,
		"star_money": [38, 67, 108],
		"reward_recipes": [],
		"reward_recipes_3": [],
		# Premio de 3 estrellas: la despensa del MOCHI, que es lo que acaba de
		# regalar David. Daba tres usos de cada EXTRA y los extras no se
		# presentan hasta el 17 (le paso al usuario).
		"reward_ingredients_3": { "matcha": 3, "masa_mochi": 3 },
		# Isla: carta CERRADA con el postre de los grumetes dentro, que es lo
		# que esta practica pone a prueba.
		"fixed_recipes": ["maki_aguacate", "nigiri_salmon", "mochi"],
		"alt_recipes": ["sopa_miso", "caldo_dashi", "onigiri", "gunkan_wakame"],
		"arrival_batch": 2,
	},
	{
		"id": "nivel_16",
		"chef_rec": 8,
		"name": "Ensenada del Maridaje",
		"desc": "Dos platos que se buscan: el dulce sabe mejor detras del te.",
		# ESCENARIO 8, JUSTO DETRAS DEL DE LOS POSTRES (pedido por el usuario):
		# alli David menciona el maridaje de pasada al regalar el mochi, y aqui
		# se practica. Por eso es de GRUMETES a secas: en la escuela los piratas
		# no suben a bordo hasta el primer abordaje.
		"client_mix": { "E": 6 },
		"arrival_span": 105.0,
		"patience_mult": 1.0,
		"arrival_scale": 0.85,
		"goal_stars": 2,
		"star_money": [25, 43, 70],
		# LA LECCION: el MARIDAJE. Un plato paga un bono si el ANTERIOR que se
		# comio ese mismo cliente esta en su lista.
		# LA PAREJA ES TE VERDE -> MOCHI, y no la sopa de miso: los dos son
		# REGALOS de guion (el te en el escenario 5 y el mochi en el 7), asi que
		# a estas alturas el jugador los tiene SI O SI. La sopa de miso es el
		# premio de 3 estrellas del escenario 10 — o sea que ni siquiera existe
		# todavia, y una carta cerrada no se puede esquivar. Ademas es la misma
		# pareja que David nombra en el 7, asi que lo que se oye alli es lo que
		# se hace aqui.
		"fixed_recipes": ["nigiri_salmon", "maki_aguacate", "te_verde", "mochi"],
		"reward_recipes": [],
		"reward_recipes_3": ["nigiri_ebi"],
		"director": "nivel_16",
	},
	{
		"id": "practica_7",
		"chef_rec": 9,
		"name": "Islote de la Sal",
		"desc": "Practica: postres, propinas y parejas, sin nadie explicando nada.",
		"client_mix": { "E": 8 },
		"arrival_span": 115.0,
		"patience_mult": 0.95,
		"arrival_scale": 0.85,
		"goal_stars": 2,
		"star_money": [34, 61, 98],
		"reward_recipes": [],
		"reward_recipes_3": [],
		"reward_ingredients_3": { "gamba": 3, "aguacate": 3 },
		"fixed_recipes": ["nigiri_salmon", "maki_aguacate", "te_verde", "mochi"],
		"no_extras": true,
		"no_perks": true,
	},
	{
		"id": "nivel_7",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 10,
		"name": "Estrecho del Rayo",
		"desc": "¡Abordaje! Reloj, clientela sin fin y los primeros piratas.",
		# Abordaje: esta mezcla es solo la PRIMERA tanda. Un solo pirata en
		# ella —es EL primer pirata del juego y David lo presenta— y después,
		# agotada la tanda, uno de cada cuatro: hay nigiri de atún para ellos.
		# (LA BANDERA YA NO SE GANA AQUÍ: se movió al 15, la práctica del
		# abordaje, pedido por el usuario. El 14 presenta a los piratas y el 15
		# trae al que paga con su bandera.)
		"client_mix": { "E": 5, "A": 1 },
		"client_weights": { "E": 3, "A": 1 },
		# EL PIRATA ES EL TERCERO EN ENTRAR, y a propósito: tiene que llegar
		# pronto para que dé tiempo a estrenar el nigiri de atún con él, pero
		# después de un par de grumetes para que la novedad se note.
		"client_order": ["E", "E", "A", "E", "E", "E"],
		"arrival_span": 100.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.8,
		"goal_stars": 2,
		"star_money": [32, 57, 92],
		# El 4º hueco de la carta lo ocupa el REGALO de David (nigiri de atún),
		# que llega con el pirata: por eso solo se pueden elegir tres.
		"recipe_slots": 3,
		"gift_recipes": ["nigiri_atun"],
		# EL NIGIRI DE ATÚN ES SOLO PARA EL PIRATA mientras corre el guion. El
		# regalo de David es para estrenarlo CON ÉL, y sin reserva no llegaba:
		# un plato de 2★ pasa por delante de los grumetes, que lo cogen al 20%
		# cada uno, así que con cuatro sentados se lo comían antes el 59% de
		# las veces. Se veía como "las probabilidades están mal" y en realidad
		# era el dado haciendo su trabajo cuatro veces seguidas.
		"exclusive_types": { "nigiri_atun": "A" },
		"reward_recipes": [],
		"reward_recipes_3": ["maki_atun"],
		"near_seats": true,
		"director": "nivel_7",
		"no_perks": true,
	},
	{
		"id": "practica_4",
		"chef_rec": 10,
		"name": "Paso de las Barracudas",
		"desc": "Un abordaje corriente... y un pirata que paga con su bandera.",
		"client_mix": { "E": 5, "A": 2 },
		"client_weights": { "E": 3, "A": 2 },
		# EL PIRATA DE LA BANDERA ENTRA EL TERCERO: pronto, para que dé tiempo
		# a sus tres platos en un turno de 2:30, y detrás de dos grumetes. Es
		# el PRIMER pirata que sube (el cliente del tesoro es el primero de su
		# tipo que aparece); los que vengan después son clientela normal.
		"client_order": ["E", "E", "A", "E", "A", "E", "E"],
		# LA BANDERA PIRATA sale de AQUÍ (pedido por el usuario: el 14 presenta
		# a los piratas y el 15 trae al que paga con su bandera). Va por el
		# mecanismo general del cliente del tesoro —él mismo canta el trato al
		# sentarse y lo cierra con un "lo prometido" al cumplirse—, así que es
		# el ÚNICO sitio del juego donde se consigue esa pieza, y es la primera
		# de vitrina: David explica qué son los coleccionables al entregarla.
		"collectible_client": {
			"who": "pirata", "type": "A", "item": "bandera",
			"reto": "platos", "n": 3,
		},
		"arrival_span": 105.0,
		"patience_mult": 0.92,
		"arrival_scale": 0.78,
		"goal_stars": 2,
		"star_money": [42, 74, 120],
		"reward_recipes": [],
		"reward_recipes_3": [],
		# Premio de 3 estrellas: la despensa del nigiri de atún recién regalado
		# (y el nori del maki de atún, premio del 14). Daba un CEBO y la pesca
		# no abre hasta el 21 (le pasó al usuario).
		"reward_ingredients_3": { "atun": 3, "nori": 3 },
	},
	{
		"id": "practica_9",
		"chef_rec": 11,
		"name": "Fondeadero del Tuerto",
		"desc": "Practica con piratas. Uno de ellos paga con un cofre.",
		"client_mix": { "E": 5, "A": 3 },
		"client_order": ["E", "A", "E", "A", "E", "A", "E", "E"],
		"arrival_span": 110.0,
		"patience_mult": 0.95,
		"arrival_scale": 0.85,
		"goal_stars": 2,
		"star_money": [39, 68, 110],
		# UN PIRATA QUE PAGA CON UN COFRE DE DOBLONES. Pagaba con el PARCHE y
		# se cambio (pedido por el usuario: el primer mar iba demasiado cargado
		# de desbloqueables; un cliente con encargo puede pagar en oro, en
		# despensa o con una receta). El parche se queda sin fuente, para
		# otro mar.
		"collectible_client": {
			"who": "pirata", "type": "A", "oro": 150,
			"reto": "distintos", "n": 3,
		},
		"reward_recipes": [],
		"reward_recipes_3": [],
		"reward_ingredients_3": { "salmon": 3, "atun": 3 },
		"no_extras": true,
		"no_perks": true,
	},
	{
		"id": "nivel_6",
		"chef_rec": 12,
		"name": "Bahía del Kraken",
		"desc": "Saverio abre su caja: el WASABI, sobre el plato ya terminado.",
		# --- EL PRIMERO DE LOS TRES ESCENARIOS DE EXTRAS ------------------
		# Los extras ya no llegan los tres de golpe (pedido por el usuario):
		# cada uno tiene SU jornada —wasabi, jengibre y soja, seguidas— porque
		# son lecciones de dos frases y lo que hace falta es USARLAS. Por eso
		# estos tres NO llevan escenario de práctica detrás: cada uno ES su
		# propia práctica.
		"client_mix": { "E": 6, "A": 2 },
		"arrival_span": 90.0,
		"patience_mult": 0.95,
		"arrival_scale": 0.8,
		# Dos tandas de cuatro: la barra se llena de golpe dos veces.
		"arrival_batch": 4,
		"goal_stars": 2,
		"star_money": [34, 60, 96],
		"reward_recipes": [],
		"reward_recipes_3": ["sopa_miso"],
		"director": "nivel_6",
		"no_perks": true,
	},
	{
		"id": "nivel_21",
		"chef_rec": 12,
		"name": "Rada del Paladar Limpio",
		"desc": "El JENGIBRE: borra lo que ha probado, a cambio de un punto de chapa.",
		"client_mix": { "E": 6, "A": 2 },
		"arrival_span": 95.0,
		"patience_mult": 0.95,
		"arrival_scale": 0.8,
		"goal_stars": 2,
		"star_money": [36, 63, 102],
		"reward_recipes": [],
		"reward_recipes_3": ["nigiri_inari"],
		"director": "nivel_21",
		"no_perks": true,
	},
	{
		"id": "nivel_22",
		"chef_rec": 13,
		"name": "Ensenada de la Salazón",
		"desc": "La SOJA: engorda la propina, pero el bocado se acaba antes.",
		"client_mix": { "E": 6, "A": 3 },
		"arrival_span": 100.0,
		"patience_mult": 0.95,
		"arrival_scale": 0.8,
		"goal_stars": 2,
		"star_money": [39, 68, 110],
		"reward_recipes": [],
		"reward_recipes_3": ["sashimi_tamago"],
		"director": "nivel_22",
		"no_perks": true,
	},
	{
		"id": "practica_10",
		"chef_rec": 14,
		"name": "Rada del Rallador",
		"desc": "La jornada de los tres extras juntos, y un pirata que sabe de eso.",
		"client_mix": { "E": 5, "A": 4 },
		"client_order": ["E", "A", "E", "A", "E", "A", "E", "A", "E"],
		"arrival_span": 115.0,
		"patience_mult": 0.95,
		"arrival_scale": 0.85,
		"goal_stars": 2,
		"star_money": [44, 78, 126],
		# LA PRACTICA DE LOS TRES EXTRAS JUNTOS, y por eso su encargo los pide
		# los tres: es el unico reto del juego que obliga a usar los tres en la
		# misma jornada, que es justo lo que las tres lecciones sueltas no
		# ensenan. Y PAGA CON EXTRAS: cuatro usos de cada uno, que es lo que un
		# pirata "que sabe de eso" lleva encima. Pagaba con el rallador de piel
		# de tiburon (pieza de vitrina) y se cambio por despensa, pedido por el
		# usuario: demasiados desbloqueables en el primer mar.
		"collectible_client": {
			"who": "pirata", "type": "A",
			"ingredientes": { "wasabi": 4, "jengibre": 4, "soja": 4 },
			"reto": "extras_distintos", "n": 3,
		},
		"reward_recipes": [],
		"reward_recipes_3": [],
		# La despensa de las tres recetas de los extras (miso, inari, tamago).
		"reward_ingredients_3": { "miso": 3, "tofu_frito": 3, "huevo": 3 },
		"no_perks": true,
	},
	{
		"id": "nivel_8",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 14,
		"name": "Isla de Gades",
		"desc": "Un pescador silencioso espera en la orilla con su caña.",
		# CAI SE SIENTA A COMER: es el PRIMER pirata que entra (`special_client`
		# le pone su modelo) y el trato del nivel es llenarle la barriga.
		"client_mix": { "E": 4, "A": 2 },
		"client_order": ["E", "A", "E", "E", "A", "E"],
		"special_client": { "who": "cai", "type": "A" },
		"arrival_span": 120.0,
		"patience_mult": 0.95,
		"arrival_scale": 0.85,
		"goal_stars": 2,
		"star_money": [27, 47, 76],
		# Isla: carta cerrada con lo aprendido hasta aquí.
		"fixed_recipes": ["maki_aguacate", "nigiri_salmon", "nigiri_atun",
			"te_verde"],
		# Superarlo trae a CAI a la tripulación y con él la PESCA.
		"unlocks_fishing": true,
		"reward_recipes": [],
		"reward_recipes_3": ["dorayaki"],
		"near_seats": true,
		"director": "nivel_8",
		"no_perks": true,
	},
	{
		"id": "nivel_9",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 15,
		"name": "Puerto Tormenta",
		"desc": "Diez bocas en dos oleadas, y la mitad son piratas.",
		"client_mix": { "E": 6, "A": 4 },
		# DOS TANDAS DE CINCO, cada una de tres grumetes y dos piratas: el orden
		# es explícito porque con la baraja no había forma de garantizarlo.
		"client_order": ["E", "E", "E", "A", "A", "E", "E", "E", "A", "A"],
		"arrival_batch": 5,
		"arrival_span": 130.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.8,
		"goal_stars": 2,
		"star_money": [44, 78, 126],
		# EL NIVEL DE LOS BONIFICADORES: David los explica antes de empezar y
		# regala el del PALADAR, que es el único que se puede ganar todavía.
		"director": "nivel_9",
		"reward_recipes": [],
		"reward_recipes_3": ["udon"],
	},
	{
		"id": "nivel_10",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 15,
		"name": "Flota del capitán Pablo el Rubio",
		"desc": "Abordaje a la flota de un viejo conocido de David.",
		"client_mix": { "E": 2, "A": 2, "G": 1 },
		"arrival_span": 120.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.7,
		"goal_stars": 2,
		"star_money": [39, 68, 110],
		# Carta LIBRE, pero solo tres huecos: el cuarto lo ocupa el tsuke don
		# que regala David cuando Pablo se sienta.
		"recipe_slots": 3,
		# El capitán del nivel es Pablo el Rubio: mismo comportamiento que un
		# capitán normal, pero con su propio modelo (ver CharacterData).
		"special_client": { "who": "pablo", "type": "G" },
		# Pablo entra el ÚLTIMO; si el jugador va sobrado, el guion lo adelanta.
		"late_type": "G",
		"director": "nivel_10",
		# David avisa en el selector de recetas antes de zarpar.
		"prep_dialog": "nivel_10",
		"gift_recipes": ["salmon_tsuke_don"],
		# Mientras corre el guion, el tsuke don es SOLO para Pablo (es su
		# regalo); al repetir el puerto ya se le puede servir a cualquiera.
		"exclusive_dishes": { "salmon_tsuke_don": "pablo" },
		"reward_recipes": [],
		"reward_recipes_3": ["aburi"],
	},
	{
		"id": "nivel_19",
		"chef_rec": 16,
		"name": "Paso de los Cangrejos",
		"desc": "Abordaje corto y apretado: entran de dos en dos y no paran.",
		"client_mix": { "E": 4, "A": 3, "G": 2 },
		"arrival_span": 100.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.75,
		"goal_stars": 2,
		"star_money": [53, 94, 152],
		"arrival_batch": 2,
		"boat": true,
		"reward_recipes": [],
		"reward_recipes_3": ["taiyaki"],
	},
	{
		"id": "practica_11",
		"chef_rec": 17,
		"name": "Escollo del Sable",
		"desc": "Un capitan con prisa y buen paladar. Paga bien quien come variado.",
		"client_mix": { "E": 4, "A": 3, "G": 2 },
		"client_order": ["E", "A", "G", "E", "A", "E", "G", "A", "E"],
		"arrival_span": 120.0,
		"patience_mult": 0.92,
		"arrival_scale": 0.82,
		"goal_stars": 2,
		"star_money": [53, 93, 150],
		# UN CAPITAN, que aqui ya existen (llegan con Pablo, en el 23), y un
		# LINGOTE de propina a las tres estrellas: los lingotes tambien se
		# explicaron alli, asi que la cifra ya significa algo.
		"collectible_client": {
			"who": "capitan", "type": "G", "item": "espada",
			"reto": "distintos", "n": 4,
		},
		"reward_recipes": [],
		"reward_recipes_3": [],
		"reward_ingots_3": 1,
		"boat": true,
	},
	{
		"id": "nivel_11",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 17,
		"name": "Cala del Hambre",
		"desc": "Tres bocas, una de ellas con un hambre que no es normal.",
		"client_mix": { "E": 1, "A": 1, "G": 1 },
		"client_order": ["E", "A", "G"],
		"arrival_span": 80.0,
		"patience_mult": 1.0,
		"arrival_scale": 0.9,
		"goal_stars": 2,
		"star_money": [25, 45, 72],
		# LA BARRA DE BOCADO CORRE: aquí mastican mucho más rápido de lo normal,
		# así que el hueco entre plato y plato se encoge y hay que cocinar
		# DEPRISA. Es la premisa de la lección (el futomaki).
		"bite_speed": 1.8,
		"fixed_recipes": ["maki_aguacate", "nigiri_atun", "salmon_tsuke_don"],
		"gift_recipes": ["futomaki_salmon"],
		"reward_recipes": [],
		"reward_recipes_3": ["sashimi_atun_rojo"],
		"near_seats": true,
		"director": "nivel_11",
	},
	{
		"id": "nivel_12",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 18,
		"name": "Ensenada del Naufragio",
		"desc": "Corre la voz de que alguien paga en tesoros, no en oro.",
		"client_mix": { "E": 4, "A": 3, "G": 1 },
		"arrival_span": 130.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.8,
		"goal_stars": 2,
		"star_money": [48, 84, 136],
		# CLIENTE CON TESORO: un capitán que, bien servido, paga con un
		# COLECCIONABLE en vez de con oro (ver `collectible_client`). Es la
		# lección del nivel y de aquí en adelante puede pasar en cualquiera.
		"collectible_client": {
			"who": "capitan", "type": "G", "item": "tricornio",
			"reto": "receta", "recipe": "sashimi_atun_rojo",
		},
		"late_type": "G",
		# SIN guion propio: la leccion de "clientes que pagan con tesoro" ya la
		# dio el pirata de la bandera en el escenario 10, y aqui el encargo lo
		# canta el propio capitan (el director se monta solo por el vigia del
		# tesoro). El encargo es DISTINTO al del 10 a proposito: pide una receta
		# concreta, el sashimi de atun rojo, que es el premio de 3 estrellas del
		# escenario anterior — quien no lo tenga (o no lo lleve en la carta)
		# tendra que volver con el.
		"reward_recipes": [],
		"reward_recipes_3": ["gunkan_tartar"],
	},
	{
		"id": "nivel_17",
		"chef_rec": 18,
		"name": "Caleta del Cartografo",
		"desc": "Un grumete trae un mapa heredado y lo cambia por una buena jornada.",
		"client_mix": { "E": 4, "A": 3, "G": 1 },
		# EL DEL MAPA ENTRA EL PRIMERO: su encargo es la jornada ENTERA, asi que
		# tiene que cantarlo antes de que empiece a contar.
		"client_order": ["E", "A", "E", "G", "A", "E", "A", "E"],
		"arrival_span": 115.0,
		"patience_mult": 0.95,
		"arrival_scale": 0.85,
		"goal_stars": 2,
		"star_money": [51, 91, 146],
		# EL ESCENARIO QUE ESTRENA LOS MAPAS DEL TESORO. Lo trae un GRUMETE
		# (pedido por el usuario), no un capitan: su encargo no es un capricho
		# de mesa sino la jornada entera —"si haces un buen servicio, el mapa es
		# tuyo"—, o sea las TRES ESTRELLAS. Por eso su reto es `estrellas`, que
		# como `hasta_el_final` no se puede resolver mirando lo que ha comido:
		# se resuelve al cerrar el turno.
		"collectible_client": {
			"who": "grumete", "type": "E", "mapa": true,
			"reto": "estrellas", "n": 3,
		},
		"reward_recipes": [],
		"reward_recipes_3": ["gunkan_ikura"],
		"director": "nivel_17",
	},
	{
		"id": "nivel_18",
		"chef_rec": 19,
		"name": "Rada de las Tres Anclas",
		"desc": "Practica. Ni lecciones ni sorpresas: solo servicio.",
		# ESCENARIO 25: practica de la leccion de los MAPAS DEL TESORO, ya con
		# la clientela completa. Estuvo en el 11 y era de grumetes a secas; al
		# moverlo hasta aqui hubo que rehacerle la mezcla, que es la trampa de
		# siempre al reordenar la campaña.
		"client_mix": { "E": 4, "A": 3, "G": 2 },
		"arrival_span": 120.0,
		"patience_mult": 0.92,
		"arrival_scale": 0.82,
		"goal_stars": 2,
		"star_money": [56, 99, 160],
		"reward_recipes": [],
		"reward_recipes_3": ["nigiri_anguila"],
	},
	{
		"id": "practica_12",
		"chef_rec": 20,
		"name": "Bajio de la Carta Marcada",
		"desc": "Carta cerrada y un capitan que paga con una receta a quien le sirva lo mas caro.",
		"client_mix": { "E": 4, "A": 3, "G": 2 },
		"client_order": ["E", "A", "G", "E", "A", "E", "G", "A", "E"],
		"arrival_span": 120.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.82,
		"goal_stars": 2,
		"star_money": [60, 107, 172],
		# PAGA CON UNA RECETA: el sashimi variado, de tres estrellas (pedido
		# por el usuario: un cliente con encargo tambien puede pagar con una
		# receta nueva). Pagaba con un mapa del tesoro; los mapas siguen
		# llegando por el grumete del 28, los cofres de la pesca y el bonus
		# diario. Su reto es `mismo_caro`, que con la CARTA CERRADA de una isla
		# se lee de un vistazo: el plato mas caro esta a la vista y no cambia.
		"collectible_client": {
			"who": "capitan", "type": "G", "receta_premio": "sashimi_variado",
			"reto": "mismo_caro", "n": 3,
		},
		"fixed_recipes": ["nigiri_salmon", "nigiri_atun", "sopa_miso",
			"salmon_tsuke_don"],
		"reward_recipes": [],
		"reward_recipes_3": [],
		"reward_ingredients_3": { "salmon": 5, "atun": 5 },
		"boat": true,
	},
	{
		"id": "nivel_13",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 20,
		"name": "Rada de los Dos Fuegos",
		"desc": "Demasiadas comandas para un solo par de manos.",
		"client_mix": { "E": 5, "A": 3, "G": 2 },
		"arrival_span": 120.0,
		"patience_mult": 0.85,
		"arrival_scale": 0.7,
		"goal_stars": 2,
		"star_money": [53, 93, 150],
		# EL AYUDANTE: aquí se presenta y desde aquí se puede ganar.
		# ALICE se sienta en la barra como una clienta mas: come de UNA estrella
		# (es una aprendiza, no una lobo de mar) y trae su propio modelo.
		"special_client": { "who": "alice", "type": "E" },
		"unlocks_perks": true,
		"unlocks_perk": "ayudante",
		"prep_dialog": "nivel_13",
		"director": "nivel_13",
		"reward_recipes": [],
		"reward_recipes_3": ["nigiri_pulpo"],
	},
	{
		"id": "nivel_20",
		"chef_rec": 21,
		"name": "Muelle del Farolero",
		"desc": "El ultimo puerto con clientela de verdad antes de la bruma.",
		"client_mix": { "E": 5, "A": 4, "G": 2 },
		"arrival_span": 135.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.8,
		"goal_stars": 2,
		"star_money": [62, 110, 178],
		"boat": true,
		"reward_recipes": [],
		"reward_recipes_3": ["uramaki_california"],
	},
	{
		"id": "nivel_14",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 21,
		"name": "Muelle de las Bandejas",
		"desc": "Muelle largo y clientela sin prisa: buen día para probar cosas.",
		"client_mix": { "E": 5, "A": 4, "G": 2 },
		"arrival_span": 130.0,
		"patience_mult": 0.85,
		"arrival_scale": 0.7,
		"goal_stars": 2,
		"star_money": [62, 109, 176],
		"boat": true,
		# SIN `unlocks_perk`: el BARCO se aprende en el mar 2 (decidido por el
		# usuario). El puerto sigue PERMITIENDO el barco para cuando llegue, y
		# aqui Alice explica en su lugar que hay mas bonificadores y como se
		# ganan (`level_director._nivel_14`).
		"prep_dialog": "nivel_14",
		"director": "nivel_14",
		"reward_recipes": [],
		"reward_recipes_3": ["chirashi"],
	},
	{
		"id": "vispera_kappa",
		"chef_rec": 22,
		"name": "Bruma del Estrecho",
		"desc": "La última parada antes de la guarida. Aquí ya no se enseña nada.",
		"client_mix": { "E": 6, "A": 4, "G": 2 },
		"arrival_span": 140.0,
		"patience_mult": 0.88,
		"arrival_scale": 0.8,
		"goal_stars": 2,
		"star_money": [69, 122, 196],
		"reward_recipes": [],
		"reward_recipes_3": ["fugu"],
		"reward_ingots_3": 2,
		"arrival_batch": 2,
	},
	{
		"id": "nivel_15",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 23,
		"name": "Cueva del Kappa",
		"desc": "Algo enorme y hambriento ronda estas aguas...",
		"client_mix": { "E": 3, "A": 2, "G": 1 },
		"arrival_span": 90.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.8,
		"goal_stars": 2,
		# JEFE: superar el nivel exige que el Kappa coma BOSS_PLATES platos (ver
		# level_director._nivel_15). El dinero solo decide la 3ª estrella.
		"star_money": [40, 70, 110],
		"boss": "kappa",
		"boat": true,
		"director": "nivel_15",
		"prep_dialog": "nivel_15",
		"reward_recipes": ["tempura"],
		"reward_recipes_3": ["temaki"],
		"reward_ingots_3": 2,
	},
	{
		"id": "m2_01",
		"sea": 2,
		"chef_rec": 23,
		"name": "Cala del Rumor",
		"desc": "La puerta del Mar de las Sirenas. Aquí la clientela ya no perdona.",
		"client_mix": { "E": 7, "A": 2 },
		"arrival_span": 120.0,
		"patience_mult": 0.95,
		"goal_stars": 2,
		"star_money": [55, 95, 150],
		"fixed_recipes": ["nigiri_salmon", "maki_atun", "sunomono", "mochi"],
		# EL PREMIO DE 3 ESTRELLAS ES LA PRIMERA MEJORA DE RECETA (ver el
		# bloque de MEJORAS en RecipeData): el maki de aguacate coronado con
		# mayonesa japonesa y cebolla frita. La presenta ALICE en el mapa
		# (main_menu._presentar_mejora): se la enseno su maestra Miku.
		"reward_upgrade_3": "maki_aguacate",
	},
	{
		"id": "m2_02",
		"sea": 2,
		"chef_rec": 24,
		"name": "Islote del Eco",
		"desc": "Las rocas devuelven cada voz... y alguna que nadie dijo.",
		"client_mix": { "E": 6, "A": 3, "G": 1 },
		"arrival_span": 125.0,
		"patience_mult": 0.92,
		# Mastican mas deprisa: vuelven a la cinta antes y piden mas.
		"bite_speed": 1.15,
		"goal_stars": 2,
		"star_money": [58, 100, 158],
		"reward_recipes_3": ["bol_arroz"],
		# CON UN CAPITAN EN LA MEZCLA, LA CARTA CERRADA LLEVA UN 3 ESTRELLAS
		# (le paso al usuario: el capitan miraba la cinta toda la jornada).
		# Entra por preferencia el tsuke don o el futomaki, los dos regalos de
		# guion del mar 1, asi que siempre hay uno.
		"fixed_recipes": ["maki_aguacate", "nigiri_atun", "dorayaki"],
		"alt_recipes": ["salmon_tsuke_don", "futomaki_salmon"],
	},
	{
		"id": "m2_03",
		"sea": 2,
		"chef_rec": 25,
		"name": "Puerto Habanera",
		"desc": "Un puerto orgulloso donde la fama corre más que la marea.",
		"client_mix": { "E": 8, "A": 3, "G": 1 },
		"arrival_span": 130.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.8,
		"goal_stars": 2,
		"star_money": [58, 100, 158],
		"reward_recipes_3": ["gunkan_shiitake"],
	},
	{
		"id": "m2_04",
		"sea": 2,
		"chef_rec": 25,
		"name": "Amarradero del Norte",
		"desc": "Aquí se atraca con tres cabos y se cocina con tres recetas.",
		"client_mix": { "E": 7, "A": 4, "G": 2 },
		"arrival_span": 135.0,
		"patience_mult": 0.9,
		"arrival_batch": 2,
		# La carta se queda en TRES huecos: elegir duele.
		"recipe_slots": 3,
		"goal_stars": 2,
		"star_money": [60, 105, 165],
		"reward_recipes_3": ["nigiri_caballa"],
	},
	{
		"id": "m2_05",
		"sea": 2,
		"chef_rec": 26,
		"name": "Isla del Catalejo",
		"desc": "Un capitán otea el horizonte... y tu cinta.",
		"client_mix": { "E": 5, "A": 3, "G": 1 },
		"arrival_span": 120.0,
		"patience_mult": 0.9,
		"goal_stars": 2,
		"star_money": [58, 100, 160],
		"reward_recipes_3": ["tsukemono"],
		"fixed_recipes": ["nigiri_atun", "maki_pepino", "edamame", "taiyaki"],
		"alt_recipes": ["sashimi_atun_rojo", "nigiri_pulpo"],
		# EL CAPITAN DEL MAPA: paga con un MAPA DEL TESORO ("mapa": true) si se
		# le cumple el capricho — N veces el plato MAS CARO de la carta de hoy.
		"collectible_client": {
			"who": "capitan", "type": "G", "mapa": true,
			"reto": "mismo_caro", "n": 3,
		},
		"late_type": "G",
	},
	{
		"id": "m2_06",
		"sea": 2,
		"chef_rec": 26,
		"name": "Paso de la Saloma",
		"desc": "El primer abordaje del mar nuevo. El reloj aquí es de cristal.",
		"client_mix": { "E": 5, "A": 3, "G": 1 },
		"arrival_span": 130.0,
		"patience_mult": 0.9,
		"goal_stars": 2,
		"star_money": [60, 105, 165],
		"reward_recipes_3": ["ensalada_wakame"],
	},
	{
		"id": "m2_07",
		"sea": 2,
		"chef_rec": 27,
		"name": "Estrecho del Lamento",
		"desc": "Dos minutos justos: el estrecho no da para más.",
		"client_mix": { "E": 5, "A": 4, "G": 1 },
		"arrival_span": 105.0,
		"patience_mult": 0.9,
		# MENOS RELOJ: 2:00 en vez de 2:30. El objetivo va recalibrado a esa
		# duracion (~4/5 del paso normal).
		"time_limit": 120.0,
		"late_type": "G",
		"goal_stars": 2,
		"star_money": [52, 92, 145],
		"reward_recipes_3": ["gunkan_jurel"],
	},
	{
		"id": "m2_08",
		"sea": 2,
		"chef_rec": 27,
		"name": "Cala del Arrullo",
		"desc": "Un canto dulce sale del agua. Nadie recuerda haberlo aprendido.",
		"client_mix": { "E": 6, "A": 3 },
		"arrival_span": 130.0,
		"patience_mult": 0.95,
		"sirena": true,
		"director": "mar2_sirena",
		"goal_stars": 2,
		"star_money": [58, 102, 162],
		"reward_upgrade_3": "nigiri_salmon",
		"fixed_recipes": ["nigiri_salmon", "maki_aguacate", "sunomono", "mochi"],
	},
	{
		"id": "m2_09",
		"sea": 2,
		"chef_rec": 28,
		"name": "Arrecife del Coro",
		"desc": "Aquí no canta una voz. Cantan varias, y se turnan.",
		"client_mix": { "E": 5, "A": 4, "G": 1 },
		"arrival_span": 125.0,
		"patience_mult": 0.9,
		"bite_speed": 1.2,
		"sirena": true,
		"goal_stars": 2,
		"star_money": [62, 108, 170],
		"reward_recipes_3": ["nigiri_besugo"],
		"fixed_recipes": ["uramaki_california", "nigiri_pulpo", "te_verde", "dorayaki"],
	},
	{
		"id": "m2_10",
		"sea": 2,
		"chef_rec": 28,
		"name": "Puerto de la Caracola",
		"desc": "Dicen que en la caracola grande se oye el canto aunque no suene.",
		"client_mix": { "E": 8, "A": 4, "G": 2 },
		"arrival_span": 140.0,
		"patience_mult": 0.88,
		"sirena": true,
		"director": "mar2_despertar",
		"goal_stars": 2,
		"star_money": [64, 112, 178],
		# EL PLATO COMPARTIDO SE GUARDA PARA EL MAR 3 (decidido por el
		# usuario): el mar 2 ya estrena las CORONAS y el picoteo extra, y tres
		# mecánicas nuevas en el mismo mar no se aprenden. Aquí entra en su
		# hueco la corona de la caballa, cuya base se gana en m2_04.
		"reward_upgrade_3": "nigiri_caballa",
	},
	{
		"id": "m2_11",
		"sea": 2,
		"chef_rec": 29,
		"name": "Dársena del Trino",
		"desc": "Con ese trino en el aire, tres recetas son un tesoro.",
		"client_mix": { "E": 7, "A": 5, "G": 2 },
		"arrival_span": 140.0,
		"patience_mult": 0.85,
		"recipe_slots": 3,
		"sirena": true,
		"goal_stars": 2,
		"star_money": [66, 115, 182],
		"reward_recipes_3": ["gyozas"],
	},
	{
		"id": "m2_12",
		"sea": 2,
		"chef_rec": 29,
		"name": "Rumbo de la Serenata",
		"desc": "Abordar con música de fondo es de locos. Cocinar, más todavía.",
		"client_mix": { "E": 5, "A": 4, "G": 1 },
		"arrival_span": 130.0,
		"patience_mult": 0.88,
		"sirena": true,
		"goal_stars": 2,
		"star_money": [64, 112, 178],
		"reward_recipes_3": ["nigiri_pargo"],
	},
	{
		"id": "m2_13",
		"sea": 2,
		"chef_rec": 30,
		"name": "Flota del Silencio",
		"desc": "Cuando el canto calla de golpe, es que viene algo peor.",
		"client_mix": { "E": 4, "A": 4, "G": 2 },
		"arrival_span": 120.0,
		"patience_mult": 0.88,
		"time_limit": 135.0,
		"late_type": "G",
		"sirena": true,
		"goal_stars": 2,
		"star_money": [62, 110, 175],
		"reward_recipes_3": ["barbo_ahumado"],
	},
	{
		"id": "m2_14",
		"sea": 2,
		"chef_rec": 30,
		"name": "Jardín de Miku",
		"desc": "Una isla en calma perfecta. Alguien cuida este jardín.",
		"client_mix": { "E": 5, "A": 3, "G": 2 },
		"arrival_span": 130.0,
		"patience_mult": 0.92,
		"goal_stars": 2,
		"star_money": [64, 112, 178],
		"fixed_recipes": ["futomaki_salmon", "nigiri_inari", "edamame", "mochi"],
		# MIKU aparece en mitad del nivel y pide un BARCO DE SUSHI. La primera
		# vez NO se puede montar (su bonificador llega en m2_18): toca volver
		# con el puesto — el guion corre en cada visita hasta que el trato se
		# cierra (ver el filtro de level3d) y servirselo ensena el SUSHI RUSH.
		"boat": true,
		"special_client": { "who": "miku", "type": "G" },
		"late_type": "G",
		"director": "mar2_miku",
		"reward_ingots_3": 1,
	},
	{
		"id": "m2_15",
		"sea": 2,
		"chef_rec": 31,
		"name": "Puerto Farolillo",
		"desc": "De noche los farolillos aguantan el canto mejor que los clientes.",
		"client_mix": { "E": 8, "A": 5, "G": 2 },
		"arrival_span": 145.0,
		"patience_mult": 0.85,
		"arrival_batch": 2,
		"sirena": true,
		"goal_stars": 2,
		"star_money": [68, 118, 188],
		"reward_upgrade_3": "bol_arroz",
	},
	{
		"id": "m2_16",
		"sea": 2,
		"chef_rec": 31,
		"name": "Presa del Compás",
		"desc": "El canto marca el compás... y los bocados lo siguen.",
		"client_mix": { "E": 5, "A": 4, "G": 1 },
		"arrival_span": 125.0,
		"patience_mult": 0.88,
		"bite_speed": 1.15,
		"sirena": true,
		"goal_stars": 2,
		"star_money": [68, 118, 188],
		"reward_upgrade_3": "nigiri_pulpo",
	},
	{
		"id": "m2_17",
		"sea": 2,
		"chef_rec": 32,
		"name": "Muelle del Estribillo",
		"desc": "El estribillo se pega. A los clientes, demasiado.",
		"client_mix": { "E": 8, "A": 5, "G": 3 },
		"arrival_span": 145.0,
		"patience_mult": 0.85,
		"recipe_slots": 3,
		"sirena": true,
		"goal_stars": 2,
		"star_money": [70, 122, 195],
		"reward_upgrade_3": "onigiri",
	},
	{
		"id": "m2_18",
		"sea": 2,
		"chef_rec": 32,
		"name": "Fondeadero de Nach",
		"desc": "El capitán Nach solo fondea donde se come de verdad.",
		"client_mix": { "E": 7, "A": 5, "G": 3 },
		"arrival_span": 145.0,
		"patience_mult": 0.85,
		"sirena": true,
		# NACH llega de cliente, reconoce a Alice y ensena el BARCO COMBINADO:
		# pide que se lo sirvan a EL (guionizado). Superar el puerto abre su
		# bonificador (la compuerta que el barco esperaba desde el mar 1).
		"boat": true,
		"boat_lesson": true,
		"special_client": { "who": "nach", "type": "G" },
		"late_type": "G",
		"unlocks_perk": "barco",
		"director": "mar2_nach",
		"goal_stars": 2,
		"star_money": [70, 122, 195],
		"reward_ingots_3": 2,
	},
	{
		"id": "m2_19",
		"sea": 2,
		"chef_rec": 33,
		"name": "Isla del Tarareo",
		"desc": "Los niños tararean una canción que nadie les enseñó.",
		"client_mix": { "E": 6, "A": 4, "G": 2 },
		"arrival_span": 130.0,
		"patience_mult": 0.88,
		"sirena": true,
		"goal_stars": 2,
		"star_money": [68, 120, 190],
		"reward_recipes_3": ["tataki_atun_rojo"],
		"fixed_recipes": ["salmon_tsuke_don", "maki_atun", "sunomono", "taiyaki"],
	},
	{
		"id": "m2_20",
		"sea": 2,
		"chef_rec": 33,
		"name": "Cala de los Cascabeles",
		"desc": "Cascabeles en cada ventana, para taparse el canto con ruido.",
		"client_mix": { "E": 5, "A": 5, "G": 2 },
		"arrival_span": 125.0,
		"patience_mult": 0.85,
		"bite_speed": 1.2,
		"sirena": true,
		"goal_stars": 2,
		"star_money": [70, 122, 195],
		"reward_upgrade_3": "maki_pepino",
		# OJO: aqui estuvo "gari", una receta que NO EXISTE en RecipeData (se
		# cayo en el calibrado): su hueco de picoteo es del edamame.
		"fixed_recipes": ["fugu", "nigiri_anguila", "edamame", "mochi"],
		"alt_recipes": ["sashimi_variado", "udon"],
	},
	{
		"id": "m2_21",
		"sea": 2,
		"chef_rec": 34,
		"name": "Caza de la Romanza",
		"desc": "Un mercante rápido y un turno más rápido todavía.",
		"client_mix": { "E": 5, "A": 4, "G": 2 },
		"arrival_span": 100.0,
		"patience_mult": 0.85,
		"time_limit": 120.0,
		"sirena": true,
		"goal_stars": 2,
		"star_money": [58, 100, 160],
		"reward_upgrade_3": "nigiri_atun",
		# (la corona de la caballa se mudó a m2_10 al aparcar el compartido)
	},
	{
		"id": "m2_22",
		"sea": 2,
		"chef_rec": 34,
		"name": "Puerto de las Cien Banderas",
		"desc": "Cada bandera es un cliente exigente. Y hay cien.",
		"client_mix": { "E": 9, "A": 5, "G": 3 },
		"arrival_span": 150.0,
		"patience_mult": 0.82,
		"arrival_batch": 2,
		"sirena": true,
		"goal_stars": 2,
		"star_money": [74, 128, 205],
		"reward_upgrade_3": "caldo_dashi",
	},
	{
		"id": "m2_23",
		"sea": 2,
		"chef_rec": 35,
		"name": "Salmodia del Sur",
		"desc": "La salmodia llega sin avisar. Como los capitanes.",
		"client_mix": { "E": 4, "A": 5, "G": 2 },
		"arrival_span": 120.0,
		"patience_mult": 0.85,
		"late_type": "G",
		"sirena": true,
		"goal_stars": 2,
		"star_money": [72, 125, 200],
		"reward_recipes_3": ["toro_aleta"],
	},
	{
		"id": "m2_24",
		"sea": 2,
		"chef_rec": 35,
		"name": "Bahía del Ojo Quieto",
		"desc": "El ojo de la tormenta: la calma que precede a la sirena.",
		"client_mix": { "E": 9, "A": 6, "G": 4 },
		"arrival_span": 155.0,
		"patience_mult": 0.82,
		"recipe_slots": 3,
		"goal_stars": 2,
		"star_money": [78, 136, 218],
		"reward_upgrade_3": "fugu",
	},
	{
		"id": "m2_25",
		"sea": 2,
		"chef_rec": 36,
		"name": "Fosa de la Sirena",
		"desc": "Un canto sale de la fosa. Nadie que lo oyó cocinó dos veces.",
		"client_mix": { "E": 3, "A": 2, "G": 1 },
		"arrival_span": 90.0,
		"patience_mult": 0.88,
		"goal_stars": 2,
		# JEFE DEL MAR 2: LA SIRENA — su duelo convierte el CANTO en arma
		# (tres fases en level_director._mar2_sirena_jefa). El nivel NO lleva
		# "sirena": los cantos del duelo los dirige ella, no el planificador.
		"star_money": [55, 95, 150],
		"boss": "sirena",
		"director": "mar2_sirena_jefa",
		"reward_ingots_3": 3,
	},
]


# --- Mapa marítimo (pantalla de selección de nivel) -------------------------
#
# El selector es un mar por el que navega el barco del jugador entre nodos.
# Cada nivel es de un TIPO: "isla", "puerto" o "abordaje" (asaltar otro barco).
# De momento el tipo es solo identidad visual; más adelante cada tipo dará una
# característica única al nivel (añadir tipos nuevos = ampliar estos diccionarios).

const KINDS: Dictionary = {
	"nivel_1": "isla",
	"nivel_2": "isla",
	"nivel_3": "isla",
	"nivel_4": "puerto",
	"nivel_5": "isla",
	"nivel_6": "puerto",
	"nivel_7": "abordaje",
	"nivel_8": "isla",
	"nivel_9": "puerto",
	"nivel_10": "abordaje",
	"nivel_11": "isla",
	"nivel_12": "puerto",
	# ALICE llega en un ABORDAJE (decidido por el usuario): su escenario es el
	# único abordaje de la recta final antes de las bandejas y la cueva.
	"nivel_13": "abordaje",
	"nivel_14": "puerto",
	# El JEFE vive en una CUEVA: el tipo nuevo reservado a los jefes. Juega
	# como un abordaje (reloj y clientela sin fin hasta que entra el jefe) pero
	# con su propio escenario y SIN el hándicap del reloj: aquí el reto es él.
	"nivel_15": "cueva",
	# LOS ESCENARIOS DE PRÁCTICA no tienen por qué repetir el tipo de su
	# lección (decidido por el usuario): el reparto del mar manda. Con esto el
	# mar 1 queda en 9 islas, 6 puertos, 4 abordajes y 1 cueva.
	"practica_1": "isla",
	"practica_2": "isla",
	"practica_3": "isla",
	"practica_4": "abordaje",
	"vispera_kappa": "puerto",
	# LOS QUE AMPLIARON EL MAR 1, primero a 25 y luego a 30. Sin estas líneas
	# `get_kind` caía a su valor por defecto ("isla") y NADIE avisaba: el Paso
	# de los Cangrejos se jugaba SIN RELOJ pese a ser un abordaje, y dos
	# puertos salían con arenal y palmeras. Un escenario sin tipo declarado ya
	# no pasa la auditoría.
	"nivel_16": "isla",
	"nivel_17": "puerto",
	"nivel_18": "puerto",
	"nivel_19": "abordaje",
	"nivel_20": "puerto",
	# LOS TRES DE LOS EXTRAS van seguidos y los tres de PUERTO: el extra se
	# echa sobre un plato ya hecho, y para eso hace falta poder elegir la carta
	# —una isla la trae cerrada—. El primero es `nivel_6`, que ya existía.
	"nivel_21": "puerto",
	"nivel_22": "puerto",
	# Las tres prácticas nuevas repiten el tipo de la lección que practican.
	"practica_8": "isla",
	"practica_9": "puerto",
	"practica_10": "puerto",
	"practica_11": "puerto",
	"practica_12": "isla",
	"practica_5": "isla",
	"practica_6": "puerto",
	"practica_7": "isla",
	# --- MAR 2 (9 islas, 9 puertos, 6 abordajes y la cueva de la sirena) ---
	"m2_01": "isla",
	"m2_02": "isla",
	"m2_03": "puerto",
	"m2_04": "puerto",
	"m2_05": "isla",
	"m2_06": "abordaje",
	"m2_07": "abordaje",
	"m2_08": "isla",
	"m2_09": "isla",
	"m2_10": "puerto",
	"m2_11": "puerto",
	"m2_12": "abordaje",
	"m2_13": "abordaje",
	"m2_14": "isla",
	"m2_15": "puerto",
	"m2_16": "abordaje",
	"m2_17": "puerto",
	"m2_18": "puerto",
	"m2_19": "isla",
	"m2_20": "isla",
	"m2_21": "abordaje",
	"m2_22": "puerto",
	"m2_23": "abordaje",
	"m2_24": "puerto",
	"m2_25": "cueva",
}

const KIND_NAMES: Dictionary = {
	"isla": "Isla",
	"puerto": "Puerto",
	"abordaje": "Abordaje",
	"cueva": "Cueva",
}

const KIND_TEXTURES: Dictionary = {
	"isla": "res://assets/map/isla.png",
	"puerto": "res://assets/map/puerto.png",
	"abordaje": "res://assets/map/barco_enemigo.png",
	# Solo lo usa el mapa 2D de referencia (level_select.gd, fuera de uso).
	"cueva": "res://assets/map/isla.png",
}

## Alto del lienzo del mapa (el ancho es el de la pantalla).
##
## La travesía va de ABAJO ARRIBA: el nivel 1 es el más bajo y el último el más
## alto, así que el barco avanza hacia el norte a medida que progresas. Los
## nodos alternan entre TRES carriles (izquierda, centro y derecha) para que la
## ruta serpentee y no caiga siempre en el mismo lado.
## AL PASAR DE 9 A 10 NIVELES el lienzo creció un MAP_STEP (2180 → 2395) y toda
## la ruta se corrió +215 hacia abajo, con el nivel 10 estrenando lo alto; el
## fondeadero del menú (`main_menu.MENU_ANCHOR`) bajó otro tanto, o el nivel 1
## asomaba por arriba estando en el menú.
const MAP_HEIGHT := 3430

const LANE_LEFT := 175.0
const LANE_CENTER := 360.0
const LANE_RIGHT := 545.0

## Separación vertical entre puertos, IGUAL para todos. La medida no es a ojo:
## `level_select3d._setup_route` dibuja un guión cada 0.44 unidades de mundo, y
## el tramo más corto (un salto de carril, 185 px en horizontal) tiene que dar
## al menos 8. Con 215 px salen 10 en el corto y 13 en el largo.
## Si se cambia este paso hay que bajar `main_menu.MENU_ANCHOR` otro tanto, o el
## nivel 1 asoma por arriba estando en el menú.
const MAP_STEP := 215.0

## EL CARRIL SALE DE LA POSICIÓN, NO DEL ID: ciclo [CENTRO, IZQUIERDA,
## DERECHA] contado desde el escenario 1, y la altura es 3220 − 312·(pos−1).
## Al reordenar la campaña hay que rehacer las DOS cosas de arriba abajo — con
## los cinco escenarios que ampliaron el mar 1 se metieron a ojo y el ciclo se
## quedó desfasado un carril de la posición 19 en adelante, que es como la
## travesía deja de serpentear y se pone a zigzaguear en corto.
const MAP_POS: Dictionary = {
	"nivel_1": Vector2(LANE_CENTER, 3220.0),
	"practica_1": Vector2(LANE_LEFT, 2908.0),
	"nivel_2": Vector2(LANE_RIGHT, 2596.0),
	"practica_5": Vector2(LANE_CENTER, 2284.0),
	"nivel_3": Vector2(LANE_LEFT, 1972.0),
	"practica_2": Vector2(LANE_RIGHT, 1660.0),
	"practica_8": Vector2(LANE_CENTER, 1348.0),
	"nivel_4": Vector2(LANE_LEFT, 1036.0),
	"practica_6": Vector2(LANE_RIGHT, 724.0),
	"nivel_5": Vector2(LANE_CENTER, 412.0),
	"practica_3": Vector2(LANE_LEFT, 100.0),
	"nivel_16": Vector2(LANE_RIGHT, -212.0),
	"practica_7": Vector2(LANE_CENTER, -524.0),
	"nivel_7": Vector2(LANE_LEFT, -836.0),
	"practica_4": Vector2(LANE_RIGHT, -1148.0),
	"practica_9": Vector2(LANE_CENTER, -1460.0),
	"nivel_6": Vector2(LANE_LEFT, -1772.0),
	"nivel_21": Vector2(LANE_RIGHT, -2084.0),
	"nivel_22": Vector2(LANE_CENTER, -2396.0),
	"practica_10": Vector2(LANE_LEFT, -2708.0),
	"nivel_8": Vector2(LANE_RIGHT, -3020.0),
	"nivel_9": Vector2(LANE_CENTER, -3332.0),
	"nivel_10": Vector2(LANE_LEFT, -3644.0),
	"nivel_19": Vector2(LANE_RIGHT, -3956.0),
	"practica_11": Vector2(LANE_CENTER, -4268.0),
	"nivel_11": Vector2(LANE_LEFT, -4580.0),
	"nivel_12": Vector2(LANE_RIGHT, -4892.0),
	"nivel_17": Vector2(LANE_CENTER, -5204.0),
	"nivel_18": Vector2(LANE_LEFT, -5516.0),
	"practica_12": Vector2(LANE_RIGHT, -5828.0),
	"nivel_13": Vector2(LANE_CENTER, -6140.0),
	"nivel_20": Vector2(LANE_LEFT, -6452.0),
	"nivel_14": Vector2(LANE_RIGHT, -6764.0),
	"vispera_kappa": Vector2(LANE_CENTER, -7076.0),
	# LA CUEVA DEL KAPPA va CENTRADA y con su respiro: la guarida del jefe
	# no comparte carril con nadie.
	"nivel_15": Vector2(LANE_CENTER, -8230.0),
	# --- MAR 2: sigue hacia el norte, con un salto de mar (1000 px) entre la
	# cueva y su primera cala. PASO 368: cada mar gano +100 px de paso
	# (pedido por el usuario) porque con los CARTELES puestos la travesia
	# se veia mas apretada de lo que estaba. El jefe (m2_25) lleva su
	# respiro extra.
	"m2_01": Vector2(LANE_CENTER, -8890.0),
	"m2_02": Vector2(LANE_LEFT, -9258.0),
	"m2_03": Vector2(LANE_CENTER, -9626.0),
	"m2_04": Vector2(LANE_RIGHT, -9994.0),
	"m2_05": Vector2(LANE_CENTER, -10362.0),
	"m2_06": Vector2(LANE_LEFT, -10730.0),
	"m2_07": Vector2(LANE_CENTER, -11098.0),
	"m2_08": Vector2(LANE_RIGHT, -11466.0),
	"m2_09": Vector2(LANE_CENTER, -11834.0),
	"m2_10": Vector2(LANE_LEFT, -12202.0),
	"m2_11": Vector2(LANE_CENTER, -12570.0),
	"m2_12": Vector2(LANE_RIGHT, -12938.0),
	"m2_13": Vector2(LANE_CENTER, -13306.0),
	"m2_14": Vector2(LANE_LEFT, -13674.0),
	"m2_15": Vector2(LANE_CENTER, -14042.0),
	"m2_16": Vector2(LANE_RIGHT, -14410.0),
	"m2_17": Vector2(LANE_CENTER, -14778.0),
	"m2_18": Vector2(LANE_LEFT, -15146.0),
	"m2_19": Vector2(LANE_CENTER, -15514.0),
	"m2_20": Vector2(LANE_RIGHT, -15882.0),
	"m2_21": Vector2(LANE_CENTER, -16250.0),
	"m2_22": Vector2(LANE_LEFT, -16618.0),
	"m2_23": Vector2(LANE_CENTER, -16986.0),
	"m2_24": Vector2(LANE_RIGHT, -17354.0),
	"m2_25": Vector2(LANE_CENTER, -17922.0),
}


## Tipo de nivel ("isla", "puerto", "abordaje").
static func get_kind(id: String) -> String:
	return KINDS.get(id, "isla")


## ¿Este nivel se juega CONTRA RELOJ? Solo los abordajes: las islas y los
## puertos los acota la clientela, no el tiempo.
static func is_timed(id: String) -> bool:
	# La CUEVA (los jefes) juega contra reloj como un abordaje: el guion del
	# jefe necesita el reloj corriendo hasta que él entra y lo para.
	return get_kind(id) in ["abordaje", "cueva"]


## Segundos de partida (0 = sin reloj: manda la clientela). Un puerto puede
## acortar el suyo con `time_limit` (los abordajes exprés del mar 2).
static func time_limit_for(id: String) -> float:
	if not is_timed(id):
		return 0.0
	return float(get_port(id).get("time_limit", SHIP_TIME))


## ¿Entran clientes sin tope? Los abordajes no tienen cupo: mientras quede
## reloj, sigue llegando gente.
static func unlimited_clients(id: String) -> bool:
	return is_timed(id)


## Nombre legible del tipo de nivel.
static func kind_name(id: String) -> String:
	return KIND_NAMES.get(get_kind(id), "Isla")


## Textura del nodo en el mapa según el tipo.
static func kind_texture(id: String) -> String:
	return KIND_TEXTURES.get(get_kind(id), KIND_TEXTURES["isla"])


## Posición del nivel en el lienzo del mapa.
static func map_pos(id: String) -> Vector2:
	return MAP_POS.get(id, Vector2.ZERO)


## EL PUERTO QUE ESTRENA UN TIPO DE CLIENTE ("A" piratas, "G" capitanes): el
## primero de la campaña cuya mezcla lo trae. Se calcula de los datos y no se
## escribe a mano, así que mover un nivel de sitio no lo deja mintiendo.
##
## Lo mira el aviso de Gigi del selector de recetas: en el nivel que ESTRENA un
## tipo, regañar al jugador por no llevar platos de esas estrellas no tiene
## sentido — evidentemente no los lleva, si es la primera vez que los ve, y es
## David quien le regala la receta dentro del propio nivel.
static func first_port_with(tipo: String) -> String:
	for p in PORTS:
		var mix: Dictionary = p.get("client_mix", {})
		if int(mix.get(tipo, 0)) > 0:
			return str(p.get("id", ""))
	return ""


## Devuelve el diccionario del nivel con ese id, o {} si no existe.
static func get_port(id: String) -> Dictionary:
	for p in PORTS:
		if p.id == id:
			return p
	return {}


## Índice del nivel en la ruta, o -1.
static func port_index(id: String) -> int:
	for i in PORTS.size():
		if PORTS[i].id == id:
			return i
	return -1


## Id del nivel anterior en la ruta ("" si es el primero o no existe).
static func prev_port_id(id: String) -> String:
	var i := port_index(id)
	if i <= 0:
		return ""
	return PORTS[i - 1].id


## Id del escenario SIGUIENTE a este ("" si es el ultimo). Se usa al cerrar un
## turno para dejar el mapa mirando al que viene, aunque ya este superado.
static func next_port_id(id: String) -> String:
	var i := port_index(id)
	if i < 0 or i >= PORTS.size() - 1:
		return ""
	return PORTS[i + 1].id


## Id del primer nivel de la ruta ("" si no hay niveles).
static func first_port_id() -> String:
	if PORTS.is_empty():
		return ""
	return PORTS[0].id


## Recetas que se pueden LLEVAR a este puerto.
##
## Si el puerto trae `fixed_recipes`, esa es la carta y punto (las islas con
## menú cerrado). Si no, valen las iniciales más las recompensas de los puertos
## ANTERIORES: aunque el jugador tenga media carta desbloqueada por haber
## avanzado, un puerto temprano no debe ofrecer recetas de más adelante.
##
## `superado` (el puerto ya está pasado y se está REPITIENDO) solo cambia la
## carta de las ISLAS, que pueden traer una lista distinta para la repetición
## (`fixed_recipes_replay`): en el nivel 1 se vuelve con el nigiri que regaló
## David la primera vez.
## Carta CERRADA de un puerto ([] si es de libre elección). Las ISLAS se juegan
## siempre con las recetas que manda el nivel, también al repetirlo; lo único
## que cambia es que pueden traer una lista propia para la repetición
## (`fixed_recipes_replay`), con lo que David regaló la primera vez.
static func fixed_recipes_for(port_id: String, superado := false) -> Array[String]:
	var port := get_port(port_id)
	var fijas: Array = port.get("fixed_recipes", [])
	if superado and not port.get("fixed_recipes_replay", []).is_empty():
		fijas = port.get("fixed_recipes_replay", [])
	var out: Array[String] = []
	for r in fijas:
		out.append(str(r))
	if out.is_empty():
		return out
	# EXTRAS DE LA CARTA CERRADA, que dependen de lo que el jugador se haya
	# ganado: `optional_recipes` entra entera si está desbloqueada, y de
	# `alt_recipes` entra SOLO LA PRIMERA que lo esté (lista por preferencia).
	# Así una isla mantiene el tamaño de carta que se diseñó tanto si el jugador
	# sacó las 3 estrellas del nivel anterior como si no.
	for r in port.get("optional_recipes", []):
		if GameState.is_recipe_unlocked(str(r)) and not str(r) in out:
			out.append(str(r))
	for r in port.get("alt_recipes", []):
		if GameState.is_recipe_unlocked(str(r)):
			if not str(r) in out:
				out.append(str(r))
			break
	return out


static func recipes_for_port(port_id: String, superado := false) -> Array[String]:
	var out: Array[String] = []
	var fijas := fixed_recipes_for(port_id, superado)
	if not fijas.is_empty():
		return fijas
	for r in INITIAL_RECIPES:
		out.append(str(r))
	var idx := port_index(port_id)
	for i in PORTS.size():
		if idx >= 0 and i > idx:
			break
		# Las recompensas solo cuentan de los puertos ANTERIORES.
		if idx < 0 or i < idx:
			for r in PORTS[i].get("reward_recipes", []):
				if not str(r) in out:
					out.append(str(r))
			for r in PORTS[i].get("reward_recipes_3", []):
				if not str(r) in out:
					out.append(str(r))
		# Las recetas que REGALA David en plena partida (`gift_recipes`) no
		# están en ninguna recompensa, así que sin esto se quedaban fuera de la
		# carta para siempre: el nigiri de atún del nivel 3 no salía luego en
		# los siguientes. La del puerto EN CURSO también entra, para cuando se
		# repite un nivel ya jugado (la primera vez no está desbloqueada y el
		# selector la descarta solo).
		for r in PORTS[i].get("gift_recipes", []):
			if not str(r) in out:
				out.append(str(r))
	return out
