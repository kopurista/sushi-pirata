"""Pinta RASGOS DE CARA (cejas, nariz y labios) en el atlas de un modelo.

    python tools/face_paint.py assets/models/chef_fem_rig.glb [--check]

Por que hace falta: `chef_fem_rig.glb` se modelo SIN CARA — un ovalo de piel
liso, sin cejas ni boca. De lejos no se notaba, pero el CARTEL DE RECOMPENSA
ensena al personaje a tamano grande y canta.

Por que se pinta asi y no recortando el atlas a mano: estos modelos vienen de
imagen->3D y su UV esta TROCEADO por triangulos, no desplegado en islas
limpias. Los vertices de la cara se reparten por todo el atlas (medido: u
0.001..0.996), asi que no hay ningun rectangulo "la cara" que abrir en un
editor. Lo que si es fiable es el camino inverso: recorrer los triangulos que
miran hacia delante en la zona de la cabeza y, para CADA TEXEL suyo, deshacer
la interpolacion para saber a que punto del modelo corresponde. Si ese punto
cae dentro de un rasgo, se pinta ese texel. Asi da igual como este empaquetado
el atlas.

Los rasgos se describen en el plano (x, y) del modelo, tomando como referencia
la PUNTA DE LA NARIZ, que se localiza sola: el vertice mas adelantado del eje
en la zona alta. Asi los mismos numeros valen aunque el modelo cambie de escala.
"""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from atlas_fix import accessor, read_glb, texels_of  # noqa: E402
from PIL import Image  # noqa: E402

## Zona de la cabeza (fraccion del alto, desde arriba) y cuanto tiene que estar
## adelantado un triangulo (fraccion del z maximo) para contar como "cara".
HEAD_FRAC = 0.25
FRONT_Z = 0.35
## Franjas en las que se corta la piel para medir la cara, y ancho minimo (en
## fraccion del maximo) para que una franja cuente como cara y no como cuello.
BANDS = 12
FACE_MIN_W = 0.60

## Colores de los rasgos, en el mismo tono tostado del contorno del juego.
CEJA = (86, 56, 38)
LABIO = (150, 84, 74)
NARIZ = (152, 102, 80)
## Sombra de los lados de la nariz: mas floja que la de las aletas, porque su
## trabajo es insinuar el volumen, no dibujar un trazo.
NARIZ_LADO = (178, 124, 100)

## Rasgos, en unidades de MODELO y relativos a la punta de la nariz:
##   (dx, dy, ancho, alto, color)  -> elipse centrada ahi
## Un pixel de piel: asi se distingue la CARA del gorro y del pelo.
def es_piel(c):
    r, g, b = c
    return r > 150 and 80 < g < 200 and 60 < b < 180 and r > g > b


## Rasgos en PROPORCIONES DE LA CARA, no en unidades del modelo:
##   dx  -> fraccion del ancho de la cara (0 = el eje)
##   y   -> altura dentro de la cara (0 = barbilla, 1 = nacimiento del pelo)
##   w,h -> fracciones del ancho de la cara
##
## Van en proporciones porque los dos primeros intentos fallaron justo ahi: con
## distancias absolutas colgadas de "la punta de la nariz" las cejas acabaron
## pintadas EN EL GORRO. Lo que se detectaba como nariz era la FRENTE (en una
## cabeza low poly sobresale lo mismo), y la cara util no mide lo que parece:
## medida, va de y=0.355 a y=0.405 —cinco centesimas— sobre un personaje de 1.0.
## El ORDEN importa: el primer rasgo que atrapa un texel se lo queda (hay un
## `break`), asi que los trazos pequenos y oscuros van ANTES que las sombras
## grandes con las que se solapan.
RASGOS = [
    # Cejas, PEGADAS al nacimiento del pelo. La altura PASA DE 1.0 a proposito:
    # la banda que se mide acaba donde la piel se ESTRECHA (y=0.404), pero la
    # frente sigue subiendo un poco mas por los lados del flequillo. Ojo con
    # pasarse: por encima de ~1.10 la piel se queda en una tira de 0.02 de
    # ancho y las cejas ya no caen sobre ella (se quedan sin pintar).
    (-0.20, 1.05, 0.145, 0.026, CEJA),
    (0.20, 1.05, 0.145, 0.026, CEJA),
    # Aletas de la nariz.
    (-0.07, 0.50, 0.04, 0.035, NARIZ),
    (0.07, 0.50, 0.04, 0.035, NARIZ),
    # Sombras LATERALES del caballete: son las que hacen que se lea como una
    # nariz y no como dos manchas sueltas. Van altas y estrechas.
    (-0.055, 0.60, 0.026, 0.095, NARIZ_LADO),
    (0.055, 0.60, 0.026, 0.095, NARIZ_LADO),
    # Labios.
    (0.0, 0.265, 0.14, 0.045, LABIO),
]


