extends Node
## Autoload: estado compartido entre pantallas + progreso persistente de la
## campaña (se guarda en disco en user://savegame.json).

const SAVE_PATH := "user://savegame.json"
## DE DONDE SE ENTRO A LA TIENDA Y A OPCIONES (de sesion, no se guarda). El
## submenu del MAPA lleva a las dos, y volver al menu principal desde ahi
## sacaba al jugador de donde estaba: con esto el "Atras" devuelve al mapa.
var shop_from := ""
var options_from := ""


## --- Estado de la partida en curso (NO se guarda a disco) ---
## Modo: "adventure" (nivel de campaña) o "test" (nivel de prueba libre).
var mode: String = "test"
## Ids de las recetas elegidas en la fase de preparación (máx. 4).
var selected_recipes: Array[String] = []
## Potenciadores permanentes elegidos para esta partida (se gastan al empezar).
var selected_perks: Array[String] = []
## Cómo debe ENTRAR la siguiente pantalla, para encadenar la animación de
## salida de una con la de entrada de la otra ("arcade", "inventario",
## "menu"...). Lo consume la pantalla que se abre y se limpia sola.
var transition: String = ""
## DE DONDE se entro a Maestrias, para que su "Atras" devuelva ahi y no
## siempre al menu: la BARRA DE NIVEL que la abre vive en el menu, en el
## mapa y en la pesca, asi que volver al menu desde las otras dos sacaba al
## jugador de donde estaba. "menu" | "mapa" | "pesca". De SESION: no se
## guarda, porque no es progreso sino por donde se iba.
var skills_from: String = "menu"
## Escenario que el MAPA tiene elegido ahora mismo. Se apunta al seleccionarlo y
## lo consume `level_select3d._focus_last_port`, para que al volver de cualquier
## pantalla el mapa siga donde estaba en vez de saltar al ultimo abierto. Al
## cerrar un turno, `level3d` lo deja en el escenario SIGUIENTE al jugado.
## De SESION: es por donde se iba, no progreso.
var map_port: String = ""
## QUE ensena el inventario al abrirse: "recetario" (recetario + despensa) o
## "coleccion" (la vitrina). Son dos botones distintos del submenu y una sola
## escena, porque comparten fondo, cabecera y el libro. De SESION.
var inventory_view: String = "recetario"
## Recetas recién desbloqueadas que el MENÚ principal tiene que anunciar con su
## animación. Lo llena complete_tutorial/complete_port y lo consume el menú.
var pending_reveal: Array = []


## Devuelve el tipo de transición pendiente y lo consume.
func take_transition() -> String:
	var t := transition
	transition = ""
	return t
## Nivel de la campaña que se va a jugar (solo en modo adventure).
var current_port: String = ""

## --- Progreso persistente ---
## Dinero total acumulado por el jugador.
var money: int = 0
## ARROZ: cada nivel jugado gasta 1. Es la "energía" del juego (se repondrá
## con dinero real más adelante); la partida nueva empieza con RICE_START.
var rice: int = RICE_START
## Momento (Unix) en que cae el próximo saco. 0 = el saco está lleno y no
## corre ningún reloj.
var rice_next_ts: int = 0
var ingots: int = INGOTS_START
## Género elegido por el jugador ("m"/"f"/"x"). Decide qué chef sale y, por
## contraste, qué ayudante: el ayudante es del género contrario (con el jugador
## neutro le toca uno al azar). Se elige en Opciones, pestaña Perfil.
var player_gender: String = CharacterData.MALE
## true desde que se zarpa de la PORTADA. Es DE SESIÓN (no se guarda): al
## volver al menú desde cualquier pantalla ya no se pasa otra vez por el
## puerto, pero al abrir el juego de nuevo sí.
var booted := false
## Título del cartel de recompensa (el renglón bajo el nombre) y los que se han
## desbloqueado. Ver `title_data.gd`: de salida solo está el de la mano.
var player_title_id: String = TitleData.MANO
var unlocked_titles: Array[String] = [TitleData.MANO]
## Nombre del jugador (de esa misma pestaña).
var player_name: String = ""
## Mano dominante ("L"/"R"). Con la IZQUIERDA la mesa queda como siempre
## (tabla a la izquierda, cajas y botones a la derecha); con la DERECHA el
## panel inferior se voltea en espejo para que el pulgar derecho no tape las
## instrucciones ni tenga que estirarse hasta la tabla.
var player_hand: String = "R"


func right_handed() -> bool:
	return player_hand == "R"


# --- Área segura de la pantalla (notch del iPhone, isla, etc.) --------------
## En el EXPORT NATIVO la ventana ocupa la pantalla ENTERA, notch incluido: el
## HUD de arriba quedaba debajo de la muesca (en Safari no pasa porque el
## navegador ya vive dentro del área segura). Devuelven píxeles DE LIENZO
## (diseño 720 de ancho), listos para sumar a un offset.

func canvas_size() -> Vector2:
	var root := get_tree().root
	return root.get_visible_rect().size if root != null else Vector2(720, 1280)


func safe_top() -> float:
	# SOLO en el export nativo móvil. En escritorio el "área segura" es el
	# escritorio menos la barra de tareas y según dónde esté la ventana al
	# arrancar daba una franja falsa: los botones del menú salían más abajo en
	# unas pantallas que en otras. En Safari tampoco toca: el navegador ya
	# vive dentro del área segura.
	if not OS.has_feature("mobile"):
		return 0.0
	var win := get_window()
	if win == null or win.size.x <= 0:
		return 0.0
	var safe := DisplayServer.get_display_safe_area()
	var px := maxf(float(safe.position.y - win.position.y), 0.0)
	return px * canvas_size().x / float(win.size.x)


func safe_bottom() -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var win := get_window()
	if win == null or win.size.x <= 0:
		return 0.0
	var safe := DisplayServer.get_display_safe_area()
	var px := maxf(float(win.position.y + win.size.y - safe.end.y), 0.0)
	return px * canvas_size().x / float(win.size.x)
## Ids de recetas y potenciadores desbloqueados.
var unlocked_recipes: Array[String] = []
var unlocked_powerups: Array[String] = []
## true cuando se ha completado el tutorial de David Jones. Hasta entonces el
## menú manda a la introducción y no hay recetas desbloqueadas (las 4 primeras
## las entrega el propio tutorial).
var tutorial_done := false
## true cuando David ya ha presentado la TIENDA y a Saverio (tras el nivel 4).
var shop_intro_done := false
## Los EXTRAS (jengibre, wasabi, soja) llegan MÁS TARDE que la tienda: Saverio
## los saca en el nivel 6, no el día que abre el puesto. Hasta entonces ni
## aparecen en la tabla ni se venden.
var extras_done := false
## David ya felicitó al jugador tras superar el NIVEL 1 (recompensas + invitación
## al 2) y ya explicó el BONUS DIARIO. Los dos van seguidos y una sola vez.
var level1_outro_done := false
var daily_intro_done := false
## La lección del CUBO DE BASURA ya se ha contado. Es de TODA LA PARTIDA, no de
## un nivel: atada al nivel, David y Gigi repetían la parrafada cada vez que se
## colaba un plato en cualquier puerto narrado.
var trash_intro_done := false
## Pablo ya pago la broma del punal con sus lingotes y David los explico.
var ingots_intro_done := false
## LINGOTES QUE PABLO DEBE Y AUN NO HA PAGADO. Se apunta al cerrar su nivel y
## los entrega el MAPA al volver (`main_menu._pagar_pablo`), que es donde estan
## a la vista las cajas de lingotes, doblones y arroz: dentro del nivel no hay
## ninguna de las tres y la explicacion de David senalaba a una pantalla vacia.
var pending_ingots := 0
## A Cai le han llenado la barriga en la Isla de Gades: es lo que cierra su
## trato cuando el jugador vuelve al mapa. Se guarda porque la escena del
## trato NO ocurre en el nivel, sino despues, en el mapa.
var cai_saciado := false
## Cai ya ha dado su clase de pesca (y con ella las tiradas gratis).
var fishing_intro_done := false
## Cai ya se ha enrolado (la escena del mapa al superar la Isla de Gades).
var cai_intro_done := false
## A ALICE le han llenado la barriga en la Rada de los Dos Fuegos. Igual que
## con Cai, se guarda porque la escena en la que se enrola NO ocurre en el
## nivel sino después, ya en el mapa: sin este apunte, quien le diera de comer
## y cerrase el turno por objetivo llegaría al mapa y ella hablaría de una
## comida que nadie recuerda.
var alice_saciada := false
## El KAPPA rendido debe su escena del mapa (2 lingotes + su diente, medio
## dormido). Persistente: se apunta al cerrar el nivel y se representa al
## volver, y sin guardarla quien cerrara el juego entre medias la perdería.
var pending_kappa := false
## La escena ya se representó: el trofeo del Kappa deja de esperar por ella
## (ver el filtro de BOSS_ITEMS en `_run_achievement_check`).
var kappa_outro_done := false
## La escena de la puerta del MAR 2 (la felicitación y el aviso de los vientos)
## ya se representó.
var mar2_intro_done := false
## EL SUSHI RUSH, la habilidad que enseña MIKU (m2_14) a cambio de un barco de
## sushi: encadenando `level3d.RUSH_CHAIN` platos sin fallo, los platos salen
## solos y el enfriamiento cae, hasta que un plato se repite o cae al cubo.
var sushi_rush_unlocked := false
## Alice ya se ha enrolado, y con ella se abrieron los BONIFICADORES (la escena
## del mapa al superar su escenario).
var alice_intro_done := false
## David ya ha explicado los CONTADORES DE MAESTRÍA del HUD (la primera vez que
## se juega con una habilidad de "cada N platos" puesta). No va atado a ningún
## escenario: esas habilidades se compran cuando el jugador quiere.
var skill_counters_intro_done := false
## David ya ha explicado el HÁNDICAP del PUERTO (3 vacíos = derrota) dentro de
## un puerto. Se cuenta también en el mapa al presentar los tipos, pero la
## primera jornada de puerto lo repite con el contador delante.
var isla_handicap_done := false
var puerto_handicap_done := false
## Y el del ABORDAJE (cada vacío resta 15 s de reloj), la primera vez que se
## juega uno.
var abordaje_handicap_done := false
## Cai ya ha explicado qué son los COLECCIONABLES (al pescar el primero).
var col_intro_done := false
## David ya ha presentado las MAESTRÍAS (al llegar al nivel 5 de cocinero).
var skills_intro_done := false
## Y ya ha explicado el NIVEL DE COCINERO (la primera vez que sube, al 2).
var nivel_intro_done := false
## Explicaciones de PANTALLA: se dan la primera vez que se entra en cada una.
var logros_intro_done := false
var inventario_intro_done := false
## David ya explicó para qué sirve el ARROZ (al elegir el primer puerto).
var rice_intro_done := false
## Ya se vio la escena de Pablo y Saverio en la tienda (tras su nivel).
var pablo_shop_done := false
## David ya señaló el pergamino de AVENTURA en el menú (la primera visita tras
## el rescate). Persistente: la guía solo se da una vez.
var menu_intro_done := false
## Y David ya señaló el PRIMER PUERTO en el mapa (la guía de los tres tipos
## de nivel). Igual que la anterior: una sola vez en la vida de la partida.
var map_intro_done := false
## Puertos cuyo GUION ya se ha visto (ver `port_narrated`). Se marca al terminar
## la fase de preparación, así que fallar y repetir NO obliga a volver a pasar
## por las explicaciones.
var narrated_ports: Array = []
## Usos de ingredientes que regala el juego al desbloquear una receta: TRES de
## cada cosa NUEVA que pida... y solo UNO (`GIFT_KNOWN`) de las que el jugador
## ya tenga. La novedad es la receta, no rellenar la despensa entera: con el
## regalo completo cada vez, la despensa dejaba de gastarse. Si aun así se
## agota antes de que abra la tienda, David repone (`gift_missing_ingredients`).
const TUTORIAL_GIFT := 3
const PORT_GIFT := 3
const GIFT_KNOWN := 1
## Y si aun así se queda a CERO de algo antes de que abra la tienda, David
## aparece y le regala esta cantidad (ver `gift_missing_ingredients`).
const RESCUE_GIFT := 3
## Mejor resultado en estrellas (0-3) por nivel jugado. port_id -> int.
var level_stars: Dictionary = {}
## Mejor puntuación (dinero ganado) por nivel jugado. port_id -> int.
var level_scores: Dictionary = {}
## Inventario de ingredientes: id -> usos restantes. Un uso = un nivel jugado
## con alguna receta que lleve ese ingrediente (NO se gasta por plato).
var ingredients: Dictionary = {}
## Potenciadores permanentes conseguidos por combos (ver PerkData) y usos
## comprados de cada uno: id -> usos restantes.
var unlocked_perks: Array[String] = []
## MEJORAS DE RECETA ganadas (ids de la receta BASE, ver RecipeData.UPGRADES).
var unlocked_upgrades: Array[String] = []
## La escena de Alice presentando la PRIMERA mejora (m2_01) espera en el mapa.
var pending_mejora_intro := false
var perk_uses: Dictionary = {}
## Nivel de MEJORA de cada bonificador (1..PerkData.MAX_LEVEL). Se sube con
## doblones desde la pantalla de Bonificadores; los usos NO se compran.
var perk_level: Dictionary = {}
## Tienda: el tendero saca CADA DÍA (fecha real) un surtido de 8 ingredientes.
## `shop_day` guarda el día del surtido actual para saber cuándo renovarlo.
var shop_stock: Array[String] = []
var shop_day: String = ""

## BONUS DIARIO (ver DailyData): día de la racha que toca cobrar (1..7) y fecha
## del último cobro. Con `daily_day` a 0 no se ha cobrado ninguno todavía.
var daily_day: int = 0
var daily_last: String = ""
## COLECCIONABLES conseguidos (ids de CollectibleData) y fragmentos sueltos del
## triángulo dorado (a CollectibleData.TRIFORCE_PIECES se juntan en uno).
var collectibles: Array[String] = []
var triforce_pieces: int = 0
## COLECCIONABLES CONSEGUIDOS QUE AÚN DEBEN SU ESCENA (ver
## `CollectibleData.SCENE_ITEMS`): el corazón con el apellido de David, el
## tenedor y los que vengan. Es una COLA y es PERSISTENTE: si el jugador
## cierra el juego con la ventana del coleccionable recién vista, la escena
## le espera al volver. La representa `main_menu`, al cerrar la pesca.
var pending_col_scenes: Array[String] = []
## ÁLBUM DE PESCA: id de pez (FishData) -> veces pescado, y el RÉCORD de
## tamaño por especie (id -> size 0..1, el mayor pescado: es lo que enseña la
## ficha). Solo estado; catálogo y economía en `fish_data.gd`.
var fish_album: Dictionary = {}
var fish_best: Dictionary = {}
## LOGROS: medallas ya RECLAMADAS (id -> 0..3) y ya ANUNCIADAS con su toast
## (id -> 0..3). Lo CONSEGUIDO no se guarda: se deduce siempre de `stats`.
var claimed_medals: Dictionary = {}
## Nivel de cocinero al que se gano cada medalla: id -> [bronce, plata,
## oro], con 0 en las que aun no estan. De aqui sale lo que paga cada una
## (`medal_reward`), asi que acumular sin reclamar no renta nada.
var medal_levels: Dictionary = {}
var seen_medals: Dictionary = {}
## Contadores de toda la vida del jugador, de los que salen los LOGROS
## (ver achievement_data.gd). Clave -> entero. Los que empiezan por "best_"
## guardan un máximo, el resto se acumulan.
var stats: Dictionary = {}
## Segundos con el juego abierto: los suma `_process` de este autoload, así que
## cuentan los menús, el mapa, la tienda y la pesca, no solo los niveles.
var play_seconds: float = 0.0
## Ajustes del jugador (gráficos e identidad). `apply_graphics()` los aplica.
var settings: Dictionary = {}

