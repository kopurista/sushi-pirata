extends Node3D
## Genera los RETRATOS DE CUERPO ENTERO de los tres chefs
## (assets/ui/chef_m.png, chef_f.png, chef_x.png) desde los propios modelos 3D,
## para que el selector de género de Opciones enseñe al personaje en vez de un
## botón con su nombre.
##
## Se rinden UNA VEZ y se guardan como PNG: tres SubViewports vivos con
## personajes rigueados en un menú serían tres escenas 3D de más por nada.
##
## Se ejecuta como escena (NO con --script: hace falta render de verdad):
##   Godot_v4.7.1-stable_win64_console.exe "res://scenes/tmp_chefs.tscn"

const SIZE := Vector2i(300, 440)
## Alto encuadrado en fracciones de la altura del personaje: 1.16 deja aire
## por arriba y por abajo para que ninguno toque el borde.
const FRAME_F := 1.16
## El pie se apoya un poco por debajo del centro vertical del recuadro.
const CENTER_F := 0.52

var _pending: Array = []
var _t := 0.0


func _ready() -> void:
	for g in CharacterData.PLAYER_GENDERS:
		_pending.append(g)


func _process(_d: float) -> void:
	_t += 1.0
	# Uno por fotograma: el SubViewport necesita un ciclo para dibujar.
	if _t < 2.0:
		return
	if _pending.is_empty():
		print("CHEFS OK")
		get_tree().quit()
		return
	_render(str(_pending.pop_front()))


func _render(gender: String) -> void:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var path := CharacterData.model("chef", gender)
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	vp.add_child(inst)

	# La POSE es la del juego, no la de reposo del rig: los modelos vienen en A
	# (brazos separados) y en el retrato parecían espantapájaros. `CharacterAnim`
	# es el mismo reposo que se les ve en la cocina, con los brazos al costado.
	var skels := inst.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		var anim := CharacterAnim.new(skels[0])
		if anim.has_humanoid_bones():
			anim.reset()
			anim.idle(0.0)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Luz SUAVE: con la del nivel (ambiente 1.15 + sol 1.45) las caras claras se
	# quemaban y el chef neutro salía sin rasgos.
	env.ambient_light_color = Color(0.80, 0.84, 0.92)
	env.ambient_light_energy = 0.72
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-26.0, -30.0, 0.0)
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.97, 0.92)
	vp.add_child(sun)

	var aabb := AABB()
	var first := true
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = m.global_transform * m.get_aabb()
		aabb = a if first else aabb.merge(a)
		first = false
	var body_h := aabb.size.y
	var center := Vector3(aabb.position.x + aabb.size.x * 0.5,
		aabb.position.y + body_h * CENTER_F,
		aabb.position.z + aabb.size.z * 0.5)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = body_h * FRAME_F
	# De frente (el personaje mira a +Z) y un pelín desde arriba.
	cam.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
	vp.add_child(cam)
	cam.position = center + cam.transform.basis.z * 8.0
	cam.make_current()

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(
		"res://assets/ui/chef_%s.png" % gender))
	print("chef_%s <- %s (alto=%.2f)" % [gender, path.get_file(), body_h])
	vp.queue_free()
