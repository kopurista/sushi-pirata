extends Node
## DIRECTOR DE AUDIO del juego (autoload `Audio`). Un solo sitio del que
## cuelgan la música, el ambiente, los efectos y las voces, para que ninguna
## pantalla tenga que saber por dónde suena nada.
##
## TRES BUSES, y se crean AQUÍ por código en vez de en un
## `default_bus_layout.tres`: el layout es un recurso binario que no se puede
## leer ni versionar en condiciones, y esto son nueve líneas que además
## documentan solas para qué es cada bus. `Musica` / `Efectos` / `Voces`
## cuelgan de Master y los mueve el jugador desde Opciones.
##
## EL AMBIENTE VA POR `Efectos`, NO POR `Musica`: la portada no tiene música
## —solo el mar, que fue una decisión de diseño— así que colgándolo del bus de
## la música, bajarla a cero dejaba la portada en silencio absoluto.
##
## VARIEDAD SOLO DONDE HACE FALTA, y esto se aprendió a base de rehacerlo. La
## COCINA sortea toma sin repetir la anterior y le mueve el tono (`VARIAN`,
## `VAIVEN`): ahí el jugador repite el mismo gesto decenas de veces por partida
## y la toma idéntica se delata. La INTERFAZ hace lo CONTRARIO: un sonido por
## PAPEL —volver, aceptar, cambiar de pantalla, zarpar, botón corriente— y
## siempre el mismo. Un botón no es un gesto que busque variedad: es una
## respuesta, y una respuesta que suena distinta cada vez se lee como que el
## juego está haciendo cosas distintas.

const SoundBankCls := preload("res://scripts/sound_bank.gd")

const BUS_MUSICA := "Musica"
const BUS_EFECTOS := "Efectos"
const BUS_VOCES := "Voces"

# --------------------------------------------------------------- MÚSICA

## Los ocho temas del juego. El MENÚ y el MAPA de aventura comparten el suyo
## (son la misma escena y el mismo momento: estar en casa preparando el
## viaje); la tienda, el arcade y la pesca tienen el suyo, y los niveles uno
## por TIPO de escenario. La cueva es el tema del jefe.
const TEMAS := {
	"menu": "res://sounds/juego/musica/menu.ogg",
	"tienda": "res://sounds/juego/musica/tienda.ogg",
	"arcade": "res://sounds/juego/musica/arcade.ogg",
	"pesca": "res://sounds/juego/musica/pesca.ogg",
	"isla": "res://sounds/juego/musica/isla.ogg",
	"puerto": "res://sounds/juego/musica/puerto.ogg",
	"abordaje": "res://sounds/juego/musica/abordaje.ogg",
	"cueva": "res://sounds/juego/musica/cueva.ogg",
	# La INTRO DEL CAOS tiene el suyo. Estuvo sonando a abordaje —una cubierta
	# desbordada contra el reloj— y no es lo mismo: allí el jugador pelea y
	# aquí PIERDE, a propósito y sin saber por qué. Su tema va acelerado y
	# cómico, de pánico de cocina.
	"tutorial": "res://sounds/juego/musica/tutorial.ogg",
	# El cartel de fin de jornada. No es un SITIO sino un MOMENTO, y por
	# eso es el único tema que no lo pone una pantalla al montarse: lo
	# pide `level3d._show_results` y lo releva la pantalla siguiente.
	"resultados": "res://sounds/juego/musica/resultados.ogg",
}

## LOS TEMAS QUE DAN LA VUELTA SOLOS. Sus .ogg están COSIDOS para repetirse
## (`tools/musica_bucle.py`: se busca el punto donde la música vuelve a sonar
## como al principio, se corta ahí y se envuelve la cabeza con su propia
## continuación), así que el bucle lo lleva el MOTOR —`loop=true` en su
## `.import`— y no cuesta nada.
##
## ESTO SUSTITUYE AL CRUCE DEL TEMA CONSIGO MISMO, que era lo que había antes
## y sigue abajo como red para cualquier tema sin bucle preparado. Aquel
## escondía el corte, sí, pero MEZCLABA dos segundos de compases que no se
## corresponden: cada vuelta sonaba emborronada. Un tema cosido no necesita
## que le tapen nada.
const TEMAS_BUCLE := {
	"menu": true, "tienda": true, "arcade": true, "pesca": true,
	"isla": true, "puerto": true, "abordaje": true, "cueva": true,
	"tutorial": true,
}

## Y EL QUE TIENE FINAL DE VERDAD. El de resultados es una pieza cerrada: sube,
## se recrea y termina con su acorde apagándose. No se cruza consigo mismo —el
## cruce se comería justo el cierre, que es lo que lo hace sonar a jornada
## terminada— ni se le pone el `loop` del motor: se deja sonar entero y se
## vuelve a empezar, con el silencio que trae detrás haciendo de respiro.
const TEMAS_FINAL := {
	"resultados": true,
}

const AMBIENTES := {
	"mar": "res://sounds/juego/barco/ocean.ogg",
}

## Volumen de referencia de la música, en dB sobre su bus. Va POR DEBAJO de
## los efectos a propósito: la música es el fondo y lo que el jugador tiene
## que oír para jugar son los avisos de la barra y la cocina.
## Nivel de referencia al que se lleva TODO el audio del juego, medido en
## sonoridad ponderada K. Es la mediana de lo que había, así que la mitad de
## los sonidos suben y la otra mitad bajan y ninguno tiene que estirarse tanto
## como para recortar.
const NIVEL := -21.0

## LO QUE SE LE SUMA A CADA TEMA para que los diez suenen igual de fuertes.
## Medido, no elegido (ver la cabecera de `VOL`): entre la cueva y el menú
## había 7 dB de diferencia, y eso se oye como que el juego sube y baja de
## volumen al cambiar de pantalla.
const TEMAS_DB := {
	"abordaje": 0.7, "arcade": -0.8, "cueva": -5.1,
	"isla": 2.4, "menu": -2.6, "pesca": 2.1,
	"puerto": 0.7, "resultados": -1.9, "tienda": 1.0,
	"tutorial": -1.6,
}

const MUS_DB := -7.0
const AMB_DB := 6.8

## Segundos de cruce entre dos temas, y del tema consigo mismo al dar la
## vuelta (ver `_bucle_musica`).
const CRUCE := 1.6
const CRUCE_BUCLE := 2.2

## Con lo que ENTRA un tema que tiene final (hoy el de resultados), tanto la
## primera vez como cada vez que vuelve a empezar. Un tema en bucle puede
## entrar de golpe —no tiene principio, es un lazo—, pero uno que acaba de
## apagarse con su acorde y arranca otra vez a plena fuerza se oye como un
## pinchazo. Pedido por el usuario: "como es una canción que tiene fin, que
## inicie con una transición".
const CRUCE_FINAL := 1.4

# -------------------------------------------------------------- EFECTOS