## Ajustes por defecto. `quality` 0 = baja, 1 = media, 2 = alta; `preset` es el
## bloque de gráficos elegido (ver GRAPHICS_PRESETS; "custom" = a medida).
## Los tres volúmenes van de 0 a 1 y los aplica `Audio.aplicar_volumenes()` a
## sus buses. La MÚSICA arranca por debajo del resto a propósito: es el fondo,
## y quien quiera subirla lo tiene a un dedo en Opciones.
const DEFAULT_SETTINGS := {
	"preset": "alta",
	"shadows": true,
	"anim": true,
	"quality": 2,
	"fps": 60,
	"vol_musica": 0.7,
	"vol_efectos": 1.0,
	"vol_voces": 1.0,
}
## Topes de fotogramas que se pueden elegir.
const FPS_CHOICES := [30, 45, 60]
## Escala de renderizado 3D por nivel de calidad (la interfaz 2D no se toca).
const QUALITY_SCALE := [0.62, 0.8, 1.0]
const QUALITY_NAMES := ["Baja", "Media", "Alta"]

## Bloques de gráficos de la pantalla de Opciones. Elegir uno pisa los cuatro
## ajustes de golpe; tocar cualquiera de ellos a mano pasa a "custom".
const GRAPHICS_PRESETS := {
	"alta": { "quality": 2, "fps": 60, "shadows": true, "anim": true },
	"media": { "quality": 1, "fps": 30, "shadows": true, "anim": true },
	"baja": { "quality": 0, "fps": 30, "shadows": false, "anim": false },
}
const PRESET_ORDER := ["alta", "media", "baja", "custom"]
const PRESET_NAMES := {
	"alta": "Alta", "media": "Media", "baja": "Baja", "custom": "Personalizado",
}

## Artículos que ofrece el tendero y precio de renovarlos a mano.
const SHOP_SLOTS := 8
const SHOP_REROLL_COST := 25

## --- Resultado de la última partida (para el panel de resultados) ---
var last_score: float = 0.0
var last_stars: int = 0
var last_money_earned: int = 0


func _ready() -> void:
	# El velo de las transiciones tiene que seguir corriendo aunque el arbol
	# este en pausa (se sale de un nivel desde el cartel de confirmacion).
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()
	apply_graphics()


## HORAS JUGADAS: se cuentan DESDE AQUÍ, así que suma todo el rato que el juego
## está abierto — menús, mapa, tienda, pesca y niveles. Antes solo sumaba
## `level3d` mientras había partida, y el contador de Progreso se quedaba muy
## por debajo de lo que el jugador recordaba haber echado.
##
## El autoload va en PROCESS_MODE_ALWAYS, así que el reloj corre también con el
## árbol en pausa (un cartel de resultados o un diálogo siguen siendo tiempo de
## juego).
func _process(delta: float) -> void:
	play_seconds += delta


# --- Fundido a negro entre pantallas ---------------------------------------
## El velo vive en el AUTOLOAD, no en la escena: asi sobrevive al cambio de
## escena y tapa los fotogramas en los que el motor ya ha soltado la escena
## vieja y aun no ha montado la nueva (se veian en gris).

## Por encima de cualquier CanvasLayer del juego.
const FADE_LAYER := 128
var _fade_rect: ColorRect = null


func _ensure_fade() -> ColorRect:
	if _fade_rect != null and is_instance_valid(_fade_rect):
		return _fade_rect
	var layer := CanvasLayer.new()
	layer.layer = FADE_LAYER
	add_child(layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Nunca se come un toque, ni siquiera con la pantalla en negro.
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade_rect)
	return _fade_rect


## Cierra el telon y deja la pantalla en negro.
func fade_out(time := 0.3) -> void:
	var rect := _ensure_fade()
	if time <= 0.0:
		rect.color.a = 1.0
		return
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 1.0, time)
	await tw.finished


## Abre el telon desde negro.
func fade_in(time := 0.4) -> void:
	var rect := _ensure_fade()
	if time <= 0.0:
		rect.color.a = 0.0
		return
	create_tween().tween_property(rect, "color:a", 0.0, time)


## Funde a negro, cambia de escena y vuelve a abrir. `in_time` a 0 deja la
## pantalla en negro: entonces la escena que entra tiene que llamar a
## `fade_in()` cuando le venga bien.
func fade_to_scene(path: String, out_time := 0.3, in_time := 0.45) -> void:
	await fade_out(out_time)
	get_tree().change_scene_to_file(path)
	# La escena nueva se monta al FINAL del frame y alguna coloca su interfaz un
	# frame despues (main_menu): se esperan tres antes de abrir el telon.
	for i in 3:
		await get_tree().process_frame
	if in_time > 0.0:
		fade_in(in_time)


func reset_run() -> void:
	last_score = 0.0
	last_stars = 0
	last_money_earned = 0


func is_adventure() -> bool:
	return mode == "adventure" and current_port != ""


func is_tutorial() -> bool:
	return mode == "tutorial"


## Cierra el tutorial (la escena del rescate): entrega SOLO el maki de
## aguacate — el resto de la carta se gana nivel a nivel, que la campaña es la
## escuela. Idempotente (repetirlo no duplica nada).
func complete_tutorial() -> void:
	tutorial_done = true
	for r in CampaignData.INITIAL_RECIPES:
		unlock_recipe(r)
	# Se estrena con la despensa llena: 5 usos de lo que pide.
	gift_ingredients_for(CampaignData.INITIAL_RECIPES, TUTORIAL_GIFT)
	# SIN `pending_reveal`: el propio David acaba de entregarlas en su despedida
	# ("estas 4 recetas son tuyas"), así que el pergamino de "¡Recetas nuevas!"
	# del menú contaba lo mismo otra vez, dos pantallas seguidas.
	save_game()


## ¿Está abierta la TIENDA? Se gana superando el nivel que la trae
## (`unlocks_shop` en CampaignData). En Arcade y en prueba está siempre.
func shop_unlocked() -> bool:
	for p in CampaignData.PORTS:
		if not p.get("unlocks_shop", false):
			continue
		return int(level_stars.get(p["id"], 0)) >= int(p.get("goal_stars", 1))
	return true


## La PESCA se gana superando el puerto que la trae (`unlocks_fishing`, hoy el
## nivel 5): hasta entonces su pergamino del menú queda apagado. Estuvo abierta
## desde el inicio mientras se probaba el minijuego.
func fishing_unlocked() -> bool:
	for p in CampaignData.PORTS:
		if p.get("unlocks_fishing", false):
			return int(level_stars.get(p["id"], 0)) >= int(p.get("goal_stars", 1))
	return true


## Los EXTRAS (jengibre, wasabi, soja) los saca Saverio en el nivel 6, DOS
## niveles después de abrir el puesto: la tienda ya es bastante novedad ella
## sola, y los extras solo tienen sentido cuando el jugador conoce el hastío.
func extras_unlocked() -> bool:
	return extras_done


## Regala `RESCUE_GIFT` usos de cada ingrediente del que no quede nada. Es la
## red de seguridad de la escuela: MIENTRAS NO HAY TIENDA (nivel 4) el jugador
## no puede reponer, así que quedarse a cero sería un callejón sin salida.
## Devuelve los ingredientes que ha rellenado (vacío si no hacía falta o si la
## tienda ya está abierta).
func gift_missing_ingredients(recipe_ids: Array) -> Array[String]:
	var faltan := missing_ingredients(recipe_ids)
	if faltan.is_empty() or shop_unlocked():
		return [] as Array[String]
	for ing in faltan:
		add_ingredient_uses(ing, RESCUE_GIFT)
	save_game()
	return faltan


## Puerto que abre el modo Arcade al superarlo. Todavía no está en la campaña
## (llega hasta el 9), así que el Arcade sigue cerrado hasta que se añada.
const ARCADE_PORT := "nivel_15"


## El modo Arcade se gana jugando: hace falta haber SUPERADO el puerto que lo
## trae (su objetivo de estrellas, no solo haberlo tocado).
func arcade_unlocked() -> bool:
	# El puerto que abre el Arcade. Mientras no exista en CampaignData, el modo
	# sigue cerrado: es una recompensa de más adelante en la travesía.
	var port := CampaignData.get_port(ARCADE_PORT)
	if port.is_empty():
		return false
	return int(level_stars.get(ARCADE_PORT, 0)) >= int(port.get("goal_stars", 1))


# --- Desbloqueos -----------------------------------------------------------

## ¿Está desbloqueada esta receta?
func is_recipe_unlocked(id: String) -> bool:
	return id in unlocked_recipes


## Desbloquea una receta si no lo estaba. Devuelve true si era nueva.
func unlock_recipe(id: String) -> bool:
	if id in unlocked_recipes:
		return false
	unlocked_recipes.append(id)
	# El surtido de la tienda se sortea entre lo que sirve para las recetas
	# conocidas: al aprender una nueva hay que rehacerlo.
	shop_day = ""
	return true


# --- Inventario de ingredientes --------------------------------------------

func get_ingredient_uses(id: String) -> int:
	return int(ingredients.get(id, 0))


func add_ingredient_uses(id: String, amount: int) -> void:
	ingredients[id] = get_ingredient_uses(id) + amount


## Regala `uses` usos de todo lo que hace falta para estas recetas, para que una
## receta recién desbloqueada se pueda estrenar sin pasar por la tienda.
## Los ingredientes GRATIS (arroz, sésamo: cost 0) se saltan, que no se gastan.
## `uses` es lo que se regala de un ingrediente NUEVO (uno que el jugador no
## tiene). De los que YA TIENE cae solo `GIFT_KNOWN`: la receta nueva es la
## novedad, y rellenar la despensa entera cada vez que David regalaba un plato
## convertía la despensa en infinita.
func gift_ingredients_for(recipe_ids: Array, uses: int) -> void:
	for rid in recipe_ids:
		for ing in RecipeData.get_ingredients(rid):
			var data: Dictionary = RecipeData.INGREDIENTS.get(ing, {})
			if int(data.get("cost", 0)) <= 0:
				continue
			add_ingredient_uses(ing,
				uses if get_ingredient_uses(ing) <= 0 else GIFT_KNOWN)


## ¿Hay al menos 1 uso de cada ingrediente de la receta?
func has_ingredients_for(recipe_id: String) -> bool:
	for ing in RecipeData.get_ingredients(recipe_id):
		if get_ingredient_uses(ing) <= 0:
			return false
	return true


## Ingredientes DISTINTOS que consumiría jugar un nivel con estas recetas.
## Los GRATUITOS (coste 0: el sésamo, como el arroz) quedan fuera: ni se
## compran en la tienda ni gastan usos, así que exigirlos aquí dejaba una
## receta sin poder jugarse por un ingrediente que no se puede conseguir.
func ingredients_for_selection(recipe_ids: Array) -> Array[String]:
	var out: Array[String] = []
	for rid in recipe_ids:
		# UNA RECETA QUE TODAVÍA NO ES SUYA NO PIDE DESPENSA. En la carta cerrada
		# de una isla puede haber una receta que David REGALA dentro del nivel
		# (el nigiri de salmón del 1): antes de zarpar el jugador aún no la tiene
		# ni tiene su género, y avisarle de que "le falta salmón" era mentir —
		# el salmón se lo va a dar David, con sus usos, en mitad de la partida.
		if is_adventure() and not is_recipe_unlocked(str(rid)):
			continue
		for ing in RecipeData.get_ingredients(rid):
			if int(RecipeData.get_ingredient(ing).get("cost", 0)) <= 0:
				continue
			if not ing in out:
				out.append(ing)
	return out


## Consume 1 uso de cada ingrediente distinto de la selección (al EMPEZAR un
## nivel de aventura). Devuelve false sin consumir nada si falta alguno.
## Cobra los sacos que hayan caído desde la última vez. Se llama al cargar y
## cada vez que alguien mira el contador, así que el tiempo cuenta igual con el
## juego cerrado: lo que se guarda es CUÁNDO cae el siguiente, no cuánto falta.
##
## Ojo: va contra el reloj del aparato, así que adelantarlo regala arroz. Para
## un juego de un solo jugador es un cambio aceptable; si algún día hay cuentas
## en servidor, la hora tendrá que venir de ahí.
func tick_rice() -> void:
	if rice >= RICE_START:
		rice_next_ts = 0
		return
	var ahora := int(Time.get_unix_time_from_system())
	if rice_next_ts <= 0:
		rice_next_ts = ahora + RICE_PERIOD
		return
	# El reloj pudo haber estado parado días: se cobran TODOS los sacos.
	while rice < RICE_START and ahora >= rice_next_ts:
		rice += 1
		rice_next_ts += RICE_PERIOD
	if rice >= RICE_START:
		rice_next_ts = 0


## Segundos que faltan para el próximo saco (0 = el saco está lleno).
func rice_seconds_left() -> int:
	tick_rice()
	if rice >= RICE_START or rice_next_ts <= 0:
		return 0
	return maxi(rice_next_ts - int(Time.get_unix_time_from_system()), 0)


## Cuenta atrás en h:mm:ss ("" si el saco está lleno).
func rice_time_text() -> String:
	var s := rice_seconds_left()
	if s <= 0:
		return ""
	return "%dh%02dm%02ds" % [s / 3600, (s % 3600) / 60, s % 60]


## Suma sacos sin pasarse del tope y pone en marcha el reloj si hacía falta.
func add_rice(n: int) -> void:
	rice = mini(rice + n, RICE_START)
	if rice < RICE_START and rice_next_ts <= 0:
		rice_next_ts = int(Time.get_unix_time_from_system()) + RICE_PERIOD
	elif rice >= RICE_START:
		rice_next_ts = 0
	save_game()


## Cuántos sacos del paquete se aprovecharían de verdad (el resto se perdería
## por el tope) y lo que costarían.
##
## El cobro es PROPORCIONAL: si un paquete de 5 por 3 lingotes se compra
## faltando solo 3 sacos, se pagan ceil(3 * 3/5) = 2. Se redondea hacia ARRIBA
## para no regalar fracciones.
func rice_deal(sacos: int, coste: int) -> Dictionary:
	tick_rice()
	var caben: int = mini(sacos, RICE_START - rice)
	if caben <= 0:
		return { "sacos": 0, "coste": 0 }
	if caben >= sacos:
		return { "sacos": sacos, "coste": coste }
	return { "sacos": caben, "coste": ceili(float(coste) * caben / float(sacos)) }


## Sacos de arroz a cambio de LINGOTES. Devuelve false si no llegan.
func buy_rice(sacos: int, coste: int) -> bool:
	if ingots < coste or sacos <= 0:
		return false
	ingots -= coste
	add_rice(sacos)
	return true


## ¿Se puede zarpar? Hace falta AL MENOS UN SACO: el arroz es la energía del
## juego y sin él no hay jornada.
func can_play() -> bool:
	tick_rice()
	return rice > 0


## Ingredientes de esa carta de los que NO queda ni un uso. Es lo que mira el
## mapa antes de zarpar a una ISLA: como ahí la carta viene impuesta, el jugador
## no puede esquivar lo que le falte y hay que avisarle.
func missing_ingredients(recipe_ids: Array) -> Array[String]:
	var out: Array[String] = []
	for ing in ingredients_for_selection(recipe_ids):
		if get_ingredient_uses(ing) <= 0:
			out.append(ing)
	return out


