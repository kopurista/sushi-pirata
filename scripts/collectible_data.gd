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
## · Los TROFEOS (cuchillo del maestro, galón de oro) se ganan COCINANDO, con
##   su hazaña — son la vía de "aventura y arcade" ya estrenada.
##
## EL CORAZÓN EN UN COFRECITO TIENE ESCENA: al salir del mar deja
## `GameState.pending_corazon`, y David reacciona al cerrar la pesca
## (`main_menu._reaccion_corazon`). Se cuenta ALLÍ y no aquí porque la ventana
## del coleccionable la saca NoticeLayer en su capa global, donde no cabe un
## diálogo con retrato.
##
## El TRIÁNGULO DORADO es especial: son TRIFORCE_PIECES fragmentos que se
## juntan en UN solo coleccionable; al completarlo se regalan
## TRIFORCE_REWARD doblones (`GameState.add_triforce_piece`).

const TRIFORCE_PIECES := 8
const TRIFORCE_REWARD := 3

## TROFEOS POR HAZAÑA: los dos coleccionables que no se pescan ni se regalan,
## sino que se ganan cocinando. Los vigila `GameState._run_achievement_check`
## y los umbrales viven AQUÍ para que la ficha no pueda contradecirlos.
const CUCHILLO_CORTES := 200
const GALON_OLEADA := 20
const DELANTAL_TIRADOS := 100
## LOS CUATRO DE QUEDARSE SIN NADA (pedidos por el usuario): recuerdos de las
## malas rachas. No se ganan HACIENDO algo, sino tocando fondo — y por eso son
## los únicos que salen de mirar el monedero y la despensa (ver
## `GameState._sin_nada`). El de las monedas no pide cero: con menos de
## MONEDERO_MINIMO ya no da ni para un uso de género.
const MONEDERO_MINIMO := 25
const CAMPANA_PROPINA := 30
## LOS PALILLOS son un ESCALÓN, no tres premios sueltos: el mismo objeto en
## madera, plata y oro según los platos servidos de toda la vida (la stat
## `dishes_made`, que NO cuenta los del ayudante). Los tres van en el mismo
## orden que `PALILLOS_PLATOS`.
const PALILLOS_IDS := ["palillos_madera", "palillos_plata", "palillos_oro"]
const PALILLOS_PLATOS := [300, 2000, 8000]
## La PIEDRA DE AFILAR es el escalón siguiente del cuchillo del maestro: se
## gasta de tanto afilarlo, así que cuelga de los mismos cortes lentos.
const PIEDRA_CORTES := 1000
## El DORAYAKI MORDIDO llega tras hacer unos cuantos: es el postre de la
## casa y el guino se gana cocinandolo, no pescandolo.
const DORAYAKI_PLATOS := 100
## El ANZUELO MAGICO se gana pescando: es el premio del que ya vive de la
## cana. La ESMERALDA la trae la rana caotica del album (`ESMERALDA_PEZ`),
## que es la unica pieza que cuelga de pescar UNA especie concreta.
const ANZUELO_PECES := 200
const ESMERALDA_PEZ := "froggy"
## El COFRE lo trae el pez cofre del álbum (mismo mecanismo que la esmeralda).
const COFRE_PEZ := "pez_cofre"
## El TIMÓN se gana reuniendo estrellas por la campaña (pedido por el
## usuario; antes eran 5 vueltas al timón, que ahora no existe hasta tenerlo).
const TIMON_ESTRELLAS := 48
## Efecto de los TAPONES DE CERA: cada canto de sirena dura este factor.
const TAPONES_CANTO := 0.65

## UN TROFEO POR JEFE DE MAR. La campana son 7 mares y cada uno cierra con
## el suyo; al rendirse deja su pieza. La stat la apunta
## `level3d._finalize_results` como "boss_<id>" con el id del propio jefe
## (el `boss` del puerto), asi que un jefe nuevo solo tiene que anadir su
## linea aqui: el coleccionable cae solo. Hoy unicamente existe el Kappa.
const BOSS_ITEMS := {
	"kappa": "diente_kappa",
	"sirena": "lagrima_sirena",
	"esqueleto": "diente_oro",
	"fantasma": "frasco_bruma",
	"cthulhu": "tomo_prohibido",
	"umibozu": "cucharon_sin_fondo",
	"shachihoko": "figura_shachihoko",
}

