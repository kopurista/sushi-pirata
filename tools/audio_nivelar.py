# -*- coding: utf-8 -*-
"""Mide la SONORIDAD de todo el audio del juego y calcula el nivel de cada uno.

EL PROBLEMA: el material viene de sitios distintos —un pack de foley, otro de
interfaz, voces de un tercero y musica generada— y cada uno trae su nivel. Con
el mismo numero en la tabla, unos sonidos se oyen a gritos y otros no se oyen.
Igualarlos es lo que permite despues subir o bajar el conjunto con una sola
perilla, que es de lo que se trata.

NO SE MIDE EL PICO, SE MIDE LA SONORIDAD. Dos sonidos con el mismo pico suenan
muy distinto si uno es un golpe seco y el otro un zumbido sostenido, y el pico
no distingue un bombo de un silbato aunque el oido si. Aqui se calcula la
sonoridad con **ponderacion K** (la de la norma ITU-R BS.1770, la que usan la
radio y la television), que pesa cada frecuencia como la oye una persona: quita
los graves muy bajos y realza la banda de la voz.

Y SE MIDE SOLO LA PARTE QUE SUENA. La medida de la norma trabaja por bloques de
400 ms y descarta lo que quede por debajo de un umbral; con efectos de 80 ms
eso devuelve "silencio" o cifras sin sentido. Aqui se acota primero la region
ACTIVA del archivo (lo que esta por encima de -45 dB de su propio pico) y se
mide ahi, asi que un chasquido corto y un bucle de un minuto se comparan por lo
mismo: lo fuerte que suenan mientras suenan.

COMO SE APLICA LA PONDERACION SIN FILTROS: por Parseval. En vez de pasar la
señal por los dos biquads de la norma, se saca su espectro, se multiplica la
POTENCIA de cada frecuencia por la respuesta de esos biquads y se suma. Sale lo
mismo, en una linea de numpy y sin arrastrar dependencias.

    python tools/audio_nivelar.py              # mide y propone
    python tools/audio_nivelar.py --aplicar    # ademas escribe las tablas
"""
import io
import os
import re
import subprocess
import sys

import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ludo_audio import _ffmpeg  # noqa: E402

SR = 48000          # la ponderacion K esta definida a esta frecuencia
AUDIO = os.path.join(RAIZ, "scripts", "audio.gd")

## Coeficientes de la ponderacion K (ITU-R BS.1770) a 48 kHz: primero el
## realce de agudos que imita la cabeza, despues el paso-alto que se lleva el
## retumbe.
K_ETAPAS = [
    ([1.53512485958697, -2.69169618940638, 1.19839281085285],
     [1.0, -1.69065929318241, 0.73248077421585]),
    ([1.0, -2.0, 1.0],
     [1.0, -1.99004745483398, 0.99007225036621]),
]

## Region activa: lo que esta por encima de esto respecto al pico del archivo.
ACTIVO_DB = -45.0
## Colchon alrededor de la region activa, en segundos.
AIRE = 0.02


def _respuesta_k(n):
    """Respuesta en POTENCIA de la ponderacion K para `n` bins de rfft."""
    w = np.linspace(0.0, np.pi, n)
    z = np.exp(-1j * w)
    h = np.ones(n, dtype=np.complex128)
    for b, a in K_ETAPAS:
        num = b[0] + b[1] * z + b[2] * z * z
        den = a[0] + a[1] * z + a[2] * z * z
        h *= num / den
    return np.abs(h) ** 2


_CACHE_K = {}


def _k(n):
    if n not in _CACHE_K:
        _CACHE_K[n] = _respuesta_k(n)
    return _CACHE_K[n]


def _pcm(ruta):
    out = subprocess.run(
        [_ffmpeg(), "-v", "error", "-i", ruta, "-f", "f32le",
         "-acodec", "pcm_f32le", "-ac", "1", "-ar", str(SR), "-"],
        capture_output=True, check=True).stdout
    return np.frombuffer(out, dtype="<f4").astype(np.float64)


