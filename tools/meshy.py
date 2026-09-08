#!/usr/bin/env python3
"""Puente entre MESHY (modelos 3D) y este proyecto de Godot.

Meshy sustituye a Ludo PARA EL 3D (decidido por el usuario el 31-8-2026);
Ludo se queda con las imagenes 2D. La API de Meshy es asincrona y sus URLs de
descarga CADUCAN EN 3 DIAS (2 meses solo las de rigging), o sea que descargar
al momento no es una recomendacion sino la unica forma de no perder el asset.

Lo que aporta esta herramienta sobre llamar a la API a pelo es la CADENA
COMPLETA de este proyecto, que un modelo nuevo necesita entera o entra roto:

    generar -> esperar -> descargar .glb -> glb_prepare -> assets/models/
    -> .import con el hook de decimado y su PRESUPUESTO -> reimportar
    -> fix_texture_imports (Basis + limite de tamano)

Sin esos ultimos pasos el modelo entra con textura s3tc (que en el export web
movil NO CARGA) y sin decimar (los modelos de imagen->3D vienen con una
densidad que no tiene nada que ver con su tamano en pantalla).

CLAVE: sale de la variable de entorno MESHY_API_KEY o del archivo `.env.local`
de la raiz, que esta en .gitignore. NUNCA se escribe en el repositorio.

Uso:
    python tools/meshy.py saldo
    python tools/meshy.py texto  <id> "prompt"        [--poly 2500] [--rig]
    python tools/meshy.py imagen <id> concepto.png    [--poly 2500] [--rig]
    python tools/meshy.py estado <task_id>
    python tools/meshy.py bajar  <id> <task_id>       [--poly 2500]

`<id>` es el nombre con el que el modelo vive en el juego: sale como
`assets/models/<id>.glb` y esa es la ruta que usan los scripts.

Notas de la API (documentacion oficial, verificadas):
  - Text-to-3D va en /openapi/v2 y tiene DOS fases: `preview` (geometria) y
    `refine` (texturas), que se encadenan por `preview_task_id`.
  - Image-to-3D va en /openapi/v1 y admite data-URI en base64, asi que no hace
    falta subir el concepto a ninguna parte (con Ludo habia que empujarlo a la
    rama tmp-rig del repositorio para tener una URL publica).
  - El rigging es SOLO humanoide bipedo, la misma limitacion que tenia Ludo.
  - Estados: PENDING / IN_PROGRESS / SUCCEEDED / FAILED / CANCELED.
"""

import argparse
import base64
import json
import mimetypes
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
MODELOS = RAIZ / "assets" / "models"
CRUDOS = RAIZ / "_gen" / "meshy"          # ignorado por git (empieza por _)
API = "https://api.meshy.ai"
## Presupuesto de triangulos por defecto: el de los platos de este juego.
POLY_DEF = 2500
## Cada cuanto se pregunta por la tarea, en segundos.
ESPERA = 6
## Tope de espera por tarea (una de texto con refinado puede tardar minutos).
TOPE = 900


# --------------------------------------------------------------- utilidades
def clave() -> str:
    k = os.environ.get("MESHY_API_KEY", "").strip()
    if k:
        return k
    env = RAIZ / ".env.local"
    if env.is_file():
        for linea in env.read_text(encoding="utf-8").splitlines():
            if linea.startswith("MESHY_API_KEY="):
                return linea.split("=", 1)[1].strip()
    sys.exit("Falta MESHY_API_KEY (variable de entorno o .env.local)")


