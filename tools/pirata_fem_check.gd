extends Node3D
## HERRAMIENTA (pareja de tools/kill_layer.py): renderiza la cabeza real de pirata_fem_rig.glb (misma
## camara que tools/head_icons.gd) para verificar el parche, SIN tocar
## assets/ui/head_A_f.png.

const SIZE := 384
const FRAME_F := 0.34
const HEAD_DROP_F := 0.13


func _ready() -> void:
	await get_tree().process_frame
	_render()


func _render() -> void:
	DirAccess.make_dir_absolute("res://_shot")
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var inst: Node3D = (load("res://assets/models/pirata_fem_rig.glb") as PackedScene).instantiate()
	vp.add_child(inst)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 0.95)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28.0, -28.0, 0.0)
	sun.light_energy = 1.2
	vp.add_child(sun)

	var aabb := AABB()
	var first := true
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = m.global_transform * m.get_aabb()
		aabb = a if first else aabb.merge(a)
		first = false
	var body_h := aabb.size.y
	var center := Vector3(aabb.position.x + aabb.size.x * 0.5,
		aabb.position.y + body_h * (1.0 - HEAD_DROP_F),
		aabb.position.z + aabb.size.z * 0.5)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = body_h * FRAME_F
	cam.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	vp.add_child(cam)
	cam.position = center + cam.transform.basis.z * 6.0
	cam.make_current()

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png("res://_shot/cara_real.png")
	print("guardado, body_h=", body_h)
	get_tree().quit()
