# LOS PEINADOS DEL CHEF (10 + calvo; dos mas salen de pelo_de.py), cada uno tintable en 5 colores.
#
# El chef es personalizable, asi que el pelo no puede venir dentro del modelo:
# son piezas sueltas que el juego cuelga del hueso `Head`. Y aqui esta la idea
# que lo sostiene: EL PELO ES UNA CASCARA DEL PROPIO CRANEO, no una pieza
# modelada aparte. Se copian las caras de la cabeza que caen por encima de la
# linea del pelo, se separan a un pelo de la piel y se les da grosor — asi el
# peinado no puede flotar ni meterse dentro de la cabeza, por raro que sea el
# craneo, y todos calzan igual sin un solo numero puesto a ojo.
#
# Lo que cambia de un peinado a otro son tres cosas:
#   · la LINEA DEL PELO, dada por su altura en el FRENTE, el LADO y la NUCA
#     (en coordenadas de la cabeza: la u.z de la direccion desde su centro);
#   · la MELENA, que se extruye del borde de abajo de la cascara y cae por los
#     lados y la nuca (nunca por delante: por ahi esta la cara);
#   · los REMATES: flequillo, tupe, coleta, moño o coletas.
#
# El color NO va horneado: el material va en BLANCO y lo tiñe el juego con
# `albedo_color`, que multiplica. Por eso 11 peinados x 5 colores salen de 10
# mallas y ni una textura.
#
#   blender --background --python tools/blender/chef_pelo.py -- <cuerpo.glb> <carpeta> [ids...]
import bpy, sys, os, math, bmesh
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
SRC = os.path.abspath(a[0])
OUT = os.path.abspath(a[1])
SOLO = a[2:] if len(a) > 2 else []
os.makedirs(OUT, exist_ok=True)

SEP = float(os.environ.get("PELO_SEP", 0.010))        # separacion de la piel, en radios
GROSOR = float(os.environ.get("PELO_GROSOR", 0.055))  # grosor de la mata, idem
# LA CASCARA HEREDA LA DENSIDAD DEL CUERPO, que son 50.000 vertices: sin
# decimar, un peinado salia con 55.000 caras — mas que el personaje entero.
CARAS = int(os.environ.get("PELO_CARAS", 2200))

