# -*- coding: utf-8 -*-
"""Compone la variante CON SOMBRERO DE PAJA de los retratos de Cai.

El sombrero de paja (coleccionable) se lo queda CAI (pedido por el usuario):
desde que la pieza cae, su arte 2D lo lleva puesto. La variante se genero con
`editImage` sobre cada retrato YA COMPUESTO y aplastado a blanco (subidos a la
rama tmp-rig), asi que el encuadre viene igualado de fabrica y aqui solo hay
que quitar el fondo e igualar el lienzo.

Lecciones de la tanda (31-8-2026):
- CADA MOOD SALIA CON UN SOMBRERO DISTINTO (el feliz estilo Luffy, el callado
  uno enorme dorado): la segunda pasada fue con el resultado del SERIO como
  `reference_image` pidiendo "el mismo sombrero de la referencia".
- La cuarta pasada del callado (hat4a) es la buena: la tercera sobrecorrigio
  el "sin sonrisa" a un ceño de enfado.
- Y LA REFERENCIA ARRASTRA LA CARA: `hablando` salio con ojos de susto y
  `callado` sonriendo. La tercera pasada blinda la expresion ("the FACE must
  stay IDENTICAL to the ORIGINAL image being edited").
- El fondo de editImage NO es blanco puro: trae ruido de papel (~240-250), asi
  que la inundacion va con umbral 232 y despues `fill` de las motas sueltas.
- La salida mide 480x640 y el retrato del juego 511x661 (proporciones 0.750 y
  0.773): se estira directo — un 3% en un dibujo plano no se ve, y respetar la
  proporcion habria descolgado la cara respecto al resto de moods.

    python tools/cai_sombrero.py
"""
import os
import sys
from collections import deque

from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEN = os.path.join(RAIZ, "_gen", "cai_hat")
OUT = os.path.join(RAIZ, "assets", "characters", "cai")

## mood -> archivo generado (la pasada buena de cada uno).
# La tanda "np_" es la BUENA: sin el pañuelo azul (pedido por el usuario —
# "quita a Cai su pañuelo original al ponerle el sombrero de Luffy"), con el
# pelo suelto y el mismo sombrero en los cinco. El sorprendido pidió una
# repetición extra (np2b): el primero salió despavorido y una variante llegó
# ¡sin sombrero y con corte militar!
FUENTES = {
    "serio": "np_serio_a.webp",
    "feliz": "np_feliz.webp",
    "sorprendido": "np2b_sorprendido.webp",
    "hablando": "np_hablando.webp",
    "callado": "np_callado.webp",
}
UMBRAL = 232


def quitar_fondo(im: Image.Image) -> Image.Image:
    """Inundacion desde los bordes: solo se borra el blanco CONECTADO al
    exterior, asi que los blancos interiores (la camisa) sobreviven."""
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
    base = Image.open(os.path.join(OUT, "cai_serio.png"))
    destino = base.size
    for mood, archivo in FUENTES.items():
        ruta = os.path.join(GEN, archivo)
        if not os.path.isfile(ruta):
            print("FALTA", archivo)
            continue
        im = quitar_fondo(Image.open(ruta))
        im = im.resize(destino, Image.LANCZOS)
        salida = os.path.join(OUT, "cai_%s_sombrero.png" % mood)
        im.save(salida)
        print("cai_%s_sombrero  %dx%d" % (mood, destino[0], destino[1]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
