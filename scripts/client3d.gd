extends Node3D
## Cliente pirata en 3D (port de client.gd con la MISMA logica de juego).
## Entra andando desde la borda, rodea el mostrador por fuera, se sienta en su
## taburete, coge platos de la cinta, come y se marcha andando.
## Se queda hasta que su barra de PACIENCIA se agota (no hay saciedad objetivo):
## cada plato comido recarga paciencia segun su nivel, pero repetirle el mismo
## plato rinde cada vez menos. La propina depende del Nº de platos (TIP_RULES).
##
## Presentacion: modelo GLB riggeado + CharacterAnim (andar/sentarse/comer
## proceduralmente). Sin fisica: la deteccion de platos sondea el grupo
## "plates" comparando distancias con su punto de la cinta. Las barras de
## paciencia/comida y los textos flotantes son Controles 2D en level.world_ui,
## anclados proyectando la cabeza del cliente con la camara (que es fija).

signal finished(report: Dictionary)
## Se emite al terminar CADA plato: el precio del plato y la propina de ese
## plato (0 si no la deja). El nivel suma ambos al instante, no al marcharse.
signal plate_served(food: int, tip: int)
## El JEFE se ha quedado sin paciencia. Un jefe NO se marcha (el duelo lo
## gobierna el guion): se queda clavado a cero y avisa UNA vez; el guion cobra
## la calavera y le devuelve parte de la barra con boss_patience_*.
signal boss_starved

enum State { ARRIVING, WAITING, EATING, LEAVING, DONE }

## Radio (en el plano del suelo) alrededor del punto de cinta del cliente en el
## que un plato se considera "a su alcance". Los puntos de cinta de dos
## asientos vecinos distan 1.8 u, asi que 0.45 no se solapa nunca.
const TAKE_RADIUS := 0.45

## Altura (u) por tipo de cliente. En la misma proporcion que las escalas 2D
## (0.095 / 0.115 / 0.13 con el pirata en 1.75). El MODELO ya no vive aqui: lo
## resuelve CharacterData segun el tipo y el genero de este cliente.
const TYPE_HEIGHTS: Dictionary = { "E": 1.45, "A": 1.75, "G": 1.95 }

## Probabilidad de coger un plato segun tipo de cliente y nivel del plato.
const TAKE_CHANCES: Dictionary = {
	"E": { 1: 0.95, 2: 0.20, 3: 0.10 },
	"A": { 1: 0.45, 2: 0.95, 3: 0.25 },
	"G": { 1: 0.10, 2: 0.55, 3: 0.95 },
}

const FAVORITE_TIER: Dictionary = { "E": 1, "A": 2, "G": 3 }

## Segundos que tarda un cliente en comerse un plato, por TIPO y por NIVEL del
## plato. Son FIJOS (antes era un rango al azar): el juego es de gestión y el
## jugador tiene que poder contar cuándo se libera un asiento.
##
## Salen de una regla de dos piezas:
##  - El NIVEL pone la base (6 / 10 / 15 s). Comer NO gasta paciencia, así que
##    el bocado es lo único que sostiene una mesa de cuatro sitios: si todo se
##    comiera rápido, cuatro clientes pedirían más de lo que puede producir una
##    cocina con enfriamientos de 3 a 9 s.
##  - El TIPO aplica un factor: grumete x1.2 (come despacio y disfruta), pirata
##    x1.0 (la referencia) y capitán x0.8 (rápido y eficiente).
##
## El resultado es que los doblones POR SEGUNDO DE ASIENTO —que es el recurso
## de verdad escaso— suben limpio en las dos direcciones: 0.51 el grumete con
## un plato de 1 estrella y 1.04 el capitán con uno de 3, justo el doble.
const EAT_TIMES: Dictionary = {
	"E": { 1: 7.0, 2: 12.0, 3: 18.0 },
	"A": { 1: 6.0, 2: 10.0, 3: 15.0 },
	"G": { 1: 5.0, 2: 8.0, 3: 12.0 },
}
## Variación sobre el tiempo fijo. Con números clavados, dos clientes que
## empiezan el mismo plato a la vez terminan a la vez y la mesa se vacía a
## oleadas; un 5% rompe la sincronía sin que deje de ser predecible.
const EAT_JITTER := 0.05

## Castigo (doblones) si el cliente se marcha SIN haber probado NADA: cuanto
## mas importante es el cliente, mas cuesta desatenderlo. Se cobra tanto si se
## le agoto la paciencia como si le pillo el fin del TIEMPO; la unica excepcion
## es cerrar el turno por haber alcanzado el objetivo (ver force_leave).
const LEAVE_PENALTY: Dictionary = { "E": 5, "A": 8, "G": 12 }
## Multiplicador del castigo por vacío. En las islas del mar 2+ va DOBLADO:
## el hándicap de la isla tiene que doler tanto como los de los otros tipos.
var leave_penalty_mult := 1.0

## Al recibir un plato la paciencia sube (fraccion del maximo) segun el nivel.
## Rebajado (antes 0.12/0.30/0.50): cada plato retiene menos al cliente.
##
## El de 3 estrellas bajo despues de 0.38, porque con esa recarga el CAPITAN
## era practicamente inmortal: recuperaba 13.3 s de paciencia por plato, mas de
## lo que gastaba esperando, asi que servido con soltura no se marchaba nunca.
## Con 0.32 el hueco que se le puede dejar entre platos baja de 13.3 a 11.2 s
## (y a 7.5 s cuando ya lleva veinte), que con cuatro sitios ocupados es un
## margen que se pierde solo. Los otros dos niveles no se tocan: el grumete ya
## estaba bien (empata a 3.1 s, imposible de sostener) y el pirata en el filo.
const PATIENCE_FOOD: Dictionary = { 1: 0.09, 2: 0.22, 3: 0.32 }

# --- HASTÍO Y VARIEDAD -------------------------------------------------------
# El cliente lleva la cuenta de qué platos ha PROBADO (`tried`). Cada plato
# nunca probado alarga su racha de variedad (`variety`: el multiplicador x1,
# x2, x3... que enseña la chapa junto a su barra); un plato repetido la ROMPE
# a cero y sube su escalera de hastío, que es monótona: no se perdona nunca.
# Con la carta limitada a 4 recetas esto le da a cada cliente un ARCO FINITO:
# cuando ya lo ha probado todo, o se le despide con un postre (que cobra el
# multiplicador) o repite y se desangra. La rotación sale sola del sistema.
#
## Recarga de un plato REPETIDO según la repetición que hace (1ª, 2ª, 3ª...):
## primero recarga poco, luego nada. El jengibre esquiva esta escalera.
const REPEAT_RECHARGE := [0.2, 0.1, 0.0]
## De la 4ª repetición en adelante el plato DRENA paciencia: fracción de la
## BARRA ENTERA por escalón (4ª −5%, 5ª −10%, 6ª −15%...), con tope. Es
## fracción de la barra y no del plato a propósito: multiplicar la recarga de
## un L1 (9%) por un factor negativo daba drenajes del 1%, imperceptibles.
const REPEAT_DRAIN_STEP := 0.05
const REPEAT_DRAIN_MAX := 0.20
## Bono de recarga por racha de variedad: el plato x2 recarga ×1.2, el x3
## ×1.3... (el primero recarga normal). No lleva tope numérico porque el tope
## es ESTRUCTURAL: la racha muere cuando se acaban los platos distintos de la
## carta (4 huecos), y el té verde REINICIA el arco en vez de continuarlo —
## si lo continuara, la recarga crecería sin freno y volvería el capitán
## inmortal que ya obligó a bajar PATIENCE_FOOD de 0.38 a 0.32.
const VARIETY_RECHARGE_STEP := 0.1
## Propina que cobra el POSTRE por cada punto de multiplicador al despedir al
## cliente (x3 = 9 doblones al bote). Es un aliciente, no un premio decisivo.
const VARIETY_TIP_PER_STEP := 3

# --- EXTRAS: los TRES cuentan como plato NUEVO, y los tres tienen contra ---
# Un extra (10 doblones el uso) hace que ese plato cuente como nunca probado,
# aunque el cliente ya lo haya comido: alarga la racha y cobra el bono de oro.
# Eso es MUY poderoso —rompe el techo de la carta— así que cada uno se paga
# con un defecto que va justo contra lo que el sistema premia:
#  - WASABI: en vez de recargar paciencia, DRENA lo que habría recargado.
#  - SOJA: acelera el bocado, y el bocado es el rato en que la paciencia NO
#    baja, así que devuelve al cliente a la cola antes de tiempo.
#  - JENGIBRE: reinicia el PALADAR entero (todos los platos vuelven a contar
#    como nuevos, este incluido) pero cuesta UN punto de multiplicador.
## Cuánto más rápido mastica un plato con soja.
const SOJA_BITE_SPEED := 1.6
## El decaimiento del PICOTEO repetido (edamame tras edamame rellena menos el
## bocado). Antes gobernaba también el hastío; ahora es SOLO de los snacks.
const REPEAT_DECAY := 0.4

## Castigo por irse de vacío, ESCALONADO: cada cliente que se marcha sin comer
## encarece al siguiente (base × 1+0.5·vacíos_previos, tope ×3). Es el
## contrapeso del "cliente eterno": monopolizar la cocina mimando a uno deja a
## los demás sin probar bocado, y cada abandono cuesta más que el anterior.
## La cuenta la lleva level3d.empty_leavers.
const EMPTY_LEAVE_STEP := 0.5
const EMPTY_LEAVE_CAP := 3.0

