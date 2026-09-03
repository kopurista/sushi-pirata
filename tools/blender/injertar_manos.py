# INJERTA MANOS DE VERDAD en un personaje de Meshy.
#   blender --background --python tools/blender/injertar_manos.py -- \
#       <cuerpo.glb> <mano.glb> <cuerpo_cuerpo.json> <salida.glb>
#
# POR QUE HACE FALTA: Meshy devuelve el personaje como UNA SOLA MASA, con la
# mano pegada a la manga. Girar la muñeca ahi retuerce los poligonos que cruzan
# de la tela a la carne y la mano sale desfigurada; cortarlos deja un agujero.
# Y la manopla que genera no tiene dedos.
#
# Asi que la mano se genera APARTE (su propio concepto en Ludo y su propio
# modelo en Meshy: dedos, pulgar y un corte de muñeca limpio) y aqui se
# TRASPLANTA: se borra la manopla vieja, se coloca la nueva en su sitio con el
# muñon METIDO dentro de la manga, y se une a la malla como isla suelta. Al no
# compartir un solo vertice con el brazo, la muñeca gira sin deformar nada.
import bpy, sys, os, json, math
import numpy as np
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
CUERPO = os.path.abspath(args[0])
MANO = os.path.abspath(args[1])
CUERPO_JSON = os.path.abspath(args[2])
DEST = os.path.abspath(args[3])
OUT = "C:/Users/KOPURI~1/AppData/Local/Temp/claude/C--Users-KOPURISTA-Desktop-GODOT-sushi/ddc3d8d7-b243-4937-ae48-84636d59f46b/scratchpad/"
# cuanto se mete el muñon dentro de la manga, en fracciones del alto
DENTRO = float(os.environ.get("DENTRO", 0.030))
# tamano de la mano nueva, en fracciones del alto del personaje
MANO_ALTO = float(os.environ.get("MANO_ALTO", 0.115))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=CUERPO)
cuerpo = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
cuerpo.name = "Cuerpo"
me = cuerpo.data
M = cuerpo.matrix_world
V = np.array([M @ v.co for v in me.vertices], dtype=np.float32)
lo, hi = V.min(axis=0), V.max(axis=0)
alto = hi[2] - lo[2]
cu = json.load(open(CUERPO_JSON))
anc = cu["ancho_hombro"] * alto
z_mu = hi[2] - cu["muneca_z"] * alto
bx = cu["brazo_x"] * anc
print("[injerto] cuerpo: alto %.3f | muñeca z %.3f | brazo x %.3f" % (alto, z_mu, bx))

# --- la manopla vieja, por COLOR (la manga es tela y la mano es carne) --------
img = None
for m in me.materials:
    if m and m.use_nodes:
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image and n.image.size[0] > 8:
                img = n.image
TW, TH = img.size
tex = np.array(img.pixels[:], dtype=np.float32).reshape(TH, TW, 4)[..., :3]
uvl = me.uv_layers.active.data
col = np.zeros((len(me.vertices), 3), dtype=np.float32)
cnt = np.zeros(len(me.vertices), dtype=np.float32)
for poly in me.polygons:
    for li in poly.loop_indices:
        vi = me.loops[li].vertex_index
        u, v = uvl[li].uv
        col[vi] += tex[int(np.clip(v, 0, 0.999) * (TH - 1)), int(np.clip(u, 0, 0.999) * (TW - 1))]
        cnt[vi] += 1
col /= np.maximum(cnt, 1.0)[:, None]
piel = (col[:, 0] > col[:, 2] + 0.12) & (col[:, 0] > 0.45)
vieja = piel & (np.abs(V[:, 0]) > bx * 0.72) & (V[:, 2] < z_mu + alto * 0.06)
print("[injerto] manopla vieja: %d vértices" % int(vieja.sum()))

datos = {}
for lado, sg in (("L", 1.0), ("R", -1.0)):
    sel = vieja & (np.sign(V[:, 0]) == sg)
    if sel.sum() < 30:
        continue
    P = V[sel]
    d = np.abs(P[:, 0])
    union = P[d < np.quantile(d, 0.20)].mean(axis=0)
    punta = P[d > np.quantile(d, 0.80)].mean(axis=0)
    datos[lado] = (union.copy(), punta.copy())
    print("[injerto] %s: unión %s punta %s" % (lado, np.round(union, 3), np.round(punta, 3)))

