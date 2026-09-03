# Le PINTA LOS OJOS al David que Meshy devolvió rigueado (el pirate doll que
# pidió el usuario): viene con cejas y nariz modeladas pero SIN ojos, que es el
# fallo de siempre de imagen→3D con una cara de trazo fino.
#
# No hay "rectángulo de la cara" en el atlas —está troceado por triángulos—, así
# que se rasteriza cada triángulo en UV y se deshace la interpolación
# baricéntrica por téxel (la técnica de tools/face_paint.py y de david_cara.py).
# Con la posición y la normal 3D de cada téxel ya se puede pintar por geometría.
#
# Los ojos van POR CONSTRUCCIÓN, no por detección: dos ÓVALOS NEGROS verticales
# del estilo Link's Awakening, colocados bajo las cejas —que sí se detectan, son
# lo único gris oscuro de la frente— y a la separación que ellas marcan.
#
#   blender --background --python tools/blender/pirata_cara.py -- diag
#   blender --background --python tools/blender/pirata_cara.py -- pintar
import bpy, sys, os, math
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GLB = os.environ.get("PIRATA_GLB", os.path.join(
    ROOT, "_gen", "meshy", "pirata_zip", "Meshy_AI_pirate_doll_rigged_biped",
    "Meshy_AI_pirate_doll_rigged_biped_Animation_Walking_withSkin.glb"))
OUT = os.path.abspath(os.environ.get("PIRATA_OUT", os.path.join(ROOT, "_gen", "pirata")))
os.makedirs(OUT, exist_ok=True)
modo = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "diag"

# Perillas del ojo, en FRACCIONES del alto de la CABEZA (así valen aunque el
# modelo se reescale). MEDIDAS sobre el primer plano de la cara despejando
# contra la proyección de la cámara (ortho_scale conocido / píxeles del render),
# no estimadas: detectar las cejas por color no vale, porque el pelo y las
# orejas son del mismo gris y se cuelan a decenas de miles de téxeles.
F_SEP = float(os.environ.get("OJO_SEP", 0.145))    # separación al eje
F_ALTO = float(os.environ.get("OJO_ALTO", 0.068))  # semieje vertical
F_ANCHO = float(os.environ.get("OJO_ANCHO", 0.038))  # semieje horizontal
F_BAJO = float(os.environ.get("OJO_BAJO", 0.329))  # por debajo de la CORONILLA
NEGRO = np.array([0.045, 0.040, 0.048], dtype=np.float32)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
me = obj.data
me.calc_loop_triangles()
img = [i for i in bpy.data.images if i.size[0] > 8][0]
W, H = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)

M = obj.matrix_world
R = M.to_3x3()
V = np.array([M @ v.co for v in me.vertices], dtype=np.float32)
N = np.array([(R @ v.normal).normalized() for v in me.vertices], dtype=np.float32)
uv = me.uv_layers.active.data
zmin, zmax = float(V[:, 2].min()), float(V[:, 2].max())
alto = zmax - zmin
print("[pir] textura %dx%d   malla z %.3f..%.3f (alto %.3f)" % (W, H, zmin, zmax, alto))

# --- rasterizado UV -> posición y normal por téxel ---------------------------
POS = np.full((H, W, 3), np.nan, dtype=np.float32)
NRM = np.zeros((H, W, 3), dtype=np.float32)
for tri in me.loop_triangles:
    li = tri.loops
    vi = list(tri.vertices)
    uvs = np.array([uv[i].uv for i in li], dtype=np.float64) * [W, H]
    x0, y0 = np.floor(uvs.min(axis=0)).astype(int)
    x1, y1 = np.ceil(uvs.max(axis=0)).astype(int)
    x0 = max(x0, 0); y0 = max(y0, 0); x1 = min(x1, W - 1); y1 = min(y1, H - 1)
    if x1 < x0 or y1 < y0:
        continue
    xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
    (ax, ay), (bx, by), (cx, cy) = uvs
    det = (bx - ax) * (cy - ay) - (cx - ax) * (by - ay)
    if abs(det) < 1e-9:
        continue
    l1 = ((bx - xs) * (cy - ys) - (cx - xs) * (by - ys)) / det
    l2 = ((cx - xs) * (ay - ys) - (ax - xs) * (cy - ys)) / det
    l3 = 1.0 - l1 - l2
    ins = (l1 >= -0.002) & (l2 >= -0.002) & (l3 >= -0.002)
    if not ins.any():
        continue
    yy, xx = np.nonzero(ins)
    b = np.stack([l1[ins], l2[ins], l3[ins]], axis=1).astype(np.float32)
    POS[y0 + yy, x0 + xx] = b @ V[vi]
    n = b @ N[vi]
    NRM[y0 + yy, x0 + xx] = n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-6)
