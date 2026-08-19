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

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageOps

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


def fill_white_holes(img: Image.Image, thr: int = 232) -> Image.Image:
    """Transparenta el blanco que quedo ENCERRADO tras `drop_white`.

    `drop_white` inunda desde los BORDES a proposito, para no tocar brillos
    claros dentro del sujeto. Pero eso deja intacto el blanco que queda
    encerrado por completo dentro del dibujo -sin camino hasta el borde-, como
    el hueco circular de una senal de "prohibido" o el centro de un engranaje
    detras de una llave: ahi no hay reflejo que proteger, es fondo que no
    llego a inundarse. Se relanza la misma inundacion pero solo por las
    regiones blancas QUE NO TOCAN EL BORDE.
    """
    img = img.copy()
    w, h = img.size
    px = img.load()
    lab = [0] * (w * h)
    tag = 0
    groups = []  # tag -> (pixeles, toca_borde)
    for sy in range(h):
        for sx in range(w):
            i = sy * w + sx
            if lab[i]:
                continue
            r, g, b, a = px[sx, sy]
            if not (a > 0 and r >= thr and g >= thr and b >= thr):
                continue
            tag += 1
            pixels = []
            touches_border = False
            q = deque([(sx, sy)])
            lab[i] = tag
            while q:
                x, y = q.popleft()
                pixels.append((x, y))
                if x == 0 or y == 0 or x == w - 1 or y == h - 1:
                    touches_border = True
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if lab[j]:
                            continue
                        nr, ng, nb, na = px[nx, ny]
                        if na > 0 and nr >= thr and ng >= thr and nb >= thr:
                            lab[j] = tag
                            q.append((nx, ny))
            groups.append((pixels, touches_border))
    for pixels, touches_border in groups:
        if touches_border:
            continue
        for x, y in pixels:
            px[x, y] = (0, 0, 0, 0)
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


def drop_specks(img: Image.Image, min_frac: float = 0.003) -> Image.Image:
    """Quita las islas de alfa MINUSCULAS, pero conserva las demas.

    Es el hermano tolerante de keep_largest, y hace falta para los dibujos con
    piezas sueltas A PROPOSITO: los remolinos del aroma, el corazon verde sobre
    la cabeza del grumete o las monedas cayendo sobre el bote. Con keep_largest
    esos iconos perdian justo lo que los distinguia y quedaban tres nigiris
    identicos en el cartel. Se descarta lo que no llegue a `min_frac` de la
    isla mayor, que es lo que de verdad son motas del recorte.
    """
    w, h = img.size
    a = img.split()[3].load()
    lab = [0] * (w * h)
    sizes = [0]
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
            sizes.append(n)
    if tag == 0:
        return img
    floor = max(sizes) * min_frac
    out = img.copy()
    px = out.load()
    for y in range(h):
        for x in range(w):
            t = lab[y * w + x]
            if t and sizes[t] < floor:
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
                        ("next_3", "ic_siguiente", 96),
                        ("cerr_2", "boton_cerrar", 128)]:
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

    # BOLSAS de monedas para el cartel de compra de oro. Una moneda suelta
    # apilada no dice "cien monedas"; una bolsa llena sí, y el montón de bolsas
    # escala la idea sin tener que contar discos.
    for src, dst, w in [("b1_1", "pack_moneda_100", 140),
                        ("b5_1", "pack_moneda_500", 150),
                        ("b10_2", "pack_moneda_1000", 150)]:
        save(fit_width(crop_alpha(keep_largest(drop_white(load(src))), 2), w), dst)

    # Cartel de compra: toldo a rayas e interior vacío. Se dibuja a TAMAÑO FIJO
    # (no es 9-slice), así que se exporta a la resolución en la que se usa.
    save(solidify(fit_width(crop_alpha(load("ptienda_2")), 660)), "panel_tienda")


# --------------------------------------------- iconos de los potenciadores

# Lado al que se exportan. El cartel los dibuja a 104 px con
# STRETCH_KEEP_ASPECT_CENTERED, asi que lo que importa es el LADO LARGO: se
# ajusta ese y el corto cae donde caiga (los tres piratas de "Mas clientela"
# son mucho mas anchos que altos y con fit_width salian enanos de alto).
POWERUP_ICON_SIDE = 128