def pide(ruta: str, datos: dict | None = None, metodo: str = "") -> dict:
    url = ruta if ruta.startswith("http") else API + ruta
    cuerpo = None if datos is None else json.dumps(datos).encode("utf-8")
    req = urllib.request.Request(url, data=cuerpo,
        method=metodo or ("POST" if datos is not None else "GET"))
    req.add_header("Authorization", "Bearer " + clave())
    if datos is not None:
        req.add_header("Content-Type", "application/json")
    # LA API CONTESTA "202 CON EL CUERPO VACIO" CUANDO SE LE PIDE DEMASIADO
    # SEGUIDO, y ahi no hay JSON que leer: un lote de trece personajes se quedo
    # en tres, y los otros diez murieron con un JSONDecodeError que no decia
    # nada de nada. No es un fallo de la peticion —la misma vuelve a funcionar
    # sola al rato, comprobado con el saldo—, asi que se reintenta con espera
    # creciente en vez de darla por perdida.
    espera = 20
    for _intento in range(6):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                crudo = r.read().decode("utf-8").strip()
            if crudo:
                return json.loads(crudo)
            print("  [meshy] respuesta vacia (HTTP 202), reintento en %ds" % espera)
        except urllib.error.HTTPError as e:
            if e.code not in (429, 500, 502, 503, 504):
                sys.exit("HTTP %d en %s\n%s" % (e.code, url, e.read().decode("utf-8")))
            print("  [meshy] HTTP %d, reintento en %ds" % (e.code, espera))
        except (urllib.error.URLError, TimeoutError) as e:
            print("  [meshy] red: %s, reintento en %ds" % (e, espera))
        time.sleep(espera)
        espera = min(espera * 2, 180)
    sys.exit("La API no responde con contenido tras 6 intentos: %s" % url)


def esperar(ruta: str, task_id: str) -> dict:
    """Sondea hasta que la tarea termina. Imprime el avance para que se vea
    que sigue viva: una tarea de texto con refinado tarda minutos."""
    t0 = time.time()
    ultimo = ""
    while True:
        r = pide("%s/%s" % (ruta, task_id))
        estado = str(r.get("status", "?"))
        marca = "%s %s%%" % (estado, r.get("progress", 0))
        if marca != ultimo:
            print("  [%4ds] %s" % (time.time() - t0, marca), flush=True)
            ultimo = marca
        if estado == "SUCCEEDED":
            return r
        if estado in ("FAILED", "CANCELED"):
            sys.exit("La tarea %s termino en %s: %s"
                % (task_id, estado, r.get("task_error", "")))
        if time.time() - t0 > TOPE:
            sys.exit("Se agoto la espera (%ds). Sigue con:\n"
                "  python tools/meshy.py estado %s" % (TOPE, task_id))
        time.sleep(ESPERA)


def descargar(url: str, destino: Path) -> Path:
    destino.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req, timeout=300) as r, \
            open(destino, "wb") as f:
        f.write(r.read())
    print("  bajado %s (%.1f KB)" % (destino.name, destino.stat().st_size / 1024))
    return destino


# ------------------------------------------------- integracion con el juego
def presupuesto(mid: str, poly: int) -> None:
    """Apunta el modelo en BUDGETS de `import_hooks/decimate_import.gd`. Sin
    esa linea el hook no lo decima y entra a plena densidad."""
    hook = RAIZ / "import_hooks" / "decimate_import.gd"
    s = hook.read_text(encoding="utf-8")
    if re.search(r'^\s*"%s"\s*:' % re.escape(mid), s, re.M):
        print("  presupuesto: ya estaba apuntado")
        return
    marca = "const BUDGETS := {\n"
    if marca not in s:
        print("  AVISO: no encuentro BUDGETS, apunta el presupuesto a mano")
        return
    linea = '\t# Entrado por Meshy (tools/meshy.py).\n\t"%s": %d,\n' % (mid, poly)
    hook.write_text(s.replace(marca, marca + linea, 1), encoding="utf-8")
    print("  presupuesto: %s -> %d triangulos" % (mid, poly))


def escribir_import(glb: Path) -> None:
    """Deja el .import con lo que este proyecto exige a TODO modelo nuevo:
    hook de decimado, sin LODs y sin malla de sombra. Godot lo crearia con
    generate_lods=true, create_shadow_meshes=true e import_script vacio."""
    imp = Path(str(glb) + ".import")
    if imp.is_file():
        s = imp.read_text(encoding="utf-8")
        s = re.sub(r"meshes/generate_lods=\w+", "meshes/generate_lods=false", s)
        s = re.sub(r"meshes/create_shadow_meshes=\w+",
            "meshes/create_shadow_meshes=false", s)
        s = re.sub(r'import_script/path="[^"]*"',
            'import_script/path="res://import_hooks/decimate_import.gd"', s)
        imp.write_text(s, encoding="utf-8")
        print("  .import: hook de decimado y LODs apagados")
    else:
        print("  .import: aun no existe; se crea al reimportar, vuelve a "
            "pasar `python tools/meshy.py ajustar %s`" % glb.stem)


