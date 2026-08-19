#!/usr/bin/env python3
"""Compone los RETRATOS DE ALICE para la caja de dialogo (544x704 RGBA).

Quita el fondo por INUNDACION desde los bordes, como los clientes genericos:
sus blancos interiores —el delantal y el lirio— estan encerrados por la linea
de entintado, asi que sobreviven.

OJO CON EL BORDE DE ABAJO: el encuadre corta a Alice por la cintura, asi que
la fila inferior es SUJETO, no fondo. Inundar desde ahi se le mete dentro del
delantal y se lo come. Se inunda solo desde ARRIBA, IZQUIERDA y DERECHA
(medido: esos tres bordes son blanco puro al 100%).

Y UNA SOLA ESCALA Y UN SOLO RECORTE PARA TODAS LAS EXPRESIONES, sacados de
`serio`: vienen alineadas pixel a pixel desde la misma base, asi que cambiar de
mood no puede mover la cabeza. Calcular el recorte de cada una por separado la
haria saltar cada vez que abre la boca.

Uso:  python tools/alice_portraits.py
"""

from collections import deque
from pathlib import Path

from PIL import Image

ORIGEN = Path("_gen/alice")
DESTINO = Path("assets/characters/alice")

## mood -> archivo elegido de la tanda
ELEGIDAS = {
    "serio": "alice_base.png",
    "hablando": "hab_b.webp",
    "feliz": "fel_a.webp",
    "riendo": "rie_a.webp",
    "sorprendido": "sor_a.webp",
    "triste": "tri_a.webp",
    "callado": "cal_a.webp",
}

CANVAS = (544, 704)
## Fraccion del alto que ocupa el sujeto. La del reparto no es unica (David
## llena 0.97 y Pablo 0.79) porque depende de lo cerrado que venga el encuadre;
## lo que importa es que la CARA mida como las demas. Alice viene de cintura
## para arriba, como Pablo, asi que se compone con su misma fraccion.
ALTO_SUJETO = 0.79
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

    for x in range(w):          # arriba
        sembrar(x, 0)
    for y in range(h):          # los dos lados; ABAJO NO (ahi esta el sujeto)
        sembrar(0, y)
        sembrar(w - 1, y)

    while cola:
        x, y = cola.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not fondo[ny][nx]:
                r, g, b, _ = px[nx, ny]
                if min(r, g, b) >= BLANCO_MIN:
                    fondo[ny][nx] = True
                    cola.append((nx, ny))

    for y in range(h):
        for x in range(w):
            if fondo[y][x]:
                px[x, y] = (255, 255, 255, 0)

    # Suaviza el canto: el recorte sale a cuchillo y en pantalla se ve dentado.
    a = im.getchannel("A")
    ap = a.load()
    suave = a.copy()
    sp = suave.load()
    for y in range(h):
        for x in range(w):
            if ap[x, y] > 200:
                if any(0 <= x + dx < w and 0 <= y + dy < h and ap[x + dx, y + dy] == 0
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    sp[x, y] = 150
    im.putalpha(suave)
    return im


def main():
    DESTINO.mkdir(parents=True, exist_ok=True)
    # El recorte y la escala se deciden UNA vez, sobre `serio`.
    base = quitar_fondo(Image.open(ORIGEN / ELEGIDAS["serio"]))
    caja = base.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
    bw, bh = caja[2] - caja[0], caja[3] - caja[1]
    escala = min(CANVAS[1] * ALTO_SUJETO / bh, CANVAS[0] / bw)
    nw, nh = int(round(bw * escala)), int(round(bh * escala))
    print("bbox origen %s  ->  %dx%d en lienzo %dx%d (%.2f del alto)"
          % (caja, nw, nh, CANVAS[0], CANVAS[1], nh / CANVAS[1]))

    for mood, archivo in ELEGIDAS.items():
        im = base if archivo == ELEGIDAS["serio"] else quitar_fondo(
            Image.open(ORIGEN / archivo))
        recorte = im.crop(caja).resize((nw, nh), Image.LANCZOS)
        hoja = Image.new("RGBA", CANVAS, (255, 255, 255, 0))
        hoja.paste(recorte, ((CANVAS[0] - nw) // 2, CANVAS[1] - nh), recorte)
        salida = DESTINO / ("alice_%s.png" % mood)
        hoja.save(salida)
        print("  %-12s -> %s" % (mood, salida))


if __name__ == "__main__":
    main()
