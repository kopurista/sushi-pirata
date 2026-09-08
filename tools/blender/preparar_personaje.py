# Prepara para el juego un personaje que Meshy devuelve RIGUEADO. Hace de una
# pasada todo lo que le falta:
#
#   1. OJOS. Viene sin ellos —solo cejas—, que es el fallo de siempre de
#      imagen→3D con una cara de trazo fino. Se ponen como GEOMETRÍA (dos
#      lentes negras pegadas a la cara con shrinkwrap), no pintando el atlas:
#      probado a pintarlo y el atlas tiene densidades MUY distintas por lado
#      (43.110 téxeles de ceja en uno y 26.873 en el otro), así que un ojo
#      salía negro y el otro lavado. Y de paso el ojo no se degrada al bajar la
#      textura a 1024.
#   2. HUESOS renombrados del esquema Mixamo al del juego, para que
#      CharacterAnim los coja tal cual (`_name` no pisa un nombre que ya venga).
#   3. ESCALA normalizada a 1.0 de alto con la base en 0.
#   4. TEXTURA a 1024 (la de Meshy viene a 4096: 16 veces más de la que este
#      retrato necesita).
#
#   5. MATERIAL sin emisión ni metálico, que Meshy los deja encendidos.
#
#   blender --background --python tools/blender/preparar_personaje.py -- #       <entrada.glb> <salida.glb> [ojos.json]
#
# Con el JSON que escribe `tools/quitar_ojos.py` los ojos van EXACTOS: sus
# fracciones se midieron sobre el concepto 2D del que salió el modelo, así que
# no hay que tantear nada.
import bpy, sys, os, math
import mathutils
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
_a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
GLB = os.path.abspath(_a[0])
DEST = os.path.abspath(_a[1])
# El tercer argumento es el JSON de `quitar_ojos.py`. Con "-" (o sin él) NO se
# pintan ojos: desde el 3-9-2026 el concepto va CON ojos y Meshy los modela,
# porque el personaje gesticula con los BRAZOS y la cara no cambia nunca.
_j = _a[2] if len(_a) > 2 else "-"
PONER_OJOS = _j != "-"
OJOS_JSON = os.path.abspath(_j) if PONER_OJOS else ""

# Sitio del ojo, en fracciones del ALTO DE LA CABEZA. Medido sobre el primer
# plano de la cara despejando contra la proyección de la cámara.
F_SEP = float(os.environ.get("OJO_SEP", 0.263))    # separación al eje
F_ANCHO = float(os.environ.get("OJO_ANCHO", 0.080))
F_ALTO = float(os.environ.get("OJO_ALTO", 0.126))
F_BAJO = float(os.environ.get("OJO_BAJO", 0.575))
PROF = float(os.environ.get("OJO_PROF", 0.45))     # grosor del ojo, del semieje
# LO QUE SE HUNDE ES FRACCIÓN DE LA PROFUNDIDAD DEL OJO, no del semieje
# horizontal: el ojo es una lenteja (0.45 de grosor) y hundiéndolo 0.78 del
# semieje se metía ENTERO dentro de la cabeza y desaparecía de la cara.
HUNDIDO = float(os.environ.get("OJO_HUNDIDO", 0.45))
OJO_ESC = float(os.environ.get("OJO_ESC", 1.55))  # los del concepto salen justos  # por debajo de la coronilla
TEX_LADO = int(os.environ.get("TEX_LADO", 1024))

# Si viene el JSON del concepto, sus fracciones MANDAN sobre las de arriba: se
# midieron sobre el dibujo del que salió este mismo modelo.
OJOS_DIBUJO = {}
if OJOS_JSON and os.path.exists(OJOS_JSON):
    import json
    OJOS_DIBUJO = json.load(open(OJOS_JSON, encoding="utf-8"))
    print("[pir] ojos del concepto:", OJOS_DIBUJO)

# Mixamo -> el esquema que CharacterAnim reconoce por nombre
RENOMBRAR = {
    "Hips": "Pelvis", "Spine": "Spine1", "Spine01": "Spine2", "Spine02": "Spine3",
    "neck": "Neck", "Head": "Head",
    "LeftShoulder": "L_Clavicle", "LeftArm": "L_Shoulder",
    "LeftForeArm": "L_Elbow", "LeftHand": "L_Wrist",
    "RightShoulder": "R_Clavicle", "RightArm": "R_Shoulder",
    "RightForeArm": "R_Elbow", "RightHand": "R_Wrist",
    "LeftUpLeg": "L_Hip", "LeftLeg": "L_Knee", "LeftFoot": "L_Ankle",
    "LeftToeBase": "L_Toe",
    "RightUpLeg": "R_Hip", "RightLeg": "R_Knee", "RightFoot": "R_Ankle",
    "RightToeBase": "R_Toe",
}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
sc = bpy.context.scene

