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


## Franja de las MEJILLAS donde pueden caer las lagrimas, en pixeles del
## lienzo ya compuesto (544x704). Se acota a proposito: fuera de aqui hay
## blancos que NO son lagrimas (el ojo, el lirio, el delantal).
## DOS VENTANAS ESTRECHAS, una por lagrima, en pixeles del lienzo compuesto.
##
## No se puede usar una sola caja ancha: los OJOS llegan hasta y=310 y su
## esclerotica es tan palida como una lagrima, asi que una caja que los pise se
## los come — paso, y el puente horizontal los borro de un plumazo dejando una
## banda gris de lado a lado de la cara. Pero las lagrimas caen POR FUERA de
## los ojos (x 205..216 y x 305..322, medido fila a fila), asi que acotando la
## X se puede subir hasta el nacimiento del reguero sin tocarlos.
LAGRIMAS_CAJAS = [(203, 302, 218, 336), (304, 302, 323, 336)]
## Y una lagrima es FINA. Una racha mas ancha que esto no es una lagrima (es un
## ojo, un brillo, un diente): se deja en paz. Es la red de seguridad que
## faltaba cuando el puente se llevo los dos ojos por delante.
LAGRIMA_MAX_ANCHO = 8
## LA LAGRIMA SE DETECTA CONTRA SU PROPIA FILA, no contra un umbral fijo. La
## piel de Alice es rosa (r-b de 60 a 85), pero el reguero NO es blanco: segun
## baja por la mejilla se queda en r-b de 56 a 70, o sea a un pelo de la piel de
## al lado. Un corte fijo (se probo en 50) solo pillaba la punta y dejaba el
## reguero entero puesto. Lo que si lo separa es la DIFERENCIA con la mediana
## de piel de SU fila: la lagrima siempre baja de ella al menos esto.
LAGRIMA_CAIDA = 10
## Y solo se mira lo CLARO: asi la linea de pestanas, que es negra, queda fuera.
LAGRIMA_MIN = 150


def quitar_lagrimas(im: Image.Image) -> Image.Image:
    """Borra las lagrimas de la expresion `triste`.

    El generador las pinto DOS VECES pese a prohibirlas en el prompt, y el
    retrato base tiene que estar sereno: las lagrimas son una decision de
    guion, no el estado por defecto de la cara.

    Se detectan por COLOR y no por coordenadas: en la franja de las mejillas,
    la piel es rosa (r-b 60..85) y la lagrima es palida (r-b 0..47). Cada
    pixel de lagrima se repinta INTERPOLANDO de lado a lado en SU FILA, entre
    la piel sana de la izquierda y la de la derecha; la mejilla tiene un
    degradado vertical suave, asi que un puente horizontal de 3-4 px no se ve.
    (Promediar el entorno, en cambio, arrastraria el rubor.)
    """
    im = im.convert("RGBA")
    px = im.load()
    tocados = 0
    for x0, y0, x1, y1 in LAGRIMAS_CAJAS:
        for y in range(y0, y1):
            claros = []
            for x in range(x0, x1):
                r, g, b, a = px[x, y]
                if a > 200 and r > LAGRIMA_MIN:
                    claros.append((x, r - b))
            if len(claros) < 6:
                continue
            orden = sorted(v for _, v in claros)
            piel = orden[len(orden) // 2]
            fila = [x for x, v in claros if v <= piel - LAGRIMA_CAIDA]
            if not fila:
                continue
            # Rachas contiguas: cada una se puentea con la piel de sus lados.
            racha = [fila[0]]
            for x in fila[1:]:
                if x - racha[-1] <= 2:
                    racha.append(x)
                    continue
                tocados += _puente(px, racha, y, x0, x1)
                racha = [x]
            tocados += _puente(px, racha, y, x0, x1)
    print("  lagrimas: %d pixeles repintados" % tocados)
    return im


def _puente(px, racha, y, x0, x1) -> int:
    """Repinta una racha de lagrima interpolando entre la piel de sus lados."""
    izq = racha[0] - 1
    der = racha[-1] + 1
    if izq < x0 or der >= x1 or len(racha) > LAGRIMA_MAX_ANCHO:
        return 0
    ci = px[izq, y]
    cd = px[der, y]
    n = der - izq
    for k, x in enumerate(racha, start=1):
        t = k / float(n)
        px[x, y] = tuple(
            int(round(ci[i] * (1.0 - t) + cd[i] * t)) for i in range(4))
    return len(racha)


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
        if mood == "triste":
            hoja = quitar_lagrimas(hoja)
        salida = DESTINO / ("alice_%s.png" % mood)
        hoja.save(salida)
        print("  %-12s -> %s" % (mood, salida))


if __name__ == "__main__":
    main()
