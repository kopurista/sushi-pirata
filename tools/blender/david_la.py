# TRATAMIENTO DE JUGUETE (estilo Link's Awakening) para un modelo de Meshy:
#   blender --background --python tools/blender/david_la.py -- <crudo.glb> <id_salida> [concepto.png]
# (el concepto da la PALETA; por defecto _gen/la_david/<id>_concepto.png)
# 1) sombreado suave (la malla de Meshy viene plana y se ven las facetas),
# 2) la textura se APLANA a una paleta de pocos colores (k-means) y se le pasa
#    un filtro de moda para matar las manchas de la proyección,
# 3) se hornea la OCLUSIÓN AMBIENTAL con Cycles y se multiplica sobre el color:
#    es el degradado "más oscuro hacia abajo y en los huecos" que llevan las
#    figuritas del remake, horneado en su textura (visto en el visor),
# 4) material de vinilo (rugosidad baja) y exportación a assets/models/<id>.glb.
import bpy, sys, os, math
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
CRUDO = os.path.abspath(args[0]); ID = args[1]
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = "C:/Users/KOPURI~1/AppData/Local/Temp/claude/C--Users-KOPURISTA-Desktop-GODOT-sushi/ddc3d8d7-b243-4937-ae48-84636d59f46b/scratchpad/"
GEN = os.path.join(ROOT, "_gen", "la_david")
K = 13            # colores de la paleta (3 neutros + 10 saturados)
TEX = 1024        # tamaño de la textura final
AO_FUERZA = float(os.environ.get("AO", 0.55))  # cuánto oscurece la oclusión (0 = nada, 1 = entera)
RUGOSIDAD = 0.32

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=CRUDO)
obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
bpy.context.view_layer.objects.active = obj; obj.select_set(True)
me = obj.data
print("[toy] tris", sum(len(p.vertices) - 2 for p in me.polygons), "verts", len(me.vertices))

# --- 1) suave -----------------------------------------------------------------
# Meshy exporta sus propias normales y el importador las mete como NORMALES
# PERSONALIZADAS, que mandan sobre el "suave" de las caras: se borran y se
# suaviza de verdad (con las facetas, el sombreado salía a parches).
try:
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.customdata_custom_splitnormals_clear()
    # Y SE SUELDAN LOS VÉRTICES DUPLICADOS: Meshy parte la malla en cada
    # costura del atlas (12.449 vértices para 16.313 triángulos, cuando una
    # superficie cerrada tendría ~8.200), así que cada isla calculaba sus
    # normales sola y el sombreado salía a PARCHES con los bordes de las
    # islas. Las UV van por esquina de cara y sobreviven a la soldadura.
    antes = len(me.vertices)
    bpy.ops.mesh.remove_doubles(threshold=0.0002)
    bpy.ops.object.mode_set(mode="OBJECT")
    print("[toy] vértices soldados: %d -> %d" % (antes, len(me.vertices)))
except Exception as e:
    print("[toy] limpiar normales:", e)
for p in me.polygons: p.use_smooth = True
print("[toy] normales personalizadas:", me.has_custom_normals)

