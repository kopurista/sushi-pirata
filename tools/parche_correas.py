"""Dibuja las DOS correas del parche del pirata sobre el concepto de Ludo.

Al generador no se le da bien la GEOMETRIA de las correas: pidiendole "una
arriba y otra por debajo de la oreja" devolvia aspas cruzadas por delante de la
cara, tres bandas, o una atravesando los dos ojos (cuatro tandas seguidas). Lo
que si hace bien es el parche LIMPIO, sin ninguna correa; el trazado se hace
aqui, que es geometria pura y sale igual todas las veces.

  python tools/parche_correas.py <entrada.png|webp> <salida.png>
"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw

SS = 4                      # supermuestreo, para que el canto quede suave
GROSOR = float(os.environ.get("GROSOR", 0.30))      # del radio del parche
# Los angulos van en el sistema de la IMAGEN con el parche a la IZQUIERDA
# (0 grados = hacia la derecha, 90 = hacia arriba). Si el parche cae al otro
# lado se espejan solos.
#   SUP cruza la cabeza hacia el lado CONTRARIO al parche, por encima de la
#   bandana; INF se va hacia atras por DEBAJO de la oreja de su propio lado.
ANG_SUP = float(os.environ.get("ANG_SUP", 55.0))
ANG_INF = float(os.environ.get("ANG_INF", 218.0))

MODO = "parche"
_args = sys.argv[1:]
if _args and _args[0] == "banda":
    MODO = "banda"
    _args = _args[1:]
ENTRA, SALE = _args[0], _args[1]
B_ALTURA = float(_args[2]) if len(_args) > 2 else 0.62   # del alto de la cabeza
B_ANG = float(_args[3]) if len(_args) > 3 else 12.0      # grados de inclinacion
F_CABEZA = float(os.environ.get("F_CABEZA", 0.34))       # cuanto ocupa la cabeza
im = Image.open(ENTRA).convert("RGBA")
W, H = im.size

if MODO == "banda":
    a = np.array(im).astype(int)
    alfa = a[..., 3]
    ys, xs = np.nonzero(alfa > 200)
    y0, y1 = ys.min(), ys.max()
    alto = y1 - y0
    # la CABEZA es la mitad alta del sujeto; se mide su ancho a la altura pedida
    # B_ALTURA es fraccion DE LA CABEZA (0 = coronilla, 1 = barbilla), y la
    # cabeza de estas figuritas ocupa ~0.34 del alto total. Midiendo sobre el
    # alto ENTERO la banda caia en el cuello.
    yb = int(y0 + alto * F_CABEZA * B_ALTURA)
    fila = np.nonzero(alfa[yb] > 200)[0]
    if len(fila) < 4:
        print("[correas] la banda cae fuera del sujeto"); sys.exit(1)
    cx = (fila.min() + fila.max()) / 2.0
    ancho = fila.max() - fila.min()
    capa = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(capa)
    t = np.radians(B_ANG)
    dx, dy = np.cos(t), -np.sin(t)
    largo = W
    d.line([((cx - dx * largo) * SS, (yb - dy * largo) * SS),
            ((cx + dx * largo) * SS, (yb + dy * largo) * SS)],
           fill=(24, 22, 26, 255), width=max(2, int(ancho * 0.075 * SS)))
    capa = capa.resize((W, H), Image.LANCZOS)
    cap = np.array(capa).astype(int)
    cap[..., 3] = (cap[..., 3] * (alfa > 200)).astype(int)
    out = Image.alpha_composite(im, Image.fromarray(np.clip(cap, 0, 255).astype(np.uint8)))
    out.save(SALE)
    print("[correas] banda en y=%d, ancho de cabeza %d -> %s" % (yb, ancho, SALE))
    sys.exit(0)
a = np.array(im).astype(int)
alfa = a[..., 3]
rgb = a[..., :3]
lum = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]

# EL PARCHE: la mancha negra mas grande de la mitad alta del sujeto. Se busca
# por componente conexa y no por umbral a secas, que las cejas tambien son
# negras y estan al lado.
# OJO: hay que exigir POCA CROMA. El pañuelo rojo oscuro baja de 70 de
# luminancia, así que sin este filtro el "parche" detectado era un trozo de
# tela y las correas salían ROJAS y en el sitio equivocado.
croma = rgb.max(axis=2) - rgb.min(axis=2)
negro = (alfa > 200) & (lum < 60) & (croma < 40)
negro[int(H * 0.45):] = False
lab = np.zeros_like(negro, dtype=np.int32)
comps = []
from collections import deque
for y, x in zip(*np.nonzero(negro)):
    if lab[y, x]:
        continue
    k = len(comps) + 1
    q = deque([(y, x)])
    lab[y, x] = k
    pts = []
    while q:
        cy, cx = q.popleft()
        pts.append((cy, cx))
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = cy + dy, cx + dx
            if 0 <= ny < H and 0 <= nx < W and negro[ny, nx] and not lab[ny, nx]:
                lab[ny, nx] = k
                q.append((ny, nx))
    comps.append(pts)
# el componente MAYOR, guardando su etiqueta: `comps` se ordena pero `lab`
# conserva las etiquetas originales, y usar lab==1 cogía otro trozo
idx = max(range(len(comps)), key=lambda i: len(comps[i]))
etiqueta = idx + 1
pts = np.array(comps[idx])
cy, cx = pts[:, 0].mean(), pts[:, 1].mean()
r = float(np.sqrt(len(pts) / np.pi))
print("[correas] parche en (%.0f, %.0f) radio %.1f  (%d pixeles)" % (cx, cy, r, len(pts)))

# hacia donde esta la NUCA: el lado del parche mas alejado del centro del sujeto
xs = np.nonzero((alfa > 200).any(axis=0))[0]
centro_x = (xs.min() + xs.max()) / 2.0
signo = -1.0 if cx < centro_x else 1.0
print("[correas] el parche cae al %s, las correas van hacia %s"
      % ("lado izquierdo" if signo < 0 else "lado derecho",
         "la izquierda" if signo < 0 else "la derecha"))

capa = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
d = ImageDraw.Draw(capa)
color = tuple(int(v) for v in np.median(rgb[lab == etiqueta], axis=0)) + (255,)
ancho = max(2, int(r * GROSOR * SS))
largo = W  # de sobra: se recorta luego con la silueta
for ang in (ANG_SUP, ANG_INF):
    t = np.radians(ang if signo < 0 else 180.0 - ang)   # espejo si va al otro lado
    x0 = cx + np.cos(t) * r * 0.72
    y0 = cy - np.sin(t) * r * 0.72
    x1 = cx + np.cos(t) * largo
    y1 = cy - np.sin(t) * largo
    d.line([(x0 * SS, y0 * SS), (x1 * SS, y1 * SS)], fill=color, width=ancho)
capa = capa.resize((W, H), Image.LANCZOS)

# LAS CORREAS SE RECORTAN A LA SILUETA: fuera de la cabeza no hay nada que
# atar, y sin recortar salian volando sobre el fondo blanco.
cap = np.array(capa).astype(int)
cap[..., 3] = (cap[..., 3] * (alfa > 200)).astype(int)
capa = Image.fromarray(np.clip(cap, 0, 255).astype(np.uint8))

out = Image.alpha_composite(im, capa)
# y el PARCHE vuelve por encima: las correas nacen DETRAS de el
solo_parche = im.crop((0, 0, W, H))
mask = Image.fromarray(((lab == etiqueta) * 255).astype(np.uint8))
out.paste(solo_parche, (0, 0), mask)
out.save(SALE)
print("[correas] ->", SALE)


# --- MODO BANDA: la correa vista desde el lado o desde atras -----------------
# Un parche es UNA SOLA correa que va de una punta del parche a la otra rodeando
# la cabeza (lo apunto porque es lo que hace que las vistas casen entre si), asi
# que en el perfil y en la nuca hay que dibujar esa banda cruzando la cabeza.
# Aqui no hay parche que detectar, asi que la banda se coloca por GEOMETRIA de
# la cabeza: se mide la silueta de la mitad alta y se traza una recta a la
# altura y el angulo que se pidan, recortada al sujeto.
#
#   python tools/parche_correas.py banda <entrada> <salida> [altura] [angulo]
