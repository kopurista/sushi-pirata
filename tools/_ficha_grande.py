"""Hoja de revision de UN personaje a tamano nativo: arriba las cuatro vistas
del cuerpo y abajo los tres primeros planos de la mano."""
import sys, os
from PIL import Image, ImageDraw
p = sys.argv[1]
d = "_gen/la4/fichas/"
cuerpo = [d + "%s_v5.png_%d.png" % (p, i) for i in range(4)]
mano = [d + "%s_v5_mano.png_%d.png" % (p, i) for i in range(3)]
cu = [Image.open(f).convert("RGB") for f in cuerpo if os.path.exists(f)]
ma = [Image.open(f).convert("RGB") for f in mano if os.path.exists(f)]
w = sum(i.width for i in cu)
h = cu[0].height + (ma[0].height if ma else 0)
o = Image.new("RGB", (w, h), (255, 255, 255))
x = 0
for i in cu:
    o.paste(i, (x, 0)); x += i.width
x = 0
for i in ma:
    o.paste(i, (x, cu[0].height)); x += i.width
ImageDraw.Draw(o).text((10, 8), p.upper(), fill=(255, 255, 255))
o.save(d + "%s_grande.png" % p)
print(d + "%s_grande.png" % p, o.size)
