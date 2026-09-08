# Sustituye las MANOS de un personaje por dos ESFERAS colgadas de la muñeca.
#
# Meshy no sabe hacer un muñón: le pongas lo que le pongas en el concepto
# —bola, muñón, manopla— reconstruye una mano con pulgar, porque "corrige" lo
# que interpreta como un brazo mal hecho. Y redondear esa mano después
# (david_munon.py) deja un bulto alargado, no una esfera. Asi que la mano se
# ESCONDE y la esfera se pone aparte, que es una pieza de tres lineas:
#
#   1. los vertices que pesan en la muñeca se COLAPSAN hacia el hueso (no se
#      borran: borrar deja agujeros y estropea el skin), asi que la mano queda
#      encogida DENTRO de la esfera;
#   2. se crea una esfera en la cabeza del hueso de la muñeca, un poco mas
#      alla en la direccion del antebrazo, con el radio sacado del grosor del
#      antebrazo (medido en la malla, no puesto a mano);
#   3. la esfera lleva material de PIEL PLANA con el color mediano de la piel de
#      la mano original (leido de la textura por las UV), y pesa al 100% en la
#      muñeca, asi que gira con ella sin deformarse.
#
#   blender --background --python tools/blender/manos_esfera.py -- <in.glb> <out.glb>
import bpy, sys, os
import numpy as np
from mathutils import Vector, Matrix

a = sys.argv[sys.argv.index("--") + 1:]
SRC, DEST = os.path.abspath(a[0]), os.path.abspath(a[1])
# MEDIDO en el capitan: a 1.05 la esfera salia mas gorda que el puño y a 0.55
# de avance asomaba un resto de la mano encogida por detras.
RADIO = float(os.environ.get("ESFERA_RADIO", 1.02))    # del radio del antebrazo
AVANCE = float(os.environ.get("ESFERA_AVANCE", 0.22))  # radios mas alla de la muñeca
ENCOGE = float(os.environ.get("MANO_ENCOGE", 0.02))    # a cuanto se colapsa la mano
# a que fraccion del radio de la bola se lleva la carne escondida: por dentro,
# pero sin colapsar a un punto (eso arrugaba la muñeca)
ENVUELVE = float(os.environ.get("MANO_ENVUELVE", 0.88))
# pasadas de alisado sobre lo envuelto, para que el empalme no deje aristas
SUAVIZA = int(os.environ.get("MANO_SUAVIZA", 0))
# La mediana de la textura de la mano sale PALIDA (lleva los brillos horneados
# dentro), asi que se oscurece un poco para casar con la cara.
PIEL_K = float(os.environ.get("ESFERA_PIEL_K", 1.0))
# hasta donde se considera "mano" lo que pesa en la muñeca, en radios de
# antebrazo: mas alla, es geometria que el rig metio ahi por error
ALCANCE = float(os.environ.get("MANO_ALCANCE", 3.2))
# hasta donde alcanza la bola cuando su sitio va MEDIDO (en radios suyos)
ALCANCE_POS = float(os.environ.get("ESFERA_ALCANCE_POS", 2.1))
# hasta que radio se envuelve del todo (dentro de eso, peso 1)
PLANO_POS = float(os.environ.get("ESFERA_PLANO_POS", 1.25))
# ESFERA_SALTAR=1 deja el modelo como esta. La SIRENA ya viene con los brazos
# cruzados y acabados en muñon redondo, y su rig pone las muñecas a la altura
# del pecho —dentro de la melena—, asi que ponerle bolas las dejaba flotando en
# el pelo. Cuando el modelo ya acaba bien, no se toca.
SALTAR = os.environ.get("ESFERA_SALTAR", "") not in ("", "0")

