class_name StartPort
extends RefCounted
## El PUERTO de la pantalla de inicio. Se construye DENTRO de la escena del
## menú (main_menu), alrededor de un ancla del mapa a la izquierda del
## fondeadero: la portada y el menú son la misma escena, y al zarpar la cámara
## viaja del muelle al fondeadero sin cambiar de pantalla.
##
## TODO ESTÁ MEDIDO CONTRA EL BARCO DEL MENÚ, no contra el de ficha del mapa:
## en la portada el barco va a escala de menú (huella ~5.3 u), así que un
## muelle pensado para el barco pequeño salía el doble de grande que él (pasó:
## farolas más altas que el mástil). Las medidas de aquí son fracciones de
## `SHIP_W`; si el barco del menú cambia de escala, el muelle le sigue.
##
## El muelle tiene FINAL por la DERECHA a propósito: al zarpar, la cámara
## acompaña al barco hacia el fondeadero y ese extremo entra en el encuadre —
## sin él, el muelle se cortaba a cuchillo en mitad del mar.

const R_HAT := SceneBackdrop.R_HAT
const D_HAT := SceneBackdrop.D_HAT

const WOOD := "res://assets/props/madera_muelle.webp"

## Huella del barco del MENÚ: SHIP_FOOT (2.3) x MENU_SHIP_SCALE (2.75).
const SHIP_W := 6.3

## Muelle: corre a lo ANCHO de la pantalla (eje R_HAT), detrás del barco.
## El barco queda amarrado por delante, en el agua.
const PIER_DEPTH := 3.1          ## fondo (hacia arriba de pantalla)
const PIER_LEN := 21.0           ## largo total
const PIER_MID := -4.2           ## centro, en u a la derecha del ancla
const PIER_TOP := 1.05           ## altura del entarimado
const PIER_OFF := 3.6            ## distancia del ancla del barco al canto
## Final del muelle por la derecha (u desde el ancla): 2.2 u más allá del
## borde de la pantalla (que queda a 4.2 u del centro).
const PIER_END := PIER_MID + PIER_LEN * 0.5

## Farolas y género, en fracciones del barco.
const LAMP_H := SHIP_W * 0.42
const CRATE_H := SHIP_W * 0.17
const BARREL_H := SHIP_W * 0.18

## Tinte que lleva la caja al tono del barril. No está elegido a ojo: sale de
## medir el color medio de las dos texturas (caja 133,60,37 y barril
## 124,80,18) y dividir una por otra.
const CAJA_TINTE := Color(0.93, 1.33, 0.49)


## Monta el puerto alrededor de `a` (el ancla del BARCO, en mundo) y devuelve
## la raíz. Quien llame decide si fusiona su geometría (GeometryBatch).
static func build(root: Node3D, a: Vector3) -> Node3D:
	var port := Node3D.new()
	port.name = "StartPort"
	root.add_child(port)

	# El entarimado va ATENUADO: la madera clara del muelle, a plena luz del
	# sol del menu (1.15 + ambiente 0.95), salia como una banda BLANCA plana.
	var tablon := _wood(Vector3(8.0, 3.0, 1.0), Color(0.80, 0.75, 0.68))
	var piedra := _mat(Color(0.56, 0.54, 0.50))
	var piedra_osc := _mat(Color(0.44, 0.42, 0.39))

	# Entarimado y zócalo de piedra. Girados 45° para quedar paralelos al
	# borde de la pantalla con la cámara isométrica: alineados con los ejes
	# del mundo se ven de canto, como una cuña.
	var centro := a + R_HAT * PIER_MID + D_HAT * -(PIER_OFF + PIER_DEPTH * 0.5)
	_box(port, Vector3(PIER_LEN, 0.5, PIER_DEPTH),
		centro + Vector3(0, PIER_TOP - 0.25, 0), tablon, 45.0)
	_box(port, Vector3(PIER_LEN + 0.2, 0.6, PIER_DEPTH + 0.2),
		centro + Vector3(0, 0.3, 0), piedra, 45.0)

	# EL FINAL del muelle, a la derecha: un machón de piedra que remata el
	# entarimado, con su noray encima. Es lo que se ve al zarpar.
	var fin := a + R_HAT * (PIER_END + 0.35) \
			+ D_HAT * -(PIER_OFF + PIER_DEPTH * 0.5)
	_box(port, Vector3(0.9, 1.35, PIER_DEPTH + 0.5),
		fin + Vector3(0, 0.675, 0), piedra_osc, 45.0)
	_noray(port, fin + Vector3(0, 1.35, 0))

	# Pilotes de madera asomando por el canto del agua.
	var pilote := _wood(Vector3(1.0, 1.0, 1.0), Color(0.78, 0.72, 0.62))
	var canto := a + D_HAT * -PIER_OFF
	var r := PIER_MID - PIER_LEN * 0.5 + 1.0
	while r < PIER_END - 0.4:
		_cyl(port, 0.16, 1.5, canto + R_HAT * r + Vector3(0, 0.35, 0), pilote)
		r += 2.1

	# Norays sobre el entarimado, cerca del canto.
	for i in [-4.0, 0.2, 4.4]:
		_noray(port, a + R_HAT * (PIER_MID + i)
			+ D_HAT * -(PIER_OFF + 0.55) + Vector3(0, PIER_TOP, 0))

	# LO QUE SE VE, COLOCADO CONTRA LA PANTALLA, no contra el muelle. En la
	# portada el logotipo ocupa el centro-arriba (x 150..570 de 720): lo que
	# suba del entarimado tiene que caer FUERA de esa franja o queda escondido
	# detrás (pasó: las dos farolas quedaron justo debajo del logo y parecía
	# que no existían). Las erres son u a la derecha del BARCO; la pantalla
	# enseña de -4.2 a +4.2.
	var deck := PIER_TOP

	# Farola a la IZQUIERDA del logotipo, pegada al borde de la pantalla...
	_prop(port, "res://assets/models/farola.glb",
		a + R_HAT * -3.3 + D_HAT * -(PIER_OFF + PIER_DEPTH - 0.55)
		+ Vector3(0, deck, 0), LAMP_H, 45.0)
	# ...y otra en el machón del FINAL: entra en cuadro durante el zarpe.
	_prop(port, "res://assets/models/farola.glb",
		a + R_HAT * (PIER_END - 0.6) + D_HAT * -(PIER_OFF + PIER_DEPTH - 0.55)
		+ Vector3(0, deck, 0), LAMP_H, 45.0)

	# Género a la DERECHA del logotipo (x > 570) y un grupo más junto al final
	# del muelle, de regalo para el paneo del zarpe.
	for s in [
		[2.7, 0.9, 0.0, CRATE_H, 18.0], [2.8, 0.9, CRATE_H, CRATE_H * 0.82, -24.0],
		[3.8, 1.5, 0.0, CRATE_H * 0.92, -8.0],
		[5.2, 1.4, 0.0, CRATE_H, 30.0],
	]:
		_prop(port, "res://assets/models/caja.glb",
			a + R_HAT * float(s[0]) + D_HAT * -(PIER_OFF + float(s[1]))
			+ Vector3(0, deck + float(s[2]), 0),
			float(s[3]), float(s[4]), CAJA_TINTE)
	for b in [[-3.9, 2.1, 20.0], [3.3, 2.2, -35.0], [4.6, 1.0, 5.0]]:
		_prop(port, "res://assets/models/barril.glb",
			a + R_HAT * float(b[0]) + D_HAT * -(PIER_OFF + float(b[1]))
			+ Vector3(0, deck, 0), BARREL_H, float(b[2]))
	return port


