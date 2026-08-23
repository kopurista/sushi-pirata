# -*- coding: utf-8 -*-
"""Deja las voces CORTAS, y reconstruye las de Gigi desde su grabacion.

LAS VOCES DEL JUEGO SON INTERJECCIONES QUE ACOMPAÑAN A UNA LINEA DE DIALOGO,
no la leen (pedido por el usuario). Y salen cada vez que se pasa de linea, o
sea a toques: una toma de segundo y medio se pisa con la siguiente y acaba
sonando como si el personaje hablara de verdad. Se cortan todas a `MAX_S` con
un fundido de salida, que es lo que hace que el corte no se oiga.

LAS DEL PACK HUMANO NO SE TOCAN AQUI: se rehacen desde el .wav original con
`tools/voces_humanas.py`, que ya corta al convertir, asi que el archivo del
juego sigue siendo de primera generacion. Aqui entran solo las que NO tienen
original a mano (Cai y el Kappa, generados en su dia) y GIGI, que si lo tiene.

GIGI ES CASO APARTE (pedido por el usuario: mas volumen y sin el ruido de
fondo). Sus doce graznidos salian de `gigi.wav`, una grabacion del propio
usuario a 96 kHz, y se habian quedado en -13/-15 dBFS de pico —flojisimos al
lado del resto— y con el siseo de la sala debajo. Se rehacen desde el original:
    · pasa-altos a 200 Hz, que se lleva el retumbe del cuarto sin tocar el
      graznido, que es todo agudo;
    · `afftdn`, el reductor de ruido por FFT, contra el siseo;
    · y CADA graznido se normaliza POR SEPARADO a `PICO_GIGI`. Normalizar la
      grabacion entera no valdria: entre un graznido y otro hay 10 dB de
      diferencia, y lo que se oye repetido es cada uno por su cuenta.
Son seis tomas para doce huecos, asi que se repiten — a proposito, ya estaba
decidido: el loro de verdad repetido suena mejor que una voz generada.

    python tools/voces_afinar.py --cortar cai kappa
    python tools/voces_afinar.py --sanear cai kappa
    python tools/voces_afinar.py --gigi
"""
import os
import re
import subprocess
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ludo_audio import _ffmpeg, PERFILES  # noqa: E402

VOCES = os.path.join(RAIZ, "sounds", "juego", "voces")

## El mismo corte que aplica `voces_humanas.py`.
MAX_S = 0.50
FADE_S = 0.09

GIGI_SRC = os.path.join(RAIZ, "sounds", "Sin utilizar", "soundly", "gigi.wav")
## Pico al que se lleva cada graznido. No se sube a 0: un pico exacto en el
## techo se recorta al codificar a Vorbis, que puede pasarse un pelo.
PICO_GIGI = -3.5
GIGI_TOMAS = 3
## QUE GRAZNIDO LE TOCA A CADA HUMOR. Son seis tomas para doce huecos, asi que
## se repiten — ya estaba decidido y esta bien: el loro de verdad repetido
## suena mejor que una voz generada. Pero el reparto NO puede ser "los tres
## primeros, los tres siguientes, y vuelta a empezar": asi dos humores salen
## con LOS MISMOS TRES archivos y son indistinguibles. Cada humor lleva un
## trio distinto.
GIGI_MOODS = {
    "loro": [0, 1, 2],
    "loro_grito": [3, 4, 5],
    "loro_resignado": [1, 3, 5],
    "loro_sorpresa": [0, 2, 4],
}


def _fade():
    return "afade=t=out:st=%.3f:d=%.3f" % (MAX_S - FADE_S, FADE_S)


def _pico(ruta):
    o = subprocess.run([_ffmpeg(), "-hide_banner", "-i", ruta, "-af",
                        "volumedetect", "-f", "null", "-"],
                       capture_output=True, text=True).stderr
    m = re.search(r"max_volume: (-?[\d.]+) dB", o)
    return float(m.group(1)) if m else 0.0


def _dur(ruta):
    o = subprocess.run([_ffmpeg(), "-hide_banner", "-i", ruta],
                       capture_output=True, text=True).stderr
    m = re.search(r"Duration: (\d+):(\d+):([\d.]+)", o)
    return (int(m.group(2)) * 60 + float(m.group(3))) if m else 0.0


def cortar(personajes):
    """Recorta EN EL SITIO los .ogg de esos personajes."""
    for pers in personajes:
        d = os.path.join(VOCES, pers)
        if not os.path.isdir(d):
            print("no existe:", pers)
            continue
        tocados = 0
        for f in sorted(os.listdir(d)):
            if not f.endswith(".ogg"):
                continue
            ruta = os.path.join(d, f)
            if _dur(ruta) <= MAX_S + 0.01:
                continue
            tmp = ruta + ".tmp.ogg"
            subprocess.run([_ffmpeg(), "-v", "error", "-y", "-i", ruta,
                            "-af", _fade(), "-t", "%.3f" % MAX_S]
                           + PERFILES["voz"] + [tmp], check=True)
            os.replace(tmp, ruta)
            tocados += 1
        print("%-8s %d clips recortados a %.2f s" % (pers, tocados, MAX_S))


