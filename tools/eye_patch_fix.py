"""Convierte las GAFAS DE SOL de `pirata_fem_rig.glb` en UN SOLO PARCHE.

Por que hace falta: el pirata masculino lleva bandana + UN parche en un ojo,
con el otro bien visible. La generacion de la variante femenina le puso un
antifaz simetrico -gafas oscuras tapando LOS DOS ojos-, que se lee como "un
parche en cada ojo" y no como el mismo diseno en version femenina.

LAS TRES DECISIONES QUE COSTARON 16 RONDAS. No volver a discutirlas:

1. QUE es gafas se decide POR COLOR, TEXEL A TEXEL. El navy de la lente
   (oscuro con el azul al mando) y el gris de la montura no se parecen a nada
   mas del personaje: el pelo granate tiene r >> b y la chaqueta verde-azulada
   tiene g >= b. Comprobado tinendo de magenta todo lo que pasa el filtro:
   sale EXACTAMENTE la silueta de las gafas.
   Texel a texel y NO por el color medio del triangulo: con la media, los
   triangulos del borde -mitad lente, mitad piel- no llegaban al listo y
   dejaban un BULTO oscuro justo encima del ojo que sobrevivio a media docena
   de intentos.

2. DE QUE LADO cae cada texel se decide por la POSICION DEL TRIANGULO, y las
   lentes se separan de las patillas por su z: medido por histograma, las
   lentes se apinan en z 0.06..0.12 y las patillas caen a 0.02 y por debajo.

3. NO se puede usar el render para nada de esto. Se intento decodificar un
   render con la textura sustituida por un gradiente que codificara las
   coordenadas del atlas, y no vale: los .glb del juego llevan sus texturas en
   BASIS (compress/mode=4, con perdida), asi que el gradiente llega machacado
   y el mapa texel -> pantalla sale con ruido.

Y las gafas SON la superficie de la cabeza: al borrar sus triangulos del .glb
se ve el fondo a traves, no una cara debajo. Por eso hay que repintar.

El reparto: la lente IZQUIERDA pasa a piel, y encima van ojo y ceja. La lente
derecha y las dos patillas se quedan negras: la lente hace de parche y las
patillas de correa alrededor de la cabeza, que es justo lo del masculino.

Uso:  python tools/eye_patch_fix.py [--check]
      GODOT --headless --import .          # OBLIGATORIO tras editar el PNG
      GODOT --path . res://tools/pirata_fem_check.tscn
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from atlas_fix import texels_of  # noqa: E402
from PIL import Image  # noqa: E402
from skin_pose import posiciones_de_reposo  # noqa: E402

GLB = Path("assets/models/pirata_fem_rig.glb")
TEX = Path("assets/models/pirata_fem_rig_0.png")
ORIG = Path("assets/models/pirata_fem_rig_0.png.antes_del_parche")

## Solo de la mitad de arriba del personaje para arriba: abajo hay cinturon y
## botas que darian el mismo color.
HEAD_FRAC = 0.55
## Frontera lente / patilla, del histograma de z.
LENS_Z = 0.04

PIEL_FALLBACK = (196, 143, 113)
OJO_COLOR = (34, 24, 22)

CEJA = (58, 32, 22)

## Ojo y ceja EN FRACCIONES DEL HUECO que deja la lente, medido sobre los
## TEXELS de verdad (por percentiles) y no sobre los vertices: unos pocos
## triangulos alargados estiraban el bbox y el ojo caia en una zona sin un
## solo texel, con lo que salia con 0 texels pintados.
##
## EL OJO ES OSCURO Y MACIZO, sin blanco ni pupila. Se probo con esclerotica
## blanca + pupila y NO vale: buena parte de los texels de la lente estan en
## pliegues que no se ven de frente, asi que el ovalo salia como una MEDIA
## LUNA blanca con la pupila descolgada por abajo. Una mancha oscura aguanta
## esa distorsion sin cantar -y es lo que hacen los personajes low poly del
## juego-, mientras que el blanco sobre piel la deja a la vista.
##
## ESTOS NUMEROS ESTAN AFINADOS A MANO CONTRA EL RENDER, no son libres: la
## superficie de la lente se pliega, asi que hay zonas suyas que no se ven de
## frente. Movido a (0.52, 0.50) el ovalo cae en el pliegue y el ojo se
## deshace en MOTAS sueltas. Si hay que tocarlos, render tras cada cambio.
OJO_AT = (0.50, 0.44)
OJO_R = (0.50, 0.44)
PUPILA_R = (0.0, 0.0)   # sin pupila aparte
CEJA_AT = (0.44, 0.93)
CEJA_R = (0.95, 0.17)


def bary(p, a, b, c):
    v0 = (b[0] - a[0], b[1] - a[1])
    v1 = (c[0] - a[0], c[1] - a[1])
    v2 = (p[0] - a[0], p[1] - a[1])
    den = v0[0] * v1[1] - v1[0] * v0[1]
    if abs(den) < 1e-12:
        return None
    v = (v2[0] * v1[1] - v1[0] * v2[1]) / den
    w = (v0[0] * v2[1] - v2[0] * v0[1]) / den
    return 1.0 - v - w, v, w


def es_gafas(c):
    r, g, b = c
    avg = (r + g + b) / 3.0
    if avg < 95 and b >= g and b >= r - 4:
        return True                      # navy / negro de la lente
    if 85 < avg < 205 and max(c) - min(c) < 30:
        return True                      # gris metalico de la montura
    if avg < 45 and max(c) - min(c) < 15:
        return True                      # negro NEUTRO del cristal de delante
    return False                         # (el pelo, (38,6,15), es rojizo: 32)


def es_piel(c):
    r, g, b = c
    return r > 150 and 80 < g < 200 and 60 < b < 180 and r > g > b


def dentro(cx, cy, rx, ry, x, y):
    dx, dy = (x - cx) / rx, (y - cy) / ry
    return dx * dx + dy * dy <= 1.0


def main():
    check = "--check" in sys.argv
    im = Image.open(ORIG if ORIG.exists() else TEX).convert("RGB")
    W, H = im.size
    px = im.load()

    # POSICIONES DE REPOSO, no las del accessor POSITION: en este modelo la
    # pose de bind MIENTE -los triangulos de delante de las gafas la tienen a
    # la altura de los PIES (y = -0.33) y se dibujan en la cara-, y por eso
    # todos los filtros geometricos anteriores los dejaban fuera. Con el
    # skinning aplicado caen donde se ven, en (-0.055, 0.402, 0.094).
    pos, uv, idx = posiciones_de_reposo(GLB)
    y_top = max(p[1] for p in pos)

    # --- texels de la LENTE IZQUIERDA, con su punto del modelo ---
    celdas = []
    piel_cerca = []
    prohibido = set()
    for t in range(0, len(idx), 3):
        a, b, c = idx[t], idx[t + 1], idx[t + 2]
        cy = (pos[a][1] + pos[b][1] + pos[c][1]) / 3.0
        if cy <= y_top * HEAD_FRAC:
            continue
        cx = (pos[a][0] + pos[b][0] + pos[c][0]) / 3.0
        cz = (pos[a][2] + pos[b][2] + pos[c][2]) / 3.0
        if cz < LENS_Z:
            continue                      # patilla: es la correa, se queda
        izquierda = cx < 0.0
        ta, tb, tc = uv[a], uv[b], uv[c]
        for (qx, qy) in texels_of([ta, tb, tc], W, H):
            col = px[qx, qy]
            if not izquierda:
                if es_gafas(col):
                    prohibido.add((qx, qy))   # parche: el halo no puede entrar
                continue
            if es_piel(col):
                piel_cerca.append(col)
                continue
            if not es_gafas(col):
                continue
            w = bary(((qx + 0.5) / W, (qy + 0.5) / H), ta, tb, tc)
            if w is None:
                celdas.append((qx, qy, None, None))
                continue
            u_, v_, w_ = w
            celdas.append((qx, qy,
                           u_ * pos[a][0] + v_ * pos[b][0] + w_ * pos[c][0],
                           u_ * pos[a][1] + v_ * pos[b][1] + w_ * pos[c][1]))
    print("texels de la lente izquierda:", len(celdas))
    if not celdas:
        print("ERROR: no se ha reconocido la lente izquierda")
        return 1

    piel = (PIEL_FALLBACK if not piel_cerca else
            tuple(sum(c[i] for c in piel_cerca) // len(piel_cerca) for i in range(3)))
    print("piel medida junto a la lente:", piel, "(%d muestras)" % len(piel_cerca))

    def pct(v, f):
        v = sorted(v)
        return v[min(len(v) - 1, int(len(v) * f))]

    mxs = [c[2] for c in celdas if c[2] is not None]
    mys = [c[3] for c in celdas if c[3] is not None]
    x0, x1 = pct(mxs, 0.02), pct(mxs, 0.98)
    y0, y1 = pct(mys, 0.02), pct(mys, 0.98)
    print("hueco de la lente: x %.4f..%.4f  y %.4f..%.4f" % (x0, x1, y0, y1))

    rx, ry = (x1 - x0) / 2.0, (y1 - y0) / 2.0
    ecx, ecy = x0 + (x1 - x0) * OJO_AT[0], y0 + (y1 - y0) * OJO_AT[1]
    bcx, bcy = x0 + (x1 - x0) * CEJA_AT[0], y0 + (y1 - y0) * CEJA_AT[1]

    pintados = {"piel": 0, "ceja": 0, "ojo": 0, "halo": 0}
    tocados = set()
    for (qx, qy, mx, my) in celdas:
        tocados.add((qx, qy))
        col, clase = piel, "piel"
        if mx is not None:
            if dentro(ecx, ecy, rx * OJO_R[0], ry * OJO_R[1], mx, my):
                col, clase = OJO_COLOR, "ojo"
            elif dentro(bcx, bcy, rx * CEJA_R[0], ry * CEJA_R[1], mx, my):
                col, clase = CEJA, "ceja"
        pintados[clase] += 1
        if not check:
            px[qx, qy] = col

    # HALO: el atlas lleva relleno entre islas, y el modelo se ve PEQUENO, asi
    # que Godot muestrea un MIPMAP reducido que promedia texels de bastante mas
    # alla del borde de la isla. Con un halo de 3 texels el bulto seguia
    # saliendo aunque la isla estuviera pintada entera: a nivel 3 de mipmap, un
    # texel de pantalla promedia ocho de textura. De ahi los 14 pasos.
    # `prohibido` son los texels del PARCHE: sin esa valla el halo se colaba
    # por el atlas y le comia un mordisco.
    for _ in range(14):
        borde = [q2 for (qx, qy) in tocados
                 for q2 in ((qx - 1, qy), (qx + 1, qy), (qx, qy - 1), (qx, qy + 1))
                 if q2 not in tocados and q2 not in prohibido
                 and 0 <= q2[0] < W and 0 <= q2[1] < H and es_gafas(px[q2])]
        for q2 in borde:
            tocados.add(q2)
            pintados["halo"] += 1
            if not check:
                px[q2] = piel

    print("texeles %s:" % ("que se pintarian" if check else "pintados"), pintados)
    if not check:
        im.save(TEX)
        print("guardado", TEX.name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
