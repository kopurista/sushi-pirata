"""Prepara el SET DE INTERFAZ nuevo (estilo cartoon pirata) para assets/ui/.

Las fuentes las genera Ludo en _gen/ui2/. Este script hace lo mismo que
tools/ui_prep.gd pero en Python, porque aquí hacen falta dos cosas que allí no
existían: limpiar el interior del pergamino (las manchas oscuras que trae la
generacion se convierten en un churro al estirar el 9-slice) y derivar piezas
por espejo o por tinte en vez de volver a generarlas.

    python tools/ui2_prep.py
"""

from collections import deque
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

RAW = Path("_gen/ui2")
OUT = Path("assets/ui")

# Alfa a partir del cual un pixel cuenta como sujeto al recortar. El mismo
# umbral alto de ui_prep.gd: por debajo entra la sombra difusa y el recorte se
# va varios pixeles, que en un 9-slice descoloca el marco.
ALPHA_CROP = 160


def load(name: str) -> Image.Image:
    return Image.open(RAW / f"{name}.webp").convert("RGBA")


def drop_white(img: Image.Image, thr: int = 232) -> Image.Image:
    """Fondo blanco -> transparente por INUNDACION desde los bordes.

    Desde los bordes y no por umbral global a proposito: los brillos claros de
    dentro del sujeto (el reflejo de la estrella, el oro claro de la moneda) no
    se tocan porque el relleno no llega hasta ellos.
    """
    img = img.copy()
    w, h = img.size
    px = img.load()
    seen = bytearray(w * h)
    q = deque()

    def push(x, y):
        i = y * w + x
        if not seen[i]:
            seen[i] = 1
            r, g, b, a = px[x, y]
            if a > 0 and r >= thr and g >= thr and b >= thr:
                q.append((x, y))

    for x in range(w):
        push(x, 0)
        push(x, h - 1)
    for y in range(h):
        push(0, y)
        push(w - 1, y)

    while q:
        x, y = q.popleft()
        px[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h:
                push(nx, ny)
    return img


def keep_largest(img: Image.Image) -> Image.Image:
    """Deja solo la mancha de alfa mas grande.

    La inundacion de fondo deja motas sueltas donde el borde de la imagen traia
    un pixel algo mas oscuro que el umbral. Da igual que sean invisibles: el
    recorte por bounding box SI las ve, y la estrella salia con 8 px de aire
    muerto a la izquierda que la descentraban en su fila.
    """
    w, h = img.size
    a = img.split()[3].load()
    lab = [0] * (w * h)
    best, best_n = 0, 0
    tag = 0
    for sy in range(h):
        for sx in range(w):
            if lab[sy * w + sx] or a[sx, sy] < ALPHA_CROP:
                continue
            tag += 1
            n = 0
            q = deque([(sx, sy)])
            lab[sy * w + sx] = tag
            while q:
                x, y = q.popleft()
                n += 1
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if 0 <= nx < w and 0 <= ny < h \
                            and not lab[ny * w + nx] and a[nx, ny] >= ALPHA_CROP:
                        lab[ny * w + nx] = tag
                        q.append((nx, ny))
            if n > best_n:
                best, best_n = tag, n
    out = img.copy()
    px = out.load()
    for y in range(h):
        for x in range(w):
            if a[x, y] >= ALPHA_CROP and lab[y * w + x] != best:
                px[x, y] = (0, 0, 0, 0)
    return out


def crop_alpha(img: Image.Image, margin: int = 0) -> Image.Image:
    bb = img.split()[3].point(lambda a: 255 if a >= ALPHA_CROP else 0).getbbox()
    if bb is None:
        return img
    x0, y0, x1, y1 = bb
    x0, y0 = max(x0 - margin, 0), max(y0 - margin, 0)
    x1, y1 = min(x1 + margin, img.width), min(y1 + margin, img.height)
    return img.crop((x0, y0, x1, y1))


def fit_width(img: Image.Image, w: int) -> Image.Image:
    h = round(img.height * w / img.width)
    return img.resize((w, h), Image.LANCZOS)


def save(img: Image.Image, name: str) -> None:
    img.save(OUT / f"{name}.png")
    print(f"{name:22s} {img.width}x{img.height}")


def fit_height(img: Image.Image, h: int) -> Image.Image:
    w = round(img.width * h / img.height)
    return img.resize((w, h), Image.LANCZOS)


def solidify(img: Image.Image, thr: int = 90) -> Image.Image:
    """Alfa a tope en todo lo que no sea fondo.

    Un 9-slice ESTIRA la banda del borde a lo ancho del panel, asi que un borde
    con alfa a medias (el antialias del dibujo original bajaba a 145) se
    convierte en una franja translucida a lo largo de TODO el canto superior:
    era la 'transparencia en la parte de arriba' del tablon de dialogo.
    """
    r, g, b, a = img.split()
    return Image.merge("RGBA", (r, g, b, a.point(lambda v: 255 if v >= thr else 0)))


# --------------------------------------------------------------- pergamino

def build_panel() -> None:
    """Pergamino 9-slice: marco de madera + interior LIMPIO.

    El interior se aplana a proposito. Es la zona que el 9-slice ESTIRA, y la
    generacion trae manchas y arañazos que al estirarse se leen como churretes
    a lo ancho del panel. Un desenfoque fuerte solo en el centro deja un crema
    con nube suave, que estirado sigue pareciendo papel.
    """
    src = crop_alpha(load("panel_4"))
    inset, feather = 72, 26

    soft = src.filter(ImageFilter.GaussianBlur(26))
    mask = Image.new("L", src.size, 0)
    ImageDraw.Draw(mask).rectangle(
        (inset, inset, src.width - inset, src.height - inset), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(feather))
    src = Image.composite(soft, src, mask)

    # EL ANCHO DE SALIDA MANDA SOBRE EL MARGEN 9-SLICE, no al reves. Godot
    # dibuja la esquina a `patch_margin` pixeles TAL CUAL, sin escalar el arte:
    # si el margen es menor que el marco, el sobrante de madera cae en la zona
    # que se estira y se derrama hacia dentro del panel. Asi que el marco tiene
    # que medir en TEXELES lo que quiera verse en pantalla. A 300 px de ancho
    # el marco queda en ~49, y PrepBoard.PANEL_MARGIN va a 52.
    panel = solidify(fit_width(src, 300))
    save(panel, "panel")

    # Pergamino LISO (sin marco) para las tarjetas pequeñas: en un boton de
    # receta de 172x144 el marco de 52 px se comeria el plato. Sale del propio
    # interior, asi que los dos pergaminos son el mismo papel.
    m = 70
    inner = panel.crop((m, m, panel.width - m, panel.height - m))
    plain = inner.resize((128, 128), Image.LANCZOS).convert("RGBA")
    edge = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle(
        (1, 1, 126, 126), radius=14, outline=(92, 58, 30, 255), width=5)
    plain = Image.alpha_composite(plain, edge)
    # Las cuatro esquinas, redondeadas para que el papel no salga a corte vivo.
    round_mask = Image.new("L", (128, 128), 0)
    ImageDraw.Draw(round_mask).rounded_rectangle((0, 0, 127, 127), radius=14, fill=255)
    plain.putalpha(ImageChops.multiply(plain.split()[3], round_mask))
    save(plain, "panel_liso")


def build_button() -> None:
    src = solidify(crop_alpha(load("boton_4")))
    save(fit_width(src, 330), "boton_madera")
    # Version BAJA para los botones pequeños (el "Salir" del nivel): al alto
    # exacto al que se dibuja, para poder 9-slicearla solo a lo ancho. Con la
    # grande, el margen encogido cortaba el tope redondo por la mitad.
    save(fit_height(src, 46), "boton_madera_bajo")


# ------------------------------------------------------------------ piezas

def build_stars() -> None:
    star = crop_alpha(keep_largest(drop_white(load("estrella_1"))), 2)
    star = fit_width(star, 128)
    save(star, "estrella_llena")

    # La VACIA se deriva de la llena, no se genera aparte: asi las dos tienen
    # exactamente la misma silueta y en una fila de estrellas no bailan.
    r, g, b, a = star.split()
    flat = Image.merge("RGBA", (
        r.point(lambda v: int(v * 0.30) + 38),
        g.point(lambda v: int(v * 0.24) + 28),
        b.point(lambda v: int(v * 0.20) + 22),
        a))
    save(flat, "estrella_vacia")


def build_coin() -> None:
    save(fit_width(crop_alpha(keep_largest(drop_white(load("moneda_3"))), 2), 128), "moneda")


def build_arrows() -> None:
    a = fit_width(crop_alpha(keep_largest(drop_white(load("flecha_3"))), 2), 128)
    save(a, "boton_flecha_der")
    save(a.transpose(Image.FLIP_LEFT_RIGHT), "boton_flecha_izq")


def build_slot() -> None:
    save(fit_width(crop_alpha(load("slot_3")), 128), "slot")


def build_ribbon() -> None:
    save(fit_width(crop_alpha(load("cinta_2")), 512), "cinta_titulo")



# ------------------------------------------------- botones con icono propio

## Altura EXACTA a la que el juego dibuja los botones con icono incrustado.
## No es un capricho: los margenes 9-slice son TEXELES que Godot dibuja 1:1, asi
## que la unica forma de que la flecha (o el aspa) no salga aplastada es que la
## textura mida de alto justo lo que el boton. Por eso van con margen vertical
## CERO y se exportan ya a esta altura.
ICON_BTN_H = 64


def build_icon_buttons() -> None:
    for src, dst in [("atras_2", "boton_atras"), ("okb_2", "boton_si"),
                     ("nob_2", "boton_no"), ("rep_2", "boton_repetir"),
                     ("cont_2", "boton_continuar"),
                     ("comp_3", "boton_comprar")]:
        img = solidify(crop_alpha(keep_largest(drop_white(load(src))), 1))
        save(fit_height(img, ICON_BTN_H), dst)


def build_zarpar() -> None:
    """Boton de ¡Zarpar!: placa de oro con ribete rojo.

    Este SI es un 9-slice normal (no lleva icono que deformar), asi que se
    exporta como el boton de madera y se estira a lo que haga falta.
    """
    save(solidify(fit_width(crop_alpha(keep_largest(drop_white(load("zarpar_2"))), 1), 330)),
         "boton_zarpar")


def build_nameplate() -> None:
    """Tablilla del nombre del que habla. Se estira SOLO a lo ancho, asi que los
    clavos de los extremos se quedan donde estan y la tablilla crece o encoge
    con la cantidad de letras del nombre."""
    save(solidify(fit_height(crop_alpha(keep_largest(drop_white(load("placa_3"))), 1), 56)),
         "placa_nombre")


def build_board() -> None:
    """Tabla de cortar: el fondo de la mesa de elaboracion."""
    img = solidify(fit_width(crop_alpha(keep_largest(drop_white(load("tabla_2"))), 1), 560))
    # La tabla NO vive en ui/: es el fondo de la mesa y el juego la carga de
    # assets/props/tabla_cortar.png.
    img.save("assets/props/tabla_cortar.png")
    print(f"{'tabla_cortar (props)':22s} {img.width}x{img.height}")


# ------------------------------------------------------------ barra nitida

## Alto EXACTO de la barra de gesto del tablero (TapBar en level3d.tscn).
BAR_H = 24
## Supermuestreo al dibujarla: se dibuja a 8x y se reduce, que es lo que le da
## el borde limpio a una capsula tan baja.
BAR_SS = 8


def build_hud() -> None:
    """Piezas del marcador: propinas, arroz, caja de recurso y boton de mas."""
    for src, dst, w in [("propina_3", "ic_propina", 128),
                        ("arroz_3", "ic_arroz", 128),
                        ("mas_1", "boton_mas", 96),
                        ("cuerda_3", "cuerda_esquina", 128),
                        ("next_3", "ic_siguiente", 96)]:
        save(fit_width(crop_alpha(keep_largest(drop_white(load(src))), 2), w), dst)
    # La caja de recurso se estira SOLO a lo ancho, asi que va al alto exacto al
    # que se dibuja (PrepBoard.RESOURCE_H).
    save(solidify(fit_height(
        crop_alpha(keep_largest(drop_white(load("cajar_3"))), 1), 60)),
        "caja_recurso")


def build_bar(name: str = "barra", h: int = BAR_H) -> None:
    """Barra de progreso DIBUJADA, no generada.

    La anterior venia de una imagen de 512x103 estirada a 464x24: los topes
    redondos se aplastaban a elipses y el conjunto se veia sucio, que es
    exactamente lo que se veia mal al elaborar una receta. Dibujandola a la
    altura final el 9-slice sale 1:1 en vertical y no deforma nada.
    """
    alto = h
    h = alto * BAR_SS
    w = h * 6
    rim = round(3.5 * BAR_SS)

    trough = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(trough)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=h // 2,
                        fill=(74, 44, 22, 255), outline=(38, 20, 9, 255),
                        width=max(2, BAR_SS // 2))
    d.rounded_rectangle((rim, rim, w - 1 - rim, h - 1 - rim),
                        radius=(h - 2 * rim) // 2, fill=(38, 22, 12, 255))
    save(trough.resize((w // BAR_SS, alto), Image.LANCZOS), name + "_fondo")

    # El relleno va en BLANCO: el juego lo tiñe con modulate segun la barra.
    fill = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    inner = rim + BAR_SS
    ImageDraw.Draw(fill).rounded_rectangle(
        (inner, inner, w - 1 - inner, h - 1 - inner),
        radius=(h - 2 * inner) // 2, fill=(255, 255, 255, 255))
    # Brillo suave en la mitad de arriba, para que no sea una mancha plana.
    gloss = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(gloss).rounded_rectangle(
        (inner, inner, w - 1 - inner, h // 2),
        radius=(h // 2 - inner) // 2, fill=(255, 255, 255, 60))
    fill = Image.alpha_composite(fill, gloss)
    save(fill.resize((w // BAR_SS, alto), Image.LANCZOS), name + "_relleno")


# ------------------------------------------------- montones de los paquetes

def _pile(base: Image.Image, spots) -> Image.Image:
    """Apila copias del MISMO dibujo para formar un montón.

    Los paquetes de la tienda de lingotes y de arroz se componen aquí en vez de
    generarse: usando el mismo dibujo, el montón de 5 y el de 10 son
    inequívocamente "más de lo mismo" que la pieza suelta, que es justo lo que
    tiene que leerse. `spots` va en fracciones del lado de la pieza:
    (dx, dy, escala), y se pinta de ATRÁS HACIA DELANTE (el de más abajo,
    el último) para que el solape se vea bien.
    """
    w, h = base.size
    xs = [x for x, _, e in spots]
    ys = [y for _, y, e in spots]
    es = [e for _, _, e in spots]
    ancho = int((max(xs) - min(xs) + max(es)) * w) + 8
    alto = int((max(ys) - min(ys) + max(es)) * h) + 8
    lienzo = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    for dx, dy, esc in sorted(spots, key=lambda t: t[1]):
        pieza = base.resize((max(1, int(w * esc)), max(1, int(h * esc))),
                            Image.LANCZOS)
        px = int((dx - min(xs)) * w) + 4
        py = int((dy - min(ys)) * h) + 4
        lienzo.alpha_composite(pieza, (px, py))
    return lienzo


def build_packs() -> None:
    """Paquetes de la tienda de lingotes y de arroz.

    Los montones de 5 y 10 se GENERAN, no se componen apilando la pieza suelta
    como en la primera versión: pedidos como pirámide explícita ("tres abajo y
    dos encima", "cuatro, tres, dos y uno") salen alineados y con el sombreado
    coherente, que es justo lo que el apilado a mano no daba.
    """
    ling = crop_alpha(keep_largest(drop_white(load("ling_1"))), 2)
    save(fit_width(ling, 128), "ic_lingote")
    save(fit_width(crop_alpha(keep_largest(drop_white(load("l5_1"))), 2), 150),
         "pack_lingote_5")
    save(fit_width(crop_alpha(keep_largest(drop_white(load("l10_2"))), 2), 160),
         "pack_lingote_10")
    save(fit_width(crop_alpha(keep_largest(drop_white(load("a10_4"))), 2), 150),
         "pack_arroz_10")

    # El de 5 sacos SÍ sigue compuesto: salió bien y no hacía falta rehacerlo.
    saco = Image.open(OUT / "ic_arroz.png").convert("RGBA")
    save(fit_width(_pile(saco, [
        (0.0, 0.55, 0.78), (0.44, 0.55, 0.78), (0.88, 0.55, 0.78),
        (0.22, 0.0, 0.78), (0.66, 0.0, 0.78)]), 150), "pack_arroz_5")

    # Montones de MONEDAS para el cartel de compra de oro: compuestos con
    # `_pile` a partir de la moneda suelta, que para discos apilados funciona
    # perfectamente (no hay que alinear caras como en los lingotes).
    mon = Image.open(OUT / "moneda.png").convert("RGBA")
    save(fit_width(_pile(mon, [
        (0.0, 0.30, 0.72), (0.38, 0.30, 0.72), (0.19, 0.0, 0.72)]), 140),
        "pack_moneda_500")
    save(fit_width(_pile(mon, [
        (0.0, 0.62, 0.62), (0.34, 0.62, 0.62), (0.68, 0.62, 0.62),
        (0.17, 0.31, 0.62), (0.51, 0.31, 0.62), (0.34, 0.0, 0.62)]), 150),
        "pack_moneda_1000")

    # Cartel de compra: toldo a rayas e interior vacío. Se dibuja a TAMAÑO FIJO
    # (no es 9-slice), así que se exporta a la resolución en la que se usa.
    save(solidify(fit_width(crop_alpha(load("ptienda_2")), 660)), "panel_tienda")


if __name__ == "__main__":
    build_panel()
    build_button()
    build_stars()
    build_coin()
    build_arrows()
    build_slot()
    build_ribbon()
    build_bar()
    # Marcador de la partida: la barra del dinero y la de propinas van a alturas
    # distintas, y cada una necesita SU textura (el tope redondo mide media
    # altura, asi que una sola no vale para las dos).
    build_bar("barra_oro", 32)
    build_bar("barra_propina", 20)
    build_hud()
    build_icon_buttons()
    build_zarpar()
    build_nameplate()
    build_board()
    build_packs()
