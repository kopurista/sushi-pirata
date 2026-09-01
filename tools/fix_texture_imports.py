#!/usr/bin/env python3
"""Deja los .import de las TEXTURAS DE MODELO como pide el export movil.

Mira TODOS los formatos que aparecen en assets/models (png, jpg, jpeg, webp):
Meshy entrega la suya en .jpg y con el filtro viejo, que solo miraba .png, se
colaba con compress/mode=2 y sin limite de tamano.

Godot importa cada textura nueva con compress/mode=2 (s3tc) y sin limite de
tamano: sin Basis Universal el export web no carga las texturas 3D en moviles.
Este script fija el modo y, SOLO a las que no tienen limite puesto (0), les da
el que toca a su familia:

  - personajes y nodos del mapa .... 512 px
  - platos y atrezzo ............... 256 px

Un limite YA puesto no se toca: varias piezas del escenario estan afinadas a
mano (la cabana y las rocas van a 512 aunque sean atrezzo) y pisarlas por
regla general les bajaria la textura a la mitad sin que nadie lo pidiera.

Uso:  python tools/fix_texture_imports.py [--check]
"""

import re
import sys
from pathlib import Path

MODELS = Path(__file__).resolve().parent.parent / "assets" / "models"

## Modelos que se ven GRANDES en pantalla: personajes y nodos del mapa.
BIG_PREFIXES = (
    "chef", "ayudante", "grumete", "pirata", "capitan", "vip", "tendero", "map_",
)

## LA PALETA DE KENNEY SE QUEDA EN LOSSLESS, y no es un descuido. Es una
## tabla de bandas de color plano que tiñe LOS 72 MODELOS del mundo: comprimir
## por bloques correria los colores en los cantos de cada banda, y como las UV
## apuntan dentro de las bandas, eso se veria como un tinte raro en piezas
## sueltas. Ocupa 1 MB de VRAM y colorea el juego entero: es una ganga. Y el
## modo 0 (sin comprimir) carga en TODAS las plataformas — lo que no carga en
## el movil web es el modo 2 (s3tc), que es contra lo que existe este script.
EXENTAS = {"colormap.png.import"}

RULES = {
    "compress/mode": "4",
    "compress/rdo_quality_loss": "4.0",
    "detect_3d/compress_to": "0",
}


def size_limit(name: str) -> str:
    return "512" if name.startswith(BIG_PREFIXES) else "256"


def main() -> int:
    check = "--check" in sys.argv
    bad = []
    # TODOS los formatos de textura de modelo, no solo PNG: MESHY entrega la
    # suya en .jpg y se colaba en s3tc sin que nadie lo viera (en el export web
    # movil eso es una textura que NO CARGA). Lo caza el --check de ahora.
    rutas = []
    for ext in ("png", "jpg", "jpeg", "webp"):
        # rglob, no glob: la paleta del kit de Kenney vive en una SUBCARPETA
        # (assets/models/kenney/Textures) y con el filtro plano no se miraba.
        rutas += list(MODELS.rglob("*.%s.import" % ext))
    for path in sorted(rutas):
        if path.name in EXENTAS:
            continue
        # utf-8-sig se come el BOM si lo hubiera; luego se escribe sin el.
        text = path.read_text(encoding="utf-8-sig")
        out = text
        rules = dict(RULES)
        # El limite solo se pone si no habia ninguno: ver cabecera.
        if re.search(r"^process/size_limit=0$", text, flags=re.MULTILINE):
            rules["process/size_limit"] = size_limit(path.name)
        for key, value in rules.items():
            out = re.sub(
                r"^%s=.*$" % re.escape(key), "%s=%s" % (key, value),
                out, flags=re.MULTILINE)
        if out != text or text != path.read_text(encoding="utf-8"):
            bad.append(path.name)
            if not check:
                path.write_text(out, encoding="utf-8", newline="\n")
    if check:
        print("fuera de norma: %d" % len(bad))
        for n in bad:
            print("  " + n)
    else:
        print("corregidos: %d" % len(bad))
    return 1 if (check and bad) else 0


if __name__ == "__main__":
    raise SystemExit(main())
