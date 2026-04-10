-- LobbyUI.client.luau
-- HUD mínimo del lobby: título, gemas y estado del kit.
-- Los cuadros de fiesta se muestran en el mundo 3D (BillboardGui + ProximityPrompt).
-- Solo visible cuando el jugador está en el lobby.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- Eventos remotos
-- ============================================================
local carpetaEventos      = ReplicatedStorage:WaitForChild("Eventos")
local evLobbyEntrar       = carpetaEventos:WaitForChild("LobbyEntrar")
local evLobbyResultadoKit = carpetaEventos:WaitForChild("LobbyResultadoKit")
local evGemas             = carpetaEventos:WaitForChild("GemasActualizadas")

-- ============================================================
-- ScreenGui principal (inicialmente oculto)
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name         = "LobbyUI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 20
screenGui.Enabled      = false
screenGui.Parent       = playerGui

local fondo = Instance.new("Frame")
fondo.Size                   = UDim2.new(1, 0, 1, 0)
fondo.BackgroundTransparency = 1
fondo.BorderSizePixel        = 0
fondo.Parent                 = screenGui

-- ── Título "FORSAKEN" (arriba al centro) ─────────────────────
local titulo = Instance.new("TextLabel")
titulo.Size                   = UDim2.new(0, 400, 0, 80)
titulo.Position               = UDim2.new(0.5, -200, 0, 24)
titulo.BackgroundTransparency = 1
titulo.Text                   = "FORSAKEN"
titulo.TextColor3             = Color3.fromRGB(220, 200, 140)
titulo.TextScaled             = true
titulo.Font                   = Enum.Font.GothamBold
titulo.TextStrokeTransparency = 0.4
titulo.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
titulo.Parent                 = fondo

-- ── Gemas (arriba derecha) ────────────────────────────────────
local gemFrame = Instance.new("Frame")
gemFrame.Size                   = UDim2.new(0, 130, 0, 36)
gemFrame.Position               = UDim2.new(1, -142, 0, 12)
gemFrame.BackgroundColor3       = Color3.fromRGB(20, 20, 30)
gemFrame.BackgroundTransparency = 0.3
gemFrame.BorderSizePixel        = 0
gemFrame.Parent                 = fondo

local _gc = Instance.new("UICorner")
_gc.CornerRadius = UDim.new(0, 8)
_gc.Parent       = gemFrame

local _gs = Instance.new("UIStroke")
_gs.Color     = Color3.fromRGB(120, 80, 200)
_gs.Thickness = 1.5
_gs.Parent    = gemFrame

local gemLabel = Instance.new("TextLabel")
gemLabel.Size                   = UDim2.new(1, -8, 1, 0)
gemLabel.Position               = UDim2.new(0, 8, 0, 0)
gemLabel.BackgroundTransparency = 1
gemLabel.Text                   = "◆ 0"
gemLabel.TextColor3             = Color3.fromRGB(200, 160, 255)
gemLabel.TextScaled             = true
gemLabel.Font                   = Enum.Font.GothamBold
gemLabel.TextXAlignment         = Enum.TextXAlignment.Left
gemLabel.Parent                 = gemFrame

-- ── Panel de kit activo (debajo del título) ───────────────────
local kitFrame = Instance.new("Frame")
kitFrame.Size                   = UDim2.new(0, 300, 0, 52)
kitFrame.Position               = UDim2.new(0.5, -150, 0, 115)
kitFrame.BackgroundColor3       = Color3.fromRGB(20, 25, 20)
kitFrame.BackgroundTransparency = 0.4
kitFrame.BorderSizePixel        = 0
kitFrame.Parent                 = fondo

local _kc = Instance.new("UICorner")
_kc.CornerRadius = UDim.new(0, 8)
_kc.Parent       = kitFrame

local _ks = Instance.new("UIStroke")
_ks.Color     = Color3.fromRGB(60, 100, 60)
_ks.Thickness = 1.5
_ks.Parent    = kitFrame

local kitLabel = Instance.new("TextLabel")
kitLabel.Size                   = UDim2.new(1, -12, 0.5, 0)
kitLabel.Position               = UDim2.new(0, 6, 0.05, 0)
kitLabel.BackgroundTransparency = 1
kitLabel.Text                   = "Sin kit comprado  •  200 ◆ cada uno"
kitLabel.TextColor3             = Color3.fromRGB(160, 200, 160)
kitLabel.TextScaled             = true
kitLabel.Font                   = Enum.Font.Gotham
kitLabel.Parent                 = kitFrame

local kitSubLabel = Instance.new("TextLabel")
kitSubLabel.Size                   = UDim2.new(1, -12, 0.45, 0)
kitSubLabel.Position               = UDim2.new(0, 6, 0.52, 0)
kitSubLabel.BackgroundTransparency = 1
kitSubLabel.Text                   = "Acércate a un cofre y presiona E para comprar"
kitSubLabel.TextColor3             = Color3.fromRGB(120, 140, 120)
kitSubLabel.TextScaled             = true
kitSubLabel.Font                   = Enum.Font.Gotham
kitSubLabel.Parent                 = kitFrame

-- ── Toast de notificación ─────────────────────────────────────
local toast = Instance.new("Frame")
toast.Size                   = UDim2.new(0, 300, 0, 40)
toast.Position               = UDim2.new(0.5, -150, 0, 176)
toast.BackgroundColor3       = Color3.fromRGB(20, 50, 20)
toast.BackgroundTransparency = 0.2
toast.BorderSizePixel        = 0
toast.Visible                = false
toast.Parent                 = fondo

local _tc = Instance.new("UICorner")
_tc.CornerRadius = UDim.new(0, 6)
_tc.Parent       = toast

