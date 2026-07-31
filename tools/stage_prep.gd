extends SceneTree
## Convierte las regeneraciones low poly de los sprites de etapa (webp con
## fondo BLANCO opaco, en el scratchpad de la sesion) en los PNG transparentes
## de assets/stages. Mismo proceso que icon_prep.gd: el fondo se quita por
## INUNDACION desde los bordes (solo el blanco conectado con el exterior, asi
## el arroz blanco del interior queda intacto) y se recorta el bounding box
## por alfa >= 0.6 con un pequeño margen.
##
## Uso:  godot --headless --script res://tools/stage_prep.gd -- <dir_entrada>

const WHITE := 0.93
const ALPHA_CROP := 0.6
const MARGIN := 6


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
		var out := _crop(img)
		var dst := "res://assets/stages/%s.png" % f.get_basename()
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
		if c.r < WHITE or c.g < WHITE or c.b < WHITE:
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
