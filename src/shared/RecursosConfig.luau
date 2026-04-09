-- RecursosConfig.luau
-- Define los tipos de recursos recolectables del mapa.
-- Usado por el servidor (lógica) y el cliente (nombres en UI).

return {

	-- Definición de cada tipo de recurso
	TIPOS = {

		Arbol = {
			nombre        = "Árbol",
			recurso       = "Madera",    -- clave en el inventario
			cantidadMin   = 1,
			cantidadMax   = 3,
			respawnTiempo = 90,          -- segundos hasta reaparecer
			-- Visual del objeto en Workspace
			tamano        = Vector3.new(2.5, 9, 2.5),
			color         = Color3.fromRGB(88, 125, 50),
			material      = Enum.Material.Wood,
			forma         = Enum.PartType.Block,
			promptTexto   = "Árbol",
		},

		Roca = {
			nombre        = "Roca",
			recurso       = "Piedra",
			cantidadMin   = 1,
			cantidadMax   = 2,
			respawnTiempo = 90,
			tamano        = Vector3.new(4, 2.5, 4),
			color         = Color3.fromRGB(140, 135, 130),
			material      = Enum.Material.Slate,
			forma         = Enum.PartType.Block,
			promptTexto   = "Roca",
		},

		Hongo = {
			nombre        = "Hongo Luminoso",
			recurso       = "Hongos",
			cantidadMin   = 1,
			cantidadMax   = 1,
			respawnTiempo = 60,
			tamano        = Vector3.new(0.7, 0.85, 0.7),
			color         = Color3.fromRGB(180, 100, 210),
			material      = Enum.Material.Neon,
			forma         = Enum.PartType.Ball,
			promptTexto   = "Hongo Luminoso",
		},

	},

	-- Recursos que se muestran en el inventario (en este orden)
	ORDEN_INVENTARIO = {
		"Madera", "Piedra", "Hongos",
		"Hierro", "Cristal",          -- minerales de zonas avanzadas
		"Piel", "Colmillo", "Garra",
		"CarneConejo", "CarneZorro", "CarneLobo", "CarneOso",
		"Antorcha", "Hoguera",
	},

	-- Subconjuntos por categoría (usados para separadores visuales en UI)
	ORDEN_COMIDA           = { "CarneConejo", "CarneZorro", "CarneLobo", "CarneOso" },
	ORDEN_HERRAMIENTAS     = { "Antorcha", "Hoguera" },
	-- Minerales avanzados: se ocultan en el inventario hasta que el jugador los consiga
	ORDEN_MINERALES_AVZ    = { "Hierro", "Cristal" },

	-- Íconos de texto para el inventario (caracteres compatibles con Roblox)
	ICONOS = {
		Madera      = "[M]",
		Piedra      = "[P]",
		Hongos      = "[H]",
		Hierro      = "[Fe]",
		Cristal     = "[Cr]",
		Piel        = "[Pi]",
		Colmillo    = "[Co]",
		Garra       = "[G]",
		CarneConejo = "[CC]",
		CarneZorro  = "[CZ]",
		CarneLobo   = "[CL]",
		CarneOso    = "[CO]",
		Antorcha    = "[At]",
		Hoguera     = "[Hg]",
	},

	-- Slots disponibles según nivel del campamento
	-- Cada recurso ocupa ceil(cantidad / MAX_POR_SLOT) slots
	SLOTS_POR_NIVEL = {
		[1] = 10,
		[2] = 15,
		[3] = 20,
		[4] = 25,
		[5] = 30,
	},

	-- Máximo de unidades apilables por slot para cada recurso
	MAX_POR_SLOT = {
		Madera      = 10,
		Piedra      = 10,
		Hongos      = 10,
		Hierro      = 10,
		Cristal     = 5,
		HojaTrebol  = 1,
		Piel        = 5,
		Colmillo    = 3,
		Garra       = 3,
		CarneConejo = 3,
		CarneZorro  = 3,
		CarneLobo   = 3,
		CarneOso    = 3,
		Antorcha    = 3,
		Hoguera     = 1,
	},

}