## Las familias de efectos. Cada una es un puñado de tomas del MISMO sonido y
## `SoundBank` elige una sin repetir la anterior.
##
## LAS RUTAS SE ESCRIBEN A MANO, NUNCA se escanea la carpeta con DirAccess:
## los .ogg se importan a `.godot/imported/*.oggvorbisstr` y en el EXPORT los
## originales no están, así que un escaneo funcionaría en el editor y
## devolvería una lista VACÍA en el juego publicado.
const IF_ := "res://sounds/juego/interfaz/"
const CO_ := "res://sounds/juego/cocina/"
const NI_ := "res://sounds/juego/nivel/"
## EL BARCO Y EL MAR tienen seccion propia: no son avisos de la jornada,
## son el mundo que hay alrededor.
const BA_ := "res://sounds/juego/barco/"

const FAMILIAS := {
	# --- INTERFAZ: UN SONIDO POR PAPEL, y siempre EL MISMO -----------------
	#
	# Aquí no hay sorteo ni vaivén de tono a propósito, al revés que en la
	# cocina. Un botón no es un gesto que se repita cien veces buscando
	# variedad: es una respuesta, y una respuesta que suena distinta cada vez
	# se lee como que el juego hace cosas distintas. Lo que tiene que
	# distinguirse es el PAPEL del botón, no la pulsación.
	#
	# Los cinco papeles: volver o cancelar, aceptar, cambiar de pantalla,
	# arrancar la jornada, y el botón corriente. Cada uno con su toma, y todos
	# los botones de un mismo papel suenan igual entre sí.
	"click": [IF_ + "Click - 1.ogg"],
	# VOLVER es el MISMO clic que el resto con el tono bajado (ver
	# `TONO`): es la misma acción de interfaz, no otra cosa, y basta con
	# eso para que el oído la reconozca sin meter un sonido nuevo.
	"atras": [IF_ + "Click - 1.ogg"],
	"ok": [IF_ + "recurso.ogg"],
	"pantalla": [IF_ + "Open Map - Menu 1.ogg"],
	# Los CUATRO pergaminos de modo: Aventura, Arcade, Pesca y Tienda.
	"modo": [IF_ + "modo.ogg"],
	# Los CINCO accesos de la barra de abajo (logros, inventario,
	# perfil, bonificadores y opciones).
	"submenu": [IF_ + "submenu.ogg"],
	# Las cajas de RECURSO de arriba (lingotes, doblones, arroz) y la
	# barra de nivel que lleva a Maestrías. Al CERRAR sus ventanas suena
	# la misma toma con el tono bajado.
	"recurso": [IF_ + "recurso.ogg"],
	"recurso_off": [IF_ + "recurso.ogg"],
	"recurso_ok": [IF_ + "recurso.ogg"],
	# EL TIMÓN SOLO SUENA POR MANGOS: un chasquido de mecanismo cada vez
	# que uno pasa por arriba. Hubo además un CRUJIDO continuo mientras se
	# giraba y el usuario lo quitó: sobre el crujido del casco, que ya
	# suena de fondo por su cuenta, eran dos maderas quejándose a la vez.
	"timon": [IF_ + "timon.ogg"],
	# ZARPAR son las CAMPANAS del barco, no un "confirmar" de interfaz.
	"zarpar": [BA_ + "campanas.ogg"],
	# EL AVISO DE ALGO BLOQUEADO: la misma pareja de ventana, un pelo mas
	# aguda al abrirse y mas grave al cerrarse (ver `TONO`).
	"aviso": [IF_ + "aviso_abre.ogg"],
	"aviso_off": [IF_ + "aviso_cierra.ogg"],
	"corte_mal": [IF_ + "corte_mal.ogg"],
	# --- premios y dinero -------------------------------------------------
	"logro": [IF_ + "logro.ogg"],
	# El cliente que PAGA. Va al 85% de velocidad (ver `TONO`).
	"moneda": [NI_ + "pago.ogg"],
	"monedas": [IF_ + "Coins - Small Pile - 1.ogg"],
	"tesoro": [IF_ + "Coins - Large Pile - 1.ogg"],
	# El cobro de TODOS los logros de golpe, al 60% de velocidad.
	"monedas_todo": [IF_ + "monedas_todo.ogg"],
	"premio": [IF_ + "Quest Item Pickup - 1.ogg"],
	# EL COFRE SON DOS SONIDOS A LA VEZ: la cerradura y la tapa.
	"cofre": [IF_ + "cofre.ogg"],
	"cofre_llave": [IF_ + "cofre_llave.ogg"],
	# La barra de experiencia mientras sube: suena SOLO mientras se
	# mueve, y su velocidad se ajusta a lo que tarde (ver `sfx_dura`).
	"exp": [IF_ + "exp.ogg"],
	"levelup": [IF_ + "levelup.ogg"],
	# Habilidad del arbol desbloqueada. La MISMA toma, mas grave, es el
	# cartel de potenciador.
	"habilidad": [IF_ + "habilidad.ogg"],
	# --- COCINA: aquí SÍ se sortea -----------------------------------------
	#
	# Sale de `sounds/soundly` y de `Cozy Craft` (elegido por el usuario a
	# oído, NO re-barajarlo). El amasado son 4 tomas y el corte 9 porque son
	# los gestos que el jugador repite decenas de veces por partida: ahí la
	# variedad es lo que evita que suene a máquina, justo lo contrario que en
	# un botón.
	"arroz": [CO_ + "arroz_1.ogg", CO_ + "arroz_2.ogg", CO_ + "arroz_3.ogg",
		CO_ + "arroz_4.ogg"],
	"corte": [CO_ + "corte_1.ogg", CO_ + "corte_2.ogg", CO_ + "corte_3.ogg",
		CO_ + "corte_4.ogg", CO_ + "corte_5.ogg", CO_ + "corte_6.ogg",
		CO_ + "corte_7.ogg", CO_ + "corte_8.ogg", CO_ + "corte_9.ogg"],
	# El corte LENTO no es un disparo: es un bucle que corre mientras el dedo
	# avanza y se PAUSA en cuanto se para (ver `prep_board._sonido_sostenido`).
	"corte_lento": [CO_ + "corte_lento.ogg"],
	"enrollar": [CO_ + "enrollar_1.ogg", CO_ + "enrollar_2.ogg"],
	"mantener": [CO_ + "mantener.ogg"],
	"remover": [CO_ + "remover.ogg"],
	"freir": [CO_ + "freir.ogg"],
	"soplete": [CO_ + "soplete.ogg"],
	"soltar": [CO_ + "soltar.ogg"],
	# EL PASO COMPLETADO NO SUENA (decidido por el usuario): una receta son
	# hasta seis pasos y un tintineo en cada uno llenaba la elaboración de
	# avisos que no dicen nada.
	"listo": [IF_ + "UI2_Decline_1.ogg"],
	"cinta": [CO_ + "coger.ogg"],
	"quemado": [CO_ + "quemado.ogg"],
	"perfecto": [CO_ + "perfecto.ogg"],
	"basura": [CO_ + "basura.ogg"],
	"guardar": [CO_ + "guardar.ogg"],
	# AGARRAR un plato ya terminado de la tabla.
	"agarrar": [CO_ + "cinta.ogg"],
	# --- el barco y el mar -------------------------------------------------
	"velas": [BA_ + "velas.ogg"],
	"barco_mover": [BA_ + "barco_mover.ogg"],
	"barco_cruje": [BA_ + "barco_cruje.ogg"],
	"gaviota": [BA_ + "gaviota_1.ogg", BA_ + "gaviota_2.ogg"],
	# --- avisos de la jornada ----------------------------------------------
	# LA CAMPANA DE LA JORNADA: suena al acabarse la preparación y al cerrar
	# el turno. Es a propósito que sea la MISMA (pedido por el usuario): el
	# servicio abre y cierra con la misma campana, y lo que no puede sonar
	# igual que esto son las campanas de ZARPAR (que son del barco) ni el
	# botón de "¡Empezar!".
	"fin_turno": [NI_ + "fin_turno.ogg"],
	# EL VIENTO del mar 2: el bucle (su volumen sigue al anemómetro, ver
	# level3d._refresh_viento_hud) y la campanilla del aviso de cambio.
	"viento": [NI_ + "viento.ogg"],
	"viento_alerta": [NI_ + "viento_alerta.ogg"],
	# El CANTO DE SIRENA (mar 2): el bucle del canto y su aviso previo.
	"sirena_canto": [NI_ + "sirena_canto.ogg"],
	"sirena_aviso": [NI_ + "sirena_aviso.ogg"],
	# La del CARTEL de resultados, que suena mas aguda con cada una.
	"estrella": [NI_ + "estrella.ogg"],
	# Las de la BARRA DEL ORO en partida: la 1a y la 2a comparten toma
	# (la primera mas grave) y la 3a tiene la suya.
	"bar_estrella": [NI_ + "bar_estrella.ogg"],
	"bar_estrella3": [NI_ + "bar_estrella3.ogg"],
	"calavera": [NI_ + "calavera.ogg"],
	"potenciador": [IF_ + "habilidad.ogg"],
}

