# DECIMA EN BLENDER Y RE-HORNEA LA TEXTURA SOBRE UN ATLAS LIMPIO (7-9-2026).
#
# El atlas de Meshy viene TROCEADO en miles de islas, y el decimador de Godot
# (import_hooks/decimate_import.gd) funde vertices a traves de sus costuras:
# las UV de los triangulos simplificados se salen de su isla y muestrean los
# huecos del atlas — MEDIDO en el grumete: 1659 pixeles de mota decimado
# frente a 1050 sin decimar, y en captura la cara sale limpia sin decimar y
# llena de rayas claras decimada ("manchas", "rugosidad", dicho por el usuario).
#
# Aqui la malla se decima con Blender (collapse, conserva los pesos del rig),
# se le da un atlas NUEVO con Smart UV Project (islas grandes, con margen) y se
# le HORNEA encima la textura de la malla original (Cycles, "selected to
# active", con dilatacion de 16 px). Godot recibe la malla ya a su presupuesto
# y no vuelve a decimar (BUDGETS por encima del recuento).
#
#   blender --background --python tools/blender/rebake.py -- \
#       <in.glb> <out.glb> [caras=14000] [textura=1024]
import bpy, sys, os, math

a = sys.argv[sys.argv.index("--") + 1:]
src, dst = os.path.abspath(a[0]), os.path.abspath(a[1])
CARAS = int(a[2]) if len(a) > 2 else 14000
TEX = int(a[3]) if len(a) > 3 else 1024

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 8
sc.render.bake.use_pass_direct = False
sc.render.bake.use_pass_indirect = False
sc.render.bake.use_pass_color = True
sc.render.bake.use_selected_to_active = True
sc.render.bake.cage_extrusion = 0.03
sc.render.bake.max_ray_distance = 0.08
sc.render.bake.margin = 16
sc.render.bake.margin_type = "EXTEND"

mallas = [o for o in sc.objects if o.type == "MESH" and not o.name.startswith("Icosphere")]
for o in mallas:
    caras0 = len(o.data.polygons)
    # --- 1. la FUENTE del horneado: una copia intacta con su textura -------
    fuente = o.copy()
    fuente.data = o.data.copy()
    sc.collection.objects.link(fuente)
    fuente.name = o.name + "_fuente"
    # --- 2. SOLDAR y decimar la copia de trabajo (los pesos se interpolan) --
    # La malla de Meshy viene PARTIDA en cada costura del atlas: sin soldar,
    # el decimado deja miles de parches sueltos y Smart UV hace una isla por
    # parche —el primer intento horneo una papilla de rombos—. Umbral diminuto,
    # que el de serie suelda vertices que no son vecinos (leccion de David).
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0001)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    if o.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    print("[rebake] %s: soldado a %d vertices" % (o.name, len(o.data.vertices)))
    if caras0 > CARAS:
        mod = o.modifiers.new("dec", "DECIMATE")
        mod.ratio = CARAS / float(caras0)
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="dec")
    bpy.ops.object.shade_smooth()
    # --- 3. atlas nuevo: islas grandes con margen ---------------------------
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.012,
        area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    # --- 4. material propio con la imagen destino ---------------------------
    img = bpy.data.images.new("horneado_%s" % o.name, TEX, TEX, alpha=False)
    mat = bpy.data.materials.new("mat_%s" % o.name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.55
    bsdf.inputs["Metallic"].default_value = 0.0
    nt.nodes.active = tex
    o.data.materials.clear()
    o.data.materials.append(mat)
    # --- 5. hornear la fuente sobre el atlas nuevo --------------------------
    bpy.ops.object.select_all(action="DESELECT")
    fuente.select_set(True)
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.bake(type="DIFFUSE")
    img.pack()
    bpy.data.objects.remove(fuente, do_unlink=True)
    print("[rebake] %s: %d -> %d caras, atlas %dx%d" % (o.name, caras0, len(o.data.polygons), TEX, TEX))

# fuera el icosaedro suelto, si viene
for o in list(sc.objects):
    if o.type == "MESH" and o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_apply=False,
    export_animations=False, export_skins=True, export_image_format="JPEG",
    export_jpeg_quality=92)
print("[rebake] exportado", dst)
