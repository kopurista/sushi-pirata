#!/usr/bin/env python3
"""Deja el cartel de paso SIN flecha: una tabla lisa que sirve para los dos.

Por que: los dos carteles de paso salieron de DOS generaciones distintas de
Meshy y no eran el mismo objeto —madera de otro tono (medido: 90,57,42 contra
114,70,51 de media en el atlas, 24 puntos de rojo), otro reparto de tablas,
otros clavos y otro poste—. Se ven en la misma frontera y en el mismo cruce,
asi que la diferencia no se lee como "otro cartel" sino como que la escena ha
cambiado de luz.

La solucion es UN SOLO modelo para los dos y la flecha PINTADA ENCIMA, como una
calcomania, volteada para el de bajar. Asi los dos carteles son literalmente el
mismo objeto y la unica diferencia posible es la flecha.

Se intento antes voltear la flecha DENTRO del atlas y no vale la pena: la UV de
estos modelos viene TROCEADA por triangulos —la flecha ocupa de u 0,005 a 0,981
y de v 0,015 a 0,970, o sea el atlas entero—, asi que hay que deshacer la
interpolacion baricentrica de cada texel para saber a que punto del modelo
corresponde. Se llego a hacer y el resultado en pantalla salia deshilachado
aunque en el modelo la textura fuera correcta. Lo que queda de aquello y SI
hace falta aqui es el relleno de bordes (ver `rellenar_bordes`).

Uso:  python tools/cartel_sin_flecha.py           (escribe cartel_mar.*)
      python tools/cartel_sin_flecha.py --check   (solo mide)

Despues: `--headless --import`. Y OJO — para que Godot rehaga una importacion
cuyo ARCHIVO no ha cambiado hay que borrar `.godot/imported/<nombre>-*` **y su
`.md5`**; sin eso se sirve el recurso viejo y parece que nada ha cambiado.
"""

import argparse
import json
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

MODELOS = Path("assets/models")
DESTINO = "cartel_mar"
## El modelo TAL CUAL salio de Meshy, con su flecha grabada. Se guarda con una
## extension que Godot no importa para que la herramienta se pueda volver a
## pasar: el `.glb` bueno del juego ya es el que sale de aqui.
ORIGEN_GLB = MODELOS / (DESTINO + ".glb.antes_de_quitar_la_flecha")
ORIGEN_JPG = MODELOS / (DESTINO + "_0.jpg.antes_de_quitar_la_flecha")

## Un texel es flecha si es claro: la madera del cartel es oscura y saturada
## (medido 93,56,41) y su crema es 222,212,171, asi que no hay confusion.
CLARO = 170.0
## Solo la cara de delante.
Z_CARA = 0.04
## Halo alrededor de la flecha al repintar. Ancho a proposito: la textura se
## importa a 256 con mipmaps, asi que se muestrea un mapa reducido que promedia
## texeles de mucho mas alla del borde. Es la leccion de `eye_patch_fix.py`.
HALO = 10
## Pasadas de difusion para cerrar el hueco de la flecha con la madera de al
## lado. El agujero mas ancho ronda los 90 texeles, asi que sobran.
PASADAS = 140
## Relleno de bordes del atlas al terminar (ver `rellenar_bordes`).
PADDING = 24
## De donde se copia la veta para que el parche no salga liso.
SALTO = (137, 91)
## ALISAR EL GRABADO: la flecha venia TALLADA en la tabla (0,0045 de hondo,
## medido), y borrarla de la textura no borra el hueco. Con la flecha nueva
## pintada encima, ese hueco se seguia viendo como una linea oscura asomando
## por fuera de ella. Se empuja hacia fuera todo lo que este hundido dentro de
## la caja de la flecha, hasta el nivel de la propia tabla.
CAJA_FLECHA = 0.012          # margen alrededor de la caja medida
Z_TABLA = 0.0908             # p90 de la cara en esa zona

