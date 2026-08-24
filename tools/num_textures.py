"""Texturas para los NUMEROS del mapa de aventura.

El numero de cada escenario va incrustado en su decorado (arena de la isla,
vela del barco), y con color plano se leia como un rotulo pegado encima. Estas
dos texturas —grano de arena y trama de lona— se le ponen a la geometria del
numero (`TextMesh`) con mapeo triplanar, asi que el relieve comparte material
con aquello en lo que esta tallado.

Van DIBUJADAS por codigo y no generadas, por lo mismo que las de la cueva: son
tramas SENCILLAS y de poco contraste a proposito —cualquier rasgo reconocible
se convierte en el motivo que delata el tileado— y salen seamless por
construccion (rejilla pequeña tileada 3x3, ampliada con bicubica y recortado el
centro).
"""
import math
import random
from pathlib import Path

from PIL import Image

OUT = Path("assets/props")
RAIZ_PROPS = Path("assets/props")
LADO = 256
## Rejilla de ruido base. Pequeña: lo que se busca es grano, no dibujo.
CELDA = 16


def _ruido(semilla: int, celda: int) -> Image.Image:
    """Ruido de valor PERIODICO: la rejilla se tilea 3x3 antes de ampliar, asi
    que los bordes empalman solos."""
    rnd = random.Random(semilla)
    base = Image.new("L", (celda, celda))
    px = base.load()
    for y in range(celda):
        for x in range(celda):
            px[x, y] = rnd.randrange(256)
    grande = Image.new("L", (celda * 3, celda * 3))
    for j in range(3):
        for i in range(3):
            grande.paste(base, (i * celda, j * celda))
    grande = grande.resize((LADO * 3, LADO * 3), Image.BICUBIC)
    return grande.crop((LADO, LADO, LADO * 2, LADO * 2))


def arena() -> None:
    """Grano de arena: dos octavas de ruido suave sobre crema calido."""
    a = _ruido(11, CELDA)
    b = _ruido(23, CELDA * 3)
    im = Image.new("RGB", (LADO, LADO))
    pa, pb, pi = a.load(), b.load(), im.load()
    for y in range(LADO):
        for x in range(LADO):
            v = (pa[x, y] * 0.62 + pb[x, y] * 0.38) / 255.0
            # Poco contraste: de 0.86 a 1.0 del color base.
            k = 0.86 + v * 0.14
            pi[x, y] = (int(238 * k), int(206 * k), int(150 * k))
    im.save(OUT / "arena_num.webp", quality=92)
    print("arena_num.webp", im.size)


def lona() -> None:
    """Trama de lona: hilos finos cruzados, con el ruido rompiendo la
    regularidad para que no se lea como una rejilla."""
    n = _ruido(37, CELDA * 2)
    im = Image.new("RGB", (LADO, LADO))
    pn, pi = n.load(), im.load()
    for y in range(LADO):
        for x in range(LADO):
            # Dos senos cruzados a periodo entero del lado: seamless exacto.
            trama = (math.sin(x * math.tau * 16.0 / LADO)
                     + math.sin(y * math.tau * 16.0 / LADO)) * 0.25 + 0.5
            v = trama * 0.55 + (pn[x, y] / 255.0) * 0.45
            k = 0.84 + v * 0.16
            pi[x, y] = (int(232 * k), int(222 * k), int(198 * k))
    im.save(OUT / "lona_num.webp", quality=92)
    print("lona_num.webp", im.size)


def cartel() -> None:
    """MADERA DEL CARTEL DEL NIVEL: la del muelle, aplanada a medio camino.

    Con la veta entera el cartel se leia como una mancha rayada y la cifra se
    perdia; con un color liso quedaba de plastico. Se mezcla la textura con su
    propio color medio, asi que queda vetа pero suave: se ve que es madera y no
    compite con el numero.
    """
    im = Image.open(RAIZ_PROPS / "madera_muelle.webp").convert("RGB")
    px = im.load()
    n = im.width * im.height
    ac = [0, 0, 0]
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            for i in range(3):
                ac[i] += c[i]
    medio = [v / n for v in ac]
    # 0 = textura entera, 1 = color liso. A la mitad la veta se intuye.
    K = 0.55
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            px[x, y] = tuple(int(c[i] * (1.0 - K) + medio[i] * K)
                             for i in range(3))
    im.save(OUT / "madera_cartel.webp", quality=92)
    print("madera_cartel.webp", im.size)


if __name__ == "__main__":
    arena()
    lona()
    cartel()