# Cada peinado: linea del pelo (frente / lado / nuca, en u.z de -1 a 1), melena
# (pasos, largo por paso, vuelo, afilado) y remates.
PEINADOS = {
    # --- masculinos ---------------------------------------------------------
    "corto":   dict(frente=0.46, lado=0.06, nuca=-0.16),
    # DESPEINADO: la mata corta y encima PICOS a distintas alturas y angulos.
    # Un tupe (un solo bulto delante) no se distinguia de un corte normal; lo
    # que se lee como anime es la silueta ROTA, con mechones sueltos que salen
    # en varias direcciones. Cada pico: direccion (x, y, z), largo y ancho en
    # radios de cabeza, y cuanto se endereza hacia arriba.
    # SEIS PICOS GORDOS, NO NUEVE FINOS: con mechones estrechos y de punta el
    # peinado se leia como un erizo, no como un pelo revuelto. Lo que lo hace
    # anime es que los mechones sean ANCHOS y salgan tumbados hacia delante y
    # a los lados, no de pie.
    # DESPEINADO: no son piezas pegadas, es la PROPIA MATA abollada. Se probo
    # con conos —primero nueve finos, luego seis gordos, luego enderezados— y
    # las tres veces salio lo mismo: un ANILLO DE PUAS alrededor de la
    # coronilla, porque un cono tiene su base y se le ve. Empujando la cascara
    # hacia fuera en varios sitios, la silueta se rompe sin una sola junta, que
    # es lo que se lee como pelo revuelto. Cada bulto: direccion, cuanto sale
    # (en radios), lo ancho que es (en radianes) y cuanto se tumba hacia arriba.
    "despeinado": dict(frente=0.42, lado=0.06, nuca=-0.16, grosor=0.075, bultos=[
        (0.00, -0.60, 0.80, 0.38, 0.30, 0.75),
        (-0.44, -0.44, 0.78, 0.34, 0.27, 0.80),
        (0.48, -0.36, 0.80, 0.32, 0.26, 0.80),
        (-0.22, 0.06, 0.97, 0.36, 0.28, 0.35),
        (0.30, 0.04, 0.95, 0.30, 0.25, 0.35),
        (-0.66, 0.10, 0.74, 0.28, 0.24, 0.75),
        (0.68, 0.16, 0.72, 0.28, 0.24, 0.75),
        (-0.34, 0.56, 0.75, 0.30, 0.25, 0.70),
        (0.26, 0.62, 0.74, 0.28, 0.24, 0.70),
    ]),
    # CON FLEQUILLO: la linea del pelo baja hasta media frente y el flequillo se
    # extruye del PROPIO borde de la mata, no es un bulto pegado — asi cuelga de
    # donde nace el pelo y no se le ve la junta.
    "flequillo": dict(frente=0.16, lado=0.08, nuca=-0.18,
                      caida=(3, 0.055, 1.02, 0.94)),
    # --- femeninos ----------------------------------------------------------
    "bob":     dict(frente=0.26, lado=0.02, nuca=-0.24, flequillo=("recto", 1.0),
                    melena=(5, 0.060, 1.06, 0.98)),
    # LAS MELENAS LARGAS CAEN POR DETRAS DE LOS HOMBROS: los mechones de
    # delante de la oreja se cortan a la altura de la mandibula (`frente_pasos`)
    # y solo la parte de atras sigue bajando. Cayendo entera por delante, en la
    # cinta la melena mas la barba se leian como un MANTO que tapaba el cuerpo
    # (lo vio el usuario).
    "melena":  dict(frente=0.32, lado=0.02, nuca=-0.26,
                    melena=(9, 0.075, 1.05, 0.99), frente_pasos=3),
    "larga":   dict(frente=0.34, lado=0.02, nuca=-0.26,
                    melena=(20, 0.075, 1.05, 0.995), frente_pasos=3),
    "mono":    dict(frente=0.36, lado=0.06, nuca=-0.18, mono=1.0),
    "coletas": dict(frente=0.30, lado=0.02, nuca=-0.24, coletas=1.0,
                    melena=(3, 0.050, 1.05, 0.98)),
}
if SOLO:
    PEINADOS = dict((k, v) for k, v in PEINADOS.items() if k in SOLO)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
