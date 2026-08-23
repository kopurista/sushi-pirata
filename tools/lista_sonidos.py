# -*- coding: utf-8 -*-
"""Genera la LISTA DE SONIDOS del juego como pagina HTML.

Los VOLUMENES, los TONOS y las TOMAS de cada familia se leen de `audio.gd`, no
se escriben aqui: asi la lista no puede contradecir al juego, y basta con
volver a ejecutarla despues de tocar la tabla.

Lo que si vive aqui es lo que el codigo no sabe: EN QUE MOMENTO suena cada
familia y QUIEN la eligio (el usuario a oido o el que monto el audio). Al
anadir una familia, anadir su fila en `CUANDO`.

    python tools/lista_sonidos.py [destino.html]
"""
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# familia -> (seccion, cuando suena, quien lo eligio)
#   "usuario" = lo mando poner el usuario (archivo concreto o regla concreta)
#   "audio"   = lo eligio quien monto el audio
CUANDO = {
    # --- interfaz ---
    "click": ("Interfaz", "Cualquier boton sin papel propio, elegir receta en "
              "la tabla, encender un interruptor de Opciones y el "
              "\u00a1Empezar! del nivel", "usuario"),
    "atras": ("Interfaz", "Atras, Salir, Terminar, cancelar una elaboracion y "
              "APAGAR un interruptor. Es el mismo clic con el tono bajado",
              "usuario"),
    "ok": ("Interfaz", "El visto verde fuera de las ventanas emergentes (la "
           "misma toma que las cajas de recurso)", "usuario"),
    "modo": ("Interfaz", "Los cuatro pergaminos del menu: Aventura, Arcade, "
             "Pesca y Tienda", "usuario"),
    "submenu": ("Interfaz", "Los cinco accesos de la barra de abajo (logros, "
                "inventario, perfil, bonificadores y opciones) y SELECCIONAR un "
                "ingrediente en la tabla", "usuario"),
    "recurso": ("Interfaz", "Cajas de lingotes, doblones y arroz, barra de "
                "nivel, mejorar un bonificador, poner un extra al plato, y "
                "CUALQUIER ventana emergente al abrirse", "usuario"),
    "recurso_off": ("Interfaz", "Cancelar en una ventana emergente, quitar un "
                    "extra del plato y extra sin despensa. Misma toma con el "
                    "tono GRAVE", "usuario"),
    "recurso_ok": ("Interfaz", "Confirmar en una ventana emergente. Misma toma "
                   "con el tono AGUDO", "usuario"),
    "aviso": ("Interfaz", "Pulsar un modo todavia bloqueado", "usuario"),
    "aviso_off": ("Interfaz", "Cerrar ese aviso. Misma pareja de ventana, mas "
                  "grave", "usuario"),
    "corte_mal": ("Interfaz", "El corte lento se ha hecho demasiado rapido",
                  "usuario"),
    "pantalla": ("Interfaz", "El mapa del bonus diario al desplegarse",
                 "audio"),
    "timon": ("Interfaz", "El timon del menu: un chasquido cada vez que un "
              "mango pasa por arriba (8 por vuelta)", "usuario"),
    # --- premios y dinero ---
    "logro": ("Premios", "Medalla de logro conseguida", "usuario"),
    "trofeo": ("Premios", "La ventana con el resumen de la subida de nivel",
               "audio"),
    "premio": ("Premios", "Receta nueva, coleccionable y captura de pesca",
               "audio"),
    "cofre": ("Premios", "La TAPA del cofre: bonus diario, pesca y reclamo de "
              "logros", "usuario"),
    "cofre_llave": ("Premios", "La CERRADURA, a la vez que la tapa", "usuario"),
    "moneda": ("Premios", "Un cliente PAGA su plato (al 85% de velocidad)",
               "usuario"),
    "monedas": ("Premios", "Cobrar los logros de UNA tarjeta", "audio"),
    "tesoro": ("Premios", "Cobrar una tarjeta de 200+ doblones", "audio"),
    "monedas_todo": ("Premios", "Reclamar TODO, cuando el cofre se abre (al "
                     "60% de velocidad)", "usuario"),
    "exp": ("Premios", "Mientras sube la barra de experiencia. Su velocidad se "
            "ajusta a lo que tarde la barra", "usuario"),
    "levelup": ("Premios", "El cocinero sube de nivel", "usuario"),
    "habilidad": ("Premios", "Se desbloquea una habilidad del arbol",
                  "usuario"),
    # --- cocina ---
    "arroz": ("Cocina", "Golpes en la tabla al moldear el arroz. Van MUY "
              "rapidos (tono 1.70)", "usuario"),
    "corte": ("Cocina", "Cada golpe de cuchillo del corte rapido", "usuario"),
    "corte_lento": ("Cocina", "BUCLE mientras el dedo avanza en el corte lento; "
                    "se pausa al parar y sigue por donde iba", "usuario"),
    "enrollar": ("Cocina", "Enrollar la esterilla y extender", "usuario"),
    "mantener": ("Cocina", "BUCLE al mantener apretado (calentar)", "usuario"),
    "remover": ("Cocina", "BUCLE al remover o mezclar", "usuario"),
    "freir": ("Cocina", "BUCLE mientras se frie en la sarten", "usuario"),
    "soplete": ("Cocina", "BUCLE del soplete del aburi", "usuario"),
    "soltar": ("Cocina", "Soltar el ingrediente sobre la tabla", "usuario"),
    "listo": ("Cocina", "El plato queda terminado", "usuario"),
    "agarrar": ("Cocina", "Agarrar un plato ya terminado, este en la tabla o "
                "en una caja. La caja que se queda VACIA no suena", "usuario"),
    "cinta": ("Cocina", "El plato sale a la cinta", "usuario"),
    "guardar": ("Cocina", "Soltar un plato en una caja", "usuario"),
    "basura": ("Cocina", "El plato da la vuelta entera y cae al cubo",
               "usuario"),
    "quemado": ("Cocina", "Fritura pasada o cruda: el plato se pierde",
                "usuario"),
    "perfecto": ("Cocina", "Fritura clavada en el punto exacto", "usuario"),
    # --- barco y mar ---
    "velas": ("Barco y mar", "Zarpar de la portada, salir hacia Aventura, "
              "Arcade o Tienda, y el boton Viajar del mapa. En PESCA no suena",
              "usuario"),
    "barco_mover": ("Barco y mar", "El casco al ponerse en marcha, y en el mapa "
                    "durante todo el viaje entre niveles (con fundido y tono "
                    "sorteado)", "usuario"),
    "barco_cruje": ("Barco y mar", "El casco crujiendo cada 9-17 s en la "
                    "portada y en el menu, y al pulsar Zarpar", "usuario"),
    "gaviota": ("Barco y mar", "Una gaviota cada 7-16 s, SOLO en el menu y el "
                "mapa. Nunca en la portada", "usuario"),
    "zarpar": ("Barco y mar", "Las campanas del barco: pulsar en la portada y "
               "el boton Zarpar del selector de recetas", "usuario"),
    # --- avisos de la jornada ---
    "fin_turno": ("Jornada", "LA CAMPANA DE LA JORNADA: suena al acabarse la "
                  "preparacion (empieza el servicio) y al cerrarse el turno. "
                  "Es la misma a proposito", "usuario"),
    "estrella": ("Jornada", "Cada estrella del cartel de resultados: la 1a al "
                 "75% de velocidad, la 2a al 85% y la 3a al 100%", "usuario"),
    "bar_estrella": ("Jornada", "1a y 2a estrella de la barra del oro en "
                     "partida (la primera mas grave)", "usuario"),
    "bar_estrella3": ("Jornada", "3a estrella de la barra del oro: la meta",
                      "usuario"),
    "calavera": ("Jornada", "Un cliente se va sin probar bocado, o el jefe "
                 "cobra un fallo", "usuario"),
    "potenciador": ("Jornada", "Sale el cartel de potenciador o de mejora. Es "
                    "la toma de la habilidad, mas grave", "usuario"),
}

