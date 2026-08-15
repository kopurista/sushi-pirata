"""Posiciones REALES de los vertices de un .glb rigueado (pose de reposo).

Por que existe: en `pirata_fem_rig.glb` las posiciones del accessor POSITION
-la pose de BIND- no coinciden con lo que se dibuja. Medido: los triangulos de
la parte de delante de las gafas tienen su posicion de bind en y = -0.33, o
sea A LA ALTURA DE LOS PIES, y se dibujan en la cara. Por eso cualquier filtro
por coordenadas del modelo dejaba fuera justo esos triangulos, que eran el
bulto oscuro sobre el ojo que sobrevivio a media docena de intentos.

Lo que se dibuja es la pose de REPOSO del esqueleto, que es lo que calcula
esto: para cada vertice, la suma ponderada de
    (global de reposo del hueso) x (inverse bind del hueso) x posicion_bind
que es la formula de skinning de glTF.
"""
import struct

from atlas_fix import accessor, read_glb


def _mat_mul(a, b):
    """a x b, matrices 4x4 en listas de 16, ORDEN COLUMNA (como glTF)."""
    out = [0.0] * 16
    for c in range(4):
        for r in range(4):
            out[c * 4 + r] = sum(a[k * 4 + r] * b[c * 4 + k] for k in range(4))
    return out


def _trs(node):
    if "matrix" in node:
        return list(node["matrix"])
    t = node.get("translation", [0.0, 0.0, 0.0])
    r = node.get("rotation", [0.0, 0.0, 0.0, 1.0])
    s = node.get("scale", [1.0, 1.0, 1.0])
    x, y, z, w = r
    rot = [
        1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w), 0.0,
        2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w), 0.0,
        2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y), 0.0,
        0.0, 0.0, 0.0, 1.0,
    ]
    for c in range(3):
        for r_ in range(3):
            rot[c * 4 + r_] *= s[c]
    rot[12], rot[13], rot[14] = t
    return rot


def _aplica(m, p):
    return (
        m[0] * p[0] + m[4] * p[1] + m[8] * p[2] + m[12],
        m[1] * p[0] + m[5] * p[1] + m[9] * p[2] + m[13],
        m[2] * p[0] + m[6] * p[1] + m[10] * p[2] + m[14],
    )


def posiciones_de_reposo(glb_path):
    """Devuelve (posiciones_reales, uv, indices) del primer primitivo."""
    js, bin_ = read_glb(glb_path)
    prim = js["meshes"][0]["primitives"][0]
    pos = accessor(js, bin_, prim["attributes"]["POSITION"])
    uv = accessor(js, bin_, prim["attributes"]["TEXCOORD_0"])
    idx = [v[0] for v in accessor(js, bin_, prim["indices"])]
    if "skin" not in js["nodes"][_nodo_de_malla(js)] and not js.get("skins"):
        return pos, uv, idx

    # global de reposo de cada nodo
    globales = {}

    def baja(i, padre):
        m = _mat_mul(padre, _trs(js["nodes"][i]))
        globales[i] = m
        for h in js["nodes"][i].get("children", []):
            baja(h, m)

    ident = [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0]
    for raiz in js["scenes"][js.get("scene", 0)]["nodes"]:
        baja(raiz, ident)

    skin = js["skins"][0]
    ibm = accessor(js, bin_, skin["inverseBindMatrices"])
    juntas = accessor(js, bin_, prim["attributes"]["JOINTS_0"])
    pesos = accessor(js, bin_, prim["attributes"]["WEIGHTS_0"])
    piel = [_mat_mul(globales[skin["joints"][j]], list(ibm[j]))
            for j in range(len(skin["joints"]))]

    reales = []
    for v, p in enumerate(pos):
        acc = [0.0, 0.0, 0.0]
        total = 0.0
        for k in range(4):
            w = pesos[v][k]
            if w <= 0.0:
                continue
            q = _aplica(piel[int(juntas[v][k])], p)
            acc = [acc[i] + q[i] * w for i in range(3)]
            total += w
        reales.append(tuple(a / total for a in acc) if total > 0 else p)
    return reales, uv, idx


def _nodo_de_malla(js):
    for i, n in enumerate(js["nodes"]):
        if "mesh" in n:
            return i
    return 0
