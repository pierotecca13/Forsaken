-- MesaConfig.luau
-- Configuración de la Mesa de Trabajo: costo de construcción,
-- recetas crafteables, propiedades de luz y radio de repulsión de enemigos.

return {

	-- Costo para construir la mesa desde el Campamento
	COSTO_CONSTRUCCION = { Madera = 2, Piedra = 2 },

	-- Posición en el mundo donde aparece la mesa (cerca del Campamento Base)
	POSICION_MESA = Vector3.new(7, 1.25, -28),

	-- Recetas disponibles en la mesa
	RECETAS = {
		Antorcha = {
			nombre        = "Antorcha",
			costo         = { Madera = 3 },
			maxInventario = 3,       -- máximo que se puede cargar al mismo tiempo
			duracion      = 120,     -- segundos que dura encendida (= 1 noche)
			radioLuz      = 14,      -- studs de iluminación
			brilloLuz     = 2.5,
			colorLuz      = Color3.fromRGB(255, 160, 60),
		},
		Hoguera = {
			nombre           = "Hoguera Portátil",
			costo            = { Madera = 8 },
			maxInventario    = 1,
			duracion         = 360,   -- segundos (= 3 noches)
			radioLuz         = 28,
			brilloLuz        = 5.5,
			colorLuz         = Color3.fromRGB(255, 110, 25),
			radioRepulsion   = 22,    -- enemigos corrompidos evitan este radio
		},
	},

	-- Orden de visualización en el menú de crafteo
	ORDEN_RECETAS = { "Antorcha", "Hoguera" },
}
