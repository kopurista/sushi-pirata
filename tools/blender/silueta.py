# Render FRONTAL con fondo transparente de un .glb, para MEDIR su silueta con
# tools/medir_cuerpo.py igual que se mide un concepto de Ludo. Hace falta
# cuando el concepto no ensena los brazos (el Kappa los lleva pegados al
# caparazon) pero el modelo de Meshy si los tiene.
#   blender --background --python tools/blender/silueta.py -- <in.glb> <out.png>
import bpy, sys, os, math, mathutils
a = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(a[0]))
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "FLAT"
sc.display.shading.color_type = "SINGLE"
sc.display.shading.single_color = (0.1, 0.1, 0.1)
sc.render.film_transparent = True
sc.render.image_settings.color_mode = "RGBA"
sc.render.resolution_x, sc.render.resolution_y = 700, 1000
vs = []
for ob in sc.objects:
    if ob.type == "MESH":
        for v in ob.data.vertices:
            vs.append(ob.matrix_world @ v.co)
lo = mathutils.Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
hi = mathutils.Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
c = (lo + hi) / 2.0; alto = hi.z - lo.z
cd = bpy.data.cameras.new("c"); cd.type = "ORTHO"; cd.ortho_scale = alto * 1.05
cam = bpy.data.objects.new("Cam", cd); sc.collection.objects.link(cam); sc.camera = cam
cam.location = (c.x, c.y - alto * 3, c.z)
cam.rotation_euler = (math.radians(90), 0, 0)
sc.render.filepath = os.path.abspath(a[1])
bpy.ops.render.render(write_still=True)
print("ok")
