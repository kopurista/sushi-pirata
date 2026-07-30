extends Node3D
var _a: CharacterAnim
var _t := 0.0
var _shots := [0.20, 0.55]
var _i := 0
func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42,0.62,0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78,0.83,0.92)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52,-125,0); sun.light_energy = 1.1
	sun.shadow_enabled = true   # CON sombras, como en el juego
	add_child(sun)
	# suelo
	var fm := BoxMesh.new(); fm.size = Vector3(6,0.2,6)
	var fi := MeshInstance3D.new(); fi.mesh = fm; fi.position = Vector3(0,-0.1,0)
	var fmat := StandardMaterial3D.new(); fmat.albedo_color = Color(0.55,0.38,0.22)
	fi.material_override = fmat; add_child(fi)
	var inst: Node3D = (load("res://assets/models/chef_rig.glb") as PackedScene).instantiate()
	add_child(inst)
	var aabb := AABB(); var first := true
	for m in inst.find_children("*","MeshInstance3D",true,false):
		var a: AABB = m.transform * m.get_aabb()
		aabb = a if first else aabb.merge(a); first = false
	var s := 1.75/aabb.size.y
	inst.scale = Vector3(s,s,s)
	inst.position = -Vector3(aabb.position.x+aabb.size.x*0.5, aabb.position.y, aabb.position.z+aabb.size.z*0.5)*s
	print("AABB del modelo: min y=%.3f  alto=%.3f  ancho=%.3f  fondo=%.3f" % [aabb.position.y, aabb.size.y, aabb.size.x, aabb.size.z])
	var sk: Skeleton3D = inst.find_children("*","Skeleton3D",true,false)[0]
	_a = CharacterAnim.new(sk)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(-30,35,0); cam.size = 1.6
	add_child(cam); cam.position = Vector3(0,0.30,0)+cam.transform.basis.z*20.0; cam.make_current()
func _process(d: float) -> void:
	_t += d
	_a.reset()
	if _t > 0.3: _a.walk(_t)
	if _i < _shots.size() and _t >= _shots[_i]:
		get_viewport().get_texture().get_image().save_png("res://rig_shot_%d.png"%_i)
		_i += 1
		if _i == _shots.size(): print("SHOTS OK"); get_tree().quit()
