# EL PETO DEL MANDIL SALIO BLANCO y tiene que ser del color de la falda.
#
# Meshy le puso al chef un mandil de dos colores: el peto (la parte de arriba,
# entre los tirantes) en blanco como la casaca, y la falda en azul marino. Se
# repinta el peto con el azul del propio mandil — leido de la textura, no
# elegido a ojo — rasterizando por BARICENTRICAS los triangulos de esa zona,
# que es lo unico que no se lleva por delante lo que hay al lado (la leccion de
# las gafas de Miku).
#
# La zona es geometrica: lo que MIRA AL FRENTE, es blanco de TELA (neutro, no
# piel) y cae en la banda del pecho por dentro de los tirantes.
#
#   blender --background --python tools/blender/chef_mandil.py -- <in.glb> <out.glb> [diag]
import bpy, sys, os
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
SRC, DEST = os.path.abspath(a[0]), os.path.abspath(a[1])
DIAG = len(a) > 2 and a[2] == "diag"

Z0 = float(os.environ.get("PETO_Z0", 0.42))   # de la altura del modelo
Z1 = float(os.environ.get("PETO_Z1", 0.585))
XMAX = float(os.environ.get("PETO_X", 0.135))
DILATA = int(os.environ.get("PETO_ORLA", 5))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
sc = bpy.context.scene
malla = max((o for o in sc.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
me = malla.data
me.calc_loop_triangles()
M = malla.matrix_world
V = np.array([M @ v.co for v in me.vertices])
nor = np.array([(M.to_3x3() @ v.normal).normalized() for v in me.vertices])
img = next(i for i in bpy.data.images if i.size[0] > 8)
W, H = img.size
pix = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
px = pix[..., :3]
uv = me.uv_layers.active.data

col = np.zeros((len(V), 3))
cnt = np.zeros(len(V))
for tri in me.loop_triangles:
    for vi, li in zip(tri.vertices, tri.loops):
        u, w = uv[li].uv
        col[vi] += px[int(w * (H - 1)) % H, int(u * (W - 1)) % W]
        cnt[vi] += 1
ok = cnt > 0
col[ok] /= cnt[ok][:, None]
lum = col.mean(axis=1)

alto = V[:, 2].max() - V[:, 2].min()
frente = ok & (nor[:, 1] < -0.30)
# TELA BLANCA, no piel: la piel es rojiza (r-b alto) y la tela es neutra
blanca = frente & (lum > 0.50) & (np.abs(col[:, 0] - col[:, 2]) < 0.08)
peto = blanca & (V[:, 2] > Z0 * alto) & (V[:, 2] < Z1 * alto) & (np.abs(V[:, 0]) < XMAX)
# EL AZUL DEL MANDIL SE LEE DE LA FALDA, no se elige: asi el peto queda
# exactamente del mismo color que lo de abajo aunque el modelo cambie.
falda = frente & (V[:, 2] < Z0 * alto) & (col[:, 2] > col[:, 0] + 0.03) & (lum < 0.25)
azul = np.median(col[falda], axis=0) if falda.sum() > 20 else np.array([0.016, 0.129, 0.243])
print("[peto] %d vertices de peto, %d de falda, azul %s"
      % (int(peto.sum()), int(falda.sum()), tuple(round(float(x), 3) for x in azul)))
if DIAG:
    azul = np.array([1.0, 0.0, 1.0])

pset = set(int(i) for i in np.nonzero(peto)[0])
mask = np.zeros((H, W), dtype=bool)
n = 0
for tri in me.loop_triangles:
    if sum(1 for vi in tri.vertices if vi in pset) < 2:
        continue
    uvs = np.array([uv[li].uv for li in tri.loops], dtype=np.float64) * [W, H]
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
    YY, XX = y0 + yy, x0 + xx
    # SE PINTA EL TRIANGULO ENTERO, sin volver a filtrar por color: filtrando
    # texel a texel, los que quedaban en sombra se salvaban y el peto salia
    # moteado y con el borde dentado. Los triangulos ya estan elegidos por
    # geometria, y lo unico que cae dentro son el peto y los tirantes, que ya
    # son de este azul.
    pix[YY, XX, :3] = azul
    mask[YY, XX] = True
    n += int(len(YY))
# LA ORLA DEL ATLAS TAMBIEN SE PINTA. Alrededor de cada isla hay un margen de
# relleno que el rasterizado no toca, y al muestrear la textura con filtrado ese
# blanco se cuela por el borde: el peto salia con una costura clara y dentada.
d = mask.copy()
for _ in range(DILATA):
    d[1:, :] |= mask[:-1, :]
    d[:-1, :] |= mask[1:, :]
    d[:, 1:] |= mask[:, :-1]
    d[:, :-1] |= mask[:, 1:]
    mask = d.copy()
orla = mask & ~np.all(np.isclose(pix[..., :3], azul, atol=1e-4), axis=2)
pix[orla, :3] = azul
print("[peto] texeles repintados: %d (+%d de orla)" % (n, int(orla.sum())))
img.pixels = pix.ravel().tolist()
img.pack()
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=DEST, export_format="GLB",
                          export_apply=False, export_animations=False)
print("[peto] exportado", DEST)
