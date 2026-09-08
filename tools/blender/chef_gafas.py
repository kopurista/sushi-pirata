# LAS GAFAS DEL CHEF, construidas sobre los OJOS MEDIDOS.
#
# No se extraen de Miku ni de nadie: unas gafas son dos aros, un puente y dos
# patillas, y lo unico que importa es que caigan CENTRADAS en los ojos y
# apoyadas en la cara. Eso se mide —los ojos son los texeles oscuros de la
# cara, como en `chef_piezas.py`— y la profundidad de cada pieza se pregunta a
# la propia cara con un RAYO, igual que la nariz.
#
# La montura va en BLANCO y la tiñe el juego con `albedo_color`, como el pelo,
# asi que de una malla salen todas las monturas que se quieran.
#
#   blender --background --python tools/blender/chef_gafas.py -- <cuerpo.glb> <carpeta>
import bpy, sys, os, math
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = os.path.abspath(a[0]), os.path.abspath(a[1])
os.makedirs(OUT, exist_ok=True)

ARO = float(os.environ.get("GAFAS_ARO", 0.72))      # radio del aro, en semialtos de ojo
TUBO = float(os.environ.get("GAFAS_TUBO", 0.20))    # grosor de la montura, idem
FUERA = float(os.environ.get("GAFAS_FUERA", 0.030)) # cuanto se separa de la cara, en radios de cabeza
PATILLA = float(os.environ.get("GAFAS_PATILLA", 0.72))  # largo, en radios de cabeza
# EL CRISTAL VA MAS ALTO QUE ANCHO, como los ojos de estos personajes. El ancho
# lo limita la separacion entre ojos —si se pasa, los dos aros se CRUZAN— asi
# que la unica forma de que el ojo quepa dentro del cristal es estirarlo a lo
# alto. Con aros redondos, el ojo asomaba por arriba y por abajo.
ALTO = float(os.environ.get("GAFAS_ALTO", 1.55))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
sc = bpy.context.scene
malla = max((o for o in sc.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
arm = next((o for o in sc.objects if o.type == "ARMATURE"), None)
M = malla.matrix_world
Minv = M.inverted()
vs = [M @ v.co for v in malla.data.vertices]
lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
alto = hi.z - lo.z
anchos = []
for k in range(30, 62):
    z = lo.z + alto * k / 100.0
    banda = [v for v in vs if abs(v.z - z) < alto * 0.01]
    if len(banda) > 20:
        anchos.append((max(v.x for v in banda) - min(v.x for v in banda), z))
z_cuello = min(anchos)[1] if anchos else lo.z + alto * 0.55
alto_cab = hi.z - z_cuello
R = alto_cab * 0.47

# --- LOS OJOS: los texeles oscuros de la cara ---------------------------------
malla.data.calc_loop_triangles()
img = next((i for i in bpy.data.images if i.size[0] > 8), None)
uv = malla.data.uv_layers.active.data if malla.data.uv_layers.active else None
W, H = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[..., :3]
col = np.zeros((len(malla.data.vertices), 3))
cnt = np.zeros(len(malla.data.vertices))
for tri in malla.data.loop_triangles:
    if tri.normal.y > -0.25:
        continue
    for vi, li in zip(tri.vertices, tri.loops):
        u, w = uv[li].uv
        col[vi] += px[int(w * (H - 1)) % H, int(u * (W - 1)) % W]
        cnt[vi] += 1
ok = cnt > 0
col[ok] /= cnt[ok][:, None]
Vw = np.array([M @ v.co for v in malla.data.vertices])
oscuro = ok & (col.mean(axis=1) < 0.16) & (Vw[:, 2] > z_cuello + alto_cab * 0.25)

ojos = []
for signo in (1.0, -1.0):
    sel = oscuro & ((Vw[:, 0] * signo) > 0.01)
    if sel.sum() < 20:
        raise SystemExit("[gafas] no encuentro el ojo")
    P = Vw[sel]
    cx = float(np.median(P[:, 0]))
    cz = float(np.median(P[:, 2]))
    semi_z = float(np.percentile(P[:, 2], 96) - np.percentile(P[:, 2], 4)) / 2.0
    semi_x = float(np.percentile(P[:, 0], 96) - np.percentile(P[:, 0], 4)) / 2.0
    ojos.append((cx, cz, semi_x, semi_z))
    print("[gafas] ojo %s: centro (%.4f, %.4f), semiejes %.4f x %.4f"
          % ("L" if signo > 0 else "R", cx, cz, semi_x, semi_z))
semi = max(o[3] for o in ojos)
r_aro = semi * ARO
# EL ARO NO PUEDE PASARSE DE LA MITAD DE LA SEPARACION ENTRE OJOS, o los dos se
# CRUZAN en mitad de la cara (paso: con el radio a 1.2 semialtos, cada aro se
# metia 0.02 en el del otro y el puente quedaba enterrado).
_sep = abs(ojos[0][0] - ojos[1][0])
r_aro = min(r_aro, _sep * 0.5 - semi * TUBO * 1.6)
r_tubo = semi * TUBO
print("[gafas] cabeza r=%.4f; aro r=%.4f, montura %.4f" % (R, r_aro, r_tubo))

mat = bpy.data.materials.new("Gafas")
mat.use_nodes = True
_b = mat.node_tree.nodes["Principled BSDF"]
_b.inputs["Base Color"].default_value = (1.0, 1.0, 1.0, 1.0)
_b.inputs["Roughness"].default_value = 0.30
mat.diffuse_color = (1.0, 1.0, 1.0, 1.0)


def _cara_en(x, z):
    """Punto de la cara a esa altura, preguntando con un rayo."""
    org = Minv @ Vector((x, lo.y - alto, z))
    dirl = (Minv.to_3x3() @ Vector((0.0, 1.0, 0.0))).normalized()
    hit, loc, _n, _i = malla.ray_cast(org, dirl)
    return (M @ loc) if hit else None


def _pintar(o):
    o.data.materials.clear()
    o.data.materials.append(mat)
    bpy.ops.object.shade_smooth()


piezas = []
y_aro = None
for (cx, cz, _sx, _sz), lado in zip(ojos, ("L", "R")):
    p = _cara_en(cx, cz)
    if p is None:
        p = Vector((cx, lo.y, cz))
    y = p.y - FUERA * R
    y_aro = y if y_aro is None else min(y_aro, y)
    bpy.ops.mesh.primitive_torus_add(major_radius=r_aro, minor_radius=r_tubo,
                                     major_segments=28, minor_segments=8,
                                     location=(cx, y, cz),
                                     rotation=(math.radians(90), 0.0, 0.0))
    o = bpy.context.object
    o.name = "Aro" + lado
    # OJO CON EL EJE: el toro se crea girado 90 grados sobre X y la rotacion NO
    # se aplica, asi que su Y local es la Z del mundo — estirar "a lo alto" es
    # escalar en Y.
    o.scale = (1.0, ALTO, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    _pintar(o)
    piezas.append(o)

# EL PUENTE va de aro a aro, a la altura de los ojos y por delante de la nariz.
cxL, czL = ojos[0][0], ojos[0][1]
cxR, czR = ojos[1][0], ojos[1][1]
hueco = abs(cxL - cxR) - 2.0 * r_aro
bpy.ops.mesh.primitive_cylinder_add(radius=r_tubo, depth=max(hueco, r_tubo) + r_tubo * 2.0,
                                    vertices=10,
                                    location=((cxL + cxR) / 2.0, y_aro, (czL + czR) / 2.0 + r_aro * ALTO * 0.18),
                                    rotation=(0.0, math.radians(90), 0.0))
_p = bpy.context.object
_p.name = "Puente"
_pintar(_p)
piezas.append(_p)

def _barra(nombre, p0, p1, r):
    """Un cilindro de un punto a otro. Las patillas se ponen POR SUS EXTREMOS,
    no con angulos: puestas con una rotacion a ojo salian al aire, lejos del
    costado de la cabeza."""
    d = p1 - p0
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=d.length, vertices=8,
                                        location=(p0 + p1) / 2.0)
    o = bpy.context.object
    o.name = nombre
    o.rotation_euler = Vector((0.0, 0.0, 1.0)).rotation_difference(d.normalized()).to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    _pintar(o)
    return o


# EL COSTADO DE LA CABEZA a la altura de los ojos, sin contar las orejas: es
# donde tiene que apoyarse la patilla.
_zc = (ojos[0][1] + ojos[1][1]) / 2.0
_banda = np.abs(Vw[:, 2] - _zc) < alto_cab * 0.05
# LAS OREJAS NO CUENTAN: sobresalen hasta |x| 0.24 contra un craneo de 0.18, y
# midiendo con ellas la patilla salia disparada hacia fuera, muy por delante de
# la silueta de la cabeza.
_sin_orejas = _banda & (np.abs(Vw[:, 0]) < R * 1.12)
_lado_x = (float(np.percentile(np.abs(Vw[_sin_orejas, 0]), 92))
           if _sin_orejas.sum() > 20 else R * 0.9)
print("[gafas] costado de la cabeza a |x| %.4f" % _lado_x)
for (cx, cz, _sx, _sz), lado in zip(ojos, ("L", "R")):
    sg = 1.0 if cx > 0 else -1.0
    p0 = Vector((cx + sg * r_aro, y_aro, cz + r_aro * ALTO * 0.35))
    p1 = Vector((sg * _lado_x * 1.02, y_aro + PATILLA * R, cz + r_aro * ALTO * 0.40))
    piezas.append(_barra("Patilla" + lado, p0, p1, r_tubo * 0.80))

# UNA SOLA MALLA, y pesada al hueso de la CABEZA: las gafas van puestas, no
# cuelgan de nada.
bpy.ops.object.select_all(action="DESELECT")
for o in piezas:
    o.select_set(True)
bpy.context.view_layer.objects.active = piezas[0]
bpy.ops.object.join()
gafas = bpy.context.object
gafas.name = "Gafas"
if arm is not None:
    g = gafas.vertex_groups.new(name="Head")
    g.add([v.index for v in gafas.data.vertices], 1.0, "REPLACE")
    gafas.parent = arm
    gafas.matrix_parent_inverse = arm.matrix_world.inverted()
    m = gafas.modifiers.new("Esqueleto", "ARMATURE")
    m.object = arm

bpy.ops.object.select_all(action="DESELECT")
gafas.select_set(True)
if arm is not None:
    arm.select_set(True)
ruta = os.path.join(OUT, "chef_gafas.glb")
bpy.ops.export_scene.gltf(filepath=ruta, export_format="GLB",
                          use_selection=True, export_apply=False,
                          export_animations=False)
print("[gafas] %d caras -> %s" % (len(gafas.data.polygons), ruta))
