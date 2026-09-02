# Busto de David (Meshy image->3D desde el retrato de Ludo), pasado por Blender.
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python tools/blender/david_busto.py -- inspeccion
#   ...                                                                                                   -- montar
# `inspeccion`: mide el .glb (objetos, triangulos, medidas, textura) y saca
#   tres renders (frente, tres cuartos, perfil) al scratchpad, con Workbench.
# `montar`: decima al presupuesto, recentra en el origen y exporta a
#   assets/models/david_busto.glb (el crudo de Meshy queda en david_busto_crudo.glb).
import bpy, sys, os, math

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GLB = os.path.join(ROOT, "assets", "models", "david_busto.glb")
OUT = "C:/Users/KOPURI~1/AppData/Local/Temp/claude/C--Users-KOPURISTA-Desktop-GODOT-sushi/ddc3d8d7-b243-4937-ae48-84636d59f46b/scratchpad/"
PRESUPUESTO = 6000
modo = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "inspeccion"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
mallas = [o for o in bpy.context.scene.objects if o.type == "MESH"]

def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)

total = sum(tris(o) for o in mallas)
print("[david] objetos:", len(mallas), "triangulos:", total)
for o in mallas:
    d = o.dimensions
    print("[david]  %-24s %6d tris  dims %.3f x %.3f x %.3f  origen z %.3f" % (o.name, tris(o), d.x, d.y, d.z, o.location.z))
    for s in o.material_slots:
        m = s.material
        if m and m.use_nodes:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image:
                    print("[david]  textura", n.image.name, n.image.size[:], "canales", n.image.channels)
                if n.type == "BSDF_PRINCIPLED":
                    print("[david]  metallic %.2f roughness %.2f" % (n.inputs["Metallic"].default_value, n.inputs["Roughness"].default_value))

# caja envolvente conjunta
lo = [1e9] * 3; hi = [-1e9] * 3
for o in mallas:
    for v in o.bound_box:
        w = o.matrix_world @ __import__("mathutils").Vector(v)
        for i in range(3):
            lo[i] = min(lo[i], w[i]); hi[i] = max(hi[i], w[i])
print("[david] caja: x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f" % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))
cx, cy, cz = [(lo[i] + hi[i]) / 2 for i in range(3)]
alto = hi[2] - lo[2]

if modo == "inspeccion":
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x = 512; sc.render.resolution_y = 640
    sc.render.film_transparent = False
    sc.world = bpy.data.worlds.new("W"); sc.world.color = (0.16, 0.36, 0.52)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam); sc.camera = cam
    cam.data.lens = 60
    dist = alto * 2.2
    for nombre, ang in (("frente", 0.0), ("3-4", 35.0), ("perfil", 90.0)):
        a = math.radians(ang)
        # el modelo mira a -Y en Blender (glTF +Z hacia delante -> Blender -Y)
        cam.location = (cx + dist * math.sin(a), cy - dist * math.cos(a), cz + alto * 0.05)
        cam.rotation_euler = (math.radians(88.0), 0.0, a)
        sc.render.filepath = OUT + "david_busto_%s.png" % nombre
        bpy.ops.render.render(write_still=True)
        print("[david] render", sc.render.filepath)
elif modo == "cara":
    # primer plano de la cabeza, de frente y a tres cuartos
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x = 640; sc.render.resolution_y = 640
    sc.world = bpy.data.worlds.new("W"); sc.world.color = (0.16, 0.36, 0.52)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam); sc.camera = cam
    cam.data.lens = 85
    dist = alto * 0.75
    zc = hi[2] - alto * 0.11
    for nombre, ang in (("cara_frente", 0.0), ("cara_3-4", 35.0)):
        a = math.radians(ang)
        cam.location = (cx + dist * math.sin(a), cy - dist * math.cos(a), zc)
        cam.rotation_euler = (math.radians(90.0), 0.0, a)
        sc.render.filepath = OUT + "david_%s.png" % nombre
        bpy.ops.render.render(write_still=True)
        print("[david] render", sc.render.filepath)
else:
    for o in mallas:
        if tris(o) > PRESUPUESTO * 1.05:
            m = o.modifiers.new("dec", "DECIMATE")
            m.ratio = PRESUPUESTO / tris(o)
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier="dec")
        # apoyado en el origen y centrado
        o.location.x -= cx; o.location.y -= cy; o.location.z -= lo[2]
    print("[david] triangulos tras decimar:", sum(tris(o) for o in mallas))
    bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", export_apply=True,
                              export_image_format="JPEG", export_jpeg_quality=85)
    print("[david] exportado", GLB)