def godot() -> str | None:
    for c in RAIZ.parent.glob("Godot_v*/Godot_*_console.exe"):
        return str(c)
    return None


def reimportar() -> None:
    exe = godot()
    if exe is None:
        print("  (no encuentro Godot: reimporta a mano con --headless --import)")
        return
    print("  reimportando...")
    subprocess.run([exe, "--headless", "--path", str(RAIZ), "--import"],
        capture_output=True, timeout=900)


def rematar(mid: str, glb_crudo: Path, poly: int) -> None:
    """Del .glb recien bajado al modelo listo para usar en el juego."""
    destino = MODELOS / ("%s.glb" % mid)
    print("preparando %s" % destino.name)
    subprocess.run([sys.executable, str(RAIZ / "tools" / "glb_prepare.py"),
        str(glb_crudo), str(destino)], check=True)
    presupuesto(mid, poly)
    reimportar()
    escribir_import(destino)
    reimportar()
    subprocess.run([sys.executable,
        str(RAIZ / "tools" / "fix_texture_imports.py")], check=False)
    reimportar()
    print("\nLISTO: res://assets/models/%s.glb" % mid)
    print("Comprueba que compila:  --headless --quit-after 250 "
        "res://scenes/level3d.tscn")


# ------------------------------------------------------------------ ordenes
def cmd_saldo(_a) -> None:
    print("creditos: %s" % pide("/openapi/v1/balance").get("balance"))


def cmd_texto(a) -> None:
    print("Text-to-3D (fase 1: geometria)")
    prev = pide("/openapi/v2/text-to-3d", {
        "mode": "preview", "prompt": a.prompt, "ai_model": "latest",
        "topology": "triangle", "target_polycount": max(a.poly * 4, 8000),
        "should_remesh": True,
        "pose_mode": "a-pose" if a.rig else "",
    })["result"]
    esperar("/openapi/v2/text-to-3d", prev)
    print("Text-to-3D (fase 2: texturas)")
    ref = pide("/openapi/v2/text-to-3d", {
        "mode": "refine", "preview_task_id": prev,
        "enable_pbr": False, "texture_resolution": "2k",
    })["result"]
    r = esperar("/openapi/v2/text-to-3d", ref)
    _bajar_y_rematar(a.id, r, a.poly, a.rig)


def cmd_imagen(a) -> None:
    img = Path(a.imagen)
    if not img.is_file():
        sys.exit("No existe %s" % img)
    tipo = mimetypes.guess_type(img.name)[0] or "image/png"
    uri = "data:%s;base64,%s" % (tipo,
        base64.b64encode(img.read_bytes()).decode("ascii"))
    print("Image-to-3D desde %s (%.0f KB)" % (img.name,
        img.stat().st_size / 1024))
    # `smart-topology` da malla limpia con tope de 15.000 triangulos, que
    # encaja con los presupuestos de este proyecto (800-9.000). OJO: la API lo
    # RECHAZA con ai_model "latest" (HTTP 400: "smart-topology requires
    # ai_model meshy-t1 or meshy-t2"), asi que va emparejado con meshy-t2.
    # Con --alta se pide MESHY-7 a maxima densidad en vez de la topologia
    # inteligente: `smart-topology` tiene tope de 15.000 triangulos y en una
    # pieza con filo (el puñal de Pablo) devolvio una cuña facetada.
    cuerpo = {
        "image_url": uri, "ai_model": "meshy-t2",
        "model_type": "smart-topology",
        "target_polycount": min(max(a.poly * 3, 4000), 15000),
        "should_remesh": True, "topology": "triangle",
        "enable_pbr": False, "texture_resolution": "2k",
    }
    if getattr(a, "alta", False):
        cuerpo.pop("model_type")
        cuerpo.update({"ai_model": "meshy-7",
                       "target_polycount": getattr(a, "poly_crudo", 60000),
                       "texture_resolution": getattr(a, "textura", "4k"),
                       "remove_lighting": True})
    tid = pide("/openapi/v1/image-to-3d", cuerpo)["result"]
    r = esperar("/openapi/v1/image-to-3d", tid)
    _bajar_y_rematar(a.id, r, a.poly, a.rig)


