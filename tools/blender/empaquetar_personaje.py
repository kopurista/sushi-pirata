# EMPAQUETA UN PERSONAJE PARA EL JUEGO: del `_v5_listo.glb` de `_gen/meshy` al
# `.glb` de `assets/models`, con lo que Godot necesita y sin lo que sobra.
#
#   · Tira la ESFERA SUELTA (un icosaedro de radio 1 sin material que arrastran
#     TODAS las piezas de la cadena v5, copiado de exportacion en exportacion;
#     en Godot es una bola gris del tamaño del personaje y revienta el AABB con
#     el que se escala).
#   · Deja el color base del material a 1.0: Meshy lo deja en 0.8 y, aunque con
#     la textura enchufada el exportador escribe el factor a 1, no cuesta nada
#     asegurarlo — un personaje un 20% mas oscuro que en Blender no se nota
#     hasta que se compara.
#   · Apaga metalico y emision (la red de `preparar_personaje.py`).
#   · La textura va EMBEBIDA tal cual (Godot la extrae al importar).
#
#   blender --background --python tools/blender/empaquetar_personaje.py -- \
#       <origen.glb> <destino.glb> [<origen2> <destino2> ...]
import bpy, sys, os

a = sys.argv[sys.argv.index("--") + 1:]
pares = [(os.path.abspath(a[i]), os.path.abspath(a[i + 1])) for i in range(0, len(a) - 1, 2)]

for src, dst in pares:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    sc = bpy.context.scene
    fuera = 0
    for o in list(sc.objects):
        if o.type == "MESH" and o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o, do_unlink=True)
            fuera += 1
    for m in bpy.data.materials:
        if not m.use_nodes:
            continue
        b = m.node_tree.nodes.get("Principled BSDF")
        if b is None:
            continue
        b.inputs["Base Color"].default_value = (1.0, 1.0, 1.0, 1.0)
        b.inputs["Metallic"].default_value = 0.0
        if "Emission Strength" in b.inputs:
            b.inputs["Emission Strength"].default_value = 0.0
    mallas = [o for o in sc.objects if o.type == "MESH"]
    caras = sum(len(o.data.polygons) for o in mallas)
    huesos = sum(len(o.data.bones) for o in sc.objects if o.type == "ARMATURE")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB",
                              export_apply=False, export_animations=False,
                              export_image_format="AUTO", export_jpeg_quality=90)
    print("[pack] %-26s %7d caras %2d huesos %d esferas fuera %6d KB"
          % (os.path.basename(dst), caras, huesos, fuera, os.path.getsize(dst) // 1024))
