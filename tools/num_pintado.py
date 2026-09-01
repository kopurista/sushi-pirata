#!/usr/bin/env python3
"""Los NUMEROS de los escenarios, PINTADOS A BROCHA como la flecha del cartel.

Antes eran cifras TALLADAS: la trama de la madera recortada por la silueta de
la fuente y con el relieve horneado (`tools/num_map.py`, que se queda solo para
las estrellas). Al pasar el cartel del escenario a ser un letrero de madera de
verdad, el numero tenia que ser lo mismo que la flecha del cartel de paso: cal
blanca dada con brocha.

De donde salen: UNA generacion de Ludo con los diez digitos en fila sobre fondo
negro (`assets/map/num_pintado.origen`). Se recortan de ahi y se componen los numeros. Diez
digitos valen para cualquier cifra: pedir una imagen por escenario serian
sesenta generaciones hoy y doscientas cincuenta cuando la campana este entera.

Uso:  python tools/num_pintado.py [--hasta 60]
Despues: `--headless --import`.
"""

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

RAIZ = Path(__file__).resolve().parent.parent
## LA HOJA DE DIGITOS VIVE EN EL REPOSITORIO, con una extension que Godot no
## importa: `_gen/` esta en el .gitignore, asi que dejandola alli la herramienta
## dejaba de poder pasarse en cuanto se limpiaba el directorio de trabajo.
FUENTE = RAIZ / "assets/map/num_pintado.origen"
OUT = RAIZ / "assets/map"

## Umbral de recorte contra el fondo negro y ancho de la rampa del canto.
FONDO = 26.0
RAMPA = 46.0
## EROSION PARA SEPARAR LOS DIGITOS. Por muy separados que se pidan, el
## generador los deja tocandose por el antialias: de tres hojas pedidas, la
## mejor daba NUEVE tramos de columna en vez de diez. Adelgazando la mascara
## dos pixeles, el puente se rompe y salen los diez limpios (medido: anchos
## 84-46-75-77-85-76-78-74-79-78, con el 46 del "1"). Luego se corta por el
## PUNTO MEDIO de cada hueco sobre la mascara ORIGINAL, asi que ningun digito
## pierde grosor.
EROSION = 2
## Separacion entre digitos, en fraccion del alto del digito. A ojo se juntaban
## demasiado: estos numeros se leen a 40 px de alto en el mapa.
HUECO = 0.10
## Margen transparente alrededor del numero compuesto.
MARGEN = 0.06
## Alto al que se guarda cada numero (px). El quad lo escala por su proporcion,
## asi que esto solo fija el detalle.
ALTO = 220