def cmd_multi(a) -> None:
    """Varias VISTAS del mismo personaje (frente, lado, espalda).

    Con una sola imagen Meshy tiene que inventarse la profundidad y el modelo
    sale APLANADO —el torso como una plancha y la barba como una cuna—, que es
    lo que le paso al primer David. Dandole el giro completo, el volumen sale
    de verdad. Cuesta 30 creditos en vez de 15, mas 5 del rig.

    OJO: multi-image NO admite `smart-topology`, asi que aqui va con el modelo
    normal (meshy-7 / latest) y el remallado por `target_polycount`.
    """
    uris = []
    for ruta in a.imagenes:
        img = Path(ruta)
        if not img.is_file():
            sys.exit("No existe %s" % img)
        tipo = mimetypes.guess_type(img.name)[0] or "image/png"
        uris.append("data:%s;base64,%s"
                    % (tipo, base64.b64encode(img.read_bytes()).decode("ascii")))
    print("Multi-image-to-3D desde %d vistas: %s"
          % (len(uris), ", ".join(Path(x).name for x in a.imagenes)))
    # CALIDAD MAXIMA (decidido por el usuario): el modelo sale lo mas denso y
    # con la textura mas fina que da Meshy, y se rebaja DESPUES en Blender. La
    # cuenta que lo justifica: los retratos 2D de David son 48 PNG y 25 MB; su
    # modelo 3D con textura de 1024 pesa 1,5 MB y cubre todos los humores y
    # las variantes a la vez. Aunque el crudo pese cuatro veces mas, sigue
    # saliendo a cuenta. `remove_lighting` es lo que quita las MANCHAS
    # horneadas en cara y cuerpo que salieron en el Kappa, la Sirena y Alice.
    tid = pide("/openapi/v1/multi-image-to-3d", {
        "image_urls": uris, "ai_model": "meshy-7",
        "target_polycount": a.poly_crudo,
        "should_remesh": True, "topology": "triangle",
        "should_texture": True, "enable_pbr": False,
        "texture_resolution": a.textura,
        "image_enhancement": True, "remove_lighting": True,
        "pose_mode": "a-pose" if a.rig else "",
    })["result"]
    r = esperar("/openapi/v1/multi-image-to-3d", tid)
    _bajar_y_rematar(a.id, r, a.poly, a.rig)


def _bajar_y_rematar(mid: str, res: dict, poly: int, rig: bool) -> None:
    urls = res.get("model_urls", {})
    if "glb" not in urls:
        sys.exit("La tarea no trae .glb: %s" % list(urls))
    crudo = descargar(urls["glb"], CRUDOS / ("%s_crudo.glb" % mid))
    if rig:
        print("Rigging (solo humanoide bipedo)")
        tid = pide("/openapi/v1/rigging", {
            "input_task_id": res["id"], "height_meters": 1.7,
        })["result"]
        rr = esperar("/openapi/v1/rigging", tid)
        # OJO: el rigging NO devuelve `model_urls` como las demas tareas, sino
        # `result.rigged_character_glb_url` (mas las animaciones basicas de
        # andar y correr en `result.basic_animations`, que aqui no se usan: el
        # juego anima por codigo con CharacterAnim). Buscarlo en `model_urls`
        # dejaba el rigueo pagado y sin descargar.
        rurls = (rr.get("result") or {})
        url_rig = rurls.get("rigged_character_glb_url", "")
        if url_rig != "":
            crudo = descargar(url_rig, CRUDOS / ("%s_rig.glb" % mid))
            mid = mid if mid.endswith("_rig") else mid + "_rig"
        else:
            print("  AVISO: el rigging no devolvio .glb; se usa el sin riguear")
    rematar(mid, crudo, poly)


def cmd_riguear(a) -> None:
    """Riguea una tarea que YA existe (su modelo esta generado).

    Hace falta cuando el rig del lote fallo —a Meshy le cuesta un CABEZON y
    contesta "Pose estimation failed"— y no se quiere pagar otra vez la
    generacion entera, que son 30 creditos contra los 5 del rig.
    """
    print("Rigging de la tarea %s" % a.tarea)
    tid = pide("/openapi/v1/rigging", {
        "input_task_id": a.tarea, "height_meters": 1.7,
    })["result"]
    rr = esperar("/openapi/v1/rigging", tid)
    url = (rr.get("result") or {}).get("rigged_character_glb_url", "")
    if url == "":
        sys.exit("El rigging no devolvio .glb")
    crudo = descargar(url, CRUDOS / ("%s_rig.glb" % a.id))
    rematar(a.id + "_rig", crudo, a.poly)


