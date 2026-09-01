@tool
extends SceneTree
## AUDITORIA DE DATOS. Se corre asi:
##
##     "…/Godot_…_console.exe" --headless --script "res://tools/auditar.gd"
##
## Cruza los catalogos del juego entre si y canta lo que NO cuadra. Es barata
## (no monta ninguna escena, no toca el guardado) y caza justo lo que el
## compilador NO ve, porque son datos y no codigo: un escenario que premia una
## receta inexistente, un escenario sin sitio en el mapa, una receta cuyos
## pasos y etapas no cuadran, un maridaje que apunta a nada, un mapa del tesoro
## que premia una pieza que no existe, un logro con las metas desordenadas.
##
## Ya ha cazado de verdad: un escenario nuevo se colo como "nivel_110" por un
## formato mal escrito, y la tempura y el takoyaki pedian dos ingredientes que
## ninguna tabla declaraba (salian con el id crudo en la chapa de la tabla).
##
## PASARLA DESPUES DE TOCAR CUALQUIER CATALOGO.
func _init() -> void:
	var fallos := 0
	print("=== ESCENARIOS ===")
	var ids := {}
	for p in CampaignData.PORTS:
		var id := str(p.get("id", ""))
		if ids.has(id):
			print("  ! id REPETIDO: ", id)
			fallos += 1
		ids[id] = true
		if not CampaignData.MAP_POS.has(id):
			print("  ! sin sitio en el mapa: ", id)
			fallos += 1
		for campo in ["reward_recipes", "reward_recipes_3", "gift_recipes",
				"fixed_recipes", "optional_recipes", "alt_recipes"]:
			for r in (p.get(campo, []) as Array):
				if not RecipeData.RECIPES.has(str(r)):
					print("  ! %s: %s -> receta inexistente '%s'"
						% [id, campo, r])
					fallos += 1
		if p.has("collectible_client"):
			var cc: Dictionary = p["collectible_client"]
			if not bool(cc.get("mapa", false)):
				var it := str(cc.get("item", ""))
				if it != "" and CollectibleData.get_item(it).is_empty():
					print("  ! %s: cliente del tesoro con pieza inexistente '%s'"
						% [id, it])
					fallos += 1
			if cc.has("recipe") and not RecipeData.RECIPES.has(str(cc["recipe"])):
				print("  ! %s: reto de receta inexistente" % id)
				fallos += 1
	print("  escenarios: %d" % CampaignData.PORTS.size())

	print("=== RECETAS ===")
	for rid in RecipeData.RECIPES:
		var r: Dictionary = RecipeData.RECIPES[rid]
		var pasos: Array = r.get("steps", [])
		var etapas: Array = r.get("stages", [])
		if not r.get("hidden", false) and pasos.size() != etapas.size():
			print("  ! %s: %d pasos y %d etapas (tienen que cuadrar)"
				% [rid, pasos.size(), etapas.size()])
			fallos += 1
		for ing in RecipeData.get_ingredients(str(rid)):
			if not RecipeData.INGREDIENTS.has(ing):
				print("  ! %s: ingrediente inexistente '%s'" % [rid, ing])
				fallos += 1
		if r.has("maridaje"):
			for c in (r["maridaje"].get("con", []) as Array):
				if not RecipeData.RECIPES.has(str(c)):
					print("  ! %s: maridaje con receta inexistente '%s'"
						% [rid, c])
					fallos += 1
	print("  recetas: %d" % RecipeData.RECIPES.size())

	print("=== COLECCIONABLES ===")
	# Una pieza SIN `desc` no es un fallo si todavia no hay forma de
	# conseguirla: su ficha cae a `DESC_GENERICA` a proposito, para no
	# prometer una mecanica que no existe. Lo que SI es un fallo es que una
	# pieza que YA se puede ganar siga sin su historia.
	var con_fuente := {}
	for m in TreasureData.MAPAS:
		var c := str((m.get("premio", {}) as Dictionary).get("coleccionable", ""))
		if c != "":
			con_fuente[c] = "mapa del tesoro"
	for cid in FishData.FISHING_COLLECTIBLES:
		con_fuente[str(cid)] = "cofre de pesca"
	for id2 in CollectibleData.BOSS_ITEMS.values():
		con_fuente[str(id2)] = "jefe"
	var sin_desc := 0
	for it in CollectibleData.ITEMS:
		var cid2 := str(it.get("id", ""))
		if str(it.get("desc", "")) != "":
			continue
		sin_desc += 1
		if con_fuente.has(cid2):
			print("  ! %s: se gana (%s) y no tiene historia"
				% [cid2, con_fuente[cid2]])
			fallos += 1
	print("  piezas: %d  (%d sin historia, aun sin forma de conseguirse)"
		% [CollectibleData.ITEMS.size(), sin_desc])

	print("=== MAPAS DEL TESORO ===")
	var vistos := {}
	for m in TreasureData.MAPAS:
		var mid := str(m.get("id", ""))
		if vistos.has(mid):
			print("  ! id repetido: ", mid)
			fallos += 1
		vistos[mid] = true
		if not str(m.get("tipo", "")) in TreasureData.TIPOS:
			print("  ! %s: tipo desconocido '%s'" % [mid, m.get("tipo", "")])
			fallos += 1
		var pr: Dictionary = m.get("premio", {})
		var col := str(pr.get("coleccionable", ""))
		if col != "" and CollectibleData.get_item(col).is_empty():
			print("  ! %s: premia una pieza inexistente '%s'" % [mid, col])
			fallos += 1
		var ing := str(pr.get("ingrediente", ""))
		if ing != "" and not RecipeData.INGREDIENTS.has(ing):
			print("  ! %s: premia un ingrediente inexistente '%s'" % [mid, ing])
			fallos += 1
		if TreasureData.texto_objetivo(m).begins_with("Objetivo desconocido"):
			print("  ! %s: sin frase de objetivo" % mid)
			fallos += 1
	print("  mapas: %d" % TreasureData.total())

	print("=== LOGROS ===")
	for a in AchievementData.ACHIEVEMENTS:
		var aid := str(a.get("id", ""))
		var tiers: Array = a.get("tiers", [])
		if tiers.size() != 3:
			print("  ! %s: %d metas (tienen que ser 3)" % [aid, tiers.size()])
			fallos += 1
		elif int(tiers[0]) > int(tiers[1]) or int(tiers[1]) > int(tiers[2]):
			print("  ! %s: metas desordenadas %s" % [aid, str(tiers)])
			fallos += 1
	print("  logros: %d" % AchievementData.ACHIEVEMENTS.size())

	print("=== RESUMEN: %d cosas que no cuadran ===" % fallos)
	quit()
