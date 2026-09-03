# PINTA A GIGI POR REGIONES, tirando a la basura la textura de Meshy.
#   blender --background --python tools/blender/pintar_ave.py -- <modelo.glb> <salida.glb>
#
# La textura que devuelve Meshy trae manchas grandes en todo lo que el concepto
# no enseñaba (el otro lado del pico, la espalda, las patas) y NO hay filtro que
# las quite: se probaron medianas de radio 14, un quitamanchas por contraste
# local y la cuantizacion a la paleta del concepto, y el pico seguia picado. La
# MALLA, en cambio, esta limpia: con un material liso el loro sale impecable
# (comprobado en render), asi que el problema es solo la pintura.
#
# Aqui la textura se pinta ENTERA desde la geometria: cada texel se colorea por
# donde cae en el cuerpo del ave (corona, cara, pico, pecho, alas, cola, patas)
# y se sombrea con su normal y con la oclusion horneada, que es lo que da el
# degradado de juguete. Colores planos y cero manchas por construccion.
import bpy, sys, os, math
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
GLB = os.path.abspath(args[0])
DEST = os.path.abspath(args[1])
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = "C:/Users/KOPURI~1/AppData/Local/Temp/claude/C--Users-KOPURISTA-Desktop-GODOT-sushi/ddc3d8d7-b243-4937-ae48-84636d59f46b/scratchpad/"
TEX = 1024
AO_FUERZA = float(os.environ.get("AO", 0.45))

# Paleta del concepto.
ROJO = np.array([0.86, 0.20, 0.16], dtype=np.float32)
NARANJA = np.array([0.94, 0.50, 0.16], dtype=np.float32)
AMARILLO = np.array([0.95, 0.80, 0.22], dtype=np.float32)
VERDE = np.array([0.44, 0.72, 0.24], dtype=np.float32)
VERDE_OSC = np.array([0.13, 0.45, 0.18], dtype=np.float32)
GRIS = np.array([0.30, 0.30, 0.32], dtype=np.float32)
BLANCO = np.array([0.96, 0.96, 0.94], dtype=np.float32)
NEGRO = np.array([0.06, 0.06, 0.07], dtype=np.float32)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
me = obj.data
bpy.context.view_layer.objects.active = obj
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.customdata_custom_splitnormals_clear()
bpy.ops.mesh.remove_doubles(threshold=0.0002)
bpy.ops.mesh.vertices_smooth(factor=0.5, repeat=3)
bpy.ops.object.mode_set(mode="OBJECT")
for p in me.polygons:
    p.use_smooth = True

M = obj.matrix_world
V = np.array([M @ v.co for v in me.vertices], dtype=np.float32)
N = np.array([(M.to_3x3() @ v.normal).normalized() for v in me.vertices], dtype=np.float32)
lo, hi = V.min(axis=0), V.max(axis=0)
alto = hi[2] - lo[2]
fondo = hi[1] - lo[1]
ancho = hi[0] - lo[0]
print("[pintar] %d verts | alto %.3f fondo %.3f ancho %.3f" % (len(V), alto, fondo, ancho))

# --- rasterizado UV -> posicion y normal por texel ----------------------------
me.calc_loop_triangles()
uv = me.uv_layers.active.data
H = W = TEX
POS = np.full((H, W, 3), np.nan, dtype=np.float32)
NRM = np.zeros((H, W, 3), dtype=np.float32)
for tri in me.loop_triangles:
    uvs = np.array([uv[i].uv for i in tri.loops], dtype=np.float64) * [W, H]
    x0, y0 = np.floor(uvs.min(axis=0)).astype(int)
    x1, y1 = np.ceil(uvs.max(axis=0)).astype(int)
    x0 = max(x0, 0); y0 = max(y0, 0); x1 = min(x1, W - 1); y1 = min(y1, H - 1)
    if x1 < x0 or y1 < y0:
        continue
    xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
    (ax, ay), (bx, by), (cx, cy) = uvs
    det = (bx - ax) * (cy - ay) - (cx - ax) * (by - ay)
    if abs(det) < 1e-9:
        continue
    l1 = ((bx - xs) * (cy - ys) - (cx - xs) * (by - ys)) / det
    l2 = ((cx - xs) * (ay - ys) - (ax - xs) * (cy - ys)) / det
    l3 = 1.0 - l1 - l2
    ins = (l1 >= -0.003) & (l2 >= -0.003) & (l3 >= -0.003)
    if not ins.any():
        continue
    yy, xx = np.nonzero(ins)
    b = np.stack([l1[ins], l2[ins], l3[ins]], axis=1).astype(np.float32)
    POS[y0 + yy, x0 + xx] = b @ V[list(tri.vertices)]
    n = b @ N[list(tri.vertices)]
    NRM[y0 + yy, x0 + xx] = n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-6)
