#!/usr/bin/env python3
"""Compone los RETRATOS DEL KAPPA para la caja de dialogo (544x704 RGBA).

El Kappa viene de cuerpo entero y con aire por los cuatro lados, asi que la
inundacion de fondo entra por los CUATRO bordes (a Alice, cortada por la
cintura, habia que respetarle el de abajo). Su vientre crema y el plato del
craneo sobreviven: los encierra la linea de entintado.

Y UNA SOLA ESCALA Y UN SOLO RECORTE PARA TODAS LAS EXPRESIONES, sacados de
`serio`: vienen alineadas pixel a pixel desde la misma base, asi que cambiar
de mood no puede mover la cabeza.

Uso:  python tools/kappa_portraits.py
"""

from collections import deque
from pathlib import Path

from PIL import Image

ORIGEN = Path("_gen/kappa")
DESTINO = Path("assets/characters/kappa")

## mood -> archivo de la tanda
ELEGIDAS = {
    "serio": "base_k.webp",
    "hablando": "hablando.webp",
    "enfadado": "enfadado.webp",
    "feliz": "feliz.webp",
    "dormido": "dormido.webp",
    # La escalada de ira de las fases del duelo: enfadado < furioso < colerico.
    "furioso": "furioso.webp",
    "colerico": "colerico.webp",
}

CANVAS = (544, 704)
## Fraccion del alto que ocupa el sujeto. MAYOR QUE 1 a proposito: el kappa es
## larguirucho y a cuerpo entero su cara median ~80 px contra los ~135 del
## reparto — en la caja se veia lejisimos. A 1.30 se compone DE CINTURA PARA
## ARRIBA (las piernas se recortan por debajo del lienzo) y la cara queda en
## la talla de los demas.
ALTO_SUJETO = 1.30
## Aire sobre la cabeza cuando el sujeto es mas alto que el lienzo.
AIRE = 26
## Que cuenta como fondo al inundar.
BLANCO_MIN = 232


def quitar_fondo(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    fondo = [[False] * w for _ in range(h)]
    cola = deque()

    def sembrar(x, y):
        r, g, b, _ = px[x, y]
        if min(r, g, b) >= BLANCO_MIN and not fondo[y][x]:
            fondo[y][x] = True
            cola.append((x, y))

    for x in range(w):
        sembrar(x, 0)
        sembrar(x, h - 1)
    for y in range(h):
        sembrar(0, y)
        sembrar(w - 1, y)
    while cola:
        x, y = cola.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h and not fondo[ny][nx]:
                r, g, b, _ = px[nx, ny]
                if min(r, g, b) >= BLANCO_MIN:
                    fondo[ny][nx] = True
                    cola.append((nx, ny))
    for y in range(h):
        for x in range(w):
            if fondo[y][x]:
                px[x, y] = (0, 0, 0, 0)
    return im


def bbox_alfa(im: Image.Image):
    return im.split()[3].point(lambda a: 255 if a >= 40 else 0).getbbox()


def main() -> None:
    DESTINO.mkdir(parents=True, exist_ok=True)
    # LA ESCALA sale de `serio` (el alto del sujeto en reposo) y EL RECORTE de
    # la UNION de todas las expresiones: el vapor del furioso y del colerico se
    # sale del cuerpo del serio, y con su caja se cortaba a cuchillo. La caja
    # es LA MISMA para todas, que es lo que mantiene la cabeza clavada al
    # cambiar de mood.
    limpias = {m: quitar_fondo(Image.open(ORIGEN / a2)) for m, a2 in ELEGIDAS.items()}
    caja_serio = bbox_alfa(limpias["serio"])
    caja = list(caja_serio)
    for im in limpias.values():
        b2 = bbox_alfa(im)
        caja = [min(caja[0], b2[0]), min(caja[1], b2[1]),
                max(caja[2], b2[2]), max(caja[3], b2[3])]
    caja = tuple(caja)
    alto_sujeto = caja_serio[3] - caja_serio[1]
    escala = CANVAS[1] * ALTO_SUJETO / alto_sujeto
    for mood in ELEGIDAS:
        im = limpias[mood].crop(caja)
        im = im.resize((round(im.width * escala), round(im.height * escala)),
                       Image.LANCZOS)
        lienzo = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
        # Mas alto que el lienzo: se ancla ARRIBA con su aire y el resto se
        # recorta por abajo (el encuadre de cintura para arriba).
        y = AIRE if im.height > CANVAS[1] else CANVAS[1] - im.height
        lienzo.paste(im, ((CANVAS[0] - im.width) // 2, y), im)
        lienzo.save(DESTINO / f"kappa_{mood}.png")
        print(f"kappa_{mood:10s} {im.width}x{im.height}")


if __name__ == "__main__":
    main()
