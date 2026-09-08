# SACA EL PELO DE UN PERSONAJE YA HECHO y lo recalza en la cabeza del chef.
#
# Los peinados construidos por codigo (chef_pelo.py) valen para las siluetas
# claras —el moño, las coletas, la melena—, pero entre dos cortes masculinos
# solo cambia la linea del pelo y salen todos iguales. El reparto, en cambio,
# ya tiene diez peinados DISTINTOS, dibujados uno a uno y aprobados: el tupe de
# Saverio, la mata de Pablo, el flequillo de Miku, la melena de Alice. Este
# script se los quita y se los pone al chef.
#
# Como se localiza el pelo, sin escribir un color a mano: la piel de la cara se
# mide (el texel mas cercano a la mediana de la cara), y es PELO toda cara de
# la cabeza cuyo texel se aparte de esa piel. Cejas y ojos tambien se apartan,
# asi que se parte el resultado en ISLAS y se queda con las gordas — las cejas
# son islas pequeñas y sueltas.
#
# Y se recalza MIDIENDO las dos cabezas: se escala por la razon de radios y se
# lleva el centro de una al de la otra. Despues, cualquier vertice que quede
# DENTRO del craneo del chef se empuja fuera preguntandole al propio craneo con
# un rayo, asi que el pelo no puede atravesarle la cabeza por mucho que las dos
# no sean iguales.
#
#   blender --background --python tools/blender/pelo_de.py -- \
#       <personaje.glb> <chef_cuerpo.glb> <salida.glb>
import bpy, sys, os, math, bmesh
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
SRC, CHEF, DEST = [os.path.abspath(x) for x in a[:3]]

RATIO = float(os.environ.get("PELO_RATIO", 0.45))     # cuanto mas oscuro que la piel
CROMA = float(os.environ.get("PELO_CROMA", 0.25))     # cuanto se aparta del tono de la piel
Z_MIN = float(os.environ.get("PELO_ZMIN", 0.06))      # desde donde se busca, en alto de cabeza
ISLA = float(os.environ.get("PELO_ISLA", 0.18))       # islas menores que esto, fuera
GROSOR = float(os.environ.get("PELO_GROSOR", 0.075))  # en radios de la cabeza del chef
SEP = float(os.environ.get("PELO_SEP", 0.050))        # holgura sobre el craneo, idem
TAPA = int(os.environ.get("PELO_TAPA", 60))           # agujeros de hasta N lados, tapados
RIZOS = int(os.environ.get("PELO_RIZOS", 0))          # cuantos bollos de rizo
RIZO_AMP = float(os.environ.get("PELO_RIZO_AMP", 0.075))   # en radios de cabeza
RIZO_RAD = float(os.environ.get("PELO_RIZO_RAD", 0.30))    # ancho, en radianes
CARAS = int(os.environ.get("PELO_CARAS", 2400))
ESCALA = float(os.environ.get("PELO_ESCALA", 1.0))    # retoque fino del calce
SUBE = float(os.environ.get("PELO_SUBE", 0.0))        # en radios, + hacia arriba
CLAROS = os.environ.get("PELO_CLAROS", "") not in ("", "0")   # pelo mas claro que la piel
BARBA = float(os.environ.get("PELO_BARBA", 0.58))     # por debajo de esto y de frente, es barba
# MODO: "pelo" saca la mata de la cabeza; "barba" saca la barba o el bigote, que
# es el mismo problema del reves — se inunda desde la BARBILLA en vez de desde
# la coronilla, y se corta por arriba para no subirse al pelo por las patillas.
MODO = os.environ.get("PELO_MODO", "pelo")
BARBA_TOPE = float(os.environ.get("PELO_BARBA_TOPE", 0.62))
# CORTE por altura de la cabeza DEL CHEF, ya recalzada la pieza: "z0,z1". Es lo
# que saca las tres variantes de una misma barba — la entera, la barba sin
# bigote y el bigote solo — sin volver a extraer nada.
CORTE = os.environ.get("PELO_CORTE", "")
# y un hueco central, "z0,z1,xmax": quita el bigote de una barba entera.
SIN_BIGOTE = os.environ.get("PELO_SIN_BIGOTE", "")
ANCHO = float(os.environ.get("PELO_ANCHO", 0))       # |x| maximo, en radios de cabeza
# PEGAR: en vez de solo SACAR lo que quede dentro del craneo, proyecta la pieza
# entera sobre el. Una barba corta viene de la cara de OTRO personaje, asi que
# por mucho que no se meta dentro, hay trozos que se quedan DESPEGADOS. Para una
# barba de tres dias es justo lo que hace falta; para una larga, no (por debajo
# de la barbilla no hay cara a la que pegarse).
PEGAR = os.environ.get("PELO_PEGAR", "") not in ("", "0")
# Y PARA UNA BARBA LARGA, un TOPE de despegue en vez de pegarla del todo: lo que
# se aleje del craneo mas de esto (en radios) se acerca hasta el tope, y lo que
# ya estuviera cerca no se toca. Pegandola entera se le quita el volumen, que es
# justo lo que la hace una barba larga y no una pintura.
PEGAR_MAX = float(os.environ.get("PELO_PEGAR_MAX", 0))
# LO QUE CUELGA POR DEBAJO DE LA BARBILLA SE COMPRIME hacia ella (fraccion del
# largo que conserva). La barba de David llega a media pechera en David, pero en
# el chef de la cinta, junto a una melena, se leia como un manto que tapaba el
# cuerpo entero. Comprimir en vez de cortar conserva la punta redondeada: un
# corte plano dejaba el fondo en una linea recta.
COLGANTE = float(os.environ.get("PELO_COLGANTE", 1.0))
# UNA BARBA VA ENTERA A LA CABEZA. El reparto por altura esta pensado para una
# melena que cuelga, y la barbilla del chef cae por DEBAJO de la linea del
# cuello: sin esto, la barba cogia peso del tronco y se quedaba atras al girar
# la cabeza.
PESO = os.environ.get("PELO_PESO", "altura")
# LA SEMILLA de la barba es por defecto la BARBILLA, pero un personaje con
# BIGOTE Y NADA MAS tiene la barbilla afeitada: ahi hay que sembrar en la
# franja de debajo de la nariz. Va en fracciones del alto de la cabeza.
SEMILLA_H = [float(x) for x in os.environ.get("PELO_SEMILLA_H", "0.03,0.14").split(",")]
# Y LA TOLERANCIA PUEDE IR A PELO: a los que llevan sombrero (Pablo, el capitan)
# la cara les sale en SOMBRA y el contraste medido no vale — sus dos muestras
# salen oscuras y el listado de "no tiene barba" salta con barba puesta.
TOL_ABS = float(os.environ.get("PELO_TOL_ABS", 0))