sc = bpy.context.scene
cuerpo = max((o for o in sc.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
arm = next((o for o in sc.objects if o.type == "ARMATURE"), None)
M = cuerpo.matrix_world
vs = [M @ v.co for v in cuerpo.data.vertices]
lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
alto = hi.z - lo.z
anchos = []
for k in range(30, 62):
    z = lo.z + alto * k / 100.0
    banda = [v for v in vs if abs(v.z - z) < alto * 0.01]
    if len(banda) > 20:
        anchos.append((max(v.x for v in banda) - min(v.x for v in banda), z))
z_cuello = min(anchos)[1] if anchos else lo.z + alto * 0.55
alto_cab = hi.z - z_cuello

# EL CENTRO DE LA CABEZA no es su centroide (la cara y las orejas lo corren):
# es el centro de la CAJA del craneo, que es lo que hace que las direcciones
# salgan simetricas y la linea del pelo caiga igual a los dos lados.
P = np.array([[v.x, v.y, v.z] for v in vs])
cab = P[P[:, 2] > z_cuello + alto_cab * 0.10]
C = Vector((0.0,
            float(cab[:, 1].min() + cab[:, 1].max()) / 2.0,
            float(cab[:, 2].min() + cab[:, 2].max()) / 2.0))
R = float(np.median(np.linalg.norm(cab - np.array(C), axis=1)))
print("[pelo] cabeza: centro (%.3f, %.3f, %.3f) radio %.4f, alto_cab %.4f"
      % (C.x, C.y, C.z, R, alto_cab))
# LAS OREJAS se miden para saber por donde puede bajar la linea del pelo sin
# partir una por la mitad.
anchura = np.abs(cab[:, 0])
orej = cab[anchura > np.percentile(anchura, 99.0)]
OREJA_X, OREJA_Z0, OREJA_Z1 = R * 1.12, C.z, C.z
if len(orej):
    OREJA_X = float(anchura.max())
    OREJA_Z0, OREJA_Z1 = float(orej[:, 2].min()), float(orej[:, 2].max())
    print("[pelo] orejas: |x| hasta %.4f, z de %.3f a %.3f"
          % (OREJA_X, OREJA_Z0, OREJA_Z1))

mat = bpy.data.materials.new("Pelo")
mat.use_nodes = True
_b = mat.node_tree.nodes["Principled BSDF"]
_b.inputs["Base Color"].default_value = (1.0, 1.0, 1.0, 1.0)
_b.inputs["Roughness"].default_value = 0.42
mat.diffuse_color = (1.0, 1.0, 1.0, 1.0)


def _u(p):
    return Vector((p[0] - C.x, p[1] - C.y, p[2] - C.z)).normalized()


def _linea(u, frente, lado, nuca, entradas=0.0):
    """Altura (u.z) de la linea del pelo en esa direccion."""
    h = Vector((u.x, u.y, 0.0))
    if h.length < 1e-6:
        return -1.0
    h.normalize()
    delante = max(-h.y, 0.0)      # el personaje mira a -Y
    detras = max(h.y, 0.0)
    z = lado + (frente - lado) * delante + (nuca - lado) * detras
    # LAS ENTRADAS son dos golfos: suben la linea a los lados de la frente y la
    # dejan como estaba en el medio.
    if entradas > 0.0:
        z += entradas * delante * (abs(h.x) ** 1.6)
    return z


def _pesar(o):
    """Pesa la pieza al esqueleto del chef, POR ALTURA.

    El chef se anima con `CharacterAnim`, que gira huesos, asi que una pieza
    colgada del hueso de la CABEZA gira entera con ella: una melena que llega a
    media pierna barreria el cuerpo en cada cabeceo. Repartiendo por altura
    —cabeza arriba, cuello en la transicion y tronco abajo— la mata sigue a la
    cabeza y las puntas al cuerpo, que es lo que hace el pelo de verdad.

    El reparto es una Bezier cuadratica (t², 2t(1-t), (1-t)²), que suma 1 en
    todo punto: sin eso, en la franja de mezcla la pieza se encoge.
    """
    if arm is None:
        return
    for n in ("Head", "Neck", "Spine1"):
        if n not in [g.name for g in o.vertex_groups]:
            o.vertex_groups.new(name=n)
    gh = o.vertex_groups["Head"]
    gn = o.vertex_groups["Neck"]
    gs = o.vertex_groups["Spine1"]
    z_alto = z_cuello + alto_cab * 0.10
    z_bajo = z_cuello - alto_cab * 0.60
    for v in o.data.vertices:
        z = (M @ v.co).z
        t = max(0.0, min(1.0, (z - z_bajo) / (z_alto - z_bajo)))
        gh.add([v.index], t * t, "REPLACE")
        gn.add([v.index], 2.0 * t * (1.0 - t), "REPLACE")
        gs.add([v.index], (1.0 - t) * (1.0 - t), "REPLACE")
    o.parent = arm
    o.matrix_parent_inverse = arm.matrix_world.inverted()
    m = o.modifiers.new("Esqueleto", "ARMATURE")
    m.object = arm


def _pintar(o):
    o.data.materials.clear()
    o.data.materials.append(mat)


def _exportar(objs, nombre):
    for o in objs:
        _pesar(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    if arm is not None:
        arm.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    ruta = os.path.join(OUT, nombre + ".glb")
    bpy.ops.export_scene.gltf(filepath=ruta, export_format="GLB",
                              use_selection=True, export_apply=False,
                              export_animations=False)
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)
    return ruta


def _casquete(cfg):
    """La CASCARA: las caras del craneo por encima de la linea del pelo."""
    me = cuerpo.data.copy()
    o = bpy.data.objects.new("Pelo", me)
    sc.collection.objects.link(o)
    o.matrix_world = M
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    fuera = []
    for f in bm.faces:
        w = M @ f.calc_center_median()
        if w.z < z_cuello:
            fuera.append(f)
            continue
        # LAS OREJAS NUNCA SON PELO: sobresalen mucho mas que el craneo (medido:
        # |x| 0.25 contra un radio de 0.18), asi que una cascara que las incluya
        # sale con forma de oreja en vez de con forma de mata. Los peinados que
        # las tapan lo hacen con la MELENA, que pasa por fuera.
        if abs(w.x) > R * 1.12:
            fuera.append(f)
            continue
        u = _u((w.x, w.y, w.z))
        if u.z < _linea(u, cfg["frente"], cfg["lado"], cfg["nuca"],
                        cfg.get("entradas", 0.0)):
            fuera.append(f)
    bmesh.ops.delete(bm, geom=fuera, context="FACES")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    # SE SEPARA DE LA PIEL a lo largo de la normal: pegado, el pelo y la cabeza
    # pelean por el mismo pixel y salen rayas de z-fighting.
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * (SEP * R)
    bm.to_mesh(me)
    bm.free()
    me.update()
    return o


def _melena(o, cfg):
    """Extruye el borde de abajo de la cascara y lo deja caer por los lados y
    la nuca. Nunca por delante: por ahi esta la cara."""
    pasos, largo, vuelo, afila = cfg["melena"]
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.edges.ensure_lookup_table()
    Mi = M.inverted()
    # LA MELENA CAE POR DETRAS DE LAS OREJAS, no por encima. Se probo lo otro
    # —abrir la cortina hasta librarlas— y hacen falta 1.35 de vuelo (orejas a
    # |x| 0.25 contra un craneo de 0.185): el vuelo se compone paso a paso y la
    # melena salia como dos ALAS enormes, mas anchas que los hombros. El pelo
    # que enmarca la cara lo ponen los MECHONES, que pasan por DELANTE de la
    # oreja y no tienen que rodear nada.
    sel = []
    for e in bm.edges:
        if not e.is_boundary:
            continue
        w = M @ ((e.verts[0].co + e.verts[1].co) / 2.0)
        h = Vector((w.x - C.x, w.y - C.y, 0.0))
        if h.length < 1e-6 or (-h.normalized().y) > 0.62:
            continue          # la FRENTE: por ahi no cae pelo
        sel.append(e)
    frente_pasos = int(cfg.get("frente_pasos", 10 ** 6))
    for i in range(pasos):
        if i >= frente_pasos:
            # de aqui abajo solo sigue lo que queda DETRAS de las orejas
            sel = [e for e in sel
                   if (lambda w: Vector((w.x - C.x, w.y - C.y, 0.0)))(
                       M @ ((e.verts[0].co + e.verts[1].co) / 2.0)).normalized().y > 0.05]
        if not sel:
            break
        ret = bmesh.ops.extrude_edge_only(bm, edges=sel)
        nv = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMVert)]
        # el vuelo abre la melena los primeros pasos y el afilado la cierra
        # despues: eso es lo que la hace acabar en punta y no en tubo.
        # OJO: el factor es POR PASO. Se llevaba acumulado y se aplicaba encima
        # sobre el anillo anterior —que ya lo traia—, o sea que crecia con el
        # CUADRADO de los pasos: la melena de 22 pasos salia como una CAPA mas
        # ancha que la figura, y antes, con menos pasos, como dos alas.
        esc = vuelo if i < max(2, pasos // 5) else afila
        for v in nv:
            w = M @ v.co
            rx, ry = w.x - C.x, w.y - C.y
            w.z -= largo * alto_cab
            w.x = C.x + rx * esc
            w.y = C.y + ry * esc
            v.co = Mi @ w
        sel = [g for g in ret["geom"]
               if isinstance(g, bmesh.types.BMEdge) and g.is_boundary]
    bm.to_mesh(me)
    bm.free()
    me.update()


def _sobre_orejas(o):
    """Abomba la melena a la altura de las orejas para que las tape.

    Sin esto, la oreja ASOMA por la mata (sobresale a |x| 0.25 y el craneo mide
    0.185) y se lee como un manchon de piel en mitad del pelo. Y no vale
    abrirla desde el borde: el vuelo se compone paso a paso y salen alas. Es un
    bombo LOCAL, con caida por arriba y por abajo, que es como se comporta el
    pelo de verdad sobre una oreja.
    """
    me = o.data
    Mi = M.inverted()
    alto_or = max(OREJA_Z1 - OREJA_Z0, 1e-6)
    rmin = OREJA_X * 1.10
    for v in me.vertices:
        w = M @ v.co
        rx, ry = w.x - C.x, w.y - C.y
        r = math.hypot(rx, ry)
        if r < 1e-6:
            continue
        # solo a los lados: por delante esta la cara y por detras no hay oreja
        lat = abs(rx) / r
        if lat < 0.45:
            continue
        t = 1.0 - abs(w.z - (OREJA_Z0 + OREJA_Z1) * 0.5) / (alto_or * 1.5)
        if t <= 0.0:
            continue
        t = min(1.0, t) * ((lat - 0.45) / 0.55)
        objetivo = max(r, rmin)
        nr = r + (objetivo - r) * (t * t * (3.0 - 2.0 * t))
        w.x = C.x + rx * nr / r
        w.y = C.y + ry * nr / r
        v.co = Mi @ w
    me.update()


def _caida_frente(o, cfg):
    """El FLEQUILLO, extruido del borde de delante de la mata."""
    pasos, largo, vuelo, afila = cfg["caida"]
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.edges.ensure_lookup_table()
    Mi = M.inverted()
    sel = []
    for e in bm.edges:
        if not e.is_boundary:
            continue
        w = M @ ((e.verts[0].co + e.verts[1].co) / 2.0)
        h = Vector((w.x - C.x, w.y - C.y, 0.0))
        if h.length < 1e-6 or (-h.normalized().y) < 0.45:
            continue
        sel.append(e)
    for i in range(pasos):
        if not sel:
            break
        ret = bmesh.ops.extrude_edge_only(bm, edges=sel)
        nv = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMVert)]
        esc = vuelo if i == 0 else afila
        for v in nv:
            w = M @ v.co
            rx, ry = w.x - C.x, w.y - C.y
            w.z -= largo * alto_cab
            w.x = C.x + rx * esc
            w.y = C.y + ry * esc
            v.co = Mi @ w
        sel = [g for g in ret["geom"]
               if isinstance(g, bmesh.types.BMEdge) and g.is_boundary]
    bm.to_mesh(me)
    bm.free()
    me.update()


