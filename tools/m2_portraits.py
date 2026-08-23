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
    # LA SIRENA (la jefa del mar 2): seis moods — "cantando" es el suyo propio,
    # con los ojos cerrados y las notas flotando, y sale cada vez que canta.
    # Su concepto ya viene DE CINTURA PARA ARRIBA, asi que el 1.32 pensado
    # para cuerpos enteros la dejaba en primerisimo plano: escala propia.
    "sirena": {
        "alto": 0.80,
        "bolsas": True,
        "origen": Path("_gen/sirena"),
        "destino": Path("assets/characters/sirena"),
        "moods": {
            "serio": "serio.webp",
            "hablando": "hablando.webp",
            "cantando": "cantando.webp",
            "enfadado": "enfadado.webp",
            "feliz": "feliz.webp",
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


def quitar_bolsas(im: Image.Image) -> Image.Image:
    """Transparenta el blanco ENCERRADO entre mechones (la sirena).

    La inundacion desde los bordes no llega a las bolsas de fondo que el pelo
    encierra, y sobre el velo oscuro del dialogo salian como rayas blancas.
    Se borran solo las islas casi blancas cuyo CENTROIDE cae FUERA de la caja
    central de la cara: la esclerotica de los ojos y los dientes viven ahi
    dentro y no se tocan (medido: ojos en x 0.41-0.58, y 0.35 del lienzo)."""
    w, h = im.size
    px = im.load()
    vist = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if vist[y][x]:
                continue
            r, g, b, a = px[x, y]
            if a == 0 or min(r, g, b) < BLANCO_MIN:
                continue
            cola = deque([(x, y)])
            vist[y][x] = True
            isla = [(x, y)]
            cx = cy = 0
            while cola:
                ax, ay = cola.popleft()
                cx += ax
                cy += ay
                for nx, ny in ((ax - 1, ay), (ax + 1, ay),
                               (ax, ay - 1), (ax, ay + 1)):
                    if 0 <= nx < w and 0 <= ny < h and not vist[ny][nx]:
                        rr, gg, bb, aa = px[nx, ny]
                        if aa > 0 and min(rr, gg, bb) >= BLANCO_MIN:
                            vist[ny][nx] = True
                            cola.append((nx, ny))
                            isla.append((nx, ny))
            n = len(isla)
            fx, fy = cx / n / w, cy / n / h
            if 0.33 <= fx <= 0.67 and 0.20 <= fy <= 0.62:
                continue  # cara: ojos y dientes se quedan
            for ax, ay in isla:
                px[ax, ay] = (0, 0, 0, 0)
    return im


def bbox_alfa(im: Image.Image):
    return im.split()[3].point(lambda a: 255 if a >= 40 else 0).getbbox()


def componer(nombre: str, cfg: dict) -> None:
    cfg["destino"].mkdir(parents=True, exist_ok=True)
    limpias = {m: quitar_fondo(Image.open(cfg["origen"] / a))
               for m, a in cfg["moods"].items()}
    if cfg.get("bolsas", False):
        limpias = {m: quitar_bolsas(im) for m, im in limpias.items()}
    caja_serio = bbox_alfa(limpias["serio"])
    caja = list(caja_serio)
    for im in limpias.values():
        b = bbox_alfa(im)
        caja = [min(caja[0], b[0]), min(caja[1], b[1]),
                max(caja[2], b[2]), max(caja[3], b[3])]
    caja = tuple(caja)
    escala = CANVAS[1] * cfg.get("alto", ALTO_SUJETO)         / (caja_serio[3] - caja_serio[1])
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
    import sys
    pedidos = sys.argv[1:]
    for nombre, cfg in PERSONAJES.items():
        if pedidos and nombre not in pedidos:
            continue
        componer(nombre, cfg)


if __name__ == "__main__":
    main()
