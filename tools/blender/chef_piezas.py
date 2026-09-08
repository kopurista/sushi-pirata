# LAS PIEZAS INTERCAMBIABLES DEL CHEF (ojos y nariz).
#
# El chef es un personaje PERSONALIZABLE: 4 tonos de piel, 11 peinados x 5
# colores, 2 tamanos de ojo, 3 de nariz, gafas si/no y barba/bigote. Generar un
# modelo por combinacion serian casi 10.000, asi que el cuerpo va CALVO y con la
# CARA LISA y cada rasgo es una pieza suelta que el juego cuelga del hueso
# `Head` con un BoneAttachment3D.
#
# Aqui se hacen las que son geometria pura y no hay que generar: los OJOS (dos
# tamanos) y la NARIZ (tres). Las medidas salen de la propia cara con un RAYO,
# igual que en preparar_personaje.py: se pregunta a que profundidad esta la cara
# en ese punto en vez de estimarla.
#
#   blender --background --python tools/blender/chef_piezas.py -- <cuerpo.glb> <carpeta>
import bpy, sys, os
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
SRC = os.path.abspath(a[0])
OUT = os.path.abspath(a[1])
os.makedirs(OUT, exist_ok=True)

# Fracciones del ALTO DE LA CABEZA, como en preparar_personaje.py.
# MEDIDO CONTRA EL REPARTO, no puesto a ojo: con la misma camara y los dos
# modelos normalizados a 1.0 de alto, el ojo del grumete mide 15 x 34 px con 70
# de separacion y su cara 200 de ancho; los del chef salian 28 x 65 con 116 de
# separacion sobre una cara de 270. O sea 1.4 veces mas grandes y 1.23 mas
# separados de lo que toca — por eso "no tenian la forma del resto".
# LOS OJOS YA NO SE GENERAN AQUI (decidido por el usuario): el chef los trae
# del concepto, como el resto del reparto, y son UNOS SOLOS. Se intento
# hacerlos por codigo en dos tamanos y no salia: el ojo del reparto es un HUECO
# —esta metido en su cuenca, con el borde de piel alrededor— y un casquete
# negro pegado a una cara lisa se lee como una pegatina por mucho que se le
# afine el tamano. Con la cuenca tallada tampoco casaba del todo, y el precio
# era un cuerpo por tamano de ojo (la cuenca es geometria del cuerpo).
# El bloque se queda comentado por si algun dia hace falta.
OJOS = {}
# EL OJO DEL REPARTO ES UN HUECO, NO UN BULTO: mirando de cerca, el del grumete
# esta HUNDIDO en la cara, con su borde de piel alrededor y el negro dentro,
# plano y parejo. El del chef salia como un huevo negro PEGADO por fuera, que
# coge un degradado gris enorme y se lee como otra cosa. Se arregla con tres
# numeros: poca profundidad (el casquete que asoma es casi plano), muy hundido,
# y material MATE (con brillo, la curvatura se nota).
PROF = 0.55          # grosor del ojo, en fraccion de su semieje horizontal
# OJO CON ESTE NUMERO: es fraccion de la PROFUNDIDAD del ojo, que ya es fina
# (ra * PROF). A 0.88 el cristal se metia entero en la carne y la cara salia sin
# ojos; con la cuenca ya hecha, basta con dejarlo casi a ras.
HUNDIDO = -0.10       # cuanto se mete en la cara, en fraccion de su PROFUNDIDAD
NARICES = {"pequena": 0.052, "media": 0.070, "grande": 0.092}   # radio / alto cabeza
NARIZ_BASE = 0.700   # donde esta la nariz que trae el modelo, para aplanarla
NARIZ_BAJO = 0.760   # por debajo de la coronilla: la nariz va DEBAJO de los
                     # ojos (0.575), no entre ellos
