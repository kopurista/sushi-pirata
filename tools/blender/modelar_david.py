# DAVID MODELADO EN BLENDER, sin pasar por Meshy.
#   blender --background --python tools/blender/modelar_david.py -- <salida.glb>
#
# POR QUE: Meshy devuelve UNA SOLA MASA con la textura proyectada, y de ahi
# venian todos los problemas que costaron una tarde: manchas donde el concepto
# no enseñaba nada, manoplas sin dedos, y una muñeca que no se podia girar
# porque la mano y la manga comparten poligonos. Aqui el personaje se construye
# por PIEZAS separadas —cabeza, barba, cuerpo, casaca, brazos, manos, botas—,
# cada una con su color plano, y las manos son piezas propias POR DISEÑO, asi
# que giran sin deformar nada.
#
# Todo va en fracciones de la altura (1.0) y con las proporciones del estilo de
# Link's Awakening: cabeza ~la mitad del alto, formas hinchadas sin aristas,
# manos de manopla y color plano por pieza.
import bpy, sys, os, math
import numpy as np
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
DEST = os.path.abspath(args[0]) if args else "david_blender.glb"
OUT = "C:/Users/KOPURI~1/AppData/Local/Temp/claude/C--Users-KOPURISTA-Desktop-GODOT-sushi/ddc3d8d7-b243-4937-ae48-84636d59f46b/scratchpad/"

# --- paleta (sRGB, la misma que ya tiene el personaje) ------------------------
PIEL = (0.973, 0.788, 0.671)
GRIS_PELO = (0.62, 0.61, 0.60)
AZUL = (0.02, 0.20, 0.42)
AZUL_CLARO = (0.17, 0.27, 0.37)
ORO = (0.93, 0.67, 0.11)
BLANCO = (0.94, 0.93, 0.91)
MARRON = (0.34, 0.18, 0.09)
NEGRO = (0.05, 0.05, 0.055)
BEIGE = (0.87, 0.80, 0.70)


def lineal(c):
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c)


_mats = {}


def mat(nombre, color, rug=0.32):
    if nombre in _mats:
        return _mats[nombre]
    m = bpy.data.materials.new(nombre)
    m.use_nodes = True
    b = [n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"][0]
    b.inputs["Base Color"].default_value = lineal(color) + (1.0,)
    b.inputs["Roughness"].default_value = rug
    b.inputs["Metallic"].default_value = 0.0
    # el Workbench NO mira el Base Color del BSDF: pinta con el color de
    # visualizacion del material, asi que hay que darselo tambien o los renders
    # de comprobacion salen todos grises
    m.diffuse_color = lineal(color) + (1.0,)
    m.roughness = rug
    _mats[nombre] = m
    return m


bpy.ops.wm.read_factory_settings(use_empty=True)
piezas = []


def pieza(obj, material):
    obj.data.materials.append(material)
    for p in obj.data.polygons:
        p.use_smooth = True
    piezas.append(obj)
    return obj


def esfera(nombre, centro, radios, segs=32, anillos=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=anillos, radius=1.0,
                                         location=centro)
    o = bpy.context.active_object
    o.name = nombre
    o.scale = Vector(radios)
    bpy.ops.object.transform_apply(scale=True)
    return o


def capsula(nombre, a, b, radio, segs=24):
    """Capsula de `a` a `b`: un cilindro con dos casquetes."""
    a = Vector(a); b = Vector(b)
    eje = b - a
    largo = eje.length
    bpy.ops.mesh.primitive_cylinder_add(vertices=segs, radius=radio, depth=largo,
                                        location=(a + b) / 2)
    cil = bpy.context.active_object
    cil.rotation_mode = "QUATERNION"
    cil.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(eje.normalized())
    bpy.ops.object.transform_apply(rotation=True)
    tapas = []
    for p in (a, b):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=segs // 2,
                                             radius=radio, location=p)
        tapas.append(bpy.context.active_object)
    bpy.ops.object.select_all(action="DESELECT")
    for t in tapas:
        t.select_set(True)
    cil.select_set(True)
    bpy.context.view_layer.objects.active = cil
    bpy.ops.object.join()
    cil.name = nombre
    return cil


