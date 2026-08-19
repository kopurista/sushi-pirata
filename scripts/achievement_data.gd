class_name AchievementData
## Catálogo de LOGROS con tres medallas (bronce, plata, oro).
##
## Aquí solo están los DATOS. El progreso lo calcula `GameState.achievement_value()`
## leyendo el diccionario de estadísticas persistente (`GameState.stats`), porque
## el catálogo es estático y el progreso es estado de la partida guardada.
##
## Para añadir un logro: una entrada en `ACHIEVEMENTS` con su `stat` y sus tres
## metas. Si la estadística no existe todavía hay que subirla desde donde ocurra
## el suceso (`GameState.bump_stat` / `max_stat`); los logros de recetas salen
## solos de `RecipeData.RECIPES`.

## Las tres medallas, de menos a más.
const MEDALS := ["bronce", "plata", "oro"]
const MEDAL_NAMES := ["Bronce", "Plata", "Oro"]
const MEDAL_COLORS := [
	Color(0.80, 0.50, 0.26),
	Color(0.78, 0.80, 0.85),
	Color(1.00, 0.80, 0.25),
]

## Apartados en los que se agrupan en la pantalla de logros. Son DOS, y no los
## cinco de antes: "Barra" (clientela) y "Platos" (recetario) son cocina —lo que
## se sirve y a quién— y "Oro" es parte del viaje. Con cinco tablones en 720 px
## los rótulos apenas cabían, y tres de las pestañas tenían media docena de
## fichas cada una.
const GROUPS := ["cocina", "travesia", "pesca"]
const GROUP_NAMES := {
	"cocina": "Cocina",
	"travesia": "Travesía",
	"pesca": "Pesca",
}
## Rótulo de la PESTAÑA. Con tres tablones siguen cabiendo enteros.
const GROUP_TABS := {
	"cocina": "Cocina",
	"travesia": "Travesía",
	"pesca": "Pesca",
}

## Metas de los logros "prepara N platos de X" (uno por receta no oculta).
const RECIPE_TIERS := [25, 100, 500]

## Metas de los logros "pesca N ejemplares de X", UNO POR PEZ. Cuanto más raro
## es el bicho, menos ejemplares se piden: un común pica cada dos por tres y un
## legendario es la captura de una tarde entera. Los pesos del sorteo son
## 24/10/4/1 por rareza, así que la escala de metas va más o menos al revés.
const FISH_TIERS := {
	"comun": [10, 30, 80],
	"raro": [5, 15, 40],
	"epico": [3, 8, 20],
	"legendario": [1, 3, 8],
}

## ICONO PROPIO DE CADA LOGRO. Los de receta usan el sprite de su plato y los de
## pez su ficha del álbum (ver `icon_for`), así que aquí solo están los escritos
## a mano. Todos DISTINTOS a propósito: en una lista de sesenta fichas, la
## moneda repetida no ayudaba a distinguir ninguna.
const ICONS := {
	# --- Cocina ---
	"bonificadores": "res://assets/ui/ic_perks.png",
	"mejoras": "res://assets/ui/perk_limite.png",
	"maestria_perk": "res://assets/ui/perk_barco.png",
	"grumetes": "res://assets/ui/head_E.png",
	"piratas": "res://assets/ui/head_A.png",
	"capitanes": "res://assets/ui/head_G.png",
	"clientes": "res://assets/ui/pot_clientela.png",
	"cliente_fiel": "res://assets/ui/pot_variedad.png",
	"despedidas": "res://assets/dishes/mochi.webp",
	"platos": "res://assets/dishes/nigiri_salmon.webp",
	"platos_partida": "res://assets/ui/pot_sin_esperas.png",
	"cortes": "res://assets/ui/col_espada.png",
	"tempura_perfecta": "res://assets/dishes/tempura.webp",
	"barcos": "res://assets/dishes/moriawase.webp",
	"combos": "res://assets/dishes/udon_tempura.webp",
	"extras": "res://assets/ingredients/jengibre.png",
	"sin_desperdicio": "res://assets/ui/pot_sin_basura.png",
	# --- Travesía ---
	"dinero_nivel": "res://assets/ui/pack_moneda_100.png",
	"dinero_arcade": "res://assets/ui/ic_arcade.png",
	"dinero_total": "res://assets/ui/pack_moneda_1000.png",
	"propinas": "res://assets/ui/ic_propina.png",
	"gastado": "res://assets/ui/ic_tienda.png",
	"estrellas": "res://assets/ui/estrella_llena.png",
	"niveles": "res://assets/ui/ic_aventura.png",
	"recetario_completo": "res://assets/ui/ic_inventario.png",
	"partidas": "res://assets/ui/timon.png",
	"dias": "res://assets/ui/reloj.png",
	"coleccion": "res://assets/ui/col_trifuerza.png",
	# El de dinero en arcade ya usa ic_arcade: las oleadas van con el barco
	# enemigo del mapa, que es la estampa del abordaje sin fin.
	"arcade_oleadas": "res://assets/map/barco_enemigo.png",
	"maestro_cocinero": "res://assets/ui/ic_maestrias.png",
	"maestrias": "res://assets/ui/skill_golpe_vista.png",
	# --- Pesca ---
	"pesca_capturas": "res://assets/ui/ic_pesca.png",
	"pesca_album": "res://assets/ui/ic_album.png",
	"pesca_legendarios": "res://assets/ui/col_perla_negra.png",
	"pesca_cofres": "res://assets/ui/cofre.png",
	"pesca_lapa": "res://assets/ui/fish_pez_lapa.png",
	"pesca_basura": "res://assets/ui/col_botella.png",
	"pesca_sedal_roto": "res://assets/ui/pesca_cana.png",
	"pesca_escapes": "res://assets/ui/fish_pez_volador.png",
}

