-- CofresConfig.luau  (ModuleScript en ReplicatedStorage/Shared/)
-- Configuración de los cofres que aparecen en el mundo durante la partida.
-- Cada tipo tiene su propia rareza, recompensa y temporizador de spawn.

return {

	-- Definición de cada tipo de cofre
	TIPOS = {
		Madera = {
			nombre     = "Cofre de Madera",
			gemasMin   = 1,
			gemasMax   = 2,
			maxPartida = 5,      -- máximo que pueden aparecer en una partida
			intervalo  = 10,    -- segundos entre spawns (6 min)
			color      = Color3.fromRGB(139, 90, 43),
			material   = Enum.Material.Wood,
		},
		Piedra = {
			nombre     = "Cofre de Piedra",
			gemasMin   = 3,
			gemasMax   = 5,
			maxPartida = 3,
			intervalo  = 60,    -- 8 min
			color      = Color3.fromRGB(150, 150, 150),
			material   = Enum.Material.Slate,
		},
		Dorado = {
			nombre     = "Cofre Dorado",
			gemasMin   = 6,
			gemasMax   = 10,
			maxPartida = 2,
			intervalo  = 120,    -- 10 min
			color      = Color3.fromRGB(255, 200, 0),
			material   = Enum.Material.SmoothPlastic,
		},
	},

	-- Posiciones de spawn distribuidas por el mapa de juego.
	-- Quedan fuera de la arena de Varek (X~100, Z~120) y del campamento (0,0,-20).
	POSICIONES_SPAWN = {
		Vector3.new(15, 1, 10),
		Vector3.new(30, 1, 20),
		Vector3.new(50, 1, -5),
		Vector3.new(40, 1, 35),
		Vector3.new(60, 1, 50),
		Vector3.new(20, 1, 50),
		Vector3.new(70, 1, 20),
		Vector3.new(55, 1, 60),
		Vector3.new(10, 1, 40),
		Vector3.new(45, 1, 10),
		Vector3.new(65, 1, -10),
		Vector3.new(25, 1, -15),
		Vector3.new(35, 1, 55),
		Vector3.new(75, 1, 40),
		Vector3.new(80, 1, 60),
	},
}
