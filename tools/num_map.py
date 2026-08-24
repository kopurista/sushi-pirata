"""LOS NUMEROS DEL MAPA, horneados con su material y su relieve.

Cada escenario lleva su numero dentro del decorado: escrito en la arena de la
isla, en el cartel del puerto, en la vela del abordaje y esculpido en la roca de
la cueva. Aqui se dibuja UNA imagen por escenario con la trama de su material
recortada por la silueta del numero y con el relieve horneado (luz por el canto
de arriba y sombra por el de abajo), y el juego la pega en un plano.

POR QUE HORNEADO Y NO `TextMesh`: se intento primero con geometria extruida y
Godot no puede con esta fuente — "Convex decomposing failed. Make sure the font
doesn't contain self-intersecting lines" con la Exo 2 tanto en Bold como en
Regular, asi que el numero salia sin malla. Y con `Label3D` el numero es texto
plano pegado encima, que es justo lo que se queria evitar.

Se generan los 20 del mar 1 leyendo los tipos de `campaign_data.gd`, asi que
cambiar un escenario de tipo y volver a pasar esto basta.
"""
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAIZ = Path(".")
OUT = RAIZ / "assets/map"
FUENTE = RAIZ / "fonts/static/Exo2-Bold.ttf"

## Alto de la caja del numero en pixeles de textura. Se dibuja a SS veces esto
## y se reduce al final: el canto del relieve tiene que bajar limpio.
ALTO = 128
SS = 4
## Aire alrededor del numero, para que el desenfoque del relieve quepa dentro.
AIRE = 10

## Trama y tinte de cada tipo. El tinte multiplica la trama: por debajo de 1 el
## numero queda mas oscuro que la superficie (talla), por encima mas claro.
## El TINTE va lejos del color de la superficie a proposito: el numero se pinta
## SIN SOMBREAR (el relieve ya viene horneado), asi que lo unico que lo separa
## del fondo es su propio tono. Con tintes cercanos al de la arena o al de la
## madera el numero casi no se veia sobre el modelo.
ESTILOS = {
    # La ISLA va CLARA como el puerto: el numero vive en la TABLA de madera
    # del cartel, y los tonos de arena sobre madera calida no se distinguian
    # (le paso al usuario). La trama de arena se queda: da su grano propio.
    "isla": ("assets/props/arena_num.webp", (1.06, 0.98, 0.82), 0.62),
    # El PUERTO va CLARO sobre la tabla oscura: al reves (numero oscuro sobre
    # madera clara) no se distinguia del carte a tamano de mapa.
    "puerto": ("assets/props/lona_num.webp", (1.0, 0.96, 0.86), 0.55),
    "abordaje": ("assets/props/lona_num.webp", (0.97, 0.94, 0.86), 0.60),
    "cueva": ("assets/props/piedra_cueva.webp", (0.80, 0.79, 0.77), 0.70),
}


def kinds() -> dict:
    txt = (RAIZ / "scripts/campaign_data.gd").read_text(encoding="utf-8")
    bloque = txt[txt.index("const KINDS: Dictionary = {"):]
    bloque = bloque[:bloque.index("\n}")]
    return dict(re.findall(r'"([a-z_0-9]+)":\s*"([a-z]+)"', bloque))


def orden() -> list:
    txt = (RAIZ / "scripts/campaign_data.gd").read_text(encoding="utf-8")
    bloque = txt[txt.index("const MAP_POS: Dictionary = {"):]
    bloque = bloque[:bloque.index("\n}")]
    return re.findall(r'"([a-z_0-9]+)":\s*Vector2', bloque)


