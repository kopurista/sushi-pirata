extends Node
## UIFx — EL MOVIMIENTO DE LA INTERFAZ, EN UN SOLO SITIO (autoload, 7-9-2026).
##
## Lo que en el mercado movil se llama "juice": cada boton se HUNDE al tocarlo
## y REBOTA al soltarlo, los carteles ENTRAN con un pop, las listas se
## ESCALONAN, los avisos LATEN y la accion principal lleva un BRILLO que cruza
## la placa. Nada de esto cambia lo que hace la interfaz; cambia lo que se
## siente al usarla (Cooking Fever, Royal Match y los de Supercell lo hacen
## en todos sus botones).
##
## COMO SE ENGANCHA: igual que el clic de `Audio`, escuchando `node_added`:
## cada `BaseButton` que entra en el arbol recibe su hundido y su rebote sin
## que nadie lo pida. Un boton se excluye con `set_meta("no_fx", true)`. Lo
## demas se pide a mano: `UIFx.pop_in(cartel)`, `UIFx.escalonar(tarjetas)`,
## `UIFx.latir(globo)`, `UIFx.brillo(boton_principal)`, `UIFx.bump(cifra)`.
##
## Los tweens cuelgan del NODO que animan (`c.create_tween()`): al liberarlo
## mueren con el, que es lo que evita el "Lambda capture was freed" de los
## carteles que se rehacen.

const HUNDIDO := Vector2(0.91, 0.91)
const T_HUNDIR := 0.06
const T_SOLTAR := 0.30
## Cuanto se pasa al soltar antes de asentarse: es lo que se VE como rebote.
const SOBRE := 1.07
const BRILLO := preload("res://shaders/ui_brillo.gdshader")


func _ready() -> void:
	get_tree().node_added.connect(_al_entrar_nodo)
	_recorrer(get_tree().root)


func _recorrer(n: Node) -> void:
	_al_entrar_nodo(n)
	for h in n.get_children():
		_recorrer(h)


func _al_entrar_nodo(n: Node) -> void:
	if not n is BaseButton:
		return
	var b := n as BaseButton
	# el mismo motivo que en Audio: un boton puede entrar dos veces en el arbol
	if b.has_meta("fx_puesto") or b.has_meta("no_fx"):
		return
	b.set_meta("fx_puesto", true)
	b.pivot_offset = b.size * 0.5
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.button_down.connect(_hundir.bind(b))
	b.button_up.connect(_soltar.bind(b))


