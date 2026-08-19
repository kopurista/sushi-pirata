# -*- coding: utf-8 -*-
"""Hornea la CAPA DE ESPUMA del agua estilo Wind Waker a una textura.

El shader de referencia ("Wind Waker style water - NekotoArts",
godotshaders.com/shader/wind-waker-water-no-textures-needed) construye la
espuma sumando SETENTA Y CINCO circulos por pixel, y la llama DOS veces por
fragmento: unas 2.500 operaciones por pixel solo para el agua. En un movil, con
el mar cubriendo la pantalla entera, eso se lleva el presupuesto de fotograma
del juego.

La forma de la espuma NO depende del tiempo: es un patron fijo en el espacio
UV, y ademas TILEA solo (el `min(c, 1.0 - c)` del original envuelve la
distancia). Asi que se hornea una vez aqui y el shader la lee con un texture().
Mismos circulos, mismo dibujo, dos accesos a textura en vez de dos mil
operaciones.

    python tools/foam_ww.py
"""
import math
from PIL import Image

SIZE = 1024
BORDE = 0.002  # el smoothstep del original
# LOS CIRCULOS SE HINCHAN respecto al original. El dibujo es "todo blanco MENOS
# los circulos", y con los radios tal cual el blanco sale al 15,6% de la
# superficie: con el mar cubriendo la pantalla entera, tanta espuma se lee como
# una RED de lineas blancas. MEDIDO: 1.00 -> 15,6% | 1.05 -> 11,4% |
# 1.12 -> 6,5%. Los circulos estan al borde de la PERCOLACION, asi que un pelo
# de radio se lleva por delante la mitad del blanco (no subirlo a ojo) — y ahi
# esta la gracia: pasado el punto de rotura, la red se parte en manchas SUELTAS
# con mar liso entre ellas, que es lo que hace que parezca que hay poca espuma.
# A 1.11 todavia hace red; a 1.14 ya son manchas separadas.
RADIO_MULT = 1.14

