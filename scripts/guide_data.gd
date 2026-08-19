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
## guía miente, que es peor que no tenerla.

const SECTIONS: Array = [
	{
		"title": "La cinta",
		"icon": "res://assets/dishes/nigiri_salmon.webp",
		"body": "Los platos que preparas salen a la **cinta** y dan la vuelta al barco pasando por delante de cada silla.\n\nCada cliente decide si coge lo que le pasa por delante. El que está **más cerca de tu tabla** lo ve primero, así que un cliente pesado sentado al principio puede quedarse con lo que era para el de atrás.\n\nUn plato solo da **una vuelta**. Si nadie lo coge, cae al cubo de la esquina y te cuesta el **20%** de su precio. Servir de más no sale gratis.",
	},
	{
		"title": "La tabla",
		"icon": "res://assets/dishes/maki_aguacate.webp",
		"body": "Cada receta es una secuencia de gestos: tocar, amasar, arrastrar, deslizar, mantener, remover o cortar despacio.\n\nNunca cocinas a ciegas: la **mano** y el **cartel** de la tabla te cantan siempre el paso que toca. Puedes **cancelar** en cualquier momento.\n\nAl terminar una receta entra su **enfriamiento**: cuanto mejor es el plato, más tarda en volver a estar disponible.\n\nAlgunas recetas rinden **varios usos** (el **x2** del pergamino): la haces una vez y las siguientes salen ya hechas.",
	},
	{
		"title": "Las cajas",
		"icon": "res://assets/ui/cofre.png",
		"body": "Un plato terminado va a la cinta con un **toque**, y a una **caja** arrastrándolo hasta ella. Cada caja apila varios platos **iguales**.\n\nEn cuanto el plato sale de la tabla puedes empezar la receta siguiente: no hace falta esperar a que llegue.\n\nGuardar sirve para dos cosas: soltar **varios platos de golpe** cuando se te junta la clientela, y llegar a los clientes de más atrás en vez de solo al primero.\n\nDesde una caja se sirve **arrastrando** a la cinta. Y con la tabla **libre**, un toque en la caja devuelve el plato a la tabla: así puedes ponerle un **extra** antes de servirlo.\n\nLos platos guardados **conservan sus extras** — la caja enseña en miniatura los del plato de arriba.",
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
		"body": "A cada cliente le pierde la **variedad**: cada plato que prueba por **primera vez** alarga su racha —el **multiplicador** x2, x3, x4 de la chapa dorada junto a su bocadillo— y le recarga más paciencia que el anterior.\n\nY el multiplicador es ORO: cada plato nuevo paga su precio **más 1 doblón por punto** de la chapa. Con un x3 puesto, un nigiri de 4 deja 7.\n\nRepetirle un plato **rompe la racha**: la primera repetición recarga una miseria, la tercera nada, y de la cuarta en adelante hasta le **quita** paciencia.\n\nLos **extras** hacen que un plato repetido cuente como nuevo: no rompen la racha, la alargan (cada uno con su pega, ver Extras). El **té verde** limpia el paladar del todo: todos los platos vuelven a ser nuevos, pero el multiplicador empieza de cero.\n\nSi se marcha con un **postre**, deja 3 doblones de propina por cada punto del multiplicador.\n\nEl **bocadillo** sobre cada cliente enseña sus últimos platos, el más reciente arriba: de un vistazo sabes qué le rompería la racha.",
	},
	{
		"title": "Picoteo",
		"icon": "res://assets/dishes/edamame.webp",
		"body": "Los platos de **picoteo** (el edamame, el té verde) se pueden coger **sin soltar** el plato que se esté comiendo.\n\nNo interrumpen el bocado: lo **alargan**. Y como la paciencia no baja mientras se come, alargar el bocado es justo lo que retiene a un cliente en la silla.\n\nPagan un doblón extra. Repetir el mismo picoteo rinde cada vez menos, así que inundar la cinta de edamame no compensa.",
	},
	{
		"title": "Postres",
		"icon": "res://assets/dishes/mochi.webp",
		"body": "Los postres son la única forma de **echar a un cliente** sin esperar a que se le agote la paciencia: al terminarlo paga, deja propina segura y se marcha.\n\nY COBRAN la **variedad**: 3 doblones de propina por cada punto del multiplicador que tenga el cliente al irse. Un cliente bien variado despedido con dulce es la jugada redonda.\n\nCada postre es de su tipo: **mochi** para grumetes, **dorayaki** para piratas y **taiyaki** para capitanes. Nadie más los coge.\n\nUna silla libre es una silla que puedes volver a llenar, así que echar a alguien a tiempo suele rentar más que aguantarlo.",
	},
	{
		"title": "Extras",
		"icon": "res://assets/ui/ic_tienda.png",
		"body": "Los **extras** no son platos: se marcan sobre un plato **ya terminado**, justo antes de mandarlo a la cinta.\n\nLos **tres** hacen que ese plato cuente como **nuevo** aunque el cliente ya lo haya comido: alargan la racha y cobran el bono del multiplicador. Por eso cuestan **10 doblones** el uso... y por eso los tres tienen su pega.\n\n**Jengibre**: le limpia el **paladar entero** — a partir de ahí TODO le vuelve a saber a nuevo. A cambio, ese plato **baja** un punto el multiplicador.\n**Wasabi**: propina más **probable**. A cambio, en vez de recargarle paciencia, se la **quita**.\n**Soja**: propina más **gorda**. A cambio, mastica **más deprisa**, y mientras mastica es cuando no pierde paciencia.\n\nSe gastan por plato servido y se compran en la tienda.",
	},
	{
		"title": "Barco y combinados",
		"icon": "res://assets/dishes/moriawase.webp",
		"body": "Con **cuatro platos** guardados en las cajas, de al menos **dos clases distintas**, se enciende el botón del **barco**. Los arrastras a la bandeja y sale a la cinta como un solo plato.\n\nEl barco se paga por la **variedad**: cuantas más clases lleve, más prima. Y entretiene mucho al que lo coge, que mientras come no pierde paciencia.\n\nAdmite nigiris, gunkan y makis.\n\nLas **combinaciones** son otra cosa: parejas exactas de dos platos guardados que se funden en uno mejor.",
	},
	{
		"title": "Propinas",
		"icon": "res://assets/ui/ic_propina.png",
		"body": "Las propinas NO son dinero de plato: van al **bote**, la barra azul del marcador.\n\nCada vez que el bote se llena, el juego se para y la clientela te deja elegir entre tres **potenciadores** para esa partida: acelerar la cinta, cocinar sin esperas, sacar dos platos de golpe...\n\nSe aplican **solos** en cuanto los eliges, así que no hay nada que guardar ni que acordarse de gastar.",
	},
	{
		"title": "Dinero y estrellas",
		"icon": "res://assets/ui/moneda.png",
		"body": "El contador de arriba marca el **dinero base**: solo el precio de los platos. Cuando llega al objetivo, el turno se cierra ahí mismo.\n\nLas **estrellas**, en cambio, se miden con el dinero base **más las propinas**, que es lo que de verdad te llevas de la jornada. La barra va partida en tres tramos, uno por estrella.\n\nCon **2 estrellas** el nivel queda superado y se abre el siguiente. Las **3 estrellas** piden bastante más y tienen premio aparte.\n\nAl cerrar se pagan además las **primas**: por los clientes que ya no hizo falta atender y, en los abordajes, por el tiempo que sobró.",
	},
	{
		"title": "Tipos de nivel",
		"icon": "res://assets/ui/ic_aventura.png",
		"body": "**Islas** y **puertos** no llevan reloj: los acota la clientela. Acaban cuando se va el último cliente o cuando llegas al oro objetivo.\n\nEn las **islas** la carta la manda el diseño del nivel (no eliges recetas), y el cliente que se va **sin comer** te cuesta oro.\n\nEn los **puertos** la carta la eliges tú, pero si **3 clientes** se marchan sin probar bocado la jornada se **pierde**. A cambio, el vacío no cuesta oro.\n\nLos **abordajes** son **contra reloj** y la clientela no se acaba. Cada cliente que se vaya sin comer **resta 15 segundos** al reloj (y tampoco cuesta oro).\n\nLas **cuevas** son las guaridas de los **jefes**: juegan como un abordaje hasta que el jefe se sienta a la barra... y entonces manda él.",
	},
	{
		"title": "Arroz",
		"icon": "res://assets/ui/ic_arroz.png",
		"body": "El **arroz** es la energía del juego: cada jornada gasta **1 saco**, y sin sacos no se puede zarpar.\n\nSe repone solo: **1 saco cada hora y media** de tiempo real, hasta un máximo de **20**. El reloj corre aunque cierres el juego.\n\nSi sales de un nivel durante los segundos de **preparación**, el saco se te devuelve. Si sales con la partida en marcha, no.\n\nTambién se compran sacos con **lingotes de oro**.",
	},
	{
		"title": "La tienda",
		"icon": "res://assets/ui/bolsa.png",
		"body": "Saverio vende **usos** de ingredientes, y esto es lo importante: **un uso = una jornada**. Si llevas salmón a un puerto gastas un uso de salmón, hagas un nigiri o veinte.\n\nEl género cambia **cada día real**. También puedes pagar por renovar el surtido en el momento.\n\nEl arroz y el sésamo son gratis: no se compran ni se gastan.",
	},
	{
		"title": "Mejoras",
		"icon": "res://assets/ui/ic_inventario.png",
		"body": "Las **mejoras** son potenciadores permanentes, distintos de los del bote: se ganan haciendo un combo en partida y se eligen antes de zarpar.\n\n**Cocina veloz**: los enfriamientos duran la mitad toda la partida. Se gana cuando un mismo cliente te come 5 platos.\n**Ayudante**: aparece un botón que termina una receta él solo. Se gana sirviendo 18 platos en una partida.\n\nGastan un uso por partida, y se compran más usos con doblones desde el Inventario.",
	},
	{
		"title": "Nivel de cocinero",
		"icon": "res://assets/ui/ic_maestrias.png",
		"body": "Se gana **experiencia** de tres maneras: cerrando **escenarios** (más cuanto más alto el escenario y más estrellas saques, y el triple la primera vez que mejoras tu récord), aguantando **oleadas** en el Arcade y **pescando** — cada captura paga según el tamaño de la presa, y un pez **repetido** paga la mitad.\n\nSubir de nivel te da **1 punto de maestría** y **doblones**, más cuantos más niveles llevas y con un plus en los múltiplos de 5, 10 y 25.\n\nY además, cada pocos niveles cae algo de la bodega: un **cebo** (una tirada de pesca gratis), un **saco de arroz**, un **lingote**, **usos de despensa** o **usos de cada extra**. Cada uno lleva su propio ritmo, así que casi nunca coinciden dos en el mismo nivel. Ojo: cada cosa empieza a caer cuando ya la conoces — los extras no llegan antes de que Saverio te los enseñe.\n\nLos puntos se gastan en los tres árboles de **Maestrías**: el cuchillo (las manos), el cliente (la barra) y el chef (los platos). Se entra por la **barra de nivel** del menú.\n\nLos puntos se meten **de uno en uno**: una habilidad no se aprende hasta reunir los **5 puntos** de su primer rango (**10** en la habilidad final de cada árbol), y cada rango siguiente pide otros tantos. Las **estrellas** de cada icono son su rango; el **x/5** de debajo, los puntos que llevas metidos hacia el siguiente.\n\nPuedes **recolocar los puntos cuando quieras** con el botón rojo: se te devuelven de uno en uno. Solo se te avisa cuando el punto que sacas es el que sostiene la habilidad. Y si quieres replantear un árbol entero, abajo del todo tienes **Reiniciar maestría**: te devuelve de golpe todos los puntos que lleves puestos en él.\n\nCada escenario del mapa enseña su **cocinero recomendado**: si vas por debajo, repite escenarios anteriores a por más estrellas y experiencia.",
	},
	{
		"title": "El Arcade sin fin",
		"icon": "res://assets/ui/ic_arcade.png",
		"body": "Se abre al vencer al **Kappa**. Es un abordaje **sin fin** por oleadas de 45 segundos: empieza suave y aprieta cada vez más — la clientela sube de tono cada 5 oleadas y cada 10 cae un **estorbo** permanente.\n\nLa partida acaba cuando **3 clientes** se van sin probar bocado.\n\nCuesta un saco de arroz, y **cada oleada gasta 1 uso** de cada ingrediente de tu carta: al arcade se va con la despensa cargada. Si un ingrediente se agota, sus recetas se caen de la carta.\n\nCada 3 oleadas eliges una **mejora de partida** (fichar una receta, otra caja, el ayudante...). Al terminar cobras todo el oro generado y la experiencia de las oleadas superadas: cuanto más aguantes, mucho más paga.",
	},
]
