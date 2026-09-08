# PASA A OTRO HUESO EL PESO DE LOS VERTICES QUE UN GRUPO TIENE LEJOS DE SU
# HUESO. Nacio para la SIRENA (5-9-2026): el rig de Meshy le metio la MELENA
# entera en el grupo de la muñeca derecha (10.620 vertices, hasta la
# coronilla), asi que al llevarse la mano a la boca el pelo salia volando de
# lado como una lamina. `manos_esfera.py` ya sabia no COLAPSAR esos vertices
# (`MANO_ALCANCE`), pero seguian pesando en la muñeca.
#
#   blender --background --python tools/blender/pesos_lejos.py -- \
#       <in.glb> <out.glb> [grupos=L_Wrist,R_Wrist,L_Elbow,R_Elbow] [alcance=0.12]
#
# Un vertice de esos grupos a mas de `alcance` (en unidades del modelo, que
# mide 1.0 de alto) del SEGMENTO de su hueso pierde ese peso, que pasa a Head
# si el vertice esta por encima del cuello y a Spine1 si no.
import bpy, sys, os
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
src, dst = os.path.abspath(a[0]), os.path.abspath(a[1])
grupos = (a[2] if len(a) > 2 else "L_Wrist,R_Wrist,L_Elbow,R_Elbow").split(",")
alcance = float(a[3]) if len(a) > 3 else 0.12

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
sc = bpy.context.scene
arm = next(o for o in sc.objects if o.type == "ARMATURE")
mallas = [o for o in sc.objects if o.type == "MESH" and o.vertex_groups]


def seg_dist(p, a0, b0):
    ab = b0 - a0
    if ab.length_squared < 1e-12:
        return (p - a0).length
    t = max(0.0, min(1.0, (p - a0).dot(ab) / ab.length_squared))
    return (p - (a0 + ab * t)).length


cuello = None
if "Neck" in arm.data.bones:
    cuello = (arm.matrix_world @ arm.data.bones["Neck"].head_local).z

for o in mallas:
    idx = {g.name: g.index for g in o.vertex_groups}
    for dest in ("Head", "Spine1"):
        if dest not in idx:
            o.vertex_groups.new(name=dest)
            idx = {g.name: g.index for g in o.vertex_groups}
    g_head = o.vertex_groups["Head"]
    g_sp = o.vertex_groups["Spine1"]
    movidos = 0
    for gname in grupos:
        if gname not in idx or gname not in arm.data.bones:
            continue
        b = arm.data.bones[gname]
        ha = arm.matrix_world @ b.head_local
        ta = arm.matrix_world @ b.tail_local
        gi = idx[gname]
        g = o.vertex_groups[gname]
        lejos = []
        for v in o.data.vertices:
            w = 0.0
            for ge in v.groups:
                if ge.group == gi:
                    w = ge.weight
            if w <= 0.0:
                continue
            p = o.matrix_world @ v.co
            if seg_dist(p, ha, ta) <= alcance:
                continue
            lejos.append((v.index, w, p.z))
        for vi, w, z in lejos:
            g.remove([vi])
            dest = g_head if (cuello is not None and z > cuello) else g_sp
            dest.add([vi], w, "ADD")
        movidos += len(lejos)
        print("[pesos] %s / %s: %d vertices lejos (> %.3f) reasignados" % (o.name, gname, len(lejos), alcance))
    # normalizar por si un vertice ha quedado con la suma por encima de 1
    for v in o.data.vertices:
        tot = sum(ge.weight for ge in v.groups)
        if tot > 1.0001:
            for ge in v.groups:
                o.vertex_groups[ge.group].add([v.index], ge.weight / tot, "REPLACE")
    print("[pesos] %s: %d vertices en total" % (o.name, movidos))

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_yup=True,
    export_apply=False, export_animations=False, export_skins=True,
    export_image_format="AUTO")
print("[pesos] exportado", dst)
