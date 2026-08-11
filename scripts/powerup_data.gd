class_name PowerupData
## Catálogo de potenciadores DE PARTIDA: los que regala el bote de propinas
## dentro de un nivel. (Los PERMANENTES son otra cosa y viven en `perk_data.gd`.)
##
## TODOS son AUTOMÁTICOS: se aplican solos al elegirlos. Antes había una mitad
## "manual" que se guardaba como un botón bajo el chef para usarla cuando
## conviniera, y eso obligaba a decidir dos veces (cuál cojo y cuándo lo gasto)
## en mitad de una partida de dos minutos y medio. Con todo automático, elegir
## un potenciador es mirar tres dibujos y tocar uno.
##
## El cartel de elección PARA EL JUEGO ENTERO (cinta, reloj, paciencia y
## bocados), así que el jugador puede leerlo con calma; lo que se recortó es lo
## que hay que leer, no el tiempo para leerlo.
##
## Campos: "name" es el título corto que se dibuja bajo el icono (tiene que
## definir el potenciador él solo, sin la descripción), "desc" es la línea de
## apoyo, e "icon" el dibujo que lo resume.
##
## EL CATÁLOGO ES CORTO A PROPÓSITO (13 entradas, y una solo sale con reloj).
## Llegó a tener 20 y estaba lleno de parejas que hacían lo mismo: dos de
## enfriamiento, dos de propinas, dos de almacén y TRES de "vienen clientes de
## más", uno por tipo. Con tres opciones sorteadas de veinte, lo normal era que
## dos de las tres fueran indistinguibles. Al fusionarlas, cada opción del
## sorteo significa algo distinto de las otras dos.
##
## Los que se cayeron y por qué, para no reintroducirlos:
##  - "comida segura" (un cliente coge seguro su próximo plato) y "cliente
##    satisfecho" (+20% de pago a UN cliente): tocan a una sola persona de la
##    barra, así que no se notan.
##  - "manos rápidas" (la siguiente receta con menos pasos): es una versión
##    floja de "Recetas instantáneas".
##  - "sin cooldown" (una receta sin enfriamiento): absorbido por "Cocina sin
##    esperas", que hace lo mismo durante 25 s.
##  - "reciclaje": devolvía los platos tirados, pero pasaba en la basura, fuera
##    de donde el jugador está mirando, y su texto ya mentía (hablaba de dos
##    vueltas cuando los platos dan una desde hace tiempo).

const POWERUPS: Dictionary = {
	"cinta_rapida": {
		"name": "Cinta rápida",
		"desc": "La cinta vuela durante 20 s.",
		"icon": "res://assets/ui/pot_cinta.png",
	},
	"aroma": {
		"name": "Aroma irresistible",
		"desc": "Ya casi nadie deja pasar su plato favorito.",
		"icon": "res://assets/ui/pot_aroma.png",
	},
	"receta_instantanea": {
		"name": "Recetas instantáneas",
		"desc": "Las 3 siguientes recetas se hacen solas.",
		"icon": "res://assets/ui/pot_instantanea.png",
	},
	"clientes_pacientes": {
		"name": "Clientes pacientes",
		"desc": "+20% de paciencia para todos, y para los que vengan.",
		"icon": "res://assets/ui/pot_paciencia.png",
	},
	"menos_cooldown": {
		"name": "Cocina sin esperas",
		"desc": "Los enfriamientos casi desaparecen durante 25 s.",
		"icon": "res://assets/ui/pot_sin_esperas.png",
	},
	"mas_propinas": {
		"name": "Lluvia de propinas",
		"desc": "Propinas más probables y más gordas durante 30 s.",
		"icon": "res://assets/ui/pot_propinas.png",
	},
	"clientes_extra": {
		"name": "Más clientela",
		"desc": "Se sientan 3 clientes de más.",
		"icon": "res://assets/ui/pot_clientela.png",
	},
	"tiempo_extra_prep": {
		"name": "Tiempo muerto",
		"desc": "Todo se detiene 10 s para que cocines tranquilo.",
		"icon": "res://assets/ui/pot_tiempo_muerto.png",
	},
	"mas_almacen": {
		"name": "Más almacén",
		"desc": "Una caja más, y cada una guarda 5 platos.",
		"icon": "res://assets/ui/pot_almacen.png",
	},
	"doble_plato": {
		"name": "Doble plato",
		"desc": "La siguiente receta saca 2 platos de golpe.",
		"icon": "res://assets/ui/pot_doble.png",
	},
	# Solo se sortea en los ABORDAJES: son los únicos niveles con reloj (ver
	# level3d._open_powerup_choice, que lo saca de la lista donde no hay tiempo).
	"horas_extra": {
		"name": "Horas extra",
		"desc": "Un minuto más de turno.",
		"icon": "res://assets/ui/pot_reloj.png",
	},
	# --- Potenciadores de HASTÍO Y VARIEDAD (ver client3d) ---
	"variedad_extra": {
		"name": "Variedad para todos",
		"desc": "+1 de variedad a todos los clientes sentados.",
		"icon": "res://assets/ui/pot_variedad.png",
	},
	"sobremesa": {
		"name": "Sobremesa dulce",
		"desc": "El próximo postre cobra el doble.",
		"icon": "res://assets/ui/pot_sobremesa.png",
	},
}


static func get_powerup(id: String) -> Dictionary:
	return POWERUPS.get(id, {})
