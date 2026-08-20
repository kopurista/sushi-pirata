#!/usr/bin/env python3
"""Recorta las PUNTAS DE PELO que sobresalen del Kappa (kappa_rig.glb).

El modelo viene de imagen->3D y su pelo son plaquitas finas que salen disparadas
del craneo: a tamaño de juego no se leen como mechones, sino como LINEAS sueltas
clavadas fuera de la silueta (era el "error del modelo" que se veia en el nivel).

Como se arregla: NO se borran triangulos (eso deja agujeros). Se CLAVA EL RADIO
maximo de la banda del pelo, empujando hacia el eje de la cabeza solo lo que
sobresale. Medido por franjas de altura: en el pelo (y 0.355..0.468) el radio
mediano es ~0.11 y el percentil 90 ~0.12, pero la cola llega a 0.150 — esas
puntas son el problema. Se acotan al percentil `TOPE_PCT` de SU franja.

Dos cosas que gobiernan los limites y no son libres:
  - Por DEBAJO de 0.355 esta el PICO, que sobresale hacia +z hasta 0.168: si se
    mete en el recorte, se le lima el pico al bicho.
  - Por ENCIMA de 0.468 esta el PLATO de la cabeza, que es ancho por definicion;
    acotarlo le come el borde.

La pose de BIND coincide con la de reposo en este rig (comprobado: diferencia
maxima 0.00000), asi que mover el accessor POSITION mueve exactamente lo que se
dibuja. Si algun dia se regenera el modelo, volver a comprobarlo con
`tools/skin_pose.py` antes de fiarse de esto.

Uso:  python tools/kappa_pelo_fix.py [--check]
"""

import json
import math
import struct
import sys
from pathlib import Path

MODELO = Path("assets/models/kappa_rig.glb")

## Banda del PELO, en coordenadas del modelo (alto total 1.004, de -0.502 a
## 0.502). Fuera de ella estan el pico (abajo) y el plato (arriba).
Y_MIN = 0.355
Y_MAX = 0.468
## Alto de cada franja en la que se mide el radio.
FRANJA = 0.02
## Percentil de radio al que se acota cada franja.
TOPE_PCT = 0.93


def leer(path):
    raw = path.read_bytes()
    n = struct.unpack("<I", raw[12:16])[0]
    js = json.loads(raw[20:20 + n])
    off = 20 + n
    blen = struct.unpack("<I", raw[off:off + 4])[0]
    return js, bytearray(raw[off + 8:off + 8 + blen]), raw


def vista_de(js, idx):
    """(offset en el binario, stride, numero de vertices) del accessor."""
    acc = js["accessors"][idx]
    view = js["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride") or 12
    return start, stride, acc["count"]


def main() -> None:
    solo_mirar = "--check" in sys.argv
    js, bin_, raw = leer(MODELO)
    prim = js["meshes"][0]["primitives"][0]
    start, stride, n = vista_de(js, prim["attributes"]["POSITION"])

    pos = []
    for i in range(n):
        o = start + i * stride
        pos.append(list(struct.unpack("<fff", bin_[o:o + 12])))

    # Eje de la cabeza: la mediana de x/z de todo lo que hay por encima de los
    # hombros (no el centro de la caja, que el pico desplaza).
    arriba = [p for p in pos if p[1] > 0.33]
    cx = sorted(p[0] for p in arriba)[len(arriba) // 2]
    cz = sorted(p[2] for p in arriba)[len(arriba) // 2]

    def radio(p):
        return math.hypot(p[0] - cx, p[2] - cz)

    # Tope por franja.
    topes = {}
    b = Y_MIN
    while b < Y_MAX:
        rs = sorted(radio(p) for p in pos if b <= p[1] < b + FRANJA)
        if rs:
            topes[round(b, 3)] = rs[min(int(len(rs) * TOPE_PCT), len(rs) - 1)]
        b = round(b + FRANJA, 3)

    tocados = 0
    peor = 0.0
    for i, p in enumerate(pos):
        if not (Y_MIN <= p[1] < Y_MAX):
            continue
        clave = round(Y_MIN + math.floor((p[1] - Y_MIN) / FRANJA) * FRANJA, 3)
        tope = topes.get(clave)
        if tope is None:
            continue
        r = radio(p)
        if r <= tope or r <= 1e-6:
            continue
        k = tope / r
        peor = max(peor, r - tope)
        tocados += 1
        if solo_mirar:
            continue
        p[0] = cx + (p[0] - cx) * k
        p[2] = cz + (p[2] - cz) * k
        struct.pack_into("<fff", bin_, start + i * stride, p[0], p[1], p[2])

    print("eje de la cabeza x=%.3f z=%.3f" % (cx, cz))
    print("puntas recortadas: %d de %d vertices (la peor sobresalia %.4f)"
          % (tocados, n, peor))
    if solo_mirar:
        return

    # Se reescribe el GLB con el mismo JSON y el binario retocado.
    # OJO CON EL TROCEADO: tras la cabecera de 12 bytes va el chunk de JSON
    # ENTERO, o sea su longitud (4) + su tipo (4) + los datos. Cortando en el
    # tipo se pierden esos 4 bytes y el archivo queda corrido: el JSON se lee
    # desde el sitio equivocado y revienta con un UnicodeDecodeError.
    njs = struct.unpack("<I", raw[12:16])[0]
    salida = bytearray(raw[:20 + njs])
    salida += struct.pack("<I", len(bin_)) + b"BIN\x00" + bin_
    struct.pack_into("<I", salida, 8, len(salida))
    MODELO.write_bytes(salida)
    print("escrito", MODELO)


if __name__ == "__main__":
    main()