## COLECCIONABLES CON ESCENA: al conseguirlos dejan su id en
## `GameState.pending_col_scenes` y alguien la representa después (hoy
## `main_menu`, al cerrar la pesca). Son los que tienen algo que decir: el
## corazón lleva el apellido de David y el tenedor le da pie a su chiste.
const SCENE_ITEMS := ["corazon_cofre", "tenedor", "tricornio"]

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
		"desc": "Reúne 48 estrellas por la campaña. Desde entonces corona el tablón del menú: gíralo y girará el barco.",
		"icon": "res://assets/ui/timon.png",
	},
	{
		"id": "bandera", "name": "Bandera pirata",
		"desc": "Regalo de un pirata del Paso de las Barracudas, por darle bien de comer.",
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
	{ "id": "panuelo", "name": "Pañuelo pirata",
		"desc": "El pañuelo que David se ata a la cabeza cuando aprieta el trabajo. Estaba pagado en un mapa." },
	{ "id": "garfio", "name": "Garfio",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "parche", "name": "Parche pirata", "desc": "" },
	{ "id": "canon", "name": "Cañón pirata",
		"desc": "Un cañón de cubierta con su cureña, sacado a pulso de una bodega inundada." },
	{ "id": "bala_canon", "name": "Bala de cañón",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "ancla", "name": "Ancla",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "pistola", "name": "Pistola pirata", "desc": "" },
	{ "id": "espada", "name": "Espada pirata", "desc": "" },
	{ "id": "brujula", "name": "Brújula",
		"desc": "Salió de un cofre pescado en alta mar." },
	{
		"id": "cofre", "name": "Cofre del tesoro",
		"desc": "Lo trajo el pez cofre: un pez con forma de caja fuerte que ni el mar sabía abrir.",
		"icon": "res://assets/ui/daily_cofre.png",
	},
	{ "id": "pluma_loro", "name": "Pluma de loro",
		"desc": "Una pluma verde de Gigi. Se le cayó protestando, que es como se le cae todo." },
	{ "id": "pluma_escribir", "name": "Pluma de escribir",
		"desc": "Pluma de escribir con el cañón partido. Con ella se firmó más de un trato malo." },
	{ "id": "barril", "name": "Barril",
		"desc": "Dragado del fondo del mar en un cofre. Suena a vacío; huele a ron." },
	{ "id": "saco_cafe", "name": "Saco de café",
		"desc": "Un saco de café de las colonias, todavía con su olor dentro." },
	{ "id": "botella_mensaje", "name": "Botella con mensaje",
		"desc": "Salió de un cofre pescado en alta mar. El mensaje sigue enrollado." },
	{ "id": "farol_aceite", "name": "Farol de aceite",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "astrolabio_roto", "name": "Astrolabio roto",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "bitacora_roto", "name": "Cuaderno de bitácora roto",
		"desc": "Salió de un cofre pescado en alta mar. No queda nada legible." },
	{ "id": "dado_hueso", "name": "Dados de hueso",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "baraja_marcada", "name": "Baraja marcada",
		"desc": "Salió de un cofre pescado en alta mar. Alguien hizo trampas." },
	{ "id": "cuerno_narval", "name": "Cuerno de narval",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "fosil_amonites", "name": "Fósil de amonites",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "estrella_mar_seca", "name": "Estrella de mar seca",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "espejo_mano", "name": "Espejo de mano oxidado",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "cascabel_gato", "name": "Cascabel del gato del barco",
		"desc": "Salió de un cofre pescado en alta mar. Suena a bordo perdido." },
	{ "id": "bota_vino", "name": "Bota de vino",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "tentaculo", "name": "Tentáculo de kraken",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "hueso", "name": "Hueso",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "calavera", "name": "Calavera",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "pata_palo", "name": "Pata de palo",
		"desc": "Salió de un cofre pescado en alta mar." },
	# --- La cocina del barco y sus trofeos ---------------------------------------
	{ "id": "maneki_neko", "name": "Maneki-neko roto",
		"desc": "Roto y pegado a mano. Salió de un cofre pescado en alta mar." },
	# El dibujo trae los DOS ojos pintados (el generador no hace la asimetría
	# del daruma a medias), así que la ficha lo cuenta: un daruma con los dos
	# ojos pintados es un deseo ya cumplido.
	{ "id": "daruma", "name": "Daruma",
		"desc": "Tiene los dos ojos pintados: alguien cumplió su deseo." },
	{ "id": "botella_sake", "name": "Botella de sake", "desc": "" },
	{ "id": "escama_sirena", "name": "Escama de sirena", "desc": "" },
	{ "id": "rallador_tiburon", "name": "Rallador de piel de tiburon",
		"desc": "" },
	{ "id": "sandalias_geta", "name": "Sandalias geta sucias", "desc": "" },
	{ "id": "koinobori", "name": "Koinobori", "desc": "" },
	{ "id": "omamori", "name": "Omamori", "desc": "" },
	{ "id": "cuchillo_maestro", "name": "Cuchillo del maestro",
		"desc": "Por bordar %d cortes lentos sin pasarte de rápido."
			% CUCHILLO_CORTES },
	{ "id": "piedra_afilar", "name": "Piedra de afilar gastada",
		"desc": "Hundida por el medio de afilar ese cuchillo %d veces."
			% PIEDRA_CORTES },
	{ "id": "plato_quemado", "name": "Plato quemado",
		"desc": "El primero que se te fue al cubo. Se guarda para no repetirlo." },
	{ "id": "dorayaki_mordisco", "name": "Dorayaki con un mordisco",
		"desc": "Por preparar %d dorayakis. Este te lo has ganado."
			% DORAYAKI_PLATOS },
	{ "id": "recetario", "name": "Recetario completo",
		"desc": "Por aprender TODAS las recetas del juego." },
	{ "id": "galon_oro", "name": "Galón de oro",
		"desc": "Por aguantar hasta la oleada %d del Arcade." % GALON_OLEADA },
	{ "id": "delantal_chamuscado", "name": "Delantal chamuscado",
		"desc": "Por tirar %d platos al cubo. No es un mérito, pero es tuyo."
			% DELANTAL_TIRADOS },
	{ "id": "campana_servicio", "name": "Campana del último servicio",
		"desc": "Por cerrar una jornada con %d doblones de propina."
			% CAMPANA_PROPINA },
	{ "id": "palillos_madera", "name": "Palillos de madera",
		"desc": "Por servir tus primeros %d platos." % PALILLOS_PLATOS[0] },
	{ "id": "palillos_plata", "name": "Palillos de plata",
		"desc": "Por servir %d platos. La mano ya no tiembla."
			% PALILLOS_PLATOS[1] },
	{ "id": "palillos_oro", "name": "Palillos de oro",
		"desc": "Por servir %d platos. Esto ya es un oficio."
			% PALILLOS_PLATOS[2] },
	# --- Los cuatro de TOCAR FONDO (ver GameState._sin_nada) ---------------------
	{ "id": "saco_vacio", "name": "Saco de arroz vacío",
		"desc": "El día que se acabó el arroz. No se navega con la bodega así." },
	{ "id": "lingote_roto", "name": "Lingote roto",
		"desc": "Lo que queda cuando se gasta hasta el último lingote." },
	{ "id": "monedero_roto", "name": "Saco de monedas roto",
		"desc": "Con lo que había dentro no llegaba ni para un puñado de arroz." },
	{ "id": "soja_vacia", "name": "Botella de soja vacía",
		"desc": "Ni una gota. Ese servicio se sirvió soso." },
	# --- Trofeos de los JEFES DE MAR (uno por mar; ver BOSS_ITEMS) ---------------
	{ "id": "diente_kappa", "name": "Diente de Kappa",
		"desc": "Se le cayó al Kappa cuando por fin se dio por servido." },
	{ "id": "lagrima_sirena", "name": "Lágrima de sirena",
		"desc": "Lo único que dejó la sirena al darse por servida." },
	{ "id": "diente_oro", "name": "Diente de oro",
		"desc": "Se le cayó al pirata esquelético de tanto masticar." },
	{ "id": "frasco_bruma", "name": "Frasco de bruma",
		"desc": "Un poco del pirata fantasma, atrapado en un frasco." },
	{ "id": "tomo_prohibido", "name": "Tomo prohibido",
		"desc": "Cthulhu lo dejó sobre la barra. Mejor no abrirlo." },
	{ "id": "cucharon_sin_fondo", "name": "Cucharón sin fondo",
		"desc": "Con esto se salva un barco: el umibōzu no puede llenarlo nunca." },
	{ "id": "figura_shachihoko", "name": "Figura de shachihoko",
		"desc": "El shachihoko la llevaba en el lomo." },
	# --- Piratas del Caribe --------------------------------------------------
	{ "id": "perla_negra", "name": "Perla negra",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "moneda_azteca", "name": "Moneda azteca",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "corazon_cofre", "name": "Corazón en un cofrecito",
		"desc": "Sigue latiendo. David prefiere no hablar de ello." },
	# --- Monkey Island -------------------------------------------------------
	{ "id": "grog", "name": "Botella de grog",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "mono_tres_cabezas", "name": "Peluche de un mono con 3 cabezas",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "lista_insultos", "name": "Lista de insultos",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "pollo_goma", "name": "Pollo de goma con polea",
		"desc": "Salió de un cofre pescado en alta mar." },
	# --- Day of the Tentacle -------------------------------------------------
	{ "id": "gafas_nerd", "name": "Gafas rotas de nerd",
		"desc": "Tiene grabado el nombre de Bernard Bernoulli." },
	# El dibujo es un PELUCHE (con su ojo de botón), así que la ficha lo cuenta.
	{ "id": "tentaculo_purpura", "name": "Tentáculo púrpura radioactivo",
		"desc": "Un peluche descolorido que sigue brillando en la oscuridad." },
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
	{ "id": "cuerno_reno", "name": "Cuerno de reno",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "sombrero_vaquero", "name": "Sombrero vaquero morado",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "botella_cola", "name": "Botella de cola",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "violin_esqueleto", "name": "Violín de esqueleto",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "caracol_telefono", "name": "Caracol teléfono",
		"desc": "Salió de un cofre pescado en alta mar." },
	# --- La Isla del Tesoro --------------------------------------------------
	{ "id": "marca_negra", "name": "La marca negra",
		"desc": "Salió de un cofre pescado en alta mar." },
	# --- Peter Pan -----------------------------------------------------------
	{ "id": "reloj_cocodrilo", "name": "Reloj despertador del cocodrilo",
		"desc": "Salió de un cofre pescado en alta mar." },
	# --- Popeye --------------------------------------------------------------
	{ "id": "lata_espinacas", "name": "Lata de espinacas",
		"desc": "Salió de un cofre pescado en alta mar." },
	# --- La Odisea -----------------------------------------------------------
	{ "id": "tapones_cera", "name": "Tapones de cera",
		"desc": "Como los de Ulises: con ellos a bordo, cada canto de sirena dura un tercio menos." },
	# --- Robinson Crusoe -----------------------------------------------------
	{ "id": "huella_arena", "name": "Molde de una huella",
		"desc": "Salió de un cofre pescado en alta mar. Alguien más pisó esa playa." },
	# --- Tiburón -------------------------------------------------------------
	{ "id": "bidon_amarillo", "name": "Bidón amarillo",
		"desc": "Salió de un cofre pescado en alta mar. Con dos mordiscos de algo grande." },
	# --- Sea of Thieves ------------------------------------------------------
	{ "id": "banana", "name": "Banana",
		"desc": "Salió de un cofre pescado en alta mar." },
	# --- Urashima Tarō -------------------------------------------------------
	{ "id": "tamatebako", "name": "Tamatebako",
		"desc": "Salió de un cofre pescado en alta mar. No se te ocurra abrirla." },
	# --- Mitología griega ----------------------------------------------------
	{ "id": "obolo_caronte", "name": "Óbolo de Caronte",
		"desc": "Salió de un cofre pescado en alta mar. El pasaje del barquero." },
	# --- Capitán Harlock -----------------------------------------------------
	{ "id": "calavera_alada", "name": "Calavera alada",
		"desc": "Salió de un cofre pescado en alta mar." },
	# --- Sonic ---------------------------------------------------------------
	{ "id": "esmeralda_caos", "name": "Esmeralda del caos",
		"desc": "La traía enganchada la rana caótica." },
	# --- Moby Dick -----------------------------------------------------------
	{ "id": "arpon", "name": "Arpón",
		"desc": "Salió de un cofre pescado en alta mar." },
	# --- 20.000 leguas de viaje submarino ------------------------------------
	{ "id": "casco_escafandra", "name": "Casco de escafandra",
		"desc": "Salió de un cofre pescado en alta mar." },
	# --- El Holandés Errante -------------------------------------------------
	{ "id": "farol_fantasma", "name": "Farol fantasma",
		"desc": "Salió de un cofre pescado en alta mar. La llama verde no se apaga." },
	# --- Buscando a Nemo -----------------------------------------------------
	{ "id": "mascara_buceo", "name": "Máscara de buceo",
		"desc": "Salió de un cofre pescado en alta mar. El nombre está borrado." },
	# --- Indiana Jones -------------------------------------------------------
	{ "id": "idolo_dorado", "name": "Ídolo dorado",
		"desc": "Salió de un cofre pescado en alta mar." },
	# --- Overcooked ----------------------------------------------------------
	{ "id": "extintor", "name": "Extintor",
		"desc": "Salió de un cofre pescado en alta mar." },
	# --- Ratatouille ---------------------------------------------------------
	{ "id": "gorro_chef", "name": "Gorro de chef diminuto",
		"desc": "Salió de un cofre pescado en alta mar. ¿De quién era?" },
	# --- Naruto --------------------------------------------------------------
	{ "id": "cuenco_ramen", "name": "Cuenco de ramen",
		"desc": "Salió de un cofre pescado en alta mar." },
	# --- Las aventuras de Tintín ---------------------------------------------
	{ "id": "maqueta_unicornio", "name": "Maqueta del Unicornio",
		"desc": "Salió de un cofre pescado en alta mar." },
	# --- Los Goonies ---------------------------------------------------------
	{ "id": "ojo_cobre", "name": "Ojo de cobre",
		"desc": "Salió de un cofre pescado en alta mar." },
	# --- Vaiana ------------------------------------------------------------------
	{ "id": "anzuelo_maui", "name": "Anzuelo mágico gigante",
		"desc": "Por sacar %d capturas del mar. Ya vives de la caña."
			% ANZUELO_PECES },
	# --- La Sirenita y las sirenas -------------------------------------------
	{ "id": "tenedor", "name": "Tenedor",
		"desc": "¿Podría utilizarse como peine?" },
	{ "id": "peine_nacar", "name": "Peine de nácar",
		"desc": "Salió de un cofre pescado en alta mar. Esto sí es un peine." },
	# --- El Planeta del Tesoro -----------------------------------------------
	{ "id": "esfera_tesoro", "name": "Esfera del tesoro",
		"desc": "Esta esfera con forma de planeta podría ser un mapa del tesoro." },
	# --- Studio Ghibli -------------------------------------------------------
	{ "id": "colgante_cielos", "name": "Colgante de los cielos",
		"desc": "Parece que este colgante cayó de los cielos hace mucho tiempo." },
	{ "id": "tarro_ponyo", "name": "Tarro con un pez naranja",
		"desc": "Salió de un cofre pescado en alta mar." },
	# --- Zelda (el triángulo cierra la vitrina) ------------------------------
	{ "id": "vela", "name": "Vela de mascarón",
		"desc": "Salió de un cofre pescado en alta mar." },
	{ "id": "batuta_viento", "name": "Batuta del viento",
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
	{ "id": "botella_leche", "name": "Botella de leche",
		"desc": "Seguramente esté caducada. Salió de un cofre pescado en alta mar." },
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
