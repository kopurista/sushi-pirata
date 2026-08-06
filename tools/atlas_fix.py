#!/usr/bin/env python3
"""Quita las MANCHAS pintadas sobre las piezas claras de un modelo (las velas).

Por que hace falta: los modelos de imagen->3D traen la textura PROYECTADA desde
el concepto, y donde el original tenia una sombra o un mastil por delante, esa
sombra queda PINTADA en el atlas. En el barco del mapa las velas salian con un
borron marron-negro en la parte de arriba. No era la compresion ni el decimado:
se comprobo a 1024 sin comprimir y sin decimar y la mancha seguia igual.

Como lo arregla SIN tocar la madera: no mira la imagen a ciegas, mira la
GEOMETRIA. Recorre los triangulos del `.glb`, se queda con los que son de vela
—los que caen sobre texels claros en su mayoria— y dentro de ESOS triangulos, y
solo ahi, repinta lo oscuro con el tono claro del propio triangulo. Los limites
del repintado son las UV de la pieza, asi que no puede desbordarse a la madera
vecina por mucho que esten pegadas en el atlas.

Se probaron antes dos vias peores, y conviene no repetirlas:
  - Cierre morfologico (dilatar/erosionar) sobre la mascara de "claro": con un
    radio capaz de tapar las manchas gordas TAMBIEN salta el hueco entre dos
    islas vecinas y pinta de blanco la madera de en medio (aparecio una mancha
    clara sobre una verga).
  - Relleno de huecos por topologia (inundar lo oscuro desde los bordes): es
    seguro, pero solo coge las manchas RODEADAS de claro. La peor del barco
    toca el borde de su isla y sobrevivia intacta.

Uso:  python tools/atlas_fix.py assets/models/map_barco.glb
      python tools/atlas_fix.py ruta.glb --check     (solo informa)
"""

import json
import struct
import sys
from pathlib import Path

from PIL import Image

## Que se considera claro: luminancia alta y poca diferencia entre canales. El
## marron de la madera es oscuro Y saturado, asi que no cuela por ninguna via.
LIGHT_MIN = 0.60
LIGHT_SPREAD = 0.26
## Un triangulo se toma por "de vela" si al menos esta fraccion de sus texels
## ya es clara. Con menos, una tabla con un reflejo se colaria como vela.
SAIL_FRAC = 0.55
## Y solo si tiene texels suficientes para que la estadistica valga algo.
MIN_TEXELS = 12

COMP = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
NUM = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_glb(path):
    raw = path.read_bytes()
    n = struct.unpack("<I", raw[12:16])[0]
    js = json.loads(raw[20:20 + n])
    # El chunk binario va detras del de JSON, con su propia cabecera de 8 bytes.
    off = 20 + n
    blen = struct.unpack("<I", raw[off:off + 4])[0]
    return js, raw[off + 8:off + 8 + blen]


