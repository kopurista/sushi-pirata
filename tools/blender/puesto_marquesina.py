# EL PUESTO DE SAVERIO CON EL TOLDO ABIERTO HACIA ARRIBA (7-9-2026).
#
# El puesto de Meshy (`la_puesto.glb`, concepto de Ludo) trae el toldo como un
# toldo de verdad: cae hacia el cliente. Con la camara isometrica de la tienda
# (35 grados de picado) eso deja al tendero DEBAJO de la tela y no se le ve
# —medido: con el puesto a 3,4 u de alto la cabeza de Saverio queda 33 px por
# debajo del canto del toldo—, que es justo el problema que el puesto viejo
# hecho a mano resolvia con el toldo SUBIENDO hacia delante, como una
# marquesina. Ludo no supo dibujarlo asi (dos tandas), asi que se opera aqui:
#   1. fuera el toldo, el faldon y los remates de los postes (todo lo que
#      queda por encima de y 0.205 en el modelo normalizado);
#   2. los cuatro postes se alargan con un cilindro que hereda la madera
#      del propio poste (todas sus UV apuntan al texel de un poste);
#   3. una MARQUESINA nueva —una lona ligeramente combada, alta por delante
#      (y 0.50) y baja por detras (0.32)— con sus rayas rojas y crema en una
#      textura propia dibujada aqui mismo.
#
#   blender --background --python tools/blender/puesto_marquesina.py -- \
#       <in.glb> <out.glb>
import bpy, bmesh, math, sys, os
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
src, dst = os.path.abspath(a[0]), os.path.abspath(a[1])
CORTE = 0.205            # por encima de esto es toldo (medido)
FRENTE_Y, ATRAS_Y = 0.56, 0.40
Z_ATRAS, Z_FRENTE = -0.40, 0.34
X_MEDIO = 0.46

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
sc = bpy.context.scene
obj = [o for o in sc.objects if o.type == "MESH"][0]
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = obj.data
# ---- 1. fuera el toldo ------------------------------------------------------
# OJO con los ejes: el importador de glTF pasa la Y de Godot a la Z de Blender
bm = bmesh.new()
bm.from_mesh(me)
postes_xy = [(-0.36, -0.29), (0.36, -0.29), (-0.36, 0.30), (0.36, 0.30)]
def es_poste(c):
    return min(math.hypot(c.x - px, c.y - py) for px, py in postes_xy) < 0.06
uv_lay = bm.loops.layers.uv.active
# LA TELA SE RECONOCE POR SU COLOR EN EL ATLAS: el toldo de Meshy no es solo
# la tapa (lo que queda por encima del corte), tambien un ENVES y un faldon
# que bajan hasta media altura del puesto y cuyas normales van como quieren
# (Meshy). Por posicion no se distinguian de las baldas; por el rojo y el
# crema de sus rayas, si (visto en render: quedaba una lona flotando).
imagen = None
for nd in obj.active_material.node_tree.nodes:
    if nd.type == "TEX_IMAGE" and nd.image is not None:
        imagen = nd.image
W_, H_ = imagen.size
PX = np.array(imagen.pixels[:], dtype=np.float32).reshape(H_, W_, 4)
def color_uv(uv):
    x = int(uv.x * W_) % W_
    y = int(uv.y * H_) % H_
    return PX[y, x, :3]
def es_tela(f):
    c = color_uv(f.loops[0][uv_lay].uv)
    rojo = c[0] > 0.45 and c[1] < 0.35 and c[2] < 0.35
    crema = c[0] > 0.70 and c[1] > 0.62 and c[2] > 0.48
    return rojo or crema
def sobra(f):
    c = f.calc_center_median()
    if c.z > CORTE:
        return True
    if es_poste(c) and not es_tela(f):
        return False
    return c.z > 0.05 and es_tela(f)
fuera = [f for f in bm.faces if sobra(f)]
print("[puesto] caras del toldo fuera: %d de %d" % (len(fuera), len(bm.faces)))
bmesh.ops.delete(bm, geom=fuera, context="FACES")
# el texel de un poste: una cara de poste (por proximidad al eje) a media
# altura, que es madera; la mas alta era ya un canto del toldo (rojo)
mejor = None
for f in bm.faces:
    c = f.calc_center_median()
    if es_poste(c) and -0.2 < c.z < 0.15 and not es_tela(f) and (mejor is None or c.z > mejor[0]):
        mejor = (c.z, f.loops[0][uv_lay].uv.copy())
uv_poste = mejor[1] if mejor else Vector((0.5, 0.5))
print("[puesto] texel de poste", uv_poste)
# postes: sus posiciones x/y (Blender) son las esquinas del mostrador
postes = [(-0.36, -0.29), (0.36, -0.29), (-0.36, 0.30), (0.36, 0.30)]   # (x, y_blender) ; y_blender = -z_godot
for (px, py) in postes:
    # el canto delantero del puesto es +z de Godot = -y de Blender
    delante = py < 0.0
    tope = FRENTE_Y if delante else ATRAS_Y
    r = 0.028
    geom = bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=r, radius2=r, depth=tope - 0.15)
    for v in geom["verts"]:
        v.co = Vector((v.co.x + px, v.co.y + py, v.co.z + 0.15 + (tope - 0.15) * 0.5))
    for v in geom["verts"]:
        for l in v.link_loops:
            l[uv_lay].uv = uv_poste
# LA TAPA DE LA ESTANTERIA lleva pintadas las RAYAS del toldo: Meshy proyecta
# la textura desde la vista y esa cara, tapada por el toldo, se quedo con lo
# que habia encima; sin toldo asomaba como una lona rayada flotando (visto en
# render). Sus UV pasan al texel del tablero del mostrador: madera lisa.
uv_tablero = None
for f in bm.faces:
    c = f.calc_center_median()
    if f.normal.z > 0.6 and -0.30 < c.z < -0.25 and abs(c.x) < 0.2 and c.y < -0.1:
        uv_tablero = f.loops[0][uv_lay].uv.copy()
        break
