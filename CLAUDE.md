# Sushi Pirata — guía del proyecto

Juego móvil **vertical (720×1280)**, 2D isométrico voxel/pixelart, de **estrategia y
gestión en tiempo real**. El jugador es el cocinero de un barco pirata que sirve
sushi en una **cinta transportadora kaiten** a clientes con comportamientos
distintos. Partidas de **2 min 30 s** (`TIME_LIMIT`, sin contar la fase de
preparación inicial). Motor: **Godot 4.7.1**.

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
- `level.gd` accede a `prep_board.instant_recipes / skip_next_cooldown /
  easy_next / double_next / stack_max / cooldown_mult` para aplicar potenciadores.

## Guiones narrados (tutorial y primeros niveles)

- `scripts/story_director.gd` (`StoryDirector`) es la BASE de todo guion sobre
  `level3d`: pausa el árbol entero al hablar (`get_tree().paused`, con la caja
  y el director en `PROCESS_MODE_ALWAYS`), retiene el reloj (`lv.clock_hold`),
  pinta el FOCO circular y vigila la inactividad. Las hijas solo escriben
  `_run()`. De ella cuelgan `tutorial_director.gd` y `level_director.gd`.
- **FOCO**: el radio sale del LADO MAYOR del rectángulo, no de la diagonal
  (con la diagonal un botón de receta pedía 135 px y el círculo se comía media
  tabla), acotado a 48-150 px. Y `_focus_node()` **espera DOS fotogramas antes
  de medir**: los contenedores de Godot recolocan a sus hijos de forma
  diferida, así que justo después de tocar `allowed_recipes` el botón sigue en
  su sitio VIEJO — de ahí que los focos del nigiri y del té cayeran al lado
  del pergamino en vez de encima.
- **Vigía de inactividad**: 10 s sin tocar nada en una fase interactiva y Gigi
  grita "¡ESPABILA!" + el recordatorio que dejó puesto `_play(aviso)`. No salta
  con alguien hablando ni con un gesto sostenido en curso
  (`prep_board.is_gesture_locked()`), que se arruinaría.
- **Cliente del tutorial**: asiento **3**. Con la cámara isométrica (yaw 45) el
  eje +X cae hacia ABAJO-DERECHA, así que la cara +X son los asientos 2 y 3 y
  el 3 es el más bajo; además esa cara entra por la borda inferior.
- **Orden del tutorial**: maki → cinta/cajas → primer cliente → oro → **nigiri
  de salmón** (con `client.slow_eat` ×4.5, para que dé tiempo a explicar cosas
  mientras mastica) → Gigi explica la **barra de comer** → **té verde** →
  David explica la **barra de paciencia** (foco en la barra del cliente, ya sin
  comer) → mochi → por qué conviene echar clientes. El "aburrimiento" se llama
  ahora **hastío** y la barra gris es la **paciencia**.
- `scripts/level_director.gd` narra los puertos que llevan `director` en
  `CampaignData`. Nivel 1: qué pasa si un plato da la vuelta entera (se cuenta
  EN CALIENTE la primera vez que ocurre; si no ocurre, a media partida).
  Nivel 2: bienvenida al puerto, consejos, el castigo por dejar marchar a
  alguien de vacío (en caliente o, si no pasa, al llegar al 70% del objetivo)
  y, al cerrar, las primas de sobrantes. Nivel 3: el pirata entra el último
  (`late_type` en el puerto) o se adelanta al 60% del objetivo, y David regala
  el **nigiri de atún** metiéndolo en la tabla EN MARCHA
  (`prep_board.add_recipe`). Nivel 4: presenta el BARCO combinado nada más
  empezar. Nivel 5: la flota de **Pablo el Rubio** — presentación de Pablo
  (con su broma de apuñalar a David), y cuando por fin se sienta a la barra,
  regalo del **salmón tsuke don** con la explicación del corte lento.
  **El `match` de `_run()` hay que ampliarlo con cada guion nuevo**: `_nivel_4`
  estaba escrito pero sin su rama, así que David no aparecía en el nivel 4
  ni con partida nueva.
