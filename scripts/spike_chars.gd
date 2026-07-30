extends Node3D
## DEMO TEMPORAL de los cinco personajes andando a la vez, cada uno con sus
## propias proporciones y todos movidos por el mismo CharacterAnim.
## Borrar junto con scenes/spike_chars.tscn cuando termine el port.
const ALL := ["grumete", "chef", "pirata", "capitan", "vip"]
var _anims: Array = []
var _pivots: Array = []
var _scales: Array = []
var _t := 0.0
var _shots := []   # vacio = demo en vivo; con valores, captura y cierra
var _i := 0

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.62, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.80, 0.90)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -125, 0)
	sun.light_energy = 1.1; sun.shadow_enabled = true; add_child(sun)
	for i in range(22):
		var m := BoxMesh.new(); m.size = Vector3(20, 0.2, 0.5)
		var mi := MeshInstance3D.new(); mi.mesh = m
		mi.position = Vector3(0, -0.1, -5 + i * 0.5)
		var mat := StandardMaterial3D.new()
		var t := 0.0 if i % 2 == 0 else 0.05
		mat.albedo_color = Color(0.52 + t, 0.35 + t, 0.20 + t); mat.roughness = 0.95
		mi.material_override = mat; add_child(mi)
	var right := Vector3(1, 0, -1).normalized()
	for k in ALL.size():
		var pivot := Node3D.new(); add_child(pivot)
		pivot.position = right * (float(k) - 2.0) * 1.05
		var inst: Node3D = (load("res://assets/models/%s_rig.glb" % ALL[k]) as PackedScene).instantiate()
		pivot.add_child(inst)
		var aabb := AABB(); var first := true
		for mi2 in inst.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = mi2.transform * mi2.get_aabb()
			aabb = a if first else aabb.merge(a); first = false
		var s := 1.75 / aabb.size.y
		inst.scale = Vector3(s, s, s)
		inst.position = -Vector3(aabb.position.x + aabb.size.x * 0.5, aabb.position.y,
			aabb.position.z + aabb.size.z * 0.5) * s
		pivot.rotation_degrees.y = 30.0
		var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
		_anims.append(CharacterAnim.new(sk)); _pivots.append(pivot); _scales.append(s)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(-35.264, 45, 0)
	cam.size = 10.5
	add_child(cam)
	cam.position = Vector3(0, 0.9, 0) + cam.transform.basis.z * 25.0
	cam.make_current()

func _process(d: float) -> void:
	_t += d
	for k in _anims.size():
		var a: CharacterAnim = _anims[k]
		a.reset(); a.walk(_t + k * 0.13)
		_pivots[k].position.y = a.walk_bob(_t + k * 0.13, _scales[k])
	if _i < _shots.size() and _t >= _shots[_i]:
		get_viewport().get_texture().get_image().save_png("res://rig_shot_%d.png" % _i)
		_i += 1
		if _i == _shots.size():
			print("SHOTS OK"); get_tree().quit()
