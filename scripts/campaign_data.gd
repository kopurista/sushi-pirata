class_name CampaignData
## Datos estáticos de la campaña (modo Aventura): lista ORDENADA de niveles.
##
## LA CAMPAÑA COMPLETA SON 250 ESCENARIOS en 7 mares, con un JEFE cada 10 y su
## escenario pagando el DOBLE de experiencia (`SkillData.XP_BOSS_MULT`). Aquí
## están escritos los **20 del PRIMER MAR**, que se cierra con el Kappa.
##
## EL ORDEN LO DA LA POSICIÓN EN `PORTS`, NO EL ID. Los ids (`nivel_7`,
## `practica_2`...) son NOMBRES, no números de escenario: los guiones, los
## avisos previos del selector y las compuertas los referencian por ese nombre,
## y renumerarlos rompería las partidas guardadas y obligaría a tocar decenas
## de sitios. Lo que el jugador ve como "Escenario 12" es `port_index + 1`. Por
## eso el Kappa sigue llamándose `nivel_15` aunque sea el escenario 20.
##
## ENSEÑAR, ENSEÑAR, PRACTICAR. Tras cada PAREJA de escenarios que presentan
## una mecánica va uno de PRÁCTICA, sin guion y sin nada nuevo: una jornada
## limpia para asentar lo aprendido antes de que llegue lo siguiente. El
## reparto del primer mar (entre paréntesis, el id):
##    1 paciencia, bocado y oro — jornada normal          (nivel_1)
##    2 las CAJAS de guardado; la despensa empieza a gastarse (nivel_2)
##    3 PRÁCTICA                                          (practica_1)
##    4 el PICOTEO: regalo del edamame                    (nivel_3)
##    5 MULTIPLICADOR, hastío y paladar; abre la TIENDA    (nivel_4)
##    6 PRÁCTICA — la primera con carta libre             (practica_2)
##    7 POSTRES, PROPINAS y potenciadores                 (nivel_5)
##    8 los EXTRAS (jengibre, wasabi, soja)               (nivel_6)
##    9 PRÁCTICA                                          (practica_3)
##   10 primer ABORDAJE y EL pirata de la bandera         (nivel_7)
##   11 CAI y la PESCA                                    (nivel_8)
##   12 PRÁCTICA — el primer abordaje sin guion           (practica_4)
##   13 el examen mudo                                    (nivel_9)
##   14 Pablo el Rubio y el corte lento                   (nivel_10)
##   15-18 el resto de mecánicas                          (nivel_11..14)
##   19 la víspera: sin lecciones, a pulso                (vispera_kappa)
##   20 JEFE: el Kappa                                    (nivel_15)
##
## Recorrido MEDIDO con la curva de experiencia vigente, bordándolo todo: se
## llega al escenario 20 con el cocinero en el nivel 15 y se sale del mar en el
## 16. Los `chef_rec` de cada puerto son exactamente esa cuenta.
##
## LOS PRIMEROS ESCENARIOS SON TODOS DE GRUMETES a propósito: se aprende a
## cocinar antes de aprender a leer paladares. Piratas y capitanes entran en el
## primer abordaje.
##
## Los BONIFICADORES permanentes (PerkData) no se reparten hasta el escenario
## 12 (`no_perks` en todos los anteriores); los POTENCIADORES de partida y las
## propinas se estrenan en el 7, con los postres.
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

