# Inspección de un .glb cualquiera con Blender: cuenta, medidas, textura y
# tres renders Workbench (frente, tres cuartos, perfil) al scratchpad.
#   blender --background --python tools/blender/inspeccionar.py -- <ruta.glb> <prefijo> [alambre]
import bpy, sys, os, math
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
GLB = os.path.abspath(args[0]); PREF = args[1]; ALAMBRE = len(args) > 2
OUT = "C:/Users/KOPURI~1/AppData/Local/Temp/claude/C--Users-KOPURISTA-Desktop-GODOT-sushi/ddc3d8d7-b243-4937-ae48-84636d59f46b/scratchpad/"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
mallas = [o for o in bpy.context.scene.objects if o.type == "MESH"]
def tris(o): return sum(len(p.vertices) - 2 for p in o.data.polygons)
print("[insp] objetos:", len(mallas), "triangulos:", sum(tris(o) for o in mallas))
for o in mallas:
    d = o.dimensions
    print("[insp]  %-20s %6d tris %6d verts  dims %.3f x %.3f x %.3f  smooth %s" % (o.name, tris(o), len(o.data.vertices), d.x, d.y, d.z, all(p.use_smooth for p in o.data.polygons)))
    for s in o.material_slots:
        m = s.material
        if m and m.use_nodes:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image:
                    print("[insp]  textura", n.image.name, n.image.size[:])
lo = [1e9]*3; hi = [-1e9]*3
for o in mallas:
    for v in o.bound_box:
        w = o.matrix_world @ Vector(v)
        for i in range(3): lo[i] = min(lo[i], w[i]); hi[i] = max(hi[i], w[i])
print("[insp] caja: x %.3f..%.3f y %.3f..%.3f z %.3f..%.3f" % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))
cx, cy, cz = [(lo[i]+hi[i])/2 for i in range(3)]; alto = hi[2]-lo[2]
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
sc.display.shading.show_specular_highlight = True
if ALAMBRE:
    sc.display.shading.type = "WIREFRAME" if hasattr(sc.display.shading, "type") else sc.display.shading.type
    for o in mallas: o.show_wire = True; o.show_all_edges = True
sc.render.resolution_x = 640; sc.render.resolution_y = 800
sc.world = bpy.data.worlds.new("W"); sc.world.color = (0.16, 0.36, 0.52)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 60; dist = alto * 2.3
for nombre, ang in (("frente", 0.0), ("3-4", 35.0), ("perfil", 90.0)):
    a = math.radians(ang)
    cam.location = (cx + dist*math.sin(a), cy - dist*math.cos(a), cz + alto*0.05)
    cam.rotation_euler = (math.radians(88.0), 0.0, a)
    sc.render.filepath = OUT + "%s_%s.png" % (PREF, nombre)
    bpy.ops.render.render(write_still=True)
print("[insp] renders", OUT + PREF + "_*.png")
