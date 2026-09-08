# Comprobacion del rig: aplica poses extremas y las renderiza, para ver si los
# pesos automaticos deforman bien (la barba siguiendo a la cabeza, el brazo sin
# arrastrar el pecho...). A ojo no se ve: hay que forzar el gesto.
#   blender --background --python tools/blender/probar_rig.py -- <rig.glb> <prefijo>
import bpy, sys, os, math
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
GLB = os.path.abspath(args[0]); PREF = args[1]
# la carpeta de salida se puede fijar con POSE_OUT (por defecto, la del rig)
OUT = os.environ.get("POSE_OUT", os.path.dirname(GLB)) + "/"

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
    "codoX-": {"L_Elbow": (-35, 0, 0), "R_Elbow": (-35, 0, 0)},
    "codoX+": {"L_Elbow": (35, 0, 0), "R_Elbow": (35, 0, 0)},
    "hombroX-": {"L_Shoulder": (-30, 0, 0), "R_Shoulder": (-30, 0, 0)},
    "manoY": {"L_Wrist": (0, 45, 0), "R_Wrist": (0, -45, 0)},
    "habla_A": {"L_Shoulder": (-16, 0, -6), "R_Shoulder": (-16, 0, 6),
                "L_Elbow": (-22, 0, 0), "R_Elbow": (-22, 0, 0),
                "L_Wrist": (0, 45, 0), "R_Wrist": (0, -45, 0)},
    "manos": {"L_Shoulder": (-20, 0, -8), "R_Shoulder": (-20, 0, 8),
              "L_Elbow": (-28, 0, 0), "R_Elbow": (-28, 0, 0),
              "L_Wrist": (0, 52, 0), "R_Wrist": (0, -52, 0)},
    "manos_neg": {"L_Shoulder": (-20, 0, -8), "R_Shoulder": (-20, 0, 8),
              "L_Elbow": (-28, 0, 0), "R_Elbow": (-28, 0, 0),
              "L_Wrist": (0, -52, 0), "R_Wrist": (0, 52, 0)},
    "habla_B": {"L_Shoulder": (-26, 0, -10), "R_Shoulder": (-26, 0, 10),
                "L_Elbow": (-34, 0, 0), "R_Elbow": (-34, 0, 0),
                "L_Wrist": (0, 60, 0), "R_Wrist": (0, -60, 0)},
}
for nombre, r in POSES.items():
    pose(**r)
    if nombre.startswith("manos"):
        # primer plano de la mano: se APUNTA al hueso de la muñeca, que es lo
        # que hay que mirar (centrando en el cuerpo salían las botas)
        pb = arm.pose.bones.get("L_Wrist")
        obj_pt = (arm.matrix_world @ pb.head) if pb else (c + Vector((alto * 0.33, 0, -alto * 0.28)))
        d = alto * 0.55; a = math.radians(20)
        cam.location = Vector((obj_pt[0] + d * math.sin(a) + alto * 0.10,
                               obj_pt[1] - d * math.cos(a), obj_pt[2] + alto * 0.10))
        cam.rotation_euler = (cam.location - Vector(obj_pt)).to_track_quat("Z", "Y").to_euler()
    else:
        d = alto * 2.3; a = math.radians(28)
        cam.location = (c[0] + d * math.sin(a), c[1] - d * math.cos(a), c[2] + alto * 0.05)
        cam.rotation_euler = (math.radians(88.0), 0.0, a)
    sc.render.filepath = OUT + "%s_%s.png" % (PREF, nombre)
    bpy.ops.render.render(write_still=True)
    print("[pose]", nombre)
