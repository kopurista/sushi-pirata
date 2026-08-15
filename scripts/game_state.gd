extends Node
## Autoload: estado compartido entre pantallas + progreso persistente de la
## campaña (se guarda en disco en user://savegame.json).

const SAVE_PATH := "user://savegame.json"

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
var player_hand: String = "L"


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
## true cuando David ya ha presentado la TIENDA y a Saverio (tras el nivel 2).
## Es lo que además abre los EXTRAS: antes de esa escena no existen.
var shop_intro_done := false
## David ya explicó para qué sirve el ARROZ (al elegir el primer puerto).
var rice_intro_done := false
## Ya se vio la escena de Pablo y Saverio en la tienda (tras su nivel).
var pablo_shop_done := false
## David ya señaló el pergamino de AVENTURA en el menú (la primera visita tras
## el rescate). Persistente: la guía solo se da una vez.
var menu_intro_done := false
## Puertos cuyo GUION ya se ha visto (ver `port_narrated`). Se marca al terminar
## la fase de preparación, así que fallar y repetir NO obliga a volver a pasar
## por las explicaciones.
var narrated_ports: Array = []
## Usos de ingredientes que regala el juego al desbloquear recetas: la tanda
## del tutorial viene más surtida que las de cada nivel.
const TUTORIAL_GIFT := 5
const PORT_GIFT := 3
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
var perk_uses: Dictionary = {}
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
## ÁLBUM DE PESCA: id de pez (FishData) -> veces pescado, y el RÉCORD de
## tamaño por especie (id -> size 0..1, el mayor pescado: es lo que enseña la
## ficha). Solo estado; catálogo y economía en `fish_data.gd`.
var fish_album: Dictionary = {}
var fish_best: Dictionary = {}
## LOGROS: medallas ya RECLAMADAS (id -> 0..3) y ya ANUNCIADAS con su toast
## (id -> 0..3). Lo CONSEGUIDO no se guarda: se deduce siempre de `stats`.
var claimed_medals: Dictionary = {}
var seen_medals: Dictionary = {}
## Contadores de toda la vida del jugador, de los que salen los LOGROS
## (ver achievement_data.gd). Clave -> entero. Los que empiezan por "best_"
## guardan un máximo, el resto se acumulan.
var stats: Dictionary = {}
## Segundos jugados de verdad (solo dentro de un nivel, nunca en los menús).
var play_seconds: float = 0.0
## Ajustes del jugador (gráficos e identidad). `apply_graphics()` los aplica.
var settings: Dictionary = {}

