@tool
extends EditorScenePostImport
## Recorta el triangulaje de los modelos que se pasan de presupuesto, EN LA
## IMPORTACIÓN. Así las rutas `.glb` del juego no cambian en ningún sitio y el
## `.glb` original se conserva intacto en el repositorio.
##
## Por qué hace falta: los modelos vienen de imagen→3D (Ludo) y salen con una
## densidad que no tiene nada que ver con su tamaño en pantalla. Medido: una
## `caja.glb` traía 19.592 triángulos —tres cajas eran el 34% de todo el nivel—
## y `futomaki_salmon` 29.566 cuando los otros diez platos rondan los 2.400.
##
## El LOD automático NO sirve aquí: con el renderer GL Compatibility no se
## aplica (medido en la tienda: 50.812 triángulos instanciados, 51.386
## dibujados, o sea el modelo entero a plena densidad aunque se vea pequeño).
## Lo que sí sirve es el simplificador de meshoptimizer que Godot lleva dentro,
## expuesto en `ImporterMesh.generate_lods()`: se genera la cadena de LODs y se
## SUSTITUYE la malla por el escalón que entra en presupuesto.
##
## Para añadir un modelo: una línea en BUDGETS y `import_script/path` apuntando
## aquí en su `.import`.

## Triángulos máximos por modelo (nombre de archivo sin extensión).
const BUDGETS := {
	# Entrado por Meshy (tools/meshy.py).
	"isla_juego_ov": 6000,
	# Entrado por Meshy (tools/meshy.py).
	"chef_ov_rig": 4000,
	# Entrado por Meshy (tools/meshy.py).
	"chef_ov": 3500,
	# Entrado por Meshy (tools/meshy.py).
	"canon_pirata": 3000,
	# Atrezzo estático, se ve a pocos píxeles desde la cámara isométrica.
	"caja": 800,
	"farola": 900,
	"cofre": 900,
	# Platos: los otros diez rondan 2.400, estos venían a 29.500.
	"futomaki_salmon": 2500,
	"gunkan_tartar": 2500,
	"gunkan_ikura": 2500,
	"hana_maki": 2500,
	"edamame": 2500,
	"maki_pepino": 2500,
	# El cuenco del sunomono es geometría MUY simple y con 2.500 el
	# simplificador lo dejaba en 48 triángulos (una caja): medido y subido.
	"sunomono": 9000,
	"temaki": 2500,
	"aburi": 2500,
	"aburi_atun": 2500,
	"chirashi": 2500,
	"udon": 2500,
	"gari": 2500,
	"te_verde": 2500,
	"fugu": 2500,
	"moriawase": 2500,
	"mochi": 2500,
	"dorayaki": 2500,
	"taiyaki": 2500,
	"nigiri_anguila": 2500,
	"yaki_onigiri": 2500,
	"caldo_dashi": 2500,
	"uramaki_california": 2500,
	"dragon_roll": 2500,
	"nigiri_wagyu": 2500,
	"udon_tempura": 2500,
	"salmon_tsuke_don": 2500,
	# Nodos del mapa: hay NUEVE en pantalla a la vez. OJO, NO BAJAR DE AQUÍ:
	# con 4.000 el simplificador no solo suavizaba, DESTROZABA los modelos —
	# fundía vértices de islas UV distintas y el puerto salía con rayas rojas
	# del faro esparcidas por la roca gris, además de perder enteros un
	# pantalán y sus cajas. A 8.000 (la cadena de LOD cae en ~7.700) se ven
	# igual que sin decimar.
	"map_isla": 8000,
	"map_puerto": 8000,
	"map_cueva": 8000,
	"map_enemigo": 8000,
	"map_barco": 8000,
	# Personajes: el chef y los clientes rondan los 6.000, estos venían a 19.500.
	"tendero": 6000,
	"chef_neutro_rig": 6000,
	"chef_fem_rig": 6000,
	"grumete_fem_rig": 6000,
	"pirata_fem_rig": 6000,
	"capitan_fem_rig": 6000,
	"vip_fem_rig": 6000,
	"pablo_rig": 6000,
	"kappa_rig": 6000,
	"cai_rig": 6000,
	"alice_rig": 6000,
	"miku_rig": 6000,
	"nach_rig": 6000,
	"sirena_rig": 6000,
	"maki_aguacate_mejorado": 2500,
	# Tanda del mar 2 (24-8-2026).
	"tsukemono": 2500,
	"bol_arroz": 2500,
	"ensalada_wakame": 2500,
	"gunkan_shiitake": 2500,
	"nigiri_caballa": 2500,
	# El nigiri de besugo es geometria MUY simple y con 2.500 el simplificador
	# lo dejaba en 32 triangulos (la trampa del sunomono): medido y subido.
	"nigiri_besugo": 9000,
	"nigiri_pargo": 2500,
	"gunkan_jurel": 2500,
	"barbo_ahumado": 2500,
	"takoyaki_pulpo": 2500,
	"takoyaki_pulpo_medio": 2500,
	"gyozas": 2500,
	"toro_aleta": 2500,
	"tataki_atun_rojo": 2500,
}

## Tope de pasadas. Cada `generate_lods` recorta ~50%, así que 6 pasadas dan de
## sobra para bajar de 30.000 a 800; el tope solo evita un bucle infinito si el
## simplificador deja de reducir (malla ya mínima).
const MAX_PASSES := 6


