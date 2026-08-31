# -*- coding: utf-8 -*-
"""Compone las VARIANTES por coleccionable de los retratos de David y Gigi.

El PAÑUELO pirata lo estrena David y el TRICORNIO se lo queda Gigi (pedidos
por el usuario): desde que cada pieza cae, el arte de la caja de diálogo lo
lleva puesto (`DialogueBox._variante_de`, con caída al arte base). Cuatro
estados y cuatro juegos de arte:

  - base (sin nada)        -> david_<mood>.png            (serie A)
  - solo pañuelo           -> david_<mood>_panuelo.png    (serie B)
  - solo tricornio         -> david_<mood>_tricornio.png  (el arte ANTERIOR,
                              ya copiado tal cual: Gigi nació con tricornio)
  - pañuelo + tricornio    -> david_<mood>_panuelo_tricornio.png (serie C)

Las series se generaron con `editImage` sobre cada retrato YA COMPUESTO y
aplastado a blanco (subidos a tmp-rig), así que el encuadre viene igualado de
fábrica: aquí solo se quita el fondo por inundación (umbral 232, que el fondo
de editImage trae ruido de papel) y se estira al lienzo del retrato vigente.
La serie A (quitar el tricornio de Gigi) REEMPLAZA al arte base: el estado
"sin coleccionables" es el nuevo punto de partida.

    python tools/david_variantes.py
"""
import os
import sys
from collections import deque

from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEN = os.path.join(RAIZ, "_gen", "david_var")
OUT = os.path.join(RAIZ, "assets", "characters", "david")

MOODS = ["serio", "hablando", "feliz", "riendo", "sorprendido", "gritando",
    "triste", "mira_loro", "loro", "loro_sorpresa", "loro_grito",
    "loro_resignado"]
## serie -> (prefijo de archivo generado, sufijo del png del juego; "" = base)
SERIES = {"a": "", "b": "_panuelo", "c": "_panuelo_tricornio"}
## Tomas que salieron con nombre propio (repeticiones elegidas a mano).
FUENTES_ESPECIALES = {("b", "serio"): "b_serio_a.webp"}
UMBRAL = 232


def quitar_fondo(im: Image.Image) -> Image.Image:
    """Inundación desde los bordes: los blancos interiores (las rayas de la
    camiseta) están cercados por la línea de entintado y sobreviven."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    visto = bytearray(w * h)
    cola = deque()
    for x in range(w):
        cola.append((x, 0))
        cola.append((x, h - 1))
    for y in range(h):
        cola.append((0, y))
        cola.append((w - 1, y))
    while cola:
        x, y = cola.popleft()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        i = y * w + x
        if visto[i]:
            continue
        visto[i] = 1
        r, g, b, a = px[x, y]
        if r < UMBRAL or g < UMBRAL or b < UMBRAL:
            continue
        px[x, y] = (r, g, b, 0)
        cola.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return im


def main() -> int:
    destino = Image.open(os.path.join(OUT, "david_serio.png")).size
    fallos = 0
    for serie, sufijo in SERIES.items():
        for mood in MOODS:
            archivo = FUENTES_ESPECIALES.get((serie, mood),
                "%s_%s.webp" % (serie, mood))
            ruta = os.path.join(GEN, archivo)
            if not os.path.isfile(ruta):
                print("FALTA", archivo)
                fallos += 1
                continue
            im = quitar_fondo(Image.open(ruta))
            im = im.resize(destino, Image.LANCZOS)
            salida = os.path.join(OUT, "david_%s%s.png" % (mood, sufijo))
            im.save(salida)
            print("david_%s%s" % (mood, sufijo))
    return 1 if fallos else 0


if __name__ == "__main__":
    sys.exit(main())
