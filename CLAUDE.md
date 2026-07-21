# Sushi Pirata — guía del proyecto

Juego móvil **vertical (720×1280)**, 2D isométrico voxel/pixelart, de **estrategia y
gestión en tiempo real**. El jugador es el cocinero de un barco pirata que sirve
sushi en una **cinta transportadora kaiten** a clientes con comportamientos
distintos. Partidas de ~4 minutos. Motor: **Godot 4.7.1**.

El núcleo NO es cocinar rápido, sino **gestionar la cinta, los recursos, las
recetas (cada una una herramienta con propiedades) y el comportamiento de los
clientes** para maximizar beneficios. Toda mecánica nueva debe reforzar ese núcleo.

## Cómo ejecutar y verificar (NO hay editor abierto de forma fiable)

Godot está en `C:/Users/KOPURISTA/Desktop/GODOT/Godot_v4.7.1-stable_win64.exe/`
(es una carpeta que contiene los .exe).

- **Comprobar errores de compilación** (rápido, headless):
  `"…/Godot_v4.7.1-stable_win64_console.exe" --headless --quit-after 250 "res://scenes/level.tscn"`
  Sin salida = OK. Repetir con la escena de menú (sin argumento) también.
- **Importar assets nuevos** antes de usarlos: `--headless --import`.
- **Verificación visual**: inyectar un nodo helper temporal con un script que
  fuerce estado (`lv.prep_phase = false`, `_try_spawn_client()`, `_on_dish_served()`)
  y guarde `get_viewport().get_texture().get_image().save_png("res://shot.png")`,
  correr SIN `--headless`, y leer el PNG. **Limpiar siempre el helper después.**
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
  `kind` ∈ tap/cut/swipe/hold/drag/stage/done/select/cancel/serve.
- `client.gd` → `finished(report: Dictionary)`: al irse; el diccionario lleva
  `type, money, tip, satisfaction, eaten (ids), satiety_eaten, satiety_needed`.
- `level.gd` accede a `prep_board.instant_recipes / skip_next_cooldown /
  easy_next / double_next / stack_max / cooldown_mult` para aplicar potenciadores.

## Arquitectura (archivos y responsabilidad)

- `scripts/recipe_data.gd` — datos const de las 6 recetas: nivel, saciedad,
  cooldown, precio, `free_uses` (maestría), `steps` (secuencia de gestos) y
  `stages` (sprite por paso). Ingredientes y helpers `get_dish_texture` /
  `get_stage_texture`. **Tipos de paso**: `tap_ingredient` {ingredient},
  `tap_board` {count, cutting?}, `drag_ingredient` {ingredient},
  `swipe_board` {count, direction: up/down}, `hold_board` {duration}. `stages`
  tiene un id de sprite por paso ("" = ninguno); el último stage no-vacío se
  descarta al emplatar (el plato final es el mismo voxel que el emplatado).
- `scripts/powerup_data.gd` — catálogo de potenciadores (`manual` = el jugador
  elige cuándo; si no, automático).
- `scripts/game_state.gd` — **autoload** `GameState`: recetas elegidas, dinero,
  resultado de la última partida.
- `scripts/prep_board.gd` — la tabla inferior: minijuego de elaboración por
  etapas, mano de gestos animada, cajas de guardado por pilas, cooldowns.
- `scripts/client.gd` — cliente: entra andando, se sienta, coge platos, come,
  bocadillo de ánimo, propina, se va andando. Tipos: E grumete, A pirata,
  G capitán (V VIP pendiente).
- `scripts/level.gd` — orquestador: cinta (Line2D por tramos), spawner por
  horario, HUD, propinas/potenciadores, puntuación, panel de resultados.
- `scripts/prep_screen.gd` — pantalla de selección de 4 recetas.
- `scenes/*.tscn` — level, prep_screen, client, plate.
- `assets/` — dishes, characters, ingredients, stages, ui, props, scenery.
  `art/concepts/` es solo referencia (tiene `.gdignore`).