NARIZ_SALE = 0.55    # cuanto sobresale, en fraccion de su radio
CUENCA = 0.40        # cuanto se hunde la piel del ojo, en fraccion de su ancho
CEJA_SOBRE = 0.055   # por encima del BORDE ALTO del ojo, en alto de cabeza
CEJA_LARGO = 0.085   # semieje largo de la ceja
CEJA_GRUESO = 0.017  # semieje corto
CEJA_ANGULO = -0.10  # inclinacion hacia fuera, en radianes
CEJA_ARCO = 1.25     # cuanto sube el centro de la ceja, en gruesos
CEJA_PUNTA = 0.75    # cuanto se afila hacia las puntas

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
sc = bpy.context.scene
malla = max((o for o in sc.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
M = malla.matrix_world
Minv = M.inverted()
vs = [M @ v.co for v in malla.data.vertices]
lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
alto = hi.z - lo.z
# LA CABEZA es lo que hay por encima del CUELLO, y el cuello se busca: es la
# fila mas estrecha de la mitad alta de la silueta.
anchos = []
for k in range(30, 62):
    z = lo.z + alto * k / 100.0
    banda = [v for v in vs if abs(v.z - z) < alto * 0.01]
    if len(banda) > 20:
        anchos.append((max(v.x for v in banda) - min(v.x for v in banda), z))
z_cuello = min(anchos)[1] if anchos else lo.z + alto * 0.55
alto_cab = hi.z - z_cuello
print("[chef] alto %.3f  cuello z %.3f  cabeza %.3f (%.0f%% del alto)"
      % (alto, z_cuello, alto_cab, 100.0 * alto_cab / alto))

# EL COLOR DE LA PIEL SALE DE LA CARA, y va por UV: con un material propio de
# color plano la pieza no casa con el cuerpo (la leccion de las bolas de las
# manos), asi que se apunta al mismo texel.
img = next((i for i in bpy.data.images if i.size[0] > 8), None)
uv = malla.data.uv_layers.active.data if malla.data.uv_layers.active else None
malla.data.calc_loop_triangles()
piel_uv = None
if img is not None and uv is not None:
    W, H = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[..., :3]
    cand = []
    for tri in malla.data.loop_triangles:
        p = [M @ malla.data.vertices[vi].co for vi in tri.vertices]
        if min(q.z for q in p) < z_cuello + alto_cab * 0.15:
            continue
        if tri.normal.y > -0.4:
            continue
        for li in tri.loops:
            u, w = uv[li].uv
            cand.append(((float(u), float(w)),
                         px[int(w * (H - 1)) % H, int(u * (W - 1)) % W]))
    if len(cand) > 30:
        C = np.array([c for _, c in cand])
        med = np.median(C, axis=0)
        i = int(np.argmin(np.linalg.norm(C - med, axis=1)))
        piel_uv = cand[i][0]
        print("[chef] piel de la cara %s en UV %s"
              % (tuple(round(float(x), 3) for x in med),
                 tuple(round(x, 4) for x in piel_uv)))

mat_cuerpo = malla.data.materials[0] if malla.data.materials else None


def _cara_en(x, z):
    """Punto y normal de la cara a esa altura, preguntando con un rayo."""
    org = Minv @ Vector((x, lo.y - alto, z))
    dirl = (Minv.to_3x3() @ Vector((0.0, 1.0, 0.0))).normalized()
    ok, loc, nor, _i = malla.ray_cast(org, dirl)
    if not ok:
        return None, None
    return M @ loc, (M.to_3x3() @ nor).normalized()


def _pintar_piel(o):
    if mat_cuerpo is not None:
        o.data.materials.append(mat_cuerpo)
    if piel_uv is not None:
        capa = o.data.uv_layers.active or o.data.uv_layers.new(name="UVMap")
        for d in capa.data:
            d.uv = piel_uv


def _exportar(objs, nombre):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    ruta = os.path.join(OUT, nombre + ".glb")
    bpy.ops.export_scene.gltf(filepath=ruta, export_format="GLB",
                              use_selection=True, export_apply=False,
                              export_animations=False)
    print("[chef] -> %s" % ruta)
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)


def _cuenca(centro, n, ra, rb, hondo):
    """Hunde la piel alrededor del ojo, con caida suave.

    EL OJO DEL REPARTO ES UN HUECO: el del grumete esta metido en una CUENCA y
    lo que lo hace leerse como ojo es ese borde de piel con su sombra. Un
    casquete negro pegado a una cara lisa se ve como una pegatina, por mucho que
    se le afine el tamano. Como la cuenca es del CUERPO y el tamano del ojo se
    elige, se exporta un cuerpo por tamano de ojo.
    """
    n = n.normalized()
    # base ortonormal del plano de la cara en ese punto
    u = n.cross(Vector((0, 0, 1)))
    if u.length < 1e-4:
        u = n.cross(Vector((0, 1, 0)))
    u.normalize()
    w = n.cross(u).normalized()
    tocados = 0
    for v in malla.data.vertices:
        p = M @ v.co
        d = p - centro
        du, dw, dn = d.dot(u), d.dot(w), d.dot(n)
        if abs(dn) > max(ra, rb) * 2.0:
            continue
        t = (du / (ra * 1.55)) ** 2 + (dw / (rb * 1.45)) ** 2
        if t >= 1.0:
            continue
        k = (1.0 - t) ** 1.5
        v.co = Minv @ (p + n * (hondo * k))
        tocados += 1
    return tocados


# --- OJOS ---------------------------------------------------------------------
mat_ojo = bpy.data.materials.new("OjoNegro")
mat_ojo.use_nodes = True
_b = mat_ojo.node_tree.nodes["Principled BSDF"]
_b.inputs["Base Color"].default_value = (0.02, 0.02, 0.025, 1)
_b.inputs["Roughness"].default_value = 0.85
mat_ojo.diffuse_color = (0.02, 0.02, 0.025, 1)

import copy
V_LIMPIO = [v.co.copy() for v in malla.data.vertices]

for nombre, m in OJOS.items():
    for v, co in zip(malla.data.vertices, V_LIMPIO):
        v.co = co.copy()
    piezas = []
    ra = rb = 0.0
    hoyos = 0
    for signo in (1.0, -1.0):
        x = signo * m["sep"] * alto_cab
        z = hi.z - m["bajo"] * alto_cab
        ra = m["ancho"] * alto_cab
        rb = m["alto"] * alto_cab
        p, n = _cara_en(x, z)
        if p is None:
            print("[chef] AVISO: el rayo del ojo no toca la cara")
            p, n = Vector((x, lo.y, z)), Vector((0, -1, 0))
        hoyos += _cuenca(p, n, ra, rb, ra * CUENCA)
        centro = p - n * (ra * PROF * HUNDIDO)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1.0,
                                             location=centro)
        o = bpy.context.object
        o.name = "Ojo%s" % ("L" if signo > 0 else "R")
        # POCA PROFUNDIDAD, no una bola: con la esfera redonda, al girar la
        # cabeza su parte trasera asoma por el canto de la cara.
        o.scale = (ra, ra * PROF, rb)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        bpy.ops.object.shade_smooth()
        o.data.materials.append(mat_ojo)
        piezas.append(o)
    print("[chef] ojos %s: semiejes %.4f x %.4f, cuenca en %d vertices"
          % (nombre, ra, rb, hoyos))
    _exportar(piezas, "chef_ojos_" + nombre)
    # EL CUERPO SE EXPORTA ENTERO, con su armature. Exportando solo la malla
    # (use_selection sobre ella) el .glb pierde la raiz y al reimportarlo vuelve
    # TUMBADO: la escena se mide por el eje equivocado y el modelo sale con otra
    # escala. Ademas, sin esqueleto no sirve para el juego.
    bpy.ops.object.select_all(action="SELECT")
    ruta = os.path.join(OUT, "chef_cuerpo_ojos_%s.glb" % nombre)
    bpy.ops.export_scene.gltf(filepath=ruta, export_format="GLB",
                              export_apply=False, export_animations=False)
    print("[chef] -> %s" % ruta)

