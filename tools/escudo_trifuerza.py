"""Corre el triangulo de arriba del ESCUDO ANTIGUO para dejar una trifuerza
MAL HECHA (los dos de abajo alineados y el de arriba encima del derecho).

    python tools/escudo_trifuerza.py

Por que a mano y no en el prompt: a Ludo se le pidio la disposicion torcida en
tres generaciones distintas y las tres devolvieron la trifuerza CENTRADA. Es
geometria exacta, asi que sale mas barato moverla que seguir tirando dados.

Lee `_gen/ui2/col/escudo_antiguo_raw.webp` (lo que devolvio Ludo) y escribe
`_gen/ui2/col/escudo_antiguo.webp`, que es de donde tira `build_collectibles`.

El triangulo se identifica por COLOR y por COMPONENTE CONEXA, no por una caja
escrita a mano: el marco dorado del escudo tambien es amarillo, asi que se
descarta por tamano (es la isla mas grande) y los rayos de la gema por altura
(estan en la mitad de abajo). Se mueve con su CONTORNO NEGRO incluido —de ahi
la dilatacion de la mascara— y el hueco se rellena con la MEDIANA del azul de
alrededor, que es lo unico que no deja un parche de otro tono.
"""

from collections import deque
from pathlib import Path
from statistics import median

from PIL import Image, ImageFilter

RAW = Path("_gen/ui2/col/escudo_antiguo_raw.webp")
OUT = Path("_gen/ui2/col/escudo_antiguo.webp")
## Cuanto se ensancha la mascara para llevarse el contorno negro del triangulo.
DILATA = 15


def es_amarillo(p) -> bool:
    r, g, b, a = p
    return a > 200 and r > 195 and g > 140 and b < 140 and (r - b) > 90


def componentes(mask, w, h):
    lab = [0] * (w * h)
    out = []
    tag = 0
    for sy in range(h):
        for sx in range(w):
            if lab[sy * w + sx] or not mask[sy * w + sx]:
                continue
            tag += 1
            q = deque([(sx, sy)])
            lab[sy * w + sx] = tag
            pts = []
            while q:
                x, y = q.popleft()
                pts.append((x, y))
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if 0 <= nx < w and 0 <= ny < h \
                            and not lab[ny * w + nx] and mask[ny * w + nx]:
                        lab[ny * w + nx] = tag
                        q.append((nx, ny))
            out.append(pts)
    return out


def main() -> None:
    img = Image.open(RAW).convert("RGBA")
    w, h = img.size
    px = img.load()
    mask = [es_amarillo(px[x, y]) for y in range(h) for x in range(w)]
    islas = componentes(mask, w, h)
    islas.sort(key=len, reverse=True)
    # La isla mayor es el MARCO del escudo: fuera. De las demas, los triangulos
    # son las tres grandes de la mitad de arriba (los rayos de la gema quedan
    # por debajo).
    cand = []
    for pts in islas[1:]:
        if len(pts) < 2000:
            continue
        cy = sum(p[1] for p in pts) / len(pts)
        if cy > h * 0.62:
            continue
        cand.append(pts)
    cand = cand[:3]
    if len(cand) != 3:
        raise SystemExit("esperaba 3 triangulos, encontre %d" % len(cand))
    centros = [(sum(p[0] for p in pts) / len(pts),
                sum(p[1] for p in pts) / len(pts)) for pts in cand]
    arriba = min(range(3), key=lambda i: centros[i][1])
    abajo = [i for i in range(3) if i != arriba]
    derecho = max(abajo, key=lambda i: centros[i][0])
    dx = int(round(centros[derecho][0] - centros[arriba][0]))
    print("triangulo de arriba en x=%.0f, se corre %d px a la derecha"
          % (centros[arriba][0], dx))

    # Mascara del triangulo de arriba, DILATADA para llevarse su contorno.
    m = Image.new("L", (w, h), 0)
    mp = m.load()
    for x, y in cand[arriba]:
        mp[x, y] = 255
    m = m.filter(ImageFilter.MaxFilter(DILATA))
    mp = m.load()

    # Azul de relleno: la mediana del campo azul que rodea al triangulo.
    xs = [p[0] for p in cand[arriba]]
    ys = [p[1] for p in cand[arriba]]
    x0, x1 = max(min(xs) - 60, 0), min(max(xs) + 60, w - 1)
    y0, y1 = max(min(ys) - 60, 0), min(max(ys) + 60, h - 1)
    az = [[], [], []]
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if mp[x, y]:
                continue
            r, g, b, a = px[x, y]
            if a > 200 and b > r + 30:
                az[0].append(r)
                az[1].append(g)
                az[2].append(b)
    if not az[0]:
        raise SystemExit("no encuentro el azul del escudo")
    azul = (int(median(az[0])), int(median(az[1])), int(median(az[2])), 255)
    print("azul de relleno:", azul)

    # 1) copia del parche, 2) borrado, 3) pegado desplazado.
    parche = {(x, y): px[x, y] for y in range(h) for x in range(w) if mp[x, y]}
    for (x, y) in parche:
        px[x, y] = azul
    for (x, y), col in parche.items():
        nx = x + dx
        if 0 <= nx < w:
            px[nx, y] = col
    img.save(OUT, lossless=True)
    print("escrito", OUT)


if __name__ == "__main__":
    main()