# LAS ANIMACIONES DE MESHY SE TIRAN: el juego anima por código
# (CharacterAnim), y una acción puesta deja la malla en la pose del fotograma 1
# —que es lo que hacía que el modelo midiera 2,7 en vez de 1,7 y descuadró dos
# rondas de medidas del ojo.
for o in sc.objects:
    if o.animation_data:
        o.animation_data_clear()
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
sc.frame_set(0)

malla = [o for o in sc.objects if o.type == "MESH"][0]
arm = [o for o in sc.objects if o.type == "ARMATURE"][0]
bpy.context.view_layer.objects.active = malla
malla.select_set(True)

vs = [malla.matrix_world @ v.co for v in malla.data.vertices]
lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
alto = hi.z - lo.z
# la cabeza: desde el hueso Head hacia arriba
z_head = (arm.matrix_world @ arm.data.bones["Head"].head_local).z
alto_cab = hi.z - z_head
print("[pir] alto %.3f  cabeza desde z=%.3f (alto_cab %.3f)" % (alto, z_head, alto_cab))


def lente(signo: float):
    """Un ojo = una ESFERA ACHATADA medio hundida en la cara.

    Se probó antes con un disco pegado por shrinkwrap y NO vale: la cara está
    facetada, así que el disco se pliega, se hunde a trozos y sale RAYADO de
    z-fighting; y proyectando en +Y los vértices del borde atraviesan la cabeza
    y se pegan a la NUCA (medido: vértices en y=+0.270). Hundir una esfera es
    lo mismo que hace el ojo del David modelado a mano, y no puede fallar: lo
    que asoma es siempre un óvalo limpio.
    """
    if OJOS_DIBUJO:
        # z_frac se mide DESDE LA CORONILLA sobre el alto total, y las medidas
        # horizontales sobre el ANCHO DE LA SILUETA a esa altura, que es como
        # las apunta quitar_ojos.py
        z = hi.z - float(OJOS_DIBUJO["z_frac"]) * alto
        banda = [v for v in vs if abs(v.z - z) < alto * 0.02]
        ancho = (max(v.x for v in banda) - min(v.x for v in banda)) if banda else alto * 0.5
        x = signo * float(OJOS_DIBUJO["sep_frac"]) * ancho
        ra = float(OJOS_DIBUJO["rx_frac"]) * ancho
        rb = float(OJOS_DIBUJO["ry_frac"]) * alto
    else:
        x = signo * F_SEP * alto_cab
        z = hi.z - F_BAJO * alto_cab
        ra = F_ANCHO * alto_cab
        rb = F_ALTO * alto_cab
    # ¿a qué profundidad está la cara en ese punto? se pregunta con un rayo,
    # no se estima
    Minv = malla.matrix_world.inverted()
    org = Minv @ Vector((x, lo.y - 0.3, z))
    dirl = (Minv.to_3x3() @ Vector((0.0, 1.0, 0.0))).normalized()
    ok, loc, nor, _idx = malla.ray_cast(org, dirl)
    if not ok:
        print("[pir] AVISO: el rayo del ojo no toca la cara")
        loc = Minv @ Vector((x, lo.y, z))
        nor = Vector((0.0, -1.0, 0.0))
    p = malla.matrix_world @ loc
    n = (malla.matrix_world.to_3x3() @ nor).normalized()
    ra *= OJO_ESC
    rb *= OJO_ESC
    centro = p - n * (ra * PROF * HUNDIDO)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1.0,
                                         location=centro)
    o = bpy.context.object
    o.name = "Ojo%s" % ("L" if signo > 0 else "R")
    # POCA PROFUNDIDAD (no una bola): con la esfera redonda, al girar la cabeza
    # su parte trasera asomaba por el CANTO de la cara como una mancha negra
    o.scale = (ra, ra * PROF, rb)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.shade_smooth()
    m = bpy.data.materials.get("OjoNegro")
    if m is None:
        m = bpy.data.materials.new("OjoNegro")
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        _c = (1.0, 0.0, 1.0, 1) if os.environ.get("OJO_MAGENTA") else (0.02, 0.02, 0.025, 1)
        b.inputs["Base Color"].default_value = _c
        b.inputs["Roughness"].default_value = 0.35
        m.diffuse_color = _c
    o.data.materials.append(m)
    print("[pir] ojo %s en (%.3f, %.3f, %.3f)  semiejes %.3f x %.3f"
          % (o.name, centro.x, centro.y, centro.z, ra, rb))
    # LOS PESOS SE COPIAN DE LA PIEL DONDE SE APOYA EL OJO, no se ponen a
    # "Head" al 100%: la carne de la cara reparte entre Neck y Head y se
    # deforma poco, así que un ojo clavado a Head giraba de más y se DESPEGABA
    # de la cara al volver la cabeza (se veía un óvalo negro flotando al lado).
    kd = mathutils.kdtree.KDTree(len(malla.data.vertices))
    for i, v in enumerate(malla.data.vertices):
        kd.insert(malla.matrix_world @ v.co, i)
    kd.balance()
    grupos = {}
    for vi, v in enumerate(o.data.vertices):
        _co, idx, _d = kd.find(o.matrix_world @ v.co)
        for ge in malla.data.vertices[idx].groups:
            nom = malla.vertex_groups[ge.group].name
            if nom not in grupos:
                grupos[nom] = o.vertex_groups.new(name=nom)
            grupos[nom].add([vi], ge.weight, "REPLACE")
    print("[pir]   pesos copiados de la piel: %s" % sorted(grupos))
    return o


