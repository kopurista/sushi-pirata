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
## ORDEN DE LA VITRINA: los que hacen referencia a una misma cosa van JUNTOS
## (One Piece con One Piece, Zelda con Zelda...). Al añadir un coleccionable,
## meterlo en su grupo — y si estrena grupo, abrirlo con su comentario.
const ITEMS: Array = [
	# --- Tesoros del propio barco (los de mecánica viva, primero) ------------
	{
		"id": "timon", "name": "Timón",
		"desc": "Dale cinco vueltas completas al timón del menú.",
		"icon": "res://assets/ui/timon.png",
	},
	{
		"id": "bandera", "name": "Bandera pirata",
		"desc": "Supera un abordaje con 3 estrellas.",
	},
	{
		"id": "mapa_tesoro", "name": "Mapa del tesoro",
		"desc": "Completa los 7 días del bonus diario.",
	},
	{
		"id": "cartel_recompensa", "name": "Cartel de recompensa",
		"desc": "Acumula 1.000.000 de doblones de recompensa.",
	},
	{
		"id": "botella", "name": "Botella vacía",
		"desc": "Pescada en alta mar.",
	},
	{ "id": "catalejo", "name": "Catalejo", "desc": "" },
	{ "id": "tricornio", "name": "Sombrero tricornio", "desc": "" },
	{ "id": "panuelo", "name": "Pañuelo pirata", "desc": "" },
	{ "id": "garfio", "name": "Garfio", "desc": "" },
	{ "id": "parche", "name": "Parche pirata", "desc": "" },
	{ "id": "canon", "name": "Cañón pirata", "desc": "" },
	{ "id": "bala_canon", "name": "Bala de cañón", "desc": "" },
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
	{ "id": "saco_cafe", "name": "Saco de café", "desc": "" },
	{ "id": "tentaculo", "name": "Tentáculo de kraken", "desc": "" },
	{ "id": "hueso", "name": "Hueso", "desc": "" },
	{ "id": "calavera", "name": "Calavera", "desc": "" },
	{ "id": "pata_palo", "name": "Pata de palo", "desc": "" },
	# --- Piratas del Caribe --------------------------------------------------
	{ "id": "perla_negra", "name": "Perla negra", "desc": "" },
	{ "id": "moneda_azteca", "name": "Moneda azteca", "desc": "" },
	# --- Monkey Island -------------------------------------------------------
	{ "id": "grog", "name": "Botella de grog", "desc": "" },
	{ "id": "mono_tres_cabezas", "name": "Mono de tres cabezas", "desc": "" },
	{ "id": "lista_insultos", "name": "Lista de insultos", "desc": "" },
	# --- One Piece (la banda del sombrero de paja, en orden de tripulación) --
	{
		"id": "sombrero_paja", "name": "Sombrero de paja",
		"desc": "Regalo del grumete del sombrero de paja: le serviste 20 platos.",
	},
	{ "id": "pendientes_espadachin", "name": "Pendientes de espadachín",
		"desc": "" },
	{ "id": "naranja", "name": "Naranja", "desc": "" },
	{ "id": "tirachinas", "name": "Tirachinas", "desc": "" },
	{ "id": "sarten", "name": "Sartén", "desc": "" },
	# --- Zelda (el triángulo cierra la vitrina) ------------------------------
	{ "id": "vela", "name": "Vela de barco", "desc": "" },
	{ "id": "semilla_dorada", "name": "Semilla dorada", "desc": "" },
	{ "id": "reloj_arena", "name": "Reloj de arena", "desc": "" },
	{ "id": "mascara_zora", "name": "Máscara Zora", "desc": "" },
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