func consume_ingredients_for_level(recipe_ids: Array) -> bool:
	# NIVEL DE PRÁCTICA (solo el primero): no gasta DESPENSA, tampoco al
	# repetirlo. El ARROZ sí se gasta desde la primera jornada — es la energía
	# del juego y hay que verla bajar, o el saco que regala el bonus diario de
	# ese mismo día parece que no suma nada. El gasto de despensa empieza en el
	# nivel 2 (David lo avisa).
	var gratis: bool = is_adventure() and CampaignData.get_port(current_port) \
			.get("free_ingredients", false)
	if not can_play():
		return false
	# Tipo explícito: con el ternario, el `[]` llega como Array pelado y la
	# asignación a un Array[String] revienta en tiempo de ejecución (y el nivel
	# se caía entero al arrancar).
	var needed: Array[String] = []
	if not gratis:
		needed = ingredients_for_selection(recipe_ids)
	for ing in needed:
		if get_ingredient_uses(ing) <= 0:
			return false
	for ing in needed:
		ingredients[ing] = get_ingredient_uses(ing) - 1
	# UN SACO POR JORNADA. Aquí es donde el arroz se gasta de verdad; sin esto
	# el contador de los 90 min no bajaría nunca del tope y no se vería.
	if rice > 0:
		rice -= 1
		if rice_next_ts <= 0:
			rice_next_ts = int(Time.get_unix_time_from_system()) + RICE_PERIOD
	save_game()
	return true


## ARCADE SIN FIN: cada oleada nueva cuesta 1 uso de cada ingrediente DISTINTO
## de la carta vigente (el arroz no: es UN saco por partida, cobrado al zarpar
## como en cualquier jornada). Devuelve los ingredientes que se han AGOTADO con
## este cobro: el nivel retira de la carta las recetas que los llevan, que es
## la segunda forma de perder — sin carta no hay variedad, sin variedad llegan
## los vacíos.
func consume_wave_ingredients(recipe_ids: Array) -> Array[String]:
	var agotados: Array[String] = []
	for ing in ingredients_for_selection(recipe_ids):
		var quedan := get_ingredient_uses(ing)
		if quedan <= 0:
			continue
		ingredients[ing] = quedan - 1
		if quedan <= 1:
			agotados.append(ing)
	save_game()
	return agotados


## Oleadas de despensa que quedan con esta carta: el MÍNIMO de usos entre sus
## ingredientes de pago. Es la cifra del HUD del arcade — el jugador puede
## actuar sobre ella (soltar una receta cara, fichar barato). 999 = la carta no
## gasta nada (todo gratis), que en la práctica es "sin límite".
func pantry_waves_left(recipe_ids: Array) -> int:
	var menor := -1
	for ing in ingredients_for_selection(recipe_ids):
		var usos := get_ingredient_uses(ing)
		menor = usos if menor < 0 else mini(menor, usos)
	return 999 if menor < 0 else menor


## Los EXTRAS (jengibre, wasabi, soja) NO van por partida: cada plato al que
## se le echa uno gasta una unidad. Se descuentan al servirlo a la cinta.
## ¿Esta ganada la mejora de esa receta? (ver RecipeData.UPGRADES).
func upgrade_unlocked(base_id: String) -> bool:
	return base_id in unlocked_upgrades


## Un uso de despensa de un ingrediente de MEJORA (mismo contrato que los
## extras: se cobra al transformar, que es cuando el ingrediente se echa).
func consume_upgrade_ingredient(id: String) -> bool:
	if get_ingredient_uses(id) <= 0:
		return false
	ingredients[id] = get_ingredient_uses(id) - 1
	return true


func consume_extra(id: String) -> bool:
	if get_ingredient_uses(id) <= 0:
		return false
	ingredients[id] = get_ingredient_uses(id) - 1
	bump_stat("extras_used")
	return true


# --- Tienda: surtido del día -----------------------------------------------

func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


## --- Bonus diario ----------------------------------------------------------

## Ayer, en el mismo formato que `_today`.
func _yesterday() -> String:
	var t := Time.get_unix_time_from_system() - 86400
	var d := Time.get_date_dict_from_unix_time(int(t))
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


## CUANTO FALTA PARA EL PROXIMO BONUS, ya escrito ("7h 21m"). El bonus se
## renueva al cambiar el DIA del aparato (`_today`), asi que lo que falta es lo
## que queda hasta la medianoche local. Lo enseña el icono del cofre del menu
## cuando el de hoy ya esta cobrado.
func daily_wait_text() -> String:
	var d := Time.get_datetime_dict_from_system()
	var faltan := 86400 - (int(d.hour) * 3600 + int(d.minute) * 60 + int(d.second))
	var h := faltan / 3600
	var m := (faltan % 3600) / 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	return "%dm" % maxi(m, 1)


## ¿Queda premio por cobrar hoy?
func daily_available() -> bool:
	return daily_last != _today()


## Día de la racha que se cobraría AHORA (1..7), sin cobrarlo.
func daily_next_day() -> int:
	if not daily_available():
		return daily_day
	# La racha solo sigue si el último cobro fue AYER. Con un hueco de por
	# medio se vuelve a empezar: el bonus premia venir a diario, no acumular
	# días sueltos. Y pasado el 7 el ciclo vuelve a empezar.
	if daily_last == _yesterday() and daily_day < DailyData.day_count():
		return daily_day + 1
	return 1


## Cobra el premio de hoy y devuelve lo que se ha dado, para que el cartel lo
## pueda enseñar: { money, rice, ingots, bait, maps, extras, ingredients,
## recipe }. Los sorteos (`extra_random`, `ingredient_random`) se resuelven
## AQUÍ, al abrir el cofre, y salen ya resueltos dentro de `ingredients`.
## Devuelve {} si hoy ya estaba cobrado.
func claim_daily() -> Dictionary:
	if not daily_available():
		return {}
	var n := daily_next_day()
	var premio := DailyData.day(n)
	daily_day = n
	daily_last = _today()
	var dado := { "day": n }
	# EL ORO ESCALA CON EL NIVEL del cocinero (DailyData.ORO_POR_NIVEL).
	var oro := DailyData.money_for(int(premio.get("money", 0)), chef_level)
	if premio.has("recipe"):
		# La receta del día 7 solo se entrega una vez; quien ya la tenga cobra
		# doblones en su lugar para que la última casilla no salga vacía.
		if unlock_recipe(str(premio["recipe"])):
			dado["recipe"] = str(premio["recipe"])
			gift_ingredients_for([str(premio["recipe"])], PORT_GIFT)
		else:
			oro += DailyData.money_for(DailyData.RECIPE_FALLBACK, chef_level)
	if oro > 0:
		money += oro
		dado["money"] = oro
	if premio.has("rice"):
		add_rice(int(premio["rice"]))
		dado["rice"] = int(premio["rice"])
	if premio.has("ingots"):
		ingots += int(premio["ingots"])
		dado["ingots"] = int(premio["ingots"])
	# Los cebos solo con la PESCA abierta: antes de Cai no hay dónde usarlos, y
	# no se guardan para después (la racha es una cadencia, no una deuda).
	if premio.has("bait") and fishing_unlocked():
		bait += int(premio["bait"])
		dado["bait"] = int(premio["bait"])
	if premio.has("maps"):
		treasure_maps += int(premio["maps"])
		dado["maps"] = int(premio["maps"])
	if premio.has("extras"):
		for e in RecipeData.EXTRAS:
			add_ingredient_uses(e, int(premio["extras"]))
		dado["extras"] = int(premio["extras"])
	var ings: Dictionary = {}
	for k in premio.get("ingredients", {}):
		ings[str(k)] = int(premio["ingredients"][k])
	# Sorteos de la apertura: UN extra al azar y UN ingrediente normal al azar
	# de entre los que el jugador ya usa.
	if premio.has("extra_random"):
		var e: String = RecipeData.EXTRAS.pick_random()
		ings[e] = int(ings.get(e, 0)) + int(premio["extra_random"])
	if premio.has("ingredient_random"):
		var ing := _random_known_ingredient()
		if ing != "":
			ings[ing] = int(ings.get(ing, 0)) + int(premio["ingredient_random"])
	if not ings.is_empty():
		for k in ings:
			add_ingredient_uses(str(k), int(ings[k]))
		dado["ingredients"] = ings
	save_game()
	# COLECCIONABLE "mapa del tesoro": completar los 7 días de la racha.
	if n >= DailyData.day_count():
		unlock_collectible("mapa_tesoro")
	return dado


## Un ingrediente NORMAL al azar (ni extras ni gratis) de entre los que usan
## las recetas que el jugador ya sabe cocinar — el mismo filtro que el surtido
## de Saverio: regalar atún antes de tener una receta con atún no sirve de
## nada. Si todavía no sabe ninguna receta que cueste despensa, cae a cualquier
## ingrediente de pago; "" solo si no hay ninguno.
func _random_known_ingredient() -> String:
	var utiles := {}
	for rid in unlocked_recipes:
		for ing in RecipeData.get_ingredients(rid):
			utiles[ing] = true
	var pool: Array[String] = []
	var todos: Array[String] = []
	for ing in RecipeData.INGREDIENTS:
		if ing in RecipeData.EXTRAS \
				or int(RecipeData.INGREDIENTS[ing].get("cost", 0)) <= 0:
			continue
		todos.append(ing)
		if utiles.has(ing):
			pool.append(ing)
	if pool.is_empty():
		pool = todos
	return "" if pool.is_empty() else pool.pick_random()


## Renueva el surtido si ha cambiado el día (o si el guardado no traía uno).
## También rehace un surtido viejo que se hubiera colado con extras dentro.
func refresh_shop_if_new_day() -> void:
	if shop_day == _today() and shop_stock.size() == SHOP_SLOTS \
			and not _stock_has_extras():
		return
	roll_shop_stock()
	shop_day = _today()
	save_game()


func _stock_has_extras() -> bool:
	for ing in shop_stock:
		if ing in RecipeData.EXTRAS:
			return true
	return false


## Sortea 8 ingredientes distintos de entre los que se venden (el arroz es
## infinito y no entra). Los EXTRAS quedan fuera: tienen su propia balda y el
## tendero los tiene SIEMPRE, así que sortearlos ocuparía un hueco del día.
## EL SURTIDO COMPLETO DE SAVERIO (pedido por el usuario: la tienda ya no
## rota cada dia — con muchos ingredientes, que el que necesitas no este era
## una loteria injusta). Todo el genero UTIL: los ingredientes de pago de las
## recetas desbloqueadas MAS los de coronacion de las mejoras ganadas (la
## receta mejorada no tiene pasos, asi que sus ingredientes no salen de
## get_ingredients y hay que sumarlos aparte). ORDENADO POR ESCASEZ: lo que
## falta (0 usos) primero, y despues de menos a mas existencias.
func shop_catalog() -> Array[String]:
	var utiles := {}
	for rid in unlocked_recipes:
		for ing in RecipeData.get_ingredients(rid):
			utiles[ing] = true
	for base in unlocked_upgrades:
		for ing in RecipeData.upgrade_of(base).get("ingredients", []):
			utiles[ing] = true
	var out: Array[String] = []
	for ing in RecipeData.INGREDIENTS:
		if ing in RecipeData.EXTRAS or not utiles.has(ing):
			continue
		if int(RecipeData.INGREDIENTS[ing].get("cost", 0)) > 0:
			out.append(ing)
	# Orden ESTABLE: a igual existencias se queda el orden del catalogo.
	var con_usos: Array = []
	for i in out.size():
		con_usos.append([get_ingredient_uses(out[i]), i, out[i]])
	con_usos.sort()
	var ordenado: Array[String] = []
	for fila in con_usos:
		ordenado.append(str(fila[2]))
	return ordenado


## (HISTORICO) El surtido rotatorio de 8 del dia: la tienda ya vende TODO el
## genero via shop_catalog(). Se conserva porque los guardados llevan
## shop_stock/shop_day dentro y porque reroll_shop es quien suma shop_spent.
func roll_shop_stock() -> void:
	# Saverio solo saca a la balda lo que sirve para las recetas que YA sabes
	# cocinar: ofrecer atún antes de tener una receta con atún no dice nada.
	var utiles := {}
	for rid in unlocked_recipes:
		for ing in RecipeData.get_ingredients(rid):
			utiles[ing] = true
	var pool: Array[String] = []
	for ing in RecipeData.INGREDIENTS:
		if ing in RecipeData.EXTRAS or not utiles.has(ing):
			continue
		if int(RecipeData.INGREDIENTS[ing].get("cost", 0)) > 0:
			pool.append(ing)
	pool.shuffle()
	# NADA REPETIDO de la tanda anterior: recargar y que vuelva a salir lo mismo
	# es tirar el dinero. Se sortea primero entre lo que NO estaba, y solo si no
	# hay bastante género distinto se rellena con lo de antes (con pocas recetas
	# desbloqueadas el surtido no da para ocho artículos nuevos).
	var antes := {}
	for ing in shop_stock:
		antes[ing] = true
	var nuevos: Array[String] = []
	var repes: Array[String] = []
	for ing in pool:
		if antes.has(ing):
			repes.append(ing)
		else:
			nuevos.append(ing)
	shop_stock = []
	for ing in nuevos + repes:
		if shop_stock.size() >= SHOP_SLOTS:
			break
		shop_stock.append(ing)


## "Recargar artículos": paga y vuelve a sortear. False si no llega el dinero.
func reroll_shop() -> bool:
	if money < SHOP_REROLL_COST:
		return false
	money -= SHOP_REROLL_COST
	bump_stat("money_spent", SHOP_REROLL_COST)
	bump_stat("shop_spent", SHOP_REROLL_COST)
	roll_shop_stock()
	save_game()
	return true


## El plato MÁS CARO de la carta elegida hoy (ni postres ni picoteos): el
## antojo de la fase 3 del Kappa y el encargo del capitán del mapa (m2_05).
## Vive aquí para que el guion y el resolvedor del reto no puedan divergir.
func plato_mas_caro_de_la_carta() -> String:
	var mejor := ""
	var precio := -1
	for id in selected_recipes:
		var r: Dictionary = RecipeData.RECIPES.get(id, {})
		if bool(r.get("leaves_seat", false)) or bool(r.get("snack", false)):
			continue
		if int(r.get("price", 0)) > precio:
			precio = int(r.get("price", 0))
			mejor = str(id)
	if mejor == "" and not selected_recipes.is_empty():
		mejor = str(selected_recipes[0])
	return mejor


# --- Potenciadores permanentes ---------------------------------------------

func is_perk_unlocked(id: String) -> bool:
	return id in unlocked_perks


## Desbloquea un bonificador por combo. Devuelve true si era NUEVO (para
## anunciarlo en el panel de resultados). El uso lo da `unlock_perk` siempre:
## la acción es REPETIBLE y cada vez que se cumple deja otro uso, así que la
## primera vez desbloquea Y regala, y las siguientes solo regalan.
func unlock_perk(id: String) -> bool:
	var nuevo := not id in unlocked_perks
	if nuevo:
		unlocked_perks.append(id)
		perk_level[id] = 1
		bump_stat("perks_unlocked", 1)
	perk_uses[id] = int(perk_uses.get(id, 0)) + 1
	save_game()
	return nuevo


func get_perk_uses(id: String) -> int:
	return int(perk_uses.get(id, 0))


func add_perk_uses(id: String, amount: int) -> void:
	perk_uses[id] = get_perk_uses(id) + amount