if PONER_OJOS:
    ojos = [lente(1.0), lente(-1.0)]
    # unir las lentes a la malla (conservan sus grupos de vértices, o sea el skin)
    bpy.ops.object.select_all(action="DESELECT")
    for o in ojos:
        o.select_set(True)
    malla.select_set(True)
    bpy.context.view_layer.objects.active = malla
    bpy.ops.object.join()
    print("[pir] ojos unidos: %d materiales" % len(malla.data.materials))
else:
    print("[pir] sin ojos que poner: los trae el propio modelo")

# --- huesos al esquema del juego ---------------------------------------------
ren = 0
for b in arm.data.bones:
    if b.name in RENOMBRAR:
        b.name = RENOMBRAR[b.name]
        ren += 1
print("[pir] huesos renombrados: %d de %d" % (ren, len(arm.data.bones)))

# --- normalizar: alto 1.0 y base en 0 ----------------------------------------
# LA ESCALA SE APLICA A LOS DATOS, no al objeto. El armature de Meshy viene con
# escala 0.01, y dejándosela puesta el conjunto acaba midiendo 0.005 en Godot:
# el modelo entra ENTERO por delante del plano cercano de la cámara del retrato
# y de él solo se ve una cuña negra (un ojo a bocajarro). Escalando los huesos
# en modo edición y los vértices de la malla, todo queda a escala 1.
from mathutils import Matrix

esc = (1.0 / alto) * arm.scale.x
S = Matrix.Scale(esc, 4)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
for eb in arm.data.edit_bones:
    eb.head = eb.head * esc
    eb.tail = eb.tail * esc
bpy.ops.object.mode_set(mode="OBJECT")
malla.data.transform(S)
arm.scale = (1.0, 1.0, 1.0)
arm.location = (arm.location[0] * esc, arm.location[1] * esc, arm.location[2] * esc)
if malla.parent is None:
    malla.scale = (1.0, 1.0, 1.0)
bpy.context.view_layer.update()
vs = [malla.matrix_world @ v.co for v in malla.data.vertices]
z0 = min(v.z for v in vs)
cx = (max(v.x for v in vs) + min(v.x for v in vs)) / 2.0
arm.location = (arm.location[0] - cx, arm.location[1], arm.location[2] - z0)
bpy.context.view_layer.update()
vs = [malla.matrix_world @ v.co for v in malla.data.vertices]
print("[pir] normalizado: alto %.3f  base z=%.3f  x %.3f..%.3f  escala arm %s"
      % (max(v.z for v in vs) - min(v.z for v in vs), min(v.z for v in vs),
         min(v.x for v in vs), max(v.x for v in vs), tuple(round(x, 3) for x in arm.scale)))

# --- material: sin emisión ni metálico ---------------------------------------
# El glb de Meshy viene con EMISIÓN encendida y METALLIC a 1 (medido en Godot:
# emision=true energia=1.00 met=1.00). Con eso el retrato salía QUEMADO —piel y
# barba a blanco— y ninguna perilla de luz lo arreglaba, porque la emisión se
# suma después de la iluminación. Es lo mismo que `glb_prepare.py` corrige en
# la cadena de Ludo.
for m in bpy.data.materials:
    if not m.use_nodes:
        continue
    for nd in m.node_tree.nodes:
        if nd.type == "BSDF_PRINCIPLED":
            if "Emission Strength" in nd.inputs:
                nd.inputs["Emission Strength"].default_value = 0.0
            if "Emission Color" in nd.inputs:
                nd.inputs["Emission Color"].default_value = (0, 0, 0, 1)
            if "Metallic" in nd.inputs:
                nd.inputs["Metallic"].default_value = 0.0
            if "Roughness" in nd.inputs and nd.inputs["Roughness"].default_value > 0.85:
                nd.inputs["Roughness"].default_value = 0.55
    m.metallic = 0.0
    print("[pir] material %s: emisión y metálico apagados" % m.name)

# --- textura a 1024 ----------------------------------------------------------
for im in bpy.data.images:
    if im.size[0] > TEX_LADO:
        antes = im.size[0]
        im.scale(TEX_LADO, TEX_LADO)
        print("[pir] textura %d -> %d" % (antes, TEX_LADO))

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=DEST, export_format="GLB",
                          export_apply=False, export_animations=False,
                          export_image_format="JPEG", export_jpeg_quality=92)
me = malla.data
me.calc_loop_triangles()
print("[pir] exportado %s  (%d tris)" % (DEST, len(me.loop_triangles)))