# EL BORDE DEL AGUJERO SE MARCA ANTES DE CORTAR. Al quitar la manopla el brazo
# queda abierto y su canto se ve como un pico de carne plano asomando por
# detrás de la tela. Se cierra colapsando ese anillo, pero los índices cambian
# al borrar, así que el anillo se apunta antes en un grupo de vértices, que sí
# sobrevive al corte.
vecinos = [set() for _ in range(len(me.vertices))]
for e in me.edges:
    a, b = e.vertices
    vecinos[a].add(b); vecinos[b].add(a)
anillo = np.zeros(len(V), dtype=bool)
for i in np.nonzero(vieja)[0]:
    for j in vecinos[i]:
        if not vieja[j]:
            anillo[j] = True
gr_anillo = cuerpo.vertex_groups.new(name="_anillo")
for i in np.nonzero(anillo)[0]:
    gr_anillo.add([int(i)], 1.0, "REPLACE")
print("[injerto] anillo del corte: %d vértices" % int(anillo.sum()))

# se borra la manopla vieja: sus caras y sus vértices
bpy.context.view_layer.objects.active = cuerpo
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="DESELECT")
bpy.ops.object.mode_set(mode="OBJECT")
for i in np.nonzero(vieja)[0]:
    me.vertices[int(i)].select = True
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.delete(type="VERT")
bpy.ops.object.mode_set(mode="OBJECT")
# y se CIERRA: cada mitad del anillo se lleva hacia su propio centro, con lo
# que el brazo acaba en punta y deja de verse el corte
idx_g = gr_anillo.index
V2 = np.array([M @ v.co for v in me.vertices], dtype=np.float32)
enanillo = np.array([any(g.group == idx_g for g in v.groups) for v in me.vertices])
for sg in (1.0, -1.0):
    sel = np.nonzero(enanillo & (np.sign(V2[:, 0]) == sg))[0]
    if len(sel) < 3:
        continue
    centro = V2[sel].mean(axis=0)
    for i in sel:
        co = V2[i] + (centro - V2[i]) * 0.88
        me.vertices[int(i)].co = M.inverted() @ Vector(co.tolist())
    print("[injerto] borde cerrado (%+d): %d vértices" % (sg, len(sel)))
cuerpo.vertex_groups.remove(gr_anillo)
print("[injerto] tras borrar: %d vértices" % len(me.vertices))
# EL AGUJERO DE LA MANGA NO SE TAPA CON GEOMETRIA: se probó con
# `select_non_manifold` + `edge_face_add` y arrasó la malla entera (la de Meshy
# tiene aristas no-manifold por todas partes, así que cosió caras por la cara y
# la barba). Lo tapa la propia mano, que entra `DENTRO` en la manga.

# --- la mano nueva -------------------------------------------------------------
bpy.ops.import_scene.gltf(filepath=MANO)
mano = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name != "Cuerpo"][0]
mano.name = "ManoNueva"
mp = [mano.matrix_world @ v.co for v in mano.data.vertices]
mlo = Vector([min(p[i] for p in mp) for i in range(3)])
mhi = Vector([max(p[i] for p in mp) for i in range(3)])
m_alto = mhi[2] - mlo[2]
print("[injerto] mano cruda: %d verts, alto %.3f" % (len(mano.data.vertices), m_alto))

# La mano lleva MATERIAL PROPIO de color plano: su textura de Meshy es de otro
# tono y con las UV del cuerpo no encaja de ninguna manera. Un color liso con
# el mismo sombreado del resto es lo que pide el estilo, y de paso no hay que
# hornear nada.
def lineal(c):
    return tuple((v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4) for v in c)

PIEL = (0.973, 0.788, 0.671)     # la piel de David, medida en su paleta
mat_mano = bpy.data.materials.new("PielMano")
mat_mano.use_nodes = True
bsdf_m = [n for n in mat_mano.node_tree.nodes if n.type == "BSDF_PRINCIPLED"][0]
bsdf_m.inputs["Base Color"].default_value = lineal(PIEL) + (1.0,)
bsdf_m.inputs["Roughness"].default_value = 0.32
bsdf_m.inputs["Metallic"].default_value = 0.0
mano.data.materials.clear()
mano.data.materials.append(mat_mano)

