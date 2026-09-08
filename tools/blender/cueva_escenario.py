# LAS PAREDES DE LA CUEVA EN ESTILO LINK'S AWAKENING, MONTADAS EN BLENDER
# (7-9-2026, pedido por el usuario: "genera el interior de una cueva con Ludo
# que encaje con el escenario y recreala luego con Blender"). El concepto es
# `_gen/la6/cueva_int_1.webp`: pedruscos REDONDEADOS de color caqui oliva,
# apilados como cantos rodados, con parches de musgo en las caras de arriba,
# cerrando los costados y el fondo, y la BOCA arriba en el centro. Salen
# tambien las ROCAS del suelo y las ESTALAGMITAS, del mismo caqui: las de
# Meshy (azul palido) desentonaban al lado de estas paredes.
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background \
#       --python tools/blender/cueva_escenario.py
#
# Sale `_gen/la6/la_cueva_escenario.glb` (se lleva a assets/models con su
# .import). El suelo (plano con `la_cueva_suelo.webp`), los cristales, las
# setas, la luz de la boca y el pasadizo siguen siendo de Godot
# (`level3d._scenery_cueva`).
#
# COORDENADAS: los pedruscos se colocan en (u, w) DE PANTALLA, como todo el
# decorado del nivel (ver SceneryLA.uw), y se pasan a mundo de Godot y de ahi
# a Blender (x, y, z) -> (x, -z, y). Lo que se ve: |u| <= 4.78 y w de -7.8 a
# 5.8; el pasillo de la clientela es el rombo |u|+|w| <= 5.23, asi que las
# caras interiores de la roca van por fuera de ~6.
#
# EL COLOR VA HORNEADO: material procedural (ruido caqui + musgo en las caras
# que miran arriba) horneado a UN atlas de 2048 sobre la malla ya unida y
# decimada — Godot no la vuelve a decimar (presupuesto por encima), que el
# decimador del motor funde las costuras del atlas y saca motas (ver rebake).
# LA PALETA VA CLARA a proposito (medido en captura: la primera pasada, mas
# parda y con mas contraste, se iba a negro con la luz de la cueva).
import bpy, math, random, sys, os
from mathutils import Vector

ROOT = "C:/Users/KOPURISTA/Desktop/GODOT/sushi"
OUT = os.environ.get("CUEVA_OUT", ROOT + "/_gen/la6/la_cueva_escenario.glb")
TEX = int(os.environ.get("CUEVA_TEX", 2048))
CARAS = int(os.environ.get("CUEVA_CARAS", 26000))
random.seed(7)


def uw(u, w):
    """(u, w) de pantalla -> (x, z) de mundo de Godot (SceneryLA.uw)."""
    return (0.70710678 * u + 0.70710678 * w, -0.70710678 * u + 0.70710678 * w)


def a_blender(x, y, z):
    return (x, -z, y)