## ¿Existen ya los BONIFICADORES como sistema? Se abren con la llegada de ALICE
## y su ayudante de cocina (`unlocks_perks` en CampaignData), y NO antes: hasta
## ese momento no se pueden ganar, ni siquiera los que no atan su propio puerto.
## Estuvo repartido —el paladar lo regalaba Puerto Tormenta y `cocina_veloz` no
## tenía compuerta ninguna, así que se ganaba desde el escenario 1—, y así los
## bonificadores aparecían a cachos y sin una escena detrás.
func perks_unlocked() -> bool:
	for p in CampaignData.PORTS:
		if not bool(p.get("unlocks_perks", false)):
			continue
		return int(level_stars.get(p["id"], 0)) >= int(p.get("goal_stars", 1))
	return true


## ¿Está ABIERTA la compuerta de campaña de este bonificador? Primero tiene que
## existir el sistema (ver arriba); además, cada bonificador puede tener SU
## puerto (`unlocks_perk`), y hasta ese momento no se gana aunque se cumpla su
## combo: aparecería una mecánica sin explicar. Uno que no pida puerto propio
## está abierto en cuanto lo está el sistema.
func perk_gate_open(id: String) -> bool:
	if not perks_unlocked():
		return false
	for p in CampaignData.PORTS:
		if str(p.get("unlocks_perk", "")) != id:
			continue
		return int(level_stars.get(p["id"], 0)) >= int(p.get("goal_stars", 1))
	# UN BONIFICADOR QUE PIDE ESCENARIO Y NO LO TIENE SIGUE CERRADO
	# (`needs_port` en PerkData): es lo que aparca el BARCO para el mar 2. Sin
	# esto, quitarle su puerto lo dejaba abierto de par en par, que es justo lo
	# contrario de lo que se busca.
	if bool(PerkData.get_perk(id).get("needs_port", false)):
		return false
	return true


## Nivel de mejora (1..PerkData.MAX_LEVEL). Un bonificador sin desbloquear
## devuelve 1 igualmente: es lo que valdría el día que se gane.
func get_perk_level(id: String) -> int:
	return clampi(int(perk_level.get(id, 1)), 1, PerkData.MAX_LEVEL)


## Valor del EFECTO del bonificador con el nivel que tenga hoy el jugador.
func perk_value(id: String) -> float:
	return PerkData.value_at(id, get_perk_level(id))


## Sube un nivel pagando su coste. Devuelve false si no se puede (ya está al
## máximo, no está desbloqueado o falta dinero).
func upgrade_perk(id: String) -> bool:
	if not is_perk_unlocked(id):
		return false
	var nivel := get_perk_level(id)
	var coste := PerkData.upgrade_cost(nivel)
	if coste <= 0 or money < coste:
		return false
	money -= coste
	bump_stat("money_spent", coste)
	perk_level[id] = nivel + 1
	bump_stat("perk_upgrades", 1)
	max_stat("best_perk_level", nivel + 1)
	save_game()
	return true


## Gasta 1 uso de cada potenciador elegido al empezar el nivel. Los que no
## tengan usos se descartan de la selección.
func consume_perks_for_level() -> void:
	var kept: Array[String] = []
	for id in selected_perks:
		if get_perk_uses(id) > 0:
			perk_uses[id] = get_perk_uses(id) - 1
			kept.append(id)
	selected_perks = kept
	save_game()


func has_perk(id: String) -> bool:
	return id in selected_perks


# --- Maestrías del cocinero (nivel, experiencia y habilidades) ---------------
# El catálogo y la economía viven en `skill_data.gd`; aquí está el ESTADO: la
# experiencia acumulada, el nivel que sale de ella y los rangos comprados.
# Los puntos NO se guardan: total = nivel (el 1 ya trae el suyo), gastado = lo
# que suman los rangos, libre = la resta. Así un guardado no puede descuadrarse.

## Experiencia acumulada del cocinero (persistente).
var chef_xp := 0
## Nivel vigente (1..SkillData.MAX_LEVEL). Se deriva de chef_xp al cargar y se
## mantiene al día en add_chef_xp; se guarda solo por legibilidad del save.
var chef_level := 1
## ¿Ya se sembró la experiencia retroactiva de los escenarios superados ANTES
## de que existieran las maestrías? Bandera propia y no "¿falta chef_xp?": ver
## la explicación en `load_game`.
var xp_seeded := false
## PUNTOS INVERTIDOS en cada habilidad: id -> 0..max_points (sin entrada = 0).
## Se invierten DE UNO EN UNO y el RANGO es su escalón (ver
## `SkillData.rank_for_points`): con coste 5, cuatro puntos no desbloquean
## nada y el quinto sube al rango 1. Guardar los puntos y derivar el rango —y
## no al revés— es lo que permite el reparto continuo.
var skills: Dictionary = {}
## Mejor OLEADA alcanzada en el arcade sin fin (el récord del cartel de fin).
var arcade_best := 0
## XP con la que se ENTRÓ a la última tanda de ganancias (-1 = nada
## pendiente). Lo consume la BARRA DE NIVEL del menú para animar el relleno
## con lo recién ganado. De SESIÓN: no se guarda.
var xp_anim_from := -1


## ¿Partida de ARCADE? Es el modo libre de siempre ("test"), que desde el
## rediseño del arcade sin fin SÍ toca el progreso: gasta arroz y despensa,
## paga experiencia y dinero, y se juega con habilidades y bonificadores.
func is_arcade() -> bool:
	return mode == "test"


func chef_points_total() -> int:
	return chef_level


func chef_points_spent() -> int:
	var total := 0
	for id in skills:
		total += int(skills[id])
	return total


func chef_points_free() -> int:
	return maxi(chef_points_total() - chef_points_spent(), 0)


## Puntos INVERTIDOS en una habilidad (0..max_points).
func skill_points(id: String) -> int:
	return clampi(int(skills.get(id, 0)), 0, SkillData.max_points(id))


## RANGO vigente (0..5), derivado de los puntos invertidos.
func skill_rank(id: String) -> int:
	return SkillData.rank_for_points(id, skill_points(id))


## Valor del efecto con el rango que tenga hoy el jugador (0 sin comprar).
func skill_value(id: String) -> float:
	return SkillData.value_at(id, skill_rank(id))


## Serie secundaria de una habilidad ("waste", "fry_widen"...), con su valor
## por defecto para cuando no está comprada.
func skill_aux(id: String, key: String, fallback: float) -> float:
	return SkillData.aux_at(id, key, skill_rank(id), fallback)


## ¿Se puede invertir UN punto más en esta habilidad AHORA?
func can_buy_skill(id: String) -> bool:
	if SkillData.get_skill(id).is_empty():
		return false
	if skill_points(id) >= SkillData.max_points(id):
		return false
	for p in SkillData.prereqs(id):
		if skill_rank(p) <= 0:
			return false
	return chef_points_free() >= 1


## Invierte UN punto. Devuelve false sin tocar nada si no se puede. El rango
## sube solo cuando la inversión cruza su listón (quien llama compara el rango
## de antes y el de después para celebrar el desbloqueo).
func buy_skill(id: String) -> bool:
	if not can_buy_skill(id):
		return false
	skills[id] = skill_points(id) + 1
	bump_stat("skills_points_spent")
	# Logro "conseguir x maestrías": por MÁXIMO de habilidades APRENDIDAS a la
	# vez (rango ≥ 1), no por puntos ni por compras — con la reasignación
	# libre, contar compras se inflaba invirtiendo y devolviendo lo mismo.
	max_stat("skills_owned", skills_owned())
	save_game()
	return true


## Habilidades con rango ≥ 1 (las APRENDIDAS: una a medio invertir no cuenta).
func skills_owned() -> int:
	var n := 0
	for id in skills:
		if skill_rank(str(id)) > 0:
			n += 1
	return n


## ¿Se puede RECUPERAR un punto? Siempre que haya alguno invertido, salvo si
## sacarlo bajaría el rango a 0 y otra habilidad aprendida depende de esta
## (quitar Fuego constante con el Corte de maestro puesto dejaría el árbol
## descolgado).
func can_refund_skill(id: String) -> bool:
	var pts := skill_points(id)
	if pts <= 0:
		return false
	# Solo el punto que sostiene el rango 1 puede dejar huérfano a otro.
	if pts == SkillData.rank_cost(id):
		for otro in SkillData.SKILLS:
			if skill_rank(str(otro)) > 0 and id in SkillData.prereqs(str(otro)):
				return false
	return true


## Devuelve UN punto al bolsillo. La REASIGNACIÓN ES LIBRE por diseño: el
## jugador cambia de estrategia cuando quiera, punto a punto — la pantalla es
## quien confirma cuando el punto que sale hace PERDER la habilidad.
func refund_skill(id: String) -> bool:
	if not can_refund_skill(id):
		return false
	var pts := skill_points(id) - 1
	if pts <= 0:
		skills.erase(id)
	else:
		skills[id] = pts
	save_game()
	return true


## REINICIA UN ÁRBOL ENTERO: saca todos los puntos de sus cinco habilidades y
## los devuelve al bolsillo. Devuelve cuántos ha recuperado.
##
## NO pasa por `refund_skill`: ese tiene el candado de los prerrequisitos (no
## deja quitar el punto que sostiene a una aprendida), y aquí se van TODAS a la
## vez, así que ninguna se queda huérfana. Es la salida rápida para el jugador
## que quiere replantear su árbol sin ir punto a punto.
func reset_skill_tree(tree: String) -> int:
	var sueltos := 0
	for id in SkillData.tree_skills(tree):
		var sid := str(id)
		sueltos += skill_points(sid)
		skills.erase(sid)
	if sueltos > 0:
		save_game()
	return sueltos


## Puntos invertidos en TODO un árbol (lo que devolvería reiniciarlo).
func tree_points(tree: String) -> int:
	var total := 0
	for id in SkillData.tree_skills(tree):
		total += skill_points(str(id))
	return total


## Suma experiencia y devuelve los niveles ganados. El aviso de subida sale por
## la capa global (un solo toast aunque caigan varios niveles de golpe: un pago
## gordo del arcade puede subir cinco y cinco carteles serían spam).
## Premios de las subidas de nivel aún SIN ANUNCIAR. Los entrega `add_chef_xp`
## en el acto (el jugador ya los tiene) y los anuncia quien tenga la pantalla
## delante: el cartel de fin de nivel o, si no pasó por él, la barra del menú.
## { "desde": n, "hasta": n, "premios": { clave -> cantidad } }
var pending_level_up: Dictionary = {}


func take_level_up() -> Dictionary:
	var out := pending_level_up
	pending_level_up = {}
	return out


## Saca la ventana de subida de nivel por la capa global de avisos.
func announce_level_up(resumen: Dictionary) -> void:
	_ensure_notices().announce_level_up(resumen)


## COMPUERTAS DE LOS PREMIOS DE NIVEL: un premio no cae hasta que el juego ha
## EXPLICADO qué es. Es la razón por la que la despensa, los extras, el arroz y
## los lingotes estuvieron desactivados un tiempo — caían antes de que el
## jugador supiera qué tenía en la mano. El oro y el punto de maestría no
## necesitan compuerta: se entienden solos.
##
## Si a un nivel le tocaba un premio todavía cerrado, ESE premio se pierde y
## no se guarda para después: la serie es una cadencia, no una deuda.
func reward_gates() -> Dictionary:
	return {
		# El cebo espera a la CLASE de Cai, no solo a que la pesca esté abierta:
		# regalado antes, el jugador no sabe qué es ni dónde se gasta.
		"bait": fishing_intro_done,
		"rice": rice_intro_done,
		"ingots": ingots_intro_done,
		"ingredients": shop_unlocked(),
		"extras": extras_unlocked(),
	}


func add_chef_xp(amount: int) -> int:
	if amount <= 0 or is_tutorial():
		return 0
	# La barra del menú anima desde donde estaba ANTES de la primera ganancia
	# pendiente (varias jornadas seguidas sin pasar por el menú se acumulan).
	if xp_anim_from < 0:
		xp_anim_from = chef_xp
	chef_xp += amount
	var nuevo := SkillData.level_for_xp(chef_xp)
	var ganados := nuevo - chef_level
	if ganados <= 0:
		return 0
	var desde := chef_level
	chef_level = nuevo
	max_stat("chef_level", chef_level)
	# CADA NIVEL SUELTA SU PREMIO, y se suman todos los de la tanda: subir
	# cinco de golpe con un arcade largo tiene que sentirse como cinco cofres,
	# no como cinco carteles seguidos.
	var premios: Dictionary = {}
	var puertas := reward_gates()
	for n in range(desde + 1, nuevo + 1):
		var premio := SkillData.level_reward(n, puertas)
		for clave in premio:
			premios[clave] = int(premios.get(clave, 0)) + int(premio[clave])
	_grant_level_rewards(premios)
	var anterior: Dictionary = pending_level_up
	if anterior.is_empty():
		pending_level_up = { "desde": desde, "hasta": nuevo, "premios": premios }
	else:
		# Dos tandas sin pasar por ninguna pantalla: se funden en una.
		anterior["hasta"] = nuevo
		var acum: Dictionary = anterior["premios"]
		for clave in premios:
			acum[clave] = int(acum.get(clave, 0)) + int(premios[clave])
	save_game()
	return ganados


## Ingresa lo que sueltan las subidas de nivel. Los PUNTOS no se ingresan: se
## deducen del nivel (`chef_points_total`), así que no hay nada que sumar.
func _grant_level_rewards(premios: Dictionary) -> void:
	var oro := int(premios.get("gold", 0))
	if oro > 0:
		money += oro
		bump_stat("money_total", oro)
	var cebos := int(premios.get("bait", 0))
	if cebos > 0:
		bait += cebos
	var lingotes := int(premios.get("ingots", 0))
	if lingotes > 0:
		ingots += lingotes
	var sacos := int(premios.get("rice", 0))
	if sacos > 0:
		add_rice(sacos)
	var extras := int(premios.get("extras", 0))
	if extras > 0:
		for e in RecipeData.EXTRAS:
			add_ingredient_uses(str(e), extras)
	var usos := int(premios.get("ingredients", 0))
	if usos > 0:
		# Reparte entre lo que piden las recetas que YA se saben cocinar: un
		# regalo de despensa que no sirva para nada no es un regalo.
		var utiles: Array[String] = []
		for rid in unlocked_recipes:
			for ing in RecipeData.get_ingredients(str(rid)):
				if int(RecipeData.get_ingredient(str(ing)).get("cost", 0)) > 0 \
						and not str(ing) in utiles:
					utiles.append(str(ing))
		utiles.shuffle()
		for i in mini(2, utiles.size()):
			add_ingredient_uses(utiles[i], usos)


## Experiencia de un ESCENARIO recién cerrado. Se paga contra el RÉCORD, así
## que hay que llamarla con las estrellas de ANTES (`prev_stars`), es decir,
## ANTES de complete_port:
##  · sin récord (nunca puntuado): 3 × base × mult(estrellas) — el estreno.
##  · repetición: base × mult, y si el récord MEJORA, además 3 × base × la
##    diferencia de multiplicadores. Mejorar de 2★ a 3★ cobra solo el salto.
func scenario_xp(port_id: String, stars: int, prev_stars: int) -> int:
	var n := CampaignData.port_index(port_id) + 1
	if n <= 0 or stars <= 0:
		return 0
	var base := float(SkillData.XP_SCENARIO * n)
	# LOS ESCENARIOS DE JEFE PAGAN ×1,5 (era el doble; el usuario lo bajó). Se
	# multiplica la BASE, así que el plus llega igual al estreno, a la
	# repetición y a la mejora de récord, sin tocar la regla de que mejorar
	# cobra solo el salto. El jefe sigue siendo el día de paga del mar.
	if str(CampaignData.get_port(port_id).get("boss", "")) != "":
		base *= SkillData.XP_BOSS_MULT
	var m := float(SkillData.STAR_MULT[clampi(stars, 0, 3)])
	var prev_m := float(SkillData.STAR_MULT[clampi(prev_stars, 0, 3)])
	if prev_stars <= 0:
		return int(round(base * m * SkillData.FIRST_MULT))
	var pago := base * m
	if m > prev_m:
		pago += base * (m - prev_m) * SkillData.FIRST_MULT
	return int(round(pago))