COMP = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
NUM = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def leer_glb(p: Path):
    raw = p.read_bytes()
    n = struct.unpack("<I", raw[12:16])[0]
    js = json.loads(raw[20:20 + n])
    off = 20 + n
    blen = struct.unpack("<I", raw[off:off + 4])[0]
    return js, raw[off + 8:off + 8 + blen]


def accesor(js, bn, i):
    a = js["accessors"][i]
    bv = js["bufferViews"][a["bufferView"]]
    o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    d = np.frombuffer(bn, dtype=np.dtype("<" + COMP[a["componentType"]]),
                      count=a["count"] * NUM[a["type"]], offset=o)
    return d.reshape(a["count"], NUM[a["type"]])


def rasterizar(tris_uv, tris_xyz, W, H):
    """Para cada texel de esos triangulos, el punto 3D al que corresponde: el
    inverso de la interpolacion baricentrica, la cuenta de `face_paint.py`."""
    masc = np.zeros((H, W), dtype=bool)
    pos = np.zeros((H, W, 3), dtype=np.float32)
    for uvt, xyzt in zip(tris_uv, tris_xyz):
        px = uvt[:, 0] * W
        py = uvt[:, 1] * H
        x0 = max(int(np.floor(px.min())) - 1, 0)
        x1 = min(int(np.ceil(px.max())) + 1, W)
        y0 = max(int(np.floor(py.min())) - 1, 0)
        y1 = min(int(np.ceil(py.max())) + 1, H)
        if x1 <= x0 or y1 <= y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        d = ((py[1] - py[2]) * (px[0] - px[2]) + (px[2] - px[1]) * (py[0] - py[2]))
        if abs(d) < 1e-9:
            continue
        l0 = ((py[1] - py[2]) * (xs - px[2]) + (px[2] - px[1]) * (ys - py[2])) / d
        l1 = ((py[2] - py[0]) * (xs - px[2]) + (px[0] - px[2]) * (ys - py[2])) / d
        l2 = 1.0 - l0 - l1
        dentro = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02)
        if not dentro.any():
            continue
        p = (l0[..., None] * xyzt[0] + l1[..., None] * xyzt[1] + l2[..., None] * xyzt[2])
        masc[y0:y1, x0:x1][dentro] = True
        pos[y0:y1, x0:x1][dentro] = p[dentro]
    return masc, pos


def rellenar_bordes(tex, cubierto, pasos):
    """Rehace el RELLENO DE BORDES del atlas (el padding de las islas de UV).

    Hace falta y no es un adorno: el atlas trae, alrededor de cada isla, una
    orla del color de la isla —de los 98.495 texeles claros del cartel, 42.818
    NO los toca ningun triangulo: son la orla de la flecha—. El renderizador
    filtra bilinealmente y con mipmaps, asi que tira de esa orla al dibujar el
    canto de la isla. Repintando la flecha sin rehacer la orla, la flecha vieja
    reaparecia en fantasma justo por donde estaba su orla.
    """
    out = tex.copy()
    val = cubierto.copy()
    for _ in range(pasos):
        if val.all():
            break
        movido = False
        for eje, d in ((0, 1), (0, -1), (1, 1), (1, -1)):
            v = np.roll(val, d, axis=eje)
            c2 = np.roll(out, d, axis=eje)
            pon = v & ~val
            if pon.any():
                out[pon] = c2[pon]
                val |= pon
                movido = True
        if not movido:
            break
    return out


def alisar_grabado(js, bn: bytes, pos, x0, x1, y0, y1) -> bytes:
    """Levanta el fondo del grabado hasta la cara de la tabla."""
    a = js["accessors"][js["meshes"][0]["primitives"][0]["attributes"]["POSITION"]]
    bv = js["bufferViews"][a["bufferView"]]
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    nueva = pos.copy()
    dentro = ((nueva[:, 0] > x0) & (nueva[:, 0] < x1)
              & (nueva[:, 1] > y0) & (nueva[:, 1] < y1)
              & (nueva[:, 2] > 0.02) & (nueva[:, 2] < Z_TABLA))
    print("alisando el grabado: %d vertices subidos a z=%.4f" % (dentro.sum(), Z_TABLA))
    nueva[dentro, 2] = Z_TABLA
    b = bytearray(bn)
    b[off:off + nueva.size * 4] = nueva.astype("<f4").tobytes()
    a["min"] = [float(nueva[:, k].min()) for k in range(3)]
    a["max"] = [float(nueva[:, k].max()) for k in range(3)]
    return bytes(b)


