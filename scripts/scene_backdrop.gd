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
	# Sin sombras proyectadas en todo el juego: cada cosa lleva su mancha
	# fija (SceneBackdrop.blob_shadow).
	sun.shadow_enabled = false
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

	# "mar" = sin modelo, solo agua (el fondo del modo Arcade).
	var pivot: Node3D = null
	if kind != "mar":
		var path: String = KIND_MODELS.get(kind, KIND_MODELS[""])
		pivot = _spawn_model(root, load(path), foot)
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


# --------------------------------------------------------- sombras fijas

## Textura de la mancha de sombra: un degradado radial. Se genera UNA vez y la
## comparten todas las manchas del juego.
static var _blob_tex: Texture2D = null
static var _blob_mat: StandardMaterial3D = null


## Mancha de sombra plana para poner bajo un personaje o un objeto.
##
## El juego NO usa sombras proyectadas: la luz direccional va sin shadow map.
## Con personajes que se balancean y palmeras de decenas de piezas, la sombra
## dinámica bailaba, mostraba acné y costaba un pase de dibujo entero. Una
## mancha fija se ve mejor, no parpadea y es un solo triángulo doble.
static func blob_shadow(size_x: float, size_z: float) -> MeshInstance3D:
	if _blob_tex == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var d := Vector2(x - 31.5, y - 31.5).length() / 31.5
				var a: float = clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(0, 0, 0, a * a * 0.62))
		_blob_tex = ImageTexture.create_from_image(img)
		_blob_mat = StandardMaterial3D.new()
		_blob_mat.albedo_texture = _blob_tex
		_blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blob_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		# Sin escritura de profundidad: varias manchas superpuestas (un cliente
		# junto a un taburete) no se recortan entre sí.
		_blob_mat.no_depth_test = false
		_blob_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var plane := PlaneMesh.new()
	plane.size = Vector2(size_x, size_z)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = _blob_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Fuera del fusionado por color: lleva material propio y translúcido.
	mi.add_to_group(GeometryBatch.NO_BATCH_GROUP)
	return mi


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
