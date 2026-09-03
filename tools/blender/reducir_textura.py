# Reduce la textura EMBEBIDA de un .glb y lo vuelve a exportar. Los modelos de
# Meshy vienen con atlas de 4096, que en este juego no se ve nunca a ese
# tamaño: es peso de repositorio y de descarga a cambio de nada.
#   blender --background --python tools/blender/reducir_textura.py -- <in.glb> <out.glb> [lado]
import bpy, sys, os
a = sys.argv[sys.argv.index("--") + 1:]
SRC, DEST = os.path.abspath(a[0]), os.path.abspath(a[1])
LADO = int(a[2]) if len(a) > 2 else 1024
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
for im in bpy.data.images:
    if im.size[0] > LADO:
        antes = im.size[0]
        im.scale(LADO, LADO)
        print("[tex] %s: %d -> %d" % (im.name, antes, LADO))
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=DEST, export_format="GLB", export_apply=False,
                          export_animations=False, export_image_format="JPEG",
                          export_jpeg_quality=92)
print("[tex] exportado", DEST)