- **Cliente ESPECIAL de un puerto** (`special_client` en `CampaignData`):
  `{who, type}` hace que UNO de los clientes de ese tipo salga con un modelo
  propio (`client3d.who_override` → `CharacterData.MODELS`), sin tocar el
  equilibrio: come, paga y aguanta como los de su tipo. Con `late_type` del
  mismo tipo, entra el último. Lo usa Pablo el Rubio en el nivel 5. La fila de
  cabezas del HUD sigue contando por TIPO, pero la CARA sale de `head_who`
  (el personaje del primero de ese tipo que llegó), así que en el nivel 5 el
  capitán de la fila es Pablo. Su icono lo genera `tools/head_icons.gd` como
  el resto, con un encuadre propio en `FRAME_OVERRIDE` (su sombrero es mucho
  más alto y se le cortaba por arriba).
- **El contador de clientes del HUD cuenta los que HAN LLEGADO**
  (`clients_spawned`), no los que se han ido: con los idos se quedaba en 0 con
  la barra llena, que es justo cuando interesa saber cuánta clientela queda.
  Y quien adelante una llegada a mano (`_adelantar_tipo` del guion) tiene que
  **gastar su hueco de `arrival_queue`**, o entra un cliente de más y el
  contador se pasa del total.
- **`recipe_slots` solo recorta la carta la PRIMERA vez**: al repetir un puerto
  ya superado se juega con los cuatro huecos de siempre (`prep_screen` y la
  ficha del mapa lo comprueban con `level_stars`).
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
- **`prep_board.free_mistakes`**: mientras un guion ESTÁ ENSEÑANDO un gesto,
  fallar el corte lento no cuesta dinero (el aviso y el destello rojo siguen).
  El guion se entera por la señal `slice_failed`, aparte de `money_penalty`
  justamente para poder regañar sin cobrar.
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
- `scripts/powerup_data.gd` — catálogo de potenciadores DE PARTIDA (`manual` =
  el jugador elige cuándo; si no, automático). Salen del bote de propinas
  dentro del nivel.
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
  Solo funcionan en aventura: Arcade no toca el progreso.
- `scripts/campaign_data.gd` — los 9 niveles de la campaña (`PORTS`, ordenados):
  `client_mix` (recuento EXACTO {E,A,G}; el nivel construye una cola barajada y
  `total_clients` sale de la suma), `time_limit` (150 s; nivel 7 es exprés de
  90 s), `patience_mult`, `arrival_scale` (<1 = llegan más seguidos),
  `goal_stars` (3 en todos), `star_money` ([$1★,$2★,$3★], calibrado al techo de
  producción de cada nivel) y `reward_recipes`. **El reparto sigue a la
  CLIENTELA del puerto**: donde solo hay grumetes caen recetas de nivel 1, los
  piratas traen las de nivel 2 y los capitanes las de nivel 3; los postres van
  al puerto donde ya se sienta su tipo (`only_type`). Entre las 2 iniciales y
  las 32 recompensas quedan cubiertas las **34 recetas visibles**; las `hidden`
  (barco, combinados, variantes de fritura) no se desbloquean nunca: salen de
  sus propias mecánicas. También
  `INITIAL_RECIPES` e `INITIAL_INGREDIENTS` de partida nueva.
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
  animaciones) y las HORAS JUGADAS (`play_seconds`, que solo suma `level3d`
  dentro de una partida: los menús no cuentan). El nombre y el género van
  aparte, en `player_name` / `player_gender`; los guardados de la primera
  versión de Opciones los traían dentro de `settings` y se rescatan al cargar.
  `apply_graphics()` aplica lo global (escala de render 3D y `Engine.max_fps`);
  sombras y animaciones las consulta cada escena al construirse
  (`shadows_on()` / `animations_on()`). `reset_progress()` borra el progreso
  pero **respeta los ajustes**: no son progreso.
