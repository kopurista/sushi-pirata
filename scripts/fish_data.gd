class_name FishData
## Catálogo del MINIJUEGO DE PESCA: los 100 peces del álbum y la tabla del
## cofre. Aquí solo hay DATOS y sorteos puros; el estado (álbum, récords,
## monedero, coleccionables) vive en GameState, y el juego es
## `fishing_game.gd`, montado SOBRE el propio menú (no hay pantalla aparte).
##
## ECONOMÍA (para no re-litigar): cada intento cuesta FISHING_COST (100)
## doblones, se cobra AL APARECER LA SOMBRA (los relanzamientos del sedal
## dentro del intento son gratis) y saca UNA de dos cosas:
## · Un PEZ (70%): cada captura trae un TAMAÑO al azar (size 0..1, sorteado
##   ANTES de ver la sombra) que decide sus doblones dentro de la horquilla
##   de su rareza — común 45–65 · raro 60–80 · épico 85–120 · legendario
##   130–190 — y el largo en cm de la ficha. Con el intento a 100 doblones,
##   SOLO las piezas gordas lo cubren: pescar por dinero compensa con épicos
##   y legendarios, y el resto se pesca por el álbum y por la despensa. (Toda
##   recompensa lleva +30 sobre la tabla anterior, subida junto al coste; la
##   BASURA es la excepción y sigue pagando JUNK_COINS.)
##   El álbum guarda el RÉCORD de tamaño por especie
##   (GameState.fish_best) y la ficha enseña el mayor pescado. Las monedas se
##   pagan DESDE LA SEGUNDA captura de la especie (la 1ª de un pez sin
##   ingrediente es solo el descubrimiento). Los peces-ingrediente dan además
##   sus usos de despensa EN CADA captura (`uses_of`: 5, y 10 el salmón real
##   — la pesca es LA fuente de despensa).
## · Un COFRE (30%): ver CHEST_TABLE. El coleccionable REPETIDO paga
##   DUP_COINS (80).
## · El PEZ LAPA no pica nunca (`no_catch`): con LAPA_CHANCE puede venir
##   PEGADO al pez pescado y entonces se cobra el valor del pez MÁS el de la
##   lapa. Es una SORPRESA: no se anuncia con la captura, sale en su propio
##   cartel al cerrar el del pez (ver `fishing_game`).
##
## LA BASURA (`junk`) es aparte: lata y rueda pagan JUNK_COINS (1) y NO
## tienen talla — su ficha no habla de centímetros. La bota SÍ tiene talla,
## pero se mide en NÚMERO DE CALZADO (`size_unit`), no en cm.
##
## EL SORTEO OCURRE ANTES DE VER LA SOMBRA (`GameState.fishing_roll()`): el
## juego ya sabe qué va a caer (pez, tamaño, lapa o cofre y su contenido) y
## de ahí salen la DIFICULTAD de la pelea (tier 0..3) y el tamaño de la
## sombra. En la pelea, la FUERZA del pez escala además con su tamaño y con
## la distancia al barco (ver fishing_game).
##
## RAREZA por pesos POR PEZ: común 24 · raro 10 · épico 4 · legendario 1.
##
## Los ICONOS son `assets/ui/fish_<id>.png` (Ludo item-icon, procesados por
## `build_fishing()` de tools/ui2_prep.py); mientras falte el arte,
## `get_icon` cae a la moneda como los coleccionables.

const FISHING_COST := 100
const FISH_INGREDIENT_USES := 5
const DUP_COINS := 80
## Probabilidad de que el intento saque COFRE en vez de pez.
const CHEST_CHANCE := 0.30
## Las monedas de rareza se pagan desde esta captura de la especie (inclusive).
const REPEAT_COINS_FROM := 2
## Probabilidad de que el pez pescado traiga un PEZ LAPA pegado.
const LAPA_CHANCE := 0.07
## Lo que paga la BASURA (`junk`), pésquese las veces que se pesque.
const JUNK_COINS := 1

## Rarezas: nombre para la ficha, color de acento, peso de sorteo POR PEZ,
## horquilla de DOBLONES por tamaño, horquilla de LARGO (cm) para la ficha y
## `tier` de dificultad de la pelea.
const RARITIES: Dictionary = {
	"comun": { "name": "Común", "weight": 24,
		"color": Color(0.55, 0.62, 0.68), "tier": 0,
		"coins": Vector2i(45, 65), "len": Vector2i(15, 40) },
	"raro": { "name": "Raro", "weight": 10,
		"color": Color(0.30, 0.55, 0.85), "tier": 1,
		"coins": Vector2i(60, 80), "len": Vector2i(30, 80) },
	"epico": { "name": "Épico", "weight": 4,
		"color": Color(0.62, 0.35, 0.80), "tier": 2,
		"coins": Vector2i(85, 120), "len": Vector2i(60, 150) },
	"legendario": { "name": "Legendario", "weight": 1,
		"color": Color(0.95, 0.72, 0.20), "tier": 3,
		"coins": Vector2i(130, 190), "len": Vector2i(100, 300) },
}

