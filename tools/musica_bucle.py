# -*- coding: utf-8 -*-
"""Convierte un tema en un BUCLE SIN COSTURA y lo deja en .ogg.

EL PROBLEMA: un generador de musica devuelve una PIEZA, con su entrada y su
salida, y el juego necesita un LAZO. La vuelta se disimulaba cruzando el tema
consigo mismo dos segundos (`Audio._bucle_musica`), que esconde el corte pero
MEZCLA dos compases que no se corresponden: cada vuelta sonaba emborronada.
Esto lo arregla de raiz, en el archivo, y asi el juego puede usar el bucle del
motor, que no cuesta nada y no se nota.

COMO SE ELIGE EL PUNTO DE VUELTA: no se estima el tempo (que falla en cuanto
la pieza respira) sino que se BUSCA el sitio donde la musica vuelve a sonar
como al principio. Se saca un espectrograma por bandas, se coge una ventana de
`--ventana` segundos del arranque y se compara contra TODAS las posiciones
posibles del final. Como casar exige que coincidan el compas y la
instrumentacion, los puntos que salen estan alineados a compas solos, sin
contar un solo pulso.

PERO EL COSTE ESPECTRAL NO DECIDE: DECIDE LA COSTURA MEDIDA. Salio midiendo
—el candidato mas barato daba peor vuelta que otro un pelin mas caro—, asi que
se cosen `CANDIDATOS` puntos de verdad y se mide cada uno (ver `_costura`).
Entre los que no se oyen, gana el MAS LARGO.

LUEGO SE AFINA A NIVEL DE MUESTRA: el salto elegido cae dentro de un "hop"
(23 ms), y ahi todavia cabe un chasquido de fase. Se recorre mas menos un hop
buscando la maxima correlacion de onda y se corrige.

Y SE COSE CON UN CRUCE ENVUELTO: la cabeza del archivo se mezcla con lo que
venia DESPUES del punto de vuelta, o sea con su continuacion natural. Al ser
material que ya casa y va a tiempo, el cruce no emborrona — al reves que el
cruce largo de antes, que caia en un sitio cualquiera. Su duracion sale de lo
bien que case el punto (`_cruce_auto`).

TAMBIEN SE QUITA LA ENTRADA: si la pieza arranca con un fundido o una
introduccion floja, se busca el primer instante con cuerpo (`--entrada`) y se
empieza ahi. El punto de vuelta se busca contra ESE arranque, no contra el
del archivo.

Uso:
    python tools/musica_bucle.py <origen> [destino.ogg] [opciones]
        --cruce 0        segundos de cruce envuelto (0 = automatico)
        --ventana 4.0    ventana de comparacion para buscar la vuelta
        --min 0.55       fraccion minima del tema que tiene que durar el bucle
        --entrada 1      buscar y saltar la introduccion floja (0 = no)
        --q 3            calidad vorbis
        --traza          enseña todos los candidatos probados
        --informe        no escribe nada, solo mide
"""
import os
import subprocess
import sys

import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ludo_audio import _ffmpeg  # noqa: E402

SR_AN = 22050          # frecuencia de analisis
HOP = 512              # 23 ms
NFFT = 2048
BANDAS = 32
SR_OUT = 44100

## Percentil por debajo del cual damos la costura por INAUDIBLE: la vuelta
## salta menos que 3 de cada 20 transiciones que la cancion ya hace sola.
PCT_LIMPIO = 85.0

## LO QUE VALE UN SEGUNDO MAS DE MUSICA, en percentiles de costura. Es el
## cambio de la moneda entre las dos cosas que se pelean aqui: que la vuelta
## no se oiga y que el tema no se haga repetitivo. A 1.5, diez segundos mas de
## bucle justifican quince puntos peor de costura — pero el corte duro de
## `PCT_LIMPIO` no se salta nunca, asi que ningun bucle audible entra por
## largo que sea.
VALE_UN_SEGUNDO = 1.5

## Cuantos puntos de vuelta se prueban de verdad, cosiendolos y midiendolos.
CANDIDATOS = 10


def _pcm(src, sr, canales):
    out = subprocess.run(
        [_ffmpeg(), "-v", "error", "-i", src, "-f", "f32le",
         "-acodec", "pcm_f32le", "-ac", str(canales), "-ar", str(sr), "-"],
        capture_output=True, check=True).stdout
    a = np.frombuffer(out, dtype="<f4").astype(np.float32)
    if canales > 1:
        a = a.reshape(-1, canales)
    return a


