# RIG HUMANOIDE POR MEDIDA para las figuritas del estilo Link's Awakening.
#   blender --background --python tools/blender/riggear.py -- <modelo.glb> <salida.glb>
#
# Meshy NO puede riguear estos cabezones ("Pose estimation failed"), así que el
# esqueleto se construye aquí MIDIENDO la silueta de la propia malla: se corta
# en bandas horizontales y se mira en cuántas islas se parte cada banda (tres
# = brazos a los lados, dos = piernas), que es lo que da la altura del hombro,
# de la muñeca y de la cadera sin tocar un número a mano.
#
# LOS HUESOS SE NOMBRAN COMO EL RIG HUMANOIDE DEL JUEGO (Pelvis, Spine1, Neck,
# Head, L_Shoulder, L_Elbow, L_Wrist, L_Hip, L_Knee, L_Ankle y sus R_): con
# esos nombres, `CharacterAnim` los usa TAL CUAL y no tiene que deducir nada
# por topología. Y el convenio de ejes del juego se cumple solo: el personaje
# mira a -Y en Blender (que es +Z en Godot) y su izquierda cae en +X.
import bpy, sys, os, math
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
GLB = os.path.abspath(args[0]); DEST = os.path.abspath(args[1])
OUT = "C:/Users/KOPURI~1/AppData/Local/Temp/claude/C--Users-KOPURISTA-Desktop-GODOT-sushi/ddc3d8d7-b243-4937-ae48-84636d59f46b/scratchpad/"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
me = obj.data
M = obj.matrix_world
V = np.array([M @ v.co for v in me.vertices], dtype=np.float32)
lo = V.min(axis=0); hi = V.max(axis=0)
alto = hi[2] - lo[2]
print("[rig] %d verts, alto %.3f, caja x %.3f..%.3f y %.3f..%.3f" % (len(V), alto, lo[0], hi[0], lo[1], hi[1]))

# --- medidas: vienen del CONCEPTO -------------------------------------------
# (tools/medir_cuerpo.py; la silueta del dibujo es limpia y la de la malla no:
# cortando la malla por bandas, cada ceja y cada punta del bigote cuenta como
# una isla y el "hombro" salía a la altura de los ojos)
import json
CUERPO = os.path.abspath(args[2]) if len(args) > 2 else os.path.splitext(GLB)[0] + "_cuerpo.json"
met = json.load(open(CUERPO))
z_de = lambda f: hi[2] - f * alto          # el json mide desde la coronilla
ancho = met["ancho_hombro"] * alto
z_hombro = z_de(met["hombro_z"]); z_muneca = z_de(met["muneca_z"]); z_cadera = z_de(met["cadera_z"])
brazo_x = met["brazo_x"] * ancho; pierna_x = met["pierna_x"] * ancho
print("[rig] hombro z %.3f | muñeca z %.3f | brazo x %.3f | cadera z %.3f | pierna x %.3f"
      % (z_hombro, z_muneca, brazo_x, z_cadera, pierna_x))

# La CABEZA de estas figuritas es la mitad de arriba; su hueso va en el centro
# de masa de lo que queda por encima del hombro (así la barba, que cuelga por
# delante del pecho, reparte peso entre cabeza y torso y acompaña a las dos).
arriba = V[V[:, 2] > z_hombro]
z_cabeza = float(np.median(arriba[:, 2])) if len(arriba) else lo[2] + alto * 0.75
y_medio = float((lo[1] + hi[1]) / 2)

