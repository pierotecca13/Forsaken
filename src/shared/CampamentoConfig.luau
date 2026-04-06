-- CampamentoConfig.luau
-- Configuración del Campamento Base: costos por nivel y zonas que desbloquea.

return {

	NIVEL_MAXIMO = 5,

	-- COSTOS[nivelActual] = lo que se paga para subir al siguiente nivel
	-- treboles: lista de tipos de Hoja del Trébol que el jugador debe poseer
	--   "Verde"=Bosque(B)  "Azul"=Hielo(H)  "Dorada"=Desierto(D)  "Gris"=Rocoso(R)
	COSTOS = {
		[1] = {
			recursos = { Madera = 30, Piedra = 10 },
			zona     = "Frostveil",
			treboles = { "Verde" },                          -- Trébol B (Bosque)
		},
		[2] = {
			recursos = { Piedra = 20, Hongos = 15 },
			zona     = "Ashvast",
			treboles = { "Azul" },                           -- Trébol H (Hielo)
		},
		[3] = {
			recursos = { Piedra = 25, Hongos = 10 },
			zona     = "Ironspire",
			treboles = { "Dorada" },                         -- Trébol D (Desierto)
		},
		[4] = {
			recursos = { HojaTrebol = 4 },  -- se obtienen al matar jefes de zona
			zona     = "Cloverbreach",
			treboles = { "Verde", "Azul", "Dorada", "Gris" }, -- Todos los trébolees B H D R
		},
	},

	-- Nombres legibles de cada recurso (usado en UI)
	NOMBRES = {
		Madera     = "Madera",
		Piedra     = "Piedra",
		Hongos     = "Hongos",
		HojaTrebol = "Hojas del Trebol",
	},

	-- Orden de visualización en el menú
	ORDEN_DISPLAY = { "Madera", "Piedra", "Hongos", "HojaTrebol" },
}
