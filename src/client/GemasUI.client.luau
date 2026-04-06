-- GemasUI.client.luau
-- Muestra el saldo de Gemas en pantalla (esquina superior derecha).
-- Las gemas son moneda global: no son ítems de inventario.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local carpetaEventos = ReplicatedStorage:WaitForChild("Eventos")
local evGemas        = carpetaEventos:WaitForChild("GemasActualizadas")

-- ============================================================
-- UI: Chip de gemas (esquina superior derecha)
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name          = "GemasUI"
screenGui.ResetOnSpawn  = false
screenGui.DisplayOrder  = 11
screenGui.Parent        = playerGui

local chip = Instance.new("Frame")
chip.Name                   = "ChipGemas"
chip.AnchorPoint            = Vector2.new(1, 0)
chip.Size                   = UDim2.new(0, 96, 0, 24)
chip.Position               = UDim2.new(1, -12, 0, 0)
chip.BackgroundColor3       = Color3.fromRGB(10, 10, 15)
chip.BackgroundTransparency = 0.3
chip.BorderSizePixel        = 0
chip.Parent                 = screenGui

local cornerChip = Instance.new("UICorner")
cornerChip.CornerRadius = UDim.new(0, 8)
cornerChip.Parent       = chip

local strokeChip = Instance.new("UIStroke")
strokeChip.Color     = Color3.fromRGB(220, 175, 40)
strokeChip.Thickness = 1.5
strokeChip.Parent    = chip

-- Icono de gema (texto emoji/carácter)
local lblIcono = Instance.new("TextLabel")
lblIcono.Size               = UDim2.new(0, 28, 1, 0)
lblIcono.Position           = UDim2.new(0, 4, 0, 0)
lblIcono.BackgroundTransparency = 1
lblIcono.Text               = "◆"
lblIcono.Font               = Enum.Font.GothamBold
lblIcono.TextScaled         = true
lblIcono.TextColor3         = Color3.fromRGB(255, 215, 50)
lblIcono.Parent             = chip

-- Contador numérico
local lblCantidad = Instance.new("TextLabel")
lblCantidad.Name             = "Cantidad"
lblCantidad.Size             = UDim2.new(1, -36, 1, 0)
lblCantidad.Position         = UDim2.new(0, 34, 0, 0)
lblCantidad.BackgroundTransparency = 1
lblCantidad.Text             = "0"
lblCantidad.Font             = Enum.Font.GothamBold
lblCantidad.TextScaled       = true
lblCantidad.TextColor3       = Color3.fromRGB(255, 230, 120)
lblCantidad.TextXAlignment   = Enum.TextXAlignment.Left
lblCantidad.Parent           = chip

-- ============================================================
-- Animación de delta (+X verde / -X rojo)
-- ============================================================
local TweenService   = game:GetService("TweenService")
local cantidadActual = nil   -- nil en el primer sync para no animar

local function mostrarDelta(delta)
	if delta == 0 then return end

	local lbl = Instance.new("TextLabel")
	lbl.Size                    = UDim2.new(0, 90, 0, 22)
	lbl.AnchorPoint             = Vector2.new(1, 0)
	lbl.Position                = UDim2.new(1, -12, 0, 46)   -- debajo del chip
	lbl.BackgroundTransparency  = 1
	lbl.Font                    = Enum.Font.GothamBold
	lbl.TextSize                = 16
	lbl.TextXAlignment          = Enum.TextXAlignment.Right
	lbl.TextColor3              = delta > 0
		and Color3.fromRGB(80, 255, 100)   -- verde para ganancias
		or  Color3.fromRGB(255, 80, 80)    -- rojo para gastos
	lbl.Text                    = delta > 0 and ("+" .. delta) or tostring(delta)
	lbl.TextTransparency        = 0
	lbl.ZIndex                  = 20
	lbl.Parent                  = screenGui

	TweenService:Create(lbl,
		TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(1, -12, 0, 8), TextTransparency = 1 }
	):Play()

	task.delay(1.6, function()
		if lbl and lbl.Parent then lbl:Destroy() end
	end)
end

-- ============================================================
-- Actualizar al recibir evento del servidor
-- ============================================================
evGemas.OnClientEvent:Connect(function(cantidad)
	if cantidadActual ~= nil then
		mostrarDelta(cantidad - cantidadActual)
	end
	cantidadActual   = cantidad
	lblCantidad.Text = tostring(cantidad)
end)

print("[GemasUI] Contador de gemas activo.")
