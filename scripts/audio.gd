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
## DINAMISMO: ninguna familia suena nunca dos veces igual. Cada toma sale
## SORTEADA SIN REPETIR LA ANTERIOR (eso lo pone `SoundBank`) y encima con el
## TONO movido al azar dentro de su horquilla (`VAIVEN`). Con seis tomas de
## clic y un vaivén del 6% no hay dos pulsaciones idénticas en toda la
## partida, que es lo que delata a un juego cuando el jugador repite la misma
## acción doscientas veces.

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
	"menu": "res://sounds/musica/menu.ogg",
	"tienda": "res://sounds/musica/tienda.ogg",
	"arcade": "res://sounds/musica/arcade.ogg",
	"pesca": "res://sounds/musica/pesca.ogg",
	"isla": "res://sounds/musica/isla.ogg",
	"puerto": "res://sounds/musica/puerto.ogg",
	"abordaje": "res://sounds/musica/abordaje.ogg",
	"cueva": "res://sounds/musica/cueva.ogg",
}

const AMBIENTES := {
	"mar": "res://sounds/musica/ambiente_mar.ogg",
}

## Volumen de referencia de la música, en dB sobre su bus. Va POR DEBAJO de
## los efectos a propósito: la música es el fondo y lo que el jugador tiene
## que oír para jugar son los avisos de la barra y la cocina.
const MUS_DB := -11.0
const AMB_DB := -15.0

## Segundos de cruce entre dos temas, y del tema consigo mismo al dar la
## vuelta (ver `_bucle_musica`).
const CRUCE := 1.6
const CRUCE_BUCLE := 2.2

# -------------------------------------------------------------- EFECTOS

## Las familias de efectos. Cada una es un puñado de tomas del MISMO sonido y
## `SoundBank` elige una sin repetir la anterior.
##
## LAS RUTAS SE ESCRIBEN A MANO, NUNCA se escanea la carpeta con DirAccess:
## los .ogg se importan a `.godot/imported/*.oggvorbisstr` y en el EXPORT los
## originales no están, así que un escaneo funcionaría en el editor y
## devolvería una lista VACÍA en el juego publicado.
const IF_ := "res://sounds/interfaz/"
const CO_ := "res://sounds/cocina/"
const NI_ := "res://sounds/nivel/"