## PRIMA DE EXPERIENCIA POR EL ORO DE MÁS. `oro` es lo que se lleva el jugador
## de la jornada ENTERA (platos + propinas + primas de cierre), y el objetivo es
## el escalón de las 3 estrellas, que es el que el juego llama "objetivo" en la
## ficha y el que cierra el turno antes de tiempo.
##
## La tarifa por moneda sale del propio escenario —lo que paga dividido por su
## objetivo— y de ella se cobran DOS TERCIOS (`XP_EXTRA_FRAC`). Ejemplo con la
## cuenta del usuario: un escenario que paga 50 con un objetivo de 40 monedas
## vale 1,25 de experiencia por moneda; 10 monedas de más son 12,5, y dos
## tercios de eso son 8 de prima.
##
## `pago` es la experiencia que ese mismo cierre ha pagado, así que la prima
## acompaña al escenario: crece con su número y con las estrellas sacadas.
func scenario_extra_xp(port_id: String, pago: int, oro: int) -> int:
	if pago <= 0 or oro <= 0:
		return 0
	var escalones: Array = CampaignData.get_port(port_id).get("star_money", [])
	if escalones.is_empty():
		return 0
	var objetivo := float(escalones[escalones.size() - 1])
	if objetivo <= 0.0:
		return 0
	var sobrante := float(oro) - objetivo
	if sobrante <= 0.0:
		return 0
	var tarifa := float(pago) / objetivo
	var extra := sobrante * tarifa * SkillData.XP_EXTRA_FRAC
	return int(round(minf(extra, float(pago) * SkillData.XP_EXTRA_CAP)))


## Experiencia de una partida de ARCADE: 15 × oleada por cada oleada superada.
func arcade_xp(waves_done: int) -> int:
	var total := 0
	for w in range(1, maxi(waves_done, 0) + 1):
		total += SkillData.ARCADE_WAVE_XP * w
	return total


## Apunta el récord de oleadas (y su estadística de logros). Devuelve true si
## es récord nuevo.
func record_arcade_wave(waves_done: int) -> bool:
	max_stat("arcade_wave", waves_done)
	if waves_done <= arcade_best:
		return false
	arcade_best = waves_done
	# El GALÓN DE ORO cuelga de este récord (no de una estadística), así que
	# hay que pedir la pasada a mano: `max_stat` de arriba solo mira `stats`.
	queue_achievement_check()
	return true


# --- Progreso de la campaña ------------------------------------------------

## ¿Está desbloqueado este nivel? El primero siempre; el resto, si el nivel
## anterior se ha superado con su objetivo de estrellas.
## ¿Este puerto ya está SUPERADO (sus estrellas llegan a `goal_stars`)? Es lo
## que decide si se está repitiendo: sin guion, con los cuatro huecos de receta
## y con la carta abierta.
## ¿Ya se ha VISTO el guion de este puerto? Se marca en cuanto termina la fase
## de preparación, no al superarlo: quedarse corto de estrellas y tener que
## repetir no debería obligar a tragarse las explicaciones otra vez. La segunda
## pasada se juega limpia, con las restricciones del puerto pero sin narración.
func port_narrated(port_id: String) -> bool:
	return port_id in narrated_ports


func mark_port_narrated(port_id: String) -> void:
	if port_id == "" or port_id in narrated_ports:
		return
	narrated_ports.append(port_id)
	save_game()


func port_beaten(port_id: String) -> bool:
	var port := CampaignData.get_port(port_id)
	if port.is_empty():
		return false
	return int(level_stars.get(port_id, 0)) >= int(port.get("goal_stars", 1))


func is_port_unlocked(port_id: String) -> bool:
	var prev_id := CampaignData.prev_port_id(port_id)
	if prev_id == "":
		return true
	var prev_port := CampaignData.get_port(prev_id)
	return int(level_stars.get(prev_id, 0)) >= int(prev_port.get("goal_stars", 1))


## Guarda la mejor puntuación (dinero ganado) de un nivel si supera la anterior.
func record_level_score(port_id: String, money: int) -> void:
	if money > int(level_scores.get(port_id, 0)):
		level_scores[port_id] = money
		save_game()


## Puntuación máxima (dinero ganado) registrada en un nivel; 0 si no se jugó.
func get_level_score(port_id: String) -> int:
	return int(level_scores.get(port_id, 0))


## Registra el resultado de un nivel y aplica sus recompensas la PRIMERA vez
## que se alcanza su objetivo. Guarda a disco. Devuelve las recetas nuevas
## desbloqueadas (Array de ids).
func complete_port(port_id: String, stars: int) -> Array:
	var newly: Array = []
	var port := CampaignData.get_port(port_id)
	if port.is_empty():
		return newly
	var goal := int(port.get("goal_stars", 1))
	var prev_best: int = int(level_stars.get(port_id, -1))
	# Guarda la mejor puntuación en estrellas.
	if stars > prev_best:
		level_stars[port_id] = stars
	# Recompensas solo al superar el objetivo por primera vez.
	if stars >= goal and prev_best < goal:
		for r in port.get("reward_recipes", []):
			if unlock_recipe(r):
				newly.append(r)
		# Lo que REGALA David dentro del nivel se desbloquea igualmente al
		# superarlo: si la partida se cerró por objetivo antes de que llegara su
		# momento (el salmón tsuke don del nivel 5), la receta se quedaba sin
		# aprender aunque el puerto estuviera superado.
		for r in port.get("gift_recipes", []):
			if unlock_recipe(r):
				newly.append(r)
	# Premio de las TRES estrellas, aparte y solo la primera vez que se sacan.
	# Va por separado del anterior a propósito: se puede aprobar hoy con 2 y
	# volver mañana, con mejor carta, a por las 3.
	# (La BANDERA PIRATA ya no se gana aquí: se la regala EN MANO el pirata del
	# Estrecho del Rayo cuando se le da bien de comer, ver
	# `level_director._nivel_7`. Colgada de "un abordaje con 3 estrellas" no
	# tenía ninguna escena detrás: aparecía sola en el cartel de resultados.)
	if stars >= 3 and prev_best < 3:
		for r in port.get("reward_recipes_3", []):
			if unlock_recipe(r):
				newly.append(r)
		# MEJORA DE RECETA (mar 2): se apunta la base, se desbloquea la receta
		# mejorada (oculta: ni selector ni recetario, pero sus ingredientes
		# entran al surtido de Saverio) y ALICE la presenta en el mapa.
		var mejora_base := str(port.get("reward_upgrade_3", ""))
		if mejora_base != "" and not mejora_base in unlocked_upgrades:
			unlocked_upgrades.append(mejora_base)
			var mejora: Dictionary = RecipeData.upgrade_of(mejora_base)
			if not mejora.is_empty():
				unlock_recipe(str(mejora.get("id", "")))
				# Y despensa de estreno de sus dos ingredientes.
				for ing in mejora.get("ingredients", []):
					ingredients[ing] = get_ingredient_uses(ing) + PORT_GIFT
			pending_mejora_intro = true
		var lingotes := int(port.get("reward_ingots_3", 0))
		if lingotes > 0:
			ingots += lingotes
		var sacos := int(port.get("reward_rice_3", 0))
		if sacos > 0:
			rice = mini(rice + sacos, RICE_START)
		# USOS DE DESPENSA de regalo (ingredientes o extras: viven en la misma
		# despensa). Lo usan los escenarios de practica.
		var usos: Dictionary = port.get("reward_ingredients_3", {})
		for ing in usos:
			ingredients[ing] = get_ingredient_uses(ing) + int(usos[ing])
		# CEBO: tiradas de pesca gratis.
		var cebos := int(port.get("reward_bait_3", 0))
		if cebos > 0:
			bait += cebos
	if not newly.is_empty():
		# Toda receta nueva llega con despensa para estrenarla.
		gift_ingredients_for(newly, PORT_GIFT)
		# NO se pone `pending_reveal`: el cartel de fin de nivel ya las anuncia
		# (`level3d._reveal_recipes`), y volver a enseñarlas al llegar al mapa
		# era repetir lo mismo dos veces seguidas. `pending_reveal` se queda solo
		# para el TUTORIAL, que no tiene cartel de resultados.
	save_game()
	return newly


# --- MODO DEBUG ------------------------------------------------------------

## Pone a mano los contadores gordos del progreso (Opciones -> Progreso ->
## Modo debug). Es herramienta de PRUEBAS, así que va sin ventanas ni escenas:
## el camino normal de cada cosa ya las saca y aquí solo estorbarían.
##
## Solo toca lo que venga en el diccionario, para poder cambiar una cosa sin
## arrasar con el resto.
func debug_apply(vals: Dictionary) -> void:
	if vals.has("money"):
		money = maxi(int(vals["money"]), 0)
	if vals.has("collectibles"):
		_debug_set_collectibles(int(vals["collectibles"]))
	if vals.has("fish"):
		_debug_set_fish(int(vals["fish"]))
	if vals.has("chef_level"):
		_debug_set_chef_level(int(vals["chef_level"]))
	if vals.has("ports"):
		_debug_set_ports(int(vals["ports"]))
	save_game()
	queue_achievement_check()


## Cuántos escenarios están superados de verdad (con su objetivo de estrellas).
func debug_ports_beaten() -> int:
	var n := 0
	for p in CampaignData.PORTS:
		if port_beaten(str(p["id"])):
			n += 1
	return n


func _debug_set_collectibles(n: int) -> void:
	var ids: Array[String] = []
	for it in CollectibleData.ITEMS:
		ids.append(str(it["id"]))
	n = clampi(n, 0, ids.size())
	collectibles.clear()
	for i in n:
		collectibles.append(ids[i])
	# El triángulo dorado son 8 fragmentos: si su pieza entra en la cuenta, los
	# fragmentos van llenos; si no, a cero. Si no, la vitrina enseñaría "3/8"
	# debajo de una pieza ya conseguida.
	triforce_pieces = CollectibleData.TRIFORCE_PIECES if "trifuerza" in collectibles else 0


func _debug_set_fish(n: int) -> void:
	n = clampi(n, 0, FishData.FISH.size())
	fish_album.clear()
	for i in n:
		fish_album[str(FishData.FISH[i]["id"])] = 1
	# Los RÉCORDS de talla de especies que ya no están en el álbum se van con
	# ellas: un récord de un pez sin pescar no lo puede enseñar nadie.
	for id in fish_best.keys():
		if not fish_album.has(id):
			fish_best.erase(id)


func _debug_set_chef_level(n: int) -> void:
	chef_level = clampi(n, 1, SkillData.MAX_LEVEL)
	# La XP se pone en la ENTRADA del nivel, para que la barra salga vacía y no
	# a media altura de un tramo que nadie ha jugado.
	chef_xp = SkillData.xp_at_level(chef_level)
	stats["chef_level"] = chef_level
	xp_seeded = true
	# Los puntos SALEN del nivel (`chef_points_total`), así que bajarlo puede
	# dejar más invertido de lo que se tiene. Antes que dejar el reparto
	# descuadrado se devuelve todo: es lo que hace `reset_skill_tree`, pero de
	# los tres árboles.
	if chef_points_spent() > chef_points_total():
		skills.clear()
	# Sin esto la barra del menú intentaría animar desde una XP que ya no existe.
	xp_anim_from = -1
	pending_level_up = {}


func _debug_set_ports(n: int) -> void:
	var ids: Array[String] = []
	for p in CampaignData.PORTS:
		ids.append(str(p["id"]))
	n = clampi(n, 0, ids.size())
	for i in range(n, ids.size()):
		level_stars.erase(ids[i])
	# Los que faltan se completan POR EL CAMINO NORMAL, para que caigan también
	# sus recetas y su despensa: sin ellas, "20 escenarios superados" deja el
	# juego con el maki suelto y sin poder jugarse, que no es lo que nadie
	# entiende por "niveles completados".
	for i in n:
		complete_port(ids[i], 3)


# --- Estadísticas y logros -------------------------------------------------

func get_stat(id: String) -> int:
	return int(stats.get(id, 0))


## Suma al contador (platos hechos, clientes servidos, doblones gastados...).
## EN EL TUTORIAL NO SE CUENTA NADA: ni platos, ni clientes, ni propinas suman
## a las estadísticas ni, por tanto, a los logros. El tutorial es la clase de
## David, no una partida — y como este es el único embudo por el que entran
## las estadísticas, el corte aquí cubre todos los orígenes de golpe.
func bump_stat(id: String, amount := 1) -> void:
	if amount == 0 or is_tutorial():
		return
	stats[id] = get_stat(id) + amount
	queue_achievement_check()


## Guarda un RÉCORD: solo se queda si supera al anterior (mejor partida, platos
## de un mismo cliente...). En el tutorial tampoco cuenta (ver bump_stat).
func max_stat(id: String, value: int) -> void:
	if is_tutorial():
		return
	if value > get_stat(id):
		stats[id] = value
		queue_achievement_check()


## Suma tiempo de juego a mano. YA NO LO USA NADIE en el bucle normal (lo lleva
## el `_process` de este autoload); se conserva por si algún día hace falta
## sumar un rato que el motor no haya contado.
func add_play_time(seconds: float) -> void:
	play_seconds += seconds


## Horas jugadas con un decimal, para la pestaña de Progreso.
func play_hours() -> float:
	return play_seconds / 3600.0


## "3 h 42 min" / "12 min": el texto que se enseña al jugador.
func play_time_text() -> String:
	var total := int(play_seconds)
	var h := total / 3600
	var m := (total % 3600) / 60
	if h <= 0:
		return "%d min" % m
	return "%d h %d min" % [h, m]


## Marca que hoy se ha jugado (para el logro de días distintos). En el
## tutorial se sale ANTES de tocar `last_day`: si se apuntara la fecha aquí
## (escribe el diccionario directo, sin pasar por bump_stat), la primera
## partida DE VERDAD de ese mismo día ya no sumaría su día jugado.
func mark_day_played() -> void:
	if is_tutorial():
		return
	var today := _today()
	if str(stats.get("last_day", "")) == today:
		return
	stats["last_day"] = today
	bump_stat("days_played")


## Progreso de un logro. Además de las claves de `stats`, entiende sumas
## (Array de claves) y las "derived:*", que se calculan del progreso guardado.
func achievement_value(a: Dictionary) -> int:
	var stat: Variant = a.get("stat", "")
	# "derived:fish:<id>": cuántos ejemplares de esa especie se han pescado. Sale
	# del ÁLBUM y no de un contador nuevo, así que los logros por pez cuentan
	# hacia atrás con lo ya capturado.
	if stat is String and str(stat).begins_with("derived:fish:"):
		return int(fish_album.get(str(stat).substr(13), 0))
	if stat is Array:
		var total := 0
		for s in stat:
			total += get_stat(str(s))
		return total
	var key := str(stat)
	match key:
		"derived:estrellas":
			var st := 0
			for id in level_stars:
				st += int(level_stars[id])
			return st
		"derived:niveles":
			var done := 0
			for port in CampaignData.PORTS:
				var id := str(port.get("id", ""))
				if int(level_stars.get(id, 0)) >= int(port.get("goal_stars", 1)):
					done += 1
			return done
		"derived:recetas":
			return unlocked_recipes.size()
		"derived:coleccion":
			return collectibles.size()
		"derived:pesca_album":
			# Especies DEL CATÁLOGO, no claves del guardado (un id renombrado
			# dejaría una entrada huérfana y el logro contaría de más).
			return FishData.caught_count(fish_album)
	return get_stat(key)