## El bocadillo de CÓMIC del cliente: SIEMPRE presente desde su primer plato,
## HORIZONTAL y colgando POR DEBAJO de la cabeza, con la COLA ARRIBA
## señalándola. Los platos van SOLAPADOS: el recién comido entra por la
## DERECHA entero y encima, y de cada anterior queda una franja
## (BUBBLE_SLIVER) asomando por su izquierda; lleno (BUBBLE_MAX), el más
## viejo desaparece por la izquierda. El bocadillo sale hacia el lado
## EXTERIOR del cliente —a la izquierda si su silla cae en la mitad izquierda
## de la pantalla, a la derecha si no— para no taparse con el circuito.
##
## CUELGA HACIA ABAJO A PROPÓSITO: por encima de la cabeza está la franja de
## las barras (paciencia y bocado), y con el bocadillo ahí arriba tapaba las
## barras del cliente de AL LADO — y la barra del vecino tapaba a su vez la
## chapa del multiplicador. Debajo de la cabeza no hay nada que estorbar.
## `bocadillo.png` (cola arriba-izquierda) es el del lado derecho y
## `bocadillo_esp.png` su espejo; 9-slice de 62 px de alto dibujado 1:1, solo
## estira su banda central blanca a lo ancho.
const BUBBLE_TEX := "res://assets/ui/bocadillo.png"
const BUBBLE_TEX_ESP := "res://assets/ui/bocadillo_esp.png"
const BUBBLE_MAX := 4
const BUBBLE_ICON := 28.0
## Franja visible de cada plato anterior bajo el que tiene encima.
const BUBBLE_SLIVER := 14.0
const BUBBLE_PAD := 12.0
## Alto de la COLA (arriba) y del cuerpo blanco, medidos sobre el PNG.
const BUBBLE_TAIL_H := 10.0
const BUBBLE_BODY_H := 52.0
const BUBBLE_H := 62.0        ## cola + cuerpo
## Cuánto por debajo del ancla de la cabeza empieza la cola.
const BUBBLE_DROP := 4.0
## Dónde cae la PUNTA de la cola dentro del gráfico, contada desde el canto
## de su lado (medido sobre el PNG: la punta ocupa x 14-16 de la esquina).
## El bocadillo se coloca restando esto, no pegando el CANTO a la cabeza:
## si no, la punta se queda 15 px hacia dentro y no señala a nadie.
const BUBBLE_TAIL_X := 15.0
## ATENUACIÓN: los bocadillos son permanentes, así que en una barra llena
## serían ocho manchas blancas; se quedan a media luz y solo el del cliente
## que ACABA de coger plato luce a plena luz un par de segundos.
const BUBBLE_DIM := 0.5
const BUBBLE_HOT := 2.2
## Tope BASE del multiplicador: recarga ×1.5, bono de oro +5 por plato y postre
## de 15 al bote. Sube a VARIETY_MAX_PERK con el bonificador "Paladar de
## capitán", y se DUPLICA mientras corre el potenciador "Doble variedad" — por
## eso hay chapas dibujadas hasta x20, que es el techo real del juego (los 10
## del bonificador por el 2 del potenciador).
const VARIETY_MAX := 5
const VARIETY_MAX_PERK := 10
## Chapas del multiplicador (x2..x5): monedas de oro DIBUJADAS por
## `build_mult_badges` con la paleta y la Exo 2 Bold del juego — la tanda
## generada con Ludo salía con estallidos que no casaban con el set.
## Hay chapa dibujada para cada valor de x2 a x20 (`build_mult_badges`).
const MULT_FIRST := 2
const MULT_LAST := 20
const MULT_BADGE := 40.0
## EL RITMO DEL JUEGO (ver RecipeData.RITMO_COOLDOWN). Estas dos son las que
## de verdad quitan la prisa: con la barra de paciencia y el bocado más largos
## el jugador deja de jugar en pánico y puede pararse a LEER la barra —los
## bocadillos, las chapas, quién está en rojo— antes de decidir.
## No van uniformes con el cooldown a propósito: el tiempo de GESTOS del
## jugador es fijo (son sus manos), así que escalarlo todo por igual dejaría
## el juego idéntico y solo más largo. Al crecer más lo del CLIENTE que lo de
## la COCINA, el jugador gana holgura de verdad.
const RITMO_PACIENCIA := 1.5
const RITMO_BOCADO := 1.35
## Cada plato comido acelera el drenaje de paciencia en este factor.
const PATIENCE_DRAIN_PER_PLATE := 0.025
## Mientras NO ha comido nada, la paciencia baja a esta fracción del ritmo
## normal: da margen para que todo cliente llegue a catar su primer plato.
const FIRST_PLATE_DRAIN := 0.45
## Cuando el nivel ya ha terminado, el bocado que quedaba a medias corre a esta
## velocidad: el jugador solo espera a cobrarlo, no tiene sentido hacerle mirar.
const END_BITE_SPEED := 5.0
## Doblones extra que deja un plato de PICOTEO ("snack" en recipe_data, como el
## edamame) cuando el cliente lo coge SIN dejar de comer el plato que tenia.
const SNACK_BONUS := 1
## Fraccion de la paciencia maxima que pierde el cliente que DESPRECIA un
## plato de RIESGO (el fugu del valiente): mirarlo y no atreverse molesta.
const RIESGO_DESPRECIO := 0.08
## Cuanto llega a escalar el precio de un plato con "talla" al tener el
## RECORD MAXIMO de su especie: x2 (el toro pasa de 10 a 20 doblones). No es
## una perilla suelta — es lo que hace que valga la pena pescar el ejemplar
## grande y no solo llenar el album.
const TALLA_MAX := 1.0
## El picoteo RELLENA LA BARRA DE COMER (no la de paciencia): alarga la comida
## en curso esta fraccion de su duracion. Mientras come, la paciencia no se
## drena, asi que alargar el bocado es lo que retiene al cliente en la mesa.
const SNACK_EAT_REFILL := 0.35

## Propina segun el nº de platos comidos (ver client.gd 2D para el detalle).
const TIP_RULES: Dictionary = {
	"E": { "start": 1, "ramp": 3, "every": 1, "base": 0.20, "step": 0.01, "max": 0.65, "pct": 0.15 },
	"A": { "start": 1, "ramp": 3, "every": 1, "base": 0.23, "step": 0.015, "max": 0.60, "pct": 0.16 },
	"G": { "start": 1, "ramp": 3, "every": 1, "base": 0.25, "step": 0.02, "max": 0.50, "pct": 0.18 },
}

## Altura del asiento del taburete (debe coincidir con level3d.STOOL_H).
const STOOL_TOP := 0.47
## Huella del plato que come el cliente, algo menor que el de la cinta.
const HELD_DISH_FOOT := 0.45

var client_type: String = "E"
## Genero de ESTE cliente ("m"/"f"): lo sortea el nivel al sentarlo, asi que
## la clientela sale mezclada y distinta en cada partida.
var gender: String = CharacterData.MALE
var patience_scale: float = 1.0
var pay_mult: float = 1.0
var guaranteed_next: bool = false
## Este cliente NO falla nunca el dado de un PICOTEO. Lo pone el guion del
## nivel 3 sobre el primer grumete: la lección es "el picoteo se cuela mientras
## come", y con el 0.9 de la receta había un 10% de que el jugador hiciera todo
## bien y viera cómo su edamame pasa de largo.
var snack_sure: bool = false
## Multiplicador extra del tiempo de comer. Solo lo toca el guion del tutorial,
## que necesita bocados largos para poder explicar cosas mientras el cliente come.
var slow_eat: float = 1.0
## Velocidad del bocado EN CURSO (1 = normal). `slow_eat` solo se aplica al
## EMPEZAR un plato, así que no sirve para acortar el que ya está en marcha: en
## el tutorial el nigiri se sirve larguísimo para poder explicar el té mientras
## mastica, y en cuanto el grumete pica el té ese motivo desaparece pero le
## quedaba casi un minuto de barra bajando. Se reinicia con cada plato.
var bite_speed: float = 1.0
## Ritmo de bocado BASE de este cliente, al que vuelve con cada plato. Lo pone
## el puerto (`bite_speed` en CampaignData): el nivel 11 come con un hambre que
## no es normal y ahi la barra corre para todos.
var bite_base: float = 1.0
## Personaje CONCRETO en vez del que le tocaría por tipo (`CharacterData.MODELS`):
## lo usan Pablo el Rubio y el Kappa, que comen como su tipo pero con su propio
## modelo. "" = el del tipo de siempre.
var who_override: String = ""
## En los niveles-escuela (sin bote) las propinas NI SE TIRAN: así no hay
## cifras verdes flotando hacia un bote que no existe en pantalla.
var tips_enabled := true
## MODO JEFE (el Kappa del nivel 10). Lo enciende `make_boss()`: bocado
## rapidísimo, paciencia que se agota más deprisa, come platos de CUALQUIER
## nivel casi seguro y no toca los postres (un postre lo despediría y el duelo
## consiste justo en retenerlo). Su condición la vigila el guion del nivel.
var boss := false
## Cuánto se ACORTA su bocado (0.32 = come el triple de rápido). Lo fija
## make_boss().
var boss_eat_scale := 1.0
## Multiplicador del DRENAJE de paciencia mientras espera. Lo usan el jefe
## (make_boss) y la INTRO DEL CAOS, que reparte drenajes calculados para que
## cada cliente se levante en su segundo exacto.
var drain_scale := 1.0
## Paciencia CONGELADA por guion (la lección de las cajas del nivel 1): la
## barra se queda quieta sin teñirse de azul, que ese color es del unagi.
var patience_hold := false
## La paciencia baja TAMBIÉN mientras come. Lo enciende la INTRO DEL CAOS: allí
## la clientela se larga a una hora fijada de antemano y darle un plato no
## puede salvarla — como mucho, retrasarla. En el juego normal el bocado es un
## respiro (comer NO gasta paciencia) y esto se queda apagado.
var always_drain := false
## ¿Se dibuja el aparato de la VARIEDAD (bocadillo de platos comidos y chapa
## del multiplicador)? En el nivel 1 no: el sistema no se ha explicado todavía
## y son dos adornos que el jugador no sabe leer. El multiplicador se sigue
## calculando por dentro — lo único que se apaga es enseñarlo.
var variety_ui := true
## Piso de probabilidad con el que el jefe coge cualquier plato no-postre.
const BOSS_TAKE := 0.95
## Plato que este cliente coge SEGURO en cuanto le pase por delante (los
## encargos de guion: el barco de Miku y el de Nach). "" = ninguno.
var eager_dish := ""
## Recorte de la PROBABILIDAD de propina del jefe. Come tantos platos (18+ por
## duelo, con las reglas de capitán subiendo al 50%) que a tarifa normal
## regaba el bote de propinas: paga como cuatro capitanes sin esto.
const BOSS_TIP_MULT := 0.25
## Perdona el castigo de marcharse sin comer (ver force_leave).
var _sin_castigo := false
## En PUERTOS y ABORDAJES el vacío no cuesta oro (el jugador ya pierde por la
## vía propia del tipo: la derrota a los 3 vacíos o los 15 s de reloj). El
## nivel lo apaga al crear el cliente; en islas, arcade y tutorial sigue puesto.
var penaliza_vacio := true
## Puntos de la ruta de entrada (el nivel los define; el ultimo es el asiento).
var route: Array = []
## Punto por el que desaparece al marcharse (la borda).
var exit_point := Vector3.ZERO
## Punto de la cinta (mundo) frente a su asiento, donde vigila los platos.
var belt_point := Vector3.ZERO
## Orientacion (grados Y) mirando a la cinta cuando esta sentado.
var seat_yaw := 0.0

var state: State = State.ARRIVING
var patience_max: float = 55.0
var patience: float = 55.0
var satiety_eaten: int = 0
# --- hastío y variedad (ver el bloque de constantes) ---
## Platos que este cliente ya ha probado (id → true). Lo limpia el té verde.
var tried: Dictionary = {}
## Racha de variedad en curso: el multiplicador x1, x2, x3...
var variety: int = 0
## Repeticiones acumuladas, monótonas: la escalera del hastío no perdona.
var repeat_count: int = 0
## Este cliente ya llegó al tope base del multiplicador (se avisa una sola vez).
var _variety_maxed := false
var money_earned: int = 0
var eat_timer: float = 0.0
var eat_duration: float = 1.0
## Un cliente solo pica UN plato de picoteo por cada plato que se está
## comiendo: se marca al cogerlo y se limpia al empezar el plato siguiente.
var snack_taken := false
## El PICOTEO EXTRA ("extra_snack", el bol de arroz) lleva su turno APARTE: no
## gasta el del picoteo normal — se puede comer un edamame Y un bol en el
## mismo bocado, en cualquier orden — pero él también es uno por bocado.
var extra_snack_taken := false
## Bono al dado del SIGUIENTE plato que le pase (lo deja el nigiri de
## caballa, "next_take_bonus"). Se limpia al coger un plato.
var next_take_bonus := 0.0
## Segundos que la paciencia se queda CONGELADA (la deja el unagi glaseado).
var patience_frozen: float = 0.0

