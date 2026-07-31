extends SceneTree
## Convierte los conceptos low poly de assets/models/source (fondo BLANCO
## opaco) en los iconos de plato de assets/dishes (webp transparente,
## recortado). El fondo se quita por INUNDACION desde los bordes: solo se
## borra el blanco CONECTADO con el exterior, asi el arroz blanco del propio
## plato (interior) queda intacto. Despues se recorta el bounding box por
## alfa >= 0.6 (regla del proyecto: excluye halos) con un pequeño margen.
##
## Uso:  godot --headless --script res://tools/icon_prep.gd

const IDS := [
	"maki_aguacate", "nigiri_salmon", "gunkan_wakame", "maki_atun",
	"sopa_miso", "futomaki_salmon", "nigiri_atun", "nigiri_inari",
	"sashimi_tamago", "sashimi_atun_rojo", "nigiri_ebi", "gunkan_tartar",
]
## Umbral de "blanco de fondo" (el fondo es #FFF plano; el margen absorbe la
## compresion del webp).
const WHITE := 0.93
const ALPHA_CROP := 0.6
const MARGIN := 6


func _init() -> void:
	for id in IDS:
		var src := "res://assets/models/source/%s.webp" % id
		var dst := "res://assets/dishes/%s.webp" % id
		var img := Image.load_from_file(ProjectSettings.globalize_path(src))
		if img == null:
			push_error("no se pudo cargar " + src)
			continue
		img.convert(Image.FORMAT_RGBA8)
		_remove_bg(img)
		var out := _crop(img)
		out.save_webp(ProjectSettings.globalize_path(dst), false)
		print("%s -> %dx%d" % [id, out.get_width(), out.get_height()])
	quit(0)


## Inundacion desde los cuatro bordes: todo pixel casi-blanco conectado con el
## exterior pasa a transparente.
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
