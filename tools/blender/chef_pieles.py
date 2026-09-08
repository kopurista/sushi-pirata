# LOS CUATRO TONOS DE PIEL DEL CHEF, en CUATRO TEXTURAS del mismo cuerpo.
#
# Cuatro modelos serian cuatro veces los mismos 50.000 vertices para cambiar un
# color, asi que lo que se genera son cuatro atlas y el juego le cambia el
# `albedo_texture` al material.
#
# Lo que hay que respetar es el SOMBREADO: estos modelos lo traen HORNEADO en
# la textura, asi que no vale pintar la piel de un color plano — se perderian
# los huecos de las cuencas, la sombra bajo la barbilla y el modelado entero de
# la cara. Lo que se hace es conservar la RELACION de brillo de cada texel con
# la piel media y aplicarsela al tono nuevo.
#
# Y la piel se localiza por CROMATICIDAD (el color quitandole el brillo), no por
# distancia de color: la cromaticidad no cambia con la sombra, asi que una
# mejilla en penumbra sigue siendo piel, mientras que la camisa blanca (neutra)
# y el mandil azul se quedan fuera solos.
#
#   blender --background --python tools/blender/chef_pieles.py -- <cuerpo.glb> <carpeta>
import bpy, sys, os
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = os.path.abspath(a[0]), os.path.abspath(a[1])
os.makedirs(OUT, exist_ok=True)

CROMA = float(os.environ.get("PIEL_CROMA", 0.18))   # cuanto puede apartarse del tono de la piel
LUM_MIN = float(os.environ.get("PIEL_LUM_MIN", 0.10))

# Los cuatro tonos, en sRGB. El "neutro" es el que ya trae el modelo.
TONOS = {
    "muy_blanca": (1.000, 0.845, 0.755),
    "neutra":     (0.945, 0.722, 0.659),
    "morena":     (0.760, 0.530, 0.395),
    "oscura":     (0.455, 0.295, 0.215),
}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
sc = bpy.context.scene
malla = max((o for o in sc.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
img = next(i for i in bpy.data.images if i.size[0] > 8)
W, H = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
rgb = px[..., :3].copy()
print("[piel] atlas %dx%d" % (W, H))

# LA PIEL DE REFERENCIA sale de la CARA, no de una media del atlas: ahi tambien
# estan la camisa y el mandil.
M = malla.matrix_world
malla.data.calc_loop_triangles()
uv = malla.data.uv_layers.active.data
vs = [M @ v.co for v in malla.data.vertices]
zlo, zhi = min(v.z for v in vs), max(v.z for v in vs)
alto = zhi - zlo
cand = []
for tri in malla.data.loop_triangles:
    p = [M @ malla.data.vertices[vi].co for vi in tri.vertices]
    if min(q.z for q in p) < zlo + alto * 0.68 or tri.normal.y > -0.4:
        continue
    for li in tri.loops:
        u, w = uv[li].uv
        cand.append(rgb[int(w * (H - 1)) % H, int(u * (W - 1)) % W])
piel = np.median(np.array(cand), axis=0)
lum_piel = float(piel.mean())
c_piel = piel / (lum_piel + 1e-6)
print("[piel] piel de la cara %s (lum %.3f), %d muestras"
      % (tuple(round(float(x), 3) for x in piel), lum_piel, len(cand)))

lum = rgb.mean(axis=2)
cro = np.linalg.norm(rgb / (lum[..., None] + 1e-6) - c_piel, axis=2)
mask = (cro < CROMA) & (lum > LUM_MIN)
print("[piel] %d texeles de piel (%.1f%% del atlas)"
      % (int(mask.sum()), 100.0 * mask.sum() / (W * H)))

# LA RELACION DE BRILLO es lo que guarda el sombreado. Se acota por arriba para
# que un brillo especular no dispare el tono nuevo a blanco.
razon = np.clip(lum / (lum_piel + 1e-6), 0.0, 1.35)[..., None]

for nombre, tono in TONOS.items():
    nuevo = px.copy()
    t = np.array(tono, dtype=np.float32)
    nuevo[..., :3] = np.where(mask[..., None], np.clip(t * razon, 0.0, 1.0), rgb)
    salida = bpy.data.images.new("piel_" + nombre, W, H, alpha=True)
    salida.pixels = nuevo.ravel().tolist()
    salida.file_format = "PNG"
    ruta = os.path.join(OUT, "chef_piel_%s.png" % nombre)
    salida.filepath_raw = ruta
    salida.save()
    print("[piel] -> %s" % ruta)
    bpy.data.images.remove(salida)
