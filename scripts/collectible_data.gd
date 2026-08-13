class_name CollectibleData
## Catálogo de COLECCIONABLES: objetos que solo se coleccionan (no dan ni hacen
## nada), expuestos en la pestaña "Colección" del inventario.
##
## Aquí solo hay DATOS. El progreso vive en `GameState.collectibles` (ids ya
## conseguidos) y `GameState.triforce_pieces` (fragmentos del triángulo). Los
## desbloqueos van SIEMPRE por `GameState.unlock_collectible()`, que además
## enseña la ventana de anuncio y guarda.
##
## `desc` es CÓMO se consigue: solo se enseña cuando ya está conseguido (los
## bloqueados van en silueta y sin ninguna pista, a propósito). Los que aún no
## tienen forma de conseguirse llevan un texto genérico y ningún disparador:
## quedan bloqueados hasta que su mecánica exista (botella → minijuego de
## pesca; catalejo y compañía → pendientes de diseño).
##
## El TRIÁNGULO DORADO es especial: son TRIFORCE_PIECES fragmentos que se
## juntan en UN solo coleccionable; al completarlo se regalan
## TRIFORCE_REWARD doblones (`GameState.add_triforce_piece`).

const TRIFORCE_PIECES := 8
const TRIFORCE_REWARD := 3

## El logro "coleccionista" pide TODOS: sus metas viven en
## `achievement_data.gd` y la del oro tiene que ser ITEMS.size(). Al añadir un
## coleccionable aquí hay que subir esa meta con él, o el logro mentiría.
const ITEMS: Array = [
	{
		"id": "timon", "name": "Timón",
		"desc": "Dale cinco vueltas completas al timón del menú.",
		"icon": "res://assets/ui/timon.png",
	},
	{
		"id": "sombrero_paja", "name": "Sombrero de paja",
		"desc": "Regalo del grumete del sombrero de paja: le serviste 20 platos.",
	},
	{
		"id": "bandera", "name": "Bandera pirata",
		"desc": "Supera un abordaje con 3 estrellas.",
	},
	{
		"id": "botella", "name": "Botella vacía",
		"desc": "Pescada en alta mar.",
	},
	{
		"id": "mapa_tesoro", "name": "Mapa del tesoro",
		"desc": "Completa los 7 días del bonus diario.",
	},
	{
		"id": "cartel_recompensa", "name": "Cartel de recompensa",
		"desc": "Acumula 1.000.000 de doblones de recompensa.",
	},
	{ "id": "catalejo", "name": "Catalejo", "desc": "" },
	{ "id": "tricornio", "name": "Sombrero tricornio", "desc": "" },
	{ "id": "panuelo", "name": "Pañuelo pirata", "desc": "" },
	{ "id": "garfio", "name": "Garfio", "desc": "" },
	{ "id": "parche", "name": "Parche pirata", "desc": "" },
	{ "id": "canon", "name": "Cañón pirata", "desc": "" },
	{ "id": "ancla", "name": "Ancla", "desc": "" },
	{ "id": "pistola", "name": "Pistola pirata", "desc": "" },
	{ "id": "espada", "name": "Espada pirata", "desc": "" },
	{ "id": "brujula", "name": "Brújula", "desc": "" },
	{
		"id": "cofre", "name": "Cofre del tesoro", "desc": "",
		"icon": "res://assets/ui/daily_cofre.png",
	},
	{ "id": "pluma_loro", "name": "Pluma de loro", "desc": "" },
	{ "id": "pluma_escribir", "name": "Pluma de escribir", "desc": "" },
	{ "id": "barril", "name": "Barril", "desc": "" },
	{ "id": "tentaculo", "name": "Tentáculo de kraken", "desc": "" },
	{ "id": "vela", "name": "Vela de barco", "desc": "" },
	{
		"id": "trifuerza", "name": "Triángulo dorado",
		"desc": "Reúne los %d fragmentos del triángulo dorado." % TRIFORCE_PIECES,
	},
]

## Texto de la ficha para los conseguidos que aún no cuentan su origen.
const DESC_GENERICA := "Un tesoro más para el camarote."


static func get_item(id: String) -> Dictionary:
	for it in ITEMS:
		if it["id"] == id:
			return it
	return {}


static func total() -> int:
	return ITEMS.size()


static func item_name(id: String) -> String:
	return str(get_item(id).get("name", id))


static func describe(id: String) -> String:
	var d := str(get_item(id).get("desc", ""))
	return d if d != "" else DESC_GENERICA


static func get_icon(id: String) -> Texture2D:
	var it := get_item(id)
	var path := str(it.get("icon", "res://assets/ui/col_%s.png" % id))
	if ResourceLoader.exists(path):
		return load(path)
	# Sin arte todavía: la moneda del juego como comodín, que nunca crashea.
	return load("res://assets/ui/moneda.png")