def _bandas_log(n_bins, sr):
    """Reparte los bins de la FFT en `BANDAS` bandas logaritmicas."""
    frec = np.linspace(0, sr / 2.0, n_bins)
    bordes = np.geomspace(40.0, sr / 2.0 * 0.95, BANDAS + 1)
    idx = np.searchsorted(frec, bordes)
    return [(int(idx[i]), int(max(idx[i + 1], idx[i] + 1)))
            for i in range(BANDAS)]


def _ventanas(y):
    n = 1 + (len(y) - NFFT) // HOP
    if n < 4:
        raise SystemExit("El audio es demasiado corto.")
    return np.lib.stride_tricks.sliding_window_view(y, NFFT)[::HOP][:n]


def _rasgos(y):
    """Espectrograma por bandas, en dB y normalizado por fotograma."""
    ven = np.hanning(NFFT).astype(np.float32)
    esp = np.abs(np.fft.rfft(_ventanas(y) * ven, axis=1))
    grupos = _bandas_log(esp.shape[1], SR_AN)
    F = np.stack([esp[:, a:b].mean(axis=1) for a, b in grupos], axis=1)
    F = np.log10(F + 1e-6).astype(np.float32)
    # Normalizar cada fotograma quita de la ecuacion el VOLUMEN y deja solo
    # el color del sonido: asi el buscador casa por armonia e instrumentacion
    # y no por lo fuerte que suene el compas.
    F -= F.mean(axis=1, keepdims=True)
    F /= (np.linalg.norm(F, axis=1, keepdims=True) + 1e-9)
    return F


def _rms(y):
    t = _ventanas(y).astype(np.float64)
    return np.sqrt((t * t).mean(axis=1))


def _recorte_silencio(y, umbral_db=-48.0):
    r = _rms(y)
    if r.max() <= 0:
        return 0, len(y)
    fuerte = r > r.max() * (10.0 ** (umbral_db / 20.0))
    if not fuerte.any():
        return 0, len(y)
    a = int(np.argmax(fuerte))
    b = len(fuerte) - int(np.argmax(fuerte[::-1]))
    return a * HOP, min(len(y), b * HOP + NFFT)


def _fin_de_entrada(y, ini, fin, tope_s=8.0):
    """Primer instante con cuerpo: donde acaba el fundido o la introduccion."""
    r = _rms(y[ini:fin])
    if len(r) < 8:
        return ini
    mediana = float(np.median(r))
    tope = max(2, int(tope_s * SR_AN / HOP))
    con_cuerpo = np.where(r[:tope] >= mediana * 0.62)[0]
    if len(con_cuerpo) == 0:
        return ini
    return ini + int(con_cuerpo[0]) * HOP


def _afinar(mono, ini, p, radio, largo):
    """Ajusta el punto de vuelta a nivel de MUESTRA por correlacion."""
    ref = mono[ini:ini + largo].astype(np.float64)
    ref = ref - ref.mean()
    nref = np.linalg.norm(ref) + 1e-9
    mejor, mejor_c = p, -2.0
    for d in range(-radio, radio + 1):
        q = p + d
        if q < ini + largo or q + largo > len(mono):
            continue
        seg = mono[q:q + largo].astype(np.float64)
        seg = seg - seg.mean()
        c = float(np.dot(ref, seg) / (nref * (np.linalg.norm(seg) + 1e-9)))
        if c > mejor_c:
            mejor_c, mejor = c, q
    return mejor, mejor_c


## EL CRUCE NO SE DEDUCE: SE PRUEBA. Parecia que bastaba con "casa bien,
## cruce corto; casa mal, cruce largo", y NO es asi — salio midiendo: en el
## abordaje, el punto que casaba casi calcado (0.019) daba la PEOR vuelta de
## todas con un cruce de 0.38 s. Con material casi identico pero no alineado
## en fase, el cruce no funde: CANCELA, y lo que se oye es un hueco. Asi que
## cada punto de vuelta se cose con todos estos cruces y se queda el que
## mejor mide.
CRUCES = [0.03, 0.12, 0.35, 0.80, 1.50]


def _lazo(y, ini, p, xs):
    """El bucle ya cosido, para poder medirlo antes de escribir nada."""
    lazo = y[ini:p].copy()
    if xs > 0 and p + xs <= len(y):
        t = np.linspace(0.0, np.pi / 2.0, xs, dtype=np.float32)
        if lazo.ndim > 1:
            t = t[:, None]
        lazo[:xs] = lazo[:xs] * np.sin(t) + y[p:p + xs] * np.cos(t)
    return lazo