func _post_import(scene: Node) -> Object:
	var key := get_source_file().get_file().get_basename()
	var budget: int = BUDGETS.get(key, 0)
	for inst in _mesh_instances(scene):
		var am: ArrayMesh = inst.mesh as ArrayMesh
		if am == null:
			continue
		# Las formas de mezcla obligarían a reconstruir también sus arrays; no
		# hay ningún modelo del juego que las use, así que se dejan intactas.
		if am.get_blend_shape_count() > 0:
			continue
		# En 4.7 el post-import recibe la escena YA convertida (MeshInstance3D
		# con ArrayMesh), no ImporterMeshInstance3D. ImporterMesh se usa aquí
		# solo como puerta al simplificador de meshoptimizer.
		var im := ImporterMesh.new()
		for s in am.get_surface_count():
			im.add_surface(am.surface_get_primitive_type(s),
				am.surface_get_arrays(s), [], {},
				am.surface_get_material(s), am.surface_get_name(s),
				am.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		var before := _tris(im)
		var after := before
		if budget > 0 and before > budget:
			after = _fit(im, budget)
		inst.mesh = _commit(im, am.resource_name)
		if budget > 0:
			print("[decimate] %-22s %6d -> %5d triángulos (tope %d)"
				% [key, before, after, budget])
	return scene


## Vuelca la malla a ArrayMesh SIN tangentes. `ensure_tangents=false` solo evita
## generarlas cuando faltan, y estos GLB ya vienen con ellas de origen: son 4
## flotantes por vértice que no usa nadie, porque en el juego no hay un solo
## normal map (ni anisotropía) que las lea.
func _commit(im: ImporterMesh, res_name: String) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in im.get_surface_count():
		var arrays: Array = im.get_surface_arrays(s)
		arrays[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(im.get_surface_primitive_type(s), arrays,
			[], {}, im.get_surface_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		out.surface_set_material(s, im.get_surface_material(s))
		out.surface_set_name(s, im.get_surface_name(s))
	out.resource_name = res_name
	return out


## Baja la malla hasta el presupuesto, a base de pasadas de simplificación.
func _fit(im: ImporterMesh, budget: int) -> int:
	var tris := _tris(im)
	for _pass in MAX_PASSES:
		if tris <= budget:
			break
		# El reparto es proporcional: si hay varias superficies, cada una
		# conserva su peso relativo en vez de recortarse todas por igual.
		var ratio := float(budget) / float(tris)
		if not _shrink(im, ratio):
			break  # el simplificador ya no reduce más: dejarlo como está
		var now := _tris(im)
		if now >= tris:
			break
		tris = now
	return tris


## Una pasada: genera LODs y se queda, por superficie, con el escalón más
## detallado que cumpla la cuota. Devuelve false si no hubo reducción posible.
func _shrink(im: ImporterMesh, ratio: float) -> bool:
	im.generate_lods(25.0, 60.0, [])
	var rebuilt: Array = []
	var changed := false
	for s in im.get_surface_count():
		var arrays: Array = im.get_surface_arrays(s)
		var base_idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var quota := int(base_idx.size() / 3 * ratio)
		var pick: PackedInt32Array = base_idx
		for l in im.get_surface_lod_count(s):
			var lod: PackedInt32Array = im.get_surface_lod_indices(s, l)
			# Los LODs vienen de más a menos detalle: vale el primero que entre.
			if lod.size() / 3 <= quota:
				pick = lod
				break
			pick = lod
		if pick.size() < base_idx.size():
			changed = true
		rebuilt.append({
			"arrays": _rebuild(arrays, pick),
			"mat": im.get_surface_material(s),
			"name": im.get_surface_name(s),
			"fmt": im.get_surface_format(s),
		})
	if not changed:
		return false
	var res_name := im.resource_name
	im.clear()
	im.resource_name = res_name
	for r in rebuilt:
		var flags := 0
		if r["fmt"] & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS:
			flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, r["arrays"], [], {},
			r["mat"], r["name"], flags)
	return true


## Reconstruye la superficie con los índices del LOD elegido. Se pasa por
## SurfaceTool para COMPACTAR: los índices del LOD siguen apuntando al buffer de
## vértices entero, así que sin esto bajaría el triangulaje pero no la memoria.
func _rebuild(arrays: Array, indices: PackedInt32Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms = arrays[Mesh.ARRAY_NORMAL]
	var uvs = arrays[Mesh.ARRAY_TEX_UV]
	var uv2s = arrays[Mesh.ARRAY_TEX_UV2]
	var cols = arrays[Mesh.ARRAY_COLOR]
	var bones = arrays[Mesh.ARRAY_BONES]
	var weights = arrays[Mesh.ARRAY_WEIGHTS]

	var per := 0
	if bones != null and not verts.is_empty():
		per = bones.size() / verts.size()

	var st := SurfaceTool.new()
	if per == 8:
		st.set_skin_weight_count(SurfaceTool.SKIN_8_WEIGHTS)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in indices:
		if norms != null:
			st.set_normal(norms[i])
		if uvs != null:
			st.set_uv(uvs[i])
		if uv2s != null:
			st.set_uv2(uv2s[i])
		if cols != null:
			st.set_color(cols[i])
		if per > 0:
			var b := PackedInt32Array()
			var w := PackedFloat32Array()
			for k in per:
				b.append(bones[i * per + k])
				w.append(weights[i * per + k])
			st.set_bones(b)
			st.set_weights(w)
		st.add_vertex(verts[i])
	st.index()
	return st.commit_to_arrays()


func _tris(im: ImporterMesh) -> int:
	var n := 0
	for s in im.get_surface_count():
		var idx: PackedInt32Array = im.get_surface_arrays(s)[Mesh.ARRAY_INDEX]
		n += idx.size() / 3
	return n


func _mesh_instances(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_mesh_instances(c))
	return out
