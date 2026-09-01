class_name TiltShift
extends RefCounted
## EL EFECTO DIORAMA: deja nitido un CIRCULO en el centro y desenfoca hacia
## fuera, para que el mundo 3D parezca una MAQUETA (el remake de Zelda).
##
## Se monta como una capa por ENCIMA del 3D y por DEBAJO de la interfaz: en el
## remake la maqueta se desenfoca y los menus se quedan nitidos, y aqui igual
## — un HUD borroso solo se leeria peor.
##
##     TiltShift.montar(self)                 # con los valores de siempre
##     TiltShift.montar(self, Vector2(0.5, 0.6), 0.5)  # afinando el circulo
##
## Su capa es `CAPA`, que va por debajo del HUD del nivel (que no declara
## numero) y de las capas de aviso del autoload.
##
## OJO CON EL NUMERO DE CAPA: el HUD del nivel es un CanvasLayer sin `layer`
## declarado, o sea layer 0, y los CanvasLayer con el MISMO numero se dibujan
## en orden de arbol. Por eso esta capa va en -1: asi queda garantizado que
## pilla el 3D y no la interfaz, sin depender del orden en que se monten.
const CAPA := -1

## Valores por defecto, medidos contra la pantalla vertical del juego: el
## circulo nitido se centra un poco por debajo del medio, que es donde vive la
## accion (la cinta y la barra de clientes).
const FOCO_CENTRO := Vector2(0.5, 0.52)
## Radio de lo nitido, en fracciones del ANCHO del lienzo.
const FOCO_RADIO := 0.42
const CAIDA := 0.38
## Desenfoque maximo. Va SUAVE a proposito (pedido por el usuario): con 2.6 el
## borde se comia demasiado y el efecto cantaba mas que ambientar.
const FUERZA := 1.7


## Cuelga el efecto de `escena` y devuelve su ColorRect, por si hay que
## apagarlo o moverle el foco en marcha.
static func montar(escena: Node, foco_centro := FOCO_CENTRO,
		foco_radio := FOCO_RADIO, fuerza := FUERZA) -> ColorRect:
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
	var lienzo := GameState.canvas_size()
	rect.size = lienzo
	rect.position = Vector2.ZERO
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/tilt_shift.gdshader")
	mat.set_shader_parameter("foco_centro", foco_centro)
	mat.set_shader_parameter("foco_radio", foco_radio)
	mat.set_shader_parameter("caida", CAIDA)
	mat.set_shader_parameter("fuerza", fuerza)
	# El aspecto REAL del lienzo, o el circulo sale elipse (720x1280 -> 1.78).
	mat.set_shader_parameter("aspecto", lienzo.y / maxf(lienzo.x, 1.0))
	rect.material = mat
	capa.add_child(rect)
	return rect
