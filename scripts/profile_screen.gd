extends Node3D
## PERFIL: el CARTEL DE RECOMPENSA del jugador en pantalla propia, abierta
## desde el SUBMENÚ del menú principal. Es el mismo `WantedPoster` de la
## bienvenida de David, con el nombre BLOQUEADO (se pone una sola vez) y el
## selector de título. Antes vivía como pestaña de Opciones; al mudarse aquí,
## Opciones se quedó con gráficos, guía y progreso.

const PrepBoard := preload("res://scripts/prep_board.gd")

var ui: CanvasLayer = null
var backdrop: Node3D = null
var apply_btn: Button = null
var cartel: WantedPoster = null
var _t := 0.0


func _ready() -> void:
	Engine.max_fps = GameState.fps_for(false)
	backdrop = SceneBackdrop.build(self, "", 17.0, 40.0, 6.0)
	_setup_ui()
	GameState.take_transition()


func _process(delta: float) -> void:
	_t += delta
	if backdrop != null and GameState.animations_on():
		backdrop.rotation_degrees.y = 205.0 + sin(_t * 0.25) * 8.0
		backdrop.rotation_degrees.z = sin(_t * 0.8) * 2.2
		backdrop.position.y = -0.1 + sin(_t * 1.2) * 0.1


func _setup_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_top = GameState.safe_top()
	ui.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.06, 0.09, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.offset_top = -GameState.safe_top()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 18.0
	bar.offset_top = 18.0
	bar.offset_right = -18.0
	bar.offset_bottom = 86.0
	bar.add_theme_constant_override("separation", 10)
	root.add_child(bar)
	var back := PrepBoard.make_back_button()
	back.pressed.connect(func() -> void:
		GameState.fade_to_scene("res://scenes/main_menu.tscn", 0.35, 0.45))
	bar.add_child(back)
	var title := PrepBoard.make_title("Perfil")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(150, 0)
	bar.add_child(pad)

	# El cartel, A ESCALA para dejar sitio al botón de aplicar. Va CON tablón:
	# aquí no hay otro pergamino detrás, la pantalla es suya.
	var lienzo := GameState.canvas_size()
	var medida := WantedPoster.panel_size(true)
	var alto_util := lienzo.y - GameState.safe_top() - 100.0 - 118.0
	var k: float = minf((lienzo.x - 40.0) / medida.x, alto_util / medida.y)
	var hueco := Control.new()
	hueco.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hueco.offset_top = 100.0
	hueco.offset_left = (lienzo.x - medida.x * k) * 0.5
	hueco.offset_right = hueco.offset_left + medida.x * k
	hueco.offset_bottom = 100.0 + medida.y * k
	root.add_child(hueco)
	cartel = WantedPoster.new()
	cartel.editable_name = false
	cartel.show_titles = true
	cartel.scale = Vector2(k, k)
	hueco.add_child(cartel)
	cartel.edited.connect(_refresh_apply)

	apply_btn = Button.new()
	apply_btn.text = "Aplicar cambios"
	apply_btn.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	apply_btn.offset_left = 130.0
	apply_btn.offset_right = -130.0
	apply_btn.offset_top = -104.0 - GameState.safe_bottom()
	apply_btn.offset_bottom = -24.0 - GameState.safe_bottom()
	PrepBoard.skin_button(apply_btn)
	PrepBoard.add_press_feedback(apply_btn)
	apply_btn.add_theme_font_size_override("font_size", 27)
	apply_btn.pressed.connect(func() -> void:
		cartel.aplicar()
		GameState.save_game()
		_refresh_apply())
	root.add_child(apply_btn)
	_refresh_apply()


func _refresh_apply() -> void:
	var dirty := cartel != null and cartel.hay_cambios()
	apply_btn.disabled = not dirty
	apply_btn.modulate = Color.WHITE if dirty else Color(0.68, 0.64, 0.58)