## Los 100 peces del álbum, ORDENADOS COMO LA VITRINA: por rareza ascendente
## y, dentro de cada rareza, los peces-ingrediente al final (cierran su
## escalón). Campos opcionales: `ingredient` (id de despensa), `uses` (usos
## que entrega, si no 5), `len` (horquilla propia), `desc` (la ficha del
## álbum: qué es el bicho), `no_catch` (no pica: solo aparece pegado),
## `junk` (basura: paga JUNK_COINS) y `no_size` / `size_unit` (ver arriba).
const FISH: Array = [
	# --- Comunes (33) --------------------------------------------------------
	{ "id": "sardina", "name": "Sardina", "rarity": "comun",
		"desc": "Nada en bancos enormes que se mueven como un solo animal. La plata de sus escamas confunde a los depredadores." },
	{ "id": "anchoa", "name": "Anchoa", "rarity": "comun",
		"desc": "Diminuta y de ojo grande. Curada en sal cambia por completo de sabor: por eso se pesca desde hace siglos." },
	{ "id": "boqueron", "name": "Boquerón", "rarity": "comun",
		"desc": "La misma familia que la anchoa, pero servido fresco y en vinagre. Se pesca de noche, atraído por las luces." },
	{ "id": "arenque", "name": "Arenque", "rarity": "comun",
		"desc": "Rey de los mares fríos del norte. Sus bancos llegaron a alimentar flotas enteras durante los inviernos." },
	{ "id": "caballa", "name": "Caballa", "rarity": "comun",
		"desc": "Se reconoce por las rayas onduladas de su lomo. Nada sin parar, incluso mientras duerme." },
	{ "id": "jurel", "name": "Jurel", "rarity": "comun",
		"desc": "Lleva una línea de escamas duras en el costado, como una cremallera. Es rápido y siempre va acompañado." },
	{ "id": "salmonete", "name": "Salmonete", "rarity": "comun",
		"desc": "Rebusca en la arena con dos barbillas bajo la boca, como si tanteara el fondo con los dedos." },
	{ "id": "palometa", "name": "Palometa", "rarity": "comun",
		"desc": "Plana y redonda como un plato de plata. Vira en grupo con destellos que se ven desde la superficie." },
	{ "id": "sargo", "name": "Sargo", "rarity": "comun",
		"desc": "Sus bandas oscuras lo camuflan entre las rocas. Muerde con dientes de paleta, casi humanos." },
	{ "id": "lisa", "name": "Lisa", "rarity": "comun",
		"desc": "Aguanta el agua sucia de puertos y desembocaduras. Da saltos fuera del agua sin motivo aparente." },
	{ "id": "gallo", "name": "Pez gallo", "rarity": "comun",
		"desc": "Levanta una cresta de espinas larguísimas cuando se asusta, y entonces parece el doble de grande." },
	{ "id": "bacaladilla", "name": "Bacaladilla", "rarity": "comun",
		"desc": "Prima pequeña del bacalao, de ojos enormes para ver en aguas profundas y oscuras." },
	{ "id": "bacalao", "name": "Bacalao", "rarity": "comun",
		"desc": "El pez que movió imperios: salado aguantaba meses en la bodega y cruzaba océanos sin echarse a perder." },
	{ "id": "abadejo", "name": "Abadejo", "rarity": "comun",
		"desc": "Pariente del bacalao con la mandíbula de abajo salida. Caza a media agua en vez de rebuscar en el fondo." },
	{ "id": "platija", "name": "Platija", "rarity": "comun",
		"desc": "Nace con un ojo a cada lado y, al crecer, uno se le muda de sitio para poder vivir tumbada en la arena." },
	{ "id": "ayu", "name": "Ayu", "rarity": "comun",
		"desc": "El pez dulce de Japón: come algas de las piedras y su carne huele a melón y pepino." },
	{ "id": "pejesapo", "name": "Pejesapo", "rarity": "comun",
		"desc": "Feo, plano y siempre enfadado. Se entierra en el fondo y espera a que la cena le pase por delante." },
	{ "id": "remora", "name": "Rémora", "rarity": "comun",
		"desc": "Lleva una ventosa en la cabeza para viajar pegada a tiburones y tortugas. Nunca paga el pasaje." },
	{ "id": "pez_cirujano", "name": "Pez cirujano", "rarity": "comun",
		"desc": "Azul intenso y con un bisturí escondido junto a la cola, afilado de verdad. De ahí su nombre." },
	{ "id": "pez_mariposa", "name": "Pez mariposa", "rarity": "comun",
		"desc": "Va en pareja toda la vida. La mancha oscura de su cola engaña a quien intente morderle la cabeza." },
	{ "id": "pez_payaso", "name": "Pez payaso", "rarity": "comun",
		"desc": "Vive entre los tentáculos venenosos de una anémona, inmune a ellos, y le paga limpiándola." },
	{ "id": "cangrejo", "name": "Cangrejo", "rarity": "comun",
		"desc": "Camina de lado y no suelta lo que agarra. Cuando le queda pequeño el caparazón, se lo cambia entero." },
	{ "id": "estrella_mar", "name": "Estrella de mar", "rarity": "comun",
		"desc": "No tiene cerebro ni sangre, pero si pierde un brazo le crece otro. A veces del brazo sale una estrella nueva." },
	{ "id": "caracola", "name": "Caracola", "rarity": "comun",
		"desc": "La casa espiral de un caracol de mar. Vacía y bien soplada, suena como una trompeta de abordaje." },
	{ "id": "erizo_mar", "name": "Erizo de mar", "rarity": "comun",
		"len": Vector2i(5, 12),
		"desc": "Una bola de púas que camina despacísimo con cientos de patas diminutas. Por dentro guarda cinco lenguas anaranjadas." },
	{ "id": "medusa", "name": "Medusa", "rarity": "comun",
		"desc": "Noventa y cinco por ciento agua, sin corazón ni cabeza, y aun así lleva en el mar más tiempo que los dinosaurios." },
	{ "id": "botella_rota", "name": "Botella rota", "rarity": "comun",
		"junk": true, "no_size": true,
		"desc": "Cristal verde partido por el cuello, sin mensaje dentro y con los bordes de cortar. Cuidado al desengancharla del anzuelo." },
	{ "id": "rueda", "name": "Rueda vieja", "rarity": "comun",
		"junk": true, "no_size": true,
		"desc": "Un neumático criando algas en el fondo. No vale nada, pero pesa como si hubiera picado un mero." },
	{ "id": "bota", "name": "Bota", "rarity": "comun",
		"junk": true, "size_unit": "talla", "len": Vector2i(34, 48),
		"desc": "Una bota sola, empapada y con el cordón deshecho. La pareja sigue ahí abajo, en alguna parte." },
	{ "id": "mata_wakame", "name": "Mata de wakame", "rarity": "comun",
		"ingredient": "wakame",
		"desc": "Alga de hoja ondulada que crece agarrada a las rocas. En la cocina se hincha hasta triplicar su tamaño." },
	{ "id": "gamba_real", "name": "Gamba real", "rarity": "comun",
		"ingredient": "gamba",
		"desc": "Nada hacia atrás dando coletazos cuando se asusta. Cruda es gris translúcida; el rojo llega con el calor." },
	{ "id": "salmon", "name": "Salmón", "rarity": "comun",
		"ingredient": "salmon",
		"desc": "Nace en el río, se cría en el mar y vuelve al mismo arroyo donde nació, remontando corriente y cascadas." },
	{ "id": "atun", "name": "Atún", "rarity": "comun",
		"ingredient": "atun",
		"desc": "Tiene la sangre más caliente que el agua y no puede parar de nadar: si se detiene, deja de respirar." },
	# --- Raros (36) ----------------------------------------------------------
	{ "id": "dorada", "name": "Dorada", "rarity": "raro",
		"desc": "Lleva una banda dorada entre los ojos, como una diadema. Tritura almejas con muelas de piedra." },
	{ "id": "lubina", "name": "Lubina", "rarity": "raro",
		"desc": "Cazadora elegante de las rompientes. Aguanta la resaca donde el mar golpea las rocas para emboscar allí." },
	{ "id": "besugo", "name": "Besugo", "rarity": "raro",
		"desc": "Rojo intenso y de ojo enorme. Vive hondo, y el lunar de su hombro lo delata en cualquier lonja." },
	{ "id": "lenguado", "name": "Lenguado", "rarity": "raro",
		"desc": "Cambia de color para copiar la arena en la que se posa. Puede desaparecer del todo delante de ti." },
	{ "id": "rodaballo", "name": "Rodaballo", "rarity": "raro",
		"desc": "Plano y casi redondo, con la piel llena de bultos óseos. Se entierra hasta dejar solo los ojos fuera." },
	{ "id": "merluza", "name": "Merluza", "rarity": "raro",
		"desc": "Sube de noche a cazar y baja de día a la profundidad. Su boca guarda dos filas de dientes finos como agujas." },
	{ "id": "rape", "name": "Rape", "rarity": "raro",
		"desc": "Todo cabeza y boca. Agita un señuelo sobre los ojos para que los curiosos se acerquen a mirarlo." },
	{ "id": "congrio", "name": "Congrio", "rarity": "raro",
		"desc": "Anguila enorme y sin escamas que vive metida en pecios y grietas. De noche sale entera a cazar." },
	{ "id": "morena", "name": "Morena", "rarity": "raro",
		"desc": "Abre y cierra la boca sin parar para respirar, no por amenaza. Tiene una segunda mandíbula en la garganta." },
	{ "id": "calamar", "name": "Calamar", "rarity": "raro",
		"desc": "Tres corazones, sangre azul y una nube de tinta para escapar. Se propulsa a chorro, hacia atrás." },
	{ "id": "sepia", "name": "Sepia", "rarity": "raro",
		"desc": "La maestra del disfraz: cambia de color y de textura en un segundo, y eso que es daltónica." },
	{ "id": "pulpo", "name": "Pulpo", "rarity": "raro",
		"ingredient": "pulpo",
		"desc": "Cada brazo piensa un poco por su cuenta. Abre tarros, se escapa de las peceras y recuerda las caras." },
	{ "id": "pirana", "name": "Piraña", "rarity": "raro",
		"desc": "Su fama es peor que su mordisco: casi siempre come fruta caída y peces enfermos. Casi siempre." },
	{ "id": "carpa_koi", "name": "Carpa koi", "rarity": "raro",
		"desc": "Criada durante siglos por su color. Bien cuidada vive más que la persona que la crió." },
	{ "id": "lampuga", "name": "Lampuga", "rarity": "raro",
		"desc": "Verde y oro mientras nada, apagándose en cuanto sale del agua. Crece más rápido que casi ningún pez." },
	{ "id": "pargo_rojo", "name": "Pargo rojo", "rarity": "raro",
		"desc": "Rojo de arrecife profundo, cauto y desconfiado. Los viejos aprenden a esquivar los anzuelos conocidos." },
	{ "id": "pez_volador", "name": "Pez volador", "rarity": "raro",
		"desc": "Sale del agua y planea con sus aletas hasta doscientos metros. A veces aterriza en la cubierta." },
	{ "id": "pez_balon", "name": "Pez balón", "rarity": "raro",
		"desc": "Traga agua hasta ponerse redondo y no caber en ninguna boca. Después tarda un buen rato en desinflarse." },
	{ "id": "pez_erizo", "name": "Pez erizo", "rarity": "raro",
		"desc": "Como el globo, pero con púas: al hincharse se convierte en una bola de pinchos imposible de morder." },
	{ "id": "pez_loro", "name": "Pez loro", "rarity": "raro",
		"desc": "Muerde el coral con su pico y lo tritura. La arena blanca de las playas salió, en buena parte, de aquí." },
	{ "id": "pez_ballesta", "name": "Pez ballesta", "rarity": "raro",
		"desc": "Se traba en su cueva con una espina que hace de cerrojo. Hasta que él no la suelta, no hay quien lo saque." },
	{ "id": "pez_angel", "name": "Pez ángel", "rarity": "raro",
		"desc": "Cambia de dibujo y de colores al hacerse adulto, tanto que parece otra especie distinta." },
	{ "id": "pez_cofre", "name": "Pez cofre", "rarity": "raro",
		"desc": "Va dentro de una caja ósea rígida, así que solo puede remar con las aletas. Nada como un helicóptero." },
	{ "id": "raya", "name": "Raya", "rarity": "raro",
		"desc": "Vuela por el fondo batiendo sus alas y se entierra en la arena. La púa de la cola es solo defensa." },
	{ "id": "caballito_mar", "name": "Caballito de mar", "rarity": "raro",
		"len": Vector2i(8, 18),
		"desc": "Nada de pie y se ancla a las algas con la cola. Aquí es el MACHO quien queda preñado y pare las crías." },
	{ "id": "bogavante", "name": "Bogavante", "rarity": "raro",
		"desc": "Sus dos pinzas son distintas: una tritura y la otra corta. Azul oscuro en el mar, rojo solo en la olla." },
	{ "id": "langosta", "name": "Langosta", "rarity": "raro",
		"desc": "Sin pinzas, pero con dos antenas larguísimas y un caparazón de espinas. Migra en fila india por el fondo." },
	{ "id": "tortuga", "name": "Tortuga", "rarity": "raro",
		"desc": "Cruza océanos enteros y vuelve a poner los huevos a la misma playa donde ella rompió el cascarón." },
	{ "id": "amia_calva", "name": "Amia calva", "rarity": "raro",
		"desc": "Un fósil viviente: respira aire tragándolo cuando el agua se queda sin oxígeno. Lleva aquí millones de años." },
	{ "id": "barbo_oloroso", "name": "Barbo oloroso", "rarity": "raro",
		"desc": "Rojo, gordo y con un olor que tumba a cualquiera. Dicen que en cierto lago alguien lo pesca por deporte." },
	{ "id": "pez_rana_pintado", "name": "Pez rana pintado", "rarity": "raro",
		"desc": "No nada: camina por el fondo con las aletas hechas patitas, y se disfraza de esponja para cazar." },
	{ "id": "pez_ojo_celestial", "name": "Pez ojo celestial", "rarity": "raro",
		"desc": "Criado con los ojos mirando al cielo para siempre. Ve pasar las nubes, pero nunca lo que tiene delante." },
	{ "id": "jikin", "name": "Jikin", "rarity": "raro",
		"desc": "Blanco con las aletas y los labios rojos, y una cola abierta en cruz. En Japón está protegido por ley." },
	{ "id": "oranda", "name": "Oranda", "rarity": "raro",
		"desc": "Le crece un gorro carnoso sobre la cabeza, como una boina, que a veces le tapa hasta los ojos." },
	{ "id": "pez_lapa", "name": "Pez lapa", "rarity": "raro",
		"no_catch": true, "len": Vector2i(3, 9),
		"desc": "No pica NUNCA: viaja pegado a otros peces con la ventosa de su vientre. Si viene enganchado a tu captura, se cobra aparte." },
	{ "id": "anguila", "name": "Anguila", "rarity": "raro",
		"ingredient": "unagi",
		"desc": "Nace en mitad del Atlántico y cruza el océano de cría. Nadie ha visto jamás dónde desovan los adultos." },
	# --- Épicos (23) ---------------------------------------------------------
	{ "id": "pez_espada", "name": "Pez espada", "rarity": "epico",
		"desc": "Su espada plana es hueso puro y la usa para golpear de plano a los bancos y aturdirlos antes de comer." },
	{ "id": "mero", "name": "Mero imperial", "rarity": "epico",
		"desc": "Traga a su presa entera abriendo la boca de golpe: el agua entra sola y arrastra la cena con ella." },
	{ "id": "corvina", "name": "Corvina real", "rarity": "epico",
		"desc": "Hace ruido con la vejiga natatoria: un tamborileo sordo que se oye desde la cubierta en noches quietas." },
	{ "id": "tiburon", "name": "Tiburón", "rarity": "epico",
		"desc": "Cambia de dientes toda su vida, miles de ellos. Huele una gota de sangre a cientos de metros." },
	{ "id": "tiburon_martillo", "name": "Tiburón martillo", "rarity": "epico",
		"desc": "La cabeza en T le separa los ojos y los sensores: barre el fondo como un detector de metales." },
	{ "id": "tiburon_tigre", "name": "Tiburón tigre", "rarity": "epico",
		"desc": "El basurero del mar: se ha encontrado de todo en su estómago, matrículas incluidas. Sus rayas se borran con la edad." },
	{ "id": "barracuda", "name": "Barracuda", "rarity": "epico",
		"desc": "Ataca en una embestida fulminante y le atrae cualquier destello. Cuidado con las hebillas brillantes." },
	{ "id": "pez_luna", "name": "Pez luna", "rarity": "epico",
		"desc": "El pez óseo más pesado del mundo, y parece una cabeza suelta. Toma el sol de lado en la superficie." },
	{ "id": "mantarraya", "name": "Mantarraya", "rarity": "epico",
		"desc": "Vuela bajo el agua con alas de siete metros y salta fuera para caer de panza. Es inofensiva: come plancton." },
	{ "id": "pez_leon", "name": "Pez león", "rarity": "epico",
		"desc": "Precioso y venenoso: su melena son espinas cargadas. Fuera de su mar de origen se ha vuelto una plaga." },
	{ "id": "pez_napoleon", "name": "Pez napoleón", "rarity": "epico",
		"desc": "Con esa joroba y esos labios parece un abuelo. Todos nacen hembra y algunos se vuelven macho de mayores." },
	{ "id": "pez_sierra", "name": "Pez sierra", "rarity": "epico",
		"desc": "Su hocico dentado detecta latidos escondidos en la arena y luego sirve de espada para desordenar bancos." },
	{ "id": "pez_cabeza_transparente", "name": "Pez cabeza transparente",
		"rarity": "epico",
		"desc": "Tiene la frente de cristal: sus ojos verdes van DENTRO de la cabeza y giran para mirar hacia arriba." },
	{ "id": "pez_vibora", "name": "Pez víbora", "rarity": "epico",
		"desc": "Colmillos tan largos que no le caben en la boca, y una hilera de luces en el vientre para no hacer sombra." },
	{ "id": "nautilus", "name": "Nautilus", "rarity": "epico",
		"desc": "Un pariente del pulpo metido en una concha en espiral, con noventa brazos y cámaras que llena de gas para flotar." },
	{ "id": "arowana", "name": "Arowana", "rarity": "epico",
		"desc": "Salta fuera del agua para cazar insectos de las ramas. Lo llaman pez dragón por sus escamas de moneda." },
	{ "id": "siluro", "name": "Siluro", "rarity": "epico",
		"desc": "Gigante de fondo con bigotes que saborean el agua. Los mayores pasan de los dos metros y de los cien kilos." },
	{ "id": "bata_bata", "name": "Piraña sónica", "rarity": "epico",
		"desc": "Una piraña de hojalata con una gema morada en el costado. Alguien la fabricó y el mar se la quedó." },
	{ "id": "froggy", "name": "Rana caótica", "rarity": "epico",
		"len": Vector2i(20, 40),
		"desc": "Una rana con una cola larguísima que no le pertenece. Parece estar buscando a alguien." },
	{ "id": "atun_rojo", "name": "Atún rojo", "rarity": "epico",
		"ingredient": "atun_rojo",
		"desc": "El más caro del mundo: uno solo puede valer una fortuna en la subasta del amanecer." },
	{ "id": "atun_amarillo", "name": "Atún de aleta amarilla", "rarity": "epico",
		"ingredient": "atun",
		"desc": "Sus aletas amarillas se alargan como hoces con la edad. Corre a más de setenta kilómetros por hora." },
	{ "id": "fugu", "name": "Pez globo", "rarity": "epico",
		"ingredient": "fugu",
		"desc": "Su veneno no tiene antídoto. Solo un cocinero con licencia puede servirlo, y se juega el título en cada corte." },
	{ "id": "salmon_real", "name": "Salmón real", "rarity": "epico",
		"ingredient": "salmon", "uses": 10, "len": Vector2i(90, 160),
		"desc": "El mayor de todos los salmones. Da el doble de despensa que uno normal y pelea el triple." },
	# --- Legendarios (8) -----------------------------------------------------
	{ "id": "pez_lanza", "name": "Pez lanza", "rarity": "legendario",
		"desc": "Aguja de mar abierto, esbelta y rapidísima. Se pasa la vida lejos de la costa y casi nunca se deja ver." },
	{ "id": "pez_vela", "name": "Pez vela", "rarity": "legendario",
		"desc": "El más veloz del océano: iza esa vela enorme para acorralar bancos y luego arranca como una flecha." },
	{ "id": "pez_remo", "name": "Pez remo", "rarity": "legendario",
		"desc": "Una cinta de plata de hasta once metros con una cresta roja. Cuando aparece varado, la gente habla de terremotos." },
	{ "id": "calamar_gigante", "name": "Calamar gigante", "rarity": "legendario",
		"desc": "El kraken de las leyendas, con ojos del tamaño de un plato. Se lo conoció por las cicatrices que deja en los cachalotes." },
	{ "id": "celacanto", "name": "Celacanto", "rarity": "legendario",
		"desc": "Se creyó extinguido durante setenta millones de años hasta que uno apareció en una red. Sus aletas tienen huesos, como brazos." },
	{ "id": "tiburon_ballena", "name": "Tiburón ballena", "rarity": "legendario",
		"len": Vector2i(500, 1000),
		"desc": "El pez más grande que existe, y come plancton. Cada uno lleva un dibujo de lunares distinto, como una huella." },
	{ "id": "caballito_dorado", "name": "Caballito de mar dorado",
		"rarity": "legendario", "len": Vector2i(10, 25),
		"desc": "Un caballito de oro macizo que nada como si nada. Los marineros juran que trae buena mar durante un mes." },
	{ "id": "koi_dorado", "name": "Koi dorado", "rarity": "legendario",
		"desc": "Cuenta la leyenda que la carpa que remonta la cascada se convierte en dragón. Esta va por la mitad." },
]

