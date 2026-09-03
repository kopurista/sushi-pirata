import bpy, sys, os, math, mathutils
a = sys.argv[sys.argv.index("--") + 1:]
ruta, salida = a[0], a[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=ruta)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.42, 0.55, 0.65)
sc.render.resolution_x, sc.render.resolution_y = 620, 620
malla = [o for o in sc.objects if o.type == "MESH"][0]
arm = [o for o in sc.objects if o.type == "ARMATURE"][0]
b = arm.data.bones.get("L_Wrist")
p = arm.matrix_world @ b.head_local
alto = max((malla.matrix_world @ v.co).z for v in malla.data.vertices)
cd = bpy.data.cameras.new("c"); cd.type = "ORTHO"; cd.ortho_scale = 0.42
cam = bpy.data.objects.new("Cam", cd); sc.collection.objects.link(cam); sc.camera = cam
for i, (dx, dy, rz) in enumerate([(0, -3, 0), (3, 0, 90), (0, 3, 180)]):
    cam.location = p + mathutils.Vector((dx * 0.5, dy * 0.5, 0.0))
    cam.rotation_euler = (math.radians(90), 0, math.radians(rz))
    sc.render.filepath = os.path.abspath("%s_%d.png" % (salida, i))
    bpy.ops.render.render(write_still=True)
print("ok mano en", tuple(round(x, 3) for x in p))