for v, co in zip(malla.data.vertices, V_LIMPIO):
    v.co = co.copy()

# --- CEJAS --------------------------------------------------------------------
# Van en pieza APARTE y con material propio ("Cejas") porque su color es el del
# PELO: el juego lo tinta. Son un trazo corto y arqueado, como los del reparto.
mat_ceja = bpy.data.materials.new("Cejas")
mat_ceja.use_nodes = True
_bc = mat_ceja.node_tree.nodes["Principled BSDF"]
_bc.inputs["Base Color"].default_value = (0.16, 0.09, 0.06, 1)
_bc.inputs["Roughness"].default_value = 0.75
mat_ceja.diffuse_color = (0.16, 0.09, 0.06, 1)

# LOS OJOS SE MIDEN EN EL MODELO, que es de donde vienen: son los texeles
# OSCUROS de la cara mirando al frente. Con sus centros, las cejas se colocan
# encima de cada uno y no hay ningun numero puesto a ojo.
oscuro = np.zeros(len(malla.data.vertices), dtype=bool)
if img is not None and uv is not None:
    cv = np.zeros((len(malla.data.vertices), 3))
    nv = np.zeros(len(malla.data.vertices))
    for tri in malla.data.loop_triangles:
        if tri.normal.y > -0.25:
            continue
        for vi, li in zip(tri.vertices, tri.loops):
            u, w = uv[li].uv
            cv[vi] += px[int(w * (H - 1)) % H, int(u * (W - 1)) % W]
            nv[vi] += 1
    mv = nv > 0
    cv[mv] /= nv[mv][:, None]
    alt = np.array([(M @ v.co).z for v in malla.data.vertices])
    oscuro = mv & (cv.mean(axis=1) < 0.16) & (alt > z_cuello + alto_cab * 0.25)