## Tabla del COFRE (pesos). El sorteo Y la resolución contra el estado viven
## en `GameState.fishing_roll()` / `fishing_apply()`:
## · "coins": 100–150 doblones, con dos franjas — lo normal es la baja
##   (100–125) y solo CHEST_COINS_HIGH_CHANCE de las veces cae la alta. El
##   cofre de oro SIEMPRE cubre el intento y compite con un pez épico.
## · "collectible": uno al azar de FISHING_COLLECTIBLES, tengas o no:
##   el repetido paga DUP_COINS. Es lo que pide el diseño — pre-filtrar los
##   conseguidos dejaría la regla de las 50 monedas sin usar.
## · "recipe": una receta BLOQUEADA al azar (ni ocultas ni dragon_roll, que
##   es exclusiva del día 7 del bonus diario); sin ninguna pendiente,
##   RECIPE_FALLBACK doblones (mismo criterio que el bonus diario).
## · "triforce": un fragmento del triángulo dorado (POR FIN tiene fuente);
##   con la trifuerza completa, paga DUP_COINS como un repetido.
## (Los USOS DE INGREDIENTE se cayeron del cofre a propósito: la despensa
## solo sale de PESCAR el pez correspondiente.)
const CHEST_TABLE: Array = [
	{ "kind": "coins", "weight": 50 },
	{ "kind": "collectible", "weight": 25 },
	{ "kind": "triforce", "weight": 15 },
	{ "kind": "recipe", "weight": 10 },
]
## De 50 a 100 SIEMPRE: el cofre de doblones cubre al menos el intento, que
## abrirlo tiene que ilusionar. Es además el ÚNICO botín que se acerca a lo
## que paga un pez épico, así que el cofre sigue siendo un buen premio.
const CHEST_COINS_LOW := Vector2i(100, 125)
const CHEST_COINS_HIGH := Vector2i(126, 150)
const CHEST_COINS_HIGH_CHANCE := 0.3
const RECIPE_FALLBACK := 230

