-- VarekUI.client.luau
-- Barra de vida del jefe Varek (arriba al centro de pantalla).
-- Se muestra al entrar a la Arena de Varek y se oculta al salir o al morir.
-- También muestra mensajes flotantes: advertencia de armadura, golpe de área, victoria.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local carpetaEventos = ReplicatedStorage:WaitForChild("Eventos")
local evVida         = carpetaEventos:WaitForChild("VarekVidaActualizada")
local evEstado       = carpetaEventos:WaitForChild("VarekEstado")
local evMensaje      = carpetaEventos:WaitForChild("VarekMensaje")

-- ============================================================
-- ScreenGui
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name          = "VarekUI"
screenGui.ResetOnSpawn  = false
screenGui.DisplayOrder  = 20
screenGui.Parent        = playerGui

-- ============================================================
-- Barra de vida del jefe (arriba al centro)
-- ============================================================
local marcoJefe = Instance.new("Frame")
marcoJefe.Name                   = "BarraVarek"
marcoJefe.AnchorPoint            = Vector2.new(0.5, 0)
marcoJefe.Size                   = UDim2.new(0, 420, 0, 54)
marcoJefe.Position               = UDim2.new(0.5, 0, 0, 10)
marcoJefe.BackgroundColor3       = Color3.fromRGB(12, 4, 4)
marcoJefe.BackgroundTransparency = 0.2
marcoJefe.BorderSizePixel        = 0
marcoJefe.Visible                = false   -- oculto hasta entrar a la arena
marcoJefe.Parent                 = screenGui

local cornerJefe = Instance.new("UICorner")
cornerJefe.CornerRadius = UDim.new(0, 10)
cornerJefe.Parent       = marcoJefe

local strokeJefe = Instance.new("UIStroke")
strokeJefe.Color     = Color3.fromRGB(180, 30, 30)
strokeJefe.Thickness = 2
strokeJefe.Parent    = marcoJefe

local paddingJefe = Instance.new("UIPadding")
paddingJefe.PaddingLeft   = UDim.new(0, 10)
paddingJefe.PaddingRight  = UDim.new(0, 10)
paddingJefe.PaddingTop    = UDim.new(0, 6)
paddingJefe.PaddingBottom = UDim.new(0, 6)
paddingJefe.Parent        = marcoJefe

-- Nombre del jefe
local lblNombre = Instance.new("TextLabel")
lblNombre.Size               = UDim2.new(1, 0, 0, 18)
lblNombre.BackgroundTransparency = 1
lblNombre.Text               = "VAREK"
lblNombre.Font               = Enum.Font.GothamBold
lblNombre.TextScaled         = true
lblNombre.TextColor3         = Color3.fromRGB(255, 80, 80)
lblNombre.TextXAlignment     = Enum.TextXAlignment.Center
lblNombre.LayoutOrder        = 1
lblNombre.Parent             = marcoJefe

-- Fondo de la barra
local barraFondo = Instance.new("Frame")
barraFondo.Size             = UDim2.new(1, 0, 0, 18)
barraFondo.Position         = UDim2.new(0, 0, 0, 28)
barraFondo.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
barraFondo.BorderSizePixel  = 0
barraFondo.Parent           = marcoJefe

local cornerBarra = Instance.new("UICorner")
cornerBarra.CornerRadius = UDim.new(0, 4)
cornerBarra.Parent       = barraFondo

-- Relleno de la barra (se escala con la vida)
local barraFill = Instance.new("Frame")
barraFill.Name              = "Fill"
barraFill.Size              = UDim2.new(1, 0, 1, 0)
barraFill.BackgroundColor3  = Color3.fromRGB(200, 30, 30)
barraFill.BorderSizePixel   = 0
barraFill.Parent            = barraFondo

local cornerFill = Instance.new("UICorner")
cornerFill.CornerRadius = UDim.new(0, 4)
cornerFill.Parent       = barraFill

-- Texto de HP numérico
local lblHP = Instance.new("TextLabel")
lblHP.Size               = UDim2.new(1, 0, 1, 0)
lblHP.BackgroundTransparency = 1
lblHP.Text               = "1500 / 1500"
lblHP.Font               = Enum.Font.GothamBold
lblHP.TextScaled         = true
lblHP.TextColor3         = Color3.fromRGB(255, 255, 255)
lblHP.TextXAlignment     = Enum.TextXAlignment.Center
lblHP.ZIndex             = 2
lblHP.Parent             = barraFondo

-- ============================================================
-- Label de mensaje flotante (advertencias + victoria)
-- ============================================================
local lblMensaje = Instance.new("TextLabel")
lblMensaje.AnchorPoint        = Vector2.new(0.5, 0)
lblMensaje.Size               = UDim2.new(0, 500, 0, 32)
lblMensaje.Position           = UDim2.new(0.5, 0, 0.32, 0)
lblMensaje.BackgroundTransparency = 1
lblMensaje.Text               = ""
lblMensaje.Font               = Enum.Font.GothamBold
lblMensaje.TextScaled         = true
lblMensaje.TextColor3         = Color3.fromRGB(255, 100, 100)
lblMensaje.TextTransparency   = 1
lblMensaje.TextStrokeTransparency = 0.4
lblMensaje.Parent             = screenGui

-- ============================================================
-- Funciones de actualización
-- ============================================================
local function actualizarBarra(vida, vidaMax)
	local pct = math.clamp(vida / vidaMax, 0, 1)
	barraFill.Size = UDim2.new(pct, 0, 1, 0)
	lblHP.Text     = math.floor(vida) .. " / " .. vidaMax
end

local function mostrarMensaje(texto, color)
	lblMensaje.Text             = texto
	lblMensaje.TextColor3       = color or Color3.fromRGB(255, 100, 100)
	lblMensaje.TextTransparency = 0
	TweenService:Create(
		lblMensaje,
		TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ TextTransparency = 1 }
	):Play()
end

-- ============================================================
-- Listeners de eventos del servidor
-- ============================================================
evVida.OnClientEvent:Connect(function(datos)
	if datos and datos.vida and datos.vidaMax then
		actualizarBarra(datos.vida, datos.vidaMax)
	end
end)

evEstado.OnClientEvent:Connect(function(datos)
	if datos and datos.visible ~= nil then
		marcoJefe.Visible = datos.visible
		if not datos.visible then
			-- Reiniciar barra al ocultar
			barraFill.Size = UDim2.new(1, 0, 1, 0)
			lblHP.Text     = "300 / 300"
		end
	end
end)

evMensaje.OnClientEvent:Connect(function(mensaje)
	if not mensaje then return end
	-- Mensajes de victoria en dorado, el resto en rojo
	local esVictoria = string.find(mensaje, "derrotado") ~= nil
	local color = esVictoria
		and Color3.fromRGB(255, 210, 60)
		or  Color3.fromRGB(255, 100, 100)
	mostrarMensaje(mensaje, color)
end)

print("[VarekUI] Interfaz del jefe Varek activa.")
