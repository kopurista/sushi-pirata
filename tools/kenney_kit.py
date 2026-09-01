#!/usr/bin/env python3
"""Trae piezas del PIRATE KIT de Kenney al proyecto, con la paleta de JUGUETE.

El kit (CC0, uso comercial libre y sin atribucion obligatoria) es la base del
mundo del juego desde el 1-9-2026: barco, isla, puerto, abordaje y todo el
atrezzo. Los PERSONAJES y los PLATOS no salen de aqui — el kit no trae ninguno.

Por que este kit y no seguir generando:
  - 72 modelos por 2,9 MB, contra los 417 MB que sumaban los generados.
  - El galeon son 1.938 triangulos; el barco enemigo generado se plantaba en
    16.410 y no bajaba (el simplificador tiene suelo propio). No hay que
    decimar NADA: ninguna pieza pasa de 2.000.
  - LOS 72 COMPARTEN UNA SOLA TEXTURA de paleta, 512x512 y 9,8 KB. Una textura
    en memoria para todo el mundo, y recolorear el juego entero es editar UNA
    imagen — que es justo lo que hace este script.

LA PALETA VA SATURADA. Kenney la entrega apagada y de acabado mate, y el
estilo del juego es plastico de juguete: se le sube la saturacion y un punto
de brillo. El BRILLO de la superficie no va aqui (una textura no lo lleva):
lo pone `SceneBackdrop.acabado_juguete`, que baja el `roughness`.

    python tools/kenney_kit.py            # copia lo declarado y la paleta
    python tools/kenney_kit.py --lista    # que hay en el kit y que se usa
"""

import os
import shutil
import sys

from PIL import Image, ImageEnhance

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KIT = os.path.join(os.path.dirname(RAIZ), "Kenney Game Assets All-in-1 3.7.0",
    "3D assets", "Pirate Kit", "Models", "GLB format")
DESTINO = os.path.join(RAIZ, "assets", "models", "kenney")

## Cuanto se sube la saturacion y el brillo de la paleta. MEDIDO a ojo contra
## los conceptos aprobados: por encima de 1.6 los marrones se vuelven naranjas
## de plastico barato y la madera deja de leerse como madera.
SATURACION = 1.42
BRILLO = 1.08

## Lo que se trae al proyecto. NO se copia el kit entero a proposito: el preset
## de export lleva `export_filter="all_resources"`, asi que todo lo que entre
## viaja al .pck aunque no lo use nadie (la misma regla que las librerias de
## sonido). Al necesitar una pieza nueva, se añade aqui y se vuelve a pasar.
PIEZAS = [
    # --- el barco del jugador y los enemigos
    "ship-pirate-large", "ship-pirate-medium", "ship-pirate-small",
    "ship-wreck",
    # --- isla
    "palm-detailed-bend", "palm-detailed-straight", "palm-bend", "palm-straight",
    "rocks-a", "rocks-b", "rocks-c", "rocks-sand-a", "rocks-sand-b",
    "patch-sand", "patch-grass", "grass-patch",
    # --- puerto
    "structure-platform-dock", "structure-platform-dock-small",
    "structure-platform", "platform-planks", "structure-fence", "tower-watch",
    # --- atrezzo
    "barrel", "crate", "crate-bottles", "chest", "bottle", "cannon",
    "cannon-mobile", "cannon-ball", "flag-pirate", "flag", "mast",
    "mast-ropes", "tool-paddle", "tool-shovel",
]


def nombre(m: str) -> str:
    """Kenney usa guiones y el proyecto guiones bajos."""
    return m.replace("-", "_")


def main() -> int:
    if not os.path.isdir(KIT):
        return err("No encuentro el kit en:\n  %s" % KIT)
    if "--lista" in sys.argv:
        hay = sorted(f[:-4] for f in os.listdir(KIT) if f.endswith(".glb"))
        print("EN EL KIT (%d):" % len(hay))
        for m in hay:
            print("  %-30s %s" % (m, "<- se usa" if m in PIEZAS else ""))
        return 0
    os.makedirs(os.path.join(DESTINO, "Textures"), exist_ok=True)
    faltan = []
    for m in PIEZAS:
        origen = os.path.join(KIT, m + ".glb")
        if not os.path.isfile(origen):
            faltan.append(m)
            continue
        shutil.copyfile(origen, os.path.join(DESTINO, nombre(m) + ".glb"))
    print("copiadas %d piezas" % (len(PIEZAS) - len(faltan)))
    if faltan:
        print("NO estaban en el kit: %s" % ", ".join(faltan))

    # LA PALETA. Se guarda con el nombre que piden los .glb (`colormap.png`,
    # que referencian por ruta relativa), asi que los 72 modelos la cogen sin
    # tocar ni una linea de codigo.
    src = os.path.join(KIT, "Textures", "colormap.png")
    im = Image.open(src).convert("RGBA")
    rgb = ImageEnhance.Color(im.convert("RGB")).enhance(SATURACION)
    rgb = ImageEnhance.Brightness(rgb).enhance(BRILLO)
    out = Image.merge("RGBA", (*rgb.split(), im.split()[3]))
    out.save(os.path.join(DESTINO, "Textures", "colormap.png"))
    print("paleta de juguete: saturacion x%.2f, brillo x%.2f" % (SATURACION, BRILLO))
    print("\nOJO: si los .glb ya estaban importados SIN la textura, Godot se "
        "queda con\nel resultado cacheado. Hay que borrar sus .scn de "
        ".godot/imported y reimportar.")
    return 0


def err(msg: str) -> int:
    print(msg)
    return 1


if __name__ == "__main__":
    sys.exit(main())