# --- armature ----------------------------------------------------------------
arm_data = bpy.data.armatures.new("Rig")
arm = bpy.data.objects.new("Rig", arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
EB = arm_data.edit_bones

def hueso(nombre, cabeza, cola, padre=None):
    b = EB.new(nombre)
    b.head = Vector(cabeza); b.tail = Vector(cola)
    if padre: b.parent = EB[padre]; b.use_connect = False
    return b

z_pelvis = z_cadera + (z_hombro - z_cadera) * 0.10
z_pecho = z_cadera + (z_hombro - z_cadera) * 0.62
hueso("Pelvis", (0, y_medio, z_pelvis), (0, y_medio, z_pecho))
hueso("Spine1", (0, y_medio, z_pecho), (0, y_medio, z_hombro), "Pelvis")
z_cuello = z_hombro + (z_cabeza - z_hombro) * 0.45
hueso("Neck", (0, y_medio, z_hombro), (0, y_medio, z_cuello), "Spine1")
hueso("Head", (0, y_medio, z_cuello), (0, y_medio, hi[2]), "Neck")
for lado, s in (("L", 1.0), ("R", -1.0)):
    zc = z_hombro - (z_hombro - z_muneca) * 0.10
    ze = (z_hombro + z_muneca) / 2
    hueso("%s_Shoulder" % lado, (s * brazo_x * 0.55, y_medio, zc), (s * brazo_x, y_medio, ze), "Spine1")
    hueso("%s_Elbow" % lado, (s * brazo_x, y_medio, ze), (s * brazo_x, y_medio, z_muneca), "%s_Shoulder" % lado)
    hueso("%s_Wrist" % lado, (s * brazo_x, y_medio, z_muneca), (s * brazo_x, y_medio, z_muneca - alto * 0.05), "%s_Elbow" % lado)
    zr = (z_cadera + lo[2]) / 2
    hueso("%s_Hip" % lado, (s * pierna_x, y_medio, z_cadera), (s * pierna_x, y_medio, zr), "Pelvis")
    hueso("%s_Knee" % lado, (s * pierna_x, y_medio, zr), (s * pierna_x, y_medio, lo[2] + alto * 0.02), "%s_Hip" % lado)
    hueso("%s_Ankle" % lado, (s * pierna_x, y_medio, lo[2] + alto * 0.02), (s * pierna_x, y_medio - alto * 0.05, lo[2]), "%s_Knee" % lado)
bpy.ops.object.mode_set(mode="OBJECT")
print("[rig] huesos:", [b.name for b in arm_data.bones])

# --- pesos POR DISTANCIA (los automáticos de Blender no valen) ----------------
# `ARMATURE_AUTO` (bone heat) FALLA en estas figuritas: avisa "failed to find
# solution for one or more bones" y deja los grupos vacíos, y entonces el
# exportador escribe los pesos pero NO el skin ("Mesh_0 has no skin"), así que
# en Godot llega una malla suelta sin esqueleto. Aquí el peso de cada vértice
# sale de su distancia al SEGMENTO de cada hueso, con caída de potencia y
# quedándose con los cuatro mejores, que es lo que admite glTF.
CAIDA = 4.0
MAX_INF = 4

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
W = 1.0 / np.power(D + alto * 0.01, CAIDA)

# REGIONES DURAS. Con la distancia a secas la cabeza se parte al girarla (unos
# vértices de la cara pesan al cuello y otros a la cabeza, y el ojo se estira)
# y el brazo arrastra media casaca. En una figurita la cabeza es una PIEZA
# RÍGIDA y el brazo solo se lleva su manga.
i_head = nombres.index("Head")
brazos = [nombres.index(n) for n in nombres if n.endswith(("_Shoulder", "_Elbow", "_Wrist"))]
# 1) todo lo que está por encima del cuello es cabeza, con una transición corta
k_head = suave(V[:, 2], z_cuello - (z_cuello - z_hombro) * 0.9, z_cuello)
# 2) y la BARBA también: cuelga por delante del pecho (y negativo) y tiene que
#    girar con la cabeza, como la de Tarin en el remake
barba = (V[:, 1] < y_medio - (hi[1] - lo[1]) * 0.12) & (V[:, 2] > z_cadera)
k_head = np.maximum(k_head, np.where(barba, 0.92, 0.0))
# 3) los brazos no tocan el tronco: solo desde la mitad de su separación
fuera = suave(np.abs(V[:, 0]), brazo_x * 0.55, brazo_x * 0.85)
W[:, brazos] *= fuera[:, None]

W[:, i_head] = 0.0
orden = np.argsort(-W, axis=1)[:, :MAX_INF]
mask = np.zeros_like(W, dtype=bool)
np.put_along_axis(mask, orden, True, axis=1)
W = np.where(mask, W, 0.0)
suma = W.sum(axis=1, keepdims=True)
W = np.divide(W, suma, out=np.zeros_like(W), where=suma > 0)
W *= (1.0 - k_head)[:, None]
W[:, i_head] = k_head
suma = W.sum(axis=1, keepdims=True)
W = np.divide(W, suma, out=np.zeros_like(W), where=suma > 0)
print("[rig] cabeza rígida: %d vértices al 90%%+ | barba: %d" % (int((W[:, i_head] > 0.9).sum()), int(barba.sum())))

for g in list(obj.vertex_groups):
    obj.vertex_groups.remove(g)
grupos = [obj.vertex_groups.new(name=n) for n, _, _ in huesos]
for k, g in enumerate(grupos):
    idx = np.nonzero(W[:, k] > 0.001)[0]
    for i in idx:
        g.add([int(i)], float(W[i, k]), "REPLACE")
print("[rig] pesos por distancia: %d vértices, media de influencias %.2f"
      % (len(V), float((W > 0.001).sum(axis=1).mean())))

obj.parent = arm
obj.matrix_parent_inverse = arm.matrix_world.inverted()
mod = obj.modifiers.new("Armature", "ARMATURE")
mod.object = arm
bpy.context.view_layer.update()
print("[rig] padre:", obj.parent.name, "| modificador:", mod.type, "| find_armature:", obj.find_armature())

bpy.ops.export_scene.gltf(filepath=DEST, export_format="GLB", export_apply=False,
                          export_image_format="JPEG", export_jpeg_quality=90,
                          export_skins=True, export_yup=True)
print("[rig] exportado", DEST)
