# RIG DE AVE para Gigi (y para cualquier pájaro de esta tanda).
#   blender --background --python tools/blender/riggear_ave.py -- <modelo.glb> <salida.glb>
#
# Cinco huesos y nada más: Cuerpo (raíz), Cabeza, Cola y las dos alas. Un loro
# posado no anda ni gesticula: lo que hace es GIRAR LA CABEZA a golpes, mecerse
# y abrir el ala de vez en cuando, y eso se anima con estos cinco.
#
# Las medidas salen de la PROPIA MALLA, no de un concepto: la silueta de un ave
# es clara por bandas —el pico asoma delante y arriba, la cola detrás y abajo—
# así que aquí sí se puede medir sin que la cara engañe (que es lo que obliga a
# medir a los humanoides sobre su dibujo).
#
# Los pesos van por DISTANCIA al segmento de cada hueso, como en `riggear.py`, y
# por el mismo motivo: el pesado automático de Blender falla con estas formas y
# deja el glb sin skin.
import bpy, sys, os
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
GLB = os.path.abspath(args[0]); DEST = os.path.abspath(args[1])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
me = obj.data
M = obj.matrix_world
V = np.array([M @ v.co for v in me.vertices], dtype=np.float32)
lo, hi = V.min(axis=0), V.max(axis=0)
alto = hi[2] - lo[2]; fondo = hi[1] - lo[1]
print("[ave] %d verts, alto %.3f, fondo %.3f" % (len(V), alto, fondo))

# El ave mira a -Y (como el resto del reparto). La cabeza es la banda alta, la
# cola la punta baja de atrás y las alas lo que sobresale a los lados.
z_cuello = lo[2] + alto * 0.52
z_cuerpo = lo[2] + alto * 0.30
cab = V[V[:, 2] > z_cuello]
c_cab = cab.mean(axis=0) if len(cab) else np.array([0, 0, hi[2] - alto * 0.2])
col = V[(V[:, 2] < lo[2] + alto * 0.35) & (V[:, 1] > lo[1] + fondo * 0.62)]
c_col = col.mean(axis=0) if len(col) else np.array([0, hi[1], lo[2] + alto * 0.2])
alas = V[(np.abs(V[:, 0]) > (hi[0] - lo[0]) * 0.32) & (V[:, 2] > z_cuerpo - alto * 0.2) & (V[:, 2] < z_cuello)]
ala_x = float(np.abs(alas[:, 0]).mean()) if len(alas) else (hi[0] - lo[0]) * 0.35
print("[ave] cuello z %.3f | cabeza %s | cola %s | ala x %.3f"
      % (z_cuello, np.round(c_cab, 2), np.round(c_col, 2), ala_x))

arm_data = bpy.data.armatures.new("Rig")
arm = bpy.data.objects.new("Rig", arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
EB = arm_data.edit_bones

def hueso(nombre, cabeza, cola, padre=None):
    b = EB.new(nombre)
    b.head = Vector(cabeza); b.tail = Vector(cola)
    if padre:
        b.parent = EB[padre]; b.use_connect = False
    return b

hueso("Cuerpo", (0, 0, lo[2] + alto * 0.18), (0, 0, z_cuello))
hueso("Cabeza", (0, 0, z_cuello), (0, float(c_cab[1]), hi[2]), "Cuerpo")
hueso("Cola", (0, lo[1] + fondo * 0.62, lo[2] + alto * 0.28), (0, hi[1], lo[2] + alto * 0.10), "Cuerpo")
for lado, s in (("L", 1.0), ("R", -1.0)):
    hueso("%s_Ala" % lado, (s * ala_x * 0.5, 0, z_cuello - alto * 0.10),
          (s * ala_x, fondo * 0.10, lo[2] + alto * 0.30), "Cuerpo")
bpy.ops.object.mode_set(mode="OBJECT")
print("[ave] huesos:", [b.name for b in arm_data.bones])

def seg_dist(P, a, b):
    ab = b - a; L2 = float(ab @ ab) + 1e-9
    t = np.clip(((P - a) @ ab) / L2, 0.0, 1.0)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)

def suave(x, a, b):
    t = np.clip((x - a) / (b - a + 1e-9), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

huesos = [(b.name, np.array(b.head_local), np.array(b.tail_local)) for b in arm_data.bones]
nombres = [n for n, _, _ in huesos]
D = np.stack([seg_dist(V, h, t) for _, h, t in huesos], axis=1)
W = 1.0 / np.power(D + alto * 0.02, 4.0)
# LA CABEZA VA RÍGIDA, con el pico dentro: si se reparte con el cuerpo, al
# girarla a golpes el pico se queda a medio camino y se deforma.
i_cab = nombres.index("Cabeza")
k_cab = suave(V[:, 2], z_cuello - alto * 0.10, z_cuello + alto * 0.06)
W[:, i_cab] = 0.0
orden = np.argsort(-W, axis=1)[:, :4]
mask = np.zeros_like(W, dtype=bool)
np.put_along_axis(mask, orden, True, axis=1)
W = np.where(mask, W, 0.0)
suma = W.sum(axis=1, keepdims=True)
W = np.divide(W, suma, out=np.zeros_like(W), where=suma > 0)
W *= (1.0 - k_cab)[:, None]
W[:, i_cab] = k_cab
suma = W.sum(axis=1, keepdims=True)
W = np.divide(W, suma, out=np.zeros_like(W), where=suma > 0)
print("[ave] cabeza rígida: %d vértices al 90%%+" % int((W[:, i_cab] > 0.9).sum()))

for g in list(obj.vertex_groups):
    obj.vertex_groups.remove(g)
grupos = [obj.vertex_groups.new(name=n) for n in nombres]
for k, g in enumerate(grupos):
    for i in np.nonzero(W[:, k] > 0.001)[0]:
        g.add([int(i)], float(W[i, k]), "REPLACE")

obj.parent = arm
obj.matrix_parent_inverse = arm.matrix_world.inverted()
mod = obj.modifiers.new("Armature", "ARMATURE"); mod.object = arm
bpy.context.view_layer.update()
bpy.ops.export_scene.gltf(filepath=DEST, export_format="GLB", export_apply=False,
                          export_image_format="JPEG", export_jpeg_quality=90)
print("[ave] exportado", DEST)
