# DEJA EL ARMATURE EN EL ORIGEN (5-9-2026). El rig del KAPPA (`riggear.py`)
# salia con el objeto armature a z=+0.5 y la malla en 0..1: en Godot el nodo
# `Rig` llega con esa traslacion y la caja del modelo (transformadas
# acumuladas x AABB de la malla) sale 0.5 por ENCIMA de donde se dibuja la
# piel —una malla con esqueleto se dibuja en el espacio del esqueleto, no en
# el suyo—. El retrato del dialogo encuadraba el aire sobre su cabeza y solo
# asomaba el plato. Aplicando la posicion del armature, todo lo que mide cajas
# (dialogo, nivel, cartel) vuelve a coincidir con lo que se ve.
#   blender --background --python tools/blender/rig_al_origen.py -- <in.glb> <out.glb>
import bpy, sys, os

a = sys.argv[sys.argv.index("--") + 1:]
src, dst = os.path.abspath(a[0]), os.path.abspath(a[1])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
sc = bpy.context.scene
for o in sc.objects:
    if o.type == "ARMATURE":
        print("[origen] armature %s en %s" % (o.name, tuple(round(v, 4) for v in o.location)))
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
        print("[origen] ahora en %s" % (tuple(round(v, 4) for v in o.location),))
for o in sc.objects:
    if o.type == "MESH":
        zs = [(o.matrix_world @ v.co).z for v in o.data.vertices]
        print("[origen] malla %s: z %.3f .. %.3f (mundo)" % (o.name, min(zs), max(zs)))
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_apply=False,
    export_animations=False, export_image_format="AUTO", export_jpeg_quality=90)
print("[origen] exportado", dst)
