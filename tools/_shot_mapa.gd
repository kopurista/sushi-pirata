extends Node
## HELPER TEMPORAL. `daily_last` se toca SOLO EN MEMORIA para que el cartel del
## bonus no tape el mapa; el guardado se restaura a mano al terminar.
func _ready() -> void:
	GameState.booted = true
	GameState.daily_last = Time.get_date_string_from_system()
	await get_tree().create_timer(0.5).timeout
	var m := get_parent()
	m.call("_go_adventure")
	await get_tree().create_timer(3.0).timeout
	get_viewport().get_texture().get_image().save_png("res://m_submenu.png")
	m.call("_select", "nivel_7", true)
	await get_tree().create_timer(1.6).timeout
	get_viewport().get_texture().get_image().save_png("res://m_ficha.png")
	m.call("_select", "nivel_15", true)
	await get_tree().create_timer(1.6).timeout
	get_viewport().get_texture().get_image().save_png("res://m_ficha2.png")
	print("CAPTURA ficha")
	get_tree().quit()