# PABLO EL RUBIO lleva un PUÑAL en vez de una de las manos: en esa muñeca, en
# lugar de la esfera va un CASQUILLO de acero cerrado que sella el muñón y una
# HOJA saliendo de su centro en la direccion del antebrazo (la misma receta por
# piezas que costo una docena de intentos en su retrato 2D). Meshy no lo
# reconstruye —se lo come como se comia las bolas—, asi que va aqui, como
# geometria propia colgada del hueso de la muñeca.
HOJA = os.environ.get("ESFERA_HOJA", "")            # "L" o "R": la muñeca del puñal
# Si ESFERA_PUNAL apunta a un .glb, se usa ESE modelo (el de Meshy) en vez de la
# geometria de aqui: se escala por su LARGO contra el radio del antebrazo, se
# orienta a lo largo del hueso y se pesa al 100% en la muñeca.
PUNAL_GLB = os.environ.get("ESFERA_PUNAL", "")
PUNAL_LARGO = float(os.environ.get("PUNAL_LARGO", 4.6))  # radios de antebrazo
# cuanto se mete la cazoleta DENTRO de la manga (radios de antebrazo): la
# cazoleta tiene que tapar la boca del puño, o asoma un anillo de piel entre la
# tela y el puñal (lo pidio el usuario: que no se le vea nada de piel)
PUNAL_ATRAS = float(os.environ.get("PUNAL_ATRAS", 0.95))
HOJA_LARGO = float(os.environ.get("HOJA_LARGO", 2.4))   # en radios del antebrazo
HOJA_ANCHO = float(os.environ.get("HOJA_ANCHO", 1.1))  # idem

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
if SALTAR:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=DEST, export_format="GLB",
                              export_apply=False, export_animations=False)
    print("[esfera] SALTADO: el modelo se copia tal cual ->", DEST)
    sys.exit(0)
