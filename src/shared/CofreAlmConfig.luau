-- CofreAlmConfig.luau
-- Configuración del Cofre de Almacenamiento del Campamento.
-- Se craftea una vez por jugador/sesión en la Mesa de Trabajo.

return {

	-- Costo para construir el cofre
	COSTO = { Madera = 20, Piedra = 10, Piel = 5 },

	-- Slots disponibles según nivel del campamento
	SLOTS_BASE = 5,
	SLOTS_POR_NIVEL = { [1] = 5, [2] = 7, [3] = 9, [4] = 11, [5] = 13 },

	-- Máximo de unidades del mismo recurso por slot
	MAX_POR_SLOT = 5,

	-- Recursos que SE PUEDEN almacenar (deben coincidir con las claves del inventario)
	ITEMS_ALMACENABLES = {
		"Madera", "Piedra", "Hongos", "Piel",
		"Colmillo", "Garra",
		"CarneConejo", "CarneZorro", "CarneLobo", "CarneOso",
		"Hierro", "Cristal",
	},

	-- Posición relativa al campamento (offsetX, 0, -20)
	OFFSET_COFRE = Vector3.new(5, 0, 0),
}
