extends Node
## SONDA TEMPORAL del efecto del tiron. Se borra tras la pasada.

var menu: Node = null
var fg: Control = null
var t := 0.0
var step := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.booted = true
	menu = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)


func _process(delta: float) -> void:
	t += delta
	if step == 0 and t > 1.2:
		step = 1
		menu._go_fishing()
	elif step == 1 and t > 2.4:
		fg = menu.fishing_ui
		step = 2
		fg.roll = { "type": "fish", "fish_id": "atun", "tier": 2, "size": 0.8 }
		fg.tier = 2
		fg.catch_size = 0.8
		fg.bobber = Vector2(300, 880)
		fg.bobber_out = true
		fg._start_fight()
		fg.phases_left = 0
		fg.energy = 0.5
		fg.tension = 0.3
		_shot("zzr_normal")
	elif step == 2 and t > 2.9:
		step = 3
		# TIRON: se enciende el efecto entero.
		fg.speed_left = 6.0
		fg.instruction.text = "¡Tira con fuerza!\n¡PULSA RÁPIDO!"
	elif step == 3 and t > 3.6:
		step = 4
		_shot("zzr_tiron")
		print("rush_on=%s fx_visible=%s fade=%.2f cam_shake=%.2f cam_zoom=%.2f" \
			% [fg.rush_on, fg.rush_fx.visible, fg._rush_fade(),
				menu.cam_shake, menu.cam_zoom])
		print("zone.scale=%.3f rod.x=%.1f (base %.1f)" \
			% [fg.zone.scale.x, fg.rod.position.x, fg.ROD_RECT.position.x])
	elif step == 4 and t > 4.2:
		step = 5
		_shot("zzr_tiron2")
		# Fin del tiron: todo debe volver.
		fg.speed_left = 0.0
	elif step == 5 and t > 5.4:
		step = 6
		_shot("zzr_vuelta")
		print("TRAS EL TIRON rush_on=%s fade=%.2f cam_shake=%.2f zone.scale=%.3f cam.size=%.2f" \
			% [fg.rush_on, fg._rush_fade(), menu.cam_shake, fg.zone.scale.x,
				menu.cam.size])
		get_tree().quit()


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("res://%s.png" % name)
	print("SHOT ", name)