def _revolver(o, cfg):
    """Abolla la mata: la despeina empujandola hacia fuera en varios sitios."""
    me = o.data
    Mi = M.inverted()
    for v in me.vertices:
        w = M @ v.co
        d = Vector((w.x - C.x, w.y - C.y, w.z - C.z))
        if d.length < 1e-6:
            continue
        u = d.normalized()
        des = Vector((0.0, 0.0, 0.0))
        for bx, by, bz, amp, rad, arr in cfg["bultos"]:
            b = Vector((bx, by, bz)).normalized()
            ang = math.acos(max(-1.0, min(1.0, u.dot(b))))
            if ang >= rad:
                continue
            t = 1.0 - (ang / rad) ** 2
            des += (b + Vector((0.0, 0.0, arr))).normalized() * (amp * R * t * t * t)
        if des.length > 1e-9:
            v.co = Mi @ (w + des)
    me.update()


def _pico(nombre, d, largo, ancho, arriba):
    """Un MECHON de punta, saliendo del craneo en esa direccion."""
    d = Vector(d).normalized()
    eje = (d + Vector((0.0, 0.0, arriba))).normalized()
    base = C + d * (R * 0.92)
    bpy.ops.mesh.primitive_cone_add(vertices=14, radius1=ancho * R,
                                    radius2=ancho * R * 0.10,
                                    depth=largo * R,
                                    location=base + eje * (largo * R * 0.5))
    o = bpy.context.object
    o.name = nombre
    o.rotation_euler = Vector((0.0, 0.0, 1.0)).rotation_difference(eje).to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.shade_smooth()
    _pintar(o)
    return o


