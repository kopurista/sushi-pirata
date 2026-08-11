"""Rehace el sprite de un PLATO a partir de su concepto de assets/models/source.

El sprite de `assets/dishes/` sale del concepto 1024x1024 recortado a la caja
del sujeto. Cuando ese recorte se hizo con la INUNDACION desde los bordes
(ver icon_prep), el blanco del fondo y el blanco del ARROZ son el mismo color,
asi que si el arroz toca el fondo sin contorno oscuro por medio la inundacion
se mete dentro del rollo y se lo come: el maki de aguacate tenia el rollo de
arriba cortado a cuchillo por la parte superior.

Los conceptos de `assets/models/source/` ya vienen con ALFA de verdad (son los
que se mandaron a imagen->3D), asi que no hace falta inundar nada: basta
recortar por la caja del alfa y escalar. Por eso este camino no puede comerse
el sujeto.

    python tools/dish_from_source.py --check              # audita los 28
    python tools/dish_from_source.py maki_aguacate        # rehace uno

CUIDADO: no todos los platos tienen concepto (28 de 41), y el sprite en uso
puede haberse retocado a mano despues. `--check` mide CUANTO SUJETO FALTA
comparando el alfa del concepto contra el del sprite; hay un ~3% de ruido de
fondo por el remuestreo del borde, asi que lo que delata un mordisco es pasar
de ahi (el maki de aguacate estaba en 5.94%).
"""

import sys
from pathlib import Path

from PIL import Image

SRC = Path("assets/models/source")
DST = Path("assets/dishes")
## Mismo umbral que el resto de recortes del proyecto (0.6 de alfa).
ALPHA = 153


def caja(img: Image.Image):
    return img.split()[3].point(lambda a: 255 if a >= ALPHA else 0).getbbox()


def rehacer(nombre: str, check: bool) -> None:
    fsrc = SRC / f"{nombre}.webp"
    fdst = DST / f"{nombre}.webp"
    if not fsrc.exists() or not fdst.exists():
        return
    src = Image.open(fsrc).convert("RGBA")
    bb = caja(src)
    if bb is None:
        return
    act = Image.open(fdst).convert("RGBA")
    ancho = act.size[0]
    alto = round((bb[3] - bb[1]) * ancho / (bb[2] - bb[0]))
    if check:
        # CUANTO SUJETO FALTA: se compara el alfa del concepto (reescalado al
        # sprite) contra el del sprite. El alto NO sirve como detector — un
        # mordisco es una MUESCA en medio y no mueve la caja: el maki de
        # aguacate perdio el rollo de arriba con solo 3 px de diferencia.
        # Hay un ruido de fondo del ~3% por el remuestreo del borde, asi que
        # lo que canta es pasar de ahi.
        ref = src.crop(bb).resize(act.size, Image.LANCZOS)
        ra = ref.split()[3].load()
        aa = act.split()[3].load()
        falta = tot = 0
        for y in range(0, act.size[1], 2):
            for x in range(0, ancho, 2):
                if ra[x, y] >= ALPHA:
                    tot += 1
                    if aa[x, y] < ALPHA:
                        falta += 1
        pc = falta * 100.0 / max(tot, 1)
        print("%-24s falta %5.2f%% del sujeto%s"
              % (nombre, pc, "   <-- REVISAR" if pc > 4.5 else ""))
        return
    print("%-24s ahora %dx%d   del concepto %dx%d"
          % (nombre, act.size[0], act.size[1], ancho, alto))
    out = src.crop(bb).resize((ancho, alto), Image.LANCZOS)
    # Calidad alta: el .import ya recomprime con perdida, aqui solo interesa
    # no encadenar una segunda degradacion.
    out.save(fdst, quality=95, method=6)
    print("   -> reescrito %s" % fdst)


if __name__ == "__main__":
    args = sys.argv[1:]
    check = "--check" in args
    nombres = [a for a in args if not a.startswith("--")]
    if not nombres:
        nombres = sorted(p.stem for p in SRC.glob("*.webp")
                         if (DST / p.name).exists())
    for n in nombres:
        rehacer(n, check)
