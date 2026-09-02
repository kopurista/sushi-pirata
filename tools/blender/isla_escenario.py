# MONTA EL ESCENARIO DE ISLA EN BLENDER Y LO EXPORTA A UN SOLO .glb
# (piloto del 2-9-2026: Blender como taller de montaje entre Meshy y Godot).
#
#   "C:/Program Files/Blender Foundation/Blender 4.1/blender.exe" --background \
#       --python tools/blender/isla_escenario.py
#
# Replica `level3d._scenery_island`: los dos discos de arena, las cuatro
# palmeras, la cabaña, las tres rocas y los dos barriles, en las MISMAS
# posiciones y tallas (la talla es la ALTURA objetivo de `_spawn_model`, con
# el modelo centrado en X/Z y apoyado en el suelo). Las manchas de sombra, el
# mar y la caja de la morsa siguen siendo de Godot: son cosas del juego.
#
# EJES: Godot es Y arriba y Blender Z arriba. El exportador glTF de Blender
# pasa (x, y, z) de Blender a (x, z, -y), así que una posición de Godot
# (x, y, z) se escribe aquí como (x, -z, y), y un giro sobre la Y de Godot es
# un giro sobre la Z de Blender con el mismo signo.
#
# DECIMADO: palmera, rocas, cabaña y barril NO tienen presupuesto en el hook
# de Godot (`import_hooks/decimate_import.gd`), así que en el juego van a la
# densidad con la que salieron de Ludo. Aquí se decima cada pieza a su tope
# ANTES de exportar; el hook de Godot recibe un archivo ya en cifra.
import bpy
import math
from mathutils import Vector, Matrix

ROOT = "C:/Users/KOPURISTA/Desktop/GODOT/sushi"
OUT = ROOT + "/assets/models/isla_escenario.glb"
# Triángulos por pieza (por instancia; las piezas repetidas comparten malla).
BUDGET = { "palmera": 3000, "rocas": 2500, "cabana": 3000, "barril": 1200 }