def _mascara(texto: str) -> Image.Image:
    """Silueta del numero, a supermuestreo y con su aire alrededor."""
    fnt = ImageFont.truetype(str(FUENTE), int(ALTO * SS * 0.82))
    tmp = Image.new("L", (10, 10))
    bb = ImageDraw.Draw(tmp).textbbox((0, 0), texto, font=fnt)
    w = bb[2] - bb[0] + AIRE * 2 * SS
    h = ALTO * SS
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    d.text((AIRE * SS - bb[0], (h - (bb[3] + bb[1])) // 2), texto,
           font=fnt, fill=255)
    return im


def _trama(ruta: str, size) -> Image.Image:
    t = Image.open(RAIZ / ruta).convert("RGB")
    out = Image.new("RGB", size)
    for y in range(0, size[1], t.height):
        for x in range(0, size[0], t.width):
            out.paste(t, (x, y))
    return out


def numero(n: int, kind: str) -> None:
    ruta, tinte, relieve = ESTILOS[kind]
    m = _mascara(str(n))
    W, H = m.size
    base = _trama(ruta, (W, H))
    px = base.load()
    for y in range(H):
        for x in range(W):
            r, g, b = px[x, y]
            px[x, y] = (int(r * tinte[0]), int(g * tinte[1]), int(b * tinte[2]))

    # RELIEVE: la diferencia entre la silueta desplazada hacia la luz y hacia
    # la sombra da el canto. El sol del mapa viene de arriba a la izquierda.
    d = int(3.5 * SS)
    suave = m.filter(ImageFilter.GaussianBlur(1.6 * SS))
    luz = Image.new("L", (W, H), 0)
    luz.paste(suave, (-d, -d))
    som = Image.new("L", (W, H), 0)
    som.paste(suave, (d, d))
    pl, ps, pm = luz.load(), som.load(), m.load()
    for y in range(H):
        for x in range(W):
            if pm[x, y] < 8:
                continue
            k = 1.0 + (pl[x, y] - ps[x, y]) / 255.0 * relieve
            r, g, b = px[x, y]
            px[x, y] = (min(255, int(r * k)), min(255, int(g * k)),
                        min(255, int(b * k)))

    out = base.convert("RGBA")
    out.putalpha(m)
    out = out.resize((W // SS, H // SS), Image.LANCZOS)
    OUT.mkdir(parents=True, exist_ok=True)
    out.save(OUT / ("num_%d.png" % n))
    print("num_%d.png (%s) %dx%d" % (n, kind, out.width, out.height))


## LAS ESTRELLAS DEL CARTEL. Van debajo del numero, en la misma tabla: con la
## hilera 2D flotando sobre el nodo se confundian con las del escenario de al
## lado, que es justo lo que pidio arreglar el usuario.
ESTRELLA_LADO = 96
ESTRELLA_HUECO = 14
## La estrella GANADA es pintura dorada con cuerpo (lona tenida de oro) y la
## que falta una TALLA hundida en la madera oscura: el mismo lenguaje de
## relieve que el numero, que es lo que las hace de cartel y no una hilera de
## interfaz pegada encima (rediseno pedido por el usuario).
ORO = ("assets/props/lona_num.webp", (1.12, 0.90, 0.34), 0.55)
TALLA = ("assets/props/madera_cartel.webp", (0.40, 0.28, 0.15), 0.85)


def _estrella_mascara(lado: int) -> Image.Image:
    """Silueta de estrella de cinco puntas, supermuestreada."""
    import math
    L = lado * SS
    im = Image.new("L", (L, L), 0)
    cx = cy = L / 2.0
    r1 = L * 0.485
    r2 = r1 * 0.46
    pts = []
    for i in range(10):
        ang = -math.pi / 2.0 + i * math.pi / 5.0
        r = r1 if i % 2 == 0 else r2
        pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
    ImageDraw.Draw(im).polygon(pts, fill=255)
    return im


def _pieza(m: Image.Image, estilo) -> Image.Image:
    """Trama tenida + relieve horneado, recortada por la mascara `m`."""
    ruta, tinte, relieve = estilo
    W, H = m.size
    base = _trama(ruta, (W, H))
    px = base.load()
    for y in range(H):
        for x in range(W):
            r, g, b = px[x, y]
            px[x, y] = (min(255, int(r * tinte[0])), min(255, int(g * tinte[1])),
                        min(255, int(b * tinte[2])))
    d = int(3.5 * SS)
    suave = m.filter(ImageFilter.GaussianBlur(1.6 * SS))
    luz = Image.new("L", (W, H), 0)
    luz.paste(suave, (-d, -d))
    som = Image.new("L", (W, H), 0)
    som.paste(suave, (d, d))
    pl, ps, pm = luz.load(), som.load(), m.load()
    for y in range(H):
        for x in range(W):
            if pm[x, y] < 8:
                continue
            k = 1.0 + (pl[x, y] - ps[x, y]) / 255.0 * relieve
            r, g, b = px[x, y]
            px[x, y] = (min(255, int(r * k)), min(255, int(g * k)),
                        min(255, int(b * k)))
    out = base.convert("RGBA")
    out.putalpha(m)
    return out


def estrellas() -> None:
    lado = ESTRELLA_LADO
    m = _estrella_mascara(lado)
    llena = _pieza(m, ORO).resize((lado, lado), Image.LANCZOS)
    # La TALLA hundida lleva el relieve AL REVES (sombra arriba, luz abajo):
    # se hornea con la mascara volteada y se devuelve al derecho.
    from PIL import ImageOps
    mv = ImageOps.flip(ImageOps.mirror(m))
    vacia = ImageOps.flip(ImageOps.mirror(_pieza(mv, TALLA))) \
        .resize((lado, lado), Image.LANCZOS)
    W = lado * 3 + ESTRELLA_HUECO * 2
    for k in range(4):
        im = Image.new("RGBA", (W, lado), (0, 0, 0, 0))
        for i in range(3):
            pieza = llena if i < k else vacia
            im.paste(pieza, (i * (lado + ESTRELLA_HUECO), 0), pieza)
        im.save(OUT / ("estrellas_%d.png" % k))
    print("estrellas_0..3.png %dx%d" % (W, lado))


def main() -> None:
    estrellas()
    ks = kinds()
    for i, idn in enumerate(orden()):
        numero(i + 1, ks.get(idn, "isla"))


if __name__ == "__main__":
    main()
