extends Node
func _ready() -> void:
	for n in ["grumete", "chef", "pirata", "vip"]:
		var path := "res://assets/models/%s_rig.glb" % n
		if not ResourceLoader.exists(path):
			continue
		var inst: Node3D = (load(path) as PackedScene).instantiate()
		add_child(inst)
		var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
		var a := CharacterAnim.new(sk)
		var want := ["Pelvis", "L_Hip", "L_Knee", "L_Ankle", "R_Hip", "R_Knee",
			"R_Ankle", "Spine1", "Neck", "L_Shoulder", "L_Elbow", "L_Wrist",
			"R_Shoulder", "R_Elbow", "R_Wrist"]
		var missing := []
		for w in want:
			if not a.resolved(w):
				missing.append(w)
		print("%-9s %2d huesos | humanoide: %s | faltan: %s" % [n,
			sk.get_bone_count(), a.has_humanoid_bones(),
			"nada" if missing.is_empty() else ", ".join(missing)])
		inst.queue_free()
	get_tree().quit()
