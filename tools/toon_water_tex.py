# -*- coding: utf-8 -*-
"""Las dos texturas de ruido que pide el Toon Water Shader.

El shader (godotshaders.com/shader/toon-water-shader, port del de Erik Roystan
Ross) necesita `surfaceNoise` —el dibujo de la espuma— y `distortNoise` —el
ruido que ondula sus UV—. Se dibujan aqui con el mismo truco que las piedras de
la cueva: ruido de valor PERIODICO (rejilla pequena tileada 3x3, ampliada con
bicubica y recortado el centro), asi que cierran solos por los cuatro lados.

    python tools/toon_water_tex.py
"""
import random
from PIL import Image

SIZE = 512


def octava(n, semilla):
    rnd = random.Random(semilla)
    small = Image.new("L", (n, n))
    small.putdata([rnd.randint(0, 255) for _ in range(n * n)])
    big = Image.new("L", (n * 3, n * 3))
    for i in range(3):
        for j in range(3):
            big.paste(small, (i * n, j * n))
    big = big.resize((SIZE * 3, SIZE * 3), Image.BICUBIC)
    return list(big.crop((SIZE, SIZE, SIZE * 2, SIZE * 2)).getdata())


def mezcla(capas):
    total = sum(c[1] for c in capas)
    acc = [0.0] * (SIZE * SIZE)
    for n, peso, semilla in capas:
        for i, v in enumerate(octava(n, semilla)):
            acc[i] += v * peso
    return [v / (255.0 * total) for v in acc]


def guarda(vals, ruta, curva=1.0):
    img = Image.new("RGB", (SIZE, SIZE))
    px = []
    for v in vals:
        c = int(min(1.0, max(0.0, v)) ** curva * 255.0 + 0.5)
        px.append((c, c, c))
    img.putdata(px)
    img.save(ruta, "WEBP", quality=95, method=6)
    print(ruta)


def superficie():
    """Espuma: manchas medianas con bastante contraste (el shader la corta con
    un umbral, asi que lo que importa es que haya blancos y negros claros)."""
    n = mezcla([(8, 0.45, 101), (16, 0.32, 102), (32, 0.23, 103)])
    # Estirar el histograma para que el umbral del shader tenga donde morder.
    lo = min(n)
    hi = max(n)
    n = [(v - lo) / max(hi - lo, 0.001) for v in n]
    guarda(n, "assets/map/ruido_espuma.webp", curva=0.85)


def distorsion():
    """Distorsion: ruido MAS GRANDE y suave; solo mueve las UV de la espuma."""
    n = mezcla([(4, 0.6, 201), (8, 0.4, 202)])
    guarda(n, "assets/map/ruido_distor.webp")


if __name__ == "__main__":
    superficie()
    distorsion()
