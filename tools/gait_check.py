#!/usr/bin/env python3
"""Analiza si un clip GLB de animacion es un ciclo de andar CORRECTO.

Las metricas que devuelve la API de Ludo (motion, fit_rmse) miden cuanto se
mueve el esqueleto y como de fiel es al prompt, pero NO si el resultado es una
marcha: un clip que arrastra un solo pie puntua igual que uno que alterna las
dos piernas. Este script mide lo que de verdad importa.

Hace cinematica directa sobre el clip (el GLB de animacion trae la jerarquia
completa de huesos como nodos), saca la trayectoria de cada pie y comprueba:

  - amplitud: cuanto avanza y retrocede cada pie en el eje de marcha,
  - simetria: que ambos pies se muevan por igual (no uno quieto),
  - antifase: que cuando uno va delante el otro va detras. Es LA firma de un
    ciclo de marcha; se mide con la correlacion de Pearson entre las dos
    señales, que debe ser MUY NEGATIVA (-1 = alternancia perfecta).
  - cruces: cuantas veces se adelantan mutuamente (2 por ciclo completo).

Uso:  python tools/gait_check.py clip.glb [clip2.glb ...]
"""

import gzip
import json
import math
import struct
import sys
from pathlib import Path

GLB_MAGIC = b"glTF"
GZIP_MAGIC = b"\x1f\x8b"

COMP_COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
COMP_FMT = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
COMP_SIZE = {"b": 1, "B": 1, "h": 2, "H": 2, "I": 4, "f": 4}


# --------------------------------------------------------------- lectura GLB

def load_glb(path):
    raw = Path(path).read_bytes()
    if raw[:2] == GZIP_MAGIC:
        raw = gzip.decompress(raw)
    if raw[:4] != GLB_MAGIC:
        raise ValueError("no es un GLB: %s" % path)
    total = struct.unpack("<I", raw[8:12])[0]
    offset, doc, binary = 12, None, b""
    while offset < total:
        length, kind = struct.unpack("<II", raw[offset:offset + 8])
        chunk = raw[offset + 8:offset + 8 + length]
        if kind == 0x4E4F534A:
            doc = json.loads(chunk)
        elif kind == 0x004E4942:
            binary = chunk
        offset += 8 + length
    return doc, binary


def read_accessor(doc, binary, idx):
    """Devuelve una lista de tuplas con los valores del accessor."""
    acc = doc["accessors"][idx]
    view = doc["bufferViews"][acc["bufferView"]]
    fmt = COMP_FMT[acc["componentType"]]
    ncomp = COMP_COUNT[acc["type"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride") or COMP_SIZE[fmt] * ncomp
    out = []
    for i in range(acc["count"]):
        vals = struct.unpack_from("<%d%s" % (ncomp, fmt), binary, start + i * stride)
        out.append(vals)
    return out


# ------------------------------------------------------------------- algebra

def quat_to_mat(q):
    """Cuaternion glTF (x, y, z, w) -> matriz 3x3 como tupla de 3 filas."""
    x, y, z, w = q
    n = math.sqrt(x * x + y * y + z * z + w * w) or 1.0
    x, y, z, w = x / n, y / n, z / n, w / n
    return (
        (1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)),
        (2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)),
        (2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)),
    )


def compose(t, r, s):
    """TRS -> matriz 4x4 (lista de 4 filas de 4)."""
    m = quat_to_mat(r)
    return [
        [m[0][0] * s[0], m[0][1] * s[1], m[0][2] * s[2], t[0]],
        [m[1][0] * s[0], m[1][1] * s[1], m[1][2] * s[2], t[1]],
        [m[2][0] * s[0], m[2][1] * s[1], m[2][2] * s[2], t[2]],
        [0.0, 0.0, 0.0, 1.0],
    ]


def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)]
            for i in range(4)]


def mat_origin(m):
    return (m[0][3], m[1][3], m[2][3])


