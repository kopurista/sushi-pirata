import bpy, sys, os, math, mathutils
a = sys.argv[sys.argv.index("--") + 1:]
ruta, salida = a[0], a[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(ruta))
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.42, 0.55, 0.65)
sc.render.resolution_x, sc.render.resolution_y = 560, 700
vs = []
for ob in sc.objects:
    if ob.type == "MESH":
        for v in ob.data.vertices: vs.append(ob.matrix_world @ v.co)
lo = mathutils.Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
hi = mathutils.Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
c = (lo + hi) / 2.0; alto = hi.z - lo.z
cd = bpy.data.cameras.new("c"); cd.type = "ORTHO"
cam = bpy.data.objects.new("Cam", cd); sc.collection.objects.link(cam); sc.camera = cam
vistas = [(0, 1.06, c.z), (35, 1.06, c.z), (90, 1.06, c.z), (0, 0.40, hi.z - alto * 0.19)]
for i, (yaw, esc, cz) in enumerate(vistas):
    cd.ortho_scale = alto * esc
    r = math.radians(yaw)
    cam.location = mathutils.Vector((c.x + math.sin(r) * alto * 3, c.y - math.cos(r) * alto * 3, cz))
    cam.rotation_euler = (math.radians(90), 0, r)
    sc.render.filepath = os.path.abspath("%s_%d.png" % (salida, i))
    bpy.ops.render.render(write_still=True)
print("ok")