def lineal(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


# (u, w, base_y, rx, ry, rz): rx a lo ancho de pantalla, ry el ALTO (semieje),
# rz el fondo. Los de la fila de atras (B) rellenan los huecos de la de
# delante (A); los laterales van por fuera del rombo del pasillo.
PEDRUSCOS = []
# fondo, fila A
for u, w, rx, ry, rz in [(-8.3, -8.0, 1.7, 1.9, 1.5), (-6.5, -8.2, 1.5, 1.6, 1.4),
        (-4.8, -7.9, 1.45, 1.8, 1.4), (-3.25, -8.1, 1.35, 1.5, 1.3),
        (3.25, -8.1, 1.35, 1.55, 1.3), (4.8, -7.9, 1.45, 1.75, 1.4),
        (6.5, -8.2, 1.5, 1.65, 1.4), (8.3, -8.0, 1.7, 1.9, 1.5)]:
    PEDRUSCOS.append((u, w, -0.6, rx, ry, rz))
# las jambas de la boca, mas altas, y el dintel encima
PEDRUSCOS += [(-2.05, -7.7, -0.6, 1.3, 2.0, 1.25), (2.05, -7.7, -0.6, 1.3, 2.0, 1.25),
              (0.0, -8.45, 1.55, 2.5, 1.15, 1.3)]
# fondo, fila B (detras y algo mas alta: tapa los huecos entre las de A)
for u in (-7.4, -5.7, -4.0, -2.6, 2.6, 4.0, 5.7, 7.4):
    PEDRUSCOS.append((u, -8.95, 0.35, 1.3, 1.35, 1.2))
# esquinas
PEDRUSCOS += [(-7.3, -7.3, -0.3, 1.8, 2.0, 1.8), (7.3, -7.3, -0.3, 1.8, 2.0, 1.8),
              (-7.4, 6.8, -0.5, 1.8, 1.9, 1.8), (7.4, 6.8, -0.5, 1.8, 1.9, 1.8)]
# laterales: la cara interior queda a |u| ~4.2 arriba y abajo, y se aparta
# donde el pasillo se acerca al canto (|w| pequeño)
for lado in (-1.0, 1.0):
    for w, u, rx, ry, rz in [(-6.4, 5.5, 1.4, 1.6, 1.4), (-4.6, 5.55, 1.3, 1.5, 1.3),
            (-2.9, 5.6, 1.25, 1.4, 1.2), (-1.2, 6.0, 1.2, 1.35, 1.2),
            (1.2, 6.0, 1.2, 1.35, 1.2), (2.9, 5.6, 1.25, 1.45, 1.2),
            (4.6, 5.55, 1.3, 1.5, 1.3), (6.4, 5.5, 1.4, 1.6, 1.4)]:
        PEDRUSCOS.append((lado * u, w, -0.6, rx, ry, rz))
    for w in (-5.5, -3.7, -2.0, 2.0, 3.7, 5.5):
        PEDRUSCOS.append((lado * 7.1, w, 0.4, 1.3, 1.35, 1.25))
# ROCAS DEL SUELO (donde `_scenery_cueva` ponia las de Meshy) y unas cuantas
# piedras menores, apoyadas en el suelo del nivel (y=0)
PEDRUSCOS += [(-3.5, -4.3, 0.0, 0.85, 0.72, 0.8), (3.3, -4.6, 0.0, 0.8, 0.66, 0.75),
              (-4.3, 0.6, 0.0, 0.5, 0.42, 0.48), (4.4, 1.0, 0.0, 0.42, 0.36, 0.4),
              (-2.6, 5.2, 0.0, 0.36, 0.30, 0.34), (2.4, -5.9, 0.0, 0.30, 0.26, 0.3)]
# ESTALAGMITAS: conos achaparrados (semiejes: estrechos y altos)
for u, w, h in [(-2.2, -5.2, 1.5), (2.0, -5.3, 1.3), (-3.6, 3.6, 1.2), (3.7, 3.5, 1.0)]:
    PEDRUSCOS.append((u, w, -0.05, h * 0.30, h * 0.5, h * 0.30))

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
bump = bpy.data.textures.new("bultos", "CLOUDS")
bump.noise_scale = 0.9
bump.noise_depth = 2

piezas = []
for (u, w, base, rx, ry, rz) in PEDRUSCOS:
    x, z = uw(u, w)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=28, ring_count=18, radius=1.0,
        location=a_blender(x, base + ry, z))
    o = bpy.context.active_object
    o.scale = (rx, rz, ry)          # en Blender el alto es Z
    # cada pedrusco algo girado, y ligeramente aplastado hacia dentro
    o.rotation_euler = (math.radians(random.uniform(-8, 8)),
                        math.radians(random.uniform(-8, 8)),
                        math.radians(random.uniform(0, 360)))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    m = o.modifiers.new("bultos", "DISPLACE")
    m.texture = bump
    m.strength = 0.26 * min(rx, ry, rz)
    m.mid_level = 0.5
    m.texture_coords = "GLOBAL"
    bpy.ops.object.modifier_apply(modifier=m.name)
    piezas.append(o)
print("[cueva] %d pedruscos" % len(piezas))

# unir, suavizar y decimar a presupuesto
bpy.ops.object.select_all(action="DESELECT")
for o in piezas:
    o.select_set(True)
bpy.context.view_layer.objects.active = piezas[0]
bpy.ops.object.join()
obj = bpy.context.active_object
obj.name = "cueva_paredes"
obj.data.name = "cueva_paredes"
bpy.ops.object.shade_smooth()
tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
if tris > CARAS:
    d = obj.modifiers.new("dec", "DECIMATE")
    d.ratio = CARAS / float(tris)
    d.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier="dec")
print("[cueva] %d -> %d triangulos" % (tris, sum(len(p.vertices) - 2 for p in obj.data.polygons)))

# atlas nuevo
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.01,
    area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
bpy.ops.object.mode_set(mode="OBJECT")