def slerp(a, b, w):
    """Interpolacion esferica entre dos cuaterniones (x, y, z, w)."""
    dot = sum(a[i] * b[i] for i in range(4))
    if dot < 0.0:
        b = tuple(-v for v in b)
        dot = -dot
    if dot > 0.9995:
        out = tuple(a[i] + (b[i] - a[i]) * w for i in range(4))
    else:
        theta = math.acos(max(-1.0, min(1.0, dot)))
        st = math.sin(theta)
        wa, wb = math.sin((1 - w) * theta) / st, math.sin(w * theta) / st
        out = tuple(a[i] * wa + b[i] * wb for i in range(4))
    n = math.sqrt(sum(v * v for v in out)) or 1.0
    return tuple(v / n for v in out)


def lerp_vec(a, b, w):
    return tuple(a[i] + (b[i] - a[i]) * w for i in range(len(a)))


# ------------------------------------------------------------- el clip en si

class Clip:
    def __init__(self, path):
        self.doc, self.binary = load_glb(path)
        self.nodes = self.doc["nodes"]
        self.name = Path(path).stem
        self.parent = {}
        for i, node in enumerate(self.nodes):
            for c in node.get("children", []):
                self.parent[c] = i
        self.tracks = {}      # nodo -> {"rotation": (tiempos, valores), ...}
        self.duration = 0.0
        if self.doc.get("animations"):
            anim = self.doc["animations"][0]
            self.clip_name = anim.get("name", "?")
            for ch in anim["channels"]:
                sampler = anim["samplers"][ch["sampler"]]
                times = [t[0] for t in read_accessor(self.doc, self.binary,
                                                     sampler["input"])]
                values = read_accessor(self.doc, self.binary, sampler["output"])
                self.tracks.setdefault(ch["target"]["node"], {})[
                    ch["target"]["path"]] = (times, values)
                self.duration = max(self.duration, times[-1] if times else 0.0)
        else:
            self.clip_name = "(sin animacion)"

    def _sample(self, node_idx, path, t, default):
        track = self.tracks.get(node_idx, {}).get(path)
        if not track:
            return default
        times, values = track
        if t <= times[0]:
            return values[0]
        if t >= times[-1]:
            return values[-1]
        hi = next(i for i, tt in enumerate(times) if tt >= t)
        lo = hi - 1
        span = times[hi] - times[lo]
        w = 0.0 if span == 0 else (t - times[lo]) / span
        if path == "rotation":
            return slerp(values[lo], values[hi], w)
        return lerp_vec(values[lo], values[hi], w)

    def local_matrix(self, node_idx, t):
        node = self.nodes[node_idx]
        base_t = tuple(node.get("translation", (0.0, 0.0, 0.0)))
        base_r = tuple(node.get("rotation", (0.0, 0.0, 0.0, 1.0)))
        base_s = tuple(node.get("scale", (1.0, 1.0, 1.0)))
        return compose(self._sample(node_idx, "translation", t, base_t),
                       self._sample(node_idx, "rotation", t, base_r),
                       self._sample(node_idx, "scale", t, base_s))

    def global_matrix(self, node_idx, t):
        m = self.local_matrix(node_idx, t)
        p = self.parent.get(node_idx)
        while p is not None:
            m = mat_mul(self.local_matrix(p, t), m)
            p = self.parent.get(p)
        return m

    def bone_indices(self):
        return [i for i, n in enumerate(self.nodes)
                if n.get("name", "").startswith("bone_")]


# ----------------------------------------------------------------- analisis

def pearson(xs, ys):
    n = len(xs)
    mx, my = sum(xs) / n, sum(ys) / n
    num = sum((xs[i] - mx) * (ys[i] - my) for i in range(n))
    dx = math.sqrt(sum((x - mx) ** 2 for x in xs))
    dy = math.sqrt(sum((y - my) ** 2 for y in ys))
    return 0.0 if dx == 0 or dy == 0 else num / (dx * dy)