def gigi():
    if not os.path.isfile(GIGI_SRC):
        raise SystemExit("No encuentro %s" % GIGI_SRC)
    tmpd = os.path.join(RAIZ, "_gigi_tmp")
    os.makedirs(tmpd, exist_ok=True)
    limpio = os.path.join(tmpd, "limpio.wav")
    subprocess.run([_ffmpeg(), "-v", "error", "-y", "-i", GIGI_SRC, "-af",
                    "highpass=f=200,afftdn=nr=24:nf=-38", "-ac", "1",
                    "-ar", "48000", limpio], check=True)
    o = subprocess.run([_ffmpeg(), "-hide_banner", "-i", limpio, "-af",
                        "silencedetect=noise=-40dB:d=0.10", "-f", "null", "-"],
                       capture_output=True, text=True).stderr
    ini = [float(x) for x in re.findall(r"silence_start: ([\d.-]+)", o)]
    fin = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", o)]
    total = _dur(limpio)
    trozos, cursor = [], 0.0
    for i, a in enumerate(ini):
        if a - cursor > 0.08:
            trozos.append((max(0.0, cursor - 0.02), a + 0.05))
        cursor = fin[i] if i < len(fin) else total
    if total - cursor > 0.08:
        trozos.append((max(0.0, cursor - 0.02), total))
    if not trozos:
        raise SystemExit("No he sabido separar los graznidos.")
    print("graznidos encontrados:", len(trozos))
    piezas = []
    for i, (a, b) in enumerate(trozos, 1):
        p = os.path.join(tmpd, "g%d.wav" % i)
        subprocess.run([_ffmpeg(), "-v", "error", "-y", "-ss", "%.3f" % a,
                        "-t", "%.3f" % (b - a), "-i", limpio, p], check=True)
        piezas.append(p)
    destino = os.path.join(VOCES, "gigi")
    os.makedirs(destino, exist_ok=True)
    for mood in sorted(GIGI_MOODS):
        for k, idx in enumerate(GIGI_MOODS[mood][:GIGI_TOMAS], 1):
            src = piezas[idx % len(piezas)]
            ganancia = PICO_GIGI - _pico(src)
            dst = os.path.join(destino, "%s_%d.ogg" % (mood, k))
            subprocess.run([_ffmpeg(), "-v", "error", "-y", "-i", src, "-af",
                            "volume=%.2fdB,%s" % (ganancia, _fade()),
                            "-t", "%.3f" % MAX_S]
                           + PERFILES["voz"] + [dst], check=True)
            print("  %-22s de g%d  %+5.1f dB  %6d B"
                  % (os.path.basename(dst), idx % len(piezas) + 1, ganancia,
                     os.path.getsize(dst)))
    for f in os.listdir(tmpd):
        os.remove(os.path.join(tmpd, f))
    os.rmdir(tmpd)


## Por debajo de esto, una toma no es una voz: es aire. VA BAJO A PROPOSITO
## (-30 y no -20): con el listón alto se cargó una toma del Kappa que era
## floja pero de verdad, media palmada de 0,51 s, y sustituirla por otra le
## quitó una voz distinta a ese humor. Lo que se busca aquí es lo MUERTO, y lo
## flojo ya lo arregla la igualación de volumen de abajo.
PICO_MUDO = -30.0
DUR_MUDA = 0.12
## Pico al que se llevan las voces saneadas. El pack humano viene practicamente
## a cero, asi que este es el listón para que unas no suenen al lado de otras.
PICO_VOZ = -2.0


def sanear(personajes):
    """Tapa las tomas MUDAS y iguala el volumen de ese personaje.

    LAS TOMAS MUDAS SON UN FALLO DE ORIGEN, no del recorte: `voz_split.py`
    parte cada generacion en tres, y cuando el motor de voz dejo una pausa
    larga al final, el tercer trozo salio siendo esa pausa — 0,06 s a -91
    dBFS. En el juego eso es que UNA DE CADA TRES VECES que ese personaje
    habla no suena nada, y como el sorteo es al azar se vive como que el audio
    va y viene. Se tapan copiando la mejor toma de SU MISMO humor: no se
    inventa nada y el personaje deja de callarse a medias.
    """
    for pers in personajes:
        d = os.path.join(VOCES, pers)
        if not os.path.isdir(d):
            print("no existe:", pers)
            continue
        moods = {}
        for f in sorted(os.listdir(d)):
            if not f.endswith(".ogg"):
                continue
            mood = f.rsplit("_", 1)[0]
            moods.setdefault(mood, []).append(os.path.join(d, f))
        mudas = 0
        for mood, rutas in sorted(moods.items()):
            estado = [(r, _pico(r), _dur(r)) for r in rutas]
            buenas = [e for e in estado
                      if e[1] > PICO_MUDO and e[2] >= DUR_MUDA]
            if not buenas:
                print("  %s/%s: TODAS mudas, no toco nada" % (pers, mood))
                continue
            mejor = max(buenas, key=lambda e: e[1])[0]
            for r, pico, dur in estado:
                if pico > PICO_MUDO and dur >= DUR_MUDA:
                    continue
                with open(mejor, "rb") as o, open(r, "wb") as dst:
                    dst.write(o.read())
                print("  %s <- %s (era %.1f dBFS, %.2f s)"
                      % (os.path.basename(r), os.path.basename(mejor), pico,
                         dur))
                mudas += 1
        igualadas = 0
        for f in sorted(os.listdir(d)):
            if not f.endswith(".ogg"):
                continue
            r = os.path.join(d, f)
            g = PICO_VOZ - _pico(r)
            if abs(g) < 1.0:
                continue
            tmp = r + ".tmp.ogg"
            subprocess.run([_ffmpeg(), "-v", "error", "-y", "-i", r, "-af",
                            "volume=%.2fdB" % g] + PERFILES["voz"] + [tmp],
                           check=True)
            os.replace(tmp, r)
            igualadas += 1
        print("%-8s %d tomas mudas tapadas, %d igualadas a %.1f dBFS"
              % (pers, mudas, igualadas, PICO_VOZ))


def main():
    args = sys.argv[1:]
    if not args:
        raise SystemExit(__doc__)
    if args[0] == "--cortar":
        cortar(args[1:])
    elif args[0] == "--sanear":
        sanear(args[1:])
    elif args[0] == "--gigi":
        gigi()
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