## TONO FIJO de una familia. Es lo que deja que dos papeles compartan la
## MISMA toma y aun así se distingan: "atras" es el clic de siempre más
## grave, y cerrar una ventana de recurso es su propio sonido más grave.
## Bajar el tono lo justo se lee como "lo contrario de lo que acabas de
## hacer" sin añadir un sonido más al juego.
const TONO := {
	"atras": 0.82,
	# LOS GOLPES DEL ARROZ VAN MUY RAPIDOS (pedido por el usuario): las
	# tomas duran 0,3-0,4 s y al ritmo natural el amasado se arrastraba
	# detrás del gesto. Con el tono arriba el golpe es seco y llega con
	# el dedo.
	"arroz": 1.70,
	# LAS VENTANAS EMERGENTES hablan con la MISMA toma a tres alturas:
	# normal al abrirse, GRAVE al cancelar y AGUDA al confirmar. Sin
	# aprenderse nada, el jugador oye si acaba de deshacer o de aceptar.
	"recurso_off": 0.80,
	"recurso_ok": 1.18,
	# El golpe del timón, algo más grave que el clic del que sale.
	"timon": 0.88,
	# El aviso de bloqueado: un pelo mas agudo al abrirse, mas grave al
	# cerrarse.
	"aviso": 1.10,
	"aviso_off": 0.90,
	# El cliente que paga, al 85% de velocidad.
	"moneda": 0.85,
	# El cobro de todos los logros, al 60%.
	"monedas_todo": 0.60,
	# El cartel de potenciador es la MISMA toma que desbloquear una
	# habilidad, mas grave.
	"potenciador": 0.85,
}


## LAS FAMILIAS QUE VARÍAN EL TONO EN CADA DISPARO. Son SOLO las de la cocina,
## que es donde el jugador repite el mismo gesto decenas de veces por partida y
## la toma idéntica se delata. Todo lo demás —botones, ventanas, premios,
## avisos— suena EXACTAMENTE IGUAL siempre: son respuestas del juego, y una
## respuesta que cambia de tono se lee como otra cosa distinta.
## Familias a las que se les mueve el tono un poco en cada disparo. Es de la
## COCINA y de lo que se repite mucho, no de la interfaz: el criterio es
## "¿cuántas veces oye el jugador ESTE sonido en una partida?". Un botón suena
## cuando se pulsa y tiene que sonar igual siempre; un golpe de cuchillo suena
## treinta veces seguidas y la toma idéntica se delata.
## LA MONEDA DEL PAGO entra por lo mismo (pedido por el usuario): es UNA sola
## toma y la oye cada vez que un cliente paga, que en una jornada son docenas.
const VARIAN := ["arroz", "corte", "enrollar", "soltar",
	"cinta", "basura", "moneda"]

## VOLUMEN DE CADA FAMILIA, EN dB, Y TODAS SUENAN IGUAL DE FUERTE.
##
## LOS NÚMEROS NO SE ELIGEN: SE MIDEN (`tools/audio_nivelar.py`). El material
## viene de un pack de foley, otro de interfaz, voces de un tercero y música
## generada, y cada uno trae su nivel: medido, había **38 dB** entre el sonido
## más flojo y el más fuerte. Con eso no hay perilla que valga, porque subir el
## conjunto deja unos a gritos antes de que otros se oigan.
##
## SE MIDE LA SONORIDAD, NO EL PICO. Dos sonidos con el mismo pico suenan muy
## distinto si uno es un golpe seco y el otro un zumbido sostenido, así que se
## usa la sonoridad con PONDERACIÓN K (la de la norma de radio y televisión),
## que pesa cada frecuencia como la oye una persona. Cada familia se lleva a
## `NIVEL`; lo que sale aquí es la diferencia que le hacía falta.
##
## LAS EXCEPCIONES VAN DECLARADAS en `MATIZ` (dentro de la herramienta) y son
## solo dos: el CORTE LENTO, que el usuario pidió de fondo, y los bucles de
## trabajo sostenido (mantener, remover, freír, soplete), que suenan segundos
## seguidos y a la misma altura que un golpe se comen la partida. Todo lo demás
## va plano. Al añadir un sonido, pasar la herramienta: a ojo no se acierta.
## Volumen de cada familia, en dB. Se guarda aquí y no en cada llamada para
## que un sonido no suene a un volumen en una pantalla y a otro en la
## siguiente. Lo que no esté listado va a 0.
##
## LOS DE COCINA VAN MEDIDOS, NO A OJO. Las tomas traen niveles muy distintos
## entre sí —el amasado pica a -30 dBFS y el soplete a 0— así que el mismo
## número dejaba unas inaudibles y otras a gritos. Cada ganancia sale de
## `objetivo - (media + pico)/2`, leídos con `ffmpeg -af volumedetect`: -26
## para los disparos, -32 para los bucles de trabajo y -38 para los que tienen
## que quedar de fondo (corte lento, sartén y soplete). De ahí que el arroz
## SUBA +12 dB y el soplete baje -34.
const VOL := {
	"agarrar": -3.5, "arroz": 23.5, "atras": -0.1,
	"aviso": -4.1, "aviso_off": 1.3, "bar_estrella": 8.8,
	"bar_estrella3": 12.2, "barco_cruje": 14.5, "barco_mover": 18.3,
	"basura": 1.3, "calavera": 4.9, "cinta": -2.2,
	"click": -0.1, "cofre": 6.6, "cofre_llave": 3.4,
	"corte": 5.2, "corte_lento": 0.1, "corte_mal": 2.6,
	"enrollar": 18.7, "estrella": 2.0, "exp": 3.6,
	"fin_turno": -1.4, "freir": -11.7, "gaviota": 1.7,
	# Viento del mar 2: el bucle 6 dB por debajo (suena minutos seguidos) y la
	# campanilla del aviso con -3 de matiz (es sutil a proposito). Medidos con
	# audio_nivelar (LK -26.9 y -14.5).
	"viento": -0.1, "viento_alerta": -9.5,
	"sirena_canto": -8.8, "sirena_aviso": -13.4,
	"guardar": 2.3, "habilidad": 8.4, "levelup": 8.2,
	"listo": -0.0, "logro": 10.2, "mantener": 18.7,
	"modo": 5.3, "moneda": -1.8, "monedas": 1.3,
	"monedas_todo": -2.4, "ok": -0.8, "pantalla": 0.6,
	"perfecto": 8.2, "potenciador": 8.4, "premio": -4.7,
	"quemado": 7.5, "recurso": -0.8, "recurso_off": -0.8,
	"recurso_ok": -0.8, "remover": 12.1, 
	"soltar": 1.7, "soplete": -19.1, "submenu": -2.2,
	"tesoro": -1.3, "timon": -0.0, 
	"velas": 10.5, "zarpar": 5.5,
}

