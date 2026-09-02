"""Borra los ojos negros de un concepto de personaje y apunta sus medidas.

A Meshy hay que mandarle la cara LISA (con ojos los talla como cuencas con
reborde que cogen luz y no hay repintado que las esconda), asi que este
script quita los dos blobs negros de la cara y guarda en <salida>_ojos.json
donde estaban, en FRACCIONES del cuerpo, para pintarlos luego en Blender:
  sep_frac / rx_frac : del ancho de la silueta a la altura de los ojos
  z_frac / ry_frac   : del alto total del personaje
Uso: python tools/quitar_ojos.py <concepto.png> <salida.png> [encoge]
"""
import sys, json
import numpy as np
from PIL import Image
from collections import deque

ENTRA, SALE = sys.argv[1], sys.argv[2]
ENCOGE = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0

im = Image.open(ENTRA).convert("RGBA")
a = np.array(im).astype(np.int32); H, W = a.shape[:2]
r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
negro = (al > 200) & (r < 70) & (g < 70) & (b < 70)
negro[int(H * 0.45):] = False          # solo la mitad alta: botas y cinturon fuera

lab = np.zeros_like(negro, dtype=np.int32); comps = []
for y, x in zip(*np.nonzero(negro)):
    if lab[y, x]:
        continue
    k = len(comps) + 1; q = deque([(y, x)]); lab[y, x] = k; pts = []
    while q:
        cy, cx = q.popleft(); pts.append((cy, cx))
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = cy + dy, cx + dx
            if 0 <= ny < H and 0 <= nx < W and negro[ny, nx] and not lab[ny, nx]:
                lab[ny, nx] = k; q.append((ny, nx))
    comps.append(pts)
comps.sort(key=len, reverse=True)
assert len(comps) >= 2, "no se han encontrado dos ojos"

out = a.copy(); ojos = []
for pts in comps[:2]:
    p = np.array(pts)
    cx, cy = p[:, 1].mean(), p[:, 0].mean()
    w = p[:, 1].max() - p[:, 1].min() + 1
    h = p[:, 0].max() - p[:, 0].min() + 1
    ojos.append((float(cx), float(cy), float(w), float(h) * ENCOGE))
    # la mascara se DILATA 4 texeles: el borde antialiasado del negro no pasa
    # el umbral y quedaria como un aro oscuro alrededor
    m = np.zeros((H, W), dtype=bool); m[p[:, 0], p[:, 1]] = True
    for _ in range(4):
        m = m | np.roll(m, 1, 0) | np.roll(m, -1, 0) | np.roll(m, 1, 1) | np.roll(m, -1, 1)
    for yy in np.unique(np.nonzero(m)[0]):
        fila = np.nonzero(m[yy])[0]; izq, der = fila.min(), fila.max()
        cizq = a[yy, izq - 7:izq - 1, :3].mean(axis=0)
        cder = a[yy, der + 2:der + 8, :3].mean(axis=0)
        t = np.linspace(0, 1, der - izq + 1)[:, None]
        out[yy, izq:der + 1, :3] = np.round(cizq * (1 - t) + cder * t).astype(np.int32)
Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(SALE)

op = al > 200
rows = np.nonzero(op.any(axis=1))[0]; top, bot = rows.min(), rows.max()
cy = (ojos[0][1] + ojos[1][1]) / 2
fila = np.nonzero(op[int(cy)])[0]; ancho = fila.max() - fila.min() + 1
met = {
    "sep_frac": abs(ojos[0][0] - ojos[1][0]) / 2 / ancho,
    "z_frac": (cy - top) / (bot - top),
    "ry_frac": (ojos[0][3] + ojos[1][3]) / 4 / (bot - top),
    "rx_frac": (ojos[0][2] + ojos[1][2]) / 4 / ancho,
}
ruta = SALE.replace("_concepto.png", "_ojos.json")
json.dump(met, open(ruta, "w"), indent=1)
print(SALE, {k: round(v, 4) for k, v in met.items()})
