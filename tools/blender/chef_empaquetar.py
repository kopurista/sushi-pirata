# EMPAQUETA LAS PIEZAS DEL CHEF PARA EL JUEGO: de `_gen/meshy/chef_piezas` a
# `assets/models/chef`, dejando cada .glb como Godot lo necesita.
#
# Lo que hace por pieza, y por que:
#   · Tira la ESFERA SUELTA. Todas las piezas (y el cuerpo) arrastraban un
#     icosaedro de radio 1 sin material, colado en algun paso anterior de la
#     cadena y copiado de exportacion en exportacion. En Godot seria una bola
#     gris del tamaño del personaje, y ademas reventaba el AABB con el que el
#     nivel escala al chef.
#   · EL CUERPO VA SIN TEXTURA EMBEBIDA. Su atlas es el tono de piel "neutro",
#     y el juego pone SIEMPRE la piel elegida por `albedo_texture` (las cuatro
#     viajan aparte, en JPG): embeber una quinta copia solo engordaria el .pck.
#     Y como al desenchufar la imagen el exportador escribe como color base el
#     valor del socket —que Meshy deja en 0.8—, se pone a 1.0 antes, o el chef
#     saldria un 20% mas oscuro que en los renders.
#   · LAS NARICES TAMPOCO LLEVAN TEXTURA: apuntan al mismo texel de piel que el
#     cuerpo, asi que en el juego reciben el material del cuerpo ya con su piel
#     puesta (si no, cambiar de tono dejaba la nariz del tono anterior).
#   · Las demas (pelo, barbas, cejas, gafas) van como estan: material plano sin
#     imagen, que el juego tiñe.
#
#   blender --background --python tools/blender/chef_empaquetar.py -- <origen> <destino>
import bpy, sys, os

a = sys.argv[sys.argv.index("--") + 1:]
ORIGEN, DESTINO = os.path.abspath(a[0]), os.path.abspath(a[1])
os.makedirs(DESTINO, exist_ok=True)

PIEZAS = (["chef_cuerpo", "chef_cejas", "chef_gafas"]
          + ["chef_nariz_%s" % n for n in ("pequena", "media", "grande")]
          + ["chef_pelo_%s" % n for n in ("corto", "rizado", "ondulado", "despeinado",
                                           "flequillo", "bob", "melena", "larga",
                                           "mono", "coletas")]
          + ["chef_%s" % n for n in ("bigote", "perilla", "bigote_perilla",
                                     "barba_rala", "barba_corta", "barba_larga")])


def _sin_imagen(mat):
    """Desenchufa la textura del material y deja el color base en blanco."""
    if not mat.use_nodes:
        return
    nt = mat.node_tree
    b = nt.nodes.get("Principled BSDF")
    for n in list(nt.nodes):
        if n.type == "TEX_IMAGE":
            nt.nodes.remove(n)
    if b is not None:
        b.inputs["Base Color"].default_value = (1.0, 1.0, 1.0, 1.0)
    mat.diffuse_color = (1.0, 1.0, 1.0, 1.0)


for nombre in PIEZAS:
    src = os.path.join(ORIGEN, nombre + ".glb")
    if not os.path.isfile(src):
        print("[chef] FALTA %s" % src)
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    sc = bpy.context.scene
    tirados = 0
    for o in list(sc.objects):
        if o.type == "MESH" and o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o, do_unlink=True)
            tirados += 1
    mallas = [o for o in sc.objects if o.type == "MESH"]
    if nombre == "chef_cuerpo" or nombre.startswith("chef_nariz"):
        for o in mallas:
            for m in o.data.materials:
                _sin_imagen(m)
    for img in list(bpy.data.images):
        if img.users == 0:
            bpy.data.images.remove(img)
    caras = sum(len(o.data.polygons) for o in mallas)
    dst = os.path.join(DESTINO, nombre + ".glb")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB",
                              export_apply=False, export_animations=False,
                              export_image_format="NONE")
    print("[chef] %-22s %6d caras, %d esferas fuera, %5d KB -> %s"
          % (nombre, caras, tirados, os.path.getsize(dst) // 1024, os.path.basename(dst)))
print("[chef] empaquetado en %s" % DESTINO)