# ------------------------------------------------------------- constructores

static func _mat(color: Color, rough := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


static func _wood(uv: Vector3, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(WOOD)
	m.albedo_color = tint
	m.uv1_scale = uv
	m.roughness = 0.95
	return m


static func _box(port: Node3D, size: Vector3, pos: Vector3, mat: Material,
		yaw := 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees.y = yaw
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	port.add_child(mi)


static func _cyl(port: Node3D, radius: float, h: float, pos: Vector3,
		mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = h
	mesh.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	port.add_child(mi)


## Noray de hierro: bolardo bajo con su tapa, a escala del muelle.
static func _noray(port: Node3D, pos: Vector3) -> void:
	var hierro := _mat(Color(0.24, 0.23, 0.26), 0.6)
	_cyl(port, 0.17, 0.44, pos + Vector3(0, 0.22, 0), hierro)
	_cyl(port, 0.23, 0.11, pos + Vector3(0, 0.46, 0), hierro)


## Instancia un GLB normalizado por ALTURA, opcionalmente teñido. El tinte
## multiplica el albedo sin tocar la textura: conserva las vetas de la madera
## y solo cambia el tono.
static func _prop(port: Node3D, path: String, pos: Vector3, alto: float,
		yaw := 0.0, tinte := Color.WHITE) -> void:
	if not ResourceLoader.exists(path):
		return
	var esc: PackedScene = load(path)
	if esc == null:
		return
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation_degrees.y = yaw
	# Los .glb no entran en el fusionado (traen sus propios materiales).
	pivot.add_to_group("no_batch")
	port.add_child(pivot)
	var inst: Node3D = esc.instantiate()
	pivot.add_child(inst)
	var caja := _aabb(inst)
	if caja.size.y > 0.001:
		var k := alto / caja.size.y
		inst.scale = Vector3(k, k, k)
		inst.position.y = -caja.position.y * k
	if tinte != Color.WHITE:
		_tint(inst, tinte)


static func _tint(n: Node, color: Color) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var m := mi.get_active_material(0)
		if m is StandardMaterial3D:
			var d: StandardMaterial3D = (m as StandardMaterial3D).duplicate()
			d.albedo_color = color
			mi.material_override = d
	for c in n.get_children():
		_tint(c, color)


static func _aabb(n: Node, acc := AABB()) -> AABB:
	if n is MeshInstance3D:
		var suya := (n as MeshInstance3D).get_aabb()
		acc = suya if acc.size == Vector3.ZERO else acc.merge(suya)
	for c in n.get_children():
		acc = _aabb(c, acc)
	return acc