# --- CANTO DE SIRENA (mar 2) ---
## Atontado: mira al mar y NO coge ni un plato (el dado se APLAZA, no se
## falla: `_scan_belt` sale sin tirar nada). La paciencia sigue bajando.
var atontado := false
## Despertado por el jugador con un TOQUE: inmune hasta que acabe ESTE canto.
var canto_despierto := false
## Inmune al canto global (la propia sirena, que es quien canta).
var canto_inmune := false
## Las notas "~" flotando sobre la cabeza del atontado (viven en world_ui).
var _notas: Label = null
var tips_earned: int = 0
var current_price: int = 0
var current_satiety: int = 0
var current_id: String = ""
## Extras (jengibre / wasabi / soja) del plato que se está comiendo.
var current_extras: Array = []
## Tiempo de comida propio del plato en curso (0 = el de su receta). Lo trae el
## barco combinado, que tarda según cuántos platos lleve dentro.
var current_eat_mult: float = 0.0
var eaten_ids: Array[String] = []
var declined: Array[int] = []
# --- Maestrías del cocinero: efectos sobre ESTE cliente (ver skill_data.gd).
# Se leen una vez en _ready; en el tutorial quedan en neutro.
## "Buen anfitrión": factor de la recarga de paciencia de los platos (solo la
## POSITIVA de los platos nuevos y neutros — no salva al que repite ni engorda
## el drenaje del wasabi).
var skill_recharge := 1.0
## "Buen precio": factor del precio de cada plato.
var skill_price := 1.0
## "Mano suelta" y "Buena cara": cuantía y puntos de probabilidad de propina.
var skill_tip_amount := 1.0
var skill_tip_chance := 0.0
## "Fama del cocinero": suelo de probabilidad de coger cualquier plato.
var skill_take_floor := 0.0
## "Paladar generoso": rango 0..5 (cuántas repeticiones admite cada plato).
var paladar_rank := 0
## Primer plato que comió este cliente (para el rango 1 del paladar).
var _primer_plato := ""
## El plato que está comiendo venía MARCADO por "Golpe de suerte": al aplicarse
## la comida sube un punto extra de multiplicador.
var current_lucky := false
## Se ha acabado el nivel mientras comia: se marchara al acabar el bocado.
var _leave_when_done := false
var level_ref: Node = null

## El modelo cuelga de "body": el bob del andar y el ajuste de sentado van en
## body.position.y, y el giro de orientacion en la raiz.
var _body: Node3D
var _anim: CharacterAnim = null
var _model_scale := 1.0
var _height := 1.75
## Alto a mano (0 = el del tipo). Lo usa el JEFE: el Kappa mide mas que un
## capitan, y su talla no puede salir de TYPE_HEIGHTS porque ocupa el hueco
## de un cliente de tipo G.
var height_override := 0.0
## Ya se aviso de esta hambruna (se rearma al recuperar paciencia).
var _starved_sent := false
## Mancha de sombra que acompaña al cliente.
var _blob: MeshInstance3D = null
var _t := 0.0                 ## reloj local para respirar/sentado
var _walk_t := 0.0            ## reloj del ciclo de marcha (solo avanza andando)
var _eat_t := 0.0             ## reloj del bocado (solo avanza comiendo)
var _walk_speed := 1.2
var _leg := 0
var _leg_dist := 0.0
var _dish_spot := Vector3.ZERO
var _held_dish: Node3D = null

var _patience_bar: ProgressBar = null
var _eat_bar: ProgressBar = null
## Chapa GRÁFICA del multiplicador (mult_x2..mult_x5), HIJA del bocadillo:
## así se dibuja siempre por encima de él y hereda su atenuación.
var _mult_badge: TextureRect = null
## Bocadillo de cómic persistente con los últimos platos comidos.
var _bubble: NinePatchRect = null
## Iconos dentro del bocadillo, índice 0 = el MÁS RECIENTE (a la derecha).
var _bubble_icons: Array = []
## true = el bocadillo sale hacia la IZQUIERDA de la cabeza (cliente en la
## mitad izquierda de la pantalla). Se decide al crearlo.
var _bubble_left := false
## Tween de la atenuación en curso (se mata con cada plato nuevo).
var _dim_tween: Tween = null
## Tween de la CHAPA en curso. Hay que guardarlo para matarlo: al bajar el
## multiplicador arranca un encogido que al terminar pone la chapa en
## `visible = false`, y si la racha vuelve a subir dentro de esa ventana ese
## tween seguía vivo y escondía la chapa con el multiplicador ya alto — el
## jugador veía "el multiplicador no sube" cuando sí estaba subiendo.
var _badge_tween: Tween = null


func _ready() -> void:
	add_to_group("clients")
	level_ref = get_parent()
	# MAESTRÍAS del cocinero: en el tutorial quedan en neutro (la clase de
	# David está medida contra el juego pelado).
	if not GameState.is_tutorial():
		skill_recharge = 1.0 + GameState.skill_value("buen_anfitrion") / 100.0
		skill_price = 1.0 + GameState.skill_value("buen_precio") / 100.0
		skill_tip_amount = 1.0 + GameState.skill_value("mano_suelta") / 100.0
		skill_tip_chance = GameState.skill_value("buena_cara") / 100.0
		skill_take_floor = GameState.skill_value("fama") / 100.0
		paladar_rank = GameState.skill_rank("paladar_generoso")
	# Paciencia base ajustada a partidas de 2:30.
	patience_max = randf_range(30.0, 40.0) * patience_scale * RITMO_PACIENCIA
	patience = patience_max
	_height = height_override if height_override > 0.0 \
			else float(TYPE_HEIGHTS.get(client_type, 1.75))
	_spawn_model()
	_make_blob()
	_make_bars()
	if not route.is_empty():
		position = route[0] if position == Vector3.ZERO else position
	_face_leg()


## Mancha de sombra bajo los pies: el juego no usa sombras proyectadas (ver
## SceneBackdrop.blob_shadow), así que sin esto los clientes flotan sobre la
## cubierta. Cuelga del propio cliente, así que le sigue sola.
func _make_blob() -> void:
	var w := _height * 0.5
	_blob = SceneBackdrop.blob_shadow(w, w * 0.68)
	_blob.position = Vector3(0.0, 0.03, 0.0)
	add_child(_blob)


func _spawn_model() -> void:
	_body = Node3D.new()
	add_child(_body)
	var quien: String = who_override if who_override != "" \
			else CharacterData.who_for_type(client_type)
	var path := CharacterData.model(quien, gender)
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	_body.add_child(inst)
	var aabb := _merged_aabb(inst)
	_model_scale = _height / maxf(aabb.size.y, 0.0001)
	inst.scale = Vector3.ONE * _model_scale
	inst.position = -Vector3(
		aabb.position.x + aabb.size.x * 0.5,
		aabb.position.y,
		aabb.position.z + aabb.size.z * 0.5) * _model_scale
	var skels := inst.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		_anim = CharacterAnim.new(skels[0])
		if not _anim.has_humanoid_bones():
			_anim = null
	# La velocidad sale del propio ciclo de marcha: con ella el pie apoyado
	# queda clavado en el suelo (cero patinaje). Es mas lenta que la del juego
	# 2D (~1.2 u/s frente a 2.2), decision tomada a proposito.
	if _anim != null:
		_walk_speed = _anim.ground_speed(_model_scale)