def _activo(y):
    """Recorta a la parte que de verdad suena."""
    if len(y) < 64:
        return y
    ven = 256
    n = len(y) // ven
    if n < 2:
        return y
    env = np.abs(y[:n * ven].reshape(n, ven)).max(axis=1)
    pico = env.max()
    if pico <= 0:
        return y
    fuerte = np.where(env > pico * (10.0 ** (ACTIVO_DB / 20.0)))[0]
    if len(fuerte) == 0:
        return y
    a = max(0, int(fuerte[0]) * ven - int(AIRE * SR))
    b = min(len(y), (int(fuerte[-1]) + 1) * ven + int(AIRE * SR))
    return y[a:b]


def sonoridad(ruta):
    """Sonoridad ponderada K de la parte activa, en LKFS."""
    y = _activo(_pcm(ruta))
    if len(y) < 64:
        return -70.0, 0.0
    pico = float(np.abs(y).max())
    esp = np.fft.rfft(y)
    pot = (np.abs(esp) ** 2) * _k(len(esp))
    # Parseval: la suma de la potencia del espectro entre N es el cuadrado
    # medio de la señal (el factor 2 es por los bins negativos que rfft no
    # devuelve).
    ms = (pot[0] + 2.0 * pot[1:-1].sum() + pot[-1]) / (len(y) ** 2)
    if ms <= 0:
        return -70.0, pico
    return -0.691 + 10.0 * np.log10(ms), pico


def _tabla(nombre, texto):
    m = re.search(r"const %s := \{(.*?)\n\}" % nombre, texto, re.S)
    return m.group(1) if m else ""


def familias():
    """{familia: [rutas]} leyendo `Audio.FAMILIAS`."""
    s = io.open(AUDIO, encoding="utf-8").read()
    pre = dict(re.findall(r'const ([A-Z]{2})_ := "res://([^"]+)"', s))
    blk = _tabla("FAMILIAS", s)
    fam = {}
    for m in re.finditer(r'"([a-z_0-9]+)": \[(.*?)\]', blk, re.S):
        rutas = []
        for p, f in re.findall(r'([A-Z]{2})_ \+ "([^"]+)"', m.group(2)):
            rutas.append(os.path.join(RAIZ, pre[p], f))
        if rutas:
            fam[m.group(1)] = rutas
    return fam


def temas():
    s = io.open(AUDIO, encoding="utf-8").read()
    blk = _tabla("TEMAS", s)
    return {k: os.path.join(RAIZ, v.replace("res://", ""))
            for k, v in re.findall(r'"([a-z_0-9]+)": "([^"]+)"', blk)}


def ambientes():
    s = io.open(AUDIO, encoding="utf-8").read()
    blk = _tabla("AMBIENTES", s)
    return {k: os.path.join(RAIZ, v.replace("res://", ""))
            for k, v in re.findall(r'"([a-z_0-9]+)": "([^"]+)"', blk)}


def voces():
    """{personaje: [rutas]} recorriendo la carpeta, que es como las compone
    el juego (por convencion, no por tabla)."""
    raiz = os.path.join(RAIZ, "sounds", "juego", "voces")
    out = {}
    for pers in sorted(os.listdir(raiz)):
        d = os.path.join(raiz, pers)
        if not os.path.isdir(d):
            continue
        out[pers] = [os.path.join(d, f) for f in sorted(os.listdir(d))
                     if f.endswith(".ogg")]
    return out


def medir(grupos):
    """{clave: (sonoridad_media, pico_max, n)} — la media en potencia, no la
    aritmetica de decibelios: lo que se compara es energia."""
    out = {}
    for k, rutas in grupos.items():
        if isinstance(rutas, str):
            rutas = [rutas]
        vals, picos = [], []
        for r in rutas:
            if not os.path.isfile(r):
                continue
            lk, pk = sonoridad(r)
            vals.append(lk)
            picos.append(pk)
        if not vals:
            continue
        lin = np.mean([10.0 ** (v / 10.0) for v in vals])
        out[k] = (10.0 * np.log10(lin), max(picos), len(vals),
                  max(vals) - min(vals))
    return out
