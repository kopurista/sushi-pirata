# EL MOSTRADOR DE LA CINTA EN ESTILO LINK'S AWAKENING (7-9-2026): un anillo
# cuadrado de madera con los cantos REDONDEADOS (bisel), a escala de mundo,
# para sustituir a las cuatro cajas de `_setup_counter_and_belt`. Se exporta
# sin textura: en Godot lleva un material triplanar con la madera de Ludo.
#
#   blender --background --python tools/blender/la_mostrador.py -- \
#       <out.glb> [lado=3.6] [ancho=1.1] [alto=0.8] [bisel=0.09]
# `lado` es la linea central de la banda (BELT_SIDE), `ancho` el del mostrador
# (COUNTER_W) y `alto` BELT_TOP: el anillo va de lado-ancho a lado+ancho.
import bpy, bmesh, sys, os

a = sys.argv[sys.argv.index("--") + 1:]
dst = os.path.abspath(a[0])
LADO = float(a[1]) if len(a) > 1 else 3.6
ANCHO = float(a[2]) if len(a) > 2 else 1.1
ALTO = float(a[3]) if len(a) > 3 else 0.8
BISEL = float(a[4]) if len(a) > 4 else 0.09

bpy.ops.wm.read_factory_settings(use_empty=True)
me = bpy.data.meshes.new("mostrador")
bm = bmesh.new()
ext = LADO * 0.5 + ANCHO * 0.5   # semi-lado exterior
inn = LADO * 0.5 - ANCHO * 0.5   # semi-lado interior
# anillo cuadrado por extrusion: 8 vertices abajo, 8 arriba (Blender Z arriba)
def anillo(z):
    outer = [bm.verts.new((x, y, z)) for x, y in ((-ext, -ext), (ext, -ext), (ext, ext), (-ext, ext))]
    inner = [bm.verts.new((x, y, z)) for x, y in ((-inn, -inn), (inn, -inn), (inn, inn), (-inn, inn))]
    return outer, inner
o0, i0 = anillo(0.0)
o1, i1 = anillo(ALTO)
for k in range(4):
    k2 = (k + 1) % 4
    bm.faces.new((o0[k], o0[k2], o1[k2], o1[k]))          # cara exterior
    bm.faces.new((i0[k2], i0[k], i1[k], i1[k2]))          # cara interior
    bm.faces.new((o1[k], o1[k2], i1[k2], i1[k]))          # tapa
    bm.faces.new((o0[k2], o0[k], i0[k], i0[k2]))          # fondo
bm.normal_update()
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(me)
bm.free()
ob = bpy.data.objects.new("mostrador", me)
bpy.context.scene.collection.objects.link(ob)
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
mod = ob.modifiers.new("bisel", "BEVEL")
mod.width = BISEL
mod.segments = 4
mod.limit_method = "ANGLE"
mod.angle_limit = 0.5
bpy.ops.object.modifier_apply(modifier="bisel")
bpy.ops.object.shade_smooth_by_angle(angle=0.6)
mat = bpy.data.materials.new("madera")
mat.use_nodes = True
mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
me.materials.append(mat)
print("[mostrador] caras %d, exterior %.2f, interior %.2f, alto %.2f" % (len(me.polygons), ext * 2, inn * 2, ALTO))
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_apply=True,
    export_animations=False, export_yup=True)
print("[mostrador] exportado", dst)
