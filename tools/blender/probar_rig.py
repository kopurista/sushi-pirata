# Comprobacion del rig: aplica poses extremas y las renderiza, para ver si los
# pesos automaticos deforman bien (la barba siguiendo a la cabeza, el brazo sin
# arrastrar el pecho...). A ojo no se ve: hay que forzar el gesto.
#   blender --background --python tools/blender/probar_rig.py -- <rig.glb> <prefijo>
import bpy, sys, os, math
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
GLB = os.path.abspath(args[0]); PREF = args[1]
OUT = "C:/Users/KOPURI~1/AppData/Local/Temp/claude/C--Users-KOPURISTA-Desktop-GODOT-sushi/ddc3d8d7-b243-4937-ae48-84636d59f46b/scratchpad/"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
arm = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"][0]
mesh = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
print("[pose] huesos:", [b.name for b in arm.pose.bones])

sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
sc.display.shading.show_specular_highlight = True
sc.render.resolution_x = 560; sc.render.resolution_y = 700
sc.world = bpy.data.worlds.new("W"); sc.world.color = (0.16, 0.36, 0.52)
pts = [mesh.matrix_world @ v.co for v in mesh.data.vertices]
lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)])
c = (lo + hi) / 2; alto = hi[2] - lo[2]
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 60

def pose(**rots):
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"; pb.rotation_euler = (0, 0, 0)
    for nombre, (rx, ry, rz) in rots.items():
        if nombre in arm.pose.bones:
            pb = arm.pose.bones[nombre]
            pb.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))
    bpy.context.view_layer.update()

POSES = {
    "reposo": {},
    "cabeza": {"Head": (0, 0, 38), "Neck": (0, 0, 16)},
    "asiente": {"Head": (26, 0, 0), "Neck": (10, 0, 0)},
    "brazos": {"L_Shoulder": (0, 0, -55), "R_Shoulder": (0, 0, 55)},
    "tronco": {"Spine1": (-14, 0, 10), "Head": (6, 0, -8)},
}
for nombre, r in POSES.items():
    pose(**r)
    d = alto * 2.3; a = math.radians(28)
    cam.location = (c[0] + d * math.sin(a), c[1] - d * math.cos(a), c[2] + alto * 0.05)
    cam.rotation_euler = (math.radians(88.0), 0.0, a)
    sc.render.filepath = OUT + "%s_%s.png" % (PREF, nombre)
    bpy.ops.render.render(write_still=True)
    print("[pose]", nombre)