def suavizar(o, niveles=1, factor=0.0):
    bpy.context.view_layer.objects.active = o
    if niveles:
        m = o.modifiers.new("sub", "SUBSURF")
        m.levels = niveles
        m.render_levels = niveles
        bpy.ops.object.modifier_apply(modifier="sub")
    if factor:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.vertices_smooth(factor=factor, repeat=2)
        bpy.ops.object.mode_set(mode="OBJECT")
    return o


# --- medidas del personaje (fracciones del alto, que es 1.0) -------------------
Z_SUELO = 0.0
Z_BOTA = 0.085          # alto de la bota
Z_CADERA = 0.20
Z_CINTURON = 0.30
Z_HOMBRO = 0.44
Z_CUELLO = 0.50
R_CABEZA = 0.245        # la cabeza es media figura
Z_CABEZA = 0.50 + R_CABEZA * 0.92
ANCHO_CUERPO = 0.175

# CABEZA: un ovoide algo mas ancho que alto
cabeza = esfera("Cabeza", (0.0, 0.0, Z_CABEZA), (R_CABEZA, R_CABEZA * 0.92, R_CABEZA * 1.06))
pieza(cabeza, mat("Piel", PIEL))
# orejas
for s in (1.0, -1.0):
    o = esfera("Oreja%s" % ("L" if s > 0 else "R"),
               (s * R_CABEZA * 0.96, 0.02, Z_CABEZA - R_CABEZA * 0.10),
               (R_CABEZA * 0.20, R_CABEZA * 0.16, R_CABEZA * 0.24), segs=20, anillos=12)
    pieza(o, mat("Piel", PIEL))
# nariz
nariz = esfera("Nariz", (0.0, -R_CABEZA * 0.86, Z_CABEZA - R_CABEZA * 0.30),
               (R_CABEZA * 0.16, R_CABEZA * 0.16, R_CABEZA * 0.15), segs=20, anillos=12)
pieza(nariz, mat("Piel", PIEL))

# OJOS: dos ovalos negros verticales, la marca del estilo
for s in (1.0, -1.0):
    o = esfera("Ojo%s" % ("L" if s > 0 else "R"),
               (s * R_CABEZA * 0.38, -R_CABEZA * 0.80, Z_CABEZA + R_CABEZA * 0.02),
               (R_CABEZA * 0.115, R_CABEZA * 0.10, R_CABEZA * 0.20), segs=20, anillos=12)
    pieza(o, mat("Negro", NEGRO, rug=0.25))
# CEJAS: dos capsulas gruesas por encima
for s in (1.0, -1.0):
    c = capsula("Ceja%s" % ("L" if s > 0 else "R"),
                (s * R_CABEZA * 0.20, -R_CABEZA * 0.80, Z_CABEZA + R_CABEZA * 0.32),
                (s * R_CABEZA * 0.60, -R_CABEZA * 0.70, Z_CABEZA + R_CABEZA * 0.34),
                R_CABEZA * 0.055, segs=16)
    pieza(c, mat("Pelo", GRIS_PELO))

# BIGOTE: dos capsulas curvadas bajo la nariz
for s in (1.0, -1.0):
    b = capsula("Bigote%s" % ("L" if s > 0 else "R"),
                (0.0, -R_CABEZA * 0.92, Z_CABEZA - R_CABEZA * 0.42),
                (s * R_CABEZA * 0.52, -R_CABEZA * 0.74, Z_CABEZA - R_CABEZA * 0.30),
                R_CABEZA * 0.085, segs=16)
    pieza(b, mat("Pelo", GRIS_PELO))

# BARBA: una masa redondeada que cuelga de la cara al pecho
# BARBA: no una bola, sino una masa ancha pegada a la cara que baja al pecho,
# como la de Tarin. Va en dos trozos: la parte de la cara y la punta.
barba = esfera("Barba", (0.0, -R_CABEZA * 0.22, Z_CABEZA - R_CABEZA * 0.62),
               (R_CABEZA * 0.86, R_CABEZA * 0.80, R_CABEZA * 0.50), segs=28, anillos=16)
pieza(barba, mat("Pelo", GRIS_PELO))
punta = esfera("BarbaPunta", (0.0, -R_CABEZA * 0.30, Z_CABEZA - R_CABEZA * 1.02),
               (R_CABEZA * 0.60, R_CABEZA * 0.56, R_CABEZA * 0.42), segs=24, anillos=14)
pieza(punta, mat("Pelo", GRIS_PELO))

