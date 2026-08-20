class_name SoundBank
extends Node
## BANCO DE EFECTOS de sonido. Es el primer audio que tiene el juego, así que
## se hace reutilizable desde el principio: la pesca lo estrena y la cocina
## puede colgar aquí sus familias sin tocar nada.
##
## Una FAMILIA es un puñado de tomas del MISMO sonido ("Casting Line" tiene
## cuatro). `play()` elige una al azar SIN REPETIR LA ÚLTIMA: con dos tomas
## alternando ya no suena a bucle de máquina, que es justo lo que delata a un
## juego cuando el jugador repite la misma acción veinte veces seguidas.
##
## LAS RUTAS SE ESCRIBEN A MANO, NUNCA se escanea la carpeta con DirAccess:
## los .ogg se importan a `.godot/imported/*.oggvorbisstr` y en el EXPORT los
## originales no están, así que un escaneo funcionaría en el editor y
## devolvería una lista vacía en el juego publicado.
##
## Los efectos PUNTUALES salen por un pool de reproductores que se reciclan
## (varios pueden sonar a la vez sin cortarse unos a otros) y los BUCLES
## —el carrete, la recogida del sedal— tienen cada uno el suyo, con el
## recurso DUPLICADO para poder marcarle `loop` sin tocar el que está en la
## caché de recursos (que lo compartirían todos los demás).

## Reproductores del pool para efectos puntuales.
const VOCES := 6

var _familias: Dictionary = {}
var _ultimo: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _bucles: Dictionary = {}
var _siguiente := 0


func _ready() -> void:
	for i in VOCES:
		var p := AudioStreamPlayer.new()
		# El audio sigue sonando con el árbol en pausa (los carteles del
		# botín la ponen): un efecto cortado a medias se nota mucho más que
		# uno que termina solo.
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_pool.append(p)


## Registra una familia con sus tomas. Las rutas se comprueban al cargar: si
## falta un archivo se salta y se sigue, que un efecto de menos no puede
## tumbar una pantalla.
func cargar(familia: String, rutas: Array) -> void:
	var tomas: Array = []
	for r in rutas:
		if ResourceLoader.exists(str(r)):
			tomas.append(load(str(r)))
	if not tomas.is_empty():
		_familias[familia] = tomas
		_ultimo[familia] = -1


## Suelta una toma al azar de la familia (sin repetir la anterior).
func play(familia: String, volumen_db := 0.0, pitch := 1.0) -> void:
	if not _familias.has(familia):
		return
	var tomas: Array = _familias[familia]
	var i := randi() % tomas.size()
	if tomas.size() > 1 and i == int(_ultimo[familia]):
		i = (i + 1) % tomas.size()
	_ultimo[familia] = i
	var p := _pool[_siguiente]
	_siguiente = (_siguiente + 1) % _pool.size()
	p.stream = tomas[i]
	p.volume_db = volumen_db
	p.pitch_scale = pitch
	p.play()


## Enciende un BUCLE (o le cambia el tono si ya sonaba). Cada bucle tiene su
## reproductor, así que el carrete y la recogida no se pisan.
##
## `desde` es el punto (en segundos) AL QUE VUELVE el sonido al llegar al
## final, no por donde empieza: con él, la cabeza del archivo suena UNA sola
## vez y a partir de ahí se repite solo la cola. Es lo que necesita un sonido
## con ARRANQUE (una máquina que se pone en marcha y luego mantiene el ritmo),
## y lo resuelve el propio motor con `loop_offset`, así que no hay que partir
## el .ogg en dos ni encadenar reproductores. Hoy no lo usa nadie —la pesca
## lo estrenó con el carrete y acabó en otro sonido—, pero es la respuesta a
## un problema que se repite en cuanto hay maquinaria de por medio.
func loop_on(familia: String, volumen_db := 0.0, pitch := 1.0,
		desde := 0.0) -> void:
	if not _familias.has(familia):
		return
	var p: AudioStreamPlayer = _bucles.get(familia)
	if p == null:
		p = AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_bucles[familia] = p
		# El recurso se DUPLICA antes de marcarle el bucle: `load()` devuelve
		# la instancia de la caché, y ponerle `loop` ahí se lo pondría también
		# a quien use ese mismo archivo como efecto puntual.
		var s: AudioStream = _familias[familia][0].duplicate()
		if s is AudioStreamOggVorbis:
			s.loop = true
			s.loop_offset = desde
		p.stream = s
	p.volume_db = volumen_db
	p.pitch_scale = pitch
	if not p.playing:
		p.play()


func loop_off(familia: String) -> void:
	var p: AudioStreamPlayer = _bucles.get(familia)
	if p != null and p.playing:
		p.stop()


## Apaga TODOS los bucles. Se llama al cambiar de estado y al cerrar la
## pantalla: un carrete que se queda sonando sobre el menú es de las cosas
## que más cantan.
func todos_los_bucles_off() -> void:
	for f in _bucles:
		loop_off(str(f))