- `scripts/achievement_data.gd` — catálogo de LOGROS (`AchievementData`), solo
  datos: id, apartado, texto, `stat` y tres metas (bronce/plata/oro). El
  progreso NO se guarda por logro: se deduce de `GameState.stats`, así que un
  logro nuevo funciona hacia atrás si su estadística ya se contaba. Los logros
  "prepara N raciones de X" se generan solos de `RecipeData.RECIPES` (uno por
  receta no oculta; las ocultas —barco, combinados— tienen el suyo a mano).
  `GROUP_TABS` son los rótulos CORTOS de las pestañas: cinco tablones de madera
  en 720 px solo dejan ~84 px de texto entre las esquinas doradas.
- `scripts/options_screen.gd` — Opciones (raíz **Node3D**, fondo `SceneBackdrop`)
  en TRES pestañas: **Perfil** (nombre y género —se elige TOCANDO AL PERSONAJE,
  no un botón con su nombre—, con "Aplicar cambios"),
  **Gráficos** (bloques Alta / Media / Baja / Personalizado, también con
  "Aplicar cambios") y **Progreso** (horas jugadas y borrado). Los cambios
  viven en `draft_*` y NO tocan `GameState` hasta pulsar aplicar: así se puede
  probar una combinación y arrepentirse. Tocar un ajuste suelto pasa el bloque
  a "Personalizado" (`current_preset()` lo deduce comparando, así que el cartel
  nunca miente). **Borrar progreso va en dos pasos**: confirmación y después
  MANTENER pulsado 5 s con una barra roja que se vacía si se suelta antes;
  al llenarse borra y vuelve al menú desde negro.
- **Los tres géneros del jugador** (`CharacterData.PLAYER_GENDERS`): masculino
  `chef_rig.glb`, femenino `chef_fem_rig.glb` y neutro `chef_neutro_rig.glb`
  (personaje andrógino propio, generado y rigueado para esto). `model()` cae al
  masculino si falta el archivo. El ayudante es del género contrario; con el
  jugador neutro es el femenino.
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
  chef neutro salía sin rasgos.
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
  **Saverio sale a la DERECHA** y David a la izquierda: en la escena de la
  tienda están los dos a la vez y el que no habla se queda apagado y hundido.
  El tablón del nombre va en el lado CONTRARIO al retrato de quien habla —
  encima del suyo le tapaba el pecho y se salía por el borde.
  **Encuadre**: Saverio se generó primero demasiado cerca (su cabeza ocupaba
  el 47% del alto frente al 30% de David) y hubo que rehacer la base pidiendo
  explícitamente "cámara MUCHO más atrás, de la cintura para arriba, con aire
  sobre la cabeza" y volver a derivar las expresiones desde ahí.
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
  `scripts/david_intro.gd` + `scenes/david_intro.tscn`: bienvenida (primera
  vez) DESDE LA CUBIERTA del barco (cubierta propia construida por código:
  tablones, barandilla al fondo, mástil con vela que respira, carga — NO el
  barco visto desde fuera), pide nombre (teclado) y género (tocando los
  retratos del chef) y salta al tutorial.
  `scripts/tutorial_director.gd`: guion del tutorial SOBRE level3d —
  **mientras David habla se PAUSA el árbol entero** (clientes y platos
  quietos; caja y director en PROCESS_MODE_ALWAYS), **foco CIRCULAR degradado**
  (`shaders/tutorial_focus.gdshader`, dim 0.78, radio acotado 70-230 px:
  enfocar contenedores anchos del HUD daba un círculo tan grande que no se
  percibía — enfocar las LABELS concretas, no sus filas), permisos por fase
  (`prep_board.allowed_recipes`), cliente fijo en el asiento 4 con paciencia
  clavada y `guaranteed_next` en cada servicio; enseña maki (guiado paso a
  paso) → cinta/cajas (rama según dónde lo deje) → té verde → nigiri → mochi
  (despide al cliente) → recetario, y al acabar `complete_tutorial()` y menú.
  En modo tutorial level3d NO termina solo (`_end_level` ignora reloj y
  clientes), sin botón Salir, sin fase de preparación, `tutorial_mode` oculta
  barco/combinar/extras. `GameState`: `tutorial_done` persistente (los saves
  viejos con recetas lo dan por hecho; **`_new_game` DEBE ponerlo a false** —
  se olvidó y borrar la partida no relanzaba la intro), `is_tutorial()`,
  `complete_tutorial()` (entrega `CampaignData.INITIAL_RECIPES`:
  maki_aguacate, nigiri_salmon, te_verde y mochi — SOLO se desbloquean así),
  `arcade_unlocked()` (= superar `GameState.ARCADE_PORT`, el **nivel 10**, que
  todavía no existe en la campaña: hasta entonces el Arcade sigue cerrado); el menú manda a la intro si falta
  el tutorial y el botón Arcade queda apagado con aviso hasta ganarlo.
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
  (`PATIENCE_DRAIN_PER_PLATE` ×0.025 por plato). `EAT_TIMES` es una matriz
  tipo×nivel de plato (subida ~20% para el ritmo 3D); `PATIENCE_FOOD` recarga
  paciencia según el nivel del plato (L1 9% · L2 22% · L3 38%, rebajada para
  que cada plato retenga menos) escalada por el "aburrimiento" (`boredom`):
  repetir el MISMO plato sube el nivel y recarga ×0.4 cada vez
  (`REPEAT_DECAY`, endurecido desde 0.5); cambiar de plato NO reinicia, solo
  retrocede un nivel.