## Al tocar: se encoge deprisa (el dedo lo aplasta).
func _hundir(b: BaseButton) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	_matar(b)
	# un boton que LATE (la accion principal) deja de latir mientras se pulsa:
	# los dos tweens tocan `scale` y el latido se comia el hundido
	if b.has_meta("fx_latido"):
		var lat: Tween = b.get_meta("fx_latido")
		if lat != null and lat.is_valid():
			lat.pause()
	var tw := b.create_tween()
	b.set_meta("fx_tween", tw)
	tw.tween_property(b, "scale", HUNDIDO, T_HUNDIR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# DESTELLO: las texturas del boton se aclaran mientras esta hundido (el
	# "se enciende al tocar" de los botones de Supercell). Va en los hijos
	# dibujados, no en el `modulate` del boton, que lo usan los estados de
	# apagado/bloqueado y no se puede tocar.
	for h in _pieles(b):
		(h as Control).modulate = Color(1.22, 1.22, 1.18)
	# HAPTICO: un toque corto en el movil (iOS y Android lo llevan en todos
	# los botones del sistema, y los juegos grandes tambien). En escritorio
	# la llamada no hace nada.
	if OS.has_feature("mobile") and not b.disabled:
		Input.vibrate_handheld(12)


## Al soltar: vuelve pasandose un poco y rebotando (elastico), que es lo que
## se lee como "ha respondido".
func _soltar(b: BaseButton) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	_matar(b)
	var base: Vector2 = b.get_meta("fx_base", Vector2.ONE)
	for h in _pieles(b):
		var ht: Tween = (h as Control).create_tween()
		ht.tween_property(h, "modulate", Color.WHITE, 0.22)
	var tw := b.create_tween()
	b.set_meta("fx_tween", tw)
	# en DOS tiempos: se pasa (1.07) en 90 ms y se asienta con elastico. Un
	# elastico solo, de 0.91 a 1, apenas se pasaba y no se leia como rebote.
	tw.tween_property(b, "scale", base * SOBRE, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", base, T_SOLTAR).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if b.has_meta("fx_latido"):
		var lat: Tween = b.get_meta("fx_latido")
		tw.tween_callback(func() -> void:
			if lat != null and lat.is_valid():
				lat.play())


## Las texturas que DIBUJAN el boton (la madera, la placa, el icono), sin la
## sombra: son las que se aclaran al pulsar y las que llevan el brillo.
func _pieles(b: Control) -> Array:
	var out := []
	for h in b.get_children():
		if (h is NinePatchRect or h is TextureRect) and not str(h.name).begins_with("SkinShadow") 				and not h.has_meta("sin_destello"):
			out.append(h)
	return out


func _matar(c: Control) -> void:
	if c.has_meta("fx_tween"):
		var tw: Tween = c.get_meta("fx_tween")
		if tw != null and tw.is_valid():
			tw.kill()
		c.remove_meta("fx_tween")


## Un cartel o tarjeta que APARECE: entra desde `desde` de escala y
## transparente, y se clava con un rebote corto. `retardo` para escalonar.
func pop_in(c: Control, retardo := 0.0, desde := 0.86, dur := 0.30) -> void:
	if c == null or not is_instance_valid(c):
		return
	c.pivot_offset = c.size * 0.5
	# un nodo que late deja de latir mientras entra (los dos tocan `scale`)
	var lat: Tween = c.get_meta("fx_latido") if c.has_meta("fx_latido") else null
	if lat != null and lat.is_valid():
		lat.pause()
	var base: Vector2 = c.get_meta("fx_base", Vector2.ONE)
	c.scale = base * desde
	var alfa := c.modulate.a
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "scale", base, dur).set_delay(retardo) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", alfa, minf(dur * 0.6, 0.2)).set_delay(retardo)
	if lat != null:
		tw.chain().tween_callback(func() -> void:
			if lat.is_valid():
				lat.play())


## Lo contrario: se encoge y se desvanece, y si `liberar` se va del arbol.
func pop_out(c: Control, liberar := true, dur := 0.16) -> void:
	if c == null or not is_instance_valid(c):
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "scale", Vector2(0.9, 0.9), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "modulate:a", 0.0, dur)
	if liberar:
		tw.chain().tween_callback(c.queue_free)


## Una lista de tarjetas que entra de una en una (paso entre cada dos).
func escalonar(nodos: Array, paso := 0.045, desde := 0.88) -> void:
	var i := 0
	for n in nodos:
		if n is Control:
			pop_in(n, i * paso, desde, 0.26)
			i += 1


