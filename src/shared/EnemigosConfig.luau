-- EnemigosConfig.luau
-- Definición de los 8 enemigos del Bosque (4 de día, 4 corrompidos de noche).
-- Importado por Enemigos.server.luau.

return {

	-- ============================================================
	-- Enemigos de DÍA (normales)
	-- comportamiento:
	--   "pasivo"   → huye; solo ataca si fue dañado primero
	--   "zorro"    → siempre huye, nunca ataca
	--   "agresivo" → persigue y ataca al detectar al jugador
	--   "cauto"    → solo ataca si el jugador se acerca mucho
	-- ============================================================
	ENEMIGOS = {

		Conejo = {
			nombre         = "Conejo",
			vida           = 15,
			dano           = 2,
			cooldown       = 0.8,
			velocidad      = 20,       -- velocidad al perseguir/atacar
			velocidadHuida = 13,       -- velocidad al huir (más lenta)
			rangoAtaque    = 3,
			rangoDeteccion = 14,       -- distancia a la que huye
			radioPatrulla  = 6,
			tiempoRespawn  = 20,
			maxInstancias  = 12,
			comportamiento = "pasivo",
			colorCuerpo    = Color3.fromRGB(235, 210, 185),
			colorCabeza    = Color3.fromRGB(215, 190, 160),
			tamCuerpo      = Vector3.new(0.9, 0.85, 1.1),
			tamCabeza      = Vector3.new(0.75, 0.75, 0.75),
			drops          = {
				{recurso = "CarneConejo", min = 0, max = 1},
			},
			puntosSpawn    = {
				Vector3.new(15, 3, 10),
				Vector3.new(25, 3, 5),
				Vector3.new(10, 3, 20),
				Vector3.new(30, 3, -5),
				Vector3.new(8,  3, -12),
			},
		},

		Zorro = {
			nombre         = "Zorro",
			vida           = 30,
			dano           = 5,
			cooldown       = 1.0,
			velocidad      = 18,
			rangoAtaque    = 4,
			rangoDeteccion = 18,
			radioPatrulla  = 8,
			tiempoRespawn  = 30,
			maxInstancias  = 8,
			comportamiento = "pasivo",  -- huye; ataca si fue dañado
			colorCuerpo    = Color3.fromRGB(200, 100, 30),
			colorCabeza    = Color3.fromRGB(175, 85, 25),
			tamCuerpo      = Vector3.new(1.2, 0.9, 1.6),
			tamCabeza      = Vector3.new(0.9, 0.8, 1.0),
			drops          = {
				{recurso = "Piel",      min = 1, max = 2},
				{recurso = "CarneZorro", min = 0, max = 1},
			},
			puntosSpawn    = {
				Vector3.new(35, 3, 10),
				Vector3.new(20, 3, 30),
				Vector3.new(45, 3, -10),
			},
		},

		Lobo = {
			nombre         = "Lobo",
			vida           = 45,
			dano           = 10,
			cooldown       = 1.2,
			velocidad      = 16,
			rangoAtaque    = 4.5,
			rangoDeteccion = 20,
			radioPatrulla  = 12,
			tiempoRespawn  = 40,
			maxInstancias  = 8,
			comportamiento = "agresivo",
			colorCuerpo    = Color3.fromRGB(80, 80, 95),
			colorCabeza    = Color3.fromRGB(65, 65, 80),
			tamCuerpo      = Vector3.new(2, 2, 1),
			tamCabeza      = Vector3.new(1.2, 1.2, 1.2),
			drops          = {
				{recurso = "Piel",      min = 1, max = 3},
				{recurso = "Colmillo",  min = 1, max = 1},
				{recurso = "CarneLobo", min = 0, max = 2},
			},
			puntosSpawn    = {
				Vector3.new(40, 3, 15),
				Vector3.new(55, 3, -5),
				Vector3.new(25, 3, 45),
				Vector3.new(60, 3, 30),
			},
		},

		Oso = {
			nombre         = "Oso",
			vida           = 75,
			dano           = 15,
			cooldown       = 1.8,
			velocidad      = 12,
			rangoAtaque    = 6,
			rangoDeteccion = 8,      -- solo ataca si el jugador se acerca mucho
			radioPatrulla  = 18,
			tiempoRespawn  = 60,
			maxInstancias  = 4,
			comportamiento = "cauto",
			colorCuerpo    = Color3.fromRGB(100, 70, 40),
			colorCabeza    = Color3.fromRGB(85, 58, 33),
			tamCuerpo      = Vector3.new(2.5, 2.5, 1.5),
			tamCabeza      = Vector3.new(1.8, 1.6, 1.5),
			drops          = {
				{recurso = "Piel",     min = 1, max = 4},
				{recurso = "Garra",    min = 1, max = 1},
				{recurso = "CarneOso", min = 1, max = 2},
			},
			puntosSpawn    = {
				Vector3.new(15, 3, 65),
				Vector3.new(75, 3, 45),
			},
		},

	},

	-- ============================================================
	-- Versiones CORROMPIDAS (de NOCHE)
	-- Solo se incluyen los campos que difieren del enemigo base.
	-- El servidor hace merge con los stats del enemigo normal.
	-- comportamiento extra:
	--   "corrupto_lobo" → persigue en grupo con lobos cercanos
	--   "oso_sombra"    → golpe en área que empuja al jugador
	-- ============================================================
	CORROMPIDOS = {

		Conejo = {
			nombre         = "Conejo Corrompido",
			vida           = 20,
			dano           = 5,
			cooldown       = 0.7,
			velocidad      = 24,
			rangoDeteccion = 16,
			comportamiento = "agresivo",  -- ataca siempre
			colorCuerpo    = Color3.fromRGB(45, 12, 12),
			colorCabeza    = Color3.fromRGB(35, 8, 8),
			drops          = {
				{recurso = "CarneConejo", min = 0, max = 2},
			},
		},

		Zorro = {
			nombre         = "Zorro Corrompido",
			vida           = 35,
			dano           = 8,
			cooldown       = 0.9,
			velocidad      = 22,
			rangoDeteccion = 22,
			comportamiento = "agresivo",
			colorCuerpo    = Color3.fromRGB(55, 18, 8),
			colorCabeza    = Color3.fromRGB(45, 12, 5),
			drops          = {
				{recurso = "Piel",       min = 2, max = 4},
				{recurso = "CarneZorro", min = 0, max = 2},
			},
		},

		Lobo = {
			nombre         = "Lobo Corrompido",
			vida           = 50,
			dano           = 13,
			cooldown       = 1.0,
			velocidad      = 18,
			rangoDeteccion = 25,
			comportamiento = "corrupto_lobo",
			colorCuerpo    = Color3.fromRGB(20, 8, 35),
			colorCabeza    = Color3.fromRGB(15, 5, 28),
			drops          = {
				{recurso = "Piel",      min = 2, max = 6},
				{recurso = "Colmillo",  min = 2, max = 2},
				{recurso = "CarneLobo", min = 1, max = 4},
			},
		},

		Oso = {
			nombre         = "Oso de Sombra",
			vida           = 80,
			dano           = 18,
			cooldown       = 2.0,
			velocidad      = 14,
			rangoAtaque    = 8,
			rangoDeteccion = 18,
			comportamiento = "oso_sombra",
			colorCuerpo    = Color3.fromRGB(8, 3, 18),
			colorCabeza    = Color3.fromRGB(5, 2, 12),
			drops          = {
				{recurso = "Piel",     min = 2, max = 8},
				{recurso = "Garra",    min = 2, max = 2},
				{recurso = "CarneOso", min = 2, max = 4},
			},
		},

	},
}