## Coleccionables que se pueden PESCAR. Son DOS familias (ver la regla de
## diseño en la cabecera de `collectible_data.gd`):
## · TODO lo que REFERENCIA otra obra — Zelda, One Piece, Monkey Island, Day
##   of the Tentacle, Piratas del Caribe, El Planeta del Tesoro, Laputa. El
##   cofre del mar es SU vía. Quedan fuera el sombrero de paja (tiene su
##   escena con el grumete) y la Tripuerca (llega en fragmentos, "triforce").
## · Lo que uno DRAGA del fondo del mar aunque sea pirata genérico: botella,
##   ancla, calavera, hueso, pata de palo, tentáculo, garfio, brújula,
##   catalejo y bala de cañón. El resto de piratas (tricornio, pistola,
##   cañón, barril...) se ganará en aventura o en arcade, no aquí.
const FISHING_COLLECTIBLES: Array = [
	# Del fondo del mar.
	"botella", "ancla", "bala_canon", "calavera", "hueso", "pata_palo",
	"tentaculo", "garfio", "brujula", "catalejo",
	# De la cocina del barco (el único de los suyos que sale del mar).
	"maneki_neko",
	# Piratas del Caribe.
	"perla_negra", "moneda_azteca", "corazon_cofre",
	# Monkey Island.
	"grog", "mono_tres_cabezas", "lista_insultos", "pollo_goma",
	# Day of the Tentacle.
	"gafas_nerd", "tentaculo_purpura",
	# One Piece.
	"pendientes_espadachin", "naranja", "tirachinas", "sarten", "cuerno_reno",
	"sombrero_vaquero", "botella_cola", "violin_esqueleto", "caracol_telefono",
	# La Isla del Tesoro, Peter Pan y Popeye.
	"marca_negra", "reloj_cocodrilo", "lata_espinacas",
	# Del naufragio (piratas genericos que uno draga del fondo).
	"botella_mensaje", "farol_aceite", "astrolabio_roto", "bitacora_roto",
	# Moby Dick, 20.000 leguas, El Holandes Errante, Buscando a Nemo,
	# Indiana Jones, Overcooked, Ratatouille y Naruto.
	"arpon", "casco_escafandra", "farol_fantasma", "mascara_buceo",
	"idolo_dorado", "extintor", "gorro_chef", "cuenco_ramen",
	# Mas del naufragio.
	"dado_hueso", "baraja_marcada", "cuerno_narval", "fosil_amonites",
	"estrella_mar_seca", "espejo_mano", "cascabel_gato", "bota_vino",
	# Mitologia griega, Capitan Harlock y el peine de las sirenas.
	"obolo_caronte", "calavera_alada", "peine_nacar",
	# La Odisea, Robinson Crusoe, Tiburon y Sea of Thieves.
	"tapones_cera", "huella_arena", "bidon_amarillo", "banana",
	# Tintin, Los Goonies y La Sirenita.
	"maqueta_unicornio", "ojo_cobre", "tenedor",
	# El Planeta del Tesoro y Studio Ghibli (Laputa y Ponyo).
	"esfera_tesoro", "colgante_cielos", "tarro_ponyo",
	# Zelda.
	"vela", "batuta_viento", "semilla_dorada", "reloj_arena", "mascara_zora",
	"escudo_antiguo", "foto_christine", "peluche_morsa", "huevo_montana",
	"botella_leche",
]