SECCIONES = ["Interfaz", "Premios", "Cocina", "Barco y mar", "Jornada"]

MUSICA = [
    ("menu", "Menu principal Y mapa de Aventura (comparten tema)"),
    ("tienda", "El puesto de Saverio"),
    ("arcade", "El arcade sin fin"),
    ("pesca", "El minijuego de pesca"),
    ("isla", "Niveles de tipo ISLA"),
    ("puerto", "Niveles de tipo PUERTO"),
    ("abordaje", "Niveles de tipo ABORDAJE"),
    ("cueva", "La Cueva del Kappa (el jefe)"),
    ("tutorial", "La intro del caos (el tutorial). Sono al de abordaje y "
                 "ahora tiene el suyo: alli el jugador pelea, aqui pierde "
                 "a proposito"),
    ("resultados", "El cartel de fin de jornada (no es un sitio, es un "
                   "momento: lo pide el cartel y lo releva la pantalla "
                   "siguiente)"),
]



## El reproductor. Los botones no llevan `onclick` inline —los nombres de
## archivo traen espacios y guiones y romperian las comillas— sino
## `data-src`/`data-db`, y un solo escuchador delegado en el documento.
##
## El volumen por defecto es el que el sonido tiene DENTRO DEL JUEGO (su dB de
## familia mas el ajuste general), que es lo que hay que juzgar; el
## interruptor de arriba lo pone a tope para comparar. Un dB positivo se
## recorta a 1: el navegador no sube por encima del original.
JS = """
<script>
(function(){
  var actual = null, boton = null;
  function parar(){
    if (actual) { actual.pause(); actual = null; }
    if (boton) { boton.classList.remove('on'); boton = null; }
  }
  document.addEventListener('click', function(e){
    var b = e.target.closest('.pl');
    if (!b) return;
    var era = (b === boton);
    parar();
    if (era) return;
    var a = new Audio(b.dataset.src);
    var db = parseFloat(b.dataset.db || '0');
    a.volume = document.getElementById('orig').checked
      ? 1 : Math.max(0, Math.min(1, Math.pow(10, db / 20)));
    a.addEventListener('ended', parar);
    a.play().catch(function(){});
    actual = a; boton = b; b.classList.add('on');
  });
})();
</script>
"""


