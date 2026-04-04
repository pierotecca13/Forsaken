-- StaminaConfig.luau
-- Configuración del sistema de stamina.
-- Importado por el cliente y, en el futuro, por el sistema de combate.

return {
	MAXIMO                      = 100,

	-- Velocidades del Humanoid (studs/segundo)
	VELOCIDAD_NORMAL            = 16,   -- velocidad por defecto de Roblox
	VELOCIDAD_SPRINT            = 26,   -- al correr

	-- Tasas por segundo
	CONSUMO_SPRINT              = 10,   -- stamina que pierde al correr
	RECUPERACION_BASE           = 8,    -- stamina que recupera parado/caminando

	-- Umbral mínimo para volver a correr después de agotarse
	UMBRAL_RECUPERACION         = 20,

	-- Multiplicador de recuperación de noche (0.8 = 20% más lento)
	MULT_RECUPERACION_NOCHE     = 0.8,
}