static func get_fish(id: String) -> Dictionary:
	for f in FISH:
		if f["id"] == id:
			return f
	return {}


static func total() -> int:
	return FISH.size()


## Cuántas ESPECIES DEL CATÁLOGO lleva pescadas el jugador. No vale
## `fish_album.size()`: un id que se renombre (marlin -> pez_lanza) dejaría
## una entrada huérfana en el guardado y el contador se pasaría del total.
static func caught_count(album: Dictionary) -> int:
	var n := 0
	for f in FISH:
		if album.has(f["id"]):
			n += 1
	return n


static func rarity_of(id: String) -> Dictionary:
	return RARITIES.get(str(get_fish(id).get("rarity", "comun")), {})


## Tier de dificultad de la pelea de un pez (0..3, por rareza). La BASURA
## pelea siempre como lo más flojo: es un trasto, no una presa.
static func tier_of(id: String) -> int:
	if get_fish(id).get("junk", false):
		return 0
	return int(rarity_of(id).get("tier", 0))


## Doblones que paga ESTA captura según su tamaño (size 0..1 dentro de la
## horquilla de su rareza). La BASURA paga siempre JUNK_COINS.
static func coins_for(id: String, size: float) -> int:
	if get_fish(id).get("junk", false):
		return JUNK_COINS
	var c: Vector2i = rarity_of(id).get("coins", Vector2i.ZERO)
	return int(roundf(lerpf(float(c.x), float(c.y), clampf(size, 0.0, 1.0))))


