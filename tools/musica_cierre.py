# -*- coding: utf-8 -*-
"""Le da un FINAL a un tema que no lo trae, y lo deja en .ogg.

Es el hermano de `musica_bucle.py` y hace justo lo contrario: aquel busca que
la cancion no acabe nunca, y este que acabe bien. Lo pide el tema del cartel
de fin de jornada, que es el unico del juego que tiene que sonar entero y
callarse.

POR QUE HACE FALTA: al generador de musica se le pidieron tres veces treinta
segundos "con una cadencia final, un acorde largo que se apaga y silencio", y
las tres veces devolvio la pieza CORTADA a media frase, con el ultimo compas
al 70-99% de su fuerza. Medido con el perfil de energia de la cola. No sabe
cerrar, asi que el cierre se monta aqui.

COMO: el fundido NO empieza donde caiga, empieza EN UN GOLPE. Se saca el flujo
espectral (los ataques), se coge el ultimo ataque fuerte que deje sitio
suficiente y desde ahi se apaga el sonido con una curva exponencial, que es
como se apaga un acorde de verdad —un fundido lineal se oye como si alguien
bajara el volumen— y detras se deja un poco de silencio. Arrancando en un
golpe, el oido lo lee como "la cancion ha terminado" y no como "han bajado el
mando".

Uso:
    python tools/musica_cierre.py <origen> [destino.ogg] [opciones]
        --cola 2.2       segundos de apagado
        --silencio 0.45  silencio que se deja detras
        --q 3            calidad vorbis
        --informe        no escribe nada, solo mide
"""
import os
import subprocess
import sys

import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ludo_audio import _ffmpeg  # noqa: E402
from musica_bucle import (_pcm, _rasgos, _recorte_silencio, HOP, SR_AN,  # noqa
                          SR_OUT)


def _ataques(mono):
    """Flujo espectral: cuanto SUBE la energia de cada banda, fotograma a
    fotograma. Es el detector de golpes de toda la vida y aqui basta, porque
    solo hay que encontrar el ultimo."""
    F = _rasgos(mono)
    d = np.diff(F, axis=0)
    return np.maximum(d, 0.0).sum(axis=1)


def cerrar(src, cola=2.2, silencio=0.45):
    mono = _pcm(src, SR_AN, 1)
    ini, fin = _recorte_silencio(mono)
    flujo = _ataques(mono)
    # El golpe tiene que dejar sitio para el apagado entero, y no puede estar
    # tan atras que se coma media cancion.
    tope = min(len(flujo), (fin - int(cola * SR_AN)) // HOP)
    suelo = max(0, tope - int(6.0 * SR_AN / HOP))
    if tope <= suelo:
        return {"ini": ini / float(SR_AN), "corte": fin / float(SR_AN),
                "fuerza": 0.0}
    tramo = flujo[suelo:tope]
    fuerte = float(np.percentile(tramo, 88))
    cand = np.where(tramo >= fuerte)[0]
    k = suelo + int(cand[-1] if len(cand) else int(np.argmax(tramo)))
    return {"ini": ini / float(SR_AN), "corte": (k * HOP) / float(SR_AN),
            "fuerza": float(flujo[k]), "medio": float(np.median(flujo)),
            "dur": len(mono) / float(SR_AN)}


def escribir(src, dst, d, cola, silencio, q):
    out = _pcm(src, SR_OUT, 2)
    ini = int(round(d["ini"] * SR_OUT))
    k = int(round(d["corte"] * SR_OUT))
    n = int(round(cola * SR_OUT))
    k = min(k, len(out) - n)
    pieza = out[ini:k + n].copy()
    # APAGADO EXPONENCIAL: un acorde se muere asi, perdiendo la mitad de su
    # fuerza cada tanto. En lineal se oye el gesto de bajar el volumen.
    t = np.linspace(0.0, 1.0, n, dtype=np.float32)[:, None]
    pieza[-n:] *= np.exp(-4.6 * t).astype(np.float32)
    pieza = np.concatenate(
        [pieza, np.zeros((int(silencio * SR_OUT), 2), dtype=np.float32)])
    dest = dst if os.path.isabs(dst) else os.path.join(RAIZ, dst)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    proc = subprocess.Popen(
        [_ffmpeg(), "-v", "error", "-y", "-f", "f32le", "-ar", str(SR_OUT),
         "-ac", "2", "-i", "-", "-c:a", "libvorbis", "-q:a", str(q),
         "-ar", "44100", dest], stdin=subprocess.PIPE)
    proc.communicate(np.clip(pieza, -1.0, 1.0).astype("<f4").tobytes())
    if proc.returncode:
        raise SystemExit("ffmpeg fallo al escribir %s" % dest)
    return os.path.getsize(dest), len(pieza) / float(SR_OUT)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    op = {"--cola": 2.2, "--silencio": 0.45, "--q": 3}
    for i, a in enumerate(sys.argv):
        if a in op and i + 1 < len(sys.argv):
            op[a] = float(sys.argv[i + 1])
    if not args:
        raise SystemExit(__doc__)
    src = args[0] if os.path.isabs(args[0]) else os.path.join(RAIZ, args[0])
    d = cerrar(src, op["--cola"], op["--silencio"])
    print("%-14s dura %5.2f s -> ultimo golpe en %.2f (fuerza %.2f, "
          "mediana %.2f)" % (os.path.basename(src), d.get("dur", 0.0),
                             d["corte"], d["fuerza"], d.get("medio", 0.0)))
    if "--informe" in sys.argv or len(args) < 2:
        return
    n, dur = escribir(src, args[1], d, op["--cola"], op["--silencio"],
                      int(op["--q"]))
    print("   -> %s  %d B  %.2f s (apagado %.1f s + %.2f de silencio)"
          % (args[1], n, dur, op["--cola"], op["--silencio"]))


if __name__ == "__main__":
    main()
