import bpy, sys, os, math, mathutils
a = sys.argv[sys.argv.index("--") + 1:]
ruta, tex, salida = a[0], a[1], a[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=ruta)
if tex != "-":
    # la textura del glb viene EMBEBIDA: tocar su filepath no hace nada, hay que
    # sustituir la imagen en el nodo TEX_IMAGE del material
    nueva = bpy.data.images.load(os.path.abspath(tex))
    n = 0
    for m in bpy.data.materials:
        if m.use_nodes:
            for nd in m.node_tree.nodes:
                if nd.type == "TEX_IMAGE":
                    nd.image = nueva; n += 1
    print("nodos de textura sustituidos:", n)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.42, 0.55, 0.65)
sc.render.resolution_x, sc.render.resolution_y = 600, 600
vs = []
for ob in sc.objects:
    if ob.type == "MESH":
        for v in ob.data.vertices: vs.append(ob.matrix_world @ v.co)
hiz = max(v.z for v in vs); loz = min(v.z for v in vs); alto = hiz - loz
cd = bpy.data.cameras.new("c"); cd.type = "ORTHO"
cam = bpy.data.objects.new("Cam", cd); sc.collection.objects.link(cam); sc.camera = cam
for i, (esc, cz) in enumerate([(0.46, hiz - alto * 0.16), (1.25, (hiz + loz) / 2)]):
    cd.ortho_scale = alto * esc
    cam.location = mathutils.Vector((0, -alto * 3, cz)); cam.rotation_euler = (math.radians(90), 0, 0)
    sc.render.filepath = os.path.abspath("%s_%d.png" % (salida, i))
    bpy.ops.render.render(write_still=True)
print("ok")
