class_name CollectibleData
## Catálogo de COLECCIONABLES: objetos que solo se coleccionan (no dan ni hacen
## nada), expuestos en la pestaña "Colección" del inventario.
##
## Aquí solo hay DATOS. El progreso vive en `GameState.collectibles` (ids ya
## conseguidos) y `GameState.triforce_pieces` (fragmentos del triángulo). Los
## desbloqueos van SIEMPRE por `GameState.unlock_collectible()`, que además
## enseña la ventana de anuncio y guarda.
##
## `desc` es CÓMO se consigue —o el guiño que lo explica—, y solo se enseña
## cuando ya está conseguido (los bloqueados van en silueta y sin ninguna
## pista, a propósito). Los que aún no tienen forma de conseguirse llevan un
## texto genérico y ningún disparador: quedan bloqueados hasta que su mecánica
## exista.
##
## DE DÓNDE SALE CADA COSA (regla de diseño, decidida por el usuario):
## · Los que REFERENCIAN otra obra (Zelda, One Piece, Monkey Island, Day of
##   the Tentacle, Piratas del Caribe, El Planeta del Tesoro, Laputa...) se
##   consiguen PESCANDO, en el cofre del minijuego
##   (`FishData.FISHING_COLLECTIBLES`). Excepción: el sombrero de paja, que ya
##   tiene su escena propia con el grumete, y la Tripuerca, que llega en
##   fragmentos por ese mismo cofre.
## · Los PIRATAS genéricos (tricornio, pistola, cañón, barril...) se ganarán
##   en aventura, en arcade o por vías especiales — de momento la mayoría
##   sigue sin disparador. La EXCEPCIÓN son los que uno draga literalmente del
##   fondo del mar (botella, ancla, calavera, hueso, pata de palo, tentáculo,
##   garfio, brújula, catalejo, bala de cañón): esos también se pescan.
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
		"desc": "Regalo del pirata del Estrecho del Rayo, por darle bien de comer.",
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
	{ "id": "catalejo", "name": "Catalejo",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "tricornio", "name": "Sombrero tricornio",
		"desc": "Un capitán agradecido se lo quitó de la cabeza y lo dejó sobre la barra." },
	{ "id": "panuelo", "name": "Pañuelo pirata", "desc": "" },
	{ "id": "garfio", "name": "Garfio",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "parche", "name": "Parche pirata", "desc": "" },
	{ "id": "canon", "name": "Cañón pirata", "desc": "" },
	{ "id": "bala_canon", "name": "Bala de cañón",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "ancla", "name": "Ancla",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "pistola", "name": "Pistola pirata", "desc": "" },
	{ "id": "espada", "name": "Espada pirata", "desc": "" },
	{ "id": "brujula", "name": "Brújula",
		"desc": "Salió de un cofre pescado en alta mar." },
	{
		"id": "cofre", "name": "Cofre del tesoro", "desc": "",
		"icon": "res://assets/ui/daily_cofre.png",
	},
	{ "id": "pluma_loro", "name": "Pluma de loro", "desc": "" },
	{ "id": "pluma_escribir", "name": "Pluma de escribir", "desc": "" },
	{ "id": "barril", "name": "Barril", "desc": "" },
	{ "id": "saco_cafe", "name": "Saco de café", "desc": "" },
	{ "id": "tentaculo", "name": "Tentáculo de kraken",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "hueso", "name": "Hueso",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "calavera", "name": "Calavera",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "pata_palo", "name": "Pata de palo",
		"desc": "Salió de un cofre pescado en alta mar." },
	# --- Piratas del Caribe --------------------------------------------------
	{ "id": "perla_negra", "name": "Perla negra",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "moneda_azteca", "name": "Moneda azteca",
		"desc": "Salió de un cofre pescado en alta mar." },
	# --- Monkey Island -------------------------------------------------------
	{ "id": "grog", "name": "Botella de grog",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "mono_tres_cabezas", "name": "Peluche de un mono con 3 cabezas",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "lista_insultos", "name": "Lista de insultos",
		"desc": "Salió de un cofre pescado en alta mar." },
	# --- Day of the Tentacle -------------------------------------------------
	{ "id": "gafas_nerd", "name": "Gafas rotas de nerd",
		"desc": "Tiene grabado el nombre de Bernard Bernoulli." },
	{ "id": "tentaculo_purpura", "name": "Tentáculo púrpura radioactivo",
		"desc": "Sigue templado y brilla en la oscuridad. Juraría que ha parpadeado." },
	# --- One Piece (la banda del sombrero de paja, en orden de tripulación) --
	{
		"id": "sombrero_paja", "name": "Sombrero de paja",
		"desc": "Regalo del grumete del sombrero de paja: le serviste 20 platos.",
	},
	{ "id": "pendientes_espadachin", "name": "Pendientes de espadachín",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "naranja", "name": "Naranja robada",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "tirachinas", "name": "Tirachinas de mentira",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "sarten", "name": "Sartén de cocina",
		"desc": "Salió de un cofre pescado en alta mar." },
	# --- El Planeta del Tesoro -----------------------------------------------
	{ "id": "esfera_tesoro", "name": "Esfera del tesoro",
		"desc": "Esta esfera con forma de planeta podría ser un mapa del tesoro." },
	# --- El castillo en el cielo ---------------------------------------------
	{ "id": "colgante_cielos", "name": "Colgante de los cielos",
		"desc": "Parece que este colgante cayó de los cielos hace mucho tiempo." },
	# --- Zelda (el triángulo cierra la vitrina) ------------------------------
	{ "id": "vela", "name": "Vela de mascarón",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "semilla_dorada", "name": "Semilla dorada",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "reloj_arena", "name": "Reloj de arena",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "mascara_zora", "name": "Máscara de raza marina",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "escudo_antiguo", "name": "Escudo antiguo",
		"desc": "Por algún motivo tiene tu nombre escrito por detrás." },
	{ "id": "foto_christine", "name": "Foto de Christine",
		"desc": "Parece la foto de una antigua princesa." },
	{ "id": "peluche_morsa", "name": "Peluche de morsa del desierto",
		"desc": "Una morsa de peluche. Nadie sabe qué hacía tan lejos del mar." },
	{ "id": "huevo_montana", "name": "Huevo de montaña",
		"desc": "Ni en mis mejores sueños encontraría un huevo tan grande." },
	{
		"id": "trifuerza", "name": "Tripuerca de Oro",
		"desc": "Reúne los %d fragmentos de la Tripuerca de Oro." % TRIFORCE_PIECES,
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
