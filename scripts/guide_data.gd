class_name GuideData
extends RefCounted
## GUÍA DEL JUEGO: el texto de la pestaña "Guía" de Opciones, partido en
## secciones. Aquí SOLO hay datos; quien lo pinta es `options_screen.gd`.
##
## Va en su propio archivo por lo mismo que `achievement_data.gd`: es una lista
## que crece con cada mecánica nueva, y metida dentro de la pantalla se comería
## el script. Al añadir una mecánica, una entrada más en SECTIONS.
##
## Cada sección: `{ title, icon (opcional), body }`. El cuerpo va en párrafos
## separados por línea en blanco; las palabras clave, entre **asteriscos**, que
## la pantalla convierte en negrita teja (el mismo marcador que los diálogos).
##
## LAS CIFRAS QUE APARECEN AQUÍ SON LAS DE VERDAD (salen de las constantes del
## juego). Si se toca un número en el código, hay que tocarlo también aquí o la
## guía miente, que es peor que no tenerla. Rehecha entera el 2-9-2026 tras el
## repaso: la tienda hablaba de un surtido que ya no existe, "Mejoras" contaba
## dos bonificadores de cinco con cifras viejas, y faltaban nueve secciones.

const SECTIONS: Array = [
	{
		"title": "La cinta",
		"icon": "res://assets/dishes/nigiri_salmon.webp",
		"body": "Los platos que preparas salen a la **cinta** y dan la vuelta al barco pasando por delante de cada silla.\n\nCada cliente decide si coge lo que le pasa por delante. El que está **más cerca de tu tabla** lo ve primero, así que un cliente pesado sentado al principio puede quedarse con lo que era para el de atrás.\n\nEn el primer mar un plato aguanta **dos vueltas**; a partir del segundo, **una**. Si nadie lo coge, cae al cubo de la esquina y te cuesta el **20%** de su precio. Servir de más no sale gratis.",
	},
	{
		"title": "La tabla",
		"icon": "res://assets/dishes/maki_aguacate.webp",
		"body": "Cada receta es una secuencia de gestos: tocar, amasar, arrastrar, deslizar, mantener, remover o cortar despacio.\n\nNunca cocinas a ciegas: la **mano** y el **cartel** de la tabla te cantan siempre el paso que toca. Puedes **cancelar** en cualquier momento.\n\nAl terminar una receta entra su **enfriamiento**: cuanto mejor es el plato, más tarda en volver a estar disponible.\n\nAlgunas recetas dan **usos extra** (el **x2** del pergamino): la haces una vez y las siguientes salen ya hechas.",
	},
	{
		"title": "Las cajas",
		"icon": "res://assets/ui/cofre.png",
		"body": "Un plato terminado va a la cinta con un **toque**, y a una **caja** arrastrándolo hasta ella. Cada caja apila varios platos **iguales**.\n\nEn cuanto el plato sale de la tabla puedes empezar la receta siguiente: no hace falta esperar a que llegue.\n\nGuardar sirve para dos cosas: soltar **varios platos de golpe** cuando se te junta la clientela, y llegar a los clientes de más atrás en vez de solo al primero.\n\nDesde una caja se sirve **arrastrando** a la cinta. Y con la tabla **libre**, un toque en la caja devuelve el plato a la tabla: así puedes ponerle un **extra** antes de servirlo.\n\nLos platos guardados **conservan sus extras** y su precio (una tempura clavada sale de la caja a lo que valía) — la caja enseña en miniatura los extras del plato de arriba.",
	},
	{
		"title": "Los clientes",
		"icon": "res://assets/ui/head_E.png",
		"body": "Hay tres tipos: **grumete**, **pirata** y **capitán**. Cada uno tiene su nivel de plato favorito —1, 2 y 3 estrellas— y va bajando el interés hacia los otros dos.\n\nCuanto más importante es el cliente, **más paga** y menos tarda en comer.\n\nAprovecha el rato en que uno mastica para adelantar el plato del siguiente. Ahí está el oficio.",
	},
	{
		"title": "Paciencia y bocado",
		"icon": "res://assets/ui/reloj.png",
		"body": "Cada cliente sentado tiene dos barras.\n\nLa de **paciencia** baja sola cuando NO está comiendo, y cambia de color según lo que le quede: **verde**, **ámbar** y **roja**. Si llega al fondo se levanta y se va.\n\nLa **azul** es su **bocado**: lo que le queda del plato que tiene entre manos. Mientras baja no coge nada más de la cinta... y su paciencia tampoco cae. Un plato que se come despacio es tiempo regalado.\n\nCada plato le rellena la paciencia, y cuanto mejor es el plato, más se la llena.",
	},
	{
		"title": "Variedad y hastío",
		"icon": "res://assets/dishes/te_verde.webp",
		"body": "A cada cliente le pierde la **variedad**: cada plato que prueba por **primera vez** alarga su racha —el **multiplicador** x2, x3, x4 de la chapa dorada junto a su bocadillo— y le recarga más paciencia que el anterior (hasta el **x5**: de ahí para arriba la chapa sigue subiendo, pero la recarga ya no).\n\nY el multiplicador es ORO: cada plato nuevo paga su precio **más 1 doblón por punto** de la chapa. Con un x3 puesto, un nigiri de 4 deja 7.\n\nRepetirle un plato **rompe la racha**: la primera repetición recarga una miseria y de la segunda en adelante le **quita** paciencia... y encima se lo come más deprisa, así que vuelve a pedir antes.\n\nLos **extras** hacen que un plato repetido cuente como nuevo: no rompen la racha, la alargan (cada uno con su pega, ver Extras). El **té verde** limpia el paladar del todo —todos los platos vuelven a ser nuevos— y la chapa **se queda como está**; a cambio, la hoja de té es cara y tarda en volver a la tabla.\n\nSi se marcha con un **postre**, deja 3 doblones de propina por cada punto del multiplicador.\n\nEl **bocadillo** que cuelga bajo cada cliente enseña sus últimos platos, el más reciente a la derecha: de un vistazo sabes qué le rompería la racha.",
	},
	{
		"title": "Picoteo",
		"icon": "res://assets/dishes/edamame.webp",
		"body": "Los platos de **picoteo** (el edamame, el té verde...) se pueden coger **sin soltar** el plato que se esté comiendo — uno por bocado.\n\nNo interrumpen el bocado: lo **alargan**. Y como la paciencia no baja mientras se come, alargar el bocado es justo lo que retiene a un cliente en la silla. Cada picoteo alarga lo suyo: la **ensalada de wakame** un 50%, el edamame un 35%, el **tsukemono** nada (lo suyo es limpiar el paladar y subir un punto de multiplicador, la primera vez que ese cliente lo prueba).\n\nEl **edamame** paga 3 doblones picoteado y solo 1 comido como plato suelto: su sitio es acompañar. Y el **bol de arroz** no gasta el turno de picoteo — entra ADEMÁS del picoteo normal, en cualquier orden.\n\nRepetir el mismo picoteo rinde cada vez menos, así que inundar la cinta de edamame no compensa.",
	},
	{
		"title": "Maridaje",
		"icon": "res://assets/dishes/mochi.webp",
		"body": "Algunos platos **maridan**: servidos justo después de otro concreto pagan un **bono** de doblones (el mochi detrás del té verde, el tataki detrás de un caldo...).\n\nLo que cuenta es **lo último que ese cliente ha comido**, picoteos incluidos. La ficha de cada receta dice con qué marida y cuánto paga.",
	},
	{
		"title": "Coronar platos",
		"icon": "res://assets/dishes/maki_aguacate_mejorado.webp",
		"body": "Algunas recetas tienen una **versión mejorada** que se gana en la aventura (el premio de 3 estrellas de ciertos escenarios).\n\nCon la corona ganada, al terminar el plato aparecen sus **ingredientes de coronación** junto a la tabla: échaselos y el plato se **transforma** — más precio, su propia mecánica (frescura, marinado, maridaje...) y, para el paladar, cuenta como un plato **distinto** de su base.\n\nSi una corona te llega antes que su receta base, se queda esperando: sin la base no hay nada que coronar.\n\nLos ingredientes de coronar se compran donde Saverio y se gastan **por plato coronado**. El enfriamiento sigue siendo el de la receta base.\n\nLa ficha de cada receta en el recetario enseña su versión mejorada y lo que hace.",
	},
	{
		"title": "Fama y otras mañas",
		"icon": "res://assets/dishes/nigiri_salmon.webp",
		"body": "Cada receta tiene su papel, y la ficha lo canta en cifras. Algunas:\n\n**Fama**: cada plato de esa receta que sirvas en la jornada sube la probabilidad de que un cliente lo coja, hasta un tope. Premia servir mucho de lo mismo repartido entre bocas.\n**Frescura** y **marinado**: el precio viaja con la cinta — el fresco vale más recién servido y el marinado cuanto más reposa.\n**Contagio** y **olor**: lo que come uno afecta a la mesa entera (paciencia) o a sus dos vecinos (multiplicador).\n**Talla**: paga más cuanto mayor es tu **récord de pesca** de esa especie, hasta el doble.\n**Riesgo**: quien lo deja pasar pierde paciencia; quien lo coge la rellena entera.\n**Plato compartido**: da para dos clientes y se queda en la cinta tras el primero.",
	},
	{
		"title": "Postres",
		"icon": "res://assets/dishes/mochi.webp",
		"body": "Los postres son la única forma de **echar a un cliente** sin esperar a que se le agote la paciencia: al terminarlo paga, deja propina segura y se marcha.\n\nY COBRAN la **variedad**: 3 doblones de propina por cada punto del multiplicador que tenga el cliente al irse. Un cliente bien variado despedido con dulce es la jugada redonda.\n\nCada postre es de su tipo: **mochi** para grumetes, **dorayaki** para piratas y **taiyaki** para capitanes. Nadie más los coge.\n\nUna silla libre es una silla que puedes volver a llenar, así que echar a alguien a tiempo suele rentar más que aguantarlo.",
	},
	{
		"title": "Extras",
		"icon": "res://assets/ui/ic_tienda.png",
		"body": "Los **extras** no son platos: se marcan sobre un plato **ya terminado**, justo antes de mandarlo a la cinta.\n\nLos **tres** hacen que ese plato cuente como **nuevo** aunque el cliente ya lo haya comido: alargan la racha y cobran el bono del multiplicador. Por eso cuestan **6 doblones** el uso, se gastan por plato servido... y por eso los tres tienen su pega. En oro puro no salen a cuenta: lo que compran es la racha y la paciencia.\n\n**Jengibre**: le limpia el **paladar entero** — a partir de ahí TODO le vuelve a saber a nuevo. Si el plato venía repetido, le **baja** un punto el multiplicador; si era nuevo, no.\n**Wasabi**: propina más **probable**. A cambio, en vez de recargarle paciencia, se la **quita**.\n**Soja**: propina más **gorda**. A cambio, mastica **más deprisa**, y mientras mastica es cuando no pierde paciencia.\n\nSe compran en la tienda, y Saverio los presenta de uno en uno a lo largo del primer mar.",
	},
	{
		"title": "Barco y combinados",
		"icon": "res://assets/dishes/moriawase.webp",
		"body": "El **barco** es una bandeja que junta **cuatro platos** guardados en las cajas, de al menos **dos clases distintas**, y sale a la cinta como un solo plato. Hace falta el bonificador **Barco de sushi** y que el escenario lo permita: sin las dos cosas, su botón no aparece.\n\nEl barco se paga por la **variedad** (cuantas más clases, más prima) y por el número de platos, y entretiene mucho al que lo coge, que mientras come no pierde paciencia.\n\nAdmite nigiris, gunkan y makis.\n\nLas **combinaciones** —parejas exactas de dos platos que se funden en uno mejor— son una mecánica que llegará más adelante en la travesía.",
	},
	{
		"title": "Propinas",
		"icon": "res://assets/ui/ic_propina.png",
		"body": "Las propinas NO son dinero de plato: van al **bote**, la barra azul del marcador.\n\nCada vez que el bote se llena, el juego se para y la clientela te deja elegir entre tres **potenciadores** para esa partida: acelerar la cinta, cocinar sin esperas, sacar dos platos de golpe, confundir el olfato de la barra...\n\nSe aplican **solos** en cuanto los eliges, así que no hay nada que guardar ni que acordarse de gastar. Los que ya están en marcha no vuelven a salir en el sorteo.",
	},
	{
		"title": "Sushi Rush",
		"icon": "res://assets/ui/pot_instantanea.png",
		"body": "Se aprende en el segundo mar, de Miku. Encadena **10 platos entregados sin fallo** —sin repetirle plato a nadie, sin cubo, sin corte fallado— y entra el **rush**: los platos se montan **al instante** y los enfriamientos se acortan mucho, hasta el primer fallo.\n\nLos picoteos, los postres y un plato con extra cuentan a favor de la cadena; el repetido de verdad la rompe.",
	},
	{
		"title": "Dinero y estrellas",
		"icon": "res://assets/ui/moneda.png",
		"body": "El contador de arriba marca el **dinero base**: solo el precio de los platos. Cuando llega al objetivo, el turno se cierra ahí mismo.\n\nLas **estrellas**, en cambio, se miden con el dinero base **más las propinas**, que es lo que de verdad te llevas de la jornada. La barra va partida en tres tramos, uno por estrella.\n\nCon **2 estrellas** el nivel queda superado y se abre el siguiente. Las **3 estrellas** piden bastante más y tienen premio aparte.\n\nAl cerrar se pagan además las **primas**: por los clientes que ya no hizo falta atender y, en los abordajes, por el tiempo que sobró.",
	},
	{
		"title": "Tipos de escenario",
		"icon": "res://assets/ui/ic_aventura.png",
		"body": "**Islas** y **puertos** no llevan reloj: los acota la clientela. Acaban cuando se va el último cliente o cuando llegas al oro objetivo.\n\nEn las **islas** la carta la manda el diseño del escenario (no eliges recetas; si te falta alguna, se juega igual con una menos). En los **puertos** la carta la eliges tú. Los **abordajes** son **contra reloj** y la clientela no se acaba.\n\n**A partir del MAR 2** la clientela se vuelve exigente y el que se va **sin probar bocado** castiga según el tipo: en la isla cuesta **oro**, en el puerto enciende una de las **3 calaveras** (a la tercera se pierde la jornada) y en el abordaje **resta 15 segundos** al reloj. En el mar 1 no hay castigo: es la escuela.\n\n**A partir del MAR 3** cada tipo aprieta además por su lado: en la **isla** la cinta tiene **tope de platos** (con la cinta llena hay que esperar para servir), en el **puerto** no puedes preparar **dos recetas iguales seguidas** (la que acabas de hacer se bloquea hasta que hagas otra) y en el **abordaje** la cinta va al **doble de rápido**.\n\nLas **cuevas** son las guaridas de los **jefes**: juegan como un abordaje hasta que el jefe se sienta a la barra... y entonces manda él.",
	},
	{
		"title": "El canto de sirena",
		"icon": "res://assets/ui/head_SI.png",
		"body": "En el **Mar de las Sirenas** (el mar 2), a ratos suena un **canto** que sale del agua. Mientras dura, el cliente que **espera** se atonta: mira al mar, **no coge ni un plato** y su paciencia sigue bajando.\n\nEl que está **comiendo** se libra: la comida puede más que el canto. Antes de cada canto suena un aviso — es el momento de poner un plato en cada boca, y de guardar en las **cajas** lo que no puedas servir.\n\nA un cliente atontado se le despierta **tocándolo**: vuelve en sí hasta que acabe ese canto.\n\nLos platos que pasan de largo delante de un atontado **no se pierden**: cuando despierta, puede cogerlos en la siguiente vuelta.\n\nEl canto aprieta según el tipo de escenario: suave en las **islas**, medio en los **puertos** y fuerte en los **abordajes**. Y hay un tesoro que lo acorta: los **tapones de cera**.",
	},
	{
		"title": "Arroz",
		"icon": "res://assets/ui/ic_arroz.png",
		"body": "El **arroz** es la energía del juego: cada jornada gasta **1 saco**, y sin sacos no se puede zarpar (ni repetir un escenario).\n\nSe repone solo: **1 saco cada hora y media** de tiempo real, hasta un máximo de **20**. El reloj corre aunque cierres el juego.\n\nSi sales de un nivel durante los segundos de **preparación**, el saco se te devuelve. Si sales con la partida en marcha, no.\n\nTambién se compran sacos con **lingotes de oro**: el pack de cinco es el que mejor sale por saco.",
	},
	{
		"title": "La tienda",
		"icon": "res://assets/ui/bolsa.png",
		"body": "Saverio vende **usos** de ingredientes, y esto es lo importante: **un uso = una jornada**. Si llevas salmón a un puerto gastas un uso de salmón, hagas un nigiri o veinte.\n\nTiene **todo el género** que tus recetas piden, siempre, ordenado por lo que te falta. El puesto abre al superar el **Arrecife del Ron** (escenario 8).\n\nCada receta nueva llega con **unos usos de regalo** de sus ingredientes; el resto se compra. Solo el **arroz** es gratis: la sal y el sésamo se compran como todo lo demás.",
	},
	{
		"title": "Bonificadores",
		"icon": "res://assets/ui/ic_perks.png",
		"body": "Los **bonificadores** son ventajas permanentes, distintas de los potenciadores del bote: se **ganan** haciendo algo concreto en una jornada, se **eligen antes de zarpar** junto a la carta y cada jornada gasta **un uso**. Cada vez que repites su hazaña te llevas otro uso; el sistema entero llega con **Alice**, en la Rada de los Dos Fuegos (escenario 31).\n\n**Ayudante de cocina**: Alice termina ella sola la receta que acabas de empezar, y descansa entre plato y plato (de 60 a 30 s según su nivel). Se gana dando 4 platos a 4 clientes distintos.\n**Cocina veloz**: los enfriamientos quedan al 60% (al 40% en su nivel 5). Se gana cuando un mismo cliente te come 5 platos.\n**Paladar de capitán**: el tope del multiplicador sube de x5 a x6 (x10 al máximo). Se gana llevando a un cliente al x5.\n**Cuaderno de bitácora**: un 25% más de experiencia por escenario (65% al máximo). Se gana cerrando un escenario con un 20% más de oro del que piden sus 3 estrellas, propinas y primas incluidas.\n**Barco de sushi**: habilita el barco combinado (ver Barco). Llega en el segundo mar.\n\nEn la pantalla de **Bonificadores** del mapa se **mejoran de nivel con doblones** (cinco niveles) y se compran usos sueltos con **lingotes**.",
	},
	{
		"title": "Nivel de cocinero",
		"icon": "res://assets/ui/ic_maestrias.png",
		"body": "Se gana **experiencia** cerrando **escenarios** (más cuanto más alto el escenario y más estrellas saques, y el triple la primera vez que mejoras tu récord), **pescando** (cada captura paga según el tamaño de la presa, y un pez repetido paga la mitad), cumpliendo **mapas del tesoro**, encontrando **coleccionables** y con el bonificador **Cuaderno de bitácora**.\n\nSubir de nivel te da **1 punto de maestría** y **doblones**, más cuantos más niveles llevas y con un plus en los múltiplos de 5, 10 y 25.\n\nY además, cada pocos niveles cae algo de la bodega: un **cebo** (una tirada de pesca gratis), un **saco de arroz**, un **lingote**, **usos de despensa** o **usos de cada extra**. Cada uno lleva su propio ritmo, así que casi nunca coinciden dos en el mismo nivel. Ojo: cada cosa empieza a caer cuando ya la conoces — los extras no llegan antes de que Saverio te los enseñe.\n\nLos puntos se gastan en los tres árboles de **Maestrías**: el cuchillo (las manos), el cliente (la barra) y el chef (los platos). Se entra por la **barra de nivel** del menú.\n\nLos puntos se meten **de uno en uno**: una habilidad no se aprende hasta reunir los **5 puntos** de su primer rango (**10** en la habilidad final de cada árbol), y cada rango siguiente pide otros tantos. Las **estrellas** de cada icono son su rango; los puntitos de debajo, los puntos que llevas metidos hacia el siguiente.\n\nPuedes **recolocar los puntos cuando quieras** con el botón rojo: se te devuelven de uno en uno. Se te pregunta antes de perder una habilidad, y el único punto que no se puede sacar es el que sostiene a otra ya aprendida. Y si quieres replantear un árbol entero, abajo del todo tienes **Reiniciar maestría**: te devuelve de golpe todos los puntos que lleves puestos en él.\n\nCada escenario del mapa enseña su **cocinero recomendado**: si vas por debajo, repite escenarios anteriores a por más estrellas y experiencia.",
	},
	{
		"title": "La pesca",
		"icon": "res://assets/ui/ic_pesca.png",
		"body": "Se abre al superar la **Isla de Gades** (escenario 21), donde **Cai** se enrola y da la clase. Cada tirada cuesta **100 doblones** (o un **cebo**, si tienes).\n\nLa sombra del pez nada bajo el barco: se toca el agua para lanzar, se espera la **picada** de verdad (las **fintas** engañan) y se pelea con la caña: mantener recoge y tensa el sedal, soltar lo afloja y deja recuperar al pez. En los **tirones** se pulsa rápido, no se mantiene.\n\nCada especie va al **álbum** con su récord de talla. La **primera captura** de una especie paga **doble**, y todas pagan por tamaño y rareza: un legendario deja entre 250 y 400 doblones, también repetido. Los peces-ingrediente rellenan además tu despensa.\n\nUn **30%** de las tiradas saca un **cofre**: doblones (150-250), un coleccionable, un mapa del tesoro, un fragmento de la Tripuerca o una receta.",
	},
	{
		"title": "Bonus diario",
		"icon": "res://assets/ui/daily_cofre.png",
		"body": "Cada día que entras te espera un **cofre** en el menú: siete cofres seguidos, cada uno mejor que el anterior. La racha sube si el último lo cobraste **ayer**; si dejas pasar un día, vuelve al primero. Pasado el séptimo, empieza otra vuelta.\n\nDan doblones (más cuanto más alto tu nivel de cocinero), sacos, cebos, usos de extras y de despensa, lingotes y mapas del tesoro — cada cosa solo cuando el juego ya te la ha presentado. El **séptimo** trae el **dragon roll**, la única receta que no se gana en la travesía.\n\nTocando un cofre ya cobrado se ve qué te dio.",
	},
	{
		"title": "Mapas del tesoro",
		"icon": "res://assets/ui/col_mapa_tesoro.png",
		"body": "Un mapa del tesoro es un **encargo aparte** de la travesía: un objetivo concreto —llevar a alguien al x5, encadenar maridajes, cerrar sin tirar nada— con su recompensa propia. Los hay **fáciles**, **medios** y **difíciles**, y cuanto más difícil, más pagan: oro, experiencia y a veces sacos, cebos, lingotes o una pieza para la vitrina.\n\nSe abren en el tablón de **Mapas** del mapa de la travesía, y se lleva **uno armado** cada vez. Los entrega el grumete de la Caleta del Cartógrafo (escenario 28), los cofres de la pesca y el bonus diario.",
	},
	{
		"title": "Colección y logros",
		"icon": "res://assets/ui/ic_logros.png",
		"body": "Los **coleccionables** no dan oro ni sirven para cocinar: se tienen. Van a la vitrina de la **Colección**, con su historia y de dónde salieron. Los hay por encargo de un cliente, por vencer a un jefe, por pescar, por mapas del tesoro y por hazañas de cocina; y algunos se lucen en el barco.\n\nLos **logros** llevan tres medallas cada uno (bronce, plata y oro) y pagan doblones al reclamarlos — más cuanto más alto tu nivel de cocinero el día que los ganas. Se cobran desde su pantalla, uno a uno o todos de golpe.",
	},
	{
		"title": "El Arcade sin fin",
		"icon": "res://assets/ui/ic_arcade.png",
		"body": "Se abre al vencer al **Kappa** (escenario 35). Es un abordaje **sin fin** por oleadas de 45 segundos: empieza suave y aprieta cada vez más — la clientela sube de tono cada 5 oleadas y cada 10 cae un **estorbo** permanente.\n\nLa partida acaba cuando **3 clientes** se van sin probar bocado.\n\nCuesta un saco de arroz, y **cada oleada gasta 1 uso** de cada ingrediente de tu carta: al arcade se va con la despensa cargada. Si un ingrediente se agota, sus recetas se caen de la carta.\n\nCada 3 oleadas eliges una **mejora de partida** (fichar una receta, otra caja, el ayudante...). Al terminar cobras todo el oro generado y la experiencia de las oleadas superadas.",
	},
]