cub = ~np.isnan(POS[..., 0])
print("[pintar] texeles cubiertos: %.1f%%" % (100.0 * cub.mean()))

X = np.nan_to_num(POS[..., 0])
Y = np.nan_to_num(POS[..., 1])
Z = np.nan_to_num(POS[..., 2])
fz = (Z - lo[2]) / alto            # 0 abajo, 1 arriba
fy = (Y - lo[1]) / fondo           # 0 delante (el pico), 1 detras (la cola)
fx = np.abs(X) / (ancho * 0.5)     # 0 en el eje, 1 en el canto


def suave(t, a, b):
    u = np.clip((t - a) / (b - a + 1e-9), 0.0, 1.0)
    return u * u * (3.0 - 2.0 * u)


# --- las regiones, con las medidas tomadas DEL PROPIO MODELO -------------------
# (una pasada de diagnostico dio: el pico sobresale hasta fy 0.00 entre fz 0.55
# y 0.80, y por encima de fz 0.92 ya no hay pico; los ojos estan en fx 0.60,
# fy 0.30, fz 0.74, con radio 0.085 del alto y la pupila a 0.69 de fx.)
#
# Se probo antes clasificar la textura de Meshy a esta misma paleta y NO vale:
# en las zonas que el concepto no enseñaba su pintura es basura, asi que las
# motas verdes del pico y las patas volvian una y otra vez, y al barrerlas con
# una moda de radio grande se comian los ojos. Aqui la textura no se mira.
col = np.zeros((H, W, 3), dtype=np.float32)
col[:] = VERDE
amar = suave(fz, 0.30, 0.42) * (1.0 - suave(fy, 0.40, 0.68))
col = col * (1 - amar[..., None]) + AMARILLO * amar[..., None]
roja = suave(fz, 0.76, 0.86)
col = col * (1 - roja[..., None]) + ROJO * roja[..., None]
pico = suave(fz, 0.52, 0.60) * (1.0 - suave(fz, 0.80, 0.88)) * (1.0 - suave(fy, 0.13, 0.23))
col = col * (1 - pico[..., None]) + NARANJA * pico[..., None]
ala = suave(fx, 0.62, 0.80) * suave(fz, 0.12, 0.26) * (1.0 - suave(fz, 0.55, 0.68))
col = col * (1 - ala[..., None]) + VERDE_OSC * ala[..., None]
cola = suave(fy, 0.78, 0.90) * (1.0 - suave(fz, 0.30, 0.45))
col = col * (1 - cola[..., None]) + VERDE_OSC * cola[..., None]
pat = 1.0 - suave(fz, 0.05, 0.11)
col = col * (1 - pat[..., None]) + GRIS * pat[..., None]

# --- ojos, en el sitio MEDIDO -------------------------------------------------
R_OJO = 0.088 * alto
R_PUP = 0.052 * alto
for sgn in (1.0, -1.0):
    cen = np.array([sgn * 0.605 * (ancho * 0.5),
                    lo[1] + 0.30 * fondo,
                    lo[2] + 0.745 * alto], dtype=np.float32)
    cen_p = np.array([sgn * 0.72 * (ancho * 0.5),
                      lo[1] + 0.28 * fondo,
                      lo[2] + 0.748 * alto], dtype=np.float32)
    d3 = np.sqrt((X - cen[0]) ** 2 + (Y - cen[1]) ** 2 + (Z - cen[2]) ** 2)
    dp = np.sqrt((X - cen_p[0]) ** 2 + (Y - cen_p[1]) ** 2 + (Z - cen_p[2]) ** 2)
    lado = cub & (np.sign(X) == sgn)
    ojo = lado & (d3 <= R_OJO)
    col[ojo] = BLANCO
    pup = lado & (dp <= R_PUP)
    col[pup] = NEGRO
    print("[pintar] ojo %+d: %d blanco, %d pupila" % (sgn, int(ojo.sum()), int(pup.sum())))