# --- Notificaciones, coleccionables y reclamo de logros ---------------------

## Doblones por medalla reclamada: bronce, plata, oro.
## ORO POR MEDALLA (bronce/plata/oro). BAJO a propósito: con ~160 logros de
## tres metales cada uno, a 25/50/100 el reclamo pagaba más que media campaña y
## el oro dejaba de valer nada. Una jornada normal deja 50-110 doblones: una
## medalla tiene que ser una propina, no un sueldo.
const MEDAL_REWARDS := [8, 15, 30]
## Y ESE PAGO CRECE CON EL NIVEL DEL COCINERO (pedido por el usuario): la base
## de arriba es lo que vale una medalla en el nivel 1, y cada nivel le suma
## MEDAL_LEVEL_STEP.
##
## PERO CUENTA EL NIVEL AL QUE SE GANÓ LA MEDALLA, no el de cuando se cobra
## (`medal_levels`, apuntado en `_run_achievement_check`). Esa es la pieza que
## sostiene todo lo demás: guardarse las medallas sin reclamar no renta nada,
## porque el precio se congela el día que se consiguen. Y como el farmeo deja
## de existir, el multiplicador puede ser GENEROSO de verdad — 4% por nivel y
## tope ×10 — en vez del 2% tímido que hacía falta cuando se podían acumular.
const MEDAL_LEVEL_STEP := 0.04
const MEDAL_LEVEL_MAX := 10.0


## Multiplicador de recompensa al nivel de cocinero que se le pase.
func medal_level_mult(nivel: int) -> float:
	return minf(1.0 + float(maxi(nivel - 1, 0)) * MEDAL_LEVEL_STEP,
		MEDAL_LEVEL_MAX)


## Nivel al que se ganó esa medalla. Las de un guardado ANTERIOR a este apunte
## no lo tienen: esas cobran al nivel de hoy, que es lo más justo con quien ya
## las tenía conseguidas (lo contrario sería pagárselas al nivel 1).
func medal_level_of(id: String, tier: int) -> int:
	var arr: Array = medal_levels.get(id, [])
	var i := tier - 1
	if i >= 0 and i < arr.size() and int(arr[i]) > 0:
		return int(arr[i])
	return chef_level


## Apunta el nivel al que se acaba de ganar una medalla. Solo la primera vez:
## una medalla no se gana dos veces.
func note_medal_level(id: String, tier: int) -> void:
	var arr: Array = medal_levels.get(id, [0, 0, 0])
	while arr.size() < 3:
		arr.append(0)
	var i := tier - 1
	if i >= 0 and i < 3 and int(arr[i]) <= 0:
		arr[i] = chef_level
	medal_levels[id] = arr


## Lo que paga una medalla de ese metal (1 bronce, 2 plata, 3 oro), al nivel
## que la ganó. Lo usan los dos cobros, para que nadie repita la cuenta.
func medal_reward(id: String, tier: int) -> int:
	var base: int = int(MEDAL_REWARDS[clampi(tier - 1, 0, MEDAL_REWARDS.size() - 1)])
	var mult := medal_level_mult(medal_level_of(id, tier))
	return maxi(int(round(base * mult)), base)
## El coleccionable "cartel de recompensa" cae al llegar a este botín de vida.
const CARTEL_BOUNTY := 1000000
## Vueltas al timón del menú que piden el coleccionable "timón".
const HELM_TURNS_GOAL := 5

## La capa de avisos (toasts de logro y ventanas de coleccionable) cuelga del
## autoload, como el velo de los fundidos: sobrevive a los cambios de escena.
var _notices: NoticeLayer = null
var _ach_check_queued := false


func _ensure_notices() -> NoticeLayer:
	if _notices == null or not is_instance_valid(_notices):
		_notices = NoticeLayer.new()
		add_child(_notices)
	return _notices


## ¿Hay algún aviso (toast o ventana de coleccionable) en pantalla o en cola?
## Lo pregunta quien tiene que hablar DESPUÉS de un cartel, para no pisarlo.
func notices_busy() -> bool:
	return _notices != null and is_instance_valid(_notices) and _notices.is_busy()


func has_collectible(id: String) -> bool:
	return id in collectibles


## Desbloquea un coleccionable, lo ANUNCIA con su ventana y guarda. Devuelve
## true si era nuevo. `extra` añade un renglón al anuncio (el regalo del
## triángulo dorado).
func unlock_collectible(id: String, extra := "") -> bool:
	if id in collectibles or CollectibleData.get_item(id).is_empty():
		return false
	collectibles.append(id)
	# LOS QUE TIENEN ESCENA solo apuntan aquí la deuda: la ventana del
	# coleccionable la saca NoticeLayer en su capa global, sin sitio para un
	# retrato, así que la escena la cobra `main_menu` al cerrar la pesca.
	if id in CollectibleData.SCENE_ITEMS:
		pending_col_scenes.append(id)
	save_game()
	_ensure_notices().announce_collectible(id, extra)
	# El logro de coleccionista bebe de aquí ("derived:coleccion").
	queue_achievement_check()
	return true


## Un fragmento del TRIÁNGULO DORADO. Los 8 se juntan en UN coleccionable y
## regalan CollectibleData.TRIFORCE_REWARD doblones.
func add_triforce_piece(n := 1) -> void:
	if has_collectible("trifuerza"):
		return
	triforce_pieces = mini(triforce_pieces + n, CollectibleData.TRIFORCE_PIECES)
	if triforce_pieces >= CollectibleData.TRIFORCE_PIECES:
		money += CollectibleData.TRIFORCE_REWARD
		unlock_collectible("trifuerza", "¡Los %d fragmentos se unen! +%d doblones"
			% [CollectibleData.TRIFORCE_PIECES, CollectibleData.TRIFORCE_REWARD])
	else:
		save_game()


# --- Minijuego de PESCA -----------------------------------------------------
# El catálogo y la economía viven en `fish_data.gd`; aquí está lo que toca
# ESTADO. El sorteo (`fishing_roll`) ocurre ANTES de que aparezca la sombra
# —el juego ya sabe qué va a caer y de ahí sale la dificultad de la pelea— y
# NO muta nada; `fishing_apply` entrega el premio SOLO si la captura se logra.

## Cobra el intento de pesca. false (sin tocar nada) si no llega el dinero.
## CEBO: cada uno paga un lanzamiento entero. Se gasta ANTES que el monedero.
## Tiene DOS fuentes: los tres que regala Cai al terminar su clase y los que
## caen al SUBIR DE NIVEL de cocinero (ver `SkillData.level_reward`). Es una
## sola cuenta a propósito — antes eran las "tiradas gratis" de Cai sin más, y
## un segundo contador que hiciera exactamente lo mismo con otro nombre solo
## habría confundido al jugador (los guardados viejos migran su `free_casts`).
var bait := 0
## MAPAS DEL TESORO (las misiones secundarias). Los reparte el bonus diario
## (días 4, 6 y 7), pero el sistema que los gasta AÚN NO EXISTE: aquí se
## acumulan para que, el día que entre, el jugador tenga lo que ya cobró.
var treasure_maps := 0


func fishing_pay() -> bool:
	if bait > 0:
		bait -= 1
		save_game()
		return true
	if money < FishData.FISHING_COST:
		return false
	money -= FishData.FISHING_COST
	bump_stat("money_spent", FishData.FISHING_COST)
	save_game()
	return true


## Sortea el premio del intento SIN tocar estado. Devuelve
## {"type": "fish", "fish_id", "tier"} o {"type": "chest", "premio", "tier"},
## con `tier` 0..3 (la dificultad de la pelea: mejor premio, pelea más dura).
func fishing_roll() -> Dictionary:
	if randf() >= FishData.CHEST_CHANCE:
		var fid := FishData.roll_fish()
		var out := { "type": "fish", "fish_id": fid,
			"tier": FishData.tier_of(fid), "size": randf() }
		# El PEZ LAPA puede venir pegado: se decide (y se dimensiona) ya.
		if randf() < FishData.LAPA_CHANCE:
			out["lapa_size"] = randf()
		return out
	var premio := {}
	match FishData.roll_chest_kind():
		"coins":
			var n := FishData.roll_chest_coins()
			premio = { "kind": "coins", "coins": n,
				"tier": 0 if n <= FishData.CHEST_COINS_LOW.y else 1 }
		"collectible":
			# Se sortea ENTRE TODOS los pescables, tengas o no: el repetido
			# paga DUP_COINS (pre-filtrar los conseguidos dejaría esa regla
			# del diseño sin usar) y pelea flojo, que no vale nada nuevo.
			var cid := str(FishData.FISHING_COLLECTIBLES[
				randi() % FishData.FISHING_COLLECTIBLES.size()])
			if has_collectible(cid):
				premio = { "kind": "dup", "collectible": cid,
					"coins": FishData.DUP_COINS, "tier": 0 }
			else:
				premio = { "kind": "collectible", "collectible": cid, "tier": 2 }
		"triforce":
			if has_collectible("trifuerza"):
				premio = { "kind": "dup_triforce",
					"coins": FishData.DUP_COINS, "tier": 0 }
			else:
				premio = { "kind": "triforce", "tier": 2 }
		"recipe":
			# Una receta BLOQUEADA al azar. Ni ocultas (salen de sus mecánicas)
			# ni dragon_roll (exclusiva del día 7 del bonus diario). Sin
			# ninguna pendiente, paga RECIPE_FALLBACK como la casilla del 7.
			var locked: Array = []
			for rid in RecipeData.RECIPES:
				if RecipeData.RECIPES[rid].get("hidden", false):
					continue
				if str(rid) == "dragon_roll":
					continue
				if not is_recipe_unlocked(str(rid)):
					locked.append(str(rid))
			if locked.is_empty():
				premio = { "kind": "coins",
					"coins": FishData.RECIPE_FALLBACK, "tier": 1 }
			else:
				premio = { "kind": "recipe",
					"recipe": str(locked[randi() % locked.size()]), "tier": 3 }
	return { "type": "chest", "premio": premio, "tier": int(premio["tier"]) }


## Entrega el premio de un `fishing_roll` LOGRADO (mutaciones y guardado).
## Devuelve el diccionario para el cartel del botín.
func fishing_apply(roll: Dictionary) -> Dictionary:
	if str(roll.get("type", "")) == "fish":
		var fid := str(roll["fish_id"])
		var size := clampf(float(roll.get("size", 0.5)), 0.0, 1.0)
		var veces := int(fish_album.get(fid, 0)) + 1
		fish_album[fid] = veces
		fish_best[fid] = maxf(float(fish_best.get(fid, 0.0)), size)
		bump_stat("fish_caught")
		# Las estadísticas de los LOGROS de pesca se suben desde aquí, que es
		# donde ocurre el suceso (el criterio de todo el juego).
		if str(FishData.get_fish(fid).get("rarity", "")) == "legendario":
			bump_stat("fish_legendary")
		if FishData.get_fish(fid).get("junk", false):
			bump_stat("fish_junk")
		var out := { "type": "fish", "fish_id": fid, "veces": veces,
			"size": size }
		# EXPERIENCIA DE COCINERO por la captura, mandando el TAMAÑO. Es la
		# tercera fuente de XP del juego, junto a los escenarios y el arcade, y
		# la única que no depende de cocinar. Un pez REPETIDO paga la MITAD: lo
		# que se premia es descubrir catálogo, no dragar la misma especie.
		var gana := SkillData.fishing_xp(FishData.tier_of(fid), size, chef_level)
		if veces > 1:
			gana = maxi(1, gana / 2)
		if gana > 0:
			add_chef_xp(gana)
			out["xp"] = gana
		# Los peces-ingrediente dan sus usos EN CADA captura (la pesca es la
		# fuente de despensa; el salmón real da el doble)...
		var ing := str(FishData.get_fish(fid).get("ingredient", ""))
		if ing != "":
			add_ingredient_uses(ing, FishData.uses_of(fid))
			out["ingredient"] = ing
			out["uses"] = FishData.uses_of(fid)
		# ...y TODOS pagan las monedas de su rareza POR TAMAÑO desde la 2ª
		# captura de la especie (la 1ª de un pez sin ingrediente es solo el
		# álbum).
		if veces >= FishData.REPEAT_COINS_FROM:
			var coins := FishData.coins_for(fid, size)
			money += coins
			out["coins"] = coins
		# El PEZ LAPA pegado: entra al álbum con su tamaño y SU valor se
		# cobra SIEMPRE (es el extra que regala la captura).
		if roll.has("lapa_size"):
			var ls := clampf(float(roll["lapa_size"]), 0.0, 1.0)
			fish_album["pez_lapa"] = int(fish_album.get("pez_lapa", 0)) + 1
			fish_best["pez_lapa"] = maxf(float(fish_best.get("pez_lapa", 0.0)), ls)
			bump_stat("fish_caught")
			bump_stat("fish_lapa")
			var lapa_coins := FishData.coins_for("pez_lapa", ls)
			money += lapa_coins
			out["lapa_coins"] = lapa_coins
			out["lapa_size"] = ls
		save_game()
		return out
	bump_stat("chests_fished")
	var premio: Dictionary = roll["premio"]
	var out_c := premio.duplicate()
	out_c["type"] = "chest"
	match str(premio["kind"]):
		"coins", "dup", "dup_triforce":
			money += int(premio["coins"])
			save_game()
		"collectible":
			# Anuncia con la ventana modal y guarda él solo. Si entre el
			# sorteo y la captura cayó por otro lado (imposible hoy), paga
			# como repetido para no quedarse en nada.
			if not unlock_collectible(str(premio["collectible"])):
				out_c["kind"] = "dup"
				out_c["coins"] = FishData.DUP_COINS
				money += FishData.DUP_COINS
				save_game()
		"triforce":
			# Guarda (y al octavo anuncia la trifuerza completa).
			add_triforce_piece()
			out_c["pieces"] = triforce_pieces
		"recipe":
			unlock_recipe(str(premio["recipe"]))
			# El mismo regalo de estreno que una receta de nivel (PORT_GIFT).
			gift_ingredients_for([str(premio["recipe"])], PORT_GIFT)
			save_game()
	return out_c


## Programa una pasada de detección para el final del fotograma. Se llama tras
## cada bump/max de estadística: así una ráfaga de platos cobrados en el mismo
## fotograma solo cuesta UNA revisión del catálogo.
func queue_achievement_check() -> void:
	if _ach_check_queued:
		return
	_ach_check_queued = true
	call_deferred("_run_achievement_check")