const FAMILIAS := {
	# --- interfaz -------------------------------------------------------
	"click": [IF_ + "Click - 1.ogg", IF_ + "Click - 2.ogg",
		IF_ + "Click - 3.ogg", IF_ + "Click - 4.ogg",
		IF_ + "Click - 5.ogg", IF_ + "Click - 6.ogg"],
	"click_suave": [IF_ + "UI2_Click_1.ogg", IF_ + "UI2_Click_2.ogg",
		IF_ + "UI2_Click_3.ogg"],
	"ok": [IF_ + "UI2_Accept_1.ogg", IF_ + "UI2_Accept_2.ogg"],
	"no": [IF_ + "UI2_Decline_1.ogg", IF_ + "UI2_Decline_2.ogg",
		IF_ + "UI2_Decline_3.ogg"],
	"error": [IF_ + "UI2_Error_1.ogg", IF_ + "UI2_Error_2.ogg"],
	"zarpar": [IF_ + "Start - Confirm 1.ogg", IF_ + "Start - Confirm 2.ogg",
		IF_ + "Start - Confirm 1 Alternate.ogg"],
	"ventana": [IF_ + "UI2_Window_Open_1.ogg", IF_ + "UI2_Window_Open_2.ogg",
		IF_ + "UI2_Window_Open_3.ogg"],
	"ventana_off": [IF_ + "UI2_Window_Close_1.ogg",
		IF_ + "UI2_Window_Close_2.ogg", IF_ + "UI2_Window_Close_3.ogg"],
	"bolsa": [IF_ + "Open - Close Bag 1.ogg", IF_ + "Open - Close Bag 2.ogg",
		IF_ + "Open - Close Bag 3.ogg", IF_ + "Open - Close Bag 4.ogg"],
	"pantalla": [IF_ + "Open Map - Menu 1.ogg", IF_ + "Open Map - Menu 2.ogg",
		IF_ + "Open Map - Menu 3.ogg", IF_ + "Open Map - Menu 4.ogg",
		IF_ + "Open Map - Menu 5.ogg"],
	"swoosh": [IF_ + "Slide - Swoosh 1.ogg", IF_ + "Slide - Swoosh 2.ogg",
		IF_ + "Slide - Swoosh 3.ogg", IF_ + "Slide - Swoosh 4.ogg"],
	"pagina": [IF_ + "Cutting Cloth & Paper - 1.ogg",
		IF_ + "Cutting Cloth & Paper - 2.ogg",
		IF_ + "Cutting Cloth & Paper - 3.ogg"],
	"tecla": [IF_ + "Typing Sound - 1.ogg", IF_ + "Typing Sound - 2.ogg",
		IF_ + "Typing Sound - 3.ogg", IF_ + "Typing Sound - 4.ogg",
		IF_ + "Typing Sound - 5.ogg", IF_ + "Typing Sound - 6.ogg"],
	"on": [IF_ + "Enable - 1.ogg", IF_ + "Enable - 2.ogg"],
	"off": [IF_ + "Disable - 1.ogg", IF_ + "Disable - 2.ogg"],
	"logro": [IF_ + "Achievement - Trophy 1.ogg",
		IF_ + "Achievement - Trophy 2.ogg", IF_ + "Achievement - Trophy 3.ogg",
		IF_ + "Achievement - Trophy 7.ogg",
		IF_ + "Achievement - Trophy 12.ogg"],
	"trofeo": [IF_ + "UI2_Trophy_1.ogg", IF_ + "UI2_Trophy_2.ogg"],
	"moneda": [IF_ + "Coins - Single Coin - 1.ogg",
		IF_ + "Coins - Single Coin - 2.ogg",
		IF_ + "Coins - Single Coin - 3.ogg",
		IF_ + "Coins - Single Coin - 4.ogg"],
	"monedas": [IF_ + "Coins - Small Pile - 1.ogg",
		IF_ + "Coins - Small Pile - 2.ogg", IF_ + "Coins - Small Pile - 3.ogg",
		IF_ + "Coins - Small Pile - 4.ogg",
		IF_ + "Coins - Small Pile - 5.ogg"],
	"tesoro": [IF_ + "Coins - Large Pile - 1.ogg",
		IF_ + "Coins - Large Pile - 2.ogg",
		IF_ + "Coins - Large Pile - 3.ogg"],
	"premio": [IF_ + "Quest Item Pickup - 1.ogg",
		IF_ + "Quest Item Pickup - 2.ogg", NI_ + "GS2_Item_Acquire_1.ogg",
		NI_ + "GS2_Item_Acquire_2.ogg", NI_ + "GS2_Item_Acquire_3.ogg",
		NI_ + "GS2_Item_Acquire_4.ogg", NI_ + "GS2_Item_Acquire_5.ogg"],
	"chispa": [IF_ + "UI_Puzzle_Game_1.ogg", IF_ + "UI_Puzzle_Game_2.ogg",
		IF_ + "UI_Puzzle_Game_3.ogg", IF_ + "UI_Puzzle_Game_4.ogg",
		IF_ + "UI_Puzzle_Game_5.ogg", IF_ + "UI_Puzzle_Game_6.ogg"],
	# --- cocina ---------------------------------------------------------
	"arroz": [CO_ + "arroz_1.ogg", CO_ + "arroz_2.ogg"],
	"corte": [CO_ + "corte_1.ogg", CO_ + "corte_2.ogg"],
	"corte_lento": [CO_ + "corte_lento_1.ogg", CO_ + "corte_lento_2.ogg"],
	"enrollar": [CO_ + "enrollar_1.ogg", CO_ + "enrollar_2.ogg"],
	"mantener": [CO_ + "mantener.ogg"],
	"remover": [CO_ + "remover.ogg"],
	"freir": [CO_ + "freir.ogg"],
	"soplete": [CO_ + "soplete.ogg"],
	"ingrediente": [CO_ + "ingrediente_1.ogg", CO_ + "ingrediente_2.ogg",
		CO_ + "Take Out Item - 1.ogg", CO_ + "Take Out Item - 2.ogg",
		CO_ + "Take Out Item - 3.ogg", CO_ + "Take Out Item - 4.ogg"],
	"soltar": [CO_ + "soltar_1.ogg", CO_ + "soltar_2.ogg",
		CO_ + "Place Item - 1.ogg", CO_ + "Place Item - 2.ogg",
		CO_ + "Place Item - 3.ogg"],
	"paso": [CO_ + "paso_1.ogg", CO_ + "paso_2.ogg"],
	"listo": [CO_ + "listo_1.ogg", CO_ + "listo_2.ogg"],
	"cinta": [CO_ + "cinta_1.ogg", CO_ + "cinta_2.ogg"],
	"quemado": [CO_ + "quemado.ogg"],
	"perfecto": [CO_ + "perfecto.ogg"],
	"extra": [CO_ + "extra_1.ogg", CO_ + "extra_2.ogg"],
	"basura": [CO_ + "basura_1.ogg", CO_ + "Drop Item - 1.ogg",
		CO_ + "Drop Item - 2.ogg", CO_ + "Drop Item - 3.ogg"],
	"caja_abre": [CO_ + "Open Drawer - 1.ogg", CO_ + "Open Drawer - 2.ogg"],
	"caja_cierra": [CO_ + "Close Drawer - 1.ogg", CO_ + "Close Drawer - 2.ogg"],
	"guardar": [CO_ + "Place Item - 4.ogg", CO_ + "Place Item - 5.ogg",
		CO_ + "Place Item - 6.ogg"],
	# --- nivel ----------------------------------------------------------
	"campana": [NI_ + "campana.ogg"],
	"fin_turno": [NI_ + "fin_turno.ogg"],
	"estrella": [NI_ + "estrella.ogg"],
	"calavera": [NI_ + "calavera.ogg"],
	"potenciador": [NI_ + "potenciador.ogg"],
	"gaviota": [NI_ + "gaviota_1.ogg", NI_ + "gaviota_2.ogg"],
	"cruje": [NI_ + "madera_barco_1.ogg"],
	"coger_plato": [NI_ + "coger_plato_1.ogg", CO_ + "cinta_2.ogg"],
	"comer": [NI_ + "comer_1.ogg", NI_ + "comer_2.ogg"],
	"cofre": [NI_ + "Crate Opening 1.ogg", NI_ + "Crate Opening 2.ogg",
		NI_ + "Crate Opening 3.ogg", NI_ + "Crate Opening 4.ogg",
		NI_ + "GS2_Treasure_Chest_Open.ogg"],
	"madera": [NI_ + "Crate Hit 1.ogg", NI_ + "Crate Hit 2.ogg",
		NI_ + "Crate Hit 3.ogg", NI_ + "Crate Hit 4.ogg",
		NI_ + "Crate Hit 5.ogg"],
	"saco": [NI_ + "GS2_Bag_Open_1.ogg", NI_ + "GS2_Bag_Open_2.ogg",
		NI_ + "GS2_Bag_Open_3.ogg"],
}

