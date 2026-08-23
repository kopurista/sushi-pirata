"""Descarga audio de Ludo y lo deja en OGG dentro del proyecto.

LUDO SOLO DEVUELVE MP3 (ninguno de sus endpoints de audio tiene parametro de
formato), y a 192 kbps ESTEREO -256 en las voces-, que para un juego movil es
el triple de lo que hace falta. Aqui se convierte a OGG Vorbis, y no es solo
por el peso:

  * PESO, medido sobre las tres familias reales: musica 1.290 -> 720 KB (-44%),
    voz 143 -> 26 KB (-82%), efecto 25,7 -> 9,6 KB (-63%). Sobre el encargo
    entero son ~25 MB en MP3 contra ~11 MB en OGG.
  * BUCLE LIMPIO: el MP3 lleva relleno del codificador al principio y al final,
    asi que una musica en bucle deja un hueco audible en cada vuelta. El OGG
    no, y ademas `SoundBank.loop_on` ya esta escrito contra
    `AudioStreamOggVorbis`: con MP3 habria que duplicar ese camino.
  * MONO donde no hay nada que separar. Una voz o un golpe de cuchillo no
    tienen imagen estereo, asi que el segundo canal es peso regalado. Solo la
    MUSICA y el AMBIENTE se quedan en estereo.

FFMPEG NO SE INSTALA: el equipo ya tiene varios (CapCut, Twitch Leecher,
DownloadHelper...). `_ffmpeg()` busca el primero que sepa codificar Vorbis, asi
que si desaparece uno la herramienta sigue funcionando con otro.

Y ADEMAS PONE EN MONO lo que se saca de las librerias compradas. Esas tomas
vienen en ESTEREO a 151-243 kbps, que para un clic de interfaz o un golpe de
cuchillo -sonidos sin ninguna imagen estereo, y que en un movil salen por un
altavoz solo- es peso regalado. Medido sobre las copias del juego: se quedan
en el 40% con la misma calidad util. Los archivos que YA son mono no se tocan,
para no meterles una segunda generacion de perdida a cambio de nada.

Uso:
    python tools/ludo_audio.py <perfil> <destino.ogg> <url>
    python tools/ludo_audio.py --lote lote.tsv     (perfil<TAB>destino<TAB>url)
    python tools/ludo_audio.py --mono <carpeta>    (pasa a mono lo que sea estereo)
    python tools/ludo_audio.py --local <perfil> <origen> <destino.ogg>

Perfiles: musica (estereo q3) | ambiente (estereo q2) | efecto (mono q2)
          voz (mono q1 32 kHz)
"""
import os
import subprocess
import sys
import urllib.request

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Perfil -> argumentos de codificacion. La calidad se elige por lo que hay que
# conservar en cada familia, no por un numero global.
PERFILES = {
    "musica":   ["-c:a", "libvorbis", "-q:a", "3", "-ar", "44100"],
    "ambiente": ["-c:a", "libvorbis", "-q:a", "2", "-ar", "44100"],
    "efecto":   ["-c:a", "libvorbis", "-q:a", "2", "-ac", "1", "-ar", "44100"],
    "voz":      ["-c:a", "libvorbis", "-q:a", "1", "-ac", "1", "-ar", "32000"],
}

CANDIDATOS = [
    r"C:\Program Files\DownloadHelper CoApp\ffmpeg.exe",
    r"C:\Program Files\Virtual Desktop Streamer\ffmpeg.exe",
    r"C:\Program Files\Twitch Leecher\ffmpeg.exe",
    "ffmpeg",
]

_cache = []


def _ffmpeg():
    """El primer ffmpeg del equipo que sepa codificar Vorbis."""
    if _cache:
        return _cache[0]
    for c in CANDIDATOS:
        try:
            out = subprocess.run([c, "-encoders"], capture_output=True,
                                 text=True, timeout=30).stdout
        except Exception:
            continue
        if "libvorbis" in out:
            _cache.append(c)
            return c
    raise SystemExit("No hay ningun ffmpeg con libvorbis en el equipo.")


