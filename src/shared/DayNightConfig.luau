-- DayNightConfig.luau
-- Configuración centralizada del ciclo día/noche.
-- Modificar aquí para ajustar tiempos e iluminación sin tocar la lógica.

return {
	-- Duración de cada fase en segundos
	DURACION_DIA   = 240,  -- 4 minutos de día
	DURACION_NOCHE = 120,  -- 2 minutos de noche

	-- Porcentaje del final de cada fase usado para la transición gradual
	-- 0.15 = los últimos 15% del día se oscurece (≈36s), primeros 15% de noche se mantiene oscuro
	MARGEN_TRANSICION = 0.15,

	-- ClockTime de Roblox (0-24) para inicio de cada fase
	HORA_INICIO_DIA   = 7,   -- amanecer
	HORA_INICIO_NOCHE = 19,  -- atardecer

	-- Iluminación diurna
	LUZ_DIA = {
		Brightness     = 2.0,
		Ambient        = Color3.fromRGB(105, 115, 135),
		OutdoorAmbient = Color3.fromRGB(145, 160, 185),
		FogEnd         = 1000,
		FogColor       = Color3.fromRGB(180, 195, 215),
	},

	-- Iluminación nocturna (oscura, densa, amenazante)
	LUZ_NOCHE = {
		Brightness     = 0.08,
		Ambient        = Color3.fromRGB(8, 8, 28),
		OutdoorAmbient = Color3.fromRGB(12, 12, 38),
		FogEnd         = 160,
		FogColor       = Color3.fromRGB(5, 5, 18),
	},
}
