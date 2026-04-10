-- EquipoUI.client.luau
-- HUD esquina inferior derecha: muestra arma y armadura equipadas.
-- Se actualiza con el evento EquipoActualizado del servidor.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmasConfig  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ArmasConfig"))
local EquipoConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EquipoConfig"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local carpetaEventos      = ReplicatedStorage:WaitForChild("Eventos")
local evEquipoActualizado = carpetaEventos:WaitForChild("EquipoActualizado")

-- ============================================================
-- UI: Panel de equipo (esquina inferior derecha)
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name          = "EquipoUI"
screenGui.ResetOnSpawn  = false
screenGui.Parent        = playerGui

local marco = Instance.new("Frame")
marco.Name                   = "MarcoEquipo"
marco.AnchorPoint            = Vector2.new(1, 1)   -- ancla esquina inferior-derecha
marco.Size                   = UDim2.new(0, 195, 0, 0)
marco.Position               = UDim2.new(1, -12, 1, -12)
marco.AutomaticSize          = Enum.AutomaticSize.Y
marco.BackgroundColor3       = Color3.fromRGB(10, 10, 15)
marco.BackgroundTransparency = 0.35
marco.BorderSizePixel        = 0
marco.Parent                 = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent       = marco

local stroke = Instance.new("UIStroke")
stroke.Color     = Color3.fromRGB(90, 70, 110)
stroke.Thickness = 1.5
stroke.Parent    = marco

local padding = Instance.new("UIPadding")
padding.PaddingLeft   = UDim.new(0, 10)
padding.PaddingRight  = UDim.new(0, 10)
padding.PaddingTop    = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.Parent        = marco

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding   = UDim.new(0, 4)
layout.Parent    = marco

-- ── Fila de arma ────────────────────────────────────────────────
local filaArma = Instance.new("Frame")
filaArma.Size               = UDim2.new(1, 0, 0, 20)
filaArma.BackgroundTransparency = 1
filaArma.LayoutOrder        = 0
filaArma.Parent             = marco

local lblArmaIcono = Instance.new("TextLabel")
lblArmaIcono.Size               = UDim2.new(0, 22, 1, 0)
lblArmaIcono.BackgroundTransparency = 1
lblArmaIcono.Text               = ""
lblArmaIcono.TextScaled         = true
lblArmaIcono.Font               = Enum.Font.GothamBold
lblArmaIcono.TextColor3         = Color3.fromRGB(255, 190, 80)
lblArmaIcono.TextXAlignment     = Enum.TextXAlignment.Left
lblArmaIcono.Parent             = filaArma

local lblArma = Instance.new("TextLabel")
lblArma.Size                 = UDim2.new(1, -24, 1, 0)
lblArma.Position             = UDim2.new(0, 24, 0, 0)
lblArma.BackgroundTransparency = 1
lblArma.Text                 = "Palo"
lblArma.TextScaled           = true
lblArma.Font                 = Enum.Font.Gotham
lblArma.TextColor3           = Color3.fromRGB(255, 210, 130)
lblArma.TextXAlignment       = Enum.TextXAlignment.Left
lblArma.Parent               = filaArma

-- ── Fila de armadura ─────────────────────────────────────────────
local filaArmadura = Instance.new("Frame")
filaArmadura.Size               = UDim2.new(1, 0, 0, 20)
filaArmadura.BackgroundTransparency = 1
filaArmadura.LayoutOrder        = 1
filaArmadura.Parent             = marco

local lblArmaduraIcono = Instance.new("TextLabel")
lblArmaduraIcono.Size               = UDim2.new(0, 22, 1, 0)
lblArmaduraIcono.BackgroundTransparency = 1
lblArmaduraIcono.Text               = ""
lblArmaduraIcono.TextScaled         = true
lblArmaduraIcono.Font               = Enum.Font.GothamBold
lblArmaduraIcono.TextColor3         = Color3.fromRGB(120, 200, 255)
lblArmaduraIcono.TextXAlignment     = Enum.TextXAlignment.Left
lblArmaduraIcono.Parent             = filaArmadura

local lblArmadura = Instance.new("TextLabel")
lblArmadura.Size                 = UDim2.new(1, -24, 1, 0)
lblArmadura.Position             = UDim2.new(0, 24, 0, 0)
lblArmadura.BackgroundTransparency = 1
lblArmadura.Text                 = "Sin Armadura"
lblArmadura.TextScaled           = true
lblArmadura.Font                 = Enum.Font.Gotham
lblArmadura.TextColor3           = Color3.fromRGB(160, 210, 255)
lblArmadura.TextXAlignment       = Enum.TextXAlignment.Left
lblArmadura.Parent               = filaArmadura

-- ============================================================
-- Actualizar HUD
-- ============================================================
local function actualizarHUD(tipoArma, tipoArmadura)
	local infoArma = ArmasConfig.ARMAS[tipoArma]
	lblArma.Text   = infoArma and infoArma.nombre or "Palo"

	local infoArm = EquipoConfig.ARMADURAS[tipoArmadura]
	if infoArm then
		local pct = math.floor(infoArm.reduccion * 100)
		lblArmadura.Text = infoArm.nombre .. (pct > 0 and ("  -" .. pct .. "%") or "")
	else
		lblArmadura.Text = "Sin Armadura"
	end
end

-- Actualizar cuando el servidor notifica un cambio de equipo
evEquipoActualizado.OnClientEvent:Connect(function(datos)
	actualizarHUD(datos.arma, datos.armadura)
end)

-- Resetear al spawnear (el servidor enviará EquipoActualizado poco después)
player.CharacterAdded:Connect(function()
	actualizarHUD("Palo", "SinArmadura")
end)

print("[EquipoUI] HUD de equipo activo.")
