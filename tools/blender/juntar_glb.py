# Junta varios .glb de PIEZA en uno solo, conservando su esqueleto.
#
# Lo pide el "bigote y perilla" del chef: la cara de Pablo va en SOMBRA bajo el
# ala de su sombrero —su cabeza entera es casi del mismo tono— y la inundacion
# de `pelo_de.py` se lleva el 48% de ella con cualquier tolerancia. Su look se
# arma con las dos piezas que si salen limpias: el bigote de Nach y la perilla
# del capitan.
#
#   blender --background --python tools/blender/juntar_glb.py -- <salida> <a.glb> <b.glb>...
import bpy, sys, os

a = sys.argv[sys.argv.index("--") + 1:]
DEST, FUENTES = os.path.abspath(a[0]), [os.path.abspath(x) for x in a[1:]]
# LO QUE SE MONTA ENCIMA DE UNA BARBA GORDA HAY QUE ADELANTARLO. El bigote va a
# ras de cara y la barba larga sobresale mucho mas, asi que puesto en su sitio
# queda DENTRO de ella y no se ve: hay que sacarlo hasta la superficie de la
# barba. Es una lista, un valor por fuente, en unidades de mundo hacia -Y.
ADELANTE = [float(x) for x in os.environ.get("JUNTAR_ADELANTE", "").split(",") if x != ""]

bpy.ops.wm.read_factory_settings(use_empty=True)
for i, f in enumerate(FUENTES):
    antes = set(o.name for o in bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=f)
    if i < len(ADELANTE) and ADELANTE[i] != 0.0:
        for o in bpy.context.scene.objects:
            if o.name not in antes and o.type == "MESH":
                for v in o.data.vertices:
                    v.co.y -= ADELANTE[i] / max(o.matrix_world.to_scale().y, 1e-6)
                o.data.update()
sc = bpy.context.scene
mallas = [o for o in sc.objects if o.type == "MESH"]
# UN SOLO ESQUELETO: cada .glb trae el suyo, y con varios el exportador escribe
# varias pieles y Godot no sabria a cual colgar la pieza.
arms = [o for o in sc.objects if o.type == "ARMATURE"]
arm = arms[0]
for m in mallas:
    m.parent = arm
    for mod in m.modifiers:
        if mod.type == "ARMATURE":
            mod.object = arm
for extra in arms[1:]:
    bpy.data.objects.remove(extra, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
for m in mallas:
    m.select_set(True)
bpy.context.view_layer.objects.active = mallas[0]
bpy.ops.object.join()
uno = bpy.context.object
bpy.ops.object.select_all(action="DESELECT")
uno.select_set(True)
arm.select_set(True)
bpy.ops.export_scene.gltf(filepath=DEST, export_format="GLB",
                          use_selection=True, export_apply=False,
                          export_animations=False)
print("[juntar] %d caras -> %s" % (len(uno.data.polygons), DEST))
