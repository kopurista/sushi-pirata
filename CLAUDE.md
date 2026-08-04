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

- `prep_board.gd` → `dish_served(recipe_id: String)`: un plato sale a la cinta.
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

## Arquitectura (archivos y responsabilidad)

- `scripts/recipe_data.gd` — datos const de las 39 recetas: nivel, saciedad,
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
  `FRY_WASTE_PENALTY`=5 y entra el cooldown), `drag_stage` {prop}
  (aparece un utensilio —sprite de `assets/stages`— animado en la esquina
  inferior derecha de la tabla y se arrastra el sprite de etapa hasta él;
  exige arrastre REAL >24 px y soltar sobre el prop, un toque no cuenta).
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
  cuatro botones con icono propio: **Aventura** (campaña), **Arcade** (partida
  libre con todas las recetas, sin tocar el progreso), **Tienda** e
  **Inventario**, más dos **botones REDONDOS de esquina** sin tablón de madera
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
  (`tendero.glb`, sin rig: respira y se balancea desde su pivote) atiende tras
  su mostrador en un muelle sobre el mar. Vende USOS de ingredientes (`cost` en
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
  En `ui/`: `boton_madera.png` (el botón de todo el juego), `libro.png` (el
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
- **`create_shadow_meshes=false` en los 29 modelos**: generaba una copia extra
  de cada malla para un pase de sombras que no existe (no hay sombras
  proyectadas en el juego). Verificado: 0 de 29 mallas llevan ya malla de sombra.
  **`ensure_tangents=false` en cambio NO sirve de nada aquí**: solo evita
  GENERARLAS cuando faltan, y estos `.glb` ya las traen de origen. Se intentó
  quitarlas poniendo `arrays[Mesh.ARRAY_TANGENT] = null` antes de
  `add_surface_from_arrays` y **Godot las vuelve a poner** (el formato sale
  idéntico). No insistir: la única vía sería regenerar los `.glb` de origen.
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
- **Botones (TODOS los del juego)**: `prep_board.skin_button()` es el único
  sitio donde se define su aspecto — tablón de madera con marco dorado y
  remaches (`assets/ui/boton_madera.png`, `BUTTON_MARGIN` 52), sombra
  proyectada y hundido al pulsar. En botones pequeños el margen del 9-slice se
  **encoge por código** al redimensionar (`min(lado)*0.44`): con el margen fijo
  las cuatro esquinas doradas no cabían y el marco salía aplastado. Si un texto
  se solapa con el marco, la solución es ensanchar el botón, no bajar el margen.
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

## Balance actual (para no re-litigar)

- **Precios (doblones)**: edamame 1, gari 1, te_verde 1, maki_aguacate 2,
  nigiri_salmon 3, gunkan_wakame 3, onigiri 4, sopa_miso 4, maki_atun 5,
  udon 6, nigiri_atun/inari 6, sashimi_tamago 6, gunkan_tartar 7 (L2),
  temaki 7, gunkan_ikura 8, futomaki 10, sashimi_atun_rojo 11, nigiri_ebi 11,
  fugu 11, hana_maki 12, aburi 12, chirashi 16; moriawase dinámico (~26-90).
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
  suma de los platos + prima por variedad (2 clases +10, 3 +24, 4 +52). Ese
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
- **Puntuación POR DINERO** (la satisfacción se eliminó): cada umbral de
  `star_money` alcanzado da 1 estrella. El dinero que cuenta para las estrellas
  (y para el monedero) es SOLO el precio de los platos; **las propinas NO suman
  a ese dinero**: van únicamente al bote (potenciadores). El techo lo marca la
  PRODUCCIÓN (partida de 2:30 solo L1 ≈ $50-70; sube con piratas/capitanes que
  comen L2-L3). Umbrales por nivel en `campaign_data.gd` (n1 16/30/45 …
  n9 36/70/100); pendientes de afinar tras probar.
  NO hay dinero extra por estrellas (economía limpia para la tienda).
  En aventura el dinero va al monedero persistente; en Prueba no toca el progreso.
- **Probabilidades de coger plato** (`TAKE_CHANCES`): piratas L1 0.45, capitanes
  L2 0.70 (subidas a propósito); tiempos de comida por tipo×nivel (`EAT_TIMES`).
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