if uv_tablero is not None:
    n_re = 0
    for f in bm.faces:
        c = f.calc_center_median()
        if 0.12 < c.z < 0.205 and f.normal.z > 0.3 and c.y > 0.0:
            for l in f.loops:
                l[uv_lay].uv = uv_tablero
            n_re += 1
    print("[puesto] caras de la tapa repintadas a madera: %d" % n_re)
bm.to_mesh(me)
bm.free()
me.update()

# ---- 3. la marquesina --------------------------------------------------------
mesh = bpy.data.meshes.new("marquesina")
bm = bmesh.new()
lay = bm.loops.layers.uv.verify()
NX, NZ = 10, 5
grid = []
for j in range(NZ + 1):
    fila = []
    for i in range(NX + 1):
        u = i / NX
        t = j / NZ
        x = -X_MEDIO + 2 * X_MEDIO * u
        yb = Z_ATRAS + (Z_FRENTE - Z_ATRAS) * t          # eje y de Blender = -z de Godot: t=1 es DELANTE (y negativa)
        yb = -yb
        z = ATRAS_Y + (FRENTE_Y - ATRAS_Y) * t + 0.035 * math.sin(math.pi * u) - 0.02 * math.sin(math.pi * t)
        fila.append(bm.verts.new((x, yb, z)))
    grid.append(fila)
bm.verts.ensure_lookup_table()
for j in range(NZ):
    for i in range(NX):
        f = bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
        for l in f.loops:
            v = l.vert.co
            l[lay].uv = Vector(((v.x + X_MEDIO) / (2 * X_MEDIO), (-v.y - Z_ATRAS) / (Z_FRENTE - Z_ATRAS)))
bm.normal_update()
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(mesh)
bm.free()
toldo = bpy.data.objects.new("marquesina", mesh)
sc.collection.objects.link(toldo)
# grosor y suavizado
bpy.context.view_layer.objects.active = toldo
toldo.select_set(True)
obj.select_set(False)
mod = toldo.modifiers.new("grosor", "SOLIDIFY")
mod.thickness = 0.022
mod.offset = 0.0
bpy.ops.object.modifier_apply(modifier="grosor")
bpy.ops.object.shade_smooth()
# la textura de rayas: 9 franjas rojas y crema, con un pelo de sombreado
W, H = 512, 128
img = bpy.data.images.new("rayas_toldo", W, H, alpha=False)
px = np.zeros((H, W, 4), np.float32)
for x in range(W):
    franja = int(x * 9 / W)
    rojo = franja % 2 == 0
    col = (0.86, 0.20, 0.22) if rojo else (0.96, 0.92, 0.80)
    # sombra suave en los bordes de cada franja
    u = (x * 9 / W) % 1.0
    k = 1.0 - 0.10 * (abs(u - 0.5) * 2.0) ** 3
    px[:, x, 0] = col[0] * k
    px[:, x, 1] = col[1] * k
    px[:, x, 2] = col[2] * k
    px[:, x, 3] = 1.0
img.pixels = px.ravel().tolist()
img.pack()
mat = bpy.data.materials.new("toldo")
mat.use_nodes = True
nt = mat.node_tree
b = nt.nodes["Principled BSDF"]
b.inputs["Roughness"].default_value = 0.75
b.inputs["Metallic"].default_value = 0.0
tx = nt.nodes.new("ShaderNodeTexImage")
tx.image = img
nt.links.new(tx.outputs["Color"], b.inputs["Base Color"])
mesh.materials.append(mat)
# el faldon: una tira que cuelga del canto delantero, con las mismas rayas
fal = bpy.data.meshes.new("faldon")
bm = bmesh.new()
lay = bm.loops.layers.uv.verify()
arriba, abajo = [], []
for i in range(NX + 1):
    u = i / NX
    x = -X_MEDIO + 2 * X_MEDIO * u
    zt = FRENTE_Y + 0.035 * math.sin(math.pi * u) - 0.02 * math.sin(math.pi)
    arriba.append(bm.verts.new((x, -Z_FRENTE - 0.005, zt)))
    abajo.append(bm.verts.new((x, -Z_FRENTE - 0.005, zt - 0.055 - 0.012 * math.sin(math.pi * u * 9 / 2.0) ** 2)))
for i in range(NX):
    f = bm.faces.new((abajo[i], abajo[i + 1], arriba[i + 1], arriba[i]))
    for l in f.loops:
        v = l.vert.co
        l[lay].uv = Vector(((v.x + X_MEDIO) / (2 * X_MEDIO), 0.5))
bm.to_mesh(fal)
bm.free()
faldon = bpy.data.objects.new("faldon", fal)
sc.collection.objects.link(faldon)
fal.materials.append(mat)
bpy.context.view_layer.objects.active = faldon
faldon.select_set(True)
m2 = faldon.modifiers.new("grosor", "SOLIDIFY")
m2.thickness = 0.012
bpy.ops.object.modifier_apply(modifier="grosor")

# ---- exportar todo junto ------------------------------------------------------
bpy.ops.object.select_all(action="DESELECT")
for o in ((obj,) if os.environ.get("PUESTO_SOLO") else (obj, toldo, faldon)):
    o.select_set(True)
for m in bpy.data.materials:
    if m.use_nodes and m.node_tree.nodes.get("Principled BSDF"):
        m.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value = 0.0
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_apply=True,
    export_animations=False, export_yup=True, use_selection=True,
    export_image_format="JPEG", export_jpeg_quality=90)
print("[puesto] exportado", dst)