## Cuanto dura un .ogg SIN ffmpeg: la ultima pagina Ogg trae el granulepos
## (muestras acumuladas) y la cabecera de identificacion de Vorbis la
## frecuencia. Son veinte lineas y ahorran depender de una herramienta
## externa solo para poner una cifra en una tabla.
def dura_ogg(ruta):
    try:
        d = io.open(ruta, "rb").read()
    except Exception:
        return 0.0
    i = d.find(b"vorbis")
    if i < 0:
        return 0.0
    rate = int.from_bytes(d[i + 12:i + 16], "little")
    j = d.rfind(b"OggS")
    if j < 0 or not rate:
        return 0.0
    gran = int.from_bytes(d[j + 6:j + 14], "little")
    return gran / float(rate)


def boton(ruta, db, etiqueta=""):
    """Un boton de reproduccion. `ruta` es relativa a la pagina."""
    trozos = [_url(t) for t in ruta.split("/")]
    return ("<button class='pl' data-src='%s' data-db='%.1f' "
            "title='%s'>%s</button>"
            % ("/".join(trozos), db, ruta.split("/")[-1],
               ("<b>%s</b>" % etiqueta) if etiqueta else "&#9654;"))


def _url(t):
    # El % va el PRIMERO: si no, se re-escapa el que introducen los demas
    # (un espacio pasa a "%20" y ese % se convertiria en "%2520").
    fuera = "% &()'#?+"
    for c in fuera:
        t = t.replace(c, "%%%02X" % ord(c))
    return t