func _merged_aabb(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = m.transform * m.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


# ------------------------------------------------------------ barras y HUD

## Las barras viven en level.world_ui (CanvasLayer bajo el HUD) y se anclan
## proyectando un punto sobre la cabeza; la camara es fija, asi que basta con
## recolocarlas cuando el cliente se sienta.
## Colores de la barra de PACIENCIA, que va cambiando con lo que le queda:
## verde de sobra, ámbar a partir del 60% y roja del 25% para abajo. El paso de
## un color a otro es un degradado, así que la barra avisa antes de que sea
## tarde sin dar un salto de color.
const PAT_VERDE := Color(0.32, 0.80, 0.30)
const PAT_AMBAR := Color(1.00, 0.62, 0.10)
const PAT_ROJO := Color(0.88, 0.20, 0.16)
const PAT_ALTO := 1.0
const PAT_MEDIO := 0.6
const PAT_BAJO := 0.25
## La barra de COMER es azul y no cambia nunca: así se distingue de un vistazo
## de la de paciencia, que es la que hay que vigilar.
const COMER_AZUL := Color(0.24, 0.60, 0.96)
## Congelada por el unagi: azul claro, para que se vea que está parada.
const PAT_HIELO := Color(0.55, 0.85, 1.0)
## La barra tenida de VIOLETA mientras el cliente esta ATONTADO por el canto
## de sirena (mar 2): el jugador tiene que ver de un vistazo quien esta ido.
const PAT_CANTO := Color(0.72, 0.5, 0.95)

var _patience_fill: StyleBoxFlat = null


## Convierte a ESTE cliente en el JEFE del nivel (el Kappa). Se llama justo
## después de sentarlo el guion; toca lo que en un cliente normal fija _ready:
##  - PACIENCIA: barra más gorda en pantalla (que se vea que es el jefe), un
##    máximo alto y un drenaje BOSS de `drain` veces el normal. El "aguanta
##    poco" del jefe sale del drenaje, no del máximo: con el máximo corto la
##    barra ni se veía bajar, era un semáforo.
##  - BOCADO: `eat` (0.32 = come el triple de rápido). Los platos de más nivel
##    siguen durando MÁS (la base por nivel se respeta), solo que todo corre.
func make_boss(eat := 0.32, drain := 1.55, max_patience := 55.0) -> void:
	boss = true
	boss_eat_scale = eat
	drain_scale = drain
	# El jefe va con el mismo ritmo que el resto: si su barra no creciera con
	# la de todos, su duelo se volvería el doble de duro al ralentizar el juego.
	patience_max = max_patience * RITMO_PACIENCIA
	patience = patience_max
	if _patience_bar != null:
		_patience_bar.max_value = patience_max
		_patience_bar.size = Vector2(96, 17)
		_eat_bar.size = Vector2(96, 17)
		patience_bar_update()


## La paciencia del JEFE, mandada por el guion: a una fraccion de su maximo
## (las recuperaciones tras cada hambruna) o sumandole una fraccion (el premio
## por superar una fase). Las dos rearman el aviso de hambruna.
func boss_patience_set(frac: float) -> void:
	patience = clampf(patience_max * frac, 0.0, patience_max)
	_starved_sent = false
	patience_bar_update()


func boss_patience_add(frac: float) -> void:
	patience = minf(patience + patience_max * frac, patience_max)
	_starved_sent = false
	patience_bar_update()


## Esconde todo el aparato flotante (barras y bocadillo). Lo usa la derrota
## del jefe: dormido en el suelo, una barra de paciencia encima seria absurda.
func hide_bars() -> void:
	if _patience_bar != null:
		_patience_bar.visible = false
	if _eat_bar != null:
		_eat_bar.visible = false
	if _bubble != null:
		_bubble.visible = false


## CANTO DE SIRENA: entrar y salir del trance. Lo llama level3d por fotograma
## mientras suena el canto (y el guion de la jefa, a dedo).
func set_atontado(v: bool) -> void:
	if atontado == v:
		return
	atontado = v
	patience_bar_update()
	if v:
		if _notas == null and _world_ui() != null:
			_notas = Label.new()
			_notas.text = "~ ~"
			_notas.add_theme_font_size_override("font_size", 30)
			_notas.add_theme_color_override("font_color", Color(0.82, 0.6, 1.0))
			_notas.add_theme_color_override("font_outline_color", Color(0.18, 0.08, 0.3))
			_notas.add_theme_constant_override("outline_size", 8)
			_notas.z_index = 2
			_notas.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_world_ui().add_child(_notas)
			var base := _head_screen() + Vector2(24, -52)
			_notas.position = base
			_notas.pivot_offset = Vector2(20, 15)
			var tw := _notas.create_tween().set_loops()
			tw.tween_property(_notas, "position:y", base.y - 6.0, 0.7) 				.set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(_notas, "rotation_degrees", 9.0, 0.7) 				.set_trans(Tween.TRANS_SINE)
			tw.tween_property(_notas, "position:y", base.y + 4.0, 0.7) 				.set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(_notas, "rotation_degrees", -9.0, 0.7) 				.set_trans(Tween.TRANS_SINE)
	elif _notas != null:
		_notas.queue_free()
		_notas = null


## El TOQUE del jugador rompe el trance: despierto hasta el fin de ESTE canto.
func despertar() -> void:
	if not atontado:
		return
	canto_despierto = true
	set_atontado(false)
	# Sacudida de cabeza: un bote rapido del cuerpo, para que el toque se vea.
	if _body != null:
		var tw := create_tween()
		tw.tween_property(_body, "rotation_degrees:z", 7.0, 0.07)
		tw.tween_property(_body, "rotation_degrees:z", -7.0, 0.1)
		tw.tween_property(_body, "rotation_degrees:z", 0.0, 0.09)


func _make_bars() -> void:
	_patience_bar = ProgressBar.new()
	_patience_bar.show_percentage = false
	_patience_bar.size = Vector2(76, 13)
	_patience_bar.max_value = patience_max
	_patience_bar.value = patience
	_patience_bar.visible = false
	_patience_fill = StyleBoxFlat.new()
	_patience_fill.bg_color = PAT_VERDE
	_patience_fill.set_corner_radius_all(4)
	_patience_bar.add_theme_stylebox_override("fill", _patience_fill)
	_eat_bar = ProgressBar.new()
	_eat_bar.show_percentage = false
	_eat_bar.size = Vector2(76, 13)
	var fill := StyleBoxFlat.new()
	fill.bg_color = COMER_AZUL
	fill.set_corner_radius_all(4)
	_eat_bar.add_theme_stylebox_override("fill", fill)
	_eat_bar.visible = false
	# Las BARRAS se dibujan SIEMPRE por encima de los bocadillos: con ocho
	# clientes alrededor de una barra isométrica, dos vecinos de la fila de
	# atrás se pisan sí o sí, y de las dos cosas la que no puede quedar
	# tapada es la barra (el bocadillo es memoria, la barra es urgencia).
	_patience_bar.z_index = 2
	_eat_bar.z_index = 2
	var ui := _world_ui()
	if ui != null:
		ui.add_child(_patience_bar)
		ui.add_child(_eat_bar)


func _world_ui() -> Node:
	if level_ref != null and "world_ui" in level_ref:
		return level_ref.world_ui
	return null


## Posicion en pantalla del punto sobre la cabeza del cliente.
func _head_screen() -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector2.ZERO
	return cam.unproject_position(global_position + Vector3.UP * (_height + 0.22))


func _place_bars() -> void:
	var p := _head_screen() + Vector2(-38, -10)
	_patience_bar.position = p
	_eat_bar.position = p



## Ancho del bocadillo con n platos dentro (el primero entero, franja por
## cada anterior). El mínimo (un plato) da 52, justo la suma de los márgenes
## 9-slice: por debajo las esquinas se pisarían.
func _bubble_width(n: int) -> float:
	return BUBBLE_PAD * 2.0 + BUBBLE_ICON + maxi(n - 1, 0) * BUBBLE_SLIVER


## DÓNDE ESTÁ DE VERDAD LA CABEZA en pantalla, que NO es `_head_screen()`.
##
## `_head_screen()` proyecta un punto a `_height + 0.22` sobre la RAÍZ del
## cliente. Para las BARRAS vale, porque justamente tienen que flotar por
## encima de todo. Pero un cliente SENTADO lleva el cuerpo bajado
## (`_sit_on_stool` mueve `_body.position.y` para posarle los glúteos en el
## taburete) y además encogido por la pose, así que su cabeza real cae
## bastante más abajo: el bocadillo colgaba de un punto en el aire y su cola
## no señalaba a nadie. Aquí se le pregunta al ESQUELETO por el hueso de la
## cabeza, y solo si no lo hay se cae al cálculo de antes.
func _head_anchor() -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector2.ZERO
	if _anim != null and _body != null:
		var skels := _body.find_children("*", "Skeleton3D", true, false)
		var idx: int = _anim.bone("Head")
		if not skels.is_empty() and idx >= 0:
			var skel: Skeleton3D = skels[0]
			var p: Vector3 = skel.global_transform \
				* skel.get_bone_global_pose(idx).origin
			# Un pelín por encima del hueso, que cae dentro del cráneo.
			return cam.unproject_position(p + Vector3.UP * 0.16)
	return _head_screen()


## Esquina superior izquierda del bocadillo para un ancho dado: pegado a la
## cabeza, extendiéndose hacia el lado exterior del cliente. La COLA (que vive
## en la banda no estirada del gráfico) queda apuntando a la cara.
func _bubble_pos(w: float) -> Vector2:
	var head := _head_anchor()
	# La PUNTA de la cola cae sobre la cabeza. Con el bocadillo a la
	# izquierda la cola está arriba-derecha (textura espejada), así que su
	# punta está a `w - BUBBLE_TAIL_X` del canto izquierdo.
	if _bubble_left:
		return Vector2(head.x - (w - BUBBLE_TAIL_X), head.y + BUBBLE_DROP)
	return Vector2(head.x - BUBBLE_TAIL_X, head.y + BUBBLE_DROP)


## Posición local del plato de antigüedad `age` (0 = recién comido) con n
## platos dentro: el nuevo a la DERECHA del todo y entero; los anteriores
## escalonados hacia la izquierda, cada uno asomando su franja. En vertical,
## centrados en el CUERPO, que empieza por debajo de la cola.
func _icon_pos(age: int, n: int) -> Vector2:
	return Vector2(BUBBLE_PAD + (n - 1 - age) * BUBBLE_SLIVER,
		BUBBLE_TAIL_H + (BUBBLE_BODY_H - BUBBLE_ICON) * 0.5)


func _exit_tree() -> void:
	for nodo in [_patience_bar, _eat_bar, _mult_badge, _bubble, _notas]:
		if nodo != null and is_instance_valid(nodo):
			nodo.queue_free()


# ------------------------------------------------------------------ estados

func is_waiting() -> bool:
	return state == State.WAITING


func boost_patience(fraction: float) -> void:
	patience += fraction * patience_max
	patience_bar_update()


## ¿Está con un plato entre manos? Lo consulta el guion del tutorial.
func is_eating() -> bool:
	return state == State.EATING


## Las dos barras flotantes, para que el guion del tutorial pueda enfocarlas.
func patience_bar() -> ProgressBar:
	return _patience_bar


func eat_bar() -> ProgressBar:
	return _eat_bar


func patience_bar_update() -> void:
	if _patience_bar == null:
		return
	_patience_bar.value = patience
	if _patience_fill == null:
		return
	if patience_frozen > 0.0:
		_patience_fill.bg_color = PAT_HIELO
		return
	if atontado:
		_patience_fill.bg_color = PAT_CANTO
		return
	_patience_fill.bg_color = _patience_color(
		clampf(patience / maxf(patience_max, 0.001), 0.0, 1.0))


## Verde → ámbar → rojo, interpolado por tramos.
static func _patience_color(f: float) -> Color:
	if f >= PAT_MEDIO:
		return PAT_AMBAR.lerp(PAT_VERDE, (f - PAT_MEDIO) / (PAT_ALTO - PAT_MEDIO))
	if f >= PAT_BAJO:
		return PAT_ROJO.lerp(PAT_AMBAR, (f - PAT_BAJO) / (PAT_MEDIO - PAT_BAJO))
	return PAT_ROJO


func _process(delta: float) -> void:
	if _time_frozen():
		return
	_t += delta
	match state:
		State.ARRIVING:
			_advance_route(delta)
		State.WAITING:
			_pose_sit_idle()
			# "patience_freeze" (unagi): la barra se congela unos segundos y no
			# baja nada. Se tiñe de azul para que se vea que está parada.
			if patience_frozen > 0.0:
				patience_frozen = maxf(patience_frozen - delta, 0.0)
				patience_bar_update()
				_scan_belt()
				return
			# Retenida POR GUION (la lección de las cajas del nivel 1): sin
			# tinte azul y sin cuenta atrás, pero el cliente sigue mirando la
			# cinta por si le llega algo.
			if patience_hold:
				_scan_belt()
				return
			# Cuanto mas ha comido, mas rapido se agota la paciencia.
			var drain := 1.0 + PATIENCE_DRAIN_PER_PLATE * eaten_ids.size()
			# Recién sentado la paciencia baja MUCHO más despacio: casi todo el
			# mundo debe llegar a probar su primer plato. En cuanto come algo,
			# el drenaje pasa a ser el normal.
			if eaten_ids.is_empty():
				drain *= FIRST_PLATE_DRAIN
			# El JEFE (y la clientela de la intro del caos) se impacienta más
			# deprisa: su espera es una cuenta atrás.
			drain *= drain_scale
			patience -= delta * drain
			if patience <= 0.0 and boss:
				# EL JEFE NO SE VA: se queda a cero y avisa una vez. Quien
				# decide que pasa (calavera, recuperacion, derrota) es el
				# guion, via boss_patience_set/add.
				patience = 0.0
				patience_bar_update()
				if not _starved_sent:
					_starved_sent = true
					boss_starved.emit()
				_scan_belt()
				return
			patience_bar_update()
			if patience <= 0.0:
				_leave()
				return
			_scan_belt()
		State.EATING:
			# Tras el fin del nivel el ultimo bocado va MUY deprisa: el jugador
			# ya no puede hacer nada y solo espera a ver lo que le dejan.
			var speed := END_BITE_SPEED if _leave_when_done else bite_speed
			_eat_t += delta * speed
			if _anim != null:
				_anim.reset()
				_anim.bite(_eat_t)
			eat_timer -= delta * speed
			_eat_bar.value = maxf(eat_timer, 0.0)
			# INTRO DEL CAOS: aquí la paciencia NO se detiene al comer. Esta
			# clientela tiene la hora puesta y darle un plato solo hace que se
			# vaya masticando; en el juego normal esta rama no corre.
			if always_drain:
				patience -= delta * drain_scale
				patience_bar_update()
				if patience <= 0.0:
					_leave()
					return
			# Sin dejar de comer puede picar un plato de "snack" (edamame).
			if not _leave_when_done:
				_scan_belt(true)
			if eat_timer <= 0.0:
				_finish_plate()
		State.LEAVING:
			_advance_route(delta)


## Recorre la ruta actual andando. Al agotar la ruta: sentarse (llegada) o
## desaparecer (salida). El avance y el bob salen del propio ciclo de marcha.
func _advance_route(delta: float) -> void:
	_walk_t += delta
	if _anim != null:
		_anim.reset()
		_anim.walk(_walk_t)
		_body.position.y = _anim.walk_bob(_walk_t, _model_scale)
	_leg_dist += _walk_speed * delta
	while _leg < route.size() - 1:
		var a: Vector3 = route[_leg]
		var b: Vector3 = route[_leg + 1]
		var leg_len := a.distance_to(b)
		if _leg_dist < leg_len:
			position = a.lerp(b, _leg_dist / leg_len)
			return
		_leg_dist -= leg_len
		_leg += 1
		_face_leg()
	# Ruta agotada.
	position = route.back()
	if state == State.ARRIVING:
		_seat()
	else:
		state = State.DONE
		queue_free()


func _face_leg() -> void:
	if _leg >= route.size() - 1:
		return
	var dir: Vector3 = route[_leg + 1] - route[_leg]
	if dir.length() > 0.001:
		rotation_degrees.y = rad_to_deg(atan2(dir.x, dir.z))


## Ya ha llegado a su taburete (el contador del HUD y la fila de cabezas lo
## esperan: hasta aquí el cliente es alguien que viene andando, no clientela
## atendible).
signal seated

func _seat() -> void:
	if state != State.ARRIVING:
		return
	state = State.WAITING
	seated.emit()
	rotation_degrees.y = seat_yaw
	_sit_on_stool()
	_place_bars()
	_patience_bar.visible = true


## Sienta al cliente EN EL ACTO, sin el paseo por la cubierta. Lo usa la INTRO
## DEL CAOS, que empieza con la barra ya llena: verlos entrar de uno en uno
## quitaba justo la sensación que busca la escena (llegas tarde a un desastre
## que ya está montado).
func sit_now() -> void:
	if state != State.ARRIVING or route.is_empty():
		return
	position = route.back()
	_leg = route.size() - 1
	_leg_dist = 0.0
	_seat()


## Sienta al personaje SOBRE el taburete: con la pose de sentado puesta, se
## sube/baja el cuerpo para que los gluteos (algo por debajo del hueso de la
## cadera) apoyen en el asiento. En personajes bajitos los pies quedan
## colgando, que es justo lo que hace un niño en un taburete de bar.
func _sit_on_stool() -> void:
	if _anim == null:
		return
	_anim.reset()
	_anim.sit()
	var skel: Skeleton3D = _body.find_children("*", "Skeleton3D", true, false)[0]
	var hip_w: Vector3 = skel.global_transform \
		* skel.get_bone_global_pose(_anim.bone("Pelvis")).origin
	var glute_drop := 0.10 * (_height / 1.75)
	var dy := (STOOL_TOP + glute_drop) - hip_w.y
	_body.position.y = dy
	# El plato ira donde la mano derecha va a buscar la comida (hand_plate es
	# un punto en espacio del esqueleto; el bocado come con la derecha: -X).
	var hp: Vector3 = _anim.hand_plate
	_dish_spot = skel.global_transform * Vector3(-hp.x, hp.y, hp.z) \
		+ Vector3(0.0, dy - 0.08, 0.0)
	_anim.reset()


func _pose_sit_idle() -> void:
	if _anim != null:
		_anim.reset()
		_anim.sit_idle(_t)
		# El atontado del canto gira la cabeza hacia lo lejos (ACUMULA sobre
		# la pose sentada, por eso va despues de sit_idle).
		if atontado:
			_anim.embobado(_t)


# ------------------------------------------------------------ coger platos

## Sondea los platos de la cinta: el que pase por su punto de la cinta a menos
## de TAKE_RADIUS (en el plano del suelo) puede ser cogido. Sustituye al Area2D
## del juego 2D sin necesitar fisica 3D.
## Con snack_only solo mira los platos de PICOTEO: es la pasada que se hace
## mientras el cliente esta comiendo, para que pueda picar sin interrumpirse.
## True en cuanto se ha sentado (sigue siéndolo mientras come y al irse).
func ya_sentado() -> bool:
	return state != State.ARRIVING


func _scan_belt(snack_only: bool = false) -> void:
	# CANTO DE SIRENA: el atontado no mira la cinta. OJO — salir AQUI es lo
	# que hace que el dado se APLACE y no se falle: el plato ni se apunta en
	# `declined`, asi que al despertar puede cogerlo en la siguiente pasada.
	if atontado:
		return
	for plate in get_tree().get_nodes_in_group("plates"):
		if plate.taken:
			continue
		var d := Vector2(plate.global_position.x - belt_point.x,
			plate.global_position.z - belt_point.z)
		if d.length() > TAKE_RADIUS:
			continue
		var pid: int = plate.get_instance_id()
		if pid in declined:
			continue
		var data: Dictionary = RecipeData.get_recipe(plate.recipe_id)
		# "only_type": postres que SOLO come un tipo de cliente (el mochi es de
		# grumetes, el dorayaki de piratas, el taiyaki de capitanes). Ni con
		# potenciadores lo cogen los demás: se descarta antes de tirar el dado.
		var only: String = data.get("only_type", "")
		if only != "" and only != client_type:
			continue
		# Plato RESERVADO a un personaje concreto (ver plate3d.only_who).
		if plate.only_who != "" and plate.only_who != who_override:
			continue
		# ...y RESERVADO a un tipo (ver plate3d.only_type).
		if plate.only_type != "" and plate.only_type != client_type:
			continue
		# El JEFE no toca los postres: un postre lo despediría de la mesa y su
		# duelo consiste justo en retenerlo comiendo. Se descarta ANTES del
		# dado, como los only_type.
		if boss and data.get("leaves_seat", false):
			continue
		# Solo un picoteo por plato en curso: hasta que no termine el que está
		# comiendo no vuelve a picar (al empezar el siguiente se rearma).
		# "Manos libres" (potenciador): mientras corre, CUALQUIER plato se puede
		# picar sin soltar el que se está comiendo, no solo los de picoteo.
		var todo_picoteo: bool = level_ref != null \
				and "snack_all_timer" in level_ref \
				and level_ref.snack_all_timer > 0.0
		# El bol de arroz ("extra_snack") gasta su propio turno, no el del
		# picoteo normal — asi entra ADEMAS del edamame, en cualquier orden.
		var pico_gastado: bool = extra_snack_taken \
			if data.get("extra_snack", false) else snack_taken
		if snack_only and (pico_gastado \
				or not (data.get("snack", false) or todo_picoteo)):
			continue
		# El barco se cataloga por lo que lleva dentro, no por su receta.
		var plate_satiety: int = int(data.get("satiety", 1))
		if plate.level_override > 0:
			plate_satiety = plate.level_override
		# "take_chance" salta la matriz por nivel. Admite las DOS formas: un
		# número, que vale igual para todos (el edamame lo pica cualquiera), o
		# un diccionario {E,A,G} con uno por tipo (el onigiri gusta a los tres,
		# pero no por igual).
		# "take_chances": matriz PROPIA de la receta (el barco combinado). Se
		# indexa igual, por tipo y nivel, solo que con otros números.
		var table: Dictionary = data.get("take_chances", TAKE_CHANCES)
		var chance: float = table.get(client_type, {}).get(plate_satiety, 0.0)
		var forced: Variant = data.get("take_chance", null)
		if forced is Dictionary:
			chance = float(forced.get(client_type, chance))
		elif forced != null:
			chance = float(forced)
		# FAMA DEL PLATO ("fama"): cada plato de esta receta ya servido en la
		# jornada sube su propio dado, con tope "fama_max". Va por RECETA y
		# por JORNADA (level3d.platos_receta), no por cliente — de ahi la
		# tension con el hastio, que es por cliente: la fama premia servir
		# mucho de lo mismo, el hastio castiga repetirselo al mismo comensal.
		var fama := float(data.get("fama", 0.0))
		if fama > 0.0 and level_ref != null and "platos_receta" in level_ref:
			var servidos: int = int(level_ref.platos_receta.get(plate.recipe_id, 0))
			chance += minf(fama * servidos, float(data.get("fama_max", 0.10)))
		chance = minf(chance, 1.0)
		if _aroma_active() and plate_satiety == FAVORITE_TIER.get(client_type, 0):
			chance = maxf(chance, 0.95)
		# "Fama del cocinero": SUELO de probabilidad, no un 100% — el capitán
		# sigue prefiriendo lo suyo y los tipos siguen significando algo. Los
		# postres de otro tipo ya se descartaron antes del dado, así que el
		# suelo no los toca.
		if skill_take_floor > 0.0:
			chance = maxf(chance, skill_take_floor)
		# El JEFE come de TODO: nivel 1, 2 o 3, casi seguro. Su filtro no es
		# qué coge, sino cuánto le dura (los platos gordos se mastican más).
		if boss and not snack_only:
			chance = maxf(chance, BOSS_TAKE)
		if guaranteed_next and not snack_only:
			chance = 1.0
		# El encargo de guion no se deja pasar nunca.
		if eager_dish != "" and str(plate.recipe_id) == eager_dish:
			chance = 1.0
		if snack_only and snack_sure:
			chance = 1.0
		# "next_take_bonus" (la caballa): el plato anterior le abrio el
		# apetito y el dado del siguiente va con bono.
		if not snack_only and next_take_bonus > 0.0:
			chance = minf(chance + next_take_bonus, 1.0)
		# DESPRECIO FORZADO (la clase del dado del nivel 1): el guion pide que
		# ESTE plato se deje pasar, y avisa al nivel para que le ponga el foco.
		if level_ref != null and "forzar_desprecio" in level_ref \
				and level_ref.forzar_desprecio and not snack_only:
			level_ref.forzar_desprecio = false
			level_ref.plato_ignorado.emit(plate.global_position)
			declined.append(pid)
			continue
		if randf() < chance:
			var rid: String = plate.recipe_id
			var plate_pos: Vector3 = plate.global_position
			# Un plato COMPARTIDO ("servings", el takoyaki) se queda en la
			# cinta con una racion menos; este cliente ya no lo vuelve a
			# mirar (a declined), pero el resto conserva su dado.
			if plate.consume_serving():
				declined.append(pid)
			if snack_only:
				_eat_snack(rid, data)
				return
			next_take_bonus = 0.0
			guaranteed_next = false
			# El plato puede traer su propio precio (barco combinado).
			var base_price: int = plate.price_override if plate.price_override > 0 \
				else int(data.get("price", 0))
			# "Buen precio": cada plato paga un poco más de lo que dice su ficha.
			current_price = int(round(base_price * pay_mult * skill_price))
			# FRESCURA / MARINADO: el precio viaja con la cinta. Recien servido
			# la frescura paga x1,3 y cae a x0,7 al final de la vuelta; el
			# marinado hace el camino contrario (reposar le sienta bien).
			if plate.belt_length > 0.0:
				var recorrido: float = clampf(plate.traveled / plate.belt_length, 0.0, 1.0)
				if data.get("frescura", false):
					current_price = int(round(current_price * (1.3 - 0.6 * recorrido)))
				elif data.get("marinado", false):
					current_price = int(round(current_price * (0.7 + 0.6 * recorrido)))
			# TALLA: el precio crece con el RECORD de pesca de su especie
			# (fish_best guarda la talla 0..1): hasta el DOBLE (TALLA_MAX).
			if data.has("talla"):
				current_price = int(round(current_price * (1.0
					+ TALLA_MAX * float(GameState.fish_best.get(str(data["talla"]), 0.0)))))
			# MARIDAJE: si el ULTIMO plato que comio esta en la lista, este
			# paga el bono — la carta se juega en parejas.
			var mar: Dictionary = data.get("maridaje", {})
			if not mar.is_empty() and not eaten_ids.is_empty() \
					and str(eaten_ids.back()) in mar.get("con", []):
				current_price += int(mar.get("bono", 0))
				_float_text("¡Maridaje!", Color(1.0, 0.86, 0.2), -50.0)
			current_satiety = plate_satiety
			current_id = rid
			current_extras = plate.extras.duplicate()
			current_eat_mult = plate.eat_mult_override
			current_lucky = plate.variety_bonus
			_start_eating(plate_pos)
			return
		# RIESGO: dejar pasar el plato de valientes cuesta paciencia.
		if data.get("riesgo", false) and not snack_only:
			patience = maxf(patience - patience_max * RIESGO_DESPRECIO, 0.0)
			patience_bar_update()
		declined.append(pid)


## Picoteo cogido MIENTRAS come otro plato: RELLENA LA BARRA DE COMER (alarga
## el bocado en curso) y se cobra con SNACK_BONUS doblones extra, sin
## interrumpir el plato que tenia. Repetir el mismo picoteo rinde cada vez
## menos (mismo decaimiento que el aburrimiento), asi que no compensa inundar
## la cinta de edamame.
func _eat_snack(recipe_id: String, data: Dictionary) -> void:
	if data.get("extra_snack", false):
		extra_snack_taken = true
	else:
		snack_taken = true
	var reps := 0
	for id in eaten_ids:
		if id == recipe_id:
			reps += 1
	var sat: int = data.get("satiety", 1)
	# "snack_refill": cuanto alarga el bocado (el gari casi nada, porque lo suyo
	# es la propina). Por defecto SNACK_EAT_REFILL.
	var refill: float = eat_duration * float(data.get("snack_refill", SNACK_EAT_REFILL)) \
		* pow(REPEAT_DECAY, reps)
	eat_timer += refill
	# La barra tiene que poder mostrar el tiempo extra: se ensancha el maximo.
	_eat_bar.max_value = maxf(_eat_bar.max_value, eat_timer)
	_eat_bar.value = eat_timer
	# "clears_boredom": el té verde limpia el PALADAR y nada más — todos los
	# platos vuelven a contar como nuevos y la racha SIGUE donde estaba, así
	# que se puede continuar combinando. Es su papel frente al jengibre: el
	# jengibre limpia el paladar pero cuesta un punto de multiplicador; el té
	# no cuesta ninguno, pero ocupa un hueco de la carta y, como todos los
	# picoteos, tampoco SUMA.
	if data.get("clears_boredom", false):
		_limpiar_paladar()
	# "snack_price": el picoteo puede pagar OTRO precio comido como picoteo
	# (el edamame: 1 suelto, 3 acompañando). Sin él, price + SNACK_BONUS.
	var price: int
	if data.has("snack_price"):
		price = int(round(float(data["snack_price"]) * pay_mult * skill_price))
	else:
		price = int(round(data.get("price", 0) * pay_mult * skill_price)) \
			+ SNACK_BONUS
	# EL PICOTEO QUE SÍ SUMA VARIEDAD ("variety_snack", hoy solo el sunomono):
	# cobra el bono de oro del multiplicador VIGENTE y sube un punto la primera
	# vez que se prueba, igual que un plato normal. Los demás picoteos ni suman
	# ni rompen la racha.
	if data.get("variety_snack", false) and not tried.has(recipe_id):
		price += variety
		tried[recipe_id] = int(tried.get(recipe_id, 0)) + 1
		_set_variety(variety + 1, true)
	satiety_eaten += sat
	money_earned += price
	eaten_ids.append(recipe_id)
	plate_served.emit(price, 0)
	_push_bubble_icon(recipe_id, false)
	_float_text("+$%d" % price, Color(1.0, 0.86, 0.2))


## El plato viaja de la cinta al mostrador frente al cliente, y este empieza a
## comer (coreografia de 4 fases de CharacterAnim.bite).
func _start_eating(plate_global: Vector3) -> void:
	state = State.EATING
	_eat_t = 0.0
	# Plato nuevo: vuelve a tener derecho a un picoteo (y a un bol) y al
	# ritmo normal.
	snack_taken = false
	extra_snack_taken = false
	bite_speed = bite_base
	# SOJA: el bocado corre más. Como la paciencia NO baja mientras se come,
	# acortar el bocado devuelve al cliente a la espera antes de tiempo — esa
	# es su contrapartida por contar como plato nuevo.
	if "soja" in current_extras:
		bite_speed = SOJA_BITE_SPEED
	var recipe := RecipeData.get_recipe(current_id)
	var base: float = float(EAT_TIMES[client_type].get(current_satiety,
		EAT_TIMES[client_type][1]))
	# "eat_mult": algunos platos (p. ej. la sopa de miso) se comen mas despacio.
	# `slow_eat` lo usa el guion del TUTORIAL para que un plato concreto dure
	# lo suficiente como para explicar otra receta mientras el cliente come.
	eat_duration = base * RITMO_BOCADO \
			* randf_range(1.0 - EAT_JITTER, 1.0 + EAT_JITTER) \
			* _eat_mult_of(recipe) * slow_eat * boss_eat_scale
	eat_timer = eat_duration
	_eat_bar.max_value = eat_duration
	_eat_bar.value = eat_duration
	_eat_bar.visible = true
	_patience_bar.visible = false
	# La comida recarga paciencia según el nivel del plato, escalada por el
	# sistema de HASTÍO Y VARIEDAD (ver _apply_meal_patience).
	_apply_meal_patience(recipe)
	# EL OLOR DEL BARBO ("neighbor_mult"): al empezar a comerlo, los vecinos
	# de silla pierden multiplicador. Lo reparte el nivel, que sabe de sillas.
	var olor := int(recipe.get("neighbor_mult", 0))
	if olor != 0 and level_ref != null \
			and level_ref.has_method("aplicar_olor_vecinos"):
		level_ref.aplicar_olor_vecinos(self, olor)
	# CONTAGIO (el dashi ahumado): reconforta tanto al que lo come que al
	# RESTO de la mesa se le hace la espera mas larga (o mas corta, si el
	# valor fuera positivo). Fraccion de la paciencia maxima de cada uno.
	var contagio := float(recipe.get("contagio", 0.0))
	if contagio != 0.0 and level_ref != null \
			and level_ref.has_method("aplicar_contagio"):
		level_ref.aplicar_contagio(self, contagio)
	# RIESGO: el valiente que lo coge rellena la paciencia ENTERA.
	if recipe.get("riesgo", false):
		patience = patience_max
		patience_bar_update()

	# El plato (modelo 3D) viaja de la cinta al mostrador, delante del cliente.
	_held_dish = Node3D.new()
	level_ref.add_child(_held_dish)
	_held_dish.global_position = plate_global
	var dish_path := "res://assets/models/%s.glb" % current_id
	if ResourceLoader.exists(dish_path):
		var inst: Node3D = (load(dish_path) as PackedScene).instantiate()
		_held_dish.add_child(inst)
		var aabb := _merged_aabb(inst)
		var foot := maxf(maxf(aabb.size.x, aabb.size.z), 0.0001)
		var s := HELD_DISH_FOOT / foot
		inst.scale = Vector3.ONE * s
		inst.position = -Vector3(
			aabb.position.x + aabb.size.x * 0.5,
			aabb.position.y,
			aabb.position.z + aabb.size.z * 0.5) * s
	var grab := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	grab.tween_property(_held_dish, "global_position", _dish_spot, 0.35)


## El plato puede traer su propio tiempo de comida (el barco, según los platos
## que lleve); si no, manda el "eat_mult" de la receta.
func _eat_mult_of(recipe: Dictionary) -> float:
	if current_eat_mult > 0.0:
		return current_eat_mult
	return float(recipe.get("eat_mult", 1.0))


## HASTÍO Y VARIEDAD: la recarga de paciencia del plato que acaba de coger
## (`current_id` / `current_satiety` / `current_extras`). Reglas:
##  - PICOTEO y POSTRE ni suman ni rompen: el picoteo es un aperitivo y el
##    postre es la cuenta, no un plato del menú. El té verde (clears_boredom)
##    además limpia el PALADAR (historial a cero) SIN tocar la racha: se
##    sigue combinando desde donde se iba.
##  - Plato NUNCA PROBADO (o repetido CON JENGIBRE, que cuenta como nuevo y
##    esquiva la escalera): la racha crece y recarga cada vez más.
##  - Plato REPETIDO: rompe la racha a cero y sube la escalera del hastío
##    (recarga ×0.2, ×0.1, nada, y de la 4ª en adelante DRENA la barra).
## Un plato nunca probado siempre reconstruye la racha tras una rotura; cuando
## el cliente ya lo ha probado todo, las únicas salidas son el té (reinicia el
## arco) o el jengibre (un repetido concreto cuenta como nuevo).
## "Paladar generoso": cuántas VECES puede comerse un plato contando como
## nuevo para ESTE cliente. 1 = lo normal (solo la primera vez); el rango sube
## la tolerancia — I el primer plato del cliente, II los de 1★, III los de
## 1★ y 2★, IV todos, V todos y dos veces los de 1★. `tried` guarda por eso
## CONTADORES, no banderas: cuántas veces se ha comido cada plato.
func _tolerancia(recipe_id: String, satiety: int) -> int:
	var extra := 0
	match paladar_rank:
		1: extra = 1 if recipe_id == _primer_plato else 0
		2: extra = 1 if satiety <= 1 else 0
		3: extra = 1 if satiety <= 2 else 0
		4: extra = 1
		5: extra = 2 if satiety <= 1 else 1
	return 1 + extra


## ¿Este plato todavía cuenta como NUEVO para este cliente?
func _es_nuevo(recipe_id: String, satiety: int) -> bool:
	return int(tried.get(recipe_id, 0)) < _tolerancia(recipe_id, satiety)


func _apply_meal_patience(recipe: Dictionary) -> void:
	var base: float = PATIENCE_FOOD.get(current_satiety, 0.12) \
		* float(recipe.get("patience_mult", 1.0))
	if _primer_plato == "":
		_primer_plato = current_id
	# SUSHI RUSH: la cadena se cuenta AQUI, antes de que las ramas de abajo
	# muten `tried` — un plato "nuevo" alarga la cadena y un repetido la rompe.
	# Los picoteos, los postres y un extra puesto nunca la rompen.
	if level_ref != null and level_ref.has_method("note_rush_plate"):
		level_ref.note_rush_plate(_es_nuevo(current_id, current_satiety)
			or recipe.get("leaves_seat", false) or recipe.get("snack", false)
			or not current_extras.is_empty())
	if recipe.get("leaves_seat", false) or recipe.get("snack", false):
		if recipe.get("clears_boredom", false):
			_limpiar_paladar()
		# El sunomono ("variety_snack") es el único picoteo que SUMA racha; ver
		# `_eat_snack`, que es la otra puerta por la que entra un picoteo.
		if recipe.get("variety_snack", false) and not tried.has(current_id):
			current_price += variety
			tried[current_id] = int(tried.get(current_id, 0)) + 1
			_set_variety(variety + 1, true)
		patience = minf(patience + base * skill_recharge * patience_max,
			patience_max)
	elif recipe.get("clears_boredom", false):
		# PLATO QUE LIMPIA EL PALADAR sin ser picoteo (la sopa de miso): borra el
		# historial —todo vuelve a contar como nuevo— pero NO toca la racha: ni
		# la sube ni la rompe. Recarga como un plato normal de su nivel.
		_limpiar_paladar()
		patience = minf(patience + base * skill_recharge * patience_max,
			patience_max)
	elif _es_nuevo(current_id, current_satiety) or not current_extras.is_empty():
		# BONO DEL MULTIPLICADOR: cada plato nuevo paga su precio + 1 doblón
		# por punto del multiplicador VIGENTE (el de la chapa al cogerlo: con
		# un x4 puesto, un plato de $3 deja $7). Los repetidos no cobran extra
		# y el postre cobra por su propio canal (la propina × mult).
		# CUALQUIER EXTRA mete el plato por esta rama aunque esté repetido: es
		# lo que hace que los extras valgan 10 doblones el uso.
		current_price += variety
		if "jengibre" in current_extras:
			# El jengibre limpia el paladar ENTERO, este plato incluido: a
			# partir de aquí todo vuelve a contar como nuevo.
			#
			# EL PUNTO DE MULTIPLICADOR SOLO SE COBRA SI EL JENGIBRE HACÍA
			# FALTA, o sea si el plato venía REPETIDO y es el jengibre quien lo
			# ha colado como nuevo. Se cobraba siempre, y eso convertía en
			# CASTIGO echarle jengibre a un plato que el cliente aún no había
			# probado: pagabas 10 doblones y un punto de chapa a cambio de
			# nada, y desde fuera se leía como "el jengibre no funciona".
			var hacia_falta := not _es_nuevo(current_id, current_satiety)
			_limpiar_paladar()
			# EL PLATO QUE SE ESTÁ COMIENDO SÍ QUEDA APUNTADO. El jengibre
			# limpia todo lo DEMÁS: acaba de tragárselo, difícilmente se le ha
			# olvidado. Estuvo dejando el paladar completamente vacío, y eso
			# abría un agujero — con la lista en blanco, el SIGUIENTE plato con
			# jengibre volvía a contar como nuevo, así que encadenar jengibre
			# sobre UNA sola receta subía la chapa hasta el tope (medido: x1,
			# x2, x3, x4, x5 con el mismo maki). Marcándolo, el jengibre sirve
			# para volver a servir el RESTO de la carta, que es su oficio.
			tried[current_id] = 1
			if hacia_falta:
				_set_variety(maxi(variety - 1, 0), false)
			else:
				# No hacía falta: el plato cuenta como el plato nuevo que era y
				# la racha sigue subiendo, con el paladar limpio de regalo.
				_set_variety(variety + 1, true)
		else:
			tried[current_id] = int(tried.get(current_id, 0)) + 1
			# El barco combinado vale DOBLE ("variety_worth"): es la bandeja
			# de la variedad, sumarlo como un plato más le quitaba la gracia.
			_set_variety(variety + int(recipe.get("variety_worth", 1)), true)
		var combo := 1.0 if variety <= 1 \
			else 1.0 + VARIETY_RECHARGE_STEP * variety
		var delta := base * combo * patience_max
		if "wasabi" in current_extras:
			# El wasabi pica: en vez de recargar, quita lo que habría recargado
			# (SIN la maestría: el "Buen anfitrión" no engorda castigos).
			patience = maxf(patience - delta, 0.0)
		else:
			patience = minf(patience + delta * skill_recharge, patience_max)
	else:
		repeat_count += 1
		_set_variety(0, false)
		if repeat_count <= REPEAT_RECHARGE.size():
			patience = minf(patience + base * REPEAT_RECHARGE[repeat_count - 1] \
				* patience_max, patience_max)
		else:
			var drain := minf(REPEAT_DRAIN_STEP * (repeat_count - REPEAT_RECHARGE.size()),
				REPEAT_DRAIN_MAX)
			patience = maxf(patience - drain * patience_max, 0.0)
	# "Golpe de suerte": el plato venía marcado y sube un punto extra al que lo
	# coge (en un postre no: el cliente se va y no queda racha que subir).
	if current_lucky and not recipe.get("leaves_seat", false):
		current_lucky = false
		_set_variety(variety + 1, true)
	_push_bubble_icon(current_id, not current_extras.is_empty())


## Cambia el multiplicador y refresca su chapa. A partir de x2 entra la
## moneda del valor (mult_x2..mult_x5) con un golpe y un giro si sube; al
## romperse la racha, se encoge y se apaga. La chapa vive DENTRO del bocadillo
## (se crea con él): siempre por encima y atenuada a su compás.
## Tope vigente del multiplicador: el base, el del bonificador "Paladar de
## capitán" si está puesto, y otro ×2 mientras corra "Doble variedad".
func variety_cap() -> int:
	# Con el bonificador puesto manda SU NIVEL de mejora (x6 el nivel 1, x10 el
	# 5); sin él, el tope base de siempre.
	var tope := int(GameState.perk_value("paladar")) if GameState.has_perk("paladar") \
			else VARIETY_MAX
	if level_ref != null and "variety_x2_timer" in level_ref \
			and level_ref.variety_x2_timer > 0.0:
		tope *= 2
	return tope


## PALADAR LIMPIO: todo vuelve a contar como nuevo. Borra el historial de
## platos Y LA ESCALERA DEL HASTÍO, que es lo que se dejaba fuera.
##
## `repeat_count` solo subía y no lo reiniciaba nadie, así que "limpiar el
## paladar" era media limpieza: el cliente olvidaba QUÉ había comido, pero
## seguía contando CUÁNTAS veces le habían repetido, y la primera repetición
## después del jengibre caía en el peldaño siguiente de la escalera — con la
## escalera ya arriba, DRENANDO la barra. Pagar 10 doblones y un punto de
## multiplicador por un paladar limpio y que el siguiente repetido castigara
## igual que antes es justo lo que se veía como "el jengibre no ajusta bien".
## Lo usan las tres cosas que limpian: el té verde, la sopa de miso y el
## jengibre.
func _limpiar_paladar() -> void:
	tried.clear()
	repeat_count = 0


func _set_variety(n: int, pop: bool) -> void:
	var prev := variety
	variety = mini(n, variety_cap())
	# Aviso al nivel la PRIMERA vez que este cliente toca el tope base: es la
	# condición del bonificador "Paladar de capitán".
	if not _variety_maxed and variety >= VARIETY_MAX:
		_variety_maxed = true
		if level_ref != null and level_ref.has_method("note_variety_maxed"):
			level_ref.note_variety_maxed()
	if _mult_badge == null or not is_instance_valid(_mult_badge):
		return
	# Un tween de chapa a medias siempre pierde contra el valor nuevo.
	if _badge_tween != null and _badge_tween.is_valid():
		_badge_tween.kill()
	if variety >= 2:
		var n_chapa := clampi(variety, MULT_FIRST, MULT_LAST)
		_mult_badge.texture = load("res://assets/ui/mult_x%d.png" % n_chapa)
		_mult_badge.visible = true
		_mult_badge.modulate = Color(1, 1, 1, 1)
		_place_badge()
		_mult_badge.scale = Vector2.ONE
		if pop and variety != prev:
			_mult_badge.scale = Vector2(1.7, 1.7)
			_mult_badge.rotation = deg_to_rad(-16.0)
			var tw := _mult_badge.create_tween().set_parallel(true)
			_badge_tween = tw
			tw.tween_property(_mult_badge, "scale", Vector2.ONE, 0.32) 				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(_mult_badge, "rotation", 0.0, 0.32) 				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif prev >= 2:
		# Racha rota: la chapa se encoge y desaparece.
		var tw := _mult_badge.create_tween().set_parallel(true)
		_badge_tween = tw
		tw.tween_property(_mult_badge, "scale", Vector2(0.15, 0.15), 0.24) 			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(_mult_badge, "modulate:a", 0.0, 0.24)
		tw.chain().tween_callback(func() -> void:
			_mult_badge.visible = false
			_mult_badge.scale = Vector2.ONE)
	else:
		_mult_badge.visible = false


## La chapa cabalga la esquina INFERIOR EXTERIOR del bocadillo, medio dentro
## medio fuera, al estilo cómic. ABAJO y no arriba: arriba están la cola, la
## cabeza y la franja de barras, y ahí la chapa acababa por debajo de la barra
## de paciencia del cliente de al lado y no se veía.
func _place_badge() -> void:
	if _bubble == null or not is_instance_valid(_bubble) 			or _mult_badge == null or not is_instance_valid(_mult_badge):
		return
	var w := _bubble_width(_bubble_icons.size())
	var y := BUBBLE_H - MULT_BADGE * 0.55
	if _bubble_left:
		_mult_badge.position = Vector2(-MULT_BADGE * 0.45, y)
	else:
		_mult_badge.position = Vector2(w - MULT_BADGE * 0.55, y)


## Mete un plato en el bocadillo. El bocadillo es PERMANENTE y HORIZONTAL:
## nace con el primer plato hacia el lado exterior del cliente, y cada plato
## nuevo entra por la DERECHA entero y por encima, dejando de los anteriores
## una franja asomando por la izquierda. Lleno (BUBBLE_MAX), el más viejo se
## despide por la izquierda. Los destinos de los iconos son ABSOLUTOS por
## antigüedad: dos empujones muy seguidos con desplazamientos relativos
## dejaban dos iconos montados en la misma casilla.
func _push_bubble_icon(recipe_id: String, con_extra: bool) -> void:
	var ui := _world_ui()
	if ui == null or not variety_ui:
		return
	if _bubble == null or not is_instance_valid(_bubble):
		# El lado se decide UNA vez, con la pantalla partida por la mitad: el
		# centro del circuito cae en el centro del lienzo, así que media
		# pantalla izquierda = silla del lado izquierdo = bocadillo hacia fuera.
		_bubble_left = _head_anchor().x < get_viewport().get_visible_rect().size.x * 0.5
		_bubble = NinePatchRect.new()
		_bubble.texture = load(BUBBLE_TEX_ESP if _bubble_left else BUBBLE_TEX)
		# Márgenes medidos sobre bocadillo.png (147x62): la COLA ocupa las
		# filas y 0-9 de la esquina superior izquierda (espejada en _esp), así
		# que el margen de arriba la protege entera del estirado.
		_bubble.patch_margin_left = 36 if not _bubble_left else 16
		_bubble.patch_margin_right = 16 if not _bubble_left else 36
		_bubble.patch_margin_top = 20
		_bubble.patch_margin_bottom = 14
		_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bubble.size = Vector2(_bubble_width(1), BUBBLE_H)
		_bubble.position = _bubble_pos(_bubble.size.x)
		ui.add_child(_bubble)
		# La chapa del multiplicador nace con el bocadillo, como hija suya.
		_mult_badge = TextureRect.new()
		_mult_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_mult_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_mult_badge.size = Vector2(MULT_BADGE, MULT_BADGE)
		_mult_badge.pivot_offset = Vector2(MULT_BADGE, MULT_BADGE) * 0.5
		_mult_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mult_badge.visible = false
		_bubble.add_child(_mult_badge)
		# La chapa nace DESPUÉS de que _apply_meal_patience haya movido el
		# multiplicador (el bocadillo se crea con el primer plato, y para
		# entonces _set_variety ya se ha llamado con la chapa a null y ha
		# salido por la puerta de atrás). Se sincroniza aquí o un primer
		# plato que ya valga x2 —el BARCO, que suma 2 de golpe— dejaba la
		# chapa invisible hasta el plato siguiente.
		_set_variety(variety, false)
	# Lleno: el más viejo se despide por la IZQUIERDA.
	if _bubble_icons.size() >= BUBBLE_MAX:
		var viejo: Control = _bubble_icons.pop_back()
		if is_instance_valid(viejo):
			var twv := create_tween().set_parallel(true)
			twv.tween_property(viejo, "position:x", viejo.position.x - 14.0, 0.16)
			twv.tween_property(viejo, "modulate:a", 0.0, 0.16)
			twv.chain().tween_callback(viejo.queue_free)
	# El nuevo entra por la DERECHA, entero y por encima de los demás (se añade
	# el último al árbol, así que se dibuja encima).
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = RecipeData.get_dish_texture(recipe_id)
	icon.size = Vector2(BUBBLE_ICON, BUBBLE_ICON)
	icon.pivot_offset = Vector2(BUBBLE_ICON, BUBBLE_ICON) * 0.5
	icon.scale = Vector2(0.2, 0.2)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(icon)
	if con_extra:
		_add_sparkle(icon)
	_bubble_icons.push_front(icon)
	var n := _bubble_icons.size()
	icon.position = _icon_pos(0, n)
	icon.create_tween().tween_property(icon, "scale", Vector2.ONE, 0.24) 		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# El cuerpo se estira hacia el lado exterior y cada plato baja a la casilla
	# de su antigüedad, con destino ABSOLUTO.
	var w := _bubble_width(n)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_bubble, "size:x", w, 0.18)
	tw.tween_property(_bubble, "position:x", _bubble_pos(w).x, 0.18)
	for k in range(1, _bubble_icons.size()):
		var nodo: Control = _bubble_icons[k]
		if is_instance_valid(nodo):
			nodo.create_tween().tween_property(nodo, "position:x",
				_icon_pos(k, n).x, 0.18)
	_place_badge()
	_wake_bubble()