## `stat`: clave de `GameState.stats`, un Array de claves que se SUMAN, o una
## clave "derived:*" que GameState calcula del progreso guardado.
const ACHIEVEMENTS: Array = [
	# --- Clientela -----------------------------------------------------------
	{
		"id": "grumetes", "group": "cocina", "name": "Pan de grumetes",
		"desc": "Da de comer a %d grumetes.",
		"stat": "clients_E", "tiers": [100, 500, 2000],
	},
	{
		"id": "piratas", "group": "cocina", "name": "Rancho de la tripulación",
		"desc": "Da de comer a %d piratas.",
		"stat": "clients_A", "tiers": [100, 500, 2000],
	},
	{
		"id": "capitanes", "group": "cocina", "name": "Mesa de capitanes",
		"desc": "Da de comer a %d capitanes.",
		"stat": "clients_G", "tiers": [100, 500, 2000],
	},
	{
		"id": "clientes", "group": "cocina", "name": "La barra nunca duerme",
		"desc": "Da de comer a %d clientes.",
		"stat": "clients_total", "tiers": [1000, 5000, 20000],
	},
	{
		"id": "cliente_fiel", "group": "cocina", "name": "Cliente de la casa",
		"desc": "Consigue que un mismo cliente coma %d platos seguidos.",
		"stat": "best_client_plates", "tiers": [5, 8, 12],
	},
	{
		"id": "despedidas", "group": "cocina", "name": "La cuenta, por favor",
		"desc": "Prepara %d postres de los que despiden al cliente.",
		"stat": ["dish_mochi", "dish_dorayaki", "dish_taiyaki"],
		"tiers": [25, 150, 600],
	},

	# --- Cocina --------------------------------------------------------------
	{
		"id": "platos", "group": "cocina", "name": "Manos de cocinero",
		"desc": "Prepara %d platos.",
		"stat": "dishes_made", "tiers": [500, 3000, 15000],
	},
	{
		"id": "platos_partida", "group": "cocina", "name": "Turno de locura",
		"desc": "Sirve %d platos en una sola partida.",
		"stat": "best_dishes_run", "tiers": [20, 35, 50],
	},
	{
		"id": "cortes", "group": "cocina", "name": "Pulso de cirujano",
		"desc": "Completa %d cortes lentos sin pasarte de rápido.",
		"stat": "slices_ok", "tiers": [50, 300, 1500],
	},
	{
		"id": "tempura_perfecta", "group": "cocina", "name": "Tres segundos clavados",
		"desc": "Borda %d tempuras en el punto exacto.",
		"stat": "fry_perfect", "tiers": [5, 25, 100],
	},
	{
		"id": "barcos", "group": "cocina", "name": "Armador de barcos",
		"desc": "Sirve %d barcos combinados.",
		"stat": "dish_moriawase", "tiers": [10, 50, 250],
	},
	{
		"id": "combos", "group": "cocina", "name": "Maridajes",
		"desc": "Sirve %d platos combinados.",
		"stat": "dish_udon_tempura", "tiers": [10, 50, 200],
	},
	{
		"id": "extras", "group": "cocina", "name": "Con su jengibre",
		"desc": "Acompaña %d platos con jengibre, wasabi o soja.",
		"stat": "extras_used", "tiers": [50, 250, 1000],
	},
	{
		"id": "sin_desperdicio", "group": "cocina", "name": "Aquí no se tira nada",
		"desc": "Termina %d partidas sin que se desperdicie ni un plato.",
		"stat": "clean_runs", "tiers": [1, 10, 50],
	},

	# --- Fortuna -------------------------------------------------------------
	{
		"id": "dinero_nivel", "group": "travesia", "name": "Caja del día",
		"desc": "Gana %d doblones en un nivel de la campaña.",
		"stat": "best_money_level", "tiers": [60, 100, 150],
	},
	{
		"id": "dinero_arcade", "group": "travesia", "name": "Récord de Arcade",
		"desc": "Gana %d doblones en una partida de Arcade.",
		"stat": "best_money_arcade", "tiers": [80, 140, 220],
	},
	{
		"id": "arcade_oleadas", "group": "travesia", "name": "Contra la marea",
		"desc": "Aguanta hasta la oleada %d del Arcade sin fin.",
		"stat": "arcade_wave", "tiers": [10, 25, 40],
	},
	{
		"id": "maestro_cocinero", "group": "travesia", "name": "Oficio de a bordo",
		"desc": "Alcanza el nivel %d de cocinero.",
		"stat": "chef_level", "tiers": [25, 100, 300],
	},
	{
		"id": "maestrias", "group": "travesia", "name": "Manos que aprenden",
		"desc": "Ten %d maestrías aprendidas a la vez.",
		"stat": "skills_owned", "tiers": [3, 9, 15],
	},
	# --- BONIFICADORES: conseguirlos y mejorarlos. Las estadísticas las suben
	# GameState.unlock_perk y upgrade_perk, que es donde ocurre el suceso.
	{
		"id": "bonificadores", "group": "travesia", "name": "Tripulación de lujo",
		"desc": "Consigue %d bonificadores permanentes.",
		"stat": "perks_unlocked", "tiers": [1, 2, 4],
	},
	{
		"id": "mejoras", "group": "travesia", "name": "Siempre a más",
		"desc": "Mejora un bonificador %d veces.",
		"stat": "perk_upgrades", "tiers": [1, 5, 12],
	},
	{
		"id": "maestria_perk", "group": "travesia", "name": "Al máximo",
		"desc": "Lleva un bonificador hasta el nivel %d.",
		"stat": "best_perk_level", "tiers": [2, 3, 5],
	},
	{
		"id": "dinero_total", "group": "travesia", "name": "Cofre del tesoro",
		"desc": "Gana %d doblones en total.",
		"stat": "money_total", "tiers": [1000, 10000, 50000],
	},
	{
		"id": "propinas", "group": "travesia", "name": "Quédate el cambio",
		"desc": "Reúne %d doblones en propinas.",
		"stat": "tips_total", "tiers": [500, 3000, 15000],
	},
	{
		"id": "gastado", "group": "travesia", "name": "Cliente del tendero",
		"desc": "Gástate %d doblones en la tienda.",
		"stat": "shop_spent", "tiers": [200, 1500, 8000],
	},

	# --- Travesía ------------------------------------------------------------
	{
		"id": "estrellas", "group": "travesia", "name": "Cielo estrellado",
		"desc": "Reúne %d estrellas en la campaña.",
		"stat": "derived:estrellas", "tiers": [9, 18, 27],
	},
	{
		"id": "niveles", "group": "travesia", "name": "Rumbo fijo",
		"desc": "Supera %d puertos de la campaña.",
		"stat": "derived:niveles", "tiers": [3, 6, 9],
	},
	{
		"id": "recetario_completo", "group": "travesia", "name": "Recetario completo",
		"desc": "Aprende %d recetas.",
		"stat": "derived:recetas", "tiers": [4, 8, 12],
	},
	{
		"id": "partidas", "group": "travesia", "name": "Lobo de mar",
		"desc": "Juega %d partidas.",
		"stat": "runs", "tiers": [25, 150, 600],
	},
	{
		"id": "dias", "group": "travesia", "name": "Fiel a la cocina",
		"desc": "Juega en %d días distintos.",
		"stat": "days_played", "tiers": [5, 30, 100],
	},
	{
		# La meta del ORO tiene que ser CollectibleData.ITEMS.size(): el logro
		# se remata teniendo TODOS los coleccionables. Al añadir uno al catálogo
		# hay que subir esta cifra con él, o el logro mentiría.
		"id": "coleccion", "group": "travesia", "name": "Camarote de tesoros",
		"desc": "Reúne %d coleccionables.",
		"stat": "derived:coleccion", "tiers": [19, 39, 78],
	},

	# --- Pesca ---------------------------------------------------------------
	# Apartado PROPIO: el minijuego tiene sus estadísticas, su álbum y su
	# progreso aparte, y mezclarlo con la travesía escondía la colección.
	{
		"id": "pesca_capturas", "group": "pesca", "name": "Buena mano con la caña",
		"desc": "Saca %d capturas del mar.",
		"stat": "fish_caught", "tiers": [10, 100, 500],
	},
	{
		# La meta del ORO es FishData.total(): se remata con el álbum LLENO.
		# Al añadir un pez al catálogo hay que subirla con él.
		"id": "pesca_album", "group": "pesca", "name": "Álbum del océano",
		"desc": "Descubre %d especies distintas.",
		"stat": "derived:pesca_album", "tiers": [15, 50, 100],
	},
	{
		"id": "pesca_legendarios", "group": "pesca", "name": "Leyendas de las profundidades",
		"desc": "Pesca %d ejemplares legendarios.",
		"stat": "fish_legendary", "tiers": [1, 5, 20],
	},
	{
		"id": "pesca_cofres", "group": "pesca", "name": "Rastreador de cofres",
		"desc": "Abre %d cofres pescados en alta mar.",
		"stat": "chests_fished", "tiers": [5, 40, 150],
	},
	{
		"id": "pesca_lapa", "group": "pesca", "name": "Dos por el precio de uno",
		"desc": "Pesca %d peces con un pez lapa pegado.",
		"stat": "fish_lapa", "tiers": [1, 10, 40],
	},
	{
		"id": "pesca_basura", "group": "pesca", "name": "Limpiando el fondo",
		"desc": "Saca %d trastos del mar: botellas, ruedas y botas.",
		"stat": "fish_junk", "tiers": [5, 25, 100],
	},
	{
		"id": "pesca_sedal_roto", "group": "pesca", "name": "Mano dura",
		"desc": "Revienta el sedal %d veces tirando de más.",
		"stat": "fish_line_broken", "tiers": [5, 20, 60],
	},
	{
		"id": "pesca_escapes", "group": "pesca", "name": "El que se escapó",
		"desc": "Deja que se te escape un pez %d veces.",
		"stat": "fish_escaped", "tiers": [5, 20, 60],
	},
]