def lee_audio():
    s = io.open(os.path.join(RAIZ, "scripts", "audio.gd"),
                encoding="utf-8").read().replace("\r\n", "\n")
    fam_txt = s[s.index("const FAMILIAS := {"):s.index("## LAS FAMILIAS QUE")]
    familias = {}
    # LAS RUTAS SE COMPONEN CON CONSTANTES (`IF_ + "algo.ogg"`), asi que hay
    # que capturar TAMBIEN el prefijo: quedandose solo con lo entrecomillado se
    # pierde la carpeta y los enlaces de la pagina salen rotos.
    carpetas = {"IF_": "interfaz", "CO_": "cocina", "NI_": "nivel",
                "BA_": "barco"}
    for m in re.finditer(r'^\t"([a-z_0-9]+)": \[(.*?)\],$', fam_txt, re.S | re.M):
        familias[m.group(1)] = [
            "%s/%s" % (carpetas[pre], f)
            for pre, f in re.findall(r'(IF_|CO_|NI_|BA_) \+ "([^"]+\.ogg)"',
                                     m.group(2))]
    vol_txt = s[s.index("const VOL := {"):s.index("## AJUSTE GENERAL")]
    vol = dict((k, float(v)) for k, v in
               re.findall(r'"([a-z_0-9]+)": (-?[\d.]+)', vol_txt))
    tono_txt = s[s.index("const TONO := {"):s.index("## LAS FAMILIAS QUE")]
    tono = dict((k, float(v)) for k, v in
                re.findall(r'"([a-z_0-9]+)": ([\d.]+)', tono_txt))
    ajuste = float(re.search(r"const AJUSTE := (-?[\d.]+)", s).group(1))
    mus_db = float(re.search(r"const MUS_DB := (-?[\d.]+)", s).group(1))
    voz_db = float(re.search(r"const VOZ_DB := (-?[\d.]+)", s).group(1))
    varian = re.findall(r'"([a-z_0-9]+)"',
                        re.search(r"const VARIAN := \[(.*?)\]", s, re.S).group(1))
    bucle = re.findall(r'"([a-z_0-9]+)": true',
                       re.search(r"const TEMAS_BUCLE := \{(.*?)\}",
                                 s, re.S).group(1))
    final = re.findall(r'"([a-z_0-9]+)": true',
                       re.search(r"const TEMAS_FINAL := \{(.*?)\}",
                                 s, re.S).group(1))
    return (familias, vol, tono, ajuste, varian, mus_db, voz_db,
            bucle, final)


## LA PESCA ES ANTERIOR AL DIRECTOR DE AUDIO y conserva su propio banco: sus
## rutas y sus volumenes viven en `fishing_game.gd` (SND, SND_EFECTO,
## SND_BUCLE...), no en `audio.gd`. Se leen de alli para que la lista los
## incluya igual.
PESCA_CUANDO = {
    "cebo": "Se abre el intento: se saca el cebo de la caja",
    "lanzar": "El latigazo de la cana al lanzar",
    "boya": "La boya toca el agua",
    "chapoteo": "La picada, la presa que se suelta y el pez al salir del agua "
                "(la misma toma a tres tonos)",
    "amago": "El pez amaga con picar y se retira",
    "recoger": "BUCLE al recoger el sedal antes de la picada, y en el tiron",
    "carrete": "BUCLE del carrete durante el tiron",
    "arrastre": "BUCLE mientras el jugador recoge en la pelea",
    "sedal_pez": "BUCLE cuando el pez se lleva sedal",
    "tiron": "El golpe que anuncia el tiron",
    "rotura": "El sedal se rompe (una sola toma)",
}