def bary(p, a, b, c):
    """Pesos baricentricos de p en el triangulo (a, b, c), en 2D."""
    v0 = (b[0] - a[0], b[1] - a[1])
    v1 = (c[0] - a[0], c[1] - a[1])
    v2 = (p[0] - a[0], p[1] - a[1])
    den = v0[0] * v1[1] - v1[0] * v0[1]
    if abs(den) < 1e-12:
        return None
    v = (v2[0] * v1[1] - v1[0] * v2[1]) / den
    w = (v0[0] * v2[1] - v2[0] * v0[1]) / den
    u = 1.0 - v - w
    return u, v, w


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    check = "--check" in sys.argv
    if not args:
        print(__doc__)
        return 1
    glb = Path(args[0])
    js, bin_ = read_glb(glb)
    tex = glb.with_name(glb.stem + "_0.png")
    im = Image.open(tex).convert("RGB")
    W, H = im.size
    px = im.load()

    prim = js["meshes"][0]["primitives"][0]
    pos = accessor(js, bin_, prim["attributes"]["POSITION"])
    uv = accessor(js, bin_, prim["attributes"]["TEXCOORD_0"])
    idx = [v[0] for v in accessor(js, bin_, prim["indices"])]

    ys = [p[1] for p in pos]
    y1 = max(ys)
    alto = y1 - min(ys)
    zmax = max(p[2] for p in pos)
    corte_y = y1 - alto * HEAD_FRAC

    # DONDE ESTA LA CARA: se mide, no se supone. Se cogen los vertices de PIEL
    # de la mitad delantera de la cabeza y se mira su ancho por franjas: el
    # cuello es estrecho (0.047 medido) y la cara ancha (0.107), asi que
    # quedarse con las franjas anchas deja la cara sola, sin cuello ni frente
    # tapada por el gorro.
    piel = []
    for i in range(len(pos)):
        if pos[i][1] < corte_y or pos[i][2] < zmax * FRONT_Z:
            continue
        u, v = uv[i]
        qx = min(max(int(u * W), 0), W - 1)
        qy = min(max(int(v * H), 0), H - 1)
        if es_piel(px[qx, qy]):
            piel.append(i)
    if len(piel) < 12:
        print("no encuentro piel en la cara de %s" % glb.name)
        return 1
    lo = min(pos[i][1] for i in piel)
    hi = max(pos[i][1] for i in piel)
    franjas = []
    for k in range(BANDS):
        a = lo + (hi - lo) * k / BANDS
        b = lo + (hi - lo) * (k + 1) / BANDS
        sub = [pos[i][0] for i in piel if a <= pos[i][1] < b]
        franjas.append((a, b, (max(sub) - min(sub)) if sub else 0.0))
    ancho = max(f[2] for f in franjas)
    buenas = [f for f in franjas if f[2] >= ancho * FACE_MIN_W]
    barbilla = min(f[0] for f in buenas)
    frente = max(f[1] for f in buenas)
    cara_h = frente - barbilla
    print("%s: cara y %.4f..%.4f (alto %.4f, ancho %.4f)" % (
        glb.name, barbilla, frente, cara_h, ancho))

    pintados = 0
    for t in range(0, len(idx), 3):
        a, b, c = idx[t], idx[t + 1], idx[t + 2]
        if min(pos[a][1], pos[b][1], pos[c][1]) < corte_y:
            continue
        # Solo la MITAD DE DELANTE de la cabeza, o salen cejas en la nuca. El
        # filtro va por POSICION y no por normal: estos .glb no traen el
        # atributo NORMAL (vienen de imagen->3D), y como la nuca esta en z
        # negativo basta con exigir que el triangulo este adelantado.
        if max(pos[a][2], pos[b][2], pos[c][2]) < zmax * FRONT_Z:
            continue
        ta, tb, tc = uv[a], uv[b], uv[c]
        for (qx, qy) in texels_of([ta, tb, tc], W, H):
            # Del texel a su punto del modelo, deshaciendo la interpolacion.
            p = ((qx + 0.5) / W, (qy + 0.5) / H)
            w = bary(p, ta, tb, tc)
            if w is None:
                continue
            u_, v_, w_ = w
            if u_ < -0.02 or v_ < -0.02 or w_ < -0.02:
                continue
            mx = u_ * pos[a][0] + v_ * pos[b][0] + w_ * pos[c][0]
            my = u_ * pos[a][1] + v_ * pos[b][1] + w_ * pos[c][1]
            for fx, fy, fw, fh, color in RASGOS:
                ex = (mx - fx * ancho) / (fw * ancho)
                ey = (my - (barbilla + fy * cara_h)) / (fh * ancho)
                d = ex * ex + ey * ey
                if d > 1.0:
                    continue
                # Borde suave: el rasgo se difumina en el ultimo tercio para
                # que no salga un pegote con escalones.
                k = min(1.0, (1.0 - math.sqrt(d)) * 3.0)
                if not check:
                    old = px[qx, qy]
                    px[qx, qy] = tuple(
                        int(old[j] + (color[j] - old[j]) * k) for j in range(3))
                pintados += 1
                break

    print("  texeles %s: %d" % ("que se pintarian" if check else "pintados",
                                pintados))
    if not check:
        im.save(tex)
        print("  guardado %s" % tex.name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
