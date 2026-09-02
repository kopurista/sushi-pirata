# Retoque de la CARA de David dentro de Blender (numpy sobre la textura, con la
# geometría del propio modelo para saber qué téxel cae dónde). El atlas de Meshy
# está troceado, así que no hay "rectángulo de la cara": se rasteriza cada
# triángulo en UV y se deshace la interpolación baricéntrica por téxel
# (la técnica de tools/face_paint.py), y con la posición y la normal 3D de
# cada téxel se decide qué es piel, dónde están los ojos y cómo sombrear.
#   blender --background --python tools/blender/david_cara.py -- diagnostico
#   blender --background --python tools/blender/david_cara.py -- pintar
import bpy, sys, os, math
import numpy as np
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GLB = os.path.join(ROOT, "assets", "models", "david_busto.glb")
GEN = os.path.join(ROOT, "_gen")
OUT = "C:/Users/KOPURI~1/AppData/Local/Temp/claude/C--Users-KOPURISTA-Desktop-GODOT-sushi/ddc3d8d7-b243-4937-ae48-84636d59f46b/scratchpad/"
modo = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "diagnostico"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
me = obj.data
me.calc_loop_triangles()
img = [i for i in bpy.data.images if i.size[0] > 8][0]
W, H = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
print("[cara] textura", img.name, W, H, "muestra (0,0)", px[0, 0, :3])

M = obj.matrix_world
R = M.to_3x3()
V = np.array([M @ v.co for v in me.vertices], dtype=np.float32)
N = np.array([(R @ v.normal).normalized() for v in me.vertices], dtype=np.float32)
uv = me.uv_layers.active.data
zmin, zmax = V[:, 2].min(), V[:, 2].max()
alto = zmax - zmin
print("[cara] z %.3f..%.3f alto %.3f  x %.3f..%.3f y %.3f..%.3f" % (zmin, zmax, alto, V[:,0].min(), V[:,0].max(), V[:,1].min(), V[:,1].max()))

# --- rasterizado UV -> posición y normal por téxel ---------------------------
POS = np.full((H, W, 3), np.nan, dtype=np.float32)
NRM = np.zeros((H, W, 3), dtype=np.float32)
for tri in me.loop_triangles:
    li = tri.loops; vi = tri.vertices
    uvs = np.array([uv[i].uv for i in li], dtype=np.float64) * [W, H]
    x0, y0 = np.floor(uvs.min(axis=0)).astype(int); x1, y1 = np.ceil(uvs.max(axis=0)).astype(int)
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
    eps = -0.002
    ins = (l1 >= eps) & (l2 >= eps) & (l3 >= eps)
    if not ins.any():
        continue
    yy, xx = np.nonzero(ins)
    b = np.stack([l1[ins], l2[ins], l3[ins]], axis=1).astype(np.float32)
    POS[y0 + yy, x0 + xx] = b @ V[list(vi)]
    n = b @ N[list(vi)]
    NRM[y0 + yy, x0 + xx] = n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-6)
cubierto = ~np.isnan(POS[..., 0])
print("[cara] téxeles cubiertos: %.1f%%" % (100.0 * cubierto.mean()))

# --- máscaras ------------------------------------------------------------------
rgb = px[..., :3]
r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
lum = 0.299 * r + 0.587 * g + 0.114 * b
piel = cubierto & (r > g) & (g > b) & ((r - b) > 0.12) & (lum > 0.32) & (r > 0.45)
cabeza = cubierto & (POS[..., 2] > zmax - 0.26 * alto)
piel_cabeza = piel & cabeza
frente = cabeza & (NRM[..., 1] < -0.35)   # mira a -Y, que es hacia delante
oscuro = frente & (lum < 0.30) & ((rgb.max(axis=2) - rgb.min(axis=2)) < 0.14) & (POS[..., 2] > zmax - 0.16 * alto)
print("[cara] piel %.2f%%  piel cabeza %.2f%%  frente %.2f%%  oscuro-frente %d téxeles" % (
    100 * piel.mean(), 100 * piel_cabeza.mean(), 100 * frente.mean(), oscuro.sum()))
zs = POS[piel_cabeza][:, 2]
print("[cara] piel de la cabeza: z %.3f..%.3f (%.2f..%.2f del alto)" % (zs.min(), zs.max(), (zs.min()-zmin)/alto, (zs.max()-zmin)/alto))
# candidatos a ojo: téxeles oscuros de la parte alta de la frente, por lado
for lado, sel in (("izq(-x)", oscuro & (POS[..., 0] < 0)), ("der(+x)", oscuro & (POS[..., 0] > 0))):
    if sel.sum() == 0:
        print("[cara]", lado, "sin oscuros"); continue
    P = POS[sel]
    print("[cara] ojo %s: n=%d centro (%.3f, %.3f, %.3f) ancho x %.3f alto z %.3f" % (
        lado, sel.sum(), P[:,0].mean(), P[:,1].mean(), P[:,2].mean(), P[:,0].max()-P[:,0].min(), P[:,2].max()-P[:,2].min()))
