class_name GeometryBatch
## Fusiona la geometría ESTÁTICA de color plano, agrupándola POR COLOR.
##
## Los escenarios (cubierta, mostrador, taburetes, barandillas, atrezzo...) se
## construyen con decenas de cajas sueltas, y cada una era un draw call —dos,
## contando el pase de sombra—. En un móvil eso se nota en fluidez y en batería
## mucho antes que el número de triángulos, que aquí es ridículo.
##
## Se fusiona por COLOR y se REUTILIZA el material original de cada grupo, en
## vez de meter el color en los vértices: `vertex_color_use_as_albedo` no
## funciona bajo GL Compatibility (el renderer del juego) y el escenario
## entero salía lavado. Así el resultado es idéntico al original píxel a
## píxel, y aun así se pasa de ~130 mallas a una por color.
##
## `bake()` solo toca los MeshInstance3D que cumplen TODO esto:
##   - son hijos directos del nodo raíz (lo que crea `_box()`),
##   - llevan `material_override` StandardMaterial3D opaco (los que llevan
##     shader —la banda de la cinta— quedan fuera a propósito),
##   - no están en el grupo "no_batch" (para lo que deba seguir siendo un nodo).
##
## Se llama AL FINAL de la construcción: hasta entonces el código coloca y rota
## las cajas con normalidad.

const NO_BATCH_GROUP := "no_batch"
## Por debajo de esta altura (en su punto MÁS ALTO) una malla se considera
## suelo y deja de proyectar sombra.
const GROUND_LEVEL := 0.06


## Devuelve cuántas mallas se han fusionado (0 si no había nada que hacer).
static func bake(root: Node3D, prefix := "Batch") -> int:
	# color (como clave estable) -> { "st": SurfaceTool, "mat": material }
	var groups: Dictionary = {}
	var victims: Array[MeshInstance3D] = []

	for child in root.get_children():
		if not (child is MeshInstance3D):
			continue
		var mi: MeshInstance3D = child
		if mi.is_in_group(NO_BATCH_GROUP) or not mi.visible:
			continue
		var mat := mi.material_override
		if not (mat is StandardMaterial3D):
			continue
		var sm: StandardMaterial3D = mat
		var mesh := mi.mesh
		if mesh == null or mesh.get_surface_count() != 1:
			continue

		# Lo que está a ras de suelo (tablones de cubierta, arena, manchas,
		# guiones de la ruta) no proyecta ninguna sombra que se vea: el sol
		# cae desde arriba. Sacarlo del pase de sombras es gratis y ahorra la
		# mitad de su coste de dibujo.
		if (mi.transform * mi.get_aabb()).end.y < GROUND_LEVEL:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# La clave junta color y acabado: dos materiales del mismo color pero
		# distinto sombreado, transparencia o sombra no deben acabar juntos.
		# Los translúcidos SÍ se fusionan, pero solo entre idénticos (los
		# guiones de la ruta del mapa), donde el orden de mezcla no cambia.
		var key := "%s|%d|%.2f|%d|%d" % [sm.albedo_color.to_html(true),
			sm.shading_mode, sm.roughness, sm.transparency, mi.cast_shadow]
		if not groups.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = { "st": st, "mat": sm, "shadow": mi.cast_shadow }
		var tool: SurfaceTool = groups[key]["st"]
		tool.append_from(mesh, 0, mi.transform)
		victims.append(mi)

	if victims.is_empty():
		return 0
	for mi in victims:
		root.remove_child(mi)
		mi.queue_free()

	var i := 0
	for key in groups:
		var st: SurfaceTool = groups[key]["st"]
		var batch := MeshInstance3D.new()
		batch.name = "%s%d" % [prefix, i]
		batch.mesh = st.commit()
		batch.material_override = groups[key]["mat"]
		batch.cast_shadow = groups[key]["shadow"]
		root.add_child(batch)
		i += 1
	return victims.size()
