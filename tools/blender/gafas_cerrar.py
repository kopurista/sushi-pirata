# CIERRA LOS AROS DE LAS GAFAS de un personaje al que Meshy se los dejo a
# medias (le paso a Miku: el aro derecho abierto por fuera y el izquierdo por
# abajo). Los aros son GEOMETRIA en relieve, no pintura, asi que repintar la
# textura no arregla nada: hay que poner el aro que falta.
#
# Se hace MIDIENDO, no a ojo: se buscan los vertices cuyo texel es del color
# del aro, se parten en izquierdo y derecho, y a cada nube se le ajusta una
# CIRCUNFERENCIA por minimos cuadrados en el plano de la cara. Con ese centro,
# ese radio y el grosor medido se crea un toro completo del mismo material.
#
#   blender --background --python tools/blender/gafas_cerrar.py -- <in.glb> <out.glb> [diag]
import bpy, sys, os, math
import numpy as np
from mathutils import Vector, Matrix

a = sys.argv[sys.argv.index("--") + 1:]
SRC, DEST = os.path.abspath(a[0]), os.path.abspath(a[1])
DIAG = len(a) > 2 and a[2] == "diag"
# el aro es MARRON OSCURO: mas oscuro que la piel y mas CALIDO que el pelo
LUM_MAX = float(os.environ.get("ARO_LUM", 0.30))
CROMA_MIN = float(os.environ.get("ARO_CROMA", 0.10))
GROSOR_K = float(os.environ.get("ARO_GROSOR", 0.62))
ADELANTE = float(os.environ.get("ARO_ADELANTE", 0.0))   # fraccion del radio

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
sc = bpy.context.scene
malla = max((o for o in sc.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
arms = [o for o in sc.objects if o.type == "ARMATURE"]
me = malla.data
me.calc_loop_triangles()
M = malla.matrix_world
V = np.array([v.co for v in me.vertices], dtype=np.float64)
lo, hi = V.min(axis=0), V.max(axis=0)
alto = float(hi[2] - lo[2])

img = next((i for i in bpy.data.images if i.size[0] > 8), None)
W, H = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[..., :3]
uv = me.uv_layers.active.data

# color por VERTICE (mediana de sus loops) y material de cada uno
col = np.zeros((len(V), 3), dtype=np.float64)
cnt = np.zeros(len(V))
uvv = np.zeros((len(V), 2))
mat_de = np.zeros(len(V), dtype=int)
for tri in me.loop_triangles:
    for vi, li in zip(tri.vertices, tri.loops):
        u, w = uv[li].uv
        col[vi] += px[int(w * (H - 1)) % H, int(u * (W - 1)) % W]
        uvv[vi] = (u, w)
        mat_de[vi] = tri.material_index
        cnt[vi] += 1
ok = cnt > 0
col[ok] /= cnt[ok][:, None]
lum = col.mean(axis=1)
croma = col.max(axis=1) - col.min(axis=1)

# la cara: mitad alta del modelo y mirando hacia delante (-Y)
nor = np.array([v.normal for v in me.vertices], dtype=np.float64)
cara = ok & (V[:, 2] > lo[2] + 0.60 * alto) & (nor[:, 1] < -0.05)
# EL ARO ES MARRON ROJIZO: mas oscuro que la piel y mucho mas CALIDO que el
# pelo (medido con k-means sobre la cara de Miku: aro (0.24, 0.09, 0.06) con
# r-b 0.18, pelo (0.045, 0.029, 0.052) con r-b -0.007).
aro = cara & (lum < LUM_MAX) & ((col[:, 0] - col[:, 2]) > CROMA_MIN) & (col[:, 0] > 0.12)
# y se acota a la BANDA DE LOS OJOS, que es donde esta la masa de esos texeles
if aro.sum() > 200:
    zc = float(np.median(V[aro][:, 2]))
    banda = aro & (np.abs(V[:, 2] - zc) < 0.075 * alto)
    if banda.sum() > 120:
        aro = banda
print("[gafas] vertices de aro: %d (de %d en la cara)" % (aro.sum(), cara.sum()))
if aro.sum() < 60:
    sys.exit("[gafas] no se encuentran los aros; ajusta ARO_LUM/ARO_CROMA")

def _fit(P):
    x, z = P[:, 0], P[:, 2]
    A = np.stack([x, z, np.ones(len(x))], axis=1)
    b = x ** 2 + z ** 2
    c = np.linalg.lstsq(A, b, rcond=None)[0]
    cx, cz = c[0] / 2.0, c[1] / 2.0
    r = math.sqrt(max(c[2] + cx * cx + cz * cz, 1e-9))
    return cx, cz, r


def ajusta(P):
    """Circunferencia por minimos cuadrados, REPESADA.

    Un ajuste a secas no vale: dentro de cada aro estan el OJO y la CEJA, que
    tambien son oscuros, y su mancha en el centro tira del circulo y lo agranda.
    Se ajusta, se tira lo que no cae cerca del aro y se vuelve a ajustar.
    """
    Q = P
    cx, cz, r = _fit(Q)
    for _ in range(5):
        d = np.sqrt((Q[:, 0] - cx) ** 2 + (Q[:, 2] - cz) ** 2)
        m = np.abs(d - r) < 0.35 * r
        if m.sum() < 25:
            break
        Q = Q[m]
        cx, cz, r = _fit(Q)
    d = np.sqrt((Q[:, 0] - cx) ** 2 + (Q[:, 2] - cz) ** 2)
    return cx, cz, r, float(np.percentile(np.abs(d - r), 80)), len(Q)

nuevos = []
ajustados = []
for lado, sel in (("L", aro & (V[:, 0] > 0)), ("R", aro & (V[:, 0] < 0))):
    P = V[sel]
    if len(P) < 30:
        print("[gafas] %s: solo %d vertices" % (lado, len(P)))
        continue
    cx, cz, r, gro, n2 = ajusta(P)
    y = float(np.percentile(P[:, 1], 15))       # lo mas adelantado del aro
    print("[gafas] %s: n=%d->%d centro (%.4f, %.4f) radio %.4f grosor %.4f y %.4f"
          % (lado, len(P), n2, cx, cz, r, gro, y))
    if DIAG:
        continue
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=max(gro * GROSOR_K, r * 0.05),
                                     major_segments=48, minor_segments=12,
                                     location=(cx, y - r * ADELANTE, cz),
                                     rotation=(math.radians(90), 0, 0))
    o = bpy.context.object
    o.name = "Aro_%s" % lado
    bpy.ops.object.shade_smooth()
    # material y UV del propio aro, para que sea del mismo color
    idx = np.nonzero(sel)[0]
    mi = int(np.bincount(mat_de[idx]).argmax())
    o.data.materials.append(me.materials[mi])
    capa = o.data.uv_layers.active or o.data.uv_layers.new(name="UVMap")
    # el texel MEDIANO del aro (el mas oscuro es el borde en sombra y salia
    # casi negro, mucho mas duro que el marron del dibujo)
    d_idx = np.sqrt((V[idx, 0] - cx) ** 2 + (V[idx, 2] - cz) ** 2)
    # LA UV SALE DE LA PATILLA, no del aro: el aro viejo se repinta de piel
    # justo despues, y si el toro apuntaba a uno de esos texeles se quedaba
    # color carne (paso: un aro marron y el otro del color de la cara).
    buenos = idx[d_idx > 1.45 * r]
    if len(buenos) < 10:
        buenos = idx[np.abs(d_idx - r) < 0.35 * r]
    if len(buenos) < 10:
        buenos = idx
    med_c = np.median(col[buenos], axis=0)
    j = buenos[int(np.argmin(np.linalg.norm(col[buenos] - med_c, axis=1)))]
    for d in capa.data:
        d.uv = (float(uvv[j][0]), float(uvv[j][1]))
    g = o.vertex_groups.new(name="Head")
    g.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
    nuevos.append(o)
    ajustados.append((sel, cx, cz, r))

if DIAG:
    sys.exit(0)

# LOS RESTOS DEL ARO ROTO SE APLANAN Y SE REPINTAN. Meshy dejo dentro de cada
# cristal un arco suelto —lo que le sobro del aro— y con el aro nuevo puesto se
# lee como una raya marron dentro del ojo. Se hunde su relieve suavizando, y
# sus texeles se pintan con la piel de alrededor.
# LA LIMPIEZA VA APAGADA POR DEFECTO. Se intento tres veces con margenes
# distintos y las tres le comio algo a la cara: con la corona ancha, los ojos
# y las cejas (son del MISMO marron que el aro y estan justo ahi); con la
# estrecha, quedan manchas grises dentro del cristal. Con el aro nuevo puesto,
# lo que queda del roto se lee como un reflejo en el cristal y no molesta.
# LA LIMPIEZA VA APAGADA. Se intento cuatro veces y ninguna sale limpia: el
# OJO y la CEJA son del MISMO marron que el aro y estan justo ahi, asi que
# ensanchando la zona se los come y estrechandola no llega a los restos. Queda
# como esta, y lo que sobra del aro roto se disimula solo cuando el aro nuevo
# esta puesto.
if ajustados and os.environ.get("ARO_LIMPIAR", "0") != "0":
    sobra = np.zeros(len(V), dtype=bool)
    for sel, cx, cz, r in ajustados:
        idx = np.nonzero(sel)[0]
        d = np.sqrt((V[idx, 0] - cx) ** 2 + (V[idx, 2] - cz) ** 2)
        # EL OJO ES DEL MISMO MARRON QUE EL ARO y vive en el CENTRO del
        # cristal, asi que "lo que no cae en el aro" se lo llevaba por delante:
        # solo cuenta como resto lo que esta en la corona, lejos del ojo.
        # y tampoco entra lo que queda POR ENCIMA del aro, que son las CEJAS:
        # tambien son marron oscuro y se las llevaba por delante.
        arriba = V[idx, 2] > cz + 0.72 * r
        # SE BORRA EL ARO VIEJO ENTERO dentro del cristal: con el toro nuevo
        # puesto, cualquier resto suyo se lee como una raya en el ojo. Solo se
        # respetan el OJO (mismo marron, en el centro) y la CEJA (arriba).
        # LOS MARGENES SON DELICADOS: bajando de 0.52r el filtro entra en el
        # ojo y lo deja con manchas grises.
        sobra[idx[(d > 0.52 * r) & (d < 1.30 * r) & (~arriba)]] = True
    print("[gafas] restos que se aplanan: %d vertices" % sobra.sum())
    if sobra.any():
        vecinos = [[] for _ in range(len(V))]
        for e in me.edges:
            x_, y_ = e.vertices
            vecinos[x_].append(y_)
            vecinos[y_].append(x_)
        Vv = V.copy()
        for _ in range(14):
            nuevo = Vv.copy()
            for vi in np.nonzero(sobra)[0]:
                vv = vecinos[vi]
                if vv:
                    nuevo[vi] = Vv[vi] + (Vv[vv].mean(axis=0) - Vv[vi]) * 0.65
            Vv = nuevo
        for i, v in enumerate(me.vertices):
            v.co = Vector(Vv[i])
        # Y LA TEXTURA: solo los texeles que DE VERDAD son del aro y que caen
        # DENTRO de esos triangulos. Pintar la caja envolvente de cada
        # triangulo arraso con cejas, ojos y flequillo (57.588 texeles), asi
        # que va con prueba baricentrica y con el mismo filtro de color que
        # encontro el aro.
        piel = np.median(col[cara & (lum > 0.45) & ((col[:, 0] - col[:, 2]) > 0.05)], axis=0)
        pix = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
        sset = set(int(i) for i in np.nonzero(sobra)[0])
        n = 0
        for tri in me.loop_triangles:
            if sum(1 for vi in tri.vertices if vi in sset) < 2:
                continue
            uvs = np.array([uv[li].uv for li in tri.loops], dtype=np.float64) * [W, H]
            x0, y0 = np.floor(uvs.min(axis=0)).astype(int)
            x1, y1 = np.ceil(uvs.max(axis=0)).astype(int)
            x0 = max(x0, 0); y0 = max(y0, 0); x1 = min(x1, W - 1); y1 = min(y1, H - 1)
            if x1 < x0 or y1 < y0:
                continue
            xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            (ax, ay), (bx, by), (cx2, cy2) = uvs
            det = (bx - ax) * (cy2 - ay) - (cx2 - ax) * (by - ay)
            if abs(det) < 1e-9:
                continue
            l1 = ((bx - xs) * (cy2 - ys) - (cx2 - xs) * (by - ys)) / det
            l2 = ((cx2 - xs) * (ay - ys) - (ax - xs) * (cy2 - ys)) / det
            l3 = 1.0 - l1 - l2
            ins = (l1 >= -0.002) & (l2 >= -0.002) & (l3 >= -0.002)
            if not ins.any():
                continue
            yy, xx = np.nonzero(ins)
            YY = y0 + yy; XX = x0 + xx
            c3 = pix[YY, XX, :3]
            m = ((c3[:, 0] - c3[:, 2]) > CROMA_MIN) & (c3.mean(axis=1) < LUM_MAX)
            if not m.any():
                continue
            pix[YY[m], XX[m], :3] = piel
            n += int(m.sum())
        img.pixels = pix.ravel().tolist()
        img.pack()
        print("[gafas] texeles repintados de piel: %d (color %s)"
              % (n, tuple(round(float(c), 3) for c in piel)))

bpy.ops.object.select_all(action="DESELECT")
for o in nuevos:
    o.select_set(True)
malla.select_set(True)
bpy.context.view_layer.objects.active = malla
if nuevos:
    bpy.ops.object.join()
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=DEST, export_format="GLB",
                          export_apply=False, export_animations=False)
print("[gafas] exportado", DEST)