## Catálogo completo: los de arriba MÁS uno por cada receta que el jugador puede
## elaborar (las ocultas —barco, combinados, tempuras fallidas— tienen los suyos
## propios arriba, así que no se repiten aquí).
static var _all: Array = []


static func all() -> Array:
	if not _all.is_empty():
		return _all
	_all = ACHIEVEMENTS.duplicate(true)
	for id in RecipeData.RECIPES:
		var r: Dictionary = RecipeData.RECIPES[id]
		if r.get("hidden", false):
			continue
		_all.append({
			"id": "receta_%s" % id,
			"group": "cocina",
			"name": str(r.get("name", id)),
			"desc": "Prepara %d raciones.",
			"stat": "dish_%s" % id,
			"tiers": RECIPE_TIERS,
			"recipe": id,
		})
	# UNO POR PEZ. La BASURA se queda fuera: no es un pez, y ya tiene su propio
	# logro ("Limpiando el fondo"). El pez lapa SÍ entra: no pica, pero se
	# consigue igual (viene pegado a otra captura).
	for f in FishData.FISH:
		if f.get("junk", false):
			continue
		var fid := str(f["id"])
		_all.append({
			"id": "pez_%s" % fid,
			"group": "pesca",
			"name": str(f.get("name", fid)),
			"desc": "Pesca %d ejemplares.",
			"stat": "derived:fish:%s" % fid,
			"tiers": FISH_TIERS.get(str(f.get("rarity", "comun")),
				FISH_TIERS["comun"]),
			"fish": fid,
		})
	return _all