## ¿Este id tiene TALLA? La lata y la rueda no: son objetos, no bichos.
static func has_size(id: String) -> bool:
	return not get_fish(id).get("no_size", false)


## La talla de ESTE ejemplar, ya con su unidad ("41 cm", "Talla 41"). Vacío
## si el id no tiene talla.
static func size_text(id: String, size: float) -> String:
	if not has_size(id):
		return ""
	var n := length_cm(id, size)
	if str(get_fish(id).get("size_unit", "cm")) == "talla":
		return "Talla %d" % n
	return "%d cm" % n


## El número de la talla (cm o número de calzado, según `size_unit`) de la
## horquilla propia del pez o la de su rareza.
static func length_cm(id: String, size: float) -> int:
	var l: Vector2i = get_fish(id).get("len",
		rarity_of(id).get("len", Vector2i(10, 50)))
	return int(roundf(lerpf(float(l.x), float(l.y), clampf(size, 0.0, 1.0))))


## Usos de despensa que entrega un pez-ingrediente (el salmón real da 10).
static func uses_of(id: String) -> int:
	return int(get_fish(id).get("uses", FISH_INGREDIENT_USES))


## Texto del premio para la ficha del álbum. Solo el RANGO: la letra pequeña
## de "según tamaño / desde la 2ª captura" sobraba, se entiende sola.
static func reward_text(id: String) -> String:
	var f := get_fish(id)
	if f.get("junk", false):
		return "%d doblón" % JUNK_COINS
	var c: Vector2i = rarity_of(id).get("coins", Vector2i.ZERO)
	var ing := str(f.get("ingredient", ""))
	if ing != "":
		var data: Dictionary = RecipeData.INGREDIENTS.get(ing, {})
		return "%d usos de %s  ·  %d–%d doblones" % [
			uses_of(id), str(data.get("name", ing)), c.x, c.y]
	return "%d–%d doblones" % [c.x, c.y]


