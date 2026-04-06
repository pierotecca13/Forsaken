-- LobbyConfig.luau  (ModuleScript en ReplicatedStorage/Shared/)
-- Configuración central del lobby: kits, precios y posiciones del mundo.

return {
	-- Costo en gemas de cualquier kit
	PRECIO_KIT = 200,

	-- Definición de los 3 kits disponibles
	KITS = {
		Explorador = {
			nombre      = "Kit Explorador",
			descripcion = "3 Antorchas + 1 Hoguera al iniciar",
			-- Items que se agregan al inventario al comenzar la partida
			items       = { Antorcha = 3, Hoguera = 1 },
			-- nil = usa el arma por defecto (Palo)
			armaInicial = nil,
		},
		Combatiente = {
			nombre      = "Kit Combatiente",
			descripcion = "Hacha de Piedra equipada desde el inicio",
			items       = {},
			-- Reemplaza el Palo inicial por HachaPiedra
			armaInicial = "HachaPiedra",
		},
		Craftero = {
			nombre      = "Kit Craftero",
			descripcion = "10 Madera + 5 Piedra al iniciar",
			items       = { Madera = 10, Piedra = 5 },
			armaInicial = nil,
		},
	},

	-- CFrame de spawn en el lobby (isla elevada a Y=500)
	SPAWN_LOBBY_CF = CFrame.new(-500, 501.25, 0),

	-- CFrame de spawn al entrar al juego (igual que SPAWN_CF de Combate)
	SPAWN_JUEGO_CF = CFrame.new(5, 3, -14),

	-- Posiciones de los 3 cofres de kit en el lobby
	POSICIONES_COFRES = {
		Explorador  = Vector3.new(-510, 502, -8),
		Combatiente = Vector3.new(-500, 502, -8),
		Craftero    = Vector3.new(-490, 502, -8),
	},

	-- Posiciones de los 3 cuadros de fiesta en el lobby
	POSICIONES_CUADROS = {
		Vector3.new(-516, 501.25, 8),
		Vector3.new(-500, 501.25, 8),
		Vector3.new(-484, 501.25, 8),
	},
}
