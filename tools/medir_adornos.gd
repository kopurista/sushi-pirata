extends Node
## MEDIDOR DE LOS ADORNOS DEL BARCO. Se corre asi:
##
##     "…/Godot_…_console.exe" --path . "res://tools/medir_adornos.tscn"
##
## Existe porque colocar estas piezas a ojo, mirando capturas, es una perdida
## de tiempo: cada intento cuesta un render de un minuto y la respuesta que da
## ("se ve" / "no se ve") no dice ni POR QUE ni CUANTO hay que mover. Esto lo
## contesta con numeros.
##
## De cada pieza informa:
##   · APOYO — a que distancia esta su punto mas bajo de la primera superficie
##     del BARCO que hay debajo. 0.00 = apoyada; positivo = FLOTANDO; negativo
##     = enterrada. Es un rayo hacia abajo contra la malla del casco.
##   · VISTA — que fraccion de la pieza se ve desde la camara del juego. Se
##     lanzan rayos DESDE la camara hacia una rejilla de puntos de su caja: si
##     el rayo choca antes con el barco, ese punto esta tapado. Asi se sabe si
##     la esconde el casco, una vela o el propio aparejo, y cuanto.
##   · PANTALLA — donde cae en pixeles, para cruzarlo con una captura.
##
## El barco recibe un colisionador de malla TEMPORAL (create_trimesh_collision)
## solo mientras dura la medida; no se toca nada del juego.

var soy_runner := false
## Puntos de la caja de cada pieza que se prueban contra la camara. 3x3x3 = 27:
## suficiente para distinguir "tapada del todo" de "asoma media".
const REJILLA := 3


func _ready() -> void:
	if not soy_runner:
		var r := Node.new()
		r.set_script(get_script())
		r.soy_runner = true
		get_tree().root.add_child.call_deferred(r)
		return
	GameState.booted = true
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	await get_tree().create_timer(4.0).timeout
	_medir()
	get_tree().quit()


func _medir() -> void:
	var esc := get_tree().current_scene
	var pivot: Node3D = esc.get("ship_pivot")
	var cam: Camera3D = esc.get("cam")
	if pivot == null or cam == null:
		print("NO ENCUENTRO el barco o la camara")
		return
	var alto: float = pivot.get_meta("alto")
	var s := alto / 0.897
	print("=== BARCO: alto=%.3f  s=%.3f ===" % [alto, s])

	# El CASCO recibe colision de malla, para poder tirarle rayos. Va a un
	# nodo aparte que se libera al final: el juego no lleva fisica ninguna.
	var cuerpos: Array[StaticBody3D] = []
	for mi in pivot.find_children("*", "MeshInstance3D", true, false):
		if _es_adorno(mi):
			continue
		(mi as MeshInstance3D).create_trimesh_collision()
		for h in (mi as MeshInstance3D).get_children():
			if h is StaticBody3D:
				cuerpos.append(h)
	print("casco con colision: %d cuerpos" % cuerpos.size())
	var espacio := get_viewport().world_3d.direct_space_state

	print("%-14s %9s  %6s   %s" % ["PIEZA", "APOYO", "VISTA", "PANTALLA"])
	for nodo in pivot.get_children():
		var n3 := nodo as Node3D
		if n3 == null or not _es_adorno(n3):
			continue
		var caja := _caja(n3)
		if caja.size == Vector3.ZERO:
			continue
		# --- APOYO: NUEVE rayos hacia abajo repartidos por su huella, no uno.
		# Con uno solo no se distingue "apoyada" de "colgando sobre un hueco":
		# el rayo se cuela por una junta, encuentra el forro de abajo y dice
		# que flota medio barco. Y ademas se informa de la ALTURA de la
		# cubierta encontrada, que es lo que se copia luego al codigo — restar
		# la distancia a ojo hacia pasarse y enterrar la pieza.
		var apoyo := "sin suelo"
		var dmin := 1e9
		var ftop := -9.0
		var tocan := 0
		for a2 in 3:
			for b2 in 3:
				var o := caja.position + Vector3(
					caja.size.x * a2 * 0.5, 0.002, caja.size.z * b2 * 0.5)
				var g2 := espacio.intersect_ray(
					PhysicsRayQueryParameters3D.create(
						o, o + Vector3.DOWN * (alto * 1.2)))
				if g2.is_empty():
					continue
				tocan += 1
				var d := o.y - (g2["position"] as Vector3).y
				dmin = minf(dmin, d)
				ftop = maxf(ftop, pivot.to_local(g2["position"]).y / alto)
		if tocan > 0:
			apoyo = "%+.3f/%d" % [dmin, tocan]
		# --- VISTA: rayos desde la camara a una rejilla de su caja
		var vistos := 0
		var total := 0
		for i in REJILLA:
			for j in REJILLA:
				for k in REJILLA:
					var t := Vector3(float(i), float(j), float(k)) \
						/ float(REJILLA - 1)
					var punto := caja.position + caja.size * t
					total += 1
					var q := PhysicsRayQueryParameters3D.create(
						cam.global_position, punto)
					var g := espacio.intersect_ray(q)
					if g.is_empty():
						vistos += 1
					elif cam.global_position.distance_to(g["position"]) \
							> cam.global_position.distance_to(punto) - 0.02:
						vistos += 1
		# --- QUE HAY DEBAJO: se perfora en vertical desde MUY ARRIBA por el
		# centro de la pieza y se apuntan TODAS las superficies que se cruzan,
		# no solo la primera. Es lo unico que distingue la vela y la verga (que
		# estan arriba) de la CUBIERTA, y sin esa lista no hay forma de saber a
		# que altura apoyar la pieza: restar la distancia medida se pasaba y la
		# enterraba.
		var pilas := PackedFloat32Array()
		var c0 := caja.get_center()
		var y := pivot.to_global(Vector3(0.0, alto * 1.7, 0.0)).y
		var desde2 := Vector3(c0.x, y, c0.z)
		for _i in 10:
			var gg := espacio.intersect_ray(
				PhysicsRayQueryParameters3D.create(desde2,
					desde2 + Vector3.DOWN * (alto * 2.4)))
			if gg.is_empty():
				break
			var hit: Vector3 = gg["position"]
			pilas.append(pivot.to_local(hit).y / alto)
			desde2 = Vector3(c0.x, hit.y - 0.004, c0.z)
		var lista := ""
		for f2 in pilas:
			lista += "%.3f " % f2
		var px := cam.unproject_position(caja.get_center())
		print("    debajo: %s" % (lista if lista != "" else "(nada)"))
		print("%-14s %10s %5.0f%%  (%4.0f,%4.0f)  suelo f=%s  caja %.2f/%.2f/%.2f"
			% [n3.name if n3.name != "" else "?", apoyo,
				100.0 * float(vistos) / float(total), px.x, px.y,
				("%.3f" % ftop) if ftop > -8.0 else "  -  ",
				caja.size.x, caja.size.y, caja.size.z])
	_buscar_sitio(pivot, cam, espacio, alto, s)
	for c in cuerpos:
		c.queue_free()


