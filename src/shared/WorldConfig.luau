-- WorldConfig.luau  (ModuleScript en ReplicatedStorage/Shared/)
-- Configuración central de todos los biomas del mundo.
-- Los biomas Hielo, Desierto, Rocoso y Final se completan en fases posteriores.

local M = {}

-- ============================================================
-- Límites de cada zona en coordenadas del mundo
-- Layout:
--   BOSQUE  | HIELO
--   --------+--------
--   DESIERTO| ROCOSO
-- con FINAL en el centro
-- ============================================================
M.ZONAS = {
	Bosque = {
		minX = -400, maxX = 120,
		minZ = -400, maxZ = 120,
		sueloColor    = Color3.fromRGB(45, 75, 35),
		sueloMaterial = Enum.Material.Grass,
		nieblaDia = {
			color     = Color3.fromRGB(30, 50, 25),
			distancia = 300,
		},
		-- Todos los objetos son interactivos (sin separación decorativo/interactivo)
		recursos = {
			{ tipo = "Arbol", cantidad = 40, espaciado = 22 },
			{ tipo = "Roca",  cantidad = 20, espaciado = 20 },
			{ tipo = "Hongo", cantidad = 20, espaciado = 12 },
		},
		-- Zona excluida del campamento y spawn
		exclusiones = {
			{ centro = Vector3.new(0, 0, -20), radio = 28 },
			{ centro = Vector3.new(5, 0, -14), radio = 15 },
		},
	},

	Hielo = {
		minX = -120, maxX = 400,
		minZ = -400, maxZ = 120,
		sueloColor    = Color3.fromRGB(180, 210, 240),
		sueloMaterial = Enum.Material.Ice,
		nieblaDia     = { color = Color3.fromRGB(160, 195, 225), distancia = 350 },
		recursos      = {},
		exclusiones   = {},
	},

	Desierto = {
		minX = -400, maxX = 120,
		minZ = -120, maxZ = 400,
		sueloColor    = Color3.fromRGB(210, 175, 90),
		sueloMaterial = Enum.Material.Sand,
		nieblaDia     = { color = Color3.fromRGB(200, 165, 80), distancia = 400 },
		recursos      = {},
		exclusiones   = {},
	},

	Rocoso = {
		minX = -120, maxX = 400,
		minZ = -120, maxZ = 400,
		sueloColor    = Color3.fromRGB(90, 80, 75),
		sueloMaterial = Enum.Material.Slate,
		nieblaDia     = { color = Color3.fromRGB(80, 72, 68), distancia = 280 },
		recursos      = {},
		exclusiones   = {},
	},

	Final = {
		minX = -120, maxX = 120,
		minZ = -120, maxZ = 120,
		sueloColor    = Color3.fromRGB(15, 10, 25),
		sueloMaterial = Enum.Material.Basalt,
		nieblaDia     = { color = Color3.fromRGB(40, 10, 60), distancia = 150 },
		recursos      = {},
		exclusiones   = {},
	},
}

return M