def find_feet(clip):
    """Los dos huesos mas bajos en reposo, uno de cada pierna."""
    rest = [(i, mat_origin(clip.global_matrix(i, -1.0)))
            for i in clip.bone_indices()]
    rest.sort(key=lambda pair: pair[1][1])          # por altura Y
    lowest = rest[0]
    # el otro pie: el mas bajo que este separado lateralmente del primero
    for idx, pos in rest[1:]:
        dist = math.dist(pos, lowest[1])
        if dist > 0.05:
            return lowest[0], idx
    return lowest[0], rest[1][0]


def analyse(path, samples=72):
    clip = Clip(path)
    if not clip.tracks:
        print("%-22s SIN PISTAS DE ANIMACION" % clip.name)
        return None
    left, right = find_feet(clip)
    root = clip.bone_indices()[0]
    ts = [clip.duration * i / (samples - 1) for i in range(samples)]
    # Posiciones RELATIVAS A LA CADERA: en un clip de andar en el sitio el
    # cuerpo entero puede desplazarse, y lo que define la marcha es donde
    # queda cada pie respecto al cuerpo, no respecto al mundo.
    hips = [mat_origin(clip.global_matrix(root, t)) for t in ts]
    lp = [tuple(a - b for a, b in zip(mat_origin(clip.global_matrix(left, t)), h))
          for t, h in zip(ts, hips)]
    rp = [tuple(a - b for a, b in zip(mat_origin(clip.global_matrix(right, t)), h))
          for t, h in zip(ts, hips)]

    # Eje de marcha = eje horizontal (0=X, 2=Z) con mas recorrido combinado.
    def amp(points, axis):
        vals = [p[axis] for p in points]
        return max(vals) - min(vals)

    fwd = max((0, 2), key=lambda ax: amp(lp, ax) + amp(rp, ax))
    lx = [p[fwd] for p in lp]
    rx = [p[fwd] for p in rp]
    amp_l, amp_r = max(lx) - min(lx), max(rx) - min(rx)
    lift_l, lift_r = amp(lp, 1), amp(rp, 1)

    corr = pearson(lx, rx)
    diff = [lx[i] - rx[i] for i in range(samples)]
    mean_diff = sum(diff) / samples
    crossings = sum(1 for i in range(1, samples)
                    if (diff[i - 1] - mean_diff) * (diff[i] - mean_diff) < 0)
    balance = min(amp_l, amp_r) / max(amp_l, amp_r) if max(amp_l, amp_r) else 0.0

    print("== %s  [%s]  %.2f s" % (clip.name, clip.clip_name, clip.duration))
    print("   eje de marcha: %s" % "XYZ"[fwd])
    print("   recorrido pie A %.3f  pie B %.3f   (equilibrio %.2f)"
          % (amp_l, amp_r, balance))
    print("   elevacion pie A %.3f  pie B %.3f" % (lift_l, lift_r))
    print("   antifase (corr) %+.2f   cruces %d" % (corr, crossings))

    problems = []
    if max(amp_l, amp_r) < 0.05:
        problems.append("los pies apenas se mueven")
    if balance < 0.45:
        problems.append("un pie se mueve mucho mas que el otro")
    if corr > -0.3:
        problems.append("los pies NO alternan (no van en antifase)")
    if crossings < 2:
        problems.append("los pies no se adelantan mutuamente")
    verdict = "OK - ciclo de marcha valido" if not problems \
        else "NO VALE: " + "; ".join(problems)
    print("   -> %s" % verdict)
    return {"path": str(path), "corr": corr, "balance": balance,
            "amp": max(amp_l, amp_r), "crossings": crossings,
            "ok": not problems}


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    results = [analyse(p) for p in sys.argv[1:]]
    good = [r for r in results if r and r["ok"]]
    if good:
        # el mejor: mas antifase, y a igualdad mas recorrido
        best = max(good, key=lambda r: (-r["corr"], r["amp"]))
        print("\nMEJOR: %s (corr %+.2f, recorrido %.3f)"
              % (Path(best["path"]).name, best["corr"], best["amp"]))
    else:
        print("\nNinguno pasa: hay que regenerar.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