# CUERPO: capsula ancha del cinturon al cuello
cuerpo = capsula("Cuerpo", (0.0, 0.0, Z_CADERA), (0.0, 0.0, Z_HOMBRO), ANCHO_CUERPO, segs=28)
pieza(cuerpo, mat("Camisa", BLANCO))

# CASACA: un abrigo ABIERTO de verdad. Es un cilindro sin tapas alrededor del
# torso al que se le quita el sector de delante, para que se vea la camisa; con
# dos bolas a los lados (el primer intento) parecia que llevara flotadores.
bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=1.0, depth=1.0,
                                    end_fill_type="NOTHING",
                                    location=(0.0, 0.0, (Z_CADERA + Z_HOMBRO) / 2))
casaca = bpy.context.active_object
casaca.name = "Casaca"
casaca.scale = (ANCHO_CUERPO * 1.14, ANCHO_CUERPO * 1.24, (Z_HOMBRO - Z_CADERA) * 1.30)
bpy.ops.object.transform_apply(scale=True)
# se abre por delante: fuera los vértices del sector frontal
ABRE = math.radians(float(os.environ.get("ABERTURA", 54.0)))
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="DESELECT")
bpy.ops.object.mode_set(mode="OBJECT")
for v in casaca.data.vertices:
    ang = math.atan2(v.co.x, -v.co.y)      # 0 = justo delante
    if abs(ang) < ABRE:
        v.select = True
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.delete(type="VERT")
bpy.ops.object.mode_set(mode="OBJECT")
# y se le da grosor, o se ve como un papel
gr = casaca.modifiers.new("solid", "SOLIDIFY")
gr.thickness = 0.012
gr.offset = 0.0
bpy.context.view_layer.objects.active = casaca
bpy.ops.object.modifier_apply(modifier="solid")
pieza(casaca, mat("Azul", AZUL))

# hombreras, que rematan el abrigo arriba
for s_ in (1.0, -1.0):
    h = esfera("Hombro%s" % ("L" if s_ > 0 else "R"),
               (s_ * ANCHO_CUERPO * 0.86, 0.0, Z_HOMBRO - 0.020),
               (ANCHO_CUERPO * 0.46, ANCHO_CUERPO * 0.66, 0.070), segs=24, anillos=14)
    pieza(h, mat("Azul", AZUL))

# CINTURON y hebilla
cint = capsula("Cinturon", (-ANCHO_CUERPO * 0.55, 0.0, Z_CINTURON),
               (ANCHO_CUERPO * 0.55, 0.0, Z_CINTURON), ANCHO_CUERPO * 0.72, segs=28)
pieza(cint, mat("Cuero", MARRON))
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -ANCHO_CUERPO * 0.98, Z_CINTURON))
heb = bpy.context.active_object
heb.name = "Hebilla"
heb.scale = (0.055, 0.02, 0.055)
bpy.ops.object.transform_apply(scale=True)
suavizar(heb, niveles=2)
pieza(heb, mat("Oro", ORO, rug=0.25))

# PANTALON
pant = capsula("Pantalon", (0.0, 0.0, Z_BOTA + 0.02), (0.0, 0.0, Z_CADERA + 0.02),
               ANCHO_CUERPO * 0.68, segs=24)
pieza(pant, mat("Beige", BEIGE))

# BOTAS
for s in (1.0, -1.0):
    b = esfera("Bota%s" % ("L" if s > 0 else "R"),
               (s * 0.062, -0.012, Z_BOTA * 0.55),
               (0.062, 0.085, Z_BOTA * 0.75), segs=24, anillos=14)
    pieza(b, mat("Negro", NEGRO, rug=0.28))

# BRAZOS: capsulas de piel con la manga azul por encima
BRAZO_X = 0.235
Z_MUNECA = 0.255
for s in (1.0, -1.0):
    lado = "L" if s > 0 else "R"
    br = capsula("Brazo%s" % lado,
                 (s * ANCHO_CUERPO * 0.85, 0.0, Z_HOMBRO - 0.03),
                 (s * BRAZO_X, 0.0, Z_MUNECA), 0.043, segs=20)
    pieza(br, mat("Piel", PIEL))
    mg = capsula("Manga%s" % lado,
                 (s * ANCHO_CUERPO * 0.80, 0.0, Z_HOMBRO - 0.02),
                 (s * (BRAZO_X - 0.022), 0.0, Z_MUNECA + 0.042), 0.052, segs=20)
    pieza(mg, mat("Azul", AZUL))
    pu = capsula("Puno%s" % lado,
                 (s * (BRAZO_X - 0.030), 0.0, Z_MUNECA + 0.052),
                 (s * (BRAZO_X - 0.018), 0.0, Z_MUNECA + 0.028), 0.058, segs=20)
    pieza(pu, mat("Oro", ORO, rug=0.28))