cubierto = ~np.isnan(POS[..., 0])
print("[pir] téxeles cubiertos: %.1f%%" % (100.0 * cubierto.mean()))

rgb = px[..., :3]
lum = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
croma = rgb.max(axis=2) - rgb.min(axis=2)

# LA CABEZA: la parte alta del modelo. En esta figurita ocupa casi la mitad.
cabeza = cubierto & (POS[..., 2] > zmin + 0.55 * alto)
delante = cabeza & (NRM[..., 1] < -0.30)     # el modelo mira a -Y
piel = delante & (rgb[..., 0] > rgb[..., 2] + 0.06) & (lum > 0.30)
# LAS CEJAS son lo único gris (poca croma) y oscuro de la mitad alta de la cara
# de frente DE VERDAD (normal muy a -Y) y cerca del eje: a los lados están las
# orejas y el pelo, que son igual de grises y se colaban a decenas de miles
ceja = (cubierto & (NRM[..., 1] < -0.62) & (croma < 0.10) & (lum < 0.62)
        & (POS[..., 2] > zmin + 0.78 * alto)
        & (np.abs(POS[..., 0]) < 0.32 * alto))

if ceja.sum() < 40:
    print("[pir] AVISO: cejas no detectadas (%d téxeles)" % ceja.sum())
Pc = POS[ceja]
alto_cab = float(POS[cabeza][:, 2].max() - POS[cabeza][:, 2].min())
lados = {}
for nombre, sel in (("L", ceja & (POS[..., 0] > 0)), ("R", ceja & (POS[..., 0] < 0))):
    P = POS[sel]
    if len(P) < 10:
        print("[pir] ceja %s: sin datos" % nombre)
        continue
    lados[nombre] = (float(np.median(P[:, 0])), float(np.median(P[:, 1])), float(np.median(P[:, 2])))
    print("[pir] ceja %s: n=%d centro (%.3f, %.3f, %.3f)  x %.3f..%.3f  z %.3f..%.3f"
          % (nombre, sel.sum(), lados[nombre][0], lados[nombre][1], lados[nombre][2],
             P[:, 0].min(), P[:, 0].max(), P[:, 2].min(), P[:, 2].max()))
print("[pir] alto de la cabeza %.3f  piel %d téxeles  color mediano %s"
      % (alto_cab, piel.sum(), np.round(np.median(rgb[piel], axis=0), 3) if piel.sum() else "-"))

if modo == "diag":
    sys.exit(0)

# --- pintar los ojos ---------------------------------------------------------
nuevo = rgb.copy()
sep = F_SEP * alto_cab
ra = F_ANCHO * alto_cab
rb = F_ALTO * alto_cab
z_ojo = zmax - F_BAJO * alto_cab
print("[pir] ojos: sep %.3f  z %.3f  semiejes %.3f x %.3f" % (sep, z_ojo, ra, rb))

pintados = 0
for signo in (1.0, -1.0):
    dx = POS[..., 0] - signo * sep
    dz = POS[..., 2] - z_ojo
    # solo la cara de delante, y por elipse en el plano de la cara
    ojo = delante & (np.abs(dx) < ra * 1.6) & (np.abs(dz) < rb * 1.6)
    ojo &= ((dx / ra) ** 2 + (dz / rb) ** 2) <= 1.0
    nuevo[ojo] = NEGRO
    pintados += int(ojo.sum())
print("[pir] téxeles de ojo pintados: %d" % pintados)

a = np.ones((H, W, 4), dtype=np.float32)
a[..., :3] = nuevo
out_img = bpy.data.images.new("pirata_tex", W, H, alpha=True)
out_img.pixels = a.ravel().tolist()
out_img.filepath_raw = os.path.join(OUT, "pirata_tex.png")
out_img.file_format = "PNG"
out_img.save()
print("[pir] ->", out_img.filepath_raw)