# perfil de z de los oscuros para ver dónde caen cejas/ojos
hz = np.histogram(POS[oscuro][:, 2], bins=12)
for c, e in zip(hz[0], hz[1]):
    print("[cara]   z %.3f (%.2f del alto): %d" % (e, (e - zmin) / alto, c))
piel_med = np.median(rgb[piel_cabeza], axis=0)
print("[cara] color mediano de la piel", piel_med)

def guardar(nombre, arr_rgb):
    im = bpy.data.images.new(nombre, W, H, alpha=True)
    a = np.ones((H, W, 4), dtype=np.float32); a[..., :3] = arr_rgb
    im.pixels = a.ravel().tolist()
    im.filepath_raw = OUT + nombre + ".png"; im.file_format = "PNG"; im.save()
    print("[cara] ->", im.filepath_raw)

if modo == "diagnostico":
    P = POS[piel_cabeza]
    print("[cara] piel cabeza: y %.3f..%.3f  normal media" % (P[:,1].min(), P[:,1].max()), NRM[piel_cabeza].mean(axis=0))
    i = np.argmin(P[:, 1]); print("[cara] punto más a -y de la piel (¿nariz?):", P[i])
    i = np.argmax(P[:, 1]); print("[cara] punto más a +y de la piel (¿nuca?):", P[i])
    print("[cara] oscuros: normal media", NRM[oscuro].mean(axis=0), "y %.3f..%.3f" % (POS[oscuro][:,1].min(), POS[oscuro][:,1].max()))
    dbg = rgb.copy()
    dbg[piel_cabeza] = [1, 0, 1]
    dbg[oscuro] = [0, 1, 0]
    guardar("david_mascaras", dbg)