## AJUSTE GENERAL de los efectos, en dB. El juego entero sonaba alto: los
## efectos tapaban la música y se comían la partida. Se baja aquí, de una vez,
## en vez de retocar cuarenta números — las proporciones entre familias ya
## estaban medidas y lo que sobraba era el conjunto.
const AJUSTE := -7.0

## Cuánto se mueve el TONO al azar en cada disparo, SOLO en las familias de
## `VARIAN`. Es lo que hace que el mismo golpe de cuchillo no suene idéntico
## veinte veces seguidas; fuera de la cocina no se aplica.
const VAIVEN := 0.06

## Cuántas veces seguidas puede sonar la MISMA familia en el mismo fotograma.
## La cocina dispara ráfagas (tres golpes de corte muy seguidos) y sin este
## tope se solapaban tres copias del mismo golpe y sonaba a distorsión.
const REPOSO := 0.035

# ---------------------------------------------------------------- VOCES

## LAS EXPRESIONES QUE TIENE CADA PERSONAJE, que son las mismas que sus
## retratos: por cada una hay TRES tomas en
## `sounds/voces/<personaje>/<expresión>_1..3.ogg`.
##
## Las voces son SONIDOS, no frases: gruñidos, hums, jadeos y risas. El
## personaje no lee su línea de diálogo — la acompaña, como en un juego de
## aventura clásico.
##
## Las rutas NO se buscan en disco (ver la nota de `FAMILIAS`): se componen
## por convención a partir de esta tabla, que es la que dice qué existe.
const VOCES := {
	"david": ["serio", "hablando", "feliz", "riendo", "sorprendido",
		"gritando", "triste", "mira_loro"],
	"gigi": ["loro", "loro_sorpresa", "loro_grito", "loro_resignado"],
	"saverio": ["serio", "hablando", "explicando", "feliz", "riendo"],
	"pablo": ["serio", "hablando", "feliz", "riendo", "sorprendido",
		"guason", "punal"],
	"cai": ["serio", "hablando", "callado", "feliz", "sorprendido"],
	"alice": ["serio", "hablando", "callado", "feliz", "riendo",
		"sorprendido", "triste"],
	"kappa": ["serio", "hablando", "feliz", "enfadado", "furioso",
		"colerico", "dormido"],
	"sirena": ["serio", "hablando", "cantando", "enfadado", "feliz",
		"sorprendido"],
	"grumete": ["serio", "hablando", "feliz"],
	"grumete_f": ["serio", "hablando", "feliz"],
	"pirata": ["serio", "hablando", "feliz", "nervioso"],
	"pirata_f": ["serio", "hablando", "feliz", "nervioso"],
	"capitan": ["serio", "hablando", "feliz"],
	"capitan_f": ["serio", "hablando", "feliz"],
}

## TONO FIJO por personaje, y es lo que de verdad separa el reparto. El pack
## de voces solo trae CUATRO tipos —dos masculinos y dos femeninos— y aquí hay
## diez personajes, así que dos comparten timbre por fuerza; lo que los hace
## distintos es la altura. Va aquí y NO horneado en el archivo, para poder
## afinarlo sin reconvertir 141 clips.
##
## El KAPPA y GIGI no son humanos (croares y graznidos generados) y CAI
## conserva su voz japonesa: los tres van por su cuenta.
const VOZ_TONO := {
	# Masculinos tipo 1
	"david": 1.00,
	"pirata": 0.94,
	"capitan": 0.84,
	# Masculinos tipo 2. LOS TRES SUBIERON de golpe (el usuario: "el grumete
	# tiene la voz demasiado grave; Pablo también; Saverio también"). Eran
	# 1.06 / 0.92 / 1.14: como los tres salen del MISMO tipo de voz del pack,
	# lo que estaba grave era el tipo entero, así que se suben todos y se
	# conserva la separación entre ellos, que es lo único que los distingue.
	# Subir el tono ACORTA además la toma, que aquí viene de perlas.
	"pablo": 1.22,
	"saverio": 1.08,
	"grumete": 1.32,
	# Femeninas (un solo tipo, por decisión del usuario)
	"alice": 1.06,
	"grumete_f": 1.14,
	"pirata_f": 0.98,
	"capitan_f": 0.88,
	# No humanos
	"kappa": 0.92,
	# La SIRENA es generada (vocalise): su altura ya es la suya.
	"sirena": 1.02,
	"gigi": 1.06,
}
## LO QUE SE LE SUMA A CADA PERSONAJE. Sus tomas vienen de sitios distintos
## —el pack humano casi a cero, Cai y el Kappa generados, Gigi grabado en una
## sala— y aunque todas están ya igualadas de PICO, la sonoridad seguía
## variando 8 dB entre unos y otros.
const VOZ_DB_PERS := {
	"alice": -11.2, "cai": -5.0, "capitan": -7.5,
	"capitan_f": -11.1, "david": -8.7, "gigi": -3.4,
	"grumete": -8.9, "grumete_f": -11.6, "kappa": -6.0,
	"pablo": -9.1, "pirata": -9.5, "pirata_f": -10.5, "sirena": -7.8,
	"saverio": -9.3,
}

const VOZ_DB := -7.0
## Vaivén de tono de las voces. Va CORTO: una voz humana estirada se nota
## enseguida, al revés que un golpe de cuchillo.
const VOZ_VAIVEN := 0.025

# ------------------------------------------------------------------------