def _cabeza(obj):
    """Centro, radio y altura del cuello de una figura de pie."""
    M = obj.matrix_world
    vs = [M @ v.co for v in obj.data.vertices]
    zlo = min(v.z for v in vs)
    zhi = max(v.z for v in vs)
    alto = zhi - zlo
    # EL CUELLO SE BUSCA ENTRE EL 52% Y EL 75% DEL ALTO, no desde el 30: en una
    # figura con falda o con las piernas juntas, la fila mas estrecha de la
    # mitad de abajo es la CINTURA, y a Alice le salia el "cuello" al 39% — con
    # eso, la "cabeza" era medio cuerpo y todo lo demas salia mal.
    anchos = []
    for k in range(52, 76):
        z = zlo + alto * k / 100.0
        banda = [v for v in vs if abs(v.z - z) < alto * 0.01]
        if len(banda) > 20:
            anchos.append((max(v.x for v in banda) - min(v.x for v in banda), z))
    z_cuello = min(anchos)[1] if anchos else zlo + alto * 0.55
    P = np.array([[v.x, v.y, v.z] for v in vs])
    cab = P[P[:, 2] > z_cuello + (zhi - z_cuello) * 0.10]
    C = Vector((0.0,
                float(cab[:, 1].min() + cab[:, 1].max()) / 2.0,
                float(cab[:, 2].min() + cab[:, 2].max()) / 2.0))
    R = float(np.median(np.linalg.norm(cab - np.array(C), axis=1)))
    return C, R, z_cuello, zhi


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
sc = bpy.context.scene
pers = max((o for o in sc.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
M = pers.matrix_world
C1, R1, z_cuello1, zhi1 = _cabeza(pers)
alto_cab1 = zhi1 - z_cuello1

# LA MALLA VIENE PARTIDA en cada costura del atlas (la leccion del Kappa), y sin
# soldarla las islas de pelo salen a trozos.
bm = bmesh.new()
bm.from_mesh(pers.data)
antes = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
bm.to_mesh(pers.data)
bm.free()
pers.data.update()
pers.data.calc_loop_triangles()

img = next((i for i in bpy.data.images if i.size[0] > 8), None)
uv = pers.data.uv_layers.active.data if pers.data.uv_layers.active else None
if img is None or uv is None:
    raise SystemExit("[pelo] ese modelo no trae textura")
W, H = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[..., :3]

col = np.zeros((len(pers.data.vertices), 3))
cnt = np.zeros(len(pers.data.vertices))
for tri in pers.data.loop_triangles:
    for vi, li in zip(tri.vertices, tri.loops):
        u, w = uv[li].uv
        col[vi] += px[int(w * (H - 1)) % H, int(u * (W - 1)) % W]
        cnt[vi] += 1
ok = cnt > 0
col[ok] /= cnt[ok][:, None]
Vw = np.array([M @ v.co for v in pers.data.vertices])
nor = np.array([(M.to_3x3() @ v.normal).normalized() for v in pers.data.vertices])

# LA PIEL SE MIDE EN LA BARBILLA, que es lo unico que es piel en todos: por
# encima hay flequillos, gafas y pañuelos. Cogiendo toda la mitad baja de la cabeza que mira al frente —que
# fue lo primero— entraban el ala del sombrero de Pablo, el pañuelo de Cai y
# la melena de Miku, y la "piel" salia morada: con la referencia mal, TODA la
# cabeza se aparta de ella y el pelo detectado era el personaje entero.
if MODO == "barba":
    # LA BARBILLA NO VALE DE REFERENCIA cuando lo que se busca ES la barba: en
    # Saverio la "piel" salia a 0.17, o sea su propia barba. Se mide en el
    # CABALLETE DE LA NARIZ —la franja estrecha entre los ojos, por encima de
    # la punta—, que es piel en todos: un bigote va DEBAJO de la nariz, nunca
    # encima, y los ojos quedan a los lados. Coger el punto mas ADELANTADO
    # tampoco valia: en una cara con bigote poblado, lo que mas sobresale es el
    # bigote.
    _alto = (Vw[:, 2] - z_cuello1) / alto_cab1
    cara = (ok & (np.abs(Vw[:, 0] - C1.x) < R1 * 0.16) & (nor[:, 1] < -0.50)
            & (_alto > 0.48) & (_alto < 0.64))
else:
    cara = (ok & (np.abs(Vw[:, 0] - C1.x) < R1 * 0.35) & (nor[:, 1] < -0.30)
            & (Vw[:, 2] > z_cuello1 + alto_cab1 * 0.08)
            & (Vw[:, 2] < z_cuello1 + alto_cab1 * 0.30))
if cara.sum() < 30:
    cara = ok & (Vw[:, 2] > z_cuello1) & (nor[:, 1] < -0.4)
piel = np.median(col[cara], axis=0)
print("[pelo] %s: piel %s (%d vertices de cara)"
      % (os.path.basename(SRC), tuple(round(float(x), 3) for x in piel), int(cara.sum())))

alto_v = (Vw[:, 2] - z_cuello1) / alto_cab1
lum = col.mean(axis=1)
lum_piel = float(piel.mean())

# EL PELO SE BUSCA DESDE LA CORONILLA, INUNDANDO. Se probaron antes dos
# criterios de color y los dos fallaron por lo mismo: estos modelos traen el
# SOMBREADO HORNEADO, asi que una mejilla en sombra se aparta de la piel media
# mas que cualquier umbral razonable y "pelo" salia el 80% de la cabeza. Aqui
# no se decide vertice a vertice: se parte del punto MAS ALTO —que es pelo por
# definicion, si lo hay— y se va extendiendo por caras vecinas mientras el
# color siga pareciendose al de la coronilla. La inundacion se para sola en el
# nacimiento del pelo, que es justo donde el color salta.
#
# Y LA TOLERANCIA NO ES UN NUMERO A MANO: es una fraccion de lo que se
# diferencian el pelo y la piel de ESE personaje, asi que un pelo muy oscuro
# admite mucha sombra y uno castaño claro admite poca.
if MODO == "barba":
    # LA SEMILLA ES LA BARBILLA, no "lo que mas se aparta de la piel": eso ultimo
    # se iba a los OJOS, que son negro puro, y de ahi salia una mancha de 200
    # caras en mitad de la cara. La barbilla es barba si la hay y piel si no, y
    # el contraste contra el caballete lo dice.
    baja = np.nonzero(ok & (alto_v > SEMILLA_H[0]) & (alto_v < SEMILLA_H[1])
                      & (nor[:, 1] < -0.20)
                      & (np.abs(Vw[:, 0] - C1.x) < R1 * 0.50))[0]
    if len(baja) < 10:
        raise SystemExit("[pelo] no encuentro la barbilla")
    pelo_c = np.median(col[baja], axis=0)
    i_alto = int(baja[np.argmin(np.linalg.norm(col[baja] - pelo_c, axis=1))])
else:
    cabeza = np.nonzero(ok & (alto_v > Z_MIN))[0]
    i_alto = int(cabeza[np.argmax(Vw[cabeza, 2])])
pelo_c = col[i_alto]
contraste = float(np.linalg.norm(pelo_c - piel))
print("[pelo] coronilla %s, piel %s, contraste %.3f"
      % (tuple(round(float(x), 3) for x in pelo_c),
         tuple(round(float(x), 3) for x in piel), contraste))
if contraste < 0.10 and TOL_ABS <= 0.0:
    raise SystemExit("[pelo] ese personaje no tiene %s"
                     % ("barba" if MODO == "barba" else "pelo (es CALVO)"))
# ...pero con TECHO: un pelo negro sobre piel clara da un contraste de 1.0 y el
# 55% de eso admite hasta la propia piel.
TOL = (TOL_ABS if TOL_ABS > 0.0
       else min(float(os.environ.get("PELO_TOL", 0.55)) * contraste,
                float(os.environ.get("PELO_TOL_MAX", 0.30))))
print("[pelo] tolerancia %.3f" % TOL)

bm = bmesh.new()
bm.from_mesh(pers.data)
bm.faces.ensure_lookup_table()
bm.verts.ensure_lookup_table()


def _color_cara(f):
    c = np.zeros(3)
    for v in f.verts:
        c += col[v.index]
    return c / len(f.verts)


def _vale(f):
    w = M @ f.calc_center_median()
    h = (w.z - z_cuello1) / alto_cab1
    if h < Z_MIN:
        return False
    # EN MODO BARBA hay que cortar por ARRIBA: la barba se junta con el pelo por
    # las PATILLAS, asi que sin tope la inundacion se sube a la cabeza y saca
    # las dos cosas de una pieza.
    if MODO == "barba" and h > BARBA_TOPE:
        return False
    # LA BARBA NO ES PELO DE LA CABEZA, y del mismo color y pegada a las
    # patillas: la inundacion se la llevaba entera (Saverio y David salian con
    # el peinado y la barba puestos). Se corta con la unica regla que las
    # separa sin mirar el color: la barba esta DELANTE y BAJA, y el pelo, o
    # esta arriba, o esta detras.
    if MODO != "barba" and h < BARBA and f.normal.y < -0.20:
        return False
    return float(np.linalg.norm(_color_cara(f) - pelo_c)) < TOL


# LA SEMILLA: en modo pelo, el trozo mas ALTO (la coronilla). En modo barba, el
# mas CERCANO A LA BARBILLA — no "el mas bajo", que es lo que se probo primero:
# en cuanto se deja bajar la busqueda por debajo del cuello (una barba larga
# cuelga), el trozo mas bajo que casa de color esta en la ROPA, y de ahi salia
# una mancha del chaleco en vez de la barba.
if MODO == "barba":
    p_sem = np.median(Vw[baja], axis=0)
    sem = min((f for f in bm.faces if _vale(f)),
              key=lambda f: (np.array(M @ f.calc_center_median()) - p_sem).dot(
                  np.array(M @ f.calc_center_median()) - p_sem), default=None)
else:
    sem = max((f for f in bm.faces if _vale(f)),
              key=lambda f: (M @ f.calc_center_median()).z, default=None)
if sem is None:
    raise SystemExit("[pelo] no he encontrado pelo en ese modelo")
dentro_pelo = set([sem.index])
pila = [sem]
while pila:
    f = pila.pop()
    for e in f.edges:
        for g in e.link_faces:
            if g.index not in dentro_pelo and _vale(g):
                dentro_pelo.add(g.index)
                pila.append(g)
print("[pelo] la mata son %d caras (%.0f%% de la cabeza)"
      % (len(dentro_pelo),
         100.0 * len(dentro_pelo) / max(1, sum(
             1 for f in bm.faces
             if (M @ f.calc_center_median()).z > z_cuello1))))
fuera = [f for f in bm.faces if f.index not in dentro_pelo]
bmesh.ops.delete(bm, geom=fuera, context="FACES")
me = bpy.data.meshes.new("Pelo")
bm.to_mesh(me)
bm.free()
o = bpy.data.objects.new("Pelo", me)
sc.collection.objects.link(o)
o.matrix_world = M
if not len(me.polygons):
    raise SystemExit("[pelo] no he encontrado pelo en ese modelo")

# ISLAS: las cejas y los ojos tambien se apartan de la piel, pero son manchas
# sueltas y pequeñas. Se queda con las gordas.
bm = bmesh.new()
bm.from_mesh(me)
bm.faces.ensure_lookup_table()
visto = set()
islas = []
for f in bm.faces:
    if f.index in visto:
        continue
    pila, grupo = [f], []
    visto.add(f.index)
    while pila:
        g = pila.pop()
        grupo.append(g)
        for e in g.edges:
            for h in e.link_faces:
                if h.index not in visto:
                    visto.add(h.index)
                    pila.append(h)
    islas.append(grupo)
islas.sort(key=len, reverse=True)
mayor = len(islas[0])
tirar = []
for g in islas[1:]:
    if len(g) < mayor * ISLA:
        tirar.extend(g)
print("[pelo] %d islas (la mayor %d caras); me quedo con %d"
      % (len(islas), mayor, sum(1 for g in islas if len(g) >= mayor * ISLA)))
bmesh.ops.delete(bm, geom=tirar, context="FACES")
bm.to_mesh(me)
bm.free()
me.update()

# --- RECALZAR EN LA CABEZA DEL CHEF ------------------------------------------
bpy.ops.import_scene.gltf(filepath=CHEF)
chef = max((x for x in sc.objects if x.type == "MESH" and x is not o and x is not pers),
           key=lambda x: len(x.data.vertices))
C2, R2, z_cuello2, zhi2 = _cabeza(chef)
s = (R2 / R1) * ESCALA
print("[pelo] cabezas: origen r=%.4f -> chef r=%.4f (escala %.3f)" % (R1, R2, s))
Mi = o.matrix_world.inverted()
for v in me.vertices:
    w = o.matrix_world @ v.co
    d = Vector((w.x - C1.x, w.y - C1.y, w.z - C1.z)) * s
    v.co = Mi @ (C2 + d + Vector((0.0, 0.0, SUBE * R2)))
me.update()

if COLGANTE < 1.0:
    _ac = zhi2 - z_cuello2
    _z_barbilla = z_cuello2 + 0.03 * _ac
    _n = 0
    for v in me.vertices:
        w = o.matrix_world @ v.co
        if w.z < _z_barbilla:
            w.z = _z_barbilla + (w.z - _z_barbilla) * COLGANTE
            v.co = o.matrix_world.inverted() @ w
            _n += 1
    me.update()
    print("[pelo] colgante comprimido a %.2f (%d vertices)" % (COLGANTE, _n))

# NADA DE PELO DENTRO DE LA CABEZA: se le pregunta al craneo del chef con un
# rayo desde su centro, y lo que quede por dentro se saca. Asi da igual que las
# dos cabezas no sean iguales.
Mc = chef.matrix_world.inverted()
dentro = 0
_alto_cab2 = zhi2 - z_cuello2
for v in me.vertices:
    w = o.matrix_world @ v.co
    d = Vector((w.x - C2.x, w.y - C2.y, w.z - C2.z))
    r = d.length
    if r < 1e-6:
        continue
    # LO QUE CUELGA POR DEBAJO DE LA BARBILLA NO SE EMPUJA. El empujon esta
    # pensado para un CASQUETE: se pregunta al craneo con un rayo desde su
    # centro y se saca lo que este dentro. Con una barba larga, ese rayo apunta
    # hacia abajo, sale por el cuello o por el pecho y devuelve una distancia
    # enorme, asi que la barba se abria hacia fuera y salia DESFIGURADA. Ahi
    # abajo no hay cabeza que atravesar: cuelga al aire.
    if (w.z - z_cuello2) / _alto_cab2 < 0.03:
        continue
    org = Mc @ C2
    dl = (Mc.to_3x3() @ d.normalized()).normalized()
    hit, loc, _n, _i = chef.ray_cast(org, dl)
    if not hit:
        continue
    piel_r = ((chef.matrix_world @ loc) - C2).length
    if PEGAR_MAX > 0.0:
        tope = piel_r + PEGAR_MAX * R2
        if r > tope:
            # se funde con la altura para no dejar un pliegue justo en la
            # barbilla, donde la barba pasa de estar pegada a colgar
            hh = (w.z - z_cuello2) / _alto_cab2
            # LA FUNDIDA VA CORTA. Con 0.14 de recorrido, la zona que de verdad
            # toca la mejilla —que empieza justo encima de la barbilla— recibia
            # el 14% de la correccion y la barba seguia despegada.
            t = max(0.0, min(1.0, (hh - 0.02) / 0.04))
            v.co = Mi @ (C2 + d.normalized() * (r + (tope - r) * t))
            dentro += 1
        continue
    if PEGAR or r < piel_r + SEP * R2:
        v.co = Mi @ (C2 + d.normalized() * (piel_r + SEP * R2))
        dentro += 1
me.update()
print("[pelo] %d vertices estaban dentro de la cabeza y se han sacado" % dentro)
# DONDE CAE LA PIEZA EN LA CARA DEL CHEF, en fracciones del alto de su cabeza.
# Es lo que dice si un bigote ha quedado por encima o por debajo de la nariz sin
# tener que mirar un render: en el chef la nariz va de h 0.19 a 0.33, los ojos
# empiezan en 0.51 y la barbilla esta en 0.00.
_h = [((o.matrix_world @ v.co).z - z_cuello2) / (zhi2 - z_cuello2) for v in me.vertices]
print("[pelo] la pieza ocupa h %.3f .. %.3f (nariz 0.19-0.33, ojos desde 0.51)"
      % (min(_h), max(_h)))

if CORTE or SIN_BIGOTE or ANCHO > 0.0:
    alto_cab2b = zhi2 - z_cuello2
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    fuera = []
    z0 = z1 = None
    if CORTE:
        z0, z1 = [float(x) for x in CORTE.split(",")]
    hb = [float(x) for x in SIN_BIGOTE.split(",")] if SIN_BIGOTE else None
    for f in bm.faces:
        w = o.matrix_world @ f.calc_center_median()
        h = (w.z - z_cuello2) / alto_cab2b
        if z0 is not None and not (z0 <= h <= z1):
            fuera.append(f)
        elif ANCHO > 0.0 and abs(w.x - C2.x) > ANCHO * R2:
            fuera.append(f)
        elif hb is not None and hb[0] <= h <= hb[1] and abs(w.x - C2.x) < hb[2] * R2:
            fuera.append(f)
    bmesh.ops.delete(bm, geom=fuera, context="FACES")
    bm.to_mesh(me)
    bm.free()
    me.update()
    print("[pelo] recortada a %d caras" % len(me.polygons))

# SE LE TAPAN LOS AGUJEROS Y SE SEPARA DE LA PIEL. La inundacion deja calvas
# —texeles del pelo que se salieron de la tolerancia—, y por ahi asomaba el
# craneo del chef. Los agujeros pequeños se cierran, y el resto de la mata se
# despega del craneo, que ademas le da VOLUMEN: un pelo pegado al hueso no
# parece pelo.
bm = bmesh.new()
bm.from_mesh(me)
# OJO CON `sides`: a 0 NO desactiva el relleno, lo deja SIN LIMITE, y entonces
# tapa tambien el borde grande de la pieza con un poligono PLANO — la barba de
# David salia como una PLANCHA rectangular. Para no tapar nada, cero pasadas.
if TAPA > 0:
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=TAPA)
bm.normal_update()
for v in bm.verts:
    v.co += v.normal * (SEP * R2)
bm.to_mesh(me)
bm.free()
me.update()

# LOS RIZOS SE MODELAN, NO SE PINTAN. El rizo de Saverio esta en su TEXTURA, y
# aqui la textura se tira (el pelo va en blanco para poder teñirlo) y ademas la
# malla se decima: sin esto, su mata y la de cualquier otro salen como el mismo
# casquete redondo. Se abolla con muchos bollos pequeños repartidos por una
# espiral de Fibonacci —que es lo que reparte puntos por una esfera sin que se
# amontonen— y la superficie pasa a ser grumosa de verdad.
if RIZOS > 0:
    Mi2 = o.matrix_world.inverted()
    oro = math.pi * (3.0 - math.sqrt(5.0))
    dirs = []
    for k in range(RIZOS):
        z = 1.0 - (k + 0.5) / RIZOS * 1.35      # solo la mitad de arriba y algo mas
        r = math.sqrt(max(0.0, 1.0 - z * z))
        dirs.append(Vector((math.cos(oro * k) * r, math.sin(oro * k) * r, z)))
    for v in me.vertices:
        w = o.matrix_world @ v.co
        d = Vector((w.x - C2.x, w.y - C2.y, w.z - C2.z))
        if d.length < 1e-6:
            continue
        u = d.normalized()
        des = Vector((0.0, 0.0, 0.0))
        for b in dirs:
            ang = math.acos(max(-1.0, min(1.0, u.dot(b))))
            if ang >= RIZO_RAD:
                continue
            t = 1.0 - (ang / RIZO_RAD) ** 2
            des += b * (RIZO_AMP * R2 * t * t)
        if des.length > 1e-9:
            v.co = Mi2 @ (w + des)
    me.update()

# PESADO POR ALTURA, como en chef_pelo.py: el chef se anima girando huesos y
# una pieza colgada solo de la cabeza barreria el cuerpo al cabecear.
arm = next((x for x in sc.objects if x.type == "ARMATURE"), None)
if arm is not None:
    for n in ("Head", "Neck", "Spine1"):
        if n not in [g.name for g in o.vertex_groups]:
            o.vertex_groups.new(name=n)
    gh, gn, gs = (o.vertex_groups[n] for n in ("Head", "Neck", "Spine1"))
    alto_cab2 = zhi2 - z_cuello2
    z_alto, z_bajo = z_cuello2 + alto_cab2 * 0.10, z_cuello2 - alto_cab2 * 0.60
    for v in me.vertices:
        z = (o.matrix_world @ v.co).z
        t = 1.0 if PESO == "head" else max(0.0, min(1.0, (z - z_bajo) / (z_alto - z_bajo)))
        gh.add([v.index], t * t, "REPLACE")
        gn.add([v.index], 2.0 * t * (1.0 - t), "REPLACE")
        gs.add([v.index], (1.0 - t) * (1.0 - t), "REPLACE")
    o.parent = arm
    o.matrix_parent_inverse = arm.matrix_world.inverted()
    mm = o.modifiers.new("Esqueleto", "ARMATURE")
    mm.object = arm

bpy.data.objects.remove(chef, do_unlink=True)
bpy.data.objects.remove(pers, do_unlink=True)
bpy.context.view_layer.objects.active = o
o.select_set(True)
m = o.modifiers.new("Grosor", "SOLIDIFY")
m.thickness = GROSOR * R2
m.offset = -1.0          # el pelo crece HACIA DENTRO: la cara buena es la de fuera
bpy.ops.object.modifier_apply(modifier=m.name)
if len(me.polygons) > CARAS:
    d = o.modifiers.new("Decima", "DECIMATE")
    d.ratio = float(CARAS) / len(me.polygons)
    bpy.ops.object.modifier_apply(modifier=d.name)
bpy.ops.object.shade_smooth()

mat = bpy.data.materials.new("Pelo")
mat.use_nodes = True
_b = mat.node_tree.nodes["Principled BSDF"]
_b.inputs["Base Color"].default_value = (1.0, 1.0, 1.0, 1.0)
_b.inputs["Roughness"].default_value = 0.42
mat.diffuse_color = (1.0, 1.0, 1.0, 1.0)
me.materials.clear()
me.materials.append(mat)

bpy.ops.object.select_all(action="DESELECT")
o.select_set(True)
if arm is not None:
    arm.select_set(True)
bpy.ops.export_scene.gltf(filepath=DEST, export_format="GLB",
                          use_selection=True, export_apply=False,
                          export_animations=False)
print("[pelo] %d caras -> %s" % (len(me.polygons), DEST))
