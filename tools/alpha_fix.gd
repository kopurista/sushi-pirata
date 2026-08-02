extends SceneTree
## Repara los "agujeros" de transparencia DENTRO de los sprites recortados.
##
## El recorte de fondo por inundación (icon_prep / stage_prep) deja a veces
## píxeles semitransparentes en mitad del sujeto —el arroz blanco es el caso
## claro: sobre la tabla oscura se veía translúcido por arriba a la derecha—.
##
## Aquí se marca primero el EXTERIOR (lo transparente que conecta con el borde
## de la imagen) y luego se vuelve opaco todo píxel que no toque ese exterior.
## El contorno de verdad conserva su suavizado, así que no queda dentado.
##
## Uso:  godot --headless --script res://tools/alpha_fix.gd

## Alfa por debajo del cual un píxel cuenta como "fondo" al inundar.
const EMPTY := 0.06
## Carpetas que se repasan enteras.
const DIRS := ["res://assets/stages/", "res://assets/ingredients/"]
## Sprites con MORDISCOS: huecos que llegan hasta el borde del sujeto, así que
## el sellado normal no los ve (por fuera y por dentro es todo "exterior").
## Le pasa al arroz, que es blanco sobre un fondo que también era blanco: la
## inundación se metió por los huecos entre granos y se comió trozos enteros.
## Se cierran con una dilatación + erosión del radio indicado.
const PATCH := {
	"res://assets/stages/arroz_bola.png": 16,
	"res://assets/stages/arroz_plano.png": 16,
	"res://assets/stages/nori_arroz_bola.png": 16,
	"res://assets/stages/nori_arroz.png": 16,
	"res://assets/ingredients/arroz.png": 16,
}


func _init() -> void:
	for path in PATCH:
		var abs := ProjectSettings.globalize_path(str(path))
		var img := Image.load_from_file(abs)
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		var n := _close_holes(img, int(PATCH[path]))
		if n > 0:
			img.save_png(abs)
		print("%s: %d px reconstruidos" % [str(path).get_file(), n])

	var fixed := 0
	for dir_path in DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for file in dir.get_files():
			if not file.ends_with(".png"):
				continue
			var path: String = dir_path + file
			var abs := ProjectSettings.globalize_path(path)
			var img := Image.load_from_file(abs)
			if img == null:
				continue
			img.convert(Image.FORMAT_RGBA8)
			var n := _seal(img)
			if n > 0:
				img.save_png(abs)
				print("%s: %d px sellados" % [file, n])
				fixed += 1
	print("listo (%d sprites retocados)" % fixed)
	quit(0)


## CIERRE MORFOLÓGICO: dilata la silueta y la vuelve a erosionar. Los huecos
## y las mellas más estrechos que el radio desaparecen; el contorno de verdad
## se queda como estaba. Lo que se recupera se pinta con el color del píxel
## opaco más cercano, así el grano del arroz continúa sin costura.
## Devuelve cuántos píxeles se han rellenado.
func _close_holes(img: Image, radius: int) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var solid := PackedByteArray()
	solid.resize(w * h)
	for y in h:
		for x in w:
			solid[y * w + x] = 1 if img.get_pixel(x, y).a >= 0.5 else 0
	var dil := _morph(solid, w, h, radius, true)
	var closed := _morph(dil, w, h, radius, false)

	var count := 0
	for y in h:
		for x in w:
			var i := y * w + x
			if closed[i] == 0 or solid[i] == 1:
				continue
			var c := _nearest_solid_color(img, solid, w, h, x, y, radius + 3)
			if c.a <= 0.0:
				continue
			c.a = 1.0
			img.set_pixel(x, y, c)
			count += 1
	return count


## Dilatación (grow=true) o erosión separable en dos pasadas.
func _morph(src: PackedByteArray, w: int, h: int, r: int,
		grow: bool) -> PackedByteArray:
	var tmp := PackedByteArray()
	tmp.resize(w * h)
	var hit: int = 1 if grow else 0
	for y in h:
		for x in w:
			var v: int = src[y * w + x]
			for d in range(-r, r + 1):
				var nx: int = clampi(x + d, 0, w - 1)
				if src[y * w + nx] == hit:
					v = hit
					break
			tmp[y * w + x] = v
	var out := PackedByteArray()
	out.resize(w * h)
	for y in h:
		for x in w:
			var v: int = tmp[y * w + x]
			for d in range(-r, r + 1):
				var ny: int = clampi(y + d, 0, h - 1)
				if tmp[ny * w + x] == hit:
					v = hit
					break
			out[y * w + x] = v
	return out


## Color del píxel opaco más cercano dentro de un radio (búsqueda en anillos).
func _nearest_solid_color(img: Image, solid: PackedByteArray, w: int, h: int,
		x: int, y: int, max_r: int) -> Color:
	for r in range(1, max_r + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var nx: int = x + dx
				var ny: int = y + dy
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				if solid[ny * w + nx] == 1:
					return img.get_pixel(nx, ny)
	return Color(0, 0, 0, 0)


## Devuelve cuántos píxeles se han vuelto opacos.
func _seal(img: Image) -> int:
	var w := img.get_width()
	var h := img.get_height()
	# 1) Inundación desde los bordes: qué transparencia es "fuera".
	var outside := PackedByteArray()
	outside.resize(w * h)
	var stack: Array[int] = []
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		if outside[i] == 1:
			continue
		var x := i % w
		var y := i / w
		if img.get_pixel(x, y).a > EMPTY:
			continue
		outside[i] = 1
		if x > 0:
			stack.append(i - 1)
		if x < w - 1:
			stack.append(i + 1)
		if y > 0:
			stack.append(i - w)
		if y < h - 1:
			stack.append(i + w)

	# 2) Lo que no es fuera y no toca el fuera, va opaco. OJO: un píxel casi
	# transparente suele traer el RGB a cero, así que subirle solo el alfa lo
	# deja NEGRO; hay que darle además el color de su vecindario opaco.
	var solid := PackedByteArray()
	solid.resize(w * h)
	for y in h:
		for x in w:
			solid[y * w + x] = 1 if img.get_pixel(x, y).a >= 0.75 else 0
	var count := 0
	for y in h:
		for x in w:
			var i := y * w + x
			if outside[i] == 1:
				continue
			var c := img.get_pixel(x, y)
			if c.a >= 0.996:
				continue
			if _touches_outside(outside, w, h, x, y):
				continue
			if c.a < 0.75:
				var near := _nearest_solid_color(img, solid, w, h, x, y, 12)
				if near.a <= 0.0:
					continue
				c = near
			c.a = 1.0
			img.set_pixel(x, y, c)
			count += 1
	return count


func _touches_outside(outside: PackedByteArray, w: int, h: int,
		x: int, y: int) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var nx: int = x + dx
			var ny: int = y + dy
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			if outside[ny * w + nx] == 1:
				return true
	return false
