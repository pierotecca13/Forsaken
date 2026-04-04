-- ArmasConfig.luau
-- Definición de todas las armas del juego y parámetros de combate.
-- Importado por servidor (daño) y cliente (cooldown local, UI).

return {

	-- Studs de alcance cuerpo a cuerpo
	RANGO_ATAQUE = 7,

	-- Tabla de armas. La clave es el nombre interno usado en Tool.Name
	-- y en player:GetAttribute("ArmaEquipada").
	ARMAS = {

		Palo = {
			nombre   = "Palo",
			dano     = 10,
			cooldown = 1.0,
			color    = Color3.fromRGB(139, 90, 43),
			tamano   = Vector3.new(0.3, 0.3, 3),
			material = Enum.Material.Wood,
		},

		HachaPiedra = {
			nombre   = "Hacha de Piedra",
			dano     = 20,
			cooldown = 1.2,
			color    = Color3.fromRGB(128, 128, 138),
			tamano   = Vector3.new(0.45, 2.2, 0.45),
			material = Enum.Material.Slate,
		},

		EspadaHierro = {
			nombre   = "Espada de Hierro",
			dano     = 35,
			cooldown = 0.9,
			color    = Color3.fromRGB(170, 178, 190),
			tamano   = Vector3.new(0.2, 3.2, 0.2),
			material = Enum.Material.Metal,
		},

		EspadaCristal = {
			nombre   = "Espada de Cristal",
			dano     = 50,
			cooldown = 0.8,
			color    = Color3.fromRGB(110, 210, 255),
			tamano   = Vector3.new(0.2, 3.2, 0.2),
			material = Enum.Material.SmoothPlastic,
		},

		LanzaLuz = {
			nombre   = "Lanza de Luz",
			dano     = 80,
			cooldown = 1.5,
			color    = Color3.fromRGB(255, 248, 110),
			tamano   = Vector3.new(0.2, 0.2, 4.8),
			material = Enum.Material.Neon,
		},

	},

	-- Arma con la que aparece el jugador
	ARMA_INICIAL = "Palo",
}
