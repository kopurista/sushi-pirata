# Cuatro vistas de un OBJETO suelto (no un personaje): encuadra su caja entera,
# asi que vale igual para un puñal que para un barril. _v.py encuadra por ALTO
# de personaje y con una pieza tumbada se le va la escala.
#   blender --background --python tools/blender/ver_objeto.py -- <in.glb> <salida.png>
import bpy, sys, os, math, mathutils
a = sys.argv[sys.argv.index("--") + 1:]
ruta, salida = a[0], a[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(ruta))
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "TEXTURE"
sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.42, 0.55, 0.65)
sc.render.resolution_x, sc.render.resolution_y = 640, 480
vs = []
for ob in sc.objects:
    if ob.type == "MESH":
        for v in ob.data.vertices:
            vs.append(ob.matrix_world @ v.co)
lo = mathutils.Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
hi = mathutils.Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
c = (lo + hi) / 2.0
d = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z)
cd = bpy.data.cameras.new("c"); cd.type = "ORTHO"
cam = bpy.data.objects.new("Cam", cd); sc.collection.objects.link(cam); sc.camera = cam
for i, (yaw, pitch) in enumerate([(0, 90), (45, 78), (90, 90), (0, 40)]):
    cd.ortho_scale = d * 1.15
    r = math.radians(yaw); p = math.radians(pitch)
    dist = d * 3
    cam.location = (c.x + math.sin(r) * math.sin(p) * dist,
                    c.y - math.cos(r) * math.sin(p) * dist,
                    c.z + math.cos(p) * dist)
    cam.rotation_euler = (p, 0, r)
    sc.render.filepath = os.path.abspath("%s_%d.png" % (salida, i))
    bpy.ops.render.render(write_still=True)
print("ok", round(d, 4))