# --- material PROCEDURAL: caqui moteado con musgo en las caras de arriba ---
# (2a pasada: la roca menos amarilla y el musgo mas escaso y apagado; con la
# luz verde de los cristales los pedruscos se leian como ARBUSTOS, visto en
# captura con la clientela sentada)
mat = bpy.data.materials.new("roca_cueva")
mat.use_nodes = True
nt = mat.node_tree
bsdf = nt.nodes["Principled BSDF"]
bsdf.inputs["Roughness"].default_value = 0.85
coord = nt.nodes.new("ShaderNodeTexCoord")
ruido = nt.nodes.new("ShaderNodeTexNoise")
ruido.inputs["Scale"].default_value = 2.2
ruido.inputs["Detail"].default_value = 2.5
ruido.inputs["Roughness"].default_value = 0.5
nt.links.new(coord.outputs["Object"], ruido.inputs["Vector"])
rampa = nt.nodes.new("ShaderNodeValToRGB")
rampa.color_ramp.elements[0].position = 0.30
rampa.color_ramp.elements[0].color = (lineal(0.50), lineal(0.46), lineal(0.36), 1.0)
rampa.color_ramp.elements[1].position = 0.72
rampa.color_ramp.elements[1].color = (lineal(0.68), lineal(0.63), lineal(0.50), 1.0)
nt.links.new(ruido.outputs["Fac"], rampa.inputs["Fac"])
# musgo: solo donde la normal mira arriba, y solo en manchas
geo = nt.nodes.new("ShaderNodeNewGeometry")
sep = nt.nodes.new("ShaderNodeSeparateXYZ")
nt.links.new(geo.outputs["Normal"], sep.inputs["Vector"])
arriba = nt.nodes.new("ShaderNodeMapRange")
arriba.inputs["From Min"].default_value = 0.40
arriba.inputs["From Max"].default_value = 0.85
nt.links.new(sep.outputs["Z"], arriba.inputs["Value"])
ruido2 = nt.nodes.new("ShaderNodeTexNoise")
ruido2.inputs["Scale"].default_value = 1.4
ruido2.inputs["Detail"].default_value = 2.0
nt.links.new(coord.outputs["Object"], ruido2.inputs["Vector"])
mult = nt.nodes.new("ShaderNodeMath")
mult.operation = "MULTIPLY"
nt.links.new(arriba.outputs["Result"], mult.inputs[0])
nt.links.new(ruido2.outputs["Fac"], mult.inputs[1])
corte = nt.nodes.new("ShaderNodeValToRGB")
corte.color_ramp.elements[0].position = 0.44
corte.color_ramp.elements[0].color = (0, 0, 0, 1)
corte.color_ramp.elements[1].position = 0.50
corte.color_ramp.elements[1].color = (1, 1, 1, 1)
nt.links.new(mult.outputs["Value"], corte.inputs["Fac"])
mezcla = nt.nodes.new("ShaderNodeMix")
mezcla.data_type = "RGBA"
mezcla.inputs[7].default_value = (lineal(0.42), lineal(0.60), lineal(0.30), 1.0)   # musgo (B)
nt.links.new(rampa.outputs["Color"], mezcla.inputs[6])   # A: la roca
nt.links.new(corte.outputs["Color"], mezcla.inputs[0])   # factor
nt.links.new(mezcla.outputs[2], bsdf.inputs["Base Color"])
# el destino del horneado
img = bpy.data.images.new("cueva_horneado", TEX, TEX, alpha=False)
tex_node = nt.nodes.new("ShaderNodeTexImage")
tex_node.image = img
nt.nodes.active = tex_node
obj.data.materials.clear()
obj.data.materials.append(mat)

sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 6
sc.render.bake.use_pass_direct = False
sc.render.bake.use_pass_indirect = False
sc.render.bake.use_pass_color = True
sc.render.bake.use_selected_to_active = False
sc.render.bake.margin = 12
sc.render.bake.margin_type = "EXTEND"
bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.object.bake(type="DIFFUSE")
img.pack()
print("[cueva] horneado %dx%d" % (TEX, TEX))

# el material que viaja: solo la imagen horneada
final = bpy.data.materials.new("roca_cueva_horneada")
final.use_nodes = True
fnt = final.node_tree
fb = fnt.nodes["Principled BSDF"]
fb.inputs["Roughness"].default_value = 0.85
fb.inputs["Metallic"].default_value = 0.0
ft = fnt.nodes.new("ShaderNodeTexImage")
ft.image = img
fnt.links.new(ft.outputs["Color"], fb.inputs["Base Color"])
obj.data.materials.clear()
obj.data.materials.append(final)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_apply=True,
    export_animations=False, export_yup=True, use_selection=True,
    export_image_format="JPEG", export_jpeg_quality=90)
print("[cueva] exportado", OUT)