def lee_pesca():
    s = io.open(os.path.join(RAIZ, "scripts", "fishing_game.gd"),
                encoding="utf-8").read().replace("\r\n", "\n")
    txt = s[s.index("const SND := {"):]
    txt = txt[:txt.index("\n}\n")]
    fam = {}
    for m in re.finditer(r'^\t"([a-z_0-9]+)": \[(.*?)\],$', txt, re.S | re.M):
        fam[m.group(1)] = [r.replace("res://sounds/juego/", "")
                           for r in re.findall(r'"([^"]+\.ogg)"', m.group(2))]
    return fam


def cuenta_voces():
    d = os.path.join(RAIZ, "sounds", "juego", "voces")
    n = 0
    pers = []
    if os.path.isdir(d):
        for p in sorted(os.listdir(d)):
            k = len([f for f in os.listdir(os.path.join(d, p))
                     if f.endswith(".ogg")])
            n += k
            pers.append((p, k))
    return n, pers


def peso(sub):
    d = os.path.join(RAIZ, "sounds", "juego", sub)
    t = 0
    for raiz, _, fs in os.walk(d):
        for f in fs:
            if f.endswith(".ogg"):
                t += os.path.getsize(os.path.join(raiz, f))
    return t / 1048576.0


CSS = """
:root{--fondo:#1a120b;--panel:#241a10;--linea:#3d2c1a;--texto:#efe2cd;
--suave:#b8a488;--oro:#e8b44a;--rojo:#c85a3c;--verde:#7fae5a}
*{box-sizing:border-box}
body{margin:0;padding:0 16px 64px;background:var(--fondo);color:var(--texto);
font:16px/1.55 "Segoe UI",system-ui,sans-serif}
.wrap{max-width:1000px;margin:0 auto}
h1{font-size:30px;margin:36px 0 4px;color:var(--oro)}
h2{font-size:22px;margin:38px 0 10px;color:var(--oro);
border-bottom:1px solid var(--linea);padding-bottom:6px}
.sub{color:var(--suave);margin:0 0 22px}
.leyenda{background:var(--panel);border:1px solid var(--linea);border-radius:8px;
padding:14px 18px;margin:22px 0}
.leyenda p{margin:6px 0}
table{width:100%;border-collapse:collapse;margin:0 0 8px;font-size:15px}
th{text-align:left;color:var(--suave);font-weight:600;padding:8px 10px;
border-bottom:1px solid var(--linea);white-space:nowrap}
td{padding:9px 10px;border-bottom:1px solid #2c2013;vertical-align:top}
tr:last-child td{border-bottom:none}
code{background:#2c2013;padding:1px 6px;border-radius:4px;font-size:13px;
color:#e8d8bd}
.db{white-space:nowrap;font-variant-numeric:tabular-nums;text-align:right}
.q{white-space:nowrap;font-size:13px;font-weight:600}
.usuario{color:var(--oro)}
.audio{color:var(--suave)}
.nota{color:var(--suave);font-size:14px;margin:10px 0 0}
.pill{display:inline-block;background:#2c2013;border:1px solid var(--linea);
border-radius:20px;padding:2px 10px;font-size:13px;margin:2px 4px 2px 0}
.pl{background:#3a2a18;border:1px solid #5a422a;color:var(--oro);cursor:pointer;
border-radius:50%;width:30px;height:30px;font-size:12px;padding:0;margin:2px 3px 2px 0;
line-height:1;vertical-align:middle;transition:background .12s,transform .12s}
.pl:hover{background:#4d3821}
.pl:active{transform:scale(.9)}
.pl.on{background:var(--oro);color:#1a120b;border-color:var(--oro)}
.pl b{font-size:11px;font-weight:700}
.tomas{white-space:nowrap}
.barra{position:sticky;top:0;z-index:5;background:var(--fondo);
border-bottom:1px solid var(--linea);padding:10px 0;margin-bottom:4px}
.barra label{color:var(--suave);font-size:14px;cursor:pointer;user-select:none}
.barra input{vertical-align:-2px;margin-right:6px}
details{background:var(--panel);border:1px solid var(--linea);border-radius:8px;
padding:8px 14px;margin:8px 0}
summary{cursor:pointer;color:var(--oro);font-weight:600;padding:4px 0}
.expr{display:flex;align-items:center;gap:6px;padding:4px 0;font-size:14px}
.expr span{color:var(--suave);min-width:130px}
@media (max-width:700px){body{font-size:15px}table{font-size:13.5px}
th,td{padding:7px 6px}}
"""