- `scripts/level.gd` — orquestador 2D ORIGINAL (referencia hasta terminar la
  conversión 3D; el juego ya NO lo usa): cinta (Line2D por tramos), spawner por
  horario (configurado por el nivel de campaña), HUD, propinas/potenciadores,
  puntuación POR DINERO, panel de resultados (anuncia recetas desbloqueadas).
- `scripts/level3d.gd` + `scenes/level3d.tscn` — **el nivel EN USO** (3D low
  poly, mismo HUD 2D): port 1:1 de la lógica de level.gd sobre un mundo 3D
  construido por código (cámara iso ortogonal pitch −35.264/yaw 45/**size 17**;
  circuito = cuadrado de 3.6 u; platos 0.9 u/s). **Escenario según el TIPO del
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
  en fase de preparación DEVUELVE los usos de ingredientes, en partida avisa de
  que se pierden; vuelve a level_select3d (aventura) o main_menu (prueba). La
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
  cinco botones con icono propio: **Aventura** (campaña), **Arcade** (partida
  libre con todas las recetas, sin tocar el progreso), **Tienda**,
  **Inventario** y **Tutorial** (más bajito, con la cara de David de
  `ic_tutorial.png`: repite el nivel guiado DIRECTO, sin la bienvenida de
  nombre/género, y no toca el progreso), más dos **botones REDONDOS de esquina**
  sin tablón de madera
  (el dibujo es el botón, con su mancha de sombra y el rótulo dentro del alto):
  la **medalla de Logros** arriba a la izquierda y la **rueda de Opciones**
  arriba a la derecha. El rótulo va DENTRO del alto del botón: colgándolo por
  debajo se salía de la pantalla. **El menú NO enseña el monedero**: el dinero
  solo sale donde se puede ganar o gastar (mapa de aventura, tienda e
  inventario), y su hueco de la esquina lo ocupa la rueda; se probó a poner la
  rueda abajo a la derecha y se montaba encima de "Inventario".
  El fondo es una **escena 3D animada**: el barco del jugador
  (`map_barco.glb`) cabecea y se balancea en mar abierto (mismo
  `water_map_3d.gdshader` del mapa). El logotipo
  (`assets/ui/logo_sushi_pirata.webp`, generado con Ludo y recortado con
  `tools/logo_prep.gd`) flota y se balancea en el CanvasLayer 2D.
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
  **Todo está animado**: el mar usa `shaders/water_map.gdshader` (repite la
  textura y la hace derivar y ondular sin fin) y el barco pasa los 16 fotogramas
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
  **Despensa** (otro libro, 8 ingredientes por doble página con sus usos) y
  **Mejoras** (potenciadores permanentes de `PerkData`: los no conseguidos
  muestran cómo se ganan; los conseguidos, sus usos y un botón para comprar más).
- `scripts/scene_backdrop.gd` — `SceneBackdrop.build()`: fondo 3D reutilizable
  (mar animado + el modelo del tipo de nivel) que usan prep_screen, la tienda y
  el inventario. La UI va en un CanvasLayer con un velo oscuro por delante.
- `scripts/prep_screen.gd` — selección de HASTA 4 recetas (raíz **Node3D**):
  el fondo es el **escenario 3D del nivel elegido** (isla / puerto / barco
  enemigo, o el barco del jugador en Arcade) meciéndose sobre el mar. En
  aventura solo lista las desbloqueadas y ataja las que no tienen usos de
  ingredientes ("Sin ingredientes"); en Arcade, todas. Recetas **agrupadas por
  nivel de estrellas**, **4 tarjetas por fila** sobre un pergamino compartido.
  Debajo, la fila de **potenciadores permanentes** disponibles (solo aventura),
  y el botón "¡Zarpar!". Arriba, "Atrás" (al mapa en aventura, al menú en
  Arcade). NO lleva el título "Sushi Pirata".
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
  Las imágenes de UI generadas con Ludo se recortan con `tools/ui_prep.gd`
  (inundación desde los bordes + recorte + reescalado). Para los ICONOS con
  fondo gris claro la inundación deja halo: se pasan antes por el
  `removeBackground` de Ludo y `ui_prep` solo recorta y reescala.

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
  el `flip` de la otra para que sean idénticas), tanto en la bienvenida de
  David como en Opciones → Perfil. **La generada por Ludo es la mano
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
  un salto. Nada de esto sirve sin la opción de exportación de arriba.
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
  desglose no dejaba ni desplazar ni cerrar por esto.
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
  probó dejándolo meciéndose en su sitio y no es una transición.
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
  la cinta exige soltar sobre su franja. Desde una caja se sirve solo con
  arrastre real (>24 px), nunca con un toque.
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
  en el botón. El potenciador "Reciclaje" añade +1 uso cuando un plato se desecha.
- **Botones de receta (in-game)**: fondo de **pergamino** (`panel.png`, no madera),
  plato grande y uniforme mirando abajo-derecha, estrellas en la franja inferior.
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
- **El nivel TERMINA en cuanto se alcanza el dinero objetivo** (el umbral de
  3 estrellas): `_check_goal_reached()` tras cada plato cobrado.
- **Las ESTRELLAS salen solo del dinero de PLATOS**; lo que se COBRA al acabar
  es `platos + propinas + primas`. Primas: **3** doblones por cada grumete que
  se quedó sin venir, **8** por pirata, **15** por capitán
  (`LEFTOVER_BONUS`), y **3** por cada bloque completo de **10 s** de reloj
  sobrante. El desglose del panel de resultados los enseña por separado.
- **Regalo de ingredientes**: al desbloquear recetas el juego da usos de todo
  lo que piden (`GameState.gift_ingredients_for`): **5** con el tutorial
  (`TUTORIAL_GIFT`) y **3** por cada nivel superado (`PORT_GIFT`). Los
  ingredientes gratis (arroz, sésamo, `cost` 0) se saltan.
- **El MENÚ anuncia las recetas nuevas** (`GameState.pending_reveal`, que
  llenan `complete_tutorial`/`complete_port` y consume `main_menu`): pergamino
  con los platos entrando de uno en uno con su bote.
- **La TIENDA se gana** superando el puerto que la trae (`unlocks_shop`, el
  nivel 2); el botón del menú queda apagado hasta entonces. La PRIMERA visita
  es una escena: David presenta a **Saverio**, que explica la tienda y los tres
  extras y regala 5 usos de cada uno (`shop_intro_done`, persistente, que es
  además lo que abre los **extras**: antes de esa escena no existen).
- **El surtido de la tienda solo trae ingredientes de recetas DESBLOQUEADAS**
  (`roll_shop_stock` filtra por `unlocked_recipes`), y `unlock_recipe` pone
  `shop_day = ""` para que el surtido se rehaga al aprender algo nuevo.
- **Campos nuevos de puerto en `CampaignData`**: `fixed_recipes` (carta
  cerrada), `recipe_slots` (huecos que se pueden llevar, 4 por defecto),
  `no_extras` (oculta extras, combinar y barco → `prep_board.hide_extras`),
  `late_type` (ese tipo de cliente entra el último), `unlocks_shop` y
  `director` (guion narrado).

## Balance actual (para no re-litigar)

- **Precios (doblones)**: edamame 1, gari 1, te_verde 1, maki_aguacate 2,
  nigiri_salmon 3, gunkan_wakame 3, onigiri 4, sopa_miso 4, maki_atun 5,
  udon 6, nigiri_atun/inari 6, sashimi_tamago 6, gunkan_tartar 7 (L2),
  temaki 7, gunkan_ikura 8, futomaki 10, sashimi_atun_rojo 11, nigiri_ebi 11,
  fugu 11, hana_maki 12, aburi 12, chirashi 16; moriawase dinámico (~26-90).
  salmon_tsuke_don 14 (regalo de David en el nivel 5).
  Postres: mochi 3, dorayaki 5, taiyaki 10 (baratos a propósito: su valor es
  vaciar la silla y la propina asegurada). Tanda nueva: caldo_dashi 4,
  nigiri_pulpo 7, uramaki_california 8 (+2 gratis), nigiri_anguila 9,
  sashimi_variado 14, dragon_roll 15 (+4 gratis); yaki_onigiri y nigiri_wagyu
  NO tienen precio fijo, lo pone el cronómetro (2-10 y 11-30);
  udon_tempura 16 (calculado: 6 + 7 + 3 de prima del combo).
- **Recetas de mecánica especial** (las 8 últimas):
  *temaki* (enrollado en CONO: `swipe_board` con `direction: "diag"`),
  *aburi* (soplete como `prop` de un `hold_board`),
  *chirashi* (bol con tres pescados distintos encima),
  *udon* (`eat_mult` 1.8 y `patience_mult` 0.7: ocupa mucho al cliente pero le
  retiene poco — sirve para aparcar a un pesado),
  *gari* (picoteo que casi no alarga el bocado pero da +6% de propina),
  *te_verde* (picoteo con `clears_boredom`: resetea el aburrimiento, así que
  vuelves a poder repetirle su plato favorito),
  *fugu* (corte con `fail_penalty` 5: cada corte rápido cuesta 5 doblones —el
  plato NO se pierde—; `tip_amount_mult` 1.15, la propina es más GORDA cuando
  cae, frente al atún rojo que la hace más PROBABLE),
  *tempura* (paso `fry_board`: contador con milésimas a la vista; al soltar se
  mira en qué franja de `FRY_WINDOWS` cayó — antes de 1.8 s cruda y a la
  basura, 1.8-2.5 poco hecha $5, 2.6-3.24 bien $7, **exactamente 3.00 s $15**,
  3.25-4.5 pasada $5, más allá quemada y a la basura; las variantes cruda y
  quemada son recetas `hidden` con su propio modelo),
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
  el final del nivel**. Viaja en `report.penalty`, el nivel lo descuenta sin
  bajar de 0, el cliente lo canta con un "-$N" rojo y la ficha del desglose
  enseña ese número en vez del dinero.
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
- **Postres que LIBERAN EL ASIENTO** (`leaves_seat`): mochi (grumetes, +5% de
  propina), dorayaki (piratas, +10%) y taiyaki (capitanes, +15%). Al terminarlo
  el cliente paga, se le suma ese porcentaje a la propina ACUMULADA (va al bote,
  como el resto) y **se marcha en el acto**, dejando la silla libre: es la única
  forma de echar a un cliente sin esperar a que se le agote la paciencia. Van
  con `only_type`, así que **solo los coge su tipo** — el descarte va ANTES de
  tirar el dado, así que ni con potenciadores los coge otro. La ficha del
  recetario lo refleja (si no, mentiría).
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
  precio bajo. Clavar los 2.00 s dobla o triplica el precio bueno (yaki 2/5/10,
  wagyu 11/15/30). El logro del punto perfecto compara con el techo de ESAS
  franjas, no con el de la tempura.
- **Los rollos rinden por MAESTRÍA, no por lote**: el uramaki California
  (`free_uses` 2) y el dragon roll (`free_uses` 4) sacan UNA pieza y las
  siguientes salen ya hechas, igual que los makis. Se intentó con un campo
  `yield` que emplataba 3 y 5 piezas de golpe y NO es lo que se quiere.
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
  (`GameState.consume_extra`), cuestan 2 doblones y el tendero los tiene
  siempre. Jengibre = el plato no cuenta como repetido; wasabi = +15% de
  PROBABILIDAD de propina; soja = +15% de CUANTÍA. Viajan con el plato:
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
- **Escala por nivel** (esfuerzo y cooldown suben con el nivel): golpes de arroz
  L1=3 · L2=4 · L3=5 (gunkan L1 usa 4 por su base alta); cooldowns aprox.
  L1 3–4 s · L2 4.5–5.5 s · L3 6.5–7.5 s. Al añadir/ajustar recetas, seguir esta
  escala.
- **APROBAR es sacar 2 ESTRELLAS** (`goal_stars` = 2 en todos los puertos):
  con 2★ el nivel queda superado, se abre el siguiente y caen las recompensas
  de `reward_recipes`. Las **3 estrellas piden bastante más dinero** y son un
  reto aparte, con premio propio: `reward_recipes_3` (recetas), `reward_ingots_3`
  (lingotes) y `reward_rice_3` (sacos). Se pueden ir a buscar más tarde,
  repitiendo el puerto con mejor carta; `complete_port` las entrega la primera
  vez que se llega a 3★, aunque el nivel ya estuviera aprobado.
- **`_score_money()` es SOLO el precio de los platos.** Estuvo devolviendo
  `money_earned + tips_total`, así que cada propina se contaba DOS veces (subía
  el bote azul y además la barra verde del oro) y el marcador iba inflado. Las
  propinas van únicamente al bote de potenciadores.
- **Puntuación POR DINERO** (la satisfacción se eliminó): cada umbral de
  `star_money` alcanzado da 1 estrella. El dinero que cuenta para las estrellas
  (y para el monedero) es SOLO el precio de los platos; **las propinas NO suman
  a ese dinero**: van únicamente al bote (potenciadores). El techo lo marca la
  PRODUCCIÓN (partida de 2:30 solo L1 ≈ $50-70; sube con piratas/capitanes que
  comen L2-L3). Umbrales por nivel en `campaign_data.gd` (n1 16/30/45 …
  n9 36/70/100); pendientes de afinar tras probar.
  NO hay dinero extra por estrellas (economía limpia para la tienda).
  En aventura el dinero va al monedero persistente; en Prueba no toca el progreso.
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