def tris_de(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def importar(nombre):
    antes = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath="%s/assets/models/%s.glb" % (ROOT, nombre))
    nuevos = [o for o in bpy.data.objects if o not in antes]
    meshes = [o for o in nuevos if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    # Los empties del importador sobran: el objeto se queda en el mundo.
    obj.parent = None
    for o in nuevos:
        if o.type != 'MESH' and o.name in bpy.data.objects:
            bpy.data.objects.remove(o)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.name = nombre
    obj.data.name = nombre
    antes_t = tris_de(obj)
    tope = BUDGET.get(nombre, 0)
    if tope and antes_t > tope:
        m = obj.modifiers.new("decimado", 'DECIMATE')
        m.ratio = tope / float(antes_t)
        bpy.ops.object.modifier_apply(modifier=m.name)
    print("[isla] %-8s %6d -> %5d tris" % (nombre, antes_t, tris_de(obj)))
    # El original se queda fuera de la vista: solo salen sus copias colocadas.
    obj.hide_render = True
    obj.hide_viewport = True
    return obj


def colocar(src, pos_godot, alto, yaw_deg=0.0, escala=1.0, nombre=None,
        vuelco_x=0.0):
    """Como `level3d._spawn_model`: alto objetivo, centrado en X/Z, base a 0."""
    obj = src.copy()
    obj.data = src.data
    obj.hide_render = False
    obj.hide_viewport = False
    obj.name = nombre or src.name
    bpy.context.collection.objects.link(obj)
    bb = [Vector(c) for c in src.bound_box]
    mn = Vector((min(c.x for c in bb), min(c.y for c in bb), min(c.z for c in bb)))
    mx = Vector((max(c.x for c in bb), max(c.y for c in bb), max(c.z for c in bb)))
    s = alto / max(mx.z - mn.z, 1e-4) * escala
    centro_base = Vector(((mn.x + mx.x) * 0.5, (mn.y + mx.y) * 0.5, mn.z))
    R = Matrix.Rotation(math.radians(yaw_deg), 3, 'Z')
    if vuelco_x:
        R = R @ Matrix.Rotation(math.radians(vuelco_x), 3, 'X')
    obj.scale = (s, s, s)
    obj.rotation_mode = 'XYZ'
    obj.rotation_euler = (math.radians(vuelco_x), 0.0, math.radians(yaw_deg))
    destino = Vector((pos_godot[0], -pos_godot[2], pos_godot[1]))
    obj.location = destino - (R @ (centro_base * s))
    return obj


def lineal(c):
    """sRGB -> lineal. Los colores de `_cyl` son los de un `albedo_color` de
    Godot (sRGB); el Base Color de Blender y el baseColorFactor del glTF van
    en LINEAL, y pasados tal cual la arena salía casi blanca (medido en
    captura)."""
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material_plano(nombre, rgb):
    mat = bpy.data.materials.new(nombre)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (lineal(rgb[0]), lineal(rgb[1]), lineal(rgb[2]), 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.0
    return mat


def disco(nombre, r_top, r_bottom, alto, pos_godot, rgb):
    """Como `level3d._cyl`: cilindro CENTRADO en pos (Godot)."""
    bpy.ops.mesh.primitive_cone_add(vertices=64, radius1=r_bottom, radius2=r_top,
        depth=alto, location=(pos_godot[0], -pos_godot[2], pos_godot[1]))
    obj = bpy.context.active_object
    obj.name = nombre
    obj.data.name = nombre
    obj.data.materials.append(material_plano(nombre + "_mat", rgb))
    return obj


bpy.ops.wm.read_factory_settings(use_empty=True)

# Arena: orilla mojada (abajo, más oscura) y arenal.
disco("orilla", 7.4, 7.8, 0.30, (0.0, -0.42, 0.0), (0.52, 0.44, 0.30))
disco("arena", 6.9, 7.3, 0.28, (0.0, -0.14, 0.0), (0.63, 0.55, 0.39))

palmera = importar("palmera")
rocas = importar("rocas")
cabana = importar("cabana")
barril = importar("barril")

PALM_FOOT = 3.4
# (yaw, porte): las tallas de `_palm` se sortean en el juego entre 0.88 y 1.12;
# aquí van fijas para que el modelo sea reproducible.
for i, (pos, yaw, porte) in enumerate([
        ((-5.2, 0.0, -2.4), 0.0, 1.0),
        ((1.2, 0.0, -5.2), 140.0, 0.94),
        ((5.2, 0.0, -2.0), 250.0, 1.08),
        ((-1.4, 0.0, 5.1), 60.0, 0.9)]):
    colocar(palmera, pos, PALM_FOOT, yaw, porte, "palmera_%d" % (i + 1))

colocar(cabana, (-5.2, 0.0, -5.2), 3.6, 45.0, 1.0, "cabana_1")

for i, (pos, alto) in enumerate([((-5.4, 0.0, 0.4), 1.0),
        ((0.8, 0.0, -5.6), 1.35), ((4.6, 0.0, -0.6), 1.0)]):
    colocar(rocas, pos, alto, pos[0] * 37.0, 1.0, "rocas_%d" % (i + 1))

colocar(barril, (-6.0, 0.0, -1.0), 0.95, 0.0, 1.0, "barril_1")
# El segundo barril va VOLCADO (rotation_degrees (90, 25, 0) y su pivote a
# y 0.33 en `_spawn_barrels`).
colocar(barril, (5.0, 0.33, 3.2), 0.95, 25.0, 1.0, "barril_2", vuelco_x=90.0)

# Fuera los originales escondidos: solo se exportan las copias colocadas.
for o in [palmera, rocas, cabana, barril]:
    bpy.data.objects.remove(o)

total = sum(tris_de(o) for o in bpy.data.objects if o.type == 'MESH')
print("[isla] objetos: %d, triángulos instanciados: %d"
    % (len([o for o in bpy.data.objects if o.type == 'MESH']), total))

bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_apply=True,
    export_yup=True, export_animations=False, export_skins=False,
    export_morph=False, export_lights=False, export_cameras=False,
    export_image_format='AUTO', export_texcoords=True, export_normals=True,
    export_tangents=False, use_selection=False)
print("[isla] exportado", OUT)