# --- 2) paleta ------------------------------------------------------------------
mat = obj.material_slots[0].material
tex_node = [n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE"][0]
img = tex_node.image
W, H = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
rgb = px[..., :3]
# LA PALETA SALE DEL CONCEPTO DE LUDO, no de la textura de Meshy: el concepto
# trae los colores limpios que se pidieron, y Meshy hornea encima su propio
# sombreado (y hasta las facetas), así que agrupando la textura salían la piel
# y la barba partidas en dos tonos y las botas negras hechas un mosaico. Cada
# téxel se asigna al color del concepto más cercano por CROMA (color dividido
# por su brillo) con el brillo pesando poco, y lo casi negro va directo al
# color más oscuro de la paleta.
CONCEPTO = os.path.abspath(args[2]) if len(args) > 2 else os.path.join(GEN, ID + "_concepto.png")
cimg = bpy.data.images.load(CONCEPTO)
cw, ch = cimg.size
cp = np.array(cimg.pixels[:], dtype=np.float32).reshape(ch, cw, 4)
cpx = cp[cp[..., 3] > 0.9][:, :3]
# Los NEUTROS (blanco, gris, negro) se separan por brillo en tres cubos fijos y
# los colores SATURADOS se agrupan solo por croma, sin brillo: así el sombreado
# horneado (del concepto y de Meshy) no parte la piel en tres rosas, y el blanco
# de la camisa no se confunde con el gris de la barba.
NEUTROS = np.array([[0.05, 0.05, 0.055], [0.62, 0.61, 0.60], [0.94, 0.93, 0.91]], dtype=np.float32)
def croma(c):
    return c / (c.max(axis=1, keepdims=True) + 1e-4)
def satur(c):
    return 1.0 - c.min(axis=1) / (c.max(axis=1) + 1e-4)
def lum(c):
    return c.max(axis=1)
def bin_neutro(c):
    l = lum(c); return np.where(l < 0.22, 0, np.where(l < 0.78, 1, 2))
SAT_MIN = 0.10   # el beige del pantalón anda por 0.17 y con 0.16 la mitad de sus téxeles caían al blanco
rng = np.random.default_rng(1)
sat_px = cpx[(satur(cpx) >= SAT_MIN) & (lum(cpx) >= 0.16)]
muestra = sat_px[rng.choice(len(sat_px), min(60000, len(sat_px)), replace=False)]
fm = croma(muestra)
KS = 14
# semillas k-means++ (cada nueva lejos de las anteriores): con semillas al azar
# los colores de POCA ÁREA, como el beige del pantalón, no salían nunca
cent = fm[rng.choice(len(fm), 1)].copy()
while len(cent) < KS:
    d = ((fm[:, None, :] - cent[None, :, :]) ** 2).sum(axis=2).min(axis=1)
    cent = np.vstack([cent, fm[rng.choice(len(fm), 1, p=d / d.sum())]])
for _ in range(30):
    d = ((fm[:, None, :] - cent[None, :, :]) ** 2).sum(axis=2)
    lab = d.argmin(axis=1)
    for k in range(KS):
        sel = fm[lab == k]
        if len(sel): cent[k] = sel.mean(axis=0)
# FUSIÓN POR TONO: dos grupos con el mismo matiz (a menos de 15°) y parecida
# saturación son el mismo material a dos luces (la piel a la luz y a la sombra,
# el azul del abrigo y su brillo); el beige del pantalón y el oro del galón
# comparten matiz pero no saturación, y se quedan aparte.
def tono_sat(c):
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    mx = c.max(axis=-1); mn = c.min(axis=-1); d = mx - mn + 1e-6
    h = np.where(mx == r, (g - b) / d % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60.0
    return h, 1.0 - mn / (mx + 1e-6)
hh, ss = tono_sat(cent)
vivos = list(range(KS))
for i in range(KS):
    for j in range(i):
        if j in vivos and i in vivos:
            dh = abs((hh[i] - hh[j] + 180) % 360 - 180)
            if dh < 15 and abs(ss[i] - ss[j]) < 0.30:
                vivos.remove(i); break
cent = cent[vivos]; KS = len(cent)
# color plano de cada grupo saturado: mediana del cuarto más claro del concepto
d = ((fm[:, None, :] - cent[None, :, :]) ** 2).sum(axis=2); lab = d.argmin(axis=1)
colores = np.zeros((KS, 3), dtype=np.float32)
for k in range(KS):
    sel = muestra[lab == k]
    if len(sel) == 0: continue
    l = lum(sel); colores[k] = np.median(sel[l >= np.quantile(l, 0.75)], axis=0)
paleta = np.concatenate([NEUTROS, colores], axis=0); K = len(paleta); oscuro = 0
def asignar(tr):
    out = bin_neutro(tr)
    sat = satur(tr) >= SAT_MIN
    if sat.any():
        d = ((croma(tr[sat])[:, None, :] - cent[None, :, :]) ** 2).sum(axis=2)
        out[sat] = 3 + d.argmin(axis=1)
    out[lum(tr) < 0.16] = 0
    return out
flat = rgb.reshape(-1, 3)
labels = np.empty(len(flat), dtype=np.int32)
for i in range(0, len(flat), 400000):
    labels[i:i+400000] = asignar(flat[i:i+400000])
labels = labels.reshape(H, W)
cent = paleta
print("[toy] paleta del concepto (%d):" % K, [tuple(int(c * 255) for c in col) for col in cent])
# filtro de moda 5x5: cada téxel toma la etiqueta más repetida a su alrededor
def moda(lab, r=2):
    votos = np.zeros((K, H, W), dtype=np.int16)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            v = np.roll(np.roll(lab, dy, 0), dx, 1)
            for k in range(K):
                votos[k] += (v == k)
    return votos.argmax(axis=0)
labels = moda(labels)
plano = cent[labels]                         # H x W x 3, color plano
# OJOS POR CONSTRUCCIÓN (el usuario los quiere MÁS REDONDOS que los del
# concepto): se localizan por los téxeles negros de la parte alta y delantera
# de la cabeza, uno por lado, y se repintan como óvalos limpios de proporción
# OJO_PROP (alto/ancho); los de Meshy salían moteados por el filtro.
OJO_PROP = 0.0   # 0 = la proporción la da la geometría
from mathutils import Vector
me.calc_loop_triangles(); uvl = me.uv_layers.active.data
MW = obj.matrix_world
V = np.array([MW @ v.co for v in me.vertices], dtype=np.float32)
Nn = np.array([(MW.to_3x3() @ v.normal).normalized() for v in me.vertices], dtype=np.float32)
POS = np.full((H, W, 3), np.nan, dtype=np.float32); NRM = np.zeros((H, W, 3), dtype=np.float32)
for tri in me.loop_triangles:
    uvs = np.array([uvl[i].uv for i in tri.loops], dtype=np.float64) * [W, H]
    x0, y0 = np.floor(uvs.min(axis=0)).astype(int); x1, y1 = np.ceil(uvs.max(axis=0)).astype(int)
    x0 = max(x0, 0); y0 = max(y0, 0); x1 = min(x1, W - 1); y1 = min(y1, H - 1)
    if x1 < x0 or y1 < y0: continue
    xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
    (ax, ay), (bx, by), (cx_, cy_) = uvs
    det = (bx - ax) * (cy_ - ay) - (cx_ - ax) * (by - ay)
    if abs(det) < 1e-9: continue
    l1 = ((bx - xs) * (cy_ - ys) - (cx_ - xs) * (by - ys)) / det
    l2 = ((cx_ - xs) * (ay - ys) - (ax - xs) * (cy_ - ys)) / det
    l3 = 1.0 - l1 - l2
    ins = (l1 >= -0.002) & (l2 >= -0.002) & (l3 >= -0.002)
    if not ins.any(): continue
    yy, xx = np.nonzero(ins)
    b = np.stack([l1[ins], l2[ins], l3[ins]], axis=1).astype(np.float32)
    POS[y0 + yy, x0 + xx] = b @ V[list(tri.vertices)]
    n = b @ Nn[list(tri.vertices)]; NRM[y0 + yy, x0 + xx] = n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-6)
cub = ~np.isnan(POS[..., 0])
zt = np.nanmax(POS[..., 2]); zb = np.nanmin(POS[..., 2]); alto_m = zt - zb
# LOS OJOS VAN POR CONSTRUCCIÓN DESDE EL CONCEPTO: a Meshy se le manda el
# concepto SIN OJOS (una cara lisa, que es lo que tiene el remake), y aquí se
# pintan donde estaban en el dibujo, en fracciones del cuerpo medidas sobre
# él (<id>_ojos.json: separación y ancho como fracción del ancho de la
# cabeza a la altura de los ojos; altura y alto como fracción del alto
# total). Tallados por Meshy salían cuencas con reborde que cogían luz.
import json
mj = os.path.join(GEN, ID_CONCEPTO + "_ojos.json") if "ID_CONCEPTO" in globals() else os.path.splitext(CONCEPTO)[0].replace("_concepto", "_ojos") + ".json"
met = json.load(open(mj))
zo = zt - met["z_frac"] * alto_m
fila = cub & (np.abs(POS[..., 2] - zo) < 0.01)
ancho_fila = np.nanmax(POS[fila][:, 0]) - np.nanmin(POS[fila][:, 0])
sep = met["sep_frac"] * ancho_fila; rx = met["rx_frac"] * ancho_fila; ry = met["ry_frac"] * alto_m
print("[toy] ojos: z %.3f sep %.3f rx %.3f ry %.3f (ancho de cabeza %.3f)" % (zo, sep, rx, ry, ancho_fila))
for signo in (-1.0, 1.0):
    cerca = cub & (NRM[..., 1] < -0.3) & (np.abs(POS[..., 0] - signo * sep) < rx) & (np.abs(POS[..., 2] - zo) < ry)
    if cerca.sum() < 5:
        print("[toy] ojo", signo, "sin superficie"); continue
    C = np.array([signo * sep, np.median(POS[cerca][:, 1]), zo], dtype=np.float32)
    zona = cub & (np.abs(POS[..., 1] - C[1]) < 0.06) & (NRM[..., 1] < -0.1)
    e = np.sqrt(((POS[..., 0] - C[0]) / rx) ** 2 + ((POS[..., 2] - C[2]) / ry) ** 2)
    # el óvalo se DILATA dos téxeles: entre triángulos vecinos del atlas queda
    # un téxel sin cubrir y salían rayitas de piel cruzando el negro del ojo
    m = zona & (e <= 1.0)
    for _ in range(2):
        m = m | np.roll(m, 1, 0) | np.roll(m, -1, 0) | np.roll(m, 1, 1) | np.roll(m, -1, 1)
    plano[m] = [0.02, 0.02, 0.03]

# --- 3) oclusión horneada -------------------------------------------------------
ao_img = bpy.data.images.new("AO", TEX, TEX)
nodes = mat.node_tree.nodes
ao_node = nodes.new("ShaderNodeTexImage"); ao_node.image = ao_img
nodes.active = ao_node
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 48
sc.render.bake.use_selected_to_active = False
sc.render.bake.margin = 8
sc.world = bpy.data.worlds.new("W"); sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
bpy.ops.object.bake(type="AO")
ao = np.array(ao_img.pixels[:], dtype=np.float32).reshape(TEX, TEX, 4)[..., 0]
print("[toy] AO media %.3f min %.3f" % (ao.mean(), ao.min()))

# --- 4) composición y textura final --------------------------------------------
# el color plano se reduce a TEX y se multiplica por la oclusión suavizada
def reducir(a, n):
    f = a.shape[0] // n
    return a.reshape(n, f, n, f, -1).mean(axis=(1, 3))
color = reducir(plano.astype(np.float32), TEX)
ao_s = np.clip(ao, 0, 1) ** 0.8
ao_s = 1.0 - AO_FUERZA * (1.0 - ao_s)
final = np.clip(color * ao_s[..., None], 0, 1)
out_img = bpy.data.images.new("toy", TEX, TEX, alpha=False)
a = np.ones((TEX, TEX, 4), dtype=np.float32); a[..., :3] = final
out_img.pixels = a.ravel().tolist()
out_img.filepath_raw = os.path.join(GEN, ID + "_tex.png"); out_img.file_format = "PNG"; out_img.save()
tex_node.image = out_img
nodes.remove(ao_node)
bsdf = [n for n in nodes if n.type == "BSDF_PRINCIPLED"][0]
bsdf.inputs["Roughness"].default_value = RUGOSIDAD
bsdf.inputs["Metallic"].default_value = 0.0

# --- renders de comprobación (Workbench con especular) --------------------------
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
sc.display.shading.show_specular_highlight = True
sc.render.resolution_x = 640; sc.render.resolution_y = 800
sc.world.use_nodes = False; sc.world.color = (0.16, 0.36, 0.52)
lo = np.array([min(v.co[i] for v in me.vertices) for i in range(3)]); hi = np.array([max(v.co[i] for v in me.vertices) for i in range(3)])
M = obj.matrix_world
from mathutils import Vector
pts = [M @ Vector(v.co) for v in me.vertices]
lo = np.array([min(p[i] for p in pts) for i in range(3)]); hi = np.array([max(p[i] for p in pts) for i in range(3)])
c = (lo + hi) / 2; alto = hi[2] - lo[2]
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 60; dist = alto * 2.3
for nombre, ang in (("frente", 0.0), ("3-4", 35.0), ("perfil", 90.0)):
    an = math.radians(ang)
    cam.location = (c[0] + dist * math.sin(an), c[1] - dist * math.cos(an), c[2] + alto * 0.05)
    cam.rotation_euler = (math.radians(88.0), 0.0, an)
    sc.render.filepath = OUT + "%s_%s.png" % (os.environ.get("PREF", ID), nombre)
    bpy.ops.render.render(write_still=True)
bpy.data.objects.remove(cam)

# --- exportación ----------------------------------------------------------------
dest = os.path.join(ROOT, "assets", "models", ID + ".glb")
bpy.ops.export_scene.gltf(filepath=dest, export_format="GLB", export_apply=True,
                          export_image_format="JPEG", export_jpeg_quality=90)
print("[toy] exportado", dest)
