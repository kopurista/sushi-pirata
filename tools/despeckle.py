"""Quita las MOTAS de alfa que deja el recorte de fondo en un sprite.

La inundacion desde los bordes (icon_prep / stage_prep / ui2_prep) deja a veces
pixeles sueltos casi blancos flotando alrededor del sujeto: sobrevivieron
porque quedaron AISLADOS, sin camino de pixeles claros hasta el borde. Se ven
como un reguero de puntitos —el arroz del maki de aguacate tenia 54 de ellos
en un arco sobre el rollo— y cantan sobre cualquier fondo oscuro.

    python tools/despeckle.py --check assets/dishes/*.webp   # solo audita
    python tools/despeckle.py assets/dishes/maki_aguacate.webp

CUIDADO al pasarlo en lote: muchos sprites tienen piezas sueltas A PROPOSITO
(el vapor del te verde, la harina de la gamba enharinada, los remolinos de los
iconos de potenciador). Por eso el corte es DOBLE y muy conservador —isla de
menos de MAX_PX pixeles Y menos de MAX_FRAC del sujeto— y por eso conviene
mirar primero con --check que lo que se va a tirar es de verdad polvo.
"""

import sys
from collections import deque
from pathlib import Path

from PIL import Image

## Alfa a partir del cual un pixel cuenta como sujeto (el mismo umbral alto
## del resto de herramientas: por debajo entra el antialias).
ALPHA = 160
## Una mota es una isla que cumple LAS DOS: pocos pixeles en absoluto y una
## fraccion insignificante del sujeto.
MAX_PX = 60
MAX_FRAC = 0.0002


def _islands(img):
    """[(tam, [pixeles])] de cada isla de alfa >= ALPHA."""
    w, h = img.size
    a = img.split()[3].load()
    seen = bytearray(w * h)
    out = []
    for sy in range(h):
        for sx in range(w):
            if seen[sy * w + sx] or a[sx, sy] < ALPHA:
                continue
            q = deque([(sx, sy)])
            seen[sy * w + sx] = 1
            px = []
            while q:
                x, y = q.popleft()
                px.append((x, y))
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] \
                            and a[nx, ny] >= ALPHA:
                        seen[ny * w + nx] = 1
                        q.append((nx, ny))
            out.append((len(px), px))
    return out


def clean(path: Path, check: bool) -> None:
    img = Image.open(path).convert("RGBA")
    isl = _islands(img)
    if not isl:
        return
    mayor = max(n for n, _ in isl)
    motas = [(n, px) for n, px in isl
             if n <= MAX_PX and n < mayor * MAX_FRAC]
    if not motas:
        print("%-34s limpio (%d islas)" % (path.name, len(isl)))
        return
    total = sum(n for n, _ in motas)
    print("%-34s %d motas, %d px (isla mayor %d)%s"
          % (path.name, len(motas), total, mayor, "  [--check]" if check else ""))
    if check:
        return
    # El alfa de la mota se borra ENTERO, incluido su halo de antialias: si se
    # deja, queda un fantasma gris igual de visible sobre fondo oscuro.
    a = img.split()[3].load()
    quita = img.load()
    w, h = img.size
    for _, px in motas:
        for x, y in px:
            for dx in range(-2, 3):
                for dy in range(-2, 3):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and a[nx, ny] < ALPHA:
                        quita[nx, ny] = (0, 0, 0, 0)
            quita[x, y] = (0, 0, 0, 0)
    if path.suffix == ".webp":
        # Calidad alta: el .import ya vuelve a comprimir con perdida, asi que
        # aqui solo interesa no encadenar una segunda degradacion.
        img.save(path, quality=95, method=6)
    else:
        img.save(path)


if __name__ == "__main__":
    args = sys.argv[1:]
    check = "--check" in args
    files = [Path(a) for a in args if not a.startswith("--")]
    if not files:
        print(__doc__)
        sys.exit(1)
    for f in files:
        clean(f, check)
