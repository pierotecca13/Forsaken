-- TrebolConfig.luau
-- Datos de las cuatro Hojas del Trébol (una por bioma).
-- No contiene lógica; solo se usa como fuente de datos.

return {

	-- Orden de visualización en el panel HUD
	ORDEN = { "Verde", "Azul", "Dorada", "Gris" },

	HOJAS = {
		Verde  = { nombre = "Bosque",   color = Color3.fromRGB(60,  160,  60)  },
		Azul   = { nombre = "Hielo",    color = Color3.fromRGB(70,  170, 230)  },
		Dorada = { nombre = "Desierto", color = Color3.fromRGB(220, 175,  40)  },
		Gris   = { nombre = "Rocoso",   color = Color3.fromRGB(150, 150, 150)  },
	},

	-- Nombre del atributo de jugador para cada hoja: "Hoja" .. tipo
	-- Ej: player:GetAttribute("HojaVerde")  → true/false
	PREFIJO_ATRIBUTO = "Hoja",
}