const PORTS: Array = [
	{
		"id": "nivel_1",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
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
		"id": "nivel_2",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 1,
		"name": "Playa del Coco",
		"desc": "Se junta la clientela: hoy aprendes a guardar platos en las cajas.",
		"client_mix": { "E": 4 },
		"arrival_span": 120.0,
		"patience_mult": 1.1,
		"arrival_scale": 0.9,
		"goal_stars": 2,
		"star_money": [14, 26, 40],
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
		"id": "practica_1",
		"chef_rec": 1,
		"name": "Ensenada del Mero",
		"desc": "Sin lecciones: solo tu cocina, cuatro grumetes y las cajas.",
		"client_mix": { "E": 5 },
		"arrival_span": 120.0,
		"patience_mult": 1.05,
		"arrival_scale": 0.9,
		"goal_stars": 2,
		"star_money": [16, 29, 46],
		"reward_recipes": [],
		"reward_recipes_3": [],
		"reward_rice_3": 1,
		# Carta cerrada con lo aprendido en el 1 y el 2. El maki de pepino entra
		# si se ganaron las 3 estrellas del 2; si no, el gunkan.
		"fixed_recipes": ["maki_aguacate", "nigiri_salmon"],
		"alt_recipes": ["maki_pepino", "gunkan_wakame"],
		"no_powerups": true,
		"no_extras": true,
		"no_variety_ui": true,
		"no_perks": true,
		"near_seats": true,
	},
	{
		"id": "nivel_3",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 2,
		"name": "Isla del Bambú",
		"desc": "Cinco grumetes hambrientos y un plato que se come sin soltar el otro.",
		"client_mix": { "E": 5 },
		"arrival_span": 120.0,
		"patience_mult": 1.05,
		"arrival_scale": 0.85,
		"goal_stars": 2,
		"star_money": [18, 32, 50],
		"reward_recipes": [],
		"reward_recipes_3": ["sunomono"],
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
		"id": "nivel_4",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 3,
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
		"star_money": [26, 46, 72],
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
		"id": "practica_2",
		"chef_rec": 4,
		"name": "Caleta del Farol",
		"desc": "Tu primera jornada libre con la carta en tus manos.",
		"client_mix": { "E": 8 },
		"arrival_span": 130.0,
		"patience_mult": 1.0,
		"arrival_scale": 0.85,
		"goal_stars": 2,
		"star_money": [28, 50, 78],
		"reward_recipes": [],
		"reward_recipes_3": [],
		"reward_rice_3": 1,
		"arrival_batch": 2,
		"no_perks": true,
		"near_seats": true,
	},
	{
		"id": "nivel_5",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 4,
		"name": "Cala del Calamar",
		"desc": "El postre es la cuenta: aprende a despedir clientes y a llenar el bote.",
		"client_mix": { "E": 5 },
		"arrival_span": 120.0,
		"patience_mult": 1.0,
		"arrival_scale": 0.85,
		"goal_stars": 2,
		"star_money": [20, 38, 58],
		"reward_recipes": [],
		"reward_recipes_3": ["caldo_dashi"],
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
		"id": "nivel_6",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 5,
		"name": "Bahía del Kraken",
		"desc": "Saverio saca los extras: jengibre, wasabi y soja sobre el plato hecho.",
		"client_mix": { "E": 8 },
		# Con solo DOS tandas la ventana se reparte entre ellas, así que un
		# `arrival_span` largo dejaba un desierto en medio: con 90, las dos
		# oleadas caen a los 5 y a los 54 s.
		"arrival_span": 90.0,
		"patience_mult": 0.95,
		"arrival_scale": 0.8,
		# Dos tandas de cuatro: la barra se llena de golpe dos veces.
		"arrival_batch": 4,
		"goal_stars": 2,
		"star_money": [28, 52, 82],
		"reward_recipes": [],
		"reward_recipes_3": ["sopa_miso"],
		"director": "nivel_6",
		"no_perks": true,
	},
	{
		"id": "practica_3",
		"chef_rec": 6,
		"name": "Rada del Pulpo",
		"desc": "Postres, propinas y extras: todo junto y sin ayuda.",
		"client_mix": { "E": 9 },
		"arrival_span": 135.0,
		"patience_mult": 0.98,
		"arrival_scale": 0.85,
		"goal_stars": 2,
		"star_money": [34, 60, 95],
		"reward_recipes": [],
		"reward_recipes_3": [],
		"reward_rice_3": 2,
		"arrival_batch": 2,
		"no_perks": true,
	},
	{
		"id": "nivel_7",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 7,
		"name": "Estrecho del Rayo",
		"desc": "¡Abordaje! Reloj, clientela sin fin y los primeros piratas.",
		# Abordaje: esta mezcla es solo la PRIMERA tanda.
		# UN SOLO PIRATA EN TODO EL NIVEL. Es EL pirata de la bandera: el
		# coleccionable se gana dándole de comer a ÉL, así que si subieran más
		# por la borda no habría forma de saber a cuál se le está sirviendo.
		# Por eso los pesos de las llegadas sin fin son solo de grumete: en un
		# abordaje, agotada la primera tanda, el sorteo sigue con las
		# proporciones de la mezcla si el puerto no trae pesos propios.
		"client_mix": { "E": 5, "A": 1 },
		"client_weights": { "E": 1 },
		# EL PIRATA ES EL TERCERO EN ENTRAR, y a propósito: tiene que llegar
		# pronto para que dé tiempo a estrenar el nigiri de atún con él y a
		# darle sus platos, pero después de un par de grumetes para que la
		# novedad se note.
		"client_order": ["E", "E", "A", "E", "E", "E"],
		"arrival_span": 100.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.8,
		"goal_stars": 2,
		"star_money": [32, 55, 88],
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
		"id": "nivel_8",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 8,
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
		"star_money": [26, 46, 72],
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
		"id": "practica_4",
		"chef_rec": 8,
		"name": "Paso de las Barracudas",
		"desc": "Un abordaje corriente, sin nadie a quien impresionar.",
		"client_mix": { "E": 5, "A": 2 },
		"client_weights": { "E": 3, "A": 2 },
		"arrival_span": 105.0,
		"patience_mult": 0.92,
		"arrival_scale": 0.78,
		"goal_stars": 2,
		"star_money": [40, 70, 110],
		"reward_recipes": [],
		"reward_recipes_3": [],
		"reward_ingots_3": 1,
	},
	{
		"id": "nivel_9",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 9,
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
		"star_money": [40, 68, 105],
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
		"chef_rec": 10,
		"name": "Flota del capitán Pablo el Rubio",
		"desc": "Abordaje a la flota de un viejo conocido de David.",
		"client_mix": { "E": 2, "A": 2, "G": 1 },
		"arrival_span": 120.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.7,
		"goal_stars": 2,
		"star_money": [36, 62, 95],
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
		"id": "nivel_11",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 11,
		"name": "Cala del Hambre",
		"desc": "Tres bocas, una de ellas con un hambre que no es normal.",
		"client_mix": { "E": 1, "A": 1, "G": 1 },
		"client_order": ["E", "A", "G"],
		"arrival_span": 80.0,
		"patience_mult": 1.0,
		"arrival_scale": 0.9,
		"goal_stars": 2,
		"star_money": [24, 42, 64],
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
		"chef_rec": 12,
		"name": "Ensenada del Naufragio",
		"desc": "Corre la voz de que alguien paga en tesoros, no en oro.",
		"client_mix": { "E": 4, "A": 3, "G": 1 },
		"arrival_span": 130.0,
		"patience_mult": 0.9,
		"arrival_scale": 0.8,
		"goal_stars": 2,
		"star_money": [44, 74, 112],
		# CLIENTE CON TESORO: un capitán que, bien servido, paga con un
		# COLECCIONABLE en vez de con oro (ver `collectible_client`). Es la
		# lección del nivel y de aquí en adelante puede pasar en cualquiera.
		"collectible_client": {
			"who": "capitan", "type": "G", "item": "tricornio", "plates": 3,
		},
		"late_type": "G",
		"director": "nivel_12",
		"reward_recipes": [],
		"reward_recipes_3": ["gunkan_tartar"],
	},
	{
		"id": "nivel_13",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 12,
		"name": "Rada de los Dos Fuegos",
		"desc": "Demasiadas comandas para un solo par de manos.",
		"client_mix": { "E": 5, "A": 3, "G": 2 },
		"arrival_span": 120.0,
		"patience_mult": 0.85,
		"arrival_scale": 0.7,
		"goal_stars": 2,
		"star_money": [48, 82, 125],
		# EL AYUDANTE: aquí se presenta y desde aquí se puede ganar.
		"unlocks_perks": true,
		"unlocks_perk": "ayudante",
		"prep_dialog": "nivel_13",
		"director": "nivel_13",
		"reward_recipes": [],
		"reward_recipes_3": ["nigiri_pulpo"],
	},
	{
		"id": "nivel_14",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 13,
		"name": "Muelle de las Bandejas",
		"desc": "Aquí no se sirve plato a plato: se sirve por bandejas.",
		"client_mix": { "E": 5, "A": 4, "G": 2 },
		"arrival_span": 130.0,
		"patience_mult": 0.85,
		"arrival_scale": 0.7,
		"goal_stars": 2,
		"star_money": [52, 88, 135],
		# EL BARCO COMBINADO: el puerto lo permite y aquí se gana su bonificador.
		"boat": true,
		"unlocks_perk": "barco",
		"prep_dialog": "nivel_14",
		"director": "nivel_14",
		"reward_recipes": [],
		"reward_recipes_3": ["chirashi"],
	},
	{
		"id": "vispera_kappa",
		"chef_rec": 14,
		"name": "Bruma del Estrecho",
		"desc": "La última parada antes de la guarida. Aquí ya no se enseña nada.",
		"client_mix": { "E": 6, "A": 4, "G": 2 },
		"arrival_span": 140.0,
		"patience_mult": 0.88,
		"arrival_scale": 0.8,
		"goal_stars": 2,
		"star_money": [52, 92, 145],
		"reward_recipes": [],
		"reward_recipes_3": [],
		"reward_ingots_3": 2,
		"arrival_batch": 2,
	},
	{
		"id": "nivel_15",
		# Nivel de COCINERO recomendado: ceil(numero del escenario x 1.09). Lo
		# ensena la ficha del mapa, para distinguir "voy corto de nivel" de
		# "lo estoy jugando mal". La curva de XP esta calibrada contra el.
		"chef_rec": 15,
		"name": "Guarida del Kappa",
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
	"nivel_13": "puerto",
	"nivel_14": "puerto",
	"nivel_15": "abordaje",
	# LOS ESCENARIOS DE PRÁCTICA. Repiten el TIPO de la pareja que acaban de
	# enseñar, para que lo que se prueba sea la mecánica y no un escenario
	# distinto: isla tras las dos islas del principio, puerto tras el primer
	# puerto, y abordaje tras el primer abordaje.
	"practica_1": "isla",
	"practica_2": "puerto",
	"practica_3": "puerto",
	"practica_4": "abordaje",
	"vispera_kappa": "puerto",
}

const KIND_NAMES: Dictionary = {
	"isla": "Isla",
	"puerto": "Puerto",
	"abordaje": "Abordaje",
}

const KIND_TEXTURES: Dictionary = {
	"isla": "res://assets/map/isla.png",
	"puerto": "res://assets/map/puerto.png",
	"abordaje": "res://assets/map/barco_enemigo.png",
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

const MAP_POS: Dictionary = {
	"nivel_1": Vector2(LANE_CENTER, 3220.0),
	"nivel_2": Vector2(LANE_LEFT, 3061.6),
	"practica_1": Vector2(LANE_RIGHT, 2903.2),
	"nivel_3": Vector2(LANE_CENTER, 2744.7),
	"nivel_4": Vector2(LANE_LEFT, 2586.3),
	"practica_2": Vector2(LANE_RIGHT, 2427.9),
	"nivel_5": Vector2(LANE_CENTER, 2269.5),
	"nivel_6": Vector2(LANE_LEFT, 2111.1),
	"practica_3": Vector2(LANE_RIGHT, 1952.6),
	"nivel_7": Vector2(LANE_CENTER, 1794.2),
	"nivel_8": Vector2(LANE_LEFT, 1635.8),
	"practica_4": Vector2(LANE_RIGHT, 1477.4),
	"nivel_9": Vector2(LANE_CENTER, 1318.9),
	"nivel_10": Vector2(LANE_LEFT, 1160.5),
	"nivel_11": Vector2(LANE_RIGHT, 1002.1),
	"nivel_12": Vector2(LANE_CENTER, 843.7),
	"nivel_13": Vector2(LANE_LEFT, 685.3),
	"nivel_14": Vector2(LANE_RIGHT, 526.8),
	"vispera_kappa": Vector2(LANE_CENTER, 368.4),
	"nivel_15": Vector2(LANE_LEFT, 210.0),
}


## Tipo de nivel ("isla", "puerto", "abordaje").
static func get_kind(id: String) -> String:
	return KINDS.get(id, "isla")


## ¿Este nivel se juega CONTRA RELOJ? Solo los abordajes: las islas y los
## puertos los acota la clientela, no el tiempo.
static func is_timed(id: String) -> bool:
	return get_kind(id) == "abordaje"


## Segundos de partida (0 = sin reloj: manda la clientela).
static func time_limit_for(id: String) -> float:
	return SHIP_TIME if is_timed(id) else 0.0


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
