-- DayNightUI.client.luau
-- Muestra el timer de día/noche en pantalla y la alerta cuando llega la noche.
-- Se alimenta de los RemoteEvents que dispara DayNightCycle.server.luau

local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService    = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DayNightConfig"))

local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui")

-- Esperar los RemoteEvents del servidor
local carpetaEventos = ReplicatedStorage:WaitForChild("Eventos")
local evNocheComenzo = carpetaEventos:WaitForChild("NocheComenzo")
local evDiaComenzo   = carpetaEventos:WaitForChild("DiaComenzo")
local evTiempoSync   = carpetaEventos:WaitForChild("TiempoSync")

-- ============================================================
-- Construir la UI del timer (esquina superior central)
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name          = "DayNightUI"
screenGui.ResetOnSpawn  = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent        = playerGui

-- Marco principal — reducido en alto para ganar visual del mapa
local marcoTimer = Instance.new("Frame")
marcoTimer.Name                  = "MarcoTimer"
marcoTimer.Size                  = UDim2.new(0, 160, 0, 36)
marcoTimer.Position              = UDim2.new(0.5, -80, 0, 0)
marcoTimer.BackgroundColor3      = Color3.fromRGB(10, 10, 15)
marcoTimer.BackgroundTransparency = 0.35
marcoTimer.BorderSizePixel       = 0
marcoTimer.Parent                = screenGui

local cornerTimer = Instance.new("UICorner")
cornerTimer.CornerRadius = UDim.new(0, 10)
cornerTimer.Parent = marcoTimer

-- Etiqueta de fase (DIA / NOCHE)
local lblFase = Instance.new("TextLabel")
lblFase.Name               = "Fase"
lblFase.Size               = UDim2.new(0, 80, 1, 0)
lblFase.Position           = UDim2.new(0, 8, 0, 0)
lblFase.BackgroundTransparency = 1
lblFase.Text               = "DIA"
lblFase.TextScaled         = true
lblFase.Font               = Enum.Font.GothamBold
lblFase.TextColor3         = Color3.fromRGB(255, 215, 50)
lblFase.TextXAlignment     = Enum.TextXAlignment.Left
lblFase.Parent             = marcoTimer

-- Separador visual
local separador = Instance.new("Frame")
separador.Size               = UDim2.new(0, 2, 0.6, 0)
separador.Position           = UDim2.new(0, 92, 0.2, 0)
separador.BackgroundColor3   = Color3.fromRGB(80, 80, 100)
separador.BorderSizePixel    = 0
separador.Parent             = marcoTimer

-- Etiqueta del tiempo restante (mm:ss)
local lblTimer = Instance.new("TextLabel")
lblTimer.Name               = "Tiempo"
lblTimer.Size               = UDim2.new(0, 70, 1, 0)
lblTimer.Position           = UDim2.new(0, 100, 0, 0)
lblTimer.BackgroundTransparency = 1
lblTimer.Text               = "4:00"
lblTimer.TextScaled         = true
lblTimer.Font               = Enum.Font.GothamMedium
lblTimer.TextColor3         = Color3.fromRGB(220, 220, 230)
lblTimer.TextXAlignment     = Enum.TextXAlignment.Center
lblTimer.Parent             = marcoTimer

-- Barra de progreso de la fase (fondo)
local barraFondo = Instance.new("Frame")
barraFondo.Name              = "BarraFondo"
barraFondo.Size              = UDim2.new(0, 136, 0, 4)
barraFondo.Position          = UDim2.new(0, 12, 1, -7)
barraFondo.BackgroundColor3  = Color3.fromRGB(40, 40, 55)
barraFondo.BorderSizePixel   = 0
barraFondo.Parent            = marcoTimer

local cornerBarraFondo = Instance.new("UICorner")
cornerBarraFondo.CornerRadius = UDim.new(1, 0)
cornerBarraFondo.Parent = barraFondo

-- Barra de progreso (relleno)
local barraRelleno = Instance.new("Frame")
barraRelleno.Name             = "Relleno"
barraRelleno.Size             = UDim2.new(1, 0, 1, 0)
barraRelleno.BackgroundColor3 = Color3.fromRGB(255, 215, 50)
barraRelleno.BorderSizePixel  = 0
barraRelleno.Parent           = barraFondo

local cornerBarraRelleno = Instance.new("UICorner")
cornerBarraRelleno.CornerRadius = UDim.new(1, 0)
cornerBarraRelleno.Parent = barraRelleno

