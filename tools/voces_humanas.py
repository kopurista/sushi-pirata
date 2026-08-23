# -*- coding: utf-8 -*-
"""Reparte el pack "FS Human Voices" entre los personajes del juego.

SON SONIDOS, NO FRASES, que es justo lo que pide el juego: el pack trae
gruñidos, jadeos, risas, suspiros y gritos repartidos en 15 categorias, y
ninguno dice una palabra. Se sustituyen asi las voces de sintetizador que
habia antes.

EL PACK VIVE FUERA DEL PROYECTO (`Desktop/GODOT/sonidos/FS Human Voices`),
como el resto de librerias: aqui solo entran los .ogg ya convertidos.

CADA PERSONAJE TIENE SU TIPO DE VOZ Y SU TONO (`REPARTO`). Solo hay CUATRO
tipos en el pack -dos masculinos y dos femeninos- y el reparto son diez
personajes, asi que lo que los separa de verdad es el TONO, que NO se hornea
en el archivo: va en `Audio.VOZ_TONO`, para poder afinarlo sin reconvertir
nada. Las voces femeninas comparten tipo por decision del usuario.

CAI, EL KAPPA Y GIGI NO SE TOCAN: el primero conserva su voz japonesa y los
otros dos no son humanos (graznidos y croares generados).

UNA TOMA NO SE REPITE DENTRO DEL MISMO PERSONAJE: el pool de cada categoria
se baraja y se va consumiendo, asi que dos expresiones de la misma cara nunca
salen con el mismo gruñido. La semilla es fija para que la pasada sea
repetible.

    python tools/voces_humanas.py [--simular]
"""
import os
import random
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ludo_audio import local  # noqa: E402

PACK = os.path.join(os.path.dirname(os.path.dirname(RAIZ)),
                    "GODOT", "sonidos", "FS Human Voices",
                    "FS Human Voices", "SOUNDS")

SEMILLA = 20260822
TOMAS = 3

## LAS VOCES VAN MUY CORTAS A PROPOSITO (pedido por el usuario): acompañan a
## una linea de dialogo, no la leen, y salen cada vez que se pasa de linea.
## Una toma de segundo y medio se pisa con la siguiente y se oye como si el
## personaje hablara de verdad, que es justo lo que no se busca. Se cortan a
## `MAX_S` con un fundido de salida de `FADE_S` para que el corte no se oiga.
##
## EL CORTE SE HACE AQUI, sobre el .wav del pack, y no sobre el .ogg ya
## convertido: asi el archivo del juego sigue siendo de PRIMERA generacion.
MAX_S = 0.50
FADE_S = 0.09

# personaje -> tipo de voz del pack
REPARTO = {
    "david": "Male Type 1",
    "pablo": "Male Type 2",
    "saverio": "Male Type 2",
    "grumete": "Male Type 2",
    "pirata": "Male Type 1",
    "capitan": "Male Type 1",
    "alice": "Female Type 1",
    "grumete_f": "Female Type 1",
    "pirata_f": "Female Type 1",
    "capitan_f": "Female Type 1",
}

# expresion -> categoria del pack. La cara manda: "riendo" es una risa y
# "gritando" un grito, no hay que darle mas vueltas.
CATEGORIA = {
    "serio": "Idle",
    "hablando": "Affirmation",
    "explicando": "Thinking",
    "feliz": "Cheering",
    "riendo": "Laughing",
    "guason": "Laughing",
    "sorprendido": "Reaction",
    "gritando": "Screaming",
    "triste": "Crying",
    "callado": "Thinking",
    "nervioso": "Erm",
    "mira_loro": "Erm",
    "punal": "Objection",
}

# Las expresiones de cada personaje (las mismas que sus retratos).
MOODS = {
    "david": ["serio", "hablando", "feliz", "riendo", "sorprendido",
              "gritando", "triste", "mira_loro"],
    "saverio": ["serio", "hablando", "explicando", "feliz", "riendo"],
    "pablo": ["serio", "hablando", "feliz", "riendo", "sorprendido",
              "guason", "punal"],
    "alice": ["serio", "hablando", "callado", "feliz", "riendo",
              "sorprendido", "triste"],
    "grumete": ["serio", "hablando", "feliz"],
    "grumete_f": ["serio", "hablando", "feliz"],
    "pirata": ["serio", "hablando", "feliz", "nervioso"],
    "pirata_f": ["serio", "hablando", "feliz", "nervioso"],
    "capitan": ["serio", "hablando", "feliz"],
    "capitan_f": ["serio", "hablando", "feliz"],
}


def pool(tipo, categoria):
    d = os.path.join(PACK, tipo, categoria)
    if not os.path.isdir(d):
        return []
    return [os.path.join(d, f) for f in sorted(os.listdir(d))
            if f.lower().endswith(".wav")]


def main():
    simular = "--simular" in sys.argv
    if not os.path.isdir(PACK):
        raise SystemExit("No encuentro el pack en %s" % PACK)
    rnd = random.Random(SEMILLA)
    total = 0
    peso = 0
    for pers in sorted(REPARTO):
        tipo = REPARTO[pers]
        # UNA BOLSA POR PERSONAJE: se van sacando tomas sin devolverlas, asi
        # que dos expresiones suyas nunca comparten grunido.
        usadas = set()
        destino = os.path.join(RAIZ, "sounds", "juego", "voces", pers)
        if not simular:
            os.makedirs(destino, exist_ok=True)
            for f in os.listdir(destino):
                if f.endswith(".ogg") or f.endswith(".import"):
                    os.remove(os.path.join(destino, f))
        linea = []
        for mood in MOODS[pers]:
            cat = CATEGORIA.get(mood, "Idle")
            libres = [f for f in pool(tipo, cat) if f not in usadas]
            if len(libres) < TOMAS:
                raise SystemExit("Faltan tomas de %s/%s" % (tipo, cat))
            elegidas = rnd.sample(libres, TOMAS)
            for i, src in enumerate(elegidas, 1):
                usadas.add(src)
                dst = os.path.join(destino, "%s_%d.ogg" % (mood, i))
                if not simular:
                    peso += local("voz", src, dst,
                                  ["afade=t=out:st=%.3f:d=%.3f"
                                   % (MAX_S - FADE_S, FADE_S)], MAX_S)
                total += 1
            linea.append("%s(%s)" % (mood, cat))
        print("%-11s %-14s %s" % (pers, tipo, " ".join(linea)))
    print("\n%d clips%s" % (total,
          "" if simular else "  |  %.2f MB" % (peso / 1048576.0)))


if __name__ == "__main__":
    main()
