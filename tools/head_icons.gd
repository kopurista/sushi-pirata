extends Node3D
## Genera los ICONOS DE CABEZA de los clientes (assets/ui/head_*.png) a partir
## de los propios modelos 3D, para que el contador de clientes del HUD use el
## mismo arte low poly que el mundo (recortar el sprite 2D voxel viejo habria
## desentonado).
##
## Encuadra la cabeza de cada rig con una camara ortogonal de frente, sobre
## fondo transparente, y guarda un PNG cuadrado por tipo. Se ejecuta como
## escena (NO con --script: hace falta render de verdad):
##   Godot_v4.7.1-stable_win64_console.exe "res://scenes/tmp_heads.tscn"

## sufijo del icono -> modelo del que se renderiza. SIEMPRE el modelo RIGUEADO,
## que es el que sale en el juego: los femeninos se sacaban de la version sin
## riguear y, al rehacerlos, el icono se quedo con la cara antigua.
const OUT := {
	# SOLO el personaje NUEVO en cada pasada: regenerar los demás es jugar a la
	# lotería de render (salen manchados a veces) y no hay motivo para tocarlos.
	# La lista completa, por si hay que rehacer alguno:
	#   "E": "grumete_rig", "A": "pirata_rig", "G": "capitan_rig",
	#   "E_f": "grumete_fem_rig", "A_f": "pirata_fem_rig",
	#   "G_f": "capitan_fem_rig", "P": "pablo_rig", "K": "kappa_rig",
	#   "C": "cai_rig", "AL": "alice_rig",
	"AL": "alice_rig",
}
const SIZE := 192
## Encuadre en fracciones de la ALTURA TOTAL del personaje, no del hueso de la
## cabeza: la distancia Neck->Head cambia muchisimo de un rig a otro (0.05 en
## el pirata, 0.16 en el capitan) y encuadrar por ella daba cabezas cortadas en
## uno y diminutas en otro. Por altura total salen las tres igual de grandes.
const FRAME_F := 0.34
## Ajuste por icono cuando el modelo se sale de la norma: el sombrero de Pablo
## es mucho más alto que el del resto y con el encuadre general se le cortaba
## por arriba.
## Y el Kappa es un cabezón con plato y pelambrera: media altura es cabeza.
const FRAME_OVERRIDE := { "P": 0.44, "K": 0.52, "AL": 0.22 }
## Centro del encuadre bajando desde la coronilla (incluye gorro/sombrero).
const HEAD_DROP_F := 0.13
## Ajuste del centro por icono, cuando la coronilla no está donde parece. La
## melena de Alice le baja mucho la caja, así que su cara queda MÁS ARRIBA de
## lo que dice la regla general.
const DROP_OVERRIDE := { "AL": 0.10 }
## Y ajuste de LUZ por icono: la piel de Alice es muy pálida y con la luz
## general se le quemaba la cara a blanco liso, sin ojos ni boca (la misma
## lección que `chef_portraits.gd`, donde las caras claras se pasaban de luz).
const LIGHT_OVERRIDE := { "AL": 0.5 }

var _pending: Array = []
var _t := 0.0


func _ready() -> void:
	for id in OUT:
		_pending.append([id, OUT[id]])


func _process(_d: float) -> void:
	_t += 1.0
	# Un tipo por fotograma: el SubViewport necesita un ciclo para dibujar.
	if _t < 2.0:
		return
	if _pending.is_empty():
		print("HEADS OK")
		get_tree().quit()
		return
	var job: Array = _pending.pop_front()
	_render(job[0], job[1])


func _render(id: String, model: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var inst: Node3D = (load("res://assets/models/%s.glb" % model) as PackedScene).instantiate()
	vp.add_child(inst)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 0.95)
	var luz := float(LIGHT_OVERRIDE.get(id, 1.0))
	env.ambient_light_energy = 1.0 * luz
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28.0, -28.0, 0.0)
	sun.light_energy = 1.2 * luz
	vp.add_child(sun)

	# La cabeza se encuadra por la caja del modelo: centro un poco por debajo
	# de la coronilla y ancho proporcional a la altura total.
	var aabb := AABB()
	var first := true
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = m.global_transform * m.get_aabb()
		aabb = a if first else aabb.merge(a)
		first = false
	var body_h := aabb.size.y
	var center := Vector3(aabb.position.x + aabb.size.x * 0.5,
		aabb.position.y + body_h * (1.0 - float(DROP_OVERRIDE.get(id, HEAD_DROP_F))),
		aabb.position.z + aabb.size.z * 0.5)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = body_h * float(FRAME_OVERRIDE.get(id, FRAME_F))
	# De frente (el personaje mira a +Z) y un pelin desde arriba.
	cam.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	vp.add_child(cam)
	cam.position = center + cam.transform.basis.z * 6.0
	cam.make_current()

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://assets/ui/head_%s.png" % id))
	print("head_%s -> %dx%d (body_h=%.2f)" % [id, img.get_width(), img.get_height(), body_h])
	vp.queue_free()