## Plena luz un par de segundos tras coger un plato, y de vuelta a media luz:
## ocho bocadillos permanentes a plena luz eran ocho manchas blancas.
func _wake_bubble() -> void:
	if _dim_tween != null and _dim_tween.is_valid():
		_dim_tween.kill()
	_bubble.modulate.a = 1.0
	_dim_tween = create_tween()
	_dim_tween.tween_interval(BUBBLE_HOT)
	_dim_tween.tween_property(_bubble, "modulate:a", BUBBLE_DIM, 0.45)

## Destellos sobre el icono de un plato que llevó extra: dos estrellitas que
## laten en las esquinas del icono.
func _add_sparkle(icon: Control) -> void:
	# UNA estrella, en la esquina superior IZQUIERDA a propósito: es la franja
	# que sigue asomando cuando el plato siguiente se solapa encima. Con dos
	# (una en cada esquina) el plato de arriba tapaba a veces la derecha y los
	# extras parecían tener unas veces una estrella y otras dos.
	var s := TextureRect.new()
	s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	s.texture = load("res://assets/ui/estrella_llena.png")
	s.size = Vector2(11, 11)
	s.position = Vector2(-4, -4)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_child(s)
	var tw := s.create_tween().set_loops()
	tw.tween_property(s, "modulate:a", 0.35, 0.4)
	tw.tween_property(s, "modulate:a", 1.0, 0.4)