## Volumen de cada familia, en dB. Se guarda aquí y no en cada llamada para
## que un sonido no suene a un volumen en una pantalla y a otro en la
## siguiente. Lo que no esté listado va a 0.
const VOL := {
	"click": -7.0, "click_suave": -9.0, "ok": -6.0, "no": -7.0,
	"error": -6.0, "zarpar": -4.0, "ventana": -8.0, "ventana_off": -9.0,
	"bolsa": -8.0, "pantalla": -8.0, "swoosh": -12.0, "pagina": -10.0,
	"tecla": -16.0, "on": -9.0, "off": -9.0, "logro": -5.0, "trofeo": -5.0,
	"moneda": -9.0, "monedas": -7.0, "tesoro": -5.0, "premio": -5.0,
	"chispa": -9.0,
	"arroz": -9.0, "corte": -7.0, "corte_lento": -7.0, "enrollar": -9.0,
	"mantener": -13.0, "remover": -13.0, "freir": -12.0, "soplete": -13.0,
	"ingrediente": -11.0, "soltar": -10.0, "paso": -10.0, "listo": -6.0,
	"cinta": -8.0, "quemado": -6.0, "perfecto": -4.0, "extra": -9.0,
	"basura": -7.0, "caja_abre": -9.0, "caja_cierra": -9.0, "guardar": -8.0,
	"campana": -5.0, "fin_turno": -6.0, "estrella": -5.0, "calavera": -5.0,
	"potenciador": -5.0, "gaviota": -14.0, "cruje": -16.0,
	"coger_plato": -12.0, "comer": -14.0, "cofre": -6.0, "madera": -9.0,
	"saco": -8.0,
}