# Los 75 circulos del shader, tal cual: (x, y, s) con radio = sqrt(s).
CIRCULOS = [
    (0.37378, 0.277169, 0.0268181), (0.0317477, 0.540372, 0.0193742),
    (0.430044, 0.882218, 0.0232337), (0.641033, 0.695106, 0.0117864),
    (0.0146398, 0.0791346, 0.0299458), (0.43871, 0.394445, 0.0289087),
    (0.909446, 0.878141, 0.028466), (0.310149, 0.686637, 0.0128496),
    (0.928617, 0.195986, 0.0152041), (0.0438506, 0.868153, 0.0268601),
    (0.308619, 0.194937, 0.00806102), (0.349922, 0.449714, 0.00928667),
    (0.0449556, 0.953415, 0.023126), (0.117761, 0.503309, 0.0151272),
    (0.563517, 0.244991, 0.0292322), (0.566936, 0.954457, 0.00981141),
    (0.0489944, 0.200931, 0.0178746), (0.569297, 0.624893, 0.0132408),
    (0.298347, 0.710972, 0.0114426), (0.878141, 0.771279, 0.00322719),
    (0.150995, 0.376221, 0.00216157), (0.119673, 0.541984, 0.0124621),
    (0.629598, 0.295629, 0.0198736), (0.334357, 0.266278, 0.0187145),
    (0.918044, 0.968163, 0.0182928), (0.965445, 0.505026, 0.006348),
    (0.514847, 0.865444, 0.00623523), (0.710575, 0.0415131, 0.00322689),
    (0.71403, 0.576945, 0.0215641), (0.748873, 0.413325, 0.0110795),
    (0.0623365, 0.896713, 0.0236203), (0.980482, 0.473849, 0.00573439),
    (0.647463, 0.654349, 0.0188713), (0.651406, 0.981297, 0.00710875),
    (0.428928, 0.382426, 0.0298806), (0.811545, 0.62568, 0.00265539),
    (0.400787, 0.74162, 0.00486609), (0.331283, 0.418536, 0.00598028),
    (0.894762, 0.0657997, 0.00760375), (0.525104, 0.572233, 0.0141796),
    (0.431526, 0.911372, 0.0213234), (0.658212, 0.910553, 0.000741023),
    (0.514523, 0.243263, 0.0270685), (0.0249494, 0.252872, 0.00876653),
    (0.502214, 0.47269, 0.0234534), (0.693271, 0.431469, 0.0246533),
    (0.415, 0.884418, 0.0271696), (0.149073, 0.41204, 0.00497198),
    (0.533816, 0.897634, 0.00650833), (0.0409132, 0.83406, 0.0191398),
    (0.638585, 0.646019, 0.0206129), (0.660342, 0.966541, 0.0053511),
    (0.513783, 0.142233, 0.00471653), (0.124305, 0.644263, 0.00116724),
    (0.99871, 0.583864, 0.0107329), (0.894879, 0.233289, 0.00667092),
    (0.246286, 0.682766, 0.00411623), (0.0761895, 0.16327, 0.0145935),
    (0.949386, 0.802936, 0.0100873), (0.480122, 0.196554, 0.0110185),
    (0.896854, 0.803707, 0.013969), (0.292865, 0.762973, 0.00566413),
    (0.0995585, 0.117457, 0.00869407), (0.377713, 0.00335442, 0.0063147),
    (0.506365, 0.531118, 0.0144016), (0.408806, 0.894771, 0.0243923),
    (0.143579, 0.85138, 0.00418529), (0.0902811, 0.181775, 0.0108896),
    (0.780695, 0.394644, 0.00475475), (0.298036, 0.625531, 0.00325285),
    (0.218423, 0.714537, 0.00157212), (0.658836, 0.159556, 0.00225897),
    (0.987324, 0.146545, 0.0288391), (0.222646, 0.251694, 0.00092276),
    (0.159826, 0.528063, 0.00605293),
]


def hornear():
    # El original parte de 1.0 y RESTA cada circulo (circ devuelve -1 dentro),
    # rematando con max(ret, 0): o sea, blanco menos los agujeros.
    acc = [1.0] * (SIZE * SIZE)
    inv = 1.0 / SIZE
    for cx, cy, s in CIRCULOS:
        r = math.sqrt(s) * RADIO_MULT
        # Caja del circulo, con dos texels de margen para el borde suave.
        rad_px = int(math.ceil(r * SIZE)) + 2
        px0 = int(cx * SIZE) - rad_px
        py0 = int(cy * SIZE) - rad_px
        for py in range(py0, py0 + 2 * rad_px + 1):
            fy = ((py % SIZE) + 0.5) * inv
            dy = abs(fy - cy)
            dy = min(dy, 1.0 - dy)
            if dy > r + 0.004:
                continue
            fila = (py % SIZE) * SIZE
            for px in range(px0, px0 + 2 * rad_px + 1):
                fx = ((px % SIZE) + 0.5) * inv
                dx = abs(fx - cx)
                dx = min(dx, 1.0 - dx)
                d = math.sqrt(dx * dx + dy * dy)
                t = (r - d) / BORDE
                if t <= 0.0:
                    continue
                if t >= 1.0:
                    v = 1.0
                else:
                    v = t * t * (3.0 - 2.0 * t)
                acc[fila + (px % SIZE)] -= v
    datos = []
    for v in acc:
        c = 0 if v <= 0.0 else (255 if v >= 1.0 else int(v * 255.0 + 0.5))
        datos.append((c, c, c))
    img = Image.new("RGB", (SIZE, SIZE))
    img.putdata(datos)
    img.save("assets/map/espuma_ww.webp", "WEBP", quality=96, method=6)
    print("assets/map/espuma_ww.webp")


if __name__ == "__main__":
    hornear()