## "1 vez" / "N veces": el plural a mano, que "1 veces" canta mucho.
static func times_text(n: int) -> String:
	return "1 vez" if n == 1 else "%d veces" % n


## Las monedas de un cofre: franja baja casi siempre, alta de vez en cuando.
static func roll_chest_coins() -> int:
	if randf() < CHEST_COINS_HIGH_CHANCE:
		return randi_range(CHEST_COINS_HIGH.x, CHEST_COINS_HIGH.y)
	return randi_range(CHEST_COINS_LOW.x, CHEST_COINS_LOW.y)


## Sorteo de UN pez por los pesos de rareza. El pez lapa (`no_catch`) no
## entra: solo aparece pegado a otros.
static func roll_fish() -> String:
	var total_w := 0
	for f in FISH:
		if f.get("no_catch", false):
			continue
		total_w += int(RARITIES[f["rarity"]]["weight"])
	var pick := randi() % total_w
	for f in FISH:
		if f.get("no_catch", false):
			continue
		pick -= int(RARITIES[f["rarity"]]["weight"])
		if pick < 0:
			return str(f["id"])
	return str(FISH[0]["id"])


## Sorteo de la CLASE de premio del cofre (la resolución vive en GameState).
static func roll_chest_kind() -> String:
	var total_w := 0
	for e in CHEST_TABLE:
		total_w += int(e["weight"])
	var pick := randi() % total_w
	for e in CHEST_TABLE:
		pick -= int(e["weight"])
		if pick < 0:
			return str(e["kind"])
	return "coins"


static func get_icon(id: String) -> Texture2D:
	var path := "res://assets/ui/fish_%s.png" % id
	if ResourceLoader.exists(path):
		return load(path)
	# Sin arte todavía: la moneda como comodín, igual que los coleccionables.
	return load("res://assets/ui/moneda.png")