## El icono que identifica a un logro: el plato si es de receta, la ficha del
## álbum si es de pez, y si no el suyo de `ICONS`. La moneda solo como comodín.
static func icon_for(a: Dictionary) -> Texture2D:
	if a.has("recipe"):
		var t := RecipeData.get_dish_texture(str(a["recipe"]))
		if t != null:
			return t
	if a.has("fish"):
		return FishData.get_icon(str(a["fish"]))
	var ruta := str(ICONS.get(str(a.get("id", "")), ""))
	if ruta != "" and ResourceLoader.exists(ruta):
		return load(ruta)
	return load("res://assets/ui/moneda.png")


static func get_achievement(id: String) -> Dictionary:
	for a in all():
		if a["id"] == id:
			return a
	return {}


static func in_group(group: String) -> Array:
	var out: Array = []
	for a in all():
		if a["group"] == group:
			out.append(a)
	return out


## Medalla conseguida con ese progreso: 0 ninguna, 1 bronce, 2 plata, 3 oro.
static func medal_for(a: Dictionary, value: int) -> int:
	var got := 0
	for t in a["tiers"]:
		if value >= int(t):
			got += 1
	return got


## Meta que toca ahora (la del oro si ya está todo conseguido).
static func next_target(a: Dictionary, value: int) -> int:
	for t in a["tiers"]:
		if value < int(t):
			return int(t)
	return int(a["tiers"][a["tiers"].size() - 1])


## Texto del logro con la cantidad de la meta en curso metida en su hueco.
static func describe(a: Dictionary, value: int) -> String:
	return str(a["desc"]) % next_target(a, value)
