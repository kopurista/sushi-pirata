#!/usr/bin/env python3
"""El BANDERIN DEL VIENTO (assets/props/banderin.png).

Un gallardete triangular rojo con una franja crema, dibujado a mano y
supermuestreado: es la tela que ondea en el mastil de los niveles con viento
(mar 2). El shader (banderin.gdshader) lo agita por vertice, asi que aqui solo
va el DIBUJO plano; la punta mira a +X (el asta queda en x=0).

Uso:  python tools/banderin_tex.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

SALIDA = Path("assets/props/banderin.png")
W, H = 256, 128
SS = 4

ROJO = (196, 60, 48, 255)
ROJO_OSCURO = (150, 38, 30, 255)
CREMA = (247, 236, 208, 255)


def main() -> None:
    im = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    w, h = W * SS, H * SS
    # Triangulo: asta a la izquierda (todo el alto), punta a la derecha.
    d.polygon([(0, 0), (w - 1, h // 2), (0, h - 1)], fill=ROJO)
    # Franja crema por el centro, siguiendo la forma.
    d.polygon([(0, int(h * 0.36)), (int(w * 0.72), h // 2),
               (0, int(h * 0.64))], fill=CREMA)
    # Canto superior e inferior en rojo oscuro, para que la tela tenga borde.
    d.line([(0, 2), (w - 1, h // 2)], fill=ROJO_OSCURO, width=SS * 3)
    d.line([(0, h - 3), (w - 1, h // 2)], fill=ROJO_OSCURO, width=SS * 3)
    # Dobladillo del asta.
    d.rectangle([0, 0, SS * 5, h], fill=ROJO_OSCURO)
    im = im.resize((W, H), Image.LANCZOS)
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    im.save(SALIDA)
    print(SALIDA, im.size)


if __name__ == "__main__":
    main()
