"""RECOMPRIME LAS TEXTURAS EMBEBIDAS DE UN .glb (7-9-2026).

Los props de Meshy (`assets/models/la_*.glb`) llegan con su atlas embebido a
2048x2048 en PNG/JPEG de alta calidad: 2,5-3,2 MB por pieza, ~70 MB en los
veinticinco del estilo LA, y todo eso solo pesa en el REPOSITORIO (Godot
exporta la importacion, no el origen, y el `.import` ya recorta la textura
a 256-1024). Aqui se reescala el atlas a `lado` y se guarda en JPEG `calidad`,
reescribiendo el chunk BIN del glb sin tocar la malla.

    python tools/glb_textura.py [--lado 1024] [--calidad 85] archivo.glb ...

OJO: despues hay que BORRAR la textura extraida (`<modelo>_0.jpg`) y su
importacion (`.godot/imported/<modelo>*`) y reimportar, o Godot sigue con el
atlas viejo (la trampa documentada en CLAUDE.md).
"""
import sys, io, json, struct, argparse
from pathlib import Path
from PIL import Image

GLB_MAGIC = b"glTF"
JSON_CHUNK, BIN_CHUNK = 0x4E4F534A, 0x004E4942


def leer(raw):
    total = struct.unpack("<I", raw[8:12])[0]
    off, doc, binario = 12, None, b""
    while off < total:
        n, kind = struct.unpack("<II", raw[off:off + 8])
        datos = raw[off + 8:off + 8 + n]
        if kind == JSON_CHUNK:
            doc = json.loads(datos)
        elif kind == BIN_CHUNK:
            binario = datos
        off += 8 + n
    return doc, binario


def escribir(doc, binario):
    js = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    binario += b"\0" * ((4 - len(binario) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(binario)
    return (GLB_MAGIC + struct.pack("<II", 2, total)
            + struct.pack("<II", len(js), JSON_CHUNK) + js
            + struct.pack("<II", len(binario), BIN_CHUNK) + binario)


def recomprimir(ruta: Path, lado: int, calidad: int) -> None:
    raw = ruta.read_bytes()
    doc, binario = leer(raw)
    vistas = doc.get("bufferViews", [])
    imagenes = doc.get("images", [])
    if not imagenes:
        print("%s: sin imagenes" % ruta.name); return
    # cada imagen: reescalar y recodificar; las vistas que no son imagen se
    # copian tal cual a un buffer nuevo
    idx_img = {im["bufferView"]: i for i, im in enumerate(imagenes) if "bufferView" in im}
    nuevo = bytearray()
    for vi, v in enumerate(vistas):
        ini = v.get("byteOffset", 0)
        datos = binario[ini:ini + v["byteLength"]]
        if vi in idx_img:
            im = Image.open(io.BytesIO(datos)).convert("RGB")
            if max(im.size) > lado:
                im = im.resize((lado, lado), Image.LANCZOS)
            buf = io.BytesIO()
            im.save(buf, "JPEG", quality=calidad, optimize=True)
            datos = buf.getvalue()
            imagenes[idx_img[vi]]["mimeType"] = "image/jpeg"
        pad = (4 - len(nuevo) % 4) % 4
        nuevo += b"\0" * pad
        v["byteOffset"] = len(nuevo)
        v["byteLength"] = len(datos)
        nuevo += datos
    doc["buffers"][0]["byteLength"] = len(nuevo)
    salida = escribir(doc, bytes(nuevo))
    ruta.write_bytes(salida)
    print("%s: %d -> %d KB" % (ruta.name, len(raw) // 1024, len(salida) // 1024))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lado", type=int, default=1024)
    ap.add_argument("--calidad", type=int, default=85)
    ap.add_argument("archivos", nargs="+")
    a = ap.parse_args()
    for f in a.archivos:
        recomprimir(Path(f), a.lado, a.calidad)


if __name__ == "__main__":
    main()