## Ajustes por defecto. `quality` 0 = baja, 1 = media, 2 = alta; `preset` es el
## bloque de gráficos elegido (ver GRAPHICS_PRESETS; "custom" = a medida).
const DEFAULT_SETTINGS := {
	"preset": "alta",
	"shadows": true,
	"anim": true,
	"quality": 2,
	"fps": 60,
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


## La PESCA está ABIERTA DESDE EL INICIO (decidido para poder probarla sin
## trabas). El candado de antes —superar el puerto con `unlocks_fishing`, el
## nivel 4— queda aquí apuntado por si algún día se quiere reponer:
##   for p in CampaignData.PORTS:
##       if p.get("unlocks_fishing", false):
##           return int(level_stars.get(p["id"], 0)) >= int(p.get("goal_stars", 1))
func fishing_unlocked() -> bool:
	return true


## Los EXTRAS (jengibre, wasabi, soja) los presenta Saverio la primera vez que
## David lleva al jugador a la tienda: hasta entonces ni existen.
func extras_unlocked() -> bool:
	return shop_intro_done


## Puerto que abre el modo Arcade al superarlo. Todavía no está en la campaña
## (llega hasta el 9), así que el Arcade sigue cerrado hasta que se añada.
const ARCADE_PORT := "nivel_10"


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
func gift_ingredients_for(recipe_ids: Array, uses: int) -> void:
	for rid in recipe_ids:
		for ing in RecipeData.get_ingredients(rid):
			var data: Dictionary = RecipeData.INGREDIENTS.get(ing, {})
			if int(data.get("cost", 0)) <= 0:
				continue
			add_ingredient_uses(ing, uses)


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
	# NIVELES DE PRÁCTICA (los dos primeros): no gastan NADA — ni usos de
	# despensa ni saco de arroz — tampoco al repetirlos. Son la escuela del
	# juego y David lo dice así ("hoy invita la casa"); el gasto de verdad
	# empieza en el nivel 3, donde él mismo lo explica.
	if is_adventure() and CampaignData.get_port(current_port) \
			.get("free_ingredients", false):
		return true
	if not can_play():
		return false
	var needed := ingredients_for_selection(recipe_ids)
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


## Los EXTRAS (jengibre, wasabi, soja) NO van por partida: cada plato al que
## se le echa uno gasta una unidad. Se descuentan al servirlo a la cinta.
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
## pueda enseñar: { money, rice, ingots, extras, ingredients, recipe }.
## Devuelve {} si hoy ya estaba cobrado.
func claim_daily() -> Dictionary:
	if not daily_available():
		return {}
	var n := daily_next_day()
	var premio := DailyData.day(n)
	daily_day = n
	daily_last = _today()
	var dado := { "day": n }
	var oro := int(premio.get("money", 0))
	if premio.has("recipe"):
		# La receta del día 7 solo se entrega una vez; quien ya la tenga cobra
		# doblones en su lugar para que la última casilla no salga vacía.
		if unlock_recipe(str(premio["recipe"])):
			dado["recipe"] = str(premio["recipe"])
			gift_ingredients_for([str(premio["recipe"])], PORT_GIFT)
		else:
			oro += DailyData.RECIPE_FALLBACK
	if oro > 0:
		money += oro
		dado["money"] = oro
	if premio.has("rice"):
		add_rice(int(premio["rice"]))
		dado["rice"] = int(premio["rice"])
	if premio.has("ingots"):
		ingots += int(premio["ingots"])
		dado["ingots"] = int(premio["ingots"])
	if premio.has("extras"):
		for e in RecipeData.EXTRAS:
			add_ingredient_uses(e, int(premio["extras"]))
		dado["extras"] = int(premio["extras"])
	if premio.has("ingredients"):
		var ings: Dictionary = premio["ingredients"]
		for k in ings:
			add_ingredient_uses(str(k), int(ings[k]))
		dado["ingredients"] = ings
	save_game()
	# COLECCIONABLE "mapa del tesoro": completar los 7 días de la racha.
	if n >= DailyData.day_count():
		unlock_collectible("mapa_tesoro")
	return dado


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
	roll_shop_stock()
	save_game()
	return true


# --- Potenciadores permanentes ---------------------------------------------

func is_perk_unlocked(id: String) -> bool:
	return id in unlocked_perks


## Desbloquea un potenciador por combo. Devuelve true si era nuevo (para
## anunciarlo en el panel de resultados). El primer uso va de regalo.
func unlock_perk(id: String) -> bool:
	if id in unlocked_perks:
		return false
	unlocked_perks.append(id)
	perk_uses[id] = int(perk_uses.get(id, 0)) + 1
	save_game()
	return true


func get_perk_uses(id: String) -> int:
	return int(perk_uses.get(id, 0))


func add_perk_uses(id: String, amount: int) -> void:
	perk_uses[id] = get_perk_uses(id) + amount


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
	# COLECCIONABLE "bandera pirata": un ABORDAJE superado con las 3 estrellas.
	if stars >= 3 and CampaignData.get_kind(port_id) == "abordaje":
		unlock_collectible("bandera")
	if stars >= 3 and prev_best < 3:
		for r in port.get("reward_recipes_3", []):
			if unlock_recipe(r):
				newly.append(r)
		var lingotes := int(port.get("reward_ingots_3", 0))
		if lingotes > 0:
			ingots += lingotes
		var sacos := int(port.get("reward_rice_3", 0))
		if sacos > 0:
			rice = mini(rice + sacos, RICE_START)
	if not newly.is_empty():
		# Toda receta nueva llega con despensa para estrenarla.
		gift_ingredients_for(newly, PORT_GIFT)
		# NO se pone `pending_reveal`: el cartel de fin de nivel ya las anuncia
		# (`level3d._reveal_recipes`), y volver a enseñarlas al llegar al mapa
		# era repetir lo mismo dos veces seguidas. `pending_reveal` se queda solo
		# para el TUTORIAL, que no tiene cartel de resultados.
	save_game()
	return newly


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


## Segundos JUGADOS: los suma `level3d` mientras hay partida (aventura y
## arcade). Los menús no cuentan, así que el contador de Opciones dice tiempo
## de juego de verdad, no tiempo con el juego abierto.
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
const MEDAL_REWARDS := [25, 50, 100]
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


func has_collectible(id: String) -> bool:
	return id in collectibles


## Desbloquea un coleccionable, lo ANUNCIA con su ventana y guarda. Devuelve
## true si era nuevo. `extra` añade un renglón al anuncio (el regalo del
## triángulo dorado).
func unlock_collectible(id: String, extra := "") -> bool:
	if id in collectibles or CollectibleData.get_item(id).is_empty():
		return false
	collectibles.append(id)
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
func fishing_pay() -> bool:
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
## tarjeta). Mismo reparto que el cobro en bloque: 25/50/100 por metal, y si de
## ese logro hay bronce y plata pendientes caen los dos.
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
		total += int(MEDAL_REWARDS[tier - 1])
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
			out["total"] = int(out["total"]) + int(MEDAL_REWARDS[tier - 1])
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


## Género del ayudante de cocina: el contrario al del jugador.
func helper_gender() -> String:
	return CharacterData.opposite(player_gender)


## Tope de fotogramas de la pantalla en curso: los menús se conforman con la
## mitad, jugando manda el ajuste del usuario.
func fps_for(playing: bool) -> int:
	var fps := int(get_setting("fps"))
	return fps if playing else mini(fps, 30)


## Aplica lo que es global: escala de renderizado 3D y tope de fotogramas.
## Lo demás (sombras y animaciones) lo consulta cada escena al construirse.
func apply_graphics() -> void:
	Engine.max_fps = fps_for(false)
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
		"perk_uses": perk_uses,
		"shop_stock": shop_stock,
		"shop_day": shop_day,
		"daily_day": daily_day,
		"daily_last": daily_last,
		"collectibles": collectibles,
		"triforce_pieces": triforce_pieces,
		"fish_album": fish_album,
		"fish_best": fish_best,
		"claimed_medals": claimed_medals,
		"seen_medals": seen_medals,
		"player_gender": player_gender,
		"player_hand": player_hand,
		"player_name": player_name,
		"player_title": player_title_id,
		"unlocked_titles": unlocked_titles,
		"tutorial_done": tutorial_done,
		"shop_intro_done": shop_intro_done,
		"rice_intro_done": rice_intro_done,
		"pablo_shop_done": pablo_shop_done,
		"menu_intro_done": menu_intro_done,
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
	perk_uses = {}
	var perk_dict: Dictionary = parsed.get("perk_uses", {})
	for k in perk_dict.keys():
		perk_uses[str(k)] = int(perk_dict[k])
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
	collectibles = _to_string_array(parsed.get("collectibles", []))
	triforce_pieces = int(parsed.get("triforce_pieces", 0))
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
	rice_intro_done = bool(parsed.get("rice_intro_done", false))
	pablo_shop_done = bool(parsed.get("pablo_shop_done", false))
	# Guardados de antes de la guía del menú: si el tutorial ya está hecho, la
	# guía sobra (ese jugador ya sabe dónde está la Aventura).
	menu_intro_done = bool(parsed.get("menu_intro_done", tutorial_done))
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
	stats = {}
	settings = DEFAULT_SETTINGS.duplicate()
	play_seconds = 0.0
	player_gender = CharacterData.MALE
	player_name = ""
	player_hand = "L"
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
	perk_uses = {}
	shop_stock = []
	shop_day = ""
	daily_day = 0
	daily_last = ""
	collectibles = []
	triforce_pieces = 0
	fish_album = {}
	fish_best = {}
	claimed_medals = {}
	seen_medals = {}
	# SIN recetas de inicio y con el tutorial pendiente: las 4 primeras las
	# entrega David al terminar su clase (complete_tutorial). Olvidar poner
	# tutorial_done a false aquí hacía que borrar la partida NO relanzara la
	# introducción: el true viejo se colaba en el guardado nuevo.
	tutorial_done = false
	shop_intro_done = false
	rice_intro_done = false
	pablo_shop_done = false
	menu_intro_done = false
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
