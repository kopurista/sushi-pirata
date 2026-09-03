# Le quita los DEDOS a las manos de David y las deja en MUÑÓN redondeado
# (pedido por el usuario: "quitarle los dedos de las manos, todos, incluido el
# pulgar, para que sea solo un muñón. Así no habrá una 'palma' de mano, y se
# podrá hacer el movimiento de forma fluida").
#
# Una manopla con pulgar obliga a que el giro de muñeca signifique algo —hay un
# derecho y un revés—, y a esta escala eso no se lee: solo se ve el bulto
# deformarse. Sin pulgar, girar la muñeca es girar un bulto y siempre queda
# bien.
#
# Los dedos NO se borran (dejaría agujeros): la mano se EMPUJA hacia el
# elipsoide que mejor la envuelve, con la mezcla a 0 en la muñeca y a 1 en la
# punta, así que el saliente del pulgar se funde en el bulto y la unión con la
# manga no se mueve ni un milímetro.
#
#   blender --background --python tools/blender/david_munon.py -- <entrada.glb> <salida.glb>
import bpy, sys, os
import bmesh
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
SRC = os.path.abspath(a[0])
DEST = os.path.abspath(a[1])
PCT = float(os.environ.get("MUNON_PCT", 95.0))
FUERZA = float(os.environ.get("MUNON_FUERZA", 1.0))   # cuánto se redondea
SUAVE = int(os.environ.get("MUNON_SUAVE", 14))         # pasadas de suavizado

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
sc = bpy.context.scene
malla = max((o for o in sc.objects if o.type == "MESH"),
            key=lambda o: len(o.data.vertices))
me = malla.data

# SOLDAR PRIMERO. La malla de Meshy viene PARTIDA en cada costura del atlas
# (medido: 7.311 aristas abiertas de 15.327 caras), así que al mover un vértice
# su gemelo se queda quieto y la superficie se ABRE: en la mano aparecía un
# arco negro que no cambiaba por muchas pasadas de suavizado que se dieran
# —la pista de que no lo causaba el suavizado—. Se sueldan solo los duplicados
# exactos, con bmesh para no entrar en modo edición.
bm = bmesh.new()
bm.from_mesh(me)
antes_v = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
bm.to_mesh(me)
bm.free()
me.update()
print("[munon] soldado: %d -> %d vértices, aristas abiertas %d"
      % (antes_v, len(me.vertices),
         sum(1 for k, n in
             ((ek, sum(1 for p in me.polygons if ek in p.edge_keys)) for ek in [])
             ) or -1))

V = np.array([v.co for v in me.vertices], dtype=np.float64)

# La mano es lo que pesa en su muñeca: se pregunta al skin, no se adivina por
# coordenadas (la mano cuelga a una altura distinta en cada brazo).
grupos = {g.name: g.index for g in malla.vertex_groups}
manos = []
print("[munon] grupos:", sorted(grupos))
for lado in ("L", "R"):
    nom = "%s_Wrist" % lado
    if nom not in grupos:
        print("[munon] sin grupo %s" % nom)
        continue
    gi = grupos[nom]
    peso = np.zeros(len(V))
    for i, v in enumerate(me.vertices):
        for ge in v.groups:
            if ge.group == gi:
                peso[i] = ge.weight
    sel = np.nonzero(peso > 0.5)[0]
    if len(sel) < 20:
        print("[munon] %s: solo %d vértices, se salta" % (nom, len(sel)))
        continue
    P = V[sel]
    centro = P.mean(axis=0)
    Q = P - centro
    # ejes propios de la nube: el largo de la mano, su ancho y su grosor
    _u, _s, Vt = np.linalg.svd(Q, full_matrices=False)
    ejes = Vt                      # filas = ejes principales
    L = Q @ ejes.T                 # la mano en su propio sistema
    # radios del elipsoide: el percentil 82 en cada eje. La MEDIANA deja la
    # mano flaca y el máximo la hincha hasta la punta del pulgar.
    rad = np.percentile(np.abs(L), PCT, axis=0)
    rad = np.maximum(rad, 1e-6)
    # LA MEZCLA VA POR DISTANCIA AL HUESO DE LA MUÑECA, no a lo largo del eje
    # de la mano. Con la rampa longitudinal el PULGAR sobrevivía siempre, y por
    # una razón tonta: nace pegado a la muñeca, que es justo donde la mezcla
    # valía 0 para no despegar la mano de la manga.
    hueso = None
    for arm in [o for o in sc.objects if o.type == "ARMATURE"]:
        b = arm.data.bones.get(nom)
        if b:
            hueso = np.array(malla.matrix_world.inverted() @ (arm.matrix_world @ b.head_local))
    if hueso is None:
        hueso = centro
    d = np.linalg.norm(P - hueso, axis=1)
    r = float(np.percentile(np.abs(L), PCT, axis=0).max())
    t = np.clip((d - r * 0.20) / max(r * 0.55, 1e-9), 0.0, 1.0)
    mezcla = (t * t * (3.0 - 2.0 * t)) * FUERZA

    # se proyecta TODA la mano, no solo lo que sobresale: hundiendo solo los
    # salientes quedaba un ESCALÓN donde estaba el pulgar
    N = L / rad
    n = np.linalg.norm(N, axis=1, keepdims=True)
    Lp = (N / np.maximum(n, 1e-9)) * rad
    Lnuevo = L + (Lp - L) * mezcla[:, None]
    V[sel] = centro + Lnuevo @ ejes
    print("[munon] %s: %d vértices sobresalían del elipsoide" % (nom, int((n[:, 0] > 1.0).sum())))
    manos.append((nom, sel, mezcla))
    print("[munon] %s: %d vértices, radios %s" % (nom, len(sel), np.round(rad, 4)))