func _run_achievement_check() -> void:
	_ach_check_queued = false
	# Coleccionables que dependen de una ESTADÍSTICA.
	if get_stat("helm_turns") >= HELM_TURNS_GOAL:
		unlock_collectible("timon")
	if get_stat("fed_sombrero") >= 20:
		unlock_collectible("sombrero_paja")
	if bounty() >= CARTEL_BOUNTY:
		unlock_collectible("cartel_recompensa")
	# TROFEOS: los dos que se ganan cocinando, no pescando ni de regalo.
	if get_stat("slices_ok") >= CollectibleData.CUCHILLO_CORTES:
		unlock_collectible("cuchillo_maestro")
	if arcade_best >= CollectibleData.GALON_OLEADA:
		unlock_collectible("galon_oro")
	if get_stat("plates_wasted") >= CollectibleData.DELANTAL_TIRADOS:
		unlock_collectible("delantal_chamuscado")
	if get_stat("best_tips_run") >= CollectibleData.CAMPANA_PROPINA:
		unlock_collectible("campana_servicio")
	# (El diente del Kappa ya NO cae por aquí: lo entrega ÉL en su escena del
	# mapa. La vía general de los jefes, abajo, lleva el mismo filtro.)
	if get_stat("slices_ok") >= CollectibleData.PIEDRA_CORTES:
		unlock_collectible("piedra_afilar")
	# El PLATO QUEMADO es el recuerdo del PRIMERO que se fue al cubo.
	if get_stat("plates_wasted") > 0:
		unlock_collectible("plato_quemado")
	if get_stat("dish_dorayaki") >= CollectibleData.DORAYAKI_PLATOS:
		unlock_collectible("dorayaki_mordisco")
	if get_stat("fish_caught") >= CollectibleData.ANZUELO_PECES:
		unlock_collectible("anzuelo_maui")
	# La ESMERALDA la trae la rana caotica: cuelga del ALBUM, asi que cae
	# tambien si ya se habia pescado antes de que existiera la pieza.
	if fish_album.has(CollectibleData.ESMERALDA_PEZ):
		unlock_collectible("esmeralda_caos")
	# EL RECETARIO COMPLETO: todas las recetas VISIBLES aprendidas (las
	# ocultas —barco, combinados, tempuras fallidas— no se aprenden nunca).
	var todas := true
	for rid in RecipeData.RECIPES:
		if RecipeData.RECIPES[rid].get("hidden", false):
			continue
		if not rid in unlocked_recipes:
			todas = false
			break
	if todas:
		unlock_collectible("recetario")
	# UN TROFEO POR JEFE DE MAR: cada uno cuelga de su propia stat, que sube
	# `level3d` al rendirlo. Los jefes que aun no existen no molestan.
	for boss_id in CollectibleData.BOSS_ITEMS:
		# EL DIENTE DEL KAPPA NO CAE POR AQUÍ: lo entrega ÉL, medio dormido, en
		# su escena del mapa (`main_menu._presentar_kappa`). Hasta que esa
		# escena corre, la vía de la stat se aguanta las ganas.
		if boss_id == "kappa" and not kappa_outro_done:
			continue
		if get_stat("boss_%s" % boss_id) > 0:
			unlock_collectible(str(CollectibleData.BOSS_ITEMS[boss_id]))
	# LOS PALILLOS suben de material con los platos servidos. Se comprueban los
	# tres escalones, no solo el siguiente: quien llegue de golpe (un guardado
	# viejo con miles de platos) se los lleva todos, de uno en uno y con su
	# ventana, que es como se ganan.
	var platos := get_stat("dishes_made")
	for i in CollectibleData.PALILLOS_IDS.size():
		if platos >= int(CollectibleData.PALILLOS_PLATOS[i]):
			unlock_collectible(str(CollectibleData.PALILLOS_IDS[i]))
	# Medallas nuevas desde la última pasada: un toast por medalla. NO se
	# guarda aquí a propósito (`seen_medals` viaja con el siguiente save
	# natural): guardar a disco en mitad de una partida daría un tirón.
	for a in AchievementData.all():
		var id := str(a["id"])
		var earned := AchievementData.medal_for(a, achievement_value(a))
		var seen := int(seen_medals.get(id, 0))
		if earned <= seen:
			continue
		seen_medals[id] = earned
		for tier in range(seen + 1, earned + 1):
			# EL NIVEL AL QUE SE GANA, congelado aquí mismo: es lo que decidirá
			# su pago cuando se reclame, hoy o dentro de cien niveles.
			note_medal_level(id, tier)
			# EL ICONO DEL LOGRO, no la moneda de siempre: así el aviso se lee de
			# un vistazo sin tener que leer el nombre.
			_ensure_notices().toast_achievement(AchievementData.icon_for(a),
				AchievementData.MEDAL_COLORS[tier - 1],
				"¡Logro: medalla de %s!" % AchievementData.MEDAL_NAMES[tier - 1].to_lower(),
				str(a["name"]))


## Medallas conseguidas y aún sin reclamar DE UN LOGRO. Es el número del globo
## rojo de su tarjeta.
func unclaimed_for(a: Dictionary) -> int:
	var earned := AchievementData.medal_for(a, achievement_value(a))
	return maxi(earned - int(claimed_medals.get(str(a["id"]), 0)), 0)


## Lo mismo para un APARTADO entero: el globo de su pestaña.
func unclaimed_in_group(group: String) -> int:
	var n := 0
	for a in AchievementData.all():
		if str(a.get("group", "")) == group:
			n += unclaimed_for(a)
	return n


## Medallas conseguidas y aún sin reclamar: el número del globo rojo del menú.
func unclaimed_medals() -> int:
	var n := 0
	for a in AchievementData.all():
		n += unclaimed_for(a)
	return n


## Cobra las medallas pendientes DE UN SOLO LOGRO (el jugador ha tocado su
## tarjeta). Mismo reparto que el cobro en bloque —`medal_reward` por metal,
## ya escalado por el nivel— y si de ese logro hay bronce y plata pendientes
## caen los dos.
func claim_achievement(id: String) -> int:
	var a := AchievementData.get_achievement(id)
	if a.is_empty():
		return 0
	var earned := AchievementData.medal_for(a, achievement_value(a))
	var claimed := int(claimed_medals.get(id, 0))
	if earned <= claimed:
		return 0
	var total := 0
	for tier in range(claimed + 1, earned + 1):
		total += medal_reward(id, tier)
	claimed_medals[id] = earned
	# Reclamado implica visto: que el toast no anuncie lo ya cobrado.
	seen_medals[id] = maxi(int(seen_medals.get(id, 0)), earned)
	money += total
	save_game()
	return total


## Cobra TODAS las medallas pendientes (MEDAL_REWARDS por metal). Si de un
## mismo logro hay bronce y plata sin reclamar, caen las dos de golpe.
## Devuelve { total, bronce, plata, oro }; total 0 si no había nada.
func claim_achievement_rewards() -> Dictionary:
	var out := { "total": 0, "bronce": 0, "plata": 0, "oro": 0 }
	for a in AchievementData.all():
		var id := str(a["id"])
		var earned := AchievementData.medal_for(a, achievement_value(a))
		var claimed := int(claimed_medals.get(id, 0))
		if earned <= claimed:
			continue
		for tier in range(claimed + 1, earned + 1):
			out["total"] = int(out["total"]) + medal_reward(id, tier)
			var metal := str(AchievementData.MEDALS[tier - 1])
			out[metal] = int(out[metal]) + 1
		claimed_medals[id] = earned
		# Reclamado implica visto: que el toast no anuncie lo ya cobrado.
		seen_medals[id] = maxi(int(seen_medals.get(id, 0)), earned)
	if int(out["total"]) > 0:
		money += int(out["total"])
		save_game()
	return out


## Recuento de medallas de todo el catálogo, para la cabecera de la pantalla.
func medal_counts() -> Dictionary:
	var out := { "bronce": 0, "plata": 0, "oro": 0, "total": 0 }
	for a in AchievementData.all():
		out["total"] = int(out["total"]) + 1
		var m := AchievementData.medal_for(a, achievement_value(a))
		if m >= 1:
			out["bronce"] = int(out["bronce"]) + 1
		if m >= 2:
			out["plata"] = int(out["plata"]) + 1
		if m >= 3:
			out["oro"] = int(out["oro"]) + 1
	return out


# --- Ajustes ---------------------------------------------------------------

func get_setting(key: String) -> Variant:
	return settings.get(key, DEFAULT_SETTINGS.get(key))


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_graphics()
	save_game()


## Aplica un bloque de gráficos entero (alta / media / baja). "custom" no toca
## nada: son los cuatro ajustes que ya haya puestos a mano.
func apply_preset(name: String) -> void:
	settings["preset"] = name
	var p: Dictionary = GRAPHICS_PRESETS.get(name, {})
	for k in p:
		settings[k] = p[k]
	apply_graphics()


## ¿A qué bloque corresponden los ajustes actuales? Si no encajan en ninguno,
## "custom": así el cartel nunca miente sobre lo que hay puesto.
func current_preset() -> String:
	for name in GRAPHICS_PRESETS:
		var p: Dictionary = GRAPHICS_PRESETS[name]
		var same := true
		for k in p:
			if get_setting(k) != p[k]:
				same = false
				break
		if same:
			return str(name)
	return "custom"


## El renglón del cartel de recompensa: "el zurdo", "la diestra"...
func player_subtitle() -> String:
	return TitleData.text(player_title_id, player_gender, player_hand)


## LA RECOMPENSA del cartel: todo el oro que ha ganado el jugador en toda su
## vida, en aventura Y en arcade (los logros son del jugador, no de la campaña,
## y esto igual). Se suma en `level3d._finalize_results`, con la jornada
## cerrada, así que no la mueven ni las compras ni los castigos.
##
## Los guardados anteriores a la estadística la SIEMBRAN con lo que tienen en
## el monedero más lo que ya se han gastado (ver `_seed_bounty`): no es exacto,
## pero un jugador con treinta horas encima merece algo mejor que un cartel a 0.
func bounty() -> int:
	return int(stats.get("money_total", 0))


## Nombre con el que el juego se dirige al jugador.
func player_title() -> String:
	var n := player_name.strip_edges()
	if n != "":
		return n
	return str(CharacterData.GENDER_TITLES.get(player_gender, "Chef"))


## ¿Se dibujan las manchas de sombra y las animaciones de adorno?
func shadows_on() -> bool:
	return bool(get_setting("shadows"))


func animations_on() -> bool:
	return bool(get_setting("anim"))


## Tope de fotogramas de la pantalla en curso: los menús se conforman con la
## mitad, jugando manda el ajuste del usuario.
func fps_for(playing: bool) -> int:
	var fps := int(get_setting("fps"))
	return fps if playing else mini(fps, 30)


## Aplica lo que es global: escala de renderizado 3D y tope de fotogramas.
## Lo demás (sombras y animaciones) lo consulta cada escena al construirse.
func apply_graphics() -> void:
	Engine.max_fps = fps_for(false)
	# Los volúmenes viajan con el resto de ajustes: `set_setting` llama aquí,
	# así que mover una barra en Opciones se oye en el acto.
	# (al arrancar, GameState monta antes que Audio: entonces no hay nada
	# que refrescar y ya lo hace Audio en su propio `_ready`.)
	if has_node("/root/Audio"):
		get_node("/root/Audio").aplicar_volumenes()
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var q: int = clampi(int(get_setting("quality")), 0, QUALITY_SCALE.size() - 1)
	tree.root.scaling_3d_scale = float(QUALITY_SCALE[q])


# --- Guardado / carga ------------------------------------------------------

## Arroz de una partida nueva Y TOPE del saco: no se acumula más de esto.
const RICE_START := 20
## Cada cuánto (en segundos de tiempo REAL) cae un saco de arroz: 1 h 30 min.
## Se guarda la MARCA DE TIEMPO del próximo saco, no un contador, para que
## siga corriendo con el juego cerrado.
const RICE_PERIOD := 5400
## LINGOTES DE ORO: la moneda que se comprará con dinero real. Con ellos se
## compran sacos de arroz.
const INGOTS_START := 5


