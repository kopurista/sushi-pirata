class_name ChefLook
extends RefCounted
## EL ASPECTO DEL CHEF: el catálogo de piezas y el MONTAJE del personaje.
##
## El chef es un solo cuerpo (calvo, con la cara lisa) al que el juego le cuelga
## piezas: cejas, nariz, pelo, barba y gafas, todas de `assets/models/chef/`.
## Cada pieza viene de Blender YA PESADA al esqueleto del chef (los huesos se
## llaman igual en todas), así que aquí no se cuelga nada de un hueso con un
## BoneAttachment3D: se saca su MeshInstance3D de la escena de la pieza, se mete
## bajo el Skeleton3D del cuerpo y Godot casa los huesos POR NOMBRE. Es lo que
## hace que la melena larga siga al tronco y no gire entera con la cabeza.
##
## El color no va horneado en ninguna pieza: pelo, cejas, barba y gafas llevan
## material plano y se les pone el `albedo_color`; la piel son cuatro texturas
## del mismo atlas y se le cambia el `albedo_texture` al cuerpo. La NARIZ
## recibe ese mismo material del cuerpo —apunta al mismo téxel de piel—, y sin
## eso cambiar de tono dejaba la nariz del tono anterior.
##
## Lo que elige el jugador viaja en un diccionario (`GameState.player_look`):
##   { piel, pelo, color, nariz, barba, gafas }
## y `validar` lo deja siempre completo y dentro del catálogo, venga de donde
## venga (un guardado viejo trae el diccionario vacío).

const DIR := "res://assets/models/chef/"

const PIELES: Array[String] = ["muy_blanca", "neutra", "morena", "oscura"]
const PIELES_NOMBRE := {
	"muy_blanca": "Muy blanca", "neutra": "Neutra", "morena": "Morena", "oscura": "Oscura",
}
## El color de la muestra del selector (el tono medio de cada textura).
const PIELES_MUESTRA := {
	"muy_blanca": Color(1.0, 0.845, 0.755), "neutra": Color(0.945, 0.722, 0.659),
	"morena": Color(0.76, 0.53, 0.395), "oscura": Color(0.455, 0.295, 0.215),
}

## Los once peinados. "calvo" no tiene pieza. Van los masculinos primero y los
## femeninos después, pero cualquiera puede llevar cualquiera: el cuerpo es
## uno y el género se elige aparte (lo usan los diálogos, no el aspecto).
const PELOS: Array[String] = [
	"calvo", "corto", "rizado", "ondulado", "despeinado", "flequillo",
	"bob", "melena", "larga", "mono", "coletas",
]
const PELOS_NOMBRE := {
	"calvo": "Calvo", "corto": "Corto", "rizado": "Rizado", "ondulado": "Ondulado",
	"despeinado": "Despeinado", "flequillo": "Flequillo", "bob": "Bob",
	"melena": "Melena", "larga": "Larga", "mono": "Moño", "coletas": "Coletas",
}

## Los cinco colores de pelo (valen para pelo, cejas y barba a la vez).
const COLORES: Array[String] = ["negro", "castano", "rubio", "gris", "pelirrojo"]
const COLORES_NOMBRE := {
	"negro": "Negro", "castano": "Castaño", "rubio": "Rubio", "gris": "Gris",
	"pelirrojo": "Pelirrojo",
}
const COLORES_RGB := {
	"negro": Color(0.09, 0.08, 0.10), "castano": Color(0.28, 0.16, 0.09),
	"rubio": Color(0.85, 0.68, 0.33), "gris": Color(0.72, 0.72, 0.74),
	"pelirrojo": Color(0.66, 0.24, 0.10),
}

const NARICES: Array[String] = ["pequena", "media", "grande"]
const NARICES_NOMBRE := { "pequena": "Pequeña", "media": "Media", "grande": "Grande" }

## Las barbas del reparto (ver CLAUDE.md): "nada" no tiene pieza.
const BARBAS: Array[String] = [
	"nada", "bigote", "perilla", "bigote_perilla", "barba_rala", "barba_corta",
	"barba_larga",
]
const BARBAS_NOMBRE := {
	"nada": "Sin barba", "bigote": "Bigote", "perilla": "Perilla",
	"bigote_perilla": "Bigote y perilla", "barba_rala": "Barba rala",
	"barba_corta": "Barba corta", "barba_larga": "Barba larga",
}

## La montura de las gafas. De momento una sola; la pieza va en blanco, así que
## el día que se quieran monturas de colores es una lista más.
const GAFAS_COLOR := Color(0.12, 0.11, 0.12)

## Las cinco claves del diccionario, con su catálogo, para validar sin repetir.
const CAMPOS := {
	"piel": PIELES, "pelo": PELOS, "color": COLORES, "nariz": NARICES, "barba": BARBAS,
}


static func por_defecto() -> Dictionary:
	return {
		"piel": "neutra", "pelo": "corto", "color": "castano", "nariz": "media",
		"barba": "nada", "gafas": false,
	}


## Deja el diccionario completo y dentro del catálogo. Lo que falte o no exista
## cae a su valor por defecto, así que un guardado viejo (o uno tocado a mano)
## nunca deja al chef sin nariz.
static func validar(d: Variant) -> Dictionary:
	var out := por_defecto()
	if not (d is Dictionary):
		return out
	for campo in CAMPOS:
		var v := str(d.get(campo, ""))
		if (CAMPOS[campo] as Array).has(v):
			out[campo] = v
	out["gafas"] = bool(d.get("gafas", false))
	return out


