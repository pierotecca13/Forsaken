-- TrebolUI.client.luau
-- Panel HUD de las Hojas del Trébol (esquina inferior derecha).
-- Muestra 4 celdas en cuadrícula 2×2 que se iluminan al obtener cada hoja.
-- Disposición:
--   [ Verde ][ Azul  ]
--   [ Gris  ][ Dorada]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrebolConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrebolConfig"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local carpetaEventos = ReplicatedStorage:WaitForChild("Eventos")
local evHoja         = carpetaEventos:WaitForChild("HojaTrebolActualizada")

-- ============================================================
-- Constantes de diseño
-- ============================================================
local TAMANO_CELDA  = 26   -- px de cada celda (antes 36, ahora fila única)
local ESPACIADO     = 3    -- px entre celdas
local COLOR_VACIA   = Color3.fromRGB(28, 28, 32)
local COLOR_BORDE   = Color3.fromRGB(60, 55, 70)
local ALPHA_VACIA   = 0.35

-- Disposición 4×1: una sola fila horizontal  B | H | R | D
local DISPOSICION = {
	Verde  = { fila = 1, col = 1 },
	Azul   = { fila = 1, col = 2 },
	Gris   = { fila = 1, col = 3 },
	Dorada = { fila = 1, col = 4 },
}

-- ============================================================
-- ScreenGui
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name          = "TrebolUI"
screenGui.ResetOnSpawn  = false
screenGui.DisplayOrder  = 12
screenGui.Parent        = playerGui

-- Marco contenedor: 4 celdas en una sola fila
local ancho = TAMANO_CELDA * 4 + ESPACIADO * 3
local alto  = TAMANO_CELDA

local marco = Instance.new("Frame")
marco.Name                   = "MarcoTrebol"
marco.AnchorPoint            = Vector2.new(1, 1)
marco.Size                   = UDim2.new(0, ancho + 10, 0, alto + 10)
-- Queda encima del EquipoUI (~54 px) con 8 px de separación
marco.Position               = UDim2.new(1, -12, 1, -76)
marco.BackgroundColor3       = Color3.fromRGB(10, 10, 15)
marco.BackgroundTransparency = 0.4
marco.BorderSizePixel        = 0
marco.Parent                 = screenGui

local cornerMarco = Instance.new("UICorner")
cornerMarco.CornerRadius = UDim.new(0, 8)
cornerMarco.Parent       = marco

local strokeMarco = Instance.new("UIStroke")
strokeMarco.Color     = COLOR_BORDE
strokeMarco.Thickness = 1.2
strokeMarco.Parent    = marco

-- ============================================================
-- Crear las 4 celdas
-- ============================================================
local celdas = {}   -- celdas[tipo] = Frame celda

for tipo, pos in pairs(DISPOSICION) do
	local info  = TrebolConfig.HOJAS[tipo]
	local xBase = 5 + (pos.col - 1) * (TAMANO_CELDA + ESPACIADO)
	local yBase = 5   -- fila única, siempre en Y=5

	local celda = Instance.new("Frame")
	celda.Name                   = "Celda_" .. tipo
	celda.Size                   = UDim2.new(0, TAMANO_CELDA, 0, TAMANO_CELDA)
	celda.Position               = UDim2.new(0, xBase, 0, yBase)
	celda.BackgroundColor3       = COLOR_VACIA
	celda.BackgroundTransparency = ALPHA_VACIA
	celda.BorderSizePixel        = 0
	celda.Parent                 = marco

	local cornerCelda = Instance.new("UICorner")
	cornerCelda.CornerRadius = UDim.new(0, 6)
	cornerCelda.Parent       = celda

	local strokeCelda = Instance.new("UIStroke")
	strokeCelda.Color     = COLOR_BORDE
	strokeCelda.Thickness = 1
	strokeCelda.Parent    = celda

	-- Inicial del bioma (centrada)
	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = string.sub(info.nombre, 1, 1)   -- primera letra del bioma
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextScaled         = true
	lbl.TextColor3         = Color3.fromRGB(70, 70, 80)
	lbl.TextXAlignment     = Enum.TextXAlignment.Center
	lbl.Parent             = celda

	celdas[tipo] = { frame = celda, lbl = lbl, strokeCelda = strokeCelda }
end

-- ============================================================
-- Actualizar celda al obtener/perder una hoja
-- ============================================================
local function actualizarCelda(tipo, tiene)
	local ref  = celdas[tipo]
	local info = TrebolConfig.HOJAS[tipo]
	if not ref or not info then return end

	if tiene then
		ref.frame.BackgroundColor3       = info.color
		ref.frame.BackgroundTransparency = 0.1
		ref.lbl.TextColor3               = Color3.fromRGB(255, 255, 255)
		ref.strokeCelda.Color            = info.color
	else
		ref.frame.BackgroundColor3       = COLOR_VACIA
		ref.frame.BackgroundTransparency = ALPHA_VACIA
		ref.lbl.TextColor3               = Color3.fromRGB(70, 70, 80)
		ref.strokeCelda.Color            = COLOR_BORDE
	end
end

-- ============================================================
-- Escuchar actualizaciones del servidor
-- ============================================================
evHoja.OnClientEvent:Connect(function(tipo, tiene)
	actualizarCelda(tipo, tiene)
end)

print("[TrebolUI] Panel de Hojas del Trébol activo.")
