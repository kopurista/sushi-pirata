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
	# Las que NO se pueden conseguir se LISTAN (no es un fallo: hay mecanicas
	# por llegar). Es la lista de la que salen los premios de los escenarios
	# nuevos, asi que tenerla a mano evita repartir dos veces la misma pieza.
	var huerfanas: Array[String] = []
	for it in CollectibleData.ITEMS:
		var cid3 := str(it.get("id", ""))
		if not con_fuente.has(cid3):
			huerfanas.append(cid3)
	print("  piezas: %d  (%d sin historia; %d sin forma de conseguirse)"
		% [CollectibleData.ITEMS.size(), sin_desc, huerfanas.size()])
	if not huerfanas.is_empty():
		print("  sin fuente: %s" % ", ".join(huerfanas))

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
		# LA MARCA decide lo que paga y lo que le hace a la jornada, asi que un
		# mapa sin ella cae a "facil" en silencio: pagaria de menos y no
		# aplicaria ningun modificador.
		if not str(m.get("dificultad", "")) in TreasureData.DIFICULTADES:
			print("  ! %s: marca desconocida '%s'" % [mid, m.get("dificultad", "")])
			fallos += 1
		var mods: Dictionary = TreasureData.mods(m)
		for k: String in mods.keys():
			if not k in ["paciencia", "bocado", "tiempo", "vidas", "falla"]:
				print("  ! %s: modificador desconocido '%s'" % [mid, k])
				fallos += 1
		# `vidas` sin `falla` no las gasta nadie, y `falla` sin `vidas` no
		# existe: las dos cosas se leen como "un mapa dificil" y no lo son.
		if mods.has("vidas") != mods.has("falla"):
			print("  ! %s: vidas y falla van juntas o no van" % mid)
			fallos += 1
		if mods.has("falla") and not str(mods["falla"]) in ["cubo", "vacio", "maridaje"]:
			print("  ! %s: falla desconocida '%s'" % [mid, mods["falla"]])
			fallos += 1
	var por_marca := {}
	for m in TreasureData.MAPAS:
		var d := TreasureData.dificultad(m)
		por_marca[d] = int(por_marca.get(d, 0)) + 1
	print("  mapas: %d  %s" % [TreasureData.total(), str(por_marca)])

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

	# --- PREMIOS: que ninguna receta se regale DOS veces --------------------
	# Un premio repetido no da error: el segundo escenario simplemente no
	# entrega nada nuevo y su 3 estrellas se queda sin recompensa. Paso dos
	# veces al ampliar el mar 1 (el gunkan de tartar y el de ikura).
	print("=== PREMIOS ===")
	var quien_da := {}
	for p in CampaignData.PORTS:
		var id := str(p.get("id", ""))
		for campo: String in ["reward_recipes", "reward_recipes_3"]:
			for r in (p.get(campo, []) as Array):
				var rid := str(r)
				if quien_da.has(rid):
					print("  ! la receta '%s' la regalan %s y %s"
							% [rid, quien_da[rid], id])
					fallos += 1
				quien_da[rid] = id
				if not RecipeData.RECIPES.has(rid):
					print("  ! %s premia una receta inexistente '%s'" % [id, rid])
					fallos += 1
	print("  recetas repartidas por la campaña: %d" % quien_da.size())

	# --- CARRIL Y ALTURA: que la travesia serpentee de verdad ---------------
	# El sitio de un escenario en el mapa SALE DE SU POSICION, no de su id: si
	# se reordena la campaña y no se rehace, dos escenarios seguidos caen en el
	# mismo carril y la ruta deja de zigzaguear.
	print("=== MAPA ===")
	# CADA MAR TIENE SU CICLO: el 1 va [centro, izquierda, derecha] y el 2
	# [centro, izquierda, centro, derecha]. No es un descuido — son dos
	# serpenteos distintos, y el del mar 2 pasa mas veces por el centro porque
	# alli el paso es mas largo (368 px contra 312).
	var CICLO := {
		1: [CampaignData.LANE_CENTER, CampaignData.LANE_LEFT,
			CampaignData.LANE_RIGHT],
		2: [CampaignData.LANE_CENTER, CampaignData.LANE_LEFT,
			CampaignData.LANE_CENTER, CampaignData.LANE_RIGHT],
	}
	for mar in [1, 2]:
		var carriles: Array = CICLO[mar]
		var pos := 0
		var antes := INF
		for p in CampaignData.PORTS:
			if int(p.get("sea", 1)) != mar:
				continue
			var id := str(p.get("id", ""))
			if not CampaignData.MAP_POS.has(id):
				continue
			var v: Vector2 = CampaignData.MAP_POS[id]
			var esperado: float = carriles[pos % carriles.size()]
			# LA GUARIDA DEL JEFE VA CENTRADA Y APARTE, fuera del ciclo: no
			# comparte carril con nadie porque no comparte nada con nadie.
			if str(p.get("boss", "")) != "":
				esperado = v.x
			if not is_equal_approx(v.x, esperado):
				print("  ! %s (pos %d del mar %d) esta en el carril que no toca"
						% [id, pos + 1, mar])
				fallos += 1
			if v.y >= antes:
				print("  ! %s no va por encima del anterior en el mapa" % id)
				fallos += 1
			antes = v.y
			pos += 1

	# --- EL CARTEL DE CADA ESCENARIO tiene su numero horneado ---------------
	# `assets/map/num_N.png` se genera con `tools/num_map.py` y hay UNO POR
	# ESCENARIO. Añadir escenarios sin volver a pasarlo deja el mapa escupiendo
	# "Resource file not found" por cada cartel que falta, y eso solo se ve
	# abriendo el mapa. Paso al ampliar el mar 1 de 25 a 30.
	var faltan_num := 0
	for i in range(1, CampaignData.PORTS.size() + 1):
		if not ResourceLoader.exists("res://assets/map/num_%d.png" % i):
			faltan_num += 1
	if faltan_num > 0:
		print("  ! faltan %d texturas de numero: pasar tools/num_map.py"
				% faltan_num)
		fallos += faltan_num

	# --- TIPOS: que ningun escenario se quede sin el suyo declarado ---------
	# `get_kind` cae a "isla" cuando falta, y eso no da ningun error: cambia el
	# escenario, la musica, el handicap y hasta SI HAY RELOJ. Paso con los cinco
	# que ampliaron el mar 1: un abordaje se jugaba sin reloj y dos puertos
	# salian con palmeras. Y una ISLA sin `fixed_recipes` es igual de raro: su
	# carta la decide el diseño, no el jugador.
	print("=== TIPOS DE ESCENARIO ===")
	var por_tipo := {}
	for p in CampaignData.PORTS:
		var id := str(p.get("id", ""))
		if not CampaignData.KINDS.has(id):
			print("  ! %s no declara tipo: se juega como isla sin quererlo" % id)
			fallos += 1
		# OJO: aqui se lee la CONSTANTE, no `CampaignData.get_kind()`. Bajo
		# `--script` no hay autoloads, asi que `campaign_data.gd` no termina de
		# compilar (referencia a GameState) y sus FUNCIONES no existen: llamar a
		# una revienta el _init a media auditoria, sin llegar nunca al quit(),
		# y el proceso se queda colgado para siempre. Las CONSTANTES si valen.
		var k := str(CampaignData.KINDS.get(id, "isla"))
		por_tipo[k] = int(por_tipo.get(k, 0)) + 1
		if k == "isla" and (p.get("fixed_recipes", []) as Array).is_empty():
			print("  ! %s es isla y no lleva carta cerrada (fixed_recipes)" % id)
			fallos += 1
	print("  reparto: ", por_tipo)

	# --- GUIONES: que todo `director` declarado tenga su rama en _run() -----
	# Es el fallo MAS CARO del juego y no da ni un error: sin rama, `_run`
	# vuelve sin llamar a `_play()`, `narrating` se queda en true y el nivel NO
	# ARRANCA (level3d._ask_start espera su tope de 90 s). Hay red de seguridad
	# en el `_:` del match, pero ese escenario se queda MUDO, que tampoco vale.
	# Se lee el codigo fuente porque las ramas de un `match` no se pueden
	# preguntar en tiempo de ejecucion.
	print("=== GUIONES ===")
	var fuente := FileAccess.get_file_as_string("res://scripts/level_director.gd")
	var guiones := {}
	for p in CampaignData.PORTS:
		var g := str(p.get("director", ""))
		if g == "":
			continue
		guiones[g] = true
		if not fuente.contains('"%s":' % g):
			print("  ! %s declara el guion '%s' y no tiene rama en _run()"
					% [p.get("id", ""), g])
			fallos += 1
		if not fuente.contains("func _%s(" % g):
			print("  ! el guion '%s' no tiene funcion _%s()" % [g, g])
			fallos += 1
	print("  guiones declarados: %d" % guiones.size())

	# --- MISIONES: que cada tipo de objetivo se apunte en alguna parte ------
	# Un tipo que nadie sube es una mision IMPOSIBLE, y tampoco da error: el
	# mapa se arma, se juega y su contador se queda a cero para siempre. Paso
	# con "punto_perfecto", que no se apuntaba en ningun sitio.
	print("=== MISIONES ===")
	var apuntados := {}
	for ruta: String in ["res://scripts/level3d.gd", "res://scripts/client3d.gd",
			"res://scripts/prep_board.gd", "res://scripts/game_state.gd"]:
		var src := FileAccess.get_file_as_string(ruta)
		for t: String in TreasureData.TIPOS:
			if src.contains('treasure_bump("%s"' % t) \
					or src.contains('treasure_record("%s"' % t):
				apuntados[t] = true
	for t: String in TreasureData.TIPOS:
		if not apuntados.has(t):
			print("  ! el objetivo '%s' no se apunta en ningun sitio: sus mapas"
					% t + " no se pueden cumplir")
			fallos += 1
	print("  tipos de objetivo: %d" % TreasureData.TIPOS.size())

	print("=== RESUMEN: %d cosas que no cuadran ===" % fallos)
	quit()
