extends Node3D
## Vaivén de un adorno del barco (la bandera pirata, el koinobori): el pivote
## gira suave alrededor de su eje, como tela que toma y suelta el viento. Va
## en su propio script porque los adornos se montan por código
## (`ColVisibles`) y un tween en bucle no puede hacer un seno continuo.
class_name ColProp

## Amplitud (grados) y velocidad del vaivén; cada adorno pone las suyas.
var amp := 9.0
var vel := 1.6
var _t := 0.0
var _base := 0.0


func _ready() -> void:
	_base = rotation_degrees.y
	# Cada adorno arranca en un punto distinto del vaivén, o la bandera y el
	# koinobori se mecerían clavados al unísono como un mecanismo.
	_t = fmod(float(get_instance_id()) * 0.37, TAU)


func _process(delta: float) -> void:
	if not GameState.animations_on():
		return
	_t += delta * vel
	rotation_degrees.y = _base + sin(_t) * amp
	rotation_degrees.z = cos(_t * 0.7) * amp * 0.25
