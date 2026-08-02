extends SceneTree
## Convierte las regeneraciones low poly de los sprites de INGREDIENTE (webp con
## fondo BLANCO opaco, en el scratchpad de la sesion) en los PNG transparentes
## de assets/stages. Mismo proceso que icon_prep.gd: el fondo se quita por
## INUNDACION desde los bordes (solo el blanco conectado con el exterior, asi
## el arroz blanco del interior queda intacto) y se recorta el bounding box
## por alfa >= 0.6 con un pequeño margen.
##
## Uso:  godot --headless --script res://tools/ingredient_prep.gd -- <dir_entrada>

## Umbral de "esto es fondo". MUY alto a proposito: el fondo generado es
## blanco PURO (1,1,1) y el arroz, aunque casi blanco, siempre trae algo de
## sombreado (0.90-0.96). Con el 0.93 de antes la inundacion no distinguia uno
## de otro y se comia el arroz por donde tocaba el borde de la imagen: por eso
## los nigiri, el rollo y la bola salian con un MORDISCO arriba.
const WHITE := 0.988
## Ademas del umbral, el fondo tiene que ser NEUTRO: los pixeles de arroz muy
## iluminados llegan a 0.99 pero con un pelin de tinte calido, y esto los
## salva. Diferencia maxima entre canales para considerar un pixel "gris".
const NEUTRAL := 0.012
const ALPHA_CROP := 0.6
const MARGIN := 6
## Cierre morfologico del alfa: tapa los mordiscos y agujeritos que quedan
## cuando el fondo se cuela por una rendija del sujeto.
const CLOSE_RADIUS := 5


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("falta el directorio de entrada (tras --)")
		quit(1)
		return
	var src_dir: String = args[0]
	for f in DirAccess.get_files_at(src_dir):
		if not f.ends_with(".webp"):
			continue
		var img := Image.load_from_file(src_dir + "/" + f)
		if img == null:
			push_error("no se pudo cargar " + f)
			continue
		img.convert(Image.FORMAT_RGBA8)
		_remove_bg(img)
		_close_alpha(img)
		var out := _crop(img)
		var dst := "res://assets/ingredients/%s.png" % f.get_basename()
		out.save_png(ProjectSettings.globalize_path(dst))
		print("%s -> %dx%d" % [f.get_basename(), out.get_width(), out.get_height()])
	quit(0)


func _remove_bg(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var visited := PackedByteArray()
	visited.resize(w * h)
	var stack: Array[int] = []
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		if visited[i] == 1:
			continue
		visited[i] = 1
		var x := i % w
		var y := i / w
		var c := img.get_pixel(x, y)
		if not _is_bg(c):
			continue
		img.set_pixel(x, y, Color(0, 0, 0, 0))
		if x > 0:
			stack.append(i - 1)
		if x < w - 1:
			stack.append(i + 1)
		if y > 0:
			stack.append(i - w)
		if y < h - 1:
			stack.append(i + w)


## Fondo = blanco casi puro Y neutro (ver WHITE / NEUTRAL).
func _is_bg(c: Color) -> bool:
	if c.r < WHITE or c.g < WHITE or c.b < WHITE:
		return false
	var hi: float = maxf(c.r, maxf(c.g, c.b))
	var lo: float = minf(c.r, minf(c.g, c.b))
	return hi - lo <= NEUTRAL


## Cierre morfologico del canal alfa (dilatar y luego erosionar): rellena los
## mordiscos y agujeritos que deje la inundacion sin engordar la silueta. El
## color de los pixeles recuperados se copia del vecino opaco mas cercano,
## porque un pixel transparente trae el RGB a cero y saldria NEGRO.
func _close_alpha(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var solid := PackedByteArray()
	solid.resize(w * h)
	for y in h:
		for x in w:
			solid[y * w + x] = 1 if img.get_pixel(x, y).a > 0.5 else 0
	var grown := _dilate(solid, w, h, CLOSE_RADIUS)
	var closed := _erode(grown, w, h, CLOSE_RADIUS)
	for y in h:
		for x in w:
			var i := y * w + x
			if closed[i] == 1 and solid[i] == 0:
				img.set_pixel(x, y, _nearest_opaque(img, x, y, CLOSE_RADIUS + 2))


func _dilate(src: PackedByteArray, w: int, h: int, r: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(w * h)
	for y in h:
		for x in w:
			var on := 0
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					if src[ny * w + nx] == 1:
						on = 1
						break
				if on == 1:
					break
			out[y * w + x] = on
	return out


func _erode(src: PackedByteArray, w: int, h: int, r: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(w * h)
	for y in h:
		for x in w:
			var all := 1
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var nx: int = clampi(x + dx, 0, w - 1)
					var ny: int = clampi(y + dy, 0, h - 1)
					if src[ny * w + nx] == 0:
						all = 0
						break
				if all == 0:
					break
			out[y * w + x] = all
	return out


func _nearest_opaque(img: Image, x: int, y: int, r: int) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	for rad in range(1, r + 1):
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				if absi(dx) != rad and absi(dy) != rad:
					continue
				var nx := x + dx
				var ny := y + dy
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var c := img.get_pixel(nx, ny)
				if c.a > 0.8:
					return Color(c.r, c.g, c.b, 1.0)
	return Color(0.92, 0.90, 0.86, 1.0)


func _crop(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a >= ALPHA_CROP:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return img
	min_x = maxi(min_x - MARGIN, 0)
	min_y = maxi(min_y - MARGIN, 0)
	max_x = mini(max_x + MARGIN, w - 1)
	max_y = mini(max_y + MARGIN, h - 1)
	var rect := Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	var out := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, rect, Vector2i.ZERO)
	return out