# LA MANO DE MESHY VIENE CON 9.792 VERTICES, que para una manopla es un
# disparate: se decima antes de duplicarla. Y el modelo final tiene que caber
# en el presupuesto del hook de Godot, o su simplificador mezcla las dos
# superficies y el personaje sale con manchas de la otra textura por la cara.
TRIS_MANO = int(os.environ.get("TRIS_MANO", 2200))
tris = sum(len(p.vertices) - 2 for p in mano.data.polygons)
if tris > TRIS_MANO:
    bpy.context.view_layer.objects.active = mano
    md = mano.modifiers.new("dec", "DECIMATE")
    md.ratio = TRIS_MANO / tris
    bpy.ops.object.modifier_apply(modifier="dec")
    print("[injerto] mano decimada: %d -> %d tris" % (tris, sum(len(p.vertices) - 2 for p in mano.data.polygons)))
bpy.ops.object.shade_smooth()

copias = []
for lado, (union, punta) in datos.items():
    dup = mano.copy(); dup.data = mano.data.copy()
    bpy.context.scene.collection.objects.link(dup)
    dup.name = "Mano_" + lado
    esc = MANO_ALTO * alto / m_alto
    # La mano del concepto viene con la MUÑECA ABAJO y los dedos arriba, así que
    # su eje propio es +Z. Se gira para que ese eje apunte del muñón a la punta
    # del brazo, y así queda como continuación natural de la manga.
    # Los dedos CUELGAN: el eje va hacia abajo y algo hacia fuera, no siguiendo
    # el de la manopla vieja (que apuntaba de lado y dejaba los dedos en
    # horizontal, como si señalara).
    sg = 1.0 if lado == "L" else -1.0
    eje = Vector((sg * float(os.environ.get("ABRE", 0.42)), 0.0, -1.0)).normalized()
    q = Vector((0.0, 0.0, 1.0)).rotation_difference(eje.normalized())
    # el giro ALREDEDOR del eje queda indeterminado con rotation_difference, y
    # es el que decide hacia dónde mira la palma en reposo: se fija a mano
    giro = math.radians(float(os.environ.get("GIRO", 0.0)) * (1.0 if lado == "L" else -1.0))
    q = q @ Matrix.Rotation(giro, 4, "Z").to_quaternion()
    centro_local = (mlo + mhi) / 2
    dup.matrix_world = (Matrix.Translation(Vector(union.tolist()) - eje.normalized() * (alto * DENTRO))
                        @ q.to_matrix().to_4x4()
                        @ Matrix.Scale(esc, 4)
                        @ Matrix.Translation(-Vector((centro_local.x, centro_local.y, mlo.z))))
    copias.append(dup)
bpy.data.objects.remove(mano, do_unlink=True)

# se unen al cuerpo: quedan como ISLAS sueltas, sin un solo vértice compartido
bpy.ops.object.select_all(action="DESELECT")
for d in copias:
    d.select_set(True)
cuerpo.select_set(True)
bpy.context.view_layer.objects.active = cuerpo
bpy.ops.object.join()
print("[injerto] unido: %d vértices, %d materiales" % (len(cuerpo.data.vertices), len(cuerpo.data.materials)))

# --- renders de comprobación ---------------------------------------------------
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "MATERIAL"
sc.display.shading.show_specular_highlight = True
sc.render.resolution_x = 620
sc.render.resolution_y = 760
sc.world = bpy.data.worlds.new("W")
sc.world.color = (0.16, 0.36, 0.52)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.lens = 60
c = (Vector(lo.tolist()) + Vector(hi.tolist())) / 2
for nombre, ang in (("frente", 0.0), ("3-4", 32.0)):
    a = math.radians(ang)
    d = alto * 2.2
    cam.location = (c[0] + d * math.sin(a), c[1] - d * math.cos(a), c[2])
    cam.rotation_euler = (math.radians(88.0), 0.0, a)
    sc.render.filepath = OUT + "inj_%s.png" % nombre
    bpy.ops.render.render(write_still=True)
bpy.data.objects.remove(cam)

bpy.ops.export_scene.gltf(filepath=DEST, export_format="GLB", export_apply=True,
                          export_image_format="JPEG", export_jpeg_quality=90)
print("[injerto] exportado", DEST)