# MANOS: la pieza de Meshy, que tiene dedos y pulgar de verdad. Aqui entra como
# una pieza mas —igual que la cabeza o las botas— asi que gira sin tocar nada.
MANO_GLB = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(DEST))),
                        "_gen", "meshy", "mano_toy_crudo.glb")
if not os.path.exists(MANO_GLB):
    MANO_GLB = os.path.abspath("_gen/meshy/mano_toy_crudo.glb")
if os.path.exists(MANO_GLB):
    antes = set(o.name for o in bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=MANO_GLB)
    mano = [o for o in bpy.context.scene.objects if o.name not in antes and o.type == "MESH"][0]
    mp = [mano.matrix_world @ v.co for v in mano.data.vertices]
    mlo = Vector([min(p[i] for p in mp) for i in range(3)])
    mhi = Vector([max(p[i] for p in mp) for i in range(3)])
    tris_m = sum(len(p.vertices) - 2 for p in mano.data.polygons)
    bpy.context.view_layer.objects.active = mano
    md = mano.modifiers.new("dec", "DECIMATE")
    md.ratio = min(1.0, 1800.0 / tris_m)
    bpy.ops.object.modifier_apply(modifier="dec")
    mano.data.materials.clear()
    for s_ in (1.0, -1.0):
        d = mano.copy(); d.data = mano.data.copy()
        bpy.context.scene.collection.objects.link(d)
        d.name = "Mano%s" % ("L" if s_ > 0 else "R")
        esc = 0.115 / (mhi[2] - mlo[2])
        eje = Vector((s_ * 0.40, 0.0, -1.0)).normalized()
        q = Vector((0.0, 0.0, 1.0)).rotation_difference(eje)
        q = q @ Matrix.Rotation(math.radians(90.0 * s_), 4, "Z").to_quaternion()
        centro = (mlo + mhi) / 2
        ancla = Vector((s_ * BRAZO_X, 0.0, Z_MUNECA + 0.010))
        d.matrix_world = (Matrix.Translation(ancla) @ q.to_matrix().to_4x4()
                          @ Matrix.Scale(esc, 4)
                          @ Matrix.Translation(-Vector((centro.x, centro.y, mlo.z))))
        pieza(d, mat("Piel", PIEL))
    bpy.data.objects.remove(mano, do_unlink=True)
    print("[david] manos injertadas")

print("[david] piezas: %d" % len(piezas))
for o in piezas:
    suavizar(o, niveles=0, factor=0.0)

# --- render de comprobacion ----------------------------------------------------
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.type = "SOLID"
sc.display.shading.light = "STUDIO"
sc.display.shading.studio_light = "Default"
sc.display.shading.color_type = "MATERIAL"
sc.display.shading.show_specular_highlight = True
sc.render.resolution_x = 560
sc.render.resolution_y = 720
sc.world = bpy.data.worlds.new("W")
sc.world.color = (0.16, 0.36, 0.52)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.lens = 60
for nombre, ang in (("frente", 0.0), ("3-4", 32.0), ("perfil", 88.0)):
    a = math.radians(ang)
    d = 2.3
    cam.location = (d * math.sin(a), -d * math.cos(a), 0.52)
    cam.rotation_euler = (math.radians(88.0), 0.0, a)
    sc.render.filepath = OUT + "dmod_%s.png" % nombre
    bpy.ops.render.render(write_still=True)
bpy.data.objects.remove(cam)

bpy.ops.object.select_all(action="DESELECT")
for o in piezas:
    o.select_set(True)
bpy.context.view_layer.objects.active = piezas[0]
bpy.ops.object.join()
final = bpy.context.active_object
final.name = "David"
print("[david] unido: %d vertices, %d tris, %d materiales" % (
    len(final.data.vertices),
    sum(len(p.vertices) - 2 for p in final.data.polygons),
    len(final.data.materials)))
bpy.ops.export_scene.gltf(filepath=DEST, export_format="GLB", export_apply=True)
print("[david] exportado", DEST)