var _banco: SoundBank = null
var _voz: AudioStreamPlayer = null
## EL AMBIENTE VA EN DOS REPRODUCTORES, igual que la música, para poder
## cruzarlo consigo mismo al dar la vuelta (ver `_bucle_ambiente`).
var _amb_pistas: Array[AudioStreamPlayer] = []
var _amb_viva := 0
## Reproductores aparte para los sueltos CON FUNDIDO (la gaviota que pasa,
## el barco viajando por el mapa): un sonido de fondo que entra y sale de
## golpe se oye como un corte. Son VARIOS porque se solapan de verdad.
const SUELTOS := 3
var _sueltos: Array[AudioStreamPlayer] = []
var _suelto_est: Array = []
var _voz_ultima: Dictionary = {}
var _ultimo_disparo: Dictionary = {}

## Los DOS reproductores de música, para poder cruzar un tema con otro (y con
## él mismo al dar la vuelta). `_vol` es el volumen LINEAL que lleva cada uno
## y `_obj` al que va; el fundido se hace a mano en `_process` y no con un
## tween a propósito: la caja de diálogo pone el árbol en pausa a cada rato y
## un fundido a medias se quedaría congelado con la música a mitad de volumen.
var _pistas: Array[AudioStreamPlayer] = []
var _vol := [0.0, 0.0]
var _tempo := 1.0
## Qué tema lleva CADA pista. Hace falta porque las dos suenan a la vez
## mientras se cruzan, y cada una tiene que ir a SU nivel: con un solo dato,
## durante el cruce el tema entrante sonaba con el ajuste del que se iba.
var _tema_de := ["", ""]
var _obj := [0.0, 0.0]
var _vel := [1.0, 1.0]
var _viva := 0
var _tema := ""

## EN HEADLESS EL AUDIO NO SE MONTA. No es un ahorro cualquiera: la
## comprobación de errores del proyecto es
## `--headless --quit-after 250 <escena>` y se da por buena "sin salida = OK",
## y con el audio puesto TODA pasada terminaba escupiendo "8 ObjectDB
## instances were leaked" y "3 resources still in use". No es un fallo de
## partida —pasa porque el proceso se mata mientras algo suena y el servidor
## de audio, sin tarjeta detrás, no llega a procesar el `stop()`— pero deja la
## consola sucia justo en el sitio donde se miran los errores de verdad, que
## es la peor clase de ruido: el que enseña a no mirar.
##
## De paso, una sonda deja de cargar los siete megas de música y voces para
## nada.
var _mudo := false

var _amb_vol := 0.0
var _amb_obj := 0.0
var _amb_vel := 1.0
## Volumen de ESTE ambiente sobre `AMB_DB` (ver `ambiente`).
## Cuánto le queda de volumen a la pista que se va tras dar la vuelta.
var _amb_saliendo := 0.0
var _amb_db := 0.0
var _amb_id := ""


func _ready() -> void:
	# El audio sigue vivo con el árbol en pausa: los carteles de resultados y
	# los guiones pausan el juego entero y la música no puede pararse con
	# ellos.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mudo = DisplayServer.get_name() == "headless"
	if _mudo:
		set_process(false)
		return
	_crear_buses()
	_banco = SoundBankCls.new()
	_banco.bus = BUS_EFECTOS
	add_child(_banco)
	for f in FAMILIAS:
		_banco.cargar(str(f), FAMILIAS[f])
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.bus = BUS_MUSICA
		p.volume_db = -60.0
		add_child(p)
		_pistas.append(p)
	_voz = AudioStreamPlayer.new()
	_voz.process_mode = Node.PROCESS_MODE_ALWAYS
	_voz.bus = BUS_VOCES
	add_child(_voz)
	for i in 2:
		var a := AudioStreamPlayer.new()
		a.process_mode = Node.PROCESS_MODE_ALWAYS
		a.bus = BUS_EFECTOS
		a.volume_db = -60.0
		add_child(a)
		_amb_pistas.append(a)
	for i in SUELTOS:
		var u := AudioStreamPlayer.new()
		u.process_mode = Node.PROCESS_MODE_ALWAYS
		u.bus = BUS_EFECTOS
		add_child(u)
		_sueltos.append(u)
		_suelto_est.append({})
	aplicar_volumenes()
	# EL CLIC DE TODOS LOS BOTONES DEL JUEGO, de una vez: en lugar de tocar
	# los cien sitios que crean botones, se escucha el alta de nodos del árbol
	# y a cada BaseButton que entra se le engancha su sonido. Así un botón
	# nuevo suena sin que nadie se acuerde de nada.
	get_tree().node_added.connect(_al_entrar_nodo)


## Los tres buses del juego, colgados de Master.
## LOS BUSES VIVEN EN `default_bus_layout.tres`, NO AQUÍ. Esto es la RED por
## si ese archivo se pierde o se abre el proyecto sin él.
##
## Estuvieron creados solo por código, y en el juego PUBLICADO PARA WEB eso
## deja el juego COMPLETAMENTE MUDO — medido en el navegador: el contexto de
## audio vivo, la salida de Godot enchufada y sus sonidos lanzándose, y RMS
## 0.00000 clavado. El build de escritorio mezcla en software y se entera de
## un bus nuevo en cualquier momento; el de web reparte los sonidos por un
## grafo de WebAudio que monta AL ARRANCAR con la disposición que haya, y todo
## lo que se mandó a un bus creado después no va a ninguna parte. Con el
## archivo de disposición, los tres buses existen desde el primer fotograma.
func _crear_buses() -> void:
	for nombre in [BUS_MUSICA, BUS_EFECTOS, BUS_VOCES]:
		if AudioServer.get_bus_index(nombre) >= 0:
			continue
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, nombre)
		AudioServer.set_bus_send(i, "Master")


## Vuelca los tres volúmenes de Opciones a sus buses. Un 0 no baja el volumen:
## SILENCIA el bus, porque -80 dB sigue dejando pasar un hilo audible.
func aplicar_volumenes() -> void:
	if _mudo:
		return
	_bus_a(BUS_MUSICA, GameState.get_setting("vol_musica"))
	_bus_a(BUS_EFECTOS, GameState.get_setting("vol_efectos"))
	_bus_a(BUS_VOCES, GameState.get_setting("vol_voces"))


func _bus_a(nombre: String, v: Variant) -> void:
	var i := AudioServer.get_bus_index(nombre)
	if i < 0:
		return
	var f := clampf(float(v), 0.0, 1.0)
	AudioServer.set_bus_mute(i, f <= 0.001)
	# El volumen se mueve por POTENCIA, no lineal: al oído, media barra tiene
	# que sonar a la mitad, y con un mapeo lineal la mitad de la barra ya
	# suena casi igual de fuerte.
	AudioServer.set_bus_volume_db(i, linear_to_db(pow(f, 1.6)))


# ----------------------------------------------------------------- efectos

