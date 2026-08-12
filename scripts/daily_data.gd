class_name DailyData
## BONUS DIARIO: recompensa por días CONSECUTIVOS entrando a jugar.
##
## Siete escalones que van a más. El día 7 es el único sitio del juego donde se
## consigue el DRAGON ROLL: se sacó de las recompensas del nivel 9 justamente
## para que la racha tenga un premio que no se pueda ganar de otra manera.
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

## Cada día: doblones, sacos de arroz, lingotes, usos de ingredientes y receta.
## `extras` son usos de CADA extra (jengibre, wasabi y soja).
const DAYS: Array = [
	{ "money": 50, "rice": 1 },
	{ "money": 50, "extras": 5 },
	{ "money": 50, "ingots": 3 },
	{ "money": 75, "rice": 2, "ingots": 1 },
	{ "money": 80, "extras": 5, "ingredients": { "salmon": 5, "atun": 5 },
		"ingots": 1 },
	{ "money": 80, "extras": 5, "ingredients": { "salmon": 5, "atun": 5 },
		"rice": 2, "ingots": 2 },
	{ "money": 100, "extras": 10, "ingredients": { "salmon": 10, "atun": 10 },
		"rice": 5, "ingots": 5, "recipe": "dragon_roll" },
]

## Doblones que sustituyen a la receta del día 7 cuando ya se tiene, o sea en
## todos los ciclos menos el primero. Van ADEMÁS del resto del premio del día 7.
const RECIPE_FALLBACK := 200


static func day_count() -> int:
	return DAYS.size()


## Premio del día `n` (1..7).
static func day(n: int) -> Dictionary:
	return DAYS[clampi(n, 1, DAYS.size()) - 1]