def escribir_glb(js, bn: bytes, img: bytes, destino: Path) -> None:
    """Copia el .glb cambiandole la imagen EMBEBIDA.

    Hay que tocar el .glb y no basta con dejar el .jpg de al lado: Godot importa
    estos modelos con `embedded_image_handling=1` (extraer), asi que al ver un
    .glb nuevo REESCRIBE `<modelo>_0.jpg` con la imagen que lleva dentro. Se
    comprobo por las bravas: el jpg editado volvia a ser identico al original,
    0 texeles de diferencia.
    """
    idx_img = js["images"][0]["bufferView"]
    vistas = sorted(range(len(js["bufferViews"])),
                    key=lambda i: js["bufferViews"][i].get("byteOffset", 0))
    trozos = []
    off = 0
    for i in vistas:
        bv = js["bufferViews"][i]
        o = bv.get("byteOffset", 0)
        datos = img if i == idx_img else bn[o:o + bv["byteLength"]]
        if off % 4:
            trozos.append(b"\0" * (4 - off % 4))
            off += 4 - off % 4
        bv["byteOffset"] = off
        bv["byteLength"] = len(datos)
        trozos.append(datos)
        off += len(datos)
    nb = b"".join(trozos)
    js["buffers"][0]["byteLength"] = len(nb)
    jb = json.dumps(js, separators=(",", ":")).encode("utf-8")
    jb += b" " * ((4 - len(jb) % 4) % 4)
    nb += b"\0" * ((4 - len(nb) % 4) % 4)
    out = bytearray()
    out += b"glTF" + struct.pack("<II", 2, 12 + 8 + len(jb) + 8 + len(nb))
    out += struct.pack("<II", len(jb), 0x4E4F534A) + jb
    out += struct.pack("<II", len(nb), 0x004E4942) + nb
    destino.write_bytes(bytes(out))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    js, bn = leer_glb(ORIGEN_GLB)
    pr = js["meshes"][0]["primitives"][0]
    pos = accesor(js, bn, pr["attributes"]["POSITION"]).astype(np.float32)
    uv = accesor(js, bn, pr["attributes"]["TEXCOORD_0"]).astype(np.float32)
    idx = accesor(js, bn, pr["indices"]).astype(np.int64).ravel().reshape(-1, 3)
    tex = np.asarray(Image.open(ORIGEN_JPG).convert("RGB")).astype(np.float32)
    H, W, _ = tex.shape

    # --- MEDIDA de la flecha, que es lo que hay que replicar con la calcomania
    tx = np.clip((uv[:, 0] * W).astype(int), 0, W - 1)
    ty = np.clip((uv[:, 1] * H).astype(int), 0, H - 1)
    claro = tex[ty, tx].mean(axis=1) > CLARO
    fx0, fx1 = float(pos[claro, 0].min()), float(pos[claro, 0].max())
    fy0, fy1 = float(pos[claro, 1].min()), float(pos[claro, 1].max())
    cara = pos[(np.abs(pos[:, 0]) < 0.35) & (np.abs(pos[:, 1]) < 0.30)][:, 2]
    z_cara = float(np.percentile(cara, 95))
    print("FLECHA MEDIDA en el modelo:")
    print("  X %.4f .. %.4f  (centro %.4f, ancho %.4f)" % (fx0, fx1, 0.5 * (fx0 + fx1), fx1 - fx0))
    print("  Y %.4f .. %.4f  (centro %.4f, alto  %.4f)" % (fy0, fy1, 0.5 * (fy0 + fy1), fy1 - fy0))
    print("  cara de la tabla en Z = %.4f (p95); la flecha esta grabada %.4f"
          % (z_cara, z_cara - float(pos[claro, 2].mean())))
    if args.check:
        return 0

    # --- borrar la flecha del atlas
    # SE MIRAN TODOS LOS TRIANGULOS, no solo los de la cara. Filtrando por
    # centroide z se quedaban fuera las PAREDES del grabado —que se hunden y
    # cuyo centroide cae por debajo del corte— y sobrevivian 8.208 texeles
    # claros justo en el hueco de la flecha: en pantalla, su fantasma. En este
    # cartel no hay nada mas que sea claro, asi que "claro" es "flecha".
    todo, _ = rasterizar(uv[idx], pos[idx], W, H)
    # SE BORRA TODO LO CLARO DEL ATLAS, tambien lo que ningun triangulo toca.
    # Esa es la ORLA de las islas de la flecha (42.818 texeles), y no es un
    # detalle: el relleno por difusion crece desde el BORDE del hueco, asi que
    # dejando la orla crema ahi fuera, la difusion la chupaba hacia dentro y
    # volvia a pintar de crema 8.208 texeles — la flecha resucitaba en fantasma
    # justo donde estaba. En este cartel no hay nada mas claro que la flecha.
    fuera = tex.mean(axis=2) > CLARO
    print("texeles claros en el atlas: %d (de ellos, en la malla %d)"
          % (fuera.sum(), (fuera & todo).sum()))
    hueco = fuera
    for _ in range(HALO):
        hueco = np.asarray(Image.fromarray((hueco * 255).astype("uint8"))
                           .filter(ImageFilter.MaxFilter(3))) > 127
    print("con halo de %d: %d texeles a repintar" % (HALO, hueco.sum()))

    out = tex.copy()
    val = (~hueco).astype(np.float32)
    out[hueco] = 0.0
    for _ in range(PASADAS):
        if val.min() > 0.5:
            break
        s = np.zeros_like(out)
        w = np.zeros_like(val)
        for eje, d in ((0, 1), (0, -1), (1, 1), (1, -1)):
            s += np.roll(out * val[..., None], d, axis=eje)
            w += np.roll(val, d, axis=eje)
        crece = (val < 0.5) & (w > 0)
        out[crece] = (s / np.maximum(w, 1e-6)[..., None])[crece]
        val[crece] = 1.0
    # La veta, copiada de una zona desplazada: sin esto queda un parche liso.
    suave = np.asarray(Image.fromarray(tex.astype("uint8"))
                       .filter(ImageFilter.GaussianBlur(3.0))).astype(np.float32)
    det = np.roll(np.roll(tex - suave, SALTO[0], axis=0), SALTO[1], axis=1)
    det[np.roll(np.roll(hueco, SALTO[0], axis=0), SALTO[1], axis=1)] = 0.0
    out[hueco] = np.clip(out[hueco] + det[hueco], 0, 255)

    out = rellenar_bordes(out, todo.copy(), PADDING)
    queda = (out.mean(axis=2) > CLARO) & todo
    print("texeles claros que quedan en la malla: %d" % queda.sum())

    bn = alisar_grabado(js, bn, pos, fx0 - CAJA_FLECHA, fx1 + CAJA_FLECHA,
                        fy0 - CAJA_FLECHA, fy1 + CAJA_FLECHA)

    dst_jpg = MODELOS / (DESTINO + "_0.jpg")
    Image.fromarray(out.astype("uint8")).save(dst_jpg, quality=94, subsampling=0)
    escribir_glb(js, bn, dst_jpg.read_bytes(), MODELOS / (DESTINO + ".glb"))
    print("escritos %s.glb y %s_0.jpg (tabla lisa, sin flecha)" % (DESTINO, DESTINO))
    return 0


if __name__ == "__main__":
    sys.exit(main())