## Suelta un efecto de la familia. `db` y `tono` se SUMAN a lo que diga la
## tabla, para poder subir o bajar un disparo concreto sin descuadrar el
## resto.
func sfx(familia: String, db := 0.0, tono := 1.0) -> void:
	if _mudo or _banco == null or not FAMILIAS.has(familia):
		return
	# Ráfagas: la cocina dispara tres golpes muy seguidos y tres copias del
	# mismo sonido solapadas suenan a distorsión, no a tres golpes.
	var ahora := float(Time.get_ticks_msec()) / 1000.0
	if ahora - float(_ultimo_disparo.get(familia, -1.0)) < REPOSO:
		return
	_ultimo_disparo[familia] = ahora
	# El vaivén de tono SOLO en la cocina (ver `VARIAN`): un botón tiene que
	# sonar exactamente igual siempre, y ahí la variación es el problema, no
	# la solución.
	tono *= float(TONO.get(familia, 1.0))
	if familia in VARIAN:
		tono *= randf_range(1.0 - VAIVEN, 1.0 + VAIVEN)
	_banco.play(familia, float(VOL.get(familia, 0.0)) + db + AJUSTE, tono)


## Un efecto que tiene que durar EXACTAMENTE `segundos`: se le mueve la
## velocidad hasta que la toma cunda lo que se le pide. Lo necesita la barra de
## experiencia, que tarda lo que tarde segun cuanta XP haya que sumar — primero
## se calcula el viaje de la barra y de ahi sale la velocidad del sonido.
##
## El tono se acota para que no acabe en un chirrido ni en un ronquido: si el
## viaje se sale de la horquilla, se prefiere que el sonido no cuadre del todo
## a que suene ridiculo.
func sfx_dura(familia: String, segundos: float, db := 0.0) -> void:
	if _mudo or not FAMILIAS.has(familia) or segundos <= 0.05:
		return
	var ruta := str(FAMILIAS[familia][0])
	if not ResourceLoader.exists(ruta):
		return
	var largo: float = load(ruta).get_length()
	sfx_suave(familia, db, minf(0.12, segundos * 0.2),
		clampf(largo / segundos, 0.55, 2.0), segundos)


## Bucle sostenido (el aceite friendo, el soplete, el removido). Se apaga
## SIEMPRE con `loop_off`: un soplete que se queda sonando sobre el cartel de
## resultados es de las cosas que más cantan.
func loop_on(familia: String, db := 0.0, tono := 1.0) -> void:
	if _mudo or _banco == null or not FAMILIAS.has(familia):
		return
	_banco.loop_on(familia, float(VOL.get(familia, 0.0)) + db + AJUSTE, tono)


func loop_off(familia: String) -> void:
	if _banco != null:
		_banco.loop_off(familia)


## Pausa o reanuda un bucle POR DONDE IBA (ver `SoundBank.loop_pause`). Lo usa
## el corte lento: suena mientras el dedo avanza y se queda a medias en cuanto
## se para, en vez de volver a empezar.
func loop_pausa(familia: String, pausado: bool) -> void:
	if _banco != null and not _mudo:
		_banco.loop_pause(familia, pausado)


func loops_off() -> void:
	if _banco != null:
		_banco.todos_los_bucles_off()


## UNA VENTANA QUE SE ABRE Y SE CIERRA, en una sola llamada. Se le pasa el
## nodo del cartel (o su velo): suena al ponerlo y vuelve a sonar solo cuando
## ese nodo se va del árbol.
##
## Va así y no con dos llamadas repartidas porque el juego tiene una veintena
## de carteles modales y cada uno se cierra por dos o tres caminos distintos
## (su botón, la X, un toque fuera, el guion que lo mata). Colgándose de
## `tree_exiting` no hay forma de que a un camino se le olvide el sonido.
func ventana(nodo: Node, abre := "recurso",
		cierra := "recurso_off") -> void:
	if _mudo:
		return
	sfx(abre)
	if nodo == null or nodo.has_meta("snd_ventana"):
		return
	# LA MARCA, y no `is_connected`: ese compara el callable ENTERO y el
	# nuestro lleva un `bind`, así que nunca reconocería la conexión y
	# colgaría otra por cada llamada.
	nodo.set_meta("snd_ventana", true)
	nodo.tree_exiting.connect(_cerrar_ventana.bind(cierra))


func _cerrar_ventana(familia: String) -> void:
	sfx(familia)


# ------------------------------------------------------------------- voces

## La voz de un personaje en una expresión: uno de sus TRES sonidos, sorteado
## sin repetir el anterior.
##
## La expresión que no tenga voz propia cae a la primera del personaje (su
## "serio"), y el personaje que no exista no suena: un hablante nuevo no puede
## tumbar un diálogo.
func voz(personaje: String, expresion := "") -> void:
	if _mudo or _voz == null or not VOCES.has(personaje):
		return
	var moods: Array = VOCES[personaje]
	if not moods.has(expresion):
		expresion = str(moods[0])
	var n := 3
	var i := randi() % n
	var clave := "%s/%s" % [personaje, expresion]
	if i == int(_voz_ultima.get(clave, -1)):
		i = (i + 1) % n
	_voz_ultima[clave] = i
	var ruta := "res://sounds/juego/voces/%s/%s_%d.ogg" % [personaje, expresion, i + 1]
	if not ResourceLoader.exists(ruta):
		return
	# Una voz nueva CORTA a la anterior: el personaje no puede hablarse
	# encima de sí mismo al pasar de línea a toques.
	_voz.stream = load(ruta)
	_voz.volume_db = VOZ_DB + float(VOZ_DB_PERS.get(personaje, 0.0))
	_voz.pitch_scale = float(VOZ_TONO.get(personaje, 1.0)) \
		* randf_range(1.0 - VOZ_VAIVEN, 1.0 + VOZ_VAIVEN)
	_voz.play()


func voz_off() -> void:
	if _voz != null and _voz.playing:
		_voz.stop()


# ------------------------------------------------------------------ música

## Pone un tema. Si ya sonaba ese, no hace nada: así una pantalla puede
## pedirlo en su `_ready` sin cortar la música al volver de una subpantalla.
func musica(id: String, cruce := CRUCE) -> void:
	if _mudo or id == _tema:
		return
	if not TEMAS.has(id):
		musica_off(cruce)
		return
	_tema = id
	tempo(1.0)
	var otra := 1 - _viva
	_tema_de[otra] = id
	_pistas[otra].stream = load(TEMAS[id])
	_pistas[otra].play()
	_fundir(otra, 1.0, cruce)
	_fundir(_viva, 0.0, cruce)
	_viva = otra


## ACELERA (o frena) EL TEMA QUE SUENA. `pitch_scale` mueve la velocidad Y el
## tono a la vez, que es justo lo que se busca aquí: en un abordaje, según se
## acaba el reloj la música se va acelerando y sube de tono, y el jugador
## siente la prisa antes de mirar el cronómetro.
##
## Lo pone `level3d` por fotograma mientras corre un abordaje, y `musica()` lo
## devuelve a 1.0 al cambiar de tema — si no, el tema siguiente heredaría la
## prisa del anterior.
func tempo(f: float) -> void:
	if _mudo:
		return
	_tempo = clampf(f, 0.5, 2.0)
	for p in _pistas:
		p.pitch_scale = _tempo