## Cuánto se mueve el TONO al azar en cada disparo. Es lo que hace que la
## misma toma no suene idéntica dos veces seguidas; las familias con una sola
## toma (el soplete, la campana) llevan más porque no tienen otra variedad.
const VAIVEN := 0.06
const VAIVEN_UNICO := 0.10

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
	"grumete": ["serio", "hablando", "feliz"],
	"grumete_f": ["serio", "hablando", "feliz"],
	"pirata": ["serio", "hablando", "feliz", "nervioso"],
	"pirata_f": ["serio", "hablando", "feliz", "nervioso"],
	"capitan": ["serio", "hablando", "feliz"],
	"capitan_f": ["serio", "hablando", "feliz"],
}

## TONO FIJO por personaje. El CAPITÁN comparte la voz grave de David (solo
## hay seis voces masculinas de catálogo y el reparto son siete hombres), así
## que se le baja el tono para que se lea como otra persona; el Kappa habla
## con gruñidos de rana y se le baja para que suene grande.
const VOZ_TONO := {
	"capitan": 0.86,
	"kappa": 0.92,
	"gigi": 1.06,
}
const VOZ_DB := -5.0
## Vaivén de tono de las voces. Va CORTO: una voz humana estirada se nota
## enseguida, al revés que un golpe de cuchillo.
const VOZ_VAIVEN := 0.025

# ------------------------------------------------------------------------

var _banco: SoundBank = null
var _voz: AudioStreamPlayer = null
var _amb: AudioStreamPlayer = null
var _voz_ultima: Dictionary = {}
var _ultimo_disparo: Dictionary = {}

## Los DOS reproductores de música, para poder cruzar un tema con otro (y con
## él mismo al dar la vuelta). `_vol` es el volumen LINEAL que lleva cada uno
## y `_obj` al que va; el fundido se hace a mano en `_process` y no con un
## tween a propósito: la caja de diálogo pone el árbol en pausa a cada rato y
## un fundido a medias se quedaría congelado con la música a mitad de volumen.
var _pistas: Array[AudioStreamPlayer] = []
var _vol := [0.0, 0.0]
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
	_amb = AudioStreamPlayer.new()
	_amb.process_mode = Node.PROCESS_MODE_ALWAYS
	_amb.bus = BUS_EFECTOS
	add_child(_amb)
	aplicar_volumenes()
	# EL CLIC DE TODOS LOS BOTONES DEL JUEGO, de una vez: en lugar de tocar
	# los cien sitios que crean botones, se escucha el alta de nodos del árbol
	# y a cada BaseButton que entra se le engancha su sonido. Así un botón
	# nuevo suena sin que nadie se acuerde de nada.
	get_tree().node_added.connect(_al_entrar_nodo)


