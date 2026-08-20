# Sushi Pirata — guía del proyecto

Juego móvil **vertical (720×1280)**, 2D isométrico voxel/pixelart, de **estrategia y
gestión en tiempo real**. El jugador es el cocinero de un barco pirata que sirve
sushi en una **cinta transportadora kaiten** a clientes con comportamientos
distintos. **Cada tipo de nivel se cierra de una manera** (ver más abajo): los
ABORDAJES van contra reloj (2 min 30 s, clientela sin fin) y las ISLAS y PUERTOS no
tienen reloj: los acota la clientela. Motor: **Godot 4.7.1**.

El núcleo NO es cocinar rápido, sino **gestionar la cinta, los recursos, las
recetas (cada una una herramienta con propiedades) y el comportamiento de los
clientes** para maximizar beneficios. Toda mecánica nueva debe reforzar ese núcleo.

## Cómo ejecutar y verificar (NO hay editor abierto de forma fiable)

Godot está en `C:/Users/KOPURISTA/Desktop/GODOT/Godot_v4.7.1-stable_win64.exe/`
(es una carpeta que contiene los .exe).

- **Comprobar errores de compilación** (rápido, headless):
  `"…/Godot_v4.7.1-stable_win64_console.exe" --headless --quit-after 250 "res://scenes/level.tscn"`
  Sin salida = OK. Repetir con la escena de menú (sin argumento) también.
- **Importar** antes de usar: `--headless --import`. No es solo para assets —
  un script NUEVO con `class_name` tampoco existe hasta importar, porque las
  clases globales se registran en `.godot/global_script_class_cache.cfg`. Sin
  esa pasada, quien la use da `Identifier "X" not declared in the current
  scope`, que es error de COMPILACIÓN: la escena no monta y el juego se cierra.
- **Si el juego CRASHEA (signal 11) al cargar un `.glb`**, mirar antes los
  avisos `invalid UID … using text path instead`: significan que las texturas
  se reimportaron (p. ej. al pasarlas a Basis) y cogieron un UID nuevo, pero
  los `.glb` importados siguen guardando el viejo. `--headless --import` NO lo
  arregla solo, porque el `.glb` ya está importado y Godot no lo rehace: hay
  que **borrar `.godot/imported/*.glb-*.scn` y reimportar**. Pasó de verdad y
  reventaba al servir un plato a la cinta.
- **Verificación visual**: inyectar un nodo helper temporal con un script que
  fuerce estado (`lv.prep_phase = false`, `_try_spawn_client()`, `_on_dish_served()`)
  y guarde `get_viewport().get_texture().get_image().save_png("res://shot.png")`,
  correr SIN `--headless`, y leer el PNG. **Limpiar siempre el helper después.**
  **El helper va en un nodo aparte, NUNCA dentro de un script de producción.**
  Pasó lo contrario: `main_menu.gd` se quedó con un `_shots_at := [2.0]` y su
  `_capture_step()` que llamaba a `get_tree().quit()`, así que el juego se
  cerraba solo a los 2 s (`level3d.gd` y `level_select3d.gd` tenían el mismo
  bloque, inerte por lista vacía). Un helper soldado al script se escapa a la
  limpieza y NO da ningún error, solo un cierre silencioso: si el juego se
  cierra sin mensaje, buscar `get_tree().quit()` y `save_png` antes que nada.
- `--script` NO carga autoloads (`GameState`), así que no sirve para probar
  escenas que dependan de ellos; usa el helper inyectado en su lugar.
- **SI UNA SONDA "SE CUELGA" SIN ERROR Y CON LA CPU EN REPOSO, mirar la
  DESPENSA del guardado antes que nada.** Un nivel cuyas recetas no tienen
  usos REBOTA a prep_screen con `change_scene_to_file.call_deferred` — y ese
  cambio de escena LIBERA a la sonda (que es la escena actual): su log se
  calla, nadie llama a `quit()` y el proceso se queda idle para siempre. Se
  perdió una noche persiguiendo un "deadlock" (¡con reinicio del ordenador
  incluido!) que era el aguacate a 0: cada pasada de la sonda consume 1 uso,
  así que la N-ésima repetición "congela" lo que la primera pasó. Las sondas
  de nivel rellenan `GameState.ingredients` de sus recetas al arrancar.
- **Lanzar el juego** para el usuario: `"…/Godot_v4.7.1-stable_win64.exe" .` en background.
- Existe el MCP **GodotIQ** (`godotiq_*`) pero se desconecta a ratos; cuando no
  esté, se editan `.tscn`/`.gd` con las herramientas nativas (el `.tscn` ya se
  guardó alguna vez desde el editor: trae `uid`/`unique_id`, respétalos).
- El input usa eventos **táctiles** (`InputEventScreenTouch`/`ScreenDrag`) porque
  `project.godot` tiene `pointing/emulate_touch_from_mouse=true`.

## Contratos entre archivos (señales) — leer antes de editar

- `prep_board.gd` → `dish_served(recipe_id, price_override, extras,
  level_override, eat_mult_override)`: un plato sale a la cinta. Los cuatro
  últimos los usa el BARCO, que no vale, ni llena, ni se tarda en comer lo que
  dice su ficha: todo eso depende de los platos que lleve dentro.
- `prep_board.gd` → `craft_event(kind: String, stage_id: String)`: cada gesto
  del jugador; `level.gd` lo usa para animar al chef y mostrar la etapa en su mesa.
  `kind` ∈ tap/cut/swipe/hold/stir/slice/drag/stage/done/select/cancel/serve.
- `client.gd` → `plate_served(food: int, tip: int)`: al terminar CADA plato; el
  nivel suma AL INSTANTE el precio del plato al dinero (estrellas + monedero) y
  envía la propina SOLO al bote de potenciadores (la propina NO cuenta como
  dinero generado). La propina se tira por plato (cuantía = % del precio de ESE
  plato).
- `client.gd` → `finished(report: Dictionary)`: al irse; el diccionario lleva
  `type, money, tip (totales acumulados, ya cobrados), penalty, eaten (ids),
  satiety_eaten`. `level.gd` NO vuelve a sumar estos totales (evita el doble
  conteo): solo los usa para el desglose de resultados. `penalty` SÍ lo cobra
  el nivel al recibirlo (ver castigo por irse de vacío en el balance).
- `level3d.gd` accede a `prep_board.instant_recipes / double_next / stack_max /
  cooldown_mult / add_storage_slot()` para aplicar potenciadores. (`skip_next_cooldown`
  y `easy_next` se fueron con los potenciadores manuales que los encendían, y
  con ellos `_simplify_steps` y `recycle_recipe`.)

## LA CAMPAÑA: EL MAR 1 SON 20 ESCENARIOS (reparto del 19-8-2026)

**9 islas, 6 puertos, 4 abordajes y 1 CUEVA** (el tipo nuevo, reservado a los
jefes). El detalle en la cabecera de `campaign_data.gd`; los ids NO se
renumeran (el número que ve el jugador es la posición en `PORTS`).

| # | Escenario | Tipo | Lección |
|---|---|---|---|
| 1 | Cala Tortuga | isla | paciencia, bocado, oro y papelera |
| 2 | Playa del Coco | isla | las CAJAS (4 platos guardados) |
| 3 | Ensenada del Mero | isla | PRÁCTICA |
| 4 | Isla del Bambú | isla | el PICOTEO (edamame) |
| 5 | Arrecife del Ron | puerto | multiplicador, hastío y paladar; abre la TIENDA |
| 6 | Caleta del Farol | isla | PRÁCTICA (3★: despensa de salmón×3 y aguacate×2) |
| 7 | Cala del Calamar | isla | POSTRES, propinas y potenciadores |
| 8 | Bahía del Kraken | puerto | los EXTRAS |
| 9 | Rada del Pulpo | isla | PRÁCTICA (3★: 3 usos de cada extra) |
| 10 | Estrecho del Rayo | abordaje | primer ABORDAJE, EL pirata y su BANDERA |
| 11 | Isla de Gades | isla | CAI y la PESCA |
| 12 | Paso de las Barracudas | abordaje | PRÁCTICA (3★: 1 cebo) |
| 13 | Puerto Tormenta | puerto | SIN lección: el examen antes de Pablo |
| 14 | Flota de Pablo | abordaje | CAPITANES, corte lento y LINGOTES |
| 15 | Cala del Hambre | isla | bocado acelerado y el futomaki |
| 16 | Ensenada del Naufragio | puerto | el capitán del TESORO pide una receta (sin lección) |
| 17 | Rada de los Dos Fuegos | abordaje | ALICE y el AYUDANTE |
| 18 | Muelle de las Bandejas | puerto | ALICE y los BONIFICADORES |
| 19 | Bruma del Estrecho | puerto | la víspera, a pulso |
| 20 | Cueva del Kappa | cueva | el JEFE; superarlo abre el ARCADE |

**LOS HÁNDICAPS SON DEL TIPO, no del escenario** (pedido por el usuario, para
que cada tipo tenga SU dificultad como la isla tiene su carta cerrada):
- **ISLA**: carta cerrada por diseño, y el cliente que se va SIN COMER cuesta
  oro (el `LEAVE_PENALTY` escalado de siempre).
- **PUERTO**: si **3 clientes** se van sin probar bocado, la jornada se
  **PIERDE** (como el arcade: `lost_by_leavers` fuerza 0 estrellas). El
  contador "Vacíos N/3" vive bajo el número de clientes
  (`level3d._setup_vacios_puerto`) — una derrota que no se ve venir no es un
  reto, es una emboscada.
- **ABORDAJE**: cada vacío **resta 15 s** al reloj (`CASTIGO_VACIO_SEG`, con
  su "-15 s" flotando desde el reloj). `time_limit` baja con tope en
  `elapsed`, así que el turno puede acabarse en el acto.
- En PUERTO y ABORDAJE **el vacío NO cuesta oro** (`client3d.penaliza_vacio`,
  apagado por el nivel al crear al cliente): el jugador ya pierde por la vía
  principal del tipo. OJO: el contador de vacíos se separó del castigo — el
  reporte del cliente lleva `"vacio"` aparte de `"penalty"`, porque contando
  por `penalty > 0` (como antes) apagar el oro habría apagado el hándicap.
  El TUTORIAL conserva los castigos de oro (el marcador del caos los necesita).
- **CUEVA**: el tipo de los jefes. Juega como un abordaje (reloj de 2:30 y
  clientela sin fin, `is_timed` la incluye) pero SIN el hándicap del reloj: el
  reto es el jefe. Escenario propio (`_scenery_cueva`) que es INTERIOR de
  verdad: sin mar (`_setup_scenery` lo salta), suelo de roca hasta el borde,
  muros cerrando el fondo y los cantos, estalagmitas Y estalactitas, rocas.glb
  entenebrecidas (`_entenebrecer` multiplica su albedo: la textura es la roca
  de las islas AL SOL y salía como nieve) y CRISTALES que hacen de luz.
  · **NI ESTALACTITAS NI CHARCAS**: las estalactitas colgaban de un techo que
    esta cámara NO enseña, así que se leían como conos flotando por el borde de
    arriba; y las charcas eran dos discos planos tirados en el suelo. Las dos
    cosas se quitaron (pedido por el usuario).
  · **SE MONTA EN COORDENADAS DE PANTALLA (u, w), no de mundo** (`_uw`,
    `_muro_cueva`). Con la cámara a yaw 45 los ejes del mundo salen en
    diagonal: los muros puestos en X/Z cruzaban el encuadre torcidos y el del
    +X asomaba POR ABAJO A LA DERECHA, tapando la barra. En (u, w) el muro del
    fondo es una banda limpia arriba y los laterales dos columnas en los
    cantos. Medidas que gobiernan el sitio de todo: se ve `|u| ≤ 4.78` de
    ancho y `w ∈ [-10.1, 5.8]` de fondo (por debajo lo tapa la tabla), y el
    pasillo de paseo de los clientes es el ROMBO `|u| + |w| = 5.23`, así que
    el decorado va por fuera de 6.3.
  · **LA BOCA DE LA CUEVA VA ARRIBA, EN u = 0** (`_entrada_cueva`): es el
    hueco entre las dos piezas del muro del fondo. Ahí es justo donde aparecen
    los clientes de la borda de arriba (`ENTRY` cae en u=0), así que salen de
    la cueva por su boca en vez de brotar del suelo.
    · **NADA DE MARCO DE PUERTA**: la boca de una cueva no tiene forma exacta,
      así que el contorno lo dibujan PIEZAS SUELTAS de roca a tamaños, fondos y
      VUELCOS distintos — el dintel son seis bloques en ARCO (los de los lados
      bajan, los del centro suben), las jambas seis pilastras ladeadas a tres
      profundidades y al pie unos cascotes que rompen la línea del suelo. Los
      muros del fondo y los laterales van por el mismo camino: en trozos
      desiguales que se SOLAPAN, con vuelcos de 1 a 3 grados.
    · **EL HUECO MIDE 2,6 u, no 3,6**: con el ancho de antes el vano salía de
      270×67 px —más del cuádruple de ancho que de alto— y por muy dentada que
      fuera la roca se leía como una banda. Estrechándolo se lee como una boca.
    · **Y EL VUELCO DE LAS PIEZAS TIENE TECHO**: a 7-14 grados y sin solaparse,
      la pared dejaba de ser pared y pasaba a ser un montón de plaquetas
      sueltas flotando. La roca rota se hace con piezas ANCHAS que se pisan
      unas a otras y se ladean poco.
    · **LA LUZ QUE ENTRA es una TARJETA DE PORTAL** (`shaders/
      portal_cueva.gdshader`, en la línea del "Portal Card (N64 Entrance)" de
      godotshaders): un plano sin sombrear metido en la garganta del túnel, que
      se ve a través del hueco irregular. El original resuelve el borde leyendo
      la PROFUNDIDAD de pantalla y este juego va en COMPATIBILITY, que no sirve
      esa textura: el borde se funde con la propia UV, que para una boca fija
      da lo mismo. **Va a media asta y con el degradado hacia ABAJO**: a plena
      fuerza llenaba el hueco de un gris uniforme y se leía como niebla. Y va
      JUSTO DETRÁS DE LA BOCA (w = -6.85), no al fondo del túnel: cuanto más
      atrás, menos se ve por el hueco.
    · **Y ESA LUZ SALE DE LA BOCA Y ALUMBRA LA CUEVA**: son DOS focos fríos
      —uno en el umbral y otro ya dentro, más suave y de más alcance—, los
      únicos que aquí no son verdes. El de dentro va por delante del muro a
      propósito: sin sombras, una luz de rango largo lo atraviesa y enciende el
      suelo de lado a lado.
  · **Texturas propias en `assets/props`**, dibujadas por código
    (`tools/cave_textures.py`, ruido de valor periódico): `piedra_cueva.webp`
    (moteado suave, suelo) y `pared_cueva.webp` (estratos horizontales, muros;
    van por FILAS porque el triplanar mapea la V sobre la Y del mundo). Son
    SENCILLAS y de poco contraste a propósito: cualquier rasgo reconocible se
    convierte en el motivo que delata el tileado. Seamless por construcción
    (rejilla pequeña tileada 3×3, ampliada con bicúbica y recortado el
    centro); el espejado 2×2 que se probó antes crea una celosía.
  · **LA ESCALA DE TEXTURA ES POR PIEZA, y va en repeticiones POR UNIDAD**
    (`_mat_piedra`, triplanar): 0.34 el suelo, 0.45 los muros y **1.15 los
    conos**, porque a la escala del suelo un cono de 1 u no llega ni a media
    baldosa y salía de color plano. Estuvo a 6 (¡seis baldosas por unidad!) y
    el suelo se leía como una rejilla de puntos.
  · **EL SUELO VA OSCURO Y LOS MUROS CLAROS**, no al revés: el suelo es una
    superficie enorme y plana, así que con el tono de la pared se comía la
    pantalla y se tragaba los charcos de luz. Y el AMBIENTE es quien pinta las
    caras verticales (el sol de la cueva casi no existe): por debajo de 0.9 de
    energía los muros y los conos salían como recortes negros.
  · **LOS CRISTALES LLEVAN LUZ DE VERDAD** (`OmniLight3D` sin sombras, cinco
    de ellos) y shader propio, `shaders/crystal.gdshader` — inspirado en el
    "Crystal Shader" de godotshaders.com: gradiente a lo largo de la pieza,
    vetas de ruido y transparencia, más FRESNEL, que es lo que enciende los
    cantos y lo hace leer como cristal desde esta cámara. Cada cristal es un
    RACIMO de tres agujas. Tres cosas medidas en captura:
    · El charco emisivo pintado a sus pies que hubo antes NO iluminaba nada
      (ni la piedra de al lado ni a los clientes): era una calcomanía.
    · **La emisión no puede pasar de 1**: el renderer Compatibility recorta y
      el cristal se iba a BLANCO. Y el color tiene que ser VERDE de verdad
      (0.22, 0.88, 0.66): con un cian los tres canales llegan arriba a la vez
      y vuelve a salir blanco.
    · **Las luces van CORTAS** (rango ~4.2 + alto): con rango 10 y cinco
      cristales, sus charcos se solapaban y encendían el suelo entero de punta
      a punta, que es lo contrario de lo que se busca.
  · Sin sol no hay sombra que fingir: aquí NO se usan las manchas de
    `blob_shadow` (una elipse oscura de borde duro en mitad de la roca).
  · **EL DECORADO VA CONTADO Y SEPARADO**: seis cristales, cuatro
    estalagmitas, dos rocas y seis cascotes, y ningún par a menos de ~1.3 u.
    Llegó a haber el doble de todo y se amontonaba y se atravesaba: el sitio
    donde cabe algo —la franja entre el rombo del pasillo y el borde de la
    pantalla— es MUY estrecha, así que la lista se escribe a mano y se
    comprueba, no se rellena a ojo.
  · Modelo de mapa propio (`map_cueva.glb`, cadena Ludo completa, presupuesto
    8000) con **ISLOTE de piedra por código** (`level_select3d._base_cueva`:
    el peñasco venía sin suelo y flotaba a corte vivo sobre el agua). Son TRES
    plataformas FACETADAS —pocos lados y giradas entre sí, para que la silueta
    no sea un disco de tarta— y pedruscos rompiendo el canto. **LA PIEDRA SALE
    DEL PROPIO MODELO** (`_textura_de` le saca su primera textura de albedo):
    con la piedra gris azulada de la cueva del NIVEL, el islote y el peñasco
    parecían de dos juegos distintos. **LAS DOS DE ARRIBA VAN CORRIDAS HACIA EL FONDO** y algo más
    bajas, y en la cara delantera no hay pedruscos: centradas le tapaban al
    peñasco la BOCA DE LA CUEVA, que está en su cara de delante y a ras de
    base. NADA de rompiente ni de bajío: el plano del mar es opaco, así que
    lo que quede bajo y=0 no se ve, y el aro claro a ras de agua que se probó
    rodeaba la roca con una fuente blanca.
  · **LA BOCA DEL PEÑASCO SE ENSOMBRECE A MANO** (`BOCA_U/W/Y`, `_base_cueva`):
    el modelo trae su entrada tallada en la cara delantera, pero a ese tamaño
    se perdía entre la roca. Lleva encima una tarjeta oscura de canto fundido
    —el MISMO shader que ilumina la boca dentro del nivel, aquí en negro— que
    la oscurece hacia dentro y la hace leerse como un agujero. **Su sitio va en
    coordenadas de PANTALLA (u, w, y), no en x/y/z de mundo**: puesta con un
    offset de mundo "hacia delante" que en realidad era puro lateral, la
    tarjeta se quedaba DENTRO del peñasco y no se veía.
    **Y VA DETRÁS DE LA CARA DE ROCA, no delante**: flotando por delante se le
    ve el óvalo entero recortado sobre la piedra —el "recuadro de sombra"— por
    muy fundido que lleve el canto. Metida en el hueco, es la PROPIA ROCA la
    que le recorta los bordes y solo asoma lo que se ve por el arco, que es
    justo lo que hay que oscurecer; así puede además ser grande sin miedo.
    Se coloca MIDIENDO: se pinta de magenta, se localiza en la captura, y se
    despeja contra la proyección del mapa (85.3 px por unidad en `u`, 49.3
    hacia abajo por unidad en `w` y 69.7 hacia arriba por unidad en `y`, que la
    sonda imprime con `cam.unproject_position`). **Y las plataformas van BAJAS** (sus
    cimas rondan y=0): subidas, le tapaban la boca al peñasco.
  · **EN EL MAPA LA RODEA LA NIEBLA** (`level_select3d._niebla_cueva`,
    pedido por el usuario): la guarida del jefe tiene que dar respeto desde el
    mapa. Va en DOS piezas y hacen falta las dos — un **MANTO** de dos planos
    TUMBADOS sobre el agua girando despacio en sentidos contrarios (el velo de
    base: los jirones van y vienen, y sin él hay instantes en que la cueva se
    queda limpia) y seis **JIRONES** en cartel orbitando bajos, la mitad de
    ellos POR DELANTE de la roca (`NIEBLA_DENTRO`, hacia la cámara), que es lo
    único que de verdad la difumina. Tres cosas medidas:
    · El dibujo va HORNEADO (`tools/niebla_tex.py`), no por shader: no cambia,
      solo se mueve.
    · **Los nodos van en el grupo `no_batch`**: `GeometryBatch.bake` funde la
      geometría estática del mapa y LIBERA los originales — los jirones salían
      como "previously freed" y no se movían nunca.
    · **La opacidad se MULTIPLICA por el alfa del dibujo** (medio 53/255), así
      que el 0.42 del primer intento daba un 9% efectivo: invisible. Y los
      radios van CORTOS (0.5-0.95 de la huella): a 1.55 salía un anillo de
      manchas sueltas lejos de la roca que parecía suciedad en el mar.
  · **EN EL MAPA VA MUY APARTE**: sola, centrada y POR ENCIMA del lienzo
    (`MAP_POS` con y **negativa**, −700), a 1.068 px del escenario 19 — casi
    siete veces el paso normal. La distancia no es estética: es la que hace
    que, con la cueva en pantalla, NO se vea ningún otro escenario. El tope de
    scroll (`level_select3d.SCROLL_MIN`) ya no es el borde del mapa sino la
    cueva menos un margen.
David presenta los tres tipos CON sus hándicaps en la intro del mapa
(`_guiar_primer_nivel`), y además la PRIMERA VEZ que se juega un puerto o un
abordaje lo repite en el nivel con el foco puesto en el contador o en el reloj
(`level_director._explicar_handicap`, banderas `puerto_handicap_done` /
`abordaje_handicap_done`; level3d monta el director aunque el escenario no
tenga guion, igual que con los contadores de maestría). La cueva no se
anuncia: es la sorpresa del jefe. La GUÍA lleva los cuatro tipos al día.

Campos nuevos de puerto que salieron de aquí: **`client_order`** (orden EXACTO
de llegada, porque con la baraja no había forma de garantizar que el pirata
fuera el tercero del 7 ni que cada tanda del 9 llevara dos), **`first_arrival`**
(el 1 lo pone a 0), **`bite_speed`** (el 11 mastica al doble),
**`collectible_client`** ({who, type, item, reto?, recipe?, n?/plates?}: paga con una pieza de
vitrina en vez de con oro) y **`unlocks_perk`** (compuerta: un bonificador no
se puede ganar antes del puerto que lo presenta).

**EL CLIENTE DEL TESORO TRAE UN ENCARGO, NO UN PEAJE** (`collectible_client`
+ su campo **`reto`**): la pieza salía sola al cumplir "N platos", una
condición que nadie decía en voz alta, y eso no es un reto sino un premio por
casualidad. Ahora **el encargo lo canta EL PROPIO CLIENTE con foco** en cuanto
se sienta (`level_director._vigilar_tesoro`, un vigía que no bloquea, como el
de la basura) — David NO anuncia su presencia (decidido por el usuario): solo
interviene si el reto es `receta` y ese plato NO va en la carta de hoy, para
explicar que se puede **volver otro día con él** (sin esa frase, el tesoro
parecería perdido para siempre). La frase del encargo sale de
`CampaignData.reto_texto` — la MISMA que se lee luego en la vitrina, para que
no puedan contradecirse. La LECCIÓN de "clientes que pagan con tesoro" es del
escenario 10 (el pirata de la bandera); el 16 ya no lleva guion propio (el
director se monta solo por el vigía) y su capitán pide el **sashimi de atún
rojo** — el premio de 3★ del escenario anterior, a propósito: quien no lo
tenga vuelve a por él. Nueve tipos en `RETO_TEXTOS`:
`platos` (el de siempre, y el que sale si no se declara `reto`), `distintos`,
`mismo`, `receta` (con `recipe`), `postre_solo`, `platos_y_postre`,
`picoteos`, `picoteos_sin_plato` y `hasta_el_final`. Los ocho primeros se
resuelven en `level3d._reto_cumplido` leyendo `eaten_ids` (los PICOTEOS también
se apuntan ahí, comprobado); **`hasta_el_final` no puede mirarse ahí** y se
resuelve en `_end_level`, antes de vaciar la barra, que es el único momento en
que se sabe.
· **Un puerto con cliente del tesoro monta director SIEMPRE**, narrado o no:
  su vigía es quien hace hablar al cliente, y sin esa escena volvemos al
  premio por casualidad.
· **Y UNA PIEZA QUE SE ESCAPÓ NO SE QUEDA EN MISTERIO**
  (`inventory_screen._pista_coleccionable`): con su escenario ya superado, la
  ficha de la vitrina se abre y dice DÓNDE sale y QUÉ pide, con el dibujo
  todavía en silueta. El jugador vio al tipo y oyó el encargo; escondérselo
  después sería castigarle dos veces. El escenario lo deduce
  `CampaignData.port_for_collectible`, no una tabla escrita a mano.

**EL CONTADOR DE VACÍOS DEL PUERTO SON TRES CALAVERAS**, no un "Vacíos N/3"
(`level3d._setup_vacios_puerto`): son la calavera de la BANDERA PIRATA
(`calavera_vacio.png`, cráneo con los dos huesos cruzados por detrás), no la
`col_calavera` de la vitrina, que es un cráneo pelado y no se leía como el
aviso que es. Nacen apagadas —la misma calavera en sombra—
y cada cliente que se larga sin probar bocado enciende la suya con un SPLASH
(entra al 260%, se aplasta y rebota). A la tercera se pierde la jornada, y eso
se lee de un vistazo mucho mejor que una cifra.

**LOS CONTADORES DE MAESTRÍA VIVEN ABAJO A LA DERECHA, PEGADOS A LA CINTA**
de la tabla de elaboración (`level3d._place_skill_counters`; el usuario los
bajó dos veces — del HUD de arriba a la banda del cartel de fase, y de ahí un
renglón más). Van a la MISMA altura que la fila de cabezas — la banda
inmediatamente encima de la cinta — y por la derecha, donde las cabezas
(centradas) no llegan; su ancho se calcula del número de chips. El cartel de
fase recuperó su altura fija (`_phase_sign_y`).: las tres habilidades deterministas del
cocinero —golpe de vista, cocina abundante y golpe de suerte— son CONTADOR y no
dado justamente para poder planearlas, y planear con un número escondido no se
puede. Un chip por habilidad: una CHAPA con el pergamino del juego de fondo y su
marco (`PrepBoard.CARD_TEX`), el icono dentro y los platos que faltan
SUPERPUESTOS abajo a la derecha; a cero se enciende y late. Suelto sobre el 3D,
el icono se perdía y el número parecía de otra cosa. Solo salen las que el jugador LLEVA. El del golpe de vista
vivía clavado en una esquina de la tabla (`vista_label`) y se retiró: dos
contadores diciendo lo mismo en dos sitios es peor que uno.
**Y David los explica con FOCO la primera vez** que se juega con una puesta
(`level_director._explicar_contadores`, bandera `skill_counters_intro_done`).
Va al principio de TODO guion y **level3d monta el director aunque el escenario
no tenga guion propio**: estas habilidades se compran cuando al jugador le da
la gana, así que su explicación no se puede colgar de ningún puerto.

**EL BARCO COMBINADO SE APRENDE EN EL MAR 2** (decidido por el usuario, no
re-litigar): su bonificador ya no lo ata ningún escenario del mar 1. El puerto
18 sigue PERMITIÉNDOLO (`boat`) para cuando llegue, pero su lección la ocupa
ahora ALICE explicando que hay MÁS bonificadores y cómo se ganan
(`level_director._nivel_14`) — la da ella y no David a propósito: acaba de
enrolarse de ayudante, o sea que ella misma ES un bonificador. Y quitarle el
`unlocks_perk` a un bonificador NO basta para aparcarlo: `perk_gate_open` da
por abierta la compuerta de cualquiera que no ate puerto, así que el barco
lleva **`needs_port: true`** en `PerkData` — "pide escenario y no lo tiene,
luego sigue cerrado".

**LOS BONIFICADORES LLEGAN CON ALICE, TODOS DE GOLPE** (decidido por el
usuario, no re-litigar): el sistema no existe hasta superar SU escenario, el
**17** (`unlocks_perks: true` en `nivel_13`), que es donde ella se enrola de
ayudante de cocina. `GameState.perks_unlocked()` lo resuelve y
`perk_gate_open()` lo exige ANTES de mirar la compuerta propia de cada uno.
**Y LOS COMBOS SE MIRAN ANTES DE `complete_port`** (`level3d._finalize_results`):
`complete_port` apunta las estrellas de ESTE escenario y las compuertas se leen
justo de ahí, así que calculándolos después, superar el 17 abría el sistema y
en el mismo fotograma cobraba los combos hechos DENTRO del 17 — el jugador
llegaba al 18 con "Cocina veloz" puesta sin haberla ganado nunca con el sistema
abierto. Se gana A PARTIR del escenario que lo presenta, no en él.
Estuvo repartido y mal: Puerto Tormenta (escenario 13) regalaba el paladar con
una parrafada de David en el selector, y **`cocina_veloz` no tenía compuerta
ninguna**, así que se ganaba desde el escenario 1 — un bonificador apareciendo
en el cartel de resultados antes de que nadie hubiera dicho qué era eso. Hoy
solo `ayudante` (el 17) y `barco` (el 18) atan puerto propio; los otros dos
abren con el sistema.

**LOS BONIFICADORES SE MEJORAN, NO SE COMPRAN POR USOS** (`PerkData`): cinco
niveles por bonificador (500 / 2.000 / 5.000 / 10.000 doblones) y la pantalla
de Bonificadores vende NIVELES. Los USOS se ganan repitiendo su hazaña —
`unlock_perk` regala uno CADA VEZ que se cumple, no solo la primera. Efectos:
ayudante 60→30 s de descanso, paladar x6→x10, cocina veloz 60→40 % de
enfriamiento (en PORCENTAJE, no en fracción: "%d%%" de 0.6 imprimía "0%") y
barco +0→+75 % de prima por variedad. El barco lleva además `level_text_1`
propio ("habilita el barco combinado"), porque en su nivel de salida su efecto
no suma nada y la plantilla general decía "paga un **0%** más de prima", que se
lee como un bonificador roto; `PerkData.level_text` mira `level_text_<n>` antes
que la plantilla, así que cualquier otro puede hacer lo mismo.

**LA TARJETA DE UN BONIFICADOR CRECE CON SU CONTENIDO** (`perks_screen`): iba
como una FILA de alto fijo (168 px) con el botón a la derecha, y entre el
icono, los márgenes y un botón de 180 px a los textos les quedaban ~260 px de
ancho, así que el nombre, el efecto y la condición se partían en cinco o seis
renglones y se salían de la tarjeta. Ahora va en dos plantas —cabecera con
icono y nombre, y el botón abajo a la derecha— y sin alto fijo. El botón de
**Mejorar** lleva su precio DIBUJADO dentro, con la moneda del juego
(`_make_upgrade_button`), en vez de tres renglones de texto pelado
("Mejorar\na nivel 3\n$2000") que no cabían; y **PREGUNTA ANTES**
(`_confirmar_mejora`), con lo que hace HOY el bonificador y lo que hará con la
mejora, uno debajo del otro: son de 500 a 10.000 doblones y estaba cobrando al
primer toque sin decir qué se llevaba a cambio.

**CAI** (`assets/characters/cai`, hablante `cai`): el pescador de la Isla de
Gades. Habla poco y mal —solo sabe japonés— así que sus frases son cortas, sin
artículos y a veces son un "..." (para eso está su expresión `callado`). Es la
voz de la pantalla de PESCA, y saluda y se despide en cada visita (10 frases de
cada). También explica los COLECCIONABLES la primera vez que sale uno del cofre.
**SU CLASE ES DE PRÁCTICA, NO DE TEORÍA** (`_clase_de_pesca`): dice UNA cosa,
se quita de en medio y el jugador la HACE; solo entonces viene la siguiente, y
cada lección se cierra sola al cumplirla, así que no se puede escuchar sin
tocar. Era una parrafada seguida con dos focos y luego "ahora tú".
· **El intento va AMAÑADO** (`clase`): pez de tier 0 y pequeño, sin cobrar
  (paga Cai), el sedal perdona (`CLASE_TENSION`), la presa tira flojo
  (`CLASE_TIRON`) y **ni el sedal se rompe ni el pez se suelta** — se quedan
  clavados a 0,93. La primera pelea de la vida del jugador no se puede perder,
  solo entender.
· **UNA fase de velocidad GARANTIZADA**, y la provoca el guion
  (`speed_next = 0`) cuando le toca, no antes: el tirón es lo único que no se
  puede explicar sin verlo y en un intento normal de tier 0 puede no salir
  ninguno. Cai avisa ANTES de que empiece.
· **MIENTRAS CAI HABLA NO CORRE NADA** (`leccion_en_curso` corta el `_process`
  entero, no solo la pelea). La caja de diálogo se traga todos los toques, así
  que cualquier cosa que avance por debajo es tiempo que el jugador no puede
  jugar: explicando la FINTA, el pez se llevaba el cebo en mitad de la frase
  que decía cómo evitarlo, y con el pez enganchado la presa se soltaba durante
  la frase que explicaba cómo aguantarla (las dos, medidas con un jugador
  simulado). Congelar solo la pelea no bastaba: hay que congelar también la
  sombra, las fintas y la ventana de la picada.
· **SI AUN ASÍ SE ESCAPA, LA CLASE NO SE CORTA**: se repite el intento hasta
  `CLASE_INTENTOS` (3) veces, con Cai encogiéndose de hombros ("Se fue. Pasa.
  Otra vez."). Antes se quedaba a medias y el jugador no llegaba a aprender la
  pelea.
· **El botón dice "Lanzar caña" y ESCONDE LA MONEDA** mientras dura la clase
  (`_refresh_cast_label` mira `clase`): paga Cai, y enseñar "100" al lado hacía
  creer que se estaba cobrando la tirada.
· Al acabar, `CAI_TIRADAS_GRATIS` (3) lanzamientos de regalo.
**Y SE SIENTA A COMER**: en la Isla de Gades no mira desde la orilla, es un
CLIENTE con su propio modelo (`cai_rig.glb`, `special_client` del puerto) que
come como un **pirata** (2 estrellas, el tipo lo pone el puerto y no el
modelo). Lo primero que dice al sentarse es su "...", y por eso David tiene que
romper el hielo por él. El trato son `level_director.PLATOS_CAI` (3) platos, y
al cumplirlos se apunta `GameState.cai_saciado`.
**LA PESCA SE ABRE POR SUPERAR EL NIVEL, NO POR LOS 3 PLATOS** (decidido, no
re-litigar): atarla a los platos dejaría sin pesca —para siempre y sin vuelta
atrás— a quien cerrara el turno por objetivo antes de alimentarlo, y eso es una
trampa. Lo que cambian los 3 platos es la ESCENA: con la barriga llena Cai se
enrola pagando su trato, y sin ella se enrola igual pero con otra frase, sin
fingir una comida que no hubo. Por eso `cai_saciado` es PERSISTENTE: la escena
del trato no ocurre en el nivel sino después, ya en el mapa
(`main_menu._presentar_cai`), y sin ese apunte quien cerrara el turno por
objetivo llegaría al mapa y Cai le hablaría de una barriga que nadie le llenó.
**El mapa YA NO ARRASTRA A LA PANTALLA DE PESCA** al cerrar esa escena: la
clase de Cai se da cuando el jugador entra en Pesca por su cuenta
(`fishing_intro_done`), así que no se pierde nada y no se le cambia de sitio
justo al volver de un nivel.

**Explicaciones de PANTALLA**: los LOGROS y el INVENTARIO se explican la
primera vez que se entra en ellos (`logros_intro_done` /
`inventario_intro_done`), no desde un nivel.

## Guiones narrados (la campaña ES el tutorial)

- **LA ENSEÑANZA VA INTEGRADA EN LOS NIVELES 1-10** (rediseño del 14-8-2026):
  el "tutorial" clásico se redujo a una escena de rescate y cada nivel presenta
  UNA mecánica jugando. El flujo de una partida nueva:
  1. **INTRO DEL CAOS** (`tutorial_director.gd`, sobre level3d en modo
     tutorial): una partida IMPOSIBLE a propósito — solo el maki, cero
     indicaciones y la barra llena de clientes de todo tipo que aparecen **YA
     SENTADOS** (`client3d.sit_now()`: verlos entrar de uno en uno quitaba la
     sensación de llegar tarde a un desastre ya montado). Cuando se han
     levantado LOS OCHO entran David y Gigi con la oferta de tripulación, y
     hablan con `congelar = false` — el árbol sigue corriendo y la clientela
     termina de cruzar la cubierta mientras habla (en pausa se quedaban
     clavados a medio paso). Botón **"Saltar tutorial"** arriba a la IZQUIERDA,
     bajo la fila del HUD, y PREGUNTA antes (`_confirmar_saltar`): saltarse el
     tutorial es una decisión, no un resbalón.
     **Las salidas van CRONOMETRADAS** (`CHAOS_EXITS` = 3 · 5 · 8 · 10 · 12 ·
     12 · 14 · 14 s) y NO con un temporizador que los levante: a cada uno se le
     da el DRENAJE justo (`_drenaje_para`, con SU `patience_max` real contra
     `FIRST_PLATE_DRAIN`) para que su barra llegue a cero en su segundo, así
     que lo que se ve bajar en pantalla es la verdad. Medido: clavado al
     décimo. Llevan además `always_drain` (la paciencia NO se detiene al comer:
     servirles algo no los salva, solo hace que se vayan masticando) y
     `slow_eat` mínimo. El recién sentado se identifica comparando los asientos
     ANTES y DESPUÉS del spawn: el spawner elige silla al azar, así que "el
     último del array" era otro cliente y los ajustes caían todos en el mismo.
     **EL MARCADOR ES DE ESCAPARATE** (`_montar_marcador`, constantes
     `TEATRO_*`): 180 de oro sobre un objetivo de 3000, "120/120" clientes y 15
     s de reloj. Se rellenan los campos REALES del nivel (money_earned,
     star_money, clients_spawned, timed/time_limit) y no hay nada dibujado
     aparte; en modo tutorial el nivel no termina ni por reloj ni por clientes,
     así que ninguna de esas cifras dispara nada. **PERO EL ORO DE SALIDA ES LO
     ÚNICO PUESTO A MANO: a partir de ahí la cuenta es REAL** y los 180 se
     desmoronan solos — cada cliente que se larga sin comer cobra su
     `LEAVE_PENALTY` escalado y cada plato que da la vuelta entera se descuenta,
     que es exactamente lo que la escena tiene que hacerle sentir. (Estuvo
     CLAVADO por fotograma para que la cifra no se moviera; se quitó a
     propósito, no reintroducirlo.)
  2. **LA FICHA DE TRIPULACIÓN SE RELLENA EN EL PROPIO MENÚ**
     (`main_menu._show_ficha` / `_run_ficha` / `_ask_identity`, transición
     `"ficha"`). Hubo un `david_intro.tscn` aparte —primero con una cubierta
     construida a mano y luego ya con el fondo del menú—; **se BORRÓ**: si el
     telón tenía que ser exactamente este (el barco navegando), el fundido a
     negro y el cambio de escena por medio solo eran un corte de más. Ahora se
     llega aquí desde la intro del caos, se ve el mismo mar todo el rato, y el
     tablón, el submenú y los contadores NO existen hasta que el cartel está
     aplicado (`_ui_in` los baja entonces); David sigue hablando ya con el
     camarote puesto (`_menu_popups` → `_guiar_a_aventura`). Detalles pagados:
     · `main_menu._ready` tiene que EXCEPTUAR la transición "ficha" en su
       "sin tutorial → a la intro", o rebota al caos (el tutorial no se da por
       hecho hasta aplicar el cartel).
     · Las dos tandas de diálogo van SIN `keep_open`: la caja tiene que
       retirarse antes de que salga el cartel, o el retrato de David lo tapa
       media pantalla.
     · El botón "¡Ese soy yo!" **se arma a los 0,9 s** (`FICHA_ARMADO`): se
       llega aquí pasando diálogo a toques y el toque de inercia se saltaba la
       ficha entera.
     · **GIGI SE BURLA DEL NOMBRE ELEGIDO** (`_pulla_de_gigi`, constantes
       `GIGI_PULLAS_M/F/ANY`): 10 frases para el chef, 10 para la chef y 5
       comunes — 25 en total, sorteadas. El género sale de
       `GameState.player_gender`, que ya está aplicado cuando esto corre
       (`cartel.aplicar()` va antes de devolver el nombre). Las frases pueden
       llevar el `%s` una o dos veces: se rellenan por CONTEO, no a pelo.
  3. Menú: `main_menu._guiar_a_aventura()` — velo oscuro con el pergamino de
     **Aventura** iluminado (patrón de `_explicar_arroz`). OJO: el z_index no
     cambia quién recibe el toque (el picking va por orden de árbol), así que
     es el PROPIO VELO quien escucha el toque sobre el pergamino y dispara
     `_go_adventure`. Bandera `menu_intro_done` (los saves con tutorial hecho
     la dan por vista al cargar).
     **EL VELO VA LO PRIMERO, ANTES DE LA ESPERA.** Se dejaban 0,8 s para que
     la interfaz terminara de entrar y solo entonces se oscurecía: en ese hueco
     el menú estaba vivo y daba tiempo de sobra a abrir la Tienda o los Logros
     antes de que David llegara a decir nada. El velo traga los toques desde el
     primer fotograma, así que ahora la espera se hace con la puerta cerrada
     (y se ve entrar el tablón atenuado, que además queda bien).
  4. Mapa: `main_menu._presentar_mapa` encadena las dos explicaciones **EN LA
     MISMA CAJA** — `_explicar_arroz` (`rice_intro_done`) dice su tanda con
     `keep_open`, se quita el foco del saco y DEVUELVE la caja, que recoge
     `level_select3d._guiar_primer_nivel(caja)` (`map_intro_done`) para seguir
     hablando. Cerrar el pergamino y volver a entrar entre las dos era un corte
     a mitad de idea. La segunda tanda arranca señalando el primer puerto
     ("nuestra primera parada es esa de ahí, una **isla**") y explica SOLO LA
     ISLA: el puerto y el abordaje se cuentan cuando se pisan por primera vez
     (`level_director._explicar_handicap`, que además de su hándicap presenta
     ya el TIPO). Tres clases de parada de golpe, antes de haber jugado
     ninguna, es una lección que no se puede aplicar a nada. NO se menciona
     ninguna "carta de navegación". Va SIN
     velo ni foco —se ve el mapa entero— y ata al jugador al primer puerto: el
     botón "Atrás" sigue vivo, pero con `_atado_al_puerto` puesto lo que hace es
     sacar a **Gigi** amenazando con echarlo a los tiburones (un botón apagado
     no habría explicado nada). Se suelta al pulsar "¡Zarpar!".
- **La rama de tutorial de level3d no repasa la interfaz de la tabla sola**:
  en aventura lo dispara la lectura del puerto, pero sin puerto hay que llamar
  `prep_board.refresh_extra_ui()` A MANO tras poner `hide_storage` (las cajas
  se quedaban dibujadas en pleno caos).
- **UN DIRECTOR SIN GUION PROPIO TIENE QUE LLAMAR A `_play()` IGUAL.**
  `StoryDirector.narrating` nace en **true** y solo lo apaga `_play()`, y
  `level3d._ask_start` ESPERA a que se apague (con tope de 90 s) antes de sacar
  el "¿Comenzamos?". Un escenario que monta director SIN guion —el 16, por su
  vigía del tesoro— y cuyas explicaciones sueltas (contadores de maestría,
  hándicap del tipo) ya estaban dadas se quedaba con `narrating` en true para
  siempre: **el nivel no arrancaba**. Ni cartel, ni cuenta atrás, ni clientes,
  y sin un solo error en consola. Si se añade una rama nueva a `_run`, que
  termine en `_play()`.
- **UN GUION QUE SE QUEDA SIN NIVEL SE APARCA PARA SIEMPRE**
  (`StoryDirector._jamas`, una señal que no se emite nunca). Al pulsar **Salir**
  —o Repetir, o al cerrarse el turno— el director se va del árbol con su
  corrutina a medias, y GDScript no deja matarlas. `_esperar` salía del bucle
  con un `is_inside_tree()` y DEVOLVÍA el control, así que el guion daba por
  hecho que su condición se había cumplido y seguía con la línea siguiente
  sobre un nivel liberado: el `create_timer` de después reventaba con
  `get_tree()` a null y el guion moría a gritos en la consola (era el "se rompe
  al salir" del nivel 7). Ahora `_esperar`, `_say` y `_pausa` aparcan la
  corrutina en un `await` que jamás se resuelve; cuando el director se libera
  con su nivel, la corrutina se va con él. **TODA espera de un director va por
  `_pausa`, nunca por `get_tree().create_timer` a pelo.**
- `scripts/story_director.gd` (`StoryDirector`) es la BASE de todo guion sobre
  `level3d`: pausa el árbol entero al hablar (`get_tree().paused`, con la caja
  y el director en `PROCESS_MODE_ALWAYS`), retiene el reloj (`lv.clock_hold`),
  pinta el FOCO circular y vigila la inactividad. Las hijas solo escriben
  `_run()`. De ella cuelgan `tutorial_director.gd` (la intro del caos) y
  `level_director.gd` (los niveles).
- **FOCO**: es una **ELIPSE** ajustada al rectángulo (`radius` es un `vec2`),
  no un círculo: la fila entera de recetas mide 700×150 y el círculo que la
  cubriera se comía la tabla y media pantalla. Cada semieje se multiplica por
  `HOLGURA` (1.25) porque la elipse INSCRITA deja fuera las cuatro esquinas y
  los pergaminos de los extremos salían medio apagados. `_focus_node()`
  **espera DOS fotogramas antes de medir**: los contenedores de Godot recolocan
  a sus hijos de forma diferida, así que justo después de tocar
  `allowed_recipes` el botón sigue en su sitio VIEJO. `_focus_nodes()` enfoca
  la envolvente de varios (David hablando de las recetas EN GENERAL: ahí se
  encienden todas con `allowed_recipes = []` y se vuelven a apagar después).
- **EL SHADER DEL FOCO NECESITA EL TAMAÑO DEL LIENZO** (`screen`): tenía
  `UV * vec2(720, 1280)` clavado y en el móvil el lienzo mide ~720×1560, así
  que el foco caía muy por encima de lo que señalaba.
- **`_say` NO puede deducir si hay foco leyendo el uniforme `dim`.** Era lo que
  hacía, y `_fade_dim` llega al valor con un TWEEN: en el fotograma siguiente a
  poner el foco `dim` valía aún 0, así que `_say` creía que no había foco, lo
  borraba y lo cambiaba por el velo suave. Solo sobrevivían los focos puestos
  después de un `_play` (ahí `_say` espera `PAUSA_ANTES` y al tween le da
  tiempo). Por eso en el tutorial no se veían ni el reloj, ni el oro, ni los
  clientes, y sí los de más adelante. Ahora manda la bandera `_focus_on`.
- **Y el foco va SIEMPRE DESPUÉS de `_play`**, que llama a `_clear_focus`.
- **Vigía de inactividad**: 10 s sin tocar nada en una fase interactiva y Gigi
  grita "¡ESPABILA!" + el recordatorio que dejó puesto `_play(aviso)`. No salta
  con alguien hablando ni con un gesto sostenido en curso
  (`prep_board.is_gesture_locked()`), que se arruinaría.
- **EL CARTEL DE "¿COMENZAMOS?" ESPERA A QUE EL GUION TERMINE SU PRESENTACIÓN**
  (`level3d._ask_start` mira `StoryDirector.narrating`, que se apaga en el
  primer `_play`): ese cartel trae un paño negro al 50% a pantalla completa y,
  sumado al foco del guion, dejaba lo enfocado tan oscuro como el resto — eran
  las "dos sombras" del nigiri del nivel 1 y de la barra de propinas del 5.
  **NO vale preguntar `dialog.is_talking()`**, que es lo que hacía: los dos
  arrancan en diferido y el guion todavía está esperando fotogramas para medir
  su foco cuando el cartel se monta, así que lo encuentra callado. Los quince
  directores llaman a `_play` antes de esperar al fin de la preparación, que es
  lo que hace segura la espera (con tope de 90 s por si acaso).
- **`slow_eat` solo se aplica al EMPEZAR un plato; para acortar el bocado YA EN
  MARCHA está `client3d.bite_speed`** (se reinicia con cada plato).
- `scripts/level_director.gd` narra los puertos que llevan `director` en
  `CampaignData`. **REDISEÑO DEL 15-8-2026 (niveles 1-6)**: los seis primeros
  niveles son TODOS de grumetes y cada uno enseña UNA cosa —jornada normal,
  cajas, picoteo, multiplicador, postres, extras—; piratas y capitanes no
  aparecen hasta el 7, que es también el primer abordaje. El reparto de
  lecciones (el detalle en la cabecera de `campaign_data.gd`):
  **EL GUION SE QUEMA AL SUPERAR EL NIVEL, NO AL JUGARLO**
  (`level3d._finalize_results` llama a `mark_port_narrated` solo con
  `stars >= goal_stars`): quien se queda corto y repite vuelve a tener a David
  explicándoselo todo, y en cuanto aprueba, las repeticiones son partidas
  limpias. Estuvo marcándose al acabar la fase de preparación, y así un intento
  fallido dejaba al jugador sin la clase que aún necesitaba.
  **N1 — JORNADA CORRIENTE**: cuatro grumetes a ritmo normal, y el **nigiri de
  salmón** YA EN LA CARTA desde el primer fotograma (`fixed_recipes`, también
  al repetir desde el mapa o desde "Repetir"); David solo lo presenta. El
  cliente se sienta y a los **0,5 s** se explica la barra de PACIENCIA, empieza
  a comer y a los 0,5 s la de BOCADO ("mientras mastica no coge nada más");
  cuando paga → el ORO. En paralelo, `_vigilar_basura` explica el CUBO la
  primera vez que un plato da la vuelta entera. **La lección de la papelera es
  DE TODA LA PARTIDA, no de este nivel**: la bandera `trash_intro_done` es
  persistente, porque atada al nivel David y Gigi soltaban la misma parrafada
  en el 1, en el 2, en el 3... cada vez que se colaba un plato.
  **El botón de Salir NO sale en el ESTRENO** y sí a partir del segundo intento
  (`no_exit` del puerto Y `level_stars` sin entrada: level3d mira las dos);
  va sin el aparato de la variedad (`no_variety_ui` →
  `client3d.variety_ui`: ni bocadillos ni chapas "x2", aunque el multiplicador
  se siga calculando por dentro), sin propinas y sin BONIFICADORES.
  Umbrales 10/25/40, con el **gunkan de wakame** a las 3 estrellas.
  **NINGÚN PASO SE ATA A UN CLIENTE CONCRETO** más allá del primero: el del
  bocado espera a que coma CUALQUIERA (`_comiendo()`) y el del oro a que suba
  el marcador. Atado al primero, bastaba con que ese se fuera sin probar bocado
  para que el guion se quedara esperando un `is_eating()` que ya no iba a
  llegar y el nivel se jugara entero sin una explicación más.
  **Y OJO CON LAS LAMBDAS DE `_esperar`**: capturan POR VALOR, así que asignar
  dentro una variable de FUERA (`alumno = _cliente_tipo()`) no sale del
  closure. Costó que no saltara NI UNO de los eventos del nivel: la de fuera
  seguía en null y el guion se daba por fallido en la línea siguiente. La
  condición MIRA; el dato se pide fuera.
  **AL SUPERARLO, en el mapa** (`main_menu._felicitar_nivel_1`): David felicita
  e invita al 2 — **ni las estrellas ni sus recompensas se explican ahí**
  (pedido por el usuario): el cartel de resultados las acaba de enseñar una a
  una y la ficha del puerto las lleva escritas; y justo después, la primera vez, `_explicar_bonus_diario` antes
  del cartel del bonus. **La recompensa de las 3 estrellas ya NO se explica**
  —el cartel de resultados y la ficha del puerto la enseñan solas, y gastaba
  dos líneas en lo evidente—; en su hueco entró lo que no se ve por ningún
  lado, que es la experiencia.
  **Y LAS MAESTRÍAS SE PRESENTAN AL LLEGAR AL NIVEL 5 DE COCINERO**
  (`main_menu._presentar_maestrias`, bandera `skills_intro_done`, constante
  `SKILLS_INTRO_LEVEL`): antes no, porque con un punto suelto la pantalla no
  tiene nada que enseñar. Al cerrar el diálogo lleva DIRECTO al árbol, el
  mismo patrón que Saverio con su puesto.
  **N2 — LAS CAJAS, y nada más**: el primer grumete entra SOLO; cuando se ha
  comido su SEGUNDO plato (o su paciencia baja a 2/3) entran los otros TRES DE
  GOLPE y arranca la lección: aparecen las cajas (`hide_storage` lo pone y lo
  quita EL GUION, no el puerto, para que al repetir el nivel salgan de
  entrada), las paciencias se retienen (`client3d.patience_hold`) y la CINTA SE
  CIERRA (`prep_board.block_serve`), así que hay que guardar 3 platos y
  soltarlos de golpe; si intenta servir, la señal `serve_blocked` hace saltar a
  Gigi (una sola vez) en vez de dejar un plato que no reacciona. Aquí David
  avisa además de que **desde hoy la despensa se gasta**. 3★: maki de pepino.
  **N3 — EL PICOTEO**: regalo del **edamame** al empezar, con la explicación de
  que se coge SIN soltar el plato en curso; cuando alguien lo pica de verdad,
  la coletilla. Al primer grumete se le pone `client3d.snack_sure`: **no falla
  el dado del picoteo**, porque con el 0.9 de la receta había un 10% de que el
  jugador lo hiciera todo bien y viera su edamame pasar de largo justo en la
  clase de para qué sirve. 3★: sunomono.
  **N4 — MULTIPLICADOR, HASTÍO Y PALADAR**: primer puerto (carta libre, TRES
  huecos) con ocho grumetes de dos en dos.
  **LA LECCIÓN DE LA CHAPA ES UN EJERCICIO OBLIGADO, no una espera**: David
  señala al primer cliente y pide **dos platos DISTINTOS** para él, y el guion
  espera a que se haga. Estuvo colgado de `_mejor_variedad() >= 2` a secas, y
  un jugador que sirva siempre la misma receta NO LLEGA NUNCA: se jugaba
  entero el nivel que ESTRENA el multiplicador sin oír una palabra de él. Al
  alumno se le **retiene la paciencia** mientras dura el ejercicio (no puede
  irse a mitad de clase y dejar al guion esperando a un cliente que ya no
  está), y vale cualquier cliente que llegue a x2, no solo el señalado.
  Al primer repetido, el hastío, y con él el regalo del **té verde**. AL CERRAR,
  Saverio abre la tienda (`shop_intro_done = true` lo pone este guion) y deja
  `pending_shop_visit`, que hace que "Continuar" lleve DIRECTO al puesto.
  3★: onigiri.
  **N5 — POSTRES Y PROPINAS**: el bote (foco en `tip_bar`), regalo del
  **mochi** con la lección de que el postre cobra el multiplicador y libera la
  silla, y la coletilla del primer potenciador. 3★: caldo dashi.
  **N6 — LOS EXTRAS**: Saverio los saca al empezar el turno; el guion pone
  `GameState.extras_done = true` (que es lo que abre los extras en la tabla Y
  en la tienda) y regala 10 usos de cada uno. 3★: sopa de miso.
  **N7 — PRIMER ABORDAJE Y EL PIRATA DE LA BANDERA**: reloj, clientela sin fin
  y prima por tiempo; y el primer PIRATA del juego (los capitanes no llegan
  hasta el 10, con Pablo), con el regalo del **nigiri de atún** para estrenarlo
  con él. **SUBE UN SOLO PIRATA EN TODO EL NIVEL** —`client_weights` del puerto
  es `{E: 1}`, porque en un abordaje, agotada la primera tanda, las llegadas se
  siguen sorteando con las proporciones de la mezcla— y es a propósito: es EL
  pirata de la **BANDERA PIRATA**, y con dos no habría forma de saber a cuál se
  le está sirviendo. Habla POR SÍ MISMO (retrato propio) y pone precio a su
  bandera: `PLATOS_BANDERA` (3) platos y es tuya, porque su capitán lo manda a
  comer y no quiere volver con el buche vacío. Al cumplirlo se entrega el
  coleccionable y David explica QUÉ SON los coleccionables — **este es el único
  sitio del juego donde se consigue la bandera**. Estuvo colgada de "un
  abordaje superado con 3 estrellas" (`complete_port`) y así aparecía sola en
  el cartel de resultados, sin ninguna escena detrás.
  **LA CUENTA Y LA ENTREGA SON DOS COSAS DISTINTAS**, y hay una razón para cada
  una. La CUENTA la apunta una señal (`_on_pirata_come`, colgada del
  `plate_served` del pirata) porque estuvo dentro de un `_esperar` que miraba
  también `lv.ended`, y eso perdía el premio en el caso más normal: `eaten_ids`
  cuenta platos TERMINADOS, no servidos, así que el último se estaba masticando
  cuando se acababa el reloj del abordaje —o cuando al pirata se le agotaba la
  paciencia— y el guion salía con la cuenta en N-1 y sin decir nada, después de
  que el jugador le hubiera servido los platos. La ENTREGA
  (`_entregar_bandera`) la hace el GUION y **después de que el pirata hable**:
  la ventana del coleccionable la saca `GameState` en su capa global de avisos,
  así que entregándola desde la señal se colaba encima de él y salía el cartel
  del premio antes que el "lo prometido". Si el turno se cierra con la cuenta
  hecha, se entrega igual y lo único que se pierde es la escena.
  Y **son TRES platos, no cinco**: en un abordaje de 2:30, con el pirata
  entrando el tercero y comiendo de dos estrellas, cinco eran casi todo el
  turno dedicado a un solo cliente.
  **N8**: la flota de **Pablo el Rubio**: broma del puñal, Pablo tardío que se
  adelanta al 80%, regalo del **salmón tsuke don** y con él la lección del
  CORTE LENTO (`free_mistakes` hasta servir el primero, y Gigi regaña vía
  `slice_failed`).
  **N9**: SIN guion a propósito — el examen antes del jefe.
  **N10**: el JEFE (ver el bloque del Kappa).
  **El `match` de `_run()` hay que ampliarlo con cada guion nuevo**: pasó de
  verdad (un guion escrito sin su rama = David no aparece).
- **Cliente ESPECIAL de un puerto** (`special_client` en `CampaignData`):
  `{who, type}` hace que UNO de los clientes de ese tipo salga con un modelo
  propio (`client3d.who_override` → `CharacterData.MODELS`), sin tocar el
  equilibrio: come, paga y aguanta como los de su tipo. Con `late_type` del
  mismo tipo, entra el último. Lo usan Pablo el Rubio (nivel 10), Cai (nivel 8)
  y el guion del jefe (que rellena `special_who` a mano para traer al Kappa).
  **CADA ESPECIAL LLEVA SU PROPIA CHAPA EN LA FILA DE CABEZAS**, aparte del
  recuento de su tipo (`_update_heads_row`). Antes su cara se colaba en la
  insignia del TIPO —era la del primero que llegó—, así que en la Isla de Gades
  TODOS los piratas de la fila salían con la cara de Cai y parecía un error del
  juego; ahora Cai (y Pablo, y el Kappa) tienen su icono al lado del de los
  suyos, y `head_who` solo guarda ya el personaje genérico. Sus iconos los
  genera `tools/head_icons.gd` con encuadre propio en `FRAME_OVERRIDE` (el
  sombrero de Pablo es muy alto, y el Kappa es un cabezón: media altura es
  cabeza). **OJO: `head_icons` solo trae en `OUT` al personaje NUEVO de cada
  pasada** — regenerar los demás es jugar a la lotería de render; la lista
  completa queda comentada. Y si un especial se queda sin icono,
  `CharacterData._pick` cae al del grumete en vez de dejar el hueco vacío.
- **EL JEFE: EL KAPPA, EN TRES FASES** (rediseño del 20-8-2026, pedido por el
  usuario — no re-litigar; `boss: "kappa"` en el puerto, coreografía en
  `level_director._nivel_15`, comportamiento en `client3d.make_boss`):
  · **SALE AL GANARSE LA 2ª ESTRELLA** (`lv._score_money() >= star_money[1]`),
    no por barrigas llenas ni por reloj: la señal está en la propia barra del
    oro. Al salir, el reloj se para, la barra se vacía sin castigos y no llega
    nadie más.
  · **ENTRA SIEMPRE POR LA BOCA DE LA CUEVA** (la borda de arriba): el guion
    fuerza las sillas cuya entrada es `ENTRY` vía `lv.first_seats` antes del
    sorteo. Y mide **2.5 u** (`KAPPA_ALTO` → `client3d.height_override`, que
    level3d aplica al especial con `special_height`): más que un capitán.
  · **LA 3ª ESTRELLA ES EL JEFE** (`lv.boss_hud_on`): su cara (`head_K.png`)
    sustituye a la estrella de la meta en la barra del oro —se gana rindiéndolo,
    no con oro— y `_place_star_marks` no la repinta (`boss_star_face`). Las dos
    primeras siguen siendo de dinero. En `_finalize_results`: derrota del duelo
    → 0 estrellas; rendido → mini(estrellas_oro, 2) + 1; cerrado sin verlo
    (el reloj antes de la 2ª estrella) → tope 1.
  · **SU CHAPA** (cara + platos que FALTAN en la fase, `boss_chip_set`) vive
    centrada bajo la fila de arriba; el cartel "Kappa: N/10" de la tablilla de
    fase se retiró (tapaba media pantalla).
  · **CINCO CALAVERAS** (`BOSS_SKULLS`, mismas que el contador de vacíos del
    puerto — el constructor es compartido, `_build_calaveras`/`_splash_calavera`).
    Cada fallo enciende una (`boss_lose_skull`); a la quinta, `boss_lost` y
    jornada perdida.
  · **CADA FALLO DECOMISA LA FASE** (`boss_forfeit`): el oro y las propinas de
    los platos que el Kappa comió en la fase en curso se restan (suelo 0). El
    guion lleva la cuenta en `_oro_fase`/`_prop_fase` vía su `plate_served`.
  · **FASE 1 — los platos**: `BOSS_PLATES` (10) antes de que su paciencia
    toque fondo. **El jefe ya NO se marcha al agotarse**: se queda a cero y
    emite `boss_starved` una vez (client3d); el guion cobra la calavera y le
    devuelve el **75% → 50% → 30%** de barra (`KAPPA_RECUPERA`, cada hambruna
    perdona menos, vía `boss_patience_set`).
  · **FASE 2 — la variedad** (+75% de barra al entrar): `KAPPA_DISTINTOS` (3)
    platos SIN repetir. Un repetido = calavera + decomiso + su paladar se
    resetea (`_limpiar_paladar`, o la escalera del hastío del intento fallido
    seguiría cargada) y se empieza de nuevo. Los picoteos que come también
    cuentan (van a `eaten_ids`).
  · **FASE 3 — el antojo** (+50%): `KAPPA_MISMO` (5) veces el plato MÁS CARO
    de la carta de hoy (`_plato_mas_caro`: ni postres —los descarta antes del
    dado— ni picoteos). Cualquier otro plato = calavera + decomiso + cuenta a
    cero. Ojo: repetirle 5 veces el mismo plato carga su hastío — los EXTRAS
    (que hacen "nuevo" a un repetido) son la herramienta pensada para esta fase.
  · **Y LA VICTORIA TAMBIÉN CIERRA**: la última frase de Gigi se quedaba
    encima del cartel de resultados y el jugador no podía pulsar "Continuar"
    ni cerrar las ventanas de subida de nivel o de receta nueva. Como red de
    seguridad, `level3d._show_results` cierra ahora las cajas de cualquier
    guion (`_cerrar_cajas_de_guion`): a esas alturas del turno no queda nada
    que decir, y así ningún guion futuro puede volver a tapar el cartel.
  · **TODO DIÁLOGO DE FALLO TERMINA EN `_play(aviso)`**: la caja del director
    solo la cierra `_play`, así que un `_decir` suelto dejaba el "¡KAPPA TIENE
    HAMBRE!" clavado en pantalla con el input tragado — y en la derrota, la
    caja encima del cartel de resultados: no se podía salir NI se cobraba el
    oro de la jornada (que se paga en `_finalize_results`). Cada fase pasa su
    recordatorio a `_fase_kappa` para que el aviso de Gigi siga siendo el
    encargo vigente. Perder el duelo da 0 estrellas pero el oro generado
    (menos los decomisos) SÍ se cobra: verificado 2471 → 2529.
  · **SUS PROPINAS VAN RECORTADAS** (`client3d.BOSS_TIP_MULT`, ×0.25 sobre la
    probabilidad): come 18+ platos con las reglas de capitán (25%→50%) y a
    tarifa normal regaba el bote — pagaba como cuatro capitanes.
  · **EL GUION VA POR SONDEO de `eaten_ids`, no por señales** (`_fase_kappa`):
    el id del plato solo está ahí, y resolver los fallos en el mismo bucle los
    SERIALIZA con las frases (un handler async hablaba encima de la charla de
    cambio de fase). Las señales solo levantan banderas (`_on_kappa_hambre`) o
    suman el decomiso (`_on_kappa_plato`).
  · **LA IRA ESCALA CON LA FASE**: los fallos hablan con `enfadado` (F1),
    `furioso` (F2) y `colerico` (F3) — ver los retratos abajo.
  · **VICTORIA**: `_kappa_duerme` — se le saca de `seat_clients` (nadie lo
    cobra ni lo echa al cerrar), se cae del taburete (tween de la raíz, pivote
    en los pies), barras y bocadillo fuera (`hide_bars`) y un "Zzz" flotante
    encima. David felicita y el turno se cierra con las 3 estrellas.
  · **Y PAGA EN EL MAPA** (`GameState.pending_kappa`, persistente; escena
    `main_menu._presentar_kappa`): medio dormido, entrega **2 lingotes**
    (`KAPPA_LINGOTES`) y su **diente**. El trofeo ya NO cae por la vía de las
    stats — tanto la vieja (`bosses_beaten`) como la general de `BOSS_ITEMS`
    esperan a `kappa_outro_done`; un guardado viejo que ya tuviera el diente
    da la escena por hecha al cargar.
  · **El nivel del jefe monta su director SIEMPRE** (level3d: `boss_id != ""`
    salta el filtro de `narrated_ports`); en las repeticiones corre EN MUDO
    (`_mudo`) y el duelo se comunica solo con la chapa, las calaveras y los
    avisos de `_play`.
  · **SU PELO LLEVA LAS PUNTAS RECORTADAS** (`tools/kappa_pelo_fix.py`): el
    modelo viene de imagen→3D y el pelo son plaquitas finas disparadas desde
    el cráneo, que a tamaño de juego se leían como LÍNEAS sueltas fuera de la
    silueta. No se borran triángulos (eso deja agujeros): se ACOTA el radio de
    la banda del pelo (y 0.355..0.468) al percentil 93 de cada franja,
    empujando hacia el eje solo lo que sobresale — 581 vértices, la peor punta
    sobresalía 0.020. Los límites NO son libres: por debajo está el PICO (que
    llega a un radio de 0.168 y se limaría) y por encima el PLATO, que es
    ancho por definición. Al reescribir el `.glb` hay que copiar el chunk de
    JSON **entero** (longitud + tipo + datos): cortando en el tipo se pierden
    4 bytes y el archivo queda corrido.
  · El modelo es `kappa_rig.glb` — **REHECHO con el rediseño**: el antiguo era
    un cabezón rechoncho con las piernas al 27% del alto y el andar/sentado lo
    DESFIGURABAN (una cuña verde enorme de carne arrastrada). El nuevo sale del
    mismo dibujo que sus retratos 2D (larguirucho, barrigón, plato llano),
    cadena completa vía `tmp-rig` con `humanoid_template_hands`: 52 huesos,
    piernas al 50.6% y brazos al 24.8% — anda y se sienta con la animación de
    verdad. `head_K.png` se regeneró de él (`FRAME_OVERRIDE` K bajó de 0.52 a
    0.30: la cabeza ya no es media altura).
- **RETRATOS 2D DEL KAPPA** (`assets/characters/kappa`, hablante `kappa`, 7
  moods: serio, hablando, enfadado, furioso, colerico, feliz, dormido):
  entrañable pero con un hambre terrible; le encanta dormir después de comer.
  El diseño costó SEIS bases: ni chibi (infantil), ni musculado, ni viejo — el
  bueno es un kappa JOVEN y larguirucho con barriga crema, pico de pato
  PEQUEÑO y saliente, plato llano en la coronilla y ceño de gruñón bonachón
  (referencia del usuario). Lecciones pagadas:
  · El pico oscila salvajemente entre pasadas: pidió tres tamaños ("bigger and
    wider" lo hizo babero, "smaller" lo dejó en boca de rana) — se acota
    DESCRIBIENDO el ancho contra los ojos ("no más ancho que el espacio ENTRE
    los dos ojos, saliente, acabando EN la barbilla").
  · La ira máxima recoloreó la cara entera a rojo demonio y NO vale (pedido
    del usuario: "demasiado diferente"): la piel se queda verde y la furia va
    en ceño, boca a gritos, pelo erizado y el AGUA DEL PLATO hirviéndose.
  · Las expresiones PIERDEN EL PLATO de la cabeza con facilidad ("furioso"
    salió dos veces sin él): se pide explícitamente que el plato se queda, y
    si aun así falta, una pasada aparte de "add back the plate" lo devuelve.
  · **El montaje es `tools/kappa_portraits.py`**: inundación desde los CUATRO
    bordes (viene entero y con aire), `ALTO_SUJETO = 1.30` — MAYOR QUE 1 a
    propósito: a cuerpo entero su cara medía ~80 px contra los ~135 del
    reparto, así que se compone DE CINTURA PARA ARRIBA anclando ARRIBA con
    `AIRE` y recortando por abajo — y el RECORTE es la UNIÓN de las cajas de
    todas las expresiones (el vapor del furioso se sale del cuerpo del serio;
    con la caja del serio se cortaba a cuchillo). La escala sigue saliendo
    solo del serio.
- **El contador de clientes del HUD cuenta los que SE HAN SENTADO**
  (`clients_seated`, que sube con la señal `client3d.seated`), no los que se han
  ido —con los idos se quedaba en 0 con la barra llena, que es justo cuando
  interesa saber cuánta clientela queda— y tampoco los que han APARECIDO. Un
  cliente tarda ~6 s en cruzar la cubierta, y contarlo desde que asoma por la
  borda lo daba por atendido antes de que llegara a su taburete: en el nivel 1,
  con David explicando que a veces alguien deja pasar un plato, el jugador
  miraba al que aún venía andando en vez de al que lo había despreciado. La FILA
  DE CABEZAS sigue el mismo criterio (`_update_client_heads` salta a los que no
  han llegado). `clients_spawned` sigue existiendo para la LÓGICA (cupo, cola de
  llegadas, `_adelantar_tipo`).
  **Y SU CUERPO DE LETRA SE REMIDE** (`_fit_top_row`, llamado desde
  `_update_hud` en cuanto cambian el ancho de la fila o `total_clients`): la
  medida diferida del arranque llega con el lienzo todavía asentándose, y
  decidirlo UNA sola vez dejaba el "120/120" del tutorial cortado por la
  derecha. Hay cuerpos hasta el 20 y la fila se remide también al cambiar el
  tamaño del viewport.
  Y quien adelante una llegada a mano (`_adelantar_tipo` del guion) tiene que
  **gastar su hueco de `arrival_queue`**, o entra un cliente de más y el
  contador se pasa del total.
- **En las ISLAS la carta la decide el DISEÑO, no el jugador**: van con
  `fixed_recipes` y no pasan por el selector NUNCA, tampoco al repetirlas.
  Además de `fixed_recipes_replay` (otra lista para cuando ya está superado),
  la carta cerrada admite dos variantes que dependen de lo que el jugador se
  haya ganado, para que el TAMAÑO de la carta no cambie:
  **`optional_recipes`** entra entera si está desbloqueada (el gunkan de
  wakame del nivel 2) y **`alt_recipes`** es una lista por PREFERENCIA de la
  que entra SOLO LA PRIMERA desbloqueada (en el 3: maki de pepino si lo tiene
  y, si no, gunkan de wakame).
  Como el jugador no elige, tampoco puede esquivar un ingrediente que le falte:
  antes de zarpar, el mapa lo comprueba (`GameState.missing_ingredients`).
  · **UNA RECETA QUE TODAVÍA NO ES SUYA NO PIDE DESPENSA**
    (`ingredients_for_selection` salta las no desbloqueadas en aventura): en la
    carta cerrada del nivel 1 está el nigiri de salmón, que David REGALA dentro
    del nivel con sus 10 usos, así que avisar de "te falta salmón" antes de
    zarpar era mentir.
  · **SIN TIENDA TODAVÍA (antes de superar el nivel 4) no hay callejón sin
    salida**: David aparece, regala `GameState.RESCUE_GIFT` (3) usos de lo que
    falte (`gift_missing_ingredients`) y se zarpa igual, tantas veces como haga
    falta. Lo mismo en `prep_screen` para los puertos de carta libre, si no
    queda NINGUNA receta jugable.
  · Con la tienda ya abierta, **Gigi canta lo que falta y para qué receta**,
    con un cartel de tres salidas — Jugar, Visitar tienda y una X que devuelve
    al mapa.
- **`recipe_slots` sí se suelta al repetir** (`GameState.port_beaten`): un
  puerto ya superado se juega con los cuatro huecos de siempre.
- **Los ingredientes GRATIS (coste 0) no se piden ni se gastan**:
  `ingredients_for_selection` los salta. El sésamo estaba dejando el uramaki
  California sin poder jugarse por un ingrediente que la tienda ni vende.
- **`recipes_for_port` tiene que mirar TAMBIÉN `reward_recipes_3`**: desde que
  las recompensas van en dos escalones, contar solo `reward_recipes` dejaba las
  de 3 estrellas fuera de la carta de todos los puertos siguientes.
- **La mano guía se monta DIFERIDA, en el mismo fotograma que el cambio de
  paso**: por eso un `drag_stage` con `from` tiene que volver a pedirla cuando
  cambia la etapa medio segundo después (si no, arrastra el sprite viejo), y
  por eso el barco combinado la repinta con cada plato colocado. El barco usa
  `_hand_drag_cycle`, que recorre TODOS los platos pendientes con su propio
  dibujo, igual que los pasos de elección.
- **`exclusive_dishes` de un puerto** (receta → personaje): mientras corre el
  guion, ese plato SOLO lo coge ese personaje (`plate3d.only_who`, filtrado en
  `client3d._scan_belt`). El tsuke don es el regalo de David para Pablo, y
  servírselo a un grumete le quitaba la gracia; al repetir el puerto no hay
  guion y el plato vale para cualquiera.
- **`gift_recipes` en un puerto**: recetas que REGALA David dentro del nivel
  (el nigiri de atún del 3, el tsuke don del 5). No están en `reward_recipes`,
  así que hay que declararlas para dos cosas: `recipes_for_port` las suma a la
  carta de los puertos siguientes —y a la del suyo propio, para cuando se
  repite— y `complete_port` las desbloquea al superar el nivel, por si la
  partida se cerró por objetivo antes de que David llegara a darlas.
- **El "x2" del tutorial tiene TRES desenlaces** y ninguno obliga a nada: con
  el grumete comiendo y un maki gratis en la mano, si el jugador lo manda a la
  **cinta** Gigi le corta (ese ya está masticando), si lo guarda en una **caja**
  David le da la razón, y si no hace nada el guion sigue sin comentar. Lo
  vigilan `_vigilar_maki_libre` (por `prep_board.stored_count`) y
  `_vigilar_maki_a_la_cinta` (por `dish_served`), compartiendo bandera para que
  hable UNO solo y una sola vez.
- **`prep_board.free_mistakes`**: mientras un guion ESTÁ ENSEÑANDO un gesto,
  fallar el corte lento no cuesta dinero (el aviso y el destello rojo siguen).
  El guion se entera por la señal `slice_failed`, aparte de `money_penalty`
  justamente para poder regañar sin cobrar.
- **EL AVISO DE "NO LLEVAS PLATOS DE N ESTRELLAS" CALLA EN EL NIVEL QUE ESTRENA
  ESE CLIENTE** (`prep_screen._clientela_desatendida`): Gigi regaña si el puerto
  trae piratas y la carta no lleva ningún plato de 2★, o capitanes y ninguno de
  3★ — pero NO en el primer puerto de la campaña con cada tipo
  (`CampaignData.first_port_with("A"/"G")`, deducido de los datos y no escrito a
  mano). Ahí el jugador no PUEDE llevarlo, porque todavía no tiene ninguno, y es
  David quien se lo regala dentro del propio nivel: el aviso solo servía para
  asustar por algo que ya estaba resuelto. Antes miraba A o G indistintamente y
  solo comprobaba las 2★, así que en un puerto de capitanes no avisaba de nada.
- **`prep_dialog` en un puerto**: aviso de David en el SELECTOR DE RECETAS
  antes de zarpar (`prep_screen._aviso_antes_de_zarpar`). Como los guiones de
  nivel, solo suena si el puerto no está superado.

## Arquitectura (archivos y responsabilidad)

- `scripts/recipe_data.gd` — datos const de las recetas: nivel, saciedad,
  cooldown, precio, `free_uses` (maestría), `vegetarian` (apta para clientes
  vegetarianos, aún sin efecto en cliente), `steps` (secuencia de gestos) y
  `stages` (sprite por paso). Ingredientes y helpers `get_dish_texture` /
  `get_stage_texture`. **Tipos de paso**: `tap_ingredient` {ingredient},
  `tap_board` {count, cutting?}, `drag_ingredient` {ingredient, prop?}
  (con `prop` el ingrediente hay que soltarlo SOBRE ese utensilio —el cuenco
  vacío del edamame— en vez de sobre la tabla entera),
  `swipe_board` {count, direction: up/down}, `hold_board` {duration},
  `stir_board` {count} (remover en círculos sin soltar; cuenta vueltas
  completas alrededor del centro de la etapa), `slice_board` {count, duration,
  cut_stage?} (corte LENTO de izquierda a derecha que puede empezar en
  CUALQUIER punto de la tabla; la barra representa SOLO el corte en curso: se
  llena entera con cada corte y se vacía para el siguiente; el recorrido debe
  durar AL MENOS `duration` s —0.7 en el atún rojo—, más rápido = mensaje
  "¡Más lento!", destello rojo y repetir; tras un corte intermedio se muestra
  el sprite `cut_stage`), `drag_choice` {options, stage_by, result_by}
  (elección de ingrediente: salen TODAS las opciones y hay que llevar UNA a la
  tabla; la elegida fija la etapa siguiente y la identidad del plato final — el
  aburi sale como `aburi_atun` si se elige atún; el cooldown recae SIEMPRE en la
  receta elegida vía `ready_base`. Vale de las DOS maneras: arrastrar directo, o
  TOCAR primero para marcar —los demás se apagan— y arrastrar después. Un toque
  suelto nunca lo lleva a la tabla, solo marca. El cartel dice "¡Elige uno!"
  hasta que hay algo marcado y luego "¡Arrastra!", y la mano guía va
  ALTERNANDO entre todas las opciones —una por vuelta— hasta que se marca una,
  momento en el que señala solo esa), `fry_board` {target}
  (freír a pulso: contador con milésimas, SIN barra; al soltar se resuelve por
  `FRY_WINDOWS`; crudo/carbonizado se desliza fuera de pantalla, cuesta
  `FRY_WASTE_PENALTY`=5 y entra el cooldown), `drag_stage` {prop, from?}
  (aparece un utensilio —sprite de `assets/stages`— animado en la esquina
  inferior derecha de la tabla y se arrastra el sprite de etapa hasta él;
  exige arrastre REAL >24 px y soltar sobre el prop, un toque no cuenta. Con
  `from` lo que se arrastra NO es el resultado del paso anterior: se ve ese
  resultado medio segundo y luego la etapa cambia sola al sprite indicado. Lo
  necesita el **salmón tsuke don**, donde el paso previo deja montado el cuenco
  de arroz —que es el DESTINO— y lo que se coge es el salmón que reposaba en la
  soja).
  `stages` tiene un id de sprite por paso ("" = ninguno); el último stage
  no-vacío se descarta al emplatar (el plato final es el mismo voxel que el
  emplatado).
- `scripts/powerup_data.gd` — catálogo de potenciadores DE PARTIDA: salen del
  bote de propinas dentro del nivel. **TODOS son AUTOMÁTICOS** y son **16**
  (una, "Horas extra", solo se sortea donde hay reloj). Cinco tocan el sistema
  de hastío y variedad: "Variedad para todos" (+1 a los sentados), "Sobremesa
  dulce" (el próximo postre cobra el doble, `dessert_boost`, que solo se
  consume si había multiplicador que cobrar), **"Manos libres"** (30 s en los
  que CUALQUIER plato se puede picar sin soltar el que se come, no solo los
  `snack`), **"Nada se tira"** (1 min sin cubo: el plato empieza otra vuelta
  y `_forget_declined` le borra la marca de RECHAZADO en todos los clientes —
  sin ese olvido daría vueltas eternas sin que nadie pudiera cogerlo, porque
  el dado se tira una sola vez por cliente y plato) y **"Doble variedad"**
  (15 s con los multiplicadores y su TOPE al doble; al expirar cada cliente
  vuelve a la mitad redondeando HACIA ARRIBA, para no castigar al que subió
  durante el doblete). Llegó a haber 20, la
  mitad de ellos `manual` (se guardaban como botón bajo el chef para gastarlos
  cuando conviniera). Se quitaron las dos cosas: lo manual obligaba a decidir
  DOS veces —cuál cojo y cuándo lo gasto— en una partida de 2:30, y de veinte
  entradas había parejas que hacían lo mismo (dos de enfriamiento, dos de
  propinas, dos de almacén y TRES de "vienen clientes de más", una por tipo),
  así que de tres opciones sorteadas lo normal era que dos fueran
  indistinguibles. La cabecera del archivo lista cuáles se cayeron y por qué:
  **leerla antes de reintroducir ninguno**.
  El **cartel de elección SIGUE PAUSANDO EL JUEGO ENTERO** (cinta, reloj,
  paciencia y bocados): lo que se recortó es lo que hay que LEER, no el tiempo
  para leerlo. Cada opción es una tarjeta con **DIBUJO + TÍTULO y nada más**
  (`level3d._make_powerup_card`); antes era "nombre (automático)\ndescripción"
  con ajuste de línea, o sea tres párrafos con el juego parado. Por eso el
  `name` de cada potenciador tiene que **sostenerse solo**, sin la línea de
  apoyo — el `desc` sigue en los datos, pero la tarjeta no lo dibuja.
  Los iconos son `assets/ui/pot_*.png`, generados con Ludo y procesados por
  `build_powerups()` de `tools/ui2_prep.py`.
  **Ese `build_powerups` usa `drop_specks`, NO `keep_largest`**: media docena
  de estos dibujos se explican con una pieza que FLOTA separada del sujeto (los
  remolinos del aroma, el corazón verde sobre el grumete, las monedas cayendo
  al bote, el destello de la receta instantánea). Quedarse con la isla de alfa
  más grande se las comía y dejaba tres nigiris pelados en el cartel; pasó y
  hubo que rehacer el recorte. `drop_specks` tira solo lo que no llega al 0,3%
  de la isla mayor, que es lo que de verdad son motas.
  Y `fill_white_holes` (ui2_prep) transparenta el blanco que quedó ENCERRADO
  tras la inundación desde los bordes: el hueco entre la papelera y su tachado
  en `pot_sin_basura` y el fondo entre el engranaje y la llave de `ic_opciones`
  salían blancos opacos. Se aplica SOLO a esos dos iconos a propósito — en
  otros dibujos un blanco interior es arte (el arroz).
- `scripts/perk_data.gd` — catálogo de potenciadores **PERMANENTES** (`PerkData`,
  no confundir con los anteriores): se ganan haciendo un COMBO en partida, se
  eligen antes de zarpar junto con las recetas, gastan 1 uso por partida y se
  compran más usos con doblones desde el Inventario. Los dos actuales:
  `cocina_veloz` (cooldown a la mitad toda la partida; se gana cuando un mismo
  cliente come 5 platos) y `ayudante` (un ayudante 3D aparece junto al chef y
  añade su BOTÓN a la tabla —a la IZQUIERDA, debajo del de combinar; pegado al
  de Cancelar se pulsaba uno por otro, y su disco enseña la CARA recortada del
  retrato de cuerpo entero—: se enciende en el
  PRIMER paso de una receta y al pulsarlo la termina él solo (DA maestría, así
  que los makis/futomaki sueltan sus platos extra, y limpia la fila de
  ingredientes: el plato aparece hecho de golpe), con `HELPER_COOLDOWN`=30 s de
  descanso. Avisa por la señal `helper_used` para que el ayudante 3D amase un
  momento y dé un saltito. Se gana sirviendo 18 platos en una partida).
  Y dos más, de la tanda de variedad: `paladar` ("Paladar de capitán": sube el
  TOPE del multiplicador de x5 a **x10** toda la partida; se gana cuando 4
  clientes llegan a x5 en una misma partida — la cuenta la lleva
  `level3d.clients_maxed`, que mide contra el tope BASE y no contra el
  vigente, o llevarlo ya puesto haría casi imposible volver a ganarlo) y
  `barco` (ver abajo).
  **`PerkData.UNLOCKS_ENABLED` pasó a `true`**: estuvo apagado mientras no
  estaba decidido el sitio de los permanentes en la progresión, y se abrió al
  entrar el BARCO como bonificador — con él apagado, el barco sería
  inalcanzable y desaparecería del juego.
  **También funcionan en el ARCADE** (desde el rediseño del arcade sin fin):
  el modo cobra arroz y despensa como cualquier jornada, así que se juega con
  todo puesto y los usos se gastan igual. La regla vieja de "Arcade no toca el
  progreso" está MUERTA — ver el bloque del ARCADE SIN FIN.
- `scripts/skill_data.gd` — **MAESTRÍAS DEL COCINERO** (`SkillData`), el
  sistema de nivel 1-450 con tres árboles de habilidades. Solo datos y helpers
  puros; el ESTADO (chef_xp, chef_level, skills, arcade_best) vive en GameState
  y se guarda en el save. Las reglas, todas en la cabecera del archivo:
  · **450 niveles = 450 puntos** (el nivel 1 ya trae el suyo) = el catálogo
    entero (150 por árbol). Curva de XP en RECTA: 60 + 20·(n−1).
  · **LOS PUNTOS SE INVIERTEN DE UNO EN UNO, y el RANGO es su escalón**
    (decisión del usuario, no re-litigar). `GameState.skills` guarda los
    PUNTOS invertidos, no el rango, y `SkillData.rank_for_points` lo deriva:
    con coste 5, cuatro puntos NO desbloquean nada y el quinto sube al rango
    1. Así el jugador reparte punto a punto y puede repartirse 6 puntos entre
    dos habilidades sin que ninguna se lleve un rango entero de golpe (antes
    el [+] gastaba los 5 de una vez, que es lo que se veía como "no reparte
    bien"). El total no cambia: 25 puntos una habilidad normal, 50 la final.
    En el save va bajo la clave **`skill_points`** — clave NUEVA a propósito,
    porque un 3 en el formato viejo era el rango 3 (15 puntos) y aquí son 3
    puntos; `load_game` convierte los guardados viejos multiplicando por el
    coste del rango.
  · **SUBIR DE NIVEL** (`SkillData.level_reward`) da SIEMPRE el punto y ORO
    (`30 + 5·n`, realzado ×1,2 en los múltiplos de 5, ×1,5 en los de 10 y ×2
    en los de 25 — suave a propósito: con la escalera vieja ×2/×3/×4 el nivel
    corriente se quedaba en nada al lado del hito, y cada nivel ya paga solo).
  · **Y CADA PREMIO DE BODEGA TIENE SU PROPIA CADENCIA**
    (`SkillData.REWARD_CADENCIA` + `toca_premio`, resuelto por MÓDULO del
    período, no recorriendo la serie): cebo cada **5·6·7** niveles desde el 7,
    arroz cada **10·11·12** desde el 4, lingote cada **11·12·13** desde el 7,
    extras cada **6·7·8** desde el 6 y despensa cada **7·8·9** desde el 6.
    El CICLO DE TRES HUECOS es lo que evita que las series se sincronicen: con
    un hueco fijo, dos premios de igual período caerían siempre juntos y
    habría niveles cargados y niveles pelados. Las cantidades de despensa y
    extras suben un escalón cada 100 niveles y nada más — lo que hace valioso
    el premio es que CAIGA, no que crezca.
  · **COMPUERTAS: un premio no cae hasta que el juego lo ha EXPLICADO**
    (`GameState.reward_gates`, que `add_chef_xp` le pasa a `level_reward`):
    cebo con la PESCA abierta, arroz con `rice_intro_done`, lingotes con
    `ingots_intro_done` (Pablo), despensa con la TIENDA y extras con
    `extras_done`. Los cuatro últimos estuvieron un tiempo DESACTIVADOS del
    todo justamente por esto —caían antes de que el jugador supiera qué tenía
    en la mano— y volvieron con las compuertas puestas. Si a un nivel le tocaba
    un premio aún cerrado, ESE premio se pierde y no se guarda para después:
    la serie es una cadencia, no una deuda. El oro y el punto no llevan
    compuerta: se entienden solos.
    Los entrega `GameState._grant_level_rewards` en el acto.
  · **EL CEBO ES `GameState.bait`**, una sola cuenta con DOS fuentes: los tres
    que regala Cai al acabar su clase y los de las subidas de nivel. Antes
    eran las "tiradas gratis" de Cai (`free_casts`, que migra al cargar); un
    segundo contador que hiciera lo mismo con otro nombre solo habría
    confundido. El botón de pescar enseña el CEBO en vez de la moneda cuando
    quedan (`_refresh_cast_label`).
  · **QUIÉN ANUNCIA LA SUBIDA**: `add_chef_xp` NO saca ventana — deja el
    resumen en `pending_level_up` y lo enseña quien tenga la pantalla delante
    (el cartel de fin de nivel tras llenar su barra, o el menú tras la suya),
    con `take_level_up()`. Una SOLA ventana aunque caigan cinco niveles de
    golpe, con el botín sumado: cinco carteles seguidos serían un castigo. La
    dibuja `NoticeLayer._show_level_up`, que ya sabe respetar la pausa que
    tenga puesta el cartel de resultados.
  · **LA SIEMBRA RETROACTIVA VA POR BANDERA PROPIA (`xp_seeded`), NO por "¿le
    falta la clave chef_xp?"**: la primera versión miraba la ausencia de la
    clave y bastaba con que el juego guardara UNA vez (con un 0 dentro) para
    que la siembra no pudiera dispararse jamás. Pasó de verdad: una partida
    con nueve escenarios superados se quedó sin sus estrenos. Con la bandera
    se dispara una sola vez y se puede volver a lanzar borrándola del save.
  · **Y CERRAR PASADO EL OBJETIVO PAGA PRIMA** (`GameState.scenario_extra_xp`,
    `SkillData.XP_EXTRA_FRAC`): el oro que sobre por encima del escalón de las
    3 estrellas —contando la jornada ENTERA: platos, propinas y primas de
    cierre— da experiencia extra a la TARIFA DEL PROPIO ESCENARIO, es decir
    "lo que paga dividido por su objetivo", y de esa tarifa se cobran DOS
    TERCIOS. Que la tarifa salga del escenario es lo que la hace crecer con la
    campaña: la misma moneda de más vale 0,45 de XP en el escenario 1 y 4,9 en
    la cueva. MEDIDO con sonda: +10 monedas son +5 XP en el 1 (27 → 32) y +49
    en el 20 (810 → 859). Tope de seguridad en `XP_EXTRA_CAP`: la prima nunca
    pasa de lo que paga el escenario. Va SUMADA Y SIN DESGLOSAR en el cartel
    de resultados (pedido por el usuario): la cifra sale sola.
  · **La XP de un escenario se paga CONTRA EL RÉCORD** (`GameState.
    scenario_xp`, llamada en `_finalize_results` con las estrellas de ANTES de
    `complete_port`): estreno = 3 × 6·n × mult(estrellas ×0.5/×1/×1.5);
    repetir paga la tarifa simple y MEJORAR el récord cobra solo la
    diferencia ×3. Así un escenario deja lo mismo se borde al primer intento o
    al quinto, y no compensa "guardarse" el aprobado.
    **LOS ESCENARIOS DE JEFE PAGAN ×1,5** (`SkillData.XP_BOSS_MULT`; estuvo en
    ×2 y el usuario lo bajó). Multiplica la BASE, así que el plus llega igual
    al estreno, a la repetición y a la mejora de récord. Sobre los 250
    previstos son ~44.000 XP extra (+5%). Hoy solo `nivel_15` lleva `boss`:
    540 → 810 a tres estrellas.
    **OJO CON LA FÓRMULA AL MEDIRLA DESDE FUERA: la base es `XP_SCENARIO × n`
    (6·n), NO `XP_SCENARIO × 6 × n`.** Una sonda que metió ese ×6 de más
    reportó "el mar acaba en nivel 35" cuando la calibración real acaba en 16;
    se perdió una ronda de recalibración persiguiendo un problema inventado.
  · **HAY TRES FUENTES DE XP y `chef_rec` SE MIDE, no se calcula**: es el
    nivel al que se llega bordando todos los escenarios anteriores con la
    curva real (simulado, y la sonda comprueba que la lista guardada cuadra).
    La fórmula vieja `ceil(n × 1.09)` murió con la curva cuadrática. Bordando
    el mar 1 entero (jefe ×1,5 incluido): **5.940 XP → nivel 16 clavado**,
    que es el cierre que pidió el usuario; aprobando justo con 2★, nivel 13.
    Lo que falte en mares posteriores lo ponen la PESCA y el ARCADE.
    · `XP_SCENARIO` estuvo en **15** y era muchísimo: tres escenarios bordados
      dejaban al cocinero en el **nivel 5** (68+135+203 = 406 XP contra los
      360 del nivel 5). A **6**, esos mismos tres dan 162 → nivel 3, y el
      escenario 15 deja el nivel 16 contra los 17 que recomienda. SIMULADO
      escenario a escenario, no a ojo.
    · `ARCADE_WAVE_XP` bajó con él (15 → **6**): dejarlo arriba habría hecho
      del arcade la única forma sensata de subir de nivel.
    · **La PESCA paga por CAPTURA y manda el TAMAÑO** (`SkillData.fishing_xp`,
      sumada en `GameState.fishing_apply`): `FISH_XP_TIER` es el suelo por
      rareza y la talla lo estira hasta ×1,5 — de 5 (común canijo) a 39
      (legendario de récord). Un pez **REPETIDO paga la MITAD**: lo que se
      premia es descubrir catálogo, no dragar la misma especie. Es goteo, no
      atajo: cerrar el escenario 5 paga 135. Se ve subir en el acto sobre la
      BARRA DE NIVEL, que se queda puesta durante la pesca.
    · **La curva NO se re-siembra al tocarla**: la XP ya ganada se queda como
      está (quitarle niveles al jugador, con sus puntos ya repartidos, sería
      peor que la inflación).
  · Comprar una habilidad = 5 puntos y cada rango extra 5; la QUINTA de cada
    árbol 10 y 10. La 3ª pide las dos primeras, la 4ª la 3ª, la 5ª la 4ª.
    `buy_skill` guarda; la pantalla CONFIRMA antes (patrón de Bonificadores).
  · **EL TECHO CONTRA EL QUE SE CALIBRA ES ×2,0** (revisado el 18-8-2026; era
    ×2,5). Los tres árboles al máximo multiplican el oro ~×2,45, pero ESE
    JUGADOR NO EXISTE: los `star_money` de los escenarios futuros se escalan
    contra ×2,0, que es el reparto realista. El 450 es techo de COMPLETISTA,
    lo que encaja con tener un arcade sin fin. Al tocar un valor, rehacer las
    cuentas.
  · **LA CAMPAÑA SON 250 ESCENARIOS** en 7 mares (~36 por mar, jefe cada 10 =
    25 jefes). Con la tarifa vigente (base 6·n, jefes ×1,5, curva cuadrática):
    bordándolos todos, 891.000 XP → **nivel ~120**; aprobando justo (2★),
    594.000 → nivel ~103. O sea que solo los escenarios reparten en torno a
    un cuarto del catálogo de 450 puntos, y el resto es pesca, arcade y los
    mares que se rejueguen: al diseñar mares nuevos, medir contra esto. Hoy
    solo existen los 20 del primer mar.
  · **EFECTOS cableados donde ocurre el suceso**, cada uno con su valor neutro
    sin comprar: `prep_board._apply_skills()` (cooldown, hold/fry/slice/swipe/
    taps, golpe de vista con su CONTADOR VISIBLE `vista_label`, cocina
    abundante por double_next, buena mano en stack_max, golpe de suerte con el
    plato DORADO y `serving_lucky` → `plate3d.variety_bonus`),
    `client3d._ready` (recarga, precio, propinas con TOPE respetado, suelo de
    take chance que NO toca postres de otro tipo, paladar generoso — `tried`
    pasó de banderas a CONTADORES con `_tolerancia`/`_es_nuevo`) y
    `level3d._apply_perks` (vueltas de plato, castigo del cubo `waste_frac`,
    olvido por vuelta). **En el tutorial todo queda en neutro.**
  · Los contadores deterministas (vista/abundante/suerte) son CONTADOR, no
    dado, a propósito: se puede planear el plato gratis o el doble. El de
    vista solo avanza con platos hechos A MANO y su gratis se consume DESPUÉS
    del potenciador instantáneo y de la maestría de la receta.
  · La subida de nivel sale como TOAST por NoticeLayer (uno aunque caigan
    varios niveles de golpe) y el cartel de resultados lleva la línea
    "+N de experiencia" (`last_xp`).
  · **`chef_rec` en cada puerto** (CampaignData) **se MIDE con la simulación**
    (el nivel de llegada bordando todo lo anterior); hoy va del 1 al 15 con
    repetidos donde un escenario corto no da para subir (1-2-3, 6-7, 11-12,
    16-17 comparten recomendación, y es correcto). Lo enseña la ficha del
    mapa, con "(llevas N)" si el jugador va corto: distingue "voy corto de
    nivel" de "lo juego mal". La recomendación es el listón de las MAESTRÍAS,
    no un requisito.
  · **El ACCESO es la BARRA DE NIVEL** (`main_menu._setup_level_bar`):
    estrella cabalgando el canto CON UN "+" DENTRO (crema en reposo, ROJO y
    latiendo en cuanto hay un punto libre: es lo que dice que ahí se mejoran
    las maestrías), "Nivel N", relleno de XP y el globo con los puntos libres.
    Tocarla abre Maestrías — POR ESO EL SUBMENÚ NO LLEVA ICONO (volvió a
    cinco; `ic_maestrias` sigue existiendo para el logro de niveles). Aparece
    con la primera experiencia.
    **VIVE EN EL MENÚ, EN EL MAPA Y EN LA PESCA**, y su sitio lo decide
    `_level_bar_spot`: centrada bajo los contadores en el menú, y en el mapa a
    la altura del botón "Atrás" pero CENTRADA EN EL HUECO que ese botón deja
    —la franja que liberó el lazo de "Aventura" al quitarse—, no pegada al
    canto. Viaja DENTRO de `_place_resources`, con los contadores, y por eso
    `_ui_out`/`_ui_in` llevan un `con_nivel` que se pasa en false al ir y
    volver del mapa: si no, el tween de la entrada y el del viaje pelean por
    su `position`. Solo la PORTADA y la FICHA la apagan a mano
    (`_set_menu_ui_visible` ya no la toca).
    **EN LA PESCA baja `LVL_BAR_PESCA` (76 px)**: arriba están el "Atrás" de
    la pesca y el botón del álbum, uno en cada esquina, y la barra les caía
    encima. Va de ESCAPARATE (`MOUSE_FILTER_IGNORE` mientras dura, restaurado
    al cerrar): el panel táctil de la pesca cubre la pantalla entera y una
    barra pulsable encima sería la trampa de irse a Maestrías con el pez
    enganchado. Cada captura emite `fishing_game.xp_gained` y el menú saca el
    **"+N exp"** flotando sobre ella (`_xp_en_la_barra`) y la llena; sin eso la
    experiencia de la pesca se sumaba en silencio.
    OJO con el globo: su anfitrión va con **posición y tamaño explícitos**, no
    con `set_anchors_preset` — el preset no toca los offsets y con un
    anfitrión de tamaño cero el globo no llegaba a dibujarse (la trampa de
    siempre, ya documentada más abajo).
  · **LA BARRA DE XP SE LLENA EN EL CARTEL DE FIN DE NIVEL, no en el menú**
    (`level3d._build_xp_row` / `_play_xp_gain`, llamada tras el recuento del
    oro): ahí es donde el jugador está mirando. Va bajo la cifra del oro, con
    el "+N de experiencia" DEBAJO —OJO: `earn_label` vive DENTRO del HBox de
    la moneda, así que la fila se cuelga del PADRE o el texto sale al lado de
    la cifra— y el cartel crece 62 px para que quepa. Al terminar CONSUME
    `GameState.xp_anim_from`, así que la barra del menú aparece ya llena; si
    el jugador se sale sin ver el cartel, la anima el menú
    (`_play_xp_anim_if_pending`). Las dos llenan por TRAMOS DE NIVEL y cada
    frontera cruzada suelta su fogonazo (destello, bote y "¡Nivel N!").
  · Pantalla `skills_screen` (**Maestrías**), en TRES SECCIONES: una PESTAÑA
    por árbol con su icono propio (`tab_cuchillo/tab_cliente/tab_chef`, de la
    cadena `build_skills`) y dentro sus cinco habilidades en tarjetas.
    Enseñar un árbol cada vez es lo que deja sitio para los ICONOS GRANDES:
    con los tres a la vez se quedaban en 88 px y las cifras no se leían.
    Cada tarjeta lleva el icono (marco por ESTADO: gris bloqueada con el
    dibujo oscurecido, neutro disponible, color del árbol aprendida, ORO al
    máximo), el nombre, **las ESTRELLAS = RANGO** y una fila de reparto
    **[−] x/N [+]**: el **"x/N" son los PUNTOS ENTREGADOS** hacia el rango
    siguiente (dos cifras distintas a propósito; la N es 5 salvo en las
    finales, que valen 10 por rango) y los dos discos lo FLANQUEAN, pequeños
    (`PM_SIZE` 46). En su propia fila debajo y a 56 px eran dos botones
    sueltos sin dueño. Tocar el icono abre su ficha, donde también se
    reparte. **SIN cinta de título**: la cabecera ya identifica la pantalla y
    el lazo rojo solo robaba alto.
  · **`boton_menos.png` NO SE GENERA: SE DERIVA de `boton_mas.png`**
    (`derive_minus_button` en ui2_prep) — mismo disco, mismo aro dorado y
    mismo bisel, con el campo verde teñido de rojo y la cruz crema recortada
    a su brazo horizontal. Pedido a Ludo aparte salía un disco rojo PLANO y
    se veía que los dos no eran pareja. Dos cosas que costaron una pasada:
    la cruz hay que DILATARLA antes de borrarla (si no su antialias sobrevive
    y deja el fantasma del brazo vertical), y el hueco se rellena
    INTERPOLANDO DE LADO A LADO en su fila, no con la media de cada ANILLO —
    a ese radio el anillo pasa por el brillo de arriba a la izquierda y lo
    repartía en manchas por todo el círculo.
  · **RAMAS**: las cinco habilidades van UNIDAS por líneas (`_dibujar_ramas`,
    `_paint_ramas`) — barra entre las dos primeras, tronco que baja por el
    PASILLO entre columnas hasta la barra de la 3ª y la 4ª, y sigue hasta la
    5ª. Va por el pasillo a propósito: es la única franja vertical libre
    (bajando por el eje de una tarjeta, la rama cruzaría su nombre, sus
    estrellas y sus botones). Se dibujan ANTES que las tarjetas (el orden de
    hijos es el de dibujado) y se ENCIENDEN cuando la habilidad a la que
    llevan es alcanzable, así que se repintan desde `_refresh_all_icons` con
    cada [+] / [−] — solas no se enteran.
  · **"Reiniciar maestría"** al pie de cada árbol
    (`GameState.reset_skill_tree`): devuelve TODOS sus puntos de golpe, con
    confirmación que dice cuántos son. NO pasa por `refund_skill` a propósito
    — ese tiene el candado de los prerrequisitos y aquí se van todas a la vez,
    así que ninguna se queda huérfana.
  · **CABECERA**: sin el rótulo "Nivel de cocinero" — la estrella con el
    número en Exo2-Bold, la barra con la experiencia ESCRITA DENTRO
    ("210 / 400") y a la derecha la CHAPA de puntos libres, que se apaga
    cuando no queda nada que gastar y RESPIRA cuando sí.
    · La chapa es `chapa_puntos.png` (medalla de oro con el disco azul VACÍO,
      el número se imprime encima): era un círculo azul liso dibujado por
      código y al lado del resto del set se leía como un marcador de
      posición. Su dibujo NO está centrado —el laurel del pie baja el
      conjunto—, así que la cifra se coloca contra `CHAPA_P_CY` (0.458),
      MEDIDO sobre el PNG.
    · **La barra se alinea con el centro VISUAL de la estrella, no con el de
      su caja** (`ESTRELLA_CY` 0.536, medido sobre el alfa de
      `estrella_llena.png`): una estrella tiene las puntas fuera y su masa cae
      por debajo del medio, así que centrada a lo geométrico la barra queda
      visiblemente alta.
    · **El ancho de `content` se calcula, no se clava** (`_ancho()` =
      lienzo − 112): estuvo a 636 a mano y la chapa se salía por detrás del
      marco del pergamino (el lienzo real mide 730, no 720).
  · **CADA SUBIDA DE RANGO SE CELEBRA** (`_celebrar_rango`): la del rango 1
    dice "¡Habilidad aprendida!" y las demás CANTAN EL CAMBIO, con el efecto
    viejo y el nuevo uno debajo del otro ("un 8% más cortos" → "un 12% más
    cortos"), que es lo que el jugador quiere saber al gastar un punto. **Y
    la del rango 1 lleva QUÉ HACE** (el efecto del rango 1 + la descripción):
    enseñaba solo el nombre, que es justo lo que no explica nada de lo que
    el jugador acaba de comprar sin verlo.
  · **CADA HABILIDAD TIENE SU PROPIO ICONO** (`assets/ui/skill_<id>.png`,
    `SkillData.icon` con la moneda de respaldo): Ludo → `_gen/ui2/skills/` →
    `build_skills()` de ui2_prep (drop_white + drop_specks, NUNCA
    keep_largest: destellos y monedas sueltas son arte). DOS TRAMPAS pagadas:
    el image_type "icon" de Ludo METE RÓTULOS DE LOGO aunque el prompt
    prohíba el texto (salió "GAME" dos veces seguidas, una de ellas por la
    propia palabra "game" del prompt) — los iconos de objeto van SIEMPRE con
    "item-icon", como los coleccionables.
  · Tocar un icono abre su POPUP (dibujo con marco de color, nombre, rangos
    en estrellas, descripción, "Ahora/Siguiente" y el REPARTO con [−] y [+]):
    **LA REASIGNACIÓN ES LIBRE Y CONTINUA, punto a punto** (decisión del
    usuario). El [+] compra en el acto (el [−] existe para arrepentirse) y el
    paso 0→1 se celebra con la ventana de "¡Habilidad aprendida!" (corona de
    estrellas); el [−] con rango 1 PREGUNTA ("vas a perder esta habilidad") y
    se BLOQUEA si el punto sostiene a otra aprendida
    (`GameState.can_refund_skill`: solo veta el último punto de un
    prerrequisito con dependientes). `refund_skill` devuelve los puntos.
  · El logro "Manos que aprenden" cuenta por `max_stat("skills_owned")` —
    máximo de habilidades con rango A LA VEZ, no compras: con reasignación
    libre, contar compras se inflaba comprando y quitando la misma.
- **EL BARCO PIDE DOS LLAVES**: que el puerto lo permita (`boat` en
  `CampaignData`; con la campaña-escuela lo llevan los niveles 8-10, sin guion
  que lo presente — su presentación queda para los niveles futuros) **Y** que
  el jugador lleve puesto el bonificador `barco`. Si falta cualquiera de las
  dos, su botón ni aparece (`prep_board.hide_boat`). Se gana teniendo **3
  platos guardados en 2 cajas distintas** a la vez (lo vigila
  `level3d._on_storage_changed` con la señal `storage_changed`, y basta con
  que ocurra una vez en la partida).
- `scripts/daily_data.gd` — **BONUS DIARIO** (`DailyData`): siete escalones por
  días CONSECUTIVOS. La racha sube solo si el último cobro fue AYER (con un
  hueco vuelve a 1: premia venir a diario, no acumular días sueltos) y pasado
  el 7 vuelve a empezar, así que el ciclo se repite. Va contra el reloj del
  aparato, como los sacos de arroz: adelantarlo regala días, asumido.
  El **día 7 es el ÚNICO sitio donde se consigue el DRAGON ROLL** — se quitó
  de las recompensas del nivel 9 para que la racha tenga un premio que no se
  pueda ganar de otra forma, así que la campaña cubre 33 de las 34 recetas
  visibles. **Completado el 7 la racha se reinicia al 1 y hay que desbloquearlo
  todo otra vez**; en esa segunda vuelta la casilla del 7 ya no da la receta
  sino `RECIPE_FALLBACK` (**200**) doblones ADEMÁS del resto de su premio, o
  sea 300 de oro. Solo sale en el menú de verdad, con el tutorial ya hecho y
  después del anuncio de recetas, para no apilar carteles.
- **El cartel del bonus diario es un MAPA DEL TESORO** (`main_menu._show_daily`
  y compañía). Las siete paradas llevan un cofre y el estado se lee del dibujo:
  los días PASADOS con el cofre ABIERTO y los que FALTAN cerrado, los dos a
  tinta como parte del mapa; el de HOY es el único A COLOR y se mece esperando.
  · **Los cofres de tinta son el MISMO dibujo que el de color**, pasado por
    `inkify()` de `tools/ui2_prep.py` (rampa de DOS puntos: más oscuro que
    `oscuro` es trazo pleno, más claro que `corte` no existe). Se derivan y no
    se generan aparte porque con otra silueta encenderse parecería cambiar de
    objeto. La primera versión usaba una rampa proporcional a la luminosidad y
    dejaba la madera como una mancha semitransparente: el cofre salía gris
    lavado. Hay que TIRAR los tonos medios, no atenuarlos.
  · **La ruta de puntos y las paradas se pintan POR CÓDIGO** (`DAILY_ROUTE`, en
    fracciones del mapa), no en la textura: es la única forma de que los cofres
    caigan clavados sobre la línea. Mismo criterio que la barra de progreso.
    El mapa generado va SIN ruta ni cofres y con el centro vacío a propósito.
    Las siete alturas van repartidas a PARTES IGUALES (0.845 -> 0.135); la
    primera versión las amontonaba abajo y dejaba media hoja vacía. Con ese
    reparto quedan ~78 px entre filas y el hueco del cofre mide 96 de alto, así
    que **dos cofres seguidos se solapan SIEMPRE en vertical y lo único que los
    separa es la horizontal**: el zigzag tiene que saltar más que el ancho del
    hueco (104 px) en CADA paso, no es una decisión estética. Dentro de eso,
    cada fila elige columna esquivando lo que el pergamino ya trae dibujado
    (rosa de los vientos, voluta, barco, palmeras y peñasco).
  · **El premio NO se cobra al abrir el cartel ni al TOCAR el cofre: se cobra
    cuando el cofre SE ABRE** (dentro del `tween_callback` que cambia la
    textura a "abierto", en `_open_daily_chest`), y hasta entonces el cartel no
    se puede cerrar: no hay X ni toque fuera, solo el cofre. Con el cobro
    automático original, cerrar mal era perder el día; y cobrando al TOCARLO,
    las cajas de la cabecera ya traían sumado el saco de arroz con el cofre
    todavía cerrado — parecía que el nivel no había gastado su arroz y que el
    bonus tampoco daba ninguno. El botín viaja en un DICCIONARIO porque las
    lambdas de GDScript capturan por VALOR. El botón "Continuar" aparece solo
    DESPUÉS, en `_daily_done`.
  · **La PRIMERA vez lo presenta David** (`main_menu._explicar_bonus_diario`,
    bandera `daily_intro_done`), justo después de la felicitación del nivel 1 y
    antes de que salga el cartel.
  · El cartel del botín (`_show_daily_reward`) **crece con lo que haya caído**
    (`ceili(fichas / DAILY_CHIPS_ROW)` filas): el día 3 son dos fichas y el 7
    son siete, y con alto fijo los días flojos salían medio vacíos. Va más
    estrecho que el panel del mapa y atenúa el mapa mientras está puesto.
  · `daily_mapa.png` es la ÚNICA textura de `assets/ui` en WebP con pérdida
    (`compress/mode=1`): la regla de dejar el set en Lossless es por el alfa de
    los bordes que ESTIRA el 9-slice, y el mapa es un sprite plano. 600 -> 66 KB.
    Nadie lo referencia por UID (se carga por ruta), así que cambiar el modo no
    deja avisos de `invalid UID`.
- **MINIJUEGO DE PESCA** (`scripts/fish_data.gd` + `scripts/fishing_game.gd`):
  el pergamino **"Pesca"** del menú, entre Arcade y Tienda (`ic_pesca`),
  **SE ABRE AL SUPERAR LA ISLA DE GADES (nivel 8)**, que es donde CAI se enrola
  y da la clase: `GameState.fishing_unlocked()` busca el puerto con
  `unlocks_fishing`. **OJO: devuelve en el PRIMERO que lo lleve**, así que ese
  campo tiene que estar en UN SOLO puerto — el nivel 5 se quedó con el suyo de
  cuando la pesca era suya y la abría dos niveles antes, con lo que el jugador
  llegaba a la pantalla sin haber recibido la clase (los diálogos de Cai sí
  salían, en el sitio equivocado).
  **NO cambia de escena**: como Aventura, se
  juega SOBRE el propio menú — `_go_fishing` aparta la interfaz con
  `_ui_out(false)` (las cajas de recursos SE QUEDAN, que el intento cuesta
  dinero), **esconde `menu_panel` y `submenu_bar` del todo** (bajados 660 px
  seguían asomando con el timón) y cuelga `FishingGame` (un Control) del
  `ui_layer`; su señal `closed` deshace el camino y `money_changed` refresca
  las cajas (`_refresh_resources`). El barco se queda quieto donde está.
  · **FLUJO (estilo Animal Crossing)**: el botón ÚNICO de la pesca
    (`boton_pesca.png`, tablón con cuerdas y boya, sprite FIJO exportado al
    ancho de dibujo; respira en espera y lleva la MONEDA del juego + "50",
    nada de "$") cobra el intento (`FishData.FISHING_COST`) → aparece la
    **SOMBRA con FORMA DE PEZ** (`_draw_fish`: cuerpo, cola y aletas vistos
    desde arriba, orientada a su rumbo; más GRANDE cuanto mejor el botín) que
    **NADA de rumbo en rumbo** (`FISH_SPEED` 62 px/s con culebreo: hay que
    apuntar adelantándose) → se TOCA EL AGUA para lanzar el sedal (parábola);
    si no interesa, **la ÚNICA forma de recuperarlo es MANTENER la pantalla**
    (`RETRIEVE_SPEED`) hasta recogerlo y volver a lanzar (gratis dentro del
    intento). El **campo de visión** (`VISION_R` 120 px) se mira CADA
    fotograma — el pez puede nadar él solo hasta el anzuelo — y al entrar la
    sombra se acerca y se planta con la **BOCA a FEINT_RETREAT del anzuelo**
    (`_feint_rest`: el centro del cuerpo queda detrás, a ~1.35 radios).
    **FINTA de 2 a 5 veces**: en cada intento EMBISTE hacia delante —la boca
    toca el anzuelo justo cuando el flotador se hunde 7 px— y vuelve a
    retroceder. La picada REAL lo deja adelantado con la boca en el anzuelo,
    hunde el flotador con "¡Ha picado!" y ondas, y da `BITE_WINDOW` (**1 s**)
    para tocar. **Tocar durante una finta ESPANTA al pez y pierde el
    intento** — pero SOLO si ya ha intentado picar al menos una vez
    (`feints_done`): un toque nada más lanzar o durante el acercamiento se
    ignora, la medida de seguridad contra el toque accidental. Dejar pasar
    la picada también lo pierde.
  · **PELEA con CAÑA-HUD animada y tira y afloja**: a la derecha va
    `pesca_cana_hud.png` (caña VERTICAL y RECTA a propósito) con **LAS DOS
    BARRAS DENTRO, hijas suyas** — así se inclinan y tiemblan con ella y el
    conjunto se lee como UN instrumento: el **SEDAL** embutido en el mástil
    (20 px, más gordo que los 14 que tuvo, pero sin comerse la madera de los
    lados; su canal no llega a los extremos, o la caña parecía dos barras
    sueltas con un carrete debajo) y la **PRESA** en paralelo a su
    izquierda. El sedal se TIÑE con su nivel (`_tension_color`): **verde
    tranquilo → naranja a media tensión → rojo a punto de romperse**. La
    **MANIVELA** (`pesca_manivela.png`) gira sobre el carrete: despacio al
    recoger y AL REVÉS y **MUCHO más rápido** cuando el pez se lleva sedal
    (medido: 10 veces más deprisa en la fase de velocidad; `_animate_rod`,
    `CRANK_*`). `ROD_RECT` calca la proporción de la textura y
    `ROD_TRACK`/`ROD_REEL` están MEDIDOS por barrido de alfa: si se regenera
    la caña, volver a medir. El pez pelea **DEBAJO de la boya**, y **la
    DISTANCIA al barco la manda su ENERGÍA** — llena lo tiene lejos
    (`LINE_T_FAR`), vacía lo trae pegado al casco (`LINE_T_NEAR`), con
    `LINE_FOLLOW` de retardo para que el viaje se vea. El sedal sube al
    MANTENER y a tope se rompe; la presa empieza al **60–90%** según el tier
    (+ un pico por tamaño) — mantener la drena, soltar la deja recuperarse, y
    **si llega al 100% ESCAPA**. Su FUERZA (`_fish_strength`) escala con el
    TAMAÑO del ejemplar y su DISTANCIA al barco, y multiplica lo que
    recupera.
    **EL AGUJERO QUE ROMPÍA LA PESCA (arreglado, no reabrirlo)**: dando
    toquecitos se recogía al pez sin que el sedal llegara a tensarse, o sea
    que machacar la pantalla era la estrategia óptima. Lo cierran TRES
    reglas juntas: 1) cada pulsación da un **PICO de tensión**
    (`TAP_TENSION_KICK`), así que el machaqueo revienta el sedal; 2) la
    presa **no cede hasta `HOLD_MIN`** (0.35 s) de dedo apoyado, o sea que
    el toque suelto no recoge nada; 3) suelto, el pez recupera **cada vez
    más deprisa** (`REGAIN_RAMP` por `idle_time`, hasta ×2.6), y mirar sale
    caro. Medido: 40 toques rápidos suben la barra de 0.60 a 1.00 (el pez
    ESCAPA), mientras que mantener de verdad la baja.
    **Y OJO CON `REGAIN_*`: LO QUE RECUPERA LA PRESA EN EL DESCANSO DECIDE SI
    LA CAPTURA ES POSIBLE.** Hay que soltar para que el sedal no reviente, así
    que si el pez recupera en ese descanso más de lo que se le drena
    recogiendo, la barra sube ciclo a ciclo y NO HAY FORMA de pescarlo por
    bien que se juegue. Pasó con 0.10+0.03/tier: un épico grande y TODOS los
    legendarios eran imposibles. Al tocar estos números hay que **SIMULAR EL
    CICLO ENTERO** con un jugador óptimo (mantener hasta 0.85 de tensión,
    soltar hasta 0.10), que a ojo no se ve. Con los vigentes la pelea dura de
    ~4 s (común pequeño) a ~17 s (legendario grande), medido con el bucle
    real del juego.
    En las
    **FASES DE VELOCIDAD** (aleatorias) la presa sube con fuerza de verdad y
    **mucho más cuanto mejor es el premio** (`SPEED_REGAIN`
    **0.34+0.13/tier = 0.34 a 0.73/s**). Para que sea amenaza y no muerte
    súbita, el tirón **se APLAZA si la barra pasa de `SPEED_MAX_ENERGY`**
    (0.72): así siempre quedan de 0.82 s (común) a 0.38 s (legendario) de
    reacción, y encima narra mejor — el pez tira con todo cuando se ve
    perdiendo
    y **cada toque NO la baja: le FRENA la subida** durante `TAP_RELIEF`
    (0.3 s) — solo pulsando más rápido que esa ventana baja, y muy poco
    (`SPEED_DRAIN_TAPPING` 0.03). Cada toque **también TENSA el sedal
    `TAP_TENSION`**: pulsar a lo loco con la barra roja alta lo rompe igual
    (el sedal solo se relaja despacio, `SPEED_TENSION_DECAY`).
    **Y AGUANTAR EL TIRÓN A PULSO NO VALE**: si el dedo se queda apoyado más
    de `HOLD_MIN` (para no confundirlo con un toque), el freno de los toques
    se CANCELA —la presa sube a plena fuerza— y encima el sedal se tensa
    como si se recogiera. Medido: manteniendo 2 s en un tirón la barra llega
    al 100% (escapa) con el sedal subiendo, mientras que pulsando rápido esos
    mismos 2 s la barra BAJA. Aquí se pulsa, no se mantiene. En plena
    faena el "Atrás" se esconde
    (los 50 ya están apostados). El **ÁLBUM** es un botón de icono propio
    (`ic_album.png`, el libro del pez dorado) ARRIBA A LA DERECHA, y la
    pantalla va SIN lazo de título (el tablón del botón ya dice dónde
    estamos).
  · **EL TIRÓN SE VE, NO SOLO SE LEE** (`_set_rush`, señal `rush_changed`):
    en cuanto la presa tira con fuerza se enciende un velo de **LÍNEAS DE
    ACCIÓN** de cómic (`shaders/action_lines.gdshader`, port del
    "Actionlines Comic - Anime" de EriNixie en godotshaders, CC0), la CAÑA
    se va de lado a lado (`RUSH_ROD_SWAY`), la cámara se ACERCA un pelín y
    TIEMBLA. Al aflojar vuelve todo solo. Cuatro cosas medidas:
    · Las líneas **convergen en el pez** (uniform `center`, refrescado por
      fotograma con la boya en UV), no en el centro de la pantalla.
    · **La normalización de la UV es la del original** (-1..1 en los dos
      ejes, sin corregir aspecto): los parámetros vienen afinados a mano
      en el editor contra ESA escala, y corrigiendo el aspecto un `radius`
      de 2.0 dejaba la pantalla sin una sola línea. Los vigentes
      (radius 2.0, line_length 2.18, softness 0.8) dan rayos LARGOS Y
      DIFUSOS que solo asoman por los bordes: suave, no un latigazo.
    · El ruido baja de **6 octavas a 4**: esto se dibuja a pantalla completa
      y corre justo cuando hay que pulsar rápido.
    · **EL ZOOM ES SOLO DE CÁMARA** (`RUSH_ZOOM_IN`, en `main_menu`).
      Estuvo escalando además `zone` con el pivote en el pez y NO VALE: el
      SEDAL se dibuja dentro de `zone`, así que al escalarlo su nacimiento
      se despegaba del barco y la línea quedaba flotando. El temblor lo
      hace `_on_pesca_rush`, que **guarda el `cam.size` de antes** en vez
      de suponerlo (el menú lo cambia en sus transiciones) y lo devuelve
      clavado al terminar. **Y la punta de la caña se proyecta AL FINAL**
      del `_process`, con la cámara ya colocada: calculándola antes, el
      sedal nacía donde estaba el barco el fotograma pasado.
  · **EL TUTORIAL SE PUEDE REPETIR, y no lo cuenta Cai** (botón
    `boton_ayuda.png` bajo el álbum → `_tutorial_guiado`): la clase de Cai
    (`_clase_de_pesca`) es la PRIMERA vez y va con diálogos; esta es la
    chuleta de siempre y aquí NO habla nadie. Un cartel de pergamino dice
    lo que toca AHORA y un foco señala dónde mirar, con el juego
    CORRIENDO — el patrón del rótulo "Toca el agua para lanzar el sedal",
    paso a paso. Lo que costó medir con un jugador simulado:
    · **Cada paso se deja leer `TUTOR_MIN_LEER` (1,1 s) como mínimo**:
      quien ya sabe pescar cumple la condición en el mismo fotograma en
      que sale el cartel, y dos pasos enteros se perdían sin verse.
    · **El TIRÓN se provoca a mano** (`speed_next = 0`) y la presa NO se
      puede cobrar hasta haberlo explicado (`tutor_falta_tiron` capa la
      energía por abajo): jugando bien, la barra se vaciaba en cuatro
      segundos y el tutorial terminaba sin dar la única lección que de
      verdad se falla.
    · **NO APUNTA NADA**: ni álbum, ni récords, ni doblones, ni
      coleccionables, y nunca sale cofre (solo peces). La marca de
      práctica viaja **con el INTENTO** (`roll["practica"]`), no con la
      bandera del guion: el tutorial puede terminar de hablar antes de que
      el pez caiga, y entonces la captura se cobraba como buena — un
      intento gratis con premio de verdad (medido: +58 doblones).
    · Los elementos DIBUJADOS (la sombra, el flotador) se señalan con un
      **anillo pulsante que los sigue** (`_anillo_en`), no con el foco de
      velo: oscurecer `zone` taparía justo lo que hay que mirar.
    · **EL FOCO MUEVE EL NODO AL FINAL DEL ÁRBOL** (`_foco_pesca`): el
      z_index cambia el DIBUJADO, no quién recibe el toque —el picking va
      por orden de árbol—, así que el velo se tragaba la pulsación y el
      botón enfocado NO RESPONDÍA. Es la misma trampa del velo del menú.
    El intento va amañado con la misma bandera que la clase (`clase`): pez
    fácil, gratis y sin poder perderlo.
  · **EL PREMIO SE SORTEA ANTES DE VER LA SOMBRA** (`GameState.fishing_roll`,
    PURO: no toca estado) y de su `tier` 0..3 sale la DIFICULTAD: el sedal se
    tensa más deprisa (+28%/tier), la presa recupera más y las fases de
    velocidad son más largas y frecuentes (tier 3: 2-3 fases). Solo al LOGRAR
    la captura se entrega (`fishing_apply`, que es quien muta y guarda).
  · **Los 100 peces** (`FishData.FISH`, orden = vitrina del álbum): 33
    comunes, 36 raros, 23 épicos y 8 legendarios, pesos POR PEZ 24/10/4/1,
    y **todos con `desc`**: la ficha del álbum cuenta qué es el bicho (dato
    real del animal), y es lo que llena la tarjeta. Salvo los guiños y los
    de agua dulce heredados, **el catálogo es de mar y océano**.
    El contador del álbum va por `FishData.caught_count()`, NO por
    `fish_album.size()`: un id renombrado (marlin → pez_lanza) dejaría una
    entrada huérfana en el guardado y el contador se pasaría del total.
    **LA BASURA** (`junk`: botella rota, rueda y bota) paga `JUNK_COINS`
    (**1**) pésquese las veces que se pesque. Ojo: la **botella rota** es
    BASURA y no tiene nada que ver con el coleccionable "Botella vacía", que
    sale de los cofres — su ficha lo aclara ("sin mensaje dentro").
    La botella y la rueda **no tienen talla**
    (`no_size`: su ficha no habla de centímetros ni de récord) y la bota se
    mide en **número de calzado** (`size_unit: "talla"`, 34–48), no en cm —
    de ahí `FishData.size_text()`, que devuelve ya la unidad puesta.
    Cada captura trae un **TAMAÑO** (size 0..1, sorteado ANTES de la sombra)
    que decide sus doblones dentro de la horquilla de su rareza — **común
    45–65 · raro 60–80 · épico 85–120 · legendario 130–190** — y el largo
    en cm de la ficha. Con el intento a **100 doblones**, **solo las piezas
    gordas lo cubren**: pescar por dinero compensa con épicos y legendarios,
    y el resto se pesca por el álbum y por la despensa. (Toda recompensa
    lleva **+30** sobre la tabla anterior, subida junto al coste; la BASURA
    es la excepción y sigue en 1 doblón) (`len` por rareza, con overrides por pez: caballitos
    diminutos, tiburón ballena de 5–10 m...). TODA captura apunta el álbum y
    el RÉCORD de talla (`GameState.fish_best`, la ficha enseña el mayor);
    un pez con `ingredient` da sus usos de despensa EN CADA captura (5, y
    **10 el salmón real** — la pesca es LA fuente de despensa: los cofres ya
    no dan usos), y TODOS pagan las monedas por tamaño **desde la 2ª captura
    de la especie**. El **PEZ LAPA** no pica nunca (`no_catch`): con
    `LAPA_CHANCE` (7%) viene PEGADO a la captura y su valor se cobra APARTE
    y SIEMPRE. **Es una SORPRESA**: no se menciona en el cartel del pez —
    sale en el suyo propio ("¡Venía acompañado!") al pulsar Continuar, que
    es de lo que va la mecánica. Y es el pez más pequeño del catálogo
    (3–9 cm), como corresponde a algo que viaja pegado a otro. Entre los nuevos hay guiños con `desc` en la ficha (barbo
    oloroso, Bata-Bata, Froggy) y basura clásica (lata, bota). Álbum con
    silueta + "???" y ficha (rareza, premio, récord en cm, veces, sabor).
  · **El COFRE** (`CHEST_CHANCE` **30%**, `FishData.CHEST_TABLE`): monedas
    (peso 50; **100–150 SIEMPRE** — franja 100–125 al 70% y 126–150 al 30%,
    así que un cofre de oro cubre el intento y compite con un pez épico),
    coleccionable pescable (25; repetido = 80 doblones, ver Pescables),
    fragmento de trifuerza (15; es SU fuente) y receta bloqueada al azar (10;
    ni ocultas ni dragon_roll, con el regalo de estreno `PORT_GIFT`; sin
    pendientes paga 230).
    **EL COFRE NO SE ABRE SOLO**: sale CERRADO, meciéndose, con un botón
    "¡Abrir!", y `GameState.fishing_apply` NO se llama hasta que termina la
    animación de apertura — así el orden es cofre → abrirlo → **y ENTONCES**
    la ventana del coleccionable (antes salía el coleccionable primero y el
    cofre después). El mismo botón hace luego de "Continuar" (la bandera va
    en un diccionario: las lambdas de GDScript capturan por VALOR). El botín
    se pinta SIN fundido a propósito: la ventana del coleccionable pausa el
    árbol y un tween se quedaría congelado a medias. Texturas del cofre del
    bonus diario.
  · Skins del chef y mapas del tesoro (misiones secundarias) están en el
    DISEÑO del cofre pero FUERA del sorteo: sus sistemas no existen todavía.
  · **La sombra, el sedal y el flotador se DIBUJAN POR CÓDIGO** (señal `draw`
    del panel táctil): cero assets. `WATER` es el rectángulo útil de agua.
    **LA PUNTA DE LA CAÑA VIAJA CON EL BARCO**: `ROD_TIP` (505,395) es la
    medida de reposo en píxeles de lienzo, pero el barco es 3D y cabecea, así
    que con "menos animaciones" se queda plano, la borda se dibuja unos píxeles
    más arriba y la línea blanca nacía FUERA del casco. `main_menu` reescribe
    `fishing_game.rod_tip` por fotograma proyectando `ROD_LOCAL`
    —(0, -0.537, 1.744) en coordenadas DEL BARCO, despejado contra `ROD_TIP`
    con la base de proyección de la cámara—, así que vale para cualquier pose y
    cualquier ajuste de gráficos. Si se recoloca el barco del menú, volver a
    despejarlo.
  · **El rótulo del coste lo pone `_refresh_cast_label` al montar la pantalla**,
    no el precio a pelo: con tiradas de regalo de Cai pendientes, la PRIMERA de
    la visita decía "100" y la siguiente ya "GRATIS x2", como si el juego
    hubiera cobrado un intento que en realidad salía gratis. Entrada solo por `InputEventScreenTouch` (el ratón llega como toque
    sintetizado), con press = picar/lanzar/mantener/tap y release = soltar.
  · **Los botones "+" de las cajas de recursos se APAGAN con un intento en
    juego** (`fishing_game.busy_changed` → `main_menu._set_plus_enabled`): el
    panel de compra no para el reloj de la pesca, así que abrirlo con el pez
    enganchado costaba los doblones apostados. La condición es la misma con
    la que se esconde el "Atrás" (todo lo que no sea READY ni REVEAL), porque
    los doblones se pagan al LANZAR, no al morder.
  · **LOGROS de pesca**: ocho a mano MÁS UNO POR PEZ (ver el bloque de logros),
    en su **apartado propio** ("pesca", la tercera
    pestaña de la pantalla de logros) — capturas (`fish_caught`), álbum
    (`derived:pesca_album`, que cuenta por `FishData.caught_count` y cuya
    meta de ORO es el catálogo entero: **al añadir un pez hay que subirla**),
    legendarios (`fish_legendary`), cofres (`chests_fished`), peces con lapa
    (`fish_lapa`), basura (`fish_junk`), **sedal roto** (`fish_line_broken`,
    sumado en `fishing_game._tick_fight` justo donde `tension >= 1.0`) y
    **pez escapado** (`fish_escaped`, mismo sitio con `energy >= 1.0`) — los
    dos son sucesos de la PELEA, no del robo de cebo ni del susto por finta,
    que son otras ramas de `_escaped()`. Las estadísticas de captura se suben
    desde `GameState.fishing_apply`, que es donde ocurre el suceso. El gasto
    de los intentos suma a `money_spent` (el general de "todo lo gastado" que
    siembra `money_total`), pero **NO** a `shop_spent` — ver el aviso de abajo.
  · Iconos `assets/ui/fish_*.png` + `ic_pesca.png` + `pesca_cana.png`: Ludo
    (item-icon, Western Cartoon, como los coleccionables) → `_gen/ui2/fish/`
    (y `menu/ic_pesca`) → `build_fishing()` de `tools/ui2_prep.py` (con
    `drop_specks`; sin arte, `FishData.get_icon` cae a la moneda y nada
    crashea).
  · **El cuarto pergamino obligó a tocar el tablón del menú**:
    `MENU_PANEL_INNER` pasó de 0.66 a **0.745** de alto (426 px de botones no
    cabían en 380) y el **ancla pintada del pie se retiró** — existía porque
    esa franja quedaba vacía, y ahora la ocupa la Pesca.
- **CÓMO TERMINA UN NIVEL, POR TIPO** (`CampaignData.is_timed` /
  `unlimited_clients` / `time_limit_for`): los **ABORDAJES** son los ÚNICOS con
  reloj —`SHIP_TIME`, 2:30 para todos— y **no tienen cupo de clientes**: sigue
  entrando gente mientras quede tiempo, así que ahí `client_mix` es solo la
  PRIMERA tanda (con su `late_type`) y, agotada, las llegadas se sortean con
  esas mismas proporciones (`client_weights` se rellena con la mezcla). Las
  **ISLAS y los PUERTOS** no llevan reloj: acaban cuando se va el último cliente
  de `client_mix`, o al llegar al oro objetivo.
  Consecuencias que hay que respetar: en los niveles sin reloj el HUD **oculta
  el reloj** y mete un relleno del ancho del contador de clientes en su hueco
  (`level3d._apply_hud_layout`), para que el oro quede centrado DE VERDAD en la
  pantalla; el contador de clientes de un abordaje enseña solo cuántos han
  pasado (sin "/N", que no existe); no hay prima "por tiempo sobrante" sin reloj
  ni prima "por clientes sobrantes" con clientela infinita; y el potenciador
  "Horas extra" se cae del sorteo donde no hay reloj.
  **`elapsed` sigue contando SIEMPRE**, haya reloj o no: es lo que dispara las
  llegadas. Lo que solo pasa con reloj es que se acabe el turno al agotarse.
- **EL ARCADE SIN FIN** (rediseño del 17-8-2026; antes "modo prueba" que no
  tocaba el progreso — esa regla está MUERTA en todas sus copias). Vive en
  `level3d` bajo la bandera `arcade` (`GameState.is_arcade()`, modo "test") y
  se abre al vencer al Kappa (`ARCADE_PORT` = nivel_15; cuando entren los
  escenarios 16-20 del primer mar, moverlo al 20):
  · **Es una jornada de verdad**: cobra 1 saco de arroz al zarpar, la primera
    tanda de despensa, y bonificadores con sus usos. El selector filtra por
    recetas desbloqueadas CON ingredientes (como aventura) y enseña la fila de
    bonificadores. Salir en preparación devuelve todo, como en aventura.
  · **Oleadas de `WAVE_TIME` (45 s)** con llegadas CONTINUAS
    (`_tick_arcade`): un cliente cada `arcade_spawn_gap` (11 s) × 0.98^oleada
    — el pellizco. La paciencia baja un 1,5% por oleada (`patience_mult`). El
    horario clásico de llegadas NO se rellena en arcade (duplicaría clientela).
  · **El tono sube cada 5 oleadas** (`_arcade_weights`): solo grumetes hasta
    la 5, piratas desde la 6, capitanes desde la 11.
  · **Cada oleada cuesta 1 uso de cada ingrediente de la carta**
    (`GameState.consume_wave_ingredients`). Lo agotado TIRA sus recetas de la
    carta (`_drop_recipes_for` → `prep_board.allowed_recipes`, con el
    centinela `["__ninguna__"]` si la carta queda vacía — una lista vacía
    significa "todas"). Sin carta no hay variedad y llegan los vacíos: la
    partida se desmorona, no se apaga. El arroz NO va por oleada: un saco por
    partida.
  · **Se pierde a los `VACIOS_MAX` (3) clientes que se van sin probar bocado**
    (el contador es `empty_leavers`, vigilado en `_on_client_finished`). No
    hay reloj ni cierre por oro: la barra del marcador es un HITO renovable
    (`ARCADE_META_STEP` 150) cuya estrella brilla en cada cruce, y
    `_check_goal_reached` sale en seco en arcade.
  · **Cada 10 oleadas, un ESTORBO permanente** sorteado sin repetir
    (`ESTORBOS`), ANUNCIADO en la oleada anterior por la tablilla de fase
    (`_cartel_oleada`): cinta más rápida (`belt_base` — ojo, el potenciador
    de cinta ahora vuelve a `belt_base`, no a 1.0), bocados +20%, fogón que
    apaga una receta a ratos (fuerza cooldowns), cubo al doble (`waste_frac`),
    cajas −1, clientela que llega al 80% de paciencia, drenaje +10%.
  · **Cada 3 oleadas, una CARTA DE MEJORA de partida** (tres opciones,
    reutilizando el cartel de potenciadores: `_upgrade_pool` /
    `_make_upgrade_card` / `_apply_upgrade`). Familias: fichaje (una receta
    del recetario QUE SE PUEDA PAGAR — sin ingrediente no se ofrece — y desde
    su oleada su despensa se cobra igual), maestría +1 de una receta que ya la
    tenga (`prep_board.mastery_bonus`), −30% cooldown de 1★
    (`cooldown_l1_mult`), caja/pila extra, cinta lenta, vuelta extra de plato,
    +15% paciencia, postres al doble PERMANENTE (`dessert_boost_perm`, que no
    consume el potenciador de un uso), el ayudante (si no está) o su descanso
    a la mitad, y el vacío perdonado (repetible, solo con vacíos). **REGLA DEL
    MODO: ninguna mejora toca el PRECIO de los platos** — producción, colchón
    y variedad sí; precio no, o el modo se vuelve fuente de dinero en vez de
    reto.
  · **HUD propio** (`_setup_arcade_hud`, bajo la fila superior): "Oleada N",
    "Despensa: N" (el MÍNIMO de usos entre los ingredientes de la carta —
    cifra sobre la que el jugador puede actuar) y "Vacíos N/3" en rojo al
    borde. El botón de Salir pasa a ser **"Terminar"**: en marcha NO pierde
    nada — cierra el turno por el camino normal y cobra.
  · **Lo que paga** (`_finalize_results`, rama is_arcade): TODO el oro
    generado al monedero + `GameState.arcade_xp(oleadas)` = Σ 15·oleada de
    las SUPERADAS (la que estaba a medias no cuenta). Récord persistente
    `arcade_best` + stat `arcade_wave` (logro "Contra la marea"). El cartel
    de resultados enseña "Oleada N · ¡Récord!" en vez de estrellas.
  · MEDIDO con sonda (12 oleadas simuladas): el cartel de mejoras pausa el
    árbol, los fichajes reconstruyen una carta arrasada por la despensa, y el
    cierre pagó 1.170 XP exactos (15·78) subiendo al cocinero del 1 al 9.
- `scripts/campaign_data.gd` — los **10 niveles-escuela** de la campaña
  (`PORTS`, ordenados; la cabecera del archivo lista qué lección trae cada
  uno). Campos: `client_mix` (recuento EXACTO {E,A,G}; el nivel construye una
  cola barajada y `total_clients` sale de la suma), **`arrival_span`** (la
  VENTANA sobre la que se reparten las llegadas; **no es la duración del
  nivel**, solo el RITMO al que entra la clientela, y por eso lo llevan
  también los niveles sin reloj: de ahí sale `arrival_step`, que en un
  abordaje se repite hasta que se acaba el tiempo), `patience_mult`,
  `arrival_scale` (<1 = llegan más seguidos), `goal_stars` (2 en todos),
  `star_money` ([$1★,$2★,$3★]) y `reward_recipes` / `reward_recipes_3`.
  **Compuertas de la escuela**: `free_ingredients` (niveles 1-2: no gastan ni
  despensa ni arroz, tampoco al repetir — `consume_ingredients_for_level` los
  salta), `no_powerups` (1-4: sin bote de propinas — el HUD esconde el bote,
  `_add_tip` no cobra y los clientes salen con `tips_enabled` false, así que
  ni tiran propina), `no_storage` (solo el 1: sin cajas,
  `prep_board.hide_storage`) y `boss` (el Kappa del 10).
  **Estos 10 niveles NO cubren la carta entera a propósito** (el jugador
  aprende ~un tercio de las recetas; el resto y el barco/bonificadores quedan
  para los niveles 11+, con jefes cada 10 como este). El DRAGON ROLL sigue
  siendo del día 7 del bonus diario. También
  `INITIAL_RECIPES` (solo el maki) e `INITIAL_INGREDIENTS` de partida nueva.
- `scripts/game_state.gd` — **autoload** `GameState`: modo ("adventure"/"test"),
  nivel en curso, recetas elegidas + progreso PERSISTENTE en
  `user://savegame.json`: dinero, recetas desbloqueadas, estrellas por nivel e
  **inventario de ingredientes por usos**. 1 uso = llevar ese ingrediente a UN
  nivel (se descuenta 1 por ingrediente distinto al EMPEZAR la partida, no por
  plato). El arroz es infinito. `consume_ingredients_for_level()`,
  `complete_port()` (recompensas solo la 1ª vez que se alcanza `goal_stars`).
  **Además es el dueño del FUNDIDO entre pantallas**: `fade_out/fade_in/
  fade_to_scene(ruta, salida, entrada)`. El velo (CanvasLayer 128) cuelga del
  AUTOLOAD, así que sobrevive al cambio de escena; los velos que se montaban en
  la escena morían con ella y dejaban ver la **pantalla gris** del motor
  mientras cargaba la siguiente. **Todo cambio de escena del juego va por
  `fade_to_scene`**, nunca por `change_scene_to_file` a pelo. La escena que
  entra no tiene que hacer nada: el telón se abre solo tres frames después
  (algunas, como main_menu, colocan su interfaz un frame más tarde).
  **Guarda también las ESTADÍSTICAS de toda la vida del jugador** (`stats`, de
  donde salen los logros: `bump_stat` suma, `max_stat` guarda récords,
  `achievement_value` resuelve sumas de claves y las "derived:*") y los
  **AJUSTES** (`settings`: bloque de gráficos, calidad, fps, sombras y
  animaciones) y las HORAS JUGADAS (`play_seconds`, que las suma el `_process`
  DEL PROPIO AUTOLOAD: cuenta todo el rato con el juego abierto —menús, mapa,
  tienda, pesca y niveles— y también con el árbol en pausa, porque GameState va
  en `PROCESS_MODE_ALWAYS`. Estuvo sumando solo `level3d` dentro de una partida
  y el contador de Progreso salía muy por debajo de lo que el jugador recordaba
  haber echado; `level3d.play_time` sigue siendo el reloj de ESA partida, que es
  otra cosa). El nombre y el género van
  aparte, en `player_name` / `player_gender`; los guardados de la primera
  versión de Opciones los traían dentro de `settings` y se rescatan al cargar.
  `apply_graphics()` aplica lo global (escala de render 3D y `Engine.max_fps`);
  sombras y animaciones las consulta cada escena al construirse
  (`shadows_on()` / `animations_on()`). `reset_progress()` borra el progreso
  pero **respeta los ajustes**: no son progreso.
- `scripts/guide_data.gd` — texto de la **GUÍA DEL JUEGO** (`GuideData`),
  partido en secciones `{title, icon, body}`. Solo datos: lo pinta la pestaña
  **Guía** de Opciones, con las secciones PLEGABLES (se abre una y se cierra la
  anterior; la lista entera de un tirón eran varias pantallas de scroll y no se
  encontraba nada). Las palabras clave van entre `**asteriscos**` y las pasa
  `DialogueBox.format_keywords`, el mismo marcador que los diálogos.
  **Las cifras de la guía son las de verdad**: si se toca una constante del
  juego hay que tocarla aquí, o la guía miente.
- `scripts/achievement_data.gd` — catálogo de LOGROS (`AchievementData`), solo
  datos: id, apartado, texto, `stat` y tres metas (bronce/plata/oro). El
  progreso NO se guarda por logro: se deduce de `GameState.stats`, así que un
  logro nuevo funciona hacia atrás si su estadística ya se contaba. Los logros
  "prepara N raciones de X" se generan solos de `RecipeData.RECIPES` (uno por
  receta no oculta; las ocultas —barco, combinados— tienen el suyo a mano), y
  los "pesca N ejemplares de X" de `FishData.FISH` (uno por pez; la BASURA se
  queda fuera, que ya tiene el suyo). Sus metas salen de `FISH_TIERS` POR
  RAREZA y van al revés que la dificultad: un común pide 10/30/80 y un
  legendario 1/3/8. Cuentan por `derived:fish:<id>`, que lee el ÁLBUM, así que
  funcionan hacia atrás con lo ya capturado.
- **CADA LOGRO CON SU ICONO** (`AchievementData.icon_for`): el sprite del plato
  si es de receta, la ficha del álbum si es de pez, y si no el suyo propio de
  `ICONS` — todos distintos, porque en una lista de 160 fichas la misma moneda
  repetida no distinguía ninguna. Ese icono sale también en el TOAST del logro.
  Al añadir un logro escrito a mano, su entrada en `ICONS`.
  `GROUP_TABS` son los rótulos de las pestañas. Son **TRES apartados**
  (Cocina, Travesía y Pesca): los cinco de antes dejaban ~84 px de texto por
  tablón en 720 px y varios tenían media docena de fichas, así que se
  fundieron —"Barra" y "Platos" son cocina, "Oro" es parte del viaje— y la
  PESCA se quedó con apartado propio, que tiene sus estadísticas y su álbum
  aparte. Con tres tablones los rótulos caben enteros; a partir de ahí, no.
  **Un logro de receta SIN DESBLOQUEAR sale OCULTO** en la pantalla
  (`_build_hidden_card`): silueta del plato EN NEGRO, "???" y sin barra, para
  no desvelar la carta del juego. **Y un logro de PEZ sin ni una captura,
  igual** (mismo `_build_hidden_card`, mirando `GameState.fish_album`): no se
  desvela ni el pez ni su nombre; la única pista de la tarjeta es la RAREZA
  ("Pesca un ejemplar de rareza épica..."). El logro "coleccion" (Camarote de tesoros)
  bebe de `derived:coleccion` y **su meta de ORO tiene que ser el tamaño del
  catálogo de coleccionables**: al añadir uno, subirla con él.
- **LOGROS: aviso, globo y reclamo** (montado con los coleccionables):
  · **`money_spent` NO ES "gastado en la tienda"**: es el total de TODO lo
    gastado (tienda, recarga del surtido, intentos de pesca, usos de
    bonificadores), y se usa para sembrar `money_total` en guardados viejos.
    El logro "Cliente del tendero" mira `shop_spent`, un contador APARTE que
    solo suman `shop_screen` (comprar ingredientes) y `GameState.reroll_shop`
    (recargar el surtido) — las DOS acciones que de verdad son "comprarle a
    Saverio". Pescar bumpeaba el mismo `money_spent` que miraba el logro y
    el "cliente del tendero" saltaba pescando: **cualquier gasto nuevo que no
    sea la tienda de Saverio va a `money_spent` y NUNCA a `shop_spent`.**
  · **EL TUTORIAL NO CUENTA**: `bump_stat`/`max_stat` (y `mark_day_played`)
    salen sin apuntar nada con `is_tutorial()` — la clase de David no suma
    platos, clientes ni días a las estadísticas ni a los logros. Es el ÚNICO
    embudo por el que entran las estadísticas, así que el corte ahí cubre
    level3d, prep_board, extras y todo lo demás de golpe.
  · La DETECCIÓN vive en `GameState._run_achievement_check`, que programa
    `queue_achievement_check()` en DIFERIDO tras cada `bump_stat`/`max_stat`
    (una ráfaga de platos en el mismo fotograma cuesta UNA pasada). Compara lo
    conseguido con `seen_medals` y saca un TOAST por medalla nueva. NO guarda a
    disco a propósito (`seen_medals` viaja con el siguiente save natural).
  · El TOAST es la banda de `notice_layer.gd`: baja de arriba, se va sola y es
    `MOUSE_FILTER_IGNORE` en todo — notificación, no cartel.
  · **Reclamo**: `claimed_medals` (id → 0..3) y `MEDAL_REWARDS` 25/50/100 por
    bronce/plata/oro. Si de un logro hay bronce Y plata sin reclamar, caen las
    dos de golpe. El botón "Reclamar todo" de `achievements_screen` (en el
    hueco que dejó la cinta del título, que se quitó) abre el cartel del COFRE
    (las texturas del diario: cerrado → meneo → abierto) con el total y el
    desglose por metales; con 0 pendientes va apagado.
  · **TAMBIÉN SE COBRA LOGRO A LOGRO**: cada tarjeta es un BOTÓN y tocarla
    cobra lo suyo (`GameState.claim_achievement`), con una lluvia de monedas
    que sale de la propia tarjeta y el "+N" subiendo por encima. Sin nada
    pendiente la tarjeta queda inerte (`disabled`), para que pulsar no dé un
    falso "algo ha pasado". El cobro EN BLOQUE lanza la misma lluvia, más
    grande y **sin la cifra**: el cartel del cofre ya canta el total y
    superpuesta le caía encima del rótulo. **Y SALE CUANDO EL COFRE SE ABRE**,
    no al pulsar: va dentro del `tween_callback` que cambia la textura a
    "abierto" y arranca en la BOCA del cofre. Lanzada al pulsar, las monedas
    volaban por delante de un cofre todavía cerrado.
  · **EL GLOBO ROJO va en TRES sitios** y lo dibuja `PrepBoard.attach_badge`
    (vive con el resto del set): sobre `ic_logros` en el menú
    (`unclaimed_medals`), sobre cada PESTAÑA (`unclaimed_in_group`) y sobre
    cada TARJETA con medallas sin cobrar (`unclaimed_for`).
  · La pantalla abre por **Cocina**. `current_group` apuntó un tiempo a
    "clientela", un apartado que ya no existe, y la lista salía VACÍA al
    entrar.
  · **Guardados viejos**: al cargar sin `seen_medals` se siembra con lo YA
    conseguido (nada de un aluvión de toasts al arrancar), pero `claimed`
    queda vacío → todo lo ganado hasta hoy se puede reclamar del tirón.
    Asumido: es el mismo criterio retroactivo de los logros.
- `scripts/collectible_data.gd` — catálogo de COLECCIONABLES (120, solo datos:
  id, nombre, `desc` = cómo se consigue o el guiño que lo explica, que SOLO se
  enseña ya conseguido).
  **El ORDEN de `ITEMS` es el de la vitrina y agrupa por REFERENCIA**: tesoros
  pirata genéricos → la cocina del barco y sus trofeos (maneki-neko, daruma,
  sake, escama de sirena, koinobori, omamori, los tres pares de palillos y los
  cinco trofeos) → Piratas del Caribe (perla negra, moneda azteca, corazón en
  un cofrecito) → Monkey Island (grog, peluche del mono de tres cabezas, lista
  de insultos, pollo de goma) → Day of the Tentacle (gafas de Bernard,
  tentáculo púrpura) → One Piece (la banda del sombrero de paja EN ORDEN DE
  TRIPULACIÓN: sombrero/Luffy, pendientes/Zoro, naranja/Nami,
  tirachinas/Usopp, sartén/Sanji, cuerno de reno/Chopper, sombrero
  vaquero/Robin, botella de cola/Franky, violín de esqueleto/Brook, y el
  caracol teléfono cerrando) → La Isla del Tesoro (marca negra) → Peter Pan
  (reloj del cocodrilo) → Popeye (lata de espinacas) → Mitología griega
  (óbolo de Caronte) → Capitán Harlock (calavera alada) → Sonic (esmeralda
  del caos) → Moby Dick (arpón) →
  20.000 leguas (casco de escafandra) → El Holandés Errante (farol fantasma)
  → Buscando a Nemo (máscara de buceo) → Indiana Jones (ídolo dorado) →
  Overcooked (extintor) → Ratatouille (gorro diminuto) → Naruto (cuenco de
  ramen) → La Odisea (tapones de
  cera) → Robinson Crusoe (molde de una huella) → Tiburón (bidón amarillo) →
  Sea of Thieves (banana) → Tintín (maqueta del
  Unicornio) → Los Goonies (ojo de cobre) → La Sirenita (tenedor) → El Planeta
  del Tesoro (esfera) → Studio Ghibli (colgante de Laputa y tarro de Ponyo) →
  Zelda (vela y batuta de Wind Waker, semilla dorada/kolog, reloj de
  arena/Phantom Hourglass, máscara de raza marina/Majora, el bloque de Link's
  Awakening —escudo, foto de Christine, peluche de morsa, huevo de montaña— y
  la botella de leche), con la Tripuerca cerrando la vitrina. Un coleccionable
  nuevo entra en SU grupo, no al final.
  **DE DÓNDE SALE CADA COSA** (regla de diseño del usuario, no re-litigar):
  lo que REFERENCIA otra obra se consigue PESCANDO (el cofre del minijuego),
  con dos excepciones que ya tienen escena propia — el sombrero de paja (el
  grumete) y la Tripuerca (sus fragmentos). Los PIRATAS genéricos se ganarán
  en aventura, arcade o por vías especiales; la excepción son los que uno
  draga literalmente del fondo (botella, ancla, calavera, hueso, pata de palo,
  tentáculo, garfio, brújula, catalejo, bala de cañón), que también se pescan.
  **Y hay diez TROFEOS que se ganan JUGANDO**, con sus umbrales en
  `CollectibleData` para que la ficha no pueda contradecirlos: **cuchillo del
  maestro** (`CUCHILLO_CORTES`, 200 cortes lentos bordados, stat `slices_ok`),
  **galón de oro** (`GALON_OLEADA`, oleada 20 del Arcade), **delantal
  chamuscado** (`DELANTAL_TIRADOS`, 100 platos al cubo, stat `plates_wasted`),
  **campana del último servicio** (`CAMPANA_PROPINA`, cerrar una jornada con 30
  doblones de propina, stat `best_tips_run`) y **diente de Kappa** (stat
  `bosses_beaten`, que sube `level3d._finalize_results` con `boss_done` — el
  diente cae cuando el JEFE se rinde, no cuando el nivel se cierra por oro).
  Las tres stats nuevas se apuntan en `_finalize_results`; el galón cuelga de
  `arcade_best`, que NO es una stat, así que `record_arcade_wave` pide la
  pasada de logros a mano.
  A esos se suman el **recetario completo** (aprender TODAS las recetas
  visibles; las ocultas —barco, combinados, tempuras fallidas— no cuentan
  porque no se aprenden nunca), el **anzuelo mágico gigante** (`ANZUELO_PECES`, 200
  capturas, stat `fish_caught`), el **dorayaki con un mordisco** (`DORAYAKI_PLATOS`, 100
  dorayakis hechos, stat `dish_dorayaki`), la **piedra de afilar gastada** (`PIEDRA_CORTES`,
  1.000 cortes lentos: es el escalón SIGUIENTE del cuchillo del maestro, se
  gasta de tanto afilarlo) y el **plato quemado**, que es el recuerdo del
  PRIMERO que se fue al cubo (`plates_wasted` > 0).
  **Y LOS PALILLOS SON UN ESCALÓN, no tres premios sueltos**
  (`PALILLOS_IDS` / `PALILLOS_PLATOS`): el mismo objeto en madera, plata y
  oro a los 300, 2.000 y 8.000 platos servidos (`dishes_made`, que no cuenta
  los del ayudante). Se comprueban los TRES escalones en cada pasada, no
  solo el siguiente: quien llegue de golpe se los lleva todos, de uno en uno
  y con su ventana.
  **LOS COLECCIONABLES CON ESCENA** (`CollectibleData.SCENE_ITEMS`) apuntan su
  id en `GameState.pending_col_scenes` (una COLA persistente) y la representa
  `main_menu._escena_coleccionable` al cerrar la pesca, con un guion por id en
  `_guion_coleccionable`. Se cuentan ALLÍ y no en el desbloqueo porque la
  ventana del coleccionable la saca NoticeLayer en su capa global, donde no
  cabe un diálogo con retrato; la escena ESPERA a `GameState.notices_busy()`
  para no salir por detrás de ese cartel, y la cola se vacía aunque el id no
  traiga guion (si no, el bucle de `_on_fishing_closed` giraría para siempre).
  Hoy son dos: el **corazón en un cofrecito** (David reconoce su propio
  apellido en la historia del cofre y Gigi le pregunta si no será él) y el
  **tenedor** (el peine de la sirenita: "yo en todo caso lo usaría en la
  barba"). Los guardados con la vieja bandera `pending_corazon` migran solos.
  No dan ni hacen nada: son para coleccionar (y para el logro "coleccion").
  El desbloqueo va SIEMPRE por `GameState.unlock_collectible(id)`, que anuncia
  con la ventana modal, guarda y repasa logros. Estado en
  `GameState.collectibles` + `triforce_pieces`.
  · **Disparadores vivos**: timón (5 vueltas al timón del menú; el arrastre y
    la inercia acumulan radianes en `main_menu._bank_wheel_turns` → stat
    `helm_turns`), bandera pirata (**EL pirata del nivel 7**, dándole
    `level_director.PLATOS_BANDERA` platos: ver ese nivel), mapa del tesoro (día 7 del bonus diario
    en `claim_daily`), cartel de recompensa (`bounty()` ≥ `CARTEL_BOUNTY`, 1M)
    y sombrero de paja (20 platos comidos por un cliente con
    `who_override == "grumete_sombrero"` — stat `fed_sombrero`; el personaje
    con sombrero AÚN NO EXISTE, queda para niveles futuros). Los tres de stats
    se comprueban al principio de `_run_achievement_check`.
  · **Pescables** (`FishData.FISHING_COLLECTIBLES`, 76): salen del COFRE del
    minijuego de PESCA, y son DOS familias — **todas las REFERENCIAS** a otras
    obras (Zelda, One Piece, Monkey Island, Day of the Tentacle, Piratas del
    Caribe, La Isla del Tesoro, Peter Pan, Popeye, El Planeta del Tesoro,
    Laputa) salvo el sombrero de paja y la Tripuerca, que tienen escena
    propia; y lo que uno **draga del fondo del mar** aunque sea pirata
    genérico (botella, ancla, calavera, hueso, pata de palo, tentáculo,
    garfio, brújula, catalejo, bala de cañón), más el maneki-neko roto. Su
    `desc` lo cuenta. El repetido paga `FishData.DUP_COINS` (80).
  · **QUÉ SON los coleccionables se explica UNA VEZ Y CON UNA PIEZA EN LA
    MANO** (`level_director._explicar_coleccionables`, bandera
    `col_intro_done`): la bandera del pirata del nivel 7, el tesoro del cliente
    del 12 o el primer cofre de la pesca, lo que llegue antes. Estuvo soltado a
    palo seco al empezar el puerto del 12, antes de que hubiera nada que
    enseñar, y sonaba a folleto.
  · **Sin disparador todavía**: lo que no esté en las listas de arriba (lo
    que huele a tierra firme: tricornio, pistola, sartén, One Piece salvo el
    sombrero...) — queda bloqueado y con `desc` genérica hasta que se decida
    su mecánica.
  · **Triángulo dorado**: 8 fragmentos (`GameState.add_triforce_piece`; su
    fuente es el cofre de la PESCA); al octavo se junta en UN coleccionable y
    regala 3 doblones. La vitrina enseña "n/8" sobre su silueta si hay alguno.
  · **UN TROFEO POR JEFE DE MAR** (`CollectibleData.BOSS_ITEMS`): la campaña
    son 7 mares y cada uno cierra con su jefe, que al rendirse deja su pieza
    — diente de Kappa, lágrima de sirena, diente de oro (pirata esquelético),
    frasco de bruma (pirata fantasma), tomo prohibido (Cthulhu), cucharón sin
    fondo (umibōzu, el truco con el que los marineros se libraban de él) y
    figura de shachihoko. La stat la apunta `level3d._finalize_results` como
    **"boss_<id>"** con el `boss` del puerto, así que **un jefe nuevo solo
    tiene que añadir su línea a `BOSS_ITEMS`**: el coleccionable cae solo.
    Hoy únicamente existe el Kappa; los otros seis esperan a su mar.
  · **LA ESMERALDA DEL CAOS cuelga de UNA ESPECIE del álbum**
    (`ESMERALDA_PEZ` = "froggy", la rana caótica): es la única pieza que se
    gana pescando un pez CONCRETO, y mira el ÁLBUM y no una estadística, así
    que cae también si esa rana se pescó antes de que la pieza existiera.
  · **LOS DADOS SE VALIDAN CONTANDO POR CÓDIGO, NO A OJO** (lección del
    19-8-2026): a Ludo se le pidieron las caras y devolvió dados con el 5
    repetido en dos caras del mismo dado, algo imposible. A tamaño de icono
    un 4 y un 5 no se distinguen, así que se comprobó detectando los pips
    por componente conexa y repartiéndolos por cara SEGÚN EL ÁNGULO desde
    el centro del dado (repartir por bandas horizontales metía los pips
    altos de la cara frontal en la de arriba y daba cuentas falsas). De ocho
    pares generados no salió ni uno correcto: el generador acierta un dado y
    falla el otro. La solución fue pedir UN SOLO dado —ahí sí acertó, 1-2-4—
    y **componer el par con dos copias suyas**, una girada 8°; dos dados
    iguales son una tirada de dobles, que existe. Si hay que rehacerlo:
    describir el PATRÓN de cada cara ("un punto centrado", "dos en
    diagonal", "cuatro en las esquinas") funciona mejor que el número.
  · **UN ICONO CON AGUJERO NECESITA LA SEGUNDA PASADA** (`CON_HUECO` en
    ui2_prep, hoy solo el cucharón sin fondo del umibōzu): `drop_white`
    inunda desde los BORDES, así que el blanco encerrado por el propio
    dibujo —el hueco de un aro— sobrevive y queda como un disco opaco. Se
    remata con `fill_white_holes`, la misma pasada que necesitaron el
    tachado de la papelera y el hueco del engranaje. Comprobado midiendo
    el ALFA del centro, no mirando la miniatura: ahí un hueco transparente
    y uno relleno de blanco se ven igual.
  · **EL DESGASTE SE PIDE EN EL PROMPT, NO SE APLICA POR CÓDIGO.** Los
    tesoros llevan años perdidos, así que a Ludo se le piden ya "worn",
    "stained" o "tarnished" y el dibujo nace con su desgaste. Hubo además
    un filtro de pátina (`ensuciar()` en ui2_prep: manchas de baja
    frecuencia, desaturación y tinte pardo) que se aplicó a todo el
    catálogo y **el usuario lo retiró** el 19-8-2026: apagaba demasiado el
    color —el latón del catalejo y el oro de la espada perdían su
    identidad— para lo que aportaba. La función y su lista de excepciones
    siguen en el archivo, SIN llamar desde `build_collectibles`, por si
    algún día se quiere recuperar: volver a encenderla es una línea. **No
    reintroducirla sin pedirlo.**
  · **Iconos** `assets/ui/col_*.png`: Ludo (item-icon, Western Cartoon) →
    `_gen/ui2/col/` → `build_collectibles()` de `tools/ui2_prep.py` (con
    `drop_specks`, NUNCA `keep_largest`: la trifuerza son 8 fragmentos
    separados por grietas). `timon` y `cofre` REUTILIZAN `timon.png` y
    `daily_cofre.png`, que ya son ese mismo objeto en el juego. **La VELA es
    la referencia a Wind Waker**: pedir "triangular sail" a Ludo da velas de
    CUATRO esquinas. Lo que acabó clavando la referencia fue describir la
    SILUETA pieza a pieza (pico arriba con parche rojo y ojal, costura
    horizontal cerca del pico con su parche en el extremo, esquina roja
    abajo-izquierda y punta LARGA saliendo por abajo-derecha) y el emblema
    como DOS formas verdes separadas (medialuna arriba + ola que se enrosca
    en espiral debajo), con el círculo crema pálido detrás.
  · La pestaña **Colección** del inventario es la vitrina: rejilla de 4, los
    bloqueados en SILUETA oscura con "???" y sin ninguna pista, los
    conseguidos abren su ficha al tocarlos.
- **LA FICHA SE ENSEÑA TAMBIÉN AL CONSEGUIR LA PIEZA**, no solo en la
  vitrina y en el álbum: la ventana del coleccionable
  (`NoticeLayer._show_collectible`) pinta su `desc` bajo el nombre y el
  cartel de captura de la pesca (`fishing_game._show_fish_reveal`) pinta la
  del pez entre la rareza y el premio. Los dos paneles CRECEN con el texto,
  y el alto se ESTIMA por caracteres a propósito: medirlo de verdad pide un
  fotograma y los dos carteles se montan ya colocados.
- `scripts/notice_layer.gd` — `NoticeLayer`, capa GLOBAL de avisos colgada del
  autoload GameState (capa 126, bajo el velo de fundido): sobrevive a los
  cambios de escena, así que un coleccionable ganado en mitad de un nivel o en
  el menú se anuncia igual. Toast de logro (no interactivo) y ventana modal de
  coleccionable (pausa el árbol mientras está puesta y RESPETA la pausa previa
  del cartel de resultados o de un guion). Todo EN COLA: varios avisos salen
  de uno en uno.
- **OJO con los HELPERS de verificación y el guardado**:
  `unlock_collectible`, `claim_achievement_rewards` y compañía GUARDAN A
  DISCO. Un helper que fuerce estado pisa `user://savegame.json` del usuario
  (pasó: hubo que reconstruirlo desde los backups `savegame.json.antes_de_*`).
  Antes de una pasada de helpers, COPIAR el savegame y restaurarlo después —
  y con rutas que existan de verdad en las DOS herramientas (el `/tmp` de Git
  Bash no lo ve Python, y un `cp` con `|| true` falla en silencio).
- `scripts/options_screen.gd` — Opciones (raíz **Node3D**, fondo `SceneBackdrop`)
  en TRES pestañas (el Perfil se mudó a `profile_screen`, y con tres tablones
  los rótulos recuperaron el cuerpo 26): **Gráficos** (bloques Alta / Media /
  Baja / Personalizado, con "Aplicar cambios"), la **Guía** (ver
  `guide_data.gd`) y **Progreso** (horas jugadas, MODO DEBUG y borrado). Los cambios
  viven en `draft_*` y NO tocan `GameState` hasta pulsar aplicar: así se puede
  probar una combinación y arrepentirse. Tocar un ajuste suelto pasa el bloque
  a "Personalizado" (`current_preset()` lo deduce comparando, así que el cartel
  nunca miente). **Borrar progreso va en dos pasos**: confirmación y después
  MANTENER pulsado 5 s con una barra roja que se vacía si se suelta antes;
  al llenarse borra y vuelve al menú desde negro.
- **MODO DEBUG** (Opciones → Progreso), con contraseña `sushi123`
  (`options_screen.DEBUG_PASS`): pone a mano los contadores gordos del
  progreso —dinero, coleccionables, nivel de cocinero, peces del álbum y
  escenarios superados—. No es seguridad, está escrita en el propio código:
  es un pestillo para que nadie entre sin querer y se encuentre el progreso
  cambiado. La interfaz solo recoge cifras; quien MUTA es
  `GameState.debug_apply`, que es el dueño del progreso.
  · **Solo viaja lo que se haya CAMBIADO de verdad**: tocar el dinero no
    puede rehacer de paso los veinte escenarios ni devolverle los puntos al
    cocinero. Por eso cada campo guarda su valor de partida (`antes`).
  · **Los escenarios se completan por el camino normal** (`complete_port`
    con 3 estrellas), no escribiendo `level_stars` a pelo: así caen también
    sus recetas y su despensa. Sin eso, «20 escenarios superados» dejaba el
    juego con el maki suelto y sin poder jugarse.
  · **El nivel del cocinero mueve la XP, no al revés**: se pone en la
    ENTRADA del nivel (`SkillData.xp_at_level`) para que la barra salga
    vacía. Los puntos SALEN del nivel, así que bajarlo puede dejar más
    invertido de lo que se tiene: antes que descuadrar el reparto se
    devuelven todos (`skills.clear()`).
  · Los coleccionables y los peces se rellenan **por orden de catálogo**, y
    con ellos se corrigen los datos que cuelgan: los fragmentos de la
    trifuerza y los récords de talla de peces que ya no están en el álbum.
  · **Va sin ventanas**: no pasa por `unlock_collectible` ni por los avisos,
    que aquí serían cien carteles seguidos.
- **La PORTADA ("Pulsa para zarpar") es un TERCER ESTADO de la escena del
  menú**, no una escena aparte (`main_menu._show_start`; el `start_screen.tscn`
  que existió un día se borró). El barco está atracado en un puerto
  (`scripts/start_port.gd`) construido alrededor de un ancla del mapa a
  `PORT_OFF` (-1500 px) del fondeadero; el paneo va por `cam_side`, el mismo
  desplazamiento lateral que usa la transición a la tienda. Al tocar, el
  logotipo se va por arriba y el barco navega hasta el fondeadero SIN fundido,
  como el viaje a Aventura; sin tutorial, el barco arranca y a mitad de camino
  cae el telón hacia la bienvenida de David. `GameState.booted` (de sesión, no
  se guarda) evita repetir la portada al volver de otras pantallas.
  · **EL PLANO DEL MAR TIENE QUE LLEGAR HASTA AQUÍ** (`level_select3d`,
    `SEA_SIZE` 190 u centrado hasta `SEA_BOTTOM_PX`): estaba dimensionado solo
    contra el mapa (98 u centradas en `MAP_HEIGHT`), y el fondeadero del menú
    queda MUY por debajo del nivel 1 —y la portada, encima, 1500 px a la
    izquierda—, así que en la esquina inferior izquierda se veía el borde del
    agua. Al mover `MENU_ANCHOR` o `PORT_OFF`, comprobarlo.
  · **El LOGOTIPO ya solo existe en la portada**: `_set_menu_ui_visible`,
    `_ui_in/_ui_out` y `_play_menu_intro` no lo tocan. En el menú su hueco lo
    ocupa el BARCO (`MENU_BAND_OFF` pasó de -70 a **190**: positivo = barco por
    encima del centro) y los botones subieron 60 px (offsets del VBox y
    `home_box_y` se mueven JUNTOS o la entrada aterriza en otro sitio).
  · Los carteles del menú (bonus diario, recetas) viven en `_menu_popups()`:
    en la portada no salen, se enseñan al LLEGAR al fondeadero.
  · **El puerto está medido contra el barco DEL MENÚ** (huella 2.3 x escala
    2.3 ≈ 5.3 u), no contra el de ficha del mapa: con las medidas del primer
    intento las farolas salían más altas que el mástil. Todo va en fracciones
    de `SHIP_W`.
  · **El muelle tiene FINAL por la DERECHA** (machón de piedra con noray y
    farola): al zarpar la cámara acompaña al barco y ese extremo entra en
    cuadro — sin él, el muelle se cortaba a cuchillo en mitad del mar.
  · **Lo que sube del entarimado se coloca CONTRA LA PANTALLA, no contra el
    muelle**: el logotipo ocupa x 150..570, y las dos farolas del primer
    intento cayeron justo detrás y "no existían". Farola a la izquierda del
    logo, género a su derecha.
  · El entarimado va ATENUADO (tinte 0.80/0.75/0.68): la madera clara del
    muelle a plena luz del menú salía como una banda blanca plana.
  · `farola.glb` entró por la cadena completa (concepto → imagen→3D →
    `glb_prepare` → presupuesto 900 en `decimate_import`).
- **CARTEL DE RECOMPENSA** (`scripts/wanted_poster.gd`, `WantedPoster`): la
  ficha del jugador y el único sitio donde se elige quién es. Lo usan la
  bienvenida de David (con el nombre escribible, anclada ARRIBA) y la pantalla
  **Perfil** del submenú (`profile_screen`, nombre bloqueado). La "foto" es el
  MODELO 3D vivo en un SubViewport con `own_world_3d`, y las flechas cambian
  de personaje. Nada toca `GameState` hasta `aplicar()`.
  El SUBTÍTULO y su selector se RETIRARON (los títulos de `title_data.gd`
  siguen en datos, sin interfaz); el nombre va CENTRADO a cuerpo 50 en
  Exo2-Bold sobre una LÍNEA DE ESCRITURA a tinta con una pluma latiendo en la
  punta — la señal de "aquí se escribe", solo con el nombre editable. El campo
  lleva `select_all_on_focus`: llega prerrelleno y sin eso el toque dejaba el
  cursor EN MEDIO y lo tecleado se incrustaba ("Kopu" -> "KoAnapu") hasta el
  tope de 14 letras — se vivía como "no me deja escribir otro nombre". Y
  `panel_size` suma el marco del tablón TAMBIÉN POR ABAJO, o las empuñaduras
  de las manos caían encima del canto dibujado.
  **OJO al parchear este repo con Python**: `CLAUDE.md` y varios scripts
  guardan CRLF y un `replace` multilínea con `\n` a secas FALLA EN SILENCIO
  (pasó varias veces en una misma sesión); los cambios multilínea van con la
  herramienta Edit, que compara con el archivo real.
  Cosas que ya se pagaron ahí:
  · **Los chefs vienen NORMALIZADOS Y CENTRADOS EN EL ORIGEN** (1.0 de alto, de
    y=-0.5 a y=+0.5), no de pie sobre el suelo. Con la cámara puesta a ojo "a la
    altura del pecho" apuntaba por encima de la cabeza y la foto salía VACÍA:
    el encuadre se calcula del AABB (`_frame_camera`).
  · **`CharacterAnim._rotate_bone` ACUMULA** y da por hecho que cada fotograma
    empieza con `reset()`. Sin llamarlo, la pose se retuerce sola: la chef salía
    ladeada y con un brazo en alto al cabo de un segundo.
  · Los modelos miran a **+Z**, que es de donde mira la cámara: NO hay que
    girarlos 180º (con el giro salen de espaldas).
  · Luz FLOJA (0.62 + 0.26), la lección de `chef_portraits.gd`: con la del nivel
    las caras claras se queman y el personaje sale sin rasgos.
  · La moneda del cartel es la `moneda.png` del juego pasada por el mismo
    `inkify` que los cofres del mapa diario, no un dibujo nuevo.
  · Las flechas de cambiar personaje son la MISMA punta de flecha que la caja
    de diálogo (`ic_siguiente.png`) y su espejo `ic_siguiente_esp.png`, no
    botones de madera; llevan `add_press_feedback`. El cambio es un CARRUSEL:
    el modelo que estaba sale por un lado y el nuevo entra por el otro. El
    recorte sale gratis, porque el SubViewport solo dibuja lo que cae dentro
    del marco de la foto.
  · **Se monta CON tablón o SIN él** (`show_board`): en la bienvenida de David
    lleva su pergamino de madera, y en Opciones NO, porque esa pantalla ya pone
    el suyo y dos marcos uno dentro de otro solo comían sitio. Sin tablón la
    hoja pasa de 520 a 640 de ancho. El hueco se reserva con
    `WantedPoster.panel_size(con_tablon)`, nunca con un número a mano.
- **`tools/face_paint.py`: la cara de la chef está PINTADA POR CÓDIGO.**
  `chef_fem_rig.glb` se modeló sin rasgos —un óvalo de piel liso— y en el
  cartel de recompensa, que la enseña grande, cantaba. No se puede arreglar
  abriendo el atlas en un editor: estos modelos vienen de imagen→3D y su UV
  está TROCEADO por triángulos (los vértices de la cara se reparten por todo el
  atlas, medido u 0.001..0.996), así que no hay ningún rectángulo "la cara".
  Lo que sí funciona es el camino inverso: recorrer los triángulos delanteros
  de la cabeza y, para CADA TÉXEL, deshacer la interpolación baricéntrica para
  saber a qué punto del modelo corresponde; si cae dentro de un rasgo, se pinta.
  **Y los rasgos van en PROPORCIONES DE LA CARA, que la herramienta MIDE sola.**
  Dos intentos fallaron por no hacerlo: anclando en "la punta de la nariz", lo
  que se detectaba como nariz era la FRENTE (en una cabeza low poly sobresale
  igual), y con distancias absolutas las cejas acabaron pintadas EN EL GORRO.
  La cara se localiza por COLOR DE PIEL y se recorta por ANCHO: el cuello mide
  0.047 y la cara 0.107, así que quedarse con las franjas anchas la deja sola.
  Medida real: va de y=0.338 a y=0.404 sobre un personaje de 1.0 de alto.
- **`scripts/title_data.gd`** (`TitleData`): el renglón bajo el nombre. El de
  salida (`MANO`) es especial —su texto sale de la mano dominante y del género,
  así que cambia solo—, y los demás hay que desbloquearlos
  (`GameState.unlocked_titles`); de momento no se gana ninguno.
  La RECOMPENSA del cartel es `GameState.bounty()` = la estadística
  `money_total`, que ya se sumaba en `level3d._finalize_results` en aventura Y
  en arcade. Los guardados sin ella la siembran con monedero + `money_spent`.
- **Los DOS géneros del jugador** (`CharacterData.PLAYER_GENDERS`): masculino
  `chef_rig.glb` y femenino `chef_fem_rig.glb`. `model()` cae al masculino si
  falta el archivo. El ayudante es del género contrario.
  **El NEUTRO se retiró** al entrar el cartel de recompensa: allí el género es
  el modelo que se ve en la foto y se pasa con flechas, así que una tercera
  opción "sin especificar" no tenía nada que enseñar. `CharacterData.NEUTRAL`
  sigue existiendo SOLO para reconocer guardados viejos (`load_game` los pasa a
  masculino); `chef_neutro_rig.glb` y `chef_x.png` quedan sin usar.
  **OJO: `chef_fem_rig.glb` NO TIENE CARA** —un óvalo de piel liso, sin ojos ni
  boca—; el retrato pre-renderizado `chef_f.png` tiene el mismo problema, o sea
  que viene del modelo y es anterior al cartel. Antes se veía pequeña y pasaba
  desapercibido; en el cartel de recompensa sale a tamaño grande y canta.
  **Los seis personajes tienen ya su pareja rigueada** (chef, ayudante,
  grumete, pirata, capitán y VIP × masculino/femenino, más el chef neutro): 13
  modelos, todos verificados miembro a miembro. Los ICONOS DE CABEZA
  (`tools/head_icons.gd`) salen de los modelos **RIGUEADOS**, no de los `_fem`
  sin riguear: se sacaban de estos y al rehacer las clientas el icono se quedó
  con la cara antigua.
  Los RETRATOS del selector (`assets/ui/chef_m/f/x.png`) salen de esos mismos
  modelos con `tools/chef_portraits.gd` (escena temporal, como
  `tools/head_icons.gd`): se rinden UNA vez a PNG porque tres SubViewports
  vivos en un menú serían tres escenas 3D de más. La luz del retrato es más
  suave que la del nivel: con la del nivel las caras claras se quemaban y el
  chef neutro salía sin rasgos. **`tools/head_icons.gd` tiene LOTERÍA de
  render**: en una misma pasada unos iconos salen limpios y otros con manchas
  oscuras (texturas a medio cargar al capturar). Tras regenerar, comparar cada
  PNG con `git diff` y **revertir los que no se buscaba tocar** — al rehacer
  `head_A_f`, `head_G_f` y `head_P` salieron manchados y hubo que devolverlos.
- **LA PIRATA FEMENINA LLEVABA GAFAS DE SOL (dos "parches") y se convirtió en
  UN parche + ojo repintando su textura**: `tools/eye_patch_fix.py`, con el
  original a salvo en `pirata_fem_rig_0.png.antes_del_parche` y la escena de
  verificación `tools/pirata_fem_check.tscn` (render de la cabeza con la misma
  cámara que `head_icons.gd`). Costó 17 rondas y todas las lecciones están en
  el docstring de la herramienta; el resumen:
  · **`tools/skin_pose.py` es la clave de todo**: en un modelo rigueado, las
    posiciones del accessor POSITION (pose de BIND) **pueden no ser dónde se
    dibuja el triángulo**. Medido aquí: los triángulos del cristal delantero
    tienen su bind en **y = −0.33, a la altura de los PIES**, y se dibujan en
    la cara. Por eso TODO filtro por coordenadas los dejaba fuera y sobrevivía
    un bulto oscuro sobre el ojo, ronda tras ronda. La herramienta aplica el
    skinning de la pose de reposo y devuelve las posiciones REALES; con ellas,
    los filtros geométricos de siempre funcionan a la primera.
  · Las gafas **SON la superficie de la cabeza**: al borrar sus triángulos del
    `.glb` se ve el fondo a través, no una cara debajo. Hay que repintar.
  · Qué es gafas se decide **por color y TEXEL A TEXEL** (nunca por el color
    medio del triángulo: los del borde son mitad lente y mitad piel y no
    llegaban al listón). Ojo: el pelo granate oscuro y el marco son casi el
    mismo color — se separan porque el pelo es ROJIZO (max−min 32) y el marco
    NEUTRO (max−min 9).
  · **El halo tiene que ser ANCHO (14 pasos)**: el modelo se ve pequeño, así
    que Godot muestrea un MIPMAP reducido que promedia téxeles de mucho más
    allá del borde de la isla. Con un halo de 3 el bulto seguía saliendo *con
    la isla entera ya pintada*. Y va vallado contra los téxeles del parche, o
    se le cuela por el atlas y le come un mordisco.
  · **El ojo es una mancha OSCURA maciza**, sin blanco ni pupila: la lente se
    pliega y parte de sus téxeles no se ven de frente, así que un óvalo con
    esclerótica salía como una media luna blanca con la pupila descolgada. Sus
    fracciones están afinadas contra el render — moverlas un poco lo deshace
    en motas, así que render tras cada cambio.
  · **NO sirve decodificar un render** con la textura sustituida por un
    gradiente de coordenadas: las texturas de modelo van en **Basis (con
    pérdida)** y el gradiente llega machacado. Para diagnosticar sí valen los
    colores PLANOS (magenta/verde), que sobreviven bien.
  · **Editar un PNG que usa un `.glb` exige `--headless --import` después**,
    o el render sigue sirviendo el `.ctex` viejo y parece que el cambio "no
    hace nada" (se perdieron varias rondas por esto).
- `scripts/achievements_screen.gd` — Logros (raíz **Node3D**): pestañas por
  apartado y una tarjeta por logro con la medalla conseguida, la barra de lo que
  falta para la SIGUIENTE y tres chapas. Los logros de receta llevan el sprite
  del plato como icono; los demás, la moneda del juego teñida del metal.
- **FUENTE del juego**: **Exo 2 Regular 400** (`fonts/static/Exo2-Regular.ttf`),
  puesta en `project.godot` como `gui/theme/custom_font`. Ese ajuste cambia
  `ThemeDB.fallback_font`, que es lo que usaba TODO el juego (no había ni un
  `add_theme_font_override` fuera de la caja de diálogo), así que con una línea
  cambia la tipografía entera. Las negritas del diálogo usan `Exo2-Bold.ttf`
  de verdad, no `variation_embolden`.
- **PERSONAJES 2D del guion** (`DialogueBox.SPEAKERS`): **David Jones**
  (`assets/characters/david/david_<mood>.png`, 12 expresiones), **Saverio**
  el tendero (`assets/characters/saverio/saverio_<mood>.png`, 5) y **Pablo el
  Rubio** (`assets/characters/pablo/pablo_<mood>.png`, 7: serio, hablando,
  feliz, riendo, sorprendido, guason y punal). Todas
  derivadas por `editImage` del mismo base para conservar la identidad.
  **La navaja de Pablo costó una docena de intentos**: pedir "un puñal en
  lugar de mano" da SIEMPRE una mano sosteniendo un puñal, por mucho que se
  prohíban los dedos. Lo que funcionó fue describirlo como PRÓTESIS con la
  referencia del garfio y por PIEZAS, en orden desde el hombro: "manga, correa
  de cuero, CASQUILLO DE ACERO CERRADO que sella el muñón, y la hoja saliendo
  del centro de ese casquillo en la misma dirección del antebrazo".
  Reglas que salieron de ahí y conviene no volver a aprender:
  1) **un cambio por pasada**. Envejecerlo Y arreglarle el brazo a la vez
  devolvía siempre la mano con empuñadura; por separado salió a la primera.
  2) Todo lo que suene a *dibujar más brazo* ("enséñame el antebrazo", "aleja
  la cámara") reintroduce la mano; lo que sí funciona es enumerar las piezas.
  3) Al envejecerlo **se le cae el bigote**: hay que devolvérselo en otra
  pasada. 4) En las expresiones hay que blindar la hoja ("delante de la
  mejilla, con su contorno, sin cruzar los ojos ni la cabeza") y prohibir
  explícitamente la perilla, o aparecen solas.
  El FONDO BLANCO no se quita por inundación: se pasa cada expresión por el
  `removeBackground` de Ludo y se compone después el lienzo (`AIRE` sobre la
  cabeza para que su cara mida como la de David: el recorte de Ludo va a
  sangre y sin ese aire se veía un palmo más grande que los demás).
  David lleva SIEMPRE a su loro **Gigi** al hombro, y por eso sus moods van en
  dos familias: con el loro CALLADO (serio, hablando, feliz, riendo,
  sorprendido, gritando, triste, mira_loro) y con el loro CHILLANDO con las
  alas abiertas (loro, loro_sorpresa, loro_grito, loro_resignado). **Gigi no
  tiene retrato propio**: es un hablante (`who: "gigi"`) que reutiliza el
  dibujo de David con el loro chillando y solo cambia el nombre del tablón.
  Gigi tiene mal genio, se enfada con los clientes y es quien salta cuando el
  jugador se equivoca; David hace de contrapunto (`loro_resignado`).
  **LOS CLIENTES DE SIEMPRE TAMBIÉN HABLAN**, y en sus DOS GÉNEROS: `grumete`,
  `pirata`, `capitan` y sus `_f`. Son retratos sin nombre propio para cuando un
  guion necesita que hable el que está sentado en la barra (el pirata del nivel
  7 y su bandera). Van a la DERECHA, como Saverio, Pablo y Cai.
  **El hablante NO se escribe a mano: se compone con
  `DialogueBox.speaker_for(tipo, genero)`**, pasándole el `gender` del propio
  `client3d`, así que el retrato de la caja es siempre el del cliente que está
  en el taburete. Si faltara el femenino, cae al masculino en vez de dejar la
  caja pelada.
  **SE GENERAN CON `generateWithStyle`, NO restilizando el modelo con
  `editImage`.** Se intentó lo segundo —partir del busto low poly y pedirle a
  `editImage` que lo dibujara en 2D— y NO funciona: la geometría achatada del
  origen se arrastra y sale una mascota vectorial de contorno grueso, que no
  tiene nada que ver con David y compañía. Con `generateWithStyle`, la
  referencia de estilo puesta en `david_serio.png` y el personaje DESCRITO por
  texto (ropa, colores y rasgos sacados de su modelo 3D), sale a la primera en
  la familia correcta. Tres cosas que costaron una pasada cada una:
  · **El estilo se pide como CARTOON PLANO**, con "flat cel shading, thin
    outlines, simplified stylised anatomy" y prohibiendo explícitamente
    "photorealistic / airbrushed / glossy": pidiéndolo sin eso sale un retrato
    pintado con músculos y piel realistas, demasiado lejos del resto.
  · **Con `reference_image` en `editImage`, los COLORES de la referencia se
    cuelan**: el pañuelo del pirata salía AZUL, que es el de Cai. Hay que decir
    "de la referencia, SOLO la técnica de dibujo; los colores, del original".
  · **Lo que tiene que estar EN CUADRO se nombra**: el cinturón del pirata se
    quedaba fuera hasta que se pidió "con su hebilla visible sobre el estómago,
    dentro del encuadre".
  Del resultado se quita el fondo por INUNDACIÓN desde los bordes (los blancos
  interiores —las rayas del grumete, la camisa del capitán— están encerrados
  por la línea de entintado y sobreviven) y se componen a 544×704 con el sujeto
  al 0,80 del alto y abajo, el encuadre de Pablo. **UNA SOLA escala y UN SOLO
  recorte por personaje**, sacados de su "serio": las expresiones vienen
  alineadas píxel a píxel, así que cambiar de mood no puede mover la cabeza.
  **Saverio sale a la DERECHA** y David a la izquierda: en la escena de la
  tienda están los dos a la vez y el que no habla se queda apagado y hundido.
  **Una línea puede llevar `side`** para forzar el lado SOLO en esa escena:
  Saverio y Pablo son los dos de la derecha y juntos se turnaban el mismo hueco
  con media pantalla vacía, así que en la tienda Pablo pasa a la izquierda (y
  su tablón, al contrario del retrato).
  El tablón del nombre va en el lado CONTRARIO al retrato de quien habla —
  encima del suyo le tapaba el pecho y se salía por el borde.
  **Encuadre**: Saverio se generó primero demasiado cerca (su cabeza ocupaba
  el 47% del alto frente al 30% de David) y hubo que rehacer la base pidiendo
  explícitamente "cámara MUCHO más atrás, de la cintura para arriba, con aire
  sobre la cabeza" y volver a derivar las expresiones desde ahí.
- **ALICE** (`assets/characters/alice`, hablante `alice`, 7 moods: los cinco de
  siempre más `triste` y `callado`): la aprendiza de cocinera, gótica y mona a
  la vez —kimono negro con ribete violeta, obi granate, delantal blanco, lirio
  en el pelo y gargantilla de encaje—, que busca a su maestra Miku. Sale de
  CLIENTA en su escenario y al superarlo se enrola como AYUDANTE. Tímida: por
  eso tiene `callado`, como Cai.
  **LAS DOS HERRAMIENTAS DE LUDO SE COMPLEMENTAN Y HAY QUE ENCADENARLAS**, que
  es lo que costó sacarla:
  · **`generateWithStyle` gira la POSE pero SIEMPRE afina el entintado** (deja
    el contorno fino y el sombreado suave, aunque el prompt insista en lo
    contrario).
  · **`editImage` NUNCA gira la pose** —conserva la composición— **pero SÍ
    entinta**. Así que primero el giro y luego la tinta encima; por separado
    ninguno de los dos llega.
  · **`augment_prompt: false` deja mandar a la imagen de estilo y reproduce al
    PERSONAJE de la referencia**, no solo su técnica: salió David otra vez, con
    su pelo gris y su casaca. Con la augmentación puesta sí entra el personaje
    descrito.
  · La pasada de SOMBRAS **vuelve grises los negros** (pelo y kimono a carbón,
    y una vez el obi a morado): hay que devolver el negro en una pasada aparte
    pidiendo SOLO eso.
  · **La cara se describe PIEZA A PIEZA**, no por referencia: pidiendo el
    estilo del reparto salían ojos de anime una y otra vez. Lo que funciona es
    enumerar ojos, nariz y boca. Y al revés: los ojos ALMENDRADOS de Alice
    (línea de pestañas gruesa, iris casi negro llenando la abertura) también
    hubo que escribirlos, porque la descripción "de cartoon" los dejaba
    redondos de muñeca.
  · **La cabeza se giró hacia el lado CONTRARIO al del cuerpo** y con las
    pupilas corridas hacia fuera: una contorsión imposible. Se arregla pidiendo
    la cabeza DE FRENTE al jugador —alineada con el giro del cuerpo, nunca
    contra él— y los dos iris CENTRADOS.
  · El iris quedó pardo aun pidiéndolo negro; se oscureció **sobre el PNG**
    (`_gen/alice`), sin volver a generar. **Con UNA CAJA POR OJO, no una que
    los abarque a los dos**: la caja ancha pilla los mechones del pelo de los
    lados y deja un corte recto visible. Se comprueba con un diff contra el
    original, que canta si el cambio se salió de los ojos.
  · **LAS LÁGRIMAS DE `triste` SE QUITAN EN EL MONTAJE, no en el prompt**: el
    generador se las puso las DOS veces pese a prohibirlas, y el retrato base
    tiene que estar sereno (una lágrima es decisión de guion, no el estado por
    defecto de la cara). `quitar_lagrimas` las detecta **contra la mediana de
    piel de SU FILA**, no contra un umbral fijo: el reguero no es blanco —según
    baja por la mejilla se queda en r−b 56..70 contra los 79..84 de la piel de
    al lado—, y un corte fijo en 50 solo pillaba la punta. Dos trampas pagadas:
    con UNA caja ancha el filtro se comió la **esclerótica de los ojos** y el
    puente horizontal los borró dejando una banda gris de lado a lado de la
    cara (van DOS ventanas estrechas, una por lágrima, por fuera de los ojos),
    y por eso hay además un **tope de anchura**: una racha de más de 8 px no es
    una lágrima y se deja en paz.
  **El montaje es `tools/alice_portraits.py`** (inundación + recorte + 544×704).
  Dos cosas suyas: se inunda solo desde ARRIBA, IZQUIERDA y DERECHA, porque el
  encuadre la corta por la cintura y desde el borde de ABAJO la inundación se
  mete dentro del delantal blanco y se lo come; y **el recorte y la escala se
  calculan UNA vez sobre `serio`** y se aplican igual a todas, que por eso las
  expresiones no mueven la cabeza. Su cara mide 135 px, entre el grumete (116)
  y la grumete (157) y clavada con Cai (136).
  **SU MODELO 3D SIRVE PARA SUS DOS PAPELES** (`alice_rig.glb`, una sola
  entrada en `CharacterData.MODELS["alice"]`): la clienta del escenario 17 y la
  AYUDANTE de la tabla en cuanto se enrola. Es la misma persona y el mismo rig,
  así que dos modelos serían dos veces los mismos triángulos. Con ella se
  fueron `ayudante_rig` y `ayudante_fem_rig` —los dos figurantes que se elegían
  por el género CONTRARIO al del jugador— y con ellos `GameState.helper_gender()`;
  el botón de la tabla enseña ahora su icono de cabeza.
  · **SU CONCEPTO 3D LLEVA EL KIMONO CORTO A PROPÓSITO**: una prenda larga tapa
    las piernas y el rigueador se las funde en una, que es lo que tuvo al
    ayudante sin animar durante seis intentos. Kimono hasta la cadera, delantal
    hasta la cadera, pantalón por piernas separadas y hueco de fondo visible
    entre ellas hasta arriba. Rig medido: 52 huesos
    (`humanoid_template_hands`), brazos al 34% del alto y piernas al 60% —
    largas, pero sanas: el fallo típico son 1-4%.
  · **Su ICONO DE CABEZA necesitó DOS perillas nuevas en `tools/head_icons.gd`**:
    `DROP_OVERRIDE`, porque su melena baja la caja del modelo y el encuadre
    general le dejaba la cara diminuta, y `LIGHT_OVERRIDE`, porque su piel
    pálida se quemaba a blanco liso sin ojos ni boca (la misma lección de
    `chef_portraits.gd`, ahora ajustable por icono).
  · **ESCENARIO 17** (`nivel_13`, Rada de los Dos Fuegos — un **ABORDAJE**,
    decidido por el usuario: reloj y clientela sin fin): se sienta de clienta
    (`special_client`, come como un GRUMETE), cuenta que busca a **una
    persona** —su maestra— y con `level_director.PLATOS_ALICE` (3) platos se da por servida
    (`GameState.alice_saciada`). La escena en la que SE ENROLA no va en el
    nivel sino en el mapa (`main_menu._presentar_alice`), igual que con Cai: es
    la que ESTRENA los bonificadores y le regala el del ayudante, que es ella.
    Si el turno se cerró por objetivo sin darle de comer, se enrola igual pero
    sin fingir una comida que no hubo.
  · **EL NOMBRE DE MIKU NO SUENA EN EL NIVEL** (pedido por el usuario): allí
    Alice solo dice que busca "a una persona". Lo suelta después, en el mapa,
    al pedir enrolarse: acaba de conocerlos y ese es el momento en que se abre
    con ellos.
- **Las explicaciones sueltas del menú y del mapa montan UNA CAJA POR BLOQUE**,
  y por eso tienen dos ayudas propias: `DialogueBox.close_and_free()` (cierra
  CON su fundido y espera a que termine antes de soltar el nodo — hacían
  `queue_free()` en cuanto llegaba `finished` y David desaparecía de golpe) y
  `main_menu._velo_guia()` / `_quitar_velo()` (el velo oscuro entra y sale con
  fundido en vez de aparecer de un fotograma a otro). Además, `_fade(true)`
  pone `modulate.a` a 0 cuando la caja NO estaba visible: el nodo nace con
  alfa 1, así que la PRIMERA aparición tweenaba de 1 a 1 y no se fundía.
- **`DialogueBox` OSCURECE EL FONDO y entra y sale con fundido**: velo negro a
  0.42 por detrás del retrato, y la caja aparece subiendo 34 px y se va bajando
  (0.22 s / 0.16 s). Dos cosas aprendidas ahí: 1) los guiones (`story_director`)
  ponen su PROPIO velo o el foco circular, así que ahí se apaga el de la caja
  (`dialog.veil_on = false`) o el nivel se queda casi negro; 2) el fundido de
  entrada hay que lanzarlo DOS FOTOGRAMAS después de montar la escena — el
  primer `_process` trae un delta enorme (todo lo que tardó en cargar) y el
  tween se lo salta de golpe, así que no se veía nunca.
- **`DialogueBox` se queda con TODO el puntero desde `_input`, no desde
  `_gui_input`**: con `_gui_input` solo se consumían los eventos TÁCTILES, y un
  clic de ratón genera DOS (el suyo y el táctil que sintetiza
  `emulate_touch_from_mouse`): el táctil pasaba la línea y el de ratón seguía
  hasta el botón de debajo, así que tocar un ingrediente de la tienda para
  pasar el texto abría de paso su panel de compra. Mientras SE VA no consume
  nada (`_closing`), o los 0.16 s de la salida se comían el primer toque del
  jugador justo cuando el guion le acaba de dar el turno.
- **La FLECHA de "toca para seguir" va en un hueco propio y con valores
  ABSOLUTOS**: el latido movía `position:x` con `as_relative()` sobre el nodo
  anclado y, como cada línea nueva mata y rehace el tween, si moría a mitad de
  la ida la flecha se quedaba desplazada y el siguiente latido partía de ahí.
  Se iba escapando a la derecha hasta salirse del pergamino. Misma lección que
  las transiciones del menú: nada de `as_relative()` en algo que se repite.
- **La GEOMETRÍA de la caja va en constantes** (`PANEL_TOP/PANEL_BOTTOM/
  PORTRAIT_TOP/PORTRAIT_BOTTOM`, `TEXT_SIZE` 30, `TEXT_MARGIN` 112): el alto de
  la caja y el apoyo de los retratos tienen que moverse JUNTOS o los personajes
  se quedan flotando. Antes de subir el cuerpo de letra, MEDIR: con la fuente
  real, la línea más larga del guion pide 7 renglones a cuerpo 30 con margen
  112, y la caja tiene que dar para eso (de ahí los 406 px de alto).
- **Máquina de escribir de `DialogueBox`, la trampa**: NO comparar contra
  `RichTextLabel.get_total_character_count()`. Devuelve 0 hasta que el nodo ha
  maquetado, así que en el primer `_process` se cumplía `0 >= 0` y la línea
  salía entera de golpe (el efecto no se veía NUNCA). La longitud se calcula a
  mano quitando los marcadores `**` del texto de origen.
- **TUTORIAL de David Jones** (capitán calvo con barba GRIS y larga, retrato
  2D cel-shading):
  `scripts/dialogue_box.gd` (`DialogueBox`): caja de pergamino inferior +
  retrato a la izquierda + tablón con el nombre; máquina de escribir letra a
  letra (un toque completa la línea, el siguiente avanza; flecha ▶ latiendo
  cuando se puede pasar), texto con márgenes anchos (95 px: los rodillos del
  pergamino tapaban 52), **palabras clave entre `**asteriscos**` en el guion**
  → negrita teja vía `format_keywords` (NUNCA mayúsculas), `set_raised(true)`
  sube caja y retrato ~330 px (para no tapar la fila de recetas al hablar de
  ella); `say([{text, mood}...])` → señal `finished`; traga TODO el input y
  funciona en pausa.
  **TRAMPA de CanvasLayer**: un Control colgado de un CanvasLayer recién creado
  NO debe usar `set_anchors_preset` — FULL_RECT se resuelve contra la VENTANA
  FÍSICA (p. ej. 1450×2560 en pantalla escalada) o queda a 0×0, pisando el
  tamaño. Anclas a cero + `position`/`size` de diseño (720×1280) explícitos:
  así van la raíz de DialogueBox y el paño del foco.
  `scripts/david_intro.gd` + `scenes/david_intro.tscn`: DESDE LA CUBIERTA del
  barco (cubierta propia construida por código), hoy es SOLO la ficha de
  tripulación — dos frases, el cartel de recompensa con nombre y género, y al
  aplicar `complete_tutorial()` y al menú. La bienvenida larga que hubo aquí
  se fue: el discurso lo da David en la intro del caos.
  `scripts/tutorial_director.gd`: la INTRO DEL CAOS (ver el bloque de guiones
  arriba). En modo tutorial level3d NO termina solo (`_end_level` ignora reloj
  y clientes), sin fase de preparación, `tutorial_mode` oculta barco/combinar/
  extras (y el caos esconde además cajas y bote con `hide_storage` +
  `no_powerups`). `GameState`: `tutorial_done` persistente (los saves viejos
  con recetas lo dan por hecho; **`_new_game` DEBE ponerlo a false** — se
  olvidó y borrar la partida no relanzaba la intro), `is_tutorial()`,
  `complete_tutorial()` (entrega `CampaignData.INITIAL_RECIPES`, que ya es
  SOLO el maki de aguacate: el resto de la carta la regala David nivel a
  nivel), `arcade_unlocked()` (= superar `GameState.ARCADE_PORT`, la **Cueva
  del Kappa, escenario 20**: vencer al jefe abre el Arcade); el menú manda a la intro del
  caos si falta el tutorial (`_ir_a_la_intro`) y el botón Arcade queda apagado
  con aviso hasta ganarlo.
  **La partida nueva empieza con 50 doblones** (botín de bienvenida para la
  tienda).
- `scripts/prep_board.gd` — la tabla inferior: minijuego de elaboración por
  etapas, mano de gestos animada, cajas de guardado por pilas, cooldowns. Ocupa
  **588 px** de alto (llega bastante más arriba que antes) para que la tabla de
  manipulación sea grande. Orden vertical: cinta → tabla (`BoardPanel`) →
  **instrucción escrita** → botones de receta.
- `scripts/client.gd` — cliente: entra andando, se sienta, coge platos, come,
  propina, se va andando. Tipos: E grumete, A pirata, G capitán (V VIP
  pendiente). SIN bocadillos de ánimo, satisfacción NI saciedad objetivo: el
  cliente se queda hasta que su barra de paciencia se agota (nunca "termina de
  comer"), y cada plato comido ACELERA el drenaje de paciencia
  (`PATIENCE_DRAIN_PER_PLATE` ×0.025 por plato). `EAT_TIMES` da el tiempo de bocado
  FIJO por tipo×nivel (7/12/18 grumete · 6/10/15 pirata · 5/8/12 capitán, con
  un `EAT_JITTER` de ±5% para que dos clientes iguales no terminen en bloque):
  el nivel pone la base (6/10/15) y el tipo un factor (x1.2 · x1.0 · x0.8), de
  modo que los doblones POR SEGUNDO DE ASIENTO suben limpio de 0.51 (grumete
  con 1★) a 1.04 (capitán con 3★). Como comer NO gasta paciencia, el bocado es
  lo único que sostiene una mesa de cuatro sitios frente a una cocina con
  enfriamientos de 3-9 s. `PATIENCE_FOOD` recarga
  paciencia según el nivel del plato (L1 9% · L2 22% · L3 32%; el 3★ bajó desde
  el 38% porque con esa recarga el CAPITÁN no llegaba a marcharse nunca —ganaba
  más paciencia por plato de la que gastaba esperando—), escalada por el
  sistema de HASTÍO Y VARIEDAD (ver su bloque en la sección de balance): los
  platos nunca probados alargan la racha del cliente y recargan cada vez más;
  los repetidos la rompen y suben una escalera monótona que primero recarga
  poco y de la 4ª repetición en adelante DRENA la barra.
- `scripts/level.gd` — orquestador 2D ORIGINAL (referencia hasta terminar la
  conversión 3D; el juego ya NO lo usa): cinta (Line2D por tramos), spawner por
  horario (configurado por el nivel de campaña), HUD, propinas/potenciadores,
  puntuación POR DINERO, panel de resultados (anuncia recetas desbloqueadas).
- `scripts/level3d.gd` + `scenes/level3d.tscn` — **el nivel EN USO** (3D low
  poly, mismo HUD 2D): port 1:1 de la lógica de level.gd sobre un mundo 3D
  construido por código (cámara iso ortogonal pitch −35.264/yaw 45/**size 17**;
  circuito = cuadrado de 3.6 u; platos **1.35 u/s**). **Escenario según el TIPO del
  nivel** (`CampaignData.get_kind`): `_scenery_island` (arenal con palmeras),
  `_scenery_port` (muelle con norays/farol) o `_scenery_ship` (abordaje: barco
  VIEJO — tablones desgastados/arrancados con el mar asomando, barandillas
  rotas, manchas y **mástil CENTRAL con velas rasgadas dentro del circuito,
  junto al chef**); los tres contenidos en el encuadre para que el mar asome.
  Las esquinas de la cinta NO llevan placas (se quitaron a propósito). Chef y
  su mesa **orientados al mismo lado** (yaw 45, de cara a la cámara). **DOS
  bordas de entrada** (`ENTRY` arriba / `ENTRY_BOTTOM` abajo): cada cliente
  entra y sale por la más cercana a su silla (`seats[]["entry"]`); la ruta
  rodea el pasillo `WALK_R` por el lado más corto desde su borda. `world_ui`
  (CanvasLayer bajo el HUD) recibe barras y textos flotantes de los clientes,
  anclados con `cam.unproject_position` (cámara fija). **Fin de nivel: 4 s con
  todo parado** (banda quieta, platos con `ended`, `prep_board` deshabilitada)
  antes del cartel. **Botón "Salir"** bajo el reloj: confirmación en pergamino;
  en fase de preparación DEVUELVE los usos de ingredientes, los de
  potenciadores permanentes **y el saco de arroz** (la fase dura 10 s, así que
  ese es el margen para arrepentirse); en partida avisa de que se pierden,
  arroz incluido, y el cartel lo dice con esas palabras; vuelve a level_select3d (aventura) o main_menu (prueba). La
  banda usa `belt_scroll_3d.gdshader` con `scroll_tiles` empujado por frame
  (se para al congelar y al terminar, acelera con "Cinta rápida").
- `scripts/client3d.gd` — cliente 3D (misma lógica que client.gd): modelo GLB
  riggeado + `CharacterAnim` (walk/sit_idle/bite procedurales). Camina a la
  velocidad natural de su ciclo (~1.2 u/s, decidido: más lento que el 2D para
  cero patinaje). Sin física: sondea el grupo "plates" por distancia a su punto
  de cinta. Se sienta SOBRE el taburete ajustando el cuerpo para que la cadera
  quede a `STOOL_TOP`+glúteos; el plato que come va al punto `hand_plate` del
  esqueleto (la mano llega sola). Alturas por tipo: E 1.45 · A 1.75 · G 1.95.
- `scripts/plate3d.gd` — plato en cinta: PathFollow3D por el Path3D del
  circuito, modelo normalizado por huella (0.62 u), 2 vueltas → descarte.
- `scripts/main_menu.gd` — menú inicial (ESCENA PRINCIPAL, raíz **Node3D**):
  CUATRO botones de modo con icono propio — **Aventura** (campaña), **Arcade**
  (el ARCADE SIN FIN, ver su bloque: una jornada de verdad que gasta arroz y
  despensa y paga oro y experiencia), **Pesca** (el minijuego, ver su
  bloque; se abre con la Isla de Gades) y
  **Tienda** — apoyados sobre el
  **SUBMENÚ inferior**: una barra de madera oscura con cuerda en el canto
  (`submenu_barra.png`, estilo propio, exportada al alto exacto de dibujo con
  margen vertical CERO como los botones con icono) con los CINCO accesos del
  jugador: **Logros, Inventario, Perfil, Bonificadores y Opciones** (iconos
  `ic_logros/ic_inventario/ic_perfil/ic_perks/ic_opciones`). Las MAESTRÍAS no
  van aquí: su acceso es la BARRA DE NIVEL del centro del menú (ver su
  bloque). El submenú sustituyó a los dos botones redondos de esquina que
  hubo antes.
  · **Perfil** abre `profile_screen` (el cartel de recompensa en pantalla
    propia; ya NO es pestaña de Opciones, que se quedó con Gráficos/Guía/
    Progreso a cuerpo 26).
  · **Bonificadores** abre `perks_screen` (los permanentes de `PerkData`; ya
    NO son la pestaña "Mejoras" del Inventario, que se quedó con Recetario y
    Despensa). Tarjetas con `CARD_TEX` (pergamino liso) y recompra de usos.
  · Las gaviotas y las nubes ENTRAN planeando desde arriba (`_sky_in` +
    `sky_drop`): `_process` las coloca cada fotograma, así que un tween de
    posición pelearía con él — se anima un DESVÍO vertical que `_process` suma
    y el tween funde a cero (el gemelo de `sky_leaving`, al revés).
  El fondo es una **escena 3D animada**: el barco del jugador
  (`map_barco.glb`) cabecea y se balancea en mar abierto (mismo
  `water_map_3d.gdshader` del mapa), ARRIBA, ocupando el hueco que dejó el
  logotipo cuando este se mudó a la PORTADA (ver ese bloque: en el menú ya no
  hay logo). `logo_sushi_pirata.webp` se generó con Ludo y se recortó con
  `tools/logo_prep.gd`.
  En el mar van el barco, unas **gaviotas** y **nubes translúcidas** que cruzan
  por delante (en 3D, así que el logotipo y los botones siempre quedan encima).
  **Decisiones ya tomadas:** el casco NO proyecta sombra real —al cabecear, la
  sombra bailaba por el agua— sino una **mancha fija** bajo él
  (`_make_blob_shadow`); las gaviotas van TODAS claras, con cuerpo pequeño y
  alas en V (con cuerpo oscuro parecían martillos); y las islas/puertos que
  pasaban de largo se quitaron por ensuciar el encuadre.
- **El menú principal Y el mapa de campaña son LA MISMA ESCENA**
  (`main_menu.gd` hereda de `level_select3d.gd`). Los nodos de la campaña
  existen desde el arranque, pero el barco está fondeado en `MENU_ANCHOR`, muy
  por debajo del nivel 1, así que ninguno asoma. Al pulsar Aventura el barco
  navega hasta el último nivel abierto y entra la interfaz del mapa; "Atrás"
  desanda el camino. Nadie debe abrir `level_select3d.tscn` a pelo: se pide
  `GameState.transition = "mapa"` y se carga `main_menu.tscn`. Con la escena
  en modo menú, `_unhandled_input` ignora el arrastre: si no, se podía
  recorrer el mapa y ver los niveles antes de tiempo.
- **Animar la interfaz del menú (3 trampas ya pisadas)**: 1) el logotipo vive
  dentro de `logo_holder` — el balanceo mueve el LOGO y las transiciones mueven
  el CONTENEDOR; compartiendo `position:y` los dos tweens se pisaban y el
  logotipo se quedaba a medio camino. 2) Nada de `as_relative()` en las
  salidas: cada una acumulaba desplazamiento. 3) La salida usa `TRANS_QUAD`,
  no `TRANS_BACK`: la anticipación del rebote hace que el logotipo baje un
  poco antes de subir y parece que no llega a irse.
- **Encuadre menú ↔ mapa**: `menu_blend` (1 = menú, 0 = mapa) interpola el
  offset de banda de la cámara durante el viaje. Cambiarlo de golpe con un
  `if in_menu` daba un salto de ~200 px justo al arrancar, que es el "tirón"
  que se veía al entrar y al salir de Aventura.
- **Animar la interfaz del menú**: las posiciones de reposo se guardan en
  `home_logo_y/home_box_y/home_coin_y` al construirla. `_ui_in` NO puede leer
  la posición actual (después de una salida ya está desplazada: los botones se
  quedaban fuera de la pantalla). El balanceo del logotipo se arranca al FINAL
  de la entrada y con un temporizador aparte: lanzado a la vez, los dos tweens
  pelean por `position:y` y el logotipo se queda a medio camino.
- **Transiciones del menú** (`GameState.transition` encadena salida y entrada):
  *Aventura* aleja la cámara y manda el barco al fondo; *Arcade* lo saca por la
  derecha y el selector de recetas baja desde arriba (y al volver "Atrás" se
  deshace el camino: panel arriba, Zarpar abajo, barco entrando por la
  izquierda); *Tienda* trae un puerto por la derecha, el barco navega hacia él
  **con la cámara detrás** (`cam_side`) y el zoom cierra sobre el atraque
  (`SHOP_DOCK_AT/SHOP_SAIL/SHOP_ZOOM_SIDE/SHOP_ZOOM_SIZE`, calibrados para que
  quepan barco Y muelle: el barco del menú es enorme y con `size` 7.5 el puerto
  se salía de cuadro); *Inventario* apaga la pantalla y sus bloques entran por
  lados distintos. La VUELTA de tienda e inventario es un fundido a negro
  normal: deshacer el atraque no aportaba nada. Mientras dura una transición,
  `leaving` corta el `_process` del fondo para que no pelee con el tween, y
  `sky_leaving` para la colocación por frame de gaviotas y nubes (viven
  alrededor del barco, así que `_process` les fijaba la posición entera cada
  fotograma y se las veía desaparecer y reaparecer de golpe).
  **El fondo del selector de recetas en Arcade es SOLO MAR** (`kind = "mar"`):
  el barco acaba de salir por la derecha y volver a verlo rompía el encadenado.
- `scripts/level_select.gd` — **mapa marítimo**: el barco del jugador navega por
  el mar entre los nodos de la campaña. Cada nivel es de un TIPO (`CampaignData.
  KINDS`): "isla", "puerto" o "abordaje" (asaltar otro barco); de momento el tipo
  es solo identidad visual, en el futuro dará una característica única al nivel
  (para añadir tipos: ampliar `KINDS`/`KIND_NAMES`/`KIND_TEXTURES`). Cada nodo
  lleva las estrellas conseguidas, el sprite isométrico del tipo y un cartel de
  madera con el NÚMERO del nivel; al tocarlo el barco viaja hasta él (tween) y el
  panel inferior despliega nombre, tipo y todas las características (clientes por
  tipo, tiempo, objetivo, récord, recompensas). Posiciones en `CampaignData.
  MAP_POS` sobre un lienzo de `MAP_HEIGHT`; los bloqueados no reciben al barco.
  **La travesía va de ABAJO ARRIBA** (nivel 1 el más bajo) y los nodos alternan
  entre TRES carriles (`LANE_LEFT/CENTER/RIGHT`) para que la ruta serpentee.
  **Todo está animado**: el mar usa `shaders/water_ww.gdshader` (ver el bloque
  del MAR más abajo; el `water_map.gdshader` 2D se queda para esta referencia)
  y el barco pasa los 16 fotogramas
  de `barco_anim.webp` (velas al viento, generado con Ludo `animateSprite` +
  `editSpritesheet` en modo `fix_loop`), recortados con `AtlasTexture` de una
  rejilla 4x4 (el tamaño de fotograma se deduce de la textura).
  **Decisiones ya tomadas (no repetir):** el barco se reproduce en **ping-pong**
  (0→15→0) porque el bucle directo daba un salto brusco en la sombra al
  reiniciar. Y el mar NO se puede animar con Ludo: `animateSprite` siempre
  recorta el fondo y en una textura de agua a sangre el azul *es* el fondo, así
  que lo borra y deja solo la espuma; además la animación rompería la
  continuidad de bordes y el mar tileado saldría con costuras. Por eso el
  movimiento del agua va por shader (deriva + dos senos cruzados).
- `scripts/shop_screen.gd` — tienda (raíz **Node3D**): el **tendero 3D**
  (`tendero.glb`, sin rig: respira y se balancea desde su pivote) atiende en un
  **PUESTO DE MERCADO** montado sobre un muelle en el mar. El puesto se
  construye por código (`_build_stall`) con las maderas de `assets/props` —
  antes era una caja marrón lisa con dos cubos al lado y se leía como una mesa,
  no como una tienda: mostrador de tablas con tablero y zócalo, cuatro postes
  con sus vigas, **toldo a rayas** de listones alternos con faldón, estantería
  a la espalda con tarros, cartel colgante con un pez, y los MODELOS
  `caja.glb` y `barril.glb` de género (no cubos de color).
  Saverio **saluda al entrar y se despide al salir**, con una frase al azar de
  `SALUDOS`/`DESPEDIDAS` (una docena de cada) que lleva su expresión y el
  nombre del jugador; el sorteo no repite la última. La salida ESPERA a la
  frase antes de fundir, o se leería media línea. La primera visita no saluda:
  ahí va la presentación con David.
  **Dos trampas de la cámara isométrica, ya pagadas:** 1) el toldo sube hacia
  DELANTE, al revés que un toldo de verdad — con el picado de 35° uno que caiga
  hacia el espectador se dibuja justo encima del tendero y solo se le ven las
  piernas; y termina antes del mostrador o taparía el género. 2) El cartel va
  **girado 45°**: una tabla alineada con los ejes del mundo se ve DE CANTO,
  como una raya (`SIGN_RIGHT`/`SIGN_FRONT` son los ejes ya girados). Vende USOS de ingredientes (`cost` en
  `RecipeData.INGREDIENTS`) de un surtido de **8 artículos que cambia cada día
  real** (`GameState.shop_stock/shop_day`, se renueva solo al cambiar la fecha);
  el botón **"Recargar artículos"** vuelve a sortearlo pagando
  `GameState.SHOP_REROLL_COST`. Al tocar un artículo se abre un cartel que
  pregunta CUÁNTOS usos se quieren (flechas ◄ N ►, total y dinero restante).
- `scripts/inventory_screen.gd` — inventario (raíz **Node3D**, fondo 3D del
  barco) con tres pestañas:
  **Recetario** (libro `libro.png` con 4 recetas por doble página, buscador y
  filtros de vegetariana / tipo de cliente; salen TODAS, las no aprendidas como
  silueta "???"; al tocar una se abre su ficha con precio, saciedad, cooldown,
  ingredientes, qué clientes la cogerán —leyendo `client3d.TAKE_CHANCES`, para
  que la ficha nunca mienta— y una DEMOSTRACIÓN que recorre sus pasos en bucle
  mostrando la etapa y el gesto),
  y **Despensa** (otro libro, 8 ingredientes por doble página con sus usos).
  La antigua pestaña "Mejoras" es hoy `scripts/perks_screen.gd` (el botón
  **Bonificadores** del submenú): los permanentes de `PerkData`, los no
  conseguidos con su condición y los conseguidos con sus usos y recompra.
- `scripts/scene_backdrop.gd` — `SceneBackdrop.build()`: fondo 3D reutilizable
  (mar animado + el modelo del tipo de nivel) que usan prep_screen, la tienda y
  el inventario. La UI va en un CanvasLayer con un velo oscuro por delante.
- `scripts/prep_screen.gd` — selección de HASTA 4 recetas (raíz **Node3D**):
  el fondo es el **escenario 3D del nivel elegido** (isla / puerto / barco
  enemigo, o el barco del jugador en Arcade) meciéndose sobre el mar. En
  aventura solo lista las desbloqueadas y ataja las que no tienen usos de
  ingredientes ("Sin ingredientes"); **en Arcade igual** — solo desbloqueadas
  y con despensa, porque el modo cobra por oleada. Recetas **agrupadas por
  nivel de estrellas**, **4 tarjetas por fila** sobre un pergamino compartido.
  Debajo, la fila de **potenciadores permanentes** disponibles (solo aventura),
  y el botón "¡Zarpar!". Arriba, "Atrás" (al mapa en aventura, al menú en
  Arcade). NO lleva el título "Sushi Pirata".
  **LA "SELECCIÓN AUTOMÁTICA" GARANTIZA COBERTURA POR TIPO**
  (`_asegurar_nivel`): su puntuación mide rendimiento MEDIO, y con un solo
  capitán entre ocho bocas ningún plato de 3★ gana nunca el reparto — salía una
  carta entera de 1★ que dejaba al capitán mirando la cinta toda la jornada, y
  que el propio selector regaña por boca de Gigi. Con piratas en la mezcla se
  fuerza un plato de 2★, y con capitanes uno de 3★, cambiando el PEOR principal
  de la carta (nunca el postre ni el picoteo, que están por lo que hacen).
  **CON LA CARTA LLENA, LO QUE NO CABE SE APAGA** (`recipe_cards` +
  `_update_ui`): las no elegidas bajan a opacidad y las elegidas se quedan a
  plena luz, para poder soltar una y cambiarla. Tocar una receta de más nunca
  hizo nada —`_on_recipe_toggled` la devuelve a su sitio— pero no había forma
  de saber por qué: parecía que la tarjeta no respondía. Solo se apuntan en
  `recipe_cards` las ELEGIBLES; las que se quedaron sin ingredientes salen
  antes por su propia rama y ya van marcadas.
- `scenes/*.tscn` — main_menu, level_select3d, shop_screen, inventory_screen,
  level3d, prep_screen, client, plate. (main_menu/level_select3d/shop_screen/
  inventory_screen son raíces vacías: toda su UI se construye por código.)
- **Escenario de isla**: palmera, rocas y cabaña son MODELOS con textura
  (`palmera.glb`, `rocas.glb`, `cabana.glb`), no geometría por código. La
  palmera se intentó montar con cilindros y tablillas y desde la cámara
  isométrica siempre se leía como una estrella plana. El muelle del puerto usa
  `madera_muelle.webp`, distinta y más clara que la cubierta del barco
  (`madera_desgastada.webp`): compartiéndola, los dos escenarios se parecían.
- `assets/` — dishes, characters, ingredients, stages, ui, props, scenery, map
  (`map/`: `mar.png` textura de agua tileable, `barco.png` del jugador estático
  y `barco_anim.webp` su spritesheet 4x4 con las velas al viento, más los nodos
  `isla.png` / `puerto.png` / `barco_enemigo.png`, todos isométricos).
  En `ui/`, el SET DE INTERFAZ (ver las constantes de `prep_board.gd`):
  `boton_madera.png` (el botón de todo el juego), `panel.png` (pergamino
  enmarcado) y `panel_liso.png` (sin marco, para tarjetas pequeñas),
  `cinta_titulo.png` (rótulos de pantalla), `barra_fondo/barra_relleno.png`
  (barras de progreso), `estrella_llena/vacia.png`, `moneda.png`,
  `boton_flecha_izq/der.png` y `slot.png`. Además `libro.png` (el
  recetario y la despensa), `logo_sushi_pirata.webp` y los iconos del menú
  `ic_aventura/ic_arcade/ic_tienda/ic_inventario/ic_opciones/ic_logros.png`
  (los dos últimos son la rueda de timón y la medalla de los botones redondos).
  En `models/`:
  `tendero.glb` (tienda, sin rig) y `ayudante_rig.glb` (potenciador "ayudante",
  rigueado y animado con `CharacterAnim`).
  `art/concepts/` es solo referencia (tiene `.gdignore`).
  `build_perks_ui()` de `tools/ui2_prep.py` saca las dos piezas sueltas de esta
  tanda: `calavera_vacio.png` (el contador de vacíos del puerto) y
  `boton_perk.png` (la chapa de latón), esta última a 330 de ancho como
  `boton_madera` para que su marco caiga en los 36 téxeles del margen.
  Las imágenes de UI generadas con Ludo se recortan con `tools/ui_prep.gd`
  (inundación desde los bordes + recorte + reescalado). Para los ICONOS con
  fondo gris claro la inundación deja halo: se pasan antes por el
  `removeBackground` de Ludo y `ui_prep` solo recorta y reescala.

## EL MAR (`shaders/water_ww.gdshader`)

Agua estilo **Wind Waker**, portada del shader de NekotoArts
("Wind Waker style water - no textures needed", godotshaders.com, a su vez de
shadertoy.com/view/3tKBDz). La montan los TRES sitios con mar: el mapa/menú/
portada (`level_select3d._setup_sea`), los niveles (`level3d._add_sea`) y el
fondo de prep_screen/tienda/inventario (`scene_backdrop`). El
`water_map_3d.gdshader` que había antes (textura de agua + deriva) se retiró.

- **LA ESPUMA VA HORNEADA EN UNA TEXTURA** (`tools/foam_ww.py` →
  `assets/map/espuma_ww.webp`). El original la construye sumando **75 círculos
  POR PÍXEL** y la evalúa DOS veces por fragmento —unas 2.500 operaciones por
  píxel, con el mar cubriendo la pantalla entera—, que en un móvil se lleva el
  fotograma. El dibujo NO depende del tiempo y además TILEA solo (el
  `min(c, 1-c)` del original envuelve la distancia), así que hornearlo da el
  MISMO resultado con dos `texture()`. El fbm del warp baja de 6 octavas a 3.
  MEDIDO con sonda (mapa, 150 fotogramas, vsync fuera): **0,29 ms/fotograma**
  el mar entero contra un material plano.
- **EL RADIO DE LOS CÍRCULOS ES UNA PERILLA DELICADA** (`RADIO_MULT`): el
  dibujo es "todo blanco MENOS los círculos", y están al borde de la
  PERCOLACIÓN, así que un pelo de radio se lleva por delante la mitad del
  blanco. MEDIDO: 1.00 → 15,6% de espuma · 1.05 → 11,4% · 1.12 → 6,5%. Y ahí
  está la gracia: **pasado el punto de rotura la red se parte en manchas
  SUELTAS con mar liso entre ellas**, que es lo que hace que parezca que hay
  poca espuma. A 1.14 las manchas salen sueltas pero finas y a 1.125 sueltas y
  con cuerpo; va a **1.110**, con las vetas ya anchas y alguna volviendo a
  juntarse — el punto en el que hay espuma sin que sea una red.
  Con el 15,6% del original el mar se lee como una rejilla de líneas blancas.
- **LA ESCALA (`tile`) SE MIDE CONTRA ESTA CÁMARA, no contra el mundo**: el
  juego enseña solo **9,5 u de ancho**, así que la espuma al tamaño "de verdad"
  del original salía en manchas de medio palmo y el mar parecía una vaca. Una
  baldosa cada ~4 u en las tres pantallas (mapa 190·1.0, nivel 90, fondos 120;
  el shader multiplica por 0.25 por dentro, como el original). El TAMAÑO de la
  baldosa es lo que SEPARA unas manchas de espuma de otras y el radio lo que
  las ADELGAZA: para "menos espuma" hacen falta las dos cosas.
- **EL OLEAJE ES DESPLAZAMIENTO DE VÉRTICE**: los planos del mar necesitan
  `subdivide_width/depth` (48 el mapa, 36 el nivel, 40 los fondos) o no se
  mueve nada — un PlaneMesh a pelo son dos triángulos.
- **LA MAREA** (`level_select3d.marea()`, uniforme `marea` del shader): en el
  MAPA el mar entero sube y baja muy despacio (24 s de ciclo). Lo que la hace
  creíble no es el agua moviéndose, sino QUIÉN SE MUEVE CON ELLA: las islas,
  los puertos y la cueva NO —el agua les trepa por la roca y les come parte de
  la plataforma—, y lo que flota —el barco del jugador y los barcos enemigos de
  los abordajes— SÍ, porque el mapa les suma la misma altura. Sin esto los
  nodos parecían pegatinas puestas sobre el mar.
  · **SOLO SUBE (0 .. MAREA_AMP), nunca baja del nivel de siempre**: los
    modelos tienen su base a −0.10, así que con marea negativa se quedarían
    flotando con un palmo de aire debajo — justo lo contrario de lo que se
    busca.
  · **Y SUBE POCO** (0.10 u ≈ 7 px). Estuvo en 0.28 y a esa altura la cueva,
    las islas y los puertos salían medio inundados: los modelos del mapa
    asientan su base casi a ras de agua, así que el margen para jugar es de
    centímetros.
  · **LO QUE VA PINTADO SOBRE EL AGUA SUBE CON ELLA**: la línea de puntos de la
    ruta (a 0.025 de altura) y las manchas de sombra de los nodos y del barco
    (a 0.03) están a ras de mar, así que con la marea alta se hundían y **la
    línea de puntos entre escenarios DESAPARECÍA** en cada pleamar. Van con la
    marea, no contra ella: la ruta ya fundida se busca por nombre
    (`RouteBatch*`) después del `GeometryBatch.bake` y se apunta a la lista de
    flotantes, y la mancha del barco lleva la marea en su recolocación por
    fotograma.
  · Los niveles y los fondos no la usan: el uniforme vale 0 si nadie lo toca.
- **SE PROBÓ TAMBIÉN EL "TOON WATER SHADER"** (`shaders/water_toon.gdshader`,
  port del de godotshaders/Erik Roystan Ross, con sus dos ruidos en
  `tools/toon_water_tex.py`). Se queda EN EL BANCO, no en el juego, y por dos
  motivos MEDIDOS:
  · **Cuesta más, no menos**: 0,6–1,4 ms/fotograma contra los 0,29 del Wind
    Waker (misma sonda, mismo mapa). Lee la PROFUNDIDAD de pantalla, que es
    justo lo caro en un móvil.
  · **Y aquí su gracia principal no se ve: este mar NO TIENE FONDO.** El
    shader colorea el agua por lo hondo que esté lo que hay debajo y pinta
    espuma donde algo corta la superficie; sin lecho marino el degradado sale
    plano y la orla de espuma acaba pintando de blanco toda la roca sumergida
    de cada isla.
  Cambiarlo es tocar dos líneas en `_setup_sea` (están comentadas ahí), así
  que el experimento se puede repetir sin rehacer nada.


## Convenciones y decisiones ya tomadas (NO reintroducir bugs resueltos)

- **ÁREA SEGURA (notch del iPhone), solo en el export NATIVO**: la ventana
  nativa ocupa la pantalla entera, muesca incluida (en Safari no pasa: el
  navegador ya vive dentro del área segura). `GameState.safe_top()/safe_bottom()`
  devuelven la franja en píxeles DE LIENZO y cada pantalla baja su barra
  superior con eso (level3d baja TopRow/PhaseLabel/Salir; los menús bajan su
  root entero y estiran el velo hacia arriba). `safe_top()` devuelve 0 fuera
  del export nativo móvil (`OS.has_feature("mobile")`): en escritorio el "área
  segura" es el escritorio menos la barra de tareas y, según dónde estuviera
  la ventana al arrancar, daba una franja falsa (los botones del menú salían
  más abajo solo en el primer arranque). Y **todo lo que cubra la
  pantalla entera bajo un CanvasLayer va a `GameState.canvas_size()`, no a
  720×1280**: en un iPhone el lienzo mide ~720×1560 (aspect expand) y con el
  alto fijo la caja de diálogo flotaba a media cuarta del borde y el paño del
  foco dejaba una franja sin oscurecer abajo (DialogueBox y story_director ya
  están corregidos).
- **MANO DOMINANTE** (`GameState.player_hand`, "L"/"R"; se pregunta en la
  bienvenida de David y se cambia en Opciones → Perfil): con la derecha,
  `prep_board._mirror_layout()` voltea el panel inferior EN ESPEJO al final de
  `_ready` — tabla pegada a la derecha (cerca del pulgar), cajas y columna de
  discos (cancelar/barco/combinar/ayudante) a la izquierda, y el cartel del
  gesto clavado en el borde IZQUIERDO de la tabla con la inclinación espejada
  (`_update_instruction` es side-aware). Solo se recolocan los bloques de
  primer nivel: lo que cuelga de ellos (ingredientes, extras, TapZone, etapa)
  va dentro, y los guiones enfocan POR NODO, así que el foco del tutorial cae
  bien sin tocar nada. Los guardados viejos quedan en "L" (la mesa de siempre).
  **El ARTE de la tabla también se voltea** (textura `flip_x` en
  `_mirror_layout`): su marco de madera solo está dibujado en el lado derecho
  —el izquierdo nace sangrado fuera de pantalla— y en espejo el lado visible
  quedaba a corte vivo. La elección se hace TOCANDO UNA MANO CON CUCHILLO
  (`assets/ui/ic_mano_izq.png` y su espejo exacto `ic_mano_der.png`, una es
  el `flip` de la otra para que sean idénticas), con el rótulo
  **"Zurda"/"Diestra"** bajo cada dibujo (solo con el dibujo había que pararse
  a pensar cuál era cuál), tanto en la bienvenida de David como en el Perfil. **La generada por Ludo es la mano
  IZQUIERDA**, no la derecha: se asignaron al revés y hubo que
  intercambiarlas. Si se regeneran, comprobar el dibujo antes de nombrarlas.
- **EN EL MÓVIL, LA INTERFAZ DE GODOT NO RESPONDE AL DEDO COMO EN EL RATÓN.**
  Dos cosas medidas, no supuestas (inyectando `InputEventScreenTouch` +
  `ScreenDrag` con `Input.parse_input_event`):
  1) El `ScrollContainer` **no se arrastra con el dedo**: el selector de recetas
  se quedaba en `scroll_vertical = 0` con 1.842 px de contenido. Para eso está
  `scripts/touch_scroll.gd` (`TouchScroll.attach(scroll)`), que además le da
  INERCIA. Ya lo usan el selector de recetas, los logros y el inventario; el
  panel de resultados del nivel tiene su propio apaño anterior (mueve el scroll
  desde el `gui_input` del pergamino ENTERO, que ahí interesa más).
  2) El `LineEdit` **no saca el teclado** porque no llega a coger el foco al
  tocarlo: `PrepBoard.enable_mobile_keyboard(edit)` le da el foco a mano y pide
  el teclado con `DisplayServer.virtual_keyboard_show`. Lo usan el nombre de
  Opciones y el buscador del recetario.
  Los dos ayudantes escuchan en **`_input`** (antes que la interfaz) y se
  tragan el toque de SOLTAR cuando ha habido gesto: si no, al deslizar sobre
  una tarjeta de receta se acababa seleccionando. Con un toque limpio (menos de
  `DEADZONE` px) el botón de debajo sigue funcionando: comprobado.
- **Gestos táctiles del juego**: `scripts/swipe_pages.gd` pasa página en los
  libros del inventario deslizando (derecha→izquierda, siguiente) y el mapa de
  aventura tiene inercia propia en `level_select3d` (`scroll_speed`). En los
  dos sitios y en `TouchScroll`, la velocidad **NO se borra mientras el dedo
  está apoyado**: hacerlo dejaba la inercia siempre a cero, porque `_process`
  la limpiaba antes de que llegara el evento de soltar.
- **Margen de toque en la mesa de elaboración** (`prep_board.TOUCH_PAD`, 22 px):
  ingredientes, platos y el sprite de etapa se tocan con un colchón alrededor,
  porque el dedo tapa justo lo que señala. En los pasos de ELECCIÓN, donde los
  márgenes de dos ingredientes se solapan, gana el de centro más cercano
  (`_nearest_ingredient`), no el primero de la lista.
- **Assets 2D**: se generan con **Ludo MCP** (ya en estilo **Low Poly**, no
  Voxel Art), se descargan de inmediato (las URLs caducan a 7 días), y se
  recortan con un script Godot midiendo el bounding box con **umbral de
  alfa ≥ 0.6–0.75** (el recorte por `get_used_rect` incluía la sombra y rompía
  los 9-slice). Los sprites se guardan como `.png`; los platos como `.webp`.
  Fondo blanco → transparente por INUNDACIÓN desde los bordes (así el arroz
  blanco interior sobrevive): `tools/icon_prep.gd` y `tools/stage_prep.gd`.
- **Restilizar sprites con `editImage`** (voxel → low poly): funciona con el
  sujeto DESCRITO explícitamente en el prompt; el arroz blanco vuelve a salir
  voxel salvo que se le pase una `reference_image` de arroz low poly, PERO una
  referencia con pez acaba SUSTITUYENDO el sujeto entero (14 sprites salieron
  convertidos en el nigiri de referencia). Referencias solo sin pez.
- **Etapas ENCADENADAS del mismo sujeto** (fugu antes/después del corte, la
  gamba a lo largo de la tempura): dos vías, y las dos hacen falta.
  1) *Dos composiciones en UNA imagen*: hay que pedir explícitamente **"dos
  tablas separadas, cada una completa, con hueco blanco entre ellas"**; con
  "una imagen con los dos pasos" salía UNA sola tabla larga partida por la
  mitad, que no es nada. Y hay que prohibir el cambio de sujeto: pedir "lomo
  rectangular sin espinas, NADA de pez entero, sin cabeza, sin aletas, sin
  escamas", porque a la mínima el lado derecho se convertía en un pescado
  completo en vez del mismo lomo cortado. Se parte por el **hueco vacío más
  ancho entre el 25% y el 75%** del ancho (barrido de columnas por alfa), no
  por un porcentaje fijo.
  2) *`editImage` sobre la etapa anterior*: es lo que garantiza la continuidad
  real (la gamba enharinada salió de la gamba pelada, misma silueta). Para
  quitar partes hay que enumerarlas una a una ("borra cabeza, ojos, antenas,
  bigotes y TODAS las patas"): `createImage` dibujaba la gamba con cabeza por
  mucho "peeled, no head" que llevara el prompt.
- **La VARIANTE de un personaje sale del concepto del original, no de un
  prompt nuevo.** Las clientas femeninas se pidieron por texto describiendo el
  estilo ("low poly, facetado, proporciones normales") y salieron igualmente
  con **la cabeza el doble de grande, los ojos enormes y el sombreado blando**:
  un personaje chibi al lado de uno esbelto. Por mucho que el prompt diga
  "nada chibi", `createImage` no tiene de dónde copiar las proporciones. Lo que
  sí funciona es `editImage` **sobre el concepto del original**
  (`assets/models/source/*.webp`) pidiendo SOLO lo que cambia (pelo largo,
  facciones) y enumerando lo que NO puede cambiar: misma altura, misma cabeza
  pequeña, mismas piernas largas, misma ropa, mismo facetado, mismo encuadre.
  Así la pareja se lee como dos versiones del mismo personaje.
  **Ojo con el moderador**: "convierte a este niño en una niña" salta como
  contenido marcado; hay que pedirlo como asset — "produce the FEMALE VARIANT
  of this character design, as a matching pair for a roster".
- **Modelos 3D (imagen→3D)**: concepto low poly generado DESDE TEXTO (el
  restilizado de un sprite voxel se queda a medias), con el objeto flotando en
  fondo VACÍO sin sombra (una sombra pintada acaba convertida en malla pegada
  al pie, como le pasó al chef); `create3DModel` → `tools/glb_prepare.py`
  (gunzip + baseColorFactor 1 + metallic 0; con `--headless` puede dar timeout
  el MCP: recuperar con `get3DModelResults`).
- **RIGUEAR (`rigModel`): la vía fiable es la URL PÚBLICA.** El `.bin` de
  `get3DModelResults` viene GZIPEADO y el rigger contesta 500 ("AI server
  error"), así que durante un tiempo hubo que repetir la generación hasta que
  `create3DModel` contestara en directo. **Ya no**: se prepara el `.glb` en
  local con `tools/glb_prepare.py` (que descomprime), se sube a la rama
  `tmp-rig` del repositorio y se le pasa a `rigModel` la URL `raw.
  githubusercontent.com`. Así da igual que la llamada expire, y el modelo puede
  venir de donde sea. Con ese camino entraron 11 rigueados seguidos.
- **Los dos `rig_type` fallan de manera DISTINTA, y por eso se prueban los dos.**
  `humanoid` da un esqueleto a medida (35-50 huesos, con dedos) pero a veces
  **se deja una pierna entera sin huesos**; `humanoid_template_hands` (52 huesos
  fijos) siempre trae las dos piernas, pero a veces sale con **los brazos
  colapsados** —hombro, codo y muñeca amontonados en el pecho a 4 mm unos de
  otros—. Cuando uno falle, probar el otro ANTES de regenerar el modelo: a la
  grumete y a la ayudante femeninas les faltaba una pierna con `humanoid` y las
  dos entraron a la primera con la plantilla.
- **LAS PIERNAS CORTAS NO SE ANIMAN** (`CharacterAnim.legs_ok`,
  `MIN_LEG_FRAC` 0.32): unas piernas sanas miden el 43-55% del alto, y por
  debajo del listón las rotaciones del andar y del sentado — pensadas para ese
  largo — arrastran media carne del cuerpo. El Kappa VIEJO (27%) salía con una
  cuña verde enorme detrás, andando Y sentado. Un rig así conserva sus piernas
  como se modelaron (anda a bandazos con el vaivén del cuerpo, `sit()` solo
  inclina el tronco y `sit_offset` devuelve 0). El Kappa nuevo (50.6%) ya no
  la necesita, pero la regla se queda: es el gemelo de `has_usable_arms`.
- **Un rig se da por bueno MIDIÉNDOLO, no mirando si tiene huesos.** Un
  esqueleto con los brazos amontonados pasa el `has_humanoid_bones()` y luego
  gira la carne del brazo alrededor de un punto del torso: el personaje agita
  los brazos de forma imposible. La medida buena es el **largo de cada miembro
  en fracciones del alto del personaje**: brazos sanos 25-35%, piernas 43-55%;
  los fallidos salen al 1-4%. `CharacterAnim.has_usable_arms()` lo comprueba
  solo y, si no cuadra, deja los brazos como se modelaron en vez de animarlos.
  **Y OJO: el AABB de una malla con esqueleto NO refleja la pose** — Godot
  devuelve el del bind, así que medir siluetas con `get_aabb()` da conclusiones
  falsas (pasó: se dio por abierto un chef que estaba bien). Medir por
  `get_bone_global_rest()`.
- **El concepto manda en si el rig va a salir bien**: las piernas tienen que
  verse **SEPARADAS, con un hueco de fondo entre ellas hasta la cadera**, y
  nada largo colgando por delante. Un **delantal largo** (o falda, o levita
  hasta la rodilla) tapa las piernas y el rigueador las funde en una: es lo que
  tuvo al ayudante sin animar durante seis intentos, y lo mismo pasó antes con
  unos pantalones anchos. Pedir "delantal CORTO, que acaba en la cintura" y
  "de pie con los pies separados a la anchura de los hombros".
- **Texturas de modelo (export web/móvil)**: `compress/mode=4` (**Basis
  Universal**, transcodifica al GPU en carga; ¡el modo 3 NO es Basis, es VRAM
  sin comprimir!) + `rdo_quality_loss=4` + `process/size_limit` 512 en
  personajes/mapa y 256 en platos/atrezzo. Sin Basis el export solo lleva
  s3tc y en navegadores móviles las texturas 3D no cargan. Los sprites 2D del
  juego de referencia van en `exclude_filter` del preset de export.
  **Al añadir un modelo nuevo hay que aplicárselo**: Godot lo importa con
  `compress/mode=2` (s3tc) y `size_limit=0`. Ya pasó: `cabana`, `palmera`,
  `rocas`, `caja` y `cofre` se quedaron en s3tc y hubo que corregirlas después.
  Lo hace `python tools/fix_texture_imports.py` (con `--check` audita sin tocar
  nada). **El límite YA PUESTO no se pisa**: solo rellena los que están a 0,
  porque hay piezas afinadas a mano —la cabaña y las rocas van a 512 aunque
  sean atrezzo— y una regla general se las bajó a la mitad sin querer.
  Un `.glb` nuevo trae además `generate_lods=true`, `create_shadow_meshes=true`
  e `import_script/path=""` en su `.import`: los tres hay que corregirlos a
  mano (los dos primeros a `false`, el tercero al hook de decimado) y añadir la
  línea del presupuesto en `import_hooks/decimate_import.gd`.
  `import_hooks/` (el post-import de decimado) va en `exclude_filter` del preset
  de export: extiende `EditorScenePostImport`, que no existe fuera del editor.

## Exportar a Android (montado el 9-8-2026)

El `.apk` sale del preset **"Android"** de `export_presets.cfg`, en formato APK
(`gradle_build/export_format=0`; el 1 es AAB, que solo sirve para Play Store) y
con las arquitecturas `arm64-v8a` y `armeabi-v7a`. Paquete
`com.kopurista.sushipirata`, salida en `sushiBeta/android/` (ignorado por git).

    "…/Godot_v4.7.1-stable_win64_console.exe" --headless --path . \
        --export-debug "Android" "sushiBeta/android/SushiPirata.apk"

Lo que hizo falta instalar, porque NADA de esto venía puesto:
- **JDK 17** (`C:/Program Files/Eclipse Adoptium/jdk-17.0.20.8-hotspot`). El
  sistema traía el **8**, y el `apksigner` de las build-tools modernas necesita
  Java 11 o superior. Va en `export/android/java_sdk_path` de los ajustes DEL
  EDITOR (`%APPDATA%\Godot\editor_settings-4.7.tres`), no del proyecto.
- **`cmdline-tools` del SDK** (no estaban; sin ellas no se puede actualizar
  nada) y después `build-tools;36.0.0` + `platforms;android-36`, porque lo
  instalado era de 2019 (build-tools 29.0.1 / android-29).
- **Las plantillas de Android** (`android_debug.apk`, `android_release.apk`,
  `android_source.zip`, 426 MB). **El juego de plantillas instalado solo traía
  web y Windows**: hubo que bajar el `.tpz` oficial entero (1,2 GB) de
  `godot-builds` y extraer las tres.
- **El keystore de depuración**: Godot apuntaba a
  `AppData/Roaming/Godot/keystores/debug.keystore`, que NO existe. El bueno es
  el `~/.android/debug.keystore` de siempre.
- **`textures/vram_compression/import_etc2_astc=true`** en `project.godot`:
  Godot se niega a exportar a Android sin él. Es un ajuste GLOBAL, así que
  afecta también a la web — medido: el `.pck` web pasó de 31,88 a 32,34 MB
  (+0,46), porque no queda ninguna textura en VRAM comprimida (todas están en
  Basis o en WebP con pérdida).
- **CERRAR EL EDITOR ANTES DE TOCAR `editor_settings-*.tres` o
  `export_presets.cfg`**: Godot los reescribe al guardar y se lleva por delante
  lo editado a mano. Ya pasó dos veces en la misma sesión.

Instalar en un móvil (no hay caducidad ni cuenta de pago, al contrario que iOS):

    "…/platform-tools/adb.exe" install -r sushiBeta/android/SushiPirata.apk

## Rendimiento en móvil (medido, no a ojo)

Para medirlo se inyecta un helper que imprime
`RenderingServer.get_rendering_info(...)` por escena. Dos trampas al medir:
el frame sale clavado a 16,67 ms si no se quitan **`Engine.max_fps = 0` Y
`DisplayServer.window_set_vsync_mode(VSYNC_DISABLED)`**, y el nivel recién
arrancado está en fase de preparación **sin un solo cliente**, así que hay que
forzar el peor caso (`prep_phase = false`, llenar asientos, servir platos) o se
mide una escena vacía. Y conviene contar los triángulos INSTANCIADOS recorriendo
el árbol, no solo los dibujados: el culling esconde media cubierta y hace creer
que no hay problema.

- **Presupuesto de triángulos por modelo** (`import_hooks/decimate_import.gd`):
  los `.glb` vienen de imagen→3D con una densidad que no tiene nada que ver con
  su tamaño en pantalla. Medido: `caja.glb` traía **19.592 triángulos por caja**
  (tres cajas = 34% del nivel entero), `cofre.glb` 19.073, y
  `futomaki_salmon`/`gunkan_tartar` 29.500 cuando los otros diez platos rondan
  los 2.400. El script es un **post-import** (`import_script/path` en el
  `.import`): decima en la importación, así las rutas `.glb` del juego no
  cambian en ningún sitio y el original se conserva en el repositorio. Para
  añadir un modelo: una línea en `BUDGETS` y `import_script/path` en su
  `.import`. Resultado: 335.538 → 128.582 triángulos en disco; el mapa pasó de
  315.747 a 85.977 instanciados y la tienda de 51.386 a 9.610 dibujados.
  **El LOD automático NO sirve**: aunque `generate_lods` estuviera activo, bajo
  GL Compatibility no se aplica (medido: 50.812 instanciados / 51.386 dibujados
  en la tienda, o sea el modelo entero a plena densidad aunque se vea pequeño).
  Por eso `generate_lods=false` en los 29 `.import`: guardarlos solo engordaba
  el `.pck` y la VRAM. Lo que sí funciona es el simplificador de meshoptimizer
  que Godot lleva dentro, expuesto en `ImporterMesh.generate_lods()`, generando
  la cadena y **sustituyendo la malla** por el escalón que entra en presupuesto.
  Dos detalles que costaron tiempo: en 4.7 el `_post_import` recibe la escena
  **ya convertida** (`MeshInstance3D` con `ArrayMesh`, NO
  `ImporterMeshInstance3D`, aunque la documentación sugiera lo contrario), y
  `ImporterMesh.from_mesh()` no rellena nada — hay que poblarla superficie a
  superficie con `add_surface()`. El simplificador tiene **suelo propio**: para
  cuando una pasada no logra recortar ~25%, así que algunos modelos no llegan a
  su tope (`map_enemigo` se queda en 16.410 con tope 4.000) y los ángulos de
  fusión de normales NO cambian nada (probados 25/60 hasta 180/180).
- **Los sprites 2D van en WebP con pérdida (`compress/mode=1`, calidad 0.9),
  NO en `Lossless`.** Godot importa por defecto en modo 0 (sin pérdida), que es
  el más caro que existe: 249 texturas del juego estaban así y solo `stages`
  ocupaba 18,6 MB. Pasarlas a modo 1 dejó ese grupo en 3,3 MB (−82%) y el
  paquete web entero de 107,4 a 70,0 MB. **Medido, no supuesto**: comparando
  píxel a píxel el original contra el importado sobre los píxeles VISIBLES
  (alfa > 0.1; promediar el lienzo entero maquilla el resultado porque casi
  todo es transparente), la diferencia media es del **0,84-1,25% según el
  grupo**, imperceptible incluso en los retratos 2D a pantalla completa.
  **`assets/ui` se queda en Lossless a propósito**: son los 9-slice de madera y
  pergamino, cuyo borde tiene que ser OPACO (ver `solidify` en `ui2_prep.py`),
  y comprimir con pérdida el alfa de una banda que se estira es justo el bug de
  la franja translúcida que ya costó encontrar. Son 3,6 MB: no compensa.
- **Al cambiar `compress/mode` de una textura, su UID CAMBIA** y las escenas que
  la referencian se quedan con el viejo: salen avisos `invalid UID … using text
  path instead`. Funciona (Godot cae al path de texto) pero es el estado que
  precedió al crash de los `.glb`. Se arregla copiando el `uid` del `.import` al
  `ext_resource` de la escena. Pasó con `tabla_cortar.png` y
  `cinta_trad_banda.png` en `level3d.tscn`.
- **`create_shadow_meshes=false` en los 29 modelos**: generaba una copia extra
  de cada malla para un pase de sombras que no existe (no hay sombras
  proyectadas en el juego). Verificado: 0 de 29 mallas llevan ya malla de sombra.
  **`ensure_tangents=false` en cambio NO sirve de nada aquí**: solo evita
  GENERARLAS cuando faltan, y estos `.glb` ya las traen de origen. Se intentó
  quitarlas poniendo `arrays[Mesh.ARRAY_TANGENT] = null` antes de
  `add_surface_from_arrays` y **Godot las vuelve a poner** (el formato sale
  idéntico). No insistir: la única vía sería regenerar los `.glb` de origen.
- **EL PRESUPUESTO DE DECIMADO NO SE BAJA A OJO: hay que MIRAR el modelo.** Los
  nodos del mapa estaban a 4.000 y el simplificador no los suavizaba, los
  DESTROZABA: fundía vértices de islas UV distintas, así que `map_puerto` salía
  con rayas rojas del faro esparcidas por la roca gris, y encima había perdido
  enteros un pantalán y sus cajas. A 8.000 (la cadena de LOD cae en ~7.700) se
  ve igual que sin decimar. Cuesta ~20.000 triángulos más en el mapa (86k →
  105k), y aun así el grueso sigue siendo `map_enemigo`, que se planta en
  16.410 porque el simplificador tiene suelo propio. **Al tocar un presupuesto,
  renderizar el modelo antes y después**: el recuento de triángulos no dice
  nada de si la textura ha reventado.
- **MANCHAS PINTADAS EN EL ATLAS de un modelo** (`tools/atlas_fix.py`): los
  modelos de imagen→3D traen la textura PROYECTADA del concepto, así que las
  sombras del dibujo quedan pintadas sobre la pieza. Las velas del barco del
  mapa salían con un borrón. Dos cosas distintas se juntaban ahí:
  1) **Sangrado de MIPMAP**: en el atlas las velas son islas claras pegadas a
  madera oscura, y al reducirse la textura el blanco promedia con el marrón de
  al lado y ennegrece el borde de la vela. Se arregla con
  `mipmaps/generate=false` en esa textura (el barco se ve siempre a un tamaño
  parecido, así que no se pierde nada). **No era la compresión ni el decimado**:
  comprobado a 1024 sin comprimir y sin decimar, la mancha seguía igual.
  2) **Motas pintadas de verdad** dentro de las velas, que quita `atlas_fix.py`
  mirando la GEOMETRÍA: recorre los triángulos del `.glb`, se queda con los que
  caen sobre texels claros y repinta lo oscuro solo dentro de ellos, así que no
  puede desbordarse a la madera vecina. Se probaron antes un cierre morfológico
  (con radio suficiente SALTA a la isla de al lado y pinta la madera de blanco)
  y un relleno de huecos por topología (seguro, pero se deja las manchas que
  tocan el borde de su isla); la herramienta acabó haciendo las dos cosas.
- **LA MANCHA NEGRA DE LA VELA DEL MENÚ NO ERA DEL BARCO: era su SOMBRA.**
  `ship_blob` es un plano horizontal a ras de agua, y con la cámara isométrica
  lo que está BAJO y CERCA gana en profundidad a lo que está ALTO y AL FONDO:
  con la mancha a la medida del casco, su esquina cercana pasaba por delante de
  las velas y se veía un borrón oscuro sobre la vela de arriba (en el menú,
  con el barco a escala 2.3, cantaba). Por eso la mancha es MÁS PEQUEÑA que la
  huella del barco y va desplazada en -x/-z. **Se perdió un buen rato
  repintando el atlas antes de dar con esto**: el modelo aislado siempre salía
  limpio, que era la pista. Cuando algo solo falla dentro de una escena,
  sospechar de lo que la escena añade, no del modelo.
- **Geometría estática fusionada** (`scripts/geometry_batch.gd`): el escenario
  se construye con ~130 cajas sueltas y cada una era un draw call (dos con el
  pase de sombra). `GeometryBatch.bake(self)` las funde **agrupando por color**
  al final de la construcción. Nivel: 269 → 116 draw calls. Mapa: 160 → 96.
  **NO usar color por vértice**: `vertex_color_use_as_albedo` no funciona bajo
  GL Compatibility (el renderer del juego) y el escenario entero sale lavado —
  la cubierta de tablones se volvía un arenal beige. Por eso se agrupa por
  color y se reutiliza el material original, que además garantiza que el
  resultado es idéntico. Quedan fuera del fusionado los materiales con shader
  (la banda de la cinta) y lo que esté en el grupo `no_batch`.
  **Ojo con la escala**: todo lo que fusiona `GeometryBatch` suma ~8.000
  triángulos en el nivel; el 95% de la geometría son los `.glb`. El fusionado
  arregla los DRAW CALLS, no el triangulaje — para eso está el presupuesto por
  modelo de arriba. No confundir los dos problemas.
- **NO hay sombras proyectadas en todo el juego**: `sun.shadow_enabled = false`
  en las cuatro escenas 3D. En su lugar, cada cosa lleva su MANCHA fija
  (`SceneBackdrop.blob_shadow`): chef, ayudante, clientes (cuelga del propio
  cliente y le sigue), palmeras, mostrador, barco del mapa y del menú. Con
  personajes que se mecen la sombra dinámica bailaba y mostraba acné, y el
  pase de sombras costaba tanto como dibujar la escena otra vez.
- **30 fps en los menús** (`MENU_FPS`), 60 solo jugando (`GAME_FPS` en
  `level3d`). `Engine.max_fps` es global: cada pantalla fija el suyo al entrar.
  En un móvil de 120 Hz esto es la diferencia más grande en batería.
- **project.godot**: `run/max_fps=60`, mapa de sombras 2048 (1024 en móvil),
  sin filtro anisotrópico, sin MSAA ni AA de pantalla.
- **`assets/models/source/` y `snapshots/` llevan `.gdignore`**: son los
  conceptos 1024×1024 con los que se generaron los modelos y las capturas que
  devuelve Ludo. No se usan en el juego (solo `tools/icon_prep.gd`, que lee del
  disco y sigue funcionando) y engordaban el export.
- **UI de madera/pergamino**: 9-slice con `NinePatchRect` (no `StyleBoxTexture`,
  que ignoraba los márgenes). `prep_board.make_nine_patch()` y `skin_button()`.
- **EL SET DE INTERFAZ ENTERO SE DEFINE EN `prep_board.gd`**, en constantes, y
  nadie debe escribir la ruta ni el margen a mano: `BUTTON_TEX/BUTTON_MARGIN`
  (44), `PANEL_TEX/PANEL_MARGIN` (54), `CARD_TEX/CARD_MARGIN` (22),
  `RIBBON_TEX/RIBBON_MARGIN` (76) y `BAR_BG_TEX/BAR_FILL_TEX/BAR_CAP` (52).
  Estilo: cartoon vectorial, madera cálida redondeada con contorno marrón
  grueso, pergamino crema y oro SOLO como acento (nada de calaveras ni cañones
  de adorno). Se generan con Ludo y se procesan con `tools/ui2_prep.py`.
- **EL MARGEN 9-SLICE NO ES LIBRE: TIENE QUE SER ≥ EL GROSOR DEL MARCO.** Godot
  dibuja la esquina a `patch_margin` **PÍXELES DE TEXTURA, sin escalar el
  arte**; si el margen se queda corto, la madera sobrante cae en la banda que
  se estira y se derrama hacia dentro del panel. Corolario que cuesta ver: **el
  ancho al que se exporta la textura es lo que decide el margen**, no al revés
  (el pergamino se exporta a 300 px justamente para que su marco mida 50).
  Antes había un número suelto por pantalla (de 34 a 60) y con el marco nuevo
  los de 34 salían derramados; por eso ahora hay UNA constante.
- **Y EL BORDE DE LA TEXTURA TIENE QUE SER OPACO** (`solidify` en
  `ui2_prep.py`): el 9-slice estira la banda del borde a lo largo de todo el
  canto, así que el antialias del dibujo original (que bajaba a alfa 145) se
  convertía en una **franja translúcida a lo ancho del panel** — era la
  "transparencia en la parte de arriba" del tablón de diálogo.
- **Pergamino LISO (`panel_liso.png`) para las tarjetas pequeñas**: en un botón
  de receta de 172×144 el marco de 54 px no deja interior donde enseñar el
  plato. Sale del interior del propio pergamino, así que es el mismo papel.
- **Rótulo de pantalla = `prep_board.make_title()`**: el texto sobre una CINTA
  de tela roja. La cinta se estira **solo a lo ancho** (márgenes verticales a
  cero): las dos colas del lazo cuelgan por debajo de la banda y con un
  9-slice vertical se leían como un trapo. Su Label se llama `TitleText`, para
  los rótulos que se reescriben en marcha.
- **Cartel con CINTA CABALGANDO sobre el canto = `add_panel_banner()`**: es lo
  que convierte un pergamino en un cartel de "Fin del turno" o "¿Salir del
  nivel?". El parámetro `vuelo` (cuánto sobresale por cada lado) va a **0 en
  paneles casi tan anchos como la pantalla**, o las colas se salen del móvil.
- **BOTONES CON EL ICONO DIBUJADO EN LA MADERA**: `make_back_button()` (flecha),
  `skin_action_button(ok)` (visto verde / aspa roja) y `skin_start_button()`
  (placa de oro de "¡Zarpar!"). El icono es parte de la TEXTURA, no un carácter
  `✔`/`✘` delante del texto como antes.
  **REGLA QUE LOS GOBIERNA: la textura se exporta a la ALTURA EXACTA a la que
  se dibuja** (`ICON_BTN_H` 64) y va con **margen vertical CERO**. Los márgenes
  9-slice son téxeles dibujados 1:1, así que una textura de 230 px de alto en
  un botón de 64 aplasta el icono. Por eso `tools/ui2_prep.py` los saca con
  `fit_height`, no con `fit_width`.
- **Barras de progreso = `prep_board.make_bar_box()`** (canal de madera +
  relleno), 9-slice **solo horizontal**: en una cápsula los topes redondos
  miden media altura, así que un margen vertical igual al tope dejaría la banda
  central en 0 px de alto. **La barra se DIBUJA por código** (`build_bar` en
  `ui2_prep.py`, supermuestreada a 8x), no se genera con Ludo: la generada era
  de 512×103 estirada a 464×24 y los topes se aplastaban a elipses — se veía
  sucia justo al elaborar una receta. Si cambia el alto de `TapBar`, hay que
  cambiar `BAR_H` con él.
- **Tablilla del nombre en el diálogo** (`PLATE_TEX`): se estira solo a lo
  ancho y **su ancho se MIDE sobre el nombre** (`DialogueBox._plate_width`, con
  la fuente y el cuerpo reales). Con ancho fijo, "Gigi" nadaba en madera.
  La MISMA tablilla es el cartel de la cuenta atrás del nivel
  (`level3d._setup_phase_sign`), meciéndose de lado a lado.
- **`set_anchors_preset` NO toca los offsets.** Al REPARENTAR un nodo que viene
  de la escena (la etiqueta de la cuenta atrás, las del dinero y el bote) hay
  que usar **`set_anchors_and_offsets_preset`**: si no, conserva los suyos
  (60/120/660/175) y el texto se dibuja fuera de su nuevo padre — el cartel
  salía en blanco.
- **Botón PEQUEÑO = `skin_small_button()`** con su propia textura
  (`boton_madera_bajo.png`, 46 px de alto, 9-slice solo horizontal). `skin_button`
  encoge el margen en los botones bajos (`min(lado)*0.44`) y a 46 px caía a 20
  téxeles, partiendo por la mitad un tope redondo que mide 44: el "Salir" del
  nivel salía como un recuadro raro.
- **Apagar un botón = `set_dimmed()`** (opacidad), no aclarar la letra: sobre la
  placa de oro de "¡Zarpar!" el texto claro era ilegible.
- **Marcador de la partida: DOS BARRAS**, oro (verde) y propinas (azul), con la
  cifra SUPERPUESTA. Cada barra tiene SU textura a SU altura (32 y 20) porque
  el tope redondo mide media altura; ver `_setup_money_bars`.
  **DOS CIFRAS POR BARRA, no un "0 / 40"** (`_place_bar_value`): el OBJETIVO se
  queda clavado al extremo derecho, y la cifra que sube VIAJA con el relleno —
  arranca pegada al principio y se mantiene en la punta, que es donde el
  jugador está mirando. Al llenarse la barra la móvil se oculta y la de la
  derecha pasa a enseñar **lo conseguido**, no la meta: pasado el umbral,
  repetir el objetivo escondía que se había cerrado con más. Lleva un contorno
  más grueso (10) porque acaba sola sobre el relleno. Dos topes al colocar la
  móvil: por la izquierda para que no se salga del canto sin relleno, y por la
  derecha para que no se monte sobre la cifra de la meta.
  **LAS SEPARACIONES DE LA BARRA DEL ORO SON LAS ESTRELLAS DEL JUEGO**
  (`estrella_vacia/llena.png`, las mismas del cartel de resultados), una por
  umbral: nacen apagadas y **al alcanzar su oro se rellenan y BRILLAN**
  —fogonazo más bote elástico, en `_light_star_mark`—, porque cruzar un umbral
  es la noticia del turno. Se apagan también si el oro baja (castigos), pero
  sin bote: perder una estrella no se celebra. Fueron unas muescas "/"
  dibujadas; con la estrella de verdad el jugador ve DE QUÉ va cada tramo sin
  que nadie se lo cuente.
  · **EL BOTE VA EN SU PROPIO TWEEN Y EN SECUENCIA**, nunca en paralelo con un
    retardo. Con `set_parallel` los dos tramos de `scale` arrancan a la vez y
    el segundo **captura su valor de partida al empezar el paso, no al vencer
    su retardo**: interpolaba de 1 a 1, mandaba el primero y la estrella se
    QUEDABA AGRANDADA para siempre. El fogonazo va en otro tween aparte, que
    así corre a la vez sin tener que mezclarlos. Además se MATA el bote
    anterior antes de lanzar otro, o uno a medias deja la estrella de otro
    tamaño. Medido fotograma a fotograma: sube a 1.59, rebota a 0.79 y vuelve
    a 1.0000 clavado.
  · La **apagada se ACLARA, no se atenúa**: `estrella_vacia.png` ya es marrón
    oscuro (111/76/38) y bajándole el brillo se hundía en el canal de la
    barra, como un agujero. El `modulate` por encima de 1 MULTIPLICA, así que
    sube el brillo en vez de teñir.
  · **CADA ESTRELLA VA EN SU FRACCIÓN EXACTA y la cifra que sube va CENTRADA
    en la punta del relleno** (solo en esta barra; en el bote sigue arrastrada
    por detrás, que allí no hay estrellas). Es lo único que cumple las tres
    condiciones a la vez: el verde llega a la estrella JUSTO al ganarla y ni
    un pixel antes, y el número aterriza clavado en su centro —centro del
    número = punta = centro de la estrella—. Se probó lo contrario, correr las
    estrellas a la izquierda para cuadrar el número dejándolo arrastrado, y es
    peor: el verde se pasaba de largo antes de haberse ganado la estrella.
    Por eso la móvil **no se acota por la derecha**: tiene que poder llegar
    hasta el final, que es donde está la tercera. Y va la ÚLTIMA del árbol,
    para dibujarse por encima de las estrellas en ese tramo final.
  · **La TERCERA es la meta y va aparte**: **centrada en el final de la
    barra** —medio cuerpo por fuera— y con el oro que cuesta **escrito
    DENTRO**. Solo un pelo mayor que las otras dos (`STAR_GOAL_H` 1.62), lo
    justo para que quepa esa cifra; con 2.1 se comía la fila. Por eso el
    objetivo ya no vive pegado al canto: se coloca a mano encima de esa
    estrella. **Su cuerpo de letra es FIJO** (`STAR_GOAL_FONT`) y quien da de
    sí es la ESTRELLA si el número no cabe (`_goal_star_side`, contra el hueco
    útil `STAR_GOAL_TEXT` — una estrella tiene las puntas fuera y solo el
    centro sirve de papel). Al revés —remidiendo el cuerpo— el mismo número se
    leía de un tamaño en un nivel y de otro en el siguiente. La estrella se
    dimensiona contra el OBJETIVO, no contra lo que la etiqueta lleve puesto:
    al llenarse la barra pasa a enseñar lo conseguido, y midiendo con eso
    daría un salto de tamaño al cerrar el turno.
  · La barra va **sin `clip_contents`**: las estrellas cabalgan el canal a
    propósito y recortándolas se les comía las puntas.
  · El tope derecho de la cifra móvil sale de esa estrella final, no de un
    número a mano: las dos se apartan a la vez y nunca se montan.
  **La barra del oro es más LARGA que la del bote** (266 vs 178): es la que
  tiene que dar cabida a objetivos de tres y cuatro cifras sin que las tres
  estrellas se amontonen. Más de eso no cabe: con el reloj visible
  (abordajes) la fila de arriba se queda sin hueco.
  **La del oro va PARTIDA EN TRES TRAMOS** (`_mark_star_steps`), con una muesca
  en el umbral de 1 y de 2 estrellas: así se ve cuánto falta para la SIGUIENTE
  estrella y no solo cuánto llevas del total. Las muescas van por ANCLA
  (fracción del ancho) y en color CREMA, no marrón: tienen que verse sobre los
  dos fondos por los que pasan —el relleno verde y el canal oscuro— y un tono
  oscuro se perdía entero en la parte vacía. Se colocan al final de `_ready`,
  no en `_setup_money_bars`: los umbrales salen del puerto y aún no están
  puestos cuando se visten los paneles.
- **El icono y la barra van en `SIZE_SHRINK_CENTER` vertical** (`_with_icon`):
  un HBoxContainer estira a sus hijos al alto de la fila, así que la barra de
  32 se estiraba al alto de la moneda (44) —deformando una textura que solo se
  puede estirar a lo ancho— y las dos quedaban descuadradas.
- **Contadores de recurso** (`make_resource_box`): dinero y ARROZ, con el icono
  cabalgando sobre el borde izquierdo. **La MISMA caja en todas las pantallas
  donde hay dinero** (menú, mapa de aventura y tienda).
  **Y en el menú/mapa son LITERALMENTE los mismos dos nodos**: no se ocultan al
  entrar en Aventura, VIAJAN (`main_menu._place_resources`) del centro a los
  extremos —dinero a la izquierda, arroz a la derecha— dejando el hueco del
  medio para el rótulo. Por eso el mapa ya no dibuja monedero propio y por eso
  `_go_adventure` llama a **`_ui_out(false)`**: si la salida del menú se los
  llevaba hacia arriba, ese tween y el del viaje peleaban por la misma
  propiedad y las cajas se quedaban a medio camino.
- **El rótulo del mapa va con ALTO FIJO y colocado a mano**, no estirado dentro
  de un contenedor: estirándolo, la cinta se pegaba al canto superior y el
  texto —centrado en un rectángulo mucho más alto que el dibujo— quedaba
  descolgado respecto a la tela. Y se centra **en el hueco entre las dos
  cajas**, no en la pantalla: el saco del arroz asoma por la izquierda de su
  caja y la cola de la cinta lo rozaba. El arroz
  (`GameState.rice`, `RICE_START` 20) es la energía del juego: 1 uso por nivel,
  su barra es **la propia caja rellenándose** de canto a canto, no una barrita
  metida dentro. **Se gasta 1 saco por jornada** (en
  `consume_ingredients_for_level`) y se repone solo: **1 saco cada 90 min de
  tiempo REAL**, tope 20. Lo que se guarda es `rice_next_ts`, la MARCA DE
  TIEMPO del próximo saco —no un contador—, así que el reloj corre igual con el
  juego cerrado; `tick_rice()` cobra de golpe todos los que hayan caído. Va
  contra el reloj del aparato, así que adelantarlo regala arroz: asumido
  mientras no haya cuentas en servidor.
- **PABLO PROMETE EN EL NIVEL Y PAGA EN EL MAPA**: al cerrar el nivel 10 el
  guion solo apunta la deuda (`GameState.pending_ingots`) y la entrega la hace
  `main_menu._pagar_pablo` al volver al mapa, que es donde están a la vista las
  tres cajas —lingotes, doblones y arroz— y donde "míralos arriba del todo, con
  su botón +" señala algo. Dentro del nivel no hay ninguna de las tres y la
  explicación apuntaba a una pantalla vacía. Mismo patrón que Saverio y Cai.
- **LINGOTES DE ORO** (`GameState.ingots`, empieza en 5): la moneda que se
  comprará con dinero real. Con ellos se compran sacos (1 saco = 1 lingote,
  5 = 3, 10 = 7, en `main_menu.PACKS_ARROZ`). Los paquetes de lingotes
  (1/5/10 por 1 €, 4,50 € y 8 €) tienen su cartel montado pero **no cobran**:
  la compra de verdad es de más adelante.
- **Sin arroz NO se zarpa** (`GameState.can_play`): hace falta al menos 1 saco,
  y el aviso salta en el selector de recetas, no al montar el nivel (allí ya
  sería tarde y la pantalla parpadearía).
- **Comprar arroz siempre CONFIRMA, y el cobro es PROPORCIONAL**
  (`GameState.rice_deal`): si el paquete de 5 por 3 lingotes se compra faltando
  solo 3 sacos, se pagan `ceil(3 * 3/5)` = 2 y el cartel lo dice. Con el saco
  lleno no se vende nada: sale Gigi y no se toca ni un lingote.
- **Las tres cajas del menú (lingotes, monedas, arroz) van centradas arriba y
  en el MAPA se corren a la DERECHA en bloque**, que es lo que deja hueco al
  botón "Atrás" a su misma altura. El
  hueco entre cajas (`RES_GAP` 46) tiene que dar para DOS voladizos: el "+" que
  asoma por la derecha de una y el icono que asoma por la izquierda de la
  siguiente — con 12 px el "+" de los lingotes se montaba sobre la moneda.
- **EL TECLADO EN LA BUILD WEB LO DECIDE UNA OPCIÓN DE EXPORTACIÓN, NO EL
  CÓDIGO**: `html/experimental_virtual_keyboard` en `export_presets.cfg`. Con
  ella en `false` (como venía), el runtime web evalúa
  `available: GodotConfig.virtual_keyboard && "ontouchstart" in window` → falso,
  así que `DisplayServer.has_feature(FEATURE_VIRTUAL_KEYBOARD)` es falso y NADIE
  pide teclado: ni el `LineEdit` de Godot ni código propio. Se gastaron TRES
  intentos arreglando el lado GDScript antes de mirar aquí; el juego se prueba
  en el iPhone como **build web**, así que las respuestas están en el runtime
  de JavaScript, no en el `DisplayServer` nativo.
  **Y se comprueba en `index.html`, no en `index.js`**: el
  `virtual_keyboard:false` de `index.js` es el valor por defecto del motor y
  despista; el que manda es `"experimentalVK"` dentro de `GODOT_CONFIG` en
  `index.html`.
- **TECLADO DEL MÓVIL = `scripts/mobile_keyboard.gd`** (`MobileKeyboard.attach`,
  que es lo que usa `prep_board.enable_mobile_keyboard`). Escucha en **`_input`**
  (antes que la interfaz) y mira si el toque cae dentro del rectángulo del
  campo, en vez de esperar a que el evento llegue al `gui_input` del `LineEdit`
  — el mismo patrón que `touch_scroll.gd`. Atiende los DOS tipos de evento
  (`emulate_mouse_from_touch` está activo, así que un dedo llega como ratón) y
  no esconde el teclado en `focus_exited`, que lo cerraba en cuanto el foco daba
  un salto. **La petición del teclado va POR DUPLICADO: en seco dentro del
  propio `_input` Y diferida un fotograma.** La de en seco es la que abre el
  teclado en el navegador del móvil (solo lo abre DENTRO del gesto del
  usuario: diferida sola, iOS la ignoraba y el teclado no salía nunca — era
  "el teclado no aparece al escribir el nombre en la intro"), y la diferida
  sigue haciendo falta porque el `LineEdit`, al reaccionar después al mismo
  toque, podía cerrarlo de vuelta. Nada de esto sirve sin la opción de
  exportación de arriba.
- **Un icono en el TEXTO de un botón se escapa al restyle**: el de Comprar de
  la tienda seguía con `"✔  Comprar"` escrito a mano, resto de cuando
  `skin_action_button` prefijaba el rótulo. Ahora Comprar tiene su propio
  gráfico con una MONEDA (`boton_comprar.png`), que además dice mejor lo que
  hace que un visto genérico.
- **`make_big_title` lleva `line_spacing` MUY negativo** (−0.62 del cuerpo): la
  Exo 2 reserva ~1.9× el cuerpo por línea y un titular de dos líneas
  ("Jornada / Acabada") salía con medio cartel de hueco en medio. Es la misma
  trampa que el cartel del gesto de la tabla.
- **El nivel NO arranca solo**: `level3d._ask_start()` enseña "¿Comenzamos?" y
  hasta pulsar "¡Empezar!" la cuenta atrás no corre (`awaiting_start`).
- **Cartel de fin de turno**: cartel PEQUEÑO (`RESULT_SIZE`) con cuerdas en las
  cuatro esquinas (una sola textura volteada, con `pivot_offset` al centro o el
  volteo se lleva la cuerda fuera de la esquina). Lleva el titular
  "Jornada acabada", las estrellas, el TOTAL de la jornada en grande con su
  moneda al lado, y **Repetir / Continuar con textura propia** (flecha circular
  en madera azul y doble galón en ámbar). El desglose largo vive en su propia
  hoja (`detail_panel`), detrás del botón del lateral.
- **`_show_results` PAUSA el árbol**, así que todo lo que se monte encima del
  cartel necesita `PROCESS_MODE_ALWAYS` o no recibe ni un toque: la hoja del
  desglose no dejaba ni desplazar ni cerrar por esto. Y los TWEENS tampoco
  corren: las estrellas del cartel llevan `PROCESS_MODE_ALWAYS` por eso.
- **EL TOTAL DE LA JORNADA SE CUENTA POR TRAMOS** (`_count_up_money`), no
  aparece hecho: primero sube el dinero de los PLATOS desde 0, luego entra la
  chapa "+N" de las PROPINAS con su icono y la cifra la absorbe, y al final la
  de las PRIMAS de cierre. Las chapas suben flotando **a la derecha** de la
  cifra: por el centro cruzaban justo por delante de las estrellas y tapaban la
  que acababa de encenderse.
- **Las ESTRELLAS se encienden AL PASO del contador** (`_count_tick`): cuando
  la suma cruza el umbral de una, esa entra. Se acota con el número de
  estrellas YA CALCULADO (base + propinas), o las primas del último tramo
  regalarían una que no se ha ganado. La conseguida llega girando y enorme, se
  clava con `TRANS_BACK`, suelta un destello y remata con un latido; **la
  TERCERA** (`_pop_star(idx, true)`) gira entera, tarda más y deja un fogonazo
  dorado que se abre detrás. La que falta (`_drop_star`) se descuelga desde
  arriba con `TRANS_QUAD` entrando y aterriza torcida, hundida y a media luz, y
  solo al final, cuando ya no queda nada que sumar. Debajo queda siempre la
  estrella vacía a poca opacidad, o la fila bailaría mientras se revelan.
  **UN RETRASO VA EN `set_delay()` DE CADA TWEENER, no en un `tween_interval`
  al principio**: con el intervalo delante y el tween en modo paralelo, las
  animaciones corren A LA VEZ que el intervalo en lugar de después.
- **Rótulo grande = `make_big_title()`** (letras doradas con contorno grueso),
  para carteles cortos: "¿Salir?" y "Jornada acabada". Una cinta con una frase
  larga pesaba más que el propio mensaje.
- **`START_TEXT_DROP`**: el rótulo de la placa de oro baja 9 px. La cara dorada
  no está centrada en la textura (el ribete rojo asoma más por abajo), así que
  centrado a lo geométrico se leía descolocado.
- **`Control.position` ES RELATIVO A LA ESQUINA SUPERIOR IZQUIERDA DEL PADRE,
  NO AL ANCLA.** Con los botones redondos anclados ABAJO, guardar como posición
  de reposo el número que se les pasa (-114) en vez de su `position.y` real
  (~1166) hacía que la animación de salida tirara de ellos HACIA ARRIBA. Las
  posiciones de reposo se leen en `_ready`, **después** de un `process_frame`.
- **El cartel de la cuenta atrás ENTRA y SALE con movimiento** (`_show_phase`,
  `PHASE_TRAVEL`): entra por la izquierda con rebote y sale por la derecha. Se
  probó dejándolo meciéndose en su sitio y no es una transición. Va **JUSTO
  ENCIMA DE LA CINTA** de la tabla de elaboración (apoyado sobre la fila de
  cabezas, `PHASE_W`×`PHASE_H` = 430×78): arriba del todo competía con el reloj
  y el marcador, y ahí es donde el jugador tiene los ojos mientras cocina.
- **Botones (TODOS los del juego)**: `prep_board.skin_button()` es el único
  sitio donde se define su aspecto — tablón de madera con marco dorado y
  remaches (`assets/ui/boton_madera.png`, `BUTTON_MARGIN` 44), sombra
  proyectada y hundido al pulsar. En botones pequeños el margen del 9-slice se
  **encoge por código** al redimensionar (`min(lado)*0.44`): con el margen fijo
  las cuatro esquinas doradas no cabían y el marco salía aplastado. Si un texto
  se solapa con el marco, la solución es ensanchar el botón, no bajar el margen.
  **Si un botón se ve distinto al resto, es que no pasa por aquí**: el "Salir"
  del nivel se había quedado con un `StyleBoxFlat` propio y era el único del
  juego fuera del estilo.
- **Estrellas**: imágenes propias (`estrella_llena/vacia.png`) vía
  `make_star_row()`, nunca el carácter ★.
- **Cinta 3D (level3d)**: cuatro tramos rectos + un **codo cuadrado en cada
  esquina con la MISMA banda** (`corner_mat`, mismo shader con sus propias
  repeticiones, avanzado desde `_process` igual que `band_mat`). Antes las
  esquinas eran placas de acero quietas y cortaban el movimiento cuatro veces
  por vuelta. Los tramos miden `BELT_SIDE - BELT_W` para dejarles el hueco.
- **Sprites con transparencias raras**: `tools/alpha_fix.gd`. El recorte por
  inundación se comía trozos del sujeto cuando era claro (el arroz blanco sobre
  fondo blanco: se veía la tabla a través). La herramienta sella los píxeles
  semitransparentes interiores y, para los sprites de `PATCH`, cierra los
  mordiscos con dilatación+erosión. **Al subir el alfa hay que arreglar TAMBIÉN
  el RGB** (un píxel casi transparente suele traer el color a cero y sale
  negro): se toma el color del vecino opaco más cercano.
- **REHACER UN PLATO DESDE SU CONCEPTO**:
  `python tools/dish_from_source.py [--check] [nombre]`. Los sprites de
  `assets/dishes/` salieron de recortar el concepto 1024×1024 por INUNDACIÓN,
  y ahí el blanco del fondo y el blanco del ARROZ son el mismo color: donde el
  arroz tocaba el fondo sin contorno oscuro por medio, la inundación se metió
  dentro y se lo comió. El **maki de aguacate tenía el rollo de arriba cortado
  a cuchillo**. Los conceptos de `assets/models/source/` (28 de los 41 platos)
  **ya traen alfa de verdad** —son los que se mandaron a imagen→3D—, así que
  rehacer el sprite desde ahí es solo recortar por la caja del alfa y escalar:
  ese camino no puede comerse el sujeto.
  **El detector NO puede ser el alto**: un mordisco es una MUESCA en medio y
  no mueve la caja (al maki le faltaba medio rollo con 3 px de diferencia).
  `--check` compara el alfa del concepto contra el del sprite y canta el % que
  falta; hay un ~3% de ruido de fondo por el remuestreo del borde, así que lo
  que delata daño es pasar de ahí (el maki estaba en 5.94%). Ojo con los
  falsos positivos de ENCUADRE: el nigiri de salmón marca 4.59% y está
  entero — su sprite sencillamente está más ampliado que el concepto.
- **MOTAS sueltas del recorte**: `python tools/despeckle.py [--check] <png/webp>`.
  El otro fallo de la inundación, y el contrario del anterior: píxeles casi
  blancos que sobreviven porque quedaron AISLADOS, sin camino de píxeles claros
  hasta el borde. Se ven como un reguero de puntitos sobre fondo oscuro — el
  maki de aguacate tenía **54 motas (81 px) en un arco sobre el rollo**, que es
  la mancha blanca que se veía en la ficha y en el bocadillo. El corte es
  DOBLE y conservador (isla de ≤60 px Y <0.02% del sujeto) porque muchos
  sprites llevan piezas sueltas A PROPÓSITO: el vapor del té verde, la harina
  de la gamba enharinada, los remolinos de los iconos de potenciador. **Pasar
  siempre `--check` primero** y mirar qué se va a tirar; en la auditoría de
  toda la carpeta salieron también `te_verde` (1 mota), `gamba_harina` (23) y
  `bol_miso` (7), y esas NO se han tocado por si son arte.
- **Cinta 2D (level.tscn, referencia)**: cuatro **tramos rectos** independientes (`Line2D` con shader
  `belt_scroll.gdshader` que desplaza la UV) + **placas romboidales metálicas**
  estáticas en las esquinas. Una `Line2D` cerrada con juntas parpadea porque la
  geometría de la junta recibe UV que se desplazan — por eso van en tramos.
- **`TextureRect`**: fijar `expand_mode = EXPAND_IGNORE_SIZE` **antes** de
  asignar `texture`, o el tamaño mínimo salta al nativo del sprite.
- **HUD**: barra superior y tabla inferior ancladas a los bordes (top / bottom)
  y a todo el ancho; el espacio extra de pantallas altas queda en el centro.
  La barra superior **ya no tiene fondo**: tiempo, dinero/bote y clientes van
  directamente sobre el 3D, legibles por contorno negro grueso (`outline_size`
  11-12) y sombra. Al quitarla, la banda visible del mundo empieza en y=0, así
  que `CAM_TARGET` de `level3d.gd` se recolocó (3.25) para recentrar la acción.
  La **fila de cabezas de cliente** se añade por código y era el último hijo del
  HUD, así que se dibujaba ENCIMA del selector de potenciadores; los carteles
  modales (`powerup_panel`, `results_panel`) llevan `z_index = 120`.
  Cuenta **por TIPO, sin separar por género**: una insignia por grumetes,
  piratas y capitanes. La cara de cada tipo es la del PRIMERO de ese tipo que
  llegó en la partida (`level3d.head_gender`) y ahí se queda aunque los
  siguientes sean del otro género; separarlas en dos caras por tipo llenaba la
  fila de iconos sin decir nada nuevo.
- **Guardado**: al soltar cerca de las cajas (con margen amplio) se guarda solo
  en la primera caja válida (misma receta con hueco → primera vacía). Servir a
  la cinta exige soltar sobre su franja. Desde una caja se sirve con arrastre
  real (>24 px); un TOQUE en la caja con la tabla LIBRE **restaura el plato de
  arriba a la tabla** (ver abajo) y con la tabla ocupada no hace nada.
- **LOS PLATOS GUARDADOS CONSERVAN SUS EXTRAS** (`stacks[i].units`, un array
  de extras POR UNIDAD en paralelo con `count`; el último es el de arriba, el
  próximo en salir). La caja enseña en miniatura los extras del plato de
  arriba (`_refresh_stack_extras`). Los extras marcados NO gastan despensa
  hasta que el plato se sirve de verdad (mismo contrato que desde la tabla):
  servir desde la caja los cobra en ese momento y viajan con el plato. **Los
  CUATRO sitios que mutan pilas deben mantener `units` en sincronía con
  `count`**: guardar (añade), servir desde caja (saca), `_consume_stored`
  (barco/combos: absorben el plato de arriba, la marca se pierde sin coste) y
  la devolución al cancelar el barco (vuelven como unidades limpias).
- **TOQUE EN CAJA CON LA TABLA LIBRE = restaurar** (`_restore_from_stack`):
  el plato de arriba vuelve a la tabla como plato TERMINADO, con sus extras ya
  MARCADOS en los botones, para poder añadirle o quitarle antes de servirlo.
  Solo con `state == IDLE`; con algo en la tabla el toque no hace nada (el
  arrastre directo sigue igual). El plato restaurado lleva
  `ready_from_storage` y al irse de la tabla **NO aplica cooldown** — su
  receta ya lo pagó al elaborarse (sin la bandera, restaurar+servir enfriaba
  la receta dos veces). Tampoco pasa por `DISH_ARM`: la restauración es un
  gesto deliberado lejos del centro de la tabla.
- **Mano de gestos**: `HAND_TIP` ancla la mano **por encima** del objetivo.
  Los pasos sobre la tabla apuntan al **centro del sprite de etapa**, sin
  desplazamientos fijos. Los deslizamientos llevan además una `flecha.png`.
  Mano (`HAND_SIZE`), flecha y fantasmas van a tamaño GRANDE a propósito: son
  la guía del jugador en móvil. Los pasos de pulsar/mantener añaden un **anillo
  dorado que late** en el punto exacto (`_ring_pulse`), porque la mano sola se
  perdía sobre el arroz blanco. El deslizamiento arranca 46 px por DEBAJO del
  centro de la etapa: desde el centro exacto, la mano grande se salía de la
  tabla por arriba.
- **La guía (mano + texto) está SIEMPRE puesta.** Se probó a mostrarla solo
  tras unos segundos de inactividad y se descartó: es la referencia de qué
  toca hacer y esconderla dejaba al jugador a ciegas. `_tick_guide` queda
  vacío a propósito.
- **Cartel del gesto** (`_instruction_text`): solo el VERBO — "¡Toca!",
  "¡Pulsa!", "¡Corta!", "¡Mantén!", "¡Desliza!", "¡Remueve!", "¡Arrastra!" y
  "¡A la cinta!" al terminar—, con las repeticiones que faltan en una segunda
  línea ("x3"). Va pegado al **borde derecho de la tabla e inclinado 30°**
  (`INSTRUCTION_ANGLE`): ahí no tapa la etapa ni la mano. Las frases largas no
  se leían de un vistazo mientras se juega. Se probó a 80° (casi vertical) y
  costaba leerlo; 30° se lee de corrido y sigue pareciendo un letrero clavado.
  Las dos líneas van MUY juntas (`line_spacing` -32 en `level3d.tscn`): la
  fuente del juego trae 75 px de caja por línea a tamaño 40, así que hasta -15
  seguían pareciendo dos carteles sueltos.
  La distancia al borde se calcula sobre la **huella del texto YA GIRADO**
  (`INSTRUCTION_MARGIN`), no con un número fijo: cuanto menos inclinación, más
  ancho ocupa, y con margen fijo se salía de la tabla.
- **Layout móvil (importante)**: en la tabla inferior las **recetas van abajo**
  y la **tabla de manipulación arriba**, a propósito: un gesto de deslizar de
  abajo hacia arriba pegado al borde inferior del móvil cierra la app.
- **Maestría (`free_uses`)**: al hacer manualmente una receta con `free_uses`
  (makis/futomaki/tamago), las N siguientes salen instantáneas — se muestra "xN"
  en el botón. Cada una de esas N **sigue pasando por el cooldown** de la
  receta, así que la maestría no es un lote que sale de golpe: es un descuento
  de gestos. Aun así pesa mucho en lo que rinde una receta, y hay que revisarla
  cada vez que se le cambien los pasos (ver el recorte del dragon roll).
- **Botones de receta (in-game)**: fondo de **pergamino** (`panel.png`, no madera),
  plato grande y uniforme mirando abajo-derecha, estrellas en la franja inferior.
  **Ordenados por PAPEL** (`prep_board._recipe_group`): los PICOTEOS delante
  (se sirven de reflejo), los POSTRES al final del todo sea cual sea su precio
  (son la cuenta: cuando decides despedir a un cliente, el postre está siempre
  en la misma esquina), y los principales en medio por estrellas y precio.
- **Cancelar**: disponible **en todo momento** durante la elaboración
  (`_can_cancel()` = `state == CRAFTING`), no solo en el primer paso.
- **Sprites de plato**: todos comparten encuadre compacto (~1.2–1.4:1) sobre una
  tabla oscura mirando a la **esquina inferior derecha**, para que se vean del
  mismo tamaño en los botones (que usan `STRETCH_KEEP_ASPECT_CENTERED`, así que un
  sprite ancho se vería pequeño). Si se regenera un plato, mantener ese encuadre.
  **Fidelidad al plato real** (el usuario aporta fotos de referencia): maki de
  aguacate = uramaki con el ARROZ POR FUERA y centro de aguacate; maki de atún =
  nori POR FUERA, 6 piezas; gunkan = nori rodeando el LATERAL con el relleno
  encima. No inventar variantes.
- **Maki de atún**: la preparación empieza esparciendo el **alga nori** en la
  tabla (ingrediente `nori`) y el arroz se moldea ENCIMA del nori (etapas
  `nori_tabla → nori_arroz_bola → nori_arroz → nori_atun → rollo_atun`).
- **Guardado por pilas**: cada caja apila hasta `stack_max` (3, o 5 con "Más
  almacén") platos IGUALES; el mismo plato nunca ocupa dos cajas. Potenciador
  "Doble plato" crea 2 platos en la tabla a la vez.
- **Estadísticas de los logros**: se suben desde donde OCURRE el suceso, no
  desde un sitio central — clientes y récord de platos por cliente en
  `level3d._on_client_finished` (solo cuenta el cliente que comió algo), platos
  en `_on_player_dish_served` (los del ayudante NO cuentan), propinas en
  `_add_tip`, récords de dinero y partida limpia en `_finalize_results`, cortes
  y tempuras perfectas en `prep_board`, extras en `GameState.consume_extra` y
  lo gastado en la tienda y en el inventario al restar el dinero. Cuentan en
  aventura Y en Arcade: los logros son del jugador, no de la campaña.
- **Ajustes de gráficos, qué hace cada uno de verdad**: *Calidad* cambia
  `scaling_3d_scale` del viewport (el 3D se dibuja a menos resolución y la
  interfaz 2D no se toca); *Fotogramas* fija `Engine.max_fps`, y los menús
  siempre van a la MITAD (`GameState.fps_for(false)`, tope 30); *Sombras*
  apaga las manchas de `SceneBackdrop.blob_shadow` (que son las únicas sombras
  del juego, no hay pase de sombras); *Animaciones* quita el adorno —gaviotas
  y nubes ni se crean, y se paran el balanceo del logotipo, el cabeceo del
  barco, el mecerse de los fondos y la respiración del tendero—, nunca las
  animaciones de juego.

## Progresión y economía (cambios recientes)

- **Un plato da UNA vuelta a la cinta** (`plate3d.MAX_LAPS` = 1, antes 2). Los
  platos NACEN en la esquina inferior del circuito (`SPAWN_PROGRESS` cae justo
  en el vértice +X/+Z), así que una vuelta los devuelve exactamente a ese
  punto: ahí está el **cubo de basura 3D** (`level3d._add_trash_bin`) y el
  plato se vuelca dentro con una caída corta en vez de desaparecer de golpe.
  El castigo por tirarlo es el **20%** de su precio (`WASTE_PENALTY`).
- **La cinta va a `PLATE_SPEED` 1.25 u/s, no a 0.9**: el circuito mide 14.4 u,
  así que a 0.9 una vuelta duraba **16 s** de los 150 del nivel y, con unos 30
  platos por partida, la cinta enseñaba **3 de media** — una cinta kaiten con
  tres platos no parece una cinta. A 1.25 la vuelta baja a ~11.5 s (se probó a
  1.35 y va justo por encima de lo cómodo para decidir). **NO toca
  el equilibrio**: el dado de coger un plato se tira UNA sola vez, al entrar en
  el radio del cliente (`client3d._scan_belt` mete el plato en `declined` si
  falla), así que la velocidad cambia el RITMO, nunca las probabilidades. Es
  una perilla libre. La misma constante empuja el shader de la banda, así que
  el dibujo y los platos van siempre acompasados.
- **Un plato terminado se manda a la cinta con un TOQUE; el ARRASTRE es para
  las cajas** (`prep_board._continue_dish_drag`, umbral de 24 px como el resto
  de arrastres del juego). Antes había que arrastrarlo SIEMPRE, y eso eran
  ~0,8 s por plato × ~30 platos = **unos 24 s de los 150 haciendo de camarero**,
  con la tabla BLOQUEADA mientras tanto (`_start_prep` exige `state == IDLE` y
  solo se vuelve a IDLE cuando la tabla se queda vacía). Ahora el plato sale de
  `dishes` en el mismo fotograma del toque y se va volando solo
  (`_fly_dish_to_belt`, decoración pura: el plato de verdad ya ha nacido en la
  cinta 3D), así que se puede empezar la receta siguiente con el anterior
  todavía en el aire. La guía de la mano en estado READY marca un TOQUE sobre
  el plato, no un arrastre hasta la cinta; el destino lo canta el cartel del
  gesto ("¡A la cinta!"). **Desde una CAJA se sigue sirviendo con arrastre**
  (un toque suelto no la vacía), y el montaje del barco también.
- **El plato de una receta que ACABA PULSANDO no acepta el toque hasta pasados
  0.4 s** (`prep_board.DISH_ARM` / `_dishes_armed`, armado desde `_advance_step`
  mirando el tipo del ÚLTIMO paso). Las que terminan con un arrastre, un corte o
  el soplete se sirven desde el primer fotograma, y tampoco se arma cuando la
  receta la termina el ayudante, la maestría o un potenciador: ahí no ha habido
  gesto y el dedo no está sobre la tabla.
  No es un adorno: MUCHAS recetas
  terminan en un paso de PULSAR (el maki de aguacate acaba con `tap_board` x2),
  los golpes se cuentan **al APRETAR**, y el plato nace justo en el CENTRO de
  la tabla, o sea debajo del dedo que venía dando golpes — así que el golpe de
  más que se le escapa a cualquiera lo mandaba a la cinta sin querer, con los
  extras aún sin poner. Y la ventana **se alarga con cada golpe frenado**,
  porque con una ventana fija una ráfaga se escapa por el final: medido
  inyectando toques, con golpes cada 180 ms el tercero caía a los 410 ms y
  servía el plato. El alargue lleva **tope duro** (`DISH_ARM_MAX`, 1 s desde
  que nace el plato) para no caer en lo contrario: sin él, quien insistiera
  tocando cada poco no serviría nunca. Solo frena al TOQUE — arrastrarlo a una
  caja funciona desde el primer fotograma, que un arrastre nunca es un golpe
  accidental.
  Esto se comprueba **inyectando `InputEventScreenTouch` con
  `Input.parse_input_event`** desde una sonda temporal, como el resto del input
  táctil de este proyecto: a ojo no se distingue "lo he tocado yo" de "se ha
  ido solo".
- **NINGUNA receta pasa de SEIS pasos** (antes: dragon roll 11, chirashi 9,
  tsuke don 9, California 8, y cinco más con 7). Las recetas largas eran
  trampas dobles: ocupaban el ÚNICO hueco de elaboración 15 s con la cinta
  vaciándose, y rendían menos doblones por segundo de atención que un sashimi
  de dos pasos. Al recortar hay dos reglas que no se pueden saltar: `stages`
  lleva **un sprite por paso** (descuadrarlo rompe la receta), y el paso que
  define el plato se queda SIEMPRE — el corte lento del tsuke don y su reposo
  en la soja (es la única receta con `from`), el rebozado en sésamo del
  California, el soplete, la fritura. Lo que se cae es el relleno: los pasos
  cuyo `stages` repetía el sprite anterior, y las guarniciones que pedían tres
  pasos para acabar dentro de un cuenco (el pepino del chirashi y del tsuke
  don). **Al recortar una receta hay que mirarle la maestría**: el dragon roll
  pasó de 11 pasos a 6 y con sus `free_uses` 4 intactos habría quedado como la
  receta más rentable del juego con diferencia, así que bajaron a 2.
- **DOS CIFRAS DE DINERO, y la asimetría es a propósito** (`_score_money` /
  `_star_money`): el **dinero BASE** (solo el precio de los platos) es lo que
  marca el contador del HUD y lo ÚNICO que puede cerrar el turno antes de
  tiempo, para que el nivel no se corte por unas propinas que el jugador no
  controla; las **ESTRELLAS** se miden con `base + propinas`, que es justo lo
  que se lleva de la jornada, así que el total del cartel y las estrellas
  cuentan la misma historia. Las primas de cierre no cuentan para estrellas:
  son premio por acabar pronto, no producción.
- **El nivel TERMINA en cuanto el dinero BASE alcanza el objetivo** (el umbral
  de 3 estrellas): `_check_goal_reached()` tras cada plato cobrado. `_add_tip`
  NO lo llama.
- Lo que se COBRA al acabar es `platos + propinas + primas`. Primas: **3**
  doblones por cada grumete que
  se quedó sin venir, **8** por pirata, **15** por capitán
  (`LEFTOVER_BONUS`), y **3** por cada bloque completo de **10 s** de reloj
  sobrante. El desglose del panel de resultados los enseña por separado.
  **Cada prima solo existe donde tiene sentido**: la de clientes, en los niveles
  con cupo (islas y puertos); la de tiempo, en los que llevan reloj (abordajes).
- **Regalo de ingredientes**: una receta nueva llega con **3 usos de cada
  ingrediente NUEVO** y **solo 1 de los que el jugador ya tenía**
  (`GameState.gift_ingredients_for`, `TUTORIAL_GIFT` = `PORT_GIFT` = 3,
  `GIFT_KNOWN` = 1). Lo que se regala es la receta, no la despensa. Diez porque la campaña-escuela no tiene tienda hasta el
  nivel 4: hasta entonces no hay dónde reponer y una receta recién regalada
  tiene que dar para varias jornadas. Por lo mismo `CampaignData.
  INITIAL_INGREDIENTS` está VACÍO: la despensa de salida la reparte
  `complete_tutorial` con esa misma regla, y poner cifras ahí sumaba encima.
  Los ingredientes gratis (arroz, sésamo, `cost` 0) se saltan.
  **Y si aun así se queda a cero antes de que abra la tienda**, David regala
  `RESCUE_GIFT` (3) usos de lo que falte — ver el bloque de las islas.
- **El MENÚ anuncia las recetas nuevas** (`GameState.pending_reveal`, que
  llenan `complete_tutorial`/`complete_port` y consume `main_menu`): pergamino
  con los platos entrando de uno en uno con su bote.
- **LOS BONIFICADORES LLEVAN CHAPA DE LATÓN, no el tablón de madera del resto
  del juego** (`PrepBoard.PERK_TEX/PERK_MARGIN`, `skin_perk_button`, pedido por
  el usuario): un bonificador no es un botón más, y con la misma madera no se
  distinguía de una receta o de un "Atrás". Sigue hundiéndose al pulsarlo, y su
  rótulo va GRABADO —letra oscura con reborde claro—, porque el latón es claro y
  la letra crema de la madera se perdía en él. Dos medidas que no son libres:
  el margen 9-slice es **36** (la textura sale a 330 de ancho y ahí su marco
  mide 19 téxeles y los REMACHES llegan al 30; por debajo de 36 el 9-slice parte
  un remache), y la tarjeta mide **336×86** y va de DOS EN DOS por renglón —de
  un botón de 216 solo quedan ~120 px de cara útil y "Ayudante de cocina" se
  salía por encima del latón.
  **Y SU FILA ES UN `HFlowContainer`, no un HBox**: cuatro chapas miden 900 px,
  el HBox no encoge a sus hijos por debajo de su mínimo, y eso estiraba el VBox
  de TODA la pantalla — la parrilla de recetas se descuadraba hacia la izquierda
  y se salía por los dos cantos. El síntoma no apuntaba a la fila de abajo.
- **EL ICONO DEL AYUDANTE ES LA CARA DE ALICE** (`head_AL.png`): el ayudante ES
  ella desde que se enrola, y el arcón de `ic_inventario` que llevaba antes no
  decía nada de eso.
- **LAS ISLAS TAMBIÉN PASAN POR EL SELECTOR SI HAY BONIFICADOR QUE ELEGIR**
  (`level_select3d._zarpar_con` → `_hay_bonificadores`): la carta no se elige,
  pero el bonificador sí, y saltándose la pantalla quien tuviera a Alice no
  podía llevársela a ninguna isla. Allí la carta sale PUESTA y sin tocar
  (`prep_screen.carta_fija` / `_marcar_carta_fija`: tarjetas marcadas, con su
  resalte y `disabled`), el subtítulo lo dice, y se apagan la selección
  automática y el aviso de clientela desatendida —el jugador no puede cambiar
  nada, así que solo serían un susto—. Sin ningún bonificador que elegir se va
  directo al nivel, como siempre: una pantalla entera para pulsar "¡Zarpar!" no
  es una decisión.
- **La TIENDA se gana** superando el puerto que la trae (`unlocks_shop`, el
  nivel 4); el botón del menú queda apagado hasta entonces. La presentación de
  Saverio va DENTRO del guion del nivel 4 (`level_director._nivel_4`, al cerrar
  el turno): es él quien pone `shop_intro_done` y deja `pending_shop_visit`,
  que hace que el botón "Continuar" del cartel de resultados lleve DIRECTO al
  puesto en vez de al mapa (David acaba de decirle que se pase; hacerle buscar
  el botón en el menú justo después rompía la escena).
  **LOS EXTRAS NO LLEGAN CON LA TIENDA**: los saca Saverio dos niveles después,
  en el 6 (`GameState.extras_done`, que es lo que mira `extras_unlocked()` y
  con ella la tabla y la tienda). La tienda ya es bastante novedad ella sola, y
  los extras solo tienen sentido cuando el jugador conoce el hastío.
- **El surtido de la tienda solo trae ingredientes de recetas DESBLOQUEADAS**
  (`roll_shop_stock` filtra por `unlocked_recipes`), y `unlock_recipe` pone
  `shop_day = ""` para que el surtido se rehaga al aprender algo nuevo.
  **Al recargar NO se repite nada de la tanda anterior**: se sortea primero
  entre lo que NO estaba y solo se rellena con lo de antes si no hay bastante
  género distinto (con pocas recetas desbloqueadas el surtido no da para ocho
  artículos nuevos). Pagar por recargar y que salga lo mismo es tirar el dinero.
- **La DESPENSA del inventario ordena por lo que sirve**: delante los
  ingredientes de recetas que ya se saben cocinar, detrás los demás en silueta
  con "???" (`_ingredient_known`). Los GRATIS (arroz, sésamo) cuentan siempre
  como conocidos: no se compran ni se gastan, y `RecipeData.get_ingredients`
  los salta a propósito, así que buscarlos en las recetas no los encontraría.
- **Campos nuevos de puerto en `CampaignData`**: `fixed_recipes` (carta
  cerrada), `recipe_slots` (huecos que se pueden llevar, 4 por defecto),
  `no_extras` (oculta extras, combinar y barco → `prep_board.hide_extras`),
  `no_storage` (oculta las cajas → `prep_board.hide_storage`), `no_powerups`
  (sin bote de propinas), `free_ingredients` (no gasta despensa ni arroz),
  `boss` (el jefe del nivel), `late_type` (ese tipo de cliente entra el
  último), `unlocks_shop` (nivel 4), `unlocks_fishing` (candado histórico de
  la PESCA; lo lleva el nivel 4), `prep_dialog` (aviso de David en el
  selector: niveles 3, 8 y 10) y `director` (guion narrado).

## Balance actual (para no re-litigar)

- **LA CARTA ESTÁ CALIBRADA POR DOBLONES POR SEGUNDO DE ATENCIÓN, no por
  precio.** El recurso escaso del juego es el ÚNICO hueco de elaboración: la
  demanda de la barra (8 asientos, un bocado cada ~10 s) es unas CUATRO VECES
  lo que puede producir la cocina, así que ni los asientos ni la retención del
  cliente son escasos — lo único que lo es son los segundos del cocinero. El
  precio de una receta sale por tanto de **cuánta atención cuesta hacerla**.
  Objetivo: **L1 1.5 · L2 2.0 · L3 2.5 $/s**. La pendiente entre niveles es
  suave y a propósito (un plato de 3★ es más difícil de COLOCAR: solo lo cogen
  los capitanes al 95%); lo que NO puede haber es diferencia dentro de un mismo
  nivel, que es donde estaban las trampas. Se pasó de una dispersión de **×18,7
  a ×1,9**.
  **La maestría (`free_uses`) era la causa principal**, no el precio: un plato
  de maestría cuesta ~0,7 s (tocar el pergamino y tocar el plato) y paga
  entero, así que multiplica el rendimiento — los cinco peores infractores eran
  los cinco con maestría (hana maki 6.45 $/s y dragon roll 6.39 frente a una
  mediana de 1.98). Por eso **el precio de una receta con maestría es POR
  PIEZA**: el dragon roll vale 6 pero salen 3 piezas, o sea 18 por rollo, igual
  que el maki de aguacate siempre valió 2 la pieza. Consecuencia que hay que
  aceptar al leer el recetario: el precio ya NO indica lo lujoso que es el
  plato, indica lo que paga UNA pieza.
- **Precios (doblones)**, por nivel y de menor a mayor. Los `(xN)` son las
  piezas que suelta una elaboración con maestría:
  **L1** edamame 1, te_verde 1, maki_pepino 2 (x4), sunomono 2, mochi 3,
  maki_aguacate 3 (x3), nigiri_salmon 4, gunkan_wakame 4, onigiri 4 (x2),
  nigiri_ebi 6, caldo_dashi 6, sopa_miso 7, yaki_onigiri 8.
  **L2** uramaki_california 4 (x3), maki_atun 5 (x3), sashimi_tamago 5 (x3),
  gunkan_tartar 5 (x2), nigiri_atun 5, nigiri_inari 5, dorayaki 5,
  gunkan_ikura 7, nigiri_pulpo 8, udon 10, nigiri_anguila 10, tempura 12.
  **L3** futomaki_salmon 6 (x3), hana_maki 6 (x3), dragon_roll 6 (x3),
  sashimi_atun_rojo 8, fugu 9, taiyaki 10, chirashi 12, sashimi_variado 12,
  temaki 13, aburi 13, salmon_tsuke_don 14, nigiri_wagyu 16.
  Fuera del calibrado, cada uno por su motivo: el **picoteo** (edamame,
  te_verde) vale 1 porque su valor es alargar el bocado y limpiar el paladar, y
  los **postres** (mochi, dorayaki, taiyaki) son baratos a propósito porque lo
  que dan es vaciar la silla y la propina asegurada.
  yaki_onigiri, tempura y nigiri_wagyu **no cobran su campo `price`**: lo pone
  el cronómetro (3/8/14 · 7/12/20 · 12/16/30), y el campo solo guarda el "buen
  punto" para que el recetario no mienta. moriawase y udon_tempura se calculan
  al vuelo (suma de las partes + prima).
- **MAKI DE PEPINO** (premio de 3★ del nivel 2): el maki de aguacate con el
  paso del arrastre cambiado por un CORTE — se toca el pepino y se dan 3 golpes
  para cortarlo en bastones sobre el arroz (6 pasos en total). Paga **2** pero
  suelta **CUATRO** piezas por elaboración: es la ÚNICA receta de la carta con
  `free_uses` **3**, y por eso su precio por pieza es el más bajo que hay
  (8 doblones por elaboración contra los 9 del maki de aguacate, y con un paso
  más de trabajo). Etapas nuevas: `plano_pepino`, `plano_pepino_cort` y
  `rollo_pepino`, derivadas con `editImage` de las del aguacate para que la
  continuidad sea real.
- **UNA RECETA NUEVA NECESITA SU `.glb` O SALE INVISIBLE EN LA CINTA**:
  `plate3d` solo instancia `assets/models/<id>.glb` si existe, y sin él el
  plato viaja siendo un PathFollow3D vacío (le pasó al maki de pepino: se
  servía, se cobraba y no se veía). Los dos nuevos salieron por la cadena de
  siempre — su propio sprite de plato a `create3DModel` (el sprite YA trae la
  tabla, como los conceptos de `assets/models/source/`), `glb_prepare.py`,
  `import_script` de decimado y `fix_texture_imports.py`.
  **Y OJO CON EL PRESUPUESTO DE DECIMADO EN GEOMETRÍA SIMPLE**: con los 2.500
  de los demás platos, el cuenco del sunomono se quedó en **48 triángulos** (una
  caja). Medido y subido a 9.000, que lo deja en 6.113. El maki de pepino a
  2.500 sale en 1.536 y se ve bien: el presupuesto no se copia, se comprueba.
- **SUNOMONO** (premio de 3★ del nivel 3): picoteo de 3 pasos (tocar el pepino,
  3 golpes de corte y arrastrar al cuenco) que reutiliza `pepino_tabla` y
  `pepino_rodajas`. **Es el ÚNICO picoteo que SUMA VARIEDAD** (`variety_snack`
  en la receta): el edamame y el té no tocan la racha, y este la sube y cobra
  el bono de oro del multiplicador. Como además se pica sin soltar el plato en
  curso, es la manera barata de estirar un multiplicador con la carta agotada.
  Se aplica en las DOS puertas por las que entra un picoteo: `_eat_snack`
  (cogido mientras come) y `_apply_meal_patience` (cogido esperando).
  Su arte se rehízo contra una foto de referencia del usuario: **cuenco BLANCO,
  rodajas REDONDAS** (pálidas con el aro verde de la piel) y unos pocos granos
  de **sésamo negro**. Costó cuatro pasadas y las dos trampas fueron pedir
  "cucumber salad" a secas (salen lonchas diagonales) y pedir sésamo sin acotar
  la cantidad (lo llena de puntos y las rodajas parecen kiwi).
- **QUÉ HACE CADA RECETA, en una frase: `RecipeData.summary(id)`**. Se DEDUCE
  de los propios datos (picoteo, postre, maestría, `clears_boredom`, `eat_mult`,
  `patience_mult`, propinas, corte lento, fritura...), no se escribe a mano
  receta por receta: así una ficha no puede mentir y una receta nueva llega
  descrita sin trabajo extra. Devuelve hasta `SUMMARY_MAX` (3) frases con las
  palabras clave entre `**asteriscos**` (`DialogueBox.format_keywords`), y lo
  pintan los TRES sitios donde el jugador pregunta "¿y esto para qué sirve?":
  la ventana de "¡Nueva receta!" del nivel (`level3d._show_next_recipe`, que
  además CRECE de 580 a 690 px cuando hay descripción), el cartel de recetas
  del menú (`main_menu._show_reveal`, solo con UNA receta: con varias no cabe
  un párrafo por plato) y la ficha del recetario (`inventory_screen`).
- **`clears_boredom` en un plato NORMAL** (la sopa de miso, premio de 3★ del
  nivel 6): limpia el PALADAR como el té verde —todo vuelve a contar como
  nuevo— pero **NO toca la racha**: ni la sube ni la rompe. Es el reinicio en
  versión plato principal (cuesta un hueco de carta y una elaboración larga, y
  a cambio se cobra como plato). Tiene su propia rama en `_apply_meal_patience`,
  entre la del picoteo/postre y la del plato nuevo.
- **Recetas de mecánica especial** (las 8 últimas):
  *temaki* (enrollado en CONO: `swipe_board` con `direction: "diag"`),
  *aburi* (soplete como `prop` de un `hold_board`),
  *chirashi* (bol con tres pescados distintos encima),
  *udon* (`eat_mult` 1.8 y `patience_mult` 0.7: ocupa mucho al cliente pero le
  retiene poco — sirve para aparcar a un pesado),
  *gari* (picoteo que casi no alarga el bocado pero da +6% de propina),
  *te_verde* (picoteo con `clears_boredom`: REINICIA el arco de variedad —
  historial limpio, todos los platos vuelven a contar como nuevos, pero el
  multiplicador cae a cero: reconstruir, no continuar),
  *fugu* (corte con `fail_penalty` 5: cada corte rápido cuesta 5 doblones —el
  plato NO se pierde—; `tip_amount_mult` 1.15, la propina es más GORDA cuando
  cae, frente al atún rojo que la hace más PROBABLE),
  *tempura* (paso `fry_board`: contador con milésimas a la vista; al soltar se
  mira en qué franja de `FRY_WINDOWS` cayó — antes de 1.2 s cruda y a la
  basura, 1.2-1.67 poco hecha $7, 1.67-2.16 bien $12, **exactamente 2.00 s
  $20**, 2.16-3.0 pasada $7, más allá quemada y a la basura; las variantes
  cruda y quemada son recetas `hidden` con su propio modelo).
  **El punto bueno se movió de 3.00 s a 2.00**: tres segundos con el dedo
  pegado a la sartén eran tres segundos del turno con el único hueco de cocina
  ocupado sin hacer nada, y por eso la tempura era la receta con PEOR
  rendimiento de toda la carta. Las franjas se reescalaron enteras a 2/3. Por
  lo mismo, el `hold_board` de la sopa de miso y del udon bajó de 2.0 a 1.2 s;
  el del aburi se queda en 2.0 porque ahí el dedo está soplando, que es la
  mecánica, no esperando,
  *onigiri* (1★ pero `take_chance` 0.5 para todos los tipos y `patience_mult`
  1.4: llena mucho para lo que cuesta),
  *moriawase* (`hidden`: no se elige en el selector).
- **Barco combinado** (`prep_board`, `BOAT_*`): icono redondo bajo las cajas,
  al lado de Cancelar. Está **SIEMPRE a la vista** (si solo aparecía al poder
  montarlo, nadie descubría que existe) pero **apagado** mientras no haya
  **4 platos guardados de BOAT_DISHES y al menos DOS clases distintas** (nunca
  4 iguales); durante el enfriamiento enseña **los segundos que faltan** en un
  contador sobre el icono (se refresca solo desde `_process`, sin repintar el
  botón entero 60 veces por segundo). Al pulsarlo
  consume esos platos y sirve un barco cuyo **precio se calcula al vuelo**:
  suma de los platos + prima por variedad (2 clases +10, 3 +24, 4 +52). Se come **muy despacio, y más cuantos más
  platos lleve**: `BOAT_EAT_BASE` + `BOAT_EAT_PER_DISH` × platos (x2.0 con los 4
  mínimos, x2.2 con 6, x2.8 con los 12 del tope). La pendiente está muy
  comprimida a propósito: con 0.15 por plato, un barco lleno aparcaba a un
  grumete casi un minuto, más de un tercio de la partida. Ese tiempo NO sale de la ficha
  de la receta: lo calcula `_finish_boat` y viaja con el plato
  (`dish_served` → `plate3d.eat_mult_override` → `client3d`), igual que el
  precio y el nivel. Un barco aparca al cliente entre 18 y 48 s según tamaño y
  tipo, y como la paciencia NO se drena mientras come, ese rato sale gratis. Ese
  precio viaja por `dish_served(recipe_id, price_override)` → `plate3d.
  price_override` → `client3d`, porque no vale el de la receta.
- **El dinero del nivel NUNCA baja de 0**: los tres castigos (plato desechado
  = 30% de su precio, `fail_penalty` del corte rápido y el cliente que se va de
  vacío) se descuentan con `maxi(..., 0)`, así que el marcador se queda en $0.
- **`fail_penalty`** en `slice_board`: cortar deprisa el pescado caro emite
  `money_penalty` y el nivel lo descuenta **sin bajar de 0**.
- **Castigo por cliente que se va DE VACÍO** (`client3d.LEAVE_PENALTY`): si se
  marcha sin haber probado NI UN plato cuesta 5 doblones el grumete, 8 el
  pirata y 12 el capitán, **tanto si se le agotó la paciencia como si le pilló
  el final del nivel**. Y **ESCALA**: cada vacío previo de la partida encarece
  al siguiente (base × 1+0.5·vacíos, tope ×3 — `EMPTY_LEAVE_STEP`/`CAP`, la
  cuenta en `level3d.empty_leavers`). Es el contrapeso del "cliente eterno"
  del sistema de variedad: monopolizar la cocina mimando a uno deja al resto
  sin probar bocado, y cada abandono cuesta más que el anterior. Un solo plato
  L1 ya libra del castigo, así que el triaje barato es "que nadie se quede a
  cero". Viaja en `report.penalty`, el nivel lo descuenta sin bajar de 0, el
  cliente lo canta con un "-$N" rojo (la cifra creciente comunica la escalada
  sola) y la ficha del desglose enseña ese número en vez del dinero.
- **Al acabar el nivel, el que está COMIENDO termina su plato** (`force_leave`
  solo marca `_leave_when_done` si está en EATING): cobra ese último plato y
  entonces se levanta. Ese bocado corre a `END_BITE_SPEED` (×5) porque el
  jugador ya no puede hacer nada, y deja de picar snacks. El cartel de fin
  espera a que nadie mastique (`_anyone_finishing_bite`, tope `END_BITE_MAX`) y
  después `END_PAY_LINGER` s más para que dé tiempo a leer el "+$N".
- **COMBINACIONES** (`RecipeData.COMBOS`, botón junto al del barco): dos platos
  YA GUARDADOS en las cajas que se funden en uno. A diferencia del barco (que
  admite cualquier surtido), cada combo exige una **pareja exacta**, una unidad
  de cada parte, en el orden que sea. Precio = suma de las partes + `bonus`.
  El botón está siempre puesto y apagado hasta que la pareja esté completa.
  De momento solo hay uno: **udon + tempura → udon con tempura** ($6+$7+3=16),
  que hereda los efectos de los dos y se come aún más despacio (`eat_mult` 2.2).
  Para añadir otro: una línea en `COMBOS` y la receta `hidden` con su sprite.
- **HASTÍO Y VARIEDAD** (`client3d`, bloque de constantes con el mismo nombre):
  cada cliente lleva la cuenta de qué platos ha PROBADO (`tried`). Un plato
  nunca probado alarga su **racha de variedad** (`variety`, el multiplicador
  x2, x3... que enseña una chapa dorada junto a su barra de paciencia) y
  recarga cada vez más (×1.2 el x2, ×1.3 el x3: `1 + 0.1×mult`, el primero
  normal). Un REPETIDO rompe la racha a CERO y sube la **escalera del hastío**,
  monótona por cliente: 1ª repetición recarga ×0.2, 2ª ×0.1, 3ª nada, y de la
  4ª en adelante **drena** la barra (−5%, −10%... del MÁXIMO, tope −20%; es
  fracción de la barra y no del plato porque multiplicar la recarga de un L1
  por un factor negativo daba drenajes del 1%, imperceptibles). Reglas clave:
  1) "nuevo" = **nunca comido por ESE cliente**, no "distinto del anterior"
  (con lo segundo, alternar dos platos sería combo infinito); 2) tras una
  rotura, los platos AÚN NO PROBADOS siempre reconstruyen — cuando ya probó
  todo, las únicas salidas son el té (reinicia el arco) y los EXTRAS, que
  hacen que ese plato cuente como nuevo; 3) el PICOTEO y el POSTRE ni suman
  ni rompen;
  4) el barco combinado vale DOBLE (`variety_worth` 2 en su receta);
  5) el multiplicador tiene TOPE (`client3d.variety_cap()`): **x5** de base,
  **x10** con el bonificador "Paladar de capitán" y el DOBLE de lo que toque
  mientras corre el potenciador "Doble variedad" — de ahí que haya chapas
  dibujadas hasta **x20**, que es el techo real del juego. Con el tope base:
  recarga máxima ×1.5, bono de oro +5 y postre de 15 al bote (30 con Sobremesa
  dulce), y encadenar jengibres más allá del quinto no rinde nada más; y el té
  REINICIA el multiplicador en vez de continuarlo (si continuara, la recarga
  crecería ciclando la carta y volvería el capitán inmortal).
  Con la carta de 4 huecos esto le da a cada cliente un ARCO FINITO y la
  ROTACIÓN emerge sola: agotada la variedad, o se le despide con postre o se
  desangra repitiendo. La elección de carta se vuelve equipo (3 principales +
  postre = arco x3 con cobro; 3 + té = ciclos sin cobro; los EXTRAS, que no
  ocupan hueco de carta, son la forma de superar su techo: un duplicado con
  wasabi o soja da el x4 antes de cobrar).
  **EL MULTIPLICADOR TAMBIÉN PAGA ORO EN CADA PLATO**: un plato NUEVO cobra su
  precio + 1 doblón por punto del multiplicador VIGENTE (con un x4 puesto, un
  plato de $3 deja $7; el bono usa la chapa de ANTES de contar el plato, que
  es la cuenta que el jugador hace mirándola). Los repetidos no cobran extra y
  el postre cobra por su canal (la propina × mult). Va por `current_price`,
  así que entra en el dinero BASE (estrellas y cierre por objetivo). Es lo que
  hace que el multiplicador valga también sin postre — y lo que acabó subiendo
  los EXTRAS a 10 doblones el uso, porque son la llave para seguir cobrándolo
  cuando ya no quedan platos por probar.
  **UI**: bocadillo de CÓMIC **SIEMPRE PRESENTE** desde el primer plato,
  **HORIZONTAL y colgando POR DEBAJO de la cabeza, con la COLA ARRIBA**,
  hacia el lado EXTERIOR del cliente (a la izquierda si su silla cae en la
  mitad izquierda de la pantalla; el lado se decide UNA vez al crearlo).
  **CUELGA HACIA ABAJO A PROPÓSITO**: por encima de la cabeza está la franja
  de las barras, y con el bocadillo ahí arriba tapaba las barras del cliente
  de AL LADO — y la barra del vecino tapaba a su vez la chapa. Debajo no hay
  nada que estorbar (medido: barra 214-227, bocadillo 228-290, cero solapes
  con ninguna barra de la mesa).
  `bocadillo.png` es el del lado derecho (cola arriba-izquierda; el arte se
  genera con la cola abajo y `build_bubble` lo VOLTEA con `ImageOps.flip`) y
  `bocadillo_esp.png` su ESPEJO horizontal, como las manos ic_mano_izq/der;
  9-slice de 62 px de alto dibujado 1:1 que solo estira su banda central
  blanca a lo ancho, con la cola protegida en el margen SUPERIOR (ocupa las
  filas y 0-9, medidas sobre el PNG).
  **DOS COSAS QUE HAY QUE ACERTAR PARA QUE LA COLA SEÑALE A LA CABEZA**, las
  dos vividas como "el bocadillo no apunta a nadie":
  1) **La punta de la cola NO está en el canto**: cae a `BUBBLE_TAIL_X` (15 px)
  hacia dentro, así que el bocadillo se coloca RESTANDO esa distancia, no
  pegando el canto a la cabeza.
  2) **`_head_screen()` NO es donde está la cabeza**, es un punto a
  `_height + 0.22` sobre la RAÍZ. Para las barras vale (tienen que flotar por
  encima), pero un cliente SENTADO lleva el cuerpo bajado por `_sit_on_stool`
  y encogido por la pose: medido, su cabeza real está **23-34 px MÁS ABAJO**.
  Para el bocadillo está `_head_anchor()`, que le pregunta al ESQUELETO por el
  hueso "Head" y solo cae a `_head_screen()` si no hay rig. Con las dos
  puestas, el desvío punta-cabeza baja a ~3 px (lo que se mueve la cabeza al
  respirar entre que se coloca el bocadillo y se mide).
  **Y las BARRAS van en `z_index` 2, por encima de los bocadillos**: con ocho
  clientes alrededor de una barra isométrica hay vecinos que se pisan sí o sí
  (dos asientos opuestos del rombo caen en la MISMA x de pantalla, solo
  cambia la y), y de las dos cosas la que no puede quedar tapada es la barra
  — el bocadillo es memoria, la barra es urgencia. Los últimos 4 platos van
  SOLAPADOS: el recién comido entra por la DERECHA entero y encima, de cada
  anterior asoma una franja (`BUBBLE_SLIVER` 14) por su izquierda, y lleno,
  el más viejo se despide por la izquierda. El ancho mínimo (un plato) es 52,
  JUSTO la suma de los márgenes del 9-slice: por debajo las esquinas se pisan.
  **Los deslizamientos de los iconos van con destino ABSOLUTO por
  antigüedad, no relativo**: dos empujones muy seguidos creaban dos tweens
  sobre la misma propiedad y el segundo leía la posición vieja — dos iconos
  acababan montados en la misma casilla. Los platos con extra lucen UNA
  estrella, en la esquina superior IZQUIERDA a propósito: es la franja que
  sigue asomando cuando el plato siguiente se solapa encima (con dos, una por
  esquina, el solape tapaba a veces la derecha y parecían tener unas veces una
  y otras dos).
  **ATENUACIÓN**: los bocadillos viven a media luz (`BUBBLE_DIM` 0.5) y solo
  el del cliente que ACABA de coger plato luce a plena luz `BUBBLE_HOT` s —
  ocho bocadillos permanentes a plena luz eran ocho manchas blancas.
  El multiplicador es una chapa gráfica (`mult_x2..mult_x20`, una por valor;
  se generan todas de golpe porque están DIBUJADAS y no cuestan trabajo) que cabalga la
  esquina INFERIOR EXTERIOR del bocadillo (abajo, lo más lejos posible de la
  franja de barras), entra con golpe y giro al subir y se encoge al romperse
  la racha. **Las chapas se DIBUJAN en `build_mult_badges` de ui2_prep**
  (moneda de oro con borde marrón y la Exo 2 Bold real, supermuestreada 8x,
  paleta del set): la tanda generada con Ludo salía con estallidos de cómic
  que no casaban con la madera y el pergamino, y cada chapa de su padre.
  **La chapa es HIJA del bocadillo**: se dibuja siempre por encima de él
  (nació aparte en world_ui y el bocadillo, añadido después, la tapaba) y
  hereda su atenuación gratis.
  **DOS TRAMPAS de la chapa, las dos vividas como "el multiplicador no
  sube":** 1) el tween de encogido al ROMPERSE la racha acaba poniendo
  `visible = false`, así que si la racha vuelve a subir dentro de esos 0.24 s
  ese tween seguía vivo y apagaba la chapa con el multiplicador ya alto —
  ahora se guarda en `_badge_tween` y se MATA al entrar en `_set_variety`
  (pasa constantemente desde que los extras hacen "nuevo" a un repetido:
  romper y volver a subir es la secuencia normal). 2) La chapa nace DENTRO
  del bocadillo, que se crea con el primer plato, o sea DESPUÉS de que
  `_apply_meal_patience` haya llamado a `_set_variety` — que sale por la
  puerta de atrás si la chapa aún no existe. Por eso `_push_bubble_icon`
  vuelve a llamar a `_set_variety(variety, false)` tras crearla: sin eso, un
  primer plato que ya valga x2 (el BARCO, que suma 2 de golpe) dejaba la
  chapa invisible hasta el plato siguiente.
  OJO al leer capturas: la fila de CABEZAS del HUD enseña "xN" de texto bajo
  cada cara (cuenta por tipo) — no confundirla con la chapa, ya pasó dos
  veces.
- **Postres que LIBERAN EL ASIENTO** (`leaves_seat`): mochi (grumetes),
  dorayaki (piratas) y taiyaki (capitanes). Al terminarlo el cliente paga,
  **cobra el multiplicador de variedad** (`VARIETY_TIP_PER_STEP` 3 doblones por
  punto, al bote — el VIGENTE, no el más alto alcanzado: el postre es un
  aliciente, no un premio decisivo) y **se marcha en el acto**, dejando la
  silla libre: es la única forma de echar a un cliente sin esperar a que se le
  agote la paciencia. (El antiguo `leave_tip_bonus`, un % de la propina
  acumulada, se fue: con ~$3-6 de propinas por cliente pagaba ~$0-1 y no se
  notaba.) Van con `only_type`, así que **solo los coge su tipo** — el
  descarte va ANTES de tirar el dado, así que ni con potenciadores los coge
  otro. La ficha del recetario lo refleja (si no, mentiría).
- **`patience_freeze`** (unagi glaseado): al terminarlo, la barra de paciencia
  se queda **congelada N segundos** (5) y se tiñe de azul. Como además se come
  en menos de la mitad de tiempo (`eat_mult` 0.45), sirve para encadenar dos
  platos sin que la espera del medio cueste nada.
- **`slice_board` con `direction`**: `"v"` corta de ARRIBA ABAJO (el dorayaki
  partido por la mitad) en vez del barrido lateral de los pescados; el recorrido
  exigido es `SLICE_SWEEP_V` (150 px) en lugar de `SLICE_SWEEP` (360), porque la
  tabla mide 312 px de alto y 520 de ancho, y la barra se normaliza para que se
  llene igual en los dos casos. `"alt"` ALTERNA el sentido en cada pasada (el
  pincel del nigiri de anguila: primero de izquierda a derecha y luego de vuelta).
  Con `brush: true` el cartel dice "¡Unta!" en vez de "¡Corta!", y con `prop`
  aparece el utensilio en la esquina (el `pincel`), decorativo.
- **`fry_board` con `windows` PROPIAS**: cada receta puede traer sus franjas en
  vez de las de la tempura. El **yaki onigiri** (a la plancha) y el **nigiri de
  wagyu** (soplete cronometrado, con `prop: "soplete"`) usan tablas mucho más
  indulgentes: pasarse o quedarse corto NO tira el plato, solo lo deja en el
  precio bajo. Clavar los 2.00 s dobla o triplica el precio bueno (yaki 3/8/14,
  wagyu 12/16/30). El logro del punto perfecto compara con el techo de ESAS
  franjas, no con el de la tempura.
- **Los rollos rinden por MAESTRÍA, no por lote**: el uramaki California y el
  dragon roll (`free_uses` 2) sacan UNA pieza y las siguientes salen ya hechas,
  igual que los makis. Se intentó con un campo `yield` que emplataba 3 y 5
  piezas de golpe y NO es lo que se quiere.
  **`free_uses` no pasa de 2 en ninguna receta** (el sashimi de tamago tenía 4
  y el hana maki 3): cada punto de maestría multiplica el rendimiento de la
  receta casi entero, así que es la perilla más peligrosa de la carta. Al
  tocarla hay que rehacer el precio POR PIEZA (ver el calibrado, arriba).
- **En un paso de tiempo (`fry_board`), el utensilio tiene que ser la etapa del
  paso ANTERIOR**: `stages[i]` es lo que se ve DESPUÉS del paso i, así que la
  sartén del yaki onigiri iba una casilla tarde y durante la fritura se veía la
  bola de arroz pelada. Mismo patrón que la tempura con `sarten_frito`.
- **`swipe_board` con `direction: "alt"`**: alterna izquierda↔derecha en cada
  pasada (el rebozado en sésamo del California). La barra del deslizamiento se
  llena **sobre la marcha** (`swipe_progress`): con `count` 1 solo saltaba de 0
  a 1 al terminar y parecía rota.
- **El sésamo es GRATIS** (`cost` 0, como el arroz): ni se compra en la tienda
  ni gasta usos de despensa.
- **Postres**: `tip_always` = la propina cae SIEMPRE (mínimo 1 doblón) y
  `no_extras` = no se les puede echar jengibre, wasabi ni soja. Sus precios son
  bajos a propósito (mochi 3, dorayaki 5, taiyaki 10): lo que dan es liberar el
  asiento y llenar el bote, no dinero de plato.
- **Los EXTRAS van en la esquina superior izquierda de la mesa pero POR DEBAJO
  de los ingredientes**: cuelgan de `BoardPanel` y se colocan al PRINCIPIO del
  árbol con `move_child`, así se dibujan sobre la madera y bajo la fila de
  ingredientes, la etapa y el plato. **Todo lo que quede por delante de ellos en
  el árbol tiene que estar en `MOUSE_FILTER_IGNORE`** o se traga sus toques: la
  fila de ingredientes, sus iconos y —el que costó encontrar— **`TapZone`**, que
  cubre la mesa entera. Ninguno de los tres usa el sistema de interfaz: se
  detectan por rectángulo desde `_input`.
- **`hint_root` va en `z_index` 110**: la fila de cabezas de cliente del HUD se
  añade DESPUÉS que la tabla y tapaba la mano justo cuando indica llevar el
  plato a la cinta. Los carteles modales siguen por delante (120).
- **EXTRAS (jengibre / wasabi / soja)**: no son platos, son añadidos que se
  marcan con el plato YA hecho (tres botones arriba a la izquierda de la tabla,
  con "+" y check verde). Los botones están **SIEMPRE a la vista** —así se sabe
  que existen desde el primer momento—, pero **semitransparentes y `disabled`**
  mientras no haya plato terminado o no queden usos en la despensa, y opacos
  cuando se pueden usar. Al pulsarlos dan un **bote** (`_bump_extra`: encoge y
  rebota), porque en 64 px el check solo se perdía. Se gastan **por plato
  servido**, no por partida
  (`GameState.consume_extra`) y el tendero los tiene siempre.
  **LOS TRES hacen que el plato cuente como NUEVO** aunque el cliente ya lo
  haya probado: no rompen la racha de variedad, la ALARGAN, esquivan la
  escalera del hastío y cobran el bono de oro del multiplicador. Eso rompe el
  techo de la carta, así que **los tres traen contrapartida** y **cuestan 10
  doblones** el uso (2 → 5 → 10 según fueron ganando poder):
  · **jengibre** → reinicia el PALADAR entero (`tried.clear()`: todos los
    platos vuelven a contar como nuevos, ESE INCLUIDO — el mismo plato se le
    puede repetir acto seguido y contará como nuevo), pero BAJA un punto de
    multiplicador. Es un té verde de pago que conserva casi toda la racha.
    **LIMPIAR EL PALADAR BORRA TAMBIÉN LA ESCALERA DEL HASTÍO**
    (`client3d._limpiar_paladar`, que vacía `tried` Y pone `repeat_count` a 0).
    `repeat_count` solo subía y no lo reiniciaba nadie, así que la limpieza era
    media limpieza: el cliente olvidaba QUÉ había comido pero seguía contando
    CUÁNTAS veces le habían repetido, y la primera repetición después del
    jengibre caía en el peldaño siguiente — con la escalera ya arriba,
    DRENANDO la barra. Pagar 10 doblones y un punto de multiplicador para que
    el siguiente repetido castigara igual que antes es lo que se veía como
    "el jengibre no ajusta bien el multiplicador". Lo usan las TRES cosas que
    limpian: el jengibre, el té verde y la sopa de miso.
  · **wasabi** → +15% de PROBABILIDAD de propina, pero en vez de recargar
    paciencia **DRENA** exactamente lo que habría recargado.
  · **soja** → +15% de CUANTÍA de la propina, pero el bocado corre a
    `SOJA_BITE_SPEED` (1.6) y, como la paciencia NO baja mientras se come,
    acortar el bocado devuelve al cliente a la cola antes de tiempo.
  Viajan con el plato:
  `dish_served(id, precio, extras, nivel)` → `plate3d.extras` → `client3d`.
- **Aburi con elección**: `get_ingredients` incluye las `options` de los pasos
  de elección, así que llevar el aburi a un nivel consume usos de LOS DOS
  pescados (en partida se puede elegir cualquiera).
- **Barco combinado (montaje)**: la bandeja da un BOTE elástico con cada plato
  colocado y lleva un overlay del barco cargado (`boat_fill`) cuya opacidad
  crece con los platos puestos.
- **Extras**: `extras_chosen` se limpia en `_finish_prep` y `_start_prep` —
  cada plato empieza SIN extras aunque el anterior los llevara.
- **Tienda**: los tres extras van en su propia balda (`extras_row`), pequeños y
  centrados bajo la parrilla del género del día, con **icono, nombre y
  "$2 · xN"** y **SIN fondo propio** (el `Button` trae un panel oscuro del tema
  por defecto que sobre el pergamino parecía una mancha: se anula con
  `StyleBoxEmpty` en los cinco estados, igual que los artículos grandes). El
  cartel es más alto (`shelf` -900) y la escena 3D va más arriba (`band_off`
  372). Los extras **NUNCA entran en el sorteo del día** (`roll_shop_stock` los
  salta): el tendero los tiene siempre, así que sortearlos gastaba un hueco de
  los 8. Un guardado viejo con extras dentro se rehace solo
  (`_stock_has_extras`).
- **Aviso momentáneo de la tabla** (`_flash_message`: "¡Más lento!",
  "¡Perfecto! $15", "¡Barco! $26"): va **por encima del hueco donde se emplata**
  y con `z_index = 90`. Centrado en el medio exacto quedaba tapado por el plato
  (y por el barco), que se añaden DESPUÉS al árbol.
- **La zona activa de la tabla (`TapZone`) ocupa TODO el panel de la mesa**
  (0,0–520,312), no un recorte interior: el límite invisible no coincidía con la
  madera dibujada y había toques que no entraban. Como ahora cubre también la
  fila de ingredientes, `drag_ingredient` y `drag_choice` exigen **arrastre real
  >24 px** (`drag_moved` / `choice_moved`): si no, un simple toque sobre el
  ingrediente contaría como haberlo soltado ya en la tabla.
- **Soplete del aburi**: dos sprites (`soplete_off` en su rincón, `soplete_on`
  con la llama latiendo mientras se agarra). Sigue al dedo, y sacarlo de la
  tabla lo devuelve apagado a su sitio **conservando la barra** (no hay que
  empezar el tostado de cero). La mano guía recorre un OCHO continuo y NO se
  reconstruye mientras se sopletea (si no, se queda clavada en el primer punto).
- **Platos de PICOTEO** (`snack: true`, de momento solo el edamame): el cliente
  puede cogerlos SIN dejar de comer el plato que tiene (`_scan_belt(true)` en el
  estado EATING de `client3d.gd`). **Rellenan la BARRA DE COMER, no la de
  paciencia**: alargan el bocado en curso un `SNACK_EAT_REFILL` (35%) de su
  duración, y como la paciencia NO se drena mientras se come, alargar el bocado
  es justo lo que retiene al cliente. Pagan `SNACK_BONUS` (+1) doblón extra.
  Repetir el mismo picoteo rinde cada vez menos (mismo `REPEAT_DECAY` que el
  aburrimiento), así que inundar la cinta de edamame no compensa. `take_chance`
  en la receta salta la matriz TAKE_CHANCES (si no, los capitanes nunca
  cogerían un plato de nivel 1).
- **Modificadores de cliente por receta** (`recipe_data`, aplicados en `client.gd`):
  `patience_mult` escala la recarga de paciencia al comer (makis + futomaki 0.8,
  sopa_miso 1.2, hana_maki 1.3; resto 1.0); `eat_mult` escala el tiempo de comer
  (sopa_miso 1.5, más lenta); `tip_chance_bonus` suma a la probabilidad de propina
  (gunkan_tartar +3%, sashimi_atun_rojo +4%, la 1ª vez, y la mitad por cada
  repetición del mismo plato). Los makis con penalización son maki_aguacate y
  maki_atun (el hana_maki es la excepción: recarga MÁS).
- **NINGÚN `tap_board` pasa de 3 golpes**, sea del nivel que sea. El esfuerzo de
  una receta lo marca ahora **de cuántos PASOS es y de qué tipo**, no de cuántas
  veces repites el mismo. Antes la escala subía por golpes (L1=3 · L2=4 · L3=5,
  con un `cutting` de 6 en el sashimi de tamago) y eso no hacía la receta más
  interesante, solo más larga: dar cinco toques seguidos donde antes dabas tres
  es la misma decisión repetida más veces. Se recortaron 19 pasos de 17 recetas.
  **Efecto secundario asumido**: las recetas de L2 y L3 se hacen algo más
  rápido que antes en relación con las de L1, que ya estaban en 3.
- **Escala por nivel** (el cooldown sí sube con el nivel): cooldowns aprox.
  L1 3–4 s · L2 4.5–5.5 s · L3 6.5–7.5 s. Al añadir/ajustar recetas, seguir esta
  escala.
- **APROBAR es sacar 2 ESTRELLAS** (`goal_stars` = 2 en todos los puertos):
  con 2★ el nivel queda superado, se abre el siguiente y caen las recompensas
  de `reward_recipes`. Las **3 estrellas piden bastante más dinero** y son un
  reto aparte, con premio propio: `reward_recipes_3` (recetas), `reward_ingots_3`
  (lingotes) y `reward_rice_3` (sacos). Se pueden ir a buscar más tarde,
  repitiendo el puerto con mejor carta; `complete_port` las entrega la primera
  vez que se llega a 3★, aunque el nivel ya estuviera aprobado.
- **`_score_money()` es SOLO el precio de los platos** y `_star_money()` es
  `platos + propinas` (ver arriba). El contador del HUD y el corte anticipado
  van con el primero; las estrellas y el total del cartel, con el segundo.
  Ojo con el histórico: `_score_money` llegó a devolver `money_earned +
  tips_total` y entonces cada propina se contaba DOS veces (subía el bote azul
  y además la barra verde del oro EN PARTIDA). Esa suma solo vale al CERRAR.
- **Puntuación POR DINERO** (la satisfacción se eliminó): cada umbral de
  `star_money` alcanzado da 1 estrella. El techo lo marca la
  PRODUCCIÓN (partida de 2:30 solo L1 ≈ $50-70; sube con piratas/capitanes que
  comen L2-L3). Umbrales por nivel en `campaign_data.gd`.
  **Cada tipo de nivel se calibra contra lo que DE VERDAD lo limita** (la
  cabecera de `campaign_data.gd` lo detalla): los ABORDAJES contra el reloj
  (150 s × los $/s de atención que rinde la carta), y las ISLAS y PUERTOS
  contra la clientela (clientes × platos × PRECIO medio de la carta). Confundir
  los dos da cifras imposibles: reescalando el nivel 2 por $/s pedía 127
  doblones cuando su techo real ronda los 75.
  Umbrales vigentes (campaña-escuela, BAJOS a propósito — aquí se aprende):
  n1 10/25/40 · n2 14/26/40 · n3 18/32/50 · n4 26/46/72 · n5 20/38/58 ·
  n6 28/52/82 · n7 32/55/88 · n8 36/62/95 · n9 40/68/105 · n10 30/55/90
  (en el 10 el aprobado es el JEFE, el dinero solo decide la 3ª estrella).
  Los seis primeros salen de la ancla que puso el usuario en el n1 —cuatro
  grumetes, 40 doblones para las 3 estrellas, o sea ~10 por grumete— escalada
  por clientela y por lo que aporta la mecánica del nivel (el 4 suma el bono de
  oro del multiplicador; el 5 suma propinas, que SÍ cuentan para estrellas).
  **Son de MODELO, no de partida jugada**: quieren una pasada real.
  **Y el aluvión de clientes se limita SOLO**: los abordajes programan más
  llegadas que asientos, pero un cliente no aparece hasta que se libera un
  sitio y uno sin comer aguanta ~50-60 s (`FIRST_PLATE_DRAIN` 0.45), así que
  el resto no llega a entrar — ni cobra su `LEAVE_PENALTY`.
  NO hay dinero extra por estrellas (economía limpia para la tienda).
  En aventura Y en el arcade el dinero va al monedero persistente: desde el
  rediseño del arcade sin fin, el modo libre es una jornada de verdad.
- **Probabilidades de coger plato** (`client3d.TAKE_CHANCES`), por tipo × nivel:
  grumete 0.95/0.20/0.10 · pirata 0.45/0.95/0.25 · capitán 0.10/0.55/0.95. Cada
  tipo tiene su nivel favorito casi asegurado y va bajando hacia los otros dos;
  **el dado se tira UNA vez por plato** (si falla entra en `declined` y no se
  vuelve a mirar). `take_chance` en la receta salta la matriz y admite las dos
  formas: un número igual para todos (edamame y té verde 0.9) o un diccionario
  `{E,A,G}` con uno por tipo (onigiri y yaki onigiri 0.85/0.70/0.70). Y
  `take_chances` sustituye la MATRIZ ENTERA: lo usa el barco combinado
  (`RecipeData.BOAT_TAKE_CHANCES`, 100/80/60 · 60/100/80 · 30/70/100), que es
  una bandeja para compartir y entra por los ojos a todo el mundo; se indexa por
  el nivel REAL del barco, el que sale de su contenido. Tiempos de comida por
  tipo×nivel en `EAT_TIMES`.
- **Propinas por plato** (`client.gd::TIP_RULES`, se tira al terminar CADA
  plato desde el 1º; la probabilidad se mantiene en la base hasta el 3er plato
  (`ramp`) y a partir de ahí crece por plato; cuantía = % del dinero ACUMULADO
  que lleva gastado el cliente hasta ese plato (no del precio de ese plato
  suelto), mín. 1 al acertar): grumete 20% de dejar el 15%, +1% por plato, tope
  65%; pirata 23% de dejar 16%, +1.5%/plato, tope 60%; capitán 25% de dejar
  18%, +2%/plato, tope 50%. El dinero (solo precio de platos) y las propinas
  (solo al bote) se abonan plato a plato, no al irse.
- Bote de propinas exponencial: umbrales acumulados 10, 22, 36, 52… (`TIP_INCREMENTS`).
- **UN CARTEL DE POTENCIADOR ABIERTO MUERE CON EL TURNO** (`_end_level`):
  pausaba el árbol y, con el nivel acabándose por debajo, el juego se quedaba
  clavado en la elección. Se cierra, se despausa y los pendientes se descartan
  — ya no hay partida en la que gastarlos.
- **El cartel de potenciador NO interrumpe un gesto sostenido**: si el jugador
  está manteniendo / removiendo / cortando lento / friendo / arrastrando
  (`prep_board.is_gesture_locked()`), la elección se aplaza y `_process` la
  saca en cuanto levanta el dedo — saltar a media faena arruinaba la receta.
  El cartel entra con rebote elástico y late despacio (`_animate_powerup_panel`;
  el panel va en `PROCESS_MODE_ALWAYS`, así que el tween corre con el juego
  pausado).
- Llegadas: horario escalonado con jitter; primero ~5 s, nadie en los últimos
  `ARRIVAL_TAIL` (22 s); `arrival_scale` (<1) comprime el horario (nivel 2 0.65).

## Flujo de trabajo por cambio

1. Editar el/los script(s) o `.tscn`.
2. `--headless --quit-after` en ambas escenas → 0 errores.
3. Si es visual: helper inyectado → screenshot → revisar → corregir → limpiar helper.
4. Lanzar el juego para el usuario.
