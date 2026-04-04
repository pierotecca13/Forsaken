-- EquipoConfig.luau
-- Configuración de armas crafteables y armaduras de la Mesa de Trabajo.
-- Usado por servidor (Equipo.server) y cliente (MesaUI, EquipoUI).

return {

	-- ── ARMAS ────────────────────────────────────────────────────────
	-- Orden de progresión. "Palo" es el arma inicial (no crafteable).
	-- Solo se puede craftear el siguiente nivel si se tiene el anterior.
	ORDEN_ARMAS = {
		"Palo",           -- inicial, no crafteable en mesa
		"HachaPiedra",
		"EspadaHierro",
		"EspadaCristal",
		"LanzaLuz",
	},

	-- Costo de crafteo por arma (Palo no aparece = no crafteable)
	CRAFTEO_ARMAS = {
		HachaPiedra   = { costo = { Piedra = 5, Madera = 5 } },
		EspadaHierro  = { costo = { Hierro = 8, Piel   = 2 } },
		EspadaCristal = { costo = { Cristal = 6, Hierro = 4 } },
		LanzaLuz      = { costo = { Cristal = 5, Hierro = 5, Garra = 1, Colmillo = 1 } },
	},

	-- ── ARMADURAS ────────────────────────────────────────────────────
	-- Orden de progresión: solo se puede mejorar un nivel a la vez.
	-- "SinArmadura" es el estado inicial (no crafteable).
	ORDEN_ARMADURAS = {
		"SinArmadura",
		"CueroPrimario",
		"CueroReforzado",
		"ArmaduraHierro",
		"ArmaduraCristal",
	},

	ARMADURAS = {
		SinArmadura = {
			nombre    = "Sin Armadura",
			reduccion = 0,
			-- sin costo: estado inicial
		},
		CueroPrimario = {
			nombre    = "Armadura de Cuero",
			reduccion = 0.10,
			costo     = { Piel = 8 },
		},
		CueroReforzado = {
			nombre    = "Cuero Reforzado",
			reduccion = 0.20,
			costo     = { Piel = 12, Colmillo = 3 },
		},
		ArmaduraHierro = {
			nombre    = "Armadura de Hierro",
			reduccion = 0.35,
			costo     = { Hierro = 10, Piel = 4 },
		},
		ArmaduraCristal = {
			nombre    = "Armadura de Cristal",
			reduccion = 0.50,
			costo     = { Cristal = 8, Hierro = 6 },
		},
	},

	ARMADURA_INICIAL = "SinArmadura",
}