func _stop_eating_anim() -> void:
	if _held_dish != null:
		_held_dish.queue_free()
		_held_dish = null


func _aroma_active() -> bool:
	return level_ref != null and "aroma_active" in level_ref and level_ref.aroma_active


func _time_frozen() -> bool:
	return level_ref != null and "frozen" in level_ref and level_ref.frozen


## Sin saciedad objetivo: el cliente NUNCA se va por comer; vuelve a esperar.
## El pago del plato y su posible propina se abonan al nivel AQUI mismo.
func _finish_plate() -> void:
	satiety_eaten += current_satiety
	money_earned += current_price
	eaten_ids.append(current_id)
	# COLECCIONABLE "sombrero de paja": los platos que come el grumete del
	# sombrero se cuentan de por vida; a 20, GameState suelta el coleccionable.
	if who_override == "grumete_sombrero":
		GameState.bump_stat("fed_sombrero")
	var tip := _roll_plate_tip()
	tips_earned += tip
	plate_served.emit(current_price, tip)
	_float_text("+$%d" % current_price, Color(1.0, 0.86, 0.2))
	if tip > 0:
		_float_text("+$%d" % tip, Color(0.4, 1.0, 0.45), -50.0)
	var recipe := RecipeData.get_recipe(current_id)
	# "patience_freeze": la barra se queda QUIETA unos segundos (unagi). Como
	# el cliente puede coger otro plato mientras tanto, la espera le sale
	# gratis; es lo que hace que rente un plato que se come en un suspiro.
	patience_frozen = maxf(patience_frozen,
		float(recipe.get("patience_freeze", 0.0)))
	# "next_take_bonus" (la caballa): el siguiente plato que le pase tira el
	# dado con este bono, hasta que coja uno.
	if float(recipe.get("next_take_bonus", 0.0)) > 0.0:
		next_take_bonus = float(recipe.get("next_take_bonus", 0.0))
	_stop_eating_anim()
	_eat_bar.visible = false
	# "leaves_seat": los postres despiden al cliente COBRANDO su multiplicador
	# de variedad: VARIETY_TIP_PER_STEP doblones por punto, al bote. Se cobra
	# el multiplicador VIGENTE, no el más alto alcanzado — si la racha se
	# rompió, se perdió: el postre es un aliciente, no un premio decisivo.
	if recipe.get("leaves_seat", false):
		var bonus := VARIETY_TIP_PER_STEP * variety
		# Potenciador "Sobremesa dulce": el próximo postre cobra el DOBLE. Solo
		# se consume si de verdad había multiplicador que cobrar — gastarlo en
		# un postre a cero sería tirar el potenciador. La mejora del arcade
		# ("los postres cobran doble") es lo mismo pero PERMANENTE, y con ella
		# puesta el potenciador de un solo uso no se consume.
		if bonus > 0 and level_ref != null:
			var perm: bool = "dessert_boost_perm" in level_ref \
					and level_ref.dessert_boost_perm
			var una: bool = "dessert_boost" in level_ref and level_ref.dessert_boost
			if perm or una:
				if una and not perm:
					level_ref.dessert_boost = false
				bonus *= 2
		if bonus > 0:
			tips_earned += bonus
			# La propina va SOLO al bote, igual que el resto (contrato de
			# plate_served): dinero 0, propina el extra.
			plate_served.emit(0, bonus)
			_float_text("+$%d  x%d" % [bonus, variety], Color(0.4, 1.0, 0.45), -95.0)
		_leave()
		return
	# El nivel se acabo mientras comia: ya ha cobrado este plato, ahora se va.
	if _leave_when_done:
		_leave()
		return
	state = State.WAITING
	_patience_bar.visible = true


