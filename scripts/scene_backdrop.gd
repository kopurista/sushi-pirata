class_name SceneBackdrop
## Fondo 3D reutilizable para pantallas de menú: mar animado (el shader del
## mapa) con el modelo del TIPO de nivel encima (isla, puerto o barco), visto
## con la misma cámara isométrica que el resto del juego.
##
## La UI 2D va en un CanvasLayer por delante, con un velo oscuro para que los
## textos y pergaminos se lean sobre el 3D.

const CAM_PITCH := -35.264
const CAM_YAW := 45.0
const R_HAT := Vector3(0.70710678, 0.0, -0.70710678)
const D_HAT := Vector3(0.70710678, 0.0, 0.70710678)

## Modelo por tipo de nivel; "" (Arcade, sin nivel) usa el barco del jugador.
const KIND_MODELS := {
	"isla": "res://assets/models/map_isla.glb",
	"puerto": "res://assets/models/map_puerto.glb",
	"abordaje": "res://assets/models/map_enemigo.glb",
	"": "res://assets/models/map_barco.glb",
}


## Monta el fondo bajo "root" y devuelve el pivote del modelo (para animarlo).
## band_off: píxeles que se sube la escena en pantalla (positivo = sube).
static func build(root: Node3D, kind: String, cam_size := 19.0,
		band_off := 300.0, foot := 7.0) -> Node3D:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.62, 0.76)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.76, 0.81, 0.9)
	env.ambient_light_energy = 0.95
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -125.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.95, 0.87)
	sun.shadow_enabled = true
	root.add_child(sun)

	var sea_tex: Texture2D = load("res://assets/map/mar.png")
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(120.0, 120.0)
	var sea := MeshInstance3D.new()
	sea.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water_map_3d.gdshader")
	mat.set_shader_parameter("sea_tex", sea_tex)
	mat.set_shader_parameter("tile_scale", Vector2(9.0, 9.0))
	mat.set_shader_parameter("tint", Vector3(0.62, 0.76, 0.96))
	mat.set_shader_parameter("deep_color", Vector3(0.10, 0.24, 0.45))
	mat.set_shader_parameter("flatten", 0.80)
	mat.set_shader_parameter("drift_speed", 0.05)
	# El plano del mar no proyecta sombra sobre nada: fuera del pase de sombras.
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.material_override = mat
	root.add_child(sea)

	var path: String = KIND_MODELS.get(kind, KIND_MODELS[""])
	var pivot := _spawn_model(root, load(path), foot)
	pivot.position.y = -0.1

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(CAM_PITCH, CAM_YAW, 0.0)
	cam.size = cam_size
	root.add_child(cam)
	# Píxeles por unidad en vertical de pantalla, para encuadrar el modelo.
	var ppu_y := (1280.0 / cam_size) * 0.57735
	cam.position = D_HAT * (band_off / ppu_y) + cam.transform.basis.z * 40.0
	cam.make_current()
	return pivot


## Instancia un GLB normalizado por su huella horizontal (igual que el mapa).
static func _spawn_model(root: Node3D, scene: PackedScene, target_foot: float) -> Node3D:
	var pivot := Node3D.new()
	root.add_child(pivot)
	var inst: Node3D = scene.instantiate()
	pivot.add_child(inst)
	var aabb := _merged_aabb(inst)
	var f := maxf(maxf(aabb.size.x, aabb.size.z), 0.0001)
	var s := target_foot / f
	inst.scale = Vector3.ONE * s
	inst.position = -Vector3(
		aabb.position.x + aabb.size.x * 0.5,
		aabb.position.y,
		aabb.position.z + aabb.size.z * 0.5) * s
	return pivot


static func _merged_aabb(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = m.transform * m.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out