def html():
    (familias, vol, tono, ajuste, varian, mus_db, voz_db,
     bucle, final) = lee_audio()
    voces_n, voces_p = cuenta_voces()
    o = []
    a = o.append
    a("<!doctype html><html lang='es'><head><meta charset='utf-8'>")
    a("<meta name='viewport' content='width=device-width,initial-scale=1'>")
    a("<title>Sushi Pirata - sonidos del juego</title>")
    a("<style>%s</style></head><body><div class='wrap'>" % CSS)
    a("<div class='barra'><label><input type='checkbox' id='orig'>"
      "Escuchar a volumen ORIGINAL del archivo (sin el volumen que tiene "
      "dentro del juego)</label></div>")
    a("<h1>Sushi Pirata &mdash; sonidos del juego</h1>")
    a("<p class='sub'>Todo lo que suena, cuando suena y a que volumen. "
      "Los volumenes y las tomas salen leidos de <code>scripts/audio.gd</code>, "
      "asi que esta lista no puede contradecir al juego.</p>")

    a("<div class='leyenda'>")
    a("<p><span class='q usuario'>&#9679; usuario</span> &mdash; sonido o regla "
      "que pidio el usuario expresamente.</p>")
    a("<p><span class='q audio'>&#9679; audio</span> &mdash; lo eligio quien "
      "monto el audio, sin instruccion concreta.</p>")
    a("<p><b>dB</b> es el volumen de la familia. <b>Efectivo</b> le suma el "
      "ajuste general de <code>%+.0f dB</code>, que baja todos los efectos de "
      "una vez.</p>" % ajuste)
    a("<p>Las familias marcadas con <code>&#9834;</code> sortean toma y mueven "
      "el tono en cada disparo: son las de cocina, donde el mismo gesto se "
      "repite decenas de veces. La interfaz hace lo contrario &mdash; un sonido "
      "por papel y siempre el mismo.</p>")
    a("</div>")

    # --- musica
    a("<h2>Musica &mdash; %d temas</h2>" % len(MUSICA))
    a("<p class='nota'>El usuario decidio QUE pantalla lleva cada tema y como "
      "tiene que sonar cada uno; las piezas se generaron para el juego. La "
      "portada no lleva musica: solo el mar.</p>")
    a("<table><tr><th>Tema</th><th>Donde suena</th><th class='db'>Dura</th>"
      "<th>Vuelta</th></tr>")
    for k, cuando in MUSICA:
        rel = "sonidos/musica/%s.ogg" % k
        d = dura_ogg(os.path.join(RAIZ, "sounds", "juego", "musica",
                                  "%s.ogg" % k))
        vuelta = ("suena entera y empieza otra vez" if k in final
                  else "bucle sin costura" if k in bucle else "cruzado")
        a("<tr><td>%s <code>%s</code></td><td>%s</td>"
          "<td class='db'>%d:%02d</td><td>%s</td></tr>"
          % (boton(rel, mus_db), k, cuando, int(d) // 60, int(d) % 60,
             vuelta))
    a("</table>")
    a("<p class='nota'>Todos NIVELADOS: el juego entero suena a la misma "
      "sonoridad medida (-28 LKFS con 0,1 dB de dispersion; antes habia 37,9 "
      "dB entre el sonido mas flojo y el mas fuerte). Lo calcula "
      "<code>tools/audio_nivelar.py</code> con ponderacion K. Los de "
      "<b>bucle sin costura</b> llevan el .ogg cosido para repetirse "
      "(<code>tools/musica_bucle.py</code> busca el punto donde la musica "
      "vuelve a sonar como al principio, corta ahi y envuelve la cabeza con "
      "su propia continuacion), asi que el bucle lo lleva el motor y no se "
      "nota. El de <b>resultados</b> es el unico con final de verdad: se le "
      "monto el cierre a mano (<code>tools/musica_cierre.py</code>) porque el "
      "generador devolvia la pieza cortada a media frase.</p>")

    # --- efectos por seccion
    for sec in SECCIONES:
        filas = [(k, v) for k, v in CUANDO.items() if v[0] == sec
                 and k in familias]
        if not filas:
            continue
        a("<h2>%s &mdash; %d sonidos</h2>" % (sec, len(filas)))
        a("<table><tr><th>Oir</th><th>Familia</th><th>Cuando suena</th>"
          "<th class='db'>dB</th><th class='db'>Efectivo</th>"
          "<th>Quien</th></tr>")
        for k, (_, cuando, quien) in sorted(filas):
            marca = " &#9834;" if k in varian else ""
            tomas = len(familias[k])
            extra = " <span class='pill'>%d tomas</span>" % tomas if tomas > 1 else ""
            if k in tono:
                extra += " <span class='pill'>tono %.2f</span>" % tono[k]
            efec = vol.get(k, 0.0) + ajuste
            botones = []
            for n, ruta in enumerate(familias[k], 1):
                rel = "sonidos/" + ruta
                botones.append(boton(rel, efec, str(n) if tomas > 1 else ""))
            a("<tr><td class='tomas'>%s</td><td><code>%s</code>%s%s</td>"
              "<td>%s</td><td class='db'>%+.0f</td><td class='db'>%+.0f</td>"
              "<td class='q %s'>%s</td></tr>"
              % ("".join(botones), k, marca, extra, cuando,
                 vol.get(k, 0.0), efec, quien, quien))
        a("</table>")

    # --- el mar (es AMBIENTE, no una familia de efectos)
    a("<h2>El mar de fondo</h2>")
    a("<p class='nota'>No es un efecto sino un AMBIENTE en bucle, y el mismo "
      "archivo suena a tres alturas seg&uacute;n d&oacute;nde est&eacute;s. "
      "Su vuelta se cruza consigo misma para que no se note el corte. "
      "<span class='q usuario'>&#9679; usuario</span></p>")
    a("<table><tr><th>Oir</th><th>D&oacute;nde</th>"
      "<th class='db'>dB</th></tr>")
    for donde, db in [("Portada (es lo &uacute;nico que suena)", -15.0),
                      ("Men&uacute; principal y mapa", -26.0),
                      ("Dentro de un nivel", -35.0)]:
        a("<tr><td>%s</td><td>%s</td><td class='db'>%+.0f</td></tr>"
          % (boton("sonidos/barco/ocean.ogg", db), donde, db))
    a("</table>")

    # --- la pesca, con su propio banco
    pesca = lee_pesca()
    a("<h2>Pesca &mdash; %d sonidos</h2>" % len(pesca))
    a("<p class='nota'>El minijuego de pesca es ANTERIOR al director de audio "
      "y conserva su propio banco: sus tomas y sus vol&uacute;menes viven en "
      "<code>fishing_game.gd</code>, no en <code>audio.gd</code>. Las tomas "
      "las eligi&oacute; el usuario a o&iacute;do en su momento. "
      "<span class='q usuario'>&#9679; usuario</span></p>")
    a("<table><tr><th>Oir</th><th>Familia</th><th>Cuando suena</th></tr>")
    for k in sorted(pesca):
        bots = []
        for n, ruta in enumerate(pesca[k], 1):
            bots.append(boton("sonidos/" + ruta, -10.0,
                              str(n) if len(pesca[k]) > 1 else ""))
        a("<tr><td class='tomas'>%s</td><td><code>%s</code></td><td>%s</td></tr>"
          % ("".join(bots), k, PESCA_CUANDO.get(k, "")))
    a("</table>")

    # --- voces
    a("<h2>Voces &mdash; %d clips</h2>" % voces_n)
    a("<p class='nota'>Tres sonidos por cada expresion de cada personaje. Son "
      "SONIDOS, no frases: el personaje no lee su linea, la acompana. Suenan "
      "al cambiar de linea en un dialogo, con la cara que trae esa linea. "
      "<span class='q usuario'>&#9679; usuario</span> pidio que fueran solo "
      "sonidos.</p>")
    raiz_v = os.path.join(RAIZ, "sounds", "juego", "voces")
    for pers, n in voces_p:
        a("<details><summary>%s &mdash; %d clips</summary>" % (pers, n))
        moods = {}
        for f in sorted(os.listdir(os.path.join(raiz_v, pers))):
            if not f.endswith(".ogg"):
                continue
            base = f[:-4]
            moods.setdefault(base.rsplit("_", 1)[0], []).append(f)
        for mood in sorted(moods):
            fila = ["<div class='expr'><span>%s</span>" % mood]
            for i, f in enumerate(sorted(moods[mood]), 1):
                fila.append(boton("sonidos/voces/%s/%s" % (pers, f), voz_db,
                                  str(i)))
            fila.append("</div>")
            a("".join(fila))
        a("</details>")

    # --- lo que NO suena
    a("<h2>Lo que a proposito NO suena</h2>")
    a("<table><tr><th>Que</th><th>Por que</th><th>Quien</th></tr>")
    for que, por, quien in [
        ("Los clientes: llegar, sentarse, coger plato, masticar, irse",
         "Con ocho bocas a la vez el nivel era un gallinero y tapaba la cocina. "
         "Solo se oye la moneda cuando pagan", "usuario"),
        ("El paso completado de una receta",
         "Una receta son hasta seis pasos y un tintineo en cada uno llenaba la "
         "elaboracion de avisos que no dicen nada", "usuario"),
        ("El crujido continuo del timon",
         "Sobre el crujido del casco, que ya suena de fondo, eran dos maderas "
         "quejandose a la vez", "usuario"),
        ("El tecleo de la maquina de escribir del dialogo",
         "Once clics por segundo mientras el texto aparece", "audio"),
        ("El roce de vela en cada cambio de pantalla",
         "El clic del boton ya marca el cambio", "audio"),
        ("La propina",
         "Cae en el mismo instante que el pago del plato y se oian dos monedas "
         "encima de la otra", "audio"),
    ]:
        a("<tr><td>%s</td><td>%s</td><td class='q %s'>%s</td></tr>"
          % (que, por, quien, quien))
    a("</table>")

    # --- peso
    a("<h2>Peso</h2>")
    a("<table><tr><th>Seccion</th><th class='db'>MB</th></tr>")
    total = 0.0
    for sub in ["musica", "voces", "pesca", "barco", "cocina", "interfaz",
                "nivel"]:
        p = peso(sub)
        total += p
        a("<tr><td><code>sounds/juego/%s</code></td>"
          "<td class='db'>%.2f</td></tr>" % (sub, p))
    a("<tr><td><b>Total</b></td><td class='db'><b>%.2f</b></td></tr>" % total)
    a("</table>")
    a("<p class='nota'>Todo en OGG Vorbis. Las librerias de las que se picotea "
      "viven en <code>sounds/Sin utilizar/</code> y no viajan al juego.</p>")
    a(JS)
    a("</div></body></html>")
    return "\n".join(o)


if __name__ == "__main__":
    destino = sys.argv[1] if len(sys.argv) > 1 else os.path.join(RAIZ, "_sonidos.html")
    io.open(destino, "w", encoding="utf-8").write(html())
    print("escrito %s (%d bytes)" % (destino, os.path.getsize(destino)))
