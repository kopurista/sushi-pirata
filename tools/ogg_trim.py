# Recorta un .ogg SIN recodificar: se queda con las paginas completas hasta el
# instante pedido, marca la ultima con el flag de fin de flujo (EOS) y le
# recalcula el CRC. El corte cae en un limite de pagina, asi que no hace falta
# tocar ni un bit de audio.
#
#   python tools/ogg_trim.py <origen.ogg> <destino.ogg> <segundos>
#
# Se usó para el lanzamiento de la PESCA: "Casting Line - 4" seguía sonando
# casi un segundo después del plof de la boya (y traía su propio chapoteo al
# final, que sonaba doble). Se dejó en 0.594 s. El instante del corte NO
# se elige a ojo — se saca de la CURVA DE BITRATE por páginas (el chapoteo es
# un estallido de 365 kbps contra los 45 del tramo anterior), que se puede
# leer sin decodificar nada.
import struct, sys

POLY = 0x04C11DB7
TAB = []
for i in range(256):
    r = i << 24
    for _ in range(8):
        r = ((r << 1) ^ POLY) & 0xFFFFFFFF if r & 0x80000000 else (r << 1) & 0xFFFFFFFF
    TAB.append(r)

def crc(buf):
    r = 0
    for b in buf:
        r = ((r << 8) & 0xFFFFFFFF) ^ TAB[((r >> 24) & 0xFF) ^ b]
    return r

def pages(d):
    i = 0
    while i < len(d):
        assert d[i:i+4] == b'OggS'
        nseg = d[i+26]
        segs = d[i+27:i+27+nseg]
        total = 27 + nseg + sum(segs)
        yield dict(off=i, total=total, nseg=nseg, segs=list(segs),
                   flags=d[i+5], gran=struct.unpack('<q', d[i+6:i+14])[0])
        i += total

src, dst, corte = sys.argv[1], sys.argv[2], float(sys.argv[3])
d = open(src, 'rb').read()
sr = struct.unpack('<I', d[27 + d[26] + 12: 27 + d[26] + 16])[0]
lim = int(round(corte * sr))

keep = []
for p in pages(d):
    if p['gran'] > lim:
        break
    keep.append(p)
assert keep, "nada que conservar"
last = keep[-1]
# Un ultimo segmento de 255 significa paquete CONTINUADO en la pagina
# siguiente: sin ella no se puede decodificar, asi que se cae.
assert not (last['segs'] and last['segs'][-1] == 255), "paquete a caballo"

out = bytearray()
for p in keep[:-1]:
    out += d[p['off']:p['off'] + p['total']]
pg = bytearray(d[last['off']:last['off'] + last['total']])
pg[5] |= 0x04                      # EOS
pg[22:26] = b'\x00\x00\x00\x00'    # el CRC se calcula con su campo a cero
pg[22:26] = struct.pack('<I', crc(pg))
out += pg
open(dst, 'wb').write(out)
print(f"{src} -> {dst}: {len(keep)} paginas, {last['gran']/sr:.3f} s "
      f"(era {list(pages(d))[-1]['gran']/sr:.3f} s), {len(out)} bytes")