# Variante elegida de cada tanda de Ludo (se generaron dos de cada). Las
# descartadas se quedan en _gen/ui2/pot por si hay que volver sobre ellas.
POWERUPS = [
    ("pot_cinta_a", "pot_cinta"),
    ("pot_aroma_b", "pot_aroma"),
    ("pot_instantanea_a", "pot_instantanea"),
    ("pot_paciencia_a", "pot_paciencia"),
    ("pot_sin_esperas_a", "pot_sin_esperas"),
    ("pot_propinas_a", "pot_propinas"),
    ("pot_clientela_a", "pot_clientela"),
    ("pot_tiempo_muerto_a", "pot_tiempo_muerto"),
    ("pot_almacen_b", "pot_almacen"),
    ("pot_doble_a", "pot_doble"),
    ("pot_reloj_a", "pot_reloj"),
    # Potenciadores de hastío/variedad.
    ("pot_variedad_a", "pot_variedad"),
    ("pot_sobremesa_a", "pot_sobremesa"),
    ("pot_picoteo_a", "pot_picoteo"),
    ("pot_sin_basura_a", "pot_sin_basura"),
    ("pot_doble_mult_a", "pot_doble_mult"),
    # Bonificadores PERMANENTES (perk_data), que hasta ahora reusaban iconos
    # de menu como provisionales.
    ("perk_limite_b", "perk_limite"),
    ("perk_barco_a", "perk_barco"),
]


def fit_max(img: Image.Image, side: int) -> Image.Image:
    if img.width >= img.height:
        return fit_width(img, side)
    return fit_height(img, side)


def build_powerups() -> None:
    """Los 11 iconos del cartel de potenciadores.

    NO llevan `solidify`: no son 9-slice, se dibujan a tamano fijo dentro de la
    tarjeta, asi que el antialias del borde ayuda en vez de estorbar (la franja
    translucida que obliga a solidificar solo aparece al ESTIRAR una banda).

    Y van con `drop_specks`, NO con `keep_largest`: media docena de estos
    iconos se explican con una pieza que flota separada del sujeto (los
    remolinos del aroma, el corazon verde, las monedas cayendo, el destello de
    la receta instantanea). Quedarse con la isla mayor los dejaba en un nigiri
    pelado, tres veces el mismo dibujo en el cartel.
    """
    for src, dst in POWERUPS:
        img = drop_white(Image.open(RAW / "pot" / f"{src}.webp").convert("RGBA"))
        # "Nada se tira" es una senal de PROHIBIDO: el circulo rojo encierra un
        # anillo de blanco entre el trazo y el cubo que la inundacion desde el
        # borde no alcanza (no toca ningun canto de la imagen). Solo aqui: los
        # demas potenciadores no tienen fondo encerrado y no hace falta tocarlos.
        if dst == "pot_sin_basura":
            img = fill_white_holes(img)
        save(fit_max(crop_alpha(drop_specks(img), 2), POWERUP_ICON_SIDE), dst)


# ------------------------------------------------- iconos de coleccionable

# Se dibujan a 200 px como mucho: 100 en la vitrina y ~220 en la ficha y el
# anuncio (ahi un pelin ampliados, asumido: son dibujos limpios de Ludo).
COLLECTIBLE_ICON_SIDE = 200

COLLECTIBLES = [
    "sombrero_paja", "bandera", "botella", "mapa_tesoro", "cartel_recompensa",
    "catalejo", "tricornio", "panuelo", "garfio", "parche", "canon", "ancla",
    "pistola", "espada", "brujula", "pluma_loro", "pluma_escribir", "barril",
    "tentaculo", "vela", "trifuerza", "hueso", "calavera", "pata_palo",
    "perla_negra", "bala_canon", "moneda_azteca", "naranja", "tirachinas",
    "sarten", "pendientes_espadachin", "grog", "mono_tres_cabezas",
    "lista_insultos", "semilla_dorada", "reloj_arena", "mascara_zora",
    "saco_cafe", "gafas_nerd", "tentaculo_purpura", "peluche_morsa",
    "foto_christine", "escudo_antiguo", "huevo_montana", "esfera_tesoro",
    "colgante_cielos", "caracol_telefono", "cuerno_reno", "violin_esqueleto",
    "sombrero_vaquero", "botella_cola", "batuta_viento", "botella_leche",
    "pollo_goma", "corazon_cofre", "marca_negra", "reloj_cocodrilo",
    "lata_espinacas", "maneki_neko", "daruma", "botella_sake",
    "escama_sirena", "cuchillo_maestro", "galon_oro", "tenedor",
    "maqueta_unicornio", "ojo_cobre", "delantal_chamuscado",
    "campana_servicio", "diente_kappa", "koinobori", "omamori",
    "palillos_madera", "palillos_plata", "palillos_oro", "tarro_ponyo",
]