-- ============================================================
-- Alerta de inicio de noche (aparece centrada y desaparece)
-- ============================================================
local marcaAlerta = Instance.new("Frame")
marcaAlerta.Name                  = "AlertaNoche"
marcaAlerta.Size                  = UDim2.new(0, 320, 0, 65)
marcaAlerta.Position              = UDim2.new(0.5, -160, 0.28, 0)
marcaAlerta.BackgroundColor3      = Color3.fromRGB(90, 5, 5)
marcaAlerta.BackgroundTransparency = 0.15
marcaAlerta.BorderSizePixel       = 0
marcaAlerta.Visible               = false
marcaAlerta.Parent                = screenGui

local cornerAlerta = Instance.new("UICorner")
cornerAlerta.CornerRadius = UDim.new(0, 12)
cornerAlerta.Parent = marcaAlerta

local lblAlerta = Instance.new("TextLabel")
lblAlerta.Size               = UDim2.new(1, 0, 1, 0)
lblAlerta.BackgroundTransparency = 1
lblAlerta.Text               = "! LA NOCHE HA LLEGADO !"
lblAlerta.TextScaled         = true
lblAlerta.Font               = Enum.Font.GothamBold
lblAlerta.TextColor3         = Color3.fromRGB(255, 70, 70)
lblAlerta.Parent             = marcaAlerta

-- ============================================================
-- Helpers
-- ============================================================

-- Convierte segundos totales a "m:ss"
local function formatearTiempo(segundos)
	local m = math.floor(segundos / 60)
	local s = segundos % 60
	return string.format("%d:%02d", m, s)
end

-- Aplica colores de día al timer
local function aplicarEstiloDia()
	lblFase.Text       = "DIA"
	lblFase.TextColor3 = Color3.fromRGB(255, 215, 50)
	barraRelleno.BackgroundColor3 = Color3.fromRGB(255, 215, 50)
end

-- Aplica colores de noche al timer
local function aplicarEstiloNoche()
	lblFase.Text       = "NOCHE"
	lblFase.TextColor3 = Color3.fromRGB(130, 130, 255)
	barraRelleno.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
end

-- ============================================================
-- Escuchar eventos del servidor
-- ============================================================

-- Sincronización de tiempo: llega cada ~1 segundo
evTiempoSync.OnClientEvent:Connect(function(esNoche, tiempoRestante)
	-- Actualizar etiqueta de tiempo
	lblTimer.Text = formatearTiempo(tiempoRestante)

	-- Actualizar barra de progreso
	local duracion = esNoche and Config.DURACION_NOCHE or Config.DURACION_DIA
	local proporcion = math.clamp(tiempoRestante / duracion, 0, 1)

	-- Tween suave de la barra para que no salte cada segundo
	TweenService:Create(
		barraRelleno,
		TweenInfo.new(0.8, Enum.EasingStyle.Linear),
		{ Size = UDim2.new(proporcion, 0, 1, 0) }
	):Play()

	-- Estilo visual según fase
	if esNoche then
		aplicarEstiloNoche()
	else
		aplicarEstiloDia()
	end
end)

-- Cuando la noche comienza
evNocheComenzo.OnClientEvent:Connect(function()
	aplicarEstiloNoche()

	-- Mostrar alerta
	marcaAlerta.Visible = true
	marcaAlerta.BackgroundTransparency = 0.15
	lblAlerta.TextTransparency = 0

	-- Desaparecer gradualmente después de 2.5 segundos
	task.delay(2.5, function()
		TweenService:Create(
			marcaAlerta,
			TweenInfo.new(1.2),
			{ BackgroundTransparency = 1 }
		):Play()
		TweenService:Create(
			lblAlerta,
			TweenInfo.new(1.2),
			{ TextTransparency = 1 }
		):Play()

		task.delay(1.3, function()
			marcaAlerta.Visible = false
			lblAlerta.TextTransparency = 0
		end)
	end)
end)

-- Cuando el día comienza: flash dorado sutil en el marco
evDiaComenzo.OnClientEvent:Connect(function()
	aplicarEstiloDia()

	-- Pequeño pulso de color en el fondo del timer
	local tweenEntrada = TweenService:Create(
		marcoTimer,
		TweenInfo.new(0.25),
		{ BackgroundColor3 = Color3.fromRGB(80, 60, 10) }
	)
	local tweenSalida = TweenService:Create(
		marcoTimer,
		TweenInfo.new(0.6),
		{ BackgroundColor3 = Color3.fromRGB(10, 10, 15) }
	)
	tweenEntrada:Play()
	tweenEntrada.Completed:Connect(function()
		tweenSalida:Play()
	end)
end)

print("[DayNightUI] Timer de ciclo dia/noche activo.")