func musica_off(cruce := 0.8) -> void:
	_tema = ""
	for i in 2:
		_fundir(i, 0.0, cruce)


func tema_actual() -> String:
	return _tema


func _db_tema(i: int) -> float:
	return float(TEMAS_DB.get(_tema_de[i], 0.0))


func _fundir(i: int, objetivo: float, segundos: float) -> void:
	_obj[i] = objetivo
	_vel[i] = 1.0 / maxf(segundos, 0.05)


# ---------------------------------------------------------------- ambiente

## El ambiente de fondo (hoy solo el mar de la portada). Va en bucle de motor
## —el .ogg viene casado por los extremos— y por el bus de EFECTOS.
## Segundos de cruce del ambiente consigo mismo al dar la vuelta. El bucle
## del motor deja un corte audible al volver al principio —el mar no está
## compuesto para casar—, así que se hace lo mismo que con la música: dos
## reproductores que se cruzan (ver `_bucle_ambiente`).
const CRUCE_AMB := 2.5


## `db` es el volumen al que suena ESTE ambiente, sobre `AMB_DB`. Lo necesita
## el mar: en la PORTADA es lo único que se oye —no hay música— y tiene que
## llenar la pantalla, mientras que en el menú va por debajo del tema, apenas
## como fondo. Es el mismo bucle sonando a dos alturas, no dos sonidos.
##
## Pedir el mismo ambiente con OTRO `db` no lo reinicia: solo mueve el
## volumen, así que el mar no se corta al llegar al fondeadero.
func ambiente(id: String, cruce := 1.2, db := 0.0) -> void:
	if _mudo:
		return
	if id == _amb_id:
		_amb_db = db
		return
	if not AMBIENTES.has(id):
		ambiente_off(cruce)
		return
	_amb_id = id
	_amb_db = db
	# SIN `loop` del motor: la vuelta la da `_bucle_ambiente` cruzando la
	# pista consigo misma, porque el corte seco del final contra el
	# principio se oye — el mar no está grabado para casar.
	_amb_pistas[_amb_viva].stream = load(AMBIENTES[id])
	_amb_pistas[_amb_viva].volume_db = -60.0
	_amb_pistas[_amb_viva].play()
	_amb_obj = 1.0
	_amb_vel = 1.0 / maxf(cruce, 0.05)


func ambiente_off(cruce := 0.8) -> void:
	_amb_id = ""
	_amb_obj = 0.0
	_amb_vel = 1.0 / maxf(cruce, 0.05)


func _process(delta: float) -> void:
	_mover_musica(delta)
	_mover_ambiente(delta)
	_bucle_musica()


func _mover_musica(delta: float) -> void:
	for i in 2:
		if is_equal_approx(_vol[i], _obj[i]):
			continue
		_vol[i] = move_toward(_vol[i], _obj[i], _vel[i] * delta)
		var p := _pistas[i]
		if _vol[i] <= 0.001:
			p.stop()
			p.volume_db = -60.0
		else:
			p.volume_db = MUS_DB + _db_tema(i) + linear_to_db(_vol[i])


func _mover_ambiente(delta: float) -> void:
	if not is_equal_approx(_amb_vol, _amb_obj):
		_amb_vol = move_toward(_amb_vol, _amb_obj, _amb_vel * delta)
	var viva := _amb_pistas[_amb_viva]
	if _amb_vol <= 0.001:
		for a in _amb_pistas:
			a.stop()
			a.volume_db = -60.0
		return
	viva.volume_db = AMB_DB + _amb_db + linear_to_db(_amb_vol)
	# La OTRA pista es la que se está yendo tras dar la vuelta: baja sola
	# en `_cruce_amb` segundos y se para.
	var otra := _amb_pistas[1 - _amb_viva]
	if otra.playing:
		_amb_saliendo = maxf(_amb_saliendo - delta / CRUCE_AMB, 0.0)
		if _amb_saliendo <= 0.001:
			otra.stop()
		else:
			otra.volume_db = AMB_DB + _amb_db \
				+ linear_to_db(_amb_saliendo * _amb_vol)
	_bucle_ambiente()
	_mover_suelto(delta)


## LA VUELTA DEL AMBIENTE SE CRUZA CONSIGO MISMA, igual que la música: a
## `CRUCE_AMB` del final arranca la otra pista desde cero y las dos se
## solapan mientras una sube y la otra baja. Con el `loop` del motor el
## salto del final al principio se oía como un corte en cada vuelta.
func _bucle_ambiente() -> void:
	var viva := _amb_pistas[_amb_viva]
	if _amb_id == "" or not viva.playing or viva.stream == null:
		return
	var largo := viva.stream.get_length()
	if largo <= CRUCE_AMB * 2.0:
		return
	if viva.get_playback_position() < largo - CRUCE_AMB:
		return
	var otra := _amb_pistas[1 - _amb_viva]
	if otra.playing:
		return
	otra.stream = viva.stream
	otra.volume_db = -60.0
	otra.play()
	# La que sonaba pasa a ser la que se va: `_amb_saliendo` la baja.
	_amb_saliendo = 1.0
	_amb_viva = 1 - _amb_viva


## Un sonido SUELTO con fundido de entrada y salida (las gaviotas). Un
## efecto puntual entra de golpe y no pasa nada —es un golpe—, pero un
## sonido de AMBIENTE que aparece y desaparece a cuchillo se oye como un
## corte. Va en su propio reproductor para no pelearse con el pool.
## Un sonido SUELTO con fundido de entrada y de salida. Un efecto puntual
## puede entrar de golpe —es un golpe—, pero un sonido de AMBIENTE que aparece
## y desaparece a cuchillo se oye como un corte.
##
## `dura` es cuánto tiene que sonar EN TOTAL: con 0 suena la toma entera y se
## apaga al llegar a su final; con un número, se apaga cuando toque aunque la
## toma diera para más. Lo usa el crujido del barco viajando por el mapa, que
## tiene que durar lo que dure el viaje.
##
## `tono` mueve la altura. El viaje lo sortea en cada trayecto: es el MISMO
## crujido y sin eso, cambiando de nivel diez veces seguidas, se oye siempre
## igual.
##
## VAN EN UN POOL de reproductores porque se solapan de verdad: en el mapa el
## barco viaja mientras pasa una gaviota, y con uno solo se cortaban.
## `desde` es el SEGUNDO por el que arranca la toma. Lo necesita el crujido
## del viaje: sus primeras décimas son las más flojas del archivo (-38 dB
## contra -35 del cuerpo, medido por tramos) y en un salto corto entre dos
## niveles vecinos no daba tiempo a oír nada.
func sfx_suave(familia: String, db := 0.0, fundido := 0.6, tono := 1.0,
		dura := 0.0, desde := 0.0) -> void:
	if _mudo or not FAMILIAS.has(familia):
		return
	var tomas: Array = FAMILIAS[familia]
	var ruta := str(tomas[randi() % tomas.size()])
	if not ResourceLoader.exists(ruta):
		return
	var i := _suelto_libre()
	var p := _sueltos[i]
	p.stream = load(ruta)
	p.pitch_scale = _pitch_sano(tono)
	p.volume_db = -60.0
	p.play(desde)
	_suelto_est[i] = {
		"db": float(VOL.get(familia, 0.0)) + db + AJUSTE,
		"vol": 0.0, "obj": 1.0, "vel": 1.0 / maxf(fundido, 0.05),
		"queda": dura if dura > 0.0 else -1.0,
	}


