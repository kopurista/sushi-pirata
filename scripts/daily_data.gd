class_name DailyData
## BONUS DIARIO: recompensa por días CONSECUTIVOS entrando a jugar.
##
## Siete escalones que van a más (reparto del 23-8-2026, pedido por el
## usuario). El día 7 es el único sitio del juego donde se consigue el DRAGON
## ROLL: se sacó de las recompensas del nivel 9 justamente para que la racha
## tenga un premio que no se pueda ganar de otra manera.
##
## Cómo se cuenta la racha (ver GameState.claim_daily):
##  - Se cobra UNA vez por día natural del aparato, igual que el surtido de la
##    tienda (`_today`).
##  - Si el último cobro fue AYER, la racha sube. Si fue hace más, vuelve a 1:
##    el bonus premia venir todos los días, no acumular días sueltos.
##  - Pasado el 7, la racha vuelve a empezar en 1 y hay que desbloquearlo todo
##    otra vez. En esa segunda vuelta el dragon roll ya está desbloqueado, así
##    que `claim_daily` lo cambia por `RECIPE_FALLBACK` doblones: la última
##    casilla del ciclo repetido paga oro, no una receta.
##
## Va contra el reloj del aparato, así que adelantarlo regala días. Asumido, lo
## mismo que con los sacos de arroz.

## Cada día, por clave:
##  · `money`        doblones BASE del día; el de verdad sale de `money_for`,
##                   que lo escala con el NIVEL del cocinero.
##  · `rice`         sacos de arroz.
##  · `ingots`       lingotes; SOLO con los lingotes ya presentados (Pablo).
##  · `bait`         cebos; SOLO se entregan con la pesca abierta (sin ella se
##                   saltan sin más: no se guardan para luego).
##  · `maps`         mapas del tesoro (las misiones secundarias). SOLO se
##                   entregan con los mapas ya presentados (escenario 28);
##                   antes se saltan, como el cebo.
##  · `extras`       usos de CADA extra YA PRESENTADO (jengibre, wasabi y
##                   soja llegan de uno en uno, y un extra sin presentar no
##                   cae).
##  · `extra_random` usos de UN extra sorteado al abrir el cofre.
##  · `ingredient_random` usos de UN ingrediente normal sorteado al abrir, de
##                   entre los de las recetas que el jugador ya sabe (el
##                   mismo criterio que el surtido de Saverio).
##  · `recipe`       receta que se aprende.
const DAYS: Array = [
	{ "money": 50, "rice": 1 },
	{ "money": 50, "extra_random": 5, "bait": 1 },
	{ "money": 60, "ingots": 1, "ingredient_random": 3 },
	{ "money": 75, "maps": 1, "extra_random": 3, "bait": 3 },
	{ "money": 80, "extras": 3, "ingredient_random": 3, "ingots": 1 },
	{ "money": 85, "extras": 5, "ingredient_random": 5, "bait": 5, "maps": 1 },
	{ "money": 100, "extras": 10, "ingredient_random": 10, "ingots": 5,
		"maps": 2, "bait": 10, "recipe": "dragon_roll" },
]

## Doblones que sustituyen a la receta del día 7 cuando ya se tiene, o sea en
## todos los ciclos menos el primero. Van ADEMÁS del resto del premio del día 7
## y NO escalan con el nivel (escalados, el día 7 del segundo ciclo pagaba más
## que cualquier 3★ del mar 1). Es la MISMA cifra que paga el cofre de la pesca
## sin recetas pendientes (`FishData.RECIPE_FALLBACK` la lee de aquí).
const RECIPE_FALLBACK := 200

## EL ORO ESCALA CON EL NIVEL DEL COCINERO (pedido por el usuario: "que la
## recompensa vaya escalando según su nivel"): cada nivel por encima del 1
## suma esta fracción del oro base. A 0.10, el nivel 16 (el cierre del mar 1)
## multiplica por 2,5 —el día 7 paga 250— y el nivel 100 por ~11. Es la misma
## pendiente lineal que el oro de subir de nivel (`SkillData.level_reward`).
## Perilla libre: tocarla no descuadra nada más.
const ORO_POR_NIVEL := 0.10


static func day_count() -> int:
	return DAYS.size()


## Premio del día `n` (1..7).
static func day(n: int) -> Dictionary:
	return DAYS[clampi(n, 1, DAYS.size()) - 1]


## Oro de un día al nivel dado (ver ORO_POR_NIVEL).
static func money_for(base: int, nivel: int) -> int:
	return int(round(base * (1.0 + ORO_POR_NIVEL * maxi(nivel - 1, 0))))