## LATIDO en bucle (globos de aviso, la accion principal): amplitud y periodo.
func latir(c: Control, amp := 0.04, periodo := 1.3) -> void:
	if c == null or not is_instance_valid(c):
		return
	quieto(c)
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.set_loops()
	tw.tween_property(c, "scale", Vector2.ONE * (1.0 + amp), periodo * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, periodo * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	c.set_meta("fx_latido", tw)


## Para el latido y deja el nodo a escala 1.
func quieto(c: Control) -> void:
	if c == null or not is_instance_valid(c):
		return
	if c.has_meta("fx_latido"):
		var tw: Tween = c.get_meta("fx_latido")
		if tw != null and tw.is_valid():
			tw.kill()
		c.remove_meta("fx_latido")
	c.scale = Vector2.ONE


## Un BOTE rapido (una cifra que cambia, un icono que recibe algo).
func bump(c: Control, amp := 1.18, dur := 0.26) -> void:
	if c == null or not is_instance_valid(c):
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * amp, dur * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, dur * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## EL BRILLO de la accion principal: una banda de luz cruza la placa cada
## `periodo` s. Se pone en las texturas del boton (NinePatchRect y
## TextureRect hijos, menos la sombra), que es lo que respeta su silueta.
func brillo(b: Control, periodo := 3.6, fuerza := 0.55) -> void:
	if b == null or not is_instance_valid(b):
		return
	for h in b.get_children():
		if not (h is NinePatchRect or h is TextureRect):
			continue
		if str(h.name).begins_with("SkinShadow") or h.has_meta("sin_brillo"):
			continue
		var mat := ShaderMaterial.new()
		mat.shader = BRILLO
		mat.set_shader_parameter("periodo", periodo)
		mat.set_shader_parameter("fuerza", fuerza)
		mat.set_shader_parameter("tam", (h as Control).size)
		(h as Control).material = mat
		(h as Control).resized.connect(func() -> void:
			mat.set_shader_parameter("tam", (h as Control).size))


## Quita el brillo (por ejemplo, al apagar un boton).
func sin_brillo(b: Control) -> void:
	if b == null or not is_instance_valid(b):
		return
	for h in b.get_children():
		if (h is NinePatchRect or h is TextureRect) and (h as Control).material != null \
				and (h as Control).material is ShaderMaterial \
				and ((h as Control).material as ShaderMaterial).shader == BRILLO:
			(h as Control).material = null


## VELO oscuro que entra con fundido (para los carteles modales). Devuelve el
## ColorRect para quitarlo con `desvelar`.
func velar(padre: Node, alfa := 0.45, dur := 0.16) -> ColorRect:
	var v := ColorRect.new()
	v.color = Color(0.0, 0.0, 0.0, 0.0)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	padre.add_child(v)
	var tw := v.create_tween()
	tw.tween_property(v, "color:a", alfa, dur)
	return v


func desvelar(v: ColorRect, dur := 0.14) -> void:
	if v == null or not is_instance_valid(v):
		return
	var tw := v.create_tween()
	tw.tween_property(v, "color:a", 0.0, dur)
	tw.tween_callback(v.queue_free)


## TODA VENTANA EMERGENTE ENTRA CON MOVIMIENTO. Lo llama `Audio.ventana`, por
## donde pasan todas: el nodo raiz (el velo) se funde desde transparente y el
## CARTEL que lleva dentro entra con un pop. El cartel se busca solo: es el
## primer descendiente que NO cubre la pantalla entera (los velos y los
## `CenterContainer` la cubren; el pergamino no). Como casi todas las pantallas
## llaman a `Audio.ventana` ANTES de colgar el contenido, se espera dos
## fotogramas —con el conjunto invisible— a que los contenedores hayan medido.
func ventana_abre(nodo: Node) -> void:
	if not (nodo is Control):
		return
	var c := nodo as Control
	if c.has_meta("fx_ventana"):
		return
	c.set_meta("fx_ventana", true)
	var a0 := c.modulate.a
	c.modulate.a = 0.0
	_ventana_abre_2(c, a0)


func _ventana_abre_2(c: Control, a0: float) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(c):
		return
	# un velo que no procesa (arbol en pausa y sin PROCESS_MODE_ALWAYS) no
	# podria terminar su tween: mejor sin animacion que invisible para siempre
	if not c.is_inside_tree() or not c.can_process():
		c.modulate.a = a0
		return
	# un cartel que ya es el propio nodo (el aviso de bloqueado, anclado al
	# centro): entra el entero con su pop, sin velo que fundir
	var lienzo := c.get_viewport_rect().size
	if c.size.x < lienzo.x * 0.9 or c.size.y < lienzo.y * 0.9:
		c.modulate.a = a0
		pop_in(c, 0.0, 0.84, 0.30)
		return
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", a0, 0.14)
	var caja := _caja_de(c)
	if caja != null:
		pop_in(caja, 0.0, 0.84, 0.30)


## Lo contrario: el cartel se encoge y el velo se funde, y al terminar se
## libera el nodo. Para los cierres explicitos (Cancelar, Comprar...).
func cerrar(nodo: Node, dur := 0.16) -> void:
	if nodo == null or not is_instance_valid(nodo):
		return
	if not (nodo is Control) or not (nodo as Control).can_process():
		nodo.queue_free()
		return
	var c := nodo as Control
	if c.has_meta("fx_cerrando"):
		return
	c.set_meta("fx_cerrando", true)
	# mientras se va no responde a nada (un segundo toque sobre "Comprar"
	# a medio fundido compraria dos veces)
	for b in c.find_children("*", "BaseButton", true, false):
		(b as BaseButton).disabled = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caja := _caja_de(c)
	if caja != null:
		pop_out(caja, false, dur)
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 0.0, dur)
	tw.tween_callback(c.queue_free)