## MIDE LA COSTURA: pega el bucle consigo mismo y compara cuanto SALTA el
## sonido en la vuelta con lo que salta en el resto de la cancion. Una musica
## normal ya pega saltos en cada cambio de compas o de instrumento; si la
## vuelta se queda por debajo de esos, no hay nada que oir. Por eso devuelve
## un PERCENTIL dentro de la propia cancion y no un numero suelto: el mismo
## salto es un escandalo en una nana y no se nota en un abordaje.
def _costura(mono_lazo, cruce):
    doble = np.concatenate([mono_lazo, mono_lazo])
    F = _rasgos(doble)
    # SE MIDE A LA ESCALA DEL CRUCE, no de un fotograma. Midiendo el cambio
    # entre dos fotogramas seguidos, un cruce largo salia siempre "limpio"
    # por el mero hecho de repartir el cambio en mas tiempo: la medida
    # premiaba difuminar en vez de casar. Comparando lo que suena medio cruce
    # ANTES con lo que suena medio cruce DESPUES, un cruce largo tiene que
    # ganarselo igual que uno corto.
    L = max(1, int(round(cruce * SR_AN / HOP / 2.0)) + 1)
    salto = 1.0 - np.einsum("fb,fb->f", F[2 * L:], F[:-2 * L])
    j = len(mono_lazo) // HOP - L
    a = max(0, j - 2)
    b = min(len(salto), j + 3)
    if b <= a:
        return {"pico": 9.9, "pct": 100.0, "mediana": 0.0, "p95": 0.0}
    pico = float(salto[a:b].max())
    dentro = np.concatenate([salto[:a], salto[b:]])
    return {"pico": pico, "pct": float((dentro < pico).mean() * 100.0),
            "mediana": float(np.median(dentro)),
            "p95": float(np.percentile(dentro, 95))}


def buscar(src, cruce=0.0, ventana=4.0, minimo=0.55, quitar_entrada=True,
           traza=False):
    mono = _pcm(src, SR_AN, 1)
    ini, fin = _recorte_silencio(mono)
    if quitar_entrada:
        ini = _fin_de_entrada(mono, ini, fin)
    F = _rasgos(mono)
    f_ini = ini // HOP
    f_fin = fin // HOP
    w = max(8, int(ventana * SR_AN / HOP))
    x = int(1.7 * SR_AN / HOP) + 2
    dur = (fin - ini) / float(SR_AN)
    lo = f_ini + max(w * 2, int(dur * minimo * SR_AN / HOP))
    hi = min(f_fin, len(F)) - w - x
    if hi <= lo:
        raise SystemExit("No hay sitio para buscar la vuelta (tema corto).")
    cab = F[f_ini:f_ini + w]                       # (w, BANDAS)
    ven = np.lib.stride_tricks.sliding_window_view(F, (w, BANDAS))[:, 0]
    ven = ven[lo:hi + 1]                           # (candidatos, w, BANDAS)
    # 1 - coseno medio fotograma a fotograma: 0 = calcado, 2 = opuesto.
    coste = 1.0 - np.einsum("cwb,wb->c", ven, cab) / float(w)
    # Candidatos SEPARADOS: dos posiciones a medio segundo una de otra son el
    # mismo sitio, y probarlas gasta el presupuesto sin mirar otra parte de
    # la cancion.
    sep = int(2.0 * SR_AN / HOP)
    elegidos = []
    for k in np.argsort(coste):
        if all(abs(int(k) - e) >= sep for e in elegidos):
            elegidos.append(int(k))
        if len(elegidos) >= CANDIDATOS:
            break
    pruebas = []
    for k in elegidos:
        p, corr = _afinar(mono, ini, (lo + k) * HOP, HOP, int(0.20 * SR_AN))
        mejor_c = None
        for c in ([cruce] if cruce > 0 else CRUCES):
            xs = int(round(c * SR_AN))
            if p + xs > len(mono):
                continue
            m = _costura(_lazo(mono, ini, p, xs), c)
            if mejor_c is None or m["pct"] < mejor_c[1]["pct"]:
                mejor_c = (c, m)
        if mejor_c is None:
            continue
        c, m = mejor_c
        pruebas.append({"ini": ini / float(SR_AN), "fin": p / float(SR_AN),
                        "largo": (p - ini) / float(SR_AN), "cruce": c,
                        "coste": float(coste[k]), "corr": corr,
                        "pct": m["pct"], "pico": m["pico"],
                        "mediana": m["mediana"]})
    if not pruebas:
        raise SystemExit("Ningun candidato cabe con su cruce.")
    # PRIMERO QUE NO SE OIGA, DESPUES QUE SEA LARGO. El salto de la vuelta se
    # oye a la primera y la repeticion tarda minutos en cansar, asi que la
    # costura manda — pero no a cualquier precio: quedarse con el candidato
    # mas limpio a secas tiraba media cancion (la isla se quedaba en 18 s de
    # los 48 que casaban de sobra). Se cambia lo uno por lo otro a la tasa de
    # `VALE_UN_SEGUNDO`, con el corte duro de `PCT_LIMPIO` por encima.
    limpios = [q for q in pruebas if q["pct"] <= PCT_LIMPIO]
    mejor = (min(limpios, key=lambda q: q["pct"] - VALE_UN_SEGUNDO * q["largo"])
             if limpios else min(pruebas, key=lambda q: q["pct"]))
    mejor["dur"] = len(mono) / float(SR_AN)
    mejor["limpios"] = len(limpios)
    mejor["probados"] = len(pruebas)
    if traza:
        for q in sorted(pruebas, key=lambda z: z["fin"]):
            print("      %6.1f s  casa %.3f  cruce %.2f  costura pct %5.1f%s"
                  % (q["largo"], q["coste"], q["cruce"], q["pct"],
                     "  <-- elegido" if q is mejor else ""))
    return mejor