def accessor(js, bin_, idx):
    acc = js["accessors"][idx]
    view = js["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    fmt = COMP[acc["componentType"]]
    per = NUM[acc["type"]]
    size = struct.calcsize(fmt) * per
    stride = view.get("byteStride") or size
    out = []
    for i in range(acc["count"]):
        chunk = bin_[start + i * stride: start + i * stride + size]
        out.append(struct.unpack("<" + fmt * per, chunk))
    return out


## Manchas RODEADAS de claro mas grandes que esto no se tocan: a ese tamaño ya
## no es una mancha, es una pieza oscura que de verdad va ahi.
MAX_HOLE = 4000


def is_light(c):
    r, g, b = c[0] / 255.0, c[1] / 255.0, c[2] / 255.0
    return min(r, g, b) >= LIGHT_MIN and (max(r, g, b) - min(r, g, b)) <= LIGHT_SPREAD


def fill_enclosed(im, px, w, h):
    """Segunda red: repinta lo oscuro ENCERRADO por claro, mire quien mire la
    geometria. Hace falta porque hay manchas que caen en triangulos que el
    clasificador no da por vela —la de la vela de arriba del barco era una— y
    esas se colaban entre las mallas de la primera pasada."""
    light = bytearray(w * h)
    for y in range(h):
        for x in range(w):
            if is_light(px[x, y]):
                light[y * w + x] = 1
    seen = bytearray(w * h)
    stack = []
    for x in range(w):
        for y in (0, h - 1):
            i = y * w + x
            if not light[i] and not seen[i]:
                seen[i] = 1
                stack.append(i)
    for y in range(h):
        for x in (0, w - 1):
            i = y * w + x
            if not light[i] and not seen[i]:
                seen[i] = 1
                stack.append(i)
    while stack:
        i = stack.pop()
        y, x = divmod(i, w)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            xx, yy = x + dx, y + dy
            if 0 <= xx < w and 0 <= yy < h:
                j = yy * w + xx
                if not light[j] and not seen[j]:
                    seen[j] = 1
                    stack.append(j)

    done = 0
    for start in range(w * h):
        if light[start] or seen[start]:
            continue
        group = []
        seen[start] = 1
        stack = [start]
        while stack:
            i = stack.pop()
            group.append(i)
            y, x = divmod(i, w)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h:
                    j = yy * w + xx
                    if not light[j] and not seen[j]:
                        seen[j] = 1
                        stack.append(j)
        if len(group) > MAX_HOLE:
            continue
        for i in group:
            y, x = divmod(i, w)
            acc = [0, 0, 0]
            n = 0
            rad = 1
            while n == 0 and rad <= 40:
                for dy in range(-rad, rad + 1):
                    for dx in range(-rad, rad + 1):
                        if max(abs(dy), abs(dx)) != rad:
                            continue
                        yy, xx = y + dy, x + dx
                        if 0 <= xx < w and 0 <= yy < h and light[yy * w + xx]:
                            c = px[xx, yy]
                            acc[0] += c[0]
                            acc[1] += c[1]
                            acc[2] += c[2]
                            n += 1
                rad += 1
            if n:
                px[x, y] = (acc[0] // n, acc[1] // n, acc[2] // n)
                done += 1
    return done


def texels_of(tri, w, h):
    """Texels dentro del triangulo UV, por barrido de la caja con baricentricas."""
    xs = [p[0] * w for p in tri]
    ys = [p[1] * h for p in tri]
    x0, x1 = max(0, int(min(xs)) - 1), min(w - 1, int(max(xs)) + 1)
    y0, y1 = max(0, int(min(ys)) - 1), min(h - 1, int(max(ys)) + 1)
    ax, ay = xs[0], ys[0]
    bx, by = xs[1], ys[1]
    cx, cy = xs[2], ys[2]
    den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    if abs(den) < 1e-9:
        return
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px, py = x + 0.5, y + 0.5
            l1 = ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / den
            l2 = ((cy - ay) * (px - cx) + (ax - cx) * (py - cy)) / den
            l3 = 1.0 - l1 - l2
            # Margen de medio texel hacia fuera: el borde del poligono tambien
            # se muestrea al filtrar, y ahi es justo donde vive la mancha.
            if l1 >= -0.02 and l2 >= -0.02 and l3 >= -0.02:
                yield x, y


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    check = "--check" in sys.argv
    if not args:
        print(__doc__)
        return 1
    glb = Path(args[0])
    js, bin_ = read_glb(glb)
    tex = glb.with_name(glb.stem + "_0.png")
    if not tex.exists():
        print("no encuentro la textura %s" % tex.name)
        return 1
    im = Image.open(tex).convert("RGB")
    w, h = im.size
    px = im.load()

    sail_tris = 0
    grown = 0
    fixed = set()
    for mesh in js["meshes"]:
        for prim in mesh["primitives"]:
            if "TEXCOORD_0" not in prim["attributes"]:
                continue
            uv = accessor(js, bin_, prim["attributes"]["TEXCOORD_0"])
            idx = [v[0] for v in accessor(js, bin_, prim["indices"])]
            tris = []
            for t in range(0, len(idx), 3):
                a, b, c = idx[t], idx[t + 1], idx[t + 2]
                cells = list(texels_of([uv[a], uv[b], uv[c]], w, h))
                if len(cells) < MIN_TEXELS:
                    continue
                light = sum(1 for q in cells if is_light(px[q[0], q[1]]))
                tris.append({"v": (a, b, c), "cells": cells, "light": light})

            # Primera pasada: los que son vela sin discusion.
            sail = set()
            for i, tr in enumerate(tris):
                if tr["light"] >= SAIL_FRAC * len(tr["cells"]):
                    sail.add(i)
            sail_tris += len(sail)

            # Segunda pasada, POR TOPOLOGIA. Una mancha grande sobre una vela
            # puede ennegrecer su triangulo lo bastante como para que no pase
            # el corte, y entonces se quedaba intacta: es lo que pasaba con la
            # vela de arriba del barco. Un triangulo cuyos TRES vertices ya
            # pertenecen a triangulos de vela es, por fuerza, del mismo paño,
            # asi que se suma. Se repite hasta que no crece mas.
            while True:
                verts = set()
                for i in sail:
                    verts.update(tris[i]["v"])
                nuevos = {i for i, tr in enumerate(tris)
                    if i not in sail and set(tr["v"]) <= verts}
                if not nuevos:
                    break
                sail |= nuevos
                grown += len(nuevos)

            for i in sail:
                tr = tris[i]
                claros = [q for q in tr["cells"] if is_light(px[q[0], q[1]])]
                if not claros:
                    continue
                n = len(claros)
                tone = (sum(px[q[0], q[1]][0] for q in claros) // n,
                        sum(px[q[0], q[1]][1] for q in claros) // n,
                        sum(px[q[0], q[1]][2] for q in claros) // n)
                for q in tr["cells"]:
                    if not is_light(px[q[0], q[1]]):
                        fixed.add(q)
                        if not check:
                            px[q[0], q[1]] = tone

    enclosed = 0 if check else fill_enclosed(im, px, w, h)
    print("%s: %d triangulos de vela (+%d por topologia), %d texels por UV, "
        "%d mas por estar rodeados" % (
            glb.name, sail_tris, grown, len(fixed), enclosed))
    if not check and (fixed or enclosed):
        im.save(tex)
        print("  textura reescrita")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
