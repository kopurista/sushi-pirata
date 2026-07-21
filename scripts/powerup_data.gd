class_name PowerupData
## Catálogo de potenciadores.
## "manual": true → se guarda como icono bajo el chef y el jugador elige cuándo usarlo.
## "manual": false → se aplica automáticamente al seleccionarlo.

const POWERUPS: Dictionary = {
	"cinta_rapida": {
		"name": "Cinta rápida",
		"desc": "La cinta va al triple de velocidad durante 20 s.",
		"manual": true,
		"icon": "Cinta+",
	},
	"aroma": {
		"name": "Aroma irresistible",
		"desc": "Los clientes son mucho más propensos a coger su plato favorito.",
		"manual": false,
	},
	"comida_segura": {
		"name": "Comida segura",
		"desc": "El primer cliente que no esté comiendo se comerá su próximo plato, 100% seguro.",
		"manual": true,
		"icon": "Segura",
	},
	"receta_instantanea": {
		"name": "Receta instantánea",
		"desc": "Las siguientes 3 recetas se hacen solas, sin pasos.",
		"manual": false,
	},
	"clientes_pacientes": {
		"name": "Clientes pacientes",
		"desc": "+20% de paciencia para los clientes actuales y los que vengan.",
		"manual": false,
	},
	"menos_cooldown": {
		"name": "Menos cooldown",
		"desc": "Todas las recetas tienen un 40% menos de cooldown durante 20 s.",
		"manual": false,
	},
	"sin_cooldown": {
		"name": "Sin cooldown",
		"desc": "La siguiente receta no entra en cooldown.",
		"manual": true,
		"icon": "NoCD",
	},
	"manos_rapidas": {
		"name": "Manos rápidas",
		"desc": "La siguiente receta necesita menos pasos.",
		"manual": true,
		"icon": "Manos",
	},
	"mas_propinas": {
		"name": "Más propinas",
		"desc": "+10% de probabilidad de propina durante 30 s.",
		"manual": false,
	},
	"mejores_propinas": {
		"name": "Mejores propinas",
		"desc": "Las propinas son un 20% mayores durante 30 s.",
		"manual": false,
	},
	"cliente_satisfecho": {
		"name": "Cliente satisfecho",
		"desc": "El próximo cliente en llegar paga un 20% más.",
		"manual": false,
	},
	"hora_feliz": {
		"name": "Hora feliz",
		"desc": "Vienen 3 grumetes extra.",
		"manual": false,
	},
	"cena_empresa": {
		"name": "Cena de tripulación",
		"desc": "Vienen 3 piratas extra.",
		"manual": false,
	},
	"noche_gourmet": {
		"name": "Noche de capitanes",
		"desc": "Vienen 3 capitanes extra.",
		"manual": false,
	},
	"horas_extra": {
		"name": "Horas extra",
		"desc": "Aumenta 1 minuto el tiempo restante.",
		"manual": false,
	},
	"guardar_extra": {
		"name": "Guardar un plato más",
		"desc": "Permite guardar un tercer plato.",
		"manual": false,
	},
	"tiempo_extra_prep": {
		"name": "Tiempo de preparación extra",
		"desc": "Todo se detiene durante 10 s para preparar platos o pensar la estrategia.",
		"manual": false,
	},
	"reciclaje": {
		"name": "Reciclaje de platos",
		"desc": "Los platos que dan 2 vueltas no se pierden: vuelven a la receta para reutilizarlos.",
		"manual": false,
	},
	"doble_plato": {
		"name": "Doble plato",
		"desc": "La siguiente receta crea 2 platos en lugar de 1.",
		"manual": false,
	},
	"mas_almacen": {
		"name": "Más almacén",
		"desc": "Cada caja puede guardar hasta 5 platos iguales.",
		"manual": false,
	},
}


static func get_powerup(id: String) -> Dictionary:
	return POWERUPS.get(id, {})
