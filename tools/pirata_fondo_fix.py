# -*- coding: utf-8 -*-
"""Quita el FONDO BLANCO que quedó ENCERRADO tras el pañuelo del pirata.

Los retratos se recortan por INUNDACIÓN desde los bordes (ver el bloque de
personajes 2D en CLAUDE.md), y esa inundación no llega a los huecos que el
propio dibujo encierra: entre la cola del pañuelo y la mejilla quedaba una
cuña de blanco OPACO que sobre el velo del diálogo se veía como un parche.

VA POR SEMILLA Y NO POR COLOR (la lección del `drop_specks` y las bolsas de
Alice): en el mismo retrato hay blancos que SÍ son arte — la hebilla del
cinturón mide 295 px y es casi igual de blanca que el hueco (243,245,246
contra 253,253,253), así que ningún umbral los separa. Se inunda desde el
punto medido del hueco y se para donde deja de ser casi blanco.

    python tools/pirata_fondo_fix.py
"""

from collections import deque
from pathlib import Path

from PIL import Image

CARPETA = Path("assets/characters/pirata")
## Punto MEDIDO dentro del hueco del pañuelo (el mismo en las cuatro
## expresiones: se derivan del mismo retrato, así que no se mueve).
SEMILLA = (176, 353)
## Por debajo de esto ya no es el hueco: es la tinta que lo rodea.
CASI_BLANCO = 232


def limpiar(ruta: Path) -> int:
    im = Image.open(ruta).convert("RGBA")
    w, h = im.size
    px = im.load()
    r, g, b, a = px[SEMILLA]
    if a == 0 or min(r, g, b) < CASI_BLANCO:
        print("%-24s ya estaba limpio" % ruta.name)
        return 0
    cola = deque([SEMILLA])
    vistos = {SEMILLA}
    while cola:
        x, y = cola.popleft()
        px[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if not (0 <= nx < w and 0 <= ny < h) or (nx, ny) in vistos:
                continue
            rr, gg, bb, aa = px[nx, ny]
            if aa > 0 and min(rr, gg, bb) >= CASI_BLANCO:
                vistos.add((nx, ny))
                cola.append((nx, ny))
    im.save(ruta)
    print("%-24s %d px de fondo fuera" % (ruta.name, len(vistos)))
    return len(vistos)


def main() -> None:
    for f in sorted(CARPETA.glob("pirata_*.png")):
        limpiar(f)


if __name__ == "__main__":
    main()
