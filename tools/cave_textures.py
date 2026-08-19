# -*- coding: utf-8 -*-
"""Texturas de la CUEVA DEL KAPPA, dibujadas por codigo (no por Ludo).

Lo que se pide de ellas es justo lo contrario de un dibujo con caracter:
tienen que ser SENCILLAS y GRANDES. Cualquier rasgo reconocible —una grieta,
una mancha oscura— se convierte en un motivo que el ojo persigue por el suelo
y delata el tileado; con ruido de poco contraste y sin hitos, la misma textura
repetida cinco veces en pantalla se lee como piedra y ya esta.

SEAMLESS POR CONSTRUCCION: el ruido se genera en una rejilla pequena, se
TILEA 3x3, se amplia con bicubica y se recorta el centro. Asi la interpolacion
de los bordes ya ha visto a sus vecinos y el corte cierra solo. (El espejado
2x2 que se probo antes crea una celosia periodica que se lee como rejilla.)

    python tools/cave_textures.py
"""
import random
from PIL import Image

SIZE = 512


def octava(n, semilla):
    """Ruido de valor periodico: rejilla n x n ampliada a SIZE con bicubica."""
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
    """capas = [(n, peso, semilla)] -> lista de floats 0..1."""
    total = sum(c[1] for c in capas)
    acc = [0.0] * (SIZE * SIZE)
    for n, peso, semilla in capas:
        datos = octava(n, semilla)
        for i, v in enumerate(datos):
            acc[i] += v * peso
    return [v / (255.0 * total) for v in acc]


def guarda(pixels, ruta):
    img = Image.new("RGB", (SIZE, SIZE))
    img.putdata(pixels)
    img.save(ruta, "WEBP", quality=94, method=6)
    print(ruta)


def suelo():
    """Piedra de suelo: moteado suave, sin un solo hito que seguir."""
    n = mezcla([(8, 0.34, 11), (16, 0.30, 12), (32, 0.22, 13), (64, 0.14, 14)])
    base = (150, 156, 170)
    px = []
    for v in n:
        # Poco contraste a proposito: 0.78 .. 1.12 del color base.
        k = 0.78 + v * 0.34
        px.append(tuple(min(255, int(c * k)) for c in base))
    guarda(px, "assets/props/piedra_cueva.webp")


def pared():
    """Piedra de pared: ESTRATOS horizontales, que es lo que dice 'roca viva'.

    Las bandas van por FILAS de la imagen porque el triplanar mapea la V de la
    textura sobre la Y del mundo en las caras verticales: filas -> capas
    horizontales. La onda se ondula con el propio ruido para que las capas no
    salgan rectas como un pentagrama.
    """
    import math
    n = mezcla([(8, 0.30, 21), (16, 0.28, 22), (32, 0.24, 23), (64, 0.18, 24)])
    onda = mezcla([(4, 0.6, 31), (8, 0.4, 32)])
    base = (138, 145, 162)
    px = []
    for i, v in enumerate(n):
        y = i // SIZE
        # 4 capas por baldosa, con la fase corrida por el ruido grande.
        fase = (y / float(SIZE)) * 4.0 + (onda[i] - 0.5) * 0.55
        onda_s = 0.5 + 0.5 * math.sin(fase * 2.0 * math.pi)
        # Curva dura: la capa es plana y el CANTO entre capas oscurece.
        estrato = onda_s * onda_s * (3.0 - 2.0 * onda_s)
        k = 0.70 + (v * 0.45 + estrato * 0.55) * 0.52
        px.append(tuple(min(255, int(c * k)) for c in base))
    guarda(px, "assets/props/pared_cueva.webp")


if __name__ == "__main__":
    suelo()
    pared()
