extends Node
func _ready() -> void:
	for n in ["map_isla", "map_puerto", "map_enemigo", "map_cueva"]:
		var esc: PackedScene = load("res://assets/models/%s.glb" % n)
		if esc == null:
			print(n, " NO EXISTE"); continue
		var inst: Node3D = esc.instantiate()
		add_child(inst)
		var total := AABB(); var first := true
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = m.transform * m.get_aabb()
			total = a if first else total.merge(a)
			first = false
			print("  %s pos=%s size=%s" % [m.name, a.position, a.size])
		print(n, " TOTAL pos=", total.position, " size=", total.size)
		inst.queue_free()
	get_tree().quit()
