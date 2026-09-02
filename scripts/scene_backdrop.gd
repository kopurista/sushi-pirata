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
	"cueva": "res://assets/models/map_cueva.glb",
	"": "res://assets/models/map_barco.glb",
}


## AJUSTE DE IMAGEN COMÚN a todas las escenas 3D del juego. Va aquí, en un solo
## sitio, para que el mundo tenga el mismo aire en el nivel, el mapa, el menú y
## la tienda, y para que retocarlo o quitarlo sea UNA función.
##
## Son las tres cosas que el renderer del juego (gl_compatibility) sí soporta,
## COMPROBADAS midiendo la imagen antes y después:
##   - GLOW con umbral ALTO: solo florece lo que de verdad emite luz (faroles,
##     cristales de la cueva, el brillo del agua), no la escena entera.
##   - Un toque de contraste y saturación, porque el ambiente plano de este
##     montaje deja los colores algo lavados.
## Lo que NO se usa, y se probó: el TONEMAP filmic. Comprime los medios, y
## estos escenarios están pintados en lineal y con luz plana: la isla salía con
## la arena apagada y verdosa, más sucia que antes (medido y visto en un A/B con
## el árbol congelado). En la cueva no aportaba nada. El tonemap se queda en
## LINEAR, que es lo que asume el arte.
## Lo que NO se usa: la NIEBLA de profundidad. Funciona, pero a la escala de
## estos escenarios se come la imagen y además se cuela en la interfaz 2D
## (medido: 38 de diferencia media sobre el pergamino, contra 0.00 del glow y
## del tonemap, que solo tocan el 3D).
##
## `oscuro` es para la CUEVA: allí el umbral del glow baja, que es lo que hace
## que los cristales sean lo único que llegue a florecer.
static func apply_look(env: Environment, oscuro := false) -> void:
	# El pase de post-proceso solo en calidad ALTA: cuesta +0,13 ms por
	# fotograma (un 18%) para un 1-3% de cambio en la imagen, y en un móvil esa
	# cuenta no sale. Ver GameState.post_fx_on().
	if not GameState.post_fx_on():
		env.glow_enabled = false
		env.adjustment_enabled = false
		return
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_strength = 1.0
	env.glow_bloom = 0.10
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 0.72 if oscuro else 1.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.12 if oscuro else 1.08


## LUZ DE RELLENO: una segunda direccional muy floja desde el lado contrario al
## sol. Hasta ahora las caras en sombra las pintaba SOLO el ambiente, que es un
## color plano y las dejaba sin volumen; con esto cogen un poco de forma sin
## tener que subir el ambiente general (que aplanaría el resto).
##
## Va sin sombras, como todas las luces del juego.
static func fill_light() -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-28.0, 55.0, 0.0)
	l.light_energy = 0.34
	l.light_color = Color(0.72, 0.82, 1.0)
	l.shadow_enabled = false
	return l


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
	apply_look(env)
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
	root.add_child(fill_light())

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(120.0, 120.0)
	mesh.subdivide_width = 40
	mesh.subdivide_depth = 40
	var sea := MeshInstance3D.new()
	sea.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water_ww.gdshader")
	mat.set_shader_parameter("espuma", load("res://assets/map/espuma_ww.webp"))
	mat.set_shader_parameter("tile", Vector2(120.0, 120.0))
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
	# Las manchas SON las sombras del juego: el ajuste "Sombras" las apaga.
	mi.visible = GameState.shadows_on()
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
