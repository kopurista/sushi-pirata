#!/usr/bin/env python3
"""Quita los LUNARES FRIOS pintados en la textura de un modelo de madera.

Por que hace falta: los modelos de imagen->3D traen la textura PROYECTADA desde
el concepto, y el generador pinto los clavos de las cajas como puntos de un
AZUL LAVANDA (medido: 90,90,123 sobre una madera de 134,60,38). En el juego la
caja se ve pequena, asi que esos puntos no se leen como clavos: se leen como
manchas de color frio sobre naranja —a ese tamano el ojo los ve verdosos— y
salpicadas por las esquinas de cada cara. Medido en la caja: 177 manchas, 66 de
ellas de 28-50 px, el 2,4% del atlas.

NO es la compresion ni el decimado: los puntos estan en el PNG de 1024 tal cual
sale del generador. Se comprobo antes de tocar nada.

Como los quita sin dejar un pegote:
  1. MASCARA por color frio (b > r + margen), que en una madera calida no puede
     confundirse con nada del propio material.
  2. HALO ancho alrededor (por defecto 8 px a 1024). Hace falta porque la
     textura se importa a 256 y con mipmaps, asi que Godot muestrea un mapa
     reducido que promedia texels de mucho mas alla del borde del lunar: sin
     halo sobrevive un aro azulado. Es la misma leccion que `eye_patch_fix.py`.
  3. RELLENO por difusion desde la madera de alrededor (media de los vecinos
     validos, creciendo hacia dentro), que da el TONO local correcto aunque el
     atlas tenga tablas de tonos muy distintos pegadas.
  4. Y se le devuelve la VETA copiando el detalle de alta frecuencia de una
     zona desplazada de la propia textura. Sin este paso quedan lunares lisos:
     el color acierta pero se ve el parche.

Uso:  python tools/lunares_fix.py assets/models/caja_0.png
      python tools/lunares_fix.py assets/models/caja_0.png --check
El original se guarda como <nombre>.antes_de_los_lunares la primera vez.

OJO: despues hay que REIMPORTAR (`--headless --import`) o Godot sigue sirviendo
el `.ctex` viejo y parece que el cambio no ha hecho nada.
"""

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

## Cuanto mas azul que rojo tiene que ser un texel para contar como lunar. Con 8
## se cogen los lunares enteros incluido su antialias; la madera de la caja no
## llega nunca (su canal azul esta 96 puntos por DEBAJO del rojo).
MARGEN = 8
## Halo alrededor del lunar, en pixeles de la textura de origen (1024).
HALO = 8
## Pasadas de difusion. Con el halo puesto, el agujero mas ancho de la caja
## mide ~68 px, asi que 90 pasadas lo cierran de sobra desde los dos lados.
PASADAS = 90
## De donde se copia la veta: un salto que no cae en ningun lunar vecino.
SALTO = (137, 91)


def mascara_fria(a: np.ndarray, margen: int) -> np.ndarray:
    return a[..., 2].astype(int) > a[..., 0].astype(int) + margen


def dilatar(m: np.ndarray, pasos: int) -> np.ndarray:
    if pasos <= 0:
        return m
    im = Image.fromarray((m * 255).astype("uint8"))
    for _ in range(pasos):
        im = im.filter(ImageFilter.MaxFilter(3))
    return np.asarray(im) > 127


def rellenar(a: np.ndarray, hueco: np.ndarray, pasadas: int) -> np.ndarray:
    """Crece la madera valida hacia dentro del hueco, promediando vecinos."""
    out = a.astype(np.float32).copy()
    val = (~hueco).astype(np.float32)
    out[hueco] = 0.0
    for _ in range(pasadas):
        if val.min() > 0.5:
            break
        suma = np.zeros_like(out)
        peso = np.zeros_like(val)
        for eje, d in ((0, 1), (0, -1), (1, 1), (1, -1)):
            suma += np.roll(out * val[..., None], d, axis=eje)
            peso += np.roll(val, d, axis=eje)
        nuevo = np.where(peso[..., None] > 0, suma / np.maximum(peso[..., None], 1e-6), out)
        crece = (val < 0.5) & (peso > 0)
        out[crece] = nuevo[crece]
        val[crece] = 1.0
    return out


def veta(a: np.ndarray, hueco: np.ndarray) -> np.ndarray:
    """Detalle de alta frecuencia de una zona desplazada, para no dejar liso."""
    suave = np.asarray(
        Image.fromarray(a.astype("uint8")).filter(ImageFilter.GaussianBlur(3.0))
    ).astype(np.float32)
    detalle = a.astype(np.float32) - suave
    det = np.roll(np.roll(detalle, SALTO[0], axis=0), SALTO[1], axis=1)
    # Donde la zona de la que se copia era a su vez un lunar, sin veta.
    malo = np.roll(np.roll(hueco, SALTO[0], axis=0), SALTO[1], axis=1)
    det[malo] = 0.0
    return det


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("textura")
    ap.add_argument("--check", action="store_true", help="solo informa")
    ap.add_argument("--margen", type=int, default=MARGEN)
    ap.add_argument("--halo", type=int, default=HALO)
    args = ap.parse_args()

    ruta = Path(args.textura)
    if not ruta.exists():
        print("no existe:", ruta)
        return 1

    im = Image.open(ruta).convert("RGB")
    a = np.asarray(im)
    m = mascara_fria(a, args.margen)
    frac = 100.0 * m.sum() / m.size
    calido = a[..., 0].mean() - a[..., 2].mean()
    print("%s  %dx%d  calidez %+.1f  lunares %d px (%.2f%%)"
          % (ruta.name, im.width, im.height, calido, m.sum(), frac))
    if calido < 20:
        print("  OJO: esta textura no es calida; aqui 'frio' no significa lunar.")
    if not m.any():
        print("  nada que quitar")
        return 0
    if args.check:
        return 0

    hueco = dilatar(m, args.halo)
    print("  con halo de %d px: %d px a repintar (%.2f%%)"
          % (args.halo, hueco.sum(), 100.0 * hueco.sum() / hueco.size))

    base = rellenar(a, hueco, PASADAS)
    det = veta(a, hueco)
    out = a.astype(np.float32).copy()
    out[hueco] = np.clip(base[hueco] + det[hueco], 0, 255)

    resp = ruta.with_suffix(ruta.suffix + ".antes_de_los_lunares")
    if not resp.exists():
        resp.write_bytes(ruta.read_bytes())
        print("  original guardado en", resp.name)
    Image.fromarray(out.astype("uint8")).save(ruta)

    queda = mascara_fria(np.asarray(Image.open(ruta).convert("RGB")), args.margen)
    print("  quedan %d px frios (%.3f%%)" % (queda.sum(), 100.0 * queda.sum() / queda.size))
    print("  AHORA: --headless --import, o Godot sigue sirviendo el .ctex viejo")
    return 0


if __name__ == "__main__":
    sys.exit(main())