def _bulto(nombre, centro, escala, giro=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=26, ring_count=14, radius=1.0,
                                         location=centro)
    o = bpy.context.object
    o.name = nombre
    o.scale = escala
    o.rotation_euler = giro
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.shade_smooth()
    _pintar(o)
    return o


def _en_cabeza(ux, uy, uz, fuera=1.0):
    """Punto a `fuera` radios del centro de la cabeza en esa direccion."""
    return C + Vector((ux, uy, uz)).normalized() * (R * fuera)


for nombre, cfg in PEINADOS.items():
    o = _casquete(cfg)
    if "bultos" in cfg:
        _revolver(o, cfg)
    if "caida" in cfg:
        _caida_frente(o, cfg)
    if "melena" in cfg:
        _melena(o, cfg)
        _sobre_orejas(o)
    m = o.modifiers.new("Grosor", "SOLIDIFY")
    m.thickness = cfg.get("grosor", GROSOR) * R
    m.offset = 1.0
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=m.name)
    if len(o.data.polygons) > CARAS:
        d = o.modifiers.new("Decima", "DECIMATE")
        d.ratio = float(CARAS) / len(o.data.polygons)
        bpy.ops.object.modifier_apply(modifier=d.name)
    bpy.ops.object.shade_smooth()
    _pintar(o)
    piezas = [o]

    if "flequillo" in cfg:
        clase, k = cfg["flequillo"]
        if clase == "recto":
            # EL FLEQUILLO NO PUEDE TAPAR LOS OJOS: con el bulto gordo salia
            # como una visera. Va alto y aplastado, rozando la linea del pelo.
            p = _en_cabeza(0.0, -1.0, cfg["frente"] - 0.05, 1.02)
            piezas.append(_bulto("Flequillo", p,
                                 (R * 0.66, R * 0.26, R * 0.17 * k)))
        else:
            p = _en_cabeza(0.30, -1.0, cfg["frente"] - 0.10, 1.02)
            piezas.append(_bulto("Flequillo", p,
                                 (R * 0.52, R * 0.26, R * 0.20 * k),
                                 giro=(0.0, math.radians(-18.0), 0.0)))
    if "picos" in cfg:
        for i, (px_, py_, pz_, lg, an, ar) in enumerate(cfg["picos"]):
            piezas.append(_pico("Pico%d" % i, (px_, py_, pz_), lg, an, ar))
    if "tupe" in cfg:
        p = _en_cabeza(0.0, -0.72, 0.86, 1.02)
        piezas.append(_bulto("Tupe", p, (R * 0.36, R * 0.30, R * 0.34),
                             giro=(math.radians(-24.0), 0.0, 0.0)))
    if "cola" in cfg:
        p = _en_cabeza(0.0, 1.0, -0.10, 1.02)
        piezas.append(_bulto("Cola", p + Vector((0, R * 0.12, -R * 0.34)),
                             (R * 0.17, R * 0.20, R * 0.42)))
        piezas.append(_bulto("Goma", p, (R * 0.13, R * 0.13, R * 0.10)))
    if "mono" in cfg:
        p = _en_cabeza(0.0, 0.55, 1.0, 1.02)
        piezas.append(_bulto("Mono", p, (R * 0.34, R * 0.34, R * 0.30)))
    if "coletas" in cfg:
        for s in (1.0, -1.0):
            lado = "L" if s > 0 else "R"
            p = _en_cabeza(s * 1.0, 0.30, 0.18, 1.26)
            piezas.append(_bulto("Coleta" + lado,
                                 p + Vector((s * R * 0.16, 0, -R * 0.42)),
                                 (R * 0.21, R * 0.21, R * 0.48)))
            piezas.append(_bulto("Goma" + lado, p, (R * 0.13, R * 0.13, R * 0.11)))
    caras = sum(len(p.data.polygons) for p in piezas)
    ruta = _exportar(piezas, "chef_pelo_" + nombre)
    print("[pelo] %-8s %d piezas, %d caras -> %s"
          % (nombre, len(piezas), caras, os.path.basename(ruta)))
print("[pelo] listos en %s" % OUT)
