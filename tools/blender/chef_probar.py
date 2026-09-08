# Monta el chef con las piezas que se le pasen y renderiza su CARA, para poder
# comparar combinaciones (dos tamanos de ojo x tres narices) de un vistazo.
#
#   blender --background --python tools/blender/chef_probar.py -- \
#       <cuerpo.glb> <salida.png> [pieza1.glb pieza2.glb ...]
import bpy, sys, os, math, mathutils

a = sys.argv[sys.argv.index("--") + 1:]
CUERPO, SALIDA = os.path.abspath(a[0]), os.path.abspath(a[1])
PIEZAS = [os.path.abspath(p) for p in a[2:]]
CARA = os.environ.get("CHEF_CARA", "1") != "0"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=CUERPO)
for p in PIEZAS:
    bpy.ops.import_scene.gltf(filepath=p)

# EL PELO VA EN BLANCO en la malla y lo tiñe el juego con `albedo_color`, que
# multiplica. Aqui se hace lo mismo para poder verlo del color que sea sin
# generar una malla por color. El valor va en sRGB, como en Godot, y se pasa a
# lineal, que es lo que entiende Blender.
# CAMBIO DE PIEL: se sustituyen los pixeles del atlas del cuerpo por los de la
# textura que se pase, que es lo mismo que hara el juego con `albedo_texture`.
_piel = os.environ.get("PIEL_TEX", "")
if _piel:
    # SE CAMBIAN TODAS LAS COPIAS DEL ATLAS, no solo la del cuerpo: la nariz es
    # una pieza aparte que apunta al mismo texel de piel, y cada .glb trae su
    # propia copia de la imagen. Sin esto, el chef cambiaba de tono y se
    # quedaba con la NARIZ del tono anterior. En el juego se resuelve al reves
    # —la nariz usa el material del cuerpo— pero aqui son escenas sueltas.
    _src = bpy.data.images.load(os.path.abspath(_piel))
    _pix = _src.pixels[:]
    for _im in bpy.data.images:
        if _im is not _src and tuple(_im.size) == tuple(_src.size):
            _im.pixels = _pix

lin = lambda c: c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _tintar(prefijo, valor):
    if not valor:
        return
    r, g, b = [float(x) for x in valor.split(",")]
    for m in bpy.data.materials:
        if m.name.startswith(prefijo):
            m.diffuse_color = (lin(r), lin(g), lin(b), 1.0)
            if m.use_nodes:
                m.node_tree.nodes["Principled BSDF"].inputs["Base Color"]                     .default_value = (lin(r), lin(g), lin(b), 1.0)


_tintar("Pelo", os.environ.get("PELO_TINTE", ""))
_tintar("Gafas", os.environ.get("GAFAS_TINTE", "0.12,0.11,0.12"))

sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "TEXTURE"
sc.world = bpy.data.worlds.new("w")
sc.world.color = (0.42, 0.55, 0.65)
sc.render.resolution_x, sc.render.resolution_y = 520, 560

vs = []
for ob in sc.objects:
    if ob.type == "MESH":
        for v in ob.data.vertices:
            vs.append(ob.matrix_world @ v.co)
lo = mathutils.Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
hi = mathutils.Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
c = (lo + hi) / 2.0
alto = hi.z - lo.z
cd = bpy.data.cameras.new("c")
cd.type = "ORTHO"
cam = bpy.data.objects.new("Cam", cd)
sc.collection.objects.link(cam)
sc.camera = cam
if CARA:
    cd.ortho_scale = alto * float(os.environ.get("CHEF_ZOOM", 0.42))
    cam.location = (c.x, c.y - alto * 3, hi.z - alto * 0.20)
else:
    cd.ortho_scale = alto * 1.08
    cam.location = (c.x, c.y - alto * 3, c.z)
_yaw = math.radians(float(os.environ.get("CHEF_YAW", 0)))
cam.location = (c.x + math.sin(_yaw) * alto * 3, c.y - math.cos(_yaw) * alto * 3, cam.location[2])
cam.rotation_euler = (math.radians(90), 0, _yaw)
sc.render.filepath = SALIDA
bpy.ops.render.render(write_still=True)
print("ok", SALIDA)