## Convenciones y decisiones ya tomadas (NO reintroducir bugs resueltos)

- **Assets**: se generan con **Ludo MCP** (`createImage` / `generateWithStyle`,
  estilo `Voxel Art`), se descargan de inmediato (las URLs caducan a 7 días), y
  se recortan con un script Godot midiendo el bounding box con **umbral de
  alfa ≥ 0.6–0.75** (el recorte por `get_used_rect` incluía la sombra y rompía
  los 9-slice). Los sprites se guardan como `.png`; los platos como `.webp`.
- **UI de madera/pergamino**: 9-slice con `NinePatchRect` (no `StyleBoxTexture`,
  que ignoraba los márgenes). `prep_board.make_nine_patch()` y `skin_button()`.
- **Estrellas**: imágenes propias (`estrella_llena/vacia.png`) vía
  `make_star_row()`, nunca el carácter ★.
- **Cinta**: cuatro **tramos rectos** independientes (`Line2D` con shader
  `belt_scroll.gdshader` que desplaza la UV) + **placas romboidales metálicas**
  estáticas en las esquinas. Una `Line2D` cerrada con juntas parpadea porque la
  geometría de la junta recibe UV que se desplazan — por eso van en tramos.
- **`TextureRect`**: fijar `expand_mode = EXPAND_IGNORE_SIZE` **antes** de
  asignar `texture`, o el tamaño mínimo salta al nativo del sprite.
- **HUD**: barra superior y tabla inferior ancladas a los bordes (top / bottom)
  y a todo el ancho; el espacio extra de pantallas altas queda en el centro.
- **Guardado**: al soltar cerca de las cajas (con margen amplio) se guarda solo
  en la primera caja válida (misma receta con hueco → primera vacía). Servir a
  la cinta exige soltar sobre su franja. Desde una caja se sirve solo con
  arrastre real (>24 px), nunca con un toque.
- **Mano de gestos**: `HAND_TIP` ancla la mano **por encima** del objetivo.
  Los pasos sobre la tabla apuntan al **centro del sprite de etapa**, sin
  desplazamientos fijos. Los deslizamientos llevan además una `flecha.png`.
- **Layout móvil (importante)**: en la tabla inferior las **recetas van abajo**
  y la **tabla de manipulación arriba**, a propósito: un gesto de deslizar de
  abajo hacia arriba pegado al borde inferior del móvil cierra la app.
- **Maestría (`free_uses`)**: al hacer manualmente una receta con `free_uses`
  (makis/futomaki), las N siguientes salen instantáneas — se muestra "xN" en el
  botón. El potenciador "Reciclaje" añade +1 uso cuando un plato se desecha.
- **Guardado por pilas**: cada caja apila hasta `stack_max` (3, o 5 con "Más
  almacén") platos IGUALES; el mismo plato nunca ocupa dos cajas. Potenciador
  "Doble plato" crea 2 platos en la tabla a la vez.

## Balance actual (para no re-litigar)

- Puntuación = 80% satisfacción media + bonus de tiempo (solo si ≥1 cliente
  atendido y todos comieron algo). 3★ ≥85%, 2★ ≥50%, 1★ resto. 0 atendidos = 0.
- Propinas por tipo y exceso de saciedad (ver `client.gd::_roll_tip`).
- Bote de propinas exponencial: umbrales acumulados 10, 22, 36, 52… (`TIP_INCREMENTS`).
- Llegadas: horario escalonado con jitter; primero ~6 s, último siempre >45 s
  antes del final; pueden irse hasta el último segundo.

## Flujo de trabajo por cambio

1. Editar el/los script(s) o `.tscn`.
2. `--headless --quit-after` en ambas escenas → 0 errores.
3. Si es visual: helper inyectado → screenshot → revisar → corregir → limpiar helper.
4. Lanzar el juego para el usuario.