def build_collectibles() -> None:
    """Los iconos de la vitrina de coleccionables (col_*.png).

    El timon y el cofre NO estan aqui: reutilizan timon.png y daily_cofre.png,
    que ya son el mismo dibujo en el juego.

    Mismo criterio que build_powerups: sin `solidify` (no son 9-slice) y con
    `drop_specks` en vez de `keep_largest` (la trifuerza son 8 fragmentos
    SEPARADOS por grietas y el mapa lleva la X suelta: quedarse con la isla
    mayor se los comeria). Si la fuente ya trae alfa (removeBackground de
    Ludo), la inundacion de blancos no toca nada y es inocua.
    """
    for name in COLLECTIBLES:
        src = RAW / "col" / f"{name}.webp"
        if not src.exists():
            print(f"col_{name:18s} FALTA {src}")
            continue
        img = drop_white(Image.open(src).convert("RGBA"))
        save(fit_max(crop_alpha(drop_specks(img), 2), COLLECTIBLE_ICON_SIDE),
             f"col_{name}")


# --------------------------------- bocadillo del cliente y chapas de variedad

def build_bubble() -> None:
    """El bocadillo de cómic del cliente (HORIZONTAL) y su versión en espejo.

    Es un 9-slice que se estira A LO ANCHO: se exporta al ALTO al que se
    dibuja (62 px, los márgenes 9-slice son téxeles 1:1) y la banda central
    blanca hace el resto.

    La COLA se VOLTEA a la parte de ARRIBA (`ImageOps.flip`): el bocadillo
    cuelga por DEBAJO de la cabeza del cliente, que es la única franja libre.
    Con la cola abajo el bocadillo salía por encima y tapaba las barras del
    cliente de al lado — y la barra del vecino tapaba a su vez la chapa del
    multiplicador.

    `bocadillo.png` tiene la cola arriba-IZQUIERDA (para el bocadillo que sale
    a la DERECHA de la cabeza) y `bocadillo_esp.png` es su espejo horizontal,
    para el que sale a la izquierda — el mismo patrón que las manos
    ic_mano_izq/der. Lleva `solidify` porque el canto estirado con alfa a
    medias deja franja translúcida.
    """
    img = solidify(fit_height(crop_alpha(drop_white(
        Image.open(RAW / "pot" / "bocadillo_h_a.webp").convert("RGBA")), 1), 62))
    img = ImageOps.flip(img)
    save(img, "bocadillo")
    save(ImageOps.mirror(img), "bocadillo_esp")


# Paleta del set (madera oscura de contorno, oro de acento, crema).
BADGE_BORDE = (74, 46, 20, 255)
BADGE_ORO = (242, 193, 78, 255)
BADGE_BRILLO = (255, 226, 145, 255)
BADGE_TEXTO = (74, 46, 20, 255)