func save_game() -> void:
	var data := {
		"version": 6,
		"stats": stats,
		"settings": settings,
		"play_seconds": play_seconds,
		"money": money,
		"rice": rice,
		"rice_next_ts": rice_next_ts,
		"ingots": ingots,
		"unlocked_recipes": unlocked_recipes,
		"unlocked_powerups": unlocked_powerups,
		"level_stars": level_stars,
		"level_scores": level_scores,
		"ingredients": ingredients,
		"unlocked_perks": unlocked_perks,
		"unlocked_upgrades": unlocked_upgrades,
		"pending_mejora_intro": pending_mejora_intro,
		"perk_uses": perk_uses,
		"perk_level": perk_level,
		"shop_stock": shop_stock,
		"shop_day": shop_day,
		"daily_day": daily_day,
		"daily_last": daily_last,
		"chef_xp": chef_xp,
		"chef_level": chef_level,
		"xp_seeded": xp_seeded,
		# PUNTOS invertidos, no rangos: clave NUEVA a propósito, porque un 3 en
		# el formato viejo era el rango 3 (15 puntos) y aquí son 3 puntos.
		"skill_points": skills,
		"arcade_best": arcade_best,
		"collectibles": collectibles,
		"triforce_pieces": triforce_pieces,
		"pending_col_scenes": pending_col_scenes,
		"fish_album": fish_album,
		"fish_best": fish_best,
		"claimed_medals": claimed_medals,
		"medal_levels": medal_levels,
		"seen_medals": seen_medals,
		"player_gender": player_gender,
		"player_hand": player_hand,
		"player_name": player_name,
		"player_title": player_title_id,
		"unlocked_titles": unlocked_titles,
		"tutorial_done": tutorial_done,
		"shop_intro_done": shop_intro_done,
		"extras_done": extras_done,
		"level1_outro_done": level1_outro_done,
		"daily_intro_done": daily_intro_done,
		"trash_intro_done": trash_intro_done,
		"ingots_intro_done": ingots_intro_done,
		"pending_ingots": pending_ingots,
		"fishing_intro_done": fishing_intro_done,
		"cai_intro_done": cai_intro_done,
		"cai_saciado": cai_saciado,
		"alice_saciada": alice_saciada,
		"pending_kappa": pending_kappa,
		"kappa_outro_done": kappa_outro_done,
		"mar2_intro_done": mar2_intro_done,
		"sushi_rush_unlocked": sushi_rush_unlocked,
		"alice_intro_done": alice_intro_done,
		"skill_counters_intro_done": skill_counters_intro_done,
		"isla_handicap_done": isla_handicap_done,
		"puerto_handicap_done": puerto_handicap_done,
		"abordaje_handicap_done": abordaje_handicap_done,
		"col_intro_done": col_intro_done,
		"skills_intro_done": skills_intro_done,
		"nivel_intro_done": nivel_intro_done,
		"logros_intro_done": logros_intro_done,
		"inventario_intro_done": inventario_intro_done,
		"bait": bait,
		"treasure_maps": treasure_maps,
		"rice_intro_done": rice_intro_done,
		"pablo_shop_done": pablo_shop_done,
		"menu_intro_done": menu_intro_done,
		"map_intro_done": map_intro_done,
		"narrated_ports": narrated_ports,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_new_game()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		_new_game()
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_new_game()
		return
	money = int(parsed.get("money", 0))
	# Los guardados anteriores al arroz arrancan con el saco lleno.
	rice = int(parsed.get("rice", RICE_START))
	rice_next_ts = int(parsed.get("rice_next_ts", 0))
	ingots = int(parsed.get("ingots", INGOTS_START))
	# Los sacos que hayan caído con el juego CERRADO se cobran al cargar.
	tick_rice()
	unlocked_recipes = _to_string_array(parsed.get("unlocked_recipes", []))
	unlocked_powerups = _to_string_array(parsed.get("unlocked_powerups", []))
	level_stars = {}
	var stars_dict: Dictionary = parsed.get("level_stars", {})
	for k in stars_dict.keys():
		level_stars[str(k)] = int(stars_dict[k])
	level_scores = {}
	var scores_dict: Dictionary = parsed.get("level_scores", {})
	for k in scores_dict.keys():
		level_scores[str(k)] = int(scores_dict[k])
	ingredients = {}
	var ing_dict: Dictionary = parsed.get("ingredients", {})
	for k in ing_dict.keys():
		ingredients[str(k)] = int(ing_dict[k])
	unlocked_perks = _to_string_array(parsed.get("unlocked_perks", []))
	unlocked_upgrades = _to_string_array(parsed.get("unlocked_upgrades", []))
	pending_mejora_intro = bool(parsed.get("pending_mejora_intro", false))
	perk_uses = {}
	var perk_dict: Dictionary = parsed.get("perk_uses", {})
	for k in perk_dict.keys():
		perk_uses[str(k)] = int(perk_dict[k])
	# Guardados de antes de las MEJORAS: todo lo desbloqueado arranca en el
	# nivel 1, que es donde estaba de hecho.
	perk_level = {}
	var nivel_dict: Dictionary = parsed.get("perk_level", {})
	for k in nivel_dict.keys():
		perk_level[str(k)] = int(nivel_dict[k])
	for pid in unlocked_perks:
		if not perk_level.has(pid):
			perk_level[pid] = 1
	shop_stock = _to_string_array(parsed.get("shop_stock", []))
	shop_day = str(parsed.get("shop_day", ""))
	daily_day = int(parsed.get("daily_day", 0))
	daily_last = str(parsed.get("daily_last", ""))
	player_gender = str(parsed.get("player_gender", CharacterData.MALE))
	# El género NEUTRO se retiró con el cartel de recompensa: quien lo tuviera
	# elegido pasa a masculino, que es al que ya caía `CharacterData.model`.
	if not CharacterData.PLAYER_GENDERS.has(player_gender):
		player_gender = CharacterData.MALE
	player_name = str(parsed.get("player_name", ""))
	player_hand = str(parsed.get("player_hand", "L"))
	player_title_id = str(parsed.get("player_title", TitleData.MANO))
	if not TitleData.exists(player_title_id):
		player_title_id = TitleData.MANO
	unlocked_titles = _to_string_array(parsed.get("unlocked_titles",
		[TitleData.MANO]))
	if unlocked_titles.is_empty():
		unlocked_titles = [TitleData.MANO]
	# Las estadísticas viajan como números sueltos; "last_day" es texto.
	stats = {}
	var stat_dict: Dictionary = parsed.get("stats", {})
	for k in stat_dict.keys():
		var v: Variant = stat_dict[k]
		stats[str(k)] = str(v) if str(k) == "last_day" else int(v)
	# LA RECOMPENSA del cartel es nueva: los guardados que no la traen la
	# siembran con el monedero más lo ya gastado, que es lo más parecido a "todo
	# lo que ha ganado" que se puede reconstruir hacia atrás.
	if not stats.has("money_total"):
		stats["money_total"] = money + int(stats.get("money_spent", 0))
	# MAESTRÍAS: el nivel se DERIVA de la experiencia (el guardado lo trae solo
	# por legibilidad), así que un save editado a mano no puede descuadrarlos.
	chef_xp = maxi(int(parsed.get("chef_xp", 0)), 0)
	# GUARDADOS ANTERIORES A LAS MAESTRÍAS: se siembra la experiencia con el
	# ESTRENO de cada escenario ya superado (mismo criterio retroactivo que
	# `money_total` y los logros). Sin esto, quien llegara con media campaña
	# hecha arrancaría al nivel 1 sin poder recuperar nunca esos estrenos —
	# el récord ya está puesto y las repeticiones pagan la tarifa corta.
	#
	# LA COMPUERTA ES UNA BANDERA PROPIA (`xp_seeded`), NO la ausencia de
	# `chef_xp`: la primera versión miraba si faltaba la clave, y en cuanto el
	# juego guardaba una vez (con un 0 dentro) la siembra ya no podía
	# dispararse nunca. Pasó de verdad — una partida con nueve escenarios
	# superados se quedó sin sus 2.430 de estreno.
	xp_seeded = bool(parsed.get("xp_seeded", false))
	if not xp_seeded:
		var semilla := 0
		for pid in level_stars:
			semilla += scenario_xp(str(pid), int(level_stars[pid]), 0)
		xp_seeded = true
		if semilla > 0:
			# Se CELEBRA: la primera visita al menú ve la barra llenarse.
			xp_anim_from = chef_xp
			chef_xp += semilla
	chef_level = SkillData.level_for_xp(chef_xp)
	skills = {}
	if parsed.has("skill_points"):
		var pts_dict: Dictionary = parsed["skill_points"]
		for k in pts_dict.keys():
			if SkillData.get_skill(str(k)).is_empty():
				continue
			var p := clampi(int(pts_dict[k]), 0, SkillData.max_points(str(k)))
			if p > 0:
				skills[str(k)] = p
	else:
		# GUARDADOS DEL PRIMER DÍA DE LAS MAESTRÍAS: guardaban el RANGO (1..5)
		# porque el rango se compraba entero. Se convierten a puntos para no
		# perder lo invertido.
		var skill_dict: Dictionary = parsed.get("skills", {})
		for k in skill_dict.keys():
			if SkillData.get_skill(str(k)).is_empty():
				continue
			var r := clampi(int(skill_dict[k]), 0, SkillData.MAX_RANK)
			if r > 0:
				skills[str(k)] = r * SkillData.rank_cost(str(k))
	arcade_best = maxi(int(parsed.get("arcade_best", 0)), 0)
	collectibles = _to_string_array(parsed.get("collectibles", []))
	triforce_pieces = int(parsed.get("triforce_pieces", 0))
	pending_col_scenes = _to_string_array(parsed.get("pending_col_scenes", []))
	# Guardado de cuando la escena del corazón era una bandera suelta.
	var corazon_viejo := bool(parsed.get("pending_corazon", false))
	if corazon_viejo and not "corazon_cofre" in pending_col_scenes:
		pending_col_scenes.append("corazon_cofre")
	fish_album = {}
	var fish_dict: Dictionary = parsed.get("fish_album", {})
	for k in fish_dict.keys():
		fish_album[str(k)] = int(fish_dict[k])
	fish_best = {}
	var best_dict: Dictionary = parsed.get("fish_best", {})
	for k in best_dict.keys():
		fish_best[str(k)] = float(best_dict[k])
	claimed_medals = {}
	var claimed_dict: Dictionary = parsed.get("claimed_medals", {})
	for k in claimed_dict.keys():
		claimed_medals[str(k)] = int(claimed_dict[k])
	seen_medals = {}
	var seen_dict: Dictionary = parsed.get("seen_medals", {})
	for k in seen_dict.keys():
		seen_medals[str(k)] = int(seen_dict[k])
	medal_levels = {}
	var niv_dict: Dictionary = parsed.get("medal_levels", {})
	for k in niv_dict.keys():
		var fila: Array = []
		for v in niv_dict[k]:
			fila.append(int(v))
		medal_levels[str(k)] = fila
	# Guardado de ANTES de las notificaciones: lo ya conseguido se da por VISTO
	# (nada de un aluvión de toasts retroactivos al arrancar), pero NO por
	# reclamado — esas recompensas quedan pendientes en el botón "Reclamar".
	if not parsed.has("seen_medals"):
		for a in AchievementData.all():
			seen_medals[str(a["id"])] = AchievementData.medal_for(a,
				achievement_value(a))
	play_seconds = float(parsed.get("play_seconds", 0.0))
	settings = DEFAULT_SETTINGS.duplicate()
	var set_dict: Dictionary = parsed.get("settings", {})
	for k in set_dict.keys():
		if DEFAULT_SETTINGS.has(str(k)):
			settings[str(k)] = set_dict[k]
	# Guardados de la primera versión de Opciones: el nombre y el género vivían
	# dentro de `settings`. Se rescatan para no perder el perfil del jugador.
	if str(set_dict.get("name", "")) != "" and player_name == "":
		player_name = str(set_dict["name"])
	if set_dict.has("gender") and not parsed.has("player_gender"):
		player_gender = str(set_dict["gender"])
	# Los guardados viejos traen los enteros como float al pasar por JSON.
	for k in ["quality", "fps"]:
		settings[k] = int(settings[k])
	tutorial_done = bool(parsed.get("tutorial_done", false))
	shop_intro_done = bool(parsed.get("shop_intro_done", false))
	# Guardados de cuando los EXTRAS los abría la tienda: quien ya la tenía
	# abierta se queda con ellos (quitárselos sería una regresión).
	extras_done = bool(parsed.get("extras_done", shop_intro_done))
	level1_outro_done = bool(parsed.get("level1_outro_done", tutorial_done))
	daily_intro_done = bool(parsed.get("daily_intro_done", tutorial_done))
	trash_intro_done = bool(parsed.get("trash_intro_done", tutorial_done))
	ingots_intro_done = bool(parsed.get("ingots_intro_done", tutorial_done))
	pending_ingots = int(parsed.get("pending_ingots", 0))
	fishing_intro_done = bool(parsed.get("fishing_intro_done", tutorial_done))
	cai_intro_done = bool(parsed.get("cai_intro_done", tutorial_done))
	cai_saciado = bool(parsed.get("cai_saciado", tutorial_done))
	alice_saciada = bool(parsed.get("alice_saciada", false))
	pending_kappa = bool(parsed.get("pending_kappa", false))
	# Un guardado de ANTES de la escena que ya tenga el diente la da por hecha:
	# su Kappa se rindió cuando el trofeo caía solo al cerrar el nivel.
	kappa_outro_done = bool(parsed.get("kappa_outro_done",
		"diente_kappa" in collectibles))
	mar2_intro_done = bool(parsed.get("mar2_intro_done", false))
	sushi_rush_unlocked = bool(parsed.get("sushi_rush_unlocked", false))
	alice_intro_done = bool(parsed.get("alice_intro_done", false))
	skill_counters_intro_done = bool(parsed.get("skill_counters_intro_done", false))
	isla_handicap_done = bool(parsed.get("isla_handicap_done", false))
	puerto_handicap_done = bool(parsed.get("puerto_handicap_done", false))
	abordaje_handicap_done = bool(parsed.get("abordaje_handicap_done", false))
	col_intro_done = bool(parsed.get("col_intro_done", tutorial_done))
	skills_intro_done = bool(parsed.get("skills_intro_done", false))
	nivel_intro_done = bool(parsed.get("nivel_intro_done", false))
	logros_intro_done = bool(parsed.get("logros_intro_done", tutorial_done))
	inventario_intro_done = bool(parsed.get("inventario_intro_done", tutorial_done))
	# Las "tiradas gratis" de los guardados viejos son los CEBOS de hoy: el
	# mecanismo era el mismo y solo cambió de nombre al ganarse por nivel.
	bait = int(parsed.get("bait", parsed.get("free_casts", 0)))
	treasure_maps = int(parsed.get("treasure_maps", 0))
	rice_intro_done = bool(parsed.get("rice_intro_done", false))
	pablo_shop_done = bool(parsed.get("pablo_shop_done", false))
	# Guardados de antes de la guía del menú: si el tutorial ya está hecho, la
	# guía sobra (ese jugador ya sabe dónde está la Aventura).
	menu_intro_done = bool(parsed.get("menu_intro_done", tutorial_done))
	map_intro_done = bool(parsed.get("map_intro_done", tutorial_done))
	narrated_ports = parsed.get("narrated_ports", [])
	# Guardado de ANTES del tutorial: si ya tenía recetas es que ya jugó, así
	# que no se le vuelve a plantar la introducción.
	if not parsed.has("tutorial_done") and not unlocked_recipes.is_empty():
		tutorial_done = true
	# Con el tutorial hecho se garantizan sus recetas aunque el save sea parcial.
	if tutorial_done:
		for r in CampaignData.INITIAL_RECIPES:
			unlock_recipe(r)


## Borra el progreso y empieza de cero. Los AJUSTES (gráficos) y el PERFIL
## (nombre y género) NO son progreso y sobreviven: se borra la partida, no la
## configuración de quien la juega.
func reset_progress() -> void:
	var keep := settings.duplicate()
	var keep_name := player_name
	var keep_gender := player_gender
	var keep_hand := player_hand
	var keep_title := player_title_id
	var keep_titles := unlocked_titles.duplicate()
	_new_game()
	settings = keep
	player_name = keep_name
	player_gender = keep_gender
	player_hand = keep_hand
	player_title_id = keep_title
	unlocked_titles = keep_titles
	save_game()


func _new_game() -> void:
	# `money_total` a CERO explicito: es lo que el cartel de recompensa
	# ensena como botin, y dejandolo sin poner el rescate de guardados viejos
	# (money + money_spent) lo sembraba con los 50 doblones de bienvenida.
	stats = { "money_total": 0 }
	settings = DEFAULT_SETTINGS.duplicate()
	play_seconds = 0.0
	player_gender = CharacterData.MALE
	player_name = ""
	# DIESTRA por defecto: es la mano dominante de la mayoria, y en la ficha
	# de tripulacion sale ya marcada para que no haya que elegir nada.
	player_hand = "R"
	player_title_id = TitleData.MANO
	unlocked_titles = [TitleData.MANO]
	# Un pequeño botín de bienvenida para las primeras compras en la tienda.
	money = 50
	rice = RICE_START
	rice_next_ts = 0
	ingots = INGOTS_START
	unlocked_recipes = []
	unlocked_powerups = []
	level_stars = {}
	level_scores = {}
	ingredients = {}
	unlocked_perks = []
	perk_level = {}
	perk_uses = {}
	chef_xp = 0
	chef_level = 1
	# Partida nueva: no hay nada superado que sembrar.
	xp_seeded = true
	skills = {}
	arcade_best = 0
	shop_stock = []
	shop_day = ""
	daily_day = 0
	daily_last = ""
	collectibles = []
	triforce_pieces = 0
	pending_col_scenes = []
	fish_album = {}
	fish_best = {}
	claimed_medals = {}
	seen_medals = {}
	medal_levels = {}
	# SIN recetas de inicio y con el tutorial pendiente: las 4 primeras las
	# entrega David al terminar su clase (complete_tutorial). Olvidar poner
	# tutorial_done a false aquí hacía que borrar la partida NO relanzara la
	# introducción: el true viejo se colaba en el guardado nuevo.
	tutorial_done = false
	shop_intro_done = false
	extras_done = false
	level1_outro_done = false
	daily_intro_done = false
	trash_intro_done = false
	ingots_intro_done = false
	pending_ingots = 0
	fishing_intro_done = false
	cai_intro_done = false
	cai_saciado = false
	alice_saciada = false
	pending_kappa = false
	kappa_outro_done = false
	mar2_intro_done = false
	sushi_rush_unlocked = false
	alice_intro_done = false
	skill_counters_intro_done = false
	isla_handicap_done = false
	puerto_handicap_done = false
	abordaje_handicap_done = false
	col_intro_done = false
	skills_intro_done = false
	nivel_intro_done = false
	logros_intro_done = false
	inventario_intro_done = false
	bait = 0
	treasure_maps = 0
	rice_intro_done = false
	pablo_shop_done = false
	menu_intro_done = false
	map_intro_done = false
	narrated_ports = []
	# Los usos iniciales SOLO en partida nueva (si se diera también al cargar,
	# se rellenarían gratis en cada arranque).
	for ing in CampaignData.INITIAL_INGREDIENTS:
		ingredients[ing] = int(CampaignData.INITIAL_INGREDIENTS[ing])
	save_game()


func _to_string_array(arr: Variant) -> Array[String]:
	var out: Array[String] = []
	if arr is Array:
		for x in arr:
			out.append(str(x))
	return out