Vw = np.array([M @ v.co for v in malla.data.vertices])
ojos_c = []
for signo in (1.0, -1.0):
    sel = oscuro & ((Vw[:, 0] * signo) > 0.01)
    if sel.sum() < 20:
        print("[chef] AVISO: no encuentro el ojo %s" % ("L" if signo > 0 else "R"))
        ojos_c.append((signo * 0.09 * alto, hi.z - 0.575 * alto_cab, signo * 0.05 * alto))
        continue
    P = Vw[sel]
    # el canto INTERIOR (el que mira a la nariz) hace falta para saber hasta
    # donde se puede aplanar el caballete sin tocar el ojo
    dentro = float(np.percentile(P[:, 0] * signo, 4)) * signo
    ojos_c.append((float(np.median(P[:, 0])), float(np.percentile(P[:, 2], 92)), dentro))
    print("[chef] ojo %s: %d texeles, centro x %.4f, arriba z %.4f, canto interior %.4f"
          % ("L" if signo > 0 else "R", int(sel.sum()), ojos_c[-1][0], ojos_c[-1][1], dentro))

piezas = []
largo = grueso = 0.0
for (cxo, czo, _dentro), signo in zip(ojos_c, (1.0, -1.0)):
    x = cxo
    z = czo + CEJA_SOBRE * alto_cab
    p, n = _cara_en(x, z)
    if p is None:
        p, n = Vector((x, lo.y, z)), Vector((0, -1, 0))
    largo = CEJA_LARGO * alto_cab
    grueso = CEJA_GRUESO * alto_cab
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=14, radius=1.0,
                                         location=p + n * (grueso * 0.25))
    o = bpy.context.object
    o.name = "Ceja%s" % ("L" if signo > 0 else "R")
    o.scale = (largo, grueso * 0.8, grueso)
    o.rotation_euler = (0.0, signo * CEJA_ANGULO, 0.0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    # UNA CEJA NO ES UN PALO: se ARQUEA (el centro sube) y se AFILA hacia las
    # puntas. Con el elipsoide a secas salia un guion plano, que fue justo lo
    # que el usuario vio como "no tiene forma de ceja".
    co = np.array([v.co for v in o.data.vertices], dtype=np.float64)
    cen = co.mean(axis=0)
    dx = (co[:, 0] - cen[0]) / max(largo, 1e-9)
    t = np.clip(np.abs(dx), 0.0, 1.0)
    for i, v in enumerate(o.data.vertices):
        c = co[i].copy()
        c[2] += (1.0 - t[i] ** 2) * grueso * CEJA_ARCO          # el arco
        f = 1.0 - CEJA_PUNTA * (t[i] ** 2)                       # las puntas
        c[2] = cen[2] + (c[2] - cen[2]) * f
        c[1] = cen[1] + (c[1] - cen[1]) * f
        v.co = Vector(c)
    bpy.ops.object.shade_smooth()
    o.data.materials.append(mat_ceja)
    piezas.append(o)
print("[chef] cejas: largo %.4f grueso %.4f" % (largo, grueso))
_exportar(piezas, "chef_cejas")

# --- LA NARIZ QUE TRAE EL MODELO SE APLANA ---------------------------------
# El concepto se pidio con la cara lisa, pero Meshy le puso un bultito de nariz
# igualmente. Con la nariz modular encima quedaban DOS. Se aplana suavizando esa
# zona: primero se sueldan los duplicados del atlas, porque sobre una malla
# partida el suavizado ABRE la superficie (la leccion del Kappa).
if os.environ.get("CHEF_APLANAR_NARIZ", "1") != "0":
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(malla.data)
    antes = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bm.to_mesh(malla.data)
    bm.free()
    malla.data.update()
    Vw = np.array([M @ v.co for v in malla.data.vertices])
    nor = np.array([(M.to_3x3() @ v.normal).normalized() for v in malla.data.vertices])
    z_nar = hi.z - NARIZ_BASE * alto_cab
    # LA ZONA LLEGA HASTA LOS OJOS, NO SE QUEDA EN LA PUNTA DE LA NARIZ. La
    # primera version aplanaba solo alrededor de z_nar y el CABALLETE seguia
    # ahi: entre los dos ojos quedaba un bulto que cogia luz y se leia como una
    # sombra rara en mitad de la cara (lo vio el usuario). El techo son los
    # ojos ya medidos, y el ancho, su canto INTERIOR menos un margen, para no
    # arrastrar el texel del ojo.
    z_alto = max(c[1] for c in ojos_c) + 0.02 * alto_cab
    z_bajo = z_nar - 0.16 * alto_cab
    x_max = max(0.05 * alto_cab, min(abs(c[2]) for c in ojos_c) - 0.02 * alto_cab)
    cerca = ((np.abs(Vw[:, 0]) < x_max) & (Vw[:, 2] > z_bajo) & (Vw[:, 2] < z_alto)
             & (nor[:, 1] < -0.2))
    idx = np.nonzero(cerca)[0]
    # Y CON CAIDA EN EL BORDE: con la mascara a cuchillo, el aplanado dejaba su
    # propio escalon justo donde termina. El peso baja a cero en el canto de la
    # zona, asi que lo aplanado se funde con la cara de alrededor.
    peso = np.zeros(len(Vw))
    if len(idx):
        dx = 1.0 - np.abs(Vw[idx, 0]) / x_max
        dz = np.minimum(Vw[idx, 2] - z_bajo, z_alto - Vw[idx, 2]) / (0.10 * alto_cab)
        t = np.clip(np.minimum(dx / 0.35, dz), 0.0, 1.0)
        peso[idx] = t * t * (3.0 - 2.0 * t)
    if len(idx) > 8:
        vecinos = [[] for _ in range(len(malla.data.vertices))]
        for e in malla.data.edges:
            a_, b_ = e.vertices
            vecinos[a_].append(b_)
            vecinos[b_].append(a_)
        Vl = np.array([v.co for v in malla.data.vertices], dtype=np.float64)
        for _ in range(26):
            nuevo = Vl.copy()
            for vi in idx:
                vv = vecinos[vi]
                if vv:
                    nuevo[vi] = Vl[vi] + (Vl[vv].mean(axis=0) - Vl[vi]) * 0.6 * peso[vi]
            Vl = nuevo
        for i, v in enumerate(malla.data.vertices):
            v.co = Vector(Vl[i])
        malla.data.update()
        print("[chef] caballete y nariz de origen aplanados: %d vertices, "
              "|x| < %.4f, z %.3f..%.3f (soldados %d -> %d)"
              % (len(idx), x_max, z_bajo, z_alto, antes, len(malla.data.vertices)))
    # el cuerpo, ya sin su nariz, se guarda para que el juego use ESTE
    bpy.ops.object.select_all(action="SELECT")
    ruta = os.path.join(OUT, "chef_cuerpo.glb")
    bpy.ops.export_scene.gltf(filepath=ruta, export_format="GLB",
                              export_apply=False, export_animations=False)
    print("[chef] -> %s" % ruta)

# --- NARIZ --------------------------------------------------------------------
for nombre, f in NARICES.items():
    r = f * alto_cab
    z = hi.z - NARIZ_BAJO * alto_cab
    p, n = _cara_en(0.0, z)
    if p is None:
        p, n = Vector((0, lo.y, z)), Vector((0, -1, 0))
    centro = p + n * (r * (NARIZ_SALE - 1.0))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=28, ring_count=16, radius=r,
                                         location=centro)
    o = bpy.context.object
    o.name = "Nariz"
    o.scale = (1.0, 0.85, 0.92)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.shade_smooth()
    _pintar_piel(o)
    print("[chef] nariz %s: radio %.4f en z %.3f" % (nombre, r, centro.z))
    _exportar([o], "chef_nariz_" + nombre)

print("[chef] piezas listas en", OUT)
