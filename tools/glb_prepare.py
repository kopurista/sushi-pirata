#!/usr/bin/env python3
"""Normaliza los GLB que devuelve Ludo (create3DModel) para usarlos en Godot.

Hace falta porque la API tiene dos rarezas comprobadas:

1. Con texture_type="pbr" el .bin que sirve viene GZIPEADO pese a la extension,
   y Godot lo rechaza. Con texture_type="simple" llega sin comprimir. Aqui se
   detecta por el magic (1f 8b) y se descomprime si toca.

2. Con texture_type="simple" el material sale con baseColorFactor [.4,.4,.4,1],
   que multiplica la textura y deja el modelo casi negro en pantalla. Se
   reescribe a [1,1,1,1].

Ademas fuerza metallicFactor=0: los modelos "pbr" vienen con metallic=1, que
bajo GL Compatibility y sin sonda de reflexion tambien oscurece el resultado, y
en low poly no aporta nada.

Uso:  python tools/glb_prepare.py entrada.bin salida.glb
      python tools/glb_prepare.py carpeta_entrada/ carpeta_salida/
      python tools/glb_prepare.py entrada.glb salida.glb strip-normals

strip-normals: borra el atributo NORMAL de todas las primitivas. Godot genera
normales PLANAS cuando faltan (spec glTF), lo que da el facetado tipico del
low poly y arregla las normales corruptas que deja el re-export de rigModel
(el modelo rigueado salia oscuro: solo le llegaba luz ambiente).
"""

import gzip
import json
import struct
import sys
from pathlib import Path

GLB_MAGIC = b"glTF"
GZIP_MAGIC = b"\x1f\x8b"
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942


def read_glb(raw: bytes) -> bytes:
    """Descomprime si hace falta y valida que sea un GLB."""
    if raw[:2] == GZIP_MAGIC:
        raw = gzip.decompress(raw)
    if raw[:4] != GLB_MAGIC:
        raise ValueError("no es un GLB (magic %r)" % raw[:4])
    return raw


def split_chunks(raw: bytes):
    """Devuelve (json_dict, bin_bytes) a partir del GLB."""
    total = struct.unpack("<I", raw[8:12])[0]
    offset = 12
    doc = None
    binary = b""
    while offset < total:
        length, kind = struct.unpack("<II", raw[offset:offset + 8])
        data = raw[offset + 8:offset + 8 + length]
        if kind == JSON_CHUNK:
            doc = json.loads(data)
        elif kind == BIN_CHUNK:
            binary = data
        offset += 8 + length
    if doc is None:
        raise ValueError("el GLB no trae chunk JSON")
    return doc, binary


def patch_materials(doc: dict) -> int:
    """Aclara el color base y quita el metalico. Devuelve cuantos cambio.

    OJO con metallicFactor: en glTF su valor POR DEFECTO es 1.0, no 0.0. El
    material que genera texture_type="simple" omite la clave, asi que queda
    100% metalico y bajo GL Compatibility, sin sonda de reflexion, se renderiza
    NEGRO. Por eso se escribe siempre de forma explicita en vez de solo
    corregirlo cuando ya viene puesto.
    """
    touched = 0
    for mat in doc.get("materials", []):
        pbr = mat.setdefault("pbrMetallicRoughness", {})
        factor = pbr.get("baseColorFactor")
        if factor is not None and factor[:3] != [1.0, 1.0, 1.0]:
            pbr["baseColorFactor"] = [1.0, 1.0, 1.0, factor[3] if len(factor) > 3 else 1.0]
            touched += 1
        if pbr.get("metallicFactor") != 0.0:
            pbr["metallicFactor"] = 0.0
            touched += 1
    return touched


def build_glb(doc: dict, binary: bytes) -> bytes:
    """Reconstruye el GLB con los tamanos y el relleno de alineacion al dia."""
    js = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    js += b" " * (-len(js) % 4)              # relleno con espacios
    binary += b"\x00" * (-len(binary) % 4)   # relleno con ceros

    out = bytearray()
    out += GLB_MAGIC + struct.pack("<I", 2)
    total = 12 + 8 + len(js) + (8 + len(binary) if binary else 0)
    out += struct.pack("<I", total)
    out += struct.pack("<II", len(js), JSON_CHUNK) + js
    if binary:
        out += struct.pack("<II", len(binary), BIN_CHUNK) + binary
    return bytes(out)


def strip_normals(doc: dict) -> int:
    """Quita NORMAL de todas las primitivas; devuelve cuantas toco."""
    n = 0
    for mesh in doc.get("meshes", []):
        for prim in mesh.get("primitives", []):
            if "NORMAL" in prim.get("attributes", {}):
                del prim["attributes"]["NORMAL"]
                n += 1
    return n


def convert(src: Path, dst: Path, drop_normals: bool = False) -> None:
    raw = read_glb(src.read_bytes())
    doc, binary = split_chunks(raw)
    touched = patch_materials(doc)
    stripped = strip_normals(doc) if drop_normals else 0
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(build_glb(doc, binary))
    print("%-34s -> %-34s (%d materiales corregidos, %d normales fuera, %.2f MB)"
          % (src.name, dst.name, touched, stripped, dst.stat().st_size / 1048576))


def main() -> int:
    if len(sys.argv) not in (3, 4):
        print(__doc__)
        return 1
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    drop = len(sys.argv) == 4 and sys.argv[3] == "strip-normals"
    if src.is_dir():
        for f in sorted(list(src.glob("*.glb")) + list(src.glob("*.bin"))):
            convert(f, dst / (f.stem + ".glb"), drop)
    else:
        convert(src, dst, drop)
    return 0


if __name__ == "__main__":
    sys.exit(main())