## Texto flotante que PARPADEA sobre el cliente y sube desvaneciendose, en el
## CanvasLayer world_ui del nivel (la camara es fija: se ancla una vez).
func _float_text(text: String, color: Color, y_offset: float = 0.0,
		con_moneda := false) -> void:
	var ui := _world_ui()
	if ui == null:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(140, 0)
	lbl.position = _head_screen() + Vector2(-70, -30.0 + y_offset)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 34)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	lbl.add_theme_constant_override("outline_size", 7)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.pivot_offset = Vector2(70, 18)
	# Las cifras de dinero llevan la moneda del juego, nunca el símbolo del dólar.
	if con_moneda:
		var coin := TextureRect.new()
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.texture = load("res://assets/ui/moneda.png")
		coin.size = Vector2(26, 26)
		coin.position = Vector2(88, 6)
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_child(coin)
	ui.add_child(lbl)
	lbl.scale = Vector2(0.5, 0.5)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in 2:
		tw.tween_property(lbl, "modulate:a", 0.25, 0.09)
		tw.tween_property(lbl, "modulate:a", 1.0, 0.09)
	tw.tween_property(lbl, "position:y", lbl.position.y - 66.0, 0.7) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.tween_callback(lbl.queue_free)


## Desalojo por fin de nivel. Si le pilla COMIENDO no se levanta a medias:
## termina su plato (y lo paga) y se marcha justo despues; el nivel espera.
## Desalojo por fin de nivel. `cobrar` a false perdona el castigo de irse de
## vacío: se usa cuando el turno se cierra porque YA se alcanzó el dinero
## objetivo, y sería absurdo penalizar por los clientes que sobraban.
func force_leave(cobrar := true) -> void:
	_sin_castigo = not cobrar
	if state == State.EATING:
		_leave_when_done = true
		return
	_leave()


