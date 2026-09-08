# Mide los OJOS de un personaje ya hecho, para que los del chef —que se generan
# por codigo— tengan la misma forma que los del resto del reparto.
#
# Los ojos son los texeles OSCUROS de la cara: se localizan por color, se
# parten en izquierdo y derecho, y se devuelven sus medidas en FRACCIONES DEL
# ALTO DE LA CABEZA, que es lo que usa chef_piezas.py.
#
#   blender --background --python tools/blender/medir_ojos.py -- <modelo.glb>
import bpy, sys, os
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
SRC = os.path.abspath(a[0])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
sc = bpy.context.scene
malla = max((o for o in sc.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
me = malla.data
me.calc_loop_triangles()
M = malla.matrix_world
V = np.array([M @ v.co for v in me.vertices], dtype=np.float64)
lo, hi = V.min(axis=0), V.max(axis=0)
alto = hi[2] - lo[2]

# el cuello: la fila mas estrecha de la mitad alta
anchos = []
for k in range(30, 62):
    z = lo[2] + alto * k / 100.0
    b = V[np.abs(V[:, 2] - z) < alto * 0.01]
    if len(b) > 20:
        anchos.append((b[:, 0].max() - b[:, 0].min(), z))
z_cuello = min(anchos)[1] if anchos else lo[2] + alto * 0.55
alto_cab = hi[2] - z_cuello

img = next((i for i in bpy.data.images if i.size[0] > 8), None)
uv = me.uv_layers.active.data
W, H = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[..., :3]
col = np.zeros((len(V), 3))
cnt = np.zeros(len(V))
for tri in me.loop_triangles:
    for vi, li in zip(tri.vertices, tri.loops):
        u, w = uv[li].uv
        col[vi] += px[int(w * (H - 1)) % H, int(u * (W - 1)) % W]
        cnt[vi] += 1
ok = cnt > 0
col[ok] /= cnt[ok][:, None]
nor = np.array([(M.to_3x3() @ v.normal).normalized() for v in me.vertices])
lum = col.mean(axis=1)
# el ojo: lo mas oscuro de la cara, mirando de frente y en la banda de los ojos
cara = ok & (V[:, 2] > z_cuello) & (nor[:, 1] < -0.25)
oscuro = cara & (lum < 0.12)
if oscuro.sum() < 40:
    oscuro = cara & (lum < np.percentile(lum[cara], 3))
print("[ojo] %s: cabeza %.1f%% del alto, %d texeles oscuros"
      % (os.path.basename(SRC), 100.0 * alto_cab / alto, int(oscuro.sum())))
for nom, sel in (("L", oscuro & (V[:, 0] > 0)), ("R", oscuro & (V[:, 0] < 0))):
    P = V[sel]
    if len(P) < 20:
        print("   %s: pocos (%d)" % (nom, len(P)))
        continue
    cx = float(np.median(P[:, 0]))
    cz = float(np.median(P[:, 2]))
    anc = float(np.percentile(P[:, 0], 95) - np.percentile(P[:, 0], 5))
    altura = float(np.percentile(P[:, 2], 95) - np.percentile(P[:, 2], 5))
    print("   %s n=%4d  sep %.4f  ancho %.4f  alto %.4f  bajo %.4f  (ratio alto/ancho %.2f)"
          % (nom, len(P), abs(cx) / alto_cab, (anc / 2) / alto_cab,
             (altura / 2) / alto_cab, (hi[2] - cz) / alto_cab, altura / max(anc, 1e-9)))