def traer(perfil, destino, url, recortar=None):
    """Descarga `url` y la deja convertida en `destino` (ruta del proyecto).

    `recortar` son segundos a quitar del principio, para las tomas que vienen
    con silencio delante (las voces sobre todo).
    """
    if perfil not in PERFILES:
        raise SystemExit("Perfil desconocido: %s" % perfil)
    dst = destino if os.path.isabs(destino) else os.path.join(RAIZ, destino)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    tmp = dst + ".mp3"
    urllib.request.urlretrieve(url, tmp)
    cmd = [_ffmpeg(), "-v", "error", "-y"]
    if recortar:
        cmd += ["-ss", str(recortar)]
    cmd += ["-i", tmp]
    # Quita el silencio de los extremos: las tomas de Ludo vienen con cola, y
    # en un efecto que se dispara mil veces ese retardo se oye como lag.
    #
    # EL AMBIENTE NO SE TOCA: viene de `createAmbiance` con los extremos ya
    # casados para que el bucle no se note, y recortarlos los descuadra.
    if perfil != "ambiente":
        cmd += ["-af", "silenceremove=start_periods=1:start_threshold=-50dB:"
                "start_silence=0.02:detection=peak,areverse,"
                "silenceremove=start_periods=1:start_threshold=-50dB:"
                "start_silence=0.05:detection=peak,areverse"]
    cmd += PERFILES[perfil] + [dst]
    subprocess.run(cmd, check=True)
    os.remove(tmp)
    return os.path.getsize(dst)


def _canales(ruta):
    out = subprocess.run([_ffmpeg(), "-hide_banner", "-i", ruta],
                         capture_output=True, text=True).stderr
    if "stereo" in out:
        return 2
    return 1


def a_mono(carpeta):
    """Pasa a mono los .ogg ESTEREO de una carpeta (los mono se dejan)."""
    raiz = carpeta if os.path.isabs(carpeta) else os.path.join(RAIZ, carpeta)
    antes = 0
    despues = 0
    tocados = 0
    for nombre in sorted(os.listdir(raiz)):
        if not nombre.endswith(".ogg"):
            continue
        ruta = os.path.join(raiz, nombre)
        n0 = os.path.getsize(ruta)
        antes += n0
        if _canales(ruta) < 2:
            despues += n0
            continue
        tmp = ruta + ".tmp.ogg"
        subprocess.run([_ffmpeg(), "-v", "error", "-y", "-i", ruta,
                        "-c:a", "libvorbis", "-q:a", "3", "-ac", "1",
                        "-ar", "44100", tmp], check=True)
        os.replace(tmp, ruta)
        despues += os.path.getsize(ruta)
        tocados += 1
    print("%s: %d de %d en mono | %d -> %d B (%d%%)"
          % (carpeta, tocados, len(os.listdir(raiz)), antes, despues,
             100 * despues // max(antes, 1)))


def local(perfil, origen, destino, filtros=None, dura=0.0):
    """Convierte un archivo del disco con uno de los perfiles del juego.

    `filtros` son filtros de ffmpeg que se AÑADEN a la cadena (el recorte de
    silencios va siempre delante), y `dura` corta el resultado a esos
    segundos. Los necesitan las VOCES: son interjecciones que acompañan a una
    linea de dialogo, no la leen, asi que tienen que ser lo mas cortas
    posibles — y el corte se hace AQUI, sobre el original del pack, en vez de
    volver a comprimir un .ogg ya comprimido.
    """
    src = origen if os.path.isabs(origen) else os.path.join(RAIZ, origen)
    dst = destino if os.path.isabs(destino) else os.path.join(RAIZ, destino)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    cmd = [_ffmpeg(), "-v", "error", "-y", "-i", src]
    cadena = []
    if perfil != "ambiente":
        cadena.append("silenceremove=start_periods=1:start_threshold=-50dB:"
                      "start_silence=0.02:detection=peak,areverse,"
                      "silenceremove=start_periods=1:start_threshold=-50dB:"
                      "start_silence=0.05:detection=peak,areverse")
    if filtros:
        cadena += list(filtros)
    if cadena:
        cmd += ["-af", ",".join(cadena)]
    if dura > 0:
        cmd += ["-t", "%.3f" % dura]
    cmd += PERFILES[perfil] + [dst]
    subprocess.run(cmd, check=True)
    return os.path.getsize(dst)


def main():
    args = sys.argv[1:]
    if not args:
        raise SystemExit(__doc__)
    if args[0] == "--mono":
        for c in args[1:]:
            a_mono(c)
        return
    if args[0] == "--local":
        # Un archivo que YA esta en el disco (los .wav que trae el usuario en
        # `sounds/soundly`, a 24 bits y 96 kHz). Misma cadena que lo de Ludo:
        # recorte de silencios, mono donde toca y OGG.
        print(local(args[1], args[2], args[3]))
        return
    if args[0] == "--lote":
        total = 0
        for linea in open(args[1], encoding="utf-8"):
            linea = linea.strip()
            if not linea or linea.startswith("#"):
                continue
            campos = linea.split("\t")
            n = traer(campos[0], campos[1], campos[2])
            total += n
            print("%8d B  %s" % (n, campos[1]))
        print("TOTAL %.2f MB" % (total / 1048576.0))
        return
    print(traer(args[0], args[1], args[2]))


if __name__ == "__main__":
    main()
