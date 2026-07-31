extends SceneTree
## Prepara imágenes de UI generadas con Ludo (fondo blanco/gris plano) para el
## juego: quita el fondo por INUNDACION desde los bordes (lo claro del interior
## sobrevive), recorta al bounding box por alfa >= 0.6 y, si se pide, reescala.
##
## Las fuentes se dejan en res://_gen/ y el resultado va a assets/ui/.
## Uso:  godot --headless --script res://tools/ui_prep.gd

const ALPHA_CROP := 0.6

## src, dst, white (umbral de "fondo"; >1 = la fuente ya trae alfa y solo se
## recorta), margin, width (0 = sin reescalar), ext (extensión de la fuente).
const JOBS := [
	{ "src": "ic_aventura", "dst": "ic_aventura", "white": 2.0, "margin": 2, "width": 192, "ext": "png" },
	{ "src": "ic_tienda", "dst": "ic_tienda", "white": 2.0, "margin": 2, "width": 192, "ext": "png" },
	{ "src": "ic_inventario", "dst": "ic_inventario", "white": 2.0, "margin": 2, "width": 192, "ext": "png" },
	{ "src": "ic_arcade", "dst": "ic_arcade", "white": 2.0, "margin": 2, "width": 192, "ext": "png" },
]


func _init() -> void:
	for job in JOBS:
		var src := "res://_gen/%s.%s" % [job["src"], job.get("ext", "webp")]
		var dst := "res://assets/ui/%s.png" % job["dst"]
		var img := Image.load_from_file(ProjectSettings.globalize_path(src))
		if img == null:
			push_error("no se pudo cargar " + src)
			continue
		img.convert(Image.FORMAT_RGBA8)
		_remove_bg(img, float(job["white"]))
		var out := _crop(img, int(job["margin"]))
		var w := int(job["width"])
		if w > 0 and out.get_width() != w:
			var h := int(round(out.get_height() * float(w) / float(out.get_width())))
			out.resize(w, h, Image.INTERPOLATE_LANCZOS)
		out.save_png(ProjectSettings.globalize_path(dst))
		print("%s -> %dx%d" % [job["dst"], out.get_width(), out.get_height()])
	quit(0)


func _remove_bg(img: Image, white: float) -> void:
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
		if c.r < white or c.g < white or c.b < white:
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


func _crop(img: Image, margin: int) -> Image:
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
	min_x = maxi(min_x - margin, 0)
	min_y = maxi(min_y - margin, 0)
	max_x = mini(max_x + margin, w - 1)
	max_y = mini(max_y + margin, h - 1)
	var rect := Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	var out := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, rect, Vector2i.ZERO)
	return out