## Monta el chef con ese aspecto. Devuelve la raíz de la escena del cuerpo, con
## las piezas ya colgadas del esqueleto y los materiales puestos. En la raíz
## quedan dos metas para quien lo encuadre: "cuerpo" (el MeshInstance3D del
## cuerpo, para escalar y encuadrar SIN contar el pelo, que cambia el alto) y
## "look" (el diccionario con el que se montó).
static func montar(look: Dictionary) -> Node3D:
	look = validar(look)
	var esc: PackedScene = load(DIR + "chef_cuerpo.glb")
	if esc == null:
		push_error("ChefLook: falta chef_cuerpo.glb")
		return Node3D.new()
	var root: Node3D = esc.instantiate()
	var skels := root.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		push_error("ChefLook: el cuerpo no trae esqueleto")
		return root
	var skel: Skeleton3D = skels[0]
	var cuerpo: MeshInstance3D = null
	for m in root.find_children("*", "MeshInstance3D", true, false):
		if cuerpo == null or m.mesh.get_surface_count() > 0 \
				and _tris(m) > _tris(cuerpo):
			cuerpo = m
	if cuerpo == null:
		push_error("ChefLook: el cuerpo no trae malla")
		return root

	# LA PIEL: el material del cuerpo con la textura del tono elegido. Se
	# duplica para no tocar el recurso importado, que es compartido.
	var piel := _material_piel(cuerpo, str(look["piel"]))
	for s in cuerpo.mesh.get_surface_count():
		cuerpo.set_surface_override_material(s, piel)

	var pelo := _material_plano(COLORES_RGB[look["color"]])
	_colgar(skel, "chef_cejas", pelo)
	_colgar(skel, "chef_nariz_%s" % look["nariz"], piel)
	if look["pelo"] != "calvo":
		_colgar(skel, "chef_pelo_%s" % look["pelo"], pelo)
	if look["barba"] != "nada":
		_colgar(skel, "chef_%s" % look["barba"], pelo)
	if bool(look["gafas"]):
		_colgar(skel, "chef_gafas", _material_plano(GAFAS_COLOR))

	root.set_meta("cuerpo", cuerpo)
	root.set_meta("look", look)
	return root


## El material del cuerpo con la piel puesta.
static func _material_piel(cuerpo: MeshInstance3D, piel: String) -> StandardMaterial3D:
	var base: Material = cuerpo.mesh.surface_get_material(0)
	var mat: StandardMaterial3D = base.duplicate() if base is StandardMaterial3D \
			else StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	var tex_path := DIR + "chef_piel_%s.jpg" % piel
	if ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path)
	else:
		push_warning("ChefLook: falta la piel %s" % piel)
	# Sin metálico ni emisión (Meshy los deja encendidos y quema el retrato);
	# `preparar_personaje.py` ya los apaga, esto es la red.
	mat.metallic = 0.0
	mat.emission_enabled = false
	return mat


## Un material de color plano, para lo que el juego tiñe.
static func _material_plano(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.45
	mat.metallic = 0.0
	return mat


## Cuelga una pieza del esqueleto del cuerpo: saca su MeshInstance3D de la
## escena de la pieza y lo mete bajo el Skeleton3D del chef. La pieza trae su
## `skin` con los huesos POR NOMBRE, y como son los mismos nombres que los del
## cuerpo, Godot la deforma con el esqueleto del chef sin más.
static func _colgar(skel: Skeleton3D, nombre: String, mat: Material) -> void:
	var ruta := DIR + nombre + ".glb"
	if not ResourceLoader.exists(ruta):
		push_warning("ChefLook: falta la pieza %s" % nombre)
		return
	var esc: PackedScene = load(ruta)
	if esc == null:
		return
	var inst: Node3D = esc.instantiate()
	var k := 0
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		# La pieza viene con su transform respecto a SU esqueleto, que esta en
		# el mismo sitio que el del chef (los dos en el origen).
		var t: Transform3D = mi.transform
		# Sin `owner`: era el de la escena de la pieza, que se libera, y Godot
		# avisa de "owner inconsistente" al cambiarla de arbol.
		mi.owner = null
		mi.get_parent().remove_child(mi)
		# Nombre unico: las cejas son DOS mallas y con el mismo nombre la
		# segunda salia renombrada a "@MeshInstance3D@2".
		mi.name = nombre if k == 0 else "%s_%d" % [nombre, k]
		k += 1
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, mat)
		if mi.skin != null:
			# Pieza PESADA (pelo, barbas, gafas): bajo el esqueleto, y Godot la
			# deforma casando los huesos por nombre.
			skel.add_child(mi)
			mi.transform = t
			mi.skeleton = NodePath("..")
		else:
			# Pieza RIGIDA (cejas, narices, que salen de `chef_piezas.py` sin
			# esqueleto): colgada del hueso de la CABEZA con un BoneAttachment3D.
			# Esta modelada en el espacio del cuerpo en reposo, asi que su sitio
			# bajo el hueso es el inverso de la pose de reposo de ese hueso.
			var head := skel.find_bone("Head")
			if head < 0:
				head = skel.find_bone("Neck")
			var ba := BoneAttachment3D.new()
			ba.name = nombre + "_hueso" if k == 1 else "%s_hueso_%d" % [nombre, k - 1]
			ba.bone_name = skel.get_bone_name(maxi(head, 0))
			skel.add_child(ba)
			ba.add_child(mi)
			mi.transform = skel.get_bone_global_rest(maxi(head, 0)).affine_inverse() * t
	inst.free()


static func _tris(m: MeshInstance3D) -> int:
	var n := 0
	if m.mesh == null:
		return 0
	for s in m.mesh.get_surface_count():
		n += m.mesh.surface_get_array_index_len(s)
	return n
