"""Parte un audio por sus SILENCIOS y deja cada trozo en OGG.

Lo necesitan las tomas que vienen con VARIOS sonidos dentro de un mismo
archivo: "cortar.wav" trae once golpes de cuchillo seguidos y el sprite de
enrollar la esterilla trae dos. Del archivo entero solo se puede sacar UN
sonido; partido, sale una familia con la que el juego puede sortear sin
repetir y el gesto deja de sonar a bucle de maquina.

ES EL HERMANO GENERICO DE `voz_split.py`, que hace lo mismo pero para las
voces: aquel FUERZA exactamente tres tomas (fundiendo los huecos mas cortos,
porque una risa se parte por dentro) y escribe en `sounds/voces`. Este saca
las que haya y escribe donde se le diga.

LOS TROZOS DEMASIADO CORTOS SE TIRAN (`--min`): un golpe de cuchillo dura
~85 ms, pero entre golpe y golpe quedan colas de 16 ms que el detector cuenta
como sonido y que en el juego no se oirian mas que como un clic sucio.

Uso:
    python tools/audio_split.py <origen> <destino_sin_numero> [opciones]
        --ruido -38dB   umbral por debajo del cual es silencio
        --hueco 0.15    silencio minimo (s) para considerarlo separacion
        --min 0.04      duracion minima (s) de un trozo para conservarlo
        --max 0         cuantos trozos como mucho (0 = todos)
        --perfil efecto perfil de codificacion de ludo_audio.py

Ejemplo:
    python tools/audio_split.py "sounds/soundly/cortar.wav" sounds/juego/cocina/corte
    -> sounds/juego/cocina/corte_1.ogg ... corte_9.ogg
"""
import os
import re
import subprocess
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ludo_audio import _ffmpeg, PERFILES  # noqa: E402

## Colchon a cada lado del trozo: cortar clavado en el umbral se come el
## ataque del golpe, que es justo lo que le da el punch.
AIRE = 0.02


def _duracion(src):
    out = subprocess.run([_ffmpeg(), "-hide_banner", "-i", src],
                         capture_output=True, text=True).stderr
    m = re.search(r"Duration: (\d+):(\d+):([\d.]+)", out)
    if not m:
        return 0.0
    return int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))


def tramos(src, ruido, hueco, minimo):
    """Los tramos CON sonido del archivo, en segundos."""
    out = subprocess.run(
        [_ffmpeg(), "-hide_banner", "-i", src, "-af",
         "silencedetect=noise=%s:d=%s" % (ruido, hueco), "-f", "null", "-"],
        capture_output=True, text=True).stderr
    ini = [float(x) for x in re.findall(r"silence_start: ([\d.-]+)", out)]
    fin = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", out)]
    dur = _duracion(src)
    trozos = []
    cursor = 0.0
    for i, a in enumerate(ini):
        if a - cursor > 0.001:
            trozos.append((cursor, a))
        cursor = fin[i] if i < len(fin) else dur
    if dur - cursor > 0.001:
        trozos.append((cursor, dur))
    return [t for t in trozos if t[1] - t[0] >= minimo], dur


def partir(src, destino, ruido="-38dB", hueco=0.15, minimo=0.04, tope=0,
           perfil="efecto"):
    origen = src if os.path.isabs(src) else os.path.join(RAIZ, src)
    base = destino if os.path.isabs(destino) else os.path.join(RAIZ, destino)
    os.makedirs(os.path.dirname(base), exist_ok=True)
    trozos, dur = tramos(origen, ruido, hueco, minimo)
    if tope > 0:
        trozos = trozos[:tope]
    total = 0
    for i, (a, b) in enumerate(trozos, 1):
        a = max(0.0, a - AIRE)
        b = min(dur, b + AIRE)
        dst = "%s_%d.ogg" % (base, i)
        subprocess.run([_ffmpeg(), "-v", "error", "-y", "-ss", str(a),
                        "-t", str(b - a), "-i", origen]
                       + PERFILES[perfil] + [dst], check=True)
        n = os.path.getsize(dst)
        total += n
        print("  %-40s %6.3f s  %6d B" % (os.path.basename(dst), b - a, n))
    print("%s -> %d trozos, %d B" % (os.path.basename(origen), len(trozos),
                                     total))
    return len(trozos)


def main():
    args = sys.argv[1:]
    if len(args) < 2:
        raise SystemExit(__doc__)
    op = {"ruido": "-38dB", "hueco": 0.15, "minimo": 0.04, "tope": 0,
          "perfil": "efecto"}
    claves = {"--ruido": ("ruido", str), "--hueco": ("hueco", float),
              "--min": ("minimo", float), "--max": ("tope", int),
              "--perfil": ("perfil", str)}
    i = 2
    while i < len(args) - 1:
        if args[i] in claves:
            k, conv = claves[args[i]]
            op[k] = conv(args[i + 1])
            i += 2
        else:
            i += 1
    partir(args[0], args[1], op["ruido"], op["hueco"], op["minimo"],
           op["tope"], op["perfil"])


if __name__ == "__main__":
    main()