def build_mult_badges() -> None:
    """Chapas x2..x20 del multiplicador de variedad, DIBUJADAS (como la barra),
    no generadas: la tanda de Ludo salía con estallidos de cómic que no
    casaban con el set (madera cálida + pergamino + oro de acento) y cada
    chapa de su padre. Moneda de oro con borde marrón, brillo superior y el
    número en la Exo 2 Bold REAL del juego, supermuestreada a 8x.
    """
    S = 8
    D = 88
    # Hasta x20: el tope normal es x5, el bonificador "Paladar de capitan" lo
    # sube a x10, y el potenciador "Doble variedad" DUPLICA el tope mientras
    # dura. 20 es el techo real del juego y son chapas dibujadas, asi que
    # generarlas todas no cuesta trabajo manual.
    for n in range(2, 21):
        img = Image.new("RGBA", (D * S, D * S), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        c = D * S // 2
        r = c - 2 * S
        d.ellipse([c - r, c - r, c + r, c + r], fill=BADGE_BORDE)
        r2 = r - 4 * S
        d.ellipse([c - r2, c - r2, c + r2, c + r2], fill=BADGE_ORO)
        # Brillo: un arco claro pegado al borde superior, como en la moneda.
        r3 = r2 - 3 * S
        d.arc([c - r3, c - r3, c + r3, c + r3], start=200, end=340,
              fill=BADGE_BRILLO, width=3 * S)
        font = ImageFont.truetype("fonts/static/Exo2-Bold.ttf", 38 * S)
        text = "x%d" % n
        bb = d.textbbox((0, 0), text, font=font)
        d.text((c - (bb[0] + bb[2]) / 2, c - (bb[1] + bb[3]) / 2), text,
               font=font, fill=BADGE_TEXTO)
        save(img.resize((D, D), Image.LANCZOS), "mult_x%d" % n)


# ------------------------------------------------------------ bonus diario

## Lado del cofre exportado. Sobre el mapa se dibuja a ~96 px, asi que 160 deja
## margen para el bote de la animacion sin que se vea borroso.
DAILY_CHEST = 160

## Ancho del mapa exportado. Dentro del panel se dibuja a 520.
DAILY_MAP_W = 560

## Tinta con la que se redibujan los cofres del mapa: el marron del trazo del
## propio pergamino, no un gris.
DAILY_INK = (94, 62, 36)


def inkify(img: Image.Image, oscuro: int = 70, corte: int = 150,
           gamma: float = 0.8) -> Image.Image:
    """Un sprite a COLOR -> el mismo dibujo A PLUMA, para el mapa del tesoro.

    Los cofres de los otros dias tienen que leerse como parte del mapa ("sin
    color realmente"), pero NO pueden ser un dibujo distinto: si el cofre de
    hoy tuviera otra silueta que los de al lado, encenderse pareceria cambiar
    de objeto. Por eso se derivan del cofre de color en vez de generarse
    aparte, igual que ic_mano_der sale de espejar ic_mano_izq.

    La rampa es de DOS PUNTOS y no proporcional a la luminosidad: mas oscuro
    que `oscuro` es trazo a plena tinta, mas claro que `corte` no existe, y en
    medio se degrada. Con una rampa proporcional (el primer intento) la madera
    de en medio se quedaba como una mancha semitransparente y el cofre salia
    gris lavado en vez de dibujado a pluma: hay que TIRAR los tonos medios,
    no atenuarlos.
    """
    r, g, b, a = img.split()
    lum = Image.merge("RGB", (r, g, b)).convert("L")
    tabla = []
    for v in range(256):
        if v <= oscuro:
            t = 1.0
        elif v >= corte:
            t = 0.0
        else:
            t = (corte - v) / float(corte - oscuro)
        tabla.append(max(0, min(255, int((t ** gamma) * 255))))
    tinta = ImageChops.multiply(lum.point(tabla), a)
    hoja = Image.new("RGBA", img.size, DAILY_INK + (255,))
    hoja.putalpha(tinta)
    return hoja


def build_daily() -> None:
    """Mapa del tesoro y los cuatro estados del cofre del BONUS DIARIO.

    El mapa sale SIN ruta ni cofres a proposito: la linea de puntos y los siete
    sitios los dibuja `main_menu` por codigo, que es la unica forma de que los
    cofres caigan CLAVADOS sobre la ruta (con la ruta pintada en la textura,
    cualquier retoque del encuadre la descoloca). Mismo criterio que la barra
    de progreso y las chapas del multiplicador.
    """
    mapa = crop_alpha(drop_white(load("daily/mapa")))
    save(fit_width(mapa, DAILY_MAP_W), "daily_mapa")

    for src, dst in (("cofre", "daily_cofre"),
                     ("cofre_abierto", "daily_cofre_abierto")):
        img = crop_alpha(keep_largest(drop_white(load("daily/" + src))), 2)
        img = fit_max(img, DAILY_CHEST)
        save(img, dst)
        save(inkify(img), dst.replace("daily_cofre", "daily_cofre_mapa"))


# ------------------------------------------------- cartel de recompensa

## Ancho al que se exporta el cartel. Dentro del panel se dibuja a ~592.
WANTED_W = 600


def build_wanted() -> None:
    """La hoja del CARTEL DE RECOMPENSA (perfil del jugador) y la moneda a
    tinta que lleva dibujada.

    La hoja viene de Ludo YA RECORTADA (trae alfa), asi que aqui no hay
    `drop_white` que valga: convertirla a 'L' para medirla pintaba de negro el
    fondo transparente y el barrido daba el marco donde no estaba.

    El hueco de la FOTO (donde va el modelo 3D del personaje) se mide sobre
    esta imagen y vive como fracciones en `wanted_poster.gd`; si se regenera la
    hoja hay que volver a medirlo.

    La moneda NO se genera: es la `moneda.png` del juego pasada por `inkify`,
    que es literalmente lo que pide el diseno ("el mismo icono pero como si
    estuviera dibujado en el cartel").
    """
    hoja = crop_alpha(load("perfil/wanted"))
    save(fit_width(hoja, WANTED_W), "wanted_hoja")

    moneda = Image.open(OUT / "moneda.png").convert("RGBA")
    save(inkify(fit_max(moneda, 96)), "wanted_moneda")

    # La PLUMA que late junto a la linea de escritura del nombre: la senal de
    # "aqui se escribe" del cartel de identidad.
    pluma = drop_white(load("perfil/pluma_a"))
    save(fit_max(crop_alpha(drop_specks(pluma), 2), 72), "wanted_pluma")

    # Flecha IZQUIERDA del selector de personaje: el ESPEJO exacto de la que la
    # caja de dialogo usa para "toca para seguir", igual que ic_mano_der sale de
    # espejar ic_mano_izq. Asi las dos flechas son el mismo dibujo.
    flecha = Image.open(OUT / "ic_siguiente.png").convert("RGBA")
    save(ImageOps.mirror(flecha), "ic_siguiente_esp")


# ------------------------------------------------- submenu del menu principal

## Alto al que se DIBUJA la barra del submenu (regla de los botones con icono:
## la textura se exporta a la altura exacta de dibujo y va con margen vertical
## CERO, porque los margenes 9-slice son texeles 1:1).
SUBMENU_BAR_H = 148


def build_submenu() -> None:
    """La barra del SUBMENU inferior del menu principal (madera oscura con
    cuerda en el canto) y los dos iconos que le faltaban al juego: el cartel
    del Perfil y el brazo de los Bonificadores. Los otros tres botones usan
    iconos que ya existian (ic_logros, ic_inventario, ic_opciones)."""
    bar = solidify(crop_alpha(drop_white(load("sub/barra"))))
    save(fit_height(bar, SUBMENU_BAR_H), "submenu_barra")
    for src, dst in (("sub/ic_perfil", "ic_perfil"), ("sub/ic_perks", "ic_perks")):
        img = drop_white(load(src))
        save(fit_max(crop_alpha(drop_specks(img), 2), 96), dst)
    # El de MAESTRIAS (mano con cuchillo y estrellas) llega ya recortado por el
    # removeBackground de Ludo: solo motas, recorte y tamano.
    save(fit_max(crop_alpha(drop_specks(load("sub/ic_maestrias")), 2), 96),
         "ic_maestrias")


SKILL_ICONS = [
    "fuego_constante", "pulso_firme", "corte_maestro", "manos_ligeras",
    "golpe_vista", "buen_anfitrion", "buen_precio", "mano_suelta",
    "buena_cara", "fama", "cocina_abundante", "buena_mano",
    "segunda_vuelta", "golpe_suerte", "paladar_generoso",
]


def build_skills() -> None:
    """Los 15 iconos de las MAESTRIAS del cocinero (skill_<id>.png, 96 px).
    Fondo blanco fuera por inundacion (drop_white: los blancos interiores
    sobreviven, que el arroz es arte) y drop_specks para las motas, NUNCA
    keep_largest: varios se explican con piezas sueltas (destellos, monedas
    botando, el corazon del paladar)."""
    for name in SKILL_ICONS:
        img = drop_white(load("skills/" + name))
        save(fit_max(crop_alpha(drop_specks(img), 2), 96), "skill_" + name)
    # Los tres iconos de SECCION (una pestana por arbol) y el boton ROJO del
    # menos, hermano del verde `boton_mas` que ya usaban las cajas de recursos.
    for name in ("tab_cuchillo", "tab_cliente", "tab_chef"):
        save(fit_max(crop_alpha(drop_specks(drop_white(load("skills/" + name))), 2),
                     96), name)
    # La CHAPA de los puntos de habilidad: medalla de oro con el disco azul
    # VACIO (el numero se imprime encima desde el juego). Sustituyo a un
    # circulo azul liso dibujado por codigo, que al lado del resto del set se
    # leia como un marcador de posicion.
    save(fit_max(crop_alpha(drop_specks(drop_white(load("skills/chapa_puntos"))),
                            2), 120), "chapa_puntos")
    # El CEBO: el premio de pesca de las subidas de nivel (una tirada gratis).
    save(fit_max(crop_alpha(drop_specks(drop_white(load("menu/ic_cebo"))), 2),
                 96), "ic_cebo")
    derive_minus_button()


def derive_minus_button() -> None:
    """`boton_menos.png` NO se genera: se DERIVA de `boton_mas.png`, para que
    los dos discos de reparto de las Maestrias sean el mismo boton. Se le
    cambia el campo verde por ROJO y de la cruz crema se queda solo el brazo
    horizontal. Generado aparte con Ludo salia un disco rojo plano, sin aro
    dorado ni bisel, y se veia que no eran pareja.

    Dos cosas que costaron una pasada cada una:
      1) la cruz hay que DILATARLA antes de borrarla, o su antialias sobrevive
         y deja un fantasma claro con la silueta del brazo vertical;
      2) el hueco se rellena INTERPOLANDO DE LADO A LADO en su propia fila. Se
         probo con la media de cada ANILLO (el disco es simetrico) y dejaba
         manchas: a ese radio el anillo pasa por el brillo de arriba a la
         izquierda y lo repartia por todo el circulo."""
    import math
    ROJO = (188, 60, 50)   # rojo calido del set, a la luminancia del verde base
    VERDE_G = 144.0        # canal verde del campo del boton (53,144,74)
    im = Image.open(OUT / "boton_mas.png").convert("RGBA")
    W, H = im.size
    src = im.load()
    cx0, cy0 = (W - 1) / 2.0, (H - 1) / 2.0

    # La cruz crema: clara, poco saturada y CERCA DEL CENTRO (el brillo de
    # arriba a la izquierda tambien es casi blanco y no es la cruz).
    cruz = [[False] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            r, g, b, a = src[x, y]
            if a < 128 or math.hypot(x - cx0, y - cy0) > min(W, H) * 0.34:
                continue
            if min(r, g, b) > 170 and (max(r, g, b) - min(r, g, b)) < 70:
                cruz[y][x] = True
    xs = [x for y in range(H) for x in range(W) if cruz[y][x]]
    assert xs, "no se ha encontrado la cruz de boton_mas"
    ancho = max(xs) - min(xs) + 1
    filas = [sum(1 for x in range(W) if cruz[y][x]) for y in range(H)]
    banda = [y for y in range(H) if filas[y] >= ancho * 0.9]
    b0, b1 = min(banda), max(banda)

    DIL = 2
    ancha = [[False] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            if not cruz[y][x]:
                continue
            for dy in range(-DIL, DIL + 1):
                for dx in range(-DIL, DIL + 1):
                    if 0 <= y + dy < H and 0 <= x + dx < W:
                        ancha[y + dy][x + dx] = True

    def relleno(y, x):
        izq, der = x - 1, x + 1
        while izq >= 0 and ancha[y][izq]:
            izq -= 1
        while der < W and ancha[y][der]:
            der += 1
        a_i = src[izq, y] if izq >= 0 and src[izq, y][3] >= 128 else None
        a_d = src[der, y] if der < W and src[der, y][3] >= 128 else None
        if a_i is None and a_d is None:
            return (53, 144, 74)
        if a_i is None:
            return a_d[:3]
        if a_d is None:
            return a_i[:3]
        t = float(x - izq) / float(der - izq)
        return tuple(int(a_i[i] * (1.0 - t) + a_d[i] * t) for i in range(3))

    out = Image.new("RGBA", (W, H))
    dst = out.load()
    for y in range(H):
        for x in range(W):
            if src[x, y][3] >= 128 and ancha[y][x]:
                dst[x, y] = relleno(y, x) + (255,)
            else:
                dst[x, y] = src[x, y]
    # Verde -> ROJO. El canal verde lleva TODO el sombreado del campo, asi que
    # se usa de factor: el bisel, la sombra del borde y el brillo se conservan.
    for y in range(H):
        for x in range(W):
            r, g, b, a = dst[x, y]
            if a < 8 or not (g > r + 12 and g > b + 12):
                continue
            s = g / VERDE_G
            dst[x, y] = (min(255, int(ROJO[0] * s)), min(255, int(ROJO[1] * s)),
                         min(255, int(ROJO[2] * s)), a)
    # Y se vuelve a pegar el brazo horizontal, calcado del original.
    for y in range(b0, b1 + 1):
        for x in range(W):
            if cruz[y][x]:
                dst[x, y] = src[x, y]
    out.save(OUT / "boton_menos.png")
    print("boton_menos            %dx%d (derivado de boton_mas)" % (W, H))


# ---------------------------------------------- panel del menu y su timon

def drop_color(img, cond):
    """Borra los pixeles que cumplan `cond(r, g, b)`. Para basura de la
    generacion que la inundacion de blanco no toca (la raya AZUL que salio
    bajo el pergamino del boton)."""
    img = img.copy()
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a > 0 and cond(r, g, b):
                px[x, y] = (0, 0, 0, 0)
    return img


## Alto al que se DIBUJAN los botones de modo (los pergaminos): la textura se
## exporta a este alto exacto y va con margen vertical CERO, la regla de los
## botones con icono.
MODE_BTN_H = 96


def build_menu_panel() -> None:
    """El tablon del MENU principal (SIN banner: quedaba vacio y sobraba — el
    remate de arriba lo pone el timon), sus BOTONES DE PERGAMINO y los iconos
    de modo PINTADOS, como tinta sobre el papel. El panel es un SPRITE FIJO,
    no un 9-slice: su marco es irregular (cuerdas) y estirarlo lo deformaria.
    Tambien los tres iconos del submenu, rehechos al estilo de ic_perfil."""
    save(fit_width(crop_alpha(drop_white(load("menu/panel2"))), 520),
         "menu_panel")
    # El pergamino de los botones de modo: 9-slice SOLO horizontal (los
    # rollos de los extremos van en el margen y la banda de papel se estira).
    scroll = drop_white(load("menu/scroll"))
    scroll = drop_color(scroll, lambda r, g, b: b > 120 and b > r + 40 and b > g + 40)
    save(fit_height(solidify(crop_alpha(keep_largest(scroll))), MODE_BTN_H),
         "boton_pergamino")
    # Iconos de modo "pintados en el papel", mas contenidos que los antiguos.
    for n in ("ic_aventura", "ic_arcade", "ic_tienda"):
        img = drop_white(load("menu/" + n))
        save(fit_max(crop_alpha(drop_specks(img), 2), 96), n)
    # El ancla pintada del pie del tablon: adorno para que la franja de abajo
    # del menu no quede vacia.
    ancla = drop_white(load("menu/ancla_b"))
    save(fit_max(crop_alpha(drop_specks(ancla), 2), 96), "menu_ancla")
    timon = crop_alpha(keep_largest(drop_white(load("menu/timon"))), 2)
    save(fit_max(timon, 300), "timon")
    for n in ("ic_logros", "ic_inventario", "ic_opciones"):
        img = drop_white(load("menu/" + n))
        # El engranaje de Opciones encierra fondo: el circulo interior detras
        # de la llave y las muescas entre dientes quedan rodeados de metal por
        # todos lados, sin camino hasta el borde de la imagen. Solo aqui: los
        # otros dos iconos no tienen huecos cerrados.
        if n == "ic_opciones":
            img = fill_white_holes(img)
        save(fit_max(crop_alpha(drop_specks(img), 2), 96), n)


# ------------------------------------------------- minijuego de pesca

# Los iconos del ALBUM de pesca (fish_*.png, uno por pez de FishData) y la
# cana del pergamino "Pesca" del menu (ic_pesca). Mismo criterio que
# build_collectibles: sin `solidify` (no son 9-slice) y con `drop_specks` en
# vez de `keep_largest` (la medusa y el pez remo llevan piezas finas y la cana
# un flotador colgando que la isla mayor podria comerse).
FISH_ICON_SIDE = 200

# Los 100 del catalogo, en el MISMO orden que FishData.FISH.
FISH = [
    "sardina", "anchoa", "boqueron", "arenque", "caballa", "jurel",
    "salmonete", "palometa", "sargo", "lisa", "gallo", "bacaladilla",
    "bacalao", "abadejo", "platija", "ayu", "pejesapo", "remora",
    "pez_cirujano", "pez_mariposa", "pez_payaso", "cangrejo", "estrella_mar",
    "caracola", "erizo_mar", "medusa", "botella_rota", "rueda", "bota",
    "mata_wakame", "gamba_real", "salmon", "atun",
    "dorada", "lubina", "besugo", "lenguado", "rodaballo", "merluza",
    "rape", "congrio", "morena", "calamar", "sepia", "pulpo",
    "pirana", "carpa_koi", "lampuga", "pargo_rojo", "pez_volador",
    "pez_balon", "pez_erizo", "pez_loro", "pez_ballesta", "pez_angel",
    "pez_cofre", "raya", "caballito_mar", "bogavante", "langosta",
    "tortuga", "amia_calva", "barbo_oloroso", "pez_rana_pintado",
    "pez_ojo_celestial", "jikin", "oranda", "pez_lapa", "anguila",
    "pez_espada", "mero", "corvina", "tiburon", "tiburon_martillo",
    "tiburon_tigre", "barracuda", "pez_luna", "mantarraya", "pez_leon",
    "pez_napoleon", "pez_sierra", "pez_cabeza_transparente", "pez_vibora",
    "nautilus", "arowana", "siluro", "bata_bata", "froggy",
    "atun_rojo", "atun_amarillo", "fugu", "salmon_real",
    "pez_lanza", "pez_vela", "pez_remo", "calamar_gigante", "celacanto",
    "tiburon_ballena", "caballito_dorado", "koi_dorado",
]


def build_fishing() -> None:
    """La cana del menu (ic_pesca), la cana GRANDE de la pelea (pesca_cana,
    misma fuente a 400 para que no salga borrosa ampliada) y los 40 peces del
    album (fish_*)."""
    icpesca = drop_white(Image.open(RAW / "menu" / "ic_pesca.webp")
                         .convert("RGBA"))
    icpesca = crop_alpha(drop_specks(icpesca), 2)
    save(fit_max(icpesca, 96), "ic_pesca")
    save(fit_max(icpesca, 400), "pesca_cana")
    # El boton de "Pulsa para pescar": tablon con cuerdas y boya, UNICO de la
    # pesca. Sprite FIJO (el marco es irregular, un 9-slice lo deformaria),
    # exportado al ancho al que se dibuja.
    boton = drop_white(Image.open(RAW / "pesca_boton_1.webp").convert("RGBA"))
    save(fit_width(crop_alpha(drop_specks(boton), 2), 470), "boton_pesca")
    # El icono del boton del ALBUM (arriba a la derecha de la pesca).
    album = drop_white(Image.open(RAW / "fish" / "ic_album.webp")
                       .convert("RGBA"))
    save(fit_max(crop_alpha(drop_specks(album), 2), 120), "ic_album")
    # La CANA-HUD de la pelea (vertical y RECTA a proposito: encima corre el
    # liston del sedal) y su MANIVELA suelta, que gira por codigo sobre el
    # carrete. Si se regeneran, volver a medir ROD_TRACK/ROD_REEL en
    # fishing_game.gd.
    hud = drop_white(Image.open(RAW / "cana_hud_2.webp").convert("RGBA"))
    save(fit_max(crop_alpha(drop_specks(hud), 2), 460), "pesca_cana_hud")
    mani = drop_white(Image.open(RAW / "manivela.webp").convert("RGBA"))
    save(fit_max(crop_alpha(drop_specks(mani), 2), 110), "pesca_manivela")
    for name in FISH:
        src = RAW / "fish" / f"{name}.webp"
        if not src.exists():
            print(f"fish_{name:14s} FALTA {src}")
            continue
        img = drop_white(Image.open(src).convert("RGBA"))
        save(fit_max(crop_alpha(drop_specks(img), 2), FISH_ICON_SIDE),
             f"fish_{name}")


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
    build_powerups()
    build_bubble()
    build_mult_badges()
    build_daily()
    build_wanted()
    build_submenu()
    build_menu_panel()
    build_fishing()


# --------------------------------- calavera del contador y chapa de bonificador

def build_perks_ui() -> None:
    """Dos piezas que no encajan en ningun grupo anterior.

    `calavera_vacio` es el contador de vacios del PUERTO: hasta ahora reusaba
    `col_calavera` (la calavera de la vitrina, que es un craneo pelado) y no se
    leia como lo que es. Esta es la de la BANDERA PIRATA, con los dos huesos
    cruzados por detras.

    `boton_perk` es la chapa de laton de los bonificadores. Va aparte del boton
    de madera del resto del juego a proposito (pedido por el usuario): un
    bonificador no es un boton mas, y con la misma madera no se distinguia de
    una receta. Se exporta a 330 de ancho como `boton_madera`, asi que su marco
    cae en ~34 texeles: el margen 9-slice que deja los remaches enteros.
    """
    cal = drop_white(Image.open(RAW / "misc" / "calavera_pirata.webp")
        .convert("RGBA"))
    save(fit_max(crop_alpha(drop_specks(cal), 2), 128), "calavera_vacio")
    plate = drop_white(Image.open(RAW / "misc" / "boton_perk.webp")
        .convert("RGBA"))
    save(fit_width(solidify(crop_alpha(plate)), 330), "boton_perk")