# EL MUÑÓN SE HACE DERRITIENDO EL PULGAR, NO PROYECTANDO AL ELIPSOIDE. Se probó
# lo segundo y el pulgar tiene vértices que al proyectarse se cruzan con los de
# la palma: las caras se invierten y la mano sale RASGADA, con agujeros. Aquí se
# aplica suavizado de TAUBIN (una pasada que encoge y otra que devuelve, λ y μ),
# que quita los salientes sin tocar la topología ni desinflar el bulto — un
# Laplaciano a secas, con las pasadas que hacen falta para comerse el pulgar,
# deja la mano en una lenteja.
#
# Y va por código, no con `bpy.ops.mesh.vertices_smooth`: esa operación pide
# entrar en modo edición, y entrando con el armature todavía seleccionado la
# malla salía EXPLOTADA en trozos.
vecinos = [[] for _ in range(len(me.vertices))]
for e in me.edges:
    a_, b_ = e.vertices
    vecinos[a_].append(b_)
    vecinos[b_].append(a_)
LAMBDA = 0.60
MU = -0.62
for lado, sel, mezcla in manos:
    antes = V[sel].copy()
    for it in range(SUAVE * 2):
        f0 = LAMBDA if it % 2 == 0 else MU
        nuevoV = V.copy()
        for k, vi in enumerate(sel):
            vv = vecinos[vi]
            if not vv:
                continue
            media = V[vv].mean(axis=0)
            nuevoV[vi] = V[vi] + (media - V[vi]) * (f0 * mezcla[k])
        V[:] = nuevoV
    movido = float(np.abs(V[sel] - antes).max())
    print("[munon] %s: %d pasadas de Taubin, el vértice que más se movió %.4f"
          % (lado, SUAVE, movido))

for i, v in enumerate(me.vertices):
    v.co = Vector(V[i])

# LAS NORMALES PERSONALIZADAS DEL GLB HAY QUE TIRARLAS. Vienen horneadas de
# Meshy y no se recalculan al mover vértices: la zona movida se quedaba con las
# normales viejas y en el render salía un AGUJERO NEGRO con forma de arco en
# mitad de la mano (parecía la malla rota, y estaba entera). Es la misma
# lección que ya costó una pasada en david_la.py.
bpy.ops.object.select_all(action="DESELECT")
malla.select_set(True)
bpy.context.view_layer.objects.active = malla
try:
    bpy.ops.mesh.customdata_custom_splitnormals_clear()
except Exception as e:
    print("[munon] sin normales personalizadas que borrar (%s)" % e)
bpy.ops.object.shade_smooth()
me.update()
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=DEST, export_format="GLB",
                          export_apply=False, export_animations=False)
print("[munon] exportado", DEST)