sc = bpy.context.scene
malla = max((o for o in sc.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
# SOLDAR LOS DUPLICADOS EXACTOS. La malla de Meshy viene PARTIDA en cada
# costura del atlas, y sobre una malla partida cualquier alisado ABRE la
# superficie: el empalme del brazo con la bola salia en astillas. Las UV son
# por LOOP, asi que soldar vertices no las toca.
if os.environ.get("MANO_SOLDAR", "0") != "0":
    import bmesh
    _bm = bmesh.new()
    _bm.from_mesh(malla.data)
    _antes = len(_bm.verts)
    bmesh.ops.remove_doubles(_bm, verts=_bm.verts, dist=1e-4)
    _bm.to_mesh(malla.data)
    _bm.free()
    malla.data.update()
    print("[esfera] soldado: %d -> %d vertices" % (_antes, len(malla.data.vertices)))
arm = [o for o in sc.objects if o.type == "ARMATURE"][0]
me = malla.data
me.calc_loop_triangles()
M = malla.matrix_world
Minv = M.inverted()

# textura, para el color de la piel
img = next((i for i in bpy.data.images if i.size[0] > 8), None)
px = None
if img is not None:
    W, H = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[..., :3]
uv = me.uv_layers.active.data if me.uv_layers.active else None

grupos = {g.name: g.index for g in malla.vertex_groups}
V = np.array([v.co for v in me.vertices], dtype=np.float64)

esferas = []
for lado in ("L", "R"):
    nom = "%s_Wrist" % lado
    if nom not in grupos:
        print("[esfera] sin grupo %s" % nom)
        continue
    gi = grupos[nom]
    peso = np.zeros(len(V))
    for i, v in enumerate(me.vertices):
        for ge in v.groups:
            if ge.group == gi:
                peso[i] = ge.weight
    mano = np.nonzero(peso > 0.5)[0]
    if len(mano) < 10:
        print("[esfera] %s: solo %d vertices" % (nom, len(mano)))
        continue
    b = arm.data.bones[nom]
    cab = Minv @ (arm.matrix_world @ b.head_local)
    cola = Minv @ (arm.matrix_world @ b.tail_local)
    eje = (cola - cab).normalized()
    # ESFERA_POS_L / ESFERA_POS_R: el sitio de la bola MEDIDO a mano, para
    # cuando el rig miente. A la SIRENA le puso las muñecas a la altura del
    # pecho, dentro de la melena, y ni el eje del codo ni "lo mas lejos del
    # hombro" dan con la punta de su brazo: su grupo del codo lleva pelo por
    # detras. Las suyas salen de localizar la CARNE en la banda de la cadera
    # (tools: la nube de texeles rojizos con z 0.50..0.70) y quedarse con su
    # extremo bajo: (0.114, -0.016, 0.514) y (-0.111, -0.010, 0.512), radio
    # 0.023 medido en esa misma nube.
    _pos = os.environ.get("ESFERA_POS_%s" % lado, "")
    if _pos:
        punta = Vector([float(x) for x in _pos.split(",")])
        r_forzado = float(os.environ.get("ESFERA_R_FIJO", "0.023"))
        eje = (punta - Vector(V[mano].mean(axis=0))).normalized() if len(mano) else Vector((0, 0, -1))
        eje = Vector((0, 0, -1)) if eje.length < 0.5 else eje
        cab = punta - eje * r_forzado * 0.8
        # SOLO CARNE: por distancia a secas se lleva por delante las MECHAS de
        # pelo que pasan al lado del brazo, y la melena salia desgarrada.
        d = np.linalg.norm(V - np.array(punta), axis=1)
        cerca_pos = np.nonzero(d < r_forzado * ALCANCE_POS)[0]
        # EL FILTRO DE CARNE SOLO CUANDO SE PIDE: es para la sirena, que tiene
        # melena por encima del brazo. Al KAPPA, que es VERDE, le dejaba fuera
        # su propio brazo (96 vertices de 2.000) y la mano vieja no se envolvia.
        if os.environ.get("ESFERA_COLOR_DE", "") == "carne" and px is not None and uv is not None:
            cv = np.zeros((len(V), 3))
            nv = np.zeros(len(V))
            dentro = set(int(i) for i in cerca_pos)
            for tri in me.loop_triangles:
                for vi, li in zip(tri.vertices, tri.loops):
                    if vi in dentro:
                        u, w = uv[li].uv
                        cv[vi] += px[int(w * (H - 1)) % H, int(u * (W - 1)) % W]
                        nv[vi] += 1
            m = nv > 0
            cv[m] /= nv[m][:, None]
            carne = cerca_pos[(cv[cerca_pos][:, 0] - cv[cerca_pos][:, 1] > 0.13)
                              & (cv[cerca_pos][:, 0] > 0.35)]
            if len(carne) > 20:
                cerca_pos = carne
        mano = cerca_pos
        print("[esfera] %s: bola MEDIDA en %s (r %.4f, %d vertices dentro)"
              % (nom, tuple(round(float(x), 3) for x in punta), r_forzado, len(mano)))

    # GROSOR DEL ANTEBRAZO, medido: los vertices del codo (pesan en Elbow y
    # no en Wrist) a menos de un tramo del hueso, y su distancia al eje
    ie = grupos.get("%s_Elbow" % lado)
    r_ante = None
    cerca = None
    if ie is not None:
        pe = np.zeros(len(V))
        for i, v in enumerate(me.vertices):
            for ge in v.groups:
                if ge.group == ie:
                    pe[i] = ge.weight
        ante = np.nonzero((pe > 0.5) & (peso < 0.3))[0]
        if len(ante) > 10:
            P = V[ante] - np.array(cab)
            e = np.array(eje)
            a_long = P @ e
            cerca = ante[np.abs(a_long) < 0.06]
            if len(cerca) > 5:
                P2 = V[cerca] - np.array(cab)
                d = np.linalg.norm(P2 - np.outer(P2 @ e, e), axis=1)
                r_ante = float(np.percentile(d, 80))
    if _pos:
        r_ante = r_forzado
    if r_ante is None:
        # sin codo medible, el radio sale de la propia nube de la mano
        P = V[mano] - V[mano].mean(axis=0)
        r_ante = float(np.percentile(np.linalg.norm(P, axis=1), 60))
    radio = r_ante * RADIO

    # LA MANO ES LO QUE PESA EN LA MUÑECA **Y ESTA CERCA DE ELLA**. El rig de
    # Meshy puede meter en el grupo de la muñeca geometria que no es la mano: a
    # la SIRENA le metio la MELENA entera (10.620 vertices, con la mediana a
    # 0.316 de un modelo que mide 1.0 y llegando hasta la coronilla), asi que
    # colapsarlos le aplastaba el pelo y le encogia la cabeza. Con el filtro se
    # queda solo lo que de verdad cuelga de la muñeca.
    d_mano = np.linalg.norm(V[mano] - np.array(cab), axis=1)
    cerca_mano = mano[d_mano < r_ante * ALCANCE]
    if len(cerca_mano) >= 10:
        if len(cerca_mano) < len(mano):
            print("[esfera] %s: %d de %d vertices estaban lejos del hueso y se dejan"
                  % (nom, len(mano) - len(cerca_mano), len(mano)))
        mano = cerca_mano

    # EL COLOR SALE DEL ANTEBRAZO PEGADO A LA MUÑECA, no de la mano. La mano de
    # Meshy lleva su propio sombreado horneado y su mediana salia palida y
    # desaturada: la bola se veia de otro color que el brazo al que se pega
    # (lo dijo el usuario). Lo que tiene que casar es lo que hay JUSTO al lado.
    def _piel_de(indices, solo_carne=False):
        """Color, UV representativa y material de la piel de esos vertices."""
        if px is None or uv is None or indices is None or len(indices) < 4:
            return None
        cj = set(int(i) for i in indices)
        cols, uvs, mats = [], [], []
        for tri in me.loop_triangles:
            if all(vi in cj for vi in tri.vertices):
                mats.append(tri.material_index)
                for li in tri.loops:
                    u, w = uv[li].uv
                    uvs.append((float(u), float(w)))
                    cols.append(px[int(w * (H - 1)) % H, int(u * (W - 1)) % W])
        if len(cols) < 12:
            return None
        C = np.array(cols); U = np.array(uvs)
        if solo_carne:
            # LA CARNE SE SEPARA DEL PELO POR SATURACION EN ROJO, no por
            # luminancia: la melena crema de la sirena tambien es calida
            # (r-b 0.25) y pasaba cualquier filtro de "tono calido", pero su
            # r-g es 0.09 contra el 0.26 de la piel.
            m = (C[:, 0] - C[:, 1] > 0.13) & (C[:, 0] > 0.35)
            if m.sum() >= 12:
                C, U = C[m], U[m]
            else:
                return None
        med = np.median(C, axis=0)
        # LA UV NO PUEDE SER LA MEDIANA DE LAS UV: el atlas va troceado, asi que
        # el punto medio de un puñado de islas cae en cualquier sitio (salio en
        # el pelo, y las bolas se volvieron marrones). Se coge la UV del texel
        # cuyo COLOR mas se parece a la mediana, que por construccion es piel.
        i = int(np.argmin(np.linalg.norm(C - med, axis=1)))
        return (tuple(float(c) for c in med),
                (float(U[i][0]), float(U[i][1])),
                int(np.bincount(mats).argmax()))

    # EL COLOR SALE DE LA PROPIA MANO, no del antebrazo: en un personaje con
    # manga (David, el capitan) lo que hay pegado a la muñeca es el PUÑO de la
    # ropa, y la bola salia del color de la tela en vez de piel.
    # ESFERA_COLOR_DE=antebrazo para quien tenga la mano tapada: a la SIRENA le
    # cae la melena encima, asi que los texeles de su mano son PELO y las bolas
    # le salian color crema.
    _de = os.environ.get("ESFERA_COLOR_DE", "mano")
    if _de == "antebrazo":
        piel = _piel_de(cerca) or _piel_de(mano)
    elif _de == "carne":
        # solo texeles de carne, para quien tenga la mano tapada de pelo
        piel = (_piel_de(mano, True) or _piel_de(cerca, True)
                or _piel_de(mano) or _piel_de(cerca))
    else:
        piel = _piel_de(mano) or _piel_de(cerca)
    if piel is None:
        color, uv_piel, mat_piel = (0.87, 0.68, 0.56), None, None
    else:
        color, uv_piel, mat_piel = piel
    color = tuple(c * PIEL_K for c in color)

    def _mat(nombre, col, rug, met=0.0):
        m = bpy.data.materials.new(nombre)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*col, 1.0)
        bsdf.inputs["Roughness"].default_value = rug
        bsdf.inputs["Metallic"].default_value = met
        m.diffuse_color = (*col, 1.0)
        return m

    def _pesa(o):
        bpy.ops.object.shade_smooth()
        g = o.vertex_groups.new(name=nom)
        g.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
        esferas.append(o)

    if HOJA == lado and PUNAL_GLB:
        # 1b) EL PUÑAL DE PABLO es un MODELO aparte (Meshy): se importa, se mide
        # y se coloca con su culata en la muñeca y su eje a lo largo del brazo.
        antes = set(sc.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.abspath(PUNAL_GLB))
        nuevos = [o for o in sc.objects if o not in antes and o.type == "MESH"]
        if not nuevos:
            print("[esfera] %s: el .glb del puñal no trae malla" % nom)
        else:
            bpy.ops.object.select_all(action="DESELECT")
            for o in nuevos:
                o.select_set(True)
            bpy.context.view_layer.objects.active = nuevos[0]
            if len(nuevos) > 1:
                bpy.ops.object.join()
            o = bpy.context.object
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            co = np.array([v.co for v in o.data.vertices], dtype=np.float64)
            lo, hi = co.min(axis=0), co.max(axis=0)
            ejeloc = int(np.argmax(hi - lo))
            largo = float((hi - lo)[ejeloc])
            k = (r_ante * PUNAL_LARGO) / max(largo, 1e-9)
            # QUE EXTREMO VA EN LA MUÑECA: el GORDO (la cazoleta), no el de
            # coordenada mas baja. Por coordenada salia del reves —la punta
            # metida en la manga—, porque el .glb puede venir mirando a
            # cualquier lado.
            otros = [i for i in range(3) if i != ejeloc]
            t = co[:, ejeloc]
            L = float(hi[ejeloc] - lo[ejeloc])
            cen = (lo + hi) * 0.5
            rad = np.linalg.norm(co[:, otros] - cen[otros], axis=1)
            g_lo = float(rad[t < lo[ejeloc] + 0.2 * L].max())
            g_hi = float(rad[t > hi[ejeloc] - 0.2 * L].max())
            base_lo = g_lo >= g_hi
            for v in o.data.vertices:
                c = np.array(v.co, dtype=np.float64) - cen
                x = float(v.co[ejeloc])
                c[ejeloc] = (x - lo[ejeloc]) if base_lo else (hi[ejeloc] - x)
                v.co = Vector(c * k)
            base = [Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))]
            q = base[ejeloc].rotation_difference(eje)
            o.data.transform(q.to_matrix().to_4x4())
            o.data.transform(Matrix.Translation(M @ (cab - eje * r_ante * PUNAL_ATRAS)))
            o.name = "Punal_%s" % lado
            for m in o.data.materials:
                if m and m.use_nodes:
                    b = m.node_tree.nodes.get("Principled BSDF")
                    if b:
                        b.inputs["Emission Strength"].default_value = 0.0
                        b.inputs["Metallic"].default_value = 0.0
            _pesa(o)
            print("[esfera] %s: PUÑAL de %s, largo %.4f (x%.3f)"
                  % (nom, os.path.basename(PUNAL_GLB), largo * k, k))
        # la mano se esconde dentro de la cazoleta
        dentro = np.array(cab - eje * (r_ante * 0.45))
        V[mano] = dentro + (V[mano] - dentro) * ENCOGE
        continue

    # 1) LA MANO SE ENVUELVE SOBRE LA ESFERA, no se colapsa a un punto.
    # Colapsando al centro, la superficie que une el antebrazo con ese punto se
    # arruga y se ve un pellizco de piel justo antes de la bola (lo dijo el
    # usuario de todos los personajes con el brazo remangado). Llevando cada
    # vertice a la esfera —conservando su direccion— la piel sigue lisa y entra
    # dentro de la bola sin doblarse. El anillo de transicion se mueve en
    # proporcion a su peso, asi que el antebrazo se queda quieto.
    centro = cab + eje * (radio * AVANCE)
    cen = np.array(centro)
    # LA RAMPA VA LARGA Y SUAVE: con una banda corta, el vertice de peso 0.15
    # casi no se mueve y el de 0.3 se va entero a la bola, asi que entre los dos
    # queda un ESCALON —el labio de piel que se veia justo antes de la esfera—.
    _t = np.clip((peso - 0.02) / 0.55, 0.0, 1.0)
    peso_col = _t * _t * (3.0 - 2.0 * _t)
    if _pos:
        # con posicion medida no hay pesos fiables: manda la distancia
        # DENTRO DE LA BOLA, LA CARNE SE ENVUELVE ENTERA. Con una rampa que
        # empieza en el propio radio, lo que quedaba a media distancia se movia
        # a medias y seguia asomando: al KAPPA se le veia el PULGAR saliendo por
        # detras de la esfera (lo vio el usuario). Peso 1 hasta 1.25 radios y
        # caida suave hasta ALCANCE_POS.
        dd = np.linalg.norm(V - np.array(punta), axis=1)
        _u = np.clip((dd - r_forzado * PLANO_POS) / (r_forzado * max(ALCANCE_POS - PLANO_POS, 0.05)), 0.0, 1.0)
        peso_col = 1.0 - _u * _u * (3.0 - 2.0 * _u)
        fuera = np.ones(len(V), dtype=bool)
        fuera[mano] = False
        peso_col[fuera] = 0.0
    sel_col = np.nonzero(peso_col > 0.001)[0]
    if len(sel_col):
        dirs = V[sel_col] - cen
        nn = np.linalg.norm(dirs, axis=1, keepdims=True)
        dirs = dirs / np.maximum(nn, 1e-9)
        objetivo = cen + dirs * (radio * ENVUELVE)
        V[sel_col] = V[sel_col] + (objetivo - V[sel_col]) * peso_col[sel_col][:, None]
        # y un ALISADO corto de lo movido: al envolver, la punta del brazo se
        # queda con una arista que asoma por el canto de la bola (se veia como
        # una astilla en el Kappa). Unas pasadas de Laplaciano pesadas por el
        # mismo peso dejan el empalme liso sin tocar el antebrazo.
        if SUAVIZA > 0:
            if "_vecinos" not in dir():
                _vecinos = [[] for _ in range(len(V))]
                for e in me.edges:
                    x_, y_ = e.vertices
                    _vecinos[x_].append(y_)
                    _vecinos[y_].append(x_)
            for _ in range(SUAVIZA):
                nuevo = V.copy()
                for vi in sel_col:
                    vv = _vecinos[vi]
                    if vv:
                        nuevo[vi] = V[vi] + (V[vv].mean(axis=0) - V[vi]) * (0.55 * peso_col[vi])
                V[:] = nuevo

    # 2) la esfera
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, radius=radio,
                                         location=M @ centro)
    o = bpy.context.object
    o.name = "Esfera_%s" % lado
    # LA BOLA USA EL MATERIAL DEL CUERPO Y LA UV DE LA PIEL DEL ANTEBRAZO, no un
    # material propio de color plano: con material aparte, el color no casa —
    # el cuerpo se pinta con la textura (sRGB) y la bola con un factor lineal,
    # asi que la bola salia palida y desaturada al lado del brazo (lo dijo el
    # usuario). Apuntando todas sus UV al MISMO texel de piel, la bola se pinta
    # literalmente con el pixel que tiene al lado y no puede desentonar.
    # ESFERA_UV fuerza el texel de la bola. Hace falta cuando la bola va MEDIDA
    # y su bola de vertices toca otra cosa: al subir la del Kappa a la muñeca,
    # el caparazon entro en la seleccion y la bola salio GRANATE.
    _uvf = os.environ.get("ESFERA_UV", "")
    if _uvf:
        uv_piel = tuple(float(x) for x in _uvf.split(","))
        if mat_piel is None:
            mat_piel = 0
    if uv_piel is not None and mat_piel is not None and mat_piel < len(me.materials):
        o.data.materials.append(me.materials[mat_piel])
        capa = o.data.uv_layers.active or o.data.uv_layers.new(name="UVMap")
        for d in capa.data:
            d.uv = uv_piel
        print("[esfera] %s: material del cuerpo (%s) y UV de piel %s"
              % (nom, me.materials[mat_piel].name, tuple(round(x, 4) for x in uv_piel)))
    else:
        o.data.materials.append(_mat("PielEsfera_%s" % lado, color, 0.45))
    _pesa(o)
    print("[esfera] %s: mano de %d vertices encogida; esfera r=%.4f (antebrazo %.4f), piel %s"
          % (nom, len(mano), radio, r_ante, tuple(round(c, 2) for c in color)))

for i, v in enumerate(me.vertices):
    v.co = Vector(V[i])

# 3) unir las esferas a la malla; se llevan su grupo de vertices, o sea su skin
bpy.ops.object.select_all(action="DESELECT")
for o in esferas:
    o.select_set(True)
malla.select_set(True)
bpy.context.view_layer.objects.active = malla
if esferas:
    bpy.ops.object.join()
# el modificador Armature ya esta en la malla; las esferas heredan al unirse
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=DEST, export_format="GLB",
                          export_apply=False, export_animations=False)
print("[esfera] exportado", DEST)