if modo == "pintar":
    # --- 1) la piel de la cabeza: sombreado limpio de cartoon en vez de los
    # brillos y costuras horneados. Se calcula por téxel con SU normal 3D, así
    # que las costuras del atlas no existen para él: dos téxeles vecinos en la
    # cara reciben el mismo color aunque vivan en islas distintas.
    BASE = np.array([0.97, 0.71, 0.56], dtype=np.float32)   # sRGB, del mediano de Meshy
    SOMBRA = np.array([0.78, 0.50, 0.40], dtype=np.float32)
    L = np.array([0.35, -0.55, 0.75], dtype=np.float32); L /= np.linalg.norm(L)
    ndl = np.clip((NRM * L).sum(axis=2), 0.0, 1.0)
    k = np.clip(0.45 + 0.55 * ndl, 0.0, 1.0)[..., None]
    piel_col = SOMBRA + (BASE - SOMBRA) * k
    nuevo = rgb.copy()
    nuevo[piel_cabeza] = piel_col[piel_cabeza]
    # LOS BORDES DE LAS ISLAS: los téxeles del canto (mezclados con el relleno
    # del atlas) no pasan el test de piel y se quedaban como rayas claras en la
    # frente y la mejilla. La piel se DILATA 3 téxeles sobre lo que no sea
    # gris (cejas, barba) ni oscuro, y los téxeles sin geometría (relleno) toman
    # la media de la piel vecina ya pintada.
    def dil(m, n):
        for _ in range(n):
            m = m | np.roll(m, 1, 0) | np.roll(m, -1, 0) | np.roll(m, 1, 1) | np.roll(m, -1, 1)
        return m
    gris = ((rgb.max(axis=2) - rgb.min(axis=2)) < 0.10) & (lum > 0.28)
    protegido = gris | (lum < 0.22)
    borde = dil(piel_cabeza, 3) & ~piel_cabeza & ~protegido & ~(cubierto & ~cabeza)
    con_geo = borde & cubierto
    nuevo[con_geo] = piel_col[con_geo]
    pintado = piel_cabeza | con_geo
    resto = borde & ~cubierto
    for _ in range(4):
        acc = np.zeros_like(nuevo); cnt = np.zeros((H, W), dtype=np.float32)
        for dy, dx in ((1,0),(-1,0),(0,1),(0,-1),(1,1),(1,-1),(-1,1),(-1,-1)):
            v = np.roll(np.roll(nuevo, dy, 0), dx, 1); m = np.roll(np.roll(pintado, dy, 0), dx, 1)
            acc += v * m[..., None]; cnt += m
        ok = resto & (cnt > 0)
        nuevo[ok] = acc[ok] / cnt[ok][:, None]
        pintado = pintado | ok; resto = resto & ~ok
    print("[cara] piel repintada: %d téxeles + %d de borde" % (piel_cabeza.sum(), (pintado & ~piel_cabeza).sum()))
    # 2) los ojos: se localizan en 3D (téxeles oscuros de la parte delantera de
    # la cara a la altura de los ojos, uno por lado) y se pintan por distancia
    # en el plano de la cara, no en el atlas.
    # MEDIDO en el render contra los ojos pintados a 0.355 (cayeron en el
    # bigote): los de verdad están 0.052 más arriba y a ±0.024 del eje.
    zo = zmax - 0.095 * alto
    # la caja de los ojos, en 3D: entre las cejas (z 0.405) y la nariz, en la
    # parte delantera y a menos de 0.07 del eje (las puntas del bigote, que son
    # oscuras, caen a 0.09 y se colaban)
    caja_ojo = cubierto & (POS[..., 2] > zo - 0.018) & (POS[..., 2] < zo + 0.022) & (POS[..., 1] < -0.03) & (NRM[..., 1] < -0.3)
    osc = caja_ojo & (lum < 0.38) & (np.abs(POS[..., 0]) > 0.02) & (np.abs(POS[..., 0]) < 0.07)
    RX, RY, RIRIS, RPUP = 0.0125, 0.0080, 0.0066, 0.0033
    SCLERA = np.array([0.95, 0.94, 0.90]); IRIS = np.array([0.36, 0.55, 0.66]); IRIS2 = np.array([0.22, 0.38, 0.50])
    PUPILA = np.array([0.07, 0.07, 0.09]); PARPADO = np.array([0.28, 0.16, 0.11]); BRILLO = np.array([1.0, 1.0, 1.0])
    # Los ojos van POR CONSTRUCCIÓN, simétricos: a 0.046 del eje y a la altura
    # medida (zo), con la profundidad sacada de la propia superficie de la
    # cara en ese punto. Detectarlos por color no valía: los de Meshy eran dos
    # motas y el bigote y las sombras pesaban más que ellos.
    OJO_X = 0.024
    for signo in (-1.0, 1.0):
        cerca = caja_ojo & (np.abs(POS[..., 0] - signo * OJO_X) < 0.012) & (np.abs(POS[..., 2] - zo) < 0.01)
        if cerca.sum() < 5:
            print("[cara] ojo", signo, "sin superficie (%d)" % cerca.sum()); continue
        C = np.array([signo * OJO_X, np.median(POS[cerca][:, 1]), zo], dtype=np.float32)
        print("[cara] ojo %+d: centro (%.3f, %.3f, %.3f), superficie de %d téxeles" % (signo, C[0], C[1], C[2], cerca.sum()))
        zona = cubierto & (np.abs(POS[..., 1] - C[1]) < 0.04) & (NRM[..., 1] < -0.15)
        dx = POS[..., 0] - C[0]; dz = POS[..., 2] - C[2]
        e = np.sqrt((dx / RX) ** 2 + (dz / RY) ** 2)
        rr = np.sqrt(dx ** 2 + dz ** 2)
        ojo = zona & (e <= 1.0)
        nuevo[ojo] = SCLERA
        iris = ojo & (rr <= RIRIS)
        # el iris se oscurece hacia el borde (dos tonos, cartoon)
        nuevo[iris] = IRIS
        nuevo[iris & (rr > RIRIS * 0.72)] = IRIS2
        nuevo[ojo & (rr <= RPUP)] = PUPILA
        # párpado: aro superior más grueso, inferior fino
        aro = zona & (e > 0.80) & (e <= 1.08) & (dz > -RY * 0.25)
        nuevo[aro] = PARPADO
        aro2 = zona & (e > 0.93) & (e <= 1.06) & (dz <= -RY * 0.25)
        nuevo[aro2] = PARPADO
        brillo = zona & (np.sqrt((dx - signo * RIRIS * 0.35) ** 2 + (dz - RIRIS * 0.4) ** 2) <= RPUP * 0.55)
        nuevo[brillo] = BRILLO
    out = px.copy(); out[..., :3] = nuevo
    img.pixels = out.ravel().tolist()
    guardar("david_retocada", nuevo)
    # renders de comprobación con la textura ya retocada
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x = 640; sc.render.resolution_y = 640
    sc.world = bpy.data.worlds.new("W"); sc.world.color = (0.16, 0.36, 0.52)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam); sc.camera = cam; cam.data.lens = 85
    cx, cy = (V[:,0].min()+V[:,0].max())/2, (V[:,1].min()+V[:,1].max())/2
    dist = alto * 0.75; zc = zmax - alto * 0.11
    for nombre, ang in (("retoque_frente", 0.0), ("retoque_3-4", 35.0)):
        a = math.radians(ang)
        cam.location = (cx + dist * math.sin(a), cy - dist * math.cos(a), zc)
        cam.rotation_euler = (math.radians(90.0), 0.0, a)
        sc.render.filepath = OUT + "david_%s.png" % nombre
        bpy.ops.render.render(write_still=True)
        print("[cara] render", sc.render.filepath)
