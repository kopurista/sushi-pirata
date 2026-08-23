#!/usr/bin/env python3
"""Compone los retratos de MIKU y NACH (mar 2) para la caja de dialogo.

El mismo patron que kappa_portraits: inundacion de fondo desde los cuatro
bordes, UNA escala y UN recorte por personaje (sacados de su `serio` y de la
UNION de las cajas de todas las expresiones), y encuadre DE CINTURA PARA
ARRIBA (ALTO_SUJETO > 1) porque vienen de cuerpo entero y a cuerpo entero la
cara se queda en ~80 px contra los ~135 del reparto.

Uso:  python tools/m2_portraits.py
"""

from collections import deque
from pathlib import Path

from PIL import Image

PERSONAJES = {
    "miku": {
        "origen": Path("_gen/miku"),
        "destino": Path("assets/characters/miku"),
        "moods": {
            "serio": "base_a.webp",
            "hablando": "hablando.webp",
            "feliz": "feliz.webp",
            "sorprendido": "sorprendido.webp",
        },
    },
    "nach": {
        "origen": Path("_gen/nach"),
        "destino": Path("assets/characters/nach"),
        "moods": {
            "serio": "base_b.webp",
            "hablando": "hablando.webp",
            "riendo": "riendo.webp",
            "sorprendido": "sorprendido.webp",
        },
    },
}

CANVAS = (544, 704)
ALTO_SUJETO = 1.32
AIRE = 26
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


def componer(nombre: str, cfg: dict) -> None:
    cfg["destino"].mkdir(parents=True, exist_ok=True)
    limpias = {m: quitar_fondo(Image.open(cfg["origen"] / a))
               for m, a in cfg["moods"].items()}
    caja_serio = bbox_alfa(limpias["serio"])
    caja = list(caja_serio)
    for im in limpias.values():
        b = bbox_alfa(im)
        caja = [min(caja[0], b[0]), min(caja[1], b[1]),
                max(caja[2], b[2]), max(caja[3], b[3])]
    caja = tuple(caja)
    escala = CANVAS[1] * ALTO_SUJETO / (caja_serio[3] - caja_serio[1])
    for mood in cfg["moods"]:
        im = limpias[mood].crop(caja)
        im = im.resize((round(im.width * escala), round(im.height * escala)),
                       Image.LANCZOS)
        lienzo = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
        y = AIRE if im.height > CANVAS[1] else CANVAS[1] - im.height
        lienzo.paste(im, ((CANVAS[0] - im.width) // 2, y), im)
        lienzo.save(cfg["destino"] / ("%s_%s.png" % (nombre, mood)))
        print("%s_%s %dx%d" % (nombre, mood, im.width, im.height))


def main() -> None:
    for nombre, cfg in PERSONAJES.items():
        componer(nombre, cfg)


if __name__ == "__main__":
    main()
