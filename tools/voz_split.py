"""Parte UNA toma de voz en las TRES que pide cada expresion, y las deja en OGG.

POR QUE UNA SOLA TOMA: el encargo son 3 sonidos por expresion y hay 63
expresiones en el reparto, o sea 189 clips. Pedirlos de uno en uno son 189
generaciones; pidiendo las tres interjecciones EN LA MISMA llamada y partiendo
por el silencio salen 63. Y no es solo ahorro: las tres salen de la misma
generacion, con la misma voz y la misma emocion, asi que no pueden desencajar
entre ellas.

EL CORTE NO PUEDE SER "UN TROZO POR SILENCIO": el motor de voz mete pausas
DENTRO de una interjeccion -"Ja, ja, ja" salen tres trozos-, asi que de una
toma de tres frases pueden salir cinco o seis. Lo que se hace es cortar por
todos los silencios y despues FUNDIR los huecos mas CORTOS hasta quedarse con
tres: los huecos de dentro de una risa miden menos que los que separan una
frase de la siguiente. Medido en la toma de prueba: 0,29-0,33 s por dentro
contra 0,36-0,44 s entre frases.

Si aun asi no salen tres, la toma se marca como FALLIDA y no se escribe nada:
mejor volver a generarla que dejar media risa suelta en el juego.

Uso:  python tools/voz_split.py <lote.tsv>
      lote.tsv = personaje<TAB>expresion<TAB>url   (una linea por expresion)
"""
import os
import re
import subprocess
import sys
import urllib.request

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESTINO = os.path.join(RAIZ, "sounds", "juego", "voces")

# ESCALERA DE UMBRALES del detector, de mas exigente a menos. -35 dB deja
# fuera el ruido de fondo del sintetizador sin comerse el final de una vocal
# apagada, y es el que sirve para 58 de las 63 tomas; pero una RISA encadenada
# ("jajaja jojojo jaja") o un GRUNIDO de criatura no bajan tanto entre golpe y
# golpe, y a -35 salen de una pieza. Se prueba de arriba abajo y se toma el
# PRIMERO que devuelva tres tramos o mas: asi la mayoria se corta con el
# umbral limpio y solo las tomas pegadas suben a uno mas permisivo.
#
# Si NINGUNO llega a tres, la toma es de verdad un sonido continuo (le paso a
# dos rugidos del Kappa, que salieron como un bramido seguido) y hay que
# volver a generarla pidiendo la separacion: partir por partes iguales daria
# tres trozos cortados a media vocal.
RUIDOS = ["-35dB", "-30dB", "-25dB", "-20dB"]
HUECO = 0.12
# Colchon que se deja a cada lado del trozo: cortar clavado en el umbral se
# come el ataque de la consonante y la cola de la vocal.
AIRE = 0.06
TOMAS = 3

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ludo_audio import _ffmpeg, PERFILES  # noqa: E402


def _silencios(mp3, ruido):
    """Tramos de silencio (inicio, fin) que encuentra ffmpeg en la toma."""
    out = subprocess.run(
        [_ffmpeg(), "-hide_banner", "-i", mp3, "-af",
         "silencedetect=noise=%s:d=%s" % (ruido, HUECO), "-f", "null", "-"],
        capture_output=True, text=True).stderr
    ini = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", out)]
    fin = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", out)]
    return ini, fin


def _duracion(mp3):
    out = subprocess.run([_ffmpeg(), "-hide_banner", "-i", mp3],
                         capture_output=True, text=True).stderr
    m = re.search(r"Duration: (\d+):(\d+):([\d.]+)", out)
    if not m:
        return 0.0
    return int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))


def trozos(mp3):
    """Los TOMAS tramos con voz de la toma, ya fundidos."""
    dur = _duracion(mp3)
    for ruido in RUIDOS:
        voz = _tramos(mp3, ruido, dur)
        if voz:
            return voz
    return []


def _tramos(mp3, ruido, dur):
    ini, fin = _silencios(mp3, ruido)
    # De los silencios salen los tramos con voz: lo que queda entre uno y otro.
    voz = []
    cursor = 0.0
    for a, b in zip(ini, fin + [dur] * (len(ini) - len(fin))):
        if a - cursor > 0.02:
            voz.append([cursor, a])
        cursor = b
    if dur - cursor > 0.02:
        voz.append([cursor, dur])
    if len(voz) < TOMAS:
        return []
    # FUNDIR LOS HUECOS MAS CORTOS: los de dentro de una risa miden menos que
    # los que separan dos frases.
    while len(voz) > TOMAS:
        huecos = [voz[i + 1][0] - voz[i][1] for i in range(len(voz) - 1)]
        i = huecos.index(min(huecos))
        voz[i][1] = voz[i + 1][1]
        del voz[i + 1]
    return voz


def partir(personaje, expresion, url):
    carpeta = os.path.join(DESTINO, personaje)
    os.makedirs(carpeta, exist_ok=True)
    mp3 = os.path.join(carpeta, "_%s.mp3" % expresion)
    urllib.request.urlretrieve(url, mp3)
    voz = trozos(mp3)
    if not voz:
        os.remove(mp3)
        return 0
    dur = _duracion(mp3)
    total = 0
    for i, (a, b) in enumerate(voz):
        a = max(0.0, a - AIRE)
        b = min(dur, b + AIRE)
        dst = os.path.join(carpeta, "%s_%d.ogg" % (expresion, i + 1))
        subprocess.run([_ffmpeg(), "-v", "error", "-y", "-ss", str(a),
                        "-t", str(b - a), "-i", mp3] + PERFILES["voz"] + [dst],
                       check=True)
        total += os.path.getsize(dst)
    os.remove(mp3)
    return total


def main():
    fallos = []
    total = 0
    for linea in open(sys.argv[1], encoding="utf-8"):
        linea = linea.strip()
        if not linea or linea.startswith("#"):
            continue
        pers, expr, url = linea.split("\t")
        n = partir(pers, expr, url)
        if n == 0:
            fallos.append("%s/%s" % (pers, expr))
            print("FALLO   %s/%s" % (pers, expr))
        else:
            total += n
    print("TOTAL %.2f MB" % (total / 1048576.0))
    if fallos:
        print("REGENERAR: %s" % ", ".join(fallos))


if __name__ == "__main__":
    main()