## true si un cliente esta terminando su ultimo bocado tras el fin del nivel.
func is_finishing_bite() -> bool:
	return _leave_when_done and state == State.EATING


func _leave() -> void:
	if state == State.DONE or state == State.LEAVING:
		return
	_stop_eating_anim()
	# Irse sin haber probado NADA cuesta dinero, tanto si se le agoto la
	# paciencia como si le pillo el final del nivel. Y ESCALA: cada cliente que
	# ya se fue de vacío en esta partida encarece al siguiente (ver
	# EMPTY_LEAVE_STEP). El "-$N" flotante enseña la cifra creciente, así que
	# la escalada se comunica sola.
	# El VACÍO (irse sin probar nada) viaja aparte del castigo en oro: en los
	# puertos y abordajes el oro no se toca pero el vacío SÍ cuenta — para la
	# derrota a los 3 en un puerto y para el robo de reloj en un abordaje.
	var vacio := eaten_ids.is_empty() and not _sin_castigo
	var penalty := 0
	if vacio and penaliza_vacio:
		var esc := 1.0
		if level_ref != null and "empty_leavers" in level_ref:
			esc = minf(1.0 + EMPTY_LEAVE_STEP * float(level_ref.empty_leavers),
				EMPTY_LEAVE_CAP)
		penalty = int(round(int(LEAVE_PENALTY.get(client_type, 0)) * esc
			* leave_penalty_mult))
		if penalty > 0:
			_float_text("-%d" % penalty, Color(1.0, 0.34, 0.28), 0.0, true)
	finished.emit({
		"type": client_type,
		"money": money_earned,
		"tip": tips_earned,
		"penalty": penalty,
		"vacio": vacio,
		"eaten": eaten_ids.duplicate(),
		"satiety_eaten": satiety_eaten,
	})
	state = State.LEAVING
	_patience_bar.visible = false
	_eat_bar.visible = false
	# El bocadillo y la chapa se despiden con el cliente.
	for nodo in [_bubble, _mult_badge]:
		if nodo != null and is_instance_valid(nodo):
			nodo.create_tween().tween_property(nodo, "modulate:a", 0.0, 0.3)
	_body.position.y = 0.0
	_walk_out()


## Se marcha andando por la ruta inversa hasta la borda.
func _walk_out() -> void:
	var out_points: Array = route.duplicate()
	out_points.reverse()
	if not out_points.is_empty():
		out_points.remove_at(0)  # ya esta en el asiento
	out_points.push_front(position)
	out_points.append(exit_point)
	route = out_points
	_leg = 0
	_leg_dist = 0.0
	_face_leg()


## Propina de UN plato: probabilidad segun TIP_RULES (crece con los platos
## comidos), cuantia = % del dinero ACUMULADO del cliente. Debe llamarse
## DESPUES de sumar current_price a money_earned y del append a eaten_ids.
func _roll_plate_tip() -> int:
	# Niveles-escuela: sin bote de propinas no hay propina que tirar.
	if not tips_enabled:
		return 0
	var rules: Dictionary = TIP_RULES.get(client_type, {})
	var plates := eaten_ids.size()
	if rules.is_empty() or plates < int(rules.start):
		return 0
	var ramp: int = int(rules.get("ramp", rules.start))
	var extra_steps := maxi(plates - ramp, 0) / int(rules.every)
	var tip_chance: float = minf(float(rules.base) + float(rules.step) * extra_steps, float(rules.max))
	var amount_mult := 1.0
	if level_ref != null:
		if "tip_chance_bonus" in level_ref:
			tip_chance += level_ref.tip_chance_bonus
		if "tip_amount_mult" in level_ref:
			amount_mult = level_ref.tip_amount_mult
	# "tip_amount_mult" de la RECETA recién comida: el fugu no hace la propina
	# más probable, pero cuando cae es un 15% más gorda.
	amount_mult *= float(RecipeData.get_recipe(current_id).get("tip_amount_mult", 1.0))
	# EXTRAS de este plato: el wasabi hace la propina más PROBABLE y la soja
	# la hace más GORDA.
	if "wasabi" in current_extras:
		tip_chance += RecipeData.EXTRA_TIP_CHANCE
	if "soja" in current_extras:
		amount_mult *= RecipeData.EXTRA_TIP_AMOUNT
	# Bono por platos especiales (recetas con "tip_chance_bonus"): entero la 1ª
	# vez, y cada repeticion del MISMO plato suma la mitad que la anterior.
	var seen := {}
	for id in eaten_ids:
		var rb: float = RecipeData.get_recipe(id).get("tip_chance_bonus", 0.0)
		if rb <= 0.0:
			continue
		var n: int = seen.get(id, 0)
		tip_chance += rb * pow(0.5, n)
		seen[id] = n + 1
	# "Buena cara" (maestría): puntos de probabilidad extra, RESPETANDO el tope
	# del tipo — solo empuja hasta el máximo de la tabla; lo que ya estuviera
	# por encima (wasabi, potenciador) se queda como estaba.
	if skill_tip_chance > 0.0:
		tip_chance = minf(tip_chance + skill_tip_chance,
			maxf(tip_chance, float(rules.max)))
	# "Mano suelta" (maestría): las propinas que caen son más gordas.
	amount_mult *= skill_tip_amount
	# "tip_always": los postres SIEMPRE dejan propina (aunque sea 1 doblón).
	# Es lo que compensa que valgan tan poco: el dinero lo dan por el bote, no
	# por el precio.
	if RecipeData.get_recipe(current_id).get("tip_always", false):
		tip_chance = 1.0
	# El JEFE deja propina de uvas a peras (ver BOSS_TIP_MULT).
	if boss:
		tip_chance *= BOSS_TIP_MULT
	if randf() < tip_chance:
		return maxi(int(round(money_earned * float(rules.pct) * amount_mult)), 1)
	return 0