## BUSCADOR DE SITIO. En vez de probar una posicion, capturar y mirar —que es
## un minuto por intento y no dice por que falla—, recorre una rejilla del
## barco y para cada casilla contesta con numeros:
##   · si hay CUBIERTA debajo y a que altura exacta (rayo hacia abajo)
##   · cuanto se VE desde la camara del juego una caja del tamaño de la pieza
##     apoyada ahi (rayos desde la camara a su caja)
## Lo que sale ordenado por visibilidad es donde hay que poner la pieza.
func _buscar_sitio(pivot: Node3D, cam: Camera3D,
		espacio: PhysicsDirectSpaceState3D, alto: float, s: float) -> void:
	# Caja del CAÑON, en unidades de modelo (mide 0.78 x 0.60 x 0.95 de mundo).
	var caja := Vector3(0.34, 0.26, 0.41) * s
	print("
=== SITIOS PARA EL CAÑON (cubierta + visibilidad) ===")
	print("%7s %7s %9s %8s %s" % ["x", "z", "cubierta", "se ve", ""])
	var filas := []
	for i in range(-9, 10):
		for j in range(-4, 5):
			var xm := i * 0.04
			var zm := j * 0.035
			# Techo del barco en ese punto: se tira el rayo desde MUY arriba.
			var desde := pivot.to_global(Vector3(xm * s, alto * 1.6, zm * s))
			var hasta := pivot.to_global(Vector3(xm * s, -alto * 0.2, zm * s))
			var g := espacio.intersect_ray(
				PhysicsRayQueryParameters3D.create(desde, hasta))
			if g.is_empty():
				continue
			var suelo: Vector3 = g["position"]
			var f := (pivot.to_local(suelo).y) / alto
			# Solo interesa la cubierta, no los palos ni la obra viva.
			if f < 0.20 or f > 0.55:
				continue
			var centro := suelo + Vector3(0.0, caja.y * 0.5, 0.0)
			var vistos := 0
			var total := 0
			for a in 3:
				for b in 3:
					for c in 3:
						var t := Vector3(float(a), float(b), float(c)) / 2.0
						var punto := centro - caja * 0.5 + caja * t
						total += 1
						var q := espacio.intersect_ray(
							PhysicsRayQueryParameters3D.create(
								cam.global_position, punto))
						if q.is_empty() or cam.global_position.distance_to(
								q["position"]) > cam.global_position 								.distance_to(punto) - 0.02:
							vistos += 1
			filas.append([100.0 * float(vistos) / float(total), xm, zm, f])
	filas.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	for k in mini(14, filas.size()):
		var r: Array = filas[k]
		print("%+7.3f %+7.3f   f=%.3f   %5.0f%%"
			% [r[1], r[2], r[3], r[0]])
	print("(x, z en unidades de modelo; f = fraccion del alto de la cubierta)")


## Un adorno es lo que cuelga del pivote del barco y NO es el propio modelo.
func _es_adorno(n: Node) -> bool:
	var p := n
	while p != null:
		if p.is_in_group("no_batch"):
			return true
		if p is Node3D and (p as Node3D).name.begins_with("Col"):
			return true
		p = p.get_parent()
	return false


## Caja global de un nodo y sus hijos.
func _caja(n: Node3D) -> AABB:
	var out := AABB()
	var primero := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var a := m.global_transform * m.get_aabb()
		out = a if primero else out.merge(a)
		primero = false
	if n is MeshInstance3D:
		var a2 := (n as MeshInstance3D).global_transform \
			* (n as MeshInstance3D).get_aabb()
		out = a2 if primero else out.merge(a2)
	return out