def cmd_estado(a) -> None:
    for ruta in ["/openapi/v1/image-to-3d", "/openapi/v1/multi-image-to-3d",
            "/openapi/v2/text-to-3d", "/openapi/v1/rigging", "/openapi/v1/remesh"]:
        try:
            r = pide("%s/%s" % (ruta, a.task))
        except SystemExit:
            continue
        print(json.dumps({k: r[k] for k in
            ("id", "status", "progress", "model_urls", "expires_at")
            if k in r}, indent=2))
        return
    sys.exit("No encuentro la tarea %s" % a.task)


def cmd_bajar(a) -> None:
    for ruta in ["/openapi/v1/image-to-3d", "/openapi/v2/text-to-3d",
            "/openapi/v1/rigging"]:
        try:
            r = pide("%s/%s" % (ruta, a.task))
        except SystemExit:
            continue
        if r.get("status") != "SUCCEEDED":
            sys.exit("La tarea esta en %s" % r.get("status"))
        _bajar_y_rematar(a.id, r, a.poly, False)
        return
    sys.exit("No encuentro la tarea %s" % a.task)


def cmd_ajustar(a) -> None:
    """Repasa el .import y el presupuesto de un modelo que ya esta en sitio."""
    glb = MODELOS / ("%s.glb" % a.id)
    if not glb.is_file():
        sys.exit("No existe %s" % glb)
    presupuesto(a.id, a.poly)
    escribir_import(glb)
    reimportar()
    subprocess.run([sys.executable,
        str(RAIZ / "tools" / "fix_texture_imports.py")], check=False)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="orden", required=True)

    sub.add_parser("saldo").set_defaults(fn=cmd_saldo)

    q = sub.add_parser("texto")
    q.add_argument("id")
    q.add_argument("prompt")
    q.add_argument("--poly", type=int, default=POLY_DEF)
    q.add_argument("--rig", action="store_true")
    q.set_defaults(fn=cmd_texto)

    q = sub.add_parser("imagen")
    q.add_argument("id")
    q.add_argument("imagen")
    q.add_argument("--poly", type=int, default=POLY_DEF)
    q.add_argument("--alta", action="store_true",
                   help="meshy-7 a maxima densidad en vez de smart-topology")
    q.add_argument("--poly-crudo", type=int, default=60000)
    q.add_argument("--textura", default="4k", choices=["2k", "4k", "8k"])
    q.add_argument("--rig", action="store_true")
    q.set_defaults(fn=cmd_imagen)

    q = sub.add_parser("multi")
    q.add_argument("id")
    q.add_argument("imagenes", nargs="+")
    q.add_argument("--poly", type=int, default=POLY_DEF,
                   help="presupuesto del hook de decimado en Godot")
    q.add_argument("--poly-crudo", type=int, default=100000,
                   help="triangulos que se le piden a Meshy (100-300000)")
    q.add_argument("--textura", default="4k", choices=["2k", "4k", "8k"])
    q.add_argument("--rig", action="store_true")
    q.set_defaults(fn=cmd_multi)

    q = sub.add_parser("riguear")
    q.add_argument("id")
    q.add_argument("tarea")
    q.add_argument("--poly", type=int, default=POLY_DEF)
    q.set_defaults(fn=cmd_riguear)

    q = sub.add_parser("estado")
    q.add_argument("task")
    q.set_defaults(fn=cmd_estado)

    q = sub.add_parser("bajar")
    q.add_argument("id")
    q.add_argument("task")
    q.add_argument("--poly", type=int, default=POLY_DEF)
    q.set_defaults(fn=cmd_bajar)

    q = sub.add_parser("ajustar")
    q.add_argument("id")
    q.add_argument("--poly", type=int, default=POLY_DEF)
    q.set_defaults(fn=cmd_ajustar)

    a = p.parse_args()
    a.fn(a)
    return 0


if __name__ == "__main__":
    sys.exit(main())