def escribir(src, dst, d, q):
    out = _pcm(src, SR_OUT, 2)
    ini = int(round(d["ini"] * SR_OUT))
    p = int(round(d["fin"] * SR_OUT))
    xs = int(round(d["cruce"] * SR_OUT))
    if p + xs > len(out):
        xs = max(0, len(out) - p)
    # CRUCE ENVUELTO en potencia constante (seno/coseno), que es lo que
    # mantiene el volumen plano en mitad del cruce: en lineal se oye un bache.
    lazo = _lazo(out, ini, p, xs)
    dest = dst if os.path.isabs(dst) else os.path.join(RAIZ, dst)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    proc = subprocess.Popen(
        [_ffmpeg(), "-v", "error", "-y", "-f", "f32le", "-ar", str(SR_OUT),
         "-ac", "2", "-i", "-", "-c:a", "libvorbis", "-q:a", str(q),
         "-ar", "44100", dest], stdin=subprocess.PIPE)
    proc.communicate(np.clip(lazo, -1.0, 1.0).astype("<f4").tobytes())
    if proc.returncode:
        raise SystemExit("ffmpeg fallo al escribir %s" % dest)
    return os.path.getsize(dest)


def verificar(ruta, cruce):
    """Mide la costura de un .ogg YA escrito (control despues de exportar)."""
    y = _pcm(ruta if os.path.isabs(ruta) else os.path.join(RAIZ, ruta),
             SR_AN, 1)
    return _costura(y, cruce)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    op = {"--cruce": 0.0, "--ventana": 4.0, "--min": 0.55, "--entrada": 1,
          "--q": 3}
    for i, a in enumerate(sys.argv):
        if a in op and i + 1 < len(sys.argv):
            op[a] = float(sys.argv[i + 1])
    if len(args) < 1:
        raise SystemExit(__doc__)
    src = args[0] if os.path.isabs(args[0]) else os.path.join(RAIZ, args[0])
    d = buscar(src, op["--cruce"], op["--ventana"], op["--min"],
               bool(op["--entrada"]), "--traza" in sys.argv)
    print("%-14s dura %5.1f s -> bucle %5.1f s  (entra %.2f, vuelve %.2f, "
          "cruce %.2f)  casa %.3f  costura pct %.1f  [%d/%d limpios]"
          % (os.path.basename(src), d["dur"], d["largo"], d["ini"], d["fin"],
             d["cruce"], d["coste"], d["pct"], d["limpios"], d["probados"]))
    if "--informe" in sys.argv or len(args) < 2:
        return
    n = escribir(src, args[1], d, int(op["--q"]))
    v = verificar(args[1], d["cruce"])
    print("   -> %s  %d B  |  ya escrito: costura %.3f = percentil %.1f "
          "(mediana %.3f, p95 %.3f)"
          % (args[1], n, v["pico"], v["pct"], v["mediana"], v["p95"]))


if __name__ == "__main__":
    main()