def cortar_digitos(p: Path):
    """Devuelve los diez digitos recortados, de izquierda a derecha."""
    a = np.asarray(Image.open(p).convert("RGB")).astype(np.float32)
    lum = a.max(axis=2)
    alfa = np.clip((lum - FONDO) / RAMPA, 0.0, 1.0)
    # EL COLOR SE EXTIENDE HACIA FUERA antes de recortar: si no, el canto se
    # queda con el negro del fondo mezclado y sale un reborde sucio.
    solido = alfa > 0.85
    rgb = a.copy()
    val = solido.copy()
    rgb[~val] = 0.0
    for _ in range(24):
        if val.all():
            break
        s = np.zeros_like(rgb)
        w = np.zeros_like(val, dtype=np.float32)
        for eje, d in ((0, 1), (0, -1), (1, 1), (1, -1)):
            s += np.roll(rgb * val[..., None], d, axis=eje)
            w += np.roll(val.astype(np.float32), d, axis=eje)
        crece = (~val) & (w > 0)
        rgb[crece] = (s / np.maximum(w, 1e-6)[..., None])[crece]
        val |= crece

    # Los digitos se separan por COLUMNAS VACIAS de la mascara EROSIONADA.
    fina = Image.fromarray(((alfa > 0.5) * 255).astype("uint8"))
    for _ in range(EROSION):
        fina = fina.filter(ImageFilter.MinFilter(3))
    col = (np.asarray(fina) > 127).any(axis=0)
    tramos = []
    ini = None
    for x, hay in enumerate(col):
        if hay and ini is None:
            ini = x
        elif not hay and ini is not None:
            tramos.append((ini, x))
            ini = None
    if ini is not None:
        tramos.append((ini, len(col)))
    ancho = a.shape[1]
    tramos = [t for t in tramos if t[1] - t[0] > ancho * 0.012]
    if len(tramos) != 10:
        print("! salen %d tramos, no 10: %s" % (len(tramos), tramos))
        return None
    # Y se corta por el PUNTO MEDIO de cada hueco, sobre la mascara original.
    cortes = [0]
    for k in range(9):
        cortes.append((tramos[k][1] + tramos[k + 1][0]) // 2)
    cortes.append(ancho)
    digitos = []
    for k in range(10):
        x0, x1 = cortes[k], cortes[k + 1]
        franja = alfa[:, x0:x1]
        # CADA DIGITO SE RECORTA A SU PROPIA TINTA, tambien a lo ANCHO. Cortando
        # solo por el punto medio de los huecos, el "0" y el "9" se llevaban
        # ademas el margen exterior de la hoja (141 y 135 px de ancho contra los
        # ~95 de los demas), asi que un numero acabado en cero salia con un
        # hueco enorme antes del cero. Con el recorte a la tinta, la separacion
        # la pone `HUECO` y es la misma entre cualquier par.
        cols = np.nonzero((franja > 0.35).any(axis=0))[0]
        filas = np.nonzero((franja > 0.35).any(axis=1))[0]
        cx0, cx1 = x0 + cols.min(), x0 + cols.max() + 1
        y0, y1 = filas.min(), filas.max() + 1
        d = np.dstack([rgb[y0:y1, cx0:cx1], alfa[y0:y1, cx0:cx1] * 255.0])
        digitos.append(Image.fromarray(d.astype("uint8"), "RGBA"))
    return digitos


def componer(digitos, n: int) -> Image.Image:
    """Pone los digitos de `n` en fila, alineados por la LINEA DE BASE."""
    txt = str(n)
    # Todos los digitos se escalan al mismo alto de referencia (el del "8",
    # que es el mas alto): asi el "1" no sale gigante por ser estrecho.
    ref = max(d.height for d in digitos)
    piezas = []
    for c in txt:
        d = digitos[int(c)]
        k = ALTO / float(ref)
        piezas.append(d.resize((max(int(d.width * k), 1), max(int(d.height * k), 1)),
                               Image.LANCZOS))
    hueco = int(ALTO * HUECO)
    ancho = sum(p.width for p in piezas) + hueco * (len(piezas) - 1)
    alto = max(p.height for p in piezas)
    m = int(ALTO * MARGEN)
    lienzo = Image.new("RGBA", (ancho + 2 * m, alto + 2 * m), (0, 0, 0, 0))
    x = m
    for p in piezas:
        # POR EL CENTRO, no por la base: los redondos (el 0, el 6, el 8) se
        # pintan con un pelo de rebose por arriba Y por abajo, asi que
        # apoyandolos en la linea se quedaban bajos respecto a su vecino — que
        # es lo que se veia como que el cero no estaba alineado.
        lienzo.alpha_composite(p, (x, m + (alto - p.height) // 2))
        x += p.width + hueco
    return lienzo


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--hasta", type=int, default=60)
    args = ap.parse_args()
    if not FUENTE.exists():
        print("falta la fuente:", FUENTE)
        return 1
    digitos = cortar_digitos(FUENTE)
    if digitos is None:
        return 1
    print("digitos recortados: %s" % [d.size for d in digitos])
    for n in range(1, args.hasta + 1):
        componer(digitos, n).save(OUT / ("num_%d.png" % n))
    print("escritos num_1..num_%d.png (alto %d)" % (args.hasta, ALTO))
    print("AHORA: --headless --import")
    return 0


if __name__ == "__main__":
    sys.exit(main())