# --- sombreado de juguete -----------------------------------------------------
L = np.array([0.30, -0.62, 0.72], dtype=np.float32)
L /= np.linalg.norm(L)
ndl = np.clip((NRM * L).sum(axis=2), 0.0, 1.0)
col *= (0.72 + 0.28 * ndl)[..., None]

ao_img = bpy.data.images.new("AO", TEX, TEX)
mat = obj.material_slots[0].material
nodes = mat.node_tree.nodes
ao_node = nodes.new("ShaderNodeTexImage")
ao_node.image = ao_img
nodes.active = ao_node
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 48
sc.render.bake.margin = 24
sc.world = bpy.data.worlds.new("W")
sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
sc.world.light_settings.distance = alto * 0.5
bpy.ops.object.bake(type="AO")
ao = np.array(ao_img.pixels[:], dtype=np.float32).reshape(TEX, TEX, 4)[..., 0]
m_ao = (ao > 0.002).astype(np.float32)
for _ in range(24):
    acc = np.zeros_like(ao)
    cnt = np.zeros_like(ao)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        acc += np.roll(np.roll(ao, dy, 0), dx, 1) * np.roll(np.roll(m_ao, dy, 0), dx, 1)
        cnt += np.roll(np.roll(m_ao, dy, 0), dx, 1)
    nuevo = (m_ao < 0.5) & (cnt > 0)
    ao = np.where(nuevo, acc / np.maximum(cnt, 1e-4), ao)
    m_ao = np.maximum(m_ao, nuevo.astype(np.float32))
ao_s = 1.0 - AO_FUERZA * (1.0 - np.clip(ao, 0, 1) ** 0.8)
col = np.clip(col * ao_s[..., None], 0, 1)

out_img = bpy.data.images.new("gigi", TEX, TEX, alpha=False)
a = np.ones((TEX, TEX, 4), dtype=np.float32)
a[..., :3] = col
out_img.pixels = a.ravel().tolist()
gen = os.path.join(ROOT, "_gen", "la_gigi")
os.makedirs(gen, exist_ok=True)
out_img.filepath_raw = os.path.join(gen, "gigi_pintada.png")
out_img.file_format = "PNG"
out_img.save()
tex_node = [n for n in nodes if n.type == "TEX_IMAGE" and n is not ao_node][0]
tex_node.image = out_img
nodes.remove(ao_node)
bsdf = [n for n in nodes if n.type == "BSDF_PRINCIPLED"][0]
bsdf.inputs["Roughness"].default_value = 0.32
bsdf.inputs["Metallic"].default_value = 0.0

sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "TEXTURE"
sc.display.shading.show_specular_highlight = True
sc.render.resolution_x = 600
sc.render.resolution_y = 700
sc.world.use_nodes = False
sc.world.color = (0.16, 0.36, 0.52)
c = (lo + hi) / 2
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.lens = 62
for nombre, ang in (("frente", 0.0), ("3-4", 30.0), ("perfil", 88.0)):
    a_ = math.radians(ang)
    d = alto * 2.2
    cam.location = (c[0] + d * math.sin(a_), c[1] - d * math.cos(a_), c[2])
    cam.rotation_euler = (math.radians(88.0), 0.0, a_)
    sc.render.filepath = OUT + "gpin_%s.png" % nombre
    bpy.ops.render.render(write_still=True)
bpy.data.objects.remove(cam)
bpy.ops.export_scene.gltf(filepath=DEST, export_format="GLB", export_apply=True,
                          export_image_format="JPEG", export_jpeg_quality=90)
print("[pintar] exportado", DEST)
