-- ComidaConfig.luau
-- Tipos de alimentos, cantidad de vida que recuperan y penalización nocturna.
-- Importado por Comida.server y Comida.client.

return {

	-- Definición de cada alimento: clave de inventario, nombre legible y HP base
	ALIMENTOS = {
		CarneConejo = { nombre = "Carne de Conejo", vidaBase = 15 },
		CarneZorro  = { nombre = "Carne de Zorro",  vidaBase = 20 },
		CarneLobo   = { nombre = "Carne de Lobo",   vidaBase = 25 },
		CarneOso    = { nombre = "Carne de Oso",    vidaBase = 40 },
	},

	-- Orden de selección en el picker (de más débil a más potente)
	-- El picker abre por defecto en el último (más potente disponible)
	ORDEN = { "CarneConejo", "CarneZorro", "CarneLobo", "CarneOso" },

	-- Penalización de curación durante la noche (fracción a restar)
	PENALIZACION_NOCHE = 0.30,   -- 30 % menos de noche
}