local toastLabel = Instance.new("TextLabel")
toastLabel.Size                   = UDim2.new(1, -12, 1, 0)
toastLabel.Position               = UDim2.new(0, 6, 0, 0)
toastLabel.BackgroundTransparency = 1
toastLabel.TextColor3             = Color3.fromRGB(180, 255, 180)
toastLabel.TextScaled             = true
toastLabel.Font                   = Enum.Font.Gotham
toastLabel.Parent                 = toast

-- ============================================================
-- Toast
-- ============================================================
local toastActivo = false
local function mostrarToast(mensaje, esExito)
	toastLabel.Text        = mensaje
	toastLabel.TextColor3  = esExito and Color3.fromRGB(180, 255, 180) or Color3.fromRGB(255, 120, 120)
	toast.BackgroundColor3 = esExito and Color3.fromRGB(20, 50, 20)   or Color3.fromRGB(50, 20, 20)
	toast.BackgroundTransparency = 0.2
	toast.Visible  = true
	toastActivo    = true

	task.delay(2.5, function()
		if not toastActivo then return end
		local tw = TweenService:Create(toast,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		)
		tw:Play()
		tw.Completed:Once(function()
			toast.Visible = false
			toast.BackgroundTransparency = 0.2
			toastActivo = false
		end)
	end)
end

-- ============================================================
-- Ocultar / restaurar UIs del juego
-- ============================================================
local uisJuego = {
	"InventarioUI", "VidaUI", "DayNightUI", "EquipoUI",
	"TrebolUI", "StaminaUI", "GemasUI", "VarekUI",
}

local function ocultarUIsJuego()
	for _, nombre in ipairs(uisJuego) do
		local gui = playerGui:FindFirstChild(nombre)
		if gui then gui.Enabled = false end
	end
end

local function mostrarUIsJuego()
	for _, nombre in ipairs(uisJuego) do
		local gui = playerGui:FindFirstChild(nombre)
		if gui then gui.Enabled = true end
	end
end

-- ============================================================
-- Mostrar / ocultar lobby
-- ============================================================
local function mostrarLobby()
	screenGui.Enabled = true
	ocultarUIsJuego()

	kitLabel.Text       = "Sin kit comprado  •  200 ◆ cada uno"
	kitLabel.TextColor3 = Color3.fromRGB(160, 200, 160)
	kitSubLabel.Text    = "Acércate a un cofre y presiona E para comprar"

	local gemas = player:GetAttribute("Gemas") or 0
	gemLabel.Text = "◆ " .. gemas
end

local function ocultarLobby()
	screenGui.Enabled = false
	mostrarUIsJuego()
end

-- Detectar cuando el personaje reaparece ya en el juego (EnLobby=false)
player.CharacterAdded:Connect(function()
	task.wait(0.2)
	if player:GetAttribute("EnLobby") == false then
		ocultarLobby()
	end
end)

-- ============================================================
-- Listeners
-- ============================================================
evLobbyEntrar.OnClientEvent:Connect(function()
	mostrarLobby()
end)

evLobbyResultadoKit.OnClientEvent:Connect(function(ok, mensaje)
	mostrarToast(mensaje, ok)
	if ok then
		local kitComprado = player:GetAttribute("KitComprado")
		if kitComprado then
			kitLabel.Text       = "Kit activo: " .. kitComprado .. " ✓"
			kitLabel.TextColor3 = Color3.fromRGB(180, 255, 180)
			kitSubLabel.Text    = "Se aplicará al comenzar la partida"
		end
	end
end)

evGemas.OnClientEvent:Connect(function(cantidad)
	gemLabel.Text = "◆ " .. cantidad
end)

-- ============================================================
-- Pantalla de carga de sesión (visible mientras se genera el mundo)
-- ============================================================
local loadingGui = Instance.new("ScreenGui")
loadingGui.Name            = "LoadingScreen"
loadingGui.ResetOnSpawn    = false
loadingGui.DisplayOrder    = 100  -- por encima de todas las demás UIs
loadingGui.IgnoreGuiInset  = true -- cubre toda la pantalla, incluyendo el área del top bar
loadingGui.Enabled         = false
loadingGui.Parent          = playerGui

local loadingFondo = Instance.new("Frame")
loadingFondo.Size                   = UDim2.new(1, 0, 1, 0)
loadingFondo.BackgroundColor3       = Color3.fromRGB(5, 5, 10)
loadingFondo.BackgroundTransparency = 0
loadingFondo.BorderSizePixel        = 0
loadingFondo.Parent                 = loadingGui

local loadingLabel = Instance.new("TextLabel")
loadingLabel.Size                   = UDim2.new(0, 440, 0, 60)
loadingLabel.Position               = UDim2.new(0.5, -220, 0.5, -30)
loadingLabel.BackgroundTransparency = 1
loadingLabel.Text                   = "Generando mundo..."
loadingLabel.TextColor3             = Color3.fromRGB(220, 200, 140)
loadingLabel.TextScaled             = true
loadingLabel.Font                   = Enum.Font.GothamBold
loadingLabel.TextStrokeTransparency = 0.4
loadingLabel.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
loadingLabel.Parent                 = loadingFondo

local evSesionPreparando = carpetaEventos:WaitForChild("SesionPreparando", 30)
local evSesionLista      = carpetaEventos:WaitForChild("SesionLista", 30)

if evSesionPreparando then
	evSesionPreparando.OnClientEvent:Connect(function()
		loadingGui.Enabled = true
	end)
end

if evSesionLista then
	evSesionLista.OnClientEvent:Connect(function()
		loadingGui.Enabled = false
	end)
end

print("[LobbyUI] Interfaz del lobby lista.")
