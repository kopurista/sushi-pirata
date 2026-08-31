class_name TiltShift
extends RefCounted
## EL EFECTO DIORAMA: desenfoca los bordes de arriba y de abajo para que el
## mundo 3D parezca una MAQUETA (el truco del remake de Link's Awakening).
##
## Se monta como una capa por ENCIMA del 3D y por DEBAJO de la interfaz: en el
## remake la maqueta se desenfoca y los menus se quedan nitidos, y aqui igual
## — un HUD borroso solo se leeria peor.
##
##     TiltShift.montar(self)                 # con los valores de siempre
##     TiltShift.montar(self, 0.52, 0.16)     # afinando la banda nitida
##
## Su capa es `CAPA`, que va por debajo del HUD del nivel (que no declara
## numero, o sea 0... ver abajo) y de las capas de aviso del autoload.
##
## OJO CON EL NUMERO DE CAPA: el HUD del nivel es un CanvasLayer sin `layer`
## declarado, o sea layer 0, y los CanvasLayer con el MISMO numero se dibujan
## en orden de arbol. Por eso esta capa va en -1: asi queda garantizado que
## pilla el 3D y no la interfaz, sin depender del orden en que se monten.
const CAPA := -1

## Valores por defecto, medidos contra la pantalla vertical del juego: la
## banda nitida cae un poco por debajo del centro, que es donde vive la accion
## (la cinta y la barra de clientes), y el borde de abajo se desenfoca menos
## porque ahi esta la tabla de elaboracion, que el jugador TOCA.
const FOCO_CENTRO := 0.52
const FOCO_ALTO := 0.16
const CAIDA := 0.26
const FUERZA := 2.6


## Cuelga el efecto de `escena` y devuelve su ColorRect, por si hay que
## apagarlo o moverle el foco en marcha.
static func montar(escena: Node, foco_centro := FOCO_CENTRO,
		foco_alto := FOCO_ALTO, fuerza := FUERZA) -> ColorRect:
	if not ResourceLoader.exists("res://shaders/tilt_shift.gdshader"):
		return null
	var capa := CanvasLayer.new()
	capa.name = "TiltShift"
	capa.layer = CAPA
	escena.add_child(capa)
	var rect := ColorRect.new()
	# TODO lo que cubre la pantalla entera bajo un CanvasLayer va al tamaño de
	# LIENZO, no a 720x1280: en un iPhone el lienzo mide ~720x1560 y con el
	# alto fijo quedaria una franja sin efecto abajo.
	rect.size = GameState.canvas_size()
	rect.position = Vector2.ZERO
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/tilt_shift.gdshader")
	mat.set_shader_parameter("foco_centro", foco_centro)
	mat.set_shader_parameter("foco_alto", foco_alto)
	mat.set_shader_parameter("caida", CAIDA)
	mat.set_shader_parameter("fuerza", fuerza)
	rect.material = mat
	capa.add_child(rect)
	return rect
