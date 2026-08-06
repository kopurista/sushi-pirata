#!/usr/bin/env python3
"""Quita el HALO BLANCO que dejan los retratos mal recortados.

Los retratos de Saverio vinieron del `removeBackground` de Ludo con un recorte
DURO (ni un pixel de alfa intermedio) y con restos del fondo blanco pegados por
fuera del contorno dibujado: un anillo claro alrededor del pelo, que es donde
mas se nota porque el pelo tiene mil entrantes.

Como los quita sin comerse los blancos de verdad: solo toca pixeles que sean
casi blancos Y esten a menos de RADIO del vacio. El anillo cumple las dos cosas
—es fondo que sobrevivio pegado al borde—, mientras que los dientes o la camisa
estan MUY dentro de la figura y no se rozan. Ademas, entre el anillo y la cara
siempre hay una linea de contorno oscura, que corta el avance.

Al terminar SUAVIZA el borde (alfa a medias en el primer pixel), porque el
recorte venia a cuchillo y en pantalla se veia dentado.

Uso:  python tools/portrait_fix.py assets/characters/saverio
      python tools/portrait_fix.py <carpeta> --check
"""

import sys
from collections import deque
from pathlib import Path

from PIL import Image

## Hasta donde puede llegar el halo desde el vacio, en pixeles.
RADIO = 7
## Que se considera "resto de fondo": muy claro y sin color.
WHITE_MIN = 208
WHITE_SPREAD = 34
## Por debajo de esto un pixel cuenta como vacio.
EMPTY_A = 8


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    check = "--check" in sys.argv
    if not args:
        print(__doc__)
        return 1
    target = Path(args[0])
    files = sorted(target.glob("*.png")) if target.is_dir() else [target]
    for path in files:
        im = Image.open(path).convert("RGBA")
        w, h = im.size
        px = im.load()

        # Distancia al vacio, por anchura (BFS) y solo hasta RADIO: mas lejos
        # ya no puede haber halo y no hace falta calcularlo.
        dist = [-1] * (w * h)
        q = deque()
        for y in range(h):
            for x in range(w):
                if px[x, y][3] < EMPTY_A:
                    dist[y * w + x] = 0
                    q.append((x, y))
        while q:
            x, y = q.popleft()
            d = dist[y * w + x]
            if d >= RADIO:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h and dist[yy * w + xx] < 0:
                    dist[yy * w + xx] = d + 1
                    q.append((xx, yy))

        quitados = 0
        for y in range(h):
            for x in range(w):
                d = dist[y * w + x]
                if d <= 0 or d > RADIO:
                    continue
                r, g, b, a = px[x, y]
                if a < EMPTY_A:
                    continue
                if min(r, g, b) >= WHITE_MIN and (max(r, g, b) - min(r, g, b)) <= WHITE_SPREAD:
                    px[x, y] = (r, g, b, 0)
                    quitados += 1

        print("%-34s halo quitado: %d px" % (path.name, quitados))
        if check or quitados == 0:
            continue

        # Borde suave: el pixel que ahora linda con el vacio se queda a medias,
        # que es lo que le faltaba a este recorte para no verse dentado.
        borde = []
        for y in range(1, h - 1):
            for x in range(1, w - 1):
                if px[x, y][3] < 250:
                    continue
                if min(px[x + dx, y + dy][3]
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) < EMPTY_A:
                    borde.append((x, y))
        for x, y in borde:
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 150)
        im.save(path)
        print("   borde suavizado en %d px" % len(borde))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