## Los tres buses del juego, colgados de Master.
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
	var v := VAIVEN if FAMILIAS[familia].size() > 1 else VAIVEN_UNICO
	_banco.play(familia, float(VOL.get(familia, 0.0)) + db,
		tono * randf_range(1.0 - v, 1.0 + v))


## Bucle sostenido (el aceite friendo, el soplete, el removido). Se apaga
## SIEMPRE con `loop_off`: un soplete que se queda sonando sobre el cartel de
## resultados es de las cosas que más cantan.
func loop_on(familia: String, db := 0.0, tono := 1.0) -> void:
	if _mudo or _banco == null or not FAMILIAS.has(familia):
		return
	_banco.loop_on(familia, float(VOL.get(familia, 0.0)) + db, tono)


func loop_off(familia: String) -> void:
	if _banco != null:
		_banco.loop_off(familia)


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
func ventana(nodo: Node, abre := "ventana", cierra := "ventana_off") -> void:
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
	var ruta := "res://sounds/voces/%s/%s_%d.ogg" % [personaje, expresion, i + 1]
	if not ResourceLoader.exists(ruta):
		return
	# Una voz nueva CORTA a la anterior: el personaje no puede hablarse
	# encima de sí mismo al pasar de línea a toques.
	_voz.stream = load(ruta)
	_voz.volume_db = VOZ_DB
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
	var otra := 1 - _viva
	_pistas[otra].stream = load(TEMAS[id])
	_pistas[otra].play()
	_fundir(otra, 1.0, cruce)
	_fundir(_viva, 0.0, cruce)
	_viva = otra


func musica_off(cruce := 0.8) -> void:
	_tema = ""
	for i in 2:
		_fundir(i, 0.0, cruce)


func tema_actual() -> String:
	return _tema


func _fundir(i: int, objetivo: float, segundos: float) -> void:
	_obj[i] = objetivo
	_vel[i] = 1.0 / maxf(segundos, 0.05)


# ---------------------------------------------------------------- ambiente

## El ambiente de fondo (hoy solo el mar de la portada). Va en bucle de motor
## —el .ogg viene casado por los extremos— y por el bus de EFECTOS.
func ambiente(id: String, cruce := 1.2) -> void:
	if _mudo or id == _amb_id:
		return
	if not AMBIENTES.has(id):
		ambiente_off(cruce)
		return
	_amb_id = id
	# El recurso se DUPLICA antes de marcarle el bucle: `load()` devuelve la
	# instancia de la caché y ponerle `loop` ahí se lo pondría también a quien
	# use ese mismo archivo como efecto puntual.
	var s: AudioStream = load(AMBIENTES[id]).duplicate()
	if s is AudioStreamOggVorbis:
		s.loop = true
	_amb.stream = s
	_amb.volume_db = -60.0
	_amb.play()
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
			p.volume_db = MUS_DB + linear_to_db(_vol[i])


func _mover_ambiente(delta: float) -> void:
	if is_equal_approx(_amb_vol, _amb_obj):
		return
	_amb_vol = move_toward(_amb_vol, _amb_obj, _amb_vel * delta)
	if _amb_vol <= 0.001:
		_amb.stop()
		_amb.volume_db = -60.0
	else:
		_amb.volume_db = AMB_DB + linear_to_db(_amb_vol)


## EL BUCLE DE LA MÚSICA SE HACE CRUZANDO EL TEMA CONSIGO MISMO, no con el
## `loop` del recurso: el corte seco del final contra el arranque se oye como
## un salto aunque el .ogg no deje hueco, y estos temas no están compuestos
## para casar nota con nota. Cruzando los dos últimos segundos con los dos
## primeros, la vuelta no se nota.
##
## Si la otra pista está ocupada (se acaba de cambiar de tema y justo toca la
## vuelta), se rebobina la que suena: es un caso rarísimo y una costura suena
## mejor que quedarse en silencio.
func _bucle_musica() -> void:
	if _tema == "":
		return
	var p := _pistas[_viva]
	if not p.playing or p.stream == null:
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
	if _amb != null:
		_amb.stop()
		_amb.stream = null


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
