#!/usr/bin/env python3
"""Hornea el JIRON DE NIEBLA del mapa (assets/map/niebla.webp).

Es un manchon blanco con alfa: opaco por dentro y deshilachado por el borde.
Se dibuja como cartel (billboard) alrededor de la cueva del Kappa, varias
copias a tamaños y velocidades distintas.

POR QUE HORNEADO Y NO POR SHADER: la niebla no cambia de dibujo, solo se
mueve; calcular ruido por pixel a pantalla completa para algo que se puede
resolver con una textura de 256 px seria pagar el fotograma por nada (misma
razon por la que la espuma del mar esta horneada, ver tools/foam_ww.py).

EL BORDE TIENE QUE MORIR A CERO EN EL CANTO del cuadrado: si el alfa llega
vivo al borde, el cartel se ve como lo que es —un rectangulo— y se acabo el
misterio. De ahi la mascara radial ademas del ruido.

Uso:  python tools/niebla_tex.py
"""

import math
import random
from pathlib import Path

from PIL import Image, ImageFilter

SALIDA = Path("assets/map/niebla.webp")
LADO = 256
## Rejilla del ruido de valor. Poca: la niebla es de grano MUY grande, y con
## una rejilla fina sale espuma de bano en vez de bruma.
REJILLA = 6
## Octavas del fbm. Tres bastan para que el borde no sea un circulo perfecto.
OCTAVAS = 3
## Cuanto deforma el ruido a la mascara radial (0 = disco limpio).
FUERZA = 0.55
SEMILLA = 20260820


def _ruido(rej, semilla):
    r = random.Random(semilla)
    return [[r.random() for _ in range(rej + 1)] for _ in range(rej + 1)]


def _muestra(g, rej, x, y):
    """Valor bilineal suavizado (smoothstep) de la rejilla en (x, y) 0..1."""
    fx, fy = x * rej, y * rej
    x0, y0 = int(fx), int(fy)
    x1, y1 = min(x0 + 1, rej), min(y0 + 1, rej)
    tx, ty = fx - x0, fy - y0
    tx = tx * tx * (3 - 2 * tx)
    ty = ty * ty * (3 - 2 * ty)
    a = g[y0][x0] * (1 - tx) + g[y0][x1] * tx
    b = g[y1][x0] * (1 - tx) + g[y1][x1] * tx
    return a * (1 - ty) + b * ty


def main() -> None:
    capas = [(_ruido(REJILLA * (2 ** i), SEMILLA + i), REJILLA * (2 ** i),
              0.5 ** i) for i in range(OCTAVAS)]
    peso = sum(c[2] for c in capas)
    img = Image.new("RGBA", (LADO, LADO), (255, 255, 255, 0))
    px = img.load()
    for j in range(LADO):
        for i in range(LADO):
            u = (i + 0.5) / LADO
            v = (j + 0.5) / LADO
            # Mascara radial: 1 en el centro, 0 en el canto.
            d = math.hypot(u - 0.5, v - 0.5) * 2.0
            base = max(0.0, 1.0 - d)
            base = base * base * (3 - 2 * base)
            n = sum(_muestra(g, rej, u, v) * w for g, rej, w in capas) / peso
            a = base * (1.0 - FUERZA + FUERZA * n * 1.6)
            px[i, j] = (255, 255, 255, max(0, min(255, int(a * 255))))
    # Un desenfoque corto remata los escalones del ruido de rejilla.
    img = img.filter(ImageFilter.GaussianBlur(2.2))
    # Y el canto se fuerza a cero, por si el desenfoque ha arrastrado alfa.
    px = img.load()
    for j in range(LADO):
        for i in range(LADO):
            u = (i + 0.5) / LADO
            v = (j + 0.5) / LADO
            d = math.hypot(u - 0.5, v - 0.5) * 2.0
            if d >= 0.98:
                r, g, b, _ = px[i, j]
                px[i, j] = (r, g, b, 0)
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    img.save(SALIDA, "WEBP", lossless=True)
    alfa = img.split()[3]
    print("%s %dx%d  alfa medio %.1f  max %d"
          % (SALIDA, LADO, LADO, sum(alfa.getdata()) / (LADO * LADO),
             max(alfa.getdata())))


if __name__ == "__main__":
    main()
