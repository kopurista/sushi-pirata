"""Mide en el CONCEPTO donde estan los hombros, las muñecas y las piernas.

Se mide en el dibujo y no en la malla porque la silueta del concepto esta
LIMPIA: es una mancha de alfa sin cejas, bigote ni arrugas, asi que partirla
por filas da islas que son de verdad "brazo, cuerpo, brazo". En la malla, los
mismos cortes se rompian con cada rasgo de la cara y el hombro salia a la
altura de los ojos.

Todo se guarda en FRACCIONES del cuerpo (del alto total, y del ancho de la
silueta a esa misma altura), que es lo que deja aplicarlas a un modelo 3D
normalizado. Uso: python tools/medir_cuerpo.py <concepto.png> <salida.json>
"""
import sys, json
import numpy as np
from PIL import Image

im = Image.open(sys.argv[1]).convert("RGBA")
a = np.array(im)
op = a[..., 3] > 200
if op.mean() > 0.98:                       # fondo blanco opaco en vez de alfa
    op = a[..., :3].min(axis=2) < 240
H, W = op.shape
filas = np.nonzero(op.any(axis=1))[0]
top, bot = int(filas.min()), int(filas.max())
alto = bot - top
HUECO = max(3, int(alto * 0.012))

def islas(y):
    xs = np.nonzero(op[y])[0]
    if len(xs) == 0:
        return []
    g = []; ini = 0
    for i in range(1, len(xs)):
        if xs[i] - xs[i - 1] > HUECO:
            g.append((xs[ini], xs[i - 1])); ini = i
    g.append((xs[ini], xs[-1]))
    return [x for x in g if x[1] - x[0] >= alto * 0.015]

perfil = {y: islas(y) for y in range(top, bot + 1)}
tres = [y for y in range(top, bot + 1) if len(perfil[y]) >= 3]
dos_abajo = [y for y in range(top + int(alto * 0.6), bot + 1) if len(perfil[y]) == 2]
assert tres, "no se ven los brazos separados del cuerpo en el concepto"

y_hombro, y_muneca = min(tres), max(tres)
y_med = (y_hombro + y_muneca) // 2
g = perfil[y_med]
brazo_px = (abs((g[0][0] + g[0][1]) / 2 - W / 2) + abs((g[-1][0] + g[-1][1]) / 2 - W / 2)) / 2
ancho_h = perfil[y_hombro][0][0], perfil[y_hombro][-1][1]
ancho_hombro = ancho_h[1] - ancho_h[0]

if dos_abajo:
    y_entre = min(dos_abajo)
    gp = perfil[dos_abajo[len(dos_abajo) // 2]]
    pierna_px = (abs((gp[0][0] + gp[0][1]) / 2 - W / 2) + abs((gp[-1][0] + gp[-1][1]) / 2 - W / 2)) / 2
else:
    y_entre = top + int(alto * 0.78); pierna_px = alto * 0.06

met = {
    "hombro_z": (y_hombro - top) / alto,      # 0 = coronilla, 1 = suelo
    "muneca_z": (y_muneca - top) / alto,
    "brazo_x": brazo_px / ancho_hombro,       # del ancho a la altura del hombro
    "cadera_z": (y_entre - top) / alto,
    "pierna_x": pierna_px / ancho_hombro,
    "ancho_hombro": ancho_hombro / alto,
}
json.dump(met, open(sys.argv[2], "w"), indent=1)
print(sys.argv[2], {k: round(v, 4) for k, v in met.items()})
