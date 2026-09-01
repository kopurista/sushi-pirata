@tool
extends SceneTree
## MIDE EL NIVEL RECOMENDADO DE CADA ESCENARIO. Se corre asi:
##
##     "…/Godot_…_console.exe" --headless --script "res://tools/medir_chef_rec.gd"
##
## `chef_rec` NO se estima a ojo ni con una regla de tres: es el nivel al que
## LLEGA el jugador que ha bordado (3 estrellas) todo lo anterior. Aqui se
## simula escenario a escenario con la curva real de `SkillData`, que es lo
## unico que no miente cuando se reordena la campaña o se cambia una tarifa.
##
## Imprime la linea `"chef_rec": N,` ya lista para pegar, el nivel al que se
## llega aprobando justo (2 estrellas) y el cierre de cada mar.
##
## OJO: bajo `--script` no hay autoloads, asi que `campaign_data.gd` no termina
## de compilar y sus FUNCIONES no existen — aqui solo se leen sus CONSTANTES y
## el indice se cuenta a mano. Llamar a `CampaignData.port_index()` cuelga el
## proceso a media medida, sin llegar nunca al quit().
func _init() -> void:
	print("escenario                        pos  3*  2*   XP(3*)")
	print("-------------------------------------------------------")
	for mar in [1, 2]:
		var xp_bordando := 0
		var xp_aprobando := 0
		var pos := 0
		for p in CampaignData.PORTS:
			var id := str(p.get("id", ""))
			if int(p.get("sea", 1)) != mar:
				continue
			pos += 1
			# El nivel RECOMENDADO es al que se llega con todo lo ANTERIOR
			# bordado: por eso se imprime antes de cobrar el de este.
			var rec := SkillData.level_for_xp(xp_bordando)
			var justo := SkillData.level_for_xp(xp_aprobando)
			var n := _indice(id) + 1
			var pago3 := _pago(p, n, 3)
			print("%-32s %3d %3d %3d %8d   (hoy %s)"
					% [id, pos, maxi(rec, 1), maxi(justo, 1), pago3,
						str(p.get("chef_rec", "-"))])
			xp_bordando += pago3
			xp_aprobando += _pago(p, n, 2)
		print("--- MAR %d: bordandolo entero %d XP -> nivel %d;"
				% [mar, xp_bordando, SkillData.level_for_xp(xp_bordando)]
				+ " aprobando justo %d XP -> nivel %d"
				% [xp_aprobando, SkillData.level_for_xp(xp_aprobando)])
		print("")
	quit()


## Posicion GLOBAL en PORTS (es la `n` de la tarifa: la campaña no reinicia la
## cuenta con cada mar, o el mar 2 pagaria como el 1).
func _indice(id: String) -> int:
	var i := 0
	for p in CampaignData.PORTS:
		if str(p.get("id", "")) == id:
			return i
		i += 1
	return -1


## Lo que paga ESTRENAR ese escenario con esas estrellas (la rama `prev_stars
## <= 0` de `GameState.scenario_xp`, sin el bonificador de experiencia).
func _pago(p: Dictionary, n: int, estrellas: int) -> int:
	var base := float(SkillData.XP_SCENARIO * n)
	if str(p.get("boss", "")) != "":
		base *= SkillData.XP_BOSS_MULT
	var m := float(SkillData.STAR_MULT[clampi(estrellas, 0, 3)])
	return int(round(base * m * SkillData.FIRST_MULT * SkillData.XP_GANANCIA))