## El primer reproductor libre; si están todos ocupados, el que lleve más
## tiempo sonando (que es el que menos se echará de menos).
func _suelto_libre() -> int:
	var viejo := 0
	var mas := -1.0
	for i in _sueltos.size():
		if not _sueltos[i].playing:
			return i
		var t := _sueltos[i].get_playback_position()
		if t > mas:
			mas = t
			viejo = i
	return viejo


## Un `pitch_scale` que no sea un número normal revienta el mezclador y puede
## llevarse por delante TODO el audio, no solo ese sonido (la misma red de
## seguridad que tiene la pesca).
func _pitch_sano(v: float) -> float:
	return clampf(v, 0.4, 2.5) if is_finite(v) else 1.0


func _mover_suelto(delta: float) -> void:
	for i in _sueltos.size():
		var p := _sueltos[i]
		if not p.playing:
			continue
		var e: Dictionary = _suelto_est[i]
		# Con `dura` puesta, la cuenta atrás manda; si no, se apaga al acercarse
		# el final de la toma para que la cola tampoco termine a cuchillo.
		var caida := 1.0 / float(e["vel"])
		if float(e["queda"]) >= 0.0:
			e["queda"] = float(e["queda"]) - delta
			if float(e["queda"]) <= caida:
				e["obj"] = 0.0
		else:
			var largo := p.stream.get_length() / maxf(p.pitch_scale, 0.01)
			if largo - p.get_playback_position() < caida:
				e["obj"] = 0.0
		e["vol"] = move_toward(float(e["vol"]), float(e["obj"]),
			float(e["vel"]) * delta)
		if float(e["vol"]) <= 0.001 and is_equal_approx(float(e["obj"]), 0.0):
			p.stop()
			continue
		p.volume_db = float(e["db"]) + linear_to_db(maxf(float(e["vol"]), 0.001))


## LA RED PARA UN TEMA SIN BUCLE PREPARADO: se cruza consigo mismo. Fue el
## sistema de toda la música hasta que los .ogg se cosieron (ver TEMAS_BUCLE),
## y se queda porque un tema nuevo entra por aquí sin que nadie tenga que
## acordarse de nada. Esconde el corte, pero mezcla dos segundos de compases
## que no se corresponden: si un tema se va a quedar, cósele el bucle.
##
## Si la otra pista está ocupada (se acaba de cambiar de tema y justo toca la
## vuelta), se rebobina la que suena: es un caso rarísimo y una costura suena
## mejor que quedarse en silencio.
func _bucle_musica() -> void:
	if _tema == "":
		return
	var p := _pistas[_viva]
	if p.stream == null:
		return
	# Un tema COSIDO da la vuelta solo: lo lleva el motor y aquí no hay nada
	# que hacer.
	if TEMAS_BUCLE.has(_tema):
		return
	# Uno con FINAL suena entero y vuelve a empezar. `_obj` es el volumen al
	# que va: si está yéndose (cambio de pantalla) no se rearranca.
	if TEMAS_FINAL.has(_tema):
		if not p.playing and _obj[_viva] > 0.5:
			# Vuelve a empezar CON TRANSICIÓN, no de golpe: acaba de morirse
			# su acorde final y volver a plena fuerza suena a pinchazo.
			p.play()
			_vol[_viva] = 0.0
			p.volume_db = -60.0
			_fundir(_viva, 1.0, CRUCE_FINAL)
		return
	if not p.playing:
		return
	var largo := p.stream.get_length()
	if largo <= CRUCE_BUCLE * 2.0:
		return
	if p.get_playback_position() < largo - CRUCE_BUCLE:
		return
	var otra := 1 - _viva
	if _vol[otra] > 0.02 or _pistas[otra].playing:
		p.seek(0.0)
		return
	_tema_de[otra] = _tema
	_pistas[otra].stream = p.stream
	_pistas[otra].play()
	_fundir(otra, 1.0, CRUCE_BUCLE)
	_fundir(_viva, 0.0, CRUCE_BUCLE)
	_viva = otra


## APAGARLO TODO AL CERRAR EL JUEGO. Sin esto, lo que estuviera sonando en ese
## momento se queda con su `AudioStreamPlayback` vivo y Godot avisa de
## instancias filtradas al salir (medido: 8 con el mar y una gaviota puestos).
## No es un fallo de partida —al cerrar da igual—, pero deja la consola sucia y
## ese aviso es de los que luego se confunden con uno de verdad.
func _exit_tree() -> void:
	if _mudo:
		return
	if _banco != null:
		_banco.silencio_total()
	for p in _pistas:
		p.stop()
		p.stream = null
	if _voz != null:
		_voz.stop()
		_voz.stream = null
	for a in _amb_pistas:
		a.stop()
		a.stream = null
	for u in _sueltos:
		u.stop()
		u.stream = null


# ------------------------------------------------------- clic de los botones

## Cada BaseButton que entra en el árbol se lleva su sonido de pulsación.
##
## VA EN `pressed` Y NO EN `button_down` a propósito: las listas del juego se
## desplazan ARRASTRANDO EL DEDO por encima de las tarjetas, que son botones,
## y `button_down` salta al apoyar el dedo — o sea que recorrer el recetario
## sonaba a ametralladora de clics. `pressed` solo se emite si el dedo se
## levanta encima del botón, y `TouchScroll` ya se traga ese evento cuando ha
## habido gesto, así que arrastrar no suena y pulsar sí.
##
## Un botón puede pedir otro sonido con `set_meta("snd", "familia")`, o
## callarse con `set_meta("snd", "")` — lo usan los botones que ya tienen
## sonido propio (las recetas de la tabla, el cofre del bonus diario).
func _al_entrar_nodo(n: Node) -> void:
	if not n is BaseButton:
		return
	# UN BOTÓN PUEDE ENTRAR DOS VECES EN EL ÁRBOL: hay pantallas que sacan un
	# nodo y lo vuelven a meter (el menú mueve sus cajas de recursos entre el
	# menú y el mapa), y `node_added` salta cada vez. Sin la marca, la segunda
	# vuelta suelta un "Signal 'pressed' is already connected" y el clic
	# sonaría doble.
	if n.has_meta("snd_puesto"):
		return
	n.set_meta("snd_puesto", true)
	(n as BaseButton).pressed.connect(_clic_de.bind(n))


func _clic_de(n: Node) -> void:
	if not is_instance_valid(n):
		return
	var fam := "click"
	if n.has_meta("snd"):
		fam = str(n.get_meta("snd"))
	if fam != "":
		sfx(fam)