## El CARTEL de una ventana: el primer descendiente que no cubre la pantalla.
func _caja_de(raiz: Control) -> Control:
	var lienzo := raiz.get_viewport_rect().size
	var cola: Array = []
	for h in raiz.get_children():
		cola.append(h)
	while not cola.is_empty():
		var n: Node = cola.pop_front()
		if n is Control:
			var c := n as Control
			var entero := c.size.x >= lienzo.x * 0.9 and c.size.y >= lienzo.y * 0.9
			if c.visible and not entero and c.size.x >= 100.0 and c.size.y >= 60.0:
				return c
		for h in n.get_children():
			cola.append(h)
	return null


## MONEDAS QUE VUELAN de un sitio a otro (una compra que sale del boton hacia
## el monedero, un cobro que cae en la caja). `padre` es la capa donde se
## dibujan; `al_llegar` se llama cuando aterriza la ultima.
## `abajo`: el abanico sale hacia ABAJO (monedas que se VAN del monedero al
## comprar); sin el, hacia arriba (monedas que llegan).
func monedas(padre: Control, desde: Vector2, hasta: Vector2, cuantas := 8,
		al_llegar := Callable(), abajo := false) -> void:
	if padre == null or not is_instance_valid(padre):
		return
	var capa := Control.new()
	capa.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.z_index = 200
	padre.add_child(capa)
	var tex: Texture2D = load("res://assets/ui/moneda.png")
	var vuelo := 0.42
	for i in cuantas:
		var m := TextureRect.new()
		m.texture = tex
		m.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		m.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		m.size = Vector2(38, 38)
		m.pivot_offset = Vector2(19, 19)
		m.position = desde - Vector2(19, 19)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		capa.add_child(m)
		# cada moneda sale en abanico y despues busca el destino, con su
		# propio retardo: en fila india se leia como una cadena
		var salto := Vector2(randf_range(-70.0, 70.0), randf_range(-110.0, -40.0))
		if abajo:
			salto = Vector2(randf_range(-40.0, 40.0), randf_range(34.0, 84.0))
		var d := i * 0.04
		var t := m.create_tween()
		t.tween_property(m, "position", m.position + salto, 0.18).set_delay(d) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(m, "position", hasta - Vector2(19, 19), vuelo) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(m, "scale", Vector2(0.55, 0.55), vuelo)
		t.parallel().tween_property(m, "rotation_degrees", randf_range(-200.0, 200.0), vuelo)
		t.tween_property(m, "modulate:a", 0.0, 0.08)
	# `al_llegar` salta cuando ATERRIZA LA PRIMERA (es cuando la cifra tiene
	# que cambiar: esperar a la ultima dejaba el monedero sin actualizar mas
	# de un segundo, medido en captura); la capa se libera con la ultima.
	var fin := capa.create_tween()
	fin.tween_interval(0.18 + vuelo)
	fin.tween_callback(func() -> void:
		if al_llegar.is_valid():
			al_llegar.call())
	fin.tween_interval(cuantas * 0.04 + 0.15)
	fin.tween_callback(capa.queue_free)


## Un TEMBLOR corto (error, algo que no se puede hacer): sacude en x.
func sacudir(c: Control, amp := 8.0, dur := 0.32) -> void:
	if c == null or not is_instance_valid(c):
		return
	var x0 := c.position.x
	var tw := c.create_tween()
	for k in 4:
		var s := amp * (1.0 - float(k) / 4.0) * (1.0 if k % 2 == 0 else -1.0)
		tw.tween_property(c, "position:x", x0 + s, dur / 5.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "position:x", x0, dur / 5.0)
